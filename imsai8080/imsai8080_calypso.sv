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

module imsai8080_calypso(
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
    "IMSAI8080;;",
    `SEP
    "F0,ROM,Reload Panel;",
    `SEP
    "O3,Swap Joysticks,No,Yes;",
    "OC,Mode,Computer,Console;",
    "T1,Led toggle;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk36m;
wire clk72m /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk36m),
    .c1(clk72m),
    .locked(pll_locked)
);

reg [2:0] ce_counter;
wire mem_clkref /* synthesis keep */ = ce_counter == 3'b000;
always @(posedge clk72m) begin
    if (reset) ce_counter <= 3'd0;
    
    ce_counter <= ce_counter + 3'd1;
end

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index;
wire ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire [7:0] ioctl_dout /* synthesis keep */;

wire no_csync;
wire ypbpr;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk36m),
    .clk_sd(clk36m),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),
    
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
    .clk_sys(clk36m),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .clkref_n(~mem_clkref),
    
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
wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;

/////////////////  Memory  ////////////////////////

assign SDRAM_CLK = clk72m;
assign SDRAM_CKE = 1'b1;
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
    
    .init_n(pll_locked),
    .clk(clk72m),
    .clkref(~mem_clkref),
    
    .port1_req(ioctl_wr),
    .port1_ack(),
    .port1_a(ioctl_addr[22:1]),
    .port1_ds({ioctl_addr[0], ~ioctl_addr[0]}),
    .port1_we(ioctl_wr),
    .port1_d({ioctl_dout, ioctl_dout}),
    .port1_q(),

    .cpu1_addr(vid_ram_addr[16:2]),
    .cpu1_q(ram_value),
    .cpu1_oe(~ioctl_download)
);

wire [13:0] audio;

wire [3:0] R /* synthesis keep */,G /* synthesis keep */,B /* synthesis keep */;
wire hblank, vblank;
wire hsync, vsync;
wire [10:0] col /* synthesis keep */;
wire [9:0] row /* synthesis keep */;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire [16:2] vid_ram_addr;
wire [31:0] ram_value;

////////////////////////////////////////////
// CORE

vga vga(
    .clk36m(clk36m),
    .reset(reset),
    
    .col(col),
    .row(row),
    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank)
);

reg [43:0] leds;
reg [25:0] counter;
always @(posedge clk36m) begin
    if (reset) begin 
        counter <= 'd0;
        leds <= 'd1;
    end
    counter <= counter + 1'd1;
    if (counter == 'd9_000_000) begin
        leds <= {leds[42:0], 1'b0};
        counter <= 'd0;
    end
    if (~|leds) leds <= 'd1;
end

panel panel(
    .clk36m(clk36m),
    .reset(reset),
    .col(col),
    .row(row),
    .hblank(hblank),
    .vblank(vblank),
    .ram_addr(vid_ram_addr),
    .ram_value(ram_value),
    
    .leds(leds),
    
    .r(R),
    .g(G),
    .b(B)
);

////////////////////////////////////////////

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk36m),
    .clk_rate(32'd36_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[13], audio[12:0], 2'b0}),
    .right_chan({~audio[13], audio[12:0], 2'b0})
);
`endif

mist_video #(
    .COLOR_DEPTH(4),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk36m),
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
    .ce_divider(3'd0),
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .scanlines(3'd0),
    .ypbpr(ypbpr)
);


endmodule
