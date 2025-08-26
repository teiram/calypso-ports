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

module ts2068_calypso(
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
    "TS2068;;",
    "F0,ROM,Load ROM;",
    "F1,DCK,Load DCK;",
    "F2,TZX,Load TZX;",
    "S0U,VHD,Mount SD;",
    `SEP
    "O3,Video,PAL,NTSC;",
    "O4,DivMMC,Off,On;",
    "O5,Swap Joysticks,Off,On;",
    "O67,Scanlines,Off,25%,50%,75%;",
    "O8,Tape Input,Line,File;",
    "O9,Tape Audio,On,Off;",
    `SEP
    "T0,Reset;",
    "T1,Remove Cartridge;",
    "T2,NMI;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////

wire pal_clk , pal_pll_locked; //56.000 Mhz
pll_pal pll0(
    .inclk0(CLK12M),
    .c0(pal_clk),
    .locked(pal_pll_locked)
);

wire ntsc_clk, ntsc_pll_locked; // 56.488 MHz
pll_ntsc pll1(
    .inclk0(CLK12M),
    .c0(ntsc_clk),
    .locked(ntsc_pll_locked)
);

wire clk_sys = model ? pal_clk : ntsc_clk;
wire power = pal_pll_locked & ntsc_pll_locked;

reg [3:0] ce;
always @(negedge clk_sys) if (~power) ce <= 1'd0; else ce <= ce + 1'd1;

wire ne28M = ce[0:0] == 1;
wire ne14M = ce[1:0] == 3;
wire ne7M0 = ce[2:0] == 7;
wire pe7M0 = ce[2:0] == 3;
wire ne3M5  = ce[3:0] == 15;
wire pe3M5  = ce[3:0] == 7;

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;
wire [31:0] joy0, joy1;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire [31:0] ioctl_filesize;
wire scandoubler_disable;
wire no_csync;
wire ypbpr;

wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;
wire sd_sdhc;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;
wire [31:0] img_ext;

wire ps2_kbd_clk;
wire ps2_kbd_data;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES('d1),
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

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),

    .sd_sdhc(sd_sdhc),
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


data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),

`ifdef NO_DIRECT_UPLOAD
    .SPI_SS4(1'b1),
`else
    .SPI_SS4(SPI_SS4),
`endif

    .clkref_n(~ne3M5),
    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),
    .ioctl_fileext(img_ext),
    .ioctl_filesize(ioctl_filesize),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

wire sd_spi_cs;
wire sd_spi_ck;
wire sd_spi_mosi;
wire sd_spi_miso;

sd_card sd_card(
    .clk_sys(clk_sys),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_lba(sd_lba),
    .sd_conf(),
    .sd_sdhc(sd_sdhc),
    .sd_ack_conf(),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_din (sd_buff_din),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_wr(sd_buff_wr),
    .img_size(img_size),
    .img_mounted(img_mounted),
    .allow_sdhc(1'b1),

    .sd_cs       (sd_spi_cs),
    .sd_sck      (sd_spi_ck),
    .sd_sdi      (sd_spi_mosi),
    .sd_sdo      (sd_spi_miso)
);

/////////////////  Memory  ////////////////////////
/*
-    64 Kb HOME RAM: $00000 - $FFFF
-      * Video RAM on HOME RAM at $4000
-    ROM at $10000
       * TS2068 ROM at 10000   15FFF    24Kb
            - 10000 - 13FFF . Main ROM  16Kb
            - 14000 - 15FFF . Ext ROM    8Kb
-      * ESXDOS ROM at 16000 - 17FFF     8Kb           128Kb
------------------------------------------------------------
-    DIVMMC RAM: $20000 - $3FFFF        128Kb          128Kb
------------------------------------------------------------
-    DOCK at $40000
*/

wire rom_download = ioctl_index == 'd0 && ioctl_download == 1'b1;
wire dock_download = ioctl_index == 'd1 && ioctl_download == 1'b1;
wire tape_download = ioctl_index == 'd2 && ioctl_download == 1'b1;
// Keep track of the amount of blocks in the current cartridge
reg [2:0] dock_blocks = 'd0;
reg dock_loaded = 1'b0;
reg dck_with_header = 1'b0;
wire dock_wr = dck_with_header ? ioctl_addr > 'd8 && ioctl_wr : ioctl_wr;
wire [15:0] dock_addr = dck_with_header ? ioctl_addr[15:0] - 16'd9 : ioctl_addr[15:0];
wire [22:0] tape_addr = tape_download ? ioctl_addr[22:0] : tape_play_addr;
reg tape_wr;
reg tape_ack;

always @(posedge clk_sys) begin
    reg dock_download_last;
    reg tape_ack_last;
    reg ioctl_wr_last;
    dock_download_last <= dock_download;

    if (dock_download) dock_blocks <= ioctl_addr[15:13];
    
    if (~dock_download_last & dock_download) begin
        dck_with_header = |ioctl_filesize[3:0];
    end
    
    if (dock_download_last & ~dock_download) begin
        dock_loaded <= 1'b1;
        dck_with_header = 1'b0;
    end
    
    else if (status[1] == 1'b1) begin
        dock_loaded <= 1'b0;
        dck_with_header <= 1'b0;
    end
   
    tape_ack_last <= tape_ack;
    ioctl_wr_last <= ioctl_wr;
    if (tape_download) begin
        if (tape_ack_last ^ tape_ack) tape_wr <= 1'b0;
        if (~ioctl_wr_last & ioctl_wr) tape_wr <= 1'b1;
    end
    
end

assign LED[1] = dock_loaded;
assign LED[2] = dck_with_header;

wire [13:0] vid_addr;
wire [7:0] vid_dout;

/* Define BRAM_VRAM to locate VRAM in BRAM.
 * this would  avoid some minor artifacts during TZX loading
 */
`ifdef BRAM_VRAM
vram vram(
    .clock(clk_sys),
    
    .address_a(memA[13:0]),
    .data_a(memD),
    .wren_a(memW && memA[15:14] == 2'b01),
    
    .address_b(vid_addr),
    .q_b(vid_dout)

);
`else
wire [22:0] vram_addr = {7'd0, 2'b01, vid_addr};
wire [15:0] vram_dout;
assign vid_dout = vid_addr[0] ? vram_dout[15:8] : vram_dout[7:0];
`endif

// Memory signals from core
wire [15:0] memA;
wire [7:0] memD;
wire [7:0] memQ;
wire memB;
wire [7:0] memM;
wire memR;
wire memW;

// DivMMC memory management
wire mapped;
wire ramcs;
wire [3:0] page;

wire dock_rd_ena = ~mapped & memM[memA[15:13]] & ~memB;
wire extrom_rd_ena = ~mapped & memM[memA[15:13]] & memB;
wire divmmc_ena = mapped & memA[15:14] == 2'b00;
wire divmmc_ram_ena = divmmc_ena & ramcs;
wire divmmc_rom_ena = divmmc_ena & ~ramcs;

// Needed for immediate DIVMMC mapping switch
reg memr_delayed = 1'b0;
always @(posedge clk_sys) if (pe3M5) memr_delayed <= memR;

wire [22:0] sdram_addr =
    rom_download == 1'b1 ? {5'd0, 2'b01, ioctl_addr[15:0]} :        // ROM ioctl download on  10000
    dock_download == 1'b1 ? {4'd0, 3'b100, dock_addr[15:0]} :       // DOCK ioctl download on 40000
    divmmc_ram_ena ? {5'd0, 1'b1, page, memA[12:0]} :               // DIVMMC RAM access (at 20000)
    divmmc_rom_ena ? {5'd0, 5'b01_011, memA[12:0]} :                // ESXDOS access (at 16000)
    extrom_rd_ena ? {5'd0, 5'b01_010, memA[12:0]} :                 // EXTROM (14000) Only 8KB
    dock_rd_ena ? {4'd0, 3'b100, memA[15:0]}:                       // DOCK (40000)
    memA[15:14] == 2'b00 ? {5'd0, 4'b0100, memA[13:0]}:             // ROM access (10000)
    {5'd0, 2'b00, memA[15:0]};                                      // HOME RAM

wire [7:0] sdram_din = rom_download | dock_download ? ioctl_dout : memD;
assign memQ = (memA[15:13] > dock_blocks || ~dock_loaded) && dock_rd_ena ? 8'hFF : sdram_dout;

wire [7:0] sdram_dout;
wire sdram_rd = memr_delayed;

wire sdram_we = dock_download == 1'b1 ? dock_wr:
    rom_download == 1'b1 ? ioctl_wr:
    memW && ((memA[15:14]) || (mapped && ramcs && memA[13]));

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
    
    .init(~power),
    .clk(clk_sys),
    .clkref(ne3M5),
    
    .bank(2'b00),
    .addr(sdram_addr),
    .oe(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),

`ifndef BRAM_VRAM
    .vram_addr(vram_addr),
    .vram_dout(vram_dout),
`endif

    .tape_addr(tape_addr),
    .tape_din(ioctl_dout),
    .tape_dout(tape_dout),
    .tape_wr(tape_wr),
    .tape_rd(tape_rd),
    .tape_ack(tape_ack)

);

//////////////////////// TZX //////////////////////////////////

wire tape_read;
wire tape_data_req;
reg tape_data_ack;
reg tape_reset;
reg tape_rd;
reg [7:0] tape_dout;
reg [22:0] tape_play_addr;
reg [22:0] tape_last_addr;

always @(posedge clk_sys) begin
    reg old_tape_ack;

    if (~reset_n) begin
        tape_play_addr <= 1;
        tape_last_addr <= 0;
        tape_rd <= 0;
        tape_reset <= 1;
    end else begin
        old_tape_ack <= tape_ack;
        tape_reset <= 0;
        if (tape_download) begin
            tape_play_addr <= 0;
            tape_last_addr <= ioctl_addr[22:0];
            tape_reset <= 1;
        end
        if (~ioctl_download && tape_rd && tape_ack ^ old_tape_ack) begin
            tape_data_ack <= tape_data_req;
            tape_rd <= 0;
            tape_play_addr <= tape_play_addr + 1'd1;
        end else if (~ioctl_download && tape_play_addr <= tape_last_addr && !tape_rd && (tape_data_req ^ tape_data_ack)) begin
            tape_rd <= 1;
        end
    end
end


tzxplayer tzxplayer(
    .clk(clk_sys),
    .ce(1),
    .restart_tape(tape_reset),
    .host_tap_in(tape_dout),
    .tzx_req(tape_data_req),
    .tzx_ack(tape_data_ack),
    .cass_read(tape_read),
    .cass_motor(1'b1)
);

/////////////////  Keyboard  ////////////////////////
wire [4:0] kbd_col;
wire [7:0] kbd_row;
wire [7:0] key_code;
wire key_strobe;
wire play_key;
wire stop_key;
wire f5_key;
wire f9_key;

ps2k ps2k(
    .clock(clk_sys),
    .ps2Ck(ps2_kbd_clk),
    .ps2D(ps2_kbd_data),
    .strb(key_strobe),
    .code(key_code)
);

matrix matrix(
    .clock(clk_sys),
    .strb(key_strobe),
    .code(key_code),
    .row(kbd_row),
    .col(kbd_col),
    .play(play_key),
    .stop(stop_key),
    .F5(f5_key),
    .F9(f9_key)
);

//////////////// Core ///////////////////////////////
wire [14:0] core_audio_left;
wire [14:0] core_audio_right;
wire R, G, B, I;
wire hsync, vsync;
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire model = status[3];
wire divmmc = status[4];

wire reset_n  = power & f9_key & ~rom_download & ~dock_download & ~status[0] & ~status[1];
wire nmi_n  = (f5_key & ~status[2]) | mapped;

wire ear = status[8] ? tape_read : TAPE_SOUND;

ts ts(
    .model(model),
    .divmmc(divmmc),
    
    .clock(clk_sys),
    .ne14M(ne14M),
    .ne7M0(ne7M0),
    .pe7M0(pe7M0),
    .ne3M5(ne3M5),
    .pe3M5(pe3M5),
    .reset(reset_n),
    .nmi(nmi_n),

    .va(vid_addr),
    .vd(vid_dout),

    .memA(memA),
    .memD(memD),
    .memQ(memQ),
    .memR(memR),
    .memW(memW),

    .memB(memB),
    .memM(memM),
    
    .mapped(mapped),
    .ramcs(ramcs),
    .page(page),

    .hsync(hsync),
    .vsync(vsync),
    .r(R),
    .g(G),
    .b(B),
    .i(I),

    .ear(ear),
    .left(core_audio_left),
    .right(core_audio_right),

    .col(kbd_col),
    .row(kbd_row),
    .joy1(joya),
    .joy2(joyb),

    .sdcCs(sd_spi_cs),
    .sdcCk(sd_spi_ck),
    .sdcMosi(sd_spi_mosi),
    .sdcMiso(sd_spi_miso)
);


`ifdef I2S_AUDIO
wire [15:0] audio_left = {1'b0, core_audio_left} + {4'd0, status[9] ? 1'b0 : ear, 11'd0};
wire [15:0] audio_right = {1'b0, core_audio_right} + {4'd0, status[9] ? 1'b0 : ear, 11'd0};
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd56_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio_left),
    .right_chan(audio_right)
);
`endif

mist_video #(
    .COLOR_DEPTH(6),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R({3{R, R & I}}),
    .G({3{G, G & I}}),
    .B({3{B, B & I}}),
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
    .scanlines(status[7:6]),
    .ypbpr(ypbpr)
);


endmodule
