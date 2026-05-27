// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// DMA dispatcher: Ch0 FSM pops npu_dma_desc_t and gates on SA/VPU dep before pulsing DMA start; Ch1 FSM pops npu_wt_load_payload_t and pulses DMA Ch1 start (no dep gating).
// Inputs:
//     - clk: System clock
//     - rst: Active-high sync reset
//     - ch0_dout: Ch0 FIFO 124-bit instruction word {opcode[7:0], dep_flags[3:0], payload[111:0]}
//     - ch0_empty: Ch0 FIFO empty flag
//     - ch1_dout: Ch1 FIFO 124-bit WT_LOAD instruction word
//     - ch1_empty: Ch1 FIFO empty flag
//     - dma_ch1_idle: DMA Ch1 WT_LOAD FSM idle; signals operation complete
//     - dma_ch0_idle: DMA Ch0 (LOAD+STORE) FSMs idle; signals operation complete
//     - dep_sa_to_dma_empty: SA->DMA DepFIFO empty; gates LOAD/UPSAMPLE/CONCAT issue
//     - dep_vpu_to_dma_empty: VPU->DMA DepFIFO empty; gates STORE issue
// Outputs:
//     - ch0_rd_en: Ch0 FIFO pop strobe, 1-cycle pulse in S_IDLE
//     - ch1_rd_en: Ch1 FIFO pop strobe, 1-cycle pulse in SS1_IDLE
//     - wt_src_base: DDR source addr for Ch1 WT_LOAD weight subblock
//     - ch1_start: 1-cycle pulse to launch DMA Ch1 with latched wt_src_base
//     - desc_src_base: DDR source addr (LOAD modes) or dest addr (STORE) for DMA
//     - desc_row_stride: Bytes between row starts in DDR
//     - desc_tile_w: Tile width in pixels
//     - desc_tile_h: Tile height in pixels
//     - desc_ch_count: Channels per pixel (multiple of 16)
//     - desc_pad_top: Top zero-pad rows
//     - desc_pad_bot: Bottom zero-pad rows
//     - desc_pad_left: Left zero-pad columns
//     - desc_pad_right: Right zero-pad columns
//     - desc_fetch_mode: DMA mode 000=LOAD 001=UP 010=CONCAT 011=STORE 100=COEFF 101=LUT
//     - desc_concat_base: CONCAT second-source DDR base from npu_concat_payload_t
//     - desc_coeff_ch_count: OP_COEFF_LOAD channel count from npu_coeff_load_payload_t
//     - desc_lut_sel: OP_LUT_LOAD ping-pong slot select from npu_lut_load_payload_t
//     - desc_start: 1-cycle pulse to launch DMA Ch0 with latched descriptor
//     - dep_sa_to_dma_pop: SA->DMA DepFIFO pop, asserted with desc_start on LOAD
//     - dep_vpu_to_dma_pop: VPU->DMA DepFIFO pop, asserted with desc_start on STORE

import NPU_ISA_pkg::*;

module Dispatch_DMA (
    input  logic         clk,
    input  logic         rst,

    // -------------------------------------------------------------------------
    // Ch0 FIFO (LOAD/STORE/UPSAMPLE/CONCAT/COEFF_LOAD)
    // -------------------------------------------------------------------------
    input  logic [123:0] ch0_dout,
    input  logic         ch0_empty,
    output logic         ch0_rd_en,

    // -------------------------------------------------------------------------
    // Ch1 FIFO (WT_LOAD)
    // -------------------------------------------------------------------------
    input  logic [123:0] ch1_dout,
    input  logic         ch1_empty,
    output logic         ch1_rd_en,

    // -------------------------------------------------------------------------
    // Ch1 descriptor → DMA.sv. Latched in SS1_POP; held across SS1_WAIT_DMA.
    // -------------------------------------------------------------------------
    output logic [31:0] wt_src_base,
    output logic        ch1_start,
    input  logic        dma_ch1_idle,

    // -------------------------------------------------------------------------
    // Descriptor → DMA.sv (Ch0). Latched in S_POP; held stable across S_WAIT_DMA.
    // -------------------------------------------------------------------------
    output logic [31:0] desc_src_base,
    output logic [15:0] desc_row_stride,
    output logic [7:0]  desc_tile_w,
    output logic [7:0]  desc_tile_h,
    output logic [7:0]  desc_ch_count,
    output logic [3:0]  desc_pad_top,
    output logic [3:0]  desc_pad_bot,
    output logic [3:0]  desc_pad_left,
    output logic [3:0]  desc_pad_right,
    output logic [2:0]  desc_fetch_mode,
    output logic [31:0] desc_concat_base,
    output logic [9:0]  desc_coeff_ch_count,
    output logic        desc_lut_sel,
    output logic        desc_start,

    // -------------------------------------------------------------------------
    // DMA Ch0 feedback
    // -------------------------------------------------------------------------
    input  logic        dma_ch0_idle,

    // -------------------------------------------------------------------------
    // Dep tokens (Ch0 consumer side): gate LOAD on SA→DMA, STORE on VPU→DMA.
    // -------------------------------------------------------------------------
    input  logic        dep_sa_to_dma_empty,
    output logic        dep_sa_to_dma_pop,
    input  logic        dep_vpu_to_dma_empty,
    output logic        dep_vpu_to_dma_pop
);

    // =========================================================================
    // Ch0 FSM
    // =========================================================================
    typedef enum logic [2:0] {
        S_IDLE,      // wait for ~ch0_empty; assert ch0_rd_en
        S_POP,       // 1-cycle latency: ch0_dout now valid; latch desc + opcode
        S_WAIT_DEP,  // stall until producer dep token available (LOAD/STORE only)
        S_START,     // pulse desc_start; pop dep token
        S_WAIT_DMA   // wait for dma_ch0_idle
    } ch0_state_e;
    ch0_state_e ch0_state;

    logic [7:0] r_opcode;

    // Required-dep flags derived from latched opcode.
    logic need_dep_sa;   // LOAD/UPSAMPLE/CONCAT consume act-bank-ready
    logic need_dep_vpu;  // STORE consumes out-bank-ready
    assign need_dep_sa  = (r_opcode == OP_DMA_LOAD) ||
                          (r_opcode == OP_UPSAMPLE) ||
                          (r_opcode == OP_CONCAT);
    assign need_dep_vpu = (r_opcode == OP_DMA_STORE);

    always_ff @(posedge clk) begin
        if (rst) begin
            ch0_state         <= S_IDLE;
            ch0_rd_en         <= 1'b0;
            desc_start        <= 1'b0;
            dep_sa_to_dma_pop <= 1'b0;
            dep_vpu_to_dma_pop<= 1'b0;
            r_opcode          <= 8'h0;
            desc_src_base     <= 32'h0;
            desc_row_stride   <= 16'h0;
            desc_tile_w       <= 8'h0;
            desc_tile_h       <= 8'h0;
            desc_ch_count     <= 8'h0;
            desc_pad_top      <= 4'h0;
            desc_pad_bot      <= 4'h0;
            desc_pad_left     <= 4'h0;
            desc_pad_right    <= 4'h0;
            desc_fetch_mode      <= 3'b000;
            desc_concat_base     <= 32'h0;
            desc_coeff_ch_count  <= 10'h0;
            desc_lut_sel         <= 1'b0;
        end else begin
            ch0_rd_en          <= 1'b0;
            desc_start         <= 1'b0;
            dep_sa_to_dma_pop  <= 1'b0;
            dep_vpu_to_dma_pop <= 1'b0;

            unique case (ch0_state)

                S_IDLE: begin
                    if (!ch0_empty) begin
                        ch0_rd_en <= 1'b1;
                        ch0_state <= S_POP;
                    end
                end

                // FIFO has 1-cycle read latency; ch0_dout valid this cycle.
                // payload[31:0] is the DDR base for all six Ch0 opcodes
                // (npu_dma_desc_t, npu_coeff_load_payload_t, npu_lut_load_payload_t
                // all share that field), so desc_src_base latch is opcode-agnostic.
                S_POP: begin
                    r_opcode         <= ch0_dout[123:116];
                    desc_src_base    <= ch0_dout[31:0];
                    // npu_dma_desc_t fields (don't-care for COEFF / LUT modes).
                    desc_row_stride  <= ch0_dout[47:32];
                    desc_tile_w      <= ch0_dout[55:48];
                    desc_tile_h      <= ch0_dout[63:56];
                    desc_ch_count    <= ch0_dout[71:64];
                    desc_pad_top     <= ch0_dout[75:72];
                    desc_pad_bot     <= ch0_dout[79:76];
                    desc_pad_left    <= ch0_dout[83:80];
                    desc_pad_right   <= ch0_dout[87:84];
                    // npu_concat_payload_t: base_addr_b[23:0] in payload[111:88];
                    // base_addr_b[31:24] shares base_addr_a[31:24] (same 256 MB region).
                    desc_concat_base <= {ch0_dout[31:24], ch0_dout[111:88]};
                    // npu_coeff_load_payload_t: ch_count in [41:32].
                    desc_coeff_ch_count <= ch0_dout[41:32];
                    // npu_lut_load_payload_t: lut_sel in [32].
                    desc_lut_sel        <= ch0_dout[32];
                    unique case (ch0_dout[123:116])
                        OP_DMA_LOAD:   desc_fetch_mode <= 3'b000;
                        OP_UPSAMPLE:   desc_fetch_mode <= 3'b001;
                        OP_CONCAT:     desc_fetch_mode <= 3'b010;
                        OP_DMA_STORE:  desc_fetch_mode <= 3'b011;
                        OP_COEFF_LOAD: desc_fetch_mode <= 3'b100;
                        OP_LUT_LOAD:   desc_fetch_mode <= 3'b101;
                        default:       desc_fetch_mode <= 3'b000;
                    endcase
                    ch0_state <= S_WAIT_DEP;
                end

                S_WAIT_DEP: begin
                    // COEFF_LOAD and LUT_LOAD have no dep gating — fall through.
                    if (need_dep_sa) begin
                        if (!dep_sa_to_dma_empty) ch0_state <= S_START;
                    end else if (need_dep_vpu) begin
                        if (!dep_vpu_to_dma_empty) ch0_state <= S_START;
                    end else begin
                        ch0_state <= S_START;  // no dep gating
                    end
                end

                S_START: begin
                    desc_start <= 1'b1;
                    if (need_dep_sa)  dep_sa_to_dma_pop  <= 1'b1;
                    if (need_dep_vpu) dep_vpu_to_dma_pop <= 1'b1;
                    ch0_state <= S_WAIT_DMA;
                end

                // dma_ch0_idle drops 1 cycle after start sampled; wait for re-assert.
                S_WAIT_DMA: begin
                    if (dma_ch0_idle && !desc_start) ch0_state <= S_IDLE;
                end

                default: ch0_state <= S_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Ch1 (WT_LOAD) FSM — single-opcode channel; no dep gating (weights
    // prefetch concurrently with SA matmul).
    // =========================================================================
    typedef enum logic [1:0] {
        SS1_IDLE,
        SS1_POP,
        SS1_START,
        SS1_WAIT_DMA
    } ch1_state_e;
    ch1_state_e ch1_state;

    always_ff @(posedge clk) begin
        if (rst) begin
            ch1_state   <= SS1_IDLE;
            ch1_rd_en   <= 1'b0;
            ch1_start   <= 1'b0;
            wt_src_base <= 32'h0;
        end else begin
            ch1_rd_en <= 1'b0;
            ch1_start <= 1'b0;

            unique case (ch1_state)

                SS1_IDLE: begin
                    if (!ch1_empty) begin
                        ch1_rd_en <= 1'b1;
                        ch1_state <= SS1_POP;
                    end
                end

                // npu_wt_load_payload_t: wt_base_addr in payload[31:0].
                SS1_POP: begin
                    wt_src_base <= ch1_dout[31:0];
                    ch1_state   <= SS1_START;
                end

                SS1_START: begin
                    ch1_start <= 1'b1;
                    ch1_state <= SS1_WAIT_DMA;
                end

                // Guard against same-cycle exit before DMA samples ch1_start.
                SS1_WAIT_DMA: begin
                    if (dma_ch1_idle && !ch1_start) ch1_state <= SS1_IDLE;
                end

                default: ch1_state <= SS1_IDLE;
            endcase
        end
    end

endmodule
