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

// IP VLNV: xilinx.com:ip:zynq_ultra_ps_e:3.5
// IP Revision: 8

// The following must be inserted into your Verilog file for this
// core to be instantiated. Change the instance name and port connections
// (in parentheses) to your own signal names.

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
zynq_ultra_ps_e_0 your_instance_name (
  .maxihpm1_fpd_aclk(maxihpm1_fpd_aclk),  // input wire maxihpm1_fpd_aclk
  .maxigp1_awid(maxigp1_awid),            // output wire [15 : 0] maxigp1_awid
  .maxigp1_awaddr(maxigp1_awaddr),        // output wire [39 : 0] maxigp1_awaddr
  .maxigp1_awlen(maxigp1_awlen),          // output wire [7 : 0] maxigp1_awlen
  .maxigp1_awsize(maxigp1_awsize),        // output wire [2 : 0] maxigp1_awsize
  .maxigp1_awburst(maxigp1_awburst),      // output wire [1 : 0] maxigp1_awburst
  .maxigp1_awlock(maxigp1_awlock),        // output wire maxigp1_awlock
  .maxigp1_awcache(maxigp1_awcache),      // output wire [3 : 0] maxigp1_awcache
  .maxigp1_awprot(maxigp1_awprot),        // output wire [2 : 0] maxigp1_awprot
  .maxigp1_awvalid(maxigp1_awvalid),      // output wire maxigp1_awvalid
  .maxigp1_awuser(maxigp1_awuser),        // output wire [15 : 0] maxigp1_awuser
  .maxigp1_awready(maxigp1_awready),      // input wire maxigp1_awready
  .maxigp1_wdata(maxigp1_wdata),          // output wire [127 : 0] maxigp1_wdata
  .maxigp1_wstrb(maxigp1_wstrb),          // output wire [15 : 0] maxigp1_wstrb
  .maxigp1_wlast(maxigp1_wlast),          // output wire maxigp1_wlast
  .maxigp1_wvalid(maxigp1_wvalid),        // output wire maxigp1_wvalid
  .maxigp1_wready(maxigp1_wready),        // input wire maxigp1_wready
  .maxigp1_bid(maxigp1_bid),              // input wire [15 : 0] maxigp1_bid
  .maxigp1_bresp(maxigp1_bresp),          // input wire [1 : 0] maxigp1_bresp
  .maxigp1_bvalid(maxigp1_bvalid),        // input wire maxigp1_bvalid
  .maxigp1_bready(maxigp1_bready),        // output wire maxigp1_bready
  .maxigp1_arid(maxigp1_arid),            // output wire [15 : 0] maxigp1_arid
  .maxigp1_araddr(maxigp1_araddr),        // output wire [39 : 0] maxigp1_araddr
  .maxigp1_arlen(maxigp1_arlen),          // output wire [7 : 0] maxigp1_arlen
  .maxigp1_arsize(maxigp1_arsize),        // output wire [2 : 0] maxigp1_arsize
  .maxigp1_arburst(maxigp1_arburst),      // output wire [1 : 0] maxigp1_arburst
  .maxigp1_arlock(maxigp1_arlock),        // output wire maxigp1_arlock
  .maxigp1_arcache(maxigp1_arcache),      // output wire [3 : 0] maxigp1_arcache
  .maxigp1_arprot(maxigp1_arprot),        // output wire [2 : 0] maxigp1_arprot
  .maxigp1_arvalid(maxigp1_arvalid),      // output wire maxigp1_arvalid
  .maxigp1_aruser(maxigp1_aruser),        // output wire [15 : 0] maxigp1_aruser
  .maxigp1_arready(maxigp1_arready),      // input wire maxigp1_arready
  .maxigp1_rid(maxigp1_rid),              // input wire [15 : 0] maxigp1_rid
  .maxigp1_rdata(maxigp1_rdata),          // input wire [127 : 0] maxigp1_rdata
  .maxigp1_rresp(maxigp1_rresp),          // input wire [1 : 0] maxigp1_rresp
  .maxigp1_rlast(maxigp1_rlast),          // input wire maxigp1_rlast
  .maxigp1_rvalid(maxigp1_rvalid),        // input wire maxigp1_rvalid
  .maxigp1_rready(maxigp1_rready),        // output wire maxigp1_rready
  .maxigp1_awqos(maxigp1_awqos),          // output wire [3 : 0] maxigp1_awqos
  .maxigp1_arqos(maxigp1_arqos),          // output wire [3 : 0] maxigp1_arqos
  .saxihp0_fpd_aclk(saxihp0_fpd_aclk),    // input wire saxihp0_fpd_aclk
  .saxigp2_aruser(saxigp2_aruser),        // input wire saxigp2_aruser
  .saxigp2_awuser(saxigp2_awuser),        // input wire saxigp2_awuser
  .saxigp2_awid(saxigp2_awid),            // input wire [5 : 0] saxigp2_awid
  .saxigp2_awaddr(saxigp2_awaddr),        // input wire [48 : 0] saxigp2_awaddr
  .saxigp2_awlen(saxigp2_awlen),          // input wire [7 : 0] saxigp2_awlen
  .saxigp2_awsize(saxigp2_awsize),        // input wire [2 : 0] saxigp2_awsize
  .saxigp2_awburst(saxigp2_awburst),      // input wire [1 : 0] saxigp2_awburst
  .saxigp2_awlock(saxigp2_awlock),        // input wire saxigp2_awlock
  .saxigp2_awcache(saxigp2_awcache),      // input wire [3 : 0] saxigp2_awcache
  .saxigp2_awprot(saxigp2_awprot),        // input wire [2 : 0] saxigp2_awprot
  .saxigp2_awvalid(saxigp2_awvalid),      // input wire saxigp2_awvalid
  .saxigp2_awready(saxigp2_awready),      // output wire saxigp2_awready
  .saxigp2_wdata(saxigp2_wdata),          // input wire [127 : 0] saxigp2_wdata
  .saxigp2_wstrb(saxigp2_wstrb),          // input wire [15 : 0] saxigp2_wstrb
  .saxigp2_wlast(saxigp2_wlast),          // input wire saxigp2_wlast
  .saxigp2_wvalid(saxigp2_wvalid),        // input wire saxigp2_wvalid
  .saxigp2_wready(saxigp2_wready),        // output wire saxigp2_wready
  .saxigp2_bid(saxigp2_bid),              // output wire [5 : 0] saxigp2_bid
  .saxigp2_bresp(saxigp2_bresp),          // output wire [1 : 0] saxigp2_bresp
  .saxigp2_bvalid(saxigp2_bvalid),        // output wire saxigp2_bvalid
  .saxigp2_bready(saxigp2_bready),        // input wire saxigp2_bready
  .saxigp2_arid(saxigp2_arid),            // input wire [5 : 0] saxigp2_arid
  .saxigp2_araddr(saxigp2_araddr),        // input wire [48 : 0] saxigp2_araddr
  .saxigp2_arlen(saxigp2_arlen),          // input wire [7 : 0] saxigp2_arlen
  .saxigp2_arsize(saxigp2_arsize),        // input wire [2 : 0] saxigp2_arsize
  .saxigp2_arburst(saxigp2_arburst),      // input wire [1 : 0] saxigp2_arburst
  .saxigp2_arlock(saxigp2_arlock),        // input wire saxigp2_arlock
  .saxigp2_arcache(saxigp2_arcache),      // input wire [3 : 0] saxigp2_arcache
  .saxigp2_arprot(saxigp2_arprot),        // input wire [2 : 0] saxigp2_arprot
  .saxigp2_arvalid(saxigp2_arvalid),      // input wire saxigp2_arvalid
  .saxigp2_arready(saxigp2_arready),      // output wire saxigp2_arready
  .saxigp2_rid(saxigp2_rid),              // output wire [5 : 0] saxigp2_rid
  .saxigp2_rdata(saxigp2_rdata),          // output wire [127 : 0] saxigp2_rdata
  .saxigp2_rresp(saxigp2_rresp),          // output wire [1 : 0] saxigp2_rresp
  .saxigp2_rlast(saxigp2_rlast),          // output wire saxigp2_rlast
  .saxigp2_rvalid(saxigp2_rvalid),        // output wire saxigp2_rvalid
  .saxigp2_rready(saxigp2_rready),        // input wire saxigp2_rready
  .saxigp2_awqos(saxigp2_awqos),          // input wire [3 : 0] saxigp2_awqos
  .saxigp2_arqos(saxigp2_arqos),          // input wire [3 : 0] saxigp2_arqos
  .saxihp1_fpd_aclk(saxihp1_fpd_aclk),    // input wire saxihp1_fpd_aclk
  .saxigp3_aruser(saxigp3_aruser),        // input wire saxigp3_aruser
  .saxigp3_awuser(saxigp3_awuser),        // input wire saxigp3_awuser
  .saxigp3_awid(saxigp3_awid),            // input wire [5 : 0] saxigp3_awid
  .saxigp3_awaddr(saxigp3_awaddr),        // input wire [48 : 0] saxigp3_awaddr
  .saxigp3_awlen(saxigp3_awlen),          // input wire [7 : 0] saxigp3_awlen
  .saxigp3_awsize(saxigp3_awsize),        // input wire [2 : 0] saxigp3_awsize
  .saxigp3_awburst(saxigp3_awburst),      // input wire [1 : 0] saxigp3_awburst
  .saxigp3_awlock(saxigp3_awlock),        // input wire saxigp3_awlock
  .saxigp3_awcache(saxigp3_awcache),      // input wire [3 : 0] saxigp3_awcache
  .saxigp3_awprot(saxigp3_awprot),        // input wire [2 : 0] saxigp3_awprot
  .saxigp3_awvalid(saxigp3_awvalid),      // input wire saxigp3_awvalid
  .saxigp3_awready(saxigp3_awready),      // output wire saxigp3_awready
  .saxigp3_wdata(saxigp3_wdata),          // input wire [127 : 0] saxigp3_wdata
  .saxigp3_wstrb(saxigp3_wstrb),          // input wire [15 : 0] saxigp3_wstrb
  .saxigp3_wlast(saxigp3_wlast),          // input wire saxigp3_wlast
  .saxigp3_wvalid(saxigp3_wvalid),        // input wire saxigp3_wvalid
  .saxigp3_wready(saxigp3_wready),        // output wire saxigp3_wready
  .saxigp3_bid(saxigp3_bid),              // output wire [5 : 0] saxigp3_bid
  .saxigp3_bresp(saxigp3_bresp),          // output wire [1 : 0] saxigp3_bresp
  .saxigp3_bvalid(saxigp3_bvalid),        // output wire saxigp3_bvalid
  .saxigp3_bready(saxigp3_bready),        // input wire saxigp3_bready
  .saxigp3_arid(saxigp3_arid),            // input wire [5 : 0] saxigp3_arid
  .saxigp3_araddr(saxigp3_araddr),        // input wire [48 : 0] saxigp3_araddr
  .saxigp3_arlen(saxigp3_arlen),          // input wire [7 : 0] saxigp3_arlen
  .saxigp3_arsize(saxigp3_arsize),        // input wire [2 : 0] saxigp3_arsize
  .saxigp3_arburst(saxigp3_arburst),      // input wire [1 : 0] saxigp3_arburst
  .saxigp3_arlock(saxigp3_arlock),        // input wire saxigp3_arlock
  .saxigp3_arcache(saxigp3_arcache),      // input wire [3 : 0] saxigp3_arcache
  .saxigp3_arprot(saxigp3_arprot),        // input wire [2 : 0] saxigp3_arprot
  .saxigp3_arvalid(saxigp3_arvalid),      // input wire saxigp3_arvalid
  .saxigp3_arready(saxigp3_arready),      // output wire saxigp3_arready
  .saxigp3_rid(saxigp3_rid),              // output wire [5 : 0] saxigp3_rid
  .saxigp3_rdata(saxigp3_rdata),          // output wire [127 : 0] saxigp3_rdata
  .saxigp3_rresp(saxigp3_rresp),          // output wire [1 : 0] saxigp3_rresp
  .saxigp3_rlast(saxigp3_rlast),          // output wire saxigp3_rlast
  .saxigp3_rvalid(saxigp3_rvalid),        // output wire saxigp3_rvalid
  .saxigp3_rready(saxigp3_rready),        // input wire saxigp3_rready
  .saxigp3_awqos(saxigp3_awqos),          // input wire [3 : 0] saxigp3_awqos
  .saxigp3_arqos(saxigp3_arqos),          // input wire [3 : 0] saxigp3_arqos
  .pl_resetn0(pl_resetn0),                // output wire pl_resetn0
  .pl_clk0(pl_clk0)                      // output wire pl_clk0
);
// INST_TAG_END ------ End INSTANTIATION Template ---------

// You must compile the wrapper file zynq_ultra_ps_e_0.v when simulating
// the core, zynq_ultra_ps_e_0. When compiling the wrapper file, be sure to
// reference the Verilog simulation library.

