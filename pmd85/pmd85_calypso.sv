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

module pmd85_calypso(
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
    "PMD85;;",
    "F1,RMM,Load to ROM Pack;",
    `SEP
    "O12,Video,Green,TV,RGB,ColorACE;",
    "O78,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O3,Sound,Beeper,Beeper + MIF85 on K2;",
    `SEP
    "O45,Joystick,None,K3,K4;",
    "O6,Mouse,None,K2;",
    "O9,Swap Joysticks,No,Yes;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////
wire pll_locked;
wire clk_sys;  //PMD85 system clock (for 8224) is 18.432MHz
wire clk_8M;   //8MHz clock for audio (SAA1099)
wire clk_50M;
wire clk_sdram /* synthesis keep */;

pll1 pll1(
    .inclk0(CLK12M),
    .c0(clk_50M)
);

pll2 pll2(
    .inclk0(clk_50M),
    .c0(clk_sys),
    .c1(clk_8M),
    .c2(clk_sdram),
    .locked(pll_locked)
);

wire reset = status[0] | buttons[1] | ~pll_locked;

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

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

wire mouse_strobe;
wire [8:0] mouse_y;
wire [8:0] mouse_x;
wire [7:0] mouse_flags;
wire [24:0] ps2_mouse = {mouse_strobe, mouse_y, mouse_x, mouse_flags[5:0]};

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

    .mouse_strobe(mouse_strobe),
    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_flags(mouse_flags),

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
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

/////////////////  Memory  ////////////////////////

wire [15:0] sdram_addr /* synthesis keep */;
wire [7:0] sdram_din /* synthesis keep */;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */;
wire sdram_we /* synthesis keep */;

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
    .we(sdram_we),
    .ready(sdram_ready)
);


////////////////  Console  ////////////////////////
wire [15:0] audio_l;
wire [15:0] audio_r;

wire [7:0] R, G, B;
wire hsync, vsync;

wire [31:0] joya = status[9] ? joy1 : joy0;
wire [31:0] joyb = status[9] ? joy0 : joy1;

wire [1:0] pixelFunction;
wire allRam_n;
wire RxD;
wire TxD;
    
PMD85_2A PMD85core(
    .clk_50M(clk_50M),
    .clk_8M(clk_8M),
    .clk_sys(clk_sys),
    .reset_main(reset),
    
    .ps2_key(ps2_key),
    .ps2_mouse(ps2_mouse),
    
    .clk_video(),
    .SR_n(hsync),
    .SD_n(vsync),
    .ZAT_n(),
    .pixel(),
    
    .RxD(RxD),
    .TxD(TxD),
    
    .audioMode(status[3]),
    .AUDIO_L(audio_l),
    .AUDIO_R(audio_r),
    
    .tape_in(TAPE_SOUND),
    
    .ColorMode(status[2:1]),
    .VGA_R(R),
    .VGA_G(G),
    .VGA_B(B),
        
    .LED_YELLOW(LED[1]),
    .LED_RED(LED[2]),
    .allRam_n(allRam_n),
        
    .joystickPort(status[5:4]),
    .joy0(joya),
    .joy1(joyb),
    .mouseEnabled(status[6]),
    
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    
    .sdram_addr(sdram_addr),
    .sdram_data_in(sdram_din),
    .sdram_data_out(sdram_dout),
    .sdram_rd(sdram_rd),
    .sdram_wr(sdram_we)
);

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_8M),
    .clk_rate(32'd8_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio_l),
    .right_chan(audio_r)
);
`endif

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
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
    .HSync(hsync),
    .VSync(vsync),
    
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    
    .ce_divider(3'd2),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[8:7]),
    .ypbpr(ypbpr)
);


endmodule
