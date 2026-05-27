// Testbench for Dispatch_DMA
`timescale 1ns/1ps

module Dispatch_DMA_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

    logic         clk;
    logic         rst;
    logic [123:0] ch0_dout;
    logic         ch0_empty;
    logic         ch0_rd_en;
    logic [123:0] ch1_dout;
    logic         ch1_empty;
    logic         ch1_rd_en;
    logic [31:0]  wt_src_base;
    logic         ch1_start;
    logic         dma_ch1_idle;
    logic [31:0]  desc_src_base;
    logic [15:0]  desc_row_stride;
    logic [7:0]   desc_tile_w;
    logic [7:0]   desc_tile_h;
    logic [7:0]   desc_ch_count;
    logic [3:0]   desc_pad_top;
    logic [3:0]   desc_pad_bot;
    logic [3:0]   desc_pad_left;
    logic [3:0]   desc_pad_right;
    logic [2:0]   desc_fetch_mode;
    logic [31:0]  desc_concat_base;
    logic [9:0]   desc_coeff_ch_count;
    logic         desc_lut_sel;
    logic         desc_start;
    logic         dma_ch0_idle;
    logic         dep_sa_to_dma_empty;
    logic         dep_sa_to_dma_pop;
    logic         dep_vpu_to_dma_empty;
    logic         dep_vpu_to_dma_pop;

    int err_cnt;
    logic seen_ch0_rd;
    logic seen_ch1_rd;

    // Instantiating the dut
    Dispatch_DMA dut (
        .clk       (clk),
        .rst       (rst),
        .ch0_dout  (ch0_dout),
        .ch0_empty (ch0_empty),
        .ch0_rd_en (ch0_rd_en),
        .ch1_dout  (ch1_dout),
        .ch1_empty (ch1_empty),
        .ch1_rd_en (ch1_rd_en),
        .wt_src_base(wt_src_base),
        .ch1_start(ch1_start),
        .dma_ch1_idle(dma_ch1_idle),
        .desc_src_base(desc_src_base),
        .desc_row_stride(desc_row_stride),
        .desc_tile_w(desc_tile_w),
        .desc_tile_h(desc_tile_h),
        .desc_ch_count(desc_ch_count),
        .desc_pad_top(desc_pad_top),
        .desc_pad_bot(desc_pad_bot),
        .desc_pad_left(desc_pad_left),
        .desc_pad_right(desc_pad_right),
        .desc_fetch_mode(desc_fetch_mode),
        .desc_concat_base(desc_concat_base),
        .desc_coeff_ch_count(desc_coeff_ch_count),
        .desc_lut_sel(desc_lut_sel),
        .desc_start(desc_start),
        .dma_ch0_idle(dma_ch0_idle),
        .dep_sa_to_dma_empty(dep_sa_to_dma_empty),
        .dep_sa_to_dma_pop(dep_sa_to_dma_pop),
        .dep_vpu_to_dma_empty(dep_vpu_to_dma_empty),
        .dep_vpu_to_dma_pop(dep_vpu_to_dma_pop)
    );

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    initial begin
        // Testcase 1: reset with both DMA FIFOs empty should leave both read enables low
        err_cnt = 0;
        rst = 1'b1;
        ch0_dout = 124'h0;
        ch1_dout = 124'h0;
        ch0_empty = 1'b1;
        ch1_empty = 1'b1;
        dma_ch0_idle = 1'b1;
        dma_ch1_idle = 1'b1;
        dep_sa_to_dma_empty = 1'b0;
        dep_vpu_to_dma_empty = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        #1ps;

        chk(!ch0_rd_en && !ch1_rd_en, "empty channels are not read");

        // Testcase 2: only channel 0 has data, so only channel 0 should be drained
        ch0_dout = {8'h20, 4'h0, 112'h10};
        ch0_empty = 1'b0;
        ch1_empty = 1'b1;
        @(posedge clk); #1ps;
        chk(ch0_rd_en && !ch1_rd_en, "ch0 drains independently");
        ch0_empty = 1'b1;
        repeat (5) @(posedge clk);

        // Testcase 3: only channel 1 has data, so only channel 1 should be drained
        ch0_empty = 1'b1;
        ch1_dout = {8'h21, 4'h0, 112'h20};
        ch1_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(!ch0_rd_en && ch1_rd_en, "ch1 drains independently");
        ch1_empty = 1'b1;
        repeat (5) @(posedge clk);

        // Testcase 4: both DMA channels have data, so both read enables should assert
        ch0_dout = {8'h20, 4'h0, 112'h30};
        ch1_dout = {8'h21, 4'h0, 112'h40};
        ch0_empty = 1'b0;
        ch1_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(ch0_rd_en && ch1_rd_en, "both channels drain when non-empty");
        ch0_empty = 1'b1;
        ch1_empty = 1'b1;
        repeat (5) @(posedge clk);

        // Testcase 5: payload bits do not affect the drain-only behavior
        ch0_dout = {8'h11, 4'hF, 112'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF};
        ch1_dout = {8'h10, 4'h0, 112'h1234_5678_9ABC_DEF0_1357_9BDF};
        ch0_empty = 1'b0;
        ch1_empty = 1'b0;
        seen_ch0_rd = 1'b0;
        seen_ch1_rd = 1'b0;
        repeat (20) begin
            @(posedge clk); #1ps;
            if (ch0_rd_en) seen_ch0_rd = 1'b1;
            if (ch1_rd_en) seen_ch1_rd = 1'b1;
        end
        chk(seen_ch0_rd && seen_ch1_rd, "payload contents do not change drain behavior");

        $display("Dispatch_DMA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
