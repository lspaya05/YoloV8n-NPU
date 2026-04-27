// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// 32-bit registered output with enable.
// When enable is high on a clock edge, the input is captured.
// When enable is low, the previous output value is held.
// Inputs:
//     - in: 32-bit data input
//     - clk: clock input
//     - enable: capture enable
// Outputs:
//     - out: 32-bit registered output

module reg(in, out, clk, enable);
	input logic [31:0] in;
	output logic [31:0] out;
	input logic clk, enable;
	
	always_ff @(posedge clk) begin
		if (enable)
			out <= in;
	end
	
endmodule