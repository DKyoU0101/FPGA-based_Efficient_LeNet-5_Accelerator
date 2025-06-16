//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.02.14
// Design Name: 
// Module Name: chapter4
// Project Name: skid_buffer
// Target Devices: 
// Tool Versions: Vivado/Vitis 2022.2
// Description: Handshake I/F skid buffer
// Dependencies: 
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module skid_buffer #(
    parameter DATA_WIDTH = 8
) (
    clk        ,
    areset     ,
    i_s_valid  ,
    o_s_ready  ,
    i_s_data   ,
    o_m_valid  ,
    i_m_ready  ,
    o_m_data   
);

// FSM 
localparam S_PIPE  = 1'b0 ; /* Stage where data is piped out or stored to temp buffer */
localparam S_SKID  = 1'b1 ; /* Stage to wait after data skid happened */

//==============================================================================
// Input/Output declaration
//==============================================================================
input                    clk     ;
input                    areset  ;

input                    i_s_valid ;
output                   o_s_ready ;
input  [DATA_WIDTH-1:0]  i_s_data  ;

output                   o_m_valid ;
input                    i_m_ready ;
output [DATA_WIDTH-1:0]  o_m_data  ;

//==============================================================================
// Main
//==============================================================================

wire w_ready         ;
assign w_ready = (i_m_ready) || ((~o_m_valid)) ;

reg c_state;
reg n_state;
always @(posedge clk) begin
    if(areset) c_state <= S_PIPE;
    else begin
        c_state <= n_state;
    end	
end

reg                     r_m_valid       ;
reg  [DATA_WIDTH-1 : 0] r_m_data        ;
reg                     r_m_valid_temp  ;
reg  [DATA_WIDTH-1 : 0] r_m_data_temp   ;
reg                     r_s_ready       ;

reg                     w_m_valid       ;
reg  [DATA_WIDTH-1 : 0] w_m_data        ;
reg                     w_m_valid_temp  ;
reg  [DATA_WIDTH-1 : 0] w_m_data_temp   ;
reg                     w_s_ready       ;

always @(posedge clk) begin
    if(areset) begin
        r_m_valid      <= 1'b0;
        r_m_data       <= {DATA_WIDTH{1'b0}};
        r_m_valid_temp <= 1'b0;
        r_m_data_temp  <= {DATA_WIDTH{1'b0}};
        r_s_ready      <= 1'b0;
    end else begin
        r_m_valid      <= w_m_valid      ;
        r_m_data       <= w_m_data       ;
        r_m_valid_temp <= w_m_valid_temp ;
        r_m_data_temp  <= w_m_data_temp  ;
        r_s_ready      <= w_s_ready      ;
    end
end
always @(*) begin
    n_state        = c_state        ;
    w_m_valid      = r_m_valid      ;
    w_m_data       = r_m_data       ;
    w_m_valid_temp = r_m_valid_temp ;
    w_m_data_temp  = r_m_data_temp  ;
    w_s_ready      = r_s_ready      ;
    case (c_state)
        S_PIPE : begin
            if(w_ready) begin
                n_state   = S_PIPE    ;
                w_m_valid = i_s_valid ;
                w_m_data  = i_s_data  ;
                w_s_ready = 1'b1      ;
            end else begin
                n_state        = S_SKID    ;
                w_m_valid_temp = i_s_valid ;
                w_m_data_temp  = i_s_data  ;
                w_s_ready      = 1'b0      ;
            end
        end
        S_SKID : begin
            if(w_ready) begin
                n_state   = S_PIPE    ;
                w_m_valid = r_m_valid_temp ;
                w_m_data  = r_m_data_temp  ;
                w_s_ready = 1'b1      ;
            end
        end
    endcase
end


assign o_s_ready = r_s_ready         ;
assign o_m_valid = r_m_valid         ;
assign o_m_data  = r_m_data          ;


endmodule