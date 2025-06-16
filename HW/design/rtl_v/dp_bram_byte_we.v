//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.03.15
// Design Name: LeNet-5
// Module Name: dp_bram
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Dual Port BRAM with Byte Write Enable
// Dependencies: synthesible true dpbram from vivado hls
// Revision: 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps
module dp_bram_byte_we #(
    parameter ADDR_WIDTH = 9   , // = log2(MEM_DEPTH)
    parameter MEM_WIDTH  = 32   ,
    parameter MEM_DEPTH  = 512 
) (
	clk    ,
	addr0  ,    addr1  ,
	ce0    ,    ce1    ,
	we0    ,    we1    ,
	d0     ,    d1     ,
	q0     ,    q1     
);

localparam COL_WIDTH = 8;
localparam NUM_COL   = MEM_WIDTH / COL_WIDTH; // 4

input clk;

input      [ADDR_WIDTH-1 : 0] addr0 , addr1 ;
input                         ce0   , ce1   ;
input      [NUM_COL   -1 : 0] we0   , we1   ;
input      [MEM_WIDTH -1 : 0] d0    , d1    ;
output reg [MEM_WIDTH -1 : 0] q0    , q1    ;

(* ram_style = "block" *)reg [MEM_WIDTH-1:0] bram[0 : MEM_DEPTH-1];

integer i;

always @(posedge clk) begin 
    if (ce0) begin
        for(i = 0; i < NUM_COL; i = i + 1) begin
            if (we0[i]) begin
                bram[addr0][i*COL_WIDTH +: COL_WIDTH] <= d0[i*COL_WIDTH +: COL_WIDTH];
            end
        end
        q0 <= bram[addr0];
    end
end

always @(posedge clk) begin 
    if (ce1) begin
        for(i = 0; i < NUM_COL; i = i + 1) begin
            if (we1[i]) begin
                bram[addr1][i*COL_WIDTH +: COL_WIDTH] <= d1[i*COL_WIDTH +: COL_WIDTH];
            end
        end
        q1 <= bram[addr1];
    end
end

endmodule
