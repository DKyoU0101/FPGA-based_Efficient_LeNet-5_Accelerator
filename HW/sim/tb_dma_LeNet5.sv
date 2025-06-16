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

`timescale 1 ns / 10 ps
import axi_vip_pkg::*;
import slv_m00_axi_vip_pkg::*;
import control_dma_ip_vip_pkg::*;

module tb_dma_LeNet5 ();

`include "defines_parameter_LeNet5.vh"

//==============================================================================
// Testbench Parameter declaration
//==============================================================================
    parameter C_S_AXI_CONTROL_ADDR_WIDTH      = 12;
    parameter C_S_AXI_CONTROL_DATA_WIDTH      = 32;
    parameter C_M00_AXI_ADDR_WIDTH            = 32;
    parameter C_M00_AXI_DATA_WIDTH            = 64; // do not change 48
    parameter C_M00_AXI_DATA_WIDTH_BYTE       = C_M00_AXI_DATA_WIDTH/8;
    parameter C_M00_AXI_DATA_WIDTH_BYTE_LOG   = $clog2(C_M00_AXI_DATA_WIDTH_BYTE);
    parameter C_M00_AXI_ID_WIDTH     = 1;
    parameter C_M00_AXI_AWUSER_WIDTH = 1;
    parameter C_M00_AXI_ARUSER_WIDTH = 1;
    parameter C_M00_AXI_WUSER_WIDTH  = 1;
    parameter C_M00_AXI_RUSER_WIDTH  = 1;
    parameter C_M00_AXI_BUSER_WIDTH  = 1;
    parameter C_M00_AXI_USER_VALUE   = 0;
    parameter C_M00_AXI_PROT_VALUE   = 0;
    parameter C_M00_AXI_CACHE_VALUE  = 3;
    
    
    // User input Param
    parameter USER_RDMA_INFMAP_ADDR              = 32'd0;
    parameter USER_WDMA_MEM_ADDR                 = 32'd1024; 
    parameter USER_RDMA_PARAM_ADDR               = USER_WDMA_MEM_ADDR + (`LOOP_NUM*8); 
    
    // DMA IP REG MAP
    parameter ADDR_AP_CTRL                    = 6'h00;
    parameter ADDR_GIE                        = 6'h04;
    parameter ADDR_IER                        = 6'h08;
    parameter ADDR_ISR                        = 6'h0c;
    parameter ADDR_RDMA_MEM_PTR_PARAM_0       = 6'h14;
    parameter ADDR_RDMA_MEM_PTR_INFMAP_0      = 6'h18;
    // parameter ADDR_WDMA_TRANSFER_BYTE_DATA_0  = 6'h18;
    parameter ADDR_WDMA_MEM_PTR_DATA_0        = 6'h1c;
    parameter ADDR_AXI00_PTR0_DATA_0          = 6'h20;
    // parameter ADDR_VALUE_TO_ADD	           	  = 6'h24;
    
    // Control Register
    parameter KRNL_CTRL_REG_ADDR              = 32'h00000000;
    parameter CTRL_START_PARAM_MASK           = 32'h00000001;
    parameter CTRL_DONE_MASK                  = 32'h00000002;
    parameter CTRL_IDLE_MASK                  = 32'h00000004;
    parameter CTRL_READY_MASK                 = 32'h00000008;
    parameter CTRL_START_INFMAP_MASK          = 32'h00000010;
    parameter CTRL_DONE_WDMA_MASK             = 32'h00000020;
    parameter CTRL_AUTO_RESTART_MASK          = 32'h00000080; // Not used
    
    parameter LP_CLK_PERIOD_PS = 10; // 100 MHz

//==============================================================================
// System Signals
//==============================================================================
    logic ap_clk = 0;   

    initial begin: AP_CLK
      forever begin
        ap_clk = #(LP_CLK_PERIOD_PS/2) ~ap_clk;
      end
    end
    
    logic ap_rst_n = 0;
    logic initial_reset  =0;    

    task automatic ap_rst_n_sequence(input integer unsigned width = 20);
      @(posedge ap_clk);
      #1ps;
      ap_rst_n = 0;
      repeat (width) @(posedge ap_clk);
      #1ps;
      ap_rst_n = 1;
    endtask 

    initial begin: AP_RST
      ap_rst_n_sequence(50);
      initial_reset =1;
    end
    
//==============================================================================
// AXI4 interface Port declaration
//==============================================================================
    wire                                 	m00_axi_awvalid;
    wire                                 	m00_axi_awready;
    wire  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_awaddr;
    wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_awid;
    wire  [7:0]                          	m00_axi_awlen;
    wire  [2:0]                          	m00_axi_awsize;
    wire  [1:0]                          	m00_axi_awburst;
    wire  [1:0]                          	m00_axi_awlock;
    wire  [3:0]                          	m00_axi_awcache;
    wire  [2:0]                          	m00_axi_awprot;
    wire  [3:0]                          	m00_axi_awqos;
    wire  [3:0]                          	m00_axi_awregion;
    wire  [C_M00_AXI_AWUSER_WIDTH - 1:0] 	m00_axi_awuser;
    wire                                 	m00_axi_wvalid;
    wire                                 	m00_axi_wready;
    wire  [C_M00_AXI_DATA_WIDTH - 1:0]   	m00_axi_wdata;
    wire  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 	m00_axi_wstrb;
    wire                                 	m00_axi_wlast;
    wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_wid;
    wire  [C_M00_AXI_WUSER_WIDTH - 1:0]  	m00_axi_wuser;
    wire                                 	m00_axi_arvalid;
    wire                                 	m00_axi_arready;
    wire  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_araddr;
    wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_arid;
    wire  [7:0]                          	m00_axi_arlen;
    wire  [2:0]                          	m00_axi_arsize;
    wire  [1:0]                          	m00_axi_arburst;
    wire  [1:0]                          	m00_axi_arlock;
    wire  [3:0]                          	m00_axi_arcache;
    wire  [2:0]                          	m00_axi_arprot;
    wire  [3:0]                          	m00_axi_arqos;
    wire  [3:0]                          	m00_axi_arregion;
    wire  [C_M00_AXI_ARUSER_WIDTH - 1:0] 	m00_axi_aruser;
    wire                                 	m00_axi_rvalid;
    wire                                 	m00_axi_rready;
    wire [C_M00_AXI_DATA_WIDTH - 1:0]    	m00_axi_rdata;
    wire                                 	m00_axi_rlast;
    wire [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_rid;
    wire [C_M00_AXI_RUSER_WIDTH - 1:0]   	m00_axi_ruser;
    wire [1:0]                           	m00_axi_rresp;
    wire                                 	m00_axi_bvalid;
    wire                                 	m00_axi_bready;
    wire [1:0]                           	m00_axi_bresp;
    wire [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_bid;
    wire [C_M00_AXI_BUSER_WIDTH - 1:0]   	m00_axi_buser;
    
    wire [1-1:0] s_axi_control_awvalid;
    wire [1-1:0] s_axi_control_awready;
    wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_awaddr;
    wire [1-1:0] s_axi_control_wvalid;
    wire [1-1:0] s_axi_control_wready;
    wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_wdata;
    wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb;
    wire [1-1:0] s_axi_control_arvalid;
    wire [1-1:0] s_axi_control_arready;
    wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_araddr;
    wire [1-1:0] s_axi_control_rvalid;
    wire [1-1:0] s_axi_control_rready;
    wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_rdata;
    wire [2-1:0] s_axi_control_rresp;
    wire [1-1:0] s_axi_control_bvalid;
    wire [1-1:0] s_axi_control_bready;
    wire [2-1:0] s_axi_control_bresp;
    wire interrupt;
    
    slv_m00_axi_vip_slv_mem_t   m00_axi;
    control_dma_ip_vip_mst_t  ctrl;
    
//==============================================================================
// Read/Write txt File
//==============================================================================
    integer fp_in_infmap     ;
    integer fp_ot_otfmap     ;
    
    initial begin
        fp_in_infmap <= $fopen(`FP_IN_INFAMP , "r");
        fp_ot_otfmap <= $fopen(`FP_OT_OTFMAP , "w");
    end

//==============================================================================
// TB register
//==============================================================================
    
    integer start_t, end_t [0 : `LOOP_NUM-1] ;
    real loop_cycle, total_cycle, min_cycle, max_cycle;

//==============================================================================
// Gen Input Signal
//==============================================================================
    rd_param_conv_layer #(
        .OCH       (CONV1_OCH ), 
        .ICH       (CONV1_ICH ), 
        .KY        (CONV_KY  ), 
        .KX        (CONV_KX  )
    ) u_rd_param_conv_layer_c1 (1'b0);
    
    rd_param_conv_layer #(
        .OCH       (CONV2_OCH ), 
        .ICH       (CONV2_ICH ), 
        .KY        (CONV_KY  ), 
        .KX        (CONV_KX  )
    ) u_rd_param_conv_layer_c2 (1'b0);
    
    rd_param_fc_layer #(
        .OCH       (FC1_OCH ), 
        .ICH       (FC1_ICH )
    ) u_rd_param_fc_layer_fc1 (1'b0);
    
    rd_param_fc_layer #(
        .OCH       (FC2_OCH ), 
        .ICH       (FC2_ICH )
    ) u_rd_param_fc_layer_fc2 (1'b0);
    
    rd_param_fc_layer #(
        .OCH       (FC3_OCH ), 
        .ICH       (FC3_ICH )
    ) u_rd_param_fc_layer_fc3 (1'b0);
    
//==============================================================================
// Control AXI4 interface Task
//==============================================================================
    /////// Control interface blocking write
    /////// The task will return when the BRESP has been returned from the kernel.
    task automatic blocking_write_register (input bit [31:0] addr_in, input bit [31:0] data);
      axi_transaction   wr_xfer;
      axi_transaction   wr_rsp;
      wr_xfer = ctrl.wr_driver.create_transaction("wr_xfer");
      wr_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
      assert(wr_xfer.randomize() with {addr == addr_in;});
      wr_xfer.set_data_beat(0, data);
      ctrl.wr_driver.send(wr_xfer);
      ctrl.wr_driver.wait_rsp(wr_rsp);
    endtask
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // Control interface blocking read
    // The task will return when the BRESP has been returned from the kernel.
    task automatic read_register (input bit [31:0] addr, output bit [31:0] rddata);
      axi_transaction   rd_xfer;
      axi_transaction   rd_rsp;
      bit [31:0] rd_value;
      rd_xfer = ctrl.rd_driver.create_transaction("rd_xfer");
      rd_xfer.set_addr(addr);
      rd_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
      ctrl.rd_driver.send(rd_xfer);
      ctrl.rd_driver.wait_rsp(rd_rsp);
      rd_value = rd_rsp.get_data_beat(0);
      rddata = rd_value;
    endtask
    
    task backdoor_memory_write_byte (
        	input int unsigned addr,
        	input byte    unsigned data 
        );
	    int unsigned aligned_offset;
	    bit [C_M00_AXI_DATA_WIDTH-1:0] 			bus_data;
	    bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;
        
	    bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	    bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	    aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];
        
	    bus_data       = bus_data + (data << (8*aligned_offset));
	    bus_strb       = bus_strb + (1'b1 << aligned_offset);
	    m00_axi.mem_model.backdoor_memory_write({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
    endtask
    
    
    task backdoor_memory_read_byte (
        	input int unsigned addr,
        	output byte   unsigned data 
        );
	    int unsigned aligned_offset;
	    bit [C_M00_AXI_DATA_WIDTH-1:0] 			bus_data;
	    bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;
        
	    bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	    bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	    aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];
        
	    bus_data = m00_axi.mem_model.backdoor_memory_read({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}});
	    data = bus_data[(8*aligned_offset) +: 8];
    endtask
    
    task rd_infmap (
            input integer i_idx  ,
            output [CONV1_ICH * CONV1_IY * CONV1_IX * I_F_BW-1   : 0] o_infmap
        );
        reg  [I_F_BW-1:0]    infmap ;
        integer         rd_och, rd_ich, rd_iy, rd_ky, status, temp;
        integer         f_idx, w_idx, b_idx ;
        integer         fcheck, icheck, bcheck;
        integer         ich, iy, ix ;
        
        begin
        fcheck = fp_in_infmap;
        if(!fcheck) begin $display("Fail infmap file open!!"); $finish; end
        
        status = $fscanf(fp_in_infmap,"idx: %03d (ich,iy): ix \n", f_idx);
        icheck = (f_idx == i_idx);
        if(!icheck) begin 
            $display("Read File idx is Wrong!!"); 
            $display("%03d ", f_idx); 
            $finish; 
        end
        
        for(ich = 0; ich < CONV1_ICH; ich = ich+1) begin
            for(iy = 0; iy < CONV1_IY; iy = iy+1) begin 
                status = $fscanf(fp_in_infmap,"(%02d,%02d) ", rd_ich, rd_iy); 
                if(ich != rd_ich) begin $display("fp_in_infmap ich Wrong!!"); $finish; end
                if(iy != rd_iy)  begin $display("fp_in_infmap iy Wrong!!");  $finish; end
                for(ix = 0; ix < CONV1_IX; ix = ix+1) begin 
                    status = $fscanf(fp_in_infmap,"%02x ", infmap);
                    o_infmap[(ich*CONV1_IY*CONV1_IX+ iy*CONV1_IX + ix)*I_F_BW +: I_F_BW] = infmap;
                end
                status = $fscanf(fp_in_infmap,"\n",temp);
            end
        end
        
        end
    endtask
        
    task backdoor_cnn_parameter_write (
        	input int unsigned start_addr
        );
        longint unsigned addr_byte;
        
        reg  [CONV1_OCH * CONV1_ICH * CONV_KY * CONV_KX * W_BW-1 : 0] r_c1_weight  ;
        reg  [CONV1_OCH * B_BW-1 : 0] r_c1_bias    ;
        
        reg  [CONV2_OCH * CONV2_ICH * CONV_KY * CONV_KX * W_BW-1 : 0] r_c2_weight  ;
        reg  [CONV2_OCH * B_BW-1 : 0] r_c2_bias    ;
        
        reg  [FC1_OCH * FC1_ICH * W_BW-1 : 0] r_fc1_weight  ;
        reg  [FC1_OCH * B_BW-1 : 0]           r_fc1_bias    ;
        
        reg  [FC2_OCH * FC2_ICH * W_BW-1 : 0] r_fc2_weight  ;
        reg  [FC2_OCH * B_BW-1 : 0]           r_fc2_bias    ;
        
        reg  [FC3_OCH * FC3_ICH * W_BW-1 : 0] r_fc3_weight  ;
        reg  [FC3_OCH * B_BW-1 : 0]           r_fc3_bias    ;
        
        u_rd_param_conv_layer_c1.rd_param_conv_layer_task(1, r_c1_weight, r_c1_bias);
        u_rd_param_conv_layer_c2.rd_param_conv_layer_task(2, r_c2_weight, r_c2_bias);
        
        u_rd_param_fc_layer_fc1.rd_param_fc_layer_task(1, r_fc1_weight, r_fc1_bias); 
        u_rd_param_fc_layer_fc2.rd_param_fc_layer_task(2, r_fc2_weight, r_fc2_bias); 
        u_rd_param_fc_layer_fc3.rd_param_fc_layer_task(3, r_fc3_weight, r_fc3_bias); 
        
        addr_byte = (start_addr >> C_M00_AXI_DATA_WIDTH_BYTE_LOG);
        
        // C1
        for(longint unsigned i = 0; i < B_C1_W_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_C1_W_DATA_W){1'b0}}, 
                r_c1_weight[i*B_C1_W_DATA_W +: B_C1_W_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        for(longint unsigned i = 0; i < B_C1_B_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_C1_B_DATA_W){1'b0}}, 
                r_c1_bias[i*B_C1_B_DATA_W +: B_C1_B_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        
        // C2
        for(longint unsigned i = 0; i < B_C2_W_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_C2_W_DATA_W){1'b0}}, 
                r_c2_weight[i*B_C2_W_DATA_W +: B_C2_W_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        for(longint unsigned i = 0; i < B_C2_B_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_C2_B_DATA_W){1'b0}}, 
                r_c2_bias[i*B_C2_B_DATA_W +: B_C2_B_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        
        // FC1
        for(longint unsigned i = 0; i < B_FC1_W_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC1_W_DATA_W){1'b0}}, 
                r_fc1_weight[i*B_FC1_W_DATA_W +: B_FC1_W_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        for(longint unsigned i = 0; i < B_FC1_B_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC1_B_DATA_W){1'b0}}, 
                r_fc1_bias[i*B_FC1_B_DATA_W +: B_FC1_B_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        
        // FC3
        for(longint unsigned i = 0; i < B_FC2_W_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC2_W_DATA_W){1'b0}}, 
                r_fc2_weight[i*B_FC2_W_DATA_W +: B_FC2_W_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        for(longint unsigned i = 0; i < B_FC2_B_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC2_B_DATA_W){1'b0}}, 
                r_fc2_bias[i*B_FC2_B_DATA_W +: B_FC2_B_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        
        // FC3
        for(longint unsigned i = 0; i < B_FC3_W_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC3_W_DATA_W){1'b0}}, 
                r_fc3_weight[i*B_FC3_W_DATA_W +: B_FC3_W_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
        for(longint unsigned i = 0; i < B_FC3_B_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_FC3_B_DATA_W){1'b0}}, 
                r_fc3_bias[i*B_FC3_B_DATA_W +: B_FC3_B_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
    endtask
    
    task backdoor_cnn_infmap_write (
            input integer i_idx  ,
        	input int unsigned start_addr
        );
        longint unsigned addr_byte;
        reg  [CONV1_ICH * CONV1_IY * CONV1_IX * I_F_BW-1   : 0] r_infmap ;
        
        rd_infmap(
            .i_idx    (i_idx   ),
            .o_infmap (r_infmap)
        );
        
        addr_byte = (start_addr >> C_M00_AXI_DATA_WIDTH_BYTE_LOG);
        
        for(longint unsigned i = 0; i < B_C1_I_DATA_D; i = i + 1) begin
	        bit [C_M00_AXI_DATA_WIDTH-1:0]      bus_data;
            bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0] bus_strb;
            
            bus_data = {{(C_M00_AXI_DATA_WIDTH - B_C1_I_DATA_W){1'b0}}, 
                r_infmap[i*B_C1_I_DATA_W +: B_C1_I_DATA_W]};
            bus_strb = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
            m00_axi.mem_model.backdoor_memory_write(
                {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
            addr_byte = addr_byte + 1;
        end
    endtask
    
    task backdoor_inference_read (
            input integer i_idx  ,
        	input int unsigned start_addr
        );
        longint unsigned addr_byte;
        reg  [4-1 : 0] r_inference ;
        
	    bit [C_M00_AXI_DATA_WIDTH-1:0] 			bus_data;
	    bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;
        
        addr_byte = (start_addr >> C_M00_AXI_DATA_WIDTH_BYTE_LOG);
        
	    bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	    bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b1}};
        
	    bus_data = m00_axi.mem_model.backdoor_memory_read(
            {addr_byte, {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}});
	    r_inference = bus_data[4-1 : 0];
        
        $display("(idx: %0d) Result: %0d", i_idx, r_inference); 
    endtask
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // Start the control VIP, SLAVE memory models and AXI4-Stream.
    `define RANDOM_TRANSACTION
    task automatic start_vips();
          axi_ready_gen     rgen;
          $display("///////////////////////////////////////////////////////////////////////////");
          $display("Control Master: ctrl");
          ctrl = new("ctrl", tb_dma_LeNet5.inst_control_dma_ip_vip.inst.IF);
          ctrl.start_master();
        
          $display("///////////////////////////////////////////////////////////////////////////");
          $display("Starting Memory slave: m00_axi");
          m00_axi = new("m00_axi", tb_dma_LeNet5.inst_slv_m00_axi_vip.inst.IF);
        `ifdef RANDOM_TRANSACTION
          $display("random transaction for checking DMA controller :) ");
          rgen = new("m00_axi_random transaction"); 
          m00_axi.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
          m00_axi.mem_model.set_inter_beat_gap_range(0,10);
        `else
          $display("Ideal Case. for checking best performance :)");
          rgen = new("m00_axi_no_backpressure_allready"); 
          rgen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
          m00_axi.wr_driver.set_wready_gen(rgen);
          m00_axi.wr_driver.set_awready_gen(rgen);
          m00_axi.rd_driver.set_arready_gen(rgen);
        `endif
        /////////
         m00_axi.start_slave();
        
    endtask

//==============================================================================
// Main Function
//==============================================================================
    reg [31:0] rd_loop;
    reg [31:0] wr_loop;
    reg rd_loop_ready;
    initial begin : STIMULUS_GET_INPUT
      bit [31:0] lite_rddata;
      bit [31:0] mask_data;
    //   bit [31:0] adding_value; // TODO Added
      byte unsigned ret_rd_value;
      byte unsigned ret_wr_value;
      bit error_found;
      integer error_counter;
      
    
    //   adding_value = 'd1; // TODO Added
      ret_rd_value = 'd0;
      ret_wr_value = 'd0;
      error_found = 'd0;
      error_counter = 'd0;
      #200;
      $display( "======================================================");
      $display( "======  TestBench for verification AMBA System  ======");
      $display( "======================================================");
      start_vips();
      
      backdoor_cnn_parameter_write(USER_RDMA_PARAM_ADDR);
    
      blocking_write_register(ADDR_AXI00_PTR0_DATA_0, 32'd0); // baseaddr is 0.
      blocking_write_register(ADDR_RDMA_MEM_PTR_PARAM_0, USER_RDMA_PARAM_ADDR);
      blocking_write_register(ADDR_RDMA_MEM_PTR_INFMAP_0, USER_RDMA_INFMAP_ADDR);
      blocking_write_register(ADDR_WDMA_MEM_PTR_DATA_0, USER_WDMA_MEM_ADDR);
      $display("NUM_RD_PARAM :%0d", NUM_RD_PARAM); 
    //   blocking_write_register(ADDR_WDMA_TRANSFER_BYTE_DATA_0, USER_TRANSFER_LEN);
    
      // start. polling
      // 1. check idle 
      while(1) begin
        read_register(ADDR_AP_CTRL, lite_rddata); // addr / data
        $display( "ADDR_AP_CTRL check idle (hex) : %x", lite_rddata);
        if( (lite_rddata & CTRL_IDLE_MASK) == 32'b100) // IDLE
          break;
      end
      
      // 2. Move quantized parameter, wait done
      blocking_write_register(ADDR_AP_CTRL, 32'b1);
      while(1) begin
        read_register(ADDR_AP_CTRL, lite_rddata); 
        // $display("Move quantized parameter wait done (hex) : %x [%0d]", lite_rddata, $time);
        if( (lite_rddata & CTRL_DONE_MASK) == 32'b10) begin // DONE
          $display("Move quantized parameter done!! [%0d]", $time); 
          break;
        end
      end
      repeat(1000) @(posedge ap_clk); #1;
      
      // 3. Write infmap to LeNet-5, wait WDMA done
      rd_loop = 0;
      wr_loop = 0;
      rd_loop_ready = 0;
      while (1) begin
        
        if((~rd_loop_ready) && (rd_loop < `LOOP_NUM)) begin
            backdoor_cnn_infmap_write(rd_loop, USER_RDMA_INFMAP_ADDR);
            blocking_write_register(ADDR_AP_CTRL, CTRL_START_INFMAP_MASK);
            rd_loop_ready = 1;
        end
        while(1) begin
            read_register(ADDR_AP_CTRL, lite_rddata); 
            if((lite_rddata & CTRL_DONE_WDMA_MASK) == CTRL_DONE_WDMA_MASK) begin // WR_DONE
                backdoor_inference_read(wr_loop, USER_WDMA_MEM_ADDR + wr_loop*8);
                wr_loop++;
                repeat(10) @(posedge ap_clk); #1;
                break;
            end else if((lite_rddata & CTRL_DONE_MASK) == CTRL_DONE_MASK) begin // RD_DONE
                $display("(idx: %0d) Write infmap done!! [%0d]", rd_loop, $time); 
                rd_loop_ready = 0;
                rd_loop++;
                repeat(10) @(posedge ap_clk); #1;
                break;
            end
        end
        if(wr_loop == `LOOP_NUM) begin
            $display("HW Run Done!");
            break;
        end
        
      end
      
      $display( "======================================================");
      $display( "================ Finish Simulation!! =================");
      $display( "======================================================");
      $finish;
    end

//==============================================================================
// Instantiation Submodule
//==============================================================================
    dma_LeNet5_top #(
      .C_S_AXI_CONTROL_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
      .C_S_AXI_CONTROL_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH ),
      .C_M00_AXI_ID_WIDTH 		  ( C_M00_AXI_ID_WIDTH    	   ),
      .C_M00_AXI_AWUSER_WIDTH 	  ( C_M00_AXI_AWUSER_WIDTH	   ),
      .C_M00_AXI_ARUSER_WIDTH 	  ( C_M00_AXI_ARUSER_WIDTH	   ),
      .C_M00_AXI_WUSER_WIDTH 	  ( C_M00_AXI_WUSER_WIDTH 	   ),
      .C_M00_AXI_RUSER_WIDTH 	  ( C_M00_AXI_RUSER_WIDTH 	   ),
      .C_M00_AXI_BUSER_WIDTH 	  ( C_M00_AXI_BUSER_WIDTH 	   ),
      .C_M00_AXI_USER_VALUE 	  ( C_M00_AXI_USER_VALUE  	   ),
      .C_M00_AXI_PROT_VALUE 	  ( C_M00_AXI_PROT_VALUE  	   ),
      .C_M00_AXI_CACHE_VALUE 	  ( C_M00_AXI_CACHE_VALUE 	   ),
      .C_M00_AXI_ADDR_WIDTH       ( C_M00_AXI_ADDR_WIDTH       ),
      .C_M00_AXI_DATA_WIDTH       ( C_M00_AXI_DATA_WIDTH       ),
      .NUM_RD_INFMAP       (NUM_RD_INFMAP   ) ,
      .NUM_RD_PARAM        (NUM_RD_PARAM    ) ,
      .MULT_DELAY       (MULT_DELAY    ) ,
      .ACC_DELAY_C      (ACC_DELAY_C   ) ,
      .ACC_DELAY_FC     (ACC_DELAY_FC  ) ,
      .AB_DELAY         (AB_DELAY      ) ,
      .I_F_BW           (I_F_BW        ) ,
      .W_BW             (W_BW          ) ,
      .B_BW             (B_BW          ) ,
      .DATA_IDX_BW      (DATA_IDX_BW   ) 
    ) u_dma_LeNet5_top (
      .ap_clk                ( ap_clk                ),
      .ap_rst_n              ( ap_rst_n              ),
      .m00_axi_awvalid	  	 ( m00_axi_awvalid		 ),
      .m00_axi_awready	  	 ( m00_axi_awready		 ),
      .m00_axi_awaddr	  	 ( m00_axi_awaddr		 ),
      .m00_axi_awid		  	 ( m00_axi_awid		  	 ),
      .m00_axi_awlen	  	 ( m00_axi_awlen		 ),
      .m00_axi_awsize	  	 ( m00_axi_awsize		 ),
      .m00_axi_awburst	  	 ( m00_axi_awburst		 ),
      .m00_axi_awlock	  	 ( m00_axi_awlock		 ),
      .m00_axi_awcache	  	 ( m00_axi_awcache		 ),
      .m00_axi_awprot	  	 ( m00_axi_awprot		 ),
      .m00_axi_awqos	  	 ( m00_axi_awqos		 ),
      .m00_axi_awregion	  	 ( m00_axi_awregion	  	 ),
      .m00_axi_awuser	  	 ( m00_axi_awuser		 ),
      .m00_axi_wvalid	  	 ( m00_axi_wvalid		 ),
      .m00_axi_wready	  	 ( m00_axi_wready		 ),
      .m00_axi_wdata	  	 ( m00_axi_wdata		 ),
      .m00_axi_wstrb	  	 ( m00_axi_wstrb		 ),
      .m00_axi_wlast	  	 ( m00_axi_wlast		 ),
      .m00_axi_wid		  	 ( m00_axi_wid			 ),
      .m00_axi_wuser	  	 ( m00_axi_wuser		 ),
      .m00_axi_arvalid	  	 ( m00_axi_arvalid		 ),
      .m00_axi_arready	  	 ( m00_axi_arready		 ),
      .m00_axi_araddr	  	 ( m00_axi_araddr		 ),
      .m00_axi_arid		  	 ( m00_axi_arid		  	 ),
      .m00_axi_arlen	  	 ( m00_axi_arlen		 ),
      .m00_axi_arsize	  	 ( m00_axi_arsize		 ),
      .m00_axi_arburst	  	 ( m00_axi_arburst		 ),
      .m00_axi_arlock	  	 ( m00_axi_arlock		 ),
      .m00_axi_arcache	  	 ( m00_axi_arcache		 ),
      .m00_axi_arprot	  	 ( m00_axi_arprot		 ),
      .m00_axi_arqos	  	 ( m00_axi_arqos		 ),
      .m00_axi_arregion	  	 ( m00_axi_arregion	  	 ),
      .m00_axi_aruser	  	 ( m00_axi_aruser		 ),
      .m00_axi_rvalid	  	 ( m00_axi_rvalid		 ),
      .m00_axi_rready	  	 ( m00_axi_rready		 ),
      .m00_axi_rdata	  	 ( m00_axi_rdata		 ),
      .m00_axi_rlast	  	 ( m00_axi_rlast		 ),
      .m00_axi_rid		  	 ( m00_axi_rid			 ),
      .m00_axi_ruser	  	 ( m00_axi_ruser		 ),
      .m00_axi_rresp	  	 ( m00_axi_rresp		 ),
      .m00_axi_bvalid	  	 ( m00_axi_bvalid		 ),
      .m00_axi_bready	  	 ( m00_axi_bready		 ),
      .m00_axi_bresp	  	 ( m00_axi_bresp		 ),
      .m00_axi_bid		  	 ( m00_axi_bid			 ),
      .m00_axi_buser	  	 ( m00_axi_buser		 ),
      .s_axi_control_awvalid ( s_axi_control_awvalid ),
      .s_axi_control_awready ( s_axi_control_awready ),
      .s_axi_control_awaddr  ( s_axi_control_awaddr  ),
      .s_axi_control_wvalid  ( s_axi_control_wvalid  ),
      .s_axi_control_wready  ( s_axi_control_wready  ),
      .s_axi_control_wdata   ( s_axi_control_wdata   ),
      .s_axi_control_wstrb   ( s_axi_control_wstrb   ),
      .s_axi_control_arvalid ( s_axi_control_arvalid ),
      .s_axi_control_arready ( s_axi_control_arready ),
      .s_axi_control_araddr  ( s_axi_control_araddr  ),
      .s_axi_control_rvalid  ( s_axi_control_rvalid  ),
      .s_axi_control_rready  ( s_axi_control_rready  ),
      .s_axi_control_rdata   ( s_axi_control_rdata   ),
      .s_axi_control_rresp   ( s_axi_control_rresp   ),
      .s_axi_control_bvalid  ( s_axi_control_bvalid  ),
      .s_axi_control_bready  ( s_axi_control_bready  ),
      .s_axi_control_bresp   ( s_axi_control_bresp   ),
      .interrupt             ( interrupt             )
    );
    
    // Master Control instantiation
    control_dma_ip_vip inst_control_dma_ip_vip (
      .aclk          ( ap_clk                ),
      .aresetn       ( ap_rst_n              ),
      .m_axi_awvalid ( s_axi_control_awvalid ),
      .m_axi_awready ( s_axi_control_awready ),
      .m_axi_awaddr  ( s_axi_control_awaddr  ),
      .m_axi_wvalid  ( s_axi_control_wvalid  ),
      .m_axi_wready  ( s_axi_control_wready  ),
      .m_axi_wdata   ( s_axi_control_wdata   ),
      .m_axi_wstrb   ( s_axi_control_wstrb   ),
      .m_axi_arvalid ( s_axi_control_arvalid ),
      .m_axi_arready ( s_axi_control_arready ),
      .m_axi_araddr  ( s_axi_control_araddr  ),
      .m_axi_rvalid  ( s_axi_control_rvalid  ),
      .m_axi_rready  ( s_axi_control_rready  ),
      .m_axi_rdata   ( s_axi_control_rdata   ),
      .m_axi_rresp   ( s_axi_control_rresp   ),
      .m_axi_bvalid  ( s_axi_control_bvalid  ),
      .m_axi_bready  ( s_axi_control_bready  ),
      .m_axi_bresp   ( s_axi_control_bresp   )
    );
    
    
    // Slave MM VIP instantiation
    // only use 64b addr
    slv_m00_axi_vip #(
      .C_S_AXI_ID_WIDTH 		  ( C_M00_AXI_ID_WIDTH    	   ),
      .C_S_AXI_AWUSER_WIDTH 	  ( C_M00_AXI_AWUSER_WIDTH	   ),
      .C_S_AXI_ARUSER_WIDTH 	  ( C_M00_AXI_ARUSER_WIDTH	   ),
      .C_S_AXI_WUSER_WIDTH 	  	  ( C_M00_AXI_WUSER_WIDTH 	   ),
      .C_S_AXI_RUSER_WIDTH 	  	  ( C_M00_AXI_RUSER_WIDTH 	   ),
      .C_S_AXI_BUSER_WIDTH 	  	  ( C_M00_AXI_BUSER_WIDTH 	   ),
      .C_S_AXI_USER_VALUE 	  	  ( C_M00_AXI_USER_VALUE  	   ),
      .C_S_AXI_PROT_VALUE 	  	  ( C_M00_AXI_PROT_VALUE  	   ),
      .C_S_AXI_CACHE_VALUE 	  	  ( C_M00_AXI_CACHE_VALUE 	   ),
      .C_S_AXI_ADDR_WIDTH         ( C_M00_AXI_ADDR_WIDTH       ),
      .C_S_AXI_DATA_WIDTH         ( C_M00_AXI_DATA_WIDTH       )
    )
    inst_slv_m00_axi_vip (  
      .aclk          				( ap_clk          	),
      .aresetn       				( ap_rst_n        	),
    
      .s_axi_awvalid	  	 		( m00_axi_awvalid	),
      .s_axi_awready	  	 		( m00_axi_awready	),
      .s_axi_awaddr	  	 			( m00_axi_awaddr	),
      .s_axi_awid		  	 		( m00_axi_awid		),
      .s_axi_awlen	  	 			( m00_axi_awlen		),
      .s_axi_awsize	  	 			( m00_axi_awsize	),
      .s_axi_awburst	 	 	 	( m00_axi_awburst	),
      .s_axi_awlock	  	 			( m00_axi_awlock	),
      .s_axi_awcache	 			( m00_axi_awcache	),
      .s_axi_awprot	  	 			( m00_axi_awprot	),
      .s_axi_awqos	  	 			( m00_axi_awqos		),
      .s_axi_awregion	 			( m00_axi_awregion	),
      .s_axi_awuser	  	 			( m00_axi_awuser	),
      .s_axi_wvalid	  	 			( m00_axi_wvalid	),
      .s_axi_wready	  	 			( m00_axi_wready	),
      .s_axi_wdata	  	 			( m00_axi_wdata		),
      .s_axi_wstrb	  	 			( m00_axi_wstrb		),
      .s_axi_wlast	  	 			( m00_axi_wlast		),
      .s_axi_wid		 			( m00_axi_wid		),
      .s_axi_wuser	  	 			( m00_axi_wuser		),
      .s_axi_arvalid	 			( m00_axi_arvalid	),
      .s_axi_arready	 			( m00_axi_arready	),
      .s_axi_araddr	  	 			( m00_axi_araddr	),
      .s_axi_arid		 			( m00_axi_arid		),
      .s_axi_arlen	  	 			( m00_axi_arlen		),
      .s_axi_arsize	  	 			( m00_axi_arsize	),
      .s_axi_arburst	 			( m00_axi_arburst	),
      .s_axi_arlock	  	 			( m00_axi_arlock	),
      .s_axi_arcache	 			( m00_axi_arcache	),
      .s_axi_arprot	  	 			( m00_axi_arprot	),
      .s_axi_arqos	  	 			( m00_axi_arqos		),
      .s_axi_arregion	 			( m00_axi_arregion	),
      .s_axi_aruser	  	 			( m00_axi_aruser	),
      .s_axi_rvalid	  	 			( m00_axi_rvalid	),
      .s_axi_rready	  	 			( m00_axi_rready	),
      .s_axi_rdata	  	 			( m00_axi_rdata		),
      .s_axi_rlast	  	 			( m00_axi_rlast		),
      .s_axi_rid		 			( m00_axi_rid		),
      .s_axi_ruser	  	 			( m00_axi_ruser		),
      .s_axi_rresp	  	 			( m00_axi_rresp		),
      .s_axi_bvalid	  	 			( m00_axi_bvalid	),
      .s_axi_bready	  	 			( m00_axi_bready	),
      .s_axi_bresp	  	 			( m00_axi_bresp		),
      .s_axi_bid		 			( m00_axi_bid		),
      .s_axi_buser	  	 			( m00_axi_buser		)
    );

endmodule


//==============================================================================
// Read CONV Layer Parameter
//==============================================================================
module rd_param_conv_layer #(
    parameter OCH = 0 ,
    parameter ICH = 0 ,
    parameter KY  = 0 ,
    parameter KX  = 0 
) (
    input i_temp
);
    `include "defines_parameter_LeNet5.vh"
    task rd_param_conv_layer_task;
        input integer                       layer_num ;
        output [OCH*ICH*KX*KY*W_BW-1 : 0]   o_weight  ;
        output [OCH*B_BW-1 : 0]             o_bias    ;
        
        reg  [W_BW-1:0]      weight ;
        reg  [B_BW-1:0]      bias   ;
        integer         rd_och, rd_ich, rd_ky, status, temp;
        integer         w_idx, b_idx ;
        integer         fcheck, icheck;
        integer         och, ich, iy, ix, ky, kx, oy, ox ;
        integer fp_weight, fp_bias;
        
        begin
            
        if(layer_num == 1) begin
            fp_weight  = $fopen(`FP_IN_C1_WEIGHT  , "r");
            fp_bias    = $fopen(`FP_IN_C1_BIAS    , "r");
        end else if(layer_num == 2) begin
            fp_weight  = $fopen(`FP_IN_C2_WEIGHT  , "r");
            fp_bias    = $fopen(`FP_IN_C2_BIAS    , "r");
        end 
        
        fcheck = fp_weight && fp_bias;
        if(!fcheck) begin $display("Fail conv_layer file open!!"); $finish; end
        
        status = $fscanf(fp_weight,"idx: %03d (och,ich,ky): kx \n", w_idx);
        status = $fscanf(fp_bias  ,"idx: %03d (och) \n", b_idx);
        icheck = (w_idx == 0) && (b_idx == 0);
        if(!icheck) begin 
            $display("Read File idx is Wrong!!"); 
            $display("%03d %03d", w_idx, b_idx); 
            $finish; 
        end
        
        for (och = 0 ; och < OCH; och = och+1) begin
            for(ich = 0; ich < ICH; ich = ich+1) begin
                for(ky = 0; ky < KY; ky = ky+1) begin 
                    status = $fscanf(fp_weight,"(%02d,%02d,%02d) ", rd_och, rd_ich, rd_ky); 
                    if(och != rd_och) begin $display("fp_weight och Wrong!!"); $finish; end
                    if(ich != rd_ich) begin $display("fp_weight ich Wrong!!"); $finish; end
                    if(ky != rd_ky) begin $display("fp_weight ky Wrong!!"); $finish; end
                    for(kx = 0; kx < KX; kx = kx+1) begin
                        status = $fscanf(fp_weight,"%02x ", weight);
                        o_weight[(och*ICH*KY*KX+ ich*KY*KX+ ky*KX + kx)*W_BW +: W_BW] = weight;
                    end 
                    status = $fscanf(fp_weight,"\n",temp);
                end
            end
        end 
        
        for (och = 0 ; och < OCH; och = och+1) begin
            status = $fscanf(fp_bias,"(%02d) ", rd_och); 
            if(och != rd_och) begin $display("fp_bias och Wrong!!"); $finish; end
            status = $fscanf(fp_bias,"%04x \n", bias);
            o_bias[och*B_BW +: B_BW] = bias;
        end
        
        $fclose(fp_weight);
        $fclose(fp_bias);
        
        end
    endtask 
endmodule

//==============================================================================
// Read FC Layer Parameter
//==============================================================================
module rd_param_fc_layer #(
    parameter OCH = 0 ,
    parameter ICH = 0 
) (
    input i_temp
);
    `include "defines_parameter_LeNet5.vh"
    task rd_param_fc_layer_task;
        input integer                 layer_num ;
        output [OCH*ICH*W_BW-1 : 0]   o_weight  ;
        output [OCH*B_BW-1 : 0]       o_bias    ;
            
        reg  [W_BW-1:0]      weight ;
        reg  [B_BW-1:0]      bias   ;
        integer         rd_och, rd_ich, status, temp;
        integer         w_idx, b_idx ;
        integer         fcheck, icheck;
        integer         och, ich ;
        integer fp_weight, fp_bias;
        
        begin
            
        if(layer_num == 1) begin
            fp_weight  = $fopen(`FP_IN_FC1_WEIGHT  , "r");
            fp_bias    = $fopen(`FP_IN_FC1_BIAS    , "r");
        end else if(layer_num == 2) begin
            fp_weight  = $fopen(`FP_IN_FC2_WEIGHT  , "r");
            fp_bias    = $fopen(`FP_IN_FC2_BIAS    , "r");
        end else if(layer_num == 3) begin
            fp_weight  = $fopen(`FP_IN_FC3_WEIGHT  , "r");
            fp_bias    = $fopen(`FP_IN_FC3_BIAS    , "r");
        end 
             
        fcheck = fp_weight && fp_bias;
        if(!fcheck) begin $display("Fail fc_layer file open!!"); $finish; end
        
        status = $fscanf(fp_weight,"idx: %03d (och,ich) \n", w_idx);
        status = $fscanf(fp_bias  ,"idx: %03d (och) \n", b_idx);
        icheck = (w_idx == 0) && (b_idx == 0);
        if(!icheck) begin 
            $display("Read File idx is Wrong!!"); 
            $display("%03d %03d", w_idx, b_idx); 
            $finish; 
        end
        
        for (och = 0 ; och < OCH; och = och+1) begin
            for(ich = 0; ich < ICH; ich = ich+1) begin
                status = $fscanf(fp_weight,"(%03d,%03d) ", rd_och, rd_ich); 
                if(och != rd_och) begin $display("fp_weight och Wrong!!"); $finish; end
                if(ich != rd_ich) begin $display("fp_weight ich Wrong!!"); $finish; end
                status = $fscanf(fp_weight,"%02x \n", weight);
                o_weight[(och*ICH+ ich)*W_BW +: W_BW] = weight;
            end
        end 
        
        for (och = 0 ; och < OCH; och = och+1) begin
            status = $fscanf(fp_bias,"(%03d) ", rd_och); 
            if(och != rd_och) begin $display("fp_bias och Wrong!!"); $finish; end
            status = $fscanf(fp_bias,"%04x \n", bias);
            o_bias[och*B_BW +: B_BW] = bias;
        end
        
        $fclose(fp_weight);
        $fclose(fp_bias);
        
        end
    endtask
endmodule