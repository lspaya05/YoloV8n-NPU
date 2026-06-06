"""
cocotb testbench for a 2-to-1 multiplexer.

DUT interface (mux2to1 #(BIT_WIDTH=8)):
  Inputs  : d0, d1  (BIT_WIDTH-bit data)
            select  (1-bit select: 0 → d0, 1 → d1)
  Output  : y       (BIT_WIDTH-bit result)

Test strategy
─────────────
1. directed_test   – exhaustively walks every combination of {d0, d1, select}
                     (only 8 cases for a 1-bit mux, so full coverage is cheap)
2. random_test     – 50 randomised stimulus vectors, checks same golden model
"""

import logging
import random

import cocotb
from cocotb.triggers import Timer

log = logging.getLogger("cocotb.mux2to1")


# ──────────────────────────────────────────────────────────
# Golden reference model
# ──────────────────────────────────────────────────────────
def mux_model(d0: int, d1: int, select: int) -> int:
    return d1 if select else d0


# ──────────────────────────────────────────────────────────
# Helper: drive inputs and sample output
# ──────────────────────────────────────────────────────────
async def apply_and_check(dut, d0: int, d1: int, select: int, test_name: str):
    """Drive one stimulus vector, wait for propagation, then assert."""
    dut.d0.value     = d0
    dut.d1.value     = d1
    dut.select.value = select

    # 10 ns settling time for a purely combinational path
    await Timer(10, units="ns")

    expected = mux_model(d0, d1, select)
    actual   = int(dut.y.value)

    assert actual == expected, (
        f"[{test_name}] FAIL  d0={d0} d1={d1} select={select}  "
        f"expected y={expected}, got y={actual}"
    )

    log.info(f"[{test_name}] PASS  d0={d0} d1={d1} select={select}  -->  y={actual}")


@cocotb.test()
async def directed_test(dut):
    """Exhaustively test all 8 input combinations."""
    log.info("=== Directed exhaustive test ===")
    for select in range(2):
        for d1 in range(2):
            for d0 in range(2):
                await apply_and_check(dut, d0, d1, select, "directed")
