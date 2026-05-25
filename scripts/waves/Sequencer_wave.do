# Sequencer_wave.do
# Sourced by scripts/sim/runlab.do after vsim Sequencer_tb.
# Usage: do scripts/sim/runlab.do Sequencer

add wave -divider "Clock / Reset"
add wave -radix binary /Sequencer_tb/clk
add wave -radix binary /Sequencer_tb/rst

add wave -divider "AXI-Lite CSR"
add wave -radix hex    /Sequencer_tb/s_axil_awaddr
add wave -radix binary /Sequencer_tb/s_axil_awvalid
add wave -radix binary /Sequencer_tb/s_axil_awready
add wave -radix hex    /Sequencer_tb/s_axil_wdata
add wave -radix binary /Sequencer_tb/s_axil_wvalid
add wave -radix binary /Sequencer_tb/s_axil_wready
add wave -radix binary /Sequencer_tb/s_axil_bvalid
add wave -radix binary /Sequencer_tb/s_axil_bready

add wave -divider "AXI4 Fetch-AR"
add wave -radix hex    /Sequencer_tb/m_axi_araddr
add wave -radix binary /Sequencer_tb/m_axi_arvalid
add wave -radix binary /Sequencer_tb/m_axi_arready
add wave -radix unsigned /Sequencer_tb/m_axi_arlen

add wave -divider "AXI4 Fetch-R"
add wave -radix hex    /Sequencer_tb/m_axi_rdata
add wave -radix binary /Sequencer_tb/m_axi_rvalid
add wave -radix binary /Sequencer_tb/m_axi_rlast
add wave -radix binary /Sequencer_tb/m_axi_rresp
add wave -radix binary /Sequencer_tb/m_axi_rready

add wave -divider "FSM Internals"
add wave -radix symbolic /Sequencer_tb/dut/state
add wave -radix hex      /Sequencer_tb/dut/fetch_ptr
add wave -radix unsigned /Sequencer_tb/dut/fetch_remaining
add wave -radix unsigned /Sequencer_tb/dut/beat_cnt
add wave -radix hex      /Sequencer_tb/dut/instr_buf

add wave -divider "Dispatch"
add wave -radix binary /Sequencer_tb/fifo_push
add wave -radix hex    /Sequencer_tb/fifo_payload
add wave -radix binary /Sequencer_tb/fifo_full
add wave -radix binary /Sequencer_tb/dut/target_bit
add wave -radix binary /Sequencer_tb/dut/dispatch_stall

add wave -divider "Config Outputs"
add wave -radix unsigned /Sequencer_tb/cfg_tile_M
add wave -radix unsigned /Sequencer_tb/cfg_tile_N
add wave -radix unsigned /Sequencer_tb/cfg_tile_K
add wave -radix unsigned /Sequencer_tb/cfg_stride
add wave -radix unsigned /Sequencer_tb/cfg_pad_mode
add wave -radix unsigned /Sequencer_tb/cfg_act_type
add wave -radix unsigned /Sequencer_tb/cfg_pool_size
add wave -radix hex      /Sequencer_tb/cfg_coeff_base

add wave -divider "Status"
add wave -radix binary   /Sequencer_tb/irq_done
add wave -radix binary   /Sequencer_tb/fetch_err
add wave -radix binary   /Sequencer_tb/dut/job_active
add wave -radix binary   /Sequencer_tb/dut/fence_mask
add wave -radix binary   /Sequencer_tb/unit_done

configure wave -namecolwidth   220
configure wave -valuecolwidth  100
configure wave -timelineunits  ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {2 us}
