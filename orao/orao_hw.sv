`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2019, Hrvoje Cavrak.
//
// Copyright (C) 2011, Thomas Skibo.  All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
// * The names of contributors may not be used to endorse or promote products
//   derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL Thomas Skibo OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//
//////////////////////////////////////////////////////////////////////////////

module orao_hw
(
   input [15:0]     addr, // CPU Interface
   input [7:0]      data_in,
   output reg [7:0] data_out,
   input            we,
   output           pix,
   output           HSync,
   output           VSync,
   output           HBlank,
   output           VBlank,
   output           de,

   input  [10:0]    ps2_key,

   output           audio, // CB2 audio

   output [15:0] tape_addr,
   output tape_rd,
   input [7:0] tape_data,
   input tape_data_ready,
   input tape_reset,
   
   input            clk,
   input            ce_1m,
   input            reset
   
);

/////////////////////////////////////////////////////////////
// Orao ROM combining the system ROM and BASIC.
// System rom mapped from E000-FFFF
// Basic is mapped from C000-DFFF
/////////////////////////////////////////////////////////////
wire [7:0]  rom_data;

orao_rom rom
(
   .q_a(rom_data),
   .address_a(addr[13:0]),
   .clock(clk)
);

   
//////////////////////////////////////////////////////////////
// Orao RAM and video RAM.  Video RAM is dual ported.
//////////////////////////////////////////////////////////////

wire [7:0]  ram_data;
wire [7:0]  vram_data;
wire [7:0]  video_data;
wire [12:0] video_addr;

wire  ram_we  = we && (addr[15:13] < 3'b011);
wire  vram_we = we && (addr[15:13] == 3'b011);

orao_ram ram
(
   .clock(clk),

   .q_a(ram_data),
   .data_a(data_in),
   .address_a(addr[14:0]),
   .wren_a(ram_we)
);

orao_vram vidram
(
   .clock(clk),

   .address_a(addr[12:0]),
   .data_a(data_in),
   .wren_a(vram_we),
   .q_a(vram_data),

   .address_b(video_addr),
   .data_b(0),
   .wren_b(0),
   .q_b(video_data)
);

//////////////////////////////////////
// Video hardware.
//////////////////////////////////////

wire  video_on;    // signal indicating VGA is scanning visible
                   // rows.  Used to generate tick inte  rrupts.
wire  video_blank; // blank screen during scrolling

orao_video vid(
    .clk(clk),

    .pix(pix),
    .HSync(HSync),
    .VSync(VSync),
    .de(de),
    .HBlank(HBlank),
    .VBlank(VBlank),

    .video_addr(video_addr),
    .video_data(video_data),
    
    .video_on(video_on),
    .video_blank(video_blank)
);

////////////////////////////////////////////////////////
// I/O hardware
////////////////////////////////////////////////////////

wire [7:0]  io_read_data;
wire  io_we = we && (addr[15:13] == 3'b100);
   
orao_io io(
   .clk(clk),
   .reset(reset),
   .ce(ce_1m),
   
   .video_blank(video_blank),
   .video_sync(video_sync),
   
   .data_out(io_read_data),
   .data_in(data_in),
   .addr(addr),
   .we(io_we),
   
   .tape_addr(tape_addr),
   .tape_rd(tape_rd),
   .tape_data(tape_data),
   .tape_data_ready(tape_data_ready),
   .tape_reset(tape_reset),
   
   .audio(audio),
   
   .ps2_key(ps2_key)
   
);


/////////////////////////////////////
// Read data mux (to CPU)
/////////////////////////////////////

always @(*)
case(addr[15:13])
   3'b110,
   3'b111:                 // E000-FFFF
      data_out = rom_data;
   3'b100:                 // 8000-9FFF
      data_out = io_read_data;         
   3'b011:                 // 6000-7FFF
      data_out = vram_data;
      
   default:
      data_out = ram_data;
endcase

endmodule
