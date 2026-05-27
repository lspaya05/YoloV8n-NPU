// Testbench for RequantPipeline (16-lane, ChCount=1 build)
`timescale 1ns/1ps

module RequantPipeline_tb();

    localparam int CLK_HALF_NS  = 5;
    localparam int Lanes        = 16;
    localparam int ChCount      = 1;
    localparam int LanesPerCh   = Lanes / ChCount;
    localparam int LaneLatency  = 4;

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

    RequantPipeline #(
        .Lanes      (Lanes),
        .ChCount    (ChCount),
        .M0Width    (32),
        .ShiftWidth (8)
    ) dut (.*);

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

    function automatic logic signed [31:0] sext8(input logic [7:0] value);
        begin
            sext8 = 32'(signed'(value));
        end
    endfunction

    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

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

    task automatic set_params(
        input logic signed [31:0] bias,
        input logic signed [31:0] m0a,
        input logic [7:0]         na,
        input logic signed [31:0] m0b,
        input logic [7:0]         nb
    );
        begin
            bias_i = bias;
            m0_a_i = m0a;
            n_a_i  = na;
            m0_b_i = m0b;
            n_b_i  = nb;
        end
    endtask

    task automatic check_sram_result(input string name, input logic binary_mode);
        logic signed [7:0] expected;
        logic signed [7:0] got;
        begin
            for (int lane = 0; lane < Lanes; lane++) begin
                expected = ref_requant(
                    sext8(sram_a_i[lane*8 +: 8]),
                    binary_mode ? sext8(sram_b_i[lane*8 +: 8]) : 32'sd0,
                    32'sd0,
                    signed'(m0_a_i),
                    n_a_i,
                    signed'(m0_b_i),
                    n_b_i
                );
                got = signed'(data_o[lane*8 +: 8]);
                chk(got === expected,
                    $sformatf("%s lane %0d expected %0d got %0d", name, lane, expected, got));
            end
        end
    endtask

    task automatic check_psb_result(input string name);
        logic signed [31:0] op_a;
        logic signed [7:0] expected;
        logic signed [7:0] got;
        begin
            for (int lane = 0; lane < Lanes; lane++) begin
                op_a = signed'(psb_row_i[lane]);
                expected = ref_requant(
                    op_a,
                    32'sd0,
                    signed'(bias_i),
                    signed'(m0_a_i),
                    n_a_i,
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
        // Testcase 1: reset clears outputs
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!valid_o && data_o == '0, "reset clears output");

        // Testcase 2: FROM_SRAM mode — sign-extend INT8 lanes and apply scale
        set_params(32'sd0, 32'sd2, 8'd1, 32'sd0, 8'd0);
        for (int lane = 0; lane < Lanes; lane++) begin
            case (lane)
                0:  sram_a_i[lane*8 +: 8] = 8'sd127;
                1:  sram_a_i[lane*8 +: 8] = -8'sd128;
                2:  sram_a_i[lane*8 +: 8] = 8'sd100;
                default: sram_a_i[lane*8 +: 8] = 8'(lane - 8);
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

        // Testcase 3: BINARY_ADD mode — two INT8 tensors scaled and summed
        set_params(32'sd0, 32'sd2, 8'd1, 32'sd3, 8'd1);
        for (int lane = 0; lane < Lanes; lane++) begin
            sram_a_i[lane*8 +: 8] = 8'(lane - 4);
            sram_b_i[lane*8 +: 8] = 8'(20 - lane);
        end
        sram_a_i[3*8 +: 8] = 8'sd120;
        sram_b_i[3*8 +: 8] = 8'sd120;
        sram_a_i[15*8 +: 8] = -8'sd128;
        sram_b_i[15*8 +: 8] = -8'sd128;
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

        // Testcase 4: invalid mode suppresses valid_o
        mode_i = 2'b11;
        sram_a_valid_i = 1'b1;
        repeat (LaneLatency + 2) @(posedge clk);
        #1ps;
        chk(!valid_o, "invalid mode suppresses valid_o");
        sram_a_valid_i = 1'b0;

        // Testcase 5: FROM_PSB mode — one 16-lane INT32 row + bias requantized
        set_params(32'sd10, 32'sd1, 8'd0, 32'sd0, 8'd0);
        mode_i = 2'b01;
        for (int col = 0; col < 16; col++) begin
            psb_row_i[col] = 32'sd100 * 32'(col) - 32'sd200;
        end
        psb_row_valid_i = 1'b1;
        @(posedge clk);
        psb_row_valid_i = 1'b0;
        repeat (LaneLatency) @(posedge clk);
        #1ps;
        chk(valid_o, "FROM_PSB valid_o at lane latency");
        check_psb_result("FROM_PSB");
        @(posedge clk); #1ps;
        chk(!valid_o, "FROM_PSB valid_o is one cycle");

        // Testcase 6: reset mid-transaction flushes the pipeline
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
