// =============================================================================
// File        : NPU_ISA_pkg.sv
// Project     : EE470 Neural Engine — KR260
// Description : NPU ISA definitions — opcodes, unit IDs, instruction struct,
//               and per-instruction payload structs. Import this package in the
//               sequencer, dispatch logic, and testbenches.
//               Hardware sizing constants are in NPU_HW_params_pkg.sv.
// =============================================================================
//
// NPU ISA — Instruction Reference  (NPUArchitectureV2 §3)
// All instructions are 128-bit fixed-width.
// Format: [127:120] opcode | [119:116] unit_id | [115:112] dep_flags | [111:0] payload
//
// Unit IDs
//   UNIT_SEQ  4'h0  Sequencer       — flow control, layer config
//   UNIT_DMA  4'h1  DMA engine      — DDR4 <-> SRAM data movement
//   UNIT_SA   4'h2  Systolic Array  — 16x16 INT8 GEMM tile
//   UNIT_PSB  4'h3  Partial Sum Buf — INT32 accumulation
//   UNIT_REQ  4'h4  Requant pipe    — INT32 -> INT8
//   UNIT_VPU  4'h5  Vector PU       — activation, pool, eltwise
//
// Instructions
//   8'h01  CONFIG      SEQ  Load layer tile params (M,N,K), stride, padding, act type
//   8'h02  FENCE       SEQ  Stall until all units in dep_flags bitmask complete
//   8'h10  WT_LOAD     DMA  Prefetch INT8 weight tile -> inactive Weight Bank (concurrent w/ SA)
//   8'h11  DMA_LOAD    DMA  2D-strided fetch of INT8 activation tile from DDR4
//   8'h12  DMA_STORE   DMA  Burst-write INT8 Output Bank -> DDR4
//   8'h13  UPSAMPLE    DMA  2x nearest-neighbor upsample (FPN layers 10, 13)
//   8'h14  CONCAT      DMA  2D-strided gather from two DDR4 addrs; interleave channels
//   8'h15  COEFF_LOAD  DMA  Write per-channel (M:INT16, S:UINT4) requant pairs to BRAM
//   8'h20  MATMUL      SA   Execute one 16x16 INT8 tile; results -> PSB_ACC
//   8'h21  PSB_ACC     PSB  Add current SA output into PSB INT32 running total
//   8'h22  PSB_FLUSH   PSB  K-tiles done; forward INT32 to Requant; zero-clear PSB
//   8'h30  REQUANT     REQ  Apply per-channel (M,S) multiply-shift-clip: INT32 -> INT8
//   8'h31  LUT_LOAD    DMA  Write 256 B of LUT data DDR4 -> Act LUT BRAM (ping-pong via lut_sel)
//   8'h32  LUT_BYPASS  VPU  Enable/disable LUT bypass mux (linear layers)
//   8'h33  SIMD_ACT    VPU  Run Act LUT lookup across all 64 lanes: INT8 -> LUT -> INT8
//   8'h34  RELU        VPU  Clamp INT8 values at zero across all lanes
//   8'h35  ELEW_ADD    VPU  Saturating lane-wise INT8 add (Output Bank + Residual Bank)
//   8'h36  ELEW_MUL    VPU  Lane-wise INT8 multiply -> INT16 -> requantized INT8
//   8'h37  MAXPOOL     VPU  Sliding-window max per lane (3x3 or 5x5 kernel)
//   8'h38  HREDUCE     VPU  4-stage binary reduction for DFL box decoding (once/frame)
//
// =============================================================================

package NPU_ISA_pkg;

    // =========================================================================
    // Instruction format — bit-field positions (128-bit fixed-width)
    // =========================================================================
    localparam int INSTR_WIDTH    = 128;

    localparam int OPCODE_MSB     = 127;
    localparam int OPCODE_LSB     = 120;  // [127:120] 8-bit opcode

    localparam int UNIT_ID_MSB    = 119;
    localparam int UNIT_ID_LSB    = 116;  // [119:116] 4-bit unit ID

    localparam int DEP_FLAGS_MSB  = 115;
    localparam int DEP_FLAGS_LSB  = 112;  // [115:112] 4-bit dependency flags

    localparam int PAYLOAD_MSB    = 111;
    localparam int PAYLOAD_LSB    = 0;    // [111:0]  112-bit payload

    // =========================================================================
    // Unit ID enum
    // =========================================================================
    typedef enum logic [3:0] {
        UNIT_SEQ = 4'h0,  // Sequencer
        UNIT_DMA = 4'h1,  // DMA engine
        UNIT_SA  = 4'h2,  // Systolic Array
        UNIT_PSB = 4'h3,  // Partial Sum Buffer
        UNIT_REQ = 4'h4,  // Requantization pipeline
        UNIT_VPU = 4'h5   // Vector Processing Unit
    } npu_unit_e;

    // =========================================================================
    // Opcode enum
    // =========================================================================
    typedef enum logic [7:0] {
        // Sequencer
        OP_CONFIG      = 8'h01,
        OP_FENCE       = 8'h02,

        // DMA
        OP_WT_LOAD     = 8'h10,
        OP_DMA_LOAD    = 8'h11,
        OP_DMA_STORE   = 8'h12,
        OP_UPSAMPLE    = 8'h13,
        OP_CONCAT      = 8'h14,
        OP_COEFF_LOAD  = 8'h15,

        // Systolic Array
        OP_MATMUL      = 8'h20,

        // Partial Sum Buffer
        OP_PSB_ACC     = 8'h21,
        OP_PSB_FLUSH   = 8'h22,

        // Requantization
        OP_REQUANT     = 8'h30,
        
        // VPU
        OP_LUT_LOAD    = 8'h31,
        OP_LUT_BYPASS  = 8'h32,
        OP_SIMD_ACT    = 8'h33,
        OP_RELU        = 8'h34,
        OP_ELEW_ADD    = 8'h35,
        OP_ELEW_MUL    = 8'h36,
        OP_MAXPOOL     = 8'h37,
        OP_HREDUCE     = 8'h38
    } npu_opcode_e;

    // =========================================================================
    // Dependency-flags typedef  (4-bit field in instruction header)
    // =========================================================================
    typedef logic [3:0] npu_dep_flags_t;

    // =========================================================================
    // Top-level instruction struct  (128 bits total)
    // =========================================================================
    typedef struct packed {
        npu_opcode_e    opcode;     // [127:120]
        npu_unit_e      unit_id;    // [119:116]
        npu_dep_flags_t dep_flags;  // [115:112]
        logic [111:0]   payload;    // [111:0]
    } npu_instr_t;

    // =========================================================================
    // Per-instruction payload structs  (each exactly 112 bits)
    // =========================================================================
    // Unused fields are named _rsvd and should be tied to '0 by the assembler.

    // --- OP_CONFIG -----------------------------------------------------------
    // tile_M/N/K: tile dimensions; stride: conv stride; pad_mode: 0=none,1=same,2=valid
    // act_type: 0=none,1=ReLU,2=SiLU; pool_size: 0=none,3=3x3,5=5x5
    // coeff_base: base DDR4 address for per-channel requant coefficients
    typedef struct packed {
        logic [43:0]  _rsvd;       // [111:68]
        logic [31:0]  coeff_base;  // [67:36]
        logic [2:0]   pool_size;   // [35:33]
        logic [2:0]   act_type;    // [32:30]
        logic [1:0]   pad_mode;    // [29:28]
        logic [3:0]   stride;      // [27:24]
        logic [7:0]   tile_K;      // [23:16]
        logic [7:0]   tile_N;      // [15:8]
        logic [7:0]   tile_M;      // [7:0]
    } npu_cfg_payload_t;

    // --- OP_FENCE ------------------------------------------------------------
    // unit_mask: one bit per unit (bit 0=SEQ, 1=DMA, 2=SA, 3=PSB, 4=REQ, 5=VPU)
    typedef struct packed {
        logic [105:0] _rsvd;      // [111:6]
        logic [5:0]   unit_mask;  // [5:0]
    } npu_fence_payload_t;

    // --- OP_WT_LOAD ----------------------------------------------------------
    // bank_sel: 0=Bank A, 1=Bank B (inactive bank to load into)
    typedef struct packed {
        logic [78:0]  _rsvd;         // [111:33]
        logic         bank_sel;      // [32]
        logic [31:0]  wt_base_addr;  // [31:0]
    } npu_wt_load_payload_t;

    // --- OP_DMA_LOAD / OP_DMA_STORE / OP_UPSAMPLE / OP_CONCAT ---------------
    // Shared 2D-strided DMA descriptor.
    // addr gen: addr = base + h*row_stride + w*ch_count + c
    typedef struct packed {
        logic [23:0]  _rsvd;       // [111:88]
        logic [3:0]   pad_right;   // [87:84]
        logic [3:0]   pad_left;    // [83:80]
        logic [3:0]   pad_bot;     // [79:76]
        logic [3:0]   pad_top;     // [75:72]
        logic [7:0]   ch_count;    // [71:64]
        logic [7:0]   tile_h;      // [63:56]
        logic [7:0]   tile_w;      // [55:48]
        logic [15:0]  row_stride;  // [47:32]
        logic [31:0]  base_addr;   // [31:0]
    } npu_dma_desc_t;

    // --- OP_CONCAT (Phase 7) -------------------------------------------------
    // Two-source 2D-strided gather. base_addr_b shares high byte with base_addr.
    typedef struct packed {
        logic [23:0]  base_addr_b_lo;  // [111:88] base_addr_b[23:0]; high byte = base_addr[31:24]
        logic [3:0]   pad_right;       // [87:84]
        logic [3:0]   pad_left;        // [83:80]
        logic [3:0]   pad_bot;         // [79:76]
        logic [3:0]   pad_top;         // [75:72]
        logic [7:0]   ch_count;        // [71:64]
        logic [7:0]   tile_h;          // [63:56]
        logic [7:0]   tile_w;          // [55:48]
        logic [15:0]  row_stride;      // [47:32]
        logic [31:0]  base_addr;       // [31:0]   base_addr_a
    } npu_concat_payload_t;

    // --- OP_COEFF_LOAD -------------------------------------------------------
    // ch_count: number of per-channel (M, S) pairs to load
    typedef struct packed {
        logic [69:0]  _rsvd;       // [111:42]
        logic [9:0]   ch_count;    // [41:32]
        logic [31:0]  coeff_addr;  // [31:0]
    } npu_coeff_load_payload_t;

    // --- OP_MATMUL -----------------------------------------------------------
    // tile_sel: selects which ping-pong act/weight bank pair to consume
    typedef struct packed {
        logic [110:0] _rsvd;     // [111:1]
        logic         tile_sel;  // [0]
    } npu_matmul_payload_t;

    // --- OP_REQUANT ----------------------------------------------------------
    // ch_count: number of output channels to requantize
    typedef struct packed {
        logic [101:0] _rsvd;     // [111:10]
        logic [9:0]   ch_count;  // [9:0]
    } npu_requant_payload_t;

    // --- OP_LUT_LOAD ---------------------------------------------------------
    // lut_sel: 0=Act LUT (SiLU), 1=HREDUCE exp LUT
    typedef struct packed {
        logic [78:0]  _rsvd;        // [111:33]
        logic         lut_sel;      // [32]
        logic [31:0]  lut_src_addr; // [31:0]
    } npu_lut_load_payload_t;

    // --- OP_LUT_BYPASS -------------------------------------------------------
    typedef struct packed {
        logic [110:0] _rsvd;      // [111:1]
        logic         bypass_en;  // [0]
    } npu_lut_bypass_payload_t;

    // --- OP_MAXPOOL ----------------------------------------------------------
    // kernel_size: 3'd3 = 3x3, 3'd5 = 5x5 (SPPF three-stage)
    typedef struct packed {
        logic [108:0] _rsvd;       // [111:3]
        logic [2:0]   kernel_size; // [2:0]
    } npu_maxpool_payload_t;

    // --- OP_ELEW_ADD ---------------------------------------------------------
    // rshift_en: optional 1-bit right shift after saturating add
    typedef struct packed {
        logic [110:0] _rsvd;      // [111:1]
        logic         rshift_en;  // [0]
    } npu_elew_add_payload_t;

    // OP_PSB_ACC, OP_PSB_FLUSH, OP_SIMD_ACT, OP_RELU,
    // OP_ELEW_MUL, OP_UPSAMPLE, OP_CONCAT, OP_HREDUCE:
    // no payload fields — callers set payload = '0.

endpackage : NPU_ISA_pkg
