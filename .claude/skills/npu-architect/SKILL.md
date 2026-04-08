---
name: npu-architect
description: Architectural advice for the EE470 Neural Engine (KR260). Use for dataflow choice (WS/OS/RS), array sizing, quantization, memory hierarchy, AXI IP selection, or TPU/Eyeriss/NVDLA comparisons. Every claim cites a source.
---

# npu-architect

Architectural advisor for the EE470 Neural Engine. Helps user pick dataflow, array size, quantization, memory hierarchy, IP reuse strategy. **Every recommendation must end with a `[Source: ...]` tag.** No invented citations.

## Citation rule (load-bearing)

Every architectural claim ends with `[Source: ...]`. Acceptable sources:

- Local PDFs: [papers/Eyeriss2017.pdf](../../../papers/Eyeriss2017.pdf), [papers/TPU2017.pdf](../../../papers/TPU2017.pdf), [papers/SurveyOfAcceleratorArch2019.pdf](../../../papers/SurveyOfAcceleratorArch2019.pdf), [papers/Orion2025.pdf](../../../papers/Orion2025.pdf)
- Arxiv / journal links
- AMD/Xilinx datasheets and IP product guides (DS, PG, UG, WP)
- Open-source NPU repos (NVDLA, Gemmini, VTA, Eyeriss-v2 forks)

If no honest citation exists, say `[Source: no canonical citation — engineering judgment]`. Never invent.

## KR260 budget cheat sheet

| Resource | Available | Notes |
|---|---|---|
| CLB LUTs | 117,120 | logic |
| CLB FFs | 234,240 | storage |
| BRAM | 144 (≈5.1 MB) | dual-port |
| URAM | 64 | for larger on-chip buffers |
| **DSP58 slices** | **1,248** | int8 MAC native, 24×24 signed mult |
| DDR4 | 4 GB @ ≈19.2 GB/s | dual-channel 64-bit |
| Realistic fabric clock | 200–300 MHz | for systolic arrays |
| PS | quad Cortex-A53 @ 1.4 GHz | for control + driver |

`[Source: Kria K26 SOM Datasheet (DS987)](https://www.mouser.com/datasheet/2/903/ds987_k26_som-2329045.pdf)` `[Source: DS891 Zynq UltraScale+ Overview](https://docs.amd.com/v/u/en-US/ds891-zynq-ultrascale-plus-overview)`

Full breakdown with proposed allocation for a 32×32 INT8 array in [references/kr260-budget.md](references/kr260-budget.md).

## Dataflow decision tree

```
Workload?
├── CNN inference, varying filter shapes (3x3, 5x5, depthwise) → Row-Stationary [Source: Eyeriss]
├── Dense GEMM, MLP/LSTM, batched inference → Weight-Stationary [Source: TPU]
└── Dense GEMM with little weight reuse, training → Output-Stationary
```

| Dataflow | Stationary | Best for | Energy edge |
|---|---|---|---|
| Weight-stationary (WS) | weights in PE | high weight reuse, batched MLP/CNN | TPU-class throughput |
| Output-stationary (OS) | partial sums in PE | dense GEMM, training | high PE utilization |
| Row-stationary (RS) | rows of weights | CNNs w/ varying filters | 1.4–2.5× better energy on conv |

Full comparison with reuse counts and references in [references/dataflows.md](references/dataflows.md).

`[Source: Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit", ISCA 2017, arxiv:1704.04760, papers/TPU2017.pdf]`
`[Source: Chen et al., "Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for CNNs", ISCA 2016 / JSSC 2017, papers/Eyeriss2017.pdf]`

## Sizing guidance

| Array | MACs/cycle | DSP usage on K26 | Notes |
|---|---|---|---|
| 8×8 | 64 | ~5% | Toy / debug |
| 16×16 | 256 | ~21% | Edge IoT, easy timing |
| **32×32** | **1024** | **~82%** | **Recommended baseline for K26** |
| 64×64 | 4096 | does not fit | needs larger device |
| 128×128 | 16384 | does not fit | TPU v2-class |
| 256×256 | 65536 | datacenter | TPU v1 |

**Why 32×32 is the sweet spot for K26:** 1024 DSPs out of 1248 leaves headroom for control logic and FP/format-conversion DSPs. Input bandwidth for INT8 at 250 MHz with double-buffering ≈ 4 GB/s, well under the 19.2 GB/s DDR4 ceiling. Bandwidth grows with the *square* of array side length, so a 64×64 (4× the BW) saturates the memory channel before reaching peak compute. `[Source: DS987 Kria K26]` `[Source: papers/SurveyOfAcceleratorArch2019.pdf]` `[Source: "Scale-out Systolic Arrays", EPFL 2022, arxiv:2204.01761]`

## Quantization guidance

| Format | Bits | Hardware fit on K26 | Use |
|---|---|---|---|
| **INT8** | 8 | native DSP58 MAC | **default for inference** |
| INT4 | 4 | manual packing | extreme edge, accuracy hit |
| BF16 | 16 | LUT or FP IP | training experiments, future |
| FP16 | 16 | FP Operator IP | mixed-precision |
| FP32 | 32 | FP Operator IP | reference / golden only |

INT8 is the right default. DSP58 supports two 8×8 MACs/slice when packed `[Source: WP505 Versal DSP58]`. Don't pay FP32 cost on K26 unless you have a measured accuracy reason. `[Source: papers/TPU2017.pdf §"Quantization"]`

## Memory hierarchy

Required pattern: **double-buffered (ping-pong) on-chip SRAM** between DDR4 and the systolic array, fed by AXI DMA.

```
DDR4 ──AXI HP──> AXI DMA ──AXI-Stream──> FIFO Gen ──> Buffer A ──┐
                                                       Buffer B ──┴──> Systolic Array
                                                                  └──> Buffer C ──> AXI DMA ──> DDR4
```

- Activation buffer: BRAM, ~1–2 MB depending on layer/tile size
- Weight buffer: BRAM or URAM, sized to one layer's filter tensor
- Output/partial-sum buffer: BRAM, banked for accumulation
- Compute and load overlap → zero stall if `T_load < T_compute`

`[Source: papers/Eyeriss2017.pdf §"Memory Hierarchy"]` `[Source: PG021 AXI DMA](https://docs.amd.com/r/en-US/pg021_axi_dma)` `[Source: DS317 FIFO Generator](https://docs.amd.com/v/u/en-US/fifo_generator_ds317)`

## Common pitfalls (cited)

- **Depthwise convolutions kill PE utilization** — utilization drops to 1/array_side. Mitigation: im2col → GEMM, accept the bandwidth hit. `[Source: Kung et al., "Adaptive Tiling: Applying Fixed-size Systolic Arrays To Sparse CNNs", Harvard, ICPR 2018]`
- **im2col balloons input bandwidth** by replicating pixels. Mitigation: PRTSM (Pixel Reuse with Time/Spatial Multiplexing) or direct conv routing. `[Source: PRTSM, Springer 2019, doi:10.1007/978-3-030-30709-7_6]`
- **Tile fragmentation** at layer boundaries leaves partial tiles wasting cycles. Mitigation: adaptive tiling. `[Source: Kung et al., ASPLOS 2019]`
- **NoC congestion** on broadcast nets to all PEs. Mitigation: hierarchical mesh (Eyeriss v2). `[Source: Chen et al., Eyeriss v2, JETCAS 2019]`
- **Reset/init bugs at scale** — staggered reset release across rows of PEs avoids power surge and simplifies STA. `[Source: UG949 §"Reset Methodology"](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology)`

## AMD/Xilinx IP — when to reuse vs build

| IP | Use it? | Why |
|---|---|---|
| AXI Interconnect | YES | Don't write your own crossbar. `[Source: PG059]` |
| AXI DMA | YES | Scatter-gather, PS↔PL data movement. `[Source: PG021]` |
| AXI4-Stream FIFO Generator | YES | Ping-pong buffering, depth/width configurable. `[Source: DS317]` |
| BRAM Controller | YES | When connecting BRAM via AXI. `[Source: PG078]` |
| Floating-Point Operator | OPTIONAL | Only for FP experiments. INT8 path doesn't need it. `[Source: PG060]` |
| AXI4-Stream Accelerator Adapter | OPTIONAL | Glue if exposing accelerator over AXI-Stream to PS. |
| **Vitis AI DPU** | **NO (use as comparison only)** | Fixed-function, defeats the point of building a custom systolic array for the course. Read the docs to compare. `[Source: Xilinx Vitis AI 3.0](https://xilinx.github.io/Vitis-AI/3.0/html/index.html)` |
| Vitis HLS | OPTIONAL | For non-systolic helpers (post-processing, softmax). The systolic array itself should be hand-written SV. |

## Open-source NPUs to read for inspiration

Full annotated list with what-to-copy / what-not-to-copy in [references/open-source-npus.md](references/open-source-npus.md). Quick index:

- **NVDLA** — full RTL + compiler + sim. Modular, not pure systolic. `[Source: https://github.com/nvdla/hw, https://nvdla.org]`
- **Gemmini** (UC Berkeley) — Chisel systolic array generator with runtime-switchable dataflow. Closest cousin to this project. `[Source: https://github.com/ucb-bar/gemmini, arxiv:1911.09925]`
- **VTA** (Apache TVM) — accelerator + ISA + compiler stack. Good end-to-end ML model. `[Source: https://github.com/apache/tvm-vta]`
- **BoooC Eyeriss-v2 fork** — already linked from project [README.md](../../../README.md). `[Source: https://github.com/BoooC/CNN-Accelerator-Based-on-Eyeriss-v2]`
- **karthisugumar Eyeriss-v2 SV** — full SystemVerilog Eyeriss-v2 with hierarchical mesh NoC. `[Source: https://github.com/karthisugumar/CSE240D-Hierarchical_Mesh_NoC-Eyeriss_v2]`

## Local papers index

- [papers/Eyeriss2017.pdf](../../../papers/Eyeriss2017.pdf) — row-stationary dataflow, energy-aware tiling, fabricated chip baseline.
- [papers/TPU2017.pdf](../../../papers/TPU2017.pdf) — 256×256 weight-stationary array, software-managed 28 MiB SRAM, datacenter workload mix.
- [papers/SurveyOfAcceleratorArch2019.pdf](../../../papers/SurveyOfAcceleratorArch2019.pdf) — DNN accelerator taxonomy; "data movement is the bottleneck" thesis.
- [papers/Orion2025.pdf](../../../papers/Orion2025.pdf) — recent accelerator reference (cite directly when discussing 2025-era trade-offs).

## References (load on demand)

- [references/dataflows.md](references/dataflows.md) — full WS/OS/RS comparison with reuse math.
- [references/kr260-budget.md](references/kr260-budget.md) — detailed K26 SOM resource allocation table.
- [references/open-source-npus.md](references/open-source-npus.md) — NVDLA / Gemmini / VTA / Eyeriss-v2 deep-dive.

## Hand-off

- "How do I write the RTL?" → call out [verilog-debugger](../verilog-debugger/SKILL.md).
- "How do I verify it?" → call out [verification](../verification/SKILL.md).
