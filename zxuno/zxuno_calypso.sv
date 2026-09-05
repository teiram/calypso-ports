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

module zxuno_calypso(
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

assign LED = {7'd0, ~sd_cs};

`include "build_id.v"
localparam CONF_STR = {
    "ZXUNO;;",
    "S0,VHD,Load SD;",
    `SEP
    "O56,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O1,Swap joysticks,Off,On;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire clk_sys;
wire clk_mem;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .c1(clk_mem),
    .locked(pll_locked)
);

/////////////////  IO  ///////////////////////////
wire [63:0] status;
wire scandoubler_disable;
wire [1:0] buttons;
wire ypbpr, no_csync;

wire [7:0] joystick_0, joystick_1;

wire [1:0] scanlines = status[6:5];

wire ps2_kbd_clk, ps2_kbd_data;
wire ps2_mouse_clk, ps2_mouse_data;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
    .PS2DIV(2800),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))
    ) user_io(
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
    .conf_str(CONF_STR),

    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),

    .scandoubler_disable(scandoubler_disable),
    .buttons(buttons),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1),

    // ps2 interface
    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    .ps2_mouse_clk(ps2_mouse_clk),
    .ps2_mouse_data(ps2_mouse_data),

    .status(status),
    .ypbpr(ypbpr),
    .no_csync(no_csync),

    // interface to embedded legacy sd card wrapper
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),
    .sd_conf(sd_conf),
    .sd_sdhc(sd_sdhc),
    .sd_dout(sd_dout),
    .sd_dout_strobe(sd_dout_strobe),
    .sd_din(sd_din),
    .sd_buff_addr(sd_buff_addr)
);

wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack, sd_ack_conf;
wire sd_conf;
wire sd_sdhc; 
wire [7:0] sd_dout;
wire sd_dout_strobe;
wire [7:0] sd_din;
wire sd_din_strobe;
wire [8:0] sd_buff_addr;

wire reset =  status[0] | buttons[1];

wire sd_cs, sd_sck, sd_sdi, sd_sdo;

sd_card sd_card(
    .clk_sys(clk_sys),   // at least 2xsd_sck
    // connection to io controller
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_conf(sd_conf),
    .sd_ack_conf(sd_ack_conf),
    .sd_sdhc(sd_sdhc),
    .sd_buff_dout(sd_dout),
    .sd_buff_wr(sd_dout_strobe),
    .sd_buff_din(sd_din),
    .sd_buff_addr(sd_buff_addr),

    .allow_sdhc(1'b1),

    // connection to local CPU
    .sd_cs(sd_cs),
    .sd_sck(sd_sck),
    .sd_sdi(sd_sdi),
    .sd_sdo(sd_sdo)
);


wire [2:0] ri, gi, bi, ro, go, bo;
wire hsync_pal, vsync_pal, csync_pal;
wire [7:0] joy0 = status[1] ? joystick_1 : joystick_0;
wire [7:0] joy1 = status[1] ? joystick_0 : joystick_1;

zxuno #(
    .FPGA_MODEL(3'b010),
    .MASTERCLK(28000000)
) zxuno(
    .sysclk(clk_sys),
    .srdclk(clk_mem),
    
    .power_on_reset_n(~reset),
    
    .r(ri),
    .g(gi),
    .b(bi),
    
    .hsync(hsync_pal),
    .vsync(vsync_pal),
    .csync(csync_pal),
    
    .clkps2(ps2_kbd_clk),
    .dataps2(ps2_kbd_data),
    
    .ear_ext(TAPE_SOUND),
    .audio_out_left(),
    .audio_out_right(),
     
    .left(l_audio),
    .right(r_audio), 

    .midi_out(),
    .clkbd(),
    .wsbd(),
    .dabd(),
     
    .uart_tx(),
    .uart_rx(1'b1),
    .uart_rts(),

    .sdramCk(SDRAM_CLK),
    .sdramCe(SDRAM_CKE),
    .sdramCs(SDRAM_nCS),
    .sdramRas(SDRAM_nRAS),
    .sdramCas(SDRAM_nCAS),
    .sdramWe(SDRAM_nWE),
    .sdramDqm({SDRAM_DQMH,SDRAM_DQML}),
    .sdramDQ(SDRAM_DQ),
    .sdramBA(SDRAM_BA),
    .sdramA(SDRAM_A),

    .sd_cs_n(sd_cs),
    .sd_clk(sd_sck),
    .sd_mosi(sd_sdi),
    .sd_miso(sd_sdo),


    .joy1up(~joy0[3]),
    .joy1down(~joy0[2]),
    .joy1left(~joy0[1]),
    .joy1right(~joy0[0]),
    .joy1fire1(~joy0[4]),
    .joy1fire2(~joy0[5]),   

     
    .joy2up(~joy1[3]),
    .joy2down(~joy1[2]),
    .joy2left(~joy1[1]),
    .joy2right(~joy1[0]),
    .joy2fire1(~joy1[4]),
    .joy2fire2(~joy1[5]),

    .mouseclk(ps2_mouse_clk),
    .mousedata(ps2_mouse_data),

    .ad724_xtal(),
    .ad724_mode(),
    .ad724_enable_gencolorclk()
);


wire [7:0] l_audio, r_audio;

i2s i2s(
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd28_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({1'b0, l_audio, 7'd0}),
    .right_chan({1'b0, r_audio, 7'd0})
);

mist_video #(
    .COLOR_DEPTH(3),
    .SD_HCNT_WIDTH(10),
    .SYNC_AND(1),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .OSD_COLOR(3'd1),
    .BIG_OSD(BIG_OSD)
    ) mist_video(
    .clk_sys(clk_sys),

    // OSD SPI interface
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines(scanlines),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider(1'b0),

    // 0 = HVSync 31KHz, 1 = CSync 15KHz
    .scandoubler_disable(scandoubler_disable),
    
    // disable csync without scandoubler
    .no_csync(no_csync),
    // YPbPr always uses composite sync
    .ypbpr(ypbpr),
    // Rotate OSD [0] - rotate [1] - left or right
    .rotate(2'b00),
    // composite-like blending
    .blend(1'b0),

    // video in
    .R(ri),
    .G(gi),
    .B(bi),

    .HSync(hsync_pal),
    .VSync(vsync_pal),

    // MiST video output signals
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS)
);


endmodule
