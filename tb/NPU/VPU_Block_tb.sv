// Testbench for VPU_Block
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module VPU_Block_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int Lanes = 16;

    logic clk;
    logic rst;
    logic [123:0] disp_payload;
    logic disp_push;
    logic disp_full;
    logic unit_done;
    logic [7:0] cfg_tile_M;
    logic [7:0] cfg_tile_N;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] hred_raddr;
    logic [127:0] hred_rdata;
    logic out_rd_sel;
    logic [$clog2(RES_BANK_DEPTH)-1:0] res_raddr;
    logic [127:0] res_rdata;
    logic lut_sel;
    logic [7:0] lut_raddr;
    logic [7:0] lut_rdata;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] out_waddr;
    logic [127:0] out_wdata;
    logic out_wen;
    logic dep_req_to_vpu_empty;
    logic dep_req_to_vpu_pop;
    logic dep_dma_to_vpu_empty;
    logic dep_dma_to_vpu_pop;
    logic dep_vpu_to_req_full;
    logic dep_vpu_to_req_push;
    logic dep_vpu_to_dma_full;
    logic dep_vpu_to_dma_push;

    int err_cnt;

    // Instantiating the dut
    VPU_Block #(.Lanes(Lanes)) dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to build a dispatch FIFO word
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
        disp_payload = '0;
        disp_push = 1'b0;
        cfg_tile_M = 8'd4;
        cfg_tile_N = 8'd4;
        hred_rdata = '0;
        res_rdata = '0;
        lut_rdata = '0;
        dep_req_to_vpu_empty = 1'b1;
        dep_dma_to_vpu_empty = 1'b1;
        dep_vpu_to_req_full = 1'b0;
        dep_vpu_to_dma_full = 1'b0;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // Sends one instruction into the block FIFO
    task automatic push_instr(input npu_opcode_e opcode, input logic [111:0] payload = 112'h0);
        disp_payload = instr(opcode, payload);
        disp_push = 1'b1;
        @(posedge clk);
        disp_push = 1'b0;
    endtask

    initial begin
        // Testcase 1: reset should leave the VPU block idle
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!disp_full && !unit_done && !out_wen && !out_rd_sel, "reset leaves VPU block idle");

        // Testcase 2: instruction should wait until both dependencies are ready
        push_instr(OP_LUT_BYPASS, 112'h1);
        repeat (8) @(posedge clk); #1ps;
        chk(!dep_req_to_vpu_pop && !dep_dma_to_vpu_pop && !unit_done,
            "dependency gating blocks VPU instruction");

        // Testcase 3: LUT_BYPASS should pop, retire, and update LUT select once dependencies are ready
        dep_req_to_vpu_empty = 1'b0;
        dep_dma_to_vpu_empty = 1'b0;
        while (!unit_done) @(posedge clk);
        #1ps;
        chk(dep_req_to_vpu_pop && dep_dma_to_vpu_pop, "LUT_BYPASS pops dependency tokens");
        chk(dep_vpu_to_req_push && dep_vpu_to_dma_push, "LUT_BYPASS pushes downstream tokens");
        chk(lut_sel, "LUT_BYPASS updates lut_sel");

        // Testcase 4: RELU should read output data, clamp negatives to zero, and write a result
        @(posedge clk);
        hred_rdata = {8'sd15, -8'sd1, 8'sd4, -8'sd8, 8'sd0, 8'sd7, -8'sd3, 8'sd2,
                      8'sd9, -8'sd6, 8'sd5, -8'sd4, 8'sd3, -8'sd2, 8'sd1, -8'sd128};
        push_instr(OP_RELU);
        while (!out_wen) @(posedge clk);
        #1ps;
        chk(out_waddr == 0, "RELU writes first output word at address 0");
        for (int lane = 0; lane < Lanes; lane++) begin
            logic signed [7:0] in_val;
            logic signed [7:0] out_val;
            in_val = signed'(hred_rdata[lane*8 +: 8]);
            out_val = signed'(out_wdata[lane*8 +: 8]);
            chk(out_val === ((in_val < 0) ? 8'sd0 : in_val),
                $sformatf("RELU lane %0d expected %0d got %0d",
                          lane, ((in_val < 0) ? 8'sd0 : in_val), out_val));
        end

        // Testcase 5: ELEW_ADD should add output-bank and residual-bank data lane by lane
        while (!unit_done) @(posedge clk);
        @(posedge clk);
        hred_rdata = 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        res_rdata  = 128'h0202_0202_0202_0202_0202_0202_0202_0202;
        push_instr(OP_ELEW_ADD);
        while (!out_wen) @(posedge clk);
        #1ps;
        chk(out_wdata == 128'h0303_0303_0303_0303_0303_0303_0303_0303,
            "ELEW_ADD writes lane-wise sums");

        $display("VPU_Block_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

endmodule
