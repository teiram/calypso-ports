//============================================================================
//  X68000
//
//  Copyright (C) 2017,2020 Alexey Melnikov
//  Copyright (C) 2020 Puu
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

module guest_top
(
	input         CLK12M,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output [7:0]       LED,
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
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifndef NO_DIRECT_UPLOAD
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


// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif


//////////////////////////////////////////////////////////////////
assign LED[0]  = ~ioctl_download;
 
//assign AUDIO_MIX = status[3:2];

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX XX      XXX

`include "build_id.v" 
parameter CONF_STR = {
	"X68000;;",
	"-;",
	"S0U,D88,FDD0;",
	"S1U,D88,FDD1;",
	"S2U,HDF,SASI Hard Disk;",
	"S3,RAM,SRAM;",
	"-;",
	"T9,Save FDD0 changes to SD;",
	"TA,Save FDD1 changes to SD;",
	"-;",
	"TB,Eject FDD0;",
	"TC,Eject FDD1;",
	"-;",
	"TD,Load SRAM from SD Card;",
	"TE,Save SRAM to SD Card;",
	"-;",
//
	"O3,Video Frequency,60fps,Original;",
//	"-;",
	"O4,CPU speed,Normal,Turbo;",
	"T7,NMI Button;",
	"T8,Power Button;",
	"T0,Reset;",
	"-;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_ram, clk_sys;
wire pll_locked;

pll pll
(
	.inclk0(CLK12M),
	.c0(clk_ram), // 80mhz
	.c1(clk_sys), // 40mhz
	.locked(pll_locked)
);


// Video oscillators
// 40.00000 - CPU/Main Oscillator
// 69.55199 - Video clock
// 38.86363 - Also attached to video circuits

altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone 10 LP"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)


sdramclk_ddr
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk_ram),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);


/////////////////  HPS  ///////////////////////////

wire [63:0] status;
wire  [1:0] buttons;

wire [15:0] joystick_0, joystick_1;

wire  [5:0] joyA = ~{joystick_0[5:4],joystick_0[0] | joystick_0[6],joystick_0[1] | joystick_0[6],joystick_0[2] | joystick_0[7],joystick_0[3] | joystick_0[7]};
wire  [5:0] joyB = ~{joystick_1[5:4],joystick_1[0] | joystick_1[6],joystick_1[1] | joystick_1[6],joystick_1[2] | joystick_1[7],joystick_1[3] | joystick_1[7]};

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;
wire        ps2_mouse_clk_out;
wire        ps2_mouse_data_out;
wire        ps2_mouse_clk_in;
wire        ps2_mouse_data_in;

wire  [31:0] sd_lba;
wire   [3:0] sd_rd;
wire   [3:0] sd_wr;

wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [3:0] img_mounted;
wire  [3:0] img_readonly;
wire [63:0] img_size;

//wire [65:0] ps2_key;
wire [63:0] sysrtc;
wire forced_scandoubler;
wire [21:0] gamma_bus;
wire  [7:0] uart1_mode;
wire [31:0] uart1_speed;

//hps_io #(.CONF_STR(CONF_STR), .PS2DIV(1625), .PS2WE(1), .VDNUM(4)) hps_io
//(
//	.clk_sys(clk_sys),
//	.HPS_BUS(HPS_BUS),
//
//	.buttons(buttons),
//	.status(status),
//	.status_menumask({mt32_newmode, mt32_available, en216p}),
//	.info_req(mt32_info_req),
//	.info(mt32_info_disp),
//
//	.sd_lba('{sd_lba,sd_lba,sd_lba,sd_lba}),
//	.sd_rd(sd_rd),
//	.sd_wr(sd_wr),
//	.sd_ack(sd_ack),
//	.sd_buff_addr(sd_buff_addr),
//	.sd_buff_dout(sd_buff_dout),
//	.sd_buff_din('{sd_buff_din,sd_buff_din,sd_buff_din,sd_buff_din}),
//	.sd_buff_wr(sd_buff_wr),
// 
//	.img_mounted(img_mounted),
//	.img_readonly(img_readonly),
//	.img_size(img_size),
//	
//	.forced_scandoubler(forced_scandoubler),
//	.gamma_bus(gamma_bus),
//
//	.ioctl_download(ioctl_download),
//	.ioctl_index(ioctl_index),
//	.ioctl_wr(ioctl_wr),
//	.ioctl_addr(ioctl_addr),
//	.ioctl_dout(ioctl_dout),
//	.ioctl_wait(ldr_wr),
//	
//	// .uart_mode(uart1_mode),
//	// .uart_speed(uart1_speed),
//
////	.new_vmode(status[4]), // Use for option to avoid 24khz
//
//	.ps2_kbd_clk_out(ps2_kbd_clk_out),
//	.ps2_kbd_data_out(ps2_kbd_data_out),
//	.ps2_kbd_clk_in(ps2_kbd_clk_in),
//	.ps2_kbd_data_in(ps2_kbd_data_in),
//	.ps2_mouse_clk_out(ps2_mouse_clk_out),
//	.ps2_mouse_data_out(ps2_mouse_data_out),
//	.ps2_mouse_clk_in(ps2_mouse_clk_in),
//	.ps2_mouse_data_in(ps2_mouse_data_in),
//
//	.ps2_key(ps2_key),
//	
//	.RTC(sysrtc),
//
//	.joystick_0(joystick_0),
//	.joystick_1(joystick_1)
//);

wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire  [1:0] switches;
wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

reg         mouse_strobe_level;

wire        sd_ack_conf;
wire        sd_conf;

always @(posedge clk_sys) if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif





user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(4), .PS2DIV(2400),.PS2BIDIR(1), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
( 
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
	 .rtc(sysrtc),

    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons),
    .switches(switches),
    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_flags(mouse_flags),
    .mouse_strobe(mouse_strobe),
	 
	.ps2_kbd_clk(ps2_kbd_clk_out),
	.ps2_kbd_data(ps2_kbd_data_out),
	.ps2_kbd_clk_i(ps2_kbd_clk_in),
	.ps2_kbd_data_i(ps2_kbd_data_in),
	.ps2_mouse_clk(ps2_mouse_clk_out),
	.ps2_mouse_data(ps2_mouse_data_out),
	.ps2_mouse_clk_i(ps2_mouse_clk_in),
	.ps2_mouse_data_i(ps2_mouse_data_in),

`ifdef USE_HDMI
    .i2c_start      (i2c_start      ),
    .i2c_read       (i2c_read       ),
    .i2c_addr       (i2c_addr       ),
    .i2c_subaddr    (i2c_subaddr    ),
    .i2c_dout       (i2c_dout       ),
    .i2c_din        (i2c_din        ),
    .i2c_ack        (i2c_ack        ),
    .i2c_end        (i2c_end        ),
`endif

    .sd_lba         (sd_lba),
    .sd_rd          (sd_rd),
    .sd_wr          (sd_wr),
    .sd_ack_x       (sd_ack),
	 .sd_ack_conf    (sd_ack_conf   ),
    .sd_dout        (sd_buff_dout),
    .sd_dout_strobe (sd_buff_wr),
    .sd_din         (sd_buff_din),
    .sd_buff_addr   (sd_buff_addr),
    .sd_conf        (sd_conf),
    .sd_sdhc        (1'b1),
    .img_mounted(img_mounted),
    .img_size(img_size)
);

data_io data_io (
    // SPI interface
    .SPI_SCK        ( SPI_SCK ),
    .SPI_SS2        ( SPI_SS2 ),
    .SPI_DI         ( SPI_DI  ),
    // ram interface
    .clk_sys        ( clk_sys ),
    //.clkref_n       ( ~clk_ref  ),
    .ioctl_download ( ioctl_download ),
    .ioctl_index    ( ioctl_index ),
    .ioctl_wr       ( ioctl_wr ),
    .ioctl_addr     ( ioctl_addr ),
    .ioctl_dout     ( ioctl_dout )
);

/////////////////  RESET  /////////////////////////

wire [3:0] img_mounted_d;
wire [1:0] fdd_eject_d;
reg [23:0] mount_count[4];
reg [15:0] fdd_eject_count[2];
assign fdd_eject_d[0] = |mount_count[0][23:16] || |fdd_eject_count[0];
assign fdd_eject_d[1] = |mount_count[1][23:16] || |fdd_eject_count[1];
assign img_mounted_d[0] = ~fdd_eject_d[0] && |mount_count[0];
assign img_mounted_d[1] = ~fdd_eject_d[1] && |mount_count[1];
assign img_mounted_d[2] = |mount_count[2];
assign img_mounted_d[3] = |mount_count[3];

reg reset_n = 0;
reg reset;
always @(posedge clk_sys) begin : rst_block
	reg init_reset_n = 0;
	reg old_rst = 0;
	reg [3:0] old_im = 4'd0;
	reg old_download;
	reg [15:0] reset_delayed;
	
	old_download <= ioctl_download;
	old_im <= img_mounted;
	if(~old_download & ioctl_download) reset_n <= 1;
	
	for (logic [2:0] x = 0; x < 3'd4; x=x+1'd1) begin
		if (mount_count[x])
			mount_count[x] <= mount_count[x] - 1'd1;
		if (img_mounted[x])
			mount_count[x] <= 24'hFFFFFF;
	end
	if (fdeject[0])
		fdd_eject_count[0]<= 16'hFFFF;
	if (fdeject[1])
		fdd_eject_count[1]<= 16'hFFFF;
	if (fdd_eject_count[0])
		fdd_eject_count[0] <= fdd_eject_count[0] - 1'd1;
	if (fdd_eject_count[1])
		fdd_eject_count[1] <= fdd_eject_count[1] - 1'd1;

	reset <= buttons[1] || status[0] || ~pll_locked  ||~init_reset_n  ||reset_delayed;

	if (reset_delayed)
		reset_delayed <= reset_delayed - 1'd1;
	if (~old_im[2] && img_mounted[2]) begin
		reset_delayed <= 16'hFFFF;
	end


	old_rst <= status[0];
	if(old_rst & ~status[0]) init_reset_n <= 1;
end

////////////////////////////  MT32pi  ////////////////////////////////// 
//wire        mt32_reset    = status[40] | reset;
//wire        mt32_disable  = status[18];
//wire        mt32_mode_req = status[19];
//wire  [1:0] mt32_rom_req  = status[21:20];
//wire  [7:0] mt32_sf_req   = status[31:29];
//wire  [1:0] mt32_info     = status[42:41];

//wire [15:0] mt32_i2s_r, mt32_i2s_l;
//wire  [7:0] mt32_mode, mt32_rom, mt32_sf;
//wire        mt32_lcd_en, mt32_lcd_pix, mt32_lcd_update;
//wire        midi_rx;

//wire mt32_newmode;
//wire mt32_available;
//wire mt32_use  = mt32_available & ~mt32_disable;
//wire mt32_mute = mt32_available &  mt32_disable;

//mt32pi mt32pi
//(
//	.*,
//	.reset(mt32_reset),
//	.midi_tx(UART_TX | mt32_mute)
//);

//reg mt32_info_req;
//reg [3:0] mt32_info_disp;
//always @(posedge clk_sys) begin
//	reg old_mode;
//
//	old_mode <= mt32_newmode;
//	mt32_info_req <= (old_mode ^ mt32_newmode) && (mt32_info == 1);
//	
//	mt32_info_disp <= (mt32_mode == 'hA2) ? (4'd1 + mt32_sf[2:0]) :
//                     (mt32_mode == 'hA1 && mt32_rom == 0) ?  4'd9 :
//                     (mt32_mode == 'hA1 && mt32_rom == 1) ?  4'd10 :
//                     (mt32_mode == 'hA1 && mt32_rom == 2) ?  4'd11 : 4'd12;
//end
//
//reg mt32_lcd_on;
//always @(posedge CLK_VIDEO) begin
//	int to;
//	reg old_update;
//
//	old_update <= mt32_lcd_update;
//	if(to) to <= to - 1;
//
//	if(mt32_info == 2) mt32_lcd_on <= 1;
//	else if(mt32_info != 3) mt32_lcd_on <= 0;
//	else begin
//		if(!to) mt32_lcd_on <= 0;
//		if(old_update ^ mt32_lcd_update) begin
//			mt32_lcd_on <= 1;
//			to <= 90000000 * 2;
//		end
//	end
//end
//
//wire mt32_lcd = mt32_lcd_on & mt32_lcd_en;

///////////////////////////////////////////////////
wire [15:0] aud_r, aud_l, pcm_r, pcm_l, ym_r, ym_l;

wire NMI = status[7];
wire POWER = status[8];
wire [1:0] fdsync = status[10:9];
wire [1:0] fdeject = status[12:11];
wire sramld	= status[13];
wire sramst = status[14];

//assign CLK_VIDEO = clk_vid;
//assign AUDIO_S = 1;

wire disk_led;

wire [7:0] red, green, blue;
wire HBlank, VBlank, HSync, VSync, ce_pix, vid_de;

wire snd_clockmode;
reg sys_ce;
reg mpu_cep;
reg mpu_cen;
reg snd_ce;
reg [1:0] opm_ce = 0;

always @(posedge clk_sys) begin
	reg [4:0] div_opm;
	reg [1:0] div_sys;
	reg [3:0] div_snd;
	reg [3:0] div_snd2;
	reg turbo = 0;

	div_sys <= div_sys + 1'd1;
	div_snd <= div_snd + 1'd1;
	div_snd2 <= div_snd2 + 1'd1;
	div_opm <= div_opm + 1'd1;

	if (div_snd2 == 9) div_snd <= 0;
	if (div_snd == 4)  div_snd <= 0;
	if (div_opm == 19) div_opm <= 0;

	opm_ce[0] <= div_snd2 == 9;
	opm_ce[1] <= div_opm == 19;

	sys_ce <= &div_sys;

	if(&div_sys) turbo <= status[4];
	mpu_cep <= turbo ?  div_sys[0] : ( div_sys[1] & div_sys[0]);
	mpu_cen <= turbo ? ~div_sys[0] : (~div_sys[1] & div_sys[0]);

	snd_ce  <= snd_clockmode ? (div_snd2 == 9) : (div_snd == 4);
end

X68K_top X68K_top
(
	.ramclk     (clk_ram),
	.sysclk     (clk_sys),
	.vidclk     (clk_ram),
	.fdcclk     (clk_sys),
	.sndclk     (clk_sys),
	
	.sys_ce     (sys_ce),
	.mpu_cep    (mpu_cep),
	.mpu_cen    (mpu_cen),
	.snd_ce     (snd_ce),
	.opm_ce     (opm_ce),
	
	.cm_out     (snd_clockmode),

	.plllock    (pll_locked),

	.sysrtc     (sysrtc),

	.pMemCke(SDRAM_CKE),
	.pMemCs_n(SDRAM_nCS),
	.pMemRas_n(SDRAM_nRAS),
	.pMemCas_n(SDRAM_nCAS),
	.pMemWe_n(SDRAM_nWE),
	.pMemUdq(SDRAM_DQMH),
	.pMemLdq(SDRAM_DQML),
	.pMemBa1(SDRAM_BA[1]),
	.pMemBa0(SDRAM_BA[0]),
	.pMemAdr(SDRAM_A),
	.pMemDat(SDRAM_DQ),

	.ldr_addr(ioctl_addr[19:0]),
	.ldr_wdat(ioctl_dout),
	.ldr_aen(ioctl_download & ~ldr_done),
	.ldr_wr(ldr_wr),
	.ldr_ack(ldr_ack),
	.ldr_done(ldr_done),
	.vid_hz(~status[3]),

	.pPs2Clkin(ps2_kbd_clk_out),
	.pPs2Clkout(ps2_kbd_clk_in),
	.pPs2Datin(ps2_kbd_data_out),
	.pPs2Datout(ps2_kbd_data_in),

	.pPmsClkin(ps2_mouse_clk_out),
	.pPmsClkout(ps2_mouse_clk_in),
	.pPmsDatin(ps2_mouse_data_out),
	.pPmsDatout(ps2_mouse_data_in),

	.mist_mounted(img_mounted_d),
	.mist_readonly(img_readonly),
	.mist_imgsize(img_size),

	.mist_lba(sd_lba),
	.mist_rd(sd_rd),
	.mist_wr(sd_wr),
	.mist_ack({sd_ack[3:2], |sd_ack[1:0], |sd_ack[1:0]}),

	.mist_buffaddr(sd_buff_addr),
	.mist_buffdout(sd_buff_dout),
	.mist_buffdin(sd_buff_din),
	.mist_buffwr(sd_buff_wr),

	.pJoyA(joyA),
	.pJoyB(joyB),

	.pFDSYNC(fdsync),
	.pFDEJECT(fdd_eject_d),
	.pFDMOTOR(fdd_active),

	.pLed(disk_led),
	.pDip(4'b0000),
	.pPsw({~NMI,~POWER}),
	.pSramld(sramld),
	.pSramst(sramst),

	.pMidi_in(UART_RX),
	.pMidi_out(UART_TX),

	.pVideoR(red),
	.pVideoG(green),
	.pVideoB(blue),
	.pVideoHS(HSync),
	.pVideoVS(VSync),
	.pVideoHB(HBlank),
	.pVideoVB(VBlank),
	.pVideoEN(vid_de),
	.pVideoClk(ce_pix),
//	.pVideoF1(VGA_F1),

	.pSndL(aud_r),
	.pSndR(aud_l),
	
	.pSndYML(ym_l),
	.pSndYMR(ym_r),
	.pSndPCML(pcm_l),
	.pSNDPCMR(pcm_r),

	.rstn(reset_n & ~reset),
	.dHMode(status[45:44]),
	.dVMode(status[46])
);

wire ldr_ack;
reg ldr_wr = 0;
reg ldr_done = 0;
always @(posedge clk_sys) begin
	reg old_ack, old_download;

	old_download <= ioctl_download;
	old_ack <= ldr_ack;

	if(~old_ack & ldr_ack & ldr_wr) ldr_wr <= 0;
	if(ioctl_wr & ~ldr_done) ldr_wr <= 1;

	if(old_download & ~ioctl_download) ldr_done <= 1;
end

wire hdd_active;
wire fdd_active;
//led hdd_led(clk_sys,  sd_ack[2],   hdd_active);
//led fdd_led(clk_sys, |sd_ack[1:0], fdd_active);


////////////////////////////  AUDIO  ////////////////////////////////////
wire [17:0] mix_r, mix_l;
reg [15:0] out_l, out_r;

localparam [3:0] comp_f1 = 4;
localparam [3:0] comp_a1 = 2;
localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b1 = comp_x1 * comp_a1;

localparam [3:0] comp_f2 = 8;
localparam [3:0] comp_a2 = 4;
localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b2 = comp_x2 * comp_a2;

function [15:0] compr; input [15:0] inp;
	reg [15:0] v, v1, v2;
	begin
		v  = inp[15] ? (~inp) + 1'd1 : inp;
		v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
		v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
		v  = status[21] ? v2 : v1;
		compr = inp[15] ? ~(v-1'd1) : v;
	end
endfunction 

reg [15:0] cmp_l, cmp_r;

always @(posedge clk_sys) begin

	out_l <= aud_l;
	out_r <= aud_r;	
end

`ifdef I2S_AUDIO

wire [31:0] clk_rate =  32'd40_000_000;

i2s i2s (
        .reset(reset),
        .clk(clk_sys),
        .clk_rate(clk_rate),

        .sclk(I2S_BCK),
        .lrclk(I2S_LRCK),
        .sdata(I2S_DATA),

        .left_chan (out_l),
        .right_chan(out_r)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.clk_i(clk_sys),
	.rst_i(1'b0),
	.clk_rate_i(clk_rate),
	.spdif_o(SPDIF),
	.sample_i({out_l,out_r})
);
`endif

dac #(
   .c_bits	(16))
audiodac_l(
   .clk_i	(clk_sys	),
   .res_n_i	(1	),
   .dac_i	(out_l),
   .dac_o	(AUDIO_L)
  );

dac #(
   .c_bits	(16))
audiodac_r(
   .clk_i	(clk_sys	),
   .res_n_i	(1	),
   .dac_i	(out_r),
   .dac_o	(AUDIO_R)
  );

  
////////////////////////////  VIDEO  ////////////////////////////////////
  
mist_video #(.COLOR_DEPTH(8),.OUT_COLOR_DEPTH(VGA_BITS),.USE_BLANKS(1),.VIDEO_CLEANER(1), .BIG_OSD(BIG_OSD)) mist_video (	
   .*,
	.clk_sys      (clk_sys    ),
	.SPI_SCK      (SPI_SCK    ),
	.SPI_SS3      (SPI_SS3    ),
	.SPI_DI       (SPI_DI     ),
	.R            (red),
	.G            (green),
	.B            (blue),
	.HSync        (HSync),
	.VSync        (VSync),
	.HBlank       (HBlank),
	.VBlank       (VBlank),
	.VGA_R        (VGA_R      ),
	.VGA_G        (VGA_G      ),
	.VGA_B        (VGA_B      ),
	.VGA_VS       (VGA_VS     ),
	.VGA_HS       (VGA_HS     ),
	.VGA_HB(),
	.VGA_VB(),
	.VGA_DE(),
	.ce_divider   (3'd0       ),
	.scandoubler_disable (1'b1),
	.rotate(2'b00),
   .blend(1'b0),
	.no_csync(1'b1),
	.scanlines    ()
	);

	
`ifdef USE_HDMI
i2c_master #(40_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(6), .SD_HCNT_WIDTH(11), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video (
	.clk_sys     ( clk_sys   ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),
	.scanlines   (  ),
	.ce_divider  ( 3'd0       ),
	.scandoubler_disable (1'b1),
	.no_csync    ( 1'b1       ),
	.ypbpr       ( 1'b0       ),
	.rotate      ( 2'b00      ),
	.blend       ( 1'b0       ),
	.R           (red),
	.G           (green),
	.B           (blue),
	.HBlank      ( HBlank      ),
	.VBlank      ( VBlank      ),
	.HSync       ( HSync       ),
	.VSync       ( VSync       ),
	.VGA_R       ( HDMI_R      ),
	.VGA_G       ( HDMI_G      ),
	.VGA_B       ( HDMI_B      ),
	.VGA_VS      (HDMI_VS      ),
	.VGA_HS      (HDMI_HS      ),
	.VGA_DE      ( HDMI_DE     )
);
assign HDMI_PCLK = clk_sys;

`endif


////////////////////////////  VIDEO  ////////////////////////////////////


//video_mixer #(.LINE_LENGTH(800), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
//(
//	.*,
//
////	.VGA_DE(vga_de),
//	.hq2x(scale==1),
//	.HSync(HSync),
//	.HBlank(HBlank),
//	.VSync(VSync),
//	.VBlank(VBlank),
//	.freeze_sync(),
//
//	.R(r_mt),
//	.G(g_mt),
//	.B(b_mt)
//);


endmodule

module led
(
	input      clk,
	input      in,
	output reg out
);

integer counter = 0;
always @(posedge clk) begin
	if(!counter) out <= 0;
	else begin
		counter <= counter - 1'b1;
		out <= 1;
	end
	
	if(in) counter <= 4500000;
end

endmodule
