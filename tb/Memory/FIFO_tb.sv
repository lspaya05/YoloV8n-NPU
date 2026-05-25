// -----------------------------------------------------------------------------
// FIFO_tb.sv
//   Directed self-checking testbench for FIFO.
//   Run via: do scripts/sim/runlab.do FIFO
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module FIFO_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int DATA_WIDTH     = 8;
    localparam int DEPTH          = 4;
    localparam int USE_XILINX_XPM = 0;
    localparam int CLK_HALF_NS    = 5;
    localparam int RESET_CYCLES   = 4;
    localparam int TIMEOUT_NS     = 20_000;

    // ---- Signals -------------------------------------------------------------
    logic                  clk;
    logic                  rst;
    logic                  wr_en;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic                  full;
    logic                  empty;

    // ---- DUT -----------------------------------------------------------------
    FIFO #(
        .USE_XILINX_XPM (USE_XILINX_XPM),
        .DATA_WIDTH     (DATA_WIDTH),
        .DEPTH          (DEPTH)
    ) dut (
        .clk   (clk),
        .rst   (rst),
        .wr_en (wr_en),
        .rd_en (rd_en),
        .din   (din),
        .dout  (dout),
        .full  (full),
        .empty (empty)
    );

    // ---- Clock ---------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_HALF_NS) clk = ~clk;

    // ---- Bookkeeping ---------------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;

    task automatic check(input logic cond, input string msg);
        if (cond) begin
            pass_count++;
            $display("  PASS: %s", msg);
        end else begin
            fail_count++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // ---- Reset ---------------------------------------------------------------
    task automatic do_reset();
        rst   = 1'b1;
        wr_en = 1'b0;
        rd_en = 1'b0;
        din   = '0;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(posedge clk); #1;
    endtask

    // ---- Primitives ----------------------------------------------------------
    // Drive on negedge; exit 1ps after the next posedge (outputs settle).
    task automatic write1(input logic [DATA_WIDTH-1:0] d);
        @(negedge clk);
        wr_en = 1'b1; din = d;
        @(posedge clk); #1;
        wr_en = 1'b0;
    endtask

    // rd_en asserted for one posedge; caller must wait one more cycle for dout.
    task automatic read1();
        @(negedge clk);
        rd_en = 1'b1;
        @(posedge clk); #1;
        rd_en = 1'b0;
    endtask

    // Drain until empty; exits at posedge+1ps after last read settles.
    task automatic drain_all();
        while (!empty) begin
            read1();
            @(posedge clk); #1;
        end
    endtask

    // ---- SVA concurrent assertions -------------------------------------------
    // FIFO cannot be simultaneously full and empty.
    property p_no_full_and_empty;
        @(posedge clk) disable iff (rst)
        !(full && empty);
    endproperty
    assert property (p_no_full_and_empty)
        else $error("[%0t] SVA: full && empty both asserted", $time);

    // full must not change unless wr_en or rd_en was active.
    property p_full_stable;
        @(posedge clk) disable iff (rst)
        (!wr_en && !rd_en) |=> $stable(full);
    endproperty
    assert property (p_full_stable)
        else $error("[%0t] SVA: full toggled without wr_en/rd_en", $time);

    // empty must not change unless wr_en or rd_en was active.
    property p_empty_stable;
        @(posedge clk) disable iff (rst)
        (!wr_en && !rd_en) |=> $stable(empty);
    endproperty
    assert property (p_empty_stable)
        else $error("[%0t] SVA: empty toggled without wr_en/rd_en", $time);

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("FIFO_tb.vcd");
        $dumpvars(0, FIFO_tb);

        fork begin
            #(TIMEOUT_NS);
            $error("TIMEOUT at %0d ns — simulation hung", TIMEOUT_NS);
            $finish;
        end join_none

        do_reset();

        // ====================================================================
        // T1: Read while empty — empty must hold, no corruption.
        // ====================================================================
        $display("\n[T1] Read while empty");
        check(empty === 1'b1, "T1.1 empty after reset");
        check(full  === 1'b0, "T1.2 not full after reset");
        @(negedge clk);
        rd_en = 1'b1;
        @(posedge clk); #1;
        check(empty === 1'b1, "T1.3 empty holds during bogus read");
        rd_en = 1'b0;
        @(posedge clk); #1;
        check(empty === 1'b1, "T1.4 empty holds after bogus read");

        // ====================================================================
        // T2: Fill to DEPTH (writing 1..DEPTH), then attempt overflow write.
        // ====================================================================
        $display("\n[T2] Fill to DEPTH=%0d then overflow write", DEPTH);
        for (int i = 1; i <= DEPTH; i++) begin
            write1(DATA_WIDTH'(i));
            @(posedge clk); #1;
            if (i < DEPTH)
                check(full === 1'b0, $sformatf("T2.a not full after %0d writes", i));
        end
        check(full  === 1'b1, "T2.b full after DEPTH writes");
        check(empty === 1'b0, "T2.c not empty when full");

        begin : blk_overflow
            logic [DATA_WIDTH-1:0] snap;
            snap = dout;
            write1(8'hFF);       // overflow: must be ignored
            @(posedge clk); #1;
            check(full === 1'b1, "T2.d still full after overflow write");
            check(dout === snap, "T2.e dout unchanged after overflow write");
        end

        // ====================================================================
        // T3: Simultaneous rd+wr while full — balanced, FIFO stays full.
        // ====================================================================
        $display("\n[T3] Simultaneous rd+wr while full");
        @(negedge clk);
        rd_en = 1'b1; wr_en = 1'b1; din = 8'hAB;
        @(posedge clk); #1;
        rd_en = 1'b0; wr_en = 1'b0;
        @(posedge clk); #1;
        check(empty === 1'b0, "T3.a not empty after balanced rd+wr from full");
        check(full  === 1'b1, "T3.b still full after balanced rd+wr");

        // Drain to empty and verify read order.
        // Fill was [01,02,03,04]; T3 popped 01 and pushed AB → [02,03,04,AB].
        $display("\n[T3->T4] Drain and verify read order (exp: 02 03 04 AB)");
        begin : blk_drain
            logic [DATA_WIDTH-1:0] exp[4] = '{8'h02, 8'h03, 8'h04, 8'hAB};
            logic [DATA_WIDTH-1:0] got;
            for (int i = 0; i < DEPTH; i++) begin
                read1();
                @(posedge clk); #1;   // one extra cycle for registered dout
                got = dout;
                check(got === exp[i],
                      $sformatf("T3->T4 drain[%0d]: got %0h exp %0h", i, got, exp[i]));
            end
        end
        @(posedge clk); #1;
        check(empty === 1'b1, "T3->T4 empty after drain");
        check(full  === 1'b0, "T3->T4 not full after drain");

        // ====================================================================
        // T4: Simultaneous rd+wr while empty — must not underflow.
        // ====================================================================
        $display("\n[T4] Simultaneous rd+wr while empty");
        check(empty === 1'b1, "T4.0 confirm empty");
        @(negedge clk);
        rd_en = 1'b1; wr_en = 1'b1; din = 8'hCA;
        @(posedge clk); #1;
        rd_en = 1'b0; wr_en = 1'b0;
        @(posedge clk); #1;
        check(full === 1'b0, "T4.a not full after empty rd+wr");

        // ====================================================================
        // T5: Drain back to empty ("pull from empty back down").
        // ====================================================================
        $display("\n[T5] Drain back to empty");
        drain_all();
        check(empty === 1'b1, "T5.a empty after final drain");
        check(full  === 1'b0, "T5.b not full after final drain");
        // extra read confirms empty is stable
        @(negedge clk);
        rd_en = 1'b1;
        @(posedge clk); #1;
        check(empty === 1'b1, "T5.c empty holds on extra read after drain");
        rd_en = 1'b0;
        @(posedge clk); #1;

        // ====================================================================
        // Report
        // ====================================================================
        $display("\n------------------------------------------------------------");
        $display("Tests run : %0d", pass_count + fail_count);
        $display("Passed    : %0d", pass_count);
        $display("Failed    : %0d", fail_count);
        if (fail_count == 0) $display("PASS");
        else                 $display("FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule

`default_nettype wire
