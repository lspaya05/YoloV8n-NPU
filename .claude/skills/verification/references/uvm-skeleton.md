# UVM Environment Skeleton

Minimal but complete UVM 1.2 / IEEE 1800.2 environment for a generic DUT. Adapt component names per DUT. All files concatenated below — split into separate files as needed and `` `include `` them from the testbench top.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## File layout

```
tb/
├── <module>_testbench.sv         <- top module, calls run_test()
├── <module>_pkg.sv               <- package: components, sequences, tests
└── <module>_if.sv                <- virtual interface
```

Compile order is handled automatically by [scripts/sim/runlab.do](../../../../scripts/sim/runlab.do) (`vlog tb/*.sv`). The package and interface files must be in `tb/`, not `src/packages/`, since they're verification-only.

---

## `tb/<module>_if.sv` — Virtual Interface

```sv
`default_nettype none

interface <module>_if (input logic clk, input logic rst_n);
    // TODO: signals matching DUT ports
    logic        valid;
    logic        ready;
    logic [31:0] data;

    // driver clocking block
    clocking drv_cb @(posedge clk);
        default input #1step output #1ns;
        output valid;
        output data;
        input  ready;
    endclocking

    // monitor clocking block
    clocking mon_cb @(posedge clk);
        default input #1step;
        input valid;
        input ready;
        input data;
    endclocking

    modport DRV (clocking drv_cb, input rst_n);
    modport MON (clocking mon_cb, input rst_n);
endinterface

`default_nettype wire
```

---

## `tb/<module>_pkg.sv` — Package (transactions, components, sequences, tests)

```sv
`default_nettype none

package <module>_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ============================================================
    // Transaction
    // ============================================================
    class <module>_txn extends uvm_sequence_item;
        rand bit [31:0] data;
        rand bit        valid;

        `uvm_object_utils_begin(<module>_txn)
            `uvm_field_int(data,  UVM_ALL_ON)
            `uvm_field_int(valid, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "<module>_txn");
            super.new(name);
        endfunction
    endclass

    // ============================================================
    // Sequence
    // ============================================================
    class <module>_seq extends uvm_sequence #(<module>_txn);
        `uvm_object_utils(<module>_seq)
        rand int unsigned n_items = 16;

        function new(string name = "<module>_seq");
            super.new(name);
        endfunction

        task body();
            <module>_txn t;
            repeat (n_items) begin
                t = <module>_txn::type_id::create("t");
                start_item(t);
                if (!t.randomize()) `uvm_error("RAND", "txn rand failed")
                finish_item(t);
            end
        endtask
    endclass

    // ============================================================
    // Driver
    // ============================================================
    class <module>_driver extends uvm_driver #(<module>_txn);
        `uvm_component_utils(<module>_driver)
        virtual <module>_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual <module>_if)::get(this, "", "vif", vif))
                `uvm_fatal("CFG", "no vif")
        endfunction

        task run_phase(uvm_phase phase);
            <module>_txn t;
            // wait reset deassert
            @(posedge vif.rst_n);
            forever begin
                seq_item_port.get_next_item(t);
                @(vif.drv_cb);
                vif.drv_cb.valid <= 1'b1;
                vif.drv_cb.data  <= t.data;
                @(vif.drv_cb);
                while (!vif.drv_cb.ready) @(vif.drv_cb);
                vif.drv_cb.valid <= 1'b0;
                seq_item_port.item_done();
            end
        endtask
    endclass

    // ============================================================
    // Monitor
    // ============================================================
    class <module>_monitor extends uvm_monitor;
        `uvm_component_utils(<module>_monitor)
        virtual <module>_if vif;
        uvm_analysis_port #(<module>_txn) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual <module>_if)::get(this, "", "vif", vif))
                `uvm_fatal("CFG", "no vif")
        endfunction

        task run_phase(uvm_phase phase);
            <module>_txn t;
            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.valid && vif.mon_cb.ready) begin
                    t       = <module>_txn::type_id::create("t");
                    t.data  = vif.mon_cb.data;
                    t.valid = vif.mon_cb.valid;
                    ap.write(t);
                end
            end
        endtask
    endclass

    // ============================================================
    // Agent
    // ============================================================
    class <module>_agent extends uvm_agent;
        `uvm_component_utils(<module>_agent)
        <module>_driver                   drv;
        <module>_monitor                  mon;
        uvm_sequencer #(<module>_txn)     seqr;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = <module>_monitor::type_id::create("mon", this);
            if (get_is_active() == UVM_ACTIVE) begin
                drv  = <module>_driver::type_id::create("drv", this);
                seqr = uvm_sequencer#(<module>_txn)::type_id::create("seqr", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE)
                drv.seq_item_port.connect(seqr.seq_item_export);
        endfunction
    endclass

    // ============================================================
    // Scoreboard
    // ============================================================
    `uvm_analysis_imp_decl(_obs)
    class <module>_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(<module>_scoreboard)
        uvm_analysis_imp_obs #(<module>_txn, <module>_scoreboard) obs_imp;

        int unsigned obs_count = 0;
        int unsigned err_count = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            obs_imp = new("obs_imp", this);
        endfunction

        function void write_obs(<module>_txn t);
            obs_count++;
            // TODO: compare against ref model
            // if (t.data !== expected) err_count++;
        endfunction

        function void report_phase(uvm_phase phase);
            if (err_count == 0)
                `uvm_info("SCB", $sformatf("PASS (%0d txns)", obs_count), UVM_LOW)
            else
                `uvm_error("SCB", $sformatf("FAIL (%0d errors / %0d txns)",
                                            err_count, obs_count))
        endfunction
    endclass

    // ============================================================
    // Env
    // ============================================================
    class <module>_env extends uvm_env;
        `uvm_component_utils(<module>_env)
        <module>_agent       agt;
        <module>_scoreboard  scb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = <module>_agent::type_id::create("agt", this);
            scb = <module>_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.mon.ap.connect(scb.obs_imp);
        endfunction
    endclass

    // ============================================================
    // Base test
    // ============================================================
    class <module>_base_test extends uvm_test;
        `uvm_component_utils(<module>_base_test)
        <module>_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = <module>_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            <module>_seq seq;
            phase.raise_objection(this);
            seq = <module>_seq::type_id::create("seq");
            seq.start(env.agt.seqr);
            #100ns;
            phase.drop_objection(this);
        endtask
    endclass

endpackage

`default_nettype wire
```

---

## `tb/<module>_testbench.sv` — Top module

```sv
`timescale 1ns/1ps
`default_nettype none

module <module>_testbench;
    import uvm_pkg::*;
    import <module>_pkg::*;

    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;
    initial begin
        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
    end

    <module>_if vif (.clk(clk), .rst_n(rst_n));

    <module> dut (
        .clk    (clk),
        .rst_n  (rst_n)
        // TODO: connect to vif signals
    );

    initial begin
        uvm_config_db#(virtual <module>_if)::set(null, "*", "vif", vif);
        run_test();   // test class chosen via +UVM_TESTNAME
    end
endmodule

`default_nettype wire
```

---

## Running it

The default `runlab.do` doesn't pass `+UVM_TESTNAME`. Two options:

**Option A — extend `runlab.do`** (one-line patch):

```tcl
vsim -voptargs="+acc" -t 1ps -lib work +UVM_TESTNAME=<module>_base_test ${module}_testbench
```

**Option B — interactive override** at the Questa prompt:

```tcl
vsim -voptargs="+acc" -t 1ps -lib work +UVM_TESTNAME=<module>_base_test <module>_testbench
do scripts/waves/<module>_wave.do
run -all
```

To run a different test class without rebuilding, change `+UVM_TESTNAME=<other_test_class>`.

---

## Sources

- Accellera UVM 1.2 User Guide: https://www.accellera.org/downloads/standards/uvm
- IEEE 1800.2-2020 (UVM standard)
- Verification Academy UVM cookbook: https://verificationacademy.com/cookbook/uvm
- Spear & Tumbush, *SystemVerilog for Verification* §8 (UVM)
