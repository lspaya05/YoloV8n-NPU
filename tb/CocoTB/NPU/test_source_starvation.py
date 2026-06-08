import random
import cocotb
from cocotb.triggers import RisingEdge

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (gen_tile, golden_matmul_requant,
                         build_seq_mem, build_dma_mem, build_wt_mem, pack_acts_128b)

TIMEOUT_CYCLES = 200_000  # wider margin for stalls
SEED = 42


@cocotb.test()
async def test_source_starvation(dut):
    """Read channels randomly stall (0-3 cycles before arready).

    NPU must pause computation without dropping data or losing state.
    Output must still match the golden model exactly.
    """
    W, A, M, S = gen_tile(seed=0)
    expected   = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]

    await reset_dut(dut)

    rng = random.Random(SEED)

    instrs    = build_standard_instrs(ch_count=16)
    seq_slave = AXI4ReadSlave(dut, 'seq', build_seq_mem(instrs), data_bits=32,
                              delay_rng=rng)
    dma_slave = AXI4ReadSlave(dut, 'dma', build_dma_mem(A, M, S),
                              delay_rng=rng)
    wt_slave  = AXI4ReadSlave(dut, 'wt',  build_wt_mem(W),
                              delay_rng=rng)
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
        raise TimeoutError('irq_done timeout under source starvation')

    assert not dut.fetch_err.value
    assert not dut.dma_err.value
    assert len(st_slave.store_words) >= 1
    assert st_slave.store_words[0] == expected, (
        f'Source-starvation output mismatch:\n'
        f'  got      {st_slave.store_words[0]:#034x}\n'
        f'  expected {expected:#034x}'
    )
