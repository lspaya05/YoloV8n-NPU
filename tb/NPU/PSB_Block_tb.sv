// Testbench for PSB_Block
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module PSB_Block_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

    logic clk;
    logic rst;
    logic [123:0] disp_payload;
    logic disp_push;
    logic disp_full;
    logic unit_done;
    logic signed [ACCUM_WIDTH-1:0] sa_row_in [SA_COLS-1:0];
    logic sa_row_valid;
    logic [SA_COLS*ACCUM_WIDTH-1:0] requant_row_out;
    logic [$clog2(SA_ROWS)-1:0] row_index_out;
    logic row_out_valid;
    logic dep_sa_to_psb_empty;
    logic dep_sa_to_psb_pop;
    logic dep_req_to_psb_empty;
    logic dep_req_to_psb_pop;
    logic dep_psb_to_sa_full;
    logic dep_psb_to_sa_push;
    logic dep_psb_to_req_full;
    logic dep_psb_to_req_push;

    int err_cnt;

    // Instantiating the dut
    PSB_Block dut (.*);

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
        sa_row_valid = 1'b0;
        dep_sa_to_psb_empty = 1'b1;
        dep_req_to_psb_empty = 1'b1;
        dep_psb_to_sa_full = 1'b0;
        dep_psb_to_req_full = 1'b0;
        foreach (sa_row_in[i]) sa_row_in[i] = '0;
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

    // Waits for unit_done with a timeout
    task automatic wait_done(input string name, input int timeout_cycles = 200);
        int count;
        count = 0;
        while (!unit_done && count < timeout_cycles) begin
            @(posedge clk);
            count++;
        end
        #1ps;
        chk(count < timeout_cycles, {name, ": timeout waiting for unit_done"});
    endtask

    // Drives one SA row pattern
    task automatic drive_row(input int row);
        for (int col = 0; col < SA_COLS; col++) begin
            sa_row_in[col] = 32'sd1000 * 32'(row) + 32'(col);
        end
        sa_row_valid = 1'b1;
    endtask

    // Checks one packed flush row for valid known data
    task automatic check_flush_row();
        logic signed [31:0] got;
        begin
            chk(row_out_valid, "flush row valid should be high");
            for (int col = 0; col < SA_COLS; col++) begin
                got = signed'(requant_row_out[col*ACCUM_WIDTH +: ACCUM_WIDTH]);
                chk(!$isunknown(got), $sformatf("flush col %0d should not be X", col));
            end
        end
    endtask

    initial begin
        // Testcase 1: reset should clear status and strobes
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!disp_full && !unit_done && !row_out_valid, "reset leaves PSB block idle");

        // Testcase 2: instruction should wait in the issue register until dependencies are ready
        drive_row(0);
        push_instr(OP_PSB_ACC);
        repeat (8) @(posedge clk); #1ps;
        chk(!unit_done && !dep_sa_to_psb_pop && !dep_req_to_psb_pop,
            "dependency gating blocks PSB_ACC consumption");
        dep_sa_to_psb_empty = 1'b0;
        dep_req_to_psb_empty = 1'b0;
        wait_done("gated PSB_ACC");
        chk(dep_sa_to_psb_pop && dep_req_to_psb_pop, "PSB_ACC pops both dependency tokens");
        chk(dep_psb_to_sa_push && dep_psb_to_req_push, "PSB_ACC pushes downstream tokens");
        sa_row_valid = 1'b0;

        // Testcase 3: sixteen PSB_ACC instructions should accumulate sixteen distinct rows
        for (int row = 1; row < SA_ROWS; row++) begin
            drive_row(row);
            push_instr(OP_PSB_ACC);
            wait_done($sformatf("PSB_ACC row %0d", row));
            sa_row_valid = 1'b0;
            @(posedge clk);
        end

        // Testcase 4: PSB_FLUSH should output all accumulated rows in order
        push_instr(OP_PSB_FLUSH);
        for (int row = 0; row < SA_ROWS-1; row++) begin
            while (!row_out_valid) @(posedge clk);
            #1ps;
            check_flush_row();
            @(posedge clk);
        end
        wait_done("PSB_FLUSH");

        // Testcase 5: a second flush after clearing should output zeros
        push_instr(OP_PSB_FLUSH);
        while (!row_out_valid) @(posedge clk);
        #1ps;
        for (int col = 0; col < SA_COLS; col++) begin
            chk(requant_row_out[col*ACCUM_WIDTH +: ACCUM_WIDTH] == 32'h0,
                "second flush starts from cleared buffer");
        end

        $display("PSB_Block_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

endmodule
