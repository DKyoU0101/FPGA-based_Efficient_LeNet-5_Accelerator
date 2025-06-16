//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.04.03
// Design Name: LeNet-5
// Module Name: rd_b_fc_infmap
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Read input feature map in BRAM 
//                  input : rd_start_idx
//                  output: infmap[ICH_T]
//                  latency:  cycle(avarage:  cycle), delay = latency
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           0.1(24.05.06) - error correction
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module rd_b_fc_infmap #( 
    parameter ICH           = 400 ,
    parameter ICH_B         = 40  ,
    parameter I_F_BW        = 8   
) ( 
    clk             ,
    areset          ,
    i_run           ,
    i_rd_start_idx  ,
    o_idle          ,
    o_run           ,
    o_en_err        ,
    o_n_ready       ,
    o_ot_valid      ,
    o_ot_done       ,
    o_ot_infmap     ,
    b_o_infmap_addr ,
    b_o_infmap_ce   ,
    b_o_infmap_we   ,
    b_i_infmap_q    
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// parameter size in CNN Block
localparam ICH_T  = ICH / ICH_B ; // 10

// BRAM
localparam B_COL_NUM        = 4 ;
localparam B_COL_BW         = $clog2(B_COL_NUM) ; // 2
localparam B_INFMAP_DATA_W  = 32 ;
localparam B_INFMAP_DATA_D  = $rtoi($ceil(ICH*1.0 / B_COL_NUM*1.0)); // 100
localparam B_INFMAP_ADDR_W  = $clog2(B_INFMAP_DATA_D); // 7

// counter
localparam ICH_T_CNT_BW  = $clog2(ICH_T) ; // 4

// icht counter state
localparam S_ICHT_IDLE   = 0;
localparam S_ICHT_FIRST  = 1;
localparam S_ICHT_MIDDLE = 2;
localparam S_ICHT_LAST   = 3;
localparam STATE_ICHT_BIT = 2;

// index
localparam INFMAP_I_IDX_BW = $clog2(ICH) ; // 9
localparam INFMAP_ICH_T_BW = ICH_T * I_F_BW ; // 80

// delay
// localparam DELAY = ; // 12

//==============================================================================
// Input/Output declaration
//==============================================================================
input                          clk               ;
input                          areset            ;

input                          i_run             ;

input  [INFMAP_I_IDX_BW-1 : 0] i_rd_start_idx    ;

output                         o_idle            ;
output                         o_run             ;
output                         o_en_err          ;
output                         o_n_ready         ;
output                         o_ot_valid        ;
output                         o_ot_done         ;

output [INFMAP_ICH_T_BW-1 : 0] o_ot_infmap       ;

output [B_INFMAP_ADDR_W-1 : 0] b_o_infmap_addr   ;
output                         b_o_infmap_ce     ;
output                         b_o_infmap_we     ;
// output [B_INFMAP_DATA_W-1 : 0] b_o_infmap_d      ; // not using write bram
input  [B_INFMAP_DATA_W-1 : 0] b_i_infmap_q      ;

//==============================================================================
// Capture Input Signal
//==============================================================================
reg  r_run           ;
reg  [B_COL_BW-1 : 0] r_rd_start_col ;

always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
        r_rd_start_col <= {B_COL_BW{1'b0}};
    end else if(i_run) begin
        r_run <= 1'b1;
        r_rd_start_col <= i_rd_start_idx[B_COL_BW-1 : 0];
    end else if(o_ot_done) begin
        r_run <= 1'b0;
        r_rd_start_col <= {B_COL_BW{1'b0}};
    end 
end

//==============================================================================
// Maximum icht Counter
//==============================================================================
reg  [ICH_T_CNT_BW-1 : 0] r_icht_cnt_max ;

always @(posedge clk) begin
    if(areset) begin
        r_icht_cnt_max <= {ICH_T_CNT_BW{1'b0}};
    end else if(i_run) begin
        r_icht_cnt_max <= ((ICH_T - 1 - (4 - i_rd_start_idx[B_COL_BW-1 : 0])) >> B_COL_BW) + 1;
    end else if(o_ot_done) begin
        r_icht_cnt_max <= {ICH_T_CNT_BW{1'b0}};
    end 
end

//==============================================================================
// Count BRAM Address
//==============================================================================
reg  [ICH_T_CNT_BW-1 : 0] r_icht_cnt        ;

reg  r_icht_cnt_done ;

reg  r_cnt_valid    ;

// counter
always @(posedge clk) begin
    if((areset) || (r_icht_cnt_done)) begin
        r_icht_cnt <= {ICH_T_CNT_BW{1'b0}};
    end else if (r_cnt_valid) begin
        r_icht_cnt <= r_icht_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || (r_icht_cnt_done)) begin
        r_icht_cnt_done <= 1'b0;
    end else begin
        r_icht_cnt_done <= (r_icht_cnt == r_icht_cnt_max-1); // not r_icht_cnt_max-2
    end
end

// valid signal
always @(posedge clk) begin
    if((areset) || (r_icht_cnt_done)) begin
        r_cnt_valid <= 1'b0;
    end else if(i_run) begin
        r_cnt_valid <= 1'b1;
    end
end

//==============================================================================
// State r_icht_cnt
//==============================================================================
reg  [STATE_ICHT_BIT-1 : 0] c_state_icht;
reg  [STATE_ICHT_BIT-1 : 0] n_state_icht;

always @(posedge clk) begin
    if(areset) begin
        c_state_icht <= S_ICHT_IDLE;
    end else begin
        c_state_icht <= n_state_icht;
    end
end
always @(*) begin
    n_state_icht = c_state_icht;
    case (c_state_icht)
        S_ICHT_IDLE   : if(i_run) n_state_icht = S_ICHT_FIRST;
        S_ICHT_FIRST  : n_state_icht = (ICH_T > 8) ? (S_ICHT_MIDDLE) : (S_ICHT_LAST);
        S_ICHT_MIDDLE : if(r_icht_cnt == r_icht_cnt_max-1) n_state_icht = S_ICHT_LAST;
        S_ICHT_LAST   : n_state_icht = S_ICHT_IDLE;
    endcase
end

//==============================================================================
// Read infmap Data in BRAM
//==============================================================================
reg  [B_INFMAP_ADDR_W-1 : 0] r_rd_addr;

always @(posedge clk) begin
    if((areset) || (r_icht_cnt_done)) begin
        r_rd_addr <= {B_INFMAP_ADDR_W{1'b0}};
    end else if(i_run) begin 
        r_rd_addr <= i_rd_start_idx[INFMAP_I_IDX_BW-1 : B_COL_BW];
    end else if(r_cnt_valid) begin
        r_rd_addr <= r_rd_addr + 1;
    end
end

assign b_o_infmap_addr = r_rd_addr;
assign b_o_infmap_ce   = 1'b1;
assign b_o_infmap_we   = 1'b0; // only read

//==============================================================================
// Shift c_state_icht 
//==============================================================================
reg  [STATE_ICHT_BIT-1 : 0] c_state_icht_t1;

always @(posedge clk) begin
    if(areset) begin
        c_state_icht_t1 <= S_ICHT_IDLE;
    end else begin
        c_state_icht_t1 <= c_state_icht;
    end
end

//==============================================================================
// Read infmap Col Counter
//==============================================================================
reg  [ICH_T_CNT_BW-1 : 0] r_rd_col_cnt;
reg  [ICH_T_CNT_BW-1 : 0] n_rd_col_cnt;

always @(*) begin
    n_rd_col_cnt = ICH_T;
    case (c_state_icht)
        S_ICHT_IDLE   : n_rd_col_cnt = ICH_T;
        S_ICHT_FIRST  : n_rd_col_cnt = r_rd_col_cnt - (4 - r_rd_start_col);
        S_ICHT_MIDDLE : n_rd_col_cnt = r_rd_col_cnt - 4;
        S_ICHT_LAST   : n_rd_col_cnt = ICH_T;
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_col_cnt <= ICH_T;
    end else begin
        r_rd_col_cnt <= n_rd_col_cnt;
    end
end

//==============================================================================
// Read infmap Word Num
//==============================================================================
reg  [B_COL_BW-1 : 0] r_rd_col_num_m1; // (read col_num) - 1
reg  [B_COL_BW-1 : 0] n_rd_col_num_m1;

always @(*) begin
    n_rd_col_num_m1 = {B_COL_BW{1'b0}};
    case (c_state_icht)
        S_ICHT_IDLE   : n_rd_col_num_m1 = {B_COL_BW{1'b0}};
        S_ICHT_FIRST  : n_rd_col_num_m1 = 4 - 1 - r_rd_start_col;
        S_ICHT_MIDDLE : n_rd_col_num_m1 = 4 - 1;
        S_ICHT_LAST   : n_rd_col_num_m1 = r_rd_col_cnt - 1;
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_col_num_m1 <= {B_COL_BW{1'b0}};
    end else begin
        r_rd_col_num_m1 <= n_rd_col_num_m1;
    end 
end

//==============================================================================
// Shift State c_state_icht_t1
//==============================================================================
reg  [STATE_ICHT_BIT-1 : 0] c_state_icht_t2;

always @(posedge clk) begin
    if(areset) begin
        c_state_icht_t2 <= S_ICHT_IDLE;
    end else begin
        c_state_icht_t2 <= c_state_icht_t1;
    end
end

//==============================================================================
// Read infmap in BRAM
//==============================================================================
reg  [B_INFMAP_DATA_W-1 : 0] r_rd_infmap_icht      ;
reg  [B_INFMAP_DATA_W-1 : 0] n_rd_infmap_icht      ;

always @(*) begin
    n_rd_infmap_icht = {B_INFMAP_DATA_W{1'b0}};
    case (c_state_icht_t1)
        S_ICHT_IDLE   : n_rd_infmap_icht = {B_COL_BW{1'b0}};
        S_ICHT_FIRST  : begin
            case (r_rd_col_num_m1)
                4'd0 : n_rd_infmap_icht = {{(3-0)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-0)*I_F_BW]};
                4'd1 : n_rd_infmap_icht = {{(3-1)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-1)*I_F_BW]};
                4'd2 : n_rd_infmap_icht = {{(3-2)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-2)*I_F_BW]};
                4'd3 : n_rd_infmap_icht = {{(3-3)*I_F_BW{1'b0}}, b_i_infmap_q[B_INFMAP_DATA_W-1 : (3-3)*I_F_BW]};
            endcase
        end 
        S_ICHT_MIDDLE : n_rd_infmap_icht = b_i_infmap_q;
        S_ICHT_LAST   : begin
            case (r_rd_col_num_m1)
                4'd0 : n_rd_infmap_icht = {{(3-0)*I_F_BW{1'b0}}, b_i_infmap_q[(1+0)*I_F_BW-1 : 0]};
                4'd1 : n_rd_infmap_icht = {{(3-1)*I_F_BW{1'b0}}, b_i_infmap_q[(1+1)*I_F_BW-1 : 0]};
                4'd2 : n_rd_infmap_icht = {{(3-2)*I_F_BW{1'b0}}, b_i_infmap_q[(1+2)*I_F_BW-1 : 0]};
                4'd3 : n_rd_infmap_icht = {{(3-3)*I_F_BW{1'b0}}, b_i_infmap_q[(1+3)*I_F_BW-1 : 0]};
            endcase
        end 
    endcase
end
always @(posedge clk) begin
    if(areset) begin
        r_rd_infmap_icht <= {B_INFMAP_DATA_W{1'b0}};
    end else begin
        r_rd_infmap_icht <= n_rd_infmap_icht;
    end 
end

//==============================================================================
// Shift r_rd_col_num_m1
//==============================================================================
reg  [B_COL_BW-1 : 0] r_rd_col_num_m1_t1;

always @(posedge clk) begin
    if(areset) begin
        r_rd_col_num_m1_t1 <= {B_COL_BW{1'b0}};
    end else begin
        r_rd_col_num_m1_t1 <= r_rd_col_num_m1;
    end 
end

//==============================================================================
// Concatanate infmap Data
//==============================================================================
reg  [INFMAP_ICH_T_BW-1 : 0] r_ot_infmap ;
reg  [INFMAP_ICH_T_BW-1 : 0] n_ot_infmap ;
always @(*) begin
    n_ot_infmap = {INFMAP_ICH_T_BW{1'b0}};
    case (r_rd_col_num_m1_t1)
        0 : n_ot_infmap = {r_rd_infmap_icht[(0+1)*I_F_BW-1 : 0], r_ot_infmap[INFMAP_ICH_T_BW-1 : (0+1)*I_F_BW]};
        1 : n_ot_infmap = {r_rd_infmap_icht[(1+1)*I_F_BW-1 : 0], r_ot_infmap[INFMAP_ICH_T_BW-1 : (1+1)*I_F_BW]};
        2 : n_ot_infmap = {r_rd_infmap_icht[(2+1)*I_F_BW-1 : 0], r_ot_infmap[INFMAP_ICH_T_BW-1 : (2+1)*I_F_BW]};
        3 : n_ot_infmap = {r_rd_infmap_icht[(3+1)*I_F_BW-1 : 0], r_ot_infmap[INFMAP_ICH_T_BW-1 : (3+1)*I_F_BW]};
    endcase
end
always @(posedge clk) begin
    if((areset) || (c_state_icht_t2 == S_ICHT_IDLE)) begin
        r_ot_infmap <= {INFMAP_ICH_T_BW{1'b0}};
    end else begin
        r_ot_infmap <= n_ot_infmap;
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
        r_n_ready <= (c_state_icht == S_ICHT_IDLE) && (c_state_icht_t1 == S_ICHT_LAST);
    end 
end
reg  r_ot_valid       ;
always @(posedge clk) begin
    if(areset) begin
        r_ot_valid <= 1'b0;
    end else begin
        r_ot_valid <= r_n_ready;
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


// assign output signal
assign o_idle    = !r_run;
assign o_run     = r_run;

assign o_en_err   = r_en_err   ;
assign o_n_ready  = r_n_ready  ;
assign o_ot_valid = r_ot_valid ;
assign o_ot_done  = r_ot_done  ;

assign o_ot_infmap  = r_ot_infmap ;

endmodule