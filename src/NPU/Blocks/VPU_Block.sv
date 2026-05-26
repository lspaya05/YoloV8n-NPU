// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Vector-processing-unit block wrapper. Encapsulates the VPU instruction
// FIFO, Dispatch_VPU FSM, and the VPU lane datapath. Exposes the Sequencer
// 4-pin contract, four DepFIFO consumer/producer pairs, SRAMHub read handles
// for the Output/Residual/LUT banks, and the Output-Bank writer bus that is
// muxed against the Requant_Block writer at NPU top. Dep gating uses Option A
// — Dispatch_VPU is untouched. Lane count is parameterized (default 16,
// matching Phase-5 baseline; v2.1 spec target 64 deferred).
// Parameters:
//     - Lanes: VPU lane count (default 16)
// Inputs:
//     - clk, rst
//     - disp_payload, disp_push: from Sequencer (slot index 4)
//     - cfg_tile_M, cfg_tile_N: CSR shadows from Sequencer
//     - hred_rdata, res_rdata: SRAMHub read data
//     - dep_req_to_vpu_empty, dep_dma_to_vpu_empty: upstream readiness
//     - dep_vpu_to_req_full, dep_vpu_to_dma_full: downstream backpressure
// Outputs:
//     - disp_full, unit_done
//     - hred_raddr, out_rd_sel: SRAMHub Output-bank read interface
//     - res_raddr: SRAMHub Residual-bank read address
//     - lut_sel: SRAMHub LUT ping-pong select (raddr deferred)
//     - out_waddr, out_wdata, out_wen: Output-Bank writer bus (mux'd at top)
//     - dep_req_to_vpu_pop, dep_dma_to_vpu_pop: token consumption
//     - dep_vpu_to_req_push, dep_vpu_to_dma_push: token production

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module VPU_Block #(
    parameter int Lanes = 16
) (
    input  logic                                clk,
    input  logic                                rst,

    // Sequencer interface (slot index 4)
    input  logic [123:0]                        disp_payload,
    input  logic                                disp_push,
    output logic                                disp_full,
    output logic                                unit_done,

    // CSR shadows
    input  logic [7:0]                          cfg_tile_M,
    input  logic [7:0]                          cfg_tile_N,

    // SRAMHub — Output bank read (HREDUCE path)
    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   hred_raddr,
    input  logic [127:0]                        hred_rdata,
    output logic                                out_rd_sel,

    // SRAMHub — Residual bank read
    output logic [$clog2(RES_BANK_DEPTH)-1:0]   res_raddr,
    input  logic [127:0]                        res_rdata,

    // SRAMHub — LUT select (raddr/data deferred)
    output logic                                lut_sel,

    // Output Bank writer bus (mux'd against Requant at NPU top)
    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   out_waddr,
    output logic [127:0]                        out_wdata,
    output logic                                out_wen,

    // Dep-in
    input  logic                                dep_req_to_vpu_empty,
    output logic                                dep_req_to_vpu_pop,
    input  logic                                dep_dma_to_vpu_empty,
    output logic                                dep_dma_to_vpu_pop,

    // Dep-out
    input  logic                                dep_vpu_to_req_full,
    output logic                                dep_vpu_to_req_push,
    input  logic                                dep_vpu_to_dma_full,
    output logic                                dep_vpu_to_dma_push
);

    // -------------------------------------------------------------------------
    // VPU instruction FIFO
    // -------------------------------------------------------------------------
    logic [123:0] vpu_dout;
    logic         vpu_fifo_empty;
    logic         vpu_fifo_rd_en;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (16)
    ) VPU_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push),
        .rd_en  (vpu_fifo_rd_en),
        .din    (disp_payload),
        .dout   (vpu_dout),
        .full   (disp_full),
        .empty  (vpu_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Dep gating
    // -------------------------------------------------------------------------
    logic deps_ready;
    logic vpu_empty_to_dispatch;
    logic vpu_rd_en_from_dispatch;
    logic vpu_done_pulse;

    assign deps_ready            = ~dep_req_to_vpu_empty & ~dep_dma_to_vpu_empty;
    assign vpu_empty_to_dispatch = vpu_fifo_empty | ~deps_ready;
    assign vpu_fifo_rd_en        = vpu_rd_en_from_dispatch;

    assign dep_req_to_vpu_pop = vpu_rd_en_from_dispatch;
    assign dep_dma_to_vpu_pop = vpu_rd_en_from_dispatch;

    assign dep_vpu_to_req_push = vpu_done_pulse;
    assign dep_vpu_to_dma_push = vpu_done_pulse;

    // -------------------------------------------------------------------------
    // Dispatch_VPU
    // -------------------------------------------------------------------------
    logic             vpu_enable_w;
    logic [7:0]       vpu_opcode_w;
    logic             vpu_reduce_max_w;
    logic             vpu_valid_opcode_w;
    logic [Lanes*8-1:0] vpu_in_a_w;
    logic [Lanes*8-1:0] vpu_in_b_w;
    logic [Lanes*8-1:0] vpu_out_w_bus;
    logic             lut_bypass_en_w;

    Dispatch_VPU #(
        .Lanes (Lanes)
    ) u_dispatch_vpu (
        .clk              (clk),
        .rst              (rst),
        .fifo_dout        (vpu_dout),
        .fifo_empty       (vpu_empty_to_dispatch),
        .fifo_rd_en       (vpu_rd_en_from_dispatch),
        .vpu_valid_opcode (vpu_valid_opcode_w),
        .vpu_out          (vpu_out_w_bus),
        .vpu_hred_rdata   (hred_rdata),
        .vpu_res_rdata    (res_rdata),
        .cfg_tile_M       (cfg_tile_M),
        .cfg_tile_N       (cfg_tile_N),
        .vpu_enable       (vpu_enable_w),
        .vpu_opcode       (vpu_opcode_w),
        .vpu_reduce_max   (vpu_reduce_max_w),
        .vpu_in_a         (vpu_in_a_w),
        .vpu_in_b         (vpu_in_b_w),
        .vpu_hred_raddr   (hred_raddr),
        .vpu_res_raddr    (res_raddr),
        .out_rd_sel       (out_rd_sel),
        .vpu_out_waddr    (out_waddr),
        .vpu_out_wdata    (out_wdata),
        .vpu_out_wen      (out_wen),
        .lut_bypass_en    (lut_bypass_en_w),
        .vpu_lut_sel      (lut_sel),
        .unit_done        (vpu_done_pulse)
    );

    assign unit_done = vpu_done_pulse;

    // -------------------------------------------------------------------------
    // VPU datapath
    // -------------------------------------------------------------------------
    vpu #(
        .LANES (Lanes)
    ) vector_processing_unit (
        .clk          (clk),
        .rst          (rst),
        .enable       (vpu_enable_w),
        .opcode       (vpu_opcode_w),
        .reduce_max   (vpu_reduce_max_w),
        .in_a         (vpu_in_a_w),
        .in_b         (vpu_in_b_w),
        .data_h_edge  (8'h0),
        .out          (vpu_out_w_bus),
        .valid_opcode (vpu_valid_opcode_w)
    );

endmodule
