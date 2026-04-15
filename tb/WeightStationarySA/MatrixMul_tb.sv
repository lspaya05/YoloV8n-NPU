// -----------------------------------------------------------------------------
// MatrixMul_tb.sv
//   Directed testbench for MatrixMul (4x4 weight-stationary systolic array).
//   Run: do scripts/sim/runlab.do MatrixMul
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module MatrixMul_tb;

    // ── Parameters ───────────────────────────────────────────────────────────────
    localparam int FBW          = 8;
    localparam int ABW          = 32;
    localparam int AH           = 4;    // ARRAY_HEIGHT
    localparam int AL           = 4;    // ARRAY_LENGTH
    localparam int KDIM         = 4;    // activation stream depth
    localparam int DrainCycles  = AH + AL - 2;  // 6: last partial sum reaches bottom-right
    localparam int ClkHalfNs   = 5;
    localparam int TimeoutNs   = 100_000;

    // ── DUT signals ──────────────────────────────────────────────────────────────
    logic                  clk;
    logic                  rst;
    logic                  loadingWeight_c;
    logic signed [FBW-1:0] weightInputRow    [AL-1:0];
    logic signed [FBW-1:0] activationInputCol[AH-1:0];
    logic signed [ABW-1:0] MatrixMulOut      [AL-1:0];

    // ── Memory arrays ────────────────────────────────────────────────────────────
    //
    // TASK 1 — Memory layout + correct feed order
    //
    // weights.mem  : AH × AL row-major, one 8-bit hex entry per line.
    //   weight_mem[row * AL + col]  =  W[row][col]
    //
    // WEIGHT LOAD ORDER  (critical for correct PE assignment)
    //   Each clock with loadingWeight_c=1, PE row 0 latches weightInputRow and
    //   forwards it to row 1; row 1 latches what row 0 had the previous cycle,
    //   and so on.  So to end up with PE row i holding W[i][*]:
    //     edge 0  → present W[AH-1]  → row 0 latches W[AH-1]
    //     edge 1  → present W[AH-2]  → row 0 latches W[AH-2], row 1 latches W[AH-1]
    //     ...
    //     edge AH-1 → present W[0]   → row i latches W[i]  ✓
    //   t_load_weights() counts down: for (row = AH-1; row >= 0; row--)
    //
    // activations.mem : KDIM × AH, one 8-bit hex entry per line.
    //   act_mem[k * AH + r]  =  cycle k, PE row r
    //   Each streaming cycle drives activationInputCol[r] = act_mem[k*AH + r]
    //   for all AH rows simultaneously (col-by-col feed from activation matrix).
    //
    logic signed [FBW-1:0] weight_mem[AH*AL-1:0];
    logic signed [FBW-1:0] act_mem   [KDIM*AH-1:0];

    // ── Output capture ────────────────────────────────────────────────────────────
    //
    // TASK 3 — Concurrent capture via always_ff
    //   capture_en is raised at the start of the drain phase.
    //   On every posedge while capture_en is high, MatrixMulOut is latched into
    //   result[].  The final latch (last posedge of drain) holds the fully-settled
    //   values for all columns.
    //
    logic signed [ABW-1:0] result[AL-1:0];
    logic                  capture_en;

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
        .FORMAT_BITWIDTH     (FBW),
        .ACCUMULATOR_BITWIDTH(ABW),
        .ARRAY_HEIGHT        (AH),
        .ARRAY_LENGTH        (AL)
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
    always  #ClkHalfNs clk = ~clk;

    // ── TASK 1 / PHASE 1 : load weights ──────────────────────────────────────────
    //   Feeds AH weight rows in reverse order (AH-1 down to 0), one per clock.
    //   Sets feed_w high for the full duration so it is visible in waveforms.
    task automatic t_load_weights();
        feed_w          = 1'b1;
        loadingWeight_c = 1'b1;
        for (int row = AH-1; row >= 0; row--) begin
            for (int col = 0; col < AL; col++)
                weightInputRow[col] = weight_mem[row * AL + col];
            @(posedge clk);
        end
        loadingWeight_c = 1'b0;
        feed_w          = 1'b0;
        foreach (weightInputRow[j]) weightInputRow[j] = '0;
    endtask

    // ── TASK 2 / PHASE 2 : stream activations ────────────────────────────────────
    //   Feeds KDIM activation columns (one per clock), driving all AH rows at once.
    task automatic t_stream_acts();
        feed_a = 1'b1;
        for (int k = 0; k < KDIM; k++) begin
            for (int r = 0; r < AH; r++)
                activationInputCol[r] = act_mem[k * AH + r];
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
        repeat (DrainCycles) @(posedge clk);
    endtask

    // ── Main stimulus ─────────────────────────────────────────────────────────────
    int unsigned fail_count = 0;

    initial begin
        // Timeout watchdog
        fork begin
            #TimeoutNs;
            $error("TIMEOUT after %0d ns", TimeoutNs);
            $finish;
        end join_none

        // Load memory files (paths relative to project root)
        $readmemh("tb/data/weights.mem",     weight_mem);
        $readmemh("tb/data/activations.mem", act_mem);

        // Init signals
        rst              = 1'b1;
        loadingWeight_c  = 1'b0;
        capture_en       = 1'b0;
        feed_w           = 1'b0;
        feed_a           = 1'b0;
        foreach (weightInputRow[j])     weightInputRow[j]     = '0;
        foreach (activationInputCol[r]) activationInputCol[r] = '0;
        foreach (result[j])             result[j]             = '0;

        // Reset — 2 cycles asserted, then release
        repeat (2) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // ── PHASE 1 : LOAD WEIGHTS ───────────────────────────────────────────────
        $display("[PHASE 1] load weights  — %0d cycles (row %0d first)", AH, AH-1);
        t_load_weights();
        $display("[PHASE 1] done");

        // ── PHASE 2 : STREAM ACTIVATIONS ─────────────────────────────────────────
        $display("[PHASE 2] stream acts   — %0d cycles", KDIM);
        t_stream_acts();
        $display("[PHASE 2] done");

        // ── PHASE 3 : DRAIN ───────────────────────────────────────────────────────
        $display("[PHASE 3] drain         — %0d cycles", DrainCycles);
        capture_en = 1'b1;      // enable concurrent capture during drain
        t_drain();
        capture_en = 1'b0;
        $display("[PHASE 3] done");

        // ── Display captured result ───────────────────────────────────────────────
        $display("------------------------------------------------------------");
        $display("MatrixMulOut  captured at end of drain:");
        for (int j = 0; j < AL; j++)
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

`default_nettype wire
