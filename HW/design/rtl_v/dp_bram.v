//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: dkyou0101
//
// Create Date: 2025.01.23
// Design Name: LeNet-5
// Module Name: dp_bram
// Project Name: CNN_FPGA
// Target Devices: TE0729
// Tool Versions: Vivado/Vitis 2022.2
// Description: Dual Port BRAM
// Dependencies: synthesible true dpbram
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps
module dp_bram #(
    parameter ADDR_WIDTH = 12   , // = log2(MEM_DEPTH)
    parameter MEM_WIDTH  = 16   ,
    parameter MEM_DEPTH  = 3840 
) (
	clk    ,
	addr0  ,    addr1  ,
	ce0    ,    ce1    ,
	we0    ,    we1    ,
	d0     ,    d1     ,
	q0     ,    q1     
);

input clk;

input      [ADDR_WIDTH-1 : 0] addr0 ;
input                         ce0   ;
input                         we0   ;
input      [MEM_WIDTH -1 : 0] d0    ;
output reg [MEM_WIDTH -1 : 0] q0    ;

input      [ADDR_WIDTH-1 : 0] addr1 ;
input                         ce1   ;
input                         we1   ;
input      [MEM_WIDTH -1 : 0] d1    ;
output reg [MEM_WIDTH -1 : 0] q1    ;

(* ram_style = "block" *)reg [MEM_WIDTH-1:0] bram[0 : MEM_DEPTH-1];

always @(posedge clk)  
begin 
    if (ce0) begin
        if (we0) 
            bram[addr0] <= d0;
		else
        	q0 <= bram[addr0];
    end
end

always @(posedge clk)  
begin 
    if (ce1) begin
        if (we1) 
            bram[addr1] <= d1;
		else
        	q1 <= bram[addr1];
    end
end

endmodule
