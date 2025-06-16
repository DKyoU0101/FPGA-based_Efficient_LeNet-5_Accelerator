//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.05
// Design Name: LeNet-5
// Module Name: LeNet5_core_ip
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: AMBA AXI4-Stream LeNet-5
//                  
// Dependencies: 
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1ns / 10ps

module LeNet5_core_ip #(
    parameter C_NUM_CLOCKS       = 1    ,
    parameter C_AXIS_S_DATA_WIDTH = 48   , // Data width of both input and output data
    parameter C_AXIS_S_ID_WIDTH   = 1    ,
    parameter C_AXIS_S_DEST_WIDTH = 1    ,
    parameter C_AXIS_S_USER_WIDTH = 8    ,
    parameter C_AXIS_M_DATA_WIDTH = 8   , // Data width of both input and output data
    parameter C_AXIS_M_ID_WIDTH   = 1    ,
    parameter C_AXIS_M_DEST_WIDTH = 1    ,
    parameter C_AXIS_M_USER_WIDTH = 1    ,
    parameter MULT_DELAY    = 3   ,
    parameter ACC_DELAY_C   = 1   ,
    parameter ACC_DELAY_FC  = 0   ,
    parameter AB_DELAY      = 1   ,
    parameter I_F_BW        = 8   ,
    parameter W_BW          = 8   ,  
    parameter B_BW          = 16  ,
    parameter DATA_IDX_BW   = 20  
) (

  input wire                              s_axis_aclk,
  input wire                              s_axis_areset,
  input wire                              s_axis_tvalid,
  output wire                             s_axis_tready,
  input wire  [C_AXIS_S_DATA_WIDTH-1:0]   s_axis_tdata,
  // no use this datas.... 
  input wire  [C_AXIS_S_DATA_WIDTH/8-1:0] s_axis_tkeep,
  input wire  [C_AXIS_S_DATA_WIDTH/8-1:0] s_axis_tstrb,
  input wire                              s_axis_tlast,
  input wire [C_AXIS_S_ID_WIDTH-1:0]      s_axis_tid,
  input wire  [C_AXIS_S_DEST_WIDTH-1:0]   s_axis_tdest,
  input wire  [C_AXIS_S_USER_WIDTH-1:0]   s_axis_tuser,
  ////////////////////////////////////////////////
  input wire                              m_axis_aclk,
  output wire                             m_axis_tvalid,
  input  wire                             m_axis_tready,
  output wire [C_AXIS_M_DATA_WIDTH-1:0]   m_axis_tdata,
  output wire [C_AXIS_M_DATA_WIDTH/8-1:0] m_axis_tkeep,
  output wire [C_AXIS_M_DATA_WIDTH/8-1:0] m_axis_tstrb,
  output wire                             m_axis_tlast,
  output wire [C_AXIS_M_ID_WIDTH-1:0]     m_axis_tid,
  output wire [C_AXIS_M_DEST_WIDTH-1:0]   m_axis_tdest,
  output wire [C_AXIS_M_USER_WIDTH-1:0]   m_axis_tuser

);

//==============================================================================
// Core IP port Setting
//==============================================================================
    wire clk = s_axis_aclk;
    wire areset = s_axis_areset;
    
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
// Declaration DUT Port
//==============================================================================
    localparam OTFMAP_O_IDX_BW  = 4 ; // 4
    
    wire                         c_core_i_in_data_valid    ;
    wire [DATA_IDX_BW-1 : 0]     c_core_i_in_data_idx      ;
    wire                         c_core_o_idle             ;
    wire                         c_core_o_run              ;
    wire                         c_core_o_data_read_valid  ;
    wire                         c_core_o_ot_valid         ;
    wire [DATA_IDX_BW-1 : 0]     c_core_o_ot_data_idx      ;
    wire [OTFMAP_O_IDX_BW-1 : 0] c_core_o_ot_data_result   ;
    
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
    
//==============================================================================
// Top Module BRAM Port 0 declaration
//==============================================================================
    // infmap
    wire [B_C1_I_ADDR_W-1 : 0]   b_in_o_infmap_addr_0     ;
    wire                         b_in_o_infmap_ce_0       ;
    wire                         b_in_o_infmap_we_0       ;
    reg  [B_C1_I_DATA_W-1 : 0]   b_in_o_infmap_d_0        ; // not using write bram
    wire [B_C1_I_DATA_W-1 : 0]   b_in_i_infmap_q_0        ;
    
    // conv1
    wire [B_C1_I_ADDR_W-1 : 0]   b_c1_o_infmap_addr_0     ;
    wire                         b_c1_o_infmap_ce_0       ;
    wire                         b_c1_o_infmap_we_0       ;
    wire [B_C1_I_DATA_W-1 : 0]   b_c1_o_infmap_d_0        ;
    wire [B_C1_I_DATA_W-1 : 0]   b_c1_i_infmap_q_0        ;
    wire [B_C1_W_ADDR_W-1 : 0]   b_c1_o_weight_addr_0     ;
    wire                         b_c1_o_weight_ce_0       ;
    wire                         b_c1_o_weight_we_0       ;
    reg  [B_C1_W_DATA_W-1 : 0]   b_c1_o_weight_d_0        ; // not using write bram
    wire [B_C1_W_DATA_W-1 : 0]   b_c1_i_weight_q_0        ;
    wire [B_C1_B_ADDR_W-1 : 0]   b_c1_o_bias_addr_0       ;
    wire                         b_c1_o_bias_ce_0         ;
    wire                         b_c1_o_bias_we_0         ;
    reg  [B_C1_B_DATA_W-1 : 0]   b_c1_o_bias_d_0          ; // not using write bram
    wire [B_C1_B_DATA_W-1 : 0]   b_c1_i_bias_q_0          ;
    wire [B_C1_P_ADDR_W-1 : 0]   b_p1_o_pool_addr_0       ;
    wire                         b_p1_o_pool_ce_0         ;
    wire [B_COL_NUM-1 : 0]       b_p1_o_pool_byte_we_0    ;
    wire [B_C1_P_DATA_W-1 : 0]   b_p1_o_pool_d_0          ;
    wire [B_C1_P_DATA_W-1 : 0]   b_p1_i_pool_q_0          ;
    
    // conv2
    wire [B_C2_I_ADDR_W-1 : 0]   b_c2_o_infmap_addr_0     ;
    wire                         b_c2_o_infmap_ce_0       ;
    wire                         b_c2_o_infmap_we_0       ;
    wire [B_C2_I_DATA_W-1 : 0]   b_c2_o_infmap_d_0        ;
    wire [B_C2_I_DATA_W-1 : 0]   b_c2_i_infmap_q_0        ;
    wire [B_C2_W_ADDR_W-1 : 0]   b_c2_o_weight_addr_0     ;
    wire                         b_c2_o_weight_ce_0       ;
    wire                         b_c2_o_weight_we_0       ;
    reg  [B_C2_W_DATA_W-1 : 0]   b_c2_o_weight_d_0        ; // not using write bram
    wire [B_C2_W_DATA_W-1 : 0]   b_c2_i_weight_q_0        ;
    wire [B_C2_B_ADDR_W-1 : 0]   b_c2_o_bias_addr_0       ;
    wire                         b_c2_o_bias_ce_0         ;
    wire                         b_c2_o_bias_we_0         ;
    reg  [B_C2_B_DATA_W-1 : 0]   b_c2_o_bias_d_0          ; // not using write bram
    wire [B_C2_B_DATA_W-1 : 0]   b_c2_i_bias_q_0          ;
    wire [B_C2_P_ADDR_W-1 : 0]   b_p2_o_pool_addr_0       ;
    wire                         b_p2_o_pool_ce_0         ;
    wire [B_COL_NUM-1 : 0]       b_p2_o_pool_byte_we_0    ;
    wire [B_C2_P_DATA_W-1 : 0]   b_p2_o_pool_d_0          ;
    wire [B_C2_P_DATA_W-1 : 0]   b_p2_i_pool_q_0          ;
    
    // fc1
    wire [B_FC1_I_ADDR_W-1 : 0]  b_fc1_o_infmap_addr_0     ;
    wire                         b_fc1_o_infmap_ce_0       ;
    wire                         b_fc1_o_infmap_we_0       ;
    wire [B_FC1_I_DATA_W-1 : 0]  b_fc1_o_infmap_d_0        ;
    wire [B_FC1_I_DATA_W-1 : 0]  b_fc1_i_infmap_q_0        ;
    wire [B_FC1_W_ADDR_W-1 : 0]  b_fc1_o_weight_addr_0     ;
    wire                         b_fc1_o_weight_ce_0       ;
    wire                         b_fc1_o_weight_we_0       ;
    reg  [B_FC1_W_DATA_W-1 : 0]  b_fc1_o_weight_d_0        ; // not using write bram
    wire [B_FC1_W_DATA_W-1 : 0]  b_fc1_i_weight_q_0        ;
    wire [B_FC1_B_ADDR_W-1 : 0]  b_fc1_o_bias_addr_0       ;
    wire                         b_fc1_o_bias_ce_0         ;
    wire                         b_fc1_o_bias_we_0         ;
    reg  [B_FC1_B_DATA_W-1 : 0]  b_fc1_o_bias_d_0          ; // not using write bram
    wire [B_FC1_B_DATA_W-1 : 0]  b_fc1_i_bias_q_0          ;
    wire [B_FC1_S_ADDR_W-1 : 0]  b_fc1_o_scaled_addr_0     ;
    wire                         b_fc1_o_scaled_ce_0       ;
    wire [B_COL_NUM-1 : 0]       b_fc1_o_scaled_byte_we_0  ;
    wire [B_FC1_S_DATA_W-1 : 0]  b_fc1_o_scaled_d_0        ;
    wire [B_FC1_S_DATA_W-1 : 0]  b_fc1_i_scaled_q_0        ;
    
    // fc2
    wire [B_FC2_I_ADDR_W-1 : 0]  b_fc2_o_infmap_addr_0     ;
    wire                         b_fc2_o_infmap_ce_0       ;
    wire                         b_fc2_o_infmap_we_0       ;
    wire [B_FC2_I_DATA_W-1 : 0]  b_fc2_o_infmap_d_0        ;
    wire [B_FC2_I_DATA_W-1 : 0]  b_fc2_i_infmap_q_0        ;
    wire [B_FC2_W_ADDR_W-1 : 0]  b_fc2_o_weight_addr_0     ;
    wire                         b_fc2_o_weight_ce_0       ;
    wire                         b_fc2_o_weight_we_0       ;
    reg  [B_FC2_W_DATA_W-1 : 0]  b_fc2_o_weight_d_0        ; // not using write bram
    wire [B_FC2_W_DATA_W-1 : 0]  b_fc2_i_weight_q_0        ;
    wire [B_FC2_B_ADDR_W-1 : 0]  b_fc2_o_bias_addr_0       ;
    wire                         b_fc2_o_bias_ce_0         ;
    wire                         b_fc2_o_bias_we_0         ;
    reg  [B_FC2_B_DATA_W-1 : 0]  b_fc2_o_bias_d_0          ; // not using write bram
    wire [B_FC2_B_DATA_W-1 : 0]  b_fc2_i_bias_q_0          ;
    wire [B_FC2_S_ADDR_W-1 : 0]  b_fc2_o_scaled_addr_0     ;
    wire                         b_fc2_o_scaled_ce_0       ;
    wire [B_COL_NUM-1 : 0]       b_fc2_o_scaled_byte_we_0  ;
    wire [B_FC2_S_DATA_W-1 : 0]  b_fc2_o_scaled_d_0        ;
    wire [B_FC2_S_DATA_W-1 : 0]  b_fc2_i_scaled_q_0        ;
    
    // fc3
    wire [B_FC3_I_ADDR_W-1 : 0]  b_fc3_o_infmap_addr_0     ;
    wire                         b_fc3_o_infmap_ce_0       ;
    wire                         b_fc3_o_infmap_we_0       ;
    wire [B_FC3_I_DATA_W-1 : 0]  b_fc3_o_infmap_d_0        ;
    wire [B_FC3_I_DATA_W-1 : 0]  b_fc3_i_infmap_q_0        ;
    wire [B_FC3_W_ADDR_W-1 : 0]  b_fc3_o_weight_addr_0     ;
    wire                         b_fc3_o_weight_ce_0       ;
    wire                         b_fc3_o_weight_we_0       ;
    reg  [B_FC3_W_DATA_W-1 : 0]  b_fc3_o_weight_d_0        ; // not using write bram
    wire [B_FC3_W_DATA_W-1 : 0]  b_fc3_i_weight_q_0        ;
    wire [B_FC3_B_ADDR_W-1 : 0]  b_fc3_o_bias_addr_0       ;
    wire                         b_fc3_o_bias_ce_0         ;
    wire                         b_fc3_o_bias_we_0         ;
    reg  [B_FC3_B_DATA_W-1 : 0]  b_fc3_o_bias_d_0          ; // not using write bram
    wire [B_FC3_B_DATA_W-1 : 0]  b_fc3_i_bias_q_0          ;
    
//==============================================================================
// Top Module BRAM Port 1 declaration
//==============================================================================
    // infmap
    reg   [B_C1_I_ADDR_W-1 : 0]   b_in_o_infmap_addr_1     ;
    reg                           b_in_o_infmap_ce_1       ;
    reg                           b_in_o_infmap_we_1       ;
    reg   [B_C1_I_DATA_W-1 : 0]   b_in_o_infmap_d_1        ; // not using write bram
    
    // conv1
    reg  [B_C1_I_ADDR_W-1 : 0]   b_c1_o_infmap_addr_1     ;
    reg                          b_c1_o_infmap_ce_1       ;
    reg                          b_c1_o_infmap_we_1       ;
    reg  [B_C1_I_DATA_W-1 : 0]   b_c1_o_infmap_d_1        ;
    reg  [B_C1_W_ADDR_W-1 : 0]   b_c1_o_weight_addr_1     ;
    reg                          b_c1_o_weight_ce_1       ;
    reg                          b_c1_o_weight_we_1       ;
    reg  [B_C1_W_DATA_W-1 : 0]   b_c1_o_weight_d_1        ; // not using write bram
    reg  [B_C1_B_ADDR_W-1 : 0]   b_c1_o_bias_addr_1       ;
    reg                          b_c1_o_bias_ce_1         ;
    reg                          b_c1_o_bias_we_1         ;
    reg  [B_C1_B_DATA_W-1 : 0]   b_c1_o_bias_d_1          ; // not using write bram
    reg  [B_C1_P_ADDR_W-1 : 0]   b_p1_o_pool_addr_1       ;
    reg                          b_p1_o_pool_ce_1         ;
    reg  [B_COL_NUM-1 : 0]       b_p1_o_pool_byte_we_1    ;
    reg  [B_C1_P_DATA_W-1 : 0]   b_p1_o_pool_d_1          ;
    
    // conv2
    reg  [B_C2_I_ADDR_W-1 : 0]   b_c2_o_infmap_addr_1     ;
    reg                          b_c2_o_infmap_ce_1       ;
    reg                          b_c2_o_infmap_we_1       ;
    reg  [B_C2_I_DATA_W-1 : 0]   b_c2_o_infmap_d_1        ;
    reg  [B_C2_W_ADDR_W-1 : 0]   b_c2_o_weight_addr_1     ;
    reg                          b_c2_o_weight_ce_1       ;
    reg                          b_c2_o_weight_we_1       ;
    reg  [B_C2_W_DATA_W-1 : 0]   b_c2_o_weight_d_1        ; // not using write bram
    reg  [B_C2_B_ADDR_W-1 : 0]   b_c2_o_bias_addr_1       ;
    reg                          b_c2_o_bias_ce_1         ;
    reg                          b_c2_o_bias_we_1         ;
    reg  [B_C2_B_DATA_W-1 : 0]   b_c2_o_bias_d_1          ; // not using write bram
    reg  [B_C2_P_ADDR_W-1 : 0]   b_p2_o_pool_addr_1       ;
    reg                          b_p2_o_pool_ce_1         ;
    reg  [B_COL_NUM-1 : 0]       b_p2_o_pool_byte_we_1    ;
    reg  [B_C2_P_DATA_W-1 : 0]   b_p2_o_pool_d_1          ;
    
    // fc1
    reg  [B_FC1_I_ADDR_W-1 : 0]  b_fc1_o_infmap_addr_1     ;
    reg                          b_fc1_o_infmap_ce_1       ;
    reg                          b_fc1_o_infmap_we_1       ;
    reg  [B_FC1_I_DATA_W-1 : 0]  b_fc1_o_infmap_d_1        ;
    reg  [B_FC1_W_ADDR_W-1 : 0]  b_fc1_o_weight_addr_1     ;
    reg                          b_fc1_o_weight_ce_1       ;
    reg                          b_fc1_o_weight_we_1       ;
    reg  [B_FC1_W_DATA_W-1 : 0]  b_fc1_o_weight_d_1        ; // not using write bram
    reg  [B_FC1_B_ADDR_W-1 : 0]  b_fc1_o_bias_addr_1       ;
    reg                          b_fc1_o_bias_ce_1         ;
    reg                          b_fc1_o_bias_we_1         ;
    reg  [B_FC1_B_DATA_W-1 : 0]  b_fc1_o_bias_d_1          ; // not using write bram
    reg  [B_FC1_S_ADDR_W-1 : 0]  b_fc1_o_scaled_addr_1     ;
    reg                          b_fc1_o_scaled_ce_1       ;
    reg  [B_COL_NUM-1 : 0]       b_fc1_o_scaled_byte_we_1  ;
    reg  [B_FC1_S_DATA_W-1 : 0]  b_fc1_o_scaled_d_1        ;
    
    // fc2
    reg  [B_FC2_I_ADDR_W-1 : 0]  b_fc2_o_infmap_addr_1     ;
    reg                          b_fc2_o_infmap_ce_1       ;
    reg                          b_fc2_o_infmap_we_1       ;
    reg  [B_FC2_I_DATA_W-1 : 0]  b_fc2_o_infmap_d_1        ;
    reg  [B_FC2_W_ADDR_W-1 : 0]  b_fc2_o_weight_addr_1     ;
    reg                          b_fc2_o_weight_ce_1       ;
    reg                          b_fc2_o_weight_we_1       ;
    reg  [B_FC2_W_DATA_W-1 : 0]  b_fc2_o_weight_d_1        ; // not using write bram
    reg  [B_FC2_B_ADDR_W-1 : 0]  b_fc2_o_bias_addr_1       ;
    reg                          b_fc2_o_bias_ce_1         ;
    reg                          b_fc2_o_bias_we_1         ;
    reg  [B_FC2_B_DATA_W-1 : 0]  b_fc2_o_bias_d_1          ; // not using write bram
    reg  [B_FC2_S_ADDR_W-1 : 0]  b_fc2_o_scaled_addr_1     ;
    reg                          b_fc2_o_scaled_ce_1       ;
    reg  [B_COL_NUM-1 : 0]       b_fc2_o_scaled_byte_we_1  ;
    reg  [B_FC2_S_DATA_W-1 : 0]  b_fc2_o_scaled_d_1        ;
    
    // fc3
    reg  [B_FC3_I_ADDR_W-1 : 0]  b_fc3_o_infmap_addr_1     ;
    reg                          b_fc3_o_infmap_ce_1       ;
    reg                          b_fc3_o_infmap_we_1       ;
    reg  [B_FC3_I_DATA_W-1 : 0]  b_fc3_o_infmap_d_1        ;
    reg  [B_FC3_W_ADDR_W-1 : 0]  b_fc3_o_weight_addr_1     ;
    reg                          b_fc3_o_weight_ce_1       ;
    reg                          b_fc3_o_weight_we_1       ;
    reg  [B_FC3_W_DATA_W-1 : 0]  b_fc3_o_weight_d_1        ; // not using write bram
    reg  [B_FC3_B_ADDR_W-1 : 0]  b_fc3_o_bias_addr_1       ;
    reg                          b_fc3_o_bias_ce_1         ;
    reg                          b_fc3_o_bias_we_1         ;
    reg  [B_FC3_B_DATA_W-1 : 0]  b_fc3_o_bias_d_1          ; // not using write bram
    
//==============================================================================
// Read Address Counter
//==============================================================================
    wire w_rd_param  = s_axis_tuser[0];
    wire w_rd_infmap = s_axis_tuser[1];
    
    reg                             r_axis_tvalid ;
    reg  [C_AXIS_S_DATA_WIDTH-1:0]  r_axis_tdata  ;
    
    always @(posedge s_axis_aclk) begin
        if(s_axis_areset) begin
            r_axis_tvalid <= 'b0;
            r_axis_tdata  <= 'b0;
        end else begin
            r_axis_tvalid <= s_axis_tvalid & s_axis_tready;
            r_axis_tdata  <= s_axis_tdata;
        end
    end
    
    reg  [B_C1_I_ADDR_W-1 : 0] r_in_cnt        ;
    reg  r_in_cnt_valid    , r_in_cnt_max    ;
    
    reg  [B_C1_W_ADDR_W-1 : 0] r_c1_w_cnt      ;
    reg  r_c1_w_cnt_valid  , r_c1_w_cnt_max  ;
    reg  [B_C1_B_ADDR_W-1 : 0] r_c1_b_cnt      ;
    reg  r_c1_b_cnt_valid  , r_c1_b_cnt_max  ;
    
    reg  [B_C2_W_ADDR_W-1 : 0] r_c2_w_cnt      ;
    reg  r_c2_w_cnt_valid  , r_c2_w_cnt_max  ;
    reg  [B_C2_B_ADDR_W-1 : 0] r_c2_b_cnt      ;
    reg  r_c2_b_cnt_valid  , r_c2_b_cnt_max  ;
    
    reg  [B_FC1_W_ADDR_W-1 : 0] r_fc1_w_cnt     ;
    reg  r_fc1_w_cnt_valid , r_fc1_w_cnt_max  ;
    reg  [B_FC1_B_ADDR_W-1 : 0] r_fc1_b_cnt     ;
    reg  r_fc1_b_cnt_valid , r_fc1_b_cnt_max  ;
    
    reg  [B_FC2_W_ADDR_W-1 : 0] r_fc2_w_cnt     ;
    reg  r_fc2_w_cnt_valid , r_fc2_w_cnt_max  ;
    reg  [B_FC2_B_ADDR_W-1 : 0] r_fc2_b_cnt     ;
    reg  r_fc2_b_cnt_valid , r_fc2_b_cnt_max  ;
    
    reg  [B_FC3_W_ADDR_W-1 : 0] r_fc3_w_cnt     ;
    reg  r_fc3_w_cnt_valid , r_fc3_w_cnt_max  ;
    reg  [B_FC3_B_ADDR_W-1 : 0] r_fc3_b_cnt     ;
    reg  r_fc3_b_cnt_valid , r_fc3_b_cnt_max  ;
    
    
    reg  r_addr_cnt_en ;
    
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_in_cnt_max || r_fc3_b_cnt_max) && r_axis_tvalid)) begin
            r_addr_cnt_en <= 'b0;
        end else if((s_axis_tvalid) && (!r_addr_cnt_en)) begin
            r_addr_cnt_en <= 1'b1;
        end
    end
    
    // infmap
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_in_cnt_max) && (r_axis_tvalid))) begin
            r_in_cnt_valid <= 'b0;
            r_in_cnt_max <= 'b0;
            r_in_cnt <= 'b0;
        end else begin
            if((s_axis_tvalid) && (!r_addr_cnt_en) && (w_rd_infmap))
                r_in_cnt_valid <= 1'b1;
            if((r_in_cnt == B_C1_I_DATA_D-2) && (r_axis_tvalid))
                r_in_cnt_max <= 1'b1;
            if((r_in_cnt_valid) && (r_axis_tvalid))
                r_in_cnt <= r_in_cnt + 1;
        end
    end
    
    // C1 weight
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_c1_w_cnt_max) && (r_axis_tvalid))) begin
            r_c1_w_cnt_valid <= 'b0;
            r_c1_w_cnt_max <= 'b0;
            r_c1_w_cnt <= 'b0;
        end else begin
            if((s_axis_tvalid) && (!r_addr_cnt_en) && (w_rd_param))
                r_c1_w_cnt_valid <= 1'b1;
            if((r_c1_w_cnt == B_C1_W_DATA_D-2) && (r_axis_tvalid))
                r_c1_w_cnt_max <= 1'b1;
            if((r_c1_w_cnt_valid) && (r_axis_tvalid))
                r_c1_w_cnt <= r_c1_w_cnt + 1;
        end
    end
    
    // C1 bias
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_c1_b_cnt_max) && (r_axis_tvalid))) begin
            r_c1_b_cnt_valid <= 'b0;
            r_c1_b_cnt_max <= 'b0;
            r_c1_b_cnt <= 'b0;
        end else begin
            if((r_c1_w_cnt_max) && (r_axis_tvalid))
                r_c1_b_cnt_valid <= 1'b1;
            if((r_c1_b_cnt == B_C1_B_DATA_D-2) && (r_axis_tvalid))
                r_c1_b_cnt_max <= 1'b1;
            if((r_c1_b_cnt_valid) && (r_axis_tvalid))
                r_c1_b_cnt <= r_c1_b_cnt + 1;
        end
    end
    
    // C2 weight
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_c2_w_cnt_max) && (r_axis_tvalid))) begin
            r_c2_w_cnt_valid <= 'b0;
            r_c2_w_cnt_max <= 'b0;
            r_c2_w_cnt <= 'b0;
        end else begin
            if((r_c1_b_cnt_max) && (r_axis_tvalid))
                r_c2_w_cnt_valid <= 1'b1;
            if((r_c2_w_cnt == B_C2_W_DATA_D-2) && (r_axis_tvalid))
                r_c2_w_cnt_max <= 1'b1;
            if((r_c2_w_cnt_valid) && (r_axis_tvalid))
                r_c2_w_cnt <= r_c2_w_cnt + 1;
        end
    end
    
    // C2 bias
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_c2_b_cnt_max) && (r_axis_tvalid))) begin
            r_c2_b_cnt_valid <= 'b0;
            r_c2_b_cnt_max <= 'b0;
            r_c2_b_cnt <= 'b0;
        end else begin
            if((r_c2_w_cnt_max) && (r_axis_tvalid))
                r_c2_b_cnt_valid <= 1'b1;
            if((r_c2_b_cnt == B_C2_B_DATA_D-2) && (r_axis_tvalid))
                r_c2_b_cnt_max <= 1'b1;
            if((r_c2_b_cnt_valid) && (r_axis_tvalid))
                r_c2_b_cnt <= r_c2_b_cnt + 1;
        end
    end
    
    // FC1 weight
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc1_w_cnt_max) && (r_axis_tvalid))) begin
            r_fc1_w_cnt_valid <= 'b0;
            r_fc1_w_cnt_max <= 'b0;
            r_fc1_w_cnt <= 'b0;
        end else begin
            if((r_c2_b_cnt_max) && (r_axis_tvalid))
                r_fc1_w_cnt_valid <= 1'b1;
            if((r_fc1_w_cnt == B_FC1_W_DATA_D-2) && (r_axis_tvalid))
                r_fc1_w_cnt_max <= 1'b1;
            if((r_fc1_w_cnt_valid) && (r_axis_tvalid))
                r_fc1_w_cnt <= r_fc1_w_cnt + 1;
        end
    end
    
    // FC1 bias
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc1_b_cnt_max) && (r_axis_tvalid))) begin
            r_fc1_b_cnt_valid <= 'b0;
            r_fc1_b_cnt_max <= 'b0;
            r_fc1_b_cnt <= 'b0;
        end else begin
            if((r_fc1_w_cnt_max) && (r_axis_tvalid))
                r_fc1_b_cnt_valid <= 1'b1;
            if((r_fc1_b_cnt == B_FC1_B_DATA_D-2) && (r_axis_tvalid))
                r_fc1_b_cnt_max <= 1'b1;
            if((r_fc1_b_cnt_valid) && (r_axis_tvalid))
                r_fc1_b_cnt <= r_fc1_b_cnt + 1;
        end
    end
    
    // FC2 weight
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc2_w_cnt_max) && (r_axis_tvalid))) begin
            r_fc2_w_cnt_valid <= 'b0;
            r_fc2_w_cnt_max <= 'b0;
            r_fc2_w_cnt <= 'b0;
        end else begin
            if((r_fc1_b_cnt_max) && (r_axis_tvalid))
                r_fc2_w_cnt_valid <= 1'b1;
            if((r_fc2_w_cnt == B_FC2_W_DATA_D-2) && (r_axis_tvalid))
                r_fc2_w_cnt_max <= 1'b1;
            if((r_fc2_w_cnt_valid) && (r_axis_tvalid))
                r_fc2_w_cnt <= r_fc2_w_cnt + 1;
        end
    end
    
    // FC2 bias
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc2_b_cnt_max) && (r_axis_tvalid))) begin
            r_fc2_b_cnt_valid <= 'b0;
            r_fc2_b_cnt_max <= 'b0;
            r_fc2_b_cnt <= 'b0;
        end else begin
            if((r_fc2_w_cnt_max) && (r_axis_tvalid))
                r_fc2_b_cnt_valid <= 1'b1;
            if((r_fc2_b_cnt == B_FC2_B_DATA_D-2) && (r_axis_tvalid))
                r_fc2_b_cnt_max <= 1'b1;
            if((r_fc2_b_cnt_valid) && (r_axis_tvalid))
                r_fc2_b_cnt <= r_fc2_b_cnt + 1;
        end
    end
    
    // FC3 weight
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc3_w_cnt_max) && (r_axis_tvalid))) begin
            r_fc3_w_cnt_valid <= 'b0;
            r_fc3_w_cnt_max <= 'b0;
            r_fc3_w_cnt <= 'b0;
        end else begin
            if((r_fc2_b_cnt_max) && (r_axis_tvalid))
                r_fc3_w_cnt_valid <= 1'b1;
            if((r_fc3_w_cnt == B_FC3_W_DATA_D-2) && (r_axis_tvalid))
                r_fc3_w_cnt_max <= 1'b1;
            if((r_fc3_w_cnt_valid) && (r_axis_tvalid))
                r_fc3_w_cnt <= r_fc3_w_cnt + 1;
        end
    end
    
    // FC3 bias
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || ((r_fc3_b_cnt_max) && (r_axis_tvalid))) begin
            r_fc3_b_cnt_valid <= 'b0;
            r_fc3_b_cnt_max <= 'b0;
            r_fc3_b_cnt <= 'b0;
        end else begin
            if((r_fc3_w_cnt_max) && (r_axis_tvalid))
                r_fc3_b_cnt_valid <= 1'b1;
            if((r_fc3_b_cnt == B_FC3_B_DATA_D-2) && (r_axis_tvalid))
                r_fc3_b_cnt_max <= 1'b1;
            if((r_fc3_b_cnt_valid) && (r_axis_tvalid))
                r_fc3_b_cnt <= r_fc3_b_cnt + 1;
        end
    end
    
//==============================================================================
// Read CNN Parameter
//==============================================================================
    always @(*) begin
        b_in_o_infmap_addr_1    = r_in_cnt ;
        b_in_o_infmap_ce_1      = r_addr_cnt_en ;
        b_in_o_infmap_we_1      = (r_in_cnt_valid) && (r_axis_tvalid) ;
        b_in_o_infmap_d_1       = r_axis_tdata[B_C1_I_DATA_W-1 : 0] ;
        
        b_c1_o_weight_addr_1    = r_c1_w_cnt ;
        b_c1_o_weight_ce_1      = r_addr_cnt_en ;
        b_c1_o_weight_we_1      = (r_c1_w_cnt_valid) && (r_axis_tvalid) ;
        b_c1_o_weight_d_1       = r_axis_tdata[B_C1_W_DATA_W-1 : 0] ;
        b_c1_o_bias_addr_1      = r_c1_b_cnt ;
        b_c1_o_bias_ce_1        = r_addr_cnt_en ;
        b_c1_o_bias_we_1        = (r_c1_b_cnt_valid) && (r_axis_tvalid) ;
        b_c1_o_bias_d_1         = r_axis_tdata[B_C1_B_DATA_W-1 : 0] ;
        
        b_c2_o_weight_addr_1    = r_c2_w_cnt ;
        b_c2_o_weight_ce_1      = r_addr_cnt_en ;
        b_c2_o_weight_we_1      = (r_c2_w_cnt_valid) && (r_axis_tvalid) ;
        b_c2_o_weight_d_1       = r_axis_tdata[B_C2_W_DATA_W-1 : 0] ;
        b_c2_o_bias_addr_1      = r_c2_b_cnt ;
        b_c2_o_bias_ce_1        = r_addr_cnt_en ;
        b_c2_o_bias_we_1        = (r_c2_b_cnt_valid) && (r_axis_tvalid) ;
        b_c2_o_bias_d_1         = r_axis_tdata[B_C2_B_DATA_W-1 : 0] ;
        
        b_fc1_o_weight_addr_1   = r_fc1_w_cnt ;
        b_fc1_o_weight_ce_1     = r_addr_cnt_en ;
        b_fc1_o_weight_we_1     = (r_fc1_w_cnt_valid) && (r_axis_tvalid) ;
        b_fc1_o_weight_d_1      = r_axis_tdata[B_FC1_W_DATA_W-1 : 0] ;
        b_fc1_o_bias_addr_1     = r_fc1_b_cnt ;
        b_fc1_o_bias_ce_1       = r_addr_cnt_en ;
        b_fc1_o_bias_we_1       = (r_fc1_b_cnt_valid) && (r_axis_tvalid) ;
        b_fc1_o_bias_d_1        = r_axis_tdata[B_FC1_B_DATA_W-1 : 0] ;
        
        b_fc2_o_weight_addr_1   = r_fc2_w_cnt ;
        b_fc2_o_weight_ce_1     = r_addr_cnt_en ;
        b_fc2_o_weight_we_1     = (r_fc2_w_cnt_valid) && (r_axis_tvalid) ;
        b_fc2_o_weight_d_1      = r_axis_tdata[B_FC2_W_DATA_W-1 : 0] ;
        b_fc2_o_bias_addr_1     = r_fc2_b_cnt ;
        b_fc2_o_bias_ce_1       = r_addr_cnt_en ;
        b_fc2_o_bias_we_1       = (r_fc2_b_cnt_valid) && (r_axis_tvalid) ;
        b_fc2_o_bias_d_1        = r_axis_tdata[B_FC2_B_DATA_W-1 : 0] ;
        
        b_fc3_o_weight_addr_1   = r_fc3_w_cnt ;
        b_fc3_o_weight_ce_1     = r_addr_cnt_en ;
        b_fc3_o_weight_we_1     = (r_fc3_w_cnt_valid) && (r_axis_tvalid) ;
        b_fc3_o_weight_d_1      = r_axis_tdata[B_FC3_W_DATA_W-1 : 0] ;
        b_fc3_o_bias_addr_1     = r_fc3_b_cnt ;
        b_fc3_o_bias_ce_1       = r_addr_cnt_en ;
        b_fc3_o_bias_we_1       = (r_fc3_b_cnt_valid) && (r_axis_tvalid) ;
        b_fc3_o_bias_d_1        = r_axis_tdata[B_FC3_B_DATA_W-1 : 0] ;
    end
    
//==============================================================================
// AXI4 Interface FIFO Register
//==============================================================================
    reg  r_axis_tready ;
    always @(posedge s_axis_aclk) begin
        if((s_axis_areset) || (c_core_o_data_read_valid)) begin
            r_axis_tready <= 1'b1;
        end else if((r_in_cnt_max) && (r_axis_tvalid)) begin
            r_axis_tready <= 1'b0;
        end
    end
    
    assign s_axis_tready = r_axis_tready;
    
    reg  r_m_axis_tvalid ;
    reg  [C_AXIS_M_DATA_WIDTH-1:0] r_m_axis_tdata  ;
    always @(posedge s_axis_aclk) begin
        if(s_axis_areset) begin
            r_m_axis_tvalid <= 'b0;
            r_m_axis_tdata  <= 'b0;
        end else if(c_core_o_ot_valid) begin
            r_m_axis_tvalid <= 1'b1;
            r_m_axis_tdata  <= {{(C_AXIS_S_DATA_WIDTH - OTFMAP_O_IDX_BW - DATA_IDX_BW){1'b0}}, 
                c_core_o_ot_data_idx, c_core_o_ot_data_result};
        end else if(m_axis_tready) begin
            r_m_axis_tvalid <= 'b0;
            r_m_axis_tdata  <= 'b0;
        end
    end
    
    assign m_axis_tvalid = r_m_axis_tvalid ;
    assign m_axis_tdata  = r_m_axis_tdata  ;

//==============================================================================
// Control Core Input Port
//==============================================================================
    reg  [DATA_IDX_BW-1 : 0]     r_in_data_idx      ;
    
    always @(posedge s_axis_aclk) begin
        if(s_axis_areset) begin
            r_in_data_idx <= 'b0;
        end else if(c_core_o_data_read_valid) begin
            r_in_data_idx <= r_in_data_idx + 1;
        end
    end
    
    assign c_core_i_in_data_valid = ~r_axis_tready  ;
    assign c_core_i_in_data_idx   = r_in_data_idx    ;
    
//==============================================================================
// Call DUT
//==============================================================================
    LeNet5 #(
        .MULT_DELAY   (MULT_DELAY  ) ,
        .ACC_DELAY_C  (ACC_DELAY_C   ) ,
        .ACC_DELAY_FC (ACC_DELAY_FC   ) ,
        .AB_DELAY     (AB_DELAY    ) ,
        .I_F_BW       (I_F_BW      ) ,
        .W_BW         (W_BW        ) ,
        .B_BW         (B_BW        ) ,
        .DATA_IDX_BW  (DATA_IDX_BW ) 
    ) u_LeNet5 (
        .clk                    (clk                    ) ,
        .areset                 (areset                 ) ,
        .i_in_data_valid        (c_core_i_in_data_valid     ) ,
        .i_in_data_idx          (c_core_i_in_data_idx       ) ,
        .o_idle                 (c_core_o_idle              ) ,
        .o_run                  (c_core_o_run               ) ,
        .o_data_read_valid      (c_core_o_data_read_valid   ) ,
        .o_ot_valid             (c_core_o_ot_valid          ) ,
        .o_ot_data_idx          (c_core_o_ot_data_idx       ) ,
        .o_ot_data_result       (c_core_o_ot_data_result    ) ,
        .b_in_o_infmap_addr     (b_in_o_infmap_addr_0     ) ,
        .b_in_o_infmap_ce       (b_in_o_infmap_ce_0       ) ,
        .b_in_o_infmap_we       (b_in_o_infmap_we_0       ) ,
        .b_in_i_infmap_q        (b_in_i_infmap_q_0        ) ,
        .b_c1_o_infmap_addr     (b_c1_o_infmap_addr_0     ) ,
        .b_c1_o_infmap_ce       (b_c1_o_infmap_ce_0       ) ,
        .b_c1_o_infmap_we       (b_c1_o_infmap_we_0       ) ,
        .b_c1_o_infmap_d        (b_c1_o_infmap_d_0        ) ,
        .b_c1_i_infmap_q        (b_c1_i_infmap_q_0        ) ,
        .b_c1_o_weight_addr     (b_c1_o_weight_addr_0     ) ,
        .b_c1_o_weight_ce       (b_c1_o_weight_ce_0       ) ,
        .b_c1_o_weight_we       (b_c1_o_weight_we_0       ) ,
        .b_c1_i_weight_q        (b_c1_i_weight_q_0        ) ,
        .b_c1_o_bias_addr       (b_c1_o_bias_addr_0       ) ,
        .b_c1_o_bias_ce         (b_c1_o_bias_ce_0         ) ,
        .b_c1_o_bias_we         (b_c1_o_bias_we_0         ) ,
        .b_c1_i_bias_q          (b_c1_i_bias_q_0          ) ,
        .b_p1_o_pool_addr       (b_p1_o_pool_addr_0       ) ,
        .b_p1_o_pool_ce         (b_p1_o_pool_ce_0         ) ,
        .b_p1_o_pool_byte_we    (b_p1_o_pool_byte_we_0    ) ,
        .b_p1_o_pool_d          (b_p1_o_pool_d_0          ) ,
        .b_p1_i_pool_q          (b_p1_i_pool_q_0          ) ,
        .b_c2_o_infmap_addr     (b_c2_o_infmap_addr_0     ) ,
        .b_c2_o_infmap_ce       (b_c2_o_infmap_ce_0       ) ,
        .b_c2_o_infmap_we       (b_c2_o_infmap_we_0       ) ,
        .b_c2_o_infmap_d        (b_c2_o_infmap_d_0        ) ,
        .b_c2_i_infmap_q        (b_c2_i_infmap_q_0        ) ,
        .b_c2_o_weight_addr     (b_c2_o_weight_addr_0     ) ,
        .b_c2_o_weight_ce       (b_c2_o_weight_ce_0       ) ,
        .b_c2_o_weight_we       (b_c2_o_weight_we_0       ) ,
        .b_c2_i_weight_q        (b_c2_i_weight_q_0        ) ,
        .b_c2_o_bias_addr       (b_c2_o_bias_addr_0       ) ,
        .b_c2_o_bias_ce         (b_c2_o_bias_ce_0         ) ,
        .b_c2_o_bias_we         (b_c2_o_bias_we_0         ) ,
        .b_c2_i_bias_q          (b_c2_i_bias_q_0          ) ,
        .b_p2_o_pool_addr       (b_p2_o_pool_addr_0       ) ,
        .b_p2_o_pool_ce         (b_p2_o_pool_ce_0         ) ,
        .b_p2_o_pool_byte_we    (b_p2_o_pool_byte_we_0    ) ,
        .b_p2_o_pool_d          (b_p2_o_pool_d_0          ) ,
        .b_p2_i_pool_q          (b_p2_i_pool_q_0          ) ,
        .b_fc1_o_infmap_addr    (b_fc1_o_infmap_addr_0    ) ,
        .b_fc1_o_infmap_ce      (b_fc1_o_infmap_ce_0      ) ,
        .b_fc1_o_infmap_we      (b_fc1_o_infmap_we_0      ) ,
        .b_fc1_o_infmap_d       (b_fc1_o_infmap_d_0       ) ,
        .b_fc1_i_infmap_q       (b_fc1_i_infmap_q_0       ) ,
        .b_fc1_o_weight_addr    (b_fc1_o_weight_addr_0    ) ,
        .b_fc1_o_weight_ce      (b_fc1_o_weight_ce_0      ) ,
        .b_fc1_o_weight_we      (b_fc1_o_weight_we_0      ) ,
        .b_fc1_i_weight_q       (b_fc1_i_weight_q_0       ) ,
        .b_fc1_o_bias_addr      (b_fc1_o_bias_addr_0      ) ,
        .b_fc1_o_bias_ce        (b_fc1_o_bias_ce_0        ) ,
        .b_fc1_o_bias_we        (b_fc1_o_bias_we_0        ) ,
        .b_fc1_i_bias_q         (b_fc1_i_bias_q_0         ) ,
        .b_fc1_o_scaled_addr    (b_fc1_o_scaled_addr_0    ) ,
        .b_fc1_o_scaled_ce      (b_fc1_o_scaled_ce_0      ) ,
        .b_fc1_o_scaled_byte_we (b_fc1_o_scaled_byte_we_0 ) ,
        .b_fc1_o_scaled_d       (b_fc1_o_scaled_d_0       ) ,
        .b_fc1_i_scaled_q       (b_fc1_i_scaled_q_0       ) ,
        .b_fc2_o_infmap_addr    (b_fc2_o_infmap_addr_0    ) ,
        .b_fc2_o_infmap_ce      (b_fc2_o_infmap_ce_0      ) ,
        .b_fc2_o_infmap_we      (b_fc2_o_infmap_we_0      ) ,
        .b_fc2_o_infmap_d       (b_fc2_o_infmap_d_0       ) ,
        .b_fc2_i_infmap_q       (b_fc2_i_infmap_q_0       ) ,
        .b_fc2_o_weight_addr    (b_fc2_o_weight_addr_0    ) ,
        .b_fc2_o_weight_ce      (b_fc2_o_weight_ce_0      ) ,
        .b_fc2_o_weight_we      (b_fc2_o_weight_we_0      ) ,
        .b_fc2_i_weight_q       (b_fc2_i_weight_q_0       ) ,
        .b_fc2_o_bias_addr      (b_fc2_o_bias_addr_0      ) ,
        .b_fc2_o_bias_ce        (b_fc2_o_bias_ce_0        ) ,
        .b_fc2_o_bias_we        (b_fc2_o_bias_we_0        ) ,
        .b_fc2_i_bias_q         (b_fc2_i_bias_q_0         ) ,
        .b_fc2_o_scaled_addr    (b_fc2_o_scaled_addr_0    ) ,
        .b_fc2_o_scaled_ce      (b_fc2_o_scaled_ce_0      ) ,
        .b_fc2_o_scaled_byte_we (b_fc2_o_scaled_byte_we_0 ) ,
        .b_fc2_o_scaled_d       (b_fc2_o_scaled_d_0       ) ,
        .b_fc2_i_scaled_q       (b_fc2_i_scaled_q_0       ) ,
        .b_fc3_o_infmap_addr    (b_fc3_o_infmap_addr_0    ) ,
        .b_fc3_o_infmap_ce      (b_fc3_o_infmap_ce_0      ) ,
        .b_fc3_o_infmap_we      (b_fc3_o_infmap_we_0      ) ,
        .b_fc3_o_infmap_d       (b_fc3_o_infmap_d_0       ) ,
        .b_fc3_i_infmap_q       (b_fc3_i_infmap_q_0       ) ,
        .b_fc3_o_weight_addr    (b_fc3_o_weight_addr_0    ) ,
        .b_fc3_o_weight_ce      (b_fc3_o_weight_ce_0      ) ,
        .b_fc3_o_weight_we      (b_fc3_o_weight_we_0      ) ,
        .b_fc3_i_weight_q       (b_fc3_i_weight_q_0       ) ,
        .b_fc3_o_bias_addr      (b_fc3_o_bias_addr_0      ) ,
        .b_fc3_o_bias_ce        (b_fc3_o_bias_ce_0        ) ,
        .b_fc3_o_bias_we        (b_fc3_o_bias_we_0        ) ,
        .b_fc3_i_bias_q         (b_fc3_i_bias_q_0         ) 
    );
    
    // Infmap
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_C1_I_ADDR_W), 
        .MEM_WIDTH  (B_C1_I_DATA_W), 
        .MEM_DEPTH  (B_C1_I_DATA_D)
    ) u_TDPBRAM_in_infmap (
        .clk   (clk), 
        .addr0 (b_in_o_infmap_addr_0 ), .addr1 (b_in_o_infmap_addr_1 ), 
        .ce0   (b_in_o_infmap_ce_0   ), .ce1   (b_in_o_infmap_ce_1   ), 
        .we0   (b_in_o_infmap_we_0   ), .we1   (b_in_o_infmap_we_1   ),
        .d0    (b_in_o_infmap_d_0    ), .d1    (b_in_o_infmap_d_1    ),
        .q0    (b_in_i_infmap_q_0    ), .q1    (    ) 
    );
    
    // C1 layer
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_C1_I_ADDR_W), 
        .MEM_WIDTH  (B_C1_I_DATA_W), 
        .MEM_DEPTH  (B_C1_I_DATA_D)
    ) u_TDPBRAM_c1_infmap (
        .clk   (clk), 
        .addr0 (b_c1_o_infmap_addr_0 ), .addr1 (b_c1_o_infmap_addr_1 ), 
        .ce0   (b_c1_o_infmap_ce_0   ), .ce1   (b_c1_o_infmap_ce_1   ), 
        .we0   (b_c1_o_infmap_we_0   ), .we1   (b_c1_o_infmap_we_1   ),
        .d0    (b_c1_o_infmap_d_0    ), .d1    (b_c1_o_infmap_d_1    ),
        .q0    (b_c1_i_infmap_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_C1_W_ADDR_W), 
        .MEM_WIDTH  (B_C1_W_DATA_W), 
        .MEM_DEPTH  (B_C1_W_DATA_D)
    ) u_TDPBRAM_c1_weight (
        .clk   (clk), 
        .addr0 (b_c1_o_weight_addr_0 ), .addr1 (b_c1_o_weight_addr_1 ), 
        .ce0   (b_c1_o_weight_ce_0   ), .ce1   (b_c1_o_weight_ce_1   ), 
        .we0   (b_c1_o_weight_we_0   ), .we1   (b_c1_o_weight_we_1   ),
        .d0    (b_c1_o_weight_d_0    ), .d1    (b_c1_o_weight_d_1    ),
        .q0    (b_c1_i_weight_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_C1_B_ADDR_W), 
        .MEM_WIDTH  (B_C1_B_DATA_W), 
        .MEM_DEPTH  (B_C1_B_DATA_D)
    ) u_TDPBRAM_c1_bias (
        .clk   (clk), 
        .addr0 (b_c1_o_bias_addr_0 ), .addr1 (b_c1_o_bias_addr_1 ), 
        .ce0   (b_c1_o_bias_ce_0   ), .ce1   (b_c1_o_bias_ce_1   ), 
        .we0   (b_c1_o_bias_we_0   ), .we1   (b_c1_o_bias_we_1   ),
        .d0    (b_c1_o_bias_d_0    ), .d1    (b_c1_o_bias_d_1    ),
        .q0    (b_c1_i_bias_q_0    ), .q1    (    ) 
    );
    
    dp_bram_byte_we #(    
        .ADDR_WIDTH (B_C1_P_ADDR_W), 
        .MEM_WIDTH  (B_C1_P_DATA_W), 
        .MEM_DEPTH  (B_C1_P_DATA_D)
    ) u_TDPBRAM_c1_pool (
        .clk   (clk), 
        .addr0 (b_p1_o_pool_addr_0    ), .addr1 (b_p1_o_pool_addr_1    ), 
        .ce0   (b_p1_o_pool_ce_0      ), .ce1   (b_p1_o_pool_ce_1      ), 
        .we0   (b_p1_o_pool_byte_we_0 ), .we1   (b_p1_o_pool_byte_we_1 ),
        .d0    (b_p1_o_pool_d_0       ), .d1    (b_p1_o_pool_d_1       ),
        .q0    (b_p1_i_pool_q_0       ), .q1    (       ) 
    );
    
    // C2 layer
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_C2_I_ADDR_W), 
        .MEM_WIDTH  (B_C2_I_DATA_W), 
        .MEM_DEPTH  (B_C2_I_DATA_D)
    ) u_TDPBRAM_c2_infmap (
        .clk   (clk), 
        .addr0 (b_c2_o_infmap_addr_0 ), .addr1 (b_c2_o_infmap_addr_1 ), 
        .ce0   (b_c2_o_infmap_ce_0   ), .ce1   (b_c2_o_infmap_ce_1   ), 
        .we0   (b_c2_o_infmap_we_0   ), .we1   (b_c2_o_infmap_we_1   ),
        .d0    (b_c2_o_infmap_d_0    ), .d1    (b_c2_o_infmap_d_1    ),
        .q0    (b_c2_i_infmap_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_C2_W_ADDR_W), 
        .MEM_WIDTH  (B_C2_W_DATA_W), 
        .MEM_DEPTH  (B_C2_W_DATA_D)
    ) u_TDPBRAM_c2_weight (
        .clk   (clk), 
        .addr0 (b_c2_o_weight_addr_0 ), .addr1 (b_c2_o_weight_addr_1 ), 
        .ce0   (b_c2_o_weight_ce_0   ), .ce1   (b_c2_o_weight_ce_1   ), 
        .we0   (b_c2_o_weight_we_0   ), .we1   (b_c2_o_weight_we_1   ),
        .d0    (b_c2_o_weight_d_0    ), .d1    (b_c2_o_weight_d_1    ),
        .q0    (b_c2_i_weight_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_C2_B_ADDR_W), 
        .MEM_WIDTH  (B_C2_B_DATA_W), 
        .MEM_DEPTH  (B_C2_B_DATA_D)
    ) u_TDPBRAM_c2_bias (
        .clk   (clk), 
        .addr0 (b_c2_o_bias_addr_0 ), .addr1 (b_c2_o_bias_addr_1 ), 
        .ce0   (b_c2_o_bias_ce_0   ), .ce1   (b_c2_o_bias_ce_1   ), 
        .we0   (b_c2_o_bias_we_0   ), .we1   (b_c2_o_bias_we_1   ),
        .d0    (b_c2_o_bias_d_0    ), .d1    (b_c2_o_bias_d_1    ),
        .q0    (b_c2_i_bias_q_0    ), .q1    (    ) 
    );
    
    dp_bram_byte_we #(    
        .ADDR_WIDTH (B_C2_P_ADDR_W), 
        .MEM_WIDTH  (B_C2_P_DATA_W), 
        .MEM_DEPTH  (B_C2_P_DATA_D)
    ) u_TDPBRAM_c2_pool (
        .clk   (clk), 
        .addr0 (b_p2_o_pool_addr_0    ), .addr1 (b_p2_o_pool_addr_1    ), 
        .ce0   (b_p2_o_pool_ce_0      ), .ce1   (b_p2_o_pool_ce_1      ), 
        .we0   (b_p2_o_pool_byte_we_0 ), .we1   (b_p2_o_pool_byte_we_1 ),
        .d0    (b_p2_o_pool_d_0       ), .d1    (b_p2_o_pool_d_1       ),
        .q0    (b_p2_i_pool_q_0       ), .q1    (       ) 
    );
    
    // FC1 layer
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_FC1_I_ADDR_W), 
        .MEM_WIDTH  (B_FC1_I_DATA_W), 
        .MEM_DEPTH  (B_FC1_I_DATA_D)
    ) u_TDPBRAM_fc1_infmap (
        .clk   (clk), 
        .addr0 (b_fc1_o_infmap_addr_0 ), .addr1 (b_fc1_o_infmap_addr_1 ), 
        .ce0   (b_fc1_o_infmap_ce_0   ), .ce1   (b_fc1_o_infmap_ce_1   ), 
        .we0   (b_fc1_o_infmap_we_0   ), .we1   (b_fc1_o_infmap_we_1   ),
        .d0    (b_fc1_o_infmap_d_0    ), .d1    (b_fc1_o_infmap_d_1    ),
        .q0    (b_fc1_i_infmap_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC1_W_ADDR_W), 
        .MEM_WIDTH  (B_FC1_W_DATA_W), 
        .MEM_DEPTH  (B_FC1_W_DATA_D)
    ) u_TDPBRAM_fc1_weight (
        .clk   (clk), 
        .addr0 (b_fc1_o_weight_addr_0 ), .addr1 (b_fc1_o_weight_addr_1 ), 
        .ce0   (b_fc1_o_weight_ce_0   ), .ce1   (b_fc1_o_weight_ce_1   ), 
        .we0   (b_fc1_o_weight_we_0   ), .we1   (b_fc1_o_weight_we_1   ),
        .d0    (b_fc1_o_weight_d_0    ), .d1    (b_fc1_o_weight_d_1    ),
        .q0    (b_fc1_i_weight_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC1_B_ADDR_W), 
        .MEM_WIDTH  (B_FC1_B_DATA_W), 
        .MEM_DEPTH  (B_FC1_B_DATA_D)
    ) u_TDPBRAM_fc1_bias (
        .clk   (clk), 
        .addr0 (b_fc1_o_bias_addr_0 ), .addr1 (b_fc1_o_bias_addr_1 ), 
        .ce0   (b_fc1_o_bias_ce_0   ), .ce1   (b_fc1_o_bias_ce_1   ), 
        .we0   (b_fc1_o_bias_we_0   ), .we1   (b_fc1_o_bias_we_1   ),
        .d0    (b_fc1_o_bias_d_0    ), .d1    (b_fc1_o_bias_d_1    ),
        .q0    (b_fc1_i_bias_q_0    ), .q1    (    ) 
    );
    
    dp_bram_byte_we #(    
        .ADDR_WIDTH (B_FC1_S_ADDR_W), 
        .MEM_WIDTH  (B_FC1_S_DATA_W), 
        .MEM_DEPTH  (B_FC1_S_DATA_D)
    ) u_TDPBRAM_fc1_scaled (
        .clk   (clk), 
        .addr0 (b_fc1_o_scaled_addr_0    ), .addr1 (b_fc1_o_scaled_addr_1    ), 
        .ce0   (b_fc1_o_scaled_ce_0      ), .ce1   (b_fc1_o_scaled_ce_1      ), 
        .we0   (b_fc1_o_scaled_byte_we_0 ), .we1   (b_fc1_o_scaled_byte_we_1 ),
        .d0    (b_fc1_o_scaled_d_0       ), .d1    (b_fc1_o_scaled_d_1       ),
        .q0    (b_fc1_i_scaled_q_0       ), .q1    (       ) 
    );
    
    // FC2 layer
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_FC2_I_ADDR_W), 
        .MEM_WIDTH  (B_FC2_I_DATA_W), 
        .MEM_DEPTH  (B_FC2_I_DATA_D)
    ) u_TDPBRAM_fc2_infmap (
        .clk   (clk), 
        .addr0 (b_fc2_o_infmap_addr_0 ), .addr1 (b_fc2_o_infmap_addr_1 ), 
        .ce0   (b_fc2_o_infmap_ce_0   ), .ce1   (b_fc2_o_infmap_ce_1   ), 
        .we0   (b_fc2_o_infmap_we_0   ), .we1   (b_fc2_o_infmap_we_1   ),
        .d0    (b_fc2_o_infmap_d_0    ), .d1    (b_fc2_o_infmap_d_1    ),
        .q0    (b_fc2_i_infmap_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC2_W_ADDR_W), 
        .MEM_WIDTH  (B_FC2_W_DATA_W), 
        .MEM_DEPTH  (B_FC2_W_DATA_D)
    ) u_TDPBRAM_fc2_weight (
        .clk   (clk), 
        .addr0 (b_fc2_o_weight_addr_0 ), .addr1 (b_fc2_o_weight_addr_1 ), 
        .ce0   (b_fc2_o_weight_ce_0   ), .ce1   (b_fc2_o_weight_ce_1   ), 
        .we0   (b_fc2_o_weight_we_0   ), .we1   (b_fc2_o_weight_we_1   ),
        .d0    (b_fc2_o_weight_d_0    ), .d1    (b_fc2_o_weight_d_1    ),
        .q0    (b_fc2_i_weight_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC2_B_ADDR_W), 
        .MEM_WIDTH  (B_FC2_B_DATA_W), 
        .MEM_DEPTH  (B_FC2_B_DATA_D)
    ) u_TDPBRAM_fc2_bias (
        .clk   (clk), 
        .addr0 (b_fc2_o_bias_addr_0 ), .addr1 (b_fc2_o_bias_addr_1 ), 
        .ce0   (b_fc2_o_bias_ce_0   ), .ce1   (b_fc2_o_bias_ce_1   ), 
        .we0   (b_fc2_o_bias_we_0   ), .we1   (b_fc2_o_bias_we_1   ),
        .d0    (b_fc2_o_bias_d_0    ), .d1    (b_fc2_o_bias_d_1    ),
        .q0    (b_fc2_i_bias_q_0    ), .q1    (    ) 
    );
    
    dp_bram_byte_we #(    
        .ADDR_WIDTH (B_FC2_S_ADDR_W), 
        .MEM_WIDTH  (B_FC2_S_DATA_W), 
        .MEM_DEPTH  (B_FC2_S_DATA_D)
    ) u_TDPBRAM_fc2_scaled (
        .clk   (clk), 
        .addr0 (b_fc2_o_scaled_addr_0    ), .addr1 (b_fc2_o_scaled_addr_1    ), 
        .ce0   (b_fc2_o_scaled_ce_0      ), .ce1   (b_fc2_o_scaled_ce_1      ), 
        .we0   (b_fc2_o_scaled_byte_we_0 ), .we1   (b_fc2_o_scaled_byte_we_1 ),
        .d0    (b_fc2_o_scaled_d_0       ), .d1    (b_fc2_o_scaled_d_1       ),
        .q0    (b_fc2_i_scaled_q_0       ), .q1    (       ) 
    );
    
    // FC3 layer
    //--------------------------------------------------------------------
    dp_bram #(    
        .ADDR_WIDTH (B_FC3_I_ADDR_W), 
        .MEM_WIDTH  (B_FC3_I_DATA_W), 
        .MEM_DEPTH  (B_FC3_I_DATA_D)
    ) u_TDPBRAM_fc3_infmap (
        .clk   (clk), 
        .addr0 (b_fc3_o_infmap_addr_0 ), .addr1 (b_fc3_o_infmap_addr_1 ), 
        .ce0   (b_fc3_o_infmap_ce_0   ), .ce1   (b_fc3_o_infmap_ce_1   ), 
        .we0   (b_fc3_o_infmap_we_0   ), .we1   (b_fc3_o_infmap_we_1   ),
        .d0    (b_fc3_o_infmap_d_0    ), .d1    (b_fc3_o_infmap_d_1    ),
        .q0    (b_fc3_i_infmap_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC3_W_ADDR_W), 
        .MEM_WIDTH  (B_FC3_W_DATA_W), 
        .MEM_DEPTH  (B_FC3_W_DATA_D)
    ) u_TDPBRAM_fc3_weight (
        .clk   (clk), 
        .addr0 (b_fc3_o_weight_addr_0 ), .addr1 (b_fc3_o_weight_addr_1 ), 
        .ce0   (b_fc3_o_weight_ce_0   ), .ce1   (b_fc3_o_weight_ce_1   ), 
        .we0   (b_fc3_o_weight_we_0   ), .we1   (b_fc3_o_weight_we_1   ),
        .d0    (b_fc3_o_weight_d_0    ), .d1    (b_fc3_o_weight_d_1    ),
        .q0    (b_fc3_i_weight_q_0    ), .q1    (    ) 
    );
    
    dp_bram #(    
        .ADDR_WIDTH (B_FC3_B_ADDR_W), 
        .MEM_WIDTH  (B_FC3_B_DATA_W), 
        .MEM_DEPTH  (B_FC3_B_DATA_D)
    ) u_TDPBRAM_fc3_bias (
        .clk   (clk), 
        .addr0 (b_fc3_o_bias_addr_0 ), .addr1 (b_fc3_o_bias_addr_1 ), 
        .ce0   (b_fc3_o_bias_ce_0   ), .ce1   (b_fc3_o_bias_ce_1   ), 
        .we0   (b_fc3_o_bias_we_0   ), .we1   (b_fc3_o_bias_we_1   ),
        .d0    (b_fc3_o_bias_d_0    ), .d1    (b_fc3_o_bias_d_1    ),
        .q0    (b_fc3_i_bias_q_0    ), .q1    (    ) 
    );

endmodule

`default_nettype wire
