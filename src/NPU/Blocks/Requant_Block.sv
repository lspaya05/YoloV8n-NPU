// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Requantization block wrapper. Encapsulates the REQUANT instruction FIFO,
// Dispatch_REQ FSM, and the 5-stage RequantPipeline (INT32 -> INT8). Exposes
// the Sequencer 4-pin contract, four DepFIFO consumer/producer pairs, the
// 512-bit packed row input from PSB_Block, the Coeff-BRAM read handle, and
// the Output-Bank writer bus that is muxed against the VPU_Block writer at
// NPU top. Dep gating uses Option A — Dispatch_REQ is untouched.
// Parameters:
//     - Lanes: requant pipeline width (default 16, matches VPU_LANES and OB word)
//     - ChCount: per-instruction coefficient channel count (default 1)
//     - M0Width: requant scale field width (default COEFF_M_WIDTH)
//     - ShiftWidth: requant shift field width (default 8)
// Inputs:
//     - clk, rst
//     - disp_payload, disp_push: from Sequencer (slot index 3)
//     - psb_row_in: 512-bit packed INT32x16 row from PSB_Block
//     - psb_row_valid: row strobe from PSB_Block
//     - coeff_rdata: Coeff BRAM read data
//     - dep_psb_to_req_empty, dep_vpu_to_req_empty: upstream readiness
//     - dep_req_to_psb_full, dep_req_to_vpu_full: downstream backpressure
// Outputs:
//     - disp_full, unit_done
//     - coeff_raddr: Coeff BRAM read address
//     - out_waddr, out_wdata, out_wen: Output-Bank writer bus (mux'd at top)
//     - req_armed: high while pipeline is in FROM_PSB mode (gates PSB flush)
//     - dep_psb_to_req_pop, dep_vpu_to_req_pop: token consumption
//     - dep_req_to_psb_push, dep_req_to_vpu_push: token production

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Requant_Block #(
    parameter int Lanes      = 16,
    parameter int ChCount    = 1,
    parameter int M0Width    = COEFF_M_WIDTH,
    parameter int ShiftWidth = 8
) (
    input  logic                                clk,
    input  logic                                rst,

    // Sequencer interface (slot index 3)
    input  logic [123:0]                        disp_payload,
    input  logic                                disp_push,
    output logic                                disp_full,
    output logic                                unit_done,

    // Datapath in — from PSB_Block
    input  logic [SA_COLS*ACCUM_WIDTH-1:0]      psb_row_in,
    input  logic                                psb_row_valid,

    // SRAMHub — Coeff BRAM read
    output logic [$clog2(MAX_CHANNELS)-1:0]                coeff_raddr,
    input  logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]         coeff_rdata,

    // Output Bank writer bus (mux'd against VPU at NPU top)
    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   out_waddr,
    output logic [127:0]                        out_wdata,
    output logic                                out_wen,

    // High once the pipeline is configured in FROM_PSB mode (S_RUN). PSB_Block
    // gates OP_PSB_FLUSH on this so flush rows are never emitted before Requant
    // is armed to receive them.
    output logic                                req_armed,

    // Dep-in
    input  logic                                dep_psb_to_req_empty,
    output logic                                dep_psb_to_req_pop,
    input  logic                                dep_vpu_to_req_empty,
    output logic                                dep_vpu_to_req_pop,

    // Dep-out
    input  logic                                dep_req_to_psb_full,
    output logic                                dep_req_to_psb_push,
    input  logic                                dep_req_to_vpu_full,
    output logic                                dep_req_to_vpu_push
);

    // -------------------------------------------------------------------------
    // REQUANT instruction FIFO
    // -------------------------------------------------------------------------
    logic [123:0] req_dout;
    logic         req_fifo_empty;
    logic         req_fifo_rd_en;
    logic         req_fifo_pop;
    logic         req_fifo_pop_d;
    logic [123:0] req_issue_dout;
    logic         req_issue_valid;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (8)
    ) REQUANT_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push),
        .rd_en  (req_fifo_pop),
        .din    (disp_payload),
        .dout   (req_dout),
        .full   (disp_full),
        .empty  (req_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Dep gating
    // -------------------------------------------------------------------------
    logic deps_ready;
    logic req_empty_to_dispatch;
    logic req_rd_en_from_dispatch;
    logic req_done_pulse;

    // WAR-only gate: don't re-issue before VPU has consumed the previous result
    // (dep_vpu_to_req starts pre-seeded). PSB->REQ ordering is handled by the
    // req_armed handshake (PSB_Block gates flush on it), so no dep_psb_to_req RAW
    // gate here — that token only arrives after flush-done and would deadlock
    // against the arm-gate. The outgoing _full terms were also wrong (a block
    // shouldn't gate issue on its own producer backpressure) and are dropped.
    assign deps_ready            = ~dep_vpu_to_req_empty;
    assign req_empty_to_dispatch = ~req_issue_valid | ~deps_ready;
    assign req_fifo_pop          = ~req_fifo_empty & ~req_issue_valid;
    assign req_fifo_rd_en        = req_rd_en_from_dispatch;

    assign dep_psb_to_req_pop = req_done_pulse & ~dep_psb_to_req_empty;
    assign dep_vpu_to_req_pop = req_rd_en_from_dispatch;

    assign dep_req_to_psb_push = req_done_pulse;
    assign dep_req_to_vpu_push = req_done_pulse;

    // Producer-side backpressure is not gated on this pass (FENCE/arm ordering is
    // assumed to prevent DepFIFO overflow), so these _full inputs are observed
    // but not consumed. Keep them referenced to avoid UNUSED lint.
    logic _unused_req_full;
    assign _unused_req_full = dep_req_to_psb_full | dep_req_to_vpu_full;

    always_ff @(posedge clk) begin
        if (rst) begin
            req_fifo_pop_d  <= 1'b0;
            req_issue_dout  <= '0;
            req_issue_valid <= 1'b0;
        end else begin
            req_fifo_pop_d <= req_fifo_pop;
            if (req_rd_en_from_dispatch) begin
                req_issue_valid <= 1'b0;
            end
            if (req_fifo_pop_d) begin
                req_issue_dout  <= req_dout;
                req_issue_valid <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Dispatch_REQ
    // -------------------------------------------------------------------------
    logic [1:0]                        req_mode_w;
    logic [ChCount*M0Width-1:0]        req_m0_a_w;
    logic [ChCount*ShiftWidth-1:0]     req_n_a_w;
    logic [ChCount*32-1:0]             req_bias_w;
    logic [Lanes*8-1:0]                req_data_o_w;
    logic                              req_valid_o_w;

    Dispatch_REQ #(
        .ChCount    (ChCount),
        .M0Width    (M0Width),
        .ShiftWidth (ShiftWidth)
    ) u_dispatch_req (
        .clk             (clk),
        .rst             (rst),
        .fifo_dout       (req_issue_dout),
        .fifo_empty      (req_empty_to_dispatch),
        .fifo_rd_en      (req_rd_en_from_dispatch),
        .req_valid_o     (req_valid_o_w),
        .req_data_o      (req_data_o_w),
        .req_coeff_rdata (coeff_rdata),
        .req_mode        (req_mode_w),
        .req_coeff_raddr (coeff_raddr),
        .req_m0_a        (req_m0_a_w),
        .req_n_a         (req_n_a_w),
        .req_bias        (req_bias_w),
        .vpu_out_waddr   (out_waddr),
        .vpu_out_wdata   (out_wdata),
        .vpu_out_wen     (out_wen),
        .unit_done       (req_done_pulse)
    );

    assign unit_done = req_done_pulse;

    // FROM_PSB (2'b01) means Dispatch_REQ has loaded coeffs and is in S_RUN
    // waiting for flush rows — i.e. armed.
    assign req_armed = (req_mode_w == 2'b01);

    // -------------------------------------------------------------------------
    // RequantPipeline datapath
    // -------------------------------------------------------------------------
    RequantPipeline #(
        .Lanes      (Lanes),
        .ChCount    (ChCount),
        .M0Width    (M0Width),
        .ShiftWidth (ShiftWidth)
    ) requantization_pipeline (
        .clk             (clk),
        .rst             (rst),
        .mode_i          (req_mode_w),
        .psb_row_i       (psb_row_in),
        .psb_row_valid_i (psb_row_valid),
        .sram_a_i        ('0),
        .sram_a_valid_i  (1'b0),
        .sram_b_i        ('0),
        .bias_i          (req_bias_w),
        .m0_a_i          (req_m0_a_w),
        .n_a_i           (req_n_a_w),
        .m0_b_i          ('0),
        .n_b_i           ('0),
        .data_o          (req_data_o_w),
        .valid_o         (req_valid_o_w)
    );

endmodule
