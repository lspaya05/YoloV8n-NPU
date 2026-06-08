# Analysis Task 01 — Sequencer, Dispatch & Dependency Tokens

**Bug:** single-layer NPU output all-zeros; SA not finishing before output.
**Mode:** static read-only. No sim. No code changes. Append findings only.

---

## Scope

Determine whether the hardware actually **honors the software-encoded dependency
tokens** (`dep_flags[115:112]`) and fences. The run summary reports
`fences=0 stalls=0`, and the sequencer reaches `S_IDLE` (cyc 88) while SA has only
just entered RUN — i.e. ops dispatch back-to-back with no RAW/WAR blocking. This
task traces the dep-token / fence path end-to-end and pins down what drives
`irq_done`.

## Files to read

| File | Why |
|------|-----|
| `src/NPU/Sequencer.sv` | FETCH FSM (S_IDLE/S_AR/S_R/S_DISPATCH/S_FENCE), opcode/dep decode, fence-mask wait |
| `src/NPU/NPU.sv` | DepFIFO instantiation + wiring; `units_done` vector; `irq_done` source |
| `src/NPU/Dispatch/Dispatch_SA.sv` | does it block on `dep_*_empty/full` before issuing? |
| `src/NPU/Dispatch/Dispatch_PSB.sv` | dep gating for PSB |
| `src/NPU/Dispatch/Dispatch_REQ.sv` | dep gating for Requant (note 50aa8e1 changed this) |
| `src/NPU/Dispatch/Dispatch_VPU.sv` | dep gating for VPU |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | dep gating for DMA load/store |
| `src/Memory/DepFIFO.sv` | token FIFO push/pop/empty/full semantics |
| `src/packages/NPU_ISA_pkg.sv` | HW opcode + dep-flag bit positions (compare vs `tb/CocoTB/NPU/npu_isa.py`) |

## Questions to answer

1. Are the 4 `dep_flags` bits (PUSH_NEXT=0x8, PUSH_PREV=0x4, POP_NEXT=0x2,
   POP_PREV=0x1) **decoded in HW** and routed to DepFIFO push/pop enables? Where?
2. Does **any** dispatch unit actually *stall* its dispatch when the required
   `dep_*_empty`/`dep_*_full` condition is not met? Quote the gating expression.
3. The test program contains **no `OP_FENCE`**. Does the FENCE FSM ever run? Is
   ordering supposed to come from FENCE, from per-op dep tokens, or both?
4. What drives `irq_done` / program completion — sequencer reaching `S_IDLE`, or
   all `units_done` asserted? If sequencer-idle, the run can finish while SA/PSB
   are still computing.
5. Do the HW dep-flag bit positions and opcode values in `NPU_ISA_pkg.sv` match
   the python encoder `npu_isa.py`? Any mismatch silently disables gating.
6. Is `stalls`/`fences` counter in the top summary even incremented on a real
   stall, or is it dead? (Confirms whether `fences=0 stalls=0` is meaningful.)

## Preliminary findings (Claude)

- Log: `SUMMARY cycles=100 dispatches=8 fences=0 stalls=0`. All 8 ops dispatched
  and sequencer hit `S_IDLE` by cyc 88, while `SAR LOAD->RUN` also at cyc 88 —
  SA had not drained. Strongly suggests dispatch is **not** blocking on dep tokens.
- Microcode sets `dep_flags=0xF` on MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS
  (`tb/CocoTB/NPU/npu_isa.py`), so the intent is full serialization — but HW shows
  none.
- Suspect either: (a) dep bits not decoded/wired, (b) dispatch reads token but
  doesn't actually hold issue, or (c) `irq_done` fires on sequencer-idle so the
  pipeline never gets to finish regardless.
- A prior exploration *claimed* a Sequencer FENCE FSM blocks until
  `(units_done & fence_mask)==fence_mask` — but no OP_FENCE is in the program, so
  that path may be unused here. Verify.

## Findings (append below)

<!-- analysis agent: add your findings here, cite file:line. Do not edit above this line. -->

## Findings — static trace (Claude, read-only)

### Root cause (short version)
Two independent dep-token defects compound into the all-zero capture:

1. **`Requant_Block.deps_ready` omits the upstream RAW check** on PSB
   (`dep_psb_to_req_empty`) — REQUANT can issue before PSB_FLUSH retires.
2. **`dep_req_to_vpu` DepFIFO is instantiated with `RESET_COUNT(1)`**
   (non-empty at reset) — VPU's RAW gate on REQUANT is satisfied from cycle 0,
   so VPU's lone queued op (`OP_LUT_BYPASS`, a 1-cycle no-op) fires almost
   immediately, long before SA/PSB/REQ run. Its completion pulses
   `dep_vpu_to_dma_push`, which is exactly the token `OP_DMA_STORE` is waiting
   on — so DMA_STORE reads the still-zero Output Bank and stores it. **#2 is
   the direct cause of "SA not finishing before output."**

---

### Q1 — Are `dep_flags` bits decoded in HW and routed to push/pop enables?
Decoded, yes — but **never consulted**. `Sequencer.sv:190,197` decodes
`dec_dep = instr_buf[DEP_FLAGS_MSB:DEP_FLAGS_LSB]` and `Sequencer.sv:341`
packs it straight through: `fifo_payload <= {dec_opcode, dec_dep, dec_payload}`.
None of `Dispatch_SA/_PSB/_REQ/_VPU/_DMA` ever read bits `[119:116]` of
`fifo_dout` — each only decodes the opcode byte `fifo_dout[123:116]`
(e.g. `Dispatch_SA.sv:52`, `Dispatch_PSB.sv:50`, `Dispatch_REQ.sv:66`,
`Dispatch_VPU.sv:97`, `Dispatch_DMA.sv` r_opcode latch at line 164).

Push/pop are instead **hard-wired structurally** inside each `*_Block`
wrapper, independent of the encoded nibble:
- pop = unconditional issue strobe `*_rd_en_from_dispatch`
  (`SA_Block.sv:116-117`, `PSB_Block.sv:101-102`, `Requant_Block.sv:113-114`,
  `VPU_Block.sv:118-119`)
- push = unconditional completion pulse `*_done_pulse`
  (`SA_Block.sv:122-123`, `PSB_Block.sv:104-105`, `Requant_Block.sv:116-117`,
  `VPU_Block.sv:121-122`)

So the assembler's `DEP_PUSH_NEXT/PREV`/`DEP_POP_NEXT/PREV` nibble
(`tb/CocoTB/NPU/npu_isa.py:14-17`) is **dead** — it happens to coincide with
the "always do both push and both pop" structural behavior for ops encoded
`0xF`, but the HW would behave identically even if the assembler emitted
`0x0` for MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS (see the commented-out
zero-flags variant at `npu_isa.py:142+`).

### Q2 — Does any dispatch unit actually stall on dep tokens? Quote the gate.
Yes — gating lives in the `*_Block` wrappers ("Option A": virtualize
`fifo_empty` until `deps_ready`), not in `Dispatch_*` (which are documented
as untouched). Exact `deps_ready` expressions:
- `SA_Block.sv:108`      `deps_ready = ~dep_dma_to_sa_empty & ~dep_psb_to_sa_empty;`
- `PSB_Block.sv:96`      `deps_ready = ~dep_sa_to_psb_empty & ~dep_req_to_psb_empty;`
- `Requant_Block.sv:107-108`
  `deps_ready = ~dep_vpu_to_req_empty & ~dep_req_to_psb_full & ~dep_req_to_vpu_full;`
  — **missing `~dep_psb_to_req_empty`** (the actual RAW-from-PSB gate; the
  port exists at `Requant_Block.sv:61` and is wired from
  `psb_to_req_empty` at `NPU.sv:772`, but in `deps_ready` it's simply absent).
  Instead this expression checks `dep_req_to_psb_full` / `dep_req_to_vpu_full`
  — backpressure on REQ's own *outgoing* producer FIFOs, which is exactly the
  kind of signal `SA_Block.sv:119-121` documents as "intentionally ignored
  this pass — FENCE-based ordering is assumed to prevent overflow." Requant
  is the only block gating on its own push-side `_full`.
- `VPU_Block.sv:113`     `deps_ready = ~dep_req_to_vpu_empty & ~dep_dma_to_vpu_empty;`

`dep_psb_to_req_empty` is referenced exactly once in the whole block — as a
guard on the *pop*, not the issue gate: `Requant_Block.sv:113`
`dep_psb_to_req_pop = req_done_pulse & ~dep_psb_to_req_empty;`. That guard
prevents a DepFIFO underflow but does nothing to delay issue — REQUANT can
run, retire, and (if the token isn't there yet) simply skip the pop.

### Q3 — Does the FENCE FSM ever run? Is ordering meant to come from FENCE or tokens?
`build_standard_instrs()` (`tb/CocoTB/NPU/npu_isa.py:113-138`) emits 9
instructions and **zero `OP_FENCE`**, so `Sequencer` never reaches `S_FENCE`
(consistent with the observed `fences=0`). Every compute op
(MATMUL/PSB_FLUSH/REQUANT/LUT_BYPASS) carries `dep_flags = 0xF`
(`npu_isa.py:124-135`) — the design clearly intends ordering to come
**entirely from per-op dep tokens**, not FENCE, for this program. The FENCE
FSM (`Sequencer.sv:353-359`, `(unit_done & fence_mask) == fence_mask`) is
real and would work if armed, but is simply unused here.

### Q4 — What actually drives `irq_done`?
**`dma_store_done_w`**, not sequencer-idle. `NPU.sv:266`:
`assign irq_done = dma_store_done_w;`
The Sequencer's own completion pulse (`job_active && state==S_IDLE &&
unit_done[1]`, `Sequencer.sv:272-276`, exposed as `seq_irq_done_w`) is
computed then explicitly discarded: `NPU.sv:267-268`
`logic _unused_seq_irq; assign _unused_seq_irq = seq_irq_done_w;`

So "sequencer hits S_IDLE at cyc 88 while SA just entered RUN" is **not**
the irq_done bug — that's expected (the sequencer only streams 8 ops into
deep per-unit FIFOs and returns to idle; it doesn't wait for execution unless
fenced, see Q3). The real question is *why does `dma_store_done_w` assert
early*, and that traces to `Dispatch_DMA`'s `need_dep_vpu` gate
(`Dispatch_DMA.sv:117,194-199`) being satisfied by a premature
`dep_vpu_to_dma` token — see Bug #2 / root cause above.

### Q5 — Do HW dep-flag bit positions / opcodes match `npu_isa.py`?
Yes, positions and opcode values match (`NPU_ISA_pkg.sv:59-60` `[115:112]`
== `npu_isa.py:11,42-46` `(dep_flags & 0xF) << 112`; spot-checked
`OP_REQUANT=0x30`, `OP_PSB_FLUSH=0x22`, `OP_DMA_STORE=0x12`,
`OP_LUT_BYPASS=0x32` against `NPU_ISA_pkg.sv:82-111`). **Moot**, though — per
Q1 the HW never inspects the field, so a mismatch couldn't "silently disable
gating" any more than it already structurally is.

### Q6 — Is `stalls`/`fences` in the run summary meaningful?
Both counters are real (not dead code) but don't measure "did dispatch
block on a dep token":
- `fences` increments on `state == S_FENCE` entry
  (`tb/CocoTB/NPU/npu_monitor.py:280-284`) — correctly zero (no OP_FENCE, Q3).
- `stalls` increments when `cycle - last_event_cyc >= stall_threshold`
  (`npu_monitor.py:434-436`) — a *global quiet-period* detector (any logged
  event resets the clock), not a per-unit dispatch-stall counter. It reads
  zero here simply because the pipeline kept producing loggable events every
  few cycles — including the spurious early completions from Bug #2 — so the
  quiet window never opened. `fences=0 stalls=0` is consistent with, not
  contradictory to, the broken-gating theory; it just isn't direct evidence
  either way for RAW/WAR blocking specifically.

---

### Suggested fix locations (for the implementer, not applied here)
- `NPU.sv:330` — change `dep_req_to_vpu` to default `RESET_COUNT` (0/empty),
  matching its RAW siblings `dep_dma_to_sa` (`:294`), `dep_sa_to_psb`
  (`:306`), `dep_psb_to_req` (`:318`).
- `Requant_Block.sv:107-108` — add `~dep_psb_to_req_empty` to `deps_ready`
  (and reconsider whether the `_full` terms belong there at all, given the
  "intentionally ignored" convention documented in `SA_Block.sv:119-121`).

