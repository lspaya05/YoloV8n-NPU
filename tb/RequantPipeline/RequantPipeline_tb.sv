// Testbench for RequantPipeline
`timescale 1ns/1ps

module RequantPipeline_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS  = 5;
    localparam int Lanes        = 64;
    localparam int ChCount      = 4;
    localparam int LanesPerCh   = Lanes / ChCount;
    localparam int LaneLatency  = 4;
    localparam int PsbRows      = Lanes / 16;

    logic clk;
    logic rst;
    logic [1:0] mode_i;
    logic [15:0][31:0] psb_row_i;
    logic psb_row_valid_i;
    logic [Lanes*8-1:0] sram_a_i;
    logic sram_a_valid_i;
    logic [Lanes*8-1:0] sram_b_i;
    logic [ChCount*32-1:0] bias_i;
    logic [ChCount*32-1:0] m0_a_i;
    logic [ChCount*8-1:0]  n_a_i;
    logic [ChCount*32-1:0] m0_b_i;
    logic [ChCount*8-1:0]  n_b_i;
    logic [Lanes*8-1:0] data_o;
    logic valid_o;

    int err_cnt;

    // Instantiating the dut
    RequantPipeline #(
        .Lanes      (Lanes),
        .ChCount    (ChCount),
        .M0Width    (32),
        .ShiftWidth (8)
    ) dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Reference model for one lane of requantization
    function automatic logic signed [7:0] ref_requant(
        input logic signed [31:0] op_a,
        input logic signed [31:0] op_b,
        input logic signed [31:0] bias,
        input logic signed [31:0] m0_a,
        input logic [7:0]         n_a,
        input logic signed [31:0] m0_b,
        input logic [7:0]         n_b
    );
        logic signed [63:0] prod_a;
        logic signed [63:0] prod_b;
        logic signed [63:0] total;
        begin
            prod_a = 64'(op_a + bias) * 64'(m0_a);
            prod_b = 64'(op_b) * 64'(m0_b);
            total = (prod_a >>> n_a) + (prod_b >>> n_b);
            if (total > 64'sd127) ref_requant = 8'sd127;
            else if (total < -64'sd128) ref_requant = -8'sd128;
            else ref_requant = total[7:0];
        end
    endfunction

    // Helper function for sign-extending packed INT8 values
    function automatic logic signed [31:0] sext8(input logic [7:0] value);
        begin
            sext8 = 32'(signed'(value));
        end
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
        mode_i = 2'b00;
        psb_row_i = '{default:'0};
        psb_row_valid_i = 1'b0;
        sram_a_i = '0;
        sram_a_valid_i = 1'b0;
        sram_b_i = '0;
        bias_i = '0;
        m0_a_i = '0;
        n_a_i = '0;
        m0_b_i = '0;
        n_b_i = '0;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    task automatic set_group_params(
        input int ch,
        input logic signed [31:0] bias,
        input logic signed [31:0] m0a,
        input logic [7:0]         na,
        input logic signed [31:0] m0b,
        input logic [7:0]         nb
    );
        begin
            bias_i[ch*32 +: 32] = bias;
            m0_a_i[ch*32 +: 32] = m0a;
            n_a_i[ch*8 +: 8] = na;
            m0_b_i[ch*32 +: 32] = m0b;
            n_b_i[ch*8 +: 8] = nb;
        end
    endtask

    // Checks all output lanes for FROM_SRAM and BINARY_ADD modes
    task automatic check_sram_result(input string name, input logic binary_mode);
        int ch;
        logic signed [7:0] expected;
        logic signed [7:0] got;
        begin
            for (int lane = 0; lane < Lanes; lane++) begin
                ch = lane / LanesPerCh;
                expected = ref_requant(
                    sext8(sram_a_i[lane*8 +: 8]),
                    binary_mode ? sext8(sram_b_i[lane*8 +: 8]) : 32'sd0,
                    32'sd0,
                    signed'(m0_a_i[ch*32 +: 32]),
                    n_a_i[ch*8 +: 8],
                    signed'(m0_b_i[ch*32 +: 32]),
                    n_b_i[ch*8 +: 8]
                );
                got = signed'(data_o[lane*8 +: 8]);
                chk(got === expected,
                    $sformatf("%s lane %0d expected %0d got %0d", name, lane, expected, got));
            end
        end
    endtask

    // Checks all output lanes for the FROM_PSB mode
    task automatic check_psb_result(input string name);
        int ch;
        int row;
        int col;
        logic signed [31:0] op_a;
        logic signed [7:0] expected;
        logic signed [7:0] got;
        begin
            for (int lane = 0; lane < Lanes; lane++) begin
                row = lane / 16;
                col = lane % 16;
                ch = lane / LanesPerCh;
                op_a = 32'sd1000 * 32'(row) + 32'(col) - 32'sd20;
                expected = ref_requant(
                    op_a,
                    32'sd0,
                    signed'(bias_i[ch*32 +: 32]),
                    signed'(m0_a_i[ch*32 +: 32]),
                    n_a_i[ch*8 +: 8],
                    32'sd0,
                    8'd0
                );
                got = signed'(data_o[lane*8 +: 8]);
                chk(got === expected,
                    $sformatf("%s lane %0d expected %0d got %0d", name, lane, expected, got));
            end
        end
    endtask

    initial begin
        // Testcase 1: reset should clear the output valid flag and data
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!valid_o && data_o == '0, "reset clears output");

        // Testcase 2: FROM_SRAM mode should sign-extend INT8 lanes and apply each channel group's scale
        set_group_params(0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        set_group_params(1, 32'sd0, 32'sd2, 8'd1, 32'sd0, 8'd0);
        set_group_params(2, 32'sd0, -32'sd1, 8'd0, 32'sd0, 8'd0);
        set_group_params(3, 32'sd0, 32'sd4, 8'd2, 32'sd0, 8'd0);
        for (int lane = 0; lane < Lanes; lane++) begin
            case (lane)
                0:  sram_a_i[lane*8 +: 8] = 8'sd127;
                1:  sram_a_i[lane*8 +: 8] = -8'sd128;
                16: sram_a_i[lane*8 +: 8] = 8'sd100;
                32: sram_a_i[lane*8 +: 8] = 8'sd64;
                48: sram_a_i[lane*8 +: 8] = -8'sd64;
                default: sram_a_i[lane*8 +: 8] = 8'(lane - 32);
            endcase
        end
        mode_i = 2'b00;
        sram_a_valid_i = 1'b1;
        @(posedge clk);
        sram_a_valid_i = 1'b0;
        repeat (LaneLatency) @(posedge clk);
        #1ps;
        chk(valid_o, "FROM_SRAM valid_o at expected latency");
        check_sram_result("FROM_SRAM", 1'b0);
        @(posedge clk); #1ps;
        chk(!valid_o, "FROM_SRAM valid_o is one cycle");

        // Testcase 3: BINARY_ADD mode should scale two INT8 tensors and add them lane by lane
        set_group_params(0, 32'sd0, 32'sd1, 8'd0, 32'sd1, 8'd0);
        set_group_params(1, 32'sd0, 32'sd2, 8'd1, 32'sd3, 8'd1);
        set_group_params(2, 32'sd0, 32'sd4, 8'd2, -32'sd2, 8'd0);
        set_group_params(3, 32'sd0, -32'sd1, 8'd0, 32'sd1, 8'd0);
        for (int lane = 0; lane < Lanes; lane++) begin
            sram_a_i[lane*8 +: 8] = 8'(lane - 20);
            sram_b_i[lane*8 +: 8] = 8'(70 - lane);
        end
        sram_a_i[3*8 +: 8] = 8'sd120;
        sram_b_i[3*8 +: 8] = 8'sd120;
        sram_a_i[61*8 +: 8] = -8'sd128;
        sram_b_i[61*8 +: 8] = -8'sd128;
        mode_i = 2'b10;
        sram_a_valid_i = 1'b1;
        @(posedge clk);
        sram_a_valid_i = 1'b0;
        repeat (LaneLatency) @(posedge clk);
        #1ps;
        chk(valid_o, "BINARY_ADD valid_o at expected latency");
        check_sram_result("BINARY_ADD", 1'b1);
        @(posedge clk); #1ps;
        chk(!valid_o, "BINARY_ADD valid_o is one cycle");

        // Testcase 4: an invalid mode should suppress output valid even if SRAM input is valid
        mode_i = 2'b11;
        sram_a_valid_i = 1'b1;
        repeat (LaneLatency + 2) @(posedge clk);
        #1ps;
        chk(!valid_o, "invalid mode suppresses valid_o");
        sram_a_valid_i = 1'b0;

        // Testcase 5: FROM_PSB mode should collect four PSB rows, add bias, and requantize all 64 lanes
        set_group_params(0, 32'sd10, 32'sd1, 8'd0, 32'sd0, 8'd0);
        set_group_params(1, -32'sd20, 32'sd1, 8'd3, 32'sd0, 8'd0);
        set_group_params(2, 32'sd0, -32'sd1, 8'd0, 32'sd0, 8'd0);
        set_group_params(3, 32'sd127, 32'sd2, 8'd1, 32'sd0, 8'd0);
        mode_i = 2'b01;
        for (int row = 0; row < PsbRows; row++) begin
            for (int col = 0; col < 16; col++) begin
                psb_row_i[col] = 32'sd1000 * 32'(row) + 32'(col) - 32'sd20;
            end
            psb_row_valid_i = 1'b1;
            @(posedge clk);
            psb_row_valid_i = 1'b0;
            if (row != PsbRows - 1) begin
                @(posedge clk); #1ps;
                chk(!valid_o, "FROM_PSB does not output before four rows");
            end
        end
        repeat (LaneLatency + 1) @(posedge clk);
        #1ps;
        chk(valid_o, "FROM_PSB valid_o after stage buffer plus lane latency");
        check_psb_result("FROM_PSB");
        @(posedge clk); #1ps;
        chk(!valid_o, "FROM_PSB valid_o is one cycle");

        // Testcase 6: reset in the middle of a transaction should flush the full pipeline
        mode_i = 2'b00;
        sram_a_valid_i = 1'b1;
        sram_a_i = '1;
        @(posedge clk);
        rst = 1'b1;
        sram_a_valid_i = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (LaneLatency + 2) @(posedge clk);
        #1ps;
        chk(!valid_o, "reset flushes in-flight pipeline data");

        $display("RequantPipeline_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "TIMEOUT");
    end

endmodule
