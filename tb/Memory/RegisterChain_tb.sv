// -----------------------------------------------------------------------------
// RegisterChain_tb.sv
//   Directed self-checking testbench for RegisterChain.
//   Run: do scripts/sim/runlab.do RegisterChain
//
//   Tests:
//     1. CHAIN_LENGTH=0: combinatorial passthrough (no clock needed).
//     2. CHAIN_LENGTH=1: output delayed by exactly 1 cycle.
//     3. CHAIN_LENGTH=4: output delayed by exactly 4 cycles.
//     4. Reset in a chained instance clears the pipeline.
//
//   SVA:
//     ap_no_x_out_c1  — no X/Z on chain-1 output after reset
//     ap_no_x_out_c4  — no X/Z on chain-4 output after reset
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module RegisterChain_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int BIT_WIDTH   = 8;
    localparam int CLK_HALF    = 5;
    localparam int RESET_CYC   = 4;
    localparam int TIMEOUT_NS  = 10_000;

    // ---- DUT signals ---------------------------------------------------------
    logic                 clk, rst;

    // Chain-0: passthrough
    logic [BIT_WIDTH-1:0] in0, out0;

    // Chain-1
    logic [BIT_WIDTH-1:0] in1, out1;

    // Chain-4
    logic [BIT_WIDTH-1:0] in4, out4;

    // ---- DUTs ----------------------------------------------------------------
    RegisterChain #(.CHAIN_LENGTH(0), .BIT_WIDTH(BIT_WIDTH)) dut0 (
        .clk(clk), .rst(rst), .in(in0), .out(out0)
    );

    RegisterChain #(.CHAIN_LENGTH(1), .BIT_WIDTH(BIT_WIDTH)) dut1 (
        .clk(clk), .rst(rst), .in(in1), .out(out1)
    );

    RegisterChain #(.CHAIN_LENGTH(4), .BIT_WIDTH(BIT_WIDTH)) dut4 (
        .clk(clk), .rst(rst), .in(in4), .out(out4)
    );

    // ---- Clock ---------------------------------------------------------------
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    // ---- Bookkeeping ---------------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;

    task automatic chk(input logic cond, input string msg);
        if (cond) pass_count++;
        else begin
            fail_count++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    task automatic do_reset();
        rst = 1'b1; in0 = '0; in1 = '0; in4 = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("RegisterChain_tb.vcd");
        $dumpvars(0, RegisterChain_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        // =====================================================================
        // TEST 1: CHAIN_LENGTH=0 — combinatorial passthrough
        // =====================================================================
        $display("-- TEST 1: Chain-0 passthrough");
        rst = 1'b0;
        in0 = 8'h00; #1;
        chk(out0 === 8'h00, "T1: out0==0x00");
        in0 = 8'hA5; #1;
        chk(out0 === 8'hA5, "T1: out0==0xA5");
        in0 = 8'hFF; #1;
        chk(out0 === 8'hFF, "T1: out0==0xFF");
        in0 = '0;

        // =====================================================================
        // TEST 2: CHAIN_LENGTH=1 — one-cycle delay
        // =====================================================================
        $display("-- TEST 2: Chain-1 one-cycle delay");
        do_reset();
        for (int i = 1; i <= 4; i++) begin
            automatic logic [BIT_WIDTH-1:0] val = BIT_WIDTH'(i * 0x11);
            @(negedge clk); in1 = val;
            @(posedge clk); @(negedge clk);
            chk(out1 === val,
                $sformatf("T2[%0d]: out1=0x%0h exp=0x%0h", i, out1, val));
        end

        // =====================================================================
        // TEST 3: CHAIN_LENGTH=4 — four-cycle delay
        //   Drive a known pattern; verify output appears 4 cycles later.
        // =====================================================================
        $display("-- TEST 3: Chain-4 four-cycle delay");
        do_reset();
        begin
            automatic logic [BIT_WIDTH-1:0] pipe[4] = '{8'hDE, 8'hAD, 8'hBE, 8'hEF};
            // Fill pipeline: drive 4 distinct values
            for (int i = 0; i < 4; i++) begin
                @(negedge clk); in4 = pipe[i];
                @(posedge clk);
            end
            // After 4 clocks, out4 should equal pipe[0]
            @(negedge clk);
            chk(out4 === pipe[0],
                $sformatf("T3[0]: out4=0x%0h exp=0x%0h", out4, pipe[0]));
            // Drain remaining
            for (int i = 1; i < 4; i++) begin
                @(negedge clk); in4 = '0;
                @(posedge clk); @(negedge clk);
                chk(out4 === pipe[i],
                    $sformatf("T3[%0d]: out4=0x%0h exp=0x%0h", i, out4, pipe[i]));
            end
        end

        // =====================================================================
        // TEST 4: Reset clears chain-4 pipeline
        // =====================================================================
        $display("-- TEST 4: Reset clears pipeline");
        do_reset();
        @(negedge clk); in4 = 8'hAA;
        @(posedge clk); @(negedge clk);
        @(negedge clk); in4 = 8'hBB;
        @(posedge clk); @(negedge clk);
        // Mid-reset with 2 values in the pipe
        @(negedge clk); rst = 1'b1; in4 = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk); rst = 1'b0;
        // Pipeline should be cleared; out4 == 0
        chk(out4 === '0, "T4: out4==0 after reset clears pipeline");

        // ---- Report ----------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("Tests run : %0d", pass_count + fail_count);
        $display("Passed    : %0d", pass_count);
        $display("Failed    : %0d", fail_count);
        if (fail_count == 0) $display("PASS");
        else                 $display("FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

    // =========================================================================
    // SVA
    // =========================================================================

    property p_no_x_out_c1;
        @(posedge clk) disable iff (rst) !$isunknown(out1);
    endproperty
    ap_no_x_out_c1: assert property (p_no_x_out_c1)
        else $error("[%0t] SVA: out1 is X/Z", $time);

    property p_no_x_out_c4;
        @(posedge clk) disable iff (rst) !$isunknown(out4);
    endproperty
    ap_no_x_out_c4: assert property (p_no_x_out_c4)
        else $error("[%0t] SVA: out4 is X/Z", $time);

endmodule

`default_nettype wire
