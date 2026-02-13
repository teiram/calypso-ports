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

module space_race_calypso(
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
    "SPACERACE;;",
    `SEP
    "O6,Credits per coin,1,2;",
    "O7B,Playtime Extension,0%,10%,20%,30%,40%,50%,60%,70%,80%,90%,100%;",
    `SEP
    "O3,Swap Joysticks,Off,On;",
    "O45,Scanlines,Off,25%,50%,75%;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

assign LED[7:1] = '0;

/////////////////  CLOCKS  ////////////////////////
wire clk_sys;
wire clk_audio;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),     // System clock - 57.33 MHz
    .c1(clk_audio)    // Audio clock  - 23.45 MHz
);

// Source clock - 14.318 MHz for source of main clock
reg clk_src;
always @(posedge clk_sys) begin
    reg [1:0]  div;
    div <= div + 2'd1;
    clk_src <= div[1];
end

// Reset signal
wire reset = status[0] | buttons[1];

/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joystick_0, joystick_1;

wire scandoubler_disable;
wire no_csync;
wire ypbpr;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_sys),
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

    .joystick_0(joystick_0),
    .joystick_1(joystick_1)
);

// Holding down COIN_SW longer than necessary will corrupt or freeze
// the screen, so limit COIN_SW period to the minimum necessary.
wire coin_sw_raw = joystick_0[4] | joystick_1[4];
reg  coin_sw_raw_q;
wire coin_sw_rise = coin_sw_raw & ~coin_sw_raw_q;
always_ff @(posedge clk_sys) coin_sw_raw_q <= coin_sw_raw;

localparam COIN_SW_CNT   = 600000; // 0.0105 s (shoud be longer than 0.01 s)
localparam COIN_SW_CNT_W = $clog2(COIN_SW_CNT);
reg [COIN_SW_CNT_W-1:0] coin_sw_counter = 0;
reg coin_sw = 1'b0;
always_ff @(posedge clk_sys) begin
    // coin_sw will corrupt the screen while playing,
    // so disable it if there is credit left.
    if (coin_sw_rise && credit_light_n) begin
        coin_sw_counter = 0;
        coin_sw = 1'b1;
    end else if (coin_sw_counter == COIN_SW_CNT - 1) begin
        coin_sw = 1'b0;
    end else begin
        coin_sw_counter = coin_sw_counter + 1'd1;
    end
end

wire start_game = joystick_0[5] | joystick_1[5];
wire [31:0] joya = status[3] ? joystick_1 : joystick_0;
wire [31:0] joyb = status[3] ? joystick_0 : joystick_1;

wire coinage  = status[6];
wire [3:0] playtime = status[11:7];
wire credit_light_n;
wire [15:0] sound;
wire video, score;
wire [3:0]  color = video ? 4'hF : score ? 4'hB: 4'h0;

wire hblank, vblank;
wire hsync, vsync;

space_race_top space_race_top(
    .CLK_DRV(clk_sys),
    .CLK_SRC(clk_src),
    .CLK_AUDIO(clk_audio),
    .RESET(reset),
    .COINAGE(coinage),
    .PLAYTIME(playtime),
    .COIN_SW(coin_sw),
    .START_GAME(start_game),
    .UP1_N(~joya[3]), 
    .DOWN1_N(~joya[2]),
    .UP2_N(~joyb[3]), 
    .DOWN2_N(~joyb[2]),
    .CLK_VIDEO(),
    .VIDEO(video),
    .SCORE(score),
    .HSYNC(hsync),
    .VSYNC(vsync),
    .HBLANK(hblank),
    .VBLANK(vblank),
    .SOUND(sound),
    .CREDIT_LIGHT_N(credit_light_n)
);

assign LED[0] = ~credit_light_n;

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd57_333_333),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(sound),
    .right_chan(sound)
);
`endif


mist_video #(
    .COLOR_DEPTH(4),
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
    .R(color),
    .G(color),
    .B(color),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
