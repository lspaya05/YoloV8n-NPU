import cocotb
from cocotb.triggers import RisingEdge

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (gen_tile, golden_matmul_requant,
                        build_seq_mem, build_dma_mem, build_wt_mem, pack_acts_128b)
from npu_monitor import NpuObserver

TIMEOUT_CYCLES = 50_000


async def _run_tile(dut, W, A, M, S, delay_rng_r=None, delay_rng_w=None):
    """Set up memories, start BFMs, kick program, wait irq_done. Returns store_slave."""
    await reset_dut(dut)

    instrs    = build_standard_instrs(ch_count=16)
    seq_slave = AXI4ReadSlave(dut, 'seq', build_seq_mem(instrs), data_bits=32,
                              delay_rng=delay_rng_r)
    dma_slave = AXI4ReadSlave(dut, 'dma', build_dma_mem(A, M, S),
                              delay_rng=delay_rng_r)
    wt_slave  = AXI4ReadSlave(dut, 'wt',  build_wt_mem(W),
                              delay_rng=delay_rng_r)
    st_slave  = AXI4WriteSlave(dut, delay_rng=delay_rng_w)

    await seq_slave.start()
    await dma_slave.start()
    await wt_slave.start()
    await st_slave.start()

    obs = NpuObserver(dut)
    await obs.start()

    axil = AXILiteMaster(dut)
    await axil.write(0x0, 0x0000_0000)  # instruction base
    await axil.write(0x4, len(instrs))  # instruction count
    await axil.write(0x8, 1)            # kick

    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if dut.irq_done.value:
            obs.note("IRQ_DONE")
            await obs.stop()
            break
    else:
        await obs.stop()
        raise TimeoutError(f'irq_done not received within {TIMEOUT_CYCLES} cycles')

    assert not dut.fetch_err.value, 'fetch_err asserted'
    assert not dut.dma_err.value,   'dma_err asserted'
    return st_slave


@cocotb.test()
async def test_single_layer_baseline(dut):
    W, A, M, S = gen_tile(seed=0)
    expected   = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]

    st = await _run_tile(dut, W, A, M, S)

    assert len(st.store_words) >= 1, 'DMA_STORE produced no output'
    actual = st.store_words[0]
    assert actual == expected, (
        f'Output mismatch:\n  got      {actual:#034x}\n  expected {expected:#034x}'
    )
