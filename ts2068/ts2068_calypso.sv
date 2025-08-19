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

module ts2068_calypso(
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
localparam CONF_STR =
{
    "TS2068;;",
    "F0,ROM,Load ROM;",
    "F1,DCK,Load DCK;",
    "F2,TZX,Load TZX;",
    "S0U,VHD,Mount SD;",
    `SEP
    "O3,Model,PAL,NTSC;",
    "O4,DivMMC,Off,On;",
    "O5,Swap Joysticks,Off,On;",
    "O67,Scanlines,Off,25%,50%,75%;",
    `SEP
    "T0,Reset;",
    "T2,NMI;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////

wire pal_clk /* synthesis keep */, pal_pll_locked; //56.000 Mhz
pll_pal pll0(
    .inclk0(CLK12M),
    .c0(pal_clk),
    .locked(pal_pll_locked)
);

wire ntsc_clk, ntsc_pll_locked; // 56.488 MHz
pll_ntsc pll1(
    .inclk0(CLK12M),
    .c0(ntsc_clk),
    .locked(ntsc_pll_locked)
);

wire clk_sys = model ? pal_clk : ntsc_clk;
wire power = pal_pll_locked & ntsc_pll_locked;

reg [3:0] ce;
always @(negedge clk_sys) if (~power) ce <= 1'd0; else ce <= ce + 1'd1;

wire ne28M = ce[0:0] == 1;
wire ne14M = ce[1:0] == 3;
wire ne7M0 = ce[2:0] == 7;
wire pe7M0 = ce[2:0] == 3;
wire ne3M5 = ce[3:0] == 15;
wire pe3M5 = ce[3:0] == 7;

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;
wire [31:0] joy0, joy1;

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index /* synthesis keep */;
wire ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire [7:0] ioctl_dout /* synthesis keep */;
wire scandoubler_disable;
wire no_csync;
wire ypbpr;

wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;
wire sd_sdhc;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;
wire [31:0] img_ext;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES('d1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
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

    .sd_sdhc(sd_sdhc),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joy0),
    .joystick_1(joy1)
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
    .ioctl_fileext(img_ext),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

wire sd_spi_cs;
wire sd_spi_ck;
wire sd_spi_mosi;
wire sd_spi_miso;

sd_card sd_card(
    .clk_sys(clk_sys),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_lba(sd_lba),
    .sd_conf(),
    .sd_sdhc(sd_sdhc),
    .sd_ack_conf(),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_din (sd_buff_din),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_wr(sd_buff_wr),
    .img_size(img_size),
    .img_mounted(img_mounted),
    .allow_sdhc(1'b1),

    .sd_cs       (sd_spi_cs),
    .sd_sck      (sd_spi_ck),
    .sd_sdi      (sd_spi_mosi),
    .sd_sdo      (sd_spi_miso)
);

/////////////////  Memory  ////////////////////////
/*
-    64 Kb HOME RAM: $00000 - $FFFF
-      * Video RAM on HOME RAM at $4000
-    ROM at $10000
       * TS2068 ROM at 10000   15FFF    24Kb
            - 10000 - 13FFF . Main ROM  16Kb
            - 14000 - 15FFF . Ext ROM    8Kb
-      * ESXDOS ROM at 16000 - 17FFF     8Kb           128Kb
------------------------------------------------------------
-    DIVMMC RAM: $20000 - $3FFFF        128Kb          128Kb
------------------------------------------------------------
-    DOCK at $40000
*/

wire download_rom = ioctl_index == 'd0 && ioctl_download == 1'b1;
wire download_dock = ioctl_index == 'd1 && ioctl_download == 1'b1;

wire [13:0] vid_addr;
wire [7:0] vid_dout;

wire [15:0] memA;
wire [7:0] memD;
wire [7:0] memQ;
wire memB;
wire [7:0] memM;
wire memW;

wire mapped;
wire ramcs /* synthesis keep */;
wire [3:0] page;

wire [22:0] sdram_addr /* synthesis keep */ =
    download_rom == 1'b1 ? {5'd0, 2'b01, ioctl_addr[15:0]} :                            // ROM write on  10000
    download_dock == 1'b1 ? {4'd0, 3'b100, ioctl_addr[15:0]} :                          // DOCK write on 40000
    memA[15:14] == 2'b00 && mapped && ramcs ? {4'd0, 1'b1, page, memA[12:0]} :          // DIVMMC RAM access (20000)
    memA[15:14] == 2'b00 && mapped && ~ramcs ? {5'd0, 5'b01_011, memA[12:0]} :          // ESXDOS access (at 16000)
    memM[memA[15:13]] ? memB ?  {5'd0, 5'b01_010, memA[12:0]} :                         // EXTROM (14000)
                                {4'd0, 3'b100, memA[15:0]}:                             // DOCK (40000)
    memA[15:14] == 2'b00 ? {5'd0, 4'b0100, memA[13:0]}:                                 // ROM access (10000)
    {5'd0, 2'b00, memA[15:0]};                                                          // HOME RAM

wire [7:0] sdram_din /* synthesis keep */ = ioctl_download == 1'b1 ? ioctl_dout : memD;

assign memQ = sdram_dout;

wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */ = ioctl_download == 1'b1 ? 1'b0 : ramcs || (mapped & memA[15:14] == 2'b00);
wire sdram_we /* synthesis keep */ = ioctl_download == 1'b1 ? ioctl_wr : memW;

assign SDRAM_CLK = clk_sys;
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
    
    .init(~power),
    .clk(clk_sys),
    .clkref(1'b1),
    
    .bank(2'b00),
    .addr(sdram_addr),
    .oe(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    
    .vram_addr({7'd0, 2'b01, vid_addr}),
    .vram_dout(vid_dout)
);


/////////////////  Keyboard  ////////////////////////
wire [4:0] kbd_col;
wire [7:0] kbd_row;
wire play_key;
wire stop_key;
wire f5_key;
wire f9_key;

matrix matrix(
    .clock(clk_sys),
    .strb(key_strobe),
    .code(key_code),
    .row(kbd_row),
    .col(kbd_col),
    .play(play_key),
    .stop(stop_key),
    .F5(f5_key),
    .F9(f9_key)
);

//////////////// Core ///////////////////////////////
wire [14:0] audio_left;
wire [14:0] audio_right;
wire R, G, B, I;
wire hsync, vsync;
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire model = status[3];
wire divmmc = status[4];

wire reset_n /* synthesis keep */ = power & f9_key & ~download_rom & ~download_dock & ~status[0];
wire nmi /* synthesis keep */ = (f5_key && !status[2]) || mapped;

wire ear = TAPE_SOUND;

ts ts(
    .model(model),
    .divmmc(divmmc),
    
    .clock(clk_sys),
    .ne14M(ne14M),
    .ne7M0(ne7M0),
    .pe7M0(pe7M0),
    .ne3M5(ne3M5),
    .pe3M5(pe3M5),
    .reset(reset_n),
    .nmi(nmi),

    .va(vid_addr),
    .vd(vid_dout),

    .memA(memA),
    .memD(memD),
    .memQ(memQ),
    .memB(memB),
    .memM(memM),
    .memW(memW),
    .mapped(mapped),
    .ramcs(ramcs),
    .page(page),

    .hsync(hsync),
    .vsync(vsync),
    .r(R),
    .g(G),
    .b(B),
    .i(I),

    .ear(ear),
    .left(audio_left),
    .right(audio_right),

    .col(kbd_col),
    .row(kbd_row),
    .joy1(joya),
    .joy2(joyb),

    .sdcCs(sd_spi_cs),
    .sdcCk(sd_spi_ck),
    .sdcMosi(sd_spi_mosi),
    .sdcMiso(sd_spi_miso)
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio_left, 2'b0}),
    .right_chan({audio_right, 2'b0})
);
`endif

mist_video #(
    .COLOR_DEPTH(6),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R({3{R, R & I}}),
    .G({3{G, G & I}}),
    .B({3{B, B & I}}),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[7:6]),
    .ypbpr(ypbpr)
);


endmodule
