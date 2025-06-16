//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.01.28
// Design Name: LeNet-5
// Module Name: rd_b_weight
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Read weight in BRAM
//                  input : rd_start_addr
//                  output: (ocht*icht) * weight[kx]
//                  latency: 13 cycle(avarage: 13 cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision 0.01 - File Created
//          1.0(25.01.31) - pipeline unroll : oxt, ocht, icht, kx
//          1.1(25.03.06) - reset_n -> areset
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module rd_b_weight #(
    parameter ICH           = 6  ,
    parameter OCH           = 16 ,
    parameter KX            = 5  ,
    parameter KY            = 5  ,
    parameter ICH_B         = 2  ,
    parameter OCH_B         = 4  ,
    parameter W_BW          = 8  
) ( 
    clk              ,
    areset           ,
    i_run            ,
    o_idle           ,
    o_run            ,
    o_n_ready        ,
    o_en_err         ,
    i_rd_start_addr  ,
    o_ot_idx         ,
    o_ot_weight      ,
    o_ot_valid       ,
    o_ot_done        ,
    b_o_weight_addr  ,
    b_o_weight_ce    ,
    b_o_weight_we    ,
    b_i_weight_q     
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam IS_ICH_1 = (ICH == 1);

// parameter in CNN Block
localparam ICH_T  = ICH / ICH_B ; // 3
localparam OCH_T  = OCH / OCH_B ; // 4

// BRAM
localparam B_WEIGHT_DATA_W  = KX * W_BW; // 40
localparam B_WEIGHT_DATA_D  = (OCH * ICH * KY * KX) / KX; // = 480
localparam B_WEIGHT_ADDR_W  = $clog2(B_WEIGHT_DATA_D); // = 9

// counter
localparam ICH_T_CNT_MAX = ICH_T; // 3
localparam ICH_T_CNT_BW  = $clog2(ICH_T_CNT_MAX) ; // 2
localparam OCH_T_CNT_MAX = OCH_T; // 4
localparam OCH_T_CNT_BW  = $clog2(OCH_T_CNT_MAX) ; // 2

// next read address
localparam RD_ADDR_ICH_T = KY ; // 5
localparam RD_ADDR_OCH_T = (KY * ICH) - (RD_ADDR_ICH_T * (ICH_T_CNT_MAX-1)) ; // 30 - 10

// index
localparam WEIGHT_IDX_MAX = OCH_T * ICH_T ; // 12
localparam WEIGHT_IDX_BW  = $clog2(WEIGHT_IDX_MAX); // 4

// delay
localparam DELAY = WEIGHT_IDX_MAX + 1; // 13

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;

output                         o_idle            ;
output                         o_run             ;
output                         o_n_ready         ;
output                         o_en_err          ;

input  [B_WEIGHT_ADDR_W-1 : 0] i_rd_start_addr   ;

output [WEIGHT_IDX_BW-1 : 0]   o_ot_idx          ;
output [B_WEIGHT_DATA_W-1 : 0] o_ot_weight       ;

output                         o_ot_valid        ;
output                         o_ot_done         ;

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
reg  [ICH_T_CNT_BW-1 : 0] r_ich_t_cnt        ;
reg  [OCH_T_CNT_BW-1 : 0] r_och_t_cnt        ;
wire w_rd_ich_t_max ;
wire w_rd_och_t_max ;

generate
if(!IS_ICH_1) begin
    assign w_rd_ich_t_max = (r_ich_t_cnt == ICH_T_CNT_MAX - 1);
    always @(posedge clk) begin
        if((areset) || (w_rd_ich_t_max) || (o_ot_done)) begin
            r_ich_t_cnt <= {ICH_T_CNT_BW{1'b0}};
        end else if (r_run) begin
            r_ich_t_cnt <= r_ich_t_cnt + 1;
        end
    end
end else begin
    assign w_rd_ich_t_max = r_run;
end
endgenerate

assign w_rd_och_t_max = (r_och_t_cnt == OCH_T_CNT_MAX - 1);
always @(posedge clk) begin
    if((areset) || (o_ot_done)) begin
        r_och_t_cnt <= {OCH_T_CNT_BW{1'b0}};
    end else if (w_rd_ich_t_max) begin
        r_och_t_cnt <= r_och_t_cnt + 1;
    end
end

//==============================================================================
// Read weight Data in BRAM
//==============================================================================
reg  [B_WEIGHT_ADDR_W-1 : 0] r_rd_addr;
always @(posedge clk) begin
    if(areset) begin
        r_rd_addr <= {B_WEIGHT_ADDR_W{1'b0}};
    end else if(i_run) begin 
        r_rd_addr <= i_rd_start_addr;
    end else if((o_n_ready) || (o_ot_done)) begin 
        r_rd_addr <= {B_WEIGHT_ADDR_W{1'b0}};
    end else if(w_rd_ich_t_max) begin 
        r_rd_addr <= r_rd_addr + RD_ADDR_OCH_T;
    end else if(r_run) begin
        r_rd_addr <= r_rd_addr + RD_ADDR_ICH_T;
    end
end

assign b_o_weight_addr = r_rd_addr;
assign b_o_weight_ce   = 1'b1;
assign b_o_weight_we   = 1'b0; // only read

//==============================================================================
// Read BRAM Valid signal
//==============================================================================
reg  r_rd_valid       ;
always @(posedge clk) begin
    if((areset) || (o_ot_done)) begin
        r_rd_valid <= 1'b0;
    end else begin
        r_rd_valid <= r_run;
    end 
end

//==============================================================================
// Count ot_idx
//==============================================================================
reg  [WEIGHT_IDX_BW-1 : 0]  r_ot_idx ;
always @(posedge clk) begin
    if((areset) || (o_ot_done)) begin
        r_ot_idx <= {WEIGHT_IDX_BW{1'b0}};
    end else if(r_rd_valid) begin
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
        r_n_ready <= (r_rd_valid) && (r_ot_idx == WEIGHT_IDX_MAX - 3);
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= (r_rd_valid) && (r_ot_idx == WEIGHT_IDX_MAX - 2);
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;
assign o_n_ready = r_n_ready;
assign o_en_err  = r_en_err;

assign o_ot_idx     = r_ot_idx    ;
assign o_ot_weight  = b_i_weight_q ;

assign o_ot_valid   = r_rd_valid  ;
assign o_ot_done    = r_ot_done   ;

endmodule