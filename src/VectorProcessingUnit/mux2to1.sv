// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// 32-bit two-input MUX. Selects one of two 32-bit inputs and forwards it to the output.
// Inputs:
//     - d0: first data input
//     - d1: second data input
//     - select: choose d1 when high, otherwise choose d0
// Outputs:
//     - y: selected 32-bit output

module mux2to1(d0, d1, select, y);
	input logic [31:0] d0, d1;
	input logic select;
	output logic [31:0] y;
	
	assign y = select ? d1 : d0;
	
endmodule