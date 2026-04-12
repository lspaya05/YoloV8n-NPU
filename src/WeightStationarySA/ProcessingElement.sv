// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-12
// Weight-stationary PE that latches a weight, multiplies it with each incoming activation, and accumulates the result into a widened register while forwarding weight and activation to neighboring PEs.
// Parameters:
//     - FORMAT_BITWIDTH: Bit width of weight and activation data paths
//     - ACCUMULATOR_BITWIDTH: Bit width of accumulator data path
// Inputs:
//     - loadWeight: Load-enable; latches weightIn into internal weight register when high
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - weightIn: FORMAT_BITWIDTH-bit signed weight to load or pass through
//     - activationIn: FORMAT_BITWIDTH-bit signed activation to multiply with held weight
//     - accumlatorIn: ACCUMULATOR_BITWIDTH-bit signed partial sum input
// Outputs:
//     - weightOut: Forwarded weight to the next PE
//     - activationOut: Forwarded activation to the next PE
//     - accumlatorOut: ACCUMULATOR_BITWIDTH-bit signed accumulated MAC result
module ProcessingElement #(
    parameter int FORMAT_BITWIDTH = 8,
    parameter int ACCUMULATOR_BITWIDTH = 32 
) (
    input logic loadWeight, clk, rst,
    input logic signed [FORMAT_BITWIDTH - 1 : 0] weightIn, activationIn,
    input logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] accumlatorIn,
    output logic signed [FORMAT_BITWIDTH - 1 : 0] weightOut, activationOut,
    output logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] accumlatorOut
);
    // Multiply Output:
    parameter int MUL_OUT_BITWIDTH = 2 * FORMAT_BITWIDTH;

    //Logic variables for held weight and result
    logic signed [FORMAT_BITWIDTH - 1 : 0] weight;
    logic signed [MUL_OUT_BITWIDTH- 1 : 0] mulOut;
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] adderOut;

    //Reformatting Bits
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] adderIn1;
    assign adderIn1 = {{(ACCUMULATOR_BITWIDTH - FORMAT_BITWIDTH){mulOut[MUL_OUT_BITWIDTH - 1]}}, mulOut};

    //Arithmetic Units:
    Adder #(.BIT_WIDTH(ACCUMULATOR_BITWIDTH)) accumlate (
        .in0(accumlatorIn), .in1(adderIn1), .out(adderOut)
    );

    Multiplier #(.BIT_WIDTH_INPUT(FORMAT_BITWIDTH), .BIT_WIDTH_OUTPUT(MUL_OUT_BITWIDTH)) mul (
        .in0(weight), .in1(activationIn), .out(mulOut)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            weight <= 0;
            weightOut <= 0;
            activationOut <= 0;
            activationOut <= 0;
        end else if (loadWeight) begin
            weight <= weightIn;
            weightOut <= weightIn;
        end else begin
            accumlatorOut <= adderOut;
            activationOut <= activationIn;
        end
    end
endmodule