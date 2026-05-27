// Testbench for DMA — Phase 1–7 port set
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;

module DMA_tb();

    localparam int ClkHalfNs = 5;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rst;

    // Ch0 descriptor
    logic [31:0] src_base;
    logic [15:0] row_stride;
    logic [7:0]  tile_w, tile_h, ch_count;
    logic [3:0]  pad_top, pad_bot, pad_left, pad_right;
    logic [2:0]  fetch_mode;
    logic [31:0] concat_base;
    logic [9:0]  coeff_ch_count;
    logic        lut_sel;

    // Ch1 descriptor + start
    logic        ch1_start;
    logic [31:0] wt_src_base;

    // Handshake / status
    logic        start;
    logic        ch0_idle, ch1_idle;
    logic        dma_act_bank_full, dma_wt_bank_full;
    logic        dma_store_done;
    logic        dma_err;

    // HP0 read master
    logic [43:0]  hp0_araddr;
    logic         hp0_arvalid;
    logic [7:0]   hp0_arlen;
    logic [2:0]   hp0_arsize;
    logic [1:0]   hp0_arburst;
    logic [3:0]   hp0_arcache;
    logic         hp0_arready;
    logic [127:0] hp0_rdata;
    logic         hp0_rvalid;
    logic         hp0_rlast;
    logic [1:0]   hp0_rresp;
    logic         hp0_rready;

    // HP1 read master (WT_LOAD)
    logic [43:0]  hp1_araddr;
    logic         hp1_arvalid;
    logic [7:0]   hp1_arlen;
    logic [2:0]   hp1_arsize;
    logic [1:0]   hp1_arburst;
    logic [3:0]   hp1_arcache;
    logic         hp1_arready;
    logic [127:0] hp1_rdata;
    logic         hp1_rvalid;
    logic         hp1_rlast;
    logic [1:0]   hp1_rresp;
    logic         hp1_rready;

    // HP2 write master (DMA_STORE)
    logic [43:0]  hp2_awaddr;
    logic         hp2_awvalid;
    logic [7:0]   hp2_awlen;
    logic [2:0]   hp2_awsize;
    logic [1:0]   hp2_awburst;
    logic [3:0]   hp2_awcache;
    logic         hp2_awready;
    logic [127:0] hp2_wdata;
    logic [15:0]  hp2_wstrb;
    logic         hp2_wlast;
    logic         hp2_wvalid;
    logic         hp2_wready;
    logic [1:0]   hp2_bresp;
    logic         hp2_bvalid;
    logic         hp2_bready;

    // SRAM ports
    logic [$clog2(RES_BANK_DEPTH)-1:0]            sram_waddr;
    logic [127:0]                                  sram_wdata;
    logic                                          sram_wen;
    logic [$clog2(WT_BUF_DEPTH)-1:0]               sram_wt_waddr;
    logic [127:0]                                  sram_wt_wdata;
    logic                                          sram_wt_wen;
    logic [$clog2(MAX_CHANNELS)-1:0]               sram_coeff_waddr;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]        sram_coeff_wdata;
    logic                                          sram_coeff_wen;
    logic [$clog2(LUT_DEPTH)-1:0]                  sram_lut_waddr;
    logic [7:0]                                    sram_lut_wdata;
    logic                                          sram_lut_wen;
    logic                                          sram_lut_sel;
    logic [$clog2(RES_BANK_DEPTH)-1:0]            sram_raddr;
    logic [127:0]                                  sram_rdata;

    // Dep ports (driven inactive; DMA still references them via lint suppressor)
    logic dep_sa_to_dma_empty, dep_vpu_to_dma_empty;
    logic dep_dma_to_sa_full,  dep_dma_to_vpu_full;
    logic dep_sa_to_dma_pop,   dep_vpu_to_dma_pop;
    logic dep_dma_to_sa_push,  dep_dma_to_vpu_push;

    // -------------------------------------------------------------------------
    // SRAM models
    // -------------------------------------------------------------------------
    logic [127:0] act_mem  [0:RES_BANK_DEPTH-1];
    logic [127:0] wt_mem   [0:WT_BUF_DEPTH-1];
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] coeff_mem [0:MAX_CHANNELS-1];
    logic [7:0]   lut_mem  [0:LUT_DEPTH-1];
    logic [127:0] out_mem  [0:RES_BANK_DEPTH-1];   // Output bank, source for STORE

    logic [127:0] ddr_words   [0:1023];            // DDR read pool (HP0 / HP1)
    logic [127:0] store_words [0:255];             // captured by HP2 write slave
    int           store_count;
    int           err_cnt;

    // DUT
    DMA dut (.*);

    // Clock
    initial clk = 1'b0;
    always #ClkHalfNs clk = ~clk;

    // SRAM read port for STORE: combinational from out_mem (1-cycle latency
    // implied by DMA's PRIME1/PRIME2 pipeline — model is synchronous read).
    always @(posedge clk) sram_rdata <= out_mem[sram_raddr];

    // Capture writes into the SRAM models
    always @(posedge clk) begin
        if (sram_wen)       act_mem[sram_waddr]        <= sram_wdata;
        if (sram_wt_wen)    wt_mem[sram_wt_waddr]      <= sram_wt_wdata;
        if (sram_coeff_wen) coeff_mem[sram_coeff_waddr]<= sram_coeff_wdata;
        if (sram_lut_wen)   lut_mem[sram_lut_waddr]    <= sram_lut_wdata;
    end

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    function automatic int word_index(input logic [43:0] addr);
        return int'(addr[19:4]);  // 1024-entry DDR pool, 16 B per word
    endfunction

    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    task automatic init_inputs();
        src_base = 32'h0;  row_stride = 16'h10;
        tile_w = 8'h1;     tile_h = 8'h1;    ch_count = 8'h10;
        pad_top = 4'h0;    pad_bot = 4'h0;
        pad_left = 4'h0;   pad_right = 4'h0;
        fetch_mode = 3'b000;
        concat_base = 32'h0;
        coeff_ch_count = 10'h0;
        lut_sel = 1'b0;
        ch1_start = 1'b0;  wt_src_base = 32'h0;
        start = 1'b0;
        hp0_arready = 1'b0;
        hp0_rdata = 128'h0;  hp0_rvalid = 1'b0;
        hp0_rlast = 1'b0;    hp0_rresp = 2'b00;
        hp1_arready = 1'b0;
        hp1_rdata = 128'h0;  hp1_rvalid = 1'b0;
        hp1_rlast = 1'b0;    hp1_rresp = 2'b00;
        hp2_awready = 1'b0;  hp2_wready = 1'b0;
        hp2_bresp = 2'b00;   hp2_bvalid = 1'b0;
        dep_sa_to_dma_empty  = 1'b0;
        dep_vpu_to_dma_empty = 1'b0;
        dep_dma_to_sa_full   = 1'b0;
        dep_dma_to_vpu_full  = 1'b0;
        store_count = 0;
    endtask

    task automatic reset_dut();
        rst = 1'b1;
        init_inputs();
        for (int i = 0; i < RES_BANK_DEPTH; i++) begin act_mem[i] = 128'h0; out_mem[i] = 128'h0; end
        for (int i = 0; i < WT_BUF_DEPTH;   i++) wt_mem[i]   = 128'h0;
        for (int i = 0; i < MAX_CHANNELS;   i++) coeff_mem[i]= '0;
        for (int i = 0; i < LUT_DEPTH;      i++) lut_mem[i]  = 8'h0;
        for (int i = 0; i < 1024; i++) ddr_words[i] = {120'h0, 8'(i)};
        for (int i = 0; i < 256;  i++) store_words[i] = 128'h0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    task automatic pulse_start();
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
    endtask

    task automatic pulse_ch1_start();
        @(posedge clk);
        ch1_start = 1'b1;
        @(posedge clk);
        ch1_start = 1'b0;
    endtask

    // AXI read slave: serves N bursts of arlen+1 beats from ddr_words[].
    task automatic hp0_read_serve(input int bursts, input logic [1:0] resp = 2'b00);
        logic [43:0] addr;
        int beats;
        for (int b = 0; b < bursts; b++) begin
            while (!hp0_arvalid) @(posedge clk);
            addr  = hp0_araddr;
            beats = hp0_arlen + 1;
            hp0_arready = 1'b1;
            @(posedge clk);
            hp0_arready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                while (!hp0_rready) @(posedge clk);
                hp0_rdata  = ddr_words[word_index(addr) + beat];
                hp0_rresp  = resp;
                hp0_rlast  = (beat == beats - 1);
                hp0_rvalid = 1'b1;
                @(posedge clk);
                hp0_rvalid = 1'b0;
                hp0_rlast  = 1'b0;
            end
            hp0_rresp = 2'b00;
        end
    endtask

    task automatic hp1_read_serve(input int bursts, input logic [1:0] resp = 2'b00);
        logic [43:0] addr;
        int beats;
        for (int b = 0; b < bursts; b++) begin
            while (!hp1_arvalid) @(posedge clk);
            addr  = hp1_araddr;
            beats = hp1_arlen + 1;
            hp1_arready = 1'b1;
            @(posedge clk);
            hp1_arready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                while (!hp1_rready) @(posedge clk);
                hp1_rdata  = ddr_words[word_index(addr) + beat];
                hp1_rresp  = resp;
                hp1_rlast  = (beat == beats - 1);
                hp1_rvalid = 1'b1;
                @(posedge clk);
                hp1_rvalid = 1'b0;
                hp1_rlast  = 1'b0;
            end
            hp1_rresp = 2'b00;
        end
    endtask

    // AXI write slave: captures one burst into store_words[].
    task automatic hp2_write_serve(input logic [1:0] resp = 2'b00);
        int beats;
        while (!hp2_awvalid) @(posedge clk);
        beats = hp2_awlen + 1;
        hp2_awready = 1'b1;
        @(posedge clk);
        hp2_awready = 1'b0;

        hp2_wready = 1'b1;
        for (int beat = 0; beat < beats; beat++) begin
            while (!hp2_wvalid) @(posedge clk);
            store_words[store_count] = hp2_wdata;
            store_count++;
            @(posedge clk);
        end
        hp2_wready = 1'b0;

        hp2_bresp  = resp;
        hp2_bvalid = 1'b1;
        while (!hp2_bready) @(posedge clk);
        @(posedge clk);
        hp2_bvalid = 1'b0;
    endtask

    // Wait for Ch0 to return to idle after a start pulse (with timeout).
    task automatic wait_ch0_idle(input int timeout_cycles = 2000);
        int cnt = 0;
        // wait until ch0_idle deasserts (FSM entered)
        while (ch0_idle && cnt < 50) begin @(posedge clk); cnt++; end
        // then wait for re-assertion
        cnt = 0;
        while (!ch0_idle && cnt < timeout_cycles) begin @(posedge clk); cnt++; end
        chk(cnt < timeout_cycles, "timeout waiting for ch0_idle");
        @(posedge clk);
    endtask

    task automatic wait_ch1_idle(input int timeout_cycles = 2000);
        int cnt = 0;
        while (ch1_idle && cnt < 50) begin @(posedge clk); cnt++; end
        cnt = 0;
        while (!ch1_idle && cnt < timeout_cycles) begin @(posedge clk); cnt++; end
        chk(cnt < timeout_cycles, "timeout waiting for ch1_idle");
        @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------
    initial begin
        err_cnt = 0;
        reset_dut();
        #1ps;

        // T1: Reset idle + AXI constants
        chk(ch0_idle && ch1_idle && !hp0_arvalid && !hp1_arvalid && !hp2_awvalid
            && !sram_wen && !sram_wt_wen && !sram_coeff_wen && !sram_lut_wen
            && !dma_err && !dma_store_done,
            "T1: reset outputs idle");
        chk(hp0_arsize == 3'b100 && hp0_arburst == 2'b01 && hp0_arcache == 4'b0011,
            "T1: HP0 AXI constants");
        chk(hp1_arsize == 3'b100 && hp1_arburst == 2'b01 && hp1_arcache == 4'b0011,
            "T1: HP1 AXI constants");
        chk(hp2_awsize == 3'b100 && hp2_awburst == 2'b01 && hp2_awcache == 4'b0011,
            "T1: HP2 AXI constants");

        // T2: 2x2 LOAD, single beat per pixel
        ddr_words[word_index(44'h1000)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A0;
        ddr_words[word_index(44'h1010)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A1;
        ddr_words[word_index(44'h1020)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A2;
        ddr_words[word_index(44'h1030)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A3;
        src_base   = 32'h1000;
        row_stride = 16'h20;
        tile_w = 8'd2;  tile_h = 8'd2;  ch_count = 8'd16;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(4);
        join
        wait_ch0_idle();
        chk(act_mem[0] == ddr_words[word_index(44'h1000)], "T2: pixel 0,0");
        chk(act_mem[1] == ddr_words[word_index(44'h1010)], "T2: pixel 0,1");
        chk(act_mem[2] == ddr_words[word_index(44'h1020)], "T2: pixel 1,0");
        chk(act_mem[3] == ddr_words[word_index(44'h1030)], "T2: pixel 1,1");
        chk(!dma_err, "T2: no error");

        // T3: padded 3-wide row (pad_left=1, pad_right=1)
        reset_dut();
        src_base   = 32'h2000;
        row_stride = 16'h10;
        tile_w = 8'd3;  tile_h = 8'd1;  ch_count = 8'd16;
        pad_left = 4'd1; pad_right = 4'd1;
        ddr_words[word_index(44'h2010)] = 128'hFACE_CAFE_DEAD_BEEF_0000_0000_0000_1234;
        fork
            pulse_start();
            hp0_read_serve(1);
        join
        wait_ch0_idle();
        chk(act_mem[0] == 128'h0, "T3: left pad zero");
        chk(act_mem[1] == ddr_words[word_index(44'h2010)], "T3: middle pixel");
        chk(act_mem[2] == 128'h0, "T3: right pad zero");

        // T4: WT_LOAD — 16-beat linear burst into Wt bank
        reset_dut();
        for (int i = 0; i < 16; i++) begin
            ddr_words[word_index(44'h3000) + i] =
                {120'hCAFE_0000_0000_0000_0000_0000_0000, 8'(i)};
        end
        wt_src_base = 32'h3000;
        fork
            pulse_ch1_start();
            hp1_read_serve(1);
        join
        wait_ch1_idle();
        for (int i = 0; i < 16; i++) begin
            chk(wt_mem[i] == ddr_words[word_index(44'h3000) + i], $sformatf("T4: wt beat %0d", i));
        end
        chk(dma_wt_bank_full === 1'b0, "T4: wt_bank_full deasserts after pulse");

        // T5: DMA_STORE — single row, 2 beats
        reset_dut();
        out_mem[0] = 128'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;
        out_mem[1] = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        src_base   = 32'h4000;        // DDR destination
        row_stride = 16'h20;
        tile_w = 8'd2;  tile_h = 8'd1; ch_count = 8'd16;
        fetch_mode = 3'b011;
        fork
            pulse_start();
            hp2_write_serve();
        join
        wait_ch0_idle();
        chk(store_count == 2, "T5: store wrote 2 beats");
        chk(store_words[0] == out_mem[0], "T5: beat 0 = out_mem[0]");
        chk(store_words[1] == out_mem[1], "T5: beat 1 = out_mem[1]");
        chk(hp2_wstrb == 16'hFFFF, "T5: all byte lanes enabled");
        chk(!dma_err, "T5: no error");

        // T6: COEFF_LOAD — 4 channels = 2 beats; check M/S unpack
        reset_dut();
        // Beat 0: chan0 = M=32'hAABB_CCDD, S=4'h5 ; chan1 = M=32'h1122_3344, S=4'h7
        ddr_words[word_index(44'h5000) + 0] = {
            32'h1122_3344,   // chan1.M [127:96]
            24'h0,           // chan1.pad [95:72]
            4'h0, 4'h7,      // chan1.pad[71:68], chan1.S[67:64]
            32'hAABB_CCDD,   // chan0.M [63:32]
            24'h0,           // chan0.pad [31:8]
            4'h0, 4'h5       // chan0.pad[7:4], chan0.S[3:0]
        };
        // Beat 1: chan2 / chan3
        ddr_words[word_index(44'h5000) + 1] = {
            32'h9999_8888, 24'h0, 4'h0, 4'h3,
            32'h6666_5555, 24'h0, 4'h0, 4'h2
        };
        src_base       = 32'h5000;
        coeff_ch_count = 10'd4;
        fetch_mode     = 3'b100;
        fork
            pulse_start();
            hp0_read_serve(1);  // single AR with arlen=1 -> 2 beats
        join
        wait_ch0_idle();
        chk(coeff_mem[0] == {32'hAABB_CCDD, 4'h5}, "T6: chan0 {M,S}");
        chk(coeff_mem[1] == {32'h1122_3344, 4'h7}, "T6: chan1 {M,S}");
        chk(coeff_mem[2] == {32'h6666_5555, 4'h2}, "T6: chan2 {M,S}");
        chk(coeff_mem[3] == {32'h9999_8888, 4'h3}, "T6: chan3 {M,S}");

        // T7: LUT_LOAD — 16 beats, 256 bytes; spot-check byte 0/15/128/255
        reset_dut();
        for (int i = 0; i < 16; i++) begin
            ddr_words[word_index(44'h6000) + i] = {
                8'(i*16+15), 8'(i*16+14), 8'(i*16+13), 8'(i*16+12),
                8'(i*16+11), 8'(i*16+10), 8'(i*16+9),  8'(i*16+8),
                8'(i*16+7),  8'(i*16+6),  8'(i*16+5),  8'(i*16+4),
                8'(i*16+3),  8'(i*16+2),  8'(i*16+1),  8'(i*16+0)
            };
        end
        src_base   = 32'h6000;
        lut_sel    = 1'b1;
        fetch_mode = 3'b101;
        fork
            pulse_start();
            hp0_read_serve(1);  // single AR with arlen=15 -> 16 beats
        join
        wait_ch0_idle();
        chk(lut_mem[0]   == 8'd0,   "T7: lut[0]");
        chk(lut_mem[15]  == 8'd15,  "T7: lut[15]");
        chk(lut_mem[128] == 8'd128, "T7: lut[128]");
        chk(lut_mem[255] == 8'd255, "T7: lut[255]");
        chk(sram_lut_sel == 1'b1, "T7: lut_sel held");

        // T8: UPSAMPLE — 1x1 src emits 2x2 (4 beats from one AR)
        reset_dut();
        ddr_words[word_index(44'h7000)] = 128'hFEED_FACE_DEAD_BEEF_AABB_CCDD_1122_3344;
        src_base   = 32'h7000;
        row_stride = 16'h10;
        tile_w = 8'd1;  tile_h = 8'd1; ch_count = 8'd16;
        fetch_mode = 3'b001;
        fork
            pulse_start();
            // src 1x1 with ch_count=16 -> 1 beat per emission, 4 emissions
            hp0_read_serve(4);
        join
        wait_ch0_idle();
        for (int i = 0; i < 4; i++) begin
            chk(act_mem[i] == ddr_words[word_index(44'h7000)],
                $sformatf("T8: upsample slot %0d", i));
        end

        // T9: CONCAT — 1 pixel, ch_count=32 -> 2 beats per phase from two bases
        reset_dut();
        ddr_words[word_index(44'h8000)] = 128'h1111_1111_1111_1111_1111_1111_1111_1111;
        ddr_words[word_index(44'h8010)] = 128'h2222_2222_2222_2222_2222_2222_2222_2222;
        ddr_words[word_index(44'h9000)] = 128'h3333_3333_3333_3333_3333_3333_3333_3333;
        ddr_words[word_index(44'h9010)] = 128'h4444_4444_4444_4444_4444_4444_4444_4444;
        src_base    = 32'h8000;
        concat_base = 32'h9000;
        row_stride  = 16'h10;
        tile_w = 8'd1;  tile_h = 8'd1; ch_count = 8'd32;  // r_beats=2 -> r_beats/2=1 beat per phase
        fetch_mode  = 3'b010;
        fork
            pulse_start();
            // 1 pixel: 1 burst from base, 1 burst from concat_base, 1 beat each
            hp0_read_serve(2);
        join
        wait_ch0_idle();
        chk(act_mem[0] == ddr_words[word_index(44'h8000)], "T9: concat phase 0 -> base");
        chk(act_mem[1] == ddr_words[word_index(44'h9000)], "T9: concat phase 1 -> concat_base");

        // T10: HP0 read SLVERR -> dma_err sticky
        reset_dut();
        src_base = 32'hA000;
        tile_w = 8'd1;  tile_h = 8'd1;  ch_count = 8'd16;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(1, 2'b10);
        join
        wait_ch0_idle();
        chk(dma_err, "T10: SLVERR sets dma_err sticky");

        // T11: HP2 write BRESP error -> dma_err sticky
        reset_dut();
        src_base = 32'hB000;
        tile_w = 8'd1;  tile_h = 8'd1;  ch_count = 8'd16;
        fetch_mode = 3'b011;
        fork
            pulse_start();
            hp2_write_serve(2'b10);
        join
        wait_ch0_idle();
        chk(dma_err, "T11: BRESP error sets dma_err sticky");

        $display("DMA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TIMEOUT");
    end

endmodule
