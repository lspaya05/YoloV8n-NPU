# Directed Testbench Template

Copy-paste skeleton. Replace `<module>` with the DUT module name. Save as `tb/<module>_testbench.sv`. Save the matching wave file as `scripts/waves/<module>_wave.do`.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## `tb/<module>_testbench.sv`

```sv
// -----------------------------------------------------------------------------
// <module>_testbench.sv
//   Directed self-checking testbench for <module>.
//   Compatible with scripts/sim/runlab.do — invoke as:
//       do scripts/sim/runlab.do <module>
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module <module>_testbench;

    // ---- Parameters ----------------------------------------------------------
    localparam int  CLK_PERIOD_NS = 10;   // 100 MHz
    localparam int  RESET_CYCLES  = 4;
    localparam int  TIMEOUT_NS    = 100_000;

    // ---- DUT I/O -------------------------------------------------------------
    logic clk;
    logic rst_n;

    // TODO: declare DUT-specific signals here
    // logic [7:0] in_a, in_b;
    // logic [7:0] out_y;

    // ---- DUT instance --------------------------------------------------------
    <module> dut (
        .clk   (clk),
        .rst_n (rst_n)
        // TODO: connect DUT ports
    );

    // ---- Clock generator -----------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // ---- Reset generator -----------------------------------------------------
    task automatic do_reset();
        rst_n = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    // ---- Test bookkeeping ----------------------------------------------------
    int unsigned pass_count = 0;
    int unsigned fail_count = 0;

    task automatic check(input logic cond, input string msg);
        if (cond) begin
            pass_count++;
        end else begin
            fail_count++;
            $error("[%0t] CHECK FAILED: %s", $time, msg);
        end
    endtask

    // ---- Golden reference ----------------------------------------------------
    function automatic logic [7:0] golden(input logic [7:0] a, input logic [7:0] b);
        // TODO: pure-SV reference model
        return a + b;
    endfunction

    // ---- Stimulus task -------------------------------------------------------
    task automatic apply_vector(input logic [7:0] a, input logic [7:0] b);
        // TODO: drive inputs
        // in_a <= a; in_b <= b;
        @(posedge clk);
        // TODO: sample output and compare
        // check(out_y === golden(a,b), $sformatf("a=%0h b=%0h", a, b));
    endtask

    // ---- Main initial block --------------------------------------------------
    initial begin
        // dump for cross-tool wave (Questa wlf is automatic; this is for VCD)
        $dumpfile("<module>_testbench.vcd");
        $dumpvars(0, <module>_testbench);

        // timeout watchdog
        fork begin
            #(TIMEOUT_NS);
            $error("TIMEOUT after %0d ns", TIMEOUT_NS);
            $finish;
        end join_none

        do_reset();

        // ---- Test cases ----
        apply_vector(8'h00, 8'h00);
        apply_vector(8'h01, 8'hFF);
        apply_vector(8'h7F, 8'h01);
        apply_vector(8'hAA, 8'h55);
        // TODO: more vectors

        // ---- Report --------
        $display("------------------------------------------------------------");
        $display("Tests run : %0d", pass_count + fail_count);
        $display("Passed    : %0d", pass_count);
        $display("Failed    : %0d", fail_count);
        if (fail_count == 0)
            $display("PASS");
        else
            $display("FAIL");
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule

`default_nettype wire
```

---

## `scripts/waves/<module>_wave.do`

```tcl
# <module>_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary  /<module>_testbench/clk
add wave -radix binary  /<module>_testbench/rst_n

add wave -divider "DUT I/O"
add wave -r -radix hex  /<module>_testbench/dut/*

configure wave -namecolwidth   200
configure wave -valuecolwidth  100
configure wave -timelineunits  ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
```

---

## Notes

- `$finish` not `$stop`. `$stop` halts the simulator interactively; `runlab.do` expects clean exit.
- `assert(...) else $error(...)` is fine for inline checks; the `check()` task above gives uniform reporting and tallying.
- For DUTs without `rst_n` (active-high reset), rename and flip polarity. Don't carry both conventions in one TB.
- VCD dump is optional — Questa records its own `wlf` automatically. Keep VCD for portability with xsim or open-source flows.
- Timeout watchdog is critical for CI / regression. Don't skip it.
- For systolic-array DUTs, drive all PE inputs in lockstep from a single stimulus task; use a separate task to sample the output column.

## Sources

- IEEE 1800-2017 §20 (System Tasks: $finish, $error, $dumpvars)
- Spear & Tumbush, *SystemVerilog for Verification* §6 (TB structure)
- Verification Academy directed-test patterns: https://verificationacademy.com
