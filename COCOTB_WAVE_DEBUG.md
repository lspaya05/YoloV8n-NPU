# CocoTB GTKWave Dump Debug Log

## Goal
Generate a `dump.fst` (or `dump.vcd`) waveform file from the CocoTB/Verilator simulation of the NPU so it can be opened in GTKWave.

---

## Environment

- **OS:** Windows 11, tests run via WSL/Conda
- **Python env:** `/home/lspaya/miniconda3/envs/HWBench` (Python 3.11)
- **Verilator root:** `/home/lspaya/miniconda3/envs/HWBench/share/verilator`
- **cocotb version:** 2.0.1
- **cocotb_test version:** 0.2.6
- **Test runner:** `pytest` via `cocotb_test.simulator.run()`
- **Sim binary output dir:** `sim_build/NPU_build/`
- **Sim binary:** `sim_build/NPU_build/NPU`

---

## Key Files

- Interface file (the pytest runner): `tb/CocoTB/NPU/test_single_layer_interface.py`
- CocoTB Verilator harness (C++): `/home/lspaya/miniconda3/envs/HWBench/lib/python3.11/site-packages/cocotb/share/lib/verilator/verilator.cpp`
- cocotb_test runner: `/home/lspaya/miniconda3/envs/HWBench/lib/python3.11/site-packages/cocotb_test/simulator.py`

---

## What We Learned About the Stack

### cocotb_test `run()` parameter map (Verilator)

| Parameter | What it does |
|---|---|
| `compile_args` | Passed to the `verilator` elaboration command |
| `waves=True` | Automatically appends `--trace-fst --trace-structs` to `compile_args` |
| `plus_args` | Appended to the sim binary command: `[sim_build/NPU_build/NPU] + plus_args` |
| `sim_args` | Maps to `self.simulation_args` — **NOT used in Verilator runner** (only used for Questa/Icarus etc.) |
| `extra_env` | Sets env vars for the subprocess, but **NOT read by `run()` itself** at init time |
| `build_args` | **Does not exist** in cocotb_test 0.2.6 — silently ignored |

### `verilator.cpp` runtime behavior

The CocoTB Verilator harness (`verilator.cpp`) controls whether a dump file is written. Relevant excerpt:

```cpp
// Line 75-100
#if VM_TRACE_FST
    const char *traceFile = "dump.fst";
#else
    const char *traceFile = "dump.vcd";
#endif
bool traceOn = false;

for (int i = 1; i < argc; i++) {
    std::string arg = argv[i];
    if (arg == "--trace") {
        traceOn = true;         // must receive --trace at runtime
    } else if (arg == "--trace-file") {
        traceFile = argv[++i];  // optional custom path
    }
}

// Line 132-136
Verilated::traceEverOn(true);
if (traceOn) {
    tfp = new verilated_trace_t;
    top->trace(tfp, 99);
    tfp->open(traceFile);       // writes to cwd = sim_build/NPU_build/
}
```

**Two things must both be true to get a dump:**
1. Binary compiled with `--trace-fst` (sets `VM_TRACE_FST=1`) — controlled by `waves=True`
2. Binary invoked with `--trace` as a runtime arg — controlled by `plus_args=['--trace']`

The dump file is written relative to `cwd`, which cocotb_test sets to `self.work_dir = self.sim_dir = sim_build/NPU_build/`. So the expected output is `sim_build/NPU_build/dump.fst`.

---

## What Was Tried

### Attempt 1 — Original state (already in file, didn't work)
```python
build_args=['--sv', '--timing', ..., '--trace'],
extra_env={'WAVES': '1'},
```
**Result:** `traceCapable = false` in `Vtop.h`. `build_args` is not a valid cocotb_test 0.2.6 parameter — silently ignored. `--trace` never reached Verilator. No dump file.

### Attempt 2 — Added `--trace-depth 0`
```python
build_args=['--sv', '--timing', ..., '--trace', '--trace-depth', '0'],
extra_env={'WAVES': '1', 'COCOTB_ENABLE_WAVES': '1'},
```
**Result:** Same — `build_args` still ignored, `traceCapable = false`. No dump file.

### Attempt 3 — Switched to `compile_args` + `waves=True`
```python
compile_args=['--sv', '--timing', ..., '--public'],
waves=True,
```
**Result:** `traceCapable = true` ✅. `Vtop__Trace__0.cpp` and `verilated_fst_c.o` now present in build dir. But **no `dump.fst`** — the runtime harness was never told to open the file.

### Attempt 4 — Added `plus_args=['--trace']`
```python
compile_args=['--sv', '--timing', ..., '--public'],
waves=True,
plus_args=['--trace'],
```
**Current state of all interface files.** Expected `dump.fst` at `sim_build/NPU_build/dump.fst`. **Still not appearing.**

---

## Current State of Interface File

```python
def test_single_layer_interface():
    run(
        verilog_sources=get_npu_sources(),
        toplevel='NPU',
        module='test_single_layer',
        simulator='verilator',
        timescale='1ns/1ps',
        compile_args=['--sv', '--timing',
                      '-Wno-TIMESCALEMOD', '-Wno-INITIALDLY',
                      '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC', '--public'],
        waves=True,
        plus_args=['--trace'],
        sim_build='sim_build/NPU_build',
    )
```

---

## What We Know Is True

- `traceCapable = true` in `sim_build/NPU_build/Vtop.h` — FST support IS compiled in
- `Vtop__Trace__0.cpp`, `verilated_fst_c.o` present — Verilator elaborated with `--trace-fst`
- No `dump.fst` or `dump.vcd` anywhere in the repo after a full run
- The sim binary IS running (results XML `*_results.xml` appears in `sim_build/NPU_build/` after each run)
- The test times out at 50k cycles (separate bug, unrelated to waves)

---

## Unknown / Not Yet Verified

- Whether `plus_args=['--trace']` is actually being appended to the sim binary invocation at runtime (not confirmed via subprocess logging)
- Whether cocotb_test 0.2.6 changes `cwd` to `sim_dir` before launching the binary or launches from the project root
- Whether there is a cocotb 2.x-specific mechanism that intercepts or overrides the `--trace` arg before it reaches `verilator.cpp`
- Whether the sim binary crashes/exits before `tfp->open()` is called (the test does timeout, so the binary may be exiting abnormally)
