// Testbench for RequantSingleLane
`timescale 1ns/1ps

module RequantSingleLane_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int LATENCY     = 4;

    logic clk;
    logic rst;
    logic valid_i;
    logic signed [31:0] operand_a_i;
    logic signed [31:0] operand_b_i;
    logic signed [31:0] bias_i;
    logic signed [31:0] m0_a_i;
    logic [7:0]         n_a_i;
    logic signed [31:0] m0_b_i;
    logic [7:0]         n_b_i;
    logic signed [7:0]  data_o;
    logic valid_o;

    int err_cnt;

    // Instantiating the dut
    RequantSingleLane dut (
        .clk         (clk),
        .rst         (rst),
        .valid_i     (valid_i),
        .operand_a_i (operand_a_i),
        .operand_b_i (operand_b_i),
        .bias_i      (bias_i),
        .m0_a_i      (m0_a_i),
        .n_a_i       (n_a_i),
        .m0_b_i      (m0_b_i),
        .n_b_i       (n_b_i),
        .data_o      (data_o),
        .valid_o     (valid_o)
    );

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Reference model for the expected requantized value
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
        logic signed [63:0] scaled_a;
        logic signed [63:0] scaled_b;
        logic signed [63:0] total;
        begin
            prod_a = 64'(op_a + bias) * 64'(m0_a);
            prod_b = 64'(op_b) * 64'(m0_b);
            scaled_a = prod_a >>> n_a;
            scaled_b = prod_b >>> n_b;
            total = scaled_a + scaled_b;
            if (total > 64'sd127) ref_requant = 8'sd127;
            else if (total < -64'sd128) ref_requant = -8'sd128;
            else ref_requant = total[7:0];
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
        valid_i = 1'b0;
        operand_a_i = '0;
        operand_b_i = '0;
        bias_i = '0;
        m0_a_i = '0;
        n_a_i = '0;
        m0_b_i = '0;
        n_b_i = '0;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // Sends one input transaction and checks the output after the pipeline latency
    task automatic send_case(
        input string name,
        input logic signed [31:0] op_a,
        input logic signed [31:0] op_b,
        input logic signed [31:0] bias,
        input logic signed [31:0] m0_a,
        input logic [7:0]         n_a,
        input logic signed [31:0] m0_b,
        input logic [7:0]         n_b
    );
        logic signed [7:0] expected;
        begin
            expected = ref_requant(op_a, op_b, bias, m0_a, n_a, m0_b, n_b);
            operand_a_i = op_a;
            operand_b_i = op_b;
            bias_i = bias;
            m0_a_i = m0_a;
            n_a_i = n_a;
            m0_b_i = m0_b;
            n_b_i = n_b;
            valid_i = 1'b1;
            @(posedge clk);
            valid_i = 1'b0;
            repeat (LATENCY) @(posedge clk);
            #1ps;
            chk(valid_o, {name, ": valid_o asserted at expected latency"});
            chk(data_o === expected,
                $sformatf("%s: expected %0d got %0d", name, expected, data_o));
            @(posedge clk); #1ps;
            chk(!valid_o, {name, ": valid_o is one cycle"});
        end
    endtask

    initial begin
        // Testcase 1: reset should clear the valid flag and output data
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!valid_o && data_o == 8'sd0, "reset clears output and valid");

        // Testcase 2: basic values, signed boundaries, clamps, shifts, bias, binary add, and large products
        send_case("identity zero", 32'sd0, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("identity positive", 32'sd42, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("identity negative", -32'sd17, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("positive clamp at 128", 32'sd128, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("negative clamp below -128", -32'sd129, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("exact positive boundary", 32'sd127, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("exact negative boundary", -32'sd128, 32'sd0, 32'sd0, 32'sd1, 8'd0, 32'sd0, 8'd0);
        send_case("bias add before multiply", 32'sd20, 32'sd0, 32'sd5, 32'sd2, 8'd1, 32'sd0, 8'd0);
        send_case("arithmetic shift negative", -32'sd257, 32'sd0, 32'sd0, 32'sd1, 8'd1, 32'sd0, 8'd0);
        send_case("binary add scaled", 32'sd40, 32'sd80, 32'sd0, 32'sd3, 8'd2, 32'sd1, 8'd1);
        send_case("binary add negative scaled", -32'sd40, -32'sd20, 32'sd0, 32'sd3, 8'd2, 32'sd5, 8'd3);
        send_case("negative m0", 32'sd20, 32'sd0, 32'sd0, -32'sd2, 8'd1, 32'sd0, 8'd0);
        send_case("large positive product clamps", 32'sd100000, 32'sd0, 32'sd0, 32'sd100000, 8'd0, 32'sd0, 8'd0);
        send_case("large shift reduces", 32'sd4096, 32'sd0, 32'sd0, 32'sd1, 8'd5, 32'sd0, 8'd0);

        // Testcase 3: two back-to-back valid inputs should produce two back-to-back valid outputs
        begin
            logic signed [7:0] expected0;
            logic signed [7:0] expected1;
            expected0 = ref_requant(32'sd12, 32'sd0, 32'sd0, 32'sd2, 8'd1, 32'sd0, 8'd0);
            expected1 = ref_requant(-32'sd80, 32'sd10, 32'sd5, 32'sd1, 8'd0, 32'sd3, 8'd1);
            operand_a_i = 32'sd12;
            operand_b_i = 32'sd0;
            bias_i = 32'sd0;
            m0_a_i = 32'sd2;
            n_a_i = 8'd1;
            m0_b_i = 32'sd0;
            n_b_i = 8'd0;
            valid_i = 1'b1;
            @(posedge clk);
            operand_a_i = -32'sd80;
            operand_b_i = 32'sd10;
            bias_i = 32'sd5;
            m0_a_i = 32'sd1;
            n_a_i = 8'd0;
            m0_b_i = 32'sd3;
            n_b_i = 8'd1;
            @(posedge clk);
            valid_i = 1'b0;
            repeat (LATENCY - 1) @(posedge clk);
            #1ps;
            chk(valid_o && data_o === expected0, "first back-to-back output is correct");
            @(posedge clk); #1ps;
            chk(valid_o && data_o === expected1, "second back-to-back output is correct");
            @(posedge clk); #1ps;
            chk(!valid_o, "back-to-back valid output ends after second result");
        end

        // Testcase 4: invalid input should not create a valid output
        operand_a_i = 32'sd99;
        m0_a_i = 32'sd1;
        valid_i = 1'b0;
        repeat (LATENCY + 2) @(posedge clk);
        #1ps;
        chk(!valid_o, "invalid input does not create valid output");

        // Testcase 5: reset in the middle of a transaction should flush the pipeline
        valid_i = 1'b1;
        operand_a_i = 32'sd77;
        @(posedge clk);
        rst = 1'b1;
        valid_i = 1'b0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (LATENCY + 2) @(posedge clk);
        #1ps;
        chk(!valid_o, "reset flushes in-flight transaction");

        $display("RequantSingleLane_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

endmodule
