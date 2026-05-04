// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------
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

// MODULE VLNV: xilinx.com:ip:zynq_ultra_ps_e:3.5

`timescale 1ps / 1ps

`include "vivado_interfaces.svh"

module zynq_ultra_ps_e_0_sv (
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_HPM1_FPD" *)
  (* X_INTERFACE_MODE = "master M_AXI_HPM1_FPD" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_HPM1_FPD, NUM_WRITE_OUTSTANDING 8, NUM_READ_OUTSTANDING 8, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 16, ADDR_WIDTH 40, AWUSER_WIDTH 16, ARUSER_WIDTH 16, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.master M_AXI_HPM1_FPD,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0_FPD" *)
  (* X_INTERFACE_MODE = "slave S_AXI_HP0_FPD" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP0_FPD, NUM_WRITE_OUTSTANDING 16, NUM_READ_OUTSTANDING 16, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 6, ADDR_WIDTH 49, AWUSER_WIDTH 1, ARUSER_WIDTH 1, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.slave S_AXI_HP0_FPD,
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1_FPD" *)
  (* X_INTERFACE_MODE = "slave S_AXI_HP1_FPD" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP1_FPD, NUM_WRITE_OUTSTANDING 16, NUM_READ_OUTSTANDING 16, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 6, ADDR_WIDTH 49, AWUSER_WIDTH 1, ARUSER_WIDTH 1, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, PHASE 0.0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
  vivado_aximm_v1_0.slave S_AXI_HP1_FPD,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire maxihpm1_fpd_aclk,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire saxihp0_fpd_aclk,
  (* X_INTERFACE_IGNORE = "true" *)
  input wire saxihp1_fpd_aclk,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire pl_resetn0,
  (* X_INTERFACE_IGNORE = "true" *)
  output wire pl_clk0
);

  // interface wire assignments
  assign M_AXI_HPM1_FPD.ARREGION = 0;
  assign M_AXI_HPM1_FPD.AWREGION = 0;
  assign M_AXI_HPM1_FPD.WID = 0;
  assign M_AXI_HPM1_FPD.WUSER = 0;
  assign S_AXI_HP0_FPD.BUSER = 0;
  assign S_AXI_HP0_FPD.RUSER = 0;
  assign S_AXI_HP1_FPD.BUSER = 0;
  assign S_AXI_HP1_FPD.RUSER = 0;

  zynq_ultra_ps_e_0 inst (
    .maxihpm1_fpd_aclk(maxihpm1_fpd_aclk),
    .maxigp1_awid(M_AXI_HPM1_FPD.AWID),
    .maxigp1_awaddr(M_AXI_HPM1_FPD.AWADDR),
    .maxigp1_awlen(M_AXI_HPM1_FPD.AWLEN),
    .maxigp1_awsize(M_AXI_HPM1_FPD.AWSIZE),
    .maxigp1_awburst(M_AXI_HPM1_FPD.AWBURST),
    .maxigp1_awlock(M_AXI_HPM1_FPD.AWLOCK),
    .maxigp1_awcache(M_AXI_HPM1_FPD.AWCACHE),
    .maxigp1_awprot(M_AXI_HPM1_FPD.AWPROT),
    .maxigp1_awvalid(M_AXI_HPM1_FPD.AWVALID),
    .maxigp1_awuser(M_AXI_HPM1_FPD.AWUSER),
    .maxigp1_awready(M_AXI_HPM1_FPD.AWREADY),
    .maxigp1_wdata(M_AXI_HPM1_FPD.WDATA),
    .maxigp1_wstrb(M_AXI_HPM1_FPD.WSTRB),
    .maxigp1_wlast(M_AXI_HPM1_FPD.WLAST),
    .maxigp1_wvalid(M_AXI_HPM1_FPD.WVALID),
    .maxigp1_wready(M_AXI_HPM1_FPD.WREADY),
    .maxigp1_bid(M_AXI_HPM1_FPD.BID),
    .maxigp1_bresp(M_AXI_HPM1_FPD.BRESP),
    .maxigp1_bvalid(M_AXI_HPM1_FPD.BVALID),
    .maxigp1_bready(M_AXI_HPM1_FPD.BREADY),
    .maxigp1_arid(M_AXI_HPM1_FPD.ARID),
    .maxigp1_araddr(M_AXI_HPM1_FPD.ARADDR),
    .maxigp1_arlen(M_AXI_HPM1_FPD.ARLEN),
    .maxigp1_arsize(M_AXI_HPM1_FPD.ARSIZE),
    .maxigp1_arburst(M_AXI_HPM1_FPD.ARBURST),
    .maxigp1_arlock(M_AXI_HPM1_FPD.ARLOCK),
    .maxigp1_arcache(M_AXI_HPM1_FPD.ARCACHE),
    .maxigp1_arprot(M_AXI_HPM1_FPD.ARPROT),
    .maxigp1_arvalid(M_AXI_HPM1_FPD.ARVALID),
    .maxigp1_aruser(M_AXI_HPM1_FPD.ARUSER),
    .maxigp1_arready(M_AXI_HPM1_FPD.ARREADY),
    .maxigp1_rid(M_AXI_HPM1_FPD.RID),
    .maxigp1_rdata(M_AXI_HPM1_FPD.RDATA),
    .maxigp1_rresp(M_AXI_HPM1_FPD.RRESP),
    .maxigp1_rlast(M_AXI_HPM1_FPD.RLAST),
    .maxigp1_rvalid(M_AXI_HPM1_FPD.RVALID),
    .maxigp1_rready(M_AXI_HPM1_FPD.RREADY),
    .maxigp1_awqos(M_AXI_HPM1_FPD.AWQOS),
    .maxigp1_arqos(M_AXI_HPM1_FPD.ARQOS),
    .saxihp0_fpd_aclk(saxihp0_fpd_aclk),
    .saxigp2_aruser(S_AXI_HP0_FPD.ARUSER),
    .saxigp2_awuser(S_AXI_HP0_FPD.AWUSER),
    .saxigp2_awid(S_AXI_HP0_FPD.AWID),
    .saxigp2_awaddr(S_AXI_HP0_FPD.AWADDR),
    .saxigp2_awlen(S_AXI_HP0_FPD.AWLEN),
    .saxigp2_awsize(S_AXI_HP0_FPD.AWSIZE),
    .saxigp2_awburst(S_AXI_HP0_FPD.AWBURST),
    .saxigp2_awlock(S_AXI_HP0_FPD.AWLOCK),
    .saxigp2_awcache(S_AXI_HP0_FPD.AWCACHE),
    .saxigp2_awprot(S_AXI_HP0_FPD.AWPROT),
    .saxigp2_awvalid(S_AXI_HP0_FPD.AWVALID),
    .saxigp2_awready(S_AXI_HP0_FPD.AWREADY),
    .saxigp2_wdata(S_AXI_HP0_FPD.WDATA),
    .saxigp2_wstrb(S_AXI_HP0_FPD.WSTRB),
    .saxigp2_wlast(S_AXI_HP0_FPD.WLAST),
    .saxigp2_wvalid(S_AXI_HP0_FPD.WVALID),
    .saxigp2_wready(S_AXI_HP0_FPD.WREADY),
    .saxigp2_bid(S_AXI_HP0_FPD.BID),
    .saxigp2_bresp(S_AXI_HP0_FPD.BRESP),
    .saxigp2_bvalid(S_AXI_HP0_FPD.BVALID),
    .saxigp2_bready(S_AXI_HP0_FPD.BREADY),
    .saxigp2_arid(S_AXI_HP0_FPD.ARID),
    .saxigp2_araddr(S_AXI_HP0_FPD.ARADDR),
    .saxigp2_arlen(S_AXI_HP0_FPD.ARLEN),
    .saxigp2_arsize(S_AXI_HP0_FPD.ARSIZE),
    .saxigp2_arburst(S_AXI_HP0_FPD.ARBURST),
    .saxigp2_arlock(S_AXI_HP0_FPD.ARLOCK),
    .saxigp2_arcache(S_AXI_HP0_FPD.ARCACHE),
    .saxigp2_arprot(S_AXI_HP0_FPD.ARPROT),
    .saxigp2_arvalid(S_AXI_HP0_FPD.ARVALID),
    .saxigp2_arready(S_AXI_HP0_FPD.ARREADY),
    .saxigp2_rid(S_AXI_HP0_FPD.RID),
    .saxigp2_rdata(S_AXI_HP0_FPD.RDATA),
    .saxigp2_rresp(S_AXI_HP0_FPD.RRESP),
    .saxigp2_rlast(S_AXI_HP0_FPD.RLAST),
    .saxigp2_rvalid(S_AXI_HP0_FPD.RVALID),
    .saxigp2_rready(S_AXI_HP0_FPD.RREADY),
    .saxigp2_awqos(S_AXI_HP0_FPD.AWQOS),
    .saxigp2_arqos(S_AXI_HP0_FPD.ARQOS),
    .saxihp1_fpd_aclk(saxihp1_fpd_aclk),
    .saxigp3_aruser(S_AXI_HP1_FPD.ARUSER),
    .saxigp3_awuser(S_AXI_HP1_FPD.AWUSER),
    .saxigp3_awid(S_AXI_HP1_FPD.AWID),
    .saxigp3_awaddr(S_AXI_HP1_FPD.AWADDR),
    .saxigp3_awlen(S_AXI_HP1_FPD.AWLEN),
    .saxigp3_awsize(S_AXI_HP1_FPD.AWSIZE),
    .saxigp3_awburst(S_AXI_HP1_FPD.AWBURST),
    .saxigp3_awlock(S_AXI_HP1_FPD.AWLOCK),
    .saxigp3_awcache(S_AXI_HP1_FPD.AWCACHE),
    .saxigp3_awprot(S_AXI_HP1_FPD.AWPROT),
    .saxigp3_awvalid(S_AXI_HP1_FPD.AWVALID),
    .saxigp3_awready(S_AXI_HP1_FPD.AWREADY),
    .saxigp3_wdata(S_AXI_HP1_FPD.WDATA),
    .saxigp3_wstrb(S_AXI_HP1_FPD.WSTRB),
    .saxigp3_wlast(S_AXI_HP1_FPD.WLAST),
    .saxigp3_wvalid(S_AXI_HP1_FPD.WVALID),
    .saxigp3_wready(S_AXI_HP1_FPD.WREADY),
    .saxigp3_bid(S_AXI_HP1_FPD.BID),
    .saxigp3_bresp(S_AXI_HP1_FPD.BRESP),
    .saxigp3_bvalid(S_AXI_HP1_FPD.BVALID),
    .saxigp3_bready(S_AXI_HP1_FPD.BREADY),
    .saxigp3_arid(S_AXI_HP1_FPD.ARID),
    .saxigp3_araddr(S_AXI_HP1_FPD.ARADDR),
    .saxigp3_arlen(S_AXI_HP1_FPD.ARLEN),
    .saxigp3_arsize(S_AXI_HP1_FPD.ARSIZE),
    .saxigp3_arburst(S_AXI_HP1_FPD.ARBURST),
    .saxigp3_arlock(S_AXI_HP1_FPD.ARLOCK),
    .saxigp3_arcache(S_AXI_HP1_FPD.ARCACHE),
    .saxigp3_arprot(S_AXI_HP1_FPD.ARPROT),
    .saxigp3_arvalid(S_AXI_HP1_FPD.ARVALID),
    .saxigp3_arready(S_AXI_HP1_FPD.ARREADY),
    .saxigp3_rid(S_AXI_HP1_FPD.RID),
    .saxigp3_rdata(S_AXI_HP1_FPD.RDATA),
    .saxigp3_rresp(S_AXI_HP1_FPD.RRESP),
    .saxigp3_rlast(S_AXI_HP1_FPD.RLAST),
    .saxigp3_rvalid(S_AXI_HP1_FPD.RVALID),
    .saxigp3_rready(S_AXI_HP1_FPD.RREADY),
    .saxigp3_awqos(S_AXI_HP1_FPD.AWQOS),
    .saxigp3_arqos(S_AXI_HP1_FPD.ARQOS),
    .pl_resetn0(pl_resetn0),
    .pl_clk0(pl_clk0)
  );

endmodule
