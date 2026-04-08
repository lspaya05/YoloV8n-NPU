# Systolic Array Dataflows — Comparison

Always be extremely concise. Sacrifice grammar for the sake of concision.

Three canonical dataflows for spatial accelerators. The taxonomy is from Chen et al. (Eyeriss). Each dataflow defines which tensor stays "stationary" in the PE array and which streams across.

---

## Weight-Stationary (WS) — TPU pattern

**Stationary:** filter weights, preloaded into PEs.
**Streaming:** activations across rows; partial sums down columns.
**Reuse:** maximum **weight reuse** (each weight is used for every activation in the input feature map).

### When to use

- Batched inference (MLPs, CNNs with large input feature maps).
- Fixed model — load weights once per layer, then run many activations.
- Workloads where weight memory is the constraint, not activation memory.

### Pros / Cons

- Pros: simple control, deterministic, easy timing closure, max throughput when batched.
- Cons: weak activation reuse; needs tall input/output buffers; doesn't adapt well to small batch / depthwise convs.

`[Source: Jouppi et al., "In-Datacenter Performance Analysis of a Tensor Processing Unit", ISCA 2017, arxiv:1704.04760, papers/TPU2017.pdf]`

---

## Output-Stationary (OS)

**Stationary:** partial sums, accumulated in place.
**Streaming:** weights and activations both flow through the array.
**Reuse:** maximum **partial-sum reuse** (no extra register transfers for accumulation).

### When to use

- Dense GEMM with little input/weight reuse.
- Training (gradient updates need fresh weights every step).
- When you want max PE utilization at the cost of memory bandwidth.

### Pros / Cons

- Pros: high PE utilization on dense GEMM, simplest accumulation logic.
- Cons: high external bandwidth demand (weights and activations both stream).

`[Source: papers/SurveyOfAcceleratorArch2019.pdf, "Dataflow Taxonomy"]`

---

## Row-Stationary (RS) — Eyeriss pattern

**Stationary:** rows of weights *and* rows of input pixels stay local to a PE for the duration of one row of convolution. Partial sums accumulate vertically.
**Streaming:** filter rows broadcast horizontally, image rows broadcast diagonally, partial sums accumulate vertically.
**Reuse:** balanced — weight reuse, activation reuse, AND partial-sum reuse all exploited.

### When to use

- CNN inference with varying filter shapes (1×1, 3×3, 5×5, depthwise) — Eyeriss adapts at runtime.
- Energy-constrained edge inference.

### Pros / Cons

- Pros: 1.4–2.5× better energy than WS/OS on AlexNet conv layers (measured silicon). Adapts to many filter shapes via reconfigurable NoC.
- Cons: complex control + reconfigurable NoC; harder to verify; harder to map onto a fixed FPGA fabric.

`[Source: Chen et al., "Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow", ISCA 2016 / JSSC 2017, papers/Eyeriss2017.pdf]`

---

## Side-by-side

| Aspect | WS (TPU) | OS | RS (Eyeriss) |
|---|---|---|---|
| Stationary tensor | weights | partial sums | rows of W + rows of A |
| Reuse maximized | weights | partial sums | all three |
| Best workload | batched MLP/CNN inference | dense GEMM, training | varying-shape CNN inference |
| Energy efficiency on conv | baseline | baseline | **1.4–2.5× better** |
| Control complexity | low | low | high |
| NoC complexity | low (mesh) | low (mesh) | high (reconfigurable mesh) |
| FPGA fit | excellent | excellent | moderate (NoC overhead) |
| Recommended for EE470 | YES if going TPU-style | optional | YES if going Eyeriss-style; harder to build |

---

## Recommendation for EE470

**Start with weight-stationary** for the v1 build. Rationale:
1. Simpler control logic → easier RTL → easier debug → faster to first-silicon-equivalent.
2. Maps cleanly onto a square grid of DSP58 MACs.
3. Verification path (directed TB → UVM env → SVA on AXI handshakes) is straightforward.
4. Once correctness is proven, the v2 build can experiment with row-stationary if time permits.

`[Source: engineering judgment + papers/TPU2017.pdf for the WS reference design]`

If the team specifically wants energy efficiency on convolutional layers and has time to design a reconfigurable NoC, then row-stationary is the higher-ceiling target. `[Source: papers/Eyeriss2017.pdf]`

---

## Sources

- Jouppi et al., ISCA 2017, arxiv:1704.04760, https://arxiv.org/abs/1704.04760
- Chen et al., ISCA 2016, https://eems.mit.edu/wp-content/uploads/2016/04/eyeriss_isca_2016.pdf
- Chen et al., JSSC 2017, https://eyeriss.mit.edu/
- Chen et al., Eyeriss v2, JETCAS 2019
- Sze, Chen, Yang, Emer, "Efficient Processing of Deep Neural Networks", Morgan & Claypool 2020
- Local papers: papers/TPU2017.pdf, papers/Eyeriss2017.pdf, papers/SurveyOfAcceleratorArch2019.pdf
