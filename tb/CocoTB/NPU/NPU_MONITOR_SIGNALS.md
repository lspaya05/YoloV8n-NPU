# NPU Monitor Signal Reference

Decode guide for the `[cyc N] [TAG] message` log emitted by
[`npu_monitor.py`](npu_monitor.py) (`NpuObserver`). Every line carries a 3-letter
owner tag so you can tell at a glance which unit acted. Grep a run by tag, e.g.
`grep '\[DMA\]'`.

## 1. Tag legend

| Tag | Owner | Emits |
|-----|-------|-------|
| `SEQ` | Sequencer | dispatch, fetch-FSM transitions, fence arm/release, `fetch_err`, dispatch-FIFO backpressure |
| `DMA` | DMA engine | Ch0/Ch1 start+idle, ACT/WT bank handoffs (DMA is producer), store complete, `dma_err` |
| `SAR` | Systolic array | controller FSM transitions, done pulse, ACT/WT bank releases |
| `PSB` | Partial-Sum Buffer | done pulse |
| `REQ` | Requant | done pulse |
| `VPU` | Vector Processing Unit | done pulse |
| `CSR` | AXI-Lite control regs | register writes (addr/data) |
| `AXI` | HP0 memory bus | AR/R handshakes + burst beats |
| `TOP` | Monitor meta | `IRQ_DONE`, STALL dump header, heartbeat (`HB`), final `SUMMARY` |

Inside the STALL dump, indented detail lines use a blank `[   ]` tag so they
visually nest under the `[TOP] STALL` header.

## 2. Event glossary

### `[SEQ]`
- `DISPATCH <OP> -> <unit>` — sequencer pushed an instruction into a unit's
  dispatch FIFO. Target name from `disp_push` bit (0=DMA_Ch0, 1=SA, 2=PSB,
  3=REQ, 4=VPU, 5=DMA_Ch1). Opcode decoded from `disp_payload[123:116]`.
- `FETCH_FSM <a> -> <b>` — fetch FSM state change (non-fence).
- `FENCE armed, waiting on <units>` — entered `S_FENCE`; lists the units whose
  done-tokens it blocks on (`fence_mask`).
- `FENCE released after N cyc` — all awaited units reported done; FSM left `S_FENCE`.
- `ERROR fetch_err asserted` — instruction fetch error (bad AXI read of seq mem).
- `BACKPRESSURE unit=<u> FIFO full >100 cyc` — a dispatch FIFO stayed full,
  stalling the sequencer; usually the downstream unit is wedged.

### `[DMA]`
- `Ch0 START mode=<m> src=0xADDR` — Ch0 descriptor launched. `mode` ∈
  {LOAD, UPSAMPLE, CONCAT, STORE, COEFF, LUT}.
- `Ch1 START src=0xADDR` — Ch1 (weight) load launched.
- `Ch0 IDLE` / `Ch1 IDLE` — channel returned to idle (descriptor done).
- `ACT bank handoff DMA -> SA` / `WT bank handoff DMA -> SA` — DMA filled an
  activation/weight bank and handed ownership to the SA (double-buffer flip).
- `DMA_STORE complete` — store FSM wrote the result tile back to DDR.
- `ERROR dma_err asserted` — DMA AXI/datapath error.

### `[SAR]`
- `IDLE->LOAD: weight loading started`
- `LOAD->RUN: weights loaded, activations streaming`
- `RUN->DRAIN: activations done, draining pipeline`
- `DRAIN->DONE: matmul complete`
- `DONE` — `sa_done_pulse` (1-cycle completion).
- `released ACT bank` / `released WT bank` — SA finished reading a bank,
  returning it to DMA for refill.

### `[PSB]` / `[REQ]` / `[VPU]`
- `DONE` — that unit's `*_done_pulse` fired (one matmul/flush/requant/activation tile finished).

### `[CSR]`
- `CSR write addr=0xAA data=0xDDDDDDDD` — AXI-Lite register write (latched on
  AW/W handshake, logged on `bvalid` rise).

### `[AXI]` (HP0 read master used by DMA Ch0)
- `AR asserted addr=0xADDR len=L (burst beats=L+1)` — read-address request issued.
- `AR handshake` — `arvalid & arready`; burst accepted, beat counter reset.
- `R beat#N rlast=x` — read-data beat received (only beats 1-2 and the last are logged).
- `R rlast handshake on beat#N` — final beat of the burst.

### `[TOP]`
- `IRQ_DONE` — top-level done interrupt asserted.
- `STALL - no events in N cycles` — no real event for `stall_threshold` cyc;
  followed by an indented state snapshot (see §6).
- `HB state=<s> units_done=0b......` — heartbeat, printed only when otherwise quiet.
- `SUMMARY cycles=.. dispatches=.. fences=.. stalls=.. errors=..` — printed by `stop()`.

## 3. FSM state tables

### Sequencer fetch FSM ([Sequencer.sv:225-231](../../../src/NPU/Sequencer.sv))
| Val | Name | Meaning |
|-----|------|---------|
| 0 | `S_IDLE` | waiting for `go` |
| 1 | `S_AR` | issuing AXI read-addr for next 128-bit instruction |
| 2 | `S_R` | receiving instruction beats |
| 3 | `S_DISPATCH` | pushing decoded instruction to a unit FIFO |
| 4 | `S_FENCE` | blocked on `fence_mask` until awaited units report done |

### SA controller FSM `ps` ([SA_Controller.sv:40](../../../src/WeightStationarySA/SA_Controller.sv))
| Val | Name | Meaning |
|-----|------|---------|
| 0 | `IDLE` | waiting for start |
| 1 | `LOAD` | broadcasting weight-load enable to fill the array |
| 2 | `RUN` | streaming valid activations through the array |
| 3 | `DRAIN` | inputs stopped; in-flight data finishing |
| 4 | `DONE` | 1-cycle completion pulse, then back to IDLE |

### DMA read FSM `state` ([DMA.sv:312-325](../../../src/NPU/DMA.sv))
| Val | Name | Meaning |
|-----|------|---------|
| 0 | `S_IDLE` | idle; accepts a new descriptor |
| 1 | `S_PIXEL` | compute pixel address, evaluate padding |
| 2 | `S_AR` | issue HP0 AR, hold until `arready` |
| 3 | `S_R` | receive R beats, write Act/Res SRAM |
| 4 | `S_PAD` | insert zero padding (no DDR access) |
| 5 | `S_ADV` | advance tile counters; pulse `load_done` |
| 6 | `S_C_AR` | COEFF_LOAD: issue AR for ceil(ch/2) beats |
| 7 | `S_C_R` | COEFF_LOAD: capture beat, write low half |
| 8 | `S_C_WR1` | COEFF_LOAD: write high half from captured beat |
| 9 | `S_L_AR` | LUT_LOAD: issue AR for 16 beats (256 B) |
| 10 | `S_L_R` | LUT_LOAD: capture beat, init byte index |
| 11 | `S_L_WR` | LUT_LOAD: drain captured beat one byte/cycle |

### DMA store FSM `store_state` ([DMA.sv:364-366](../../../src/NPU/DMA.sv))
`SS_IDLE`(0), `SS_AW`(1), `SS_W_PRIME1`(2), `SS_W_LOAD`(3), `SS_W`(4), `SS_B`(5).

### DMA `fetch_mode` ([DMA.sv:16](../../../src/NPU/DMA.sv))
`000`=LOAD `001`=UPSAMPLE `010`=CONCAT `011`=STORE `100`=COEFF_LOAD `101`=LUT_LOAD.

## 4. Dependency model ([npu_isa.py:11-17](npu_isa.py))

Pipeline order: `DMA(1) -> SA(2) -> PSB(3) -> REQ(4) -> VPU(5) -> DMA(1)`.
"next" = downstream, "prev" = upstream. Each instruction's `dep_flags`
(bits `[115:112]`) gate it against per-edge token FIFOs:

| Flag | Bit | Meaning |
|------|-----|---------|
| `DEP_PUSH_NEXT` | 0x8 | push done-token to downstream RAW FIFO |
| `DEP_PUSH_PREV` | 0x4 | push done-token to upstream WAR FIFO |
| `DEP_POP_NEXT`  | 0x2 | block until token from upstream RAW FIFO |
| `DEP_POP_PREV`  | 0x1 | block until token from downstream WAR FIFO |

RAW = read-after-write (consumer waits for producer); WAR = write-after-read
(producer waits for consumer to free the buffer). In a STALL dump the
`dep_X->Y empty=1` lines show which edge FIFO is starved.

## 5. Opcodes ([npu_isa.py:19-39](npu_isa.py))

| Op | Hex | Unit |
|----|-----|------|
| `OP_CONFIG` | 0x01 | SEQ |
| `OP_FENCE` | 0x02 | SEQ |
| `OP_WT_LOAD` | 0x10 | DMA Ch1 |
| `OP_DMA_LOAD` | 0x11 | DMA Ch0 |
| `OP_DMA_STORE` | 0x12 | DMA Ch0 |
| `OP_UPSAMPLE` | 0x13 | DMA Ch0 |
| `OP_CONCAT` | 0x14 | DMA Ch0 |
| `OP_COEFF_LOAD` | 0x15 | DMA Ch0 |
| `OP_MATMUL` | 0x20 | SA |
| `OP_PSB_ACC` | 0x21 | PSB |
| `OP_PSB_FLUSH` | 0x22 | PSB |
| `OP_REQUANT` | 0x30 | REQ |
| `OP_LUT_LOAD` | 0x31 | VPU |
| `OP_LUT_BYPASS` | 0x32 | VPU |
| `OP_SIMD_ACT` | 0x33 | VPU |
| `OP_RELU` | 0x34 | VPU |
| `OP_ELEW_ADD` | 0x35 | VPU |
| `OP_ELEW_MUL` | 0x36 | VPU |
| `OP_MAXPOOL` | 0x37 | VPU |
| `OP_HREDUCE` | 0x38 | VPU |

## 6. STALL dump field guide

When no real event occurs for `stall_threshold` cycles, the monitor dumps a
snapshot (all lines tagged `[   ]` under the `[TOP] STALL` header):

| Field | Read as |
|-------|---------|
| `state` | sequencer fetch FSM (§3); `S_FENCE` ⇒ blocked on dependencies |
| `fence_mask = 0b......` | units the fence still waits on; bit i set ⇒ unit i not done. Bit order = unit IDs (SEQ0 DMA1 SA2 PSB3 REQ4 VPU5) |
| `units_done = 0b......` | which units have reported done this fence |
| `dma_ch0_idle` / `dma_ch1_idle` | 1 ⇒ that DMA channel parked (not the bottleneck) |
| `dma_state` / `dma_store_state` | DMA read/store FSM (§3); pinned non-idle ⇒ stuck mid-transfer |
| `coeff_beats_received/total`, `coeff_waddr_r`, `coeff_last_beat` | COEFF_LOAD progress; received<total with idle AXI ⇒ hung coeff fetch |
| `HP0 AR: ...` | read-addr channel; `arvalid=1 arready=0` ⇒ memory not accepting the request |
| `HP0 R: ...` | read-data channel; `rvalid=0` ⇒ memory not returning data |
| `dep_X->Y empty=1` | the RAW/WAR token FIFO for that pipeline edge is empty — the consumer on that edge is starved (§4) |

Bitmask reminder: index by unit ID, LSB = SEQ(0). So `0b000100` in `fence_mask`
means bit 2 = SA still outstanding.
