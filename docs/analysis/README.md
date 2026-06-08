# NPU Single-Layer All-Zeros — Analysis Task Index

**Target:** AMD Kria KR260 (Zynq UltraScale+ MPSoC) · 16×16 weight-stationary systolic array
**Sim:** cocotb + Verilator · `tb/CocoTB/NPU/test_single_layer.py`
**Status:** 🔴 failing — `DMA_STORE` output all-zeros vs golden `0x0803edf5ee04fcf6fff1fdecfb01f6f7`

---

## Bug TL;DR

`test_single_layer.py` runs a single INT8 16×16 layer through the full NPU pipeline
(COEFF → WT → ACT → MATMUL → PSB_FLUSH → REQUANT → LUT_BYPASS → DMA_STORE).
The store comes back **all-zeros**. Symptom: the **Systolic Array does not finish
before the output is produced** — the run "completes" (IRQ_DONE) while SA is still
mid-compute.

## Cycle-timeline evidence (1 clk = 10 ns)

| cyc | event | note |
|-----|-------|------|
| 31  | `DISPATCH OP_COEFF_LOAD -> DMA_Ch0` | program start |
| 55  | `DISPATCH OP_MATMUL -> SA` | matmul issued |
| 72  | `SAR IDLE->LOAD` | weight load starts **17 cyc after dispatch** |
| 88  | `SAR LOAD->RUN` + `FETCH_FSM S_AR -> S_IDLE` | **sequencer drained all 8 dispatches while SA just entered RUN** |
| 93  | `DMA Ch0 START mode=STORE` | store fires before SA drains |
| 100 | `IRQ_DONE` · `SUMMARY cycles=100 dispatches=8 fences=0 stalls=0` | **0 fences, 0 stalls** |

SA needs ~63 cyc (16 LOAD + 16 RUN + 30 DRAIN + 1 DONE) and never reaches
DRAIN/DONE before STORE.

## Top hypotheses (to confirm/refute)

1. **Dep tokens not gating dispatch** — microcode sets `dep_flags=0xF` on
   MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS, yet `fences=0 stalls=0`. No RAW/WAR stall fired.
2. **Missing `OP_PSB_ACC`** — program jumps MATMUL → PSB_FLUSH; PSB likely flushes
   an empty buffer → zeros.
3. **IRQ_DONE = sequencer-idle, not all-units-done** — run completes while SA/PSB still working.

---

## Analysis tasks (one agent each)

| # | File | Scope |
|---|------|-------|
| 01 | [ANALYSIS_01_SEQUENCER_DISPATCH.md](ANALYSIS_01_SEQUENCER_DISPATCH.md) | Sequencer FSM, dispatch, DepFIFO dep-token gating, fence, `irq_done` semantics |
| 02 | [ANALYSIS_02_SYSTOLIC_ARRAY.md](ANALYSIS_02_SYSTOLIC_ARRAY.md) | SA LOAD/RUN/DRAIN timing, done-pulse wiring, dispatch→LOAD gap |
| 03 | [ANALYSIS_03_PSB_ACCUMULATE_FLUSH.md](ANALYSIS_03_PSB_ACCUMULATE_FLUSH.md) | PSB accumulate vs flush; missing PSB_ACC; empty-buffer flush |
| 04 | [ANALYSIS_04_REQUANT_VPU_OUTBANK.md](ANALYSIS_04_REQUANT_VPU_OUTBANK.md) | Requant pipeline, VPU, output-bank write mux |
| 05 | [ANALYSIS_05_DMA_STORE_OUTPUT.md](ANALYSIS_05_DMA_STORE_OUTPUT.md) | DMA store FSM, output-bank read, AXI write capture, endianness |
| 06 | [ANALYSIS_06_TESTBENCH_MICROCODE.md](ANALYSIS_06_TESTBENCH_MICROCODE.md) | test + microcode + golden correctness; python vs HW ISA package |

---

## Rules for analysis agents

1. **Static read-only.** Read RTL / python / logs. **Do not run the simulator.**
2. **No code changes.** Edit nothing in `src/` or `tb/`.
3. **Append only.** Write your findings under the `## Findings (append below)`
   section of your assigned file. Do not edit the brief above that marker.
4. **Cite `file:line`** for every claim (e.g. `src/NPU/Sequencer.sv:333`).
5. Answer the numbered questions explicitly; flag anything that contradicts the
   preliminary findings.
