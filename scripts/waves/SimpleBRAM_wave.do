# SimpleBRAM_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock"
add wave -radix binary /SimpleBRAM_tb/clk

add wave -divider "Write Port"
add wave -radix binary   /SimpleBRAM_tb/w_en
add wave -radix unsigned /SimpleBRAM_tb/w_addr
add wave -radix hex      /SimpleBRAM_tb/w_data

add wave -divider "Read Port"
add wave -radix unsigned /SimpleBRAM_tb/r_addr
add wave -radix hex      /SimpleBRAM_tb/r_data

configure wave -namecolwidth  200
configure wave -valuecolwidth 100
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {3 us}
