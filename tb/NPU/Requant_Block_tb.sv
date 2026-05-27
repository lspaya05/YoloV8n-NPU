// Testbench for Requant_Block (16-lane, ChCount=1 build)
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Requant_Block_tb();

    localparam int CLK_HALF_NS = 5;
    localparam int Lanes = 16;
    localparam int ChCount = 1;

    logic clk;
    logic rst;
    logic [123:0] disp_payload;
    logic disp_push;
    logic disp_full;
    logic unit_done;
    logic [SA_COLS*ACCUM_WIDTH-1:0] psb_row_in;
    logic psb_row_valid;
    logic [$clog2(MAX_CHANNELS)-1:0] coeff_raddr;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] coeff_rdata;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] out_waddr;
    logic [127:0] out_wdata;
    logic out_wen;
    logic dep_psb_to_req_empty;
    logic dep_psb_to_req_pop;
    logic dep_vpu_to_req_empty;
    logic dep_vpu_to_req_pop;
    logic dep_req_to_psb_full;
    logic dep_req_to_psb_push;
    logic dep_req_to_vpu_full;
    logic dep_req_to_vpu_push;

    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] coeff_mem [0:MAX_CHANNELS-1];
    logic signed [7:0] expected_lanes [0:15];
    int err_cnt;
    logic seen_req_pop;
    logic seen_vpu_pop;
    logic seen_psb_push;
    logic seen_vpu_push;

    Requant_Block #(
        .Lanes(Lanes),
        .ChCount(ChCount)
    ) dut (.*);

    assign coeff_rdata = coeff_mem[coeff_raddr];

    always @(posedge clk) begin
        if (rst) begin
            seen_req_pop  <= 1'b0;
            seen_vpu_pop  <= 1'b0;
            seen_psb_push <= 1'b0;
            seen_vpu_push <= 1'b0;
        end else begin
            if (dep_psb_to_req_pop) seen_req_pop <= 1'b1;
            if (dep_vpu_to_req_pop) seen_vpu_pop <= 1'b1;
            if (dep_req_to_psb_push) seen_psb_push <= 1'b1;
            if (dep_req_to_vpu_push) seen_vpu_push <= 1'b1;
        end
    end

    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    function automatic logic [111:0] requant_payload(input logic [9:0] ch_count);
        npu_requant_payload_t p;
        p = '0;
        p.ch_count = ch_count;
        return p;
    endfunction

    function automatic logic [123:0] instr(input npu_opcode_e opcode,
                                           input logic [111:0] payload);
        return {opcode, 4'h0, payload};
    endfunction

    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    task automatic reset_dut();
        rst = 1'b1;
        disp_payload = '0;
        disp_push = 1'b0;
        psb_row_in = '0;
        psb_row_valid = 1'b0;
        dep_psb_to_req_empty = 1'b1;
        dep_vpu_to_req_empty = 1'b1;
        dep_req_to_psb_full = 1'b0;
        dep_req_to_vpu_full = 1'b0;
        for (int i = 0; i < MAX_CHANNELS; i++) coeff_mem[i] = {32'sd1, 4'd0};
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    task automatic push_instr(input npu_opcode_e opcode, input logic [111:0] payload);
        disp_payload = instr(opcode, payload);
        disp_push = 1'b1;
        @(posedge clk);
        disp_push = 1'b0;
    endtask

    // Drives one PSB row and records expected 16 INT8 outputs (m0=1, n=0, no bias)
    task automatic drive_psb_row();
        logic signed [31:0] value;
        begin
            for (int col = 0; col < SA_COLS; col++) begin
                value = 32'(col) - 32'sd8;
                psb_row_in[col*ACCUM_WIDTH +: ACCUM_WIDTH] = value;
                if (value > 127) expected_lanes[col] = 8'sd127;
                else if (value < -128) expected_lanes[col] = -8'sd128;
                else expected_lanes[col] = value[7:0];
            end
            psb_row_valid = 1'b1;
            @(posedge clk);
            psb_row_valid = 1'b0;
        end
    endtask

    initial begin
        // Testcase 1: reset leaves the block idle
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!disp_full && !unit_done && !out_wen, "reset leaves Requant block idle");

        // Testcase 2: REQUANT waits for both dependency tokens
        push_instr(OP_REQUANT, requant_payload(10'd1));
        repeat (8) @(posedge clk); #1ps;
        chk(!dep_psb_to_req_pop && !dep_vpu_to_req_pop && !out_wen,
            "dependency gating blocks REQUANT consumption");

        // Testcase 3: with deps ready, coeff loads then one PSB row requantizes
        dep_psb_to_req_empty = 1'b0;
        dep_vpu_to_req_empty = 1'b0;
        repeat (6) @(posedge clk);
        #1ps;
        chk(seen_req_pop && seen_vpu_pop, "REQUANT pops both dependency tokens");
        drive_psb_row();
        while (!out_wen) @(posedge clk);
        #1ps;
        chk(out_waddr == 0, "out_waddr is 0 on first write");
        for (int lane = 0; lane < 16; lane++) begin
            chk(signed'(out_wdata[lane*8 +: 8]) === expected_lanes[lane],
                $sformatf("requant lane %0d expected %0d got %0d",
                          lane, expected_lanes[lane], signed'(out_wdata[lane*8 +: 8])));
        end
        while (!unit_done) @(posedge clk);
        @(posedge clk); #1ps;
        chk(seen_psb_push && seen_vpu_push, "REQUANT pushes downstream dependency tokens");

        // Testcase 4: done and write strobes are one cycle
        chk(!unit_done && !out_wen, "REQUANT completion strobes are one cycle");

        $display("Requant_Block_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

endmodule
