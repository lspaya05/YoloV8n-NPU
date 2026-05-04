# INT8 NPU Design Document
### YOLOv8n Inference · Kria KR260 · 300 MHz · v2.0

---

## 1. Architecture Overview

The NPU runs on the KR260 PL (FPGA fabric) and is controlled by the ARM Cortex-A53 PS running Ubuntu + PyTorch. The ARM dispatches layer-by-layer via a Linux character driver using AXI-Lite CSR writes and a per-frame interrupt. The NPU handles all MAC-intensive compute; the ARM handles control flow, pre/post-processing, and irregular ops.

**Key changes from v1.0:** Clock upgraded to 300 MHz; software im2col fully replaced by hardware 2D strided DMA; SRAM split into dedicated banks; per-channel quantization mandatory; BN and requant fused into a single pipeline stage; PSB_ACC/PSB_FLUSH replace the `last_k` flag; HREDUCE added to VPU for DFL box decoding; FENCE replaces SYNC.

---

## 2. Block Descriptions

### ARM PS · A53

| Block | What it does |
|---|---|
| **Preprocess** | Letterbox-resize input image to 640×640, normalize pixel values, quantize to INT8 using a single input scale factor. ~0.15 ms NEON. |
| **Detect head (DFL assist)** | HREDUCE instruction in the VPU handles 4-stage tree reduction for DFL box decoding. Class sigmoid (~672 k calls in fp32) and IoU-based NMS run on A53 in PyTorch. Total detect: ~3–8 ms. |
| **NMS + decode** | Score sort, IoU-based box suppression, bbox xyxy decode. Highly branchy and data-dependent — poor fit for SIMD hardware. |

---

### NPU · PL

#### SRAM Hub — Dedicated Banks

| Bank | What it does |
|---|---|
| **Act Bank A/B** | Ping-pong activation buffers. While Bank A feeds the SA, Bank B is being written by DMA_LOAD. Swap each tile. |
| **Weight Bank A/B** | Ping-pong weight buffers. Next layer's weights are prefetched via WT_LOAD while the SA computes the current layer. Fully independent ping-pong from Act Banks. |
| **Residual Bank** | Holds C2f skip-connection tensors. Written by DMA; read directly by the VPU eltwise stage, bypassing the SA, PSB, and Requant entirely. |
| **Output Bank** | Written by the VPU at the end of each layer. Becomes the source for DMA_STORE back to DDR4. |

#### 2D Strided DMA
Fetches spatial tiles from DRAM using a descriptor: `{base_addr, row_stride, tile_w, tile_h, ch_count, pad_top, pad_bottom, pad_left, pad_right}`. Computes im2col-layout addresses in hardware: `addr = base + h*row_stride + w*ch_count + c`. Inserts synthetic zero rows/columns at image edges so the SA never sees out-of-bounds reads. Runs concurrently with SA compute via ping-pong. Also supports UPSAMPLE (2× nearest-neighbor) and CONCAT (2D-strided gather for FPN concat) modes — these remain in hardware, not on ARM.

**No software im2col at any stage.** The 40 MB/frame DDR4 im2col workspace and ~5 ms/frame ARM im2col overhead from v1.0 are fully eliminated.

#### Systolic Array 16×16
256-PE weight-stationary array. Activations are skew-loaded diagonally; weights are held stationary in PE registers and prefetched via WT_LOAD into the inactive Weight Bank. Each PE computes INT8 × INT8 → INT32 and accumulates. Handles every `Conv2d` in the backbone, neck, and detection head — approximately 95% of total YOLOv8n compute.

#### PSB — Partial Sum Buffer
Holds the INT32 running total across input-channel (K) tiles. After each MATMUL, PSB_ACC adds the tile's result to the running total. When all K-tiles are exhausted, PSB_FLUSH forwards the final INT32 values to the Requant pipeline and zero-clears the PSB. No `last_k` flag in MATMUL — K-tile counting is managed entirely by the sequencer's PSB instruction sequence.

#### Requant Pipeline — Fused BN + Requant
Converts INT32 PSB output to INT8 in a single pipelined stage using per-channel `(M, S)` coefficients. The `M` (INT16 fixed-point scale) and `S` (UINT4 right-shift) simultaneously encode the folded BatchNorm scale, replacing the separate BIAS_ADD stage from v1.0.

Operation: `INT8_out = clip(round((INT32_acc × M) >> S), -128, 127)`

A BRAM-resident coefficient buffer holds one `(M, S)` pair per output channel (up to 512 channels). Coefficients are loaded from DDR4 before each layer via the COEFF_LOAD instruction.

#### 64-Lane VPU

| Stage | What it does |
|---|---|
| **① Act LUT** | 256-entry × 8-bit BRAM table. Uses the INT8 value from Requant as an array index and returns `SiLU(x)` in one cycle per lane. A `LUT_BYPASS` mux passes the value through unchanged for linear layers. LUT pre-loaded before each layer via `LUT_LOAD`. |
| **② Eltwise + MaxPool** | Saturating INT8 lane-wise add for C2f residual connections (residual tensor arrives directly from the Residual Bank, bypassing LUT, Requant, and PSB). ELEW_MUL for elementwise multiply (rare in YOLOv8n). RELU for future variants. SPPF's three cascaded 5×5 max-pool passes via MAXPOOL. |
| **③ HREDUCE** | 4-stage in-lane binary reduction tree (16→8→4→2→1). Fires **once per frame** for DFL box decoding: max → subtract → exp (LUT) → sum → normalize → dot product with `[0..15]` to produce continuous box coordinates. Passthrough on all conv layers. |

---

## 3. ISA — NPU Sequencer Instructions

All instructions are 128-bit fixed-width. Opcode in [127:120], unit_id in [119:116], dependency flags in [115:112], payload in [111:0]. Dispatched from the ARM via AXI-Lite into five unit FIFOs (DMA, SA, PSB/Requant, VPU, Sequencer).

Synchronisation uses the **FENCE** instruction (bitmask of units) rather than a two-FIFO SYNC primitive, allowing waiting on any combination of units simultaneously.

| Instruction | Opcode | Unit | Description |
|---|---|---|---|
| `CONFIG` | 0x01 | Sequencer | Load layer parameters into shadow registers: tile shape (M,N,K), conv stride, requant coeff base address, padding mode, activation type, pool size. |
| `FENCE` | 0x02 | Sequencer | Block until all units in a bitmask (bits [7:0] of payload) report completion. Used to synchronise pipeline stages at layer boundaries. |
| `WT_LOAD` | 0x10 | DMA | Prefetch INT8 weight tile from DDR4 into inactive Weight Bank (A or B). Runs concurrently with SA compute on active Weight Bank. |
| `DMA_LOAD` | 0x11 | DMA | 2D-strided fetch of INT8 activation tile from DDR4 into Act Bank. Args: base_addr, row_stride, tile_w, tile_h, ch_count, pad counts. Zero-padding inserted in hardware. |
| `DMA_STORE` | 0x12 | DMA | Burst-write INT8 Output Bank to DDR4. |
| `UPSAMPLE` | 0x13 | DMA | 2× nearest-neighbor upsample. Reads source tensor from DDR4, emits each pixel 2×2 times into SRAM. FPN neck layers 10 and 13. |
| `CONCAT` | 0x14 | DMA | 2D-strided gather: reads from two DDR4 base addresses and interleaves channels into SRAM. All five FPN/PAN concat operations. |
| `COEFF_LOAD` | 0x15 | DMA | Write per-channel `(M: INT16, S: UINT4)` requant coefficient pairs from DDR4 into the Requant BRAM. Args: src DDR4 addr, channel count. |
| `MATMUL` | 0x20 | SA | Execute one 16×16 INT8 matrix multiply tile. Reads from Act Bank and Weight Bank; outputs INT32 results to PSB_ACC. |
| `PSB_ACC` | 0x21 | PSB | Add current SA output into PSB INT32 running total. Issues after every MATMUL. No SRAM access. |
| `PSB_FLUSH` | 0x22 | PSB | Signal K-tiles complete. Forward final INT32 from PSB to Requant pipeline input; zero-clear PSB for next layer. |
| `REQUANT` | 0x30 | Requant | Apply per-channel `(M, S)` multiply-shift-clip to PSB output. Reads coefficient BRAM sequentially per output channel. |
| `LUT_LOAD` | 0x31 | VPU | Write 256 bytes of LUT data into Act LUT BRAM from DDR4. Must issue before SIMD_ACT on a new layer. |
| `LUT_BYPASS` | 0x32 | VPU | Enable/disable the LUT bypass mux. When enabled, Act LUT output is replaced by passthrough (linear layers, no activation). |
| `SIMD_ACT` | 0x33 | VPU | Run Act LUT lookup across all 64 lanes for one output row. INT8 → LUT → INT8. Single-cycle throughput after LUT_LOAD. |
| `RELU` | 0x34 | VPU | Apply ReLU: clamp INT8 values at zero. Per-lane comparator. Included for future YOLOv8 variants. |
| `ELEW_ADD` | 0x35 | VPU | Saturating elementwise INT8 add of Output Bank + Residual Bank (C2f residual connections). Optional 1-bit right shift to prevent overflow. |
| `ELEW_MUL` | 0x36 | VPU | Elementwise INT8 multiply → INT16 intermediate → requantized INT8. Rarely used in YOLOv8n. |
| `MAXPOOL` | 0x37 | VPU | Sliding-window maximum per lane. 3×3 or 5×5 kernel (CONFIG pool_size bit). SPPF three-stage 5×5 pooling. Tournament comparator: 25 inputs, 5 levels. |
| `HREDUCE` | 0x38 | VPU | 4-stage binary reduction tree within 16-element lane groups. Fires once per frame for DFL box decoding: max → subtract → exp LUT → sum → dot·[0..15] → continuous box coordinates. Passthrough on all conv layers. |

---

## 4. Data Types

| Region | Type | Width |
|---|---|---|
| DRAM weights & activations | INT8 | 8-bit |
| SA accumulator / PSB | INT32 | 32-bit |
| Requant coefficient M | INT16 (fixed-point) | 16-bit |
| Requant shift S | UINT4 | 4-bit |
| Requant output | INT8 | 8-bit |
| VPU lanes | INT8 | 8-bit |
| Act LUT | 256 × INT8 | 8-bit |
| HREDUCE exp LUT | 256 × INT8 → fixed-point | 8-bit |
| DFL output to ARM | INT8 (dequantized to fp32 on ARM) | 8-bit → fp32 |

---

## 5. On-Chip Memory Map

| Buffer | Size | Notes |
|---|---|---|
| Act Bank A | tile_H × tile_W × C bytes | Sized for largest single tile in YOLOv8n |
| Act Bank B | tile_H × tile_W × C bytes | Ping-pong partner |
| Weight Bank A | K × C × 3 × 3 bytes | Largest conv weight tile |
| Weight Bank B | K × C × 3 × 3 bytes | Ping-pong partner for WT_LOAD prefetch |
| Residual Bank | tile_H × tile_W × C bytes | C2f skip tensor; direct VPU eltwise port |
| Output Bank | tile_H × tile_W × K bytes | VPU write-back; source for DMA_STORE |
| PSB | 16 × 16 × INT32 | One INT32 per SA output PE (~1 KB) |
| Requant coeff buf | 512 × (M:INT16 + S:UINT4) | Worst case: 512 output channels (~1 BRAM18) |
| Act LUT BRAM | 256 × 8-bit = 256 B | Single block RAM, one per VPU LUT stage |
| HREDUCE exp LUT | 256 × 8-bit = 256 B | Shared across HREDUCE lanes |

---

## 6. DDR4 Memory Map

| Region | Address Range | Size / Notes |
|---|---|---|
| NPU instruction programs | 0x2000_0000 — 0x2000_FFFF | 64 KB |
| INT8 model weights | 0x2001_0000 — 0x2033_FFFF | ~3.2 MB |
| Requant coefficient table | 0x2034_0000 — 0x2034_FFFF | 64 KB — per-layer per-channel (M, S) pairs |
| Input image buffer | 0x2035_0000 — 0x2035_FFFF | 640×640×1 = 409 KB |
| Layer activation buffers (ping-pong) | 0x2040_0000 — 0x2060_FFFF | ~33 MB — no im2col workspace in v2.0 |
| Skip feature maps (L4, L6, L9) | 0x2061_0000 — 0x2062_FFFF | ~717 KB — never overwritten mid-inference |
| SiLU LUT store (per layer) | 0x2063_0000 — 0x2063_FFFF | 64 KB — precomputed offline |
| ARM output buffer (detect head) | 0x2064_0000 — 0x2064_FFFF | 64 KB — bbox + class outputs from NMS |

The 40 MB im2col workspace present in v1.0 is eliminated.

---

## 7. ARM ↔ NPU Interface

- **AXI-Lite CSR**: ARM writes layer descriptors and instruction words to memory-mapped registers at base 0xA000_0000.
- **DMA**: `dma_alloc_coherent` allocates physically contiguous buffers for activation, weight, and output tensors. The NPU DMA engine reads/writes these directly via HP0 (read) and HP1 (write).
- **Completion interrupt**: One interrupt per frame fired when the final `DMA_STORE` completes. All sub-unit interrupts masked in driver.
- **PyTorch integration**: `torch.library` custom op `npu::conv_silu` wraps the driver call. Dispatches COEFF_LOAD + LUT_LOAD + instruction stream per op invocation; blocks on IRQ.

---

## 8. YOLOv8n Layer Partition

Layers 0–21 run entirely on the FPGA NPU. Layer 22 (Detect head, HREDUCE assist + ARM) runs split between VPU and A53. ~95% of inference FLOPs on FPGA.

### 8.1 Backbone (Layers 0–9) — All FPGA

| # | Operation | Input Shape | Output Shape | Unit |
|---|---|---|---|---|
| 0 | Conv 3×3 s2 — 3→16 ch | 640×640×3 | 320×320×16 | SA + Requant + VPU |
| 1 | Conv 3×3 s2 — 16→32 ch | 320×320×16 | 160×160×32 | SA + Requant + VPU |
| 2 | C2f n=1 — 32→32 ch | 160×160×32 | 160×160×32 | SA + Requant + VPU + ELEW_ADD |
| 3 | Conv 3×3 s2 — 32→64 ch | 160×160×32 | 80×80×64 | SA + Requant + VPU |
| 4 | C2f n=2 — 64→64 ch | 80×80×64 | 80×80×64 | SA + Requant + VPU + ELEW_ADD |
| 5 | Conv 3×3 s2 — 64→128 ch | 80×80×64 | 40×40×128 | SA + Requant + VPU |
| 6 | C2f n=2 — 128→128 ch (P4 saved) | 40×40×128 | 40×40×128 | SA + Requant + VPU + ELEW_ADD |
| 7 | Conv 3×3 s2 — 128→256 ch | 40×40×128 | 20×20×256 | SA + Requant + VPU |
| 8 | C2f n=1 — 256→256 ch | 20×20×256 | 20×20×256 | SA + Requant + VPU + ELEW_ADD |
| 9 | SPPF — 3× MaxPool 5×5, concat ×4 ch | 20×20×256 | 20×20×256 | VPU (MAXPOOL ×3) |

### 8.2 FPN/PAN Neck (Layers 10–21) — All FPGA

| # | Operation | Input Shape | Output Shape | Unit |
|---|---|---|---|---|
| 10 | Upsample 2× nearest-neighbor | 20×20×256 | 40×40×256 | DMA (UPSAMPLE) |
| 11 | Concat L10 + L6 skip | 40×40×256 + 40×40×128 | 40×40×384 | DMA (CONCAT) |
| 12 | C2f n=1 — 384→128 ch | 40×40×384 | 40×40×128 | SA + Requant + VPU |
| 13 | Upsample 2× nearest-neighbor | 40×40×128 | 80×80×128 | DMA (UPSAMPLE) |
| 14 | Concat L13 + L4 skip | 80×80×128 + 80×80×64 | 80×80×192 | DMA (CONCAT) |
| 15 | C2f n=1 — 192→64 ch (P3 out, 80×80) | 80×80×192 | 80×80×64 | SA + Requant + VPU |
| 16 | Conv 3×3 s2 — 64→64 ch | 80×80×64 | 40×40×64 | SA + Requant + VPU |
| 17 | Concat L16 + L12 skip | 40×40×64 + 40×40×128 | 40×40×192 | DMA (CONCAT) |
| 18 | C2f n=1 — 192→128 ch (P4 out, 40×40) | 40×40×192 | 40×40×128 | SA + Requant + VPU |
| 19 | Conv 3×3 s2 — 128→128 ch | 40×40×128 | 20×20×128 | SA + Requant + VPU |
| 20 | Concat L19 + L9 skip | 20×20×128 + 20×20×256 | 20×20×384 | DMA (CONCAT) |
| 21 | C2f n=1 — 384→256 ch (P5 out, 20×20) | 20×20×384 | 20×20×256 | SA + Requant + VPU |

### 8.3 Detect Head (Layer 22) — VPU HREDUCE + ARM

| # | Operation | Inputs | Notes |
|---|---|---|---|
| 22 | Detect [L15, L18, L21] — DFL + NMS | 80×80×64, 40×40×128, 20×20×256 | HREDUCE in VPU performs DFL box decode (tree reduction). Class sigmoid and NMS on A53 in PyTorch. ~3–8 ms total. |

### 8.4 Skip-Connection Feature Map Retention

| Layer | Tensor | Size (INT8) | Retained Until |
|---|---|---|---|
| L4 output | 80×80×64 | 409 KB | Layer 14 concat |
| L6 output | 40×40×128 | 205 KB | Layer 11 concat |
| L9 output | 20×20×256 | 103 KB | Layer 20 concat |

Total live DDR4 retention: ~717 KB. These regions are reserved in the DDR4 memory map.

---

## 9. Sample Microcode — One Conv+SiLU Layer

Full instruction sequence for one 3×3 Conv+SiLU layer (128 in channels, 64 out channels, 40×40 spatial tile). BN pre-folded. 2D strided DMA fetches im2col layout natively.

```
COEFF_LOAD  src=DDR4:0x0034_0000  ch=64               ; load per-channel (M, S)
LUT_LOAD    src=DDR4:0x0063_0000                       ; SiLU LUT for this layer's scale
WT_LOAD     src=DDR4:0x0400_0000  dst=Weight_BankB     ; prefetch K=0..15 weights
DMA_LOAD    base=DDR4:0x0200_0000  row_stride=...      ; activation tile K=0

FENCE       wait=[DMA_done, WT_done]

MATMUL      act=ActBank_A  wt=WeightBank_B             ; K tile 0
PSB_ACC                                                ; accumulate into PSB

WT_LOAD     src=DDR4:0x0400_0100  dst=Weight_BankA     ; prefetch K=16..31
DMA_LOAD    base=DDR4:0x0200_0100  row_stride=...      ; activation tile K=1

... (repeat for K=32..127, 8 tiles total)

MATMUL      act=ActBank_A  wt=WeightBank_B             ; final K tile
PSB_ACC
PSB_FLUSH                                              ; forward INT32 to Requant

FENCE       wait=[PSB_done]

REQUANT                                                ; per-channel M/S clip (fused BN)
SIMD_ACT                                               ; SiLU LUT lookup, 64 lanes

DMA_STORE   src=OutputBank  dst=DDR4:0x0300_0000
```

---

## 10. Key Design Constraints

| Constraint | Value |
|---|---|
| Clock | 300 MHz (PL); 250 MHz fallback if timing closure fails |
| SA size | 16×16 PEs = 256 MACs/cycle |
| Target throughput | ~102 GOPS (INT8) at 300 MHz |
| Quantization | Per-channel INT8 — global scale collapses accuracy |
| Activation | SiLU via 256-entry LUT; LUT_BYPASS for linear layers |
| DMA | 2D strided, no software im2col at any stage |
| Max on-chip SRAM | ~38 BRAM36; Residual Bank may require URAM for large skip tensors |
| DMA bandwidth | HP0 read + HP1 write: up to 19.2 GB/s theoretical combined |
| Completion interrupt | One IRQ per inference frame (not per layer) |

---

## 11. TODO List

### 11.1 Quantization & Model Export
- [ ] Export YOLOv8n from PyTorch using `torch.export` or ONNX
- [ ] Run post-training quantization (PTQ) with 500+ representative COCO images
- [ ] Extract per-channel `(M, S)` scale/shift pairs for every Conv2d layer
- [ ] Fuse BatchNorm into Conv2d weights and bias offline (`model.fuse()`)
- [ ] Build per-layer per-channel quantization config file (JSON/YAML)
- [ ] Precompute SiLU LUT entries `[SiLU(dequant(i)) for i in range(-128, 128)]` and quantize to INT8
- [ ] Precompute HREDUCE exp LUT entries for DFL softmax path
- [ ] Validate INT8 model accuracy vs fp32 baseline (target: <1.0 mAP drop)

### 11.2 RTL — 2D Strided DMA
- [ ] Design DMA descriptor register file (`base_addr, row_stride, tile_w, tile_h, ch_count, pad_top/bot/left/right`)
- [ ] Implement row-stride address generator: `addr = base + h*row_stride + w*ch_count + c`
- [ ] Implement zero-padding insertion state machine (suppress DRAM read, output zero word)
- [ ] Implement AXI4 master: read channel on HP0, write channel on HP1
- [ ] Implement UPSAMPLE mode (2× nearest-neighbor pixel repetition)
- [ ] Implement CONCAT mode (2D-strided gather from two DDR4 base addresses)
- [ ] Implement COEFF_LOAD path (write requant coefficients into Requant BRAM)
- [ ] Implement ping-pong bank select logic for Act Banks and Weight Banks independently
- [ ] Write testbench: verify correct tile extraction at image edges with all four padding modes
- [ ] Verify concurrent WT_LOAD + DMA_LOAD + SA compute (three-way ping-pong timing)

### 11.3 RTL — SRAM Hub
- [ ] Instantiate Act Bank A/B (dual-port BRAM: read port → SA activation input; write port ← DMA)
- [ ] Instantiate Weight Bank A/B (dual-port BRAM: read port → SA weight load phase; write port ← DMA WT_LOAD)
- [ ] Instantiate Residual Bank (write port ← DMA; read port → VPU eltwise stage directly)
- [ ] Instantiate Output Bank (write port ← VPU; read port → DMA DMA_STORE)
- [ ] Implement bank-select mux and ping-pong swap control signals for Act and Weight Banks independently
- [ ] Verify no port conflicts: Residual Bank read and Act Bank read must be independent ports

### 11.4 RTL — Systolic Array 16×16
- [ ] Implement single INT8 PE: registered multiply-accumulate into INT32
- [ ] Tile 16×16 PE array with weight-stationary datapath
- [ ] Implement activation skew-load FIFOs (depth = column index, 0..15)
- [ ] Implement weight load phase: broadcast from active Weight Bank to PE rows
- [ ] Implement compute phase: stream activations from Act Bank, accumulate INT32
- [ ] Wire SA output (256 INT32 values) to PSB_ACC input
- [ ] Confirm DSP48E2 dual-packing for v2: two MACs per DSP via pre-adder (WP486)
- [ ] Write testbench: verify INT32 output against numpy reference for 3×3 and 1×1 conv tiles

### 11.5 RTL — PSB
- [ ] Implement 16×16 INT32 register bank (one accumulator per PE output position)
- [ ] Implement PSB_ACC: add new SA output into running total; no SRAM access
- [ ] Implement PSB_FLUSH: forward final INT32 values to Requant pipeline input; zero-clear
- [ ] Write testbench: multi-tile accumulation matches reference across 8 K-tiles

### 11.6 RTL — Requant Pipeline
- [ ] Implement per-channel coefficient BRAM (512 × {M: INT16, S: UINT4})
- [ ] Implement COEFF_LOAD write path from DMA into coefficient BRAM
- [ ] Implement sequential read port: increment channel address each output cycle
- [ ] Implement multiply-shift pipeline: INT32 × INT16 → INT48, right-shift by S, round
- [ ] Implement saturating clip to [−128, 127]; one DSP48E2 per lane for M multiply
- [ ] Write testbench: verify per-channel output matches software PTQ reference values

### 11.7 RTL — VPU (64 lanes)
- [ ] Implement Act LUT BRAM (256 × 8-bit); LUT_LOAD write path; LUT_BYPASS mux
- [ ] Implement SIMD_ACT: LUT lookup per lane, single-cycle throughput
- [ ] Implement ELEW_ADD: saturating lane-wise add from Residual Bank
- [ ] Implement ELEW_MUL: INT8×INT8 → INT16 → requantized INT8
- [ ] Implement RELU: max(0, x) per lane
- [ ] Implement MAXPOOL: sliding 5×5 window, tournament comparator tree (25 inputs, 5 levels)
- [ ] Implement HREDUCE 4-stage binary tree:
  - [ ] Stage 1: 16→8 (8 parallel adds/max ops)
  - [ ] Stage 2: 8→4
  - [ ] Stage 3: 4→2
  - [ ] Stage 4: 2→1 (scalar result per group)
  - [ ] Exp LUT for softmax path (256 × INT8 → fixed-point exp)
  - [ ] Dot product with [0..15] for DFL weighted sum
- [ ] Write testbench: SiLU correctness, ELEW_ADD saturation at ±127, HREDUCE softmax vs numpy

### 11.8 RTL — Sequencer
- [ ] Implement five instruction FIFOs: DMA, SA, PSB/Requant, VPU, Sequencer control
- [ ] Implement 128-bit instruction decoder: opcode [127:120] + unit_id [119:116] + dep flags [115:112] + payload [111:0]
- [ ] Implement FENCE barrier: stall downstream FIFOs until bitmask of done signals asserts
- [ ] Implement AXI-Lite instruction write interface (ARM pushes 128-bit words into FIFOs)
- [ ] Implement completion IRQ: fire on final DMA_STORE done signal
- [ ] Write testbench: full single-layer dispatch (COEFF_LOAD → LUT_LOAD → WT_LOAD → DMA_LOAD → FENCE → MATMUL × N → PSB_ACC × N → PSB_FLUSH → FENCE → REQUANT → SIMD_ACT → ELEW_ADD → DMA_STORE)

### 11.9 Integration & Top-Level RTL
- [ ] Wire all blocks at top level: DMA ↔ SRAM Hub ↔ SA ↔ PSB ↔ Requant ↔ VPU
- [ ] Connect AXI-Lite slave to Zynq PS AXI master in Vivado block design
- [ ] Connect AXI4 DMA read master to HP0 port; write master to HP1 port
- [ ] Assign AXI-Lite CSR base address in device tree (0xA000_0000)
- [ ] Run Vivado synthesis and check timing at 300 MHz
- [ ] Fix any timing violations (pipeline registers in DSP48E2 chains, SA output path)
- [ ] Run Vivado implementation and confirm resource utilisation fits KR260

### 11.10 Verification
- [ ] Write full-layer cocotb testbench: feed real INT8 YOLOv8n Conv2d tile, compare output to PyTorch INT8 reference
- [ ] Verify 2D strided DMA padding correctness on all four image edges
- [ ] Verify K-tile accumulation across multiple PSB_ACC / PSB_FLUSH cycles (8-tile test)
- [ ] Verify per-channel Requant matches PTQ reference values for each output channel
- [ ] Verify SiLU LUT matches software reference across all 256 INT8 inputs
- [ ] Verify HREDUCE softmax output matches numpy softmax to within floating-point tolerance
- [ ] Verify ELEW_ADD saturation at ±127 boundary conditions
- [ ] Verify WT_LOAD + DMA_LOAD concurrent execution does not cause port conflicts
- [ ] Run ILA capture on hardware for a single layer dispatch
- [ ] **Acceptance criterion**: mAP50 on COCO val2017 (500 images) within 1.5 points of FP32 baseline

### 11.11 Linux Driver
- [ ] Write Linux char driver (`/dev/npu0`) as platform character device
- [ ] Map AXI-Lite CSR region with `ioremap`
- [ ] Allocate DMA-coherent buffers with `dma_alloc_coherent` for act, weight, output tensors
- [ ] Implement `ioctl`: `LOAD_WEIGHTS`, `DISPATCH_LAYER`, `WAIT_DONE`
- [ ] Register interrupt handler for completion IRQ; use `wait_for_completion` / `complete`
- [ ] Write device tree node (`reg`, `interrupts`, `compatible = "mynpu,v2"`)
- [ ] Test driver with simple memcpy kernel before full integration

### 11.12 PyTorch Integration
- [ ] Register `torch.library` custom op: `npu::conv_silu(input, weight, M, S, lut) -> Tensor`
- [ ] Implement op: copy tensors into DMA buffers → write COEFF_LOAD + LUT_LOAD + instruction stream → wait on IRQ → return output tensor
- [ ] Register autograd passthrough (inference only, no backward needed)
- [ ] Write Python layer dispatch scheduler: iterate YOLOv8n graph, call NPU op for each Conv2d
- [ ] Benchmark end-to-end latency: preprocess → NPU → HREDUCE → NMS

### 11.13 Bring-Up Sequence
- [ ] Flash bitstream to KR260 via Vivado Hardware Manager over Tailscale / JTAG
- [ ] Confirm AXI-Lite register read/write from ARM (`devmem2` smoke test)
- [ ] Run single-layer dispatch: verify Output Bank contents via ILA
- [ ] Run full YOLOv8n inference on a single test image
- [ ] Compare NPU output vs PyTorch CPU INT8 reference (check mAP)
- [ ] Measure per-frame latency and throughput at 300 MHz
- [ ] Profile bottlenecks: DMA bandwidth, SA utilisation, VPU idle time

---

## 12. Open Questions

| Open Question | Status / Notes |
|---|---|
| Residual Bank sizing | 80×80×64 skip tensor = 409 KB — may exceed BRAM budget. Consider URAM or DDR4 prefetch. Decision pending. |
| SPPF concat | 4-way concat along channel dim — needs CONCAT three times or a 4-way DMA mode. Design decision pending. |
| Tiling for 80×80 layers | 80×80×192 activations may not fit in Act Banks in one shot. Halo handling strategy for tiling along H or W TBD. |
| QAT vs PTQ | Run PTQ first; if mAP drop > 1.5 points, escalate to QAT (~50 GPU-hours on A100). |
| Timing closure at 300 MHz | Achievable for pipelined DSP48E2 chains on XCK26. Verify after RTL. 250 MHz fallback. |
| HREDUCE scheduling | Fires once per frame after layer 21. Verify it does not stall VPU pipeline. Explicit FENCE before HREDUCE required. |
| Per-channel ELEW_ADD scales | If residual branch and main branch have different quantization scales, REQUANT must be applied to one branch before ELEW_ADD. Driver must detect and insert accordingly. |

---

## 13. Key References

| Reference | Relevance |
|---|---|
| Jacob et al., CVPR 2018 (arXiv:1712.05877) | INT8 per-channel requantization M·2^(−n); BN folding math |
| Xilinx WP486 | INT8 dual-packing for DSP48E2; latency benchmarks on ZU5EV |
| Gemmini (UC Berkeley): github.com/ucb-bar/gemmini | Weight-stationary systolic RTL; 2D-strided DMA patterns |
| Apache TVM VTA: github.com/apache/tvm-vta | Microcoded sequencer; dependency FIFO design; instruction encoding |
| NVDLA: github.com/nvdla/hw | AXI4 master DMA patterns; SDP post-processing pipeline; CSR conventions |
| Eyeriss v2 (MIT): arXiv:1807.07928 | Flexible dataflow; depthwise conv for future model variants |
| Ultralytics YOLOv8 YAML: github.com/ultralytics/ultralytics | Authoritative layer definitions for YOLOv8n variant |
| Xilinx PG058, PG057, PG247, PG172 | BRAM Generator, FIFO Generator, SmartConnect, ILA product guides |
| Xilinx UG1085: Zynq UltraScale+ Device TRM | AXI HP port specs; DDR4 controller latency; PS-PL interface constraints |
| Xilinx dma-proxy driver | Linux DMA coherency patterns; `dma_alloc_coherent` for AXI HP transfers |

---

*Document version: 2.0 — merged architecture: 300 MHz · 2D strided DMA · per-channel quant · fused Requant · dedicated SRAM banks · explicit PSB_ACC/PSB_FLUSH · HREDUCE VPU · FENCE sync · UPSAMPLE/CONCAT in DMA.*