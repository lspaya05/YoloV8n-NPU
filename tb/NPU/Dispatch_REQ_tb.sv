// Testbench for Dispatch_REQ
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_REQ_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int ChCount = 1;
    localparam int M0Width = 32;
    localparam int ShiftWidth = 8;

    logic                                             clk;
    logic                                             rst;
    logic [123:0]                                     fifo_dout;
    logic                                             fifo_empty;
    logic                                             fifo_rd_en;
    logic                                             req_valid_o;
    logic [127:0]                                     req_data_o;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]           req_coeff_rdata;
    logic [1:0]                                       req_mode;
    logic [$clog2(MAX_CHANNELS)-1:0]                  req_coeff_raddr;
    logic [ChCount*M0Width-1:0]                       req_m0_a;
    logic [ChCount*ShiftWidth-1:0]                    req_n_a;
    logic [ChCount*32-1:0]                            req_bias;
    logic [$clog2(OUT_BANK_DEPTH)-1:0]                vpu_out_waddr;
    logic [127:0]                                     vpu_out_wdata;
    logic                                             vpu_out_wen;
    logic                                             unit_done;

    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] coeff_mem [0:7];
    int err_cnt;

    // Instantiating the dut
    Dispatch_REQ #(
        .ChCount    (ChCount),
        .M0Width    (M0Width),
        .ShiftWidth (ShiftWidth)
    ) dut (.*);

    always_ff @(posedge clk) begin
        req_coeff_rdata <= coeff_mem[req_coeff_raddr];
    end

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to build a FIFO word
    function automatic logic [123:0] instr(input npu_opcode_e opcode,
                                           input logic [111:0] payload);
        return {opcode, 4'h0, payload};
    endfunction

    // Helper function to build a requant payload
    function automatic logic [111:0] requant_payload(input logic [9:0] ch_count);
        npu_requant_payload_t p;
        p = '0;
        p.ch_count = ch_count;
        return p;
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
        req_valid_o = 1'b0;
        req_data_o = 128'h0;
        req_coeff_rdata = '0;
        for (int i = 0; i < 8; i++) coeff_mem[i] = {32'(32'h1000_0000 + i), 4'(i)};
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        // Testcase 1: reset should clear outputs and keep bias tied to zero
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(req_mode == 2'b00 && !vpu_out_wen && !unit_done, "outputs deassert after reset");
        chk(req_bias == '0, "bias is tied to zero");

        // Testcase 2: empty FIFO should not start coefficient loading
        fifo_empty = 1'b1;
        fifo_dout = instr(OP_REQUANT, requant_payload(10'd2));
        repeat (2) @(posedge clk); #1ps;
        chk(!fifo_rd_en && req_mode == 2'b00 && !unit_done,
            "empty FIFO does not start REQUANT");

        // Testcase 3: an unexpected opcode should be dropped without side effects
        fifo_dout = instr(OP_RELU, 112'h0);
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "unexpected opcode is dropped");
        chk(req_mode == 2'b00 && !unit_done, "unexpected opcode has no side effects");

        // Testcase 4: REQUANT should pop the FIFO and load coefficient shadow registers
        fifo_dout = instr(OP_REQUANT, requant_payload(10'd2));
        fifo_empty = 1'b0;
        @(posedge clk); #1ps;
        chk(fifo_rd_en, "REQUANT pops FIFO");
        fifo_empty = 1'b1;

        repeat (ChCount + 1) @(posedge clk);
        #1ps;
        chk(req_mode == 2'b01, "REQUANT enters FROM_PSB mode after loading coeffs");
        chk(req_m0_a[0 +: M0Width] == 32'h1000_0000, "first captured M0 reflects coeff address 0");
        chk(req_n_a[0 +: ShiftWidth] == 8'h0, "first captured shift reflects coeff address 0");

        // Testcase 5: first valid pipeline beat should write output data but should not finish yet
        req_data_o = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        req_valid_o = 1'b1;
        @(posedge clk); #1ps;
        chk(!vpu_out_wen, "first valid beat is captured before write");
        @(posedge clk); #1ps;
        chk(vpu_out_wen && vpu_out_waddr == 0, "first valid beat writes current address");
        chk(vpu_out_wdata == 128'h1111_2222_3333_4444_5555_6666_7777_8888,
            "first valid beat writes data");
        @(posedge clk); #1ps;
        chk(!unit_done, "not done before target beat count");

        // Testcase 6: second valid beat reaches the target count and should complete the operation
        req_data_o = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1234;
        @(posedge clk); #1ps;
        chk(!vpu_out_wen, "second valid beat is captured before write");
        @(posedge clk); #1ps;
        chk(vpu_out_wen && vpu_out_waddr == 1, "second valid beat writes current address");
        @(posedge clk); #1ps;
        chk(unit_done && req_mode == 2'b00, "second beat completes operation");

        // Testcase 7: done and write strobes should be one cycle
        req_valid_o = 1'b0;
        @(posedge clk); #1ps;
        chk(!unit_done && !vpu_out_wen, "done and write strobes are one cycle");

        $display("Dispatch_REQ_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
