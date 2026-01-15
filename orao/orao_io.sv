`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2019, Hrvoje Cavrak
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

module orao_io(
   output reg [7:0] data_out,    // CPU interface
   input  [7:0]  data_in,
   input [15:0]  addr,
   input         we,

   input  [10:0] ps2_key,

   output [15:0] tape_addr,
   input [7:0] tape_data,
   input tape_data_ready,
   output reg tape_rd,
   input tape_reset,
   
   output        video_blank,    // Video controls
   input         video_sync,

   output reg    audio,

   input         ce,
   input         clk,
   input         reset  
);

//////////////////////////////////////////////////////////////////////
// PS/2 to Orao keyboard interface
//////////////////////////////////////////////////////////////////////
wire  [7:0] kbd_data_out, tape_data_out;

reg [15:0] old_read_addr;
   
keyboard keyboard(
    .reset(reset),
    .clk(clk),
    .ps2_key(ps2_key),
    .addr(addr),
    .kbd_data_out(kbd_data_out)
);

reg [24:0] read_counter = 0;

assign tape_addr = read_counter[24:9];

always @(posedge clk) begin
   old_read_addr <= addr;
   
   tape_rd <= 1'b0;
   if (tape_reset) begin                                              // Detect end of download
       read_counter <= 32'b0;
   end
   
   /* read_counter contains:
      [24:9] - temporary tape buffer address, 
      [8:6]  - current bit pointer in byte received, 
      [5:0]  - bits read by loader per 1 bit of tap file, outputting msb generates Manchester encoding that loader interprets
   */
   
   if (addr == 16'h87ff && old_read_addr != 16'h87ff) begin
      tape_rd <= 1'b1;
   end
   
   if (tape_rd == 1'b1) begin
       if (tape_data_ready == 1'b1) begin
           tape_rd <= 1'b0;
           read_counter <= read_counter + (tape_data[read_counter[8:6]] ? 32'd1 : 32'd2);
           audio <= read_counter[5];
       end
   end

   if (addr == 16'h87ff) begin                                        // 0x87ff is used to read from the tape
      data_out <= read_counter[5] ? 8'hff : 8'h00;
   end
   
   else if (addr[15:11] == 5'b10000)                                 // Addresses with 0b10000 in high bits are for reading the keyboard
      data_out <= kbd_data_out;     
      
   else
      data_out <= 8'hff;                                             // This handles the remaining address space, return all ones.
      
   if (ce && addr[15:11] == 5'b10001)
      audio <= ~audio;                                               // When location with 10001 in address high bits is read or 
                                                                     // written, flip-flop is switched. Used to generate audio.
end                                                                  

assign video_blank = 1'b0;
 
endmodule // orao_io
