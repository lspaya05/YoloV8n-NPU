# Kria KR260 Custom INT8 NPU — Project Reference

## Project Overview

A hand-written Verilog RTL INT8 NPU targeting YOLOv8n inference on a Xilinx Kria KR260 FPGA.
The ARM Cortex-A53 PS runs Ubuntu/PyTorch. The PL runs the custom accelerator.
No HLS or Vitis AI is used.

---

## Directory Structure

```
kria_npu/
├── rtl/                          ← all hand-written Verilog/SystemVerilog
│   ├── npu_top.sv                ← top-level module
│   ├── csr_regbank.sv            ← AXI-Lite CSR register bank
│   ├── sequencer.sv              ← microcoded VTA-style sequencer
│   ├── systolic_array.sv         ← 16×16 INT8 weight-stationary systolic array
│   ├── vpu.sv                    ← 64-lane SIMD vector processing unit
│   ├── psb.sv                    ← Partial Sum Accumulation Buffer
│   ├── ping_pong_hub.sv          ← dual-bank SRAM hub for weights/activations
│   ├── skew_fifos.sv             ← activation lane alignment (wraps FIFO Generator .xci)
│   └── dma_controller.sv         ← controls ping-pong banks, signals sequencer on load done
│
├── ip/                           ← Vivado-generated .xci files (outside project scope)
│   ├── fifo_skew/
│   ├── fifo_cmd/
│   └── (clocking_wizard, proc_reset, cdma if generated standalone)
│
└── vivado_proj/                  ← .xpr project lives here
    └── bd/                       ← Block Design lives here
        └── bd_npu_ps.bd
```

---

## IP Blocks — Where They Live and Key Settings

### Block Design Only (IP Integrator — cannot be instantiated in RTL)

These must live inside a Block Design (`bd_npu_ps.bd`). Export as HDL wrapper to get a plain Verilog module.

#### 1. Zynq UltraScale+ MPSoC
The PS itself. Only exists in Block Design.

| Setting | Value |
|---|---|
| Board Preset | Apply KR260 preset first |
| S_AXI_HP0_FPD | Enabled, 128-bit |
| S_AXI_HP1_FPD | Enabled, 128-bit |
| M_AXI_HPM0_FPD | Enabled (CPU → CSR control path) |
| PL Fabric Clock PL0 | Enabled, 100 MHz requested (~96.969 MHz actual) |
| PL to PS Interrupt | IRQ0[0:0] enabled |

#### 2. AXI SmartConnect
Routes AXI transactions between all masters and slaves. Cannot be used outside Block Design.

| Setting | Value |
|---|---|
| Number of Slave Interfaces | 2 (HPM0_FPD from CPU, CDMA control) |
| Number of Master Interfaces | 3 (HP0_FPD, HP1_FPD, NPU CSR AXI-Lite) |

#### 3. AXI CDMA (Central DMA)
Moves weights and activations between DDR and ping-pong SRAM. Programmed by Linux driver.

| Setting | Value |
|---|---|
| Enable Scatter Gather | Unchecked |
| Data Width | 128-bit |
| Address Width | 64-bit |
| Max Burst Length | 256 |
| Allow Unaligned Transfers | Unchecked |

#### 4. Clocking Wizard
Generates stable 200 MHz PL clock from PS PL0 output.

| Setting | Value |
|---|---|
| Input Clock Frequency | 96.969 MHz (match PL0 actual frequency) |
| Input Clock Source | Single ended clock capable pin |
| Output clk_out1 | 200 MHz |
| Reset Type | Active Low |
| Enable Locked Output | Checked — wire to Processor System Reset |

#### 5. Processor System Reset
Synchronises PL reset to PS clock domain. Prevents metastability at startup.

| Setting | Value |
|---|---|
| All settings | Leave at defaults |

Connections:
- `slowest_sync_clk` → 200 MHz from Clocking Wizard
- `dcm_locked` → `locked` from Clocking Wizard
- `ext_reset_in` → `pl_resetn0` from Zynq PS
- `peripheral_aresetn` → NPU reset input

---

### RTL-Instantiated IP (.xci files — live in ip/ folder)

#### 6. FIFO Generator
Instantiated multiple times inside `skew_fifos.sv` and `sequencer.sv`.

**Skew FIFOs (activation lane alignment):**

| Setting | Value |
|---|---|
| Interface Type | Native |
| FIFO Implementation | Independent Clocks Block RAM |
| Read Mode | First Word Fall Through (FWFT) |
| Write/Read Width | 128-bit |
| Write Depth | 16 |

**Command FIFOs (sequencer → execution units):**

| Setting | Value |
|---|---|
| Interface Type | Native |
| FIFO Implementation | Independent Clocks Distributed RAM |
| Read Mode | FWFT |
| Write/Read Width | 128-bit |
| Write Depth | 16 |
| Almost Empty/Full Flags | Checked |

---

### Primitives — No IP Required (Direct RTL Instantiation)

| Primitive | Used In |
|---|---|
| DSP48E2 | systolic_array.sv — INT8×INT8 MAC units, dual-packed |
| RAMB36 | ping_pong_hub.sv, psb.sv — on-chip SRAM |

---

## External IP Repository Setup

1. Create the folder: `mkdir -p ~/kria_npu/ip/`
2. Add to Vivado: Tools → Settings → IP → Repository → (+) → select `~/kria_npu/ip/`
3. Generate IP via IP Catalog (lands in project `.srcs` by default)
4. Move the IP subfolder to `~/kria_npu/ip/`
5. Re-point Vivado: IP Sources tab → right-click broken IP → Replace File → point to new `.xci`
6. Run: `generate_target all [get_ips]`

---

## Block Design → RTL Integration

After completing the Block Design, right-click it and select **Create HDL Wrapper**. This produces `bd_npu_ps_wrapper.v` which is instantiated in `npu_top.sv` like any other module.

```
bd_npu_ps_wrapper.v   (auto-generated — do not edit)
    exposes:
    ├── pl_clk0           → clk (200 MHz)
    ├── pl_resetn0        → rst_n
    ├── M_AXI_HPM0_FPD   → s_axil_* ports on npu_top
    ├── S_AXI_HP0_FPD    → m_axi_* ports on npu_top (via CDMA)
    └── pl_ps_irq0[0]    → npu_intr
```

---

## npu_top.sv — Full Port List

```verilog
module npu_top (
    // Clock & Reset
    input  logic         clk,             // 200 MHz from Clocking Wizard
    input  logic         rst_n,           // active-low sync from Proc System Reset

    // AXI4-Lite Slave — CPU control path (→ csr_regbank.sv)
    input  logic         s_axil_awvalid,
    output logic         s_axil_awready,
    input  logic [31:0]  s_axil_awaddr,
    input  logic         s_axil_wvalid,
    output logic         s_axil_wready,
    input  logic [31:0]  s_axil_wdata,
    input  logic [3:0]   s_axil_wstrb,
    output logic         s_axil_bvalid,
    input  logic         s_axil_bready,
    output logic [1:0]   s_axil_bresp,
    input  logic         s_axil_arvalid,
    output logic         s_axil_arready,
    input  logic [31:0]  s_axil_araddr,
    output logic         s_axil_rvalid,
    input  logic         s_axil_rready,
    output logic [31:0]  s_axil_rdata,
    output logic [1:0]   s_axil_rresp,

    // AXI4 Master — DMA data path (→ dma_controller.sv → ping_pong_hub.sv)
    output logic         m_axi_awvalid,
    input  logic         m_axi_awready,
    output logic [63:0]  m_axi_awaddr,
    output logic [7:0]   m_axi_awlen,
    output logic [2:0]   m_axi_awsize,
    output logic [1:0]   m_axi_awburst,
    output logic         m_axi_wvalid,
    input  logic         m_axi_wready,
    output logic [127:0] m_axi_wdata,
    output logic [15:0]  m_axi_wstrb,
    output logic         m_axi_wlast,
    input  logic         m_axi_bvalid,
    output logic         m_axi_bready,
    input  logic [1:0]   m_axi_bresp,
    output logic         m_axi_arvalid,
    input  logic         m_axi_arready,
    output logic [63:0]  m_axi_araddr,
    output logic [7:0]   m_axi_arlen,
    output logic [2:0]   m_axi_arsize,
    output logic [1:0]   m_axi_arburst,
    input  logic         m_axi_rvalid,
    output logic         m_axi_rready,
    input  logic [127:0] m_axi_rdata,
    input  logic         m_axi_rlast,
    input  logic [1:0]   m_axi_rresp,

    // Interrupt — frame completion (→ sequencer.sv → PS IRQ0[0])
    output logic         npu_intr
);
```

---

## Internal Signal Flow

```
CPU (Linux driver)
    │ ioctl / mmap
    ▼
csr_regbank.sv        ← s_axil_* ports
    │ base_addr, tile_count, go_pulse
    ▼
sequencer.sv          ← orchestrates all units via instruction FIFOs
    │              │              │              │
    ▼              ▼              ▼              ▼
dma_controller  systolic_array  vpu.sv        psb.sv
    │               │              ▲              ▲
    ▼               ▼              │              │
ping_pong_hub   partial sums ─────┘    accumulated results
    │
    ▼
skew_fifos.sv   ← FIFO Generator .xci instances here
    │
    ▼
systolic_array.sv (activation input)

sequencer.sv ──► npu_intr  (asserted when all units report done for a frame)
```

---

## Port → Submodule Mapping Summary

| Port Group | Destination |
|---|---|
| `clk`, `rst_n` | All submodules |
| `s_axil_*` | `csr_regbank.sv` only |
| `m_axi_*` | `dma_controller.sv` only |
| `npu_intr` | Driven by `sequencer.sv` |

---

## Build Order

1. Set up external IP repository folder
2. Apply KR260 board preset to Zynq PS IP
3. Build Block Design (Zynq PS + SmartConnect + CDMA + Clocking Wizard + Proc Reset)
4. Export Block Design as HDL Wrapper
5. Generate FIFO Generator `.xci` files, move to `ip/` folder
6. Write RTL submodules (systolic array, VPU, PSB, ping-pong hub, skew FIFOs, sequencer, CSR bank, DMA controller)
7. Write `npu_top.sv` instantiating all submodules + `bd_npu_ps_wrapper`
8. Run `generate_target all [get_ips]`
9. Run synthesis and implementation in Vivado

---

## What the Linux Driver Owns

- Programs AXI CDMA src/dst addresses and length via `/dev/` character device
- Writes `go` bit to NPU CSR bank via AXI-Lite (M_AXI_HPM0_FPD)
- Allocates DMA-coherent buffers with `dma_alloc_coherent`
- Sleeps on `wait_for_completion_interruptible()` until `npu_intr` fires
- Uses single completion interrupt per frame
