import cocotb
from cocotb.triggers import RisingEdge

from npu_bfm import reset_dut, AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave
from npu_isa import build_standard_instrs
from npu_golden import (gen_tile, golden_matmul_requant,
                         build_seq_mem, build_dma_mem, build_wt_mem, pack_acts_128b)
from npu_monitor import NpuObserver

TIMEOUT_CYCLES = 50_000


def _si(sig):
    try:
        return int(sig.value)
    except Exception:
        return None


def _sext(v, bits=32):
    """Interpret an unsigned int as a signed two's-complement value."""
    if v is None:
        return None
    return v - (1 << bits) if (v >> (bits - 1)) & 1 else v


async def _diag_probe(dut, state):
    """TEMP diagnostic: latch key internal signals to localise the all-zero bug."""
    state['rv_count'] = 0
    state['wt_or'] = 0
    state['act_or'] = 0
    state['cyc'] = 0
    state['mmi_trace'] = []   # (cyc, ctrl_state, [16 signed cols]) when any col != 0
    while True:
        await RisingEdge(dut.clk)
        state['cyc'] += 1
        cyc = state['cyc']
        # M coefficient loaded into the requant pipeline (1 per lane when correct).
        m = _si(getattr(getattr(dut, 'u_requant_block', None), 'req_m0_a_w', None))
        if m:
            state['m0'] = m
        # Did weight / activation data actually reach the SA bank read ports?
        state['wt_or']  |= (_si(getattr(dut, 'sa_wt_rdata_w', None)) or 0)
        state['act_or'] |= (_si(getattr(dut, 'sa_act_rdata_w', None)) or 0)
        # Full 16-col MatrixMul bottom row, every cycle. Find the cycle where all
        # 16 cols are simultaneously valid vs. when SA_top latches / PSB captures.
        try:
            sa = dut.u_sa_block.Systolic_array
            mmi = [_sext(int(sa.matrixMulOut_internal[i].value)) for i in range(16)]
            try:
                cs = int(sa.controller.ps.value)
            except Exception:
                cs = None
            if any(v != 0 for v in mmi):
                state['mmi_trace'].append((cyc, cs, mmi))
                state['mmi_nz'] = mmi  # last non-zero row seen (back-compat)
        except Exception as e:
            state['mmi_nz'] = f'err:{e}'
        # One-shot dump of loaded PE weights at first RUN cycle (ps==2), and the
        # per-cycle activation vector entering column 0 during RUN/DRAIN.
        try:
            sa = dut.u_sa_block.Systolic_array
            cs = int(sa.controller.ps.value)
            dp = sa.datapath
            if cs == 2 and 'pe_w' not in state:
                w = []
                for i in range(16):
                    row = []
                    for j in range(16):
                        pe = dp.gen_PE_Rows[i].gen_PE_Col[j].PE
                        row.append(_sext(int(pe.weight.value), 8))
                    w.append(row)
                state['pe_w'] = w
            if cs in (2, 3):
                dact = [_sext(int(dp.delayedActivation[i].value), 8) for i in range(16)]
                state.setdefault('dact_trace', []).append((cyc, cs, dact))
            # During LOAD (ps==1): what weight row is presented each cycle?
            if cs == 1:
                wr = _si(getattr(dut, 'sa_wt_rdata_w', None)) or 0
                ra = _si(getattr(dut, 'sa_wt_raddr_w', None))
                wbytes = [_sext((wr >> (8*k)) & 0xFF, 8) for k in range(16)]
                state.setdefault('wt_load_trace', []).append((cyc, ra, wbytes))
        except Exception as e:
            state['pe_w_err'] = f'{e}'
        # Count SA->PSB capture-strobe pulses; snapshot SA output row when it fires.
        rv = _si(getattr(dut, 'sa_row_valid_w', None))
        if rv:
            state['rv_count'] = state.get('rv_count', 0) + 1
            state['rv_cyc'] = cyc
            try:
                state['sa_at_rv'] = [int(dut.sa_row_out_w[i].value) for i in range(4)]
                state['sa_at_rv16'] = [_sext(int(dut.sa_row_out_w[i].value))
                                       for i in range(16)]
            except Exception as e:
                state['sa_at_rv'] = f'err:{e}'
        # First PSB flush beat = buffer[0] (the W@A row) as seen by Requant.
        if _si(getattr(dut, 'psb_row_out_valid_w', None)) and 'psb_first' not in state:
            state['psb_first'] = _si(getattr(dut, 'requant_row_out_w', None))
        # First requant pipeline output beat.
        rb = getattr(dut, 'u_requant_block', None)
        if rb is not None and _si(getattr(rb, 'req_valid_o_w', None)) and 'req_out' not in state:
            state['req_out'] = _si(getattr(rb, 'req_data_o_w', None))


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

    diag = {}
    cocotb.start_soon(_diag_probe(dut, diag))

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

    def _h(v, w=128):
        return 'None' if v is None else f"0x{v:0{w//4}x}"
    dut._log.info(f"[DIAG] req_m0_a_w (loaded M, 512b) = {_h(diag.get('m0'), 512)}")
    dut._log.info(f"[DIAG] psb first flush row (buffer[0], 512b) = {_h(diag.get('psb_first'), 512)}")
    dut._log.info(f"[DIAG] req first output beat (128b) = {_h(diag.get('req_out'))}")
    dut._log.info(f"[DIAG] sa_row_valid pulses = {diag.get('rv_count')}")
    dut._log.info(f"[DIAG] sa_row_out_w[0..3] at capture = {diag.get('sa_at_rv')}")
    try:
        sa_now = [int(dut.sa_row_out_w[i].value) for i in range(4)]
    except Exception as e:
        sa_now = f'err:{e}'
    dut._log.info(f"[DIAG] sa_row_out_w[0..3] at irq_done = {sa_now}")
    dut._log.info(f"[DIAG] sa_wt_rdata OR-over-time  = {_h(diag.get('wt_or'))}")
    dut._log.info(f"[DIAG] sa_act_rdata OR-over-time = {_h(diag.get('act_or'))}")
    dut._log.info(f"[DIAG] matrixMulOut_internal[0..3] (any non-zero seen) = {diag.get('mmi_nz')}")
    dut._log.info(f"[DIAG] sa_row_valid fired at cyc = {diag.get('rv_cyc')}")
    dut._log.info(f"[DIAG] sa_row_out 16-col at capture = {diag.get('sa_at_rv16')}")
    dut._log.info("[DIAG] matrixMulOut_internal bottom-row trace "
                  "(cyc, ctrl_ps, [16 signed cols]) — ctrl_ps: 0=IDLE 1=LOAD 2=RUN 3=DRAIN 4=DONE")
    for (cyc, cs, mmi) in diag.get('mmi_trace', []):
        nz = sum(1 for v in mmi if v != 0)
        dut._log.info(f"[DIAG]   cyc={cyc:4d} ps={cs} nz={nz:2d}/16 row={mmi}")
    import json
    with open('sa_dump.json', 'w') as f:
        json.dump({'pe_w': diag.get('pe_w'), 'pe_w_err': diag.get('pe_w_err'),
                   'dact_trace': diag.get('dact_trace'),
                   'wt_load_trace': diag.get('wt_load_trace'),
                   'mmi_trace': diag.get('mmi_trace')}, f)
    dut._log.info(f"[DIAG] pe_w_err = {diag.get('pe_w_err')}")
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
