# Kria K26 SOM Resource Budget — 32×32 INT8 Systolic Array Allocation

Always be extremely concise. Sacrifice grammar for the sake of concision.

K26 SOM is the basis for both the **KR260** (robotics-focused) and **KV260** (vision-focused) starter kits. Same XCK26 device, same fabric resources.

---

## Total available

| Resource | Count | Notes |
|---|---|---|
| CLB LUTs (logic) | 117,120 | |
| CLB FFs | 234,240 | |
| BRAM blocks (36 Kb) | 144 | ≈5.1 MB total |
| URAM blocks (288 Kb) | 64 | ≈2.3 MB total |
| **DSP58 slices** | **1,248** | int8 native, 24×24 signed mult, dual int8 mode |
| GTH transceivers | 4 | high-speed I/O |
| Distributed RAM | 3.5 MB | |

**On-module:**
- 4 GB DDR4-2667 (dual channel, 64-bit) ≈ **19.2 GB/s** peak.
- 16 GB eMMC.

**PS:**
- Quad Cortex-A53 @ 1.4 GHz
- Dual Cortex-R5 @ 600 MHz

`[Source: DS987 Kria K26 SOM Datasheet](https://www.mouser.com/datasheet/2/903/ds987_k26_som-2329045.pdf)`
`[Source: DS891 Zynq UltraScale+ Overview](https://docs.amd.com/v/u/en-US/ds891-zynq-ultrascale-plus-overview)`

---

## Proposed allocation — 32×32 INT8 weight-stationary array

Goal: 32×32 = 1024 INT8 MAC PEs, double-buffered weight + activation SRAMs, AXI-DMA-fed, single 250 MHz fabric clock.

| Block | LUTs | FFs | BRAM | URAM | DSP | Notes |
|---|---|---|---|---|---|---|
| 1024 PEs (1 DSP each) | ~30 K | ~50 K | 0 | 0 | **1024** | input/output flops + DSP MAC |
| Activation buffer (ping/pong) | ~3 K | ~3 K | 32 | 0 | 0 | 1 MB total, banked |
| Weight buffer (ping/pong) | ~3 K | ~3 K | 0 | 16 | 0 | URAM-backed for density |
| Output / partial-sum buffer | ~3 K | ~3 K | 32 | 0 | 0 | banked for accumulation |
| AXI Interconnect (PG059) | ~5 K | ~5 K | 0 | 0 | 0 | from PS HP ports |
| AXI DMA × 2 (PG021) | ~6 K | ~6 K | 8 | 0 | 0 | one in, one out |
| FIFO Generators (DS317) | ~4 K | ~4 K | 16 | 0 | 0 | decouple compute from DDR |
| Control FSM + AXI-Lite reg file | ~5 K | ~5 K | 0 | 0 | 0 | start/done/status |
| Format conversion / scaling | ~5 K | ~5 K | 0 | 0 | ~16 | DSP for shift/round |
| Headroom (debug, ILA, slack) | ~30 K | ~30 K | 56 | 48 | ~192 | |
| **Total budget** | **117K** | **234K** | **144** | **64** | **1,248** | |

Numbers above are approximate planning targets — measure actual via `report_utilization` after each synth.

---

## Bandwidth check

**Compute side:**
- 1024 INT8 MACs × 2 ops × 250 MHz = **512 GOPS** peak.
- Each MAC needs 2 input bytes (1 act + 1 weight). Activation reuse via WS dataflow makes the steady-state need ≈ 1 byte/cycle/PE for the activation row + occasional weight reload.
- Steady-state input bandwidth: ≈ 32 bytes/cycle × 250 MHz = **8 GB/s** (inputs only, after weight load amortized).

**Memory side:**
- DDR4 peak: **19.2 GB/s**.
- AXI HP port pairs achieve 75–95% of peak under good access patterns.
- Realistic sustained: **~14–18 GB/s**, comfortably above the 8 GB/s steady-state need.

**Conclusion:** 32×32 INT8 @ 250 MHz fits both compute and bandwidth budgets on KR260. `[Source: DS987 + AXI HP port analysis: https://xilinx.github.io/Embedded-Design-Tutorials/docs/2021.1/build/html/docs/User_Guides/SPA-UG/docs/6-evaluating-high-performance-ports.html]`

A 64×64 array would need ≈32 GB/s steady-state bandwidth → exceeds DDR4. Either drop to 16-bit weights / sparser activation, add HBM (not on K26), or stay at 32×32. `[Source: "Scale-out Systolic Arrays", EPFL 2022, arxiv:2204.01761]`

---

## Power planning (rough)

K26 SOM is rated for typical edge/robotics power envelopes (~10–20 W board-level). DSP-heavy designs at 250 MHz with 80% DSP utilization typically draw 4–8 W in PL. Use Vivado `report_power` after place-and-route for the real number. `[Source: UG1145 PetaLinux + thermal notes for KR260 starter kit]`

---

## Sources

- DS987 Kria K26 SOM Datasheet — https://www.mouser.com/datasheet/2/903/ds987_k26_som-2329045.pdf
- DS891 Zynq UltraScale+ Overview — https://docs.amd.com/v/u/en-US/ds891-zynq-ultrascale-plus-overview
- PG021 AXI DMA — https://docs.amd.com/r/en-US/pg021_axi_dma
- PG059 AXI Interconnect
- DS317 FIFO Generator — https://docs.amd.com/v/u/en-US/fifo_generator_ds317
- UG949 Vivado Design Methodology — https://docs.amd.com/r/en-US/ug949-vivado-design-methodology
- AXI HP port utilization tutorial — https://xilinx.github.io/Embedded-Design-Tutorials/docs/2021.1/build/html/docs/User_Guides/SPA-UG/docs/6-evaluating-high-performance-ports.html
