//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.01.30
// Design Name: LeNet-5
// Module Name: parallel_mult
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Multiplier Parallelization
//                  input : in0[MULT_OPS*IN_DATA_BW], in1[MULT_OPS*IN_DATA_BW]
//                  output: result[MULT_OPS*OT_DATA_BW]
//                      result = in0 * in1
//                  latency: 1 cycle(avarage: 1 cycle), delay = 3 cycle
//                          (random seed:1, LOOP_NUM:1,000)
// Dependencies: "Review of deep learning: concepts, CNN architectures, 
//                  challenges, applications, future directions"
//               - Fig. 14 The architecture of LeNet
// Revision 0.01 - File Created
//          0.1(25.03.06) - input data: unsigned -> signed, reset_n -> areset
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "timescale.vh"
module parallel_mult #(
    parameter MULT_OPS      = 60 ,
    parameter MULT_DELAY    = 3  ,
    parameter IN_DATA_BW    = 8  
    ) ( 
    clk          ,
    areset       ,
    i_run        ,
    o_idle       ,
    o_run        ,
    o_n_ready    ,
    i_in0        ,
    i_in1        ,
    o_valid      ,
    o_result     
);
// `include "defines_parameter.vh"

//==============================================================================
// Local Parameter declaration
//==============================================================================
localparam OT_DATA_BW = 2 * IN_DATA_BW ; // 16

// delay
localparam DELAY = MULT_DELAY;

//==============================================================================
// Input/Output declaration
//==============================================================================
input                                     clk             ;
input                                     areset          ;

input                                     i_run           ;

output                                    o_idle          ;
output                                    o_run           ;
output                                    o_n_ready       ;

input  signed [MULT_OPS*IN_DATA_BW-1 : 0] i_in0           ;
input  signed [MULT_OPS*IN_DATA_BW-1 : 0] i_in1           ;

output                                    o_valid         ;
output signed [MULT_OPS*OT_DATA_BW-1 : 0] o_result        ;


//==============================================================================
// Capture Input Run Signal
//==============================================================================
reg [DELAY-1 : 0] r_run;
always @(posedge clk) begin
    if(areset) begin
        r_run <= {DELAY{1'b0}};
    end else begin
        r_run <= {r_run[DELAY-2:0], i_run};
    end
end

//==============================================================================
// Instance Module: gen_mult_s8_3dly_lut 
//==============================================================================
wire                           c_mult_i_sclr [0 : MULT_OPS-1] ;
wire                           c_mult_i_ce   [0 : MULT_OPS-1] ;
wire signed [IN_DATA_BW-1 : 0] c_mult_i_in0  [0 : MULT_OPS-1] ;
wire signed [IN_DATA_BW-1 : 0] c_mult_i_in1  [0 : MULT_OPS-1] ;
wire signed [MULT_OPS*OT_DATA_BW-1 : 0] c_mult_o_out   ;

genvar mult_idx;
generate
    for (mult_idx = 0; mult_idx < MULT_OPS; mult_idx = mult_idx + 1) begin : gen_mult_inst
        
        assign c_mult_i_sclr [mult_idx] = areset ;
        assign c_mult_i_ce   [mult_idx] = 1'b1;
        assign c_mult_i_in0  [mult_idx] = i_in0[mult_idx*IN_DATA_BW +: IN_DATA_BW];
        assign c_mult_i_in1  [mult_idx] = i_in1[mult_idx*IN_DATA_BW +: IN_DATA_BW];
        
        gen_mult_s8_3dly_lut gen_mult_s8_3dly_lut (
            .CLK    (clk        ),
            .SCLR   (c_mult_i_sclr [mult_idx] ),
            .CE     (c_mult_i_ce   [mult_idx] ),
        	.A      (c_mult_i_in0  [mult_idx] ),
            .B      (c_mult_i_in1  [mult_idx] ),
            .P      (c_mult_o_out  [mult_idx*OT_DATA_BW +: OT_DATA_BW]  )
        );
    end
endgenerate


// assign output signal
assign o_idle    = !(r_run);
assign o_run     = |(r_run);
assign o_n_ready = r_run[DELAY-2];
// assign o_en_err  = r_en_err;

assign o_valid  = r_run[DELAY-1];
assign o_result = c_mult_o_out;

endmodule