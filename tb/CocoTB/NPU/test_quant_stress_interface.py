import os
import glob
from cocotb_test.simulator import run


def get_npu_sources():
    src = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'src'))
    pkgs = sorted(glob.glob(os.path.join(src, 'packages', '*.sv')))
    rest = [f for f in sorted(glob.glob(os.path.join(src, '**', '*.sv'), recursive=True))
            if f not in pkgs]
    return pkgs + rest


def test_quant_stress_interface():
    run(
        verilog_sources=get_npu_sources(),
        toplevel='NPU',
        module='test_quant_stress',
        simulator='verilator',
        timescale='1ns/1ps',
        compile_args=['--sv', '--timing',
                      '-Wno-TIMESCALEMOD', '-Wno-INITIALDLY',
                      '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC', '--public'],
        waves=True,
        plus_args=['--trace'],
        sim_build='sim_build/NPU_build',
    )
