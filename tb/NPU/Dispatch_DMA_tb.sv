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

    int err_cnt;

    // Instantiating the dut
    Dispatch_DMA dut (
        .clk       (clk),
        .rst       (rst),
        .ch0_dout  (ch0_dout),
        .ch0_empty (ch0_empty),
        .ch0_rd_en (ch0_rd_en),
        .ch1_dout  (ch1_dout),
        .ch1_empty (ch1_empty),
        .ch1_rd_en (ch1_rd_en)
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
        repeat (3) @(posedge clk);
        rst = 1'b0;
        #1ps;

        chk(!ch0_rd_en && !ch1_rd_en, "empty channels are not read");

        // Testcase 2: only channel 0 has data, so only channel 0 should be drained
        ch0_empty = 1'b0;
        ch1_empty = 1'b1;
        #1ps;
        chk(ch0_rd_en && !ch1_rd_en, "ch0 drains independently");

        // Testcase 3: only channel 1 has data, so only channel 1 should be drained
        ch0_empty = 1'b1;
        ch1_empty = 1'b0;
        #1ps;
        chk(!ch0_rd_en && ch1_rd_en, "ch1 drains independently");

        // Testcase 4: both DMA channels have data, so both read enables should assert
        ch0_empty = 1'b0;
        ch1_empty = 1'b0;
        #1ps;
        chk(ch0_rd_en && ch1_rd_en, "both channels drain when non-empty");

        // Testcase 5: payload bits do not affect the drain-only behavior
        ch0_dout = 124'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFF;
        ch1_dout = 124'h1234_5678_9ABC_DEF0_1357_9BDF_2468_AC0;
        ch0_empty = 1'b0;
        ch1_empty = 1'b0;
        #1ps;
        chk(ch0_rd_en && ch1_rd_en, "payload contents do not change drain behavior");

        $display("Dispatch_DMA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
