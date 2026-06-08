import numpy as np

# Unit IDs
UNIT_SEQ = 0x0
UNIT_DMA = 0x1
UNIT_SA  = 0x2
UNIT_PSB = 0x3
UNIT_REQ = 0x4
UNIT_VPU = 0x5

# dep_flags bit masks  (bits [115:112] of 128-bit instruction word)
# Pipeline: DMA(1) -> SA(2) -> PSB(3) -> REQ(4) -> VPU(5) -> DMA(1)
# "next" = downstream, "prev" = upstream
DEP_PUSH_NEXT = 0x8  # push done-token to downstream RAW FIFO
DEP_PUSH_PREV = 0x4  # push done-token to upstream WAR FIFO
DEP_POP_NEXT  = 0x2  # block until token from upstream RAW FIFO
DEP_POP_PREV  = 0x1  # block until token from downstream WAR FIFO

# Opcodes
OP_CONFIG     = 0x01
OP_FENCE      = 0x02
OP_WT_LOAD    = 0x10
OP_DMA_LOAD   = 0x11
OP_DMA_STORE  = 0x12
OP_UPSAMPLE   = 0x13
OP_CONCAT     = 0x14
OP_COEFF_LOAD = 0x15
OP_MATMUL     = 0x20
OP_PSB_ACC    = 0x21
OP_PSB_FLUSH  = 0x22
OP_REQUANT    = 0x30
OP_LUT_LOAD   = 0x31
OP_LUT_BYPASS = 0x32
OP_SIMD_ACT   = 0x33
OP_RELU       = 0x34
OP_ELEW_ADD   = 0x35
OP_ELEW_MUL   = 0x36
OP_MAXPOOL    = 0x37
OP_HREDUCE    = 0x38


def make_instr(opcode, unit_id, dep_flags, payload):
    return (
        ((opcode   & 0xFF)         << 120) |
        ((unit_id  & 0xF)          << 116) |
        ((dep_flags & 0xF)         << 112) |
        (payload   & ((1 << 112) - 1))
    )


def make_config_payload(tile_m, tile_n, tile_k, stride, pad_mode, act_type, pool_size, coeff_base):
    # {44'h0, coeff_base[31:0], pool_size[2:0], act_type[2:0], pad_mode[1:0], stride[3:0],
    #  tile_k[7:0], tile_n[7:0], tile_m[7:0]}
    return (
        ((coeff_base & 0xFFFF_FFFF) << 36) |
        ((pool_size  & 0x7)         << 33) |
        ((act_type   & 0x7)         << 30) |
        ((pad_mode   & 0x3)         << 28) |
        ((stride     & 0xF)         << 24) |
        ((tile_k     & 0xFF)        << 16) |
        ((tile_n     & 0xFF)        <<  8) |
        (tile_m      & 0xFF)
    )


def make_dma_payload(base_addr, row_stride, tile_w, tile_h, ch_count,
                     pad_top, pad_bot, pad_left, pad_right):
    # {24'h0, pad_right[3:0], pad_left[3:0], pad_bot[3:0], pad_top[3:0],
    #  ch_count[7:0], tile_h[7:0], tile_w[7:0], row_stride[15:0], base_addr[31:0]}
    return (
        ((pad_right & 0xF)          << 84) |
        ((pad_left  & 0xF)          << 80) |
        ((pad_bot   & 0xF)          << 76) |
        ((pad_top   & 0xF)          << 72) |
        ((ch_count  & 0xFF)         << 64) |
        ((tile_h    & 0xFF)         << 56) |
        ((tile_w    & 0xFF)         << 48) |
        ((row_stride & 0xFFFF)      << 32) |
        (base_addr   & 0xFFFF_FFFF)
    )


def make_coeff_load_payload(ch_count, coeff_addr):
    # {70'h0, ch_count[9:0], coeff_addr[31:0]}
    return ((ch_count & 0x3FF) << 32) | (coeff_addr & 0xFFFF_FFFF)


def make_wt_load_payload(bank_sel, wt_base_addr):
    # {79'h0, bank_sel[0], wt_base_addr[31:0]}
    return ((bank_sel & 0x1) << 32) | (wt_base_addr & 0xFFFF_FFFF)


def make_matmul_payload(tile_sel):
    # {111'h0, tile_sel[0]}
    return tile_sel & 0x1


def make_requant_payload(ch_count):
    # {102'h0, ch_count[9:0]}
    return ch_count & 0x3FF


def make_lut_bypass_payload(bypass_en):
    # {111'h0, bypass_en[0]}
    return bypass_en & 0x1


def encode_instr_to_seq_mem(instrs):
    """Return word_addr -> 128-bit value dict. Word addr i = byte addr i*16."""
    return {i: instr for i, instr in enumerate(instrs)}


def build_standard_instrs(ch_count=16):
    """9-instruction sequence for one 16x16 INT8 tile pass."""
    return [
        make_instr(OP_CONFIG,     UNIT_SEQ, 0x0,
                   make_config_payload(16, 16, 16, 1, 0, 0, 0, 0x0000)),
        make_instr(OP_COEFF_LOAD, UNIT_DMA, 0x0,
                   make_coeff_load_payload(ch_count, 0x0000)),
        make_instr(OP_WT_LOAD,    UNIT_DMA, 0x0,
                   make_wt_load_payload(0, 0x6000)),
        make_instr(OP_DMA_LOAD,   UNIT_DMA, DEP_PUSH_NEXT | DEP_POP_PREV,
                   make_dma_payload(0x7000, 16, 1, 1, ch_count, 0, 0, 0, 0)),
        make_instr(OP_MATMUL,     UNIT_SA,
                   DEP_PUSH_NEXT | DEP_PUSH_PREV | DEP_POP_NEXT | DEP_POP_PREV,
                   make_matmul_payload(0)),
        make_instr(OP_PSB_FLUSH,  UNIT_PSB,
                   DEP_PUSH_NEXT | DEP_PUSH_PREV | DEP_POP_NEXT | DEP_POP_PREV,
                   0),
        # Matrix-vector: the SA produces one output row (W@A), so Requant retires
        # exactly one beat (the 16-lane output vector) and writes output word 0.
        # ch_count here is the BEAT count (target_count in Dispatch_REQ), not the
        # per-channel coeff count (that is the COEFF_LOAD ch_count / ChCount param).
        make_instr(OP_REQUANT,    UNIT_REQ,
                   DEP_PUSH_NEXT | DEP_PUSH_PREV | DEP_POP_NEXT | DEP_POP_PREV,
                   make_requant_payload(1)),
        make_instr(OP_LUT_BYPASS, UNIT_VPU,
                   DEP_PUSH_NEXT | DEP_PUSH_PREV | DEP_POP_NEXT | DEP_POP_PREV,
                   make_lut_bypass_payload(1)),
        make_instr(OP_DMA_STORE,  UNIT_DMA, DEP_POP_NEXT | DEP_PUSH_PREV,
                   make_dma_payload(0x8000, 16, 1, 1, ch_count, 0, 0, 0, 0)),
    ]


# ---------------------------------------------------------------------------
# Previous version of build_standard_instrs (dep_flags all zero)
# ---------------------------------------------------------------------------
# def build_standard_instrs(ch_count=16):
#     """9-instruction sequence for one 16x16 INT8 tile pass."""
#     return [
#         make_instr(OP_CONFIG,     UNIT_SEQ, 0,
#                    make_config_payload(16, 16, 16, 1, 0, 0, 0, 0x0000)),
#         make_instr(OP_COEFF_LOAD, UNIT_DMA, 0,
#                    make_coeff_load_payload(ch_count, 0x0000)),
#         make_instr(OP_WT_LOAD,    UNIT_DMA, 0,
#                    make_wt_load_payload(0, 0x6000)),
#         make_instr(OP_DMA_LOAD,   UNIT_DMA, 0,
#                    make_dma_payload(0x7000, 16, 1, 1, ch_count, 0, 0, 0, 0)),
#         make_instr(OP_MATMUL,     UNIT_SA,  0, make_matmul_payload(0)),
#         make_instr(OP_PSB_FLUSH,  UNIT_PSB, 0, 0),
#         make_instr(OP_REQUANT,    UNIT_REQ, 0, make_requant_payload(ch_count)),
#         make_instr(OP_LUT_BYPASS, UNIT_VPU, 0, make_lut_bypass_payload(1)),
#         make_instr(OP_DMA_STORE,  UNIT_DMA, 0,
#                    make_dma_payload(0x8000, 16, 1, 1, ch_count, 0, 0, 0, 0)),
#     ]
