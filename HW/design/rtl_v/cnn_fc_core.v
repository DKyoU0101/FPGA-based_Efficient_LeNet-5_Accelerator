//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.03
// Design Name: LeNet-5
// Module Name: cnn_fc_core
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Convolution Arithmetic in Convolutional Layer
//                  input : infmap[ICH_T], 
//                          (OCH_T) * weight[ICH_T],
//                          bias[OCH_T]
//                  output: (OCH_T) * otfmap
//                  otfmap = infmap * weight + bias
//                  latency: ~ cycle(avarage:  cycle), delay = latency
//                          (random seed:5, LOOP_NUM:10)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           0.1(25.04.18) - delete b_i_scaled_q
//           0.2(25.04.19) - add parameter: IS_FINAL_LAYER
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"

module cnn_fc_core #(
    parameter MULT_DELAY     = 3   ,
    parameter ACC_DELAY      = 0   ,
    parameter AB_DELAY       = 1   ,
    parameter OCH            = 120 ,
    parameter ICH            = 400 ,
    parameter OCH_B          = 8   ,
    parameter ICH_B          = 40  ,
    parameter I_F_BW         = 8   ,
    parameter W_BW           = 8   ,
    parameter B_BW           = 16  ,
    parameter PARA_B_BW      = 6   ,
    parameter PARA_T_BW      = 4   ,
    parameter M_INV          = 256 ,
    parameter B_SCALE        = 1   ,
    parameter RELU           = 1   ,
    parameter IS_FINAL_LAYER = 0   
) (
    clk                 ,
    areset              ,
    i_run               ,
    i_scaling           ,
    i_infmap_start_idx  ,
    i_weight_start_addr ,
    i_bias_start_addr   ,
    o_idle              ,
    o_run               ,
    o_en_err            ,
    o_n_ready           ,
    o_ot_done           ,
    o_ot_valid          ,
    o_ot_otfmap_idx     ,
    o_ot_max_otfmap     ,
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
    b_i_bias_q          ,
    b_o_scaled_addr     ,
    b_o_scaled_ce       ,
    b_o_scaled_byte_we  ,
    b_o_scaled_d        
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// FSM 
localparam S_IDLE       = 0 ;
localparam S_RD_IF_W    = 1 ;
localparam S_MULT_SHIFT = 2 ;
localparam S_ACC_WAIT   = 3 ;
localparam S_SCALING    = 4 ;
localparam S_DONE       = 5 ;
localparam STATE_BW = S_DONE + 1 ; // One hot

// parameter size in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 15
localparam ICH_T  = ICH / ICH_B ; // 10

// parameter quantization scale
localparam M_INV_LOG2 = $clog2(M_INV) ; // 8
localparam ADDED_ROUNDING = M_INV / 2 ; // 128
localparam B_SHIFT = $clog2(B_SCALE) ; // 0

// parameter bit width
parameter   M_BW     = I_F_BW + W_BW; // 16 = I_F_BW + W_BW
parameter   O_F_BW   = M_BW + $clog2(ICH) ; // 25; Add Kernel 

// BRAM
localparam B_COL_NUM     = 4  ;
localparam B_COL_BW      = $clog2(B_COL_NUM) ; // 2
localparam B_INFMAP_DATA_W = 32 ;
localparam B_INFMAP_DATA_D = $rtoi($ceil(ICH*1.0 / B_COL_NUM*1.0)); // 100
localparam B_INFMAP_ADDR_W = $clog2(B_INFMAP_DATA_D); // 7
localparam B_WEIGHT_DATA_W = ICH_T * W_BW; // 80
localparam B_WEIGHT_DATA_D = OCH * ICH_B ; // 4800 = 120 * 40
localparam B_WEIGHT_ADDR_W = $clog2(B_WEIGHT_DATA_D); // 13
localparam B_BIAS_DATA_W   = B_BW ; // 16
localparam B_BIAS_DATA_D   = OCH  ; // 120
localparam B_BIAS_ADDR_W   = $clog2(B_BIAS_DATA_D); // 7
localparam B_SCALED_DATA_W = 32;
localparam B_SCALED_DATA_D = $rtoi($ceil(OCH*1.0 / B_COL_NUM*1.0)); // 30
localparam B_SCALED_ADDR_W = $clog2(B_SCALED_DATA_D); // 5

// Core Memory Size
localparam CORE_INFMAP_W = ICH_T * I_F_BW ; // 80
// localparam CORE_INFMAP_D = 1;
localparam CORE_WEIGHT_W = ICH_T * W_BW ; // 80
localparam CORE_WEIGHT_D = OCH_T ; // 15
localparam CORE_OTFMAP_W = O_F_BW ; // 25
localparam CORE_OTFMAP_D = OCH_T ; // 15
localparam CORE_BIAS_W   = B_BW  ; // 16
localparam CORE_BIAS_D   = OCH_T ; // 15

// parallel multiplier
localparam MULT_OPS = OCH_T ; // 15

// counter (cnt_max > 2)
localparam MSFT_CNT_MAX = ICH_T ; // 10
localparam MSFT_CNT_BW  = $clog2(MSFT_CNT_MAX) ; // 4
localparam ACC_CNT_MAX  = ICH_T ; // 10
localparam ACC_CNT_BW   = $clog2(ACC_CNT_MAX) ; // 4
localparam AB_CNT_MAX   = OCH_T ; // 15
localparam AB_CNT_BW    = $clog2(AB_CNT_MAX) ; // 4
localparam SCALED_CNT_MAX = OCH_T ; // 15
localparam SCALED_CNT_BW  = $clog2(SCALED_CNT_MAX) ; // 4

// index
localparam INFMAP_I_IDX_BW = $clog2(ICH); // 9
localparam INFMAP_ICH_T_BW = ICH_T * I_F_BW ; // 80
localparam WEIGHT_O_IDX_BW = $clog2(OCH_T); // 4
localparam BIAS_O_IDX_BW   = $clog2(OCH_T) ; // 4
localparam SCALED_I_IDX_BW = $clog2(OCH) ; // 7
localparam OTFMAP_O_IDX_BW  = $clog2(OCH) ; // 4

// scaled output feature map
localparam QNT_OTFMAP_BW = O_F_BW - M_INV_LOG2; // 17
localparam QNT_MIN = -(1 << (I_F_BW-1)); // -128
localparam QNT_MAX = (1 << (I_F_BW-1)) - 1; // 127
localparam OCH_T_SCALED_BW = OCH_T * I_F_BW ; // 120

// // delay
// localparam DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                           clk                 ;
input                           areset              ;

input                           i_run               ;
input                           i_scaling           ;

input  [INFMAP_I_IDX_BW-1 : 0]  i_infmap_start_idx  ;
input  [B_WEIGHT_ADDR_W-1 : 0]  i_weight_start_addr ;
input  [B_BIAS_ADDR_W-1 : 0]    i_bias_start_addr   ;

output                          o_idle              ;
output                          o_run               ;
output                          o_en_err            ;
output                          o_n_ready           ;
output                          o_ot_done           ;

output                          o_ot_valid          ;
output [OTFMAP_O_IDX_BW-1 : 0]  o_ot_otfmap_idx     ;
output [I_F_BW-1 : 0]           o_ot_max_otfmap     ;

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

output [B_SCALED_ADDR_W-1 : 0]  b_o_scaled_addr     ;
output                          b_o_scaled_ce       ;
output [B_COL_NUM-1 : 0]        b_o_scaled_byte_we  ;
output [B_SCALED_DATA_W-1 : 0]  b_o_scaled_d        ;
// input  [B_SCALED_DATA_W-1 : 0]  b_i_scaled_q        ; // not using read bram

//==============================================================================
// Declaration Submodule Port
//==============================================================================
wire                         c_infmap_i_run             ;
wire [INFMAP_I_IDX_BW-1 : 0] c_infmap_i_rd_start_idx    ;
wire                         c_infmap_o_idle            ;
wire                         c_infmap_o_run             ;
wire                         c_infmap_o_en_err          ;
wire                         c_infmap_o_n_ready         ;
wire                         c_infmap_o_ot_valid        ;
wire                         c_infmap_o_ot_done         ;
wire [INFMAP_ICH_T_BW-1 : 0] c_infmap_o_ot_infmap       ;

wire                         c_weight_i_run             ;
wire [B_WEIGHT_ADDR_W-1 : 0] c_weight_i_rd_start_addr   ;
wire                         c_weight_o_idle            ;
wire                         c_weight_o_run             ;
wire                         c_weight_o_en_err          ;
wire                         c_weight_o_n_ready         ;
wire                         c_weight_o_ot_valid        ;
wire                         c_weight_o_ot_done         ;
wire [WEIGHT_O_IDX_BW-1 : 0] c_weight_o_ot_idx          ;
wire [B_WEIGHT_DATA_W-1 : 0] c_weight_o_ot_weight       ;

wire                         c_prmult_i_run             ;
wire                         c_prmult_o_idle            ;
wire                         c_prmult_o_run             ;
wire                         c_prmult_o_n_ready         ;
wire [MULT_OPS*I_F_BW-1 : 0] c_prmult_i_in0             ;
wire [MULT_OPS*W_BW  -1 : 0] c_prmult_i_in1             ;
wire                         c_prmult_o_valid           ;
wire [MULT_OPS*M_BW  -1 : 0] c_prmult_o_result          ;

wire                         c_bias_i_run               ;
wire [B_BIAS_ADDR_W-1 : 0]   c_bias_i_rd_start_addr     ;
wire                         c_bias_o_idle              ;
wire                         c_bias_o_run               ;
wire                         c_bias_o_en_err            ;
wire                         c_bias_o_n_ready           ;
wire                         c_bias_o_ot_valid          ;
wire                         c_bias_o_ot_done           ;
wire [BIAS_O_IDX_BW-1 : 0]   c_bias_o_ot_idx            ;
wire [B_BIAS_DATA_W-1 : 0]   c_bias_o_ot_bias           ;

wire                         c_scaled_i_run             ;
wire [SCALED_I_IDX_BW-1 : 0] c_scaled_i_scaled_idx      ;
wire [OCH_T_SCALED_BW-1 : 0] c_scaled_i_ocht_scaled     ;
wire                         c_scaled_o_idle            ;
wire                         c_scaled_o_run             ;
wire                         c_scaled_o_n_ready         ;
wire                         c_scaled_o_en_err          ;
wire                         c_scaled_o_ot_done         ;

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
reg  [B_BIAS_ADDR_W-1 : 0] r_bias_start_addr       ;
always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
        r_scaling <= 1'b0;
        r_bias_start_addr <= 1'b0;
    end else if(i_run) begin
        r_run <= 1'b1;
        r_scaling <= i_scaling;
        r_bias_start_addr <= i_bias_start_addr;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
        r_scaling <= 1'b0;
        r_bias_start_addr <= 1'b0;
    end 
end

//==============================================================================
// Counter: mult_shift, acc, add_bias
//==============================================================================
reg  [MSFT_CNT_BW-1 : 0] r_msft_cnt ;
reg  [ACC_CNT_BW-1  : 0] r_acc_cnt  ;
reg  [AB_CNT_BW-1   : 0] r_add_bias_cnt  ;

reg  r_add_bias_cnt_valid ;

reg  r_msft_cnt_done ;
reg  r_acc_cnt_done  ;
reg  r_add_bias_cnt_done  ;

reg  r_acc_cnt_done_t1;

// counter
always @(posedge clk) begin
    if((areset) || (r_msft_cnt_done)) begin
        r_msft_cnt <= {MSFT_CNT_BW{1'b0}};
    end else if (c_state[S_MULT_SHIFT]) begin
        r_msft_cnt <= r_msft_cnt + 1;
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
    end else if((c_state[S_ACC_WAIT]) && (r_acc_cnt_done) && (r_scaling)) begin
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
        r_acc_cnt_done_t1 <= 1'b0;
    end else begin
        r_acc_cnt_done_t1 <= r_acc_cnt_done;
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
//  Update Core Otfmap: rd otfmap, wr otfmap, add bias
//==============================================================================
reg  r_update_core_otfmap;

always @(posedge clk) begin
    if((areset) || (r_add_bias_cnt_done)) begin
        r_update_core_otfmap <= 1'b0;
    end else if((c_state[S_ACC_WAIT]) && (r_acc_cnt_done) && (r_scaling)) begin
        r_update_core_otfmap <= 1'b1;
    end
end

//==============================================================================
// Inner Core Register Memory
//==============================================================================
reg         [CORE_INFMAP_W-1 : 0] r_core_infmap ;
reg         [CORE_INFMAP_W-1 : 0] n_core_infmap ;
reg         [CORE_WEIGHT_W-1 : 0] r_core_weight [0 : CORE_WEIGHT_D-1] ;
reg         [CORE_WEIGHT_W-1 : 0] n_core_weight [0 : CORE_WEIGHT_D-1] ;
reg  signed [CORE_OTFMAP_W-1 : 0] r_core_otfmap [0 : CORE_OTFMAP_D-1] ;
reg  signed [CORE_OTFMAP_W-1 : 0] n_core_otfmap [0 : CORE_OTFMAP_D-1] ;
reg  signed [CORE_BIAS_W-1 : 0]   r_core_bias   [0 : CORE_BIAS_D-1]   ;
reg  signed [CORE_BIAS_W-1 : 0]   n_core_bias   [0 : CORE_BIAS_D-1]   ;

reg  signed [CORE_OTFMAP_W-1 : 0] w_prmult_result [0 : CORE_OTFMAP_D-1] ;

// infmap
always @(*) begin
    n_core_infmap = r_core_infmap;
    if(c_infmap_o_ot_valid) begin
        n_core_infmap = c_infmap_o_ot_infmap;
    end else if(c_state[S_MULT_SHIFT]) begin
        n_core_infmap = {{I_F_BW{1'b0}}, r_core_infmap[CORE_INFMAP_W-1 : I_F_BW]};
    end
end
always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_core_infmap <= {CORE_INFMAP_W{1'b0}};
    end else begin
        r_core_infmap <= n_core_infmap;
    end
end

// weight
genvar g_w;
generate
    for (g_w = 0; g_w < CORE_WEIGHT_D; g_w = g_w + 1) begin : gen_core_w
        always @(*) begin
            n_core_weight[g_w] = r_core_weight[g_w];
            if(c_weight_o_ot_valid) begin
                if(g_w == CORE_WEIGHT_D-1) begin
                    n_core_weight[g_w] = c_weight_o_ot_weight;
                end else begin
                    n_core_weight[g_w] = r_core_weight[g_w+1];
                end
            end else if(c_state[S_MULT_SHIFT]) begin
                n_core_weight[g_w] = {{W_BW{1'b0}}, r_core_weight[g_w][CORE_WEIGHT_W-1 : W_BW]};
            end
        end
        always @(posedge clk) begin
            if((areset) || (o_n_ready)) begin
                r_core_weight[g_w] <= {CORE_WEIGHT_W{1'b0}};
            end else begin
                r_core_weight[g_w] <= n_core_weight[g_w];
            end
        end
    end
endgenerate

// otfmap
genvar g_o;
generate
    for (g_o = 0; g_o < CORE_OTFMAP_D; g_o = g_o + 1) begin : gen_core_o
        always @(*) begin
            w_prmult_result[g_o] = {{(CORE_OTFMAP_W - M_BW){c_prmult_o_result[(g_o*M_BW) + (M_BW-1)]}}, 
                c_prmult_o_result[g_o*M_BW +: M_BW]};
            
            n_core_otfmap[g_o] = r_core_otfmap[g_o];
            if(r_update_core_otfmap) begin
                if(g_o == CORE_OTFMAP_D-1) begin
                    n_core_otfmap[g_o] = {CORE_OTFMAP_W{1'b0}};
                end else begin
                    n_core_otfmap[g_o] = r_core_otfmap[g_o+1];
                end
            end else if(c_prmult_o_valid) begin
                n_core_otfmap[g_o] = r_core_otfmap[g_o] + w_prmult_result[g_o];
            end 
        end
        always @(posedge clk) begin
            if((areset) || ((r_scaling) && (o_n_ready))) begin
                r_core_otfmap[g_o] <= {CORE_OTFMAP_W{1'b0}};
            end else begin
                r_core_otfmap[g_o] <= n_core_otfmap[g_o];
            end
        end
    end
endgenerate

// bias
genvar g_b;
generate
    for (g_b = 0; g_b < CORE_BIAS_D; g_b = g_b + 1) begin : gen_core_b
        always @(*) begin
            n_core_bias[g_b] = r_core_bias[g_b];
            if((r_update_core_otfmap) || (c_bias_o_ot_valid)) begin
                if(g_b == CORE_BIAS_D-1) begin
                    n_core_bias[g_b] = (c_bias_o_ot_valid) 
                        ? (c_bias_o_ot_bias) : ({CORE_BIAS_W{1'b0}});
                end else begin
                    n_core_bias[g_b] = r_core_bias[g_b+1];
                end
            end 
        end
        always @(posedge clk) begin
            if((areset) || (o_n_ready)) begin
                r_core_bias[g_b] <= {CORE_BIAS_W{1'b0}};
            end else begin
                r_core_bias[g_b] <= n_core_bias[g_b];
            end
        end
    end
endgenerate

//==============================================================================
// Control Submodule Input Port: rd_b_infmap 
//==============================================================================
assign c_infmap_i_run          = i_run ;
assign c_infmap_i_rd_start_idx = i_infmap_start_idx ;

//==============================================================================
// Control Submodule Input Port: rd_b_weight 
//==============================================================================
assign c_weight_i_run           = i_run ;
assign c_weight_i_rd_start_addr = i_weight_start_addr ;

//==============================================================================
// Control Submodule Input Port: parallel_mult 
//==============================================================================
reg                          r_prmult_i_run ;
wire [MULT_OPS*I_F_BW-1 : 0] w_prmult_i_in0 ;
wire [MULT_OPS*W_BW  -1 : 0] w_prmult_i_in1 ;

generate
    always @(posedge clk) begin
        if((areset) || (r_msft_cnt_done)) begin
            r_prmult_i_run <= 1'b0;
        end else if((c_state[S_RD_IF_W]) && (r_rd_i_w_done)) begin
            r_prmult_i_run <= 1'b1;
        end
    end
endgenerate

genvar g_m;

generate
    for (g_m = 0; g_m < OCH_T; g_m = g_m + 1) begin : gen_in0_ocht
        assign w_prmult_i_in0[g_m*I_F_BW +: I_F_BW] = r_core_infmap[I_F_BW-1 : 0];
        assign w_prmult_i_in1[g_m*W_BW +: W_BW] = r_core_weight[g_m][W_BW-1 : 0];
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
reg  signed [O_F_BW-1 : 0] r_add_bias ;
wire signed [O_F_BW-1 : 0] w_bias_extend ;

assign w_bias_extend = {{(O_F_BW - B_BW - B_SHIFT){r_core_bias[0][B_BW-1]}}, 
    r_core_bias[0], {B_SHIFT{1'b0}}};
    
always @(posedge clk) begin
    if((areset) || (!r_add_bias_cnt_valid)) begin
        r_add_bias <= {O_F_BW{1'b0}};
    end else begin
        r_add_bias <= r_core_otfmap[0] + w_bias_extend;
    end
end

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
wire signed [O_F_BW-1 : 0] w_rounding_otfmap ;
reg  signed [QNT_OTFMAP_BW-1 : 0] r_qnt_otfmap ;

assign w_rounding_otfmap = r_add_bias + ADDED_ROUNDING;
always @(posedge clk) begin
    if((areset) || (!r_add_bias_valid)) begin
        r_qnt_otfmap <= {QNT_OTFMAP_BW{1'b0}};
    end else begin
        r_qnt_otfmap <= w_rounding_otfmap[O_F_BW-1 : M_INV_LOG2];
    end
end

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
reg  signed [I_F_BW-1 : 0] r_clp_otfmap ;
reg  signed [I_F_BW-1 : 0] n_clp_otfmap ;

generate
if(RELU) begin
    always @(*) begin
        n_clp_otfmap = r_clp_otfmap;
        if(r_qnt_otfmap[QNT_OTFMAP_BW-1]) begin
            n_clp_otfmap = {I_F_BW{1'b0}};
        end else if(|(r_qnt_otfmap[QNT_OTFMAP_BW-2 : I_F_BW-1])) begin
            n_clp_otfmap = QNT_MAX;
        end else begin
            n_clp_otfmap = r_qnt_otfmap[I_F_BW-1 : 0];
        end
    end
end else begin
    always @(*) begin
        n_clp_otfmap = r_clp_otfmap;
        if((r_qnt_otfmap[QNT_OTFMAP_BW-1]) && (~&(r_qnt_otfmap[QNT_OTFMAP_BW-2 : I_F_BW-1]))) begin
            n_clp_otfmap = QNT_MIN;
        end else if((~(r_qnt_otfmap[QNT_OTFMAP_BW-1]) && |(r_qnt_otfmap[QNT_OTFMAP_BW-2 : I_F_BW-1]))) begin
            n_clp_otfmap = QNT_MAX;
        end else begin
            n_clp_otfmap = r_qnt_otfmap[I_F_BW-1 : 0];
        end
    end
end
endgenerate
always @(posedge clk) begin
    if((areset) || (!r_qnt_otfmap_valid)) begin
        r_clp_otfmap <= {I_F_BW{1'b0}};
    end else begin
        r_clp_otfmap <= n_clp_otfmap;
    end
end

reg r_clp_otfmap_valid;

always @(posedge clk) begin
    if(areset) begin
        r_clp_otfmap_valid <= 1'b0;
    end else begin
        r_clp_otfmap_valid <= r_qnt_otfmap_valid;
    end 
end

//==============================================================================
//  Scaled otfmap Counter
//==============================================================================
reg  [SCALED_CNT_BW-1 : 0] r_scaled_cnt       ;
reg                        r_scaled_cnt_done  ;
reg                        r_scaled_cnt_valid ;

always @(posedge clk) begin
    if((areset) || (r_scaled_cnt_done)) begin
        r_scaled_cnt <= {SCALED_CNT_BW{1'b0}};
    end else if(r_scaled_cnt_valid) begin
        r_scaled_cnt <= r_scaled_cnt + 1;
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_scaled_cnt_done <= 1'b0;
    end else begin
        r_scaled_cnt_done <= (r_scaled_cnt == SCALED_CNT_MAX-2);
    end
end

always @(posedge clk) begin
    if((areset) || (r_scaled_cnt_done)) begin
        r_scaled_cnt_valid <= 1'b0;
    end else if(r_clp_otfmap_valid) begin
        r_scaled_cnt_valid <= 1'b1;
    end
end

//==============================================================================
//  Scaled otfmap
//==============================================================================
reg  [OCH_T_SCALED_BW-1 : 0] r_scaled ;

always @(posedge clk) begin
    if((areset) || (r_scaled_cnt_done)) begin
        r_scaled <= {OCH_T_SCALED_BW{1'b0}};
    end else if(r_clp_otfmap_valid) begin
        r_scaled <= {r_clp_otfmap, r_scaled[OCH_T_SCALED_BW-1 : I_F_BW]};
    end
end

//==============================================================================
// Control Submodule Input Port: wr_b_fc_scaled 
//==============================================================================
generate
if(!IS_FINAL_LAYER) begin  
    assign c_scaled_i_run         = r_scaled_cnt_done   ;
    assign c_scaled_i_scaled_idx  = r_bias_start_addr   ;
    assign c_scaled_i_ocht_scaled = r_scaled ;
end 
endgenerate

//==============================================================================
// Output Max Otfmap (only IS_FINAL_LAYER) 
//==============================================================================
wire w_scaled_o_ot_done;

reg  [OTFMAP_O_IDX_BW-1 : 0]  r_otfmap_cnt  ;
reg                           r_otfmap_cnt_valid  ;
reg                           r_otfmap_cnt_done  ;

reg                           r_ot_valid          ;
reg  [OCH_T_SCALED_BW-1 : 0]  r_otfmap ;
reg  [OTFMAP_O_IDX_BW-1 : 0]  r_ot_otfmap_idx     ;
reg  signed [I_F_BW-1 : 0]    r_ot_max_otfmap     ;

wire signed [I_F_BW-1 : 0] w_compare_otfmap;

generate
if(!IS_FINAL_LAYER) begin 
    assign w_scaled_o_ot_done = c_scaled_o_ot_done;
end else begin
    // max otfmap counter
    always @(posedge clk) begin
        if((areset) || (r_otfmap_cnt_done)) begin
            r_otfmap_cnt <= {OTFMAP_O_IDX_BW{1'b0}};
        end else if(r_otfmap_cnt_valid) begin
            r_otfmap_cnt <= r_otfmap_cnt + 1;
        end
    end
    
    always @(posedge clk) begin
        if((areset) || (r_otfmap_cnt_done)) begin
            r_otfmap_cnt_valid <= 1'b0;
        end else if(r_scaled_cnt_done) begin
            r_otfmap_cnt_valid <= 1'b1;
        end
    end
    
    always @(posedge clk) begin
        if((areset) || (r_otfmap_cnt_done)) begin
            r_otfmap_cnt_done <= 1'b0;
        end else begin
            r_otfmap_cnt_done <= (r_otfmap_cnt == OCH_T-2);
        end
    end
    
    // output register
    always @(posedge clk) begin
        if(areset) begin
            r_ot_valid <= 1'b0;
        end else begin
            r_ot_valid <= (r_otfmap_cnt_done);
        end
    end
    
    always @(posedge clk) begin
        if(areset) begin
            r_otfmap <= {OCH_T_SCALED_BW{1'b0}};
        end else if(r_scaled_cnt_done) begin
            r_otfmap <= r_scaled;
        end else if(r_otfmap_cnt_valid) begin
            r_otfmap <= {{I_F_BW{1'b0}}, r_otfmap[OCH_T_SCALED_BW-1 : I_F_BW]};
        end
    end
    
    assign w_compare_otfmap = r_otfmap[I_F_BW-1 : 0];
    
    always @(posedge clk) begin
        if((areset) || (r_ot_valid)) begin
            r_ot_otfmap_idx <= {OTFMAP_O_IDX_BW{1'b0}};
        end else if((r_otfmap_cnt_valid) && (w_compare_otfmap > r_ot_max_otfmap)) begin
            r_ot_otfmap_idx <= r_otfmap_cnt ;
        end
    end
       
    always @(posedge clk) begin
        if((areset) || (r_ot_valid)) begin
            r_ot_max_otfmap <= {I_F_BW{1'b0}};
        end else if(r_scaled_cnt_done) begin
            r_ot_max_otfmap <= QNT_MIN;
        end else if((r_otfmap_cnt_valid) && (w_compare_otfmap > r_ot_max_otfmap)) begin
            r_ot_max_otfmap <= w_compare_otfmap ;
        end
    end
    
    assign w_scaled_o_ot_done = r_ot_valid;
end
endgenerate

//==============================================================================
// Output Register: State signal
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
generate
    always @(posedge clk) begin
        if(areset) begin
            r_n_ready <= 1'b0;
        end else begin
            if(!IS_FINAL_LAYER) begin
                r_n_ready <= ((c_state[S_SCALING]) && (c_scaled_o_n_ready)) ||
                    (r_acc_cnt_done) && (~r_scaling);
            end else begin
                r_n_ready <= (r_otfmap_cnt_done) ||
                    ((r_acc_cnt_done) && (~r_scaling));
            end
        end 
    end
endgenerate
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

assign o_en_err  = r_en_err;
assign o_n_ready = r_n_ready;
assign o_ot_done = r_ot_done;

assign o_ot_valid      = r_ot_valid      ;
assign o_ot_otfmap_idx = r_ot_otfmap_idx ;
assign o_ot_max_otfmap = r_ot_max_otfmap ;

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
            n_state = (1 << S_ACC_WAIT); 
        end
        (1 << S_ACC_WAIT ) : if(r_acc_cnt_done_t1) begin 
            if(r_scaling) begin
                n_state = (1 << S_SCALING  ); 
            end else begin
                n_state = (1 << S_DONE  ); 
            end
        end
        (1 << S_SCALING  ) : if(w_scaled_o_ot_done) begin 
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

rd_b_fc_infmap #( 
    .ICH    (ICH    ) ,
    .ICH_B  (ICH_B  ) ,
    .I_F_BW (I_F_BW ) 
) u_rd_b_fc_infmap ( 
    .clk             (clk             ) ,
    .areset          (areset          ) ,
    .i_run           (c_infmap_i_run           ) ,
    .i_rd_start_idx  (c_infmap_i_rd_start_idx  ) ,
    .o_idle          (c_infmap_o_idle          ) ,
    .o_run           (c_infmap_o_run           ) ,
    .o_en_err        (c_infmap_o_en_err        ) ,
    .o_n_ready       (c_infmap_o_n_ready       ) ,
    .o_ot_valid      (c_infmap_o_ot_valid      ) ,
    .o_ot_done       (c_infmap_o_ot_done       ) ,
    .o_ot_infmap     (c_infmap_o_ot_infmap     ) ,
    .b_o_infmap_addr (b_o_infmap_addr ) ,
    .b_o_infmap_ce   (b_o_infmap_ce   ) ,
    .b_o_infmap_we   (b_o_infmap_we   ) ,
    .b_i_infmap_q    (b_i_infmap_q    ) 
);

rd_b_fc_weight #(
    .OCH   (OCH   ) ,
    .ICH   (ICH   ) ,
    .OCH_B (OCH_B ) ,
    .ICH_B (ICH_B ) ,
    .W_BW  (W_BW  ) 
) u_rd_b_fc_weight ( 
    .clk             (clk             ) ,
    .areset          (areset          ) ,
    .i_run           (c_weight_i_run           ) ,
    .i_rd_start_addr (c_weight_i_rd_start_addr ) ,
    .o_idle          (c_weight_o_idle          ) ,
    .o_run           (c_weight_o_run           ) ,
    .o_en_err        (c_weight_o_en_err        ) ,
    .o_n_ready       (c_weight_o_n_ready       ) ,
    .o_ot_valid      (c_weight_o_ot_valid      ) ,
    .o_ot_done       (c_weight_o_ot_done       ) ,
    .o_ot_idx        (c_weight_o_ot_idx        ) ,
    .o_ot_weight     (c_weight_o_ot_weight     ) ,
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
    .i_rd_start_addr (c_bias_i_rd_start_addr ) ,
    .o_idle          (c_bias_o_idle          ) ,
    .o_run           (c_bias_o_run           ) ,
    .o_en_err        (c_bias_o_en_err        ) ,
    .o_n_ready       (c_bias_o_n_ready       ) ,
    .o_ot_valid      (c_bias_o_ot_valid      ) ,
    .o_ot_done       (c_bias_o_ot_done       ) ,
    .o_ot_idx        (c_bias_o_ot_idx        ) ,
    .o_ot_bias       (c_bias_o_ot_bias       ) ,
    .b_o_bias_addr   (b_o_bias_addr   ) ,
    .b_o_bias_ce     (b_o_bias_ce     ) ,
    .b_o_bias_we     (b_o_bias_we     ) ,
    .b_i_bias_q      (b_i_bias_q      ) 
);

generate
if(!IS_FINAL_LAYER) begin
    wr_b_fc_scaled #( 
        .OCH    (OCH    ) ,
        .OCH_B  (OCH_B  ) ,
        .I_F_BW (I_F_BW )
    ) u_wr_b_fc_scaled ( 
        .clk                (clk                ) ,
        .areset             (areset             ) ,
        .i_run              (c_scaled_i_run              ) ,
        .i_scaled_idx       (c_scaled_i_scaled_idx       ) ,
        .i_ocht_scaled      (c_scaled_i_ocht_scaled      ) ,
        .o_idle             (c_scaled_o_idle             ) ,
        .o_run              (c_scaled_o_run              ) ,
        .o_n_ready          (c_scaled_o_n_ready          ) ,
        .o_en_err           (c_scaled_o_en_err           ) ,
        .o_ot_done          (c_scaled_o_ot_done          ) ,
        .b_o_scaled_addr    (b_o_scaled_addr    ) ,
        .b_o_scaled_ce      (b_o_scaled_ce      ) ,
        .b_o_scaled_byte_we (b_o_scaled_byte_we ) ,
        .b_o_scaled_d       (b_o_scaled_d       ) 
    );
end
endgenerate

endmodule