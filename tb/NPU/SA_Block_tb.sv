// Testbench for SA_Block
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module SA_Block_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

    logic clk;
    logic rst;
    logic [123:0] disp_payload;
    logic disp_push;
    logic disp_full;
    logic unit_done;
    logic [7:0] cfg_tile_K;
    logic [$clog2(ACT_BUF_DEPTH)-1:0] sa_act_raddr;
    logic [127:0] sa_act_rdata;
    logic sa_act_bank_read;
    logic [$clog2(WT_BUF_DEPTH)-1:0] sa_wt_raddr;
    logic [127:0] sa_wt_rdata;
    logic sa_wt_bank_read;
    logic signed [ACCUM_WIDTH-1:0] sa_row_out [SA_COLS-1:0];
    logic sa_row_valid;
    logic dep_dma_to_sa_empty;
    logic dep_dma_to_sa_pop;
    logic dep_psb_to_sa_empty;
    logic dep_psb_to_sa_pop;
    logic dep_sa_to_dma_full;
    logic dep_sa_to_dma_push;
    logic dep_sa_to_psb_full;
    logic dep_sa_to_psb_push;

    int err_cnt;
    logic seen_dma_pop;
    logic seen_psb_pop;
    logic seen_dma_push;
    logic seen_psb_push;
    logic seen_act_bank_read;
    logic seen_wt_bank_read;
    logic seen_row_valid;

    // Instantiating the dut
    SA_Block dut (.*);

    always @(posedge clk) begin
        if (rst) begin
            seen_dma_pop       <= 1'b0;
            seen_psb_pop       <= 1'b0;
            seen_dma_push      <= 1'b0;
            seen_psb_push      <= 1'b0;
            seen_act_bank_read <= 1'b0;
            seen_wt_bank_read  <= 1'b0;
            seen_row_valid     <= 1'b0;
        end else begin
            if (dep_dma_to_sa_pop) seen_dma_pop <= 1'b1;
            if (dep_psb_to_sa_pop) seen_psb_pop <= 1'b1;
            if (dep_sa_to_dma_push) seen_dma_push <= 1'b1;
            if (dep_sa_to_psb_push) seen_psb_push <= 1'b1;
            if (sa_act_bank_read) seen_act_bank_read <= 1'b1;
            if (sa_wt_bank_read) seen_wt_bank_read <= 1'b1;
            if (sa_row_valid) seen_row_valid <= 1'b1;
        end
    end

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to build a dispatch FIFO word
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
        disp_payload = '0;
        disp_push = 1'b0;
        cfg_tile_K = 8'd16;
        sa_act_rdata = {16{8'h01}};
        sa_wt_rdata = {16{8'h01}};
        dep_dma_to_sa_empty = 1'b1;
        dep_psb_to_sa_empty = 1'b1;
        dep_sa_to_dma_full = 1'b0;
        dep_sa_to_psb_full = 1'b0;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // Sends one instruction into the block FIFO
    task automatic push_instr(input npu_opcode_e opcode);
        disp_payload = instr(opcode);
        disp_push = 1'b1;
        @(posedge clk);
        disp_push = 1'b0;
    endtask

    initial begin
        // Testcase 1: reset should leave the SA block idle
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!disp_full && !unit_done && !sa_row_valid, "reset leaves SA block idle");

        // Testcase 2: MATMUL should wait until both dependency inputs are ready
        push_instr(OP_MATMUL);
        repeat (8) @(posedge clk); #1ps;
        chk(!dep_dma_to_sa_pop && !dep_psb_to_sa_pop && !unit_done,
            "dependency gating blocks MATMUL consumption");

        // Testcase 3: once dependencies are ready, MATMUL should pop tokens and walk read addresses
        dep_dma_to_sa_empty = 1'b0;
        dep_psb_to_sa_empty = 1'b0;
        while (!dep_dma_to_sa_pop) @(posedge clk);
        #1ps;
        chk(seen_dma_pop && seen_psb_pop, "MATMUL pops both dependency tokens");
        repeat (6) @(posedge clk);
        #1ps;
        chk(sa_wt_raddr != '0, "weight read address advances during load phase");

        // Testcase 4: SA should eventually complete, pulse row_valid, and push downstream tokens
        while (!unit_done) @(posedge clk);
        #1ps;
        chk(seen_row_valid, "SA row valid follows SA done");
        chk(seen_act_bank_read && seen_wt_bank_read, "SA completion pulses bank-read strobes");
        chk(seen_dma_push && seen_psb_push, "SA completion pushes downstream tokens");

        // Testcase 5: completion strobes should be one cycle
        @(posedge clk); #1ps;
        chk(!unit_done && !sa_act_bank_read && !sa_wt_bank_read,
            "SA completion strobes are one cycle");

        $display("SA_Block_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

endmodule
