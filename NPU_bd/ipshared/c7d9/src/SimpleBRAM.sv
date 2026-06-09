// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Generic synchronous block RAM for KR260 BRAM; registered 1-cycle read, no data reset.
// Parameters:
//     - DEPTH: number of addressable entries
//     - DATA_WIDTH: bit width of each entry
// Inputs:
//     - clk: System clock
//     - w_addr: Write address, $clog2(DEPTH) bits wide
//     - w_data: Write data, DATA_WIDTH bits wide
//     - w_en: Write enable; asserted to store w_data at w_addr
//     - r_addr: Read address, $clog2(DEPTH) bits wide
// Outputs:
//     - r_data: Registered read data, DATA_WIDTH bits (1-cycle latency)

// No reset on data array — BRAM primitives on KR260 do not support sync reset.
module SimpleBRAM #(
    parameter int DEPTH      = 256,
    parameter int DATA_WIDTH = 8
)(
    input  logic                          clk,
    input  logic [$clog2(DEPTH)-1:0]     w_addr,
    input  logic [DATA_WIDTH-1:0]         w_data,
    input  logic                          w_en,
    input  logic [$clog2(DEPTH)-1:0]     r_addr,
    output logic [DATA_WIDTH-1:0]         r_data
);

(* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

always_ff @(posedge clk) begin
    if (w_en)
        mem[w_addr] <= w_data;
end

always_ff @(posedge clk) begin
    r_data <= mem[r_addr];
end

endmodule
