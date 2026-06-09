import cocotb
from cocotb.triggers import RisingEdge
from cocotb.utils import get_sim_time

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (gen_tile, golden_matmul_requant,
                        build_seq_mem, build_dma_mem, build_wt_mem, pack_acts_128b)

TIMEOUT_CYCLES = 50_000
SA_ROWS        = 16
SA_COLS        = 16
TILE_K         = 16
MACS           = 2 * SA_ROWS * SA_COLS * TILE_K   # 8192
PEAK_GOPS      = 2 * SA_ROWS * SA_COLS * 0.3      # 153.6  (300 MHz)
WT_BYTES       = SA_ROWS * SA_COLS                 # 256 B  (16x16 INT8 weight tile)
ACT_BYTES      = SA_ROWS                           # 16 B   (16 INT8 activation column)


class MetricsCounter:
    """Cycle-accurate pipeline stage counter. Run as a cocotb background coroutine.

    Each cycle is assigned to exactly one bucket (mutually exclusive):
      SA > load > store > idle
    Requires --public Verilator flag to access dut.u_sa_block.sa_busy_w.
    """

    def __init__(self, dut):
        self._dut         = dut
        self._active      = False
        self.total_cycles = 0
        self.sa_cycles    = 0   # systolic array computing
        self.load_cycles  = 0   # AXI read traffic on dma or wt channels
        self.store_cycles = 0   # AXI write traffic on st channel
        self.idle_cycles  = 0   # none of the above

    async def run(self):
        self._active = True
        dut = self._dut
        while self._active:
            await RisingEdge(dut.clk)
            if not self._active:
                break
            self.total_cycles += 1
            if dut.u_sa_block.sa_busy_w.value:
                self.sa_cycles += 1
            elif (dut.dma_arvalid.value or dut.dma_rvalid.value or
                  dut.wt_arvalid.value  or dut.wt_rvalid.value):
                self.load_cycles += 1
            elif dut.st_awvalid.value or dut.st_wvalid.value:
                self.store_cycles += 1
            else:
                self.idle_cycles += 1

    def stop(self):
        self._active = False


@cocotb.test()
async def test_npu_metrics_report(dut):
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

    counter = MetricsCounter(dut)
    cocotb.start_soon(counter.run())

    axil = AXILiteMaster(dut)
    await axil.write(0x0, 0x0)
    await axil.write(0x4, len(instrs))

    t_start = get_sim_time('ns')
    await axil.write(0x8, 1)

    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if dut.irq_done.value:
            break
    else:
        counter.stop()
        raise TimeoutError(f'irq_done not received within {TIMEOUT_CYCLES} cycles')

    t_end = get_sim_time('ns')
    counter.stop()

    assert not dut.fetch_err.value, 'fetch_err asserted'
    assert not dut.dma_err.value,   'dma_err asserted'
    assert len(st_slave.store_words) >= 1, 'no output produced'
    assert st_slave.store_words[0] == expected, (
        f'Output mismatch: got {st_slave.store_words[0]:#034x}, '
        f'expected {expected:#034x}'
    )

    # ---- Compute metrics ----
    sim_ns = t_end - t_start
    cyc    = counter.total_cycles or 1  # guard against /0

    # 1. GOPS + MFU
    eff_gops = MACS / sim_ns
    mfu      = eff_gops / PEAK_GOPS * 100

    # 2. Memory bandwidth (B/ns == GB/s)
    act_bw_gbs = ACT_BYTES / sim_ns
    wt_bw_gbs  = WT_BYTES  / sim_ns

    # 3. Arithmetic intensity (constant for this tile shape; shown for context)
    total_bytes     = ACT_BYTES + WT_BYTES
    arith_intensity = MACS / total_bytes

    # 4. Pipeline stage breakdown
    sa_pct    = counter.sa_cycles    / cyc * 100
    load_pct  = counter.load_cycles  / cyc * 100
    store_pct = counter.store_cycles / cyc * 100
    idle_pct  = counter.idle_cycles  / cyc * 100

    # 5. SA stall rate
    sa_stall_rate = (cyc - counter.sa_cycles) / cyc * 100

    sep = '=' * 52
    print(f'\n{sep}')
    print('  NPU Performance Metrics (Zero-Delay Baseline)')
    print(sep)
    print(f'  Total sim time      : {sim_ns:.1f} ns  ({cyc} cycles @ 10 ns)')
    print()
    print(f'  1. GOPS             : {eff_gops:.4f}')
    print(f'     Peak GOPS        : {PEAK_GOPS:.2f}')
    print(f'     MFU              : {mfu:.2f}%')
    print()
    print(f'  2. Activation BW    : {act_bw_gbs:.4f} GB/s')
    print(f'     Weight BW        : {wt_bw_gbs:.4f} GB/s')
    print(f'     Combined BW      : {act_bw_gbs + wt_bw_gbs:.4f} GB/s')
    print()
    print(f'  3. Arith intensity  : {arith_intensity:.2f} ops/byte')
    print(f'     ({total_bytes} B total  |  {MACS} MACs)')
    print()
    print(f'  4. Stage breakdown  : SA={sa_pct:.1f}%  Load={load_pct:.1f}%  '
          f'Store={store_pct:.1f}%  Idle={idle_pct:.1f}%')
    print(f'     SA active cycles : {counter.sa_cycles} / {cyc}')
    print()
    print(f'  5. SA stall rate    : {sa_stall_rate:.2f}%')
    print(sep)
