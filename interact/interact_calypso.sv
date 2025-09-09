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

module interact_calypso(
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
    input AUDIO_IN
`endif
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

wire tape_play = status[14];
wire tape_rewind = status[15];

`include "build_id.v"
 localparam CONF_STR = {
     "Interact;;",
     "F,CINK7 ,Load tape;",
     "TE,Play;",
     "TF,Stop & Rewind;",
     `SEP
     "O23,Scanlines,None,25%,50%,75%;",
     `SEP
     "O6,Test Pattern,Off,On;",
     `SEP
     "T0,Reset;",
     "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys /* synthesis keep */;
wire clk_video /* synthesis keep */;
wire pll_locked;

pll pll (
    .inclk0(CLK12M),
    .c0(clk_video), //57.53 mhz
    .c1(clk_sys),   //14.38 mhz
    .locked(pll_locked)
);

/////////////////  IO  ///////////////////////////
wire [31:0] status;
wire [1:0] buttons;

wire [15:0] joy0, joy1;
wire [15:0] ajoy0, ajoy1;

wire ioctl_download;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire scandoubler_disable;
wire no_csync;
wire ypbpr;

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
    .joystick_1(joy1),

    .joystick_analog_0(ajoy0),
    .joystick_analog_1(ajoy1)
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
wire rom_download = ioctl_download && (ioctl_index == 0);
wire tape_download = ioctl_download && (ioctl_index != 0);

wire reset /* synthesis keep */ = status[0] | buttons[1] | rom_download;
wire rst_n = ~reset;

// vm80a needs a nice long reset
reg [7:0] rcnt = 8'h00;
wire cpu_rst_n /* synthesis keep */= (rcnt == 8'hFF);

always @(posedge clk_sys) begin
    if (reset) rcnt <= 8'h00;
    else if (rcnt != 8'hFF) rcnt <= rcnt + 8'h01;
end


////////////////  Computer  ////////////////////////

wire ph1 /* synthesis keep */;
wire ph2 /* synthesis keep */;
wire cbclk;
wire pix_a /* synthesis keep */;
wire vid_sel;
wire [11:0] vid_a /* synthesis keep */;
wire vid_sel_n;
wire nrr_n;
wire ce_n;
wire pce;
wire vid_ltc;
wire ram_clk;
wire brst;
wire tpclk;
wire cmp_blank;
wire irq;
wire inte;
wire cmp_sync;
wire hblank_n;
wire vblank_n;
wire hsync_n /* synthesis keep */;
wire vsync_n /* synthesis keep */;

video_timing timing (
    .clk_14m(clk_sys),
    .rst_n(rst_n),
    .ph1(ph1),
    .ph2(ph2),
    .cbclk(cbclk),
    .pix_a(pix_a),
    .vid_sel(vid_sel),
    .vid_a0(vid_a[0]),
    .vid_a1(vid_a[1]),
    .vid_a2(vid_a[2]),
    .vid_a3(vid_a[3]),
    .vid_a4(vid_a[4]),
    .vid_a5(vid_a[5]),
    .vid_a6(vid_a[6]),
    .vid_a7(vid_a[7]),
    .vid_a8(vid_a[8]),
    .vid_a9(vid_a[9]),
    .vid_a10(vid_a[10]),
    .vid_a11(vid_a[11]),
    .vid_sel_n(vid_sel_n),
    .nrr_n(nrr_n),
    .ce_n(ce_n),
    .pce(pce),
    .vid_ltc(vid_ltc),
    .ram_clk(ram_clk),
    .brst(brst),
    .tpclk(tpclk),
    .cmp_blank(cmp_blank),
    .irq(irq),
    .inte(inte),
    .cmp_sync(cmp_sync),
    .hblank_n(hblank_n),
    .vblank_n(vblank_n),
    .hsync_n(hsync_n),
    .vsync_n(vsync_n)
);

///////////////////   CPU   ///////////////////
wire [15:0] addr;
reg [7:0] cpu_din;
wire [7:0] cpu_dout;
wire wr_n;
wire ready;
wire hold;
wire rd;
wire sync;
wire vait;
wire hlda;
wire pin_aena;
wire pin_dena;

assign hold = 1'b0;
assign ready = 1'b1;

vm80a_core cpu(
    .pin_clk(clk_sys),
    .pin_f1(~ph2),
    .pin_f2(ph2),
    .pin_reset(~cpu_rst_n),
    .pin_a(addr),
    .pin_dout(cpu_dout),
    .pin_din(cpu_din),
    .pin_aena(pin_aena),
    .pin_dena(pin_dena),
    .pin_hold(hold),
    .pin_ready(ready),
    .pin_int(irq),
    .pin_wr_n(wr_n),
    .pin_dbin(rd),
    .pin_inte(inte),
    .pin_hlda(hlda),
    .pin_wait(vait),
    .pin_sync(sync)
);

//////// STATUS system control ////////////

reg [7:0] cpu_status;
wire status_inta = cpu_status[0];
//wire status_wo_n = cpu_status[1];
//wire status_stack = cpu_status[2];
//wire status_hlta = cpu_status[3];
//wire status_out = cpu_status[4];
//wire status_m1 = cpu_status[5];
//wire status_inp = cpu_status[6];
//wire status_memr = cpu_status[7];

always @(posedge clk_sys or negedge rst_n) begin
reg old_sync;
if (!rst_n) cpu_status <= 8'b0;
else begin
    old_sync <= sync;
    if (~old_sync & sync) cpu_status <= cpu_dout;
end
end

always_comb begin
    casez ({status_inta, rom_e, ram_e, ~io_3800_r_n, ~io_3000_r_n})
        5'b1????: cpu_din <= 8'hFF;
        5'b00001: cpu_din <= io_rd_rtc_ad;
        5'b00010: cpu_din <= key_data;
        5'b00100: cpu_din <= ram_out;
        5'b01000: cpu_din <= rom_out;
        default:  cpu_din <= 8'hFF;
    endcase
end


///////////////////   MEMORY   ///////////////////
//                  1111110000000000
//                  5432109876543210
// ROM A    0000H   0000000000000000
// ROM B    0800H   0000100000000000
// IO 10    1000H   0001000000000000
// IO 18    1800H   0001100000000000
// IO 20    2000H   0010000000000000
// IO 28    2800H   0010100000000000
// IO 30    3000H   0011000000000000
// IO 38    3800H   0011100000000000
// VRAM     4000H   0100000000000000
//          49FFH   0100100111111111
// RAM      4800H   0100101000000000

wire rom_e = ~addr[15] & ~addr[14] & ~addr[13] & ~addr[12] & ~addr[11];
wire [7:0] rom_out;

dpram #(
    .ADDRWIDTH(12),
    .NUMWORDS(4096),
    .MEM_INIT_FILE("rtl/boot.mif")
) rom (
    .clock(clk_sys),
    .address_a(ioctl_addr),
    .data_a(ioctl_dout),
    .wren_a(rom_download && ioctl_wr),

    .address_b(addr[11:0]),
    .q_b(rom_out)
);

wire ram_e = ~addr[15] & addr[14];
wire [7:0] ram_out;
wire ram_w = ram_e & ~wr_n;
wire [7:0] vid_out;

dpram #(
    .ADDRWIDTH(14)
) ram(
    .clock(clk_sys),
    .address_a(addr[13:0]),
    .data_a(cpu_dout),
    .wren_a(ram_w),
    .q_a(ram_out),

    .address_b({2'b0, vid_a[11:0]}),
    .q_b(vid_out)
);

///////////////////   Memory Mapped IO Registers   ///////////////////

// sure we could do this with some simple verilog conditionals, but digging the old-time TTL ICs

wire io_0000_r_n;
wire io_0800_r_n;
wire io_1000_r_n;
wire io_1800_r_n;
wire io_2000_r_n;
wire io_2800_r_n;
wire io_3000_r_n;
wire io_3800_r_n;

wire io_0000_w_n;
wire io_0800_w_n;
wire io_1000_w_n;
wire io_1800_w_n;
wire io_2000_w_n;
wire io_2800_w_n;
wire io_3000_w_n;
wire io_3800_w_n;

SN74LS138 IC25 (
    .a(addr[11]),
    .b(addr[12]),
    .c(addr[13]),
    .g1(rd),
    .g2an(addr[15]),
    .g2bn(addr[14]),
    .y0n(io_0000_r_n),
    .y1n(io_0800_r_n),
    .y2n(io_1000_r_n),
    .y3n(io_1800_r_n),
    .y4n(io_2000_r_n),
    .y5n(io_2800_r_n),
    .y6n(io_3000_r_n),
    .y7n(io_3800_r_n)
);

SN74LS138 IC26 (
    .a(addr[11]),
    .b(addr[12]),
    .c(addr[13]),
    .g1(~wr_n),
    .g2an(addr[15]),
    .g2bn(addr[14]),
    .y0n(io_0000_w_n),
    .y1n(io_0800_w_n),
    .y2n(io_1000_w_n),
    .y3n(io_1800_w_n),
    .y4n(io_2000_w_n),
    .y5n(io_2800_w_n),
    .y6n(io_3000_w_n),
    .y7n(io_3800_w_n)
);


wire [7:0] io_rd_rtc_ad;
always_comb begin
    casez (io_wr_misc[7:3])
        5'b00111: io_rd_rtc_ad = {tape_flux, rtc[6:0]};
        5'b10111: io_rd_rtc_ad = rtc;
        5'b?1111: io_rd_rtc_ad = {1'b0, rtc[6:0]};
        5'b??001: io_rd_rtc_ad = joy0[4] ? 8'h00 : 8'h80;
        5'b??010: io_rd_rtc_ad = {~ajoy0[7], ajoy0[6:0]};
        5'b??100: io_rd_rtc_ad = joy1[4] ? 8'h00 : 8'h80;
        5'b??101: io_rd_rtc_ad = {~ajoy1[7], ajoy1[6:0]};
        default:  io_rd_rtc_ad = 8'h00;
    endcase
end

wire rtc_clr = ~rst_n | io_wr_misc[6];
reg [7:0] rtc;
wire rtc_clk = io_wr_misc[6] ? 1'b0 : (io_wr_misc[7] ? pix_a : tpclk);

always @(negedge rtc_clk or posedge rtc_clr) begin
    if (rtc_clr) begin
        rtc <= 8'b0;
    end else begin
        rtc <= rtc + 1'b1;
    end
end

wire [7:0] keys[7:0];
wire [7:0] key_data = keys[addr[3:0]];

keyboard keyboard(
    .clk_sys(clk_sys),
    .rst_n(rst_n),
    .ps2_key(ps2_key),
    .joystick_0(joy0),
    .joystick_1(joy1),
    .keys(keys)
);


reg [7:0] io_wr_color_a_tape;
reg [7:0] io_wr_color_b_snd;

reg [7:0] io_wr_sound_a[3:0];
reg [7:0] io_wr_sound_b[3:0];

reg [7:0] io_wr_misc;

always @(posedge io_1000_w_n or negedge rst_n) begin
    if (!rst_n) begin
        io_wr_color_a_tape <= 8'b0;
    end else begin
        io_wr_color_a_tape <= cpu_dout;
    end
end

always @(posedge io_1800_w_n or negedge rst_n) begin
    if (!rst_n) begin
        io_wr_color_b_snd <= 8'b0;
    end else begin
        io_wr_color_b_snd <= cpu_dout;
    end
end

always @(posedge io_2000_w_n or negedge rst_n) begin
    if (!rst_n) begin
        io_wr_sound_a[2'b00] <= 8'b0;
        io_wr_sound_a[2'b01] <= 8'b0;
        io_wr_sound_a[2'b10] <= 8'b0;
        io_wr_sound_a[2'b11] <= 8'b0;
    end else begin
        io_wr_sound_a[addr[1:0]] <= cpu_dout;
    end
end

always @(posedge io_2800_w_n or negedge rst_n) begin
    if (!rst_n) begin
        io_wr_sound_b[2'b00] <= 8'b0;
        io_wr_sound_b[2'b01] <= 8'b0;
        io_wr_sound_b[2'b10] <= 8'b0;
        io_wr_sound_b[2'b11] <= 8'b0;
    end else begin
        io_wr_sound_b[addr[1:0]] <= cpu_dout;
    end
end

always @(posedge io_3000_w_n or negedge rst_n) begin
    if (!rst_n) begin
        io_wr_misc <= 8'b0;
    end else begin
        io_wr_misc <= cpu_dout;
    end
end


///////////////////   Video   ///////////////////

//// Test generator start

reg [7:0] vidtest_x;
reg [7:0] vidtest_y;
wire [6:0] vidtest_scanline = vid_a[11:5];

always @(posedge vid_ltc or negedge hblank_n) begin
    if (!hblank_n) vidtest_x <= 8'b0;
    else vidtest_x <= vidtest_x + 1'b1;
end

always @(posedge hsync_n or negedge vblank_n) begin
    if (!vblank_n) vidtest_y <= 8'b0;
    else vidtest_y <= vidtest_y + 1'b1;
end

//// Test generator end


reg [7:0] pix_byte;
wire pix_en = vid_sel & vid_ltc & ~(ce_n | pce);

always @(posedge pix_en or negedge rst_n) begin
    if (!rst_n) begin
        pix_byte <= 8'b0;
    end else begin
        pix_byte <= vid_out;
    end
end

reg [3:0] pix_nib;

always @(posedge vid_sel_n or negedge rst_n) begin
    if (!rst_n) begin
        pix_nib <= 4'b0;
    end else begin
        pix_nib <= pix_byte[7:4];
   end
end



reg [7:0] R;
reg [7:0] G;
reg [7:0] B;

wire [1:0] pix = vid_sel ? (pix_a ? pix_nib[3:2] : pix_nib[1:0]) : (pix_a ? pix_byte[3:2] : pix_byte[1:0]);

wire [2:0] cr[3:0];

assign cr[2'b00] = io_wr_color_a_tape[2:0];
assign cr[2'b01] = io_wr_color_b_snd[2:0];
assign cr[2'b10] = io_wr_color_a_tape[5:3];
assign cr[2'b11] = io_wr_color_b_snd[5:3];

wire [2:0] color = cr[pix];
wire color_intensity = (pix == 2'b10) ? io_wr_color_b_snd[6] : 1'b0;

wire test_pattern = status[6];

always @(posedge vid_ltc or negedge rst_n) begin
    if (!rst_n) begin
        R <= 8'b0;
        G <= 8'b0;
        B <= 8'b0;
    end else begin
        if (cmp_blank) begin
            R <= 8'b0;
            G <= 8'b0;
            B <= 8'b0;
        end else if (test_pattern & (vidtest_x === 8'd0)) begin
            R <= 8'h00;  //darkgreen
            G <= 8'h64;
            B <= 8'h00;
        end else if (test_pattern & (vidtest_x === 8'd110)) begin
            R <= 8'h7c;  //lawngreen
            G <= 8'hfc;
            B <= 8'h00;
        end else if (test_pattern & (vidtest_scanline === 7'd0)) begin
            R <= 8'h8A;  //blueviolet
            G <= 8'h2B;
            B <= 8'hE2;
        end else if (test_pattern & (vidtest_scanline === 7'd75)) begin
            R <= 8'h1e;  //dodgerblue
            G <= 8'h90;
            B <= 8'hff;
        end else begin
            if (color_intensity) begin
                if (test_pattern) begin
                    R <= 8'h7c;  //lawngreen
                    G <= 8'hfc;
                    B <= 8'h00;
                end else begin
                    R <= {1'b0, {7{color[0]}}};
                    G <= {1'b0, {7{color[1]}}};
                    B <= {1'b0, {7{color[2]}}};
                end
            end else begin
                R <= {8{color[0]}};
                G <= {8{color[1]}};
                B <= {8{color[2]}};
            end
        end
    end
end


//// Tape Loading

wire [15:0] tape_addr;
wire [7:0] tape_data;
reg [15:0] tape_end;

dpram #(
    .ADDRWIDTH(15)
) tape(
    .clock(clk_sys),
    .address_a(ioctl_addr),
    .data_a(ioctl_dout),
    .wren_a(tape_download && ioctl_wr),

    .address_b(tape_addr),
    .q_b(tape_data)
);

always @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
        tape_end <= 16'b0;
    end else begin
        if (tape_download) tape_end <= ioctl_addr;
    end
end

wire tape_playing;
wire tape_flux;

wire [15:0] audio;

cassette cassette(
    .clk(clk_sys),
    .rst_n(rst_n),
    .play(tape_play),
    .rewind(tape_rewind),
    .playing(tape_playing),
    .motor(io_wr_color_a_tape[6]),

    .tape_addr(tape_addr),
    .tape_data(tape_data),
    .tape_end (tape_end),

    .flux (tape_flux),
    .audio(audio)
);



`ifdef I2S_AUDIO
i2s i2s(
    .reset(1'b0),
    .clk(clk_video),
    .clk_rate(32'd57_600_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio),
    .right_chan(audio)
);
`endif


mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(11),
    .OSD_COLOR(3'b010),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1'b1),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_video),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R),
    .G(G),
    .B(B),
    .HBlank(~hblank_n),
    .VBlank(~vblank_n),
    .HSync(hsync_n),
    .VSync(vsync_n),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd1),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[3:2]),
    .ypbpr(ypbpr)
);


endmodule
