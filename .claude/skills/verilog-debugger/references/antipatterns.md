# SystemVerilog Antipattern Catalog

Each entry: **signature** → **why broken** → **minimal fix** → **tool that catches it** → **citation**.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## 1. Blocking `=` in `always_ff`

**Signature:**
```sv
always_ff @(posedge clk) begin
    a = b;        // BAD
    c = a;        // reads new a, not old
end
```
**Why broken:** Race between sequential statements; sim/synth mismatch. Each `<=` schedules update at end of time step; blocking does it immediately, breaking pipeline semantics.
**Fix:** Use `<=`.
**Caught by:** Verible lint, Verilator `-Walways`, Questa `vlog -lint`.
**Cite:** IEEE 1800-2017 §10.4.2; Cliff Cummings, "Nonblocking Assignments in Verilog Synthesis, Coding Styles That Kill!" (SNUG 2000).

---

## 2. Non-blocking `<=` in `always_comb`

**Signature:**
```sv
always_comb begin
    out <= in & mask;   // BAD
end
```
**Why broken:** Schedules update for end of time step; downstream comb logic sees stale value. Sim works "by accident" if no fanout in same block, fails subtly otherwise.
**Fix:** Use `=`.
**Caught by:** Verible, Questa `vlog -lint`.
**Cite:** IEEE 1800-2017 §10.4.1.

---

## 3. Latch inference (missing else / missing default)

**Signature:**
```sv
always_comb begin
    if (sel) y = a;     // no else → y holds → latch
end
```
**Why broken:** Synth tool infers a level-sensitive latch to "remember" `y` when `sel` is low. Latches break STA, are CDC nightmares.
**Fix (option A — default at top):**
```sv
always_comb begin
    y = '0;
    if (sel) y = a;
end
```
**Fix (option B — full else):**
```sv
always_comb begin
    if (sel) y = a;
    else     y = '0;
end
```
**Caught by:** Vivado synth `WARNING: [Synth 8-327] inferring latch`, Verible `--rules=always_comb`, Questa lint.
**Cite:** Xilinx UG901 "Inference of Latches"; Sutherland *RTL Modeling with SystemVerilog* §11.

---

## 4. Multi-driven nets

**Signature:** Same `logic`/`wire` assigned in two `always` blocks or in an `assign` plus an `always`.
**Why broken:** Sim shows `X`; synth fails `multidriven net`.
**Fix:** Pick one driver. If you really need a mux, write the mux explicitly in one block.
**Caught by:** Vivado `[Synth 8-91]`, Verilator `MULTIDRIVEN`.
**Cite:** IEEE 1800-2017 §6.5.

---

## 5. Combinational loop

**Signature:** Output of `always_comb` feeds back to its own input through pure comb logic.
**Why broken:** No stable solution; sim oscillates or X-locks; synth `combinational loop` error.
**Fix:** Insert a register break (`always_ff`), or restructure logic to be acyclic.
**Caught by:** Vivado `[Synth 8-295]`, Verilator `UNOPTFLAT`.
**Cite:** Xilinx UG901 "Combinational Loops".

---

## 6. Unsynchronized clock domain crossing

**Signature:**
```sv
always_ff @(posedge clk_b) begin
    sig_b <= sig_a;     // sig_a from clk_a domain — BAD
end
```
**Why broken:** Metastability; `sig_b` may capture mid-transition. Mean time between failures shrinks fast at high clocks.
**Fix (control bit):** 2-FF synchronizer.
```sv
logic sig_a_meta, sig_a_sync;
always_ff @(posedge clk_b) begin
    sig_a_meta <= sig_a;
    sig_a_sync <= sig_a_meta;
end
```
**Fix (multi-bit data):** async FIFO or handshake protocol — not 2-FF.
**Caught by:** Manual review; Vivado CDC report (`report_cdc`).
**Cite:** Xilinx UG949 "Clock Domain Crossing"; Sutherland *RTL Modeling* §14; Clifford Cummings, "Synthesis and Scripting Techniques for Designing Multi-Asynchronous Clock Designs" (SNUG 2001).

---

## 7. Reset polarity / sync vs async mismatch

**Signature:** Half the design uses `always_ff @(posedge clk or negedge rst_n)`, other half uses `always_ff @(posedge clk)` with `if (rst_n)`. Or worse, `posedge rst` mixed with `negedge rst_n`.
**Why broken:** Reset doesn't release on the same edge; some flops out of reset before others; bad initial state.
**Fix:** Pick one convention project-wide. For UltraScale+, **synchronous active-high or active-low** is preferred (FF reset is dedicated). Document in CLAUDE.md.
**Cite:** Xilinx UG949 "Reset Methodology"; UG901 "Resets".

---

## 8. Signed vs unsigned arithmetic

**Signature:**
```sv
logic [7:0] a;            // unsigned
logic signed [7:0] b;     // signed
logic [15:0] product;
assign product = a * b;   // a promotes to signed? unsigned? — IMPLEMENTATION-DEFINED gotcha
```
**Why broken:** SV promotion rules: any unsigned operand makes the whole expression unsigned. So `b` is treated as unsigned → wrong result for negative `b`.
**Fix:** Make both operands the same signedness, or cast: `signed'(a) * b`.
**Caught by:** Eyeballs + careful TB. Lint mostly silent.
**Cite:** IEEE 1800-2017 §11.8 "Expression types".

---

## 9. Bit-width truncation

**Signature:**
```sv
logic [3:0] sum;
assign sum = a + b;       // a, b are [3:0]; sum loses carry
```
**Why broken:** Silent loss of MSBs.
**Fix:** Widen result, or use explicit cast.
```sv
logic [4:0] sum;
assign sum = {1'b0, a} + {1'b0, b};
```
**Caught by:** Verilator `WIDTH`, Verible `--rules=truncated-numeric-literal`.
**Cite:** IEEE 1800-2017 §11.6.

---

## 10. `case` without `default`

**Signature:**
```sv
always_comb begin
    case (state)
        IDLE: y = 0;
        RUN:  y = 1;
    endcase                 // missing DONE → latch + X-prop
end
```
**Fix:** Always include `default:`. Or use `unique case` to assert at sim that all cases are covered.
**Caught by:** Vivado synth latch warning, Questa `vlog -lint`.
**Cite:** IEEE 1800-2017 §12.5; Sutherland §10.

---

## 11. `casex` / `casez` X-propagation

**Signature:** `casex (in)` with `4'b1xxx:` patterns. `x` in `in` matches anything.
**Why broken:** Real hardware doesn't have `x`; sim hides bugs by matching X to anything.
**Fix:** Use `case inside` with `4'b1???` in SV, or `casez` (which only treats `?`/`z` as wildcard, not `x`). Best: `unique case inside`.
**Cite:** Sutherland *RTL Modeling* §10.4.

---

## 12. `always @*` instead of `always_comb`

**Signature:**
```sv
always @* begin
    y = a & b;
end
```
**Why broken:** Tool can't enforce that the block is purely combinational. `always_comb` triggers tool checks (latch detection, single-driver enforcement).
**Fix:** `always_comb`.
**Cite:** IEEE 1800-2017 §9.2.2.2.2.

---

## 13. Sensitivity list typo (legacy `always @(...)`)

**Signature:** `always @(a or b)` but block reads `c`. Sim wrong (won't re-evaluate on `c` change), synth correct.
**Fix:** Never write explicit comb sensitivity lists in new code. Use `always_comb`.
**Cite:** IEEE 1800-2017 §9.2.2.2.

---

## 14. X-propagation through priority encoders

**Signature:** Reset deassert produces brief X on a flop fanning into a `casez`/priority logic; X spreads through whole datapath in sim, masking real init bugs.
**Fix:** Deterministic reset on all flops; `unique case` to catch coverage holes; `$assert(!$isunknown(sig))` in TB.
**Caught by:** Coverage + assertions. See [verification](../../verification/SKILL.md) skill.
**Cite:** Mike Turpin, "The Dangers of Living with an X (poorly understood) in Verilog Designs" (SNUG 2003).

---

## 15. Implicit nets (`wire` auto-creation)

**Signature:** Typo in a port name → Verilog 2001 silently creates a 1-bit `wire` with that name. Module connects to nothing.
**Fix:** Always declare ports as `logic`. Add `` `default_nettype none `` at top of file.
**Caught by:** `default_nettype none` + Verible.
**Cite:** IEEE 1800-2017 §6.10.

---

## Sources

- IEEE 1800-2017 SystemVerilog LRM
- Sutherland & Mills, *RTL Modeling with SystemVerilog for Simulation and Synthesis* (2017)
- Cliff Cummings SNUG papers (sunburst-design.com/papers)
- Xilinx UG901 Vivado Synthesis Guide: https://docs.amd.com/r/en-US/ug901-vivado-synthesis
- Xilinx UG949 UltraFast Methodology Guide: https://docs.amd.com/r/en-US/ug949-vivado-design-methodology
- Verible lint rules: https://chipsalliance.github.io/verible/lint.html
- Sigasi: https://www.sigasi.com/tech/verilog_assignments_blocking_nonblocking/
- Verification Academy: https://verificationacademy.com
