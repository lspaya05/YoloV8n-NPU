// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
// Date        : Mon Jun  8 23:17:33 2026
// Host        : PaPayaPC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/Leona/GitHubRepo/EE470-FinalProject/NPU_bd/ip/NPU_bd_NPU_0_3/NPU_bd_NPU_0_3_stub.v
// Design      : NPU_bd_NPU_0_3
// Purpose     : Stub declaration of top-level module interface
// Device      : xck26-sfvc784-2LV-c
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "NPU_bd_NPU_0_3,NPU,{}" *) (* CORE_GENERATION_INFO = "NPU_bd_NPU_0_3,NPU,{x_ipProduct=Vivado 2025.2,x_ipVendor=xilinx.com,x_ipLibrary=user,x_ipName=NPU,x_ipVersion=1.0,x_ipCoreRevision=5,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) 
(* IP_DEFINITION_SOURCE = "package_project" *) (* X_CORE_INFO = "NPU,Vivado 2025.2" *) 
module NPU_bd_NPU_0_3(clk, rst, s_axil_awaddr, s_axil_awvalid, 
  s_axil_awready, s_axil_wdata, s_axil_wvalid, s_axil_wready, s_axil_bresp, s_axil_bvalid, 
  s_axil_bready, seq_araddr, seq_arvalid, seq_arlen, seq_arsize, seq_arburst, seq_arready, 
  seq_rdata, seq_rvalid, seq_rlast, seq_rresp, seq_rready, dma_araddr, dma_arvalid, dma_arlen, 
  dma_arsize, dma_arburst, dma_arcache, dma_arready, dma_rdata, dma_rvalid, dma_rlast, dma_rresp, 
  dma_rready, wt_araddr, wt_arvalid, wt_arlen, wt_arsize, wt_arburst, wt_arcache, wt_arready, 
  wt_rdata, wt_rvalid, wt_rlast, wt_rresp, wt_rready, st_awaddr, st_awvalid, st_awlen, st_awsize, 
  st_awburst, st_awcache, st_awready, st_wdata, st_wstrb, st_wlast, st_wvalid, st_wready, st_bresp, 
  st_bvalid, st_bready, irq_done, fetch_err, dma_err)
/* synthesis syn_black_box black_box_pad_pin="rst,s_axil_awaddr[31:0],s_axil_awvalid,s_axil_awready,s_axil_wdata[31:0],s_axil_wvalid,s_axil_wready,s_axil_bresp[1:0],s_axil_bvalid,s_axil_bready,seq_araddr[43:0],seq_arvalid,seq_arlen[7:0],seq_arsize[2:0],seq_arburst[1:0],seq_arready,seq_rdata[31:0],seq_rvalid,seq_rlast,seq_rresp[1:0],seq_rready,dma_araddr[43:0],dma_arvalid,dma_arlen[7:0],dma_arsize[2:0],dma_arburst[1:0],dma_arcache[3:0],dma_arready,dma_rdata[127:0],dma_rvalid,dma_rlast,dma_rresp[1:0],dma_rready,wt_araddr[43:0],wt_arvalid,wt_arlen[7:0],wt_arsize[2:0],wt_arburst[1:0],wt_arcache[3:0],wt_arready,wt_rdata[127:0],wt_rvalid,wt_rlast,wt_rresp[1:0],wt_rready,st_awaddr[43:0],st_awvalid,st_awlen[7:0],st_awsize[2:0],st_awburst[1:0],st_awcache[3:0],st_awready,st_wdata[127:0],st_wstrb[15:0],st_wlast,st_wvalid,st_wready,st_bresp[1:0],st_bvalid,st_bready,irq_done,fetch_err,dma_err" */
/* synthesis syn_force_seq_prim="clk" */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF dma:s_axil:seq:st:wt, ASSOCIATED_RESET rst, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *) input clk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *) input rst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [31:0]s_axil_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *) input s_axil_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *) output s_axil_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *) input [31:0]s_axil_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *) input s_axil_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *) output s_axil_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *) output [1:0]s_axil_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *) output s_axil_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *) input s_axil_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARADDR" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME seq, DATA_WIDTH 32, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [43:0]seq_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARVALID" *) output seq_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARLEN" *) output [7:0]seq_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARSIZE" *) output [2:0]seq_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARBURST" *) output [1:0]seq_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARREADY" *) input seq_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RDATA" *) input [31:0]seq_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RVALID" *) input seq_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RLAST" *) input seq_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RRESP" *) input [1:0]seq_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RREADY" *) output seq_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARADDR" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME dma, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [43:0]dma_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARVALID" *) output dma_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARLEN" *) output [7:0]dma_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARSIZE" *) output [2:0]dma_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARBURST" *) output [1:0]dma_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARCACHE" *) output [3:0]dma_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARREADY" *) input dma_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RDATA" *) input [127:0]dma_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RVALID" *) input dma_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RLAST" *) input dma_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RRESP" *) input [1:0]dma_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RREADY" *) output dma_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARADDR" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wt, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [43:0]wt_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARVALID" *) output wt_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARLEN" *) output [7:0]wt_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARSIZE" *) output [2:0]wt_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARBURST" *) output [1:0]wt_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARCACHE" *) output [3:0]wt_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARREADY" *) input wt_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RDATA" *) input [127:0]wt_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RVALID" *) input wt_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RLAST" *) input wt_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RRESP" *) input [1:0]wt_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RREADY" *) output wt_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWADDR" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME st, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [43:0]st_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWVALID" *) output st_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWLEN" *) output [7:0]st_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWSIZE" *) output [2:0]st_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWBURST" *) output [1:0]st_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWCACHE" *) output [3:0]st_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWREADY" *) input st_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WDATA" *) output [127:0]st_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WSTRB" *) output [15:0]st_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WLAST" *) output st_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WVALID" *) output st_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WREADY" *) input st_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BRESP" *) input [1:0]st_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BVALID" *) input st_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BREADY" *) output st_bready;
  output irq_done;
  output fetch_err;
  output dma_err;
endmodule
