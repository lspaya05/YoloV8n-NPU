// Testbench for Dispatch_SA
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_SA_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

    logic                              clk;
    logic                              rst;
    logic [123:0]                      fifo_dout;
    logic                              fifo_empty;
    logic                              fifo_rd_en;
    logic                              sa_done;
    logic [7:0]                        cfg_tile_K;
    logic                              sa_start;
    logic [$clog2(ACT_BUF_DEPTH)-1:0]  sa_act_raddr;
    logic [$clog2(WT_BUF_DEPTH)-1:0]   sa_wt_raddr;
    logic                              sa_act_bank_read;
    logic                              sa_wt_bank_read;
    logic                              unit_done;

    int err_cnt;

    // Instantiating the dut
    Dispatch_SA dut (.*);

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
        sa_done = 1'b0;
        cfg_tile_K = 8'd16;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        // Testcase 1: reset should clear all output strobes
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!fifo_rd_en && !sa_start && !unit_done, "outputs deassert after reset");

        // Testcase 2: empty FIFO should not start the SA
        fifo_empty = 1'b1;
        fifo_dout = instr(OP_MATMUL);
        repeat (2) @(posedge clk); #1ps;
        chk(!fifo_rd_en && !sa_start && !unit_done, "empty FIFO does not start SA");

        // Testcase 3: an unexpected opcode should be dropped and should not start the SA
        fifo_dout = instr(OP_RELU);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "unexpected opcode is dropped");
        chk(!sa_start && !unit_done, "unexpected opcode does not start SA");

        // Testcase 4: MATMUL should pop the FIFO, pulse start, and clear the SRAM read addresses
        fifo_dout = instr(OP_MATMUL);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en && sa_start, "MATMUL pops FIFO and starts SA");
        chk(sa_wt_raddr == '0 && sa_act_raddr == '0, "MATMUL clears read addresses");

        // Testcase 5: during the load phase the weight read address should walk forward
        fifo_empty = 1'b1;
        @(posedge clk); #1ps;
        chk(sa_wt_raddr == '0, "first running cycle reads weight address 0");
        repeat (5) @(posedge clk);
        #1ps;
        chk(sa_wt_raddr == 5, "weight address walks during load phase");

        // Testcase 6: after the load phase the activation address should start from zero
        repeat (SA_ROWS - 5) @(posedge clk);
        #1ps;
        chk(sa_act_raddr == '0, "activation address starts after load phase");

        // Testcase 7: when SA reports done, the dispatch should finish and pulse bank-read strobes
        sa_done = 1'b1;
        @(posedge clk); #1ps;
        chk(!unit_done, "sa_done moves to finish state");
        sa_done = 1'b0;
        @(posedge clk); #1ps;
        chk(unit_done && sa_act_bank_read && sa_wt_bank_read,
            "finish pulses done and bank-read strobes");

        @(posedge clk); #1ps;
        chk(!unit_done && !sa_act_bank_read && !sa_wt_bank_read,
            "finish strobes are one cycle");

        $display("Dispatch_SA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
