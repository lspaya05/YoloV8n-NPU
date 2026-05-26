---
paths:
  - "tb/**/*.sv"
  - "scripts/sim/**"
  - "scripts/waves/**"
---

# Sim flow + testbench contract

Single source of truth: [scripts/sim/runlab.do](../../scripts/sim/runlab.do).

## Naming contract (DO NOT BREAK)

- Every TB file: `tb/<module>_tb.sv`
- Every TB top module name: `<module>_tb` (file name minus `.sv`)
- Every wave file: `scripts/waves/<module>_wave.do`

Breaking any of these breaks `runlab.do`.

## Compile + run order

`do scripts/sim/runlab.do <module>` →

1. `vlog src/packages/*.sv`  (packages first)
2. `vlog src/*.sv`
3. `vlog tb/*.sv`
4. `vsim ${module}_tb`
5. `do scripts/waves/${module}_wave.do`
6. `run -all`

## TB requirements

- `import` only from [src/packages/](../../src/packages/) — anything else won't compile.
- Print `PASS` / `FAIL` to transcript.
- End with `$finish` (not `$stop`).
- Pair with at least `add wave -r /*` in the matching `<module>_wave.do`.

## Guardrails

- Don't modify [scripts/sim/runlab.do](../../scripts/sim/runlab.do) without partner sign-off.
- For UVM: append `+UVM_TESTNAME=<test>` via Questa CLI; don't silently mutate runlab.do.
