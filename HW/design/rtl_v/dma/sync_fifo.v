//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.16
// Design Name: 
// Module Name: sync_fifo
// Project Name: chapter7
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: Synchronize FIFO
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module sync_fifo #(
    parameter FIFO_S_REG = 1  ,
    parameter FIFO_M_REG = 1  ,
    parameter FIFO_W     = 32 ,
    parameter FIFO_D     = 4  
) (
    clk        ,
    areset     ,
    i_s_valid  ,
    o_s_ready  ,
    i_s_data   ,
    o_m_valid  ,
    i_m_ready  ,
    o_m_data   ,
    o_empty    ,
    o_full     
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam FIFO_PTR_BW = $clog2(FIFO_D) ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                clk       ;
input                areset    ;

input                i_s_valid ;
output               o_s_ready ;
input  [FIFO_W-1:0]  i_s_data  ;

output               o_m_valid ;
input                i_m_ready ;
output [FIFO_W-1:0]  o_m_data  ;

output               o_empty   ;
output               o_full    ;

//==============================================================================
// Declaration Submodule Port
//==============================================================================
wire               c_1_skid_i_s_valid ;
wire               c_1_skid_o_s_ready ;
wire [FIFO_W-1:0]  c_1_skid_i_s_data  ;
wire               c_1_skid_o_m_valid ;
wire               c_1_skid_i_m_ready ;
wire [FIFO_W-1:0]  c_1_skid_o_m_data  ;

//==============================================================================
// Declaration Master/Slave Signal
//==============================================================================
wire               w_s_valid ;
wire               w_s_ready ;
wire [FIFO_W-1:0]  w_s_data  ;

wire               w_m_valid ;
wire               w_m_ready ;
wire [FIFO_W-1:0]  w_m_data  ;

//==============================================================================
// Handshake Signal
//==============================================================================
wire w_s_hs ;
wire w_m_hs ;

assign w_s_hs = (w_s_valid) && (w_s_ready) ;
assign w_m_hs = (w_m_valid) && (w_m_ready) ;

//==============================================================================
// Write FIFO Pointer
//==============================================================================
reg  [FIFO_PTR_BW-1 : 0] r_wr_ptr       ;
reg                      r_wr_ptr_round ;
reg  [FIFO_PTR_BW-1 : 0] n_wr_ptr       ;
reg                      n_wr_ptr_round ;

always @(posedge clk) begin
    if(areset ) begin
        r_wr_ptr       <= {FIFO_PTR_BW{1'b0}};
        r_wr_ptr_round <= 1'b0;
    end else if(w_s_hs) begin
        r_wr_ptr       <= n_wr_ptr       ;
        r_wr_ptr_round <= n_wr_ptr_round ;
    end
end
always @(*) begin
    n_wr_ptr       = r_wr_ptr + 'd1 ;
    n_wr_ptr_round = r_wr_ptr_round ;
    if(r_wr_ptr == FIFO_D-1) begin
        n_wr_ptr       = 0 ;
        n_wr_ptr_round = (~r_wr_ptr_round) ;
    end
end

//==============================================================================
// Read FIFO Pointer
//==============================================================================
reg  [FIFO_PTR_BW-1 : 0] r_rd_ptr       ;
reg                      r_rd_ptr_round ;
reg  [FIFO_PTR_BW-1 : 0] n_rd_ptr       ;
reg                      n_rd_ptr_round ;

always @(posedge clk) begin
    if(areset ) begin
        r_rd_ptr       <= {FIFO_PTR_BW{1'b0}};
        r_rd_ptr_round <= 1'b0;
    end else if(w_m_hs) begin
        r_rd_ptr       <= n_rd_ptr       ;
        r_rd_ptr_round <= n_rd_ptr_round ;
    end
end
always @(*) begin
    n_rd_ptr       = r_rd_ptr + 'd1 ;
    n_rd_ptr_round = r_rd_ptr_round ;
    if(r_rd_ptr == (FIFO_D-1)) begin
        n_rd_ptr       = 0 ;
        n_rd_ptr_round = (~r_rd_ptr_round) ;
    end
end

//==============================================================================
// FIFO Mem 
//==============================================================================
reg  [FIFO_W-1 : 0] r_fifo [0 : FIFO_D-1] ;

integer idx_i;
always @(posedge clk) begin
    if(areset ) begin
        for (idx_i = 0; idx_i < FIFO_D; idx_i=idx_i+1) begin : gen_fifo_ini 
            r_fifo[idx_i] <= {FIFO_W{1'b0}};
        end
    end else if(w_s_hs) begin
        r_fifo[r_wr_ptr] <= w_s_data;
    end
end

//==============================================================================
// Master/Slave Output Signal before Skid Buffer
//==============================================================================
assign w_s_ready = (~o_full) ;
assign w_m_valid = (~o_empty) ;
assign w_m_data  = r_fifo[r_rd_ptr] ;

//==============================================================================
// Output State signal
//==============================================================================
assign o_empty = (r_wr_ptr == r_rd_ptr) && (r_wr_ptr_round == r_rd_ptr_round) ;
assign o_full  = (r_wr_ptr == r_rd_ptr) && (r_wr_ptr_round != r_rd_ptr_round) ;

//==============================================================================
// Instantiate Skid Buffer
//==============================================================================
generate 
begin : u_skid_gen
    if(FIFO_S_REG) begin
        wire               c_0_skid_i_s_valid ;
        wire               c_0_skid_o_s_ready ;
        wire [FIFO_W-1:0]  c_0_skid_i_s_data  ;
        wire               c_0_skid_o_m_valid ;
        wire               c_0_skid_i_m_ready ;
        wire [FIFO_W-1:0]  c_0_skid_o_m_data  ;
        
        assign c_0_skid_i_s_valid = i_s_valid ;
        assign c_0_skid_i_s_data  = i_s_data  ;
        assign c_0_skid_i_m_ready = w_s_ready ;
        
        skid_buffer #(
            .DATA_WIDTH (FIFO_W)
        ) u0_skid_buffer (
            .clk        (clk        ) ,
            .areset     (areset     ) ,
            .i_s_valid  (c_0_skid_i_s_valid  ) ,
            .o_s_ready  (c_0_skid_o_s_ready  ) ,
            .i_s_data   (c_0_skid_i_s_data   ) ,
            .o_m_valid  (c_0_skid_o_m_valid  ) ,
            .i_m_ready  (c_0_skid_i_m_ready  ) ,
            .o_m_data   (c_0_skid_o_m_data   ) 
        );
        
        assign o_s_ready = c_0_skid_o_s_ready ;
        assign w_s_valid = c_0_skid_o_m_valid ;
        assign w_s_data  = c_0_skid_o_m_data  ;
    end else begin
        assign o_s_ready = w_s_ready ;
        assign w_s_valid = i_s_valid ;
        assign w_s_data  = i_s_data  ;
    end
end
endgenerate 
generate 
    if(FIFO_M_REG) begin
        assign c_1_skid_i_s_valid = w_m_valid ;
        assign c_1_skid_i_s_data  = w_m_data  ;
        assign c_1_skid_i_m_ready = i_m_ready ;
        
        skid_buffer #(
            .DATA_WIDTH (FIFO_W)
        ) u1_skid_buffer (
            .clk        (clk        ) ,
            .areset     (areset     ) ,
            .i_s_valid  (c_1_skid_i_s_valid  ) ,
            .o_s_ready  (c_1_skid_o_s_ready  ) ,
            .i_s_data   (c_1_skid_i_s_data   ) ,
            .o_m_valid  (c_1_skid_o_m_valid  ) ,
            .i_m_ready  (c_1_skid_i_m_ready  ) ,
            .o_m_data   (c_1_skid_o_m_data   ) 
        );
        
        assign w_m_ready = c_1_skid_o_s_ready ;
        assign o_m_valid = c_1_skid_o_m_valid ;
        assign o_m_data  = c_1_skid_o_m_data  ;
    end else begin
        assign w_m_ready = i_m_ready ;
        assign o_m_valid = w_m_valid ;
        assign o_m_data  = w_m_data  ;
    end
endgenerate 



endmodule