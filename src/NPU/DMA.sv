// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// DMA engine for EE470 NPU: Ch0 HP0 read fetches 2D-strided Act tiles with zero-padding, Ch1 HP1 read fetches 16x16 INT8 Weight subblocks, HP2 write flushes Output Bank to DDR.
// Inputs:
//     - clk: System clock
//     - rst: Active-high sync reset
//     - src_base: Ch0 DDR source addr (modes 00-10) or DDR dest (mode 11)
//     - row_stride: Bytes between row starts in DDR
//     - tile_w: Tile width in pixels
//     - tile_h: Tile height in pixels
//     - ch_count: Channels per pixel; multiple of 16
//     - pad_top: Top zero-pad rows
//     - pad_bot: Bottom zero-pad rows
//     - pad_left: Left zero-pad columns
//     - pad_right: Right zero-pad columns
//     - fetch_mode: 00=LOAD 01=UPSAMPLE 10=CONCAT 11=STORE
//     - concat_base: CONCAT second-source DDR base
//     - ch1_start: 1-cycle pulse to launch Ch1 WT_LOAD with wt_src_base
//     - wt_src_base: Ch1 DDR source addr for one 16x16 weight subblock
//     - start: Ch0 1-cycle pulse to launch the latched descriptor
//     - hp0_arready: HP0 AR handshake ready
//     - hp0_rdata: HP0 R 128-bit beat data
//     - hp0_rvalid: HP0 R beat valid
//     - hp0_rlast: HP0 R last-beat flag
//     - hp0_rresp: HP0 R response code
//     - hp2_awready: HP2 AW handshake ready
//     - hp2_wready: HP2 W handshake ready
//     - hp2_bresp: HP2 B response code
//     - hp2_bvalid: HP2 B response valid
//     - hp1_arready: HP1 AR handshake ready
//     - hp1_rdata: HP1 R 128-bit beat data
//     - hp1_rvalid: HP1 R beat valid
//     - hp1_rlast: HP1 R last-beat flag
//     - hp1_rresp: HP1 R response code
//     - sram_rdata: Output Bank read data for DMA_STORE
//     - dep_sa_to_dma_empty: DepFIFO empty flag SA->DMA
//     - dep_vpu_to_dma_empty: DepFIFO empty flag VPU->DMA
//     - dep_dma_to_sa_full: DepFIFO full flag DMA->SA
//     - dep_dma_to_vpu_full: DepFIFO full flag DMA->VPU
// Outputs:
//     - ch0_idle: Ch0 (LOAD+STORE) FSMs idle, for FENCE
//     - ch1_idle: Ch1 (WT_LOAD) FSM idle, for FENCE
//     - dma_act_bank_full: 1-cycle pulse on Act tile LOAD complete
//     - dma_wt_bank_full: 1-cycle pulse on Wt tile LOAD complete
//     - hp0_araddr: HP0 AR 44-bit DDR address
//     - hp0_arvalid: HP0 AR valid
//     - hp0_arlen: HP0 AR burst length minus 1
//     - hp0_arsize: HP0 AR beat size (3'b100 = 16 B)
//     - hp0_arburst: HP0 AR burst type (INCR)
//     - hp0_arcache: HP0 AR cache attrs (4'b0011)
//     - hp0_rready: HP0 R ready
//     - hp2_awaddr: HP2 AW 44-bit DDR address
//     - hp2_awvalid: HP2 AW valid
//     - hp2_awlen: HP2 AW burst length minus 1
//     - hp2_awsize: HP2 AW beat size (3'b100 = 16 B)
//     - hp2_awburst: HP2 AW burst type (INCR)
//     - hp2_awcache: HP2 AW cache attrs (4'b0011)
//     - hp2_wdata: HP2 W 128-bit beat data
//     - hp2_wstrb: HP2 W byte strobes (all 1s)
//     - hp2_wlast: HP2 W last-beat flag
//     - hp2_wvalid: HP2 W valid
//     - hp2_bready: HP2 B response ready
//     - hp1_araddr: HP1 AR 44-bit DDR address
//     - hp1_arvalid: HP1 AR valid
//     - hp1_arlen: HP1 AR burst length minus 1
//     - hp1_arsize: HP1 AR beat size (3'b100 = 16 B)
//     - hp1_arburst: HP1 AR burst type (INCR)
//     - hp1_arcache: HP1 AR cache attrs (4'b0011)
//     - hp1_rready: HP1 R ready
//     - sram_waddr: Ch0 SRAM sequential word write addr (bank-addr width)
//     - sram_wdata: Ch0 SRAM 128-bit write data
//     - sram_wen: Ch0 SRAM write enable
//     - sram_raddr: SRAM read addr for DMA_STORE
//     - sram_wt_waddr: Ch1 Weight Bank write addr ($clog2(WT_BUF_DEPTH) bits)
//     - sram_wt_wdata: Ch1 Weight Bank 128-bit write data
//     - sram_wt_wen: Ch1 Weight Bank write enable
//     - dma_err: Sticky AXI error flag (any non-OKAY R or B response, all channels)
//     - dep_sa_to_dma_pop: DepFIFO pop SA->DMA (tied 0; owned by Dispatch_DMA)
//     - dep_vpu_to_dma_pop: DepFIFO pop VPU->DMA (tied 0; owned by Dispatch_DMA)
//     - dep_dma_to_sa_push: DepFIFO push DMA->SA, = dma_act_bank_full
//     - dep_dma_to_vpu_push: DepFIFO push DMA->VPU

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
    // Ch1 (WT_LOAD) descriptor — fixed 16x16 INT8 subblock (256 B = 16 beats).
    // Tile dims derive from SA_ROWS/SA_COLS; only base address is per-instruction.
    // -------------------------------------------------------------------------
    input  logic        ch1_start,
    input  logic [31:0] wt_src_base,

    // -------------------------------------------------------------------------
    // Handshake / status
    // -------------------------------------------------------------------------
    input  logic        start,             // Ch0 1-cycle pulse; ignored while busy
    output logic        ch0_idle,          // Ch0 (LOAD+STORE) both FSMs idle
    output logic        ch1_idle,          // Ch1 (WT_LOAD) FSM idle
    output logic        dma_act_bank_full, // 1-cycle pulse: Act tile LOAD complete
    output logic        dma_wt_bank_full,  // 1-cycle pulse: Wt tile LOAD complete

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
    // HP2 AXI4 write master — mode 11 only (DMA_STORE)  (128-bit, 44-bit addr)
    // -------------------------------------------------------------------------
    output logic [43:0]  hp2_awaddr,
    output logic         hp2_awvalid,
    output logic [7:0]   hp2_awlen,
    output logic [2:0]   hp2_awsize,
    output logic [1:0]   hp2_awburst,
    output logic [3:0]   hp2_awcache,
    input  logic         hp2_awready,

    output logic [127:0] hp2_wdata,
    output logic [15:0]  hp2_wstrb,
    output logic         hp2_wlast,
    output logic         hp2_wvalid,
    input  logic         hp2_wready,

    input  logic [1:0]   hp2_bresp,
    input  logic         hp2_bvalid,
    output logic         hp2_bready,

    // -------------------------------------------------------------------------
    // HP1 AXI4 read master — WT_LOAD only (128-bit, 44-bit addr).
    // Tied off in Phase 1; driven by Ch1 FSM in Phase 4.
    // -------------------------------------------------------------------------
    output logic [43:0]  hp1_araddr,
    output logic         hp1_arvalid,
    output logic [7:0]   hp1_arlen,
    output logic [2:0]   hp1_arsize,
    output logic [1:0]   hp1_arburst,
    output logic [3:0]   hp1_arcache,
    input  logic         hp1_arready,
    input  logic [127:0] hp1_rdata,
    input  logic         hp1_rvalid,
    input  logic         hp1_rlast,
    input  logic [1:0]   hp1_rresp,
    output logic         hp1_rready,

    // -------------------------------------------------------------------------
    // SRAM write port — DDR → SRAM for Ch0 modes 00/01/10.
    // Address is a sequential word counter from 0; NPU_TopLevel connects to
    // the appropriate bank (Act Bank, Residual Bank, Coeff BRAM, etc.).
    // Width: $clog2(RES_BANK_DEPTH) = 10 bits covers the deepest bank.
    // -------------------------------------------------------------------------
    output logic [$clog2(RES_BANK_DEPTH)-1:0] sram_waddr,
    output logic [127:0]                        sram_wdata,
    output logic                                sram_wen,

    // -------------------------------------------------------------------------
    // Wt SRAM write port — DDR → Weight Bank for Ch1 WT_LOAD.
    // -------------------------------------------------------------------------
    output logic [$clog2(WT_BUF_DEPTH)-1:0] sram_wt_waddr,
    output logic [127:0]                    sram_wt_wdata,
    output logic                            sram_wt_wen,

    // -------------------------------------------------------------------------
    // SRAM read port — SRAM → DDR for mode 11 (DMA_STORE, Output Bank source).
    // -------------------------------------------------------------------------
    output logic [$clog2(RES_BANK_DEPTH)-1:0] sram_raddr,
    input  logic [127:0]                        sram_rdata,

    // Sticky; set on any non-OKAY AXI R or B response.
    output logic dma_err,

    // -------------------------------------------------------------------------
    // Dependency-FIFO ports (DMA-side). NPU_TopLevel hosts the DepFIFO banks;
    // this module exposes the producer-push / consumer-pop pins so future DMA
    // bring-up can hand off RAW/WAR tokens to SA and VPU. Datapath deferred —
    // push/pop tied to 0 inside; full/empty observed but unused.
    // -------------------------------------------------------------------------
    input  logic dep_sa_to_dma_empty,
    output logic dep_sa_to_dma_pop,
    input  logic dep_vpu_to_dma_empty,
    output logic dep_vpu_to_dma_pop,
    input  logic dep_dma_to_sa_full,
    output logic dep_dma_to_sa_push,
    input  logic dep_dma_to_vpu_full,
    output logic dep_dma_to_vpu_push
);

    // Phase 1: only dep_dma_to_sa_push wired (= dma_act_bank_full).
    // Other dep handshakes tied off; rewired in Phases 3/5.
    assign dep_sa_to_dma_pop   = 1'b0;
    assign dep_vpu_to_dma_pop  = 1'b0;
    assign dep_dma_to_sa_push  = dma_act_bank_full;
    assign dep_dma_to_vpu_push = 1'b0;
    // Suppress unused-input lint by referencing the empty/full flags.
    logic _unused_dep_in;
    assign _unused_dep_in = dep_sa_to_dma_empty | dep_vpu_to_dma_empty
                          | dep_dma_to_sa_full  | dep_dma_to_vpu_full;

    // HP1 AXI constants (same as HP0/HP2).
    assign hp1_arsize  = 3'b100;
    assign hp1_arburst = 2'b01;
    assign hp1_arcache = 4'b0011;

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
    // Total 128-bit words for current Act LOAD = tile_h * tile_w * (ch_count/16).
    // Latched at start; used to pulse dma_act_bank_full on the last sram_wen.
    logic [$clog2(RES_BANK_DEPTH)-1:0] r_act_total;
    // 24-bit context forces full-width multiply (operand self-determination
    // would otherwise truncate to 8 bits). Truncated to bank-addr width on latch.
    logic [23:0] act_total_calc;
    assign act_total_calc = 24'(tile_h) * 24'(tile_w) * {16'h0, 4'h0, ch_count[7:4]};

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

    // =========================================================================
    // Ch1 WT_LOAD FSM — linear 16-beat burst (one 16x16 INT8 subblock).
    // Tile size is hardware-fixed: SA_ROWS * SA_COLS = 256 B = 16 beats.
    // =========================================================================
    localparam int WtBeatsPerTile = (SA_ROWS * SA_COLS) / 16;  // = 16
    typedef enum logic [1:0] {
        SS1_IDLE, SS1_AR, SS1_R, SS1_DONE
    } ch1_state_e;
    ch1_state_e ch1_state;

    logic [$clog2(WT_BUF_DEPTH)-1:0] wt_waddr_r;
    logic [43:0]                     wt_ar_addr;
    logic                            err_ch1_r; // sticky from Ch1 FSM

    logic [43:0]                          store_aw_addr;
    logic [$clog2(RES_BANK_DEPTH)-1:0]   store_raddr_r;
    logic [7:0]                           store_beat_cnt;
    logic                                 store_done_r; // 1-cycle pulse from store FSM
    logic                                 err_store_r;  // sticky from store FSM

    // =========================================================================
    // Combinational outputs
    // =========================================================================
    assign ch0_idle   = (state == S_IDLE) & (store_state == SS_IDLE);
    assign ch1_idle   = (ch1_state == SS1_IDLE);
    assign dma_err    = err_load_r  | err_store_r | err_ch1_r;

    assign hp0_rready  = (state == S_R);
    assign hp1_rready  = (ch1_state == SS1_R);
    assign hp2_bready  = (store_state == SS_B);

    assign hp0_arsize  = 3'b100; assign hp0_arburst = 2'b01;
    assign hp0_arcache = 4'b0011;
    assign hp2_awsize  = 3'b100; assign hp2_awburst = 2'b01;
    assign hp2_awcache = 4'b0011;
    assign hp2_wstrb   = 16'hFFFF; // all byte lanes valid


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
            r_act_total   <= '0;
            dma_act_bank_full <= 1'b0;
        end else begin
            load_done_r       <= 1'b0;
            sram_wen          <= 1'b0;
            dma_act_bank_full <= 1'b0;

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
                        // 1 DSP at 300 MHz; truncated to bank-addr width.
                        r_act_total   <= act_total_calc[$clog2(RES_BANK_DEPTH)-1:0];
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
                        if (waddr_r == r_act_total - 1'b1) dma_act_bank_full <= 1'b1;
                        if (hp0_rlast) state <= S_ADV;
                    end
                end

                // Padding pixel: write r_beats zeros without DDR access.
                S_PAD: begin
                    sram_wen   <= 1'b1;
                    sram_wdata <= 128'h0;
                    sram_waddr <= waddr_r;
                    waddr_r    <= waddr_r + 1'b1;
                    if (waddr_r == r_act_total - 1'b1) dma_act_bank_full <= 1'b1;
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
            hp2_awaddr     <= 44'h0;
            hp2_awvalid    <= 1'b0;
            hp2_awlen      <= 8'h0;
            hp2_wdata      <= 128'h0;
            hp2_wlast      <= 1'b0;
            hp2_wvalid     <= 1'b0;
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

                // Issue HP2 AW; hold awvalid until awready (AXI4 §A3.2.2).
                SS_AW: begin
                    if (!hp2_awvalid) begin
                        hp2_awaddr  <= store_aw_addr;
                        hp2_awlen   <= store_beat_cnt;
                        hp2_awvalid <= 1'b1;
                    end else if (hp2_awready) begin
                        hp2_awvalid <= 1'b0;
                        store_state <= SS_W;
                    end
                end

                // Stream SRAM words out on HP2 W channel.
                // TODO: pipeline sram_raddr one cycle ahead of hp2_wvalid to hide
                //   SRAM read latency (SimpleBRAM has 1-cycle registered output).
                SS_W: begin
                    if (!hp2_wvalid) begin
                        hp2_wvalid <= 1'b1;
                        hp2_wdata  <= sram_rdata;
                        hp2_wlast  <= (store_beat_cnt == 8'h0);
                    end else if (hp2_wready) begin
                        if (hp2_wlast) begin
                            hp2_wvalid  <= 1'b0;
                            hp2_wlast   <= 1'b0;
                            store_state <= SS_B;
                        end else begin
                            store_raddr_r  <= store_raddr_r + 1'b1;
                            sram_raddr     <= store_raddr_r + 1'b1;
                            store_beat_cnt <= store_beat_cnt - 8'h1;
                            hp2_wdata      <= sram_rdata;
                            hp2_wlast      <= (store_beat_cnt == 8'h1);
                        end
                    end
                end

                // Wait for write response; set sticky error on SLVERR/DECERR.
                SS_B: begin
                    if (hp2_bvalid) begin
                        if (|hp2_bresp) err_store_r <= 1'b1;
                        store_done_r <= 1'b1;
                        store_state  <= SS_IDLE;
                    end
                end

                default: store_state <= SS_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Ch1 WT_LOAD FSM — registered logic.
    // Single linear AXI burst of WtBeatsPerTile = 16 beats (256 B weight tile);
    // pulses dma_wt_bank_full on the last sram_wt_wen.
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            ch1_state        <= SS1_IDLE;
            hp1_araddr       <= 44'h0;
            hp1_arvalid      <= 1'b0;
            hp1_arlen        <= 8'h0;
            sram_wt_waddr    <= '0;
            sram_wt_wdata    <= 128'h0;
            sram_wt_wen      <= 1'b0;
            wt_waddr_r       <= '0;
            wt_ar_addr       <= 44'h0;
            err_ch1_r        <= 1'b0;
            dma_wt_bank_full <= 1'b0;
        end else begin
            sram_wt_wen      <= 1'b0;
            dma_wt_bank_full <= 1'b0;

            unique case (ch1_state)

                SS1_IDLE: begin
                    if (ch1_start) begin
                        wt_ar_addr  <= {12'h0, wt_src_base};
                        wt_waddr_r  <= '0;
                        ch1_state   <= SS1_AR;
                    end
                end

                // Issue HP1 AR; hold arvalid until arready (AXI4 §A3.2.2).
                SS1_AR: begin
                    if (!hp1_arvalid) begin
                        hp1_araddr  <= wt_ar_addr;
                        hp1_arlen   <= 8'(WtBeatsPerTile - 1);
                        hp1_arvalid <= 1'b1;
                    end else if (hp1_arready) begin
                        hp1_arvalid <= 1'b0;
                        ch1_state   <= SS1_R;
                    end
                end

                // Receive R beats; write each 128-bit word to Wt bank.
                SS1_R: begin
                    if (hp1_rvalid) begin
                        if (|hp1_rresp) err_ch1_r <= 1'b1;
                        sram_wt_wen   <= 1'b1;
                        sram_wt_wdata <= hp1_rdata;
                        sram_wt_waddr <= wt_waddr_r;
                        wt_waddr_r    <= wt_waddr_r + 1'b1;
                        if (hp1_rlast) begin
                            dma_wt_bank_full <= 1'b1;
                            ch1_state        <= SS1_DONE;
                        end
                    end
                end

                // 1-cycle settle so dma_wt_bank_full deasserts before returning.
                SS1_DONE: ch1_state <= SS1_IDLE;

                default: ch1_state <= SS1_IDLE;
            endcase
        end
    end

endmodule
