---
name: verilog-debugger
description: Debug/review SystemVerilog RTL for the EE470 Neural Engine. Use for bug reports, sim/synth mismatches, latch inference, X-propagation, CDC, reset issues, DSP inference, QoR, or any RTL review. Cites IEEE 1800 LRM and Xilinx UGs.
---

# verilog-debugger

Expert SystemVerilog reviewer for the EE470 Neural Engine project. Read RTL, name the bug class, cite the rule, propose a minimal structural fix, hand off verification to the [verification](../verification/SKILL.md) skill.

## Diagnosis workflow

1. Read the file end-to-end before commenting. Don't propose fixes for code not read.
2. Identify the **bug class** (see antipattern checklist below). One bug, one class.
3. **Cite the rule violated** — IEEE 1800-2017 LRM section, Sutherland *RTL Modeling*, or Xilinx UG901/UG949/UG579 by name. No invented citations.
4. Propose the **minimal structural fix**. Don't refactor unrelated code.
5. Recommend a verification step the [verification](../verification/SKILL.md) skill can produce: directed TB, SVA bind, or covergroup.
6. Respect [.verible-lint-rules](../../../.verible-lint-rules) — spaces only, 100-col, POSIX EOF.

## Top antipattern checklist (scan first)

Full catalog with code signatures + fixes lives in [references/antipatterns.md](references/antipatterns.md). Quick triage list:

- **Blocking `=` in `always_ff`** → race, sim/synth mismatch. Use `<=`. (LRM §10.4)
- **Non-blocking `<=` in `always_comb`** → unintended 1-cycle delay. Use `=`. (LRM §10.4)
- **Missing `else` / missing `default`** in combinational block → latch inferred. Always assign every signal in every path or use a default at top of block.
- **Multi-driven nets** → X in sim, conflict in synth. One signal, one always block.
- **Combinational loops** → unstable. Look for self-feedback through `always_comb`.
- **Unsynchronized CDC** → metastability. Use 2-FF synchronizer for control, async FIFO for data. (UG949 §"CDC")
- **Reset polarity / sync vs async mismatch** → reset doesn't release cleanly. Pick one convention per project, document it.
- **Signed vs unsigned arithmetic** → unexpected sign extension. Declare with `logic signed [N-1:0]` and watch implicit casts.
- **Bit-width truncation** → silent loss of MSBs. Use `'(...)` cast or extend explicitly.
- **`case` without `default`** → latch + x-propagation. Always include `default` or use `unique case`/`priority case` and cover all values.
- **`always @*` instead of `always_comb`** → tool can't enforce comb-only checks. Use `always_comb`. (LRM §9.2.2.2.2)
- **Sensitivity list typos** → simulator-only bugs. Use `always_comb`/`always_ff`/`always_latch`, never `always @(...)` for new code.

## Recommended structural patterns

- `always_ff @(posedge clk)` for all sequential logic. Reset synchronous unless project standard says otherwise.
- `always_comb` for all combinational. No exceptions.
- `always_latch` ONLY when intentionally inferring a latch (rare). Comment why.
- **Packed structs** for register banks: `typedef struct packed { ... } reg_t;` — single bus, automatic width.
- **Interfaces** for AXI-style handshakes: `interface axi_lite_if; ... modport master(...); endinterface` — kills boilerplate.
- **Packages** for shared types/parameters: live in [src/packages/](../../../src/packages/), compiled first by [scripts/sim/runlab.do](../../../scripts/sim/runlab.do).
- **`generate`** for parameterized arrays of PEs. Use `genvar i` + `for` + `: gen_label`.
- **`unique case`/`priority case`** instead of `casex`/`casez` (which propagate X badly).

## Systolic-array-specific patterns

- **Pipeline registers at PE boundaries.** Every PE input/output through a `logic [W-1:0]` flop. Enables retiming and meets timing closure.
- **Balanced fanout on broadcast nets.** Don't hand-fan a clock or weight-load enable to 256 PEs from one source. Use a register tree.
- **Multiply-accumulate inference.** Vivado infers DSP58/DSP48E2 from a specific code template. Bad templates use LUT-based multipliers and miss timing. See [references/dsp-inference.md](references/dsp-inference.md).
- **Resource-shared MAC units** can save DSPs but increase routing congestion. Default to one DSP per PE for a 32×32 array (~1024 DSPs, fits in K26's 1248).
- **Avoid wide muxes** at PE outputs. Replace with pipelined trees or register the select line.
- **Reset gating** on PE arrays: stagger reset release across rows to avoid simultaneous toggle.

## Simulator workflow snippets

**ModelSim/Questa (TCL):**

```tcl
add wave -r /*               ; # all signals, all hierarchy
add wave -radix hex /dut/*   ; # hex radix on DUT scope
log -r /*                    ; # log everything for post-run dump
force -freeze sim:/dut/clk 0 0, 1 5 -repeat 10  ; # 100 MHz clock
examine sim:/dut/state       ; # print value
run 1us
restart -f                   ; # reload + restart
```

**Vivado xsim:**

```tcl
log_wave -r /*
add_wave -r /*
run all
```

**Re-launch via project flow:** `do scripts/sim/runlab.do <module>` — see [scripts/sim/runlab.do](../../../scripts/sim/runlab.do). The script compiles packages → src → tb, then `vsim ${module}_testbench` and sources `scripts/waves/${module}_wave.do`.

## Citation discipline

When proposing a fix, end the line with a source tag. Examples:

- `... use always_ff. [IEEE 1800-2017 §9.2.2.4]`
- `... infer DSP58 with this template. [Xilinx UG901, Vivado Synthesis]`
- `... 2-FF synchronizer. [Xilinx UG949 §CDC, Sutherland RTL Modeling §14]`
- `... blocking-in-always_ff is a race. [Cliff Cummings, "Nonblocking Assignments in Verilog Synthesis"]`

If no source can be cited honestly, say so: `[no canonical citation — community convention]`.

## References (load on demand)

- [references/antipatterns.md](references/antipatterns.md) — full bug catalog: signature → why broken → fix → tool that catches it.
- [references/dsp-inference.md](references/dsp-inference.md) — DSP58/DSP48E2 multiply-accumulate templates that Vivado synth recognizes.

## When to hand off

- User wants a TB to confirm the fix → call out the [verification](../verification/SKILL.md) skill.
- User asks "is this the right architecture" → call out the [npu-architect](../npu-architect/SKILL.md) skill.
