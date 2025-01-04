`timescale 1ns / 1ps
`default_nettype none

module ace_calypso(
   input         CLK12M,
   output  [3:0] VGA_R,
   output  [3:0] VGA_G,
   output  [3:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,	 
   output  [7:0] LED,
   output        AUDIO_L,
   output        AUDIO_R,
   output        UART_TX,//uses for Tape Record
   input         UART_RX,//uses for Tape Play	
   input         SPI_SCK,
   output        SPI_DO,
   input         SPI_DI,
   input         SPI_SS2,
   input         SPI_SS3,
   input         SPI_SS4,
   input         CONF_DATA0
);
	 
`include "build_id.v" 
	 
localparam CONF_STR = {
		  "Jupiter ACE;;",
		  "F,ACE;",
		  "O34,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
		  "O67,CPU Speed,Normal,x2,x4;",
		  "T5,Reset;",
		  "V,v0.5.",`BUILD_DATE
		};

wire			clk_sys;
wire        clk_sdram;
wire 			locked;
wire        scandoubler_disable;
wire        ypbpr;
wire [10:0] ps2_key;

assign LED[0] = buttons[1];
assign LED[1] = status[0];
assign LED[2] = status[5];
assign LED[3] = reset;
assign LED[5] = loader_reset;
assign LED[6] = ioctl_download;

wire [31:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;
wire 			HSync, VSync, HBlank, VBlank;
wire 			blankn = ~(HBlank | VBlank);
wire 			video;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
reg         ioctl_wait = 0;
	
pll pll(
	.inclk0(CLK12M),
	.c0(clk_sys)
	);


mist_io #(.STRLEN(($size(CONF_STR)>>3))) mist_io
(
	.conf_str(CONF_STR),
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.CONF_DATA0(CONF_DATA0),
	.SPI_SS2(SPI_SS2),
	.SPI_DO(SPI_DO),
	.SPI_DI(SPI_DI),
	.buttons(buttons),
	.switches(switches),
	.scandoublerD(scandoubler_disable),
	.ypbpr(ypbpr),
	.status(status),
	.ps2_key(ps2_key),
    .ioctl_ce(1'b1),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout)
);

wire [5:0] vgar;
wire [5:0] vgag;
wire [5:0] vgab;

assign VGA_R = vgar[5:2];
assign VGA_G = vgag[5:2];
assign VGA_B = vgab[5:2];

video_mixer #(.LINE_LENGTH(280), .HALF_DEPTH(1)) video_mixer
(
	.clk_sys(clk_sys),
	.ce_pix(ce_pix),
	.ce_pix_actual(ce_pix),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),
	.scanlines(scandoubler_disable ? 2'b00 : {status[4:3] == 3, status[4:3] == 2}),
	.scandoublerD(scandoubler_disable),
	.hq2x(status[4:3]==1),
	.ypbpr(ypbpr),
	.ypbpr_full(1),
	.R(blankn ? {video,video,video} : "000"),
	.G(blankn ? {video,video,video} : "000"),
	.B(blankn ? {video,video,video} : "000"),
	.mono(0),
	.HSync(~HSync),
	.VSync(~VSync),
	.line_start(0),
	.VGA_R(vgar),
	.VGA_G(vgag),
	.VGA_B(vgab),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS)
);

wire [1:0] turbo = status[7:6];

reg ce_pix;
reg ce_cpu;
always @(negedge clk_sys) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div[1:0];
	ce_cpu <= (!div[2:0] && !turbo) | (!div[1:0] && turbo[0]) | turbo[1];
end
wire reset = buttons[1] || status[0] || status[5];
wire spk, mic;

jupiter_ace jupiter_ace(
	.clk(clk_sys),
	.ce_cpu(ce_cpu),
	.ce_pix(ce_pix),
	.no_wait(|turbo),
	.reset(reset|loader_reset),
	.kbd_row(kbd_row),
	.kbd_col(kbd_col),
	.video_out(video),
	.hsync(HSync),
	.vsync(VSync),
	.hblank(HBlank),
	.vblank(VBlank),
	.mic(mic),
	.spk(spk),
	.loader_en(ioctl_download),
	.loader_addr(ioctl_addr[15:0] + 16'h2000),
	.loader_data(ioctl_dout),
	.loader_wr(ioctl_wr),
    .led_cpu_reset(LED[4])
);

sigma_delta_dac sigma_delta_dac
(	
	.DACout(AUDIO_L),
	.DACin({1'b0, spk, mic, 13'd0}),
	.CLK(clk_sys),
	.RESET(reset)
);

assign AUDIO_R = AUDIO_L;
wire [7:0] kbd_row;
wire [4:0] kbd_col;

keyboard keyboard(
	.reset(reset),
	.clk_sys(clk_sys),
	.ps2_key(ps2_key),
	.kbd_row(kbd_row),
	.kbd_col(kbd_col)
);

reg loader_reset = 0;

always @(posedge clk_sys) begin
	reg       old_download;
    old_download <= ioctl_download;
    if (~old_download & ioctl_download) loader_reset <= 1;
    if (old_download & ~ioctl_download) loader_reset <= 0;
end


endmodule
