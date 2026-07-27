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

module jr100_calypso(
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
localparam CONF_STR = {
    "JR100;;",
    "F0,rom,Load BASIC ROM;",
    "F1,prg,Load PRG;",
    "F2,bas,Load BAS;",
    `SEP
    "S0,prg,Mount Save File;",
    "T3,Save BASIC to file;",
    `SEP
    "S1,cmt,Mount Tape;",
    "T4,Tape Play;",
    `SEP
    "O68,Display color,White,Green,Amber,Cyan,Orange,Blue,Paper,Mint;",
    "O9A,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O2,Extended RAM (reset),Off,On;",
    "O5,Autostart loaded program,No,Yes;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


// OSD momentary status bits -> one-clk pulses
reg  save_req, tape_play;
always @(posedge clk_sys) begin
    reg old_save, old_play;
    old_save <= status[3];
    save_req <= ~old_save & status[3];
    old_play <= status[4];
    tape_play <= ~old_play & status[4];
end

/////////////////  CLOCKS  ////////////////////////
// 57.272727 MHz = 4x NTSC colorburst: /8 = 7.159 MHz pixel,
wire clk_sys;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

reg [31:0] sd_lba;
wire [1:0] sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
reg [7:0] sd_buff_din;
wire sd_buff_wr;

wire [1:0] img_mounted;
wire [63:0] img_size;

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

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(2),
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

    .sd_sdhc(1),
    .sd_lba(sd_lba),
    .sd_rd({tape_rd, 1'b0}),
    .sd_wr({tape_wr, prsave_wr}),
    .sd_ack_x(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),
    
    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .joystick_0(joy0),
    .joystick_1(joy1)
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

/////////////////  RESET  /////////////////////////
wire reset =  status[0] | buttons[1] | ~pll_locked;

///////////////////////   CORE   /////////////////////////////////

// boot.rom (games/JR100/) and the OSD "F0" slot both arrive as
// ioctl index 0: an 8 KiB image, char ROM first (AGENTS.md §7).
wire rom_download = ioctl_download && (ioctl_index[5:0] == 0);
wire loader_we = ioctl_wr && rom_download && (ioctl_addr[24:13] == 0);

wire prg_download = ioctl_download && (ioctl_index[5:0] == 1);
wire prg_wait;

wire bas_download = ioctl_download && (ioctl_index[5:0] == 2);
wire bas_wait;

// MiSTer joystick -> JR-100 CC02 (AGENTS.md §4): bit0=right, bit1=left,
// bit2=up, bit3=down, bit4=fire, all active high, idle = 00.
wire [7:0] joy_status = {3'b000,
                         joy0[4],   // fire
                         joy0[2],   // down
                         joy0[3],   // up
                         joy0[1],   // left
                         joy0[0]};  // right

wire [44:0] key_matrix;
jr100_keyboard keyboard
(
    .clk(clk_sys),
    .rst(reset),
    .ps2_key(ps2_key),
    .key_matrix(key_matrix)
);

wire pb7, audio;
wire vid_pixel, hsync, vsync;

wire [31:0] tape_lba;
wire tape_rd;
wire tape_wr;
wire [7:0] tape_buff_din;

wire [31:0] prsave_lba;
wire [7:0] prsave_buff_din;
wire prsave_wr;

always @(posedge clk_sys) begin
    if (tape_rd == 1'b1 || tape_wr == 1'b1) begin
        sd_lba <= tape_lba;
        sd_buff_din <= tape_buff_din;
    end
    if (prsave_wr == 1'b1) begin
        sd_lba <= prsave_lba;
        sd_buff_din <= prsave_buff_din;
    end
end

jr100_top core(
    .clk         (clk_sys),
    .rst         (reset),
    .downloading (rom_download),
    .cpu_hold    (1'b0),

    .loader_we   (loader_we),
    .loader_addr (ioctl_addr[12:0]),
    .loader_data (ioctl_dout),

    .prg_download (prg_download),
    .prg_wr       (ioctl_wr && prg_download),
    .prg_data     (ioctl_dout),
    .prg_wait     (prg_wait),

    .bas_download (bas_download),
    .bas_wr       (ioctl_wr && bas_download),
    .bas_data     (ioctl_dout),
    .bas_wait     (bas_wait),

    .save_req     (save_req),
    .img_mounted  (img_mounted[0]),
    .img_readonly (1'b0),
    .img_size     (img_size),
    .sd_lba       (prsave_lba),
    .sd_wr        (prsave_wr),
    .sd_ack       (sd_ack[0]),
    .sd_buff_addr (sd_buff_addr),
    .sd_buff_din  (prsave_buff_din),

    .tape_play    (tape_play),
    .tape_mounted (img_mounted[1]),
    .tape_readonly (1'b0),
    .tape_size    (img_size),
    .tape_playing (),
    .tape_recording (),
    .sd1_lba      (tape_lba),
    .sd1_rd       (tape_rd),
    .sd1_wr       (tape_wr),
    .sd1_ack      (sd_ack[1]),
    .sd1_buff_din (tape_buff_din),
    .sd_buff_dout (sd_buff_dout),
    .sd_buff_wr   (sd_buff_wr),

    .autostart_en (status[5]),

    .key_matrix  (key_matrix),
    .joy_status  (joy_status),
    .ext_ram_en  (status[2]),

    .pb7         (pb7),
    .audio       (audio),

    .vid_pixel   (vid_pixel),
    .vid_de      (),
    .vid_hs      (hsync),
    .vid_vs      (vsync),
    .vid_hcnt    (),
    .vid_vcnt    (),

    .cen_pix_out (),
    .cen_cpu_out (),
    .boundary    (),
    .dbg_pc      (),
    .dbg_sp      (),
    .dbg_ix      (),
    .dbg_a       (),
    .dbg_b       (),
    .dbg_cc      (),
    .dbg_ora     (),
    .dbg_orb     (),
    .dbg_ddra    (),
    .dbg_ddrb    (),
    .dbg_acr     (),
    .dbg_pcr     (),
    .dbg_ifr     (),
    .dbg_ier     (),
    .dbg_sr      (),
    .dbg_t1      (),
    .dbg_t1l     (),
    .dbg_t2      (),
    .dbg_t2l     ()
);

///////////////////////   VIDEO / AUDIO   ////////////////////////
wire [7:0] R, G, B;


// Display colour (OSD): classic monochrome-monitor phosphors. The
// JR-100's optional dedicated monitor (TR-120MIC) was a green display.
reg [23:0] fg_color;
always @(*) begin
    case (status[8:6])
        3'd0: fg_color = 24'hFFFFFF;   // White
        3'd1: fg_color = 24'h33FF33;   // Green (P1)
        3'd2: fg_color = 24'hFFB000;   // Amber (P3)
        3'd3: fg_color = 24'h66FFFF;   // Cyan
        3'd4: fg_color = 24'hFF8020;   // Orange
        3'd5: fg_color = 24'h99BBFF;   // Blue
        3'd6: fg_color = 24'hFFE8C8;   // Paper
        default: fg_color = 24'hCCFFCC; // Mint
    endcase
end

assign R = vid_pixel ? fg_color[23:16] : 8'h00;
assign G = vid_pixel ? fg_color[15:8]  : 8'h00;
assign B = vid_pixel ? fg_color[7:0]   : 8'h00;

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd57_272_727),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({1'b0, audio, 14'd0}),
    .right_chan({1'b0, audio, 14'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
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
    .HBlank(),
    .VBlank(),
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
    .scanlines(status[10:9]),
    .ypbpr(ypbpr)
);


endmodule
