# EE470 NPU Linux Driver

This directory contains the Linux side of the FPGA interface described in
`notes/Architecture-FINAL/NPUArchitectureV2.md`.

The driver is a platform character device for `/dev/npu0`. It maps the NPU
AXI-Lite CSR window, allocates DMA-coherent DDR buffers, loads 128-bit
instruction streams, kicks the sequencer, and waits for the per-frame
completion interrupt.

## Build

On the KR260 Ubuntu image with kernel headers installed:

```sh
make
sudo insmod ee470_npu.ko
```

The device tree must expose a node compatible with `ee470,npu-v2`; see
`npu-devicetree.dtsi`.

## Userspace ABI

Include `npu_uapi.h` in the PyTorch custom op or smoke-test program.

Supported ioctls:

- `EE470_NPU_IOC_QUERY_BUFFERS`: returns coherent buffer sizes, DMA addresses,
  and mmap offsets.
- `EE470_NPU_IOC_LOAD_WEIGHTS`: copies model weights into the weight buffer.
- `EE470_NPU_IOC_WRITE_BUFFER`: copies input, coefficients, LUTs, or activation
  data into a selected buffer.
- `EE470_NPU_IOC_READ_BUFFER`: copies output or intermediate buffers back.
- `EE470_NPU_IOC_DISPATCH`: copies a 128-bit instruction program to the
  instruction buffer, writes `INSTR_BASE` and `INSTR_COUNT`, then asserts
  `CONTROL.START`.
- `EE470_NPU_IOC_WAIT_DONE`: blocks until the frame completion interrupt.
- `EE470_NPU_IOC_RESET`: pulses the soft reset CSR.

Buffers can also be mapped directly. Call `mmap()` with `offset =
buffer_id * getpagesize()`. The returned mapping is the coherent buffer used by
the NPU DMA engines.

## CSR Contract

The RTL should implement this AXI-Lite map:

| Offset | Register |
|---:|---|
| `0x00` | `VERSION` |
| `0x04` | `CONTROL` bit 0 `START`, bit 1 `RESET` |
| `0x08` | `STATUS` bit 0 `BUSY`, bit 1 `DONE`, bit 2 `ERROR` |
| `0x0c` | `IRQ_ENABLE` bit 0 `DONE`, bit 1 `ERROR` |
| `0x10` | `IRQ_STATUS` write-1-to-clear, bit 0 `DONE`, bit 1 `ERROR` |
| `0x20` | `INSTR_BASE_LO` |
| `0x24` | `INSTR_BASE_HI` |
| `0x28` | `INSTR_COUNT` in 128-bit words |
| `0x40..0x7c` | eight 64-bit coherent buffer base addresses |

The buffer slots are ordered as `INSTR`, `WEIGHTS`, `COEFF`, `INPUT`,
`ACTIVATION`, `SKIP`, `LUT`, and `OUTPUT`.

## Model Note

The linked Ultralytics tag is package release `v8.4.53`, not a special hardware
model checkpoint. Use YOLOv8n from that Ultralytics version as the floating
point source, then run offline INT8 PTQ/QAT export. The hardware path expects
folded Conv+BN weights, per-channel requant `(M, S)` coefficients, INT8
activations/weights, and precomputed SiLU/HREDUCE LUTs.
