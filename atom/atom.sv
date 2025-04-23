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

module atom_calypso(
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
    input SPI_SS2,    // data_io
    input SPI_SS3,    // OSD
    input CONF_DATA0, // SPI_SS for user_io

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
    "atom;;",
    "F1,COLBINROM,Load CART;",
    `SEP
    "S0U,VHD,Load VHD;",
    `SEP
    "O3,Swap Joysticks,No,Yes;",
    `SEP
    "O45,Audio,Atom,SID,TAPE,off;",
    "O67,Keyboard,UK,US,orig,game;",
    "O8,character set,original,xtra;",
    "O9,Background,Black,Dark;",
    "OA,Mode,Atom,BBC;",
    "OBC,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", 
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_main = clk_sys;
wire clk_sys = clk_32;
wire clk_16;
wire clk_32;
wire clk_42;
wire pll_locked;


pll pll(
    .inclk0(CLK12M),
    .c0(clk_42),
    .c1(clk_32),
    .c2(clk_16),
    .locked(pll_locked)
);

reg clk_14M318_ena ;
reg [1:0] count;

always @(posedge clk_42)
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


/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;

wire        ioctl_download /* synthesis keep */;
wire  [7:0] ioctl_index /* synthesis keep */;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        scandoubler_disable;

wire [31:0] sd_lba;
reg sd_rd /* synthesis keep */;
reg sd_wr;
wire sd_ack /* synthesis keep */;
wire sd_ack_conf;
wire sd_buff_addr /* synthesis keep */;
wire sd_buff_dout;
wire sd_buff_din;
wire sd_buff_wr;
wire sd_sdhc;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;

wire ypbpr;
wire [31:0] img_ext;

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;


wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1),
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
    .no_csync(),
    .buttons(buttons),

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .sd_sdhc(sd_sdhc),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
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

/////////////////  RESET  /////////////////////////
wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;

/////////////////  Memory  ////////////////////////
wire [22:0] sdram_addr /* synthesis keep */;
wire [7:0] sdram_din /* synthesis keep */;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */;
wire sdram_we /* synthesis keep */;
wire sdram_ready /* synthesis keep */;


assign SDRAM_CLK = clk_42;
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
    .clk(clk_42),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);


////////////////  Console  ////////////////////////
wire [15:0] audio;

wire [1:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

////////////////////////////////////////////
// CORE

wire charset = status[8];

wire tape_out;
wire pixel_clock;

wire sdclk;
wire sdss;
wire sdmosi;
wire sdmiso;

wire rom_cs;
wire mem_we;
wire [7:0] mem_dout;
wire [7:0] mem_din;
wire [17:0] mem_addr;

AtomFpga_Core AcornAtom(
    // clocks
    .clk_vid(clk_42),
    .clk_vid_en(clk_14M318_ena),
    .clk_main(clk_main),
    .clk_dac(clk_sys),  // -2.202 setup slack
    //.clk_avr(clk_16), // -4.98 setup slack -- this is to fix SD Card problem
    .clk_avr(clk_main), // this helps timing
    
    .pixel_clock(pixel_clock),
    
    // Keyboard
    .ps2_key(ps2_key),
    .layout(status[7:6]),
    .BLACK_BACKGND(~status[9]),
    .computer(status[10]),

    // Mouse
    //.ps2_mouse_clk(mse_clk),	//  : inout std_logic;
    //.ps2_mouse_data(mse_clk),	// : inout std_logic;

    //resets
    //.powerup_reset_n(~RESET),
    .ext_reset_n(~reset),
    //.int_reset_n(),

    // VGA
    .red(R),
    .green(G),
    .blue(B),
    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank),
    
    // External 6502 bus interface
    //.phi2(),
    //.sync(),
    //.rnw(),
    //.blk_b(),
    //.addr(),
    //.rdy(1'b1),
    //.so(1'b1),
    //.irq_n(1'b1),
    //.nmi_n(1'b1),
    
    // External Bus/Ram/Rom interface
    //	.ExternBus(),
    //	.ExternCE(),
    .ExternROM(rom_cs),
    .ExternWE(mem_we),
    .ExternDout(mem_dout),
    .ExternDin(mem_din),
    .ExternA(mem_addr),


    // Audio
    .atom_audio(a_audio),
    .sid_audio(),
    .sid_audio_d(sid_audio),

    // SD Card
    .SDCLK(sdclk),
    .SDSS(sdss),
    .SDMOSI(sdmosi),
    .SDMISO(sdmiso),

    //Serial
    //.uart_TxD(),
    //.uart_RxD(1'B0),

    // Cassette
    .cas_in(TAPE_SOUND),
    .cas_out(tape_out),

    // Misc
    .LED1(LED[1]),
    .LED2(LED[2]),
    .charset(charset),
    .Joystick1(~joya),
    .Joystick2(~joyb),

    // USB Uart on FPGA Module
    .avr_TxD(),
    .avr_RxD(1'b0)

);


////////////////////////////////////////////////


sd_card sd_card(
    .clk_sys(clk_sys),
    .img_mounted(img_mounted),
    .img_size(img_size),
    .sd_lba(sd_lba),
    .sd_wr(sd_wr),
    .sd_rd(sd_rd),
    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),
    .sd_sdhc(sd_sdhc),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_wr(sd_buff_wr),

    .allow_sdhc(1'b0),

    .sd_sck(sdclk),
    .sd_cs(sdss),
    .sd_sdi(sdmosi),
    .sd_sdo(sdmiso)
);

////////////////////////////////////////////

wire [17:0] sid_audio;
wire a_audio;

assign audio = status[5:4] == 2'b00 ? {{16{a_audio}}} : status[5:4] == 2'b01 ? sid_audio[17:2] : status[5:4] == 2'b10 ? {{16{tape_out}}} : 16'b0 ;


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio),
    .right_chan(audio)
);
`endif

mist_video #(
    .COLOR_DEPTH(2),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_42),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R),
    .G(G),
    .B(B),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync( vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
//  .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(1'b1),
    .scanlines(status[12:11]),
    .ypbpr(ypbpr)
);


endmodule
