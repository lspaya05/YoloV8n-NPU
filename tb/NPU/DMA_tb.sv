// Testbench for DMA
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;

module DMA_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int DDR_WORDS   = 4096;
    localparam int MAX_EVENTS  = 128;

    logic clk;
    logic rst;

    logic [31:0] src_base;
    logic [15:0] row_stride;
    logic [7:0]  tile_w;
    logic [7:0]  tile_h;
    logic [7:0]  ch_count;
    logic [3:0]  pad_top;
    logic [3:0]  pad_bot;
    logic [3:0]  pad_left;
    logic [3:0]  pad_right;
    logic [2:0]  fetch_mode;
    logic [31:0] concat_base;
    logic [9:0]  coeff_ch_count;
    logic        lut_sel;
    logic        ch1_start;
    logic [31:0] wt_src_base;
    logic        start;
    logic        ch0_idle;
    logic        ch1_idle;
    logic        dma_act_bank_full;
    logic        dma_wt_bank_full;
    logic        dma_store_done;

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

    logic [$clog2(RES_BANK_DEPTH)-1:0] sram_waddr;
    logic [127:0]                      sram_wdata;
    logic                              sram_wen;
    logic [$clog2(WT_BUF_DEPTH)-1:0]   sram_wt_waddr;
    logic [127:0]                      sram_wt_wdata;
    logic                              sram_wt_wen;
    logic [$clog2(MAX_CHANNELS)-1:0]   sram_coeff_waddr;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] sram_coeff_wdata;
    logic                              sram_coeff_wen;
    logic [$clog2(LUT_DEPTH)-1:0]      sram_lut_waddr;
    logic [7:0]                        sram_lut_wdata;
    logic                              sram_lut_wen;
    logic                              sram_lut_sel;
    logic [$clog2(RES_BANK_DEPTH)-1:0] sram_raddr;
    logic [127:0]                      sram_rdata;
    logic                              dma_err;

    logic dep_sa_to_dma_empty;
    logic dep_sa_to_dma_pop;
    logic dep_vpu_to_dma_empty;
    logic dep_vpu_to_dma_pop;
    logic dep_dma_to_sa_full;
    logic dep_dma_to_sa_push;
    logic dep_dma_to_vpu_full;
    logic dep_dma_to_vpu_push;

    logic [127:0] sram_model [0:RES_BANK_DEPTH-1];
    logic [127:0] wt_model [0:WT_BUF_DEPTH-1];
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] coeff_model [0:MAX_CHANNELS-1];
    logic [7:0] lut_model [0:LUT_DEPTH-1];
    logic [127:0] ddr_words [0:DDR_WORDS-1];
    logic [127:0] wt_ddr_words [0:DDR_WORDS-1];
    logic [127:0] store_words [0:MAX_EVENTS-1];
    logic         store_last_seen [0:MAX_EVENTS-1];
    logic [43:0]  hp0_ar_seen [0:MAX_EVENTS-1];
    logic [7:0]   hp0_arlen_seen [0:MAX_EVENTS-1];
    logic [43:0]  hp1_ar_seen [0:MAX_EVENTS-1];
    logic [7:0]   hp1_arlen_seen [0:MAX_EVENTS-1];
    logic [43:0]  hp2_aw_seen [0:MAX_EVENTS-1];
    logic [7:0]   hp2_awlen_seen [0:MAX_EVENTS-1];

    int err_cnt;
    int hp0_read_burst_count;
    int hp1_read_burst_count;
    int hp2_write_burst_count;
    int store_count;
    int act_done_count;
    int wt_done_count;
    int store_done_count;
    int dep_sa_push_count;
    int dep_vpu_push_count;

    // Instantiating the dut
    DMA dut (
        .clk(clk),
        .rst(rst),
        .src_base(src_base),
        .row_stride(row_stride),
        .tile_w(tile_w),
        .tile_h(tile_h),
        .ch_count(ch_count),
        .pad_top(pad_top),
        .pad_bot(pad_bot),
        .pad_left(pad_left),
        .pad_right(pad_right),
        .fetch_mode(fetch_mode),
        .concat_base(concat_base),
        .coeff_ch_count(coeff_ch_count),
        .lut_sel(lut_sel),
        .ch1_start(ch1_start),
        .wt_src_base(wt_src_base),
        .start(start),
        .ch0_idle(ch0_idle),
        .ch1_idle(ch1_idle),
        .dma_act_bank_full(dma_act_bank_full),
        .dma_wt_bank_full(dma_wt_bank_full),
        .dma_store_done(dma_store_done),
        .hp0_araddr(hp0_araddr),
        .hp0_arvalid(hp0_arvalid),
        .hp0_arlen(hp0_arlen),
        .hp0_arsize(hp0_arsize),
        .hp0_arburst(hp0_arburst),
        .hp0_arcache(hp0_arcache),
        .hp0_arready(hp0_arready),
        .hp0_rdata(hp0_rdata),
        .hp0_rvalid(hp0_rvalid),
        .hp0_rlast(hp0_rlast),
        .hp0_rresp(hp0_rresp),
        .hp0_rready(hp0_rready),
        .hp2_awaddr(hp2_awaddr),
        .hp2_awvalid(hp2_awvalid),
        .hp2_awlen(hp2_awlen),
        .hp2_awsize(hp2_awsize),
        .hp2_awburst(hp2_awburst),
        .hp2_awcache(hp2_awcache),
        .hp2_awready(hp2_awready),
        .hp2_wdata(hp2_wdata),
        .hp2_wstrb(hp2_wstrb),
        .hp2_wlast(hp2_wlast),
        .hp2_wvalid(hp2_wvalid),
        .hp2_wready(hp2_wready),
        .hp2_bresp(hp2_bresp),
        .hp2_bvalid(hp2_bvalid),
        .hp2_bready(hp2_bready),
        .hp1_araddr(hp1_araddr),
        .hp1_arvalid(hp1_arvalid),
        .hp1_arlen(hp1_arlen),
        .hp1_arsize(hp1_arsize),
        .hp1_arburst(hp1_arburst),
        .hp1_arcache(hp1_arcache),
        .hp1_arready(hp1_arready),
        .hp1_rdata(hp1_rdata),
        .hp1_rvalid(hp1_rvalid),
        .hp1_rlast(hp1_rlast),
        .hp1_rresp(hp1_rresp),
        .hp1_rready(hp1_rready),
        .sram_waddr(sram_waddr),
        .sram_wdata(sram_wdata),
        .sram_wen(sram_wen),
        .sram_wt_waddr(sram_wt_waddr),
        .sram_wt_wdata(sram_wt_wdata),
        .sram_wt_wen(sram_wt_wen),
        .sram_coeff_waddr(sram_coeff_waddr),
        .sram_coeff_wdata(sram_coeff_wdata),
        .sram_coeff_wen(sram_coeff_wen),
        .sram_lut_waddr(sram_lut_waddr),
        .sram_lut_wdata(sram_lut_wdata),
        .sram_lut_wen(sram_lut_wen),
        .sram_lut_sel(sram_lut_sel),
        .sram_raddr(sram_raddr),
        .sram_rdata(sram_rdata),
        .dma_err(dma_err),
        .dep_sa_to_dma_empty(dep_sa_to_dma_empty),
        .dep_sa_to_dma_pop(dep_sa_to_dma_pop),
        .dep_vpu_to_dma_empty(dep_vpu_to_dma_empty),
        .dep_vpu_to_dma_pop(dep_vpu_to_dma_pop),
        .dep_dma_to_sa_full(dep_dma_to_sa_full),
        .dep_dma_to_sa_push(dep_dma_to_sa_push),
        .dep_dma_to_vpu_full(dep_dma_to_vpu_full),
        .dep_dma_to_vpu_push(dep_dma_to_vpu_push)
    );

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // SRAM write and one-cycle read model
    always @(negedge clk) begin
        sram_rdata = sram_model[sram_raddr];
        if (sram_wen) sram_model[sram_waddr] <= sram_wdata;
        if (sram_wt_wen) wt_model[sram_wt_waddr] <= sram_wt_wdata;
        if (sram_coeff_wen) coeff_model[sram_coeff_waddr] <= sram_coeff_wdata;
        if (sram_lut_wen) lut_model[sram_lut_waddr] <= sram_lut_wdata;
        if (dma_act_bank_full) act_done_count++;
        if (dma_wt_bank_full) wt_done_count++;
        if (dma_store_done) store_done_count++;
        if (dep_dma_to_sa_push) dep_sa_push_count++;
        if (dep_dma_to_vpu_push) dep_vpu_push_count++;
    end

    // Helper function to convert a byte address to a 128-bit DDR word index
    function automatic int word_index(input logic [43:0] addr);
        return int'(addr[15:4]);
    endfunction

    // Helper function to make distinct DDR data
    function automatic logic [127:0] make_word(input int tag);
        logic [127:0] word;
        begin
            word = '0;
            for (int b = 0; b < 16; b++) begin
                word[b*8 +: 8] = 8'(tag + b);
            end
            return word;
        end
    endfunction

    // Helper function to make packed requant coefficients
    function automatic logic [127:0] make_coeff_word(input int pair);
        logic [127:0] word;
        begin
            word = '0;
            word[63:32]  = 32'h1000_0000 + pair * 2;
            word[3:0]    = 4'(pair * 2);
            word[127:96] = 32'h1000_0001 + pair * 2;
            word[67:64]  = 4'(pair * 2 + 1);
            return word;
        end
    endfunction

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // Initializes all inputs to idle values
    task automatic init_inputs();
        src_base = 32'h0;
        row_stride = 16'h10;
        tile_w = 8'h1;
        tile_h = 8'h1;
        ch_count = 8'h10;
        pad_top = 4'h0;
        pad_bot = 4'h0;
        pad_left = 4'h0;
        pad_right = 4'h0;
        fetch_mode = 3'b000;
        concat_base = 32'h0;
        coeff_ch_count = 10'h0;
        lut_sel = 1'b0;
        ch1_start = 1'b0;
        wt_src_base = 32'h0;
        start = 1'b0;
        hp0_arready = 1'b0;
        hp0_rdata = 128'h0;
        hp0_rvalid = 1'b0;
        hp0_rlast = 1'b0;
        hp0_rresp = 2'b00;
        hp1_arready = 1'b0;
        hp1_rdata = 128'h0;
        hp1_rvalid = 1'b0;
        hp1_rlast = 1'b0;
        hp1_rresp = 2'b00;
        hp2_awready = 1'b0;
        hp2_wready = 1'b0;
        hp2_bresp = 2'b00;
        hp2_bvalid = 1'b0;
        dep_sa_to_dma_empty = 1'b1;
        dep_vpu_to_dma_empty = 1'b1;
        dep_dma_to_sa_full = 1'b0;
        dep_dma_to_vpu_full = 1'b0;
        hp0_read_burst_count = 0;
        hp1_read_burst_count = 0;
        hp2_write_burst_count = 0;
        store_count = 0;
        act_done_count = 0;
        wt_done_count = 0;
        store_done_count = 0;
        dep_sa_push_count = 0;
        dep_vpu_push_count = 0;
    endtask

    // Resets everything
    task automatic reset_dut();
        rst = 1'b1;
        init_inputs();
        sram_rdata = 128'h0;
        for (int i = 0; i < RES_BANK_DEPTH; i++) sram_model[i] = 128'h0;
        for (int i = 0; i < WT_BUF_DEPTH; i++) wt_model[i] = 128'h0;
        for (int i = 0; i < MAX_CHANNELS; i++) coeff_model[i] = '0;
        for (int i = 0; i < LUT_DEPTH; i++) lut_model[i] = 8'h0;
        for (int i = 0; i < DDR_WORDS; i++) begin
            ddr_words[i] = make_word(i);
            wt_ddr_words[i] = make_word(16'h8000 + i);
        end
        for (int i = 0; i < MAX_EVENTS; i++) begin
            store_words[i] = 128'h0;
            store_last_seen[i] = 1'b0;
            hp0_ar_seen[i] = 44'h0;
            hp0_arlen_seen[i] = 8'h0;
            hp1_ar_seen[i] = 44'h0;
            hp1_arlen_seen[i] = 8'h0;
            hp2_aw_seen[i] = 44'h0;
            hp2_awlen_seen[i] = 8'h0;
        end
        repeat (5) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
    endtask

    // Sends a one-cycle Ch0 start pulse
    task automatic pulse_start();
        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
    endtask

    // Sends a one-cycle Ch1 start pulse
    task automatic pulse_ch1_start();
        @(negedge clk);
        ch1_start = 1'b1;
        @(negedge clk);
        ch1_start = 1'b0;
    endtask

    // Waits for Ch0 to return idle with a timeout
    task automatic wait_ch0_idle(input string name, input int timeout_cycles = 3000);
        int count;
        count = 0;
        while (!ch0_idle && count < timeout_cycles) begin
            @(posedge clk);
            count++;
        end
        #1ps;
        chk(count < timeout_cycles, {name, ": timeout waiting for ch0 idle"});
    endtask

    // Waits for Ch1 to return idle with a timeout
    task automatic wait_ch1_idle(input string name, input int timeout_cycles = 1000);
        int count;
        count = 0;
        while (!ch1_idle && count < timeout_cycles) begin
            @(posedge clk);
            count++;
        end
        #1ps;
        chk(count < timeout_cycles, {name, ": timeout waiting for ch1 idle"});
    endtask

    // HP0 AXI read slave for one or more bursts
    task automatic hp0_read_serve(
        input int bursts,
        input int ar_delay = 0,
        input int r_gap = 0,
        input logic [1:0] resp = 2'b00
    );
        logic [43:0] addr;
        int beats;
        for (int burst = 0; burst < bursts; burst++) begin
            while (!hp0_arvalid) @(negedge clk);
            repeat (ar_delay) @(negedge clk);
            addr = hp0_araddr;
            beats = hp0_arlen + 1;
            hp0_ar_seen[hp0_read_burst_count] = hp0_araddr;
            hp0_arlen_seen[hp0_read_burst_count] = hp0_arlen;
            hp0_read_burst_count++;
            hp0_arready = 1'b1;
            @(negedge clk);
            hp0_arready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                repeat (r_gap) @(negedge clk);
                while (!hp0_rready) @(negedge clk);
                hp0_rdata = ddr_words[word_index(addr) + beat];
                hp0_rresp = resp;
                hp0_rlast = (beat == beats - 1);
                hp0_rvalid = 1'b1;
                @(negedge clk);
                hp0_rvalid = 1'b0;
                hp0_rlast = 1'b0;
            end
            hp0_rresp = 2'b00;
        end
    endtask

    // HP1 AXI read slave for the weight channel
    task automatic hp1_read_serve(
        input int ar_delay = 0,
        input int r_gap = 0,
        input logic [1:0] resp = 2'b00
    );
        logic [43:0] addr;
        int beats;
        while (!hp1_arvalid) @(negedge clk);
        repeat (ar_delay) @(negedge clk);
        addr = hp1_araddr;
        beats = hp1_arlen + 1;
        hp1_ar_seen[hp1_read_burst_count] = hp1_araddr;
        hp1_arlen_seen[hp1_read_burst_count] = hp1_arlen;
        hp1_read_burst_count++;
        hp1_arready = 1'b1;
        @(negedge clk);
        hp1_arready = 1'b0;
        for (int beat = 0; beat < beats; beat++) begin
            repeat (r_gap) @(negedge clk);
            while (!hp1_rready) @(negedge clk);
            hp1_rdata = wt_ddr_words[word_index(addr) + beat];
            hp1_rresp = resp;
            hp1_rlast = (beat == beats - 1);
            hp1_rvalid = 1'b1;
            @(negedge clk);
            hp1_rvalid = 1'b0;
            hp1_rlast = 1'b0;
        end
        hp1_rresp = 2'b00;
    endtask

    // HP2 AXI write slave for one or more store rows
    task automatic hp2_write_serve(
        input int rows,
        input int aw_delay = 0,
        input int w_gap = 0,
        input logic [1:0] resp = 2'b00
    );
        int beats;
        for (int row = 0; row < rows; row++) begin
            while (!hp2_awvalid) @(negedge clk);
            repeat (aw_delay) @(negedge clk);
            beats = hp2_awlen + 1;
            hp2_aw_seen[hp2_write_burst_count] = hp2_awaddr;
            hp2_awlen_seen[hp2_write_burst_count] = hp2_awlen;
            hp2_write_burst_count++;
            hp2_awready = 1'b1;
            @(negedge clk);
            hp2_awready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                repeat (w_gap) @(negedge clk);
                while (!hp2_wvalid) @(negedge clk);
                store_words[store_count] = hp2_wdata;
                store_last_seen[store_count] = hp2_wlast;
                store_count++;
                hp2_wready = 1'b1;
                @(negedge clk);
                hp2_wready = 1'b0;
            end
            hp2_bresp = resp;
            hp2_bvalid = 1'b1;
            while (!hp2_bready) @(negedge clk);
            @(negedge clk);
            hp2_bvalid = 1'b0;
            hp2_bresp = 2'b00;
        end
    endtask

    initial begin
        err_cnt = 0;

        // Testcase 1: reset should leave both channels idle and set fixed AXI constants
        reset_dut();
        #1ps;
        chk(ch0_idle && ch1_idle && !dma_act_bank_full && !dma_wt_bank_full && !dma_store_done,
            "reset leaves DMA idle");
        chk(!hp0_arvalid && !hp1_arvalid && !hp2_awvalid && !hp2_wvalid && !sram_wen && !dma_err,
            "reset clears active outputs");
        chk(hp0_arsize == 3'b100 && hp0_arburst == 2'b01 && hp0_arcache == 4'b0011,
            "HP0 AXI constants");
        chk(hp1_arsize == 3'b100 && hp1_arburst == 2'b01 && hp1_arcache == 4'b0011,
            "HP1 AXI constants");
        chk(hp2_awsize == 3'b100 && hp2_awburst == 2'b01 && hp2_awcache == 4'b0011 &&
            hp2_wstrb == 16'hFFFF, "HP2 AXI constants");
        chk(!dep_sa_to_dma_pop && !dep_vpu_to_dma_pop, "DMA does not pop dependency FIFOs");

        // Testcase 2: basic 2 by 2 load should honor row_stride and tolerate AXI backpressure
        reset_dut();
        src_base = 32'h1000;
        row_stride = 16'h40;
        tile_w = 8'd2;
        tile_h = 8'd2;
        ch_count = 8'd16;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(4, 3, 2);
        join
        wait_ch0_idle("basic strided load");
        chk(hp0_read_burst_count == 4, "basic load creates four AR bursts");
        chk(act_done_count == 1 && dep_sa_push_count == 1, "basic load pulses act full and SA dependency once");
        chk(hp0_ar_seen[0] == 44'h1000 && hp0_ar_seen[1] == 44'h1010 &&
            hp0_ar_seen[2] == 44'h1040 && hp0_ar_seen[3] == 44'h1050,
            "basic load AR addresses follow row_stride and ch_count");
        chk(sram_model[0] == ddr_words[word_index(44'h1000)], "basic load word 0");
        chk(sram_model[1] == ddr_words[word_index(44'h1010)], "basic load word 1");
        chk(sram_model[2] == ddr_words[word_index(44'h1040)], "basic load word 2");
        chk(sram_model[3] == ddr_words[word_index(44'h1050)], "basic load word 3");

        // Testcase 3: ch_count of 32 should generate two-beat bursts per pixel
        reset_dut();
        src_base = 32'h2000;
        row_stride = 16'h80;
        tile_w = 8'd1;
        tile_h = 8'd2;
        ch_count = 8'd32;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(2, 0, 1);
        join
        wait_ch0_idle("multi-beat load");
        chk(hp0_read_burst_count == 2, "multi-beat load creates two bursts");
        chk(hp0_arlen_seen[0] == 8'd1 && hp0_arlen_seen[1] == 8'd1, "multi-beat load ARLEN is 1");
        chk(sram_model[0] == ddr_words[word_index(44'h2000)], "multi-beat first pixel beat 0");
        chk(sram_model[1] == ddr_words[word_index(44'h2010)], "multi-beat first pixel beat 1");
        chk(sram_model[2] == ddr_words[word_index(44'h2080)], "multi-beat second row beat 0");
        chk(sram_model[3] == ddr_words[word_index(44'h2090)], "multi-beat second row beat 1");

        // Testcase 4: full-edge padding should insert zeros without issuing DDR reads for padded pixels
        reset_dut();
        src_base = 32'h3000;
        row_stride = 16'h30;
        tile_w = 8'd3;
        tile_h = 8'd3;
        ch_count = 8'd16;
        pad_top = 4'd1;
        pad_bot = 4'd1;
        pad_left = 4'd1;
        pad_right = 4'd1;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(1);
        join
        wait_ch0_idle("padded load");
        chk(hp0_read_burst_count == 1, "padding skips DDR reads for eight padded pixels");
        chk(hp0_ar_seen[0] == 44'h3040, "padding fetches only the center pixel address");
        for (int i = 0; i < 9; i++) begin
            if (i == 4)
                chk(sram_model[i] == ddr_words[word_index(44'h3040)], "center pixel is fetched");
            else
                chk(sram_model[i] == 128'h0, $sformatf("padding word %0d is zero", i));
        end

        // Testcase 5: CONCAT should fetch half the channels from each source for the same pixel
        reset_dut();
        src_base = 32'h4100;
        concat_base = 32'h5100;
        row_stride = 16'h40;
        tile_w = 8'd1;
        tile_h = 8'd1;
        ch_count = 8'd32;
        fetch_mode = 3'b010;
        fork
            pulse_start();
            hp0_read_serve(2, 1, 0);
        join
        wait_ch0_idle("concat load");
        chk(hp0_read_burst_count == 2, "concat creates two half-channel bursts");
        chk(hp0_arlen_seen[0] == 8'd0 && hp0_arlen_seen[1] == 8'd0, "concat half bursts are one beat each");
        chk(hp0_ar_seen[0] == 44'h4100 && hp0_ar_seen[1] == 44'h5100, "concat uses base and concat_base");
        chk(sram_model[0] == ddr_words[word_index(44'h4100)], "concat first half data");
        chk(sram_model[1] == ddr_words[word_index(44'h5100)], "concat second half data");

        // Testcase 6: UPSAMPLE should emit each source pixel four times
        reset_dut();
        src_base = 32'h6200;
        row_stride = 16'h20;
        tile_w = 8'd1;
        tile_h = 8'd1;
        ch_count = 8'd16;
        fetch_mode = 3'b001;
        fork
            pulse_start();
            hp0_read_serve(4);
        join
        wait_ch0_idle("upsample load");
        chk(hp0_read_burst_count == 4, "upsample performs four reads for one source pixel");
        for (int i = 0; i < 4; i++) begin
            chk(hp0_ar_seen[i] == 44'h6200, $sformatf("upsample read %0d uses the same source address", i));
            chk(sram_model[i] == ddr_words[word_index(44'h6200)], $sformatf("upsample write %0d duplicates source", i));
        end

        // Testcase 7: a start pulse while Ch0 is busy should be ignored
        reset_dut();
        src_base = 32'h7000;
        row_stride = 16'h10;
        tile_w = 8'd3;
        tile_h = 8'd1;
        ch_count = 8'd16;
        fetch_mode = 3'b000;
        fork
            begin
                pulse_start();
                repeat (3) @(negedge clk);
                start = 1'b1;
                @(negedge clk);
                start = 1'b0;
            end
            hp0_read_serve(3, 4, 0);
        join
        wait_ch0_idle("busy start ignore");
        repeat (5) @(posedge clk);
        chk(act_done_count == 1 && hp0_read_burst_count == 3, "busy start did not launch a second transaction");

        // Testcase 8: read response errors on HP0 should set dma_err sticky while still completing
        reset_dut();
        src_base = 32'h8000;
        tile_w = 8'd1;
        tile_h = 8'd1;
        ch_count = 8'd16;
        fetch_mode = 3'b000;
        fork
            pulse_start();
            hp0_read_serve(1, 0, 0, 2'b10);
        join
        wait_ch0_idle("HP0 read error");
        chk(dma_err, "HP0 SLVERR sets dma_err");
        repeat (5) @(posedge clk);
        chk(dma_err, "dma_err remains sticky after HP0 read error");

        // Testcase 9: COEFF_LOAD should unpack two coefficient entries per beat
        reset_dut();
        src_base = 32'h9000;
        coeff_ch_count = 10'd4;
        fetch_mode = 3'b100;
        ddr_words[word_index(44'h9000)] = make_coeff_word(0);
        ddr_words[word_index(44'h9010)] = make_coeff_word(1);
        fork
            pulse_start();
            hp0_read_serve(1, 2, 1);
        join
        wait_ch0_idle("coeff load");
        chk(hp0_read_burst_count == 1 && hp0_ar_seen[0] == 44'h9000 && hp0_arlen_seen[0] == 8'd1,
            "coeff load issues one two-beat burst");
        chk(coeff_model[0] == {32'h1000_0000, 4'h0}, "coeff entry 0 unpacked");
        chk(coeff_model[1] == {32'h1000_0001, 4'h1}, "coeff entry 1 unpacked");
        chk(coeff_model[2] == {32'h1000_0002, 4'h2}, "coeff entry 2 unpacked");
        chk(coeff_model[3] == {32'h1000_0003, 4'h3}, "coeff entry 3 unpacked");

        // Testcase 10: LUT_LOAD should drain sixteen 128-bit beats into 256 byte entries
        reset_dut();
        src_base = 32'hA000;
        fetch_mode = 3'b101;
        lut_sel = 1'b1;
        fork
            pulse_start();
            hp0_read_serve(1, 1, 1);
        join
        wait_ch0_idle("lut load");
        chk(hp0_read_burst_count == 1 && hp0_ar_seen[0] == 44'hA000 && hp0_arlen_seen[0] == 8'd15,
            "lut load issues one sixteen-beat burst");
        chk(sram_lut_sel == 1'b1, "lut select is held from descriptor");
        chk(lut_model[0] == ddr_words[word_index(44'hA000)][7:0], "lut byte 0");
        chk(lut_model[15] == ddr_words[word_index(44'hA000)][127:120], "lut byte 15");
        chk(lut_model[16] == ddr_words[word_index(44'hA010)][7:0], "lut byte 16");
        chk(lut_model[255] == ddr_words[word_index(44'hA0F0)][127:120], "lut byte 255");

        // Testcase 11: Ch1 WT_LOAD should fetch a full 16-beat weight tile with backpressure
        reset_dut();
        wt_src_base = 32'hB000;
        fork
            pulse_ch1_start();
            hp1_read_serve(3, 2);
        join
        wait_ch1_idle("weight load");
        chk(hp1_read_burst_count == 1 && hp1_ar_seen[0] == 44'hB000 && hp1_arlen_seen[0] == 8'd15,
            "weight load issues one sixteen-beat burst");
        chk(wt_done_count == 1, "weight load pulses wt bank full once");
        for (int i = 0; i < 16; i++) begin
            chk(wt_model[i] == wt_ddr_words[word_index(44'hB000) + i],
                $sformatf("weight word %0d written", i));
        end

        // Testcase 12: HP1 read errors should set dma_err sticky
        reset_dut();
        wt_src_base = 32'hC000;
        fork
            pulse_ch1_start();
            hp1_read_serve(0, 0, 2'b11);
        join
        wait_ch1_idle("HP1 read error");
        chk(dma_err, "HP1 DECERR sets dma_err");
        repeat (5) @(posedge clk);
        chk(dma_err, "dma_err remains sticky after HP1 read error");

        // Testcase 13: STORE should emit one row burst per tile row with full strobes and row_stride addresses
        reset_dut();
        src_base = 32'hD000;
        row_stride = 16'h80;
        tile_w = 8'd2;
        tile_h = 8'd2;
        ch_count = 8'd32;
        fetch_mode = 3'b011;
        for (int i = 0; i < 8; i++) sram_model[i] = 128'hD000_0000_0000_0000 + i;
        fork
            pulse_start();
            hp2_write_serve(2, 2, 1);
        join
        wait_ch0_idle("store");
        chk(hp2_write_burst_count == 2, "store issues one AW per row");
        chk(hp2_aw_seen[0] == 44'hD000 && hp2_aw_seen[1] == 44'hD080, "store AW addresses follow row_stride");
        chk(hp2_awlen_seen[0] == 8'd3 && hp2_awlen_seen[1] == 8'd3, "store row bursts contain four beats");
        chk(store_count == 8, "store writes eight beats total");
        for (int i = 0; i < 8; i++) begin
            chk(store_words[i] == (128'hD000_0000_0000_0000 + i), $sformatf("store beat %0d data", i));
            chk(store_last_seen[i] == ((i == 3) || (i == 7)), $sformatf("store beat %0d last flag", i));
        end
        chk(store_done_count == 1 && dep_vpu_push_count == 1, "store pulses done and VPU dependency once");
        chk(!dma_err, "store completes without error");

        // Testcase 14: HP2 write response errors should set dma_err sticky after store completion
        reset_dut();
        src_base = 32'hE000;
        tile_w = 8'd1;
        tile_h = 8'd1;
        ch_count = 8'd16;
        fetch_mode = 3'b011;
        sram_model[0] = 128'hE0E0_E0E0_E0E0_E0E0_E0E0_E0E0_E0E0_E0E0;
        fork
            pulse_start();
            hp2_write_serve(1, 0, 0, 2'b10);
        join
        wait_ch0_idle("HP2 write error");
        chk(dma_err, "HP2 BRESP error sets dma_err");
        repeat (5) @(posedge clk);
        chk(dma_err, "dma_err remains sticky after HP2 write error");

        $display("DMA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "TIMEOUT");
    end

endmodule
