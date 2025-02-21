// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

`timescale 1ns / 1ps

module NES_calypso(
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
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

// the configuration string is returned to the io controller to allow
// it to control the menu on the OSD 
parameter CONF_STR = {
			"NES;NESFDSNSF;",
			"F2,BIN,Load FDS BIOS;",
			"S0,SAV,Mount SRAM;",
			"TH,Write SRAM;",
			`SEP
			"O12,System Type,NTSC,PAL,Dendy;",
			"O34,Scanlines,OFF,25%,50%,75%;",
			"O5,Joystick swap,OFF,ON;",
			"O6,Invert mirroring,OFF,ON;",
			"O7,Hide overscan,OFF,ON;",
			"OG,Blend,OFF,ON;",
			"OCF,Palette,Digital Prime,Smooth,Unsat.,FCEUX,NES Classic,Composite,PC-10,PVM,Wavebeam,Real,Sony CXA,YUV,Greyscale,Rockman9,Ninten.;",
			`SEP
			"O8,Famicon keyboard,OFF,ON;",
			"O9B,Disk side,Auto,A,B,C,D;",
			`SEP
			"T0,Reset;",
			"V,v2.0-",`BUILD_DATE
};

wire [31:0] status;

wire arm_reset = status[0];
wire [1:0] system_type = status[2:1];
wire pal_video = |system_type;
wire [1:0] scanlines = status[4:3];
wire joy_swap = status[5];
wire mirroring_osd = status[6];
wire overscan_osd = status[7];
wire famicon_kbd = status[8];
wire [3:0] palette_osd = status[15:12];
wire [2:0] diskside_osd = status[11:9];
wire blend = status[16];
wire bk_save = status[17];

wire scandoubler_disable;
wire ypbpr;
wire no_csync;

wire [31:0] core_joy_A;
wire [31:0] core_joy_B;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_rd;
wire        sd_buff_wr;
wire  [1:0] img_mounted;
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

user_io #(.STRLEN($size(CONF_STR)>>3), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io(
	.clk_sys(clk),
	.clk_sd(clk),
	.conf_str(CONF_STR),
	// the spi interface

	.SPI_CLK(SPI_SCK),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_MISO(SPI_DO),   // tristate handling inside user_io
	.SPI_MOSI(SPI_DI),

	.switches(switches),
	.buttons(buttons),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
`ifdef USE_HDMI
	.i2c_start      ( i2c_start      ),
	.i2c_read       ( i2c_read       ),
	.i2c_addr       ( i2c_addr       ),
	.i2c_subaddr    ( i2c_subaddr    ),
	.i2c_dout       ( i2c_dout       ),
	.i2c_din        ( i2c_din        ),
	.i2c_ack        ( i2c_ack        ),
	.i2c_end        ( i2c_end        ),
`endif
	.joystick_0(core_joy_A),
	.joystick_1(core_joy_B),

	.status(status),

	.key_strobe(key_strobe),
	.key_pressed(key_pressed),
	.key_extended(key_extended),
	.key_code(key_code),

	.sd_conf(0),
	.sd_sdhc(1),
	.sd_lba(sd_lba),
	.sd_rd({1'b0, sd_rd}),
	.sd_wr({1'b0, sd_wr}),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout_strobe(sd_buff_wr),
	.sd_dout(sd_buff_dout),
	.sd_din_strobe(sd_buff_rd),
	.sd_din(sd_buff_din),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

// 27e6/2^20 = ~25.7hz
reg [19:0] turbo_cnt = 0;
always @(posedge clk) begin
    turbo_cnt <= turbo_cnt + 1'd1;
end

// Y/X act as turbo B/A buttons
wire [5:4] joyA_t = {turbo_cnt[19],turbo_cnt[19]} & (joy_swap ? core_joy_B[9:8] : core_joy_A[9:8]);
wire [5:4] joyB_t = {turbo_cnt[19],turbo_cnt[19]} & (joy_swap ? core_joy_A[9:8] : core_joy_B[9:8]);

wire [7:0] joyA = joy_swap ? core_joy_B[7:0] | core_joy_A[19:16] : core_joy_A[7:0] | core_joy_B[19:16];
wire [7:0] joyB = joy_swap ? core_joy_A[7:0] | core_joy_B[19:16] : core_joy_B[7:0] | core_joy_A[19:16];

reg kbd_select;
reg kbd_start;
always @(posedge clk) begin
	if (key_strobe) begin
        if (!key_extended) begin
            case(key_code) 
                8'h05: kbd_select <= key_pressed; // F1
                8'h06: kbd_start  <= key_pressed; // F2
            endcase
        end
    end
end

wire [7:0] nes_joy_A = { joyA[0], joyA[1], joyA[2], joyA[3], joyA[7] | kbd_select, joyA[6] | kbd_start, joyA[5] | joyA_t[5], joyA[4] | joyA_t[4] };
wire [7:0] nes_joy_B = { joyB[0], joyB[1], joyB[2], joyB[3], joyB[7], joyB[6], joyB[5] | joyB_t[5], joyB[4] | joyB_t[4] };
 
  wire clock_locked;
  wire clk85;
  wire clk;
	wire clk_x2;
  clk clock_21mhz(
    .inclk0(CLK12M),
    .c0(clk85),
    .c1(clk),
`ifdef USE_HDMI
    .c2(clk_x2),
`endif
    .locked(clock_locked));
  assign SDRAM_CLK = clk85;
  assign SDRAM_CKE = 1;

  // reset after download
  reg [7:0] download_reset_cnt;
  wire download_reset = download_reset_cnt != 0;
  always @(posedge clk) begin
	if(downloading)
		download_reset_cnt <= 8'd255;
	else if(!loader_busy && download_reset_cnt != 0)
		download_reset_cnt <= download_reset_cnt - 8'd1;
 end

  // hold machine in reset until first download starts
  reg init_reset = 1;
  always @(posedge clk) begin
	if(downloading)	init_reset <= 1'b0;
  end
  
  wire [8:0] cycle;
  wire [8:0] scanline;
  wire [15:0] sample;
  wire [5:0] color;
  wire [2:0] joypad_out;
  wire joypad_strobe = joypad_out[0];
  wire [1:0] joypad_clock;
  wire [4:0] joypad1_data, joypad2_data;
  wire [21:0] memory_addr_cpu, memory_addr_ppu;
  wire memory_read_cpu, memory_read_ppu;
  wire memory_write_cpu, memory_write_ppu;
  wire [7:0] memory_din_cpu, memory_din_ppu;
  wire [7:0] memory_dout_cpu, memory_dout_ppu;
  reg [7:0] joypad_bits, joypad_bits2;
  reg [7:0] powerpad_d3, powerpad_d4;
  reg [1:0] last_joypad_clock;
  wire [31:0] dbgadr;
  wire [1:0] dbgctr;

  wire [1:0] nes_ce;
  wire mic = 0;
  
wire [11:0] powerpad;
wire [3:0] key_out;
wire fds_eject;

keyboard keyboard (
	.clk(clk),
	.reset(reset_nes),
	.posit(1'b1),
	.key_strobe(key_strobe),
	.key_pressed(key_pressed),
	.key_extended(key_extended),
	.key_code(key_code),
	.reg_4016(joypad_out),
	.reg_4017(key_out),
	.powerpad(powerpad),
	.fds_eject(fds_eject)
);

	always @(posedge clk) begin
		if (reset_nes) begin
			joypad_bits <= 8'd0;
			joypad_bits2 <= 8'd0;
			powerpad_d3 <= 8'd0;
			powerpad_d4 <= 8'd0;
			last_joypad_clock <= 2'b00;
		end else begin
			if (joypad_strobe) begin
				joypad_bits <= nes_joy_A;
				joypad_bits2 <= nes_joy_B;
				powerpad_d4 <= {4'b0000, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
				powerpad_d3 <= {powerpad[6], powerpad[10], powerpad[9], powerpad[5], powerpad[8], powerpad[4], powerpad[0], powerpad[1]};
			end
			if (!joypad_clock[0] && last_joypad_clock[0]) begin
				joypad_bits <= {1'b0, joypad_bits[7:1]};
			end	
			if (!joypad_clock[1] && last_joypad_clock[1]) begin
				joypad_bits2 <= {1'b0, joypad_bits2[7:1]};
				powerpad_d4 <= {1'b0, powerpad_d4[7:1]};
				powerpad_d3 <= {1'b0, powerpad_d3[7:1]};
			end	
			last_joypad_clock <= joypad_clock;
		end
	end

	assign joypad1_data = {2'b0, mic, 1'b0, joypad_bits[0]};
	assign joypad2_data = {famicon_kbd ? key_out : {powerpad_d4[0],powerpad_d3[0], 2'b00}, joypad_bits2[0]};
	
  // Loader
  wire [7:0] loader_input =  (loader_busy && !downloading) ? nsf_data : ioctl_dout;
  wire       loader_clk;
  wire [21:0] loader_addr;
  wire [7:0] loader_write_data;
  wire loader_reset = !download_reset; //loader_conf[0];
  wire loader_write;
  wire [63:0] loader_flags;
  reg  [63:0] mapper_flags;
  wire loader_done, loader_fail;
	wire loader_busy;
	wire type_bios = (menu_index == 2);
	wire is_bios = 0;//type_bios;
	wire type_nes = (menu_index == 0) || (menu_index == {2'd0, 6'h1});
	wire type_fds = (menu_index == {2'd1, 6'h1});
	wire type_nsf = (menu_index == {2'd2, 6'h1});

GameLoader loader
(
	.clk              ( clk               ),
	.reset            ( loader_reset      ),
	.downloading      ( downloading       ),
	.filetype         ( {4'b0000, type_nsf, type_fds, type_nes, type_bios} ),
	.is_bios          ( is_bios           ),
	.indata           ( loader_input      ),
	.indata_clk       ( loader_clk        ),
	.invert_mirroring ( mirroring_osd     ),
	.mem_addr         ( loader_addr       ),
	.mem_data         ( loader_write_data ),
	.mem_write        ( loader_write      ),
	.bios_download    (                   ),
	.mapper_flags     ( loader_flags      ),
	.busy             ( loader_busy       ),
	.done             ( loader_done       ),
	.error            ( loader_fail       ),
	.rom_loaded       (                   )
);

  always @(posedge clk)
	if (loader_done)
    mapper_flags <= loader_flags;
	 
	// LED displays loader status
	reg [23:0] led_blink;	// divide 21MHz clock to around 1Hz
	always @(posedge clk) begin
		led_blink <= led_blink + 13'd1;
	end

// Loopy's NSF player ROM
reg [7:0] nsf_player [4096];
reg [7:0] nsf_data;
initial begin
  $readmemh("nes/nsf.hex", nsf_player);
end
always @(posedge clk) nsf_data <= nsf_player[loader_addr[11:0]];

assign LED[0] = downloading ? 1'b0 : loader_fail ? led_blink[23] : ~bk_ena;

wire reset_nes = (init_reset || buttons[1] || arm_reset || download_reset || loader_fail);

wire ext_audio = 1;
wire int_audio = 1;

wire [1:0] diskside_req;
wire [1:0] diskside = (diskside_osd == 0) ? diskside_req : (diskside_osd - 1'd1);

NES nes(
	.clk(clk),
	.reset_nes(reset_nes),
	.cold_reset(downloading & (type_fds | type_nes)),
	.sys_type(system_type),
	.nes_div(nes_ce),
	.mapper_flags(mapper_flags),
	.sample(sample),
	.color(color),
	.joypad_out(joypad_out),
	.joypad_clock(joypad_clock),
	.joypad1_data(joypad1_data),
	.joypad2_data(joypad2_data),
	.fds_busy(),
	.fds_eject(fds_eject),
	.diskside_req(diskside_req),
	.diskside(diskside),
	.audio_channels(5'b11111),  // enable all channels
	.cpumem_addr(memory_addr_cpu),
	.cpumem_read(memory_read_cpu),
	.cpumem_din(memory_din_cpu),
	.cpumem_write(memory_write_cpu),
	.cpumem_dout(memory_dout_cpu),
	.ppumem_addr(memory_addr_ppu),
	.ppumem_read(memory_read_ppu),
	.ppumem_write(memory_write_ppu),
	.ppumem_din(memory_din_ppu),
	.ppumem_dout(memory_dout_ppu),
	.cycle(cycle),
	.scanline(scanline),
	.int_audio(int_audio),
	.ext_audio(ext_audio)
);

// loader_write -> clock when data available
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [21:0] loader_addr_mem;

reg loader_write_triggered;

always @(posedge clk) begin
	if(loader_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
		loader_write_data_mem <= loader_write_data;
	end

	// signal write in the PPU memory phase
	if(nes_ce == 3) begin
		loader_write_mem <= loader_write_triggered | loader_write;
		loader_write_triggered <= 1'b0;
	end
end

sdram sdram (
	.SDRAM_DQ       ( SDRAM_DQ                 ),
	.SDRAM_A        ( SDRAM_A                  ),
	.SDRAM_DQML     ( SDRAM_DQML               ),
	.SDRAM_DQMH     ( SDRAM_DQMH               ),
	.SDRAM_nCS      ( SDRAM_nCS                ),
	.SDRAM_BA       ( SDRAM_BA                 ),
	.SDRAM_nWE      ( SDRAM_nWE                ),
	.SDRAM_nRAS     ( SDRAM_nRAS               ),
	.SDRAM_nCAS     ( SDRAM_nCAS               ),

	// system interface
	.clk            ( clk85                    ),
	.init_n         ( clock_locked             ),
	.clkref         ( nes_ce[1]               ),

	// PPU
	.addrA          ( memory_addr_ppu ),
	.weA            ( memory_write_ppu ),
	.dinA           ( memory_dout_ppu ),
	.oeA            ( memory_read_ppu ),
	.doutA          ( memory_din_ppu  ),

	// CPU
	.addrB     	    ( (downloading | loader_busy) ? loader_addr_mem : memory_addr_cpu ),
	.weB            ( loader_write_mem || memory_write_cpu ),
	.dinB           ( (downloading | loader_busy) ? loader_write_data_mem : memory_dout_cpu ),
	.oeB            ( ~(downloading | loader_busy) & memory_read_cpu ),
	.doutB          ( memory_din_cpu  ),

	// IO-Controller
	.addrC          ( {4'b1111, sd_lba[8:0], sram_a} ),
	.oeweC          ( sram_req ),
	.weC            ( sram_we ),
	.dinC           ( sd_buff_dout ),
	.doutC          ( sd_buff_din )
);

wire downloading;
wire [7:0] menu_index;
wire [7:0] ioctl_dout;

data_io data_io (
	.clk_sys        ( clk          ),

	.SPI_SCK        ( SPI_SCK      ),
	.SPI_SS2        ( SPI_SS2      ),
	.SPI_DI         ( SPI_DI       ),

	.ioctl_download ( downloading  ),
	.ioctl_index    ( menu_index   ),

   // ram interface
	.ioctl_wr       ( loader_clk   ),
	.ioctl_dout     ( ioctl_dout )
);

wire nes_hs, nes_vs;
wire nes_hb, nes_vb;
wire [7:0] nes_r;
wire [7:0] nes_g;
wire [7:0] nes_b;

video video (
	.clk(clk),
	.color(color),
	.count_v(scanline),
	.count_h(cycle),
	.pal_video(pal_video),
	.overscan(overscan_osd),
	.palette(palette_osd),

	.sync_h(nes_hs),
	.sync_v(nes_vs),
	.hblank(nes_hb),
	.vblank(nes_vb),
	.r(nes_r),
	.g(nes_g),
	.b(nes_b)
);

mist_video #(.COLOR_DEPTH(8), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .BIG_OSD(BIG_OSD), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS)) mist_video (
	.clk_sys     ( clk        ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 3'd1       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( scandoubler_disable ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( blend      ),

	// video in
	.R           ( nes_r      ),
	.G           ( nes_g      ),
	.B           ( nes_b      ),

	.HSync       ( ~nes_hs    ),
	.VSync       ( ~nes_vs    ),
	.HBlank      ( nes_hb     ),
	.VBlank      ( nes_vb     ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(21_500_000) i2c_master (
	.CLK         (clk),
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

mist_video #(.COLOR_DEPTH(8), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .BIG_OSD(BIG_OSD), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(8)) hdmi_video (
	.clk_sys     ( clk_x2     ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 3'd0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( scandoubler_disable ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( blend      ),

	// video in
	.R           ( nes_r      ),
	.G           ( nes_g      ),
	.B           ( nes_b      ),

	.HSync       ( ~nes_hs    ),
	.VSync       ( ~nes_vs    ),
	.HBlank      ( nes_hb     ),
	.VBlank      ( nes_vb     ),

	// MiST video output signals
	.VGA_R       ( HDMI_R     ),
	.VGA_G       ( HDMI_G     ),
	.VGA_B       ( HDMI_B     ),
	.VGA_VS      ( HDMI_VS    ),
	.VGA_HS      ( HDMI_HS    ),
	.VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_x2;

`endif

assign AUDIO_R = audio;
assign AUDIO_L = audio;
wire audio;
sigma_delta_dac sigma_delta_dac (
	.DACout(audio),
	.DACin(sample[15:8]),
	.CLK(clk),
	.RESET(reset_nes)
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk85),
	.clk_rate(32'd85_910_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({~sample[15], sample[14:0]}),
	.right_chan({~sample[15], sample[14:0]})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk85) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk85),
	.rst_i(1'b0),
	.clk_rate_i(32'd85_910_000),
	.spdif_o(SPDIF),
	.sample_i({2{~sample[15], sample[14:0]}})
);
`endif

// SRAM handling

reg         sram_we;
reg         sram_req;
wire        sram_ack;
reg         bk_ena;
reg         bk_load;
reg         bk_state;
reg         bk_loading;
reg  [11:0] sav_size;
reg   [8:0] sram_a;

always @(posedge clk) begin

	reg img_mountedD;
	reg downloadingD;
	reg bk_loadD, bk_saveD;
	reg sd_ackD;

	bk_load <= 0;
	img_mountedD <= img_mounted[0];
	if (~img_mountedD & img_mounted[0]) begin
		if (|img_size) begin
			bk_ena <= 1;
			sav_size <= img_size[20:9];
			bk_load <= 1;
		end else begin
			bk_ena <= 0;
		end
	end

	downloadingD <= downloading;
	if (~downloadingD & downloading) bk_ena <= 0;

	bk_loadD <= bk_load;
	bk_saveD <= bk_save;
	sd_ackD  <= sd_ack;

	if (~sd_ackD & sd_ack) { sd_rd, sd_wr } <= 2'b00;

	case (bk_state)
	0:	if (bk_ena && ((~bk_loadD & bk_load) || (~bk_saveD & bk_save))) begin
			bk_state <= 1;
			sd_lba <= 0;
			bk_loading <= bk_load;
			sd_rd <= bk_load;
			sd_wr <= ~bk_load;
		end
	1:	if (sd_ackD & ~sd_ack) begin
			if (sd_lba[11:0] == sav_size) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <= bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	endcase
end

always @(negedge clk) begin

	if (sd_buff_wr | sd_buff_rd) begin
		sram_we <= sd_buff_wr;
		sram_req <= ~sram_req;
		sram_a <= sd_buff_addr;
	end;

end

endmodule
