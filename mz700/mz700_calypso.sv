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

module mz700_calypso(
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
parameter CONF_STR = {
    "MZ700;;",
    "S0U,DSK,Load Floppy 1;",
    `SEP
    "O45,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O3,Swap Joysticks,No,Yes;",
    "OC,Mode,Computer,Console;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire clk_sys /* synthesis keep */;
wire clk_mem;
wire clk_vga;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys), // 21.50Mhz
    .c1(clk_mem), // 86.00Mhz
    .locked(pll_locked)
);

vgapll vgapll(
    .inclk0(CLK12M),
    .c0(clk_vga) //25 Mhz
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
wire [31:0] sd_lba_mux;
reg sd_rd /* synthesis keep */;
reg sd_wr;
wire sd_ack /* synthesis keep */;
wire sd_ack_mux;
wire sd_ack_conf;
wire [8:0] sd_buff_addr /* synthesis keep */;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;
wire sd_sdhc;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;

wire [31:0] img_ext;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;
wire ps2_kbd_clk;
wire ps2_kbd_data;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
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

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .ps2_kbd_clk(ps2_kbd_clk),
    .ps2_kbd_data(ps2_kbd_data),
    
    .sd_sdhc(sd_sdhc),
    .sd_lba(sd_lba_mux),
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

wire sdclk;
wire sdmosi;
wire sdss;
wire sdmiso;

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

/////////////////  RESET  /////////////////////////
wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;

////////////////  Machine  ////////////////////////
wire [5:0] laudio;
wire [5:0] raudio;

wire [5:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

mz700 mz700(
    .pClk21m(clk_sys),      // in std_logic;      - VDP clock ... 21.48MHz
    .pClk25m(clk_vga),      // in std_logic;      - VGA clock ... 25 Mhz
    .pClk84m(clk_mem),      // in std_logic;      - Mem clock ... 85.92Mhz (VDP clock x 4)
    .pExtClk(),             // in std_logic;      - Reserved (for multi FPGAs)
    .pCpuClk(),             // out std_logic;     - CPU clock ... 3.58MHz (up to 10.74MHz/21.48MHz)
    
    .pSltClk(),             // in std_logic;      - pCpuClk returns here, for Z80, etc.
    .pSltRst_n(~reset),     // in std_logic;      - pCpuRst_n returns here
    .pSltSltsl_n(),         // inout std_logic;
    .pSltSlts2_n(),         // inout std_logic;
    .pSltIorq_n(),          // inout std_logic;
    .pSltRd_n(),            // inout std_logic;
    .pSltWr_n(),            // inout std_logic;
    .pSltAdr(),             // inout std_logic_vector(15 downto 0);
    .pSltDat(),             // inout std_logic_vector(7 downto 0);
    .pSltBdir_n(),          // out std_logic;      - Bus direction (not used in master mode)
    .pSltCs1_n(),           // inout std_logic;
    .pSltCs2_n(),           // inout std_logic;
    .pSltCs12_n(),          // inout std_logic;
    .pSltRfsh_n(),          // inout std_logic;
    .pSltWait_n(),          // inout std_logic;
    .pSltInt_n(),           // inout std_logic;
    .pSltM1_n(),            // inout std_logic;
    .pSltMerq_n(),          // inout std_logic;

    .pSltRsv5(),            // out std_logic;      - Reserved
    .pSltRsv16(),           // out std_logic;      - Reserved (w/ external pull-up)
    .pSltSw1(),             // inout std_logic;    - Reserved (w/ external pull-up)
    .pSltSw2(),             // inout std_logic;    - Reserved
    
    .pMemClk(SDRAM_CLK),    // out std_logic;      - SD-RAM Clock
    .pMemCke(SDRAM_CKE),    // out std_logic;      - SD-RAM Clock enable
    .pMemCs_n(SDRAM_nCS),   // out std_logic;      - SD-RAM Chip select
    .pMemRas_n(SDRAM_nRAS), // out std_logic;      - SD-RAM Row/RAS
    .pMemCas_n(SDRAM_nCAS), // out std_logic;      - SD-RAM /CAS
    .pMemWe_n(SDRAM_nWE),   // out std_logic;      - SD-RAM /WE
    .pMemUdq(SDRAM_DQMH),   // out std_logic;      - SD-RAM UDQM
    .pMemLdq(SDRAM_DQML),   // out std_logic;      - SD-RAM LDQM
    .pMemBa1(SDRAM_BA[0]),  // out std_logic;      - SD-RAM Bank select address 1
    .pMemBa0(SDRAM_BA[1]),  // out std_logic;      - SD-RAM Bank select address 0
    .pMemAdr(SDRAM_A),      // out std_logic_vector(12 downto 0);    -- SD-RAM Address
    .pMemDat(SDRAM_DQ),     // inout std_logic_vector(15 downto 0);  -- SD-RAM Data
    
    .pPs2Clk(ps2_kbd_clk),        // inout std_logic;
    .pPs2Dat(ps2_kbd_data),        // inout std_logic;
    
    .pJoyA(),          // inout std_logic_vector( 5 downto 0);
    .pStrA(),          // out std_logic;
    .pJoyB(),          // inout std_logic_vector( 5 downto 0);
    .pStrB(),          // out std_logic;

    // pSd_Ck,       --MMCCK
    // pSd_Dt(3),    --MMCCS
    // pSd_Dt(0),    --MMCDI
    // pSd_Cm,       --MMCDO
    .pSd_Ck(sdclk),                        // out std_logic - pin 5
    .pSd_Cm(sdmosi),                       // out std_logic - pin 2
    .pSd_Dt({sdss, 2'd0, sdmiso}),         // inout std_logic_vector( 3 downto 0) - pin 1(D3), 9(D2), 8(D1), 7(D0)
    
    .pDip(8'b00100000),           // in std_logic_vector( 7 downto 0) - 0=ON,  1=OFF(default on shipment)
    .pLed(LED),       // out std_logic_vector( 7 downto 0)- 0=OFF, 1=ON(green)
    .pLedPwr(),        // out std_logic                    - 0=OFF, 1=ON(red) ...Power & SD/MMC access lamp

    .pDac_VR(R),       // inout std_logic_vector( 5 downto 0);  - RGB_Red / Svideo_C
    .pDac_VG(G),       // inout std_logic_vector( 5 downto 0);  - RGB_Grn / Svideo_Y
    .pDac_VB(B),       // inout std_logic_vector( 5 downto 0);  - RGB_Blu / CompositeVideo
    .pDac_SL(laudio),  // out   std_logic_vector( 5 downto 0);  - Sound-L
    .pDac_SR(raudio),  // inout std_logic_vector( 5 downto 0);  - Sound-R / CMT

    .pVideoHS_n(hsync), // out std_logic;                       - Csync(RGB15K), HSync(VGA31K)
    .pVideoVS_n(vsync), // out std_logic;                       - Audio(RGB15K), VSync(VGA31K)

    .pVideoClk(),       // out std_logic;                        - (Reserved)
    .pVideoDat(),       // out std_logic;                        - (Reserved)

    // Reserved ports (USB)
    .pUsbP1(),          // inout std_logic;
    .pUsbN1(),          // inout std_logic;
    .pUsbP2(),          // inout std_logic;
    .pUsbN2(),          // inout std_logic;

    // Reserved ports
    .pIopRsv14(),       // out std_logic;
    .pIopRsv15(),       // out std_logic;
    .pIopRsv16(),       // out std_logic;
    .pIopRsv17(),       // out std_logic;
    .pIopRsv18(),       // out std_logic;
    .pIopRsv19(),       // out std_logic;
    .pIopRsv20(),       // out std_logic;
    .pIopRsv21()        // out std_logic
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({laudio, 10'd0}),
    .right_chan({raudio, 10'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(6),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_vga),
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
    .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
