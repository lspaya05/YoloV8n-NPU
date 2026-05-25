# psb_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.

add wave -divider "Clock / Reset"
add wave -radix binary /psb_tb/clk
add wave -radix binary /psb_tb/rst

add wave -divider "Control"
add wave -radix binary /psb_tb/psb_acc
add wave -radix binary /psb_tb/psb_flush
add wave -radix binary /psb_tb/row_valid

add wave -divider "Input Row"
add wave -radix decimal /psb_tb/sa_row_in

add wave -divider "Status"
add wave -radix binary /psb_tb/busy
add wave -radix binary /psb_tb/acc_done
add wave -radix binary /psb_tb/flush_done

add wave -divider "Output"
add wave -radix binary   /psb_tb/row_out_valid
add wave -radix unsigned /psb_tb/row_index_out
add wave -radix hex      /psb_tb/requant_row_out

add wave -divider "DUT Internals"
add wave -radix symbolic /psb_tb/dut/ps

configure wave -namecolwidth  220
configure wave -valuecolwidth 120
configure wave -timelineunits ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {5 us}
