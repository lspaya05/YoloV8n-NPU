// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Mon Jun  8 23:14:25 2026
// Host        : PaPayaPC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/Leona/GitHubRepo/EE470-FinalProject/NPU_bd/ip/NPU_bd_zynq_ultra_ps_e_0_0/NPU_bd_zynq_ultra_ps_e_0_0_stub.v
// Design      : NPU_bd_zynq_ultra_ps_e_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xck26-sfvc784-2LV-c
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "NPU_bd_zynq_ultra_ps_e_0_0,zynq_ultra_ps_e_v3_5_8_zynq_ultra_ps_e,{}" *) (* CORE_GENERATION_INFO = "NPU_bd_zynq_ultra_ps_e_0_0,zynq_ultra_ps_e_v3_5_8_zynq_ultra_ps_e,{x_ipProduct=Vivado 2025.2,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=zynq_ultra_ps_e,x_ipVersion=3.5,x_ipCoreRevision=8,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_DP_USE_AUDIO=0,C_DP_USE_VIDEO=0,C_MAXIGP0_DATA_WIDTH=128,C_MAXIGP1_DATA_WIDTH=128,C_MAXIGP2_DATA_WIDTH=32,C_SAXIGP0_DATA_WIDTH=128,C_SAXIGP1_DATA_WIDTH=128,C_SAXIGP2_DATA_WIDTH=128,C_SAXIGP3_DATA_WIDTH=128,C_SAXIGP4_DATA_WIDTH=128,C_SAXIGP5_DATA_WIDTH=128,C_SAXIGP6_DATA_WIDTH=128,C_USE_DIFF_RW_CLK_GP0=0,C_USE_DIFF_RW_CLK_GP1=0,C_USE_DIFF_RW_CLK_GP2=0,C_USE_DIFF_RW_CLK_GP3=0,C_USE_DIFF_RW_CLK_GP4=0,C_USE_DIFF_RW_CLK_GP5=0,C_USE_DIFF_RW_CLK_GP6=0,C_EN_FIFO_ENET0=0,C_EN_FIFO_ENET1=0,C_EN_FIFO_ENET2=0,C_EN_FIFO_ENET3=0,C_PL_CLK0_BUF=TRUE,C_PL_CLK1_BUF=TRUE,C_PL_CLK2_BUF=FALSE,C_PL_CLK3_BUF=FALSE,C_TRACE_PIPELINE_WIDTH=8,C_EN_EMIO_TRACE=0,C_TRACE_DATA_WIDTH=32,C_USE_DEBUG_TEST=0,C_SD0_INTERNAL_BUS_WIDTH=5,C_SD1_INTERNAL_BUS_WIDTH=5,C_NUM_F2P_0_INTR_INPUTS=1,C_NUM_F2P_1_INTR_INPUTS=1,C_EMIO_GPIO_WIDTH=1,C_NUM_FABRIC_RESETS=1}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) 
(* X_CORE_INFO = "zynq_ultra_ps_e_v3_5_8_zynq_ultra_ps_e,Vivado 2025.2" *) 
module NPU_bd_zynq_ultra_ps_e_0_0(maxihpm0_fpd_aclk, maxigp0_awid, 
  maxigp0_awaddr, maxigp0_awlen, maxigp0_awsize, maxigp0_awburst, maxigp0_awlock, 
  maxigp0_awcache, maxigp0_awprot, maxigp0_awvalid, maxigp0_awuser, maxigp0_awready, 
  maxigp0_wdata, maxigp0_wstrb, maxigp0_wlast, maxigp0_wvalid, maxigp0_wready, maxigp0_bid, 
  maxigp0_bresp, maxigp0_bvalid, maxigp0_bready, maxigp0_arid, maxigp0_araddr, maxigp0_arlen, 
  maxigp0_arsize, maxigp0_arburst, maxigp0_arlock, maxigp0_arcache, maxigp0_arprot, 
  maxigp0_arvalid, maxigp0_aruser, maxigp0_arready, maxigp0_rid, maxigp0_rdata, 
  maxigp0_rresp, maxigp0_rlast, maxigp0_rvalid, maxigp0_rready, maxigp0_awqos, maxigp0_arqos, 
  maxihpm1_fpd_aclk, maxigp1_awid, maxigp1_awaddr, maxigp1_awlen, maxigp1_awsize, 
  maxigp1_awburst, maxigp1_awlock, maxigp1_awcache, maxigp1_awprot, maxigp1_awvalid, 
  maxigp1_awuser, maxigp1_awready, maxigp1_wdata, maxigp1_wstrb, maxigp1_wlast, 
  maxigp1_wvalid, maxigp1_wready, maxigp1_bid, maxigp1_bresp, maxigp1_bvalid, maxigp1_bready, 
  maxigp1_arid, maxigp1_araddr, maxigp1_arlen, maxigp1_arsize, maxigp1_arburst, 
  maxigp1_arlock, maxigp1_arcache, maxigp1_arprot, maxigp1_arvalid, maxigp1_aruser, 
  maxigp1_arready, maxigp1_rid, maxigp1_rdata, maxigp1_rresp, maxigp1_rlast, maxigp1_rvalid, 
  maxigp1_rready, maxigp1_awqos, maxigp1_arqos, maxihpm0_lpd_aclk, maxigp2_awid, 
  maxigp2_awaddr, maxigp2_awlen, maxigp2_awsize, maxigp2_awburst, maxigp2_awlock, 
  maxigp2_awcache, maxigp2_awprot, maxigp2_awvalid, maxigp2_awuser, maxigp2_awready, 
  maxigp2_wdata, maxigp2_wstrb, maxigp2_wlast, maxigp2_wvalid, maxigp2_wready, maxigp2_bid, 
  maxigp2_bresp, maxigp2_bvalid, maxigp2_bready, maxigp2_arid, maxigp2_araddr, maxigp2_arlen, 
  maxigp2_arsize, maxigp2_arburst, maxigp2_arlock, maxigp2_arcache, maxigp2_arprot, 
  maxigp2_arvalid, maxigp2_aruser, maxigp2_arready, maxigp2_rid, maxigp2_rdata, 
  maxigp2_rresp, maxigp2_rlast, maxigp2_rvalid, maxigp2_rready, maxigp2_awqos, maxigp2_arqos, 
  saxihp0_fpd_aclk, saxigp2_aruser, saxigp2_awuser, saxigp2_awid, saxigp2_awaddr, 
  saxigp2_awlen, saxigp2_awsize, saxigp2_awburst, saxigp2_awlock, saxigp2_awcache, 
  saxigp2_awprot, saxigp2_awvalid, saxigp2_awready, saxigp2_wdata, saxigp2_wstrb, 
  saxigp2_wlast, saxigp2_wvalid, saxigp2_wready, saxigp2_bid, saxigp2_bresp, saxigp2_bvalid, 
  saxigp2_bready, saxigp2_arid, saxigp2_araddr, saxigp2_arlen, saxigp2_arsize, 
  saxigp2_arburst, saxigp2_arlock, saxigp2_arcache, saxigp2_arprot, saxigp2_arvalid, 
  saxigp2_arready, saxigp2_rid, saxigp2_rdata, saxigp2_rresp, saxigp2_rlast, saxigp2_rvalid, 
  saxigp2_rready, saxigp2_awqos, saxigp2_arqos, saxihp1_fpd_aclk, saxigp3_aruser, 
  saxigp3_awuser, saxigp3_awid, saxigp3_awaddr, saxigp3_awlen, saxigp3_awsize, 
  saxigp3_awburst, saxigp3_awlock, saxigp3_awcache, saxigp3_awprot, saxigp3_awvalid, 
  saxigp3_awready, saxigp3_wdata, saxigp3_wstrb, saxigp3_wlast, saxigp3_wvalid, 
  saxigp3_wready, saxigp3_bid, saxigp3_bresp, saxigp3_bvalid, saxigp3_bready, saxigp3_arid, 
  saxigp3_araddr, saxigp3_arlen, saxigp3_arsize, saxigp3_arburst, saxigp3_arlock, 
  saxigp3_arcache, saxigp3_arprot, saxigp3_arvalid, saxigp3_arready, saxigp3_rid, 
  saxigp3_rdata, saxigp3_rresp, saxigp3_rlast, saxigp3_rvalid, saxigp3_rready, saxigp3_awqos, 
  saxigp3_arqos, saxihp2_fpd_aclk, saxigp4_aruser, saxigp4_awuser, saxigp4_awid, 
  saxigp4_awaddr, saxigp4_awlen, saxigp4_awsize, saxigp4_awburst, saxigp4_awlock, 
  saxigp4_awcache, saxigp4_awprot, saxigp4_awvalid, saxigp4_awready, saxigp4_wdata, 
  saxigp4_wstrb, saxigp4_wlast, saxigp4_wvalid, saxigp4_wready, saxigp4_bid, saxigp4_bresp, 
  saxigp4_bvalid, saxigp4_bready, saxigp4_arid, saxigp4_araddr, saxigp4_arlen, 
  saxigp4_arsize, saxigp4_arburst, saxigp4_arlock, saxigp4_arcache, saxigp4_arprot, 
  saxigp4_arvalid, saxigp4_arready, saxigp4_rid, saxigp4_rdata, saxigp4_rresp, saxigp4_rlast, 
  saxigp4_rvalid, saxigp4_rready, saxigp4_awqos, saxigp4_arqos, pl_ps_irq0, pl_resetn0, 
  pl_clk0, pl_clk1)
/* synthesis syn_black_box black_box_pad_pin="maxigp0_awid[15:0],maxigp0_awaddr[39:0],maxigp0_awlen[7:0],maxigp0_awsize[2:0],maxigp0_awburst[1:0],maxigp0_awlock,maxigp0_awcache[3:0],maxigp0_awprot[2:0],maxigp0_awvalid,maxigp0_awuser[15:0],maxigp0_awready,maxigp0_wdata[127:0],maxigp0_wstrb[15:0],maxigp0_wlast,maxigp0_wvalid,maxigp0_wready,maxigp0_bid[15:0],maxigp0_bresp[1:0],maxigp0_bvalid,maxigp0_bready,maxigp0_arid[15:0],maxigp0_araddr[39:0],maxigp0_arlen[7:0],maxigp0_arsize[2:0],maxigp0_arburst[1:0],maxigp0_arlock,maxigp0_arcache[3:0],maxigp0_arprot[2:0],maxigp0_arvalid,maxigp0_aruser[15:0],maxigp0_arready,maxigp0_rid[15:0],maxigp0_rdata[127:0],maxigp0_rresp[1:0],maxigp0_rlast,maxigp0_rvalid,maxigp0_rready,maxigp0_awqos[3:0],maxigp0_arqos[3:0],maxigp1_awid[15:0],maxigp1_awaddr[39:0],maxigp1_awlen[7:0],maxigp1_awsize[2:0],maxigp1_awburst[1:0],maxigp1_awlock,maxigp1_awcache[3:0],maxigp1_awprot[2:0],maxigp1_awvalid,maxigp1_awuser[15:0],maxigp1_awready,maxigp1_wdata[127:0],maxigp1_wstrb[15:0],maxigp1_wlast,maxigp1_wvalid,maxigp1_wready,maxigp1_bid[15:0],maxigp1_bresp[1:0],maxigp1_bvalid,maxigp1_bready,maxigp1_arid[15:0],maxigp1_araddr[39:0],maxigp1_arlen[7:0],maxigp1_arsize[2:0],maxigp1_arburst[1:0],maxigp1_arlock,maxigp1_arcache[3:0],maxigp1_arprot[2:0],maxigp1_arvalid,maxigp1_aruser[15:0],maxigp1_arready,maxigp1_rid[15:0],maxigp1_rdata[127:0],maxigp1_rresp[1:0],maxigp1_rlast,maxigp1_rvalid,maxigp1_rready,maxigp1_awqos[3:0],maxigp1_arqos[3:0],maxigp2_awid[15:0],maxigp2_awaddr[39:0],maxigp2_awlen[7:0],maxigp2_awsize[2:0],maxigp2_awburst[1:0],maxigp2_awlock,maxigp2_awcache[3:0],maxigp2_awprot[2:0],maxigp2_awvalid,maxigp2_awuser[15:0],maxigp2_awready,maxigp2_wdata[31:0],maxigp2_wstrb[3:0],maxigp2_wlast,maxigp2_wvalid,maxigp2_wready,maxigp2_bid[15:0],maxigp2_bresp[1:0],maxigp2_bvalid,maxigp2_bready,maxigp2_arid[15:0],maxigp2_araddr[39:0],maxigp2_arlen[7:0],maxigp2_arsize[2:0],maxigp2_arburst[1:0],maxigp2_arlock,maxigp2_arcache[3:0],maxigp2_arprot[2:0],maxigp2_arvalid,maxigp2_aruser[15:0],maxigp2_arready,maxigp2_rid[15:0],maxigp2_rdata[31:0],maxigp2_rresp[1:0],maxigp2_rlast,maxigp2_rvalid,maxigp2_rready,maxigp2_awqos[3:0],maxigp2_arqos[3:0],saxigp2_aruser,saxigp2_awuser,saxigp2_awid[5:0],saxigp2_awaddr[48:0],saxigp2_awlen[7:0],saxigp2_awsize[2:0],saxigp2_awburst[1:0],saxigp2_awlock,saxigp2_awcache[3:0],saxigp2_awprot[2:0],saxigp2_awvalid,saxigp2_awready,saxigp2_wdata[127:0],saxigp2_wstrb[15:0],saxigp2_wlast,saxigp2_wvalid,saxigp2_wready,saxigp2_bid[5:0],saxigp2_bresp[1:0],saxigp2_bvalid,saxigp2_bready,saxigp2_arid[5:0],saxigp2_araddr[48:0],saxigp2_arlen[7:0],saxigp2_arsize[2:0],saxigp2_arburst[1:0],saxigp2_arlock,saxigp2_arcache[3:0],saxigp2_arprot[2:0],saxigp2_arvalid,saxigp2_arready,saxigp2_rid[5:0],saxigp2_rdata[127:0],saxigp2_rresp[1:0],saxigp2_rlast,saxigp2_rvalid,saxigp2_rready,saxigp2_awqos[3:0],saxigp2_arqos[3:0],saxigp3_aruser,saxigp3_awuser,saxigp3_awid[5:0],saxigp3_awaddr[48:0],saxigp3_awlen[7:0],saxigp3_awsize[2:0],saxigp3_awburst[1:0],saxigp3_awlock,saxigp3_awcache[3:0],saxigp3_awprot[2:0],saxigp3_awvalid,saxigp3_awready,saxigp3_wdata[127:0],saxigp3_wstrb[15:0],saxigp3_wlast,saxigp3_wvalid,saxigp3_wready,saxigp3_bid[5:0],saxigp3_bresp[1:0],saxigp3_bvalid,saxigp3_bready,saxigp3_arid[5:0],saxigp3_araddr[48:0],saxigp3_arlen[7:0],saxigp3_arsize[2:0],saxigp3_arburst[1:0],saxigp3_arlock,saxigp3_arcache[3:0],saxigp3_arprot[2:0],saxigp3_arvalid,saxigp3_arready,saxigp3_rid[5:0],saxigp3_rdata[127:0],saxigp3_rresp[1:0],saxigp3_rlast,saxigp3_rvalid,saxigp3_rready,saxigp3_awqos[3:0],saxigp3_arqos[3:0],saxigp4_aruser,saxigp4_awuser,saxigp4_awid[5:0],saxigp4_awaddr[48:0],saxigp4_awlen[7:0],saxigp4_awsize[2:0],saxigp4_awburst[1:0],saxigp4_awlock,saxigp4_awcache[3:0],saxigp4_awprot[2:0],saxigp4_awvalid,saxigp4_awready,saxigp4_wdata[127:0],saxigp4_wstrb[15:0],saxigp4_wlast,saxigp4_wvalid,saxigp4_wready,saxigp4_bid[5:0],saxigp4_bresp[1:0],saxigp4_bvalid,saxigp4_bready,saxigp4_arid[5:0],saxigp4_araddr[48:0],saxigp4_arlen[7:0],saxigp4_arsize[2:0],saxigp4_arburst[1:0],saxigp4_arlock,saxigp4_arcache[3:0],saxigp4_arprot[2:0],saxigp4_arvalid,saxigp4_arready,saxigp4_rid[5:0],saxigp4_rdata[127:0],saxigp4_rresp[1:0],saxigp4_rlast,saxigp4_rvalid,saxigp4_rready,saxigp4_awqos[3:0],saxigp4_arqos[3:0],pl_ps_irq0[0:0],pl_resetn0" */
/* synthesis syn_force_seq_prim="maxihpm0_fpd_aclk" */
/* synthesis syn_force_seq_prim="maxihpm1_fpd_aclk" */
/* synthesis syn_force_seq_prim="maxihpm0_lpd_aclk" */
/* synthesis syn_force_seq_prim="saxihp0_fpd_aclk" */
/* synthesis syn_force_seq_prim="saxihp1_fpd_aclk" */
/* synthesis syn_force_seq_prim="saxihp2_fpd_aclk" */
/* synthesis syn_force_seq_prim="pl_clk0" */
/* synthesis syn_force_seq_prim="pl_clk1" */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 M_AXI_HPM0_FPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM0_FPD_ACLK, ASSOCIATED_BUSIF M_AXI_HPM0_FPD, FREQ_HZ 99999001, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk0, INSERT_VIP 0" *) input maxihpm0_fpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWID" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM0_FPD, NUM_WRITE_OUTSTANDING 8, NUM_READ_OUTSTANDING 8, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 99999001, ID_WIDTH 16, ADDR_WIDTH 40, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk0, NUM_READ_THREADS 4, NUM_WRITE_THREADS 4, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [15:0]maxigp0_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWADDR" *) output [39:0]maxigp0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWLEN" *) output [7:0]maxigp0_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWSIZE" *) output [2:0]maxigp0_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWBURST" *) output [1:0]maxigp0_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWLOCK" *) output maxigp0_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWCACHE" *) output [3:0]maxigp0_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWPROT" *) output [2:0]maxigp0_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWVALID" *) output maxigp0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWUSER" *) output [15:0]maxigp0_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWREADY" *) input maxigp0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD WDATA" *) output [127:0]maxigp0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD WSTRB" *) output [15:0]maxigp0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD WLAST" *) output maxigp0_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD WVALID" *) output maxigp0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD WREADY" *) input maxigp0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD BID" *) input [15:0]maxigp0_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD BRESP" *) input [1:0]maxigp0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD BVALID" *) input maxigp0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD BREADY" *) output maxigp0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARID" *) output [15:0]maxigp0_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARADDR" *) output [39:0]maxigp0_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARLEN" *) output [7:0]maxigp0_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARSIZE" *) output [2:0]maxigp0_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARBURST" *) output [1:0]maxigp0_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARLOCK" *) output maxigp0_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARCACHE" *) output [3:0]maxigp0_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARPROT" *) output [2:0]maxigp0_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARVALID" *) output maxigp0_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARUSER" *) output [15:0]maxigp0_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARREADY" *) input maxigp0_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RID" *) input [15:0]maxigp0_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RDATA" *) input [127:0]maxigp0_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RRESP" *) input [1:0]maxigp0_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RLAST" *) input maxigp0_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RVALID" *) input maxigp0_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD RREADY" *) output maxigp0_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD AWQOS" *) output [3:0]maxigp0_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_FPD ARQOS" *) output [3:0]maxigp0_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 M_AXI_HPM1_FPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM1_FPD_ACLK, ASSOCIATED_BUSIF M_AXI_HPM1_FPD, FREQ_HZ 99999001, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk0, INSERT_VIP 0" *) input maxihpm1_fpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWID" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM1_FPD, NUM_WRITE_OUTSTANDING 8, NUM_READ_OUTSTANDING 8, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 99999001, ID_WIDTH 16, ADDR_WIDTH 40, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk0, NUM_READ_THREADS 4, NUM_WRITE_THREADS 4, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [15:0]maxigp1_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWADDR" *) output [39:0]maxigp1_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWLEN" *) output [7:0]maxigp1_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWSIZE" *) output [2:0]maxigp1_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWBURST" *) output [1:0]maxigp1_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWLOCK" *) output maxigp1_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWCACHE" *) output [3:0]maxigp1_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWPROT" *) output [2:0]maxigp1_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWVALID" *) output maxigp1_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWUSER" *) output [15:0]maxigp1_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWREADY" *) input maxigp1_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD WDATA" *) output [127:0]maxigp1_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD WSTRB" *) output [15:0]maxigp1_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD WLAST" *) output maxigp1_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD WVALID" *) output maxigp1_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD WREADY" *) input maxigp1_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD BID" *) input [15:0]maxigp1_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD BRESP" *) input [1:0]maxigp1_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD BVALID" *) input maxigp1_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD BREADY" *) output maxigp1_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARID" *) output [15:0]maxigp1_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARADDR" *) output [39:0]maxigp1_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARLEN" *) output [7:0]maxigp1_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARSIZE" *) output [2:0]maxigp1_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARBURST" *) output [1:0]maxigp1_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARLOCK" *) output maxigp1_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARCACHE" *) output [3:0]maxigp1_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARPROT" *) output [2:0]maxigp1_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARVALID" *) output maxigp1_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARUSER" *) output [15:0]maxigp1_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARREADY" *) input maxigp1_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RID" *) input [15:0]maxigp1_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RDATA" *) input [127:0]maxigp1_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RRESP" *) input [1:0]maxigp1_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RLAST" *) input maxigp1_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RVALID" *) input maxigp1_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD RREADY" *) output maxigp1_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD AWQOS" *) output [3:0]maxigp1_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD ARQOS" *) output [3:0]maxigp1_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 M_AXI_HPM0_LPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM0_LPD_ACLK, ASSOCIATED_BUSIF M_AXI_HPM0_LPD, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *) input maxihpm0_lpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWID" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM0_LPD, NUM_WRITE_OUTSTANDING 8, NUM_READ_OUTSTANDING 8, DATA_WIDTH 32, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 16, ADDR_WIDTH 40, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 4, NUM_WRITE_THREADS 4, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [15:0]maxigp2_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWADDR" *) output [39:0]maxigp2_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWLEN" *) output [7:0]maxigp2_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWSIZE" *) output [2:0]maxigp2_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWBURST" *) output [1:0]maxigp2_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWLOCK" *) output maxigp2_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWCACHE" *) output [3:0]maxigp2_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWPROT" *) output [2:0]maxigp2_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWVALID" *) output maxigp2_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWUSER" *) output [15:0]maxigp2_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWREADY" *) input maxigp2_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD WDATA" *) output [31:0]maxigp2_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD WSTRB" *) output [3:0]maxigp2_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD WLAST" *) output maxigp2_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD WVALID" *) output maxigp2_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD WREADY" *) input maxigp2_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD BID" *) input [15:0]maxigp2_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD BRESP" *) input [1:0]maxigp2_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD BVALID" *) input maxigp2_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD BREADY" *) output maxigp2_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARID" *) output [15:0]maxigp2_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARADDR" *) output [39:0]maxigp2_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARLEN" *) output [7:0]maxigp2_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARSIZE" *) output [2:0]maxigp2_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARBURST" *) output [1:0]maxigp2_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARLOCK" *) output maxigp2_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARCACHE" *) output [3:0]maxigp2_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARPROT" *) output [2:0]maxigp2_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARVALID" *) output maxigp2_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARUSER" *) output [15:0]maxigp2_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARREADY" *) input maxigp2_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RID" *) input [15:0]maxigp2_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RDATA" *) input [31:0]maxigp2_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RRESP" *) input [1:0]maxigp2_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RLAST" *) input maxigp2_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RVALID" *) input maxigp2_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD RREADY" *) output maxigp2_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD AWQOS" *) output [3:0]maxigp2_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM0_LPD ARQOS" *) output [3:0]maxigp2_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_HP0_FPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP0_FPD_ACLK, ASSOCIATED_BUSIF S_AXI_HP0_FPD, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *) input saxihp0_fpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARUSER" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP0_FPD, NUM_WRITE_OUTSTANDING 16, NUM_READ_OUTSTANDING 16, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 6, ADDR_WIDTH 49, AWUSER_WIDTH 1, ARUSER_WIDTH 1, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input saxigp2_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWUSER" *) input saxigp2_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWID" *) input [5:0]saxigp2_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWADDR" *) input [48:0]saxigp2_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWLEN" *) input [7:0]saxigp2_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWSIZE" *) input [2:0]saxigp2_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWBURST" *) input [1:0]saxigp2_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWLOCK" *) input saxigp2_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWCACHE" *) input [3:0]saxigp2_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWPROT" *) input [2:0]saxigp2_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWVALID" *) input saxigp2_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWREADY" *) output saxigp2_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD WDATA" *) input [127:0]saxigp2_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD WSTRB" *) input [15:0]saxigp2_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD WLAST" *) input saxigp2_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD WVALID" *) input saxigp2_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD WREADY" *) output saxigp2_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD BID" *) output [5:0]saxigp2_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD BRESP" *) output [1:0]saxigp2_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD BVALID" *) output saxigp2_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD BREADY" *) input saxigp2_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARID" *) input [5:0]saxigp2_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARADDR" *) input [48:0]saxigp2_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARLEN" *) input [7:0]saxigp2_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARSIZE" *) input [2:0]saxigp2_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARBURST" *) input [1:0]saxigp2_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARLOCK" *) input saxigp2_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARCACHE" *) input [3:0]saxigp2_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARPROT" *) input [2:0]saxigp2_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARVALID" *) input saxigp2_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARREADY" *) output saxigp2_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RID" *) output [5:0]saxigp2_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RDATA" *) output [127:0]saxigp2_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RRESP" *) output [1:0]saxigp2_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RLAST" *) output saxigp2_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RVALID" *) output saxigp2_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD RREADY" *) input saxigp2_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD AWQOS" *) input [3:0]saxigp2_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD ARQOS" *) input [3:0]saxigp2_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_HP1_FPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP1_FPD_ACLK, ASSOCIATED_BUSIF S_AXI_HP1_FPD, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *) input saxihp1_fpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARUSER" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP1_FPD, NUM_WRITE_OUTSTANDING 16, NUM_READ_OUTSTANDING 16, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 6, ADDR_WIDTH 49, AWUSER_WIDTH 1, ARUSER_WIDTH 1, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input saxigp3_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWUSER" *) input saxigp3_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWID" *) input [5:0]saxigp3_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWADDR" *) input [48:0]saxigp3_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWLEN" *) input [7:0]saxigp3_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWSIZE" *) input [2:0]saxigp3_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWBURST" *) input [1:0]saxigp3_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWLOCK" *) input saxigp3_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWCACHE" *) input [3:0]saxigp3_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWPROT" *) input [2:0]saxigp3_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWVALID" *) input saxigp3_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWREADY" *) output saxigp3_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD WDATA" *) input [127:0]saxigp3_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD WSTRB" *) input [15:0]saxigp3_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD WLAST" *) input saxigp3_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD WVALID" *) input saxigp3_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD WREADY" *) output saxigp3_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD BID" *) output [5:0]saxigp3_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD BRESP" *) output [1:0]saxigp3_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD BVALID" *) output saxigp3_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD BREADY" *) input saxigp3_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARID" *) input [5:0]saxigp3_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARADDR" *) input [48:0]saxigp3_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARLEN" *) input [7:0]saxigp3_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARSIZE" *) input [2:0]saxigp3_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARBURST" *) input [1:0]saxigp3_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARLOCK" *) input saxigp3_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARCACHE" *) input [3:0]saxigp3_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARPROT" *) input [2:0]saxigp3_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARVALID" *) input saxigp3_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARREADY" *) output saxigp3_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RID" *) output [5:0]saxigp3_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RDATA" *) output [127:0]saxigp3_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RRESP" *) output [1:0]saxigp3_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RLAST" *) output saxigp3_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RVALID" *) output saxigp3_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD RREADY" *) input saxigp3_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD AWQOS" *) input [3:0]saxigp3_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD ARQOS" *) input [3:0]saxigp3_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_HP2_FPD_ACLK CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP2_FPD_ACLK, ASSOCIATED_BUSIF S_AXI_HP2_FPD, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *) input saxihp2_fpd_aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARUSER" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP2_FPD, NUM_WRITE_OUTSTANDING 16, NUM_READ_OUTSTANDING 16, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 6, ADDR_WIDTH 49, AWUSER_WIDTH 1, ARUSER_WIDTH 1, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input saxigp4_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWUSER" *) input saxigp4_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWID" *) input [5:0]saxigp4_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWADDR" *) input [48:0]saxigp4_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWLEN" *) input [7:0]saxigp4_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWSIZE" *) input [2:0]saxigp4_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWBURST" *) input [1:0]saxigp4_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWLOCK" *) input saxigp4_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWCACHE" *) input [3:0]saxigp4_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWPROT" *) input [2:0]saxigp4_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWVALID" *) input saxigp4_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWREADY" *) output saxigp4_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD WDATA" *) input [127:0]saxigp4_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD WSTRB" *) input [15:0]saxigp4_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD WLAST" *) input saxigp4_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD WVALID" *) input saxigp4_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD WREADY" *) output saxigp4_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD BID" *) output [5:0]saxigp4_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD BRESP" *) output [1:0]saxigp4_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD BVALID" *) output saxigp4_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD BREADY" *) input saxigp4_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARID" *) input [5:0]saxigp4_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARADDR" *) input [48:0]saxigp4_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARLEN" *) input [7:0]saxigp4_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARSIZE" *) input [2:0]saxigp4_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARBURST" *) input [1:0]saxigp4_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARLOCK" *) input saxigp4_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARCACHE" *) input [3:0]saxigp4_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARPROT" *) input [2:0]saxigp4_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARVALID" *) input saxigp4_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARREADY" *) output saxigp4_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RID" *) output [5:0]saxigp4_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RDATA" *) output [127:0]saxigp4_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RRESP" *) output [1:0]saxigp4_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RLAST" *) output saxigp4_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RVALID" *) output saxigp4_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD RREADY" *) input saxigp4_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD AWQOS" *) input [3:0]saxigp4_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP2_FPD ARQOS" *) input [3:0]saxigp4_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 PL_PS_IRQ0 INTERRUPT" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_PS_IRQ0, SENSITIVITY LEVEL_HIGH, PortWidth 1" *) input [0:0]pl_ps_irq0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 PL_RESETN0 RST" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_RESETN0, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) output pl_resetn0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PL_CLK0 CLK" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_CLK0, FREQ_HZ 99999001, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk0, INSERT_VIP 0" *) output pl_clk0 /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 PL_CLK1 CLK" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME PL_CLK1, FREQ_HZ 99999001, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_zynq_ultra_ps_e_0_0_pl_clk1, INSERT_VIP 0" *) output pl_clk1 /* synthesis syn_isclock = 1 */;
endmodule
