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

module imsai8080_calypso(
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
    output SDRAM_CKE,

    inout [3:0] PSRAM_SIO,
    output PSRAM_CE,
    output PSRAM_CLK

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
    "IMSAI8080;;",
    `SEP
    "F0,ROM,Load Panel;",
    `SEP
    "F1,ROM,Load ROM;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk36m;
wire clk72m /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk36m),
    .c1(clk72m),
    .locked(pll_locked)
);

reg [2:0] ce_counter;
wire mem_clkref /* synthesis keep */ = ce_counter == 3'b000;
always @(posedge clk72m) begin
    if (reset) ce_counter <= 3'd0;
    
    ce_counter <= ce_counter + 3'd1;
end

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index;
wire ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire [7:0] ioctl_dout /* synthesis keep */;

wire no_csync;
wire ypbpr;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk36m),
    .clk_sd(clk36m),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),
    
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
    .clk_sys(clk36m),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .clkref_n(~mem_clkref),
    
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
wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked;

/////////////////  Memory  ////////////////////////
wire rom_download = ioctl_download && ioctl_index == 8'd1;
wire panel_download = ioctl_download && ioctl_index == 8'd0;

assign SDRAM_CLK = clk72m;
assign SDRAM_CKE = 1'b1;
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
    
    .init_n(pll_locked),
    .clk(clk72m),
    .clkref(~mem_clkref),
    
    .port1_req(ioctl_wr),
    .port1_ack(),
    .port1_a(ioctl_addr[22:1]),
    .port1_ds({ioctl_addr[0], ~ioctl_addr[0]}),
    .port1_we(ioctl_wr & panel_download),
    .port1_d({ioctl_dout, ioctl_dout}),
    .port1_q(),

    .cpu1_addr(vid_ram_addr[16:2]),
    .cpu1_q(ram_value),
    .cpu1_oe(~panel_download)
);



wire [22:0] psram_addr = rom_download == 1'b1 ? ioctl_addr[22:0] : {7'd0, extram_addr[15:0]};
wire psram_rd = rom_download == 1'b1 ? 1'b0 : extram_rd;
wire psram_we = rom_download == 1'b1 ? ioctl_wr : extram_we;
wire psram_ready;
wire [7:0] psram_din = rom_download == 1'b1 ? ioctl_dout : extram_din;
wire [7:0] psram_dout;
assign extram_dout = psram_dout;

assign PSRAM_CLK = clk72m;

psram64 psram(
    .PSRAM_SIO(PSRAM_SIO),
    .PSRAM_CE(PSRAM_CE),
    
    .init(~pll_locked),
    .clk(clk72m),

    .addr(psram_addr),
    .rd(psram_rd),
    .we(psram_we),
    .din(psram_din),
    .dout(psram_dout),
    
    .ready(psram_ready)
);

wire [13:0] audio;

wire [3:0] R /* synthesis keep */,G /* synthesis keep */,B /* synthesis keep */;
wire hblank, vblank;
wire hsync, vsync;
wire [10:0] col /* synthesis keep */;
wire [9:0] row /* synthesis keep */;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire [16:2] vid_ram_addr;
wire [31:0] ram_value;

////////////////////////////////////////////
// CORE

vga vga(
    .clk36m(clk36m),
    .reset(reset),
    
    .col(col),
    .row(row),
    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank)
);

wire [3:0] r_panel;
wire [3:0] g_panel;
wire [3:0] b_panel;
wire [15:0] panel_switches;
wire [9:0] panel_m_switches;

wire [7:0] port_leds;
wire [15:0] addr_leds;
wire [7:0] data_leds;
wire [7:0] cpu_leds;
wire [3:0] status_leds;

panel panel(
    .clk36m(clk36m),
    .reset(reset),
    .col(col),
    .row(row),
    .hblank(hblank),
    .vblank(vblank),
    .ram_addr(vid_ram_addr),
    .ram_value(ram_value),
    
    .leds({port_leds, cpu_leds, data_leds, addr_leds, status_leds}),
    .switches(panel_switches),
    .m_switches(panel_m_switches),
    
    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe),
    .key_extended(key_extended),

    .r(r_panel),
    .g(g_panel),
    .b(b_panel)
);

wire pixel_terminal;

terminal terminal(
    .clk36m(clk36m),
    .reset(reset),
    .col(col),
    .row(row - 11'd240),
    .hblank(hblank),
    .vblank(vblank),
    
    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe),
    .key_extended(key_extended),
    
    .vout(pixel_terminal)
);

wire cpu_sync;

wire [15:0] extram_addr;
wire [7:0] extram_din;
wire [7:0] extram_dout;
wire extram_rd;
wire extram_we;

imsai8080 core(
    .clk(clk36m),
    .pauseModeSW(),
    .reset(reset),
    
    .rx(),
    .hold_in(1'b0),
    .ready_in(1'b1),
    .tx(),
    
    .cpu_sync(cpu_sync),
    
    .mem_rd(cpu_leds[7]),
    .io_rd(cpu_leds[6]),
    .m1(cpu_leds[5]),
    .io_wr(cpu_leds[4]),
    .halt_ack(cpu_leds[3]),
    .io_stack(cpu_leds[2]),
    .mem_wr_n(cpu_leds[1]),
    .interrupt_ack(cpu_leds[0]),

    .inte_o(status_leds[3]),
    .wait_o(status_leds[1]),
    .hlda_o(status_leds[0]),
    
    .data_leds(data_leds),
    .addr_leds(addr_leds),
    .programmed_output_leds(port_leds),
    
    .data_addr_in(panel_switches[7:0]),
    .addr_sense_in(panel_switches[15:8]),
    
    .step_switch(panel_m_switches[8] | panel_m_switches[9]),
    .examine_switch(panel_m_switches[1]),
    .examine_next_switch(panel_m_switches[0]),
    .deposit_switch(panel_m_switches[3]),
    .deposit_next_switch(panel_m_switches[2]),
    .reset_switch(panel_m_switches[5]),
    .clear_switch(panel_m_switches[4]),
    .run_switch(panel_m_switches[7]),
    .stop_switch(panel_m_switches[6]),
    
    .extram_addr(extram_addr),
    .extram_data_in(extram_din),
    .extram_data_out(extram_dout),
    .extram_rd(extram_rd),
    .extram_we(extram_we),

    .debug_leds(LED)
);

assign R = row < 10'd240 ? r_panel : {4{pixel_terminal}};
assign G = row < 10'd240 ? g_panel : {4{pixel_terminal}};
assign B = row < 10'd240 ? b_panel : {4{pixel_terminal}};

////////////////////////////////////////////

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk36m),
    .clk_rate(32'd36_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[13], audio[12:0], 2'b0}),
    .right_chan({~audio[13], audio[12:0], 2'b0})
);
`endif

mist_video #(
    .COLOR_DEPTH(4),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk36m),
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
    .ce_divider(3'd0),
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .scanlines(3'd0),
    .ypbpr(ypbpr)
);


endmodule
