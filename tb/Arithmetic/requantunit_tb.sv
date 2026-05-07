`timescale 1ns/1ps

module requantunit_tb();

    parameter CLOCK_PERIOD = 100;
    localparam int LANES = 8;

    // Instantiating all the variables used in this module and defining input and output pins
    logic clk;
    logic [LANES*32-1:0] in_32;
    logic [4:0] shift;
    logic signed [7:0] zero_point;
    logic [LANES*8-1:0] out_8;

    int errors;

    // Instantiating the dut
    requant_unit #(
        .LANES(LANES)
    ) dut (
        .in_32(in_32),
        .shift(shift),
        .zero_point(zero_point),
        .out_8(out_8)
    );

    // Creating the simulated clock
    initial begin
        clk <= 0;
        forever #(CLOCK_PERIOD/2) clk <= ~clk; // Forever toggle the clock
    end

    initial begin
        // Initializing everything
        errors <= 0;
        in_32 <= '0;
        shift <= 5'd0;
        zero_point <= 8'sd0;              @(posedge clk);

        // Testcase 1: values already inside signed INT8 range should stay the same
        shift <= 5'd0;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= 32'sd0;
        in_32[1*32 +: 32] <= 32'sd1;
        in_32[2*32 +: 32] <= -32'sd1;
        in_32[3*32 +: 32] <= 32'sd42;
        in_32[4*32 +: 32] <= -32'sd17;    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd0) begin
            $display("FAIL testcase 1 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd1) begin
            $display("FAIL testcase 1 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== -8'sd1) begin
            $display("FAIL testcase 1 lane 2");
            errors = errors + 1;
        end
        if ($signed(out_8[3*8 +: 8]) !== 8'sd42) begin
            $display("FAIL testcase 1 lane 3");
            errors = errors + 1;
        end
        if ($signed(out_8[4*8 +: 8]) !== -8'sd17) begin
            $display("FAIL testcase 1 lane 4");
            errors = errors + 1;
        end

        // Testcase 2: exact signed INT8 boundaries should stay the same
        shift <= 5'd0;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= 32'sd127;
        in_32[1*32 +: 32] <= -32'sd128;   @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 2 positive boundary");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 2 negative boundary");
            errors = errors + 1;
        end

        // Testcase 3: values outside signed INT8 range should clamp
        shift <= 5'd0;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= 32'sd128;
        in_32[1*32 +: 32] <= 32'sd300;
        in_32[2*32 +: 32] <= -32'sd129;
        in_32[3*32 +: 32] <= -32'sd300;   @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 3 128 should clamp to 127");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 3 300 should clamp to 127");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 3 -129 should clamp to -128");
            errors = errors + 1;
        end
        if ($signed(out_8[3*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 3 -300 should clamp to -128");
            errors = errors + 1;
        end

        // Testcase 4: positive numbers should shift right before clamping
        shift <= 5'd1;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= 32'sd200;    // 200 >>> 1 = 100
        in_32[1*32 +: 32] <= 32'sd20;     // 20 >>> 1 = 10
        in_32[2*32 +: 32] <= 32'sd255;    // 255 >>> 1 = 127
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd100) begin
            $display("FAIL testcase 4 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd10) begin
            $display("FAIL testcase 4 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 4 lane 2");
            errors = errors + 1;
        end

        // Testcase 5: negative numbers should arithmetic shift right before clamping
        shift <= 5'd1;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= -32'sd200;   // -200 >>> 1 = -100
        in_32[1*32 +: 32] <= -32'sd20;    // -20 >>> 1 = -10
        in_32[2*32 +: 32] <= -32'sd257;   // -257 >>> 1 = -129, clamp to -128
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== -8'sd100) begin
            $display("FAIL testcase 5 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== -8'sd10) begin
            $display("FAIL testcase 5 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 5 lane 2");
            errors = errors + 1;
        end

        // Testcase 6: positive zero_point should be added after shifting
        shift <= 5'd1;
        zero_point <= 8'sd1;
        in_32[0*32 +: 32] <= 32'sd200;    // 100 + 1 = 101
        in_32[1*32 +: 32] <= 32'sd20;     // 10 + 1 = 11
        in_32[2*32 +: 32] <= -32'sd300;   // -150 + 1 = -149, clamp to -128
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd101) begin
            $display("FAIL testcase 6 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd11) begin
            $display("FAIL testcase 6 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 6 lane 2");
            errors = errors + 1;
        end

        // Testcase 7: positive zero_point can cause positive clamp
        shift <= 5'd0;
        zero_point <= 8'sd10;
        in_32[0*32 +: 32] <= 32'sd117;    // 117 + 10 = 127
        in_32[1*32 +: 32] <= 32'sd118;    // 118 + 10 = 128, clamp to 127
        in_32[2*32 +: 32] <= 32'sd120;    // 120 + 10 = 130, clamp to 127
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 7 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 7 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 7 lane 2");
            errors = errors + 1;
        end

        // Testcase 8: negative zero_point can cause negative clamp
        shift <= 5'd0;
        zero_point <= -8'sd10;
        in_32[0*32 +: 32] <= -32'sd118;   // -118 - 10 = -128
        in_32[1*32 +: 32] <= -32'sd119;   // -119 - 10 = -129, clamp to -128
        in_32[2*32 +: 32] <= 32'sd20;     // 20 - 10 = 10
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 8 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 8 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== 8'sd10) begin
            $display("FAIL testcase 8 lane 2");
            errors = errors + 1;
        end

        // Testcase 9: larger shifts should reduce values into range
        shift <= 5'd4;
        zero_point <= 8'sd0;
        in_32[0*32 +: 32] <= 32'sd2048;   // 2048 >>> 4 = 128, clamp to 127
        in_32[1*32 +: 32] <= 32'sd2032;   // 2032 >>> 4 = 127
        in_32[2*32 +: 32] <= -32'sd2048;  // -2048 >>> 4 = -128
                                                    @(posedge clk);
                                                    #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 9 lane 0");
            errors = errors + 1;
        end
        if ($signed(out_8[1*8 +: 8]) !== 8'sd127) begin
            $display("FAIL testcase 9 lane 1");
            errors = errors + 1;
        end
        if ($signed(out_8[2*8 +: 8]) !== -8'sd128) begin
            $display("FAIL testcase 9 lane 2");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: requantunit_tb passed all tests");
        end else begin
            $display("FAIL: requantunit_tb found %0d errors", errors);
        end

        $stop;
    end

endmodule
