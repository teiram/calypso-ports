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

module trs80m3_calypso(
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
parameter CONF_STR = {
    "TRS80M3;;",
    "S0U,DSK,Disk 0:;",
    `SEP
    "O45,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O3,Enable Floppy,No,Yes;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clock_master_s; // 20Mhz
wire clk_sdram;      // 80Mhz
wire clk_sys = clock_master_s;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clock_master_s),
    .c1(clk_sdram),
    .locked(pll_locked)
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

wire [31:0] sd_lba;
reg sd_rd;
reg sd_wr;
wire sd_ack;
wire sd_ack_conf;
wire sd_conf;
wire sd_sdhc;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;
wire [31:0] img_ext;

wire ps2_kbd_clk;
wire ps2_kbd_data;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)),
    .PS2DIV(400)
) user_io(
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

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    
    .sd_sdhc(sd_sdhc),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_conf(sd_conf),
    .sd_ack_conf(sd_ack_conf),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

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
    .ioctl_fileext(img_ext),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

wire sdcard_cs;
wire sdcard_sclk;
wire sdcard_mosi;
wire sdcard_miso;

sd_card sd_card(
    .clk_sys(clk_sys),

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),
    .sd_conf(sd_conf),
    .sd_sdhc(sd_sdhc),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .sd_buff_dout(sd_buff_dout),
    .sd_buff_wr(sd_buff_wr),
    .sd_buff_din(sd_buff_din),
    .sd_buff_addr(sd_buff_addr),
    .allow_sdhc(1),

    .sd_cs(sdcard_cs),
    .sd_sck(sdcard_sclk),
    .sd_sdi(sdcard_mosi),
    .sd_sdo(sdcard_miso)
);

wire reset /* synthesis keep */= status[0] | buttons[1] | ioctl_download | ~pll_locked;
wire reset_por_s = ~pll_locked;


/////////////////  Memory  ////////////////////////
wire [22:0] sdram_addr = {7'd0, ram_addr_s};
wire [7:0] sdram_din = ram_data_to_s;
wire [7:0] sdram_dout;
wire sdram_rd = ram_rd_s;
wire sdram_we = ram_wr_s;
wire sdram_ready;

assign ram_data_from_s = sdram_dout;

assign SDRAM_CLK = clk_sdram;
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
    .clk(clk_sdram),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);


////////////////  Core  ////////////////////////
wire hsync, vsync;
wire video_bit_s;

wire [15:0] ram_addr_s;
wire ram_rd_s;
wire ram_wr_s;
wire [7:0] ram_data_to_s;
wire [7:0] ram_data_from_s;
wire [13:0] rom_addr_s;
wire [7:0] rom_data_from_s;

wire [7:0] kb_columns_s;
wire [7:0] kb_rows_s;

wire [1:0] sound_s;
wire cas500_s = TAPE_SOUND;
wire cas1500_s = TAPE_SOUND;

trs80 trs80(
 
    .clock_i(clock_master_s),
    .por_i(reset_por_s),
    .reset_i(reset),

    //Options
    .opt_floppy_i(status[3]),

    //RAM
    .ram_addr_o(ram_addr_s),
    .ram_data_to_o(ram_data_to_s),
    .ram_data_from_i(ram_data_from_s),
    .ram_rd_o(ram_rd_s),
    .ram_wr_o(ram_wr_s),

    //ROM
    .rom_addr_o(rom_addr_s),
    .rom_data_from_i(rom_data_from_s),
    .rom_rd_o(),

    //Video
    .video_bit_o(video_bit_s),
    .video_hs_n_o(hsync),
    .video_vs_n_o(vsync),

    //Audio
    .sound_o(sound_s),

    //Cassette
    .cas500_i(cas500_s),
    .cas1500_i(cas1500_s),

    //Keyboard
    .kb_rows_o(kb_rows_s),
    .kb_columns_i(kb_columns_s),

    //Extension
    .bus_a_o(),
    .bus_d_io(),
    .bus_in_n_o(),
    .bus_out_n_o(),
    .bus_reset_n_o(),
    .bus_int_n_i(1'b1),
    .bus_wait_n_i(1'b1),
    .bus_extiosel_n_i(1'b1),
    .bus_m1_n_o(),
    .bus_iorq_n_o(),
    .bus_enextio_n_o(),

    // SD Card
    .image_num_i(1'b0),
    .sd_cs_n_o(sdcard_cs),
    .sd_miso_i(sdcard_miso),
    .sd_mosi_o(sdcard_mosi),
    .sd_sclk_o(sdcard_sclk),
    
    // Debug
    .D_cpu_a_o(),
    .D_track_num_o(),
    .D_track_ram_addr_o(),
    .D_track_ram_we_o(),
    .D_error_o()
);

rom rom(
    .clk(clock_master_s),
    .addr(rom_addr_s),
    .data(rom_data_from_s)
);

keyboard #(
    .clkfreq(20000)
) keyboard(
    .clock_i(clock_master_s),
    .por_i(reset_por_s),
    .reset_i(reset),
    .ps2_clk_i(ps2_kbd_clk),
    .ps2_data_i(ps2_kbd_data),
    .rows_i(kb_rows_s),
    .cols_o(kb_columns_s)
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clock_master_s),
    .clk_rate(32'd20_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({1'b0, sound_s, TAPE_SOUND, 12'd0}),
    .right_chan({1'b0, sound_s, TAPE_SOUND, 12'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clock_master_s),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(video_bit_s),
    .G(video_bit_s),
    .B(video_bit_s),
    .HBlank(),
    .VBlank(),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_VS(VGA_VS),
    .VGA_B(VGA_B),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd1),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
