//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.05.04
// Design Name: 
// Module Name: wdma
// Project Name: chapter20
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: WDMA (AXI4 AW, W, B Channel)
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module wdma #(
    parameter C_M_AXI_ID_W      = 1  ,
    parameter C_M_AXI_ADDR_W    = 32 ,
    parameter C_M_AXI_DATA_W    = 64 ,
    parameter C_M_AXI_AW_USER_W = 1  ,
    parameter C_M_AXI_W_USER_W  = 1  ,
    parameter C_M_AXI_B_USER_W  = 1  
) (
    ap_clk   ,
    ap_rst_n ,
    i_ap_start ,
    o_ap_done  ,
    o_ap_idle  ,
    o_ap_ready ,
    o_m_axi_AW_VALID  ,
    i_m_axi_AW_READY  ,
    o_m_axi_AW_ADDR   ,
    o_m_axi_AW_ID     ,
    o_m_axi_AW_LEN    ,
    o_m_axi_AW_SIZE   ,
    o_m_axi_AW_BURST  ,
    o_m_axi_AW_LOCK   ,
    o_m_axi_AW_CACHE  ,
    o_m_axi_AW_PROT   ,
    o_m_axi_AW_QOS    ,
    o_m_axi_AW_REGION ,
    o_m_axi_AW_USER   ,
    o_m_axi_W_VALID ,
    i_m_axi_W_READY ,
    o_m_axi_W_DATA  ,
    o_m_axi_W_STRB  ,
    o_m_axi_W_LAST  ,
    o_m_axi_W_ID    ,
    o_m_axi_W_USER  ,
    i_m_axi_B_VALID   ,
    o_m_axi_W_READY   ,
    i_m_axi_B_RESP    ,
    i_m_axi_B_ID      ,
    i_m_axi_B_USER    ,
    // i_transfer_byte ,
    i_mem_baseaddr  ,
    i_r_dout        ,
    i_r_empty_n     ,
    o_r_read        
);

//==============================================================================
// Local Parameter declaration
//==============================================================================
    localparam C_M_AXI_W_STRB_W = (C_M_AXI_DATA_W / 8);
    
    localparam S_IDLE   = 2'b00;
    localparam S_RUN   = 2'b01;
    localparam S_PRE   = 2'b10;  // Prepare Data
    localparam S_DONE   = 2'b11;
    
    localparam NUM_AXI_DATA = C_M_AXI_DATA_W / 8; // 8
    localparam AXI_DATA_SHIFT = $clog2(NUM_AXI_DATA); // 3
    localparam NUM_AXI_AW_MOR_REQ = 8'd4;
    localparam LOG_NUM_AXI_AW_MOR_REQ = $clog2(NUM_AXI_AW_MOR_REQ) + 1;
    
    localparam NUM_MAX_BURST = 16;
    localparam NUM_AW_LEN_BW = 9;
    
    
//==============================================================================
// Input/Output declaration
//==============================================================================
    input  ap_clk   ;
    input  ap_rst_n ;
    
    // ap_ctrl signals
    input  i_ap_start ;
    output o_ap_done  ;
    output o_ap_idle  ;
    output o_ap_ready ;
    
    // AW Channel
    output                              o_m_axi_AW_VALID  ;
    input                               i_m_axi_AW_READY  ;
    output  [C_M_AXI_ADDR_W - 1:0]      o_m_axi_AW_ADDR   ;
    output  [C_M_AXI_ID_W - 1:0]        o_m_axi_AW_ID     ;
    output  [7:0]                       o_m_axi_AW_LEN    ;
    output  [2:0]                       o_m_axi_AW_SIZE   ;
    output  [1:0]                       o_m_axi_AW_BURST  ;
    output  [1:0]                       o_m_axi_AW_LOCK   ;
    output  [3:0]                       o_m_axi_AW_CACHE  ;
    output  [2:0]                       o_m_axi_AW_PROT   ;
    output  [3:0]                       o_m_axi_AW_QOS    ;
    output  [3:0]                       o_m_axi_AW_REGION ;
    output  [C_M_AXI_AW_USER_W - 1:0]   o_m_axi_AW_USER   ;
    
    // W Channel
    output                           o_m_axi_W_VALID ;
    input                            i_m_axi_W_READY ;
    output  [C_M_AXI_DATA_W - 1:0]   o_m_axi_W_DATA  ;
    output  [C_M_AXI_W_STRB_W - 1:0] o_m_axi_W_STRB  ; // full use wdata.
    output                           o_m_axi_W_LAST  ;
    output  [C_M_AXI_ID_W - 1:0]     o_m_axi_W_ID    ;
    output  [C_M_AXI_W_USER_W - 1:0] o_m_axi_W_USER  ;
    
    // B Channel
    input                           i_m_axi_B_VALID   ;
    output                          o_m_axi_W_READY   ;
    input  [1:0]                    i_m_axi_B_RESP    ;
    input  [C_M_AXI_ID_W - 1:0]     i_m_axi_B_ID      ;
    input  [C_M_AXI_B_USER_W - 1:0] i_m_axi_B_USER    ;
    
    // input parameter
    // input  [C_M_AXI_ADDR_W-1:0] i_transfer_byte ;
    input  [C_M_AXI_ADDR_W-1:0] i_mem_baseaddr  ;
    
    // fifo Hand Shake
    input  [C_M_AXI_DATA_W-1:0] i_r_dout        ;
    input                       i_r_empty_n     ;
    output                      o_r_read        ;
    
//==============================================================================
// Declaration Submodule Port
//==============================================================================
    wire                       c_aw2w_i_s_valid ;
    wire                       c_aw2w_o_s_ready ;
    wire [NUM_AW_LEN_BW-1 : 0] c_aw2w_i_s_data  ;
    wire                       c_aw2w_o_m_valid ;
    wire                       c_aw2w_i_m_ready ;
    wire [NUM_AW_LEN_BW-1 : 0] c_aw2w_o_m_data  ;
    
    wire                       c_w2b_i_s_valid ;
    wire                       c_w2b_o_s_ready ;
    wire [NUM_AW_LEN_BW-1 : 0] c_w2b_i_s_data  ;
    wire                       c_w2b_o_m_valid ;
    wire                       c_w2b_i_m_ready ;
    wire [NUM_AW_LEN_BW-1 : 0] c_w2b_o_m_data  ;
    
//==============================================================================
// To prevent confuse I/F.
//==============================================================================
    wire                        w_s_valid ;
    wire                        w_s_ready ;
    wire  [C_M_AXI_DATA_W-1:0]  w_s_data  ;
    
    assign w_s_valid = i_r_empty_n;
    assign w_s_ready = i_m_axi_W_READY;
    assign w_s_data  = i_r_dout;
    
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
    assign o_m_axi_AW_ID      = 1'b0;
    assign o_m_axi_AW_SIZE    = 3'b011; // Burst Size : 8 Bytes. 2^3
    assign o_m_axi_AW_BURST   = 2'b01 ; // Burst Type : INCR
    assign o_m_axi_AW_LOCK    = 2'b0  ;
    assign o_m_axi_AW_CACHE   = 4'b0  ;
    assign o_m_axi_AW_PROT    = 3'b0  ;
    assign o_m_axi_AW_QOS     = 4'b0  ;
    assign o_m_axi_AW_REGION  = 4'b0  ;
    assign o_m_axi_AW_USER    = 1'b0  ;
    assign o_m_axi_W_ID       = 1'b0  ;
    assign o_m_axi_W_USER     = 1'b0  ;
    assign o_m_axi_W_STRB     = {C_M_AXI_W_STRB_W{1'b1}};
    
//==============================================================================
// Declaration FSM
//==============================================================================
    reg  [1:0] c_state    , n_state     ; 
    reg  [1:0] c_state_aw , n_state_aw  ; 
    reg  [1:0] c_state_w  , n_state_w   ; 
    reg  [1:0] c_state_b  , n_state_b   ; 
    
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            c_state     <= S_IDLE;
            c_state_aw  <= S_IDLE;
            c_state_w   <= S_IDLE;
            c_state_b   <= S_IDLE;
        end else begin
            c_state     <= n_state;
            c_state_aw  <= n_state_aw;
            c_state_w   <= n_state_w;
            c_state_b   <= n_state_b;
        end
    end
    
    wire      w_is_run;  
    wire      w_is_done;
    
    wire w_s_idle = (c_state == S_IDLE);
    wire w_s_pre  = (c_state == S_PRE);
    wire w_s_run  = (c_state == S_RUN);
    wire w_s_done = (c_state == S_DONE);

//==============================================================================
// latching input data
//==============================================================================
    reg  [C_M_AXI_ADDR_W-1:0] r_wdma_baseaddr;
    
    always @(posedge ap_clk) begin
      if(r_ap_rst) begin
        r_wdma_baseaddr <= 'b0;
      end else if (w_is_run) begin
        r_wdma_baseaddr <= i_mem_baseaddr   ;
        end
    end
    
    reg   [C_M_AXI_ADDR_W-1:0] r_real_base_addr;
    reg   [C_M_AXI_ADDR_W-NUM_AXI_DATA-1:0] r_num_total_stream_hs;
    
    always @(posedge ap_clk) begin
      if(r_ap_rst) begin
        r_real_base_addr        <= 'b0;
        r_num_total_stream_hs   <= 'b0;
      end else if (w_s_pre) begin
        r_real_base_addr        <= r_wdma_baseaddr     ;
        r_num_total_stream_hs   <= 'b1 ;
        end
    end

//==============================================================================
// Handshake AW, W, B Channel
//==============================================================================
    wire w_aw_hs;
    wire w_w_hs;
    wire w_b_hs;
    
    assign w_aw_hs = o_m_axi_AW_VALID & i_m_axi_AW_READY;
    assign w_w_hs = o_m_axi_W_VALID & i_m_axi_W_READY;
    assign w_b_hs = o_m_axi_W_READY & i_m_axi_B_VALID;

//==============================================================================
// AXI4 AW Channel 4k Boundary
//==============================================================================
    reg   [C_M_AXI_ADDR_W-NUM_AXI_DATA-1:0] r_hs_data_cnt;  

    wire [C_M_AXI_ADDR_W-NUM_AXI_DATA-1 : 0] w_remain_hs      ;
    wire                                     w_is_max_burst   ;
    wire [NUM_AW_LEN_BW-1 : 0]               w_init_burst_len ; 
    
    wire [13-1 : 0]                w_addr_4k            ;
    wire [13-AXI_DATA_SHIFT-1 : 0] w_last_addr_in_burst ;
    wire [NUM_AW_LEN_BW-1 : 0]     w_boudary_burst_len  ;
    wire                           w_is_boundary_burst  ;
    wire [C_M_AXI_ADDR_W-1 : 0]    w_wdma_offset_addr   ;
    
    wire [NUM_AW_LEN_BW-1:0] w_burst_len_aw;
    
    wire [C_M_AXI_ADDR_W-1:0] w_m_axi_AW_ADDR;
    
    
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
            r_hs_data_cnt  <= 'b0;
        end else if (w_aw_hs) begin
            r_hs_data_cnt  <= r_hs_data_cnt + w_burst_len_aw;
        end
    end
    
    assign w_remain_hs      = r_num_total_stream_hs - r_hs_data_cnt;
    assign w_is_max_burst   = (w_remain_hs > NUM_MAX_BURST);
    assign w_init_burst_len = (w_is_max_burst) ? NUM_MAX_BURST : w_remain_hs; 
    
    assign w_addr_4k = 13'h1000;
    assign w_last_addr_in_burst = (w_m_axi_AW_ADDR[11:AXI_DATA_SHIFT] + w_init_burst_len);
    assign w_boudary_burst_len  = w_addr_4k[13-1:AXI_DATA_SHIFT] - w_m_axi_AW_ADDR[11:AXI_DATA_SHIFT];
    assign w_is_boundary_burst  = (w_last_addr_in_burst > w_addr_4k[13-1:AXI_DATA_SHIFT]);
    assign w_wdma_offset_addr   = {r_hs_data_cnt, {AXI_DATA_SHIFT{1'b0}}};
    
    assign w_burst_len_aw = (w_is_boundary_burst) ? (w_boudary_burst_len) : (w_init_burst_len);
    
    assign w_m_axi_AW_ADDR = r_real_base_addr + w_wdma_offset_addr;
    
//==============================================================================
// Ctrl of AXI4 AW channels
//==============================================================================
    reg   [C_M_AXI_ADDR_W-NUM_AXI_DATA-1:0] r_aw_hs_cnt;
    wire w_is_last_aw;
    
    always @(posedge ap_clk) begin
      if(r_ap_rst) begin
        r_aw_hs_cnt  <= 'b0;
      end else if (w_s_idle) begin
        r_aw_hs_cnt  <= 'b0;
      end else if (w_aw_hs) begin
        r_aw_hs_cnt  <= r_aw_hs_cnt + w_burst_len_aw;
      end
    end
    assign w_is_last_aw = r_aw_hs_cnt >= r_num_total_stream_hs;
    
    wire w_aw_fifo_full_n;
    wire w_aw_fifo_empty_n;
    
    assign w_aw_fifo_full_n  = c_aw2w_o_s_ready;
    assign w_aw_fifo_empty_n = c_aw2w_o_m_valid;

    always @(*) begin
      n_state_aw = c_state_aw; 
      case(c_state_aw)
      S_IDLE  : if(w_aw_fifo_full_n & (!w_is_last_aw) & w_s_run)
            n_state_aw = S_PRE;
      S_PRE  : n_state_aw = S_RUN;
      S_RUN   : if(w_aw_hs)
            n_state_aw = S_IDLE;
      endcase
    end 
    
    reg  [C_M_AXI_ADDR_W-1:0] r_m_axi_AW_ADDR;
    reg  [NUM_AW_LEN_BW-1:0] r_AWLEN_aw;
    reg  [NUM_AW_LEN_BW-1:0] r_burst_len_aw;
    
    reg  r_s_valid ;
    reg  [C_M_AXI_DATA_W-1:0]  r_s_data ;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
        r_m_axi_AW_ADDR  <= 'b0;
        r_AWLEN_aw       <= 'b0;
        r_burst_len_aw   <= 'b0;
      end else if (c_state_aw == S_PRE) begin
        r_m_axi_AW_ADDR  <= w_m_axi_AW_ADDR + {r_s_data[24-1 : 4], 3'b000};
        r_AWLEN_aw       <= w_burst_len_aw - 1'b1;
        r_burst_len_aw   <= w_burst_len_aw;
      end
    end

//==============================================================================
// Ctrl of AXI4 W channels
//==============================================================================
    reg   [C_M_AXI_ADDR_W-NUM_AXI_DATA-1:0] r_w_hs_cnt;
    wire w_is_w_last_hs;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle)) begin
        r_w_hs_cnt  <= 'b0;
      end else if (w_w_hs) begin
        r_w_hs_cnt  <= r_w_hs_cnt + 1'b1;
      end
    end
    assign w_is_w_last_hs = (r_w_hs_cnt + 1)  >= r_num_total_stream_hs;
    
    wire w_w_fifo_full_n    ;
    wire w_w_fifo_empty_n   ;
    
    assign w_w_fifo_full_n  = c_w2b_o_s_ready;
    assign w_w_fifo_empty_n = c_w2b_o_m_valid;
    
    // temp
    //------------------------------------------------------
    reg  r_aw_valid;
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_w_hs)) begin
            r_aw_valid  <= 'b0;
        end else if (o_m_axi_AW_VALID) begin
            r_aw_valid  <= 1'b1;
        end
    end
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_w_hs)) begin
            r_s_valid  <= 'b0;
            r_s_data  <= 'b0;
        end else if (w_s_valid) begin
            r_s_valid  <= 1'b1;
            r_s_data  <= i_r_dout;
        end
    end
    
    reg  r_w_valid;
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_w_hs)) begin
            r_w_valid  <= 'b0;
        end else if (r_aw_valid & r_s_valid) begin
            r_w_valid  <= 1'b1;
        end
    end
    
    //------------------------------------------------------
    
    wire w_is_aw_req_pre;
    wire w_is_burst_done_w;
    
    wire w_is_burst_last_w;
    
    assign w_is_aw_req_pre = w_aw_fifo_empty_n & w_w_fifo_full_n & w_s_run & r_aw_valid;
    assign w_is_burst_done_w = w_is_burst_last_w & w_w_hs;
    
    always @(*) begin
        n_state_w = c_state_w; 
        case(c_state_w)
            S_IDLE  : if(w_is_aw_req_pre) n_state_w = S_RUN;
            S_RUN   : if(w_is_burst_done_w) begin
                    n_state_w = (w_is_aw_req_pre) ? (S_RUN) : (S_IDLE);
              end 
        endcase
    end 
    
    wire w_s_idle_w;
    wire w_s_run_w;
    wire w_fifo_read_w;
    
    assign w_s_idle_w  = (c_state_w == S_IDLE);
    assign w_s_run_w   = (c_state_w == S_RUN);
    // assign w_fifo_read_w = (w_s_idle_w | w_is_burst_done_w) & w_is_aw_req_pre ;
    assign w_fifo_read_w = w_is_burst_done_w; // (chapter 20)

    reg   [NUM_AW_LEN_BW-1:0] r_burst_cnt_w;
    
    always @(posedge ap_clk) begin
        if((r_ap_rst) || (w_s_idle_w) || (w_is_burst_done_w)) begin
            r_burst_cnt_w  <= 'b0;
        end else if (w_w_hs) begin
            r_burst_cnt_w  <= r_burst_cnt_w + 1'b1;
        end
    end
    
    // assign w_is_burst_last_w = (r_burst_cnt_w+1 == r_burst_len_w);
    assign w_is_burst_last_w = (r_burst_cnt_w+1 == c_aw2w_o_m_data); // (chapter 20)
    
//==============================================================================
// Ctrl of AXI4 B channels
//==============================================================================
    wire w_fifo_read_b;
    reg  [NUM_AW_LEN_BW-1:0] r_burst_len_b;
    
    assign w_fifo_read_b = (c_state_b == S_PRE);
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
        r_burst_len_b <= S_IDLE;
        end else if (w_fifo_read_b) begin
        r_burst_len_b <= c_w2b_o_m_data;
        end
    end
    
    reg  [C_M_AXI_ADDR_W-NUM_AXI_DATA-1:0] r_b_hs_cnt;
    wire w_is_b_last_hs;
    
    always @(posedge ap_clk) begin
      if(r_ap_rst) begin
        r_b_hs_cnt  <= 'b0;
      end else if (w_s_idle) begin
        r_b_hs_cnt  <= 'b0;
      end else if (w_b_hs) begin
        r_b_hs_cnt  <= r_b_hs_cnt + r_burst_len_b;
      end
    end
    assign w_is_b_last_hs = (r_b_hs_cnt + r_burst_len_b)  >= r_num_total_stream_hs;

    always @(*) begin
      n_state_b = c_state_b; 
      case(c_state_b)
      S_IDLE  : if(w_w_fifo_empty_n & w_s_run)
            n_state_b = S_PRE;
      S_PRE  : n_state_b = S_RUN;
      S_RUN   : if(w_b_hs)
            n_state_b = S_IDLE;
      endcase
    end 

    wire w_s_run_b;
    
    assign w_s_run_b   = (c_state_b == S_RUN);

//==============================================================================
// Control Submodule Input Port: u_sync_fifo_aw2w 
//==============================================================================
    assign c_aw2w_i_s_valid = w_aw_hs ;
    assign c_aw2w_i_s_data  = r_burst_len_aw ;
    assign c_aw2w_i_m_ready = w_fifo_read_w ;

//==============================================================================
// Control Submodule Input Port: u_sync_fifo_w2b 
//==============================================================================
    assign c_w2b_i_s_valid = w_is_burst_done_w ;
    assign c_w2b_i_s_data  = c_aw2w_o_m_data ;
    assign c_w2b_i_m_ready = w_fifo_read_b ;

//==============================================================================
// Main Ctrl 
//==============================================================================
//make w_is_run Signals (1 tick)
    reg r_tick_ff;
    always @(posedge ap_clk) begin
        if(r_ap_rst) begin
            r_tick_ff <= 0;
        end else begin
            r_tick_ff <= i_ap_start;
        end
    end
    
    // main state machine
    assign w_is_run = i_ap_start && (~r_tick_ff);
    assign w_is_done = w_b_hs && w_is_b_last_hs; // wait last b hand shake
    
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
    
//==============================================================================
// Assign output signal
//==============================================================================
    assign o_ap_done = w_s_done;
    assign o_ap_idle = w_s_idle;
    assign o_ap_ready = w_s_pre; 
    
    assign o_m_axi_AW_LEN   = r_AWLEN_aw[7:0];
    assign o_m_axi_AW_VALID = (c_state_aw == S_RUN); 
    assign o_m_axi_AW_ADDR  = r_m_axi_AW_ADDR;
    
    assign o_m_axi_W_VALID = r_w_valid;
    assign o_r_read        = w_s_ready;
    assign o_m_axi_W_DATA  = r_s_data;
    
    assign o_m_axi_W_READY = w_s_run_b;
    assign o_m_axi_W_LAST  = w_is_burst_last_w;
    
    
//==============================================================================
// Instantiation Submodule
//==============================================================================
    sync_fifo #(
        .FIFO_S_REG (0 ) ,
        .FIFO_M_REG (0 ) ,
        .FIFO_W     (NUM_AW_LEN_BW     ) ,
        .FIFO_D     (NUM_AXI_AW_MOR_REQ     ) 
    ) u_sync_fifo_aw2w (
        .clk       (ap_clk       ) ,
        .areset    (r_ap_rst   ) ,
        .i_s_valid (c_aw2w_i_s_valid  ) ,
        .o_s_ready (c_aw2w_o_s_ready  ) ,
        .i_s_data  (c_aw2w_i_s_data   ) ,
        .o_m_valid (c_aw2w_o_m_valid  ) ,
        .i_m_ready (c_aw2w_i_m_ready  ) ,
        .o_m_data  (c_aw2w_o_m_data   ) ,
        .o_empty   (   ) ,
        .o_full    (    ) 
    );
    
    sync_fifo #(
        .FIFO_S_REG (0 ) ,
        .FIFO_M_REG (0 ) ,
        .FIFO_W     (NUM_AW_LEN_BW     ) ,
        .FIFO_D     (NUM_AXI_AW_MOR_REQ     ) 
    ) u_sync_fifo_w2b (
        .clk       (ap_clk       ) ,
        .areset    (r_ap_rst   ) ,
        .i_s_valid (c_w2b_i_s_valid  ) ,
        .o_s_ready (c_w2b_o_s_ready  ) ,
        .i_s_data  (c_w2b_i_s_data   ) ,
        .o_m_valid (c_w2b_o_m_valid  ) ,
        .i_m_ready (c_w2b_i_m_ready  ) ,
        .o_m_data  (c_w2b_o_m_data   ) ,
        .o_empty   (   ) ,
        .o_full    (    ) 
    );
    
    
endmodule