// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-14
// Top-level wrapper for the weight-stationary systolic array.
// This module connects the SA controller to the MatrixMul datapath.
// The controller decides when to load weights and when activations are valid.
// weightInputRow and activationInputCol are still streamed by outside logic;
// this wrapper's job is to coordinate when those streams are considered valid
// and when the final MatrixMul result should be captured.

module SA_top #(
    parameter int FORMAT_BITWIDTH = 8,
    parameter int ACCUMULATOR_BITWIDTH = 32,
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16,
    parameter int K_DIM = 16
) (
    input logic clk,
    input logic rst,
    input logic start,

    input logic signed [FORMAT_BITWIDTH - 1 : 0] weightInputRow [ARRAY_LENGTH - 1 : 0],
    input logic signed [FORMAT_BITWIDTH - 1 : 0] activationInputCol [ARRAY_HEIGHT - 1 : 0],

    output logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] MatrixMulOut [ARRAY_LENGTH - 1 : 0],
    output logic load_done,
    output logic done,
    output logic busy
);

    // Internal control signals from the controller to the datapath.
    // We keep them local first, then expose the ones we want at the top level.
    logic loadingWeight_c;
    logic validActivations;
    logic load_done_c;
    logic controller_done_c;
    logic controller_busy_c;

    // Gated activation inputs.
    // While the controller is not in RUN, feed zeros into the array so that
    // MatrixMul only sees meaningful activations during the valid window.
    logic signed [FORMAT_BITWIDTH - 1 : 0] activationInputCol_gated [ARRAY_HEIGHT - 1 : 0];


    // MatrixMul continuously produces bottom-row outputs internally.
    // SA_top captures those values into MatrixMulOut at the correct time.
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] matrixMulOut_internal [ARRAY_LENGTH - 1 : 0];
    integer i;

    // Only let real activation data enter the array during RUN.
    // In all other phases, drive zeros so the array can load weights or drain
    // without treating random input activations as valid work.
    always_comb begin
        for (i = 0; i < ARRAY_HEIGHT; i = i + 1) begin
            if (validActivations)
                activationInputCol_gated[i] = activationInputCol[i];
            else
                activationInputCol_gated[i] = 0;
        end
    end

    // Controller instance:
    // Handles the timing of load, run, drain, and done.
    SA_Controller #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH),
        .K_DIM(K_DIM)
    ) controller (
        .clk(clk),
        .rst(rst),
        .start(start),
        .loadingWeight_c(loadingWeight_c),
        .validActivations(validActivations),
        .load_done(load_done_c),
        .done(controller_done_c),
        .busy(controller_busy_c)
    );

    // The top-level status outputs currently mirror the controller status.
    assign load_done = load_done_c;
    assign done = controller_done_c;
    assign busy = controller_busy_c;

    // Drain-phase diagonal output de-skew.
    // The array streams its bottom row out diagonally: column j becomes valid one
    // cycle after column j-1 and is then overwritten as later partial sums shift
    // down. A single-cycle capture of the whole row therefore only ever catches
    // one column (the all-zeros bug). Instead, track the drain phase and latch
    // each column at its own valid cycle, holding the assembled row until the
    // next MATMUL. validActivations is high only during RUN, so its falling edge
    // marks the first drain cycle and column j is valid on drain cycle j.
    logic valid_act_prev;
    logic in_drain;
    logic [$clog2(ARRAY_LENGTH):0] drain_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_act_prev <= 1'b0;
            in_drain       <= 1'b0;
            drain_cnt      <= '0;
        end else begin
            valid_act_prev <= validActivations;
            if (start && !busy) begin
                in_drain  <= 1'b0;
                drain_cnt <= '0;
            end else if (valid_act_prev && !validActivations) begin
                // RUN just ended -> drain begins; column 0 lands first.
                in_drain  <= 1'b1;
                drain_cnt <= '0;
            end else if (in_drain) begin
                drain_cnt <= drain_cnt + 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int col = 0; col < ARRAY_LENGTH; col = col + 1)
                MatrixMulOut[col] <= '0;
        end else if (start && !busy) begin
            for (int col = 0; col < ARRAY_LENGTH; col = col + 1)
                MatrixMulOut[col] <= '0;
        end else if (in_drain) begin
            for (int col = 0; col < ARRAY_LENGTH; col = col + 1)
                if (drain_cnt == ($clog2(ARRAY_LENGTH)+1)'(col))
                    MatrixMulOut[col] <= matrixMulOut_internal[col];
        end
    end

    // Datapath instance:
    // Uses the controller outputs to decide when weights are loaded and when
    // activations are allowed into the systolic array.
    MatrixMul #(
        .FORMAT_BITWIDTH(FORMAT_BITWIDTH),
        .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH),
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH)
    ) datapath (
        .clk(clk),
        .rst(rst),
        .loadingWeight_c(loadingWeight_c),
        .weightInputRow(weightInputRow),
        .activationInputCol(activationInputCol_gated),
        .MatrixMulOut(matrixMulOut_internal)
    );

endmodule
