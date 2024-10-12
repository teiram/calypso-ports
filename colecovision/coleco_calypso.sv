module coleco_calypso(
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

`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
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
    "COLECO;COLBINROM;",
    "F,SG ,Load;",
    `SEP
    "O45,RAM Size,1k,8k,SGM;",
    "O7,Exp mod. 2,Off,On;",
    "O6,Joystick swap,Off,On;",
    "O23,Scanlines,Off,25%,50%,75%;",
    "O5,Blend,Off,On;",
    "T0,Reset;",
    "V,v",`BUILD_DATE
};

wire  [1:0] scanlines = status[3:2];
wire        blend = status[5];
wire        joyswap = status[6];

assign LED[0] = ~downl;
assign UART_TX = 1;

wire clk_mem, clk_21m3, clk_sys = clk_21m3, clk_vid, pll_locked;
assign SDRAM_CLK = clk_mem;
assign SDRAM_CKE = 1;

pll pll (
    .inclk0(CLK12M),
    .c0(clk_mem), // 84 MHz
    .c1(clk_vid), // 42 MHz
    .c2(clk_21m3),
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
wire        ps2Clk;
wire        ps2Data;

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
    .clk_sd(),
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
    .joystick_0(joy0),
    .joystick_1(joy1),
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_code(key_code),
    .ps2_kbd_clk(ps2Clk),
    .ps2_kbd_data(ps2Data)
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
reg [15:0] clk_en_spinner_counter;
reg        clk_en_spinner;

always @(posedge clk_sys) begin
	if (reset) begin
		clk_cnt <= 0;
		clk_en_10m7 <= 0;
		clk_en_spinner <= 0;
		clk_en_spinner_counter <= 0;
	end else begin
		clk_cnt <= clk_cnt + 1'd1;

		if (clk_cnt == 1 || clk_cnt == 3)
			clk_en_10m7 <= 1;
		else
			clk_en_10m7 <= 0;

		// clk enable for spinner
		clk_en_spinner_counter <= clk_en_spinner_counter + 1'd1;
		if (clk_en_spinner_counter == 0)
			clk_en_spinner <= 1;
		else
			clk_en_spinner <= 0;
	end
end

always @(posedge clk_sys)
	reset <= status[0] || buttons[1] || force_reset;

//-----------------------------------------------------------------------------
//-- The Colecovision console
//-----------------------------------------------------------------------------
wire        sg1000 = index[1];
reg         dahjeeA;
wire  [2:0] sg1000_row;
wire [11:0] sg1000_col;

wire [14:0] cpu_ram_a;
wire        cpu_ram_ce_n;
wire        cpu_ram_we_n;
wire  [7:0] cpu_ram_d_to_cv;
wire  [7:0] cpu_ram_d_from_cv;

wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_d_to_cv;
wire  [7:0] vram_d_from_cv;

wire [24:0] cart_a;
wire  [7:0] cart_d;
wire        cart_en_80_n;
wire        cart_en_a0_n;
wire        cart_en_c0_n;
wire        cart_en_e0_n;
wire        cart_en_sg1000_n;
wire [12:0] bios_rom_a;
wire        bios_rom_ce_n;
wire  [7:0] bios_rom_d;

wire  [7:0] coleco_red;
wire  [7:0] coleco_green;
wire  [7:0] coleco_blue;
wire        coleco_hs;
wire        coleco_vs;
wire        coleco_hb;
wire        coleco_vb;
wire [10:0] unsigned_audio;

wire  [7:0] joya, joyb;
reg   [2:1] ctrl_p1,
            ctrl_p2,
            ctrl_p3,
            ctrl_p4,
            ctrl_p5,
            ctrl_p6,
            ctrl_p7,
            ctrl_p8,
            ctrl_p9;

cv_console #(.is_pal_g(0), .compat_rgb_g(0)) cv_console
(
    .clk_i           ( clk_21m3 ),
    .clk_en_10m7_i   ( clk_en_10m7 ),
    .reset_n_i       ( ~reset ),
    .sg1000          ( sg1000 ),
    .sg1000_row_o    ( sg1000_row ),
    .sg1000_col_i    ( sg1000_col ),
    .sg1000_tap_i    ( ear_input ),
    .dahjeeA_i       ( dahjeeA ),
    .por_n_o         ( por_n ),
    .ctrl_p1_i       ( ctrl_p1 ),
    .ctrl_p2_i       ( ctrl_p2 ),
    .ctrl_p3_i       ( ctrl_p3 ),
    .ctrl_p4_i       ( ctrl_p4 ),
    .ctrl_p5_o       ( ctrl_p5 ),
    .ctrl_p6_i       ( ctrl_p6 ),
    .ctrl_p7_i       ( ctrl_p7 ),
    .ctrl_p8_o       ( ctrl_p8 ),
    .ctrl_p9_i       ( ctrl_p9 ),
    .joy0_i          ( ~joya ),
    .joy1_i          ( ~joyb ),
    .bios_rom_a_o    ( bios_rom_a ),
    .bios_rom_ce_n_o ( bios_rom_ce_n ),
    .bios_rom_d_i    ( bios_rom_d ),
    .cpu_ram_a_o     ( cpu_ram_a ),
    .cpu_ram_ce_n_o  ( cpu_ram_ce_n ),
    .cpu_ram_we_n_o  ( cpu_ram_we_n ),
    .cpu_ram_d_i     ( cpu_ram_d_to_cv ),
    .cpu_ram_d_o     ( cpu_ram_d_from_cv ),
    .vram_a_o        ( vram_a ),
    .vram_we_o       ( vram_we ),
    .vram_d_o        ( vram_d_from_cv ),
    .vram_d_i        ( vram_d_to_cv ),
    .cart_a_o        ( cart_a[19:0] ),
    .cart_pages_i    ( romwr_a[19:14] ),
    .cart_en_80_n_o  ( cart_en_80_n ),
    .cart_en_a0_n_o  ( cart_en_a0_n ),
    .cart_en_c0_n_o  ( cart_en_c0_n ),
    .cart_en_e0_n_o  ( cart_en_e0_n ),
    .cart_en_sg1000_n_o ( cart_en_sg1000_n ),
    .cart_d_i        ( cart_d ),
    .col_o           ( ),
    .rgb_r_o         ( coleco_red ),
    .rgb_g_o         ( coleco_green ),
    .rgb_b_o         ( coleco_blue ),
    .hsync_n_o       ( coleco_hs ),
    .vsync_n_o       ( coleco_vs ),
    .hblank_o        ( coleco_hb ),
    .vblank_o        ( coleco_vb ),
    .audio_o         ( unsigned_audio )
);

// PS/2 keyboard interface
wire [15:0] ps2_keys;
wire [15:0] ps2_joy;

colecoKeyboard ps2if_inst
(
    .clk             ( clk_21m3   ),
    .reset           ( reset      ),
  
    // inputs from PS/2 port
    .ps2_clk         ( ps2Clk     ),
    .ps2_data        ( ps2Data    ),
  
      // user outputs
    .keys            ( ps2_keys   ),
    .joy             ( ps2_joy    ),

    .sg1000_row      ( sg1000_row ),
    .sg1000_col      ( sg1000_col )
);

assign joya = joyswap ? joy1[7:0] : joy0[7:0];
assign joyb = joyswap ? joy0[7:0] : joy1[7:0];

localparam [3:0] cv_key_0_c =  0;
localparam [3:0] cv_key_1_c =  1;
localparam [3:0] cv_key_2_c =  2;
localparam [3:0] cv_key_3_c =  3;
localparam [3:0] cv_key_4_c =  4;
localparam [3:0] cv_key_5_c =  5;
localparam [3:0] cv_key_6_c =  6;
localparam [3:0] cv_key_7_c =  7;
localparam [3:0] cv_key_8_c =  8;
localparam [3:0] cv_key_9_c =  9;
localparam [3:0] cv_key_asterisk_c = 10;
localparam [3:0] cv_key_number_c   = 11;
localparam [3:0] cv_key_none_c     = 12;
localparam [3:0] cv_key_last_c     = cv_key_none_c;

//Key map encoding
//
// cv_key_t(1)  <->  Pin 1
// cv_key_t(2)  <->  Pin 2
// cv_key_t(3)  <->  Pin 3
// cv_key_t(4)  <->  Pin 4

localparam bit [1:4] cv_keys_c[13] = '{
 4'b0011,
 4'b1110,
 4'b1101,
 4'b0110,
 4'b0001,
 4'b1001,
 4'b0111,
 4'b1100,
 4'b1000,
 4'b1011,
 4'b1010,
 4'b0101,
 4'b1111
};
	
genvar idx;

generate
	for (idx = 1; idx <= 2; idx = idx + 1) begin : controls
		wire [1:0] quadr_in = {ctrl_p7[idx], ctrl_p9[idx]};
		wire [7:0] joy = idx == 1 ? joya : joyb;
		reg  [3:0] key_v;

		always @(posedge clk_21m3) begin
			if (!status[7]) begin
				ctrl_p7[idx] <= 1;
				ctrl_p9[idx] <= 1;
			end else if (clk_en_spinner) begin
				if (joy[1]) begin
					case (quadr_in)
						2'b00: ctrl_p9[idx] <= 1;
						2'b01: ctrl_p7[idx] <= 1;
						2'b11: ctrl_p9[idx] <= 0;
						2'b10: ctrl_p7[idx] <= 0;
						default: ;
					endcase;
				end else if (joy[0]) begin
					case (quadr_in)
						2'b00: ctrl_p7[idx] <= 1;
						2'b01: ctrl_p9[idx] <= 0;
						2'b11: ctrl_p7[idx] <= 0;
						2'b10: ctrl_p9[idx] <= 1;
					endcase;
				end
			end
		end

		always @(*) begin
			key_v = cv_key_none_c;

			if (!ctrl_p5[idx] & ctrl_p8[idx]) begin
				// keys and right button enabled --------------------------------------
				if (ps2_keys[13])
					// KEY 1
					key_v = cv_key_1_c;
				else if (ps2_keys[7])
					// KEY 2
					key_v = cv_key_2_c;
				else if (ps2_keys[12])
					// KEY 3
					key_v = cv_key_3_c;
				else if (ps2_keys[2])
					// KEY 4
					key_v = cv_key_4_c;
				else if (ps2_keys[3])
					// KEY 5
					key_v = cv_key_5_c;  
				else if (ps2_keys[14])
					// KEY 6
					key_v = cv_key_6_c;  
				else if (ps2_keys[5])
					// KEY 7
					key_v = cv_key_7_c;  
				else if (ps2_keys[1])
					// KEY 8
					key_v = cv_key_8_c;
				else if (ps2_keys[11])
					// KEY 9
					key_v = cv_key_9_c;
				else if (ps2_keys[10])
					// KEY 0
					key_v = cv_key_0_c;         
				else if (ps2_keys[9])
					// KEY *
					key_v = cv_key_asterisk_c;
				else if (ps2_keys[6])
					// KEY #
					key_v = cv_key_number_c;

				ctrl_p1[idx] = cv_keys_c[key_v][1];
				ctrl_p2[idx] = cv_keys_c[key_v][2];
				ctrl_p3[idx] = cv_keys_c[key_v][3];
				ctrl_p4[idx] = cv_keys_c[key_v][4];

				// KEY X
				ctrl_p6[idx] = ~ps2_keys[0] & ~joy[5]; // button 2

			end else if (ctrl_p5[idx] & !ctrl_p8[idx]) begin
				// joystick and left button enabled -----------------------------------
				ctrl_p1[idx] = ~ps2_joy[0] & ~joy[3]; // up
				ctrl_p2[idx] = ~ps2_joy[1] & ~joy[2]; // down
				ctrl_p3[idx] = ~ps2_joy[2] & ~joy[1]; // left
				ctrl_p4[idx] = ~ps2_joy[3] & ~joy[0]; // right
				ctrl_p6[idx] = ~ps2_joy[4] & ~joy[4]; // button 1
      end else begin
				// nothing active -----------------------------------------------------
				ctrl_p1[idx] = 1;
				ctrl_p2[idx] = 1;
				ctrl_p3[idx] = 1;
				ctrl_p4[idx] = 1;
        ctrl_p6[idx] = 1;
			end;
		end
	end
endgenerate

//-----------------------------------------------------------------------------
//-- BIOS ROM
//-----------------------------------------------------------------------------
sprom #(.widthad_a(13), .init_file("colecovision_fpga/roms/hex/bios.hex")) bios_b
(
    .clock     ( clk_21m3 ),
    .address   ( bios_rom_a ),
    .q         ( bios_rom_d )
);

//-----------------------------------------------------------------------------
//-- CPU RAM
//-----------------------------------------------------------------------------
wire        cpu_ram_we = clk_en_10m7 & ~(cpu_ram_we_n | cpu_ram_ce_n);
wire [14:0] ram_a = (sg1000 & dahjeeA) ? cpu_ram_a[14:0] :
             (sg1000 & !cpu_ram_a[14]) ? {1'b1, cpu_ram_a[13:0]} :    // 16k at $8000 for Basic/The Castle/Othello
                  status[5:4] == 2'b01 ? {2'b00, cpu_ram_a[12:0]} :   // 8k
                  status[5:4] == 2'b00 ? {5'b00000, cpu_ram_a[9:0]} : // 1k
                                sg1000 ? {1'b0, cpu_ram_a[13:0]} :    // SGM means 16k on SG1000
                                         cpu_ram_a; // SGM/32k

spram #(.widthad_a(15)) cpu_ram_b
(
    .clock     ( clk_21m3 ),
    .address   ( ram_a    ),
    .wren      ( cpu_ram_we ),
    .data      ( cpu_ram_d_from_cv ),
    .q         ( cpu_ram_d_to_cv )
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

wire        rom_en;
reg         sdram_req;
wire [24:0] sdram_addr;
wire [15:0] sdram_q;

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
    .port1_we    ( downl ),
    .port1_a     ( sdram_addr[23:1] ),
    .port1_ds    ( {sdram_addr[0], ~sdram_addr[0]} ),
    .port1_d     ( {ioctl_dout, ioctl_dout} ),
    .port1_q     ( sdram_q )
);

assign rom_en = ~(cart_en_80_n & cart_en_a0_n & cart_en_c0_n & cart_en_e0_n & cart_en_sg1000_n);
assign sdram_addr = downl ? romwr_a : cart_a;
assign cart_d = sdram_addr[0] ? sdram_q[15:8] : sdram_q[7:0];

reg  [2:0] clk_mem_cnt;
assign clkref = clk_mem_cnt == 0;
assign force_reset = downl;

always @(posedge clk_mem) begin
    reg old_downl;
    reg rom_enD;
    reg [7:0] chksum;

    clk_mem_cnt <= clk_mem_cnt + 1'd1;
    old_downl <= downl;

    rom_enD <= rom_en;
    if (rom_wr | (!rom_enD & rom_en))
        sdram_req <= ~sdram_req;

    if (sg1000 & downl) begin
        if (!old_downl) begin
            chksum <= 0;
            dahjeeA <= 0;
        end
        if (romwr_a[15:0] == 16'h2000) begin
            chksum <= ioctl_dout;
        end else if (romwr_a[15:13] == 3'b001) begin //-- 2xxx - 3xxx
            chksum <= chksum & ioctl_dout;
        end
    end
    if (sg1000 & !downl & chksum == 8'hFF)
        dahjeeA <= 1;
end

//-----------------------------------------------------------------------------
//-- VIDEO OUTPUT
//-----------------------------------------------------------------------------

mist_video #(.COLOR_DEPTH(8), .OSD_COLOR(3'd3), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD), .USE_BLANKS(1'b1)) mist_video (
    .clk_sys     ( clk_vid    ),

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
    .R           ( coleco_red ),
    .G           ( coleco_green ),
    .B           ( coleco_blue ),

    .HBlank      ( coleco_hb  ),
    .VBlank      ( coleco_vb  ),
    .HSync       ( coleco_hs  ),
    .VSync       ( coleco_vs  ),

    // MiST video output signals
    .VGA_R       ( VGA_R      ),
    .VGA_G       ( VGA_G      ),
    .VGA_B       ( VGA_B      ),
    .VGA_VS      ( VGA_VS     ),
    .VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(21_300_000) i2c_master (
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
    .clk_sys     ( clk_vid    ),

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
    .R           ( coleco_red ),
    .G           ( coleco_green ),
    .B           ( coleco_blue ),

    .HBlank      ( coleco_hb  ),
    .VBlank      ( coleco_vb  ),
    .HSync       ( coleco_hs  ),
    .VSync       ( coleco_vs  ),

    // MiST video output signals
    .VGA_R       ( HDMI_R     ),
    .VGA_G       ( HDMI_G     ),
    .VGA_B       ( HDMI_B     ),
    .VGA_VS      ( HDMI_VS    ),
    .VGA_HS      ( HDMI_HS    ),
    .VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_vid;

`endif

//-----------------------------------------------------------------------------
//-- AUDIO OUTPUT
//-----------------------------------------------------------------------------

wire dac_o;

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
	.clk(clk_vid),
	.clk_rate(32'd42_660_000),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan({2'd0, unsigned_audio, 3'd0}),
	.right_chan({2'd0, unsigned_audio, 3'd0})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_vid) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif (
	.rst_i(1'b0),
	.clk_i(clk_vid),
	.clk_rate_i(32'd42_660_000),
	.spdif_o(SPDIF),
	.sample_i({2{2'd0, unsigned_audio, 3'd0}})
);
`endif

endmodule
