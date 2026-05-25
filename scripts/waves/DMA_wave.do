# DMA_wave.do — wave configuration for DMA_testbench
# Run: do scripts/sim/runlab.do DMA

quietly WaveActivateNextPane {} 0

# -------------------------------------------------------------------------
# Clock / Reset
# -------------------------------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix binary /DMA_testbench/clk
add wave -radix binary /DMA_testbench/rst

# -------------------------------------------------------------------------
# Status outputs
# -------------------------------------------------------------------------
add wave -divider "Status"
add wave -radix binary /DMA_testbench/unit_done
add wave -radix binary /DMA_testbench/dma_err
add wave -radix binary /DMA_testbench/store_done

# -------------------------------------------------------------------------
# Ch0 — DMA_LOAD
# -------------------------------------------------------------------------
add wave -divider "Ch0 FIFO (DMA_LOAD)"
add wave -radix binary  /DMA_testbench/ch0_empty
add wave -radix binary  /DMA_testbench/ch0_rd
add wave -radix hex     /DMA_testbench/ch0_rdata

add wave -divider "Ch0 FSM"
add wave -radix symbolic /DMA_testbench/dut/state
add wave -radix binary   /DMA_testbench/dut/r_fetch_mode
add wave -radix unsigned /DMA_testbench/dut/cur_h
add wave -radix unsigned /DMA_testbench/dut/cur_w
add wave -radix binary   /DMA_testbench/dut/is_pad

add wave -divider "HP0 Read Master (DMA_LOAD)"
add wave -radix hex      /DMA_testbench/hp0_araddr
add wave -radix unsigned /DMA_testbench/hp0_arlen
add wave -radix binary   /DMA_testbench/hp0_arvalid
add wave -radix binary   /DMA_testbench/hp0_arready
add wave -radix hex      /DMA_testbench/hp0_rdata
add wave -radix binary   /DMA_testbench/hp0_rvalid
add wave -radix binary   /DMA_testbench/hp0_rlast
add wave -radix binary   /DMA_testbench/hp0_rready
add wave -radix binary   /DMA_testbench/hp0_rresp

add wave -divider "Act Bank Write"
add wave -radix unsigned /DMA_testbench/dma_act_waddr
add wave -radix hex      /DMA_testbench/dma_act_wdata
add wave -radix binary   /DMA_testbench/dma_act_wen
add wave -radix binary   /DMA_testbench/dma_act_bank_full

# -------------------------------------------------------------------------
# Ch1 — WT_LOAD
# -------------------------------------------------------------------------
add wave -divider "Ch1 FIFO (WT_LOAD)"
add wave -radix binary  /DMA_testbench/ch1_empty
add wave -radix binary  /DMA_testbench/ch1_rd
add wave -radix hex     /DMA_testbench/ch1_rdata

add wave -divider "Ch1 FSM"
add wave -radix symbolic /DMA_testbench/dut/ch1_state

add wave -divider "HP1 Read Master (WT_LOAD)"
add wave -radix hex      /DMA_testbench/hp1_araddr
add wave -radix unsigned /DMA_testbench/hp1_arlen
add wave -radix binary   /DMA_testbench/hp1_arvalid
add wave -radix binary   /DMA_testbench/hp1_arready
add wave -radix hex      /DMA_testbench/hp1_rdata
add wave -radix binary   /DMA_testbench/hp1_rvalid
add wave -radix binary   /DMA_testbench/hp1_rlast
add wave -radix binary   /DMA_testbench/hp1_rready

add wave -divider "Weight Bank Write"
add wave -radix unsigned /DMA_testbench/dma_wt_waddr
add wave -radix hex      /DMA_testbench/dma_wt_wdata
add wave -radix binary   /DMA_testbench/dma_wt_wen
add wave -radix binary   /DMA_testbench/dma_wt_bank_full

# -------------------------------------------------------------------------
# HP3 arbiter (shared RES/COEFF/LUT)
# -------------------------------------------------------------------------
add wave -divider "HP3 Arbiter (Ch2>Ch3>Ch4)"
add wave -radix binary /DMA_testbench/dut/ch2_hp3_req
add wave -radix binary /DMA_testbench/dut/ch3_hp3_req
add wave -radix binary /DMA_testbench/dut/ch4_hp3_req

add wave -divider "HP3 Read Master (arbitrated)"
add wave -radix hex      /DMA_testbench/hp3_araddr
add wave -radix unsigned /DMA_testbench/hp3_arlen
add wave -radix binary   /DMA_testbench/hp3_arvalid
add wave -radix binary   /DMA_testbench/hp3_arready
add wave -radix hex      /DMA_testbench/hp3_rdata
add wave -radix binary   /DMA_testbench/hp3_rvalid
add wave -radix binary   /DMA_testbench/hp3_rlast
add wave -radix binary   /DMA_testbench/hp3_rready

# -------------------------------------------------------------------------
# Ch2 — RES_LOAD
# -------------------------------------------------------------------------
add wave -divider "Ch2 FSM (RES_LOAD)"
add wave -radix binary   /DMA_testbench/ch2_empty
add wave -radix binary   /DMA_testbench/ch2_rd
add wave -radix symbolic /DMA_testbench/dut/ch2_state

add wave -divider "Residual Bank Write"
add wave -radix unsigned /DMA_testbench/dma_res_waddr
add wave -radix hex      /DMA_testbench/dma_res_wdata
add wave -radix binary   /DMA_testbench/dma_res_wen

# -------------------------------------------------------------------------
# Ch3 — COEFF_LOAD
# -------------------------------------------------------------------------
add wave -divider "Ch3 FSM (COEFF_LOAD)"
add wave -radix binary   /DMA_testbench/ch3_empty
add wave -radix binary   /DMA_testbench/ch3_rd
add wave -radix symbolic /DMA_testbench/dut/ch3_state
add wave -radix unsigned /DMA_testbench/dut/r3_slot
add wave -radix hex      /DMA_testbench/dut/ch3_beat_buf
add wave -radix hex      /DMA_testbench/dut/coeff_extract

add wave -divider "Coeff BRAM Write"
add wave -radix unsigned /DMA_testbench/dma_coeff_waddr
add wave -radix hex      /DMA_testbench/dma_coeff_wdata
add wave -radix binary   /DMA_testbench/dma_coeff_wen

# -------------------------------------------------------------------------
# Ch4 — LUT_LOAD
# -------------------------------------------------------------------------
add wave -divider "Ch4 FSM (LUT_LOAD)"
add wave -radix binary   /DMA_testbench/ch4_empty
add wave -radix binary   /DMA_testbench/ch4_rd
add wave -radix symbolic /DMA_testbench/dut/ch4_state
add wave -radix unsigned /DMA_testbench/dut/lut_waddr_r
add wave -radix binary   /DMA_testbench/dut/r4_lut_sel

add wave -divider "LUT Bank Write"
add wave -radix unsigned /DMA_testbench/dma_lut_waddr
add wave -radix hex      /DMA_testbench/dma_lut_wdata
add wave -radix binary   /DMA_testbench/dma_lut_wen
add wave -radix binary   /DMA_testbench/dma_lut_sel

# -------------------------------------------------------------------------
# Ch5 — DMA_STORE
# -------------------------------------------------------------------------
add wave -divider "Ch5 FSM (DMA_STORE)"
add wave -radix binary   /DMA_testbench/ch5_empty
add wave -radix binary   /DMA_testbench/ch5_rd
add wave -radix symbolic /DMA_testbench/dut/ch5_state
add wave -radix unsigned /DMA_testbench/dut/r5_beat_cnt

add wave -divider "Output Bank Read"
add wave -radix unsigned /DMA_testbench/dma_out_raddr
add wave -radix hex      /DMA_testbench/dma_out_rdata

add wave -divider "HP2 Write Master (DMA_STORE)"
add wave -radix hex      /DMA_testbench/hp2_awaddr
add wave -radix unsigned /DMA_testbench/hp2_awlen
add wave -radix binary   /DMA_testbench/hp2_awvalid
add wave -radix binary   /DMA_testbench/hp2_awready
add wave -radix hex      /DMA_testbench/hp2_wdata
add wave -radix hex      /DMA_testbench/hp2_wstrb
add wave -radix binary   /DMA_testbench/hp2_wlast
add wave -radix binary   /DMA_testbench/hp2_wvalid
add wave -radix binary   /DMA_testbench/hp2_wready
add wave -radix binary   /DMA_testbench/hp2_bresp
add wave -radix binary   /DMA_testbench/hp2_bvalid
add wave -radix binary   /DMA_testbench/hp2_bready

# -------------------------------------------------------------------------
# Error tracking (testbench scoreboard)
# -------------------------------------------------------------------------
add wave -divider "Scoreboard"
add wave -radix unsigned /DMA_testbench/error_count

configure wave -namecolwidth 240
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns
configure wave -timeline 0

TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {5000 ns}
