# FIFO_wave.do — sourced by runlab.do after vsim.

add wave -divider "Clock / Reset"
add wave -radix binary /FIFO_tb/clk
add wave -radix binary /FIFO_tb/rst

add wave -divider "Control"
add wave -radix binary /FIFO_tb/wr_en
add wave -radix binary /FIFO_tb/rd_en

add wave -divider "Data"
add wave -radix hex /FIFO_tb/din
add wave -radix hex /FIFO_tb/dout

add wave -divider "Status"
add wave -radix binary /FIFO_tb/full
add wave -radix binary /FIFO_tb/empty

add wave -divider "DUT Internal"
add wave -r /FIFO_tb/dut/*

configure wave -namecolwidth  200
configure wave -valuecolwidth 100
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {500 ns}
