-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.
-- IP VLNV: xilinx.com:ip:zynq_ultra_ps_e:3.5
-- IP Revision: 8

-- The following code must appear in the VHDL architecture header.

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT zynq_ultra_ps_e_0
  PORT (
    maxihpm1_fpd_aclk : IN STD_LOGIC;
    maxigp1_awid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_awaddr : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
    maxigp1_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    maxigp1_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    maxigp1_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    maxigp1_awlock : OUT STD_LOGIC;
    maxigp1_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    maxigp1_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    maxigp1_awvalid : OUT STD_LOGIC;
    maxigp1_awuser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_awready : IN STD_LOGIC;
    maxigp1_wdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    maxigp1_wstrb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_wlast : OUT STD_LOGIC;
    maxigp1_wvalid : OUT STD_LOGIC;
    maxigp1_wready : IN STD_LOGIC;
    maxigp1_bid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    maxigp1_bvalid : IN STD_LOGIC;
    maxigp1_bready : OUT STD_LOGIC;
    maxigp1_arid : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_araddr : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
    maxigp1_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    maxigp1_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    maxigp1_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    maxigp1_arlock : OUT STD_LOGIC;
    maxigp1_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    maxigp1_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    maxigp1_arvalid : OUT STD_LOGIC;
    maxigp1_aruser : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_arready : IN STD_LOGIC;
    maxigp1_rid : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    maxigp1_rdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    maxigp1_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    maxigp1_rlast : IN STD_LOGIC;
    maxigp1_rvalid : IN STD_LOGIC;
    maxigp1_rready : OUT STD_LOGIC;
    maxigp1_awqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    maxigp1_arqos : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxihp0_fpd_aclk : IN STD_LOGIC;
    saxigp2_aruser : IN STD_LOGIC;
    saxigp2_awuser : IN STD_LOGIC;
    saxigp2_awid : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp2_awaddr : IN STD_LOGIC_VECTOR(48 DOWNTO 0);
    saxigp2_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    saxigp2_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp2_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp2_awlock : IN STD_LOGIC;
    saxigp2_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp2_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp2_awvalid : IN STD_LOGIC;
    saxigp2_awready : OUT STD_LOGIC;
    saxigp2_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    saxigp2_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    saxigp2_wlast : IN STD_LOGIC;
    saxigp2_wvalid : IN STD_LOGIC;
    saxigp2_wready : OUT STD_LOGIC;
    saxigp2_bid : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp2_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp2_bvalid : OUT STD_LOGIC;
    saxigp2_bready : IN STD_LOGIC;
    saxigp2_arid : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp2_araddr : IN STD_LOGIC_VECTOR(48 DOWNTO 0);
    saxigp2_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    saxigp2_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp2_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp2_arlock : IN STD_LOGIC;
    saxigp2_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp2_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp2_arvalid : IN STD_LOGIC;
    saxigp2_arready : OUT STD_LOGIC;
    saxigp2_rid : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp2_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    saxigp2_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp2_rlast : OUT STD_LOGIC;
    saxigp2_rvalid : OUT STD_LOGIC;
    saxigp2_rready : IN STD_LOGIC;
    saxigp2_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp2_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxihp1_fpd_aclk : IN STD_LOGIC;
    saxigp3_aruser : IN STD_LOGIC;
    saxigp3_awuser : IN STD_LOGIC;
    saxigp3_awid : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp3_awaddr : IN STD_LOGIC_VECTOR(48 DOWNTO 0);
    saxigp3_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    saxigp3_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp3_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp3_awlock : IN STD_LOGIC;
    saxigp3_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp3_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp3_awvalid : IN STD_LOGIC;
    saxigp3_awready : OUT STD_LOGIC;
    saxigp3_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    saxigp3_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    saxigp3_wlast : IN STD_LOGIC;
    saxigp3_wvalid : IN STD_LOGIC;
    saxigp3_wready : OUT STD_LOGIC;
    saxigp3_bid : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp3_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp3_bvalid : OUT STD_LOGIC;
    saxigp3_bready : IN STD_LOGIC;
    saxigp3_arid : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp3_araddr : IN STD_LOGIC_VECTOR(48 DOWNTO 0);
    saxigp3_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    saxigp3_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp3_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp3_arlock : IN STD_LOGIC;
    saxigp3_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp3_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    saxigp3_arvalid : IN STD_LOGIC;
    saxigp3_arready : OUT STD_LOGIC;
    saxigp3_rid : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    saxigp3_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    saxigp3_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    saxigp3_rlast : OUT STD_LOGIC;
    saxigp3_rvalid : OUT STD_LOGIC;
    saxigp3_rready : IN STD_LOGIC;
    saxigp3_awqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    saxigp3_arqos : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    pl_resetn0 : OUT STD_LOGIC;
    pl_clk0 : OUT STD_LOGIC 
  );
END COMPONENT;
-- COMP_TAG_END ------ End COMPONENT Declaration ------------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
your_instance_name : zynq_ultra_ps_e_0
  PORT MAP (
    maxihpm1_fpd_aclk => maxihpm1_fpd_aclk,
    maxigp1_awid => maxigp1_awid,
    maxigp1_awaddr => maxigp1_awaddr,
    maxigp1_awlen => maxigp1_awlen,
    maxigp1_awsize => maxigp1_awsize,
    maxigp1_awburst => maxigp1_awburst,
    maxigp1_awlock => maxigp1_awlock,
    maxigp1_awcache => maxigp1_awcache,
    maxigp1_awprot => maxigp1_awprot,
    maxigp1_awvalid => maxigp1_awvalid,
    maxigp1_awuser => maxigp1_awuser,
    maxigp1_awready => maxigp1_awready,
    maxigp1_wdata => maxigp1_wdata,
    maxigp1_wstrb => maxigp1_wstrb,
    maxigp1_wlast => maxigp1_wlast,
    maxigp1_wvalid => maxigp1_wvalid,
    maxigp1_wready => maxigp1_wready,
    maxigp1_bid => maxigp1_bid,
    maxigp1_bresp => maxigp1_bresp,
    maxigp1_bvalid => maxigp1_bvalid,
    maxigp1_bready => maxigp1_bready,
    maxigp1_arid => maxigp1_arid,
    maxigp1_araddr => maxigp1_araddr,
    maxigp1_arlen => maxigp1_arlen,
    maxigp1_arsize => maxigp1_arsize,
    maxigp1_arburst => maxigp1_arburst,
    maxigp1_arlock => maxigp1_arlock,
    maxigp1_arcache => maxigp1_arcache,
    maxigp1_arprot => maxigp1_arprot,
    maxigp1_arvalid => maxigp1_arvalid,
    maxigp1_aruser => maxigp1_aruser,
    maxigp1_arready => maxigp1_arready,
    maxigp1_rid => maxigp1_rid,
    maxigp1_rdata => maxigp1_rdata,
    maxigp1_rresp => maxigp1_rresp,
    maxigp1_rlast => maxigp1_rlast,
    maxigp1_rvalid => maxigp1_rvalid,
    maxigp1_rready => maxigp1_rready,
    maxigp1_awqos => maxigp1_awqos,
    maxigp1_arqos => maxigp1_arqos,
    saxihp0_fpd_aclk => saxihp0_fpd_aclk,
    saxigp2_aruser => saxigp2_aruser,
    saxigp2_awuser => saxigp2_awuser,
    saxigp2_awid => saxigp2_awid,
    saxigp2_awaddr => saxigp2_awaddr,
    saxigp2_awlen => saxigp2_awlen,
    saxigp2_awsize => saxigp2_awsize,
    saxigp2_awburst => saxigp2_awburst,
    saxigp2_awlock => saxigp2_awlock,
    saxigp2_awcache => saxigp2_awcache,
    saxigp2_awprot => saxigp2_awprot,
    saxigp2_awvalid => saxigp2_awvalid,
    saxigp2_awready => saxigp2_awready,
    saxigp2_wdata => saxigp2_wdata,
    saxigp2_wstrb => saxigp2_wstrb,
    saxigp2_wlast => saxigp2_wlast,
    saxigp2_wvalid => saxigp2_wvalid,
    saxigp2_wready => saxigp2_wready,
    saxigp2_bid => saxigp2_bid,
    saxigp2_bresp => saxigp2_bresp,
    saxigp2_bvalid => saxigp2_bvalid,
    saxigp2_bready => saxigp2_bready,
    saxigp2_arid => saxigp2_arid,
    saxigp2_araddr => saxigp2_araddr,
    saxigp2_arlen => saxigp2_arlen,
    saxigp2_arsize => saxigp2_arsize,
    saxigp2_arburst => saxigp2_arburst,
    saxigp2_arlock => saxigp2_arlock,
    saxigp2_arcache => saxigp2_arcache,
    saxigp2_arprot => saxigp2_arprot,
    saxigp2_arvalid => saxigp2_arvalid,
    saxigp2_arready => saxigp2_arready,
    saxigp2_rid => saxigp2_rid,
    saxigp2_rdata => saxigp2_rdata,
    saxigp2_rresp => saxigp2_rresp,
    saxigp2_rlast => saxigp2_rlast,
    saxigp2_rvalid => saxigp2_rvalid,
    saxigp2_rready => saxigp2_rready,
    saxigp2_awqos => saxigp2_awqos,
    saxigp2_arqos => saxigp2_arqos,
    saxihp1_fpd_aclk => saxihp1_fpd_aclk,
    saxigp3_aruser => saxigp3_aruser,
    saxigp3_awuser => saxigp3_awuser,
    saxigp3_awid => saxigp3_awid,
    saxigp3_awaddr => saxigp3_awaddr,
    saxigp3_awlen => saxigp3_awlen,
    saxigp3_awsize => saxigp3_awsize,
    saxigp3_awburst => saxigp3_awburst,
    saxigp3_awlock => saxigp3_awlock,
    saxigp3_awcache => saxigp3_awcache,
    saxigp3_awprot => saxigp3_awprot,
    saxigp3_awvalid => saxigp3_awvalid,
    saxigp3_awready => saxigp3_awready,
    saxigp3_wdata => saxigp3_wdata,
    saxigp3_wstrb => saxigp3_wstrb,
    saxigp3_wlast => saxigp3_wlast,
    saxigp3_wvalid => saxigp3_wvalid,
    saxigp3_wready => saxigp3_wready,
    saxigp3_bid => saxigp3_bid,
    saxigp3_bresp => saxigp3_bresp,
    saxigp3_bvalid => saxigp3_bvalid,
    saxigp3_bready => saxigp3_bready,
    saxigp3_arid => saxigp3_arid,
    saxigp3_araddr => saxigp3_araddr,
    saxigp3_arlen => saxigp3_arlen,
    saxigp3_arsize => saxigp3_arsize,
    saxigp3_arburst => saxigp3_arburst,
    saxigp3_arlock => saxigp3_arlock,
    saxigp3_arcache => saxigp3_arcache,
    saxigp3_arprot => saxigp3_arprot,
    saxigp3_arvalid => saxigp3_arvalid,
    saxigp3_arready => saxigp3_arready,
    saxigp3_rid => saxigp3_rid,
    saxigp3_rdata => saxigp3_rdata,
    saxigp3_rresp => saxigp3_rresp,
    saxigp3_rlast => saxigp3_rlast,
    saxigp3_rvalid => saxigp3_rvalid,
    saxigp3_rready => saxigp3_rready,
    saxigp3_awqos => saxigp3_awqos,
    saxigp3_arqos => saxigp3_arqos,
    pl_resetn0 => pl_resetn0,
    pl_clk0 => pl_clk0
  );
-- INST_TAG_END ------ End INSTANTIATION Template ---------

-- You must compile the wrapper file zynq_ultra_ps_e_0.vhd when simulating
-- the core, zynq_ultra_ps_e_0. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.



