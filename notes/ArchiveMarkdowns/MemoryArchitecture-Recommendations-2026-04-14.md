# NPU Memory Architecture — Design Recommendations
**Date:** 2026-04-14  
**Context:** Weight-stationary 16×16 systolic array on KR260, planning multi-core NPU (SA + VPU + Reduction Tree)

---

## 1. Weight Loading — Single Dual-Port BRAM, No Ping-Pong

### How wavefront loading works
Weights propagate through the PE array one row per cycle during the LOAD phase (ARRAY_HEIGHT cycles total). Because `weightOut` is a registered FF in the PE, the first row presented ends up at the **bottom** PE after full propagation:

```
Present W[ARRAY_HEIGHT-1] first  →  ends up in PE[ARRAY_HEIGHT-1]
Present W[0] last                →  stays in PE[0]
```

The BRAM address counter must count **down** (bottom row first, top row last).

### Why one BRAM is enough
- 16×16 × 8-bit = 256 bytes. Fits in a single BRAM36 (4KB) with room to spare.
- Configure BRAM: **128-bit wide** (16 cols × 8b), **16 addresses deep** (one address = one full weight row).
- One read per LOAD cycle delivers the full `weightInputRow[ARRAY_LENGTH-1:0]` directly.

### Why not ping-pong for weights
- LOAD phase = 16 cycles. RUN + DRAIN ≈ K_DIM + 30 cycles. The BRAM is idle during computation.
- DMA can silently write the **next** weight matrix to the BRAM during RUN/DRAIN via **Port A**.
- LOAD reads via **Port B**. Non-overlapping → no contention, no second buffer needed.
- Exception: add ping-pong only if K_DIM < ARRAY_HEIGHT (compute finishes before DMA refills).

### Known RTL bug (MatrixMul.sv:51)
```systemverilog
// Wrong — i == 0 always in this branch, feeds weightInputRow[0] to all columns
assign intermediateWeightIn = weightInputRow[i];

// Correct — j is the column index
assign intermediateWeightIn = weightInputRow[j];
```

---

## 2. Activation Loading — FIFO + Skew Buffer (Ping-Pong BRAM)

### Why FIFO for activations
Activations are consumed once per computation — streaming access pattern. FIFO is the right primitive. Use AXI4-Stream FIFO (PG080) between the DMA and the skew buffer.

### Skew buffer (required)
PE[i][j] must receive its activation delayed by `i` cycles (row offset) so data meets the correct weight in the correct PE. Without skew all rows arrive simultaneously → wrong pairing.

```
Row 0:  act[0]  ──────────────────────────> activationInputCol[0]   (0 delay)
Row 1:  act[1]  ──[FF]─────────────────── > activationInputCol[1]   (1 cycle)
Row 2:  act[2]  ──[FF]──[FF]────────────── > activationInputCol[2]  (2 cycles)
...
Row N-1:act[N-1]──[FF]──...──[FF]─────────> activationInputCol[N-1] (N-1 cycles)
```

For 16×16 INT8: (0+1+...+15) × 8b = **960 bits** of FFs — trivial.  
At 128×128 scale, prefer staggered BRAM reads over the FF triangle.

### Ping-pong for activations (needed)
Activations stream continuously across tiles. Buffer A feeds the array while Buffer B loads the next tile from DDR4 via DMA. Swap on `load_done`.

---

## 3. Shared SRAM Architecture for Multi-Core NPU

### The problem with direct AXI-to-core wiring
- Each new core needs its own DMA master and HP port wiring.
- Cores can't pass data to each other without round-tripping through DDR4.
- Arbitration complexity grows with every core added.

### Correct architecture: banked shared SRAM
All cores read/write a shared on-chip SRAM. DMA Engine is the **sole AXI master**.

```
DDR4 ──AXI HP──> DMA Engine ──> Shared On-Chip SRAM (banked)
                                        │
                   ┌────────────────────┼──────────────────┐
                   ▼                    ▼                   ▼
             Systolic Array            VPU           Reduction Tree
```

### SRAM bank allocation

| Bank | Physical | Size | Owner (compute) | Owner (load) |
|---|---|---|---|---|
| Weight A | BRAM | 2 KB | SA (read during LOAD) | DMA (write prev cycle) |
| Weight B | BRAM | 2 KB | DMA (prefetch next layer) | — |
| Activation A | URAM | ~256 KB | DMA (load input tile) | — |
| Activation B | URAM | ~256 KB | SA (read) / VPU (write output) | — |
| Output | BRAM | 64 KB | SA (write accum) | DMA (drain to DDR4) |

Each bank is a **separate BRAM/URAM instance** with independent ports — no contention between cores as long as the Instruction Sequencer schedules correctly.

### Are cores truly concurrent?
For inference, cores are naturally **sequentially pipelined per layer**, not truly parallel:

```
Layer N:   SA computes GEMM → writes Activation Bank B
Layer N:   VPU requantizes Bank B → can't start until GEMM finishes

Across layers (overlap is possible):
  t=0..T:    SA computes Layer N (Weight Bank A, Act Bank A)
  t=T..T+k:  VPU requantizes Layer N output (Act Bank B)
             SA loads Layer N+1 weights into Weight Bank B   ← overlap
  t=T+k..:   SA computes Layer N+1
```

True concurrent multi-core (SA + VPU on the same layer simultaneously) requires a crossbar NoC — Eyeriss v2 territory, out of scope for EE470.

---

## 4. Revised Vivado IP List

| IP | PG | Purpose | Count |
|---|---|---|---|
| Zynq UltraScale+ MPSoC | — | PS, DDR4, AXI HP ports | 1 |
| AXI DMA | PG021 | Single DMA engine, DDR4 ↔ SRAM banks | 1 |
| Block Memory Generator | PG058 | Weight A/B + Output banks | 3 |
| URAM (via Block Memory Gen) | PG058 | Activation A/B banks | 2 |
| AXI BRAM Controller | PG078 | DMA AXI access to SRAM banks | 1–2 |
| AXI4-Stream Data FIFO | PG080 | Activation staging between DMA and skew buffer | 1 |
| AXI SmartConnect | PG247 | DMA master → HP port + BRAM controllers | 1 |
| AXI-Lite (GPIO or custom) | — | PS → Instruction Sequencer control registers | 1 |

**Key change from naive design:** One DMA engine (not one per core). No per-core AXI wiring.

---

## 5. Recommended Build Order

1. **Define SRAM bank interface** — port widths, read latency, handshake protocol. This is the contract every core is built against.
2. **Wire SA_top to SRAM** — swap raw `weightInputRow`/`activationInputCol` ports for SRAM-sourced signals. Easy win, proves the interface.
3. **Testbench SA + SRAM** — preload banks with `$readmemh`, assert `start`, check `MatrixMulOut`. Validates memory interface before any other core exists.
4. **Add DMA Engine** — Vivado AXI DMA IP pointed at SRAM banks. Load weights/activations from DDR4.
5. **Instruction Sequencer skeleton** — FSM: LOAD → GEMM → STORE. Hardcoded for one layer first.
6. **Add VPU, Reduction Tree** — memory interface is now proven and stable. Each core slots in cleanly.

**Rationale:** The SA is your existence proof. Get it running end-to-end on the real memory interface first — that de-risks all subsequent core development.

---

## Sources
- [papers/TPU2017.pdf] — weight-stationary dataflow, software-managed SRAM, decoupled access/execute
- [papers/Eyeriss2017.pdf] — global buffer banking, double buffering, skew buffer
- [papers/SurveyOfAcceleratorArch2019.pdf] — multi-bank SRAM, memory hierarchy taxonomy
- PG021 AXI DMA, PG058 Block Memory Generator, PG078 AXI BRAM Controller, PG080 AXI4-Stream FIFO, PG247 AXI SmartConnect
