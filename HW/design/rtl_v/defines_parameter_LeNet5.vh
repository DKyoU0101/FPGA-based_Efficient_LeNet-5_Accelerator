//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.19
// Design Name: LeNet-5
// Module Name: tb_LeNet5
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: CNN Convolutional Layer
//                  input : infmap, weight, bias, in_idx
//                  output: ot_idx, output(0 ~ 9)
//                  Max latency: 17,964 cycle, Max delay: 71,914 cycle
//                          (random seed:5, LOOP_NUM:100, avarage_cycle = 18,327)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

parameter   MULT_DELAY    = 3 ;
parameter   ACC_DELAY_C     = 1 ;
parameter   ACC_DELAY_FC    = 0 ;
parameter   AB_DELAY      = 1 ;

// parameter bit width
parameter   I_F_BW      = 8  ;  // Bit Width of Input Feature
parameter   W_BW        = 8  ;  // BW of weight parameter
parameter   B_BW        = 16 ;  // BW of bias parameter

parameter   M_BW     = I_F_BW + W_BW; // 16 = I_F_BW + W_BW

parameter   DATA_IDX_BW   = 20  ;

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
    
    localparam OTFMAP_O_IDX_BW  = $clog2(FC3_OCH) ; // 4
    
    localparam NUM_RD_INFMAP  = B_C1_I_DATA_D ; 
    localparam NUM_RD_PARAM   = B_C1_W_DATA_D + B_C1_B_DATA_D + B_C2_W_DATA_D + 
        B_C2_B_DATA_D + B_FC1_W_DATA_D + B_FC1_B_DATA_D + B_FC2_W_DATA_D + 
        B_FC2_B_DATA_D + B_FC3_W_DATA_D + B_FC3_B_DATA_D ; 
    
    // // counter
    // localparam OCH_B_CNT_BW = $clog2(OCH_B) ; // 5
    // localparam ICH_B_CNT_BW = $clog2(ICH_B) ; // 6
    
`define FP_IN_INFAMP "../design/ref_cpp/trace/in_infmap.txt" 

`define FP_IN_C1_WEIGHT  "../design/ref_cpp/trace/in_conv1_weight.txt"
`define FP_IN_C1_BIAS    "../design/ref_cpp/trace/in_conv1_bias.txt"

`define FP_IN_C2_WEIGHT  "../design/ref_cpp/trace/in_conv2_weight.txt"
`define FP_IN_C2_BIAS    "../design/ref_cpp/trace/in_conv2_bias.txt"

`define FP_IN_FC1_WEIGHT "../design/ref_cpp/trace/in_fc1_weight.txt"
`define FP_IN_FC1_BIAS   "../design/ref_cpp/trace/in_fc1_bias.txt"

`define FP_IN_FC2_WEIGHT "../design/ref_cpp/trace/in_fc2_weight.txt"
`define FP_IN_FC2_BIAS   "../design/ref_cpp/trace/in_fc2_bias.txt"

`define FP_IN_FC3_WEIGHT "../design/ref_cpp/trace/in_fc3_weight.txt"
`define FP_IN_FC3_BIAS   "../design/ref_cpp/trace/in_fc3_bias.txt"

`define FP_OT_OTFMAP "../design/ref_cpp/trace/ot_otfmap_rtl.txt"
