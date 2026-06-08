"""Reusable cycle-by-cycle diagnostic probe for the NPU cocotb testbenches.

This is the deep-internal probe used to localise the single-layer all-zeros /
wrong-value bugs (see docs/analysis/SESSION_HANDOFF.md "Resolution 2"). It is
kept as a standalone, opt-in module so it does NOT slow down or clutter the
normal passing tests, but can be re-attached instantly when something regresses.

It complements (does not replace) npu_monitor.NpuObserver: the monitor prints the
high-level cycle-by-cycle FSM/DMA/SAR walk-through on every run; this probe digs
into the systolic-array internals (loaded PE weights, bottom-row de-skew trace,
activation feed, weight-load address walk, PSB/requant first beats).

Usage in a test (e.g. test_single_layer._run_tile):

    from diag_probe import diag_probe, report_diag

    diag = {}
    cocotb.start_soon(diag_probe(dut, diag))      # after obs.start()
    ...                                            # run the program, wait irq_done
    report_diag(dut, diag)                         # before returning; also writes
                                                   # sa_dump.json for offline analysis

All hierarchical accesses are wrapped in try/except so the probe degrades
gracefully if signal names change or the build lacks --public on a node.
"""

from cocotb.triggers import RisingEdge


def _si(sig):
    """int(sig.value) or None if unreadable."""
    try:
        return int(sig.value)
    except Exception:
        return None


def _sext(v, bits=32):
    """Interpret an unsigned int as a signed two's-complement value."""
    if v is None:
        return None
    return v - (1 << bits) if (v >> (bits - 1)) & 1 else v


async def diag_probe(dut, state):
    """Latch key SA-internal signals every cycle into `state` (a dict)."""
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
        # Full 16-col MatrixMul bottom row, every cycle. Shows the diagonal output
        # wavefront and the cycle each column is valid vs. when it is captured.
        try:
            sa = dut.u_sa_block.Systolic_array
            mmi = [_sext(int(sa.matrixMulOut_internal[i].value)) for i in range(16)]
            try:
                cs = int(sa.controller.ps.value)
            except Exception:
                cs = None
            if any(v != 0 for v in mmi):
                state['mmi_trace'].append((cyc, cs, mmi))
                state['mmi_nz'] = mmi  # last non-zero row seen
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
                wbytes = [_sext((wr >> (8 * k)) & 0xFF, 8) for k in range(16)]
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


def report_diag(dut, state, dump_json='sa_dump.json'):
    """Log the collected diagnostics and (optionally) write a JSON dump."""
    def _h(v, w=128):
        return 'None' if v is None else f"0x{v:0{w // 4}x}"

    dut._log.info(f"[DIAG] req_m0_a_w (loaded M, 512b) = {_h(state.get('m0'), 512)}")
    dut._log.info(f"[DIAG] psb first flush row (buffer[0], 512b) = {_h(state.get('psb_first'), 512)}")
    dut._log.info(f"[DIAG] req first output beat (128b) = {_h(state.get('req_out'))}")
    dut._log.info(f"[DIAG] sa_row_valid pulses = {state.get('rv_count')}")
    dut._log.info(f"[DIAG] sa_row_out_w[0..3] at capture = {state.get('sa_at_rv')}")
    try:
        sa_now = [int(dut.sa_row_out_w[i].value) for i in range(4)]
    except Exception as e:
        sa_now = f'err:{e}'
    dut._log.info(f"[DIAG] sa_row_out_w[0..3] at irq_done = {sa_now}")
    dut._log.info(f"[DIAG] sa_wt_rdata OR-over-time  = {_h(state.get('wt_or'))}")
    dut._log.info(f"[DIAG] sa_act_rdata OR-over-time = {_h(state.get('act_or'))}")
    dut._log.info(f"[DIAG] matrixMulOut_internal (last non-zero row) = {state.get('mmi_nz')}")
    dut._log.info(f"[DIAG] sa_row_valid fired at cyc = {state.get('rv_cyc')}")
    dut._log.info(f"[DIAG] sa_row_out 16-col at capture = {state.get('sa_at_rv16')}")
    dut._log.info("[DIAG] matrixMulOut_internal bottom-row trace "
                  "(cyc, ctrl_ps, [16 signed cols]) — ps: 0=IDLE 1=LOAD 2=RUN 3=DRAIN 4=DONE")
    for (cyc, cs, mmi) in state.get('mmi_trace', []):
        nz = sum(1 for v in mmi if v != 0)
        dut._log.info(f"[DIAG]   cyc={cyc:4d} ps={cs} nz={nz:2d}/16 row={mmi}")
    dut._log.info(f"[DIAG] pe_w_err = {state.get('pe_w_err')}")
    if dump_json:
        import json
        try:
            with open(dump_json, 'w') as f:
                json.dump({'pe_w': state.get('pe_w'), 'pe_w_err': state.get('pe_w_err'),
                           'dact_trace': state.get('dact_trace'),
                           'wt_load_trace': state.get('wt_load_trace'),
                           'mmi_trace': state.get('mmi_trace')}, f)
            dut._log.info(f"[DIAG] wrote {dump_json}")
        except Exception as e:
            dut._log.info(f"[DIAG] could not write {dump_json}: {e}")
