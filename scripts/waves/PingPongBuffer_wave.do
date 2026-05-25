# PingPongBuffer_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.
# Run: do scripts/sim/runlab.do PingPongBuffer

add wave -divider "Clock / Reset"
add wave -radix binary /PingPongBuffer_tb/clk
add wave -radix binary /PingPongBuffer_tb/rst

add wave -divider "DMA Write Port"
add wave -radix unsigned /PingPongBuffer_tb/w_addr
add wave -radix hex      /PingPongBuffer_tb/w_data
add wave -radix binary   /PingPongBuffer_tb/write_en
add wave -radix binary   /PingPongBuffer_tb/bank_full

add wave -divider "SA Read Port"
add wave -radix unsigned /PingPongBuffer_tb/r_addr
add wave -radix hex      /PingPongBuffer_tb/r_data
add wave -radix binary   /PingPongBuffer_tb/bank_read

add wave -divider "Internal State"
add wave -radix binary   /PingPongBuffer_tb/dut/bank_sel

add wave -divider "Golden Model"
add wave -radix binary   /PingPongBuffer_tb/gsel
add wave -radix unsigned /PingPongBuffer_tb/cnt

configure wave -namecolwidth   220
configure wave -valuecolwidth  120
configure wave -timelineunits  ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
