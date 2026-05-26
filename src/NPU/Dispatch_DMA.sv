// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// DMA-unit dispatch stub. The real DMA datapath is deferred; this stub only
// drains both DMA instruction FIFOs (Ch0 = LOAD/STORE/UPSAMPLE/CONCAT/COEFF,
// Ch1 = WT_LOAD) so the Sequencer never stalls on dispatch_stall. Per-unit
// done is tied high at the NPU top level, so this module reports nothing.
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset (unused; kept for interface symmetry)
//     - ch0_empty: DMA Ch0 instr FIFO empty flag
//     - ch1_empty: DMA Ch1 (WT_LOAD) instr FIFO empty flag
//     - ch0_dout / ch1_dout: 124-bit {opcode, dep_flags, payload} — unused in this stub
// Outputs:
//     - ch0_rd_en: Pop strobe for Ch0 FIFO (asserted whenever Ch0 not empty)
//     - ch1_rd_en: Pop strobe for Ch1 FIFO (asserted whenever Ch1 not empty)

module Dispatch_DMA (
    input  logic         clk,
    input  logic         rst,

    input  logic [123:0] ch0_dout,
    input  logic         ch0_empty,
    output logic         ch0_rd_en,

    input  logic [123:0] ch1_dout,
    input  logic         ch1_empty,
    output logic         ch1_rd_en
);

    // Stub: drain both FIFOs continuously. Real decode/handshake comes with the
    // DMA datapath implementation.
    assign ch0_rd_en = ~ch0_empty;
    assign ch1_rd_en = ~ch1_empty;

    // Tie-off unused inputs to suppress lint warnings.
    logic _unused;
    assign _unused = clk | rst | (|ch0_dout) | (|ch1_dout);

endmodule
