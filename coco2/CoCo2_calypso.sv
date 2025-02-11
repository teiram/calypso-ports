//============================================================================
// 
//  Tandy Color Computer top level for MiST and compatibles
//  Copyright (C) 2024 Gyorgy Szombathelyi
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
//
//============================================================================

module CoCo2_calypso (
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
	input         HDMI_INT,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
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
`ifdef USE_EXPANSION
	output        EXP5,
`endif
	input         UART_RX,
	output        UART_TX

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

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

localparam CONF_STR = {
	"COCO2;;",
	"F1,CCCROM,Load Cartridge;",
	"S0U,DSK,Load Disk Drive 0;",
	"S1U,DSK,Load Disk Drive 1;",
	"S2U,DSK,Load Disk Drive 2;",
	"S3U,DSK,Load Disk Drive 3;",
	`SEP
	"P1,Video;",
	"P1O34,Scanlines,Off,25%,50%,75%;",
	"P1O5,Blend,Off,On;",
	"P1O6,Overscan,Hidden,Visible;",
	"P1O7,Artifact,Enable,Disable;",
	"P1O8,Artifact Phase,Normal,Reverse;",
	"O9,Machine,CoCo,Dragon;",
	"OA,Memory,16K,64K;",
	"OB,Joystick Swap,Off,On;",
	"OC,Tape Sounds,Off,On;",
`ifndef USE_EXPANSION
	"OD,Userport,Tape,UART;",
`endif
	"OE,Disk Cartridge,Disable,Enable;",
	"OF,Keyboard Layout,PC,CoCo;",
	`SEP
	"T2,Remove Cardrige;",
	"T0,Hard Reset;",
	"T1,Reset;",
	"V,v1.00.",`BUILD_DATE
};

wire        cart_remove = status[2];
wire  [1:0] scanlines = status[4:3];
wire        blend = status[5];
wire        overscan = status[6];
wire        artifact_enable = ~status[7];
wire        artifact_phase = status[8];
wire        dragon = status[9];
wire        mem64kb = status[10];
wire        joyswap = status[11];
wire        tapesnd = status[12];
wire        uart_en = status[13];
wire        disk_ena = status[14];
wire        kblayout = ~status[15];

wire        ledb;
assign      LED[0] = ~ledb;

wire clk57, pll_locked;
pll pll(
	.inclk0(CLK12M),
	.c0(clk57),
`ifdef USE_HDMI
	.c1(HDMI_PCLK),
`endif
	.locked(pll_locked)
	);

assign SDRAM_A = 13'hZZZZ;
assign SDRAM_BA = 0;
assign SDRAM_DQML = 1;
assign SDRAM_DQMH = 1;
assign SDRAM_CKE = 0;
assign SDRAM_CLK = 0;
assign SDRAM_nCS = 1;
assign SDRAM_DQ = 16'hZZZZ;
assign SDRAM_nCAS = 1;
assign SDRAM_nRAS = 1;
assign SDRAM_nWE = 1;

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [15:0] joystick_0;
wire [15:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;
wire        scandoublerD;
wire        ypbpr;
wire        no_csync;
wire  [6:0] core_mod;
wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

wire [31:0] sd_lba;
wire  [3:0] sd_rd;
wire  [3:0] sd_wr;
wire        sd_ack;
wire  [3:0] img_mounted;
wire [63:0] img_size;
wire  [7:0] sd_buff_dout;
wire        sd_buff_wr;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_din;

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

user_io #(
	.STRLEN(($size(CONF_STR)>>3)),
	.SD_IMAGES(4),
	.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
	.clk_sys        (clk57          ),
	.conf_str       (CONF_STR       ),
	.SPI_CLK        (SPI_SCK        ),
	.SPI_SS_IO      (CONF_DATA0     ),
	.SPI_MISO       (SPI_DO         ),
	.SPI_MOSI       (SPI_DI         ),
	.buttons        (buttons        ),
	.switches       (switches       ),
	.scandoubler_disable (scandoublerD),
	.ypbpr          (ypbpr          ),
	.no_csync       (no_csync       ),
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
	.core_mod       (core_mod       ),
	.key_strobe     (key_strobe     ),
	.key_pressed    (key_pressed    ),
	.key_extended   (key_extended   ),
	.key_code       (key_code       ),
	.leds           ({2'b01, 4'd0, upcase, 1'b1}),
	.joystick_0     (joystick_0     ),
	.joystick_1     (joystick_1     ),
	.joystick_analog_0 (joystick_analog_0 ),
	.joystick_analog_1 (joystick_analog_1 ),
	.status         (status         ),

	// SD/block device interface
	.clk_sd         ( clk57         ),
	.img_mounted    ( img_mounted   ),
	.img_size       ( img_size      ),
	.sd_lba         ( sd_lba        ),
	.sd_rd          ( sd_rd         ),
	.sd_wr          ( sd_wr         ),
	.sd_ack         ( sd_ack        ),
	.sd_conf        ( 1'b0          ),
	.sd_sdhc        ( 1'b1          ),
	.sd_dout        ( sd_buff_dout  ),
	.sd_dout_strobe ( sd_buff_wr    ),
	.sd_buff_addr   ( sd_buff_addr  ),
	.sd_din         ( sd_buff_din   )
	);

wire        ioctl_downl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

data_io data_io(
	.clk_sys       ( clk57        ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_DI        ( SPI_DI       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
);

reg reset = 1;
reg rom_loaded = 0;
reg hard_reset = 1;
reg [15:0] hard_reset_cnt = 0;

always @(posedge clk57) begin
	reg ioctl_downlD, mem64kb_d, dragon_d;
	ioctl_downlD <= ioctl_downl;
	mem64kb_d <= mem64kb;
	dragon_d <= dragon;

	if (mem64kb ^ mem64kb_d || dragon ^ dragon_d) hard_reset_cnt <= 16'hFFFF;
	if (ioctl_downlD & ~ioctl_downl) rom_loaded <= 1;
	reset <= hard_reset | status[1] | buttons[1] | ~rom_loaded;
	hard_reset <= status[0] | ioctl_downl | cart_remove | |hard_reset_cnt;
	if (|hard_reset_cnt) hard_reset_cnt <= hard_reset_cnt - 1'd1;
end

wire [11:0] sound;
reg   [1:0] cass_in;
wire        cass_out;
wire        cass_relay;
wire        uart_tx;
wire        upcase;

wire [16:0] ram_addr;
wire        ram_rd, ram_wr;
wire  [7:0] ram_dout, ram_din;

always @(posedge clk57) begin
`ifdef USE_AUDIO_IN
	cass_in[0] <= AUDIO_IN;
`else
	cass_in[0] <= UART_RX;
`endif
	cass_in[1] <= cass_in[0];
end

`ifdef USE_EXPANSION
assign EXP5 = ~cass_relay;
assign UART_TX = uart_tx;
`else
assign UART_TX = uart_en ? uart_tx : ~cass_relay;
`endif

wire  [7:0] red, green, blue;
wire        hb, vb, hs, vs;

wire [15:0] coco_joy1 = joyswap ? joystick_1 : joystick_0;
wire [15:0] coco_joy2 = joyswap ? joystick_0 : joystick_1;

wire [15:0] coco_ajoy1 = joyswap ? joystick_analog_1 : joystick_analog_0;
wire [15:0] coco_ajoy2 = joyswap ? joystick_analog_0 : joystick_analog_1;

dragoncoco dragoncoco(
  .clk(clk57), // 57.272 mhz
  .por(~pll_locked),
  .reset_n(~reset),
  .hard_reset(hard_reset),
  .cart_remove(cart_remove),
  .dragon(dragon),
  .kblayout(kblayout),
  .mem64kb(mem64kb),
  .red(red),
  .green(green),
  .blue(blue),

  .hblank(hb),
  .vblank(vb),
  .hsync(hs),
  .vsync(vs),
  .vclk(),
  .uart_rx(UART_RX),
  .uart_tx(uart_tx),

  .key_strobe(key_strobe),
  .key_pressed(key_pressed),
  .key_extended(key_extended),
  .key_code(key_code),

  .ioctl_addr(ioctl_addr),
  .ioctl_data(ioctl_dout),
  .ioctl_download(ioctl_downl),
  .ioctl_wr(ioctl_wr),
  .ioctl_cart(ioctl_index[5:0] == 1),
  .ioctl_rom(ioctl_index == 0),

  .casdout(cass_in[1]),
  .cas_relay(cass_relay),
  .artifact_phase(artifact_phase),
  .artifact_enable(artifact_enable),
  .overscan(overscan),

  .joy_use_dpad(1'b0),

  .joy1(coco_joy1),
  .joy2(coco_joy2),

  .joya1({coco_ajoy1[15:8]-8'h80, coco_ajoy1[7:0]-8'h80}),
  .joya2({coco_ajoy2[15:8]-8'h80, coco_ajoy2[7:0]-8'h80}),

  .cass_snd(adc_value),
  .sound(sound),
  .sndout(sndout),

  // we load the disk ROM instead of cart ram
  .disk_cart_enabled(disk_ena),

  .img_mounted  ( img_mounted    ),
  .img_size     ( img_size       ),
  .sd_lba       ( sd_lba         ),
  .sd_rd        ( sd_rd          ),
  .sd_wr        ( sd_wr          ),
  .sd_ack       ( sd_ack         ),
  .sd_buff_addr ( sd_buff_addr   ),
  .sd_buff_dout ( sd_buff_dout   ),
  .sd_buff_din  ( sd_buff_din    ),
  .sd_buff_wr   ( sd_buff_wr     )
);

mist_dual_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1'b1)) mist_video(
	.clk_sys        ( clk57            ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( red              ),
	.G              ( green            ),
	.B              ( blue             ),
	.HBlank         ( hb               ),
	.VBlank         ( vb               ),
	.HSync          ( hs               ),
	.VSync          ( vs               ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
`ifdef USE_HDMI
	.HDMI_R         ( HDMI_R           ),
	.HDMI_G         ( HDMI_G           ),
	.HDMI_B         ( HDMI_B           ),
	.HDMI_VS        ( HDMI_VS          ),
	.HDMI_HS        ( HDMI_HS          ),
	.HDMI_DE        ( HDMI_DE          ),
`endif
	.ce_divider     ( 4'h3             ),
	.rotate         ( 2'b00            ),
	.rotate_screen  ( 1'b0             ),
	.rotate_hfilter ( 1'b0             ),
	.rotate_vfilter ( 1'b0             ),
	.blend          ( blend            ),
	.scandoubler_disable( scandoublerD ),
	.scanlines      ( scanlines        ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
	);

`ifdef USE_HDMI

i2c_master #(57_000_000) i2c_master (
	.CLK         (clk57),

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
`endif

wire [12:0] audio_mix = sound + (tapesnd ? {cass_in[1], cass_out, 7'd0} : 13'd0);
dac #(
	.C_bits(15))
dac_l(
	.clk_i(clk57),
	.res_n_i(1),
	.dac_i(audio_mix),
	.dac_o(AUDIO_L)
	);

	assign AUDIO_R = AUDIO_L;

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk57),
	.clk_rate(32'd57_272_270),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan({~audio_mix[12], audio_mix[11:0], 3'd0}),
	.right_chan({~audio_mix[12], audio_mix[11:0], 3'd0})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk57) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.rst_i(1'b0),
	.clk_i(clk57),
	.clk_rate_i(32'd57_272_270),
	.spdif_o(SPDIF),
	.sample_i({2{{~audio_mix[12], audio_mix[11:0], 3'd0}}})
);
`endif

endmodule
