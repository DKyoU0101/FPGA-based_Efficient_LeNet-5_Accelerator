//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.17
// Design Name: 
// Module Name: dma_LeNet5_main.c
// Project Name: ECDSA_2024
// Target Devices: TE0729
// Tool Versions: Vitis_2022.2
// Description: 
// Dependencies: 
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

#ifndef DMA_LENET5_MAIN_H
#define DMA_LENET5_MAIN_H

#include <c++/11.2.0/random>
#include <c++/11.2.0/string>
#include <c++/11.2.0/fstream>
#include <c++/11.2.0/iostream>
#include <c++/11.2.0/vector>
#include "ff.h"
#include "xil_printf.h"
#include "ffconf.h"
#include "xsdps.h"

using namespace std;

#define   MULT_DELAY    3
#define   ACC_DELAY_C   1
#define   ACC_DELAY_FC  0
#define   AB_DELAY      1

// #define bit width
#define   I_F_BW      8    // Bit Width of Input Feature
#define   W_BW        8    // BW of weight #define
#define   B_BW        16   // BW of bias #define

#define   M_BW     I_F_BW + W_BW // 16 I_F_BW + W_BW

#define   DATA_IDX_BW   20

struct conv_param {
    int OCH ;
    int OY  ;
    int OX  ;
    int ICH ;
    int IY  ;
    int IX  ;
    int KY  ;
    int KX  ;
};
struct pool_param {
    int OCH ;
    int OY  ;
    int OX  ;
    int KY  ;
    int KX  ;
};
struct fc_param {
    int OCH ;
    int ICH ;
};
struct layer_scale {
    int IN_I_INV ;
    int IN_W_INV ;
    int IN_B_INV ;
    int IN_O_INV ;
};

#define INFMAP_QNT_BW 8
#define WEIGHT_QNT_BW 8
#define BIAS_QNT_BW   16
#define OTFMAP_QNT_BW 8

//==============================================================================
// Layers #define
//==============================================================================
    // #define size in CNN
#define CONV_KY 5
#define CONV_KX 5

#define POOL_KY 2
#define POOL_KX 2

#define CONV1_OCH 6
#define CONV2_OCH 16
#define CONV1_OY  28
#define CONV2_OY  10
#define CONV1_OX  28
#define CONV2_OX  10
#define CONV1_ICH 1
#define CONV2_ICH 6
#define CONV1_IY  32
#define CONV2_IY  14
#define CONV1_IX  32
#define CONV2_IX  14
#define CONV1_B_SHIFT 0
#define CONV2_B_SHIFT 0
#define CONV1_M_INV   512
#define CONV2_M_INV   512

#define CONV1_O_F_BW  21
#define CONV2_O_F_BW  24
#define POOL1_OCH 6
#define POOL2_OCH 16
#define POOL1_ICH 6
#define POOL2_ICH 16
#define POOL1_IY 28
#define POOL2_IY 10
#define POOL1_IX 28
#define POOL2_IX 10

#define FC1_OCH 120
#define FC2_OCH 84
#define FC3_OCH 10
#define FC1_ICH 400
#define FC2_ICH 120
#define FC3_ICH 84
#define FC1_B_SCALE 1
#define FC2_B_SCALE 1
#define FC3_B_SCALE 1
#define FC1_M_INV   256
#define FC2_M_INV   256
#define FC3_M_INV   256

    // #define size in CNN Block
#define CONV1_OCH_B 2
#define CONV2_OCH_B 4
#define CONV1_OX_B  4
#define CONV2_OX_B  2
#define CONV1_ICH_B 1
#define CONV2_ICH_B 2
#define CONV1_B_BW 2
#define  CONV2_B_BW 2
#define CONV1_T_BW 4
#define  CONV2_T_BW 4

#define POOL1_OCH_B 2
#define POOL2_OCH_B 4
#define POOL1_ICH_B 2
#define POOL2_ICH_B 4
#define POOL1_IX_B  4
#define POOL2_IX_B  2
#define POOL1_B_BW  2
#define POOL2_B_BW  2
#define POOL1_T_BW  3
#define POOL2_T_BW  3
    
#define FC1_OCH_B 8
#define FC2_OCH_B 4
#define FC3_OCH_B 2
#define FC1_ICH_B 80
#define FC2_ICH_B 24
#define FC3_ICH_B 14
#define FC1_B_BW 7
#define FC2_B_BW 5
#define FC3_B_BW 4
#define FC1_T_BW 4
#define FC2_T_BW 6
#define FC3_T_BW 3
#define FC1_RELU 1
#define FC2_RELU 1
#define FC3_RELU 0
#define FC1_IS_FINAL_LAYER 0
#define FC2_IS_FINAL_LAYER 0
#define FC3_IS_FINAL_LAYER 1
    
#define CONV1_OCH_T (CONV1_OCH / CONV1_OCH_B)
#define CONV2_OCH_T (CONV2_OCH / CONV2_OCH_B)
#define CONV1_OX_T  (CONV1_OX  / CONV1_OX_B )
#define CONV2_OX_T  (CONV2_OX  / CONV2_OX_B )
    
#define POOL1_ICH_T (POOL1_ICH / POOL1_ICH_B)
#define POOL2_ICH_T (POOL2_ICH / POOL2_ICH_B)
#define POOL1_IX_T  (POOL1_IX  / POOL1_IX_B )
#define POOL2_IX_T  (POOL2_IX  / POOL2_IX_B )
    
#define FC1_OCH_T (FC1_OCH / FC1_OCH_B)
#define FC2_OCH_T (FC2_OCH / FC2_OCH_B)
#define FC3_OCH_T (FC3_OCH / FC3_OCH_B)
#define FC1_ICH_T (FC1_ICH / FC1_ICH_B)
#define FC2_ICH_T (FC2_ICH / FC2_ICH_B)
#define FC3_ICH_T (FC3_ICH / FC3_ICH_B)

//==============================================================================
// BRAM Port Bandwidth
//==============================================================================
#define B_COL_NUM     32 / I_F_BW   // 4
#define B_COL_BW      static_cast<int>(ceil(log2(B_COL_NUM)))
    
#define B_C1_I_DATA_W  32
#define B_C1_I_DATA_D  (CONV1_ICH * CONV1_IY * CONV1_IX) / B_COL_NUM // 1024
#define B_C1_I_ADDR_W  static_cast<int>(ceil(log2(B_C1_I_DATA_D))) // 10
#define B_C1_W_DATA_W  CONV_KX * W_BW // 40
#define B_C1_W_DATA_D  CONV1_OCH * CONV1_ICH * CONV_KY  // 30
#define B_C1_W_ADDR_W  static_cast<int>(ceil(log2(B_C1_W_DATA_D))) // 5
#define B_C1_B_DATA_W  B_BW  // 16
#define B_C1_B_DATA_D  CONV1_OCH   // 6
#define B_C1_B_ADDR_W  static_cast<int>(ceil(log2(B_C1_B_DATA_D))) // 3
#define B_C1_P_DATA_W  32
#define B_C1_P_DATA_D  (POOL1_ICH * (POOL1_IY/2) * (POOL1_IX/2)) / B_COL_NUM // 294 1176 / 4
#define B_C1_P_ADDR_W  static_cast<int>(ceil(log2(B_C1_P_DATA_D))) // 9
    
#define B_C2_I_DATA_W  32
#define B_C2_I_DATA_D  (CONV2_ICH * CONV2_IY * CONV2_IX) / B_COL_NUM // 1024
#define B_C2_I_ADDR_W  static_cast<int>(ceil(log2(B_C2_I_DATA_D))) // 10
#define B_C2_W_DATA_W  CONV_KX * W_BW // 40
#define B_C2_W_DATA_D  CONV2_OCH * CONV2_ICH * CONV_KY  // 30
#define B_C2_W_ADDR_W  static_cast<int>(ceil(log2(B_C2_W_DATA_D))) // 5
#define B_C2_B_DATA_W  B_BW  // 16
#define B_C2_B_DATA_D  CONV2_OCH   // 6
#define B_C2_B_ADDR_W  static_cast<int>(ceil(log2(B_C2_B_DATA_D))) // 3
#define B_C2_P_DATA_W  32
#define B_C2_P_DATA_D  (POOL2_ICH * (POOL2_IY/2) * (POOL2_IX/2)) / B_COL_NUM // 294 1176 / 4
#define B_C2_P_ADDR_W  static_cast<int>(ceil(log2(B_C2_P_DATA_D))) // 9
    
#define B_FC1_I_DATA_W  32
#define B_FC1_I_DATA_D  (static_cast<int>(ceil(static_cast<double>(FC1_ICH) / static_cast<double>(B_COL_NUM))))
#define B_FC1_I_ADDR_W  static_cast<int>(ceil(log2(B_FC1_I_DATA_D))) // 7
#define B_FC1_W_DATA_W  FC1_ICH_T * W_BW // 80
#define B_FC1_W_DATA_D  FC1_OCH * FC1_ICH_B  // 4800 120 * 40
#define B_FC1_W_ADDR_W  static_cast<int>(ceil(log2(B_FC1_W_DATA_D))) // 13
#define B_FC1_B_DATA_W  B_BW  // 16
#define B_FC1_B_DATA_D  FC1_OCH   // 120
#define B_FC1_B_ADDR_W  static_cast<int>(ceil(log2(B_FC1_B_DATA_D))) // 7
#define B_FC1_S_DATA_W  32
#define B_FC1_S_DATA_D  (static_cast<int>(ceil(static_cast<double>(FC1_OCH) / static_cast<double>(B_COL_NUM))))
#define B_FC1_S_ADDR_W  static_cast<int>(ceil(log2(B_FC1_S_DATA_D))) // 5
    
#define B_FC2_I_DATA_W  32
#define B_FC2_I_DATA_D  (static_cast<int>(ceil(static_cast<double>(FC2_ICH) / static_cast<double>(B_COL_NUM))))
#define B_FC2_I_ADDR_W  static_cast<int>(ceil(log2(B_FC2_I_DATA_D))) // 7
#define B_FC2_W_DATA_W  FC2_ICH_T * W_BW // 80
#define B_FC2_W_DATA_D  FC2_OCH * FC2_ICH_B  // 4800 120 * 40
#define B_FC2_W_ADDR_W  static_cast<int>(ceil(log2(B_FC2_W_DATA_D))) // 13
#define B_FC2_B_DATA_W  B_BW  // 16
#define B_FC2_B_DATA_D  FC2_OCH   // 120
#define B_FC2_B_ADDR_W  static_cast<int>(ceil(log2(B_FC2_B_DATA_D))) // 7
#define B_FC2_S_DATA_W  32
#define B_FC2_S_DATA_D  (static_cast<int>(ceil(static_cast<double>(FC2_OCH) / static_cast<double>(B_COL_NUM))))
#define B_FC2_S_ADDR_W  static_cast<int>(ceil(log2(B_FC2_S_DATA_D))) // 5
    
#define B_FC3_I_DATA_W  32
#define B_FC3_I_DATA_D  (static_cast<int>(ceil(static_cast<double>(FC3_ICH) / static_cast<double>(B_COL_NUM))))
#define B_FC3_I_ADDR_W  static_cast<int>(ceil(log2(B_FC3_I_DATA_D))) // 7
#define B_FC3_W_DATA_W  FC3_ICH_T * W_BW // 80
#define B_FC3_W_DATA_D  FC3_OCH * FC3_ICH_B  // 4800 120 * 40
#define B_FC3_W_ADDR_W  static_cast<int>(ceil(log2(B_FC3_W_DATA_D))) // 13
#define B_FC3_B_DATA_W  B_BW  // 16
#define B_FC3_B_DATA_D  FC3_OCH   // 120
#define B_FC3_B_ADDR_W  static_cast<int>(ceil(log2(B_FC3_B_DATA_D))) // 7
    
#define OTFMAP_O_IDX_BW  static_cast<int>(ceil(log2(FC3_OCH)))  // 4
    
#define NUM_RD_INFMAP  B_C1_I_DATA_D
#define NUM_RD_PARAM   B_C1_W_DATA_D + B_C1_B_DATA_D + B_C2_W_DATA_D + B_C2_B_DATA_D + B_FC1_W_DATA_D + B_FC1_B_DATA_D + B_FC2_W_DATA_D + B_FC2_B_DATA_D + B_FC3_W_DATA_D + B_FC3_B_DATA_D
    
// read file
#define FP_IN_INFMAP_BIN    "0:/LeNet5/images"
#define FP_IN_LABEL_BIN     "0:/LeNet5/labels"

#define FP_IN_CONV1_WEIGHT  "0:/LeNet5/c1_w.txt"
#define FP_IN_CONV1_BIAS    "0:/LeNet5/c1_b.txt"

#define FP_IN_CONV2_WEIGHT  "0:/LeNet5/c2_w.txt"
#define FP_IN_CONV2_BIAS    "0:/LeNet5/c2_b.txt"

#define FP_IN_FC1_WEIGHT    "0:/LeNet5/fc1_w.txt"
#define FP_IN_FC1_BIAS      "0:/LeNet5/fc1_b.txt"

#define FP_IN_FC2_WEIGHT    "0:/LeNet5/fc2_w.txt"
#define FP_IN_FC2_BIAS      "0:/LeNet5/fc2_b.txt"

#define FP_IN_FC3_WEIGHT    "0:/LeNet5/fc3_w.txt"
#define FP_IN_FC3_BIAS      "0:/LeNet5/fc3_b.txt"


#endif
