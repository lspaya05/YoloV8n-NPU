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

    // Logic needed for the packed INT8 VPU inputs and outputs
    logic [LANES*8-1:0] in_a;
    logic [LANES*8-1:0] in_b;
    logic [7:0] data_h_edge;
    logic [LANES*8-1:0] out;

    // Logic needed to check the output values
    int lane;
    logic signed [7:0] expected_8;
    logic signed [15:0] expected_16;

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
        in_a <= '0;
        in_b <= '0;
        data_h_edge <= 8'sd0;

        // Reset the VPU registers.
                                            @(posedge clk);
        rst <= 1'b0;                       @(posedge clk);
        enable <= 1'b1;                    @(posedge clk);

        // ------------------------------------------------
        // Testcase 1:
        // Give every lane simple positive INT8 numbers.
        // lane 0: in_a = 10, in_b = 3
        // lane 1: in_a = 11, in_b = 4
        // lane 2: in_a = 12, in_b = 5
        // ...
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*8 +: 8] <= 8'sd10 + lane[7:0];
            in_b[lane*8 +: 8] <= 8'sd3 + lane[7:0];
        end
                                            @(posedge clk);

        // ------------------------------------------------
        // Testcase 2:
        // VADD should output in_a + in_b.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out = 13 + 2N.
        // ------------------------------------------------
        opcode <= 8'h20;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = (8'sd10 + lane[7:0]) + (8'sd3 + lane[7:0]);
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VADD lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 3:
        // HOLD should forward the value saved by the previous VADD.
        // Input: VPE registers are holding the previous VADD results.
        // Expected output: lane N has out = 13 + 2N.
        // ------------------------------------------------
        opcode <= 8'h52;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = (8'sd10 + lane[7:0]) + (8'sd3 + lane[7:0]);
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL HOLD lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 4:
        // VSUB should output in_a - in_b.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: every lane has out = 7.
        // ------------------------------------------------
        opcode <= 8'h21;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = (8'sd10 + lane[7:0]) - (8'sd3 + lane[7:0]);
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VSUB lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 5:
        // VMUL should output (in_a * in_b) shifted right by 7.
        // This keeps the INT8 multiply result in INT8 scale.
        // ------------------------------------------------
        opcode <= 8'h22;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_16 = ((8'sd10 + lane[7:0]) * (8'sd3 + lane[7:0])) >>> 7;
            expected_8 = expected_16[7:0];
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VMUL lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 6:
        // VMAX should output the bigger input.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out = 10 + N.
        // ------------------------------------------------
        opcode <= 8'h23;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = 8'sd10 + lane[7:0];
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VMAX lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 7:
        // VMIN should output the smaller input.
        // Input: lane N has in_a = 10 + N and in_b = 3 + N.
        // Expected output: lane N has out = 3 + N.
        // ------------------------------------------------
        opcode <= 8'h24;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = 8'sd3 + lane[7:0];
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VMIN lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
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
            in_a[lane*8 +: 8] <= 8'sd100 + lane[7:0];
            in_b[lane*8 +: 8] <= lane[0];
        end
                                            @(posedge clk);
        opcode <= 8'h25;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            if (lane[0])
                expected_8 = 8'sd100 + lane[7:0];
            else
                expected_8 = 8'sd0;

            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VSEL lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 9:
        // VABS should output the positive version of in_a.
        // Input: lane N has in_a = -20 - N.
        // Expected output: lane N has out = 20 + N.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*8 +: 8] <= -8'sd20 - lane[7:0];
            in_b[lane*8 +: 8] <= 8'sd0;
        end
                                            @(posedge clk);
        opcode <= 8'h26;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = 8'sd20 + lane[7:0];
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL VABS lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 10:
        // Saturating VADD should clamp above +127.
        // Input: 120 + 20 = 140.
        // Expected output: +127.
        // ------------------------------------------------
        in_a[0*8 +: 8] <= 8'sd120;
        in_b[0*8 +: 8] <= 8'sd20;
        opcode <= 8'h20;                   @(posedge clk);
        #1;
        if ($signed(out[0*8 +: 8]) !== 8'sd127) begin
            $display("FAIL VADD saturation: out=%0d expected=127", $signed(out[0*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 11:
        // Saturating VSUB should clamp below -128.
        // Input: -120 - 20 = -140.
        // Expected output: -128.
        // ------------------------------------------------
        in_a[0*8 +: 8] <= -8'sd120;
        in_b[0*8 +: 8] <= 8'sd20;
        opcode <= 8'h21;                   @(posedge clk);
        #1;
        if ($signed(out[0*8 +: 8]) !== -8'sd128) begin
            $display("FAIL VSUB saturation: out=%0d expected=-128", $signed(out[0*8 +: 8]));
            $stop;
        end

        // ------------------------------------------------
        // Testcase 12:
        // Clear each lane register to 0 before testing REDUCE.
        // Input: every lane has in_a = 0 and in_b = 0.
        // Expected output after VADD clock: every lane register holds 0.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*8 +: 8] <= 8'sd0;
            in_b[lane*8 +: 8] <= 8'sd0;
        end
        data_h_edge <= 8'sd1;
        opcode <= 8'h20;                   @(posedge clk);

        // ------------------------------------------------
        // Testcase 13:
        // REDUCE sum first pass.
        // Every lane sees Data-H as 1 and its register as 0.
        // Input: data_h_edge = 1, every lane register = 0.
        // Expected output: every lane has out = 1.
        // ------------------------------------------------
        reduce_max <= 1'b0;
        opcode <= 8'h40;
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = 8'sd1;
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL REDUCE sum first pass lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 14:
        // REDUCE sum second pass.
        // The right-neighbor chain creates a running sum across the lanes.
        // Input: data_h_edge = 1, every lane register = 1.
        // Expected output: lane N has out = LANES - N + 1.
        // ------------------------------------------------
                                            @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = LANES - lane + 1;
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL REDUCE sum second pass lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 15:
        // Clear each lane register to 0 before testing REDUCE max.
        // Input: every lane has in_a = 0 and in_b = 0.
        // Expected output after VADD clock: every lane register holds 0.
        // ------------------------------------------------
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            in_a[lane*8 +: 8] <= 8'sd0;
            in_b[lane*8 +: 8] <= 8'sd0;
        end
        opcode <= 8'h20;                   @(posedge clk);

        // ------------------------------------------------
        // Testcase 16:
        // REDUCE max should pass the max value across the Data-H chain.
        // Input: data_h_edge = 50, every lane register = 0.
        // Expected output: every lane has out = 50.
        // ------------------------------------------------
        data_h_edge <= 8'sd50;
        reduce_max <= 1'b1;
        opcode <= 8'h40;                   @(posedge clk);
        #1;
        for (lane = 0; lane < LANES; lane = lane + 1) begin
            expected_8 = 8'sd50;
            if ($signed(out[lane*8 +: 8]) !== expected_8) begin
                $display("FAIL REDUCE max lane %0d: out=%0d expected=%0d",
                         lane, $signed(out[lane*8 +: 8]), expected_8);
                $stop;
            end
        end

        // ------------------------------------------------
        // Testcase 17:
        // enable = 0 should keep VADD from updating the saved lane registers.
        // Input: save 9 + 1 = 10, then try to save 100 + 20 while enable = 0.
        // Expected output after HOLD: lane 0 still has out = 10.
        // ------------------------------------------------
        enable <= 1'b1;
        in_a[0*8 +: 8] <= 8'sd9;
        in_b[0*8 +: 8] <= 8'sd1;
        opcode <= 8'h20;                   @(posedge clk);

        enable <= 1'b0;
        in_a[0*8 +: 8] <= 8'sd100;
        in_b[0*8 +: 8] <= 8'sd20;
        opcode <= 8'h20;                   @(posedge clk);

        opcode <= 8'h52;                   @(posedge clk);
        #1;
        if ($signed(out[0*8 +: 8]) !== 8'sd10) begin
            $display("FAIL enable hold lane 0: out=%0d expected=10",
                     $signed(out[0*8 +: 8]));
            $stop;
        end
        enable <= 1'b1;

        // ------------------------------------------------
        // Testcase 18:
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

        $display("PASS: VPU INT8 tests passed");
        $stop;
    end

endmodule
