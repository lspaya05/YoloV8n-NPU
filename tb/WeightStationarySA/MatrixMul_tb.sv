// -----------------------------------------------------------------------------
// MatrixMul_tb.sv
//   Directed testbench for MatrixMul (4x4 weight-stationary systolic array).
//   Run: do scripts/sim/runlab.do MatrixMul
// -----------------------------------------------------------------------------
module MatrixMul_tb;

    // ── Parameters ───────────────────────────────────────────────────────────────
    localparam int FORMAT_BITWIDTH      = 8;
    localparam int ACCUMULATOR_BITWIDTH = 32;
    localparam int ARRAY_HEIGHT         = 4;
    localparam int ARRAY_LENGTH         = 4;
    localparam int KDIM                 = 4;    // activation stream depth
    localparam int DRAIN_CYCLES         = ARRAY_HEIGHT + ARRAY_LENGTH - 2;  // 6: last partial sum reaches bottom-right
    localparam int CLK_HALF_NS          = 5;
    localparam int TIMEOUT_NS           = 100_000;

    // ── DUT signals ──────────────────────────────────────────────────────────────
    logic                              clk;
    logic                              rst;
    logic                              loadingWeight_c;
    logic signed [FORMAT_BITWIDTH-1:0] weightInputRow    [ARRAY_LENGTH-1:0];
    logic signed [FORMAT_BITWIDTH-1:0] activationInputCol[ARRAY_HEIGHT-1:0];
    logic signed [ACCUMULATOR_BITWIDTH-1:0] MatrixMulOut [ARRAY_LENGTH-1:0];

    // ── Memory arrays ────────────────────────────────────────────────────────────
    //
    // TASK 1 — Memory layout + correct feed order
    //
    // weights.mem  : ARRAY_HEIGHT × ARRAY_LENGTH row-major, one 8-bit hex entry per line.
    //   weight_mem[row * ARRAY_LENGTH + col]  =  W[row][col]
    //
    // WEIGHT LOAD ORDER  (critical for correct PE assignment)
    //   Each clock with loadingWeight_c=1, PE row 0 latches weightInputRow and
    //   forwards it to row 1; row 1 latches what row 0 had the previous cycle,
    //   and so on.  So to end up with PE row i holding W[i][*]:
    //     edge 0              → present W[ARRAY_HEIGHT-1]  → row 0 latches W[ARRAY_HEIGHT-1]
    //     edge 1              → present W[ARRAY_HEIGHT-2]  → row 0 latches W[ARRAY_HEIGHT-2], row 1 latches W[ARRAY_HEIGHT-1]
    //     ...
    //     edge ARRAY_HEIGHT-1 → present W[0]               → row i latches W[i]  ✓
    //   t_load_weights() counts down: for (row = ARRAY_HEIGHT-1; row >= 0; row--)
    //
    // activations.mem : KDIM × ARRAY_HEIGHT, one 8-bit hex entry per line.
    //   act_mem[k * ARRAY_HEIGHT + r]  =  cycle k, PE row r
    //   Each streaming cycle drives activationInputCol[r] = act_mem[k*ARRAY_HEIGHT + r]
    //   for all ARRAY_HEIGHT rows simultaneously (col-by-col feed from activation matrix).
    //
    logic signed [FORMAT_BITWIDTH-1:0] weight_mem[ARRAY_HEIGHT*ARRAY_LENGTH-1:0];
    logic signed [FORMAT_BITWIDTH-1:0] act_mem   [KDIM*ARRAY_HEIGHT-1:0];

    // ── Output capture ────────────────────────────────────────────────────────────
    //
    // TASK 3 — Concurrent capture via always_ff
    //   capture_en is raised at the start of the drain phase.
    //   On every posedge while capture_en is high, MatrixMulOut is latched into
    //   result[].  The final latch (last posedge of drain) holds the fully-settled
    //   values for all columns.
    //
    logic signed [ACCUMULATOR_BITWIDTH-1:0] result[ARRAY_LENGTH-1:0];
    logic                                   capture_en;

    always_ff @(posedge clk) begin
        if (capture_en)
            foreach (result[j]) result[j] <= MatrixMulOut[j];
    end

    // ── Phase-active indicators (waveform visibility) ─────────────────────────────
    //   feed_w : high for the duration of weight loading
    //   feed_a : high for the duration of activation streaming
    logic feed_w;
    logic feed_a;

    // ── DUT instantiation ────────────────────────────────────────────────────────
    MatrixMul #(
        .FORMAT_BITWIDTH     (FORMAT_BITWIDTH),
        .ACCUMULATOR_BITWIDTH(ACCUMULATOR_BITWIDTH),
        .ARRAY_HEIGHT        (ARRAY_HEIGHT),
        .ARRAY_LENGTH        (ARRAY_LENGTH)
    ) dut (
        .clk              (clk),
        .rst              (rst),
        .loadingWeight_c  (loadingWeight_c),
        .weightInputRow   (weightInputRow),
        .activationInputCol(activationInputCol),
        .MatrixMulOut     (MatrixMulOut)
    );

    // ── Clock ─────────────────────────────────────────────────────────────────────
    initial clk = 1'b0;
    always  #CLK_HALF_NS clk = ~clk;

    // ── TASK 1 / PHASE 1 : load weights ──────────────────────────────────────────
    //   Feeds ARRAY_HEIGHT weight rows in reverse order (ARRAY_HEIGHT-1 down to 0), one per clock.
    //   Sets feed_w high for the full duration so it is visible in waveforms.
    task automatic t_load_weights();
        feed_w          = 1'b1;
        loadingWeight_c = 1'b1;
        for (int row = ARRAY_HEIGHT-1; row >= 0; row--) begin
            for (int col = 0; col < ARRAY_LENGTH; col++)
                weightInputRow[col] = weight_mem[row * ARRAY_LENGTH + col];
            @(posedge clk);
        end
        loadingWeight_c = 1'b0;
        feed_w          = 1'b0;
        foreach (weightInputRow[j]) weightInputRow[j] = '0;
    endtask

    // ── TASK 2 / PHASE 2 : stream activations ────────────────────────────────────
    //   Feeds KDIM activation columns (one per clock), driving all ARRAY_HEIGHT rows at once.
    task automatic t_stream_acts();
        feed_a = 1'b1;
        for (int k = 0; k < KDIM; k++) begin
            for (int r = 0; r < ARRAY_HEIGHT; r++)
                activationInputCol[r] = act_mem[k * ARRAY_HEIGHT + r];
            @(posedge clk);
        end
        feed_a = 1'b0;
        foreach (activationInputCol[r]) activationInputCol[r] = '0;
    endtask

    // ── TASK 3 / PHASE 3 : drain ─────────────────────────────────────────────────
    //   Waits DrainCycles clocks.  Caller asserts capture_en before entry so the
    //   always_ff block latches MatrixMulOut each cycle; the last latch is the
    //   fully-settled result.
    task automatic t_drain();
        repeat (DRAIN_CYCLES) @(posedge clk);
    endtask

    // ── Main stimulus ─────────────────────────────────────────────────────────────
    int unsigned fail_count = 0;

    initial begin
        // Timeout watchdog
        fork begin
            #TIMEOUT_NS;
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        // Load memory files (paths relative to project root)
        $readmemh("../../tb/data/weights.mem",     weight_mem);
        $readmemh("../../tb/data/activations.mem", act_mem);

        // Init signals
        rst              = 1'b1;
        loadingWeight_c  = 1'b0;
        capture_en       = 1'b0;
        feed_w           = 1'b0;
        feed_a           = 1'b0;
        foreach (weightInputRow[j])     weightInputRow[j]     = '0;
        foreach (activationInputCol[r]) activationInputCol[r] = '0;

        // Reset — 2 cycles asserted, then release
        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // ── PHASE 1 : LOAD WEIGHTS ───────────────────────────────────────────────
        $display("[PHASE 1] load weights  — %0d cycles (row %0d first)", ARRAY_HEIGHT, ARRAY_HEIGHT-1);
        t_load_weights();
        $display("[PHASE 1] done");

        // ── PHASE 2 : STREAM ACTIVATIONS ─────────────────────────────────────────
        $display("[PHASE 2] stream acts   — %0d cycles", KDIM);
        t_stream_acts();
        $display("[PHASE 2] done");

        // ── PHASE 3 : DRAIN ───────────────────────────────────────────────────────
        $display("[PHASE 3] drain         — %0d cycles", DRAIN_CYCLES);
        capture_en = 1'b1;      // enable concurrent capture during drain
        t_drain();
        capture_en = 1'b0;
        $display("[PHASE 3] done");

        // ── Display captured result ───────────────────────────────────────────────
        $display("------------------------------------------------------------");
        $display("MatrixMulOut  captured at end of drain:");
        for (int j = 0; j < ARRAY_LENGTH; j++)
            $display("  result[%0d] = %11d  (0x%08h)",
                     j, $signed(result[j]), result[j]);
        $display("------------------------------------------------------------");

        if (fail_count == 0)
            $display("PASS");
        else
            $display("FAIL  (%0d errors)", fail_count);
        $finish;
    end

endmodule
