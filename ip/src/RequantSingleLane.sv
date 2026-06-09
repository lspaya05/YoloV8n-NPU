// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-18
// 4-stage pipelined requantization lane. Implements bias-add, multiply-by-M0,
// arithmetic shift, and saturating clamp for one INT32 data lane.
// All mode muxing (sign-extension, bias gating, B-operand zeroing) is done
// upstream in RequantPipeline; this module is mode-agnostic.
// Parameters:
//     - M0_WIDTH:    Bit width of the M0 scale factor (INT32 signed)
//     - SHIFT_WIDTH: Bit width of the shift amount n
// Inputs:
//     - clk, rst:      Clock and active-high synchronous reset
//     - valid_i:       Input data valid
//     - operand_a_i:   INT32 operand A (PSB value or sign-extended INT8)
//     - operand_b_i:   INT32 operand B (sign-extended INT8 for BINARY_ADD, else 0)
//     - bias_i:        INT32 bias (non-zero only for FROM_PSB mode)
//     - m0_a_i, n_a_i: Per-channel scale and shift for operand A
//     - m0_b_i, n_b_i: Per-channel scale and shift for operand B
// Outputs:
//     - data_o:  Clamped INT8 result (4 cycles after valid_i)
//     - valid_o: Output data valid

module RequantSingleLane #(
    parameter int M0_WIDTH    = 32,
    parameter int SHIFT_WIDTH = 8
) (
    input  logic                          clk,
    input  logic                          rst,
    input  logic                          valid_i,
    input  logic signed [31:0]            operand_a_i,
    input  logic signed [31:0]            operand_b_i,
    input  logic signed [31:0]            bias_i,
    input  logic signed [M0_WIDTH-1:0]    m0_a_i,
    input  logic        [SHIFT_WIDTH-1:0] n_a_i,
    input  logic signed [M0_WIDTH-1:0]    m0_b_i,
    input  logic        [SHIFT_WIDTH-1:0] n_b_i,
    output logic signed [7:0]             data_o,
    output logic                          valid_o
);

    localparam int ProdW  = 2 * M0_WIDTH;      // 64-bit product
    localparam int TotalW = ProdW + 1;          // 65-bit sum (prevents overflow)

    // Stage 0 — Input Registration
    logic signed [31:0]            op_a_s0, op_b_s0, bias_s0;
    logic signed [M0_WIDTH-1:0]    m0_a_s0, m0_b_s0;
    logic        [SHIFT_WIDTH-1:0] n_a_s0, n_b_s0;
    logic                          valid_s0;

    always_ff @(posedge clk) begin
        if (rst) begin
            op_a_s0  <= '0; op_b_s0  <= '0; bias_s0  <= '0;
            m0_a_s0  <= '0; m0_b_s0  <= '0;
            n_a_s0   <= '0; n_b_s0   <= '0;
            valid_s0 <= 1'b0;
        end else begin
            op_a_s0  <= operand_a_i;
            op_b_s0  <= operand_b_i;
            bias_s0  <= bias_i;
            m0_a_s0  <= m0_a_i;
            m0_b_s0  <= m0_b_i;
            n_a_s0   <= n_a_i;
            n_b_s0   <= n_b_i;
            valid_s0 <= valid_i;
        end
    end

    // Stage 1 — Bias Add
    // Adds bias_i to operand A. For FROM_SRAM and BINARY_ADD, bias_i = 0 (no-op).
    logic signed [31:0]            biased_a_s1, op_b_s1;
    logic signed [M0_WIDTH-1:0]    m0_a_s1, m0_b_s1;
    logic        [SHIFT_WIDTH-1:0] n_a_s1, n_b_s1;
    logic                          valid_s1;

    logic signed [31:0] bias_add_out;
    Adder #(.BIT_WIDTH(32)) u_bias_add (
        .in0(op_a_s0),
        .in1(bias_s0),
        .out(bias_add_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            biased_a_s1 <= '0; op_b_s1 <= '0;
            m0_a_s1     <= '0; m0_b_s1 <= '0;
            n_a_s1      <= '0; n_b_s1  <= '0;
            valid_s1    <= 1'b0;
        end else begin
            biased_a_s1 <= bias_add_out;
            op_b_s1     <= op_b_s0;
            m0_a_s1     <= m0_a_s0;
            m0_b_s1     <= m0_b_s0;
            n_a_s1      <= n_a_s0;
            n_b_s1      <= n_b_s0;
            valid_s1    <= valid_s0;
        end
    end

    // Stage 2 — Multiply
    // Scales A and B by their M0 factors. B product is 0 when m0_b = 0.
    logic signed [ProdW-1:0]       prod_a_s2, prod_b_s2;
    logic        [SHIFT_WIDTH-1:0] n_a_s2, n_b_s2;
    logic                          valid_s2;

    logic signed [ProdW-1:0] mul_a_out, mul_b_out;
    Multiplier #(
        .BIT_WIDTH_INPUT (M0_WIDTH),
        .BIT_WIDTH_OUTPUT(ProdW)
    ) u_mul_a (
        .in0(biased_a_s1),
        .in1(m0_a_s1),
        .out(mul_a_out)
    );
    Multiplier #(
        .BIT_WIDTH_INPUT (M0_WIDTH),
        .BIT_WIDTH_OUTPUT(ProdW)
    ) u_mul_b (
        .in0(op_b_s1),
        .in1(m0_b_s1),
        .out(mul_b_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            prod_a_s2 <= '0; prod_b_s2 <= '0;
            n_a_s2    <= '0; n_b_s2    <= '0;
            valid_s2  <= 1'b0;
        end else begin
            prod_a_s2 <= mul_a_out;
            prod_b_s2 <= mul_b_out;
            n_a_s2    <= n_a_s1;
            n_b_s2    <= n_b_s1;
            valid_s2  <= valid_s1;
        end
    end

    // Stage 3 — Arithmetic Right Shift
    // Shifts each product down by the per-channel factor n (typically ~31 for Q31 M0).
    logic signed [ProdW-1:0] int_a_s3, int_b_s3;
    logic                      valid_s3;

    always_ff @(posedge clk) begin
        if (rst) begin
            int_a_s3 <= '0; int_b_s3 <= '0;
            valid_s3 <= 1'b0;
        end else begin
            int_a_s3 <= prod_a_s2 >>> n_a_s2;
            int_b_s3 <= prod_b_s2 >>> n_b_s2;
            valid_s3 <= valid_s2;
        end
    end

    // Stage 4 — Sum and Clamp
    // Sums A and B intermediates then saturates to signed INT8 [-128, 127].
    // For non-BINARY_ADD modes int_b_s3 = 0 so the sum equals int_a_s3.
    logic signed [TotalW-1:0] total_s4;
    assign total_s4 = TotalW'(signed'(int_a_s3)) + TotalW'(signed'(int_b_s3));

    always_ff @(posedge clk) begin
        if (rst) begin
            data_o  <= '0;
            valid_o <= 1'b0;
        end else begin
            if      (total_s4 > 127)  data_o <= 8'sd127;
            else if (total_s4 < -128) data_o <= -8'sd128;
            else                      data_o <= total_s4[7:0];
            valid_o <= valid_s3;
        end
    end

endmodule
