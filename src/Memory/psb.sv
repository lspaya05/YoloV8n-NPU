// Name: Leonard Paya, Bernardo Lin
// Date: 2026-05-18
// Accumulates INT32 partial-sum rows from the systolic array across K-tiles then flushes one packed row per cycle to the requant unit.
// Parameters:
//     - ACCUMULATOR_BITWIDTH: Bit width of each partial-sum entry
//     - ARRAY_HEIGHT: Number of rows per output tile; must be a power of 2
//     - ARRAY_LENGTH: Number of columns per output tile; must be a power of 2
// Inputs:
//     - clk: System clock
//     - rst: Active-high synchronous reset
//     - psb_acc: Command to start accumulating the next SA tile into the buffer
//     - psb_flush: Command to start flushing the completed tile to the requant unit
//     - row_valid: Asserted when sa_row_in holds a valid partial-sum row
//     - sa_row_in: ARRAY_LENGTH unpacked ACCUMULATOR_BITWIDTH-bit INT32 partial sums from the systolic array
// Outputs:
//     - requant_row_out: Packed ARRAY_LENGTH x ACCUMULATOR_BITWIDTH-bit row driven to the requant unit each flush cycle
//     - row_index_out: log2(ARRAY_HEIGHT)-bit index of the row currently being flushed
//     - row_out_valid: High during flush; indicates requant_row_out holds a valid row
//     - acc_done: One-cycle pulse when a full tile has been accumulated
//     - flush_done: One-cycle pulse when a full tile has been flushed
//     - busy: High while the PSB is accumulating or flushing; low when idle

// WARNING: The array height and length must be in powers of 2 to avoid overflow in the row counters.

module psb #(
    parameter int ACCUMULATOR_BITWIDTH = 32,
    parameter int ARRAY_HEIGHT = 16,
    parameter int ARRAY_LENGTH = 16
) (
    input logic clk,
    input logic rst,
    input logic psb_acc,
    input logic psb_flush,
    input logic row_valid,
    input logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] sa_row_in [ARRAY_LENGTH - 1 : 0],

    output logic [ARRAY_LENGTH*ACCUMULATOR_BITWIDTH - 1 : 0] requant_row_out,
    output logic [$clog2(ARRAY_HEIGHT) - 1 : 0] row_index_out,
    output logic row_out_valid,
    output logic acc_done,
    output logic flush_done,
    output logic busy
);

    enum {s0, s1, s2, s3} ps, ns;

    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] buffer [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];

    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] acc_row_count;
    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] flush_row_count;

    logic last_acc_row;
    logic last_flush_row;

    assign last_acc_row   = (acc_row_count   == ARRAY_HEIGHT - 1);
    assign last_flush_row = (flush_row_count == ARRAY_HEIGHT - 1);

    always_comb begin
        case (ps)
            s0: begin
                if (psb_acc)
                    ns = s1;
                else if (psb_flush)
                    ns = s2;
                else
                    ns = s0;
            end

            s1: begin
                if (row_valid && last_acc_row)
                    ns = s3;
                else
                    ns = s1;
            end

            s2: begin
                if (last_flush_row)
                    ns = s3;
                else
                    ns = s2;
            end

            s3: begin
                ns = s0;
            end

            default: begin
                ns = s0;
            end
        endcase
    end

    always_comb begin
        row_out_valid = 1'b0;
        acc_done      = 1'b0;
        flush_done    = 1'b0;
        busy          = 1'b1;

        case (ps)
            s0: begin
                busy = 1'b0;
            end

            s1: begin
                busy = 1'b1;
            end

            s2: begin
                row_out_valid = 1'b1;
                busy          = 1'b1;
            end

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

    always_ff @(posedge clk) begin
        if (rst)
            ps <= s0;
        else
            ps <= ns;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            acc_row_count   <= '0;
            flush_row_count <= '0;
        end else begin
            case (ps)
                s0: begin
                    acc_row_count   <= '0;
                    flush_row_count <= '0;
                end

                s1: begin
                    if (row_valid && !last_acc_row)
                        acc_row_count <= acc_row_count + 1;
                end

                s2: begin
                    if (!last_flush_row)
                        flush_row_count <= flush_row_count + 1;
                end

                default: begin
                    acc_row_count   <= acc_row_count;
                    flush_row_count <= flush_row_count;
                end
            endcase
        end
    end

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
                    if (row_valid) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[acc_row_count][col] <= buffer[acc_row_count][col] + sa_row_in[col];
                        end
                    end
                end

                s2: begin
                    // Clear each row while it is being presented; output mux reads buffer[flush_row_count] combinatorially.
                    for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                        buffer[flush_row_count][col] <= '0;
                    end
                end

                default: begin
                    for (int row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[row][col] <= buffer[row][col];
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        row_index_out = flush_row_count;

        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
            requant_row_out[(col*ACCUMULATOR_BITWIDTH) +: ACCUMULATOR_BITWIDTH] = buffer[flush_row_count][col];
        end
    end

endmodule
