//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.03.15
// Design Name: LeNet-5
// Module Name: wr_b_pool
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Write Pooling data in BRAM 
//                  input : pool[OX]
//                  latency:  cycle(avarage:  cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           0.1(25.04.18) - delete b_i_pool_q
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module wr_b_pool #( 
    parameter OCH           = 6  ,
    parameter OY            = 14 ,
    parameter OX            = 14 ,
    parameter OCH_B         = 2  ,
    parameter O_F_BW        = 8  
) ( 
    clk              ,
    areset           ,
    i_run            ,
    i_oy_idx         ,
    i_och_idx        ,
    i_ox_pool        ,
    o_idle           ,
    o_run            ,
    o_n_ready        ,
    o_en_err         ,
    o_ot_done        ,
    b_o_pool_addr    ,
    b_o_pool_ce      ,
    b_o_pool_byte_we ,
    b_o_pool_d       
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// parameter size in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 4

// BRAM
localparam B_COL_NUM     = 4  ;
localparam B_COL_BW      = $clog2(B_COL_NUM) ; // 2
localparam B_POOL_DATA_W  = 32 ;
localparam B_POOL_DATA_D  = (OCH * OY * OX) / B_COL_NUM; // 294 = 1176 / 4
localparam B_POOL_ADDR_W  = $clog2(B_POOL_DATA_D); // 9

// counter
localparam OX_CNT_MAX   = OX ; // 14
localparam OX_CNT_BW    = $clog2(OX_CNT_MAX) ; // 4
localparam POOL_CNT_MAX = OCH * OY * OX ; // 1176
localparam POOL_CNT_BW  = $clog2(POOL_CNT_MAX) ; // 11

// index
localparam OY_IDX_MAX    = OY ; // 14
localparam OY_IDX_BW     = $clog2(OY_IDX_MAX) ; // 4
localparam OCH_IDX_MAX   = OCH ; // 6
localparam OCH_IDX_BW    = $clog2(OCH_IDX_MAX) ; // 3

// input data width
localparam OX_POOL_BW = OX * O_F_BW ; // 112

// delay
// localparam MODULE_DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;
input  [OY_IDX_BW-1 : 0]       i_oy_idx          ;
input  [OCH_IDX_BW -1 : 0]     i_och_idx         ;
input  [OX_POOL_BW-1 : 0]      i_ox_pool         ;

output                         o_idle            ;
output                         o_run             ;
output                         o_n_ready         ;
output                         o_en_err          ;
output                         o_ot_done         ;

output [B_POOL_ADDR_W-1 : 0]   b_o_pool_addr     ;
output                         b_o_pool_ce       ;
output [B_COL_NUM-1 : 0]       b_o_pool_byte_we  ;
output [B_POOL_DATA_W-1 : 0]   b_o_pool_d        ;
// input  [B_POOL_DATA_W-1 : 0]   b_i_pool_q        ;

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
reg  [OX_CNT_BW-1   : 0] r_ox_cnt     ;
reg  [POOL_CNT_BW-1 : 0] r_pool_cnt   ;

reg  r_cnt_valid    ;

reg  r_ox_cnt_done  ;

// counter
always @(posedge clk) begin
    if((areset) || (r_ox_cnt_done)) begin
        r_ox_cnt <= OX - 1;
    end else if (r_cnt_valid) begin
        r_ox_cnt <= r_ox_cnt - 1;
    end
end
always @(posedge clk) begin
    if((areset) || (r_ox_cnt_done)) begin
        r_pool_cnt <= {POOL_CNT_BW{1'b0}};
    end else if (i_run) begin
        r_pool_cnt <= (i_och_idx*OY*OX) + (i_oy_idx*OX);
    end else if (r_cnt_valid) begin
        r_pool_cnt <= r_pool_cnt + 1;
    end
end

// valid signal
always @(posedge clk) begin
    if((areset) || (r_ox_cnt_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end
// count done
always @(posedge clk) begin
    if(areset) begin
        r_ox_cnt_done <= 1'b0;
    end else begin
        r_ox_cnt_done <= (r_ox_cnt < 5) && (r_pool_cnt[B_COL_BW-1 : 0] == 2'd3);
    end
end

//==============================================================================
// Capture and Shift ox_pool data
//==============================================================================
reg  [OX_POOL_BW-1 : 0] r_ox_pool  ;

always @(posedge clk) begin
    if(areset) begin
        r_ox_pool <= {OX_POOL_BW{1'b0}};
    end else if(i_run) begin
        r_ox_pool <= i_ox_pool;
    end else if(r_cnt_valid) begin
        r_ox_pool <= {{O_F_BW{1'b0}}, r_ox_pool[OX_POOL_BW-1 : O_F_BW]};
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
// Write Pool Data to BRAM
//==============================================================================
reg  [B_POOL_ADDR_W-1 : 0] r_b_pool_addr ;
reg  [B_COL_NUM-1 : 0]     r_b_pool_we   ;
reg  [B_POOL_DATA_W-1 : 0] r_b_pool_d    ;

reg  [B_COL_NUM-1 : 0]     n_b_pool_we   ;
reg  [B_POOL_DATA_W-1 : 0] n_b_pool_d    ;

always @(*) begin
    n_b_pool_we = {B_COL_BW{1'b0}};
    if(r_i_run_t1) begin
        case (r_pool_cnt[B_COL_BW-1 : 0])
            2'd0 : n_b_pool_we = 4'b1111;
            2'd1 : n_b_pool_we = 4'b1110;
            2'd2 : n_b_pool_we = 4'b1100;
            2'd3 : n_b_pool_we = 4'b1000;
        endcase
    end else if((r_cnt_valid) && (r_pool_cnt[B_COL_BW-1 : 0] == 0)) begin
        if(r_ox_cnt < 4) begin
            case (r_ox_cnt[B_COL_BW-1 : 0])
                2'd0 : n_b_pool_we = 4'b0001;
                2'd1 : n_b_pool_we = 4'b0011;
                2'd2 : n_b_pool_we = 4'b0111;
                2'd3 : n_b_pool_we = 4'b1111;
            endcase   
        end else begin
            n_b_pool_we = 4'b1111;
        end
    end 
end

always @(*) begin
    n_b_pool_d = r_ox_pool[B_POOL_DATA_W-1 : 0];
    if(r_i_run_t1) begin
        case (r_pool_cnt[B_COL_BW-1 : 0])
            2'd1 : n_b_pool_d = {r_ox_pool[(O_F_BW*3)-1 : 0], {(O_F_BW*1){1'b0}}};
            2'd2 : n_b_pool_d = {r_ox_pool[(O_F_BW*2)-1 : 0], {(O_F_BW*2){1'b0}}};
            2'd3 : n_b_pool_d = {r_ox_pool[(O_F_BW*1)-1 : 0], {(O_F_BW*3){1'b0}}};
        endcase
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_b_pool_addr <= {B_POOL_ADDR_W{1'b0}};
        r_b_pool_we   <= {B_COL_BW{1'b0}};
        r_b_pool_d    <= {B_POOL_DATA_W{1'b0}};
    end else begin
        r_b_pool_addr <= r_pool_cnt[POOL_CNT_BW-1 : B_COL_BW];
        r_b_pool_we   <= n_b_pool_we ;
        r_b_pool_d    <= n_b_pool_d  ;
    end
end

assign b_o_pool_addr    = r_b_pool_addr;
assign b_o_pool_ce      = 1'b1;
assign b_o_pool_byte_we = r_b_pool_we ;
assign b_o_pool_d       = r_b_pool_d  ;

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
        r_n_ready <= (r_ox_cnt < 5) && (r_pool_cnt[B_COL_BW-1 : 0] == 2'd3);
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= r_ox_cnt_done;
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;

assign o_n_ready = r_n_ready ;
assign o_en_err  = r_en_err  ;
assign o_ot_done = r_ot_done ;

endmodule