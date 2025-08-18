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

module galaxian_calypso(
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

assign LED[0] = ~ioctl_download; 

`include "build_id.v" 

`define NAME "GALAXIAN"
wire [6:0] core_mod;
reg rotate_dir;

always @(*) begin
    if (core_mod == 7'd1  || // "MOONCR"
        core_mod == 7'd6  || // "DEVILFSH"
        core_mod == 7'd9  || // "OMEGA"
        core_mod == 7'd10 || // "ORBITRON"
        core_mod == 7'd13)   // "VICTORY"
    begin
        rotate_dir = 1'b0;
    end else begin
        rotate_dir = 1'b1;
    end
end

localparam CONF_STR = {
    `NAME,";;",
    "O1,Rotate,Off,On;",
    "O23,Scanlines,Off,25%,50%,75%;",
    "O4,Blend,Off,On;",
    "O5,Swap Joysticks,No,Yes;",
    "DIP;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire       rotate    = status[1];
wire [1:0] scanlines = status[3:2];
wire       blend     = status[4];
wire       joy_swap  = status[5];

/////////////////  CLOCKS  ////////////////////////

wire clk_12, clk_6, clk_96;
wire pll_locked;
pll pll(
    .inclk0(CLK12M),
    .locked(pll_locked),
    .c0(clk_96),
    .c1(clk_12),
    .c2(clk_6)
);

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;
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
    .clk_sys(clk_12),
    
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

    .joystick_0(joy0),
    .joystick_1(joy1)
);


data_io data_io(
    .clk_sys(clk_12),
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

wire  [7:0] audio_a, audio_b, audio_c;
wire [10:0] audio = {1'b0, audio_b, 2'b0} + {3'b0, audio_a} + {2'b00, audio_c, 1'b0};
wire        hsync, vsync;
wire        hblank, vblank;
wire        blankn = ~(hblank | vblank);
wire  [2:0] R,G,B;
wire [31:0] joya = joy_swap ? joy1 : joy0;
wire [31:0] joyb = joy_swap ? joy0 : joy1;

galaxian galaxian
(
    .W_CLK_12M(clk_12),
    .W_CLK_6M(clk_6),
    .I_RESET(status[0] | buttons[1]),
    .I_HWSEL(core_mod),

    .I_DL_ADDR(ioctl_addr[15:0]),
    .I_DL_WR(ioctl_wr),
    .I_DL_DATA(ioctl_dout),

    .I_TABLE(status[5]),
    .I_TEST(status[6]),
    .I_SERVICE(status[7]),
    .I_SW1_67(status[15:14]),
    .I_DIP(status[23:16]),
    .P1_CSJUDLR({m_coin1,m_one_player,m_fireA,m_up,m_down,m_left,m_right}),
    .P2_CSJUDLR({m_coin2,m_two_players,m_fire2A,m_up2,m_down2,m_left2,m_right2}),

    .W_R(R),
    .W_G(G),
    .W_B(B),
    .W_H_SYNC(hsync),
    .W_V_SYNC(vsync),
    .HBLANK(hblank),
    .VBLANK(vblank),

    .W_SDAT_A(audio_a),
    .W_SDAT_B(audio_b),
    .W_SDAT_C(audio_c)

);


wire m_up, m_down, m_left, m_right, m_fireA, m_fireB, m_fireC, m_fireD, m_fireE, m_fireF;
wire m_up2, m_down2, m_left2, m_right2, m_fire2A, m_fire2B, m_fire2C, m_fire2D, m_fire2E, m_fire2F;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs inputs(
    .clk         ( clk_12      ),
    .key_strobe  ( key_strobe  ),
    .key_pressed ( key_pressed ),
    .key_code    ( key_code    ),
    .joystick_0  ( joya  ),
    .joystick_1  ( joyb  ),
    .rotate      ( ~rotate      ),
    .orientation ( {rotate_dir, 1'b1 }),
    .joyswap     ( 1'b0        ),
    .oneplayer   ( 1'b1        ),
    .controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
    .player1     ( {m_fireF, m_fireE, m_fireD, m_fireC, m_fireB, m_fireA, m_up, m_down, m_left, m_right} ),
    .player2     ( {m_fire2F, m_fire2E, m_fire2D, m_fire2C, m_fire2B, m_fire2A, m_up2, m_down2, m_left2, m_right2} )
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_12),
    .clk_rate(32'd12_060_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[10], audio[9:0], 5'd0}),
    .right_chan({~audio[10], audio[9:0], 5'd0})
);
`endif

assign SDRAM_CKE = 1'b1;
assign SDRAM_CLK = clk_96;

mist_dual_video #(
    .COLOR_DEPTH(3),
    .SD_HCNT_WIDTH(11),
    .USE_BLANKS(1'b1),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_96),
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
    .ce_divider(4'd15),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(scanlines),
    .ypbpr(ypbpr),
    
    .rotate({rotate_dir, rotate}),
    .rotate_screen({~rotate_dir, ~rotate}),
    
    .rotate_hfilter(1'b1),
    .rotate_vfilter(1'b1),
    
    .clk_sdram(clk_96),
    .sdram_init(~pll_locked),
    
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS)
);


endmodule
