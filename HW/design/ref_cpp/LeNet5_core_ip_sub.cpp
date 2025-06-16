//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
// 
// Create Date: 2025.03.28
// Associated Filename: LeNet5_core_ip_sub.cpp
// Project Name: CNN_FPGA
// Tool Versions: 
// Purpose: To run simulation
// Revision: 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

#include "LeNet5_core_ip.h"
void read_mnist_labels(
    std::ifstream& fp_in_label, 
    int& label, 
    const int image_index
) {
    static bool first_call = true;
    static uint32_t num_labels;

    // Check if the file is open
    if (!fp_in_label.is_open()) {
        std::cerr << "Error: MNIST label file is not open." << std::endl;
        exit(1);
    }

    // Read header only on the first call
    if (first_call) {
        uint32_t magic;
        fp_in_label.read(reinterpret_cast<char*>(&magic), 4);
        fp_in_label.read(reinterpret_cast<char*>(&num_labels), 4);

        // Convert from big-endian to host byte order
        magic = __builtin_bswap32(magic);
        num_labels = __builtin_bswap32(num_labels);

        // Validate magic number
        if (magic != 2049) {
            std::cerr << "Invalid magic number for labels: " << magic << std::endl;
            exit(1);
        }
        first_call = false;
    }

    // Validate image_index
    if (image_index < 1 || image_index > static_cast<int>(num_labels)) {
        std::cerr << "Label index out of range: " << image_index << " (valid range: 1 to " << num_labels << ")" << std::endl;
        exit(1);
    }

    // Calculate offset to the desired label
    const int header_size = 8; // 4 bytes for magic, 4 bytes for num_labels
    const int offset = header_size + (image_index - 1); // Each label is 1 byte

    // Move file pointer to the correct position
    fp_in_label.seekg(offset, std::ios::beg);

    // Read the label (1 byte)
    unsigned char label_byte;
    fp_in_label.read(reinterpret_cast<char*>(&label_byte), 1);
    label = static_cast<int>(label_byte);
}

void read_mnist_images(std::ifstream& fp_in_infmap, 
                       vector<vector<vector<int>>>& infmap, 
                       vector<vector<vector<int8_t>>>& infmap_qnt,
                       const int image_index) {
    static bool first_call = true;
    static uint32_t num_images, rows, cols;

    if (!fp_in_infmap.is_open()) {
        std::cerr << "Error: MNIST image file is not open." << std::endl;
        exit(1);
    }

    if (first_call) {
        // Read header only on the first call
        uint32_t magic;
        fp_in_infmap.read(reinterpret_cast<char*>(&magic), 4);
        fp_in_infmap.read(reinterpret_cast<char*>(&num_images), 4);
        fp_in_infmap.read(reinterpret_cast<char*>(&rows), 4);
        fp_in_infmap.read(reinterpret_cast<char*>(&cols), 4);

        // Handle big-endian format
        magic = __builtin_bswap32(magic);
        num_images = __builtin_bswap32(num_images);
        rows = __builtin_bswap32(rows);
        cols = __builtin_bswap32(cols);

        // Validate header
        if (magic != 2051) {
            std::cerr << "Invalid magic number: " << magic << std::endl;
            exit(1);
        }
        if (rows != 28 || cols != 28) {
            std::cerr << "Unexpected image dimensions: " << rows << "x" << cols << std::endl;
            exit(1);
        }
        first_call = false;
    }

    if (image_index < 1 || image_index > static_cast<int>(num_images)) {
        std::cerr << "Image index out of range: " << image_index << " (valid range: 1 to " << num_images << ")" << std::endl;
        exit(1);
    }

    // Calculate offset to the desired image
    const int image_size = 28 * 28; // 784 bytes per image
    const int header_size = 16;     // 4 bytes each for magic, num_images, rows, cols
    const int offset = header_size + (image_index - 1) * image_size;

    // Move to the correct position in the file
    fp_in_infmap.seekg(offset, std::ios::beg);

    // Clear existing data and read one image
    infmap.clear();
    infmap_qnt.clear();

    // Calculate the padding value: normalized and scaled 0
    float normalized_pad = (0.0f - 0.1307f) / 0.3081f;
    int pad_value = static_cast<int>(std::round(normalized_pad * 32.0f));
    pad_value = std::max(-128, std::min(127, pad_value));

    // Initialize 32x32 image with padding (single channel) using pad_value
    vector<vector<int>> image(32, vector<int>(32, pad_value));
    vector<vector<int8_t>> image_qnt(32, vector<int8_t>(32, static_cast<int8_t>(pad_value)));

    // Read 28x28 image data
    for (int y = 0; y < 28; ++y) {
        for (int x = 0; x < 28; ++x) {
            unsigned char pixel;
            fp_in_infmap.read(reinterpret_cast<char*>(&pixel), 1);

            // Normalize: (pixel / 255 - mean) / std
            float normalized = (static_cast<float>(pixel) / 255.0f - 0.1307f) / 0.3081f;

            // Scale and quantize: multiply by 32 and round
            int quantized = static_cast<int>(std::round(normalized * 32.0f));

            // Clip to [-128, 127]
            quantized = std::max(-128, std::min(127, quantized));

            // Store in padded region [2:30][2:30]
            image[y + 2][x + 2] = quantized;
            image_qnt[y + 2][x + 2] = static_cast<int8_t>(quantized);
        }
    }

    // Add the single image to the vectors
    infmap.push_back(image);
    infmap_qnt.push_back(image_qnt);
}

void rd_conv_infmap (
    std::ifstream& fp_in_infmap,
    vector<vector<vector<int>>>&    infmap,
    vector<vector<vector<int8_t>>>& infmap_qnt,
    const int ICH_ ,
    const int IY_  ,
    const int IX_
) {
    for(int ich = 0; ich < ICH_; ich ++){
    	for(int iy = 0; iy < IY_; iy++){
    		for(int ix = 0; ix < IX_; ix++){
        std::string line;
        
        if (!std::getline(fp_in_infmap, line)) {
            std::cerr << "infmap: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "infmap: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (INFMAP_QNT_BW/4));
        if (hex_str.length() != (INFMAP_QNT_BW/4)) {
            std::cerr << "infmap: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            infmap_qnt[ich][iy][ix] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            infmap[ich][iy][ix] = infmap_qnt[ich][iy][ix];
        } catch (const std::exception& e) {
            std::cerr << "infmap: Hex conversion error: " << hex_str << std::endl;
            return;
        }
    } } }
}

void rd_conv_weight (
    std::ifstream& fp_in_weight,
    vector<vector<vector<vector<int>>>>&    weight,
    vector<vector<vector<vector<int8_t>>>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ ,
    const int KY_  ,
    const int KX_  
) {
    for (int och = 0 ; och < OCH_; och++){
        for(int ich = 0; ich < ICH_; ich++){
            for(int ky = 0; ky < KY_; ky++){
                for(int kx = 0; kx < KX_; kx++){
        std::string line;
        
        if (!std::getline(fp_in_weight, line)) {
            std::cerr << "weight: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "weight: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (WEIGHT_QNT_BW/4));
        if (hex_str.length() != (WEIGHT_QNT_BW/4)) {
            std::cerr << "weight: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            weight_qnt[och][ich][ky][kx] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            weight[och][ich][ky][kx] = weight_qnt[och][ich][ky][kx];
        } catch (const std::exception& e) {
            std::cerr << "weight: Hex conversion error: " << hex_str << std::endl;
            return;
        } 
    } } } }
}

void rd_conv_otfmap (
    std::ifstream& fp_in_otfmap,
    vector<vector<vector<int>>>&    otfmap,
    vector<vector<vector<int8_t>>>& otfmap_qnt,
    const int OCH_ ,
    const int OY_  ,
    const int OX_
) {
    for(int och = 0; och < OCH_; och ++){
        for(int oy = 0; oy < OY_; oy++){
            for(int ox = 0; ox < OX_; ox++){
        std::string line;
        
        if (!std::getline(fp_in_otfmap, line)) {
            std::cerr << "otfmap: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "otfmap: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (OTFMAP_QNT_BW/4));
        if (hex_str.length() != (OTFMAP_QNT_BW/4)) {
            std::cerr << "otfmap: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            otfmap_qnt[och][oy][ox] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            otfmap[och][oy][ox] = otfmap_qnt[och][oy][ox];
        } catch (const std::exception& e) {
            std::cerr << "otfmap: Hex conversion error: " << hex_str << std::endl;
            return;
        } 
    } } }
}

void rd_fc_infmap (
    std::ifstream& fp_in_infmap,
    vector<int>&    infmap,
    vector<int8_t>& infmap_qnt,
    const int ICH_
) {
    for(int ich = 0; ich < ICH_; ich ++){
        std::string line;
        
        if (!std::getline(fp_in_infmap, line)) {
            std::cerr << "infmap: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "infmap: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (INFMAP_QNT_BW/4));
        if (hex_str.length() != (INFMAP_QNT_BW/4)) {
            std::cerr << "infmap: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            infmap_qnt[ich] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            infmap[ich] = infmap_qnt[ich];
        } catch (const std::exception& e) {
            std::cerr << "infmap: Hex conversion error: " << hex_str << std::endl;
            return;
        }
    } 
}

void rd_fc_weight (
    std::ifstream& fp_in_weight,
    vector<vector<int>>&    weight,
    vector<vector<int8_t>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ 
) {
    for (int och = 0 ; och < OCH_; och++){
        for(int ich = 0; ich < ICH_; ich++){
        std::string line;
        
        if (!std::getline(fp_in_weight, line)) {
            std::cerr << "weight: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "weight: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (WEIGHT_QNT_BW/4));
        if (hex_str.length() != (WEIGHT_QNT_BW/4)) {
            std::cerr << "weight: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            weight_qnt[och][ich] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            weight[och][ich] = weight_qnt[och][ich];
        } catch (const std::exception& e) {
            std::cerr << "weight: Hex conversion error: " << hex_str << std::endl;
            return;
        } 
    } }
}

void rd_fc_otfmap (
    std::ifstream& fp_in_otfmap,
    vector<int>&    otfmap,
    vector<int8_t>& otfmap_qnt,
    const int OCH_
) {
    for(int och = 0; och < OCH_; och ++){
        std::string line;
        
        if (!std::getline(fp_in_otfmap, line)) {
            std::cerr << "otfmap: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "otfmap: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (OTFMAP_QNT_BW/4));
        if (hex_str.length() != (OTFMAP_QNT_BW/4)) {
            std::cerr << "otfmap: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            otfmap_qnt[och] = static_cast<int8_t>(std::stoi(hex_str, nullptr, 16));
            otfmap[och] = otfmap_qnt[och];
        } catch (const std::exception& e) {
            std::cerr << "otfmap: Hex conversion error: " << hex_str << std::endl;
            return;
        } 
    } 
}

void rd_bias (
    std::ifstream& fp_in_bias,
    vector<int>&     bias,
    vector<int16_t>& bias_qnt,
    const int OCH_
) {
    for (int och = 0; och < OCH_; och++) {
        std::string line;
        
        if (!std::getline(fp_in_bias, line)) {
            std::cerr << "bias: Unable to read line. File does not have enough lines." << std::endl;
            return;
        }
        size_t pos = line.find("0x");
        if (pos == std::string::npos) {
            std::cerr << "bias: Format error: '0x' not found (line=" << line << ")" << std::endl;
            return;
        }
        std::string hex_str = line.substr(pos + 2, (BIAS_QNT_BW/4));
        if (hex_str.length() != (BIAS_QNT_BW/4)) {
            std::cerr << "bias: Hex string length error: " << hex_str << std::endl;
            return;
        }
        try {
            bias_qnt[och] = static_cast<int16_t>(std::stoi(hex_str, nullptr, 16));
            bias[och] = bias_qnt[och];
        } catch (const std::exception& e) {
            std::cerr << "bias: Hex conversion error: " << hex_str << std::endl;
            return;
        } 
    }
}

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
) {
    int32_t SHIFT = log2(M_INV);
    // int32_t QMIN = -128;
    int32_t QMAX = 127;
    int32_t B_SHIFT = log2(B_SCALE);
    
    for (int och = 0; och < OCH_; och++) {
        for(int oy = 0; oy < OY_; oy++){
            for(int ox = 0; ox < OX_; ox++){
                int32_t acc = 0;
                
                // Convolution
                for (int ich = 0; ich < ICH_; ++ich) {
                    for (int ky = 0; ky < KY_; ++ky) {
                        for (int kx = 0; kx < KX_; ++kx) {
                            int32_t in_val = infmap[ich][oy + ky][ox + kx];
                            int32_t w_val = weight[och][ich][ky][kx];
                            acc += in_val * w_val;
                } } }
                
                // Add bias (adjusted for scale difference)
                int32_t b_val = bias[och] << B_SHIFT;  // Multiply by 2 (S_B / (S_IN * S_W))
                acc += b_val;
                                
                // Scale and quantize
                // y = (acc * S_IN * S_W + bias * S_B) / S_OUT + ZP_OUT
                // Approximate: (acc >> SHIFT) + ZP_OUT
                int32_t scaled = (acc + (M_INV / 2)) >> SHIFT;  // Rounding
                                
                // Clamp to 8-bit range
                // if (scaled < QMIN) scaled = QMIN;
                if (scaled < 0) scaled = 0; // ReLU
                if (scaled > QMAX) scaled = QMAX;
                                
                otfmap[och][oy][ox] = static_cast<int>(scaled);
    } } }
}

void max_pooling (
    const vector<vector<vector<int>>>& infmap,
    vector<vector<vector<int>>>& pooling,
    const int OCH_ ,
    const int OY_  , 
    const int OX_  ,
    const int KY_  , 
    const int KX_  
) {
    for(int och = 0; och < OCH_; och++) {
        for(int oy = 0; oy < OY_; oy++) {
            for(int ox = 0; ox < OX_; ox++) {
                int max_pool = 0;
                int pool0 = infmap[och][oy*KY_ + 0][ox*KX_ + 0];
                int pool1 = infmap[och][oy*KY_ + 0][ox*KX_ + 1];
                int pool2 = infmap[och][oy*KY_ + 1][ox*KX_ + 0];
                int pool3 = infmap[och][oy*KY_ + 1][ox*KX_ + 1];
                
                max_pool = (pool0 > max_pool) ? (pool0) : (max_pool);
                max_pool = (pool1 > max_pool) ? (pool1) : (max_pool);
                max_pool = (pool2 > max_pool) ? (pool2) : (max_pool);
                max_pool = (pool3 > max_pool) ? (pool3) : (max_pool);
                
                pooling[och][oy][ox] = max_pool;
    } } }
    
}

void flatten (
    const vector<vector<vector<int>>>& infmap,
    vector<int>& otfmap,
    const int ICH_ ,
    const int IY_  , 
    const int IX_  
) {
    for(int ich = 0; ich < ICH_; ich++) {
        for(int iy = 0; iy < IY_; iy++) {
            for(int ix = 0; ix < IX_; ix++) {
                otfmap[(ich*IY_*IX_) + (iy*IX_) + (ix)] = infmap[ich][iy][ix];
    } } }
    
}

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
) {
    int32_t SHIFT = log2(M_INV); // Approximate 1/M 
    // constexpr int32_t QMIN = -128;
    int32_t QMAX = 127; // 2^7 - 1
    int32_t B_SHIFT = log2(B_SCALE);     // log2(1) = 0
    
    for (int och = 0; och < OCH_; och++) {
        int32_t acc = 0;
        
        // Convolution
        for (int ich = 0; ich < ICH_; ich++) {
            int32_t in_val = infmap[ich];
            int32_t w_val  = weight[och][ich];
            acc += in_val * w_val;  
        }
        
        // Add bias (adjusted for scale difference)
        int32_t b_val = bias[och] << B_SHIFT;
        acc += b_val;
        
        // Scale and quantize
        int32_t scaled = (acc + (M_INV / 2)) >> SHIFT;  // Rounding
        
        // Clamp to 8-bit range
        // if (scaled < QMIN) scaled = QMIN;
        if ((scaled < 0) && (relu)) scaled = 0; // ReLU
        if (scaled > QMAX) scaled = QMAX;
        
        otfmap[och] = static_cast<int>(scaled);
    }
    
}

//========================================================================
// file write
//========================================================================
void wr_conv_infmap (
    const int loop,
    std::ofstream& fp_ot_infmap,
    const vector<vector<vector<int8_t>>>& infmap_qnt,
    const int ICH_ ,
    const int IY_  ,
    const int IX_
) {
    fp_ot_infmap << "idx: ";
    fp_ot_infmap.width(3); fp_ot_infmap.fill('0');
    fp_ot_infmap << dec << loop ;
    fp_ot_infmap << " (ich,iy): ix " << std::endl;
    for(int ich = 0; ich < ICH_; ich ++){
        for(int iy = 0; iy < IY_; iy++){
            fp_ot_infmap << "(";
            fp_ot_infmap.width(2); fp_ot_infmap.fill('0');
            fp_ot_infmap << std::dec << ich << ",";
            fp_ot_infmap.width(2); fp_ot_infmap.fill('0');
            fp_ot_infmap << std::dec << iy << ") ";
            for(int ix = 0; ix < IX_; ix++){
                // Prevent from being interpreted as char
                fp_ot_infmap << std::hex << std::setw(2) << std::setfill('0') 
                << static_cast<int>(static_cast<uint8_t>(infmap_qnt[ich][iy][ix])) << " ";
                // fp_ot_infmap.width(2); fp_ot_infmap.fill('0');
                // fp_ot_infmap << std::hex << infmap[ich][iy][ix] << " ";
            }
            fp_ot_infmap << std::endl;
    } }
}

void wr_conv_weight (
    const int loop,
    std::ofstream& fp_ot_weight,
    const vector<vector<vector<vector<int8_t>>>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ ,
    const int KY_  ,
    const int KX_  
) {
    fp_ot_weight << "idx: ";
    fp_ot_weight.width(3); fp_ot_weight.fill('0');
    fp_ot_weight << dec << loop ;
    fp_ot_weight << " (och,ich,ky): kx " << std::endl;
    for (int och = 0 ; och < OCH_; och ++){
        for(int ich = 0; ich < ICH_; ich ++){
            for(int ky = 0; ky < KY_; ky++){
                fp_ot_weight << "(";
                fp_ot_weight.width(2); fp_ot_weight.fill('0');
                fp_ot_weight << std::dec << och << ",";
                fp_ot_weight.width(2); fp_ot_weight.fill('0');
                fp_ot_weight << std::dec << ich << ",";
                fp_ot_weight.width(2); fp_ot_weight.fill('0');
                fp_ot_weight << std::dec << ky << ") ";
                for(int kx = 0; kx < KX_; kx++){ 
                    // Prevent from being interpreted as char
                    fp_ot_weight << std::hex << std::setw(2) << std::setfill('0') 
                    << static_cast<int>(static_cast<uint8_t>(weight_qnt[och][ich][ky][kx])) << " ";
                    // fp_ot_weight.width(2); fp_ot_weight.fill('0');
                    // fp_ot_weight << std::dec << weight[och][ich][ky][kx] << " ";
                }
                fp_ot_weight << std::endl;
    } } }
}

void wr_conv_otfmap (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<vector<vector<int8_t>>>& otfmap_qnt,
    const int OCH_ ,
    const int OY_  ,
    const int OX_
) {
    fp_ot_otfmap << "idx: ";
    fp_ot_otfmap.width(3); fp_ot_otfmap.fill('0');
    fp_ot_otfmap << dec << loop ;
    fp_ot_otfmap << " (och,oy): ox " << std::endl;
    for(int och = 0; och < OCH_; och ++){
        for(int oy = 0; oy < OY_; oy++){
            fp_ot_otfmap << "(";
            fp_ot_otfmap.width(2); fp_ot_otfmap.fill('0');
            fp_ot_otfmap << std::dec << och << ",";
            fp_ot_otfmap.width(2); fp_ot_otfmap.fill('0');
            fp_ot_otfmap << std::dec << oy << ") ";
            for(int ox = 0; ox < OX_; ox++){
                // Prevent from being interpreted as char
                fp_ot_otfmap << std::hex << std::setw(2) << std::setfill('0') 
                << static_cast<int>(static_cast<uint8_t>(otfmap_qnt[och][oy][ox])) << " ";
            }
            fp_ot_otfmap << std::endl;
    } }
}

void wr_fc_infmap (
    const int loop,
    std::ofstream& fp_ot_infmap,
    const vector<int8_t>& infmap_qnt,
    const int ICH_ 
) {
    fp_ot_infmap << "idx: ";
    fp_ot_infmap.width(3); fp_ot_infmap.fill('0');
    fp_ot_infmap << dec << loop ;
    fp_ot_infmap << " (ich) " << std::endl;
    for(int ich = 0; ich < ICH_; ich ++){
        fp_ot_infmap << "(";
        fp_ot_infmap.width(3); fp_ot_infmap.fill('0');
        fp_ot_infmap << std::dec << ich << ") ";
        fp_ot_infmap.width(2); fp_ot_infmap.fill('0');
        fp_ot_infmap << std::hex << std::setw(2) << std::setfill('0') 
            << static_cast<int>(static_cast<uint8_t>(infmap_qnt[ich])) << " ";
        fp_ot_infmap << std::endl;
    } 
}

void wr_fc_weight (
    const int loop,
    std::ofstream& fp_ot_weight,
    const vector<vector<int8_t>>& weight_qnt,
    const int OCH_ , 
    const int ICH_ 
) {
    fp_ot_weight << "idx: ";
    fp_ot_weight.width(3); fp_ot_weight.fill('0');
    fp_ot_weight << dec << loop ;
    fp_ot_weight << " (och,ich) " << std::endl;
    for (int och = 0 ; och < OCH_; och ++){
        for(int ich = 0; ich < ICH_; ich ++){
            fp_ot_weight << "(";
            fp_ot_weight.width(3); fp_ot_weight.fill('0');
            fp_ot_weight << std::dec << och << ",";
            fp_ot_weight.width(3); fp_ot_weight.fill('0');
            fp_ot_weight << std::dec << ich << ") ";
            fp_ot_weight.width(2); fp_ot_weight.fill('0');
            fp_ot_weight << std::hex << std::setw(2) << std::setfill('0') 
                << static_cast<int>(static_cast<uint8_t>(weight_qnt[och][ich])) << " ";
            fp_ot_weight << std::endl;
    } }
}

void wr_fc_otfmap (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<int8_t>& otfmap_qnt,
    const int OCH_ 
) {
    fp_ot_otfmap << "idx: ";
    fp_ot_otfmap.width(3); fp_ot_otfmap.fill('0');
    fp_ot_otfmap << dec << loop ;
    fp_ot_otfmap << " (och) " << std::endl;
    for(int och = 0; och < OCH_; och++){
        fp_ot_otfmap << "(";
        fp_ot_otfmap.width(3); fp_ot_otfmap.fill('0');
        fp_ot_otfmap << std::dec << och << ") ";
        fp_ot_otfmap.width(2); fp_ot_otfmap.fill('0');
        fp_ot_otfmap << std::hex << std::setw(2) << std::setfill('0') 
            << static_cast<int>(static_cast<uint8_t>(otfmap_qnt[och])) << " ";
        fp_ot_otfmap << std::endl;
    } 
}

void wr_bias (
    const int loop,
    std::ofstream& fp_ot_bias,
    const vector<int16_t>& bias_qnt,
    const int OCH_
) {
    fp_ot_bias << "idx: ";
    fp_ot_bias.width(3); fp_ot_bias.fill('0');
    fp_ot_bias << dec << loop ;
    fp_ot_bias << " (och) " << std::endl;
    for(int och = 0; och < OCH_; och++){
        fp_ot_bias << "(";
        fp_ot_bias.width(2); fp_ot_bias.fill('0');
        fp_ot_bias << std::dec << och << ") ";
        fp_ot_bias.width(4); fp_ot_bias.fill('0');
        fp_ot_bias << std::hex << bias_qnt[och] << " ";
        fp_ot_bias << std::endl;
    } 
}

void wr_result (
    const int loop,
    std::ofstream& fp_ot_otfmap,
    const vector<int8_t>& otfmap_qnt,
    const int OCH_ 
) {
    fp_ot_otfmap << "idx: ";
    fp_ot_otfmap.width(3); fp_ot_otfmap.fill('0');
    fp_ot_otfmap << dec << loop ;
    
    int otfmap = -128;
    int result = 10;
    for(int och = 0; och < OCH_; och++){
        if(otfmap_qnt[och] > otfmap) {
            otfmap = otfmap_qnt[och];
            result = och;
        }
    } 
    cout << "  result: " << dec << result << std::endl;
    fp_ot_otfmap << "  result: " << dec << result << std::endl;
}