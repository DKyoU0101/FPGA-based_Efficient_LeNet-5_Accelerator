//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.05
// Design Name: 
// Module Name: control_dma_ip_vip
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: 
// Dependencies: 
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module control_dma_ip_vip (
  aclk,
  aresetn,
  m_axi_awaddr,
  m_axi_awvalid,
  m_axi_awready,
  m_axi_wdata,
  m_axi_wstrb,
  m_axi_wvalid,
  m_axi_wready,
  m_axi_bresp,
  m_axi_bvalid,
  m_axi_bready,
  m_axi_araddr,
  m_axi_arvalid,
  m_axi_arready,
  m_axi_rdata,
  m_axi_rresp,
  m_axi_rvalid,
  m_axi_rready
);

input wire aclk;
input wire aresetn;
output wire [11 : 0] m_axi_awaddr;
output wire m_axi_awvalid;
input wire m_axi_awready;
output wire [31 : 0] m_axi_wdata;
output wire [3 : 0] m_axi_wstrb;
output wire m_axi_wvalid;
input wire m_axi_wready;
input wire [1 : 0] m_axi_bresp;
input wire m_axi_bvalid;
output wire m_axi_bready;
output wire [11 : 0] m_axi_araddr;
output wire m_axi_arvalid;
input wire m_axi_arready;
input wire [31 : 0] m_axi_rdata;
input wire [1 : 0] m_axi_rresp;
input wire m_axi_rvalid;
output wire m_axi_rready;

  axi_vip_v1_1_11_top #(
    .C_AXI_PROTOCOL(2),
    .C_AXI_INTERFACE_MODE(0),
    .C_AXI_ADDR_WIDTH(12),
    .C_AXI_WDATA_WIDTH(32),
    .C_AXI_RDATA_WIDTH(32),
    .C_AXI_WID_WIDTH(0),
    .C_AXI_RID_WIDTH(0),
    .C_AXI_AWUSER_WIDTH(0),
    .C_AXI_ARUSER_WIDTH(0),
    .C_AXI_WUSER_WIDTH(0),
    .C_AXI_RUSER_WIDTH(0),
    .C_AXI_BUSER_WIDTH(0),
    .C_AXI_SUPPORTS_NARROW(0),
    .C_AXI_HAS_BURST(0),
    .C_AXI_HAS_LOCK(0),
    .C_AXI_HAS_CACHE(0),
    .C_AXI_HAS_REGION(0),
    .C_AXI_HAS_PROT(0),
    .C_AXI_HAS_QOS(0),
    .C_AXI_HAS_WSTRB(1),
    .C_AXI_HAS_BRESP(1),
    .C_AXI_HAS_RRESP(1),
    .C_AXI_HAS_ARESETN(1)
  ) inst (
    .aclk(aclk),
    .aclken(1'B1),
    .aresetn(aresetn),
    .s_axi_awid(1'B0),
    .s_axi_awaddr(12'B0),
    .s_axi_awlen(8'B0),
    .s_axi_awsize(3'B0),
    .s_axi_awburst(2'B1),
    .s_axi_awlock(1'B0),
    .s_axi_awcache(4'B0),
    .s_axi_awprot(3'B0),
    .s_axi_awregion(4'B0),
    .s_axi_awqos(4'B0),
    .s_axi_awuser(1'B0),
    .s_axi_awvalid(1'B0),
    .s_axi_awready(),
    .s_axi_wid(1'B0),
    .s_axi_wdata(32'B0),
    .s_axi_wstrb(4'HF),
    .s_axi_wlast(1'B0),
    .s_axi_wuser(1'B0),
    .s_axi_wvalid(1'B0),
    .s_axi_wready(),
    .s_axi_bid(),
    .s_axi_bresp(),
    .s_axi_buser(),
    .s_axi_bvalid(),
    .s_axi_bready(1'B0),
    .s_axi_arid(1'B0),
    .s_axi_araddr(12'B0),
    .s_axi_arlen(8'B0),
    .s_axi_arsize(3'B0),
    .s_axi_arburst(2'B1),
    .s_axi_arlock(1'B0),
    .s_axi_arcache(4'B0),
    .s_axi_arprot(3'B0),
    .s_axi_arregion(4'B0),
    .s_axi_arqos(4'B0),
    .s_axi_aruser(1'B0),
    .s_axi_arvalid(1'B0),
    .s_axi_arready(),
    .s_axi_rid(),
    .s_axi_rdata(),
    .s_axi_rresp(),
    .s_axi_rlast(),
    .s_axi_ruser(),
    .s_axi_rvalid(),
    .s_axi_rready(1'B0),
    .m_axi_awid(),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(),
    .m_axi_awsize(),
    .m_axi_awburst(),
    .m_axi_awlock(),
    .m_axi_awcache(),
    .m_axi_awprot(),
    .m_axi_awregion(),
    .m_axi_awqos(),
    .m_axi_awuser(),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wid(),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(),
    .m_axi_wuser(),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(1'B0),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_buser(1'B0),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(),
    .m_axi_arsize(),
    .m_axi_arburst(),
    .m_axi_arlock(),
    .m_axi_arcache(),
    .m_axi_arprot(),
    .m_axi_arregion(),
    .m_axi_arqos(),
    .m_axi_aruser(),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(1'B0),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(1'B0),
    .m_axi_ruser(1'B0),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready)
  );
endmodule
