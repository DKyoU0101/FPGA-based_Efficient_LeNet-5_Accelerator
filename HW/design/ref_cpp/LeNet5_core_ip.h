//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
// 
// Create Date: 2025.03.28
// Associated Filename: LeNet5_core_ip.h
// Project Name: CNN_FPGA
// Tool Versions: 
// Purpose: To run simulation
// Revision: 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


#ifndef LeNet5_core_ip_h
#define LeNet5_core_ip_h

#include <iostream>
#include <vector>
#include <random>
#include <algorithm>
#include <fstream>
#include <string>
#include <sstream>
#include <iomanip>
#include <bitset>
#include <cstdint>

using namespace std;

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

// read file
#define FP_IN_INFMAP "../design/ref_cpp/mnist_dataset/input_y_q_padd.txt"
#define FP_IN_INFMAP_BIN "../design/ref_cpp/mnist_dataset/MNIST/raw/t10k-images-idx3-ubyte"
#define FP_IN_LABEL_BIN  "../design/ref_cpp/mnist_dataset/MNIST/raw/t10k-labels-idx1-ubyte"

#define FP_IN_CONV1_WEIGHT "../design/ref_cpp/mnist_dataset/conv1_weight_quantized.txt"
#define FP_IN_CONV1_BIAS   "../design/ref_cpp/mnist_dataset/conv1_bias_quantized.txt"

#define FP_IN_CONV2_WEIGHT "../design/ref_cpp/mnist_dataset/conv2_weight_quantized.txt"
#define FP_IN_CONV2_BIAS   "../design/ref_cpp/mnist_dataset/conv2_bias_quantized.txt"

#define FP_IN_FC1_WEIGHT "../design/ref_cpp/mnist_dataset/fc1_weight_quantized.txt"
#define FP_IN_FC1_BIAS   "../design/ref_cpp/mnist_dataset/fc1_bias_quantized.txt"

#define FP_IN_FC2_WEIGHT "../design/ref_cpp/mnist_dataset/fc2_weight_quantized.txt"
#define FP_IN_FC2_BIAS   "../design/ref_cpp/mnist_dataset/fc2_bias_quantized.txt"

#define FP_IN_FC3_WEIGHT "../design/ref_cpp/mnist_dataset/fc3_weight_quantized.txt"
#define FP_IN_FC3_BIAS   "../design/ref_cpp/mnist_dataset/fc3_bias_quantized.txt"

#define FP_IN_OTFMAP "../design/ref_cpp/mnist_dataset/fc3_output.txt"

// write file
#define FP_OT_INFMAP "../design/ref_cpp/trace/in_infmap.txt"

#define FP_OT_CONV1_WEIGHT "../design/ref_cpp/trace/in_conv1_weight.txt"
#define FP_OT_CONV1_BIAS   "../design/ref_cpp/trace/in_conv1_bias.txt"

#define FP_OT_CONV2_WEIGHT "../design/ref_cpp/trace/in_conv2_weight.txt"
#define FP_OT_CONV2_BIAS   "../design/ref_cpp/trace/in_conv2_bias.txt"

#define FP_OT_FC1_WEIGHT "../design/ref_cpp/trace/in_fc1_weight.txt"
#define FP_OT_FC1_BIAS   "../design/ref_cpp/trace/in_fc1_bias.txt"

#define FP_OT_FC2_WEIGHT "../design/ref_cpp/trace/in_fc2_weight.txt"
#define FP_OT_FC2_BIAS   "../design/ref_cpp/trace/in_fc2_bias.txt"

#define FP_OT_FC3_WEIGHT "../design/ref_cpp/trace/in_fc3_weight.txt"
#define FP_OT_FC3_BIAS   "../design/ref_cpp/trace/in_fc3_bias.txt"

#define FP_OT_OTFMAP "../design/ref_cpp/trace/ot_otfmap.txt"


#define INT_LENTH 32
// #define INBIT_LENTH 68
// #define OTBIT_LENTH 69
// #define MEM_WIDTH 32 
// #define MEM_DEPTH 1 
// #define DATA_MEMNUM 	(INBIT_LENTH / MEM_WIDTH)

#define TRUE  1;
#define FALSE 0;

//========================================================================
// Submodules
//========================================================================
// file read
void read_mnist_labels(
    std::ifstream& fp_in_label, 
    int& label, 
    const int image_index
);
void read_mnist_images(
    std::ifstream& fp_in_infmap, 
    vector<vector<vector<int>>>& infmap, 
    vector<vector<vector<int8_t>>>& infmap_qnt,
    const int image_index
);
void rd_conv_infmap (
    std::ifstream& fp_in_infmap,
    vector<vector<vector<int>>>&    infmap,
    vector<vector<vector<int8_t>>>& infmap_qnt,
    const int ICH_ ,
    const int IY_  ,
    const int IX_
);
void rd_conv_weight (
    std::ifstream& fp_in_weight,
    vector<vector<vector<vector<int>>>>&    weight,
    vector<vector<vector<vector<int8_t>>>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ ,
    const int KY_  ,
    const int KX_  
);
void rd_conv_otfmap (
    std::ifstream& fp_in_otfmap,
    vector<vector<vector<int>>>&    otfmap,
    vector<vector<vector<int8_t>>>& otfmap_qnt,
    const int OCH_ ,
    const int OY_  ,
    const int OX_
);
void rd_fc_infmap (
    std::ifstream& fp_in_infmap,
    vector<int>&    infmap,
    vector<int8_t>& infmap_qnt,
    const int ICH_
);
void rd_fc_weight (
    std::ifstream& fp_in_weight,
    vector<vector<int>>&    weight,
    vector<vector<int8_t>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ 
);
void rd_fc_otfmap (
    std::ifstream& fp_in_otfmap,
    vector<int>&    otfmap,
    vector<int8_t>& otfmap_qnt,
    const int OCH_
);
void rd_bias (
    std::ifstream& fp_in_bias,
    vector<int>&    bias,
    vector<int16_t>& bias_qnt,
    const int OCH_
);

// layers
void conv_layer(
    const vector<vector<vector<int>>>& infmap,
    const vector<vector<vector<vector<int>>>>& weight,
    const vector<int>& bias,
    vector<vector<vector<int>>>& otfmap,
    const int OCH_ ,
    const int OY_  , 
    const int OX_  , 
    const int ICH_ , 
    const int KY_  , 
    const int KX_  ,
    const int M_INV   ,
    const int B_SCALE 
);
void max_pooling(
    const vector<vector<vector<int>>>& infmap,
    vector<vector<vector<int>>>& pooling,
    const int OCH_ ,
    const int OY_  , 
    const int OX_  ,
    const int KY_  , 
    const int KX_  
);
void flatten (
    const vector<vector<vector<int>>>& infmap,
    vector<int>& otfmap,
    const int ICH_ ,
    const int IY_  , 
    const int IX_  
);
void fc_layer (
    const vector<int>& infmap,
    const vector<vector<int>>& weight,
    const vector<int>& bias,
    vector<int>& otfmap,
    const int OCH_ ,
    const int ICH_ ,
    const int M_INV   ,
    const int B_SCALE ,
    const bool relu
);

// file write
void wr_conv_infmap (
    const int loop,
    std::ofstream& fp_ot_infmap,
    const vector<vector<vector<int8_t>>>& infmap_qnt,
    const int ICH_ ,
    const int IY_  ,
    const int IX_
);
void wr_conv_weight (
    const int loop,
    std::ofstream& fp_ot_weight,
    const vector<vector<vector<vector<int8_t>>>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ ,
    const int KY_  ,
    const int KX_  
);
void wr_conv_otfmap (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<vector<vector<int8_t>>>& otfmap_qnt,
    const int OCH_ ,
    const int OY_  ,
    const int OX_
);
void wr_fc_infmap (
    const int loop,
    std::ofstream& fp_ot_infmap,
    const vector<int8_t>& infmap_qnt,
    const int ICH_ 
);
void wr_fc_weight (
    const int loop,
    std::ofstream& fp_ot_weight,
    const vector<vector<int8_t>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ 
);
void wr_fc_otfmap (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<int8_t>& otfmap_qnt,
    const int OCH_ 
);
void wr_bias (
    const int loop,
    std::ofstream& fp_ot_bias,
    const vector<int16_t>& bias_qnt,
    const int OCH_
);
void wr_result (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<int8_t>& otfmap_qnt,
    const int OCH_ 
);
#endif 