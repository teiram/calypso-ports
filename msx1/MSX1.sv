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
//
//============================================================================



module calypso_top
(
	input         CLK12M,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output       [7:0] LED,
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


	


assign SDRAM_CLK = sdram_clk_o;

//////////////////////////////////////////////////////////////////


`include "build_id.v" 

parameter CONF_STR = {
        "MSX1;;",
        "S0,VHDIMGDSK;",
		  "O2,Hard reset after Mount,No,Yes;",
        "O3,Joysticks Swap,No,Yes;",
		  `SEP
		  "OD,F18A Max Sprites,4,32;",
        "OE,F18A Scanlines,Off,On;",
		  `SEP
        "T1,Reset (soft);",
		  "T0,Reset (hard);",
        "V,calypso-",`BUILD_DATE 
};


wire scandoubler_disable;
wire no_csync;
wire  [1:0] buttons;
wire  [1:0] switches;
wire [31:0] status;



//VHD	
wire [31:0] sd_lba;
wire   		sd_rd;
wire   		sd_wr;

wire        sd_ack;
wire        sd_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_dout_strobe;
wire        sd_din_strobe;

wire        img_readonly;

wire        sd_ack_conf;

wire        img_mounted;
wire [63:0] img_size;


//Keyboard Ps2
wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;

// Analog joySticks
wire       joystick_analog_0;
wire       joystick_analog_1;

wire ypbpr;


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

user_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(750),.SD_IMAGES(1), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(	
	.clk_sys        	(clk_sys         	),
	.clk_sd           (clk_sys           ),
	.conf_str       	(CONF_STR       	),
	.SPI_CLK        	(SPI_SCK        	),
	.SPI_SS_IO      	(CONF_DATA0     	),
	.SPI_MISO       	(SPI_DO        	),
	.SPI_MOSI       	(SPI_DI         	),

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

	.buttons        	(buttons        	),
	.switches       	(switches      	),
	.scandoubler_disable (scandoubler_disable	),
	.ypbpr          	(ypbpr          	),
	.no_csync         ( no_csync),

	.joystick_0       ( joy_A      ),
	.joystick_1       ( joy_B      ),
	.status         	(status         	),
//	
   .ps2_kbd_clk(ps2_kbd_clk_in),
	.ps2_kbd_data(ps2_kbd_data_in),
	.ps2_kbd_clk_i(ps2_kbd_clk_out),
	.ps2_kbd_data_i(ps2_kbd_data_out),
//
	// SD CARD
   .sd_lba                      (sd_lba        ),
	.sd_rd                       (sd_rd         ),
	.sd_wr                       (sd_wr         ),
	.sd_ack                      (sd_ack        ),
	.sd_ack_conf                 (sd_ack_conf   ),
	.sd_conf                     (sd_conf       ),
	.sd_sdhc                     (1'b1          ),
	.sd_dout                     (sd_buff_dout  ),
	.sd_dout_strobe              (sd_buff_wr    ),
	.sd_din                      (sd_buff_din   ),
	.sd_din_strobe               (sd_din_strobe ),
	.sd_buff_addr                (sd_buff_addr  ),
	.img_mounted                 (img_mounted   ),
	.img_size                    (img_size      )
);


assign LED=sd_rd||sd_wr;

///////////////////////   CLOCKS   ///////////////////////////////

wire clock_sdram_s, sdram_clk_o, clock_vga_s, pll_locked;
wire clk_sys;
wire clk_100,clk_25;


`ifdef USE_CLOCK_50
pll1 pll1
(
	.inclk0(CLOCK_50),
	.c0(clk_sys),	      // 21.477 MHz					[21.484]
	.c1(clock_sdram_s),  // 85.908 MHz (4x master)	[85.937] - 85.908 
	.c2(sdram_clk_o),		// 85.908 MHz -90°
	.locked(pll_locked)
);

pll_vdp pll_vdp
(
        .inclk0(CLOCK_50),
        .c0(clk_100),
		  .c1(clk_25)
);

`else

pll1 pll1
(
	.inclk0(CLK12M),
	.c0(clk_sys),	      // 21.477 MHz					[21.484]
	.c1(clock_sdram_s),  // 85.908 MHz (4x master)	[85.937] - 85.908 
	.c2(sdram_clk_o),		// 85.908 MHz -90°
	.locked(pll_locked)
);

pll_vdp pll_vdp
(
        .inclk0(CLK12M),
        .c0(clk_100),
		  .c1(clk_25)
);
`endif


wire reset = status[0] | buttons[1] | !pll_locked | (status[2] && img_mounted);



//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire vga_blank;

//////////////////   SD   ///////////////////

wire sdclk;
wire sdmosi;
wire sdmiso;
wire sd_busy;
wire sdss;


sd_card1 sd_card1
(
	.*,
	.clk_spi(clk_sys), 
	.sdhc(1'b1),
	.sck(sdclk),
	.ss(sdss),
	.mosi(sdmosi),
	.miso(sdmiso)
);


wire [15:0] joy_0 = status[3] ? joy_B : joy_A;
wire [15:0] joy_1 = status[3] ? joy_A : joy_B;
wire [15:0] joy_A;
wire [15:0] joy_B;

wire vga_DE;

Mist_top msx
(



		.clock_master_s	(clk_sys),	//		: std_logic;
		.clock_sdram_s		(clock_sdram_s), 	//		: std_logic;
		.clk_100_i (clk_100),
		.clk_25_i  (clk_25),
		.sprite_max_i(~status[13]),
		.scan_lines_i(status[14]),

		.pll_locked_s		(pll_locked), 		//		: std_logic;
		.reset				(reset),
		.soft_reset_osd   (status[1]),
		
//		-- Buttons
		.sdram_cke_o	(SDRAM_CKE),					//			: out   std_logic								:= '0';
		.sdram_ad_o		(SDRAM_A),						//			: out   std_logic_vector(12 downto 0)	:= (others => '0');
		.sdram_da_io	(SDRAM_DQ),						//			: inout std_logic_vector(15 downto 0)	:= (others => 'Z');
		.sdram_ba_o		(SDRAM_BA),						//			: out   std_logic_vector( 1 downto 0)	:= (others => '0');
		.sdram_dqm_o	({SDRAM_DQMH,SDRAM_DQML}),	//		: out   std_logic_vector( 1 downto 0)	:= (others => '1');
		.sdram_ras_o	(SDRAM_nRAS),					//		: out   std_logic								:= '1';
		.sdram_cas_o	(SDRAM_nCAS),					//		: out   std_logic								:= '1';
		.sdram_cs_o		(SDRAM_nCS),					//	: out   std_logic								:= '1';
		.sdram_we_o		(SDRAM_nWE),					//			: out   std_logic								:= '1';

		
//		-- PS2
		.ps2_clk_i		(ps2_kbd_clk_in),				//	: inout std_logic								:= 'Z';
		.ps2_data_i		(ps2_kbd_data_in),			//	: inout std_logic								:= 'Z';
		.ps2_clk_o		(ps2_kbd_clk_out),			//	: inout std_logic								:= 'Z';
		.ps2_data_o		(ps2_kbd_data_out),			//	: inout std_logic								:= 'Z';

//		-- SD Card
		.sd_cs_n_o		(sdss),								//: out   std_logic								:= '1';
		.sd_sclk_o		(sdclk),								//: out   std_logic								:= '0';
		.sd_mosi_o		(sdmosi),								//: out   std_logic								:= '0';
		.sd_miso_i		(sdmiso),								//: in    std_logic;
		.sd_pres_n_i   (img_mounted),


		
//		-- Joysticks
		.joy1_up_i		(~joy_0[3]),	//	: in    std_logic;
		.joy1_down_i	(~joy_0[2]),	//			: in    std_logic;
		.joy1_left_i	(~joy_0[1]),	//			: in    std_logic;
		.joy1_right_i	(~joy_0[0]),	//		: in    std_logic;
		.joy1_p6_i		(~joy_0[4]),	//		: in    std_logic;
		.joy1_p9_i		(~joy_0[5]),	//		: in    std_logic;
		.joy2_up_i		(~joy_1[3]),	//		: in    std_logic;
		.joy2_down_i	(~joy_1[2]),	//			: in    std_logic;
		.joy2_left_i	(~joy_1[1]),	//			: in    std_logic;
		.joy2_right_i	(~joy_1[0]),	//		: in    std_logic;
		.joy2_p6_i		(~joy_1[4]),	//		: in    std_logic;
		.joy2_p9_i		(~joy_1[5]),	//		: in    std_logic;
//--		joyX_p7_o			: out   std_logic								:= '1';

//		-- Audio
		.dac_l_o        (),
		.dac_r_o			 (),
		.PreDac_l_s     (dac_in_l),
		.PreDac_r_s     (dac_in_r),
		.ear_i				(tape_in),		//	: in    std_logic;
//		mic_o					: out   std_logic								:= '0';

//		-- VGA
		.vga_r_o			(Rx),		//			: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_g_o			(Gx),		//	: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_b_o			(Bx),		//	: out   std_logic_vector(4 downto 0)	:= (others => '0');
		.vga_hsync_n_o	(HSync),	//	: out   std_logic								:= '1';
		.vga_vsync_n_o	(VSync),	//	: out   std_logic								:= '1';
		.VBlank		(VBlank),			//
		.HBlank		(HBlank),			//
		.vga_DE		(vga_DE)
		

	);
	

reg [3:0] Rx, Gx, Bx;

wire tape_in;
assign tape_in = TAPE_SOUND;


	mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(11), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (	
	.clk_sys      (clk_25     ),
	.SPI_SCK      (SPI_SCK    ),
	.SPI_SS3      (SPI_SS3    ),
	.SPI_DI       (SPI_DI     ),
	.R            (Rx ),
	.G            (Gx ),
	.B            (Bx ),
	.HSync        (HSync         ),
	.VSync        (VSync         ),
	.VGA_R        (VGA_R      ),
	.VGA_G        (VGA_G      ),
	.VGA_B        (VGA_B      ),
	.VGA_VS       (VGA_VS     ),
	.VGA_HS       (VGA_HS     ),
	.ce_divider   (1'b0       ),
	.scandoubler_disable(1'b1	),
	.no_csync     (1'b1	),
	.scanlines    (2'b0),
	.ypbpr        (ypbpr      )
	);

`ifdef USE_HDMI
i2c_master #(21_000_000) i2c_master (
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

mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(11),.OUT_COLOR_DEPTH(8), .USE_BLANKS(1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video (
	.*,
	.clk_sys     ( clk_25   ),
	.scanlines   (),
	.ce_divider  ( 3'd0       ),
	.scandoubler_disable (1'b1),
	.rotate      ( 2'b00      ),
	.blend       ( 1'b0       ),
	.no_csync    ( 1'b1),
	.R(Rx),
	.G(Gx),
	.B(Bx),
	.HBlank      (HBlank),
	.VBlank      (VBlank),
	.HSync       (HSync),
	.VSync       (VSync),
	.VGA_R       ( HDMI_R      ),
	.VGA_G       ( HDMI_G      ),
	.VGA_B       ( HDMI_B      ),
	.VGA_VS      ( HDMI_VS     ),
	.VGA_HS      ( HDMI_HS     ),
	.VGA_HB(),
	.VGA_VB(),
   .VGA_DE      ( HDMI_DE     )
);
assign HDMI_PCLK = clk_25;
`endif



//////////////////////////////// AUDIO ///////////////////////////
wire[15:0] dac_in_l;
wire[15:0] dac_in_r;

dac #(
   .c_bits	(16))
audiodac_l(
   .clk_i	(clk_sys	),
   .res_n_i	(1	),
   .dac_i	(dac_in_l),
   .dac_o	(AUDIO_L)
  );

dac #(
   .c_bits	(16))
audiodac_r(
   .clk_i	(clk_sys	),
   .res_n_i	(1	),
   .dac_i	(dac_in_r),
   .dac_o	(AUDIO_R)
  );

wire [31:0] clk_rate =  32'd21_489_796;

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan ({~dac_in_l[15],dac_in_l[14:0]}),
	.right_chan({~dac_in_r[15],dac_in_r[14:0]})
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
	.sample_i({dac_in_r, dac_in_l})
);
`endif


endmodule
