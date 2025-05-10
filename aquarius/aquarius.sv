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

module aquarius_calypso(
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
    "AQUARIUS;;",
    `SEP
    "F1,BIN,Load Cartridge;",
    "F2,CAQ,Load Tape;",
//    "O9,Fast loading,No,Yes;",
    "O4,Tape Input,File,Audio;",
    "O5,Tape Sound,Yes,No;",
    `SEP
    "O23,Scanlines,Off,25%,50%,75%;",
    `SEP
    "O78,RAM expansion,16KB,32KB,None,4KB;",
    `SEP
    "T0,Reset;",
    `SEP
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};


/////////////////  CLOCKS  ////////////////////////
wire clk_sys;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);

reg ce_3m5;
reg ce_1m7;
reg ce_3k33;

wire fast_tape = tape_req && {status[9],status[6:5]};

always @(negedge clk_sys) begin 
    reg  [4:0] clk_div;
    reg [14:0] clk_div2;

    clk_div <= clk_div + 1'd1;
    ce_1m7 <= !clk_div[4:0];
    
    casex({fast_tape, status[6:5]}) 
        'b1XX: ce_3m5 <= 1;
        'b000: ce_3m5 <= !clk_div[3:0];
        'b001: ce_3m5 <= !clk_div[2:0];
        'b010: ce_3m5 <= !clk_div[1:0];
        'b011: ce_3m5 <= !clk_div[0:0];
    endcase
    
    clk_div2 <= clk_div2 + 1'd1;
    if(clk_div2 >= (fast_tape ? 1073 : 17187)) clk_div2 <= 0;
    ce_3k33 <= !clk_div2;
end

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

wire [31:0] img_ext;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b0),
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
wire reset = status[0] | buttons[1];
wire cpu_reset = reset || (ioctl_download && (ioctl_index == 1));

reg rom_loaded = 0;
always @(posedge clk_sys) begin
    if(ioctl_download && (ioctl_index == 1)) rom_loaded <= 1;
    if(reset) rom_loaded <= 0;
end

// CPU control signals
wire [15:0] cpu_addr;
wire [7:0] cpu_din;
wire [7:0] cpu_dout;
wire cpu_rd_n;
wire cpu_wr_n;
wire cpu_mreq_n;
wire cpu_rfsh_n;
wire cpu_m1_n;
wire cpu_iorq_n;
wire ce_3m5_gated = (mainrom_download | tape_download) ? 1'b0 : ce_3m5;

T80s T80s(
    .RESET_n(~cpu_reset),
    .CLK(clk_sys),
    .CEN(ce_3m5_gated),
    .RFSH_n(cpu_rfsh_n),
    .IORQ_n(cpu_iorq_n),
    .M1_n(cpu_m1_n),
    .MREQ_n(cpu_mreq_n),
    .RD_n(cpu_rd_n), 
    .WR_n(cpu_wr_n),
    .A(cpu_addr),
    .DI(cpu_din),
    .DO(cpu_dout)
);

/////////////////  Memory  ////////////////////////
wire ram_we, ext_we;
wire [7:0] ram_dout;
wire [7:0] ram_din;

wire [22:0] sdram_addr;
wire [15:0] sdram_din;
wire [15:0] sdram_dout;
wire sdram_rd;
wire sdram_we;
wire sdram_ready;

wire mainrom_download = ioctl_download && ioctl_index[1:0] == 2'b00;
wire extrom_download = ioctl_download && ioctl_index[1:0] == 2'b01;
wire tape_download = ioctl_download && ioctl_index[1:0] == 2'b10;

wire cpu_memrq = ~cpu_mreq_n & (~cpu_rd_n | ~cpu_wr_n);

always @(*) begin
    casex ({mainrom_download, extrom_download, tape_download, cpu_memrq, tape_req})
        'b1xxxx:  sdram_addr = {10'd0, ioctl_addr[12:0]};              //main rom       @ 00000 - 01FFF -  8Kb
        'b01xxx:  sdram_addr = {7'd0, 2'b11, ioctl_addr[13:0]};        //ext rom        @ 0C000 - 0FFFF -  16Kb
        'b001xx:  sdram_addr = {6'd0, 1'b1, ioctl_addr[15:0]};         //tape write     @ 10000 -       
        'b0001x:  sdram_addr = {7'd0, cpu_addr[15:0]};                 //cpu access     @ 00000 - 0FFFF   64Kb
        'b00001:  sdram_addr = {6'd0, 1'b1, tape_addr[15:0]};          //tape read      @ 10000 -
        default: sdram_addr = sdram_addr;
    endcase
end

assign sdram_rd = ~(cpu_rd_n | cpu_mreq_n) | tape_req;
assign sdram_we = ioctl_wr | ~(cpu_wr_n | cpu_mreq_n); 
assign sdram_din = ioctl_wr ? ioctl_dout : ram_din;
assign ram_dout = (cpu_rd_n | cpu_mreq_n) ? 8'hff : sdram_dout;
assign tape_data = sdram_dout;

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
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);

wire [7:0] aquarius_rom_data = sdram_dout[7:0];
/*
main_rom main_rom(
    .clk(clk_sys),
    .addr(cpu_addr[12:0]),
    .data(aquarius_rom_data)
);
*/


/*
gen_dpram #(16,8) main_ram(
    .clock_a(clk_sys),
    .address_a({2'b11, ioctl_addr[13:0]}),
    .data_a(ioctl_dout),
    .wren_a((ioctl_index == 1) && ioctl_download && ioctl_wr),

    .clock_b(clk_sys),
    .address_b(cpu_addr),
    .data_b(ram_din),
    .enable_b(ce_3m5),
    .wren_b(ram_we | ext_we),
    .q_b(ram_dout)
);
*/

wire video_we;
wire cass_in, cass_out;
Pla1 Pla1(
    .CLK(clk_sys & ce_3m5),
    .RST(cpu_reset),

    .CFG(status[8:7] + 2'd2),

    .ADDR(cpu_addr),
    .CPU_IN(cpu_dout),
    .CPU_OUT(cpu_din),
    .MEMWR(~cpu_mreq_n & ~cpu_wr_n), 
    .IOWR((~cpu_iorq_n && cpu_m1_n) && ~cpu_wr_n),
    .IORD((~cpu_iorq_n && cpu_m1_n) && ~cpu_rd_n),

    .VIDEO_WE(video_we),

    .DATA_ROM(aquarius_rom_data),
    .DATA_ROMPACK(ram_dout),
    .ROM_EN(rom_loaded),

    .EXT_WE(ext_we),
    .RAM_WE(ram_we),
    .RAM_IN(ram_dout),
    .RAM_OUT(ram_din),

    .KEY_VALUE(key_value),
    .PSG_IN(psg_dout),
    .PSG_SEL(psg_sel),
    .LED_OUT(LED[1]),
    .CASS_OUT(cass_out),
    .CASS_IN(status[4] ? TAPE_SOUND : cass_in),
    .VSYNC(vf)
);

////////////////////////////////////////////////////////

gen_dpram #(10,8) video_data(
    .clock_a(clk_sys),
    .enable_a(ce_3m5),
    .address_a(cpu_addr[9:0]),
    .wren_a(~cpu_addr[10] & video_we),
    .data_a(cpu_dout),

    .clock_b(clk_sys),
    .address_b(vd_addr),
    .q_b(vd_data)
);

gen_dpram #(10,8) video_color(
    .clock_a(clk_sys),
    .enable_a(ce_3m5),
    .address_a( cpu_addr[9:0]),
    .wren_a( cpu_addr[10] & video_we),
    .data_a( cpu_dout),

    .clock_b(clk_sys),
    .address_b(vd_addr),
    .q_b( vd_color)
);


wire [7:0] vd_data, vd_color;
wire [9:0] vd_addr;
wire vf;
wire [7:0] R,G,B;
wire HBlank,VBlank,HSync,VSync;
wire ce_pix;

video video(
    .clk_sys(clk_sys),
    .vf(vf),
    .video_addr(vd_addr),
    .video_data(vd_data),
    .video_color(vd_color),
    .ce_pix(ce_pix),
    .R(R),
    .G(G),
    .B(B),
    .HBlank(HBlank),
    .VBlank(VBlank),
    .HSync(HSync),
    .VSync(VSync)
);


////////////////////////////////////////////////////////

wire [7:0] psg_dout;
wire       psg_sel;
wire [9:0] audio_a, audio_b, audio_c;

ym2149 ym2149(
    .CLK(clk_sys),
    .CE(ce_1m7),
    .RESET(cpu_reset),

    .BDIR(psg_sel && !cpu_wr_n),
    .BC(psg_sel && (cpu_addr[0] || cpu_wr_n)),
    .DI(cpu_dout),
    .DO(psg_dout),

    .CHANNEL_A(audio_a[7:0]),
    .CHANNEL_B(audio_b[7:0]),
    .CHANNEL_C(audio_c[7:0]),

    .SEL(0),
    .MODE(0),

    .IOA_in(pad0),
    .IOB_in(pad1)
);

assign {audio_a[9:8], audio_b[9:8], audio_c[9:8]} = 0;
wire [1:0] cass_audio = status[5] ? 2'b00 : {cass_out, status[4] ? TAPE_SOUND : cass_in};
wire [9:0] audio_data = audio_a + audio_b + audio_c + {2'b00, cass_audio, 6'd0};

////////////////////////////////////////////////////////

wire [7:0] pad0, pad1;

pad pad_0(.joy_in(joy0[9:0] | kbd_pad0), .pad_out(pad0));
pad pad_1(.joy_in(joy1[9:0] | kbd_pad1), .pad_out(pad1));

// include keyboard decoder
wire [7:0] key_value; // Pla1 <-> PS2_to_matrix

wire [9:0] kbd_pad0,kbd_pad1;
PS2_to_matrix PS2_to_matrix(
    .clk(clk_sys),
    .reset( cpu_reset),

    // Pla1 interface
    .sfrdatao(key_value),
    .addr(cpu_addr[15:8]),

    .pad0(kbd_pad0),
    .pad1(kbd_pad1),
    
    .psdatai(key_code),
    .psdataex(key_extended),
    .pspress(key_pressed),
    .psstate(key_strobe)
);

////////////////////////////////////////////////////////

reg tape_loaded = 0;
always @(posedge clk_sys) begin
    reg old_download;
    old_download <= ioctl_download;
    
    tape_loaded <= (old_download & ~ioctl_download && (ioctl_index == 2));
    if(cpu_reset) tape_loaded <= 0;
end

/*
gen_dpram #(16,8) tape_ram(
    .clock_a(clk_sys),
    .address_a(ioctl_addr[15:0]),
    .data_a(ioctl_dout),
    .wren_a((ioctl_index == 2) && ioctl_download && ioctl_wr),

    .clock_b(clk_sys),
    .address_b(tape_addr),
    .data_b(0),
    .wren_b(0),
    .q_b(tape_data)
);
*/

wire [7:0]  tape_data;
wire [15:0] tape_addr;
wire tape_req;

tape tape(
    .clk(clk_sys),
    .ce_tape(ce_3k33),
    .reset(cpu_reset),
    .sdram_available(~cpu_rfsh_n),
    .sdram_ready(sdram_ready),

    // Memory interface
    .data(tape_data),
    .addr(tape_addr),
    .length(ioctl_addr[15:0]),
    .req(tape_req),
    
    // Tape interface
    .loaded(tape_loaded),
    .out(cass_in)
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd42_660_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio_data[9], audio_data[8:0], 6'b0}),
    .right_chan({~audio_data[9], audio_data[8:0], 6'b0})
);
`endif

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .USE_BLANKS(1'b1),
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
    .HBlank(HBlank),
    .VBlank(VBlank),
    .HSync(~HSync),
    .VSync(~VSync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[3:2]),
    .ypbpr(ypbpr)
);


endmodule
