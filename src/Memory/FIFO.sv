// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Parameterizable synchronous FIFO; wraps xpm_fifo_sync (XPM) or custom RTL with MSB wrap-around pointer scheme.
// Parameters:
//     - USE_XILINX_XPM: 1 = Xilinx xpm_fifo_sync macro, 0 = custom RTL
//     - DATA_WIDTH: Width of each FIFO entry in bits
//     - DEPTH: Number of entries; must be power of 2 for custom RTL correctness
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - wr_en: Write enable; pushes din onto the FIFO
//     - rd_en: Read enable; pops head entry to dout
//     - din: Write data, DATA_WIDTH bits
// Outputs:
//     - dout: Read data, DATA_WIDTH bits, one-cycle registered latency
//     - full: Asserted when FIFO is full; writes ignored
//     - empty: Asserted when FIFO is empty; reads ignored
module FIFO #(
    parameter USE_XILINX_XPM = 1,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
)(
    input  logic clk,
    input  logic rst,
    input  logic wr_en,
    input  logic rd_en,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout,
    output logic full,
    output logic empty
);

    generate
        if (USE_XILINX_XPM == 1) begin : gen_xilinx_fifo

            xpm_fifo_sync #(
                .WRITE_DATA_WIDTH(DATA_WIDTH),
                .READ_DATA_WIDTH(DATA_WIDTH),
                .FIFO_WRITE_DEPTH(DEPTH),
                .READ_MODE("std"),
                .DOUT_RESET_VALUE("0")
            ) xpm_inst (
                .wr_clk(clk),
                .rst(rst),
                .wr_en(wr_en),
                .rd_en(rd_en),
                .din(din),
                .dout(dout),
                .full(full),
                .empty(empty),
                .almost_empty(), .almost_full(), .data_valid(), .dbiterr(),
                .overflow(), .prog_empty(), .prog_full(), .rd_data_count(),
                .rd_rst_busy(), .sbiterr(), .underflow(), .wr_ack(),
                .wr_data_count(), .wr_rst_busy(),
                .sleep(1'b0), .injectsbiterr(1'b0), .injectdbiterr(1'b0)
            );

        end else begin : gen_custom_fifo

            localparam PTR_WIDTH = $clog2(DEPTH);

            logic [DATA_WIDTH-1:0] memory_array [0:DEPTH-1];

            logic [PTR_WIDTH:0] wr_ptr;
            logic [PTR_WIDTH:0] rd_ptr;
            logic [PTR_WIDTH:0] count;

            wire do_write = wr_en && (!full || rd_en);
            wire do_read  = rd_en && !empty;

            always_ff @(posedge clk) begin
                if (rst) begin
                    wr_ptr <= '0;
                    rd_ptr <= '0;
                    count  <= '0;
                    dout   <= '0;
                end else begin
                    if (do_write) begin
                        memory_array[wr_ptr[PTR_WIDTH-1:0]] <= din;
                        wr_ptr <= wr_ptr + 1'b1;
                    end
                    if (do_read) begin
                        dout   <= memory_array[rd_ptr[PTR_WIDTH-1:0]];
                        rd_ptr <= rd_ptr + 1'b1;
                    end

                    case ({do_write, do_read})
                        2'b10: count <= count + 1'b1;
                        2'b01: count <= count - 1'b1;
                        default: count <= count;
                    endcase
                end
            end

            assign empty = (count == '0);
            assign full  = (count == DEPTH);

        end
    endgenerate

endmodule
