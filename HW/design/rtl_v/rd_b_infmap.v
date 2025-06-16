//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.01.25
// Design Name: LeNet-5
// Module Name: rd_b_infmap
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Read input feature map in BRAM 
//                  input : rd_start_addr
//                  output: (icht) * infmap[ixt]
//                  latency: 12 cycle(avarage: 12 cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision 0.01 - File Created
//          1.0(25.02.01) - pipeline unroll : oxt, ocht, icht, kx
//          1.1(25.03.06) - reset_n -> areset
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module rd_b_infmap #( 
    parameter ICH           = 6  ,
    parameter KX            = 5  ,
    parameter KY            = 5  ,
    parameter OX            = 10 ,
    parameter OY            = 10 ,
    parameter ICH_B         = 2  ,
    parameter OX_B          = 2  ,
    parameter OY_B          = 2  ,
    parameter I_F_BW        = 8  
) ( 
    clk             ,
    areset          ,
    i_run           ,
    o_idle          ,
    o_run           ,
    o_n_ready       ,
    o_en_err        ,
    i_rd_start_addr ,
    i_rd_start_word ,
    o_ot_idx        ,
    o_ot_infmap     ,
    o_ot_valid      ,
    o_ot_done       ,
    b_o_infmap_addr ,
    b_o_infmap_ce   ,
    b_o_infmap_we   ,
    b_i_infmap_q    
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
localparam OX_T   = OX  / OX_B ; // 5
localparam OY_T   = OY  / OY_B ; // 5
localparam IX_T   = OX_T + KX - 1 ; // 9
localparam IY_T   = OY_T + KY - 1 ; // 9

// BRAM
localparam B_INFMAP_DATA_W  = 32 ;
localparam B_INFMAP_WORD    = B_INFMAP_DATA_W / I_F_BW ; // 4
localparam B_INFMAP_DATA_D  = (ICH * IY * IX) / B_INFMAP_WORD; // 294
localparam B_INFMAP_ADDR_W  = $clog2(B_INFMAP_DATA_D); // 9

// counter
localparam IX_T_CNT_MAX  = (IX_T / B_INFMAP_WORD) + 1 ; // 3
localparam IX_T_CNT_BW   = $clog2(IX_T_CNT_MAX) ; // 2
localparam ICH_T_CNT_MAX = ICH_T; // 3
localparam ICH_T_CNT_BW  = $clog2(ICH_T_CNT_MAX) ; // 2
localparam WORD_CNT_MAX  = IX_T; // 9
localparam WORD_CNT_BW   = $clog2(WORD_CNT_MAX) ; // 4

// ixt counter state
localparam S_IXT_IDLE   = 0;
localparam S_IXT_FIRST  = 1;
localparam S_IXT_MIDDLE = 2;
localparam S_IXT_LAST   = 3;
localparam STATE_IXT_BIT = 2;

// rd BRAM ixt num
localparam RD = IX_T % B_INFMAP_WORD; //

// next read address
localparam RD_ADDR_IX_T  = 1 ;
// localparam RD_ADDR_ICH_T = (IY * IX / B_INFMAP_WORD) - (RD_ADDR_IX_T * (IX_T_CNT_MAX-1)) ; // 49 - 2

// index
localparam INFMAP_WORD_MAX = B_INFMAP_WORD ; // 4
localparam INFMAP_WORD_BW = $clog2(INFMAP_WORD_MAX) ; // 2
localparam INFMAP_IDX_MAX = ICH_T; // 3
localparam INFMAP_IDX_BW  = (!IS_ICH_1) ? ($clog2(INFMAP_IDX_MAX)) : (1) ; // 2

// delay
localparam DELAY = INFMAP_IDX_MAX*IX_T_CNT_MAX + 3; // 12

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

input  [B_INFMAP_ADDR_W-1 : 0] i_rd_start_addr   ;
input  [INFMAP_WORD_BW-1 : 0]  i_rd_start_word   ;

output [INFMAP_IDX_BW-1 : 0]   o_ot_idx          ;
output [(IX_T*I_F_BW)-1   : 0] o_ot_infmap       ;

output                         o_ot_valid        ;
output                         o_ot_done         ;

output [B_INFMAP_ADDR_W-1 : 0] b_o_infmap_addr   ;
output                         b_o_infmap_ce     ;
output                         b_o_infmap_we     ;
// output [B_INFMAP_DATA_W-1 : 0] b_o_infmap_d      ; // not using write bram
input  [B_INFMAP_DATA_W-1 : 0] b_i_infmap_q      ;

//==============================================================================
// Capture Input Signal
//==============================================================================
reg  r_run           ;
reg  [INFMAP_WORD_BW-1 : 0] r_rd_start_word ;

always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
        r_rd_start_word <= {INFMAP_WORD_BW{1'b0}};
    end else if(i_run) begin
        r_run <= 1'b1;
        r_rd_start_word <= i_rd_start_word;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
        r_rd_start_word <= {INFMAP_WORD_BW{1'b0}};
    end 
end

//==============================================================================
// Maximum ixt Counter
//==============================================================================
reg  [IX_T_CNT_BW-1 : 0] r_ixt_cnt_max ;

always @(posedge clk) begin
    if(areset) begin
        r_ixt_cnt_max <= {IX_T_CNT_BW{1'b0}};
    end else if(i_run) begin
        r_ixt_cnt_max <= ((IX_T - 1 - (4 - i_rd_start_word)) >> INFMAP_WORD_BW) + 1;
    end else if(o_ot_done) begin
        r_ixt_cnt_max <= {IX_T_CNT_BW{1'b0}};
    end 
end

//==============================================================================
// Count BRAM Address
//==============================================================================
reg  [IX_T_CNT_BW-1  : 0] r_ixt_cnt         ;
reg  [ICH_T_CNT_BW-1 : 0] r_icht_cnt        ;

reg  r_ixt_cnt_done  ;
reg  r_icht_cnt_done ;

reg  r_cnt_valid    ;

// counter
always @(posedge clk) begin
    if((areset) || (r_ixt_cnt_done)) begin
        r_ixt_cnt <= 0;
    end else if (r_cnt_valid) begin
        r_ixt_cnt <= r_ixt_cnt + 1;
    end
end
generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || (r_icht_cnt_done)) begin
            r_icht_cnt <= {ICH_T_CNT_BW{1'b0}};
        end else if (r_ixt_cnt_done) begin
            r_icht_cnt <= r_icht_cnt + 1;
        end
    end
end
endgenerate

// count done
always @(posedge clk) begin
    if((areset) || (r_ixt_cnt_done)) begin
        r_ixt_cnt_done <= 1'b0;
    end else begin
        r_ixt_cnt_done <= (r_ixt_cnt == r_ixt_cnt_max-1); // not r_ixt_cnt_max-2
    end
end
generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || (r_icht_cnt_done)) begin
            r_icht_cnt_done <= 1'b0;
        end else if((r_icht_cnt == ICH_T_CNT_MAX-1) && (r_ixt_cnt == r_ixt_cnt_max-1)) begin
            r_icht_cnt_done <= 1'b1;
        end
    end
end else begin
    always @(*) begin
        r_icht_cnt_done = r_ixt_cnt_done;
    end
end
endgenerate

// valid signal
always @(posedge clk) begin
    if((areset) || (r_icht_cnt_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end

//==============================================================================
// State r_ixt_cnt
//==============================================================================
reg  [STATE_IXT_BIT-1 : 0] c_state_ixt;
reg  [STATE_IXT_BIT-1 : 0] n_state_ixt;

always @(posedge clk) begin
    if(areset) begin
        c_state_ixt <= S_IXT_IDLE;
    end else begin
        c_state_ixt <= n_state_ixt;
    end
end
always @(*) begin
    n_state_ixt = c_state_ixt;
    case (c_state_ixt)
        S_IXT_IDLE   : if(i_run) n_state_ixt = S_IXT_FIRST;
        S_IXT_FIRST  : n_state_ixt = S_IXT_MIDDLE;
        S_IXT_MIDDLE : if(r_ixt_cnt == r_ixt_cnt_max-1) n_state_ixt = S_IXT_LAST;
        S_IXT_LAST   : begin
            if(r_icht_cnt_done) n_state_ixt = S_IXT_IDLE;
            else                n_state_ixt = S_IXT_FIRST;
        end
    endcase
end

//==============================================================================
// Read infmap Data in BRAM
//==============================================================================
reg  [B_INFMAP_ADDR_W-1 : 0] r_rd_addr;

generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || (r_icht_cnt_done)) begin
            r_rd_addr <= {B_INFMAP_ADDR_W{1'b0}};
        end else if(i_run) begin 
            r_rd_addr <= i_rd_start_addr;
        end else if(r_ixt_cnt_done) begin 
            r_rd_addr <= r_rd_addr + (IY * IX / B_INFMAP_WORD) - r_ixt_cnt_max;
        end else if(r_cnt_valid) begin
            r_rd_addr <= r_rd_addr + RD_ADDR_IX_T;
        end
    end
end else begin
    always @(posedge clk) begin
        if((areset) || (r_icht_cnt_done)) begin
            r_rd_addr <= {B_INFMAP_ADDR_W{1'b0}};
        end else if(i_run) begin 
            r_rd_addr <= i_rd_start_addr;
        end else if(r_cnt_valid) begin
            r_rd_addr <= r_rd_addr + RD_ADDR_IX_T;
        end
    end
end
endgenerate

assign b_o_infmap_addr = r_rd_addr;
assign b_o_infmap_ce   = 1'b1;
assign b_o_infmap_we   = 1'b0; // only read

//==============================================================================
// Shift c_state_ixt 
//==============================================================================
reg  [STATE_IXT_BIT-1 : 0] c_state_ixt_t1;

always @(posedge clk) begin
    if(areset) begin
        c_state_ixt_t1 <= S_IXT_IDLE;
    end else begin
        c_state_ixt_t1 <= c_state_ixt;
    end
end

//==============================================================================
// Read infmap Word Counter
//==============================================================================
reg  [WORD_CNT_BW-1 : 0] r_rd_word_cnt;
reg  [WORD_CNT_BW-1 : 0] n_rd_word_cnt;

always @(*) begin
    n_rd_word_cnt = IX_T;
    case (c_state_ixt)
        S_IXT_IDLE   : n_rd_word_cnt = IX_T;
        S_IXT_FIRST  : n_rd_word_cnt = r_rd_word_cnt - (4 - r_rd_start_word);
        S_IXT_MIDDLE : n_rd_word_cnt = r_rd_word_cnt - 4;
        S_IXT_LAST   : n_rd_word_cnt = IX_T;
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_word_cnt <= IX_T;
    end else begin
        r_rd_word_cnt <= n_rd_word_cnt;
    end
end

//==============================================================================
// Read infmap Word Num
//==============================================================================
reg  [INFMAP_WORD_BW-1 : 0] r_rd_word_num_m1;
reg  [INFMAP_WORD_BW-1 : 0] n_rd_word_num_m1;

always @(*) begin
    n_rd_word_num_m1 = {INFMAP_WORD_BW{1'b0}};
    case (c_state_ixt)
        S_IXT_IDLE   : n_rd_word_num_m1 = {INFMAP_WORD_BW{1'b0}};
        S_IXT_FIRST  : n_rd_word_num_m1 = 4 - 1 - r_rd_start_word;
        S_IXT_MIDDLE : n_rd_word_num_m1 = 4 - 1;
        S_IXT_LAST   : n_rd_word_num_m1 = r_rd_word_cnt - 1;
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_word_num_m1 <= {INFMAP_WORD_BW{1'b0}};
    end else begin
        r_rd_word_num_m1 <= n_rd_word_num_m1;
    end 
end

//==============================================================================
// Shift State c_state_ixt_t1
//==============================================================================
reg  [STATE_IXT_BIT-1 : 0] c_state_ixt_t2;

always @(posedge clk) begin
    if(areset) begin
        c_state_ixt_t2 <= S_IXT_IDLE;
    end else begin
        c_state_ixt_t2 <= c_state_ixt_t1;
    end
end

//==============================================================================
// Read infmap in BRAM
//==============================================================================
reg  [B_INFMAP_DATA_W-1 : 0] r_rd_infmap_ixt      ;
reg  [B_INFMAP_DATA_W-1 : 0] n_rd_infmap_ixt      ;

always @(*) begin
    n_rd_infmap_ixt = {B_INFMAP_DATA_W{1'b0}};
    case (c_state_ixt_t1)
        S_IXT_IDLE   : n_rd_infmap_ixt = {INFMAP_WORD_BW{1'b0}};
        S_IXT_FIRST  : begin
            case (r_rd_word_num_m1)
                4'd0 : n_rd_infmap_ixt = {{(3-0)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-0)*I_F_BW]};
                4'd1 : n_rd_infmap_ixt = {{(3-1)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-1)*I_F_BW]};
                4'd2 : n_rd_infmap_ixt = {{(3-2)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-2)*I_F_BW]};
                4'd3 : n_rd_infmap_ixt = {{(3-3)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-3)*I_F_BW]};
            endcase
        end 
        S_IXT_MIDDLE : n_rd_infmap_ixt = b_i_infmap_q;
        S_IXT_LAST   : begin
            case (r_rd_word_num_m1)
                4'd0 : n_rd_infmap_ixt = {{(3-0)*I_F_BW{1'b0}}, b_i_infmap_q[(1+0)*I_F_BW-1 : 0]};
                4'd1 : n_rd_infmap_ixt = {{(3-1)*I_F_BW{1'b0}}, b_i_infmap_q[(1+1)*I_F_BW-1 : 0]};
                4'd2 : n_rd_infmap_ixt = {{(3-2)*I_F_BW{1'b0}}, b_i_infmap_q[(1+2)*I_F_BW-1 : 0]};
                4'd3 : n_rd_infmap_ixt = {{(3-3)*I_F_BW{1'b0}}, b_i_infmap_q[(1+3)*I_F_BW-1 : 0]};
            endcase
        end 
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_infmap_ixt <= {B_INFMAP_DATA_W{1'b0}};
    end else begin
        r_rd_infmap_ixt <= n_rd_infmap_ixt;
    end 
end

//==============================================================================
// Shift r_rd_word_num_m1_t1
//==============================================================================
reg  [INFMAP_WORD_BW-1 : 0] r_rd_word_num_m1_t1;

always @(posedge clk) begin
    if(areset) begin
        r_rd_word_num_m1_t1 <= {INFMAP_WORD_BW{1'b0}};
    end else begin
        r_rd_word_num_m1_t1 <= r_rd_word_num_m1;
    end 
end

//==============================================================================
// Concatanate infmap Data
//==============================================================================
reg  [(IX_T*I_F_BW)-1 : 0] r_ot_infmap ;
reg  [(IX_T*I_F_BW)-1 : 0] n_ot_infmap ;
always @(*) begin
    n_ot_infmap = {(IX_T*I_F_BW){1'b0}};
    case (r_rd_word_num_m1_t1)
        0 : n_ot_infmap = {r_rd_infmap_ixt[(0+1)*I_F_BW-1 : 0], r_ot_infmap[(IX_T*I_F_BW)-1 : (0+1)*I_F_BW]};
        1 : n_ot_infmap = {r_rd_infmap_ixt[(1+1)*I_F_BW-1 : 0], r_ot_infmap[(IX_T*I_F_BW)-1 : (1+1)*I_F_BW]};
        2 : n_ot_infmap = {r_rd_infmap_ixt[(2+1)*I_F_BW-1 : 0], r_ot_infmap[(IX_T*I_F_BW)-1 : (2+1)*I_F_BW]};
        3 : n_ot_infmap = {r_rd_infmap_ixt[(3+1)*I_F_BW-1 : 0], r_ot_infmap[(IX_T*I_F_BW)-1 : (3+1)*I_F_BW]};
    endcase
end
always @(posedge clk) begin
    if((areset) || (c_state_ixt_t2 == S_IXT_IDLE)) begin
        r_ot_infmap <= {IX_T*I_F_BW{1'b0}};
    end else begin
        r_ot_infmap <= n_ot_infmap;
    end
end

//==============================================================================
// Count ot_idx
//==============================================================================
reg  [INFMAP_IDX_BW-1 : 0]  r_ot_idx        ;

generate
if(!IS_ICH_1) begin
    always @(posedge clk) begin
        if((areset) || (o_ot_done)) begin
            r_ot_idx <= {INFMAP_IDX_BW{1'b0}};
        end else if(c_state_ixt_t2 == S_IXT_LAST) begin
            r_ot_idx <= r_ot_idx + 1;
        end 
    end
end else begin
    always @(posedge clk) begin
        r_ot_idx <= {INFMAP_IDX_BW{1'b0}};
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
        r_n_ready <= (c_state_ixt == S_IXT_IDLE) && (c_state_ixt_t1 == S_IXT_LAST);
    end 
end
reg  r_ot_valid       ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_valid <= 1'b0;
    end else begin
        r_ot_valid <= (c_state_ixt_t2 == S_IXT_LAST);
    end 
end
reg  r_ot_done        ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_done <= 1'b0;
    end else begin
        r_ot_done <= (c_state_ixt_t1 == S_IXT_IDLE) && (c_state_ixt_t2 == S_IXT_LAST);
    end 
end


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;
assign o_n_ready = r_n_ready;
assign o_en_err  = r_en_err;

assign o_ot_idx     = r_ot_idx    ;
assign o_ot_infmap  = r_ot_infmap ;

assign o_ot_valid   = r_ot_valid  ;
assign o_ot_done    = r_ot_done   ;

endmodule