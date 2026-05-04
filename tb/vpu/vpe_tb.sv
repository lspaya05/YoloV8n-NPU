module vpe_tb();

    // Logic needed for the clock and reset
    logic clk;
    logic rst;

    // Logic needed to control the VPE muxes, register, and FU
    logic left_mux_select;
    logic right_mux_select;
    logic output_mux_select;
    logic register_enable;
    logic [2:0] fu_opcode;

    // Logic needed for the VPE data inputs and output
    logic [31:0] in_a;
    logic [31:0] in_b;
    logic [31:0] data_h_in;
    logic [31:0] out;

    // Logic needed to check the output values
    logic signed [31:0] expected_32;

    // Instantiating the dut
    vpe dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin

        // Initializing all signals so that they do not start as x.
        rst <= 1'b1;
        left_mux_select <= 1'b0;
        right_mux_select <= 1'b0;
        output_mux_select <= 1'b0;
        register_enable <= 1'b0;
        fu_opcode <= 3'b000;
        in_a <= 32'sd0;
        in_b <= 32'sd0;
        data_h_in <= 32'sd0;

        // ------------------------------------------------
        // Testcase 1:
        // Reset should clear the internal VPE register.
        // Input: rst = 1, output_mux_select = 1.
        // Expected output: out = 0.
        // ------------------------------------------------
                                            @(posedge clk);
        rst <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_32 = 32'sd0;
        if ($signed(out) !== expected_32) begin
            $display("FAIL reset register: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 2:
        // Direct ADD path should use in_a and in_b.
        // Input: in_a = 5, in_b = 7, left mux = in_a, right mux = in_b.
        // Expected output: out = 12.
        // ------------------------------------------------
        output_mux_select <= 1'b0;
        left_mux_select <= 1'b0;
        right_mux_select <= 1'b0;
        register_enable <= 1'b0;
        fu_opcode <= 3'b000;
        in_a <= 32'sd5;
        in_b <= 32'sd7;                    @(posedge clk);
        #1;
        expected_32 = 32'sd12;
        if ($signed(out) !== expected_32) begin
            $display("FAIL direct ADD: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 3:
        // Register enable should save the FU result on the clock edge.
        // Input: in_a = 5, in_b = 7, register_enable = 1.
        // Expected output after HOLD: out = 12.
        // ------------------------------------------------
        register_enable <= 1'b1;           @(posedge clk);
        register_enable <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_32 = 32'sd12;
        if ($signed(out) !== expected_32) begin
            $display("FAIL register save: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 4:
        // HOLD should keep forwarding the saved register even when inputs change.
        // Input: saved register = 12, new in_a = 100, new in_b = 200.
        // Expected output: out = 12.
        // ------------------------------------------------
        in_a <= 32'sd100;
        in_b <= 32'sd200;                  @(posedge clk);
        #1;
        expected_32 = 32'sd12;
        if ($signed(out) !== expected_32) begin
            $display("FAIL HOLD changed inputs: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 5:
        // Right mux should choose the saved VPE register when selected.
        // Input: in_a = 10, saved register = 12, right_mux_select = 1.
        // Expected output: out = 22.
        // ------------------------------------------------
        output_mux_select <= 1'b0;
        left_mux_select <= 1'b0;
        right_mux_select <= 1'b1;
        fu_opcode <= 3'b000;
        in_a <= 32'sd10;                   @(posedge clk);
        #1;
        expected_32 = 32'sd22;
        if ($signed(out) !== expected_32) begin
            $display("FAIL right mux register: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 6:
        // Left mux should choose Data-H when selected.
        // Input: data_h_in = 100, in_b = 23, left_mux_select = 1.
        // Expected output: out = 123.
        // ------------------------------------------------
        left_mux_select <= 1'b1;
        right_mux_select <= 1'b0;
        data_h_in <= 32'sd100;
        in_b <= 32'sd23;                   @(posedge clk);
        #1;
        expected_32 = 32'sd123;
        if ($signed(out) !== expected_32) begin
            $display("FAIL left mux Data-H: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 7:
        // Both muxes selected should combine Data-H with the saved register.
        // Input: data_h_in = 5, saved register = 12.
        // Expected output: out = 17.
        // ------------------------------------------------
        left_mux_select <= 1'b1;
        right_mux_select <= 1'b1;
        data_h_in <= 32'sd5;               @(posedge clk);
        #1;
        expected_32 = 32'sd17;
        if ($signed(out) !== expected_32) begin
            $display("FAIL Data-H plus register: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        // ------------------------------------------------
        // Testcase 8:
        // Reset should clear the saved register even after it held 12.
        // Input: rst = 1, output_mux_select = 1.
        // Expected output: out = 0.
        // ------------------------------------------------
        rst <= 1'b1;                       @(posedge clk);
        rst <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_32 = 32'sd0;
        if ($signed(out) !== expected_32) begin
            $display("FAIL reset after save: out=%0d expected=%0d", $signed(out), expected_32);
            $stop;
        end

        $display("PASS: VPE tests passed");
        $stop;
    end

endmodule
