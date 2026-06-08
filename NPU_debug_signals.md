# NPU Debug Signal Reference

Signals to watch in GTKWave (or cocotb `dut.*` polling) when triaging a run of [test_single_layer.py](../tb/CocoTB/NPU/test_single_layer.py). Top-level RTL: [src/NPU/NPU.sv](../src/NPU/NPU.sv).

Cocotb runner already passes `--public` ([test_single_layer_interface.py:23](../tb/CocoTB/NPU/test_single_layer_interface.py#L23)), so every internal net listed below is visible in the `dump.fst` and reachable via `dut.<instance>.<signal>`.

---

## 1. Host kick / CSR — did the run even start?

| Signal | Location | Meaning |
|---|---|---|
| `s_axil_awaddr`, `s_axil_awvalid`, `s_axil_awready` | [NPU.sv:89-91](../src/NPU/NPU.sv#L89-L91) | AXI-Lite AW (CSR reg select) |
| `s_axil_wdata`, `s_axil_wvalid`, `s_axil_wready` | [NPU.sv:92-94](../src/NPU/NPU.sv#L92-L94) | AXI-Lite W (CSR value) |
| `s_axil_bvalid`, `s_axil_bready` | [NPU.sv:96-97](../src/NPU/NPU.sv#L96-L97) | CSR write complete |
| `sequence_unit.job_active` | [Sequencer.sv:238](../src/NPU/Sequencer.sv#L238) | high after kick until last instr dispatched |

Expected CSR sequence per test: write `0x0` (instr_base) → `0x4` (count) → `0x8=1` (kick).

---

## 2. Instruction fetch — Sequencer reading DDR

| Signal | Location | Meaning |
|---|---|---|
| `seq_araddr`, `seq_arvalid`, `seq_arready` | [NPU.sv:103-108](../src/NPU/NPU.sv#L103-L108) | AR: where in DDR |
| `seq_rdata`, `seq_rvalid`, `seq_rlast`, `seq_rresp` | [NPU.sv:109-112](../src/NPU/NPU.sv#L109-L112) | 32-b instr beats (4 = 128-b instr) |
| `sequence_unit.state` | [Sequencer.sv:233](../src/NPU/Sequencer.sv#L233) | S_IDLE / S_AR / S_R / S_DISPATCH / S_FENCE |
| `sequence_unit.instr_buf` | Sequencer.sv | assembled 128-b instr |
| `sequence_unit.beat_cnt` | Sequencer.sv | which 32-b beat (0–3) |
| `sequence_unit.fetch_ptr`, `sequence_unit.fetch_remaining` | Sequencer.sv | DDR cursor / instrs left |
| `fetch_err` | [NPU.sv:173](../src/NPU/NPU.sv#L173) | sticky Seq AXI error |

---

## 3. Dispatch fanout — Sequencer → per-unit FIFOs (THE instruction-flow signals)

| Signal | Location | Meaning |
|---|---|---|
| `disp_payload[123:0]` | [NPU.sv:184](../src/NPU/NPU.sv#L184) | `{opcode[7:0], dep_flags[3:0], payload[111:0]}` — the actual decoded instruction |
| `disp_push[5:0]` | [NPU.sv:185](../src/NPU/NPU.sv#L185) | which unit got the instr |
| `disp_full[5:0]` | [NPU.sv:186](../src/NPU/NPU.sv#L186) | unit FIFO full → fetch stall |
| `sequence_unit.dec_opcode`, `sequence_unit.dec_unit` | Sequencer.sv | what the decoder thinks it's issuing |
| `sequence_unit.fence_mask` | Sequencer.sv | which units a FENCE is waiting on |

`disp_push` bit map:

| Bit | Unit |
|---|---|
| 0 | DMA Ch0 (LOAD / STORE / UPSAMPLE / CONCAT / COEFF_LOAD) |
| 1 | SA |
| 2 | PSB |
| 3 | Requant |
| 4 | VPU |
| 5 | DMA Ch1 (WT_LOAD) |

---

## 4. CSR shadow — did OP_CONFIG take?

| Signal | Location |
|---|---|
| `cfg_tile_M`, `cfg_tile_N`, `cfg_tile_K` | [NPU.sv:194-196](../src/NPU/NPU.sv#L194-L196) |
| `cfg_stride`, `cfg_pad_mode` | [NPU.sv:197-198](../src/NPU/NPU.sv#L197-L198) |
| `cfg_coeff_base` | [NPU.sv:199](../src/NPU/NPU.sv#L199) |
| `cfg_act_type`, `cfg_pool_size` | [NPU.sv:200-201](../src/NPU/NPU.sv#L200-L201) |

---

## 5. FENCE / completion

| Signal | Location | Meaning |
|---|---|---|
| `units_done[5:0]` | [NPU.sv:190](../src/NPU/NPU.sv#L190) | bit map: 0=SEQ 1=DMA 2=SA 3=PSB 4=REQ 5=VPU |
| `sa_done_pulse`, `psb_done_pulse`, `req_done_pulse`, `vpu_done_pulse` | [NPU.sv:191](../src/NPU/NPU.sv#L191) | per-unit done strobes |
| `dma_ch0_idle_w`, `dma_ch1_idle_w` | [NPU.sv:206](../src/NPU/NPU.sv#L206) | DMA idle flags (combine → `units_done[1]`) |

---

## 6. Dep-FIFO ordering — deadlock triage

A unit blocked because its input dep-FIFO is `empty` ⇒ upstream never pushed; one stuck `full` ⇒ downstream not popping.

| Edge | Empty / Full | NPU.sv |
|---|---|---|
| DMA → SA | `dma_to_sa_empty`, `dma_to_sa_full` | [279](../src/NPU/NPU.sv#L279) |
| SA → DMA | `sa_to_dma_empty`, `sa_to_dma_full` | [280](../src/NPU/NPU.sv#L280) |
| SA → PSB | `sa_to_psb_empty`, `sa_to_psb_full` | [282](../src/NPU/NPU.sv#L282) |
| PSB → SA | `psb_to_sa_empty`, `psb_to_sa_full` | [283](../src/NPU/NPU.sv#L283) |
| PSB → REQ | `psb_to_req_empty`, `psb_to_req_full` | [285](../src/NPU/NPU.sv#L285) |
| REQ → PSB | `req_to_psb_empty`, `req_to_psb_full` | [286](../src/NPU/NPU.sv#L286) |
| REQ → VPU | `req_to_vpu_empty`, `req_to_vpu_full` | [288](../src/NPU/NPU.sv#L288) |
| VPU → REQ | `vpu_to_req_empty`, `vpu_to_req_full` | [289](../src/NPU/NPU.sv#L289) |
| VPU → DMA | `vpu_to_dma_empty`, `vpu_to_dma_full` | [291](../src/NPU/NPU.sv#L291) |
| DMA → VPU | `dma_to_vpu_empty`, `dma_to_vpu_full` | [292](../src/NPU/NPU.sv#L292) |

---

## 7. DMA datapath

### Ch0 (HP0_DMA — DMA_LOAD activations)
`dma_araddr`, `dma_arvalid`, `dma_arready`, `dma_rdata`, `dma_rvalid`, `dma_rlast` ([NPU.sv:119-130](../src/NPU/NPU.sv#L119-L130))

### Ch1 (HP1_DMA — WT_LOAD weights)
`wt_araddr`, `wt_arvalid`, `wt_arready`, `wt_rdata`, `wt_rvalid`, `wt_rlast` ([NPU.sv:136-147](../src/NPU/NPU.sv#L136-L147))

### Ch2/STORE (HP2_DMA — DMA_STORE flush)
`st_awaddr`, `st_awvalid`, `st_wdata`, `st_wvalid`, `st_wlast`, `st_bvalid` ([NPU.sv:153-167](../src/NPU/NPU.sv#L153-L167))

### Descriptor / FSM control
| Signal | Location | Meaning |
|---|---|---|
| `desc_start_w` | [NPU.sv:380](../src/NPU/NPU.sv#L380) | 1-cycle pulse: Ch0 descriptor latched, launch DMA |
| `desc_fetch_mode_w` | [NPU.sv:376](../src/NPU/NPU.sv#L376) | 000=LOAD 001=UP 010=CONCAT 011=STORE 100=COEFF 101=LUT |
| `ch1_start_w` | [NPU.sv:398](../src/NPU/NPU.sv#L398) | 1-cycle pulse: Ch1 WT_LOAD launch |
| `dma_act_bank_full_w` | [NPU.sv:508](../src/NPU/NPU.sv#L508) | Act ping-pong handoff to SA |
| `dma_wt_bank_full_w` | [NPU.sv:509](../src/NPU/NPU.sv#L509) | Wt ping-pong handoff to SA |
| `dma_store_done_w` | [NPU.sv:510](../src/NPU/NPU.sv#L510) | **drives `irq_done`** |
| `dma_err` | [NPU.sv:174](../src/NPU/NPU.sv#L174) | sticky DMA AXI error |

---

## 8. SRAM Hub — did data actually land in the banks?

| Signal | Location | Meaning |
|---|---|---|
| `dma_sram_wen_w`, `dma_sram_waddr_w`, `dma_sram_wdata_w` | [NPU.sv:393-395](../src/NPU/NPU.sv#L393-L395) | Act-bank write |
| `dma_sram_wt_wen_w`, `dma_sram_wt_waddr_w`, `dma_sram_wt_wdata_w` | [NPU.sv:400-402](../src/NPU/NPU.sv#L400-L402) | Wt-bank write |
| `dma_coeff_wen_w`, `dma_coeff_waddr_w` | [NPU.sv:385-387](../src/NPU/NPU.sv#L385-L387) | Requant coeff BRAM write |
| `dma_lut_wen_w`, `dma_lut_waddr_w`, `dma_lut_sel_w` | [NPU.sv:388-389](../src/NPU/NPU.sv#L388-L389) | VPU LUT bank write |
| `out_wen_mux_w`, `out_waddr_mux_w`, `out_wdata_mux_w` | [NPU.sv:636-640](../src/NPU/NPU.sv#L636-L640) | Output-bank writer (Requant **or** VPU) |
| `sa_act_bank_read_w` | [NPU.sv:604](../src/NPU/NPU.sv#L604) | SA released Act bank → DMA can refill |
| `sa_wt_bank_read_w` | [NPU.sv:605](../src/NPU/NPU.sv#L605) | SA released Wt bank → DMA Ch1 can refill |
| `dma_sram_raddr_w`, `dma_sram_rdata_w` | [NPU.sv:405-406](../src/NPU/NPU.sv#L405-L406) | Output-bank read during STORE |

---

## 9. Compute pipe outputs — verify MACs ran

| Signal | Location | Meaning |
|---|---|---|
| `sa_row_out_w[SA_COLS-1:0]`, `sa_row_valid_w` | [NPU.sv:709-710](../src/NPU/NPU.sv#L709-L710) | SA partial-sum row |
| `requant_row_out_w` | [NPU.sv:750](../src/NPU/NPU.sv#L750) | PSB accumulated row → Requant |
| `psb_row_index_w`, `psb_row_out_valid_w` | [NPU.sv:751-752](../src/NPU/NPU.sv#L751-L752) | PSB row index + valid |
| `req_vpu_out_waddr_w`, `req_vpu_out_wdata_w`, `req_vpu_out_wen_w` | [NPU.sv:612-614](../src/NPU/NPU.sv#L612-L614) | Requant → Output bank |
| `vpu_vpu_out_waddr_w`, `vpu_vpu_out_wdata_w`, `vpu_vpu_out_wen_w` | [NPU.sv:622-624](../src/NPU/NPU.sv#L622-L624) | VPU → Output bank |
| `vpu_hred_raddr_w`, `vpu_hred_rdata_w` | [NPU.sv:617-618](../src/NPU/NPU.sv#L617-L618) | VPU HREDUCE source |
| `vpu_res_raddr_w`, `vpu_res_rdata_w` | [NPU.sv:619-620](../src/NPU/NPU.sv#L619-L620) | VPU residual read |
| `vpu_lut_sel_w`, `vpu_lut_raddr_w`, `vpu_lut_rdata_w` | [NPU.sv:625-627](../src/NPU/NPU.sv#L625-L627) | VPU SIMD_ACT LUT |

---

## 10. End-of-test

| Signal | Location | Meaning |
|---|---|---|
| `irq_done` | [NPU.sv:172](../src/NPU/NPU.sv#L172) | = `dma_store_done_w`. Test polls this ([test_single_layer.py:61](../tb/CocoTB/NPU/test_single_layer.py#L61)) |
| `fetch_err` | [NPU.sv:173](../src/NPU/NPU.sv#L173) | must be 0 post-run |
| `dma_err` | [NPU.sv:174](../src/NPU/NPU.sv#L174) | must be 0 post-run |

---

## 11. Minimal triage set (tight wave window)

Put these first; drill into per-unit internals only when one stalls.

```
clk, rst
s_axil_awvalid, s_axil_wdata, s_axil_bvalid
seq_arvalid, seq_rvalid, seq_rlast
disp_payload, disp_push[5:0], disp_full[5:0]
units_done[5:0]
dma_arvalid, wt_arvalid, st_wvalid, st_bvalid
dma_store_done_w
irq_done, fetch_err, dma_err
```

---

## 12. GTKWave / cocotb access notes

- Runner: `verilator` + `--public` + `waves=True` ⇒ `--trace-fst --trace-structs`. All internal nets are visible.
- Dump file: `sim_build/NPU_build/dump.fst` (or `.vcd` depending on cocotb_test version).
- Hierarchical access from Python: `dut.sequence_unit.state.value`, `dut.dma_unit.<signal>.value`, etc.
- Dispatch instance names match NPU.sv: `sequence_unit`, `dma_unit`, `u_dispatch_dma`, `u_sa_block`, `u_psb_block`, `u_requant_block`, `u_vpu_block`, `SRAM_hub`.
