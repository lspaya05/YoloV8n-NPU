// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Parameterized registered output with enable.
// When enable is high on a clock edge, the input is captured.
// When enable is low, the previous output value is held.
// Inputs:
//     - in: data input
//     - clk: clock input
//     - enable: capture enable
// Outputs:
//     - out: registered output

module vpe_reg #(parameter int BIT_WIDTH = 8) (in, out, clk, enable, rst);
	input logic [BIT_WIDTH - 1:0] in;
	output logic [BIT_WIDTH - 1:0] out;
	input logic clk, enable, rst;
	
	always_ff @(posedge clk) begin
		if (rst)
            out <= '0;
        else if (enable)
            out <= in;
	end
	
endmodule
