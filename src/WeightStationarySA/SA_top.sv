// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-14
// Top-level wrapper for the weight-stationary systolic array.
// This module connects the SA controller to the MatrixMul datapath.
// The controller decides when to load weights and when activations are valid.
// Still a work in progress, but pushing the basic structure on for now so that we can start integrating and testing the pieces together.

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

    output logic [ACCUMULATOR_BITWIDTH - 1 : 0] MatrixMulOut [ARRAY_LENGTH - 1 : 0],
    output logic load_done,
    output logic done,
    output logic busy
);

    // Internal control signals from the controller to the datapath.
    logic loadingWeight_c;
    logic validActivations;

    // Gated activation inputs.
    // While the controller is not in RUN, feed zeros into the array so that
    // MatrixMul only sees meaningful activations during the valid window.
    logic signed [FORMAT_BITWIDTH - 1 : 0] activationInputCol_gated [ARRAY_HEIGHT - 1 : 0];

    integer i;
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
        .load_done(load_done),
        .done(done),
        .busy(busy)
    );

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
        .MatrixMulOut(MatrixMulOut)
    );

endmodule
