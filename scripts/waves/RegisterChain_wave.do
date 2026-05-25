# RegisterChain_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary /RegisterChain_tb/clk
add wave -radix binary /RegisterChain_tb/rst

add wave -divider "Chain-0 (passthrough)"
add wave -radix hex /RegisterChain_tb/in0
add wave -radix hex /RegisterChain_tb/out0

add wave -divider "Chain-1"
add wave -radix hex /RegisterChain_tb/in1
add wave -radix hex /RegisterChain_tb/out1

add wave -divider "Chain-4"
add wave -radix hex /RegisterChain_tb/in4
add wave -radix hex /RegisterChain_tb/out4

configure wave -namecolwidth  220
configure wave -valuecolwidth 100
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {2 us}
