// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:user:NPU:1.0
// IP Revision: 5

(* X_CORE_INFO = "NPU,Vivado 2025.2" *)
(* CHECK_LICENSE_TYPE = "NPU_bd_NPU_0_3,NPU,{}" *)
(* CORE_GENERATION_INFO = "NPU_bd_NPU_0_3,NPU,{x_ipProduct=Vivado 2025.2,x_ipVendor=xilinx.com,x_ipLibrary=user,x_ipName=NPU,x_ipVersion=1.0,x_ipCoreRevision=5,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}" *)
(* IP_DEFINITION_SOURCE = "package_project" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module NPU_bd_NPU_0_3 (
  clk,
  rst,
  s_axil_awaddr,
  s_axil_awvalid,
  s_axil_awready,
  s_axil_wdata,
  s_axil_wvalid,
  s_axil_wready,
  s_axil_bresp,
  s_axil_bvalid,
  s_axil_bready,
  seq_araddr,
  seq_arvalid,
  seq_arlen,
  seq_arsize,
  seq_arburst,
  seq_arready,
  seq_rdata,
  seq_rvalid,
  seq_rlast,
  seq_rresp,
  seq_rready,
  dma_araddr,
  dma_arvalid,
  dma_arlen,
  dma_arsize,
  dma_arburst,
  dma_arcache,
  dma_arready,
  dma_rdata,
  dma_rvalid,
  dma_rlast,
  dma_rresp,
  dma_rready,
  wt_araddr,
  wt_arvalid,
  wt_arlen,
  wt_arsize,
  wt_arburst,
  wt_arcache,
  wt_arready,
  wt_rdata,
  wt_rvalid,
  wt_rlast,
  wt_rresp,
  wt_rready,
  st_awaddr,
  st_awvalid,
  st_awlen,
  st_awsize,
  st_awburst,
  st_awcache,
  st_awready,
  st_wdata,
  st_wstrb,
  st_wlast,
  st_wvalid,
  st_wready,
  st_bresp,
  st_bvalid,
  st_bready,
  irq_done,
  fetch_err,
  dma_err
);

(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF dma:s_axil:seq:st:wt, ASSOCIATED_RESET rst, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0" *)
input wire clk;
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
input wire rst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_\
THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire [31 : 0] s_axil_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
input wire s_axil_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
output wire s_axil_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
input wire [31 : 0] s_axil_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
input wire s_axil_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
output wire s_axil_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
output wire [1 : 0] s_axil_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
output wire s_axil_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
input wire s_axil_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME seq, DATA_WIDTH 32, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREAD\
S 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire [43 : 0] seq_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARVALID" *)
output wire seq_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARLEN" *)
output wire [7 : 0] seq_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARSIZE" *)
output wire [2 : 0] seq_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARBURST" *)
output wire [1 : 0] seq_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq ARREADY" *)
input wire seq_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RDATA" *)
input wire [31 : 0] seq_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RVALID" *)
input wire seq_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RLAST" *)
input wire seq_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RRESP" *)
input wire [1 : 0] seq_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 seq RREADY" *)
output wire seq_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME dma, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREA\
DS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire [43 : 0] dma_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARVALID" *)
output wire dma_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARLEN" *)
output wire [7 : 0] dma_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARSIZE" *)
output wire [2 : 0] dma_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARBURST" *)
output wire [1 : 0] dma_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARCACHE" *)
output wire [3 : 0] dma_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma ARREADY" *)
input wire dma_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RDATA" *)
input wire [127 : 0] dma_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RVALID" *)
input wire dma_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RLAST" *)
input wire dma_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RRESP" *)
input wire [1 : 0] dma_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma RREADY" *)
output wire dma_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wt, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREAD\
S 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire [43 : 0] wt_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARVALID" *)
output wire wt_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARLEN" *)
output wire [7 : 0] wt_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARSIZE" *)
output wire [2 : 0] wt_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARBURST" *)
output wire [1 : 0] wt_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARCACHE" *)
output wire [3 : 0] wt_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt ARREADY" *)
input wire wt_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RDATA" *)
input wire [127 : 0] wt_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RVALID" *)
input wire wt_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RLAST" *)
input wire wt_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RRESP" *)
input wire [1 : 0] wt_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wt RREADY" *)
output wire wt_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME st, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREA\
DS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire [43 : 0] st_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWVALID" *)
output wire st_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWLEN" *)
output wire [7 : 0] st_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWSIZE" *)
output wire [2 : 0] st_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWBURST" *)
output wire [1 : 0] st_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWCACHE" *)
output wire [3 : 0] st_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st AWREADY" *)
input wire st_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WDATA" *)
output wire [127 : 0] st_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WSTRB" *)
output wire [15 : 0] st_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WLAST" *)
output wire st_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WVALID" *)
output wire st_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st WREADY" *)
input wire st_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BRESP" *)
input wire [1 : 0] st_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BVALID" *)
input wire st_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 st BREADY" *)
output wire st_bready;
output wire irq_done;
output wire fetch_err;
output wire dma_err;

  NPU inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .seq_araddr(seq_araddr),
    .seq_arvalid(seq_arvalid),
    .seq_arlen(seq_arlen),
    .seq_arsize(seq_arsize),
    .seq_arburst(seq_arburst),
    .seq_arready(seq_arready),
    .seq_rdata(seq_rdata),
    .seq_rvalid(seq_rvalid),
    .seq_rlast(seq_rlast),
    .seq_rresp(seq_rresp),
    .seq_rready(seq_rready),
    .dma_araddr(dma_araddr),
    .dma_arvalid(dma_arvalid),
    .dma_arlen(dma_arlen),
    .dma_arsize(dma_arsize),
    .dma_arburst(dma_arburst),
    .dma_arcache(dma_arcache),
    .dma_arready(dma_arready),
    .dma_rdata(dma_rdata),
    .dma_rvalid(dma_rvalid),
    .dma_rlast(dma_rlast),
    .dma_rresp(dma_rresp),
    .dma_rready(dma_rready),
    .wt_araddr(wt_araddr),
    .wt_arvalid(wt_arvalid),
    .wt_arlen(wt_arlen),
    .wt_arsize(wt_arsize),
    .wt_arburst(wt_arburst),
    .wt_arcache(wt_arcache),
    .wt_arready(wt_arready),
    .wt_rdata(wt_rdata),
    .wt_rvalid(wt_rvalid),
    .wt_rlast(wt_rlast),
    .wt_rresp(wt_rresp),
    .wt_rready(wt_rready),
    .st_awaddr(st_awaddr),
    .st_awvalid(st_awvalid),
    .st_awlen(st_awlen),
    .st_awsize(st_awsize),
    .st_awburst(st_awburst),
    .st_awcache(st_awcache),
    .st_awready(st_awready),
    .st_wdata(st_wdata),
    .st_wstrb(st_wstrb),
    .st_wlast(st_wlast),
    .st_wvalid(st_wvalid),
    .st_wready(st_wready),
    .st_bresp(st_bresp),
    .st_bvalid(st_bvalid),
    .st_bready(st_bready),
    .irq_done(irq_done),
    .fetch_err(fetch_err),
    .dma_err(dma_err)
  );
endmodule
