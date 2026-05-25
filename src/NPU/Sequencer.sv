// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// AXI4-read instruction fetch sequencer: bursts 128-bit instructions from DDR4,
// decodes opcode/unit_id, dispatches {dep_flags, payload} to one of 6 per-unit
// FIFOs, and handles CONFIG shadow-register updates and FENCE barriers internally.
// Parameters:
//     - INSTR_WIDTH: Instruction width in bits
//     - OPCODE_MSB/OPCODE_LSB: Bit range of opcode field [127:120]
//     - UNIT_ID_MSB/UNIT_ID_LSB: Bit range of unit_id field [119:116]
//     - DEP_FLAGS_MSB/DEP_FLAGS_LSB: Bit range of dependency-flags field [115:112]
//     - PAYLOAD_MSB/PAYLOAD_LSB: Bit range of payload field [111:0]
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - s_axil_awaddr: AXI-Lite write address; [3:2] selects CSR register
//     - s_axil_awvalid: AXI-Lite write-address valid
//     - s_axil_wdata: AXI-Lite write data (instr_base / instr_count / kick)
//     - s_axil_wvalid: AXI-Lite write-data valid
//     - s_axil_bready: AXI-Lite B-channel ready (host accepts write response)
//     - m_axi_arready: AXI4 AR ready (memory accepts fetch address)
//     - m_axi_rdata: AXI4 R data (one 32-bit beat of the instruction)
//     - m_axi_rvalid: AXI4 R valid
//     - m_axi_rlast: AXI4 last-beat indicator
//     - m_axi_rresp: AXI4 read response; non-OKAY sets fetch_err and aborts
//     - fifo_full: One-hot full flags from 6 per-unit dispatch FIFOs
//     - unit_done: One-hot completion flags per unit; sampled by FENCE logic
// Outputs:
//     - s_axil_awready: AXI-Lite write-address ready
//     - s_axil_wready: AXI-Lite write-data ready
//     - s_axil_bresp: AXI-Lite write response (always OKAY / 2'b00)
//     - s_axil_bvalid: AXI-Lite write response valid
//     - m_axi_araddr: 44-bit DDR4 byte address for next instruction fetch
//     - m_axi_arvalid: AXI4 AR valid
//     - m_axi_arlen: AXI4 burst length (fixed 8'd3 = 4 beats)
//     - m_axi_arsize: AXI4 beat size (fixed 3'b010 = 32-bit)
//     - m_axi_arburst: AXI4 burst type (fixed 2'b01 = INCR)
//     - m_axi_rready: AXI4 R ready; asserted only while FSM is in S_R state
//     - fifo_payload: 116-bit dispatch word {dep_flags[3:0], payload[111:0]}
//     - fifo_push: One-hot 1-cycle strobe selecting target per-unit FIFO
//     - cfg_tile_M: Tile M dimension latched from last OP_CONFIG instruction
//     - cfg_tile_N: Tile N dimension latched from last OP_CONFIG instruction
//     - cfg_tile_K: Tile K (depth) dimension latched from last OP_CONFIG
//     - cfg_stride: Convolution stride latched from last OP_CONFIG
//     - cfg_pad_mode: Padding mode latched from last OP_CONFIG
//     - cfg_coeff_base: DDR4 requant-coefficient base address from last OP_CONFIG
//     - cfg_act_type: Activation function selector from last OP_CONFIG
//     - cfg_pool_size: Pooling kernel size from last OP_CONFIG
//     - irq_done: 1-cycle pulse when program finishes and unit_done[1] (DMA) asserts
//     - fetch_err: Sticky flag; set when any AXI4 read response is non-OKAY

import NPU_ISA_pkg::*;

module Sequencer #(
    parameter int INSTR_WIDTH    = 128,

    parameter int OPCODE_MSB     = 127,
    parameter int OPCODE_LSB     = 120,

    parameter int UNIT_ID_MSB    = 119,
    parameter int UNIT_ID_LSB    = 116,

    parameter int DEP_FLAGS_MSB  = 115,
    parameter int DEP_FLAGS_LSB  = 112,

    parameter int PAYLOAD_MSB    = 111,
    parameter int PAYLOAD_LSB    = 0
) (
    input  logic clk,
    input  logic rst,

    // AXI-Lite slave
    input  logic [31:0] s_axil_awaddr,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,

    input  logic [31:0] s_axil_wdata,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,

    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,

    // AXI4 master
    output logic [43:0] m_axi_araddr,
    output logic        m_axi_arvalid,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    input  logic        m_axi_arready,

    input  logic [31:0] m_axi_rdata,
    input  logic        m_axi_rvalid,
    input  logic        m_axi_rlast,
    input  logic [1:0]  m_axi_rresp,
    output logic        m_axi_rready,

    // Dispatch
    output logic [115:0] fifo_payload,
    output logic [5:0]   fifo_push,
    input  logic [5:0]   fifo_full,

    // FENCE
    // bit: 0=SEQ 1=DMA 2=SA 3=PSB 4=REQ 5=VPU
    input  logic [5:0]  unit_done,

    // CONFIG outputs — hold from OP_CONFIG until next CONFIG
    output logic [7:0]  cfg_tile_M,
    output logic [7:0]  cfg_tile_N,
    output logic [7:0]  cfg_tile_K,
    output logic [3:0]  cfg_stride,
    output logic [1:0]  cfg_pad_mode,
    output logic [31:0] cfg_coeff_base,
    output logic [2:0]  cfg_act_type,
    output logic [2:0]  cfg_pool_size,

    // Status
    output logic        irq_done,
    output logic        fetch_err
);

    // AXI-Lite slave
    logic [43:0] reg_instr_base;
    logic [31:0] reg_instr_count;

    logic        aw_pend;  // AW handshake latched, waiting for W
    logic [1:0]  aw_sel;   // registered awaddr[3:2]
    logic        w_pend;   // W handshake latched, waiting for AW
    logic [31:0] w_lat;    // registered wdata
    logic        bvalid_r; // B response in flight
    logic        kick;     // 1-cycle strobe: launches fetch FSM

    // Block new transactions until current B response is consumed
    assign s_axil_awready = ~aw_pend & ~bvalid_r;
    assign s_axil_wready  = ~w_pend  & ~bvalid_r;
    assign s_axil_bvalid  = bvalid_r;
    assign s_axil_bresp   = 2'b00;  // OKAY

    always_ff @(posedge clk) begin
        if (rst) begin
            aw_pend <= 1'b0;
            aw_sel  <= 2'b0;
        end else if (s_axil_awvalid && s_axil_awready) begin
            aw_pend <= 1'b1;
            aw_sel  <= s_axil_awaddr[3:2];
        end else if (aw_pend && w_pend && ~bvalid_r) begin
            aw_pend <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            w_pend <= 1'b0;
            w_lat  <= '0;
        end else if (s_axil_wvalid && s_axil_wready) begin
            w_pend <= 1'b1;
            w_lat  <= s_axil_wdata;
        end else if (aw_pend && w_pend && ~bvalid_r) begin
            w_pend <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_instr_base  <= '0;
            reg_instr_count <= '0;
            bvalid_r        <= 1'b0;
            kick            <= 1'b0;
        end else begin
            kick <= 1'b0;
            if (aw_pend && w_pend && ~bvalid_r) begin
                unique case (aw_sel)
                    2'b00:   reg_instr_base  <= {12'b0, w_lat};
                    2'b01:   reg_instr_count <= w_lat;
                    2'b10:   kick            <= w_lat[0];
                    default: ;
                endcase
                bvalid_r <= 1'b1;
            end else if (bvalid_r && s_axil_bready) begin
                bvalid_r <= 1'b0;
            end
        end
    end

    // Decode
    logic [127:0] instr_buf;

    npu_opcode_e        dec_opcode;
    npu_unit_e          dec_unit;
    logic [3:0]         dec_dep;
    logic [111:0]       dec_payload;
    npu_cfg_payload_t   cfg_dec;
    npu_fence_payload_t fence_dec;

    assign dec_opcode  = npu_opcode_e'(instr_buf[OPCODE_MSB   : OPCODE_LSB ]);
    assign dec_unit    = npu_unit_e'  (instr_buf[UNIT_ID_MSB  : UNIT_ID_LSB]);
    assign dec_dep     =               instr_buf[DEP_FLAGS_MSB : DEP_FLAGS_LSB];
    assign dec_payload =               instr_buf[PAYLOAD_MSB   : PAYLOAD_LSB ];
    assign cfg_dec     = npu_cfg_payload_t'(dec_payload);
    assign fence_dec   = npu_fence_payload_t'(dec_payload);

    // Map unit_id (+ opcode for DMA) to one-hot FIFO bit [5:0]
    logic [5:0] target_bit;
    logic       dispatch_stall;

    always_comb begin
        unique case (dec_unit)
            UNIT_DMA: begin
                if (dec_opcode == OP_WT_LOAD)
                    target_bit = 6'b10_0000;  // bit5 -> Ch1 FIFO (WT_LOAD)
                else
                    target_bit = 6'b00_0001;  // bit0 -> Ch0 FIFO
            end
            UNIT_SA:  target_bit = 6'b00_0010;
            UNIT_PSB: target_bit = 6'b00_0100;
            UNIT_REQ: target_bit = 6'b00_1000;
            UNIT_VPU: target_bit = 6'b01_0000;
            default:  target_bit = 6'b00_0000;
        endcase
    end

    assign dispatch_stall = (dec_unit != UNIT_SEQ) && |(fifo_full & target_bit);

    // Fetch FSM
    typedef enum logic [2:0] {
        S_IDLE,
        S_AR,
        S_R,
        S_DISPATCH,
        S_FENCE
    } seq_state_e;

    seq_state_e  state;
    logic [43:0] fetch_ptr;
    logic [31:0] fetch_remaining;
    logic [1:0]  beat_cnt;
    logic [5:0]  fence_mask;
    logic        job_active;

    // Fixed AXI4 burst parameters
    assign m_axi_arlen   = 8'd3;    // 4-beat burst (128-bit instruction)
    assign m_axi_arsize  = 3'b010;  // 32-bit per beat
    assign m_axi_arburst = 2'b01;   // INCR
    assign m_axi_rready  = (state == S_R);

    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= S_IDLE;
            fetch_ptr       <= '0;
            fetch_remaining <= '0;
            beat_cnt        <= 2'd0;
            instr_buf       <= '0;
            m_axi_araddr    <= '0;
            m_axi_arvalid   <= 1'b0;
            fifo_payload    <= '0;
            fifo_push       <= 6'b0;
            fence_mask      <= '0;
            cfg_tile_M      <= '0;
            cfg_tile_N      <= '0;
            cfg_tile_K      <= '0;
            cfg_stride      <= '0;
            cfg_pad_mode    <= '0;
            cfg_act_type    <= '0;
            cfg_pool_size   <= '0;
            cfg_coeff_base  <= '0;
            irq_done        <= 1'b0;
            fetch_err       <= 1'b0;
            job_active      <= 1'b0;
        end else begin
            fifo_push <= 6'b0;
            irq_done  <= 1'b0;
            if (kick) job_active <= 1'b1;
            else if (job_active && (state == S_IDLE) && unit_done[1]) begin
                irq_done   <= 1'b1;
                job_active <= 1'b0;
            end

            unique case (state)

                S_IDLE: begin
                    if (kick) begin
                        fetch_ptr       <= reg_instr_base;
                        fetch_remaining <= reg_instr_count;
                        state           <= S_AR;
                    end
                end

                // Present fetch address; wait for DDR4 AR handshake
                S_AR: begin
                    if (fetch_remaining == '0) begin
                        state <= S_IDLE;
                    end else if (!m_axi_arvalid) begin
                        m_axi_araddr  <= fetch_ptr;
                        m_axi_arvalid <= 1'b1;
                    end else if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        beat_cnt      <= 2'd0;
                        state         <= S_R;
                    end
                end

                // Collect 4 × 32-bit beats into instr_buf, LSB-first
                S_R: begin
                    if (m_axi_rvalid) begin
                        instr_buf[beat_cnt * 32 +: 32] <= m_axi_rdata;
                        if (|m_axi_rresp) fetch_err <= 1'b1;
                        if (m_axi_rlast) begin
                            state <= |m_axi_rresp ? S_IDLE : S_DISPATCH;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                        end
                    end
                end

                // Decode complete instruction; dispatch or handle internally
                S_DISPATCH: begin
                    unique case (dec_opcode)

                        OP_CONFIG: begin
                            cfg_tile_M     <= cfg_dec.tile_M;
                            cfg_tile_N     <= cfg_dec.tile_N;
                            cfg_tile_K     <= cfg_dec.tile_K;
                            cfg_stride     <= cfg_dec.stride;
                            cfg_pad_mode   <= cfg_dec.pad_mode;
                            cfg_act_type   <= cfg_dec.act_type;
                            cfg_pool_size  <= cfg_dec.pool_size;
                            cfg_coeff_base <= cfg_dec.coeff_base;
                            fetch_ptr       <= fetch_ptr + 44'd16;
                            fetch_remaining <= fetch_remaining - 1'b1;
                            state           <= S_AR;
                        end

                        OP_FENCE: begin
                            fence_mask <= fence_dec.unit_mask;
                            state      <= S_FENCE;
                        end

                        default: begin
                            // All unit instructions — global stall if target FIFO full
                            if (!dispatch_stall) begin
                                fifo_payload    <= {dec_dep, dec_payload};
                                fifo_push       <= target_bit;
                                fetch_ptr       <= fetch_ptr + 44'd16;
                                fetch_remaining <= fetch_remaining - 1'b1;
                                state           <= S_AR;
                            end
                        end

                    endcase
                end

                // Wait until all fenced units report done
                S_FENCE: begin
                    if ((unit_done & fence_mask) == fence_mask) begin
                        fetch_ptr       <= fetch_ptr + 44'd16;
                        fetch_remaining <= fetch_remaining - 1'b1;
                        state           <= S_AR;
                    end
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
