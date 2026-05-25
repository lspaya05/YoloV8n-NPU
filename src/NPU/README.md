# DMA Engine — `src/NPU/DMA.sv`

## Architecture

Dual-channel DMA engine. Ch0 handles all activation/data movement; Ch1 handles weight prefetch concurrently.

| Channel | Opcodes | AXI Port | Direction |
|---------|---------|----------|-----------|
| Ch0 | DMA_LOAD, DMA_STORE, UPSAMPLE, CONCAT, COEFF_LOAD, LUT_LOAD | HP0 (read), HP2 (write) | DDR4 ↔ Act/Residual/Output/Coeff/LUT banks |
| Ch1 | WT_LOAD | HP1 (read) | DDR4 → Weight bank |

**AXI4**: 128-bit data width (`arsize=3'b100`), 44-bit address. `arcache=4'b0011`, INCR burst.

**Clocks**: 300 MHz fabric throughout. HP port CDC via SmartConnect.

**unit_done[1]**: combinational level — `ch0_idle & ch1_idle`. Used by Sequencer FENCE.

---

## Instruction FIFOs

Two Xilinx FIFO Generator IPs, each 116-bit × 16-deep, FWFT mode, `prog_full` threshold=14.

- **Ch0 FIFO**: receives all DMA ops except WT_LOAD. `prog_full → fifo_full[0]` → Sequencer backpressure.
- **Ch1 FIFO**: receives WT_LOAD only. `prog_full → fifo_full[5]` → Sequencer backpressure.

Sequencer routes by opcode in `S_DISPATCH`: `OP_WT_LOAD` → FIFO 5; other `UNIT_DMA` → FIFO 0.

---

## Opcodes Handled

| Opcode | Value | Ch | SRAM Target | Source |
|--------|-------|----|-------------|--------|
| OP_WT_LOAD    | 0x10 | 1 | Weight Bank (inactive) | DDR4 linear burst |
| OP_DMA_LOAD   | 0x11 | 0 | Act Bank (inactive)    | DDR4 2D-strided + zero-pad |
| OP_DMA_STORE  | 0x12 | 0 | DDR4                   | Output Bank sequential read |
| OP_UPSAMPLE   | 0x13 | 0 | Act Bank (inactive)    | DDR4 2D, 2× nearest-neighbor |
| OP_CONCAT     | 0x14 | 0 | Act Bank (inactive)    | DDR4 dual-addr interleave |
| OP_COEFF_LOAD | 0x15 | 0 | Coeff BRAM             | DDR4 burst, 2 entries/beat |
| OP_LUT_LOAD   | 0x31 | 0 | Act/HREDUCE LUT BRAM   | DDR4 burst, 16 entries/beat |

Note: `OP_LUT_LOAD` unit_id is `UNIT_DMA` (fixed from original `UNIT_VPU` in ISA pkg).

---

## 2D Address Generator (DMA_LOAD / UPSAMPLE / CONCAT)

```
addr = base_addr + h*row_stride + w*ch_count + c
```

No multiplier — iterative adder:
- `row_base` updated once per row: `row_base += row_stride`
- `col_offset` updated once per pixel: `col_offset += ch_count`
- Phase 1 constraint: `ch_count` must be multiple of 16 (one 128-bit word per pixel column)

---

## Zero-Padding Logic (DMA_LOAD)

```systemverilog
is_pad_row = (cur_h < pad_top) || (cur_h >= tile_h - pad_bot)
is_pad_col = (cur_w < pad_left) || (cur_w >= tile_w - pad_right)
is_pad     = is_pad_row | is_pad_col
```

When `is_pad`: skip HP0 AXI read; write `128'h0` to Act bank. `waddr` increments normally.

---

## Ping-Pong Completion

DMA drives `dma_act_bank_full` / `dma_wt_bank_full`. Each pulses **1 cycle** after the last write to the inactive bank. DMA does not wait for PingPongBuffer swap before asserting `unit_done`.

```systemverilog
dma_act_bank_full <= dma_act_wen && (act_waddr == act_total_words - 1);
```

---

## COEFF_LOAD DDR4 Packing

Each channel stored as 8 bytes in DDR4: `[63:32]=M (INT32)`, `[7:0]=S (UINT8, 4b used)`, `[31:8]=pad`.
One 128-bit AXI beat = 2 channel entries. BRAM stores `{M[31:0], S[3:0]}` = 36 bits per entry.

---

## CONCAT Second Address Encoding (`npu_concat_payload_t`)

Uses the 24 reserved bits `[111:88]` of the payload for `base_addr_b[23:0]`.
`base_addr_b[31:24] = base_addr_a[31:24]` (both tensors always in the same 256 MB DDR4 region — guaranteed by memory map `0x2040_0000–0x2062_FFFF`).

---

## DMA_STORE Pipeline

Output Bank (SimpleBRAM) has 1-cycle registered read latency. Read-ahead pipeline:
- Cycle N: issue `dma_out_raddr=N`
- Cycle N+1: capture `dma_out_rdata` → `wdata_reg`; issue `dma_out_raddr=N+1`
- Cycle N+1: drive `hp2_wdata = wdata_reg`, assert `hp2_wvalid`

---

## ISA Package Changes Required

1. Fix `OP_LUT_LOAD` unit_id from `UNIT_VPU` → `UNIT_DMA` in `NPU_ISA_pkg.sv`
2. Add `npu_concat_payload_t` to `NPU_ISA_pkg.sv` (see CONCAT section above)

---

## Sequencer Changes Required

Extend `fifo_push` / `fifo_full` from 5-bit to 6-bit:
- `[5]` = DMA Ch1 (WT_LOAD)
- In `S_DISPATCH`: `OP_WT_LOAD` → `fifo_push[5]`; other `UNIT_DMA` → `fifo_push[0]`

---

## Implementation Phases

| Phase | Scope | Key Deliverable |
|-------|-------|-----------------|
| 1 | Ch0: DMA_LOAD + HP0 read | 2D addr gen, zero-pad, Act bank write, `bank_full`, `unit_done` |
| 2 | Ch1: WT_LOAD + HP1 read | Concurrent weight prefetch, Sequencer FIFO extension |
| 3 | Ch0: COEFF_LOAD + LUT_LOAD | Coeff BRAM write, LUT BRAM write, ISA pkg fix |
| 4 | Ch0: DMA_STORE + HP2 write | Output Bank read pipeline, AXI write master |
| 5 | Ch0: UPSAMPLE + CONCAT | FPN ops, `npu_concat_payload_t` |
| 6 | Integration | NPU_TopLevel wiring, full-layer TB |

---

## Verification Checklist

- [ ] Zero-pad positions = `128'h0` in Act bank
- [ ] `dma_act_bank_full` pulses exactly 1 cycle after last act write
- [ ] `dma_wt_bank_full` pulses exactly 1 cycle after last wt write
- [ ] `unit_done` level: low while any channel active, high only when both idle
- [ ] Ch1 WT_LOAD concurrent with Ch0 DMA_LOAD; both `bank_full` fire independently
- [ ] COEFF BRAM: `{M[31:0], S[3:0]}` at correct `coeff_waddr`
- [ ] LUT BRAM: 256 entries; `dma_lut_sel` selects correct bank
- [ ] DMA_STORE: AXI W data order correct; `wlast` on final beat; B-handshake completes
- [ ] UPSAMPLE: 2×2 → 4×4 output; each source pixel at all 4 output positions
- [ ] CONCAT: first `ch_count/2` from addr_a, second half from addr_b at each pixel
- [ ] 16 consecutive DMA_LOAD saturate Ch0 FIFO; `ch0_fifo_full` stalls Sequencer
