`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
//
// Initial Engineer (2001 Model):          Thomas Skibo
// Brought to 3032 and 4032 (non CRTC):    Ruben Aparicio
// 
// Create Date:      Sep 23, 2011
//
// Module Name:      pet2001hw
//
// Description:      Encapsulate all Pet hardware except cpu.
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2011, Thomas Skibo.  All rights reserved.
// Copyright (C) 2019, Ruben Aparicio.  All rights reserved.
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

module pet2001hw(
    input            clk,
    input            ce_7mp,
    input            ce_7mn,
    input            ce_1m,
    input            reset,
    input            diag_l,

    input [15:0] addr,
    input [7:0] data_in,
    output reg [7:0] data_out,
    input we,
    output irq,

    output pix,
    output HSync,
    output VSync,
    output HBlank,
    output VBlank,

    output [3:0] keyrow,
    input  [7:0] keyin,

    output cass_motor_n,
    output cass_write,
    input cass_sense_n,
    input cass_read,
    
    output audio,

    input  st_ieee_bus ieee_i,
    output st_ieee_bus ieee_o,

    input [7:0] sdram_data
);

wire [10:0] charaddr; // To charrom of 2048 bytes
wire [7:0] chardata;

charrom charrom(
    .clock(clk),
    .address(charaddr),
    .q(chardata)
);

//////////////////////////////////////////////////////////////
// Dual ported video RAM
//////////////////////////////////////////////////////////////
wire [7:0] vram_data;
wire [7:0] video_data;
wire [10:0] video_addr;
wire vram_we = we && (addr[15:12] == 4'h8);

dpram #(.addr_width(10)) pet2001vram(
    .clock(clk),

    .address_a(addr[9:0]),
    .data_a(data_in),
    .wren_a(vram_we),
    .q_a(vram_data),

    .address_b(video_addr),
    .q_b(video_data)
);

//////////////////////////////////////
// Video hardware.
//////////////////////////////////////
wire video_on;        // signal indicating VGA is scanning visible
                      // rows.  Used to generate tick interrupts.
wire video_blank;     // blank screen during scrolling
wire video_gfx;       // display graphic characters vs. lower-case

pet2001video vid(
    .clk(clk),
    .ce_7mp(ce_7mp),
    .ce_7mn(ce_7mn),
    
    .pix(pix),
    .HSync(HSync),
    .VSync(VSync),
    .HBlank(HBlank),
    .VBlank(VBlank),
    
    .video_addr(video_addr),
    .video_data(video_data),
    
    .charaddr(charaddr),
    .chardata(chardata),
    
    .video_on(video_on),
    .video_gfx(video_gfx)
);

////////////////////////////////////////////////////////
// I/O hardware
////////////////////////////////////////////////////////
wire [7:0] io_read_data;
wire io_sel = addr[15:8] == 8'hE8;

pet2001io io(
    .clk(clk),
    .ce(ce_1m),
    .reset(reset),
    .diag_l(diag_l),
    .irq(irq),
    
    .keyrow(keyrow),
    .keyin(keyin),
    
    .ieee_i(ieee_i),
    .ieee_o(ieee_o),
    
    .data_out(io_read_data),
    .data_in(data_in),
    .addr(addr[10:0]),
    .cs(io_sel),
    .we(we),
    
    .video_sync(video_on),
    .video_blank(video_blank),
    .video_gfx(video_gfx),
    
    .cass_motor_n(cass_motor_n),
    .cass_write(cass_write),
    .cass_sense_n(cass_sense_n),
    .cass_read(cass_read),

    .audio(audio)
);

/////////////////////////////////////
// Read data mux (to CPU)
/////////////////////////////////////
always @(*)
casex (addr[15:11])
    5'b1111_x: data_out = sdram_data;         // F000-FFFF
    5'b1110_1: data_out = io_read_data;       // E800-EFFF I/O (ROM contains chargen here, not accessible by CPU)
    5'b1110_0: data_out = sdram_data;         // E000-E7FF
    5'b110x_x: data_out = sdram_data;         // C000-DFFF
    5'b1011_x: data_out = sdram_data;         // B000-BFFF BASIC
    5'b1010_x: data_out = sdram_data;         // A000-AFFF OPT ROM 2
    5'b1001_x: data_out = sdram_data;         // 9000-9FFF OPT ROM 1
    5'b1000_x: data_out = vram_data;          // 8000-8FFF VIDEO RAM (mirrored several times)
    5'b0xxx_x: data_out = sdram_data;         // 0000-7FFF 32KB RAM
    default:   data_out = 8'h55;
endcase

endmodule
