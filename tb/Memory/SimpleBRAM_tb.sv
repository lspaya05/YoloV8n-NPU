// -----------------------------------------------------------------------------
// SimpleBRAM_tb.sv
//   Directed self-checking testbench for SimpleBRAM.
//   Run: do scripts/sim/runlab.do SimpleBRAM
//
//   Tests:
//     1. Sequential writes then reads verify 1-cycle read latency.
//     2. Write-read to same address immediately (read one cycle after write).
//     3. Overwrite: second write to same address visible on next read.
//     4. All-zero write clears a location.
//     5. Full address sweep: write then read all DEPTH locations.
//
//   SVA:
//     ap_no_x_rdata — no X/Z on r_data for any address that has been written
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module SimpleBRAM_tb;

    // ---- Parameters ----------------------------------------------------------
    localparam int DEPTH      = 16;
    localparam int DATA_WIDTH = 8;
    localparam int ADDR_W     = $clog2(DEPTH);
    localparam int CLK_HALF   = 5;
    localparam int TIMEOUT_NS = 20_000;

    // ---- DUT signals ---------------------------------------------------------
    logic                 clk;
    logic [ADDR_W-1:0]    w_addr, r_addr;
    logic [DATA_WIDTH-1:0] w_data;
    logic                 w_en;
    logic [DATA_WIDTH-1:0] r_data;

    // ---- DUT -----------------------------------------------------------------
    SimpleBRAM #(.DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk   (clk),
        .w_addr(w_addr),
        .w_data(w_data),
        .w_en  (w_en),
        .r_addr(r_addr),
        .r_data(r_data)
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

    // ---- Write helper (one cycle) --------------------------------------------
    task automatic do_write(input logic [ADDR_W-1:0] addr,
                            input logic [DATA_WIDTH-1:0] data);
        @(negedge clk);
        w_en = 1'b1; w_addr = addr; w_data = data;
        @(posedge clk); @(negedge clk);
        w_en = 1'b0;
    endtask

    // ---- Read helper (issue addr, wait one cycle, sample r_data) ------------
    task automatic do_read(input  logic [ADDR_W-1:0]    addr,
                           output logic [DATA_WIDTH-1:0] data);
        @(negedge clk);
        r_addr = addr;
        @(posedge clk); @(negedge clk);
        data = r_data;
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("SimpleBRAM_tb.vcd");
        $dumpvars(0, SimpleBRAM_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        w_en = 1'b0; w_addr = '0; w_data = '0; r_addr = '0;
        @(posedge clk); @(negedge clk);

        // =====================================================================
        // TEST 1: Write then read back (1-cycle latency)
        // =====================================================================
        $display("-- TEST 1: Write-then-read latency");
        begin
            automatic logic [DATA_WIDTH-1:0] rd;
            do_write(4'h3, 8'hA5);
            do_read(4'h3, rd);
            chk(rd === 8'hA5, $sformatf("T1: rd=0x%0h exp=0xA5", rd));
        end

        // =====================================================================
        // TEST 2: Immediate read after write same address
        // =====================================================================
        $display("-- TEST 2: Same-cycle write/read pipe");
        begin
            automatic logic [DATA_WIDTH-1:0] rd;
            // Write addr 5, then issue read to addr 5 one cycle later
            do_write(4'h5, 8'hDE);
            // r_addr already set in do_read; issue read immediately
            do_read(4'h5, rd);
            chk(rd === 8'hDE, $sformatf("T2: rd=0x%0h exp=0xDE", rd));
        end

        // =====================================================================
        // TEST 3: Overwrite — second write replaces first
        // =====================================================================
        $display("-- TEST 3: Overwrite");
        begin
            automatic logic [DATA_WIDTH-1:0] rd;
            do_write(4'h7, 8'h11);
            do_write(4'h7, 8'h22);
            do_read(4'h7, rd);
            chk(rd === 8'h22, $sformatf("T3: rd=0x%0h exp=0x22", rd));
        end

        // =====================================================================
        // TEST 4: All-zero write
        // =====================================================================
        $display("-- TEST 4: All-zero write");
        begin
            automatic logic [DATA_WIDTH-1:0] rd;
            do_write(4'hB, 8'hFF);
            do_write(4'hB, 8'h00);
            do_read(4'hB, rd);
            chk(rd === 8'h00, $sformatf("T4: rd=0x%0h exp=0x00", rd));
        end

        // =====================================================================
        // TEST 5: Full address sweep
        // =====================================================================
        $display("-- TEST 5: Full address sweep");
        begin
            automatic logic [DATA_WIDTH-1:0] rd;
            // Write all addresses
            for (int a = 0; a < DEPTH; a++) begin
                do_write(ADDR_W'(a), DATA_WIDTH'(a * 5 + 1));
            end
            // Read all addresses
            for (int a = 0; a < DEPTH; a++) begin
                automatic logic [DATA_WIDTH-1:0] exp = DATA_WIDTH'(a * 5 + 1);
                do_read(ADDR_W'(a), rd);
                chk(rd === exp,
                    $sformatf("T5[%0d]: rd=0x%0h exp=0x%0h", a, rd, exp));
            end
        end

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
    // SVA — after a write completes, r_data must not be X/Z when read back
    // =========================================================================

    // Track whether any address has been written (crude: any write done)
    logic write_seen;
    initial write_seen = 1'b0;
    always @(posedge clk)
        if (w_en) write_seen <= 1'b1;

    property p_no_x_rdata;
        @(posedge clk)
        write_seen |-> !$isunknown(r_data);
    endproperty
    ap_no_x_rdata: assert property (p_no_x_rdata)
        else $error("[%0t] SVA: r_data is X/Z after writes have occurred", $time);

endmodule

`default_nettype wire
