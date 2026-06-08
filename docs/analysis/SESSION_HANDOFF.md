# Session Handoff — NPU Single-Layer All-Zeros Debug

**Date:** 2026-06-08 · **Branch:** main · **Sim:** cocotb + Verilator
**Status:** 🔴 root cause not yet confirmed — analysis briefs authored, agents not yet run.
**Read this first, then [README.md](README.md) for the task index.**

> **UPDATE 2026-06-08 — fixes implemented. See the [Resolution](#resolution--implemented-fix) section at the bottom.** The original "3 hypotheses" below were partially right but the dominant root cause turned out to be a **ping-pong buffer swap bug** that starved the systolic array of all weights/activations — not found by the static briefs (they checked SA address *logic*, never that real data arrived). Keep the analysis above for history; the bottom section is the current truth.

---

## Why this doc exists

A debug session was opened on `tb/CocoTB/NPU/test_single_layer.py` failing with an
all-zeros output. We investigated, formed hypotheses, and wrote 6 per-stage
analysis briefs for other agents to fill in. **No code was changed; no fix
attempted.** This doc lets a fresh context window pick up exactly where we left off.

---

## The failure

`test_single_layer.py` pushes one INT8 16×16 layer through the full pipeline and
asserts the DMA-stored result against a golden model. It fails:

```
Output mismatch:
  got      0x00000000000000000000000000000000
  expected 0x0803edf5ee04fcf6fff1fdecfb01f6f7
```

User's own read: *"the Systolic Array isn't finishing before it outputs its data."*
The evidence agrees.

## Cycle timeline (from the cocotb monitor log, 1 clk = 10 ns)

| cyc | event | significance |
|-----|-------|--------------|
| 31  | DISPATCH OP_COEFF_LOAD → DMA_Ch0 | program starts |
| 55  | DISPATCH OP_MATMUL → SA | matmul issued |
| 72  | SAR IDLE→LOAD | weight load starts — **17 cyc after dispatch** |
| 88  | SAR LOAD→RUN **and** FETCH_FSM S_AR→S_IDLE | **sequencer drained ALL 8 dispatches while SA just entered RUN** |
| 93  | DMA Ch0 START mode=STORE | store fires before SA drains |
| 100 | IRQ_DONE · SUMMARY dispatches=8 fences=0 stalls=0 | **0 fences, 0 stalls** |

SA needs ~63 cyc (16 LOAD + 16 RUN + 30 DRAIN + 1 DONE). At cyc 100 it has run
~28 cyc since LOAD started — nowhere near done. Output is read from an Output Bank
that was never validly written → all zeros.

## The program the test runs (no PSB_ACC!)

Order observed in the log (`build_standard_instrs` in `tb/CocoTB/NPU/npu_isa.py`):

```
CONFIG → COEFF_LOAD → WT_LOAD → DMA_LOAD → MATMUL → PSB_FLUSH → REQUANT → LUT_BYPASS → DMA_STORE
```

Note: **no `OP_PSB_ACC`** between MATMUL and PSB_FLUSH.

Instruction word (128-bit, `npu_isa.py`):
`opcode[127:120] | unit_id[119:116] | dep_flags[115:112] | payload[111:0]`
dep bits: `PUSH_NEXT=0x8 PUSH_PREV=0x4 POP_NEXT=0x2 POP_PREV=0x1`.
MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS all carry `dep_flags=0xF` (intended full
serialization) — yet HW shows `fences=0 stalls=0`.

---

## Our three working hypotheses (ranked)

1. **Missing `OP_PSB_ACC` → PSB flushes an empty buffer.**
   Prior RTL read suggests `psb.sv` populates its buffer only on `psb_acc`/
   `row_valid` pulses driven by Dispatch_PSB during `OP_PSB_ACC`. With no ACC op,
   the buffer is never written, so FLUSH emits the reset value (zeros). **Leading
   candidate.** Could be a pure microcode/testbench bug. → Tasks 03 & 06.

2. **Dep tokens don't actually gate dispatch.**
   `dep_flags=0xF` is set but `fences=0 stalls=0` and the sequencer reaches
   `S_IDLE` while SA is mid-RUN. Either HW doesn't decode/honor the dep bits, the
   python bit-positions/opcodes disagree with `src/packages/NPU_ISA_pkg.sv`, or
   dispatch reads tokens without holding issue. → Tasks 01 & 06.

3. **`irq_done` fires on sequencer-idle, not all-units-done.**
   The run "completes" at cyc 100 while SA/PSB are still working, and the test
   samples `store_words[0]` right after polling `irq_done`. Even with correct data
   this races the pipeline. → Tasks 01 & 06.

These compound: #2/#3 mean downstream units run on data that doesn't exist yet;
#1 means even with correct timing the buffer would be empty. A real fix likely
touches more than one.

---

## What we did NOT yet do (open work)

- Have not opened `src/NPU/Sequencer.sv`, `psb.sv`, the `Dispatch_*` /
  `*_Block.sv` files line-by-line to *confirm* the above (only summarized via an
  Explore pass — treat those summaries as unverified).
- Have not compared `tb/CocoTB/NPU/npu_isa.py` against
  `src/packages/NPU_ISA_pkg.sv` for opcode/dep-bit parity.
- Have not confirmed whether PSB is *supposed* to auto-capture SA rows (making
  PSB_ACC redundant) or whether the microcode is simply missing the op.
- Have not run the sim again or inspected waveforms (`dump.vcd` exists at repo root).
- **No code changes. No fix.**

## How to resume

1. Read [README.md](README.md) (index) and the 6 `ANALYSIS_0N_*.md` briefs. Each
   has Scope / Files-to-read / numbered Questions / preliminary findings / an empty
   **Findings (append below)** section.
2. Dispatch one agent per brief (or work them yourself), **static read-only**:
   read RTL/python, cite `file:line`, append answers under the Findings marker,
   change nothing else. Suggested order: **03 → 06 → 01 → 02 → 04 → 05**
   (start with the empty-buffer + microcode suspects).
3. Consolidate: once briefs are filled, confirm/refute the 3 hypotheses above and
   write the root cause + proposed fix. Only then touch `src/` or `tb/`.

## Key file map

- RTL: `src/NPU/{Sequencer,NPU,DMA}.sv`, `src/NPU/Dispatch/Dispatch_{SA,PSB,REQ,VPU,DMA}.sv`,
  `src/NPU/Blocks/{SA,PSB,Requant,VPU}_Block.sv`,
  `src/WeightStationarySA/{SA_top,SA_Controller,ProcessingElement,MatrixMul}.sv`,
  `src/Memory/{psb,DepFIFO,SRAMHub}.sv`, `src/RequantPipeline/RequantPipeline.sv`,
  `src/packages/{NPU_ISA_pkg,NPU_HW_params_pkg}.sv`
- TB: `tb/CocoTB/NPU/{test_single_layer,npu_isa,npu_bfm,npu_golden,npu_monitor}.py`
- Prior context: commit `50aa8e1` (requant ordering / PSB-token fix),
  `tb/CocoTB/NPU/NPU_MONITOR_SIGNALS.md`, `COCOTB_NPU_TESTS.md` (repo root).

---

# Resolution — implemented fix

**Date:** 2026-06-08 · **Method:** consolidated the 6 analyses, then iterated with
in-sim signal probes (cocotb + Verilator) to localise the true root cause.

## How the all-zeros bug actually broke down

The single all-zeros symptom was **four stacked bugs**. Fixing any one alone still
gave zeros. In dataflow order:

1. **Systolic array starved (dominant root cause).**
   `src/Memory/PingPongBuffer.sv` swapped banks only on `bank_full && bank_read`
   *in the same cycle*. Both are **1-cycle pulses** that never coincide
   (`bank_full` ≈ cyc 64 when the DMA finishes filling; `bank_read` ≈ cyc 135 when
   the SA finishes), so `bank_sel` was stuck at 0. At reset bank A is the SA-read
   side and the DMA writes bank B → **the SA always read the never-written bank A
   → `MatrixMulOut` = 0**. Proven in sim: `sa_wt_rdata`/`sa_act_rdata` were
   `0x0` for the entire run. *Not* caught by the static briefs.

2. **PSB buffer never populated.** PSB only wrote its buffer on `OP_PSB_ACC`, which
   the program never issues. (ANALYSIS_03.)

3. **Requant ran on data that didn't exist / store fired too early.**
   `dep_req_to_vpu` reset to 1 let VPU + `OP_DMA_STORE` + `irq_done` fire before
   the pipeline produced anything; Requant had no real handshake with PSB.
   (ANALYSIS_01/04.)

4. **(latent) `sa_row_valid` mistiming and `ChCount=1` per-channel broadcast.**
   (ANALYSIS_02 Q5 / ANALYSIS_04 Q2.)

> Correction to the briefs: their headline "add 16 `OP_PSB_ACC`" fix **would
> deadlock** — `PSB_Block` dep accounting allows only one PSB op per SA tile.
> Buffer population was instead done via the reserved SA-driven `sa_row_valid`
> capture path.

## Files changed (RTL)

| File | Change |
|------|--------|
| `src/Memory/PingPongBuffer.sv` | **Bank-swap rewrite** — latch the `bank_full`/`bank_read` pulses until consumed; prime the SA side on the first fill. Fixes the starved-SA root cause. |
| `src/NPU/NPU.sv` | `dep_req_to_vpu` DepFIFO reset count `1→0` (RAW must start empty); thread `req_armed_w` (Requant→PSB); `Requant_Block` `ChCount 1→16`. |
| `src/NPU/Blocks/SA_Block.sv` | `sa_row_valid` (and the PSB token) now sourced from a 1-cycle-delayed `sa_done_pulse` so PSB captures a settled `sa_row_out` (avoids an NBA same-edge read of `MatrixMulOut`). |
| `src/Memory/psb.sv` | New `sa_capture` input + S_IDLE accumulate path: latches the SA result row into `buffer[0]` without entering S_ACC (matrix-vector path; no `OP_PSB_ACC` needed). |
| `src/NPU/Blocks/PSB_Block.sv` | Wire `sa_row_valid→psb.sa_capture`; add `requant_armed` and pass to `Dispatch_PSB`. |
| `src/NPU/Dispatch/Dispatch_PSB.sv` | Gate `OP_PSB_FLUSH` on `requant_armed` so flush rows aren't emitted before Requant is in FROM_PSB. |
| `src/NPU/Blocks/Requant_Block.sv` | Expose `req_armed = (mode==FROM_PSB)`; simplify `deps_ready` to the WAR gate only; suppress now-unused `_full` inputs. |
| `src/NPU/Dispatch/Dispatch_REQ.sv` | Parameterize the coeff-load counter width (was 3-bit, overflowed at `ChCount=16`). |

## Files changed (TB / microcode)

| File | Change |
|------|--------|
| `tb/CocoTB/NPU/npu_isa.py` | REQUANT beat count = 1 (matrix-vector: one output vector). No `OP_PSB_ACC` added. |
| `tb/{Memory,misc}/psb_tb.sv`, `tb/NPU/Dispatch/Dispatch_PSB_tb.sv`, `tb/NPU/Blocks/{PSB_Block,Requant_Block}_tb.sv` | Connect the new ports (`sa_capture=0`, `requant_armed=1`, declare `req_armed`) so the standalone ModelSim TBs still compile. ⚠️ Their accumulate/flush testcases may need re-tuning given the new `sa_capture` path. |
| `tb/CocoTB/NPU/test_single_layer.py` | **TEMP** `_diag_probe` instrumentation (req M coeff / `buffer[0]` / SA output / bank rdata). **Remove once the suite is green.** |

## Verified in sim (cocotb + Verilator)

- Ordering fixed: SA fully drains (DONE ~cyc 136) **before** REQ→VPU→STORE→IRQ.
- Diagnostics localised the residual zero precisely: M coeffs loaded `=1` ✓,
  `buffer[0]=0`, `sa_row_out=0`, **`sa_wt_rdata`/`sa_act_rdata`=0** → SA starved →
  PingPongBuffer swap bug.

## Status / next steps

- [x] Re-run `test_single_layer_interface.py` — **PASSES** (golden output).
- [x] Remove the `_diag_probe` instrumentation from `test_single_layer.py`.
- [x] Run the rest of the suite — **all green** (`quant_stress`, `zero_delay`,
      `source_starvation`, `sink_backpressure` + `single_layer` = 5/5 pass).
- [ ] **Re-verify ModelSim TBs (needs Questa, not runnable in WSL/Verilator):**
      `Dispatch_SA_tb.sv` assertions updated for the new weight-addr lead;
      `SA_top_tb.sv` golden-capture is coupled to the OLD single-shot capture and
      will need its reference model re-tuned to the de-skew timing — unverified.
- [ ] Add a non-uniform per-channel M/S `gen_tile` to actually exercise `ChCount=16`.

---

# Resolution 2 — single-layer GREEN (2026-06-08)

The PingPong fix (Resolution 1) removed SA starvation but exposed **two more
stacked bugs**, both now fixed; the full cocotb NPU suite is bit-exact green.

## Root causes found (via in-sim probing, see git history of `test_single_layer.py`)

1. **Missing output de-skew (all-zeros).** The systolic array emits its bottom
   row **diagonally** — column *j* is valid only on drain-cycle *j*, then
   overwritten. The old `SA_top` `done_prev` logic took **one** snapshot at DONE
   (~15 cyc after the wavefront had passed) → captured zeros. The PSB then
   faithfully stored those zeros. **Fix:** `src/WeightStationarySA/SA_top.sv` —
   replaced the single-shot capture with a **drain-phase diagonal collector** that
   latches each column on its own valid cycle (keyed off `validActivations`
   falling edge) and holds the assembled row.

2. **Weight-load off-by-one (wrong values).** `PingPongBuffer.sv` has a 1-cycle
   **registered read** (`r_data <= bank[r_addr]`); `Dispatch_SA` drove the read
   address aligned with the LOAD latch → W[0] loaded twice, W[15] dropped.
   **Fix:** `src/NPU/Dispatch/Dispatch_SA.sv` — weight read address now **leads
   `phase_cnt` by one** (`phase_cnt+1`) to hide the latency.

3. **Weight orientation (transpose contract).** The array loads row-packed weight
   words into its *columns* and so computes `loadedᵀ @ A`; the layer needs
   `W @ A`. **Fix (by design choice):** store weights **pre-transposed** in the
   weight memory image — `tb/CocoTB/NPU/npu_golden.py` `build_wt_mem` now packs
   `W.T[::-1]` (transpose + row-reverse, matching the load's reversal). Golden
   stays `W @ A`. This is the accelerator's weight-layout contract (host
   pre-transposes), not an RTL bug.

Proven in-sim before/after: `collected == pe.T @ A` and `dact == A` (engine +
activation feed correct); after fixes `pe == W.T` ⇒ output `== W @ A`.

## Files changed this resolution

| File | Change |
|------|--------|
| `src/WeightStationarySA/SA_top.sv` | Diagonal drain-phase output collector (replaces `done_prev` single-shot capture). |
| `src/NPU/Dispatch/Dispatch_SA.sv` | Weight read addr leads by one cycle (BRAM read-latency compensation). |
| `tb/CocoTB/NPU/npu_golden.py` | `build_wt_mem` packs `W.T[::-1]` (pre-transposed weight contract). |
| `tb/CocoTB/NPU/test_single_layer.py` | Removed temporary `_diag_probe` instrumentation. |
| `tb/NPU/Dispatch/Dispatch_SA_tb.sv` | Updated weight-addr-walk assertions for the new lead. |

⚠️ **Not yet re-verified (no Questa here):** `SA_top_tb.sv` reference-capture is
tied to the old capture timing and likely needs its golden model updated.
