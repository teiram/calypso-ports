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

module pc88_calypso(
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

wire mist_active = |sd_rd[2:0] || |sd_wr[2:0];

assign LED[0] = ~ioctl_download; 
assign LED[6] = disk_led;
assign LED[5] = mist_active;
assign LED[7] = reset;

`include "build_id.v" 
parameter CONF_STR = {
    "PC8801;;",
    "O78,Mode,N88V2,N88V1H,N88V1S,N;",
    "O9,Speed,4MHz,8MHz;",
    `SEP
    "S0U,D88,Mount FDD0;",
    "S1U,D88,Mount FDD1;",
    "TF,Sync FDD0;",
    "TG,Sync FDD1;",
    `SEP
    "OA,Basic mode,Basic,Terminal;",
    "OB,Cols,80,40;",
    "OC,Lines,25,20;",
    "OD,Disk boot,Enable,Disable;",
    `SEP
    "OK,Input,Joypad,Mouse;",
    "OL,Sound Board 2,Expansion,Onboard;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////
wire clk_ram /* synthesis keep */, clk_sys /* synthesis keep */, clk_emu /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_ram),
    .c1(clk_sys),
    .c2(clk_emu),
    .locked(pll_locked)
);

assign SDRAM_CLK = clk_ram;

/////////////////  IO  ///////////////////////////
wire [63:0] status;
wire  [1:0] buttons;

wire [15:0] joystick_0, joystick_1;

wire [5:0] joyA = ~{joystick_0[5:4],joystick_0[0],joystick_0[1],joystick_0[2],joystick_0[3]};
wire [5:0] joyB = ~{joystick_1[5:4],joystick_1[0],joystick_1[1],joystick_1[2],joystick_1[3]};

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;

wire ps2_kbd_clk_out;
wire ps2_kbd_data_out;
wire ps2_kbd_clk_in;
wire ps2_kbd_data_in;
wire ps2_mouse_clk_out;
wire ps2_mouse_data_out;
wire ps2_mouse_clk_in;
wire ps2_mouse_data_in;

wire [31:0] sd_lba;
wire [3:0] sd_rd;
wire [3:0] sd_wr;

wire [3:0] sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;
wire [3:0] img_mounted;
wire [3:0] img_readonly;
wire [63:0] img_size;

wire mouse_strobe;
wire [8:0] mouse_y;
wire [8:0] mouse_x;
wire [7:0] mouse_flags;
wire [24:0] ps2_mouse = {mouse_strobe, mouse_y, mouse_x, mouse_flags[5:0]};

wire key_strobe;
wire key_pressed;
wire key_extended;
wire [7:0] key_code;

wire scandoubler_disable;
wire no_csync;
wire ypbpr;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(4),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)),
    .PS2DIV(600),
    .PS2BIDIR(1'b1)
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

    .ps2_kbd_clk(ps2_kbd_clk_out),
    .ps2_kbd_data(ps2_kbd_data_out),
    .ps2_kbd_clk_i(ps2_kbd_clk_in),
    .ps2_kbd_data_i(ps2_kbd_data_in),

    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    .key_code(key_code),
    
    .mouse_strobe(mouse_strobe),
    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_flags(mouse_flags),
    
    .sd_sdhc(1),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack_x(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1)
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

// Reset key
reg kbd_reset /* synthesis keep */;
always @(posedge clk_sys) begin
    if (key_strobe) begin
        if (!key_extended) begin
            case(key_code)
                8'h78: kbd_reset <= key_pressed; // F11
            endcase
        end
    end
end
wire reset /* synthesis keep */ = buttons[1] | status[0] | kbd_reset;

wire [1:0] basicmode = ~status[8:7];
wire clkmode = status[9];
wire cBT = ~status[10];
wire c40C = status[11];
wire c20L = status[12];
wire cDisk = status[13];
wire MTSAVE = 1;
wire [1:0] FDsync = status[16:15];
wire cInDev = status[20];
wire cSB2 = status[21];

wire disk_led;

wire [7:0] red, green, blue;
wire HSync, VSync, ce_pix, vid_de;
wire hblank, vblank;
wire [15:0] audio_left;
wire [15:0] audio_right;

PC88MiST #(
    .RAMAWIDTH(22),
    .RAMCAWIDTH(8)
) PC88(
    .clksys(clk_sys),
    .rclk(clk_ram),
    .emuclk(clk_emu),
    .plllocked(pll_locked),
    .rstn(~reset),

    .sysrtc(),

    .LOADER_ADR(ioctl_addr[18:0]),
    .LOADER_WDAT(ioctl_dout),
    .LOADER_OE(ioctl_download & ~ldr_done),
    .LOADER_WR(ldr_wr),
    .LOADER_ACK(ldr_ack),
    .LOADER_DONE(ldr_done),

    .pMemCke(SDRAM_CKE),
    .pMemCs_n(SDRAM_nCS),
    .pMemRas_n(SDRAM_nRAS),
    .pMemCas_n(SDRAM_nCAS),
    .pMemWe_n(SDRAM_nWE),
    .pMemUdq(SDRAM_DQMH),
    .pMemLdq(SDRAM_DQML),
    .pMemBa1(SDRAM_BA[1]),
    .pMemBa0(SDRAM_BA[0]),
    .pMemAdr(SDRAM_A),
    .pMemDat(SDRAM_DQ),

    .pPs2Clkin(ps2_kbd_clk_out),
    .pPs2Clkout(ps2_kbd_clk_in),
    .pPs2Datin(ps2_kbd_data_out),
    .pPs2Datout(ps2_kbd_data_in),

    .ps2_mouse(ps2_mouse),

    .pJoyA(joyA),
    .pJoyB(joyB),

    .mist_mounted(img_mounted),
    .mist_readonly(img_readonly),
    .mist_imgsize(img_size),

    .mist_lba(sd_lba),
    .mist_rd(sd_rd),
    .mist_wr(sd_wr),
    .mist_ack({sd_ack[3:2], |sd_ack[1:0], |sd_ack[1:0]}),

    .mist_buffaddr(sd_buff_addr),
    .mist_buffdout(sd_buff_dout),
    .mist_buffdin(sd_buff_din),
    .mist_buffwr(sd_buff_wr),

    .pFd_sync(FDsync),

    .pLed(disk_led),
    .pDip({clkmode, 2'b0, cDisk, c20L, c40C, MTSAVE, cBT, basicmode}),
    .pCoreConfig({cSB2,cInDev}),
    .pPsw(2'b11),

    .pVideoR(red),
    .pVideoG(green),
    .pVideoB(blue),
    .pVideoHS(HSync),
    .pVideoVS(VSync),
    .pVideoEN(vid_de),
    .pVideoClk(ce_pix),
    .pVideoHBlank(hblank),
    .pVideoVBlank(vblank),

    .pSndL(audio_left),
    .pSndR(audio_right),

    .tape(TAPE_SOUND)
    
);


wire ldr_ack;
reg ldr_wr = 0;
reg ldr_done = 0;
always @(posedge clk_sys) begin
    reg old_ack, old_download;

    old_download <= ioctl_download;
    old_ack <= ldr_ack;

    if (~old_ack & ldr_ack & ldr_wr) ldr_wr <= 0;
    if (ioctl_wr & ~ldr_done) ldr_wr <= 1;

    if (old_download & ~ioctl_download) ldr_done <= 1;
end


`ifdef I2S_AUDIO

i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd20_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio_left),
    .right_chan(audio_right)
);
`endif

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b101),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_ram),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(red),
    .G(green),
    .B(blue),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(HSync),
    .VSync(VSync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd1),
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .scanlines(),
    .ypbpr(ypbpr)
);


endmodule
