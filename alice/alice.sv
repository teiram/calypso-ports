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

module alice_calypso(
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
    inout  [15:0] SDRAM_DQ,
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
wire TAPE_SOUND=1'b0;
`endif

assign LED[0] = ~ioctl_download; 

`include "build_id.v"
parameter CONF_STR = {
    "Alice;;",
    "OC,16k expansion,Off,On;",
    "O3,Swap Joysticks,No,Yes;",
    "-;",
    "OF,Tape Input,File,Ear;",
    "F1,C10,Load Tape;",
    "TA,Play/Pause Tape;",
    "TB,Rewind Tape;",
    "OD,Show tape stream,Off,On;",
    "OE,Enable tape audio,Off,On;",
    "-;",
    "O12,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
    "-;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire pll_locked;
wire clk_sys;   //50     Mhz
wire clk_4;     // 4     MHz
wire clk_video; //37.5   Mhz

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .c1(clk_4),
    .locked(pll_locked)
);


pll_video pll_video(
    .inclk0(CLK12M),
    .c0(clk_video)
);

reg clk_14M318_ena;
reg [1:0] count;

always @(posedge clk_video)
begin
    if (reset)
        count <= 0;
    else
    begin
        clk_14M318_ena <= 0;
        if (count == 'd2)
        begin
            clk_14M318_ena <= 1;
            count <= 0;
        end
        else
        begin
            count <= count + 2'd1;
        end
    end
end

wire reset = status[0] | buttons[1] | ~pll_locked;

/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;
wire rs1 = joy0[4] | joy0[1];
wire rs2 = joy0[4] | joy0[0];

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index /* synthesis keep */;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire [31:0] img_ext;


wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(2'b00),
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

/////////////////  Memory  ////////////////////////

wire sdram_ready;
wire [24:0] cas_addr;
wire cas_rd;
wire [7:0] cas_din;

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
    
    .init(~pll_locked),
    .clk(clk_sys),

    .wtbt(0),
    .addr(ioctl_wr ? ioctl_addr : cas_addr),
    .rd(cas_rd),
    .dout(cas_din),
    .din(ioctl_dout),
    .we(ioctl_wr)
);


////////////////  Console  ////////////////////////
wire alice_audio;
wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync /* synthesis keep */, vsync /* synthesis keep */;
wire ce_pix /* synthesis keep */;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire k7_dout;
wire [2:0] tape_status;

wire [15:0] exp_addr;
wire [7:0] exp_ram_dout;
wire [7:0] exp_dout;
wire exp_rw;
wire exp_sel = status[12] && (exp_addr[15:12]  > 4 && exp_addr[15:12] < 9);
wire [7:0] joy_dout;
wire exp_e /* synthesis keep */;
wire audio_in = status[15] ? ~TAPE_SOUND : (tape_status != 0 ? ~k7_dout : 1'b1);

mc10 mc10(
    .reset(reset),
    .clk_sys(clk_sys),
    .clk_4(clk_4),
    .clk_video(clk_video),
    .ce_video(clk_14M318_ena),

    .ps2_key(ps2_key),

    .exp_din((exp_sel ? exp_ram_dout : 8'd0) | joy_dout),
    .exp_sel(exp_sel),
    .exp_nmi(),
    .exp_dout(exp_dout),
    .exp_rw(exp_rw),
    .exp_addr(exp_addr),
    .exp_reset(),
    .exp_e(exp_e),

    .rs232_a(~rs1),
    .rs232_b(~rs2),

    .red(R),
    .green(G),
    .blue(B),

    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank),
    .ce_pix(ce_pix),

    .audio(alice_audio),

    .cin(audio_in)
);


cassette cassette(
    .clk(clk_4),
    .play(status[10]),
    .rewind(status[11]),

    .sdram_addr(cas_addr),
    .sdram_data(cas_din),
    .sdram_rd(cas_rd),

    .data(k7_dout),
    .status(tape_status)
);

// Tape status overlay
reg [7:0] overlay_out;
overlay ov(
    .clk_vid(clk_video),
    .din(status[15] ? { TAPE_SOUND, 7'd0 } : cas_din),
    .sample(status[15] ? TAPE_SOUND : cas_rd),
    .vsync(vsync),
    .hsync(hsync),
    .status(status[15] ? {TAPE_SOUND, 3'd3} : {k7_dout, tape_status}),
    .color(overlay_out),
    .en(status[13])
);

joysticks joysticks(
    .joy1(joy0),
    .joy2(joy1),
    .addr(exp_addr),
    .dout(joy_dout)
);

spram exp_ram(
    .clock(clk_sys),
    .address(exp_addr[14:0]),
    .data(exp_dout),
    .wren(~exp_rw & exp_sel),
    .q(exp_ram_dout)
);


`ifdef I2S_AUDIO
wire [15:0] audio = {alice_audio, 4'd0, status[14] ? audio_in : 1'b0, 10'd0};
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd50_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio),
    .right_chan(audio)
);
`endif

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b100),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_video),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R | overlay_out),
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
    .ce_divider(3'd2),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[2:1]),
    .ypbpr(ypbpr)
);

endmodule
