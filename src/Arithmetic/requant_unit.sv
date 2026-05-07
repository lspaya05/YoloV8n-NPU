// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-07
// This is the requantization unit where it takes the 32-bit partial sums from the PSB and converts them into 8-bit values for the VPU.
// The requantization process involves shifting the 32-bit values down, adding a zero point, and clamping the results to fit within the signed INT8 range of -128 to +127.
//
// This module goes after the PSB and before the VPU:
// SA -> PSB -> RequantUnit -> VPU
//
// The PSB stores INT32 partial sums. The VPU should work on INT8 values, so
// this unit converts each INT32 value into signed INT8. It first shifts the
// INT32 value down, then adds the zero point, then clamps the final value into
// the signed INT8 range of -128 to +127. If shift is 0 and zero_point is 0,
// this acts like a pure INT32-to-INT8 clamp.
//
// The input and output rows are packed instead of unpacked because these ports
// sit on the main synthesis datapath. Packed rows make the PSB -> RequantUnit
// -> VPU connection a direct bus-to-bus connection and match the packed-lane
// VPU interface. I made the decision of using packed due to STA/PPA and further synthesis concerns of the overall final system.

module requant_unit #(
    parameter int LANES = 16
) (
    input  logic [LANES*32-1:0] in_32,
    input  logic [4:0]          shift,
    input  logic signed [7:0]   zero_point,
    output logic [LANES*8-1:0]  out_8
);

    genvar lane;

    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : requant_lanes
            logic signed [31:0] lane_in;
            logic signed [31:0] shifted_value;
            logic signed [31:0] quantized_value;
            logic signed [7:0] clamped_value;

            assign lane_in = in_32[(lane*32)+31 : lane*32];

            always @(*) begin
                // Divide by a power of two while keeping the sign.
                shifted_value = lane_in >>> shift;

                // Add the zero point after shifting.
                quantized_value = shifted_value + {{24{zero_point[7]}}, zero_point};

                if (quantized_value > 32'sd127) begin
                    // Clamp values above signed INT8 range to +127.
                    clamped_value = 8'sd127;
                end else if (quantized_value < -32'sd128) begin
                    // Clamp values below signed INT8 range to -128.
                    clamped_value = -8'sd128;
                end else begin
                    // If the value already fits, keep the lower 8 bits.
                    clamped_value = quantized_value[7:0];
                end
            end

            assign out_8[(lane*8)+7 : lane*8] = clamped_value;
        end
    endgenerate

endmodule
