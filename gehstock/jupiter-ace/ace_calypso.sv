`timescale 1ns / 1ps
`default_nettype none

module ace_calypso(
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
    output SDRAM_CKE

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


`include "build_id.v"

localparam CONF_STR = {
    "JUPITER;;",
    "FpACE,ACE;",
    "O34,Scanlines,None,25%,50%,75%;",
    "O67,CPU Speed,Normal,x2,x4;",
    "T5,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

assign LED[0] = ~ioctl_download;

/////////////////// CLOCKS ////////////////////////////
wire clk_sys;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys)
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

//////////////////// MIST IO ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;
wire scandoubler_disable;
wire ypbpr;
wire no_csync;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;
wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

wire [7:0] ioctl_index;
wire ioctl_download;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
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
    .key_extended(key_extended)
);


data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),

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

wire reset = buttons[1] || status[0] || status[5];


wire spk, mic;
wire hblank, vblank, hsync, vsync, video;

jupiter_ace jupiter_ace(
    .clk(clk_sys),
    .ce_cpu(ce_cpu),
    .ce_pix(ce_pix),
    .no_wait(|turbo),
    .reset(reset|loader_reset),
    .kbd_row(kbd_row),
    .kbd_col(kbd_col),
    .video_out(video),
    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank),
    .mic(mic),
    .spk(spk),
    .loader_en(ioctl_download),
    .loader_addr(ioctl_addr[15:0] + 16'h2000),
    .loader_data(ioctl_dout),
    .loader_wr(ioctl_wr)
);


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
    reg old_download;
    
    old_download <= ioctl_download;
    if (~old_download & ioctl_download) loader_reset <= 1;
    if (old_download & ~ioctl_download) loader_reset <= 0;
end


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({1'b0, spk, mic, 13'd0}),
    .right_chan({1'b0, spk, mic, 13'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(11),
    .USE_BLANKS(1'b1),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(video),
    .G(video),
    .B(video),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd1),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[4:3]),
    .ypbpr(ypbpr)
);


endmodule
