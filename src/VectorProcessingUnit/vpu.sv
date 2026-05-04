// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-03
// Vector Processing Unit (VPU).
//
// The VPU owns ISA opcode decode and broadcasts decoded lane controls to
// 16 VPE lanes. Each VPE produces a 32-bit result. The VPU also provides a
// simple requantization path from signed 32-bit lane values to signed INT8
// values using arithmetic right shift and saturation.

module vpu #(
    parameter int LANES = 16             // Number of parallel VPE lanes in the VPU.
) (
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  enable,             // Allows instructions to update the VPE registers.
    input  logic [7:0]            opcode,             // Full 8-bit ISA opcode from the control unit.
    input  logic                  reduce_max,         // Selects max reduction instead of sum reduction for REDUCE.
    input  logic [4:0]            requant_shift,      // Amount to right shift before clamping to INT8.
    input  logic signed [7:0]     requant_zero_point, // Offset added during requantization.
    input  logic [LANES*32-1:0]   in_a,               // Packed 32-bit input A values for all lanes.
    input  logic [LANES*32-1:0]   in_b,               // Packed 32-bit input B values for all lanes.
    input  logic [31:0]           data_h_edge,        // Data-H input for the rightmost lane.
    output logic [LANES*32-1:0]   out_32,             // Packed 32-bit outputs from all VPE lanes.
    output logic [LANES*8-1:0]    out_8,              // Packed 8-bit requantized outputs from all lanes.
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
    localparam logic [7:0] OPCODE_REQUANT = 8'h28;
    localparam logic [7:0] OPCODE_REDUCE  = 8'h40;
    localparam logic [7:0] OPCODE_HOLD    = 8'h52;

    logic       left_mux_select;    // Selects in_a or Data-H for the left FU input.
    logic       right_mux_select;   // Selects in_b or the local VPE register for the right FU input.
    logic       output_mux_select;  // Selects FU output or local VPE register for lane output.
    logic       register_enable;    // Enables the internal register in every VPE lane.
    logic [2:0] fu_opcode;          // Smaller opcode used directly by the FU.
    logic       requant_from_input; // Selects whether requantization uses in_a or lane_out.

    genvar lane;

    // A simple decoder maps opcodes to VPE mux selects and control signals.
    // The same decoded controls are broadcast to every lane.
    always_comb begin
        left_mux_select   = 1'b0;      // 0: in_a,        1: right-neighbor Data-H
        right_mux_select  = 1'b0;      // 0: in_b,        1: local VPE register
        output_mux_select = 1'b0;      // 0: FU result,   1: local VPE register
        register_enable   = 1'b0;      // Default is to hold each VPE register.
        fu_opcode         = opcode[2:0]; // Vector opcodes 0x20-0x26 use the low 3 bits.
        requant_from_input = 1'b0;     // Default requantizes the VPE lane output.
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

            OPCODE_REQUANT: begin
                // Requantization consumes signed 32-bit accumulator values directly.
                // The VPE registers are held because the VPE FU is not needed here.
                requant_from_input = 1'b1;
                fu_opcode = 3'b000;
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

    // Generate the VPU lanes. Each lane has one VPE instance.
    // The rightmost lane takes Data-H from data_h_edge, while all other
    // lanes take Data-H from the output of the lane to their right.
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : vpe_lanes
            logic [31:0] lane_in_a;
            logic [31:0] lane_in_b;
            logic [31:0] lane_data_h;
            logic [31:0] lane_out;
            logic signed [31:0] requant_source;
            logic signed [31:0] shifted_value;
            logic signed [31:0] biased_value;
            logic signed [7:0] clamped_value;

            // Pick this lane's 32-bit value out of the packed input buses.
            assign lane_in_a = in_a[(lane*32)+31 : lane*32];
            assign lane_in_b = in_b[(lane*32)+31 : lane*32];

            if (lane == LANES-1) begin : right_edge
                // The rightmost lane has no right neighbor, so it uses the edge input.
                assign lane_data_h = data_h_edge;
            end else begin : right_neighbor
                // Other lanes receive Data-H from the VPE immediately to the right.
                assign lane_data_h = out_32[((lane+1)*32)+31 : (lane+1)*32];
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
                .out(lane_out)
            );

            // Put this lane's 32-bit result back into the packed output bus.
            assign out_32[(lane*32)+31 : lane*32] = lane_out;

            // Requantize from in_a for OPCODE_REQUANT, otherwise requantize lane_out.
            assign requant_source = requant_from_input ? lane_in_a : lane_out;

            always @(*) begin
                // Divide by a power of two while keeping the sign.
                shifted_value = requant_source >>> requant_shift;

                // Add the zero point after shifting.
                biased_value = shifted_value + {{24{requant_zero_point[7]}}, requant_zero_point};

                if (biased_value > 32'sd127) begin
                    // Clamp values above signed INT8 range to +127.
                    clamped_value = 8'sd127;
                end else if (biased_value < -32'sd128) begin
                    // Clamp values below signed INT8 range to -128.
                    clamped_value = -8'sd128;
                end else begin
                    // If the value already fits, keep the lower 8 bits.
                    clamped_value = biased_value[7:0];
                end
            end

            // Put this lane's 8-bit result into the packed INT8 output bus.
            assign out_8[(lane*8)+7 : lane*8] = clamped_value;
        end
    endgenerate

endmodule
