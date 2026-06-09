// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-03
// This is the Vector Processing Unit (VPU) which contains 16 parallel Vector Processing Elements (VPEs). 
// Each VPE can perform one of seven operations on two signed INT8 inputs, as well as a reduction operation that combines the current 
// lane's saved register value with the right neighbor's saved register value. The VPU also supports a HOLD instruction that forwards 
// each lane's saved register value without updating it.
// Each VPE produces an 8-bit result. Requantization is handled
// outside the VPU by the requantunit, so the data path can be:
// SA -> PSB -> RequantUnit -> VPU.

module vpu #(
    parameter int LANES = 16             // Number of parallel VPE lanes in the VPU.
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  enable,             // Allows instructions to update the VPE registers.
    input  logic [7:0]            opcode,             // Full 8-bit ISA opcode from the control unit.
    input  logic                  reduce_max,         // Selects max reduction instead of sum reduction for REDUCE.
    input  logic [LANES*8-1:0]    in_a,               // Packed 8-bit input A values for all lanes.
    input  logic [LANES*8-1:0]    in_b,               // Packed 8-bit input B values for all lanes.
    input  logic [7:0]            data_h_edge,        // Data-H input for the rightmost lane.
    output logic [LANES*8-1:0]    out,                // Packed 8-bit outputs from all VPE lanes.
    output logic                  valid_opcode        // Goes low when the opcode is not supported here.
);

    // Local opcode names make the decoder easier to read than raw hex values.
    localparam logic [7:0] OPCODE_VADD    = 8'h20;
    localparam logic [7:0] OPCODE_VSUB    = 8'h21;
    localparam logic [7:0] OPCODE_VMUL    = 8'h22;
    localparam logic [7:0] OPCODE_VMAX    = 8'h23;
    localparam logic [7:0] OPCODE_VMIN    = 8'h24;
    localparam logic [7:0] OPCODE_VSEL    = 8'h25;
    localparam logic [7:0] OPCODE_VABS    = 8'h26;
    localparam logic [7:0] OPCODE_REDUCE  = 8'h40;
    localparam logic [7:0] OPCODE_HOLD    = 8'h52;

    logic       left_mux_select;    // Selects in_a or Data-H for the left FU input.
    logic       right_mux_select;   // Selects in_b or the local VPE register for the right FU input.
    logic       output_mux_select;  // Selects FU output or local VPE register for lane output.
    logic       register_enable;    // Enables the internal register in every VPE lane.
    logic [2:0] fu_opcode;          // Smaller opcode used directly by the FU.

    genvar lane;

    // A simple decoder maps opcodes to VPE mux selects and control signals.
    // The same decoded controls are broadcast to every lane.
    always_comb begin
        left_mux_select   = 1'b0;      // 0: in_a,        1: right-neighbor Data-H
        right_mux_select  = 1'b0;      // 0: in_b,        1: local VPE register
        output_mux_select = 1'b0;      // 0: FU result,   1: local VPE register
        register_enable   = 1'b0;      // Default is to hold each VPE register.
        fu_opcode         = opcode[2:0]; // Vector opcodes 0x20-0x26 use the low 3 bits.
        valid_opcode      = 1'b1;      // Assume valid unless the case statement says otherwise.

        case (opcode)
            OPCODE_VADD,
            OPCODE_VSUB,
            OPCODE_VMUL,
            OPCODE_VMAX,
            OPCODE_VMIN,
            OPCODE_VSEL,
            OPCODE_VABS: begin
                // Normal vector operations use in_a and in_b, then save the FU result.
                register_enable = enable;
            end

            OPCODE_REDUCE: begin
                // Reduction combines Data-H with the saved local register value.
                left_mux_select  = 1'b1;
                right_mux_select = 1'b1;
                register_enable  = enable;
                fu_opcode        = reduce_max ? 3'b011 : 3'b000;
            end

            OPCODE_HOLD: begin
                // HOLD forwards each lane's saved register value without updating it.
                output_mux_select = 1'b1;
            end

            default: begin
                // Unsupported opcodes do not update the VPE registers.
                valid_opcode = 1'b0;
            end
        endcase
    end

    /* verilator lint_off UNOPTFLAT */
    logic [7:0] lane_outs [LANES]; // acyclic chain; Verilator can't prove it across a generate loop
    /* verilator lint_on UNOPTFLAT */

    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : gen_vpe_lanes
            logic [7:0] lane_in_a;
            logic [7:0] lane_in_b;
            logic [7:0] lane_data_h;

            assign lane_in_a = in_a[(lane*8)+7 : lane*8];
            assign lane_in_b = in_b[(lane*8)+7 : lane*8];

            if (lane == LANES-1) begin : gen_right_edge
                assign lane_data_h = data_h_edge;
            end else begin : gen_right_neighbor
                assign lane_data_h = lane_outs[lane+1];
            end

            vpe lane_vpe (
                .clk(clk),
                .rst(rst),
                .left_mux_select(left_mux_select),
                .right_mux_select(right_mux_select),
                .output_mux_select(output_mux_select),
                .register_enable(register_enable),
                .fu_opcode(fu_opcode),
                .in_a(lane_in_a),
                .in_b(lane_in_b),
                .data_h_in(lane_data_h),
                .out(lane_outs[lane])
            );
        end
    endgenerate

    genvar k;
    generate
        for (k = 0; k < LANES; k = k + 1) begin : gen_pack_out
            assign out[k*8 +: 8] = lane_outs[k];
        end
    endgenerate

endmodule
