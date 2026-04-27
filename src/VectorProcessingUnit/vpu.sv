module vpu();
    input [31:0] in_from_sa, ; // Input from the systolic array
    input [3:0] opcode; // Operation code to select the function
    input rst, clk; // Clock signal

endmodule