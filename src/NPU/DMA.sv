// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// DMA engine for EE470 NPU: Ch0 HP0 read fetches Act tiles, Coeff pairs, and LUT bytes from DDR; Ch1 HP1 read fetches 16x16 INT8 Weight subblocks; HP2 write flushes Output Bank to DDR.
// Inputs:
//     - clk: System clock
//     - rst: Active-high sync reset
//     - src_base: Ch0 DDR source addr (modes 000/001/010/100/101) or DDR dest (mode 011)
//     - row_stride: Bytes between row starts in DDR
//     - tile_w: Tile width in pixels
//     - tile_h: Tile height in pixels
//     - ch_count: Channels per pixel; multiple of 16
//     - pad_top: Top zero-pad rows
//     - pad_bot: Bottom zero-pad rows
//     - pad_left: Left zero-pad columns
//     - pad_right: Right zero-pad columns
//     - fetch_mode: 000=LOAD 001=UPSAMPLE 010=CONCAT 011=STORE 100=COEFF_LOAD 101=LUT_LOAD
//     - concat_base: CONCAT second-source DDR base
//     - coeff_ch_count: OP_COEFF_LOAD channel count (up to MAX_CHANNELS = 512)
//     - lut_sel: OP_LUT_LOAD ping-pong slot select
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
//     - dma_store_done: 1-cycle pulse on full DMA_STORE complete (drives NPU irq_done)
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
//     - sram_coeff_waddr: Requant Coeff BRAM write addr ($clog2(MAX_CHANNELS) bits)
//     - sram_coeff_wdata: Requant Coeff write data, {M[31:0], S[3:0]} = 36 bits
//     - sram_coeff_wen: Requant Coeff BRAM write enable
//     - sram_lut_waddr: Act LUT BRAM write addr (8 bits, LUT_DEPTH = 256)
//     - sram_lut_wdata: Act LUT 8-bit byte data
//     - sram_lut_wen: Act LUT BRAM write enable
//     - sram_lut_sel: Act LUT ping-pong slot select (held = r_lut_sel)
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
    input  logic [2:0]  fetch_mode,  // 000=LOAD 001=UP 010=CONCAT 011=STORE 100=COEFF 101=LUT
    input  logic [31:0] concat_base, // CONCAT: second source base address
    input  logic [9:0]  coeff_ch_count, // OP_COEFF_LOAD: channel count (up to MAX_CHANNELS)
    input  logic        lut_sel,        // OP_LUT_LOAD: ping-pong slot select

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
    output logic        dma_store_done,    // 1-cycle pulse: full DMA_STORE complete (IRQ)

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
    // HP1 AXI4 read master — WT_LOAD only (128-bit, 44-bit addr). Driven by
    // the Ch1 FSM below; AXI constants assigned combinationally further down.
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
    // Coeff BRAM write port — DDR → Requant Coeff BRAM for OP_COEFF_LOAD.
    // 2 entries packed per 128-bit beat; written as two sequential SRAM writes.
    // -------------------------------------------------------------------------
    output logic [$clog2(MAX_CHANNELS)-1:0]            sram_coeff_waddr,
    output logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]     sram_coeff_wdata,
    output logic                                        sram_coeff_wen,

    // -------------------------------------------------------------------------
    // LUT BRAM write port — DDR → Act LUT BRAM for OP_LUT_LOAD.
    // 16 bytes packed per 128-bit beat; drained one byte per cycle.
    // -------------------------------------------------------------------------
    output logic [$clog2(LUT_DEPTH)-1:0] sram_lut_waddr,
    output logic [7:0]                    sram_lut_wdata,
    output logic                          sram_lut_wen,
    output logic                          sram_lut_sel,

    // -------------------------------------------------------------------------
    // SRAM read port — SRAM → DDR for mode 11 (DMA_STORE, Output Bank source).
    // -------------------------------------------------------------------------
    output logic [$clog2(RES_BANK_DEPTH)-1:0] sram_raddr,
    input  logic [127:0]                        sram_rdata,

    // Sticky; set on any non-OKAY AXI R or B response.
    output logic dma_err,

    // -------------------------------------------------------------------------
    // Dependency-FIFO ports (DMA-side). NPU_TopLevel hosts the DepFIFO banks.
    // Push pins are driven from DMA done pulses (dma_act_bank_full -> SA,
    // dma_store_done -> VPU). Pop pins are owned by Dispatch_DMA and tied 0
    // here to avoid multi-driver; full/empty inputs are observed only via a
    // lint-suppressor (correctness assumed via Sequencer FENCE discipline).
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

    // Dep handshakes: producers wired from DMA's own done pulses; consumers
    // (pop pins) owned by Dispatch_DMA — tied 0 here to avoid multi-driver.
    assign dep_sa_to_dma_pop   = 1'b0;
    assign dep_vpu_to_dma_pop  = 1'b0;
    assign dep_dma_to_sa_push  = dma_act_bank_full;
    assign dep_dma_to_vpu_push = dma_store_done;
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
    logic [2:0]  r_fetch_mode;

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
    // UPSAMPLE emits each src pixel 2x in W and 2x in H -> 4x writes vs LOAD.
    logic [25:0] upsample_total_calc;
    assign upsample_total_calc = {act_total_calc, 2'b00};

    // CONCAT phase: 0 = first half (r_base), 1 = second half (r_concat_base).
    // UPSAMPLE repeat flags: track 2x replication in W and H.
    logic concat_phase;
    logic repeat_w;
    logic repeat_h;

    // Zero-padding detection: combinational on registered counters.
    logic is_pad;
    assign is_pad = (cur_h <  8'(r_pad_top))               |
                    (cur_h >= r_tile_h - 8'(r_pad_bot))     |
                    (cur_w <  8'(r_pad_left))                |
                    (cur_w >= r_tile_w - 8'(r_pad_right));

    // =========================================================================
    // Ch0 read-master FSM — modes 000 / 001 / 010 (Act tile fetch + pad)
    //                        modes 100 / 101         (COEFF / LUT loads)
    // All read modes share the HP0 master; mutual exclusion via S_IDLE re-entry.
    // =========================================================================
    typedef enum logic [3:0] {
        S_IDLE,
        S_PIXEL,   // compute pixel address; evaluate padding
        S_AR,      // issue HP0 AR; hold arvalid until arready
        S_R,       // receive HP0 R beats; write to Act/Res SRAM
        S_PAD,     // insert zeros without DDR access
        S_ADV,     // advance tile counters; pulse load_done_r at end
        S_C_AR,    // COEFF_LOAD: issue HP0 AR for ceil(ch_count/2) beats
        S_C_R,     // COEFF_LOAD: capture beat; write entry 0 (low half)
        S_C_WR1,   // COEFF_LOAD: write entry 1 (high half) from captured beat
        S_L_AR,    // LUT_LOAD: issue HP0 AR for 16 beats (256 B)
        S_L_R,     // LUT_LOAD: capture beat; init byte index
        S_L_WR     // LUT_LOAD: drain captured beat one byte per cycle
    } state_e;
    state_e state;

    logic load_done_r; // 1-cycle pulse from load FSM
    logic err_load_r;  // sticky from load FSM

    // -------------------------------------------------------------------------
    // COEFF_LOAD scratch state. Each 128-bit beat = 2 channel pairs.
    // BRAM is single-port write: two sequential SRAM writes per beat.
    // -------------------------------------------------------------------------
    logic [9:0]                                  r_coeff_ch_count;
    logic [$clog2(MAX_CHANNELS)-1:0]             coeff_waddr_r;
    logic [127:0]                                coeff_buf;
    logic                                        coeff_last_beat;
    // 9-bit context: max beats = ceil(512/2) = 256; arlen field truncated to 8b.
    logic [8:0]                                  coeff_beats_total;
    // Count of beats accepted; backstop so the FSM exits on burst-length even
    // if hp0_rlast is lost across the S_C_R/S_C_WR1 rready toggle.
    logic [8:0]                                  coeff_beats_received;

    // -------------------------------------------------------------------------
    // LUT_LOAD scratch state. 16 beats × 16 bytes = 256 B = LUT_DEPTH.
    // Each beat drained over 16 cycles into the byte-wide BRAM port.
    // -------------------------------------------------------------------------
    logic                                        r_lut_sel;
    logic [$clog2(LUT_DEPTH)-1:0]                lut_waddr_r;
    logic [127:0]                                lut_beat_buf;
    logic [3:0]                                  lut_byte_idx;
    logic                                        lut_last_beat;

    // Hold sel from latched descriptor; SRAMHub only consults sel when wen=1.
    assign sram_lut_sel = r_lut_sel;

    // =========================================================================
    // DMA_STORE FSM — mode 11. Row loop over r_tile_h, one AXI burst per row.
    // Per-row beats = r_tile_w * (ch_count>>4); BRAM 1-cycle read pipelined
    // via PRIME1/LOAD states so registered SRAM data is captured before W.
    // Pulses dma_store_done on the bvalid of the final row.
    // =========================================================================
    typedef enum logic [2:0] {
        SS_IDLE, SS_AW, SS_W_PRIME1, SS_W_LOAD, SS_W, SS_B
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

    logic [43:0]                       store_aw_addr;
    logic [$clog2(RES_BANK_DEPTH)-1:0] store_send_idx;    // next beat addr to transmit
    logic [7:0]                        store_beat_idx;    // beat index within current row
    logic [7:0]                        store_cur_h;       // current row index
    logic [7:0]                        store_per_row_r;   // beats per row (latched)
    logic [7:0]                        store_tile_h_r;    // total rows (latched)
    logic [15:0]                       store_stride_r;    // DDR row stride (latched)
    logic [127:0]                      wdata_reg;         // current beat data
    logic                              store_done_r;      // 1-cycle pulse
    logic                              err_store_r;       // sticky from store FSM

    // Per-row beat count: tile_w * (ch_count[7:4]); 16-bit context avoids
    // operand-self-determined truncation. Latched in SS_IDLE on start.
    logic [15:0] store_per_row_calc;
    assign store_per_row_calc = 16'(tile_w) * {12'h0, ch_count[7:4]};

    // =========================================================================
    // Combinational outputs
    // =========================================================================
    assign ch0_idle       = (state == S_IDLE) & (store_state == SS_IDLE);
    assign ch1_idle       = (ch1_state == SS1_IDLE);
    assign dma_err        = err_load_r  | err_store_r | err_ch1_r;
    assign dma_store_done = store_done_r;

    assign hp0_rready  = (state == S_R) | (state == S_C_R) | (state == S_L_R);
    assign hp1_rready  = (ch1_state == SS1_R);
    assign hp2_bready  = (store_state == SS_B);

    // HP2 W-channel: combinational drive from wdata_reg / state.
    assign hp2_wvalid = (store_state == SS_W);
    assign hp2_wdata  = wdata_reg;
    assign hp2_wlast  = (store_state == SS_W) &&
                        (store_beat_idx == store_per_row_r - 8'h1);

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
            r_fetch_mode  <= 3'b000;
            row_base      <= 44'h0;   col_off       <= 44'h0;
            r_pix_addr    <= 44'h0;
            cur_h         <= 8'h0;    cur_w         <= 8'h0;
            beat_cnt      <= 8'h0;    waddr_r       <= '0;
            r_act_total   <= '0;
            dma_act_bank_full <= 1'b0;
            concat_phase  <= 1'b0;
            repeat_w      <= 1'b0;
            repeat_h      <= 1'b0;
            // COEFF_LOAD scratch
            r_coeff_ch_count  <= 10'h0;
            coeff_waddr_r     <= '0;
            coeff_buf         <= 128'h0;
            coeff_last_beat   <= 1'b0;
            coeff_beats_total <= 9'h0;
            coeff_beats_received <= 9'h0;
            sram_coeff_waddr  <= '0;
            sram_coeff_wdata  <= '0;
            sram_coeff_wen    <= 1'b0;
            // LUT_LOAD scratch
            r_lut_sel         <= 1'b0;
            lut_waddr_r       <= '0;
            lut_beat_buf      <= 128'h0;
            lut_byte_idx      <= 4'h0;
            lut_last_beat     <= 1'b0;
            sram_lut_waddr    <= '0;
            sram_lut_wdata    <= 8'h0;
            sram_lut_wen      <= 1'b0;
        end else begin
            load_done_r       <= 1'b0;
            sram_wen          <= 1'b0;
            dma_act_bank_full <= 1'b0;
            sram_coeff_wen    <= 1'b0;
            sram_lut_wen      <= 1'b0;

            unique case (state)

                S_IDLE: begin
                    if (start) begin
                        // Latch shared descriptor (Store FSM reads these too).
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
                        unique case (fetch_mode)
                            3'b000, 3'b001, 3'b010: begin  // LOAD / UPSAMPLE / CONCAT
                                cur_h        <= 8'h0;
                                cur_w        <= 8'h0;
                                row_base     <= 44'h0;
                                col_off      <= 44'h0;
                                waddr_r      <= '0;
                                concat_phase <= 1'b0;
                                repeat_w     <= 1'b0;
                                repeat_h     <= 1'b0;
                                // UPSAMPLE writes 4x the LOAD count; same Act bank.
                                r_act_total  <= (fetch_mode == 3'b001)
                                    ? upsample_total_calc[$clog2(RES_BANK_DEPTH)-1:0]
                                    : act_total_calc[$clog2(RES_BANK_DEPTH)-1:0];
                                state        <= S_PIXEL;
                            end
                            3'b100: begin  // COEFF_LOAD
                                r_coeff_ch_count  <= coeff_ch_count;
                                // ceil(ch_count/2) total beats.
                                coeff_beats_total <= 9'((coeff_ch_count + 10'd1) >> 1);
                                coeff_waddr_r     <= '0;
                                coeff_last_beat   <= 1'b0;
                                coeff_beats_received <= 9'h0;
                                state             <= S_C_AR;
                            end
                            3'b101: begin  // LUT_LOAD
                                r_lut_sel     <= lut_sel;
                                lut_waddr_r   <= '0;
                                lut_byte_idx  <= 4'h0;
                                lut_last_beat <= 1'b0;
                                state         <= S_L_AR;
                            end
                            // 3'b011 (STORE): stay; Store FSM picks up via SS_IDLE.
                            default: ;
                        endcase
                    end
                end

                // Pixel base: CONCAT phase 1 sources from r_concat_base.
                // beat_cnt: CONCAT bursts only half the channels per phase.
                S_PIXEL: begin
                    r_pix_addr <= ((r_fetch_mode == 3'b010) && concat_phase)
                                  ? {12'h0, r_concat_base} + row_base + col_off
                                  : {12'h0, r_base}        + row_base + col_off;
                    beat_cnt   <= (r_fetch_mode == 3'b010)
                                  ? {1'b0, r_beats[7:1]} - 8'h1
                                  : r_beats - 8'h1;
                    state <= is_pad ? S_PAD : S_AR;
                end

                // Issue HP0 AR; hold arvalid until arready (AXI4 §A3.2.2).
                S_AR: begin
                    if (!hp0_arvalid) begin
                        hp0_araddr  <= r_pix_addr;
                        hp0_arlen   <= beat_cnt;  // mode-aware (set in S_PIXEL)
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
                // CONCAT: first half from r_base, second half from r_concat_base
                // before advancing the pixel.
                // UPSAMPLE: each source pixel emitted 2x in W and 2x in H by
                // re-entering S_PIXEL with col_off/row_base unchanged.
                S_ADV: begin
                    if ((r_fetch_mode == 3'b010) && !concat_phase) begin
                        // CONCAT: kick second-half burst for current pixel.
                        concat_phase <= 1'b1;
                        state        <= S_PIXEL;
                    end else if ((r_fetch_mode == 3'b001) && !repeat_w) begin
                        // UPSAMPLE: re-emit current src pixel in W direction.
                        repeat_w <= 1'b1;
                        state    <= S_PIXEL;
                    end else if (cur_w == r_tile_w - 8'h1) begin
                        cur_w        <= 8'h0;
                        col_off      <= 44'h0;
                        concat_phase <= 1'b0;
                        repeat_w     <= 1'b0;
                        if ((r_fetch_mode == 3'b001) && !repeat_h) begin
                            // UPSAMPLE: re-emit current src row in H direction.
                            repeat_h <= 1'b1;
                            state    <= S_PIXEL;
                        end else begin
                            repeat_h <= 1'b0;
                            row_base <= row_base + {28'h0, r_stride};
                            if (cur_h == r_tile_h - 8'h1) begin
                                load_done_r <= 1'b1;
                                state       <= S_IDLE;
                            end else begin
                                cur_h <= cur_h + 8'h1;
                                state <= S_PIXEL;
                            end
                        end
                    end else begin
                        cur_w        <= cur_w + 8'h1;
                        col_off      <= col_off + {36'h0, r_ch_count};
                        concat_phase <= 1'b0;
                        repeat_w     <= 1'b0;
                        state        <= S_PIXEL;
                    end
                end

                // -------------------------------------------------------------
                // OP_COEFF_LOAD path
                // -------------------------------------------------------------
                // Issue single HP0 AR for the full coeff burst.
                S_C_AR: begin
                    if (!hp0_arvalid) begin
                        hp0_araddr  <= {12'h0, r_base};
                        hp0_arlen   <= coeff_beats_total[7:0] - 8'h1;
                        hp0_arvalid <= 1'b1;
                    end else if (hp0_arready) begin
                        hp0_arvalid <= 1'b0;
                        state       <= S_C_R;
                    end
                end

                // Accept a beat; write entry 0 (low half). Drop rready next
                // cycle (S_C_WR1) so AXI throttles between paired writes.
                // coeff_last_beat backstop: assert on burst-length match in case
                // hp0_rlast is dropped by a non-strict slave during the rready toggle.
                S_C_R: begin
                    if (hp0_rvalid) begin
                        if (|hp0_rresp) err_load_r <= 1'b1;
                        coeff_buf        <= hp0_rdata;
                        coeff_last_beat  <= hp0_rlast |
                            (coeff_beats_received == coeff_beats_total - 9'h1);
                        sram_coeff_wdata <= {hp0_rdata[63:32], hp0_rdata[3:0]};
                        sram_coeff_waddr <= coeff_waddr_r;
                        sram_coeff_wen   <= 1'b1;
                        coeff_waddr_r    <= coeff_waddr_r + 1'b1;
                        coeff_beats_received <= coeff_beats_received + 9'h1;
                        state            <= S_C_WR1;
                    end
                end

                // Write entry 1 (high half) from captured beat.
                S_C_WR1: begin
                    sram_coeff_wdata <= {coeff_buf[127:96], coeff_buf[67:64]};
                    sram_coeff_waddr <= coeff_waddr_r;
                    sram_coeff_wen   <= 1'b1;
                    coeff_waddr_r    <= coeff_waddr_r + 1'b1;
                    state            <= coeff_last_beat ? S_IDLE : S_C_R;
                end

                // -------------------------------------------------------------
                // OP_LUT_LOAD path
                // -------------------------------------------------------------
                // Fixed 16-beat burst (LUT_DEPTH bytes total = 256).
                S_L_AR: begin
                    if (!hp0_arvalid) begin
                        hp0_araddr  <= {12'h0, r_base};
                        hp0_arlen   <= 8'd15;
                        hp0_arvalid <= 1'b1;
                    end else if (hp0_arready) begin
                        hp0_arvalid <= 1'b0;
                        state       <= S_L_R;
                    end
                end

                // Capture one beat; drain over 16 cycles in S_L_WR.
                S_L_R: begin
                    if (hp0_rvalid) begin
                        if (|hp0_rresp) err_load_r <= 1'b1;
                        lut_beat_buf  <= hp0_rdata;
                        lut_last_beat <= hp0_rlast;
                        lut_byte_idx  <= 4'h0;
                        state         <= S_L_WR;
                    end
                end

                // Drain one byte per cycle into LUT BRAM.
                S_L_WR: begin
                    sram_lut_wdata <= lut_beat_buf[{lut_byte_idx, 3'h0} +: 8];
                    sram_lut_waddr <= lut_waddr_r;
                    sram_lut_wen   <= 1'b1;
                    lut_waddr_r    <= lut_waddr_r + 1'b1;
                    if (lut_byte_idx == 4'hF) begin
                        state <= lut_last_beat ? S_IDLE : S_L_R;
                    end else begin
                        lut_byte_idx <= lut_byte_idx + 4'h1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // DMA_STORE FSM — registered logic.
    // Row loop: one AW+W burst per tile_h row; store_aw_addr += r_stride per row.
    // BRAM pipeline: SS_W_PRIME1 issues raddr=send_idx; SS_W_PRIME2 issues
    // raddr=send_idx+1 and captures first beat into wdata_reg. SS_W streams.
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            store_state     <= SS_IDLE;
            store_done_r    <= 1'b0;
            err_store_r     <= 1'b0;
            hp2_awaddr      <= 44'h0;
            hp2_awvalid     <= 1'b0;
            hp2_awlen       <= 8'h0;
            sram_raddr      <= '0;
            store_send_idx  <= '0;
            store_aw_addr   <= 44'h0;
            store_beat_idx  <= 8'h0;
            store_cur_h     <= 8'h0;
            store_per_row_r <= 8'h0;
            store_tile_h_r  <= 8'h0;
            store_stride_r  <= 16'h0;
            wdata_reg       <= 128'h0;
        end else begin
            store_done_r <= 1'b0;

            unique case (store_state)

                SS_IDLE: begin
                    if (start && fetch_mode == 3'b011) begin
                        store_aw_addr   <= {12'h0, src_base};
                        store_per_row_r <= store_per_row_calc[7:0];
                        store_tile_h_r  <= tile_h;
                        store_stride_r  <= row_stride;
                        store_send_idx  <= '0;
                        store_cur_h     <= 8'h0;
                        store_state     <= SS_AW;
                    end
                end

                // Issue HP2 AW; hold awvalid until awready (AXI4 §A3.2.2).
                SS_AW: begin
                    if (!hp2_awvalid) begin
                        hp2_awaddr  <= store_aw_addr;
                        hp2_awlen   <= store_per_row_r - 8'h1;
                        hp2_awvalid <= 1'b1;
                    end else if (hp2_awready) begin
                        hp2_awvalid <= 1'b0;
                        sram_raddr  <= store_send_idx;
                        store_state <= SS_W_PRIME1;
                    end
                end

                // PRIME1: raddr=send_idx in flight. Capture the first beat and
                // pre-issue send_idx+1 so the next SRAM word can become valid.
                SS_W_PRIME1: begin
                    wdata_reg      <= sram_rdata;
                    sram_raddr     <= store_send_idx + 1'b1;
                    store_beat_idx <= 8'h0;
                    store_state    <= SS_W;
                end

                // Registered SRAM output for the next beat is valid here.
                // Capture it before returning to the AXI W state.
                SS_W_LOAD: begin
                    wdata_reg  <= sram_rdata;
                    sram_raddr <= sram_raddr + 1'b1;
                    store_state <= SS_W;
                end

                // Stream: each accepted beat advances send_idx and lookahead.
                SS_W: if (hp2_wready) begin
                    store_send_idx <= store_send_idx + 1'b1;
                    if (store_beat_idx == store_per_row_r - 8'h1) begin
                        store_state <= SS_B;
                    end else begin
                        store_beat_idx <= store_beat_idx + 8'h1;
                        store_state    <= SS_W_LOAD;
                    end
                end

                // Wait for write response; sticky err on SLVERR/DECERR.
                SS_B: if (hp2_bvalid) begin
                    if (|hp2_bresp) err_store_r <= 1'b1;
                    if (store_cur_h == store_tile_h_r - 8'h1) begin
                        store_done_r <= 1'b1;
                        store_state  <= SS_IDLE;
                    end else begin
                        store_cur_h   <= store_cur_h + 8'h1;
                        store_aw_addr <= store_aw_addr + {28'h0, store_stride_r};
                        store_state   <= SS_AW;
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
