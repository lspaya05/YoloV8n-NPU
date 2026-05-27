// Testbench for NPU
`timescale 1ns/1ps

import NPU_ISA_pkg::*;
import NPU_HW_params_pkg::*;

module NPU_tb();

    // Instantiating all the variables used in this module and defining input and output pins
    localparam int CLK_HALF_NS = 5;
    localparam int MAX_INSTR   = 64;
    localparam int MAX_EVENTS  = 128;

    logic clk;
    logic rst;

    logic [31:0] s_axil_awaddr;
    logic        s_axil_awvalid;
    logic        s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic        s_axil_wvalid;
    logic        s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;

    logic [43:0] seq_araddr;
    logic        seq_arvalid;
    logic [7:0]  seq_arlen;
    logic [2:0]  seq_arsize;
    logic [1:0]  seq_arburst;
    logic        seq_arready;
    logic [31:0] seq_rdata;
    logic        seq_rvalid;
    logic        seq_rlast;
    logic [1:0]  seq_rresp;
    logic        seq_rready;

    logic [43:0]  dma_araddr;
    logic         dma_arvalid;
    logic [7:0]   dma_arlen;
    logic [2:0]   dma_arsize;
    logic [1:0]   dma_arburst;
    logic [3:0]   dma_arcache;
    logic         dma_arready;
    logic [127:0] dma_rdata;
    logic         dma_rvalid;
    logic         dma_rlast;
    logic [1:0]   dma_rresp;
    logic         dma_rready;

    logic [43:0]  wt_araddr;
    logic         wt_arvalid;
    logic [7:0]   wt_arlen;
    logic [2:0]   wt_arsize;
    logic [1:0]   wt_arburst;
    logic [3:0]   wt_arcache;
    logic         wt_arready;
    logic [127:0] wt_rdata;
    logic         wt_rvalid;
    logic         wt_rlast;
    logic [1:0]   wt_rresp;
    logic         wt_rready;

    logic [43:0]  st_awaddr;
    logic         st_awvalid;
    logic [7:0]   st_awlen;
    logic [2:0]   st_awsize;
    logic [1:0]   st_awburst;
    logic [3:0]   st_awcache;
    logic         st_awready;
    logic [127:0] st_wdata;
    logic [15:0]  st_wstrb;
    logic         st_wlast;
    logic         st_wvalid;
    logic         st_wready;
    logic [1:0]   st_bresp;
    logic         st_bvalid;
    logic         st_bready;

    logic irq_done;
    logic fetch_err;
    logic dma_err;

    logic [127:0] instr_mem [0:MAX_INSTR-1];
    logic [127:0] dma_words [0:4095];
    logic [127:0] wt_words [0:4095];
    logic [127:0] store_words [0:MAX_EVENTS-1];
    logic         store_last [0:MAX_EVENTS-1];
    logic [43:0]  seq_ar_seen [0:MAX_EVENTS-1];
    logic [43:0]  dma_ar_seen [0:MAX_EVENTS-1];
    logic [7:0]   dma_arlen_seen [0:MAX_EVENTS-1];
    logic [43:0]  wt_ar_seen [0:MAX_EVENTS-1];
    logic [7:0]   wt_arlen_seen [0:MAX_EVENTS-1];
    logic [43:0]  st_aw_seen [0:MAX_EVENTS-1];
    logic [7:0]   st_awlen_seen [0:MAX_EVENTS-1];

    int err_cnt;
    int seq_fetch_count;
    int dma_read_count;
    int wt_read_count;
    int store_burst_count;
    int store_count;
    int irq_count;
    int disp_count [0:5];

    // Instantiating the dut
    NPU dut (
        .clk(clk),
        .rst(rst),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .seq_araddr(seq_araddr),
        .seq_arvalid(seq_arvalid),
        .seq_arlen(seq_arlen),
        .seq_arsize(seq_arsize),
        .seq_arburst(seq_arburst),
        .seq_arready(seq_arready),
        .seq_rdata(seq_rdata),
        .seq_rvalid(seq_rvalid),
        .seq_rlast(seq_rlast),
        .seq_rresp(seq_rresp),
        .seq_rready(seq_rready),
        .dma_araddr(dma_araddr),
        .dma_arvalid(dma_arvalid),
        .dma_arlen(dma_arlen),
        .dma_arsize(dma_arsize),
        .dma_arburst(dma_arburst),
        .dma_arcache(dma_arcache),
        .dma_arready(dma_arready),
        .dma_rdata(dma_rdata),
        .dma_rvalid(dma_rvalid),
        .dma_rlast(dma_rlast),
        .dma_rresp(dma_rresp),
        .dma_rready(dma_rready),
        .wt_araddr(wt_araddr),
        .wt_arvalid(wt_arvalid),
        .wt_arlen(wt_arlen),
        .wt_arsize(wt_arsize),
        .wt_arburst(wt_arburst),
        .wt_arcache(wt_arcache),
        .wt_arready(wt_arready),
        .wt_rdata(wt_rdata),
        .wt_rvalid(wt_rvalid),
        .wt_rlast(wt_rlast),
        .wt_rresp(wt_rresp),
        .wt_rready(wt_rready),
        .st_awaddr(st_awaddr),
        .st_awvalid(st_awvalid),
        .st_awlen(st_awlen),
        .st_awsize(st_awsize),
        .st_awburst(st_awburst),
        .st_awcache(st_awcache),
        .st_awready(st_awready),
        .st_wdata(st_wdata),
        .st_wstrb(st_wstrb),
        .st_wlast(st_wlast),
        .st_wvalid(st_wvalid),
        .st_wready(st_wready),
        .st_bresp(st_bresp),
        .st_bvalid(st_bvalid),
        .st_bready(st_bready),
        .irq_done(irq_done),
        .fetch_err(fetch_err),
        .dma_err(dma_err)
    );

    // Creating the simulated clock
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Count important one-cycle pulses after the dut has updated them
    always @(negedge clk) begin
        if (irq_done) irq_count++;
        for (int i = 0; i < 6; i++) begin
            if (dut.disp_push[i]) disp_count[i]++;
        end
    end

    // Helper function to make one full 128-bit instruction
    function automatic logic [127:0] make_instr(
        input logic [7:0] opcode,
        input logic [3:0] unit_id,
        input logic [3:0] dep_flags,
        input logic [111:0] payload
    );
        begin
            make_instr = {opcode, unit_id, dep_flags, payload};
        end
    endfunction

    // Helper function to make a DMA descriptor payload
    function automatic logic [111:0] make_dma_payload(
        input logic [31:0] base_addr,
        input logic [15:0] row_stride,
        input logic [7:0] tile_w,
        input logic [7:0] tile_h,
        input logic [7:0] ch_count,
        input logic [3:0] pad_top,
        input logic [3:0] pad_bot,
        input logic [3:0] pad_left,
        input logic [3:0] pad_right
    );
        begin
            make_dma_payload = {24'h0, pad_right, pad_left, pad_bot, pad_top,
                                ch_count, tile_h, tile_w, row_stride, base_addr};
        end
    endfunction

    // Helper function to make a CONCAT payload
    function automatic logic [111:0] make_concat_payload(
        input logic [31:0] base_addr_a,
        input logic [31:0] base_addr_b,
        input logic [15:0] row_stride,
        input logic [7:0] tile_w,
        input logic [7:0] tile_h,
        input logic [7:0] ch_count,
        input logic [3:0] pad_top,
        input logic [3:0] pad_bot,
        input logic [3:0] pad_left,
        input logic [3:0] pad_right
    );
        begin
            make_concat_payload = {base_addr_b[23:0], pad_right, pad_left, pad_bot, pad_top,
                                   ch_count, tile_h, tile_w, row_stride, base_addr_a};
        end
    endfunction

    // Helper function to make a config payload
    function automatic logic [111:0] make_config_payload(
        input logic [7:0] tile_m,
        input logic [7:0] tile_n,
        input logic [7:0] tile_k,
        input logic [3:0] stride,
        input logic [1:0] pad_mode,
        input logic [2:0] act_type,
        input logic [2:0] pool_size,
        input logic [31:0] coeff_base
    );
        begin
            make_config_payload = {44'h0, coeff_base, pool_size, act_type,
                                   pad_mode, stride, tile_k, tile_n, tile_m};
        end
    endfunction

    // Helper function to make distinct 128-bit memory data
    function automatic logic [127:0] make_word(input int tag);
        logic [127:0] word;
        begin
            word = '0;
            for (int b = 0; b < 16; b++) begin
                word[b*8 +: 8] = 8'(tag + b);
            end
            make_word = word;
        end
    endfunction

    // Helper function to convert byte addresses to 128-bit word addresses
    function automatic int word_index(input logic [43:0] addr);
        begin
            word_index = int'(addr[15:4]);
        end
    endfunction

    // Helper task for checking expected values
    task automatic chk(input logic cond, input string msg);
        if (!cond) begin
            err_cnt++;
            $error("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    // Initialize all top-level inputs
    task automatic init_inputs();
        s_axil_awaddr = 32'h0;
        s_axil_awvalid = 1'b0;
        s_axil_wdata = 32'h0;
        s_axil_wvalid = 1'b0;
        s_axil_bready = 1'b0;
        seq_arready = 1'b0;
        seq_rdata = 32'h0;
        seq_rvalid = 1'b0;
        seq_rlast = 1'b0;
        seq_rresp = 2'b00;
        dma_arready = 1'b0;
        dma_rdata = 128'h0;
        dma_rvalid = 1'b0;
        dma_rlast = 1'b0;
        dma_rresp = 2'b00;
        wt_arready = 1'b0;
        wt_rdata = 128'h0;
        wt_rvalid = 1'b0;
        wt_rlast = 1'b0;
        wt_rresp = 2'b00;
        st_awready = 1'b0;
        st_wready = 1'b0;
        st_bresp = 2'b00;
        st_bvalid = 1'b0;
        seq_fetch_count = 0;
        dma_read_count = 0;
        wt_read_count = 0;
        store_burst_count = 0;
        store_count = 0;
        irq_count = 0;
        for (int i = 0; i < 6; i++) disp_count[i] = 0;
    endtask

    // Reset the dut and all testbench memories
    task automatic reset_dut();
        rst = 1'b1;
        init_inputs();
        for (int i = 0; i < MAX_INSTR; i++) instr_mem[i] = 128'h0;
        for (int i = 0; i < 4096; i++) begin
            dma_words[i] = make_word(i);
            wt_words[i] = make_word(16'h8000 + i);
        end
        for (int i = 0; i < MAX_EVENTS; i++) begin
            store_words[i] = 128'h0;
            store_last[i] = 1'b0;
            seq_ar_seen[i] = 44'h0;
            dma_ar_seen[i] = 44'h0;
            dma_arlen_seen[i] = 8'h0;
            wt_ar_seen[i] = 44'h0;
            wt_arlen_seen[i] = 8'h0;
            st_aw_seen[i] = 44'h0;
            st_awlen_seen[i] = 8'h0;
        end
        repeat (6) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
    endtask

    // AXI-Lite write used by the CPU to program Sequencer CSRs
    task automatic axil_write(input logic [31:0] addr, input logic [31:0] data);
        @(negedge clk);
        s_axil_awaddr = addr;
        s_axil_wdata = data;
        s_axil_awvalid = 1'b1;
        s_axil_wvalid = 1'b1;
        s_axil_bready = 1'b1;
        while (!(s_axil_awready && s_axil_wready)) @(negedge clk);
        @(negedge clk);
        s_axil_awvalid = 1'b0;
        s_axil_wvalid = 1'b0;
        while (!s_axil_bvalid) @(negedge clk);
        chk(s_axil_bresp == 2'b00, "AXI-Lite write response is OKAY");
        @(negedge clk);
        s_axil_bready = 1'b0;
    endtask

    // Start a program by writing instruction base, instruction count, and kick
    task automatic start_program(input logic [31:0] base_addr, input logic [31:0] instr_count);
        axil_write(32'h0, base_addr);
        axil_write(32'h4, instr_count);
        axil_write(32'h8, 32'h1);
    endtask

    // Serve instruction fetches from instr_mem over the Sequencer read port
    task automatic serve_seq_fetch(input int instructions, input logic [1:0] resp = 2'b00);
        int index;
        int base_word;
        for (int inst = 0; inst < instructions; inst++) begin
            while (!seq_arvalid) @(negedge clk);
            seq_ar_seen[seq_fetch_count] = seq_araddr;
            seq_fetch_count++;
            chk(seq_arlen == 8'd3 && seq_arsize == 3'b010 && seq_arburst == 2'b01,
                "Sequencer fetch uses four 32-bit INCR beats");
            base_word = word_index(seq_araddr);
            seq_arready = 1'b1;
            @(negedge clk);
            seq_arready = 1'b0;
            for (int beat = 0; beat < 4; beat++) begin
                while (!seq_rready) @(negedge clk);
                index = base_word;
                seq_rdata = instr_mem[index][beat*32 +: 32];
                seq_rresp = resp;
                seq_rlast = (beat == 3);
                seq_rvalid = 1'b1;
                @(negedge clk);
                seq_rvalid = 1'b0;
                seq_rlast = 1'b0;
            end
            seq_rresp = 2'b00;
        end
    endtask

    // Serve DMA HP0 reads from dma_words
    task automatic serve_dma_read(input int bursts, input int ar_delay = 0, input int r_gap = 0,
                                  input logic [1:0] resp = 2'b00);
        logic [43:0] addr;
        int beats;
        int wait_cycles;
        for (int burst = 0; burst < bursts; burst++) begin
            wait_cycles = 0;
            while (!dma_arvalid && wait_cycles < 1000) begin
                @(negedge clk);
                wait_cycles++;
            end
            if (wait_cycles >= 1000) begin
                chk(1'b0, "timeout waiting for DMA HP0 ARVALID");
            end else begin
                repeat (ar_delay) @(negedge clk);
                addr = dma_araddr;
                beats = dma_arlen + 1;
                dma_ar_seen[dma_read_count] = dma_araddr;
                dma_arlen_seen[dma_read_count] = dma_arlen;
                dma_read_count++;
                chk(dma_arsize == 3'b100 && dma_arburst == 2'b01 && dma_arcache == 4'b0011,
                    "DMA HP0 read constants are correct");
                dma_arready = 1'b1;
                @(negedge clk);
                dma_arready = 1'b0;
                for (int beat = 0; beat < beats; beat++) begin
                    repeat (r_gap) @(negedge clk);
                    while (!dma_rready) @(negedge clk);
                    dma_rdata = dma_words[word_index(addr) + beat];
                    dma_rresp = resp;
                    dma_rlast = (beat == beats - 1);
                    dma_rvalid = 1'b1;
                    @(negedge clk);
                    dma_rvalid = 1'b0;
                    dma_rlast = 1'b0;
                end
                dma_rresp = 2'b00;
            end
        end
    endtask

    // Serve DMA HP1 weight reads from wt_words
    task automatic serve_wt_read(input int ar_delay = 0, input int r_gap = 0,
                                 input logic [1:0] resp = 2'b00);
        logic [43:0] addr;
        int beats;
        while (!wt_arvalid) @(negedge clk);
        repeat (ar_delay) @(negedge clk);
        addr = wt_araddr;
        beats = wt_arlen + 1;
        wt_ar_seen[wt_read_count] = wt_araddr;
        wt_arlen_seen[wt_read_count] = wt_arlen;
        wt_read_count++;
        chk(wt_arsize == 3'b100 && wt_arburst == 2'b01 && wt_arcache == 4'b0011,
            "DMA HP1 read constants are correct");
        wt_arready = 1'b1;
        @(negedge clk);
        wt_arready = 1'b0;
        for (int beat = 0; beat < beats; beat++) begin
            repeat (r_gap) @(negedge clk);
            while (!wt_rready) @(negedge clk);
            wt_rdata = wt_words[word_index(addr) + beat];
            wt_rresp = resp;
            wt_rlast = (beat == beats - 1);
            wt_rvalid = 1'b1;
            @(negedge clk);
            wt_rvalid = 1'b0;
            wt_rlast = 1'b0;
        end
        wt_rresp = 2'b00;
    endtask

    // Serve DMA HP2 stores and capture the data written out of the NPU
    task automatic serve_store(input int rows, input int aw_delay = 0, input int w_gap = 0,
                               input logic [1:0] resp = 2'b00);
        int beats;
        for (int row = 0; row < rows; row++) begin
            while (!st_awvalid) @(negedge clk);
            repeat (aw_delay) @(negedge clk);
            beats = st_awlen + 1;
            st_aw_seen[store_burst_count] = st_awaddr;
            st_awlen_seen[store_burst_count] = st_awlen;
            store_burst_count++;
            chk(st_awsize == 3'b100 && st_awburst == 2'b01 && st_awcache == 4'b0011 &&
                st_wstrb == 16'hFFFF, "DMA HP2 write constants are correct");
            st_awready = 1'b1;
            @(negedge clk);
            st_awready = 1'b0;
            for (int beat = 0; beat < beats; beat++) begin
                repeat (w_gap) @(negedge clk);
                while (!st_wvalid) @(negedge clk);
                store_words[store_count] = st_wdata;
                store_last[store_count] = st_wlast;
                store_count++;
                st_wready = 1'b1;
                @(negedge clk);
                st_wready = 1'b0;
            end
            st_bresp = resp;
            st_bvalid = 1'b1;
            while (!st_bready) @(negedge clk);
            @(negedge clk);
            st_bvalid = 1'b0;
            st_bresp = 2'b00;
        end
    endtask

    // Wait a fixed number of cycles and make sure no unexpected external access starts
    task automatic wait_no_dma_access(input int cycles, input string msg);
        for (int i = 0; i < cycles; i++) begin
            @(negedge clk);
            chk(!dma_arvalid && !wt_arvalid && !st_awvalid, msg);
        end
    endtask

    task automatic give_vpu_to_dma_token();
        instr_mem[0] = make_instr(OP_LUT_BYPASS, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        wait_vpu_done("VPU producer created VPU->DMA dependency token");
    endtask

    task automatic give_sa_tokens();
        instr_mem[0] = make_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0,
                                  make_dma_payload(32'hF000, 16'h10, 8'd1, 8'd1, 8'd16,
                                                   4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(1, 0, 0);
        join
        repeat (4) @(negedge clk);
    endtask

    task automatic give_psb_tokens();
        give_sa_tokens();
        instr_mem[0] = make_instr(OP_MATMUL, UNIT_SA, 4'h0, {111'h0, 1'b0});
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        wait_sa_done("SA producer created SA->PSB dependency token");
    endtask

    // Waits for SA done with a timeout
    task automatic wait_sa_done(input string msg);
        int count;
        count = 0;
        while (!dut.sa_done_pulse && count < 500) begin
            @(negedge clk);
            count++;
        end
        chk(count < 500, msg);
    endtask

    // Waits for PSB done with a timeout
    task automatic wait_psb_done(input string msg);
        int count;
        count = 0;
        while (!dut.psb_done_pulse && count < 500) begin
            @(negedge clk);
            count++;
        end
        chk(count < 500, msg);
    endtask

    // Waits for Requant done with a timeout
    task automatic wait_req_done(input string msg);
        int count;
        count = 0;
        while (!dut.req_done_pulse && count < 1000) begin
            @(negedge clk);
            count++;
        end
        chk(count < 1000, msg);
    endtask

    // Waits for VPU done with a timeout
    task automatic wait_vpu_done(input string msg);
        int count;
        count = 0;
        while (!dut.vpu_done_pulse && count < 1000) begin
            @(negedge clk);
            count++;
        end
        chk(count < 1000, msg);
    endtask

    initial begin
        err_cnt = 0;

        // Testcase 1: Reset and idle outputs
        // What it does: Resets the full NPU top level and checks the outside world sees no active transaction.
        // Input: rst=1 for several cycles, all AXI ready/valid inputs held low.
        // Expected output: AXI-Lite is ready for writes, all master valid signals are low, irq_done/fetch_err/dma_err are low.
        reset_dut();
        #1ps;
        chk(s_axil_awready && s_axil_wready && !s_axil_bvalid, "AXI-Lite slave is idle after reset");
        chk(!seq_arvalid && !dma_arvalid && !wt_arvalid && !st_awvalid && !st_wvalid,
            "no AXI master transaction after reset");
        chk(!irq_done && !fetch_err && !dma_err, "status outputs clear after reset");

        // Testcase 2: AXI-Lite CSR edge case with zero instruction count
        // What it does: Writes base/count/kick through the CPU register interface, but count is zero.
        // Input: instr_base=0x1000, instr_count=0, kick=1.
        // Expected output: AXI-Lite writes return OKAY, no instruction fetch starts, and no DMA access starts.
        reset_dut();
        start_program(32'h1000, 32'd0);
        wait_no_dma_access(10, "zero-count program must not start DMA");
        chk(seq_fetch_count == 0 && !seq_arvalid, "zero-count program does not fetch instructions");
        chk(!fetch_err && !dma_err && irq_count == 0, "zero-count program leaves status clean");

        // Testcase 3: CONFIG instruction updates Sequencer configuration registers
        // What it does: Fetches one CONFIG instruction through HP0_SEQ and checks the top-level config wires.
        // Input: CONFIG tile_M=7, tile_N=9, tile_K=11, stride=2, pad_mode=1, act_type=3, pool_size=5, coeff_base=0x12345678.
        // Expected output: Sequencer fetches one instruction from 0x0000 and the internal cfg wires hold those exact fields.
        reset_dut();
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd7, 8'd9, 8'd11, 4'd2, 2'd1,
                                                      3'd3, 3'd5, 32'h1234_5678));
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        repeat (6) @(negedge clk);
        chk(seq_fetch_count == 1 && seq_ar_seen[0] == 44'h0, "CONFIG fetched from instruction base");
        chk(dut.cfg_tile_M == 8'd7 && dut.cfg_tile_N == 8'd9 && dut.cfg_tile_K == 8'd11,
            "CONFIG tile dimensions reached top-level config wires");
        chk(dut.cfg_stride == 4'd2 && dut.cfg_pad_mode == 2'd1 &&
            dut.cfg_act_type == 3'd3 && dut.cfg_pool_size == 3'd5 &&
            dut.cfg_coeff_base == 32'h1234_5678, "CONFIG non-dimension fields reached top-level config wires");

        // Testcase 4: Sequencer routing to every unit FIFO
        // What it does: Fetches one instruction for DMA Ch0, DMA Ch1, SA, PSB, Requant, and VPU.
        // Input: COEFF_LOAD, WT_LOAD, MATMUL, PSB_ACC, REQUANT, RELU instructions.
        // Expected output: disp_push[0], [5], [1], [2], [3], and [4] each pulse once, proving top-level instruction fanout is wired.
        reset_dut();
        instr_mem[0] = make_instr(OP_COEFF_LOAD, UNIT_DMA, 4'h0, {70'h0, 10'd2, 32'h2000});
        instr_mem[1] = make_instr(OP_WT_LOAD, UNIT_DMA, 4'h0, {79'h0, 1'b0, 32'h3000});
        instr_mem[2] = make_instr(OP_MATMUL, UNIT_SA, 4'h0, {111'h0, 1'b0});
        instr_mem[3] = make_instr(OP_PSB_ACC, UNIT_PSB, 4'h0, 112'h0);
        instr_mem[4] = make_instr(OP_REQUANT, UNIT_REQ, 4'h0, {102'h0, 10'd16});
        instr_mem[5] = make_instr(OP_RELU, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd6);
            serve_seq_fetch(6);
        join
        repeat (20) @(negedge clk);
        chk(disp_count[0] == 1, "DMA Ch0 dispatch pulse seen");
        chk(disp_count[5] == 1, "DMA Ch1 dispatch pulse seen");
        chk(disp_count[1] == 1, "SA dispatch pulse seen");
        chk(disp_count[2] == 1, "PSB dispatch pulse seen");
        chk(disp_count[3] == 1, "Requant dispatch pulse seen");
        chk(disp_count[4] == 1, "VPU dispatch pulse seen");

        // Testcase 5: COEFF_LOAD through top level into SRAMHub coefficient BRAM
        // What it does: Runs a real COEFF_LOAD instruction and serves the DMA HP0 read with backpressure.
        // Input: coeff base=0x4000, ch_count=4, two HP0 DMA beats with packed M/S coefficient pairs.
        // Expected output: DMA HP0 issues one two-beat burst at 0x4000 and coefficient BRAM entries 0..3 contain the unpacked values.
        reset_dut();
        instr_mem[0] = make_instr(OP_COEFF_LOAD, UNIT_DMA, 4'h0, {70'h0, 10'd4, 32'h4000});
        dma_words[word_index(44'h4000)] = {32'hBBBB_0001, 28'h0, 4'h1, 32'hAAAA_0000, 28'h0, 4'h0};
        dma_words[word_index(44'h4010)] = {32'hDDDD_0003, 28'h0, 4'h3, 32'hCCCC_0002, 28'h0, 4'h2};
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(1, 3, 2);
        join
        repeat (10) @(negedge clk);
        chk(dma_read_count == 1 && dma_ar_seen[0] == 44'h4000 && dma_arlen_seen[0] == 8'd1,
            "COEFF_LOAD DMA burst shape is correct");
        chk(dut.SRAM_hub.coeff_bram.mem[0] == {32'hAAAA_0000, 4'h0}, "coefficient 0 written through SRAMHub");
        chk(dut.SRAM_hub.coeff_bram.mem[1] == {32'hBBBB_0001, 4'h1}, "coefficient 1 written through SRAMHub");
        chk(dut.SRAM_hub.coeff_bram.mem[2] == {32'hCCCC_0002, 4'h2}, "coefficient 2 written through SRAMHub");
        chk(dut.SRAM_hub.coeff_bram.mem[3] == {32'hDDDD_0003, 4'h3}, "coefficient 3 written through SRAMHub");

        // Testcase 6: LUT_LOAD edge case writes all 256 bytes to selected LUT bank
        // What it does: Runs a real LUT_LOAD instruction and lets DMA drain sixteen 128-bit beats into byte-wide LUT memory.
        // Input: lut_src_addr=0x5000, lut_sel=1, HP0 DMA returns the default test pattern.
        // Expected output: DMA requests sixteen beats, HREDUCE LUT byte 0/15/16/255 match the returned DDR data, and act LUT is not selected.
        reset_dut();
        instr_mem[0] = make_instr(OP_LUT_LOAD, UNIT_DMA, 4'h0, {79'h0, 1'b1, 32'h5000});
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(1, 1, 1);
        join
        repeat (20) @(negedge clk);
        chk(dma_read_count == 1 && dma_ar_seen[0] == 44'h5000 && dma_arlen_seen[0] == 8'd15,
            "LUT_LOAD DMA burst shape is correct");
        chk(dut.SRAM_hub.hreduce_lut.mem[0] == dma_words[word_index(44'h5000)][7:0], "HREDUCE LUT byte 0 written");
        chk(dut.SRAM_hub.hreduce_lut.mem[15] == dma_words[word_index(44'h5000)][127:120], "HREDUCE LUT byte 15 written");
        chk(dut.SRAM_hub.hreduce_lut.mem[16] == dma_words[word_index(44'h5010)][7:0], "HREDUCE LUT byte 16 written");
        chk(dut.SRAM_hub.hreduce_lut.mem[255] == dma_words[word_index(44'h50F0)][127:120], "HREDUCE LUT byte 255 written");

        // Testcase 7: WT_LOAD through top level to the HP1 weight DMA channel
        // What it does: Runs a real WT_LOAD instruction and serves the HP1 read channel with stalls between beats.
        // Input: wt_base_addr=0x6000.
        // Expected output: HP1 issues one 16-beat burst at 0x6000 and the top-level weight channel returns idle afterward.
        reset_dut();
        instr_mem[0] = make_instr(OP_WT_LOAD, UNIT_DMA, 4'h0, {79'h0, 1'b0, 32'h6000});
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_wt_read(2, 2);
        join
        repeat (10) @(negedge clk);
        chk(wt_read_count == 1 && wt_ar_seen[0] == 44'h6000 && wt_arlen_seen[0] == 8'd15,
            "WT_LOAD HP1 burst shape is correct");
        chk(dut.dma_ch1_idle_w == 1'b1 && !dma_err, "WT_LOAD completed without DMA error");

        // Testcase 8: DMA_LOAD consumes the reset SA->DMA free-resource token before HP0 access
        // What it does: Runs a DMA_LOAD instruction using the initial free Act-bank token.
        // Input: DMA_LOAD base=0x7000, tile 1x1, ch_count=16.
        // Expected output: One read at 0x7000 completes and the SA->DMA token is consumed.
        reset_dut();
        instr_mem[0] = make_instr(OP_DMA_LOAD, UNIT_DMA, 4'h0,
                                  make_dma_payload(32'h7000, 16'h10, 8'd1, 8'd1, 8'd16,
                                                   4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(1, 0, 0);
        join
        repeat (10) @(negedge clk);
        chk(dma_read_count == 1 && dma_ar_seen[0] == 44'h7000 && dma_arlen_seen[0] == 8'd0,
            "DMA_LOAD starts after dependency token and reads one beat");
        chk(dut.sa_to_dma_empty == 1'b1, "SA->DMA token was consumed by Dispatch_DMA");

        // Testcase 9: DMA_STORE waits for VPU->DMA token, reads Output Bank, writes HP2, and raises irq_done
        // What it does: Preloads Output Bank as if VPU/Requant produced data, then runs a real DMA_STORE instruction.
        // Input: STORE dest=0x8000, tile_w=2, tile_h=1, ch_count=16, VPU->DMA token is supplied late.
        // Expected output: No HP2 AW before token; after token, HP2 writes two stored words and irq_done pulses once.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
        dut.SRAM_hub.out_bank.mem[1] = 128'h9999_AAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0001;
        instr_mem[0] = make_instr(OP_DMA_STORE, UNIT_DMA, 4'h0,
                                  make_dma_payload(32'h8000, 16'h20, 8'd2, 8'd1, 8'd16,
                                                   4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
                wait_no_dma_access(20, "DMA_STORE must wait for VPU->DMA token");
                give_vpu_to_dma_token();
            end
            serve_store(1, 2, 1);
        join
        repeat (10) @(negedge clk);
        chk(store_burst_count == 1 && st_aw_seen[0] == 44'h8000 && st_awlen_seen[0] == 8'd1,
            "DMA_STORE HP2 burst shape is correct");
        chk(store_count == 2, "DMA_STORE wrote two beats");
        chk(store_words[0] == 128'h1111_2222_3333_4444_5555_6666_7777_8888, "STORE beat 0 came from Output Bank");
        chk(store_words[1] == 128'h9999_AAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0001, "STORE beat 1 came from Output Bank");
        chk(store_last[0] == 1'b0 && store_last[1] == 1'b1, "STORE wlast only asserted on final beat");
        chk(irq_count == 1 && irq_done == 1'b0, "top-level irq_done pulsed once for STORE completion");

        // Testcase 10: FENCE instruction waits on unit_done masks without dispatching to a block FIFO
        // What it does: Runs a FENCE that waits on UNIT_DMA while DMA is already idle.
        // Input: FENCE payload unit_mask has only bit 1 set.
        // Expected output: One instruction is fetched, no unit FIFO dispatch happens, and no external DMA access happens.
        reset_dut();
        instr_mem[0] = make_instr(OP_FENCE, UNIT_SEQ, 4'h0, {106'h0, 6'b000010});
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        repeat (10) @(negedge clk);
        chk(seq_fetch_count == 1, "FENCE instruction was fetched");
        chk(disp_count[0] == 0 && disp_count[1] == 0 && disp_count[2] == 0 &&
            disp_count[3] == 0 && disp_count[4] == 0 && disp_count[5] == 0,
            "FENCE did not dispatch to any unit FIFO");
        chk(dma_read_count == 0 && wt_read_count == 0 && store_burst_count == 0,
            "FENCE did not create any DMA traffic");

        // Testcase 11: UPSAMPLE instruction through top level
        // What it does: Runs UPSAMPLE through Sequencer, Dispatch_DMA, DMA, and SRAMHub.
        // Input: UPSAMPLE base=0xB000, tile 1x1, ch_count=16, using the reset SA->DMA free token.
        // Expected output: DMA does not read before the token, then performs four reads from the same source pixel.
        reset_dut();
        instr_mem[0] = make_instr(OP_UPSAMPLE, UNIT_DMA, 4'h0,
                                  make_dma_payload(32'hB000, 16'h10, 8'd1, 8'd1, 8'd16,
                                                   4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(4, 1, 0);
        join
        repeat (10) @(negedge clk);
        chk(dma_read_count == 4, "UPSAMPLE made four DMA reads");
        chk(dma_ar_seen[0] == 44'hB000 && dma_ar_seen[1] == 44'hB000 &&
            dma_ar_seen[2] == 44'hB000 && dma_ar_seen[3] == 44'hB000,
            "UPSAMPLE duplicated the same source address four times");

        // Testcase 12: CONCAT instruction through top level
        // What it does: Runs CONCAT through Sequencer, Dispatch_DMA, and DMA.
        // Input: CONCAT base A=0xC000, base B=0xD000, tile 1x1, ch_count=32, using the reset SA->DMA free token.
        // Expected output: DMA reads one half-channel beat from base A and one half-channel beat from base B.
        reset_dut();
        instr_mem[0] = make_instr(OP_CONCAT, UNIT_DMA, 4'h0,
                                  make_concat_payload(32'hC000, 32'hD000, 16'h10, 8'd1, 8'd1, 8'd32,
                                                      4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(2, 1, 0);
        join
        repeat (10) @(negedge clk);
        chk(dma_read_count == 2, "CONCAT made two DMA reads");
        chk(dma_ar_seen[0] == 44'hC000 && dma_ar_seen[1] == 44'hD000, "CONCAT used both source bases");
        chk(dma_arlen_seen[0] == 8'd0 && dma_arlen_seen[1] == 8'd0, "CONCAT split 32 channels into one beat per source");

        // Testcase 13: MATMUL instruction through top level
        // What it does: Runs MATMUL through Sequencer, SA FIFO, dependency gates, Dispatch_SA, and SA_top.
        // Input: MATMUL with tile_sel=0, DMA->SA and PSB->SA tokens supplied after fetch.
        // Expected output: SA consumes both dependency tokens and eventually pulses unit_done.
        reset_dut();
        instr_mem[0] = make_instr(OP_MATMUL, UNIT_SA, 4'h0, {111'h0, 1'b0});
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        give_sa_tokens();
        wait_sa_done("MATMUL produced SA unit_done");
        chk(dut.dma_to_sa_empty == 1'b1 && dut.psb_to_sa_empty == 1'b1, "MATMUL consumed SA dependency tokens");

        // Testcase 14: PSB_ACC instruction through top level
        // What it does: Runs one PSB_ACC instruction through the PSB wrapper.
        // Input: PSB_ACC with SA->PSB and REQ->PSB dependency tokens supplied after fetch.
        // Expected output: PSB consumes both tokens and pulses unit_done for the accumulated row.
        reset_dut();
        instr_mem[0] = make_instr(OP_PSB_ACC, UNIT_PSB, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        give_psb_tokens();
        wait_psb_done("PSB_ACC produced PSB unit_done");

        // Testcase 15: PSB_FLUSH instruction through top level
        // What it does: Runs PSB_FLUSH through the PSB wrapper and psb datapath.
        // Input: PSB_FLUSH with SA->PSB and REQ->PSB dependency tokens supplied after fetch.
        // Expected output: PSB emits row_out_valid during the flush and pulses unit_done after the flush sequence.
        reset_dut();
        instr_mem[0] = make_instr(OP_PSB_FLUSH, UNIT_PSB, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        give_psb_tokens();
        wait_psb_done("PSB_FLUSH produced PSB unit_done");
        chk(dut.psb_row_out_valid_w == 1'b0, "PSB_FLUSH completed and row_out_valid returned low");

        // Testcase 16: REQUANT instruction through top level
        // What it does: Runs REQUANT through Sequencer, Requant wrapper, coeff BRAM, and RequantPipeline.
        // Input: REQUANT ch_count=1 runs alongside a real PSB_FLUSH. Dependency
        // counters are seeded to model prior producer completion.
        // Expected output: Requant consumes tokens, reads coeff address 0, writes Output Bank word 0, and pulses unit_done.
        reset_dut();
        dut.SRAM_hub.coeff_bram.mem[0] = {32'h0000_0001, 4'h0};
        for (int row = 0; row < SA_ROWS; row++) begin
            for (int col = 0; col < SA_COLS; col++) begin
                dut.u_psb_block.partial_sum_buffer.buffer[row][col] = 32'sd16;
            end
        end
        instr_mem[0] = make_instr(OP_REQUANT, UNIT_REQ, 4'h0, {102'h0, 10'd1});
        instr_mem[1] = make_instr(OP_PSB_FLUSH, UNIT_PSB, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        give_psb_tokens();
        wait_req_done("REQUANT produced Requant unit_done");
        chk(dut.psb_to_req_empty == 1'b1 && dut.vpu_to_req_empty == 1'b1, "REQUANT consumed Requant dependency tokens");
        chk(dut.SRAM_hub.out_bank.mem[0] == 128'h1010_1010_1010_1010_1010_1010_1010_1010,
            "REQUANT math converts the PSB flush row to one INT8 output word");

        // Testcase 17: LUT_BYPASS instruction through top level
        // What it does: Runs LUT_BYPASS through VPU wrapper.
        // Input: LUT_BYPASS bypass_en=1 with REQ->VPU and DMA->VPU dependency tokens.
        // Expected output: VPU consumes tokens, pulses unit_done, and latches lut_sel high.
        reset_dut();
        instr_mem[0] = make_instr(OP_LUT_BYPASS, UNIT_VPU, 4'h0, {111'h0, 1'b1});
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        wait_vpu_done("LUT_BYPASS produced VPU unit_done");
        chk(dut.vpu_lut_sel_w == 1'b1, "LUT_BYPASS latched LUT select high");

        // Testcase 18: SIMD_ACT instruction through top level
        // What it does: Runs SIMD_ACT through the VPU wrapper stub.
        // Input: SIMD_ACT with REQ->VPU and DMA->VPU dependency tokens.
        // Expected output: VPU consumes tokens and acknowledges the instruction with unit_done.
        reset_dut();
        instr_mem[0] = make_instr(OP_SIMD_ACT, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1);
        join
        wait_vpu_done("SIMD_ACT produced VPU unit_done");

        // Testcase 19: RELU instruction through top level
        // What it does: Runs RELU on one Output Bank word using the VPU path.
        // Input: CONFIG tile 4x4, output word has negative and positive INT8 values, VPU dependency tokens supplied.
        // Expected output: VPU writes one Output Bank word and pulses unit_done.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h8080_8080_8080_8080_8080_8080_8080_8080;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_RELU, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        wait_vpu_done("RELU produced VPU unit_done");
        chk(dut.vpu_vpu_out_wen_w == 1'b0, "RELU write strobe returned low after completion");
        chk(dut.SRAM_hub.out_bank.mem[0] == 128'h0, "RELU math clamps negative INT8 lanes to zero");

        // Testcase 20: ELEW_ADD instruction through top level
        // What it does: Runs ELEW_ADD on one Output Bank word and one Residual Bank word.
        // Input: CONFIG tile 4x4, output word=1 in every byte, residual word=2 in every byte.
        // Expected output: VPU completes and writes one result word back to Output Bank.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        dut.SRAM_hub.res_bank.mem[0] = 128'h0202_0202_0202_0202_0202_0202_0202_0202;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_ELEW_ADD, UNIT_VPU, 4'h0, {111'h0, 1'b0});
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        wait_vpu_done("ELEW_ADD produced VPU unit_done");
        chk(dut.vpu_vpu_out_wen_w == 1'b0, "ELEW_ADD write strobe returned low after completion");
        chk(dut.SRAM_hub.out_bank.mem[0] == 128'h0303_0303_0303_0303_0303_0303_0303_0303,
            "ELEW_ADD math adds 1 plus 2 in every lane");

        // Testcase 21: ELEW_MUL instruction through top level
        // What it does: Runs ELEW_MUL on one Output Bank word and one Residual Bank word.
        // Input: CONFIG tile 4x4, output word=64 in every byte, residual word=2 in every byte.
        // Expected output: VPU completes and writes one result word back to Output Bank.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h4040_4040_4040_4040_4040_4040_4040_4040;
        dut.SRAM_hub.res_bank.mem[0] = 128'h0202_0202_0202_0202_0202_0202_0202_0202;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_ELEW_MUL, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        wait_vpu_done("ELEW_MUL produced VPU unit_done");
        chk(dut.vpu_vpu_out_wen_w == 1'b0, "ELEW_MUL write strobe returned low after completion");
        chk(dut.SRAM_hub.out_bank.mem[0] == 128'h0101_0101_0101_0101_0101_0101_0101_0101,
            "ELEW_MUL math computes 64 times 2 shifted right by 7 in every lane");

        // Testcase 22: MAXPOOL instruction through top level
        // What it does: Runs the current single-window MAXPOOL VPU path.
        // Input: CONFIG tile 4x4, Output Bank and Residual Bank contain one candidate window word each.
        // Expected output: VPU completes one max pass and pulses unit_done.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        dut.SRAM_hub.res_bank.mem[0] = 128'h0202_0202_0202_0202_0202_0202_0202_0202;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_MAXPOOL, UNIT_VPU, 4'h0, {109'h0, 3'd3});
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        wait_vpu_done("MAXPOOL produced VPU unit_done");
        chk(dut.vpu_vpu_out_wen_w == 1'b0, "MAXPOOL write strobe returned low after completion");
        chk(dut.SRAM_hub.out_bank.mem[0] == 128'h0202_0202_0202_0202_0202_0202_0202_0202,
            "MAXPOOL math selects the larger lane value for the current single-window pass");

        // Testcase 23: HREDUCE instruction through top level
        // What it does: Runs HREDUCE through the VPU reduction path.
        // Input: CONFIG tile 4x4, Output Bank word contains small lane values.
        // Expected output: VPU completes reduction path and pulses unit_done.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h0101_0101_0101_0101_0101_0101_0101_0101;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_HREDUCE, UNIT_VPU, 4'h0, 112'h0);
        fork
            start_program(32'h0000_0000, 32'd2);
            serve_seq_fetch(2);
        join
        wait_vpu_done("HREDUCE produced VPU unit_done");
        chk(dut.vpu_vpu_out_wen_w == 1'b0, "HREDUCE write strobe returned low after completion");

        // Testcase 24: VPU-computed vector leaves the NPU through DMA_STORE st_wdata
        // What it does: Runs RELU to compute a vector in the Output Bank, then runs DMA_STORE to write that vector out.
        // Input: Output Bank starts with all lanes = -128, RELU should produce all zeros, then STORE writes to DDR address 0xE000.
        // Expected output: The external store bus st_wdata sends the computed zero vector and irq_done pulses once.
        reset_dut();
        dut.SRAM_hub.out_bank.mem[0] = 128'h8080_8080_8080_8080_8080_8080_8080_8080;
        instr_mem[0] = make_instr(OP_CONFIG, UNIT_SEQ, 4'h0,
                                  make_config_payload(8'd4, 8'd4, 8'd1, 4'd1, 2'd0, 3'd0, 3'd0, 32'h0));
        instr_mem[1] = make_instr(OP_RELU, UNIT_VPU, 4'h0, 112'h0);
        instr_mem[2] = make_instr(OP_DMA_STORE, UNIT_DMA, 4'h0,
                                  make_dma_payload(32'hE000, 16'h10, 8'd1, 8'd1, 8'd16,
                                                   4'd0, 4'd0, 4'd0, 4'd0));
        fork
            begin
                start_program(32'h0000_0000, 32'd3);
                serve_seq_fetch(3);
            end
            serve_store(1, 0, 0);
        join
        repeat (10) @(negedge clk);
        chk(st_aw_seen[0] == 44'hE000 && st_awlen_seen[0] == 8'd0, "end-to-end STORE writes to expected DDR address");
        chk(store_count == 1 && store_words[0] == 128'h0, "end-to-end st_wdata contains VPU-computed RELU vector");
        chk(store_last[0] == 1'b1, "end-to-end STORE marks the only beat as last");
        chk(irq_count == 1, "end-to-end STORE pulses irq_done once");

        // Testcase 25: Sequencer fetch error is sticky and prevents bad instruction dispatch
        // What it does: Injects a non-OKAY response during instruction fetch.
        // Input: One fetched DMA instruction, but seq_rresp is SLVERR.
        // Expected output: fetch_err stays high, no unit dispatch happens, and no DMA external access starts.
        reset_dut();
        instr_mem[0] = make_instr(OP_COEFF_LOAD, UNIT_DMA, 4'h0, {70'h0, 10'd2, 32'h9000});
        fork
            start_program(32'h0000_0000, 32'd1);
            serve_seq_fetch(1, 2'b10);
        join
        repeat (15) @(negedge clk);
        chk(fetch_err == 1'b1, "fetch_err set after Sequencer SLVERR");
        chk(disp_count[0] == 0 && disp_count[5] == 0, "bad fetch did not dispatch DMA instruction");
        chk(dma_read_count == 0 && !dma_arvalid, "bad fetch did not start DMA HP0");

        // Testcase 26: DMA read error propagates to top-level dma_err and remains sticky
        // What it does: Runs COEFF_LOAD normally through instruction fetch but returns DECERR on the DMA HP0 data.
        // Input: COEFF_LOAD base=0xA000, ch_count=2, dma_rresp=DECERR.
        // Expected output: dma_err becomes 1 and remains 1 after the DMA channel returns idle.
        reset_dut();
        instr_mem[0] = make_instr(OP_COEFF_LOAD, UNIT_DMA, 4'h0, {70'h0, 10'd2, 32'hA000});
        fork
            begin
                start_program(32'h0000_0000, 32'd1);
                serve_seq_fetch(1);
            end
            serve_dma_read(1, 0, 0, 2'b11);
        join
        repeat (10) @(negedge clk);
        chk(dma_err == 1'b1, "top-level dma_err set by HP0 DECERR");
        repeat (10) @(negedge clk);
        chk(dma_err == 1'b1, "top-level dma_err remains sticky");

        $display("NPU_tb errors: %0d", err_cnt);
        if (err_cnt == 0) $display("PASS"); else $fatal(1, "FAIL");
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "TIMEOUT");
    end

endmodule
