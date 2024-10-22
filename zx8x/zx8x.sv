//============================================================================
// 
//  ZX80-ZX81 replica for Calypso
//  Port from MiST version Copyright (C) 2018 by Gyorgy Szombathelyi
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
//
//============================================================================

`default_nettype none

module zx8x
(
	input         CLK12M,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output [7:0]       LED,
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

	output [11:0] SDRAM_A,
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

assign LED[0] = ~ioctl_download & ~tape_ready;

`include "build_id.v"
localparam CONF_STR = 
{
	"ZX8X;;",
	"F,O  P  ,Load tape;",
	"O4,Model,ZX80,ZX81;",
	"OAB,RAM size,1k,16k,32k,64k;",
	"OC,CHR128 support,Off,On;",
	"O8,Swap joy axle,Off,On;",
	"O6,Video frequency,50Hz,60Hz;",
	"O7,Inverse video,Off,On;",
	"O9,Scanlines,Off,On;",
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////
wire clk_sys;
wire locked;

pll pll
(
	.inclk0(CLK12M),
	.c0(clk_sys), //52 MHz
	.locked(locked)
);

reg  ce_cpu_p;
reg  ce_cpu_n;
reg  ce_13,ce_65,ce_psg;

always @(posedge clk_sys) begin
	reg [4:0] counter = 0;

	if (reset) begin
		counter <= 5'h1f;
		ce_cpu_p <= 0;
		ce_cpu_n <= 0;
		ce_65 <= 0;
		ce_13 <= 0;
		ce_psg <= 0;
	end else begin
		counter  <=  counter + 1'd1;
		ce_cpu_p <= !counter[3] & !counter[2:0];
		ce_cpu_n <=  counter[3] & !counter[2:0];
		ce_65    <= !counter[2:0];
		ce_13    <= !counter[1:0];
		ce_psg   <= !counter[4:0];
	end
end

//////////////////   MIST ARM I/O   ///////////////////
wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;
wire [63:0] status;

wire        key_pressed;
wire  [7:0] key_code;
wire        key_strobe;
wire        key_extended;

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

user_io #(
	.STRLEN(($size(CONF_STR)>>3)),
	.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
	.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))
	)
(
	.clk_sys(clk_sys),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_CLK(SPI_SCK),
	.SPI_MOSI(SPI_DI),
	.SPI_MISO(SPI_DO),
	
	.conf_str(CONF_STR),

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

	.status(status),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.buttons(buttons),
	.switches(switches),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
    .key_strobe     (key_strobe     ),
    .key_pressed    (key_pressed    ),
    .key_code       (key_code       ),
    .key_extended   (key_extended   )
);

wire        ioctl_wr;
wire [13:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;

data_io  data_io (
      .clk_sys ( clk_sys ),
      // io controller spi interface
      .SPI_SCK ( SPI_SCK ),
      .SPI_SS2 ( SPI_SS2 ),
      .SPI_DI  ( SPI_DI  ),

      .ioctl_download ( ioctl_download ),  // signal indicating an active rom download

      // external ram interface
      .ioctl_index  ( ioctl_index ),
      .ioctl_wr     ( ioctl_wr    ),
      .ioctl_addr   ( ioctl_addr  ),
      .ioctl_dout   ( ioctl_dout  )
);

///////////////////   CPU   ///////////////////
wire [15:0] addr;
wire  [7:0] cpu_din;
wire  [7:0] cpu_dout;
wire        nM1;
wire        nMREQ;
wire        nIORQ;
wire        nRD;
wire        nWR;
wire        nRFSH;
wire        nHALT;
wire        nINT = addr[6];
wire        nNMI;
wire        nWAIT;
reg       	reset;

T80pa cpu
(
	.RESET_n(~reset),
	.CLK(clk_sys),
	.CEN_p(ce_cpu_p),
	.CEN_n(ce_cpu_n),
	.WAIT_n(nWAIT),
	.INT_n(nINT),
	.NMI_n(nNMI),
	.BUSRQ_n(1),
	.M1_n(nM1),
	.MREQ_n(nMREQ),
	.IORQ_n(nIORQ),
	.RD_n(nRD),
	.WR_n(nWR),
	.RFSH_n(nRFSH),
	.HALT_n(nHALT),
	.A(addr),
	.DO(cpu_dout),
	.DI(cpu_din)
);

wire [7:0] io_dout = kbd_n ? (psg_sel ? psg_out : 8'hFF) : { tape_in, hz50, 1'b0, key_data[4:0] & ({5{addr[12]}} | ~joykeys) };

always_comb begin
	case({nMREQ, ~nM1 | nIORQ | nRD})
	    'b01: cpu_din = (~nM1 & nopgen) ? 8'h0 : mem_out;
	    'b10: cpu_din = io_dout;
	 default: cpu_din = 8'hFF;
	endcase
end

wire       tape_in;
`ifdef USE_AUDIO_IN
assign tape_in = AUDIO_IN;
`else
assign tape_in = ~UART_RX;
`endif

reg        init_reset = 1;
reg        zx81;
reg  [1:0] mem_size; //00-1k, 01 - 16k 10 - 32k
wire       hz50 = ~status[6];
wire       joyrev = status[8];
wire [4:0] joykeys = joyrev ? {joystick_0[2], joystick_0[3], joystick_0[0], joystick_0[1], joystick_0[4]} :
										{joystick_0[1:0], joystick_0[2], joystick_0[3], joystick_0[4]};
reg [15:0] reset_cnt = 16'hFFFF;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= ioctl_download;
	if(~ioctl_download && old_download && !ioctl_index) init_reset <= 0;
	if(~ioctl_download && old_download && ioctl_index) tape_ready <= 1;

	reset <= (reset_cnt != 0);
	if (reset_cnt != 0) reset_cnt <= reset_cnt - 1'd1;
	if (buttons[1] | status[0] | (mod[1] & Fn[11]) | init_reset) reset_cnt <= 16'hFFFF;

	if (reset) begin
		zx81 <= status[4];
		mem_size <= status[11:10];
		tape_ready <= 0;
	end
end

//////////////////   MEMORY   //////////////////
assign SDRAM_CLK = clk_sys;

sdram ram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.wtbt(0),
	.dout(ram_out),
	.din (ram_in),
	.addr(ram_a),
	.we(ram_we | tapewrite_we),
	.rd(ram_e & (~nRFSH | (~nRD & ~nMREQ)) & ~ce_cpu_n & ~tapeloader),
	.ready(ram_ready)
);

wire        ram_ready;
reg   [7:0] rom[12288];
wire [12:0] rom_a  = nRFSH ? addr[12:0] : { addr[12:9], ram_data_latch[5:0], row_counter };
wire [15:0] tape_load_addr = 16'h4000 + ((ioctl_index[7:6] == 1) ? tape_addr + 4'd8 : tape_addr-1'd1);
wire [15:0] ram_a;
wire        ram_e_64k = &mem_size & (addr[13] | (addr[15] & nM1));
wire        rom_e  = ~addr[14] & (~addr[12] | zx81) & ~ram_e_64k & ~chr128_mem;
wire        ram_e  = addr[14] | ram_e_64k | chr128_mem;
wire        ram_we = ~nWR & ~nMREQ & ram_e;
wire  [7:0] ram_in = tapeloader ? tape_in_byte : cpu_dout;
wire  [7:0] rom_out;
wire  [7:0] ram_out;
wire  [7:0] mem_out;

wire        chr128 = status[12];
wire        chr128_mem = chr128 & (addr[15:12] == 4'h3);

always_comb begin
	casex({ tapeloader, rom_e, ram_e })
		'b110: mem_out = tape_loader_patch[addr - (zx81 ? 13'h0347 : 13'h0207)];
		'b010: mem_out = rom_out;
		'b001: mem_out = ram_out;
		default: mem_out = 8'd0;
	endcase

    casex({tapeloader, mem_size, chr128_mem })
        'b1_XX_X: ram_a = tape_load_addr;
        'b0_00_0: ram_a = { 6'b010000,             addr[9:0] }; //1k
        'b0_01_0: ram_a = { 2'b01,                addr[13:0] }; //16k
        'b0_10_0: ram_a = { 1'b0, addr[15] & nM1, addr[13:0] } + 16'h4000; //32k
        'b0_11_0: ram_a = { addr[15] & nM1,       addr[14:0] }; //64k
        'b0_XX_1: ram_a = nRFSH ? addr[15:0] : { addr[15:10], addr[8] & ram_data_latch[7], ram_data_latch[5:0], row_counter }; //chr
    endcase
end

always @(posedge clk_sys) begin
	if (ioctl_wr & !ioctl_index) begin
		rom[ioctl_addr] <= ioctl_dout;
	end
end

always @(posedge clk_sys) begin
	rom_out <= rom[{ (zx81 ? rom_a[12] : 2'h2), rom_a[11:0] }];
end

////////////////////  TAPE  //////////////////////
reg   [7:0] tape_ram[16384];
reg         tapeloader, tapewrite_we;
reg  [13:0] tape_addr;
reg   [7:0] tape_in_byte;
reg         tape_ready;  // there is data in the tape memory
// patch the load ROM routines to loop until the memory is filled from $4000(.o file ) $4009 (.p file)
// xor a; loop: nop or scf, jr nc loop, jp h0207 (jp h0203 - ZX80)
reg   [7:0] tape_loader_patch[7] = '{8'haf, 8'h00, 8'h30, 8'hfd, 8'hc3, 8'h07, 8'h02};

always @(posedge clk_sys) begin
	if (ioctl_wr & ioctl_index) begin
		tape_ram[ioctl_addr] <= ioctl_dout;
	end
end

always @(posedge clk_sys) begin
	tape_in_byte <= tape_ram[tape_addr];
end

always @(posedge clk_sys) begin
	reg old_nM1;
	
	old_nM1 <= nM1;
	tapewrite_we <= 0;
	
	if (~nM1 & old_nM1 & tape_ready) begin
		if (zx81) begin
			if (addr == 16'h0347) begin
				tape_loader_patch[1] <= 8'h00; //nop
				tape_loader_patch[5] <= 8'h07; //0207h
				tape_addr <= 14'h0;
				tapeloader <= 1;
			end
			if (addr >= 16'h03c3 || addr < 16'h0347) begin
				tapeloader <= 0;
			end
		end else begin
			if (addr == 16'h0207) begin
				tape_loader_patch[1] <= 8'h00; //nop
				tape_loader_patch[5] <= 8'h03; //0203h
				tape_addr <= 14'h0;
				tapeloader <= 1;
			end
			if (addr >= 16'h024d || addr < 16'h0207) begin
				tapeloader <= 0;
			end
		end
	end

	if (tapeloader & ce_cpu_p) begin
		if (tape_addr != ioctl_addr) begin
			tape_addr <= tape_addr + 1'h1;
			tapewrite_we <= 1;
		end else begin
			tape_loader_patch[1] <= 8'h37; //scf
		end
	end
end

////////////////////  VIDEO //////////////////////
// Based on the schematic:
// http://searle.hostei.com/grant/zx80/zx80.html

// character generation
wire      nopgen = addr[15] & ~mem_out[6] & nHALT;
wire      data_latch_enable = nRFSH & ce_cpu_n & ~nMREQ;
reg [7:0] ram_data_latch;
reg       nopgen_store;
reg [2:0] row_counter;
wire      shifter_start = nMREQ & nopgen_store & (~zx81 | ~NMIlatch);
reg [7:0] shifter_reg;
wire      video_out = (~status[7] ^ shifter_reg[7] ^ inverse) & !back_porch_counter & csync;
reg       inverse;

reg[4:0]  back_porch_counter = 1;

always @(posedge clk_sys) begin
	reg old_csync;
	reg old_shifter_start;
	
	old_csync <= csync;

	if (data_latch_enable) begin
		ram_data_latch <= mem_out;
		nopgen_store <= nopgen;
	end

	if (nMREQ & ce_cpu_p) inverse <= 0;

	if (ce_cpu_p) old_shifter_start <= shifter_start;
	if (ce_cpu_p & ~old_shifter_start & shifter_start) begin
		shifter_reg <= (~nM1 & nopgen) ? 8'h0 : mem_out;
		inverse <= ram_data_latch[7];
	end else if (ce_65) begin
		shifter_reg <= { shifter_reg[6:0], 1'b0 };
	end

	if (old_csync & ~csync)	row_counter <= row_counter + 1'd1;
	if (~vsync) row_counter <= 0;

	if (~old_csync & csync) back_porch_counter <= 1;
	if (ce_65 && back_porch_counter) back_porch_counter <= back_porch_counter + 1'd1;

	end

// ZX80 sync generator
reg ic11,ic18,ic19_1,ic19_2;
//wire csync = ic19_2; //ZX80 original
wire csync = zx81 ? vsync & hsync : ic19_2;
wire vsync = ic11;

always @(posedge clk_sys) begin

	reg old_nM1;
	old_nM1 <= nM1;

	if (~(nIORQ | nWR) & (~zx81 | ~NMIlatch)) ic11 <= 1; // stop vsync - any OUT
	if (~kbd_n & (~zx81 | ~NMIlatch)) ic11 <= 0; // start vsync - keyboard IN

	if (~nIORQ) ic18 <= 1;  // if IORQ - preset HSYNC start
	if (~ic19_2) ic18 <= 0; // if sync active - preset sync end

	// And 2 M1 later the presetted sync arrives at the csync pin
	if (old_nM1 & ~nM1) begin
		ic19_1 <= ~ic18;
		ic19_2 <= ic19_1;
	end
	if (~ic11) ic19_2 <= 0; //vsync keeps csync low
end

// ZX81 upgrade
// http://searle.hostei.com/grant/zx80/zx80nmi.html

wire      hsync = ~(sync_counter >= 16 && sync_counter <= 31);
reg       NMIlatch;
reg [7:0] sync_counter = 0;

assign nWAIT = ~(nHALT & ~nNMI) | ~zx81;
assign nNMI = ~(NMIlatch & ~hsync) | ~zx81;

always @(posedge clk_sys) begin
	if (ce_cpu_n) begin
		sync_counter <= sync_counter + 1'd1;
		if (sync_counter == 8'd206 | (~nM1 & ~nIORQ)) sync_counter <= 0;
	end

	if (zx81) begin
		if (~nIORQ & ~nWR & (addr[0] ^ addr[1])) NMIlatch <= addr[1];
	end
end

wire       v_sd_out, HS_sd_out, VS_sd_out, BL_sd_out;

zxscandoubler zxscandoubler
(
	.clk(clk_sys),
	.ce_2pix(ce_13),

	.scanlines(status[9]),

	.csync(csync),
	.v_in(video_out),

	.hs_out(HS_sd_out),
	.vs_out(VS_sd_out),
	.blank_out(BL_sd_out),    
	.v_out(v_sd_out)
);

wire [7:0] R_out,G_out,B_out;
osd #(.OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD)) osd
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),

	.R_in((scandoubler_disable ? video_out : v_sd_out) ? 8'hFF : 8'd0),
	.G_in((scandoubler_disable ? video_out : v_sd_out) ? 8'hFF : 8'd0),
	.B_in((scandoubler_disable ? video_out : v_sd_out) ? 8'hFF : 8'd0),

	.R_out(R_out),
	.G_out(G_out),
	.B_out(B_out),
	.HSync(scandoubler_disable ? hsync : HS_sd_out),
	.VSync(scandoubler_disable ? vsync : VS_sd_out)
);

wire [7:0] y, pb, pr;
wire       hs_out, vs_out, cs_out;
RGBtoYPbPr #(8) RGBtoYPbPr
(
	.clk       ( clk_sys ),
	.ena       ( ypbpr   ),
	.red_in    ( R_out   ),
	.green_in  ( G_out   ),
	.blue_in   ( B_out   ),
	.hs_in     ( scandoubler_disable ? hsync : HS_sd_out ),
	.vs_in     ( scandoubler_disable ? vsync : VS_sd_out ),
	.cs_in     ( csync   ),
	.red_out   ( y       ),
	.green_out ( pb      ),
	.blue_out  ( pr      ),
	.hs_out    ( hs_out  ),
	.vs_out    ( vs_out  ),
	.cs_out    ( cs_out  )
);

assign VGA_HS = ((scandoubler_disable & !no_csync) || ypbpr) ? cs_out : hs_out;
assign VGA_VS = ((scandoubler_disable & !no_csync) || ypbpr) ? 1'd1 : vs_out;
assign VGA_R = pr[7:8-VGA_BITS];
assign VGA_G = y[7:8-VGA_BITS];
assign VGA_B = pb[7:8-VGA_BITS];

`ifdef USE_HDMI
i2c_master #(56_000_000) i2c_master (
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

osd #(.OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD)) osd_hdmi
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.SPI_DI(SPI_DI),

	.R_in(v_sd_out ? 8'hFF : 8'd0),
	.G_in(v_sd_out ? 8'hFF : 8'd0),
	.B_in(v_sd_out ? 8'hFF : 8'd0),
	
	.R_out(HDMI_R),
	.G_out(HDMI_G),
	.B_out(HDMI_B),
	.HSync(HS_sd_out),
	.VSync(VS_sd_out)
);

assign HDMI_HS = HS_sd_out;
assign HDMI_VS = VS_sd_out;
assign HDMI_DE = !BL_sd_out;
assign HDMI_PCLK = clk_sys;
`endif

////////////////////  SOUND //////////////////////
wire [7:0] psg_out;
wire       psg_sel = ~nIORQ & &addr[3:0]; //xF
wire [7:0] psg_ch_a, psg_ch_b, psg_ch_c;

YM2149 psg
(
	.CLK(clk_sys),
	.CE(ce_psg),
	.RESET(reset),
	.BDIR(psg_sel & ~nWR),
	.BC(psg_sel & (&addr[7:6] ^ nWR)),
	.DI(cpu_dout),
	.DO(psg_out),
	.CHANNEL_A(psg_ch_a),
	.CHANNEL_B(psg_ch_b),
	.CHANNEL_C(psg_ch_c)
);

// Route vsync through a high-pass filter to filter out sync signals from the
// tape audio
wire [7:0] mic_out;
wire       mic_bit = mic_out > 8'd8 && mic_out < 8'd224;

rc_filter_1o #(
	.R_ohms_g(33000),
	.C_p_farads_g(47000),
	.fclk_hz_g(6500000),
	.cwidth_g(18)) mic_filter
(
	.clk_i(clk_sys),
	.clken_i(ce_65),
	.res_i(reset),
	.din_i({1'b0, vsync, 6'd0 }),
	.dout_o(mic_out)
);

wire [8:0] audio_l = { 1'b0, psg_ch_a } + { 1'b0, psg_ch_c } + { mic_bit, 4'd0 };
wire [8:0] audio_r = { 1'b0, psg_ch_b } + { 1'b0, psg_ch_c } + { mic_bit, 4'd0 };

sigma_delta_dac #(7) dac_l
(
	.CLK(clk_sys),
	.RESET(reset),
	.DACin(audio_l[8:1]),
	.DACout(AUDIO_L)
);

sigma_delta_dac #(7) dac_r
(
	.CLK(clk_sys),
	.RESET(reset),
	.DACin(audio_r[8:1]),
	.DACout(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd56_000_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({1'b0, audio_l, 6'd0}),
	.right_chan({1'b0, audio_r, 6'd0})
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
	.clk_rate_i(32'd56_000_000),
	.spdif_o(SPDIF),
	.sample_i({1'b0, audio_r, 6'd0, 1'b0, audio_l, 6'd0})
);
`endif
////////////////////   HID   /////////////////////

wire kbd_n = nIORQ | nRD | addr[0];

wire [11:1] Fn;
wire  [2:0] mod;
wire  [4:0] key_data;

keyboard kbd( .* );

endmodule
