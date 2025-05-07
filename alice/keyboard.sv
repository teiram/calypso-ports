//
// HT1080Z for MiSTer Keyboard module
//
// Copyright (c) 2009-2011 Mike Stirling
// Copyright (c) 2015-2017 Sorgelig
// Modified for Calypso (c) 2025 overCLK

// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Redistributions in synthesized form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
// * Neither the name of the author nor the names of other contributors may
//   be used to endorse or promote products derived from this software without
//   specific prior written agreement from the author.
//
// * License is granted for non-commercial use only.  A fee may not be charged
//   for redistributions as source code or in synthesized/hardware form without
//   specific prior written agreement from the author.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//

module keyboard(
    input reset,                // reset when driven high
    input clk_sys,              // should be same clock as clk_sys from HPS_IO

    input [10:0] ps2_key,       // [7:0] - scancode,
                                // [8] - extended (i.e. preceded by scan 0xE0),
                                // [9] - pressed
                                // [10] -strobe

    input [7:0] addr,           // bottom 7 address lines from CPU for memory-mapped access
    output reg [7:0] kb_rows,   // data lines returned from scanning

    input kblayout              // 0 = TRS-80 keyboard arrangement; 1 = PS/2 key assignment

);

reg [7:0] keys[7:0];
wire press_btn = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
wire input_strobe = ps2_key[10];

// Output addressed row to ULA
always @(addr) begin
    kb_rows <= 8'hff;
    if (keys[0][0]==1'b0) if (addr[0] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][1]==1'b0) if (addr[1] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][2]==1'b0) if (addr[2] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][3]==1'b0) if (addr[3] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][4]==1'b0) if (addr[4] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][5]==1'b0) if (addr[5] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][6]==1'b0) if (addr[6] == 1'b0) kb_rows[0] <= 1'b0;
    if (keys[0][7]==1'b0) if (addr[7] == 1'b0) kb_rows[0] <= 1'b0;

    if (keys[1][0]==1'b0) if (addr[0] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][1]==1'b0) if (addr[1] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][2]==1'b0) if (addr[2] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][3]==1'b0) if (addr[3] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][4]==1'b0) if (addr[4] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][5]==1'b0) if (addr[5] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][6]==1'b0) if (addr[6] == 1'b0) kb_rows[1] <= 1'b0;
    if (keys[1][7]==1'b0) if (addr[7] == 1'b0) kb_rows[1] <= 1'b0;

    if (keys[2][0]==1'b0) if (addr[0] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][1]==1'b0) if (addr[1] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][2]==1'b0) if (addr[2] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][3]==1'b0) if (addr[3] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][4]==1'b0) if (addr[4] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][5]==1'b0) if (addr[5] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][6]==1'b0) if (addr[6] == 1'b0) kb_rows[2] <= 1'b0;
    if (keys[2][7]==1'b0) if (addr[7] == 1'b0) kb_rows[2] <= 1'b0;

    if (keys[3][0]==1'b0) if (addr[0] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][1]==1'b0) if (addr[1] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][2]==1'b0) if (addr[2] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][3]==1'b0) if (addr[3] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][4]==1'b0) if (addr[4] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][5]==1'b0) if (addr[5] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][6]==1'b0) if (addr[6] == 1'b0) kb_rows[3] <= 1'b0;
    if (keys[3][7]==1'b0) if (addr[7] == 1'b0) kb_rows[3] <= 1'b0;

    if (keys[4][0]==1'b0) if (addr[0] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][1]==1'b0) if (addr[1] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][2]==1'b0) if (addr[2] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][3]==1'b0) if (addr[3] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][4]==1'b0) if (addr[4] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][5]==1'b0) if (addr[5] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][6]==1'b0) if (addr[6] == 1'b0) kb_rows[4] <= 1'b0;
    if (keys[4][7]==1'b0) if (addr[7] == 1'b0) kb_rows[4] <= 1'b0;

    if (keys[5][0]==1'b0) if (addr[0] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][1]==1'b0) if (addr[1] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][2]==1'b0) if (addr[2] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][3]==1'b0) if (addr[3] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][4]==1'b0) if (addr[4] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][5]==1'b0) if (addr[5] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][6]==1'b0) if (addr[6] == 1'b0) kb_rows[5] <= 1'b0;
    if (keys[5][7]==1'b0) if (addr[7] == 1'b0) kb_rows[5] <= 1'b0;

    if (keys[6][0]==1'b0) if (addr[0] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][1]==1'b0) if (addr[1] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][2]==1'b0) if (addr[2] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][3]==1'b0) if (addr[3] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][4]==1'b0) if (addr[4] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][5]==1'b0) if (addr[5] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][6]==1'b0) if (addr[6] == 1'b0) kb_rows[6] <= 1'b0;
    if (keys[6][7]==1'b0) if (addr[7] == 1'b0) kb_rows[6] <= 1'b0;

    if (keys[7][0]==1'b0) if (addr[0] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][1]==1'b0) if (addr[1] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][2]==1'b0) if (addr[2] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][3]==1'b0) if (addr[3] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][4]==1'b0) if (addr[4] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][5]==1'b0) if (addr[5] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][6]==1'b0) if (addr[6] == 1'b0) kb_rows[7] <= 1'b0;
    if (keys[7][7]==1'b0) if (addr[7] == 1'b0) kb_rows[7] <= 1'b0;


end


always @(posedge clk_sys) begin
    if (reset) begin
        keys[0] <= 8'd0;
        keys[1] <= 8'd0;
        keys[2] <= 8'd0;
        keys[3] <= 8'd0;
        keys[4] <= 8'd0;
        keys[5] <= 8'd0;
        keys[6] <= 8'b11000001;
        keys[7] <= 8'd0;
    end

    if (input_strobe) begin
        case (code)

            8'h54 : keys[0][0] <= press_btn; // @
            8'h1c : keys[0][1] <= press_btn; // A
            8'h32 : keys[0][2] <= press_btn; // B
            8'h21 : keys[0][3] <= press_btn; // C
            8'h23 : keys[0][4] <= press_btn; // D
            8'h24 : keys[0][5] <= press_btn; // E
            8'h2b : keys[0][6] <= press_btn; // F
            8'h34 : keys[0][7] <= press_btn; // G

            8'h33 : keys[1][0] <= press_btn; // H
            8'h43 : keys[1][1] <= press_btn; // I
            8'h3b : keys[1][2] <= press_btn; // J
            8'h42 : keys[1][3] <= press_btn; // K
            8'h4b : keys[1][4] <= press_btn; // L
            8'h3a : keys[1][5] <= press_btn; // M
            8'h31 : keys[1][6] <= press_btn; // N
            8'h44 : keys[1][7] <= press_btn; // O

            8'h4d : keys[2][0] <= press_btn; // P
            8'h15 : keys[2][1] <= press_btn; // Q
            8'h2d : keys[2][2] <= press_btn; // R
            8'h1b : keys[2][3] <= press_btn; // S
            8'h2c : keys[2][4] <= press_btn; // T
            8'h3c : keys[2][5] <= press_btn; // U
            8'h2a : keys[2][6] <= press_btn; // V
            8'h1d : keys[2][7] <= press_btn; // W

            8'h22 : keys[3][0] <= press_btn; // X
            8'h35 : keys[3][1] <= press_btn; // Y
            8'h1a : keys[3][2] <= press_btn; // Z
            
            8'h5a : keys[3][6] <= press_btn; // ENTER
            8'h29 : keys[3][7] <= press_btn; // SPACE

            8'h45 : keys[4][0] <= press_btn; // 0
            8'h16 : keys[4][1] <= press_btn; // 1
            8'h1e : keys[4][2] <= press_btn; // 2
            8'h26 : keys[4][3] <= press_btn; // 3
            8'h25 : keys[4][4] <= press_btn; // 4
            8'h2e : keys[4][5] <= press_btn; // 5
            8'h36 : keys[4][6] <= press_btn; // 6
            8'h3d : keys[4][7] <= press_btn; // 7
            
            8'h3e : keys[5][0] <= press_btn; // 8
            8'h46 : keys[5][1] <= press_btn; // 9
            8'h4e : keys[5][2] <= press_btn; // +;
            8'h55 : keys[5][3] <= press_btn; // 
            8'h41 : keys[5][4] <= press_btn; // ,<
            8'h5b : keys[5][5] <= press_btn; // 
            8'h49 : keys[5][6] <= press_btn; // .>
            8'h4a : keys[5][7] <= press_btn; // /?


            8'h76 : keys[6][2] <= press_btn; // BREAK

            // Modifiers
            8'h14 : keys[6][0] <= ~press_btn; // CTRL
            8'h12 : keys[6][7] <= ~press_btn; // Left shift
            8'h59 : keys[6][7] <= ~press_btn; // Right shift

            default:
        ;
        endcase
    end
end

endmodule
