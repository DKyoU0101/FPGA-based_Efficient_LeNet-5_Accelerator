//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Create Date:
// Design Name: slv_m00_axi_vip
// Module Name: slv_m00_axi_vip
// Project Name:
// Target Devices: Zybo Z7-20
// Tool Versions:
// Description: AXI VIP slave model wrapper
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module slv_m00_axi_vip #(
  parameter integer C_S_AXI_ID_WIDTH     = 1,
  parameter integer C_S_AXI_AWUSER_WIDTH = 1,
  parameter integer C_S_AXI_ARUSER_WIDTH = 1,
  parameter integer C_S_AXI_WUSER_WIDTH  = 1,
  parameter integer C_S_AXI_RUSER_WIDTH  = 1,
  parameter integer C_S_AXI_BUSER_WIDTH  = 1,
  parameter integer C_S_AXI_USER_VALUE   = 0,
  parameter integer C_S_AXI_PROT_VALUE   = 0,
  parameter integer C_S_AXI_CACHE_VALUE  = 3,
  parameter integer C_S_AXI_ADDR_WIDTH   = 32,  // Zybo Z7-20's Address Range.
  parameter integer C_S_AXI_DATA_WIDTH   = 64
)
(
  aclk,
  aresetn,
  s_axi_awvalid	,
  s_axi_awready	,
  s_axi_awaddr	,
  s_axi_awid	,
  s_axi_awlen	,
  s_axi_awsize	,
  s_axi_awburst	,
  s_axi_awlock	,
  s_axi_awcache	,
  s_axi_awprot	,
  s_axi_awqos	,
  s_axi_awregion,
  s_axi_awuser	,
  s_axi_wvalid	,
  s_axi_wready	,
  s_axi_wdata	,
  s_axi_wstrb	,
  s_axi_wlast	,
  s_axi_wid		,
  s_axi_wuser	,
  s_axi_arvalid	,
  s_axi_arready	,
  s_axi_araddr	,
  s_axi_arid	,
  s_axi_arlen	,
  s_axi_arsize	,
  s_axi_arburst	,
  s_axi_arlock	,
  s_axi_arcache	,
  s_axi_arprot	,
  s_axi_arqos	,
  s_axi_arregion,
  s_axi_aruser	,
  s_axi_rvalid	,
  s_axi_rready	,
  s_axi_rdata	,
  s_axi_rlast	,
  s_axi_rid		,
  s_axi_ruser	,
  s_axi_rresp	,
  s_axi_bvalid	,
  s_axi_bready	,
  s_axi_bresp	,
  s_axi_bid		,
  s_axi_buser	  	
);

input aclk;
input aresetn;

input  s_axi_awvalid                                   ;
output s_axi_awready                                   ;
input  [C_S_AXI_ADDR_WIDTH - 1:0]   	s_axi_awaddr   ;
input  [C_S_AXI_ID_WIDTH - 1:0]     	s_axi_awid     ;
input  [7:0]                          	s_axi_awlen    ;
input  [2:0]                          	s_axi_awsize   ;
input  [1:0]                          	s_axi_awburst  ;
input  [1:0]                          	s_axi_awlock   ;
input  [3:0]                          	s_axi_awcache  ;
input  [2:0]                          	s_axi_awprot   ;
input  [3:0]                          	s_axi_awqos    ;
input  [3:0]                          	s_axi_awregion ;
input  [C_S_AXI_AWUSER_WIDTH - 1:0] 	s_axi_awuser   ;
input  s_axi_wvalid                                    ;
output s_axi_wready                                    ;
input  [C_S_AXI_DATA_WIDTH - 1:0]   	s_axi_wdata    ;
input  [C_S_AXI_DATA_WIDTH/8 - 1:0] 	s_axi_wstrb    ;
input  s_axi_wlast                                     ;
input  [C_S_AXI_ID_WIDTH - 1:0]     	s_axi_wid      ;
input  [C_S_AXI_WUSER_WIDTH - 1:0]  	s_axi_wuser    ;
input  s_axi_arvalid                                   ;
output s_axi_arready                                   ;
input  [C_S_AXI_ADDR_WIDTH - 1:0]   	s_axi_araddr   ;
input  [C_S_AXI_ID_WIDTH - 1:0]     	s_axi_arid     ;
input  [7:0]                          	s_axi_arlen    ;
input  [2:0]                          	s_axi_arsize   ;
input  [1:0]                          	s_axi_arburst  ;
input  [1:0]                          	s_axi_arlock   ;
input  [3:0]                          	s_axi_arcache  ;
input  [2:0]                          	s_axi_arprot   ;
input  [3:0]                          	s_axi_arqos    ;
input  [3:0]                          	s_axi_arregion ;
input  [C_S_AXI_ARUSER_WIDTH - 1:0] 	s_axi_aruser   ;
output s_axi_rvalid                                    ;
input  s_axi_rready                                    ;
output [C_S_AXI_DATA_WIDTH - 1:0]    	s_axi_rdata    ;
output s_axi_rlast                                     ;
output [C_S_AXI_ID_WIDTH - 1:0]      	s_axi_rid      ;
output [C_S_AXI_RUSER_WIDTH - 1:0]   	s_axi_ruser    ;
output [1:0]                           	s_axi_rresp    ;
output s_axi_bvalid                                    ;
input  s_axi_bready                                    ;
output [1:0]                           	s_axi_bresp    ;
output [C_S_AXI_ID_WIDTH - 1:0]      	s_axi_bid      ;
output [C_S_AXI_BUSER_WIDTH - 1:0]   	s_axi_buser    ;

  axi_vip_v1_1_11_top #(
    .C_AXI_PROTOCOL(0),
    .C_AXI_INTERFACE_MODE(2),
    .C_AXI_ADDR_WIDTH(32),
    .C_AXI_WDATA_WIDTH(64),
    .C_AXI_RDATA_WIDTH(64),
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
    .C_AXI_HAS_BRESP(0),
    .C_AXI_HAS_RRESP(0),
    .C_AXI_HAS_ARESETN(1)
  ) inst (
    .aclk(aclk),
    .aclken(1'B1),
    .aresetn(aresetn),

	.s_axi_awvalid		( s_axi_awvalid		),
	.s_axi_awready		( s_axi_awready		),
	.s_axi_awaddr	 	( s_axi_awaddr		),
	.s_axi_awid			( s_axi_awid		),
	.s_axi_awlen	  	( s_axi_awlen		),
	.s_axi_awsize	  	( s_axi_awsize		),
	.s_axi_awburst		( s_axi_awburst		),
	.s_axi_awlock	  	( s_axi_awlock[0]	),
	.s_axi_awcache		( s_axi_awcache		),
	.s_axi_awprot	  	( s_axi_awprot		),
	.s_axi_awqos	  	( s_axi_awqos		),
	.s_axi_awregion		( s_axi_awregion	),
	.s_axi_awuser	  	( s_axi_awuser		),
	.s_axi_wvalid	  	( s_axi_wvalid		),
	.s_axi_wready	  	( s_axi_wready		),
	.s_axi_wdata	  	( s_axi_wdata		),
	.s_axi_wstrb	  	( s_axi_wstrb		),
	.s_axi_wlast	  	( s_axi_wlast		),
	.s_axi_wid			( s_axi_wid			),
	.s_axi_wuser	  	( s_axi_wuser		),
	.s_axi_arvalid		( s_axi_arvalid		),
	.s_axi_arready		( s_axi_arready		),
	.s_axi_araddr	  	( s_axi_araddr		),
	.s_axi_arid			( s_axi_arid		),
	.s_axi_arlen	  	( s_axi_arlen		),
	.s_axi_arsize	  	( s_axi_arsize		),
	.s_axi_arburst		( s_axi_arburst		),
	.s_axi_arlock	  	( s_axi_arlock[0]	),
	.s_axi_arcache		( s_axi_arcache		),
	.s_axi_arprot	  	( s_axi_arprot		),
	.s_axi_arqos	  	( s_axi_arqos		),
	.s_axi_arregion		( s_axi_arregion	),
	.s_axi_aruser	  	( s_axi_aruser	 	),
	.s_axi_rvalid	  	( s_axi_rvalid	 	),
	.s_axi_rready	  	( s_axi_rready	 	),
	.s_axi_rdata	  	( s_axi_rdata		),
	.s_axi_rlast	  	( s_axi_rlast		),
	.s_axi_rid			( s_axi_rid		 	),
	.s_axi_ruser	  	( s_axi_ruser		),
	.s_axi_rresp	  	( s_axi_rresp		),
	.s_axi_bvalid	  	( s_axi_bvalid	 	),
	.s_axi_bready	  	( s_axi_bready	 	),
	.s_axi_bresp	  	( s_axi_bresp		),
	.s_axi_bid			( s_axi_bid		 	),
	.s_axi_buser	  	( s_axi_buser		),
    .m_axi_awid(),
    .m_axi_awaddr(),
    .m_axi_awlen(),
    .m_axi_awsize(),
    .m_axi_awburst(),
    .m_axi_awlock(),
    .m_axi_awcache(),
    .m_axi_awprot(),
    .m_axi_awregion(),
    .m_axi_awqos(),
    .m_axi_awuser(),
    .m_axi_awvalid(),
    .m_axi_awready(1'B0),
    .m_axi_wid(),
    .m_axi_wdata(),
    .m_axi_wstrb(),
    .m_axi_wlast(),
    .m_axi_wuser(),
    .m_axi_wvalid(),
    .m_axi_wready(1'B0),
    .m_axi_bid(1'B0),
    .m_axi_bresp(2'B0),
    .m_axi_buser(1'B0),
    .m_axi_bvalid(1'B0),
    .m_axi_bready(),
    .m_axi_arid(),
    .m_axi_araddr(),
    .m_axi_arlen(),
    .m_axi_arsize(),
    .m_axi_arburst(),
    .m_axi_arlock(),
    .m_axi_arcache(),
    .m_axi_arprot(),
    .m_axi_arregion(),
    .m_axi_arqos(),
    .m_axi_aruser(),
    .m_axi_arvalid(),
    .m_axi_arready(1'B0),
    .m_axi_rid(1'B0),
    .m_axi_rdata(64'B0),
    .m_axi_rresp(2'B0),
    .m_axi_rlast(1'B0),
    .m_axi_ruser(1'B0),
    .m_axi_rvalid(1'B0),
    .m_axi_rready()
  );
endmodule
