# SVA Cookbook — Bind-able Properties

Drop-in SystemVerilog Assertions for the EE470 Neural Engine. Each entry is written to be `bind`-ed onto the DUT so production RTL stays clean.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## Pattern: bind-from-separate-file

Keep all assertions in `tb/<module>_assertions.sv`, then bind onto the DUT:

```sv
// tb/<module>_assertions.sv
module <module>_assertions (
    input logic clk,
    input logic rst_n,
    // ...DUT signals
);
    // properties + assertions here
endmodule

// in tb/<module>_testbench.sv
bind <module> <module>_assertions u_asserts (.*);
```

The `bind` connects by port name (`.*`). DUT remains untouched.

---

## 1. AXI4-Lite handshake — `valid` stable until `ready`

```sv
// VALID once asserted must stay high until READY
property axi_valid_stable;
    @(posedge clk) disable iff (!rst_n)
    valid && !ready |=> valid;
endproperty
ap_valid_stable: assert property (axi_valid_stable)
    else $error("AXI VALID dropped before READY");

// DATA stable while VALID && !READY
property axi_data_stable;
    @(posedge clk) disable iff (!rst_n)
    valid && !ready |=> $stable(data);
endproperty
ap_data_stable: assert property (axi_data_stable)
    else $error("AXI DATA changed mid-handshake");
```

**Cite:** AMD AXI4 Reference Guide (UG1037), Sutherland *SVA Handbook* §"Protocol checking".

---

## 2. AXI4-Lite — no transfer during reset

```sv
property axi_quiet_in_reset;
    @(posedge clk) !rst_n |-> !valid;
endproperty
ap_axi_quiet_in_reset: assert property (axi_quiet_in_reset)
    else $error("AXI VALID asserted while in reset");
```

---

## 3. FIFO — never write when full

```sv
property fifo_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    full |-> !wr_en;
endproperty
ap_fifo_no_overflow: assert property (fifo_no_overflow)
    else $error("FIFO write while full");
```

## 4. FIFO — never read when empty

```sv
property fifo_no_underflow;
    @(posedge clk) disable iff (!rst_n)
    empty |-> !rd_en;
endproperty
ap_fifo_no_underflow: assert property (fifo_no_underflow)
    else $error("FIFO read while empty");
```

## 5. FIFO — full and empty mutually exclusive (assuming non-empty FIFO)

```sv
property fifo_full_empty_mutex;
    @(posedge clk) disable iff (!rst_n)
    !(full && empty);
endproperty
ap_fifo_mutex: assert property (fifo_full_empty_mutex);
```

---

## 6. Pipeline valid propagation through PE row

For a systolic array with `N` pipeline stages, valid in stage 0 should propagate to stage `N` exactly `N` cycles later.

```sv
property pe_valid_propagates;
    @(posedge clk) disable iff (!rst_n)
    valid_stage[0] |-> ##N valid_stage[N];
endproperty
ap_pe_valid_prop: assert property (pe_valid_propagates)
    else $error("PE valid did not propagate after %0d cycles", N);
```

Replace `N` with the actual pipeline depth.

---

## 7. One-hot state encoding

```sv
property state_one_hot;
    @(posedge clk) disable iff (!rst_n)
    $onehot(state);
endproperty
ap_state_onehot: assert property (state_one_hot)
    else $error("state is not one-hot: %b", state);
```

For "zero or one hot": use `$onehot0(state)`.

---

## 8. State transition — must reach DONE within K cycles after START

```sv
property start_to_done_bound;
    @(posedge clk) disable iff (!rst_n)
    $rose(start) |-> ##[1:K_MAX] done;
endproperty
ap_start_done: assert property (start_to_done_bound)
    else $error("DONE not reached within %0d cycles of START", K_MAX);
```

---

## 9. No X on critical control signals

```sv
property no_x_on_valid;
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(valid);
endproperty
ap_no_x_valid: assert property (no_x_on_valid)
    else $error("VALID is X");
```

Catches uninitialized flops, missing reset, accidental floating nets.

---

## 10. Reset behavior — all outputs zero in reset

```sv
property out_zero_in_reset;
    @(posedge clk) !rst_n |-> (data_out === '0);
endproperty
ap_out_zero_reset: assert property (out_zero_in_reset)
    else $error("data_out non-zero during reset: %h", data_out);
```

---

## Cover properties (functional coverage via SVA)

```sv
cover property (@(posedge clk) $rose(start) ##[1:10] done);
cover property (@(posedge clk) full && empty);  // should never hit (paired with assert above)
```

In Questa: `vsim -coverage` then `vcover report` to see cover prop hit counts.

---

## Coverage hooks for systolic-array specific corners

```sv
covergroup pe_boundary_cg @(posedge clk);
    cp_row: coverpoint pe_row { bins first = {0}; bins last = {N-1}; bins mid = {[1:N-2]}; }
    cp_col: coverpoint pe_col { bins first = {0}; bins last = {M-1}; bins mid = {[1:M-2]}; }
    cross cp_row, cp_col;   // ensure all 9 corner/edge/interior classes hit
endgroup
```

---

## Sources

- IEEE 1800-2017 SystemVerilog LRM §16 (Assertions)
- Sutherland, *SystemVerilog Assertions Handbook*, 4th ed.
- Mentor Verification Academy SVA cookbook: https://verificationacademy.com/cookbook/sva
- AMD UG1037 AXI4 Reference Guide: https://docs.amd.com/v/u/en-US/ug1037-vivado-axi-reference-guide
- Spear & Tumbush, *SystemVerilog for Verification* §10
