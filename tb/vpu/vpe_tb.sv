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

    // Logic needed for the VPE INT8 data inputs and output
    logic [7:0] in_a;
    logic [7:0] in_b;
    logic [7:0] data_h_in;
    logic [7:0] out;

    // Logic needed to check the output values
    logic signed [7:0] expected_8;

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
        in_a <= 8'sd0;
        in_b <= 8'sd0;
        data_h_in <= 8'sd0;

        // Testcase 1: Reset should clear the internal VPE register.
                                            @(posedge clk);
        rst <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_8 = 8'sd0;
        if ($signed(out) !== expected_8) begin
            $display("FAIL reset register: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 2: Direct ADD path should use in_a and in_b.
        output_mux_select <= 1'b0;
        left_mux_select <= 1'b0;
        right_mux_select <= 1'b0;
        register_enable <= 1'b0;
        fu_opcode <= 3'b000;
        in_a <= 8'sd5;
        in_b <= 8'sd7;                     @(posedge clk);
        #1;
        expected_8 = 8'sd12;
        if ($signed(out) !== expected_8) begin
            $display("FAIL direct ADD: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 3: Register enable should save the FU result on the clock edge.
        register_enable <= 1'b1;           @(posedge clk);
        register_enable <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_8 = 8'sd12;
        if ($signed(out) !== expected_8) begin
            $display("FAIL register save: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 4: HOLD should keep forwarding the saved register even when inputs change.
        in_a <= 8'sd100;
        in_b <= 8'sd20;                    @(posedge clk);
        #1;
        expected_8 = 8'sd12;
        if ($signed(out) !== expected_8) begin
            $display("FAIL HOLD changed inputs: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 5: Right mux should choose the saved VPE register when selected.
        output_mux_select <= 1'b0;
        left_mux_select <= 1'b0;
        right_mux_select <= 1'b1;
        fu_opcode <= 3'b000;
        in_a <= 8'sd10;                    @(posedge clk);
        #1;
        expected_8 = 8'sd22;
        if ($signed(out) !== expected_8) begin
            $display("FAIL right mux register: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 6: Left mux should choose Data-H when selected.
        left_mux_select <= 1'b1;
        right_mux_select <= 1'b0;
        data_h_in <= 8'sd100;
        in_b <= 8'sd23;                    @(posedge clk);
        #1;
        expected_8 = 8'sd123;
        if ($signed(out) !== expected_8) begin
            $display("FAIL left mux Data-H: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 7: Both muxes selected should combine Data-H with the saved register.
        left_mux_select <= 1'b1;
        right_mux_select <= 1'b1;
        data_h_in <= 8'sd5;                @(posedge clk);
        #1;
        expected_8 = 8'sd17;
        if ($signed(out) !== expected_8) begin
            $display("FAIL Data-H plus register: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        // Testcase 8: Reset should clear the saved register even after it held 12.
        rst <= 1'b1;                       @(posedge clk);
        rst <= 1'b0;
        output_mux_select <= 1'b1;         @(posedge clk);
        #1;
        expected_8 = 8'sd0;
        if ($signed(out) !== expected_8) begin
            $display("FAIL reset after save: out=%0d expected=%0d", $signed(out), expected_8);
            $stop;
        end

        $display("PASS: VPE INT8 tests passed");
        $stop;
    end

endmodule
