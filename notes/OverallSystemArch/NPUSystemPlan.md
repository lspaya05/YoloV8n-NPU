# Complete NPU System Plan for MNIST

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOST SYSTEM (PS)                             │
│                                                                     │
│  Python/JAX → XLA Compiler → C++ Driver → /dev/xdma0              │
│                                                                     │
│  ARM Cortex-A53 @ 1.3GHz                                           │
│  - Compiles HLO graph to instruction buffer at load time           │
│  - Writes DMA descriptors to DDR                                   │
│  - Kicks off NPU via AXI-lite register write                       │
│  - Waits on interrupt, reads result                                │
└────────────────────────────┬────────────────────────────────────────┘
                             │ AXI4 HP (high performance) port
                             │ 128-bit wide @ 300MHz
                             │ ~38 GB/s theoretical
┌────────────────────────────▼────────────────────────────────────────┐
│                        NPU (PL Fabric)                              │
│                                                                     │
│  ┌─────────────┐    ┌──────────────────────────────────────────┐   │
│  │  AXI-Lite   │    │           Instruction Sequencer          │   │
│  │  Control    │───▶│  FIFO → Decode → Scoreboard → Dispatch  │   │
│  │  Registers  │    └──────┬──────┬──────┬──────┬──────┬──────┘   │
│  └─────────────┘           │      │      │      │      │           │
│                            │      │      │      │      │           │
│               ┌────────────▼┐ ┌───▼───┐ ┌▼────┐ ┌────▼┐ ┌───▼──┐ │
│               │   Systolic  │ │  VPU  │ │ LUT │ │ Red │ │ DMA  │ │
│               │    Array    │ │       │ │Unit │ │Tree │ │Engine│ │
│               │   16×16     │ │64-wide│ │     │ │     │ │      │ │
│               └──────┬──────┘ └───┬───┘ └──┬──┘ └──┬──┘ └───┬──┘ │
│                      │            │         │        │         │   │
│               ┌───────────────────────────────────────────────▼──┐ │
│               │          On-Chip SRAM (Double Buffered)          │ │
│               │    Weight Buffers A/B    Activation Buffers A/B  │ │
│               │         256KB BRAM            512KB URAM         │ │
│               └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                             │ DDR4
                        ┌────▼────┐
                        │  PS DDR │
                        │   4GB   │
                        │Weights  │
                        │Activates│
                        │Instrs   │
                        └─────────┘
```

---

## Block 1: Systolic Array

### Architecture
```
Weight-stationary dataflow. Weights preloaded into PEs,
inputs flow left→right, partial sums flow top→bottom.

        col0    col1    col2  ...  col15
row0  ┌──────┬──────┬──────┬───┬──────┐
      │ PE   │ PE   │ PE   │   │ PE   │  ← input[row0] flows right
row1  ├──────┼──────┼──────┼───┼──────┤
      │ PE   │ PE   │ PE   │   │ PE   │  ← input[row1] flows right
...   │  .   │  .   │  .   │   │  .   │
row15 ├──────┼──────┼──────┼───┼──────┤
      │ PE   │ PE   │ PE   │   │ PE   │
      └──────┴──────┴──────┴───┴──────┘
         ↓      ↓      ↓          ↓
      accum  accum  accum      accum     ← partial sums drain down
      col0   col1   col2       col15
```

### Single PE Design
```systemverilog
module pe (
    input  logic        clk, rst,
    input  logic        weight_load,     // preload phase
    input  logic [7:0]  weight_in,       // weight flowing in during load
    input  logic [7:0]  data_in,         // activation flowing left→right
    input  logic [31:0] acc_in,          // partial sum flowing top→bottom
    output logic [7:0]  data_out,        // activation passed to right neighbor
    output logic [31:0] acc_out,         // partial sum passed to down neighbor
    output logic [7:0]  weight_out       // weight passed right during load
);
    logic [7:0]  weight_reg;
    logic [31:0] acc_reg;

    always_ff @(posedge clk) begin
        if (weight_load) begin
            weight_reg <= weight_in;
            weight_out <= weight_reg;  // shift chain during load
        end else begin
            acc_reg  <= acc_in + ({{24{data_in[7]}}, data_in}
                               *  {{24{weight_reg[7]}}, weight_reg});
            data_out <= data_in;
            acc_out  <= acc_reg;
        end
    end
endmodule
```

### Sub-Components and Pipeline Stages

**Weight Loader**
```
Purpose: Shift 16×16 weight tile into PE array before GEMM
Method:  Diagonal systolic load — each row loads one cycle later
         than the previous to align with data flow timing
Latency: 16 + 16 = 32 cycles to fully load a 16×16 tile
BRAM:    Reads from weight buffer, one row per cycle
```

**Input Skew Buffer**
```
Purpose: Stagger input rows so row N starts N cycles after row 0
         This ensures input[row][col] meets weight[row][col] in
         the correct PE at the correct time

Without skew:  all rows arrive cycle 0 → wrong PE pairing
With skew:
  row 0:  ████████████████  (starts cycle 0)
  row 1:  ░████████████████ (starts cycle 1)
  row 2:  ░░████████████████(starts cycle 2)
  ...
  row 15: ░░░░░░░░░░░░░░░████████████████

Implementation: 16 shift registers of depth 0,1,2,...,15
                feeding the 16 rows of the array
Latency added:  15 cycles (depth of deepest shift register)
```

**Output Drain**
```
Purpose: Read 16 accumulator columns after computation completes
Timing:  Results appear at bottom of array staggered by column
         (same skew effect as input, just inverted)
Implementation: 16 shift registers de-skewing the outputs
Output rate: 16 INT32 values per cycle once pipeline is full
```

**Tile Loop Controller**
```
Purpose: Handle matrices larger than 16×16 by tiling
Example: 512×512 GEMM = (512/16)² = 1024 tile iterations

State machine:
  IDLE → LOAD_WEIGHTS → COMPUTE → ACCUMULATE → (next tile or DONE)

Registers:
  tile_m, tile_n, tile_k  : current tile position
  total_M, total_N, total_K: total tile counts from instruction
  accumulate_flag          : whether to add to existing output
                             or overwrite (first K tile = overwrite,
                             subsequent = accumulate)
```

**Pipeline depth: 5 stages**
```
Stage 1: Address generation (weight + input buffer read addr)
Stage 2: BRAM read (weight tile, input tile)
Stage 3: Skew buffer (input staggering)
Stage 4: PE array compute (MAC, 1 cycle per element)
Stage 5: Output de-skew + write to activation buffer
Total latency: ~35 cycles for first result of a 16×16 tile
Throughput:    256 MACs/cycle once pipeline full
```

**DSP usage:** 256 DSP58E2 (one per PE, INT8×INT8→INT32)  
**BRAM usage:** 8 BRAM18 for weight double buffer  
**LUT usage:** ~4000 LUTs for controllers and skew buffers

---

## Block 2: Vector Processing Unit

### Architecture
```
64 parallel lanes, each operating on one INT8 element.
All lanes execute the same operation (SIMD).

Input Bus A (64 × INT8 = 512 bits) ──┐
Input Bus B (64 × INT8 = 512 bits) ──┼──▶ 64 lanes ──▶ Output (64 × INT8)
Operation select (4 bits) ───────────┘

One lane:
┌─────────────────────────────┐
│  a[7:0]        b[7:0]       │
│     ↓              ↓        │
│  ┌──▼──────────────▼──────┐ │
│  │    Operation MUX       │ │
│  │  ADD / SUB / MUL /     │ │
│  │  MAX / MIN / AND /     │ │
│  │  OR  / XOR / SEL       │ │
│  └──────────┬─────────────┘ │
│             ↓               │
│  ┌──────────▼─────────────┐ │
│  │  Saturation + Clip     │ │
│  │  INT8 range [-128,127] │ │
│  └──────────┬─────────────┘ │
│             ↓               │
│          result[7:0]        │
└─────────────────────────────┘
```

### Sub-Components

**INT8 Lane (×64)**
```
Operations per lane:
  ADD  : a + b, saturate to INT8
  SUB  : a - b, saturate to INT8
  MUL  : (a * b) >> 8, keeps INT8 range
  MAX  : a > b ? a : b        ← ReLU = MAX(input, 0)
  MIN  : a < b ? a : b
  SEL  : mask ? a : b         ← masked select
  ABS  : |a|
  NEG  : -a

Each lane: ~6 LUTs + 1 DSP for MUL
Total 64 lanes: ~384 LUTs + 64 DSPs
```

**INT32 Bias Lane (×16, wider)**
```
Purpose: Add INT32 bias to INT32 accumulator output
         from systolic array BEFORE requantization
Width:   16 lanes × INT32 (handles one output row at a time)
Operation: acc[i] + bias[i] → INT32 result
```

**Requantization Unit**
```
Purpose:  INT32 accumulator → INT8 activation
          This happens after every GEMM layer

Pipeline:
  INT32 input
      ↓
  × scale_factor (FP16 multiply, implemented in DSP)
      ↓
  + zero_point (INT32 offset)
      ↓
  round to nearest integer
      ↓
  clamp to [-128, 127]
      ↓
  cast to INT8

Why this exists: GEMM outputs 32-bit accumulators.
  INT8 × INT8 → INT32 (to avoid overflow during accumulation).
  Each layer needs to scale back to INT8 for the next layer.
  The scale factor is computed during quantization-aware training
  and stored as a per-layer constant.

Latency: 4 cycles
DSPs: 16 (one per output lane for FP16 multiply)
```

**Zero Register**
```
A permanent buffer initialized to all-zeros.
ReLU is implemented as: VMAX(input_buf, zero_buf, count)
No special ReLU instruction needed — reuses VMAX.
Costs: 1 BRAM18, saves an opcode.
```

**Pipeline depth: 2 stages**
```
Stage 1: Read input buffers, select operation
Stage 2: Execute, saturate, write output buffer
Throughput: 64 INT8 elements per cycle
For 512-element vector: 8 cycles
```

**DSP usage:** 64 (INT8 lanes) + 16 (bias) + 16 (requant) = 96 DSPs  
**LUT usage:** ~6000 LUTs

---

## Block 3: Reduction Tree

### Architecture
```
6-stage binary tree, 64 inputs → 1 output per tree.
Multiple trees run in parallel for vectorized reduction.

Stage 0 (input):  [e0  e1  e2  e3  e4  e5 ... e62 e63]
                    ↓↑  ↓↑  ↓↑  ↓↑  ↓↑  ↓↑       ↓↑
Stage 1 (32 ops): [op(e0,e1) op(e2,e3) ... op(e62,e63)]
                         ↓↑       ↓↑               ↓↑
Stage 2 (16 ops): [op(s1_0,s1_1) ...  op(s1_30,s1_31)]
Stage 3 (8 ops)
Stage 4 (4 ops)
Stage 5 (2 ops)
Stage 6 (1 op) :  [final_result]

op = ADD (for SUM) or MAX (for MaxPool/global max)
     selected by control register, same hardware
```

### Sub-Components

**Operator Select MUX (per node)**
```systemverilog
always_comb begin
    case (op_select)
        SUM: result = a + b;           // overflow-safe INT32
        MAX: result = (a > b) ? a : b;
        MIN: result = (a < b) ? a : b;
        default: result = a;
    endcase
end
```

**Multi-Cycle Accumulator**
```
Purpose: Reduce tensors larger than 64 elements
Method:  Seed accumulator with first 64-element chunk result,
         then accumulate subsequent chunks into it

Example: Reduce 512-element vector
  Cycle 0-1:  reduce elements [0:63]   → partial_0
  Cycle 2-3:  reduce elements [64:127] → partial_1
  ...
  Cycle 14-15: reduce elements [448:511] → partial_7
  Final:       op(partial_0..7) in accumulator register

The accumulator is just a register with a feedback MUX:
  acc = (first_chunk) ? tree_output : op(acc, tree_output)
```

**ReduceWindow Controller (for MaxPool)**
```
Purpose: Apply 2×2 max over spatial dimensions
         for pooling layers in CNN

For a [32, 13, 13] feature map with 2×2 pool, stride 2:
  Output shape: [32, 6, 6]
  For each output position [c, oh, ow]:
    Feed tree: input[c, oh*2, ow*2],   input[c, oh*2,   ow*2+1],
               input[c, oh*2+1, ow*2], input[c, oh*2+1, ow*2+1]
    Take MAX

Controller is a 3-level nested loop counter:
  for c  in range(32):
    for oh in range(6):
      for ow in range(6):
        → compute 4 addresses, feed tree, store result

Address generation logic: ~500 LUTs
```

**Pipeline depth: 2 stages**
```
Stage 1: Read 64 elements from activation buffer
Stage 2: 6-level tree computes, write scalar result
Throughput: 1 reduction per 2 cycles (64 elements)
            For softmax on 10-class output: 1 cycle (trivial)
            For global pool on 512 channels: 8 cycles per channel
```

**DSP usage:** 32 (adder tree nodes for SUM mode)  
**LUT usage:** ~2000 LUTs

---

## Block 4: On-Chip SRAM with Double Buffering

### Memory Map
```
Total on-chip memory budget for KR260:
  BRAM: 144 × BRAM36 = 5,184 Kbits = 648 KB
  URAM: 64  × URAM288 = 18,432 Kbits = 2,304 KB

Allocation:
┌─────────────────────────────────────────────────┐
│  Weight Buffer A    128 KB  (BRAM)              │
│  Weight Buffer B    128 KB  (BRAM)              │
├─────────────────────────────────────────────────┤
│  Activation Buffer A  256 KB  (URAM)            │
│  Activation Buffer B  256 KB  (URAM)            │
├─────────────────────────────────────────────────┤
│  Bias Buffer          16 KB   (BRAM)            │
│  Zero Buffer          4 KB    (BRAM)            │
│  Instruction FIFO     4 KB    (BRAM)            │
│  Scratchpad           64 KB   (BRAM)            │
└─────────────────────────────────────────────────┘

Buffer IDs (referenced by ISA):
  0x00 = Weight Buffer A
  0x01 = Weight Buffer B
  0x02 = Activation Buffer A
  0x03 = Activation Buffer B
  0x04 = Bias Buffer
  0x05 = Zero Buffer
  0x06 = Scratchpad
  0x07-0xFF = reserved for expansion
```

### Banking Structure
```
Each buffer split into 8 banks, XOR-interleaved:
  bank = address[3:1]  (bits 3:1 of element address)

Benefits:
  Sequential access (stride 1): hits different banks every cycle
  → no stall
  Stride-8 access: all hits same bank → 8-cycle stall
  → acceptable for our access patterns

Port allocation:
  Bank has 2 read ports + 1 write port (true dual-port BRAM)
  Port A → Systolic array (read weights / write output)
  Port B → VPU / Reduction / DMA (read/write activations)
  Arbiter handles conflicts (rare with good instruction scheduling)
```

### Double Buffer Controller
```
State machine (4 states):

  ┌─────────────────────────────────────────────────┐
  │                                                 │
  │  LOAD_A_COMPUTE_B ──→ SWAP ──→ LOAD_B_COMPUTE_A│
  │         ↑                              │        │
  │         └──────────── SWAP ←───────────┘        │
  │                                                 │
  └─────────────────────────────────────────────────┘

Transition condition:
  SWAP fires when BOTH:
    dma_done_flag = 1   (DMA finished loading next buffer)
    compute_done_flag = 1 (current compute finished)

  Whichever finishes first waits for the other.
  This is what hides DDR latency — compute and load overlap.

Signals exposed to sequencer:
  buffer_ready[A] : activation buffer A has valid data
  buffer_ready[B] : activation buffer B has valid data
  weight_ready[A] : weight buffer A has valid data
  weight_ready[B] : weight buffer B has valid data
```

**BRAM usage:** 96 BRAM36 (weights + bias + misc)  
**URAM usage:** 32 URAM288 (activations)

---

## Block 5: Instruction Sequencer + AXI Interface

### AXI-Lite Register Map
```
Offset  Register         Access  Description
──────────────────────────────────────────────────────
0x00    CTRL             WO      bit[0]=START, bit[1]=RESET
0x04    STATUS           RO      bit[0]=BUSY, bit[1]=DONE,
                                 bit[2]=ERROR
0x08    INSTR_ADDR_LO    WO      Lower 32 bits of instruction
                                 buffer address in DDR
0x0C    INSTR_ADDR_HI    WO      Upper 32 bits (for >4GB addrs)
0x10    INSTR_COUNT      WO      Number of 64-bit instructions
0x14    ERROR_CODE       RO      Error type if STATUS.ERROR=1
0x18    CYCLE_COUNT_LO   RO      Cycles elapsed (perf counter)
0x1C    CYCLE_COUNT_HI   RO      Upper 32 bits of cycle count
0x20    UNIT_STATUS      RO      bits[4:0] = busy flags per unit
0x24    VERSION          RO      Hardware version register
                                 [31:16]=major [15:0]=minor
0x28-   reserved                 Future expansion
0xFF
```

### Sequencer Pipeline
```
5-stage sequencer pipeline:

Stage 1: FETCH
  Read next 64-bit instruction from instruction FIFO
  FIFO is pre-loaded from DDR by DMA at START
  Stall if FIFO empty (shouldn't happen with proper prefetch)

Stage 2: DECODE
  Parse opcode field [63:56]
  Determine target unit
  Extract operand fields
  Detect if instruction is a SYNC/FENCE (special handling)

Stage 3: HAZARD CHECK
  Scoreboard lookup:
    For each input buffer referenced by instruction,
    check if any busy unit is currently writing to it
    If conflict: stall until writing unit clears its busy bit
  This is the key correctness mechanism

Stage 4: ISSUE
  Assert valid signal to target unit
  Write decoded fields to unit's input registers
  Set unit's scoreboard bit to BUSY

Stage 5: WRITEBACK
  Monitor unit done signals
  Clear scoreboard bits when units complete
  Handle DONE instruction (fire interrupt)
```

### Scoreboard
```
5-bit register, one bit per unit:
  bit 0: DMA Engine
  bit 1: Systolic Array
  bit 2: VPU
  bit 3: LUT Unit
  bit 4: Reduction Tree

Per-buffer write tracking table:
  16 entries (one per buffer ID)
  Each entry: which_unit_is_writing (3 bits), valid (1 bit)

Hazard detection logic:
  For instruction referencing buffers X, Y, Z as inputs:
    if write_table[X].valid || write_table[Y].valid: STALL
  For instruction writing to buffer W:
    write_table[W] = {issuing_unit, valid=1}
  When unit done:
    clear all write_table entries for that unit

This handles RAW (Read After Write) hazards automatically.
WAW and WAR hazards: handled by construction
  (driver never reuses a buffer until it's consumed)
```

---

## The ISA: Final Specification

### Encoding Philosophy
```
63      56 55    48 47   40 39   32 31             0
┌──────────┬─────────┬───────┬───────┬─────────────┐
│  opcode  │  flags  │  dst  │  src1 │  src2/imm   │
│  8 bits  │  8 bits │ 8 bits│ 8 bits│   32 bits   │
└──────────┴─────────┴───────┴───────┴─────────────┘

Opcode space allocation (designed for expansion):
  0x00-0x0F : Memory / DMA operations      (16 slots, using 2)
  0x10-0x1F : Systolic array operations    (16 slots, using 2)
  0x20-0x2F : Vector operations            (16 slots, using 7)
  0x30-0x3F : Transcendental operations    (16 slots, using 1)
  0x40-0x4F : Reduction operations         (16 slots, using 2)
  0x50-0x5F : Synchronization / control    (16 slots, using 3)
  0x60-0xEF : Reserved for future blocks   (144 slots)
  0xF0-0xFE : Debug / profiling            (15 slots)
  0xFF      : DONE                         (1 slot, always last)
```

### Complete Instruction Definitions

**Memory Group (0x00-0x0F)**
```
LOAD_DESC  opcode=0x00
┌──────────┬─────────┬───────┬───────┬─────────────────────────┐
│   0x00   │  flags  │  0x00 │  0x00 │  desc_addr[31:0]        │
└──────────┴─────────┴───────┴───────┴─────────────────────────┘
flags[0]: 0=weight buffer dest, 1=activation buffer dest
flags[1]: 0=use buffer A,       1=use buffer B
flags[2]: 0=blocking,           1=non-blocking (overlap with compute)
desc_addr: 32-bit DDR address of DMA descriptor struct

DMA Descriptor struct (lives in DDR, not in instruction):
  typedef struct {
      uint64_t src_addr;        // DDR source
      uint8_t  dst_buf_id;      // on-chip buffer ID
      uint32_t rows;            // number of rows
      uint32_t cols;            // number of cols
      uint32_t src_row_stride;  // bytes between rows in DDR
                                // (enables strided/transposed loads)
      uint32_t dst_row_stride;  // bytes between rows on-chip
  } DMADescriptor;

STORE_DESC  opcode=0x01
┌──────────┬─────────┬───────┬───────┬─────────────────────────┐
│   0x01   │  flags  │  0x00 │  0x00 │  desc_addr[31:0]        │
└──────────┴─────────┴───────┴───────┴─────────────────────────┘
Same structure, direction reversed (on-chip → DDR)
```

**Systolic Array Group (0x10-0x1F)**
```
GEMM  opcode=0x10
┌──────────┬─────────┬───────┬───────┬────────┬────────┬───────┐
│   0x10   │  flags  │dst_buf│wgt_buf│inp_buf │  imm   │       │
│          │         │       │       │  8b    │M(8)N(8)│ K(8)  │
└──────────┴─────────┴───────┴───────┴────────┴────────┴───────┘
flags[0]: accumulate (add to dst, don't overwrite — for K tiling)
flags[1]: fuse_relu  (apply ReLU inline after GEMM)
flags[2]: fuse_bias  (add bias_buf after GEMM, before relu)
flags[3]: output_int32 (keep INT32 output, skip requant)
M, N, K: tile counts (actual dim = value × 16)
         M=tiles in output rows
         N=tiles in output cols
         K=tiles in contraction dimension

CONV  opcode=0x11
┌──────────┬─────────┬───────┬───────┬─────────────────────────┐
│   0x11   │  flags  │dst_buf│wgt_buf│  inp_buf(8) + conv_desc │
│          │         │       │       │  addr(24)               │
└──────────┴─────────┴───────┴───────┴─────────────────────────┘
flags[0]: fuse_relu
flags[1]: fuse_bias
flags[2]: depthwise (depthwise conv for MobileNet etc)
conv_desc: 24-bit address of conv parameter block in scratchpad:
  typedef struct {
      uint8_t  N, C, H, W;      // input shape
      uint8_t  K, R, S;         // filters, kernel H, kernel W
      uint8_t  pad_h, pad_w;
      uint8_t  stride_h, stride_w;
      uint8_t  dilation_h, dilation_w;  // future use
  } ConvDesc;
```

**Vector Group (0x20-0x2F)**
```
VADD   opcode=0x20
VSUB   opcode=0x21
VMUL   opcode=0x22
VMAX   opcode=0x23  ← ReLU = VMAX(src, zero_buf)
VMIN   opcode=0x24
VSEL   opcode=0x25
VABS   opcode=0x26

All vector ops share encoding:
┌──────────┬─────────┬───────┬───────┬──────────┬──────────────┐
│  0x2x    │  flags  │dst_buf│src1_b │  src2_b  │  count(16)   │
│          │         │       │       │   (8b)   │              │
└──────────┴─────────┴───────┴───────┴──────────┴──────────────┘
flags[0]: saturate output to INT8 range
flags[1]: treat inputs as INT32 (for bias add before requant)
count: number of elements (up to 65535)

VSCALE  opcode=0x27  (scalar broadcast multiply)
┌──────────┬─────────┬───────┬───────┬────────────────────────┐
│   0x27   │  flags  │dst_buf│src_buf│scale_fp16(16) count(16)│
└──────────┴─────────┴───────┴───────┴────────────────────────┘

REQUANT opcode=0x28  (INT32 → INT8)
┌──────────┬─────────┬───────┬───────┬────────────────────────┐
│   0x28   │  flags  │dst_buf│src_buf│scale_fp16(16) count(16)│
└──────────┴─────────┴───────┴───────┴────────────────────────┘
flags[0]: signed output (default) vs unsigned
flags[1]: round half up vs round half to even
```

**Transcendental Group (0x30-0x3F)**
```
VLUT  opcode=0x30
┌──────────┬─────────┬───────┬───────┬───────────┬────────────┐
│   0x30   │  func   │dst_buf│src_buf│  reserved │  count(16) │
└──────────┴─────────┴───────┴───────┴───────────┴────────────┘
func (flags field used as function select):
  0x00: EXP      e^x
  0x01: LOG      ln(x)
  0x02: TANH     tanh(x)
  0x03: SIGMOID  1/(1+e^-x)
  0x04: SQRT     √x
  0x05: RSQRT    1/√x
  0x06: GELU     x·Φ(x)
  0x07: RCP      1/x
  0x08-0xFF: reserved for additional functions
```

**Reduction Group (0x40-0x4F)**
```
REDUCE  opcode=0x40
┌──────────┬─────────┬───────┬───────┬──────────┬─────────────┐
│   0x40   │op│axis  │dst_buf│src_buf│ outer(16)│  inner(16)  │
└──────────┴─────────┴───────┴───────┴──────────┴─────────────┘
op (bits [7:4] of flags):   0=SUM, 1=MAX, 2=MIN, 3=MEAN
axis (bits [3:0] of flags): 0=reduce along dim0, 1=reduce along dim1
outer: number of independent reductions to perform
inner: number of elements per reduction
Example: reduce [64,10] along axis=1
  outer=64, inner=10 → 64 scalar outputs

REDUCEWIN  opcode=0x41  (pooling)
┌──────────┬─────────┬───────┬───────┬───────────────────────┐
│   0x41   │  flags  │dst_buf│src_buf│kH(4)kW(4)sH(4)sW(4)  │
│          │         │       │       │H(8) W(8) C(8) pad(8)  │
└──────────┴─────────┴───────┴───────┴───────────────────────┘
flags[0]: op select (0=MAX, 1=AVG)
flags[1]: ceil_mode for output size calculation
kH,kW: kernel height/width (4 bits each, max 15×15)
sH,sW: stride height/width
H,W,C: input spatial dimensions and channels
pad:   symmetric padding
```

**Control Group (0x50-0x5F)**
```
SYNC  opcode=0x50
┌──────────┬─────────┬──────────────────────────────────────┐
│   0x50   │  mask   │  0x000000000000                      │
└──────────┴─────────┴──────────────────────────────────────┘
mask = unit_busy_flags to wait for:
  bit 0: wait for DMA
  bit 1: wait for Systolic Array
  bit 2: wait for VPU
  bit 3: wait for LUT Unit
  bit 4: wait for Reduction Tree
  bits 5-7: reserved for future units

FENCE  opcode=0x51  (wait for ALL units)
┌──────────┬──────────────────────────────────────────────┐
│   0x51   │  0x00000000000000                            │
└──────────┴──────────────────────────────────────────────┘

NOP    opcode=0x52
┌──────────┬──────────────────────────────────────────────┐
│   0x52   │  0x00000000000000                            │
└──────────┴──────────────────────────────────────────────┘
Used for pipeline alignment and timing padding

DONE   opcode=0xFF
┌──────────┬─────────┬──────────────────────────────────┐
│   0xFF   │  flags  │  status_code(32)                 │
└──────────┴─────────┴──────────────────────────────────┘
flags[0]: fire interrupt to CPU
flags[1]: write status_code to AXI-lite STATUS register
flags[2]: write cycle count to AXI-lite perf counters
status_code: user-defined value readable by CPU driver
```

---

## MNIST Execution Trace

To make this concrete, here is the full instruction stream the C++ driver would generate for one MNIST inference pass:

```asm
; ── Load first conv weights (3×3×1×32 = 288 bytes) ──
LOAD_DESC  desc=&weight_desc_0     ; DMA: DDR→weight_buf_A, non-blocking
LOAD_DESC  desc=&input_desc        ; DMA: DDR→activation_buf_A (28×28 image)
SYNC       mask=DMA                ; wait for both loads

; ── Conv Layer 1: [1,28,28] → [32,26,26] ──
CONV       dst=act_B, wgt=wgt_A, inp=act_A, flags=fuse_bias|fuse_relu
           conv_desc=&conv_desc_0  ; 3×3, 32 filters, stride=1, pad=0
; Internally expands to: im2col + GEMM tiles + bias + relu + requant

; ── Prefetch conv2 weights while MaxPool runs ──
LOAD_DESC  desc=&weight_desc_1     ; DMA: DDR→weight_buf_B, non-blocking

SYNC       mask=GEMM               ; wait for conv1

; ── MaxPool: [32,26,26] → [32,13,13] ──
REDUCEWIN  dst=act_A, src=act_B, op=MAX, kH=2, kW=2, sH=2, sW=2
           H=26, W=26, C=32

SYNC       mask=REDUCE|DMA         ; wait for pool AND weight prefetch

; ── Conv Layer 2: [32,13,13] → [64,11,11] ──
CONV       dst=act_B, wgt=wgt_B, inp=act_A, flags=fuse_bias|fuse_relu
           conv_desc=&conv_desc_1  ; 3×3, 64 filters

LOAD_DESC  desc=&weight_desc_2     ; prefetch dense layer weights
SYNC       mask=GEMM

; ── MaxPool: [64,11,11] → [64,5,5] ──
REDUCEWIN  dst=act_A, src=act_B, op=MAX, kH=2, kW=2, sH=2, sW=2
           H=11, W=11, C=64

SYNC       mask=REDUCE|DMA

; ── Flatten: [64,5,5] → [1600] ──
; (zero-copy, just a reshape — no instruction needed,
;  handled by adjusting buffer view in next GEMM descriptor)

; ── Dense Layer 1: [1600] → [128] ──
GEMM       dst=act_B, wgt=wgt_A, inp=act_A, flags=fuse_bias|fuse_relu
           M=1, N=8, K=100   ; 1×128 output, tiles of 16

LOAD_DESC  desc=&weight_desc_3     ; prefetch final dense weights
SYNC       mask=GEMM|DMA

; ── Dense Layer 2: [128] → [10] ──
GEMM       dst=act_A, wgt=wgt_B, inp=act_B, flags=fuse_bias
           M=1, N=1, K=8     ; 1×10 output (padded to 1×16 tile)

SYNC       mask=GEMM

; ── Softmax: [10] → [10] probabilities ──
REDUCE     dst=act_B, src=act_A, op=MAX, axis=1, outer=1, inner=10
SYNC       mask=REDUCE
VSUB       dst=act_A, src1=act_A, src2=act_B, count=10  ; x - max(x)
SYNC       mask=VPU
VLUT       dst=act_B, src=act_A, func=EXP, count=10     ; exp(x - max(x))
SYNC       mask=LUT
REDUCE     dst=act_A, src=act_B, op=SUM, axis=1, outer=1, inner=10
SYNC       mask=REDUCE
VSCALE     dst=act_B, src=act_B, scale=1.0, count=10    ; placeholder
; (proper division needs RCP then VMUL)
VLUT       dst=act_A, src=act_A, func=RCP, count=1      ; 1/sum
SYNC       mask=LUT
VMUL       dst=act_B, src1=act_B, src2=act_A, count=10  ; normalize

SYNC       mask=VPU

; ── Store result to DDR ──
STORE_DESC desc=&output_desc       ; DMA: act_B → DDR output buffer

SYNC       mask=DMA

; ── Signal completion ──
DONE       flags=INTERRUPT, status=0x00000000
```

---

## Pipeline Summary

| Block | Pipelines | Stages | Throughput |
|---|---|---|---|
| Systolic Array | 1 | 5 | 256 INT8 MACs/cycle |
| VPU | 1 (64-wide SIMD) | 2 | 64 INT8 elements/cycle |
| Reduction Tree | 1 | 2 | 64→1 per 2 cycles |
| SRAM Controller | 2 (A/B ping-pong) | 1 | 512 bits/cycle each port |
| Sequencer | 1 | 5 | 1 instruction/cycle |
| DMA Engine | 1 | 4 | 128-bit AXI burst |

---

## What Interviewers Will Ask About This

The design decisions that show depth:

- **Why weight-stationary?** Minimizes weight memory bandwidth — weights are the large constant, activations are the small variable. For inference this is optimal.
- **Why 64-wide VPU?** Matches the 16×16 systolic array output width — 16 columns × 4 bytes INT32 = 64 bytes = 512 bits per cycle. The VPU consumes exactly what the array produces.
- **Why separate DMA descriptors from instructions?** Keeps instruction width fixed and clean, enables complex strided transfers without bloating the ISA.
- **Why the scoreboard over in-order completion?** Units have different latencies — DMA takes hundreds of cycles, GEMM takes dozens, VPU takes 2. In-order would serialize everything. The scoreboard lets fast units proceed while slow ones finish.
- **Why INT8 with INT32 accumulation?** INT8×INT8 can produce values up to 255×255×16 = ~1M per accumulator for a 16-element dot product, which requires 20 bits minimum. INT32 gives full headroom across the K dimension without overflow.

---

## 6-Week Schedule

```
Week 1: Systolic array PE + grid, simulation only
Week 2: Systolic array tiling controller + VPU
        Get GEMM + ReLU working in simulation end-to-end
Week 3: Reduction tree + SRAM double buffer
        Run a single conv layer in simulation
Week 4: Instruction sequencer + AXI interface
        CPU can send instructions, get completion interrupt
Week 5: Integration + bring-up on KR260
        Run full MNIST model, measure latency
Week 6: Buffer for bugs (you will need this)
        Polish demo, measure throughput, write up results
```

---

## ISA Opcode Quick Reference

| Opcode | Mnemonic | Group | Description |
|--------|----------|-------|-------------|
| 0x00 | LOAD_DESC | Memory | DMA load from DDR to on-chip buffer |
| 0x01 | STORE_DESC | Memory | DMA store from on-chip buffer to DDR |
| 0x10 | GEMM | Systolic | General matrix multiply |
| 0x11 | CONV | Systolic | 2D convolution (via im2col + GEMM) |
| 0x20 | VADD | Vector | Element-wise add |
| 0x21 | VSUB | Vector | Element-wise subtract |
| 0x22 | VMUL | Vector | Element-wise multiply |
| 0x23 | VMAX | Vector | Element-wise max (ReLU via zero_buf) |
| 0x24 | VMIN | Vector | Element-wise min |
| 0x25 | VSEL | Vector | Masked select |
| 0x26 | VABS | Vector | Absolute value |
| 0x27 | VSCALE | Vector | Scalar broadcast multiply |
| 0x28 | REQUANT | Vector | INT32 → INT8 requantization |
| 0x30 | VLUT | Transcendental | LUT-based function (EXP/LOG/TANH/etc) |
| 0x40 | REDUCE | Reduction | Dimensional reduction (SUM/MAX/MIN/MEAN) |
| 0x41 | REDUCEWIN | Reduction | Sliding window reduction (pooling) |
| 0x50 | SYNC | Control | Wait for specified units to complete |
| 0x51 | FENCE | Control | Wait for all units |
| 0x52 | NOP | Control | No operation |
| 0x60-0xEF | — | Reserved | Future hardware blocks |
| 0xF0-0xFE | — | Debug | Profiling and debug instructions |
| 0xFF | DONE | Control | Signal completion, fire interrupt |

---

## Resource Summary

| Resource | Used | KR260 Total | % Used |
|----------|------|-------------|--------|
| DSP58E2 | 384 | 1,248 | 31% |
| BRAM36 | 96 | 144 | 67% |
| URAM288 | 32 | 64 | 50% |
| LUT (est.) | ~15,000 | 117,120 | 13% |

Remaining DSP headroom available for LUT transcendental unit interpolation and future FP8 MAC upgrade.