// =============================================================================
// File        : DMA.sv
// Project     : EE470 Neural Engine — KR260
// Description : 2D strided DMA engine.
//
//   Fetches a spatial tile from DDR using a descriptor and writes 128-bit words
//   sequentially to a generic SRAM write port.  Address generation (no mult):
//     addr = base + h * row_stride + w * ch_count
//   Accumulated via two running sums (row_base, col_off) updated once per row
//   and once per pixel respectively.  Zero rows/columns are inserted in hardware
//   at padded edges without any DDR access.
//
//   NPU_TopLevel owns all instruction FIFOs, dependency tracking (WAR/RAW), and
//   bank selection.  This module exposes only a start/done handshake and the
//   flat descriptor inputs.  Start is a 1-cycle pulse; descriptor fields must be
//   held stable until done pulses.
//
//   fetch_mode encoding:
//     2'b00  DMA_LOAD   2D strided read, im2col layout, zero-padding
//     2'b01  UPSAMPLE   2× nearest-neighbor (each pixel emitted 2×2 times) [STUB]
//     2'b10  CONCAT     2-source gather from base + concat_base [STUB]
//     2'b11  DMA_STORE  Burst-write SRAM → DDR via HP1 [STUB — single burst]
//
//   HP0 AXI4 read master  : all DDR → SRAM transfers (modes 00/01/10)
//   HP1 AXI4 write master : SRAM → DDR only (mode 11, DMA_STORE)
//
//   SRAM write port : generic 128-bit; NPU_TopLevel muxes to active bank.
//   SRAM read port  : generic 128-bit; source for DMA_STORE (Output Bank).
//
//   Phase constraint: ch_count must be a multiple of 16.
//
// AXI4 constant parameters (applied combinationally):
//   arsize = 3'b100 (16 B/beat), arburst = INCR, arcache = 4'b0011
//   awsize = 3'b100,              awburst = INCR, awcache = 4'b0011
// =============================================================================

import NPU_ISA_pkg::*;
import NPU_HW_params_pkg::*;

module DMA (
    input  logic clk,
    input  logic rst,

    // -------------------------------------------------------------------------
    // Descriptor — held stable by NPU_TopLevel; latched on start pulse.
    // -------------------------------------------------------------------------
    input  logic [31:0] src_base,    // DDR source (modes 00–10) or DDR dst (11)
    input  logic [15:0] row_stride,  // bytes between row starts in DDR
    input  logic [7:0]  tile_w,      // tile width in pixels
    input  logic [7:0]  tile_h,      // tile height in pixels
    input  logic [7:0]  ch_count,    // channels (bytes/pixel); must be multiple of 16
    input  logic [3:0]  pad_top,
    input  logic [3:0]  pad_bot,
    input  logic [3:0]  pad_left,
    input  logic [3:0]  pad_right,
    input  logic [1:0]  fetch_mode,  // 00=load 01=upsample 10=concat 11=store
    input  logic [31:0] concat_base, // CONCAT: second source base address

    // -------------------------------------------------------------------------
    // Handshake
    // -------------------------------------------------------------------------
    input  logic        start,  // 1-cycle pulse; ignored while busy
    output logic        busy,   // combinational; high while any FSM is active
    output logic        done,   // 1-cycle pulse on completion

    // -------------------------------------------------------------------------
    // HP0 AXI4 read master — modes 00/01/10  (128-bit, 44-bit addr)
    // -------------------------------------------------------------------------
    output logic [43:0] hp0_araddr,
    output logic        hp0_arvalid,
    output logic [7:0]  hp0_arlen,
    output logic [2:0]  hp0_arsize,
    output logic [1:0]  hp0_arburst,
    output logic [3:0]  hp0_arcache,
    input  logic        hp0_arready,

    input  logic [127:0] hp0_rdata,
    input  logic         hp0_rvalid,
    input  logic         hp0_rlast,
    input  logic [1:0]   hp0_rresp,
    output logic         hp0_rready,

    // -------------------------------------------------------------------------
    // HP1 AXI4 write master — mode 11 only  (128-bit, 44-bit addr)
    // -------------------------------------------------------------------------
    output logic [43:0]  hp1_awaddr,
    output logic         hp1_awvalid,
    output logic [7:0]   hp1_awlen,
    output logic [2:0]   hp1_awsize,
    output logic [1:0]   hp1_awburst,
    output logic [3:0]   hp1_awcache,
    input  logic         hp1_awready,

    output logic [127:0] hp1_wdata,
    output logic [15:0]  hp1_wstrb,
    output logic         hp1_wlast,
    output logic         hp1_wvalid,
    input  logic         hp1_wready,

    input  logic [1:0]   hp1_bresp,
    input  logic         hp1_bvalid,
    output logic         hp1_bready,

    // -------------------------------------------------------------------------
    // SRAM write port — DDR → SRAM for modes 00/01/10.
    // Address is a sequential word counter from 0; NPU_TopLevel connects to
    // the appropriate bank (Act Bank, Residual Bank, Coeff BRAM, etc.).
    // Width: $clog2(RES_BANK_DEPTH) = 10 bits covers the deepest bank.
    // -------------------------------------------------------------------------
    output logic [$clog2(RES_BANK_DEPTH)-1:0] sram_waddr,
    output logic [127:0]                        sram_wdata,
    output logic                                sram_wen,

    // -------------------------------------------------------------------------
    // SRAM read port — SRAM → DDR for mode 11 (DMA_STORE, Output Bank source).
    // -------------------------------------------------------------------------
    output logic [$clog2(RES_BANK_DEPTH)-1:0] sram_raddr,
    input  logic [127:0]                        sram_rdata,

    // Sticky; set on any non-OKAY AXI R or B response.
    output logic dma_err
);

    // =========================================================================
    // Descriptor shadow registers — latched on start
    // =========================================================================
    logic [31:0] r_base, r_concat_base;
    logic [15:0] r_stride;
    logic [7:0]  r_tile_w, r_tile_h, r_ch_count;
    logic [3:0]  r_pad_top, r_pad_bot, r_pad_left, r_pad_right;
    logic [7:0]  r_beats;       // ch_count >> 4: 128-bit words per pixel column
    logic [1:0]  r_fetch_mode;

    // =========================================================================
    // 2D iterative address generator (no multiplier)
    //   row_base : accumulated h * row_stride (one add per row)
    //   col_off  : accumulated w * ch_count   (one add per pixel; reset per row)
    // =========================================================================
    logic [43:0] row_base, col_off, r_pix_addr;
    logic [7:0]  cur_h, cur_w, beat_cnt;
    logic [$clog2(RES_BANK_DEPTH)-1:0] waddr_r;

    // Zero-padding detection: combinational on registered counters.
    logic is_pad;
    assign is_pad = (cur_h <  r_pad_top)             |
                    (cur_h >= r_tile_h - r_pad_bot)   |
                    (cur_w <  r_pad_left)              |
                    (cur_w >= r_tile_w - r_pad_right);

    // =========================================================================
    // Load FSM — modes 00 / 01 / 10
    // =========================================================================
    typedef enum logic [2:0] {
        S_IDLE,
        S_PIXEL,  // compute pixel address; evaluate padding
        S_AR,     // issue HP0 AR; hold arvalid until arready
        S_R,      // receive HP0 R beats; write to SRAM
        S_PAD,    // insert zeros without DDR access
        S_ADV     // advance tile counters; pulse load_done_r at end
    } state_e;
    state_e state;

    logic load_done_r; // 1-cycle pulse from load FSM
    logic err_load_r;  // sticky from load FSM

    // =========================================================================
    // DMA_STORE FSM — mode 11
    // STUB: issues a single AW+W burst, then done.
    // TODO: loop over tile_h rows (advance store_aw_addr by row_stride each row).
    // =========================================================================
    typedef enum logic [1:0] {
        SS_IDLE, SS_AW, SS_W, SS_B
    } store_state_e;
    store_state_e store_state;

    logic [43:0]                          store_aw_addr;
    logic [$clog2(RES_BANK_DEPTH)-1:0]   store_raddr_r;
    logic [7:0]                           store_beat_cnt;
    logic                                 store_done_r; // 1-cycle pulse from store FSM
    logic                                 err_store_r;  // sticky from store FSM

    // =========================================================================
    // Combinational outputs
    // =========================================================================
    assign busy       = (state != S_IDLE) | (store_state != SS_IDLE);
    assign done       = load_done_r | store_done_r;
    assign dma_err    = err_load_r  | err_store_r;

    assign hp0_rready  = (state == S_R);
    assign hp1_bready  = (store_state == SS_B);

    assign hp0_arsize  = 3'b100; assign hp0_arburst = 2'b01;
    assign hp0_arcache = 4'b0011;
    assign hp1_awsize  = 3'b100; assign hp1_awburst = 2'b01;
    assign hp1_awcache = 4'b0011;
    assign hp1_wstrb   = 16'hFFFF; // all byte lanes valid

    // =========================================================================
    // Load FSM — registered logic
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= S_IDLE;
            load_done_r   <= 1'b0;
            err_load_r    <= 1'b0;
            hp0_arvalid   <= 1'b0;
            hp0_araddr    <= 44'h0;
            hp0_arlen     <= 8'h0;
            sram_wen      <= 1'b0;
            sram_wdata    <= 128'h0;
            sram_waddr    <= '0;
            r_base        <= 32'h0;   r_concat_base <= 32'h0;
            r_stride      <= 16'h0;
            r_tile_w      <= 8'h0;    r_tile_h      <= 8'h0;
            r_ch_count    <= 8'h0;    r_beats       <= 8'h0;
            r_pad_top     <= 4'h0;    r_pad_bot     <= 4'h0;
            r_pad_left    <= 4'h0;    r_pad_right   <= 4'h0;
            r_fetch_mode  <= 2'b00;
            row_base      <= 44'h0;   col_off       <= 44'h0;
            r_pix_addr    <= 44'h0;
            cur_h         <= 8'h0;    cur_w         <= 8'h0;
            beat_cnt      <= 8'h0;    waddr_r       <= '0;
        end else begin
            load_done_r <= 1'b0;
            sram_wen    <= 1'b0;

            unique case (state)

                S_IDLE: begin
                    if (start && fetch_mode != 2'b11) begin
                        r_base        <= src_base;
                        r_stride      <= row_stride;
                        r_tile_w      <= tile_w;
                        r_tile_h      <= tile_h;
                        r_ch_count    <= ch_count;
                        r_beats       <= {4'h0, ch_count[7:4]};
                        r_pad_top     <= pad_top;
                        r_pad_bot     <= pad_bot;
                        r_pad_left    <= pad_left;
                        r_pad_right   <= pad_right;
                        r_fetch_mode  <= fetch_mode;
                        r_concat_base <= concat_base;
                        cur_h         <= 8'h0;
                        cur_w         <= 8'h0;
                        row_base      <= 44'h0;
                        col_off       <= 44'h0;
                        waddr_r       <= '0;
                        state         <= S_PIXEL;
                    end
                end

                S_PIXEL: begin
                    r_pix_addr <= {12'h0, r_base} + row_base + col_off;
                    beat_cnt   <= r_beats - 8'h1;
                    // TODO fetch_mode 2'b01 (UPSAMPLE): add repeat counters so each
                    //   source pixel is emitted 2× in W and 2× in H before advancing.
                    // TODO fetch_mode 2'b10 (CONCAT): toggle source base between
                    //   r_base and r_concat_base when the column crosses the first
                    //   tensor's channel boundary.
                    state <= is_pad ? S_PAD : S_AR;
                end

                // Issue HP0 AR; hold arvalid until arready (AXI4 §A3.2.2).
                S_AR: begin
                    if (!hp0_arvalid) begin
                        hp0_araddr  <= r_pix_addr;
                        hp0_arlen   <= r_beats - 8'h1;
                        hp0_arvalid <= 1'b1;
                    end else if (hp0_arready) begin
                        hp0_arvalid <= 1'b0;
                        state       <= S_R;
                    end
                end

                // Receive R beats; write each 128-bit word to SRAM.
                S_R: begin
                    if (hp0_rvalid) begin
                        if (|hp0_rresp) err_load_r <= 1'b1;
                        sram_wen   <= 1'b1;
                        sram_wdata <= hp0_rdata;
                        sram_waddr <= waddr_r;
                        waddr_r    <= waddr_r + 1'b1;
                        if (hp0_rlast) state <= S_ADV;
                    end
                end

                // Padding pixel: write r_beats zeros without DDR access.
                S_PAD: begin
                    sram_wen   <= 1'b1;
                    sram_wdata <= 128'h0;
                    sram_waddr <= waddr_r;
                    waddr_r    <= waddr_r + 1'b1;
                    if (beat_cnt == 8'h0) begin
                        state <= S_ADV;
                    end else begin
                        beat_cnt <= beat_cnt - 8'h1;
                    end
                end

                // Advance 2D tile counters; pulse load_done_r when tile complete.
                S_ADV: begin
                    if (cur_w == r_tile_w - 8'h1) begin
                        cur_w    <= 8'h0;
                        col_off  <= 44'h0;
                        row_base <= row_base + {28'h0, r_stride};
                        if (cur_h == r_tile_h - 8'h1) begin
                            load_done_r <= 1'b1;
                            state       <= S_IDLE;
                        end else begin
                            cur_h <= cur_h + 8'h1;
                            state <= S_PIXEL;
                        end
                    end else begin
                        cur_w   <= cur_w + 8'h1;
                        col_off <= col_off + {36'h0, r_ch_count};
                        state   <= S_PIXEL;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // DMA_STORE FSM — registered logic
    // Issues a single linear AW+W burst then pulses store_done_r.
    // TODO: wrap in a tile_h row loop; advance store_aw_addr by row_stride each row.
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            store_state    <= SS_IDLE;
            store_done_r   <= 1'b0;
            err_store_r    <= 1'b0;
            hp1_awaddr     <= 44'h0;
            hp1_awvalid    <= 1'b0;
            hp1_awlen      <= 8'h0;
            hp1_wdata      <= 128'h0;
            hp1_wlast      <= 1'b0;
            hp1_wvalid     <= 1'b0;
            sram_raddr     <= '0;
            store_raddr_r  <= '0;
            store_aw_addr  <= 44'h0;
            store_beat_cnt <= 8'h0;
        end else begin
            store_done_r <= 1'b0;

            unique case (store_state)

                SS_IDLE: begin
                    if (start && fetch_mode == 2'b11) begin
                        store_aw_addr  <= {12'h0, src_base};
                        // TODO: store_beat_cnt = tile_w × (ch_count/16) × tile_h - 1.
                        //   Requires multiplier; placeholder until row-loop added.
                        store_beat_cnt <= 8'h0;
                        store_raddr_r  <= '0;
                        sram_raddr     <= '0;
                        store_state    <= SS_AW;
                    end
                end

                // Issue HP1 AW; hold awvalid until awready (AXI4 §A3.2.2).
                SS_AW: begin
                    if (!hp1_awvalid) begin
                        hp1_awaddr  <= store_aw_addr;
                        hp1_awlen   <= store_beat_cnt;
                        hp1_awvalid <= 1'b1;
                    end else if (hp1_awready) begin
                        hp1_awvalid <= 1'b0;
                        store_state <= SS_W;
                    end
                end

                // Stream SRAM words out on HP1 W channel.
                // TODO: pipeline sram_raddr one cycle ahead of hp1_wvalid to hide
                //   SRAM read latency (SimpleBRAM has 1-cycle registered output).
                SS_W: begin
                    if (!hp1_wvalid) begin
                        hp1_wvalid <= 1'b1;
                        hp1_wdata  <= sram_rdata;
                        hp1_wlast  <= (store_beat_cnt == 8'h0);
                    end else if (hp1_wready) begin
                        if (hp1_wlast) begin
                            hp1_wvalid  <= 1'b0;
                            hp1_wlast   <= 1'b0;
                            store_state <= SS_B;
                        end else begin
                            store_raddr_r  <= store_raddr_r + 1'b1;
                            sram_raddr     <= store_raddr_r + 1'b1;
                            store_beat_cnt <= store_beat_cnt - 8'h1;
                            hp1_wdata      <= sram_rdata;
                            hp1_wlast      <= (store_beat_cnt == 8'h1);
                        end
                    end
                end

                // Wait for write response; set sticky error on SLVERR/DECERR.
                SS_B: begin
                    if (hp1_bvalid) begin
                        if (|hp1_bresp) err_store_r <= 1'b1;
                        store_done_r <= 1'b1;
                        store_state  <= SS_IDLE;
                    end
                end

                default: store_state <= SS_IDLE;
            endcase
        end
    end

endmodule
