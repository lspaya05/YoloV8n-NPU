import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;


// AXI port naming:
//   seq_* : Sequencer AXI4 read master (instruction fetch, HP0_SEQ)
//   dma_* : DMA Ch0  AXI4 read master (DMA_LOAD, HP0_DMA)
//   wt_*  : DMA Ch1  AXI4 read master (WT_LOAD,  HP1_DMA)

module NPU_TopLevel (
    input  logic clk,
    input  logic rst,

    // -------------------------------------------------------------------------
    // AXI-Lite slave — Sequencer CSR (ARM PS writes instr_base / count / kick)
    // Write-only: AW + W + B channels only (no AR/R per v2.1 arch doc §14.2).
    // -------------------------------------------------------------------------
    input  logic [31:0] s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,

    // -------------------------------------------------------------------------
    // HP0_SEQ — Sequencer AXI4 read master (instruction fetch)
    // 4-beat 32-bit INCR bursts; Sequencer assembles 128-bit instructions.
    // -------------------------------------------------------------------------
    output logic [43:0] seq_araddr,
    output logic        seq_arvalid,
    output logic [7:0]  seq_arlen,
    output logic [2:0]  seq_arsize,
    output logic [1:0]  seq_arburst,
    input  logic        seq_arready,
    input  logic [31:0] seq_rdata,
    input  logic        seq_rvalid,
    input  logic        seq_rlast,
    input  logic [1:0]  seq_rresp,
    output logic        seq_rready,

    // -------------------------------------------------------------------------
    // HP0_DMA — DMA Ch0 AXI4 read master (DMA_LOAD activation tiles)
    // 128-bit data, 44-bit address, INCR, arcache=0011.
    // -------------------------------------------------------------------------
    output logic [43:0]  dma_araddr,
    output logic         dma_arvalid,
    output logic [7:0]   dma_arlen,
    output logic [2:0]   dma_arsize,
    output logic [1:0]   dma_arburst,
    output logic [3:0]   dma_arcache,
    input  logic         dma_arready,
    input  logic [127:0] dma_rdata,
    input  logic         dma_rvalid,
    input  logic         dma_rlast,
    input  logic [1:0]   dma_rresp,
    output logic         dma_rready,

    // -------------------------------------------------------------------------
    // HP1_DMA — DMA Ch1 AXI4 read master (WT_LOAD weight tiles)
    // 128-bit data, 44-bit address, INCR, arcache=0011.
    // -------------------------------------------------------------------------
    output logic [43:0]  wt_araddr,
    output logic         wt_arvalid,
    output logic [7:0]   wt_arlen,
    output logic [2:0]   wt_arsize,
    output logic [1:0]   wt_arburst,
    output logic [3:0]   wt_arcache,
    input  logic         wt_arready,
    input  logic [127:0] wt_rdata,
    input  logic         wt_rvalid,
    input  logic         wt_rlast,
    input  logic [1:0]   wt_rresp,
    output logic         wt_rready,

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------
    output logic irq_done,   // per-frame IRQ (final DMA_STORE done — Phase 4)
    output logic fetch_err,  // Sequencer AXI error
    output logic dma_err     // DMA AXI error (HP0 or HP1)
);

// Sequencer:   
Sequencer #(

) sequence_unit (

); 

// SRAM HUB - inc Partial Sum Buffer
SRAMHub #(

) SRAM_hub (

);


// DMA 


// Systolic Array
SA_top #(

) Systolic_array (

);

// Partial Sum Buffer
PSB #( 

) partial_sum_buffer (

);

// Requantization Pipeline
RequantPipeline #(

) requantization_pipeline (

);

// Vector Processiong Unit
VPU #(

) vector_processing_unit (

);


endmodule
