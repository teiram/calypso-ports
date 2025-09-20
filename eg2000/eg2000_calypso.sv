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

module eg2000_calypso(
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

assign LED[0] = ~TAPE_SOUND; 

`include "build_id.v"
localparam CONF_STR = {
    "EG2000;;",
    `SEP
    "O12,Scanlines,None,25%,50%,75%;",
    "O3,Polarity,Direct,Inverted;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////

wire clock;

pll pll(
    .inclk0(CLK12M),
    .c0(clock)
);

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;


wire scandoubler_disable;
wire no_csync;
wire ypbpr;


wire ps2_kbd_clk;
wire ps2_kbd_data;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clock),
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

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
);

////////////////  Core  ////////////////////////
wire pixel;
wire boot;

wire [5:0] R = pixel ? palette[color][17:12] : 6'd0;
wire [5:0] G = pixel ? palette[color][11:6] : 6'd0;
wire [5:0] B = pixel ? palette[color][5:0] : 6'd0;

wire [9:0] audio;
wire hsync, vsync;

reg [7:0] pw;
wire power = pw[7] & ~status[0];
always @(posedge clock) if (!power) pw <= pw + 1'd1;

wire tape = (~TAPE_SOUND) ^ status[3];
wire[3:0] color;

glue Glue(
    .clock(clock),
    .power(power),
    .boot(boot),
    .hsync(hsync),
    .vsync(vsync),
    .pixel(pixel),
    .color(color),
    .tape(tape),
    .pcm(audio),
    .ps2({ps2_kbd_data, ps2_kbd_clk}),
    .ramCk(SDRAM_CLK),
    .ramCe(SDRAM_CKE),
    .ramCs(SDRAM_nCS),
    .ramWe(SDRAM_nWE),
    .ramRas(SDRAM_nRAS),
    .ramCas(SDRAM_nCAS),
    .ramDqm({SDRAM_DQMH, SDRAM_DQML}),
    .ramDQ(SDRAM_DQ),
    .ramBA(SDRAM_BA),
    .ramA(SDRAM_A)
);

reg[17:0] palette[15:0];
initial begin
    palette[15] = 18'b111111_111111_111111; // FF FF FF // 16 // white
    palette[14] = 18'b100110_001000_111111; // 98 20 FF //  8 // magenta
    palette[13] = 18'b000111_110001_100011; // 1F C4 8C // 14 // turquise
    palette[12] = 18'b100011_100011_100011; // 8C 8C 8C // 13 // grey
    palette[11] = 18'b100010_011001_111111; // 8A 67 FF // 12 // violet
    palette[10] = 18'b110001_010011_111111; // C7 4E FF // 15 // pink
    palette[ 9] = 18'b101111_110111_111111; // BC DF FF //  9 // light blue
    palette[ 8] = 18'b001011_010100_111111; // 2F 53 FF //  8 // blue
    palette[ 7] = 18'b111010_111111_001001; // EA FF 27 // 11 // yellow/green
    palette[ 6] = 18'b111010_011011_001010; // EB 6F 2B //  5 // orange
    palette[ 5] = 18'b101010_111111_010010; // AB FF 4A //  2 // green
    palette[ 4] = 18'b111111_111100_001111; // FF F2 3D //  4 // yellow
    palette[ 3] = 18'b111010_111010_111010; // EA EA EA //  1 // light grey
    palette[ 2] = 18'b110010_001001_010111; // CB 26 5E //  3 // red
    palette[ 1] = 18'b011011_111111_111010; // 7C FF EA //  7 // cyan
    palette[ 0] = 18'b010111_010111_010111; // 5E 5E 5E // 10 // dark grey
end




////////////////////////////////////////////
// CORE
////////////////////////////////////////////

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clock),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[9], audio[8:0], 6'd0}),
    .right_chan({~audio[9], audio[8:0], 6'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(6),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b110),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clock),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R),
    .G(G),
    .B(B),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd0),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[2:1]),
    .ypbpr(ypbpr)
);


endmodule
