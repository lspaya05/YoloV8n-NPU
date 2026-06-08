# Analysis Task 02 — Systolic Array Timing & Completion

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

The Systolic Array is dispatched at cyc 55 but only begins weight LOAD at cyc 72
(17-cyc gap) and reaches RUN at cyc 88 — by which point the sequencer has already
drained all dispatches and STORE fires at cyc 93. SA never reaches DRAIN/DONE
before its result is consumed. Trace SA timing, the dispatch→LOAD latency, and
whether SA's done-pulse is correctly wired back to the sequencer and the
`dep_sa_to_psb` token.

## Files to read

| File | Why |
|------|-----|
| `src/WeightStationarySA/SA_top.sv` | top wrapper; `done` output, raddr ports, MatrixMul hookup |
| `src/WeightStationarySA/SA_Controller.sv` | IDLE→LOAD→RUN→DRAIN→DONE FSM, counters |
| `src/WeightStationarySA/ProcessingElement.sv` | PE MAC + weight latch behavior |
| `src/WeightStationarySA/MatrixMul.sv` | array interconnect / output collection |
| `src/NPU/Dispatch/Dispatch_SA.sv` | drives `start`, `sa_wt_raddr`, `sa_act_raddr`; observes `sa_done` |
| `src/NPU/Blocks/SA_Block.sv` | `sa_done_pulse`, `dep_sa_to_psb_push`, unit_done to sequencer |

## Questions to answer

1. Confirm the LOAD / RUN / DRAIN / DONE cycle counts for a 16×16 / K=16 tile.
   Does total ≈ 63 cyc? Where is DRAIN length computed?
2. What causes the **17-cycle gap** between MATMUL dispatch (cyc 55) and
   `IDLE->LOAD` (cyc 72)? (Weight-bank handoff? activation availability? a wait
   state in Dispatch_SA?)
3. Is `sa_done` / `controller_done` asserted exactly once and **routed to the
   sequencer `units_done`** and to `dep_sa_to_psb_push`? Trace both nets.
4. Do `sa_wt_raddr` and `sa_act_raddr` actually **advance** during LOAD/RUN
   (0→15)? If raddr is stuck, PEs latch garbage/zeros.
5. Does the SA output (`MatrixMulOut` / row outputs) become valid only at
   DRAIN/DONE? If PSB samples before DRAIN, it captures zeros.
6. Is there any path by which `start` could be re-pulsed or the FSM reset
   mid-run (e.g. a later dispatch touching SA)?

## Preliminary findings (Claude)

- Per RTL exploration: LOAD=16, RUN=16, DRAIN=ARRAY_H+ARRAY_L−2=30, DONE=1 →
  ~63 cyc. From dispatch (cyc 55) that lands done ≈ cyc 135, but IRQ_DONE is at
  cyc 100 — **SA result is never ready when consumed**.
- The 17-cyc dispatch→LOAD gap is unexplained and worth confirming; if the
  pipeline is non-blocking (see Task 01), this gap means downstream units run on
  stale/zero SA output.
- Even if SA finishes correctly, with no back-pressure the result arrives far too
  late — so this task and Task 01 (dep gating) are coupled.

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

### Q1 — LOAD/RUN/DRAIN/DONE counts (16x16, K=16): confirmed ≈63 cyc
`SA_Controller.sv:90-110`: LOAD=ARRAY_HEIGHT=16 (counter 0..15, `load_done` @ 15,
line 99), RUN=K_DIM=16 (`run_done` @ 15, line 103), DRAIN=ARRAY_HEIGHT+
ARRAY_LENGTH-2=30 (counter 0..29, `drain_done` @ counter==29, line 109), DONE=1
(unconditional `ns=IDLE`, line 149). Total = 16+16+30+1 = **63 cyc from `start`
sample to `done` pulse**. So `done` cannot land before `start_cyc + 63`,
regardless of anything else.

### Q2 — 17-cyc dispatch→LOAD gap: dominated by `deps_ready`, not Dispatch_SA's pipe
Pipeline-only latency from `disp_push` to `sa_start` is ~5 cyc: FIFO write→
`sa_fifo_empty` deassert (+1), `sa_fifo_pop_d` (+1), `sa_issue_valid` (+1)
(`SA_Block.sv:131-139`), then `sa_start<=1` (+1), `ps→LOAD` (+1). That alone
would put LOAD @ ~cyc 60, not 72.
The remaining ~12 cyc is gated by `deps_ready = ~dep_dma_to_sa_empty &
~dep_psb_to_sa_empty` (`SA_Block.sv:108`): while either upstream DepFIFO is
empty, `sa_empty_to_dispatch = ~sa_issue_valid | ~deps_ready` stays high
(line 109), so `Dispatch_SA.fifo_empty` never deasserts and `S_IDLE` can't fire
`sa_start` (`Dispatch_SA.sv:90-97`). This matches the wrapper's documented
"virtual fifo_empty=1 when upstream deps are not ready" behavior
(`SA_Block.sv:8-9`). **Conclusion: the 17-cyc gap is SA stalling on
`dep_dma_to_sa_push`/`dep_psb_to_sa_push` from DMA_Block/PSB_Block — not an SA
defect.** Confirming the exact arrival cycle requires those blocks' waveforms
(outside this task's file list, but worth a follow-up trace).

### Q3 — done / unit_done / dep_sa_to_psb_push: routed correctly, but at two different latencies
`controller_done_c` (`SA_Controller.sv:188-192`) pulses exactly once (DONE state
unconditionally returns to IDLE, line 149) →`SA_top.done`(line 80)→`sa_done_w`.
From there it forks:
- `sa_row_valid = sa_done_w` directly (`SA_Block.sv:167`) — same cycle as `done`.
- `Dispatch_SA.sa_done` only moves `S_RUNNING→S_FINISH` (line 118-120);
  `unit_done` (and therefore `sa_done_pulse`→`dep_sa_to_dma_push`/
  `dep_sa_to_psb_push`, `SA_Block.sv:122-123,166`) asserts exactly once, but
  **one cycle later**, in `S_FINISH` (lines 123-128).
Both nets are single-pulse and correctly wired to sequencer `unit_done` /
`dep_sa_to_psb_push`. The 1-cycle skew between them turns out to matter — see Q5.

### Q4 — sa_wt_raddr / sa_act_raddr: do advance 0→15, in lock-step with `counter`
Cycle-by-cycle trace of `Dispatch_SA.sv:89-121`: the `S_IDLE→S_RUNNING`
transition pre-loads `sa_wt_raddr<='0` / `phase_cnt<=0` the same edge `sa_start`
fires (lines 95-97), one cycle before `SA_Controller` enters LOAD. Net effect:
`sa_wt_raddr == counter` for every cycle of LOAD (counter 0..15), and
`sa_act_raddr == counter` for every cycle of RUN (`act_phase_cnt = phase_cnt -
LoadCyc`, lines 68-69, 111-115). Sequencing itself is correct and monotonic.
This is only "data-correct" if SRAMHub has exactly 1-cyc read latency (raddr is
asserted one cycle before `loadingWeight_c`/`validActivations` needs the
corresponding data). SRAMHub's actual latency isn't in this task's file set —
worth checking; a latency mismatch would shift every loaded weight/activation
row by a constant offset (could plausibly produce all-zero or garbage MACs).

### Q5 — `sa_row_valid` fires 2 cycles BEFORE `sa_row_out` data is valid (latent bug)
Confirmed: `MatrixMulOut`/`sa_row_out` only contains the *new* tile's result
once DRAIN fully flushes the array — `matrixMulOut_internal`
(`MatrixMul.sv:49,76`, the live bottom-row accumulator) is correct only at the
end of DRAIN, and `SA_top` captures it through a `done_prev`-delayed register
(`SA_top.sv:83-101`). Cycle-accurate trace (let C1 = the DONE-state cycle):
- **C1**: `controller_done_c`=`sa_done_w`=`sa_row_valid`=1. `done_prev` is still
  0 (it lags `controller_done_c` by 1 cyc, line 87) ⇒ `MatrixMulOut` is **not**
  updated yet — it still holds the *previous* tile's result (or reset zeros on
  tile #0, lines 91-96).
- **C2**: `done_prev`=1 ⇒ `MatrixMulOut<=matrixMulOut_internal` scheduled
  (lines 97-100).
- **C3**: `MatrixMulOut`/`sa_row_out` finally shows the *new*, correct result.
So `sa_row_valid` (`SA_Block.sv:167`, `assign sa_row_valid = sa_done_w;`) pulses
**at C1 — two cycles before `sa_row_out` is actually valid**. Any consumer that
samples `sa_row_out` on `sa_row_valid` would capture stale/zero data — exactly
the symptom this bug report describes.
Notably, `dep_sa_to_psb_push`/`unit_done` (Q3, asserted in `S_FINISH`, one cycle
after `sa_row_valid`) land **exactly on C3** — i.e. *that* path IS correctly
aligned with data validity by what looks like a fortunate coincidence of the
extra `S_FINISH` cycle in `Dispatch_SA`.
Per `PSB_Block.sv:16-17,173-177`, `sa_row_valid` is currently tied off
(`_unused_sa_row_valid`) — PSB drives its own `row_valid` from `Dispatch_PSB`,
gated instead by `dep_sa_to_psb_pop` (`PSB_Block.sv:101`, consuming the
correctly-timed `dep_sa_to_psb` token). So **this mistiming is latent — it does
not by itself explain today's all-zero output**, since PSB ignores
`sa_row_valid`. But:
  (a) it's a landmine: the header explicitly calls `sa_row_valid` "reserved for
      future use" (`PSB_Block.sv:16`) — wiring it up later reproduces this bug
      exactly.
  (b) whether PSB actually captures correct data now hinges entirely on
      `Dispatch_PSB`/`psb.sv` timing relative to the `dep_sa_to_psb` token —
      that's outside this task's file set (likely Task 01 territory).
**Recommend**: fix `SA_Block.sv:167` so `sa_row_valid` reflects data-valid (e.g.
derive it from the same point as `sa_done_pulse`, or from `done_prev`-style
capture-complete) — independent of whether PSB currently consumes it, since the
name promises "row is valid now."

### Q6 — no start re-pulse / FSM-reset hazard
`Dispatch_SA` only asserts `sa_start` from `S_IDLE` (`Dispatch_SA.sv:90-97`),
then holds `S_RUNNING` until it observes `sa_done` (lines 118-120), transits
through a dedicated `S_FINISH` (lines 123-128), and only then returns to
`S_IDLE` — a second MATMUL can't be popped nor `sa_start` re-pulsed while
`SA_Controller` is mid LOAD/RUN/DRAIN. Only synchronous `rst` can force
`SA_Controller` back to IDLE (`SA_Controller.sv:54-60`); no other internal
reset/re-trigger path exists. Confirmed safe.

### Cross-check against preliminary estimate
If `sa_start` pulses @ cyc 71 (one cycle before the observed LOAD-entry @ 72),
`done` lands @ 71+63 = **134** — matches the "≈ cyc 135" preliminary estimate
(off by rounding/which edge is "cyc 55"). Reinforces: **the SA result cannot
possibly be ready by IRQ_DONE @ cyc 100 / STORE @ cyc 93** — those consume
zeros/garbage no matter how the `deps_ready` stall (Q2) shakes out. This task
and Task 01 (pipeline/dep gating that lets the sequencer race ahead of SA) are
the same root cause from two angles.

### Summary of new findings
1. **Q2 root cause located**: 17-cyc gap = `deps_ready` stall in `SA_Block`
   (`SA_Block.sv:108-109`), not an SA/Dispatch_SA defect — points at
   DMA_Block/PSB_Block token-push timing as the next trace target.
2. **New concrete bug (Q5)**: `sa_row_valid` (`SA_Block.sv:167`) is asserted 2
   cycles before `sa_row_out` contains valid data — a capture-races-ahead-of-
   data bug, currently latent only because PSB ties the signal off
   (`PSB_Block.sv:173-177`) and uses the (correctly-timed) `dep_sa_to_psb`
   token + `Dispatch_PSB.row_valid` instead. Should be fixed regardless.
3. Q1, Q3, Q4, Q6 check out as implemented — no defects found in those areas
   (Q4 carries one unverified assumption: SRAMHub read latency == 1 cyc).
