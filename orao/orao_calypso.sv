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

module orao_calypso(
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
assign LED[1] = reset;

`include "build_id.v"
localparam CONF_STR = {
   "ORAO;;",
   `SEP
   "F,TAP;",
   `SEP
    "O2,Screen Color,White,Green;",
   `SEP
   "T0,Reset;",
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

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

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

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 

user_io #(
    .STRLEN($size(CONF_STR)>>3),
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
    .key_extended(key_extended)
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
reg reset = 1;

always @(posedge clk_sys) begin
   integer initRESET = 20000000;
   reg [3:0] reset_cnt;

   if ((~(status[0] | buttons[1] | ~pll_locked) && reset_cnt == 4'd14) && !initRESET)
      reset <= 0;
   else begin
      if (initRESET) initRESET <= initRESET - 1;
      reset <= 1;
      reset_cnt <= reset_cnt + 4'd1;
   end
end

reg ce_1m;

always @(posedge clk_sys) begin
   reg  [6:0] cpu_div = 0;
   reg  [6:0] cpu_rate = 7'd50;     // For a 50 MHz clock

   if(cpu_div == cpu_rate) begin
      cpu_div  <= 0;
    end
    else
        cpu_div <= cpu_div + 1'd1;
   
      
   ce_1m <= (cpu_div == 7'd8);
end

/////////////////  Memory  ////////////////////////

wire [22:0] sdram_addr = ioctl_download ? ioctl_addr[22:0] : {7'd0, tape_addr};
wire [7:0] sdram_din = ioctl_download ? ioctl_dout: 8'd0;
wire [7:0] sdram_dout;
wire sdram_rd = ioctl_download ? 1'b0 : tape_rd;
wire sdram_we = ioctl_download ? ioctl_wr : 1'b0;
wire sdram_ready;

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


///////////////////////////////////////////////////
// CPU
///////////////////////////////////////////////////

wire [15:0] addr;
wire [7:0] cpu_data_out;
wire [7:0] cpu_data_in;

wire we;
wire irq;

cpu6502 cpu(
   .clk(clk_sys),
   .ce(ce_1m & (~ioctl_download)),
   .reset(reset),
   .nmi(0),
   .irq(irq),
   .din(cpu_data_in),
   .dout(cpu_data_out),
   .addr(addr),
   .we(we)
);

///////////////////////////////////////////////////
// Orao hardware
///////////////////////////////////////////////////

wire pix;
wire hblank, vblank;
wire hsync, vsync;
wire sound;
wire [7:0] R = status[2] ? 8'd0 : {8{pix}},
           G = {8{pix}},
           B = status[2] ? 8'd0 : {8{pix}};

wire tape_rd;
wire [15:0] tape_addr;

orao_hw hw(
    .clk(clk_sys),
    .ce_1m(ce_1m),
    .reset(reset),
    
    .HSync(hsync),
    .VSync(vsync),
    .HBlank(hblank),
    .VBlank(vblank),
    .pix(pix),

    .addr(addr),
    .data_out(cpu_data_in),
    .data_in(cpu_data_out),
    .we(we),
    
    .ps2_key(ps2_key),
   
    .audio(sound),
    
    .tape_data(sdram_dout),
    .tape_rd(tape_rd),
    .tape_data_ready(sdram_ready),
    .tape_addr(tape_addr),
    .tape_reset(ioctl_download)
    
);


////////////////////////////////////////////////////////////////////
// Audio                                                          //
////////////////////////////////////////////////////////////////////
wire mixed_audio = {sound ^ (ioctl_download & ioctl_dout[6])};
wire [13:0] audio = {mixed_audio, 3'd0, mixed_audio, 9'd0};

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd50_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~audio[13], audio[12:0], 2'b0}),
    .right_chan({~audio[13], audio[12:0], 2'b0})
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
    .scandoubler_disable(1'b1),
    .no_csync(no_csync),
    .scanlines(),
    .ypbpr(ypbpr)
);


endmodule
