// -----------------------------------------------------------------------------
// D_FF_tb.sv
//   Directed self-checking testbench for D_FF.
//   Run: do scripts/sim/runlab.do D_FF
//
//   Tests:
//     1. Reset forces output to zero.
//     2. Data captured one cycle after input is driven.
//     3. Output tracks sequential input changes.
//     4. Reset mid-operation clears output.
//
//   SVA:
//     ap_dff_capture — out == $past(in) when previous cycle not in reset
//     ap_no_x_out   — no X/Z on out after reset deasserts
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module D_FF_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int BIT_WIDTH  = 8;
    localparam int CLK_HALF   = 5;     // 100 MHz
    localparam int RESET_CYC  = 3;
    localparam int TIMEOUT_NS = 5_000;

    // ---- DUT signals ---------------------------------------------------------
    logic                 clk, rst;
    logic [BIT_WIDTH-1:0] in, out;

    // ---- DUT -----------------------------------------------------------------
    D_FF #(.BIT_WIDTH(BIT_WIDTH)) dut (
        .clk(clk), .rst(rst), .in(in), .out(out)
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
        rst = 1'b1; in = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("D_FF_tb.vcd");
        $dumpvars(0, D_FF_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        // =====================================================================
        // TEST 1: Reset forces output to zero
        // =====================================================================
        $display("-- TEST 1: Reset");
        rst = 1'b1; in = 8'hAB;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        chk(out === '0, "T1: out == 0 during reset");
        rst = 1'b0;

        // =====================================================================
        // TEST 2: Data captured one cycle later
        // =====================================================================
        $display("-- TEST 2: Capture");
        do_reset();
        @(negedge clk); in = 8'h5A;
        @(posedge clk); @(negedge clk);
        chk(out === 8'h5A, "T2: out == 0x5A one cycle after input");

        // =====================================================================
        // TEST 3: Output tracks sequential input changes
        // =====================================================================
        $display("-- TEST 3: Sequential updates");
        do_reset();
        for (int i = 0; i < 8; i++) begin
            automatic logic [BIT_WIDTH-1:0] val = BIT_WIDTH'(i * 17);
            @(negedge clk); in = val;
            @(posedge clk); @(negedge clk);
            chk(out === val,
                $sformatf("T3[%0d]: out=0x%0h expected=0x%0h", i, out, val));
        end

        // =====================================================================
        // TEST 4: Reset mid-operation clears output
        // =====================================================================
        $display("-- TEST 4: Mid-op reset");
        do_reset();
        @(negedge clk); in = 8'hFF;
        @(posedge clk); @(negedge clk);
        chk(out === 8'hFF, "T4: out==0xFF before mid-op reset");
        @(negedge clk); rst = 1'b1;
        @(posedge clk); @(negedge clk);
        chk(out === '0, "T4: out==0 after mid-op reset");
        rst = 1'b0;

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

    // When previous cycle was not in reset, out must equal $past(in)
    property p_dff_capture;
        @(posedge clk) disable iff (rst)
        !$past(rst) |-> out == $past(in);
    endproperty
    ap_dff_capture: assert property (p_dff_capture)
        else $error("[%0t] SVA: out=0x%0h != past(in)=0x%0h", $time, out, $past(in));

    property p_no_x_out;
        @(posedge clk) disable iff (rst) !$isunknown(out);
    endproperty
    ap_no_x_out: assert property (p_no_x_out)
        else $error("[%0t] SVA: out is X/Z", $time);

endmodule

`default_nettype wire
