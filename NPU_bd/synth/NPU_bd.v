//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Mon Jun  8 23:11:10 2026
//Host        : PaPayaPC running 64-bit major release  (build 9200)
//Command     : generate_target NPU_bd.bd
//Design      : NPU_bd
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "NPU_bd,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=NPU_bd,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=6,numReposBlks=6,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,da_axi4_cnt=9,da_board_cnt=3,da_zynq_ultra_ps_e_cnt=1,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "NPU_bd.hwdef" *) 
module NPU_bd
   ();

  wire [43:0]NPU_0_dma_ARADDR;
  wire [1:0]NPU_0_dma_ARBURST;
  wire [3:0]NPU_0_dma_ARCACHE;
  wire [7:0]NPU_0_dma_ARLEN;
  wire NPU_0_dma_ARREADY;
  wire [2:0]NPU_0_dma_ARSIZE;
  wire NPU_0_dma_ARVALID;
  wire [127:0]NPU_0_dma_RDATA;
  wire NPU_0_dma_RLAST;
  wire NPU_0_dma_RREADY;
  wire [1:0]NPU_0_dma_RRESP;
  wire NPU_0_dma_RVALID;
  wire NPU_0_irq_done;
  wire [43:0]NPU_0_seq_ARADDR;
  wire [1:0]NPU_0_seq_ARBURST;
  wire [7:0]NPU_0_seq_ARLEN;
  wire NPU_0_seq_ARREADY;
  wire [2:0]NPU_0_seq_ARSIZE;
  wire NPU_0_seq_ARVALID;
  wire [31:0]NPU_0_seq_RDATA;
  wire NPU_0_seq_RLAST;
  wire NPU_0_seq_RREADY;
  wire [1:0]NPU_0_seq_RRESP;
  wire NPU_0_seq_RVALID;
  wire [43:0]NPU_0_st_AWADDR;
  wire [1:0]NPU_0_st_AWBURST;
  wire [3:0]NPU_0_st_AWCACHE;
  wire [7:0]NPU_0_st_AWLEN;
  wire NPU_0_st_AWREADY;
  wire [2:0]NPU_0_st_AWSIZE;
  wire NPU_0_st_AWVALID;
  wire NPU_0_st_BREADY;
  wire [1:0]NPU_0_st_BRESP;
  wire NPU_0_st_BVALID;
  wire [127:0]NPU_0_st_WDATA;
  wire NPU_0_st_WLAST;
  wire NPU_0_st_WREADY;
  wire [15:0]NPU_0_st_WSTRB;
  wire NPU_0_st_WVALID;
  wire [43:0]NPU_0_wt_ARADDR;
  wire [1:0]NPU_0_wt_ARBURST;
  wire [3:0]NPU_0_wt_ARCACHE;
  wire [7:0]NPU_0_wt_ARLEN;
  wire NPU_0_wt_ARREADY;
  wire [2:0]NPU_0_wt_ARSIZE;
  wire NPU_0_wt_ARVALID;
  wire [127:0]NPU_0_wt_RDATA;
  wire NPU_0_wt_RLAST;
  wire NPU_0_wt_RREADY;
  wire [1:0]NPU_0_wt_RRESP;
  wire NPU_0_wt_RVALID;
  wire [48:0]axi_smc_1_M00_AXI_ARADDR;
  wire [1:0]axi_smc_1_M00_AXI_ARBURST;
  wire [3:0]axi_smc_1_M00_AXI_ARCACHE;
  wire [7:0]axi_smc_1_M00_AXI_ARLEN;
  wire [0:0]axi_smc_1_M00_AXI_ARLOCK;
  wire [2:0]axi_smc_1_M00_AXI_ARPROT;
  wire [3:0]axi_smc_1_M00_AXI_ARQOS;
  wire axi_smc_1_M00_AXI_ARREADY;
  wire [2:0]axi_smc_1_M00_AXI_ARSIZE;
  wire axi_smc_1_M00_AXI_ARVALID;
  wire [48:0]axi_smc_1_M00_AXI_AWADDR;
  wire [1:0]axi_smc_1_M00_AXI_AWBURST;
  wire [3:0]axi_smc_1_M00_AXI_AWCACHE;
  wire [7:0]axi_smc_1_M00_AXI_AWLEN;
  wire [0:0]axi_smc_1_M00_AXI_AWLOCK;
  wire [2:0]axi_smc_1_M00_AXI_AWPROT;
  wire [3:0]axi_smc_1_M00_AXI_AWQOS;
  wire axi_smc_1_M00_AXI_AWREADY;
  wire [2:0]axi_smc_1_M00_AXI_AWSIZE;
  wire axi_smc_1_M00_AXI_AWVALID;
  wire axi_smc_1_M00_AXI_BREADY;
  wire [1:0]axi_smc_1_M00_AXI_BRESP;
  wire axi_smc_1_M00_AXI_BVALID;
  wire [127:0]axi_smc_1_M00_AXI_RDATA;
  wire axi_smc_1_M00_AXI_RLAST;
  wire axi_smc_1_M00_AXI_RREADY;
  wire [1:0]axi_smc_1_M00_AXI_RRESP;
  wire axi_smc_1_M00_AXI_RVALID;
  wire [127:0]axi_smc_1_M00_AXI_WDATA;
  wire axi_smc_1_M00_AXI_WLAST;
  wire axi_smc_1_M00_AXI_WREADY;
  wire [15:0]axi_smc_1_M00_AXI_WSTRB;
  wire axi_smc_1_M00_AXI_WVALID;
  wire [48:0]axi_smc_1_M01_AXI_ARADDR;
  wire [1:0]axi_smc_1_M01_AXI_ARBURST;
  wire [3:0]axi_smc_1_M01_AXI_ARCACHE;
  wire [7:0]axi_smc_1_M01_AXI_ARLEN;
  wire [0:0]axi_smc_1_M01_AXI_ARLOCK;
  wire [2:0]axi_smc_1_M01_AXI_ARPROT;
  wire [3:0]axi_smc_1_M01_AXI_ARQOS;
  wire axi_smc_1_M01_AXI_ARREADY;
  wire [2:0]axi_smc_1_M01_AXI_ARSIZE;
  wire axi_smc_1_M01_AXI_ARVALID;
  wire [48:0]axi_smc_1_M01_AXI_AWADDR;
  wire [1:0]axi_smc_1_M01_AXI_AWBURST;
  wire [3:0]axi_smc_1_M01_AXI_AWCACHE;
  wire [7:0]axi_smc_1_M01_AXI_AWLEN;
  wire [0:0]axi_smc_1_M01_AXI_AWLOCK;
  wire [2:0]axi_smc_1_M01_AXI_AWPROT;
  wire [3:0]axi_smc_1_M01_AXI_AWQOS;
  wire axi_smc_1_M01_AXI_AWREADY;
  wire [2:0]axi_smc_1_M01_AXI_AWSIZE;
  wire axi_smc_1_M01_AXI_AWVALID;
  wire axi_smc_1_M01_AXI_BREADY;
  wire [1:0]axi_smc_1_M01_AXI_BRESP;
  wire axi_smc_1_M01_AXI_BVALID;
  wire [127:0]axi_smc_1_M01_AXI_RDATA;
  wire axi_smc_1_M01_AXI_RLAST;
  wire axi_smc_1_M01_AXI_RREADY;
  wire [1:0]axi_smc_1_M01_AXI_RRESP;
  wire axi_smc_1_M01_AXI_RVALID;
  wire [127:0]axi_smc_1_M01_AXI_WDATA;
  wire axi_smc_1_M01_AXI_WLAST;
  wire axi_smc_1_M01_AXI_WREADY;
  wire [15:0]axi_smc_1_M01_AXI_WSTRB;
  wire axi_smc_1_M01_AXI_WVALID;
  wire [48:0]axi_smc_1_M02_AXI_ARADDR;
  wire [1:0]axi_smc_1_M02_AXI_ARBURST;
  wire [3:0]axi_smc_1_M02_AXI_ARCACHE;
  wire [7:0]axi_smc_1_M02_AXI_ARLEN;
  wire [0:0]axi_smc_1_M02_AXI_ARLOCK;
  wire [2:0]axi_smc_1_M02_AXI_ARPROT;
  wire [3:0]axi_smc_1_M02_AXI_ARQOS;
  wire axi_smc_1_M02_AXI_ARREADY;
  wire [2:0]axi_smc_1_M02_AXI_ARSIZE;
  wire axi_smc_1_M02_AXI_ARVALID;
  wire [48:0]axi_smc_1_M02_AXI_AWADDR;
  wire [1:0]axi_smc_1_M02_AXI_AWBURST;
  wire [3:0]axi_smc_1_M02_AXI_AWCACHE;
  wire [7:0]axi_smc_1_M02_AXI_AWLEN;
  wire [0:0]axi_smc_1_M02_AXI_AWLOCK;
  wire [2:0]axi_smc_1_M02_AXI_AWPROT;
  wire [3:0]axi_smc_1_M02_AXI_AWQOS;
  wire axi_smc_1_M02_AXI_AWREADY;
  wire [2:0]axi_smc_1_M02_AXI_AWSIZE;
  wire axi_smc_1_M02_AXI_AWVALID;
  wire axi_smc_1_M02_AXI_BREADY;
  wire [1:0]axi_smc_1_M02_AXI_BRESP;
  wire axi_smc_1_M02_AXI_BVALID;
  wire [127:0]axi_smc_1_M02_AXI_RDATA;
  wire axi_smc_1_M02_AXI_RLAST;
  wire axi_smc_1_M02_AXI_RREADY;
  wire [1:0]axi_smc_1_M02_AXI_RRESP;
  wire axi_smc_1_M02_AXI_RVALID;
  wire [127:0]axi_smc_1_M02_AXI_WDATA;
  wire axi_smc_1_M02_AXI_WLAST;
  wire axi_smc_1_M02_AXI_WREADY;
  wire [15:0]axi_smc_1_M02_AXI_WSTRB;
  wire axi_smc_1_M02_AXI_WVALID;
  wire [31:0]axi_smc_M00_AXI_AWADDR;
  wire axi_smc_M00_AXI_AWREADY;
  wire axi_smc_M00_AXI_AWVALID;
  wire axi_smc_M00_AXI_BREADY;
  wire [1:0]axi_smc_M00_AXI_BRESP;
  wire axi_smc_M00_AXI_BVALID;
  wire [31:0]axi_smc_M00_AXI_WDATA;
  wire axi_smc_M00_AXI_WREADY;
  wire axi_smc_M00_AXI_WVALID;
  wire clk_wiz_0_clk_out1;
  wire clk_wiz_0_locked;
  wire [0:0]rst_clk_wiz_0_150M_peripheral_aresetn;
  wire [0:0]rst_clk_wiz_0_150M_peripheral_reset;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WREADY;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WVALID;
  wire zynq_ultra_ps_e_0_pl_clk0;
  wire zynq_ultra_ps_e_0_pl_resetn0;

  NPU_bd_NPU_0_3 NPU_0
       (.clk(clk_wiz_0_clk_out1),
        .dma_araddr(NPU_0_dma_ARADDR),
        .dma_arburst(NPU_0_dma_ARBURST),
        .dma_arcache(NPU_0_dma_ARCACHE),
        .dma_arlen(NPU_0_dma_ARLEN),
        .dma_arready(NPU_0_dma_ARREADY),
        .dma_arsize(NPU_0_dma_ARSIZE),
        .dma_arvalid(NPU_0_dma_ARVALID),
        .dma_rdata(NPU_0_dma_RDATA),
        .dma_rlast(NPU_0_dma_RLAST),
        .dma_rready(NPU_0_dma_RREADY),
        .dma_rresp(NPU_0_dma_RRESP),
        .dma_rvalid(NPU_0_dma_RVALID),
        .irq_done(NPU_0_irq_done),
        .rst(rst_clk_wiz_0_150M_peripheral_reset),
        .s_axil_awaddr(axi_smc_M00_AXI_AWADDR),
        .s_axil_awready(axi_smc_M00_AXI_AWREADY),
        .s_axil_awvalid(axi_smc_M00_AXI_AWVALID),
        .s_axil_bready(axi_smc_M00_AXI_BREADY),
        .s_axil_bresp(axi_smc_M00_AXI_BRESP),
        .s_axil_bvalid(axi_smc_M00_AXI_BVALID),
        .s_axil_wdata(axi_smc_M00_AXI_WDATA),
        .s_axil_wready(axi_smc_M00_AXI_WREADY),
        .s_axil_wvalid(axi_smc_M00_AXI_WVALID),
        .seq_araddr(NPU_0_seq_ARADDR),
        .seq_arburst(NPU_0_seq_ARBURST),
        .seq_arlen(NPU_0_seq_ARLEN),
        .seq_arready(NPU_0_seq_ARREADY),
        .seq_arsize(NPU_0_seq_ARSIZE),
        .seq_arvalid(NPU_0_seq_ARVALID),
        .seq_rdata(NPU_0_seq_RDATA),
        .seq_rlast(NPU_0_seq_RLAST),
        .seq_rready(NPU_0_seq_RREADY),
        .seq_rresp(NPU_0_seq_RRESP),
        .seq_rvalid(NPU_0_seq_RVALID),
        .st_awaddr(NPU_0_st_AWADDR),
        .st_awburst(NPU_0_st_AWBURST),
        .st_awcache(NPU_0_st_AWCACHE),
        .st_awlen(NPU_0_st_AWLEN),
        .st_awready(NPU_0_st_AWREADY),
        .st_awsize(NPU_0_st_AWSIZE),
        .st_awvalid(NPU_0_st_AWVALID),
        .st_bready(NPU_0_st_BREADY),
        .st_bresp(NPU_0_st_BRESP),
        .st_bvalid(NPU_0_st_BVALID),
        .st_wdata(NPU_0_st_WDATA),
        .st_wlast(NPU_0_st_WLAST),
        .st_wready(NPU_0_st_WREADY),
        .st_wstrb(NPU_0_st_WSTRB),
        .st_wvalid(NPU_0_st_WVALID),
        .wt_araddr(NPU_0_wt_ARADDR),
        .wt_arburst(NPU_0_wt_ARBURST),
        .wt_arcache(NPU_0_wt_ARCACHE),
        .wt_arlen(NPU_0_wt_ARLEN),
        .wt_arready(NPU_0_wt_ARREADY),
        .wt_arsize(NPU_0_wt_ARSIZE),
        .wt_arvalid(NPU_0_wt_ARVALID),
        .wt_rdata(NPU_0_wt_RDATA),
        .wt_rlast(NPU_0_wt_RLAST),
        .wt_rready(NPU_0_wt_RREADY),
        .wt_rresp(NPU_0_wt_RRESP),
        .wt_rvalid(NPU_0_wt_RVALID));
  NPU_bd_axi_smc_0 axi_smc
       (.M00_AXI_awaddr(axi_smc_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_smc_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_smc_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_smc_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_smc_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_smc_M00_AXI_BVALID),
        .M00_AXI_wdata(axi_smc_M00_AXI_WDATA),
        .M00_AXI_wready(axi_smc_M00_AXI_WREADY),
        .M00_AXI_wvalid(axi_smc_M00_AXI_WVALID),
        .S00_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR),
        .S00_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST),
        .S00_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE),
        .S00_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID),
        .S00_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN),
        .S00_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK),
        .S00_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT),
        .S00_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS),
        .S00_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY),
        .S00_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE),
        .S00_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER),
        .S00_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID),
        .S00_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR),
        .S00_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST),
        .S00_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE),
        .S00_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID),
        .S00_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN),
        .S00_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK),
        .S00_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT),
        .S00_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS),
        .S00_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY),
        .S00_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE),
        .S00_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER),
        .S00_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID),
        .S00_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID),
        .S00_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY),
        .S00_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP),
        .S00_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID),
        .S00_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA),
        .S00_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID),
        .S00_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST),
        .S00_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY),
        .S00_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP),
        .S00_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID),
        .S00_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA),
        .S00_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST),
        .S00_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY),
        .S00_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB),
        .S00_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID),
        .S01_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .S01_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .S01_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .S01_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .S01_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .S01_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .S01_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .S01_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .S01_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .S01_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .S01_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .S01_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .S01_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .S01_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .S01_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .S01_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .S01_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .S01_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .S01_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .S01_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .S01_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .S01_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .S01_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .S01_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .S01_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .S01_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .S01_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .S01_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .S01_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .S01_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .S01_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .S01_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .S01_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .S01_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .S01_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .S01_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .S01_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .S01_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .S01_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .S02_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARADDR),
        .S02_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARBURST),
        .S02_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARCACHE),
        .S02_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARID),
        .S02_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLEN),
        .S02_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLOCK),
        .S02_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARPROT),
        .S02_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARQOS),
        .S02_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARREADY),
        .S02_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARSIZE),
        .S02_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARUSER),
        .S02_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARVALID),
        .S02_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWADDR),
        .S02_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWBURST),
        .S02_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWCACHE),
        .S02_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWID),
        .S02_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLEN),
        .S02_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLOCK),
        .S02_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWPROT),
        .S02_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWQOS),
        .S02_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWREADY),
        .S02_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWSIZE),
        .S02_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWUSER),
        .S02_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWVALID),
        .S02_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BID),
        .S02_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BREADY),
        .S02_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BRESP),
        .S02_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BVALID),
        .S02_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RDATA),
        .S02_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RID),
        .S02_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RLAST),
        .S02_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RREADY),
        .S02_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RRESP),
        .S02_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RVALID),
        .S02_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WDATA),
        .S02_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WLAST),
        .S02_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WREADY),
        .S02_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WSTRB),
        .S02_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WVALID),
        .aclk(clk_wiz_0_clk_out1),
        .aclk1(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_clk_wiz_0_150M_peripheral_aresetn));
  NPU_bd_axi_smc_1_0 axi_smc_1
       (.M00_AXI_araddr(axi_smc_1_M00_AXI_ARADDR),
        .M00_AXI_arburst(axi_smc_1_M00_AXI_ARBURST),
        .M00_AXI_arcache(axi_smc_1_M00_AXI_ARCACHE),
        .M00_AXI_arlen(axi_smc_1_M00_AXI_ARLEN),
        .M00_AXI_arlock(axi_smc_1_M00_AXI_ARLOCK),
        .M00_AXI_arprot(axi_smc_1_M00_AXI_ARPROT),
        .M00_AXI_arqos(axi_smc_1_M00_AXI_ARQOS),
        .M00_AXI_arready(axi_smc_1_M00_AXI_ARREADY),
        .M00_AXI_arsize(axi_smc_1_M00_AXI_ARSIZE),
        .M00_AXI_arvalid(axi_smc_1_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_smc_1_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_smc_1_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_smc_1_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_smc_1_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_smc_1_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_smc_1_M00_AXI_AWPROT),
        .M00_AXI_awqos(axi_smc_1_M00_AXI_AWQOS),
        .M00_AXI_awready(axi_smc_1_M00_AXI_AWREADY),
        .M00_AXI_awsize(axi_smc_1_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(axi_smc_1_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_smc_1_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_smc_1_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_smc_1_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_smc_1_M00_AXI_RDATA),
        .M00_AXI_rlast(axi_smc_1_M00_AXI_RLAST),
        .M00_AXI_rready(axi_smc_1_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_smc_1_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_smc_1_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_smc_1_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_smc_1_M00_AXI_WLAST),
        .M00_AXI_wready(axi_smc_1_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_smc_1_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_smc_1_M00_AXI_WVALID),
        .M01_AXI_araddr(axi_smc_1_M01_AXI_ARADDR),
        .M01_AXI_arburst(axi_smc_1_M01_AXI_ARBURST),
        .M01_AXI_arcache(axi_smc_1_M01_AXI_ARCACHE),
        .M01_AXI_arlen(axi_smc_1_M01_AXI_ARLEN),
        .M01_AXI_arlock(axi_smc_1_M01_AXI_ARLOCK),
        .M01_AXI_arprot(axi_smc_1_M01_AXI_ARPROT),
        .M01_AXI_arqos(axi_smc_1_M01_AXI_ARQOS),
        .M01_AXI_arready(axi_smc_1_M01_AXI_ARREADY),
        .M01_AXI_arsize(axi_smc_1_M01_AXI_ARSIZE),
        .M01_AXI_arvalid(axi_smc_1_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_smc_1_M01_AXI_AWADDR),
        .M01_AXI_awburst(axi_smc_1_M01_AXI_AWBURST),
        .M01_AXI_awcache(axi_smc_1_M01_AXI_AWCACHE),
        .M01_AXI_awlen(axi_smc_1_M01_AXI_AWLEN),
        .M01_AXI_awlock(axi_smc_1_M01_AXI_AWLOCK),
        .M01_AXI_awprot(axi_smc_1_M01_AXI_AWPROT),
        .M01_AXI_awqos(axi_smc_1_M01_AXI_AWQOS),
        .M01_AXI_awready(axi_smc_1_M01_AXI_AWREADY),
        .M01_AXI_awsize(axi_smc_1_M01_AXI_AWSIZE),
        .M01_AXI_awvalid(axi_smc_1_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_smc_1_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_smc_1_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_smc_1_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_smc_1_M01_AXI_RDATA),
        .M01_AXI_rlast(axi_smc_1_M01_AXI_RLAST),
        .M01_AXI_rready(axi_smc_1_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_smc_1_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_smc_1_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_smc_1_M01_AXI_WDATA),
        .M01_AXI_wlast(axi_smc_1_M01_AXI_WLAST),
        .M01_AXI_wready(axi_smc_1_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_smc_1_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_smc_1_M01_AXI_WVALID),
        .M02_AXI_araddr(axi_smc_1_M02_AXI_ARADDR),
        .M02_AXI_arburst(axi_smc_1_M02_AXI_ARBURST),
        .M02_AXI_arcache(axi_smc_1_M02_AXI_ARCACHE),
        .M02_AXI_arlen(axi_smc_1_M02_AXI_ARLEN),
        .M02_AXI_arlock(axi_smc_1_M02_AXI_ARLOCK),
        .M02_AXI_arprot(axi_smc_1_M02_AXI_ARPROT),
        .M02_AXI_arqos(axi_smc_1_M02_AXI_ARQOS),
        .M02_AXI_arready(axi_smc_1_M02_AXI_ARREADY),
        .M02_AXI_arsize(axi_smc_1_M02_AXI_ARSIZE),
        .M02_AXI_arvalid(axi_smc_1_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_smc_1_M02_AXI_AWADDR),
        .M02_AXI_awburst(axi_smc_1_M02_AXI_AWBURST),
        .M02_AXI_awcache(axi_smc_1_M02_AXI_AWCACHE),
        .M02_AXI_awlen(axi_smc_1_M02_AXI_AWLEN),
        .M02_AXI_awlock(axi_smc_1_M02_AXI_AWLOCK),
        .M02_AXI_awprot(axi_smc_1_M02_AXI_AWPROT),
        .M02_AXI_awqos(axi_smc_1_M02_AXI_AWQOS),
        .M02_AXI_awready(axi_smc_1_M02_AXI_AWREADY),
        .M02_AXI_awsize(axi_smc_1_M02_AXI_AWSIZE),
        .M02_AXI_awvalid(axi_smc_1_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_smc_1_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_smc_1_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_smc_1_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_smc_1_M02_AXI_RDATA),
        .M02_AXI_rlast(axi_smc_1_M02_AXI_RLAST),
        .M02_AXI_rready(axi_smc_1_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_smc_1_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_smc_1_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_smc_1_M02_AXI_WDATA),
        .M02_AXI_wlast(axi_smc_1_M02_AXI_WLAST),
        .M02_AXI_wready(axi_smc_1_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_smc_1_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_smc_1_M02_AXI_WVALID),
        .S00_AXI_araddr(NPU_0_dma_ARADDR),
        .S00_AXI_arburst(NPU_0_dma_ARBURST),
        .S00_AXI_arcache(NPU_0_dma_ARCACHE),
        .S00_AXI_arlen(NPU_0_dma_ARLEN),
        .S00_AXI_arlock(1'b0),
        .S00_AXI_arprot({1'b0,1'b0,1'b0}),
        .S00_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_arready(NPU_0_dma_ARREADY),
        .S00_AXI_arsize(NPU_0_dma_ARSIZE),
        .S00_AXI_arvalid(NPU_0_dma_ARVALID),
        .S00_AXI_rdata(NPU_0_dma_RDATA),
        .S00_AXI_rlast(NPU_0_dma_RLAST),
        .S00_AXI_rready(NPU_0_dma_RREADY),
        .S00_AXI_rresp(NPU_0_dma_RRESP),
        .S00_AXI_rvalid(NPU_0_dma_RVALID),
        .S01_AXI_araddr(NPU_0_seq_ARADDR),
        .S01_AXI_arburst(NPU_0_seq_ARBURST),
        .S01_AXI_arcache({1'b0,1'b0,1'b1,1'b1}),
        .S01_AXI_arlen(NPU_0_seq_ARLEN),
        .S01_AXI_arlock(1'b0),
        .S01_AXI_arprot({1'b0,1'b0,1'b0}),
        .S01_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_arready(NPU_0_seq_ARREADY),
        .S01_AXI_arsize(NPU_0_seq_ARSIZE),
        .S01_AXI_arvalid(NPU_0_seq_ARVALID),
        .S01_AXI_rdata(NPU_0_seq_RDATA),
        .S01_AXI_rlast(NPU_0_seq_RLAST),
        .S01_AXI_rready(NPU_0_seq_RREADY),
        .S01_AXI_rresp(NPU_0_seq_RRESP),
        .S01_AXI_rvalid(NPU_0_seq_RVALID),
        .S02_AXI_awaddr(NPU_0_st_AWADDR),
        .S02_AXI_awburst(NPU_0_st_AWBURST),
        .S02_AXI_awcache(NPU_0_st_AWCACHE),
        .S02_AXI_awlen(NPU_0_st_AWLEN),
        .S02_AXI_awlock(1'b0),
        .S02_AXI_awprot({1'b0,1'b0,1'b0}),
        .S02_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S02_AXI_awready(NPU_0_st_AWREADY),
        .S02_AXI_awsize(NPU_0_st_AWSIZE),
        .S02_AXI_awvalid(NPU_0_st_AWVALID),
        .S02_AXI_bready(NPU_0_st_BREADY),
        .S02_AXI_bresp(NPU_0_st_BRESP),
        .S02_AXI_bvalid(NPU_0_st_BVALID),
        .S02_AXI_wdata(NPU_0_st_WDATA),
        .S02_AXI_wlast(NPU_0_st_WLAST),
        .S02_AXI_wready(NPU_0_st_WREADY),
        .S02_AXI_wstrb(NPU_0_st_WSTRB),
        .S02_AXI_wvalid(NPU_0_st_WVALID),
        .S03_AXI_araddr(NPU_0_wt_ARADDR),
        .S03_AXI_arburst(NPU_0_wt_ARBURST),
        .S03_AXI_arcache(NPU_0_wt_ARCACHE),
        .S03_AXI_arlen(NPU_0_wt_ARLEN),
        .S03_AXI_arlock(1'b0),
        .S03_AXI_arprot({1'b0,1'b0,1'b0}),
        .S03_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S03_AXI_arready(NPU_0_wt_ARREADY),
        .S03_AXI_arsize(NPU_0_wt_ARSIZE),
        .S03_AXI_arvalid(NPU_0_wt_ARVALID),
        .S03_AXI_rdata(NPU_0_wt_RDATA),
        .S03_AXI_rlast(NPU_0_wt_RLAST),
        .S03_AXI_rready(NPU_0_wt_RREADY),
        .S03_AXI_rresp(NPU_0_wt_RRESP),
        .S03_AXI_rvalid(NPU_0_wt_RVALID),
        .aclk(clk_wiz_0_clk_out1),
        .aresetn(rst_clk_wiz_0_150M_peripheral_aresetn));
  NPU_bd_clk_wiz_0_0 clk_wiz_0
       (.clk_in1(zynq_ultra_ps_e_0_pl_clk0),
        .clk_out1(clk_wiz_0_clk_out1),
        .locked(clk_wiz_0_locked),
        .resetn(zynq_ultra_ps_e_0_pl_resetn0));
  NPU_bd_rst_clk_wiz_0_150M_0 rst_clk_wiz_0_150M
       (.aux_reset_in(1'b1),
        .dcm_locked(clk_wiz_0_locked),
        .ext_reset_in(zynq_ultra_ps_e_0_pl_resetn0),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_clk_wiz_0_150M_peripheral_aresetn),
        .peripheral_reset(rst_clk_wiz_0_150M_peripheral_reset),
        .slowest_sync_clk(clk_wiz_0_clk_out1));
  NPU_bd_zynq_ultra_ps_e_0_0 zynq_ultra_ps_e_0
       (.maxigp0_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .maxigp0_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .maxigp0_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .maxigp0_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .maxigp0_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .maxigp0_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .maxigp0_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .maxigp0_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .maxigp0_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .maxigp0_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .maxigp0_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .maxigp0_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .maxigp0_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .maxigp0_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .maxigp0_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .maxigp0_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .maxigp0_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .maxigp0_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .maxigp0_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .maxigp0_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .maxigp0_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .maxigp0_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .maxigp0_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .maxigp0_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .maxigp0_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .maxigp0_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .maxigp0_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .maxigp0_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .maxigp0_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .maxigp0_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .maxigp0_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .maxigp0_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .maxigp0_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .maxigp0_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .maxigp0_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .maxigp0_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .maxigp0_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .maxigp0_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .maxigp0_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .maxigp1_araddr(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARADDR),
        .maxigp1_arburst(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARBURST),
        .maxigp1_arcache(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARCACHE),
        .maxigp1_arid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARID),
        .maxigp1_arlen(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLEN),
        .maxigp1_arlock(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARLOCK),
        .maxigp1_arprot(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARPROT),
        .maxigp1_arqos(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARQOS),
        .maxigp1_arready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARREADY),
        .maxigp1_arsize(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARSIZE),
        .maxigp1_aruser(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARUSER),
        .maxigp1_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_ARVALID),
        .maxigp1_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWADDR),
        .maxigp1_awburst(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWBURST),
        .maxigp1_awcache(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWCACHE),
        .maxigp1_awid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWID),
        .maxigp1_awlen(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLEN),
        .maxigp1_awlock(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWLOCK),
        .maxigp1_awprot(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWPROT),
        .maxigp1_awqos(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWQOS),
        .maxigp1_awready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWREADY),
        .maxigp1_awsize(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWSIZE),
        .maxigp1_awuser(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWUSER),
        .maxigp1_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_AWVALID),
        .maxigp1_bid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BID),
        .maxigp1_bready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BREADY),
        .maxigp1_bresp(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BRESP),
        .maxigp1_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_BVALID),
        .maxigp1_rdata(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RDATA),
        .maxigp1_rid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RID),
        .maxigp1_rlast(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RLAST),
        .maxigp1_rready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RREADY),
        .maxigp1_rresp(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RRESP),
        .maxigp1_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_RVALID),
        .maxigp1_wdata(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WDATA),
        .maxigp1_wlast(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WLAST),
        .maxigp1_wready(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WREADY),
        .maxigp1_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WSTRB),
        .maxigp1_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM1_FPD_WVALID),
        .maxigp2_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARADDR),
        .maxigp2_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARBURST),
        .maxigp2_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARCACHE),
        .maxigp2_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARID),
        .maxigp2_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLEN),
        .maxigp2_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARLOCK),
        .maxigp2_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARPROT),
        .maxigp2_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARQOS),
        .maxigp2_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARREADY),
        .maxigp2_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARSIZE),
        .maxigp2_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARUSER),
        .maxigp2_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_ARVALID),
        .maxigp2_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWADDR),
        .maxigp2_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWBURST),
        .maxigp2_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWCACHE),
        .maxigp2_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWID),
        .maxigp2_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLEN),
        .maxigp2_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWLOCK),
        .maxigp2_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWPROT),
        .maxigp2_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWQOS),
        .maxigp2_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWREADY),
        .maxigp2_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWSIZE),
        .maxigp2_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWUSER),
        .maxigp2_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_AWVALID),
        .maxigp2_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BID),
        .maxigp2_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BREADY),
        .maxigp2_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BRESP),
        .maxigp2_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_BVALID),
        .maxigp2_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RDATA),
        .maxigp2_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RID),
        .maxigp2_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RLAST),
        .maxigp2_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RREADY),
        .maxigp2_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RRESP),
        .maxigp2_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_RVALID),
        .maxigp2_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WDATA),
        .maxigp2_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WLAST),
        .maxigp2_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WREADY),
        .maxigp2_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WSTRB),
        .maxigp2_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_LPD_WVALID),
        .maxihpm0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .maxihpm0_lpd_aclk(clk_wiz_0_clk_out1),
        .maxihpm1_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .pl_clk0(zynq_ultra_ps_e_0_pl_clk0),
        .pl_ps_irq0(NPU_0_irq_done),
        .pl_resetn0(zynq_ultra_ps_e_0_pl_resetn0),
        .saxigp2_araddr(axi_smc_1_M00_AXI_ARADDR),
        .saxigp2_arburst(axi_smc_1_M00_AXI_ARBURST),
        .saxigp2_arcache(axi_smc_1_M00_AXI_ARCACHE),
        .saxigp2_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arlen(axi_smc_1_M00_AXI_ARLEN),
        .saxigp2_arlock(axi_smc_1_M00_AXI_ARLOCK),
        .saxigp2_arprot(axi_smc_1_M00_AXI_ARPROT),
        .saxigp2_arqos(axi_smc_1_M00_AXI_ARQOS),
        .saxigp2_arready(axi_smc_1_M00_AXI_ARREADY),
        .saxigp2_arsize(axi_smc_1_M00_AXI_ARSIZE),
        .saxigp2_aruser(1'b0),
        .saxigp2_arvalid(axi_smc_1_M00_AXI_ARVALID),
        .saxigp2_awaddr(axi_smc_1_M00_AXI_AWADDR),
        .saxigp2_awburst(axi_smc_1_M00_AXI_AWBURST),
        .saxigp2_awcache(axi_smc_1_M00_AXI_AWCACHE),
        .saxigp2_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_awlen(axi_smc_1_M00_AXI_AWLEN),
        .saxigp2_awlock(axi_smc_1_M00_AXI_AWLOCK),
        .saxigp2_awprot(axi_smc_1_M00_AXI_AWPROT),
        .saxigp2_awqos(axi_smc_1_M00_AXI_AWQOS),
        .saxigp2_awready(axi_smc_1_M00_AXI_AWREADY),
        .saxigp2_awsize(axi_smc_1_M00_AXI_AWSIZE),
        .saxigp2_awuser(1'b0),
        .saxigp2_awvalid(axi_smc_1_M00_AXI_AWVALID),
        .saxigp2_bready(axi_smc_1_M00_AXI_BREADY),
        .saxigp2_bresp(axi_smc_1_M00_AXI_BRESP),
        .saxigp2_bvalid(axi_smc_1_M00_AXI_BVALID),
        .saxigp2_rdata(axi_smc_1_M00_AXI_RDATA),
        .saxigp2_rlast(axi_smc_1_M00_AXI_RLAST),
        .saxigp2_rready(axi_smc_1_M00_AXI_RREADY),
        .saxigp2_rresp(axi_smc_1_M00_AXI_RRESP),
        .saxigp2_rvalid(axi_smc_1_M00_AXI_RVALID),
        .saxigp2_wdata(axi_smc_1_M00_AXI_WDATA),
        .saxigp2_wlast(axi_smc_1_M00_AXI_WLAST),
        .saxigp2_wready(axi_smc_1_M00_AXI_WREADY),
        .saxigp2_wstrb(axi_smc_1_M00_AXI_WSTRB),
        .saxigp2_wvalid(axi_smc_1_M00_AXI_WVALID),
        .saxigp3_araddr(axi_smc_1_M01_AXI_ARADDR),
        .saxigp3_arburst(axi_smc_1_M01_AXI_ARBURST),
        .saxigp3_arcache(axi_smc_1_M01_AXI_ARCACHE),
        .saxigp3_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp3_arlen(axi_smc_1_M01_AXI_ARLEN),
        .saxigp3_arlock(axi_smc_1_M01_AXI_ARLOCK),
        .saxigp3_arprot(axi_smc_1_M01_AXI_ARPROT),
        .saxigp3_arqos(axi_smc_1_M01_AXI_ARQOS),
        .saxigp3_arready(axi_smc_1_M01_AXI_ARREADY),
        .saxigp3_arsize(axi_smc_1_M01_AXI_ARSIZE),
        .saxigp3_aruser(1'b0),
        .saxigp3_arvalid(axi_smc_1_M01_AXI_ARVALID),
        .saxigp3_awaddr(axi_smc_1_M01_AXI_AWADDR),
        .saxigp3_awburst(axi_smc_1_M01_AXI_AWBURST),
        .saxigp3_awcache(axi_smc_1_M01_AXI_AWCACHE),
        .saxigp3_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp3_awlen(axi_smc_1_M01_AXI_AWLEN),
        .saxigp3_awlock(axi_smc_1_M01_AXI_AWLOCK),
        .saxigp3_awprot(axi_smc_1_M01_AXI_AWPROT),
        .saxigp3_awqos(axi_smc_1_M01_AXI_AWQOS),
        .saxigp3_awready(axi_smc_1_M01_AXI_AWREADY),
        .saxigp3_awsize(axi_smc_1_M01_AXI_AWSIZE),
        .saxigp3_awuser(1'b0),
        .saxigp3_awvalid(axi_smc_1_M01_AXI_AWVALID),
        .saxigp3_bready(axi_smc_1_M01_AXI_BREADY),
        .saxigp3_bresp(axi_smc_1_M01_AXI_BRESP),
        .saxigp3_bvalid(axi_smc_1_M01_AXI_BVALID),
        .saxigp3_rdata(axi_smc_1_M01_AXI_RDATA),
        .saxigp3_rlast(axi_smc_1_M01_AXI_RLAST),
        .saxigp3_rready(axi_smc_1_M01_AXI_RREADY),
        .saxigp3_rresp(axi_smc_1_M01_AXI_RRESP),
        .saxigp3_rvalid(axi_smc_1_M01_AXI_RVALID),
        .saxigp3_wdata(axi_smc_1_M01_AXI_WDATA),
        .saxigp3_wlast(axi_smc_1_M01_AXI_WLAST),
        .saxigp3_wready(axi_smc_1_M01_AXI_WREADY),
        .saxigp3_wstrb(axi_smc_1_M01_AXI_WSTRB),
        .saxigp3_wvalid(axi_smc_1_M01_AXI_WVALID),
        .saxigp4_araddr(axi_smc_1_M02_AXI_ARADDR),
        .saxigp4_arburst(axi_smc_1_M02_AXI_ARBURST),
        .saxigp4_arcache(axi_smc_1_M02_AXI_ARCACHE),
        .saxigp4_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_arlen(axi_smc_1_M02_AXI_ARLEN),
        .saxigp4_arlock(axi_smc_1_M02_AXI_ARLOCK),
        .saxigp4_arprot(axi_smc_1_M02_AXI_ARPROT),
        .saxigp4_arqos(axi_smc_1_M02_AXI_ARQOS),
        .saxigp4_arready(axi_smc_1_M02_AXI_ARREADY),
        .saxigp4_arsize(axi_smc_1_M02_AXI_ARSIZE),
        .saxigp4_aruser(1'b0),
        .saxigp4_arvalid(axi_smc_1_M02_AXI_ARVALID),
        .saxigp4_awaddr(axi_smc_1_M02_AXI_AWADDR),
        .saxigp4_awburst(axi_smc_1_M02_AXI_AWBURST),
        .saxigp4_awcache(axi_smc_1_M02_AXI_AWCACHE),
        .saxigp4_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_awlen(axi_smc_1_M02_AXI_AWLEN),
        .saxigp4_awlock(axi_smc_1_M02_AXI_AWLOCK),
        .saxigp4_awprot(axi_smc_1_M02_AXI_AWPROT),
        .saxigp4_awqos(axi_smc_1_M02_AXI_AWQOS),
        .saxigp4_awready(axi_smc_1_M02_AXI_AWREADY),
        .saxigp4_awsize(axi_smc_1_M02_AXI_AWSIZE),
        .saxigp4_awuser(1'b0),
        .saxigp4_awvalid(axi_smc_1_M02_AXI_AWVALID),
        .saxigp4_bready(axi_smc_1_M02_AXI_BREADY),
        .saxigp4_bresp(axi_smc_1_M02_AXI_BRESP),
        .saxigp4_bvalid(axi_smc_1_M02_AXI_BVALID),
        .saxigp4_rdata(axi_smc_1_M02_AXI_RDATA),
        .saxigp4_rlast(axi_smc_1_M02_AXI_RLAST),
        .saxigp4_rready(axi_smc_1_M02_AXI_RREADY),
        .saxigp4_rresp(axi_smc_1_M02_AXI_RRESP),
        .saxigp4_rvalid(axi_smc_1_M02_AXI_RVALID),
        .saxigp4_wdata(axi_smc_1_M02_AXI_WDATA),
        .saxigp4_wlast(axi_smc_1_M02_AXI_WLAST),
        .saxigp4_wready(axi_smc_1_M02_AXI_WREADY),
        .saxigp4_wstrb(axi_smc_1_M02_AXI_WSTRB),
        .saxigp4_wvalid(axi_smc_1_M02_AXI_WVALID),
        .saxihp0_fpd_aclk(clk_wiz_0_clk_out1),
        .saxihp1_fpd_aclk(clk_wiz_0_clk_out1),
        .saxihp2_fpd_aclk(clk_wiz_0_clk_out1));
endmodule
