// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Parameterized two-input MUX. Selects one of two inputs and forwards it to the output.
// Inputs:
//     - d0: first data input
//     - d1: second data input
//     - select: choose d1 when high, otherwise choose d0
// Outputs:
//     - y: selected output

module mux2to1 #(parameter int BIT_WIDTH = 8) (d0, d1, select, y);
	input logic [BIT_WIDTH - 1:0] d0, d1;
	input logic select;
	output logic [BIT_WIDTH - 1:0] y;
	
	assign y = select ? d1 : d0;
	
endmodule
