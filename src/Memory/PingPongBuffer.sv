// Name: Bernardo Lin, Leonard Paya
// Date: 2026-05-17
// Dual-bank ping-pong buffer that lets a DMA fill one BRAM bank while the systolic array drains the other, swapping banks when both signal done.
// Parameters:
//     - BUFFER_DEPTH: number of entries per bank (256 = one 16×16 INT8 tile)
//     - DATA_BITWIDTH: data bus width in bits, should match DMA/HP port width
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - w_data: DATA_BITWIDTH-bit write data from DMA into the inactive bank
//     - w_addr: log2(BUFFER_DEPTH)-bit write address for DMA port
//     - write_en: Write enable for DMA port
//     - bank_full: Asserted by DMA when the inactive bank is fully loaded
//     - r_addr: log2(BUFFER_DEPTH)-bit read address for systolic array port
//     - bank_read: Asserted by systolic array when the active tile is fully consumed
// Outputs:
//     - r_data: DATA_BITWIDTH-bit read data from the active bank to the systolic array
module PingPongBuffer #(
    parameter int BUFFER_DEPTH = 256,   // entries per bank (one 16×16 INT8 tile = 256 bytes)
    parameter int DATA_BITWIDTH = 128   // match your DMA/HP port width
)(
    input  logic clk, rst,

    // DMA write port (fills the inactive bank)
    input  logic [DATA_BITWIDTH-1:0] w_data,
    input  logic [$clog2(BUFFER_DEPTH)-1:0] w_addr,
    input  logic write_en,
    input  logic bank_full,       // DMA asserts this when bank is full

    // Systolic array read port (drains the active bank)
    input  logic [$clog2(BUFFER_DEPTH)-1:0] r_addr,
    output logic [DATA_BITWIDTH-1:0] r_data,
    input  logic bank_read         // systolic array asserts when tile consumed
);

logic bank_sel;   // 0: bank A is SA-side, bank B is DMA-side
                  // 1: bank B is SA-side, bank A is DMA-side

// Swap when both sides signal done
always_ff @(posedge clk) begin
    if (rst) bank_sel <= 0;
    else if (bank_full && bank_read) bank_sel <= ~bank_sel;
end

// Two inferred BRAMs
(* ram_style = "block" *) logic [DATA_BITWIDTH-1:0] bank_a [0:BUFFER_DEPTH-1];
(* ram_style = "block" *) logic [DATA_BITWIDTH-1:0] bank_b [0:BUFFER_DEPTH-1];

// Write port — always goes to the inactive bank
always_ff @(posedge clk) begin
    if (write_en) begin
        if (bank_sel == 0) bank_b[w_addr] <= w_data;  // A=SA, B=DMA
        else               bank_a[w_addr] <= w_data;  // B=SA, A=DMA
    end
end

// Read port — always reads from the active bank
always_ff @(posedge clk) begin
    if (bank_sel == 0) r_data <= bank_a[r_addr];
    else               r_data <= bank_b[r_addr];
end

endmodule
