// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// VPU dispatch. Pops VPU instructions and steers them through a 3-stage
// per-word pipeline (READ -> COMPUTE -> WRITE) that gathers operands from
// SRAMHub (Output Bank ± Residual Bank), feeds vpu, and scatters results
// back to the Output Bank.
//
// NPU ISA opcode -> vpu internal opcode translation:
//   OP_ELEW_ADD  0x35 -> VADD   0x20  (out = out_bank + res_bank)
//   OP_ELEW_MUL  0x36 -> VMUL   0x22  (out = out_bank * res_bank)
//   OP_RELU      0x34 -> VMAX   0x23  with in_b = 0
//   OP_MAXPOOL   0x37 -> VMAX   0x23  (single-window first pass; multi-window
//                                       windowing TODO — driver issues N ops)
//   OP_HREDUCE   0x38 -> REDUCE 0x40  (reduce_max = 0 for sum tree)
//   OP_SIMD_ACT  0x33 -> HOLD   0x52  STUB (vpu.sv lacks LUT support)
//   OP_LUT_LOAD  0x31         STUB (DMA datapath deferred)
//   OP_LUT_BYPASS 0x32        latched bypass_en flag
//
// All operand SRAM transactions are 128-bit words (= 16 INT8 lanes). The vpu
// LANES parameter is 16 in this build to match the Output Bank word width;
// the v2.1 spec calls for 64 lanes — flagged as an open item.
// Inputs:
//     - clk, rst: clock and active-high synchronous reset
//     - fifo_dout: 124-bit {opcode, dep_flags, payload} from VPU instr FIFO
//     - fifo_empty: VPU instr FIFO empty flag
//     - vpu_valid_opcode: vpu.valid_opcode (1 when current vpu opcode is supported)
//     - vpu_out: 128-bit packed vpu output (16 lanes x 8 bits)
//     - vpu_hred_rdata: 128-bit Output Bank read data
//     - vpu_res_rdata: 128-bit Residual Bank read data
//     - cfg_tile_M, cfg_tile_N: tile dims from Sequencer CSR
// Outputs:
//     - fifo_rd_en: pop strobe for VPU instr FIFO
//     - vpu_enable: drives vpu.enable (high during compute cycle)
//     - vpu_opcode: 8-bit vpu opcode (translated from ISA)
//     - vpu_reduce_max: drives vpu.reduce_max (0 = sum tree for HREDUCE)
//     - vpu_in_a, vpu_in_b: packed 128-bit operand buses to vpu
//     - vpu_hred_raddr: Output Bank read addr (active when vpu_rd_active=1)
//     - vpu_res_raddr: Residual Bank read addr
//     - out_rd_sel: 1 while VPU is reading the Output Bank (SRAMHub mux)
//     - vpu_out_waddr, vpu_out_wdata, vpu_out_wen: write-back to Output Bank
//     - lut_bypass_en: latched OP_LUT_BYPASS flag
//     - vpu_lut_sel: tied to lut_bypass_en for now (0=Act LUT, 1=HREDUCE LUT)
//     - unit_done: 1-cycle pulse when current VPU op retires

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_VPU #(
    parameter int Lanes = 16
)(
    input  logic                                clk,
    input  logic                                rst,

    input  logic [123:0]                        fifo_dout,
    input  logic                                fifo_empty,
    output logic                                fifo_rd_en,

    input  logic                                vpu_valid_opcode,
    input  logic [Lanes*8-1:0]                  vpu_out,
    input  logic [127:0]                        vpu_hred_rdata,
    input  logic [127:0]                        vpu_res_rdata,

    input  logic [7:0]                          cfg_tile_M,
    input  logic [7:0]                          cfg_tile_N,

    output logic                                vpu_enable,
    output logic [7:0]                          vpu_opcode,
    output logic                                vpu_reduce_max,
    output logic [Lanes*8-1:0]                  vpu_in_a,
    output logic [Lanes*8-1:0]                  vpu_in_b,

    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   vpu_hred_raddr,
    output logic [$clog2(RES_BANK_DEPTH)-1:0]   vpu_res_raddr,
    output logic                                out_rd_sel,

    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   vpu_out_waddr,
    output logic [127:0]                        vpu_out_wdata,
    output logic                                vpu_out_wen,

    output logic                                lut_bypass_en,
    output logic                                vpu_lut_sel,

    output logic                                unit_done
);

    // Translated vpu opcodes (mirroring vpu.sv localparams).
    localparam logic [7:0] VOP_VADD   = 8'h20;
    localparam logic [7:0] VOP_VMUL   = 8'h22;
    localparam logic [7:0] VOP_VMAX   = 8'h23;
    localparam logic [7:0] VOP_REDUCE = 8'h40;
    localparam logic [7:0] VOP_HOLD   = 8'h52;

    npu_opcode_e fifo_opcode;
    assign fifo_opcode = npu_opcode_e'(fifo_dout[123:116]);

    typedef enum logic [2:0] {
        S_IDLE,
        S_READ,
        S_COMPUTE,
        S_WRITE,
        S_DONE
    } state_e;

    state_e     state;
    logic [7:0] word_idx;       // 0..target_count-1
    logic [7:0] target_count;   // total 128-bit words to process
    logic [7:0] latched_opcode; // vpu opcode held across the run
    logic       use_residual;   // 1 for ELEW_*; 0 otherwise

    // Approximate work size: one 16x16 output tile = 16 words of 16 lanes.
    // Falls back to 16 when CSR is uninitialised.
    logic [15:0] tile_words_w;
    assign tile_words_w = (cfg_tile_M == 8'h0 || cfg_tile_N == 8'h0)
                              ? 16'd16
                              : (16'(cfg_tile_M) * 16'(cfg_tile_N)) >> 4;

    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= S_IDLE;
            fifo_rd_en      <= 1'b0;
            vpu_enable      <= 1'b0;
            vpu_opcode      <= VOP_HOLD;
            vpu_reduce_max  <= 1'b0;
            vpu_in_a        <= '0;
            vpu_in_b        <= '0;
            vpu_hred_raddr  <= '0;
            vpu_res_raddr   <= '0;
            out_rd_sel      <= 1'b0;
            vpu_out_waddr   <= '0;
            vpu_out_wdata   <= 128'h0;
            vpu_out_wen     <= 1'b0;
            lut_bypass_en   <= 1'b0;
            vpu_lut_sel     <= 1'b0;
            unit_done       <= 1'b0;
            word_idx        <= 8'h0;
            target_count    <= 8'h0;
            latched_opcode  <= VOP_HOLD;
            use_residual    <= 1'b0;
        end else begin
            fifo_rd_en  <= 1'b0;
            vpu_enable  <= 1'b0;
            vpu_out_wen <= 1'b0;
            unit_done   <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    out_rd_sel <= 1'b0;
                    if (!fifo_empty) begin
                        // Dispatch on ISA opcode.
                        unique case (fifo_opcode)
                            OP_ELEW_ADD: begin
                                fifo_rd_en     <= 1'b1;
                                latched_opcode <= VOP_VADD;
                                use_residual   <= 1'b1;
                                target_count   <= 8'(tile_words_w);
                                word_idx       <= 8'h0;
                                vpu_hred_raddr <= '0;
                                vpu_res_raddr  <= '0;
                                vpu_out_waddr  <= '0;
                                state          <= S_READ;
                            end
                            OP_ELEW_MUL: begin
                                fifo_rd_en     <= 1'b1;
                                latched_opcode <= VOP_VMUL;
                                use_residual   <= 1'b1;
                                target_count   <= 8'(tile_words_w);
                                word_idx       <= 8'h0;
                                vpu_hred_raddr <= '0;
                                vpu_res_raddr  <= '0;
                                vpu_out_waddr  <= '0;
                                state          <= S_READ;
                            end
                            OP_RELU: begin
                                fifo_rd_en     <= 1'b1;
                                latched_opcode <= VOP_VMAX;  // max(out, 0)
                                use_residual   <= 1'b0;      // in_b = 0
                                target_count   <= 8'(tile_words_w);
                                word_idx       <= 8'h0;
                                vpu_hred_raddr <= '0;
                                vpu_out_waddr  <= '0;
                                state          <= S_READ;
                            end
                            OP_MAXPOOL: begin
                                // Single-window pass; driver issues multiple
                                // ops for k>1 windows. Multi-cycle windowing
                                // is a Phase 5+ TODO.
                                fifo_rd_en     <= 1'b1;
                                latched_opcode <= VOP_VMAX;
                                use_residual   <= 1'b1;
                                target_count   <= 8'(tile_words_w);
                                word_idx       <= 8'h0;
                                vpu_hred_raddr <= '0;
                                vpu_res_raddr  <= '0;
                                vpu_out_waddr  <= '0;
                                state          <= S_READ;
                            end
                            OP_HREDUCE: begin
                                fifo_rd_en     <= 1'b1;
                                latched_opcode <= VOP_REDUCE;
                                vpu_reduce_max <= 1'b0;
                                use_residual   <= 1'b0;
                                target_count   <= 8'(tile_words_w);
                                word_idx       <= 8'h0;
                                vpu_hred_raddr <= '0;
                                vpu_out_waddr  <= '0;
                                state          <= S_READ;
                            end
                            OP_LUT_BYPASS: begin
                                fifo_rd_en    <= 1'b1;
                                lut_bypass_en <= fifo_dout[0];
                                vpu_lut_sel   <= fifo_dout[0];
                                unit_done     <= 1'b1;
                            end
                            OP_SIMD_ACT, OP_LUT_LOAD: begin
                                // STUBS: pop and acknowledge so Sequencer
                                // FENCEs unblock. Real LUT path needs DMA.
                                fifo_rd_en <= 1'b1;
                                unit_done  <= 1'b1;
                            end
                            default: begin
                                // Drop anything we don't understand.
                                fifo_rd_en <= 1'b1;
                            end
                        endcase
                    end
                end

                // Drive SRAM raddr; capture rdata next cycle into vpu inputs.
                S_READ: begin
                    out_rd_sel     <= 1'b1;
                    vpu_hred_raddr <= word_idx[$clog2(OUT_BANK_DEPTH)-1:0];
                    vpu_res_raddr  <= word_idx[$clog2(RES_BANK_DEPTH)-1:0];
                    state          <= S_COMPUTE;
                end

                // rdata now valid. Feed vpu, pulse enable, advance to write.
                S_COMPUTE: begin
                    vpu_opcode     <= latched_opcode;
                    vpu_in_a       <= vpu_hred_rdata;
                    vpu_in_b       <= use_residual ? vpu_res_rdata : 128'h0;
                    vpu_enable     <= 1'b1;
                    state          <= S_WRITE;
                end

                // vpu.out reflects the new value; store it.
                S_WRITE: begin
                    vpu_out_wdata <= vpu_out;
                    vpu_out_waddr <= word_idx[$clog2(OUT_BANK_DEPTH)-1:0];
                    vpu_out_wen   <= 1'b1;
                    word_idx      <= word_idx + 8'h1;
                    if ((word_idx + 8'h1) == target_count) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_READ;
                    end
                end

                S_DONE: begin
                    unit_done  <= 1'b1;
                    out_rd_sel <= 1'b0;
                    state      <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Surface so unused-input lint stays quiet when vpu opcode never errors.
    logic _unused;
    assign _unused = vpu_valid_opcode;

endmodule
