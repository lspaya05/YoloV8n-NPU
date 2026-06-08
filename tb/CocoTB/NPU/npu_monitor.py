"""NPU cocotb observer — turns NPU signal traffic into a human-readable event log.

Drop-in instrumentation for any cocotb test driving [src/NPU/NPU.sv]. Decodes
disp_push/disp_payload into named DISPATCH events, tracks per-unit FSM
transitions and done pulses, detects FENCE arm/release, and dumps a snapshot
when the pipeline stalls.

Every log line carries a 3-letter owner tag: [cyc N] [TAG] message. Tags:
SEQ (sequencer/dispatch/fence), DMA (DMA engine + bank handoffs), SAR (systolic
array), PSB, REQ, VPU (done pulses + FSM), CSR (AXI-Lite writes), AXI (HP0 bus),
TOP (monitor meta: stall/heartbeat/summary). See NPU_MONITOR_SIGNALS.md.

Basic usage:
    from npu_monitor import NpuObserver

    obs = NpuObserver(dut)
    await obs.start()
    # ... run test ...
    await obs.stop()          # prints summary

Mirror output to a file (for diffing two runs):
    obs = NpuObserver(dut, log_file="monitor.log")

Tuning knobs:
    stall_threshold      cycles with no real event before STALL dump (default 2000)
    heartbeat_interval   cycles between HB lines when otherwise quiet
                         (default 1000; set 0 to disable)

Requires the cocotb runner to expose NPU internals — already true for
test_single_layer_interface.py via `--public`.
"""

import cocotb
from cocotb.triggers import RisingEdge

from npu_isa import (
    UNIT_SEQ, UNIT_DMA, UNIT_SA, UNIT_PSB, UNIT_REQ, UNIT_VPU,
    OP_CONFIG, OP_FENCE, OP_WT_LOAD, OP_DMA_LOAD, OP_DMA_STORE,
    OP_UPSAMPLE, OP_CONCAT, OP_COEFF_LOAD, OP_MATMUL, OP_PSB_ACC,
    OP_PSB_FLUSH, OP_REQUANT, OP_LUT_LOAD, OP_LUT_BYPASS, OP_SIMD_ACT,
    OP_RELU, OP_ELEW_ADD, OP_ELEW_MUL, OP_MAXPOOL, OP_HREDUCE,
)


_OPCODE_NAMES = {
    OP_CONFIG: "OP_CONFIG", OP_FENCE: "OP_FENCE",
    OP_WT_LOAD: "OP_WT_LOAD", OP_DMA_LOAD: "OP_DMA_LOAD",
    OP_DMA_STORE: "OP_DMA_STORE", OP_UPSAMPLE: "OP_UPSAMPLE",
    OP_CONCAT: "OP_CONCAT", OP_COEFF_LOAD: "OP_COEFF_LOAD",
    OP_MATMUL: "OP_MATMUL", OP_PSB_ACC: "OP_PSB_ACC",
    OP_PSB_FLUSH: "OP_PSB_FLUSH", OP_REQUANT: "OP_REQUANT",
    OP_LUT_LOAD: "OP_LUT_LOAD", OP_LUT_BYPASS: "OP_LUT_BYPASS",
    OP_SIMD_ACT: "OP_SIMD_ACT", OP_RELU: "OP_RELU",
    OP_ELEW_ADD: "OP_ELEW_ADD", OP_ELEW_MUL: "OP_ELEW_MUL",
    OP_MAXPOOL: "OP_MAXPOOL", OP_HREDUCE: "OP_HREDUCE",
}

_UNIT_NAMES = {
    UNIT_SEQ: "SEQ", UNIT_DMA: "DMA", UNIT_SA: "SA",
    UNIT_PSB: "PSB", UNIT_REQ: "REQ", UNIT_VPU: "VPU",
}

# disp_push bit index -> per-unit FIFO target (NPU.sv:183)
_DISP_PUSH_BIT_TO_UNIT = {
    0: "DMA_Ch0", 1: "SA", 2: "PSB", 3: "REQ", 4: "VPU", 5: "DMA_Ch1",
}

# Sequencer fetch-FSM enum (Sequencer.sv:225-231)
_SEQ_STATE_NAMES = {
    0: "S_IDLE", 1: "S_AR", 2: "S_R", 3: "S_DISPATCH", 4: "S_FENCE",
}

# DMA fetch_mode enum (Dispatch_DMA.sv:29)
_FETCH_MODE_NAMES = {
    0: "LOAD", 1: "UPSAMPLE", 2: "CONCAT", 3: "STORE", 4: "COEFF", 5: "LUT",
}

# SA_Controller FSM enum (src/WeightStationarySA/SA_Controller.sv:40)
_SA_STATE_NAMES = {
    0: "IDLE", 1: "LOAD", 2: "RUN", 3: "DRAIN", 4: "DONE",
}


def _sa_state_name(s):
    return _SA_STATE_NAMES.get(s, f"SA_S{s}")


def opcode_name(op):
    return _OPCODE_NAMES.get(op, f"OP_0x{op:02X}")


def unit_name(uid):
    return _UNIT_NAMES.get(uid, f"UNIT_{uid}")


def _seq_state_name(s):
    return _SEQ_STATE_NAMES.get(s, f"STATE_{s}")


def _fetch_mode_name(m):
    return _FETCH_MODE_NAMES.get(m, f"MODE_{m}")


def _decode_unit_mask(mask):
    """6-bit mask -> 'DMA,SA,PSB' style string (units_done / fence_mask indexing)."""
    if mask is None:
        return "?"
    if mask == 0:
        return "(none)"
    names = []
    for uid, name in _UNIT_NAMES.items():
        if mask & (1 << uid):
            names.append(name)
    return ",".join(names)


def _safe_int(sig):
    try:
        return int(sig.value)
    except (ValueError, AttributeError):
        return None


class NpuObserver:
    def __init__(self, dut, log_file=None, stall_threshold=2000,
                 heartbeat_interval=1000):
        self._dut = dut
        self._stall_threshold = stall_threshold
        self._heartbeat_interval = heartbeat_interval
        self._cycle = 0
        self._last_event_cyc = 0
        self._stop = False
        self._fh = open(log_file, "w") if log_file else None
        # Summary counters
        self._n_dispatches = 0
        self._n_fences     = 0
        self._n_stalls     = 0
        self._n_errors     = 0

    async def start(self):
        cocotb.start_soon(self._run())

    def note(self, msg, tag="TOP"):
        """Log a one-off event from the test harness in the monitor's format.

        Use for edges the observer can't catch itself — e.g. irq_done, which
        ends the run on the same cycle stop() halts the monitor.
        """
        self._log(msg, tag=tag)

    async def stop(self):
        self._stop = True
        summary = (
            f"SUMMARY cycles={self._cycle} "
            f"dispatches={self._n_dispatches} "
            f"fences={self._n_fences} "
            f"stalls={self._n_stalls} "
            f"errors={self._n_errors}"
        )
        self._log(summary, tag="TOP", real=False)
        if self._fh:
            self._fh.close()
            self._fh = None

    def _log(self, msg, tag="TOP", real=True):
        line = f"[cyc {self._cycle:6d}] [{tag}] {msg}"
        self._dut._log.info(line)
        if self._fh:
            self._fh.write(line + "\n")
            self._fh.flush()
        if real:
            self._last_event_cyc = self._cycle

    def _dump_stall(self):
        dut = self._dut
        state = _safe_int(dut.sequence_unit.state)
        fm    = _safe_int(dut.sequence_unit.fence_mask)
        ud    = _safe_int(dut.units_done)
        self._log(f"STALL - no events in {self._stall_threshold} cycles", tag="TOP")
        self._log(f"  state         = {_seq_state_name(state)}", tag="   ", real=False)
        self._log(f"  fence_mask    = 0b{(fm or 0):06b} "
                  f"(waiting on {_decode_unit_mask(fm)})", tag="   ", real=False)
        self._log(f"  units_done    = 0b{(ud or 0):06b}", tag="   ", real=False)
        self._log(f"  dma_ch0_idle  = {_safe_int(dut.dma_ch0_idle_w)}", tag="   ", real=False)
        self._log(f"  dma_ch1_idle  = {_safe_int(dut.dma_ch1_idle_w)}", tag="   ", real=False)
        # DMA Ch0 internal state + HP0 AXI snapshot to bisect COEFF/LOAD hangs.
        dma_state = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.state)
        dma_ss    = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.store_state)
        cbr       = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.coeff_beats_received)
        cbt       = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.coeff_beats_total)
        cwa       = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.coeff_waddr_r)
        clb       = _safe_int(getattr(dut, 'dma_unit', None) and dut.dma_unit.coeff_last_beat)
        self._log(f"  dma_state     = {dma_state} (S_IDLE=0 S_PIXEL=1 S_AR=2 S_R=3 "
                  f"S_PAD=4 S_ADV=5 S_C_AR=6 S_C_R=7 S_C_WR1=8 S_L_AR=9 S_L_R=10 "
                  f"S_L_WR=11)", tag="   ", real=False)
        self._log(f"  dma_store_state = {dma_ss} (SS_IDLE=0)", tag="   ", real=False)
        self._log(f"  coeff_beats_received/total = {cbr}/{cbt}  "
                  f"coeff_waddr_r={cwa}  coeff_last_beat={clb}", tag="   ", real=False)
        self._log(f"  HP0 AR: arvalid={_safe_int(dut.dma_arvalid)} "
                  f"arready={_safe_int(dut.dma_arready)} "
                  f"araddr=0x{_safe_int(dut.dma_araddr) or 0:011x} "
                  f"arlen={_safe_int(dut.dma_arlen)}", tag="   ", real=False)
        self._log(f"  HP0 R : rvalid={_safe_int(dut.dma_rvalid)} "
                  f"rready={_safe_int(dut.dma_rready)} "
                  f"rlast={_safe_int(dut.dma_rlast)} "
                  f"rresp={_safe_int(dut.dma_rresp)}", tag="   ", real=False)
        for sig_name, label in (
            ("dma_to_sa",  "DMA->SA "), ("sa_to_dma",  "SA->DMA "),
            ("sa_to_psb",  "SA->PSB "), ("psb_to_sa",  "PSB->SA "),
            ("psb_to_req", "PSB->REQ"), ("req_to_psb", "REQ->PSB"),
            ("req_to_vpu", "REQ->VPU"), ("vpu_to_req", "VPU->REQ"),
            ("vpu_to_dma", "VPU->DMA"), ("dma_to_vpu", "DMA->VPU"),
        ):
            sig = getattr(dut, f"{sig_name}_empty", None)
            empty = _safe_int(sig) if sig is not None else None
            if empty is not None:
                self._log(f"  dep_{label} empty={empty}", tag="   ", real=False)

    async def _run(self):
        dut = self._dut
        prev_state     = None
        prev_fetch_err = 0
        prev_dma_err   = 0
        prev_bvalid    = 0
        last_awaddr    = 0
        last_wdata     = 0
        # Phase 3 rising-edge trackers
        prev = {
            "desc_start": 0, "ch1_start": 0,
            "ch0_idle": 0, "ch1_idle": 0,
            "sa_done": 0, "psb_done": 0, "req_done": 0, "vpu_done": 0,
            "act_bank_full": 0, "wt_bank_full": 0,
            "act_bank_read": 0, "wt_bank_read": 0,
            "store_done": 0, "irq_done": 0,
            "dma_arvalid": 0, "dma_arready_hs": 0, "dma_rvalid": 0, "dma_rlast_hs": 0,
        }
        dma_beat_count = 0
        prev_sa_state  = None
        S_FENCE = 4
        fence_enter_cyc       = 0
        disp_full_count       = [0] * 6
        disp_full_logged      = [False] * 6
        BACKPRESSURE_THRESH   = 100

        while not self._stop:
            await RisingEdge(dut.clk)
            self._cycle += 1

            if _safe_int(dut.rst):
                continue

            # --- CSR write decode (latch on handshake, log on bvalid rise) ---
            awv = _safe_int(dut.s_axil_awvalid)
            awr = _safe_int(dut.s_axil_awready)
            wv  = _safe_int(dut.s_axil_wvalid)
            wr  = _safe_int(dut.s_axil_wready)
            if awv and awr:
                last_awaddr = _safe_int(dut.s_axil_awaddr) or 0
            if wv and wr:
                last_wdata = _safe_int(dut.s_axil_wdata) or 0
            bv = _safe_int(dut.s_axil_bvalid) or 0
            if bv and not prev_bvalid:
                self._log(f"CSR write addr=0x{last_awaddr:02X} data=0x{last_wdata:08X}", tag="CSR")
            prev_bvalid = bv

            # --- Dispatch events (decode opcode from disp_payload[123:116]) ---
            disp_push = _safe_int(dut.disp_push) or 0
            if disp_push:
                pay = _safe_int(dut.disp_payload) or 0
                opcode = (pay >> 116) & 0xFF
                op = opcode_name(opcode)
                for bit in range(6):
                    if disp_push & (1 << bit):
                        self._log(f"DISPATCH {op} -> {_DISP_PUSH_BIT_TO_UNIT[bit]}", tag="SEQ")
                        self._n_dispatches += 1

            # --- Sequencer fetch-FSM transitions (FENCE arm/release decoded) ---
            state = _safe_int(dut.sequence_unit.state)
            if state is not None and prev_state is not None and state != prev_state:
                if state == S_FENCE:
                    fm = _safe_int(dut.sequence_unit.fence_mask)
                    self._log(f"FENCE armed, waiting on {_decode_unit_mask(fm)}", tag="SEQ")
                    fence_enter_cyc = self._cycle
                    self._n_fences += 1
                elif prev_state == S_FENCE:
                    self._log(f"FENCE released after "
                              f"{self._cycle - fence_enter_cyc} cyc", tag="SEQ")
                else:
                    self._log(f"FETCH_FSM {_seq_state_name(prev_state)} -> "
                              f"{_seq_state_name(state)}", tag="SEQ")
            if state is not None:
                prev_state = state

            # --- Error rising edges ---
            fe = _safe_int(dut.fetch_err) or 0
            if fe and not prev_fetch_err:
                self._log("ERROR fetch_err asserted", tag="SEQ")
                self._n_errors += 1
            prev_fetch_err = fe
            de = _safe_int(dut.dma_err) or 0
            if de and not prev_dma_err:
                self._log("ERROR dma_err asserted", tag="DMA")
                self._n_errors += 1
            prev_dma_err = de

            # --- Phase 3: per-unit datapath events (all rising-edge) ---
            ds = _safe_int(dut.desc_start_w) or 0
            if ds and not prev["desc_start"]:
                mode = _safe_int(dut.desc_fetch_mode_w) or 0
                src  = _safe_int(dut.desc_src_base_w) or 0
                self._log(f"Ch0 START mode={_fetch_mode_name(mode)} "
                          f"src=0x{src:08X}", tag="DMA")
            prev["desc_start"] = ds

            cs = _safe_int(dut.ch1_start_w) or 0
            if cs and not prev["ch1_start"]:
                src = _safe_int(dut.wt_src_base_w) or 0
                self._log(f"Ch1 START src=0x{src:08X}", tag="DMA")
            prev["ch1_start"] = cs

            i0 = _safe_int(dut.dma_ch0_idle_w) or 0
            if i0 and not prev["ch0_idle"]:
                self._log("Ch0 IDLE", tag="DMA")
            prev["ch0_idle"] = i0
            i1 = _safe_int(dut.dma_ch1_idle_w) or 0
            if i1 and not prev["ch1_idle"]:
                self._log("Ch1 IDLE", tag="DMA")
            prev["ch1_idle"] = i1

            for key, sig, tag in (
                ("sa_done",  dut.sa_done_pulse,  "SAR"),
                ("psb_done", dut.psb_done_pulse, "PSB"),
                ("req_done", dut.req_done_pulse, "REQ"),
                ("vpu_done", dut.vpu_done_pulse, "VPU"),
            ):
                v = _safe_int(sig) or 0
                if v and not prev[key]:
                    self._log("DONE", tag=tag)
                prev[key] = v

            # --- SA Controller FSM transitions ---
            sa_ps = _safe_int(getattr(
                getattr(getattr(getattr(dut, 'u_sa_block', None),
                        'Systolic_array', None), 'controller', None),
                'ps', None))
            if sa_ps is not None and prev_sa_state is not None and sa_ps != prev_sa_state:
                old_n = _sa_state_name(prev_sa_state)
                new_n = _sa_state_name(sa_ps)
                if sa_ps == 1:  # LOAD
                    self._log(f"{old_n}->{new_n}: weight loading started", tag="SAR")
                elif sa_ps == 2:  # RUN
                    self._log(f"{old_n}->{new_n}: weights loaded, activations streaming", tag="SAR")
                elif sa_ps == 3:  # DRAIN
                    self._log(f"{old_n}->{new_n}: activations done, draining pipeline", tag="SAR")
                elif sa_ps == 4:  # DONE
                    self._log(f"{old_n}->{new_n}: matmul complete", tag="SAR")
                elif sa_ps == 0:  # back to IDLE
                    self._log(f"{old_n}->{new_n}", tag="SAR")
                else:
                    self._log(f"{old_n}->{new_n}", tag="SAR")
            if sa_ps is not None:
                prev_sa_state = sa_ps

            abf = _safe_int(dut.dma_act_bank_full_w) or 0
            if abf and not prev["act_bank_full"]:
                self._log("ACT bank handoff DMA -> SA", tag="DMA")
            prev["act_bank_full"] = abf
            wbf = _safe_int(dut.dma_wt_bank_full_w) or 0
            if wbf and not prev["wt_bank_full"]:
                self._log("WT bank handoff DMA -> SA", tag="DMA")
            prev["wt_bank_full"] = wbf

            abr = _safe_int(dut.sa_act_bank_read_w) or 0
            if abr and not prev["act_bank_read"]:
                self._log("released ACT bank", tag="SAR")
            prev["act_bank_read"] = abr
            wbr = _safe_int(dut.sa_wt_bank_read_w) or 0
            if wbr and not prev["wt_bank_read"]:
                self._log("released WT bank", tag="SAR")
            prev["wt_bank_read"] = wbr

            sd = _safe_int(dut.dma_store_done_w) or 0
            if sd and not prev["store_done"]:
                self._log("DMA_STORE complete", tag="DMA")
            prev["store_done"] = sd

            # HP0 (dma_*) AXI handshake tracking — bisects Ch0 COEFF/LOAD hangs.
            arv = _safe_int(dut.dma_arvalid) or 0
            arr = _safe_int(dut.dma_arready) or 0
            if arv and not prev["dma_arvalid"]:
                araddr = _safe_int(dut.dma_araddr) or 0
                arlen  = _safe_int(dut.dma_arlen) or 0
                self._log(f"AR asserted addr=0x{araddr:011x} len={arlen} "
                          f"(burst beats={arlen+1})", tag="AXI")
            prev["dma_arvalid"] = arv
            ar_hs = 1 if (arv and arr) else 0
            if ar_hs and not prev["dma_arready_hs"]:
                self._log("AR handshake", tag="AXI")
                dma_beat_count = 0
            prev["dma_arready_hs"] = ar_hs
            rv = _safe_int(dut.dma_rvalid) or 0
            rr = _safe_int(dut.dma_rready) or 0
            rl = _safe_int(dut.dma_rlast) or 0
            r_hs = 1 if (rv and rr) else 0
            if r_hs and not prev["dma_rvalid"]:
                dma_beat_count += 1
                if rl or dma_beat_count <= 2:
                    self._log(f"R beat#{dma_beat_count} rlast={rl}", tag="AXI")
            prev["dma_rvalid"] = r_hs
            if rl and rv and rr and not prev["dma_rlast_hs"]:
                self._log(f"R rlast handshake on beat#{dma_beat_count}", tag="AXI")
            prev["dma_rlast_hs"] = 1 if (rl and rv and rr) else 0

            iq = _safe_int(dut.irq_done) or 0
            if iq and not prev["irq_done"]:
                self._log("IRQ_DONE", tag="TOP")
            prev["irq_done"] = iq

            # --- Phase 4: backpressure detector ---
            df = _safe_int(dut.disp_full) or 0
            for bit in range(6):
                if df & (1 << bit):
                    disp_full_count[bit] += 1
                    if (disp_full_count[bit] > BACKPRESSURE_THRESH
                            and not disp_full_logged[bit]):
                        self._log(f"BACKPRESSURE unit={_DISP_PUSH_BIT_TO_UNIT[bit]} "
                                  f"FIFO full >{BACKPRESSURE_THRESH} cyc", tag="SEQ")
                        disp_full_logged[bit] = True
                else:
                    disp_full_count[bit] = 0
                    disp_full_logged[bit] = False

            # --- Phase 4: stall detector ---
            if self._cycle - self._last_event_cyc >= self._stall_threshold:
                self._dump_stall()
                self._n_stalls += 1

            # --- Phase 4: heartbeat (only when otherwise quiet) ---
            if (self._heartbeat_interval > 0
                    and self._cycle % self._heartbeat_interval == 0
                    and self._cycle - self._last_event_cyc
                        >= self._heartbeat_interval):
                hb_state = _safe_int(dut.sequence_unit.state)
                hb_ud    = _safe_int(dut.units_done) or 0
                self._log(f"HB state={_seq_state_name(hb_state)} "
                          f"units_done=0b{hb_ud:06b}", tag="TOP", real=False)
