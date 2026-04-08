# DSP58 / DSP48E2 Multiply-Accumulate Inference Templates

Vivado synthesis recognizes specific RTL templates and maps them to a single DSP slice. Wrong template → LUT-based multiplier → 3–5× more area, missed timing.

K26 SOM has **1,248 DSP58 slices** [DS987]. A 32×32 systolic array with one DSP/PE = 1024 DSPs (≈82% utilization). Spend them well.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## Template 1 — Pipelined signed multiply-accumulate (preferred for systolic PE)

```sv
module mac_pe #(
    parameter int A_W = 8,
    parameter int B_W = 8,
    parameter int ACC_W = 32
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       en,
    input  logic signed [A_W-1:0]      a,
    input  logic signed [B_W-1:0]      b,
    output logic signed [ACC_W-1:0]    acc
);
    logic signed [A_W-1:0]    a_r;
    logic signed [B_W-1:0]    b_r;
    logic signed [A_W+B_W-1:0] m_r;
    logic signed [ACC_W-1:0]   acc_r;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_r   <= '0;
            b_r   <= '0;
            m_r   <= '0;
            acc_r <= '0;
        end else if (en) begin
            a_r   <= a;
            b_r   <= b;
            m_r   <= a_r * b_r;
            acc_r <= acc_r + m_r;
        end
    end

    assign acc = acc_r;
endmodule
```

**Why this template works:** Three pipeline registers (input → multiply → accumulate) match DSP48E2/DSP58 internal register stages (A1/A2 → M → P). Vivado infers the full DSP slice including pre-adder, multiplier, and accumulator. Fmax >300 MHz on K26.

**Cite:** Xilinx UG901 "Multipliers", UG579 §"DSP48E2 Slice".

---

## Template 2 — Asymmetric width MAC (for INT8 × INT8 → INT32 PE)

```sv
logic signed [7:0]   weight;
logic signed [7:0]   activation;
logic signed [15:0]  product;
logic signed [31:0]  acc;

always_ff @(posedge clk) begin
    product <= weight * activation;
    acc     <= acc + product;
end
```

DSP48E2 native widths: 27×18 signed multiply, 48-bit accumulator. INT8×INT8 fits with room to spare. DSP58 supports 24×24 + dual 8×8 INT modes (2 MACs/cycle/slice in INT8).

**Cite:** Xilinx UG579 §"Arithmetic Functions", AMD Versal DSP58 architecture brief.

---

## Template 3 — Pre-adder MAC (saves a DSP for symmetric FIR)

```sv
logic signed [8:0]   sum;        // a + b
logic signed [17:0]  product;
logic signed [47:0]  acc;

always_ff @(posedge clk) begin
    sum     <= a + b;             // pre-adder D+A
    product <= sum * coeff;       // multiplier
    acc     <= acc + product;     // post-adder
end
```

Maps `(a+b)*c + acc` into ONE DSP slice via the pre-adder + multiplier + ALU path. Useful for symmetric FIR or some pooling kernels.

**Cite:** UG579 §"Pre-Adder".

---

## Template 4 — Dual MAC in one DSP58 (INT8 packing)

DSP58 supports two 8×8 multiplies per slice when packed correctly. Vivado 2024+ infers this from:

```sv
logic signed [16:0] a_pack;   // {a1, a0}, with sign-extend
logic signed [7:0]  b_shared;
logic signed [33:0] result;

assign a_pack = {{1'b0, a1}, a0};  // pack two int8 with separator
always_ff @(posedge clk) begin
    result <= a_pack * b_shared;
end
// extract result[15:0] = a0*b_shared, result[33:18] = a1*b_shared
```

This is fragile — verify infered DSP count in `report_utilization` after synth. If Vivado fails to infer, fall back to two separate DSPs.

**Cite:** AMD WP505 "Versal AI Engine and DSP58"; UG579 §"INT8 Optimizations".

---

## What kills DSP inference

- **Resetting the multiply register synchronously inside the always_ff** with a value other than zero — DSP slice has no general-purpose reset, only a register clear. Use `'0` only.
- **Asynchronous reset** on intermediate pipeline registers — DSP register stages are sync-only. Vivado falls back to LUTs.
- **Extra logic between multiply and add** that doesn't fit the DSP datapath. Keep it `acc <= acc + (a*b)`.
- **Wide signed/unsigned mixing** — see [antipatterns.md §8](antipatterns.md).
- **Dynamic operand width** via `+:` slicing on a parameterized index — synth can't pin it to DSP.

---

## Verifying inference

After synth:

```tcl
report_utilization -hierarchical -file util.rpt
report_dsp -file dsp.rpt
```

In `util.rpt`, look for `DSPs` row under your PE module. Should equal the number of MACs you wrote. If less, check synth log for `DSP not inferred` warnings.

---

## Sources

- Xilinx UG901 Vivado Synthesis Guide: https://docs.amd.com/r/en-US/ug901-vivado-synthesis
- Xilinx UG579 UltraScale Architecture DSP Slice: https://docs.amd.com/v/u/en-US/ug579-ultrascale-dsp
- AMD WP505 Versal DSP58 Architecture: https://docs.amd.com/v/u/en-US/wp505-versal-acap
- DS987 Kria K26 SOM Datasheet: https://www.mouser.com/datasheet/2/903/ds987_k26_som-2329045.pdf
