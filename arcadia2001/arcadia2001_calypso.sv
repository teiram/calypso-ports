//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
`default_nettype none

module arcadia2001_calypso(
    input CLK12M,
`ifdef USE_CLOCK_50
    input CLOCK_50,
`endif

    output [7:0] LED,
    output [VGA_BITS-1:0] VGA_R,
    output [VGA_BITS-1:0] VGA_G,
    output [VGA_BITS-1:0] VGA_B,
    output VGA_HS,
    output VGA_VS,

    input SPI_SCK,
    inout SPI_DO,
    input SPI_DI,
    input SPI_SS2,
    input SPI_SS3,
    input CONF_DATA0,

`ifndef NO_DIRECT_UPLOAD
    input SPI_SS4,
`endif

`ifdef I2S_AUDIO
    output I2S_BCK,
    output I2S_LRCK,
    output I2S_DATA,
`endif

`ifdef USE_AUDIO_IN
    input AUDIO_IN,
`endif

    output [12:0] SDRAM_A,
    inout [15:0] SDRAM_DQ,
    output SDRAM_DQML,
    output SDRAM_DQMH,
    output SDRAM_nWE,
    output SDRAM_nCAS,
    output SDRAM_nRAS,
    output SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CLK,
    output SDRAM_CKE

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 4;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef USE_AUDIO_IN
localparam bit USE_AUDIO_IN = 1;
wire TAPE_SOUND=AUDIO_IN;
`else
localparam bit USE_AUDIO_IN = 0;
wire TAPE_SOUND=UART_RX;
`endif

assign LED[0] = ~ioctl_download; 

`include "build_id.v"
localparam CONF_STR = {
    "Arcadia;;",
    `SEP
    "F,BIN,Load Cartridge;",
    "O2,Video output,PAL,NTSC;",
    "O3,Auto-Center,On,Off;",
    "O4,Swap Joystick XY,Off,On;",
    "O5,D-Pad Analog Emulation,Off,On;",
    "O67,Scanlines,Off,25%,50%,75%;",
    "O9,Swap Controllers,Off,On;",
    "OA,Pause Core on OSD,Off,On;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys, clk_sys_ntsc, clk_sys_pal, pll_locked;
assign clk_sys = status[2] ? clk_sys_ntsc : clk_sys_pal;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys_pal),
    .c1(clk_sys_ntsc),
    .locked(pll_locked)
);
  
/* CLK = Pix CLK * 8
   NTSC : 3.579545MHz   * 8 => 28,636363
   PAL  : 4.43361875MHz * 8 => 35,468888
*/

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;


reg [9:0] kb1_keys, kb2_keys;
reg kb1_enter, kb1_clear, kb2_enter, kb2_clear;
wire [31:0] joystick_0,joystick_1;
wire [15:0] joystick_analog_0,joystick_analog_1;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire scandoubler_disable;
wire no_csync;
wire ypbpr;


wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons),

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .joystick_analog_0(joystick_analog_0),
    .joystick_analog_1(joystick_analog_1)
);


data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),

`ifdef NO_DIRECT_UPLOAD
    .SPI_SS4(1'b1),
`else
    .SPI_SS4(SPI_SS4),
`endif

    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

always @(posedge clk_sys) begin
    if (ps2_key[10]) begin
        if (ps2_key[9]) begin  // Press
            case (ps2_key[7:0])
                'h16: kb1_keys[1] <= 1'b1;
                'h1E: kb1_keys[2] <= 1'b1;
                'h26: kb1_keys[3] <= 1'b1;
                'h15: kb1_keys[4] <= 1'b1;
                'h1D: kb1_keys[5] <= 1'b1;
                'h24: kb1_keys[6] <= 1'b1;
                'h1C: kb1_keys[7] <= 1'b1;
                'h1B: kb1_keys[8] <= 1'b1;
                'h23: kb1_keys[9] <= 1'b1;
                'h1A: kb1_clear   <= 1'b1;
                'h22: kb1_keys[0] <= 1'b1;
                'h21: kb1_enter   <= 1'b1;
                'h3E: kb2_keys[1] <= 1'b1;
                'h46: kb2_keys[2] <= 1'b1;
                'h45: kb2_keys[3] <= 1'b1;
                'h43: kb2_keys[4] <= 1'b1;
                'h44: kb2_keys[5] <= 1'b1;
                'h4D: kb2_keys[6] <= 1'b1;
                'h42: kb2_keys[7] <= 1'b1;
                'h4B: kb2_keys[8] <= 1'b1;
                'h4C: kb2_keys[9] <= 1'b1;
                'h41: kb2_clear   <= 1'b1;
                'h49: kb2_keys[0] <= 1'b1;
                'h4A: kb2_enter   <= 1'b1;
            endcase
        end else begin  // Release
            case (ps2_key[7:0])
                'h16: kb1_keys[1] <= 1'b0;
                'h1E: kb1_keys[2] <= 1'b0;
                'h26: kb1_keys[3] <= 1'b0;
                'h15: kb1_keys[4] <= 1'b0;
                'h1D: kb1_keys[5] <= 1'b0;
                'h24: kb1_keys[6] <= 1'b0;
                'h1C: kb1_keys[7] <= 1'b0;
                'h1B: kb1_keys[8] <= 1'b0;
                'h23: kb1_keys[9] <= 1'b0;
                'h1A: kb1_clear   <= 1'b0;
                'h22: kb1_keys[0] <= 1'b0;
                'h21: kb1_enter   <= 1'b0;
                'h3E: kb2_keys[1] <= 1'b0;
                'h46: kb2_keys[2] <= 1'b0;
                'h45: kb2_keys[3] <= 1'b0;
                'h43: kb2_keys[4] <= 1'b0;
                'h44: kb2_keys[5] <= 1'b0;
                'h4D: kb2_keys[6] <= 1'b0;
                'h42: kb2_keys[7] <= 1'b0;
                'h4B: kb2_keys[8] <= 1'b0;
                'h4C: kb2_keys[9] <= 1'b0;
                'h41: kb2_clear   <= 1'b0;
                'h49: kb2_keys[0] <= 1'b0;
                'h4A: kb2_enter   <= 1'b0;
            endcase
        end
    end
end

// OR keyboard keys into joystick keypad bits before feeding the core
wire [31:0] joy0_combined, joy1_combined;

// P1 combined
assign joy0_combined[3:0]   = joystick_0[3:0];                // d-pad
assign joy0_combined[6:4]   = joystick_0[6:4];                // Start, Select, Option
assign joy0_combined[7]     = joystick_0[7]  | kb1_enter;     // ENTER
assign joy0_combined[8]     = joystick_0[8]  | kb1_clear;     // CLEAR
assign joy0_combined[9]     = joystick_0[9]  | kb1_keys[0];   // 0
assign joy0_combined[10]    = joystick_0[10] | kb1_keys[1];   // 1
assign joy0_combined[11]    = joystick_0[11] | kb1_keys[2];   // 2
assign joy0_combined[12]    = joystick_0[12] | kb1_keys[3];   // 3
assign joy0_combined[13]    = joystick_0[13] | kb1_keys[4];   // 4
assign joy0_combined[14]    = joystick_0[14] | kb1_keys[5];   // 5
assign joy0_combined[15]    = joystick_0[15] | kb1_keys[6];   // 6
assign joy0_combined[16]    = joystick_0[16] | kb1_keys[7];   // 7
assign joy0_combined[17]    = joystick_0[17] | kb1_keys[8];   // 8
assign joy0_combined[18]    = joystick_0[18] | kb1_keys[9];   // 9
assign joy0_combined[19]    = joystick_0[19] | kb1_keys[2];   // 2 alt
assign joy0_combined[20]    = joystick_0[20] | kb1_keys[2];   // 2 alt

// P2 combined
assign joy1_combined[3:0]   = joystick_1[3:0];                // d-pad
assign joy1_combined[6:4]   = joystick_1[6:4];                // Start, Select, Option
assign joy1_combined[7]     = joystick_1[7]  | kb2_enter;     // ENTER
assign joy1_combined[8]     = joystick_1[8]  | kb2_clear;     // CLEAR
assign joy1_combined[9]     = joystick_1[9]  | kb2_keys[0];   // 0
assign joy1_combined[10]    = joystick_1[10] | kb2_keys[1];   // 1
assign joy1_combined[11]    = joystick_1[11] | kb2_keys[2];   // 2
assign joy1_combined[12]    = joystick_1[12] | kb2_keys[3];   // 3
assign joy1_combined[13]    = joystick_1[13] | kb2_keys[4];   // 4
assign joy1_combined[14]    = joystick_1[14] | kb2_keys[5];   // 5
assign joy1_combined[15]    = joystick_1[15] | kb2_keys[6];   // 6
assign joy1_combined[16]    = joystick_1[16] | kb2_keys[7];   // 7
assign joy1_combined[17]    = joystick_1[17] | kb2_keys[8];   // 8
assign joy1_combined[18]    = joystick_1[18] | kb2_keys[9];   // 9
assign joy1_combined[19]    = joystick_1[19] | kb2_keys[2];   // 2 alt
assign joy1_combined[20]    = joystick_1[20] | kb2_keys[2];   // 2 alt

assign joy0_combined[31:21] = joystick_0[31:21];
assign joy1_combined[31:21] = joystick_1[31:21];

// ====================================================================
// D-PAD ANALOG EMULATION
// ====================================================================
// When status[5] is enabled, D-pad presses generate emulated analog
// values that ramp up over time and decay when released, so an
// NTT Data controller (D-pad only) can drive analog-sensitive games.
// The emulated analog replaces joystick_analog_0/1 to the core.
// ====================================================================

// Ramp prescaler: ~131k clocks per step at ~35.5 MHz gives ~0.5s
// for a full 0-to-127 sweep (127 steps * 131k = ~16.6M clocks).
localparam RAMP_PRE = 17'd131071;

// Player 1 emulated analog state
reg  [16:0] p1_ramp_cnt;       // prescaler counter
reg   [7:0] p1_analog_x;       // signed: 0x00=center, 0x7F=max+, 0x80=max-
reg   [7:0] p1_analog_y;       // signed: 0x00=center, 0x7F=max+, 0x80=max-
reg   [3:0] p1_dpad_d;         // delayed D-pad for edge detection

// Player 2 emulated analog state
reg  [16:0] p2_ramp_cnt;
reg   [7:0] p2_analog_x;
reg   [7:0] p2_analog_y;
reg   [3:0] p2_dpad_d;

// Muxed analog outputs to the core
wire [15:0] analog_0_core, analog_1_core;

assign analog_0_core = status[5] ? {p1_analog_x, p1_analog_y} : joystick_analog_0;
assign analog_1_core = status[5] ? {p2_analog_x, p2_analog_y} : joystick_analog_1;

// D-pad direction bits from the COMBINED joystick (includes keyboard)
// joystick_0 bits: 0=Up, 1=Down, 2=Left, 3=Right
wire [3:0] p1_dpad = joy0_combined[3:0];
wire [3:0] p2_dpad = joy1_combined[3:0];

always @(posedge clk_sys) begin
    // ---- Player 1 ----
    p1_dpad_d <= p1_dpad;
    
    // Edge detect: jump prescaler for immediate response
    if (p1_dpad != 4'd0 && p1_dpad_d == 4'd0)
        p1_ramp_cnt <= RAMP_PRE;
    else if (p1_ramp_cnt == RAMP_PRE) begin
        p1_ramp_cnt <= 17'd0;
        
        // X axis (Left/Right)
        // Real analog stick: Right = negative, Left = positive
        if (p1_dpad[3] && !p1_dpad[2]) begin
            // Right pressed, Left not: ramp toward -128 (0x80)
            if (p1_analog_x[7] == 1'b1 && p1_analog_x != 8'h80)
                p1_analog_x <= p1_analog_x - 8'd1;
            else if (p1_analog_x[7] == 1'b0)
                p1_analog_x <= p1_analog_x - 8'd1;
        end else if (p1_dpad[2] && !p1_dpad[3]) begin
            // Left pressed, Right not: ramp toward +127 (0x7F)
            if (p1_analog_x[7] == 1'b0 && p1_analog_x != 8'h7F)
                p1_analog_x <= p1_analog_x + 8'd1;
            else if (p1_analog_x[7] == 1'b1)
                p1_analog_x <= p1_analog_x + 8'd1;
        end else begin
            // Neither or both: decay toward center (0x00) if auto-center enabled
            if (!status[3]) begin
                if (p1_analog_x[7] == 1'b0 && p1_analog_x != 8'h00)
                    p1_analog_x <= p1_analog_x - 8'd1;
                else if (p1_analog_x[7] == 1'b1 && p1_analog_x != 8'h00)
                    p1_analog_x <= p1_analog_x + 8'd1;
            end
        end
        
        // Y axis (Up/Down)
        // Real analog stick: Down = negative, Up = positive
        if (p1_dpad[1] && !p1_dpad[0]) begin
            // Down pressed, Up not: ramp toward -128 (0x80)
            if (p1_analog_y[7] == 1'b1 && p1_analog_y != 8'h80)
                p1_analog_y <= p1_analog_y - 8'd1;
            else if (p1_analog_y[7] == 1'b0)
                p1_analog_y <= p1_analog_y - 8'd1;
        end else if (p1_dpad[0] && !p1_dpad[1]) begin
            // Up pressed, Down not: ramp toward +127 (0x7F)
            if (p1_analog_y[7] == 1'b0 && p1_analog_y != 8'h7F)
                p1_analog_y <= p1_analog_y + 8'd1;
            else if (p1_analog_y[7] == 1'b1)
                p1_analog_y <= p1_analog_y + 8'd1;
        end else begin
            // Neither or both: decay toward center if auto-center enabled
            if (!status[3]) begin
                if (p1_analog_y[7] == 1'b0 && p1_analog_y != 8'h00)
                    p1_analog_y <= p1_analog_y - 8'd1;
                else if (p1_analog_y[7] == 1'b1 && p1_analog_y != 8'h00)
                    p1_analog_y <= p1_analog_y + 8'd1;
            end
        end
    end else begin
        p1_ramp_cnt <= p1_ramp_cnt + 17'd1;
    end
    
    // ---- Player 2 ----
    p2_dpad_d <= p2_dpad;
    
    // Edge detect for immediate response
    if (p2_dpad != 4'd0 && p2_dpad_d == 4'd0)
        p2_ramp_cnt <= RAMP_PRE;
    else if (p2_ramp_cnt == RAMP_PRE) begin
        p2_ramp_cnt <= 17'd0;
        
        // X axis: Right = negative, Left = positive
        if (p2_dpad[3] && !p2_dpad[2]) begin
            if (p2_analog_x[7] == 1'b1 && p2_analog_x != 8'h80)
                p2_analog_x <= p2_analog_x - 8'd1;
            else if (p2_analog_x[7] == 1'b0)
                p2_analog_x <= p2_analog_x - 8'd1;
        end else if (p2_dpad[2] && !p2_dpad[3]) begin
            if (p2_analog_x[7] == 1'b0 && p2_analog_x != 8'h7F)
                p2_analog_x <= p2_analog_x + 8'd1;
            else if (p2_analog_x[7] == 1'b1)
                p2_analog_x <= p2_analog_x + 8'd1;
        end else begin
            if (!status[3]) begin
                if (p2_analog_x[7] == 1'b0 && p2_analog_x != 8'h00)
                    p2_analog_x <= p2_analog_x - 8'd1;
                else if (p2_analog_x[7] == 1'b1 && p2_analog_x != 8'h00)
                    p2_analog_x <= p2_analog_x + 8'd1;
            end
        end
        
        // Y axis: Down = negative, Up = positive
        if (p2_dpad[1] && !p2_dpad[0]) begin
            if (p2_analog_y[7] == 1'b1 && p2_analog_y != 8'h80)
                p2_analog_y <= p2_analog_y - 8'd1;
            else if (p2_analog_y[7] == 1'b0)
                p2_analog_y <= p2_analog_y - 8'd1;
        end else if (p2_dpad[0] && !p2_dpad[1]) begin
            if (p2_analog_y[7] == 1'b0 && p2_analog_y != 8'h7F)
                p2_analog_y <= p2_analog_y + 8'd1;
            else if (p2_analog_y[7] == 1'b1)
                p2_analog_y <= p2_analog_y + 8'd1;
        end else begin
            if (!status[3]) begin
                if (p2_analog_y[7] == 1'b0 && p2_analog_y != 8'h00)
                    p2_analog_y <= p2_analog_y - 8'd1;
                else if (p2_analog_y[7] == 1'b1 && p2_analog_y != 8'h00)
                    p2_analog_y <= p2_analog_y + 8'd1;
            end
        end
    end else begin
        p2_ramp_cnt <= p2_ramp_cnt + 17'd1;
    end
    
    // Reset all analog state to center
    if (reset) begin
        p1_analog_x <= 8'h00;
        p1_analog_y <= 8'h00;
        p1_ramp_cnt <= 17'd0;
        p1_dpad_d   <= 4'd0;
        p2_analog_x <= 8'h00;
        p2_analog_y <= 8'h00;
        p2_ramp_cnt <= 17'd0;
        p2_dpad_d   <= 4'd0;
    end
end

/////////////////  RESET  /////////////////////////
wire reset = status[0] | buttons[1]  | ~pll_locked;

////////////////  Console  ////////////////////////

wire [7:0] sound;

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

arcadia_core arcadia_core(
    .clk(clk_sys),
    .reset(reset),
    .OSD_STATUS(),
    .pause_osd(status[9]),

    .ntsc_pal(~status[2]),
    .swapxy(status[4]),
    .swap_controllers(status[8]),

    .clk_video(),
    .ce_pixel(),
    .vga_r(R),
    .vga_g(G),
    .vga_b(B),
    .vga_hs(hsync),
    .vga_vs(vsync),
    .vga_hblank(hblank),
    .vga_vblank(vblank),
    .vga_de(),

    .sound(sound),

    .ps2_key(ps2_key),
    .joystick_0(joy0_combined),
    .joystick_1(joy1_combined),
    .joystick_analog_0(analog_0_core),
    .joystick_analog_1(analog_1_core),
    .dpad_analog_en(status[5]),

    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_wait()
);


i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(status[2] ? 32'd28_615_385 : 32'd35_428_571),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~sound[7], sound[6:0], 8'd0}),
    .right_chan({~sound[7], sound[6:0], 8'd0})
);

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .USE_BLANKS(1'b1),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R),
    .G(G),
    .B(B),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd1),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[7:6]),
    .ypbpr(ypbpr)
);


endmodule
