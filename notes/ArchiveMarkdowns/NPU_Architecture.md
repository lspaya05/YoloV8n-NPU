# INT8 NPU Design Document
### YOLOv8n Inference · Kria KR260 · 300 MHz

---

## 1. Architecture Overview

The NPU runs on the KR260 PL (FPGA fabric) and is controlled by the ARM Cortex-A53 PS running Ubuntu + PyTorch. The ARM dispatches layer-by-layer via a Linux character driver using AXI-Lite CSR writes. The NPU handles all MAC-intensive compute; the ARM handles control flow, pre/post-processing, and irregular ops.

---

## 2. Block Descriptions

### ARM PS · A53

| Block | What it does |
|---|---|
| **Preprocess** | Letterbox-resize input image to 640×640, normalize pixel values, quantize to INT8 using a single input scale factor. |
| **Upsample ×2** | Bilinear nearest-neighbor 2× upsampling in the PAN-FPN neck. Runs on NEON; too irregular to tile efficiently on NPU. |
| **Concat / Split** | `torch.cat` to merge P3/P4/P5 FPN feature maps; `torch.chunk` to split input channels for C2f branches. Pure DMA gather/scatter — no arithmetic. |
| **Class sigmoid** | Applies sigmoid to 80-class logits across 8,400 anchors (~672k calls). Cheap in NEON fp32; not worth an NPU round-trip. |
| **NMS + decode** | Score sort, IoU-based box suppression, conversion of raw offsets to xyxy pixel coordinates. Highly branchy and data-dependent — poor fit for SIMD hardware. |

---

### NPU · PL

#### SRAM Hub

| Bank | What it does |
|---|---|
| **Act Bank A/B** | Ping-pong activation buffers. While bank A feeds the SA, bank B is being written by the DMA. Swap each tile. |
| **Weight Bank A/B** | Ping-pong weight buffers. Next layer's weights are prefetched while the SA computes the current layer. |
| **Residual Bank** | Holds the C2f skip-connection tensor. Read directly by the VPU eltwise stage, bypassing the SA, PSB, Requant, and LUT entirely. |
| **Output Bank** | Written by the VPU at the end of each layer. Becomes the next layer's Act Bank after the swap. |

#### 2D Strided DMA
Fetches spatial tiles from DRAM using a descriptor: `{base_addr, row_stride, tile_w, tile_h, ch_count, pad_top, pad_bottom, pad_left, pad_right}`. Skips non-tile columns automatically and inserts synthetic zero rows/columns at image edges so the SA never sees out-of-bounds reads. Runs concurrently with SA compute via ping-pong.

#### Systolic Array 16×16
256-PE weight-stationary array. Activations are skew-loaded diagonally; weights are held stationary in PE registers. Each PE computes INT8 × INT8 → INT32 and accumulates. Handles every `Conv2d` in the backbone, neck, and detection head — approximately 95% of total YOLOv8n compute.

#### PSB — Partial Sum Buffer
Holds the INT32 running total across input-channel (K) tiles. A single output channel requires accumulating across all input channels; if they don't fit in one SA pass, the PSB adds each tile's result to the running total. Only releases the final INT32 sum to Requant when all K-tiles are exhausted.

#### Requant Pipeline
Converts INT32 PSB output to INT8 using per-channel scale factors computed offline during post-training quantization. Operation: `INT8_out = clip(round((INT32_acc × M) >> S), -128, 127)`. M and S simultaneously perform the fused BatchNorm scale. A BRAM-resident coefficient buffer holds one `(M, S)` pair per output channel; the VPU reads them sequentially as it walks the output tile.

#### 64-Lane VPU

| Stage | What it does |
|---|---|
| **① Act LUT** | 256-entry × 8-bit BRAM table. Uses the INT8 value from Requant as an array index and returns `SiLU(x)` in one cycle per lane. Reprogrammed before each layer to change activation function. A `LUT_BYPASS` mux passes the value through unchanged for layers with no activation (e.g. 1×1 linear projections). |
| **② Eltwise + MaxPool** | Saturating INT8 lane-wise add for C2f residual connections (residual tensor arrives directly from the Residual Bank, bypassing the LUT). Also handles SPPF's three cascaded 5×5 max-pool passes as a sliding-window max across 64 lanes. |
| **③ HREDUCE** | 4-stage in-lane binary reduction tree. Fires **once per frame** for DFL box decoding: computes max → subtract → exp (LUT) → sum → normalize → dot product with `[0..15]` to produce continuous box coordinates. Acts as a passthrough on all conv layers. |

---

## 3. ISA — NPU Sequencer Instructions

All instructions are 128-bit fixed-width, dispatched from the ARM via AXI-Lite into four unit FIFOs.

| Instruction | Unit | Description |
|---|---|---|
| `DMA_LOAD` | DMA | Fetch activation tile from DRAM to Act Bank. Args: base_addr, row_stride, tile dims, pad counts. |
| `DMA_STORE` | DMA | Write output tile from Output Bank to DRAM. |
| `WT_LOAD` | DMA | Prefetch weight tile from DRAM to Weight Bank. |
| `MATMUL` | SA | Fire systolic array for one K-tile. Args: act bank select, wt bank select, tile K/M/N dims. |
| `PSB_ACC` | PSB | Add current SA output into PSB running total. |
| `PSB_FLUSH` | PSB | Signal K-tiles complete; forward final INT32 sum to Requant. |
| `REQUANT` | Requant | Apply per-channel M·x>>S·clip to PSB output. Args: coeff buffer base address. |
| `LUT_LOAD` | VPU | Write 256 bytes into the Act LUT BRAM. Args: source address in DRAM. |
| `LUT_BYPASS` | VPU | Enable/disable the LUT bypass mux for the current layer. |
| `COEFF_LOAD` | Requant | Write (M, S) coefficient pairs into the per-channel BRAM. Args: source addr, channel count. |
| `SIMD_ACT` | VPU | Run LUT lookup across all 64 lanes for one output row. |
| `SIMD_ADD` | VPU | Saturating elementwise add of two INT8 tiles (residual + activated output). |
| `SIMD_MAXPOOL` | VPU | Sliding 5×5 max-pool across 64 lanes. Args: window size, stride. |
| `HREDUCE` | VPU | 4-stage horizontal tree reduction over 16-element groups. Args: op (max / sum / dot). |
| `SYNC` | Global | Insert a dependency barrier between two unit FIFOs. Stalls the downstream FIFO until the upstream one completes. |

---

## 4. Data Types

| Region | Type | Width |
|---|---|---|
| DRAM weights & activations | INT8 | 8-bit |
| SA accumulator / PSB | INT32 | 32-bit |
| Requant coefficients M | INT16 (fixed-point) | 16-bit |
| Requant shift S | UINT4 | 4-bit |
| Requant output | INT8 | 8-bit |
| VPU lanes | INT8 | 8-bit |
| Act LUT | 256 × INT8 | 8-bit |
| DFL output to ARM | INT8 (dequantized to fp32 on ARM) | 8-bit → fp32 |

---

## 5. On-Chip Memory Map

| Buffer | Size | Notes |
|---|---|---|
| Act Bank A | tile_H × tile_W × C bytes | Sized for largest single tile in YOLOv8n |
| Act Bank B | tile_H × tile_W × C bytes | Ping-pong partner |
| Weight Bank A | K × C × 3 × 3 bytes | Largest conv weight tile |
| Weight Bank B | K × C × 3 × 3 bytes | Ping-pong partner |
| Residual Bank | tile_H × tile_W × C bytes | C2f skip tensor |
| Output Bank | tile_H × tile_W × K bytes | VPU write-back |
| PSB | 16 × 16 × INT32 | One INT32 per SA output PE |
| Requant coeff buf | 512 × (M + S) | Worst case: 512 output channels |
| Act LUT BRAM | 256 × 8-bit = 256 B | Single block RAM |

---

## 6. ARM ↔ NPU Interface

- **AXI-Lite CSR**: ARM writes layer descriptors and instruction words to memory-mapped registers.
- **DMA**: `dma_alloc_coherent` allocates physically contiguous buffers for activation and weight tensors. The NPU DMA engine reads/writes these directly.
- **Completion interrupt**: One interrupt per frame fired when `DMA_STORE` of the final layer's output completes.
- **PyTorch integration**: `torch.library` custom op `npu::conv_bn_silu` wraps the driver call. The ARM dispatches a full layer sequence per op invocation.

---

## 7. TODO List

### 7.1 Quantization & Model Export
- [ ] Export YOLOv8n from PyTorch using `torch.export` or ONNX
- [ ] Run post-training quantization (PTQ) with representative COCO images
- [ ] Extract per-channel `(M, S)` scale/shift pairs for every Conv2d layer
- [ ] Fuse BatchNorm into Conv2d weights and bias offline
- [ ] Build per-layer quantization config file (JSON/YAML)
- [ ] Precompute SiLU LUT entries `[SiLU(dequant(i)) for i in range(-128, 128)]` and quantize to INT8
- [ ] Validate INT8 model accuracy vs fp32 baseline (target: <1.0 mAP drop)

### 7.2 RTL — 2D Strided DMA
- [ ] Design DMA descriptor register file (base_addr, row_stride, tile_w, tile_h, C, pad mask)
- [ ] Implement row-stride address generator with automatic gap-skip
- [ ] Implement zero-padding insertion state machine (suppress DRAM read, output zero word)
- [ ] Implement AXI4 master read/write channels
- [ ] Implement ping-pong bank select logic and handshake with SA
- [ ] Write testbench: verify correct tile extraction at image edges with padding
- [ ] Verify concurrent DMA fetch + SA compute (ping-pong timing)

### 7.3 RTL — SRAM Hub
- [ ] Instantiate Act Bank A/B (dual-port BRAM, one read port for SA, one write port for DMA)
- [ ] Instantiate Weight Bank A/B (same structure)
- [ ] Instantiate Residual Bank (read port wired directly to VPU eltwise, write port from DMA)
- [ ] Instantiate Output Bank (write port from VPU, read port for DMA_STORE)
- [ ] Implement bank-select mux and ping-pong swap control signals
- [ ] Verify no port conflicts: residual read and SA act read must be independent ports

### 7.4 RTL — Systolic Array 16×16
- [ ] Implement single INT8 PE: registered multiply-accumulate into INT32
- [ ] Tile 16×16 PE array with weight-stationary data path
- [ ] Implement activation skew-load FIFOs (depth = row index, one per column)
- [ ] Implement weight load phase: broadcast weights from Weight Bank to PEs
- [ ] Implement compute phase: stream activations, accumulate INT32
- [ ] Wire SA output (256 INT32 values) to PSB
- [ ] Confirm DSP48E2 dual-packing for INT8: two MACs per DSP (A[15:8]×B + A[7:0]×B)
- [ ] Write testbench: verify output against numpy reference for 3×3 and 1×1 conv tiles

### 7.5 RTL — PSB
- [ ] Implement 16×16 INT32 register bank (one accumulator per PE output)
- [ ] Implement K-tile accumulation: add new SA output into running total each `PSB_ACC`
- [ ] Implement flush: forward final INT32 values to Requant on `PSB_FLUSH`
- [ ] Implement zero-clear on flush for next layer readiness
- [ ] Write testbench: multi-tile accumulation matches reference

### 7.6 RTL — Requant Pipeline
- [ ] Implement per-channel coefficient BRAM (512 × {M: INT16, S: UINT4})
- [ ] Implement AXI-Lite write port for COEFF_LOAD from ARM
- [ ] Implement sequential read port: increment channel address each output cycle
- [ ] Implement multiply-shift pipeline: INT32 × INT16 → INT48, right-shift by S, round
- [ ] Implement saturating clip to [-128, 127]
- [ ] Write testbench: verify per-channel output matches software reference

### 7.7 RTL — VPU (64 lanes)
- [ ] Implement 64-lane datapath register file (INT8 per lane)
- [ ] Implement Act LUT BRAM (256 × 8-bit, one read port, one write port via AXI-Lite)
- [ ] Implement LUT_BYPASS mux: select between LUT output and passthrough
- [ ] Implement lane-wise saturating add for SIMD_ADD (residual path)
- [ ] Implement lane-wise max for SIMD_MAXPOOL with programmable window
- [ ] Implement HREDUCE: 4-stage binary tree reduction within 16-element lane groups
  - [ ] Stage 1: 16→8 (8 parallel adds)
  - [ ] Stage 2: 8→4
  - [ ] Stage 3: 4→2
  - [ ] Stage 4: 2→1 (scalar result per group)
- [ ] Implement exp LUT for HREDUCE softmax path (256 × INT8 → fixed-point exp)
- [ ] Implement dot-product with [0..15] for DFL weighted sum
- [ ] Write testbench: SiLU correctness, residual add saturation, HREDUCE softmax vs numpy

### 7.8 RTL — Sequencer
- [ ] Implement four instruction FIFOs: DMA, SA, PSB/Requant, VPU
- [ ] Implement 128-bit instruction decoder: opcode + field extraction
- [ ] Implement SYNC barrier: stall downstream FIFO until upstream done signal asserts
- [ ] Implement AXI-Lite instruction write interface (ARM pushes instructions into FIFOs)
- [ ] Implement completion interrupt: fire on final DMA_STORE done
- [ ] Write testbench: full single-layer dispatch sequence (DMA_LOAD → MATMUL × N → PSB_FLUSH → REQUANT → SIMD_ACT → SIMD_ADD → DMA_STORE)

### 7.9 Integration & Top-Level RTL
- [ ] Wire all blocks at top level: DMA ↔ SRAM Hub ↔ SA ↔ PSB ↔ Requant ↔ VPU
- [ ] Connect AXI-Lite slave to Zynq PS AXI master in Vivado block design
- [ ] Connect AXI4 DMA master to HP0 port (high-performance DDR port)
- [ ] Assign AXI-Lite CSR base address in device tree
- [ ] Run Vivado synthesis and check timing at 300 MHz
- [ ] Fix any timing violations (pipeline registers, DSP constraints)
- [ ] Run Vivado implementation and confirm resource utilization fits KR260

### 7.10 Verification
- [ ] Write full-layer cocotb testbench: feed real INT8 YOLOv8n Conv2d tile, compare output to PyTorch INT8 reference
- [ ] Verify padding correctness on all four image edges
- [ ] Verify K-tile accumulation across multiple PSB_ACC / PSB_FLUSH cycles
- [ ] Verify per-channel Requant matches PTQ reference values
- [ ] Verify SiLU LUT matches software reference across all 256 INT8 inputs
- [ ] Verify HREDUCE softmax output matches numpy softmax (floating-point tolerance)
- [ ] Verify residual add saturation at ±127 boundary
- [ ] Run ILA capture on hardware for a single layer dispatch

### 7.11 Linux Driver
- [ ] Write Linux char driver (`/dev/npu0`)
- [ ] Map AXI-Lite CSR region with `ioremap`
- [ ] Allocate DMA-coherent buffers with `dma_alloc_coherent` for act, weight, output tensors
- [ ] Implement `ioctl` interface: LOAD_WEIGHTS, DISPATCH_LAYER, WAIT_DONE
- [ ] Register interrupt handler for completion IRQ
- [ ] Write device tree node for NPU (reg, interrupts, compatible)
- [ ] Test driver with a simple memcpy kernel (no SA logic) before full integration

### 7.12 PyTorch Integration
- [ ] Register `torch.library` custom op: `npu::conv_bn_silu(input, weight, M, S, lut) -> Tensor`
- [ ] Implement op to: copy tensors into DMA buffers → write layer descriptor → wait on IRQ → return output tensor
- [ ] Register autograd passthrough (inference only, no backward needed)
- [ ] Write Python layer dispatch scheduler: iterate YOLOv8n graph, call NPU op for each Conv2d
- [ ] Benchmark end-to-end latency: preprocess → NPU → NMS

### 7.13 Bring-Up Sequence
- [ ] Flash bitstream to KR260 via Vivado Hardware Manager over Tailscale / JTAG
- [ ] Confirm AXI-Lite register read/write from ARM (devmem2 smoke test)
- [ ] Run single-layer dispatch: verify output SRAM contents via ILA
- [ ] Run full YOLOv8n inference on a single test image
- [ ] Compare NPU output vs PyTorch CPU INT8 reference (check mAP)
- [ ] Measure per-frame latency and throughput at 300 MHz
- [ ] Profile bottlenecks: DMA bandwidth, SA utilization, VPU idle time

---

## 8. Key Design Constraints

| Constraint | Value |
|---|---|
| Clock | 300 MHz (PL) |
| SA size | 16×16 PEs = 256 MACs/cycle |
| Target throughput | ~102 GOPS (INT8) |
| Max on-chip SRAM | Limited by KR260 BRAM budget — size tile banks accordingly |
| DMA bandwidth | HP0 port: up to 19.2 GB/s theoretical |
| INT8 accumulation | INT32 PSB, no intermediate overflow possible for YOLOv8n channel counts |
| Per-channel quant | Required — global scale collapses accuracy |
| Activation | SiLU via 256-entry LUT, reprogrammable |

---

*Document version: 1.0 — reflects INT8 systolic array + 64-lane VPU + no dedicated reduction tree design.*