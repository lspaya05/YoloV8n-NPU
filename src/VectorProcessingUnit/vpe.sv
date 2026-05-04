// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Vector Processing Element (VPE).
//
// Datapath matches the VPE block diagram:
//     - left operand MUX selects either the lane input or Data-H from the right neighbor
//     - right operand MUX selects either the second lane input or the local register
//     - FU performs the decoded vector operation
//     - local register stores FU results for feedback/reuse
//     - output MUX selects either the current FU result or the local register
// The parent VPU decodes ISA opcodes and drives these control signals.

module vpe (
    input  logic        clk,
    input  logic        rst,
    input  logic        left_mux_select,
    input  logic        right_mux_select,
    input  logic        output_mux_select,
    input  logic        register_enable,
    input  logic [2:0]  fu_opcode,
    input  logic [31:0] in_a,
    input  logic [31:0] in_b,
    input  logic [31:0] data_h_in,
    output logic [31:0] out
);

    logic [31:0] left_operand;
    logic [31:0] right_operand;
    logic [31:0] fu_out;
    logic [31:0] register_out;

    mux2to1 left_operand_mux (
        .d0(in_a),
        .d1(data_h_in),
        .select(left_mux_select),
        .y(left_operand)
    );

    mux2to1 right_operand_mux (
        .d0(in_b),
        .d1(register_out),
        .select(right_mux_select),
        .y(right_operand)
    );

    fu functional_unit (
        .in1(left_operand),
        .in2(right_operand),
        .out(fu_out),
        .opcode(fu_opcode)
    );

    vpe_reg local_register (
        .in(fu_out),
        .out(register_out),
        .clk(clk),
        .enable(register_enable),
        .rst(rst)
    );

    mux2to1 output_mux (
        .d0(fu_out),
        .d1(register_out),
        .select(output_mux_select),
        .y(out)
    );

endmodule
