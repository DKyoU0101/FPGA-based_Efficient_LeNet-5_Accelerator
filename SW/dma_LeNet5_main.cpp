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

#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xtime_l.h"  // To measure of processing time
#include <stdlib.h>	  // To generate rand value
#include <assert.h>
#include "dma_LeNet5_main.h"

// input data
#define PARAM_READ 1
#define HW_RUN 2
#define CHECK 3
#define TEST_MEM 4

#define AXI_DATA_BYTE 8 // 64 / 8

// REG MAP
#define ADDR_AP_CTRL                    0x00
#define ADDR_GIE                        0x04
#define ADDR_IER                        0x08
#define ADDR_ISR                        0x0c
// #define ADDR_RDMA_TRANSFER_BYTE_DATA_0  0x10
#define ADDR_RDMA_MEM_PTR_PARAM_0       0x14
#define ADDR_RDMA_MEM_PTR_INFMAP_0      0x18
#define ADDR_WDMA_MEM_PTR_DATA_0        0x1c
#define ADDR_AXI00_PTR0_DATA_0          0x20

#define CTRL_START_PARAM_MASK  1 << 0
#define CTRL_DONE_MASK         1 << 1
#define CTRL_IDLE_MASK         1 << 2
#define CTRL_READY_MASK        1 << 3
#define CTRL_START_INFMAP_MASK 1 << 4
#define CTRL_DONE_WDMA_MASK    1 << 5
#define CTRL_AUTO_RESTART_MASK 1 << 7

#define LOOP_NUM  30

#define USER_RDMA_INFMAP_ADDR  0x10000000
#define USER_WDMA_MEM_ADDR     (USER_RDMA_INFMAP_ADDR + 2048)
#define USER_RDMA_PARAM_ADDR   (USER_WDMA_MEM_ADDR + LOOP_NUM*8)

#define FPGA_FREQ     100000000

void read_mnist_labels_fatfs (
    FIL* fp_in_label,
    int& label,
    const int image_index
) {
    static bool first_call = true;
    static uint32_t num_labels;

    if (fp_in_label == NULL) {
        xil_printf("Error: MNIST label file is not open.\n");
        return;
    }

    if (first_call) {
        uint32_t magic;
        UINT bytes_read;
        f_lseek(fp_in_label, 0);
        f_read(fp_in_label, &magic, 4, &bytes_read);
        f_read(fp_in_label, &num_labels, 4, &bytes_read);

        magic = __builtin_bswap32(magic);
        num_labels = __builtin_bswap32(num_labels);

        if (magic != 2049) {
            xil_printf("Invalid magic number for labels: %u\n", magic);
            return;
        }
        first_call = false;
    }

    if (image_index < 1 || image_index > static_cast<int>(num_labels)) {
        xil_printf("Label index out of range: %d (valid range: 1 to %u)\n", image_index, num_labels);
        return;
    }

    const int header_size = 8;
    const int offset = header_size + (image_index - 1);

    f_lseek(fp_in_label, offset);

    unsigned char label_byte;
    UINT bytes_read;
    f_read(fp_in_label, &label_byte, 1, &bytes_read);
    label = static_cast<int>(label_byte);
}

void read_mnist_images_fatfs (
    FIL* fp_in_infmap,
    int8_t* infmap_qnt,
    u64* infmap_bus
) {
    
    static bool first_call = true;
    static uint32_t num_images, rows, cols;

    if (fp_in_infmap == NULL) {
        xil_printf("Error: MNIST image file is not open.\n");
        return;
    }

    if (first_call) {
        uint32_t magic;
        UINT bytes_read;
        f_lseek(fp_in_infmap, 0);
        f_read(fp_in_infmap, &magic, 4, &bytes_read);
        f_read(fp_in_infmap, &num_images, 4, &bytes_read);
        f_read(fp_in_infmap, &rows, 4, &bytes_read);
        f_read(fp_in_infmap, &cols, 4, &bytes_read);

        magic = __builtin_bswap32(magic);
        num_images = __builtin_bswap32(num_images);
        rows = __builtin_bswap32(rows);
        cols = __builtin_bswap32(cols);

        if (magic != 2051) {
            xil_printf("Invalid magic number: %u\n", magic);
            return;
        }
        if (rows != 28 || cols != 28) {
            xil_printf("Unexpected image dimensions: %u x %u\n", rows, cols);
            return;
        }
        first_call = false;
    }

    if (LOOP_NUM < 1 || LOOP_NUM > static_cast<int>(num_images)) {
        xil_printf("Image index out of range: %d (valid range: 1 to %u)\n", LOOP_NUM, num_images);
        return;
    }

    const int image_size = 28 * 28;
    const int header_size = 16;
    const int offset = header_size + (1 - 1) * image_size;

    f_lseek(fp_in_infmap, offset);

    float normalized_pad = (0.0f - 0.1307f) / 0.3081f;
    int pad_value = static_cast<int>(std::round(normalized_pad * 32.0f));
    pad_value = std::max(-128, std::min(127, pad_value));
    
    for (int loop = 0; loop < LOOP_NUM; ++loop) {
        for (int iy = 0; iy < 32; ++iy) {
            for (int ix = 0; ix < 32; ++ix) {
                unsigned long index = (loop * CONV1_IY + iy) * CONV1_IX + ix;
                
                if((ix >= 2) && (ix < 30) && (iy >= 2) && (iy < 30)) {
                    unsigned char pixel;
                    UINT bytes_read;
                    f_read(fp_in_infmap, &pixel, 1, &bytes_read);
                    
                    float normalized = (static_cast<float>(pixel) / 255.0f - 0.1307f) / 0.3081f;
                    
                    int quantized = static_cast<int>(std::round(normalized * 32.0f));
                    
                    quantized = std::max(-128, std::min(127, quantized));
                    
                    infmap_qnt[index] = static_cast<int8_t>(quantized);
                } else {
                    infmap_qnt[index] = static_cast<int8_t>(pad_value);
                }
                // xil_printf("index: %d, infmap_qnt: %02x ", index, (int8_t)(infmap_qnt[index] & 0xff));
            }
            // xil_printf("n");
        }
    }
    
    unsigned long addr_byte = 0;
    for (int loop = 0; loop < LOOP_NUM; ++loop) {
        for (int iy = 0; iy < CONV1_IY; iy++) {
            for (int ix = 0; ix < CONV1_IX; ix += B_COL_NUM) {
                u64 bus_data = 0;
                for (int col = 0; col < B_COL_NUM; col++) {
                    unsigned long index = (loop * CONV1_IY + iy) * CONV1_IX + (ix + col);
                    bus_data |= ((u64)(infmap_qnt[index] & 0xff) << (col * 8));
                    // xil_printf("index: %d, infmap_qnt: %02x ", index, (int8_t)(infmap_qnt[index] & 0xff));
                }
                infmap_bus[addr_byte] = bus_data;
                // xil_printf("addr_byte: %08x infmap_baseaddr: %08x%08x \n", addr_byte, (u32)(infmap_bus[addr_byte] >> 32), (u32)infmap_bus[addr_byte]);
                addr_byte++;
            }
        }
        // if(loop%100 == 0) {
            // xil_printf("loop:%4d Write infmap_bus done! \n\n", loop);
        // } 
    }
    
}

void rd_conv_weight_fatfs(
    FIL* fp_in_weight,
    int8_t* weight_qnt,  // Pointer to 1D array for quantized weights
    const int OCH,       // Output channels
    const int ICH,       // Input channels
    const int KY,        // Kernel height
    const int KX         // Kernel width
) {
    char line[64];
    for (int och = 0; och < OCH; och++) {
        for (int ich = 0; ich < ICH; ich++) {
            for (int ky = 0; ky < KY; ky++) {
                for (int kx = 0; kx < KX; kx++) {
                    if (f_gets(line, sizeof(line), fp_in_weight) == NULL) {
                        xil_printf("weight: Unable to read line.\n");
                    }
                    char* pos = strstr(line, "0x");
                    if (pos == NULL) {
                        xil_printf("weight: Format error: '0x' not found.\n");
                    }
                    char* hex_str = pos + 2;
                    if (strlen(hex_str) < 2) {
                        xil_printf("weight: Hex string length error.\n");
                    }
                    int val = strtol(hex_str, NULL, 16);
                    int index = ((och * ICH + ich) * KY + ky) * KX + kx;
                    weight_qnt[index] = static_cast<int8_t>(val);
                }
            }
        }
    }
}

void rd_fc_weight_fatfs(
    FIL* fp_in_weight,
    int8_t* weight_qnt,  // Pointer to 1D array for quantized weights
    const int OCH,       // Output channels
    const int ICH        // Input channels
) {
    char line[64];
    for (int och = 0; och < OCH; och++) {
        for (int ich = 0; ich < ICH; ich++) {
            if (f_gets(line, sizeof(line), fp_in_weight) == NULL) {
                xil_printf("fc_weight: Unable to read line.\n");
            }
            char* pos = strstr(line, "0x");
            if (pos == NULL) {
                xil_printf("fc_weight: Format error: '0x' not found.\n");
            }
            char* hex_str = pos + 2;
            if (strlen(hex_str) < 2) {
                xil_printf("fc_weight: Hex string length error.\n");
            }
            int val = strtol(hex_str, NULL, 16);
            unsigned long index = och * ICH + ich;
            weight_qnt[index] = static_cast<int8_t>(val);
        }
    }
}

void rd_bias_fatfs(
    FIL* fp_in_bias,
    int16_t* bias_qnt,  // Pointer to 1D array for quantized biases
    const int OCH       // Output channels
) {
    char line[64];
    for (int och = 0; och < OCH; och++) {
        if (f_gets(line, sizeof(line), fp_in_bias) == NULL) {
            xil_printf("bias: Unable to read line.\n");
        }
        char* pos = strstr(line, "0x");
        if (pos == NULL) {
            xil_printf("bias: Format error: '0x' not found.\n");
        }
        char* hex_str = pos + 2;
        if (strlen(hex_str) < 4) {
            xil_printf("bias: Hex string length error.\n");
        }
        int val = strtol(hex_str, NULL, 16);
        bias_qnt[och] = static_cast<int16_t>(val);
    }
}

void rd_param_fatfs(
    u64* rdma_baseaddr
) {
    xil_printf("Starting rd_param_fatfs...\n");

    FATFS fatfs;
    FIL fp_conv1_weight, fp_conv1_bias, fp_conv2_weight, fp_conv2_bias,
        fp_fc1_weight, fp_fc1_bias, fp_fc2_weight, fp_fc2_bias,
        fp_fc3_weight, fp_fc3_bias;
    FRESULT res;

    // Mount the file system
    res = f_mount(&fatfs, "0:/", 1);
    if (res != FR_OK) {
        xil_printf("Failed to mount SD card: %d\n", res);
        return;
    }
    xil_printf("SD card mounted successfully.\n");

    // Open all parameter files with error checking
    res = f_open(&fp_conv1_weight, FP_IN_CONV1_WEIGHT, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_CONV1_WEIGHT, res);
        return;
    }
    res = f_open(&fp_conv1_bias, FP_IN_CONV1_BIAS, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_CONV1_BIAS, res);
        return;
    }
    res = f_open(&fp_conv2_weight, FP_IN_CONV2_WEIGHT, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_CONV2_WEIGHT, res);
        return;
    }
    res = f_open(&fp_conv2_bias, FP_IN_CONV2_BIAS, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_CONV2_BIAS, res);
        return;
    }
    res = f_open(&fp_fc1_weight, FP_IN_FC1_WEIGHT, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC1_WEIGHT, res);
        return;
    }
    res = f_open(&fp_fc1_bias, FP_IN_FC1_BIAS, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC1_BIAS, res);
        return;
    }
    res = f_open(&fp_fc2_weight, FP_IN_FC2_WEIGHT, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC2_WEIGHT, res);
        return;
    }
    res = f_open(&fp_fc2_bias, FP_IN_FC2_BIAS, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC2_BIAS, res);
        return;
    }
    res = f_open(&fp_fc3_weight, FP_IN_FC3_WEIGHT, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC3_WEIGHT, res);
        return;
    }
    res = f_open(&fp_fc3_bias, FP_IN_FC3_BIAS, FA_READ);
    if (res != FR_OK) {
        xil_printf("Failed to open %s: %d\n", FP_IN_FC3_BIAS, res);
        return;
    }
    xil_printf("All files opened successfully.\n");

    // Define fixed-size 1D arrays for weights and biases
    std::vector<int8_t> conv1_weight_qnt(CONV1_OCH * CONV1_ICH * CONV_KY * CONV_KX);
    std::vector<int16_t> conv1_bias_qnt(CONV1_OCH);
    std::vector<int8_t> conv2_weight_qnt(CONV2_OCH * CONV2_ICH * CONV_KY * CONV_KX);
    std::vector<int16_t> conv2_bias_qnt(CONV2_OCH);
    std::vector<int8_t> fc1_weight_qnt(FC1_OCH * FC1_ICH);
    std::vector<int16_t> fc1_bias_qnt(FC1_OCH);
    std::vector<int8_t> fc2_weight_qnt(FC2_OCH * FC2_ICH);
    std::vector<int16_t> fc2_bias_qnt(FC2_OCH);
    std::vector<int8_t> fc3_weight_qnt(FC3_OCH * FC3_ICH);
    std::vector<int16_t> fc3_bias_qnt(FC3_OCH);

    // Read data from files using FatFs functions
    xil_printf("Reading conv1 weights...\n");
    rd_conv_weight_fatfs(&fp_conv1_weight, &conv1_weight_qnt[0], CONV1_OCH, CONV1_ICH, CONV_KY, CONV_KX);
    xil_printf("Reading conv1 biases...\n");
    rd_bias_fatfs(&fp_conv1_bias, &conv1_bias_qnt[0], CONV1_OCH);
    xil_printf("Reading conv2 weights...\n");
    rd_conv_weight_fatfs(&fp_conv2_weight, &conv2_weight_qnt[0], CONV2_OCH, CONV2_ICH, CONV_KY, CONV_KX);
    xil_printf("Reading conv2 biases...\n");
    rd_bias_fatfs(&fp_conv2_bias, &conv2_bias_qnt[0], CONV2_OCH);
    xil_printf("Reading fc1 weights...\n");
    rd_fc_weight_fatfs(&fp_fc1_weight, &fc1_weight_qnt[0], FC1_OCH, FC1_ICH);
    xil_printf("Reading fc1 biases...\n");
    rd_bias_fatfs(&fp_fc1_bias, &fc1_bias_qnt[0], FC1_OCH);
    xil_printf("Reading fc2 weights...\n");
    rd_fc_weight_fatfs(&fp_fc2_weight, &fc2_weight_qnt[0], FC2_OCH, FC2_ICH);
    xil_printf("Reading fc2 biases...\n");
    rd_bias_fatfs(&fp_fc2_bias, &fc2_bias_qnt[0], FC2_OCH);
    xil_printf("Reading fc3 weights...\n");
    rd_fc_weight_fatfs(&fp_fc3_weight, &fc3_weight_qnt[0], FC3_OCH, FC3_ICH);
    xil_printf("Reading fc3 biases...\n");
    rd_bias_fatfs(&fp_fc3_bias, &fc3_bias_qnt[0], FC3_OCH);
    xil_printf("Read Param Done\n");

    unsigned long addr_byte = 0;

    // Store conv1 weights and biases
    for (int och = 0; och < CONV1_OCH; och++) {
        for (int ich = 0; ich < CONV1_ICH; ich++) {
            for (int ky = 0; ky < CONV_KY; ky++) {
                u64 bus_data = 0;
                for (int kx = 0; kx < CONV_KX; kx++) {
                    int index = ((och * CONV1_ICH + ich) * CONV_KY + ky) * CONV_KX + kx;
                    bus_data |= ((u64)(conv1_weight_qnt[index] & 0xff) << (kx * 8));
                }
                // xil_printf("addr_byte:%d bus_data: %08x%08x \n", addr_byte, (u32)(bus_data >> 32), (u32)bus_data);
                rdma_baseaddr[addr_byte] = bus_data;
                addr_byte++;
            }
        }
    }
    for (int och = 0; och < CONV1_OCH; och++) {
        rdma_baseaddr[addr_byte] = conv1_bias_qnt[och] & 0xffff;
        addr_byte++;
    }
    xil_printf("C1 Param Write Done \n");

    // Store conv2 weights and biases
    for (int och = 0; och < CONV2_OCH; och++) {
        for (int ich = 0; ich < CONV2_ICH; ich++) {
            for (int ky = 0; ky < CONV_KY; ky++) {
                u64 bus_data = 0;
                for (int kx = 0; kx < CONV_KX; kx++) {
                    int index = ((och * CONV2_ICH + ich) * CONV_KY + ky) * CONV_KX + kx;
                    bus_data |= ((u64)(conv2_weight_qnt[index] & 0xff) << (kx * 8));
                    // xil_printf("bus_data: %llx \n", bus_data);
                }
                rdma_baseaddr[addr_byte] = bus_data;
                addr_byte++;
            }
        }
    }
    for (int och = 0; och < CONV2_OCH; och++) {
        rdma_baseaddr[addr_byte] = conv2_bias_qnt[och] & 0xffff;
        addr_byte++;
    }
    xil_printf("C2 Param Write Done \n");

    // Store fc1 weights and biases
    for (int och = 0; och < FC1_OCH; och++) {
        for (int ichb = 0; ichb < FC1_ICH; ichb += FC1_ICH_T) {
            u64 bus_data = 0;
            for (int icht = 0; icht < FC1_ICH_T && (ichb + icht) < FC1_ICH; icht++) {
                int index = och * FC1_ICH + (ichb + icht);
                bus_data |= ((u64)(fc1_weight_qnt[index] & 0xff) << (icht * 8));
            }
            rdma_baseaddr[addr_byte] = bus_data;
            addr_byte++;
        }
    }
    for (int och = 0; och < FC1_OCH; och++) {
        rdma_baseaddr[addr_byte] = fc1_bias_qnt[och] & 0xffff;
        addr_byte++;
    }
    xil_printf("FC1 Param Write Done \n");

    // Store fc2 weights and biases
    for (int och = 0; och < FC2_OCH; och++) {
        for (int ichb = 0; ichb < FC2_ICH; ichb += FC2_ICH_T) {
            u64 bus_data = 0;
            for (int icht = 0; icht < FC2_ICH_T && (ichb + icht) < FC2_ICH; icht++) {
                int index = och * FC2_ICH + (ichb + icht);
                bus_data |= ((u64)(fc2_weight_qnt[index] & 0xff) << (icht * 8));
            }
            rdma_baseaddr[addr_byte] = bus_data;
            addr_byte++;
        }
    }
    for (int och = 0; och < FC2_OCH; och++) {
        rdma_baseaddr[addr_byte] = fc2_bias_qnt[och] & 0xffff;
        addr_byte++;
    }
    xil_printf("FC2 Param Write Done \n");

    // Store fc3 weights and biases
    for (int och = 0; och < FC3_OCH; och++) {
        for (int ichb = 0; ichb < FC3_ICH; ichb += FC3_ICH_T) {
            u64 bus_data = 0;
            for (int icht = 0; icht < FC3_ICH_T && (ichb + icht) < FC3_ICH; icht++) {
                int index = och * FC3_ICH + (ichb + icht);
                bus_data |= ((u64)(fc3_weight_qnt[index] & 0xff) << (icht * 8));
            }
            rdma_baseaddr[addr_byte] = bus_data;
            addr_byte++;
        }
    }
    for (int och = 0; och < FC3_OCH; och++) {
        rdma_baseaddr[addr_byte] = fc3_bias_qnt[och] & 0xffff;
        addr_byte++;
    }
    xil_printf("FC3 Param Write Done \n");

    // Close all files
    f_close(&fp_conv1_weight);
    f_close(&fp_conv1_bias);
    f_close(&fp_conv2_weight);
    f_close(&fp_conv2_bias);
    f_close(&fp_fc1_weight);
    f_close(&fp_fc1_bias);
    f_close(&fp_fc2_weight);
    f_close(&fp_fc2_bias);
    f_close(&fp_fc3_weight);
    f_close(&fp_fc3_bias);

    // Unmount the file system
    f_mount(NULL, "0:/", 1);
}

void run_hw_lenet5_fatfs(u64* wdma_baseaddr, u64* infmap_baseaddr, u64* infmap_bus) {
    xil_printf("Starting run_hw_lenet5_fatfs...\n");

    u32 read_data;

    int rd_loop = 0;
    // int wr_loop = 0;
    int rd_loop_ready = 0;
    unsigned long addr_loop = 0;
    
    // read wait
    while (1) {

        if(rd_loop_ready == 0) {
            
            unsigned long addr_byte = 0;
            for (int iy = 0; iy < CONV1_IY; iy++) {
                for (int ixt = 0; ixt < 8; ixt++) {
                    infmap_baseaddr[addr_byte] = infmap_bus[addr_loop + addr_byte];
                    // xil_printf("addr:%08x infmap_baseaddr: %08x%08x \n", &infmap_baseaddr[addr_byte], (u32)(infmap_baseaddr[addr_byte] >> 32), (u32)infmap_baseaddr[addr_byte]);
                    addr_byte++;
                }
            }
            addr_loop += CONV1_IY * 8;
            rd_loop_ready = 1;
            Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AP_CTRL, (u32)(CTRL_START_INFMAP_MASK));
            rd_loop++;
            // xil_printf("(idx: %0d) Write Test Image done! \n", rd_loop);
        }
        
        while (1) {
            read_data = Xil_In32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AP_CTRL);
            // xil_printf("read_data:  %08x\n", read_data);
            if((read_data & CTRL_DONE_MASK) == CTRL_DONE_MASK) {
                // xil_printf("(idx: %0d) Start Test Image! \n", rd_loop + 1);
                rd_loop_ready = 0;
                break;
            }
        }
        if(rd_loop >= LOOP_NUM) {
            break;
        }

    }
    
    // write wait
    while (1) {
        if ((wdma_baseaddr[LOOP_NUM-1] & 0xffff0) == ((LOOP_NUM-1) << 4)) {
            xil_printf("(idx: %0d) Hardware execution Done! \n", LOOP_NUM);
            break;
        } 
    }
    

    xil_printf("HW Run Done!");
}

int main() {
    XTime tStart, tEnd;
    
    u64* rdma_param_baseaddr = (u64*) USER_RDMA_PARAM_ADDR;
    u64* rdma_infmap_baseaddr = (u64*) USER_RDMA_INFMAP_ADDR;
    u64* wdma_mam_baseaddr = (u64*) USER_WDMA_MEM_ADDR;
            
    while (1) {
        u32 case_num;
    	printf("======= LeNet-5 HW Accelerator ======\n");
    	printf("plz input run mode\n");
    	printf("1. READ Quantized LeNet-5 Parameter \n");
    	printf("2. HW RUN \n");
    	printf("3. CHECK SW vs HW result\n");
    	printf("=====================================\n");
        do{
    		scanf("%lu",&case_num);
    	}while( !( (0 < case_num) && (case_num <= 4) ) );
		
		std::string s;
        // MODE: PARAM_READ
    	if (case_num == PARAM_READ){
    	    printf("rdma_param_baseaddr : 0x%x\n", USER_RDMA_PARAM_ADDR);
            
    	    Xil_DCacheDisable(); // flush to external mem.
            
            u32 read_data;
    	    Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AXI00_PTR0_DATA_0, (u32)(0x00000000)); // base addr no use now.
	        Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_RDMA_MEM_PTR_PARAM_0, (u32) rdma_param_baseaddr );
            Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_RDMA_MEM_PTR_INFMAP_0, (u32)rdma_infmap_baseaddr);
            Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_WDMA_MEM_PTR_DATA_0, (u32)wdma_mam_baseaddr);
            xil_printf("Hardware registers configured.\n");

            rd_param_fatfs(rdma_param_baseaddr);
            
            while(1) {
        		read_data = Xil_In32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AP_CTRL);
        	    if( (read_data & CTRL_IDLE_MASK) == CTRL_IDLE_MASK ) // IDLE
        	    	break;
        	}
            
    	    XTime_GetTime(&tStart);
        	Xil_Out32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AP_CTRL, (u32)(CTRL_START_PARAM_MASK)); // Start !!
         	while(1) {
        		read_data = Xil_In32((XPAR_DMA_LENET5_TOP_0_BASEADDR) + ADDR_AP_CTRL);
        	    if( (read_data & CTRL_DONE_MASK) == CTRL_DONE_MASK ) // DONE
        	    	break;
        	}
    	    XTime_GetTime(&tEnd);
        
		    printf("HW Mem Copy function Time %.2f us.\n",
		           1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000000));
    		printf("Parameter Data Read Success. \n");
    		printf("\n");
    	} 
        // MODE: HW_RUN
		else if(case_num == HW_RUN){
    	    printf("LOOP_NUM : 0%d\n", LOOP_NUM);
    	    printf("rdma_infmap_baseaddr : 0x%x\n", USER_RDMA_INFMAP_ADDR);
    	    printf("wdma_mem_baseaddr : 0x%x\n", USER_WDMA_MEM_ADDR);
            
            for (int loop = 0; loop < LOOP_NUM; loop++) {
                wdma_mam_baseaddr[loop] = 0;
            }
            
            // infmap file open
            FATFS fatfs;
            FIL fp_in_infmap;
            FRESULT res;
            
            res = f_mount(&fatfs, "0:/", 1);
            if (res != FR_OK) {
                xil_printf("SD card mount failed: %d\n", res);
            }
            xil_printf("SD card mounted successfully.\n");

            res = f_open(&fp_in_infmap, FP_IN_INFMAP_BIN, FA_READ);
            if (res != FR_OK) {
                xil_printf("%s file open failed: %d\n", FP_IN_INFMAP_BIN, res);
                f_mount(NULL, "0:/", 1);
            }
            xil_printf("MNIST image file opened successfully.\n");
            
            // read infmap 
            std::vector<int8_t>  infmap_qnt(LOOP_NUM * CONV1_IY * CONV1_IX);
            std::vector<u64>  infmap_bus(LOOP_NUM * CONV1_IY * 8);
            read_mnist_images_fatfs(&fp_in_infmap, &infmap_qnt[0], &infmap_bus[0]);
            xil_printf("Read image file successfully.\n");
            
            // run HW
    	    XTime_GetTime(&tStart);
    	    run_hw_lenet5_fatfs(wdma_mam_baseaddr, rdma_infmap_baseaddr, &infmap_bus[0]);
    	    XTime_GetTime(&tEnd);

		    printf("HW Mem Copy function Time %.3f ms.\n",
		           1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000));
            
            f_close(&fp_in_infmap);
            f_mount(NULL, "0:/", 1);
            
    		printf("HW Run Success. \n");
    		printf("\n");
    	} 
        // MODE: CHECK
		else if(case_num == CHECK){

            FATFS fatfs;
	        FIL fp_in_label;
            FRESULT res;

            res = f_mount(&fatfs, "0:/", 1);
            if (res != FR_OK) {
                xil_printf("SD card mount failed: %d\n", res);
            }
            xil_printf("SD card mounted successfully.\n");

            res = f_open(&fp_in_label, FP_IN_LABEL_BIN, FA_READ);
            if (res != FR_OK) {
                xil_printf("%s file open failed: %d\n", FP_IN_LABEL_BIN, res);
                f_mount(NULL, "0:/", 1);
            }
            xil_printf("MNIST label file opened successfully.\n");

            double wrong = 0;
            for(int loop = 0; loop < LOOP_NUM; loop++) {
                int label;
               read_mnist_labels_fatfs(&fp_in_label, label, loop+1);
                int infer = (wdma_mam_baseaddr[loop] & 0xf);
                if(label != infer){
                    printf("loop:%d, label:%d, inference:%d \n", loop+1, label, infer);
                    wrong++;
    		    }
            }
            f_close(&fp_in_label);
            f_mount(NULL, "0:/", 1);

    		printf("Test: %d, Accuracy: %f%% \n", LOOP_NUM, (LOOP_NUM*1.0 - wrong) / (LOOP_NUM*1.0) * 100);
    		printf("Check Inference Accuracy Success. \n");
    		printf("\n");
    	} 
        
        else if(case_num == TEST_MEM) {
            
            for (int loop = 0; loop < 5; loop++)
            {
                printf("infmap[%3d]: %08x%08x \n", loop+1, (u32)(rdma_infmap_baseaddr[loop] >> 32), (u32)rdma_infmap_baseaddr[loop]);
                printf("infmap_addr: %08x \n", &(rdma_infmap_baseaddr[loop]));
            }
            for (int loop = 0; loop < 100; loop++)
            {
                printf("wdma[%3d]: %08x%08x\n", loop+1, (u32)(wdma_mam_baseaddr[loop] >> 32), (u32)wdma_mam_baseaddr[loop]);
                printf("wdma_addr: %08x \n", &(wdma_mam_baseaddr[loop]));
            }
            for (int loop = 0; loop < 5; loop++)
            {
                printf("rdma[%3d]: %08x%08x\n", loop+1, (u32)(rdma_param_baseaddr[loop] >> 32), (u32)rdma_param_baseaddr[loop]);
                printf("rdma_addr: %08x \n", &(rdma_param_baseaddr[loop]));
            }

        }

		else {
    		// no operation, exit
    		//break;
    	}
    }
	
    return 0;
}
