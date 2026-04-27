// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Functional unit for the VPE.
// Performs one of seven operations on two 32-bit inputs based on opcode.
// Inputs:
//     - in1: first 32-bit input
//     - in2: second 32-bit input
//     - opcode: selects the operation
// Outputs:
//     - out: result of the selected operation

module fu(in1, in2, out, opcode);
    input logic [31:0] in1, in2;
    input logic [2:0] opcode;
    output logic [31:0] out;

    logic signed [31:0] a;
    logic signed [31:0] b;
    logic signed [32:0] tmp;
    logic signed [63:0] prod;

    always_comb begin

        a = in1;
        b = in2;
        tmp = 0;
        prod = 0;

        case (opcode)
            3'b000: begin // ADD: add the two inputs
                out = a + b;
            end
            3'b001: begin // SUB: subtract second input from first
                out = a - b;
            end
            3'b010: begin // MUL: multiply then shift right by 8 bits
                prod = a * b;
                out = prod >>> 8;
            end
            3'b011: begin // MAX: choose the larger input
                if (a > b)
                    out = in1;
                else
                    out = in2;
            end
            3'b100: begin // MIN: choose the smaller input
                if (a < b)
                    out = in1;
                else
                    out = in2;
            end
            3'b101: begin // SEL: choose in1 when b[0] is 1, otherwise choose in2
                if (b[0])
                    out = in1;
                else
                    out = in2;
            end
            3'b110: begin // ABS: output the absolute value of the first input
                if (a[31])
                    out = -a;
                else
                    out = a;
            end
            default: begin
                out = 32'h00000000;
            end
        endcase
    end

endmodule