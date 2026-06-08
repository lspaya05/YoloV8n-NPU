# Analysis Task 05 — DMA Store & Output Capture

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

`OP_DMA_STORE` reads the Output Bank and streams it over AXI to DDR, where the
testbench `AXI4WriteSlave` captures it into `store_words[0]`. The captured word is
all-zeros. Determine whether STORE reads the bank too early (before Requant/VPU
write), whether the read address advances, and whether capture/endianness matches
the golden packing.

## Files to read

| File | Why |
|------|-----|
| `src/NPU/DMA.sv` | store FSM (SS_AW / SS_W_PRIME1 / SS_W_LOAD / SS_W / SS_B), `sram_raddr`, `hp2_w*` |
| `src/Memory/SRAMHub.sv` | Output-Bank read port; read latency |
| `src/NPU/NPU.sv` | store read path wiring (DMA ↔ SRAMHub output bank) |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | STORE dep gating + start |
| `tb/CocoTB/NPU/npu_bfm.py` | `AXI4WriteSlave` — how W beats append to `store_words` |
| `tb/CocoTB/NPU/npu_golden.py` | `pack_acts_128b` — expected byte ordering (A[0] in LSB) |

## Questions to answer

1. Does `sram_raddr` advance across the store burst (0→15 or per output element)?
   A stuck raddr reads one cell repeatedly.
2. Pipelined read: SS_W_PRIME1 issues raddr, next cycle data latched. Is the W
   beat aligned to the latched data, or off-by-one (could send a stale/zero beat)?
3. STORE fires at cyc 93 while SA only entered RUN at cyc 88 — does the Output
   Bank contain valid data at cyc 93, or is STORE reading **before** Requant/VPU
   ever wrote it? (Cross-ref Task 04.)
4. In `AXI4WriteSlave`, how is a 128-bit word assembled from W beats, and what
   data width / `wstrb` is assumed? Confirm `store_words[0]` indexing matches the
   first output tile.
5. Endianness/packing: does the HW byte order match `pack_acts_128b` (A[0] in bits
   [7:0])? A mismatch would corrupt — but **all-zeros** points to no-data, not
   mis-order. Confirm it's zeros, not a permutation.
6. Does the DMA store base addr (`0x8000`) and the testbench's expected store
   address line up so the captured beat is the intended one?

## Preliminary findings (Claude)

- Log: `DMA Ch0 START mode=STORE src=0x00008000` at cyc 93; `IRQ_DONE` at cyc 100.
  The whole store happens in the last ~7 cyc, immediately after SA enters RUN.
- Test assertion got `0x000…0` (pure zero), not a byte-permuted value — consistent
  with **reading an Output Bank that was never validly written** (upstream
  starvation), rather than an endianness bug. Confirm.
- This stage is likely a faithful messenger of an empty bank. Still verify raddr
  advance and the off-by-one PRIME→W alignment, which could independently drop the
  real data even once upstream is fixed.

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

### Q1 — Does `sram_raddr` advance across the burst (0→15 or per element)?

Neither — this descriptor is a **single-beat** transfer. `build_standard_instrs`
issues `make_dma_payload(0x8000, row_stride=16, tile_w=1, tile_h=1, ch_count=16, …)`
(`tb/CocoTB/NPU/npu_isa.py:136-137`, field layout `npu_isa.py:66-80`). With
`tile_w=1, tile_h=1, ch_count=16`, `store_per_row_calc = tile_w * ch_count[7:4]
= 1*1 = 1` beat/row and `store_tile_h_r = 1` row (`src/NPU/DMA.sv:397, 747-748`)
→ exactly **one** 128-bit beat total, address 0. The "stuck raddr" framing
doesn't apply: there is only one cell to read and the FSM reads exactly that
cell once. (I also traced the general multi-row path, `DMA.sv:757-808`:
`store_send_idx` is never reset between rows — only in `SS_IDLE`, `DMA.sv:750`
— and `sram_raddr <= store_send_idx` on the `SS_AW`→`SS_W_PRIME1` edge,
`DMA.sv:764`, is a no-op because both counters stay in lockstep across row
boundaries. A multi-beat STORE would advance correctly 0,1,2,….)

### Q2 — Is the PRIME1→W capture off-by-one (stale/zero beat)?

No off-by-one. Cycle-accurate trace of `DMA.sv:757-795`, given `SimpleBRAM`'s
1-cycle registered read (`src/Memory/SimpleBRAM.sv:36-38`):

- `sram_raddr` sits at its reset value `0` through `SS_IDLE`/`SS_AW`
  (`DMA.sv:730` reset; never reassigned in those states) — address 0 has been
  "parked" on the Output-Bank read port since cycle 0.
- `SS_AW`→`SS_W_PRIME1`: `sram_raddr <= store_send_idx` (=0, a no-op);
  `SS_W_PRIME1` captures `wdata_reg <= sram_rdata` = `mem[0]` (the value that's
  been sitting on the registered output since reset) and pre-issues
  `sram_raddr <= store_send_idx + 1` = 1 (`DMA.sv:772-773`).
- `SS_W` (beat 0): transmits `wdata_reg` = `mem[0]` ✓; raddr=1 now in flight.
- `SS_W_LOAD` captures `mem[1]`, advances raddr→2; `SS_W` (beat 1) sends
  `mem[1]` ✓ … and so on.

Beat *i* transmitted always carries `mem[i]`. The PRIME/LOAD pipeline is
correctly aligned to the registered-BRAM 1-cycle latency — it neither drops
nor duplicates a beat, and never sends a stale value.

### Q3 — Is the Output Bank valid at cyc ~95 (STORE capture time)?

**No — this is the real bug**, confirming the preliminary hypothesis. Because
`sram_raddr` has been parked at address 0 since reset (Q2), `out_rdata_int =
mem[0]` (`src/Memory/SRAMHub.sv:198-211`) simply reflects whatever word-0 of
the Output Bank holds at the instant `SS_W_PRIME1` samples it (~cyc 95, two
cycles after the `start` pulse at cyc 93). Per the project timeline
(`docs/analysis/README.md:17-29`), SA only reaches RUN at cyc 88 and never
reaches DRAIN/DONE before STORE fires — REQUANT/VPU (which run only after
PSB_FLUSH, which runs only after MATMUL drains) cannot have written the
Output Bank yet (cross-ref Task 04). So `mem[0]` is read in its
**never-written** state.

`SimpleBRAM` has **no reset on its data array** ("No reset on data array — BRAM
primitives on KR260 do not support sync reset", `src/Memory/SimpleBRAM.sv:16`,
array declared at `SimpleBRAM.sv:29` with no initial block). Verilator
zero-initializes unpacked `logic` arrays at time 0, so an unwritten `mem[0]`
reads back as `128'h0` — exactly the `0x000…0` the test captured. This is a
**faithful read of an empty bank**, not a DMA datapath defect — fully
consistent with the "Preliminary findings" note above.

### Q4 — AXI4WriteSlave word assembly / `store_words[0]` indexing

`AXI4WriteSlave._run` (`tb/CocoTB/NPU/npu_bfm.py:168-198`) does a straight 1:1
capture: `self.store_words.append(int(self._wdata.value))` per accepted W beat
(`npu_bfm.py:188`), in burst arrival order, gated purely on the
`awvalid`→`awready` then `wvalid`/`wready` handshakes — it never reads
`awaddr` (no `_awaddr` member exists, `npu_bfm.py:150-163`). `_wdata` binds to
`dut.st_wdata` = the full 128-bit `hp2_wdata` (`src/NPU/NPU.sv:534`, and
`assign hp2_wdata = wdata_reg;` at `DMA.sv:413`). `wstrb` is neither inspected
by the BFM nor meaningfully varied by the DMA (`hp2_wstrb = 16'hFFFF` always,
`DMA.sv:421`). Since this descriptor produces exactly **one** beat (Q1),
`store_words[0]` is unambiguously that single captured beat = `wdata_reg` =
`mem[0]`, matching `pack_acts_128b`'s single-element return
(`tb/CocoTB/NPU/npu_golden.py:36-41`). **No indexing/width bug** in the BFM.

### Q5 — Endianness / packing

DMA does not reorder bytes: `assign hp2_wdata = wdata_reg;` (`DMA.sv:413`) is a
pure pass-through of the captured `sram_rdata`. `pack_acts_128b`
(`npu_golden.py:36-41`) places `A[0]` in bits `[7:0]` (LSB-first). The captured
value is uniformly `0x0` across all 128 bits — a constant has no byte order to
permute, so endianness can't be distinguished from "no data" by value alone.
Combined with Q3 (bank never written), the simplest and only consistent
explanation is **no data**, not mis-ordering. Confirms preliminary finding #5:
nothing in DMA's read/store path would corrupt byte order even if the upstream
write (Task 04) packs correctly — endianness is moot until the real bug is fixed.

### Q6 — Does store base addr `0x8000` line up with the testbench's expectation?

Moot — `AXI4WriteSlave` never reads `st_awaddr` at all (`npu_bfm.py:168-198`
has no address-channel member besides `_awvalid/_awready/_awlen`). It is a
pure burst-order capture sink: `store_words[0]` = first W beat of the first
accepted AW burst, regardless of which DDR address that burst targets.
`store_aw_addr <= {12'h0, src_base}` = `{12'h0, 32'h0000_8000}`
(`DMA.sv:746`, `src_base` sourced from `make_dma_payload(0x8000, …)` at
`npu_isa.py:137`) drives `hp2_awaddr`/`st_awaddr`, but `test_single_layer.py`
(lines 49-65) asserts nothing about it. **Address alignment is not a candidate
cause of the all-zeros symptom** — ruled out.

---

### Summary / verdict

All six questions resolve in favor of the preliminary hypothesis, with the
DMA-side fully exonerated:

- `sram_raddr` advances correctly (trivially so here — a single-beat transfer;
  the general multi-beat/multi-row pipeline is also correctly indexed, Q1/Q2).
- The `SS_W_PRIME1`/`SS_W_LOAD`/`SS_W` BRAM-read pipeline is exactly aligned to
  `SimpleBRAM`'s 1-cycle registered-read latency — no off-by-one, no stale beat
  (Q2).
- `AXI4WriteSlave` is a faithful, address-agnostic, burst-ordered 128-bit
  capture sink; `store_words[0]` indexing and width are correct (Q4, Q6).
- DMA performs no byte reordering; the all-zero capture is a property of the
  source data, not the transport (Q5).
- The root cause is upstream: `sram_raddr`/`dma_out_raddr` has pointed at
  Output-Bank word 0 since reset (parked there through `SS_IDLE`/`SS_AW`), and
  STORE's `SS_W_PRIME1` samples it at ~cyc 95 — before SA/PSB/Requant/VPU have
  ever written it (timeline: SA enters RUN at cyc 88, never reaches DRAIN/DONE
  before STORE fires at cyc 93; see `docs/analysis/README.md:17-29` and Task 04).
  `SimpleBRAM` has no data-array reset (`SimpleBRAM.sv:16`), so the never-written
  cell simply reads back as Verilator's zero-initialized value — `0x000…0`,
  matching the captured symptom exactly (Q3).

**Conclusion: `src/NPU/DMA.sv` and the AXI-write capture path need no changes.**
The fix belongs in the dep-token/FENCE gating that lets `OP_DMA_STORE` issue
`desc_start` (`Dispatch_DMA.sv:194-203`, gated only on `dep_vpu_to_dma_empty`)
before the Output Bank is actually populated — i.e., Tasks 01/03/04's territory
(VPU/Requant push their "out-bank-ready" token to the VPU→DMA DepFIFO too early,
or the Sequencer doesn't fence STORE on SA/PSB/Requant completion).
