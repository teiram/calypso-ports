`default_nettype none

module sordm5_calypso(
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

assign LED[0] = reset;
assign LED[1] = ioctl_download; 

`include "build_id.v"
parameter CONF_STR = {
    "SordM5;;",
    "-;",
    "O02,Memory extension,None,EM-5,EM-64,64KBF,64KRX,BrnoMod;",
    "O34,Cartridge,None,BASIC-I,BASIC-G,BASIC-F;",
    "P1,EM64;",
    "P1O5,EM64 mode,64KB,32KB;",
    "P1O6,EM64 mon. deactivate,Dis.,En.;",
    "P1O7,EM64 wp low 32KB,Dis.,En.;",
    "P1O8,EM64 boot on,ROM,RAM;",  
    "F,BINROM,Load to ROM;",
    "F,CAS,Load Tape;",
    "O9,Fast Tape Load,On,Off;",
    "OA,Tape Sound,On,Off;",
    "-;",
    "OEF,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
    "OG,Border,No,Yes;",
    "-;",
    "TH,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys /* synthesis keep */;
wire pll_locked;
pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
    reg [2:0] div;
    
    div <= div + 1'd1;
    ce_10m7 <= !div[1:0];
    ce_5m3  <= !div[2:0];
end

/////////////////  RESET  /////////////////////////

reg [4:0] old_ram_mode = 5'd0;
always @(posedge clk_sys) begin
    old_ram_mode <= status[4:0];
end

wire ram_mode_changed = old_ram_mode == status[4:0] ? 1'b0 : 1'b1 ;
wire reset =  ~pll_locked | ram_mode_changed | status[17] | ioctl_download;

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;

wire        ioctl_download /* synthesis keep */;
wire  [7:0] ioctl_index /* synthesis keep */;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire no_csync;
wire ypbpr;

wire        cart_enable = status[2:1] ==  2'b00 | status[2:0] == 3'b010;
wire        binary_load_enable = cart_enable & status[4:3] == 2'b00;
wire        kb64_enable = status[2:0] == 3'b010;


wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;
wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b0),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),
    .scandoubler_disable(forced_scandoubler),
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons),
	
    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
	 
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
    .joystick_0(joy0),
    .joystick_1(joy1)
);

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


data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
`ifdef USE_QSPI
    .QSCK(QSCK),
    .QCSn(QCSn),
    .QDAT(QDAT),
`endif
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


////////////////  Console  ////////////////////////
wire [10:0] audio;
wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;
wire [15:0] audio_left;
wire [15:0] audio_right;
assign audio_left = {audio, 5'd0};
assign audio_right = {audio, 5'd0};


sordM5 SordM5(
    .clk_i(clk_sys),
    .clk_en_10m7_i(ce_10m7),
    .reset_n_i(~reset),
    .por_n_o(),
    .border_i(status[16]),
    .rgb_r_o(R),
    .rgb_g_o(G),
    .rgb_b_o(B),
    .hsync_n_o(hsync),
    .vsync_n_o(vsync),
    .hblank_o(hblank),
    .vblank_o(vblank),
    .audio_o(audio),
    .ps2_key_i(ps2_key),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_download(ioctl_download),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_CLK(SDRAM_CLK),
    .SDRAM_CKE(SDRAM_CKE),
    .pll_locked_i(pll_locked),
    
    .AUDIO_INPUT(AUDIO_IN),

    .casSpeed(status[9]),
    .tape_sound_i(status[10]),
    .ramMode_i(status[8:0])
);


`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd42_660_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({audio_left}),
	.right_chan({audio_right})
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

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b110),
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
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd3),
    .scandoubler_disable(forced_scandoubler),
    .no_csync(1'b1),
    .scanlines(status[15:14]),
    .ypbpr(ypbpr)
);

endmodule
