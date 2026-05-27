// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-25
// Saturating entry counter tracking in-flight RAW/WAR dependency slots; exposes full/empty status to the sequencer.
// Parameters:
//     - DEPTH: Max number of concurrent in-flight dependencies tracked
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - push: Increment count — new dependency slot acquired
//     - pop: Decrement count — dependency resolved
// Outputs:
//     - full: Asserted when count == DEPTH; no more slots available
//     - empty: Asserted when count == 0; no pending dependencies

module DepFIFO #(
    parameter int DEPTH = 4
) (
    input  logic clk, rst,
    input  logic push, pop,
    output logic full, empty
);

    logic [$clog2(DEPTH):0] mem;

    always_ff @(posedge clk) begin
        if (rst) begin
            mem <= '0;
        end else begin
            case ({push, pop})
                2'b10:   if (!full)  mem <= mem + 1;
                2'b01:   if (!empty) mem <= mem - 1;
                default: mem <= mem;
            endcase
        end
    end

    assign full  = (mem == DEPTH);
    assign empty = (mem == 0);
endmodule
