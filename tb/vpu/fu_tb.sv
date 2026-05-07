module fu_tb();

    // Logic needed for the FU inputs and output
    logic [7:0] in1;
    logic [7:0] in2;
    logic [2:0] opcode;
    logic [7:0] out;

    // Logic needed to check the output values
    logic signed [7:0] expected_8;

    // Instantiating the dut
    fu dut (.*);

    initial begin

        // Initializing all signals so that they do not start as x.
        in1 = 8'sd0;
        in2 = 8'sd0;
        opcode = 3'b000;
        #1;

        // Testcase 1: ADD should add the two signed INT8 inputs.
        in1 = 8'sd25;
        in2 = -8'sd5;
        opcode = 3'b000;
        #1;
        expected_8 = 8'sd20;
        if ($signed(out) !== expected_8) begin
            $display("FAIL ADD: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 2: ADD should saturate above +127.
        in1 = 8'sd120;
        in2 = 8'sd20;
        opcode = 3'b000;
        #1;
        expected_8 = 8'sd127;
        if ($signed(out) !== expected_8) begin
            $display("FAIL ADD saturation: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 3: SUB should subtract the second input from the first input.
        in1 = 8'sd25;
        in2 = 8'sd40;
        opcode = 3'b001;
        #1;
        expected_8 = -8'sd15;
        if ($signed(out) !== expected_8) begin
            $display("FAIL SUB: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 4: SUB should saturate below -128.
        in1 = -8'sd120;
        in2 = 8'sd20;
        opcode = 3'b001;
        #1;
        expected_8 = -8'sd128;
        if ($signed(out) !== expected_8) begin
            $display("FAIL SUB saturation: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 5: MUL should multiply the inputs and shift right by 7.
        in1 = 8'sd64;
        in2 = 8'sd4;
        opcode = 3'b010;
        #1;
        expected_8 = 8'sd2;
        if ($signed(out) !== expected_8) begin
            $display("FAIL MUL positive: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 6: MAX should use signed comparison.
        in1 = -8'sd2;
        in2 = 8'sd5;
        opcode = 3'b011;
        #1;
        expected_8 = 8'sd5;
        if ($signed(out) !== expected_8) begin
            $display("FAIL MAX: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 7: MIN should use signed comparison.
        in1 = -8'sd2;
        in2 = 8'sd5;
        opcode = 3'b100;
        #1;
        expected_8 = -8'sd2;
        if ($signed(out) !== expected_8) begin
            $display("FAIL MIN: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 8: SEL should choose in1 when in2[0] is 1.
        in1 = 8'sd123;
        in2 = 8'sd1;
        opcode = 3'b101;
        #1;
        expected_8 = 8'sd123;
        if ($signed(out) !== expected_8) begin
            $display("FAIL SEL choose in1: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 9: SEL should choose in2 when in2[0] is 0.
        in1 = 8'sd123;
        in2 = 8'sd8;
        opcode = 3'b101;
        #1;
        expected_8 = 8'sd8;
        if ($signed(out) !== expected_8) begin
            $display("FAIL SEL choose in2: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 10: ABS should make a negative value positive.
        in1 = -8'sd99;
        in2 = 8'sd0;
        opcode = 3'b110;
        #1;
        expected_8 = 8'sd99;
        if ($signed(out) !== expected_8) begin
            $display("FAIL ABS normal: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 11: ABS of -128 should saturate to +127.
        in1 = -8'sd128;
        in2 = 8'sd0;
        opcode = 3'b110;
        #1;
        expected_8 = 8'sd127;
        if ($signed(out) !== expected_8) begin
            $display("FAIL ABS edge: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 12: Unsupported FU opcode should output 0.
        in1 = 8'sd55;
        in2 = 8'sd66;
        opcode = 3'b111;
        #1;
        expected_8 = 8'sd0;
        if ($signed(out) !== expected_8) begin
            $display("FAIL default opcode: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        $display("PASS: FU INT8 tests passed");
        $stop;
    end

endmodule
