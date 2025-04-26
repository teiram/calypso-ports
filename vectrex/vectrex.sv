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
//============================================================================
`default_nettype none

module vectrex_calypso(
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
    output        SDRAM_CKE
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

assign LED[0] = ~ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
    "vectrex;BINVECROM;",
    "O1,CPU,MC6809,CPU09;",
    "O2,Show Frame,Yes,No;",
    "O3,Skip Logo,Yes,No;",
    "O4,Joystick swap,Off,On;",
    "O5,Second port,Joystick,Speech;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_24 /* synthesis keep */;
wire clk_12 /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_24),
    .c1(clk_12),
    .locked(pll_locked)
);


/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;
wire [15:0] joy_ana_0, joy_ana_1;

wire        ioctl_download /* synthesis keep */;
wire  [7:0] ioctl_index /* synthesis keep */;
wire        ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire  [7:0] ioctl_dout /* synthesis keep */;
wire        scandoubler_disable;
wire ypbpr;


wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(0),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_24),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(),
    .buttons(buttons),

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

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
    .clk_sys(clk_24),
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


/////////////////  Memory  ////////////////////////
wire [14:0] cart_addr /* synthesis keep */;
wire  [7:0] cart_do /* synthesis keep */;
wire [15:0] sdram_dout /* synthesis keep */;
wire cart_rd /* synthesis keep */;
assign cart_do = sdram_dout[7:0];

assign SDRAM_CLK = clk_24;
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
    .clk(clk_24),

    .wtbt(0),
    .addr(ioctl_download ? ioctl_addr : cart_addr),
    .rd(~ioctl_download & cart_rd),
    .dout(sdram_dout),
    .din({ioctl_dout, ioctl_dout}),
    .we(ioctl_download & ioctl_wr)
);



////////////////  Console  ////////////////////////

reg reset = 0;
reg second_reset = 0;

always @(posedge clk_24) begin
    integer timeout = 0;
    reg [15:0] reset_counter = 0;
    reg reset_start;

    reset <= 0;
    reset_start <= status[0] | buttons[1] | ioctl_download | second_reset;
    if (reset_counter) begin
        reset <= 1'b1;
        reset_counter <= reset_counter - 1'd1;
    end
    if (reset_start) reset_counter <= 16'd1000;

    second_reset <= 0;
    if (timeout) begin
        timeout <= timeout - 1;
        if(timeout == 1) second_reset <= 1'b1;
    end
    if(ioctl_download && !status[3]) timeout <= 5000000;
end

wire [7:0] pot_x_1, pot_x_2;
wire [7:0] pot_y_1, pot_y_2;
wire [9:0] audio;
wire hblank, vblank;
wire hsync, vsync;
wire frame_line;
wire [3:0] RR, GG, BB;
wire [3:0] R, G, B;
wire blankn = ~(hblank | vblank);

assign pot_x_1 = status[4] ? joy_ana_1[15:8] : joy_ana_0[15:8];
assign pot_x_2 = status[4] ? joy_ana_0[15:8] : joy_ana_1[15:8];
assign pot_y_1 = status[4] ? ~joy_ana_1[ 7:0] : ~joy_ana_0[ 7:0];
assign pot_y_2 = status[4] ? ~joy_ana_0[ 7:0] : ~joy_ana_1[ 7:0];


assign R = status[2] & frame_line ? 4'h4 : blankn ? RR : 4'd0;
assign G = status[2] & frame_line ? 4'h0 : blankn ? GG : 4'd0;
assign B = status[2] & frame_line ? 4'h0 : blankn ? BB : 4'd0;

wire [31:0] joya = status[4] ? joy1 : joy0;
wire [31:0] joyb = status[4] ? joy0 : joy1;

vectrex vectrex(
    .clock_24(clk_24),
    .clock_12(clk_12),
    .reset(reset),
    .cpu(status[1]),
    .video_r(RR),
    .video_g(GG),
    .video_b(BB),
    .video_hblank(hblank),
    .video_vblank(vblank),
    .speech_mode(status[5]),
    .video_hs(hsync),
    .video_vs(vsync),
    .frame(frame_line),
    .audio_out(audio),
    .cart_addr(cart_addr),
    .cart_do(cart_do),
    .cart_rd(cart_rd),
    .btn11(joya[4]),
    .btn12(joya[5]),
    .btn13(joya[6]),
    .btn14(joya[7]),
    .pot_x_1(pot_x_1),
    .pot_y_1(pot_y_1),
    .btn21(joyb[4]),
    .btn22(joyb[5]),
    .btn23(joyb[6]),
    .btn24(joyb[7]),
    .pot_x_2(pot_x_2),
    .pot_y_2(pot_y_2),
    .leds(),
    .dbg_cpu_addr()
);


`ifdef I2S_AUDIO
i2s i2s(
    .reset(1'b0),
    .clk(clk_24),
    .clk_rate(32'd24_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[9], audio[8:0], 6'd0}),
    .right_chan({~audio[9], audio[8:0], 6'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(4),
    .SD_HCNT_WIDTH(13),
    .OSD_COLOR(3'b010),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_24),
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
    .ce_divider(3'd1),
    .scandoubler_disable(1'b1),
    .no_csync(1'b0),
    .scanlines(),
    .ypbpr(ypbpr)
);

endmodule
