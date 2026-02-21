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

module apple1_calypso(
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

parameter CONF_STR = {
    "APPLE-I;;",
    `SEP
    "F0,TXT,Load ASCII;",
//  "F,CAS,Load Cassette;",
    "O2,RAM Size,8K,32K;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////


wire clk6p25, clk25 /* synthesis keep */, pll_locked;
wire clk_sys = clk25;
wire clk_sdram;
wire reset /* synthesis keep */ = status[0] | buttons[1];


pll pll(
    .inclk0(CLK12M),
    .c0(clk6p25),
    .c1(clk25),
    .c2(clk_sdram),
    .locked(pll_locked)
);

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;

wire ps2_kbd_clk;
wire ps2_kbd_data;

wire scandoubler_disable;
wire no_csync;
wire ypbpr;


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),

    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),

    .conf_str(CONF_STR),
    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons)

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

wire [15:0] sdram_addr /* synthesis keep */;
wire [7:0] sdram_din /* synthesis keep */;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */;
wire sdram_wr /* synthesis keep */;

wire sdram_ready /* synthesis keep */;

assign SDRAM_CLK = clk_sdram;
sdram sdram(
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_CKE(SDRAM_CKE),
    
    .init(~pll_locked),
    .clk(clk_sdram),

    .wtbt(0),
    .addr({7'd0, sdram_addr}),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_wr),
    .ready(sdram_ready)
);


wire R,G,B;
wire hsync, vsync;

apple1 #(
    .BASIC_FILENAME("roms/basic.hex"),
    .FONT_ROM_FILENAME("roms/vga_font_bitreversed.hex"),
    .RAM_FILENAME("roms/ram.hex"),
    .VRAM_FILENAME("roms/vga_vram.bin"),
    .WOZMON_ROM_FILENAME("roms/wozmon.hex")
) apple1 (
    .clk25(clk25),
    .rst_n(~reset),

    .uart_rx(),
    .uart_tx(),
    .uart_cts(),
    
    .ps2_clk(ps2_kbd_clk),
    .ps2_din(ps2_kbd_data),
    .ps2_select(1'b1),
    
    .vga_h_sync(hsync),
    .vga_v_sync(vsync),
    .vga_red(R),
    .vga_grn(G),
    .vga_blu(B),
    .vga_de(),
    .vga_cls(),

    .ioctl_download(ioctl_download),
    .ioctl_dout(ioctl_dout),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr[12:0]),
    
    .sdram_addr(sdram_addr),
    .sdram_din(sdram_din),
    .sdram_dout(sdram_dout),
    .sdram_wr(sdram_wr),
    .sdram_rd(sdram_rd),
    .sdram_ready(sdram_ready),

    .pc_monitor(),
    .large_ram(status[2])
);


mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b010),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk25),
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
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .scanlines(),
    .ypbpr(ypbpr)
);


endmodule
