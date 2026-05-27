// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// Top-level requantization pipeline. Supports three modes selected by mode_i:
//   2'b00  FROM_SRAM    — INT8 SRAM tensor rescaled to a new output scale
//   2'b01  FROM_PSB     — INT32 PSB accumulator path (conv/linear output)
//   2'b10  BINARY_ADD   — two INT8 SRAM tensors independently scaled then summed
//
// 16-lane datapath. One PSB row (16 x INT32) feeds Lanes RequantSingleLane
// instances directly; ChCount = 1 means one (M0, n) pair drives all lanes.
// Mode-specific input muxing (sign-extension, bias gating) is done here so
// each lane remains mode-agnostic.
//
// Parameters:
//     - Lanes:      Number of parallel lanes (= VPU_LANES = 16)
//     - ChCount:    Channel groups per beat (= 1, one M0/n pair per beat)
//     - M0Width:    Bit width of M0 scale factor (INT32 signed)
//     - ShiftWidth: Bit width of shift amount n
// Inputs:
//     - clk, rst:        Clock and active-high synchronous reset
//     - mode_i:          2-bit mode select (see above)
//     - psb_row_i:       16-lane INT32 row from PSB (FROM_PSB mode)
//     - psb_row_valid_i: PSB row valid strobe
//     - sram_a_i:        16-lane packed INT8 operand A (FROM_SRAM / BINARY_ADD)
//     - sram_a_valid_i:  Operand A valid
//     - sram_b_i:        16-lane packed INT8 operand B (BINARY_ADD only)
//     - bias_i:          1 x INT32 bias (FROM_PSB)
//     - m0_a_i:          1 x M0 scale for operand A
//     - n_a_i:           1 x shift for operand A
//     - m0_b_i:          1 x M0 scale for operand B (BINARY_ADD; tie 0 otherwise)
//     - n_b_i:           1 x shift for operand B
// Outputs:
//     - data_o:   16-lane packed INT8 result
//     - valid_o:  Output valid (5-cycle pipeline latency from lane valid_i)

module RequantPipeline #(
    parameter int Lanes      = 16,
    parameter int ChCount    = 1,
    parameter int M0Width    = 32,
    parameter int ShiftWidth = 8
) (
    input  logic                          clk,
    input  logic                          rst,
    input  logic [1:0]                    mode_i,

    // FROM_PSB source — 16-lane INT32 row from PSB
    input  logic [15:0][31:0]             psb_row_i,
    input  logic                          psb_row_valid_i,

    // FROM_SRAM / BINARY_ADD sources — Lanes packed INT8
    input  logic [Lanes*8-1:0]            sram_a_i,
    input  logic                          sram_a_valid_i,
    input  logic [Lanes*8-1:0]            sram_b_i,

    // Per-channel parameters — ChCount sets (= 1 in 16-lane build)
    input  logic [ChCount*32-1:0]         bias_i,
    input  logic [ChCount*M0Width-1:0]    m0_a_i,
    input  logic [ChCount*ShiftWidth-1:0] n_a_i,
    input  logic [ChCount*M0Width-1:0]    m0_b_i,
    input  logic [ChCount*ShiftWidth-1:0] n_b_i,

    output logic [Lanes*8-1:0]            data_o,
    output logic                          valid_o
);

    localparam int LanesPerCh = Lanes / ChCount;

    // Input mux and sign extension
    logic signed [31:0] lane_op_a [Lanes-1:0];
    logic signed [31:0] lane_op_b [Lanes-1:0];
    logic signed [31:0] lane_bias [Lanes-1:0];
    logic               lane_valid_i;

    always_comb begin
        lane_valid_i = 1'b0;
        unique case (mode_i)
            2'b01:   lane_valid_i = psb_row_valid_i;
            2'b00:   lane_valid_i = sram_a_valid_i;
            2'b10:   lane_valid_i = sram_a_valid_i;
            default: lane_valid_i = 1'b0;
        endcase

        for (int i = 0; i < Lanes; i++) begin
            automatic int ch = i / LanesPerCh;
            unique case (mode_i)
                2'b01: begin  // FROM_PSB: INT32 directly from psb_row_i + bias
                    lane_op_a[i] = signed'(psb_row_i[i]);
                    lane_op_b[i] = '0;
                    lane_bias[i] = signed'(bias_i[ch*32 +: 32]);
                end
                2'b00: begin  // FROM_SRAM: sign-extend INT8, no bias
                    lane_op_a[i] = 32'(signed'(sram_a_i[i*8 +: 8]));
                    lane_op_b[i] = '0;
                    lane_bias[i] = '0;
                end
                2'b10: begin  // BINARY_ADD: two sign-extended INT8 operands
                    lane_op_a[i] = 32'(signed'(sram_a_i[i*8 +: 8]));
                    lane_op_b[i] = 32'(signed'(sram_b_i[i*8 +: 8]));
                    lane_bias[i] = '0;
                end
                default: begin
                    lane_op_a[i] = '0;
                    lane_op_b[i] = '0;
                    lane_bias[i] = '0;
                end
            endcase
        end
    end

    // Parameter replication: each lane inherits params from its channel group
    logic signed [M0Width-1:0]    lane_m0_a [Lanes-1:0];
    logic        [ShiftWidth-1:0] lane_n_a  [Lanes-1:0];
    logic signed [M0Width-1:0]    lane_m0_b [Lanes-1:0];
    logic        [ShiftWidth-1:0] lane_n_b  [Lanes-1:0];

    genvar gi;
    generate
        for (gi = 0; gi < Lanes; gi++) begin : gen_param_rep
            localparam int Ch = gi / LanesPerCh;
            assign lane_m0_a[gi] = signed'(m0_a_i[Ch*M0Width    +: M0Width]);
            assign lane_n_a[gi]  =         n_a_i [Ch*ShiftWidth  +: ShiftWidth];
            assign lane_m0_b[gi] = signed'(m0_b_i[Ch*M0Width    +: M0Width]);
            assign lane_n_b[gi]  =         n_b_i [Ch*ShiftWidth  +: ShiftWidth];
        end
    endgenerate

    // Single-lane pipelines
    logic signed [7:0] lane_data_o [Lanes-1:0];
    logic              lane_valid_o [Lanes-1:0];

    genvar i;
    generate
        for (i = 0; i < Lanes; i++) begin : gen_lane
            RequantSingleLane #(
                .M0_WIDTH   (M0Width),
                .SHIFT_WIDTH(ShiftWidth)
            ) u_lane (
                .clk         (clk),
                .rst         (rst),
                .valid_i     (lane_valid_i),
                .operand_a_i (lane_op_a[i]),
                .operand_b_i (lane_op_b[i]),
                .bias_i      (lane_bias[i]),
                .m0_a_i      (lane_m0_a[i]),
                .n_a_i       (lane_n_a[i]),
                .m0_b_i      (lane_m0_b[i]),
                .n_b_i       (lane_n_b[i]),
                .data_o      (lane_data_o[i]),
                .valid_o     (lane_valid_o[i])
            );
        end
    endgenerate

    // Output pack
    genvar j;
    generate
        for (j = 0; j < Lanes; j++) begin : gen_out_pack
            assign data_o[j*8 +: 8] = lane_data_o[j];
        end
    endgenerate
    assign valid_o = lane_valid_o[0];

endmodule
