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

module pdp11_calypso(
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
    output SDRAM_CKE,

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

localparam TOT_DISKS = 1'b1;

assign LED[0] = ~ioctl_download; 

`include "build_id.v"
parameter CONF_STR = {
    "PDP11;;",
    "F1,COLBINROM,Load CART;",
    `SEP
    "S0U,DSK,Load Floppy 1;",
    "S1U,DSK,Load Floppy 2;",
    "S2U,DDP,Load Tape 1;",
    "S3U,DDP,Load Tape 2;",
    "O45,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O3,Swap Joysticks,No,Yes;",
    "OC,Mode,Computer,Console;",
    `SEP
    "OD,F18A Max Sprites,4,32;",
    "OE,F18A Scanlines,Off,On;",
    "-;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk50m;
wire clk100m;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk50m),
    .c1(clk100m),
    .locked(pll_locked)
);

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

wire [31:0] sd_lba[TOT_DISKS];
wire [31:0] sd_lba_mux;
reg [TOT_DISKS-1:0] sd_rd /* synthesis keep */;
reg [TOT_DISKS-1:0] sd_wr;
wire [TOT_DISKS-1:0] sd_ack /* synthesis keep */;
wire sd_ack_mux;
wire [8:0] sd_buff_addr /* synthesis keep */;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din[TOT_DISKS];
wire [7:0] sd_buff_din_mux;
wire sd_buff_wr;

wire [TOT_DISKS-1:0] img_mounted;
wire img_readonly;

wire [63:0] img_size;
wire [31:0] img_ext;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(TOT_DISKS),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk50m),
    .clk_sd(clk50m),
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
    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    
    .sd_sdhc(1),
    .sd_lba(sd_lba_mux),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack_mux),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din_mux),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joy0),
    .joystick_1(joy1)
);


data_io data_io(
    .clk_sys(clk50m),
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

/////////////////  RESET  /////////////////////////
wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;


////////////////  Machine  ////////////////////////
wire [13:0] audio;

wire [1:0] R,G,B;
wire vga_ht;
wire vga_fb;
wire hsync, vsync;
wire vtreset;

wire [21:0] addr;
wire [21:0] addrq;
wire [15:0] dati;
wire [15:0] dato;
wire control_dati;
wire control_dato;
wire control_datob;
wire dram_match;

wire ifetch;
wire iwait;

logic have_rl;
wire rl_cs;
wire rl_mosi;
wire rl_sclk;
wire rl_miso;
wire [3:0] rl_sddebug;

logic have_rk;
wire rk_cs;
wire rk_mosi;
wire rk_sclk;
wire rk_miso;
wire [3:0] rk_sddebug;

logic have_rh;
wire rh_cs;
wire rh_mosi;
wire rh_sclk;
wire rh_miso;
wire [3:0] rh_sddebug;

wire cpureset;
wire cpuclk;

wire rxrx0;
wire txtx0;

//assign rxrx0 = UART_RX;
assign UART_TX = txtx0;

logic slowreset;
logic [11:0] slowresetdelay;

always @(posedge cpuclk) begin
    if (ifetch == 1'b1) addrq <= addr;
end

always @(posedge clk100m) begin
    if (reset == 1'b1) begin
        slowreset <= 1'b1;
        slowresetdelay <= 12'd4095;
    end else begin
        if (slowresetdelay == 12'd0) begin
            slowreset <= 1'b0;
            vtreset <= 1'b0;
        end else begin
            slowreset <= 1'b1;
            slowresetdelay <= slowresetdelay -12'd1;
        end 
    end
end

unibus pdp11(
    .addr(addr),
    .dati(dati),
    .dato(dato),
    .control_dati(control_dati),
    .control_dato(control_dato),
    .control_datob(control_datob),
    .addr_match(dram_match),
    
    .ifetch(ifetch),
    .iwait(iwait),
    
    .have_rl(have_rl),
    .rl_sdcard_cs(rl_cs),
    .rl_sdcard_mosi(rl_mosi),
    .rl_sdcard_sclk(rl_sclk),
    .rl_sdcard_miso(rl_miso),
    .rl_sdcard_debug(rl_sddebug),

    .have_rk(have_rk),
    .rk_sdcard_cs(rk_cs),
    .rk_sdcard_mosi(rk_mosi),
    .rk_sdcard_sclk(rk_sclk),
    .rk_sdcard_miso(rk_miso),
    .rk_sdcard_debug(rk_sddebug),

    .have_rh(have_rh),
    .rh_sdcard_cs(rh_cs),
    .rh_sdcard_mosi(rh_mosi),
    .rh_sdcard_sclk(rh_sclk),
    .rh_sdcard_miso(rh_miso),
    .rh_sdcard_debug(rh_sddebug),

    .have_kl11(1'b1),
    .rx0(rxrx0),
    .tx0(txtx0),
    
    .have_xu(1'b0),
    .xu_cs(),
    .xu_mosi(),
    .xu_sclk(),
    .xu_miso(),
    .xu_debug_tx(),
    
    .modelcode(8'd44),
    
    .reset(cpureset),
    .clk50mhz(clk50m),
    .clk(cpuclk)
);

assign dram_match = addr[21:18] == 4'b1111 ? 1'b0: 1'b1;

sdram sdram(
    .addr(addr),
    .dati(dati),
    .dato(dato),
    .control_dati(control_dati),
    .control_dato(control_dato),
    .control_datob(control_datob),
    .dram_match(dram_match),
    
    .dram_addr(SDRAM_A),
    .dram_dq(SDRAM_DQ),
    .dram_ba_1(SDRAM_BA[1]),
    .dram_ba_0(SDRAM_BA[0]),
    .dram_udqm(SDRAM_DQMH),
    .dram_ldqm(SDRAM_DQML),
    .dram_ras_n(SDRAM_nRAS),
    .dram_cas_n(SDRAM_nCAS),
    .dram_we_n(SDRAM_nWE),
    .dram_cs_n(SDRAM_nCS),
    .dram_cke(SDRAM_CKE),
    .dram_clk(SDRAM_CLK),
    
    .reset(reset),
    .cpureset(cpureset),
    .cpuclk(cpuclk),
    .c0(clk100m)
);

assign R = 2'b00;
assign G = vga_fb ? 2'b11 : vga_ht ? 2'b01 : 2'b00;
assign B = 2'b00;

vt10x vt10x(
    .vga_hsync(hsync),
    .vga_vsync(vsync),
    .vga_fb(vga_fb),
    .vga_ht(vga_ht),
    
    .rx(txtx0),
    .tx(rxrx0),

//    .ps2k_c(ps2_kbd_clk),
//    .ps2k_d(ps2_kbd_data),
        
    .vttype(7'd100),
        
    .cpuclk(cpuclk),
    .clk50mhz(clk50m),
    .reset(vtreset)
);
   
`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk50m),
    .clk_rate(32'd50_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[13], audio[12:0], 2'b0}),
    .right_chan({~audio[13], audio[12:0], 2'b0})
);
`endif

mist_video #(
    .COLOR_DEPTH(2),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b010),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk50m),
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
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .ypbpr(ypbpr)
);


endmodule
