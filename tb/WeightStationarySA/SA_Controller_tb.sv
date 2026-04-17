`timescale 1ns/1ps

module SA_Controller_tb();

    // ------------------------------------------------
    // Parameters for the controller instance
    // ------------------------------------------------
    localparam int ARRAY_HEIGHT = 16;
    localparam int ARRAY_LENGTH = 16;
    localparam int K_DIM        = 4;

    localparam int EXPECT_LOAD_CYCLES  = ARRAY_HEIGHT;
    localparam int EXPECT_RUN_CYCLES   = K_DIM;
    localparam int EXPECT_DRAIN_CYCLES = ARRAY_HEIGHT + ARRAY_LENGTH - 2;
    localparam int CLK_HALF_NS         = 5;
    localparam int TIMEOUT_NS          = 50_000;

    // ------------------------------------------------
    // DUT interface signals
    // ------------------------------------------------
    logic clk;
    logic rst;
    logic start;

    logic loadingWeight_c;
    logic validActivations;
    logic load_done;
    logic done;
    logic busy;

    // ------------------------------------------------
    // Scoreboard / bookkeeping
    // ------------------------------------------------
    int cycle_count;
    int error_count;
    int transaction_count;

    int load_cycles_seen;
    int run_cycles_seen;
    int drain_cycles_seen;
    int done_cycles_seen;

    int accepted_start_count;
    int ignored_start_count;

    // ------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------
    SA_Controller #(
        .ARRAY_HEIGHT(ARRAY_HEIGHT),
        .ARRAY_LENGTH(ARRAY_LENGTH),
        .K_DIM(K_DIM)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .loadingWeight_c(loadingWeight_c),
        .validActivations(validActivations),
        .load_done(load_done),
        .done(done),
        .busy(busy)
    );

    // ------------------------------------------------
    // Simulated clock
    // ------------------------------------------------
    initial clk = 1'b0;
    always #CLK_HALF_NS clk = ~clk;

    // ------------------------------------------------
    // Helper tasks
    // ------------------------------------------------
    task automatic fail;
        input string message;
        begin
            error_count = error_count + 1;
            $display("FAIL at cycle %0d: %0s", cycle_count, message);
        end
    endtask

    task automatic check_outputs;
        input logic expect_load;
        input logic expect_valid;
        input logic expect_load_done;
        input logic expect_done;
        input logic expect_busy;
        input string label;
        begin
            if (loadingWeight_c !== expect_load)
                fail($sformatf("%0s: loadingWeight_c expected %0b got %0b", label, expect_load, loadingWeight_c));
            if (validActivations !== expect_valid)
                fail($sformatf("%0s: validActivations expected %0b got %0b", label, expect_valid, validActivations));
            if (load_done !== expect_load_done)
                fail($sformatf("%0s: load_done expected %0b got %0b", label, expect_load_done, load_done));
            if (done !== expect_done)
                fail($sformatf("%0s: done expected %0b got %0b", label, expect_done, done));
            if (busy !== expect_busy)
                fail($sformatf("%0s: busy expected %0b got %0b", label, expect_busy, busy));
        end
    endtask

    task automatic apply_reset;
        input string label;
        begin
            $display("");
            $display("// ------------------------------------------------");
            $display("// %0s", label);
            $display("// ------------------------------------------------");

            rst   = 1'b1;
            start = 1'b0;
            @(posedge clk);
            @(posedge clk);
            rst = 1'b0;
            @(posedge clk);

            if (dut.ps !== dut.IDLE)
                fail($sformatf("%0s: controller should return to IDLE after reset", label));
            if (dut.counter !== 0)
                fail($sformatf("%0s: counter should be 0 after reset", label));
            check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, label);
        end
    endtask

    task automatic pulse_start;
        input string label;
        begin
            $display("%0s", label);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
        end
    endtask

    task automatic hold_start_for_cycles;
        input int hold_cycles;
        input string label;
        begin
            $display("%0s", label);
            start = 1'b1;
            repeat (hold_cycles) @(posedge clk);
            start = 1'b0;
        end
    endtask

    task automatic expect_idle_cycles;
        input int cycles_to_watch;
        input string label;
        begin
            repeat (cycles_to_watch) begin
                @(posedge clk);
                if (dut.ps !== dut.IDLE)
                    fail($sformatf("%0s: expected IDLE state", label));
                if (dut.counter !== 0)
                    fail($sformatf("%0s: counter should stay 0 in IDLE", label));
                check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, label);
            end
        end
    endtask

    task automatic expect_load_phase;
        input string label;
        begin
            for (int i = 0; i < EXPECT_LOAD_CYCLES; i++) begin
                @(posedge clk);
                if (dut.ps !== dut.LOAD)
                    fail($sformatf("%0s: expected LOAD state on load cycle %0d", label, i));
                if (dut.counter !== i)
                    fail($sformatf("%0s: LOAD counter expected %0d got %0d", label, i, dut.counter));

                if (i == EXPECT_LOAD_CYCLES - 1)
                    check_outputs(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, label);
                else
                    check_outputs(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, label);
            end
        end
    endtask

    task automatic expect_run_phase;
        input string label;
        begin
            for (int i = 0; i < EXPECT_RUN_CYCLES; i++) begin
                @(posedge clk);
                if (dut.ps !== dut.RUN)
                    fail($sformatf("%0s: expected RUN state on run cycle %0d", label, i));
                if (dut.counter !== i)
                    fail($sformatf("%0s: RUN counter expected %0d got %0d", label, i, dut.counter));
                check_outputs(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, label);
            end
        end
    endtask

    task automatic expect_drain_phase;
        input string label;
        begin
            for (int i = 0; i < EXPECT_DRAIN_CYCLES; i++) begin
                @(posedge clk);
                if (dut.ps !== dut.DRAIN)
                    fail($sformatf("%0s: expected DRAIN state on drain cycle %0d", label, i));
                if (dut.counter !== i)
                    fail($sformatf("%0s: DRAIN counter expected %0d got %0d", label, i, dut.counter));
                check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, label);
            end
        end
    endtask

    task automatic expect_done_cycle;
        input string label;
        begin
            @(posedge clk);
            if (dut.ps !== dut.DONE)
                fail($sformatf("%0s: expected DONE state", label));
            if (dut.counter !== 0)
                fail($sformatf("%0s: counter should be 0 in DONE", label));
            check_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, label);

            @(posedge clk);
            if (dut.ps !== dut.IDLE)
                fail($sformatf("%0s: expected return to IDLE after DONE", label));
            if (dut.counter !== 0)
                fail($sformatf("%0s: counter should return to 0 after DONE", label));
            check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, label);
        end
    endtask

    task automatic run_full_transaction;
        input string label;
        begin
            $display("");
            $display("// ------------------------------------------------");
            $display("// %0s", label);
            $display("// ------------------------------------------------");

            pulse_start("Start one clean transaction");
            expect_load_phase({label, " / LOAD"});
            expect_run_phase({label, " / RUN"});
            expect_drain_phase({label, " / DRAIN"});
            expect_done_cycle({label, " / DONE"});
        end
    endtask

    task automatic wait_for_done_then_idle;
        input string label;
        begin
            wait (dut.ps == dut.DONE);
            @(posedge clk);
            #1ps;
            if (dut.ps !== dut.IDLE)
                fail($sformatf("%0s: expected return to IDLE after DONE", label));
            check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, label);
        end
    endtask

    task automatic start_during_busy_should_be_ignored;
        input int phase_select;
        input string label;
        begin
            $display("");
            $display("// ------------------------------------------------");
            $display("// %0s", label);
            $display("// ------------------------------------------------");

            pulse_start("Start transaction");

            case (phase_select)
                0: begin
                    @(posedge clk);
                    if (dut.ps !== dut.LOAD)
                        fail("Expected LOAD before testing busy start in LOAD");
                    pulse_start("Issue another start pulse while in LOAD");
                    wait_for_done_then_idle(label);
                end

                1: begin
                    expect_load_phase({label, " / LOAD"});
                    @(posedge clk);
                    if (dut.ps !== dut.RUN)
                        fail("Expected RUN before testing busy start in RUN");
                    pulse_start("Issue another start pulse while in RUN");
                    wait_for_done_then_idle(label);
                end

                2: begin
                    expect_load_phase({label, " / LOAD"});
                    expect_run_phase({label, " / RUN"});
                    @(posedge clk);
                    if (dut.ps !== dut.DRAIN)
                        fail("Expected DRAIN before testing busy start in DRAIN");
                    pulse_start("Issue another start pulse while in DRAIN");
                    wait_for_done_then_idle(label);
                end

                default: begin
                    fail("Unsupported phase_select in start_during_busy_should_be_ignored");
                end
            endcase
        end
    endtask

    task automatic reset_mid_phase;
        input int phase_select;
        input string label;
        begin
            $display("");
            $display("// ------------------------------------------------");
            $display("// %0s", label);
            $display("// ------------------------------------------------");

            pulse_start("Start transaction before reset injection");

            case (phase_select)
                0: begin
                    @(posedge clk);
                    if (dut.ps !== dut.LOAD)
                        fail("Expected LOAD before reset-in-LOAD");
                end

                1: begin
                    expect_load_phase({label, " / pre-reset LOAD"});
                    @(posedge clk);
                    if (dut.ps !== dut.RUN)
                        fail("Expected RUN before reset-in-RUN");
                end

                2: begin
                    expect_load_phase({label, " / pre-reset LOAD"});
                    expect_run_phase({label, " / pre-reset RUN"});
                    @(posedge clk);
                    if (dut.ps !== dut.DRAIN)
                        fail("Expected DRAIN before reset-in-DRAIN");
                end

                default: begin
                    fail("Unsupported phase_select in reset_mid_phase");
                end
            endcase

            rst = 1'b1;
            @(posedge clk);
            @(posedge clk);
            rst = 1'b0;
            @(posedge clk);

            if (dut.ps !== dut.IDLE)
                fail($sformatf("%0s: controller should return to IDLE after reset", label));
            if (dut.counter !== 0)
                fail($sformatf("%0s: counter should clear after reset", label));
            check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, label);
        end
    endtask

    // ------------------------------------------------
    // Continuous protocol checks
    // ------------------------------------------------
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (start) begin
            if (dut.ps == dut.IDLE)
                accepted_start_count <= accepted_start_count + 1;
            else
                ignored_start_count <= ignored_start_count + 1;
        end

        if (!rst) begin
            if (loadingWeight_c && validActivations)
                fail("loadingWeight_c and validActivations should never be high together");

            case (dut.ps)
                dut.IDLE: begin
                    if (dut.ns != dut.IDLE && dut.ns != dut.LOAD)
                        fail("IDLE should only remain IDLE or move to LOAD");
                end

                dut.LOAD: begin
                    load_cycles_seen <= load_cycles_seen + 1;
                    if (dut.counter >= EXPECT_LOAD_CYCLES)
                        fail("LOAD counter exceeded legal range");
                    if ((dut.counter == EXPECT_LOAD_CYCLES - 1) && !load_done)
                        fail("load_done should assert on final LOAD cycle");
                    if ((dut.counter != EXPECT_LOAD_CYCLES - 1) && load_done)
                        fail("load_done asserted too early in LOAD");
                end

                dut.RUN: begin
                    run_cycles_seen <= run_cycles_seen + 1;
                    if (dut.counter >= EXPECT_RUN_CYCLES)
                        fail("RUN counter exceeded legal range");
                    if (load_done)
                        fail("load_done must be low in RUN");
                end

                dut.DRAIN: begin
                    drain_cycles_seen <= drain_cycles_seen + 1;
                    if (dut.counter >= EXPECT_DRAIN_CYCLES)
                        fail("DRAIN counter exceeded legal range");
                    if (load_done)
                        fail("load_done must be low in DRAIN");
                end

                dut.DONE: begin
                    done_cycles_seen <= done_cycles_seen + 1;
                    transaction_count <= transaction_count + 1;
                end

                default: begin
                    fail("Controller entered an unknown state");
                end
            endcase

            if ((dut.ps == dut.LOAD) && (dut.ns == dut.RUN) && !load_done)
                fail("LOAD should only transition to RUN when load_done is high");

            if ((dut.ps == dut.RUN) && (dut.ns == dut.DRAIN) && (dut.counter != EXPECT_RUN_CYCLES - 1))
                fail("RUN should only transition to DRAIN on the final RUN cycle");

            if ((dut.ps == dut.DRAIN) && (dut.ns == dut.DONE) && (dut.counter != EXPECT_DRAIN_CYCLES - 1))
                fail("DRAIN should only transition to DONE on the final DRAIN cycle");

            if ((dut.ps == dut.DONE) && (dut.ns != dut.IDLE))
                fail("DONE should always transition back to IDLE");
        end
    end

    // ------------------------------------------------
    // Main stimulus
    // ------------------------------------------------
    initial begin
        fork
            begin
                #TIMEOUT_NS;
                $fatal(1, "TIMEOUT after %0d ns", TIMEOUT_NS);
            end
        join_none

        rst = 1'b0;
        start = 1'b0;

        cycle_count = 0;
        error_count = 0;
        transaction_count = 0;
        load_cycles_seen = 0;
        run_cycles_seen = 0;
        drain_cycles_seen = 0;
        done_cycles_seen = 0;
        accepted_start_count = 0;
        ignored_start_count = 0;

        // ------------------------------------------------
        // Situation 1:
        // Reset into IDLE and verify the controller stays quiet
        // ------------------------------------------------
        apply_reset("Situation 1: reset and idle sanity");
        expect_idle_cycles(2, "Situation 1: hold idle for two extra cycles");

        // ------------------------------------------------
        // Situation 2:
        // One clean transaction with exact LOAD/RUN/DRAIN/DONE timing
        // ------------------------------------------------
        run_full_transaction("Situation 2: nominal transaction");

        // ------------------------------------------------
        // Situation 3:
        // Another start pulse arrives while the controller is busy in LOAD
        // It must be ignored
        // ------------------------------------------------
        start_during_busy_should_be_ignored(0, "Situation 3: ignore start while in LOAD");

        // ------------------------------------------------
        // Situation 4:
        // Another start pulse arrives while the controller is busy in RUN
        // It must be ignored
        // ------------------------------------------------
        start_during_busy_should_be_ignored(1, "Situation 4: ignore start while in RUN");

        // ------------------------------------------------
        // Situation 5:
        // Another start pulse arrives while the controller is busy in DRAIN
        // It must be ignored
        // ------------------------------------------------
        start_during_busy_should_be_ignored(2, "Situation 5: ignore start while in DRAIN");

        // ------------------------------------------------
        // Situation 6:
        // Hold start high for multiple cycles from IDLE
        // The controller should start once and keep progressing normally
        // ------------------------------------------------
        $display("");
        $display("// ------------------------------------------------");
        $display("// Situation 6: hold start high for multiple cycles");
        $display("// ------------------------------------------------");
        hold_start_for_cycles(3, "Hold start high for three clocks");
        wait_for_done_then_idle("Situation 6");

        // ------------------------------------------------
        // Situation 7:
        // Reset in the middle of LOAD
        // ------------------------------------------------
        reset_mid_phase(0, "Situation 7: reset during LOAD");

        // ------------------------------------------------
        // Situation 8:
        // Reset in the middle of RUN
        // ------------------------------------------------
        reset_mid_phase(1, "Situation 8: reset during RUN");

        // ------------------------------------------------
        // Situation 9:
        // Reset in the middle of DRAIN
        // ------------------------------------------------
        reset_mid_phase(2, "Situation 9: reset during DRAIN");

        // ------------------------------------------------
        // Situation 10:
        // Start immediately after a reset-recovery idle cycle
        // ------------------------------------------------
        run_full_transaction("Situation 10: transaction after reset recovery");

        // ------------------------------------------------
        // Situation 11:
        // Start pulse during DONE should be ignored because DONE always returns to IDLE
        // ------------------------------------------------
        $display("");
        $display("// ------------------------------------------------");
        $display("// Situation 11: start pulse during DONE");
        $display("// ------------------------------------------------");
        pulse_start("Start transaction");
        expect_load_phase("Situation 11 / LOAD");
        expect_run_phase("Situation 11 / RUN");
        expect_drain_phase("Situation 11 / DRAIN");
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        if (dut.ps !== dut.DONE)
            fail("Situation 11: expected DONE while issuing start pulse");
        check_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, "Situation 11 / DONE");
        @(posedge clk);
        if (dut.ps !== dut.IDLE)
            fail("Situation 11: expected return to IDLE after DONE");
        expect_idle_cycles(1, "Situation 11: verify no auto-restart after DONE start pulse");

        // ------------------------------------------------
        // Final summary
        // ------------------------------------------------
        $display("");
        $display("Summary:");
        $display("  Transactions completed = %0d", transaction_count);
        $display("  LOAD cycles seen       = %0d", load_cycles_seen);
        $display("  RUN cycles seen        = %0d", run_cycles_seen);
        $display("  DRAIN cycles seen      = %0d", drain_cycles_seen);
        $display("  DONE cycles seen       = %0d", done_cycles_seen);
        $display("  Accepted starts        = %0d", accepted_start_count);
        $display("  Ignored starts         = %0d", ignored_start_count);

        if (transaction_count != 7)
            fail($sformatf("Expected 7 completed transactions, saw %0d", transaction_count));

        if (done_cycles_seen != transaction_count)
            fail("DONE should pulse exactly once per completed transaction");

        if (accepted_start_count != 10)
            fail($sformatf("Expected 10 accepted start observations, saw %0d", accepted_start_count));

        if (ignored_start_count != 6)
            fail($sformatf("Expected 6 ignored start observations, saw %0d", ignored_start_count));

        if (error_count == 0) begin
            $display("PASS: SA_Controller comprehensive FSM checks passed.");
        end else begin
            $display("FAIL: SA_Controller_tb found %0d issue(s).", error_count);
            $fatal(1);
        end

        $finish;
    end

endmodule
