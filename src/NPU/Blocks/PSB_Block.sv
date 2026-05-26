// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Partial-sum-buffer block wrapper. Encapsulates the PSB instr FIFO,
// Dispatch_PSB FSM, and the 16x16 INT32 accumulator. Exposes the Sequencer
// 4-pin contract, four DepFIFO consumer/producer pairs, the unpacked INT32
// row input from SA_Block, and the 512-bit packed requant-row output to
// Requant_Block. Dep gating uses Option A — Dispatch_PSB is untouched, the
// wrapper virtualises fifo_empty until upstream deps are ready and pushes
// downstream tokens on unit_done.
// Parameters:
//     - None (geometry pulled from NPU_HW_params_pkg)
// Inputs:
//     - clk, rst
//     - disp_payload, disp_push: from Sequencer (slot index 2)
//     - sa_row_in: INT32[SA_COLS] partial-sum row from SA_Block
//     - sa_row_valid: 1-cycle pulse on SA tile retire (reserved; not driving
//       psb internally — psb.row_valid is driven by Dispatch_PSB)
//     - dep_sa_to_psb_empty, dep_req_to_psb_empty: upstream readiness
//     - dep_psb_to_sa_full, dep_psb_to_req_full: downstream backpressure
// Outputs:
//     - disp_full, unit_done
//     - requant_row_out: 512-bit packed INT32x16 row to Requant_Block
//     - row_index_out, row_out_valid
//     - dep_sa_to_psb_pop, dep_req_to_psb_pop: token consumption
//     - dep_psb_to_sa_push, dep_psb_to_req_push: token production

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module PSB_Block (
    input  logic                                clk,
    input  logic                                rst,

    // Sequencer interface (slot index 2)
    input  logic [123:0]                        disp_payload,
    input  logic                                disp_push,
    output logic                                disp_full,
    output logic                                unit_done,

    // Datapath in — from SA_Block
    input  logic signed [ACCUM_WIDTH-1:0]       sa_row_in [SA_COLS-1:0],
    input  logic                                sa_row_valid,

    // Datapath out — to Requant_Block
    output logic [SA_COLS*ACCUM_WIDTH-1:0]      requant_row_out,
    output logic [$clog2(SA_ROWS)-1:0]          row_index_out,
    output logic                                row_out_valid,

    // Dep-in (consumer side)
    input  logic                                dep_sa_to_psb_empty,
    output logic                                dep_sa_to_psb_pop,
    input  logic                                dep_req_to_psb_empty,
    output logic                                dep_req_to_psb_pop,

    // Dep-out (producer side)
    input  logic                                dep_psb_to_sa_full,
    output logic                                dep_psb_to_sa_push,
    input  logic                                dep_psb_to_req_full,
    output logic                                dep_psb_to_req_push
);

    // -------------------------------------------------------------------------
    // PSB instruction FIFO
    // -------------------------------------------------------------------------
    logic [123:0] psb_dout;
    logic         psb_fifo_empty;
    logic         psb_fifo_rd_en;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (32)
    ) PSB_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push),
        .rd_en  (psb_fifo_rd_en),
        .din    (disp_payload),
        .dout   (psb_dout),
        .full   (disp_full),
        .empty  (psb_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Dep gating
    // -------------------------------------------------------------------------
    logic deps_ready;
    logic psb_empty_to_dispatch;
    logic psb_rd_en_from_dispatch;
    logic psb_done_pulse;

    assign deps_ready            = ~dep_sa_to_psb_empty & ~dep_req_to_psb_empty;
    assign psb_empty_to_dispatch = psb_fifo_empty | ~deps_ready;
    assign psb_fifo_rd_en        = psb_rd_en_from_dispatch;

    assign dep_sa_to_psb_pop  = psb_rd_en_from_dispatch;
    assign dep_req_to_psb_pop = psb_rd_en_from_dispatch;

    assign dep_psb_to_sa_push  = psb_done_pulse;
    assign dep_psb_to_req_push = psb_done_pulse;

    // -------------------------------------------------------------------------
    // Dispatch_PSB
    // -------------------------------------------------------------------------
    logic psb_acc_w;
    logic psb_flush_w;
    logic psb_row_valid_w;
    logic psb_acc_done_w;
    logic psb_flush_done_w;
    logic psb_busy_w;

    Dispatch_PSB u_dispatch_psb (
        .clk            (clk),
        .rst            (rst),
        .fifo_dout      (psb_dout),
        .fifo_empty     (psb_empty_to_dispatch),
        .fifo_rd_en     (psb_rd_en_from_dispatch),
        .psb_busy       (psb_busy_w),
        .psb_acc_done   (psb_acc_done_w),
        .psb_flush_done (psb_flush_done_w),
        .psb_acc        (psb_acc_w),
        .psb_flush      (psb_flush_w),
        .row_valid      (psb_row_valid_w),
        .unit_done      (psb_done_pulse)
    );

    assign unit_done = psb_done_pulse;

    // -------------------------------------------------------------------------
    // PSB accumulator datapath
    // -------------------------------------------------------------------------
    psb #(
        .ACCUMULATOR_BITWIDTH (ACCUM_WIDTH),
        .ARRAY_HEIGHT         (SA_ROWS),
        .ARRAY_LENGTH         (SA_COLS)
    ) partial_sum_buffer (
        .clk             (clk),
        .rst             (rst),
        .psb_acc         (psb_acc_w),
        .psb_flush       (psb_flush_w),
        .row_valid       (psb_row_valid_w),
        .sa_row_in       (sa_row_in),
        .requant_row_out (requant_row_out),
        .row_index_out   (row_index_out),
        .row_out_valid   (row_out_valid),
        .acc_done        (psb_acc_done_w),
        .flush_done      (psb_flush_done_w),
        .busy            (psb_busy_w)
    );

    // sa_row_valid is reserved for future use (e.g. an SA-driven row_valid
    // pipeline). Currently psb.row_valid is sourced from Dispatch_PSB, so
    // this port is observed but not consumed inside the block.
    logic _unused_sa_row_valid;
    assign _unused_sa_row_valid = sa_row_valid;

endmodule
