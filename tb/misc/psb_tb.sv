`timescale 1ns/1ps

module psb_misc_tb;

    // Small PSB size for easier testing.
    localparam int ACCUMULATOR_BITWIDTH = 32;
    localparam int ARRAY_HEIGHT = 4;
    localparam int ARRAY_LENGTH = 4;

    // Inputs to the PSB.
    logic clk;
    logic rst;
    logic psb_acc;
    logic psb_flush;
    logic row_valid;
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] sa_row_in [ARRAY_LENGTH - 1 : 0];

    // Outputs from the PSB.
    logic [ARRAY_LENGTH*ACCUMULATOR_BITWIDTH - 1 : 0] requant_row_out;
    logic [$clog2(ARRAY_HEIGHT) - 1 : 0] row_index_out;
    logic row_out_valid;
    logic acc_done;
    logic flush_done;
    logic busy;

    // Variables used by the testbench.
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] expected [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];
    int row;
    int col;
    int errors;

    // Instantiate the PSB.
    psb #(
        .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH),
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .psb_acc(psb_acc),
        .psb_flush(psb_flush),
        .row_valid(row_valid),
        .sa_row_in(sa_row_in),
        .requant_row_out(requant_row_out),
        .row_index_out(row_index_out),
        .row_out_valid(row_out_valid),
        .acc_done(acc_done),
        .flush_done(flush_done),
        .busy(busy)
    );

    // Clock generation.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initial values.
        rst = 1'b1;
        psb_acc = 1'b0;
        psb_flush = 1'b0;
        row_valid = 1'b0;
        errors = 0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                expected[row][col] = 0;
            end
        end

        for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
            sa_row_in[col] = 0;
        end

        // Reset the PSB.
        @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        if (busy !== 1'b0) begin
            $display("FAIL reset: busy should be 0");
            errors = errors + 1;
        end

        // ------------------------------------------------
        // Test 1: Accumulate one 4x4 tile into the PSB.
        // ------------------------------------------------
        psb_acc = 1'b1;
        @(posedge clk);
        psb_acc = 1'b0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                sa_row_in[col] = (row * 10) + col;
                expected[row][col] = (row * 10) + col;
            end

            row_valid = 1'b1;
            @(posedge clk);
        end

        row_valid = 1'b0;
        #1;

        if (acc_done !== 1'b1) begin
            $display("FAIL test 1: acc_done should be 1 after accumulating all rows");
            errors = errors + 1;
        end

        @(posedge clk);

        // ------------------------------------------------
        // Test 2: Flush the one tile and check all rows.
        // ------------------------------------------------
        psb_flush = 1'b1;
        @(posedge clk);
        psb_flush = 1'b0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            #1;

            if (row_out_valid !== 1'b1) begin
                $display("FAIL test 2: row_out_valid should be 1 on row %0d", row);
                errors = errors + 1;
            end

            if (row_index_out !== row) begin
                $display("FAIL test 2: row_index_out expected %0d got %0d", row, row_index_out);
                errors = errors + 1;
            end

            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                if ($signed(requant_row_out[col*ACCUMULATOR_BITWIDTH +: ACCUMULATOR_BITWIDTH]) !== expected[row][col]) begin
                    $display("FAIL test 2: row %0d col %0d expected %0d got %0d",
                             row, col, expected[row][col],
                             $signed(requant_row_out[col*ACCUMULATOR_BITWIDTH +: ACCUMULATOR_BITWIDTH]));
                    errors = errors + 1;
                end
            end

            @(posedge clk);
        end

        #1;

        if (flush_done !== 1'b1) begin
            $display("FAIL test 2: flush_done should be 1 after flushing all rows");
            errors = errors + 1;
        end

        @(posedge clk);

        // Clear expected values because the PSB clears rows during flush.
        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                expected[row][col] = 0;
            end
        end

        // ------------------------------------------------
        // Test 3: Accumulate two tiles before flushing.
        // This checks that the PSB adds new values into old values.
        // ------------------------------------------------
        psb_acc = 1'b1;
        @(posedge clk);
        psb_acc = 1'b0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                sa_row_in[col] = 100 + (row * 10) + col;
                expected[row][col] = expected[row][col] + 100 + (row * 10) + col;
            end

            row_valid = 1'b1;
            @(posedge clk);
        end

        row_valid = 1'b0;
        @(posedge clk);

        psb_acc = 1'b1;
        @(posedge clk);
        psb_acc = 1'b0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                sa_row_in[col] = 200 + (row * 10) + col;
                expected[row][col] = expected[row][col] + 200 + (row * 10) + col;
            end

            row_valid = 1'b1;
            @(posedge clk);
        end

        row_valid = 1'b0;
        @(posedge clk);

        // Flush after two accumulated tiles.
        psb_flush = 1'b1;
        @(posedge clk);
        psb_flush = 1'b0;

        for (row = 0; row < ARRAY_HEIGHT; row = row + 1) begin
            #1;

            for (col = 0; col < ARRAY_LENGTH; col = col + 1) begin
                if ($signed(requant_row_out[col*ACCUMULATOR_BITWIDTH +: ACCUMULATOR_BITWIDTH]) !== expected[row][col]) begin
                    $display("FAIL test 3: row %0d col %0d expected %0d got %0d",
                             row, col, expected[row][col],
                             $signed(requant_row_out[col*ACCUMULATOR_BITWIDTH +: ACCUMULATOR_BITWIDTH]));
                    errors = errors + 1;
                end
            end

            @(posedge clk);
        end

        @(posedge clk);

        // ------------------------------------------------
        // End result.
        // ------------------------------------------------
        if (errors == 0) begin
            $display("PASS: psb_tb passed all tests");
        end else begin
            $display("FAIL: psb_tb found %0d errors", errors);
        end

        $stop;
    end

endmodule
