# Bug Handoff — DMA Ch0 hangs in COEFF_LOAD

**Status:** open, blocks [tb/CocoTB/NPU/test_single_layer.py](tb/CocoTB/NPU/test_single_layer.py) (times out at 50k cyc).
**Discovered by:** cocotb observer [tb/CocoTB/NPU/npu_monitor.py](tb/CocoTB/NPU/npu_monitor.py) on baseline run.
**Reader:** RTL specialist agent — start at "Where to look" then "Reproduction".

---

## TL;DR

DMA Ch0 fires START for `OP_COEFF_LOAD` at cyc 39, then **never asserts `ch0_idle`**. `dma_ch0_idle_w` stays low for the rest of the run. Because `Dispatch_DMA` waits on `dma_ch0_idle` before popping the next Ch0 FIFO entry, the queued `OP_DMA_LOAD` and `OP_DMA_STORE` never launch. Activations never land in SRAM, SA never gets a dep token, every downstream unit blocks. Cascade-stall → IRQ never fires → test timeout.

WT_LOAD path (DMA Ch1, HP1) works correctly. Sequencer + dispatch fanout work correctly. Bug is **isolated to the DMA Ch0 COEFF_LOAD completion path**.

---

## Evidence (from monitor log)

Full instruction set is the 9-entry `build_standard_instrs()` in [tb/CocoTB/NPU/npu_isa.py:113-138](tb/CocoTB/NPU/npu_isa.py#L113-L138).

What fired:

```
[cyc     4] CSR write addr=0x00 data=0x00000000     (instr_base)
[cyc     9] CSR write addr=0x04 data=0x00000009     (instr_count=9)
[cyc    14] CSR write addr=0x08 data=0x00000001     (kick)
[cyc    33] DISPATCH OP_COEFF_LOAD -> DMA_Ch0
[cyc    39] DMA Ch0 START mode=COEFF src=0x00000000   <-- starts here
[cyc    42] DISPATCH OP_WT_LOAD    -> DMA_Ch1
[cyc    47] DMA Ch1 START src=0x00006000
[cyc    51] DISPATCH OP_DMA_LOAD   -> DMA_Ch0          (queued in Ch0 FIFO)
[cyc    60] DISPATCH OP_MATMUL     -> SA
[cyc    68] WT bank handoff DMA -> SA                  (Ch1 finished)
[cyc    69] DMA Ch1 IDLE
[cyc    69] DISPATCH OP_PSB_FLUSH  -> PSB
[cyc    78] DISPATCH OP_REQUANT    -> REQ
[cyc    87] DISPATCH OP_LUT_BYPASS -> VPU
[cyc    91] VPU DONE                                   (LUT_BYPASS pass-through)
[cyc    96] DISPATCH OP_DMA_STORE  -> DMA_Ch0          (queued)
[cyc    97] FETCH_FSM S_AR -> S_IDLE                   (Sequencer done)
```

(`OP_CONFIG` not in DISPATCH log is correct — Sequencer absorbs it as a CSR shadow update, no FIFO push.)

What never fired:

- `DMA Ch0 IDLE` (for COEFF_LOAD, DMA_LOAD, or DMA_STORE)
- `DMA Ch0 START mode=LOAD` (instr 4 stuck in Ch0 FIFO)
- `DMA Ch0 START mode=STORE` (instr 9 stuck in Ch0 FIFO)
- `ACT bank handoff DMA -> SA`
- `SA released ACT bank`, `SA released WT bank`
- `SA DONE`, `PSB DONE`, `REQ DONE`
- `DMA_STORE complete`, `IRQ_DONE`

Stall snapshot (repeats every 2000 cyc, identical from cyc 2097 onward):

```
state         = S_IDLE
fence_mask    = 0b000000
units_done    = 0b000000
dma_ch0_idle  = 0          <-- THE smoking gun
dma_ch1_idle  = 1
dep_DMA->SA   empty=1      (DMA never pushed RAW token to SA)
dep_SA->PSB   empty=1
dep_PSB->REQ  empty=1
dep_REQ->VPU  empty=1
dep_DMA->VPU  empty=1
(all WAR FIFOs empty=0 -- reset-injected credit)
```

---

## Where to look

### Primary suspect: DMA Ch0 COEFF_LOAD completion path

**Files:**

- [src/NPU/DMA.sv](src/NPU/DMA.sv) — the DMA unit. The Ch0 FSM is here. Look for whatever state handles `desc_fetch_mode == 3'b100` (COEFF, per [src/NPU/Dispatch/Dispatch_DMA.sv:29](src/NPU/Dispatch/Dispatch_DMA.sv#L29)). Find the path that drops back to idle / asserts `ch0_idle`.
- [src/NPU/Dispatch/Dispatch_DMA.sv](src/NPU/Dispatch/Dispatch_DMA.sv) — confirms it pops the next Ch0 instr only when `dma_ch0_idle` is high (line ~474 wiring in [src/NPU/NPU.sv:474](src/NPU/NPU.sv#L474)). So if Ch0 FSM never returns to idle, the queued LOAD/STORE never get a `desc_start_w` pulse.

**Three failure modes to bisect, in order of likelihood:**

1. **AXI read never completes.** COEFF_LOAD issues an HP0 read for the coeff payload at `src=0x00000000`. If `dma_rlast` never arrives (e.g., the test memory backing `0x0000` returns zero beats, or burst length is wrong for COEFF), the FSM waits forever. Check `dma_arvalid` / `dma_arready` / `dma_rvalid` / `dma_rlast` in the fst around cyc 39 onward.
2. **COEFF write loop terminate condition wrong.** COEFF_LOAD writes `coeff_ch_count` channels into the coeff BRAM via `dma_coeff_wen_w`/`dma_coeff_waddr_w` (wired at [src/NPU/NPU.sv:686-688](src/NPU/NPU.sv#L686-L688)). If the write counter never matches the target (off-by-one, wrong field decode, `desc_coeff_ch_count` mis-latched), the FSM loops on a never-true `done` condition.
3. **COEFF state has no exit at all.** Phase 6 of the DMA wiring (per `memory/project_dma_phase1.md`: "Phase 6 (COEFF/LUT/ISA) next") was the upcoming phase, not yet signed off — the COEFF path may be a stub.

### Signals worth scoping in the .fst at cyc 39 → 200

```
dut.dma_unit.<ch0_state_signal>          -- internal FSM state
dut.dma_arvalid, dma_arready, dma_araddr, dma_arlen
dut.dma_rvalid,  dma_rready,  dma_rdata,  dma_rlast
dut.dma_coeff_wen_w, dut.dma_coeff_waddr_w, dut.dma_coeff_wdata_w
dut.desc_coeff_ch_count_w     (target count latched in Dispatch_DMA)
dut.dma_ch0_idle_w            (will stay 0 through bug)
```

The cocotb runner already passes `--public` ([tb/CocoTB/NPU/test_single_layer_interface.py:23](tb/CocoTB/NPU/test_single_layer_interface.py#L23)) so every internal net is in the dump.

### Test-memory check (cheaper than RTL spelunking)

If `dma_arvalid` rises but `dma_rvalid` never does, the bug is in the test BFM, not RTL. Check `build_dma_mem(A, M, S)` in [tb/CocoTB/NPU/npu_golden.py](tb/CocoTB/NPU/npu_golden.py) — does it populate the word address `0x0000` (where COEFF_LOAD reads from per `make_coeff_load_payload(ch_count, 0x0000)` at [tb/CocoTB/NPU/npu_isa.py:119](tb/CocoTB/NPU/npu_isa.py#L119))? If not, AXI4ReadSlave returns 0 and the burst may never `rlast`.

---

## Reproduction

```
pytest tb/CocoTB/NPU/test_single_layer_interface.py
```

(via WSL/HWBench conda env per [COCOTB_WAVE_DEBUG.md](COCOTB_WAVE_DEBUG.md)).

The test will hang for 50k cycles and time out with `TimeoutError: irq_done not received within 50000 cycles`. Wave dump at `sim_build/NPU_build/dump.fst`. Monitor log goes to stdout (cocotb logger). Pass `log_file="monitor.log"` to `NpuObserver` in [tb/CocoTB/NPU/test_single_layer.py](tb/CocoTB/NPU/test_single_layer.py) if you want the events in a separate file for diffing.

---

## What is NOT the bug (don't waste time here)

- **Sequencer fetch / dispatch fanout.** All 8 dispatchable instructions decoded correctly, FETCH_FSM transitions clean, instructions queued in the right per-unit FIFOs.
- **DMA Ch1 / HP1 / WT_LOAD path.** Completes at cyc 69 with bank handoff. Working.
- **AXI-Lite CSR.** Three writes complete cleanly at cyc 4/9/14.
- **VPU `OP_LUT_BYPASS`.** Done pulse at cyc 91. Trivial pass-through, working.
- **Dep-FIFO RAW/WAR mechanism.** Looks correct given the upstream stall — WAR FIFOs have reset-injected credits, RAW FIFOs empty because producers never ran.
- **`FENCE armed/released` lines absent.** Not a bug — this 9-instr program doesn't use the Sequencer's `S_FENCE` state; ordering is via dep-FIFOs only.
- **Cyc-1 `DMA Ch0/Ch1 IDLE` lines.** Monitor cosmetic: rising-edge detector sees `prev=0 → cur=1` on first sample post-reset. Both signals are 1 at idle. Ignore.

---

## Context for the fix

- `OP_COEFF_LOAD` is "Phase 6" of the DMA bring-up (per `memory/project_dma_phase1.md` — Phase 5 signed off, Phase 6 = COEFF/LUT/ISA, pending).
- Architecture reference: [notes/Architecture-FINAL/](notes/Architecture-FINAL/) and [notes/NPU_debug_signals.md](notes/NPU_debug_signals.md) for signal catalog.
- Instruction-set source of truth: [tb/CocoTB/NPU/npu_isa.py](tb/CocoTB/NPU/npu_isa.py) (Python encoder) — payload format documented in `make_coeff_load_payload()`.

---

## Investigation log (2026-06-07)

### What was tried and what happened

**1. RTL counter backstop (DMA.sv)**
Added `coeff_beats_received[8:0]` register to DMA Ch0 COEFF FSM. Purpose: exit COEFF FSM via a beat counter even if `hp0_rlast` is missed. The counter increments on each R-channel handshake in `S_C_R`, and `coeff_last_beat` is ORed with `(coeff_beats_received == coeff_beats_total - 1)`.

**Result: did NOT fix the hang.** The counter never increments because `hp0_rvalid` never goes high — no beats arrive at all.

**2. BFM strict-AXI compliance (npu_bfm.py)**
Original BFM `AXI4ReadSlave._run()` drove `rvalid` for exactly 1 cycle then dropped it, regardless of `rready`. This violated AMBA IHI 0022 §A3.2.1: VALID must be held until handshake (VALID && READY). Fixed the BFM to hold `rvalid+rdata+rlast` until `rready` rises.

**Result: did NOT fix the hang (combined with RTL fix above).** `behavior.txt` output is identical. The BFM fix is correct for protocol compliance, but the real issue is upstream — R-channel data transfer never begins.

**3. Enhanced monitor (npu_monitor.py)**
Added:
- HP0 AXI handshake tracking: AR assert, AR handshake, R beats, R rlast handshake
- DMA internal state dump in stall snapshot: `dma_unit.state`, `store_state`, `coeff_beats_received`, `coeff_beats_total`, `coeff_waddr_r`, `coeff_last_beat`
- HP0 AR/R signal snapshot in stall dump
- SA Controller FSM transition tracking: logs IDLE→LOAD (weight loading), LOAD→RUN (activations streaming), RUN→DRAIN (draining), DRAIN→DONE (matmul complete)

**Result: not yet run.** Awaiting next test execution to capture enhanced output.

### Root cause narrowed but not yet identified

Both fixes failed because **zero R-channel beats arrive**. The failure is earlier in the pipeline than originally hypothesized. Remaining candidates (ordered by likelihood):

| # | Hypothesis | What enhanced monitor will show |
|---|---|---|
| 1 | `hp0_arvalid` never asserts — S_C_AR doesn't drive it | Stall dump: `dma_state=6` (S_C_AR), no "HP0 AR asserted" log line |
| 2 | AR fires but BFM never accepts (arready never rises) | "HP0 AR asserted" appears, no "HP0 AR handshake" |
| 3 | AR handshakes but BFM doesn't drive rvalid (mem lookup fails, X-prop kills coroutine) | "HP0 AR handshake" appears, no "HP0 R beat#1" |
| 4 | Signal name mismatch in Verilator for `dma_*` prefix | arvalid shows in stall dump but BFM prefix doesn't match |

### Files modified

- `src/NPU/DMA.sv` — added `coeff_beats_received` register + backstop OR in S_C_R
- `tb/CocoTB/NPU/npu_bfm.py` — strict-AXI rvalid hold-until-handshake in `AXI4ReadSlave._run()`
- `tb/CocoTB/NPU/npu_monitor.py` — HP0 handshake tracking, DMA stall details, SA FSM tracking

### Next steps for continuing agent

1. **Run `pytest tb/CocoTB/NPU/test_single_layer_interface.py`** and read the enhanced stall dump output.
2. Use the bisection table above to identify which hypothesis matches.
3. If hypothesis #1: check DMA.sv S_C_AR body (lines 628-637) — is `hp0_arvalid` actually driven in COEFF path? The `hp0_arvalid` assign at line ~402 may only cover `S_AR` (LOAD path), not `S_C_AR`.
4. If hypothesis #3: check that `AXI4ReadSlave` `dma` instance receives the correct mem dict with coeff words at addresses matching `hp0_araddr >> 4`.
5. If hypothesis #4: check Verilator signal mapping — the BFM uses prefix `dma` but top-level ports may be `dma_ar*` not `hp0_ar*`.
