# NPU DMA Bring-Up Plan
### EE470 Neural Engine · KR260 · Leonard Paya / Bernardo Lin
### Created: 2026-05-26

**Resume instruction for new Claude instance**: Read this file top-to-bottom before touching any code. This is the single source of truth. The old `src/NPU/README.md` has been deleted; its content is absorbed here.

Repo root: `c:\Users\Leona\GitHubRepo\EE470-FinalProject`

**Rule**: Do NOT proceed to the next phase without explicit user sign-off. Phase 0 is auto-accepted.

---

## Status Table

| Phase | Scope | Status | Notes |
|---|---|---|---|
| 0 | Write this plan markdown; delete old README | DONE | This file |
| 1 | DMA.sv port fix (hp1→hp2, add hp1 read), bank_full, unit_done level, NPU.sv HP2 port | NOT STARTED | No behavior change to Load FSM |
| 2 | Dispatch_DMA real decoder: FSM + descriptor drive | NOT STARTED | Replaces stub that just drains FIFO |
| 3 | NPU.sv Act Bank wiring + dep_dma_to_sa push | NOT STARTED | First end-to-end DMA_LOAD path |
| 4 | Ch1 WT_LOAD FSM, HP1 read, Weight Bank wiring | NOT STARTED | Concurrent prefetch |
| 5 | DMA_STORE fix: HP2 write, row loop, BRAM pipeline | NOT STARTED | dep_dma_to_vpu, irq_done |
| 6 | COEFF_LOAD + LUT_LOAD, ISA pkg fixes | NOT STARTED | Coeff BRAM + LUT BRAM |
| 7 | UPSAMPLE + CONCAT | NOT STARTED | FPN ops |

---

## Files Owned by This Plan

| File | Role | First Phase |
|---|---|---|
| `src/NPU/DMA.sv` | DMA datapath | 1 |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | FIFO decoder + descriptor driver | 2 |
| `src/NPU/NPU.sv` | Top-level wiring | 1 |
| `src/packages/NPU_ISA_pkg.sv` | ISA fixes | 6 |

**Reused, no edits:**
- `src/Memory/FIFO.sv` — instruction FIFOs
- `src/Memory/DepFIFO.sv` — dep token counters
- `src/Memory/SRAMHub.sv` — SRAM bank mux

---

## What Is Already Correct in DMA.sv

- **Load FSM** (S_IDLE → S_PIXEL → S_AR → S_R → S_PAD → S_ADV): solid 2D strided read with zero-padding. Keep as-is.
- **2D address generator**: `row_base` + `col_off` iterative adder (no multiplier). Correct.
- **is_pad** combinational logic: correct pad edge detection.
- **HP0 AXI4 constants**: arsize=3'b100, arburst=INCR, arcache=4'b0011. Correct.
- **Descriptor shadow registers**: latched on start pulse. Correct.
- **Dep port stubs**: 8 pins (`dep_sa_to_dma_*`, `dep_vpu_to_dma_*`, `dep_dma_to_sa_*`, `dep_dma_to_vpu_*`) present in port list, all tied 0 inside. Structure correct; contents replaced per phase.

---

## What Is Wrong / Missing in DMA.sv

| Problem | Fix Phase |
|---|---|
| `hp1_*` is a write master — must be renamed `hp2_*` | 1 |
| No hp1 read master for Ch1 WT_LOAD | 1 (stub), 4 (full) |
| `done` is a 1-cycle pulse — must be level `ch0_idle & ch1_idle` | 1 |
| `dma_act_bank_full` output missing | 1 |
| `dma_wt_bank_full` output missing | 1 (stub=0), 4 (full) |
| No Ch1 FSM at all | 4 |
| DMA_STORE FSM: single burst only, no row loop | 5 |
| DMA_STORE FSM: no 1-cycle BRAM read latency pipeline | 5 |
| COEFF_LOAD: not implemented | 6 |
| LUT_LOAD: not implemented | 6 |
| UPSAMPLE: stub/TODO comment only | 7 |
| CONCAT: stub/TODO comment only | 7 |

---

## What Is Wrong / Missing in NPU.sv (DMA section)

| Problem | Fix Phase |
|---|---|
| `units_done[UNIT_DMA] = 1'b1` tied high | 1 |
| `DMA dma_unit` instantiation: `start = 1'b0` | 2 |
| All DMA descriptor ports tied 0 | 2 |
| HP2 write master not in NPU module ports | 1 |
| `wt_araddr` / `wt_rready` tied off (HP1 Ch1) | 4 |
| SRAMHub `dma_act_waddr/wdata/wen/bank_full` tied 0 | 3 |
| SRAMHub `dma_wt_waddr/wdata/wen/bank_full` tied 0 | 4 |
| SRAMHub `dma_out_raddr` tied 0 | 5 |
| SRAMHub `dma_coeff_waddr/wdata/wen` tied 0 | 6 |
| SRAMHub `dma_lut_waddr/wdata/wen/sel` tied 0 | 6 |
| `dep_dma_to_sa_push = 0`, `dep_dma_to_vpu_push = 0` (DMA dep stubs) | 3, 5 |

---

## ISA Package Fixes Required

File: `src/packages/NPU_ISA_pkg.sv` (Phase 6)

1. **`OP_LUT_LOAD` unit_id**: change from `UNIT_VPU` → `UNIT_DMA`. Sequencer uses this to route to `disp_push[0]` (Ch0 FIFO) vs `disp_push[4]` (VPU FIFO).
2. **Add `npu_concat_payload_t`**:
   - `base_addr_b[23:0]` packed into bits [111:88] of the 112-bit payload
   - `base_addr_b[31:24]` = same as `base_addr_a[31:24]` (both tensors in same 256 MB DDR4 region: `0x2040_0000–0x2062_FFFF`)
   - Bits [87:0] = normal DMA_LOAD payload fields (same layout)

---

## FIFO Inventory — Modules, Clock Domains, CDC Analysis

### FIFO.sv — synchronous only, no dual-clock

`src/Memory/FIFO.sv` wraps either `xpm_fifo_sync` (`USE_XILINX_XPM=1`) or a custom single-clock RTL (`USE_XILINX_XPM=0`). Both modes: one `clk` for both read and write. **No dual-clock / async FIFO capability.**

### Does the DMA need dual-clock FIFOs?

**No.** Arch doc: *"Clocks: 300 MHz fabric throughout. HP port CDC via SmartConnect."* All NPU PL blocks (Sequencer, DMA, Dispatch_DMA, SA, PSB, Requant, VPU) share a single 300 MHz clock. The AXI HP ports go through AMD SmartConnect IP in the Vivado block design, which handles CDC between PL 300 MHz and PS AXI clock. No clock boundary crosses through FIFO.sv.

**Simulation warning**: if you were to switch to `xpm_fifo_async`, Questa needs `compile_simlib -family zynquplus -simulator questa -library xpm` first. Without it, elaboration fails with "module xpm_fifo_async not found." The existing `runlab.do` does not compile XPM sim libs. The async FIFO also adds 2–3 cycle read latency even with the same clock on both ports, breaking assumptions in any tests expecting 1-cycle latency. **Do not change FIFO.sv.**

### Instruction FIFOs (NPU.sv top, lines ~283–311)

| Instance | Module | Width | Depth | Writer | Reader | Clock |
|---|---|---|---|---|---|---|
| `DMA_Ch0_instr_fifo` | `src/Memory/FIFO.sv` | 124-bit | 16 | Sequencer `disp_push[0]` | `Dispatch_DMA dma0_rd_en` | 300 MHz |
| `DMA_Ch1_instr_fifo` | `src/Memory/FIFO.sv` | 124-bit | 16 | Sequencer `disp_push[5]` | `Dispatch_DMA dma1_rd_en` | 300 MHz |

- 124-bit word = `{opcode[7:0], dep_flags[3:0], payload[111:0]}`. Unit_id consumed by Sequencer at dispatch; not forwarded.
- Ch0 receives: DMA_LOAD (0x11), DMA_STORE (0x12), UPSAMPLE (0x13), CONCAT (0x14), COEFF_LOAD (0x15), LUT_LOAD (0x31).
- Ch1 receives: WT_LOAD (0x10) only. Sequencer routes by opcode in S_DISPATCH.
- FIFO full → `disp_full[0]` or `disp_full[5]` → Sequencer global stall (v2.1 §14.1).
- dout available 1 cycle after rd_en (registered output in both XPM and custom RTL modes).

### Dep-Token FIFOs (NPU.sv top, lines ~193–251)

`src/Memory/DepFIFO.sv` is **not a data FIFO** — it is a saturating up/down counter (push=+1, pop=-1, saturates at DEPTH). No data stored; only `full`/`empty` status exposed. Single 300 MHz clock.

| Instance | DEPTH | Producer (push) | Consumer (pop) | Phase wired |
|---|---|---|---|---|
| `dep_dma_to_sa` | 8 | DMA on `dma_act_bank_full` | SA_Block before MATMUL | 3 |
| `dep_sa_to_dma` | 8 | SA_Block on tile done | DMA before DMA_LOAD | 3 (wire in Dispatch_DMA) |
| `dep_dma_to_vpu` | 8 | DMA on `store_done_r` | VPU_Block before OutBank write | 5 |
| `dep_vpu_to_dma` | 8 | VPU_Block on unit_done | DMA before DMA_STORE | 5 |

The other 6 DepFIFOs (SA↔PSB, PSB↔REQ, REQ↔VPU) are not touched by DMA.

### How Dispatch_DMA Uses FIFOs (Phase 2 behavior)

Step-by-step for each Ch0 instruction:
1. See `ch0_empty = 0` → assert `ch0_rd_en` for 1 cycle
2. Next cycle: `dma0_dout[123:116]` = opcode; `[111:0]` = payload
3. Decode fetch_mode from opcode; extract descriptor fields (see Phase 2 section)
4. For DMA_LOAD: stall in S_WAIT_DEP until `dep_sa_to_dma_empty = 0`; pop (`dep_sa_to_dma_pop = 1`) on same cycle as `start`
5. Assert `start` 1 cycle; DMA.sv latches descriptor, leaves S_IDLE
6. Dispatch enters S_WAIT_DMA; polls `ch0_idle`; when high → back to step 1

---

## AXI Port Architecture (from old README)

| Port on DMA.sv | Direction | Ch | Purpose |
|---|---|---|---|
| `hp0_*` | Read master | Ch0 | DMA_LOAD, UPSAMPLE, CONCAT, COEFF_LOAD, LUT_LOAD |
| `hp1_*` | Read master | Ch1 | WT_LOAD only |
| `hp2_*` | Write master | Ch0 | DMA_STORE only |

AXI4 constants (applied combinationally): `arsize=3'b100` (16 B/beat), `arburst=INCR`, `arcache=4'b0011`. Same for write master.
44-bit address (K26 SOM DDR4 range). 300 MHz; HP ports enter SmartConnect for CDC.

---

## DMA_STORE Pipeline (1-cycle BRAM latency — from old README)

Output Bank (SimpleBRAM) has 1-cycle registered read latency. Read-ahead pipeline in SS_W state:
- Cycle N: issue `sram_raddr = N` (pre-issue on entry to SS_W before first wvalid)
- Cycle N+1: `sram_rdata` valid → capture into `wdata_reg`; issue `sram_raddr = N+1`
- Cycle N+1: drive `hp2_wdata = wdata_reg`, assert `hp2_wvalid`

Do not drive `hp2_wdata` directly from `sram_rdata` in the same cycle as `sram_raddr` — BRAM output is registered.

---

## COEFF_LOAD DDR4 Packing (from old README)

Each channel stored as 8 bytes in DDR4:
- `[63:32]` = M (INT32 scale factor)
- `[7:0]`   = S (UINT8; only [3:0] used — 4-bit shift)
- `[31:8]`  = pad (ignored)

One 128-bit AXI beat = 2 channel entries. BRAM stores `{M[31:0], S[3:0]}` = 36 bits per entry at `coeff_waddr`. Extract from beat: entry 0 from `[63:0]`; entry 1 from `[127:64]`.

---

## bank_full Timing (from old README)

```systemverilog
dma_act_bank_full <= sram_wen && (waddr_r == r_act_total - 1);
```
`r_act_total` = total 128-bit words written for one tile = `tile_w * tile_h * r_beats`. No multiplier: compute iteratively at start (add `r_beats` once per pixel, loop tile_w × tile_h iterations using existing cur_h/cur_w counters — or latch a precomputed total using an accumulator in S_IDLE on start).

`dma_act_bank_full` pulses exactly 1 cycle. NPU top wires it to both `SRAMHub.dma_act_bank_full` and `dep_dma_to_sa.push`.

---

## Arch Constants — Verify in NPU_HW_params_pkg.sv Before Coding

```systemverilog
ACT_BUF_DEPTH    // depth of Act Bank A/B
WT_BUF_DEPTH     // depth of Weight Bank A/B
RES_BANK_DEPTH   // depth of Residual Bank (sram_waddr width in current DMA.sv)
OUT_BANK_DEPTH   // depth of Output Bank
MAX_CHANNELS     // 512 — max channels for Coeff BRAM
COEFF_M_WIDTH    // M field width
COEFF_S_WIDTH    // S field width
FIFO_USE_XPM     // 1 = xpm_fifo_sync, 0 = custom RTL
SA_ROWS, SA_COLS // 16, 16
```

Width note: current DMA.sv `sram_waddr` is `[$clog2(RES_BANK_DEPTH)-1:0]`. When wiring to Act Bank in Phase 3, verify `ACT_BUF_DEPTH` vs `RES_BANK_DEPTH`. If ACT < RES: truncate (take lower bits). If ACT > RES: zero-extend.

---

## Phase 1 — Port Fix + unit_done + bank_full

Files: `src/NPU/DMA.sv`, `src/NPU/NPU.sv`
No behavior change to Load FSM. Stop after done; wait sign-off.

### DMA.sv changes

1. **Rename hp1 write → hp2**: replace every `hp1_aw`, `hp1_w`, `hp1_b` → `hp2_aw`, `hp2_w`, `hp2_b`.

2. **Add HP1 read ports** (Ch1 WT_LOAD; tie off until Phase 4):
```systemverilog
output logic [43:0]  hp1_araddr,
output logic         hp1_arvalid,
output logic [7:0]   hp1_arlen,
output logic [2:0]   hp1_arsize,
output logic [1:0]   hp1_arburst,
output logic [3:0]   hp1_arcache,
input  logic         hp1_arready,
input  logic [127:0] hp1_rdata,
input  logic         hp1_rvalid,
input  logic         hp1_rlast,
input  logic [1:0]   hp1_rresp,
output logic         hp1_rready
```
Inside: `assign hp1_arvalid = 1'b0; assign hp1_rready = 1'b0;` Add lint suppressor for unused inputs.

3. **Add output ports**:
```systemverilog
output logic dma_act_bank_full,   // 1-cycle pulse after last act write
output logic dma_wt_bank_full,    // tie 1'b0 until Phase 4
output logic ch0_idle,            // = (state == S_IDLE), combinational
output logic ch1_idle             // = 1'b1 until Phase 4
```

4. **Remove `done` and `busy` outputs** (replaced by `ch0_idle` / `ch1_idle`).

5. **Add `dma_act_bank_full` generation** in Load FSM. Latch `r_act_total` on start:
```systemverilog
// In S_IDLE on start: r_act_total = tile_h * tile_w * r_beats
// Iterative: accumulate in a loop state or pre-multiply with adder.
// Simplest: latch = tile_h * tile_w * r_beats computed via:
//   r_act_total <= {tile_h} * ({tile_w} * r_beats) -- allow 1-cycle compute
// Or use a separate counting-state after S_IDLE to accumulate.
r_act_total <= ... // see note below on multiplier avoidance
```
In S_R / S_PAD (any sram_wen=1 cycle):
```systemverilog
dma_act_bank_full <= sram_wen && (waddr_r == r_act_total - 1);
```
Set `dma_act_bank_full <= 1'b0` on reset and at start of new operation.

**Note on r_act_total without multiplier**: Use an accumulator state after S_IDLE:
- `r_act_total <= 0` on start
- New state S_CALC: loop `tile_h` times, adding `tile_w * r_beats` (the inner product is `tile_w * r_beats` which itself can be accumulated: loop `tile_w` times adding `r_beats`). This adds ~2 states and some cycles. Alternative: just use the waddr counter itself — total words = tile_h * tile_w * r_beats. Accept the multiplier latency (1 cycle at 300 MHz is fine for this).

6. **Wire dep ports** (partial — full in Phase 3):
- `assign dep_dma_to_sa_push = dma_act_bank_full;` (remove the `= 1'b0` stub)
- Keep `dep_dma_to_vpu_push = 1'b0`, `dep_sa_to_dma_pop = 1'b0`, `dep_vpu_to_dma_pop = 1'b0` for now.

### NPU.sv changes

1. Add `hp2_*` AXI write master ports to NPU module declaration (44-bit addr, 128-bit data).
2. Update `DMA dma_unit (...)`:
   - Replace hp1 write port connections with hp2 (tie all hp2 inputs to 0 for now: `hp2_awready=1'b0, hp2_wready=1'b0, hp2_bvalid=1'b0, hp2_bresp=2'b0`).
   - Add hp1 read port connections → top-level `wt_*` ports.
   - Remove `.busy()`, `.done()`.
   - Add `.ch0_idle(dma_ch0_idle_w)`, `.ch1_idle(dma_ch1_idle_w)`, `.dma_act_bank_full(dma_act_bank_full_w)`, `.dma_wt_bank_full()`.
3. `assign units_done[UNIT_DMA] = dma_ch0_idle_w & dma_ch1_idle_w;`
4. Remove `units_done[UNIT_DMA] = 1'b1` from the always_comb block.

---

## Phase 2 — Dispatch_DMA Real Decoder

File: `src/NPU/Dispatch/Dispatch_DMA.sv`, minor `src/NPU/NPU.sv` update.
Stop after done; wait sign-off.

### Dispatch_DMA.sv — full rewrite

State machine (Ch0):
```
S_IDLE → S_POP → S_WAIT_DEP → S_START → S_WAIT_DMA → S_IDLE
```
- **S_IDLE**: wait for `~ch0_empty`. On entry: assert `ch0_rd_en = 1`.
- **S_POP**: capture `ch0_dout`; decode opcode; load descriptor shadow regs.
- **S_WAIT_DEP**: for DMA_LOAD: stall until `dep_sa_to_dma_empty = 0`. For DMA_STORE: stall until `dep_vpu_to_dma_empty = 0`. Others: skip wait.
- **S_START**: assert `desc_start = 1` for 1 cycle; pop dep token (`dep_sa_to_dma_pop` or `dep_vpu_to_dma_pop` = 1).
- **S_WAIT_DMA**: wait `dma_ch0_idle = 1` → back to S_IDLE.

Descriptor extraction from `ch0_dout[111:0]`:
```
src_base[31:0]    = payload[31:0]
row_stride[15:0]  = payload[47:32]
tile_w[7:0]       = payload[55:48]
tile_h[7:0]       = payload[63:56]
ch_count[7:0]     = payload[71:64]
pad_top[3:0]      = payload[75:72]
pad_bot[3:0]      = payload[79:76]
pad_left[3:0]     = payload[83:80]
pad_right[3:0]    = payload[87:84]
fetch_mode[1:0]:
  opcode=0x11 DMA_LOAD  → 2'b00
  opcode=0x13 UPSAMPLE  → 2'b01
  opcode=0x14 CONCAT    → 2'b10
  opcode=0x12 DMA_STORE → 2'b11
concat_base[31:0] = {src_base[31:24], payload[111:88]}  // CONCAT only
```

New ports (added to Dispatch_DMA):
```systemverilog
// Descriptor outputs → DMA.sv
output logic [31:0] desc_src_base,
output logic [15:0] desc_row_stride,
output logic [7:0]  desc_tile_w, desc_tile_h, desc_ch_count,
output logic [3:0]  desc_pad_top, desc_pad_bot, desc_pad_left, desc_pad_right,
output logic [1:0]  desc_fetch_mode,
output logic [31:0] desc_concat_base,
output logic        desc_start,
// Feedback from DMA
input  logic        dma_ch0_idle,
// Dep token ports (Ch0)
input  logic        dep_sa_to_dma_empty,
output logic        dep_sa_to_dma_pop,
input  logic        dep_vpu_to_dma_empty,
output logic        dep_vpu_to_dma_pop
```

Ch1 (WT_LOAD): keep `ch1_rd_en = ~ch1_empty` stub until Phase 4. Ch1 descriptor drive added in Phase 4.

### NPU.sv changes

- Update `Dispatch_DMA u_dispatch_dma (...)` instantiation with new ports.
- Wire `desc_*` outputs → `DMA dma_unit (...)` descriptor inputs.
- Remove `.start(1'b0)` from DMA instantiation; wire `.start(desc_start)`.
- Wire `dep_sa_to_dma_empty`, `dep_sa_to_dma_pop`, `dep_vpu_to_dma_empty`, `dep_vpu_to_dma_pop` through Dispatch_DMA.

---

## Phase 3 — NPU.sv Act Bank Wiring + dep_dma_to_sa

File: `src/NPU/NPU.sv` only.
Stop after done; wait sign-off.

### NPU.sv changes

1. Wire SRAMHub Act Bank write:
```systemverilog
.dma_act_waddr     (u_dma.sram_waddr),   // width: $clog2(RES_BANK_DEPTH) — verify vs ACT_BUF_DEPTH
.dma_act_wdata     (u_dma.sram_wdata),
.dma_act_wen       (u_dma.sram_wen),
.dma_act_bank_full (dma_act_bank_full_w),
```

2. `dep_dma_to_sa.push` is already wired via `dma_to_sa_push`. In DMA.sv Phase 1 we set `dep_dma_to_sa_push = dma_act_bank_full`. NPU.sv wiring (already done in Phase 6 of encapsulation): `dep_dma_to_sa_push` net drives `DepFIFO dep_dma_to_sa .push`. Verify that stub `= 1'b0` is removed.

3. `dep_sa_to_dma` consumer side: `sa_to_dma_pop` driven by Dispatch_DMA (Phase 2). NPU.sv wires `dep_sa_to_dma.pop ← sa_to_dma_pop` (from DMA.sv `dep_sa_to_dma_pop` pin, driven by Dispatch_DMA). Verify signal path is fully connected.

---

## Phase 4 — Ch1 WT_LOAD FSM + HP1 + Weight Bank

Files: `src/NPU/DMA.sv`, `src/NPU/Dispatch/Dispatch_DMA.sv`, `src/NPU/NPU.sv`.
Stop after done; wait sign-off.

### DMA.sv changes

Add independent Ch1 FSM. States:
```systemverilog
typedef enum logic [1:0] { SS1_IDLE, SS1_AR, SS1_R, SS1_ADV } ch1_state_e;
```

New input ports:
```systemverilog
input  logic        ch1_start,
input  logic [31:0] wt_src_base,
input  logic [15:0] wt_row_stride,
input  logic [7:0]  wt_tile_w, wt_tile_h, wt_ch_count,
```

New output ports:
```systemverilog
output logic [$clog2(WT_BUF_DEPTH)-1:0] sram_wt_waddr,
output logic [127:0]                     sram_wt_wdata,
output logic                             sram_wt_wen,
output logic                             dma_wt_bank_full,  // was tied 0 in Phase 1
output logic                             ch1_idle           // was 1'b1 in Phase 1
```

WT_LOAD is a linear burst (no 2D padding). Addr gen: `wt_base + (row * row_stride) + col_off`. Or simpler: linear address `wt_base + beat_count * 16` for a fully packed linear tile. Burst length per AXI transaction = `wt_ch_count >> 4` beats per row (ch_count/16 = 128-bit words). Issue one AR per row; advance address by `wt_row_stride` per row.

HP1: same constants: arsize=3'b100, arburst=INCR, arcache=4'b0011.
`ch1_idle = (ch1_state == SS1_IDLE)`.
`dma_wt_bank_full`: 1-cycle pulse after last wt write (same pattern as act_bank_full).

Also: update `hp1_arvalid`/`hp1_rready` logic — remove the Phase 1 tie-offs and drive from Ch1 FSM.

### Dispatch_DMA.sv changes

Add Ch1 state machine alongside Ch0:
```
SS1_IDLE → SS1_POP (ch1_rd_en=1) → SS1_LATCH → SS1_START (ch1_start=1) → SS1_WAIT_DMA (until ch1_idle) → SS1_IDLE
```
Remove `assign ch1_rd_en = ~ch1_empty` stub.
New Dispatch_DMA ports: `ch1_start`, `wt_src_base/row_stride/tile_w/tile_h/ch_count`, `dma_ch1_idle`.

### NPU.sv changes

- Wire HP1 read: `hp1_ar* → wt_*` top ports (remove tie-offs).
- Wire SRAMHub wt bank: `.dma_wt_waddr(u_dma.sram_wt_waddr)`, `.dma_wt_wdata(...)`, `.dma_wt_wen(...)`, `.dma_wt_bank_full(u_dma.dma_wt_bank_full)`.
- Update Dispatch_DMA instantiation with Ch1 ports.

---

## Phase 5 — DMA_STORE Fix (HP2, Row Loop, BRAM Pipeline)

Files: `src/NPU/DMA.sv`, `src/NPU/NPU.sv`.
Stop after done; wait sign-off.

### DMA.sv — Store FSM rewrite

New store state machine:
```
SS_IDLE → SS_CALC_BEATS → SS_AW → SS_W → SS_B → (if more rows: SS_AW; else pulse store_done_r → SS_IDLE)
```

Key changes vs current stub:
1. **Row loop**: add `store_cur_h[7:0]` counter. After `SS_B`: if `store_cur_h < r_tile_h - 1`, `store_cur_h++`, `store_aw_addr += {28'h0, r_stride}`, go to `SS_AW`. Else `store_done_r = 1`, go to `SS_IDLE`.
2. **Beats per row** (no multiplier): `r_tile_w * r_beats`. Use SS_CALC_BEATS to accumulate: add `r_beats` into `beats_this_row` for `r_tile_w` iterations.
3. **BRAM read pipeline** (see DMA_STORE Pipeline section above):
   - On `SS_AW → SS_W` transition: issue `sram_raddr = store_raddr_r` (pre-fetch).
   - In `SS_W`: when `hp2_wready`:
     - Capture `sram_rdata` into `wdata_reg`.
     - Drive `hp2_wdata = wdata_reg`.
     - Issue `sram_raddr = store_raddr_r + 1`.
     - Increment `store_raddr_r`.
     - Decrement `store_beat_cnt`; set `hp2_wlast = (store_beat_cnt == 8'h1)`.
4. **HP2 AXI write**: `hp2_awsize=3'b100`, `hp2_awburst=INCR`, `hp2_awcache=4'b0011`, `hp2_wstrb=16'hFFFF`.
5. **Dep tokens**: `assign dep_dma_to_vpu_push = store_done_r;` (remove `= 1'b0` stub).
6. **dep_vpu_to_dma_pop**: pop from DMA.sv (`dep_vpu_to_dma_pop = 1`) on same cycle as `ch1_start` in Dispatch_DMA S_START for DMA_STORE. Wire from Dispatch_DMA (Phase 2 added the port stubs).

### NPU.sv changes

- Add HP2 write master ports to NPU module declaration (match DMA.sv hp2_* names).
- Wire `DMA dma_unit` hp2 ports → NPU top HP2 ports.
- Wire SRAMHub output bank read: `.dma_out_raddr(u_dma.sram_raddr)`, `u_dma.sram_rdata ← dma_out_rdata`.
- `assign irq_done = dma_store_done_w;` (expose `store_done_r` via a logic wire from DMA.sv — add as output port or use hierarchical reference).
- Wire `dep_dma_to_vpu_push` (already connected to DepFIFO; remove `= 1'b0` stub from DMA.sv).
- Wire `dep_vpu_to_dma_pop` (from Dispatch_DMA through DMA.sv dep pin → DepFIFO.pop).

---

## Phase 6 — COEFF_LOAD + LUT_LOAD

Files: `src/NPU/DMA.sv`, `src/NPU/Dispatch/Dispatch_DMA.sv`, `src/NPU/NPU.sv`, `src/packages/NPU_ISA_pkg.sv`.
Stop after done; wait sign-off.

### DMA.sv changes

Extend with two new Ch0 FSMs (or extend the existing load FSM with new modes via `fetch_mode` field extension from 2-bit to 3-bit):

**COEFF_LOAD** (new fetch_mode = 3'b100 or handle via separate opcode decode in Dispatch_DMA → set a `coeff_mode` flag):
- New descriptor fields: `coeff_src_base[31:0]`, `coeff_ch_count[8:0]` (up to 512 channels).
- HP0 burst; `arlen = coeff_ch_count/2 - 1` (each beat = 2 entries).
- On each beat `[127:0]`:
  - Entry 0: `M0 = rdata[63:32]`, `S0 = rdata[3:0]` → `coeff_wdata = {M0, S0}` at `coeff_waddr`
  - Entry 1: `M1 = rdata[127:96]`, `S1 = rdata[67:64]` → `coeff_wdata = {M1, S1}` at `coeff_waddr + 1`
- New output ports: `sram_coeff_waddr[$clog2(MAX_CHANNELS)-1:0]`, `sram_coeff_wdata[35:0]`, `sram_coeff_wen`.

**LUT_LOAD** (fetch_mode = 3'b101):
- New descriptor field: `lut_src_base[31:0]`, `lut_sel` (ping-pong bank select; toggles each LUT_LOAD).
- HP0 burst; `arlen = 15` (16 beats × 16 bytes = 256 entries).
- Each beat: 16 LUT entries (bytes [127:0]). Write sequentially to LUT BRAM byte by byte (or 16 at a time if BRAM port allows).
- New output ports: `sram_lut_waddr[7:0]`, `sram_lut_wdata[7:0]`, `sram_lut_wen`, `sram_lut_sel`.

### ISA pkg changes

```systemverilog
// Fix OP_LUT_LOAD unit_id
localparam logic [3:0] OP_LUT_LOAD_UNIT = UNIT_DMA;  // was UNIT_VPU

// Add npu_concat_payload_t
typedef struct packed {
    logic [23:0] base_addr_b_lo;   // [111:88] = base_addr_b[23:0]
    logic [87:0] dma_load_fields;  // [87:0] same as npu_dma_load_payload_t
} npu_concat_payload_t;
```

### Dispatch_DMA.sv changes

- Decode COEFF_LOAD opcode → extract `coeff_src_base`, `coeff_ch_count`; drive DMA with fetch_mode=3'b100 (or dedicated flag).
- Decode LUT_LOAD opcode → extract `lut_src_base`; drive DMA with fetch_mode=3'b101.

### NPU.sv changes

- Wire SRAMHub Coeff BRAM write: `.dma_coeff_waddr(...)`, `.dma_coeff_wdata(...)`, `.dma_coeff_wen(...)`. Note: SRAMHub `dma_coeff_wdata` width = `COEFF_M_WIDTH + COEFF_S_WIDTH`. Verify against DMA.sv 36-bit output.
- Wire SRAMHub LUT write: `.dma_lut_waddr(...)`, `.dma_lut_wdata(...)`, `.dma_lut_wen(...)`, `.dma_lut_sel(...)`.

---

## Phase 7 — UPSAMPLE + CONCAT

File: `src/NPU/DMA.sv`, `src/NPU/Dispatch/Dispatch_DMA.sv`.
Stop after done; wait sign-off.

### DMA.sv — UPSAMPLE (fetch_mode 2'b01)

Extend Load FSM. Add `repeat_w[0]` and `repeat_h[0]` counters:
- In `S_ADV` when `fetch_mode == UPSAMPLE`:
  - Before advancing `cur_w`: if `repeat_w == 0` → `repeat_w = 1`; keep `col_off` unchanged; go to `S_PIXEL` (re-issue same pixel's AXI burst).
  - Else: `repeat_w = 0`; advance `cur_w` normally.
  - Before advancing `cur_h` (when `cur_w` wraps): if `repeat_h == 0` → `repeat_h = 1`; reset `cur_w = 0`; keep `row_base` unchanged; go to `S_PIXEL`.
  - Else: `repeat_h = 0`; advance `cur_h` and `row_base` normally.
- Net effect: each source pixel emitted 2× in W direction, each row emitted 2× in H direction → 2× nearest-neighbor upsampling.

### DMA.sv — CONCAT (fetch_mode 2'b10)

Extend Load FSM. Each pixel requires two AXI bursts: first `r_beats/2` 128-bit words from `r_base`, then `r_beats/2` from `r_concat_base`:
- Add `concat_phase` flag (0 = first half, 1 = second half).
- In `S_PIXEL`: set AXI base to `r_base` if `concat_phase=0`, else `r_concat_base`. Set `beat_cnt = r_beats/2 - 1`.
- After first half done (S_ADV with `concat_phase=0`): set `concat_phase=1`; go back to `S_AR` (same `cur_h/cur_w`, different base).
- After second half: `concat_phase=0`; advance `cur_w` normally.

Requires `npu_concat_payload_t` decode in Dispatch_DMA to extract `r_concat_base` from payload[111:88].

---

## Dep Token Wiring Table (Complete)

| DepFIFO instance (NPU.sv) | `.push` source | `.pop` source | Status |
|---|---|---|---|
| `dep_dma_to_sa` | `u_dma.dep_dma_to_sa_push` = `dma_act_bank_full` | `u_sa_block.dep_dma_to_sa_pop` (existing) | Wired Phase 3 |
| `dep_sa_to_dma` | `u_sa_block.dep_sa_to_dma_push` (existing) | `u_dispatch_dma.dep_sa_to_dma_pop` → `u_dma.dep_sa_to_dma_pop` | Wired Phase 3 |
| `dep_dma_to_vpu` | `u_dma.dep_dma_to_vpu_push` = `store_done_r` | `u_vpu_block.dep_dma_to_vpu_pop` (existing) | Wired Phase 5 |
| `dep_vpu_to_dma` | `u_vpu_block.dep_vpu_to_dma_push` (existing) | `u_dispatch_dma.dep_vpu_to_dma_pop` → `u_dma.dep_vpu_to_dma_pop` | Wired Phase 5 |

All other DepFIFOs (SA↔PSB, PSB↔REQ, REQ↔VPU) are already fully wired between their block wrappers; DMA does not touch them.

---

## File Map (cumulative)

| File | Phase | Changes |
|---|---|---|
| `NPU_DMA_PLAN.md` (this file) | 0 | Created |
| `src/NPU/README.md` | 0 | **Deleted** |
| `src/NPU/DMA.sv` | 1 | hp1→hp2, hp1 read stub, bank_full, ch0_idle, dep wires |
| `src/NPU/NPU.sv` | 1 | hp2 ports, unit_done wiring |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | 2 | Full FSM rewrite, descriptor decode |
| `src/NPU/NPU.sv` | 2 | Dispatch_DMA instantiation update |
| `src/NPU/NPU.sv` | 3 | Act Bank SRAM wiring, dep_dma_to_sa wiring |
| `src/NPU/DMA.sv` | 4 | Ch1 FSM, hp1 drive, dma_wt_bank_full, ch1_idle |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | 4 | Ch1 state machine |
| `src/NPU/NPU.sv` | 4 | HP1 wt port activation, SRAMHub wt wiring |
| `src/NPU/DMA.sv` | 5 | Store FSM rewrite, HP2 drive, dep_dma_to_vpu |
| `src/NPU/NPU.sv` | 5 | HP2 ports, SRAMHub out bank read, irq_done, dep wiring |
| `src/NPU/DMA.sv` | 6 | COEFF_LOAD FSM, LUT_LOAD FSM, fetch_mode extension |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | 6 | COEFF_LOAD + LUT_LOAD decode |
| `src/NPU/NPU.sv` | 6 | Coeff + LUT BRAM wiring |
| `src/packages/NPU_ISA_pkg.sv` | 6 | OP_LUT_LOAD fix, npu_concat_payload_t |
| `src/NPU/DMA.sv` | 7 | UPSAMPLE + CONCAT in Load FSM |
| `src/NPU/Dispatch/Dispatch_DMA.sv` | 7 | CONCAT payload decode |

---

## SV Style Rules (from .verible-lint-rules)

- Spaces only, no tabs
- 100-col line max
- POSIX EOF newline
- `always_ff` / `always_comb` only — no bare `always @(...)`
- Synchronous active-high reset (`rst`)
- `import NPU_ISA_pkg::*; import NPU_HW_params_pkg::*;` at file top
- IEEE 1800-2017
