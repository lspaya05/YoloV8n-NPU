// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Systolic-array dispatch. Pops one MATMUL instruction at a time, pulses
// SA_top.start, then drives a free-running counter that walks weight then
// activation read addresses through SRAMHub for the LOAD and RUN phases of
// SA_Controller. SA_top gates which stream is consumed internally
// (loadingWeight_c / validActivations), so spurious reads outside the phase
// windows are harmless. On SA_top.done, asserts bank_read pulses to swap the
// ping-pong banks and pulses unit_done back to the Sequencer.
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - fifo_dout: 124-bit {opcode, dep_flags, payload} from SA instr FIFO
//     - fifo_empty: SA instr FIFO empty flag
//     - sa_done: SA_top completion strobe (1-cycle pulse)
//     - cfg_tile_K: Tile K depth from Sequencer CSR (unused this phase; SA
//       processes its hardware K_DIM internally)
// Outputs:
//     - fifo_rd_en: Pop strobe for SA instr FIFO
//     - sa_start: 1-cycle pulse to launch a MATMUL tile
//     - sa_act_raddr: Activation bank read address into SRAMHub
//     - sa_wt_raddr: Weight bank read address into SRAMHub
//     - sa_act_bank_read: 1-cycle pulse signalling the active activation tile
//       has been fully consumed (PingPongBuffer swap trigger)
//     - sa_wt_bank_read: same for weight bank
//     - unit_done: 1-cycle pulse when current MATMUL retires

import NPU_HW_params_pkg::*;
import NPU_ISA_pkg::*;

module Dispatch_SA (
    input  logic                                clk,
    input  logic                                rst,

    input  logic [123:0]                        fifo_dout,
    input  logic                                fifo_empty,
    output logic                                fifo_rd_en,

    input  logic                                sa_done,
    input  logic [7:0]                          cfg_tile_K,

    output logic                                sa_start,
    output logic [$clog2(ACT_BUF_DEPTH)-1:0]    sa_act_raddr,
    output logic [$clog2(WT_BUF_DEPTH)-1:0]     sa_wt_raddr,
    output logic                                sa_act_bank_read,
    output logic                                sa_wt_bank_read,
    output logic                                unit_done
);

    // Opcode field is the top byte of the FIFO word.
    npu_opcode_e fifo_opcode;
    assign fifo_opcode = npu_opcode_e'(fifo_dout[123:116]);

    typedef enum logic [1:0] {
        S_IDLE,
        S_RUNNING,
        S_FINISH
    } state_e;

    state_e     state;
    logic [7:0] phase_cnt;

    // Active phase windows match SA_Controller's parameter defaults
    // (ARRAY_HEIGHT cycles of LOAD followed by K_DIM cycles of RUN).
    localparam logic [7:0] LoadCyc = 8'(SA_ROWS);
    localparam logic [7:0] RunCyc  = 8'(SA_ROWS);  // K_DIM = SA_ROWS in this build

    logic [7:0] act_phase_cnt;
    assign act_phase_cnt = phase_cnt - LoadCyc;

    always_ff @(posedge clk) begin
        if (rst) begin
            state            <= S_IDLE;
            phase_cnt        <= 8'h0;
            fifo_rd_en       <= 1'b0;
            sa_start         <= 1'b0;
            sa_act_raddr     <= '0;
            sa_wt_raddr      <= '0;
            sa_act_bank_read <= 1'b0;
            sa_wt_bank_read  <= 1'b0;
            unit_done        <= 1'b0;
        end else begin
            fifo_rd_en       <= 1'b0;
            sa_start         <= 1'b0;
            sa_act_bank_read <= 1'b0;
            sa_wt_bank_read  <= 1'b0;
            unit_done        <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    if (!fifo_empty && (fifo_opcode == OP_MATMUL)) begin
                        fifo_rd_en   <= 1'b1;
                        sa_start     <= 1'b1;
                        phase_cnt    <= 8'h0;
                        sa_wt_raddr  <= '0;
                        sa_act_raddr <= '0;
                        state        <= S_RUNNING;
                    end else if (!fifo_empty) begin
                        // Drop non-MATMUL ops to avoid deadlock; real ISA only
                        // routes MATMUL here so this path should not fire.
                        fifo_rd_en <= 1'b1;
                    end
                end

                S_RUNNING: begin
                    // Walk weight raddr through LOAD window, then activation
                    // raddr through RUN window. Hold after to ride out DRAIN.
                    if (phase_cnt < LoadCyc) begin
                        sa_wt_raddr <= phase_cnt[$clog2(WT_BUF_DEPTH)-1:0];
                    end
                    if ((phase_cnt >= LoadCyc) &&
                        (phase_cnt <  (LoadCyc + RunCyc))) begin
                        sa_act_raddr <=
                            act_phase_cnt[$clog2(ACT_BUF_DEPTH)-1:0];
                    end
                    phase_cnt <= phase_cnt + 8'h1;

                    if (sa_done) begin
                        state <= S_FINISH;
                    end
                end

                S_FINISH: begin
                    unit_done        <= 1'b1;
                    sa_act_bank_read <= 1'b1;
                    sa_wt_bank_read  <= 1'b1;
                    state            <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // cfg_tile_K reserved for multi-tile MATMUL loops in a later phase.
    logic _unused;
    assign _unused = |cfg_tile_K;

endmodule
