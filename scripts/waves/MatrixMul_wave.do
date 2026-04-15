# MatrixMul_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary /MatrixMul_tb/clk
add wave -radix binary /MatrixMul_tb/rst

add wave -divider "Phase Controls"
add wave -radix binary /MatrixMul_tb/feed_w
add wave -radix binary /MatrixMul_tb/feed_a
add wave -radix binary /MatrixMul_tb/loadingWeight_c
add wave -radix binary /MatrixMul_tb/capture_en

add wave -divider "Weight Input Row"
add wave -radix decimal /MatrixMul_tb/weightInputRow

add wave -divider "Activation Input Col"
add wave -radix decimal /MatrixMul_tb/activationInputCol

add wave -divider "MatrixMul Output"
add wave -radix decimal /MatrixMul_tb/MatrixMulOut

add wave -divider "Captured Result"
add wave -radix decimal /MatrixMul_tb/result

configure wave -namecolwidth   220
configure wave -valuecolwidth  120
configure wave -timelineunits  ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {1 us}
