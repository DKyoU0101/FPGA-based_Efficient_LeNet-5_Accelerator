//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.04
// Design Name: 
// Module Name: dma_wrapper
// Project Name: chapter20
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: RDMA
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module dma_wrapper #(
  parameter integer C_M00_AXI_ID_WIDTH = 1,
  parameter integer C_M00_AXI_AWUSER_WIDTH = 1,
  parameter integer C_M00_AXI_ARUSER_WIDTH = 1,
  parameter integer C_M00_AXI_WUSER_WIDTH = 1,
  parameter integer C_M00_AXI_RUSER_WIDTH = 1,
  parameter integer C_M00_AXI_BUSER_WIDTH = 1,
  parameter integer C_M00_AXI_USER_VALUE = 0,
  parameter integer C_M00_AXI_PROT_VALUE = 0,
  parameter integer C_M00_AXI_CACHE_VALUE = 3,
  parameter integer C_M00_AXI_ADDR_WIDTH = 32,
  parameter integer C_M00_AXI_DATA_WIDTH = 32,
  parameter integer NUM_RD_INFMAP    = 1,
  parameter integer NUM_RD_PARAM     = 1
)
(
  // System Signals
  input                                		ap_clk            ,
  input                                		ap_rst_n          ,
    // AXI4 master interface m00_axi
  output                                 	m00_axi_awvalid,
  input                                  	m00_axi_awready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_awaddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_awid,
  output  [7:0]                          	m00_axi_awlen,
  output  [2:0]                          	m00_axi_awsize,
  output  [1:0]                          	m00_axi_awburst,
  output  [1:0]                          	m00_axi_awlock,
  output  [3:0]                          	m00_axi_awcache,
  output  [2:0]                          	m00_axi_awprot,
  output  [3:0]                          	m00_axi_awqos,
  output  [3:0]                          	m00_axi_awregion,
  output  [C_M00_AXI_AWUSER_WIDTH - 1:0] 	m00_axi_awuser,
  output                                 	m00_axi_wvalid,
  input                                  	m00_axi_wready,
  output  [C_M00_AXI_DATA_WIDTH - 1:0]   	m00_axi_wdata,
  output  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 	m00_axi_wstrb,
  output                                 	m00_axi_wlast,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_wid,
  output  [C_M00_AXI_WUSER_WIDTH - 1:0]  	m00_axi_wuser,
  output                                 	m00_axi_arvalid,
  input                                  	m00_axi_arready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_araddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_arid,
  output  [7:0]                          	m00_axi_arlen,
  output  [2:0]                          	m00_axi_arsize,
  output  [1:0]                          	m00_axi_arburst,
  output  [1:0]                          	m00_axi_arlock,
  output  [3:0]                          	m00_axi_arcache,
  output  [2:0]                          	m00_axi_arprot,
  output  [3:0]                          	m00_axi_arqos,
  output  [3:0]                          	m00_axi_arregion,
  output  [C_M00_AXI_ARUSER_WIDTH - 1:0] 	m00_axi_aruser,
  input                                  	m00_axi_rvalid,
  output                                 	m00_axi_rready,
  input  [C_M00_AXI_DATA_WIDTH - 1:0]    	m00_axi_rdata,
  input                                  	m00_axi_rlast,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_rid,
  input  [C_M00_AXI_RUSER_WIDTH - 1:0]   	m00_axi_ruser,
  input  [1:0]                           	m00_axi_rresp,
  input                                  	m00_axi_bvalid,
  output                                 	m00_axi_bready,
  input  [1:0]                           	m00_axi_bresp,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_bid,
  input  [C_M00_AXI_BUSER_WIDTH - 1:0]   	m00_axi_buser,

  // Control Signals
  input                               		ap_start_param    ,
  input                               		ap_start_infmap   ,
  input                               		ap_start_wdma     ,
  output                              		ap_idle           ,
  output                              		ap_done           ,
  output                              		ap_ready          ,
  output                              		ap_wdma_done          ,
  input  [32-1:0]                     		rdma_param_ptr      ,
  input  [32-1:0]                     		rdma_infmap_ptr      ,
//   input  [32-1:0]                     		wdma_transfer_byte,
  input  [32-1:0]                     		wdma_mem_ptr      ,
  input  [32-1:0]                     		axi00_ptr0        ,

// Stream from RDMA
  output  [C_M00_AXI_DATA_WIDTH-1:0] 		out_r_din		 ,
  input   							   		out_r_full_n	 ,
  output   							   		out_r_write		 ,
  output   							   		out_r_rd_param    ,
  output   							   		out_r_rd_infmap   ,
// Stream to WDMA
  input   [C_M00_AXI_DATA_WIDTH-1:0] 		in_r_dout		 , 
  input   							   		in_r_empty_n	 , 
  output 							   		in_r_read		   
);

reg areset 		= 1'b0;

reg r_ap_rd_cnn_param = 1'b0;
reg r_ap_infmap_valid = 1'b0;
reg r_ap_wr_wdma      = 1'b0;

wire ap_start_param_pulse  ;
wire ap_start_infmap_pulse ;
wire ap_start_wdma_pulse ;

wire  ap_done_rdma	;
wire  ap_idle_rdma	;
wire  ap_ready_rdma	;

wire  ap_done_wdma	; // no use
wire  ap_idle_wdma	; // no use
wire  ap_ready_wdma	; // no use

// make ap_ctrl_sig
// after power on, initial value is 0;\
reg   r_ap_start_param  = 1'b0;
reg   r_ap_start_infmap = 1'b0;
reg   r_ap_start_wdma	= 1'b0;

// Register and invert reset signal.
always @(posedge ap_clk) begin
	areset <= ~ap_rst_n;
end

// create pulse when ap_start transitions to 1
always @(posedge ap_clk) begin
  	begin
    	r_ap_start_param  <= ap_start_param  ;
    	r_ap_start_infmap <= ap_start_infmap ;
    	r_ap_start_wdma   <= ap_start_wdma ;
  	end
end

assign ap_start_param_pulse  = ap_start_param  & (~r_ap_start_param );
assign ap_start_infmap_pulse = ap_start_infmap & (~r_ap_start_infmap);
assign ap_start_wdma_pulse   = ap_start_wdma   & (~r_ap_start_wdma  );

always @(posedge ap_clk) begin
	if (areset) begin
		r_ap_rd_cnn_param <= 1'b0;
	end else if (ap_start_param_pulse) begin
		r_ap_rd_cnn_param <= 1'b1;
	end else if (ap_ready_rdma) begin
		r_ap_rd_cnn_param <= 1'b0;
  	end
end
always @(posedge ap_clk) begin
	if (areset) begin
		r_ap_infmap_valid <= 1'b0;
	end else if (ap_start_infmap_pulse) begin
		r_ap_infmap_valid <= 1'b1;
	end else if (ap_ready_rdma) begin
		r_ap_infmap_valid <= 1'b0;
  	end
end

always @(posedge ap_clk) begin
	if (areset) begin
		r_ap_wr_wdma <= 1'b0;
	end else if (ap_start_wdma_pulse) begin
		r_ap_wr_wdma <= 1'b1;
	end else if (ap_ready_wdma) begin
		r_ap_wr_wdma <= 1'b0;
  	end
end

assign ap_idle	= ap_idle_rdma;          
assign ap_done	= ap_done_rdma;
assign ap_ready = ap_ready_rdma;          
assign ap_wdma_done = ap_done_wdma;          

rdma #(
    .C_M_AXI_ID_W      (C_M00_AXI_ID_WIDTH     ) ,
    .C_M_AXI_ADDR_W    (C_M00_AXI_ADDR_WIDTH   ) ,
    .C_M_AXI_DATA_W    (C_M00_AXI_DATA_WIDTH   ) ,
    .C_M_AXI_AR_USER_W (C_M00_AXI_ARUSER_WIDTH ) ,
    .C_M_AXI_R_USER_W  (C_M00_AXI_RUSER_WIDTH  ) ,
    .NUM_RD_INFMAP  (NUM_RD_INFMAP  ) ,
    .NUM_RD_PARAM   (NUM_RD_PARAM   ) 
) u_rdma (
	.ap_clk						(ap_clk				),
	.ap_rst_n					(ap_rst_n			),
	.i_ap_rd_cnn_param			(r_ap_rd_cnn_param	),
	.i_ap_infmap_valid			(r_ap_infmap_valid	),
	.o_ap_done 					(ap_done_rdma		),
	.o_ap_idle 					(ap_idle_rdma		),
	.o_ap_ready					(ap_ready_rdma		),
    
	.o_m_axi_AR_VALID   		(m00_axi_arvalid	),
	.i_m_axi_AR_READY   		(m00_axi_arready	),
	.o_m_axi_AR_ADDR    		(m00_axi_araddr		),
	.o_m_axi_AR_ID      		(m00_axi_arid		),
	.o_m_axi_AR_LEN     		(m00_axi_arlen		),
	.o_m_axi_AR_SIZE    		(m00_axi_arsize		),
	.o_m_axi_AR_BURST   		(m00_axi_arburst	),
	.o_m_axi_AR_LOCK    		(m00_axi_arlock		),
	.o_m_axi_AR_CACHE   		(m00_axi_arcache	),
	.o_m_axi_AR_PROT    		(m00_axi_arprot		),
	.o_m_axi_AR_QOS     		(m00_axi_arqos		),
	.o_m_axi_AR_REGION  		(m00_axi_arregion	),
	.o_m_axi_AR_USER    		(m00_axi_aruser		),
    
	.i_m_axi_R_VALID    		(m00_axi_rvalid		),
	.o_m_axi_R_READY    		(m00_axi_rready		),
	.i_m_axi_R_DATA     		(m00_axi_rdata		),
	.i_m_axi_R_LAST     		(m00_axi_rlast		),
	.i_m_axi_R_ID       		('b0				),
	.i_m_axi_R_USER     		('b0				),
	.i_m_axi_R_RESP     		('b0				),

	.i_param_baseaddr 			(rdma_param_ptr		),
	.i_infmap_baseaddr 			(rdma_infmap_ptr		),
	.o_r_din        			(out_r_din			),
	.i_r_full_n     			(out_r_full_n		),
	.o_r_write      			(out_r_write		),
    
    .o_r_rd_param               (out_r_rd_param  ),
    .o_r_rd_infmap              (out_r_rd_infmap )
);

wdma #(
    .C_M_AXI_ID_W      (C_M00_AXI_ID_WIDTH     ) ,
    .C_M_AXI_ADDR_W    (C_M00_AXI_ADDR_WIDTH   ) ,
    .C_M_AXI_DATA_W    (C_M00_AXI_DATA_WIDTH   ) ,
    .C_M_AXI_AW_USER_W (C_M00_AXI_AWUSER_WIDTH ) ,
    .C_M_AXI_W_USER_W  (C_M00_AXI_WUSER_WIDTH  ) ,
    .C_M_AXI_B_USER_W  (C_M00_AXI_BUSER_WIDTH  ) 
) u_wdma (
	.ap_clk						(ap_clk				),
	.ap_rst_n					(ap_rst_n			),
	.i_ap_start 				(r_ap_wr_wdma	),
	.o_ap_done  				(ap_done_wdma		),
	.o_ap_idle  				(ap_idle_wdma		),
	.o_ap_ready 				(ap_ready_wdma		),

	.o_m_axi_AW_VALID   		(m00_axi_awvalid	),
	.i_m_axi_AW_READY   		(m00_axi_awready	),
	.o_m_axi_AW_ADDR    		(m00_axi_awaddr		),
	.o_m_axi_AW_ID      		(m00_axi_awid		),
	.o_m_axi_AW_LEN     		(m00_axi_awlen		),
	.o_m_axi_AW_SIZE    		(m00_axi_awsize		),
	.o_m_axi_AW_BURST   		(m00_axi_awburst	),
	.o_m_axi_AW_LOCK    		(m00_axi_awlock		),
	.o_m_axi_AW_CACHE   		(m00_axi_awcache	),
	.o_m_axi_AW_PROT    		(m00_axi_awprot		),
	.o_m_axi_AW_QOS     		(m00_axi_awqos		),
	.o_m_axi_AW_REGION  		(m00_axi_awregion	),
	.o_m_axi_AW_USER    		(m00_axi_awuser		),
    
	.o_m_axi_W_VALID    		(m00_axi_wvalid		),
	.i_m_axi_W_READY    		(m00_axi_wready		),
	.o_m_axi_W_DATA     		(m00_axi_wdata		),
	.o_m_axi_W_STRB     		(m00_axi_wstrb		),
	.o_m_axi_W_LAST     		(m00_axi_wlast		),
	.o_m_axi_W_ID       		(m00_axi_wid		),
	.o_m_axi_W_USER     		(m00_axi_wuser		),

	.i_m_axi_B_VALID    		(m00_axi_bvalid		),
	.o_m_axi_W_READY    		(m00_axi_bready		),
	.i_m_axi_B_RESP     		(m00_axi_bresp		),
	.i_m_axi_B_ID       		(m00_axi_bid	 	),
	.i_m_axi_B_USER     		(m00_axi_buser		),
	// .i_transfer_byte			(wdma_transfer_byte	),
	.i_mem_baseaddr 			(wdma_mem_ptr		),
	.i_r_dout       			(in_r_dout			),
	.i_r_empty_n    			(in_r_empty_n		),
	.o_r_read       			(in_r_read			)
);

endmodule