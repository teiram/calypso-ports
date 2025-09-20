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

module lynx_calypso(
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
    "Lynx;;",
    "O1,RAM,48K,96K;",
    "O2,ROM,Standard,Scorpion;",
    "O3,Bank 2 CAS enable,Off,On;",
    `SEP
    "O45,Scanlines,None,25%,50%,75%;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire pll_locked;
wire clock24;
wire clock48;
wire ce;

pll pll(
    .inclk0(CLK12M),
    .c0(clock24),
    .c1(clock48),
    .locked(pll_locked)
);

wire ramX = status[1];
wire romS = status[2];
wire casM = status[3];

reg rxd, rxp;
always @(posedge clock24) if(ce) begin rxd <= ramX; rxp <= ramX != rxd; end

reg rsd, rsp;
always @(posedge clock24) if(ce) begin rsd <= romS; rsp <= romS != rsd; end

//-------------------------------------------------------------------------------------------------

reg[3:0] pw;
wire power = pw[3];
always @(posedge clock24) if(ce) if(!power) pw <= pw + 1'd1;

//-------------------------------------------------------------------------------------------------

reg[4:0] rs;
wire reset = rs[4];
always @(posedge clock24) if(ce) if(!reset) rs <= rs+1'd1; else if(status[0] || rxp || rsp) rs <= 1'd0;

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


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clock24),
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

    .joystick_0(joy0),
    .joystick_1(joy1)
);


data_io data_io(
    .clk_sys(clock24),
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

/////////////////  RESET  /////////////////////////
//wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;

/////////////////  Memory  ////////////////////////
wire [22:0] sdram_addr;
wire [7:0] sdram_din;
wire [7:0] sdram_dout;
wire sdram_rd;
wire sdram_we;
wire sdram_ready;

assign SDRAM_CLK = clock48;
assign SDRAM_CKE = 1'b1;

/*
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
    .clk(clk_sys),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);
*/

////////////////  Computer  ////////////////////////
wire [5:0] dac;

wire R,G,B;
wire hsync, vsync;

wire [31:0] joya = status[3] ? joy1 : joy0;

wire tape = ~TAPE_SOUND;

main Main(
    .clock(clock24),
    .power(power),
    .reset(reset),

    .ce(ce),
    .ramX(ramX),
    .romS(romS),
    .casM(casM),

    .hSync(hsync),
    .vSync(vsync),
    .r(R),
    .g(G),
    .b(B),

    .tape(tape),
    .audio(dac),

    .keyPrss(~key_pressed),
    .keyStrb(key_strobe),
    .keyCode(key_code),
    .joy    (joya),

    .ramCs(SDRAM_nCS),
    .ramWe(SDRAM_nWE),
    .ramRas(SDRAM_nRAS),
    .ramCas(SDRAM_nCAS),
    .ramDqm({SDRAM_DQMH, SDRAM_DQML}),
    .ramDQ(SDRAM_DQ),
    .ramBa(SDRAM_BA),
    .ramA(SDRAM_A),
    .clockSdram(clock48)
);


////////////////////////////////////////////

`ifdef I2S_AUDIO
wire[9:0] audio_mix = { 2'b00, {6{tape}} } + { 2'b00, dac };

i2s i2s (
    .reset(1'b0),
    .clk(clock24),
    .clk_rate(32'd24_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio_mix[9], audio_mix[8:0], 6'd0}),
    .right_chan({audio_mix[9], audio_mix[8:0], 6'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clock24),
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
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
