//
// Video Sync Generator
//
// Copyright (c) 2020 Stephen Eddy
//
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

module video_sync(
    input wire i_clk,           // base clock
    input wire i_pix_stb,       // pixel clock strobe
    input wire i_rst,           // reset: restarts frame
    input wire i_ntsc,            // 0 = pal, 1 = ntsc
    output logic o_hs,           // horizontal sync
    output logic o_vs,           // vertical sync
    output logic o_hblank,       // high during blanking interval
    output logic o_vblank,       // high during blanking interval
    output logic o_active,       // high during active pixel drawing
    output logic o_prefetch,     // high on start of line pixel prefetch
    output logic o_screenstart,    // high for one tick at the end of screen
    output logic o_linestart,    // Start of line (horizontal sync area)
    output logic o_animate,      // high for one tick at end of active drawing
    output logic [10:0] o_x,     // current pixel x position
    output logic [8:0] o_y,      // current pixel y position
    output logic o_timer         // PCW Timer int

    );

    // 720x256 video timing based on 1024x312 total screen areas
    // 16 Mhz pixel clock.  15.625 Hkz X, 50.08 Hz Y
    // X sync pulse len is 4uS, Y sync pulse len is 256 uS
    localparam H_FP     = 96;             // X Front Porch Len
    localparam H_SYNC   = 64;             // X SYNC Len
    localparam H_BP     = 144;            // X Back Porch Len
    localparam H_ACTIVE = 720;            // X Active Pixels

    localparam HS_STA = H_FP;              // horizontal sync start
    localparam HS_END = HS_STA + H_SYNC;   // horizontal sync end
    localparam HA_STA = HS_END + H_BP;     // horizontal active pixel start
    localparam LINE   = HA_STA + H_ACTIVE; // complete line (pixels)
    localparam TIMER_LINES = 52;            // How many lines per timer interrupt

    // PAL
    localparam V_P_FP     = 26;             // Y Front Porch Len
    localparam V_P_SYNC   = 4;              // Y SYNC Len
    localparam V_P_BP     = 26;             // Y Back Porch Len
    localparam V_P_ACTIVE = 256;            // Y Active Pixels
    // NTSC
    localparam V_N_FP     = 30;             // Y Front Porch Len
    localparam V_N_SYNC   = 4;              // Y SYNC Len
    localparam V_N_BP     = 26;             // Y Back Porch Len
    localparam V_N_ACTIVE = 200;            // Y Active Pixels

    localparam H_TIMER_STA = 300;
    reg [9:0] VS_STA, VS_END, VA_END, SCREEN, VS_TIMER_START;

    assign VS_STA = ~i_ntsc ? V_P_ACTIVE + V_P_FP : V_N_ACTIVE + V_N_FP;  // vertical sync start
    assign VS_END = VS_STA + (~i_ntsc ? V_P_SYNC : V_N_SYNC);             // vertical sync end
    assign VS_TIMER_START = VS_STA;                                       // Vertical timer start for int
    assign VA_END = ~i_ntsc ? V_P_ACTIVE : V_N_ACTIVE;                    // vertical active pixel end
    assign SCREEN = VS_END + (~i_ntsc ? V_P_BP : V_N_BP);                 // complete screen (lines)

    reg [10:0] h_count;  // line position
    reg [9:0] v_count;  // screen position

    // generate sync signals (active low for resolution)
    assign o_hs = ~((h_count >= HS_STA) & (h_count < HS_END));
    assign o_vs = ~((v_count >= VS_STA) & (v_count < VS_END));

    // keep x and y bound within the active pixels
    assign o_x = (h_count < HA_STA) ? 0 : (h_count - HA_STA);
    assign o_y = (v_count >= VA_END) ? (VA_END - 1) : (v_count);

    // blanking: high within the blanking period
    assign o_hblank = (h_count < HA_STA);
    assign o_vblank = (v_count > VA_END - 1);

    // Line start signal for roller ram lookup
    assign o_linestart = (h_count == 0);

    // active: high during active pixel drawing
    assign o_active = ~((h_count < HA_STA) | (v_count > VA_END - 1)); 
    assign o_prefetch = ~((h_count < HA_STA - 8) | (v_count > VA_END - 1));
    // screenend: high for one tick at the end of the screen
    assign o_screenstart = ((v_count == 0) & (h_count == 0));

    // animate: high for one tick at the end of the final active pixel line
    assign o_animate = ((v_count == VA_END - 1) & (h_count == LINE-1));

    // Timer interrupt processing
    logic timer_tick, timer_line;
    logic [5:0] timer_count;
    logic [9:0] timer_duration;
    assign timer_line = ((v_count == VS_TIMER_START) & (h_count == H_TIMER_STA - 1));
    assign o_timer = timer_tick;

    // Vertical and Horizontal counts
    always @ (posedge i_clk or posedge i_rst)
    begin
        if (i_rst)  // reset to start of frame
        begin
            h_count <= 0;
            v_count <= 0;
            timer_count <= TIMER_LINES - 1;
        end else
        if (i_pix_stb)  // once per pixel
        begin
            timer_tick <= 1'b0;

            if (h_count == LINE - 1)  // end of line
            begin
                h_count <= 0;
                // Loop at screen end
                if (v_count + 1 == SCREEN) v_count <= 0;
                else v_count <= v_count + 1;
            end else h_count <= h_count + 1;

            if (h_count == H_TIMER_STA - 1) begin
                if (timer_count == 0 || timer_line) begin
                    timer_count <= TIMER_LINES - 1;
                    timer_tick <= 1'b1;
                end else timer_count <= timer_count - 1;
            end
        end
    end
endmodule