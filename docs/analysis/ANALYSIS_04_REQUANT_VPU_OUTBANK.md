# Analysis Task 04 — Requant, VPU & Output-Bank Write

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

After PSB flush, the Requant pipeline applies `clip(acc*M >> S, -128, 127)` per
lane and writes INT8 results into the Output Bank; VPU (here `OP_LUT_BYPASS`)
optionally post-processes. Determine whether Requant captures the PSB rows,
whether M/S coefficients load correctly, and whether results are written to the
Output Bank at the right addresses (so STORE can read them).

## Files to read

| File | Why |
|------|-----|
| `src/NPU/Blocks/Requant_Block.sv` | dep gating (changed in 50aa8e1), `psb_row_valid` capture, coeff load |
| `src/NPU/Dispatch/Dispatch_REQ.sv` | S_LOAD_COEFF→S_RUN, drives output-bank write addr/data/en |
| `src/RequantPipeline/RequantPipeline.sv` | 16-lane requant datapath |
| `src/RequantPipeline/RequantSingleLane.sv` | per-lane multiply/shift/clip |
| `src/NPU/Blocks/VPU_Block.sv` | VPU dep gating + done |
| `src/NPU/Dispatch/Dispatch_VPU.sv` | LUT_BYPASS path; output-bank read/write |
| `src/VectorProcessingUnit/vpu.sv`, `src/VectorProcessingUnit/fu.sv` | VPU datapath / bypass |
| `src/NPU/NPU.sv` | output-bank write mux (Requant vs VPU priority), ~lines 629-641 |

## Questions to answer

1. Does Requant capture incoming `psb_row_valid` data into its pipeline? If PSB
   emits zeros (Task 03) or emits before Requant is in S_RUN, what does Requant
   latch?
2. Are the M (multiplier) and S (shift) coefficients loaded from the COEFF_LOAD
   path into Requant before S_RUN? Confirm the coeff addressing (test uses M=1,
   S=11).
3. Does Requant's output write address into the Output Bank **increment** per
   lane/row (0→15)? A stuck write addr writes one cell and leaves the rest 0.
4. `OP_LUT_BYPASS` with `bypass_en=1`: does VPU pass Requant output through
   unmodified, or does it read the Output Bank, transform, and write back? Which
   unit's write actually lands in the bank that STORE reads?
5. The output-bank write mux in `NPU.sv`: when do Requant-write and VPU-write
   contend, and which wins? Could the bypass VPU overwrite good Requant data with
   zeros (e.g. reading an empty bank)?
6. Timing: given the pipeline is non-blocking (Task 01) and SA isn't done (Task
   02), is Requant even fed valid data when it runs at cyc ~71–83?

## Preliminary findings (Claude)

- Log shows `DISPATCH OP_REQUANT -> REQ` at cyc 71 and `VPU DONE` at cyc 83 —
  both **before** SA reaches RUN-complete/DRAIN. So Requant/VPU operate on data
  that does not yet exist. Even a perfectly correct datapath yields zeros here.
- 50aa8e1 removed the `dep_psb_to_req` token from Requant's dispatch gate, so
  Requant no longer waits on PSB completion — consistent with it running too
  early. Confirm whether this is the intended data-valid handshake or a hole.
- This stage is likely **correct in isolation** but starved of valid input due to
  Tasks 01–03. Focus on confirming the write-addr increment and the
  Requant-vs-VPU output-bank mux, which could independently zero the output.

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

### Q1 — Does Requant capture `psb_row_valid` data?

Only when `mode_i == 2'b01` (FROM_PSB). In `RequantPipeline.sv:73-80`,
`lane_valid_i = psb_row_valid_i` solely in the `2'b01` case; every other case
(including the forced `mode_i = 2'b00` in `Dispatch_REQ` `S_IDLE`/`S_LOAD_COEFF`,
`Dispatch_REQ.sv:109,154`) routes `lane_valid_i = sram_a_valid_i`, which
`Requant_Block.sv:187` ties to constant `1'b0`. So any `psb_row_valid` pulse that
arrives **before** Dispatch_REQ reaches `S_RUN` is silently dropped — the strobe
simply isn't observed; nothing latches.

`req_mode` only becomes `2'b01` on the final cycle of `S_LOAD_COEFF`
(`Dispatch_REQ.sv:147-150`), i.e. ≥2 cycles after OP_REQUANT pops from the FIFO.
Meanwhile `psb_row_valid` (`= psb_row_out_valid_w`) is wired straight from
`PSB_Block` to `Requant_Block` combinationally with **no FIFO/handshake**
(`NPU.sv:806-807`) — it's a fire-and-forget strobe driven entirely by
`Dispatch_PSB` during PSB_FLUSH. There is no mechanism that makes PSB wait for
Requant to be in FROM_PSB mode, nor any buffer that lets Requant catch a strobe
it missed. Combined with the prelim finding that REQ dispatches at cyc 71 while
SA/PSB haven't finished (Tasks 01-02), and that 50aa8e1 deleted the
`dep_psb_to_req` wait that used to gate Requant on PSB completion, this is a
genuine hole, not just "starvation": even with correct SA/PSB timing, Requant's
FROM_PSB sampling window has no guaranteed overlap with PSB's row-emission
window.

### Q2 — Are M/S coefficients loaded correctly (M=1, S=11)?

The `S_LOAD_COEFF` capture itself is correctly pipelined: `req_coeff_raddr` is
driven to 0 on entry, and `req_coeff_rdata[35:4] -> req_m0_a[0]`,
`req_coeff_rdata[3:0] -> req_n_a[0]` are captured exactly one cycle later
(`Dispatch_REQ.sv:128-150`), matching a 1-cycle synchronous-read BRAM. Bit
packing is consistent end to end: DMA writes `{M[31:0], S[3:0]}`
(`DMA.sv:654,665`) and Requant reads the same split (`Dispatch_REQ.sv:133-138`),
both matching `npu_golden.pack_coeffs_128b` (`npu_golden.py:44-56`).

BUT: `Requant_Block` is instantiated with `ChCount = 1` (`NPU.sv:794`), so only
**one** (M0, n) pair — read from coeff-BRAM address 0 — is loaded and then
broadcast to all 16 lanes for all 16 output beats (`RequantPipeline.sv:65,
117-124`, `LanesPerCh = Lanes/ChCount = 16`). The test, however, issues
`OP_COEFF_LOAD` with `ch_count = 16` and `gen_tile` produces *per-channel*
`M = ones(16)`, `S = full(16, 11)` (`npu_golden.py:9-10`, `npu_isa.py:119`). The
hardware silently ignores channels 1–15 and reuses channel 0's (M=1, S=11) for
everything. This happens to be numerically harmless for this specific stress
vector (every channel's M/S are identical), so it is **not** the cause of the
all-zero bug here, but it is a real per-channel-dequant gap flagged in
`Requant_Block.sv:9-11` as an intentional ChCount=1 simplification — would break
on any test with non-uniform per-channel M/S.

### Q3 — Output-Bank write address increment

Correct. `vpu_out_waddr <= vpu_out_waddr + 1'b1` fires once per retired beat in
`S_WRITE_DONE` (`Dispatch_REQ.sv:169`), sweeping 0→15 across the
`target_count = 16` beats set by `make_requant_payload(ch_count=16)`
(`npu_isa.py:98-100,132`; `Dispatch_REQ.sv:113,172`). Address generation is not
the source of the all-zero bug.

### Q4 — Does `OP_LUT_BYPASS` read/transform/write the Output Bank?

No — it's a pure flag-set-and-retire no-op w.r.t. the Output Bank.
`Dispatch_VPU` `S_IDLE` handles `OP_LUT_BYPASS` entirely inline
(`Dispatch_VPU.sv:212-217`): it only latches `lut_bypass_en <= fifo_dout[0]`,
`vpu_lut_sel <= fifo_dout[0]`, and pulses `unit_done <= 1'b1` immediately. It
never transitions to `S_READ`/`S_COMPUTE`/`S_WRITE`, so `vpu_out_wen`,
`vpu_out_waddr`, `vpu_out_wdata` are never driven — they stay at the
unconditional `vpu_out_wen <= 1'b0` default reasserted every cycle
(`Dispatch_VPU.sv:146`). VPU performs **zero** Output-Bank reads or writes for
this op; "bypass" here means "don't touch the data path at all", not "pass
through unmodified".

### Q5 — Output-Bank write mux: can VPU clobber Requant's data?

No, not in this test. `NPU.sv:636-640` gives VPU write priority
(`out_waddr/wdata_mux_w = vpu_vpu_out_wen_w ? vpu_* : req_*`,
`out_wen_mux_w = req_vpu_out_wen_w | vpu_vpu_out_wen_w`), but per Q4
`vpu_vpu_out_wen_w` never asserts during `OP_LUT_BYPASS`. So
`vpu_vpu_out_wen_w` is always 0 here, the mux always passes Requant's
`{waddr, wdata, wen}` through untouched, and Requant's writes land in the bank
that STORE reads. **The prelim hypothesis that bypass-VPU could overwrite good
Requant data with zeros is ruled out** — VPU never contends for the write port
in this instruction sequence.

### Q6 — Is Requant fed valid data at cyc ~71–83?

No. Tasks 01/02 already establish SA hasn't reached RUN-complete/DRAIN by cyc
71, so PSB cannot yet hold real accumulator rows. Layering Q1 on top: Requant's
FROM_PSB sampling window opens only after `S_LOAD_COEFF` completes (≥2 cycles
post-pop) and there is no buffering of `psb_row_valid`, so whatever `psb_row_in`
( = `requant_row_out_w`, driven by PSB) happens to be while Requant sits in
`S_RUN` is what gets latched. The fact that `unit_done`/`VPU DONE` are observed
at cyc 83 (i.e. REQ *did* retire all 16 beats, meaning `req_valid_o` pulsed 16
times) is most consistent with Requant capturing 16 rows of `psb_row_in = '0`
(PSB/SA still idle/pre-accumulation), which `clip(0 * M0 >> S)` always evaluates
to `0` regardless of M/S — producing exactly the observed all-zero Output Bank.

### Summary / verdict

Requant's **datapath is correct in isolation**: coeff load addressing/timing
(Q2), lane multiply/shift/clip math (`RequantSingleLane.sv`), output-beat
write-address increment (Q3), and the output-bank write mux (Q5) all behave as
designed, and VPU's LUT_BYPASS is a true no-op (Q4) — it cannot be the source of
the zeros. The entire bug traces to **Q1/Q6**: Requant has no handshake with
PSB's row-emission — `mode_i` (and therefore `lane_valid_i` gating of
`psb_row_valid_i`) is only `FROM_PSB` for the narrow `S_RUN` window that opens
~2 cycles after OP_REQUANT pops, `psb_row_valid` is an unbuffered combinational
strobe (`NPU.sv:806-807`), and 50aa8e1 removed the `dep_psb_to_req` token that
used to force Requant to wait for PSB to finish before dispatching at all. Given
SA/PSB aren't done by cyc 71 (Tasks 01-02), Requant requantizes whatever
`psb_row_in` is driving at that moment — almost certainly zeros — and faithfully
writes `clip(0*1 >> 11) = 0` into all 16 Output-Bank words. **Fix belongs
upstream of Requant** (restore/repair the PSB→REQ dependency gate so Requant
only enters `S_RUN`/FROM_PSB after PSB_FLUSH has real rows ready), not in the
Requant/VPU/output-mux logic itself.

