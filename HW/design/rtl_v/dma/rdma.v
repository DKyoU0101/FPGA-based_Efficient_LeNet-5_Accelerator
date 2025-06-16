//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.04
// Design Name: 
// Module Name: rdma
// Project Name: chapter20
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: RDMA (AXI4 AR, R Channel)
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module rdma #(
    parameter C_M_AXI_ID_W      = 1  ,
    parameter C_M_AXI_ADDR_W    = 32 ,
    parameter C_M_AXI_DATA_W    = 64 ,
    parameter C_M_AXI_AR_USER_W = 1  ,
    parameter C_M_AXI_R_USER_W  = 1  ,
    parameter NUM_RD_INFMAP     = 1  ,
    parameter NUM_RD_PARAM      = 1  
) (
    ap_clk   ,
    ap_rst_n ,
    i_ap_rd_cnn_param ,
    i_ap_infmap_valid ,
    o_ap_idle  ,
    o_ap_ready ,
    o_ap_done  ,
    o_m_axi_AR_VALID  ,
    i_m_axi_AR_READY  ,
    o_m_axi_AR_ADDR   ,
    o_m_axi_AR_ID     ,
    o_m_axi_AR_LEN    ,
    o_m_axi_AR_SIZE   ,
    o_m_axi_AR_BURST  ,
    o_m_axi_AR_LOCK   ,
    o_m_axi_AR_CACHE  ,
    o_m_axi_AR_PROT   ,
    o_m_axi_AR_QOS    ,
    o_m_axi_AR_REGION ,
    o_m_axi_AR_USER   ,
    i_m_axi_R_VALID ,
    o_m_axi_R_READY ,
    i_m_axi_R_DATA  ,
    i_m_axi_R_LAST  ,
    i_m_axi_R_ID    ,
    i_m_axi_R_USER  ,
    i_m_axi_R_RESP  ,
    i_param_baseaddr  ,
    i_infmap_baseaddr  ,
    o_r_din         ,
    i_r_full_n      ,
    o_r_write       ,
    o_r_rd_param  ,
    o_r_rd_infmap 
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
    localparam S_IDLE    = 2'b00;
    localparam S_RUN     = 2'b01;
    localparam S_PRE     = 2'b10;  // Prepare Data
    localparam S_DONE    = 2'b11;
    
    localparam NUM_AXI_DATA = C_M_AXI_DATA_W / 8; // 8
    localparam AXI_DATA_SHIFT = $clog2(NUM_AXI_DATA); // 3
    localparam NUM_AXI_AR_MOR_REQ = 8'd4;
    localparam LOG_NUM_AXI_AR_MOR_REQ = $clog2(NUM_AXI_AR_MOR_REQ) + 1;
    
    localparam NUM_MAX_BURST = 16;
    localparam NUM_AR_LEN_BW = 9;
    
//==============================================================================
// Input/Output declaration
//==============================================================================
    input                               ap_clk   ;
    input                               ap_rst_n ;
    
    // ap_ctrl signals
    input                               i_ap_rd_cnn_param ;
    input                               i_ap_infmap_valid ;
    
    output                              o_ap_idle  ;
    output                              o_ap_ready ;
    output                              o_ap_done  ;
    
    // AR Channel
    output                              o_m_axi_AR_VALID  ;
    input                               i_m_axi_AR_READY  ;
    output [C_M_AXI_ADDR_W - 1:0]       o_m_axi_AR_ADDR   ;
    output [C_M_AXI_ID_W - 1:0]         o_m_axi_AR_ID     ;
    output [7:0]                        o_m_axi_AR_LEN    ;
    output [2:0]                        o_m_axi_AR_SIZE   ;
    output [1:0]                        o_m_axi_AR_BURST  ;
    output [1:0]                        o_m_axi_AR_LOCK   ;
    output [3:0]                        o_m_axi_AR_CACHE  ;
    output [2:0]                        o_m_axi_AR_PROT   ;
    output [3:0]                        o_m_axi_AR_QOS    ;
    output [3:0]                        o_m_axi_AR_REGION ;
    output [C_M_AXI_AR_USER_W - 1:0]    o_m_axi_AR_USER   ;
    
    // R Channel
    input                               i_m_axi_R_VALID ;
    output                              o_m_axi_R_READY ;
    input  [C_M_AXI_DATA_W - 1:0]       i_m_axi_R_DATA  ;
    input                               i_m_axi_R_LAST  ;
    input  [C_M_AXI_ID_W - 1:0]         i_m_axi_R_ID    ;
    input  [C_M_AXI_R_USER_W - 1:0]     i_m_axi_R_USER  ;
    input  [1:0]                        i_m_axi_R_RESP  ;
    
    // input parameter
    input  [C_M_AXI_ADDR_W-1:0]         i_param_baseaddr  ;
    input  [C_M_AXI_ADDR_W-1:0]         i_infmap_baseaddr  ;
    
    // fifo Hand Shake
    output [C_M_AXI_DATA_W-1:0]         o_r_din         ;
    input                               i_r_full_n      ;
    output                              o_r_write       ;
    
    output                              o_r_rd_param  ;
    output                              o_r_rd_infmap ;
    
//==============================================================================
// Declaration Submodule Port
//==============================================================================
    wire                       c_fifo_i_s_valid ;
    wire                       c_fifo_o_s_ready ;
    wire [NUM_AR_LEN_BW-1 : 0] c_fifo_i_s_data  ;
    wire                       c_fifo_o_m_valid ;
    wire                       c_fifo_i_m_ready ;
    wire [NUM_AR_LEN_BW-1 : 0] c_fifo_o_m_data  ;

//==============================================================================
// To prevent confuse I/F.
//==============================================================================
    wire                       w_m_valid ;
    wire                       w_m_ready ;
    wire  [C_M_AXI_DATA_W-1:0] w_m_data  ;
    
    assign w_m_valid = i_m_axi_R_VALID;
    assign w_m_ready = i_r_full_n ;
    assign w_m_data = i_m_axi_R_DATA;

//==============================================================================
// Register and invert reset signal.
//==============================================================================
    reg r_ap_rst;
    always @(posedge ap_clk) begin
      r_ap_rst <= ~ap_rst_n;
    end

//==============================================================================
// Fixed AXI4 port 
//==============================================================================
    assign o_m_axi_AR_ID     = 1'b0 ;
    assign o_m_axi_AR_SIZE   = 3'b011; // Burst Size : 8 Bytes. 2^3
    assign o_m_axi_AR_BURST  = 2'b01 ; // Burst Type : INCR
    assign o_m_axi_AR_LOCK   = 2'b0 ;
    assign o_m_axi_AR_CACHE  = 4'b0 ;
    assign o_m_axi_AR_PROT   = 3'b0 ;
    assign o_m_axi_AR_QOS    = 4'b0 ;
    assign o_m_axi_AR_REGION = 4'b0 ;
    assign o_m_axi_AR_USER   = 1'b0 ;

//==============================================================================
// Declaration FSM
//==============================================================================
    reg  [1:0] c_state    , n_state     ; 
    reg  [1:0] c_state_ar , n_state_ar  ; 
    reg  [1:0] c_state_r  , n_state_r   ; 
    
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            c_state     <= S_IDLE;
            c_state_ar  <= S_IDLE;
            c_state_r   <= S_IDLE;
        end else begin
            c_state     <= n_state;
            c_state_ar  <= n_state_ar;
            c_state_r   <= n_state_r;
        end
    end
    
    wire w_s_idle = (c_state == S_IDLE) ;
    wire w_s_pre  = (c_state == S_PRE)  ;
    wire w_s_run  = (c_state == S_RUN)  ;
    wire w_s_done = (c_state == S_DONE) ;   
    
    wire  w_is_run;  
    wire  w_is_done;
    
//==============================================================================
// latching input data
//==============================================================================
    reg  [C_M_AXI_ADDR_W-1:0] r_param_baseaddr; 
    reg  [C_M_AXI_ADDR_W-1:0] r_infmap_baseaddr; 
    reg  r_ap_rd_cnn_param ;
    reg  r_ap_infmap_valid ;
    
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            r_param_baseaddr  <= 'b0;
            r_infmap_baseaddr <= 'b0;
        end else if (w_is_run) begin
            r_param_baseaddr  <= i_param_baseaddr ;
            r_infmap_baseaddr <= i_infmap_baseaddr ;
        end
    end
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (o_ap_done)) begin
            r_ap_rd_cnn_param  <= 'b0;
            r_ap_infmap_valid  <= 'b0;
        end else if (w_is_run) begin
            r_ap_rd_cnn_param  <= i_ap_rd_cnn_param ; 
            r_ap_infmap_valid  <= i_ap_infmap_valid ; 
        end
    end
    
    
    reg  [C_M_AXI_ADDR_W-1:0] r_real_base_addr;
    reg  [C_M_AXI_ADDR_W-1:0] r_num_total_stream_hs;
    
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            r_real_base_addr        <= 'b0;
            r_num_total_stream_hs   <= 'b0;
        end else if (w_s_pre) begin
            if(r_ap_rd_cnn_param) begin
                r_real_base_addr <= r_param_baseaddr ;
                r_num_total_stream_hs <= NUM_RD_PARAM ;
            end else if(r_ap_infmap_valid) begin
                r_real_base_addr <= r_infmap_baseaddr ;
                r_num_total_stream_hs <= NUM_RD_INFMAP ;
            end 
        end
    end
    
//==============================================================================
// Handshake AR, R Channel
//==============================================================================
    wire w_ar_hs;
    wire w_r_hs;
    
    assign w_ar_hs = (o_m_axi_AR_VALID) && (i_m_axi_AR_READY) ;
    assign w_r_hs  = (i_m_axi_R_VALID ) && (o_m_axi_R_READY ) ;
    
//==============================================================================
// AXI4 AR Channel 4k Boundary
//==============================================================================
    reg  [C_M_AXI_ADDR_W-1-NUM_AXI_DATA:0] r_hs_data_cnt;
    
    wire [C_M_AXI_ADDR_W-NUM_AXI_DATA-1 : 0] w_remain_hs      ;
    wire                                     w_is_max_burst   ;
    wire [NUM_AR_LEN_BW-1 : 0]               w_init_burst_len ; 
    
    wire [13-1 : 0]                w_addr_4k            ;
    wire [13-AXI_DATA_SHIFT-1 : 0] w_last_addr_in_burst ;
    wire [NUM_AR_LEN_BW-1 : 0]     w_boudary_burst_len  ;
    wire                           w_is_boundary_burst  ;
    wire [C_M_AXI_ADDR_W-1 : 0]    w_rdma_offset_addr   ;
    
    wire [NUM_AR_LEN_BW-1:0] w_burst_len_ar;
    
    wire [C_M_AXI_ADDR_W-1:0] w_m_axi_AR_ADDR;
    
    
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
            r_hs_data_cnt    <= 'b0;
        end else if (w_ar_hs) begin
            r_hs_data_cnt    <= r_hs_data_cnt + w_burst_len_ar;
        end
    end
    
    assign w_remain_hs      = r_num_total_stream_hs - r_hs_data_cnt;
    assign w_is_max_burst   = (w_remain_hs > NUM_MAX_BURST);
    assign w_init_burst_len = (w_is_max_burst) ? NUM_MAX_BURST : w_remain_hs; 
    
    assign w_addr_4k = 13'h1000;
    assign w_last_addr_in_burst = (w_m_axi_AR_ADDR[11:AXI_DATA_SHIFT] + w_init_burst_len);
    assign w_boudary_burst_len  = w_addr_4k[13-1:AXI_DATA_SHIFT] - w_m_axi_AR_ADDR[11:AXI_DATA_SHIFT];
    assign w_is_boundary_burst  = (w_last_addr_in_burst > w_addr_4k[13-1:AXI_DATA_SHIFT]);
    assign w_rdma_offset_addr   = {r_hs_data_cnt, {AXI_DATA_SHIFT{1'b0}}};
    
    assign w_burst_len_ar = (w_is_boundary_burst) ? (w_boudary_burst_len) : (w_init_burst_len) ;
    
    assign w_m_axi_AR_ADDR = r_real_base_addr + w_rdma_offset_addr;
    
//==============================================================================
// Ctrl of AXI4 AR channels
//==============================================================================
    reg  [C_M_AXI_ADDR_W-NUM_AXI_DATA-1 : 0] r_ar_hs_cnt;
    wire w_is_last_ar;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
            r_ar_hs_cnt    <= 'b0;
        end else if (w_ar_hs) begin
            r_ar_hs_cnt    <= r_ar_hs_cnt + w_burst_len_ar;
        end
    end
    assign w_is_last_ar = (r_ar_hs_cnt >= r_num_total_stream_hs);
    
    wire w_ar_fifo_full_n  ;
    wire w_ar_fifo_empty_n ;
    
    assign w_ar_fifo_full_n  = c_fifo_o_s_ready;
    assign w_ar_fifo_empty_n = c_fifo_o_m_valid;
    
    always @(*) begin
        n_state_ar = c_state_ar; 
        case(c_state_ar)
            S_IDLE : if(w_ar_fifo_full_n & (!w_is_last_ar) & w_s_run) n_state_ar = S_PRE;
            S_PRE  : n_state_ar = S_RUN;
            S_RUN  : if(w_ar_hs) n_state_ar = S_IDLE;
        endcase
    end 
    
    reg  [C_M_AXI_ADDR_W-1:0] r_m_axi_AR_ADDR;
    reg  [NUM_AR_LEN_BW-1:0] r_AR_LEN_ar;
    reg  [NUM_AR_LEN_BW-1:0] r_burst_len_ar;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
            r_m_axi_AR_ADDR <= 'b0;
            r_AR_LEN_ar     <= 'b0;
            r_burst_len_ar  <= 'b0;
        end else if (c_state_ar == S_PRE) begin
            r_m_axi_AR_ADDR <= w_m_axi_AR_ADDR;
            r_AR_LEN_ar     <= w_burst_len_ar - 1'b1;
            r_burst_len_ar  <= w_burst_len_ar;
        end
    end
    
//==============================================================================
// Ctrl of AXI4 R channels
//==============================================================================
    reg  [C_M_AXI_ADDR_W-NUM_AXI_DATA-1 : 0] r_r_hs_cnt;
    wire w_is_r_last_hs;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
            r_r_hs_cnt    <= 'b0;
        end else if (w_r_hs) begin
            r_r_hs_cnt    <= r_r_hs_cnt + 1'b1;
        end
    end
    assign w_is_r_last_hs = (r_r_hs_cnt == r_num_total_stream_hs-1);
    
    wire w_is_burst_done_r;
    assign w_is_burst_done_r = i_m_axi_R_LAST & w_r_hs;
    
    always @(*) begin
        n_state_r = c_state_r; 
        case(c_state_r)
            S_IDLE : if(w_ar_fifo_empty_n) n_state_r = S_RUN;
            S_RUN  : if(w_is_burst_done_r) begin
                    n_state_r = (w_ar_fifo_empty_n) ? (S_RUN) : (S_IDLE);
                end  
        endcase
    end 
    
    wire w_s_idle_r;
    wire w_fifo_read_r;
    
    assign w_s_idle_r    = (c_state_r == S_IDLE);
    assign w_fifo_read_r = (c_state_r == S_RUN) & w_is_burst_done_r;
    
    reg     [NUM_AR_LEN_BW-1:0] r_burst_cnt_r;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle_r) || (w_is_burst_done_r)) begin
            r_burst_cnt_r    <= 'b0;
        end else if (w_r_hs) begin
            r_burst_cnt_r    <= r_burst_cnt_r + 1'b1;
        end
    end
    
//==============================================================================
// Control Submodule Input Port: sync_fifo 
//==============================================================================
    assign c_fifo_i_s_valid = w_ar_hs ;
    assign c_fifo_i_s_data  = r_burst_len_ar ;
    assign c_fifo_i_m_ready = w_fifo_read_r ;

//==============================================================================
// Main Ctrl 
//==============================================================================
    wire w_ap_start = (i_ap_rd_cnn_param || i_ap_infmap_valid);
    
    //make w_is_run Signals (1 tick)
    reg  r_tick_ff;
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            r_tick_ff <= 0;
        end else begin
            r_tick_ff <= w_ap_start;
        end
    end
    
    // main state machine
    assign w_is_run = w_ap_start && (~r_tick_ff);
    assign w_is_done = w_r_hs && w_is_r_last_hs && i_m_axi_R_LAST;
    
    // State
    always @(*) begin
        n_state = c_state; 
        case(c_state)
            S_IDLE  : if(w_is_run) n_state = S_PRE;
            S_PRE   : n_state = S_RUN;
            S_RUN   : if(w_is_done) n_state = S_DONE;
            S_DONE  : n_state = S_IDLE;
        endcase
    end 
    
// //==============================================================================
// // Paremeter mem Address Counter
// //==============================================================================
//     reg  [B_ADDR_BW-1 : 0] r_b_addr_cnt ;
//     wire w_b_addr_cnt_valid ;
//     wire [10-1 : 0] w_b_addr_cnt_max_arr ;
//     reg  w_b_addr_cnt_max ;
    
//     reg  r_rd_c1_w_max ;
//     reg  r_rd_c1_d_max ;
//     reg  r_rd_c2_w_max ;
//     reg  r_rd_c2_d_max ;
//     reg  r_rd_fc1_w_max ;
//     reg  r_rd_fc1_d_max ;
//     reg  r_rd_fc2_w_max ;
//     reg  r_rd_fc2_d_max ;
//     reg  r_rd_fc3_w_max ;
//     reg  r_rd_fc3_d_max ;
    
//     always @(posedge ap_clk) begin
//         if((r_ap_rst) || (w_b_addr_cnt_max)) begin
//             r_b_addr_cnt <= 'b0;
//         end else if(w_b_addr_cnt_valid) begin
//             r_b_addr_cnt <= r_b_addr_cnt + 1;
//         end
//     end
    
//     assign w_b_addr_cnt_valid = w_m_valid && r_ap_rd_cnn_param && w_r_hs ;
    
//     always @(posedge ap_clk) begin
//         if(r_ap_rst) begin
//             r_rd_c1_w_max  <= 'b0;
//             r_rd_c1_d_max  <= 'b0;
//             r_rd_c2_w_max  <= 'b0;
//             r_rd_c2_d_max  <= 'b0;
//             r_rd_fc1_w_max <= 'b0;
//             r_rd_fc1_d_max <= 'b0;
//             r_rd_fc2_w_max <= 'b0;
//             r_rd_fc2_d_max <= 'b0;
//             r_rd_fc3_w_max <= 'b0;
//             r_rd_fc3_d_max <= 'b0;
//         end else begin
//             r_rd_c1_w_max  <= (r_b_addr_cnt == B_C1_W_DATA_D -2) && (o_ap_param_weight ) && (o_ap_layer_c1 );
//             r_rd_c1_d_max  <= (r_b_addr_cnt == B_C1_B_DATA_D -2) && (o_ap_param_bias   ) && (o_ap_layer_c1 );
//             r_rd_c2_w_max  <= (r_b_addr_cnt == B_C2_W_DATA_D -2) && (o_ap_param_weight ) && (o_ap_layer_c2 );
//             r_rd_c2_d_max  <= (r_b_addr_cnt == B_C2_B_DATA_D -2) && (o_ap_param_bias   ) && (o_ap_layer_c2 );
//             r_rd_fc1_w_max <= (r_b_addr_cnt == B_FC1_W_DATA_D-2) && (o_ap_param_weight ) && (o_ap_layer_fc1);
//             r_rd_fc1_d_max <= (r_b_addr_cnt == B_FC1_B_DATA_D-2) && (o_ap_param_bias   ) && (o_ap_layer_fc1);
//             r_rd_fc2_w_max <= (r_b_addr_cnt == B_FC2_W_DATA_D-2) && (o_ap_param_weight ) && (o_ap_layer_fc2);
//             r_rd_fc2_d_max <= (r_b_addr_cnt == B_FC2_B_DATA_D-2) && (o_ap_param_bias   ) && (o_ap_layer_fc2);
//             r_rd_fc3_w_max <= (r_b_addr_cnt == B_FC3_W_DATA_D-2) && (o_ap_param_weight ) && (o_ap_layer_fc3);
//             r_rd_fc3_d_max <= (r_b_addr_cnt == B_FC3_B_DATA_D-2) && (o_ap_param_bias   ) && (o_ap_layer_fc3);
//         end
//     end
    
//     assign w_b_addr_cnt_max_arr = {r_rd_c1_w_max, r_rd_c1_d_max, r_rd_c2_w_max, 
//         r_rd_c2_d_max, r_rd_fc1_w_max, r_rd_fc1_d_max, r_rd_fc2_w_max, 
//         r_rd_fc2_d_max, r_rd_fc3_w_max, r_rd_fc3_d_max};
        
//     assign w_b_addr_cnt_max = (|w_b_addr_cnt_max_arr) ;
    
//==============================================================================
// Assign output signal
//==============================================================================
    assign o_ap_idle = w_s_idle;
    assign o_ap_ready = w_s_pre; 
    assign o_ap_done = w_s_done;
    
    assign o_m_axi_AR_LEN   = r_AR_LEN_ar[7:0];
    assign o_m_axi_AR_VALID = (c_state_ar == S_RUN);
    assign o_m_axi_AR_ADDR  = r_m_axi_AR_ADDR;
    
    assign o_r_write       = w_m_valid  ;
    assign o_m_axi_R_READY = w_m_ready  ;
    assign o_r_din         = w_m_data   ;
    
    assign o_r_rd_param  = r_ap_rd_cnn_param ;
    assign o_r_rd_infmap = r_ap_infmap_valid ;
 
//==============================================================================
// Instantiation Submodule
//==============================================================================
    sync_fifo #(
        .FIFO_S_REG (0 ) ,
        .FIFO_M_REG (0 ) ,
        .FIFO_W     (NUM_AR_LEN_BW     ) ,
        .FIFO_D     (NUM_AXI_AR_MOR_REQ     ) 
    ) u_sync_fifo (
        .clk       (ap_clk       ) ,
        .areset    (r_ap_rst   ) ,
        .i_s_valid (c_fifo_i_s_valid ) ,
        .o_s_ready (c_fifo_o_s_ready ) ,
        .i_s_data  (c_fifo_i_s_data  ) ,
        .o_m_valid (c_fifo_o_m_valid ) ,
        .i_m_ready (c_fifo_i_m_ready ) ,
        .o_m_data  (c_fifo_o_m_data  ) ,
        .o_empty   (   ) ,
        .o_full    (    ) 
    );

endmodule
