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
//     - sa_capture: SA-driven single-row capture strobe. Accumulates sa_row_in
//                   into buffer[0] while idle, without entering S_ACC (used for
//                   the matrix-vector path instead of microcode OP_PSB_ACC)
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
    input logic sa_capture,
    input logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] sa_row_in [ARRAY_LENGTH - 1 : 0],

    output logic [ARRAY_LENGTH*ACCUMULATOR_BITWIDTH - 1 : 0] requant_row_out,
    output logic [$clog2(ARRAY_HEIGHT) - 1 : 0] row_index_out,
    output logic row_out_valid,
    output logic acc_done,
    output logic flush_done,
    output logic busy
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_ACC,
        S_FLUSH,
        S_ACC_DONE,
        S_FLUSH_DONE
    } state_e;
    state_e ps, ns;

    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] buffer [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];

    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] acc_row_count;
    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] flush_row_count;

    logic last_acc_row;
    logic last_flush_row;

    localparam logic [$clog2(ARRAY_HEIGHT)-1:0] LastRow = ($clog2(ARRAY_HEIGHT))'(ARRAY_HEIGHT - 1);
    assign last_acc_row   = (acc_row_count   == LastRow);
    assign last_flush_row = (flush_row_count == LastRow);

    always_comb begin
        unique case (ps)
            S_IDLE: begin
                if (psb_acc)
                    ns = S_ACC;
                else if (psb_flush)
                    ns = S_FLUSH;
                else
                    ns = S_IDLE;
            end

            S_ACC: begin
                if (row_valid && last_acc_row)
                    ns = S_ACC_DONE;
                else
                    ns = S_ACC;
            end

            S_FLUSH: begin
                if (last_flush_row)
                    ns = S_FLUSH_DONE;
                else
                    ns = S_FLUSH;
            end

            S_ACC_DONE:   ns = S_IDLE;
            S_FLUSH_DONE: ns = S_IDLE;

            default: begin
                ns = S_IDLE;
            end
        endcase
    end

    always_comb begin
        row_out_valid = 1'b0;
        acc_done      = 1'b0;
        flush_done    = 1'b0;
        busy          = 1'b1;

        unique case (ps)
            S_IDLE: begin
                busy = 1'b0;
            end

            S_ACC: begin
                busy = 1'b1;
            end

            S_FLUSH: begin
                row_out_valid = 1'b1;
                busy          = 1'b1;
            end

            S_ACC_DONE: begin
                busy = 1'b0;
                acc_done = 1'b1;
            end

            S_FLUSH_DONE: begin
                busy = 1'b0;
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
            ps <= S_IDLE;
        else
            ps <= ns;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            acc_row_count   <= '0;
            flush_row_count <= '0;
        end else begin
            case (ps)
                S_IDLE: begin
                    acc_row_count   <= '0;
                    flush_row_count <= '0;
                    if (psb_acc && row_valid)
                        acc_row_count <= 1;
                end

                S_ACC: begin
                    if (row_valid && !last_acc_row)
                        acc_row_count <= acc_row_count + 1;
                end

                S_FLUSH: begin
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
                S_ACC: begin
                    if (row_valid) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[acc_row_count][col] <= buffer[acc_row_count][col] + sa_row_in[col];
                        end
                    end
                end

                S_IDLE: begin
                    if (psb_acc && row_valid) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[0][col] <= buffer[0][col] + sa_row_in[col];
                        end
                    end else if (sa_capture) begin
                        // SA-driven auto-capture: latch the single SA result row
                        // into buffer[0] without leaving S_IDLE (matrix-vector
                        // path; no OP_PSB_ACC instruction needed). busy stays low
                        // so the following OP_PSB_FLUSH can fire immediately.
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[0][col] <= buffer[0][col] + sa_row_in[col];
                        end
                    end
                end

                S_FLUSH: begin
                    // Rows are cleared after the flush finishes so the
                    // currently presented row remains visible for the cycle.
                end

                S_FLUSH_DONE: begin
                    for (int row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
                        for (int col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                            buffer[row][col] <= '0;
                        end
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
