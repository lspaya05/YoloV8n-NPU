// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-15
// Parameterized combinational signed multiplier targeting the DSP58 slice on the
// AMD Kria KR260 (Zynq UltraScale+ MPSoC).
//
// To verify DSP inference after synthesis:
//     report_utilization -hierarchical -file util.rpt
//     report_dsp -file dsp.rpt
//
// Parameters:
//     - BIT_WIDTH_INPUT:  Bit width of each signed input operand
//     - BIT_WIDTH_OUTPUT: Bit width of the signed product output (must be 2*BIT_WIDTH_INPUT)
// Inputs:
//     - in0: First signed operand
//     - in1: Second signed operand
// Outputs:
//     - out: Combinational signed product
module Multiplier #(
    parameter int BIT_WIDTH_INPUT  = 8,
    parameter int BIT_WIDTH_OUTPUT = 16  // must equal 2 * BIT_WIDTH_INPUT
) (
    input  logic signed [BIT_WIDTH_INPUT-1:0]  in0, in1,
    output logic signed [BIT_WIDTH_OUTPUT-1:0] out
);
    // (* use_dsp = "yes" *) forces Vivado to infer a DSP58 slice. Without it,
    // Vivado may choose LUT fabric for small operand widths. [UG901 §"use_dsp"]
    // Explicit cast to BIT_WIDTH_OUTPUT prevents silent MSB truncation of the
    // full-width product. [IEEE 1800-2017 §6.24.1]
    (* use_dsp = "yes" *)
    assign out = BIT_WIDTH_OUTPUT'(in0 * in1);
endmodule
