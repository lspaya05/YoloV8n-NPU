# Instruction Set Architecture

## 3.1 Design Principles

- Fixed-width 128-bit instruction words — simplifies fetch alignment and FIFO sizing
- Opcode in the high byte `[127:120]` — sequencer decodes without full payload parse
- Unit ID in bits `[119:116]` — explicit routing to five per-unit command FIFOs
- Dependency flags always in bits `[115:112]` — uniform across all instruction types
- Remaining 112 bits are instruction-specific payload

---

## 3.2 Instruction Word Encoding

| Field | Bit Range | Description |
|-------|-----------|-------------|
| `opcode` | `[127:120]` | 8-bit opcode identifying the instruction type |
| `unit_id` | `[119:116]` | Target unit: 0=Sequencer, 1=DMA, 2=SA, 3=PSB, 4=Requant, 5=VPU |
| `dep_push_next` | `[115]` | Push done-token to downstream unit's RAW FIFO on completion |
| `dep_push_prev` | `[114]` | Push done-token to upstream unit's WAR FIFO on completion |
| `dep_pop_next` | `[113]` | Block until token arrives from upstream unit's RAW FIFO |
| `dep_pop_prev` | `[112]` | Block until token arrives from downstream unit's WAR FIFO |
| `payload` | `[111:0]` | 112-bit instruction-specific data |

> **Implementation note:** dep_flags bits are passed through the dispatch FIFO payload but are
> not currently decoded by individual dispatch modules (Dispatch_SA/PSB/REQ/VPU). Unit ordering
> is enforced by block-wrapper DepFIFO gating ("Option A"): each block wrapper masks
> `fifo_empty` to the dispatch FSM until upstream RAW/WAR token counts are non-zero, independent
> of the instruction word. dep_flags should still be encoded correctly in software for
> forward-compatibility when per-instruction decode is implemented.

---

## 3.3 Complete Instruction Table

| Instruction | Opcode | Unit | Description |
|-------------|--------|------|-------------|
| `CONFIG` | `0x01` | Sequencer | Load layer parameters into shadow registers: tile shape (M,N,K), conv stride, requant scale M/S base address, padding mode, activation type, pool size. |
| `FENCE` | `0x02` | Sequencer | Block until all units in a bitmask (bits `[7:0]` of payload) report completion. Used to synchronise pipeline stages at layer boundaries. Bitmask allows waiting on any combination of units simultaneously. |
| `DMA_LOAD` | `0x11` | DMA | 2D-strided fetch of INT8 activation tile from DDR4 into Act Bank. Descriptor: base_addr, row_stride, tile_w, tile_h, ch_count, pad counts. Zero-padding inserted in HW. |
| `DMA_STORE` | `0x12` | DMA | Burst-write INT8 Output Bank to DDR4. Used after VPU completes post-processing. |
| `WT_LOAD` | `0x10` | DMA | Prefetch INT8 weight tile from DDR4 into inactive Weight Bank (A or B). Runs concurrently with SA compute on active Weight Bank. |
| `UPSAMPLE` | `0x13` | DMA | 2× nearest-neighbor upsample. Reads source tensor from DDR4, emits each pixel 2×2 times into SRAM. Handles FPN neck upsample at layers 10 and 13. |
| `CONCAT` | `0x14` | DMA | 2D-strided gather: reads from two DDR4 base addresses (src_a, src_b) and interleaves channels into contiguous SRAM block. Used for all five FPN/PAN concat operations. |
| `COEFF_LOAD` | `0x15` | DMA | Write per-channel (M: INT16, S: UINT4) requant coefficient pairs from DDR4 into the Requant pipeline BRAM. Args: src DDR4 addr, channel count. |
| `MATMUL` | `0x20` | SA | Execute one 16×16 INT8 matrix multiply tile. Reads from Act Bank and Weight Bank; outputs INT32 results. PSB_ACC must immediately follow to accumulate. |
| `PSB_ACC` | `0x21` | PSB | Add current SA output into PSB INT32 running total. Issues after every MATMUL. No SRAM access. |
| `PSB_FLUSH` | `0x22` | PSB | Signal K-tiles complete. Forward final INT32 values from PSB to Requant pipeline input. Zero-clear PSB for next layer. |
| `REQUANT` | `0x30` | Requant | Apply per-channel (M, S) multiply-shift-clip to PSB output: `clip(round((INT32×M)>>S), −128, 127)`. Reads (M,S) from coefficient BRAM sequentially per channel. |
| `LUT_LOAD` | `0x31` | VPU | Write 256 bytes of LUT data (one per INT8 input index) into Act LUT BRAM. Args: src DDR4 address. Must issue before SIMD_ACT on a new layer. |
| `LUT_BYPASS` | `0x32` | VPU | Enable or disable the LUT bypass mux. When enabled, Act LUT output is replaced by passthrough (for linear layers with no activation function). |
| `SIMD_ACT` | `0x33` | VPU | Run Act LUT lookup across all 64 lanes for one output row. INT8 input → LUT → INT8 output. Single-cycle throughput per lane after LUT_LOAD. |
| `RELU` | `0x34` | VPU | Apply ReLU: clamp INT8 values at zero. Simple per-lane comparator. No DSP/LUT required. For future YOLOv8 variants. |
| `ELEW_ADD` | `0x35` | VPU | Elementwise saturating INT8 add. Reads activated output and Residual Bank. Optional 1-bit arithmetic right shift to prevent overflow (controlled by CONFIG). For C2f residual connections. |
| `ELEW_MUL` | `0x36` | VPU | Elementwise INT8 multiply. INT8×INT8→INT16 intermediate, requantized to INT8 using layer M/S. Rarely used in YOLOv8n; included for future model support. |
| `MAXPOOL` | `0x37` | VPU | Sliding-window maximum per lane. 3×3 or 5×5 kernel (set via CONFIG pool_size bit). SPPF three-stage 5×5 pooling at layer 9. Tournament comparator tree: 25 inputs, 5 levels. |
| `HREDUCE` | `0x38` | VPU | 4-stage binary reduction tree within 16-element lane groups. Fires once per frame for DFL box decoding: max → subtract → exp LUT → sum → dot·[0..15] → continuous box coordinates. Passthrough (no-op) on all conv layers. |

---

## 3.4 Sample Microcode — One Conv+SiLU Layer

Full instruction sequence for a 3×3 conv, 128 input channels, 64 output channels, 40×40 spatial tile. BN pre-folded. 2D strided DMA fetches im2col layout natively.

```asm
COEFF_LOAD  src=DDR4:0x0034_0000  ch=64               ; per-channel (M, S)
LUT_LOAD    src=DDR4:0x0035_0000                       ; SiLU LUT for this layer
WT_LOAD     src=DDR4:0x0400_0000  dst=Weight_BankB     ; prefetch K=0..15 weights
DMA_LOAD    base=DDR4:0x0200_0000  row_stride=...      ; activation tile K=0
FENCE       wait=[DMA_done, WT_done]
MATMUL      act=ActBank_A  wt=WeightBank_B             ; K tile 0
PSB_ACC                                                 ; accumulate into PSB
WT_LOAD     src=DDR4:0x0400_0100  dst=Weight_BankA     ; prefetch K=16..31
DMA_LOAD    base=DDR4:0x0200_0100  row_stride=...      ; activation tile K=1
... (repeat for K=32..127, 8 tiles total)
MATMUL      act=ActBank_A  wt=WeightBank_B             ; final K tile
PSB_ACC
PSB_FLUSH                                               ; forward INT32 to Requant
FENCE       wait=[PSB_done]
REQUANT                                                  ; per-channel M/S clip
SIMD_ACT                                                 ; SiLU LUT lookup
DMA_STORE   src=OutputBank  dst=DDR4:0x0300_0000
```
