// Testbench for DMA
`timescale 1ns/1ps

import NPU_HW_params_pkg::*;

module DMA_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;

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
    logic [1:0]  fetch_mode;
    logic [31:0] concat_base;
    logic        start;
    logic        busy;
    logic        done;

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

    logic [43:0]  hp1_awaddr;
    logic         hp1_awvalid;
    logic [7:0]   hp1_awlen;
    logic [2:0]   hp1_awsize;
    logic [1:0]   hp1_awburst;
    logic [3:0]   hp1_awcache;
    logic         hp1_awready;
    logic [127:0] hp1_wdata;
    logic [15:0]  hp1_wstrb;
    logic         hp1_wlast;
    logic         hp1_wvalid;
    logic         hp1_wready;
    logic [1:0]   hp1_bresp;
    logic         hp1_bvalid;
    logic         hp1_bready;

    logic [$clog2(RES_BANK_DEPTH)-1:0] sram_waddr;
    logic [127:0]                      sram_wdata;
    logic                              sram_wen;
    logic [$clog2(RES_BANK_DEPTH)-1:0] sram_raddr;
    logic [127:0]                      sram_rdata;
    logic                              dma_err;

    logic [127:0] sram_model [0:RES_BANK_DEPTH-1];
    logic [127:0] ddr_words  [0:255];
    logic [127:0] store_words[0:15];

    int err_cnt;
    int store_count;

    // Instantiating the dut
    DMA dut (.*);

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Simple SRAM model for DMA store/load checking
    assign sram_rdata = sram_model[sram_raddr];

    always @(posedge clk) begin
        if (sram_wen) sram_model[sram_waddr] <= sram_wdata;
    end

    // Helper function to convert a byte address to a 128-bit word index
    function automatic int word_index(input logic [43:0] addr);
        return int'(addr[15:4]);
    endfunction

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // Initializes all input signals to idle values
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
        fetch_mode = 2'b00;
        concat_base = 32'h0;
        start = 1'b0;
        hp0_arready = 1'b0;
        hp0_rdata = 128'h0;
        hp0_rvalid = 1'b0;
        hp0_rlast = 1'b0;
        hp0_rresp = 2'b00;
        hp1_awready = 1'b0;
        hp1_wready = 1'b0;
        hp1_bresp = 2'b00;
        hp1_bvalid = 1'b0;
        store_count = 0;
    endtask

    // Resets everything
    task automatic reset_dut();
        rst = 1'b1;
        init_inputs();
        for (int i = 0; i < RES_BANK_DEPTH; i++) sram_model[i] = 128'h0;
        for (int i = 0; i < 256; i++) ddr_words[i] = {120'h0, 8'(i)};
        for (int i = 0; i < 16; i++) store_words[i] = 128'h0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
    endtask

    // Sends a one-cycle start pulse to the DMA
    task automatic pulse_start();
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
    endtask

    // AXI read slave model used for DDR to SRAM transfers
    task automatic axi_read_serve(input int bursts, input logic [1:0] resp = 2'b00);
        logic [43:0] addr;
        int beats;
        for (int b = 0; b < bursts; b++) begin
            while (!hp0_arvalid) @(posedge clk);
            addr = hp0_araddr;
            beats = hp0_arlen + 1;
            hp0_arready = 1'b1;
            @(posedge clk);
            hp0_arready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                while (!hp0_rready) @(posedge clk);
                hp0_rdata = ddr_words[word_index(addr) + beat];
                hp0_rresp = resp;
                hp0_rlast = (beat == beats - 1);
                hp0_rvalid = 1'b1;
                @(posedge clk);
                hp0_rvalid = 1'b0;
                hp0_rlast = 1'b0;
            end
            hp0_rresp = 2'b00;
        end
    endtask

    // AXI write slave model used for SRAM to DDR transfers
    task automatic axi_write_serve(input logic [1:0] resp = 2'b00);
        while (!hp1_awvalid) @(posedge clk);
        hp1_awready = 1'b1;
        @(posedge clk);
        hp1_awready = 1'b0;

        while (!hp1_wvalid) @(posedge clk);
        store_words[store_count] = hp1_wdata;
        store_count++;
        hp1_wready = 1'b1;
        @(posedge clk);
        hp1_wready = 1'b0;

        hp1_bresp = resp;
        hp1_bvalid = 1'b1;
        while (!hp1_bready) @(posedge clk);
        @(posedge clk);
        hp1_bvalid = 1'b0;
    endtask

    // Waits for the DMA done pulse with a timeout
    task automatic wait_done(input int timeout_cycles = 500);
        int count;
        count = 0;
        while (!done && count < timeout_cycles) begin
            @(posedge clk);
            count++;
        end
        chk(count < timeout_cycles, "timeout waiting for done");
        @(posedge clk);
    endtask

    initial begin
        // Testcase 1: reset should leave the DMA idle and set the fixed AXI constants
        err_cnt = 0;
        reset_dut();
        #1ps;
        chk(!busy && !done && !hp0_arvalid && !hp1_awvalid && !sram_wen && !dma_err,
            "reset outputs are idle");
        chk(hp0_arsize == 3'b100 && hp0_arburst == 2'b01 && hp0_arcache == 4'b0011,
            "HP0 AXI constants");
        chk(hp1_awsize == 3'b100 && hp1_awburst == 2'b01 && hp1_awcache == 4'b0011,
            "HP1 AXI constants");

        // Testcase 2: basic 2 by 2 load should fetch four 128-bit words using row_stride
        ddr_words[word_index(44'h1000)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A0;
        ddr_words[word_index(44'h1010)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A1;
        ddr_words[word_index(44'h1020)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A2;
        ddr_words[word_index(44'h1030)] = 128'h0000_0000_0000_0000_0000_0000_0000_00A3;
        src_base = 32'h1000;
        row_stride = 16'h20;
        tile_w = 8'd2;
        tile_h = 8'd2;
        ch_count = 8'd16;
        fetch_mode = 2'b00;
        fork
            pulse_start();
            axi_read_serve(4);
        join
        wait_done();
        chk(sram_model[0] == ddr_words[word_index(44'h1000)], "load writes pixel 0");
        chk(sram_model[1] == ddr_words[word_index(44'h1010)], "load writes pixel 1");
        chk(sram_model[2] == ddr_words[word_index(44'h1020)], "load writes row 1 pixel 0");
        chk(sram_model[3] == ddr_words[word_index(44'h1030)], "load writes row 1 pixel 1");
        chk(!dma_err, "load completes without error");

        // Testcase 3: a padded 3-wide row should insert zeros on the left and right edges
        reset_dut();
        src_base = 32'h2000;
        row_stride = 16'h10;
        tile_w = 8'd3;
        tile_h = 8'd1;
        ch_count = 8'd16;
        pad_left = 4'd1;
        pad_right = 4'd1;
        ddr_words[word_index(44'h2010)] = 128'hFACE_CAFE_DEAD_BEEF_0000_0000_0000_1234;
        fork
            pulse_start();
            axi_read_serve(1);
        join
        wait_done();
        chk(sram_model[0] == 128'h0, "left padding writes zero");
        chk(sram_model[1] == ddr_words[word_index(44'h2010)], "unpadded middle pixel fetched");
        chk(sram_model[2] == 128'h0, "right padding writes zero");

        // Testcase 4: store mode should write one SRAM word to DDR in the current DMA_STORE stub
        reset_dut();
        src_base = 32'h3000;
        fetch_mode = 2'b11;
        sram_model[0] = 128'hDEAD_BEEF_CAFE_BABE_0123_4567_89AB_CDEF;
        fork
            pulse_start();
            axi_write_serve();
        join
        wait_done();
        chk(store_count == 1, "store writes one beat in current stub");
        chk(store_words[0] == sram_model[0], "store forwards SRAM read data");
        chk(hp1_wstrb == 16'hFFFF, "store enables all byte lanes");
        chk(!dma_err, "store completes without error");

        // Testcase 5: a read response error should set dma_err
        reset_dut();
        src_base = 32'h4000;
        tile_w = 8'd1;
        tile_h = 8'd1;
        ch_count = 8'd16;
        fork
            pulse_start();
            axi_read_serve(1, 2'b10);
        join
        wait_done();
        chk(dma_err, "read SLVERR sets dma_err sticky");

        // Testcase 6: a write response error should also set dma_err
        reset_dut();
        src_base = 32'h5000;
        fetch_mode = 2'b11;
        fork
            pulse_start();
            axi_write_serve(2'b10);
        join
        wait_done();
        chk(dma_err, "write BRESP error sets dma_err sticky");

        $display("DMA_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "TIMEOUT");
    end

endmodule
