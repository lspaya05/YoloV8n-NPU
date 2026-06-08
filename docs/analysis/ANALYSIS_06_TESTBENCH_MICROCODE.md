# Analysis Task 06 — Testbench & Microcode Correctness

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

Verify the cocotb test, the microcode it emits, and the golden model are correct —
independent of RTL bugs. Two specific suspects: (1) the program omits
`OP_PSB_ACC`, and (2) the python ISA encoding may not match the HW ISA package.
Also check that the test samples output only after the pipeline truly drains.

## Files to read

| File | Why |
|------|-----|
| `tb/CocoTB/NPU/test_single_layer.py` | program build, memory setup, IRQ_DONE polling, output assert |
| `tb/CocoTB/NPU/npu_isa.py` | `make_instr`, dep-flag bits, opcodes, `build_standard_instrs`, payload encoders |
| `tb/CocoTB/NPU/npu_bfm.py` | AXI BFMs, memory builders, `store_words` capture |
| `tb/CocoTB/NPU/npu_golden.py` | `gen_tile`, `golden_matmul_requant`, `pack_acts_128b`, mem maps |
| `src/packages/NPU_ISA_pkg.sv` | HW opcode + dep-flag bit positions (ground truth to compare against) |
| `src/packages/NPU_HW_params_pkg.sv` | tile/array params used by both sides |

## Questions to answer

1. **PSB_ACC:** Does `build_standard_instrs` emit `OP_PSB_ACC` between MATMUL and
   PSB_FLUSH? The log shows it does **not**. Is ACC required by the HW (Task 03)?
   If so, the microcode is missing the op that writes SA rows into PSB → zeros.
2. **ISA parity:** Do python `OP_*` opcode values, `unit_id`s, and dep-flag bit
   positions (`[127:120]/[119:116]/[115:112]/[111:0]`, PUSH_NEXT=0x8…POP_PREV=0x1)
   exactly match `NPU_ISA_pkg.sv`? Any mismatch silently breaks decode/gating.
3. **Memory map:** coeff `0x0–0x7`, weights `0x600` (word) / `0x6000` (byte?),
   acts `0x700` / `0x7000`, output `0x8000`. The log shows DMA src addrs `0x6000`,
   `0x7000`, `0x8000` — confirm the payload base addrs and the BFM memory builders
   agree on word-vs-byte addressing. Off-by-shift here feeds SA wrong data.
4. **Sampling timing:** the test polls `irq_done` then reads `store_words[0]`. If
   `irq_done` asserts on sequencer-idle (Task 01) the test samples **before** the
   pipeline drains. Should the test instead wait for an all-units-done / fence?
5. **Golden model:** does `golden_matmul_requant` (acc = W@A int32; out =
   clip(acc*M >> S, -128,127); M=1,S=11) match the HW requant exactly, including
   rounding and clip bounds? Confirm `pack_acts_128b` LSB-first ordering matches HW.
6. **Config:** is `OP_CONFIG` (tile_m/n/k=16) consumed correctly so SA/PSB use the
   right dimensions? The log shows CONFIG isn't counted in `dispatches=8` — confirm
   it's handled by the sequencer, not dropped.

## Preliminary findings (Claude)

- Program order (from log): CONFIG, COEFF_LOAD, WT_LOAD, DMA_LOAD, MATMUL,
  PSB_FLUSH, REQUANT, LUT_BYPASS, DMA_STORE — **no PSB_ACC**. If HW needs PSB_ACC
  to load SA rows into the buffer, this is a **testbench/microcode bug** and the
  most likely single root cause of all-zeros (pairs with Task 03).
- Dep flags are set (`0xF` on MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS) but produce
  `fences=0 stalls=0` in HW — either HW ignores them (Task 01) or the bit
  positions/opcodes disagree with `NPU_ISA_pkg.sv`. **Compare the two ISA defs
  byte-for-byte.**
- IRQ_DONE polling likely samples too early; even with correct data the fixed
  completion-on-idle would race the pipeline. Recommend the test wait on a true
  drain signal.

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

### Root cause (short version)
The microcode IS missing `OP_PSB_ACC` — a real testbench/assembler bug, and
ANALYSIS_03 independently confirms HW requires it (explicit per-row
accumulation; no SA→PSB auto-capture path exists). Everything else this task
was asked to check — ISA encoding, memory-map addressing, golden-model
arithmetic/packing, `OP_CONFIG` handling — is **correct**. The "IRQ_DONE
samples too early" preliminary hypothesis is **refuted**: `irq_done` is wired
to `dma_store_done`, not sequencer-idle, and the test's poll-then-read is
race-free; the bug is that `dma_store_done` itself fires too early (an HW
dep-token defect, ANALYSIS_01's domain).

### Q1 — Is `OP_PSB_ACC` missing, and does HW need it?
**Yes, and yes — confirmed microcode bug.**
- `build_standard_instrs()` (`tb/CocoTB/NPU/npu_isa.py:115-138`) emits exactly
  9 instructions: CONFIG, COEFF_LOAD, WT_LOAD, DMA_LOAD, MATMUL, PSB_FLUSH,
  REQUANT, LUT_BYPASS, DMA_STORE — **zero `OP_PSB_ACC`** (opcode `0x21` never
  appears; the commented-out "previous version" at `npu_isa.py:144-161` is
  identical in op sequence, just with `dep_flags=0`, so this isn't a
  regression from a working program — `OP_PSB_ACC` was never in either
  version).
- ANALYSIS_03 (Q1/Q2/Q6, `docs/analysis/ANALYSIS_03_PSB_ACCUMULATE_FLUSH.md:58-84,160-175`)
  independently traced the RTL and found **no** SA→PSB auto-capture path:
  `psb.row_valid` is sourced solely from `Dispatch_PSB` and pulses only on
  `OP_PSB_ACC` retirement (`Dispatch_PSB.sv:78-84`); `PSB_Block.sv:173-177`
  explicitly ties off `sa_row_valid` as "reserved for future use." With no
  `OP_PSB_ACC`, the buffer is read back all-zero (post-reset value) when
  `OP_PSB_FLUSH` runs.
- **Fix for the testbench:** insert 16 `make_instr(OP_PSB_ACC, UNIT_PSB, ...)`
  instructions between MATMUL and PSB_FLUSH (one per SA output row, per
  `Dispatch_PSB.sv:4-9` header: "Fire one row of accumulation per instr...
  After 16 PSB_ACCs psb pulses acc_done"). This is squarely a
  testbench/microcode defect — the assembler under-builds the program for the
  PSB's documented explicit-accumulate design.

### Q2 — ISA parity: do python opcodes / unit IDs / dep-flag bit positions match `NPU_ISA_pkg.sv`?
**Exact match — no encoding bug anywhere.** (Independently corroborates
ANALYSIS_01 Q1/Q5, `docs/analysis/ANALYSIS_01_SEQUENCER_DISPATCH.md:83-106,158-164`.)
- **Bit-field layout:** `make_instr` (`npu_isa.py:42-48`) packs
  `opcode<<120 | unit_id<<116 | dep_flags<<112 | payload` exactly matching
  `OPCODE_MSB/LSB=127/120`, `UNIT_ID_MSB/LSB=119/116`,
  `DEP_FLAGS_MSB/LSB=115/112`, `PAYLOAD_MSB/LSB=111/0`
  (`src/packages/NPU_ISA_pkg.sv:53-63`).
- **Unit IDs:** `npu_isa.py:4-9` (`UNIT_SEQ..UNIT_VPU = 0x0..0x5`) == the
  `npu_unit_e` enum (`NPU_ISA_pkg.sv:68-75`).
- **Opcodes:** all 20 values in `npu_isa.py:20-39` (`OP_CONFIG=0x01` through
  `OP_HREDUCE=0x38`) match `npu_opcode_e` 1:1 (`NPU_ISA_pkg.sv:80-112`),
  including every opcode actually used in the program: `CONFIG=0x01`,
  `COEFF_LOAD=0x15`, `WT_LOAD=0x10`, `DMA_LOAD=0x11`, `MATMUL=0x20`,
  `PSB_FLUSH=0x22`, `REQUANT=0x30`, `LUT_BYPASS=0x32`, `DMA_STORE=0x12`.
- **dep_flags bit values:** `DEP_PUSH_NEXT/PREV/POP_NEXT/POP_PREV =
  0x8/0x4/0x2/0x1` (`npu_isa.py:14-17`) occupy the correct 4-bit field at the
  correct position. **However**, per `Sequencer.sv:341`
  (`fifo_payload <= {dec_opcode, dec_dep, dec_payload}`) the field is only
  ever *passed through* — none of `Dispatch_SA/_PSB/_REQ/_VPU` read
  `fifo_dout[119:116]` (each decodes only the opcode byte:
  `Dispatch_SA.sv:52`, `Dispatch_PSB.sv:50`, `Dispatch_REQ.sv:66`,
  `Dispatch_VPU.sv:97`), and `Dispatch_DMA.sv:111-117` derives its dep gate
  (`need_dep_sa`/`need_dep_vpu`) purely from the **latched opcode**, never
  from the encoded nibble. Push/pop are hard-wired structurally inside the
  `*_Block` wrappers (`SA_Block.sv:108,116-123`, `PSB_Block.sv:96,101-105`,
  `Requant_Block.sv:107-117`, `VPU_Block.sv:113,118-122`). So while the
  *encoding* is correct, the field is functionally **dead** in this HW
  revision — a real defect, but it lives in the dispatch/dependency logic
  (ANALYSIS_01's domain), not in the testbench's encoder. Setting
  `dep_flags=0xF` vs `0x0` produces byte-identical HW behavior (confirmed by
  comparing against the commented-out all-zero-flags variant,
  `npu_isa.py:144-161`).

### Q3 — Memory map: do payload base addrs and BFM mem builders agree on word-vs-byte addressing?
**Yes — fully consistent, no off-by-shift.**
- Program payload addresses (all in **bytes**): `coeff_addr=0x0000`
  (`npu_isa.py:119`), `wt_base_addr=0x6000` (`npu_isa.py:121`),
  `DMA_LOAD base_addr=0x7000` (`npu_isa.py:123`), `DMA_STORE
  base_addr=0x8000` (`npu_isa.py:137`).
- `AXI4ReadSlave` converts `araddr` (bytes) to a dict key via
  `word_addr = int(self._araddr.value) >> 4` (`npu_bfm.py:110`) — i.e.
  byte-address / 16, because each "word" in `mem` is one 128-bit (16-byte)
  burst beat.
- HW drives the AR address straight from the descriptor's byte-address field
  with no extra shift: `hp0_araddr <= {12'h0, r_base}` where `r_base <=
  src_base` (`src/NPU/DMA.sv:485,635,678`), and `hp1_araddr <= wt_ar_addr <=
  {12'h0, wt_src_base}` (`DMA.sv:841,850`). So `araddr == payload base_addr`
  (bytes), and the BFM's `>>4` correctly recovers the word index.
- `build_dma_mem`/`build_wt_mem` (`npu_golden.py:64-78`) place data at exactly
  those resulting word indices: coeffs at words `0x000-0x007`
  (`0x0000>>4 = 0`), activation at word `0x700` (`0x7000>>4 = 0x700`), weight
  rows at words `0x600-0x60F` (`0x6000>>4 = 0x600`). All three line up
  byte-for-byte with the program's payload addresses. **No addressing bug.**

### Q4 — Sampling timing: does the test sample before the pipeline drains?
**No — the preliminary hypothesis is refuted.** The test's
poll-`irq_done`-then-read-`store_words[0]` pattern is race-free; the real bug
is that `irq_done` itself fires too early (an HW defect, not a TB one).
- `irq_done` is **not** sequencer-idle. `NPU.sv:266`:
  `assign irq_done = dma_store_done_w;` — and the sequencer's own completion
  pulse is explicitly thrown away two lines later: `NPU.sv:267-268`
  (`logic _unused_seq_irq; assign _unused_seq_irq = seq_irq_done_w;`).
  Independently confirmed by ANALYSIS_01 Q4
  (`docs/analysis/ANALYSIS_01_SEQUENCER_DISPATCH.md:142-156`).
- `dma_store_done` (`store_done_r`) only pulses on the **write-response**
  handshake of the final store row — `DMA.sv:798-802`
  (`SS_B: if (hp2_bvalid) ... if (store_cur_h == store_tile_h_r-1)
  store_done_r <= 1'b1`) — which is strictly *after* the W-channel beats for
  that row have already been accepted in state `SS_W`
  (`DMA.sv:787-795`, `SS_W → ... → SS_B`).
- `AXI4WriteSlave._run` appends to `store_words` during the W phase, the
  moment `wvalid && wready` — `npu_bfm.py:185-189`
  (`while not self._wvalid.value: ... self.store_words.append(...)`) — which
  the FSM ordering above guarantees happens one or more beats *before*
  `bvalid`/`store_done_r`/`irq_done`. So by the cycle the test observes
  `dut.irq_done.value == 1` (`test_single_layer.py:41`), `st.store_words`
  is **already populated** with the (wrong, all-zero) captured word — there
  is no TB-side race that would explain or contribute to the all-zeros result.
- The actual defect is *why* `dma_store_done_w` (and thus `irq_done`) fires
  on cycle 100 while SA/PSB/REQ are still mid-pipeline: ANALYSIS_01's root
  cause #2 — `dep_req_to_vpu` is instantiated with `RESET_COUNT(1)`
  (`NPU.sv:330`), so VPU's RAW gate is satisfied at reset, `OP_LUT_BYPASS`
  retires almost immediately, and its completion pulse satisfies
  `OP_DMA_STORE`'s `dep_vpu_to_dma` wait long before the real data exists
  (`docs/analysis/ANALYSIS_01_SEQUENCER_DISPATCH.md:73-79`). **This belongs to
  ANALYSIS_01, not to the testbench** — recommend the preliminary finding #3
  ("IRQ_DONE polling likely samples too early...") be retracted/reworded to
  "`irq_done` (= `dma_store_done`) asserts too early due to a broken
  dependency-token chain," since the *test's* sampling discipline is correct.

### Q5 — Golden model: does `golden_matmul_requant` match HW requant exactly (incl. rounding/clip), and does `pack_acts_128b` ordering match HW?
**Arithmetic matches exactly; packing convention matches exactly; one latent
(currently-masked) blind spot noted below.**
- **Multiply → shift → clip pipeline:** golden does
  `acc=W@A (int32); scaled=acc*M; shifted = scaled >> S; clip(shifted,-128,127)`
  (`npu_golden.py:14-22`). HW `RequantSingleLane` does the same sequence:
  bias-add (`RequantSingleLane.sv:74-79`, see below), multiply by M0
  (`:104-120`), **arithmetic** right shift `prod_a_s2 >>> n_a_s2`
  (`:141-150`), then clamp `total_s4 > 127 → 127`, `< -128 → -128`, else
  truncate to `[7:0]` (`:158-168`). Python's `>>` on ints is a true
  arithmetic/floor shift — bit-identical to SV `>>>` on signed values — so
  there is **no rounding-mode mismatch** (neither side does
  round-to-nearest/round-half-up).
- **Bias:** the golden model has no bias term; HW ties `req_bias = '0`
  for the SA/matmul path — `Dispatch_REQ.sv:84-85` ("bias is fixed 0 for
  SA-path requant"). Consistent.
- **Clip bounds:** both `[-128, 127]` (`npu_golden.py:21`,
  `RequantSingleLane.sv:163-165`). `gen_tile`'s scale choice
  (`M=1, S=11`, comment "max |out|=126 < 127", `npu_golden.py:9-10`) means
  the clip path is essentially never exercised by this seed — a coverage gap,
  not a correctness bug.
- **Packing/ordering — LSB-first, byte `i` = element `i`, confirmed
  consistent end-to-end:**
  - `pack_weights_128b` ("col 0 in LSB", `npu_golden.py:25-33`) ↔
    `weightInputRow[gi] = sa_wt_rdata[gi*8 +: 8]` (`SA_Block.sv:178`).
  - `pack_acts_128b` ("byte 0 = A[0] in LSB", `npu_golden.py:36-41`) ↔
    `activationInputCol[gi] = sa_act_rdata[gi*8 +: 8]` (`SA_Block.sv:181`).
  - Output side reuses `pack_acts_128b` to build `expected`
    (`test_single_layer.py:57`); HW assembles `data_o[j*8 +: 8] =
    lane_data_o[j]` (`RequantPipeline.sv:157`), i.e. lane `j` (= PSB row `j`
    = output channel `j`, per ANALYSIS_03 Q3) → byte `j`. Same convention on
    both ends — `actual == expected` is a valid byte-for-byte comparison once
    the data itself is correct.
- **Latent blind spot (not the cause of the current failure):**
  `Requant_Block` is instantiated with `ChCount = 1` (`NPU.sv:794`), and
  `Dispatch_REQ`'s coefficient-load loop bound is the **module parameter**
  `ChCount`, not the payload's `ch_count` field — `Dispatch_REQ.sv:128-150`
  loads only **one** `(M0, shift)` pair and `RequantPipeline` broadcasts it
  to all 16 lanes (`Ch = gi / LanesPerCh` ⇒ `Ch=0` for every lane when
  `LanesPerCh = Lanes/ChCount = 16`, `RequantPipeline.sv:118-122`) — even
  though the microcode encodes `ch_count=16`
  (`make_requant_payload(ch_count)`, `npu_isa.py:130-132`). The golden model
  applies a **distinct** `M[i]`/`S[i]` per output channel
  (`npu_golden.py:18-21`). `gen_tile` happens to set `M = ones(16)` and
  `S = full(16, 11)` — *uniform* across channels (`npu_golden.py:9-10`) — so
  broadcast-vs-per-channel is numerically indistinguishable for this seed and
  the golden model is *currently* correct. **If `gen_tile` is ever changed to
  use non-uniform per-channel M/S (more realistic), the golden model would
  start mismatching this HW configuration** — worth flagging to whoever owns
  `ChCount` sizing/`Dispatch_REQ` (outside this task's scope to fix).

### Q6 — Is `OP_CONFIG` consumed correctly (not dropped)?
**Yes — consumed in-line by the Sequencer, which is exactly why
`dispatches=8` for a 9-instruction program; not a bug.**
- `Sequencer.sv:317-331`: `OP_CONFIG` is decoded and handled entirely inside
  `S_DISPATCH` — it latches `cfg_tile_M/N/K`, `cfg_stride`, `cfg_pad_mode`,
  `cfg_act_type`, `cfg_pool_size`, `cfg_coeff_base` from the decoded payload,
  then advances `fetch_ptr`/`fetch_remaining` and returns to `S_AR` — **it
  never asserts `fifo_push`** (that only happens in the `default:` branch,
  `Sequencer.sv:338-347`). So of the 9 program instructions, 8 reach a unit
  FIFO and 1 (CONFIG) is consumed by the sequencer itself — `dispatches=8` is
  the expected, correct count, not evidence CONFIG was dropped.
- The captured CSRs are wired onward: `cfg_tile_K → SA_Block`
  (`NPU.sv:721`) and `cfg_tile_M/cfg_tile_N → VPU_Block` (`NPU.sv:846-847`).
  However, `Dispatch_SA.sv:16-17` documents `cfg_tile_K` as "unused this
  phase; SA processes its hardware K_DIM internally" — i.e. SA ignores the
  CONFIG-supplied K and uses a fixed HW constant instead. This is harmless
  for the current program because `tile_K=16` (`make_config_payload(16,16,16,...)`,
  `npu_isa.py:117`) equals the HW array's `K_DIM`, but it means CONFIG's
  `tile_K` is presently a documented no-op rather than a load-bearing input —
  worth noting for anyone relying on CONFIG to *change* tile dimensions at
  runtime (not exercised by this single fixed-size-tile test).

### Conclusion / scorecard for this task's mandate
| Suspect (from brief)                          | Verdict |
|------------------------------------------------|---------|
| Program omits `OP_PSB_ACC`                     | **CONFIRMED bug** — real, and HW-required (ANALYSIS_03). Fix: emit 16 `OP_PSB_ACC` between MATMUL and PSB_FLUSH. |
| Python ISA encoding vs `NPU_ISA_pkg.sv` mismatch | **Not found** — bit-for-bit match (opcodes, unit IDs, field positions, dep-flag values). The dep-flags *field* is correctly encoded but functionally dead in HW (ANALYSIS_01 territory). |
| Memory-map / word-vs-byte addressing            | **Not found** — payload addrs are bytes, BFM `>>4` and mem-builder placements agree exactly (0x0000→wd 0, 0x6000→wd 0x600, 0x7000→wd 0x700). |
| Test samples output before pipeline drains      | **Refuted as a TB issue** — `irq_done = dma_store_done`, and `store_words` is populated strictly before `irq_done` asserts (W-phase precedes B-phase). The *real* problem is `dma_store_done` itself firing too early — an HW dependency-token defect (ANALYSIS_01 root cause #2), not a test-sampling defect. |
| Golden model arithmetic / packing                | **Matches HW exactly** (mult→`>>>`→clip, bias=0, LSB-first byte packing both ends). Noted one latent `ChCount=1`-broadcast-vs-per-channel blind spot that today's uniform `gen_tile` M/S values mask — not the cause of the present failure. |
| `OP_CONFIG` handling                             | **Correct** — consumed in-line by Sequencer (explains `dispatches=8`); `cfg_tile_K` is wired to SA but documented as currently unused there (no effect on this program since `tile_K==K_DIM==16`). |

**Net:** Of the two suspects this task was asked to confirm/refute, suspect #1
(missing `OP_PSB_ACC`) is real and is a genuine testbench/microcode bug —
ANALYSIS_03 shows it is independently sufficient to cause all-zero PSB→Requant
data. Suspect #2 (ISA encoding mismatch) is **refuted** — the encoding is
correct; the dep-flags field is simply unused by this HW revision (a design
issue, not an encoding bug). The all-zeros symptom is therefore the product of
**at least three independent defects** stacked together: (a) missing
`OP_PSB_ACC` in microcode [this task / TB], (b) `Requant_Block.deps_ready`
missing the PSB RAW check + `PSB_FLUSH`/`Dispatch_REQ` config race [ANALYSIS_03
Q5 / ANALYSIS_01], and (c) `dep_req_to_vpu` reset-count defect causing
`OP_DMA_STORE` (and `irq_done`) to fire before the pipeline produces real data
[ANALYSIS_01 root cause]. Fixing only the microcode (a) would not by itself
produce correct output — (b) and (c) must also be fixed in RTL.
