import cocotb
from cocotb.triggers import RisingEdge
from cocotb.utils import get_sim_time

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (gen_tile, golden_matmul_requant,
                         build_seq_mem, build_dma_mem, build_wt_mem, pack_acts_128b)

TIMEOUT_CYCLES = 50_000
CLK_FREQ_GHZ   = 0.3              # 300 MHz = 0.3 GHz
SA_ROWS        = 16
SA_COLS        = 16
TILE_K         = 16
MACS           = 2 * SA_ROWS * SA_COLS * TILE_K   # total ops for this tile
# Peak: all 256 PEs fire every cycle at 300 MHz
PEAK_GOPS      = 2 * SA_ROWS * SA_COLS * CLK_FREQ_GHZ  # = 153.6 GOPS


@cocotb.test()
async def test_zero_delay_throughput(dut):
    """Zero-stall baseline: measures minimum clock cycles and reports GOPS."""
    W, A, M, S = gen_tile(seed=0)
    expected   = pack_acts_128b(golden_matmul_requant(W, A, M, S))[0]

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

    t_start = get_sim_time('ns')
    await axil.write(0x8, 1)   # kick — start timing here

    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if dut.irq_done.value:
            break
    else:
        raise TimeoutError('irq_done timeout in zero-delay test')

    t_end  = get_sim_time('ns')
    sim_ns = t_end - t_start

    assert not dut.fetch_err.value
    assert not dut.dma_err.value
    assert len(st_slave.store_words) >= 1, 'no output produced'
    assert st_slave.store_words[0] == expected, (
        f'Zero-delay output mismatch: got {st_slave.store_words[0]:#034x}'
    )

    # GOPS = MACs / time_seconds / 1e9; with sim_ns in ns: MACs / (sim_ns*1e-9) / 1e9 = MACs/sim_ns
    eff_gops = MACS / sim_ns

    print('\n--- GOPS Report (Zero-Delay Baseline) ---')
    print(f'  Simulated time  : {sim_ns:.1f} ns  ({sim_ns/10:.0f} cycles @ 10 ns)')
    print(f'  Peak GOPS       : {PEAK_GOPS:.2f}')
    print(f'  Effective GOPS  : {eff_gops:.4f}')
    print(f'  PE utilization  : {eff_gops / PEAK_GOPS * 100:.2f}%')
    print('-----------------------------------------')
