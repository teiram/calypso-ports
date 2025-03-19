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


module mtx512(
	input         CLK12M,
	output [7:0]  LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX,
    
    output  [7:0] AUX

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
wire TAPE_SOUND = AUDIO_IN;
`else
wire TAPE_SOUND = UART_RX;
`endif


`include "build_id.v" 
localparam CONF_STR = {
    "MTX512;;",
    "O4,Video Out,80Col,VDP;",
    "S0U,IMGVHD,Load VHD;",
    "F0,ROM,Load ROM;",
    "O2,PAL,Normal,Marat;",
    "O3,Hz,60,50;",
    "T0,Reset;",
    "V,calypso-",`BUILD_DATE 
};

/////////////////  CLOCKS  ////////////////////////

wire clk_25Mhz;
wire clk_ram;
wire locked;
wire clk_50Mhz;
wire clk_cpu;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_ram),
    .c1(clk_50Mhz),
    .c2(clk_25Mhz),
    .locked(locked)
);

wire clk_sys=clk_25Mhz;


///////////////// SDRAM ///////////////////////////

wire [22:0] sramAddress;
wire [7:0]  sramData;
wire [7:0]  sramDataIn;
wire [7:0]  sramDataOut;

wire n_sRamWE;
wire n_sRamOE;
wire n_sRamCS;

wire ram_ready;
sdram ram(
	.*,
	.init(~locked),
	.clk(clk_ram),	
	.addr(ioctl_download ? ioctl_addr: sramAddress),
	.dout(sramDataOut),
	.din(ioctl_download ? ioctl_data : sramDataIn),
	.wtbt(2'b00),
	.we(ioctl_download  ? ioctl_wr   : ~n_sRamWE),
	.rd(ioctl_download ? 1'b0        : ~n_sRamOE),
	.ready(ram_ready)
);
assign SDRAM_CLK=clk_ram;

wire forced_scandoubler;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [31:0] status;

wire ps2_kbd_clk,ps2_kbd_data;
wire ps2_mouse_clk,ps2_mouse_data;

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;

wire        ioctl_download;
wire        ioctl_wr;
wire [22:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire  [7:0] ioctl_index;

wire [31:0] joy1, joy2;
wire [15:0] joystick_analog_0,joystick_analog_1;

wire ypbpr;

wire        img_readonly;
wire        img_mounted;
wire [63:0] img_size;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_ack_conf;
wire        sd_busy;
wire        sd_sdhc;
wire        sd_conf;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io(

    .clk_sys(clk_sys),
    .clk_sd(clk_50Mhz),
    .conf_str(CONF_STR),
    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),
    .buttons(buttons),
    .switches(switches),
    .ypbpr(ypbpr),

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    .key_code(key_code),
    .joystick_0(joy1),
    .joystick_1(joy2),
    .status(status),

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),
    .sd_conf(sd_conf),
    .sd_sdhc(sd_sdhc),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout_strobe(sd_buff_wr),
    .img_mounted(img_mounted),
    .img_size(img_size)
);

data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_DI(SPI_DI),
    .clkref_n(1'b0),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_data)
);


wire reset = status[0] || ioctl_download || !locked;
assign LED[0] = reset;

/*
reg [31:0] reset_counter = 32'd10000000;
wire reset = |reset_counter;
assign LED[0] = reset;

always @(posedge clk_sys) begin
    if (status[0] || ioctl_download || !locked) reset_counter <= 32'd10000000;
    else if (|reset_counter) reset_counter <= reset_counter - 32'b1;
end
*/
`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd25_000_000;
i2s i2s(
    .reset(reset),
    .clk(clk_sys),
    .clk_rate(clk_rate),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({AudioOut, AudioOut}),
    .right_chan({AudioOut, AudioOut})       
);
`endif


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;

rememotech rememotech(
    .CLOCK_50(clk_50Mhz),

    .SD_CLK(sdclk),
    .SD_CMD(sdmosi),
    .SD_DAT(sdmiso),
    .SD_DAT3(sdss),

	.SRAM_CE_N(n_sRamCS),
    .SRAM_ADDR(sramAddress),
    .SRAM_LB_N(),
    .SRAM_UB_N(),
    .SRAM_OE_N(n_sRamOE),
    .SRAM_WE_N(n_sRamWE),
    .SRAM_D(sramDataIn),
	.SRAM_Q(sramDataOut),
	.SRAM_RDY(ram_ready),
    
    .LED(LED[7]),

    .SW({3'b101, status[4], status[2], ~status[3], 2'b0, 2'b0}),
    //      |       |           |           |        |     +-----
    //      |       |           |           |        +-----------
    //      |       |           |           +-------------------- Frame rate (50/60hz)
    //      |       |           +-------------------------------- PAL/NTSC
    //      |       +-------------------------------------------- 80cols/VDP video out
    //      +---------------------------------------------------- CPU Speed (hardcoded to 4.166MHz)

    .KEY({reset, 3'b111}),

    .VGA_R(r),
    .VGA_G(g),
    .VGA_B(b),
    .VGA_HS(HSync),
    .VGA_VS(VSync),
 	.VGA_HB(HBlank),
	.VGA_VB(VBlank),

	.clk_video_i(clk_25Mhz),
    .clk_cpu_o(clk_cpu),
	 
	.PS2_CLK(ps2_kbd_clk),
	.PS2_DAT(ps2_kbd_data),
	  
	.EKey(key_extended),
    .key_ready(key_strobe),
    .key_stroke(key_pressed),
    .key_code(key_code),
    
    .sound_out(AudioOut)
);


wire [7:0] AudioOut;

/////////////////  VIDEO  /////////////////////////
wire [3:0] r,g,b;

mist_video #(
    .COLOR_DEPTH(4),
    .SD_HCNT_WIDTH(11),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD)) mist_video (	
	.clk_sys(clk_25Mhz),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.R(r),
	.G(g),
	.B(b),
	.HSync(HSync),
	.VSync(VSync),
	.HBlank(HBlank),
	.VBlank(VBlank),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(),
	.VGA_HS(),
	.ce_divider(1'b0),
	
	.scandoubler_disable(1'b1),
	.ypbpr(ypbpr),
	.rotate(2'b00),
	.blend(1'b0)
	);

assign VGA_HS = HSync;
assign VGA_VS = VSync;

/////////////////  Tape In   /////////////////////////

wire tape_in=TAPE_SOUND;

//////////////////   SD   ///////////////////

wire sdclk;
wire sdmosi;
wire sdss;
wire sdmiso;

reg sdcard_ss_delayed;

always @(posedge clk_sys) begin
  sdcard_ss_delayed <= sdss;
end

sd_card sd_card(
    .clk_sys(clk_50Mhz),
    .img_mounted(img_mounted),
    .img_size(img_size),
    .sd_lba(sd_lba),
    .sd_wr(sd_wr),
    .sd_rd(sd_rd),
    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),
    .sd_sdhc(sd_sdhc),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_wr(sd_buff_wr),
		  
    .allow_sdhc(1'b0),
    
    .sd_sck(sdclk),
    .sd_cs(sdss),
    .sd_sdi(sdmosi),
    .sd_sdo(sdmiso)
);

assign AUX[0] = sdclk;
assign AUX[1] = sdss;
assign AUX[2] = sdmosi;
assign AUX[3] = sdmiso;
assign AUX[4] = reset;
assign AUX[5] = locked;
assign AUX[6] = ioctl_download;
assign AUX[7] = ioctl_download;
endmodule
