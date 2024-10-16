//============================================================================
//  SMS top-level for Nuked-SMS-FPGA
//  https://github.com/nukeykt/Nuked-SMS-FPGA
//
//  Port to MiST/SiDi
//  Szombathelyi György
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

module SMS_Nuked
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

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
localparam VGA_BITS = 6;
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
`else
localparam bit USE_AUDIO_IN = 0;
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 1;
assign SDRAM2_DQMH = 1;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"
parameter CONF_STR = {
	"NUKEDSMS;;",
	"F1,BINSMS,Load;",
	"S,SAV,Mount;",
	"T7,Write Save RAM;",
	`SEP    
	"O34,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"O2,TV System,NTSC,PAL;",
	//"P1OC,FM sound,Enable,Disable;",
	"O1,Swap joysticks,No,Yes;",
	"O6,Multitap,Disable,Port1;",
	"ODE,Lightgun,Disable,Port 1, Port 2;",
	//"P3OA,Region,US/UE,Japan;",
	//"P3O5,BIOS,Enable,Disable;",
	"OF,Lock mappers,No,Yes;",
	`SEP
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire       joyswap = status[1];
wire       palmode = status[2];
wire [1:0] scanlines = status[4:3];
//wire       enable_bios_n = status[5];
wire       multitap = status[6];
wire       save_ram = status[7];
//wire       region = status[10];
//wire       enable_fm_n = status[12];
wire [1:0] lightgun = status[14:13];
wire       lockmappers = status[15];

assign LED  = ~ioctl_download & ~bk_ena;

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;

pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_sys),
	.locked(locked)
);

assign SDRAM_CLK = clk_sys;

//////////////////   MiST I/O   ///////////////////
wire  [6:0] joy_0;
wire  [6:0] joy_1;
wire  [6:0] joy[4];
wire  [1:0] buttons;
wire [31:0] status;
wire        ypbpr;
wire        no_csync;
wire        scandoubler_disable;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire [31:0] img_size;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(
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
	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy[2]),
	.joystick_3(joy[3]),
`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif
	.mouse_x(mouse_x),
	.mouse_y(mouse_y),
	.mouse_flags(mouse_flags),
	.mouse_strobe(mouse_strobe),

	.sd_conf(0),
	.sd_sdhc(1),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

data_io data_io
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_DI(SPI_DI),
	.SPI_SS2(SPI_SS2),

	.clkref_n(ioctl_wait),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

wire [21:0] rom_addr;
wire [15:0] cart_addr;
wire  [7:0] cart_dout, cart_din;
wire        cart_oe, cart_cs, cart_csram, cart_wr;

sdram ram
(
	.*,

	.init(~locked),
	.clk(clk_sys),

	.waddr(ioctl_addr),
	.din(ioctl_dout),
	.we(rom_wr),
	.we_ack(sd_wrack),

	.raddr((rom_addr[21:0] & cart_mask) + (romhdr ? 10'd512 : 0)),
	.dout(cart_dout),
	.rd(cart_oe & cart_cs & ~cart_csram),
	.rd_rdy()
);

reg  rom_wr = 0;
wire sd_wrack;
reg  [21:0] cart_mask;
reg  reset;

always @(posedge clk_sys) begin
	reg old_download, old_reset;

	reset <= status[0] | buttons[1] | ioctl_download | bk_reset;

	old_download <= ioctl_download;
	old_reset <= reset;

	if(~old_download && ioctl_download) begin
		cart_mask <= 0;
		ioctl_wait <= 0;
	end else begin
		if(ioctl_wr && ioctl_index[5:0] == 1) begin
			ioctl_wait <= 1;
			rom_wr <= ~rom_wr;
			cart_mask <= cart_mask | ioctl_addr[21:0];
		end else if(ioctl_wait && (rom_wr == sd_wrack)) begin
			ioctl_wait <= 0;
		end
	end
end

wire  [7:0] vid_r, vid_g, vid_b;
wire        vid_hs, vid_vs, vid_hb, vid_vb;

wire        romhdr = ioctl_addr[9:0] == 10'h1FF; // has 512 byte header

wire [12:0] ram_a;
wire        ram_we;
wire  [7:0] ram_d;
wire  [7:0] ram_q;

wire [14:0] nvram_a;
wire        nvram_we = nvram_cs & cart_wr;
wire  [7:0] nvram_d = cart_din;
wire  [7:0] nvram_q;
wire        nvram_cs;

wire [12:0] bios_address;
wire  [7:0] bios_data;

wire  [6:0] port_a_o, port_b_o;

wire signed [9:0] opll_ro, opll_mo;
wire signed [15:0] psg;
wire opll_dac_clk;

wire [17:0] aud_l, aud_r;
sms_board sms_board
(
	.MCLK(clk_sys),
	.ext_reset(reset),
	.pause_button(~(joya[6]&joyb[6])),
	.reset_button(),

	// z80 ram
	.ram_address(ram_a),
	.ram_data(ram_d),
	.ram_wren(ram_we),
	.ram_o(ram_q),

	// cart
	.cart_data(nvram_cs ? nvram_q : cart_dout),
	.cart_data_en(cart_oe & cart_cs & ~cart_csram),
	.cart_address(cart_addr),
	.cart_cs(cart_cs),
	.cart_oe(cart_oe),
	.cart_wr(cart_wr),
	.cart_data_wr(cart_din),
	.cart_exm1(),
	.cart_exm2(),
	.cart_csram(cart_csram),
	.pal(palmode),

	.bios_data(bios_data),
	.bios_address(bios_address),

	.vid_r(vid_r),
	.vid_g(vid_g),
	.vid_b(vid_b),
	.vid_hsync(vid_hs),
	.vid_vsync(vid_vs),
	.vid_hblank(vid_hb),
	.vid_vblank(vid_vb),

	.opll_ro(opll_ro),
	.opll_mo(opll_mo),
	.opll_dac_clk(opll_dac_clk),
	.vdp_psg(psg),

	.port_a_i({joya_th, joya[5], joya[4], joya[0], joya[1], joya[2], joya[3]}),
	.port_b_i({joyb_th, joyb[5], joyb[4], joyb[0], joyb[1], joyb[2], joyb[3]}),
	.port_a_o(port_a_o),
	.port_b_o(port_b_o)
);

mappers mappers_inst
(
	.clk_sys   (clk_sys),
	.RESET_n   (~reset),
	.mapper_lock(lockmappers),

	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr && ioctl_index[5:0] == 1),

	.rom_a     (rom_addr),
	.cart_address (cart_addr),
	.cart_cs   (cart_cs),
	.cart_oe   (cart_oe),
	.cart_wr   (cart_wr),
	.cart_data_wr(cart_din),

	.nvram_a   (nvram_a),
	.nvram_cs  (nvram_cs)
);

spram #(.widthad_a(13)) ram_inst
(
	.clock     (clk_sys),
	.address   (ram_a),
	.wren      (ram_we),
	.data      (ram_d),
	.q         (ram_q)
);

dpram #(.widthad_a(13)) bios_inst
(
	.clock_a    (clk_sys),
	.address_a  (bios_address),
	.wren_a     (1'b0),
	.q_a        (bios_data),

	.clock_b    (clk_sys),
	.address_b  (ioctl_addr),
	.data_b     (ioctl_dout),
	.wren_b     (ioctl_wr && ioctl_index == 0)
);

/////////////////// CONTROLS //////////////////
wire       joya_tr_out = port_a_o[5];
wire       joya_th_out = port_a_o[6];
wire       joyb_tr_out = port_a_o[5];
wire       joyb_th_out = port_a_o[6];
reg        joya_th;
reg        joyb_th;
wire       joyser_th;
reg  [6:0] joya, joyb;
reg  [1:0] jcnt = 0;

assign joy[0] = joyswap ? joy_1[6:0] : joy_0[6:0];
assign joy[1] = joyswap ? joy_0[6:0] : joy_1[6:0];

always @(posedge clk_sys) begin

	reg old_th;
	reg [19:0] tmr;

	joya <= ~joy[jcnt];
	joyb <= multitap ? 7'h7F : ~joy[1];
	joya_th <=  1'b1;
	joyb_th <=  1'b1;

	if(tmr > (57000*15)) jcnt <= 0;
	else if(joya_th) tmr <= tmr + 1'd1;

	old_th <= joya_th_out;
	if(old_th & ~joya_th_out) begin
		tmr <= 0;
		//first clock doesn't count as capacitor has not discharged yet
		if(tmr < (57000*15)) jcnt <= jcnt + 1'd1;
	end

	if(reset | ~multitap) jcnt <= 0;

	if(gun_en) begin
		if(lightgun == 2'b10) begin
			joyb_th <= ~gun_sensor;
			joyb <= {2'b11, ~gun_trigger ,4'b1111};
		end else begin
			joya_th <= ~gun_sensor;
			joya <= {2'b11, ~gun_trigger ,4'b1111};
			joyb <= ~joy[0];
			joyb_th <= 1'b1;
		end
	end
end

wire        gun_en = |lightgun;
wire        gun_target;
wire        gun_sensor;
wire        gun_trigger;
wire [24:0] ps2_mouse = { mouse_strobe_level, mouse_y[7:0], mouse_x[7:0], mouse_flags };
reg         mouse_strobe_level;

always @(posedge clk_sys) if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;

reg         ce_pix;
always @(posedge clk_sys) begin
	reg [3:0] cnt;
	cnt <= cnt + 1'd1;
	ce_pix <= 0;
	if (cnt == 9) begin
		ce_pix <= 1;
		cnt <= 0;
	end
end

lightgun lightgun_instance
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(1'b1),

	.JOY_X(),
	.JOY_Y(),
	.JOY(),

	.HDE(~vid_hb),
	.VDE(~vid_vb),
	.CE_PIX(ce_pix),

	.BTN_MODE(1'b1),
	.SIZE(2'b01),
	.SENSOR_DELAY(34),

	.TARGET(gun_target),
	.SENSOR(gun_sensor),
	.TRIGGER(gun_trigger)
);

//////////////////   VIDEO   //////////////////

wire  [7:0] red   = (gun_en & gun_target) ? 8'hff : vid_r;
wire  [7:0] green = (gun_en & gun_target) ? 8'h00 : vid_g;
wire  [7:0] blue  = (gun_en & gun_target) ? 8'h00 : vid_b;

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(8), .OUT_COLOR_DEPTH(VGA_BITS), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) mist_video
(
	.clk_sys(clk_sys),
	.scanlines(scanlines),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.rotate(2'b00),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~vid_hs),
	.VSync(~vid_vs),
	.HBlank(vid_hb),
	.VBlank(vid_vb),
	.R(red),
	.G(green),
	.B(blue),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B)
);

`ifdef USE_HDMI
i2c_master #(54_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.SD_HCNT_WIDTH(10), .COLOR_DEPTH(8), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) hdmi_video
(
	.clk_sys(clk_sys),
	.scanlines(scanlines),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~vid_hs),
	.VSync(~vid_vs),
	.HBlank(vid_hb),
	.VBlank(vid_vb),
	.R(red),
	.G(green),
	.B(blue),
	.VGA_HS(HDMI_HS),
	.VGA_VS(HDMI_VS),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_DE(HDMI_DE)
);
assign HDMI_PCLK = clk_sys;
`endif

//////////////////   AUDIO   //////////////////

reg [4:0] opll_ch = 0;
reg       opll_dac_clkD;
reg signed [15:0] opll_mo_sum, opll_ro_sum;
reg signed [16:0] aud_mix;

always @(posedge clk_sys) begin
    opll_dac_clkD <= opll_dac_clk;
    if (opll_dac_clk & ~opll_dac_clkD) begin
        opll_ch <= opll_ch + 1'd1;
        opll_mo_sum <= opll_mo_sum + opll_mo;
        opll_ro_sum <= opll_ro_sum + opll_ro;
    end
    if (~opll_dac_clk & opll_dac_clkD) begin
        if (opll_ch == 18) begin
            opll_ch <= 0;
            opll_mo_sum <= 0;
            opll_ro_sum <= 0;
            aud_mix <= opll_mo_sum + opll_ro_sum + psg;
        end
    end
end

hybrid_pwm_sd dac
(
	.clk(clk_sys),
	.terminate(1'b0),
	.d_l({~aud_mix[16], aud_mix[15:1]}),
	.q_l(AUDIO_L),
	.d_r({~aud_mix[16], aud_mix[15:1]}),
	.q_r(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(reset),
	.clk(clk_sys),
	.clk_rate(32'd53_180_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(aud_mix[16:1]),
	.right_chan(aud_mix[16:1])
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(reset),
	.clk_rate_i(32'd53_180_000),
	.spdif_o(SPDIF),
	.sample_i({2{aud_mix[16:1]}})
);
`endif

/////////////////////////  STATE SAVE/LOAD  /////////////////////////////
// 8k auxilary RAM - 32k doesn't fit
dpram #(.widthad_a(13)) nvram_inst
(
	.clock_a     (clk_sys),
	.address_a   (nvram_a[12:0]),
	.wren_a      (nvram_we),
	.data_a      (nvram_d),
	.q_a         (nvram_q),
	.clock_b     (clk_sys),
	.address_b   ({sd_lba[3:0],sd_buff_addr}),
	.wren_b      (sd_buff_wr & sd_ack),
	.data_b      (sd_buff_dout),
	.q_b         (sd_buff_din)
);

reg  bk_ena     = 0;
reg  bk_load    = 0;
wire bk_save    = save_ram;
reg  bk_reset   = 0;

always @(posedge clk_sys) begin
	reg  old_load = 0, old_save = 0, old_ack, old_mounted = 0, old_download = 0;
	reg  bk_state = 0;

	bk_reset <= 0;

	old_download <= ioctl_download;
	if (~old_download & ioctl_download) bk_ena <= 0;

	old_mounted <= img_mounted;
	if(~old_mounted && img_mounted && img_size) begin
		bk_ena <= 1;
		bk_load <= 1;
	end

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(&sd_lba[3:0]) begin
				if (bk_load) bk_reset <= 1;
				bk_load <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_load;
				sd_wr  <= ~bk_load;
			end
		end
	end
end

endmodule
