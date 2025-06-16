//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.18
// Design Name: LeNet-5
// Module Name: cnn_conv_layer
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: CNN Convolutional Layer
//                  input : infmap[ICH*IY*IX], 
//                          weight[OCH*ICH*KY*KX],
//                          bias[OCH]
//                  output: (OCH_B * OY * OX) * scaled_otfmap[OCH_T]
//                  otfmap = infmap * weight + bias
//                  latency: 18,962 cycle(avarage: 18,962 cycle), delay = latency
//                          (random seed:5, LOOP_NUM:10)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           1.0(25.03.09) - Major Rivision
//           1.1(25.03.18) - Rivision: Set Start Address
//           1.3(25.04.10) - remove b_otfmap
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"

module cnn_conv_layer #(
    parameter MULT_DELAY    = 3  ,
    parameter ACC_DELAY     = 1  ,
    parameter AB_DELAY      = 1  ,
    parameter ICH           = 6  ,
    parameter OCH           = 16 ,
    parameter KX            = 5  ,
    parameter KY            = 5  ,
    parameter OX            = 10 ,
    parameter OY            = 10 ,
    parameter ICH_B         = 2  ,
    parameter OCH_B         = 4  ,
    parameter OX_B          = 2  ,
    parameter I_F_BW        = 8  ,
    parameter W_BW          = 8  ,
    parameter B_BW          = 16 ,
    parameter PARA_B_BW     = 2  ,
    parameter PARA_T_BW     = 4  ,
    parameter B_SHIFT       = 0  ,
    parameter M_INV         = 512
) (
    clk               ,
    areset            ,
    i_run             ,
    o_idle            ,
    o_run             ,
    o_en_err          ,
    o_n_ready         ,
    o_ot_done         ,
    o_ot_valid        ,
    o_ot_ox_b_idx     ,
    o_ot_ox_t_idx     ,
    o_ot_oy_idx       ,
    o_ot_och_b_idx    ,
    o_ot_och_t_otfmap ,
    b_o_infmap_addr   ,
    b_o_infmap_ce     ,
    b_o_infmap_we     ,
    b_i_infmap_q      ,
    b_o_weight_addr   ,
    b_o_weight_ce     ,
    b_o_weight_we     ,
    b_i_weight_q      ,
    b_o_bias_addr     ,
    b_o_bias_ce       ,
    b_o_bias_we       ,
    b_i_bias_q        
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam IS_ICH_1 = (ICH == 1);

// parameter size in CNN
localparam IX   = OX + KX - 1 ; // 14
localparam IY   = OY + KY - 1 ; // 14

// parameter size in CNN Block
localparam ICH_T  = ICH / ICH_B ; // 3
localparam OCH_T  = OCH / OCH_B ; // 4
localparam OX_T   = OX  / OX_B  ; // 5
localparam IX_T   = OX_T + KX - 1 ; // 9

// parameter bit width
localparam M_BW     = I_F_BW + W_BW; // 16 = I_F_BW + W_BW
localparam ACC_BW   = M_BW + $clog2(ICH_T); // 18; Accum parallel_mult output
localparam O_F_BW   = ACC_BW + $clog2(ICH_B*KY*KX); // 24; Add Kernel 

// BRAM
localparam B_INFMAP_DATA_W  = 32 ;
localparam B_INFMAP_WORD    = B_INFMAP_DATA_W / I_F_BW ; // 4
localparam B_INFMAP_DATA_D  = (ICH * IY * IX) / B_INFMAP_WORD; // 294
localparam B_INFMAP_ADDR_W  = $clog2(B_INFMAP_DATA_D); // 9
localparam B_WEIGHT_DATA_W  = KX * W_BW; // 40
localparam B_WEIGHT_DATA_D  = (OCH * ICH * KY * KX) / KX; // 480
localparam B_WEIGHT_ADDR_W  = $clog2(B_WEIGHT_DATA_D); // 9
localparam B_BIAS_DATA_W    = B_BW ; // 16
localparam B_BIAS_DATA_D    = OCH  ; // 16
localparam B_BIAS_ADDR_W    = $clog2(B_BIAS_DATA_D); // 4

// counter
localparam OX_B_CNT_BW  = $clog2(OX) ; // 1
localparam OY_CNT_BW    = $clog2(OY) ; // 4
localparam ICH_B_CNT_BW = (IS_ICH_1) ? (1) : ($clog2(ICH_B)) ; // 1
localparam OCH_B_CNT_BW = $clog2(OCH_B) ; // 2

// address bit width
localparam ADDR_I_ICH_B_BW = $clog2(ICH_B * ICH_T * IY * IX) ;
localparam ADDR_I_OY_BW    = $clog2(OY * IX) ;
localparam ADDR_I_OX_B_BW  = $clog2(OX_B * OX_T) ;
localparam ADDR_W_OCH_B_BW = $clog2(OCH_B * OCH_T * ICH * KY) ;
localparam ADDR_W_ICH_B_BW = $clog2(ICH_B * ICH_T * KY) ;
localparam ADDR_O_OY_BW    = $clog2(OY * OX) ;
localparam ADDR_O_OX_B_BW  = $clog2(OX_B * OX_T) ;

// index
localparam INFMAP_WORD_BW = $clog2(B_INFMAP_WORD) ; // 2
localparam OX_B_IDX_BW    = $clog2(OX_B) ; // 1
localparam OX_T_IDX_BW    = $clog2(OX_T) ; // 3
localparam OY_IDX_BW      = $clog2(OY) ; // 4
localparam OCH_B_IDX_BW   = $clog2(OCH_B) ; // 2
localparam SCALED_IDX_MAX = OX_T ; // 5
localparam SCALED_IDX_BW  = $clog2(SCALED_IDX_MAX) ; // 3
localparam SCALED_OTFMAP_BW = OCH_T * I_F_BW ; // 32

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
output [OX_B_IDX_BW-1 : 0]      o_ot_ox_b_idx       ;
output [OX_T_IDX_BW-1 : 0]      o_ot_ox_t_idx       ;
output [OY_IDX_BW-1 : 0]        o_ot_oy_idx         ;
output [OCH_B_IDX_BW-1 : 0]     o_ot_och_b_idx      ;
output [SCALED_OTFMAP_BW-1 : 0] o_ot_och_t_otfmap   ;

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

//==============================================================================
// Declaration Submodule Port
//==============================================================================
wire                          c_core_i_run               ;
wire                          c_core_i_scaling           ;
wire                          c_core_o_idle              ;
wire                          c_core_o_run               ;
wire                          c_core_o_en_err            ;
wire                          c_core_o_n_ready           ;
wire                          c_core_o_ot_done           ;
wire [B_INFMAP_ADDR_W-1 : 0]  c_core_i_infmap_start_addr ;
wire [INFMAP_WORD_BW -1 : 0]  c_core_i_infmap_start_word ;
wire [B_WEIGHT_ADDR_W-1 : 0]  c_core_i_weight_start_addr ;
wire [B_BIAS_ADDR_W-1 : 0]    c_core_i_bias_start_addr   ;
wire                          c_core_o_ot_valid          ;
wire [SCALED_IDX_BW-1 : 0]    c_core_o_ot_scaled_idx     ;
wire [SCALED_OTFMAP_BW-1 : 0] c_core_o_ot_scaled_otfmap  ;

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
// Counter: ox_b, oy, ich_b, och_b
//==============================================================================
reg  [ICH_B_CNT_BW-1 : 0] r_ich_b_cnt ;
reg                       r_oy0_cnt   ;
reg  [OX_B_CNT_BW -1 : 0] r_ox_b_cnt  ;
reg  [OY_CNT_BW   -2 : 0] r_oy1_cnt   ;
reg  [OCH_B_CNT_BW-1 : 0] r_och_b_cnt ;

reg  r_ich_b_cnt_done ;
reg  r_oy0_cnt_done   ;
reg  r_ox_b_cnt_done  ;
reg  r_oy1_cnt_done   ;
reg  r_och_b_cnt_done ;
reg  r_all_cnt_done   ;

wire w_counter_update;
assign w_counter_update = c_core_i_run;

wire [OY_CNT_BW-1 : 0] w_oy_cnt;
assign w_oy_cnt = {r_oy1_cnt, r_oy0_cnt};

// counter
generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || ((w_counter_update) && (r_ich_b_cnt_done))) begin
            r_ich_b_cnt <= {ICH_B_CNT_BW{1'b0}};
        end else if (w_counter_update) begin
            r_ich_b_cnt <= r_ich_b_cnt + 1;
        end
    end
end else begin
    always @(posedge clk) begin
        r_ich_b_cnt <= {ICH_B_CNT_BW{1'b0}};
    end
end
endgenerate
always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_oy0_cnt <= 1'b0;
    end else if ((w_counter_update) && (r_ich_b_cnt_done)) begin
        r_oy0_cnt <= ~r_oy0_cnt;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ox_b_cnt_done))) begin
        r_ox_b_cnt <= {OX_B_CNT_BW{1'b0}};
    end else if ((w_counter_update) && (r_oy0_cnt_done)) begin
        r_ox_b_cnt <= r_ox_b_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_oy1_cnt_done))) begin
        r_oy1_cnt <= {(OY_CNT_BW-1){1'b0}};
    end else if ((w_counter_update) && (r_ox_b_cnt_done)) begin
        r_oy1_cnt <= r_oy1_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_och_b_cnt_done))) begin
        r_och_b_cnt <= {OCH_B_CNT_BW{1'b0}};
    end else if ((w_counter_update) && (r_oy1_cnt_done)) begin
        r_och_b_cnt <= r_och_b_cnt + 1;
    end
end

// count done
wire w_oy0_done_update;
generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || ((w_counter_update) && (r_ich_b_cnt_done))) begin
            r_ich_b_cnt_done <= 1'b0;
        end else if((w_counter_update) && (r_ich_b_cnt == ICH_B-2)) begin
            r_ich_b_cnt_done <= 1'b1;
        end
    end
    assign w_oy0_done_update = (w_counter_update) && (r_ich_b_cnt == ICH_B-2) && (r_oy0_cnt);
end else begin
    always @(posedge clk) begin
        if(areset) begin
            r_ich_b_cnt_done <= 1'b1;
        end
    end
    assign w_oy0_done_update = (w_counter_update) && (~r_oy0_cnt);
end
endgenerate
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_oy0_cnt_done))) begin
        r_oy0_cnt_done <= 1'b0;
    end else if(w_oy0_done_update) begin
        r_oy0_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_ox_b_cnt_done))) begin
        r_ox_b_cnt_done <= 1'b0;
    end else if((w_oy0_done_update) && (r_ox_b_cnt == OX_B-1)) begin
        r_ox_b_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_oy1_cnt_done))) begin
        r_oy1_cnt_done <= 1'b0;
    end else if((w_oy0_done_update) && (r_ox_b_cnt == OX_B-1) && 
        (r_oy1_cnt == (OY/2)-1)) begin
        r_oy1_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_counter_update) && (r_och_b_cnt_done))) begin
        r_och_b_cnt_done <= 1'b0;
    end else if((w_oy0_done_update) && (r_ox_b_cnt == OX_B-1) && 
        (r_oy1_cnt == (OY/2)-1) && (r_och_b_cnt == OCH_B-1)) begin
        r_och_b_cnt_done <= 1'b1;
    end
end

always @(posedge clk) begin
    if((areset) || (o_n_ready)) begin
        r_all_cnt_done <= 1'b0;
    end else if((w_counter_update) && (r_och_b_cnt_done)) begin
        r_all_cnt_done <= 1'b1;
    end
end

//==============================================================================
// Counter to Address
//==============================================================================
reg [ADDR_I_ICH_B_BW-1 : 0] r_infmap_ichb ;
reg [ADDR_I_OY_BW   -1 : 0] r_infmap_oy   ;
reg [ADDR_I_OX_B_BW -1 : 0] r_infmap_oxb  ;
reg [ADDR_W_OCH_B_BW-1 : 0] r_weight_ochb ;
reg [ADDR_W_ICH_B_BW-1 : 0] r_weight_ichb ;

always @(posedge clk) begin
    if(areset) begin
        r_infmap_ichb <= {ADDR_I_ICH_B_BW{1'b0}};
        r_infmap_oy   <= {ADDR_I_OY_BW   {1'b0}};
        r_infmap_oxb  <= {ADDR_I_OX_B_BW {1'b0}};
        r_weight_ochb <= {ADDR_W_OCH_B_BW{1'b0}};
        r_weight_ichb <= {ADDR_W_ICH_B_BW{1'b0}};
    end else begin
        r_infmap_ichb <= (r_ich_b_cnt * ICH_T * IY * IX);
        r_infmap_oy   <= (w_oy_cnt * IX);
        r_infmap_oxb  <= (r_ox_b_cnt * OX_T);
        r_weight_ochb <= (r_och_b_cnt * OCH_T * ICH * KY);
        r_weight_ichb <= (r_ich_b_cnt * ICH_T * KY);
    end
end

//==============================================================================
// Set Start Address
//==============================================================================
reg  [(B_INFMAP_ADDR_W+INFMAP_WORD_BW)-1 : 0] r_infmap_start ;
reg  [B_WEIGHT_ADDR_W-1 : 0]                  r_weight_start ;
reg  [B_BIAS_ADDR_W-1 : 0]                    r_bias_start   ;


always @(posedge clk) begin
    if(areset) begin
        r_infmap_start <= {(B_INFMAP_ADDR_W+INFMAP_WORD_BW){1'b0}};
        r_weight_start <= {B_WEIGHT_ADDR_W{1'b0}};
        r_bias_start <= {B_BIAS_ADDR_W{1'b0}};
    end else begin
        r_infmap_start <= r_infmap_ichb + r_infmap_oy + r_infmap_oxb ;
        r_weight_start <= r_weight_ochb + r_weight_ichb ;
        r_bias_start <= r_och_b_cnt * OCH_T;
    end
end

//==============================================================================
// Control Submodule Input Port: cnn_conv_core 
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
        r_core_i_scaling <= (n_core_i_run) && (r_ich_b_cnt_done);
    end
end

assign c_core_i_run               = r_core_i_run       ;
assign c_core_i_scaling           = r_core_i_scaling   ;
assign c_core_i_infmap_start_addr = r_infmap_start[(B_INFMAP_ADDR_W+INFMAP_WORD_BW)-1 : INFMAP_WORD_BW] ;
assign c_core_i_infmap_start_word = r_infmap_start[INFMAP_WORD_BW-1 : 0] ;
assign c_core_i_weight_start_addr = r_weight_start ;
assign c_core_i_bias_start_addr   = r_bias_start   ;

//==============================================================================
// Output Index Counter: ox, oy, och_b 
//==============================================================================
reg  [OX_T_IDX_BW-1 : 0]  r_oxt_idx_cnt   ;
reg                       r_oy0_idx_cnt   ;
reg  [OX_B_IDX_BW-1 : 0]  r_oxb_idx_cnt   ;
reg  [OY_IDX_BW-2 : 0]    r_oy1_idx_cnt   ;
reg  [OCH_B_IDX_BW-1 : 0] r_och_b_idx_cnt ;

reg  r_oxt_idx_cnt_done   ;
reg  r_oy0_idx_cnt_done   ;
reg  r_oxb_idx_cnt_done   ;
reg  r_oy1_idx_cnt_done   ;
reg  r_och_b_idx_cnt_done ;

wire w_ot_idx_update;
assign w_ot_idx_update = c_core_o_ot_valid;

wire [OY_IDX_BW-1 : 0] w_oy_idx_cnt;
assign w_oy_idx_cnt = {r_oy1_idx_cnt, r_oy0_idx_cnt};

// counter
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oxt_idx_cnt_done))) begin
        r_oxt_idx_cnt <= {OX_T_IDX_BW{1'b0}};
    end else if (w_ot_idx_update) begin
        r_oxt_idx_cnt <= r_oxt_idx_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oy0_idx_cnt_done))) begin
        r_oy0_idx_cnt <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt_done)) begin
        r_oy0_idx_cnt <= ~r_oy0_idx_cnt;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oxb_idx_cnt_done))) begin
        r_oxb_idx_cnt <= {OX_B_IDX_BW{1'b0}};
    end else if ((w_ot_idx_update) && (r_oy0_idx_cnt_done)) begin
        r_oxb_idx_cnt <= r_oxb_idx_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oy1_idx_cnt_done))) begin
        r_oy1_idx_cnt <= {(OY_IDX_BW-1){1'b0}};
    end else if ((w_ot_idx_update) && (r_oxb_idx_cnt_done)) begin
        r_oy1_idx_cnt <= r_oy1_idx_cnt + 1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_och_b_idx_cnt_done))) begin
        r_och_b_idx_cnt <= {OCH_B_IDX_BW{1'b0}};
    end else if ((w_ot_idx_update) && (r_oy1_idx_cnt_done)) begin
        r_och_b_idx_cnt <= r_och_b_idx_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oxt_idx_cnt_done))) begin
        r_oxt_idx_cnt_done <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt == OX_T-2)) begin
        r_oxt_idx_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oy0_idx_cnt_done))) begin
        r_oy0_idx_cnt_done <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt == OX_T-2) && (r_oy0_idx_cnt)) begin
        r_oy0_idx_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oxb_idx_cnt_done))) begin
        r_oxb_idx_cnt_done <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt == OX_T-2) && (r_oy0_idx_cnt) &&
        (r_oxb_idx_cnt == OX_B-1)) begin
        r_oxb_idx_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_oy1_idx_cnt_done))) begin
        r_oy1_idx_cnt_done <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt == OX_T-2) && 
        (r_oxb_idx_cnt == OX_B-1) && (w_oy_idx_cnt == OY-1)) begin
        r_oy1_idx_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if((areset) || ((w_ot_idx_update) && (r_och_b_idx_cnt_done))) begin
        r_och_b_idx_cnt_done <= 1'b0;
    end else if((w_ot_idx_update) && (r_oxt_idx_cnt == OX_T-2) && 
        (r_oxb_idx_cnt == OX_B-1) && (w_oy_idx_cnt == OY-1) && (r_och_b_idx_cnt == OCH_B-1)) begin
        r_och_b_idx_cnt_done <= 1'b1;
    end
end

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

assign o_ot_valid        = c_core_o_ot_valid ;
assign o_ot_ox_b_idx     = r_oxb_idx_cnt ;
assign o_ot_ox_t_idx     = r_oxt_idx_cnt ;
assign o_ot_oy_idx       = w_oy_idx_cnt    ;
assign o_ot_och_b_idx    = r_och_b_idx_cnt ;
assign o_ot_och_t_otfmap = c_core_o_ot_scaled_otfmap ;

//==============================================================================
// Instantiation Submodule
//==============================================================================
cnn_conv_core #(
    .MULT_DELAY (MULT_DELAY ) ,
    .ACC_DELAY  (ACC_DELAY  ) ,
    .AB_DELAY   (AB_DELAY   ) ,
    .ICH        (ICH        ) ,
    .OCH        (OCH        ) ,
    .KX         (KX         ) ,
    .KY         (KY         ) ,
    .OX         (OX         ) ,
    .OY         (OY         ) ,
    .ICH_B      (ICH_B      ) ,
    .OCH_B      (OCH_B      ) ,
    .OX_B       (OX_B       ) ,
    .I_F_BW     (I_F_BW     ) ,
    .W_BW       (W_BW       ) ,
    .B_BW       (B_BW       ) ,
    .PARA_B_BW  (PARA_B_BW  ) ,
    .PARA_T_BW  (PARA_T_BW  ) ,
    .B_SHIFT    (B_SHIFT    ) ,
    .M_INV      (M_INV      ) 
) u_cnn_conv_core (
    .clk                 (clk                 ) ,
    .areset              (areset              ) ,
    .i_run               (c_core_i_run               ) ,
    .i_scaling           (c_core_i_scaling           ) ,
    .o_idle              (c_core_o_idle              ) ,
    .o_run               (c_core_o_run               ) ,
    .o_en_err            (c_core_o_en_err            ) ,
    .o_n_ready           (c_core_o_n_ready           ) ,
    .o_ot_done           (c_core_o_ot_done           ) ,
    .i_infmap_start_addr (c_core_i_infmap_start_addr ) ,
    .i_infmap_start_word (c_core_i_infmap_start_word ) ,
    .i_weight_start_addr (c_core_i_weight_start_addr ) ,
    .i_bias_start_addr   (c_core_i_bias_start_addr   ) ,
    .o_ot_valid          (c_core_o_ot_valid          ) ,
    .o_ot_scaled_idx     (c_core_o_ot_scaled_idx     ) ,
    .o_ot_scaled_otfmap  (c_core_o_ot_scaled_otfmap  ) ,
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
    .b_i_bias_q          (b_i_bias_q          ) 
);

endmodule