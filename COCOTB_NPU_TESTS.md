# CocoTB NPU Test Suite

**Target:** NPU top-level (`src/NPU/NPU.sv`) — 16×16 weight-stationary systolic array, INT8/INT32, targeting KR260 @ 300 MHz  
**Simulator:** Verilator (via `cocotb_test`)  
**Location:** `tb/CocoTB/NPU/`

---

## What We Are Building

A Python CocoTB test suite that validates the NPU end-to-end through its AXI4 memory interfaces. Every test drives the NPU from the outside only (no internal signal peeking) using three custom Python BFMs that model DDR4 memory. The suite covers three verification goals and one metrics goal:

1. **Functional & Math Accuracy** — verify INT8 output matches a NumPy golden model exactly
2. **Quantization Stress** — feed extreme data patterns to confirm the INT32 accumulator never overflows
3. **AXI Protocol Resilience** — inject source starvation and sink backpressure; confirm the NPU stalls cleanly and produces correct output
4. **GOPS Metrics** — measure effective throughput vs. theoretical peak for the presentation

---

## File Structure

```
tb/CocoTB/NPU/
├── npu_isa.py                      # ISA helpers: opcode constants, make_instr(), payload builders,
│                                   # build_standard_instrs() — 9-instr tile sequence
├── npu_golden.py                   # NumPy golden model: gen_tile(), golden_matmul_requant(),
│                                   # pack_weights_128b/acts_128b/coeffs_128b, build_*_mem()
├── npu_bfm.py                      # AXI4 BFMs: AXILiteMaster, AXI4ReadSlave, AXI4WriteSlave,
│                                   # reset_dut()
│
├── test_single_layer.py            # Phase 2: bit-exact golden comparison (seed=0)
├── test_single_layer_interface.py  # pytest → Verilator runner
│
├── test_quant_stress.py            # Phase 2: all-zeros, max-values (0x7F), checkerboard
├── test_quant_stress_interface.py
│
├── test_zero_delay.py              # Phase 3: 0-stall baseline + GOPS report
├── test_zero_delay_interface.py
│
├── test_source_starvation.py       # Phase 3: read channels stall 0-3 cycles (seed=42)
├── test_source_starvation_interface.py
│
├── test_sink_backpressure.py       # Phase 3: write channel stalls 0-3 cycles (seed=43)
└── test_sink_backpressure_interface.py
```

All 5 interface files share **one Verilator build** (`sim_build/NPU_build`) — compiles once, all tests reuse the binary.

---

## Test Instruction Sequence

Every test drives the same 9-instruction program:

| # | Opcode | Unit | Purpose |
|---|---|---|---|
| 0 | `OP_CONFIG` | SEQ | Set tile_M/N/K=16, stride=1, coeff_base=0 |
| 1 | `OP_COEFF_LOAD` | DMA | Fetch 8 beats of (M,S) pairs from addr 0x0 → SRAM |
| 2 | `OP_WT_LOAD` | DMA | Fetch 16 beats of INT8 weights from addr 0x6000 → Weight Bank |
| 3 | `OP_DMA_LOAD` | DMA | Fetch 1 beat of INT8 activations from addr 0x7000 → Act Bank |
| 4 | `OP_MATMUL` | SA | 16×16 INT8 tile → INT32 partial sums |
| 5 | `OP_PSB_FLUSH` | PSB | Forward INT32 row to Requant; zero-clear PSB |
| 6 | `OP_REQUANT` | REQ | Apply per-channel (M,S) → INT8 → Output Bank |
| 7 | `OP_LUT_BYPASS` | VPU | bypass_en=1 (forwards Output Bank, generates VPU→DMA token) |
| 8 | `OP_DMA_STORE` | DMA | Write 1 beat of INT8 output from addr 0x8000 → DDR4 |

Test passes when `irq_done` fires, no `fetch_err`/`dma_err`, and `store_words[0]` matches the NumPy golden.

---

## Golden Model

```
W[16,16] @ A[16] = acc[16]   (INT8 × INT8 → INT32)
out[i] = clip((acc[i] * M[i]) >> S[i],  −128, 127)   (INT8)
```

Default tile (`gen_tile(seed=0)`): random W/A, M=1, S=11 → max |output| ≈ 126, no saturation.

---

## GOPS Metrics (test_zero_delay)

| Metric | Formula |
|---|---|
| Peak GOPS | `2 × 16 × 16 × 0.3 GHz = 153.6 GOPS` |
| Effective GOPS | `MACS / sim_time_ns` |
| PE utilization | `Effective / Peak × 100%` |

---

## Status

| Phase | What | Status |
|---|---|---|
| Phase 0 | Verilator compiles full NPU cleanly | ✅ **Done — 0 warnings, binary runs** |
| Phase 1 | Shared helpers (npu_isa, npu_bfm, npu_golden) | ✅ Written |
| Phase 2 | Functional tests (single_layer, quant_stress) | 🔴 **Checkpoint B still failing — `irq_done` timeout (50 k cycles). BFM bug fixed; root cause of stall TBD — see debug section below** |
| Phase 3 | Resilience tests (zero_delay, starvation, backpressure) | ✅ Written — pending Checkpoint C |
| Phase 4 | Full suite validation + results file | ⬜ Pending |

---

## How to Run

```powershell
# Checkpoint A — compile check (run first, fix any Verilator errors before proceeding)
pytest tb/CocoTB/NPU/test_single_layer_interface.py -v -s 2>&1 | head -80

# Checkpoint B — functional correctness
pytest tb/CocoTB/NPU/test_single_layer_interface.py `
       tb/CocoTB/NPU/test_quant_stress_interface.py -v -s

# Checkpoint C — AXI resilience
pytest tb/CocoTB/NPU/test_zero_delay_interface.py `
       tb/CocoTB/NPU/test_source_starvation_interface.py `
       tb/CocoTB/NPU/test_sink_backpressure_interface.py -v -s

# Checkpoint D — full suite + save results
pytest tb/CocoTB/NPU/ -v -s 2>&1 | Tee-Object npu_cocotb_results.txt
```

---

## RTL Fixes Applied for Verilator (Phase 0)

The following RTL bugs and width-lint issues were fixed to get Verilator to compile with zero warnings:

| File | Fix |
|---|---|
| `src/WeightStationarySA/ProcessingElement.sv:40` | Sign-extension replicate was `FORMAT_BITWIDTH` (wrong) → `MUL_OUT_BITWIDTH` — was generating 40-bit RHS for a 32-bit signal (math bug, already corrected in file) |
| `src/WeightStationarySA/SA_top.sv:86–105` | Two `always_ff` blocks drove `MatrixMulOut` on different clock edges (`posedge` + `negedge`). Replaced with single `posedge` block using `done_prev` (1-cycle delayed `controller_done_c`) |
| `src/VectorProcessingUnit/vpu.sv:87–` | Added `lane_outs[LANES]` intermediate array with `/* verilator lint_off UNOPTFLAT */` guard. `lane_data_h` now reads from `lane_outs[lane+1]` instead of the packed `out` bus, breaking Verilator's perceived circular dependency |
| `src/VectorProcessingUnit/fu.sv:43,47` | Explicit sign-extension on ADD/SUB: `{{8{a[7]}},a} + {{8{b[7]}},b}` |
| `src/WeightStationarySA/SA_Controller.sv:99,103,109` | Cast 32-bit integer constants to `8'(...)` for comparisons with 8-bit `counter` |
| `src/Memory/psb.sv:62–63` | Added `localparam LastRow = ($clog2(ARRAY_HEIGHT))'(ARRAY_HEIGHT-1)` — explicit-width cast avoids WIDTHTRUNC on localparam init |
| `src/Memory/DepFIFO.sv:38` | Added `localparam FullVal = ($clog2(DEPTH)+1)'(DEPTH)` — same pattern |
| `src/NPU/DMA.sv:302–305` | Cast 4-bit pad registers to `8'(...)` in `is_pad` comparisons |
| `src/NPU/NPU.sv:213–217` | Cast 4-bit `UNIT_*` enum indices to `3'(...)` when indexing `units_done[5:0]` |

---

## Checkpoint B Debug Log

### Fix 1 — Applied ✅: `npu_bfm.py` seq channel beat addressing (`AXI4ReadSlave._run`)

**Bug:** For `data_bits=32` (seq channel), the BFM did `raw = self.mem.get(word_addr + b, 0)` for each of the 4 beats. This read from a different 128-bit instruction word per beat (`word_addr+0`, `word_addr+1`, ...) instead of slicing four 32-bit chunks from the **same** instruction word. The Sequencer assembled a Frankenstein instruction whose opcode/unit bits `[127:96]` came from instruction 3 (DMA_LOAD), not instruction 0 (CONFIG). Every instruction was corrupted.

**Fix:** `npu_bfm.py:122–129` — split the 32-bit and 128-bit fetch paths so `data_bits=32` always uses `self.mem.get(word_addr, 0)` (no `+ b`).

**Consistency check:** Sequencer assembles LSB-first (`instr_buf[beat_cnt*32 +: 32] <= m_axi_rdata`, beat 0 → `[31:0]`). BFM delivers `raw >> (b*32)` (beat 0 → `[31:0]`). Both are LSB-first. ✓

**Result after fix:** Test still times out at 50 k cycles. A second bug is present.

### Next Debug Step — monitoring added ✅

`test_single_layer.py` now has a `monitor()` coroutine (lines 14–29) that logs every 1 000 cycles:

```
seq_arvalid  dma_arvalid  wt_arvalid  st_awvalid  st_wvalid  irq_done  fetch_err  dma_err
```

**Run command (shows only the key lines):**
```powershell
pytest tb/CocoTB/NPU/test_single_layer_interface.py -v -s 2>&1 | Select-String "cyc|irq_done|FAIL|PASS|TimeoutError"
```

### What to look for in the monitor output

| Pattern | Meaning |
|---|---|
| `seq_arv` never goes 1 | Sequencer never kicked — AXI-Lite write failed or kick pulse missed |
| `seq_arv` goes 1 but `dma_arv` never | Seq fetching but DMA never starts — COEFF/WT/ACT load stall |
| `dma_arv` pulses but `st_awv` never | Pipeline stalls between DMA_LOAD and DMA_STORE — trace dep chain |
| `st_awv` goes 1 but `irq` never | Store FSM stuck in SS_W or SS_B — check BFM write-channel handshake |

### Dep-chain token inventory (for stall diagnosis)

| DepFIFO | RESET_COUNT | Producer | Consumer |
|---|---|---|---|
| `sa_to_dma` | **1** (pre-seeded) | SA `sa_done_pulse` | Dispatch_DMA DMA_LOAD |
| `dma_to_sa` | 0 | DMA `dma_act_bank_full` | SA_Block MATMUL |
| `psb_to_sa` | **1** (pre-seeded) | PSB `psb_done_pulse` | SA_Block |
| `sa_to_psb` | 0 | SA `sa_done_pulse` | PSB_Block PSB_FLUSH |
| `req_to_psb` | **1** (pre-seeded) | REQ `req_done_pulse` | PSB_Block |
| `psb_to_req` | 0 | PSB `psb_done_pulse` | Requant_Block |
| `req_to_vpu` | **1** (pre-seeded) | REQ `req_done_pulse` | VPU_Block |
| `vpu_to_req` | **1** (pre-seeded) | VPU `vpu_done_pulse` | Requant_Block |
| `dma_to_vpu` | **1** (pre-seeded) | DMA `dma_store_done` | VPU_Block |
| `vpu_to_dma` | 0 | VPU `vpu_done_pulse` | Dispatch_DMA DMA_STORE |

**Critical path to `irq_done`:**  
DMA_LOAD → `dma_to_sa` → MATMUL → `sa_to_psb` → PSB_FLUSH → `psb_to_req` → REQUANT → `req_to_vpu`+`vpu_to_req` → LUT_BYPASS → `vpu_to_dma` → DMA_STORE → `dma_store_done` = `irq_done`.

### Key files already verified

- `DMA.sv`: Ch0 FSM handles COEFF_LOAD (states `S_C_AR/S_C_R/S_C_WR1`), DMA_LOAD (`S_PIXEL/S_AR/S_R/S_ADV`), DMA_STORE (`SS_AW/SS_W_PRIME1/SS_W/SS_B`). `dma_act_bank_full` fired in `S_R` when `waddr_r == r_act_total - 1`. `dma_store_done` (`= store_done_r`) fired in `SS_B` on last row.
- `Dispatch_VPU.sv:212–217`: `OP_LUT_BYPASS` pops FIFO and fires `unit_done` in the SAME cycle — single-cycle retire. Pushes `vpu_to_dma` immediately.
- `psb.sv`: PSB_FLUSH runs 16 cycles in `S_FLUSH` counting `flush_row_count`, then pulses `flush_done`. Does NOT require prior PSB_ACCs.
- `DepFIFO.sv`: `RESET_COUNT` correctly pre-loads the counter at reset.
- `FIFO_USE_XPM = 1'b0` — behavioral FIFO, no Xilinx IP dependency.
- `AXI-Lite slave` (Sequencer): `awready/wready` are combinatorial, AW+W latched independently, kick is a 1-cycle NBA strobe consumed one cycle after generation. AXI-Lite BFM handshake verified correct.

---

## Key Reference Files

| File | Purpose |
|---|---|
| `tb/NPU/NPU_tb.sv:188–263` | SV payload builder helpers — ported to `npu_isa.py` |
| `tb/NPU/NPU_tb.sv:281–500` | SV BFM tasks — ported to `npu_bfm.py` |
| `tb/NPU/NPU_tb.sv:862–928` | TC16 (REQUANT) and TC24 (end-to-end) — closest to our sequence |
| `src/packages/NPU_ISA_pkg.sv` | Opcode/unit_id values |
| `src/packages/NPU_HW_params_pkg.sv` | SA_ROWS=16, SA_COLS=16, ACT_WIDTH=8 |
| `tb/CocoTB/VPU/mux2to1/` | Style reference for test/interface file pattern |
