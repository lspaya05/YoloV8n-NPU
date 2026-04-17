`timescale 1ns/1ps

module SA_top_tb;

    // ------------------------------------------------
    // Small test configuration
    // ------------------------------------------------
    // We use a 4x4 array here to keep the simulation short and readable
    // while still exercising all of the controller/datapath timing behavior.
    localparam int FORMAT_BITWIDTH      = 8;
    localparam int ACCUMULATOR_BITWIDTH = 32;
    localparam int ARRAY_HEIGHT         = 4;
    localparam int ARRAY_LENGTH         = 4;
    localparam int K_DIM                = 4;

    // Expected controller phase lengths for this small configuration.
    localparam int LOAD_CYCLES          = ARRAY_HEIGHT;
    localparam int RUN_CYCLES           = K_DIM;
    localparam int DRAIN_CYCLES         = ARRAY_HEIGHT + ARRAY_LENGTH - 2;
    localparam int CLK_HALF_NS          = 5;
    localparam int TIMEOUT_NS           = 250_000;

    // ------------------------------------------------
    // DUT interface
    // ------------------------------------------------
    logic clk;
    logic rst;
    logic start;

    logic signed [FORMAT_BITWIDTH - 1 : 0] weightInputRow [ARRAY_LENGTH - 1 : 0];
    logic signed [FORMAT_BITWIDTH - 1 : 0] activationInputCol [ARRAY_HEIGHT - 1 : 0];
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] MatrixMulOut [ARRAY_LENGTH - 1 : 0];
    logic load_done;
    logic done;
    logic busy;

    // ------------------------------------------------
    // Reference datapath inputs/outputs
    // ------------------------------------------------
    // The golden MatrixMul instance is fed with the exact same weight and
    // activation traffic as the DUT datapath. That lets us verify the SA_top
    // wrapper connection logic without re-deriving matrix results by hand.
    logic signed [FORMAT_BITWIDTH - 1 : 0] ref_weightInputRow [ARRAY_LENGTH - 1 : 0];
    logic signed [FORMAT_BITWIDTH - 1 : 0] ref_activationInputCol [ARRAY_HEIGHT - 1 : 0];
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] ref_MatrixMulOut [ARRAY_LENGTH - 1 : 0];

    // ------------------------------------------------
    // Test vectors and bookkeeping storage
    // ------------------------------------------------
    logic signed [FORMAT_BITWIDTH - 1 : 0] weight_matrix [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];
    logic signed [FORMAT_BITWIDTH - 1 : 0] activation_matrix [K_DIM - 1 : 0][ARRAY_HEIGHT - 1 : 0];
    logic signed [FORMAT_BITWIDTH - 1 : 0] next_weight_matrix [ARRAY_HEIGHT - 1 : 0][ARRAY_LENGTH - 1 : 0];
    logic signed [FORMAT_BITWIDTH - 1 : 0] next_activation_matrix [K_DIM - 1 : 0][ARRAY_HEIGHT - 1 : 0];
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] expected_result [ARRAY_LENGTH - 1 : 0];
    logic signed [ACCUMULATOR_BITWIDTH - 1 : 0] previous_result [ARRAY_LENGTH - 1 : 0];

    int error_count;
    int cycle_count;
    int transaction_count;
    int load_cycles_seen;
    int run_cycles_seen;
    int drain_cycles_seen;
    int done_cycles_seen;
    int accepted_start_count;
    int current_load_cycle;
    int current_run_cycle;

    // ------------------------------------------------
    // DUT: full wrapper under test
    // ------------------------------------------------
    SA_top #(
        .FORMAT_BITWIDTH(FORMAT_BITWIDTH),
        .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH),
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH),
        .K_DIM(K_DIM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .weightInputRow(weightInputRow),
        .activationInputCol(activationInputCol),
        .MatrixMulOut(MatrixMulOut),
        .load_done(load_done),
        .done(done),
        .busy(busy)
    );

    // ------------------------------------------------
    // Golden reference: datapath only
    // ------------------------------------------------
    // This sees the same streamed inputs and controller load signal as the DUT's
    // internal datapath, so its final output should match the wrapper's held
    // MatrixMulOut when SA_top is wired correctly.
    MatrixMul #(
        .FORMAT_BITWIDTH(FORMAT_BITWIDTH),
        .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH),
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH)
    ) golden_datapath (
        .clk(clk),
        .rst(rst),
        .loadingWeight_c(dut.loadingWeight_c),
        .weightInputRow(ref_weightInputRow),
        .activationInputCol(ref_activationInputCol),
        .MatrixMulOut(ref_MatrixMulOut)
    );

    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // Common failure helper so every check reports cycle/transaction context.
    task automatic fail;
        input string message;
        begin
            error_count = error_count + 1;
            $display("FAIL cycle=%0d txn=%0d : %0s", cycle_count, transaction_count, message);
        end
    endtask

    // Drive all DUT inputs to zero.
    // This is useful during reset, between phases, and before a new transaction.
    task automatic clear_dut_inputs;
        begin
            foreach (weightInputRow[col])
                weightInputRow[col] = '0;
            foreach (activationInputCol[row])
                activationInputCol[row] = '0;
        end
    endtask

    // Load one set of test matrices.
    // Each case gives us a different mix of positive/negative/zero values so
    // we exercise more than one easy “all positive” path.
    task automatic load_case_data;
        input int case_id;
        begin
            case (case_id)
                0: begin
                    weight_matrix = '{
                        '{ 8'sd3,  -8'sd2,  8'sd1,  8'sd4},
                        '{-8'sd1,   8'sd5, -8'sd3,  8'sd2},
                        '{ 8'sd6,   8'sd0,  8'sd2, -8'sd1},
                        '{ 8'sd4,  -8'sd2,  8'sd7,  8'sd3}
                    };
                    activation_matrix = '{
                        '{ 8'sd1,   8'sd2, -8'sd1,  8'sd0},
                        '{-8'sd2,   8'sd3,  8'sd1,  8'sd4},
                        '{ 8'sd0,  -8'sd1,  8'sd2,  8'sd3},
                        '{ 8'sd5,   8'sd1, -8'sd2,  8'sd2}
                    };
                end

                1: begin
                    weight_matrix = '{
                        '{ 8'sd0,   8'sd0,  8'sd0,  8'sd0},
                        '{ 8'sd1,  -8'sd1,  8'sd1, -8'sd1},
                        '{-8'sd4,   8'sd2,  8'sd0,  8'sd3},
                        '{ 8'sd7,  -8'sd6,  8'sd5, -8'sd4}
                    };
                    activation_matrix = '{
                        '{ 8'sd4,   8'sd0, -8'sd3,  8'sd2},
                        '{ 8'sd0,   8'sd0,  8'sd0,  8'sd0},
                        '{-8'sd1,   8'sd2, -8'sd2,  8'sd1},
                        '{ 8'sd3,  -8'sd3,  8'sd1, -8'sd1}
                    };
                end

                2: begin
                    weight_matrix = '{
                        '{-8'sd8,   8'sd7, -8'sd6,  8'sd5},
                        '{ 8'sd4,  -8'sd3,  8'sd2, -8'sd1},
                        '{ 8'sd1,   8'sd2,  8'sd3,  8'sd4},
                        '{-8'sd5,  -8'sd4, -8'sd3, -8'sd2}
                    };
                    activation_matrix = '{
                        '{ 8'sd2,  -8'sd1,  8'sd3, -8'sd4},
                        '{-8'sd3,   8'sd4, -8'sd2,  8'sd1},
                        '{ 8'sd1,   8'sd0,  8'sd2, -8'sd2},
                        '{-8'sd4,   8'sd3,  8'sd1,  8'sd2}
                    };
                end

                default: begin
                    fail($sformatf("Unsupported case_id %0d", case_id));
                end
            endcase
        end
    endtask

    // Preload another matrix set so we can test a later back-to-back run
    // without reusing exactly the same data again.
    task automatic preload_next_case_data;
        input int case_id;
        begin
            case (case_id)
                0: begin
                    next_weight_matrix = '{
                        '{ 8'sd2,  8'sd1, -8'sd1,  8'sd0},
                        '{ 8'sd3, -8'sd2,  8'sd4, -8'sd3},
                        '{-8'sd1,  8'sd5,  8'sd2,  8'sd1},
                        '{ 8'sd6, -8'sd4,  8'sd0,  8'sd2}
                    };
                    next_activation_matrix = '{
                        '{ 8'sd1, -8'sd1,  8'sd2,  8'sd3},
                        '{ 8'sd2,  8'sd0, -8'sd2,  8'sd1},
                        '{-8'sd3,  8'sd4,  8'sd1, -8'sd1},
                        '{ 8'sd0,  8'sd2,  8'sd3, -8'sd2}
                    };
                end

                1: begin
                    next_weight_matrix = '{
                        '{-8'sd2,  8'sd3,  8'sd1, -8'sd4},
                        '{ 8'sd5,  8'sd0, -8'sd1,  8'sd2},
                        '{ 8'sd1, -8'sd3,  8'sd6,  8'sd0},
                        '{-8'sd4,  8'sd2, -8'sd5,  8'sd3}
                    };
                    next_activation_matrix = '{
                        '{ 8'sd4, -8'sd2,  8'sd1,  8'sd0},
                        '{-8'sd1,  8'sd3,  8'sd2, -8'sd2},
                        '{ 8'sd2,  8'sd1, -8'sd3,  8'sd4},
                        '{-8'sd3,  8'sd0,  8'sd1,  8'sd2}
                    };
                end

                default: begin
                    fail($sformatf("Unsupported preload case_id %0d", case_id));
                end
            endcase
        end
    endtask

    // Compare the wrapper's held output against the expected result captured
    // from the golden datapath.
    task automatic compare_outputs;
        input string label;
        begin
            for (int col = 0; col < ARRAY_LENGTH; col++) begin
                if (MatrixMulOut[col] !== expected_result[col]) begin
                    fail($sformatf("%0s: MatrixMulOut[%0d] expected %0d got %0d",
                                   label, col, expected_result[col], MatrixMulOut[col]));
                end
            end
        end
    endtask

    // Save the current top-level outputs so we can later verify that they stay
    // stable instead of drifting while a transaction is still running.
    task automatic snapshot_outputs;
        begin
            for (int col = 0; col < ARRAY_LENGTH; col++)
                previous_result[col] = MatrixMulOut[col];
        end
    endtask

    // Check that the user-visible output register is holding its previous value.
    task automatic expect_outputs_hold;
        input string label;
        begin
            for (int col = 0; col < ARRAY_LENGTH; col++) begin
                if (MatrixMulOut[col] !== previous_result[col]) begin
                    fail($sformatf("%0s: output[%0d] changed from %0d to %0d",
                                   label, col, previous_result[col], MatrixMulOut[col]));
                end
            end
        end
    endtask

    // Start one transaction by loading a new matrix case, clearing old stream
    // inputs, and pulsing start for one clock.
    task automatic start_transaction;
        input int case_id;
        begin
            load_case_data(case_id);
            clear_dut_inputs();
            current_load_cycle = 0;
            current_run_cycle = 0;

            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
        end
    endtask

    // Wait until SA_top reports done, then compare the held result register
    // against the golden datapath result.
    // The tiny #1ps delay gives nonblocking assignments a chance to settle.
    task automatic wait_for_done_and_check;
        input string label;
        begin
            wait (done === 1'b1);
            @(posedge clk);
            #1ps;
            compare_outputs(label);
        end
    endtask

    // Reset the wrapper in the middle of a transaction and make sure it returns
    // to a clean idle state with cleared outputs.
    task automatic inject_reset_mid_transaction;
        begin
            rst = 1'b1;
            @(posedge clk);
            @(posedge clk);
            rst = 1'b0;
            clear_dut_inputs();
            current_load_cycle = 0;
            current_run_cycle = 0;
            @(posedge clk);

            if (busy !== 1'b0)
                fail("busy should be 0 immediately after mid-transaction reset recovery");
            if (done !== 1'b0)
                fail("done should be 0 after mid-transaction reset");
            if (load_done !== 1'b0)
                fail("load_done should be 0 after mid-transaction reset");
            for (int col = 0; col < ARRAY_LENGTH; col++) begin
                if (MatrixMulOut[col] !== '0)
                    fail($sformatf("output[%0d] should clear to 0 on reset", col));
            end
        end
    endtask

    // Simple cycle counter used in failure messages.
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
    end

    // ------------------------------------------------
    // Negative-edge driver for DUT inputs
    // ------------------------------------------------
    // The DUT samples on the positive edge, so we update the streamed weights
    // and activations on the negative edge. That way the values are already
    // stable before the next positive edge arrives.
    always @(negedge clk) begin
        if (rst) begin
            current_load_cycle = 0;
            current_run_cycle = 0;
            clear_dut_inputs();
        end else begin
            // Default to zeros each half-cycle. If the controller says we are in
            // LOAD or RUN, we overwrite these with the next valid stream values.
            foreach (weightInputRow[col])
                weightInputRow[col] = '0;
            foreach (activationInputCol[row])
                activationInputCol[row] = '0;

            // During LOAD, feed weight rows in reverse order so the first row
            // shifted in ends up at the bottom after weight propagation.
            if (dut.loadingWeight_c) begin
                if (current_load_cycle >= LOAD_CYCLES)
                    fail("loadingWeight_c stayed high longer than expected");
                for (int col = 0; col < ARRAY_LENGTH; col++)
                    weightInputRow[col] = weight_matrix[ARRAY_HEIGHT - 1 - current_load_cycle][col];
                current_load_cycle = current_load_cycle + 1;
            end

            // During RUN, feed one activation vector per cycle.
            if (dut.validActivations) begin
                if (current_run_cycle >= RUN_CYCLES)
                    fail("validActivations stayed high longer than expected");
                for (int row = 0; row < ARRAY_HEIGHT; row++)
                    activationInputCol[row] = activation_matrix[current_run_cycle][row];
                current_run_cycle = current_run_cycle + 1;
            end

            // Feed the same external traffic into the golden datapath.
            for (int col = 0; col < ARRAY_LENGTH; col++)
                ref_weightInputRow[col] = weightInputRow[col];

            for (int row = 0; row < ARRAY_HEIGHT; row++) begin
                if (dut.validActivations)
                    ref_activationInputCol[row] = activationInputCol[row];
                else
                    ref_activationInputCol[row] = '0;
            end

            // When the controller enters DONE, the golden datapath's output at
            // that moment becomes the expected answer for this transaction.
            if (dut.controller_done_c) begin
                for (int col = 0; col < ARRAY_LENGTH; col++)
                    expected_result[col] = ref_MatrixMulOut[col];
            end
        end
    end

    // ------------------------------------------------
    // Protocol monitor
    // ------------------------------------------------
    // This block continuously checks that SA_top is wiring the controller and
    // datapath together correctly while the scenario stimulus is running.
    always @(posedge clk) begin
        if (!rst) begin
            if (dut.loadingWeight_c && dut.validActivations)
                fail("loadingWeight_c and validActivations should never be high together");

            // Check controller phase behavior cycle-by-cycle.
            case (dut.controller.ps)
                dut.controller.IDLE: begin
                    if (load_done !== 1'b0)
                        fail("load_done should be 0 in IDLE");
                end

                dut.controller.LOAD: begin
                    load_cycles_seen <= load_cycles_seen + 1;
                    if (!dut.loadingWeight_c)
                        fail("loadingWeight_c should be high in LOAD");
                    if (dut.validActivations)
                        fail("validActivations should be 0 in LOAD");
                    if ((dut.controller.counter == ARRAY_HEIGHT - 1) && (load_done !== 1'b1))
                        fail("load_done should assert on final LOAD cycle");
                    if ((dut.controller.counter != ARRAY_HEIGHT - 1) && (load_done !== 1'b0))
                        fail("load_done should only assert on final LOAD cycle");
                end

                dut.controller.RUN: begin
                    run_cycles_seen <= run_cycles_seen + 1;
                    if (dut.loadingWeight_c)
                        fail("loadingWeight_c should be 0 in RUN");
                    if (!dut.validActivations)
                        fail("validActivations should be high in RUN");
                    if (load_done !== 1'b0)
                        fail("load_done should be 0 in RUN");
                end

                dut.controller.DRAIN: begin
                    drain_cycles_seen <= drain_cycles_seen + 1;
                    if (dut.loadingWeight_c)
                        fail("loadingWeight_c should be 0 in DRAIN");
                    if (dut.validActivations)
                        fail("validActivations should be 0 in DRAIN");
                    if (load_done !== 1'b0)
                        fail("load_done should be 0 in DRAIN");
                end

                dut.controller.DONE: begin
                    done_cycles_seen <= done_cycles_seen + 1;
                end

                default: begin
                    fail("controller entered unknown state");
                end
            endcase

            if (start && !busy)
                accepted_start_count <= accepted_start_count + 1;

            // When the controller says RUN, the gated activation bus inside
            // SA_top should match the external activation bus exactly.
            if (dut.controller.ps == dut.controller.RUN) begin
                for (int row = 0; row < ARRAY_HEIGHT; row++) begin
                    if (dut.activationInputCol_gated[row] !== activationInputCol[row])
                        fail($sformatf("activationInputCol_gated[%0d] should match activationInputCol during RUN", row));
                end
            end

            // Outside RUN, the gated activation bus should be forced to zero.
            if ((dut.controller.ps != dut.controller.RUN)) begin
                for (int row = 0; row < ARRAY_HEIGHT; row++) begin
                    if (dut.activationInputCol_gated[row] !== '0)
                        fail($sformatf("gated activation[%0d] should be 0 outside RUN", row));
                end
            end

            if ((dut.controller.ps == dut.controller.LOAD) && (dut.controller.counter == ARRAY_HEIGHT - 1) &&
                (dut.controller.ns != dut.controller.RUN))
                fail("controller should transition from LOAD to RUN after final load cycle");

            if ((dut.controller.ps == dut.controller.RUN) && (dut.controller.counter == K_DIM - 1) &&
                (dut.controller.ns != dut.controller.DRAIN))
                fail("controller should transition from RUN to DRAIN after final activation cycle");

            if ((dut.controller.ps == dut.controller.DRAIN) &&
                (dut.controller.counter == ARRAY_HEIGHT + ARRAY_LENGTH - 3) &&
                (dut.controller.ns != dut.controller.DONE))
                fail("controller should transition from DRAIN to DONE after drain completes");
        end
    end

    // ------------------------------------------------
    // Main stimulus
    // ------------------------------------------------
    // This is written as a readable sequence of situations rather than one
    // giant block of low-level signal toggles. The monitor above still does the
    // detailed cycle-by-cycle checking in the background.
    initial begin
        fork
            begin
                #TIMEOUT_NS;
                $fatal(1, "TIMEOUT after %0d ns", TIMEOUT_NS);
            end
        join_none

        rst = 1'b1;
        start = 1'b0;
        error_count = 0;
        cycle_count = 0;
        transaction_count = 0;
        load_cycles_seen = 0;
        run_cycles_seen = 0;
        drain_cycles_seen = 0;
        done_cycles_seen = 0;
        accepted_start_count = 0;
        current_load_cycle = 0;
        current_run_cycle = 0;
        clear_dut_inputs();
        foreach (ref_weightInputRow[col])
            ref_weightInputRow[col] = '0;
        foreach (ref_activationInputCol[row])
            ref_activationInputCol[row] = '0;
        foreach (expected_result[col])
            expected_result[col] = '0;

        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        for (int col = 0; col < ARRAY_LENGTH; col++) begin
            if (MatrixMulOut[col] !== '0)
                fail($sformatf("output[%0d] should reset to 0", col));
        end
        if (busy !== 1'b0)
            fail("busy should be 0 after reset");

        // ------------------------------------------------
        // Transaction 0:
        // Start a normal run and make sure the visible outputs do not change
        // early while the array is still processing.
        // ------------------------------------------------
        start_transaction(0);
        snapshot_outputs();
        repeat (2) @(posedge clk);
        expect_outputs_hold("outputs should stay stable during active transaction");

        // Pulse start again while the controller is busy. This should be ignored.
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait_for_done_and_check("transaction 0");
        transaction_count = transaction_count + 1;
        snapshot_outputs();

        // After the transaction completes, the output register should hold
        // its result until the next accepted start.
        repeat (3) @(posedge clk);
        expect_outputs_hold("outputs should hold after done until next transaction");

        // ------------------------------------------------
        // Transaction 1:
        // Reset in the middle of a transaction, then restart cleanly.
        // ------------------------------------------------
        start_transaction(1);
        repeat (LOAD_CYCLES + 1) @(posedge clk);
        inject_reset_mid_transaction();

        start_transaction(1);
        wait_for_done_and_check("transaction 1 after reset");
        transaction_count = transaction_count + 1;
        snapshot_outputs();

        // ------------------------------------------------
        // Transaction 2:
        // Use a different matrix set and run again to make sure back-to-back
        // traffic still works after a previous reset/restart path.
        // ------------------------------------------------
        preload_next_case_data(0);
        weight_matrix = next_weight_matrix;
        activation_matrix = next_activation_matrix;
        clear_dut_inputs();
        current_load_cycle = 0;
        current_run_cycle = 0;

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait_for_done_and_check("transaction 2 back-to-back");
        transaction_count = transaction_count + 1;
        snapshot_outputs();

        if (transaction_count != 3)
            fail($sformatf("expected 3 completed transactions, saw %0d", transaction_count));

        if (error_count == 0) begin
            $display("PASS: SA_top_tb completed %0d transactions with comprehensive controller/datapath integration checks.",
                     transaction_count);
        end else begin
            $display("FAIL: SA_top_tb found %0d issue(s).", error_count);
            $fatal(1);
        end

        $finish;
    end

endmodule
