// -----------------------------------------------------------------------------
// PingPongBuffer_tb.sv
//   Directed self-checking testbench for PingPongBuffer.
//   Run: do scripts/sim/runlab.do PingPongBuffer
//
//   Sequence:
//     1. Pre-fill inactive bank (Bank B), data 1..DEPTH.
//     2. Swap 1 → read Bank B while writing Bank A (data DEPTH+1..).
//     3. Swap 2 → read Bank A while writing Bank B.
//     4. Swap 3 → read Bank B while writing Bank A.
//   Data counter never resets — always increasing by 1.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module PingPongBuffer_tb;

    import NPU_HW_params_pkg::*;

    // ---- Parameters ----------------------------------------------------------
    localparam int DEPTH      = 8;       // small for fast sim (one pass = 8 cycles)
    localparam int DBITS      = 128;
    localparam int CLK_HALF   = 5;       // 100 MHz
    localparam int RESET_CYC  = 4;
    localparam int TIMEOUT_NS = 20_000;

    // ---- DUT signals ---------------------------------------------------------
    logic                         clk;
    logic                         rst;
    logic [DBITS-1:0]             w_data;
    logic [$clog2(DEPTH)-1:0]     w_addr;
    logic                         write_en;
    logic                         bank_full;
    logic [$clog2(DEPTH)-1:0]     r_addr;
    logic [DBITS-1:0]             r_data;
    logic                         bank_read;

    // ---- DUT -----------------------------------------------------------------
    PingPongBuffer #(
        .BUFFER_DEPTH (DEPTH),
        .DATA_BITWIDTH(DBITS)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .w_data    (w_data),
        .w_addr    (w_addr),
        .write_en  (write_en),
        .bank_full (bank_full),
        .r_addr    (r_addr),
        .r_data    (r_data),
        .bank_read (bank_read)
    );

    // ---- Clock ---------------------------------------------------------------
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    // ---- Test state ----------------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;
    int          cnt        = 1;    // global monotonic write counter (never resets)

    // Golden model: mirrors what was written to each physical bank.
    // gsel=0: Bank A is SA-side, Bank B is DMA-side (matches initial bank_sel=0).
    // gsel=1: Bank B is SA-side, Bank A is DMA-side.
    logic [DBITS-1:0] golden_a [0:DEPTH-1];
    logic [DBITS-1:0] golden_b [0:DEPTH-1];
    logic             gsel = 0;

    // ---- Helpers -------------------------------------------------------------
    task automatic chk(
        input logic [DBITS-1:0] got,
        input logic [DBITS-1:0] exp,
        input string            msg
    );
        if (got === exp) begin
            pass_count++;
        end else begin
            fail_count++;
            $error("[%0t] FAIL %s: got=%0h  exp=%0h", $time, msg, got, exp);
        end
    endtask

    // ---- Reset ---------------------------------------------------------------
    task automatic do_reset();
        rst = 1'b0;  // active-low: assert reset
        write_en = 0; bank_full = 0; bank_read = 0;
        w_addr = '0; w_data = '0; r_addr = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        rst = 1'b1;  // deassert
        @(negedge clk);
    endtask

    // ---- fill_inactive -------------------------------------------------------
    // Writes DEPTH words into the currently-inactive bank.
    // assert_bank_read=1: fire bank_read simultaneously on the last cycle
    //                     (used for the initial fill where SA has nothing to drain).
    // Updates golden model and flips gsel.
    task automatic fill_inactive(input logic assert_bank_read);
        for (int a = 0; a < DEPTH; a++) begin
            @(negedge clk);
            w_addr    = $clog2(DEPTH)'(a);
            w_data    = DBITS'(cnt);
            write_en  = 1'b1;
            bank_full = (a == DEPTH - 1) ? 1'b1 : 1'b0;
            bank_read = (a == DEPTH - 1) ? assert_bank_read : 1'b0;
            // Inactive bank: B when gsel=0, A when gsel=1
            if (gsel == 1'b0) golden_b[a] = DBITS'(cnt);
            else              golden_a[a] = DBITS'(cnt);
            cnt++;
        end
        // The posedge in this cycle latches the last write AND triggers the swap.
        @(posedge clk);
        @(negedge clk);
        write_en  = 1'b0;
        bank_full = 1'b0;
        bank_read = 1'b0;
        gsel = ~gsel;  // swap has occurred
    endtask

    // ---- read_while_write ----------------------------------------------------
    // Simultaneously reads from the active bank and writes to the inactive bank.
    // Asserts bank_full + bank_read on the last cycle to trigger the next swap.
    // Checks: r_data (1-cycle latency) against golden of the active bank.
    // Updates golden model for the newly-written inactive bank and flips gsel.
    task automatic read_while_write();
        for (int a = 0; a < DEPTH; a++) begin
            @(negedge clk);
            // Read port → active bank
            r_addr    = $clog2(DEPTH)'(a);
            // Write port → inactive bank
            w_addr    = $clog2(DEPTH)'(a);
            w_data    = DBITS'(cnt);
            write_en  = 1'b1;
            // Trigger next swap on the last address
            bank_full = (a == DEPTH - 1) ? 1'b1 : 1'b0;
            bank_read = (a == DEPTH - 1) ? 1'b1 : 1'b0;
            // Update golden for the inactive bank
            if (gsel == 1'b0) golden_b[a] = DBITS'(cnt);
            else              golden_a[a] = DBITS'(cnt);
            cnt++;
            // Check the previous cycle's read (available 1 cycle after r_addr)
            if (a > 0) begin
                if (gsel == 1'b0)
                    chk(r_data, golden_a[a-1], $sformatf("rd BankA[%0d]", a-1));
                else
                    chk(r_data, golden_b[a-1], $sformatf("rd BankB[%0d]", a-1));
            end
        end
        // The posedge here latches r_data for the last address AND triggers swap.
        @(posedge clk);
        @(negedge clk);
        write_en  = 1'b0;
        bank_full = 1'b0;
        bank_read = 1'b0;
        // Check the last address (now available in r_data)
        if (gsel == 1'b0)
            chk(r_data, golden_a[DEPTH-1], $sformatf("rd BankA[%0d]", DEPTH-1));
        else
            chk(r_data, golden_b[DEPTH-1], $sformatf("rd BankB[%0d]", DEPTH-1));
        gsel = ~gsel;  // swap has occurred
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("PingPongBuffer_tb.vcd");
        $dumpvars(0, PingPongBuffer_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        do_reset();

        // Phase 0: fill inactive bank B with data 1-8, swap immediately.
        // bank_read asserted right away — nothing in Bank A to drain after reset.
        fill_inactive(1'b1);                // → Swap 1

        // Phase 1, Swap 2, Swap 3, Swap 4:
        // Each call simultaneously reads the active bank and fills the inactive bank,
        // then triggers the next swap. 3 calls = 3 bank_sel flips after the pre-fill.
        read_while_write();                 // Swap 2
        read_while_write();                 // Swap 3
        read_while_write();                 // Swap 4 (confirms 3 are done)

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

endmodule

`default_nettype wire
