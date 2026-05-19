// Name: Leonard Paya, Bernardo Lin
// Date: 2026-04-15
// Chains CHAIN_LENGTH D flip-flops to skew a BIT_WIDTH-wide signal by CHAIN_LENGTH cycles; used to stagger weight/activation inputs across systolic array rows/columns.
// Parameters:
//     - CHAIN_LENGTH: number of pipeline delay stages
//     - BIT_WIDTH: data path width in bits
// Inputs:
//     - clk: system clock
//     - rst: active-high synchronous reset
//     - in: data to delay, BIT_WIDTH bits wide
// Outputs:
//     - out: input delayed by CHAIN_LENGTH clock cycles
module RegisterChain # (
    parameter int CHAIN_LENGTH,
    parameter int BIT_WIDTH
) (
    input  logic clk, rst,
    input  logic [BIT_WIDTH - 1 : 0] in,
    output logic [BIT_WIDTH - 1 : 0] out
);

    genvar i;
    generate
        if (CHAIN_LENGTH == 0) begin : gen_passthrough
            assign out = in;

        end else if (CHAIN_LENGTH == 1) begin : gen_single
            D_FF #(.BIT_WIDTH(BIT_WIDTH)) singleFF (
                .clk(clk), .rst(rst), .in(in), .out(out)
            );

        end else begin : gen_chain
            logic [BIT_WIDTH - 1 : 0] intermediateFFOut [CHAIN_LENGTH - 1];

            for (i = 0; i < CHAIN_LENGTH; i++) begin : gen_FFChain
                if (i == 0) begin : gen_first
                    D_FF #(.BIT_WIDTH(BIT_WIDTH)) firstFF (
                        .clk(clk), .rst(rst), .in(in), .out(intermediateFFOut[i])
                    );
                end else if (i == CHAIN_LENGTH - 1) begin : gen_last
                    D_FF #(.BIT_WIDTH(BIT_WIDTH)) lastFF (
                        .clk(clk), .rst(rst), .in(intermediateFFOut[i - 1]), .out(out)
                    );
                end else begin : gen_middle
                    D_FF #(.BIT_WIDTH(BIT_WIDTH)) intermediateFF (
                        .clk(clk), .rst(rst), .in(intermediateFFOut[i - 1]), .out(intermediateFFOut[i])
                    );
                end
            end
        end
    endgenerate
endmodule
