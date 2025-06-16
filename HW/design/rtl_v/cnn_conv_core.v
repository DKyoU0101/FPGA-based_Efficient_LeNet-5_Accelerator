//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.04
// Design Name: LeNet-5
// Module Name: cnn_conv_core
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Convolution Arithmetic in Convolutional Layer
//                  input : (KY) * infmap[ICH_T*IX_T], 
//                          (KY) * weight[OCH_T*ICH_T*KX],
//                          bias[OCH_T]
//                  output: (OX_T) * otfmap[OCH_T]
//                  otfmap = infmap * weight
//                  latency: 99~107 cycle(avarage: 103 cycle), delay = latency
//                          (random seed:5, LOOP_NUM:10)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           1.0(25.03.05) - Major Rivision
//           1.1(25.03.09) - include ReLU function
//           1.2(25.04.10) - remove b_otfmap
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"

module cnn_conv_core #(
    parameter MULT_DELAY    = 3  ,
    parameter ACC_DELAY     = 1  ,
    parameter AB_DELAY      = 1  ,
    parameter ICH           = 6  ,
    parameter OCH           = 16 ,
    parameter KX            = 5  ,
    parameter KY            = 5  ,
    parameter OX            = 10 ,
    parameter OY            = 10 ,
    parameter ICH_B         = 2  ,
    parameter OCH_B         = 4  ,
    parameter OX_B          = 2  ,
    parameter I_F_BW        = 8  ,
    parameter W_BW          = 8  ,
    parameter B_BW          = 16 ,
    parameter PARA_B_BW     = 2  ,
    parameter PARA_T_BW     = 4  ,
    parameter B_SHIFT       = 0  ,
    parameter M_INV         = 512  
) (
    clk                 ,
    areset              ,
    i_run               ,
    i_scaling           ,
    o_idle              ,
    o_run               ,
    o_en_err            ,
    o_n_ready           ,
    o_ot_done           ,
    i_infmap_start_addr ,
    i_infmap_start_word ,
    i_weight_start_addr ,
    i_bias_start_addr   ,
    o_ot_valid          ,
    o_ot_scaled_idx     ,
    o_ot_scaled_otfmap  ,
    b_o_infmap_addr     ,
    b_o_infmap_ce       ,
    b_o_infmap_we       ,
    b_i_infmap_q        ,
    b_o_weight_addr     ,
    b_o_weight_ce       ,
    b_o_weight_we       ,
    b_i_weight_q        ,
    b_o_bias_addr       ,
    b_o_bias_ce         ,
    b_o_bias_we         ,
    b_i_bias_q          
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam IS_ICH_1 = (ICH == 1);

// FSM 
localparam S_IDLE       = 0 ;
localparam S_RD_IF_W    = 1 ;
localparam S_MULT_SHIFT = 2 ;
localparam S_ACC_WAIT   = 3 ;
localparam S_SCALING    = 4 ;
localparam S_DONE       = 5 ;
localparam STATE_BW = S_DONE + 1 ; // One hot

// parameter size in CNN
localparam IX   = OX + KX - 1 ; // 14
localparam IY   = OY + KY - 1 ; // 14

// parameter size in CNN Block
localparam ICH_T  = ICH / ICH_B ; // 3
localparam OCH_T  = OCH / OCH_B ; // 4
localparam OX_T   = OX  / OX_B  ; // 5
localparam IX_T   = OX_T + KX - 1 ; // 9

// parameter quantization scale
localparam M_INV_LOG2 = $clog2(M_INV) ; // 9
localparam ADDED_ROUNDING = M_INV / 2 ; // 256

// parameter bit width
localparam M_BW     = I_F_BW + W_BW; // 16 = I_F_BW + W_BW
localparam ACC_BW   = M_BW + $clog2(ICH_T); // 18; Accum parallel_mult output
localparam O_F_BW   = ACC_BW + $clog2(ICH_B*KY*KX); // 24; Add Kernel 

// BRAM
localparam B_COL_NUM        = 32 / I_F_BW ; // 4
localparam B_INFMAP_DATA_W  = 32 ;
localparam B_INFMAP_DATA_D  = (ICH * IY * IX) / B_COL_NUM; // 294
localparam B_INFMAP_ADDR_W  = $clog2(B_INFMAP_DATA_D); // 9
localparam B_WEIGHT_DATA_W  = KX * W_BW; // 40
localparam B_WEIGHT_DATA_D  = (OCH * ICH * KY * KX) / KX; // 480
localparam B_WEIGHT_ADDR_W  = $clog2(B_WEIGHT_DATA_D); // 9
localparam B_BIAS_DATA_W    = B_BW ; // 16
localparam B_BIAS_DATA_D    = OCH  ; // 16
localparam B_BIAS_ADDR_W    = $clog2(B_BIAS_DATA_D); // 4


// Core Memory Size
localparam CORE_INFMAP_W = IX_T * I_F_BW ; // 72
localparam CORE_INFMAP_D = ICH_T ; // 3
localparam CORE_WEIGHT_W = KX * W_BW ; // 40
localparam CORE_WEIGHT_D = OCH_T * ICH_T ; // 12
localparam CORE_OTFMAP_W = O_F_BW ; // 24
localparam CORE_OTFMAP_D = OCH_T * OX_T ; // 20
localparam CORE_BIAS_W   = B_BW  ; // 16
localparam CORE_BIAS_D   = OCH_T ; // 4

// parallel multiplier
localparam MULT_OPS = OCH_T * ICH_T * OX_T ; // 60

// counter (cnt_max > 2)
localparam MSFT_CNT_MAX = (OX_T * OCH_T * ICH_T * KX) / MULT_OPS ; // 5
localparam MSFT_CNT_BW  = $clog2(MSFT_CNT_MAX) ; // 3
localparam KY_CNT_MAX   = KY ; // 5
localparam KY_CNT_BW    = $clog2(KY_CNT_MAX) ; // 3
localparam ACC_CNT_MAX  = MULT_DELAY + ACC_DELAY + 1 ; // 5
localparam ACC_CNT_BW   = $clog2(ACC_CNT_MAX) ; // 3
localparam AB_CNT_MAX   = OX_T ; // 5
localparam AB_CNT_BW    = $clog2(AB_CNT_MAX) ; // 3

// next read address
localparam INFMAP_CNT_IX_T_MAX = $rtoi($ceil(IX_T*1.0 / B_COL_NUM*1.0)) ; // 3
localparam RD_N_ADDR_WEIGHT    = 1 ;

// index
localparam INFMAP_WORD_MAX = B_COL_NUM ; // 4
localparam INFMAP_WORD_BW  = $clog2(INFMAP_WORD_MAX) ; // 2
localparam INFMAP_IDX_MAX  = ICH_T; // 3
localparam INFMAP_IDX_BW   = (!IS_ICH_1) ? ($clog2(INFMAP_IDX_MAX)) : (1) ; // 2
localparam WEIGHT_IDX_MAX  = OCH_T * ICH_T ; // 12
localparam WEIGHT_IDX_BW   = $clog2(WEIGHT_IDX_MAX); // 4
localparam OTFMAP_IDX_MAX  = OCH_T * OX_T; // 20
localparam OTFMAP_IDX_BW   = $clog2(OTFMAP_IDX_MAX) ; // 5
localparam BIAS_IDX_MAX    = OCH_T; // 4
localparam BIAS_IDX_BW     = $clog2(BIAS_IDX_MAX) ; // 2
localparam SCALED_IDX_MAX  = OX_T ; // 5
localparam SCALED_IDX_BW   = $clog2(SCALED_IDX_MAX) ; // 3

// scaled output feature map
localparam QNT_OTFMAP_BW = O_F_BW - M_INV_LOG2; // 15
localparam QNT_MIN = -(1 << (I_F_BW-1)); // -128
localparam QNT_MAX = (1 << (I_F_BW-1)) - 1; // 127
localparam SCALED_OTFMAP_BW = OCH_T * I_F_BW ; // 32

// // delay
// localparam DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                           clk                 ;
input                           areset              ;

input                           i_run               ;
input                           i_scaling           ;

output                          o_idle              ;
output                          o_run               ;
output                          o_en_err            ;
output                          o_n_ready           ;
output                          o_ot_done           ;

input  [B_INFMAP_ADDR_W-1 : 0]  i_infmap_start_addr ;
input  [INFMAP_WORD_BW -1 : 0]  i_infmap_start_word ;
input  [B_WEIGHT_ADDR_W-1 : 0]  i_weight_start_addr ;
input  [B_BIAS_ADDR_W-1 : 0]    i_bias_start_addr   ;

output                          o_ot_valid          ;
output [SCALED_IDX_BW-1 : 0]    o_ot_scaled_idx     ;
output [SCALED_OTFMAP_BW-1 : 0] o_ot_scaled_otfmap  ;

output [B_INFMAP_ADDR_W-1 : 0]  b_o_infmap_addr     ;
output                          b_o_infmap_ce       ;
output                          b_o_infmap_we       ;
// output [B_INFMAP_DATA_W-1 : 0]  b_o_infmap_d        ; // not using write bram
input  [B_INFMAP_DATA_W-1 : 0]  b_i_infmap_q        ;

output [B_WEIGHT_ADDR_W-1 : 0]  b_o_weight_addr     ;
output                          b_o_weight_ce       ;
output                          b_o_weight_we       ;
// output [B_WEIGHT_DATA_W-1 : 0]  b_o_weight_d        ; // not using write bram
input  [B_WEIGHT_DATA_W-1 : 0]  b_i_weight_q        ;

output [B_BIAS_ADDR_W-1 : 0]    b_o_bias_addr       ;
output                          b_o_bias_ce         ;
output                          b_o_bias_we         ;
// output [B_BIAS_DATA_W-1 : 0]    b_o_bias_d          ; // not using write bram
input  [B_BIAS_DATA_W-1 : 0]    b_i_bias_q          ;

//==============================================================================
// Declaration Submodule Port
//==============================================================================
wire                          c_infmap_i_run             ;
wire                          c_infmap_o_idle            ;
wire                          c_infmap_o_run             ;
wire                          c_infmap_o_n_ready         ;
wire                          c_infmap_o_en_err          ;
wire [B_INFMAP_ADDR_W-1  : 0] c_infmap_i_rd_start_addr   ;
wire [INFMAP_WORD_BW-1   : 0] c_infmap_i_rd_start_word   ;
wire [INFMAP_IDX_BW-1 : 0]    c_infmap_o_ot_idx          ;
wire [(IX_T*I_F_BW)-1   : 0]  c_infmap_o_ot_infmap       ;
wire                          c_infmap_o_ot_valid        ;
wire                          c_infmap_o_ot_done         ;

wire                         c_weight_i_run             ;
wire                         c_weight_o_idle            ;
wire                         c_weight_o_run             ;
wire                         c_weight_o_n_ready         ;
wire                         c_weight_o_en_err          ;
wire [B_WEIGHT_ADDR_W-1 : 0] c_weight_i_rd_start_addr   ;
wire [WEIGHT_IDX_BW-1 : 0]   c_weight_o_ot_idx          ;
wire [B_WEIGHT_DATA_W-1 : 0] c_weight_o_ot_weight       ;
wire                         c_weight_o_ot_valid        ;
wire                         c_weight_o_ot_done         ;

wire                         c_prmult_i_run           ;
wire                         c_prmult_o_idle          ;
wire                         c_prmult_o_run           ;
wire                         c_prmult_o_n_ready       ;
wire [MULT_OPS*I_F_BW-1 : 0] c_prmult_i_in0           ;
wire [MULT_OPS*W_BW  -1 : 0] c_prmult_i_in1           ;
wire                         c_prmult_o_valid         ;
wire [MULT_OPS*M_BW  -1 : 0] c_prmult_o_result        ;

wire                         c_bias_i_run             ;
wire                         c_bias_o_idle            ;
wire                         c_bias_o_run             ;
wire                         c_bias_o_n_ready         ;
wire                         c_bias_o_en_err          ;
wire [B_BIAS_ADDR_W-1 : 0]   c_bias_i_rd_start_addr   ;
wire [BIAS_IDX_BW-1 : 0]     c_bias_o_ot_idx          ;
wire [B_BIAS_DATA_W-1 : 0]   c_bias_o_ot_bias         ;
wire                         c_bias_o_ot_valid        ;
wire                         c_bias_o_ot_done         ;

//==============================================================================
// Declaration FSM
//==============================================================================
reg  [(STATE_BW-1):0] c_state;
reg  [(STATE_BW-1):0] n_state;
always @(posedge clk) begin
    if(areset) begin
        c_state <= (1 << S_IDLE);
    end else begin
        c_state <= n_state;
    end	
end

//==============================================================================
// Capture Input Signal
//==============================================================================
reg  r_run           ;
reg  r_scaling       ;
always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
        r_scaling <= 1'b0;
    end else if(i_run) begin
        r_run <= 1'b1;
        r_scaling <= i_scaling;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
        r_scaling <= 1'b0;
    end 
end

//==============================================================================
// Counter: mult_shift, ky, acc, add_bias
//==============================================================================
reg  [MSFT_CNT_BW-1 : 0] r_msft_cnt ;
reg  [KY_CNT_BW-1   : 0] r_ky_cnt   ;
reg  [ACC_CNT_BW-1  : 0] r_acc_cnt  ;
reg  [AB_CNT_BW-1   : 0] r_add_bias_cnt  ;

reg  r_add_bias_cnt_valid ;

reg  r_msft_cnt_done ;
reg  r_ky_cnt_done   ;
reg  r_acc_cnt_done  ;
reg  r_add_bias_cnt_done  ;

reg  r_acc_cnt_done_shift;

// counter
always @(posedge clk) begin
    if((areset) || (r_msft_cnt_done)) begin
        r_msft_cnt <= {MSFT_CNT_BW{1'b0}};
    end else if (c_state[S_MULT_SHIFT]) begin
        r_msft_cnt <= r_msft_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((r_msft_cnt_done) && (r_ky_cnt_done))) begin
        r_ky_cnt <= {KY_CNT_BW{1'b0}};
    end else if (r_msft_cnt_done) begin
        r_ky_cnt <= r_ky_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || (r_acc_cnt_done)) begin
        r_acc_cnt <= {ACC_CNT_BW{1'b0}};
    end else if (c_prmult_o_valid) begin
        r_acc_cnt <= r_acc_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || (r_add_bias_cnt_done)) begin
        r_add_bias_cnt <= {AB_CNT_BW{1'b0}};
    end else if (r_add_bias_cnt_valid) begin
        r_add_bias_cnt <= r_add_bias_cnt + 1;
    end
end

// count valid
always @(posedge clk) begin
    if((areset) || (r_add_bias_cnt_done)) begin
        r_add_bias_cnt_valid <= 1'b0;
    end else if((c_state[S_ACC_WAIT]) && (r_acc_cnt_done_shift) && (r_scaling)) begin
        r_add_bias_cnt_valid <= 1'b1;
    end
end

// count done
always @(posedge clk) begin
    if(areset) begin
        r_msft_cnt_done <= 1'b0;
    end else begin
        r_msft_cnt_done <= (r_msft_cnt == MSFT_CNT_MAX-2);
    end
end
always @(posedge clk) begin
    if((areset) || ((r_msft_cnt_done) && (r_ky_cnt_done))) begin
        r_ky_cnt_done <= 1'b0;
    end else if((r_msft_cnt_done) && (r_ky_cnt == KY_CNT_MAX-2)) begin
        r_ky_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if(areset) begin
        r_acc_cnt_done <= 1'b0;
    end else begin
        r_acc_cnt_done <= (r_acc_cnt == ACC_CNT_MAX-2);
    end
end
always @(posedge clk) begin
    if(areset) begin
        r_add_bias_cnt_done <= 1'b0;
    end else begin
        r_add_bias_cnt_done <= (r_add_bias_cnt == AB_CNT_MAX-2);
    end
end

// shift
always @(posedge clk) begin
    if(areset) begin
        r_acc_cnt_done_shift <= 1'b0;
    end else begin
        r_acc_cnt_done_shift <= r_acc_cnt_done;
    end
end


//==============================================================================
//  Done Read infmap, weight
//==============================================================================
reg  r_rd_i_or_w_done;
reg  r_rd_i_w_done;

always @(posedge clk) begin
    if((areset) || (r_rd_i_w_done)) begin
        r_rd_i_or_w_done <= 1'b0;
    end else if((c_infmap_o_n_ready) || (c_weight_o_n_ready)) begin
        r_rd_i_or_w_done <= 1'b1;
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_rd_i_w_done <= 1'b0;
    end else begin
        r_rd_i_w_done <= ((c_infmap_o_n_ready) && (c_weight_o_n_ready)) 
            || (((c_infmap_o_n_ready) || (c_weight_o_n_ready)) && (r_rd_i_or_w_done));
    end
end

//==============================================================================
// Accumulate Mult Result
//==============================================================================
reg  signed [ACC_BW-1 : 0] r_acc_mult [0 : CORE_OTFMAP_D-1] ;
reg  signed [ACC_BW-1 : 0] w_acc_mult [0 : CORE_OTFMAP_D-1] ;

reg  signed [M_BW-1 : 0] w_mult_out [0 : MULT_OPS-1] ;

reg  r_acc_mult_valid ;

genvar g_och, g_ox;
integer g_ich;
generate
    for (g_och = 0; g_och < OCH_T; g_och = g_och + 1) begin : gen_acc_och
        for (g_ox = 0; g_ox < OX_T; g_ox = g_ox + 1) begin : gen_acc_ox
            always @(*) begin
                w_acc_mult[(g_och*OX_T) + g_ox] = {ACC_BW{1'b0}};
                for (g_ich = 0; g_ich < ICH_T; g_ich = g_ich + 1) begin : gen_acc_ich
                    w_mult_out[(g_och*ICH_T*OX_T) + (g_ich*OX_T) + g_ox] 
                        = c_prmult_o_result[((g_och*ICH_T*OX_T) + (g_ich*OX_T) + g_ox)*M_BW +: M_BW];
                    
                    w_acc_mult[(g_och*OX_T) + g_ox] = w_acc_mult[(g_och*OX_T) + g_ox]
                        + w_mult_out[(g_och*ICH_T*OX_T) + (g_ich*OX_T) + g_ox];
                end
            end
            always @(posedge clk) begin
                if((areset) || (!c_prmult_o_valid)) begin
                    r_acc_mult[(g_och*OX_T) + g_ox] <= {ACC_BW{1'b0}};
                end else begin
                    r_acc_mult[(g_och*OX_T) + g_ox] <=  w_acc_mult[(g_och*OX_T) + g_ox];
                end
            end
            
        end
    end 
    always @(posedge clk) begin
        if(areset) begin
            r_acc_mult_valid <= 1'b0;
        end else begin
            r_acc_mult_valid <= c_prmult_o_valid;
        end
    end
endgenerate

//==============================================================================
//  Update Core Otfmap: rd otfmap, wr otfmap, add bias
//==============================================================================
reg  r_update_core_otfmap;

always @(posedge clk) begin
    if((areset) || (r_add_bias_cnt_done)) begin
        r_update_core_otfmap <= 1'b0;
    end else if((c_state[S_ACC_WAIT]) && (r_acc_cnt_done_shift) && (r_scaling)) begin
        r_update_core_otfmap <= 1'b1;
    end
end

//==============================================================================
// Inner Core Register Memory
//==============================================================================
reg  [CORE_INFMAP_D*CORE_INFMAP_W-1 : 0] r_core_infmap ;
reg  [CORE_WEIGHT_D*CORE_WEIGHT_W-1 : 0] r_core_weight ;
reg  signed [CORE_OTFMAP_W-1 : 0] r_core_otfmap [0 : CORE_OTFMAP_D-1] ;
reg  signed [CORE_BIAS_W-1 : 0]   r_core_bias   [0 : CORE_BIAS_D-1]   ;

reg  [CORE_INFMAP_D*CORE_INFMAP_W-1 : 0] w_core_infmap ;
reg  [CORE_WEIGHT_D*CORE_WEIGHT_W-1 : 0] w_core_weight ;
reg  signed [CORE_OTFMAP_W-1 : 0] w_core_otfmap [0 : CORE_OTFMAP_D-1] ;
reg  signed [CORE_BIAS_W-1 : 0]   w_core_bias   [0 : CORE_BIAS_D-1]   ;

reg  signed [CORE_OTFMAP_W-1 : 0] w_prmult_result [0 : CORE_OTFMAP_D-1] ;

integer g_i;
generate
if(!IS_ICH_1) begin
    always @(*) begin
        w_core_infmap = r_core_infmap;
        if(c_infmap_o_ot_valid) begin
            w_core_infmap = {c_infmap_o_ot_infmap, 
                r_core_infmap[CORE_INFMAP_D*CORE_INFMAP_W-1 : CORE_INFMAP_W]};
        end else if(c_state[S_MULT_SHIFT]) begin
            for (g_i = 0; g_i < CORE_INFMAP_D; g_i = g_i + 1) begin : gen_core_infmap
                w_core_infmap[g_i*CORE_INFMAP_W +: CORE_INFMAP_W] 
                    = {{I_F_BW{1'b0}}, r_core_infmap[(g_i*CORE_INFMAP_W) + (I_F_BW) +: (CORE_INFMAP_W-I_F_BW)]};
            end
        end
    end
end else begin
    always @(*) begin
        w_core_infmap = r_core_infmap;
        if(c_infmap_o_ot_valid) begin
            w_core_infmap = c_infmap_o_ot_infmap;
        end else if(c_state[S_MULT_SHIFT]) begin
            w_core_infmap = {{I_F_BW{1'b0}}, r_core_infmap[I_F_BW +: CORE_INFMAP_W-I_F_BW]};
        end
    end
end
endgenerate

integer g_w;
generate
    always @(*) begin
        w_core_weight = r_core_weight;
        if(c_weight_o_ot_valid) begin
            w_core_weight = {c_weight_o_ot_weight,
                    r_core_weight[CORE_WEIGHT_D*CORE_WEIGHT_W-1 : CORE_WEIGHT_W]};
        end else if(c_state[S_MULT_SHIFT]) begin
            for (g_w = 0; g_w < CORE_WEIGHT_D; g_w = g_w + 1) begin : gen_core_w
                w_core_weight[g_w*CORE_WEIGHT_W +: CORE_WEIGHT_W] 
                    = {{W_BW{1'b0}}, r_core_weight[(g_w*CORE_WEIGHT_W) + (W_BW) +: (CORE_WEIGHT_W-W_BW)]};
            end
        end
    end
endgenerate

always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_core_infmap <= {CORE_INFMAP_D*CORE_INFMAP_W{1'b0}};
        r_core_weight <= {CORE_WEIGHT_D*CORE_WEIGHT_W{1'b0}};
    end else begin
        r_core_infmap <= w_core_infmap;
        r_core_weight <= w_core_weight;
    end
end

genvar g_o;
generate
    for (g_o = 0; g_o < CORE_OTFMAP_D; g_o = g_o + 1) begin : gen_core_o
        always @(*) begin
            w_prmult_result[g_o] = {{(CORE_OTFMAP_W - ACC_BW){r_acc_mult[g_o][ACC_BW-1]}}, r_acc_mult[g_o]};
            
            w_core_otfmap[g_o] = r_core_otfmap[g_o];
            if(r_update_core_otfmap) begin
                if(g_o == CORE_OTFMAP_D-1) begin
                    w_core_otfmap[g_o] = {CORE_OTFMAP_W{1'b0}};
                end else begin
                    w_core_otfmap[g_o] = r_core_otfmap[g_o+1];
                end
            end else if(r_acc_mult_valid) begin
                w_core_otfmap[g_o] = r_core_otfmap[g_o] + w_prmult_result[g_o];
            end 
        end
        always @(posedge clk) begin
            if((areset) || ((r_scaling) && (o_n_ready))) begin
                r_core_otfmap[g_o] <= {CORE_OTFMAP_W{1'b0}};
            end else begin
                r_core_otfmap[g_o] <= w_core_otfmap[g_o];
            end
        end
    end
endgenerate

genvar g_b;
generate
    for (g_b = 0; g_b < CORE_BIAS_D; g_b = g_b + 1) begin : gen_core_b
        always @(*) begin
            w_core_bias[g_b] = r_core_bias[g_b];
            if(c_bias_o_ot_valid) begin
                if(g_b == CORE_BIAS_D-1) begin
                    w_core_bias[g_b] = c_bias_o_ot_bias;
                end else begin
                    w_core_bias[g_b] = r_core_bias[g_b+1];
                end
            end 
        end
        always @(posedge clk) begin
            if((areset) || (o_n_ready)) begin
                r_core_bias[g_b] <= {CORE_BIAS_W{1'b0}};
            end else begin
                r_core_bias[g_b] <= w_core_bias[g_b];
            end
        end
    end
endgenerate

//==============================================================================
// Control Submodule Input Port: rd_b_infmap 
//==============================================================================
reg  r_infmap_i_run           ;

reg  [(B_INFMAP_ADDR_W+INFMAP_WORD_BW)-1 : 0] r_infmap_index;

always @(posedge clk) begin
    if(areset) begin
        r_infmap_i_run <= 1'b0;
    end else begin
        r_infmap_i_run <= (i_run) || ((r_msft_cnt_done) && (!r_ky_cnt_done));
    end
end

always @(posedge clk) begin
    if((areset) || ((r_msft_cnt_done) && (r_ky_cnt_done))) begin
        r_infmap_index <= {(B_INFMAP_ADDR_W+INFMAP_WORD_BW){1'b0}};
    end else if(i_run) begin 
        r_infmap_index <= {i_infmap_start_addr, i_infmap_start_word};
    end else if(r_msft_cnt_done) begin 
        r_infmap_index <= r_infmap_index + IX;
    end 
end

assign c_infmap_i_run           = r_infmap_i_run           ;
assign c_infmap_i_rd_start_addr = r_infmap_index[(B_INFMAP_ADDR_W+INFMAP_WORD_BW)-1 : INFMAP_WORD_BW] ;
assign c_infmap_i_rd_start_word = r_infmap_index[INFMAP_WORD_BW-1 : 0] ;

//==============================================================================
// Control Submodule Input Port: rd_b_weight 
//==============================================================================
reg                          r_weight_i_run           ;
reg  [B_WEIGHT_ADDR_W-1 : 0] r_weight_i_rd_start_addr ;

always @(posedge clk) begin
    if(areset) begin
        r_weight_i_run <= 1'b0;
    end else begin
        r_weight_i_run <= (i_run) || ((r_msft_cnt_done) && (!r_ky_cnt_done));
    end
end

always @(posedge clk) begin
    if((areset) || ((r_msft_cnt_done) && (r_ky_cnt_done))) begin
        r_weight_i_rd_start_addr <= {B_WEIGHT_ADDR_W{1'b0}};
    end else if(i_run) begin 
        r_weight_i_rd_start_addr <= i_weight_start_addr;
    end else if(r_msft_cnt_done) begin 
        r_weight_i_rd_start_addr <= r_weight_i_rd_start_addr + RD_N_ADDR_WEIGHT;
    end 
end

assign c_weight_i_run           = r_weight_i_run           ;
assign c_weight_i_rd_start_addr = r_weight_i_rd_start_addr ;

//==============================================================================
// Control Submodule Input Port: parallel_mult 
//==============================================================================
reg                          r_prmult_i_run ;
wire [MULT_OPS*I_F_BW-1 : 0] w_prmult_i_in0 ;
wire [MULT_OPS*W_BW  -1 : 0] w_prmult_i_in1 ;

wire signed [I_F_BW-1 : 0] w_prm_in0_arr [0 : (ICH_T*OX_T )-1] ;
wire signed [W_BW  -1 : 0] w_prm_in1_arr [0 : (OCH_T*ICH_T)-1] ;

generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || (r_msft_cnt_done)) begin
            r_prmult_i_run <= 1'b0;
        end else if((c_state[S_RD_IF_W]) && (r_rd_i_w_done)) begin
            r_prmult_i_run <= 1'b1;
        end
    end
end else begin
    always @(posedge clk) begin
        if((areset) || (r_msft_cnt_done)) begin
            r_prmult_i_run <= 1'b0;
        end else if((c_state[S_RD_IF_W]) && (r_rd_i_w_done)) begin
            r_prmult_i_run <= 1'b1;
        end
    end 
end
endgenerate

genvar g_mo, g_mi, g_mx;

// in0
generate
if(!IS_ICH_1) begin
    for (g_mi = 0; g_mi < ICH_T; g_mi = g_mi + 1) begin : gen_in0_ich
        for (g_mx = 0; g_mx < OX_T; g_mx = g_mx + 1) begin : gen_in0_ox
            assign w_prm_in0_arr[(g_mi*OX_T) + (g_mx)]
                = r_core_infmap[(g_mi*CORE_INFMAP_W) + (g_mx*I_F_BW) +: I_F_BW];
            for (g_mo = 0; g_mo < OCH_T; g_mo = g_mo + 1) begin : gen_in0_och
                assign w_prmult_i_in0[((g_mo*ICH_T*OX_T) + (g_mi*OX_T) + (g_mx))*I_F_BW +: I_F_BW]
                    = w_prm_in0_arr[(g_mi*OX_T) + (g_mx)];
            end
        end
    end
end else begin
    for (g_mo = 0; g_mo < OCH_T; g_mo = g_mo + 1) begin : gen_in0_och
        for (g_mx = 0; g_mx < OX_T; g_mx = g_mx + 1) begin : gen_in0_ox
            assign w_prmult_i_in0[((g_mo*OX_T) + (g_mx))*I_F_BW +: I_F_BW]
                = r_core_infmap[(g_mx*I_F_BW) +: I_F_BW];
        end
    end
end
endgenerate

// in1
generate
if(!IS_ICH_1) begin
    for (g_mo = 0; g_mo < OCH_T; g_mo = g_mo + 1) begin : gen_in1_och
        for (g_mi = 0; g_mi < ICH_T; g_mi = g_mi + 1) begin : gen_in1_ich
            assign w_prm_in1_arr[(g_mo*ICH_T) + (g_mi)]
                = r_core_weight[((g_mo*ICH_T) + (g_mi))*CORE_WEIGHT_W +:W_BW];
            for (g_mx = 0; g_mx < OX_T; g_mx = g_mx + 1) begin : gen_in1_ox
                assign w_prmult_i_in1[((g_mo*ICH_T*OX_T) + (g_mi*OX_T) + (g_mx))*W_BW +: W_BW]
                    = w_prm_in1_arr[(g_mo*ICH_T) + (g_mi)];
            end
        end
    end
end else begin
    for (g_mo = 0; g_mo < OCH_T; g_mo = g_mo + 1) begin : gen_in1_och
        for (g_mx = 0; g_mx < OX_T; g_mx = g_mx + 1) begin : gen_in1_ox
            assign w_prmult_i_in1[((g_mo*OX_T) + (g_mx))*W_BW +: W_BW]
                = r_core_weight[(g_mo*CORE_WEIGHT_W) +:W_BW];
        end
    end
end
endgenerate

assign c_prmult_i_run        = r_prmult_i_run          ;
assign c_prmult_i_in0        = w_prmult_i_in0          ;
assign c_prmult_i_in1        = w_prmult_i_in1          ;

//==============================================================================
// Control Submodule Input Port: rd_b_bias 
//==============================================================================
assign c_bias_i_run           = (i_run) && (i_scaling) ;
assign c_bias_i_rd_start_addr = i_bias_start_addr ;

//==============================================================================
//  Add bias
//==============================================================================
reg  signed [O_F_BW-1 : 0] r_add_bias [0 : OCH_T-1];
wire signed [O_F_BW-1 : 0] w_bias_extend [0 : OCH_T-1];

genvar g_ab;
generate
    for (g_ab = 0; g_ab < OCH_T; g_ab = g_ab + 1) begin : gen_ab
        assign w_bias_extend[g_ab] 
            = {{(O_F_BW - B_BW - B_SHIFT){r_core_bias[g_ab][B_BW-1]}}, 
            r_core_bias[g_ab], {B_SHIFT{1'b0}}};
        always @(posedge clk) begin
            if((areset) || (!r_add_bias_cnt_valid)) begin
                r_add_bias[g_ab] <= {O_F_BW{1'b0}};
            end else begin
                r_add_bias[g_ab] <= r_core_otfmap[g_ab * OX_T] + w_bias_extend[g_ab];
            end
        end
    end
endgenerate

reg r_add_bias_valid;

always @(posedge clk) begin
    if(areset) begin
        r_add_bias_valid <= 1'b0;
    end else begin
        r_add_bias_valid <= r_add_bias_cnt_valid;
    end 
end

//==============================================================================
//  Scale and Quantize (+ rounding)
//==============================================================================
wire signed [O_F_BW-1 : 0] w_rounding_otfmap [0 : OCH_T-1];
reg  signed [QNT_OTFMAP_BW-1 : 0] r_qnt_otfmap [0 : OCH_T-1];

genvar g_qnt;
generate
    for (g_qnt = 0; g_qnt < OCH_T; g_qnt = g_qnt + 1) begin : gen_qnt
        assign w_rounding_otfmap[g_qnt] = r_add_bias[g_qnt] + ADDED_ROUNDING;
        always @(posedge clk) begin
            if((areset) || (!r_add_bias_valid)) begin
                r_qnt_otfmap[g_qnt] <= {QNT_OTFMAP_BW{1'b0}};
            end else begin
                r_qnt_otfmap[g_qnt] 
                    <= w_rounding_otfmap[g_qnt][O_F_BW-1 : M_INV_LOG2];
            end
        end
    end
endgenerate

reg r_qnt_otfmap_valid;

always @(posedge clk) begin
    if(areset) begin
        r_qnt_otfmap_valid <= 1'b0;
    end else begin
        r_qnt_otfmap_valid <= r_add_bias_valid;
    end 
end

//==============================================================================
//  Clamping
//==============================================================================
reg  signed [I_F_BW-1 : 0] r_clp_otfmap [0 : OCH_T-1];
reg  signed [I_F_BW-1 : 0] w_clp_otfmap [0 : OCH_T-1];

genvar g_clp;
generate
    for (g_clp = 0; g_clp < OCH_T; g_clp = g_clp + 1) begin : gen_clp
        always @(*) begin
            w_clp_otfmap[g_clp] = r_clp_otfmap[g_clp];
            if(r_qnt_otfmap[g_clp][QNT_OTFMAP_BW-1]) begin
                w_clp_otfmap[g_clp] = 0;
            end else if(|(r_qnt_otfmap[g_clp][QNT_OTFMAP_BW-2 : I_F_BW-1])) begin
                w_clp_otfmap[g_clp] = QNT_MAX;
            end else begin
                w_clp_otfmap[g_clp] = r_qnt_otfmap[g_clp][I_F_BW-1 : 0];
            end
        end
        always @(posedge clk) begin
            if((areset) || (!r_qnt_otfmap_valid)) begin
                r_clp_otfmap[g_clp] <= {I_F_BW{1'b0}};
            end else begin
                r_clp_otfmap[g_clp] <= w_clp_otfmap[g_clp];
            end
        end
    end
endgenerate

reg r_clp_otfmap_valid;

always @(posedge clk) begin
    if(areset) begin
        r_clp_otfmap_valid <= 1'b0;
    end else begin
        r_clp_otfmap_valid <= r_qnt_otfmap_valid;
    end 
end

//==============================================================================
//  Scaled otfmap index Counter 
//==============================================================================
reg  [SCALED_IDX_BW-1 : 0] r_ot_scaled_cnt      ;
reg                        r_ot_scaled_cnt_done ;

always @(posedge clk) begin
    if((areset) || (r_ot_scaled_cnt_done)) begin
        r_ot_scaled_cnt <= {SCALED_IDX_BW{1'b0}};
    end else if(r_clp_otfmap_valid) begin
        r_ot_scaled_cnt <= r_ot_scaled_cnt + 1;
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_ot_scaled_cnt_done <= 1'b0;
    end else begin
        r_ot_scaled_cnt_done <= (r_ot_scaled_cnt == SCALED_IDX_MAX-2);
    end
end

//==============================================================================
// Output Register: State signal
//==============================================================================
reg  r_n_ready        ;
always @(posedge clk) begin
    if(areset) begin
        r_n_ready <= 1'b0;
    end else begin
        r_n_ready <= ((c_state[S_ACC_WAIT]) && (r_acc_cnt_done) && (~r_scaling)) ||
            (r_ot_scaled_cnt == SCALED_IDX_MAX-2);
    end 
end
reg  r_en_err        ;
always @(posedge clk) begin
    if(areset) begin
        r_en_err <= 1'b0;
    end else if((r_run) && (i_run) && (!o_ot_done)) begin
        r_en_err <= 1'b1;
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

//==============================================================================
// Assign output signal
//==============================================================================
assign o_idle    = !r_run;
assign o_run     = r_run;
assign o_n_ready = r_n_ready;
assign o_en_err  = r_en_err;
assign o_ot_done       = r_ot_done   ;

assign o_ot_valid      = r_clp_otfmap_valid  ;
assign o_ot_scaled_idx = r_ot_scaled_cnt  ;

genvar scl_idx;
generate
    for (scl_idx = 0; scl_idx < OCH_T; scl_idx = scl_idx + 1) begin : gen_scl
        assign o_ot_scaled_otfmap[scl_idx*I_F_BW +: I_F_BW] = r_clp_otfmap[scl_idx];
    end
endgenerate

//==============================================================================
// FSM Detail
//==============================================================================
always @(*) begin
    n_state = c_state;
    case (c_state)
        (1 << S_IDLE) : if(i_run) begin 
            n_state = (1 << S_RD_IF_W); 
        end
        (1 << S_RD_IF_W   ) : if(r_rd_i_w_done) begin 
            n_state = (1 << S_MULT_SHIFT); 
        end
        (1 << S_MULT_SHIFT) : if(r_msft_cnt_done) begin 
            if(~r_ky_cnt_done)
                n_state = (1 << S_RD_IF_W); 
            else
                n_state = (1 << S_ACC_WAIT); 
        end
        (1 << S_ACC_WAIT ) : if(r_acc_cnt_done_shift) begin 
            if(r_scaling)
                n_state = (1 << S_SCALING  ); 
            else
                n_state = (1 << S_DONE); 
        end
        (1 << S_SCALING  ) : if(r_ot_scaled_cnt_done) begin 
            n_state = (1 << S_DONE); 
        end
        (1 << S_DONE) : if(i_run) begin 
            n_state = (1 << S_RD_IF_W); 
        end else begin 
            n_state = (1 << S_IDLE); 
        end
    endcase
end

//==============================================================================
// Instantiation Submodule
//==============================================================================
parallel_mult #(
    .MULT_OPS    (MULT_OPS    ) ,
    .MULT_DELAY  (MULT_DELAY  ) ,
    .IN_DATA_BW  (I_F_BW  ) 
    ) u_parallel_mult ( 
    .clk          (clk          ) ,
    .areset       (areset       ) ,
    .i_run        (c_prmult_i_run        ) ,
    .o_idle       (c_prmult_o_idle       ) ,
    .o_run        (c_prmult_o_run        ) ,
    .o_n_ready    (c_prmult_o_n_ready    ) ,
    .i_in0        (c_prmult_i_in0        ) ,
    .i_in1        (c_prmult_i_in1        ) ,
    .o_valid      (c_prmult_o_valid      ) ,
    .o_result     (c_prmult_o_result     ) 
);

rd_b_infmap #( 
    .ICH      (ICH      ) ,
    .KX       (KX       ) ,
    .KY       (KY       ) ,
    .OX       (OX       ) ,
    .OY       (OY       ) ,
    .ICH_B    (ICH_B    ) ,
    .OX_B     (OX_B     ) ,
    .I_F_BW   (I_F_BW   )  
) u_rd_b_infmap ( 
    .clk             (clk             ) ,
    .areset          (areset          ) ,
    .i_run           (c_infmap_i_run           ) ,
    .o_idle          (c_infmap_o_idle          ) ,
    .o_run           (c_infmap_o_run           ) ,
    .o_n_ready       (c_infmap_o_n_ready       ) ,
    .o_en_err        (c_infmap_o_en_err        ) ,
    .i_rd_start_addr (c_infmap_i_rd_start_addr ) ,
    .i_rd_start_word (c_infmap_i_rd_start_word ) ,
    .o_ot_idx        (c_infmap_o_ot_idx        ) ,
    .o_ot_infmap     (c_infmap_o_ot_infmap     ) ,
    .o_ot_valid      (c_infmap_o_ot_valid      ) ,
    .o_ot_done       (c_infmap_o_ot_done       ) ,
    .b_o_infmap_addr (b_o_infmap_addr ) ,
    .b_o_infmap_ce   (b_o_infmap_ce   ) ,
    .b_o_infmap_we   (b_o_infmap_we   ) ,
    .b_i_infmap_q    (b_i_infmap_q    ) 
);

rd_b_weight #(
    .ICH      (ICH     ) ,
    .OCH      (OCH     ) ,
    .KX       (KX      ) ,
    .KY       (KY      ) ,
    .ICH_B    (ICH_B   ) ,
    .OCH_B    (OCH_B   ) ,
    .W_BW     (W_BW    )  
) u_rd_b_weight (
    .clk             (clk             ) ,
    .areset          (areset          ) ,
    .i_run           (c_weight_i_run           ) ,
    .o_idle          (c_weight_o_idle          ) ,
    .o_run           (c_weight_o_run           ) ,
    .o_n_ready       (c_weight_o_n_ready       ) ,
    .o_en_err        (c_weight_o_en_err        ) ,
    .i_rd_start_addr (c_weight_i_rd_start_addr ) ,
    .o_ot_idx        (c_weight_o_ot_idx        ) ,
    .o_ot_weight     (c_weight_o_ot_weight     ) ,
    .o_ot_valid      (c_weight_o_ot_valid      ) ,
    .o_ot_done       (c_weight_o_ot_done       ) ,
    .b_o_weight_addr (b_o_weight_addr ) ,
    .b_o_weight_ce   (b_o_weight_ce   ) ,
    .b_o_weight_we   (b_o_weight_we   ) ,
    .b_i_weight_q    (b_i_weight_q    ) 
);

rd_b_bias #( 
    .OCH   (OCH   ) ,
    .OCH_B (OCH_B ) ,
    .B_BW  (B_BW  ) 
) u_rd_b_bias ( 
    .clk             (clk             ) ,
    .areset          (areset          ) ,
    .i_run           (c_bias_i_run           ) ,
    .o_idle          (c_bias_o_idle          ) ,
    .o_run           (c_bias_o_run           ) ,
    .o_n_ready       (c_bias_o_n_ready       ) ,
    .o_en_err        (c_bias_o_en_err        ) ,
    .i_rd_start_addr (c_bias_i_rd_start_addr ) ,
    .o_ot_idx        (c_bias_o_ot_idx        ) ,
    .o_ot_bias       (c_bias_o_ot_bias       ) ,
    .o_ot_valid      (c_bias_o_ot_valid      ) ,
    .o_ot_done       (c_bias_o_ot_done       ) ,
    .b_o_bias_addr   (b_o_bias_addr   ) ,
    .b_o_bias_ce     (b_o_bias_ce     ) ,
    .b_o_bias_we     (b_o_bias_we     ) ,
    .b_i_bias_q      (b_i_bias_q      ) 
);

endmodule