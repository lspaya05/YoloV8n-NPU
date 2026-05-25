// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// NPU v2.1 on-chip memory hub: Act/WT ping-pong, residual/output BRAM, requant coeff BRAM, LUTs.
// Parameters:
//     - ACT_DEPTH: entries per activation ping-pong bank
//     - WT_DEPTH: entries per weight ping-pong bank
//     - RES_DEPTH: entries in the residual bank
//     - OUT_DEPTH: entries in the output bank
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - dma_act_waddr: DMA write address into inactive activation ping-pong bank
//     - dma_act_wdata: 128-bit DMA write data to activation ping-pong
//     - dma_act_wen: DMA write enable for activation ping-pong
//     - dma_act_bank_full: DMA asserts when inactive activation bank is fully written
//     - sa_act_raddr: SA read address for active activation bank
//     - sa_act_bank_read: SA asserts when active activation tile is consumed
//     - dma_wt_waddr: DMA write address into inactive weight ping-pong bank
//     - dma_wt_wdata: 128-bit DMA write data to weight ping-pong
//     - dma_wt_wen: DMA write enable for weight ping-pong
//     - dma_wt_bank_full: DMA asserts when inactive weight bank is fully written
//     - sa_wt_raddr: SA read address for active weight bank
//     - sa_wt_bank_read: SA asserts when active weight tile is consumed
//     - dma_res_waddr: DMA write address into residual bank
//     - dma_res_wdata: 128-bit DMA write data to residual bank
//     - dma_res_wen: DMA write enable for residual bank
//     - vpu_res_raddr: VPU read address into residual bank for ELEW_ADD
//     - vpu_out_waddr: VPU write address into output bank
//     - vpu_out_wdata: 128-bit VPU write data to output bank
//     - vpu_out_wen: VPU write enable for output bank
//     - out_rd_sel: Output bank reader select: 0 = DMA (DMA_STORE), 1 = VPU (HREDUCE)
//     - dma_out_raddr: DMA read address for output bank
//     - vpu_hred_raddr: VPU HREDUCE read address for output bank
//     - dma_coeff_waddr: DMA write address into requant coeff BRAM
//     - dma_coeff_wdata: Requant coeff write data, COEFF_M_WIDTH+COEFF_S_WIDTH bits
//     - dma_coeff_wen: DMA write enable for requant coeff BRAM
//     - req_coeff_raddr: Requantization unit read address for coeff BRAM
//     - dma_lut_waddr: 8-bit DMA write address for LUT banks
//     - dma_lut_wdata: 8-bit DMA write data to selected LUT bank
//     - dma_lut_wen: DMA write enable for LUT banks
//     - dma_lut_sel: LUT write select: 0 = Act LUT, 1 = HREDUCE LUT
//     - vpu_lut_raddr: 8-bit VPU read address for LUT banks
//     - vpu_lut_sel: LUT read select: 0 = Act LUT, 1 = HREDUCE LUT
// Outputs:
//     - sa_act_rdata: 128-bit active activation tile data to systolic array
//     - sa_wt_rdata: 128-bit active weight tile data to systolic array
//     - vpu_res_rdata: 128-bit residual data to VPU for ELEW_ADD
//     - dma_out_rdata: 128-bit output bank data to DMA (DMA_STORE path)
//     - vpu_hred_rdata: 128-bit output bank data to VPU HREDUCE path
//     - req_coeff_rdata: Requant M+S coefficients to requant unit, COEFF_M+COEFF_S bits
//     - vpu_lut_rdata: 8-bit LUT entry to VPU, selected by vpu_lut_sel

import NPU_HW_params_pkg::*;

// Central on-chip memory arbiter for the NPU v2.1.
// Instantiates: Act ping-pong, Weight ping-pong, Residual bank, Output bank,
// Requant Coeff BRAM, Act LUT, HREDUCE LUT.
// Instruction FIFOs are Vivado IP (FIFO Generator) — not included here.
module SRAMHub #(
    parameter int ACT_DEPTH  = ACT_BUF_DEPTH,   // entries per ping-pong bank
    parameter int WT_DEPTH   = WT_BUF_DEPTH,
    parameter int RES_DEPTH  = RES_BANK_DEPTH,
    parameter int OUT_DEPTH  = OUT_BANK_DEPTH
)(
    input logic clk,
    input logic rst,

    // -----------------------------------------------------------------------
    // Activation ping-pong  (DMA writes inactive bank, SA reads active bank)
    // -----------------------------------------------------------------------
    input  logic [$clog2(ACT_DEPTH)-1:0] dma_act_waddr,
    input  logic [127:0]                 dma_act_wdata,
    input  logic                         dma_act_wen,
    input  logic                         dma_act_bank_full,   // DMA: inactive bank done

    input  logic [$clog2(ACT_DEPTH)-1:0] sa_act_raddr,
    output logic [127:0]                 sa_act_rdata,
    input  logic                         sa_act_bank_read,    // SA: active tile consumed

    // -----------------------------------------------------------------------
    // Weight ping-pong  (DMA writes inactive bank, SA reads active bank)
    // -----------------------------------------------------------------------
    input  logic [$clog2(WT_DEPTH)-1:0]  dma_wt_waddr,
    input  logic [127:0]                 dma_wt_wdata,
    input  logic                         dma_wt_wen,
    input  logic                         dma_wt_bank_full,

    input  logic [$clog2(WT_DEPTH)-1:0]  sa_wt_raddr,
    output logic [127:0]                 sa_wt_rdata,
    input  logic                         sa_wt_bank_read,

    // -----------------------------------------------------------------------
    // Residual bank  (DMA writes, VPU reads for ELEW_ADD)
    // -----------------------------------------------------------------------
    input  logic [$clog2(RES_DEPTH)-1:0] dma_res_waddr,
    input  logic [127:0]                 dma_res_wdata,
    input  logic                         dma_res_wen,

    input  logic [$clog2(RES_DEPTH)-1:0] vpu_res_raddr,
    output logic [127:0]                 vpu_res_rdata,

    // -----------------------------------------------------------------------
    // Output bank  (VPU writes, DMA/VPU-HREDUCE reads)
    // out_rd_sel: 0 = DMA reads (DMA_STORE), 1 = VPU reads (HREDUCE)
    // -----------------------------------------------------------------------
    input  logic [$clog2(OUT_DEPTH)-1:0] vpu_out_waddr,
    input  logic [127:0]                 vpu_out_wdata,
    input  logic                         vpu_out_wen,

    input  logic                         out_rd_sel,
    input  logic [$clog2(OUT_DEPTH)-1:0] dma_out_raddr,
    output logic [127:0]                 dma_out_rdata,
    input  logic [$clog2(OUT_DEPTH)-1:0] vpu_hred_raddr,
    output logic [127:0]                 vpu_hred_rdata,

    // -----------------------------------------------------------------------
    // Requant Coeff BRAM  512 x 36-bit: [35:4]=M (INT32), [3:0]=S (UINT4)
    // -----------------------------------------------------------------------
    input  logic [$clog2(MAX_CHANNELS)-1:0] dma_coeff_waddr,
    input  logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] dma_coeff_wdata,
    input  logic                                    dma_coeff_wen,

    input  logic [$clog2(MAX_CHANNELS)-1:0] req_coeff_raddr,
    output logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] req_coeff_rdata,

    // -----------------------------------------------------------------------
    // LUT banks  256 x 8-bit (Act LUT and HREDUCE exp LUT)
    // dma_lut_sel: 0 = write Act LUT, 1 = write HREDUCE LUT
    // vpu_lut_sel: 0 = read Act LUT,  1 = read HREDUCE LUT
    // -----------------------------------------------------------------------
    input  logic [7:0] dma_lut_waddr,
    input  logic [7:0] dma_lut_wdata,
    input  logic       dma_lut_wen,
    input  logic       dma_lut_sel,

    input  logic [7:0] vpu_lut_raddr,
    output logic [7:0] vpu_lut_rdata,
    input  logic       vpu_lut_sel
);

// ---------------------------------------------------------------------------
// Activation ping-pong
// ---------------------------------------------------------------------------
PingPongBuffer #(
    .BUFFER_DEPTH (ACT_DEPTH),
    .DATA_BITWIDTH(128)
) act_buf (
    .clk        (clk),
    .rst        (rst),
    .w_data     (dma_act_wdata),
    .w_addr     (dma_act_waddr),
    .write_en   (dma_act_wen),
    .bank_full  (dma_act_bank_full),
    .r_addr     (sa_act_raddr),
    .r_data     (sa_act_rdata),
    .bank_read  (sa_act_bank_read)
);

// ---------------------------------------------------------------------------
// Weight ping-pong
// ---------------------------------------------------------------------------
PingPongBuffer #(
    .BUFFER_DEPTH (WT_DEPTH),
    .DATA_BITWIDTH(128)
) wt_buf (
    .clk        (clk),
    .rst        (rst),
    .w_data     (dma_wt_wdata),
    .w_addr     (dma_wt_waddr),
    .write_en   (dma_wt_wen),
    .bank_full  (dma_wt_bank_full),
    .r_addr     (sa_wt_raddr),
    .r_data     (sa_wt_rdata),
    .bank_read  (sa_wt_bank_read)
);

// ---------------------------------------------------------------------------
// Residual bank
// ---------------------------------------------------------------------------
SimpleBRAM #(
    .DEPTH      (RES_DEPTH),
    .DATA_WIDTH (128)
) res_bank (
    .clk    (clk),
    .w_addr (dma_res_waddr),
    .w_data (dma_res_wdata),
    .w_en   (dma_res_wen),
    .r_addr (vpu_res_raddr),
    .r_data (vpu_res_rdata)
);

// ---------------------------------------------------------------------------
// Output bank — shared read port muxed between DMA and VPU-HREDUCE
// ---------------------------------------------------------------------------
logic [$clog2(OUT_DEPTH)-1:0] out_raddr_mux;
logic [127:0]                 out_rdata_int;

assign out_raddr_mux  = out_rd_sel ? vpu_hred_raddr : dma_out_raddr;
assign dma_out_rdata  = out_rdata_int;
assign vpu_hred_rdata = out_rdata_int;

SimpleBRAM #(
    .DEPTH      (OUT_DEPTH),
    .DATA_WIDTH (128)
) out_bank (
    .clk    (clk),
    .w_addr (vpu_out_waddr),
    .w_data (vpu_out_wdata),
    .w_en   (vpu_out_wen),
    .r_addr (out_raddr_mux),
    .r_data (out_rdata_int)
);

// ---------------------------------------------------------------------------
// Requant Coeff BRAM  (512 x 36-bit)
// ---------------------------------------------------------------------------
SimpleBRAM #(
    .DEPTH      (MAX_CHANNELS),
    .DATA_WIDTH (COEFF_M_WIDTH + COEFF_S_WIDTH)
) coeff_bram (
    .clk    (clk),
    .w_addr (dma_coeff_waddr),
    .w_data (dma_coeff_wdata),
    .w_en   (dma_coeff_wen),
    .r_addr (req_coeff_raddr),
    .r_data (req_coeff_rdata)
);

// ---------------------------------------------------------------------------
// Act LUT  (256 x 8-bit, SiLU table)
// ---------------------------------------------------------------------------
logic [7:0] act_lut_rdata;

SimpleBRAM #(
    .DEPTH      (LUT_DEPTH),
    .DATA_WIDTH (ACT_WIDTH)
) act_lut (
    .clk    (clk),
    .w_addr (dma_lut_waddr),
    .w_data (dma_lut_wdata),
    .w_en   (dma_lut_wen & ~dma_lut_sel),
    .r_addr (vpu_lut_raddr),
    .r_data (act_lut_rdata)
);

// ---------------------------------------------------------------------------
// HREDUCE exp LUT  (256 x 8-bit, softmax exp table)
// ---------------------------------------------------------------------------
logic [7:0] hreduce_lut_rdata;

SimpleBRAM #(
    .DEPTH      (LUT_DEPTH),
    .DATA_WIDTH (ACT_WIDTH)
) hreduce_lut (
    .clk    (clk),
    .w_addr (dma_lut_waddr),
    .w_data (dma_lut_wdata),
    .w_en   (dma_lut_wen & dma_lut_sel),
    .r_addr (vpu_lut_raddr),
    .r_data (hreduce_lut_rdata)
);

assign vpu_lut_rdata = vpu_lut_sel ? hreduce_lut_rdata : act_lut_rdata;

endmodule
