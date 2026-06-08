import numpy as np


def gen_tile(seed=0):
    """Return (W[16,16], A[16], M[16], S[16]) with controlled scale so output rarely saturates."""
    rng = np.random.default_rng(seed)
    W = rng.integers(-128, 128, (16, 16), dtype=np.int8)
    A = rng.integers(-128, 128, (16,),   dtype=np.int8)
    M = np.ones(16, dtype=np.int32)
    S = np.full(16, 11, dtype=np.uint8)  # >> 11: max |acc|=258064 → max |out|=126 < 127
    return W, A, M, S


def golden_matmul_requant(W, A, M, S):
    """INT8 reference: acc = W@A (INT32), out = clip(acc*M >> S, -128, 127)."""
    acc = W.astype(np.int32) @ A.astype(np.int32)
    out = np.empty(16, dtype=np.int8)
    for i in range(16):
        scaled = int(acc[i]) * int(M[i])
        shifted = scaled >> int(S[i])
        out[i] = np.clip(shifted, -128, 127)
    return out


def pack_weights_128b(W):
    """W[16,16] int8 → 16 128-bit words, word i = row i (16 bytes, col 0 in LSB)."""
    words = []
    for row in range(16):
        word = 0
        for col in range(16):
            word |= (int(W[row, col]) & 0xFF) << (col * 8)
        words.append(word)
    return words


def pack_acts_128b(A):
    """A[16] int8 → one 128-bit word (byte 0 = A[0] in LSB)."""
    word = 0
    for i in range(16):
        word |= (int(A[i]) & 0xFF) << (i * 8)
    return [word]


def pack_coeffs_128b(M, S):
    """M[16] int32, S[16] uint4 → 8 128-bit words.
    Word k: {M[2k+1][31:0], 28'h0, S[2k+1][3:0], M[2k][31:0], 28'h0, S[2k][3:0]}
    """
    words = []
    for k in range(0, 16, 2):
        m0 = int(M[k])   & 0xFFFF_FFFF
        s0 = int(S[k])   & 0xF
        m1 = int(M[k+1]) & 0xFFFF_FFFF
        s1 = int(S[k+1]) & 0xF
        word = (m1 << 96) | (s1 << 64) | (m0 << 32) | s0
        words.append(word)
    return words


def build_seq_mem(instrs):
    """instrs: list of 128-bit ints → {word_addr: value}"""
    return {i: v for i, v in enumerate(instrs)}


def build_dma_mem(A, M, S):
    """Coefficients at word 0x000..0x007; activations at word 0x700."""
    mem = {}
    for i, w in enumerate(pack_coeffs_128b(M, S)):
        mem[i] = w
    mem[0x700] = pack_acts_128b(A)[0]
    return mem


def build_wt_mem(W):
    """Weight rows at words 0x600..0x60F."""
    mem = {}
    for i, w in enumerate(pack_weights_128b(W)):
        mem[0x600 + i] = w
    return mem
