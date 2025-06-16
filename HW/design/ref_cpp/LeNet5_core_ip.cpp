//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
// 
// Create Date: 2025.03.22
// Associated Filename: LeNet5_core_ip.cpp
// Project Name: CNN_FPGA
// Tool Versions: 
// Purpose: To run simulation
// Revision: 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

#include "LeNet5_core_ip.h"

int main(int argc, char **argv) {
	if(argc != 3){
		printf("Usage : <executable> <srand_val> <srand_val>\n");
		return -1;
	}
	
    int RD_SEED  = atoi(argv[1]);
    int LOOP_NUM = atoi(argv[2]);
	
	mt19937 rd(RD_SEED);
    // brand::independent_bits_engine<mt19937, 512, INT_t> gen_512(atoi(argv[1]));
	
    //========================================================================
    // Layers Parameter
    //========================================================================
    conv_param conv1 = {6, 28, 28, 1, 32, 32, 5, 5};
    pool_param pool1 = {6, 14, 14, 2, 2};
    layer_scale conv1_scale = {32, 256, 8192, 16};
    int M_INV_conv1 = conv1_scale.IN_I_INV * conv1_scale.IN_W_INV / conv1_scale.IN_O_INV;
    int B_SCALE_conv1 = conv1_scale.IN_B_INV / (conv1_scale.IN_I_INV * conv1_scale.IN_W_INV);
    
    conv_param conv2 = {16, 10, 10, 6, 14, 14, 5, 5};
    pool_param pool2 = {16, 5, 5, 2, 2};
    layer_scale conv2_scale = {16, 128, 2048, 4};
    int M_INV_conv2 = conv2_scale.IN_I_INV * conv2_scale.IN_W_INV / conv2_scale.IN_O_INV;
    int B_SCALE_conv2 = conv2_scale.IN_B_INV / (conv2_scale.IN_I_INV * conv2_scale.IN_W_INV);
    
    fc_param fc1 = {120, 400};
    layer_scale fc1_scale = {4, 128, 512, 2};
    int M_INV_fc1 = fc1_scale.IN_I_INV * fc1_scale.IN_W_INV / fc1_scale.IN_O_INV;
    int B_SCALE_fc1 = fc1_scale.IN_B_INV / (fc1_scale.IN_I_INV * fc1_scale.IN_W_INV);
    
    fc_param fc2 = {84, 120};
    layer_scale fc2_scale = {2, 256, 512, 2};
    int M_INV_fc2 = fc2_scale.IN_I_INV * fc2_scale.IN_W_INV / fc2_scale.IN_O_INV;
    int B_SCALE_fc2 = fc2_scale.IN_B_INV / (fc2_scale.IN_I_INV * fc2_scale.IN_W_INV);
    
    fc_param fc3 = {10, 84};
    layer_scale fc3_scale = {2, 256, 512, 2};
    int M_INV_fc3 = fc3_scale.IN_I_INV * fc3_scale.IN_W_INV / fc3_scale.IN_O_INV;
    int B_SCALE_fc3 = fc3_scale.IN_B_INV / (fc3_scale.IN_I_INV * fc3_scale.IN_W_INV);
    
    //===========================================================================
    // Read/Write txt File
    //===========================================================================
	// std::ifstream fp_in_infmap (FP_IN_INFMAP );
	std::ifstream fp_in_infmap (FP_IN_INFMAP_BIN );
	std::ifstream fp_in_label (FP_IN_LABEL_BIN );
	std::ifstream fp_in_conv1_weight (FP_IN_CONV1_WEIGHT );
	std::ifstream fp_in_conv1_bias   (FP_IN_CONV1_BIAS   );
	std::ifstream fp_in_conv2_weight (FP_IN_CONV2_WEIGHT );
	std::ifstream fp_in_conv2_bias   (FP_IN_CONV2_BIAS   );
	std::ifstream fp_in_fc1_weight (FP_IN_FC1_WEIGHT );
	std::ifstream fp_in_fc1_bias   (FP_IN_FC1_BIAS   );
	std::ifstream fp_in_fc2_weight (FP_IN_FC2_WEIGHT );
	std::ifstream fp_in_fc2_bias   (FP_IN_FC2_BIAS   );
	std::ifstream fp_in_fc3_weight (FP_IN_FC3_WEIGHT );
	std::ifstream fp_in_fc3_bias   (FP_IN_FC3_BIAS   );
	std::ifstream fp_in_otfmap (FP_IN_OTFMAP );
    
    if (!fp_in_infmap.is_open()) {
        std::cerr << "Error opening FP_IN_INFMAP file" << std::endl; return 1;
    } else if (!fp_in_label.is_open()) {
        std::cerr << "Error opening FP_IN_label file" << std::endl; return 1;
    } else if (!fp_in_conv1_weight.is_open()) {
        std::cerr << "Error opening FP_IN_WEIGHT file" << std::endl; return 1;
    } else if (!fp_in_conv1_bias.is_open()) {
        std::cerr << "Error opening FP_IN_BIAS   file" << std::endl; return 1;
    } else if (!fp_in_conv2_weight.is_open()) {
        std::cerr << "Error opening FP_IN_WEIGHT file" << std::endl; return 1;
    } else if (!fp_in_conv2_bias.is_open()) {
        std::cerr << "Error opening FP_IN_BIAS   file" << std::endl; return 1;
    } else if (!fp_in_fc1_weight.is_open()) {
        std::cerr << "Error opening FP_IN_WEIGHT file" << std::endl; return 1;
    } else if (!fp_in_fc1_bias.is_open()) {
        std::cerr << "Error opening FP_IN_BIAS   file" << std::endl; return 1;
    } else if (!fp_in_fc2_weight.is_open()) {
        std::cerr << "Error opening FP_IN_WEIGHT file" << std::endl; return 1;
    } else if (!fp_in_fc2_bias.is_open()) {
        std::cerr << "Error opening FP_IN_BIAS   file" << std::endl; return 1;
    } else if (!fp_in_fc3_weight.is_open()) {
        std::cerr << "Error opening FP_IN_WEIGHT file" << std::endl; return 1;
    } else if (!fp_in_fc3_bias.is_open()) {
        std::cerr << "Error opening FP_IN_BIAS   file" << std::endl; return 1;
    } else if (!fp_in_otfmap.is_open()) {
        std::cerr << "Error opening FP_IN_OTFMAP file" << std::endl; return 1;
    }
    
	std::ofstream fp_ot_infmap (FP_OT_INFMAP );
	std::ofstream fp_ot_conv1_weight (FP_OT_CONV1_WEIGHT );
	std::ofstream fp_ot_conv1_bias   (FP_OT_CONV1_BIAS   );
	std::ofstream fp_ot_conv2_weight (FP_OT_CONV2_WEIGHT );
	std::ofstream fp_ot_conv2_bias   (FP_OT_CONV2_BIAS   );
	std::ofstream fp_ot_fc1_weight (FP_OT_FC1_WEIGHT );
	std::ofstream fp_ot_fc1_bias   (FP_OT_FC1_BIAS   );
	std::ofstream fp_ot_fc2_weight (FP_OT_FC2_WEIGHT );
	std::ofstream fp_ot_fc2_bias   (FP_OT_FC2_BIAS   );
	std::ofstream fp_ot_fc3_weight (FP_OT_FC3_WEIGHT );
	std::ofstream fp_ot_fc3_bias   (FP_OT_FC3_BIAS   );
	std::ofstream fp_ot_otfmap (FP_OT_OTFMAP );
    
    //========================================================================
    // Initial Setting weight, bias value.
    //======================================================================== 
    // conv1
    vector<vector<vector<vector<int>>>>    conv1_weight     
        (conv1.OCH, vector<vector<vector<int>>>(conv1.ICH, vector<vector<int>>(conv1.KY, vector<int>(conv1.KX, 0)))); // 8b
    vector<vector<vector<vector<int8_t>>>> conv1_weight_qnt 
        (conv1.OCH, vector<vector<vector<int8_t>>>(conv1.ICH, vector<vector<int8_t>>(conv1.KY, vector<int8_t>(conv1.KX, 0)))); // 8b
    rd_conv_weight(fp_in_conv1_weight, conv1_weight, conv1_weight_qnt, 
        conv1.OCH, conv1.ICH, conv1.KY, conv1.KX);
    vector<int>     conv1_bias     (conv1.OCH, 0); 		// 16b
    vector<int16_t> conv1_bias_qnt (conv1.OCH, 0); 		// 16b
    rd_bias(fp_in_conv1_bias, conv1_bias, conv1_bias_qnt, conv1.OCH);
    
    // conv2
    vector<vector<vector<vector<int>>>>    conv2_weight     
        (conv2.OCH, vector<vector<vector<int>>>(conv2.ICH, vector<vector<int>>(conv2.KY, vector<int>(conv2.KX, 0)))); // 8b
    vector<vector<vector<vector<int8_t>>>> conv2_weight_qnt 
        (conv2.OCH, vector<vector<vector<int8_t>>>(conv2.ICH, vector<vector<int8_t>>(conv2.KY, vector<int8_t>(conv2.KX, 0)))); // 8b
    rd_conv_weight(fp_in_conv2_weight, conv2_weight, conv2_weight_qnt, 
        conv2.OCH, conv2.ICH, conv2.KY, conv2.KX);
    vector<int>     conv2_bias     (conv2.OCH, 0); 		// 16b
    vector<int16_t> conv2_bias_qnt (conv2.OCH, 0); 		// 16b
    rd_bias(fp_in_conv2_bias, conv2_bias, conv2_bias_qnt, conv2.OCH);
    
    // fc1
    vector<vector<int>>    fc1_weight     (fc1.OCH, vector<int>(fc1.ICH, 0)); // 8b
    vector<vector<int8_t>> fc1_weight_qnt (fc1.OCH, vector<int8_t>(fc1.ICH, 0)); // 8b
    rd_fc_weight(fp_in_fc1_weight, fc1_weight, fc1_weight_qnt, fc1.OCH, fc1.ICH);
    vector<int>     fc1_bias     (fc1.OCH, 0); 		// 16b
    vector<int16_t> fc1_bias_qnt (fc1.OCH, 0); 		// 16b
    rd_bias(fp_in_fc1_bias, fc1_bias, fc1_bias_qnt, fc1.OCH);
    
    // fc2
    vector<vector<int>>    fc2_weight     (fc2.OCH, vector<int>(fc2.ICH, 0)); // 8b
    vector<vector<int8_t>> fc2_weight_qnt (fc2.OCH, vector<int8_t>(fc2.ICH, 0)); // 8b
    rd_fc_weight(fp_in_fc2_weight, fc2_weight, fc2_weight_qnt, fc2.OCH, fc2.ICH);
    vector<int>     fc2_bias     (fc2.OCH, 0); 		// 16b
    vector<int16_t> fc2_bias_qnt (fc2.OCH, 0); 		// 16b
    rd_bias(fp_in_fc2_bias, fc2_bias, fc2_bias_qnt, fc2.OCH);
    
    // fc3
    vector<vector<int>>    fc3_weight     (fc3.OCH, vector<int>(fc3.ICH, 0)); // 8b
    vector<vector<int8_t>> fc3_weight_qnt (fc3.OCH, vector<int8_t>(fc3.ICH, 0)); // 8b
    rd_fc_weight(fp_in_fc3_weight, fc3_weight, fc3_weight_qnt, fc3.OCH, fc3.ICH);
    vector<int>     fc3_bias     (fc3.OCH, 0); 		// 16b
    vector<int16_t> fc3_bias_qnt (fc3.OCH, 0); 		// 16b
    rd_bias(fp_in_fc3_bias, fc3_bias, fc3_bias_qnt, fc3.OCH);
    
    //========================================================================
    // Read Golden Quantized Value
    //======================================================================== 
    vector<int>    golden_otfmap     (fc3.OCH, 0); // 8b
    vector<int8_t> golden_otfmap_qnt (fc3.OCH, 0); // 8b
    
    rd_fc_otfmap(fp_in_otfmap, golden_otfmap, golden_otfmap_qnt, fc3.OCH);
    
    //===========================================================================
    // loop: LOOP_NUM
    //===========================================================================
	std::string s;
	for (int loop = 0; loop < LOOP_NUM; loop++){
        
        // Initial Setting infmap value.
        //------------------------------------------------------------------------ 
        // infmap 
        vector<vector<vector<int>>>    infmap     
            (conv1.ICH, vector<vector<int>>(conv1.IY, vector<int>(conv1.IX, 0))); // 8b
        vector<vector<vector<int8_t>>> infmap_qnt 
            (conv1.ICH, vector<vector<int8_t>>(conv1.IY, vector<int8_t>(conv1.IX, 0))); // 8b
        // rd_conv_infmap(fp_in_infmap, infmap, infmap_qnt, conv1.ICH, conv1.IY, conv1.IX);
        read_mnist_images(fp_in_infmap, infmap, infmap_qnt, loop+1); 
        
        int label;
        read_mnist_labels(fp_in_label, label, loop+1); 
        cout << "Loop: " << loop << " label: " << label << endl; 
        //------------------------------------------------------------------------ 
        
        // conv1
        vector<vector<vector<int>>>    conv1_otfmap 
            (conv1.OCH, vector<vector<int>>(conv1.OY, vector<int>(conv1.OX, 0))); // 8b
        vector<vector<vector<int>>>    pool1_otfmap 
            (pool1.OCH, vector<vector<int>>(pool1.OY, vector<int>(pool1.OX, 0))); // 8b
        
        // conv2
        vector<vector<vector<int>>>    conv2_otfmap 
            (conv2.OCH, vector<vector<int>>(conv2.OY, vector<int>(conv2.OX, 0))); // 8b
        vector<vector<vector<int>>>    pool2_otfmap 
            (pool2.OCH, vector<vector<int>>(pool2.OY, vector<int>(pool2.OX, 0))); // 8b
        
        // flatten
        vector<int>    fc1_infmap (fc1.ICH, 0); // 8b
        
        // fc1
        vector<int>    fc1_otfmap (fc1.OCH, 0); // 8b
        
        // fc2
        vector<int>    fc2_otfmap (fc2.OCH, 0); // 8b
        
        // fc3
        vector<int>    fc3_otfmap (fc3.OCH, 0); // 8b
        
        vector<int8_t> fc3_otfmap_qnt (fc3.OCH, 0); // 8b
        // vector<vector<vector<int>>>    otfmap_test 
        //     (OCH, vector<vector<int>>(OY, vector<int>(OX, 0))); // 8b
	    
        // for(int och = 0; och < OCH; och ++){
        //     for(int oy = 0; oy < OY; oy++){
        //         for(int ox = 0; ox < OX; ox++){
        //             otfmap[och][oy][ox] = 0;
        //             otfmap_qnt[och][oy][ox] = 0;
        //             // otfmap_test[och][oy][ox] = 0;
        // } } }
        
        //========================================================================
        // Random infmap
        //========================================================================
        // for(int ich = 0; ich < ICH; ich ++){
        //     infmap_qnt[ich] = rd() % 128;
        //     infmap[ich] = infmap_qnt[ich];
        // } 
        
        //========================================================================
        // Calculate LeNet5
        //========================================================================
        // conv1
        conv_layer(infmap, conv1_weight, conv1_bias, conv1_otfmap, 
            conv1.OCH, conv1.OY , conv1.OX , conv1.ICH, conv1.KY , conv1.KX , 
            M_INV_conv1, B_SCALE_conv1);
        max_pooling(conv1_otfmap, pool1_otfmap, 
            pool1.OCH, pool1.OY, pool1.OX, pool1.KY, pool1.KX);
        
        // conv2
        conv_layer(pool1_otfmap, conv2_weight, conv2_bias, conv2_otfmap, 
            conv2.OCH, conv2.OY , conv2.OX , conv2.ICH, conv2.KY , conv2.KX , 
            M_INV_conv2, B_SCALE_conv2);
        max_pooling(conv2_otfmap, pool2_otfmap, 
            pool2.OCH, pool2.OY, pool2.OX, pool2.KY, pool2.KX);
        
        // flatten
        flatten(pool2_otfmap, fc1_infmap, pool2.OCH, pool2.OY, pool2.OX);
        
        // fc1
        fc_layer(fc1_infmap, fc1_weight, fc1_bias, fc1_otfmap, 
                fc1.OCH, fc1.ICH, M_INV_fc1, B_SCALE_fc1, 1);
        
        // fc2
        fc_layer(fc1_otfmap, fc2_weight, fc2_bias, fc2_otfmap, 
            fc2.OCH, fc2.ICH, M_INV_fc2, B_SCALE_fc2, 1);
        
        // fc3
        fc_layer(fc2_otfmap, fc3_weight, fc3_bias, fc3_otfmap, 
            fc3.OCH, fc3.ICH, M_INV_fc3, B_SCALE_fc3, 0);
        
        // Print Test Quantization
        int test_fc3 = 0;
	    for(int och = 0; och < fc3.OCH; och ++){
            fc3_otfmap_qnt[och] = fc3_otfmap[och];
            if(golden_otfmap[och] != fc3_otfmap[och]) {
                // cout << och << endl; 
                test_fc3++;
            }
	    }
        if(test_fc3 != 0) cout << "Quantization Diff Num: " << test_fc3 << std::endl;
        
        //========================================================================
        // Algorithm test
        //========================================================================
	    // int ixb  , ixt  ; 
        // int iy ;
	    // int ichb , icht ; 
        
        
        // // Print Test Result
        // int test = 0;
	    // for(och = 0; och < OCH; och ++){
	    // 	for(oy = 0; oy < OY; oy++){
	    // 		for(ox = 0; ox < OX; ox++){
        //             if(pooling[och][oy][ox] != pooling_test[och][oy][ox]) {
        //                 cout << och << " " << oy << " " << ox << endl; 
        //                 cout << "pooling: " << pooling[och][oy][ox] << 
        //                     " pooling_test: " << pooling_test[och][oy][ox] << endl; 
        //                 test++;
        //             }
	    // } } }
        // if(test != 0) cout << "Wrong!! test: " << test << std::endl;
        
        //========================================================================
		// file write
        //========================================================================
        // infmap
		wr_conv_infmap(loop, fp_ot_infmap, infmap_qnt, 
            conv1.ICH, conv1.IY, conv1.IX);
        
        if(loop == 0) {
            // conv1
            wr_conv_weight(loop, fp_ot_conv1_weight, conv1_weight_qnt, 
                conv1.OCH, conv1.ICH, conv1.KY, conv1.KX);
            wr_bias(loop, fp_ot_conv1_bias, conv1_bias_qnt, conv1.OCH);
            
            // conv2
            wr_conv_weight(loop, fp_ot_conv2_weight, conv2_weight_qnt, 
                conv2.OCH, conv2.ICH, conv2.KY, conv2.KX);
            wr_bias(loop, fp_ot_conv2_bias, conv2_bias_qnt, conv2.OCH);
            
            // fc1
            wr_fc_weight(loop, fp_ot_fc1_weight, fc1_weight_qnt, fc1.OCH, fc1.ICH);
            wr_bias(loop, fp_ot_fc1_bias, fc1_bias_qnt, fc1.OCH);
            
            // fc2
            wr_fc_weight(loop, fp_ot_fc2_weight, fc2_weight_qnt, fc2.OCH, fc2.ICH);
            wr_bias(loop, fp_ot_fc2_bias, fc2_bias_qnt, fc2.OCH);
            
            // fc3
            wr_fc_weight(loop, fp_ot_fc3_weight, fc3_weight_qnt, fc3.OCH, fc3.ICH);
            wr_bias(loop, fp_ot_fc3_bias, fc3_bias_qnt, fc3.OCH);
        }
        
        // otfmap
        wr_result(loop, fp_ot_otfmap, fc3_otfmap_qnt, fc3.OCH);
	    // for(int och = 0; och < fc3.OCH; och ++){
        //     cout << std::hex << std::setw(2) << std::setfill('0') 
        //         << static_cast<int>(static_cast<uint8_t>(fc3_otfmap_qnt[och])) << std::endl;
	    // }
        
        
	}
    
    fp_in_infmap.close();
    fp_in_label.close();
    fp_in_conv1_weight.close();
    fp_in_conv1_bias  .close();
    fp_in_conv2_weight.close();
    fp_in_conv2_bias  .close();
    fp_in_fc1_weight.close();
    fp_in_fc1_bias  .close();
    fp_in_fc2_weight.close();
    fp_in_fc2_bias  .close();
    fp_in_fc3_weight.close();
    fp_in_fc3_bias  .close();
    fp_in_otfmap.close();
    
    fp_ot_infmap.close();
    fp_ot_conv1_weight.close();
    fp_ot_conv1_bias  .close();
    fp_ot_conv2_weight.close();
    fp_ot_conv2_bias  .close();
    fp_ot_fc1_weight.close();
    fp_ot_fc1_bias  .close();
    fp_ot_fc2_weight.close();
    fp_ot_fc2_bias  .close();
    fp_ot_fc3_weight.close();
    fp_ot_fc3_bias  .close();
    fp_ot_otfmap.close();
    
	return 0;
}
