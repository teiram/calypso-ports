//============================================================================
// 
//  VIC20 replica for Calypso Top-level
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

module vic20_calypso
(
	input         CLK12M,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output          [7:0] LED,
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

assign LED[0] = ~ioctl_download & ~led_disk & cass_motor;
assign UART_TX = ~cass_motor;

localparam TAP_MEM_START = 22'h20000;

localparam CONF_STR =
{
    "VIC20;PRGCRTTAP;",
    "S0U,D64,Mount Disk;",
    "TC,Play/Stop TAP;",
    `SEP
    "P1,Memory configuration;",
    "P1O78,Cartridge ,Off,ROM,RAM;",
    "P1O2,CRT with load address,Yes,No;",
    "P1O6,3K RAM Cartridge,Off,On;",
    "P1O45,8K+ RAM Cartridge,Off,8K,16K,24K;",
    "P2,Megacart;",
    "P2OF,Megacart,Off,On (overrides RAM);",
    "P2F,ROM,Load Megacart ROM;",
    "P2S1U,NV ,Mount NVRAM;",
    "P2TG,Write NVRAM;",
    "P3,Video / Audio;",
    "P3O3,Video,PAL,NTSC;",
    "P3OAB,Scanlines,Off,25%,50%,75%;",
    "P3OE,Composite blend,Off,On;",
    "P3OD,Tape sound,Off,On;",
    "P3O9,Audio Filter,On,Off;",
    `SEP
    "T0,Reset;",
    "T1,Reset with cart unload;",
    "V,v1.0.",`BUILD_DATE
};

reg uart_rxD;
reg uart_rxD2;

// UART_RX synchronizer
always @(posedge clk_sys) begin
	uart_rxD <= UART_RX;
	uart_rxD2 <= uart_rxD;
end

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
assign ear_input = uart_rxD2;
`endif

////////////////////   CLOCKS   ///////////////////
wire clk_sys;
wire clk_32;
wire clk_1541 = clk_32;
reg clk8m;
wire pll_locked;
reg clk_ref; //sync sdram to during prg downloading
reg  reset;
reg  c1541_reset;
reg cart_unload;
reg force_reset;

wire       pll_reconfig_busy;
wire       pll_areset;
wire       pll_configupdate;
wire       pll_scanclk;
wire       pll_scanclkena;
wire       pll_scandata;
wire       pll_scandataout;
wire       pll_scandone;
wire       pll_reconfig_reset;
wire [7:0] pll_rom_address;
wire       pll_rom_q;
wire       pll_write_from_rom;
wire       pll_write_rom_ena;
wire       pll_reconfig;
wire       q_reconfig_ntsc;
wire       q_reconfig_pal;

rom_reconfig_pal rom_reconfig_pal
(
    .address(pll_rom_address),
    .clock(clk_32),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_pal)
);

rom_reconfig_ntsc rom_reconfig_ntsc
(
    .address(pll_rom_address),
    .clock(clk_32),
    .rden(pll_write_rom_ena),
    .q(q_reconfig_ntsc)
);

assign pll_rom_q = st_ntsc ? q_reconfig_ntsc : q_reconfig_pal;

pll_reconfig pll_reconfig_inst
(
    .busy(pll_reconfig_busy),
    .clock(clk_32),
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

pll_vic20 pll_vic20
(
    .inclk0(CLK12M),
    .c0(clk_sys),  //35.48 MHz PAL, 28.63 MHz NTSC
    .areset(pll_areset),
    .scanclk(pll_scanclk),
    .scandata(pll_scandata),
    .scanclkena(pll_scanclkena),
    .configupdate(pll_configupdate),
    .scandataout(pll_scandataout),
    .scandone(pll_scandone),
    .locked(pll_locked)
);

always @(posedge clk_32) begin
    reg ntsc_d, ntsc_d2, ntsc_d3;
    reg [1:0] pll_reconfig_state = 0;
    reg [9:0] pll_reconfig_timeout;

    ntsc_d <= st_ntsc;
    ntsc_d2 <= ntsc_d;
    pll_write_from_rom <= 0;
    pll_reconfig <= 0;
    pll_reconfig_reset <= 0;
    case (pll_reconfig_state)
    2'b00:
    begin
        ntsc_d3 <= ntsc_d2;
        if (ntsc_d2 ^ ntsc_d3) begin
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

pll27 pll
(
    .inclk0(CLK12M),
    .c0(clk_32) //32 MHz
);

always @(posedge clk_sys) begin
    reg [4:0] sys_count;
    clk8m <= ~|sys_count[1:0];
    clk_ref <= ~|sys_count[3:0];
    sys_count <= sys_count + 1'd1;

    reset <= st_reset | st_cart_unload | buttons[1] | rom_download | force_reset | fn_keys[10] | ~pll_locked;
    cart_unload <= 0;
    if (st_cart_unload | buttons[1] | (fn_keys[10] & mod_keys[0])) cart_unload <= 1;
    c1541_reset <= reset;
end

//////////////////   MIST ARM I/O   ///////////////////
wire        ps2Clk;
wire        ps2Data;

wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;

// status word wires (9 is unused)
wire [31:0] status;
wire        st_reset               = status[0];
wire        st_cart_unload         = status[1];
wire        st_crt_no_load_address = status[2];
wire        st_ntsc                = status[3];
wire  [1:0] st_ram_expansion       = status[5:4];
wire        st_3k_expansion        = status[6];
wire  [1:0] st_8k_rom              = status[8:7];
wire        st_audio_filter        = ~status[9];
wire  [1:0] st_scanlines           = status[11:10];
wire        st_tap_play_btn        = status[12];
wire        st_tape_sound          = status[13];
wire        st_blend               = status[14];
wire        st_megacart            = status[15];
wire        st_writenv             = status[16];

wire [31:0] sd_lba;
wire [1:0]  sd_rd;
wire [1:0]  sd_wr;
wire        sd_ack;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire  [8:0] sd_buff_addr;
wire  [1:0] img_mounted;
wire [31:0] img_size;

// Multiplexers for sd related signals.
wire uio_sel_nvram, sd_busy_1541;

wire [31:0] sd_lba_nvram, sd_lba_1541;
assign sd_lba = uio_sel_nvram ? sd_lba_nvram : sd_lba_1541;

wire sd_rd_nvram, sd_rd_1541;
assign sd_rd[1] = uio_sel_nvram ? sd_rd_nvram : 1'b0;
assign sd_rd[0] = uio_sel_nvram ? 1'b0 : sd_rd_1541;

wire sd_wr_nvram, sd_wr_1541;
assign sd_wr[1] = uio_sel_nvram ? sd_wr_nvram : 1'b0;
assign sd_wr[0] = uio_sel_nvram ? 1'b0 : sd_wr_1541;

wire [7:0] sd_din_nvram, sd_din_1541;
assign sd_din = uio_sel_nvram ? sd_din_nvram : sd_din_1541;

wire sd_ack_nvram, sd_ack_1541;
assign sd_ack_nvram = uio_sel_nvram ? sd_ack : 1'b0;
assign sd_ack_1541 = uio_sel_nvram ? 1'b0 : sd_ack;

wire sd_strobe_nvram, sd_strobe_1541;
assign sd_strobe_nvram = uio_sel_nvram ? sd_dout_strobe : 1'b0;
assign sd_strobe_1541 = uio_sel_nvram ? 1'b0 : sd_dout_strobe;

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
    .clk_sd(clk_1541),
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
    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .ps2_kbd_clk(ps2Clk),
    .ps2_kbd_data(ps2Data),

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

wire  [7:0] col_in;
wire  [7:0] row_out;
wire  [7:0] row_in;
wire  [7:0] col_out;
wire [11:1] fn_keys;
wire  [2:0] mod_keys;

keyboard keyboard
(
    .reset(reset),
    .clk_sys(clk_sys),
    .ps2_kbd_clk(ps2Clk),
    .ps2_kbd_data(ps2Data),
    .col_in(col_in),
    .row_out(row_out),
    .row_in(row_in),
    .col_out(col_out),
    .Fn(fn_keys),
    .mod(mod_keys)
);

wire  [7:0] vic20_joy = joystick_0 | joystick_1;

wire vic_wr_n;
wire vic_rom_sel;
wire vic_io2_sel;
wire vic_io3_sel;
wire vic_blk123_sel;
wire vic_blk5_sel;
wire vic_ram123_sel;

wire [7:0] to_vic;
wire [7:0] from_vic;

vic20 #(.I_EXTERNAL_ROM(1'b1)) VIC20
(
    .I_SYSCLK(clk_sys),
    .I_SYSCLK_EN(clk8m),
    .I_PAUSE(ioctl_download),
    .I_RESET(reset | mc_reset),
    .I_PAL(~st_ntsc),

    .I_JOY(~{vic20_joy[0],vic20_joy[1],vic20_joy[2],vic20_joy[3]}),
    .I_FIRE(~vic20_joy[4]),
    .O_VIDEO_R(R_O),
    .O_VIDEO_G(G_O),
    .O_VIDEO_B(B_O),
    .O_HSYNC(HS_O),
    .O_VSYNC(VS_O),
    .O_DE(DE_O),

    .atn_o(vic20_iec_atn_o),
    .clk_o(vic20_iec_clk_o),
    .data_o(vic20_iec_data_o),
    .clk_i(c1541_iec_clk_o),
    .data_i(c1541_iec_data_o),

    .O_ROW_IN(row_in),
    .I_COL_OUT(col_out),
    .O_COL_IN(col_in),
    .I_ROW_OUT(row_out),
    .I_RESTORE_OUT(fn_keys[11]),

    .I_CART_EN(st_megacart | (|st_8k_rom)),  // at $A000(8k)
    .I_CART_RO(st_megacart ? 1'b0 : (st_8k_rom != 2'd2)),
    .I_RAM_EXT(st_megacart ? 4'b1111 : {&st_ram_expansion, st_ram_expansion[1], |st_ram_expansion, st_3k_expansion}), //at $6000(8k),$4000(8k),$2000(8k),$0400(3k)

    .O_CASS_WRITE(cass_write),
    .I_CASS_READ(cass_read),
    .O_CASS_MOTOR(cass_motor),
    .I_CASS_SENSE(cass_sense),

    .O_AUDIO(vic_audio),
    .O_AUDIO_FILTERED(vic_audio_filtered),

    .o_extmem_sel(sdram_en),
    .o_extmem_r_wn(vic_wr_n),
    .o_extmem_addr(sdram_vic20_a),
    .i_extmem_data(to_vic),
    .o_extmem_data(from_vic),
    .o_rom_sel(vic_rom_sel),
    .o_io2_sel(vic_io2_sel),
    .o_io3_sel(vic_io3_sel),
    .o_blk123_sel(vic_blk123_sel),
    .o_blk5_sel(vic_blk5_sel),
    .o_ram123_sel(vic_ram123_sel),

    .o_p2_h(p2_h),

    // -- ROM setup bus
    .CONF_WR(ioctl_internal_memory_wr & ioctl_ram_wr),
    .CONF_AI(ioctl_target_addr[15:0]),
    .CONF_DI(ioctl_reg_inject_state ? ioctl_reg_data : ioctl_dout)
);

//////////////////   MEMORY   //////////////////
assign SDRAM_CLK = clk_sys;

wire  [7:0] sdram_out;
wire [15:0] sdram_vic20_a;
wire [22:0] sdram_a;
wire        sdram_en;
reg         sdram_access;
wire        p2_h;

wire [22:0] sdram_vic20_a_adj =
    cart_unload ? 16'ha004 : 
    sdram_vic20_a[15:13] == 3'b111 ? { st_ntsc, sdram_vic20_a } : // NTSC/PAL Kernal
	 mc_sdram_addr;
//   sdram_vic20_a;

always_comb begin
    casex ({megacart_download | rom_download | prg_download | tap_download, p2_h})
    'b01 : sdram_a = sdram_vic20_a_adj;
    'b00 : sdram_a = tap_play_addr;
    'b1X : sdram_a = ioctl_target_addr;
    endcase
end

wire mc_reset;
wire [22:0] mc_sdram_addr;
wire [7:0] mc_to_vic;
wire mc_sdram_wr_n;
wire mc_rom_sel;
wire mc_nvram_sel;
wire mc_qm;

megacart mc
(
	.clk(clk_sys),
	.reset_n(pll_locked & !st_cart_unload & !force_reset),
	.active(st_megacart),
	.vic_addr(sdram_vic20_a),
	.vic_wr_n(vic_wr_n),
//	.vic_sdram_en(sdram_en),
	.vic_io2_sel(vic_io2_sel),
	.vic_io3_sel(vic_io3_sel),
	.vic_blk123_sel(vic_blk123_sel),
	.vic_blk5_sel(vic_blk5_sel),
	.vic_ram123_sel(vic_ram123_sel),
	.from_vic(from_vic),
	.to_vic(mc_to_vic),
	.mc_addr(mc_sdram_addr),
	.mc_wr_n(mc_sdram_wr_n),
	.mc_rom_sel(mc_rom_sel),
	.mc_nvram_sel(mc_nvram_sel),
	.mc_qm(mc_qm),
//	.mc_sdram_en(mc_sdram_en),
	.mc_soft_reset(mc_reset)
);

wire [7:0] mc_nvram_out;

megacart_nvram nvr
(
	// VIC20 interface
	.clk_a          ( clk_sys         ),
	.reset_n        ( pll_locked & !st_cart_unload ),
	.a_a            ( sdram_vic20_a   ),
	.d_a            ( from_vic        ),
	.q_a            ( mc_nvram_out    ),
	.we_a           ( mc_nvram_sel & ~mc_sdram_wr_n ),
	// UserIO interface
	.clk_b          ( clk_1541        ),
	.readnv         ( img_mounted[1]  ),
	.writenv        ( st_writenv      ),
	.uio_busy       ( sd_busy_1541    ),
	.nvram_sel      ( uio_sel_nvram   ),
	.sd_lba         ( sd_lba_nvram    ),
	.sd_rd          ( sd_rd_nvram     ),
	.sd_wr          ( sd_wr_nvram     ),
	.sd_ack         ( sd_ack_nvram    ),
	.sd_buff_din    ( sd_din_nvram    ),
	.sd_buff_dout   ( sd_dout         ),
	.sd_buff_wr     ( sd_strobe_nvram ),
	.sd_buff_addr   ( sd_buff_addr    ),
	.img_size       ( img_size )
);


// Megacart can drive the data bus - as can NVRAM.
assign to_vic = mc_qm ? mc_to_vic : (mc_nvram_sel ? mc_nvram_out : sdram_out);

// SDRAM port arbitration

wire [7:0] sdram_in;
assign sdram_in =
	(megacart_download | rom_download | prg_download | tap_download) ? ioctl_dout
		: from_vic;

wire sdram_we;
assign sdram_we = (sdram_en & ~mc_sdram_wr_n) || // Write originates from VIC20
	cart_unload ||
	( ioctl_ram_wr &&
		(((rom_download || prg_download) && !ioctl_internal_memory_wr) ||
		(megacart_download || tap_download))
	);

wire sdram_oe;
assign sdram_oe = p2_h ? sdram_en & mc_sdram_wr_n : tap_sdram_oe;

wire [1:0] sdram_bank;
assign sdram_bank = {mc_nvram_sel,mc_rom_sel | megacart_download};

sdram ram
(
    .*,
    .clkref(ioctl_download ? ioctl_wr : p2_h),
    .init(~pll_locked),
    .clk(clk_sys),
    .bank(sdram_bank),
    .dout(sdram_out),
    .din (sdram_in),
    .addr(sdram_a),
    .we(sdram_we),
    .oe(sdram_oe)
);

//////////////////  PRG/ROM/TAP LOAD //////////////
wire        ioctl_wr;
wire        ioctl_ram_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        rom_download = ioctl_download && !ioctl_index;
wire        prg_download = ioctl_download && (ioctl_index == 8'h01 || ioctl_index == 8'h41);
wire        tap_download = ioctl_download && ioctl_index == 8'h81;
wire        megacart_download = ioctl_download && (ioctl_index==8'h02);
reg   [4:0] ioctl_reg_inject_state = 0;
wire [22:0] ioctl_target_addr;
reg  [22:0] ioctl_tap_addr;
reg  [15:0] ioctl_prg_addr;
reg  [15:0] ioctl_reg_addr;
reg         ioctl_reg_wr;
reg   [7:0] ioctl_reg_data;

data_io data_io (
    // SPI interface
    .SPI_SCK        ( SPI_SCK ),
    .SPI_SS2        ( SPI_SS2 ),
    .SPI_DI         ( SPI_DI  ),
    // ram interface
    .clk_sys        ( clk_sys ),
    .clkref_n       ( ~clk_ref  ),
    .ioctl_download ( ioctl_download ),
    .ioctl_index    ( ioctl_index ),
    .ioctl_wr       ( ioctl_wr ),
    .ioctl_addr     ( ioctl_addr ),
    .ioctl_dout     ( ioctl_dout )
);

always_comb begin
    casex ({megacart_download , tap_download, rom_download, ioctl_addr[15:13]})
        'b0X1_00X: ioctl_target_addr = {7'h0, 2'b00, ioctl_addr[13:0]}; //1541
        'b0X1_010: ioctl_target_addr = {7'h0, 3'b111, ioctl_addr[12:0]}; //kernal pal
        'b0X1_011: ioctl_target_addr = {7'h1, 3'b111, ioctl_addr[12:0]}; //kernal ntsc
        'b0X1_100: ioctl_target_addr = {7'h0, 3'b110, ioctl_addr[12:0]}; //basic
        'b0X1_101: ioctl_target_addr = {7'h0, 4'b1000, ioctl_addr[11:0]}; //character
        'b000_XXX: ioctl_target_addr = {7'h0, ioctl_reg_inject_state ? ioctl_reg_addr : ioctl_prg_addr};
        'b010_XXX: ioctl_target_addr = ioctl_tap_addr;
        'b100_XXX: ioctl_target_addr = ioctl_addr[22:0];
         default: ioctl_target_addr = 0;
    endcase;
end

wire ioctl_internal_memory_wr =
    ioctl_reg_inject_state ||
    (rom_download && (ioctl_target_addr[15:13] == 3'b101)) || // only char rom is internal
    (prg_download && (ioctl_target_addr[15:10] == 6'b000000 ||
                      ioctl_target_addr[15:11] == 5'b00010 ||
                      ioctl_target_addr[15:11] == 5'b00011 ||
                      ioctl_target_addr[15:10] == 6'b100101));

always @(posedge clk_sys) begin
    reg old_prg_download;
    reg old_mc_download;
    reg auto_reset;

    force_reset <= 0;
    old_prg_download <= prg_download;
    old_mc_download <= megacart_download;
    ioctl_ram_wr <= 0;
    if (prg_download && ioctl_wr) begin
        if (~st_crt_no_load_address) begin //cart/prg loading with address in the first 2 bytes
            if (ioctl_addr == 16'h0000) ioctl_prg_addr[7:0] <= ioctl_dout; else
            if (ioctl_addr == 16'h0001) ioctl_prg_addr[15:8] <= ioctl_dout; else begin
                ioctl_ram_wr <= 1;
                if (ioctl_addr != 16'h0002 && ioctl_prg_addr != 16'hbfff) ioctl_prg_addr <= ioctl_prg_addr + 1'd1;
            end
        end else begin
            if (ioctl_addr == 0)
                ioctl_prg_addr <= 16'ha000; // load to $a000 without header
            else if (ioctl_prg_addr != 16'hbfff)
                ioctl_prg_addr <= ioctl_prg_addr + 1'd1; // increment load addr, but don't overwrite ROMs
            ioctl_ram_wr <= 1;
        end
        if (ioctl_prg_addr == 16'ha000) auto_reset <= 1;
    end
    if (tap_download && ioctl_wr) begin
        ioctl_tap_addr <= ioctl_addr ? ioctl_tap_addr + 1'd1 : TAP_MEM_START; //load tap to 20000
        ioctl_ram_wr <= 1;
    end
    if (rom_download) ioctl_ram_wr <= ioctl_wr;
    if (megacart_download) ioctl_ram_wr <= ioctl_wr;
    if (old_mc_download & ~megacart_download) force_reset<=1'b1;

    //prg download ended, adjust registers
    if (old_prg_download & ~prg_download) ioctl_reg_inject_state <= 1;
    
    case (ioctl_reg_inject_state)
		 1: begin ioctl_reg_addr <= 16'h2d; ioctl_reg_data <= ioctl_prg_addr[7:0];  ioctl_ram_wr <= 1; end
		 3: begin ioctl_reg_addr <= 16'h2e; ioctl_reg_data <= ioctl_prg_addr[15:8]; ioctl_ram_wr <= 1; end
		 5: begin ioctl_reg_addr <= 16'h2f; ioctl_reg_data <= ioctl_prg_addr[7:0];  ioctl_ram_wr <= 1; end
		 7: begin ioctl_reg_addr <= 16'h30; ioctl_reg_data <= ioctl_prg_addr[15:8]; ioctl_ram_wr <= 1; end
		 9: begin ioctl_reg_addr <= 16'h31; ioctl_reg_data <= ioctl_prg_addr[7:0];  ioctl_ram_wr <= 1; end
		11: begin ioctl_reg_addr <= 16'h32; ioctl_reg_data <= ioctl_prg_addr[15:8]; ioctl_ram_wr <= 1; end
		13: begin ioctl_reg_addr <= 16'hae; ioctl_reg_data <= ioctl_prg_addr[7:0];  ioctl_ram_wr <= 1; end
		15: begin ioctl_reg_addr <= 16'haf; ioctl_reg_data <= ioctl_prg_addr[15:8]; ioctl_ram_wr <= 1; end
		31: begin force_reset <= auto_reset; auto_reset <= 0; end
    endcase

    if (ioctl_reg_inject_state) ioctl_reg_inject_state <= ioctl_reg_inject_state + 1'd1;
end

//////////////////   TAPE   //////////////////

reg [22:0] tap_play_addr;
reg [22:0] tap_last_addr;
reg  [7:0] tap_data_in;
reg        tap_reset;
reg        tap_wrreq;
reg        tap_wrfull;
reg        tap_version;
reg        tap_sdram_oe;
wire       cass_read;
wire       cass_write;
wire       cass_motor;
wire       cass_sense;

always @(posedge clk_sys) begin
    reg p2_hD;

    if (reset) begin
        tap_play_addr <= TAP_MEM_START;
        tap_last_addr <= TAP_MEM_START;
        tap_sdram_oe <= 0;
        tap_reset <= 1;
    end else begin
        tap_reset <= 0;
        if (tap_download) begin
            tap_play_addr <= TAP_MEM_START;
            tap_last_addr <= ioctl_tap_addr;
            tap_reset <= 1;
            if (ioctl_addr == 24'h0C && ioctl_wr) begin
                tap_version <= ioctl_dout[0];
            end
        end
        p2_hD <= p2_h;
        tap_wrreq <= 0;
        if (p2_hD && !p2_h && !ioctl_download && tap_play_addr != tap_last_addr && !tap_wrfull) tap_sdram_oe <= 1;
        if (!p2_h && tap_sdram_oe) tap_data_in <= sdram_out;
        if (p2_h && !p2_hD && tap_sdram_oe) begin
            tap_wrreq <= 1;
            tap_sdram_oe <= 0;
            tap_play_addr <= tap_play_addr + 1'd1;
        end
    end
end

c1530 c1530
(
    .clk32(clk_sys),
    .restart_tape(tap_reset),
    .wav_mode(0),
    .tap_version(tap_version),
    .host_tap_in(tap_data_in),
    .host_tap_wrreq(tap_wrreq),
    .tap_fifo_wrfull(tap_wrfull),
    .tap_fifo_error(),
    .cass_read(cass_read),
    .cass_write(cass_write),
    .cass_motor(cass_motor),
    .cass_sense(cass_sense),
    .osd_play_stop_toggle(st_tap_play_btn | fn_keys[9]),
    .ear_input(ear_input)
);
//////////////////   AUDIO   //////////////////

wire [15:0] vic_audio, vic_audio_filtered;
wire [15:0] audio_sel = st_audio_filter ? vic_audio_filtered : vic_audio;
wire [15:0] cass_audio = { 1'd0, (~cass_read | (cass_write & ~cass_motor & ~cass_sense)), 11'd0 };  // silence cass_write when motor is off because bit is in common with keyboard
wire [16:0] audio_out = st_tape_sound ? audio_sel + cass_audio : audio_sel;

sigma_delta_dac #(15) dac_l
(
    .CLK(clk_sys),
    .RESET(reset),
    .DACin(audio_out[16] ? 16'hffff : audio_out),
    .DACout(AUDIO_L)
);

sigma_delta_dac #(15) dac_r
(
    .CLK(clk_sys),
    .RESET(reset),
    .DACin(audio_out[16] ? 16'hffff : audio_out),
    .DACout(AUDIO_R)
);

wire [31:0] vic20_clk_rate = st_ntsc ? 32'd28_630_000 : 32'd35_480_000;

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(vic20_clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(audio_out[16] ? 16'h7fff : {~audio_out[15], audio_out[14:0]}),
	.right_chan(audio_out[16] ? 16'h7fff : {~audio_out[15], audio_out[14:0]})
);
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(reset),
	.clk_rate_i(vic20_clk_rate),
	.spdif_o(SPDIF),
	.sample_i({2{audio_out[16] ? 16'h7fff : {~audio_out[15], audio_out[14:0]}}})
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
//////////////////   VIDEO   //////////////////

wire  [3:0] R_O;
wire  [3:0] G_O;
wire  [3:0] B_O;
wire        HS_O;
wire        VS_O;
wire        DE_O;

wire        hs,vs;

mist_video #(.COLOR_DEPTH(4), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (
    .clk_sys     ( clk_sys    ),

    // OSD SPI interface
    .SPI_SCK     ( SPI_SCK    ),
    .SPI_SS3     ( SPI_SS3    ),
    .SPI_DI      ( SPI_DI     ),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines   ( st_scanlines  ),

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
    .blend       ( st_blend   ),

    // video in
    .R           ( R_O        ),
    .G           ( G_O        ),
    .B           ( B_O        ),

    .HSync       ( HS_O       ),
    .VSync       ( VS_O       ),

    // MiST video output signals
    .VGA_R       ( VGA_R      ),
    .VGA_G       ( VGA_G      ),
    .VGA_B       ( VGA_B      ),
    .VGA_VS      ( vs         ),
    .VGA_HS      ( hs         )
);

// Use different alignment of csync @15kHz
wire   cs = ~(~HS_O | ~VS_O);
assign VGA_HS = (~no_csync & scandoubler_disable & ~ypbpr) ? cs : hs;
assign VGA_VS = (~no_csync & scandoubler_disable & ~ypbpr) ? 1'b1 : vs;

`ifdef USE_HDMI
i2c_master #(35_480_000) i2c_master (
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

mist_video #(.COLOR_DEPTH(4), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1'b1)) hdmi_video (
    .clk_sys     ( clk_sys    ),

    // OSD SPI interface
    .SPI_SCK     ( SPI_SCK    ),
    .SPI_SS3     ( SPI_SS3    ),
    .SPI_DI      ( SPI_DI     ),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines   ( st_scanlines  ),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider  ( 1'b0       ),

    // 0 = HVSync 31KHz, 1 = CSync 15KHz
    .scandoubler_disable ( 1'b0 ),
    // disable csync without scandoubler
    .no_csync    ( 1'b1       ),
    // YPbPr always uses composite sync
    .ypbpr       ( 1'b0       ),
    // Rotate OSD [0] - rotate [1] - left or right
    .rotate      ( 2'b00      ),
    // composite-like blending
    .blend       ( st_blend   ),

    // video in
    .R           ( R_O        ),
    .G           ( G_O        ),
    .B           ( B_O        ),

    .HSync       ( HS_O       ),
    .VSync       ( VS_O       ),
    .HBlank      ( ~DE_O      ),
    .VBlank      ( ~VS_O      ),

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

//////////////////   DISK   //////////////////

wire led_disk;
wire vic20_iec_atn_o;
wire vic20_iec_data_o;
wire vic20_iec_clk_o;

wire c1541_iec_atn_o;
wire c1541_iec_data_o;
wire c1541_iec_clk_o;

reg disk_present;
always @(posedge clk_1541)
	disk_present <= |img_size;

reg c1541_reset_32_d;
reg c1541_reset_32;

// Sync reset to the 32MHz domain since some of the logic inside
// the emulated drive uses synchronous resets.
always @(posedge clk_1541) begin
	c1541_reset_32_d<=c1541_reset;
	c1541_reset_32<=c1541_reset_32_d;
end

c1541_sd c1541_sd (
    .clk32 ( clk_1541 ),
    .reset ( c1541_reset_32 ),

    .disk_change ( img_mounted[0] ),
    .disk_mount ( disk_present),
    .disk_num ( 10'd0 ), // always 0 on MiST, the image is selected by the OSD menu

    .iec_atn_i  ( vic20_iec_atn_o  ),
    .iec_data_i ( vic20_iec_data_o ),
    .iec_clk_i  ( vic20_iec_clk_o  ),
    .iec_data_o ( c1541_iec_data_o ),
    .iec_clk_o  ( c1541_iec_clk_o ),

    .sd_lba         ( sd_lba_1541    ),
    .sd_rd          ( sd_rd_1541     ),
    .sd_wr          ( sd_wr_1541     ),
    .sd_ack         ( sd_ack_1541    ),
    .sd_buff_din    ( sd_din_1541    ),
    .sd_buff_dout   ( sd_dout        ),
    .sd_buff_wr     ( sd_strobe_1541 ),
    .sd_buff_addr   ( sd_buff_addr   ),
    .sd_busy_o      ( sd_busy_1541   ),
    .led            ( led_disk       ),

    .c1541rom_clk   ( clk_sys         ),
    .c1541rom_addr  ( ioctl_addr[13:0]),
    .c1541rom_data  ( ioctl_dout      ),
    .c1541rom_wr    ( ioctl_wr & rom_download & !ioctl_addr[15:14] )
);

endmodule
