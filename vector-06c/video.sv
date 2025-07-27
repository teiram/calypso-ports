//
// Vector-06C display implementation
// 
// Copyright (c) 2016 Sorgelig
//
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//


`timescale 1ns / 1ps

module video
(
    input reset,

    // Clocks
    input clk_sys,
    input ce_12mp,
    input ce_12mn,

    // Video outputs
    output [2:0] R,
    output [2:0] G,
    output [2:0] B,
    output reg vsync,
    output reg hsync,
    output reg vblank,
    output reg hblank,

    // CPU bus
    input [15:0] addr,
    input [7:0] din,
    input we,
    input io_we,

    // SDRAM bus
    output reg [24:0] vram_addr,
    input [31:0] vram_data,
    output vram_rd,
    
    // Misc signals
    input [7:0] scroll,
    input [3:0] border,
    input mode512,
    output reg retrace
);

assign retrace = vsync;

reg  [9:0] hc /* synthesis keep */;
reg  [8:0] vc /* synthesis keep */;
wire [8:0] vcr = vc + ~roll;
reg  [7:0] roll;

reg        viden, dot;
reg  [7:0] idx0, idx1, idx2, idx3;
//wire[31:0] vram_o;

/*
dpram vram
(
	.clock(clk_sys),
	.wraddress({addr[12:0], addr[14:13]}),
	.data(din),
	.wren(we & addr[15]),
	.rdaddress({hc[8:4], ~vcr[7:0]}),
	.q(vram_o)
);
*/

reg mode512_lock;

always @(posedge clk_sys) begin
	reg [7:0] border_d;
	reg       mode512_acc; 

	if(ce_12mp) begin
		if(hc == 767) begin
			hc <=0;
			if (vc == 311) vc <= 9'd0;
				else vc <= vc + 1'd1;
			if(vc == 271) begin
				vsync <= 1;
				mode512_lock <= mode512_acc;
				mode512_acc  <= 0;
			end
			if(vc == 281) vsync <= 0;
		end else begin
			hc <= hc + 1'd1;
		end

		if((vc == 311) && (hc == 759)) roll <= scroll;
		if(hc == 563) begin
			hblank <= 1;
			if(vc == 267) vblank <= 1;
		end
		if(hc == 597) hsync <= 1;
		if(hc == 653) hsync <= 0;
		if(hc == 723) begin
			hblank <= 0;
			if(vc == 295) vblank <= 0;
		end
        if (hc[2:0] == 3'd0) begin
            vram_rd <= 1'b1;
            vram_addr <= {hc[8:4], ~vcr[7:0]};
        end
	end

	if(ce_12mn) begin
        vram_rd <= 1'b0;
		if(hc[0]) begin
			idx0 <= {idx0[6:0], border_d[4]};
			idx1 <= {idx1[6:0], border_d[5]};
			idx2 <= {idx2[6:0], border_d[6]};
			idx3 <= {idx3[6:0], border_d[7]};
			if((hc[3:1] == 2) & ~hc[9] & ~vc[8]) {idx0, idx1, idx2, idx3} <= vram_data;

			border_d <= {border_d[3:0], border};
		end

		dot   <= ~hc[0];
		viden <= ~hblank & ~vblank;
		if(~hblank & ~vblank) mode512_acc <= mode512_acc | mode512;
	end
end

reg  [7:0] palette[16];
wire [3:0] color_idx = {{2{~(mode512 & ~dot)}} & {idx3[7], idx2[7]}, {2{~(mode512 & dot)}} & {idx1[7], idx0[7]}};

always @(posedge clk_sys) begin
	reg old_we;
	old_we <= io_we;

	if(reset) begin
		palette[0]  <= ~8'b11111111;
		palette[1]  <= ~8'b01010101;
		palette[2]  <= ~8'b11010111;
		palette[3]  <= ~8'b10000111;
		palette[4]  <= ~8'b11101010;
		palette[5]  <= ~8'b01101000;
		palette[6]  <= ~8'b11010000;
		palette[7]  <= ~8'b11000000;
		palette[8]  <= ~8'b10111101;
		palette[9]  <= ~8'b01111010;
		palette[10] <= ~8'b11000111;
		palette[11] <= ~8'b00111111;
		palette[12] <= ~8'b11101000;
		palette[13] <= ~8'b11010010;
		palette[14] <= ~8'b10010000;
		palette[15] <= ~8'b00000010;
	end else if(~old_we & io_we) begin
		palette[color_idx] <= din;
	end
end

assign R = {3{viden}} & palette[color_idx][2:0];
assign G = {3{viden}} & palette[color_idx][5:3];
assign B = {3{viden}} & {palette[color_idx][7:6], palette[color_idx][7]};


endmodule
