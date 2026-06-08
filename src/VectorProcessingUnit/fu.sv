// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Functional unit for the VPE.
// Performs one of seven operations on two signed INT8 inputs based on opcode.
// Inputs:
//     - in1: first 8-bit input
//     - in2: second 8-bit input
//     - opcode: selects the operation
// Outputs:
//     - out: result of the selected operation

module fu(in1, in2, out, opcode);
    input logic [7:0] in1, in2;
    input logic [2:0] opcode;
    output logic [7:0] out;

    logic signed [7:0] a;
    logic signed [7:0] b;
    logic signed [15:0] tmp;
    logic signed [15:0] prod;

    function automatic logic signed [7:0] clamp_int8;
        input logic signed [15:0] value;
        begin
            if (value > 16'sd127)
                clamp_int8 = 8'sd127;
            else if (value < -16'sd128)
                clamp_int8 = -8'sd128;
            else
                clamp_int8 = value[7:0];
        end
    endfunction

    always_comb begin

        a = in1;
        b = in2;
        tmp = 0;
        prod = 0;

        case (opcode)
            3'b000: begin // ADD: add the two inputs
                tmp = {{8{a[7]}}, a} + {{8{b[7]}}, b};
                out = clamp_int8(tmp);
            end
            3'b001: begin // SUB: subtract second input from first
                tmp = {{8{a[7]}}, a} - {{8{b[7]}}, b};
                out = clamp_int8(tmp);
            end
            3'b010: begin // MUL: multiply then shift right by 7 bits
                prod = a * b;
                out = clamp_int8(prod >>> 7);
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
                if (a == -8'sd128)
                    out = 8'sd127;
                else if (a[7])
                    out = -a;
                else
                    out = a;
            end
            default: begin
                out = 8'h00;
            end
        endcase
    end

endmodule
