module vpu_tb();

    // Number of VPE lanes in the VPU
    localparam int LANES = 16;

    // Logic needed for the clock and reset
    logic clk;
    logic rst;

    // Logic needed to control the VPU
    logic enable;
    logic [7:0] opcode;
    logic reduce_max;
    logic valid_opcode;

    // Logic needed for requantizing 32-bit values down to 8-bit values
    logic [4:0] requant_shift;
    logic signed [7:0] requant_zero_point;

    // Logic needed for the packed VPU inputs and outputs
    logic [LANES*32-1:0] in_a;
    logic [LANES*32-1:0] in_b;
    logic [31:0] data_h_edge;
    logic [LANES*32-1:0] out_32;
    logic [LANES*8-1:0] out_8;

    // Logic needed to check the output values
    int lane;
    logic signed [31:0] expected_32;

    // Instantiating the dut
    vpu #(
        .LANES(LANES)
    ) dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin

        // Initializing all signals so that they do not start as x.
        rst <= 1'b1;
        enable <= 1'b0;
        opcode <= 8'h52;
        reduce_max <= 1'b0;
        requant_shift <= 5'd0;
        requant_zero_point <= 8'sd0;
        in_a <= '0;
        in_b <= '0;
        data_h_edge <= 32'sd0;

        // Reset the VPU registers.
                                            @(posedge clk);
        rst <= 1'b0;                       @(posedge clk);
        enable <= 1'b1;                    @(posedge clk);

        // ------------------------------------------------
        // Testcase 1:
        // Give every lane simple positive numbers.
        // lane 0: in_a = 10, in_b = 3
        // lane 1: in_a = 11, in_b = 4
        // lane 2: in_a = 12, in_b = 5
        // ...
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*32 +: 32] <= 32'sd10 + lane;
            in_b[lane*32 +: 32] <= 32'sd3 + lane;
        end
                                            @(posedge clk);

        // ------------------------------------------------
        // Testcase 2:
        // VADD should output in_a + in_b.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out_32 = 13 + 2N.
        // ------------------------------------------------
        opcode <= 8'h20;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = (32'sd10 + lane) + (32'sd3 + lane);
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VADD lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 3:
        // HOLD should forward the value saved by the previous VADD.
        // Input: VPE registers are holding the previous VADD results.
        // Expected output: lane N has out_32 = 13 + 2N.
        // ------------------------------------------------
        opcode <= 8'h52;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = (32'sd10 + lane) + (32'sd3 + lane);
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL HOLD lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 4:
        // VSUB should output in_a - in_b.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: every lane has out_32 = 7.
        // ------------------------------------------------
        opcode <= 8'h21;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = (32'sd10 + lane) - (32'sd3 + lane);
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VSUB lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 5:
        // VMUL should output (in_a * in_b) shifted right by 8.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out_32 = ((10 + N) * (3 + N)) >>> 8.
        // ------------------------------------------------
        opcode <= 8'h22;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = ((32'sd10 + lane) * (32'sd3 + lane)) >>> 8;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VMUL lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 6:
        // VMAX should output the bigger input.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out_32 = 10 + N.
        // ------------------------------------------------
        opcode <= 8'h23;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = 32'sd10 + lane;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VMAX lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 7:
        // VMIN should output the smaller input.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out_32 = 3 + N.
        // ------------------------------------------------
        opcode <= 8'h24;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = 32'sd3 + lane;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VMIN lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 8:
        // VSEL chooses in_a when the lowest bit of in_b is 1.
        // It chooses in_b when the lowest bit of in_b is 0.
        // Input: lane N has in_a = 100 + N and in_b = N[0].
        // Expected output: odd lanes output 100 + N, even lanes output 0.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*32 +: 32] <= 32'sd100 + lane;
            in_b[lane*32 +: 32] <= lane[0];
        end
                                            @(posedge clk);
        opcode <= 8'h25;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            if (lane[0])
                expected_32 = 32'sd100 + lane;
            else
                expected_32 = 32'sd0;

            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VSEL lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 9:
        // VABS should output the positive version of in_a.
        // Input: lane N has in_a = -20 - N.
        // Expected output: lane N has out_32 = 20 + N.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*32 +: 32] <= -32'sd20 - lane;
            in_b[lane*32 +: 32] <= 32'sd0;
        end
                                            @(posedge clk);
        opcode <= 8'h26;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = 32'sd20 + lane;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL VABS lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 10:
        // Clear each lane register to 0 before testing REDUCE.
        // Input: every lane has in_a = 0 and in_b = 0.
        // Expected output after VADD clock: every lane register holds 0.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*32 +: 32] <= 32'sd0;
            in_b[lane*32 +: 32] <= 32'sd0;
        end
        data_h_edge <= 32'sd1;
        opcode <= 8'h20;                   @(posedge clk);

        // ------------------------------------------------
        // Testcase 11:
        // REDUCE sum first pass.
        // Every lane sees Data-H as 1 and its register as 0.
        // Input: data_h_edge = 1, every lane register = 0.
        // Expected output: every lane has out_32 = 1.
        // ------------------------------------------------
        reduce_max <= 1'b0;
        opcode <= 8'h40;
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = 32'sd1;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL REDUCE sum first pass lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 12:
        // REDUCE sum second pass.
        // The right-neighbor chain creates a running sum across the lanes.
        // Input: data_h_edge = 1, every lane register = 1.
        // Expected output: lane N has out_32 = LANES - N + 1.
        // ------------------------------------------------
                                            @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = LANES - lane + 1;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL REDUCE sum second pass lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 13:
        // Clear each lane register to 0 before testing REDUCE max.
        // Input: every lane has in_a = 0 and in_b = 0.
        // Expected output after VADD clock: every lane register holds 0.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*32 +: 32] <= 32'sd0;
            in_b[lane*32 +: 32] <= 32'sd0;
        end
        opcode <= 8'h20;                   @(posedge clk);

        // ------------------------------------------------
        // Testcase 14:
        // REDUCE max should pass the max value across the Data-H chain.
        // Input: data_h_edge = 50, every lane register = 0.
        // Expected output: every lane has out_32 = 50.
        // ------------------------------------------------
        data_h_edge <= 32'sd50;
        reduce_max <= 1'b1;
        opcode <= 8'h40;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_32 = 32'sd50;
            if ($signed(out_32[lane*32 +: 32]) !== expected_32) begin
                $display("FAIL REDUCE max lane %0d: out=%0d expected=%0d",
                         lane, $signed(out_32[lane*32 +: 32]), expected_32);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 15:
        // REQUANT should shift, add zero point, and clamp to INT8.
        // lane 0: 200 >>> 1 + 1 = 101
        // lane 1: -300 >>> 1 + 1 = -149, clamp to -128
        // lane 2: 20 >>> 1 + 1 = 11
        // Input: requant_shift = 1, requant_zero_point = 1.
        // Expected output: lane 0 = 101, lane 1 = -128, lane 2 = 11.
        // ------------------------------------------------
        reduce_max <= 1'b0;
        requant_shift <= 5'd1;
        requant_zero_point <= 8'sd1;
        in_a[0*32 +: 32] <= 32'sd200;
        in_a[1*32 +: 32] <= -32'sd300;
        in_a[2*32 +: 32] <= 32'sd20;
        opcode <= 8'h28;                   @(posedge clk);
        #1;
        if ($signed(out_8[0*8 +: 8]) !== 8'sd101) begin
            $display("FAIL REQUANT lane 0: out=%0d expected=101", $signed(out_8[0*8 +: 8]));
            $stop;
        end
        if ($signed(out_8[1*8 +: 8]) !== -8'sd128) begin
            $display("FAIL REQUANT lane 1: out=%0d expected=-128", $signed(out_8[1*8 +: 8]));
            $stop;
        end
        if ($signed(out_8[2*8 +: 8]) !== 8'sd11) begin
            $display("FAIL REQUANT lane 2: out=%0d expected=11", $signed(out_8[2*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 16:
        // REQUANT positive clamp.
        // 300 is bigger than signed INT8 can hold, so output should be 127.
        // Input: lane 3 has in_a = 300, shift = 0, zero point = 0.
        // Expected output: lane 3 has out_8 = 127.
        // ------------------------------------------------
        requant_shift <= 5'd0;
        requant_zero_point <= 8'sd0;
        in_a[3*32 +: 32] <= 32'sd300;
        opcode <= 8'h28;                   @(posedge clk);
        #1;
        if ($signed(out_8[3*8 +: 8]) !== 8'sd127) begin
            $display("FAIL REQUANT positive clamp lane 3: out=%0d expected=127",
                     $signed(out_8[3*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 17:
        // REQUANT exact INT8 boundaries should not change.
        // Input: lane 4 = 127, lane 5 = -128, shift = 0, zero point = 0.
        // Expected output: lane 4 = 127, lane 5 = -128.
        // ------------------------------------------------
        in_a[4*32 +: 32] <= 32'sd127;
        in_a[5*32 +: 32] <= -32'sd128;
        opcode <= 8'h28;                   @(posedge clk);
        #1;
        if ($signed(out_8[4*8 +: 8]) !== 8'sd127) begin
            $display("FAIL REQUANT exact positive lane 4: out=%0d expected=127",
                     $signed(out_8[4*8 +: 8]));
            $stop;
        end
        if ($signed(out_8[5*8 +: 8]) !== -8'sd128) begin
            $display("FAIL REQUANT exact negative lane 5: out=%0d expected=-128",
                     $signed(out_8[5*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 18:
        // REQUANT zero point can push a value into the clamp range.
        // Input: lane 6 = 120, shift = 0, zero point = 10.
        // Expected output: lane 6 = 127 because 120 + 10 = 130.
        // ------------------------------------------------
        requant_shift <= 5'd0;
        requant_zero_point <= 8'sd10;
        in_a[6*32 +: 32] <= 32'sd120;
        opcode <= 8'h28;                   @(posedge clk);
        #1;
        if ($signed(out_8[6*8 +: 8]) !== 8'sd127) begin
            $display("FAIL REQUANT zero point clamp lane 6: out=%0d expected=127",
                     $signed(out_8[6*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 19:
        // enable = 0 should keep VADD from updating the saved lane registers.
        // Input: save 9 + 1 = 10, then try to save 100 + 200 while enable = 0.
        // Expected output after HOLD: lane 0 still has out_32 = 10.
        // ------------------------------------------------
        enable <= 1'b1;
        in_a[0*32 +: 32] <= 32'sd9;
        in_b[0*32 +: 32] <= 32'sd1;
        opcode <= 8'h20;                   @(posedge clk);

        enable <= 1'b0;
        in_a[0*32 +: 32] <= 32'sd100;
        in_b[0*32 +: 32] <= 32'sd200;
        opcode <= 8'h20;                   @(posedge clk);

        opcode <= 8'h52;                   @(posedge clk);
        #1;
        if ($signed(out_32[0*32 +: 32]) !== 32'sd10) begin
            $display("FAIL enable hold lane 0: out=%0d expected=10",
                     $signed(out_32[0*32 +: 32]));
            $stop;
        end
        enable <= 1'b1;

        // ------------------------------------------------
        // Testcase 20:
        // Unsupported opcode should make valid_opcode go low.
        // Input: opcode = 8'h99.
        // Expected output: valid_opcode = 0.
        // ------------------------------------------------
        opcode <= 8'h99;                   @(posedge clk);
        #1;
        if (valid_opcode !== 1'b0) begin
            $display("FAIL invalid opcode: valid_opcode=%b expected=0", valid_opcode);
            $stop;
        end

        $display("PASS: VPU tests passed");
        $stop;
    end

endmodule
