//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.10
// Design Name: LeNet-5
// Module Name: rd_b_bias
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Read bias in BRAM 
//                  input : rd_start_addr
//                  output: (ocht) * bias
//                  latency: 6 cycle(avarage: 6 cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision 0.01 - pipeline unroll : oxt, ocht, icht, kx
//          1.0(25.03.05) - Major Rivision
//          1.1(25.03.06) - reset_n -> areset
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module rd_b_bias #( 
    parameter OCH           = 16 ,
    parameter OCH_B         = 4  ,
    parameter B_BW          = 16  
) ( 
    clk             ,
    areset          ,
    i_run           ,
    o_idle          ,
    o_run           ,
    o_n_ready       ,
    o_en_err        ,
    i_rd_start_addr ,
    o_ot_idx        ,
    o_ot_bias       ,
    o_ot_valid      ,
    o_ot_done       ,
    b_o_bias_addr   ,
    b_o_bias_ce     ,
    b_o_bias_we     ,
    b_i_bias_q      
);
// `include "defines_parameter.vh"

//==============================================================================
// Local Parameter declaration
//==============================================================================
// Do NOT Change KX, KY, I_F_BW Value

// parameter size in CNN

// parameter size in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 4

// BRAM
localparam B_BIAS_DATA_W  = B_BW ; //16
localparam B_BIAS_DATA_D  = OCH ; // 16
localparam B_BIAS_ADDR_W  = $clog2(B_BIAS_DATA_D); // 4

// counter
localparam OCH_T_CNT_MAX = OCH_T; // 4
localparam OCH_T_CNT_BW  = $clog2(OCH_T_CNT_MAX) ; // 2

// next read address
localparam RD_ADDR_OCH_T = 1 ;

// index
localparam BIAS_IDX_MAX  = OCH_T; // 4
localparam BIAS_IDX_BW   = $clog2(BIAS_IDX_MAX) ; // 2

// delay
localparam DELAY = 1 + BIAS_IDX_MAX + 1; // 6

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;

output                         o_idle            ;
output                         o_run             ;
output                         o_n_ready         ;
output                         o_en_err          ;

input  [B_BIAS_ADDR_W-1 : 0]   i_rd_start_addr   ;

output [BIAS_IDX_BW-1 : 0]     o_ot_idx          ;
output [B_BIAS_DATA_W-1 : 0]   o_ot_bias         ;

output                         o_ot_valid        ;
output                         o_ot_done         ;

output [B_BIAS_ADDR_W-1 : 0]   b_o_bias_addr   ;
output                         b_o_bias_ce     ;
output                         b_o_bias_we     ;
// output [B_BIAS_DATA_W-1 : 0]   b_o_bias_d      ; // not using write bram
input  [B_BIAS_DATA_W-1 : 0]   b_i_bias_q      ;

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
// Count BRAM Address
//==============================================================================
reg  [OCH_T_CNT_BW-1 : 0] r_och_t_cnt        ;
reg  r_rd_done       ;
reg  r_cnt_valid    ;

// counter
always @(posedge clk) begin
    if((areset) || (r_rd_done)) begin
        r_och_t_cnt <= {OCH_T_CNT_BW{1'b0}};
    end else if (r_cnt_valid) begin
        r_och_t_cnt <= r_och_t_cnt + 1;
    end
end

// read done
always @(posedge clk) begin
    if(areset) begin
        r_rd_done <= 1'b0;
    end else begin
        r_rd_done <= (r_och_t_cnt == OCH_T_CNT_MAX-2);
    end
end

// valid signal
always @(posedge clk) begin
    if((areset) || (r_rd_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end

//==============================================================================
// Read bias Data in BRAM
//==============================================================================
reg  [B_BIAS_ADDR_W-1 : 0] r_rd_addr;
always @(posedge clk) begin
    if((areset) || (r_rd_done)) begin
        r_rd_addr <= {B_BIAS_ADDR_W{1'b0}};
    end else if(i_run) begin 
        r_rd_addr <= i_rd_start_addr;
    end else if(r_cnt_valid) begin
        r_rd_addr <= r_rd_addr + RD_ADDR_OCH_T;
    end
end

assign b_o_bias_addr = r_rd_addr;
assign b_o_bias_ce   = 1'b1;
assign b_o_bias_we   = 1'b0; // only read

//==============================================================================
// Count ot_idx
//==============================================================================
reg  [BIAS_IDX_BW-1 : 0]  r_ot_idx        ;
always @(posedge clk) begin
    if((areset) || (o_ot_done)) begin
        r_ot_idx <= {BIAS_IDX_BW{1'b0}};
    end else begin
        r_ot_idx <= r_och_t_cnt;
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
// reg  r_n_ready        ;
// always @(posedge clk) begin
//     if(areset) begin
//         r_n_ready <= 1'b0;
//     end else begin
//         r_n_ready <= (!r_cnt_valid) & (r_cnt_valid_t1);
//     end 
// end
reg  r_ot_valid       ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_valid <= 1'b0;
    end else begin
        r_ot_valid <= r_cnt_valid;
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= r_rd_done;
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;
assign o_n_ready = r_rd_done;
assign o_en_err  = r_en_err;

assign o_ot_idx     = r_ot_idx    ;
assign o_ot_bias    = (b_i_bias_q) & ({B_BIAS_DATA_W{r_ot_valid}}) ;

assign o_ot_valid   = r_ot_valid  ;
assign o_ot_done    = r_ot_done   ;

endmodule