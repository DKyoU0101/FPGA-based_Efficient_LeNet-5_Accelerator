//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.03
// Design Name: LeNet-5
// Module Name: rd_b_fc_weight
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Read weight in BRAM
//                  input : rd_start_addr
//                  output: (OCH_T) * weight[ICH_T]
//                  latency: OCH_T cycle(avarage: OCH_T cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module rd_b_fc_weight #(
    parameter OCH           = 120 ,
    parameter ICH           = 400 ,
    parameter OCH_B         = 8   ,
    parameter ICH_B         = 40  ,
    parameter W_BW          = 8  
) ( 
    clk             ,
    areset          ,
    i_run           ,
    i_rd_start_addr ,
    o_idle          ,
    o_run           ,
    o_en_err        ,
    o_n_ready       ,
    o_ot_valid      ,
    o_ot_done       ,
    o_ot_idx        ,
    o_ot_weight     ,
    b_o_weight_addr ,
    b_o_weight_ce   ,
    b_o_weight_we   ,
    b_i_weight_q    
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// parameter in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 15
localparam ICH_T  = ICH / ICH_B ; // 10

// BRAM
localparam B_WEIGHT_DATA_W  = ICH_T * W_BW; // 80
localparam B_WEIGHT_DATA_D  = OCH * ICH_B ; // 4800 = 120 * 40
localparam B_WEIGHT_ADDR_W  = $clog2(B_WEIGHT_DATA_D); // 13

// counter
localparam OCH_T_CNT_BW  = $clog2(OCH_T) ; // 4

// index
localparam WEIGHT_O_IDX_BW  = $clog2(OCH_T); // 4

// delay
localparam DELAY = OCH_T + 1; // 16

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;

input  [B_WEIGHT_ADDR_W-1 : 0] i_rd_start_addr   ;

output                         o_idle            ;
output                         o_run             ;
output                         o_en_err          ;
output                         o_n_ready         ;
output                         o_ot_valid        ;
output                         o_ot_done         ;

output [WEIGHT_O_IDX_BW-1 : 0] o_ot_idx          ;
output [B_WEIGHT_DATA_W-1 : 0] o_ot_weight       ;

output [B_WEIGHT_ADDR_W-1 : 0] b_o_weight_addr   ;
output                         b_o_weight_ce     ;
output                         b_o_weight_we     ;
// output [(B_WEIGHT_DATA_W-1):0] b_o_weight_d      ; // not using write bram
input  [B_WEIGHT_DATA_W-1 : 0] b_i_weight_q      ;

//==============================================================================
// Capture Input Signal
//==============================================================================
reg r_run           ;
always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
    end else if(i_run) begin
        r_run <= 1'b1;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
    end 
end

//==============================================================================
// Count BRAM Address
//==============================================================================
reg  [OCH_T_CNT_BW-1 : 0] r_och_t_cnt        ;
wire w_rd_och_t_max ;
reg  r_och_t_cnt_valid;

assign w_rd_och_t_max = (r_och_t_cnt == OCH_T - 1);
always @(posedge clk) begin
    if((areset) || (w_rd_och_t_max) || (o_ot_done)) begin
        r_och_t_cnt <= {OCH_T_CNT_BW{1'b0}};
    end else if (r_run) begin
        r_och_t_cnt <= r_och_t_cnt + 1;
    end
end

always @(posedge clk) begin
    if((areset) || (w_rd_och_t_max)) begin
        r_och_t_cnt_valid <= 1'b0;
    end else if (i_run) begin
        r_och_t_cnt_valid <= 1'b1;
    end
end

//==============================================================================
// Read weight Data in BRAM
//==============================================================================
reg  [B_WEIGHT_ADDR_W-1 : 0] r_rd_addr;
always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_rd_addr <= {B_WEIGHT_ADDR_W{1'b0}};
    end else if(i_run) begin 
        r_rd_addr <= i_rd_start_addr;
    end else if(r_och_t_cnt_valid) begin
        r_rd_addr <= r_rd_addr + ICH_B ;
    end
end

assign b_o_weight_addr = r_rd_addr;
assign b_o_weight_ce   = 1'b1;
assign b_o_weight_we   = 1'b0; // only read

//==============================================================================
// Count ot_idx
//==============================================================================
reg  [WEIGHT_O_IDX_BW-1 : 0]  r_ot_idx ;
always @(posedge clk) begin
    if((areset) || (o_ot_done)) begin
        r_ot_idx <= {WEIGHT_O_IDX_BW{1'b0}};
    end else if(o_ot_valid) begin
        r_ot_idx <= r_ot_idx + 1;
    end 
end

//==============================================================================
// Output State signal
//==============================================================================
reg  r_en_err        ;
always @(posedge clk) begin
    if(areset) begin
        r_en_err <= 1'b0;
    end else if((r_run) && (i_run) && (!o_ot_done)) begin
        r_en_err <= 1'b1;
    end 
end
reg  r_n_ready        ;
always @(posedge clk) begin
    if(areset) begin
        r_n_ready <= 1'b0;
    end else begin
        r_n_ready <= (r_och_t_cnt == OCH_T - 2);
    end 
end
reg  r_ot_valid       ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_valid <= 1'b0;
    end else begin
        r_ot_valid <= r_och_t_cnt_valid;
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= r_n_ready;
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;

assign o_en_err   = r_en_err   ;
assign o_n_ready  = r_n_ready  ;
assign o_ot_valid = r_ot_valid ;
assign o_ot_done  = r_ot_done  ;

assign o_ot_idx     = r_ot_idx    ;
assign o_ot_weight  = b_i_weight_q ;

endmodule