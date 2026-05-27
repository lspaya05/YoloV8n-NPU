// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// Top-level NPU integrating Sequencer, DMA, Systolic Array, PSB, Requant, VPU, SRAMHub, and inter-block DepFIFOs for the EE470 KR260 neural engine.
// Inputs:
//     - clk: System clock
//     - rst: Active-high sync reset
//     - s_axil_awaddr: AXI-Lite slave AW address (Sequencer CSR write)
//     - s_axil_awvalid: AXI-Lite slave AW valid
//     - s_axil_wdata: AXI-Lite slave W data (CSR value)
//     - s_axil_wvalid: AXI-Lite slave W valid
//     - s_axil_bready: AXI-Lite slave B ready
//     - seq_arready: HP0_SEQ AR handshake ready
//     - seq_rdata: HP0_SEQ R 32-bit instruction word
//     - seq_rvalid: HP0_SEQ R beat valid
//     - seq_rlast: HP0_SEQ R last-beat flag
//     - seq_rresp: HP0_SEQ R response code
//     - dma_arready: HP0_DMA AR handshake ready
//     - dma_rdata: HP0_DMA R 128-bit Act tile beat
//     - dma_rvalid: HP0_DMA R beat valid
//     - dma_rlast: HP0_DMA R last-beat flag
//     - dma_rresp: HP0_DMA R response code
//     - wt_arready: HP1_DMA AR handshake ready
//     - wt_rdata: HP1_DMA R 128-bit Weight tile beat
//     - wt_rvalid: HP1_DMA R beat valid
//     - wt_rlast: HP1_DMA R last-beat flag
//     - wt_rresp: HP1_DMA R response code
//     - st_awready: HP2_DMA AW handshake ready
//     - st_wready: HP2_DMA W handshake ready
//     - st_bresp: HP2_DMA B response code
//     - st_bvalid: HP2_DMA B response valid
// Outputs:
//     - s_axil_awready: AXI-Lite slave AW ready
//     - s_axil_wready: AXI-Lite slave W ready
//     - s_axil_bresp: AXI-Lite slave B response code
//     - s_axil_bvalid: AXI-Lite slave B valid
//     - seq_araddr: HP0_SEQ AR 44-bit DDR address
//     - seq_arvalid: HP0_SEQ AR valid
//     - seq_arlen: HP0_SEQ AR burst length minus 1
//     - seq_arsize: HP0_SEQ AR beat size
//     - seq_arburst: HP0_SEQ AR burst type (INCR)
//     - seq_rready: HP0_SEQ R ready
//     - dma_araddr: HP0_DMA AR 44-bit DDR address
//     - dma_arvalid: HP0_DMA AR valid
//     - dma_arlen: HP0_DMA AR burst length minus 1
//     - dma_arsize: HP0_DMA AR beat size (3'b100 = 16 B)
//     - dma_arburst: HP0_DMA AR burst type (INCR)
//     - dma_arcache: HP0_DMA AR cache attrs (4'b0011)
//     - dma_rready: HP0_DMA R ready
//     - wt_araddr: HP1_DMA AR 44-bit DDR address
//     - wt_arvalid: HP1_DMA AR valid
//     - wt_arlen: HP1_DMA AR burst length minus 1
//     - wt_arsize: HP1_DMA AR beat size
//     - wt_arburst: HP1_DMA AR burst type (INCR)
//     - wt_arcache: HP1_DMA AR cache attrs (4'b0011)
//     - wt_rready: HP1_DMA R ready
//     - st_awaddr: HP2_DMA AW 44-bit DDR address
//     - st_awvalid: HP2_DMA AW valid
//     - st_awlen: HP2_DMA AW burst length minus 1
//     - st_awsize: HP2_DMA AW beat size (3'b100 = 16 B)
//     - st_awburst: HP2_DMA AW burst type (INCR)
//     - st_awcache: HP2_DMA AW cache attrs (4'b0011)
//     - st_wdata: HP2_DMA W 128-bit beat data
//     - st_wstrb: HP2_DMA W byte strobes (all 1s)
//     - st_wlast: HP2_DMA W last-beat flag
//     - st_wvalid: HP2_DMA W valid
//     - st_bready: HP2_DMA B response ready
//     - irq_done: Per-frame interrupt on final DMA_STORE complete
//     - fetch_err: Sticky Sequencer AXI fetch error
//     - dma_err: Sticky DMA AXI error (HP0 / HP1 / HP2)

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;


// AXI port naming:
//   seq_* : Sequencer AXI4 read master  (instruction fetch, HP0_SEQ)
//   dma_* : DMA Ch0  AXI4 read master   (DMA_LOAD,  HP0_DMA)
//   wt_*  : DMA Ch1  AXI4 read master   (WT_LOAD,   HP1_DMA)
//   st_*  : DMA Ch0  AXI4 write master  (DMA_STORE, HP2_DMA)

module NPU (
    input  logic clk,
    input  logic rst,

    // -------------------------------------------------------------------------
    // AXI-Lite slave — Sequencer CSR (ARM PS writes instr_base / count / kick)
    // Write-only: AW + W + B channels only (no AR/R per v2.1 arch doc §14.2).
    // -------------------------------------------------------------------------
    input  logic [31:0] s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,

    // -------------------------------------------------------------------------
    // HP0_SEQ — Sequencer AXI4 read master (instruction fetch)
    // 4-beat 32-bit INCR bursts; Sequencer assembles 128-bit instructions.
    // -------------------------------------------------------------------------
    output logic [43:0] seq_araddr,
    output logic        seq_arvalid,
    output logic [7:0]  seq_arlen,
    output logic [2:0]  seq_arsize,
    output logic [1:0]  seq_arburst,
    input  logic        seq_arready,
    input  logic [31:0] seq_rdata,
    input  logic        seq_rvalid,
    input  logic        seq_rlast,
    input  logic [1:0]  seq_rresp,
    output logic        seq_rready,

    // -------------------------------------------------------------------------
    // HP0_DMA — DMA Ch0 AXI4 read master (DMA_LOAD activation tiles)
    // 128-bit data, 44-bit address, INCR, arcache=0011.
    // -------------------------------------------------------------------------
    output logic [43:0]  dma_araddr,
    output logic         dma_arvalid,
    output logic [7:0]   dma_arlen,
    output logic [2:0]   dma_arsize,
    output logic [1:0]   dma_arburst,
    output logic [3:0]   dma_arcache,
    input  logic         dma_arready,
    input  logic [127:0] dma_rdata,
    input  logic         dma_rvalid,
    input  logic         dma_rlast,
    input  logic [1:0]   dma_rresp,
    output logic         dma_rready,

    // -------------------------------------------------------------------------
    // HP1_DMA — DMA Ch1 AXI4 read master (WT_LOAD weight tiles)
    // 128-bit data, 44-bit address, INCR, arcache=0011.
    // -------------------------------------------------------------------------
    output logic [43:0]  wt_araddr,
    output logic         wt_arvalid,
    output logic [7:0]   wt_arlen,
    output logic [2:0]   wt_arsize,
    output logic [1:0]   wt_arburst,
    output logic [3:0]   wt_arcache,
    input  logic         wt_arready,
    input  logic [127:0] wt_rdata,
    input  logic         wt_rvalid,
    input  logic         wt_rlast,
    input  logic [1:0]   wt_rresp,
    output logic         wt_rready,

    // -------------------------------------------------------------------------
    // HP2_DMA — DMA Ch0 AXI4 write master (DMA_STORE Output Bank flush)
    // 128-bit data, 44-bit address, INCR, awcache=0011.
    // -------------------------------------------------------------------------
    output logic [43:0]  st_awaddr,
    output logic         st_awvalid,
    output logic [7:0]   st_awlen,
    output logic [2:0]   st_awsize,
    output logic [1:0]   st_awburst,
    output logic [3:0]   st_awcache,
    input  logic         st_awready,
    output logic [127:0] st_wdata,
    output logic [15:0]  st_wstrb,
    output logic         st_wlast,
    output logic         st_wvalid,
    input  logic         st_wready,
    input  logic [1:0]   st_bresp,
    input  logic         st_bvalid,
    output logic         st_bready,

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------
    output logic irq_done,   // per-frame IRQ (final DMA_STORE done — Phase 4)
    output logic fetch_err,  // Sequencer AXI error
    output logic dma_err     // DMA AXI error (HP0 or HP1)
);

// =============================================================================
// Sequencer block — instruction fetch, CSR shadow, per-unit dispatch fanout.
// =============================================================================

    // Dispatch fanout bus driven by Sequencer; consumed by all per-unit FIFOs.
    // bit map (disp_push / disp_full):
    //   [0]=DMA Ch0  [1]=SA  [2]=PSB  [3]=REQ  [4]=VPU  [5]=DMA Ch1 (WT_LOAD)
    logic [123:0] disp_payload;   // {opcode[7:0], dep_flags[3:0], payload[111:0]}
    logic [5:0]   disp_push;
    logic [5:0]   disp_full;

    // Per-unit completion vector returned to Sequencer FENCE logic.
    // Indexing follows npu_unit_e: 0=SEQ 1=DMA 2=SA 3=PSB 4=REQ 5=VPU.
    logic [5:0]   units_done;
    logic         sa_done_pulse, psb_done_pulse, req_done_pulse, vpu_done_pulse;

    // CSR shadow — held by Sequencer from the last OP_CONFIG.
    logic [7:0]  cfg_tile_M;
    logic [7:0]  cfg_tile_N;
    logic [7:0]  cfg_tile_K;
    logic [3:0]  cfg_stride;
    logic [1:0]  cfg_pad_mode;
    logic [31:0] cfg_coeff_base;
    logic [2:0]  cfg_act_type;
    logic [2:0]  cfg_pool_size;

    // UNIT_SEQ never fences on itself. UNIT_DMA reports done when both Ch0
    // (LOAD/STORE/UPSAMPLE/CONCAT/COEFF/LUT) and Ch1 (WT_LOAD) FSMs are idle.
    // Other units report idle via their dispatch modules.
    logic dma_ch0_idle_w, dma_ch1_idle_w;
    logic dma_act_bank_full_w;
    logic dma_wt_bank_full_w;
    always_comb begin
        units_done           = 6'b0;
        units_done[UNIT_DMA] = dma_ch0_idle_w & dma_ch1_idle_w;
        units_done[UNIT_SA]  = sa_done_pulse;
        units_done[UNIT_PSB] = psb_done_pulse;
        units_done[UNIT_REQ] = req_done_pulse;
        units_done[UNIT_VPU] = vpu_done_pulse;
    end

    Sequencer sequence_unit (
        .clk             (clk),
        .rst             (rst),

        .s_axil_awaddr   (s_axil_awaddr),
        .s_axil_awvalid  (s_axil_awvalid),
        .s_axil_awready  (s_axil_awready),
        .s_axil_wdata    (s_axil_wdata),
        .s_axil_wvalid   (s_axil_wvalid),
        .s_axil_wready   (s_axil_wready),
        .s_axil_bresp    (s_axil_bresp),
        .s_axil_bvalid   (s_axil_bvalid),
        .s_axil_bready   (s_axil_bready),

        .m_axi_araddr    (seq_araddr),
        .m_axi_arvalid   (seq_arvalid),
        .m_axi_arlen     (seq_arlen),
        .m_axi_arsize    (seq_arsize),
        .m_axi_arburst   (seq_arburst),
        .m_axi_arready   (seq_arready),
        .m_axi_rdata     (seq_rdata),
        .m_axi_rvalid    (seq_rvalid),
        .m_axi_rlast     (seq_rlast),
        .m_axi_rresp     (seq_rresp),
        .m_axi_rready    (seq_rready),

        .fifo_payload    (disp_payload),
        .fifo_push       (disp_push),
        .fifo_full       (disp_full),
        .unit_done       (units_done),

        .cfg_tile_M      (cfg_tile_M),
        .cfg_tile_N      (cfg_tile_N),
        .cfg_tile_K      (cfg_tile_K),
        .cfg_stride      (cfg_stride),
        .cfg_pad_mode    (cfg_pad_mode),
        .cfg_coeff_base  (cfg_coeff_base),
        .cfg_act_type    (cfg_act_type),
        .cfg_pool_size   (cfg_pool_size),

        .irq_done        (seq_irq_done_w),
        .fetch_err       (fetch_err)
    );

    // Top-level irq_done = DMA_STORE complete (v2.1 §IRQ semantics). Sequencer
    // irq stays internal (Phase 5 takes Phase-1 priority to DMA pulse).
    assign irq_done = dma_store_done_w;
    logic _unused_seq_irq;
    assign _unused_seq_irq = seq_irq_done_w;

// =============================================================================
// Dependency FIFOs — RAW/WAR ordering between units. Block-driven semantics:
// producer pushes a token on completion; consumer's dispatch pops before
// issuing dependent work. All push/pop pins are wired to their owning blocks.
// =============================================================================

    localparam int DepDepth = 8;

    // DMA <-> SA
    logic dma_to_sa_push,  dma_to_sa_pop,  dma_to_sa_full,  dma_to_sa_empty;
    logic sa_to_dma_push,  sa_to_dma_pop,  sa_to_dma_full,  sa_to_dma_empty;
    // SA <-> PSB
    logic sa_to_psb_push,  sa_to_psb_pop,  sa_to_psb_full,  sa_to_psb_empty;
    logic psb_to_sa_push,  psb_to_sa_pop,  psb_to_sa_full,  psb_to_sa_empty;
    // PSB <-> Requant
    logic psb_to_req_push, psb_to_req_pop, psb_to_req_full, psb_to_req_empty;
    logic req_to_psb_push, req_to_psb_pop, req_to_psb_full, req_to_psb_empty;
    // Requant <-> VPU
    logic req_to_vpu_push, req_to_vpu_pop, req_to_vpu_full, req_to_vpu_empty;
    logic vpu_to_req_push, vpu_to_req_pop, vpu_to_req_full, vpu_to_req_empty;
    // VPU <-> DMA
    logic vpu_to_dma_push, vpu_to_dma_pop, vpu_to_dma_full, vpu_to_dma_empty;
    logic dma_to_vpu_push, dma_to_vpu_pop, dma_to_vpu_full, dma_to_vpu_empty;

    DepFIFO #(.DEPTH(DepDepth)) dep_dma_to_sa (
        .clk(clk), .rst(rst),
        .push(dma_to_sa_push), .pop(dma_to_sa_pop),
        .full(dma_to_sa_full), .empty(dma_to_sa_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_sa_to_dma (
        .clk(clk), .rst(rst),
        .push(sa_to_dma_push), .pop(sa_to_dma_pop),
        .full(sa_to_dma_full), .empty(sa_to_dma_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_sa_to_psb (
        .clk(clk), .rst(rst),
        .push(sa_to_psb_push), .pop(sa_to_psb_pop),
        .full(sa_to_psb_full), .empty(sa_to_psb_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_psb_to_sa (
        .clk(clk), .rst(rst),
        .push(psb_to_sa_push), .pop(psb_to_sa_pop),
        .full(psb_to_sa_full), .empty(psb_to_sa_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_psb_to_req (
        .clk(clk), .rst(rst),
        .push(psb_to_req_push), .pop(psb_to_req_pop),
        .full(psb_to_req_full), .empty(psb_to_req_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_req_to_psb (
        .clk(clk), .rst(rst),
        .push(req_to_psb_push), .pop(req_to_psb_pop),
        .full(req_to_psb_full), .empty(req_to_psb_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_req_to_vpu (
        .clk(clk), .rst(rst),
        .push(req_to_vpu_push), .pop(req_to_vpu_pop),
        .full(req_to_vpu_full), .empty(req_to_vpu_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_vpu_to_req (
        .clk(clk), .rst(rst),
        .push(vpu_to_req_push), .pop(vpu_to_req_pop),
        .full(vpu_to_req_full), .empty(vpu_to_req_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_vpu_to_dma (
        .clk(clk), .rst(rst),
        .push(vpu_to_dma_push), .pop(vpu_to_dma_pop),
        .full(vpu_to_dma_full), .empty(vpu_to_dma_empty)
    );

    DepFIFO #(.DEPTH(DepDepth)) dep_dma_to_vpu (
        .clk(clk), .rst(rst),
        .push(dma_to_vpu_push), .pop(dma_to_vpu_pop),
        .full(dma_to_vpu_full), .empty(dma_to_vpu_empty)
    );

    // All DepFIFO push/pop pins are now owned by their respective block
    // wrappers (Phases 2–6). No tie-offs remain at NPU top.


// =============================================================================
// DMA block — Ch0 (LOAD/STORE/UPSAMPLE/CONCAT/COEFF) + Ch1 (WT_LOAD) FIFOs,
// Dispatch_DMA (Phase 2 real decoder, Ch0 active), and DMA datapath.
// =============================================================================

    // FIFO read-side
    logic [123:0] dma0_dout, dma1_dout;
    logic         dma0_empty, dma1_empty;
    logic         dma0_rd_en, dma1_rd_en;
    logic         dma_err_w;

    assign dma_err = dma_err_w;

    // Dispatch_DMA → DMA descriptor + handshake (Phase 2).
    logic [31:0] desc_src_base_w;
    logic [15:0] desc_row_stride_w;
    logic [7:0]  desc_tile_w_w, desc_tile_h_w, desc_ch_count_w;
    logic [3:0]  desc_pad_top_w, desc_pad_bot_w, desc_pad_left_w, desc_pad_right_w;
    logic [2:0]  desc_fetch_mode_w;
    logic [31:0] desc_concat_base_w;
    logic [9:0]  desc_coeff_ch_count_w;
    logic        desc_lut_sel_w;
    logic        desc_start_w;

    // DMA Coeff/LUT BRAM write ports (Phase 6).
    logic [$clog2(MAX_CHANNELS)-1:0]            dma_coeff_waddr_w;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]     dma_coeff_wdata_w;
    logic                                        dma_coeff_wen_w;
    logic [$clog2(LUT_DEPTH)-1:0]               dma_lut_waddr_w;
    logic [7:0]                                  dma_lut_wdata_w;
    logic                                        dma_lut_wen_w;
    logic                                        dma_lut_sel_w;

    // DMA SRAM Act-bank write port (Phase 3). DMA's sram_waddr is sized for
    // RES_BANK_DEPTH (10b); Act bank is ACT_BUF_DEPTH (8b) — truncate low bits.
    logic [$clog2(RES_BANK_DEPTH)-1:0] dma_sram_waddr_w;
    logic [127:0]                      dma_sram_wdata_w;
    logic                              dma_sram_wen_w;

    // DMA Ch1 WT_LOAD descriptor + Wt-bank write port (Phase 4).
    logic        ch1_start_w;
    logic [31:0] wt_src_base_w;
    logic [$clog2(WT_BUF_DEPTH)-1:0] dma_sram_wt_waddr_w;
    logic [127:0]                    dma_sram_wt_wdata_w;
    logic                            dma_sram_wt_wen_w;

    // DMA Output-bank read port + STORE done (Phase 5).
    logic [$clog2(RES_BANK_DEPTH)-1:0] dma_sram_raddr_w;
    logic [127:0]                      dma_sram_rdata_w;
    logic                              dma_store_done_w;
    logic                              seq_irq_done_w;

    // wt_* read master now driven by DMA HP1 (Phase 1 ties low inside DMA.sv;
    // Phase 4 brings up the Ch1 FSM). No top-level tie-offs needed.

    // DMA Ch0 — DMA_LOAD / DMA_STORE / UPSAMPLE / CONCAT / COEFF_LOAD
    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (16)
    ) DMA_Ch0_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[0]),
        .rd_en  (dma0_rd_en),
        .din    (disp_payload),
        .dout   (dma0_dout),
        .full   (disp_full[0]),
        .empty  (dma0_empty)
    );

    // DMA Ch1 — WT_LOAD only
    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (16)
    ) DMA_Ch1_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[5]),
        .rd_en  (dma1_rd_en),
        .din    (disp_payload),
        .dout   (dma1_dout),
        .full   (disp_full[5]),
        .empty  (dma1_empty)
    );

    Dispatch_DMA u_dispatch_dma (
        .clk                  (clk),
        .rst                  (rst),

        .ch0_dout             (dma0_dout),
        .ch0_empty            (dma0_empty),
        .ch0_rd_en            (dma0_rd_en),

        .ch1_dout             (dma1_dout),
        .ch1_empty            (dma1_empty),
        .ch1_rd_en            (dma1_rd_en),

        .wt_src_base          (wt_src_base_w),
        .ch1_start            (ch1_start_w),
        .dma_ch1_idle         (dma_ch1_idle_w),

        .desc_src_base        (desc_src_base_w),
        .desc_row_stride      (desc_row_stride_w),
        .desc_tile_w          (desc_tile_w_w),
        .desc_tile_h          (desc_tile_h_w),
        .desc_ch_count        (desc_ch_count_w),
        .desc_pad_top         (desc_pad_top_w),
        .desc_pad_bot         (desc_pad_bot_w),
        .desc_pad_left        (desc_pad_left_w),
        .desc_pad_right       (desc_pad_right_w),
        .desc_fetch_mode      (desc_fetch_mode_w),
        .desc_concat_base     (desc_concat_base_w),
        .desc_coeff_ch_count  (desc_coeff_ch_count_w),
        .desc_lut_sel         (desc_lut_sel_w),
        .desc_start           (desc_start_w),

        .dma_ch0_idle         (dma_ch0_idle_w),

        .dep_sa_to_dma_empty  (sa_to_dma_empty),
        .dep_sa_to_dma_pop    (sa_to_dma_pop),
        .dep_vpu_to_dma_empty (vpu_to_dma_empty),
        .dep_vpu_to_dma_pop   (vpu_to_dma_pop)
    );

    DMA dma_unit (
        .clk          (clk),
        .rst          (rst),

        // Descriptor — driven by Dispatch_DMA (Phase 2).
        .src_base     (desc_src_base_w),
        .row_stride   (desc_row_stride_w),
        .tile_w       (desc_tile_w_w),
        .tile_h       (desc_tile_h_w),
        .ch_count     (desc_ch_count_w),
        .pad_top      (desc_pad_top_w),
        .pad_bot      (desc_pad_bot_w),
        .pad_left     (desc_pad_left_w),
        .pad_right    (desc_pad_right_w),
        .fetch_mode      (desc_fetch_mode_w),
        .concat_base     (desc_concat_base_w),
        .coeff_ch_count  (desc_coeff_ch_count_w),
        .lut_sel         (desc_lut_sel_w),

        // Ch1 descriptor + start
        .ch1_start    (ch1_start_w),
        .wt_src_base  (wt_src_base_w),

        .start             (desc_start_w),
        .ch0_idle          (dma_ch0_idle_w),
        .ch1_idle          (dma_ch1_idle_w),
        .dma_act_bank_full (dma_act_bank_full_w),
        .dma_wt_bank_full  (dma_wt_bank_full_w),
        .dma_store_done    (dma_store_done_w),

        // HP0 read — wired to NPU top-level dma_* AXI master.
        .hp0_araddr   (dma_araddr),
        .hp0_arvalid  (dma_arvalid),
        .hp0_arlen    (dma_arlen),
        .hp0_arsize   (dma_arsize),
        .hp0_arburst  (dma_arburst),
        .hp0_arcache  (dma_arcache),
        .hp0_arready  (dma_arready),
        .hp0_rdata    (dma_rdata),
        .hp0_rvalid   (dma_rvalid),
        .hp0_rlast    (dma_rlast),
        .hp0_rresp    (dma_rresp),
        .hp0_rready   (dma_rready),

        // HP2 write — DMA_STORE master (driven Phase 5; ports wired now).
        .hp2_awaddr   (st_awaddr),
        .hp2_awvalid  (st_awvalid),
        .hp2_awlen    (st_awlen),
        .hp2_awsize   (st_awsize),
        .hp2_awburst  (st_awburst),
        .hp2_awcache  (st_awcache),
        .hp2_awready  (st_awready),
        .hp2_wdata    (st_wdata),
        .hp2_wstrb    (st_wstrb),
        .hp2_wlast    (st_wlast),
        .hp2_wvalid   (st_wvalid),
        .hp2_wready   (st_wready),
        .hp2_bresp    (st_bresp),
        .hp2_bvalid   (st_bvalid),
        .hp2_bready   (st_bready),

        // HP1 read — WT_LOAD master (driven Phase 4; ports wired now).
        .hp1_araddr   (wt_araddr),
        .hp1_arvalid  (wt_arvalid),
        .hp1_arlen    (wt_arlen),
        .hp1_arsize   (wt_arsize),
        .hp1_arburst  (wt_arburst),
        .hp1_arcache  (wt_arcache),
        .hp1_arready  (wt_arready),
        .hp1_rdata    (wt_rdata),
        .hp1_rvalid   (wt_rvalid),
        .hp1_rlast    (wt_rlast),
        .hp1_rresp    (wt_rresp),
        .hp1_rready   (wt_rready),

        // Ch0 SRAM write → SRAMHub Act bank (Phase 3); SRAM read → Output bank
        // (Phase 5, DMA_STORE).
        .sram_waddr   (dma_sram_waddr_w),
        .sram_wdata   (dma_sram_wdata_w),
        .sram_wen     (dma_sram_wen_w),
        .sram_raddr   (dma_sram_raddr_w),
        .sram_rdata   (dma_sram_rdata_w),

        // Wt SRAM write port → SRAMHub Weight bank (Phase 4).
        .sram_wt_waddr (dma_sram_wt_waddr_w),
        .sram_wt_wdata (dma_sram_wt_wdata_w),
        .sram_wt_wen   (dma_sram_wt_wen_w),

        // Coeff / LUT BRAM write ports → SRAMHub (Phase 6).
        .sram_coeff_waddr (dma_coeff_waddr_w),
        .sram_coeff_wdata (dma_coeff_wdata_w),
        .sram_coeff_wen   (dma_coeff_wen_w),
        .sram_lut_waddr   (dma_lut_waddr_w),
        .sram_lut_wdata   (dma_lut_wdata_w),
        .sram_lut_wen     (dma_lut_wen_w),
        .sram_lut_sel     (dma_lut_sel_w),

        .dma_err      (dma_err_w),

        // Dep-FIFO: push owned by DMA (producer), pop owned by Dispatch_DMA
        // (consumer; Phase 2). DMA's pop outputs are tied 0 internally and
        // left unconnected to avoid multi-driver on sa_to_dma_pop / vpu_to_dma_pop.
        .dep_sa_to_dma_empty  (sa_to_dma_empty),
        .dep_sa_to_dma_pop    (),
        .dep_vpu_to_dma_empty (vpu_to_dma_empty),
        .dep_vpu_to_dma_pop   (),
        .dep_dma_to_sa_full   (dma_to_sa_full),
        .dep_dma_to_sa_push   (dma_to_sa_push),
        .dep_dma_to_vpu_full  (dma_to_vpu_full),
        .dep_dma_to_vpu_push  (dma_to_vpu_push)
    );

// =============================================================================
// SRAM Hub block — Act/Wt ping-pong, Res, Out, Coeff BRAM, LUT banks.
// All DMA write ports (Act/Wt/Out/Coeff/LUT) and SA/VPU/Requant read ports are
// wired to their owning blocks. Residual-bank write port still tied 0 (no DMA
// path for skip-tensor preload yet; future work).
// =============================================================================

    // SA-side (driven by Dispatch_SA in the SA block below)
    logic [$clog2(ACT_BUF_DEPTH)-1:0]               sa_act_raddr_w;
    logic [$clog2(WT_BUF_DEPTH)-1:0]                sa_wt_raddr_w;
    logic                                           sa_act_bank_read_w;
    logic                                           sa_wt_bank_read_w;
    logic [127:0]                                   sa_act_rdata_w;
    logic [127:0]                                   sa_wt_rdata_w;

    // Requant-side (driven by Dispatch_REQ in the Requant block below)
    logic [$clog2(MAX_CHANNELS)-1:0]                req_coeff_raddr_w;
    logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0]         req_coeff_rdata_w;
    logic [$clog2(OUT_BANK_DEPTH)-1:0]              req_vpu_out_waddr_w;
    logic [127:0]                                   req_vpu_out_wdata_w;
    logic                                           req_vpu_out_wen_w;

    // VPU-side (driven by Dispatch_VPU in the VPU block below)
    logic [$clog2(OUT_BANK_DEPTH)-1:0]              vpu_hred_raddr_w;
    logic [127:0]                                   vpu_hred_rdata_w;
    logic [$clog2(RES_BANK_DEPTH)-1:0]              vpu_res_raddr_w;
    logic [127:0]                                   vpu_res_rdata_w;
    logic                                           vpu_out_rd_sel_w;
    logic [$clog2(OUT_BANK_DEPTH)-1:0]              vpu_vpu_out_waddr_w;
    logic [127:0]                                   vpu_vpu_out_wdata_w;
    logic                                           vpu_vpu_out_wen_w;
    logic                                           vpu_lut_sel_w;
    logic [7:0]                                     vpu_lut_raddr_w;
    logic [7:0]                                     vpu_lut_rdata_w;

    // Output Bank writer mux: Requant (Phase 4 path) vs VPU dispatch (Phase 5
    // path). Sequencer FENCEs guarantee they don't fire simultaneously, but
    // the mux is needed because both ports exist concurrently.
    logic [$clog2(OUT_BANK_DEPTH)-1:0] out_waddr_mux_w;
    logic [127:0]                     out_wdata_mux_w;
    logic                             out_wen_mux_w;

    assign out_wen_mux_w   = req_vpu_out_wen_w | vpu_vpu_out_wen_w;
    assign out_waddr_mux_w = vpu_vpu_out_wen_w ? vpu_vpu_out_waddr_w
                                               : req_vpu_out_waddr_w;
    assign out_wdata_mux_w = vpu_vpu_out_wen_w ? vpu_vpu_out_wdata_w
                                               : req_vpu_out_wdata_w;

    // Act-bank ping-pong now driven by DMA (Phase 3); other DMA-side ports
    // (Wt, Out, Coeff, LUT) come up in Phases 4–6.
    SRAMHub SRAM_hub (
        .clk               (clk),
        .rst               (rst),

        // Activation ping-pong — DMA Act write (truncate addr to bank width)
        .dma_act_waddr     (dma_sram_waddr_w[$clog2(ACT_BUF_DEPTH)-1:0]),
        .dma_act_wdata     (dma_sram_wdata_w),
        .dma_act_wen       (dma_sram_wen_w),
        .dma_act_bank_full (dma_act_bank_full_w),
        .sa_act_raddr      (sa_act_raddr_w),
        .sa_act_rdata      (sa_act_rdata_w),
        .sa_act_bank_read  (sa_act_bank_read_w),

        // Weight ping-pong — driven by DMA Ch1 (Phase 4)
        .dma_wt_waddr      (dma_sram_wt_waddr_w),
        .dma_wt_wdata      (dma_sram_wt_wdata_w),
        .dma_wt_wen        (dma_sram_wt_wen_w),
        .dma_wt_bank_full  (dma_wt_bank_full_w),
        .sa_wt_raddr       (sa_wt_raddr_w),
        .sa_wt_rdata       (sa_wt_rdata_w),
        .sa_wt_bank_read   (sa_wt_bank_read_w),

        // Residual bank — VPU reads via Dispatch_VPU
        .dma_res_waddr     ('0),
        .dma_res_wdata     (128'h0),
        .dma_res_wen       (1'b0),
        .vpu_res_raddr     (vpu_res_raddr_w),
        .vpu_res_rdata     (vpu_res_rdata_w),

        // Output bank — muxed writer (Requant or VPU), VPU reader (HREDUCE),
        // DMA reader for DMA_STORE (Phase 5). out_rd_sel must be 0 during STORE;
        // Sequencer FENCEs guarantee VPU HREDUCE doesn't fire concurrently.
        .vpu_out_waddr     (out_waddr_mux_w),
        .vpu_out_wdata     (out_wdata_mux_w),
        .vpu_out_wen       (out_wen_mux_w),
        .out_rd_sel        (vpu_out_rd_sel_w),
        .dma_out_raddr     (dma_sram_raddr_w[$clog2(OUT_BANK_DEPTH)-1:0]),
        .dma_out_rdata     (dma_sram_rdata_w),
        .vpu_hred_raddr    (vpu_hred_raddr_w),
        .vpu_hred_rdata    (vpu_hred_rdata_w),

        // Requant Coeff BRAM — DMA writes via OP_COEFF_LOAD (Phase 6).
        .dma_coeff_waddr   (dma_coeff_waddr_w),
        .dma_coeff_wdata   (dma_coeff_wdata_w),
        .dma_coeff_wen     (dma_coeff_wen_w),
        .req_coeff_raddr   (req_coeff_raddr_w),
        .req_coeff_rdata   (req_coeff_rdata_w),

        // LUT banks — DMA writes via OP_LUT_LOAD (Phase 6). Read-side wired to
        // VPU dispatch; raddr not yet driven (SIMD_ACT RTL deferred).
        .dma_lut_waddr     (dma_lut_waddr_w),
        .dma_lut_wdata     (dma_lut_wdata_w),
        .dma_lut_wen       (dma_lut_wen_w),
        .dma_lut_sel       (dma_lut_sel_w),
        .vpu_lut_raddr     (vpu_lut_raddr_w),
        .vpu_lut_rdata     (vpu_lut_rdata_w),
        .vpu_lut_sel       (vpu_lut_sel_w)
    );


// =============================================================================
// Systolic Array block — encapsulated in SA_Block wrapper. Owns its instr
// FIFO, Dispatch_SA, packed/unpacked conversion, and SA_top datapath.
// =============================================================================

    logic signed [ACCUM_WIDTH-1:0] sa_row_out_w [SA_COLS-1:0];
    logic                          sa_row_valid_w;

    SA_Block u_sa_block (
        .clk                  (clk),
        .rst                  (rst),

        .disp_payload         (disp_payload),
        .disp_push            (disp_push[1]),
        .disp_full            (disp_full[1]),
        .unit_done            (sa_done_pulse),

        .cfg_tile_K           (cfg_tile_K),

        .sa_act_raddr         (sa_act_raddr_w),
        .sa_act_rdata         (sa_act_rdata_w),
        .sa_act_bank_read     (sa_act_bank_read_w),
        .sa_wt_raddr          (sa_wt_raddr_w),
        .sa_wt_rdata          (sa_wt_rdata_w),
        .sa_wt_bank_read      (sa_wt_bank_read_w),

        .sa_row_out           (sa_row_out_w),
        .sa_row_valid         (sa_row_valid_w),

        .dep_dma_to_sa_empty  (dma_to_sa_empty),
        .dep_dma_to_sa_pop    (dma_to_sa_pop),
        .dep_psb_to_sa_empty  (psb_to_sa_empty),
        .dep_psb_to_sa_pop    (psb_to_sa_pop),

        .dep_sa_to_dma_full   (sa_to_dma_full),
        .dep_sa_to_dma_push   (sa_to_dma_push),
        .dep_sa_to_psb_full   (sa_to_psb_full),
        .dep_sa_to_psb_push   (sa_to_psb_push)
    );


// =============================================================================
// PSB block — encapsulated in PSB_Block wrapper. Owns its instr FIFO,
// Dispatch_PSB, and the partial-sum accumulator.
// =============================================================================

    logic [SA_COLS*ACCUM_WIDTH-1:0] requant_row_out_w;
    logic [$clog2(SA_ROWS)-1:0]     psb_row_index_w;
    logic                           psb_row_out_valid_w;

    PSB_Block u_psb_block (
        .clk                  (clk),
        .rst                  (rst),

        .disp_payload         (disp_payload),
        .disp_push            (disp_push[2]),
        .disp_full            (disp_full[2]),
        .unit_done            (psb_done_pulse),

        .sa_row_in            (sa_row_out_w),
        .sa_row_valid         (sa_row_valid_w),

        .requant_row_out      (requant_row_out_w),
        .row_index_out        (psb_row_index_w),
        .row_out_valid        (psb_row_out_valid_w),

        .dep_sa_to_psb_empty  (sa_to_psb_empty),
        .dep_sa_to_psb_pop    (sa_to_psb_pop),
        .dep_req_to_psb_empty (req_to_psb_empty),
        .dep_req_to_psb_pop   (req_to_psb_pop),

        .dep_psb_to_sa_full   (psb_to_sa_full),
        .dep_psb_to_sa_push   (psb_to_sa_push),
        .dep_psb_to_req_full  (psb_to_req_full),
        .dep_psb_to_req_push  (psb_to_req_push)
    );

    // psb_row_index_w: PSB row index output has no downstream consumer at this
    // level (Requant_Block addresses coefficients internally). Suppress lint.
    logic _unused_psb_row_idx;
    assign _unused_psb_row_idx = |psb_row_index_w;


// =============================================================================
// Requant block — encapsulated in Requant_Block wrapper. Owns its instr FIFO,
// Dispatch_REQ, coeff handling, and RequantPipeline datapath.
// =============================================================================

    Requant_Block #(
        .Lanes      (64),
        .ChCount    (4),
        .M0Width    (COEFF_M_WIDTH),
        .ShiftWidth (8)
    ) u_requant_block (
        .clk                  (clk),
        .rst                  (rst),

        .disp_payload         (disp_payload),
        .disp_push            (disp_push[3]),
        .disp_full            (disp_full[3]),
        .unit_done            (req_done_pulse),

        .psb_row_in           (requant_row_out_w),
        .psb_row_valid        (psb_row_out_valid_w),

        .coeff_raddr          (req_coeff_raddr_w),
        .coeff_rdata          (req_coeff_rdata_w),

        .out_waddr            (req_vpu_out_waddr_w),
        .out_wdata            (req_vpu_out_wdata_w),
        .out_wen              (req_vpu_out_wen_w),

        .dep_psb_to_req_empty (psb_to_req_empty),
        .dep_psb_to_req_pop   (psb_to_req_pop),
        .dep_vpu_to_req_empty (vpu_to_req_empty),
        .dep_vpu_to_req_pop   (vpu_to_req_pop),

        .dep_req_to_psb_full  (req_to_psb_full),
        .dep_req_to_psb_push  (req_to_psb_push),
        .dep_req_to_vpu_full  (req_to_vpu_full),
        .dep_req_to_vpu_push  (req_to_vpu_push)
    );


// =============================================================================
// VPU block — instr FIFO, dispatch, and vector processing unit.
// LANES kept at 16 (matches Output Bank 128-bit word). v2.1 spec targets 64
// lanes — bumping requires multi-word SRAM gather/scatter; deferred.
// =============================================================================

    VPU_Block #(
        .Lanes (16)
    ) u_vpu_block (
        .clk                  (clk),
        .rst                  (rst),

        .disp_payload         (disp_payload),
        .disp_push            (disp_push[4]),
        .disp_full            (disp_full[4]),
        .unit_done            (vpu_done_pulse),

        .cfg_tile_M           (cfg_tile_M),
        .cfg_tile_N           (cfg_tile_N),

        .hred_raddr           (vpu_hred_raddr_w),
        .hred_rdata           (vpu_hred_rdata_w),
        .out_rd_sel           (vpu_out_rd_sel_w),

        .res_raddr            (vpu_res_raddr_w),
        .res_rdata            (vpu_res_rdata_w),

        .lut_sel              (vpu_lut_sel_w),
        .lut_raddr            (vpu_lut_raddr_w),
        .lut_rdata            (vpu_lut_rdata_w),

        .out_waddr            (vpu_vpu_out_waddr_w),
        .out_wdata            (vpu_vpu_out_wdata_w),
        .out_wen              (vpu_vpu_out_wen_w),

        .dep_req_to_vpu_empty (req_to_vpu_empty),
        .dep_req_to_vpu_pop   (req_to_vpu_pop),
        .dep_dma_to_vpu_empty (dma_to_vpu_empty),
        .dep_dma_to_vpu_pop   (dma_to_vpu_pop),

        .dep_vpu_to_req_full  (vpu_to_req_full),
        .dep_vpu_to_req_push  (vpu_to_req_push),
        .dep_vpu_to_dma_full  (vpu_to_dma_full),
        .dep_vpu_to_dma_push  (vpu_to_dma_push)
    );

endmodule
