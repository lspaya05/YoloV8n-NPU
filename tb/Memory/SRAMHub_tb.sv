// -----------------------------------------------------------------------------
// SRAMHub_tb.sv
//   Directed self-checking testbench for SRAMHub.
//   Run: do scripts/sim/runlab.do SRAMHub
//
//   Test order:
//     1. Residual bank (DMA write / VPU read)
//     2. Output bank DMA read  (out_rd_sel=0)
//     3. Output bank HREDUCE read (out_rd_sel=1)
//     4. Requant Coeff BRAM (36-bit)
//     5. Act LUT  (dma_lut_sel=0 / vpu_lut_sel=0)
//     6. HREDUCE LUT (dma_lut_sel=1 / vpu_lut_sel=1)
//     7. Activation ping-pong (3 bank swaps, concurrent read+write)
//     8. Weight    ping-pong (3 bank swaps, concurrent read+write)
//
//   WARNING: SRAMHub passes its active-high rst directly to PingPongBuffer,
//   which expects an active-low rst.  bank_sel will not reset to 0 through
//   SRAMHub's rst.  Tests 7 & 8 assertions run regardless and will report
//   mismatches until SRAMHub.sv is fixed to pass ~rst to PingPongBuffer.
//
//   Data counter (cnt) starts at 1 and never resets across sub-tests.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module SRAMHub_tb;

    import NPU_HW_params_pkg::*;

    // ---- Parameters ----------------------------------------------------------
    localparam int CLK_HALF   = 5;       // 100 MHz
    localparam int RESET_CYC  = 4;
    localparam int TIMEOUT_NS = 500_000;
    localparam int N_SIMPLE   = 16;      // addresses tested per SimpleBRAM bank
    localparam int PP_DEPTH   = 8;       // addresses used in ping-pong sub-tests

    // ---- Clock / Reset -------------------------------------------------------
    logic clk = 1'b0;
    logic rst;
    always #CLK_HALF clk = ~clk;

    // ---- DUT signals ---------------------------------------------------------
    // Activation ping-pong
    logic [$clog2(ACT_BUF_DEPTH)-1:0] dma_act_waddr;
    logic [127:0]                      dma_act_wdata;
    logic                              dma_act_wen;
    logic                              dma_act_bank_full;
    logic [$clog2(ACT_BUF_DEPTH)-1:0] sa_act_raddr;
    logic [127:0]                      sa_act_rdata;
    logic                              sa_act_bank_read;

    // Weight ping-pong
    logic [$clog2(WT_BUF_DEPTH)-1:0]  dma_wt_waddr;
    logic [127:0]                      dma_wt_wdata;
    logic                              dma_wt_wen;
    logic                              dma_wt_bank_full;
    logic [$clog2(WT_BUF_DEPTH)-1:0]  sa_wt_raddr;
    logic [127:0]                      sa_wt_rdata;
    logic                              sa_wt_bank_read;

    // Residual bank
    logic [$clog2(RES_BANK_DEPTH)-1:0] dma_res_waddr;
    logic [127:0]                       dma_res_wdata;
    logic                               dma_res_wen;
    logic [$clog2(RES_BANK_DEPTH)-1:0] vpu_res_raddr;
    logic [127:0]                       vpu_res_rdata;

    // Output bank
    logic [$clog2(OUT_BANK_DEPTH)-1:0] vpu_out_waddr;
    logic [127:0]                       vpu_out_wdata;
    logic                               vpu_out_wen;
    logic                               out_rd_sel;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] dma_out_raddr;
    logic [127:0]                       dma_out_rdata;
    logic [$clog2(OUT_BANK_DEPTH)-1:0] vpu_hred_raddr;
    logic [127:0]                       vpu_hred_rdata;

    // Requant Coeff BRAM
    localparam int COEFF_W = COEFF_M_WIDTH + COEFF_S_WIDTH;  // 36
    logic [$clog2(MAX_CHANNELS)-1:0] dma_coeff_waddr;
    logic [COEFF_W-1:0]              dma_coeff_wdata;
    logic                            dma_coeff_wen;
    logic [$clog2(MAX_CHANNELS)-1:0] req_coeff_raddr;
    logic [COEFF_W-1:0]              req_coeff_rdata;

    // LUT
    logic [7:0] dma_lut_waddr;
    logic [7:0] dma_lut_wdata;
    logic       dma_lut_wen;
    logic       dma_lut_sel;
    logic [7:0] vpu_lut_raddr;
    logic [7:0] vpu_lut_rdata;
    logic       vpu_lut_sel;

    // ---- DUT -----------------------------------------------------------------
    SRAMHub dut (
        .clk               (clk),
        .rst               (rst),
        .dma_act_waddr     (dma_act_waddr),
        .dma_act_wdata     (dma_act_wdata),
        .dma_act_wen       (dma_act_wen),
        .dma_act_bank_full (dma_act_bank_full),
        .sa_act_raddr      (sa_act_raddr),
        .sa_act_rdata      (sa_act_rdata),
        .sa_act_bank_read  (sa_act_bank_read),
        .dma_wt_waddr      (dma_wt_waddr),
        .dma_wt_wdata      (dma_wt_wdata),
        .dma_wt_wen        (dma_wt_wen),
        .dma_wt_bank_full  (dma_wt_bank_full),
        .sa_wt_raddr       (sa_wt_raddr),
        .sa_wt_rdata       (sa_wt_rdata),
        .sa_wt_bank_read   (sa_wt_bank_read),
        .dma_res_waddr     (dma_res_waddr),
        .dma_res_wdata     (dma_res_wdata),
        .dma_res_wen       (dma_res_wen),
        .vpu_res_raddr     (vpu_res_raddr),
        .vpu_res_rdata     (vpu_res_rdata),
        .vpu_out_waddr     (vpu_out_waddr),
        .vpu_out_wdata     (vpu_out_wdata),
        .vpu_out_wen       (vpu_out_wen),
        .out_rd_sel        (out_rd_sel),
        .dma_out_raddr     (dma_out_raddr),
        .dma_out_rdata     (dma_out_rdata),
        .vpu_hred_raddr    (vpu_hred_raddr),
        .vpu_hred_rdata    (vpu_hred_rdata),
        .dma_coeff_waddr   (dma_coeff_waddr),
        .dma_coeff_wdata   (dma_coeff_wdata),
        .dma_coeff_wen     (dma_coeff_wen),
        .req_coeff_raddr   (req_coeff_raddr),
        .req_coeff_rdata   (req_coeff_rdata),
        .dma_lut_waddr     (dma_lut_waddr),
        .dma_lut_wdata     (dma_lut_wdata),
        .dma_lut_wen       (dma_lut_wen),
        .dma_lut_sel       (dma_lut_sel),
        .vpu_lut_raddr     (vpu_lut_raddr),
        .vpu_lut_rdata     (vpu_lut_rdata),
        .vpu_lut_sel       (vpu_lut_sel)
    );

    // ---- Test state ----------------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;
    int          cnt        = 1;   // global monotonic counter (never resets)

    task automatic chk128(
        input logic [127:0] got,
        input logic [127:0] exp,
        input string        msg
    );
        if (got === exp) begin
            pass_count++;
        end else begin
            fail_count++;
            $error("[%0t] FAIL %s: got=%0h  exp=%0h", $time, msg, got, exp);
        end
    endtask

    task automatic chk36(
        input logic [COEFF_W-1:0] got,
        input logic [COEFF_W-1:0] exp,
        input string               msg
    );
        if (got === exp) begin
            pass_count++;
        end else begin
            fail_count++;
            $error("[%0t] FAIL %s: got=%0h  exp=%0h", $time, msg, got, exp);
        end
    endtask

    task automatic chk8(
        input logic [7:0] got,
        input logic [7:0] exp,
        input string      msg
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
        rst = 1'b1;  // active-high: assert
        dma_act_wen = 0; dma_act_bank_full = 0; sa_act_bank_read = 0;
        dma_wt_wen  = 0; dma_wt_bank_full  = 0; sa_wt_bank_read  = 0;
        dma_res_wen = 0;
        vpu_out_wen = 0; out_rd_sel = 0;
        dma_coeff_wen = 0;
        dma_lut_wen   = 0; dma_lut_sel = 0; vpu_lut_sel = 0;
        dma_act_waddr = '0; dma_act_wdata = '0; sa_act_raddr = '0;
        dma_wt_waddr  = '0; dma_wt_wdata  = '0; sa_wt_raddr  = '0;
        dma_res_waddr = '0; dma_res_wdata  = '0; vpu_res_raddr = '0;
        vpu_out_waddr = '0; vpu_out_wdata  = '0;
        dma_out_raddr = '0; vpu_hred_raddr = '0;
        dma_coeff_waddr = '0; dma_coeff_wdata = '0; req_coeff_raddr = '0;
        dma_lut_waddr = '0; dma_lut_wdata = '0; vpu_lut_raddr = '0;
        repeat (RESET_CYC) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;  // deassert
        @(negedge clk);
    endtask

    // =========================================================================
    // Test 1: Residual bank — DMA write, VPU read
    // =========================================================================
    task automatic test_residual();
        logic [127:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 1: Residual bank", $time);
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            dma_res_waddr = $clog2(RES_BANK_DEPTH)'(a);
            dma_res_wdata = 128'(cnt);
            dma_res_wen   = 1'b1;
            golden[a]     = 128'(cnt);
            cnt++;
        end
        @(negedge clk);
        dma_res_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_res_raddr = $clog2(RES_BANK_DEPTH)'(a);
            @(posedge clk);
            @(negedge clk);
            chk128(vpu_res_rdata, golden[a], $sformatf("res[%0d]", a));
        end
    endtask

    // =========================================================================
    // Test 2: Output bank — VPU write, DMA read (out_rd_sel=0)
    // =========================================================================
    task automatic test_output_dma();
        logic [127:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 2: Output bank DMA read", $time);
        out_rd_sel = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_out_waddr = $clog2(OUT_BANK_DEPTH)'(a);
            vpu_out_wdata = 128'(cnt);
            vpu_out_wen   = 1'b1;
            golden[a]     = 128'(cnt);
            cnt++;
        end
        @(negedge clk);
        vpu_out_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            dma_out_raddr = $clog2(OUT_BANK_DEPTH)'(a);
            @(posedge clk);
            @(negedge clk);
            chk128(dma_out_rdata, golden[a], $sformatf("out_dma[%0d]", a));
        end
    endtask

    // =========================================================================
    // Test 3: Output bank — VPU write, HREDUCE read (out_rd_sel=1)
    // =========================================================================
    task automatic test_output_hred();
        logic [127:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 3: Output bank HREDUCE read", $time);
        out_rd_sel = 1'b1;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_out_waddr = $clog2(OUT_BANK_DEPTH)'(a);
            vpu_out_wdata = 128'(cnt);
            vpu_out_wen   = 1'b1;
            golden[a]     = 128'(cnt);
            cnt++;
        end
        @(negedge clk);
        vpu_out_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_hred_raddr = $clog2(OUT_BANK_DEPTH)'(a);
            @(posedge clk);
            @(negedge clk);
            chk128(vpu_hred_rdata, golden[a], $sformatf("out_hred[%0d]", a));
        end
        out_rd_sel = 1'b0;
    endtask

    // =========================================================================
    // Test 4: Requant Coeff BRAM (36-bit)
    // =========================================================================
    task automatic test_coeff();
        logic [COEFF_W-1:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 4: Coeff BRAM", $time);
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            dma_coeff_waddr = $clog2(MAX_CHANNELS)'(a);
            dma_coeff_wdata = COEFF_W'(cnt);
            dma_coeff_wen   = 1'b1;
            golden[a]       = COEFF_W'(cnt);
            cnt++;
        end
        @(negedge clk);
        dma_coeff_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            req_coeff_raddr = $clog2(MAX_CHANNELS)'(a);
            @(posedge clk);
            @(negedge clk);
            chk36(req_coeff_rdata, golden[a], $sformatf("coeff[%0d]", a));
        end
    endtask

    // =========================================================================
    // Test 5: Act LUT (8-bit, dma_lut_sel=0 / vpu_lut_sel=0)
    // =========================================================================
    task automatic test_act_lut();
        logic [7:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 5: Act LUT", $time);
        dma_lut_sel = 1'b0;
        vpu_lut_sel = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            dma_lut_waddr = 8'(a);
            dma_lut_wdata = 8'(cnt);
            dma_lut_wen   = 1'b1;
            golden[a]     = 8'(cnt);
            cnt++;
        end
        @(negedge clk);
        dma_lut_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_lut_raddr = 8'(a);
            @(posedge clk);
            @(negedge clk);
            chk8(vpu_lut_rdata, golden[a], $sformatf("act_lut[%0d]", a));
        end
    endtask

    // =========================================================================
    // Test 6: HREDUCE exp LUT (8-bit, dma_lut_sel=1 / vpu_lut_sel=1)
    // =========================================================================
    task automatic test_hred_lut();
        logic [7:0] golden [0:N_SIMPLE-1];
        $display("[%0t] Test 6: HREDUCE LUT", $time);
        dma_lut_sel = 1'b1;
        vpu_lut_sel = 1'b1;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            dma_lut_waddr = 8'(a);
            dma_lut_wdata = 8'(cnt);
            dma_lut_wen   = 1'b1;
            golden[a]     = 8'(cnt);
            cnt++;
        end
        @(negedge clk);
        dma_lut_wen = 1'b0;
        for (int a = 0; a < N_SIMPLE; a++) begin
            @(negedge clk);
            vpu_lut_raddr = 8'(a);
            @(posedge clk);
            @(negedge clk);
            chk8(vpu_lut_rdata, golden[a], $sformatf("hred_lut[%0d]", a));
        end
        dma_lut_sel = 1'b0;
        vpu_lut_sel = 1'b0;
    endtask

    // =========================================================================
    // Tests 7 & 8: Activation and Weight ping-pong (3 swaps each)
    // =========================================================================
    logic [127:0] act_golden_a [0:PP_DEPTH-1];
    logic [127:0] act_golden_b [0:PP_DEPTH-1];
    logic         act_gsel = 1'b0;

    logic [127:0] wt_golden_a [0:PP_DEPTH-1];
    logic [127:0] wt_golden_b [0:PP_DEPTH-1];
    logic         wt_gsel = 1'b0;

    // Fills the inactive act bank; optionally fires bank_read simultaneously.
    task automatic act_fill_inactive(input logic assert_bank_read);
        for (int a = 0; a < PP_DEPTH; a++) begin
            @(negedge clk);
            dma_act_waddr     = $clog2(ACT_BUF_DEPTH)'(a);
            dma_act_wdata     = 128'(cnt);
            dma_act_wen       = 1'b1;
            dma_act_bank_full = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            sa_act_bank_read  = (a == PP_DEPTH - 1) ? assert_bank_read : 1'b0;
            if (act_gsel == 1'b0) act_golden_b[a] = 128'(cnt);
            else                  act_golden_a[a] = 128'(cnt);
            cnt++;
        end
        @(posedge clk);
        @(negedge clk);
        dma_act_wen = 1'b0; dma_act_bank_full = 1'b0; sa_act_bank_read = 1'b0;
        act_gsel = ~act_gsel;
    endtask

    // Simultaneously reads active act bank and writes inactive act bank.
    task automatic act_read_while_write();
        for (int a = 0; a < PP_DEPTH; a++) begin
            @(negedge clk);
            sa_act_raddr      = $clog2(ACT_BUF_DEPTH)'(a);
            dma_act_waddr     = $clog2(ACT_BUF_DEPTH)'(a);
            dma_act_wdata     = 128'(cnt);
            dma_act_wen       = 1'b1;
            dma_act_bank_full = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            sa_act_bank_read  = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            if (act_gsel == 1'b0) act_golden_b[a] = 128'(cnt);
            else                  act_golden_a[a] = 128'(cnt);
            cnt++;
            if (a > 0) begin
                if (act_gsel == 1'b0)
                    chk128(sa_act_rdata, act_golden_a[a-1],
                           $sformatf("act BankA[%0d]", a-1));
                else
                    chk128(sa_act_rdata, act_golden_b[a-1],
                           $sformatf("act BankB[%0d]", a-1));
            end
        end
        @(posedge clk);
        @(negedge clk);
        dma_act_wen = 1'b0; dma_act_bank_full = 1'b0; sa_act_bank_read = 1'b0;
        if (act_gsel == 1'b0)
            chk128(sa_act_rdata, act_golden_a[PP_DEPTH-1],
                   $sformatf("act BankA[%0d]", PP_DEPTH-1));
        else
            chk128(sa_act_rdata, act_golden_b[PP_DEPTH-1],
                   $sformatf("act BankB[%0d]", PP_DEPTH-1));
        act_gsel = ~act_gsel;
    endtask

    // Fills the inactive weight bank; optionally fires bank_read simultaneously.
    task automatic wt_fill_inactive(input logic assert_bank_read);
        for (int a = 0; a < PP_DEPTH; a++) begin
            @(negedge clk);
            dma_wt_waddr     = $clog2(WT_BUF_DEPTH)'(a);
            dma_wt_wdata     = 128'(cnt);
            dma_wt_wen       = 1'b1;
            dma_wt_bank_full = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            sa_wt_bank_read  = (a == PP_DEPTH - 1) ? assert_bank_read : 1'b0;
            if (wt_gsel == 1'b0) wt_golden_b[a] = 128'(cnt);
            else                 wt_golden_a[a] = 128'(cnt);
            cnt++;
        end
        @(posedge clk);
        @(negedge clk);
        dma_wt_wen = 1'b0; dma_wt_bank_full = 1'b0; sa_wt_bank_read = 1'b0;
        wt_gsel = ~wt_gsel;
    endtask

    // Simultaneously reads active weight bank and writes inactive weight bank.
    task automatic wt_read_while_write();
        for (int a = 0; a < PP_DEPTH; a++) begin
            @(negedge clk);
            sa_wt_raddr      = $clog2(WT_BUF_DEPTH)'(a);
            dma_wt_waddr     = $clog2(WT_BUF_DEPTH)'(a);
            dma_wt_wdata     = 128'(cnt);
            dma_wt_wen       = 1'b1;
            dma_wt_bank_full = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            sa_wt_bank_read  = (a == PP_DEPTH - 1) ? 1'b1 : 1'b0;
            if (wt_gsel == 1'b0) wt_golden_b[a] = 128'(cnt);
            else                 wt_golden_a[a] = 128'(cnt);
            cnt++;
            if (a > 0) begin
                if (wt_gsel == 1'b0)
                    chk128(sa_wt_rdata, wt_golden_a[a-1],
                           $sformatf("wt BankA[%0d]", a-1));
                else
                    chk128(sa_wt_rdata, wt_golden_b[a-1],
                           $sformatf("wt BankB[%0d]", a-1));
            end
        end
        @(posedge clk);
        @(negedge clk);
        dma_wt_wen = 1'b0; dma_wt_bank_full = 1'b0; sa_wt_bank_read = 1'b0;
        if (wt_gsel == 1'b0)
            chk128(sa_wt_rdata, wt_golden_a[PP_DEPTH-1],
                   $sformatf("wt BankA[%0d]", PP_DEPTH-1));
        else
            chk128(sa_wt_rdata, wt_golden_b[PP_DEPTH-1],
                   $sformatf("wt BankB[%0d]", PP_DEPTH-1));
        wt_gsel = ~wt_gsel;
    endtask

    // ---- Main ----------------------------------------------------------------
    initial begin
        $dumpfile("SRAMHub_tb.vcd");
        $dumpvars(0, SRAMHub_tb);

        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        do_reset();

        // SimpleBRAM sub-tests (unaffected by the ping-pong reset polarity bug)
        test_residual();
        test_output_dma();
        test_output_hred();
        test_coeff();
        test_act_lut();
        test_hred_lut();

        // Test 7: Activation ping-pong (3 swaps)
        // See WARNING in file header re: reset polarity — assertions run anyway.
        $display("[%0t] Test 7: Activation ping-pong", $time);
        $display("[%0t] WARNING: ping-pong results undefined until SRAMHub rst polarity fixed",
                 $time);
        act_fill_inactive(1'b1);    // pre-fill + Swap 1
        act_read_while_write();     // Swap 2
        act_read_while_write();     // Swap 3
        act_read_while_write();     // Swap 4 (confirms 3 are done)

        // Test 8: Weight ping-pong (3 swaps)
        $display("[%0t] Test 8: Weight ping-pong", $time);
        $display("[%0t] WARNING: ping-pong results undefined until SRAMHub rst polarity fixed",
                 $time);
        wt_fill_inactive(1'b1);
        wt_read_while_write();
        wt_read_while_write();
        wt_read_while_write();

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
