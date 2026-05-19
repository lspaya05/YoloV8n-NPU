# ISA Coverage Analysis — YOLOv8 on the NPU

**Date:** 2026-05-18
**ISA version:** NPUArchitectureV2
**Models examined:** YOLOv8n, YOLOv8s

---

## What Works Correctly

| YOLOv8 operation | ISA instruction | Notes |
|---|---|---|
| 3×3 / 1×1 convolution | `MATMUL` + `DMA_LOAD` | 2D-strided DMA handles padding and stride; no im2col needed |
| Folded BatchNorm | `REQUANT` | M×>>S encodes BN scale+shift in a single pass |
| SiLU activation | `SIMD_ACT` | 256-entry LUT, correct |
| Residual add (C2f bottleneck) | `ELEW_ADD` | saturating INT8 add, correct |
| 5×5 MaxPool (SPPF) | `MAXPOOL` | 5×5 kernel supported |
| 2× nearest-neighbor upsample (FPN) | `UPSAMPLE` | correct for layers 10, 13 |
| DFL box decode (reg_max=16) | `HREDUCE` | 4-stage binary reduction tree matches reg_max=16 exactly |
| Strided conv (stride 2 downsampling) | `CONFIG` stride field + `DMA_LOAD` | correct |
| Per-channel quantization | `COEFF_LOAD` + `REQUANT` | INT16 scale M, UINT4 shift S per channel |
| Elementwise multiply (ELEW) | `ELEW_MUL` | INT8 → INT16 → requantized INT8 |

---

## Critical Gaps

### 1. `CONCAT` is 2-input only — multi-branch concat is a DDR4 round-trip problem

**Why it matters:**
- **C2f** concatenates `(2 + n)` tensors: the shortcut path plus each bottleneck output.
  - YOLOv8n: `n ≈ 1` → 3-tensor concat
  - YOLOv8s (depth×0.33): `n ≈ 1–2` → 3–4 tensor concat
- **SPPF** concatenates 4 tensors: original input + 3 sequential 5×5 MaxPool outputs.
- **Neck FPN/PAN** C2f blocks repeat the multi-input concat pattern.

**Consequence:**
Every multi-input concat requires chained `DMA_STORE` → `CONCAT` → `DMA_STORE` → `CONCAT` cycles using DDR4 as scratch space for intermediate results. For a 640×640 YOLOv8n inference this adds estimated 5–10 extra ms in DDR4 round-trip traffic spread across all C2f and SPPF blocks.

**Fix:** Add a 3- or 4-input `CONCAT` variant, or add a dedicated SRAM concat scratchpad so intermediate tensors do not leave the chip.

---

### 2. Single 256-entry Act LUT — SiLU and Sigmoid cannot coexist

**Why it matters:**
- Backbone and neck Conv layers use **SiLU** → `SIMD_ACT` with the Act LUT loaded with the SiLU table.
- The detection head classification branch uses **Sigmoid** on its final output.
- There is only one 256-entry Act LUT BRAM.

**Consequence:**
A `LUT_LOAD` reload is required at the backbone-to-head transition. The reload itself is only 256 bytes, but it serializes the last backbone layer and the first head Sigmoid — no overlap possible. Creates a pipeline bubble once per frame.

**Fix:** Add a second 256-byte Act LUT bank (≈ 1 extra BRAM18 slice) and an `lut_sel` bit in `SIMD_ACT`; or dedicate one LUT slot permanently to Sigmoid and one to the user-configurable activation.

---

### 3. No PERMUTE / RESHAPE instruction

**Why it matters:**
The detection head must:
1. Reshape each scale output: `(B, H, W, C)` → `(B, H×W, C)`
2. Concatenate all three scale outputs into `(B, 8400, 144)` for NMS input.

There is no ISA instruction for tensor transpose or reshape. These operations must run on the ARM PS.

**Consequence:**
The ARM must copy and reformat ~1.2 MB of output data per frame (6400 + 1600 + 400 spatial positions × 144 channels × INT8). This is standard practice for edge NPUs and is not a blocker, but it is a confirmed CPU cost that limits end-to-end latency.

**Fix:** Acceptable as-is; document it as an ARM post-processing step in the driver.

---

### 4. `MAX_CHANNELS = 512` caps the requant buffer for larger models

| Model | Peak channels | Fits in 512-deep buffer? |
|---|---|---|
| YOLOv8n (width 0.25×) | 256 | Yes |
| YOLOv8s (width 0.50×) | 512 | Exactly (borderline) |
| YOLOv8m (width 0.75×) | 768 | **No** |
| YOLOv8l/x (width 1.0×) | 1024 | **No** |

**Fix:** Increase `MAX_CHANNELS` in `NPU_HW_params_pkg.sv` if targeting m/l/x variants. Costs one additional BRAM18 per doubling.

---

## Performance Concerns (Correctness Fine, Throughput Affected)

### 5. 1×1 convolutions underutilize the 16×16 SA

C2f uses 1×1 convs for the channel-split and channel-fuse steps. With `tile_K = 1`, each PE accumulates once per tile — the systolic array is essentially used as a banked multiplier rather than an accumulator. Effective utilization ≈ 1/K_depth per 1×1 layer.

This is a throughput concern, not a correctness one. Nothing to fix in the ISA; it is inherent to weight-stationary systolic arrays on pointwise convolutions.

### 6. `HREDUCE` reg_max is hardwired to 16

The 4-stage binary reduction tree assumes exactly 16 input values (reg_max=16), which matches the default YOLOv8 DFL configuration. If a future variant uses `reg_max=8` or `reg_max=32`, the instruction breaks.

**Fix:** Add a `reg_max[4:0]` field to the `HREDUCE` payload (currently all-zero reserved bits) to parameterize the reduction depth.

---

## Summary

| Category | Count |
|---|---|
| Operations fully covered | 10 |
| Critical gaps (functional holes) | 3 |
| Performance concerns | 2 |

The ISA can run YOLOv8n and YOLOv8s **functionally**. The dominant pain point is the 2-input CONCAT limitation, which forces DDR4 round-trips on every C2f and SPPF block. YOLOv8m and larger are blocked by the 512-channel requant buffer cap. Everything else is either working or can be handled by the ARM PS with acceptable overhead.
