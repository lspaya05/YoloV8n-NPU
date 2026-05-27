# DMA_wave.do — wave configuration for DMA_tb (Phase 1-7 port set)
# Run: do scripts/sim/runlab.do DMA

quietly WaveActivateNextPane {} 0

# -------------------------------------------------------------------------
# Clock / Reset
# -------------------------------------------------------------------------
add wave -divider "Clock / Reset"
add wave -radix binary /DMA_tb/clk
add wave -radix binary /DMA_tb/rst

# -------------------------------------------------------------------------
# Status
# -------------------------------------------------------------------------
add wave -divider "Status"
add wave -radix binary /DMA_tb/ch0_idle
add wave -radix binary /DMA_tb/ch1_idle
add wave -radix binary /DMA_tb/dma_act_bank_full
add wave -radix binary /DMA_tb/dma_wt_bank_full
add wave -radix binary /DMA_tb/dma_store_done
add wave -radix binary /DMA_tb/dma_err

# -------------------------------------------------------------------------
# Ch0 descriptor + control
# -------------------------------------------------------------------------
add wave -divider "Ch0 Descriptor"
add wave -radix hex      /DMA_tb/src_base
add wave -radix hex      /DMA_tb/row_stride
add wave -radix unsigned /DMA_tb/tile_w
add wave -radix unsigned /DMA_tb/tile_h
add wave -radix unsigned /DMA_tb/ch_count
add wave -radix binary   /DMA_tb/fetch_mode
add wave -radix hex      /DMA_tb/concat_base
add wave -radix unsigned /DMA_tb/coeff_ch_count
add wave -radix binary   /DMA_tb/lut_sel
add wave -radix binary   /DMA_tb/start

# -------------------------------------------------------------------------
# Ch0 FSM internals
# -------------------------------------------------------------------------
add wave -divider "Ch0 Load FSM"
add wave -radix symbolic /DMA_tb/dut/state
add wave -radix binary   /DMA_tb/dut/r_fetch_mode
add wave -radix unsigned /DMA_tb/dut/cur_h
add wave -radix unsigned /DMA_tb/dut/cur_w
add wave -radix binary   /DMA_tb/dut/is_pad
add wave -radix binary   /DMA_tb/dut/concat_phase
add wave -radix binary   /DMA_tb/dut/repeat_w
add wave -radix binary   /DMA_tb/dut/repeat_h

add wave -divider "Ch0 Store FSM"
add wave -radix symbolic /DMA_tb/dut/store_state
add wave -radix unsigned /DMA_tb/dut/store_cur_h
add wave -radix unsigned /DMA_tb/dut/store_beat_idx

# -------------------------------------------------------------------------
# HP0 Read Master
# -------------------------------------------------------------------------
add wave -divider "HP0 Read Master"
add wave -radix hex      /DMA_tb/hp0_araddr
add wave -radix unsigned /DMA_tb/hp0_arlen
add wave -radix binary   /DMA_tb/hp0_arvalid
add wave -radix binary   /DMA_tb/hp0_arready
add wave -radix hex      /DMA_tb/hp0_rdata
add wave -radix binary   /DMA_tb/hp0_rvalid
add wave -radix binary   /DMA_tb/hp0_rlast
add wave -radix binary   /DMA_tb/hp0_rready
add wave -radix binary   /DMA_tb/hp0_rresp

# -------------------------------------------------------------------------
# HP1 Read Master (WT_LOAD)
# -------------------------------------------------------------------------
add wave -divider "HP1 Read Master (WT_LOAD)"
add wave -radix symbolic /DMA_tb/dut/ch1_state
add wave -radix hex      /DMA_tb/wt_src_base
add wave -radix binary   /DMA_tb/ch1_start
add wave -radix hex      /DMA_tb/hp1_araddr
add wave -radix unsigned /DMA_tb/hp1_arlen
add wave -radix binary   /DMA_tb/hp1_arvalid
add wave -radix binary   /DMA_tb/hp1_arready
add wave -radix hex      /DMA_tb/hp1_rdata
add wave -radix binary   /DMA_tb/hp1_rvalid
add wave -radix binary   /DMA_tb/hp1_rlast
add wave -radix binary   /DMA_tb/hp1_rready

# -------------------------------------------------------------------------
# HP2 Write Master (DMA_STORE)
# -------------------------------------------------------------------------
add wave -divider "HP2 Write Master (DMA_STORE)"
add wave -radix hex      /DMA_tb/hp2_awaddr
add wave -radix unsigned /DMA_tb/hp2_awlen
add wave -radix binary   /DMA_tb/hp2_awvalid
add wave -radix binary   /DMA_tb/hp2_awready
add wave -radix hex      /DMA_tb/hp2_wdata
add wave -radix hex      /DMA_tb/hp2_wstrb
add wave -radix binary   /DMA_tb/hp2_wlast
add wave -radix binary   /DMA_tb/hp2_wvalid
add wave -radix binary   /DMA_tb/hp2_wready
add wave -radix binary   /DMA_tb/hp2_bresp
add wave -radix binary   /DMA_tb/hp2_bvalid
add wave -radix binary   /DMA_tb/hp2_bready

# -------------------------------------------------------------------------
# SRAM ports
# -------------------------------------------------------------------------
add wave -divider "Act Bank Write"
add wave -radix unsigned /DMA_tb/sram_waddr
add wave -radix hex      /DMA_tb/sram_wdata
add wave -radix binary   /DMA_tb/sram_wen

add wave -divider "Wt Bank Write"
add wave -radix unsigned /DMA_tb/sram_wt_waddr
add wave -radix hex      /DMA_tb/sram_wt_wdata
add wave -radix binary   /DMA_tb/sram_wt_wen

add wave -divider "Coeff BRAM Write"
add wave -radix unsigned /DMA_tb/sram_coeff_waddr
add wave -radix hex      /DMA_tb/sram_coeff_wdata
add wave -radix binary   /DMA_tb/sram_coeff_wen

add wave -divider "LUT BRAM Write"
add wave -radix unsigned /DMA_tb/sram_lut_waddr
add wave -radix hex      /DMA_tb/sram_lut_wdata
add wave -radix binary   /DMA_tb/sram_lut_wen
add wave -radix binary   /DMA_tb/sram_lut_sel

add wave -divider "Output Bank Read (STORE)"
add wave -radix unsigned /DMA_tb/sram_raddr
add wave -radix hex      /DMA_tb/sram_rdata

# -------------------------------------------------------------------------
# Dep ports
# -------------------------------------------------------------------------
add wave -divider "Dep Tokens"
add wave -radix binary /DMA_tb/dep_sa_to_dma_empty
add wave -radix binary /DMA_tb/dep_vpu_to_dma_empty
add wave -radix binary /DMA_tb/dep_dma_to_sa_push
add wave -radix binary /DMA_tb/dep_dma_to_vpu_push

# -------------------------------------------------------------------------
# Scoreboard
# -------------------------------------------------------------------------
add wave -divider "Scoreboard"
add wave -radix unsigned /DMA_tb/err_cnt
add wave -radix unsigned /DMA_tb/store_count

configure wave -namecolwidth 240
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns
configure wave -timeline 0

TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ns} {5000 ns}
