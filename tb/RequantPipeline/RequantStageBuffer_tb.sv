// Testbench for RequantStageBuffer
`timescale 1ns/1ps

module RequantStageBuffer_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int LANES_IN    = 16;
    localparam int LANES_OUT   = 64;
    localparam int GROUP       = LANES_OUT / LANES_IN;

    logic clk;
    logic rst;
    logic [LANES_IN*32-1:0]  row_i;
    logic                    valid_i;
    logic [LANES_OUT*32-1:0] data_o;
    logic                    valid_o;

    int err_cnt;

    // Instantiating the dut
    RequantStageBuffer #(
        .LANES_IN  (LANES_IN),
        .LANES_OUT (LANES_OUT)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .row_i   (row_i),
        .valid_i (valid_i),
        .data_o  (data_o),
        .valid_o (valid_o)
    );

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Helper function to make an easily checked PSB row
    function automatic logic [LANES_IN*32-1:0] make_row(input int row_num);
        logic [LANES_IN*32-1:0] row;
        begin
            row = '0;
            for (int lane = 0; lane < LANES_IN; lane++) begin
                row[lane*32 +: 32] = 32'(row_num * 1000 + lane);
            end
            return row;
        end
    endfunction

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // Checks that all rows in the widened group match the expected rows
    task automatic check_group(input int first_row);
        logic [31:0] got;
        logic [31:0] exp;
        begin
            for (int row = 0; row < GROUP; row++) begin
                for (int lane = 0; lane < LANES_IN; lane++) begin
                    got = data_o[(row*LANES_IN + lane)*32 +: 32];
                    exp = 32'((first_row + row) * 1000 + lane);
                    chk(got === exp,
                        $sformatf("group row %0d lane %0d expected %0d got %0d",
                                  row, lane, exp, got));
                end
            end
        end
    endtask

    // Resets everything
    task automatic reset_dut();
        rst = 1'b1;
        row_i = '0;
        valid_i = 1'b0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // Sends one row into the stage buffer
    task automatic send_row(input int row_num, input logic valid);
        row_i = make_row(row_num);
        valid_i = valid;
        @(posedge clk);
        #1ps;
        valid_i = 1'b0;
    endtask

    initial begin
        // Testcase 1: reset should clear the valid flag and output data
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!valid_o && data_o == '0, "reset clears valid and data");

        // Testcase 2: four valid rows should create one widened output group, and an invalid row should not count
        send_row(0, 1'b1);
        chk(!valid_o, "row 0 does not complete group");
        send_row(1, 1'b1);
        chk(!valid_o, "row 1 does not complete group");
        send_row(99, 1'b0);
        chk(!valid_o, "invalid row does not advance group");
        send_row(2, 1'b1);
        chk(!valid_o, "row 2 does not complete group after gap");
        send_row(3, 1'b1);
        chk(valid_o, "row 3 completes group");
        check_group(0);

        // Testcase 3: the valid pulse should only last one cycle and the data should stay stable
        @(posedge clk); #1ps;
        chk(!valid_o, "valid_o is one cycle");
        check_group(0);

        // Testcase 4: a second group should start fresh after the first group is emitted
        send_row(4, 1'b1);
        send_row(5, 1'b1);
        send_row(6, 1'b1);
        send_row(7, 1'b1);
        chk(valid_o, "second group completes");
        check_group(4);

        // Testcase 5: reset in the middle of a partial group should clear the partial count
        send_row(8, 1'b1);
        rst = 1'b1;
        @(posedge clk); #1ps;
        chk(!valid_o, "reset clears partial group valid");
        rst = 1'b0;
        send_row(10, 1'b1);
        send_row(11, 1'b1);
        send_row(12, 1'b1);
        send_row(13, 1'b1);
        chk(valid_o, "group after reset completes");
        check_group(10);

        $display("RequantStageBuffer_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
