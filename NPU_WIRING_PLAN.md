# NPU.sv Top-Level Wiring Plan

## Status
- **Phase 1: COMPLETE** (Sequencer + 6 instr FIFOs + 5 Dispatch skeletons + DMA shell, all in block-organized NPU.sv).
- **Phase 2: COMPLETE** (SRAMHub instantiated; Dispatch_SA full MATMUL FSM; SA_top wired with packed-to-unpacked row conversion).
- **Phase 3: COMPLETE** (Dispatch_PSB ACC+FLUSH FSM; psb instantiated with sa_row_in <- MatrixMulOut; requant_row_out / row_out_valid surfaced for Phase 4).
- **Phase 4: COMPLETE** (Dispatch_REQ coeff-load + mode-select + output-writer FSM; RequantPipeline instantiated; SRAMHub coeff & vpu_out ports rewired to Dispatch_REQ).
- **Phase 5: COMPLETE** (Dispatch_VPU ISA→vpu translator + 3-stage per-word FSM; vpu instantiated LANES=16; Output Bank writer muxed between Requant and VPU; FIFO_USE_XPM parameter added to package).
- **All five phases complete. Block-organized NPU.sv elaborates with full Sequencer → DMA-stub → SRAMHub → SA → PSB → Requant → VPU pipeline.**

## Context
[src/NPU/NPU.sv](src/NPU/NPU.sv) is shell-only — module ports done, sub-block instantiations empty. Goal: wire submodules to top-level ports + each other without altering the existing structure. Each phase = manual approval gate. No testbenches written in this plan — only RTL implementation.

## Key Decisions (locked from clarifications)
- **DMA unit:** instantiate empty shell only; no internal DMA logic this pass. `unit_done[UNIT_DMA] = 1'b1` so Sequencer never stalls on DMA ops.
- **DepFIFOs:** not instantiated this pass — Sequencer + per-unit done handshake provides ordering.
- **Dispatch:** five separate per-unit modules — `Dispatch_DMA.sv`, `Dispatch_SA.sv`, `Dispatch_PSB.sv`, `Dispatch_REQ.sv`, `Dispatch_VPU.sv` — each is a small FSM that pops its instr-FIFO, decodes the 124-bit `fifo_payload`, drives the unit's control ports, and pulses `unit_done`. Files live in [src/NPU/](src/NPU/).
- **Sequencer fifo_payload widened to 124 bits:** `{opcode[7:0], dep_flags[3:0], payload[111:0]}`. Resolves the previous opcode-drop problem so PSB ACC/FLUSH, VPU sub-ops, and DMA Ch0 sub-ops can be distinguished by `fifo_dout[123:116]`.
- **Six instr FIFOs (not five):** Sequencer routes two DMA slots — Ch0 (DMA_LOAD/STORE/UPSAMPLE/CONCAT/COEFF_LOAD, bit0) and Ch1 (WT_LOAD, bit5). Other slots: SA bit1, PSB bit2, REQ bit3, VPU bit4.
- **Instr-FIFO depths (v2.1 spec):** DMA_Ch0=16, DMA_Ch1=16, SA=32, PSB=32, REQ=8, VPU=16. All DATA_WIDTH=124.
- **NPU.sv organization:** one block per pipeline stage in v2.1 dataflow order — Sequencer → DMA → SRAMHub → SA → PSB → Requant → VPU. Each block contains its own nets, FIFO(s), Dispatch, and datapath module.
- **VPU LANES:** parameterized to `NPU_HW_params_pkg::VPU_LANES` (=16 per 2026-05-26 amendment; see notes/Architecture-FINAL/NPUArchitectureV2_1.md).
- **Verification:** none in this plan — pure RTL build out. TB phases follow later.

## Inventory (port-list verified)
- Sequencer: AXI-Lite slv + HP0 read mst; outputs `fifo_payload[123:0]` + `fifo_push[5:0]`; inputs `fifo_full[5:0]`, `unit_done[5:0]`; CSR cfg fanout. (fifo_payload widened from 116 to 124 bits to carry opcode.)
- DMA: ports exist; logic out-of-scope this pass.
- SRAMHub: Act/Wt/Res/Out/Coeff/LUT bank R+W ports.
- SA_top: unpacked `weightInputRow[16]`, `activationInputCol[16]`, `MatrixMulOut[16]` INT32.
- psb: unpacked `sa_row_in[16]`, packed 512-bit `requant_row_out`.
- RequantPipeline: 16x32 packed psb_row_i, Lanes=16 sram_a/b paths (post-2026-05-26 narrowing).
- vpu: parameterized LANES; opcode-driven.
- FIFO: generic (USE_XILINX_XPM, DATA_WIDTH, DEPTH).

## Cross-Phase Coding Rules
- Spaces only, <=100 col, `always_ff`/`always_comb`, sync reset.
- New `.sv` files get the standard EE470 header via the `comment-generator` skill.
- Do not touch [scripts/sim/runlab.do](scripts/sim/runlab.do), [.gitignore](.gitignore), or testbench naming.
- NPU.sv layout: one block per pipeline stage. Each block declares its own local nets, then its FIFO(s), Dispatch, and datapath module. Block order matches v2.1 dataflow (Sequencer → DMA → SRAMHub → SA → PSB → Requant → VPU). CSR shadow nets live inside the Sequencer block.

---

## Phase 1 — Sequencer + Instr FIFOs + Dispatch Skeletons + DMA Shell  **[DONE]**
**Approval gate before Phase 2.**

Scope: stand up the front-end (Sequencer fanout) and create the five dispatch modules. DMA shell instanced with all ports tied. No data-path units active yet.

Tasks:
1. Widen Sequencer's `fifo_payload` from 116 to 124 bits and emit `{dec_opcode, dec_dep, dec_payload}` so each Dispatch can read the opcode at `fifo_dout[123:116]`.
2. Inside the Sequencer block in [src/NPU/NPU.sv](src/NPU/NPU.sv): declare CSR shadow nets + `disp_payload`/`disp_push`/`disp_full`/`units_done` + per-unit `*_done_pulse` wires + the `units_done` always_comb aggregator. Instantiate `Sequencer sequence_unit`. Drive top-level `irq_done`, `fetch_err`. Hardwire `units_done[UNIT_DMA]=1`; leave `units_done[UNIT_SEQ]=0`.
3. Create six instr FIFOs (one per Sequencer dispatch slot) at DATA_WIDTH=124:
   - DMA_Ch0=16, DMA_Ch1=16 (in DMA block), SA=32, PSB=32, REQ=8, VPU=16.
   - `din = disp_payload`, `wr_en = disp_push[i]`, `full -> disp_full[i]`.
4. Create five new files in [src/NPU/](src/NPU/):
   - `Dispatch_DMA.sv` - stub: continuously drains both DMA FIFOs so Sequencer never stalls on dispatch_stall.
   - `Dispatch_SA.sv`, `Dispatch_PSB.sv`, `Dispatch_REQ.sv`, `Dispatch_VPU.sv` - skeletons only this phase: declared ports (clk, rst, fifo_dout/empty/rd_en, unit_done, plus unit control ports as outputs), reset-state body, no decode/FSM yet. Bodies implemented in Phases 2-5.
5. Instantiate each Dispatch inside its unit's block, alongside the FIFO and the (later) datapath module.
6. Instantiate empty `DMA` shell in the DMA block - bind HP0 to top-level `dma_*`; tie HP1 inputs to 0 and leave HP1 outputs open (wt_* polarity discrepancy noted); tie descriptor + `start` to 0 so the unit stays in S_IDLE; leave SRAM ports open until Phase 2.

Deliverables this phase: NPU.sv elaborates, Sequencer reads instructions, six FIFOs accept pushes, dispatch modules sit idle. `irq_done` reachable; DMA AXI buses idle but driven; data-path units (SA/PSB/REQ/VPU) not yet instantiated.

---

## Phase 2 — SRAMHub + SA Dispatch + Systolic Array  **[DONE]**
**Approval gate before Phase 3.**

Tasks:
1. Inside the SRAMHub block in NPU.sv, instantiate `SRAMHub SRAM_hub`. Tie all `dma_*` write-side ports to 0 (DMA still stubbed). Tie `vpu_*`, `req_coeff_*` to 0 (later phases).
2. Implement `Dispatch_SA.sv` (widen ports as needed):
   - Pop SA_instr_fifo on `!empty && !sa_busy`.
   - Confirm opcode at `fifo_dout[123:116] == OP_MATMUL`; decode MATMUL payload (`tile_sel` from `npu_matmul_payload_t`).
   - Drive SRAMHub read addr counters: `sa_act_raddr`, `sa_wt_raddr`, `sa_act_bank_read`, `sa_wt_bank_read`. Walk `cfg_tile_K` beats from CSR.
   - Pulse `SA_top.start` for one cycle; wait for `SA_top.done`; pulse the dispatch's `unit_done` port (already plumbed into `sa_done_pulse` -> `units_done[UNIT_SA]`).
3. Instantiate `SA_top Systolic_array` inside the SA block.
   - Convert 128-bit `sa_act_rdata` -> unpacked `activationInputCol[16][7:0]` via generate-for.
   - Convert 128-bit `sa_wt_rdata` -> unpacked `weightInputRow[16][7:0]` via generate-for.
   - Surface `MatrixMulOut[16]` as internal net for Phase 3.
4. Drop the Phase 1 `assign sa_done_w = 1'b0;` placeholder in the SA block; wire `sa_done_w <= SA_top.done`.

---

## Phase 3 — PSB Dispatch + Partial Sum Buffer  **[DONE]**
**Approval gate before Phase 4.**

Tasks:
1. Implement `Dispatch_PSB.sv`:
   - Pop PSB_instr_fifo on `!empty && !psb_busy`.
   - Decode opcode at `fifo_dout[123:116]` — `OP_PSB_ACC` vs `OP_PSB_FLUSH`.
   - Drive `psb.psb_acc` / `psb.psb_flush` for the appropriate window.
   - Generate `row_valid` pacing from SA row outputs (use `SA_top.done` + an internal row counter, or directly from Phase 2's beat counter exposed as `sa_row_valid`).
   - Pulse the dispatch's `unit_done` (already plumbed into `psb_done_pulse` -> `units_done[UNIT_PSB]`) on `psb.acc_done | psb.flush_done`.
2. Instantiate `psb partial_sum_buffer` inside the PSB block.
   - Connect `sa_row_in <= MatrixMulOut` directly (both unpacked INT32[16]).
   - Surface `requant_row_out[511:0]` and `row_out_valid` as internal nets for Phase 4.
3. Replace Phase 1 placeholders `assign psb_acc_done_w = 1'b0;` / `assign psb_flush_done_w = 1'b0;` with the real `psb.acc_done` / `psb.flush_done` outputs.

---

## Phase 4 — Requant Dispatch + Requant Pipeline + Coeff Path  **[DONE]**
**Approval gate before Phase 5.**

Tasks:
1. Implement `Dispatch_REQ.sv`:
   - Pop REQUANT_instr_fifo on `!empty && !req_busy`.
   - Confirm opcode at `fifo_dout[123:116] == OP_REQUANT`; decode `ch_count` from `npu_requant_payload_t`.
   - Drive `RequantPipeline.mode_i`:
     - SA path: `mode_i = 2'b00` (PSB row source), only `psb_row_i` + `m0_a_i` + `n_a_i` + `bias_i` active.
   - Walk SRAMHub `req_coeff_raddr` for `ch_count` channels; pack `req_coeff_rdata` into `m0_a_i` / `n_a_i` / `bias_i` windows feeding RequantPipeline.
   - Track `valid_o` beats; on count == ch_count pulse the dispatch's `unit_done` (already plumbed into `req_done_pulse` -> `units_done[UNIT_REQ]`).
2. Instantiate `RequantPipeline requantization_pipeline` inside the Requant block with Lanes=16, ChCount=1 (2026-05-26 amendment).
   - Split `requant_row_out[511:0]` -> `psb_row_i[16][32]`.
   - Set `psb_row_valid_i = row_out_valid`.
   - Route `data_o` (INT8 byte lanes) into SRAMHub `vpu_out_w*` write ports (driven via a small writer FSM inside Dispatch_REQ; OK because VPU not yet writing this bank).
3. Replace the Phase 1 placeholder `assign req_valid_o_w = 1'b0;` with the real `RequantPipeline.valid_o`.

---

## Phase 5 — VPU Dispatch + Vector PU  **[DONE]**
**Approval gate before sign-off.**

Tasks:
1. Implement `Dispatch_VPU.sv`:
   - Pop VPU_instr_fifo on `!empty && !vpu_busy`.
   - Decode VPU opcode from `fifo_dout[123:116]`: SIMD_ACT, RELU, ELEW_ADD, ELEW_MUL, MAXPOOL, HREDUCE, LUT_LOAD, LUT_BYPASS.
   - For SRAM-sourced ops (RELU, ELEW_*, MAXPOOL, SIMD_ACT): walk Output Bank read addr (`out_rd_sel`, `vpu_hred_raddr`) and Residual Bank (`vpu_res_raddr`); pack 64x8 INT8 lanes into VPU `in_a` / `in_b`.
   - Drive `vpu.opcode`, `vpu.enable`, `vpu.reduce_max`.
   - Capture `vpu.out` and write back to SRAMHub `vpu_out_w*` ports.
   - LUT_LOAD: route VPU instr to SRAMHub `dma_lut_w*` (one-shot 256-byte copy from a known source — placeholder until DMA is real; for now leave the write ports inactive and just consume the instruction).
   - LUT_BYPASS: latch `bypass_en` into a top-level reg consumed by `vpu_lut_sel`.
   - Pulse the dispatch's `unit_done` (already plumbed into `vpu_done_pulse` -> `units_done[UNIT_VPU]`) on opcode-specific completion (counter == lane sweep length).
2. Instantiate `vpu vector_processing_unit` inside the VPU block with `LANES = NPU_HW_params_pkg::VPU_LANES` (=16 per 2026-05-26 amendment).
   - Bus `vpu_out_rdata[127:0]` -> `in_a[16*8-1:0]` directly; no replication needed.
3. Replace the Phase 1 placeholder `assign vpu_valid_opcode_w = 1'b0;` with the real `vpu.valid_opcode`.

End of plan: NPU.sv contains Sequencer + 6 instr FIFOs + 5 Dispatch modules + SRAMHub + SA + PSB + Requant + VPU + DMA shell, all interconnected. DMA payload path and DepFIFOs deferred to follow-on work.

## Open Items to Resolve During Implementation (not blocking the plan)
- Whether vpu.sv tolerates LANES=64 internally or hardcodes 16 — confirm at Phase 5.
- DMA write-channel polarity for `wt_*` vs current DMA.sv — out of scope this pass (DMA logic deferred).

---

## Final NPU.sv File Analysis (post-Phase 5)

**Structure** — 707 lines, single module, block-organized in v2.1 dataflow order.

| Block | Contains | Status |
|---|---|---|
| Sequencer | CSR shadow, units_done aggregator, Sequencer instance | functional |
| DMA | 2 instr FIFOs, Dispatch_DMA stub, DMA shell (start=0) | shell-only |
| SRAMHub | bank-side nets, Output-Bank writer mux, SRAMHub instance | functional |
| SA | SA FIFO, Dispatch_SA, SA_top + packed↔unpacked conversion | functional |
| PSB | PSB FIFO, Dispatch_PSB, psb instance | functional |
| Requant | REQUANT FIFO, Dispatch_REQ, RequantPipeline (Lanes=16) | functional |
| VPU | VPU FIFO, Dispatch_VPU, vpu instance (LANES=16) | functional |

**Sanity findings:**
- All 6 FIFOs use `FIFO_USE_XPM` from the package — single switch toggles sim vs synth mode.
- All Phase 1 `assign foo_w = 1'b0;` placeholders are gone; every dispatch feedback net is now driven by its real source.
- Sequencer → 6 unit FIFOs → 5 Dispatch FSMs → datapath units → SRAMHub form one coherent dataflow graph.
- All NPU module-level outputs are driven (irq_done, fetch_err, dma_err, all AXI buses).

**Known weak points (worth flagging before sim/synth):**
1. **DMA datapath is a shell** — `start=0` permanently; `dma_*_bank_full` tied 0 keeps PingPongBuffer on bank A forever; SA reads bank A only. No real data flows in until DMA is built out.
2. **vpu LANES=16, not 64** — to match Output Bank word width without multi-cycle SRAM gather. v2.1 spec gap.
3. **Only lower 128 bits of RequantPipeline.data_o written back** — upper 48 lanes wasted; OK because PSB only feeds 16 lanes.
4. **Cross-unit hazards rely entirely on microcode FENCE** — no DepFIFOs. Forgotten FENCE = silent hazard.
5. **PSB ACC granularity mismatch with ISA comment** — psb.sv expects 16 row_valid pulses per ACC tile; one PSB_ACC instr = one row_valid, so microcode needs 16 PSB_ACCs per tile.
6. **Output Bank writer mux uses priority (vpu_wen wins)** — relies on FENCE to prevent overlap; would lose a write if Sequencer ever issued REQUANT and VPU concurrently.
7. **`cfg_coeff_base` from CSR is unused** — Dispatch_REQ starts coeff read at address 0 each instr.
8. **`wt_*` top-level read channel tied inactive** — DMA.sv `hp1` is a write port (polarity discrepancy still open).
9. **SIMD_ACT + LUT_LOAD stubbed** — Dispatch_VPU acknowledges them but does no work; vpu.sv has no LUT support.
10. **SA_top captures MatrixMulOut on `negedge clk`** — already in SA_top, not something Phase 5 introduced, but worth flagging as it's the only negedge-driven register feeding downstream posedge logic.

**Bottom line:** the wiring is complete and self-consistent. The remaining work is (a) DMA bring-up to actually push data in, (b) DepFIFOs or compiler-side FENCE management, (c) testbench-driven timing alignment of the BRAM-latency-vs-SA-phase windows. Everything should elaborate cleanly today; functional simulation needs DMA datapath first.
