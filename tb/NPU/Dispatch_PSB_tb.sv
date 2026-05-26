// Testbench for Dispatch_PSB
`timescale 1ns/1ps

import NPU_ISA_pkg::*;

module Dispatch_PSB_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

    logic         clk;
    logic         rst;
    logic [123:0] fifo_dout;
    logic         fifo_empty;
    logic         fifo_rd_en;
    logic         psb_busy;
    logic         psb_acc_done;
    logic         psb_flush_done;
    logic         psb_acc;
    logic         psb_flush;
    logic         row_valid;
    logic         unit_done;

    int err_cnt;

    // Instantiating the dut
    Dispatch_PSB dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to build a FIFO word with the opcode in the top byte
    function automatic logic [123:0] instr(input npu_opcode_e opcode);
        return {opcode, 4'h0, 112'h0};
    endfunction

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // Resets everything
    task automatic reset_dut();
        rst = 1'b1;
        fifo_dout = '0;
        fifo_empty = 1'b1;
        psb_busy = 1'b0;
        psb_acc_done = 1'b0;
        psb_flush_done = 1'b0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        // Testcase 1: reset should clear all output strobes
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!fifo_rd_en && !psb_acc && !psb_flush && !row_valid && !unit_done,
            "outputs deassert after reset");

        // Testcase 2: empty FIFO should not create any side effects
        fifo_empty = 1'b1;
        fifo_dout = instr(OP_PSB_ACC);
        repeat (2) @(posedge clk); #1ps;
        chk(!fifo_rd_en && !psb_acc && !row_valid && !unit_done,
            "empty FIFO does not trigger PSB_ACC");

        // Testcase 3: PSB_ACC should pop the FIFO, pulse accumulate, mark the row valid, and retire
        fifo_dout = instr(OP_PSB_ACC);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "PSB_ACC pops FIFO");
        chk(psb_acc && row_valid, "PSB_ACC pulses acc and row_valid");
        chk(unit_done, "PSB_ACC retires in same cycle");

        fifo_empty = 1'b1;
        @(posedge clk); #1ps;
        chk(!fifo_rd_en && !psb_acc && !row_valid && !unit_done,
            "PSB_ACC pulses are one cycle");

        // Testcase 4: PSB_FLUSH should wait while the PSB block is busy
        fifo_dout = instr(OP_PSB_FLUSH);
        fifo_empty = 1'b0;
        psb_busy = 1'b1;
        @(posedge clk); #1ps;
        chk(!fifo_rd_en && !psb_flush, "PSB_FLUSH waits while psb_busy");

        // Testcase 5: once the PSB block is idle, PSB_FLUSH should pop and start flushing
        psb_busy = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en && psb_flush, "PSB_FLUSH pops and starts when idle");
        chk(!unit_done, "PSB_FLUSH waits for flush_done before done");

        // Testcase 6: the flush operation should retire only when flush_done arrives
        fifo_empty = 1'b1;
        psb_flush_done = 1'b1;
        @(posedge clk); #1ps;
        chk(unit_done, "PSB_FLUSH retires on flush_done");

        psb_flush_done = 1'b0;
        @(posedge clk); #1ps;
        chk(!unit_done, "PSB_FLUSH done pulse is one cycle");

        // Testcase 7: an unexpected opcode should be dropped without side effects
        fifo_dout = instr(OP_DMA_LOAD);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "unexpected opcode is dropped");
        chk(!psb_acc && !psb_flush && !unit_done, "unexpected opcode has no side effects");

        $display("Dispatch_PSB_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
