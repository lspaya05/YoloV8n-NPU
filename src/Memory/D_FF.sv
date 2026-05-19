// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-15
// BIT_WIDTH-wide D flip-flop with synchronous active-high reset; building block for RegisterChain delay stages.
// Parameters:
//     - BIT_WIDTH: data path width in bits
// Inputs:
//     - clk: system clock
//     - rst: active-high synchronous reset
//     - in: data input, BIT_WIDTH bits wide
// Outputs:
//     - out: registered output, captures `in` one cycle later
module D_FF # (
    parameter int BIT_WIDTH
) (
    input logic clk, rst,
    input logic [BIT_WIDTH - 1 : 0] in,
    output logic [BIT_WIDTH - 1 : 0] out
);

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= '0;
        end else begin
            out <= in;   
        end
    end
endmodule
