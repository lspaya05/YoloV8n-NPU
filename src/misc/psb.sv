// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-07
// This is the Partial Sum Buffer (PSB) for the Systolic Array. The PSB accumulates the 32-bit output rows from the SA and then
// flushes them out one row per cycle for requantization to the VPU.
//
// The PSB stores the INT32 output rows from the Systolic Array. Each PSB_ACC
// accepts ARRAY_HEIGHT rows, where each row has ARRAY_LENGTH INT32
// values. New rows are added into the buffer so multiple K-tiles can accumulate
// into one final output tile. PSB_FLUSH then sends the completed tile out one
// row per cycle and clears the buffer for the next output tile.
//
// A K-tile is one small chunk of the input channels used for one matrix
// multiply. If a layer has too many input channels to process all at once, the
// Systolic Array computes one chunk first, then another chunk, and the PSB adds
// those chunk results together until the full answer is ready.

// WARNING: The array height and length must be in powers of 2 to avoid overflow in the row counters.

module psb #(
    parameter int ACCUMULATOR_BITWIDTH = 32,
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16
) (
    // Instantiating the input and output logic
    input logic clk,
    input logic rst,
    input logic psb_acc,
    input logic psb_flush,
    input logic row_valid,
    input logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] sa_row_in [ARRAY_LENGTH - 1 : 0],

    output logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] requant_row_out [ARRAY_LENGTH - 1 : 0],
    output logic [$clog2(ARRAY_HEIGHT) - 1 : 0] row_index_out,
    output logic row_out_valid,
    output logic acc_done,
    output logic flush_done,
    output logic busy
);

    // Instantiating the state for the fsm
    enum {s0, s1, s2, s3} ps, ns;

    // Buffer that holds the partial sums for one output tile.
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] buffer [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];

    // Row counters for the accumulate and flush phases.
    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] acc_row_count;
    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] flush_row_count;

    logic last_acc_row;
    logic last_flush_row;

    assign last_acc_row = (acc_row_count == ARRAY_HEIGHT - 1);
    assign last_flush_row = (flush_row_count == ARRAY_HEIGHT - 1);

// Next-state logic
    always_comb begin
        case (ps)
            // Waits for a PSB command.
            s0: begin
                // Start accumulating an SA tile when psb_acc is high.
                if (psb_acc)
                    ns = s1;
                else if (psb_flush)
                    ns = s2;
                else
                    ns = s0;
            end

            // Accumulate: accept ARRAY_HEIGHT rows from the Systolic Array.
            s1: begin
                // Wait until the last row has been accepted.
                if (row_valid && last_acc_row)
                    ns = s3;
                else
                    ns = s1;
            end

            // Flush: output ARRAY_HEIGHT rows to the requant unit.
            s2: begin
                // After the last row is sent, return through the done state.
                if (last_flush_row)
                    ns = s3;
                else
                    ns = s2;
            end

            // Done: pulse the done signal for the previous command.
            s3: begin
                ns = s0;
            end

            default: begin
                ns = s0;
            end
        endcase
    end

// Output logic for the fsm at each state
    always_comb begin

        // Giving initial value for each of the logic variables
        row_out_valid = 1'b0;
        acc_done      = 1'b0;
        flush_done    = 1'b0;
        busy          = 1'b1;

        case (ps)
            // Defining the output logic at s0, if you want to see the definition of states, check the code above
            s0: begin
                busy = 1'b0;
            end

            // Defining the output logic at s1, if you want to see the definition of states, check the code above
            s1: begin
                busy = 1'b1;
            end

            // Defining the output logic at s2, if you want to see the definition of states, check the code above
            s2: begin
                row_out_valid = 1'b1;
                busy = 1'b1;
            end

            // Defining the output logic at s3, if you want to see the definition of states, check the code above
            s3: begin
                busy = 1'b0;

                if (last_acc_row)
                    acc_done = 1'b1;
                else
                    flush_done = 1'b1;
            end

            default: begin
                row_out_valid = 1'b0;
                acc_done      = 1'b0;
                flush_done    = 1'b0;
                busy          = 1'b0;
            end
        endcase
    end

    // Flip flop for reset
    always_ff @(posedge clk) begin
        if (rst)
            ps <= s0;
        else
            ps <= ns;
    end

    // Counter flip flops
    // s0: reset both row counters because the PSB is idle.
    // s1: count which SA row is being accumulated into the buffer.
    // s2: count which buffered row is being flushed to the requant unit.
    // default: hold the current counter values.
    always_ff @(posedge clk) begin
        if (rst) begin
            acc_row_count <= '0;
            flush_row_count <= '0;
        end else begin
            case (ps)
                s0: begin
                    // In idle, the next command should always start at row 0.
                    acc_row_count <= '0;
                    flush_row_count <= '0;
                end

                s1: begin
                    // During accumulate, move to the next row only when the
                    // current SA row is valid and there are more rows left.
                    if (row_valid && !last_acc_row)
                        acc_row_count <= acc_row_count + 1;
                end

                s2: begin
                    // During flush, send one row per cycle and move to the
                    // next row until the full tile has been sent.
                    if (!last_flush_row)
                        flush_row_count <= flush_row_count + 1;
                end

                default: begin
                    // In the done state, keep the counters stable for the
                    // one-cycle done pulse.
                    acc_row_count <= acc_row_count;
                    flush_row_count <= flush_row_count;
                end
            endcase
        end
    end

    // Buffer flip flops
    // s1: add each incoming SA row into the matching PSB row.
    // s2: clear each row after it has been presented to requant_row_out.
    // default: keep all stored partial sums unchanged.
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
                for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                    buffer[row][col] <= '0;
                end
            end
        end else begin
            case (ps)
                s1: begin
                    // Accumulate the current SA row into the current PSB row.
                    // This lets multiple K-tiles add into the same output tile.
                    if (row_valid) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[acc_row_count][col] <= buffer[acc_row_count][col] + sa_row_in[col];
                        end
                    end
                end

                s2: begin
                    // The output mux is already showing this row during s2, so
                    // clear the row here to prepare for the next output tile.
                    for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                        buffer[flush_row_count][col] <= '0;
                    end
                end

                default: begin
                    // When the PSB is idle or pulsing done, keep the stored
                    // partial sums exactly as they are.
                    for (int row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[row][col] <= buffer[row][col];
                        end
                    end
                end
            endcase
        end
    end

    // Output row mux
    always_comb begin
        row_index_out = flush_row_count;

        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
            requant_row_out[col] = buffer[flush_row_count][col];
        end
    end

endmodule
