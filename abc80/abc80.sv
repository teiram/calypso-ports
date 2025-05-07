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

module abc80_calypso(
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

`ifdef USE_HDMI
    output HDMI_RST,
    output [7:0] HDMI_R,
    output [7:0] HDMI_G,
    output [7:0] HDMI_B,
    output HDMI_HS,
    output HDMI_VS,
    output HDMI_PCLK,
    output HDMI_DE,
    inout HDMI_SDA,
    inout HDMI_SCL,
    input HDMI_INT,
`endif

    input SPI_SCK,
    inout SPI_DO,
    input SPI_DI,
    input SPI_SS2,    // data_io
    input SPI_SS3,    // OSD
    input CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
    input QSCK,
    input QCSn,
    inout [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
    input SPI_SS4,
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
    output SDRAM_CKE,

`ifdef DUAL_SDRAM
    output [12:0] SDRAM2_A,
    inout [15:0] SDRAM2_DQ,
    output SDRAM2_DQML,
    output SDRAM2_DQMH,
    output SDRAM2_nWE,
    output SDRAM2_nCAS,
    output SDRAM2_nRAS,
    output SDRAM2_nCS,
    output [1:0] SDRAM2_BA,
    output SDRAM2_CLK,
    output SDRAM2_CKE,
`endif

    output AUDIO_L,
    output AUDIO_R,
`ifdef I2S_AUDIO
    output I2S_BCK,
    output I2S_LRCK,
    output I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
    output HDMI_MCLK,
    output HDMI_BCK,
    output HDMI_LRCK,
    output HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
    output SPDIF,
`endif
`ifdef USE_AUDIO_IN
    input AUDIO_IN,
`endif
    input UART_RX,
    output UART_TX

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

assign LED[0]   = ~ioctl_download; 
assign LED[1] = reset;

`include "build_id.v"
localparam CONF_STR = {
    "ABC80;;",
    "F1,BAC,Load;",
    "F2,BAC,Alternative Load;",
    `SEP
    "O2,Memory,16K,32K;",
    "O34,Scanlines,Off,25%,50%,75%;",
    "O5,Blend,Off,On;",
    "O6,Tape Sounds,Off,On;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire [1:0] scanlines = status[4:3];
wire blend = status[5];
wire tapesnd = status[6];
wire xmem = status[2];
wire uart_en = status[7];

/////////////////  CLOCKS  ////////////////////////
wire clk48, clk12, pll_locked;
pll pll(
    .inclk0(CLK12M),
    .c0(clk48),
    .c1(clk12),
    .locked(pll_locked)
);

/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;
wire [1:0] switches;
wire [7:0] joystick_0;
wire [7:0] joystick_1;
wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire key_strobe;
wire key_pressed;
wire key_extended;
wire [7:0] key_code;

user_io #(
    .STRLEN(($size(CONF_STR)>>3)),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk12),
    .conf_str(CONF_STR),
    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),
    .buttons(buttons),
    .switches(switches),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
`ifdef USE_HDMI
    .i2c_start(i2c_start),
    .i2c_read(i2c_read),
    .i2c_addr(i2c_addr),
    .i2c_subaddr(i2c_subaddr),
    .i2c_dout(i2c_dout),
    .i2c_din(i2c_din),
    .i2c_ack(i2c_ack),
    .i2c_end(i2c_end),
`endif
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    .key_code(key_code),
    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .status(status)
);

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;

data_io data_io(
    .clk_sys(clk48),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_DI(SPI_DI),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);


reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk48) begin
    reg ioctl_download_prev;
    ioctl_download_prev <= ioctl_download;
    if (ioctl_download_prev & ~ioctl_download) rom_loaded <= 1;
    reset <= status[0] | buttons[1] | ~rom_loaded;
end


////////////////  Core  ////////////////////////
wire video;
wire [13:0] audio;
wire hs, vs;
wire hb, vb;
reg [1:0] cass_in;
wire cass_out;
wire cass_relay;
wire upcase;
wire uart_tx, uart_rts, uart_cts;

always @(posedge clk12) begin
`ifdef USE_AUDIO_IN
    cass_in[0] <= AUDIO_IN;
`else
    cass_in[0] <= UART_RX;
`endif
    cass_in[1] <= cass_in[0];
end

ABC80 ABC80 (
    .RESET(reset),
    .CLK12(clk12),
    .HSYNC(hs),
    .VSYNC(vs),
    .HBLANK(hb),
    .VBLANK(vb),
    .VIDEO(video),
    .AUDIO(audio),
    .CASS_IN(cass_in[1]),
    .CASS_OUT(cass_out),
    .CASS_CTRL(cass_relay),
    .XMEM(xmem),

    .UART_RX(UART_RX),
    .UART_TX(uart_tx),
    .UART_CTS(uart_cts),
    .UART_RTS(uart_rts),

    .KEY_STROBE(key_strobe),
    .KEY_PRESSED(key_pressed),
    .KEY_EXTENDED(key_extended),
    .KEY_CODE(key_code),
    .UPCASE(upcase),

    .DL(ioctl_download),
    .DL_CLK(clk48),
    .DL_ADDR(ioctl_addr[15:0]),
    .DL_DATA(ioctl_dout),
    .DL_WE(ioctl_wr),
    .DL_ROM(ioctl_index == 0),
    .DL_ALT(ioctl_index == 2)
);

wire [14:0] audio_mix = audio + (tapesnd ? {cass_in[1], cass_out, 10'd0} : 14'd0);

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk48),
    .clk_rate(32'd48_000_000),
    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),
    .left_chan({~audio_mix[14], audio_mix[13:0], 2'b00}),
    .right_chan({~audio_mix[14], audio_mix[13:0], 2'b00})
);
`endif

mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(10),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD)) 
mist_video(
    .clk_sys(clk48),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(video),
    .G(video),
    .B(video),
    .HBlank(hb),
    .VBlank(vb),
    .HSync(~hs),
    .VSync(~vs),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
`ifdef USE_HDMI
    .HDMI_R(HDMI_R),
    .HDMI_G(HDMI_G),
    .HDMI_B(HDMI_B),
    .HDMI_VS(HDMI_VS),
    .HDMI_HS(HDMI_HS),
    .HDMI_DE(HDMI_DE),
`endif
    .ce_divider(4'h3),
    .blend(blend),
    .scandoubler_disable(scandoubler_disable),
    .scanlines(scanlines),
    .ypbpr(ypbpr),
    .no_csync(no_csync)
);

endmodule
