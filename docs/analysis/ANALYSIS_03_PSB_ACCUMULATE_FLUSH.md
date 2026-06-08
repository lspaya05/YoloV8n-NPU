# Analysis Task 03 — PSB Accumulate vs Flush

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

The Partial-Sum Buffer (PSB) holds SA row results and flushes them downstream to
Requant. The test program goes **`OP_MATMUL` → `OP_PSB_FLUSH` with no
`OP_PSB_ACC`** in between. Determine whether SA rows ever land in the PSB buffer,
and whether FLUSH on an unpopulated buffer emits zeros — a prime suspect for the
all-zeros output.

## Files to read

| File | Why |
|------|-----|
| `src/Memory/psb.sv` | PSB FSM: S_ACC accumulate (per `psb_acc`/`row_valid`), S_FLUSH emit, `acc_done`/`flush_done`, `psb_busy` |
| `src/NPU/Blocks/PSB_Block.sv` | wires SA row in, dep tokens (`dep_sa_to_psb`), drives psb control |
| `src/NPU/Dispatch/Dispatch_PSB.sv` | how OP_PSB_ACC vs OP_PSB_FLUSH drive `psb_acc`/`psb_flush`; idle wait |

## Questions to answer

1. Does the PSB buffer get populated **only** on `OP_PSB_ACC` pulses, or is
   accumulation automatic while SA streams (e.g. driven by `sa_row_valid`)?
2. With **no OP_PSB_ACC** in the program, what is in the buffer when
   `OP_PSB_FLUSH` runs? Zeros? Stale data? Quote the reset/initial buffer state.
3. Trace S_FLUSH: per cycle it drives `requant_row_out = buffer[flush_row_count]`
   with `row_out_valid`. Is the data combinational off the buffer, and does
   `flush_row_count` advance 0→15?
4. Does FLUSH wait for `!psb_busy` before starting? If SA hasn't finished (Task
   02), is `psb_busy` ever asserted by a phantom ACC?
5. Re-examine the 50aa8e1 fix (Requant no longer waits on `dep_psb_to_req`
   token). Did removing that token open a race where FLUSH rows are emitted
   before Requant is listening?
6. Is `sa_row_valid` (from SA) connected to the PSB accumulate enable at all? If
   not, the SA→PSB data path is broken regardless of microcode.

## Preliminary findings (Claude)

- The program sequence is COEFF → WT → ACT → **MATMUL → PSB_FLUSH** → REQUANT →
  LUT_BYPASS → STORE. **No PSB_ACC** appears (confirmed in log:
  no `OP_PSB_ACC` dispatch line; `dispatches=8`).
- Prior RTL exploration states the buffer accumulates on `psb_acc`/`row_valid`
  pulses driven by Dispatch_PSB during OP_PSB_ACC. If that op is the only writer,
  the buffer is never written → FLUSH emits the reset value (likely 0) → all-zeros
  output. **This is a leading root-cause candidate.**
- Need to confirm whether the design intends PSB to auto-capture SA rows
  (making PSB_ACC redundant) or whether the microcode is simply missing the ACC
  op (a testbench bug — see Task 06).

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

### Q1 — ACC-pulse-only or auto-streamed?

ACC-pulse-only; **no auto-capture path exists in RTL**.

- `psb.sv:186-192` writes `buffer[acc_row_count]` only in `S_ACC` gated by
  `row_valid`; `psb.sv:194-200` is a fast-path first-row write in `S_IDLE`
  gated by `psb_acc && row_valid`. The FSM only *enters* `S_ACC` when
  `psb_acc` is asserted (`psb.sv:69-70`).
- `Dispatch_PSB.sv:78-84` pulses `psb_acc`/`row_valid`/`unit_done` for exactly
  one cycle, **only** in the `OP_PSB_ACC` branch — "Fire one row of
  accumulation per instr" (header comment, `Dispatch_PSB.sv:4-9`).
- `PSB_Block.sv:173-177` states outright that `sa_row_valid` is "reserved for
  future use ... currently psb.row_valid is sourced from Dispatch_PSB" and
  ties it to `_unused_sa_row_valid`. The SA→PSB row strobe is wired straight
  to the data input (`sa_row_in`, `NPU.sv` muxing) but the *valid/enable* is
  100% microcode-driven.

### Q2 — buffer contents at FLUSH with no ACC

All-zero — confirmed.

- Reset clears `buffer` to `'0` (`psb.sv:178-183`), and `S_FLUSH_DONE` clears
  it again to `'0` after every completed flush (`psb.sv:207-213`).
- Since the program never issues `OP_PSB_ACC` (per the "Preliminary findings"
  log: `dispatches=8`, no `OP_PSB_ACC` line), no write path (`S_ACC` nor the
  `S_IDLE` fast path) is ever taken. The buffer is therefore still holding its
  post-reset value — all zeros — for all 16 rows when `OP_PSB_FLUSH` runs.

### Q3 — S_FLUSH trace

Confirmed as described:

- `requant_row_out` is driven combinationally off `buffer[flush_row_count]`
  in an `always_comb` (`psb.sv:226-232`); it is effectively the registered
  buffer contents (zero, per Q2) presented one column-pack at a time.
- `flush_row_count` increments 0→15, one per cycle, while `!last_flush_row`
  (`psb.sv:164-167`, `LastRow = ARRAY_HEIGHT-1 = 15` at `psb.sv:62-64`);
  `row_out_valid=1` is held for the full `S_FLUSH` window
  (`psb.sv:115-118`); transition to `S_FLUSH_DONE` happens on
  `last_flush_row` (`psb.sv:84-89`). Full 16-row sweep confirmed, all zero.

### Q4 — does FLUSH wait on `!psb_busy`; any phantom ACC?

Yes it waits (`Dispatch_PSB.sv:90 if (!psb_busy)`), and **no phantom ACC is
possible**:

- `psb_busy` (`psb.busy`) is asserted only in `S_ACC`/`S_FLUSH`/`S_ACC_DONE`/
  `S_FLUSH_DONE` (`psb.sv:106-137`); `S_IDLE` drives `busy = 0`
  (`psb.sv:107-109`).
- The FSM can only leave `S_IDLE` toward `S_ACC` via `psb_acc`
  (`psb.sv:69-70`), and `psb_acc` is pulsed exclusively by the `OP_PSB_ACC`
  branch of `Dispatch_PSB` (`Dispatch_PSB.sv:78-84`), which never fires here.
  So `busy` stays low continuously and `OP_PSB_FLUSH` is dispatched
  immediately — it is **not** blocked or delayed by Task 02's SA-finishing
  issue through this path.

### Q5 — 50aa8e1 fix / `dep_psb_to_req` race — SECOND independent root cause

Confirmed: the token removal described in 50aa8e1 is real, but more
importantly there is a live, structural race between `PSB_FLUSH` and
`OP_REQUANT` configuration that **independently** causes zero output, even if
Q1/Q2 were fixed.

- `Requant_Block.sv:107-108` — `deps_ready` for issuing `Dispatch_REQ` no
  longer includes `dep_psb_to_req_empty` (only `dep_vpu_to_req_empty` and the
  two downstream-full signals). The PSB→Requant token is now only *popped*
  opportunistically on `req_done_pulse` (`Requant_Block.sv:113`), never
  *waited on* — matches the commit's description of removing the
  force-wait.
- The actual row datapath is wired with **no buffering**: PSB's
  `row_out_valid`/`requant_row_out` go straight (combinationally) to
  `Requant_Block.psb_row_valid`/`psb_row_in` and into
  `RequantPipeline.psb_row_valid_i`/`psb_row_i`
  (`NPU.sv:766-768` → `NPU.sv:806-807`).
- `RequantPipeline` only treats `psb_row_valid_i` as the lane-valid source
  when `mode_i == 2'b01` (`FROM_PSB`); in `mode_i == 2'b00` (`FROM_SRAM`,
  the reset/idle value) it instead samples `lane_valid_i = sram_a_valid_i`
  (`RequantPipeline.sv:75-77`), which `Requant_Block.sv:187` ties to a
  constant `1'b0`.
- `Dispatch_REQ` resets `req_mode <= 2'b00` (`Dispatch_REQ.sv:91`) and *holds*
  it at `2'b00` through `S_IDLE` (`Dispatch_REQ.sv:109`) and the entire
  `S_LOAD_COEFF` coefficient-load sequence (`Dispatch_REQ.sv:128-150`); it
  only raises `req_mode <= 2'b01` on the cycle the last coefficient is
  captured, when it transitions to `S_RUN` (`Dispatch_REQ.sv:148-149`).
- The module's own header even documents the assumed concurrency:
  "`psb_row_valid_i` is driven externally by `psb.row_out_valid` during a
  **parallel** PSB_FLUSH; this dispatch only configures the pipeline"
  (`Dispatch_REQ.sv:12-13`).

  **Net effect:** while `Dispatch_REQ` is still popping its FIFO entry and
  walking through `S_LOAD_COEFF` (mode held at `FROM_SRAM`, lane-valid forced
  to the tied-off `sram_a_valid_i = 0`), every `psb_row_valid_i` pulse from
  the in-flight `PSB_FLUSH` is silently swallowed — never latched into any
  pipeline stage. By the time `req_mode` finally becomes `FROM_PSB`
  (`S_RUN`), the 16-row flush sweep is already over and `row_out_valid` has
  dropped. This is *exactly* what the 50aa8e1 commit message says: "Requant
  was waiting for PSB token that only appeared after PSB_FLUSH, but the row
  data already passed by then" — except the same hazard persists post-fix,
  just without the token-wait masking/serializing it. **Even with a populated
  PSB buffer (Q1/Q2 fixed), this sequencing bug alone would still produce
  zero valid `RequantPipeline` beats and zero Output-Bank writes.**

### Q6 — is `sa_row_valid` wired to the PSB accumulate enable?

No — confirmed broken/unconnected as a control signal (data path is fine).

- `PSB_Block.sv:173-177`: `sa_row_valid` is explicitly tied to
  `_unused_sa_row_valid` with the comment "reserved for future use ... not
  driving psb internally." `psb.row_valid` comes solely from
  `Dispatch_PSB.row_valid`, which only pulses on `OP_PSB_ACC` retirement
  (`Dispatch_PSB.sv:78-84`).
- This is consistent with — not contradictory to — Q1: the design's
  *intended* mechanism for SA→PSB capture is explicit per-row `OP_PSB_ACC`
  microcode (see `Dispatch_PSB.sv:4-9` header: "Fire one row of accumulation
  per instr ... After 16 PSB_ACCs psb pulses acc_done"), not an
  SA-driven auto-capture. `sa_row_valid` being parked as reserved/unused
  strongly suggests the auto-capture idea was considered and deliberately
  deferred, not that it's the live mechanism with a wiring bug.

### Conclusion

This resolves the "design intent" question raised in Preliminary Findings:
the RTL clearly intends **explicit microcode-driven accumulation**
(`OP_PSB_ACC` × 16, one per SA output row, before `OP_PSB_FLUSH`). The test
program omits all 16 `OP_PSB_ACC` ops — **a microcode/testbench bug** (see
Task 06) — which alone is sufficient to produce all-zero PSB→Requant rows
(Q1/Q2/Q4).

However, **even a corrected microcode sequence would not be sufficient on its
own**: Q5 identifies a second, independent RTL sequencing bug — `PSB_FLUSH`
and `OP_REQUANT` config race, with the pipeline's `lane_valid` gated off
during `Dispatch_REQ`'s `S_IDLE`/`S_LOAD_COEFF` window — that drops the
flushed rows on the floor regardless of whether the buffer holds real data.
Both issues likely need to be fixed for non-zero NPU output: (1) add
`OP_PSB_ACC` instructions to the test program, AND (2) resequence so
`Dispatch_REQ` reaches `mode_i = FROM_PSB` (`S_RUN`) *before* `PSB_FLUSH`
begins emitting rows (e.g. gate `psb_flush` on a "Requant pipeline armed"
signal, or have the Sequencer serialize REQUANT-config ahead of FLUSH rather
than relying on the documented "parallel" assumption).
