// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// PSB dispatch. Pops PSB instructions and steers them into the psb datapath:
//   OP_PSB_ACC   : pulse psb_acc + row_valid every cycle that a PSB_ACC is
//                  popped. psb internally ignores psb_acc once it has already
//                  entered the s1 accumulate window; row_valid then advances
//                  acc_row_count. After 16 PSB_ACCs psb pulses acc_done and
//                  drops back to idle. unit_done pulses one cycle per
//                  PSB_ACC retire so the Sequencer FENCE keeps advancing.
//   OP_PSB_FLUSH : wait for psb idle (psb_busy=0), pulse psb_flush, wait for
//                  flush_done, pulse unit_done.
// sa_row_in is wired directly to SA_top.MatrixMulOut by NPU.sv; this dispatch
// only paces row_valid.
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - fifo_dout: 124-bit {opcode, dep_flags, payload} from PSB instr FIFO
//     - fifo_empty: PSB instr FIFO empty flag
//     - psb_busy: psb.busy — high during ACC/FLUSH windows
//     - psb_acc_done: psb.acc_done — 1-cycle pulse after 16th row_valid
//     - psb_flush_done: psb.flush_done — 1-cycle pulse after 16 flush rows
// Outputs:
//     - fifo_rd_en: Pop strobe for PSB instr FIFO
//     - psb_acc: psb.psb_acc — enter accumulate state
//     - psb_flush: psb.psb_flush — enter flush state
//     - row_valid: psb.row_valid — sa_row_in is valid this cycle
//     - unit_done: 1-cycle pulse when current PSB op retires

import NPU_ISA_pkg::*;

module Dispatch_PSB (
    input  logic         clk,
    input  logic         rst,

    input  logic [123:0] fifo_dout,
    input  logic         fifo_empty,
    output logic         fifo_rd_en,

    input  logic         psb_busy,
    input  logic         psb_acc_done,
    input  logic         psb_flush_done,

    output logic         psb_acc,
    output logic         psb_flush,
    output logic         row_valid,
    output logic         unit_done
);

    npu_opcode_e fifo_opcode;
    assign fifo_opcode = npu_opcode_e'(fifo_dout[123:116]);

    typedef enum logic [0:0] {
        S_IDLE,
        S_WAIT_FLUSH
    } state_e;

    state_e state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= S_IDLE;
            fifo_rd_en <= 1'b0;
            psb_acc    <= 1'b0;
            psb_flush  <= 1'b0;
            row_valid  <= 1'b0;
            unit_done  <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;
            psb_acc    <= 1'b0;
            psb_flush  <= 1'b0;
            row_valid  <= 1'b0;
            unit_done  <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    if (!fifo_empty) begin
                        unique case (fifo_opcode)
                            OP_PSB_ACC: begin
                                // Fire one row of accumulation per instr.
                                fifo_rd_en <= 1'b1;
                                psb_acc    <= 1'b1;
                                row_valid  <= 1'b1;
                                unit_done  <= 1'b1;
                            end

                            OP_PSB_FLUSH: begin
                                // psb.psb_flush is sampled only in s0; if psb
                                // is mid-ACC wait for it to drain (acc_done
                                // brings it back to s0).
                                if (!psb_busy) begin
                                    fifo_rd_en <= 1'b1;
                                    psb_flush  <= 1'b1;
                                    state      <= S_WAIT_FLUSH;
                                end
                            end

                            default: begin
                                // Drop unexpected opcodes to keep FIFO moving.
                                fifo_rd_en <= 1'b1;
                            end
                        endcase
                    end
                end

                S_WAIT_FLUSH: begin
                    if (psb_flush_done) begin
                        unit_done <= 1'b1;
                        state     <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // psb_acc_done not consumed for unit_done (PSB_ACC is per-row above) but
    // kept on the port for visibility / future use.
    logic _unused;
    assign _unused = psb_acc_done;

endmodule
