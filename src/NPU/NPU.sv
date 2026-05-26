import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;


// AXI port naming:
//   seq_* : Sequencer AXI4 read master (instruction fetch, HP0_SEQ)
//   dma_* : DMA Ch0  AXI4 read master (DMA_LOAD, HP0_DMA)
//   wt_*  : DMA Ch1  AXI4 read master (WT_LOAD,  HP1_DMA)

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

    // UNIT_SEQ never fences on itself. UNIT_DMA is tied high this pass — DMA
    // datapath is deferred and we don't want FENCE to stall. Other units are
    // driven by their dispatch modules (held inactive until Phases 2–5).
    always_comb begin
        units_done           = 6'b0;
        units_done[UNIT_DMA] = 1'b1;
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

        .irq_done        (irq_done),
        .fetch_err       (fetch_err)
    );

// =============================================================================
// DMA block — Ch0 (LOAD/STORE/UPSAMPLE/CONCAT/COEFF) + Ch1 (WT_LOAD) FIFOs,
// Dispatch_DMA stub, and the DMA datapath shell. DMA logic deferred; shell
// holds `start` low so the unit stays in S_IDLE.
// =============================================================================

    // FIFO read-side
    logic [123:0] dma0_dout, dma1_dout;
    logic         dma0_empty, dma1_empty;
    logic         dma0_rd_en, dma1_rd_en;
    logic         dma_err_w;

    assign dma_err = dma_err_w;

    // Tie NPU top-level wt_* read master inactive (DMA HP1 is a write port in
    // current DMA.sv — polarity discrepancy tracked in NPU_WIRING_PLAN.md).
    assign wt_araddr  = 44'h0;
    assign wt_arvalid = 1'b0;
    assign wt_arlen   = 8'h0;
    assign wt_arsize  = 3'b000;
    assign wt_arburst = 2'b00;
    assign wt_arcache = 4'b0000;
    assign wt_rready  = 1'b0;

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
        .clk        (clk),
        .rst        (rst),
        .ch0_dout   (dma0_dout),
        .ch0_empty  (dma0_empty),
        .ch0_rd_en  (dma0_rd_en),
        .ch1_dout   (dma1_dout),
        .ch1_empty  (dma1_empty),
        .ch1_rd_en  (dma1_rd_en)
    );

    DMA dma_unit (
        .clk          (clk),
        .rst          (rst),

        // Descriptor — all tied off; DMA stays in S_IDLE.
        .src_base     (32'h0),
        .row_stride   (16'h0),
        .tile_w       (8'h0),
        .tile_h       (8'h0),
        .ch_count     (8'h0),
        .pad_top      (4'h0),
        .pad_bot      (4'h0),
        .pad_left     (4'h0),
        .pad_right    (4'h0),
        .fetch_mode   (2'b00),
        .concat_base  (32'h0),

        .start        (1'b0),
        .busy         (),
        .done         (),

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

        // HP1 write — not exposed to NPU top-level this pass.
        .hp1_awaddr   (),
        .hp1_awvalid  (),
        .hp1_awlen    (),
        .hp1_awsize   (),
        .hp1_awburst  (),
        .hp1_awcache  (),
        .hp1_awready  (1'b0),
        .hp1_wdata    (),
        .hp1_wstrb    (),
        .hp1_wlast    (),
        .hp1_wvalid   (),
        .hp1_wready   (1'b0),
        .hp1_bresp    (2'b00),
        .hp1_bvalid   (1'b0),
        .hp1_bready   (),

        // SRAM ports — open until SRAMHub instantiated (Phase 2).
        .sram_waddr   (),
        .sram_wdata   (),
        .sram_wen     (),
        .sram_raddr   (),
        .sram_rdata   (128'h0),

        .dma_err      (dma_err_w)
    );

// =============================================================================
// SRAM Hub block — Act/Wt ping-pong, Res, Out, Coeff BRAM, LUT banks.
// Phase 2: only SA-side read ports are driven; all DMA write ports and the
// VPU/Requant ports are tied to 0 until their owning blocks come online.
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

    // DMA-side bank-full sticky flags — DMA stub never asserts them, so the
    // PingPongBuffer stays on bank A and Dispatch_SA reads bank A forever.
    // Acceptable for elaboration / single-tile bring-up; revisit when DMA
    // datapath comes up.
    SRAMHub SRAM_hub (
        .clk               (clk),
        .rst               (rst),

        // Activation ping-pong
        .dma_act_waddr     ('0),
        .dma_act_wdata     (128'h0),
        .dma_act_wen       (1'b0),
        .dma_act_bank_full (1'b0),
        .sa_act_raddr      (sa_act_raddr_w),
        .sa_act_rdata      (sa_act_rdata_w),
        .sa_act_bank_read  (sa_act_bank_read_w),

        // Weight ping-pong
        .dma_wt_waddr      ('0),
        .dma_wt_wdata      (128'h0),
        .dma_wt_wen        (1'b0),
        .dma_wt_bank_full  (1'b0),
        .sa_wt_raddr       (sa_wt_raddr_w),
        .sa_wt_rdata       (sa_wt_rdata_w),
        .sa_wt_bank_read   (sa_wt_bank_read_w),

        // Residual bank — VPU reads via Dispatch_VPU
        .dma_res_waddr     ('0),
        .dma_res_wdata     (128'h0),
        .dma_res_wen       (1'b0),
        .vpu_res_raddr     (vpu_res_raddr_w),
        .vpu_res_rdata     (vpu_res_rdata_w),

        // Output bank — muxed writer (Requant or VPU), VPU reader (HREDUCE).
        .vpu_out_waddr     (out_waddr_mux_w),
        .vpu_out_wdata     (out_wdata_mux_w),
        .vpu_out_wen       (out_wen_mux_w),
        .out_rd_sel        (vpu_out_rd_sel_w),
        .dma_out_raddr     ('0),
        .dma_out_rdata     (),
        .vpu_hred_raddr    (vpu_hred_raddr_w),
        .vpu_hred_rdata    (vpu_hred_rdata_w),

        // Requant Coeff BRAM
        .dma_coeff_waddr   ('0),
        .dma_coeff_wdata   ('0),
        .dma_coeff_wen     (1'b0),
        .req_coeff_raddr   (req_coeff_raddr_w),
        .req_coeff_rdata   (req_coeff_rdata_w),

        // LUT banks — read-side wired to VPU dispatch (raddr not yet driven
        // because SIMD_ACT is RTL-deferred; sel held latched for LUT_BYPASS).
        .dma_lut_waddr     (8'h0),
        .dma_lut_wdata     (8'h0),
        .dma_lut_wen       (1'b0),
        .dma_lut_sel       (1'b0),
        .vpu_lut_raddr     (8'h0),
        .vpu_lut_rdata     (),
        .vpu_lut_sel       (vpu_lut_sel_w)
    );


// =============================================================================
// Systolic Array block — instr FIFO, dispatch, and 16x16 SA datapath.
// =============================================================================

    logic [123:0] sa_dout;
    logic         sa_empty, sa_rd_en;
    logic         sa_start_w;
    logic         sa_done_w;
    logic         sa_busy_w;
    logic         sa_load_done_w;

    // 128-bit packed bank rdata -> unpacked INT8[16] arrays for SA_top.
    logic signed [ACT_WIDTH-1:0] weightInputRow    [SA_COLS-1:0];
    logic signed [ACT_WIDTH-1:0] activationInputCol[SA_ROWS-1:0];
    logic signed [ACCUM_WIDTH-1:0] MatrixMulOut    [SA_COLS-1:0];

    genvar gi;
    generate
        for (gi = 0; gi < SA_COLS; gi = gi + 1) begin : gen_wt_unpack
            assign weightInputRow[gi] =
                sa_wt_rdata_w[gi*ACT_WIDTH +: ACT_WIDTH];
        end
        for (gi = 0; gi < SA_ROWS; gi = gi + 1) begin : gen_act_unpack
            assign activationInputCol[gi] =
                sa_act_rdata_w[gi*ACT_WIDTH +: ACT_WIDTH];
        end
    endgenerate

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (32)
    ) SA_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[1]),
        .rd_en  (sa_rd_en),
        .din    (disp_payload),
        .dout   (sa_dout),
        .full   (disp_full[1]),
        .empty  (sa_empty)
    );

    Dispatch_SA u_dispatch_sa (
        .clk              (clk),
        .rst              (rst),
        .fifo_dout        (sa_dout),
        .fifo_empty       (sa_empty),
        .fifo_rd_en       (sa_rd_en),
        .sa_done          (sa_done_w),
        .cfg_tile_K       (cfg_tile_K),
        .sa_start         (sa_start_w),
        .sa_act_raddr     (sa_act_raddr_w),
        .sa_wt_raddr      (sa_wt_raddr_w),
        .sa_act_bank_read (sa_act_bank_read_w),
        .sa_wt_bank_read  (sa_wt_bank_read_w),
        .unit_done        (sa_done_pulse)
    );

    SA_top #(
        .FORMAT_BITWIDTH      (ACT_WIDTH),
        .ACCUMULATOR_BITWIDTH (ACCUM_WIDTH),
        .ARRAY_HEIGHT         (SA_ROWS),
        .ARRAY_LENGTH         (SA_COLS),
        .K_DIM                (SA_ROWS)
    ) Systolic_array (
        .clk                (clk),
        .rst                (rst),
        .start              (sa_start_w),
        .weightInputRow     (weightInputRow),
        .activationInputCol (activationInputCol),
        .MatrixMulOut       (MatrixMulOut),
        .load_done          (sa_load_done_w),
        .done               (sa_done_w),
        .busy               (sa_busy_w)
    );


// =============================================================================
// PSB block — instr FIFO, dispatch, and 16x16 INT32 partial-sum buffer.
// =============================================================================

    logic [123:0] psb_dout;
    logic         psb_empty, psb_rd_en;
    logic         psb_acc_w, psb_flush_w, psb_row_valid_w;
    logic         psb_acc_done_w, psb_flush_done_w;
    logic         psb_busy_w;

    // Phase 4 will consume these; surfaced here for clarity.
    logic [SA_COLS*ACCUM_WIDTH-1:0]   requant_row_out_w;
    logic [$clog2(SA_ROWS)-1:0]       psb_row_index_w;
    logic                             psb_row_out_valid_w;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (32)
    ) PSB_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[2]),
        .rd_en  (psb_rd_en),
        .din    (disp_payload),
        .dout   (psb_dout),
        .full   (disp_full[2]),
        .empty  (psb_empty)
    );

    Dispatch_PSB u_dispatch_psb (
        .clk            (clk),
        .rst            (rst),
        .fifo_dout      (psb_dout),
        .fifo_empty     (psb_empty),
        .fifo_rd_en     (psb_rd_en),
        .psb_busy       (psb_busy_w),
        .psb_acc_done   (psb_acc_done_w),
        .psb_flush_done (psb_flush_done_w),
        .psb_acc        (psb_acc_w),
        .psb_flush      (psb_flush_w),
        .row_valid      (psb_row_valid_w),
        .unit_done      (psb_done_pulse)
    );

    psb #(
        .ACCUMULATOR_BITWIDTH (ACCUM_WIDTH),
        .ARRAY_HEIGHT         (SA_ROWS),
        .ARRAY_LENGTH         (SA_COLS)
    ) partial_sum_buffer (
        .clk             (clk),
        .rst             (rst),
        .psb_acc         (psb_acc_w),
        .psb_flush       (psb_flush_w),
        .row_valid       (psb_row_valid_w),
        .sa_row_in       (MatrixMulOut),
        .requant_row_out (requant_row_out_w),
        .row_index_out   (psb_row_index_w),
        .row_out_valid   (psb_row_out_valid_w),
        .acc_done        (psb_acc_done_w),
        .flush_done      (psb_flush_done_w),
        .busy            (psb_busy_w)
    );


// =============================================================================
// Requant block — instr FIFO, dispatch, and INT32→INT8 requant pipeline.
// =============================================================================

    localparam int ReqLanes      = 64;
    localparam int ReqChCount    = 4;
    localparam int ReqM0Width    = COEFF_M_WIDTH;
    localparam int ReqShiftWidth = 8;

    logic [123:0]                          req_dout;
    logic                                  req_empty, req_rd_en;
    logic [1:0]                            req_mode_w;
    logic [ReqChCount*ReqM0Width-1:0]      req_m0_a_w;
    logic [ReqChCount*ReqShiftWidth-1:0]   req_n_a_w;
    logic [ReqChCount*32-1:0]              req_bias_w;
    logic [ReqLanes*8-1:0]                 req_data_o_w;
    logic                                  req_valid_o_w;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (8)
    ) REQUANT_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[3]),
        .rd_en  (req_rd_en),
        .din    (disp_payload),
        .dout   (req_dout),
        .full   (disp_full[3]),
        .empty  (req_empty)
    );

    Dispatch_REQ #(
        .ChCount    (ReqChCount),
        .M0Width    (ReqM0Width),
        .ShiftWidth (ReqShiftWidth)
    ) u_dispatch_req (
        .clk             (clk),
        .rst             (rst),
        .fifo_dout       (req_dout),
        .fifo_empty      (req_empty),
        .fifo_rd_en      (req_rd_en),
        .req_valid_o     (req_valid_o_w),
        .req_data_o_lo   (req_data_o_w[127:0]),
        .req_coeff_rdata (req_coeff_rdata_w),
        .req_mode        (req_mode_w),
        .req_coeff_raddr (req_coeff_raddr_w),
        .req_m0_a        (req_m0_a_w),
        .req_n_a         (req_n_a_w),
        .req_bias        (req_bias_w),
        .vpu_out_waddr   (req_vpu_out_waddr_w),
        .vpu_out_wdata   (req_vpu_out_wdata_w),
        .vpu_out_wen     (req_vpu_out_wen_w),
        .unit_done       (req_done_pulse)
    );

    RequantPipeline #(
        .Lanes      (ReqLanes),
        .ChCount    (ReqChCount),
        .M0Width    (ReqM0Width),
        .ShiftWidth (ReqShiftWidth)
    ) requantization_pipeline (
        .clk             (clk),
        .rst             (rst),
        .mode_i          (req_mode_w),
        .psb_row_i       (requant_row_out_w),
        .psb_row_valid_i (psb_row_out_valid_w),
        .sram_a_i        ('0),
        .sram_a_valid_i  (1'b0),
        .sram_b_i        ('0),
        .bias_i          (req_bias_w),
        .m0_a_i          (req_m0_a_w),
        .n_a_i           (req_n_a_w),
        .m0_b_i          ('0),
        .n_b_i           ('0),
        .data_o          (req_data_o_w),
        .valid_o         (req_valid_o_w)
    );


// =============================================================================
// VPU block — instr FIFO, dispatch, and vector processing unit.
// LANES kept at 16 (matches Output Bank 128-bit word). v2.1 spec targets 64
// lanes — bumping requires multi-word SRAM gather/scatter; deferred.
// =============================================================================

    localparam int VpuLanesPhase5 = 16;

    logic [123:0]                    vpu_dout;
    logic                            vpu_empty, vpu_rd_en;
    logic                            vpu_enable_w;
    logic [7:0]                      vpu_opcode_w;
    logic                            vpu_reduce_max_w;
    logic                            vpu_valid_opcode_w;
    logic [VpuLanesPhase5*8-1:0]     vpu_in_a_w;
    logic [VpuLanesPhase5*8-1:0]     vpu_in_b_w;
    logic [VpuLanesPhase5*8-1:0]     vpu_out_w_bus;
    logic                            lut_bypass_en_w;

    FIFO #(
        .USE_XILINX_XPM (FIFO_USE_XPM),
        .DATA_WIDTH     (124),
        .DEPTH          (16)
    ) VPU_instr_fifo (
        .clk    (clk),
        .rst    (rst),
        .wr_en  (disp_push[4]),
        .rd_en  (vpu_rd_en),
        .din    (disp_payload),
        .dout   (vpu_dout),
        .full   (disp_full[4]),
        .empty  (vpu_empty)
    );

    Dispatch_VPU #(
        .Lanes (VpuLanesPhase5)
    ) u_dispatch_vpu (
        .clk              (clk),
        .rst              (rst),
        .fifo_dout        (vpu_dout),
        .fifo_empty       (vpu_empty),
        .fifo_rd_en       (vpu_rd_en),
        .vpu_valid_opcode (vpu_valid_opcode_w),
        .vpu_out          (vpu_out_w_bus),
        .vpu_hred_rdata   (vpu_hred_rdata_w),
        .vpu_res_rdata    (vpu_res_rdata_w),
        .cfg_tile_M       (cfg_tile_M),
        .cfg_tile_N       (cfg_tile_N),
        .vpu_enable       (vpu_enable_w),
        .vpu_opcode       (vpu_opcode_w),
        .vpu_reduce_max   (vpu_reduce_max_w),
        .vpu_in_a         (vpu_in_a_w),
        .vpu_in_b         (vpu_in_b_w),
        .vpu_hred_raddr   (vpu_hred_raddr_w),
        .vpu_res_raddr    (vpu_res_raddr_w),
        .out_rd_sel       (vpu_out_rd_sel_w),
        .vpu_out_waddr    (vpu_vpu_out_waddr_w),
        .vpu_out_wdata    (vpu_vpu_out_wdata_w),
        .vpu_out_wen      (vpu_vpu_out_wen_w),
        .lut_bypass_en    (lut_bypass_en_w),
        .vpu_lut_sel      (vpu_lut_sel_w),
        .unit_done        (vpu_done_pulse)
    );

    vpu #(
        .LANES (VpuLanesPhase5)
    ) vector_processing_unit (
        .clk          (clk),
        .rst          (rst),
        .enable       (vpu_enable_w),
        .opcode       (vpu_opcode_w),
        .reduce_max   (vpu_reduce_max_w),
        .in_a         (vpu_in_a_w),
        .in_b         (vpu_in_b_w),
        .data_h_edge  (8'h0),
        .out          (vpu_out_w_bus),
        .valid_opcode (vpu_valid_opcode_w)
    );

endmodule
