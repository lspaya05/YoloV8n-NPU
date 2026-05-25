// =============================================================================
// File        : Sequencer_tb.sv
// Project     : EE470 Neural Engine — KR260
// Description : Directed self-checking testbench for Sequencer.
//               Run: do scripts/sim/runlab.do Sequencer
// =============================================================================
`timescale 1ns/1ps
`default_nettype none

import NPU_ISA_pkg::*;

module Sequencer_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int CLK_HALF_NS  = 5;       // 100 MHz
    localparam int RESET_CYCLES = 4;
    localparam int TIMEOUT_NS   = 100_000;

    // =========================================================================
    // DUT I/O
    // =========================================================================
    logic clk;
    logic rst;

    // AXI-Lite slave (TB is master)
    logic [31:0] s_axil_awaddr;
    logic        s_axil_awvalid;
    logic        s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic        s_axil_wvalid;
    logic        s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;

    // AXI4 read master (TB is memory slave)
    logic [43:0] m_axi_araddr;
    logic        m_axi_arvalid;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic        m_axi_arready;
    logic [31:0] m_axi_rdata;
    logic        m_axi_rvalid;
    logic        m_axi_rlast;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rready;

    // Dispatch
    logic [115:0] fifo_payload;
    logic [5:0]   fifo_push;
    logic [5:0]   fifo_full;

    // Synchronization
    logic [5:0]  unit_done;

    // CONFIG shadow outputs
    logic [7:0]  cfg_tile_M;
    logic [7:0]  cfg_tile_N;
    logic [7:0]  cfg_tile_K;
    logic [3:0]  cfg_stride;
    logic [1:0]  cfg_pad_mode;
    logic [31:0] cfg_coeff_base;
    logic [2:0]  cfg_act_type;
    logic [2:0]  cfg_pool_size;

    // Status
    logic irq_done;
    logic fetch_err;

    // =========================================================================
    // DUT instance
    // =========================================================================
    Sequencer dut (
        .clk            (clk),
        .rst            (rst),
        .s_axil_awaddr  (s_axil_awaddr),
        .s_axil_awvalid (s_axil_awvalid),
        .s_axil_awready (s_axil_awready),
        .s_axil_wdata   (s_axil_wdata),
        .s_axil_wvalid  (s_axil_wvalid),
        .s_axil_wready  (s_axil_wready),
        .s_axil_bresp   (s_axil_bresp),
        .s_axil_bvalid  (s_axil_bvalid),
        .s_axil_bready  (s_axil_bready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rready   (m_axi_rready),
        .fifo_payload   (fifo_payload),
        .fifo_push      (fifo_push),
        .fifo_full      (fifo_full),
        .unit_done      (unit_done),
        .cfg_tile_M     (cfg_tile_M),
        .cfg_tile_N     (cfg_tile_N),
        .cfg_tile_K     (cfg_tile_K),
        .cfg_stride     (cfg_stride),
        .cfg_pad_mode   (cfg_pad_mode),
        .cfg_coeff_base (cfg_coeff_base),
        .cfg_act_type   (cfg_act_type),
        .cfg_pool_size  (cfg_pool_size),
        .irq_done       (irq_done),
        .fetch_err      (fetch_err)
    );

    // =========================================================================
    // Clock
    // =========================================================================
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // =========================================================================
    // Bookkeeping
    // =========================================================================
    int err_cnt;

    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // =========================================================================
    // Helper: pack 128-bit instruction
    // =========================================================================
    function automatic logic [127:0] build_instr(
        input npu_opcode_e  opcode,
        input npu_unit_e    unit_id,
        input logic [3:0]   dep_flags,
        input logic [111:0] payload
    );
        return {opcode, unit_id, dep_flags, payload};
    endfunction

    // =========================================================================
    // BFM: AXI-Lite write (drives AW + W simultaneously)
    // =========================================================================
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        s_axil_awaddr  <= addr;
        s_axil_awvalid <= 1'b1;
        s_axil_wdata   <= data;
        s_axil_wvalid  <= 1'b1;
        @(posedge clk);
        while (!(s_axil_awready && s_axil_wready)) @(posedge clk);
        s_axil_awvalid <= 1'b0;
        s_axil_wvalid  <= 1'b0;
        s_axil_bready  <= 1'b1;
        while (!s_axil_bvalid) @(posedge clk);
        @(posedge clk);
        s_axil_bready  <= 1'b0;
    endtask

    // =========================================================================
    // BFM: AXI4 read slave — respond to one 4-beat burst
    // =========================================================================
    task automatic axi_fetch_respond(
        input logic [127:0] instr128,
        input logic [1:0]   rresp_val = 2'b00
    );
        // Wait for DUT to assert AR request
        while (!m_axi_arvalid) @(posedge clk);
        m_axi_arready <= 1'b1;
        @(posedge clk);              // AR handshake; DUT next-state = S_R
        m_axi_arready <= 1'b0;
        // Send 4 beats LSB-first; DUT drives rready when state == S_R
        for (int beat = 0; beat < 4; beat++) begin
            while (!m_axi_rready) @(posedge clk);
            m_axi_rdata  <= instr128[beat*32 +: 32];
            m_axi_rvalid <= 1'b1;
            m_axi_rresp  <= rresp_val;
            m_axi_rlast  <= (beat == 3) ? 1'b1 : 1'b0;
            @(posedge clk);
            m_axi_rvalid <= 1'b0;
            m_axi_rlast  <= 1'b0;
        end
        m_axi_rresp <= 2'b00;
    endtask

    // =========================================================================
    // Helper: write instr_count + kick
    // =========================================================================
    task automatic do_kick(input logic [31:0] n);
        axil_write(32'h04, n);
        axil_write(32'h08, 32'd1);
    endtask

    // =========================================================================
    // Reset
    // =========================================================================
    task automatic do_reset();
        rst            <= 1'b1;
        s_axil_awvalid <= 1'b0;
        s_axil_wvalid  <= 1'b0;
        s_axil_bready  <= 1'b0;
        m_axi_arready  <= 1'b0;
        m_axi_rvalid   <= 1'b0;
        m_axi_rlast    <= 1'b0;
        m_axi_rresp    <= 2'b0;
        m_axi_rdata    <= '0;
        fifo_full      <= 6'b0;
        unit_done      <= 6'b0;
        repeat (RESET_CYCLES) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    initial begin
        err_cnt = 0;

        fork begin
            #TIMEOUT_NS;
            $fatal(1, "TIMEOUT after %0d ns", TIMEOUT_NS);
        end join_none

        do_reset();

        // ---------------------------------------------------------------------
        // T1: Reset — all key outputs zero
        // ---------------------------------------------------------------------
        #1ps;
        chk(fifo_push     == 6'b0, "T1: fifo_push=0 after reset");
        chk(irq_done      == 1'b0, "T1: irq_done=0 after reset");
        chk(fetch_err     == 1'b0, "T1: fetch_err=0 after reset");
        chk(m_axi_arvalid == 1'b0, "T1: arvalid=0 after reset");
        chk(s_axil_bvalid == 1'b0, "T1: bvalid=0 after reset");
        $display("T1 DONE: reset checks");

        // ---------------------------------------------------------------------
        // T2: CSR writes without kick — no fetch, no dispatch
        // ---------------------------------------------------------------------
        axil_write(32'h00, 32'hDEAD_0000);   // instr_base
        axil_write(32'h04, 32'd1);            // instr_count
        @(posedge clk); #1ps;
        chk(fifo_push     == 6'b0, "T2: no dispatch without kick");
        chk(m_axi_arvalid == 1'b0, "T2: no fetch without kick");
        $display("T2 DONE: CSR write, no kick");

        // ---------------------------------------------------------------------
        // T3: CONFIG instruction — shadow registers must update
        // ---------------------------------------------------------------------
        begin : t3
            npu_cfg_payload_t cfg_p;
            logic [111:0]     pload;
            logic [127:0]     instr;
            cfg_p          = '0;
            cfg_p.tile_M   = 8'd8;
            cfg_p.tile_N   = 8'd16;
            cfg_p.tile_K   = 8'd32;
            cfg_p.stride   = 4'd2;
            cfg_p.pad_mode = 2'd1;
            cfg_p.act_type = 3'd1;
            cfg_p.pool_size = 3'd3;
            cfg_p.coeff_base = 32'hABCD_0000;
            pload = cfg_p;
            instr = build_instr(OP_CONFIG, UNIT_SEQ, 4'h0, pload);
            axil_write(32'h00, 32'h0010_0000);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            @(posedge clk); #1ps;    // S_DISPATCH: cfg registers updated
            chk(cfg_tile_M    == 8'd8,           "T3: tile_M");
            chk(cfg_tile_N    == 8'd16,          "T3: tile_N");
            chk(cfg_tile_K    == 8'd32,          "T3: tile_K");
            chk(cfg_stride    == 4'd2,           "T3: stride");
            chk(cfg_pad_mode  == 2'd1,           "T3: pad_mode");
            chk(cfg_act_type  == 3'd1,           "T3: act_type");
            chk(cfg_pool_size == 3'd3,           "T3: pool_size");
            chk(cfg_coeff_base == 32'hABCD_0000, "T3: coeff_base");
            chk(fifo_push     == 6'b0,           "T3: no FIFO push for CONFIG");
            $display("T3 DONE: CONFIG shadow registers");
        end

        // ---------------------------------------------------------------------
        // T4: DMA_LOAD → fifo_push[0], payload preserved
        // ---------------------------------------------------------------------
        begin : t4
            logic [127:0] instr;
            instr = build_instr(OP_DMA_LOAD, UNIT_DMA, 4'hA, 112'hBEEF);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            @(posedge clk); #1ps;    // S_DISPATCH fires push strobe
            chk(fifo_push         == 6'b00_0001, "T4: fifo_push[0]");
            chk(fifo_payload[115:112] == 4'hA,   "T4: dep_flags");
            chk(fifo_payload[111:0]   == 112'hBEEF, "T4: payload");
            $display("T4 DONE: DMA_LOAD dispatch");
        end

        // ---------------------------------------------------------------------
        // T5: WT_LOAD → fifo_push[5]
        // ---------------------------------------------------------------------
        begin : t5
            logic [127:0] instr;
            instr = build_instr(OP_WT_LOAD, UNIT_DMA, 4'h0, 112'h1234);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b10_0000, "T5: fifo_push[5] for WT_LOAD");
            $display("T5 DONE: WT_LOAD dispatch");
        end

        // ---------------------------------------------------------------------
        // T6: SA / PSB / REQ / VPU dispatch (one instruction each)
        // ---------------------------------------------------------------------
        begin : t6
            logic [127:0] instr;

            instr = build_instr(OP_MATMUL,  UNIT_SA,  4'h0, 112'h0);
            do_kick(32'd1); axi_fetch_respond(instr);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_0010, "T6: fifo_push[1] MATMUL/SA");

            instr = build_instr(OP_PSB_ACC, UNIT_PSB, 4'h0, 112'h0);
            do_kick(32'd1); axi_fetch_respond(instr);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_0100, "T6: fifo_push[2] PSB_ACC");

            instr = build_instr(OP_REQUANT, UNIT_REQ, 4'h0, 112'h0);
            do_kick(32'd1); axi_fetch_respond(instr);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_1000, "T6: fifo_push[3] REQUANT");

            instr = build_instr(OP_RELU,    UNIT_VPU, 4'h0, 112'h0);
            do_kick(32'd1); axi_fetch_respond(instr);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b01_0000, "T6: fifo_push[4] RELU/VPU");
            $display("T6 DONE: SA/PSB/REQ/VPU dispatch");
        end

        // ---------------------------------------------------------------------
        // T7: FENCE — FSM stalls; releases on matching unit_done
        // ---------------------------------------------------------------------
        begin : t7
            npu_fence_payload_t fence_p;
            logic [111:0]       pload;
            logic [127:0]       instr;
            fence_p           = '0;
            fence_p.unit_mask = 6'b00_0110;    // wait DMA(1) + SA(2)
            pload = fence_p;
            instr = build_instr(OP_FENCE, UNIT_SEQ, 4'h0, pload);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            // FSM: S_R → S_DISPATCH → S_FENCE; verify stall for 5 cycles
            repeat(5) begin
                @(posedge clk); #1ps;
                chk(fifo_push == 6'b0, "T7: no push during FENCE stall");
            end
            // Release: assert matching unit_done
            unit_done <= 6'b00_0110;
            repeat(4) @(posedge clk);   // exit S_FENCE → S_AR(remaining=0) → S_IDLE
            unit_done <= 6'b0;
            #1ps;
            chk(m_axi_arvalid == 1'b0, "T7: no fetch after FENCE (remaining=0)");
            $display("T7 DONE: FENCE stall + release");
        end

        // ---------------------------------------------------------------------
        // T8: FIFO full stall — FSM holds S_DISPATCH until fifo_full deasserted
        // ---------------------------------------------------------------------
        begin : t8
            logic [127:0] instr;
            instr = build_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0, 112'h0);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            // State just transitioned to S_DISPATCH; assert full BEFORE next posedge
            fifo_full <= 6'b00_0001;
            repeat(3) begin
                @(posedge clk); #1ps;
                chk(fifo_push == 6'b0, "T8: no push while fifo_full asserted");
            end
            // Release stall
            fifo_full <= 6'b0;
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_0001, "T8: push after fifo_full deasserted");
            $display("T8 DONE: FIFO full stall");
        end

        // ---------------------------------------------------------------------
        // T9: AXI read error → fetch_err set, FSM halts, no dispatch
        // ---------------------------------------------------------------------
        begin : t9
            logic [127:0] instr;
            instr = build_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0, 112'h0);
            do_kick(32'd1);
            axi_fetch_respond(instr, 2'b10);    // SLVERR on all beats
            @(posedge clk); #1ps;               // would be S_DISPATCH if no error
            chk(fetch_err     == 1'b1, "T9: fetch_err set on SLVERR");
            chk(fifo_push     == 6'b0, "T9: no dispatch on AXI error");
            chk(m_axi_arvalid == 1'b0, "T9: FSM halted in S_IDLE");
            $display("T9 DONE: AXI error halt");
        end

        // ---------------------------------------------------------------------
        // T10: irq_done — exactly 1-cycle pulse after job + unit_done[1]
        // ---------------------------------------------------------------------
        begin : t10
            logic [127:0] instr;
            int           irq_cycles;
            // Reset to clear fetch_err from T9
            do_reset();
            instr = build_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0, 112'h0);
            do_kick(32'd1);
            axi_fetch_respond(instr);
            // Wait for FSM to finish dispatch and return to S_IDLE
            repeat(6) @(posedge clk);
            // Assert DMA done; irq_done should pulse exactly once
            unit_done <= 6'b00_0010;
            irq_cycles = 0;
            repeat(5) begin
                @(posedge clk); #1ps;
                if (irq_done) irq_cycles++;
            end
            unit_done <= 6'b0;
            chk(irq_cycles == 1, "T10: irq_done pulses exactly 1 cycle");
            $display("T10 DONE: irq_done 1-cycle pulse");
        end

        // ---------------------------------------------------------------------
        // T11: 5-instruction program: CONFIG→DMA_LOAD→WT_LOAD→MATMUL→FENCE
        // ---------------------------------------------------------------------
        begin : t11
            logic [127:0]       prog[5];
            npu_cfg_payload_t   cfg_p;
            npu_fence_payload_t fence_p;
            logic [111:0]       pload;
            int                 irq_cycles;

            cfg_p        = '0;
            cfg_p.tile_M = 8'd4;
            pload = cfg_p;
            prog[0] = build_instr(OP_CONFIG,   UNIT_SEQ, 4'h0, pload);
            prog[1] = build_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0, 112'h0);
            prog[2] = build_instr(OP_WT_LOAD,  UNIT_DMA, 4'h0, 112'h0);
            prog[3] = build_instr(OP_MATMUL,   UNIT_SA,  4'h0, 112'h0);
            fence_p           = '0;
            fence_p.unit_mask = 6'b00_0110;
            pload = fence_p;
            prog[4] = build_instr(OP_FENCE, UNIT_SEQ, 4'h0, pload);

            do_kick(32'd5);

            // [0] CONFIG
            axi_fetch_respond(prog[0]);
            @(posedge clk); #1ps;
            chk(cfg_tile_M == 8'd4,    "T11: CONFIG tile_M=4");
            chk(fifo_push  == 6'b0,    "T11: no push for CONFIG");

            // [1] DMA_LOAD → push[0]
            axi_fetch_respond(prog[1]);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_0001, "T11: DMA_LOAD push[0]");

            // [2] WT_LOAD → push[5]
            axi_fetch_respond(prog[2]);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b10_0000, "T11: WT_LOAD push[5]");

            // [3] MATMUL → push[1]
            axi_fetch_respond(prog[3]);
            @(posedge clk); #1ps;
            chk(fifo_push == 6'b00_0010, "T11: MATMUL push[1]");

            // [4] FENCE — stall then release
            axi_fetch_respond(prog[4]);
            repeat(3) begin
                @(posedge clk); #1ps;
                chk(fifo_push == 6'b0, "T11: no push during FENCE");
            end
            unit_done <= 6'b00_0110;
            repeat(4) @(posedge clk);
            unit_done <= 6'b0;
            // FSM now S_IDLE; wait for irq_done pulse when DMA signals done
            repeat(4) @(posedge clk);
            unit_done <= 6'b00_0010;
            irq_cycles = 0;
            repeat(5) begin
                @(posedge clk); #1ps;
                if (irq_done) irq_cycles++;
            end
            unit_done <= 6'b0;
            chk(irq_cycles == 1, "T11: irq_done pulse after program completes");
            $display("T11 DONE: 5-instruction program");
        end

        // ---------------------------------------------------------------------
        // Final report
        // ---------------------------------------------------------------------
        $display("============================================================");
        $display("Errors : %0d", err_cnt);
        if (err_cnt == 0)
            $display("PASS");
        else
            $display("FAIL");
        $display("============================================================");
        if (err_cnt != 0) $fatal(1);
        $finish;
    end

endmodule

`default_nettype wire
