// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-27
// Vector Processing Element (VPE).
//
// Datapath matches the VPE block diagram:
//     - left operand MUX selects either the lane input or Data-H from the left neighbor
//     - right operand MUX selects either the second lane input or the local register
//     - FU performs the decoded vector operation
//     - local register stores FU results for feedback/reuse
//     - output MUX selects either the current FU result or the local register
//
// Supported instruction opcodes:
//     - 8'h20: VADD
//     - 8'h21: VSUB
//     - 8'h22: VMUL
//     - 8'h23: VMAX
//     - 8'h24: VMIN
//     - 8'h25: VSEL
//     - 8'h26: VABS
//     - 8'h40: REDUCE, using data_h_in and reg_out
//     - 8'h52: HOLD, forwards reg_out without updating it

module vpe (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    input  logic [7:0]  opcode,
    input  logic        reduce_max,
    input  logic [31:0] in_a,
    input  logic [31:0] in_b,
    input  logic [31:0] data_h_in,
    output logic [31:0] out,
    output logic        valid_opcode
);

    logic        left_mux_select;
    logic        right_mux_select;
    logic        output_mux_select;
    logic        register_enable;
    logic [2:0]  fu_opcode;
    logic [31:0] left_operand;
    logic [31:0] right_operand;
    logic [31:0] fu_out;
    logic [31:0] register_out;

    // Opcode decoder. Normal SIMD opcodes 8'h20-8'h26 use their low
    // three bits as the FU opcode.
    always_comb begin
        left_mux_select   = 1'b0;   // 0: in_a,   1: data_h_in
        right_mux_select  = 1'b0;   // 0: in_b,   1: register_out
        output_mux_select = 1'b0;   // 0: fu_out,  1: register_out
        register_enable   = 1'b0;
        fu_opcode         = opcode[2:0];
        valid_opcode      = 1'b1;

        case (opcode)
            8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h25, 8'h26: begin
                left_mux_select   = 1'b0;
                right_mux_select  = 1'b0;
                output_mux_select = 1'b0;
                register_enable   = enable;
            end

            8'h40: begin // REDUCE: data_h_in + reg_out, or max(data_h_in, reg_out)
                left_mux_select   = 1'b1;
                right_mux_select  = 1'b1;
                output_mux_select = 1'b0;
                register_enable   = enable;
                fu_opcode         = reduce_max ? 3'b011 : 3'b000;
            end

            8'h52: begin // HOLD: pass through the last registered value
                left_mux_select   = 1'b0;
                right_mux_select  = 1'b0;
                output_mux_select = 1'b1;
                register_enable   = 1'b0;
            end

            default: begin
                valid_opcode = 1'b0;
            end
        endcase
    end

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

    always_ff @(posedge clk) begin
        if (rst)
            register_out <= 32'h00000000;
        else if (register_enable)
            register_out <= fu_out;
    end

    mux2to1 output_mux (
        .d0(fu_out),
        .d1(register_out),
        .select(output_mux_select),
        .y(out)
    );

endmodule
