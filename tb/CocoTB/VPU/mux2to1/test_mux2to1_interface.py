import os
from cocotb_test.simulator import run

def test_mux2to1_interface():
    tests_dir = os.path.dirname(__file__)
    hw_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', '..', '..', 'src', 'VectorProcessingUnit'))

    run(
        verilog_sources=[os.path.join(hw_dir, "mux2to1.sv")],
        toplevel="mux2to1",
        module="test_mux2to1",
        simulator="verilator",
        timescale="1ns/1ps",
        waves=True,
        sim_build="sim_build/mux2to1_test"    # Isolates waveforms and logs into a unique folder
    )