import numpy as np
import cocotb
from cocotb.triggers import RisingEdge

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (golden_matmul_requant, build_seq_mem, build_dma_mem,
                         build_wt_mem, pack_acts_128b)

TIMEOUT_CYCLES = 50_000


async def _run_stress(dut, W, A, M, S):
    await reset_dut(dut)

    instrs    = build_standard_instrs(ch_count=16)
    seq_slave = AXI4ReadSlave(dut, 'seq', build_seq_mem(instrs), data_bits=32)
    dma_slave = AXI4ReadSlave(dut, 'dma', build_dma_mem(A, M, S))
    wt_slave  = AXI4ReadSlave(dut, 'wt',  build_wt_mem(W))
    st_slave  = AXI4WriteSlave(dut)

    await seq_slave.start()
    await dma_slave.start()
    await wt_slave.start()
    await st_slave.start()

    axil = AXILiteMaster(dut)
    await axil.write(0x0, 0x0)
    await axil.write(0x4, len(instrs))
    await axil.write(0x8, 1)

    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if dut.irq_done.value:
            break
    else:
        raise TimeoutError('irq_done timeout in stress test')

    assert not dut.fetch_err.value
    assert not dut.dma_err.value
    return st_slave


@cocotb.test()
async def test_all_zeros(dut):
    """All-zero activations and weights must produce all-zero output."""
    W = np.zeros((16, 16), dtype=np.int8)
    A = np.zeros(16,       dtype=np.int8)
    M = np.ones(16,        dtype=np.int32)
    S = np.zeros(16,       dtype=np.uint8)

    expected = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]
    st = await _run_stress(dut, W, A, M, S)

    assert st.store_words[0] == expected == 0, (
        f'All-zeros: got {st.store_words[0]:#034x}'
    )


@cocotb.test()
async def test_max_values(dut):
    """Maximum INT8 inputs must not overflow the INT32 accumulator.

    W=A=0x7F, M=1, S=11: acc = 16*127*127 = 258064; scaled = 258064>>11 = 126.
    All 16 output bytes must equal 126 (0x7E).
    """
    W = np.full((16, 16), 127, dtype=np.int8)
    A = np.full(16,       127, dtype=np.int8)
    M = np.ones(16,           dtype=np.int32)
    S = np.full(16, 11,       dtype=np.uint8)

    expected = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]
    st = await _run_stress(dut, W, A, M, S)

    assert st.store_words[0] == expected, (
        f'Max-values: got {st.store_words[0]:#034x}, expected {expected:#034x}'
    )


@cocotb.test()
async def test_checkerboard(dut):
    """Checkerboard W and alternating A produce a known signed-alternating output.

    W[i,j] = (-1)^(i+j), A[k] = (-1)^k
    acc[i] = sum_k((-1)^(i+k) * (-1)^k) = sum_k((-1)^i) = 16*(-1)^i
    => acc[even_row]=16, acc[odd_row]=-16; M=1, S=0 => out = +16 / -16
    """
    W = np.array([[(-1)**((i+j) % 2) for j in range(16)]
                  for i in range(16)], dtype=np.int8)
    A = np.array([(-1)**(k % 2) for k in range(16)], dtype=np.int8)
    M = np.ones(16,  dtype=np.int32)
    S = np.zeros(16, dtype=np.uint8)

    expected = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]
    st = await _run_stress(dut, W, A, M, S)

    assert st.store_words[0] == expected, (
        f'Checkerboard: got {st.store_words[0]:#034x}, expected {expected:#034x}'
    )
