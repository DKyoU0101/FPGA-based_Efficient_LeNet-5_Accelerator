//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.09
// Design Name: LeNet-5
// Module Name: mem_copy
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: BRAM Memory Copy 
//                  input : rd_start_idx
//                  output: infmap[ICH_T]
//                  latency:  cycle(avarage:  cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module mem_copy #( 
    parameter DATA_NUM      = 400,
    parameter I_F_BW        = 8   
) ( 
    clk             ,
    areset          ,
    i_run           ,
    o_idle          ,
    o_run           ,
    o_en_err        ,
    o_n_ready       ,
    o_ot_done       ,
    b_o_infmap_addr ,
    b_o_infmap_ce   ,
    b_i_infmap_q    ,
    b_o_otfmap_addr ,
    b_o_otfmap_ce   ,
    b_o_otfmap_we   ,
    b_o_otfmap_d    
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// BRAM
localparam B_COL_NUM        = 32 / I_F_BW ; // 4
localparam B_COL_BW         = $clog2(B_COL_NUM) ; // 2
localparam B_INFMAP_DATA_W  = 32 ;
localparam B_INFMAP_DATA_D  = $rtoi($ceil(DATA_NUM*1.0 / B_COL_NUM*1.0)); // 100
localparam B_INFMAP_ADDR_W  = $clog2(B_INFMAP_DATA_D); // 7

// counter
localparam ADDR_CNT_BW  = B_INFMAP_ADDR_W ; // 7

// delay
// localparam DELAY = ; // 12

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;

output                         o_idle            ;
output                         o_run             ;
output                         o_en_err          ;
output                         o_n_ready         ;
output                         o_ot_done         ;

output [B_INFMAP_ADDR_W-1 : 0] b_o_infmap_addr   ;
output                         b_o_infmap_ce     ;
// output                         b_o_infmap_we     ; // not using write bram
// output [B_INFMAP_DATA_W-1 : 0] b_o_infmap_d      ; // not using write bram
input  [B_INFMAP_DATA_W-1 : 0] b_i_infmap_q      ;

output [B_INFMAP_ADDR_W-1 : 0] b_o_otfmap_addr   ;
output                         b_o_otfmap_ce     ;
output                         b_o_otfmap_we     ;
output [B_INFMAP_DATA_W-1 : 0] b_o_otfmap_d      ; 
// input  [B_INFMAP_DATA_W-1 : 0] b_i_otfmap_q      ; // not using read bram

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
reg  [ADDR_CNT_BW-1 : 0] r_addr_cnt        ;
reg  r_addr_cnt_done ;
reg  r_cnt_valid    ;

reg  r_addr_cnt_done_t1 ;
reg  r_cnt_valid_t1    ;

// counter
always @(posedge clk) begin
    if((areset) || (r_addr_cnt_done)) begin
        r_addr_cnt <= {ADDR_CNT_BW{1'b0}};
    end else if (r_cnt_valid) begin
        r_addr_cnt <= r_addr_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || (r_addr_cnt_done)) begin
        r_addr_cnt_done <= 1'b0;
    end else begin
        r_addr_cnt_done <= (r_addr_cnt == B_INFMAP_DATA_D-2); 
    end
end

// valid signal
always @(posedge clk) begin
    if((areset) || (r_addr_cnt_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end

// shift counter
always @(posedge clk) begin
    if(areset) begin
        r_addr_cnt_done_t1 <= 1'b0;
        r_cnt_valid_t1     <= 1'b0;
    end else begin
        r_addr_cnt_done_t1 <= r_addr_cnt_done; 
        r_cnt_valid_t1     <= r_cnt_valid; 
    end
end

//==============================================================================
// Read infmap Data in BRAM
//==============================================================================
reg  [B_INFMAP_ADDR_W-1 : 0] r_rd_addr;

always @(posedge clk) begin
    if((areset) || (r_addr_cnt_done)) begin
        r_rd_addr <= {B_INFMAP_ADDR_W{1'b0}};
    end else if(r_cnt_valid) begin
        r_rd_addr <= r_rd_addr + 1;
    end
end

assign b_o_infmap_addr = r_rd_addr;
assign b_o_infmap_ce   = 1'b1;

//==============================================================================
// Write otfmap Data to BRAM
//==============================================================================
reg  [B_INFMAP_ADDR_W-1 : 0] r_wr_addr;

always @(posedge clk) begin
    if((areset) || (r_addr_cnt_done_t1)) begin
        r_wr_addr <= {B_INFMAP_ADDR_W{1'b0}};
    end else if(r_cnt_valid_t1) begin
        r_wr_addr <= r_wr_addr + 1;
    end
end

assign b_o_otfmap_addr = r_wr_addr;
assign b_o_otfmap_ce   = 1'b1;
assign b_o_otfmap_we   = r_cnt_valid_t1; 
assign b_o_otfmap_d    = b_i_infmap_q;


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
        r_n_ready <= r_addr_cnt_done_t1;
    end 
end
// reg  r_ot_valid       ;
// always @(posedge clk) begin
//     if(areset) begin
//         r_ot_valid <= 1'b0;
//     end else begin
//         r_ot_valid <= r_n_ready;
//     end 
// end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= r_n_ready;
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;

assign o_en_err   = r_en_err   ;
assign o_n_ready  = r_n_ready  ;
// assign o_ot_valid = r_ot_valid ;
assign o_ot_done  = r_ot_done  ;

endmodule