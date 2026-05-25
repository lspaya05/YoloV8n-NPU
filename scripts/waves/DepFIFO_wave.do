# DepFIFO_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary /DepFIFO_tb/clk
add wave -radix binary /DepFIFO_tb/rst

add wave -divider "Control"
add wave -radix binary /DepFIFO_tb/push
add wave -radix binary /DepFIFO_tb/pop

add wave -divider "Status"
add wave -radix binary  /DepFIFO_tb/full
add wave -radix binary  /DepFIFO_tb/empty

add wave -divider "DUT Internals"
add wave -radix unsigned /DepFIFO_tb/dut/mem

configure wave -namecolwidth  200
configure wave -valuecolwidth 100
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
