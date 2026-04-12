// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-11
// Parameterized signed adder for accumulation in the systolic array PE. Used throughout
// the systolic array; easily swapped if targeting silicon.
// Parameters:
//     - BIT_WIDTH_INPUT: Bit width of each input operand
//     - BIT_WIDTH_OUTPUT: Bit width of the output sum
// Inputs:
//     - in0: First signed operand (BIT_WIDTH_INPUT bits)
//     - in1: Second signed operand (BIT_WIDTH_INPUT bits)
// Outputs:
//     - out: Sum of in0 and in1 (BIT_WIDTH_OUTPUT bits)
module Adder #(
    parameter int BIT_WIDTH = 8
) (
    input logic signed [BIT_WIDTH - 1 : 0] in0, in1,
    output logic signed [BIT_WIDTH - 1 : 0] out
);
    assign out = in0 + in1;
endmodule 