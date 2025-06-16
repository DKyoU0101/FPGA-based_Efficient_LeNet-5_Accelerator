//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.06
// Design Name: LeNet-5
// Module Name: LeNet5
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: CNN Convolutional Layer
//                  input : infmap, weight, bias, in_idx
//                  output: ot_idx, output(0 ~ 9)
//                  latency:  cycle(avarage:  cycle), delay: cycle(avarage:  cycle)
//                          (random seed:5, LOOP_NUM:10)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"

module LeNet5 #(
    parameter MULT_DELAY    = 3   ,
    parameter ACC_DELAY_C   = 1   ,
    parameter ACC_DELAY_FC  = 0   ,
    parameter AB_DELAY      = 1   ,
    parameter I_F_BW        = 8   ,
    parameter W_BW          = 8   ,  
    parameter B_BW          = 16  ,
    parameter DATA_IDX_BW   = 20  
) (
    clk                    ,
    areset                 ,
    i_in_data_valid        ,
    i_in_data_idx          ,
    o_idle                 ,
    o_run                  ,
    o_data_read_valid      ,
    o_ot_valid             ,
    o_ot_data_idx          ,
    o_ot_data_result       ,
    b_in_o_infmap_addr     ,
    b_in_o_infmap_ce       ,
    b_in_o_infmap_we       ,
    b_in_i_infmap_q        ,
    b_c1_o_infmap_addr     ,
    b_c1_o_infmap_ce       ,
    b_c1_o_infmap_we       ,
    b_c1_o_infmap_d        ,
    b_c1_i_infmap_q        ,
    b_c1_o_weight_addr     ,
    b_c1_o_weight_ce       ,
    b_c1_o_weight_we       ,
    b_c1_i_weight_q        ,
    b_c1_o_bias_addr       ,
    b_c1_o_bias_ce         ,
    b_c1_o_bias_we         ,
    b_c1_i_bias_q          ,
    b_p1_o_pool_addr       ,
    b_p1_o_pool_ce         ,
    b_p1_o_pool_byte_we    ,
    b_p1_o_pool_d          ,
    b_p1_i_pool_q          ,
    b_c2_o_infmap_addr     ,
    b_c2_o_infmap_ce       ,
    b_c2_o_infmap_we       ,
    b_c2_o_infmap_d        ,
    b_c2_i_infmap_q        ,
    b_c2_o_weight_addr     ,
    b_c2_o_weight_ce       ,
    b_c2_o_weight_we       ,
    b_c2_i_weight_q        ,
    b_c2_o_bias_addr       ,
    b_c2_o_bias_ce         ,
    b_c2_o_bias_we         ,
    b_c2_i_bias_q          ,
    b_p2_o_pool_addr       ,
    b_p2_o_pool_ce         ,
    b_p2_o_pool_byte_we    ,
    b_p2_o_pool_d          ,
    b_p2_i_pool_q          ,
    b_fc1_o_infmap_addr    ,
    b_fc1_o_infmap_ce      ,
    b_fc1_o_infmap_we      ,
    b_fc1_o_infmap_d       ,
    b_fc1_i_infmap_q       ,
    b_fc1_o_weight_addr    ,
    b_fc1_o_weight_ce      ,
    b_fc1_o_weight_we      ,
    b_fc1_i_weight_q       ,
    b_fc1_o_bias_addr      ,
    b_fc1_o_bias_ce        ,
    b_fc1_o_bias_we        ,
    b_fc1_i_bias_q         ,
    b_fc1_o_scaled_addr    ,
    b_fc1_o_scaled_ce      ,
    b_fc1_o_scaled_byte_we ,
    b_fc1_o_scaled_d       ,
    b_fc1_i_scaled_q       ,
    b_fc2_o_infmap_addr    ,
    b_fc2_o_infmap_ce      ,
    b_fc2_o_infmap_we      ,
    b_fc2_o_infmap_d       ,
    b_fc2_i_infmap_q       ,
    b_fc2_o_weight_addr    ,
    b_fc2_o_weight_ce      ,
    b_fc2_o_weight_we      ,
    b_fc2_i_weight_q       ,
    b_fc2_o_bias_addr      ,
    b_fc2_o_bias_ce        ,
    b_fc2_o_bias_we        ,
    b_fc2_i_bias_q         ,
    b_fc2_o_scaled_addr    ,
    b_fc2_o_scaled_ce      ,
    b_fc2_o_scaled_byte_we ,
    b_fc2_o_scaled_d       ,
    b_fc2_i_scaled_q       ,
    b_fc3_o_infmap_addr    ,
    b_fc3_o_infmap_ce      ,
    b_fc3_o_infmap_we      ,
    b_fc3_o_infmap_d       ,
    b_fc3_i_infmap_q       ,
    b_fc3_o_weight_addr    ,
    b_fc3_o_weight_ce      ,
    b_fc3_o_weight_we      ,
    b_fc3_i_weight_q       ,
    b_fc3_o_bias_addr      ,
    b_fc3_o_bias_ce        ,
    b_fc3_o_bias_we        ,
    b_fc3_i_bias_q         
);

//==============================================================================
// Layers Parameter
//==============================================================================
    // parameter size in CNN
    localparam CONV_KY = 5;
    localparam CONV_KX = 5;
    
    localparam POOL_KY = 2;
    localparam POOL_KX = 2;
    
    localparam CONV1_OCH = 6  , CONV2_OCH = 16 ;
    localparam CONV1_OY  = 28 , CONV2_OY  = 10 ;
    localparam CONV1_OX  = 28 , CONV2_OX  = 10 ;
    localparam CONV1_ICH = 1  , CONV2_ICH = 6  ;
    localparam CONV1_IY  = 32 , CONV2_IY  = 14 ;
    localparam CONV1_IX  = 32 , CONV2_IX  = 14 ;
    localparam CONV1_B_SHIFT = 0   , CONV2_B_SHIFT = 0   ;
    localparam CONV1_M_INV   = 512 , CONV2_M_INV   = 512 ;
    
    localparam CONV1_O_F_BW  = 21  , CONV2_O_F_BW  = 24 ;
    localparam POOL1_OCH = 6 , POOL2_OCH = 16 ;
    localparam POOL1_ICH = 6 , POOL2_ICH = 16 ;
    localparam POOL1_IY = 28 , POOL2_IY = 10  ;
    localparam POOL1_IX = 28 , POOL2_IX = 10  ;
    
    localparam FC1_OCH = 120 , FC2_OCH = 84  , FC3_OCH = 10  ;
    localparam FC1_ICH = 400 , FC2_ICH = 120 , FC3_ICH = 84  ;
    localparam FC1_B_SCALE = 1   , FC2_B_SCALE = 1   , FC3_B_SCALE = 1   ;
    localparam FC1_M_INV   = 256 , FC2_M_INV   = 256 , FC3_M_INV   = 256 ;
    
    // parameter size in CNN Block
    localparam CONV1_OCH_B = 2 , CONV2_OCH_B = 4 ;
    localparam CONV1_OX_B  = 4 , CONV2_OX_B  = 2 ;
    localparam CONV1_ICH_B = 1 , CONV2_ICH_B = 2 ;
    localparam CONV1_B_BW = 2 ,  CONV2_B_BW = 2 ;
    localparam CONV1_T_BW = 4 ,  CONV2_T_BW = 4 ;
    
    localparam POOL1_OCH_B = 2 , POOL2_OCH_B = 4 ;
    localparam POOL1_ICH_B = 2 , POOL2_ICH_B = 4 ;
    localparam POOL1_IX_B  = 4 , POOL2_IX_B  = 2 ;
    localparam POOL1_B_BW  = 2 , POOL2_B_BW  = 2 ;
    localparam POOL1_T_BW  = 3 , POOL2_T_BW  = 3 ;
    
    localparam FC1_OCH_B = 8  , FC2_OCH_B = 4  , FC3_OCH_B = 2 ;
    localparam FC1_ICH_B = 80 , FC2_ICH_B = 24 , FC3_ICH_B = 14 ;
    localparam FC1_B_BW = 7 , FC2_B_BW = 5 , FC3_B_BW = 4 ;
    localparam FC1_T_BW = 4 , FC2_T_BW = 6 , FC3_T_BW = 3 ;
    localparam FC1_RELU = 1 , FC2_RELU = 1 , FC3_RELU = 0 ;
    localparam FC1_IS_FINAL_LAYER = 0 , FC2_IS_FINAL_LAYER = 0 , FC3_IS_FINAL_LAYER = 1 ;
    
    localparam CONV1_OCH_T = (CONV1_OCH / CONV1_OCH_B) , CONV2_OCH_T = (CONV2_OCH / CONV2_OCH_B) ;
    localparam CONV1_OX_T  = (CONV1_OX  / CONV1_OX_B ) , CONV2_OX_T  = (CONV2_OX  / CONV2_OX_B ) ;
    
    localparam POOL1_ICH_T = (POOL1_ICH / POOL1_ICH_B) , POOL2_ICH_T = (POOL2_ICH / POOL2_ICH_B) ;
    localparam POOL1_IX_T  = (POOL1_IX  / POOL1_IX_B ) , POOL2_IX_T  = (POOL2_IX  / POOL2_IX_B ) ;
    
    localparam FC1_OCH_T = (FC1_OCH / FC1_OCH_B) , FC2_OCH_T = (FC2_OCH / FC2_OCH_B) , FC3_OCH_T = (FC3_OCH / FC3_OCH_B) ;
    localparam FC1_ICH_T = (FC1_ICH / FC1_ICH_B) , FC2_ICH_T = (FC2_ICH / FC2_ICH_B) , FC3_ICH_T = (FC3_ICH / FC3_ICH_B) ;
    
//==============================================================================
// BRAM Port Bandwidth
//==============================================================================
    localparam B_COL_NUM     = 32 / I_F_BW  ; // 4
    localparam B_COL_BW      = $clog2(B_COL_NUM) ; // 2
    
    localparam B_C1_I_DATA_W  = 32 ;
    localparam B_C1_I_DATA_D  = (CONV1_ICH * CONV1_IY * CONV1_IX) / B_COL_NUM; // 1024
    localparam B_C1_I_ADDR_W  = $clog2(B_C1_I_DATA_D); // 10
    localparam B_C1_W_DATA_W  = CONV_KX * W_BW; // 40
    localparam B_C1_W_DATA_D  = CONV1_OCH * CONV1_ICH * CONV_KY ; // 30
    localparam B_C1_W_ADDR_W  = $clog2(B_C1_W_DATA_D); // 5
    localparam B_C1_B_DATA_W  = B_BW ; // 16
    localparam B_C1_B_DATA_D  = CONV1_OCH  ; // 6
    localparam B_C1_B_ADDR_W  = $clog2(B_C1_B_DATA_D); // 3
    localparam B_C1_P_DATA_W  = 32 ;
    localparam B_C1_P_DATA_D  = (POOL1_ICH * (POOL1_IY/2) * (POOL1_IX/2)) / B_COL_NUM; // 294 = 1176 / 4
    localparam B_C1_P_ADDR_W  = $clog2(B_C1_P_DATA_D); // 9
    
    localparam B_C2_I_DATA_W  = 32 ;
    localparam B_C2_I_DATA_D  = (CONV2_ICH * CONV2_IY * CONV2_IX) / B_COL_NUM; // 1024
    localparam B_C2_I_ADDR_W  = $clog2(B_C2_I_DATA_D); // 10
    localparam B_C2_W_DATA_W  = CONV_KX * W_BW; // 40
    localparam B_C2_W_DATA_D  = CONV2_OCH * CONV2_ICH * CONV_KY ; // 30
    localparam B_C2_W_ADDR_W  = $clog2(B_C2_W_DATA_D); // 5
    localparam B_C2_B_DATA_W  = B_BW ; // 16
    localparam B_C2_B_DATA_D  = CONV2_OCH  ; // 6
    localparam B_C2_B_ADDR_W  = $clog2(B_C2_B_DATA_D); // 3
    localparam B_C2_P_DATA_W  = 32 ;
    localparam B_C2_P_DATA_D  = (POOL2_ICH * (POOL2_IY/2) * (POOL2_IX/2)) / B_COL_NUM; // 294 = 1176 / 4
    localparam B_C2_P_ADDR_W  = $clog2(B_C2_P_DATA_D); // 9
    
    localparam B_FC1_I_DATA_W  = 32 ;
    localparam B_FC1_I_DATA_D  = $rtoi($ceil(FC1_ICH*1.0 / B_COL_NUM*1.0)); // 100
    localparam B_FC1_I_ADDR_W  = $clog2(B_FC1_I_DATA_D); // 7
    localparam B_FC1_W_DATA_W  = FC1_ICH_T * W_BW; // 80
    localparam B_FC1_W_DATA_D  = FC1_OCH * FC1_ICH_B ; // 4800 = 120 * 40
    localparam B_FC1_W_ADDR_W  = $clog2(B_FC1_W_DATA_D); // 13
    localparam B_FC1_B_DATA_W  = B_BW ; // 16
    localparam B_FC1_B_DATA_D  = FC1_OCH  ; // 120
    localparam B_FC1_B_ADDR_W  = $clog2(B_FC1_B_DATA_D); // 7
    localparam B_FC1_S_DATA_W  = 32 ;
    localparam B_FC1_S_DATA_D  = $rtoi($ceil(FC1_OCH*1.0 / B_COL_NUM*1.0)); // 30
    localparam B_FC1_S_ADDR_W  = $clog2(B_FC1_S_DATA_D); // 5
    
    localparam B_FC2_I_DATA_W  = 32 ;
    localparam B_FC2_I_DATA_D  = $rtoi($ceil(FC2_ICH*1.0 / B_COL_NUM*1.0)); // 100
    localparam B_FC2_I_ADDR_W  = $clog2(B_FC2_I_DATA_D); // 7
    localparam B_FC2_W_DATA_W  = FC2_ICH_T * W_BW; // 80
    localparam B_FC2_W_DATA_D  = FC2_OCH * FC2_ICH_B ; // 4800 = 120 * 40
    localparam B_FC2_W_ADDR_W  = $clog2(B_FC2_W_DATA_D); // 13
    localparam B_FC2_B_DATA_W  = B_BW ; // 16
    localparam B_FC2_B_DATA_D  = FC2_OCH  ; // 120
    localparam B_FC2_B_ADDR_W  = $clog2(B_FC2_B_DATA_D); // 7
    localparam B_FC2_S_DATA_W  = 32 ;
    localparam B_FC2_S_DATA_D  = $rtoi($ceil(FC2_OCH*1.0 / B_COL_NUM*1.0)); // 30
    localparam B_FC2_S_ADDR_W  = $clog2(B_FC2_S_DATA_D); // 5
    
    localparam B_FC3_I_DATA_W  = 32 ;
    localparam B_FC3_I_DATA_D  = $rtoi($ceil(FC3_ICH*1.0 / B_COL_NUM*1.0)); // 100
    localparam B_FC3_I_ADDR_W  = $clog2(B_FC3_I_DATA_D); // 7
    localparam B_FC3_W_DATA_W  = FC3_ICH_T * W_BW; // 80
    localparam B_FC3_W_DATA_D  = FC3_OCH * FC3_ICH_B ; // 4800 = 120 * 40
    localparam B_FC3_W_ADDR_W  = $clog2(B_FC3_W_DATA_D); // 13
    localparam B_FC3_B_DATA_W  = B_BW ; // 16
    localparam B_FC3_B_DATA_D  = FC3_OCH  ; // 120
    localparam B_FC3_B_ADDR_W  = $clog2(B_FC3_B_DATA_D); // 7
    
    // // counter
    // localparam OCH_B_CNT_BW = $clog2(OCH_B) ; // 5
    // localparam ICH_B_CNT_BW = $clog2(ICH_B) ; // 6
    
//==============================================================================
// Submodule Port Index
//==============================================================================
    localparam C1_OX_B_IDX_BW    = $clog2(CONV1_OX_B) ; // 1
    localparam C1_OX_T_IDX_BW    = $clog2(CONV1_OX_T) ; // 3
    localparam C1_OY_IDX_BW      = $clog2(CONV1_OY) ; // 4
    localparam C1_OCH_B_IDX_BW   = $clog2(CONV1_OCH_B) ; // 2
    localparam C1_SCALED_IDX_BW  = $clog2(CONV1_OX_T) ; // 3
    localparam C1_SCALED_OTFMAP_BW = CONV1_OCH_T * I_F_BW ; // 32
    
    localparam P1_IX_B_IDX_BW   = $clog2(POOL1_IX_B) ; // 2
    localparam P1_IX_T_IDX_BW   = $clog2(POOL1_IX_T) ; // 3
    localparam P1_IY_IDX_BW     = $clog2(POOL1_IY) ; // 5
    localparam P1_ICH_B_IDX_BW  = $clog2(POOL1_ICH_B) ; // 1
    localparam P1_ICH_T_INFMAP_BW = POOL1_ICH_T * I_F_BW ; // 24
    
    localparam C2_OX_B_IDX_BW    = $clog2(CONV2_OX_B) ; // 1
    localparam C2_OX_T_IDX_BW    = $clog2(CONV2_OX_T) ; // 3
    localparam C2_OY_IDX_BW      = $clog2(CONV2_OY) ; // 4
    localparam C2_OCH_B_IDX_BW   = $clog2(CONV2_OCH_B) ; // 2
    localparam C2_SCALED_IDX_BW  = $clog2(CONV2_OX_T) ; // 3
    localparam C2_SCALED_OTFMAP_BW = CONV2_OCH_T * I_F_BW ; // 32
    
    localparam P2_IX_B_IDX_BW   = $clog2(POOL2_IX_B) ; // 2
    localparam P2_IX_T_IDX_BW   = $clog2(POOL2_IX_T) ; // 3
    localparam P2_IY_IDX_BW     = $clog2(POOL2_IY) ; // 5
    localparam P2_ICH_B_IDX_BW  = $clog2(POOL2_ICH_B) ; // 1
    localparam P2_ICH_T_INFMAP_BW = POOL2_ICH_T * I_F_BW ; // 24
    
//==============================================================================
// Local Parameter declaration
//==============================================================================
    // Pipeline operation 
    localparam S_C1_LAYER  = 0 ;
    localparam S_C2_LAYER  = 1 ;
    localparam S_FC1_LAYER = 2 ;
    localparam S_FC2_LAYER = 3 ;
    localparam S_FC3_LAYER = 4 ;
    localparam S_IDLE      = 5 ;
    localparam STATE_BW = S_IDLE + 1 ; // One hot
    localparam LAYERS_NUM = S_IDLE ;
    
    localparam OTFMAP_O_IDX_BW  = $clog2(FC3_OCH) ; // 4
    
//==============================================================================
// Input/Output declaration
//==============================================================================
    input                          clk                    ;
    input                          areset                 ;
    
    input                          i_in_data_valid        ;
    input  [DATA_IDX_BW-1 : 0]     i_in_data_idx          ;
    
    output                         o_idle                 ;
    output                         o_run                  ;
    
    output                         o_data_read_valid      ;
    output                         o_ot_valid             ;
    output [DATA_IDX_BW-1 : 0]     o_ot_data_idx          ;
    output [OTFMAP_O_IDX_BW-1 : 0] o_ot_data_result       ;
    
    // infmap
    output [B_C1_I_ADDR_W-1 : 0]   b_in_o_infmap_addr     ;
    output                         b_in_o_infmap_ce       ;
    output                         b_in_o_infmap_we       ;
    // output [B_C1_I_DATA_W-1 : 0]   b_in_o_infmap_d        ; // not using write bram
    input  [B_C1_I_DATA_W-1 : 0]   b_in_i_infmap_q        ;
    
    // conv1
    output [B_C1_I_ADDR_W-1 : 0]   b_c1_o_infmap_addr     ;
    output                         b_c1_o_infmap_ce       ;
    output                         b_c1_o_infmap_we       ;
    output [B_C1_I_DATA_W-1 : 0]   b_c1_o_infmap_d        ;
    input  [B_C1_I_DATA_W-1 : 0]   b_c1_i_infmap_q        ;
    output [B_C1_W_ADDR_W-1 : 0]   b_c1_o_weight_addr     ;
    output                         b_c1_o_weight_ce       ;
    output                         b_c1_o_weight_we       ;
    // output [B_C1_W_DATA_W-1 : 0]   b_c1_o_weight_d        ; // not using write bram
    input  [B_C1_W_DATA_W-1 : 0]   b_c1_i_weight_q        ;
    output [B_C1_B_ADDR_W-1 : 0]   b_c1_o_bias_addr       ;
    output                         b_c1_o_bias_ce         ;
    output                         b_c1_o_bias_we         ;
    // output [B_C1_B_DATA_W-1 : 0]   b_c1_o_bias_d          ; // not using write bram
    input  [B_C1_B_DATA_W-1 : 0]   b_c1_i_bias_q          ;
    output [B_C1_P_ADDR_W-1 : 0]   b_p1_o_pool_addr       ;
    output                         b_p1_o_pool_ce         ;
    output [B_COL_NUM-1 : 0]       b_p1_o_pool_byte_we    ;
    output [B_C1_P_DATA_W-1 : 0]   b_p1_o_pool_d          ;
    input  [B_C1_P_DATA_W-1 : 0]   b_p1_i_pool_q          ;
    
    // conv2
    output [B_C2_I_ADDR_W-1 : 0]   b_c2_o_infmap_addr     ;
    output                         b_c2_o_infmap_ce       ;
    output                         b_c2_o_infmap_we       ;
    output [B_C2_I_DATA_W-1 : 0]   b_c2_o_infmap_d        ;
    input  [B_C2_I_DATA_W-1 : 0]   b_c2_i_infmap_q        ;
    output [B_C2_W_ADDR_W-1 : 0]   b_c2_o_weight_addr     ;
    output                         b_c2_o_weight_ce       ;
    output                         b_c2_o_weight_we       ;
    // output [B_C2_W_DATA_W-1 : 0]   b_c2_o_weight_d        ; // not using write bram
    input  [B_C2_W_DATA_W-1 : 0]   b_c2_i_weight_q        ;
    output [B_C2_B_ADDR_W-1 : 0]   b_c2_o_bias_addr       ;
    output                         b_c2_o_bias_ce         ;
    output                         b_c2_o_bias_we         ;
    // output [B_C2_B_DATA_W-1 : 0]   b_c2_o_bias_d          ; // not using write bram
    input  [B_C2_B_DATA_W-1 : 0]   b_c2_i_bias_q          ;
    output [B_C2_P_ADDR_W-1 : 0]   b_p2_o_pool_addr       ;
    output                         b_p2_o_pool_ce         ;
    output [B_COL_NUM-1 : 0]       b_p2_o_pool_byte_we    ;
    output [B_C2_P_DATA_W-1 : 0]   b_p2_o_pool_d          ;
    input  [B_C2_P_DATA_W-1 : 0]   b_p2_i_pool_q          ;
    
    // fc1
    output [B_FC1_I_ADDR_W-1 : 0]  b_fc1_o_infmap_addr     ;
    output                         b_fc1_o_infmap_ce       ;
    output                         b_fc1_o_infmap_we       ;
    output [B_FC1_I_DATA_W-1 : 0]  b_fc1_o_infmap_d        ;
    input  [B_FC1_I_DATA_W-1 : 0]  b_fc1_i_infmap_q        ;
    output [B_FC1_W_ADDR_W-1 : 0]  b_fc1_o_weight_addr     ;
    output                         b_fc1_o_weight_ce       ;
    output                         b_fc1_o_weight_we       ;
    // output [B_FC1_W_DATA_W-1 : 0]  b_fc1_o_weight_d        ; // not using write bram
    input  [B_FC1_W_DATA_W-1 : 0]  b_fc1_i_weight_q        ;
    output [B_FC1_B_ADDR_W-1 : 0]  b_fc1_o_bias_addr       ;
    output                         b_fc1_o_bias_ce         ;
    output                         b_fc1_o_bias_we         ;
    // output [B_FC1_B_DATA_W-1 : 0]  b_fc1_o_bias_d          ; // not using write bram
    input  [B_FC1_B_DATA_W-1 : 0]  b_fc1_i_bias_q          ;
    output [B_FC1_S_ADDR_W-1 : 0]  b_fc1_o_scaled_addr     ;
    output                         b_fc1_o_scaled_ce       ;
    output [B_COL_NUM-1 : 0]       b_fc1_o_scaled_byte_we  ;
    output [B_FC1_S_DATA_W-1 : 0]  b_fc1_o_scaled_d        ;
    input  [B_FC1_S_DATA_W-1 : 0]  b_fc1_i_scaled_q        ;
    
    // fc2
    output [B_FC2_I_ADDR_W-1 : 0]  b_fc2_o_infmap_addr     ;
    output                         b_fc2_o_infmap_ce       ;
    output                         b_fc2_o_infmap_we       ;
    output [B_FC2_I_DATA_W-1 : 0]  b_fc2_o_infmap_d        ;
    input  [B_FC2_I_DATA_W-1 : 0]  b_fc2_i_infmap_q        ;
    output [B_FC2_W_ADDR_W-1 : 0]  b_fc2_o_weight_addr     ;
    output                         b_fc2_o_weight_ce       ;
    output                         b_fc2_o_weight_we       ;
    // output [B_FC2_W_DATA_W-1 : 0]  b_fc2_o_weight_d        ; // not using write bram
    input  [B_FC2_W_DATA_W-1 : 0]  b_fc2_i_weight_q        ;
    output [B_FC2_B_ADDR_W-1 : 0]  b_fc2_o_bias_addr       ;
    output                         b_fc2_o_bias_ce         ;
    output                         b_fc2_o_bias_we         ;
    // output [B_FC2_B_DATA_W-1 : 0]  b_fc2_o_bias_d          ; // not using write bram
    input  [B_FC2_B_DATA_W-1 : 0]  b_fc2_i_bias_q          ;
    output [B_FC2_S_ADDR_W-1 : 0]  b_fc2_o_scaled_addr     ;
    output                         b_fc2_o_scaled_ce       ;
    output [B_COL_NUM-1 : 0]       b_fc2_o_scaled_byte_we  ;
    output [B_FC2_S_DATA_W-1 : 0]  b_fc2_o_scaled_d        ;
    input  [B_FC2_S_DATA_W-1 : 0]  b_fc2_i_scaled_q        ;
    
    // fc3
    output [B_FC3_I_ADDR_W-1 : 0]  b_fc3_o_infmap_addr     ;
    output                         b_fc3_o_infmap_ce       ;
    output                         b_fc3_o_infmap_we       ;
    output [B_FC3_I_DATA_W-1 : 0]  b_fc3_o_infmap_d        ;
    input  [B_FC3_I_DATA_W-1 : 0]  b_fc3_i_infmap_q        ;
    output [B_FC3_W_ADDR_W-1 : 0]  b_fc3_o_weight_addr     ;
    output                         b_fc3_o_weight_ce       ;
    output                         b_fc3_o_weight_we       ;
    // output [B_FC3_W_DATA_W-1 : 0]  b_fc3_o_weight_d        ; // not using write bram
    input  [B_FC3_W_DATA_W-1 : 0]  b_fc3_i_weight_q        ;
    output [B_FC3_B_ADDR_W-1 : 0]  b_fc3_o_bias_addr       ;
    output                         b_fc3_o_bias_ce         ;
    output                         b_fc3_o_bias_we         ;
    // output [B_FC3_B_DATA_W-1 : 0]  b_fc3_o_bias_d          ; // not using write bram
    input  [B_FC3_B_DATA_W-1 : 0]  b_fc3_i_bias_q          ;

//==============================================================================
// Declaration Submodule Port
//==============================================================================
    wire                             c_mc_in_i_run             ;
    wire                             c_mc_in_o_idle            ;
    wire                             c_mc_in_o_run             ;
    wire                             c_mc_in_o_en_err          ;
    wire                             c_mc_in_o_n_ready         ;
    wire                             c_mc_in_o_ot_done         ;
    
    wire                             c_c1_i_run               ;
    wire                             c_c1_o_idle              ;
    wire                             c_c1_o_run               ;
    wire                             c_c1_o_en_err            ;
    wire                             c_c1_o_n_ready           ;
    wire                             c_c1_o_ot_done           ;
    wire                             c_c1_o_ot_valid          ;
    wire [C1_OX_B_IDX_BW-1 : 0]      c_c1_o_ot_ox_b_idx       ;
    wire [C1_OX_T_IDX_BW-1 : 0]      c_c1_o_ot_ox_t_idx       ;
    wire [C1_OY_IDX_BW-1 : 0]        c_c1_o_ot_oy_idx         ;
    wire [C1_OCH_B_IDX_BW-1 : 0]     c_c1_o_ot_och_b_idx      ;
    wire [C1_SCALED_OTFMAP_BW-1 : 0] c_c1_o_ot_och_t_otfmap   ;
    
    wire                             c_p1_i_run               ;
    wire                             c_p1_i_in_valid          ;
    wire [P1_IX_B_IDX_BW-1 : 0]      c_p1_i_ix_b_idx          ;
    wire [P1_IX_T_IDX_BW-1 : 0]      c_p1_i_ix_t_idx          ;
    wire [P1_IY_IDX_BW-1 : 0]        c_p1_i_iy_idx            ;
    wire [P1_ICH_B_IDX_BW-1 : 0]     c_p1_i_ich_b_idx         ;
    wire [P1_ICH_T_INFMAP_BW-1 : 0]  c_p1_i_ich_t_infmap      ;
    wire                             c_p1_i_in_done           ;
    wire                             c_p1_o_idle              ;
    wire                             c_p1_o_run               ;
    wire                             c_p1_o_en_err            ;
    wire                             c_p1_o_n_ready           ;
    wire                             c_p1_o_ot_done           ;
    
    wire                             c_mc_c1_i_run             ;
    wire                             c_mc_c1_o_idle            ;
    wire                             c_mc_c1_o_run             ;
    wire                             c_mc_c1_o_en_err          ;
    wire                             c_mc_c1_o_n_ready         ;
    wire                             c_mc_c1_o_ot_done         ;
    
    wire                             c_c2_i_run               ;
    wire                             c_c2_o_idle              ;
    wire                             c_c2_o_run               ;
    wire                             c_c2_o_en_err            ;
    wire                             c_c2_o_n_ready           ;
    wire                             c_c2_o_ot_done           ;
    wire                             c_c2_o_ot_valid          ;
    wire [C2_OX_B_IDX_BW-1 : 0]      c_c2_o_ot_ox_b_idx       ;
    wire [C2_OX_T_IDX_BW-1 : 0]      c_c2_o_ot_ox_t_idx       ;
    wire [C2_OY_IDX_BW-1 : 0]        c_c2_o_ot_oy_idx         ;
    wire [C2_OCH_B_IDX_BW-1 : 0]     c_c2_o_ot_och_b_idx      ;
    wire [C2_SCALED_OTFMAP_BW-1 : 0] c_c2_o_ot_och_t_otfmap   ;
    
    wire                             c_p2_i_run               ;
    wire                             c_p2_i_in_valid          ;
    wire [P2_IX_B_IDX_BW-1 : 0]      c_p2_i_ix_b_idx          ;
    wire [P2_IX_T_IDX_BW-1 : 0]      c_p2_i_ix_t_idx          ;
    wire [P2_IY_IDX_BW-1 : 0]        c_p2_i_iy_idx            ;
    wire [P2_ICH_B_IDX_BW-1 : 0]     c_p2_i_ich_b_idx         ;
    wire [P2_ICH_T_INFMAP_BW-1 : 0]  c_p2_i_ich_t_infmap      ;
    wire                             c_p2_i_in_done           ;
    wire                             c_p2_o_idle              ;
    wire                             c_p2_o_run               ;
    wire                             c_p2_o_en_err            ;
    wire                             c_p2_o_n_ready           ;
    wire                             c_p2_o_ot_done           ;

    wire                             c_mc_c2_i_run             ;
    wire                             c_mc_c2_o_idle            ;
    wire                             c_mc_c2_o_run             ;
    wire                             c_mc_c2_o_en_err          ;
    wire                             c_mc_c2_o_n_ready         ;
    wire                             c_mc_c2_o_ot_done         ;
    
    wire                             c_fc1_i_run              ;
    wire                             c_fc1_o_idle             ;
    wire                             c_fc1_o_run              ;
    wire                             c_fc1_o_en_err           ;
    wire                             c_fc1_o_n_ready          ;
    wire                             c_fc1_o_ot_done          ;

    wire                             c_mc_fc1_i_run             ;
    wire                             c_mc_fc1_o_idle            ;
    wire                             c_mc_fc1_o_run             ;
    wire                             c_mc_fc1_o_en_err          ;
    wire                             c_mc_fc1_o_n_ready         ;
    wire                             c_mc_fc1_o_ot_done         ;
    
    wire                             c_fc2_i_run              ;
    wire                             c_fc2_o_idle             ;
    wire                             c_fc2_o_run              ;
    wire                             c_fc2_o_en_err           ;
    wire                             c_fc2_o_n_ready          ;
    wire                             c_fc2_o_ot_done          ;

    wire                             c_mc_fc2_i_run             ;
    wire                             c_mc_fc2_o_idle            ;
    wire                             c_mc_fc2_o_run             ;
    wire                             c_mc_fc2_o_en_err          ;
    wire                             c_mc_fc2_o_n_ready         ;
    wire                             c_mc_fc2_o_ot_done         ;
    
    wire                             c_fc3_i_run              ;
    wire                             c_fc3_o_idle             ;
    wire                             c_fc3_o_run              ;
    wire                             c_fc3_o_en_err           ;
    wire                             c_fc3_o_n_ready          ;
    wire                             c_fc3_o_ot_done          ;
    wire                             c_fc3_o_ot_valid         ;
    wire  [OTFMAP_O_IDX_BW-1 : 0]    c_fc3_o_ot_otfmap_idx    ;
    
    // mem_copy bram port 
    assign b_in_o_infmap_we = 1'b0;
    
    wire [B_C1_I_ADDR_W-1 : 0]   b_c1_o_infmap_addr_0 , b_c1_o_infmap_addr_1 ;
    wire                         b_c1_o_infmap_ce_0   , b_c1_o_infmap_ce_1   ;
    
    wire [B_C1_P_ADDR_W-1 : 0]   b_p1_o_pool_addr_0 , b_p1_o_pool_addr_1 ;
    wire                         b_p1_o_pool_ce_0   , b_p1_o_pool_ce_1   ;
    wire [B_C2_I_ADDR_W-1 : 0]   b_c2_o_infmap_addr_0 , b_c2_o_infmap_addr_1 ;
    wire                         b_c2_o_infmap_ce_0   , b_c2_o_infmap_ce_1   ;
    
    wire [B_C2_P_ADDR_W-1 : 0]   b_p2_o_pool_addr_0 , b_p2_o_pool_addr_1 ;
    wire                         b_p2_o_pool_ce_0   , b_p2_o_pool_ce_1   ;
    wire [B_FC1_I_ADDR_W-1 : 0]  b_fc1_o_infmap_addr_0 , b_fc1_o_infmap_addr_1 ;
    wire                         b_fc1_o_infmap_ce_0   , b_fc1_o_infmap_ce_1   ;
    
    wire [B_FC1_S_ADDR_W-1 : 0]  b_fc1_o_scaled_addr_0 , b_fc1_o_scaled_addr_1 ;
    wire                         b_fc1_o_scaled_ce_0   , b_fc1_o_scaled_ce_1   ;
    wire [B_FC2_I_ADDR_W-1 : 0]  b_fc2_o_infmap_addr_0 , b_fc2_o_infmap_addr_1 ;
    wire                         b_fc2_o_infmap_ce_0   , b_fc2_o_infmap_ce_1   ;
    
    wire [B_FC2_S_ADDR_W-1 : 0]  b_fc2_o_scaled_addr_0 , b_fc2_o_scaled_addr_1 ;
    wire                         b_fc2_o_scaled_ce_0   , b_fc2_o_scaled_ce_1   ;
    wire [B_FC3_I_ADDR_W-1 : 0]  b_fc3_o_infmap_addr_0 , b_fc3_o_infmap_addr_1 ;
    wire                         b_fc3_o_infmap_ce_0   , b_fc3_o_infmap_ce_1   ;
    
    assign b_c1_o_infmap_addr = (c_mc_in_o_run) ? (b_c1_o_infmap_addr_0 ) : (b_c1_o_infmap_addr_1 );
    assign b_c1_o_infmap_ce   = (c_mc_in_o_run) ? (b_c1_o_infmap_ce_0   ) : (b_c1_o_infmap_ce_1   );
    
    assign b_p1_o_pool_addr   = (c_mc_c1_o_run) ? (b_p1_o_pool_addr_1 ) : (b_p1_o_pool_addr_0 );
    assign b_p1_o_pool_ce     = (c_mc_c1_o_run) ? (b_p1_o_pool_ce_1   ) : (b_p1_o_pool_ce_0   );
    assign b_c2_o_infmap_addr = (c_mc_c1_o_run) ? (b_c2_o_infmap_addr_0 ) : (b_c2_o_infmap_addr_1 );
    assign b_c2_o_infmap_ce   = (c_mc_c1_o_run) ? (b_c2_o_infmap_ce_0   ) : (b_c2_o_infmap_ce_1   );
    
    assign b_p2_o_pool_addr    = (c_mc_c2_o_run) ? (b_p2_o_pool_addr_1 ) : (b_p2_o_pool_addr_0 );
    assign b_p2_o_pool_ce      = (c_mc_c2_o_run) ? (b_p2_o_pool_ce_1   ) : (b_p2_o_pool_ce_0   );
    assign b_fc1_o_infmap_addr = (c_mc_c2_o_run) ? (b_fc1_o_infmap_addr_0 ) : (b_fc1_o_infmap_addr_1 );
    assign b_fc1_o_infmap_ce   = (c_mc_c2_o_run) ? (b_fc1_o_infmap_ce_0   ) : (b_fc1_o_infmap_ce_1   );
    
    assign b_fc1_o_scaled_addr = (c_mc_fc1_o_run) ? (b_fc1_o_scaled_addr_1 ) : (b_fc1_o_scaled_addr_0 );
    assign b_fc1_o_scaled_ce   = (c_mc_fc1_o_run) ? (b_fc1_o_scaled_ce_1   ) : (b_fc1_o_scaled_ce_0   );
    assign b_fc2_o_infmap_addr = (c_mc_fc1_o_run) ? (b_fc2_o_infmap_addr_0 ) : (b_fc2_o_infmap_addr_1 );
    assign b_fc2_o_infmap_ce   = (c_mc_fc1_o_run) ? (b_fc2_o_infmap_ce_0   ) : (b_fc2_o_infmap_ce_1   );
    
    assign b_fc2_o_scaled_addr = (c_mc_fc2_o_run) ? (b_fc2_o_scaled_addr_1 ) : (b_fc2_o_scaled_addr_0 );
    assign b_fc2_o_scaled_ce   = (c_mc_fc2_o_run) ? (b_fc2_o_scaled_ce_1   ) : (b_fc2_o_scaled_ce_0   );
    assign b_fc3_o_infmap_addr = (c_mc_fc2_o_run) ? (b_fc3_o_infmap_addr_0 ) : (b_fc3_o_infmap_addr_1 );
    assign b_fc3_o_infmap_ce   = (c_mc_fc2_o_run) ? (b_fc3_o_infmap_ce_0   ) : (b_fc3_o_infmap_ce_1   );

//==============================================================================
// Declaration Pipeline State
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
    // reg  r_run           ;
    // always @(posedge clk) begin
    //     if(areset) begin
    //         r_run <= 1'b0;
    //     end else if(i_run) begin
    //         r_run <= 1'b1;
    //     end else if(o_ot_done) begin
    //         r_run <= 1'b0;
    //     end 
    // end
 
//==============================================================================
// Last State
//==============================================================================
    reg  r_update_state;
    
    reg  r_last_state;
    
    always @(posedge clk) begin
        if(areset) begin
            r_last_state <= 1'b0;
        end else if(r_update_state) begin
            r_last_state <= (c_state[LAYERS_NUM-2 : 0] == 5'b0_1000) && ~(i_in_data_valid);
        end	
    end
    
//==============================================================================
// Update State
//==============================================================================
    reg  [LAYERS_NUM-2 : 0] r_layers_done;
    wire w_layers_done_all;
    
    reg  [LAYERS_NUM-2 : 0] r_mem_copy_done;
    wire w_mem_copy_done_all;
    
    always @(posedge clk) begin
        if((areset) || (w_layers_done_all)) begin
            r_layers_done <= {(LAYERS_NUM-1){1'b0}};
        end	else begin
            if(c_p1_o_n_ready ) r_layers_done[S_C1_LAYER ] <= 1'b1;
            if(c_p2_o_n_ready ) r_layers_done[S_C2_LAYER ] <= 1'b1;
            if(c_fc1_o_n_ready) r_layers_done[S_FC1_LAYER] <= 1'b1;
            if(c_fc2_o_n_ready) r_layers_done[S_FC2_LAYER] <= 1'b1;
        end	
    end
    assign w_layers_done_all = (r_layers_done == c_state[LAYERS_NUM-2 : 0]) &&
        ~(c_state[S_IDLE]);
    
    always @(posedge clk) begin
        if((areset) || (w_mem_copy_done_all)) begin
            r_mem_copy_done <= {(LAYERS_NUM-1){1'b0}};
        end	else begin
            if(c_mc_c1_o_n_ready ) r_mem_copy_done[S_C1_LAYER ] <= 1'b1;
            if(c_mc_c2_o_n_ready ) r_mem_copy_done[S_C2_LAYER ] <= 1'b1;
            if(c_mc_fc1_o_n_ready) r_mem_copy_done[S_FC1_LAYER] <= 1'b1;
            if(c_mc_fc2_o_n_ready) r_mem_copy_done[S_FC2_LAYER] <= 1'b1;
        end	
    end
    assign w_mem_copy_done_all = (r_mem_copy_done == c_state[LAYERS_NUM-2 : 0]) &&
            ~(c_state[S_IDLE]) && ~(r_last_state);
        
    always @(posedge clk) begin
        if((areset) || (r_update_state)) begin
            r_update_state <= 1'b0;
        end else begin
            r_update_state <= ((c_state[S_IDLE]) && (i_in_data_valid)) ||
                (w_mem_copy_done_all) ||
                ((c_fc3_o_n_ready) && (r_last_state));
        end	
    end

//==============================================================================
// Capture Data Index
//==============================================================================
    reg  [DATA_IDX_BW-1 : 0] r_c1_idx  ;
    reg  [DATA_IDX_BW-1 : 0] r_c2_idx  ;
    reg  [DATA_IDX_BW-1 : 0] r_fc1_idx ;
    reg  [DATA_IDX_BW-1 : 0] r_fc2_idx ;
    reg  [DATA_IDX_BW-1 : 0] r_fc3_idx ;
    
    always @(posedge clk) begin
        if(areset) begin
            r_c1_idx  <= {DATA_IDX_BW{1'b0}};
            r_c2_idx  <= {DATA_IDX_BW{1'b0}};
            r_fc1_idx <= {DATA_IDX_BW{1'b0}};
            r_fc2_idx <= {DATA_IDX_BW{1'b0}};
            r_fc3_idx <= {DATA_IDX_BW{1'b0}};
        end else if(r_update_state) begin
            r_c1_idx  <= i_in_data_idx ;
            r_c2_idx  <= r_c1_idx  ;
            r_fc1_idx <= r_c2_idx  ;
            r_fc2_idx <= r_fc1_idx ;
            r_fc3_idx <= r_fc2_idx ;
        end
    end
    
//==============================================================================
// Control Infmap BRAM mem_copy
//==============================================================================
    reg  r_mc_in_i_run       ;
    
    always @(posedge clk) begin
        if((areset) || (r_mc_in_i_run)) begin
            r_mc_in_i_run <= 1'b0;
        end else begin
            r_mc_in_i_run <= ((c_state[S_IDLE]) || (w_mem_copy_done_all) || 
                ((c_fc3_o_n_ready) && (r_last_state))) && (i_in_data_valid);
        end
    end
    
    assign c_mc_in_i_run       = r_mc_in_i_run        ;

//==============================================================================
// Control Submodule Input Port: C1 layer
//==============================================================================
    reg                             r_c1_i_run          ;
    reg                             r_mc_c1_i_run       ;
    
    always @(posedge clk) begin
        if((areset) || (r_c1_i_run)) begin
            r_c1_i_run <= 1'b0;
        end else begin
            r_c1_i_run <= c_mc_in_o_n_ready;
        end
    end
    
    always @(posedge clk) begin
        if((areset) || (r_mc_c1_i_run)) begin
            r_mc_c1_i_run <= 1'b0;
        end else begin
            r_mc_c1_i_run <= (w_layers_done_all) && (r_layers_done[S_C1_LAYER]);
        end
    end
    
    assign c_c1_i_run          = r_c1_i_run           ;
    assign c_p1_i_run          = r_c1_i_run           ;
    assign c_p1_i_in_valid     = c_c1_o_ot_valid         ;
    assign c_p1_i_ix_b_idx     = c_c1_o_ot_ox_b_idx      ;
    assign c_p1_i_ix_t_idx     = c_c1_o_ot_ox_t_idx      ;
    assign c_p1_i_iy_idx       = c_c1_o_ot_oy_idx        ;
    assign c_p1_i_ich_b_idx    = c_c1_o_ot_och_b_idx     ;
    assign c_p1_i_ich_t_infmap = c_c1_o_ot_och_t_otfmap  ;
    assign c_p1_i_in_done      = c_c1_o_ot_done          ;
    assign c_mc_c1_i_run       = r_mc_c1_i_run        ;
    
//==============================================================================
// Control Submodule Input Port: C2 layer
//==============================================================================
    reg                             r_c2_i_run          ;
    reg                             r_mc_c2_i_run       ;
    
    always @(posedge clk) begin
        if(areset) begin
            r_c2_i_run <= 1'b0;
        end else begin
            r_c2_i_run <= (w_mem_copy_done_all) && (r_mem_copy_done[S_C1_LAYER ]);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_mc_c2_i_run <= 1'b0;
        end else begin
            r_mc_c2_i_run <= (w_layers_done_all) && (r_layers_done[S_C2_LAYER]);
        end
    end
    
    assign c_c2_i_run          = r_c2_i_run           ;
    assign c_p2_i_run          = r_c2_i_run           ;
    assign c_p2_i_in_valid     = c_c2_o_ot_valid        ;
    assign c_p2_i_ix_b_idx     = c_c2_o_ot_ox_b_idx     ;
    assign c_p2_i_ix_t_idx     = c_c2_o_ot_ox_t_idx     ;
    assign c_p2_i_iy_idx       = c_c2_o_ot_oy_idx       ;
    assign c_p2_i_ich_b_idx    = c_c2_o_ot_och_b_idx    ;
    assign c_p2_i_ich_t_infmap = c_c2_o_ot_och_t_otfmap ;
    assign c_p2_i_in_done      = c_c2_o_ot_done         ;
    assign c_mc_c2_i_run       = r_mc_c2_i_run        ;
    
//==============================================================================
// Control Submodule Input Port: FC layer
//==============================================================================
    reg  r_fc1_i_run         ;
    reg  r_mc_fc1_i_run      ;
    reg  r_fc2_i_run         ;
    reg  r_mc_fc2_i_run      ;
    reg  r_fc3_i_run         ;
    
    always @(posedge clk) begin
        if(areset) begin
            r_fc1_i_run <= 1'b0;
        end else begin
            r_fc1_i_run <= (w_mem_copy_done_all) && (r_mem_copy_done[S_C2_LAYER]);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_mc_fc1_i_run <= 1'b0;
        end else begin
            r_mc_fc1_i_run <= (w_layers_done_all) && (r_layers_done[S_FC1_LAYER]);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_fc2_i_run <= 1'b0;
        end else begin
            r_fc2_i_run <= (w_mem_copy_done_all) && (r_mem_copy_done[S_FC1_LAYER]);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_mc_fc2_i_run <= 1'b0;
        end else begin
            r_mc_fc2_i_run <= (w_layers_done_all) && (r_layers_done[S_FC2_LAYER]);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_fc3_i_run <= 1'b0;
        end else begin
            r_fc3_i_run <= (w_mem_copy_done_all) && (r_mem_copy_done[S_FC2_LAYER]);
        end
    end
    
    assign c_fc1_i_run     = r_fc1_i_run          ;
    assign c_mc_fc1_i_run  = r_mc_fc1_i_run       ;
    assign c_fc2_i_run     = r_fc2_i_run          ;
    assign c_mc_fc2_i_run  = r_mc_fc2_i_run       ;
    assign c_fc3_i_run     = r_fc3_i_run          ;
    
//==============================================================================
// Assign output signal
//==============================================================================
    assign o_idle = c_state[S_IDLE];
    assign o_run  = !c_state[S_IDLE];
    // assign o_en_err  = r_en_err  ;
    // assign o_n_ready = r_n_ready ;
    // assign o_ot_done = r_ot_done ;
    
    assign o_data_read_valid = r_c1_i_run  ;
    assign o_ot_valid        = c_fc3_o_ot_valid ;
    assign o_ot_data_idx     = (r_fc3_idx) & ({DATA_IDX_BW{c_fc3_o_ot_valid}}) ;
    assign o_ot_data_result  = (c_fc3_o_ot_otfmap_idx) & ({DATA_IDX_BW{c_fc3_o_ot_valid}}) ;

//==============================================================================
// Pipeline Detail
//==============================================================================
    always @(*) begin
        n_state = c_state;
        if(c_fc3_o_ot_valid) begin
            n_state[S_FC3_LAYER] = 1'b0;
        end else if(r_update_state) begin
            n_state[S_C1_LAYER ] = i_in_data_valid;
            n_state[S_C2_LAYER ] = c_state[S_C1_LAYER ];
            n_state[S_FC1_LAYER] = c_state[S_C2_LAYER ];
            n_state[S_FC2_LAYER] = c_state[S_FC1_LAYER];
            n_state[S_FC3_LAYER] = c_state[S_FC2_LAYER];
            n_state[S_IDLE     ] = ~(i_in_data_valid) && (r_last_state);
        end
    end

//==============================================================================
// Instantiation Submodule
//==============================================================================
    // Infmap
    //--------------------------------------------------------------------
    mem_copy #( 
        .DATA_NUM (B_C1_I_DATA_D * B_COL_NUM) ,
        .I_F_BW   (I_F_BW   ) 
    ) u_mem_copy_in ( 
        .clk             (clk             ) ,
        .areset          (areset          ) ,
        .i_run           (c_mc_in_i_run           ) ,
        .o_idle          (c_mc_in_o_idle          ) ,
        .o_run           (c_mc_in_o_run           ) ,
        .o_en_err        (c_mc_in_o_en_err        ) ,
        .o_n_ready       (c_mc_in_o_n_ready       ) ,
        .o_ot_done       (c_mc_in_o_ot_done       ) ,
        .b_o_infmap_addr (b_in_o_infmap_addr      ) ,
        .b_o_infmap_ce   (b_in_o_infmap_ce        ) ,
        .b_i_infmap_q    (b_in_i_infmap_q         ) ,
        .b_o_otfmap_addr (b_c1_o_infmap_addr_0  ) ,
        .b_o_otfmap_ce   (b_c1_o_infmap_ce_0    ) ,
        .b_o_otfmap_we   (b_c1_o_infmap_we      ) ,
        .b_o_otfmap_d    (b_c1_o_infmap_d       ) 
    );
    
    // C1 layer
    //--------------------------------------------------------------------
    cnn_conv_layer #(
        .MULT_DELAY (MULT_DELAY ) ,
        .ACC_DELAY  (ACC_DELAY_C  ) ,
        .AB_DELAY   (AB_DELAY   ) ,
        .ICH        (CONV1_ICH        ) ,
        .OCH        (CONV1_OCH        ) ,
        .KX         (CONV_KX          ) ,
        .KY         (CONV_KY          ) ,
        .OX         (CONV1_OX         ) ,
        .OY         (CONV1_OY         ) ,
        .ICH_B      (CONV1_ICH_B      ) ,
        .OCH_B      (CONV1_OCH_B      ) ,
        .OX_B       (CONV1_OX_B       ) ,
        .I_F_BW     (I_F_BW     ) ,
        .W_BW       (W_BW       ) ,
        .B_BW       (B_BW       ) ,
        .PARA_B_BW  (CONV1_B_BW  ) ,
        .PARA_T_BW  (CONV1_T_BW  ) ,
        .B_SHIFT    (CONV1_B_SHIFT    ) ,
        .M_INV      (CONV1_M_INV      ) 
    ) u_c1_layer (
        .clk               (clk               ) ,
        .areset            (areset            ) ,
        .i_run             (c_c1_i_run             ) ,
        .o_idle            (c_c1_o_idle            ) ,
        .o_run             (c_c1_o_run             ) ,
        .o_en_err          (c_c1_o_en_err          ) ,
        .o_n_ready         (c_c1_o_n_ready         ) ,
        .o_ot_done         (c_c1_o_ot_done         ) ,
        .o_ot_valid        (c_c1_o_ot_valid        ) ,
        .o_ot_ox_b_idx     (c_c1_o_ot_ox_b_idx     ) ,
        .o_ot_ox_t_idx     (c_c1_o_ot_ox_t_idx     ) ,
        .o_ot_oy_idx       (c_c1_o_ot_oy_idx       ) ,
        .o_ot_och_b_idx    (c_c1_o_ot_och_b_idx    ) ,
        .o_ot_och_t_otfmap (c_c1_o_ot_och_t_otfmap ) ,
        .b_o_infmap_addr   (b_c1_o_infmap_addr_1   ) ,
        .b_o_infmap_ce     (b_c1_o_infmap_ce_1     ) ,
        .b_o_infmap_we     (     ) ,
        .b_i_infmap_q      (b_c1_i_infmap_q      ) ,
        .b_o_weight_addr   (b_c1_o_weight_addr   ) ,
        .b_o_weight_ce     (b_c1_o_weight_ce     ) ,
        .b_o_weight_we     (b_c1_o_weight_we     ) ,
        .b_i_weight_q      (b_c1_i_weight_q      ) ,
        .b_o_bias_addr     (b_c1_o_bias_addr     ) ,
        .b_o_bias_ce       (b_c1_o_bias_ce       ) ,
        .b_o_bias_we       (b_c1_o_bias_we       ) ,
        .b_i_bias_q        (b_c1_i_bias_q        ) 
    );
    
    cnn_max_pool #(
        .OCH       (POOL1_OCH        ) ,
        .ICH       (POOL1_ICH        ) ,
        .KX        (POOL_KX         ) ,
        .KY        (POOL_KY         ) ,
        .IX        (POOL1_IX        ) ,
        .IY        (POOL1_IY        ) ,
        .OCH_B     (POOL1_OCH_B     ) ,
        .ICH_B     (POOL1_ICH_B     ) ,
        .IX_B      (POOL1_IX_B      ) ,
        .I_F_BW    (I_F_BW    ) ,
        .PARA_B_BW (POOL1_B_BW ) ,
        .PARA_T_BW (POOL1_T_BW ) 
    ) u_max_pool1 (
        .clk              (clk              ) ,
        .areset           (areset           ) ,
        .i_run            (c_p1_i_run            ) ,
        .i_in_valid       (c_p1_i_in_valid       ) ,
        .i_ix_b_idx       (c_p1_i_ix_b_idx       ) ,
        .i_ix_t_idx       (c_p1_i_ix_t_idx       ) ,
        .i_iy_idx         (c_p1_i_iy_idx         ) ,
        .i_ich_b_idx      (c_p1_i_ich_b_idx      ) ,
        .i_ich_t_infmap   (c_p1_i_ich_t_infmap   ) ,
        .i_in_done        (c_p1_i_in_done        ) ,
        .o_idle           (c_p1_o_idle           ) ,
        .o_run            (c_p1_o_run            ) ,
        .o_en_err         (c_p1_o_en_err         ) ,
        .o_n_ready        (c_p1_o_n_ready        ) ,
        .o_ot_done        (c_p1_o_ot_done        ) ,
        .b_o_pool_addr    (b_p1_o_pool_addr_0    ) ,
        .b_o_pool_ce      (b_p1_o_pool_ce_0      ) ,
        .b_o_pool_byte_we (b_p1_o_pool_byte_we   ) ,
        .b_o_pool_d       (b_p1_o_pool_d         ) 
    );
    
    mem_copy #( 
        .DATA_NUM (B_C1_P_DATA_D * B_COL_NUM) ,
        .I_F_BW   (I_F_BW   ) 
    ) u_mem_copy_c1 ( 
        .clk             (clk             ) ,
        .areset          (areset          ) ,
        .i_run           (c_mc_c1_i_run           ) ,
        .o_idle          (c_mc_c1_o_idle          ) ,
        .o_run           (c_mc_c1_o_run           ) ,
        .o_en_err        (c_mc_c1_o_en_err        ) ,
        .o_n_ready       (c_mc_c1_o_n_ready       ) ,
        .o_ot_done       (c_mc_c1_o_ot_done       ) ,
        .b_o_infmap_addr (b_p1_o_pool_addr_1    ) ,
        .b_o_infmap_ce   (b_p1_o_pool_ce_1      ) ,
        .b_i_infmap_q    (b_p1_i_pool_q         ) ,
        .b_o_otfmap_addr (b_c2_o_infmap_addr_0  ) ,
        .b_o_otfmap_ce   (b_c2_o_infmap_ce_0    ) ,
        .b_o_otfmap_we   (b_c2_o_infmap_we      ) ,
        .b_o_otfmap_d    (b_c2_o_infmap_d       ) 
    );
    //--------------------------------------------------------------------
    
    // C2 layer
    //--------------------------------------------------------------------
    cnn_conv_layer #(
        .MULT_DELAY (MULT_DELAY ) ,
        .ACC_DELAY  (ACC_DELAY_C  ) ,
        .AB_DELAY   (AB_DELAY   ) ,
        .ICH        (CONV2_ICH        ) ,
        .OCH        (CONV2_OCH        ) ,
        .KX         (CONV_KX          ) ,
        .KY         (CONV_KY          ) ,
        .OX         (CONV2_OX         ) ,
        .OY         (CONV2_OY         ) ,
        .ICH_B      (CONV2_ICH_B      ) ,
        .OCH_B      (CONV2_OCH_B      ) ,
        .OX_B       (CONV2_OX_B       ) ,
        .I_F_BW     (I_F_BW     ) ,
        .W_BW       (W_BW       ) ,
        .B_BW       (B_BW       ) ,
        .PARA_B_BW  (CONV2_B_BW  ) ,
        .PARA_T_BW  (CONV2_T_BW  ) ,
        .B_SHIFT    (CONV2_B_SHIFT    ) ,
        .M_INV      (CONV2_M_INV      ) 
    ) u_c2_layer (
        .clk               (clk               ) ,
        .areset            (areset            ) ,
        .i_run             (c_c2_i_run             ) ,
        .o_idle            (c_c2_o_idle            ) ,
        .o_run             (c_c2_o_run             ) ,
        .o_en_err          (c_c2_o_en_err          ) ,
        .o_n_ready         (c_c2_o_n_ready         ) ,
        .o_ot_done         (c_c2_o_ot_done         ) ,
        .o_ot_valid        (c_c2_o_ot_valid        ) ,
        .o_ot_ox_b_idx     (c_c2_o_ot_ox_b_idx     ) ,
        .o_ot_ox_t_idx     (c_c2_o_ot_ox_t_idx     ) ,
        .o_ot_oy_idx       (c_c2_o_ot_oy_idx       ) ,
        .o_ot_och_b_idx    (c_c2_o_ot_och_b_idx    ) ,
        .o_ot_och_t_otfmap (c_c2_o_ot_och_t_otfmap ) ,
        .b_o_infmap_addr   (b_c2_o_infmap_addr_1   ) ,
        .b_o_infmap_ce     (b_c2_o_infmap_ce_1     ) ,
        .b_o_infmap_we     (     ) ,
        .b_i_infmap_q      (b_c2_i_infmap_q      ) ,
        .b_o_weight_addr   (b_c2_o_weight_addr   ) ,
        .b_o_weight_ce     (b_c2_o_weight_ce     ) ,
        .b_o_weight_we     (b_c2_o_weight_we     ) ,
        .b_i_weight_q      (b_c2_i_weight_q      ) ,
        .b_o_bias_addr     (b_c2_o_bias_addr     ) ,
        .b_o_bias_ce       (b_c2_o_bias_ce       ) ,
        .b_o_bias_we       (b_c2_o_bias_we       ) ,
        .b_i_bias_q        (b_c2_i_bias_q        ) 
    );
    
    cnn_max_pool #(
        .OCH       (POOL2_OCH        ) ,
        .ICH       (POOL2_ICH        ) ,
        .KX        (POOL_KX         ) ,
        .KY        (POOL_KY         ) ,
        .IX        (POOL2_IX        ) ,
        .IY        (POOL2_IY        ) ,
        .OCH_B     (POOL2_OCH_B     ) ,
        .ICH_B     (POOL2_ICH_B     ) ,
        .IX_B      (POOL2_IX_B      ) ,
        .I_F_BW    (I_F_BW    ) ,
        .PARA_B_BW (POOL2_B_BW ) ,
        .PARA_T_BW (POOL2_T_BW ) 
    ) u_max_pool2 (
        .clk              (clk              ) ,
        .areset           (areset           ) ,
        .i_run            (c_p2_i_run            ) ,
        .i_in_valid       (c_p2_i_in_valid       ) ,
        .i_ix_b_idx       (c_p2_i_ix_b_idx       ) ,
        .i_ix_t_idx       (c_p2_i_ix_t_idx       ) ,
        .i_iy_idx         (c_p2_i_iy_idx         ) ,
        .i_ich_b_idx      (c_p2_i_ich_b_idx      ) ,
        .i_ich_t_infmap   (c_p2_i_ich_t_infmap   ) ,
        .i_in_done        (c_p2_i_in_done        ) ,
        .o_idle           (c_p2_o_idle           ) ,
        .o_run            (c_p2_o_run            ) ,
        .o_en_err         (c_p2_o_en_err         ) ,
        .o_n_ready        (c_p2_o_n_ready        ) ,
        .o_ot_done        (c_p2_o_ot_done        ) ,
        .b_o_pool_addr    (b_p2_o_pool_addr_0    ) ,
        .b_o_pool_ce      (b_p2_o_pool_ce_0      ) ,
        .b_o_pool_byte_we (b_p2_o_pool_byte_we   ) ,
        .b_o_pool_d       (b_p2_o_pool_d       ) 
    );
    
    mem_copy #( 
        .DATA_NUM (B_C2_P_DATA_D * B_COL_NUM) ,
        .I_F_BW   (I_F_BW   ) 
    ) u_mem_copy_c2 ( 
        .clk             (clk             ) ,
        .areset          (areset          ) ,
        .i_run           (c_mc_c2_i_run           ) ,
        .o_idle          (c_mc_c2_o_idle          ) ,
        .o_run           (c_mc_c2_o_run           ) ,
        .o_en_err        (c_mc_c2_o_en_err        ) ,
        .o_n_ready       (c_mc_c2_o_n_ready       ) ,
        .o_ot_done       (c_mc_c2_o_ot_done       ) ,
        .b_o_infmap_addr (b_p2_o_pool_addr_1    ) ,
        .b_o_infmap_ce   (b_p2_o_pool_ce_1      ) ,
        .b_i_infmap_q    (b_p2_i_pool_q         ) ,
        .b_o_otfmap_addr (b_fc1_o_infmap_addr_0 ) ,
        .b_o_otfmap_ce   (b_fc1_o_infmap_ce_0   ) ,
        .b_o_otfmap_we   (b_fc1_o_infmap_we     ) ,
        .b_o_otfmap_d    (b_fc1_o_infmap_d      ) 
    );
    //--------------------------------------------------------------------
    
    // FC1 layer
    //--------------------------------------------------------------------
    cnn_fc_layer #(
        .MULT_DELAY     (MULT_DELAY     ) ,
        .ACC_DELAY      (ACC_DELAY_FC      ) ,
        .AB_DELAY       (AB_DELAY       ) ,
        .OCH            (FC1_OCH            ) ,
        .ICH            (FC1_ICH            ) ,
        .OCH_B          (FC1_OCH_B          ) ,
        .ICH_B          (FC1_ICH_B          ) ,
        .I_F_BW         (I_F_BW         ) ,
        .W_BW           (W_BW           ) ,
        .B_BW           (B_BW           ) ,
        .PARA_B_BW      (FC1_B_BW      ) ,
        .PARA_T_BW      (FC1_T_BW      ) ,
        .M_INV          (FC1_M_INV          ) ,
        .B_SCALE        (FC1_B_SCALE        ) ,
        .RELU           (FC1_RELU           ) ,
        .IS_FINAL_LAYER (FC1_IS_FINAL_LAYER ) 
    ) u_fc1_layer (
        .clk                (clk                ) ,
        .areset             (areset             ) ,
        .i_run              (c_fc1_i_run              ) ,
        .o_idle             (c_fc1_o_idle             ) ,
        .o_run              (c_fc1_o_run              ) ,
        .o_en_err           (c_fc1_o_en_err           ) ,
        .o_n_ready          (c_fc1_o_n_ready          ) ,
        .o_ot_done          (c_fc1_o_ot_done          ) ,
        .o_ot_valid         (    ) ,
        .o_ot_otfmap_idx    (    ) ,
        .b_o_infmap_addr    (b_fc1_o_infmap_addr_1    ) ,
        .b_o_infmap_ce      (b_fc1_o_infmap_ce_1      ) ,
        .b_o_infmap_we      (      ) ,
        .b_i_infmap_q       (b_fc1_i_infmap_q       ) ,
        .b_o_weight_addr    (b_fc1_o_weight_addr    ) ,
        .b_o_weight_ce      (b_fc1_o_weight_ce      ) ,
        .b_o_weight_we      (b_fc1_o_weight_we      ) ,
        .b_i_weight_q       (b_fc1_i_weight_q       ) ,
        .b_o_bias_addr      (b_fc1_o_bias_addr      ) ,
        .b_o_bias_ce        (b_fc1_o_bias_ce        ) ,
        .b_o_bias_we        (b_fc1_o_bias_we        ) ,
        .b_i_bias_q         (b_fc1_i_bias_q         ) ,
        .b_o_scaled_addr    (b_fc1_o_scaled_addr_0    ) ,
        .b_o_scaled_ce      (b_fc1_o_scaled_ce_0      ) ,
        .b_o_scaled_byte_we (b_fc1_o_scaled_byte_we ) ,
        .b_o_scaled_d       (b_fc1_o_scaled_d       ) 
    );
    
    mem_copy #( 
        .DATA_NUM (B_FC1_S_DATA_D * B_COL_NUM) ,
        .I_F_BW   (I_F_BW   ) 
    ) u_mem_copy_fc1 ( 
        .clk             (clk             ) ,
        .areset          (areset          ) ,
        .i_run           (c_mc_fc1_i_run           ) ,
        .o_idle          (c_mc_fc1_o_idle          ) ,
        .o_run           (c_mc_fc1_o_run           ) ,
        .o_en_err        (c_mc_fc1_o_en_err        ) ,
        .o_n_ready       (c_mc_fc1_o_n_ready       ) ,
        .o_ot_done       (c_mc_fc1_o_ot_done       ) ,
        .b_o_infmap_addr (b_fc1_o_scaled_addr_1    ) ,
        .b_o_infmap_ce   (b_fc1_o_scaled_ce_1      ) ,
        .b_i_infmap_q    (b_fc1_i_scaled_q         ) ,
        .b_o_otfmap_addr (b_fc2_o_infmap_addr_0    ) ,
        .b_o_otfmap_ce   (b_fc2_o_infmap_ce_0      ) ,
        .b_o_otfmap_we   (b_fc2_o_infmap_we        ) ,
        .b_o_otfmap_d    (b_fc2_o_infmap_d         ) 
    );
    //--------------------------------------------------------------------
    
    // FC2 layer
    //--------------------------------------------------------------------
    cnn_fc_layer #(
        .MULT_DELAY     (MULT_DELAY     ) ,
        .ACC_DELAY      (ACC_DELAY_FC      ) ,
        .AB_DELAY       (AB_DELAY       ) ,
        .OCH            (FC2_OCH            ) ,
        .ICH            (FC2_ICH            ) ,
        .OCH_B          (FC2_OCH_B          ) ,
        .ICH_B          (FC2_ICH_B          ) ,
        .I_F_BW         (I_F_BW         ) ,
        .W_BW           (W_BW           ) ,
        .B_BW           (B_BW           ) ,
        .PARA_B_BW      (FC2_B_BW      ) ,
        .PARA_T_BW      (FC2_T_BW      ) ,
        .M_INV          (FC2_M_INV          ) ,
        .B_SCALE        (FC2_B_SCALE        ) ,
        .RELU           (FC2_RELU           ) ,
        .IS_FINAL_LAYER (FC2_IS_FINAL_LAYER ) 
    ) u_fc2_layer (
        .clk                (clk                ) ,
        .areset             (areset             ) ,
        .i_run              (c_fc2_i_run              ) ,
        .o_idle             (c_fc2_o_idle             ) ,
        .o_run              (c_fc2_o_run              ) ,
        .o_en_err           (c_fc2_o_en_err           ) ,
        .o_n_ready          (c_fc2_o_n_ready          ) ,
        .o_ot_done          (c_fc2_o_ot_done          ) ,
        .o_ot_valid         (    ) ,
        .o_ot_otfmap_idx    (    ) ,
        .b_o_infmap_addr    (b_fc2_o_infmap_addr_1    ) ,
        .b_o_infmap_ce      (b_fc2_o_infmap_ce_1      ) ,
        .b_o_infmap_we      (     ) ,
        .b_i_infmap_q       (b_fc2_i_infmap_q       ) ,
        .b_o_weight_addr    (b_fc2_o_weight_addr    ) ,
        .b_o_weight_ce      (b_fc2_o_weight_ce      ) ,
        .b_o_weight_we      (b_fc2_o_weight_we      ) ,
        .b_i_weight_q       (b_fc2_i_weight_q       ) ,
        .b_o_bias_addr      (b_fc2_o_bias_addr      ) ,
        .b_o_bias_ce        (b_fc2_o_bias_ce        ) ,
        .b_o_bias_we        (b_fc2_o_bias_we        ) ,
        .b_i_bias_q         (b_fc2_i_bias_q         ) ,
        .b_o_scaled_addr    (b_fc2_o_scaled_addr_0    ) ,
        .b_o_scaled_ce      (b_fc2_o_scaled_ce_0      ) ,
        .b_o_scaled_byte_we (b_fc2_o_scaled_byte_we ) ,
        .b_o_scaled_d       (b_fc2_o_scaled_d       ) 
    );
    
    mem_copy #( 
        .DATA_NUM (B_FC2_S_DATA_D * B_COL_NUM) ,
        .I_F_BW   (I_F_BW   ) 
    ) u_mem_copy_fc2 ( 
        .clk             (clk             ) ,
        .areset          (areset          ) ,
        .i_run           (c_mc_fc2_i_run           ) ,
        .o_idle          (c_mc_fc2_o_idle          ) ,
        .o_run           (c_mc_fc2_o_run           ) ,
        .o_en_err        (c_mc_fc2_o_en_err        ) ,
        .o_n_ready       (c_mc_fc2_o_n_ready       ) ,
        .o_ot_done       (c_mc_fc2_o_ot_done       ) ,
        .b_o_infmap_addr (b_fc2_o_scaled_addr_1    ) ,
        .b_o_infmap_ce   (b_fc2_o_scaled_ce_1      ) ,
        .b_i_infmap_q    (b_fc2_i_scaled_q         ) ,
        .b_o_otfmap_addr (b_fc3_o_infmap_addr_0    ) ,
        .b_o_otfmap_ce   (b_fc3_o_infmap_ce_0      ) ,
        .b_o_otfmap_we   (b_fc3_o_infmap_we        ) ,
        .b_o_otfmap_d    (b_fc3_o_infmap_d         ) 
    );
    //--------------------------------------------------------------------
    
    // FC3 layer
    //--------------------------------------------------------------------
    cnn_fc_layer #(
        .MULT_DELAY     (MULT_DELAY     ) ,
        .ACC_DELAY      (ACC_DELAY_FC      ) ,
        .AB_DELAY       (AB_DELAY       ) ,
        .OCH            (FC3_OCH            ) ,
        .ICH            (FC3_ICH            ) ,
        .OCH_B          (FC3_OCH_B          ) ,
        .ICH_B          (FC3_ICH_B          ) ,
        .I_F_BW         (I_F_BW         ) ,
        .W_BW           (W_BW           ) ,
        .B_BW           (B_BW           ) ,
        .PARA_B_BW      (FC3_B_BW      ) ,
        .PARA_T_BW      (FC3_T_BW      ) ,
        .M_INV          (FC3_M_INV          ) ,
        .B_SCALE        (FC3_B_SCALE        ) ,
        .RELU           (FC3_RELU           ) ,
        .IS_FINAL_LAYER (FC3_IS_FINAL_LAYER ) 
    ) u_fc3_layer (
        .clk                (clk                ) ,
        .areset             (areset             ) ,
        .i_run              (c_fc3_i_run              ) ,
        .o_idle             (c_fc3_o_idle             ) ,
        .o_run              (c_fc3_o_run              ) ,
        .o_en_err           (c_fc3_o_en_err           ) ,
        .o_n_ready          (c_fc3_o_n_ready          ) ,
        .o_ot_done          (c_fc3_o_ot_done          ) ,
        .o_ot_valid         (c_fc3_o_ot_valid         ) ,
        .o_ot_otfmap_idx    (c_fc3_o_ot_otfmap_idx    ) ,
        .b_o_infmap_addr    (b_fc3_o_infmap_addr_1    ) ,
        .b_o_infmap_ce      (b_fc3_o_infmap_ce_1      ) ,
        .b_o_infmap_we      (      ) ,
        .b_i_infmap_q       (b_fc3_i_infmap_q       ) ,
        .b_o_weight_addr    (b_fc3_o_weight_addr    ) ,
        .b_o_weight_ce      (b_fc3_o_weight_ce      ) ,
        .b_o_weight_we      (b_fc3_o_weight_we      ) ,
        .b_i_weight_q       (b_fc3_i_weight_q       ) ,
        .b_o_bias_addr      (b_fc3_o_bias_addr      ) ,
        .b_o_bias_ce        (b_fc3_o_bias_ce        ) ,
        .b_o_bias_we        (b_fc3_o_bias_we        ) ,
        .b_i_bias_q         (b_fc3_i_bias_q         ) ,
        .b_o_scaled_addr    ( ) ,
        .b_o_scaled_ce      ( ) ,
        .b_o_scaled_byte_we ( ) ,
        .b_o_scaled_d       ( ) 
    );
    //--------------------------------------------------------------------
    
endmodule