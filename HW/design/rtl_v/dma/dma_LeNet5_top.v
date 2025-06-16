//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.05
// Design Name: LeNet-5
// Module Name: dma_LeNet5_top
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: 
// Dependencies: 
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

//`define BYPASS_RDMA_TO_WDMA_DATA
`timescale 1 ns / 1 ps
// Top level of the kernel. Do not modify module name, parameters or ports.
module dma_LeNet5_top #(
    parameter C_S_AXI_CONTROL_ADDR_WIDTH = 12,
    parameter C_S_AXI_CONTROL_DATA_WIDTH = 32,
    
    parameter C_M00_AXI_ID_WIDTH     = 1,
    parameter C_M00_AXI_AWUSER_WIDTH = 1,
    parameter C_M00_AXI_ARUSER_WIDTH = 1,
    parameter C_M00_AXI_WUSER_WIDTH  = 1,
    parameter C_M00_AXI_RUSER_WIDTH  = 1,
    parameter C_M00_AXI_BUSER_WIDTH  = 1,
    parameter C_M00_AXI_USER_VALUE   = 0,
    parameter C_M00_AXI_PROT_VALUE   = 0,
    parameter C_M00_AXI_CACHE_VALUE  = 3,
    parameter C_M00_AXI_ADDR_WIDTH   = 32,  // Zybo Z7-20's Address Range.
    parameter C_M00_AXI_DATA_WIDTH   = 64,
    
    parameter NUM_RD_INFMAP     = 256   , // B_C1_I_DATA_D
    parameter NUM_RD_PARAM      = 12502   , // NUM_RD_PARAM
    
    parameter MULT_DELAY    = 3   ,
    parameter ACC_DELAY_C   = 1   ,
    parameter ACC_DELAY_FC  = 0   ,
    parameter AB_DELAY      = 1   ,
    parameter I_F_BW        = 8   ,
    parameter W_BW          = 8   ,  
    parameter B_BW          = 16  ,
    parameter DATA_IDX_BW   = 20  
) (
  // System Signals
  input  wire                                    ap_clk               ,
  input  wire                                    ap_rst_n             ,

  // AXI4 master interface m00_axi
  output                                 			m00_axi_awvalid,
  input                                  			m00_axi_awready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   			m00_axi_awaddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_awid,
  output  [7:0]                          			m00_axi_awlen,
  output  [2:0]                          			m00_axi_awsize,
  output  [1:0]                          			m00_axi_awburst,
  output  [1:0]                          			m00_axi_awlock,
  output  [3:0]                          			m00_axi_awcache,
  output  [2:0]                          			m00_axi_awprot,
  output  [3:0]                          			m00_axi_awqos,
  output  [3:0]                          			m00_axi_awregion,
  output  [C_M00_AXI_AWUSER_WIDTH - 1:0] 			m00_axi_awuser,
  output                                 			m00_axi_wvalid,
  input                                  			m00_axi_wready,
  output  [C_M00_AXI_DATA_WIDTH - 1:0]   			m00_axi_wdata,
  output  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 			m00_axi_wstrb,
  output                                 			m00_axi_wlast,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_wid,
  output  [C_M00_AXI_WUSER_WIDTH - 1:0]  			m00_axi_wuser,
  output                                 			m00_axi_arvalid,
  input                                  			m00_axi_arready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   			m00_axi_araddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_arid,
  output  [7:0]                          			m00_axi_arlen,
  output  [2:0]                          			m00_axi_arsize,
  output  [1:0]                          			m00_axi_arburst,
  output  [1:0]                          			m00_axi_arlock,
  output  [3:0]                          			m00_axi_arcache,
  output  [2:0]                          			m00_axi_arprot,
  output  [3:0]                          			m00_axi_arqos,
  output  [3:0]                          			m00_axi_arregion,
  output  [C_M00_AXI_ARUSER_WIDTH - 1:0] 			m00_axi_aruser,
  input                                  			m00_axi_rvalid,
  output                                 			m00_axi_rready,
  input  [C_M00_AXI_DATA_WIDTH - 1:0]    			m00_axi_rdata,
  input                                  			m00_axi_rlast,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      			m00_axi_rid,
  input  [C_M00_AXI_RUSER_WIDTH - 1:0]   			m00_axi_ruser,
  input  [1:0]                           			m00_axi_rresp,
  input                                  			m00_axi_bvalid,
  output                                 			m00_axi_bready,
  input  [1:0]                           			m00_axi_bresp,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      			m00_axi_bid,
  input  [C_M00_AXI_BUSER_WIDTH - 1:0]   			m00_axi_buser,

  // AXI4-Lite slave interface
  input  wire                                    	s_axi_control_awvalid,
  output wire                                    	s_axi_control_awready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   	s_axi_control_awaddr ,
  input  wire                                    	s_axi_control_wvalid ,
  output wire                                    	s_axi_control_wready ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   	s_axi_control_wdata  ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] 	s_axi_control_wstrb  ,
  input  wire                                    	s_axi_control_arvalid,
  output wire                                    	s_axi_control_arready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   	s_axi_control_araddr ,
  output wire                                    	s_axi_control_rvalid ,
  input  wire                                    	s_axi_control_rready ,
  output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   	s_axi_control_rdata  ,
  output wire [2-1:0]                            	s_axi_control_rresp  ,
  output wire                                    	s_axi_control_bvalid ,
  input  wire                                    	s_axi_control_bready ,
  output wire [2-1:0]                            	s_axi_control_bresp  ,
  output wire                                    	interrupt            
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam C_ADDER_BIT_WIDTH = 8;

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
reg           areset                        ;
wire          ap_start_param                   ;
wire          ap_start_infmap                  ;
wire          ap_idle                       ;
wire          ap_done                       ;
wire          ap_ready                      ;
wire          ap_wdma_done                      ;
wire [32-1:0] rdma_param_ptr                  ;
wire [32-1:0] rdma_infmap_ptr                  ;
// wire [32-1:0] wdma_transfer_byte            ;
wire [32-1:0] wdma_mem_ptr                  ;
wire [32-1:0] axi00_ptr0                    ;
// wire [32-1:0] value_to_add                  ;

// Stream I/F TODO use core
wire [C_M00_AXI_DATA_WIDTH-1:0] out_r_din		                ;
wire                            out_r_full_n		            ;
wire                            out_r_write		                ;
wire [C_M00_AXI_DATA_WIDTH-1:0] in_r_dout		                ;
wire                            in_r_empty_n		            ;
wire                            in_r_read		                ;

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

///////////////////////////////////////////////////////////////////////////////
// Begin control interface RTL.  Modifying not recommended.
///////////////////////////////////////////////////////////////////////////////

// AXI4-Lite slave interface
dma_ip_control_s_axi #(
  .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
) u_dma_ip_control_s_axi (
    .ACLK                 (ap_clk ) ,
    .ARESET               (areset ) ,
    .ACLK_EN              (1'b1   ) ,
    .i_AWADDR             (s_axi_control_awaddr  ) ,
    .i_AWVALID            (s_axi_control_awvalid ) ,
    .o_AWREADY            (s_axi_control_awready ) ,
    .i_WDATA              (s_axi_control_wdata   ) ,
    .i_WSTRB              (s_axi_control_wstrb   ) ,
    .i_WVALID             (s_axi_control_wvalid  ) ,
    .o_WREADY             (s_axi_control_wready  ) ,
    .o_BRESP              (s_axi_control_bresp   ) ,
    .o_BVALID             (s_axi_control_bvalid  ) ,
    .i_BREADY             (s_axi_control_bready  ) ,
    .i_ARADDR             (s_axi_control_araddr  ) ,
    .i_ARVALID            (s_axi_control_arvalid ) ,
    .o_ARREADY            (s_axi_control_arready ) ,
    .o_RDATA              (s_axi_control_rdata   ) ,
    .o_RRESP              (s_axi_control_rresp   ) ,
    .o_RVALID             (s_axi_control_rvalid  ) ,
    .i_RREADY             (s_axi_control_rready  ) ,
    .o_interrupt          (interrupt             ) ,
    .o_rdma_param_ptr     (rdma_param_ptr          ) ,
    .o_rdma_infmap_ptr    (rdma_infmap_ptr          ) ,
    // .o_wdma_transfer_byte (wdma_transfer_byte    ) ,
    .o_wdma_mem_ptr       (wdma_mem_ptr          ) ,
    .o_axi00_ptr0         (axi00_ptr0            ) ,
    // .o_value_to_add       (value_to_add          ) ,
    .o_ap_start_param     (ap_start_param           ) ,
    .o_ap_start_infmap    (ap_start_infmap          ) ,
    .i_ap_done            (ap_done               ) ,
    .i_ap_ready           (ap_ready              ) ,
    .i_ap_idle            (ap_idle               ) ,
    .i_ap_wdma_done       (ap_wdma_done              )
);         

wire [C_M00_AXI_DATA_WIDTH-1:0] 		w_in_r_dout		    ;
wire 				                w_in_r_empty_n      ;
wire				                w_in_r_read		    ;
	
// matbi_dma_wrapper #(
dma_wrapper #(
  .C_M00_AXI_ID_WIDTH 		(C_M00_AXI_ID_WIDTH    ),
  .C_M00_AXI_AWUSER_WIDTH 	(C_M00_AXI_AWUSER_WIDTH),
  .C_M00_AXI_ARUSER_WIDTH 	(C_M00_AXI_ARUSER_WIDTH),
  .C_M00_AXI_WUSER_WIDTH 	(C_M00_AXI_WUSER_WIDTH ),
  .C_M00_AXI_RUSER_WIDTH 	(C_M00_AXI_RUSER_WIDTH ),
  .C_M00_AXI_BUSER_WIDTH 	(C_M00_AXI_BUSER_WIDTH ),
  .C_M00_AXI_USER_VALUE 	(C_M00_AXI_USER_VALUE  ),
  .C_M00_AXI_PROT_VALUE 	(C_M00_AXI_PROT_VALUE  ),
  .C_M00_AXI_CACHE_VALUE 	(C_M00_AXI_CACHE_VALUE ),
  .C_M00_AXI_ADDR_WIDTH 	( C_M00_AXI_ADDR_WIDTH ),
  .C_M00_AXI_DATA_WIDTH 	( C_M00_AXI_DATA_WIDTH ),
  .NUM_RD_INFMAP 	( NUM_RD_INFMAP ),
  .NUM_RD_PARAM  	( NUM_RD_PARAM  )
) u_dma_wrapper (
  .ap_clk             ( ap_clk                ),
  .ap_rst_n           ( ap_rst_n              ),
  .m00_axi_awvalid	  ( m00_axi_awvalid		  ),
  .m00_axi_awready	  ( m00_axi_awready		  ),
  .m00_axi_awaddr	  ( m00_axi_awaddr		  ),
  .m00_axi_awid		  ( m00_axi_awid		  ),
  .m00_axi_awlen	  ( m00_axi_awlen		  ),
  .m00_axi_awsize	  ( m00_axi_awsize		  ),
  .m00_axi_awburst	  ( m00_axi_awburst		  ),
  .m00_axi_awlock	  ( m00_axi_awlock		  ),
  .m00_axi_awcache	  ( m00_axi_awcache		  ),
  .m00_axi_awprot	  ( m00_axi_awprot		  ),
  .m00_axi_awqos	  ( m00_axi_awqos		  ),
  .m00_axi_awregion	  ( m00_axi_awregion	  ),
  .m00_axi_awuser	  ( m00_axi_awuser		  ),
  .m00_axi_wvalid	  ( m00_axi_wvalid		  ),
  .m00_axi_wready	  ( m00_axi_wready		  ),
  .m00_axi_wdata	  ( m00_axi_wdata		  ),
  .m00_axi_wstrb	  ( m00_axi_wstrb		  ),
  .m00_axi_wlast	  ( m00_axi_wlast		  ),
  .m00_axi_wid		  ( m00_axi_wid			  ),
  .m00_axi_wuser	  ( m00_axi_wuser		  ),
  .m00_axi_arvalid	  ( m00_axi_arvalid		  ),
  .m00_axi_arready	  ( m00_axi_arready		  ),
  .m00_axi_araddr	  ( m00_axi_araddr		  ),
  .m00_axi_arid		  ( m00_axi_arid		  ),
  .m00_axi_arlen	  ( m00_axi_arlen		  ),
  .m00_axi_arsize	  ( m00_axi_arsize		  ),
  .m00_axi_arburst	  ( m00_axi_arburst		  ),
  .m00_axi_arlock	  ( m00_axi_arlock		  ),
  .m00_axi_arcache	  ( m00_axi_arcache		  ),
  .m00_axi_arprot	  ( m00_axi_arprot		  ),
  .m00_axi_arqos	  ( m00_axi_arqos		  ),
  .m00_axi_arregion	  ( m00_axi_arregion	  ),
  .m00_axi_aruser	  ( m00_axi_aruser		  ),
  .m00_axi_rvalid	  ( m00_axi_rvalid		  ),
  .m00_axi_rready	  ( m00_axi_rready		  ),
  .m00_axi_rdata	  ( m00_axi_rdata		  ),
  .m00_axi_rlast	  ( m00_axi_rlast		  ),
  .m00_axi_rid		  ( m00_axi_rid			  ),
  .m00_axi_ruser	  ( m00_axi_ruser		  ),
  .m00_axi_rresp	  ( m00_axi_rresp		  ),
  .m00_axi_bvalid	  ( m00_axi_bvalid		  ),
  .m00_axi_bready	  ( m00_axi_bready		  ),
  .m00_axi_bresp	  ( m00_axi_bresp		  ),
  .m00_axi_bid		  ( m00_axi_bid			  ),
  .m00_axi_buser	  ( m00_axi_buser		  ),
  .ap_start_param     ( ap_start_param        ),
  .ap_start_infmap    ( ap_start_infmap       ),
  .ap_start_wdma      ( w_in_r_empty_n           ),
  .ap_done            ( ap_done               ),
  .ap_idle            ( ap_idle               ),
  .ap_ready           ( ap_ready              ),
  .ap_wdma_done       ( ap_wdma_done              ),
  .rdma_param_ptr       ( rdma_param_ptr          ),
  .rdma_infmap_ptr       ( rdma_infmap_ptr          ),
//   .wdma_transfer_byte ( wdma_transfer_byte    ),
  .wdma_mem_ptr       ( wdma_mem_ptr          ),
  .axi00_ptr0         ( axi00_ptr0            ),
// stream I/F
  .out_r_din          ( out_r_din             ),
  .out_r_full_n       ( out_r_full_n          ),
  .out_r_write        ( out_r_write           ),
  .out_r_rd_param     ( out_r_rd_param        ),
  .out_r_rd_infmap    ( out_r_rd_infmap       ),
  .in_r_dout          ( in_r_dout             ),
  .in_r_empty_n       ( in_r_empty_n          ),
  .in_r_read          ( in_r_read             )
  );

`ifdef BYPASS_RDMA_TO_WDMA_DATA
sync_fifo #(
    .FIFO_S_REG (1 ) ,
    .FIFO_M_REG (1 ) ,
    .FIFO_W     (C_M00_AXI_DATA_WIDTH     ) ,
    .FIFO_D     (8     ) 
) u_sync_fifo (
    .clk       (ap_clk       ) ,
    .areset    (areset   ) ,
    .i_s_valid (out_r_write ) ,
    .o_s_ready (out_r_full_n    ) ,
    .i_s_data  (out_r_din       ) ,
    .o_m_valid (in_r_empty_n    ) ,
    .i_m_ready (in_r_read       ) ,
    .o_m_data  (in_r_dout	    ) ,
    .o_empty   (   ) ,
    .o_full    (    ) 
);

`else // If you use core, you'll fill code here~~
// TODO

LeNet5_core_ip #(
    .C_NUM_CLOCKS       ( 1                  ) ,
    .C_AXIS_S_DATA_WIDTH ( C_M00_AXI_DATA_WIDTH ) ,
    .C_AXIS_S_USER_WIDTH ( 8 ) ,
    .C_AXIS_M_DATA_WIDTH ( C_M00_AXI_DATA_WIDTH ) ,
    .MULT_DELAY       (MULT_DELAY    ) ,
    .ACC_DELAY_C      (ACC_DELAY_C   ) ,
    .ACC_DELAY_FC     (ACC_DELAY_FC  ) ,
    .AB_DELAY         (AB_DELAY      ) ,
    .I_F_BW           (I_F_BW        ) ,
    .W_BW             (W_BW          ) ,
    .B_BW             (B_BW          ) ,
    .DATA_IDX_BW      (DATA_IDX_BW   ) 
) u_LeNet5_core_ip  (
  .s_axis_aclk   ( ap_clk                   		) ,
  .s_axis_areset ( areset                   		) ,
//   .ctrl_constant ( value_to_add[C_ADDER_BIT_WIDTH-1:0]) ,
  .s_axis_tvalid ( out_r_write              		) ,
  .s_axis_tready ( out_r_full_n             		) ,
  .s_axis_tdata  ( out_r_din                		) ,
  .s_axis_tkeep	 ( 'b0								),
  .s_axis_tstrb	 ( {C_M00_AXI_DATA_WIDTH/8{1'b1}}	),
  .s_axis_tlast	 ( 'b0								),
  .s_axis_tid	 ( 'b0								),
  .s_axis_tdest	 ( 'b0								),
  .s_axis_tuser	 ( {6'b0, out_r_rd_infmap, out_r_rd_param}	),

  .m_axis_aclk   ( ap_clk                   		),
  .m_axis_tvalid ( w_in_r_empty_n             		),
  .m_axis_tready ( w_in_r_read	             		),
  .m_axis_tdata  ( w_in_r_dout                		),
  // unused signals
  .m_axis_tkeep	 (									),
  .m_axis_tstrb	 (									),
  .m_axis_tlast	 (									),
  .m_axis_tid	 (									),
  .m_axis_tdest	 (									),
  .m_axis_tuser	 (									)

);

sync_fifo #(
    .FIFO_S_REG (1 ) ,
    .FIFO_M_REG (1 ) ,
    .FIFO_W     (C_M00_AXI_DATA_WIDTH     ) ,
    .FIFO_D     (8     ) 
) u_sync_fifo (
    .clk       (ap_clk       ) ,
    .areset    (areset   ) ,
    .i_s_valid (w_in_r_empty_n	) ,
    .o_s_ready (w_in_r_read	) ,
    .i_s_data  (w_in_r_dout	) ,
    .o_m_valid (in_r_empty_n	) ,
    .i_m_ready (in_r_read		) ,
    .o_m_data  (in_r_dout		) ,
    .o_empty   (   ) ,
    .o_full    (    ) 
);

`endif

endmodule
