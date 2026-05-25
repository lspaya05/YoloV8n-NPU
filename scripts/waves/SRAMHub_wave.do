# SRAMHub_wave.do
# Sourced by scripts/sim/runlab.do after vsim launches.
# Run: do scripts/sim/runlab.do SRAMHub

add wave -divider "Clock / Reset"
add wave -radix binary  /SRAMHub_tb/clk
add wave -radix binary  /SRAMHub_tb/rst

add wave -divider "Residual Bank"
add wave -radix unsigned /SRAMHub_tb/dma_res_waddr
add wave -radix hex      /SRAMHub_tb/dma_res_wdata
add wave -radix binary   /SRAMHub_tb/dma_res_wen
add wave -radix unsigned /SRAMHub_tb/vpu_res_raddr
add wave -radix hex      /SRAMHub_tb/vpu_res_rdata

add wave -divider "Output Bank"
add wave -radix unsigned /SRAMHub_tb/vpu_out_waddr
add wave -radix hex      /SRAMHub_tb/vpu_out_wdata
add wave -radix binary   /SRAMHub_tb/vpu_out_wen
add wave -radix binary   /SRAMHub_tb/out_rd_sel
add wave -radix unsigned /SRAMHub_tb/dma_out_raddr
add wave -radix hex      /SRAMHub_tb/dma_out_rdata
add wave -radix unsigned /SRAMHub_tb/vpu_hred_raddr
add wave -radix hex      /SRAMHub_tb/vpu_hred_rdata

add wave -divider "Coeff BRAM"
add wave -radix unsigned /SRAMHub_tb/dma_coeff_waddr
add wave -radix hex      /SRAMHub_tb/dma_coeff_wdata
add wave -radix binary   /SRAMHub_tb/dma_coeff_wen
add wave -radix unsigned /SRAMHub_tb/req_coeff_raddr
add wave -radix hex      /SRAMHub_tb/req_coeff_rdata

add wave -divider "LUT Banks"
add wave -radix unsigned /SRAMHub_tb/dma_lut_waddr
add wave -radix hex      /SRAMHub_tb/dma_lut_wdata
add wave -radix binary   /SRAMHub_tb/dma_lut_wen
add wave -radix binary   /SRAMHub_tb/dma_lut_sel
add wave -radix unsigned /SRAMHub_tb/vpu_lut_raddr
add wave -radix hex      /SRAMHub_tb/vpu_lut_rdata
add wave -radix binary   /SRAMHub_tb/vpu_lut_sel

add wave -divider "Activation Ping-Pong"
add wave -radix unsigned /SRAMHub_tb/dma_act_waddr
add wave -radix hex      /SRAMHub_tb/dma_act_wdata
add wave -radix binary   /SRAMHub_tb/dma_act_wen
add wave -radix binary   /SRAMHub_tb/dma_act_bank_full
add wave -radix unsigned /SRAMHub_tb/sa_act_raddr
add wave -radix hex      /SRAMHub_tb/sa_act_rdata
add wave -radix binary   /SRAMHub_tb/sa_act_bank_read
add wave -radix binary   /SRAMHub_tb/dut/act_buf/bank_sel

add wave -divider "Weight Ping-Pong"
add wave -radix unsigned /SRAMHub_tb/dma_wt_waddr
add wave -radix hex      /SRAMHub_tb/dma_wt_wdata
add wave -radix binary   /SRAMHub_tb/dma_wt_wen
add wave -radix binary   /SRAMHub_tb/dma_wt_bank_full
add wave -radix unsigned /SRAMHub_tb/sa_wt_raddr
add wave -radix hex      /SRAMHub_tb/sa_wt_rdata
add wave -radix binary   /SRAMHub_tb/sa_wt_bank_read
add wave -radix binary   /SRAMHub_tb/dut/wt_buf/bank_sel

add wave -divider "Golden / Counter"
add wave -radix unsigned /SRAMHub_tb/cnt
add wave -radix binary   /SRAMHub_tb/act_gsel
add wave -radix binary   /SRAMHub_tb/wt_gsel

configure wave -namecolwidth   240
configure wave -valuecolwidth  120
configure wave -timelineunits  ns
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {5 us}
