module ti994a_calypso(
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

`include "build_id.v"

localparam CONF_STR =
{
    "TI994A;;",
    "F1,C  D  G  ,Load;",
    "F2,BIN,Load Full or C.bin;",
    "F3,BIN,Load D.bin;",
    "F4,BIN,Load G.bin;",
    "S0U,DSK,Drive 1;",
    "S1U,DSK,Drive 2;",
    "OD,Cart Type,Normal,MBX;",
    "OE,Scratchpad RAM,256B,1KB;",
    "OA,Turbo,Off,On;",
    "OGH,Speech,Off,5220,5200;",
    "O6,Joystick swap,Off,On;",
    "O23,Scanlines,Off,25%,50%,75%;",
    "O5,Blend,Off,On;",
    "T0,Reset;",
    "V,v",`BUILD_DATE
};

wire  [1:0] scanlines = status[3:2];
wire        blend = status[5];
wire        joyswap = status[6];
wire        turbo = status[10];
wire        scratch1k = status[14];

assign LED[0] = ~downl;
assign UART_TX = 1;

wire clk_mem, clk_sys, pll_locked;
assign SDRAM_CLK = clk_mem;
assign SDRAM_CKE = 1;

pll pll (
    .inclk0(CLK12M),
    .c0(clk_mem), // 84 MHz
    .c1(clk_sys), // 42 MHz
    .locked(pll_locked)
);

wire ear_input;

`ifdef USE_AUDIO_IN
reg ainD;
reg ainD2;
always @(posedge clk_sys) begin
	ainD <= AUDIO_IN;
	ainD2 <= ainD;
end
assign ear_input = ainD2;
`else
reg uart_rxD;
reg uart_rxD2;

// UART_RX synchronizer
always @(posedge clk_sys) begin
	uart_rxD <= UART_RX;
	uart_rxD2 <= uart_rxD;
end

assign ear_input = uart_rxD2;
`endif

wire [63:0] status;
wire [15:0] joy0;
wire [15:0] joy1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;
wire        key_strobe;
wire        key_pressed;
wire  [7:0] key_code;

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire  [8:0] sd_buff_addr;
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

user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(2), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
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
    .switches(switches),
    .joystick_0(joy0),
    .joystick_1(joy1),
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_code(key_code),

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

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_dout(sd_dout),
    .sd_dout_strobe(sd_dout_strobe),
    .sd_din(sd_din),
    .sd_buff_addr(sd_buff_addr),
    .sd_conf(0),
    .sd_sdhc(1),
    .img_mounted(img_mounted),
    .img_size(img_size)
);

wire [24:0] romwr_a;
wire        clkref;
wire        downl;
wire  [7:0] index;
wire        rom_wr;
wire  [7:0] ioctl_dout;

data_io data_io_inst (
    .clk_sys(clk_mem),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    //'1',
    .SPI_DI(SPI_DI),
    //'1',
    .clkref_n(~clkref),
    .ioctl_download(downl),
    .ioctl_index(index),
    .ioctl_wr(rom_wr),
    .ioctl_addr(romwr_a),
    .ioctl_dout(ioctl_dout)
);
    
reg        reset;
wire       por_n;
wire       force_reset;
reg  [1:0] clk_cnt;
reg        clk_en_10m7;

always @(posedge clk_sys) begin
	if (reset) begin
		clk_cnt <= 0;
		clk_en_10m7 <= 0;
	end else begin
		clk_cnt <= clk_cnt + 1'd1;
	end

	if (clk_cnt == 1)
		clk_en_10m7 <= 1;
	else
		clk_en_10m7 <= 0;
end

always @(posedge clk_sys)
	reset <= status[0] || buttons[1] || force_reset || ~pll_locked;

//-----------------------------------------------------------------------------
//-- The TI99/4A module
//-----------------------------------------------------------------------------

wire  [7:0] red,green,blue;
wire        hs, vs, hb, vb;
wire [10:0] unsigned_audio;

wire  [8:0] kbd_i;
wire  [7:0] kbd_o;
wire  [6:1] rommask;

wire [14:0] speech_rom_a;
wire  [7:0] speech_rom_d;

wire [18:0] cpu_ram_a;
wire        cpu_ram_ce_n;
wire        cpu_ram_we_n;
wire [15:0] cpu_ram_d_to_ti;
wire [15:0] cpu_ram_d_from_ti;
wire  [1:0] cpu_ram_be_n;

wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_d_to_cv;
wire  [7:0] vram_d_from_cv;
  
ep994a #(.is_pal_g(0), .compat_rgb_g(0)) ti994a
(
    .clk_i           ( clk_sys ),
    .clk_en_10m7_i   ( clk_en_10m7 ),
    .reset_n_i       ( ~reset ),
    .por_n_o         ( por_n ),

    .epGPIO_i        ( kbd_o ),
    .epGPIO_o        ( kbd_i ),

    .cpu_ram_a_o     ( cpu_ram_a ),
    .cpu_ram_ce_n_o  ( cpu_ram_ce_n ),
    .cpu_ram_we_n_o  ( cpu_ram_we_n ),
    .cpu_ram_be_n_o  ( cpu_ram_be_n ),
    .cpu_ram_d_i     ( cpu_ram_d_to_ti ),
    .cpu_ram_d_o     ( cpu_ram_d_from_ti ),

    .vram_a_o        ( vram_a ),
    .vram_we_o       ( vram_we ),
    .vram_d_o        ( vram_d_from_cv ),
    .vram_d_i        ( vram_d_to_cv ),

    .rgb_r_o         ( red ),
    .rgb_g_o         ( green ),
    .rgb_b_o         ( blue ),
    .hsync_n_o       ( hs ),
    .vsync_n_o       ( vs ),
    .hblank_o        ( hb ),
    .vblank_o        ( vb ),
    .audio_total_o   ( unsigned_audio ),

    .speech_model    ( ~status[17:16] ),
    .sr_re_o         ( ),
    .sr_addr_o       ( speech_rom_a ),
    .sr_data_i       ( speech_rom_d ),

    .sd_lba          ( sd_lba ),
    .sd_rd           ( sd_rd ),
    .sd_wr           ( sd_wr ),
    .sd_ack          ( sd_ack ),
    .sd_dout         ( sd_dout ),
    .sd_dout_strobe  ( sd_dout_strobe ),
    .sd_din          ( sd_din ),
    .sd_buff_addr    ( sd_buff_addr ),
    .img_mounted     ( img_mounted ),
    .img_size        ( img_size[31:0] ),
    .img_wp          ( 2'b00 ),

    .rommask_i       ( rommask ),
    .scratch_1k_i    ( scratch1k ),
    .mbx_i           ( 1'b0/*--status(13)*/ ),
    .flashloading_i  ( downl ),
    .turbo_i         ( turbo )
);

TI994A_keyboard keyboard
(
    .clk_sys           ( clk_sys ),
    .key_strobe        ( key_strobe ),
    .key_pressed       ( key_pressed ),
    .key_code          ( key_code ),
    .joy_swap          ( joyswap ),
    .joy0              ( joy0[15:0] ),
    .joy1              ( joy1[15:0] ),
    .keyboardSignals_i ( kbd_i ),
    .keyboardSignals_o ( kbd_o )
);

//-----------------------------------------------------------------------------
//-- SPEECH ROM
//-----------------------------------------------------------------------------
sprom #(.widthad_a(15), .init_file("../../../roms/hex/spchrom.hex")) speech_rom
(
    .clock       ( clk_sys ),
    .address     ( speech_rom_a ),
    .q           ( speech_rom_d )
);

//-----------------------------------------------------------------------------
//-- VRAM
//-----------------------------------------------------------------------------
  
spram #(.widthad_a(14)) vram_b
(
    .clock     ( clk_sys ),
    .wren      ( vram_we ),
    .address   ( vram_a ),
    .data      ( vram_d_from_cv ),
    .q         ( vram_d_to_cv )
);

//-----------------------------------------------------------------------------
//-- SDRAM
//-----------------------------------------------------------------------------

//---------------------------------------------------------
//-- 00000..7FFFF - Cartridge module port, paged, 512K, to support the TI megademo :)
//-- 80000..8FFFF - GROM mapped to this area, 64K (was at 30000)
//-- 90000..AFFFF - Not used currently
//-- B0000..B7FFF - DSR area, 32K reserved	(was at 60000)
//-- B8000..B8FFF - Scratchpad 	(was at 68000)
//-- BA000..BCFFF - Boot ROM remapped (was at 0)   
//-- C0000..FFFFF - SAMS SRAM 256K (i.e. the "normal" CPU RAM paged with the SAMS system)
//---------------------------------------------------------

wire        ram_rd, ram_we;
reg         sdram_req, sdram_we;
wire [24:0] sdram_addr;
wire  [1:0] sdram_bs;
wire [15:0] sdram_dout;
wire [15:0] sdram_din;

sdram ext_ram_rom
(
    .SDRAM_DQ    ( SDRAM_DQ ),
    .SDRAM_A     ( SDRAM_A ),
    .SDRAM_DQML  ( SDRAM_DQML ),
    .SDRAM_DQMH  ( SDRAM_DQMH ),
    .SDRAM_BA    ( SDRAM_BA ),
    .SDRAM_nCS   ( SDRAM_nCS ),
    .SDRAM_nWE   ( SDRAM_nWE ),
    .SDRAM_nRAS  ( SDRAM_nRAS ),
    .SDRAM_nCAS  ( SDRAM_nCAS ),

    .init_n      ( pll_locked ),
    .clk         ( clk_mem ),

    .port1_req   ( sdram_req ),
    .port1_ack   ( ),
    .port1_we    ( sdram_we ),
    .port1_a     ( sdram_addr[23:1] ),
    .port1_ds    ( sdram_bs ),
    .port1_d     ( sdram_din ),
    .port1_q     ( sdram_dout )
);

//-- apply some mask when .D was loaded last
assign rommask = (index != 8'h03 && index != 8'h41) ? 6'b111111 : // not .D
               romwr_a[24:14] == 11'b00000000000 ? 6'b00001 :
               romwr_a[24:15] == 10'b0000000000 ? 6'b000011 :
               romwr_a[24:16] ==  9'b000000000 ? 6'b000111 :
               romwr_a[24:17] ==  8'b00000000 ? 6'b001111 :
               romwr_a[24:18] ==  7'b0000000 ? 6'b011111 :
               6'b111111;

assign cpu_ram_d_to_ti = sdram_dout;
assign sdram_addr = !downl ? {5'b00000, cpu_ram_a, 1'b0} :
                (index == 8'h02 || index == 8'h01) ? romwr_a : // .c
                (index == 8'h03 || index == 8'h41) ? romwr_a + 16'h2000  : // .d
                (index == 8'h04 || index == 8'h81) ? romwr_a + 20'h86000 : // .g
                romwr_a + 20'h80000; // .rom

assign ram_we = downl ? rom_wr : ~(cpu_ram_ce_n || cpu_ram_we_n);
assign ram_rd = downl ? 1'b0 :   ~(cpu_ram_ce_n || ~cpu_ram_we_n);
assign sdram_din = downl ? {ioctl_dout, ioctl_dout} : cpu_ram_d_from_ti;
assign sdram_bs =  downl ? {~romwr_a[0], romwr_a[0]} : ~cpu_ram_be_n;

reg  [2:0] clk_mem_cnt;
assign clkref = clk_mem_cnt == 0;
assign force_reset = downl;

always @(posedge clk_mem) begin
	reg ram_rdD, ram_weD;

	clk_mem_cnt <= clk_mem_cnt + 1'd1;
	ram_weD <= ram_we;
	ram_rdD <= ram_rd;
	if ((ram_we & !ram_weD) || (ram_rd & !ram_rdD)) begin
		sdram_req <= ~sdram_req;
		sdram_we <= ram_we;
	end
end

//-----------------------------------------------------------------------------
//-- VIDEO OUTPUT
//-----------------------------------------------------------------------------

mist_video #(.COLOR_DEPTH(8), .OSD_COLOR(3'd3), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD), .USE_BLANKS(1'b1)) mist_video (
    .clk_sys     ( clk_sys    ),

    // OSD SPI interface
    .SPI_SCK     ( SPI_SCK    ),
    .SPI_SS3     ( SPI_SS3    ),
    .SPI_DI      ( SPI_DI     ),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines   ( scanlines  ),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider  ( 1'b0       ),

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
    .R           ( red        ),
    .G           ( green      ),
    .B           ( blue       ),

    .HBlank      ( hb         ),
    .VBlank      ( vb         ),
    .HSync       ( hs         ),
    .VSync       ( vs         ),

    // MiST video output signals
    .VGA_R       ( VGA_R      ),
    .VGA_G       ( VGA_G      ),
    .VGA_B       ( VGA_B      ),
    .VGA_VS      ( VGA_VS     ),
    .VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(42_000_000) i2c_master (
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

mist_video #(.COLOR_DEPTH(8), .OSD_COLOR(3'd3), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .USE_BLANKS(1'b1)) hdmi_video (
    .clk_sys     ( clk_sys    ),

    // OSD SPI interface
    .SPI_SCK     ( SPI_SCK    ),
    .SPI_SS3     ( SPI_SS3    ),
    .SPI_DI      ( SPI_DI     ),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines   ( scanlines  ),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider  ( 1'b0       ),

    // 0 = HVSync 31KHz, 1 = CSync 15KHz
    .scandoubler_disable ( 1'b0 ),
    // disable csync without scandoubler
    .no_csync    ( no_csync   ),
    // YPbPr always uses composite sync
    .ypbpr       ( ypbpr      ),
    // Rotate OSD [0] - rotate [1] - left or right
    .rotate      ( 2'b00      ),
    // composite-like blending
    .blend       ( blend      ),

    // video in
    .R           ( red        ),
    .G           ( green      ),
    .B           ( blue       ),

    .HBlank      ( hb         ),
    .VBlank      ( vb         ),
    .HSync       ( hs         ),
    .VSync       ( vs         ),

    // MiST video output signals
    .VGA_R       ( HDMI_R     ),
    .VGA_G       ( HDMI_G     ),
    .VGA_B       ( HDMI_B     ),
    .VGA_VS      ( HDMI_VS    ),
    .VGA_HS      ( HDMI_HS    ),
    .VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_sys;

`endif

//-----------------------------------------------------------------------------
//-- AUDIO OUTPUT
//-----------------------------------------------------------------------------

wire dac_o;
assign AUDIO_L = dac_o;
assign AUDIO_R = dac_o;

dac #(
	.C_bits(11))
dac_r(
	.clk_i(clk_sys),
	.res_n_i(1),
	.dac_i(unsigned_audio),
	.dac_o(dac_o)
	);	

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd42_660_000),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan({2'd0, unsigned_audio, 3'd0}),
	.right_chan({2'd0, unsigned_audio, 3'd0})
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
spdif spdif (
	.rst_i(1'b0),
	.clk_i(clk_sys),
	.clk_rate_i(32'd42_660_000),
	.spdif_o(SPDIF),
	.sample_i({2{2'd0, unsigned_audio, 3'd0}})
);
`endif

endmodule
