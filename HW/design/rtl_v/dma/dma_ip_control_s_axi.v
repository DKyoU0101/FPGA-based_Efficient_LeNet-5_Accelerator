//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.21
// Design Name: 
// Module Name: dma_ip_control_s_axi
// Project Name: chapter7
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: AXI4-Lite I/F
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module dma_ip_control_s_axi #(
    parameter C_S_AXI_ADDR_WIDTH = 6  ,
    parameter C_S_AXI_DATA_WIDTH = 32 
) (
    ACLK               ,
    ARESET             ,
    ACLK_EN            ,
    i_AWADDR           ,
    i_AWVALID          ,
    o_AWREADY          ,
    i_WDATA            ,
    i_WSTRB            ,
    i_WVALID           ,
    o_WREADY           ,
    o_BRESP            ,
    o_BVALID           ,
    i_BREADY           ,
    i_ARADDR           ,
    i_ARVALID          ,
    o_ARREADY          ,
    o_RDATA            ,
    o_RRESP            ,
    o_RVALID           ,
    i_RREADY           ,
    o_interrupt        ,
    o_rdma_param_ptr   ,
    o_rdma_infmap_ptr  ,
    o_wdma_mem_ptr     ,
    o_axi00_ptr0       ,
    o_ap_start_param   ,
    o_ap_start_infmap  ,
    i_ap_done          ,
    i_ap_ready         ,
    i_ap_idle          ,
    i_ap_wdma_done     
);
//------------------------Address Info-------------------
// 0x00 : Control signals
//        bit 0  - o_ap_start_param (Read/Write/COH)
//        bit 1  - i_ap_done (Read/COR)
//        bit 2  - i_ap_idle (Read)
//        bit 3  - i_ap_ready (Read/COR)
//        bit 4  - o_ap_start_infmap (Read/Write/COH)
//        bit 5  - i_ap_wdma_done (Read/COR)
//        bit 7  - auto_restart (Read/Write)
//        bit 9  - interrupt (Read)
//        others - reserved
// 0x04 : Global Interrupt Enable Register
//        bit 0  - Global Interrupt Enable (Read/Write)
//        others - reserved
// 0x08 : IP Interrupt Enable Register (Read/Write)
//        bit 0 - enable i_ap_done interrupt (Read/Write)
//        bit 1 - enable i_ap_ready interrupt (Read/Write)
//        others - reserved
// 0x0c : IP Interrupt Status Register (Read/COR)
//        bit 0 - i_ap_done (Read/COR)
//        bit 1 - i_ap_ready (Read/COR)
//        others - reserved
// 0x14 : Data signal of rdma_param_ptr
//        bit 31~0 - rdma_param_ptr[31:0] (Read/Write)
// 0x18 : Data signal of rdma_infmap_ptr
//        bit 31~0 - rdma_infmap_ptr[31:0] (Read/Write)
// 0x1c : Data signal of wdma_mem_ptr
//        bit 31~0 - wdma_mem_ptr[31:0] (Read/Write)
// 0x20 : Data signal of axi00_ptr0
//        bit 31~0 - axi00_ptr0[31:0] (Read/Write)
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam
    ADDR_BITS                      = 6      ,
    ADDR_AP_CTRL                   = 6'h00  ,
    ADDR_GIE                       = 6'h04  ,
    ADDR_IER                       = 6'h08  ,
    ADDR_ISR                       = 6'h0c  ,
    // ADDR_RDMA_TRANSFER_BYTE_DATA_0 = 6'h10  ,
    ADDR_RDMA_MEM_PTR_PARAM_0       = 6'h14  ,
    ADDR_RDMA_MEM_PTR_INFMAP_0      = 6'h18  ,
    ADDR_WDMA_MEM_PTR_DATA_0       = 6'h1c  ,
    ADDR_AXI00_PTR0_DATA_0         = 6'h20  ,
    // ADDR_VALUE_TO_ADD	           = 6'h24  ,
    
    S_WR_IDLE                      = 2'd0   ,
    S_WR_DATA                      = 2'd1   ,
    S_WR_RESP                      = 2'd2   ,
    S_WR_RESET                     = 2'd3   ,
    
    S_RD_IDLE                      = 2'd0   ,
    S_RD_DATA                      = 2'd1   ,
    S_RD_RESET                     = 2'd2   ,
    
    DMA_DATA_WIDTH                 = 32     ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                             ACLK                 ;
input                             ARESET               ;
input                             ACLK_EN              ;

input  [C_S_AXI_ADDR_WIDTH-1:0]   i_AWADDR             ;
input                             i_AWVALID            ;
output                            o_AWREADY            ;

input  [C_S_AXI_DATA_WIDTH-1:0]   i_WDATA              ;
input  [C_S_AXI_DATA_WIDTH/8-1:0] i_WSTRB              ;
input                             i_WVALID             ;
output                            o_WREADY             ;

output [1:0]                      o_BRESP              ;
output                            o_BVALID             ;
input                             i_BREADY             ;

input  [C_S_AXI_ADDR_WIDTH-1:0]   i_ARADDR             ;
input                             i_ARVALID            ;
output                            o_ARREADY            ;

output [C_S_AXI_DATA_WIDTH-1:0]   o_RDATA              ;
output [1:0]                      o_RRESP              ;
output                            o_RVALID             ;
input                             i_RREADY             ;

output                            o_interrupt          ;

output [DMA_DATA_WIDTH-1 : 0]     o_rdma_param_ptr     ;
output [DMA_DATA_WIDTH-1 : 0]     o_rdma_infmap_ptr    ;
// output [DMA_DATA_WIDTH-1 : 0]     o_wdma_transfer_byte ;
output [DMA_DATA_WIDTH-1 : 0]     o_wdma_mem_ptr       ;
output [DMA_DATA_WIDTH-1 : 0]     o_axi00_ptr0         ;
// output [DMA_DATA_WIDTH-1 : 0]     o_value_to_add       ;

output                            o_ap_start_param           ;
output                            o_ap_start_infmap           ;
input                             i_ap_done            ;
input                             i_ap_ready           ;
input                             i_ap_idle            ;
input                             i_ap_wdma_done       ;


//==============================================================================
// Hand Shake
//==============================================================================
wire  w_awr_hs   ;
wire  w_wr_hs    ;
wire  w_ard_hs   ;
wire  w_rd_hs    ;

assign w_awr_hs  = (i_AWVALID) && (o_AWREADY) ;
assign w_wr_hs   = (i_WVALID ) && (o_WREADY ) ;
assign w_ard_hs  = (i_ARVALID) && (o_ARREADY) ;
assign w_rd_hs   = (o_RVALID ) && (i_RREADY ) ;

//==============================================================================
// AXI Write FSM
//==============================================================================
reg  [1:0] c_state_wr ;
reg  [1:0] n_state_wr ;

always @(posedge ACLK) begin
    if (ARESET) c_state_wr <= S_WR_RESET;
    else if (ACLK_EN) begin
        c_state_wr <= n_state_wr;
    end
end
always @(*) begin
    n_state_wr = S_WR_IDLE;
    case (c_state_wr)
        S_WR_IDLE:
            if (i_AWVALID)
                n_state_wr = S_WR_DATA;
            else
                n_state_wr = S_WR_IDLE;
        S_WR_DATA:
            if (i_WVALID)
                n_state_wr = S_WR_RESP;
            else
                n_state_wr = S_WR_DATA;
        S_WR_RESP:
            if (i_BREADY)
                n_state_wr = S_WR_IDLE;
            else
                n_state_wr = S_WR_RESP;
    endcase
end

//==============================================================================
// Write Address
//==============================================================================
reg  [ADDR_BITS-1:0] r_wr_addr ;
always @(posedge ACLK) begin
    if (ARESET) r_wr_addr <= {ADDR_BITS{1'b0}};
    else if (ACLK_EN) begin
        if (w_awr_hs) r_wr_addr <= i_AWADDR[ADDR_BITS-1:0];
    end
end

//==============================================================================
// Write Mask
//==============================================================================
wire [C_S_AXI_DATA_WIDTH-1:0] r_wr_mask  ;
assign r_wr_mask = { {8{i_WSTRB[3]}}, {8{i_WSTRB[2]}}, {8{i_WSTRB[1]}}, {8{i_WSTRB[0]}} };

//==============================================================================
// AXI Read FSM
//==============================================================================
reg  [1:0]                    c_state_rd ;
reg  [1:0]                    n_state_rd ;

always @(posedge ACLK) begin
    if (ARESET) c_state_rd <= S_RD_RESET;
    else if (ACLK_EN) begin
        c_state_rd <= n_state_rd;
    end
end
always @(*) begin
    n_state_rd = S_RD_IDLE;
    case (c_state_rd)
        S_RD_IDLE:
            if (i_ARVALID)
                n_state_rd = S_RD_DATA;
            else
                n_state_rd = S_RD_IDLE;
        S_RD_DATA:
            if (w_rd_hs)
                n_state_rd = S_RD_IDLE;
            else
                n_state_rd = S_RD_DATA;
    endcase
end

//==============================================================================
// Read Address
//==============================================================================
wire [ADDR_BITS-1:0] w_rd_addr  ;
assign w_rd_addr = i_ARADDR[ADDR_BITS-1:0];

//==============================================================================
// Internal Registers
//==============================================================================
reg                          r_auto_restart_status ;
wire                         w_task_ap_done        ;
wire                         w_task_ap_ready       ;
wire                         w_auto_restart_done   ;

reg                          r_int_interrupt          ;
reg                          r_int_ap_start_param        ;
reg                          r_int_ap_start_infmap       ;
reg                          r_int_ap_done            ;
reg                          r_int_task_ap_done       ;
reg                          r_int_task_ap_wdma_done       ;
reg                          r_int_ap_idle            ;
reg                          r_int_ap_ready           ;
reg                          r_int_auto_restart       ;
reg                          r_int_gie                ;
reg  [1:0]                   r_int_ier                ;
reg  [1:0]                   r_int_isr                ;
// reg  [DMA_DATA_WIDTH-1 : 0]  r_int_rdma_transfer_byte ;
reg  [DMA_DATA_WIDTH-1 : 0]  r_int_rdma_param_ptr       ;
reg  [DMA_DATA_WIDTH-1 : 0]  r_int_rdma_infmap_ptr      ;
reg  [DMA_DATA_WIDTH-1 : 0]  r_int_wdma_mem_ptr       ;
reg  [DMA_DATA_WIDTH-1 : 0]  r_int_axi00_ptr0         ;
// reg  [DMA_DATA_WIDTH-1 : 0]  r_int_value_to_add       ;

// r_auto_restart_status
always @(posedge ACLK) begin
    if (ARESET) r_auto_restart_status <= 1'b0;
    else if (ACLK_EN) begin
        if (r_int_auto_restart)
            r_auto_restart_status <= 1'b1;
        else if (i_ap_idle)
            r_auto_restart_status <= 1'b0;
    end
end

assign w_task_ap_done       = (i_ap_done      && (!r_auto_restart_status)) || (w_auto_restart_done);
assign w_task_ap_wdma_done  = (i_ap_wdma_done && (!r_auto_restart_status)) || (w_auto_restart_done);
assign w_task_ap_ready      = i_ap_ready && (!r_int_auto_restart);
assign w_auto_restart_done  = (r_auto_restart_status) && (i_ap_idle && (!r_int_ap_idle));

// r_int_interrupt
always @(posedge ACLK) begin
    if (ARESET) r_int_interrupt <= 1'b0;
    else if (ACLK_EN) begin
        if (r_int_gie && (|r_int_isr))
            r_int_interrupt <= 1'b1;
        else
            r_int_interrupt <= 1'b0;
    end
end

// r_int_ap_start
always @(posedge ACLK) begin
    if (ARESET) r_int_ap_start_param <= 1'b0;
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_AP_CTRL) && i_WSTRB[0] && i_WDATA[0])
            r_int_ap_start_param <= 1'b1;
        else if (i_ap_ready)
            r_int_ap_start_param <= r_int_auto_restart; // clear on handshake/auto restart
    end
end
always @(posedge ACLK) begin
    if (ARESET) r_int_ap_start_infmap <= 1'b0;
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_AP_CTRL) && i_WSTRB[0] && i_WDATA[4])
            r_int_ap_start_infmap <= 1'b1;
        else if (i_ap_ready)
            r_int_ap_start_infmap <= r_int_auto_restart; // clear on handshake/auto restart
    end
end

// r_int_ap_done
always @(posedge ACLK) begin
    if (ARESET) r_int_ap_done <= 1'b0;
    else if (ACLK_EN) begin
        r_int_ap_done <= i_ap_done;
    end
end

// r_int_task_ap_done
always @(posedge ACLK) begin
    if (ARESET) r_int_task_ap_done <= 1'b0;
    else if (ACLK_EN) begin
        if (w_task_ap_done)
            r_int_task_ap_done <= 1'b1;
        else if (w_ard_hs && (w_rd_addr == ADDR_AP_CTRL))
            r_int_task_ap_done <= 1'b0; // clear on read
    end
end
always @(posedge ACLK) begin
    if (ARESET) r_int_task_ap_wdma_done <= 1'b0;
    else if (ACLK_EN) begin
        if (w_task_ap_wdma_done)
            r_int_task_ap_wdma_done <= 1'b1;
        else if (w_ard_hs && (w_rd_addr == ADDR_AP_CTRL))
            r_int_task_ap_wdma_done <= 1'b0; // clear on write
    end
end

// r_int_ap_idle
always @(posedge ACLK) begin
    if (ARESET) r_int_ap_idle <= 1'b0;
    else if (ACLK_EN) begin
        r_int_ap_idle <= i_ap_idle;
    end
end

// r_int_ap_ready
always @(posedge ACLK) begin
    if (ARESET) r_int_ap_ready <= 1'b0;
    else if (ACLK_EN) begin
        if (w_task_ap_ready)
            r_int_ap_ready <= 1'b1;
        else if (w_ard_hs && (w_rd_addr == ADDR_AP_CTRL))
            r_int_ap_ready <= 1'b0;
    end
end

// r_int_auto_restart
always @(posedge ACLK) begin
    if (ARESET) r_int_auto_restart <= 1'b0;
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_AP_CTRL) && i_WSTRB[0])
            r_int_auto_restart <= i_WDATA[7];
    end
end

// r_int_gie
always @(posedge ACLK) begin
    if (ARESET) r_int_gie <= 1'b0;
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_GIE) && i_WSTRB[0])
            r_int_gie <= i_WDATA[0];
    end
end

// r_int_ier
always @(posedge ACLK) begin
    if (ARESET) r_int_ier <= 1'b0;
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_IER) && i_WSTRB[0])
            r_int_ier <= i_WDATA[1:0];
    end
end

// r_int_isr[0]
always @(posedge ACLK) begin
    if (ARESET) r_int_isr[0] <= 1'b0;
    else if (ACLK_EN) begin
        if (r_int_ier[0] && i_ap_done)
            r_int_isr[0] <= 1'b1;
        else if (w_ard_hs && (w_rd_addr == ADDR_ISR))
            r_int_isr[0] <= 1'b0; // clear on read
    end
end

// r_int_isr[1]
always @(posedge ACLK) begin
    if (ARESET) r_int_isr[1] <= 1'b0;
    else if (ACLK_EN) begin
        if (r_int_ier[1] && i_ap_ready)
            r_int_isr[1] <= 1'b1;
        else if (w_ard_hs && (w_rd_addr == ADDR_ISR))
            r_int_isr[1] <= 1'b0; // clear on read
    end
end

// r_int_rdma_ptr
always @(posedge ACLK) begin
    if (ARESET) r_int_rdma_param_ptr <= {DMA_DATA_WIDTH{1'b0}};
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_RDMA_MEM_PTR_PARAM_0 ))
            r_int_rdma_param_ptr <= (i_WDATA & r_wr_mask) | (r_int_rdma_param_ptr & (~r_wr_mask));
    end
end
always @(posedge ACLK) begin
    if (ARESET) r_int_rdma_infmap_ptr <= {DMA_DATA_WIDTH{1'b0}};
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_RDMA_MEM_PTR_INFMAP_0))
            r_int_rdma_infmap_ptr <= (i_WDATA & r_wr_mask) | (r_int_rdma_infmap_ptr & (~r_wr_mask));
    end
end

// // r_int_wdma_transfer_byte
// always @(posedge ACLK) begin
//     if (ARESET)
//         r_int_wdma_transfer_byte <= {DMA_DATA_WIDTH{1'b0}};
//     else if (ACLK_EN) begin
//         if (w_wr_hs && (r_wr_addr == ADDR_WDMA_TRANSFER_BYTE_DATA_0))
//             r_int_wdma_transfer_byte <= (i_WDATA & r_wr_mask) | (r_int_wdma_transfer_byte & (~r_wr_mask));
//     end
// end

// r_int_wdma_mem_ptr
always @(posedge ACLK) begin
    if (ARESET) r_int_wdma_mem_ptr <= {DMA_DATA_WIDTH{1'b0}};
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_WDMA_MEM_PTR_DATA_0))
            r_int_wdma_mem_ptr <= (i_WDATA & r_wr_mask) | (r_int_wdma_mem_ptr & (~r_wr_mask));
    end
end

// r_int_axi00_ptr0
always @(posedge ACLK) begin
    if (ARESET) r_int_axi00_ptr0 <= {DMA_DATA_WIDTH{1'b0}};
    else if (ACLK_EN) begin
        if (w_wr_hs && (r_wr_addr == ADDR_AXI00_PTR0_DATA_0))
            r_int_axi00_ptr0 <= (i_WDATA & r_wr_mask) | (r_int_axi00_ptr0 & (~r_wr_mask));
    end
end

// // r_int_value_to_add
// always @(posedge ACLK) begin
//     if (ARESET) r_int_value_to_add <= {DMA_DATA_WIDTH{1'b0}};
//     else if (ACLK_EN) begin
//         if (w_wr_hs && (r_wr_addr == ADDR_VALUE_TO_ADD))
//             r_int_value_to_add <= (i_WDATA & r_wr_mask) | (r_int_value_to_add & (~r_wr_mask));
//     end
// end

//==============================================================================
// Read Data
//==============================================================================
reg  [C_S_AXI_DATA_WIDTH-1:0] r_rd_data  ;
reg  [C_S_AXI_DATA_WIDTH-1:0] n_rd_data  ;

always @(posedge ACLK) begin
    if (ARESET) r_rd_data <= {C_S_AXI_DATA_WIDTH{1'b0}};
    else if ((ACLK_EN) || (w_ard_hs)) begin
        r_rd_data <= n_rd_data ;
    end
end
always @(*) begin
    n_rd_data = {C_S_AXI_DATA_WIDTH{1'b0}};
    case (w_rd_addr)
        ADDR_AP_CTRL: begin
            n_rd_data[0] = r_int_ap_start_param;
            n_rd_data[1] = r_int_task_ap_done;
            n_rd_data[2] = r_int_ap_idle;
            n_rd_data[3] = r_int_ap_ready;
            n_rd_data[4] = r_int_ap_start_infmap;
            n_rd_data[5] = r_int_task_ap_wdma_done;
            n_rd_data[7] = r_int_auto_restart;
            n_rd_data[9] = r_int_interrupt;
        end
        ADDR_GIE: begin
            n_rd_data[0] = r_int_gie;
        end
        ADDR_IER: begin
            n_rd_data[2-1 : 0] = r_int_ier;
        end
        ADDR_ISR: begin
            n_rd_data[2-1 : 0] = r_int_isr;
        end
        ADDR_RDMA_MEM_PTR_PARAM_0: begin
            n_rd_data = r_int_rdma_param_ptr;
        end
        ADDR_RDMA_MEM_PTR_INFMAP_0: begin
            n_rd_data = r_int_rdma_infmap_ptr;
        end
        // ADDR_WDMA_TRANSFER_BYTE_DATA_0: begin
        //     n_rd_data = r_int_wdma_transfer_byte;
        // end
        ADDR_WDMA_MEM_PTR_DATA_0: begin
            n_rd_data = r_int_wdma_mem_ptr;
        end
        ADDR_AXI00_PTR0_DATA_0: begin
            n_rd_data = r_int_axi00_ptr0;
		end  
        // ADDR_VALUE_TO_ADD: begin
        //     n_rd_data = r_int_value_to_add;
        // end
    endcase
end

// synthesis translate_off
always @(posedge ACLK) begin
    if (ACLK_EN) begin
        if (r_int_gie & (~r_int_isr[0]) & r_int_ier[0] & i_ap_done)
            $display ("// Interrupt Monitor : interrupt for i_ap_done detected @ \"%0t\"", $time);
        if (r_int_gie & (~r_int_isr[1]) & r_int_ier[1] & i_ap_ready)
            $display ("// Interrupt Monitor : interrupt for i_ap_ready detected @ \"%0t\"", $time);
    end
end
//synthesis translate_on

//==============================================================================
// Output State signal
//==============================================================================
assign o_AWREADY = (c_state_wr == S_WR_IDLE) ;
assign o_WREADY  = (c_state_wr == S_WR_DATA) ;
assign o_BRESP   = 2'b00;  // OKAY
assign o_BVALID  = (c_state_wr == S_WR_RESP) ;

assign o_ARREADY = (c_state_rd == S_RD_IDLE) ;
assign o_RDATA   = r_rd_data ;
assign o_RRESP   = 2'b00;  // OKAY
assign o_RVALID  = (c_state_rd == S_RD_DATA) ;

assign o_interrupt          = r_int_interrupt          ;
assign o_rdma_param_ptr     = r_int_rdma_param_ptr       ;
assign o_rdma_infmap_ptr    = r_int_rdma_infmap_ptr       ;
// assign o_wdma_transfer_byte = r_int_wdma_transfer_byte ;
assign o_wdma_mem_ptr       = r_int_wdma_mem_ptr       ;
assign o_axi00_ptr0         = r_int_axi00_ptr0         ;
// assign o_value_to_add       = r_int_value_to_add       ;

assign o_ap_start_param  = r_int_ap_start_param  ;
assign o_ap_start_infmap = r_int_ap_start_infmap ;

endmodule
