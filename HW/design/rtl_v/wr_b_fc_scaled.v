//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.05
// Design Name: LeNet-5
// Module Name: wr_b_fc_scaled
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Write Pooling data in BRAM 
//                  input : scaled[OCH_T]
//                  latency:  cycle(avarage:  cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           0.1(25.04.18) - delete b_i_scaled_q
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module wr_b_fc_scaled #( 
    parameter OCH           = 120 ,
    parameter OCH_B         = 8   ,
    parameter I_F_BW        = 8   
) ( 
    clk                ,
    areset             ,
    i_run              ,
    i_scaled_idx       ,
    i_ocht_scaled      ,
    o_idle             ,
    o_run              ,
    o_n_ready          ,
    o_en_err           ,
    o_ot_done          ,
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

// BRAM
localparam B_COL_NUM       = 4  ;
localparam B_COL_BW        = $clog2(B_COL_NUM) ; // 2
localparam B_SCALED_DATA_W = 32 ;
localparam B_SCALED_DATA_D = $rtoi($ceil(OCH*1.0 / B_COL_NUM*1.0)); // 30
localparam B_SCALED_ADDR_W = $clog2(B_SCALED_DATA_D); // 5

// counter
localparam OCH_T_CNT_BW   = $clog2(OCH_T) ; // 4
localparam SCALED_CNT_MAX = OCH ; // 120
localparam SCALED_CNT_BW  = $clog2(SCALED_CNT_MAX) ; // 7

// index
localparam SCALED_I_IDX_BW = $clog2(OCH) ; // 7

// input data width
localparam OCH_T_SCALED_BW = OCH_T * I_F_BW ; // 120

// delay
// localparam MODULE_DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk                 ;
input                          areset              ;

input                          i_run               ;
input  [SCALED_I_IDX_BW-1 : 0] i_scaled_idx        ;
input  [OCH_T_SCALED_BW-1 : 0] i_ocht_scaled       ;

output                         o_idle              ;
output                         o_run               ;
output                         o_n_ready           ;
output                         o_en_err            ;
output                         o_ot_done           ;

output [B_SCALED_ADDR_W-1 : 0] b_o_scaled_addr     ;
output                         b_o_scaled_ce       ;
output [B_COL_NUM-1 : 0]       b_o_scaled_byte_we  ;
output [B_SCALED_DATA_W-1 : 0] b_o_scaled_d        ;
// input  [B_SCALED_DATA_W-1 : 0]  b_i_scaled_q        ; // not using read bram

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
// Counter
//==============================================================================
reg  [OCH_T_CNT_BW-1 : 0]  r_ocht_cnt     ;
reg  [SCALED_CNT_BW-1 : 0] r_scaled_cnt   ;

reg  r_cnt_done  ;

reg  r_cnt_valid    ;

// counter
always @(posedge clk) begin
    if((areset) || (r_cnt_done)) begin
        r_ocht_cnt <= OCH_T - 1;
    end else if (r_cnt_valid) begin
        r_ocht_cnt <= r_ocht_cnt - 1;
    end
end
always @(posedge clk) begin
    if((areset) || (r_cnt_done)) begin
        r_scaled_cnt <= {SCALED_CNT_BW{1'b0}};
    end else if (i_run) begin
        r_scaled_cnt <= i_scaled_idx;
    end else if (r_cnt_valid) begin
        r_scaled_cnt <= r_scaled_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if(areset) begin
        r_cnt_done <= 1'b0;
    end else begin
        r_cnt_done <= (r_ocht_cnt < 5) && (r_scaled_cnt[B_COL_BW-1 : 0] == 2'd3);
    end
end

// valid signal
always @(posedge clk) begin
    if((areset) || (r_cnt_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end

//==============================================================================
// Capture and Shift ocht_scaled data
//==============================================================================
reg  [OCH_T_SCALED_BW-1 : 0] r_ocht_scaled  ;

always @(posedge clk) begin
    if(areset) begin
        r_ocht_scaled <= {OCH_T_SCALED_BW{1'b0}};
    end else if(i_run) begin
        r_ocht_scaled <= i_ocht_scaled;
    end else if(r_cnt_valid) begin
        r_ocht_scaled <= {{I_F_BW{1'b0}}, r_ocht_scaled[OCH_T_SCALED_BW-1 : I_F_BW]};
    end 
end

//==============================================================================
// Shift i_run
//==============================================================================
reg  r_i_run_t1     ;

always @(posedge clk) begin
    if(areset) begin
        r_i_run_t1 <= 1'b0;
    end else begin
        r_i_run_t1 <= i_run;
    end
end

//==============================================================================
// Write Scaled Data to BRAM
//==============================================================================
reg  [B_SCALED_ADDR_W-1 : 0] r_b_scaled_addr ;
reg  [B_COL_NUM-1 : 0]       r_b_scaled_we   ;
reg  [B_SCALED_DATA_W-1 : 0] r_b_scaled_d    ;

reg  [B_COL_NUM-1 : 0]       n_b_scaled_we   ;
reg  [B_SCALED_DATA_W-1 : 0] n_b_scaled_d    ;

always @(*) begin
    n_b_scaled_we = {B_COL_BW{1'b0}};
    if(r_i_run_t1) begin
        case (r_scaled_cnt[B_COL_BW-1 : 0])
            2'd0 : n_b_scaled_we = 4'b1111;
            2'd1 : n_b_scaled_we = 4'b1110;
            2'd2 : n_b_scaled_we = 4'b1100;
            2'd3 : n_b_scaled_we = 4'b1000;
        endcase
    end else if((r_cnt_valid) && (r_scaled_cnt[B_COL_BW-1 : 0] == 0)) begin
        if(r_ocht_cnt < 4) begin
            case (r_ocht_cnt[B_COL_BW-1 : 0])
                2'd0 : n_b_scaled_we = 4'b0001;
                2'd1 : n_b_scaled_we = 4'b0011;
                2'd2 : n_b_scaled_we = 4'b0111;
                2'd3 : n_b_scaled_we = 4'b1111;
            endcase   
        end else begin
            n_b_scaled_we = 4'b1111;
        end
    end 
end

always @(*) begin
    n_b_scaled_d = r_ocht_scaled[B_SCALED_DATA_W-1 : 0];
    if(r_i_run_t1) begin
        case (r_scaled_cnt[B_COL_BW-1 : 0])
            2'd1 : n_b_scaled_d = {r_ocht_scaled[(I_F_BW*3)-1 : 0], {(I_F_BW*1){1'b0}}};
            2'd2 : n_b_scaled_d = {r_ocht_scaled[(I_F_BW*2)-1 : 0], {(I_F_BW*2){1'b0}}};
            2'd3 : n_b_scaled_d = {r_ocht_scaled[(I_F_BW*1)-1 : 0], {(I_F_BW*3){1'b0}}};
        endcase
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_b_scaled_addr <= {B_SCALED_ADDR_W{1'b0}};
        r_b_scaled_we   <= {B_COL_BW{1'b0}};
        r_b_scaled_d    <= {B_SCALED_DATA_W{1'b0}};
    end else begin
        r_b_scaled_addr <= r_scaled_cnt[SCALED_CNT_BW-1 : B_COL_BW];
        r_b_scaled_we   <= n_b_scaled_we ;
        r_b_scaled_d    <= n_b_scaled_d  ;
    end
end

assign b_o_scaled_addr    = r_b_scaled_addr;
assign b_o_scaled_ce      = 1'b1;
assign b_o_scaled_byte_we = r_b_scaled_we ;
assign b_o_scaled_d       = r_b_scaled_d  ;

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
        r_n_ready <= (r_ocht_cnt < 5) && (r_scaled_cnt[B_COL_BW-1 : 0] == 2'd3);
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= r_cnt_done;
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;

assign o_n_ready = r_n_ready ;
assign o_en_err  = r_en_err  ;
assign o_ot_done = r_ot_done ;

endmodule