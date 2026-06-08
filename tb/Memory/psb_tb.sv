// -----------------------------------------------------------------------------
// psb_tb.sv
//   Directed self-checking testbench for psb (Partial Sum Buffer).
//   Run: do scripts/sim/runlab.do psb
//
//   Parameters: ARRAY_HEIGHT=4, ARRAY_LENGTH=4 (power-of-2, fast sim).
//
//   Tests:
//     1. Reset: FSM in s0, busy==0, row_out_valid==0.
//     2. Accumulate: psb_acc, 4 rows of row_valid -> acc_done pulse.
//     3. Flush: psb_flush -> 4 rows output, flush_done pulse.
//     4. Flush data integrity: verify requant_row_out matches accumulated sums.
//     5. Busy signal: high during acc and flush, low in idle/done.
//     6. Reset mid-accumulate clears FSM.
//
//   SVA:
//     ap_busy_mutex     — busy deasserted only in s0/s3
//     ap_no_x_valid     — no X/Z on row_out_valid after reset
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module psb_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int ACCUM_W     = 32;
    localparam int HEIGHT      = 4;
    localparam int LENGTH      = 4;
    localparam int CLK_HALF    = 5;
    localparam int RESET_CYC   = 4;
    localparam int TIMEOUT_NS  = 50_000;

    // ---- DUT signals ---------------------------------------------------------
    logic clk, rst;
    logic psb_acc, psb_flush;
    logic row_valid;
    logic signed [ACCUM_W-1:0] sa_row_in [LENGTH-1:0];

    logic [LENGTH*ACCUM_W-1:0]    requant_row_out;
    logic [$clog2(HEIGHT)-1:0]    row_index_out;
    logic                         row_out_valid;
    logic                         acc_done;
    logic                         flush_done;
    logic                         busy;

    // ---- DUT -----------------------------------------------------------------
    psb #(
        .ACCUMULATOR_BITWIDTH(ACCUM_W),
        .ARRAY_HEIGHT        (HEIGHT),
        .ARRAY_LENGTH        (LENGTH)
    ) dut (
        .clk           (clk),
        .rst           (rst),
        .psb_acc       (psb_acc),
        .psb_flush     (psb_flush),
        .row_valid     (row_valid),
        .sa_capture    (1'b0),
        .sa_row_in     (sa_row_in),
        .requant_row_out(requant_row_out),
        .row_index_out (row_index_out),
        .row_out_valid (row_out_valid),
        .acc_done      (acc_done),
        .flush_done    (flush_done),
        .busy          (busy)
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

    // ---- Reset ---------------------------------------------------------------
    task automatic do_reset();
        rst = 1'b1; psb_acc = 1'b0; psb_flush = 1'b0;
        row_valid = 1'b0;
        foreach (sa_row_in[i]) sa_row_in[i] = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk); rst = 1'b0;
        @(negedge clk);
    endtask

    // ---- Accumulate full tile ------------------------------------------------
    // Drives HEIGHT rows with distinct data; waits for acc_done.
    // Returns the data driven so the caller can verify flush output.
    logic signed [ACCUM_W-1:0] acc_ref [HEIGHT-1:0][LENGTH-1:0];

    task automatic do_accumulate();
        // Assert psb_acc with the first row, then stream the remaining rows.
        for (int r = 0; r < HEIGHT; r++) begin
            @(negedge clk);
            psb_acc = (r == 0);
            row_valid = 1'b1;
            for (int c = 0; c < LENGTH; c++) begin
                sa_row_in[c]      = 32'(r * LENGTH + c + 1);
                acc_ref[r][c]     = sa_row_in[c];  // first accumulation, no prior sum
            end
            @(posedge clk); @(negedge clk);
            psb_acc = 1'b0;
            row_valid = 1'b0;
        end

        // acc_done fires after the last row is accepted.
        while (!acc_done) @(posedge clk);
        #1ps;
        chk(acc_done === 1'b1, "acc: acc_done asserted after full tile");
        @(posedge clk); @(negedge clk);
    endtask

    // ---- Flush full tile -----------------------------------------------------
    // Waits HEIGHT cycles for rows, captures output, checks flush_done.
    task automatic do_flush();
        @(negedge clk); psb_flush = 1'b1;
        @(posedge clk); @(negedge clk); psb_flush = 1'b0;

        // Collect HEIGHT output rows
        for (int r = 0; r < HEIGHT; r++) begin
            chk(row_out_valid === 1'b1,
                $sformatf("flush r%0d: row_out_valid high", r));
            chk(int'(row_index_out) === r,
                $sformatf("flush r%0d: row_index_out==%0d", r, r));

            // Verify each column
            for (int c = 0; c < LENGTH; c++) begin
                automatic logic signed [ACCUM_W-1:0] got;
                got = requant_row_out[(c*ACCUM_W) +: ACCUM_W];
                chk(got === acc_ref[r][c],
                    $sformatf("flush r%0d c%0d: got=%0d exp=%0d",
                              r, c, got, acc_ref[r][c]));
            end
            @(posedge clk); @(negedge clk);
        end

        // flush_done fires in s3
        chk(flush_done === 1'b1, "flush: flush_done asserted");
        @(posedge clk); @(negedge clk);
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("psb_tb.vcd");
        $dumpvars(0, psb_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        // =====================================================================
        // TEST 1: Reset state
        // =====================================================================
        $display("-- TEST 1: Reset");
        do_reset();
        chk(busy          === 1'b0, "T1: busy==0 in idle");
        chk(row_out_valid === 1'b0, "T1: row_out_valid==0");
        chk(acc_done      === 1'b0, "T1: acc_done==0");
        chk(flush_done    === 1'b0, "T1: flush_done==0");

        // =====================================================================
        // TEST 2: Accumulate — acc_done fires after full tile
        // =====================================================================
        $display("-- TEST 2: Accumulate");
        do_reset();
        chk(busy === 1'b0, "T2: idle before acc");
        do_accumulate();
        chk(busy === 1'b0, "T2: idle after acc completes");

        // =====================================================================
        // TEST 3 + 4: Flush — flush_done fires, data matches reference
        // =====================================================================
        $display("-- TEST 3+4: Flush data integrity");
        do_flush();
        chk(busy === 1'b0, "T3: idle after flush completes");

        // =====================================================================
        // TEST 5: Busy high during acc and flush
        // =====================================================================
        $display("-- TEST 5: Busy signal");
        do_reset();
        @(negedge clk); psb_acc = 1'b1;
        @(posedge clk); @(negedge clk); psb_acc = 1'b0;
        chk(busy === 1'b1, "T5: busy==1 during accumulate");
        // Drain accumulation
        for (int r = 0; r < HEIGHT; r++) begin
            @(negedge clk); row_valid = 1'b1;
            foreach (sa_row_in[c]) sa_row_in[c] = '0;
            @(posedge clk); @(negedge clk);
        end
        row_valid = 1'b0;
        @(posedge clk); @(negedge clk); // s3
        @(posedge clk); @(negedge clk); // back to s0
        chk(busy === 1'b0, "T5: busy==0 after acc done");

        // =====================================================================
        // TEST 6: Reset mid-accumulate
        // =====================================================================
        $display("-- TEST 6: Reset mid-accumulate");
        do_reset();
        @(negedge clk); psb_acc = 1'b1;
        @(posedge clk); @(negedge clk); psb_acc = 1'b0;
        // Send one row then reset
        @(negedge clk); row_valid = 1'b1;
        foreach (sa_row_in[c]) sa_row_in[c] = 32'hDEAD;
        @(posedge clk); @(negedge clk); row_valid = 1'b0;
        do_reset();
        chk(busy          === 1'b0, "T6: busy==0 after mid-acc reset");
        chk(acc_done      === 1'b0, "T6: acc_done==0 after reset");
        chk(row_out_valid === 1'b0, "T6: row_out_valid==0 after reset");

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

    property p_no_x_valid;
        @(posedge clk) disable iff (rst) !$isunknown(row_out_valid);
    endproperty
    ap_no_x_valid: assert property (p_no_x_valid)
        else $error("[%0t] SVA: row_out_valid is X/Z", $time);

    property p_no_x_busy;
        @(posedge clk) disable iff (rst) !$isunknown(busy);
    endproperty
    ap_no_x_busy: assert property (p_no_x_busy)
        else $error("[%0t] SVA: busy is X/Z", $time);

    // acc_done and flush_done must never assert simultaneously
    property p_done_mutex;
        @(posedge clk) disable iff (rst)
        !(acc_done && flush_done);
    endproperty
    ap_done_mutex: assert property (p_done_mutex)
        else $error("[%0t] SVA: acc_done && flush_done both high", $time);

    cp_acc_done:   cover property (@(posedge clk) $rose(acc_done));
    cp_flush_done: cover property (@(posedge clk) $rose(flush_done));

endmodule

`default_nettype wire
