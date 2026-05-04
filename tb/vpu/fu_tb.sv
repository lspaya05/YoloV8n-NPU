module fu_tb();

    // Logic needed for the FU inputs and output
    logic [31:0] in1;
    logic [31:0] in2;
    logic [2:0] opcode;
    logic [31:0] out;

    // Logic needed to check the output values
    logic signed [31:0] expected_32;

    // Instantiating the dut
    fu dut (.*);

    initial begin

        // Initializing all signals so that they do not start as x.
        in1 = 32'sd0;
        in2 = 32'sd0;
        opcode = 3'b000;
        #1;

        // ------------------------------------------------
        // Testcase 1:
        // ADD should add the two signed inputs.
        // Input: in1 = 25, in2 = -5, opcode = 000.
        // Expected output: out = 20.
        // ------------------------------------------------
        in1 = 32'sd25;
        in2 = -32'sd5;
        opcode = 3'b000;
        #1;
        expected_32 = 32'sd20;
        if ($signed(out) !== expected_32) begin
            $display("FAIL ADD: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 2:
        // SUB should subtract the second input from the first input.
        // Input: in1 = 25, in2 = 40, opcode = 001.
        // Expected output: out = -15.
        // ------------------------------------------------
        in1 = 32'sd25;
        in2 = 32'sd40;
        opcode = 3'b001;
        #1;
        expected_32 = -32'sd15;
        if ($signed(out) !== expected_32) begin
            $display("FAIL SUB: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 3:
        // MUL should multiply the inputs and shift right by 8.
        // Input: in1 = 512, in2 = 3, opcode = 010.
        // Expected output: out = 6.
        // ------------------------------------------------
        in1 = 32'sd512;
        in2 = 32'sd3;
        opcode = 3'b010;
        #1;
        expected_32 = 32'sd6;
        if ($signed(out) !== expected_32) begin
            $display("FAIL MUL positive: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 4:
        // MUL should keep the sign when the product is negative.
        // Input: in1 = -512, in2 = 3, opcode = 010.
        // Expected output: out = -6.
        // ------------------------------------------------
        in1 = -32'sd512;
        in2 = 32'sd3;
        opcode = 3'b010;
        #1;
        expected_32 = -32'sd6;
        if ($signed(out) !== expected_32) begin
            $display("FAIL MUL negative: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 5:
        // MAX should use signed comparison.
        // Input: in1 = -2, in2 = 5, opcode = 011.
        // Expected output: out = 5.
        // ------------------------------------------------
        in1 = -32'sd2;
        in2 = 32'sd5;
        opcode = 3'b011;
        #1;
        expected_32 = 32'sd5;
        if ($signed(out) !== expected_32) begin
            $display("FAIL MAX: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 6:
        // MIN should use signed comparison.
        // Input: in1 = -2, in2 = 5, opcode = 100.
        // Expected output: out = -2.
        // ------------------------------------------------
        in1 = -32'sd2;
        in2 = 32'sd5;
        opcode = 3'b100;
        #1;
        expected_32 = -32'sd2;
        if ($signed(out) !== expected_32) begin
            $display("FAIL MIN: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 7:
        // SEL should choose in1 when in2[0] is 1.
        // Input: in1 = 123, in2 = 1, opcode = 101.
        // Expected output: out = 123.
        // ------------------------------------------------
        in1 = 32'sd123;
        in2 = 32'sd1;
        opcode = 3'b101;
        #1;
        expected_32 = 32'sd123;
        if ($signed(out) !== expected_32) begin
            $display("FAIL SEL choose in1: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 8:
        // SEL should choose in2 when in2[0] is 0.
        // Input: in1 = 123, in2 = 8, opcode = 101.
        // Expected output: out = 8.
        // ------------------------------------------------
        in1 = 32'sd123;
        in2 = 32'sd8;
        opcode = 3'b101;
        #1;
        expected_32 = 32'sd8;
        if ($signed(out) !== expected_32) begin
            $display("FAIL SEL choose in2: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 9:
        // ABS should make a negative value positive.
        // Input: in1 = -99, opcode = 110.
        // Expected output: out = 99.
        // ------------------------------------------------
        in1 = -32'sd99;
        in2 = 32'sd0;
        opcode = 3'b110;
        #1;
        expected_32 = 32'sd99;
        if ($signed(out) !== expected_32) begin
            $display("FAIL ABS normal: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 10:
        // ABS of the most negative 32-bit value overflows in two's complement.
        // Input: in1 = 0x80000000, opcode = 110.
        // Expected output: out = 0x80000000.
        // ------------------------------------------------
        in1 = 32'h80000000;
        in2 = 32'sd0;
        opcode = 3'b110;
        #1;
        if (out !== 32'h80000000) begin
            $display("FAIL ABS edge: out=%h expected=80000000", out);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 11:
        // Unsupported FU opcode should output 0.
        // Input: in1 = 55, in2 = 66, opcode = 111.
        // Expected output: out = 0.
        // ------------------------------------------------
        in1 = 32'sd55;
        in2 = 32'sd66;
        opcode = 3'b111;
        #1;
        expected_32 = 32'sd0;
        if ($signed(out) !== expected_32) begin
            $display("FAIL default opcode: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        $display("PASS: FU tests passed");
        $stop;
    end

endmodule
