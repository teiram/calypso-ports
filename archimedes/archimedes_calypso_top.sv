`timescale 1ns / 1ps

module guest_top(
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
//	input         HDMI_INT,
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
//	output        HDMI_MCLK,
//	output        HDMI_BCK,
//	output        HDMI_LRCK,
//	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
//	output        SPDIF,
`endif
`ifdef USE_ADC
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

wire [7:0] kbd_out_data;
wire kbd_out_strobe;
wire [7:0] kbd_in_data;
wire kbd_in_strobe;

// generated clocks
wire clk_pix, clk_pix_i;
wire clk_vid, clk_vid_i;
wire ce_pix;
wire clk_sys /* synthesis keep */ ;
wire clk_mem /* synthesis keep */ ;
//wire clk_8m  /* synthesis keep */ ;

wire pll_ready;
wire pll_vidc_ready;
wire ram_ready;

// core's raw video 
wire [3:0] core_r, core_g, core_b;
wire       core_hs, core_vs;
wire       core_hb, core_vb;

// core's raw audio 
wire [15:0] coreaud_l, coreaud_r;

// data loading 
wire       downloading, uploading;
wire       loader_active = downloading && (dio_index == 1 || dio_index == 2);
wire [7:0] dio_index;
wire       loader_we /* synthesis keep */ ;
reg        loader_stb = 1'b0 /* synthesis keep */ ;
reg        rom_ready = 0;
(*KEEP="TRUE"*)wire [3:0]	loader_sel /* synthesis keep */ ;
(*KEEP="TRUE"*)wire [23:0]	loader_addr /* synthesis keep */ ;
(*KEEP="TRUE"*)wire [7:0]	loader_dout /* synthesis keep */ ;
wire [7:0] loader_din;

// IDE
wire        hdd_cmd_req;
wire        hdd_dat_req;
wire        hdd_status_wr;

wire  [2:0] hdd_addr;
wire        hdd_wr;

wire [15:0] hdd_data_out;
wire [15:0] hdd_data_in;
wire        hdd_data_rd;
wire        hdd_data_wr;

wire [15:0] IDE_DAT_O;
wire [15:0] IDE_DAT_I;
wire  [2:0] IDE_A;
wire        IDE_WE;
wire        IDE_CS;

// user io

wire [7:0] joyA;
wire [7:0] joyB;
wire [1:0] buttons;
wire [1:0] switches;
wire       scandoubler_disable;
wire       ypbpr;
wire       no_csync;
wire[63:0] rtc;

// the top file should generate the correct clocks for the machine

clockgen_calypso CLOCKS(
	.inclk0	(CLK12M),
	.c0		(SDRAM_CLK),// 120 MHz, shifted
	.c1		(clk_mem), // 120 MHz
	.c2      (clk_sys), // 40 MHz
	.locked	(pll_ready)  // pll locked output
);

reg [3:0] clken_counter;
reg       clk8m_en;
reg       clk2m_en;

always @(posedge clk_sys) begin
	clken_counter <= clken_counter + 1'd1;
	if (clken_counter == 19) clken_counter <= 0;

	clk2m_en <= clken_counter ==  0;
	clk8m_en <= clken_counter ==  0 || clken_counter ==  5 || clken_counter == 10 || clken_counter == 15;
end

pll_vidc_36_calypso CLOCKS_VIDC(
	.inclk0	(clk_sys),
	.c0     (clk_pix_i), // 2x VIDC pixel clock (48, 50, 76 MHz);
	.c1     (clk_vid_i), // 4x VIDC pixel clock for scandoubler use (24MHz mode => 96 MHz), otherwise 2x pixel clock
	.areset(pll_areset),
	.scanclk(pll_scanclk),
	.scandata(pll_scandata),
	.scanclkena(pll_scanclkena),
	.configupdate(pll_configupdate),
	.scandataout(pll_scandataout),
	.scandone(pll_scandone),
	.locked	(pll_vidc_ready)  // pll locked output
);

reg        vidc_clock_ena;

clkcltr_calypso CLKCTRL_PIX(
	.inclk(clk_pix_i),
	.outclk(clk_pix),
	.ena(vidc_clock_ena)
);

clkcltr_calypso CLKCTRL_VID(
	.inclk(clk_vid_i),
	.outclk(clk_vid),
	.ena(vidc_clock_ena)
);

wire       pll_reconfig_busy;
wire       pll_areset;
wire       pll_configupdate;
wire       pll_scanclk;
wire       pll_scanclkena;
wire       pll_scandata;
wire       pll_scandataout;
wire       pll_scandone;
reg        pll_reconfig_reset;
wire [7:0] pll_rom_address;
wire       pll_rom_q;
reg        pll_write_from_rom;
wire       pll_write_rom_ena;
reg        pll_reconfig;
wire       q_reconfig_25;
wire       q_reconfig_24;
wire       q_reconfig_36;

//POSEIDON TEST
//assign SDRAM_CLK = ~SDRAM_CLK;

rom_reconfig_25_calypso rom_reconfig_25
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_25)
);

rom_reconfig_24_calypso rom_reconfig_24
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_24)
);

rom_reconfig_36_calypso rom_reconfig_36
(
	.address(pll_rom_address),
	.clock(clk_sys),
	.rden(pll_write_rom_ena),
	.q(q_reconfig_36)
);

assign pll_rom_q = pixbaseclk_select == 2'b01 ? q_reconfig_25 :
                   pixbaseclk_select == 2'b10 ? q_reconfig_36 : q_reconfig_24;

pll_reconfig_calypso pll_reconfig_inst
(
	.busy(pll_reconfig_busy),
	.clock(clk_sys),
	.counter_param(0),
	.counter_type(0),
	.data_in(0),
	.pll_areset(pll_areset),
	.pll_areset_in(0),
	.pll_configupdate(pll_configupdate),
	.pll_scanclk(pll_scanclk),
	.pll_scanclkena(pll_scanclkena),
	.pll_scandata(pll_scandata),
	.pll_scandataout(pll_scandataout),
	.pll_scandone(pll_scandone),
	.read_param(0),
	.reconfig(pll_reconfig),
	.reset(pll_reconfig_reset),
	.reset_rom_address(0),
	.rom_address_out(pll_rom_address),
	.rom_data_in(pll_rom_q),
	.write_from_rom(pll_write_from_rom),
	.write_param(0),
	.write_rom_ena(pll_write_rom_ena)
);

always @(posedge clk_sys) begin
	reg [1:0] pixbaseclk_select_d = 2'b10;
	reg [1:0] pll_reconfig_state = 0;
	reg [9:0] pll_reconfig_timeout;

	pll_write_from_rom <= 0;
	pll_reconfig <= 0;
	pll_reconfig_reset <= 0;
	case (pll_reconfig_state)
	2'b00:
	begin
		vidc_clock_ena <= 1;
		pixbaseclk_select_d <= pixbaseclk_select;
		if (pixbaseclk_select_d != pixbaseclk_select) begin
			vidc_clock_ena <= 0;
			pll_write_from_rom <= 1;
			pll_reconfig_state <= 2'b01;
		end
	end
	2'b01: pll_reconfig_state <= 2'b10;
	2'b10:
        if (~pll_reconfig_busy) begin
            pll_reconfig <= 1;
            pll_reconfig_state <= 2'b11;
            pll_reconfig_timeout <= 10'd1000;
        end
	2'b11:
	begin
		pll_reconfig_timeout <= pll_reconfig_timeout - 1'd1;
		if (pll_reconfig_timeout == 10'd1) begin
			// pll_reconfig stuck in busy state
			pll_reconfig_reset <= 1;
			pll_reconfig_state <= 2'b00;
		end
		if (~pll_reconfig & ~pll_reconfig_busy) pll_reconfig_state <= 2'b00;
	end
	default: ;
	endcase
end

// forcibly blank back porch area
reg [3:0] r_adj, g_adj, b_adj;
reg       hs_adj, vs_adj;
reg [7:0] pix_cnt;
// blanking size: 256 cycles @ 24MHz (TV), 64 cycles otherwise (VGA)
wire      back_porch_n =  (pixbaseclk_select[0] == pixbaseclk_select[1]) ? &pix_cnt : &pix_cnt[5:0];

always @(posedge clk_pix) begin

	if (~back_porch_n) pix_cnt <= pix_cnt + 1'd1;
	if (~hs_adj) pix_cnt <= 0;

	if (ce_pix) begin
		hs_adj <= core_hs;
		vs_adj <= core_vs;

		if (back_porch_n) begin
			r_adj <= core_r;
			g_adj <= core_g;
			b_adj <= core_b;
		end else
			{ r_adj, g_adj, b_adj } <= 12'h0;
	end
end

wire   scandoubler_en = ~scandoubler_disable && pixbaseclk_select[0] == pixbaseclk_select[1];

mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(12), .OUT_COLOR_DEPTH(VGA_BITS)) mist_video (
	.clk_sys     ( clk_vid    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b1       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( ~scandoubler_en ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( r_adj      ),
	.G           ( g_adj      ),
	.B           ( b_adj      ),

	.HSync       ( hs_adj     ),
	.VSync       ( vs_adj     ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(40_000_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_wdata),
	.I2C_RDATA   (i2c_rdata),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(4), .SD_HCNT_WIDTH(12), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1)) hdmi_video (
	.clk_sys     ( clk_pix    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 3'd1       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( pixbaseclk_select[0] != pixbaseclk_select[1] ),
	// disable csync without scandoubler
	.no_csync    ( 1'b1       ),
	// YPbPr always uses composite sync
	.ypbpr       ( 1'b0       ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( r_adj      ),
	.G           ( g_adj      ),
	.B           ( b_adj      ),

	.HSync       ( core_hs    ),
	.VSync       ( core_vs    ),
	.HBlank      ( core_hb    ),
	.VBlank      ( core_vb    ),

	// MiST video output signals
	.VGA_R       ( HDMI_R     ),
	.VGA_G       ( HDMI_G     ),
	.VGA_B       ( HDMI_B     ),
	.VGA_VS      ( HDMI_VS    ),
	.VGA_HS      ( HDMI_HS    ),
	.VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_pix;

`endif

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc = 1'b1;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire        sd_din_strobe;
wire  [8:0] sd_buff_addr;
wire  [1:0] img_mounted;
wire [31:0] img_size;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_rdata;
wire  [7:0] i2c_wdata;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.ARCHIE(1)) user_io(
	// the spi interface
	.clk_sys        ( clk_sys        ),
	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),   // tristate handling inside user_io
	.SPI_MOSI       ( SPI_DI         ),

	.switches       ( switches       ),
	.buttons        ( buttons        ),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr          ( ypbpr          ),
	.no_csync       ( no_csync       ),
	.rtc            ( rtc            ),

	.joystick_0     ( joyA           ),
	.joystick_1     ( joyB           ),

	.kbd_out_data   ( kbd_out_data   ),
	.kbd_out_strobe ( kbd_out_strobe ),
	.key_code       ( kbd_in_data    ),
	.key_strobe     ( kbd_in_strobe  ),
`ifdef USE_HDMI
	.i2c_start      ( i2c_start      ),
	.i2c_read       ( i2c_read       ),
	.i2c_addr       ( i2c_addr       ),
	.i2c_subaddr    ( i2c_subaddr    ),
	.i2c_dout       ( i2c_wdata      ),
	.i2c_din        ( i2c_rdata      ),
	.i2c_ack        ( i2c_ack        ),
	.i2c_end        ( i2c_end        ),
`endif
	.clk_sd         ( clk_sys        ),
	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( sd_ack         ),
	.sd_ack_conf    ( sd_ack_conf    ),
	.sd_conf        ( sd_conf        ),
	.sd_sdhc        ( sd_sdhc        ),
	.sd_dout        ( sd_dout        ),
	.sd_dout_strobe ( sd_dout_strobe ),
	.sd_din         ( sd_din         ),
	.sd_din_strobe  ( sd_din_strobe  ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       )
);

data_io #(.START_ADDR(24'h40_0000), .ENABLE_IDE(1'b1)) data_io(
	.clk_sys       ( clk_sys      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( downloading  ),
	.ioctl_upload  ( uploading    ),
	.ioctl_index   ( dio_index    ),
	.ioctl_wr      ( loader_we    ),
	.ioctl_addr    ( loader_addr  ),
	.ioctl_dout    ( loader_dout  ),
	.ioctl_din     ( loader_din   ),

	.hdd_clk       ( clk_sys      ),
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

assign loader_sel = loader_addr[1:0] == 2'b00 ? 4'b0001 :
                    loader_addr[1:0] == 2'b01 ? 4'b0010 :
                    loader_addr[1:0] == 2'b10 ? 4'b0100 : 4'b1000;

ide ide (
	.clk(clk_sys), // system clock
	.clk_en(1'b1),
	.reset(reset),

	// cpu interface
	.address_in(IDE_A[2:0]),
	.sel_secondary(1'b0),
	.data_in({IDE_DAT_O[7:0], IDE_DAT_O[15:8]}),
	.data_out({IDE_DAT_I[7:0], IDE_DAT_I[15:8]}),
	.rd(~IDE_WE),
	.hwr(IDE_WE),
	.lwr(IDE_WE),
	.sel_ide(IDE_CS),
	.intreq(),
	.intreq_ack(),  // interrupt clear
	.nrdy(),				// fifo is not ready for reading 
	.hdd0_ena(2'b11),		// enables Master & Slave drives on primary channel
	.hdd1_ena(2'b00),		// enables Master & Slave drives on secondary channel
	.fifo_rd(),
	.fifo_wr(),

	// io controller interface
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

wire        core_ack_in   /* synthesis keep */ ;
wire        core_stb_out  /* synthesis keep */ ;
wire        core_cyc_out  /* synthesis keep */ ;
wire        core_we_o;
wire  [3:0] core_sel_o;
wire  [2:0] core_cti_o;
wire [31:0] core_data_in, core_data_out;
wire [31:0] ram_data_in;
wire [26:2] core_address_out;

wire  [1:0] pixbaseclk_select;

wire        i2c_din, i2c_dout, i2c_clock;

wire        reset = ~ram_ready | ~rom_ready | buttons[1];

archimedes_top ARCHIMEDES(

	.CLKCPU_I       ( clk_sys        ),
	.CLKPIX_I       ( clk_pix        ), // 2xVIDC clock
	.CEPIX_O        ( ce_pix         ),
	.CLK2M_EN       ( clk2m_en       ),
	.CLK8M_EN       ( clk8m_en       ),

	.RESET_I        ( reset          ),

	.MEM_ACK_I      ( core_ack_in    ),
	.MEM_DAT_I      ( core_data_in   ),
	.MEM_DAT_O      ( core_data_out  ),
	.MEM_ADDR_O     ( core_address_out ),
	.MEM_STB_O      ( core_stb_out   ),
	.MEM_CYC_O      ( core_cyc_out   ),
	.MEM_SEL_O      ( core_sel_o     ),
	.MEM_WE_O       ( core_we_o      ),
	.MEM_CTI_O      ( core_cti_o     ),

	.HSYNC          ( core_hs        ),
	.VSYNC          ( core_vs        ),
	.HBLANK         ( core_hb        ),
	.VBLANK         ( core_vb        ),

	.VIDEO_R        ( core_r         ),
	.VIDEO_G        ( core_g         ),
	.VIDEO_B        ( core_b         ),

	.AUDIO_L        ( coreaud_l      ),
	.AUDIO_R        ( coreaud_r      ),

	.I2C_DOUT       ( i2c_din        ),
	.I2C_DIN        ( i2c_dout       ),
	.I2C_CLOCK      ( i2c_clock      ),

	.DEBUG_LED      ( LED            ),

	// FDC connection
	.img_mounted    ( img_mounted    ),
	.img_size       ( img_size       ),
	.img_wp         ( 0              ),
	.sd_lba         ( sd_lba         ),
	.sd_rd          ( sd_rd          ),
	.sd_wr          ( sd_wr          ),
	.sd_ack         ( sd_ack         ),
	.sd_buff_addr   ( sd_buff_addr   ),
	.sd_dout        ( sd_dout        ),
	.sd_din         ( sd_din         ),
	.sd_dout_strobe ( sd_dout_strobe ),

	// IDE controller
	.IDE_DAT_O      ( IDE_DAT_O      ),
	.IDE_DAT_I      ( IDE_DAT_I      ),
	.IDE_A          ( IDE_A          ),
	.IDE_WE         ( IDE_WE         ),
	.IDE_CS         ( IDE_CS         ),

	.KBD_OUT_DATA   ( kbd_out_data   ),
	.KBD_OUT_STROBE ( kbd_out_strobe ),
	.KBD_IN_DATA    ( kbd_in_data    ),
	.KBD_IN_STROBE  ( kbd_in_strobe  ),

	.JOYSTICK0      ( ~{joyB[4], joyB[0], joyB[1], joyB[2], joyB[3]} ),
	.JOYSTICK1      ( ~{joyA[4], joyA[0], joyA[1], joyA[2], joyA[3]} ),
	.VIDBASECLK_O	( pixbaseclk_select ),
	.VIDSYNCPOL_O	( )
);

wire        ram_ack     /* synthesis keep */ ;
wire        ram_stb     /* synthesis keep */ ;
wire        ram_cyc     /* synthesis keep */ ;
wire        ram_we      /* synthesis keep */ ;
wire  [3:0] ram_sel     /* synthesis keep */ ;
wire [25:0] ram_address /* synthesis keep */ ;

sdram_top SDRAM(

	// wishbone interface
	.wb_clk         ( clk_sys        ),
	.wb_stb         ( ram_stb        ),
	.wb_cyc         ( ram_cyc        ),
	.wb_we          ( ram_we         ),
	.wb_ack         ( ram_ack        ),

	.wb_sel         ( ram_sel        ),
	.wb_adr         ( ram_address    ),
	.wb_dat_i       ( ram_data_in    ),
	.wb_dat_o       ( core_data_in   ),
	.wb_cti	        ( core_cti_o     ),

	// SDRAM Interface
	.sd_clk         ( clk_mem        ),
	.sd_rst         ( ~pll_ready     ),
	.sd_cke         ( SDRAM_CKE      ),

	.sd_dq          ( SDRAM_DQ       ),
	.sd_addr        ( SDRAM_A        ),
	.sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML} ),
	.sd_cs_n        ( SDRAM_nCS      ),
	.sd_ba          ( SDRAM_BA       ),
	.sd_we_n        ( SDRAM_nWE      ),
	.sd_ras_n       ( SDRAM_nRAS     ),
	.sd_cas_n       ( SDRAM_nCAS     ),
	.sd_ready	( ram_ready      )
);

i2cSlaveTop CMOS (
	.clk            ( clk_sys        ),
	.rst            ( ~pll_ready     ),
	.sdaIn          ( i2c_din        ),
	.sdaOut	        ( i2c_dout       ),
	.scl            ( i2c_clock      ),
	.we             ( downloading && dio_index == 3 && loader_we ),
	.rd             ( uploading && dio_index == 3),
	.addr           ( loader_addr[7:0] ),
	.din            ( loader_dout[7:0] ),
	.dout           ( loader_din ),
	.RTC            ( rtc            )
);

audio	AUDIO	(
	.clk            ( clk_pix        ),
	.rst            ( ~pll_ready     ),
	.audio_data_l   ( coreaud_l      ),
	.audio_data_r   ( coreaud_r      ),
	.audio_l        ( AUDIO_L        ),
	.audio_r        ( AUDIO_R        )
);

wire [31:0] clk_rate = pixbaseclk_select == 2'b01 ? 32'd50_000_000 :
                       pixbaseclk_select == 2'b10 ? 32'd72_000_000 : 32'd48_000_000;

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_pix),
	.clk_rate(clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({~coreaud_l[15], coreaud_l[14:0]}),
	.right_chan({~coreaud_r[15], coreaud_r[14:0]})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_pix) begin
//	HDMI_BCK <= I2S_BCK;
//	HDMI_LRCK <= I2S_LRCK;
//	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.clk_i(clk_pix),
	.rst_i(1'b0),
	.clk_rate_i(clk_rate),
	.spdif_o(SPDIF),
	.sample_i({~coreaud_r[15], coreaud_r[14:0], ~coreaud_l[15], coreaud_l[14:0]})
);
`endif

always @(posedge clk_sys) begin 
	reg loader_active_old;
	loader_active_old <= loader_active;

	if (loader_active_old & ~loader_active) rom_ready <= 1;
	if (loader_we) begin 

		loader_stb <= 1'b1;

	end else if (ram_ack) begin 

		loader_stb <= 1'b0;

	end

end

assign ram_we       = loader_active ? loader_active : core_we_o;
assign ram_sel      = loader_active ? loader_sel : core_sel_o;
assign ram_address  = loader_active ? {loader_addr[23:2],2'b00} : {core_address_out[23:2],2'b00};
assign ram_stb      = loader_active ? loader_stb : core_stb_out;
assign ram_cyc      = loader_active ? loader_stb : core_stb_out;
assign ram_data_in  = loader_active ? {loader_dout, loader_dout, loader_dout, loader_dout} : core_data_out;
assign core_ack_in  = loader_active ? 1'b0 : ram_ack;

endmodule // archimedes_mist_top
