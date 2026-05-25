# D_FF_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary /D_FF_tb/clk
add wave -radix binary /D_FF_tb/rst

add wave -divider "Data Path"
add wave -radix hex /D_FF_tb/in
add wave -radix hex /D_FF_tb/out

configure wave -namecolwidth  200
configure wave -valuecolwidth 100
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
