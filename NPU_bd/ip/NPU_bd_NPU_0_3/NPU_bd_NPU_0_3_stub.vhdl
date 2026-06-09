-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
-- Date        : Mon Jun  8 23:17:33 2026
-- Host        : PaPayaPC running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               c:/Users/Leona/GitHubRepo/EE470-FinalProject/NPU_bd/ip/NPU_bd_NPU_0_3/NPU_bd_NPU_0_3_stub.vhdl
-- Design      : NPU_bd_NPU_0_3
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xck26-sfvc784-2LV-c
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity NPU_bd_NPU_0_3 is
  Port ( 
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;
    s_axil_awaddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_awvalid : in STD_LOGIC;
    s_axil_awready : out STD_LOGIC;
    s_axil_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axil_wvalid : in STD_LOGIC;
    s_axil_wready : out STD_LOGIC;
    s_axil_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s_axil_bvalid : out STD_LOGIC;
    s_axil_bready : in STD_LOGIC;
    seq_araddr : out STD_LOGIC_VECTOR ( 43 downto 0 );
    seq_arvalid : out STD_LOGIC;
    seq_arlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    seq_arsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    seq_arburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    seq_arready : in STD_LOGIC;
    seq_rdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    seq_rvalid : in STD_LOGIC;
    seq_rlast : in STD_LOGIC;
    seq_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    seq_rready : out STD_LOGIC;
    dma_araddr : out STD_LOGIC_VECTOR ( 43 downto 0 );
    dma_arvalid : out STD_LOGIC;
    dma_arlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    dma_arsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    dma_arburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    dma_arcache : out STD_LOGIC_VECTOR ( 3 downto 0 );
    dma_arready : in STD_LOGIC;
    dma_rdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
    dma_rvalid : in STD_LOGIC;
    dma_rlast : in STD_LOGIC;
    dma_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    dma_rready : out STD_LOGIC;
    wt_araddr : out STD_LOGIC_VECTOR ( 43 downto 0 );
    wt_arvalid : out STD_LOGIC;
    wt_arlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    wt_arsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    wt_arburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    wt_arcache : out STD_LOGIC_VECTOR ( 3 downto 0 );
    wt_arready : in STD_LOGIC;
    wt_rdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
    wt_rvalid : in STD_LOGIC;
    wt_rlast : in STD_LOGIC;
    wt_rresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    wt_rready : out STD_LOGIC;
    st_awaddr : out STD_LOGIC_VECTOR ( 43 downto 0 );
    st_awvalid : out STD_LOGIC;
    st_awlen : out STD_LOGIC_VECTOR ( 7 downto 0 );
    st_awsize : out STD_LOGIC_VECTOR ( 2 downto 0 );
    st_awburst : out STD_LOGIC_VECTOR ( 1 downto 0 );
    st_awcache : out STD_LOGIC_VECTOR ( 3 downto 0 );
    st_awready : in STD_LOGIC;
    st_wdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
    st_wstrb : out STD_LOGIC_VECTOR ( 15 downto 0 );
    st_wlast : out STD_LOGIC;
    st_wvalid : out STD_LOGIC;
    st_wready : in STD_LOGIC;
    st_bresp : in STD_LOGIC_VECTOR ( 1 downto 0 );
    st_bvalid : in STD_LOGIC;
    st_bready : out STD_LOGIC;
    irq_done : out STD_LOGIC;
    fetch_err : out STD_LOGIC;
    dma_err : out STD_LOGIC
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of NPU_bd_NPU_0_3 : entity is "NPU_bd_NPU_0_3,NPU,{}";
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of NPU_bd_NPU_0_3 : entity is "NPU_bd_NPU_0_3,NPU,{x_ipProduct=Vivado 2025.2,x_ipVendor=xilinx.com,x_ipLibrary=user,x_ipName=NPU,x_ipVersion=1.0,x_ipCoreRevision=5,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of NPU_bd_NPU_0_3 : entity is "yes";
  attribute IP_DEFINITION_SOURCE : string;
  attribute IP_DEFINITION_SOURCE of NPU_bd_NPU_0_3 : entity is "package_project";
end NPU_bd_NPU_0_3;

architecture stub of NPU_bd_NPU_0_3 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "clk,rst,s_axil_awaddr[31:0],s_axil_awvalid,s_axil_awready,s_axil_wdata[31:0],s_axil_wvalid,s_axil_wready,s_axil_bresp[1:0],s_axil_bvalid,s_axil_bready,seq_araddr[43:0],seq_arvalid,seq_arlen[7:0],seq_arsize[2:0],seq_arburst[1:0],seq_arready,seq_rdata[31:0],seq_rvalid,seq_rlast,seq_rresp[1:0],seq_rready,dma_araddr[43:0],dma_arvalid,dma_arlen[7:0],dma_arsize[2:0],dma_arburst[1:0],dma_arcache[3:0],dma_arready,dma_rdata[127:0],dma_rvalid,dma_rlast,dma_rresp[1:0],dma_rready,wt_araddr[43:0],wt_arvalid,wt_arlen[7:0],wt_arsize[2:0],wt_arburst[1:0],wt_arcache[3:0],wt_arready,wt_rdata[127:0],wt_rvalid,wt_rlast,wt_rresp[1:0],wt_rready,st_awaddr[43:0],st_awvalid,st_awlen[7:0],st_awsize[2:0],st_awburst[1:0],st_awcache[3:0],st_awready,st_wdata[127:0],st_wstrb[15:0],st_wlast,st_wvalid,st_wready,st_bresp[1:0],st_bvalid,st_bready,irq_done,fetch_err,dma_err";
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of clk : signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_MODE : string;
  attribute X_INTERFACE_MODE of clk : signal is "slave";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of clk : signal is "XIL_INTERFACENAME clk, ASSOCIATED_BUSIF dma:s_axil:seq:st:wt, ASSOCIATED_RESET rst, FREQ_HZ 150079014, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of rst : signal is "xilinx.com:signal:reset:1.0 rst RST";
  attribute X_INTERFACE_MODE of rst : signal is "slave";
  attribute X_INTERFACE_PARAMETER of rst : signal is "XIL_INTERFACENAME rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axil_awaddr : signal is "xilinx.com:interface:aximm:1.0 s_axil AWADDR";
  attribute X_INTERFACE_MODE of s_axil_awaddr : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axil_awaddr : signal is "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axil_awvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil AWVALID";
  attribute X_INTERFACE_INFO of s_axil_awready : signal is "xilinx.com:interface:aximm:1.0 s_axil AWREADY";
  attribute X_INTERFACE_INFO of s_axil_wdata : signal is "xilinx.com:interface:aximm:1.0 s_axil WDATA";
  attribute X_INTERFACE_INFO of s_axil_wvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil WVALID";
  attribute X_INTERFACE_INFO of s_axil_wready : signal is "xilinx.com:interface:aximm:1.0 s_axil WREADY";
  attribute X_INTERFACE_INFO of s_axil_bresp : signal is "xilinx.com:interface:aximm:1.0 s_axil BRESP";
  attribute X_INTERFACE_INFO of s_axil_bvalid : signal is "xilinx.com:interface:aximm:1.0 s_axil BVALID";
  attribute X_INTERFACE_INFO of s_axil_bready : signal is "xilinx.com:interface:aximm:1.0 s_axil BREADY";
  attribute X_INTERFACE_INFO of seq_araddr : signal is "xilinx.com:interface:aximm:1.0 seq ARADDR";
  attribute X_INTERFACE_MODE of seq_araddr : signal is "master";
  attribute X_INTERFACE_PARAMETER of seq_araddr : signal is "XIL_INTERFACENAME seq, DATA_WIDTH 32, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of seq_arvalid : signal is "xilinx.com:interface:aximm:1.0 seq ARVALID";
  attribute X_INTERFACE_INFO of seq_arlen : signal is "xilinx.com:interface:aximm:1.0 seq ARLEN";
  attribute X_INTERFACE_INFO of seq_arsize : signal is "xilinx.com:interface:aximm:1.0 seq ARSIZE";
  attribute X_INTERFACE_INFO of seq_arburst : signal is "xilinx.com:interface:aximm:1.0 seq ARBURST";
  attribute X_INTERFACE_INFO of seq_arready : signal is "xilinx.com:interface:aximm:1.0 seq ARREADY";
  attribute X_INTERFACE_INFO of seq_rdata : signal is "xilinx.com:interface:aximm:1.0 seq RDATA";
  attribute X_INTERFACE_INFO of seq_rvalid : signal is "xilinx.com:interface:aximm:1.0 seq RVALID";
  attribute X_INTERFACE_INFO of seq_rlast : signal is "xilinx.com:interface:aximm:1.0 seq RLAST";
  attribute X_INTERFACE_INFO of seq_rresp : signal is "xilinx.com:interface:aximm:1.0 seq RRESP";
  attribute X_INTERFACE_INFO of seq_rready : signal is "xilinx.com:interface:aximm:1.0 seq RREADY";
  attribute X_INTERFACE_INFO of dma_araddr : signal is "xilinx.com:interface:aximm:1.0 dma ARADDR";
  attribute X_INTERFACE_MODE of dma_araddr : signal is "master";
  attribute X_INTERFACE_PARAMETER of dma_araddr : signal is "XIL_INTERFACENAME dma, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of dma_arvalid : signal is "xilinx.com:interface:aximm:1.0 dma ARVALID";
  attribute X_INTERFACE_INFO of dma_arlen : signal is "xilinx.com:interface:aximm:1.0 dma ARLEN";
  attribute X_INTERFACE_INFO of dma_arsize : signal is "xilinx.com:interface:aximm:1.0 dma ARSIZE";
  attribute X_INTERFACE_INFO of dma_arburst : signal is "xilinx.com:interface:aximm:1.0 dma ARBURST";
  attribute X_INTERFACE_INFO of dma_arcache : signal is "xilinx.com:interface:aximm:1.0 dma ARCACHE";
  attribute X_INTERFACE_INFO of dma_arready : signal is "xilinx.com:interface:aximm:1.0 dma ARREADY";
  attribute X_INTERFACE_INFO of dma_rdata : signal is "xilinx.com:interface:aximm:1.0 dma RDATA";
  attribute X_INTERFACE_INFO of dma_rvalid : signal is "xilinx.com:interface:aximm:1.0 dma RVALID";
  attribute X_INTERFACE_INFO of dma_rlast : signal is "xilinx.com:interface:aximm:1.0 dma RLAST";
  attribute X_INTERFACE_INFO of dma_rresp : signal is "xilinx.com:interface:aximm:1.0 dma RRESP";
  attribute X_INTERFACE_INFO of dma_rready : signal is "xilinx.com:interface:aximm:1.0 dma RREADY";
  attribute X_INTERFACE_INFO of wt_araddr : signal is "xilinx.com:interface:aximm:1.0 wt ARADDR";
  attribute X_INTERFACE_MODE of wt_araddr : signal is "master";
  attribute X_INTERFACE_PARAMETER of wt_araddr : signal is "XIL_INTERFACENAME wt, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 0, HAS_BRESP 0, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of wt_arvalid : signal is "xilinx.com:interface:aximm:1.0 wt ARVALID";
  attribute X_INTERFACE_INFO of wt_arlen : signal is "xilinx.com:interface:aximm:1.0 wt ARLEN";
  attribute X_INTERFACE_INFO of wt_arsize : signal is "xilinx.com:interface:aximm:1.0 wt ARSIZE";
  attribute X_INTERFACE_INFO of wt_arburst : signal is "xilinx.com:interface:aximm:1.0 wt ARBURST";
  attribute X_INTERFACE_INFO of wt_arcache : signal is "xilinx.com:interface:aximm:1.0 wt ARCACHE";
  attribute X_INTERFACE_INFO of wt_arready : signal is "xilinx.com:interface:aximm:1.0 wt ARREADY";
  attribute X_INTERFACE_INFO of wt_rdata : signal is "xilinx.com:interface:aximm:1.0 wt RDATA";
  attribute X_INTERFACE_INFO of wt_rvalid : signal is "xilinx.com:interface:aximm:1.0 wt RVALID";
  attribute X_INTERFACE_INFO of wt_rlast : signal is "xilinx.com:interface:aximm:1.0 wt RLAST";
  attribute X_INTERFACE_INFO of wt_rresp : signal is "xilinx.com:interface:aximm:1.0 wt RRESP";
  attribute X_INTERFACE_INFO of wt_rready : signal is "xilinx.com:interface:aximm:1.0 wt RREADY";
  attribute X_INTERFACE_INFO of st_awaddr : signal is "xilinx.com:interface:aximm:1.0 st AWADDR";
  attribute X_INTERFACE_MODE of st_awaddr : signal is "master";
  attribute X_INTERFACE_PARAMETER of st_awaddr : signal is "XIL_INTERFACENAME st, DATA_WIDTH 128, PROTOCOL AXI4, FREQ_HZ 150079014, ID_WIDTH 0, ADDR_WIDTH 44, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE WRITE_ONLY, HAS_BURST 1, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 0, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN NPU_bd_clk_wiz_0_0_clk_out1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of st_awvalid : signal is "xilinx.com:interface:aximm:1.0 st AWVALID";
  attribute X_INTERFACE_INFO of st_awlen : signal is "xilinx.com:interface:aximm:1.0 st AWLEN";
  attribute X_INTERFACE_INFO of st_awsize : signal is "xilinx.com:interface:aximm:1.0 st AWSIZE";
  attribute X_INTERFACE_INFO of st_awburst : signal is "xilinx.com:interface:aximm:1.0 st AWBURST";
  attribute X_INTERFACE_INFO of st_awcache : signal is "xilinx.com:interface:aximm:1.0 st AWCACHE";
  attribute X_INTERFACE_INFO of st_awready : signal is "xilinx.com:interface:aximm:1.0 st AWREADY";
  attribute X_INTERFACE_INFO of st_wdata : signal is "xilinx.com:interface:aximm:1.0 st WDATA";
  attribute X_INTERFACE_INFO of st_wstrb : signal is "xilinx.com:interface:aximm:1.0 st WSTRB";
  attribute X_INTERFACE_INFO of st_wlast : signal is "xilinx.com:interface:aximm:1.0 st WLAST";
  attribute X_INTERFACE_INFO of st_wvalid : signal is "xilinx.com:interface:aximm:1.0 st WVALID";
  attribute X_INTERFACE_INFO of st_wready : signal is "xilinx.com:interface:aximm:1.0 st WREADY";
  attribute X_INTERFACE_INFO of st_bresp : signal is "xilinx.com:interface:aximm:1.0 st BRESP";
  attribute X_INTERFACE_INFO of st_bvalid : signal is "xilinx.com:interface:aximm:1.0 st BVALID";
  attribute X_INTERFACE_INFO of st_bready : signal is "xilinx.com:interface:aximm:1.0 st BREADY";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of stub : architecture is "NPU,Vivado 2025.2";
begin
end;
