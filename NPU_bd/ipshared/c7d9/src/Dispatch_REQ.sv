// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-26
// Requant-pipeline dispatch. On OP_REQUANT:
//   1. Read ChCount per-channel (M0, n) pairs from SRAMHub.coeff BRAM into
//      shadow registers feeding RequantPipeline.{m0_a_i, n_a_i}. Default
//      ChCount = 1: one coeff per REQUANT op drives all 16 lanes.
//   2. Drive mode_i = 2'b01 (FROM_PSB) and hold it until ch_count output beats
//      have streamed through RequantPipeline.valid_o.
//   3. Each valid_o beat writes the full 128-bit data_o (16 INT8 lanes,
//      matching one PSB row) into SRAMHub.vpu_out_w*.
//   4. After ch_count beats, pulse unit_done back to the Sequencer.
// psb_row_valid_i is driven externally by psb.row_out_valid during a parallel
// PSB_FLUSH; this dispatch only configures the pipeline.
// Inputs:
//     - clk, rst: Clock and active-high synchronous reset
//     - fifo_dout: 124-bit {opcode, dep_flags, payload} from REQUANT instr FIFO
//     - fifo_empty: REQUANT instr FIFO empty flag
//     - req_valid_o: RequantPipeline.valid_o (beat retire)
//     - req_data_o: 128-bit RequantPipeline.data_o (16 INT8 lanes)
//     - req_coeff_rdata: 36-bit {M[31:0], S[3:0]} from SRAMHub coeff BRAM
// Outputs:
//     - fifo_rd_en: Pop strobe for REQUANT instr FIFO
//     - req_mode: 2-bit mode_i selector for RequantPipeline
//     - req_coeff_raddr: Coeff BRAM read address into SRAMHub
//     - req_m0_a: 4 x INT32 packed scale factor (drives RequantPipeline.m0_a_i)
//     - req_n_a: 4 x UINT8 packed shift amount (drives RequantPipeline.n_a_i)
//     - req_bias: 4 x INT32 bias — tied 0 in SA mode
//     - vpu_out_waddr: Output Bank write address into SRAMHub
//     - vpu_out_wdata: 128-bit Output Bank write data
//     - vpu_out_wen: Output Bank write enable
//     - unit_done: 1-cycle pulse when current REQUANT op retires

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_REQ #(
    parameter int ChCount    = 1,
    parameter int M0Width    = 32,
    parameter int ShiftWidth = 8
)(
    input  logic                                clk,
    input  logic                                rst,

    input  logic [123:0]                        fifo_dout,
    input  logic                                fifo_empty,
    output logic                                fifo_rd_en,

    input  logic                                req_valid_o,
    input  logic [127:0]                        req_data_o,
    input  logic [COEFF_M_WIDTH+COEFF_S_WIDTH-1:0] req_coeff_rdata,

    output logic [1:0]                          req_mode,
    output logic [$clog2(MAX_CHANNELS)-1:0]     req_coeff_raddr,
    output logic [ChCount*M0Width-1:0]          req_m0_a,
    output logic [ChCount*ShiftWidth-1:0]       req_n_a,
    output logic [ChCount*32-1:0]               req_bias,

    output logic [$clog2(OUT_BANK_DEPTH)-1:0]   vpu_out_waddr,
    output logic [127:0]                        vpu_out_wdata,
    output logic                                vpu_out_wen,

    output logic                                unit_done
);

    npu_opcode_e fifo_opcode;
    assign fifo_opcode = npu_opcode_e'(fifo_dout[123:116]);

    npu_requant_payload_t req_payload;
    assign req_payload = npu_requant_payload_t'(fifo_dout[111:0]);

    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD_COEFF,
        S_RUN,
        S_WRITE,
        S_WRITE_DONE
    } state_e;

    // Coeff-load counter: wide enough to hold 0..ChCount inclusive (e.g. 5 bits
    // for ChCount = 16 per-channel dequant).
    localparam int   CoeffCntW = $clog2(ChCount + 1);

    state_e            state;
    logic [CoeffCntW-1:0] coeff_cnt;     // 0..ChCount inclusive
    logic [9:0]        target_count;  // latched ch_count (beat count)
    logic [9:0]        beat_count;    // valid_o beats observed

    // bias is fixed 0 for SA-path requant
    assign req_bias = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            state           <= S_IDLE;
            fifo_rd_en      <= 1'b0;
            req_mode        <= 2'b00;
            req_coeff_raddr <= '0;
            req_m0_a        <= '0;
            req_n_a         <= '0;
            vpu_out_waddr   <= '0;
            vpu_out_wdata   <= 128'h0;
            vpu_out_wen     <= 1'b0;
            unit_done       <= 1'b0;
            coeff_cnt       <= '0;
            target_count    <= 10'h0;
            beat_count      <= 10'h0;
        end else begin
            fifo_rd_en  <= 1'b0;
            vpu_out_wen <= 1'b0;
            unit_done   <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    req_mode <= 2'b00;
                    if (!fifo_empty) begin
                        if (fifo_opcode == OP_REQUANT) begin
                            fifo_rd_en      <= 1'b1;
                            target_count    <= req_payload.ch_count;
                            beat_count      <= 10'h0;
                            vpu_out_waddr   <= '0;
                            coeff_cnt       <= '0;
                            req_coeff_raddr <= '0;
                            state           <= S_LOAD_COEFF;
                        end else begin
                            // Drop unexpected opcodes.
                            fifo_rd_en <= 1'b1;
                        end
                    end
                end

                // Drive coeff_cnt as raddr; capture rdata one cycle later into
                // shadow[coeff_cnt-1]. Total 1+ChCount cycles to fully load.
                S_LOAD_COEFF: begin
                    // Capture lagged rdata into shadow.
                    if (coeff_cnt > '0 && coeff_cnt <= CoeffCntW'(ChCount)) begin
                        for (int g = 0; g < ChCount; g = g + 1) begin
                            if (CoeffCntW'(g) == coeff_cnt - 1'b1) begin
                                req_m0_a[g*M0Width +: M0Width] <=
                                    req_coeff_rdata[COEFF_M_WIDTH+COEFF_S_WIDTH-1
                                                    : COEFF_S_WIDTH];
                                req_n_a[g*ShiftWidth +: ShiftWidth] <=
                                    {{(ShiftWidth-COEFF_S_WIDTH){1'b0}},
                                     req_coeff_rdata[COEFF_S_WIDTH-1:0]};
                            end
                        end
                    end

                    if (coeff_cnt < CoeffCntW'(ChCount)) begin
                        req_coeff_raddr <= req_coeff_raddr + 1'b1;
                        coeff_cnt       <= coeff_cnt + 1'b1;
                    end else begin
                        // All coeffs captured this cycle. Switch to RUN.
                        req_mode <= 2'b01;  // FROM_PSB
                        state    <= S_RUN;
                    end
                end

                S_RUN: begin
                    req_mode <= 2'b01;  // hold FROM_PSB
                    if (req_valid_o) begin
                        vpu_out_wdata <= req_data_o;
                        state         <= S_WRITE;
                    end
                end

                S_WRITE: begin
                    req_mode      <= 2'b01;
                    vpu_out_wen   <= 1'b1;
                    state         <= S_WRITE_DONE;
                end

                S_WRITE_DONE: begin
                    req_mode      <= 2'b01;
                    vpu_out_waddr <= vpu_out_waddr + 1'b1;
                    beat_count    <= beat_count + 10'h1;

                    if ((beat_count + 10'h1) == target_count) begin
                        unit_done <= 1'b1;
                        req_mode  <= 2'b00;
                        state     <= S_IDLE;
                    end else begin
                        state <= S_RUN;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
