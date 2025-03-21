module SVI328(       
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

 
assign LED[0]  =  svi_audio_in;




`include "build_id.v" 
localparam CONF_STR = {
	"SVI328;;",
	"F,BINROM,Load Cartridge;",
	"F,CAS,Cas File;",
	"OF,Tape Input,File,Line;",
	"TD,Tape Rewind;",
	"O79,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"O6,Border,No,Yes;",
	"O3,Joysticks swap,No,Yes;",
	"T0,Reset;",
	"V,calypso-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire clk_sys;
wire pll_locked;

pll pll
(
	.inclk0(CLK12M),
	.c0(clk_sys),
	.locked(pll_locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
reg ce_21m3 = 0;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div+1'd1;
	ce_10m7 <= !div[1:0];
	ce_5m3  <= !div[2:0];
	ce_21m3 <= div[0];
end

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire        ypbpr;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io(

    .clk_sys(clk_sys),
    .conf_str(CONF_STR),
    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),
    .buttons(buttons),
    .ypbpr(ypbpr),
    
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    .key_code(key_code),
    
    .joystick_0(joy0),
    .joystick_1(joy1),
    .status(status)
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
    .ioctl_dout(ioctl_dout)
);


wire reset = status[0] | (ioctl_download && ioctl_isROM);


wire [3:0] svi_row;
wire [7:0] svi_col;
sviKeyboard KeyboardSVI(
    .clk(clk_sys),
    .reset(reset),

    .key(key_code),
    .strobe(key_strobe),
    .pressed(key_pressed),
    .extended(key_extended),
    
    .svi_row (svi_row),
    .svi_col (svi_col)
);


wire [15:0] cpu_ram_a;
wire        ram_we_n, ram_rd_n, ram_ce_n;
wire  [7:0] ram_di;
wire  [7:0] ram_do;


wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_di;
wire  [7:0] vram_do;

spram #(14) vram(
    .clock(clk_sys),
    .address(vram_a),
    .wren(vram_we),
    .data(vram_do),
    .q(vram_di)
);


wire sdram_rdy;


wire sdram_we,sdram_rd;
wire [17:0] sdram_addr;
wire  [7:0] sdram_din;
wire ioctl_isROM = ioctl_index[5:0] < 6'd2; //Index osd File is 0 (ROM) or 1(Rom Cartridge)


assign sdram_we = (ioctl_wr && ioctl_isROM) | ( isRam & ~(ram_we_n | ram_ce_n));
assign sdram_addr = (ioctl_download && ioctl_isROM) ? {ioctl_index[0],ioctl_addr[15:0]} : ram_a;
assign sdram_din = (ioctl_wr && ioctl_isROM) ? ioctl_dout : ram_do;

assign sdram_rd = ~(ram_rd_n | ram_ce_n);
assign SDRAM_CLK = clk_sys;
sdram sdram(
    .*,
    .init(~pll_locked),
    .clk(clk_sys),

   .wtbt(0),
   .addr(sdram_addr), 
   .rd(sdram_rd),
   .dout(ram_di),
   .din(sdram_din),
   .we(sdram_we), 
   .ready(sdram_rdy)
);


wire [17:0] ram_a;
wire isRam;

wire motor;

svi_mapper RamMapper(
    .addr_i(cpu_ram_a),
    .RegMap_i(ay_port_b),
    .addr_o(ram_a),
    .ram(isRam)
);



wire [10:0] audio;


`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd44_000_000;
i2s i2s(
    .reset(reset),
    .clk(clk_sys),
    .clk_rate(clk_rate),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio, 5'b00000}),
    .right_chan({audio, 5'b00000})
);
`endif


//assign CLK_VIDEO = clk_sys;

wire [7:0] R,G,B,ay_port_b;
wire hblank, vblank;
wire hsync, vsync;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;


wire svi_audio_in = status[15] ? tape_in : (CAS_status != 0 ? CAS_dout : 1'b0);

cv_console console
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.clk_en_5m3_i(ce_5m3),
	.reset_n_i(~reset),

   .svi_row_o(svi_row),
   .svi_col_i(svi_col),	
	
	.svi_tap_i(svi_audio_in),//status[15] ? tape_in : (CAS_status != 0 ? CAS_dout : 1'b0)),

   .motor_o(motor),

	.joy0_i(~{joya[4],joya[0],joya[1],joya[2],joya[3]}), //SVI {Fire,Right, Left, Down, Up} // HPS {Fire,Up, Down, Left, Right}
	.joy1_i(~{joyb[4],joyb[0],joyb[1],joyb[2],joyb[3]}),

	.cpu_ram_a_o(cpu_ram_a),
	.cpu_ram_we_n_o(ram_we_n),
	.cpu_ram_ce_n_o(ram_ce_n),
	.cpu_ram_rd_n_o(ram_rd_n),
	.cpu_ram_d_i(ram_di),
	.cpu_ram_d_o(ram_do),

	.ay_port_b(ay_port_b),
	
	.vram_a_o(vram_a),
	.vram_we_o(vram_we),
	.vram_d_o(vram_do),
	.vram_d_i(vram_di),

	.border_i(status[6]),
	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),

	.audio_o(audio)
);


mist_video #(.COLOR_DEPTH(4),
             .SD_HCNT_WIDTH(11),
             .OUT_COLOR_DEPTH(VGA_BITS),
             .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R[7:2]),
    .G(G[7:2]),
    .B(B[7:2]),
    .HSync(hsync),
    .VSync(vsync),
    .HBlank(hblank),
    .VBlank(vblank),
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

assign VGA_HS = hsync;
assign VGA_VS = vsync;

/*
wire [2:0] scale = status[9:7];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

reg hs_o, vs_o;
always @(posedge CLK_VIDEO) begin
	hs_o <= ~hsync;
	if(~hs_o & ~hsync) vs_o <= ~vsync;
end

video_mixer #(.LINE_LENGTH(290)) video_mixer
(
	.*,

	.ce_pix(ce_5m3),
   .ce_pix_actual(ce_5m3),
   
	.scandoubler_disable(forced_scandoubler),
	.hq2x(scale==1),
	.mono(0),
	.scanlines(forced_scandoubler ? 2'b00 : {scale==3, scale==2}),
   .ypbpr_full(0),
   .line_start(0),


	.R(R[7:2]),
	.G(G[7:2]),
	.B(B[7:2]),

	// Positive pulses.
	.HSync(hs_o),
	.VSync(vs_o),
	.HBlank(hblank),
	.VBlank(vblank)
);

*/


/////////////////  Tape In   /////////////////////////

wire tape_in;
assign tape_in = TAPE_SOUND;


///////////// OSD CAS load //////////

wire CAS_dout;
wire [2:0] CAS_status;
wire play, rewind;
wire CAS_rd;
wire [25:0] CAS_addr;
wire [7:0] CAS_di;

wire [25:0] CAS_ram_addr;
wire CAS_ram_wren, CAS_ram_cs;
wire ioctl_isCAS = (ioctl_index[5:0] == 6'd2);

assign CAS_ram_cs = 1'b1;
assign CAS_ram_addr = (ioctl_download && ioctl_isCAS) ? ioctl_addr[17:0] : CAS_addr;
assign CAS_ram_wren = ioctl_wr && ioctl_isCAS; 

//17 128
//18 256
spram #(14) CAS_ram
(
	.clock(clk_sys),
	.cs(CAS_ram_cs),
	.address(CAS_ram_addr),	
	.wren(CAS_ram_wren), 
	.data(ioctl_dout),
	.q(CAS_di)
);


assign play = ~motor;
assign rewind = status[13] | (ioctl_download && ioctl_isCAS) | reset; //status[13];

cassette CASReader(

  .clk(ce_21m3), //  42.666/2
  .play(play), 
  .rewind(rewind),

  .sdram_addr(CAS_addr),
  .sdram_data(CAS_di),
  .sdram_rd(CAS_rd),

  .data(CAS_dout),
  .status(CAS_status)

);

endmodule