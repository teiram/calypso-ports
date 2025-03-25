module calypso_top(       
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
wire TAPE_SOUND = AUDIO_IN;
`else
wire TAPE_SOUND = UART_RX;
`endif

wire        ioctl_download;
wire [7:0]  ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0]  ioctl_dout;
wire forced_scandoubler;
wire [31:0] joy0, joy1;
wire  [1:0] buttons;
wire [31:0] status;
wire [24:0] ps2_mouse;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire azerty,dcmoto;

assign azerty = status[6] & !status[5];
assign dcmoto = !status[5] & !status[6];

`include "build_id.v" 
localparam CONF_STR = {
	"MO;;",
	"-;",
	"F,WAV,Load tape;",
	"O56,Keyboard,DCMOTO,QWERTY,AZERTY;",
	"O7,OVO,Off,On;",
	"O8,Model,MO6,MO5;",
	"O9,Fast,Off,On;",
	"TA,Rewind Tape;",
	"-;",
	"R0,Reset;",
	"V,calypso",`BUILD_DATE 
};

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))

user_io(

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
    .SPI_SS4(SPI_SS4),
    .SPI_DI(SPI_DI),
    .clkref_n(1'b0),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

wire clk_sys;
wire pll_locked;
pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);

wire reset = status[0] | !pll_locked;

assign SDRAM_CLK = clk_sys;
wire sdram_ready;

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
    .we(sdram_we),
    .din(sdram_din),
    .dout(ram_di),
    
    .ready(sdram_ready)
);


`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd32_000_000;
wire [15:0] audio_left;
wire [15:0] audio_right;

i2s i2s(
    .reset(reset),
    .clk(clk_sys),
    .clk_rate(clk_rate),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio_left}),
    .right_chan({audio_right})
);
`endif

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;
wire cpu_rfsh_n;
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

mo_core mo_core(
	.sysclk(clk_sys),
	.reset(reset),

	.mo5(status[8]),
	.azerty(azerty),
    .dcmoto(dcmoto),
	.rewind(status[10]),
	.fast(status[9]),
	.ovo_ena(status[7]),
	.capslock(LED[7]),
 
//	.clk_video(CLK_VIDEO),
//	.ce_pixel(CE_PIXEL),
	.vga_r(R),
	.vga_g(G),
	.vga_b(B),
	.vga_hs(hsync),
	.vga_vs(vsync),
//	.vga_de(VGA_DE),
	
	.audio_l(audio_left),
	.audio_r(audio_right),
	
	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.joystick_0(joya),
	.joystick_1(joyb),
	
	.ddram_clk(DDRAM_CLK),
	.ddram_busy(DDRAM_BUSY),
	.ddram_burstcnt(DDRAM_BURSTCNT),
	.ddram_addr(DDRAM_ADDR),
	.ddram_dout(DDRAM_DOUT),
	.ddram_dout_ready(DDRAM_DOUT_READY),
	.ddram_rd(DDRAM_RD),
	.ddram_din(DDRAM_DIN),
	.ddram_be(DDRAM_BE),
	.ddram_we(DDRAM_WE),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout)
);

wire [1:0] scanlines = status[9:7];

mist_video #(.COLOR_DEPTH(8),
             .SD_HCNT_WIDTH(11),
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
    .HSync(hsync),
    .VSync(vsync),
    .HBlank(hblank),
    .VBlank(vblank),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .scanlines(scanlines),
    .ce_divider(1'b0),

    .scandoubler_disable(1'b0),
    .ypbpr(ypbpr),
    .rotate(2'b00),
    .blend(1'b0)
);

wire tape_in;
assign tape_in = TAPE_SOUND;

endmodule
