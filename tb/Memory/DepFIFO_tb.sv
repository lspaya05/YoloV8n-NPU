// -----------------------------------------------------------------------------
// DepFIFO_tb.sv
//   Directed self-checking testbench for DepFIFO.
//   Run: do scripts/sim/runlab.do DepFIFO
//
//   Tests:
//     1.  Reset clears mem, asserts empty, deasserts full.
//     2.  Push-only to full.
//     3.  Pop-only to empty.
//     4.  Simultaneous push+pop — mem unchanged.
//     5.  Overflow guard: push when full (SPEC test — FAILS until RTL clamping added).
//     6.  Underflow guard: pop when empty (SPEC test — FAILS until RTL clamping added).
//     7.  full/empty flag timing at boundary values.
//     8.  Back-to-back push/pop sequence (no over/underflow in stimulus).
//     9.  Reset mid-operation.
//
//   SVA:
//     ap_mem_in_range   — mem ∈ [0, DEPTH] (fires on overflow or underflow-wrap)
//     ap_full_correct   — full ↔ mem==DEPTH
//     ap_empty_correct  — empty ↔ mem==0
//     ap_mutex          — !(full && empty)
//     ap_no_x_full/empty — no X/Z on outputs
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module DepFIFO_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int DEPTH      = 4;
    localparam int MEM_W      = $clog2(DEPTH) + 1;   // 3 bits: can hold 0..7
    localparam int CLK_HALF   = 5;                    // 100 MHz
    localparam int RESET_CYC  = 4;
    localparam int TIMEOUT_NS = 10_000;

    // ---- DUT signals ---------------------------------------------------------
    logic clk, rst;
    logic push, pop;
    logic full, empty;

    // ---- DUT -----------------------------------------------------------------
    DepFIFO #(.DEPTH(DEPTH)) dut (
        .clk   (clk),
        .rst   (rst),
        .push  (push),
        .pop   (pop),
        .full  (full),
        .empty (empty)
    );

    // ---- Clock ---------------------------------------------------------------
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    // ---- Test bookkeeping ----------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;

    task automatic chk(input logic cond, input string msg);
        if (cond) pass_count++;
        else begin
            fail_count++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // ---- Reference model (clamped — represents spec) -------------------------
    int ref_count = 0;

    function automatic void ref_push_fn();
        if (ref_count < DEPTH) ref_count++;
    endfunction

    function automatic void ref_pop_fn();
        if (ref_count > 0) ref_count--;
    endfunction

    // ---- Saved state ---------------------------------------------------------
    logic [MEM_W-1:0] saved_mem;

    // ---- Reset ---------------------------------------------------------------
    // Active-high synchronous rst. Leaves sim at negedge after deassert.
    task automatic do_reset();
        rst = 1'b1; push = 1'b0; pop = 1'b0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
    endtask

    // ---- Single-cycle primitives ---------------------------------------------
    // Each task: drive on negedge → latch on posedge → settle on next negedge.
    // Returns at negedge with outputs stable.

    task automatic do_push();
        @(negedge clk); push = 1'b1; pop = 1'b0;
        @(posedge clk);
        @(negedge clk); push = 1'b0;
    endtask

    task automatic do_pop();
        @(negedge clk); push = 1'b0; pop = 1'b1;
        @(posedge clk);
        @(negedge clk); pop = 1'b0;
    endtask

    task automatic do_push_pop();
        @(negedge clk); push = 1'b1; pop = 1'b1;
        @(posedge clk);
        @(negedge clk); push = 1'b0; pop = 1'b0;
    endtask

    // ---- Back-to-back sequence task ------------------------------------------
    // ops[i][1]=push, ops[i][0]=pop. Stimulus avoids over/underflow.
    task automatic run_op_sequence(input logic [1:0] ops [8]);
        for (int i = 0; i < 8; i++) begin
            @(negedge clk);
            push = ops[i][1]; pop = ops[i][0];
            @(posedge clk);
            @(negedge clk);
            push = 1'b0; pop = 1'b0;
            case (ops[i])
                2'b10: ref_push_fn();
                2'b01: ref_pop_fn();
                default: ;
            endcase
            chk(int'(dut.mem) == ref_count,
                $sformatf("T8 op[%0d]: mem=%0d exp=%0d push=%b pop=%b",
                          i, dut.mem, ref_count, ops[i][1], ops[i][0]));
        end
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("DepFIFO_tb.vcd");
        $dumpvars(0, DepFIFO_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        // =====================================================================
        // TEST 1: Reset
        // =====================================================================
        $display("-- TEST 1: Reset");
        do_reset();
        chk(empty   === 1'b1, "T1: empty asserted after reset");
        chk(full    === 1'b0, "T1: full deasserted after reset");
        chk(dut.mem === '0,   "T1: mem == 0 after reset");

        // =====================================================================
        // TEST 2: Push-only to full
        // =====================================================================
        $display("-- TEST 2: Push to full");
        do_reset();
        repeat (DEPTH) do_push();
        chk(full          === 1'b1, "T2: full after DEPTH pushes");
        chk(empty         === 1'b0, "T2: empty deasserted");
        chk(int'(dut.mem) == DEPTH, "T2: mem == DEPTH");

        // =====================================================================
        // TEST 3: Pop-only to empty (from full)
        // =====================================================================
        $display("-- TEST 3: Pop to empty");
        repeat (DEPTH) do_pop();
        chk(empty         === 1'b1, "T3: empty after DEPTH pops");
        chk(full          === 1'b0, "T3: full deasserted");
        chk(dut.mem       === '0,   "T3: mem == 0");

        // =====================================================================
        // TEST 4: Simultaneous push+pop — mem must not change
        // =====================================================================
        $display("-- TEST 4: Simultaneous push+pop");
        do_reset();
        do_push(); do_push();          // mem = 2
        saved_mem = dut.mem;
        do_push_pop();
        chk(dut.mem === saved_mem, "T4: mem stable on push+pop");
        chk(full    === 1'b0,      "T4: not full");
        chk(empty   === 1'b0,      "T4: not empty");

        // =====================================================================
        // TEST 5: Overflow guard — push when full
        //   Expected: mem stays == DEPTH. WILL FAIL until RTL clamping added.
        // =====================================================================
        $display("-- TEST 5: Overflow guard");
        do_reset();
        repeat (DEPTH) do_push();
        chk(full === 1'b1, "T5: full before overflow attempt");
        do_push();                     // push on full
        chk(int'(dut.mem) == DEPTH,   "T5: mem unchanged (== DEPTH) on push-when-full");
        chk(full           === 1'b1,  "T5: full remains asserted");

        // =====================================================================
        // TEST 6: Underflow guard — pop when empty
        //   Expected: mem stays == 0. WILL FAIL until RTL clamping added.
        // =====================================================================
        $display("-- TEST 6: Underflow guard");
        do_reset();
        chk(empty === 1'b1, "T6: empty before underflow attempt");
        do_pop();                      // pop on empty
        chk(dut.mem === '0,           "T6: mem stays 0 on pop-when-empty");
        chk(empty   === 1'b1,         "T6: empty remains asserted");

        // =====================================================================
        // TEST 7: full/empty flag timing at boundaries
        // =====================================================================
        $display("-- TEST 7: Flag timing");
        do_reset();
        repeat (DEPTH - 1) do_push();
        chk(full  === 1'b0, "T7: not full at DEPTH-1");
        chk(empty === 1'b0, "T7: not empty at DEPTH-1");
        do_push();                     // -> full
        chk(full  === 1'b1, "T7: full exactly at DEPTH");
        do_pop();                      // -> DEPTH-1
        chk(full  === 1'b0, "T7: full deasserts one below DEPTH");
        repeat (DEPTH - 1) do_pop();   // drain
        chk(empty === 1'b1, "T7: empty after full drain");

        // =====================================================================
        // TEST 8: Back-to-back push/pop (counts stay in [0,2] — no over/underflow)
        //   Sequence: push push pop push pop pop push push
        //   Expected: 1    2    1   2    1   0   1    2
        // =====================================================================
        $display("-- TEST 8: Back-to-back");
        do_reset(); ref_count = 0;
        begin
            automatic logic [1:0] ops [8] = '{2'b10, 2'b10, 2'b01, 2'b10,
                                              2'b01, 2'b01, 2'b10, 2'b10};
            run_op_sequence(ops);
        end

        // =====================================================================
        // TEST 9: Reset mid-operation
        // =====================================================================
        $display("-- TEST 9: Reset mid-operation");
        do_reset();
        do_push(); do_push();
        chk(int'(dut.mem) == 2, "T9: mem==2 before mid-reset");
        do_reset();
        chk(empty   === 1'b1, "T9: empty after mid-reset");
        chk(dut.mem === '0,   "T9: mem==0 after mid-reset");

        // ---- Report ----------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("Tests run : %0d", pass_count + fail_count);
        $display("Passed    : %0d", pass_count);
        $display("Failed    : %0d", fail_count);
        if (fail_count == 0)
            $display("PASS");
        else
            $display("FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

    // =========================================================================
    // SVA: concurrent assertions [IEEE 1800-2017 §16]
    // =========================================================================

    // mem in [0..DEPTH] — catches overflow and underflow-wrap simultaneously
    property p_mem_in_range;
        @(posedge clk) disable iff (rst)
        dut.mem <= MEM_W'(DEPTH);
    endproperty
    ap_mem_in_range: assert property (p_mem_in_range)
        else $error("[%0t] SVA: mem=%0d out of [0..%0d]", $time, dut.mem, DEPTH);

    // full ↔ mem == DEPTH (combinational equivalence)
    property p_full_correct;
        @(posedge clk) disable iff (rst)
        full == (dut.mem == MEM_W'(DEPTH));
    endproperty
    ap_full_correct: assert property (p_full_correct)
        else $error("[%0t] SVA: full=%b mem=%0d", $time, full, dut.mem);

    // empty ↔ mem == 0
    property p_empty_correct;
        @(posedge clk) disable iff (rst)
        empty == (dut.mem == '0);
    endproperty
    ap_empty_correct: assert property (p_empty_correct)
        else $error("[%0t] SVA: empty=%b mem=%0d", $time, empty, dut.mem);

    // full and empty mutually exclusive
    property p_mutex;
        @(posedge clk) disable iff (rst)
        !(full && empty);
    endproperty
    ap_mutex: assert property (p_mutex)
        else $error("[%0t] SVA: full && empty both high", $time);

    // No X/Z on outputs after reset
    property p_no_x_full;
        @(posedge clk) disable iff (rst) !$isunknown(full);
    endproperty
    ap_no_x_full: assert property (p_no_x_full)
        else $error("[%0t] SVA: full is X/Z", $time);

    property p_no_x_empty;
        @(posedge clk) disable iff (rst) !$isunknown(empty);
    endproperty
    ap_no_x_empty: assert property (p_no_x_empty)
        else $error("[%0t] SVA: empty is X/Z", $time);

    // Cover properties
    cp_full_hit:  cover property (@(posedge clk) $rose(full));
    cp_empty_hit: cover property (@(posedge clk) $rose(empty));

endmodule

`default_nettype wire
