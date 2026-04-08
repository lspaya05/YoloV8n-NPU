# Open-Source NPU References

What each project provides, what to copy, what NOT to copy. Use these as inspiration for the EE470 Neural Engine.

Always be extremely concise. Sacrifice grammar for the sake of concision.

---

## NVDLA — NVIDIA Deep Learning Accelerator

- **Repo:** https://github.com/nvdla/hw
- **Docs:** https://nvdla.org/primer.html, https://nvdla.org/hw/v1/hwarch.html
- **Language:** Verilog (production-grade)
- **Architecture:** modular — separate Convolution, Pooling, Activation, Local Memory, Bridge DMA blocks. **NOT a pure systolic array.**
- **Quantization:** INT8 inference focused
- **Verification:** comes with C-model + UVM testbenches

**Copy:** verification methodology, register-file design, AXI integration patterns, SystemC/C-model approach for golden reference.
**Don't copy:** the modular block architecture — defeats the purpose of building a systolic array. Read it for taste, not as a template.

`[Source: https://github.com/nvdla/hw, https://nvdla.org]`

---

## Gemmini — UC Berkeley ADEPT Lab

- **Repo:** https://github.com/ucb-bar/gemmini
- **Paper:** https://arxiv.org/abs/1911.09925
- **Language:** Chisel (Scala-embedded HDL); generates Verilog
- **Architecture:** parameterized systolic array generator with **runtime-switchable WS / OS dataflows**
- **Integration:** drops into Rocket Chip (RISC-V SoC); RoCC ISA extension for accelerator commands
- **Closest cousin to the EE470 project.**

**Copy:** parameterization strategy (array size, dtype, dataflow as parameters), the ISA-level command interface design, the bookkeeping of input/output buffers.
**Don't copy:** Chisel itself — the project mandates SystemVerilog. Read the generated Verilog for hand-translatable patterns.

**Most useful sections:** the PE design (`Mesh.scala`), the controller / scratchpad (`Scratchpad.scala`), the high-level architectural diagrams in the paper.

`[Source: https://github.com/ucb-bar/gemmini, arxiv:1911.09925]`

---

## VTA — Versatile Tensor Accelerator (Apache TVM)

- **Repo:** https://github.com/apache/tvm-vta
- **Announcement:** https://tvm.apache.org/2018/07/12/vta-release-announcement
- **Architecture:** accelerator + ISA + compiler stack
- **Programming model:** TVM IR → VTA ISA → hardware
- **End-to-end ML model**: shows how to compile a real network down to accelerator instructions

**Copy:** the ISA + register file abstraction; the decoupled load/compute/store pipeline pattern; the TVM-style instruction queue model.
**Don't copy:** the full TVM software stack — out of scope for EE470. Just understand the hardware-software interface.

`[Source: https://github.com/apache/tvm-vta]`

---

## BoooC Eyeriss-v2 fork

- **Repo:** https://github.com/BoooC/CNN-Accelerator-Based-on-Eyeriss-v2
- **Language:** Verilog/SystemVerilog
- **Architecture:** Eyeriss-v2-derived; supports sparse CNN operations, hybrid dataflows
- **Already linked from project [README.md](../../../README.md).**

**Copy:** the row-stationary PE design, the hierarchical mesh NoC, the sparse-data path if going for advanced energy optimization.
**Don't copy:** the sparse-data path verbatim if you don't have time to verify it — sparse logic adds significant complexity.

`[Source: https://github.com/BoooC/CNN-Accelerator-Based-on-Eyeriss-v2]`

---

## karthisugumar Eyeriss-v2 SystemVerilog

- **Repo:** https://github.com/karthisugumar/CSE240D-Hierarchical_Mesh_NoC-Eyeriss_v2
- **Language:** SystemVerilog (clean academic style)
- **Architecture:** Eyeriss-v2 row-stationary + hierarchical mesh NoC

**Copy:** project structure, NoC routing, file organization. Closest "academic SV reference" to what EE470 is building.
**Don't copy:** test infrastructure if it doesn't match the project's [scripts/sim/runlab.do](../../../../scripts/sim/runlab.do) flow.

`[Source: https://github.com/karthisugumar/CSE240D-Hierarchical_Mesh_NoC-Eyeriss_v2]`

---

## SingularityKChen dl_accelerator

- **Repo:** https://github.com/SingularityKChen/dl_accelerator
- **Language:** Chisel
- **Architecture:** Eyeriss-v2 inside Rocket Chip with custom RISC-V instructions

**Copy:** the SoC integration model, RoCC instruction wiring.
**Don't copy:** Chisel.

`[Source: https://github.com/SingularityKChen/dl_accelerator]`

---

## MIT Eyeriss official site

- **URL:** https://eyeriss.mit.edu/
- **Provides:** original chip docs, energy-efficient dataflow tools (Accelergy, Timeloop), benchmarking suites.
- **Most useful for:** understanding what numbers to measure and how to compare against published data.

**Copy:** the methodology for energy/throughput evaluation.
**Don't copy:** the Accelergy/Timeloop toolflow into the synth flow — out of EE470 scope, useful for the writeup.

`[Source: https://eyeriss.mit.edu/]`

---

## Quick selection table

| Need | Best reference |
|---|---|
| End-to-end systolic array generator | Gemmini |
| Production verification methodology | NVDLA |
| ML compiler ↔ hardware interface | VTA |
| Row-stationary FPGA-targetable RTL | BoooC Eyeriss-v2 / karthisugumar |
| Energy benchmarking methodology | MIT Eyeriss |

---

## Sources (cited above, repeated)

- NVDLA: https://github.com/nvdla/hw, https://nvdla.org
- Gemmini: https://github.com/ucb-bar/gemmini, https://arxiv.org/abs/1911.09925
- VTA: https://github.com/apache/tvm-vta
- BoooC Eyeriss-v2: https://github.com/BoooC/CNN-Accelerator-Based-on-Eyeriss-v2
- karthisugumar Eyeriss-v2: https://github.com/karthisugumar/CSE240D-Hierarchical_Mesh_NoC-Eyeriss_v2
- SingularityKChen dl_accelerator: https://github.com/SingularityKChen/dl_accelerator
- MIT Eyeriss: https://eyeriss.mit.edu/
