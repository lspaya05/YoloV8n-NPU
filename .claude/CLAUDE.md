Always be extremely concise. Sacrifice grammar for the sake of concision.

# EE470 Final Project — Neural Engine

SystemVerilog Neural Engine, systolic array dataflow, target = AMD Kria **KR260** (K26 SOM, Zynq UltraScale+ MPSoC). For board specs, dataflow choices, sizing, papers — use the [npu-architect](skills/npu-architect/SKILL.md) skill.

## Toolchain (pinned)

- RTL: SystemVerilog (IEEE 1800-2017)
- Synth/impl: **Vivado 2025**
- Sim: **Questa/ModelSim** primary, **Vivado xsim** secondary
- Verif: UVM 1.2 / IEEE 1800.2, SVA
- Lint: Verible — see [.verible-lint-rules](../.verible-lint-rules)
- IP: AMD/Xilinx (AXI Interconnect, AXI DMA, FIFO Generator, BRAM Ctrl, FP Operator)

## Repo map

- [src/](../src/) — RTL (`*.sv`)
- [src/packages/](../src/packages/) — shared `package`/typedefs, compiled first
- [tb/](../tb/) — testbenches, `<module>_testbench.sv`
- [scripts/sim/](../scripts/sim/) — ModelSim launchers; entrypoint [scripts/sim/runlab.do](../scripts/sim/runlab.do)
- [scripts/waves/](../scripts/waves/) — `<module>_wave.do`
- [vivado/](../vivado/) — Vivado project (most outputs gitignored)
- [notes](../notes/) — reference notes for designers.
- [notes/papers/](../notes/papers/) — reference PDFs
- [benchmarks/](../benchmarks/) — perf data

## What NOT to do

- No tabs in `.sv`. Spaces only.
- Don't commit `work/`, `*.wlf`, `transcript`, Vivado `*.runs/`, `.Xil/` — already in [.gitignore](../.gitignore).
- Don't rename testbenches off the `<module>_testbench.sv` pattern — breaks runlab.do.
- Don't modify [scripts/sim/runlab.do](../scripts/sim/runlab.do) without partner sign-off.
- Don't invent citations in [npu-architect](skills/npu-architect/SKILL.md) output. Unknown = say unknown.
