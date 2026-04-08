---
name: verification
description: Write SystemVerilog testbenches, UVM envs, SVA, or covergroups for the EE470 Neural Engine. Use for "testbench", "smoke test", "UVM", "scoreboard", "assertion", "coverage", or verifying a DUT. Obeys runlab.do naming contract.
---

# verification

Expert testbench / UVM / SVA author for the EE470 Neural Engine project. Default behavior depends on the user prompt and the size of the DUT.

## Decide which TB style

| User said... | Use | Reference |
|---|---|---|
| "quick TB", "smoke test", "simple testbench", "show me waveforms" | Directed SV | [references/directed-tb-template.md](references/directed-tb-template.md) |
| "UVM", "constrained random", "scoreboard", "agent", "factory", "regression" | Full UVM env | [references/uvm-skeleton.md](references/uvm-skeleton.md) |
| "assertion", "property", "formal", "bind", "AXI handshake check" | SVA | [references/sva-cookbook.md](references/sva-cookbook.md) |
| "cover", "covergroup", "coverpoint", "functional coverage" | Covergroup (in any of the above) | this file §Coverage |

When unclear, ask: "Directed TB or full UVM env?". Default to **directed** for single-PE / FIFO / counter level DUTs and **UVM** for the top-level systolic array, AXI agents, and regression-style verification.

## Project flow integration (every TB must obey)

The single source of truth is [scripts/sim/runlab.do](../../../scripts/sim/runlab.do):

```tcl
vlog ${project_root}/src/packages/*.sv
vlog ${project_root}/src/*.sv
vlog ${project_root}/tb/*.sv
vsim -voptargs="+acc" -t 1ps -lib work ${module}_testbench
do ${project_root}/scripts/waves/${module}_wave.do
run -all
```

So every TB MUST:

1. Live at `tb/<module>_testbench.sv`.
2. Declare `module <module>_testbench;` (top module name = file name minus `.sv`).
3. Have a paired `scripts/waves/<module>_wave.do` with at least `add wave -r /*`.
4. Print `PASS` or `FAIL` to the transcript and call `$finish` (don't `$stop`).
5. Only `import` from packages in [src/packages/](../../../src/packages/) — anything else won't be compiled.

If the user wants UVM, also extend the runlab.do invocation with `+UVM_TESTNAME=<test>` (note this in the response — don't silently break the script).

## Directed TB checklist

Use [references/directed-tb-template.md](references/directed-tb-template.md) as the starting skeleton, then customize:

- [ ] Clock generator (`always #5 clk = ~clk;` for 100 MHz / 10 ns period)
- [ ] Reset generator (assert N cycles, deassert sync to clock)
- [ ] DUT instantiation with all ports connected
- [ ] Stimulus task(s) — separate from main initial block
- [ ] Golden-model task or function — pure SV reference
- [ ] Self-check: `assert(actual === expected) else begin $error(...); fail_count++; end`
- [ ] PASS/FAIL print at end based on `fail_count`
- [ ] `$finish` (not `$stop`)
- [ ] `$dumpfile`/`$dumpvars` for VCD if cross-tool, otherwise rely on Questa wlf
- [ ] Optional: `covergroup` for input/state space

## UVM checklist (IEEE 1800.2 / Accellera UVM 1.2)

Use [references/uvm-skeleton.md](references/uvm-skeleton.md). Components needed:

- `uvm_pkg` import + `` `include "uvm_macros.svh" ``
- **Transaction** (`uvm_sequence_item`)
- **Sequence** (`uvm_sequence #(txn)`)
- **Sequencer** (`uvm_sequencer #(txn)`)
- **Driver** (`uvm_driver #(txn)`) — drives the virtual interface
- **Monitor** (`uvm_monitor`) — passive, publishes via analysis port
- **Agent** (`uvm_agent`) — wraps driver/monitor/sequencer, configurable active/passive
- **Scoreboard** (`uvm_scoreboard`) — analysis_imp, compares against ref model
- **Reference model** (regular SV class or DPI to C/Python golden)
- **Env** (`uvm_env`) — instantiates agents, scoreboard, virtual sequencer
- **Base test** (`uvm_test`) — sets config_db, builds env, starts virtual sequence
- **Top module** — declares clk/rst/interface, instantiates DUT, calls `run_test()`
- `+UVM_TESTNAME=<test_class>` plusarg to select test

Tie-in to runlab.do: the top module must still be named `<module>_testbench` to satisfy [scripts/sim/runlab.do](../../../scripts/sim/runlab.do). User runs `do scripts/sim/runlab.do <module>` and adds `+UVM_TESTNAME=...` via Questa CLI or by editing runlab.do.

## SVA checklist

Use [references/sva-cookbook.md](references/sva-cookbook.md). Key patterns:

- **Immediate** assertions (`assert (cond) else $error(...);`) — inline in always blocks for simple invariants.
- **Concurrent** assertions (`property` + `assert property`) — clocked, multi-cycle.
- Use `$past`, `$rose`, `$fell`, `$stable` for temporal expressions.
- `disable iff (!rst_n)` to gate assertions during reset.
- **Bind to RTL** from a separate file so the production RTL stays clean:
  ```sv
  bind dut_module dut_assertions u_asserts (.*);
  ```
- For the systolic array, prioritize: AXI4-Lite handshake, FIFO full/empty correctness, pipeline-valid propagation, one-hot state encodings.

## Coverage

Write a `covergroup` when:

- Input space has structural classes worth tracking (e.g., AXI burst types, weight values that exercise sign extension).
- State machine has corner transitions you want to prove you hit.
- A systolic array boundary tile has different behavior than interior tiles — cover both.

```sv
covergroup pe_cg @(posedge clk);
    cp_a: coverpoint a { bins zero = {0}; bins neg = {[-128:-1]}; bins pos = {[1:127]}; }
    cp_b: coverpoint b { bins zero = {0}; bins neg = {[-128:-1]}; bins pos = {[1:127]}; }
    cross cp_a, cp_b;
endgroup
```

Enable code coverage in Questa: `vsim -coverage -coverstore covdb`. Report with `vcover report covdb`.

## Waveform conventions

Every `<module>_wave.do` should at minimum:

```tcl
add wave -r /*
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
```

For systolic-array TBs, group signals: `add wave -group "PE[0][0]" /tb/dut/pe[0][0]/*`, etc.

## Citation discipline

When the user asks "why this pattern", cite:

- Accellera UVM 1.2 User Guide: https://www.accellera.org/downloads/standards/uvm
- IEEE 1800-2017 SystemVerilog LRM (SVA chapters §16)
- Sutherland, *SystemVerilog Assertions Handbook* (4th ed.)
- Mentor/Siemens Verification Academy UVM cookbook: https://verificationacademy.com/cookbook/uvm
- Spear & Tumbush, *SystemVerilog for Verification* (3rd ed.)

If unsure, say so. Don't invent UVM API names.

## References (load on demand)

- [references/directed-tb-template.md](references/directed-tb-template.md) — copy-paste directed TB skeleton.
- [references/uvm-skeleton.md](references/uvm-skeleton.md) — minimal full UVM env.
- [references/sva-cookbook.md](references/sva-cookbook.md) — bind-able SVA properties for AXI, FIFO, pipelines.

## Hand-off

- Bug found while writing TB → call out [verilog-debugger](../verilog-debugger/SKILL.md).
- "Should this even be tested this way?" / architectural question → call out [npu-architect](../npu-architect/SKILL.md).
