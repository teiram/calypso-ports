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

module scv_calypso(
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
    "SCV;;",
    `SEP
    "F1,ROMBIN;",
    `SEP
    "O3,Swap Joysticks,No,Yes;",
    "O45,Scanlines,Off,25%,50%,75%;",
    "O8,Palette,RGB,RF;",
    "O9A,Overscan mask,Large,Small,None;",
    `SEP
    "OGJ,Cartridge mapper,automatic,rom8k,rom16k,rom32k,rom32k_ram,rom64k,rom128k,rom128_ram;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);


/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index;
wire ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire [7:0] ioctl_dout /* synthesis keep */;
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

//////////////////////////////////////////////////////////////////////
// Download manager

wire rominit_active;
wire rominit_sel_boot, rominit_sel_chr, rominit_sel_apu, rominit_sel_cart;
wire [16:0] rominit_addr;
wire [7:0] rominit_data;
wire rominit_valid;

rominit rominit(
   .CLK_SYS(clk_sys),

   .IOCTL_DOWNLOAD(ioctl_download),
   .IOCTL_INDEX(ioctl_index),
   .IOCTL_WR(ioctl_wr),
   .IOCTL_ADDR(ioctl_addr),
   .IOCTL_DOUT(ioctl_dout),
   .IOCTL_WAIT(),

   .ROMINIT_ACTIVE(rominit_active),
   .ROMINIT_SEL_BOOT(rominit_sel_boot),
   .ROMINIT_SEL_CHR(rominit_sel_chr),
   .ROMINIT_SEL_APU(rominit_sel_apu),
   .ROMINIT_SEL_CART(rominit_sel_cart),
   .ROMINIT_ADDR(rominit_addr),
   .ROMINIT_DATA(rominit_data),
   .ROMINIT_VALID(rominit_valid)
   );

//////////////////////////////////////////////////////////////////////
// Connect joysticks and keyboard to HMI
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;
hmi_t hmi;

joykey joykey(
    .CLK_SYS(clk_sys),

    .JOYSTICK_0(joya),
    .JOYSTICK_1(joyb),
    .PS2_KEY(ps2_key),

    .HMI(hmi)
);


mapper_t mapper;
palette_t vdc_palette;
overscan_mask_t vdc_overscan_mask;

assign mapper = mapper_t'(status[19:16]);
assign vdc_palette = palette_t'(status[8]);
assign vdc_overscan_mask = overscan_mask_t'(status[10:9]);

/////////////////  RESET  /////////////////////////
wire reset /* synthesis keep */ =  status[0] | buttons[1] | ioctl_download | ~pll_locked | rominit_active;

/////////////////  Memory  ////////////////////////
wire [22:0] sdram_addr /* synthesis keep */ = {5'd0, ram_addr};
wire [7:0] sdram_din /* synthesis keep */ = ram_din;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd = ram_oe /* synthesis keep */;
wire sdram_we = ram_we /* synthesis keep */;

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
    
    .init(~pll_locked),
    .clk(clk_sys),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready()
);


////////////////  Console  ////////////////////////
wire [7:0] R,G,B;
wire hsync, vsync;
wire signed [8:0] pcm_audio;

wire ram_oe;
wire ram_we;
wire [17:0] ram_addr;
wire [7:0] ram_din;
wire [7:0] ram_dout = sdram_dout;

////////////////////////////////////////////
// CORE
scv scv(
    .CLK(clk_sys),
    .RESB(~reset),

    .ROMINIT_SEL_BOOT(rominit_sel_boot),
    .ROMINIT_SEL_CHR(rominit_sel_chr),
    .ROMINIT_SEL_APU(rominit_sel_apu),
    .ROMINIT_SEL_CART(rominit_sel_cart),
    .ROMINIT_ADDR(rominit_addr),
    .ROMINIT_DATA(rominit_data),
    .ROMINIT_VALID(rominit_valid),

    .MAPPER(mapper),
    .VDC_PALETTE(vdc_palette),
    .VDC_OVERSCAN_MASK(vdc_overscan_mask),

    .HMI(hmi),

    .VID_HS(hsync),
    .VID_VS(vsync),
    .VID_RGB({R, G, B}),

    .AUD_PCM(pcm_audio),
   
    .ram_addr(ram_addr),
    .ram_din(ram_din),
    .ram_dout(ram_dout),
    .ram_oe(ram_oe),
    .ram_we(ram_we)
);

////////////////////////////////////////////

`ifdef I2S_AUDIO

i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd28_636_364),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({pcm_audio, 7'd0}),
    .right_chan({pcm_audio, 7'd0})
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
    .HBlank(),
    .VBlank(),
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
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
