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
wire TAPE_SOUND = AUDIO_IN;
`else
localparam bit USE_AUDIO_IN = 0;
wire TAPE_SOUND = UART_RX;
`endif

`include "build_id.v"
parameter CONF_STR = {
    "IMSAI8080;;",
    "S0U,DSK,Mount Drive 0;",
    "S1U,DSK,Mount Drive 1;",
    "O3,DSK Protect,Disable,Enable;",
    `SEP
    "F0,ROM,Reload Panel;",
    `SEP
    "F1,ROM,Reload ROM at F800;",
    `SEP
    "O12,Console color,Cyan,White,Green,Yellow;",
    "O4,Votrax,Disabled,Enabled;",
    "O5,Votrax Input,Console,Port B;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire clk36m;
wire clk72m;
wire clk2m5;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk36m),
    .c1(clk72m),
    .c2(clk2m5),
    .locked(pll_locked)
);

reg [1:0] ce_counter;
wire mem_clkref = ce_counter == 2'b00;
always @(posedge clk36m) begin
    if (reset) ce_counter <= 2'd0;
    
    ce_counter <= ce_counter + 1'd1;
end

/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;

wire [31:0] sd_lba;
wire [1:0] sd_rd;
wire [1:0] sd_wr;
wire [1:0] sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;

wire [1:0] img_mounted;
wire [63:0] img_size;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;

wire no_csync;
wire ypbpr;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

user_io #(
    .SERIAL_CHANNEL(3'd2),
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(2),
    .FEATURES(32'h1000 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk36m),
    .clk_sd(clk36m),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_CLK(SPI_SCK),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .conf_str(CONF_STR),
    .status(status),

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
    
    .ypbpr(ypbpr),
    .no_csync(no_csync),
    .buttons(buttons),

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    
    .serial_data(porta_serial_data),
    .serial_strobe(porta_serial_strobe)
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

wire reset =  status[0] | buttons[1] | ioctl_download | ~pll_locked | ~panel_ready | ~rom_ready;

wire panel_download = ioctl_download && ioctl_index == 8'd0;
wire rom_download = ioctl_download && ioctl_index == 8'd1;

reg panel_ready = 1'b0;
reg rom_ready = 1'b0;

always @(posedge clk36m) begin
    reg panel_download_last = 1'b0;
    reg rom_download_last = 1'b0;
    panel_download_last <= panel_download;
    rom_download_last <= rom_download;
    if (~panel_download_last & panel_download) panel_ready <= 1'b0;
    if (~rom_download_last & rom_download) rom_ready <= 1'b0;

    if (panel_download_last & ~panel_download) panel_ready <= 1'b1;
    if (rom_download_last & ~rom_download) rom_ready <= 1'b1;
end

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



// Place the ROM at F800 initially
// TODO: Option to load arbitrary data on the address given by the programmed input switches
//       Avoid wrapping by masking the bits
wire ram_rd = bus_cpu_rd == 1'b1 && bus_cpu_sysctl[6] == 1'b0;
wire ram_we = (bus_cpu_wr_n == 1'b0 && bus_cpu_sysctl[4] == 1'b0) || panel_we == 1'b1;

wire [22:0] psram_addr = rom_download == 1'b1 ? {7'd0, 5'b11111, ioctl_addr[10:0]} : {7'd0, bus_addr[15:0]};
wire psram_rd = rom_download == 1'b1 ? 1'b0 : ram_rd;
wire psram_we = rom_download == 1'b1 ? ioctl_wr : ram_we;
wire psram_ready;
wire [7:0] psram_din = rom_download == 1'b1 ? ioctl_dout :
    panel_we == 1'b1 ? panel_data_out : bus_cpu_data_out;
wire [7:0] psram_dout;
assign ram_data_out = ram_rd == 1'b1 ? psram_dout : 8'h00;

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

wire [3:0] R, G, B;
wire hblank, vblank;
wire hsync, vsync;
wire [10:0] col;
wire [9:0] row;

wire [16:2] vid_ram_addr;
wire [31:0] ram_value;

vga vga(
    .clk36m(clk36m),
    .reset(reset),
    .clkref(~mem_clkref),
    
    .col(col),
    .row(row),
    .hsync(hsync),
    .vsync(vsync),
    .hblank(hblank),
    .vblank(vblank)
);

// Keyboard will be routed to panel or console based on this flag
// Control + F1 to toggle
// Control + F2 to swap terminal and panel positions

reg terminal_active = 1'b0;
reg swapped_panels = 1'b0;
always @(posedge clk36m) begin
    reg ctrl = 1'b0;

    if (reset == 1'b1) begin
        terminal_active <= 1'b0;
        ctrl <= 1'b0;
    end
    else if (key_strobe == 1'b1) begin
        casez ({ctrl, key_code})
            {1'b1, 8'h05}: if (key_pressed == 1'b1) terminal_active <= ~terminal_active;
            {1'b1, 8'h06}: if (key_pressed == 1'b1) swapped_panels <= ~swapped_panels;
            {1'b?, 8'h14}: ctrl <= key_pressed;
        endcase
    end
end

localparam [9:0] PANEL_WIDTH = 10'd800;
localparam [8:0] PANEL_HEIGHT = 9'd280;
localparam [8:0] TERMINAL_HEIGHT = 9'd300;

wire [3:0] r_panel;
wire [3:0] g_panel;
wire [3:0] b_panel;

wire fdc_cpu_ready;
wire [7:0] disk_leds;

wire [15:0] bus_addr;
wire [7:0] bus_cpu_data_in = panel_ce == 1'b1 ? panel_data_out :
    portb_serial_bus_data_out | terminal_data_out | fdc_data_out | ram_data_out;
wire [7:0] bus_cpu_data_out;
wire [7:0] bus_cpu_sysctl;
wire bus_cpu_wait;
wire bus_cpu_inte;
wire bus_cpu_hlda;
wire bus_cpu_rd;
wire bus_cpu_wr_n;
wire bus_cpu_sync;
wire bus_xrdy;
wire panel_ce;
wire panel_we;

panel panel(
    .clk(clk36m),
    .f1(f1),
    .f2(f2),
    .reset(reset),
    .ready_in(fdc_cpu_ready),
    
    .col(col),
    .row(swapped_panels ? row - TERMINAL_HEIGHT : row),
    .hblank(hblank),
    .vblank(vblank),
    .ram_addr(vid_ram_addr),
    .ram_value(ram_value),
    
    .disk_leds(disk_leds),
    
    .bus_addr(bus_addr),
    .bus_data_in(bus_cpu_data_out),
    .bus_cpu_data_in(bus_cpu_data_in),
    .bus_data_out(panel_data_out),
    .bus_cpu_sysctl(bus_cpu_sysctl),
    .bus_cpu_sync(bus_cpu_sync),
    .bus_cpu_wait(bus_cpu_wait),
    .bus_cpu_inte(bus_cpu_inte),
    .bus_cpu_hlda(bus_cpu_hlda),
    .bus_cpu_rd(bus_cpu_rd),
    .bus_cpu_wr_n(bus_cpu_wr_n),
    
    .bus_xrdy(bus_xrdy),
    .panel_ce(panel_ce),
    .panel_we(panel_we),

    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe & ~terminal_active),
    .key_extended(key_extended),

    .r(r_panel),
    .g(g_panel),
    .b(b_panel)
);


wire pixel_terminal;

wire [7:0] porta_serial_data;
wire porta_serial_strobe;

terminal #(
    .CARD_ADDR(4'd0),
    .CARD_PORT(2'b01)
) terminal(
    .clk(clk36m),
    .reset(reset),
    
    .xpos(col),
    .ypos(swapped_panels ? row : row - PANEL_HEIGHT),
    .hblank(hblank),
    .vblank(vblank),
    
    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe & terminal_active),
    .key_extended(key_extended),
    
    .bus_addr(bus_addr),
    .bus_cpu_rd(bus_cpu_rd),
    .bus_cpu_wr_n(bus_cpu_wr_n),
    .bus_cpu_sysctl(bus_cpu_sysctl),
    .bus_data_in(bus_cpu_data_out),
    .bus_data_out(terminal_data_out),
    
    .vout(pixel_terminal),

    .serial_echo(porta_serial_data),
    .serial_echo_strobe(porta_serial_strobe)
);

reg [4:0] cnt = 3'd0;
always @(posedge clk36m) begin
    if (cnt == 5'd17) cnt <= 3'd0;
    else cnt <= cnt + 1'd1;
end

wire f1 = cnt == 5'd0;
wire f2 = cnt == 5'd9;

wire [7:0] terminal_data_out;
wire [7:0] panel_data_out;
wire [7:0] fdc_data_out;
wire [7:0] ram_data_out;

cpu cpu_board(
    .clk(clk36m),
    .f1(f1),
    .f2(f2),
    .reset(reset),
    
    .bus_cpu_xrdy(bus_xrdy),
    .bus_cpu_intr(1'b0),
    .bus_cpu_hold(1'b0),
    
    .bus_cpu_sync(bus_cpu_sync),
    .bus_cpu_wait(bus_cpu_wait),
    .bus_cpu_inte(bus_cpu_inte),
    .bus_cpu_hlda(bus_cpu_hlda),
    .bus_cpu_rd(bus_cpu_rd),
    .bus_cpu_wr_n(bus_cpu_wr_n),

    .bus_cpu_sysctl(bus_cpu_sysctl),
    .bus_addr(bus_addr),
    .bus_data_out(bus_cpu_data_out),
    .bus_data_in(bus_cpu_data_in)
);


fdc fdc_board(
    .clk(clk36m),
    .ce(f1),
    .reset(reset),
    
    .bus_cpu_sysctl(bus_cpu_sysctl),
    .bus_cpu_wr_n(bus_cpu_wr_n),
    .bus_cpu_rd(bus_cpu_rd),

    .bus_addr(bus_addr),
    .bus_data_in(bus_cpu_data_out),
    .bus_data_out(fdc_data_out),
    
    .sd_lba_mux(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din_mux(sd_buff_din),
    .sd_buff_wr(sd_buff_wr),
    
    .img_mounted(img_mounted),
    .img_size(img_size),
    
    .fdc_cpu_ready(fdc_cpu_ready),
    
    .write_protect(status[3]),
    
    .disk_leds(disk_leds)
);

wire [7:0] portb_serial_bus_data_out;
wire [7:0] portb_serial_data;
wire portb_serial_strobe;
sio2 #(
    .CARD_ADDR(4'd0),
    .CARD_PORT(2'b10)
) serial_port_b(
    .clk(clk36m),
    .reset(reset),
    .bus_cpu_sysctl(bus_cpu_sysctl),
    .bus_cpu_rd(bus_cpu_rd),
    .bus_cpu_wr_n(bus_cpu_wr_n),
    .bus_addr(bus_addr),
    .bus_data_in(bus_cpu_data_out),
    .bus_data_out(portb_serial_bus_data_out),
    .cts(1'b1),
    .rts(1'b1),

    .serial_in(),
    .serial_in_strobe(),
    .serial_out(portb_serial_data),
    .serial_out_strobe(portb_serial_strobe)
);

wire [17:0] votrax_audio;
wire [7:0] votrax_serial_data = status[5] == 1'b1 ? portb_serial_data : porta_serial_data;
wire votrax_serial_strobe = status[5] == 1'b1 ? portb_serial_strobe : porta_serial_strobe;

votrax votrax(
    .clk36m(clk36m),
    .clk2m5(clk2m5),
    .reset(reset),
    
    .serial_data(votrax_serial_data),
    .serial_strobe(votrax_serial_strobe & status[4]),
    
    .audio(votrax_audio),
    .audio_valid(),
    
    .acia_status()
);

wire [15:0] audio = status[4] == 1'b1 ? votrax_audio[17:2] : 16'd0;

i2s i2s (
    .reset(1'b0),
    .clk(clk36m),
    .clk_rate(32'd36_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio),
    .right_chan(audio)
);

wire [11:0] rgb_t_green = pixel_terminal == 1'b1 ? 12'h0e0 : 12'd0;
wire [11:0] rgb_t_white = pixel_terminal == 1'b1 ? 12'heee : 12'd0;
wire [11:0] rgb_t_cyan = pixel_terminal == 1'b1 ? 12'h7ee : 12'h111;
wire [11:0] rgb_t_yellow = pixel_terminal == 1'b1 ? 12'hfe0 : 12'd0;
wire [11:0] rgb_t_disabled = pixel_terminal == 1'b1 ? 12'h555 : 12'h111;

wire [12:0] rgb_terminal = terminal_active ? 
    status[2:1] == 2'b00 ? rgb_t_cyan :
    status[2:1] == 2'b01 ? rgb_t_white :
    status[2:1] == 2'b10 ? rgb_t_green :
    rgb_t_yellow :
    rgb_t_disabled;

assign R = swapped_panels ?
    (row < TERMINAL_HEIGHT ? rgb_terminal[11:8] : r_panel) :
    (row < PANEL_HEIGHT ? r_panel : rgb_terminal[11:8]);
assign G = swapped_panels ?
    (row < TERMINAL_HEIGHT ? rgb_terminal[7:4] : g_panel) :
    (row < PANEL_HEIGHT ? g_panel : rgb_terminal[7:4]);
assign B = swapped_panels ?
    (row < TERMINAL_HEIGHT ? rgb_terminal[3:0] : b_panel) :
    (row < PANEL_HEIGHT ? b_panel : rgb_terminal[3:0]);


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
