//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.03.14
// Design Name: LeNet-5
// Module Name: cnn_max_pool
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: CNN Max Pooling Layer
//                  input : (ICH_B * (IY/2) * IX_B) * infmap[ICH_T*2*IX_T]
//                  output: (OCH_B * OY) * max_pool[OCH_T * OX]
//                  max_pool = pooling(infmap)
//                  latency: cycle(avarage:  cycle), delay = latency
//                          (random seed:, LOOP_NUM:)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision: 0.01 - File Created
//           0.1(25.04.18) - delete b_i_pool_q
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"

module cnn_max_pool #(
    parameter OCH           = 6  ,
    parameter ICH           = 6  ,
    parameter KX            = 2  ,
    parameter KY            = 2  ,
    parameter IX            = 28 ,
    parameter IY            = 28 ,
    parameter OCH_B         = 2  ,
    parameter ICH_B         = 2  ,
    parameter IX_B          = 4  ,
    parameter I_F_BW        = 8  ,
    parameter PARA_B_BW     = 2  ,
    parameter PARA_T_BW     = 3  
) (
    clk              ,
    areset           ,
    i_run            ,
    i_in_valid       ,
    i_ix_b_idx       ,
    i_ix_t_idx       ,
    i_iy_idx         ,
    i_ich_b_idx      ,
    i_ich_t_infmap   ,
    i_in_done        ,
    o_idle           ,
    o_run            ,
    o_en_err         ,
    o_n_ready        ,
    o_ot_done        ,
    b_o_pool_addr    ,
    b_o_pool_ce      ,
    b_o_pool_byte_we ,
    b_o_pool_d       
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
// FSM 
localparam S_IDLE      = 0 ;
localparam S_RD_INFMAP = 1 ;
localparam S_WR_POOL   = 2 ;
localparam S_DONE      = 3 ;
localparam STATE_BW = S_DONE + 1 ; // One hot

// parameter size in CNN
localparam OX   = IX / KX ; // 14
localparam OY   = IY / KY ; // 14

// parameter size in CNN Block
localparam OCH_T  = OCH / OCH_B ; // 4
localparam ICH_T  = ICH / ICH_B ; // 3
localparam IX_T   = IX / IX_B   ; // 7

// parameter bit width
localparam O_F_BW   = I_F_BW; // 8

// BRAM
localparam B_COL_NUM     = 4  ;
localparam B_COL_BW      = $clog2(B_COL_NUM) ; // 2
localparam B_POOL_DATA_W = 32 ;
localparam B_POOL_DATA_D = (OCH * OY * OX) / B_COL_NUM; // 294 = 1176 / 4
localparam B_POOL_ADDR_W = $clog2(B_POOL_DATA_D); // 9

// counter
localparam IX_T_CNT_BW  = $clog2(IX_T  ) ; // 3
localparam OX_CNT_BW    = $clog2(OX+1    ) ; // 4
localparam OCH_T_CNT_BW = $clog2(OCH_T ) ; // 2

// index
localparam IX_B_IDX_BW   = $clog2(IX_B) ; // 2
localparam IX_T_IDX_BW   = $clog2(IX_T) ; // 3
localparam IY_IDX_BW     = $clog2(IY) ; // 5
localparam ICH_B_IDX_BW  = $clog2(ICH_B) ; // 1
localparam OCH_IDX_BW    = $clog2(OCH) ; // 2
localparam OY_IDX_BW     = $clog2(OY) ; // 4

// input data width
localparam ICH_T_INFMAP_BW = ICH_T * I_F_BW ; // 24
localparam OX_POOL_BW      = OX * O_F_BW ; // 112

// // delay
// localparam DELAY = ;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                           clk                 ;
input                           areset              ;

input                           i_run               ;

input                           i_in_valid          ;
input  [IX_B_IDX_BW-1 : 0]      i_ix_b_idx          ;
input  [IX_T_IDX_BW-1 : 0]      i_ix_t_idx          ;
input  [IY_IDX_BW-1 : 0]        i_iy_idx            ;
input  [ICH_B_IDX_BW-1 : 0]     i_ich_b_idx         ;
input  [ICH_T_INFMAP_BW-1 : 0]  i_ich_t_infmap      ;
input                           i_in_done           ;

output                          o_idle              ;
output                          o_run               ;
output                          o_en_err            ;
output                          o_n_ready           ;
output                          o_ot_done           ;

output [B_POOL_ADDR_W-1 : 0]    b_o_pool_addr       ;
output                          b_o_pool_ce         ;
output [B_COL_NUM-1 : 0]        b_o_pool_byte_we    ;
output [B_POOL_DATA_W-1 : 0]    b_o_pool_d          ;
// input  [B_POOL_DATA_W-1 : 0]    b_i_pool_q          ;

//==============================================================================
// Declaration Submodule Port
//==============================================================================
wire                     c_wrp_i_run             ;
wire [OCH_IDX_BW -1 : 0] c_wrp_i_och_idx         ;
wire [OY_IDX_BW-1 : 0]   c_wrp_i_oy_idx          ;
wire [OX_POOL_BW-1 : 0]  c_wrp_i_ox_pool         ;
wire                     c_wrp_o_idle            ;
wire                     c_wrp_o_run             ;
wire                     c_wrp_o_n_ready         ;
wire                     c_wrp_o_en_err          ;
wire                     c_wrp_o_ot_done         ;

//==============================================================================
// Declaration FSM
//==============================================================================
reg  [STATE_BW-1 : 0] c_state;
reg  [STATE_BW-1 : 0] n_state;
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
reg  r_in_done       ;

always @(posedge clk) begin
    if(areset) begin
        r_run <= 1'b0;
        r_in_done <= 1'b0;
    end else if(i_run) begin
        r_run <= 1'b1;
    end else if(i_in_done) begin
        r_in_done <= 1'b1;
    end else if(o_ot_done) begin
        r_run <= 1'b0;
        r_in_done <= 1'b0;
    end 
end

//==============================================================================
// Read ix_t infmap done
//==============================================================================
reg  r_ixt_infmap_done ;

always @(posedge clk) begin
    if((areset) || (r_ixt_infmap_done)) begin
        r_ixt_infmap_done <= 1'b0;
    end else if((i_in_valid) && (i_ix_t_idx == IX_T-2)) begin
        r_ixt_infmap_done <= 1'b1;
    end 
end

//==============================================================================
// Counter: ix_t
//==============================================================================
reg  [IX_T_CNT_BW-1 : 0] r_ixt_cnt  ;
reg  r_ixt_cnt_valid ;
reg  r_ixt_cnt_done  ;
reg  r_ixt_cnt_done_t1  ;

// counter
always @(posedge clk) begin
    if((areset) || (r_ixt_cnt_done)) begin
        r_ixt_cnt <= {IX_T_CNT_BW{1'b0}};
    end else if (r_ixt_cnt_valid) begin
        r_ixt_cnt <= r_ixt_cnt + 1;
    end
end

// count valid
always @(posedge clk) begin
    if((areset) || (r_ixt_cnt_done)) begin
        r_ixt_cnt_valid <= 1'b0;
    end else if((i_in_valid) && (r_ixt_infmap_done) && (i_iy_idx[0])) begin
        r_ixt_cnt_valid <= 1'b1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || (r_ixt_cnt_done)) begin
        r_ixt_cnt_done <= 1'b0;
    end else if(r_ixt_cnt == IX_T - 2) begin
        r_ixt_cnt_done <= 1'b1;
    end
end
always @(posedge clk) begin
    if(areset) begin
        r_ixt_cnt_done_t1 <= 1'b0;
    end else begin
        r_ixt_cnt_done_t1 <= r_ixt_cnt_done;
    end
end

//==============================================================================
// infmap register core
//==============================================================================
reg  [O_F_BW-1 : 0] r_infmap_0 [0 : (ICH_T*IX_T)-1];
reg  [O_F_BW-1 : 0] n_infmap_0 [0 : (ICH_T*IX_T)-1];

reg  [O_F_BW-1 : 0] r_infmap_1 [0 : (ICH_T*IX_T)-1];
reg  [O_F_BW-1 : 0] n_infmap_1 [0 : (ICH_T*IX_T)-1];

genvar g_x, g_c;
generate
    for (g_c = 0; g_c < ICH_T; g_c = g_c + 1) begin : gen_x
        for (g_x = 0; g_x < IX_T; g_x = g_x + 1) begin : gen_c
            always @(*) begin
                n_infmap_0[(g_c*IX_T)+(g_x)] = r_infmap_0[(g_c*IX_T)+(g_x)];
                n_infmap_1[(g_c*IX_T)+(g_x)] = r_infmap_1[(g_c*IX_T)+(g_x)];
                if(r_ixt_cnt_valid) begin
                    if(g_x == IX_T-1) begin
                        n_infmap_0[(g_c*IX_T)+(g_x)] = {O_F_BW{1'b0}};
                        n_infmap_1[(g_c*IX_T)+(g_x)] = {O_F_BW{1'b0}};
                    end else begin
                        n_infmap_0[(g_c*IX_T)+(g_x)] = r_infmap_0[(g_c*IX_T)+(g_x)+1];
                        n_infmap_1[(g_c*IX_T)+(g_x)] = r_infmap_1[(g_c*IX_T)+(g_x)+1];
                    end
                end else if(i_in_valid) begin
                    if(i_iy_idx[0]) begin
                        if(g_x == IX_T-1) begin
                            n_infmap_1[(g_c*IX_T)+(g_x)] = i_ich_t_infmap[g_c*O_F_BW +: O_F_BW];
                        end else begin
                            n_infmap_1[(g_c*IX_T)+(g_x)] = r_infmap_1[(g_c*IX_T)+(g_x)+1];
                        end
                    end else begin
                        if(g_x == IX_T-1) begin
                            n_infmap_0[(g_c*IX_T)+(g_x)] = i_ich_t_infmap[g_c*O_F_BW +: O_F_BW];
                        end else begin
                            n_infmap_0[(g_c*IX_T)+(g_x)] = r_infmap_0[(g_c*IX_T)+(g_x)+1];
                        end
                    end
                end
            end
            always @(posedge clk) begin
                if(areset) begin
                    r_infmap_0[(g_c*IX_T)+(g_x)] <= {O_F_BW{1'b0}};
                    r_infmap_1[(g_c*IX_T)+(g_x)] <= {O_F_BW{1'b0}};
                end else begin
                    r_infmap_0[(g_c*IX_T)+(g_x)] <= n_infmap_0[(g_c*IX_T)+(g_x)];
                    r_infmap_1[(g_c*IX_T)+(g_x)] <= n_infmap_1[(g_c*IX_T)+(g_x)];
                end
            end
        end
    end
endgenerate

//==============================================================================
// Comparison infmap(KX*KY)
//==============================================================================
wire w_rd_cmp_ky_valid;

wire [O_F_BW-1 : 0] w_cmp_ky [0 : ICH_T-1] ;
reg  [O_F_BW-1 : 0] r_cmp_ky0 [0 : ICH_T-1] ;
reg                 r_cmp_ky0_valid ;
reg  [O_F_BW-1 : 0] r_cmp_ky1 [0 : ICH_T-1] ;
reg                 r_cmp_ky1_valid ;

wire [O_F_BW-1 : 0] w_cmp_kx [0 : ICH_T-1] ;
reg  [O_F_BW-1 : 0] r_cmp_kx [0 : ICH_T-1] ;
reg                 r_cmp_kx_valid ;

assign w_rd_cmp_ky_valid = r_ixt_cnt_valid;

genvar g_k;
generate
    for (g_k = 0; g_k < ICH_T; g_k = g_k + 1) begin : gen_k
        // cmp_ky
        assign w_cmp_ky[g_k] = (r_infmap_0[g_k*IX_T] > r_infmap_1[g_k*IX_T]) ?
            (r_infmap_0[g_k*IX_T]) : (r_infmap_1[g_k*IX_T]);
        always @(posedge clk) begin
            if((areset) || ((r_ixt_cnt_done_t1) && (r_cmp_ky1_valid))) begin
                r_cmp_ky0[g_k] <= {O_F_BW{1'b0}};
            end else if ((w_rd_cmp_ky_valid) && ((~r_cmp_ky0_valid) || (r_cmp_ky1_valid))) begin
                r_cmp_ky0[g_k] <= w_cmp_ky[g_k];
            end
        end
        always @(posedge clk) begin
            if((areset) || (r_cmp_ky1_valid)) begin
                r_cmp_ky1[g_k] <= {O_F_BW{1'b0}};
            end else if ((w_rd_cmp_ky_valid) && ~((~r_cmp_ky0_valid) || (r_cmp_ky1_valid))) begin
                r_cmp_ky1[g_k] <= w_cmp_ky[g_k];
            end
        end
        
        // cmp_kx
        assign w_cmp_kx[g_k] = (r_cmp_ky0[g_k] > r_cmp_ky1[g_k]) ?
            (r_cmp_ky0[g_k]) : (r_cmp_ky1[g_k]);
        always @(posedge clk) begin
            if((areset) || (~r_cmp_ky1_valid)) begin
                r_cmp_kx[g_k] <= {O_F_BW{1'b0}};
            end else begin
                r_cmp_kx[g_k] <= w_cmp_kx[g_k];
            end
        end
    end
endgenerate

// valid
always @(posedge clk) begin
    if((areset) || ((~w_rd_cmp_ky_valid) && (r_cmp_ky1_valid))) begin
        r_cmp_ky0_valid <= 1'b0;
    end else if((w_rd_cmp_ky_valid) && ((~r_cmp_ky0_valid) || (r_cmp_ky1_valid))) begin
        r_cmp_ky0_valid <= 1'b1;
    end 
end

always @(posedge clk) begin
    if((areset) || (r_cmp_ky1_valid)) begin
        r_cmp_ky1_valid <= 1'b0;
    end else if((w_rd_cmp_ky_valid) && ~((~r_cmp_ky0_valid) || (r_cmp_ky1_valid))) begin
        r_cmp_ky1_valid <= 1'b1;
    end 
end

always @(posedge clk) begin
    if((areset) || (~r_cmp_ky1_valid)) begin
        r_cmp_kx_valid <= 1'b0;
    end else begin
        r_cmp_kx_valid <= 1'b1;
    end
end

//==============================================================================
// pool register core
//==============================================================================
reg  [O_F_BW-1 : 0] r_pool [0 : (OCH_T*OX)-1];
reg  [O_F_BW-1 : 0] n_pool [0 : (OCH_T*OX)-1];

genvar g_ox, g_oc;
generate
    for (g_oc = 0; g_oc < OCH_T; g_oc = g_oc + 1) begin : gen_oc
        for (g_ox = 0; g_ox < OX; g_ox = g_ox + 1) begin : gen_ox
            always @(*) begin
                n_pool[(g_oc*OX)+(g_ox)] = r_pool[(g_oc*OX)+(g_ox)];
                if(r_cmp_kx_valid) begin
                    if(g_ox == OX-1) begin
                        n_pool[(g_oc*OX)+(g_ox)] = r_cmp_kx[g_oc];
                    end else begin
                        n_pool[(g_oc*OX)+(g_ox)] = r_pool[(g_oc*OX)+(g_ox)+1];
                    end
                end else if(c_wrp_i_run) begin
                    if(g_oc == OCH_T-1) begin
                        n_pool[(g_oc*OX)+(g_ox)] = {O_F_BW{1'b0}};
                    end else begin
                        n_pool[(g_oc*OX)+(g_ox)] = r_pool[((g_oc+1)*OX)+(g_ox)];
                    end
                end
            end
            always @(posedge clk) begin
                if(areset) begin
                    r_pool[(g_oc*OX)+(g_ox)] <= {O_F_BW{1'b0}};
                end else begin
                    r_pool[(g_oc*OX)+(g_ox)] <= n_pool[(g_oc*OX)+(g_ox)];
                end
            end
        end
    end
endgenerate

//==============================================================================
// Counter: ox
//==============================================================================
reg  [OX_CNT_BW-1 : 0]    r_ox_cnt   ;
reg  r_ox_cnt_done   ;

// counter
always @(posedge clk) begin
    if((areset) || (r_ox_cnt_done)) begin
        r_ox_cnt <= {OX_CNT_BW{1'b0}};
    end else if (r_cmp_kx_valid) begin
        r_ox_cnt <= r_ox_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || (r_ox_cnt_done)) begin
        r_ox_cnt_done <= 1'b0;
    end else if((r_cmp_kx_valid) && (r_ox_cnt == OX-1)) begin
        r_ox_cnt_done <= 1'b1;
    end
end

//==============================================================================
// Counter: och_t
//==============================================================================
reg  [OCH_T_CNT_BW-1 : 0] r_ocht_cnt ;
reg  r_ocht_cnt_done ;

wire w_ocht_cnt_update;
assign w_ocht_cnt_update = (~r_ocht_cnt_done) && (c_wrp_o_n_ready);

// counter
always @(posedge clk) begin
    if((areset) || ((r_ocht_cnt_done) && (c_wrp_o_n_ready))) begin
        r_ocht_cnt <= {OX_CNT_BW{1'b0}};
    end else if(w_ocht_cnt_update) begin
        r_ocht_cnt <= r_ocht_cnt + 1;
    end
end

// count done
always @(posedge clk) begin
    if((areset) || ((c_wrp_o_n_ready) && (r_ocht_cnt_done))) begin
        r_ocht_cnt_done <= 1'b0;
    end else if((c_wrp_o_n_ready) && (r_ocht_cnt == OCH_T-2)) begin
        r_ocht_cnt_done <= 1'b1;
    end
end

//==============================================================================
// Control Submodule Input Port: wr_b_pool 
//==============================================================================
reg                      r_wrp_i_run     ;
reg  [OCH_IDX_BW-1 : 0]  r_wrp_i_och_idx ;
reg  [OY_IDX_BW-1 : 0]   r_wrp_i_oy_idx  ;
wire [OX_POOL_BW-1 : 0]  w_wrp_i_ox_pool ;

always @(posedge clk) begin
    if(areset) begin
        r_wrp_i_run <= 0;
    end else begin
        r_wrp_i_run <= (r_ox_cnt_done) || (w_ocht_cnt_update);
    end
end

wire w_wrp_idx_update = c_wrp_o_n_ready;

always @(posedge clk) begin
    if(areset) begin
        r_wrp_i_och_idx <= {OCH_IDX_BW{1'b0}};
    end else if(i_in_valid) begin
        r_wrp_i_och_idx <= i_ich_b_idx * OCH_T;
    end else if(w_wrp_idx_update) begin
        r_wrp_i_och_idx <= r_wrp_i_och_idx + 1;
    end
end

always @(posedge clk) begin
    if(areset) begin
        r_wrp_i_oy_idx <= {OY_IDX_BW{1'b0}};
    end else if((i_in_valid) && (i_iy_idx[0])) begin
        r_wrp_i_oy_idx <= i_iy_idx[IY_IDX_BW-1 : 1];
    end
end

genvar g_p;
generate
    for (g_p = 0; g_p < OX; g_p = g_p + 1) begin : gen_p
        assign w_wrp_i_ox_pool[g_p*O_F_BW +: O_F_BW] = r_pool[g_p];
    end
endgenerate

assign c_wrp_i_run     = r_wrp_i_run     ;
assign c_wrp_i_och_idx = r_wrp_i_och_idx ;
assign c_wrp_i_oy_idx  = r_wrp_i_oy_idx  ;
assign c_wrp_i_ox_pool = w_wrp_i_ox_pool ;

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
        r_n_ready <= (r_in_done) && (r_ocht_cnt_done) && (c_wrp_o_n_ready);
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

//==============================================================================
// FSM Detail
//==============================================================================
always @(*) begin
    n_state = c_state;
    case (c_state)
        (1 << S_IDLE) : if(i_run) begin 
            n_state = (1 << S_RD_INFMAP); 
        end
        (1 << S_RD_INFMAP) : if(r_ox_cnt_done) begin 
            n_state = (1 << S_WR_POOL); 
        end
        (1 << S_WR_POOL ) : if((r_ocht_cnt_done) && (c_wrp_o_n_ready)) begin 
            if(r_in_done)
                n_state = (1 << S_DONE); 
            else
                n_state = (1 << S_RD_INFMAP); 
        end
        (1 << S_DONE) : begin 
            if(i_run)
                n_state = (1 << S_RD_INFMAP); 
            else 
                n_state = (1 << S_IDLE); 
        end
    endcase
end

//==============================================================================
// Instantiation Submodule
//==============================================================================
wr_b_pool #( 
    .OCH    (OCH    ) ,
    .OY     (OY     ) ,
    .OX     (OX     ) ,
    .OCH_B  (OCH_B  ) ,
    .O_F_BW (O_F_BW ) 
) u_wr_b_pool ( 
    .clk              (clk              ) ,
    .areset           (areset           ) ,
    .i_run            (c_wrp_i_run            ) ,
    .i_oy_idx         (c_wrp_i_oy_idx         ) ,
    .i_och_idx        (c_wrp_i_och_idx        ) ,
    .i_ox_pool        (c_wrp_i_ox_pool        ) ,
    .o_idle           (c_wrp_o_idle           ) ,
    .o_run            (c_wrp_o_run            ) ,
    .o_n_ready        (c_wrp_o_n_ready        ) ,
    .o_en_err         (c_wrp_o_en_err         ) ,
    .o_ot_done        (c_wrp_o_ot_done        ) ,
    .b_o_pool_addr    (b_o_pool_addr    ) ,
    .b_o_pool_ce      (b_o_pool_ce      ) ,
    .b_o_pool_byte_we (b_o_pool_byte_we ) ,
    .b_o_pool_d       (b_o_pool_d       ) 
);

endmodule