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
    "S0U,DSK,Load Drive 0;",
    "S1U,DSK,Load Drive 1;",
    "O3,DSK Protect,Disable,Enable;",
    `SEP
    "F0,ROM,Reload Panel;",
    `SEP
    "F1,ROM,Reload ROM at F800;",
    `SEP
    "O12,Console color,Cyan,White,Green,Yellow;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////
wire clk36m;
wire clk72m;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk36m),
    .c1(clk72m),
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

wire [31:0] sd_lba_mux;
wire [1:0] sd_rd;
wire [1:0] sd_wr;
wire [1:0] sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din_mux;
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

    .sd_sdhc(1),
    .sd_lba(sd_lba_mux),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack_x(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din_mux),
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
    
    .serial_data(serial_data),
    .serial_strobe(serial_strobe)
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
//       Avoid wrapping by masking the bits o
wire [22:0] psram_addr = rom_download == 1'b1 ? {7'd0, 5'b11111, ioctl_addr[10:0]} : {7'd0, extram_addr[15:0]};
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
wire [15:0] panel_switches;
wire [9:0] panel_m_switches;

wire [7:0] port_leds;
wire [7:0] data_leds;
wire [7:0] cpu_leds;
wire [3:0] status_leds;

wire [7:0] disk_leds = {
    fdd_sel[0],
    fdd_ready[0],
    fdd_sel[1],
    fdd_ready[1],
    ~status[3],
    |sd_wr,
    (head_loaded[0] & fdd_sel[0] & fdd_ready[0]) | (head_loaded[1] & fdd_sel[1] & fdd_ready[1]),
    (track_zero[0] & fdd_sel[0] & fdd_ready[0]) | (track_zero[1] & fdd_sel[1] & fdd_ready[1])
};
    
panel panel(
    .clk36m(clk36m),
    .reset(reset),
    .col(col),
    .row(swapped_panels ? row - TERMINAL_HEIGHT : row),
    .hblank(hblank),
    .vblank(vblank),
    .ram_addr(vid_ram_addr),
    .ram_value(ram_value),
    
    .leds({port_leds, cpu_leds, data_leds, cpu_addr, status_leds}),
    .disk_leds(disk_leds),

    .switches(panel_switches),
    .m_switches(panel_m_switches),
    
    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe & ~terminal_active),
    .key_extended(key_extended),

    .r(r_panel),
    .g(g_panel),
    .b(b_panel)
);


wire pixel_terminal;

wire sio_rd;
wire sio_we;
wire sio_addr;
wire [7:0] sio_in;
wire [7:0] sio_out;

wire [7:0] serial_data;
wire serial_strobe;

terminal terminal(
    .clk36m(clk36m),
    .reset(reset),
    .xpos(col),
    .ypos(swapped_panels ? row : row - PANEL_HEIGHT),
    .hblank(hblank),
    .vblank(vblank),
    
    .key_pressed(key_pressed),
    .key_code(key_code),
    .key_strobe(key_strobe & terminal_active),
    .key_extended(key_extended),
    
    .sio_we(sio_we),
    .sio_rd(sio_rd),
    .sio_addr(sio_addr),
    .sio_in(sio_in),
    .sio_out(sio_out),
    
    .vout(pixel_terminal),

    .serial_echo(serial_data),
    .serial_echo_strobe(serial_strobe)
);

wire [15:0] extram_addr;
wire [7:0] extram_din;
wire [7:0] extram_dout;
wire extram_rd;
wire extram_we;

wire io_rd;
wire io_wr;
wire cpu_sync;
wire [15:0] cpu_addr;
wire fdc_we;
wire [7:0] io_data_in;
wire [7:0] io_data_out = cpu_addr[7:0] == 8'h63 ? vdrsel : 
    fdd_sel[0] ? fdc_data_out[0] :
    fdd_sel[1] ? fdc_data_out[1] :
    8'h00;

reg [4:0] cnt = 3'd0;

always @(posedge clk36m) begin
    if (cnt == 5'd17) cnt <= 3'd0;
    else cnt <= cnt + 1'd1;
end

wire f1 = cnt == 5'd0;
wire f2 = cnt == 5'd9;

assign cpu_leds[6] = io_rd;
assign cpu_leds[4] = io_wr;

imsai8080 core(
    .clk(clk36m),
    .f1(f1),
    .f2(f2),
    .reset(reset),
    
    .intr_in(1'b0),
    .hold_in(1'b0),
    .ready_in(fdc_cpu_ready),
    
    .cpu_sync(cpu_sync),
    
    .mem_rd(cpu_leds[7]),
    .io_rd(io_rd),
    .m1(cpu_leds[5]),
    .io_wr(io_wr),
    .halt_ack(cpu_leds[3]),
    .io_stack(cpu_leds[2]),
    .mem_wr_n(cpu_leds[1]),
    .interrupt_ack(cpu_leds[0]),

    .cpu_inte_o(status_leds[3]),
    .cpu_wait_o(status_leds[1]),
    .cpu_hlda_o(status_leds[0]),
    .run_o(status_leds[2]),

    .cpu_addr(cpu_addr),
    .fdc_data_in(io_data_in),
    .fdc_we(fdc_we),
    .fdc_data_out(io_data_out),
    
    .data_leds(data_leds),
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
    
    .sio_addr(sio_addr),
    .sio_rd(sio_rd),
    .sio_we(sio_we),
    .sio_in(sio_in),
    .sio_out(sio_out),

    .debug_leds()
);

reg [7:0] vdrsel = 8'd0;
wire [1:0] head_loaded;
wire [1:0] track_zero;
reg [1:0] fdd_ready = 2'b00;
wire [1:0] fdd_sel = {vdrsel[1], vdrsel[0]};
wire fdd_side = vdrsel[4];
wire [7:0] fdc_data_out[2];
wire [31:0] sd_lba[2];
wire [7:0] sd_buff_din[2];
wire [1:0] drq;
wire [1:0] fdd_io_ena = {cpu_addr[2] & fdd_ready[1] & fdd_sel[1], cpu_addr[2] & fdd_ready[0] & fdd_sel[0]};

wire fdc1_cpu_ready = ~(vdrsel[7] == 1'b1 && cpu_addr[7:0] == 8'h67 && fdd_ready[0] == 1'b1 && fdd_sel[0] == 1'b1 && drq[0] == 1'b0 && (io_rd | io_wr));
wire fdc2_cpu_ready = ~(vdrsel[7] == 1'b1 && cpu_addr[7:0] == 8'h67 && fdd_ready[1] == 1'b1 && fdd_sel[1] == 1'b1 && drq[1] == 1'b0 && (io_rd | io_wr));
wire fdc_cpu_ready = fdc1_cpu_ready & fdc2_cpu_ready;

always @(posedge clk36m) begin
    reg [1:0] old_mounted;
    old_mounted <= img_mounted;

    if (~old_mounted[0] & img_mounted[0]) fdd_ready[0] <= |img_size;
    if (~old_mounted[1] & img_mounted[1]) fdd_ready[1] <= |img_size;
    
end

assign sd_lba_mux = fdd_sel[1] ? sd_lba[1] : sd_lba[0];
assign sd_buff_din_mux = fdd_sel[1] ? sd_buff_din[1] : sd_buff_din[0];

//For a Versafloppy II controller
//With DIBASE 60H
// VDRSEL   equ     DIBASE+3    ;Drive select port
// VDCOM    equ     DIBASE+4    ;WD1793 Command port
// VDSTAT   equ     DIBASE+4    ;WD1793 Status port
// VTRACK   equ     DIBASE+5    ;WD1793 Track port
// VSECT    equ     DIBASE+6    ;WD1793 Sector Register
// VDDATA   equ     DIBASE+7    ;WD1793 Data Register

// Versafloppy II VDRSEL bit assignments (all active-high)

// VDSEL0   equ     00000001b   ;select drive 0
// VDSEL1   equ     00000010b   ;select drive 1
// VDSEL2   equ     00000100b   ;select drive 2
// VDSEL3   equ     00001000b   ;select drive 3
// VSIDE1   equ     00010000b   ;Select side 1
// VMINI    equ     00100000b   ;Set up for minidisk
// VDDEN    equ     01000000b   ;Enable double-density
// VWAIT    equ     10000000b   ;Enable auto-wait circuit

always @(posedge clk36m) begin
    reg last_fdc_we = 1'b0;
    if (reset) begin
        last_fdc_we <= 1'b0;
    end else begin
        last_fdc_we <= fdc_we;
        
        if (~last_fdc_we & fdc_we & io_wr) begin
            if (cpu_addr[7:0] == 8'h63) begin
                vdrsel <= io_data_in;
            end
        end
    end
end

wd1793 #(.RWMODE(1), .EDSK(1)) fdc1(
    .clk_sys(clk36m),
    .ce(f1),
    .reset(reset),
    .io_en(fdd_io_ena[0]),
    .intrq(),
    .drq(drq[0]),
    .busy(),
    
    .rd(io_rd),
    .wr(io_wr & fdc_we),
    .addr(cpu_addr[1:0]),
    .din(io_data_in),
    .dout(fdc_data_out[0]),

    .img_mounted(img_mounted[0]),
    .img_size(img_size[19:0]),
    .sd_lba(sd_lba[0]),
    .sd_rd(sd_rd[0]),
    .sd_wr(sd_wr[0]),
    .sd_ack(sd_ack[0]),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[0]),
    .sd_buff_wr(sd_buff_wr),

    .wp(status[3]),

    .size_code(3'd0), // 26 sectors per track x 128 bytes per sector  = 3.3KB
    .layout(0),
    .side(fdd_side),
    .ready(fdd_ready[0]),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din(),
    
    .track_zero(track_zero[0]),
    .head_loaded(head_loaded[0])
);


wd1793 #(.RWMODE(1), .EDSK(1)) fdc2(
    .clk_sys(clk36m),
    .ce(f1),
    .reset(reset),
    .io_en(fdd_io_ena[1]),
    .intrq(),
    .drq(drq[1]),
    .busy(),
    
    .rd(io_rd),
    .wr(io_wr & fdc_we),
    .addr(cpu_addr[1:0]),
    .din(io_data_in),
    .dout(fdc_data_out[1]),

    .img_mounted(img_mounted[1]),
    .img_size(img_size[19:0]),
    .sd_lba(sd_lba[1]),
    .sd_rd(sd_rd[1]),
    .sd_wr(sd_wr[1]),
    .sd_ack(sd_ack[1]),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[1]),
    .sd_buff_wr(sd_buff_wr),

    .wp(status[3]),

    .size_code(3'd0), // 26 sectors per track x 128 bytes per sector  = 3.3KB
    .layout(0),
    .side(fdd_side),
    .ready(fdd_ready[1]),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din(),
    
    .track_zero(track_zero[1]),
    .head_loaded(head_loaded[1])
);

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
