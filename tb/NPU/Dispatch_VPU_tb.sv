// Testbench for Dispatch_VPU
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_VPU_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int Lanes = 16;

    logic                              clk;
    logic                              rst;
    logic [123:0]                      fifo_dout;
    logic                              fifo_empty;
    logic                              fifo_rd_en;
    logic                              vpu_valid_opcode;
    logic [Lanes*8-1:0]                vpu_out;
    logic [127:0]                      vpu_hred_rdata;
    logic [127:0]                      vpu_res_rdata;
    logic [7:0]                        cfg_tile_M;
    logic [7:0]                        cfg_tile_N;
    logic                              vpu_enable;
    logic [7:0]                        vpu_opcode;
    logic                              vpu_reduce_max;
    logic [Lanes*8-1:0]                vpu_in_a;
    logic [Lanes*8-1:0]                vpu_in_b;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] vpu_hred_raddr;
    logic [$clog2(RES_BANK_DEPTH)-1:0] vpu_res_raddr;
    logic                              out_rd_sel;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] vpu_out_waddr;
    logic [127:0]                      vpu_out_wdata;
    logic                              vpu_out_wen;
    logic                              lut_bypass_en;
    logic                              vpu_lut_sel;
    logic                              unit_done;

    int err_cnt;

    // Instantiating the dut
    Dispatch_VPU #(.Lanes(Lanes)) dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to build a FIFO word
    function automatic logic [123:0] instr(input npu_opcode_e opcode,
                                           input logic [111:0] payload = 112'h0);
        return {opcode, 4'h0, payload};
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
        vpu_valid_opcode = 1'b1;
        vpu_out = 128'hCAFE_BABE_DEAD_BEEF_0123_4567_89AB_CDEF;
        vpu_hred_rdata = 128'h0102_0304_0506_0708_090A_0B0C_0D0E_0F10;
        vpu_res_rdata = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        cfg_tile_M = 8'd4;
        cfg_tile_N = 8'd4;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        // Testcase 1: reset should clear all output strobes
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!fifo_rd_en && !vpu_enable && !vpu_out_wen && !unit_done,
            "outputs deassert after reset");

        // Testcase 2: empty FIFO should not create any VPU activity
        fifo_empty = 1'b1;
        fifo_dout = instr(OP_RELU);
        repeat (2) @(posedge clk); #1ps;
        chk(!fifo_rd_en && !vpu_enable && !unit_done && !vpu_out_wen,
            "empty FIFO does not start VPU operation");

        // Testcase 3: LUT_BYPASS should pop and retire immediately while latching the bypass flag
        fifo_dout = instr(OP_LUT_BYPASS, 112'h1);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en && unit_done, "LUT_BYPASS pops and retires immediately");
        chk(lut_bypass_en && vpu_lut_sel, "LUT_BYPASS latches bypass flag");

        fifo_empty = 1'b1;
        @(posedge clk); #1ps;
        chk(!unit_done, "LUT_BYPASS done is one cycle");

        // Testcase 4: LUT_LOAD and SIMD_ACT stubs should pop and retire immediately
        fifo_dout = instr(OP_LUT_LOAD);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en && unit_done, "LUT_LOAD stub pops and retires immediately");
        fifo_dout = instr(OP_SIMD_ACT);
        @(posedge clk); #1ps;
        chk(fifo_rd_en && unit_done, "SIMD_ACT stub pops and retires immediately");
        fifo_empty = 1'b1;
        @(posedge clk); #1ps;
        chk(!unit_done, "stub done pulse is one cycle");

        // Testcase 5: RELU should run through READ, COMPUTE, WRITE, and DONE
        fifo_dout = instr(OP_RELU);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "RELU pops FIFO");
        fifo_empty = 1'b1;

        @(posedge clk); #1ps;
        chk(out_rd_sel && vpu_hred_raddr == '0, "READ selects output bank address 0");

        @(posedge clk); #1ps;
        chk(vpu_enable, "COMPUTE pulses vpu_enable");
        chk(vpu_opcode == 8'h23, "RELU translates to VMAX");
        chk(vpu_in_a == vpu_hred_rdata, "COMPUTE forwards output-bank data to in_a");
        chk(vpu_in_b == 128'h0, "RELU uses zero for in_b");

        // Testcase 6: WRITE should store the VPU output into the output bank
        @(posedge clk); #1ps;
        chk(vpu_out_wen && vpu_out_waddr == '0, "WRITE stores VPU result at address 0");
        chk(vpu_out_wdata == vpu_out, "WRITE stores VPU output data");

        @(posedge clk); #1ps;
        chk(unit_done && !out_rd_sel, "DONE pulses unit_done and releases output read mux");

        @(posedge clk); #1ps;
        chk(!unit_done && !vpu_out_wen, "done and write strobes are one cycle");

        // Testcase 7: ELEW_ADD should translate to VADD and use residual data as operand B
        fifo_dout = instr(OP_ELEW_ADD);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        fifo_empty = 1'b1;
        @(posedge clk);
        @(posedge clk); #1ps;
        chk(vpu_opcode == 8'h20, "ELEW_ADD translates to VADD");
        chk(vpu_in_b == vpu_res_rdata, "ELEW_ADD forwards residual data to in_b");

        $display("Dispatch_VPU_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
