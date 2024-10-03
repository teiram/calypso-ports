////////////////////////////////////////////////////////////////////////////////
//
//
//
//  MENU for MIST board
//  (C) 2016 Sorgelig
//  (C) 2022 Slingshot
//
//
////////////////////////////////////////////////////////////////////////////////
module MENU
(
	input         CLOCK12,

	output        LED,
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
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_AUDIO,
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

	output [11:0] SDRAM_A,
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
localparam SEP = "-;";
`else
localparam bit BIG_OSD = 0;
localparam SEP = "";
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

`include "build_id.v"

wire clk_x2, clk_pix, clk_sys, clk_ram, pll_locked;
pll pll(
	.inclk0(CLOCK12),
	.c0(clk_ram),
	.c1(clk_sys),
	.c2(clk_x2),
	.c3(clk_pix),
	.locked(pll_locked)
);

/*
reg[2:0] ce_counter;
always @(posedge clk_ram)
begin
	ce_counter <= ce_counter + 6'd1;
	clk_sys <= ce_counter[0];
	clk_x2 <= ce_counter[1];
	clk_pix <= ce_counter[2];
end
*/

assign SDRAM_CLK = clk_ram;
assign SDRAM_CKE = 1;
//______________________________________________________________________________
//
// MIST ARM I/O
//
`include "build_id.v"

localparam CONF_STR = {
	"MENU;;",
	"O1,Video mode,PAL,NTSC;",
	"O23,Rotate,Off,Left,Right;",
	"V,",`BUILD_DATE
};

wire           scandoubler_disable;
wire           ypbpr;
wire           no_csync;
wire    [63:0] status;

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

user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'd1 | (BIG_OSD << 13) | (HDMI << 14)), .ROM_DIRECT_UPLOAD(DIRECT_UPLOAD)) user_io
(
	.clk_sys(clk_x2),
	.conf_str(CONF_STR),

	.SPI_CLK(SPI_SCK),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_MISO(SPI_DO),
	.SPI_MOSI(SPI_DI),
	.status(status),

	.scandoubler_disable(scandoubler_disable),
`ifdef USE_HDMI
	.i2c_start      ( i2c_start      ),
	.i2c_read       ( i2c_read       ),
	.i2c_addr       ( i2c_addr       ),
	.i2c_subaddr    ( i2c_subaddr    ),
	.i2c_dout       ( i2c_dout       ),
	.i2c_din        ( i2c_din        ),
	.i2c_ack        ( i2c_ack        ),
	.i2c_end        ( i2c_end        ),
`endif
	.ypbpr(ypbpr),
	.no_csync(no_csync)
);

wire        ntsc = status[1];
wire  [1:0] rotate = status[3:2];

wire  [8:0] line_max = ntsc ? 9'd262 : 9'd312;
assign LED = ~ioctl_downl;

wire        ioctl_downl;
wire        ioctl_upl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_dout;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD)) data_io(
	.clk_sys       ( clk_sys      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_upload  ( ioctl_upl    ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_din     ( ioctl_din    ),
	.ioctl_dout    ( ioctl_dout   )
);

reg  [23:0] bmp_data_start;
wire [22:0] downl_addr = ioctl_addr[22:0] - bmp_data_start[22:0];
reg         bmp_loaded = 0;
reg         port1_req;

always @(posedge clk_sys) begin
	reg        ioctl_wr_last = 0;
	reg        ioctl_downl_last = 0;

	ioctl_wr_last <= ioctl_wr;
	ioctl_downl_last <= ioctl_downl;

	if (ioctl_downl) begin
		if (~ioctl_wr_last & ioctl_wr) begin
			if (ioctl_addr == 10) bmp_data_start[7:0] <= ioctl_dout;
			else if (ioctl_addr == 11) bmp_data_start[15:8] <= ioctl_dout;
			else if (ioctl_addr == 12) bmp_data_start[23:16] <= ioctl_dout;
			port1_req <= ~port1_req;
		end
	end
	if (ioctl_downl_last & ~ioctl_downl) bmp_loaded <= 1;
end

wire [31:0] cpu_q;
reg [22:0] cpu1_addr;

// max is ((312 - 1) * 512) + 639) * 4 = 639484 . 20 bits
always @(posedge clk_ram) begin
	cpu1_addr <= (((line_max - 1'd1 - vc) * 640) + hc) << 2;
end

sdram #(.MHZ(100)) sdram(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_ram      ),
	.clkref        (),

	// ROM upload
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( downl_addr[22:1] ),
	.port1_ds      ( {downl_addr[0], ~downl_addr[0]} ),
	.port1_we      ( ioctl_downl ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       (  ),

	// CPU/video access
	.cpu1_addr     ( cpu1_addr[22:2] ),
	.cpu1_q        ( cpu_q ),
	.cpu1_oe       ( ~ioctl_downl )
);

//______________________________________________________________________________
//
// Video 
//

reg  [9:0] hc;
reg  [8:0] vc;
reg  [9:0] vvc;

reg [22:0] rnd_reg;
wire [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

wire [22:0] rnd;
lfsr random(rnd);

always @(posedge clk_pix) begin
	if(hc == 799) begin
		hc <= 0;
		if(vc == line_max - 1) begin
			vc <= 0;
			vvc <= vvc + 9'd6;
		end else begin
			vc <= vc + 1'd1;
		end
	end else begin
		hc <= hc + 1'd1;
	end
	
	rnd_reg <= rnd;
end

reg  HBlank;
reg  HSync, HSync_VGA;
reg  VBlank;
reg  VSync;

always @(posedge clk_pix) begin
/* original
	if (hc == 639) HBlank <= 1;
		else if (hc == 1) HBlank <= 0;

	if (hc == 655) HSync <= 1;
		else if (hc == 751) HSync <= 0;

   if (vc == line_max - 3 && hc == 655) VSync <= 1;
      else if (vc == 0 && hc == 751) VSync <= 0;

   if (vc == line_max - 5) VBlank <= 1;
      else if (vc == 2) VBlank <= 0;
*/
   if (hc == 640+2) begin
       HBlank <= 1;
       if (vc == line_max - 5) VBlank <= 1;
   end
   if (hc == 2) begin
       HBlank <= 0;
       if (vc == 2) VBlank <= 0;
   end

   if (hc == 655) begin
       HSync <= 1;
       HSync_VGA <= 1;
   end
   if (hc == 655+64) HSync <= 0;
   if (hc == 655+96) HSync_VGA <= 0;

   if(vc == line_max-3 && hc == 655) VSync <= 1;
		else if (vc == 0 && hc == 751) VSync <= 0;

end

///// Noise
reg  [7:0] cos_out;
wire [7:0] cos_g = cos_out[7:1]+6'd32;
cos cos(vvc + {vc, 2'b00}, cos_out);

wire [7:0] comp_v = (cos_g >= rnd_c) ? cos_g - rnd_c : 8'd0;

wire [7:0] R_in = bmp_loaded ? cpu_q[23:16] : comp_v;
wire [7:0] G_in = bmp_loaded ? cpu_q[15: 8] : comp_v;
wire [7:0] B_in = bmp_loaded ? cpu_q[7 : 0] : comp_v;

mist_video #(
	.COLOR_DEPTH(8),
	.SD_HCNT_WIDTH(10),
	.OSD_X_OFFSET(10),
	.OSD_Y_OFFSET(0),
	.OSD_COLOR(2),
	.OSD_AUTO_CE(0),
	.OUT_COLOR_DEPTH(VGA_BITS),
	.USE_BLANKS(1),
	.BIG_OSD(BIG_OSD)
) mist_video (
	.clk_sys        ( clk_x2           ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( R_in             ),
	.G              ( G_in             ),
	.B              ( B_in             ),
	.HBlank         ( HBlank           ),
	.VBlank         ( VBlank           ),
	.HSync          ( scandoubler_disable ? ~HSync : ~HSync_VGA ),
	.VSync          ( ~VSync           ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.ce_divider     ( 1'b1             ),
	.rotate         ( {rotate[0], |rotate} ),
	.blend          ( 1'b0             ),
	.scandoubler_disable( scandoubler_disable ),
	.scanlines      ( 2'b00            ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
	);

`ifdef USE_HDMI
i2c_master #(25_000_000) i2c_master (
	.CLK         (clk_x2),
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

wire HDMI_VB, HDMI_HB;

mist_video #(
	.COLOR_DEPTH(8),
	.SD_HCNT_WIDTH(10),
	.OSD_X_OFFSET(10),
	.OSD_Y_OFFSET(0),
	.OSD_COLOR(4),
	.OSD_AUTO_CE(0),
	.OUT_COLOR_DEPTH(8),
	.USE_BLANKS(1),
	.BIG_OSD(BIG_OSD),
	.VIDEO_CLEANER(1)
) hdmi_video (
	.clk_sys        ( clk_x2           ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( R_in             ),
	.G              ( G_in             ),
	.B              ( B_in             ),
	.HBlank         ( HBlank           ),
	.VBlank         ( VBlank           ),
	.HSync          ( ~HSync           ),
	.VSync          ( ~VSync           ),
	.VGA_R          ( HDMI_R           ),
	.VGA_G          ( HDMI_G           ),
	.VGA_B          ( HDMI_B           ),
	.VGA_VS         ( HDMI_VS          ),
	.VGA_HS         ( HDMI_HS          ),
	.VGA_HB         ( HDMI_HB          ),
	.VGA_VB         ( HDMI_VB          ),
	.VGA_DE         ( HDMI_DE          ),
	.ce_divider     ( 3'd1             ),
	.rotate         ( {rotate[0], |rotate} ),
	.blend          ( 1'b0             ),
	.scandoubler_disable( 1'b0         ),
	.scanlines      ( 2'b00            ),
	.ypbpr          ( 1'b0             ),
	.no_csync       ( 1'b1             )
	);

assign HDMI_PCLK = clk_x2;

`endif

endmodule
