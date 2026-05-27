// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Systolic-array block wrapper. Encapsulates SA instruction FIFO, Dispatch_SA
// FSM, packed->unpacked SRAM word conversion, and the SA_top datapath. Exposes
// only the Sequencer 4-pin contract, two SRAMHub read-port handles, four
// DepFIFO consumer/producer port pairs, and the unpacked INT32 row output
// feeding the PSB block. Dep gating uses Option A — Dispatch_SA is untouched;
// the wrapper presents a virtual fifo_empty=1 when upstream deps are not
// ready, and pushes consumer-side WAR/RAW tokens on the unit_done pulse.
// Parameters:
//     - None (geometry pulled from NPU_HW_params_pkg)
// Inputs:
//     - clk, rst: system clock + sync active-high reset
//     - disp_payload: 124-bit dispatch payload from Sequencer
//     - disp_push: write-strobe into SA instr FIFO (= disp_push[1] at top)
//     - cfg_tile_K: CSR tile-K shadow from Sequencer
//     - sa_act_rdata, sa_wt_rdata: 128-bit packed bank read data from SRAMHub
//     - dep_dma_to_sa_empty, dep_psb_to_sa_empty: upstream RAW/WAR readiness
//     - dep_sa_to_dma_full, dep_sa_to_psb_full: downstream backpressure
// Outputs:
//     - disp_full: SA instr FIFO full (= disp_full[1] at top)
//     - unit_done: 1-cycle pulse to Sequencer FENCE bitmask
//     - sa_act_raddr, sa_wt_raddr: SRAMHub read addresses
//     - sa_act_bank_read, sa_wt_bank_read: ping-pong swap strobes
//     - sa_row_out: INT32[SA_COLS] partial-sum row to PSB block
//     - sa_row_valid: 1-cycle pulse on SA tile retire (= SA_top.done)
//     - dep_dma_to_sa_pop, dep_psb_to_sa_pop: token consumption strobes
//     - dep_sa_to_dma_push, dep_sa_to_psb_push: token production strobes

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module SA_Block (
    input  logic                                clk,
    input  logic                                rst,

    // Sequencer interface (slot index 1)
    input  logic [123:0]                        disp_payload,
    input  logic                                disp_push,
    output logic                                disp_full,
    output logic                                unit_done,

    // CSR shadow
    input  logic [7:0]                          cfg_tile_K,

    // SRAMHub — Activation bank read
    output logic [$clog2(ACT_BUF_DEPTH)-1:0]    sa_act_raddr,
    input  logic [127:0]                        sa_act_rdata,
    output logic                                sa_act_bank_read,

    // SRAMHub — Weight bank read
    output logic [$clog2(WT_BUF_DEPTH)-1:0]     sa_wt_raddr,
    input  logic [127:0]                        sa_wt_rdata,
    output logic                                sa_wt_bank_read,

    // Datapath out — to PSB_Block
    output logic signed [ACCUM_WIDTH-1:0]       sa_row_out [SA_COLS-1:0],
    output logic                                sa_row_valid,

    // Dep-in (consumer side)
    input  logic                                dep_dma_to_sa_empty,
    output logic                                dep_dma_to_sa_pop,
    input  logic                                dep_psb_to_sa_empty,
    output logic                                dep_psb_to_sa_pop,

    // Dep-out (producer side)
    input  logic                                dep_sa_to_dma_full,
    output logic                                dep_sa_to_dma_push,
    input  logic                                dep_sa_to_psb_full,
    output logic                                dep_sa_to_psb_push
);

    // -------------------------------------------------------------------------
    // SA instruction FIFO
    // -------------------------------------------------------------------------
    logic [123:0] sa_dout;
    logic         sa_fifo_empty;
    logic         sa_fifo_rd_en;
    logic         sa_fifo_pop;
    logic         sa_fifo_pop_d;
    logic [123:0] sa_issue_dout;
    logic         sa_issue_valid;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (32)
    ) SA_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push),
        .rd_en  (sa_fifo_pop),
        .din    (disp_payload),
        .dout   (sa_dout),
        .full   (disp_full),
        .empty  (sa_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Dep gating — Option A: hide instructions from Dispatch_SA until both
    // upstream deps are ready. Push downstream tokens on unit_done pulse.
    // -------------------------------------------------------------------------
    logic deps_ready;
    logic sa_empty_to_dispatch;
    logic sa_rd_en_from_dispatch;
    logic sa_done_pulse;

    assign deps_ready           = ~dep_dma_to_sa_empty & ~dep_psb_to_sa_empty;
    assign sa_empty_to_dispatch = ~sa_issue_valid | ~deps_ready;
    assign sa_fifo_pop          = ~sa_fifo_empty & ~sa_issue_valid;
    assign sa_fifo_rd_en        = sa_rd_en_from_dispatch;

    // Pop both upstream tokens on the cycle Dispatch_SA actually consumes an
    // instruction (rd_en only fires when sa_empty_to_dispatch is low, which
    // requires deps_ready).
    assign dep_dma_to_sa_pop = sa_rd_en_from_dispatch;
    assign dep_psb_to_sa_pop = sa_rd_en_from_dispatch;

    // Push downstream tokens on tile completion. Backpressure on
    // dep_*_full is intentionally ignored this pass — FENCE-based ordering
    // is assumed to prevent overflow. Revisit if a producer overruns DepFIFO.
    assign dep_sa_to_dma_push = sa_done_pulse;
    assign dep_sa_to_psb_push = sa_done_pulse;

    always_ff @(posedge clk) begin
        if (rst) begin
            sa_fifo_pop_d  <= 1'b0;
            sa_issue_dout  <= '0;
            sa_issue_valid <= 1'b0;
        end else begin
            sa_fifo_pop_d <= sa_fifo_pop;
            if (sa_rd_en_from_dispatch) begin
                sa_issue_valid <= 1'b0;
            end
            if (sa_fifo_pop_d) begin
                sa_issue_dout  <= sa_dout;
                sa_issue_valid <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Dispatch_SA — drives SRAMHub read addresses and SA_top start.
    // -------------------------------------------------------------------------
    logic sa_start_w;
    logic sa_done_w;
    logic sa_busy_w;
    logic sa_load_done_w;

    Dispatch_SA u_dispatch_sa (
        .clk              (clk),
        .rst              (rst),
        .fifo_dout        (sa_issue_dout),
        .fifo_empty       (sa_empty_to_dispatch),
        .fifo_rd_en       (sa_rd_en_from_dispatch),
        .sa_done          (sa_done_w),
        .cfg_tile_K       (cfg_tile_K),
        .sa_start         (sa_start_w),
        .sa_act_raddr     (sa_act_raddr),
        .sa_wt_raddr      (sa_wt_raddr),
        .sa_act_bank_read (sa_act_bank_read),
        .sa_wt_bank_read  (sa_wt_bank_read),
        .unit_done        (sa_done_pulse)
    );

    assign unit_done    = sa_done_pulse;
    assign sa_row_valid = sa_done_w;

    // -------------------------------------------------------------------------
    // Packed -> unpacked SRAM word conversion
    // -------------------------------------------------------------------------
    logic signed [ACT_WIDTH-1:0] weightInputRow     [SA_COLS-1:0];
    logic signed [ACT_WIDTH-1:0] activationInputCol [SA_ROWS-1:0];

    genvar gi;
    generate
        for (gi = 0; gi < SA_COLS; gi = gi + 1) begin : gen_wt_unpack
            assign weightInputRow[gi] = sa_wt_rdata[gi*ACT_WIDTH +: ACT_WIDTH];
        end
        for (gi = 0; gi < SA_ROWS; gi = gi + 1) begin : gen_act_unpack
            assign activationInputCol[gi] = sa_act_rdata[gi*ACT_WIDTH +: ACT_WIDTH];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // SA_top datapath — 16x16 weight-stationary systolic array.
    // -------------------------------------------------------------------------
    SA_top #(
        .FORMAT_BITWIDTH      (ACT_WIDTH),
        .ACCUMULATOR_BITWIDTH (ACCUM_WIDTH),
        .ARRAY_HEIGHT         (SA_ROWS),
        .ARRAY_LENGTH         (SA_COLS),
        .K_DIM                (SA_ROWS)
    ) Systolic_array (
        .clk                (clk),
        .rst                (rst),
        .start              (sa_start_w),
        .weightInputRow     (weightInputRow),
        .activationInputCol (activationInputCol),
        .MatrixMulOut       (sa_row_out),
        .load_done          (sa_load_done_w),
        .done               (sa_done_w),
        .busy               (sa_busy_w)
    );

endmodule
