//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.06
// Design Name: LeNet-5
// Module Name: cnn_fc_layer
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: CNN Convolutional Layer
//                  input : infmap[ICH], 
//                          weight[OCH*ICH],
//                          bias[OCH]
//                  output: scaled_otfmap[OCH]
//                  otfmap = infmap * weight + bias
//                  latency:  cycle(avarage:  cycle), delay = latency
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

module cnn_fc_layer #(
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
    clk                ,
    areset             ,
    i_run              ,
    o_idle             ,
    o_run              ,
    o_en_err           ,
    o_n_ready          ,
    o_ot_done          ,
    o_ot_valid         ,
    o_ot_otfmap_idx    ,
    b_o_infmap_addr    ,
    b_o_infmap_ce      ,
    b_o_infmap_we      ,
    b_i_infmap_q       ,
    b_o_weight_addr    ,
    b_o_weight_ce      ,
    b_o_weight_we      ,
    b_i_weight_q       ,
    b_o_bias_addr      ,
    b_o_bias_ce        ,
    b_o_bias_we        ,
    b_i_bias_q         ,
    b_o_scaled_addr    ,
    b_o_scaled_ce      ,
    b_o_scaled_byte_we ,
    b_o_scaled_d       
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// parameter size in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 15
localparam ICH_T  = ICH / ICH_B ; // 10

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
localparam B_SCALED_DATA_W = 32 ;
localparam B_SCALED_DATA_D = $rtoi($ceil(OCH*1.0 / B_COL_NUM*1.0)); // 30
localparam B_SCALED_ADDR_W = $clog2(B_SCALED_DATA_D); // 5

localparam OTFMAP_O_IDX_BW  = $clog2(OCH) ; // 4

// counter
localparam OCH_B_CNT_BW = $clog2(OCH_B) ; // 5
localparam ICH_B_CNT_BW = $clog2(ICH_B) ; // 6

// index
localparam INFMAP_I_IDX_BW   = $clog2(ICH) ; // 9

localparam QNT_MIN = -(1 << (I_F_BW-1)); // -128

// // delay
// localparam DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                           clk                 ;
input                           areset              ;

input                           i_run               ;

output                          o_idle              ;
output                          o_run               ;
output                          o_en_err            ;
output                          o_n_ready           ;
output                          o_ot_done           ;

output                          o_ot_valid          ;
output [OTFMAP_O_IDX_BW-1 : 0]  o_ot_otfmap_idx     ;

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
wire                         c_core_i_run               ;
wire                         c_core_i_scaling           ;
wire [INFMAP_I_IDX_BW-1 : 0] c_core_i_infmap_start_idx  ;
wire [B_WEIGHT_ADDR_W-1 : 0] c_core_i_weight_start_addr ;
wire [B_BIAS_ADDR_W-1 : 0]   c_core_i_bias_start_addr   ;
wire                         c_core_o_idle              ;
wire                         c_core_o_run               ;
wire                         c_core_o_en_err            ;
wire                         c_core_o_n_ready           ;
wire                         c_core_o_ot_done           ;
wire                         c_core_o_ot_valid          ;
wire [OTFMAP_O_IDX_BW-1 : 0] c_core_o_ot_otfmap_idx     ;
wire signed [I_F_BW-1 : 0]   c_core_o_ot_max_otfmap     ;

//==============================================================================
// Capture Input Signal
//==============================================================================
reg  r_run           ;
always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
    end else if(i_run) begin
        r_run <= 1'b1;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
    end 
end

//==============================================================================
// Update Counter 
//==============================================================================
reg  r_counter_update;
wire w_counter_update;

assign w_counter_update = c_core_i_run;

always @(posedge clk) begin
    if(areset) begin
        r_counter_update <= 1'b0;
    end else begin
        r_counter_update <= w_counter_update;
    end
end

//==============================================================================
// Counter: ichb, ochb 
//==============================================================================
reg  [ICH_B_CNT_BW-1 : 0] r_ichb_cnt ;
reg  [OCH_B_CNT_BW-1 : 0] r_ochb_cnt ;

reg  r_ichb_cnt_done ;
reg  r_ochb_cnt_done ;
reg  r_all_cnt_done  ;

// counter
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ichb_cnt_done))) begin
        r_ichb_cnt <= {ICH_B_CNT_BW{1'b0}};
    end else if (w_counter_update) begin
        r_ichb_cnt <= r_ichb_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ochb_cnt_done))) begin
        r_ochb_cnt <= {OCH_B_CNT_BW{1'b0}};
    end else if ((w_counter_update) && (r_ichb_cnt_done)) begin
        r_ochb_cnt <= r_ochb_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ichb_cnt_done))) begin
        r_ichb_cnt_done <= 1'b0;
    end else if((w_counter_update) && (r_ichb_cnt == ICH_B-2)) begin
        r_ichb_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ochb_cnt_done))) begin
        r_ochb_cnt_done <= 1'b0;
    end else if((w_counter_update) && (r_ichb_cnt == ICH_B-2) && (r_ochb_cnt == OCH_B-1)) begin
        r_ochb_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_all_cnt_done <= 1'b0;
    end else if((w_counter_update) && (r_ochb_cnt_done)) begin
        r_all_cnt_done <= 1'b1;
    end
end

//==============================================================================
// Counter to Address
//==============================================================================
wire [INFMAP_I_IDX_BW-1 : 0] w_infmap_ichb ;
wire [B_WEIGHT_ADDR_W-1 : 0] w_weight_ochb ;
wire [B_BIAS_ADDR_W-1 : 0]   w_bias_ochb   ;

assign w_infmap_ichb = (r_ichb_cnt * ICH_T);
assign w_weight_ochb = (r_ochb_cnt * OCH_T * ICH_B);
assign w_bias_ochb   = (r_ochb_cnt * OCH_T);

//==============================================================================
// Set Start Address
//==============================================================================
reg  [INFMAP_I_IDX_BW-1 : 0]  r_infmap_start_idx  ;
reg  [B_WEIGHT_ADDR_W-1 : 0]  r_weight_start_addr ;
reg  [B_BIAS_ADDR_W-1 : 0]    r_bias_start_addr   ;

always @(posedge clk) begin
    if(areset) begin
        r_infmap_start_idx  <= {INFMAP_I_IDX_BW{1'b0}};
        r_weight_start_addr <= {B_WEIGHT_ADDR_W{1'b0}};
        r_bias_start_addr   <= {B_BIAS_ADDR_W{1'b0}};
    end else if(r_counter_update) begin
        r_infmap_start_idx  <= w_infmap_ichb ;
        r_weight_start_addr <= w_weight_ochb + r_ichb_cnt ;
        r_bias_start_addr   <= w_bias_ochb   ;
    end
end

//==============================================================================
// Valid scaling 
//==============================================================================
reg  r_scaling_valid   ;

always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ichb_cnt_done))) begin
        r_scaling_valid <= 1'b0;
    end else if((w_counter_update) && (r_ichb_cnt == ICH_B-2)) begin
        r_scaling_valid <= 1'b1;
    end
end

//==============================================================================
// Control Submodule Input Port: cnn_fc_core 
//==============================================================================
reg  r_core_i_run       ;
reg  r_core_i_scaling   ;

wire n_core_i_run ;
assign n_core_i_run = (i_run) || ((c_core_o_n_ready) && (~r_all_cnt_done));

always @(posedge clk) begin
    if(areset) begin
        r_core_i_run <= 1'b0;
    end else begin
        r_core_i_run <= n_core_i_run;
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_core_i_scaling <= 1'b0;
    end else begin
        r_core_i_scaling <= (n_core_i_run) && (r_scaling_valid);
    end
end

assign c_core_i_run               = r_core_i_run       ;
assign c_core_i_scaling           = r_core_i_scaling   ;
assign c_core_i_infmap_start_idx  = r_infmap_start_idx   ;
assign c_core_i_weight_start_addr = r_weight_start_addr  ;
assign c_core_i_bias_start_addr   = r_bias_start_addr    ;

//==============================================================================
// Output Max Otfmap Index (only IS_FINAL_LAYER) 
//==============================================================================
reg  signed [I_F_BW-1 : 0] r_max_otfmap      ;
reg [OTFMAP_O_IDX_BW-1 : 0] r_otfmap_idx     ;
reg [OTFMAP_O_IDX_BW-1 : 0] r_otfmap_idx_cnt ;

generate
if(IS_FINAL_LAYER) begin
    always @(posedge clk) begin
        if((areset) || (o_n_ready)) begin
            r_max_otfmap <= QNT_MIN; 
            r_otfmap_idx <= {OTFMAP_O_IDX_BW{1'b1}}; // 4'b1111
            r_otfmap_idx_cnt <= {OTFMAP_O_IDX_BW{1'b0}};
        end else if((c_core_o_ot_valid) && (c_core_o_ot_max_otfmap > r_max_otfmap)) begin
            r_max_otfmap <= c_core_o_ot_max_otfmap;
            r_otfmap_idx <= c_core_o_ot_otfmap_idx + r_otfmap_idx_cnt;
            r_otfmap_idx_cnt <= r_otfmap_idx_cnt + OCH_T;
        end
    end
end
endgenerate

//==============================================================================
// Output State signal
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
always @(posedge clk) begin
    if(areset) begin
        r_n_ready <= 1'b0;
    end else begin
        r_n_ready <= (c_core_o_n_ready) && (r_all_cnt_done);
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
assign o_idle = !r_run;
assign o_run  = r_run;
assign o_en_err  = r_en_err  ;
assign o_n_ready = r_n_ready ;
assign o_ot_done = r_ot_done ;

assign o_ot_valid      = r_n_ready ;
assign o_ot_otfmap_idx = r_otfmap_idx ;

//==============================================================================
// Instantiation Submodule
//==============================================================================
cnn_fc_core #(
    .MULT_DELAY     (MULT_DELAY     ) ,
    .ACC_DELAY      (ACC_DELAY      ) ,
    .AB_DELAY       (AB_DELAY       ) ,
    .OCH            (OCH            ) ,
    .ICH            (ICH            ) ,
    .OCH_B          (OCH_B          ) ,
    .ICH_B          (ICH_B          ) ,
    .I_F_BW         (I_F_BW         ) ,
    .W_BW           (W_BW           ) ,
    .B_BW           (B_BW           ) ,
    .PARA_B_BW      (PARA_B_BW      ) ,
    .PARA_T_BW      (PARA_T_BW      ) ,
    .M_INV          (M_INV          ) ,
    .B_SCALE        (B_SCALE        ) ,
    .RELU           (RELU           ) ,
    .IS_FINAL_LAYER (IS_FINAL_LAYER ) 
) u_cnn_fc_core (
    .clk                 (clk                 ) ,
    .areset              (areset              ) ,
    .i_run               (c_core_i_run               ) ,
    .i_scaling           (c_core_i_scaling           ) ,
    .i_infmap_start_idx  (c_core_i_infmap_start_idx  ) ,
    .i_weight_start_addr (c_core_i_weight_start_addr ) ,
    .i_bias_start_addr   (c_core_i_bias_start_addr   ) ,
    .o_idle              (c_core_o_idle              ) ,
    .o_run               (c_core_o_run               ) ,
    .o_en_err            (c_core_o_en_err            ) ,
    .o_n_ready           (c_core_o_n_ready           ) ,
    .o_ot_done           (c_core_o_ot_done           ) ,
    .o_ot_valid          (c_core_o_ot_valid          ) ,
    .o_ot_otfmap_idx     (c_core_o_ot_otfmap_idx     ) ,
    .o_ot_max_otfmap     (c_core_o_ot_max_otfmap     ) ,
    .b_o_infmap_addr     (b_o_infmap_addr     ) ,
    .b_o_infmap_ce       (b_o_infmap_ce       ) ,
    .b_o_infmap_we       (b_o_infmap_we       ) ,
    .b_i_infmap_q        (b_i_infmap_q        ) ,
    .b_o_weight_addr     (b_o_weight_addr     ) ,
    .b_o_weight_ce       (b_o_weight_ce       ) ,
    .b_o_weight_we       (b_o_weight_we       ) ,
    .b_i_weight_q        (b_i_weight_q        ) ,
    .b_o_bias_addr       (b_o_bias_addr       ) ,
    .b_o_bias_ce         (b_o_bias_ce         ) ,
    .b_o_bias_we         (b_o_bias_we         ) ,
    .b_i_bias_q          (b_i_bias_q          ) ,
    .b_o_scaled_addr     (b_o_scaled_addr     ) ,
    .b_o_scaled_ce       (b_o_scaled_ce       ) ,
    .b_o_scaled_byte_we  (b_o_scaled_byte_we  ) ,
    .b_o_scaled_d        (b_o_scaled_d        ) 
);

endmodule