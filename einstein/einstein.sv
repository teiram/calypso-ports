//============================================================================
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

module einstein_calypso(
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

wire [2:0] scanlines = status[5:3];

`include "build_id.v" 
localparam CONF_STR = {
    "EINSTEIN;;",
    "S0U,DSK,Mount Disk 0:;",
    "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "O1,Swap Joysticks,No,Yes;",
    "O2,Joystick,Digital,Analog;",
    "O6,Diagnostic ROM mounted,Off,On;",
    "O7,Border,Off,On;",
    "T0,Reset;",
    "V,calypso-",`BUILD_DATE 
};

wire clk_sys;
wire clk_vdp;
wire clk_vid;
wire locked;

pll pll(
    .inclk0(CLK12M),
    .areset(1'b0),
    .locked(locked),
    .c0(clk_sys), // 32   Mhz
    .c1(clk_vdp), // 10.7 Mhz
    .c2(clk_vid) //  42   Mhz
);

wire reset = status[0] | buttons[1] | ioctl_download | !locked;

reg [2:0] clk_div;
wire clk_cpu = clk_div[2]; // 4M
wire clk_fdc = clk_div == 3'b111;
always @(posedge clk_sys) clk_div <= clk_div + 3'd1;

wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire  [1:0] buttons;
wire [31:0] status;
wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire img_mounted;
wire [31:0] img_size;
wire img_readonly;

wire [31:0] joy0, joy1;
wire [15:0] ajoy0, ajoy1;

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
    .FEATURES(32'h8 | (BIG_OSD << 13) | (HDMI << 14)))
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

    .sd_sdhc(1'b1),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joy0),
    .joystick_1(joy1)
);

//////////////////////////////////////////////////////////////////
wire [7:0] kb_row;
wire [7:0] kb_col;
wire shift, ctrl, graph;
wire press_btn;

keyboard keyboard(
    .clk_sys(clk_sys),
    .reset(reset),
    .ps2_key(ps2_key),
    .addr(kb_row),
    .kb_cols(kb_col),
    .modif({ctrl, graph, shift}),
    .press_btn(press_btn)
);


wire ce_pix = pxcnt[2];
reg [2:0] pxcnt;

always @(posedge clk_vid)
    pxcnt <= pxcnt + 3'd1;

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

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire [31:0] img_ext;

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
    .ioctl_fileext(img_ext),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);


wire [22:0] sdram_addr /* synthesis keep */;
wire [7:0] sdram_din /* synthesis keep */;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */;
wire sdram_we /* synthesis keep */;
wire sdram_ready /* synthesis keep */;

wire [15:0] cpu_sdram_addr;
wire [7:0] cpu_sdram_din;
wire [7:0] cpu_sdram_dout;
wire cpu_ram_rd;
wire cpu_ram_wr;
wire cpu_roma_rd;
wire cpu_romb_rd;

always @(*) begin
    casex({ioctl_download, cpu_ram_rd | cpu_ram_wr, cpu_roma_rd, cpu_romb_rd})
        'b1xxx:  sdram_addr = {7'd0, ioctl_addr[14:0]};         //ioctl (roms).   @ 00000 - 07FFF - 32Kb
        'b0100:  sdram_addr = {7'd1, cpu_sdram_addr[15:0]};     //RAM   (64Kb).   @ 10000 - 1FFFF - 64Kb
        'b0010:  sdram_addr = {8'd0, cpu_sdram_addr[13:0]};     //ROM   (16Kb).   @ 00000 - 03FFF - 16Kb
        'b0001:  sdram_addr = {8'd1, cpu_sdram_addr[13:0]};     //DIAG  (16Kb).   @ 04000 - 07FFF - 16Kb                     //cart.           @ 100000 - 1FFFFF - 1Mb
        default: sdram_addr = {7'd1, cpu_sdram_addr[15:0]};
    endcase
end

assign sdram_rd = cpu_ram_rd | cpu_roma_rd | cpu_romb_rd;
assign sdram_we = ioctl_wr | cpu_ram_wr; 
assign sdram_din = ioctl_wr ? ioctl_dout :
    cpu_ram_wr ? cpu_sdram_din : 8'h00;
assign cpu_sdram_dout = sdram_rd ? sdram_dout : 8'hff;

assign SDRAM_CLK = clk_sys;
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
    
    .init(~locked),
    .clk(clk_sys),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);


wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;
wire [9:0] sound;
wire [31:0] joya = status[2] ? joy1 : joy0;
wire [31:0] joyb = status[2] ? joy0 : joy1;

tatung tatung(
    .clk_sys(clk_sys),
    .clk_vdp(clk_vdp),
    .clk_cpu(clk_cpu),
    .clk_fdc(clk_fdc),
    .reset(reset),

    .vga_red(R),
    .vga_green(G),
    .vga_blue(B),
    .vga_hblank(hblank),
    .vga_vblank(vblank),
    .vga_hsync(hsync),
    .vga_vsync(vsync),
    
    .sound(sound),
    
    .kb_row(kb_row),
    .kb_col(kb_col),
    .kb_shift(shift),
    .kb_ctrl(ctrl),
    .kb_graph(graph),
    .kb_down(press_btn),

    .img_mounted(img_mounted),
    .img_readonly(img_readonly),
    .img_size(img_size),

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(|sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .joystick_0(joya),
    .joystick_1(joyb),
//    .joystick_analog_0(joystick_analog_0),
//    .joystick_analog_1(joystick_analog_1),

    .diagnostic(status[6]),
    .border(status[7]),
    .analog(status[2]),
    
    .sdram_addr(cpu_sdram_addr),
    .sdram_din(cpu_sdram_din),
    .sdram_dout(cpu_sdram_dout),
    .ram_rd(cpu_ram_rd),
    .ram_wr(cpu_ram_wr),
    .roma_rd(cpu_roma_rd),
    .romb_rd(cpu_romb_rd)
);


`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd32_000_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({sound, 6'b0}),
	.right_chan({sound, 6'b0})
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
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(reset),
	.clk_rate_i(32'd42_660_000),
	.spdif_o(SPDIF),
	.sample_i({DAC_R, DAC_L})
);
`endif

`ifdef USE_HDMI
i2c_master #(100_000_000) i2c_master (
	.CLK         (clk_100),
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

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(9), .USE_BLANKS(1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video(
	.clk_sys        ( clk_vid          ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( R                ),
	.G              ( G                ),
	.B              ( B                ),
	.HBlank         ( hblank           ),
	.VBlank         ( vblank           ),
	.HSync          ( hsync            ),
	.VSync          ( vsync            ),
	.VGA_R          ( HDMI_R           ),
	.VGA_G          ( HDMI_G           ),
	.VGA_B          ( HDMI_B           ),
	.VGA_VS         ( HDMI_VS          ),
	.VGA_HS         ( HDMI_HS          ),
	.VGA_DE         ( HDMI_DE          ),
	.ce_divider     ( 3'd7             ),
	.scandoubler_disable( 1'b1         ),
	.scanlines      ( ),
	.ypbpr          ( 1'b0             ),
	.no_csync       ( 1'b1             )
	);

assign HDMI_PCLK = clk_25;

`endif

mist_video #(
    .COLOR_DEPTH(4),
    .SD_HCNT_WIDTH(9),
    .USE_BLANKS(1'b1),
    .OSD_COLOR(3'b001),
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
	.ce_divider(1'b0),
	.scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),    
    .rotate(2'b00),
	.scanlines(scanlines),
	.ypbpr(ypbpr)
);

endmodule
