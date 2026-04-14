`timescale 1ns/1ps

module SA_Controller_tb;
    localparam int ARRAY_HEIGHT = 4;
    localparam int ARRAY_LENGTH = 5;
    localparam int K_DIM        = 4;

    localparam int EXPECT_LOAD_CYCLES  = ARRAY_HEIGHT;
    localparam int EXPECT_RUN_CYCLES   = K_DIM;
    localparam int EXPECT_DRAIN_CYCLES = ARRAY_HEIGHT + ARRAY_LENGTH - 2;

    logic clk;
    logic rst;
    logic start;

    logic loadingWeight_c;
    logic validActivations;
    logic load_done;
    logic done;
    logic busy;

    int cycle_count;
    int load_cycles_seen;
    int run_cycles_seen;
    int drain_cycles_seen;
    int done_cycles_seen;
    int transaction_count;
    int error_count;

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

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic fail;
        input [255:0] message;
        begin
            error_count = error_count + 1;
            $display("FAIL at cycle %0d: %0s", cycle_count, message);
        end
    endtask

    task automatic check_idle_outputs;
        begin
            if (loadingWeight_c !== 0)
                fail("loadingWeight_c should be 0 in IDLE");
            if (validActivations !== 0)
                fail("validActivations should be 0 in IDLE");
            if (done !== 0)
                fail("done should be 0 in IDLE");
            if (busy !== 0)
                fail("busy should be 0 in IDLE");
            if (dut.counter !== 0)
                fail("counter should stay at 0 in IDLE");
        end
    endtask

    task automatic check_load_outputs;
        begin
            if (loadingWeight_c !== 1)
                fail("loadingWeight_c should be 1 in LOAD for MatrixMul weight loading");
            if (validActivations !== 0)
                fail("validActivations should be 0 in LOAD");
            if (done !== 0)
                fail("done should be 0 in LOAD");
            if (busy !== 1)
                fail("busy should be 1 in LOAD");
        end
    endtask

    task automatic check_run_outputs;
        begin
            if (loadingWeight_c !== 0)
                fail("loadingWeight_c should be 0 in RUN");
            if (validActivations !== 1)
                fail("validActivations should be 1 in RUN for MatrixMul activations");
            if (done !== 0)
                fail("done should be 0 in RUN");
            if (busy !== 1)
                fail("busy should be 1 in RUN");
        end
    endtask

    task automatic check_drain_outputs;
        begin
            if (loadingWeight_c !== 0)
                fail("loadingWeight_c should be 0 in DRAIN");
            if (validActivations !== 0)
                fail("validActivations should be 0 in DRAIN");
            if (done !== 0)
                fail("done should be 0 in DRAIN");
            if (busy !== 1)
                fail("busy should be 1 in DRAIN");
        end
    endtask

    task automatic check_done_outputs;
        begin
            if (loadingWeight_c !== 0)
                fail("loadingWeight_c should be 0 in DONE");
            if (validActivations !== 0)
                fail("validActivations should be 0 in DONE");
            if (done !== 1)
                fail("done should be 1 in DONE");
            if (busy !== 0)
                fail("busy should be 0 in DONE");
            if (dut.counter !== 0)
                fail("counter should reset to 0 in DONE");
        end
    endtask

    task automatic pulse_start;
        begin
            start = 1;
            @(posedge clk);
            start = 0;
        end
    endtask

    task automatic issue_busy_start_pulse;
        begin
            start = 1;
            @(posedge clk);
            start = 0;
        end
    endtask

    initial begin
        rst = 1;
        start = 0;
        cycle_count = 0;
        load_cycles_seen = 0;
        run_cycles_seen = 0;
        drain_cycles_seen = 0;
        done_cycles_seen = 0;
        transaction_count = 0;
        error_count = 0;

        repeat (2) @(posedge clk);
        rst = 0;

        repeat (2) @(posedge clk);
        pulse_start();

        repeat (2) @(posedge clk);
        issue_busy_start_pulse();

        wait (done == 1);
        @(posedge clk);

        repeat (2) @(posedge clk);
        pulse_start();

        wait (done == 1);
        @(posedge clk);

        repeat (2) @(posedge clk);

        $display("");
        $display("Summary:");
        $display("  Transactions completed = %0d", transaction_count);
        $display("  LOAD cycles seen       = %0d", load_cycles_seen);
        $display("  RUN cycles seen        = %0d", run_cycles_seen);
        $display("  DRAIN cycles seen      = %0d", drain_cycles_seen);
        $display("  DONE cycles seen       = %0d", done_cycles_seen);

        if (transaction_count != 2)
            fail("expected exactly 2 completed transactions");

        if (load_cycles_seen != 2 * EXPECT_LOAD_CYCLES)
            fail("unexpected total LOAD cycle count");

        if (run_cycles_seen != 2 * EXPECT_RUN_CYCLES)
            fail("unexpected total RUN cycle count");

        if (drain_cycles_seen != 2 * EXPECT_DRAIN_CYCLES)
            fail("unexpected total DRAIN cycle count");

        if (done_cycles_seen != 2)
            fail("DONE should last one cycle per transaction");

        if (error_count == 0) begin
            $display("PASS: SA_Controller FSM and counter checks passed.");
        end else begin
            $display("FAIL: SA_Controller_tb found %0d issue(s).", error_count);
            $fatal(1);
        end

        $finish;
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (rst) begin
            if (dut.ps != dut.IDLE)
                fail("controller should reset into IDLE");
            if (dut.counter != 0)
                fail("counter should reset to 0");
        end else begin
            if (loadingWeight_c && validActivations)
                fail("loadingWeight_c and validActivations should never be high together");

            case (dut.ps)
                dut.IDLE: begin
                    check_idle_outputs();
                    if (load_done)
                        fail("load_done should not assert in IDLE");
                end

                dut.LOAD: begin
                    check_load_outputs();
                    load_cycles_seen <= load_cycles_seen + 1;

                    if (dut.counter >= ARRAY_HEIGHT)
                        fail("counter exceeded expected LOAD range");

                    if ((dut.counter == ARRAY_HEIGHT - 1) && !load_done)
                        fail("load_done should assert on final LOAD cycle");

                    if ((dut.counter != ARRAY_HEIGHT - 1) && load_done)
                        fail("load_done asserted too early in LOAD");
                end

                dut.RUN: begin
                    check_run_outputs();
                    run_cycles_seen <= run_cycles_seen + 1;

                    if (load_done)
                        fail("load_done should not assert in RUN");

                    if (dut.counter >= K_DIM)
                        fail("counter exceeded expected RUN range");
                end

                dut.DRAIN: begin
                    check_drain_outputs();
                    drain_cycles_seen <= drain_cycles_seen + 1;

                    if (load_done)
                        fail("load_done should not assert in DRAIN");

                    if (dut.counter >= EXPECT_DRAIN_CYCLES)
                        fail("counter exceeded expected DRAIN range");
                end

                dut.DONE: begin
                    check_done_outputs();
                    done_cycles_seen <= done_cycles_seen + 1;
                    transaction_count <= transaction_count + 1;
                end

                default: begin
                    fail("controller entered an unknown state");
                end
            endcase

            if ((dut.ps != dut.ns) && (dut.ns == dut.LOAD) && busy)
                fail("controller should not accept a new transaction while busy");

            if ((dut.ps == dut.LOAD) && (dut.ns == dut.RUN) && !load_done)
                fail("LOAD should only exit when load_done is high");

            if ((dut.ps == dut.RUN) && (dut.ns == dut.DRAIN) && (dut.counter != K_DIM - 1))
                fail("RUN should last exactly K_DIM cycles");

            if ((dut.ps == dut.DRAIN) && (dut.ns == dut.DONE) && (dut.counter != EXPECT_DRAIN_CYCLES - 1))
                fail("DRAIN should last ARRAY_HEIGHT + ARRAY_LENGTH - 2 cycles");
        end

        $display("cycle=%0d ps=%0d ns=%0d counter=%0d start=%0b load=%0b valid=%0b load_done=%0b done=%0b busy=%0b",
                 cycle_count, dut.ps, dut.ns, dut.counter, start,
                 loadingWeight_c, validActivations, load_done, done, busy);
    end

endmodule
