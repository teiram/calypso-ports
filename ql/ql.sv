//
// ql.v - Sinclair QL for the Calypso
//
// https://github.com/mist-devel
// 
// Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module ql (
   input CLK12M,

	// LED outputs
   output [7:0]         LED,            // LED Yellow
	
   // SDRAM interface
   inout [15:0]    SDRAM_DQ,       // SDRAM Data bus 16 Bits
   output [11:0]   SDRAM_A,        // SDRAM Address bus 12 Bits
   output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
   output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
   output          SDRAM_nWE,      // SDRAM Write Enable
   output          SDRAM_nCAS,     // SDRAM Column Address Strobe
   output          SDRAM_nRAS,     // SDRAM Row Address Strobe
   output          SDRAM_nCS,      // SDRAM Chip Select
   output [1:0]    SDRAM_BA,       // SDRAM Bank Address
   output          SDRAM_CLK,      // SDRAM Clock
   output          SDRAM_CKE,      // SDRAM Clock Enable
  
   // SPI interface to arm io controller
   output      SPI_DO,
   input       SPI_DI,
   input       SPI_SCK,
   input       SPI_SS2,
   input       SPI_SS3,
   input       SPI_SS4,
   input       CONF_DATA0, 

	output 		AUDIO_L, // sigma-delta DAC output left
	output 		AUDIO_R, // sigma-delta DAC output right

   output VGA_HS,
   output VGA_VS,
   output [3:0] VGA_R,
   output [3:0] VGA_G,
   output [3:0] VGA_B
);

// -------------------------------------------------------------------------
// ------------------------------ user_io ----------------------------------
// -------------------------------------------------------------------------

// user_io implements a connection to the io controller and receives various
// kind of user input from there (keyboard, buttons, mouse). It is also used
// by the fake SD card to exchange data with the real sd card connected to the
// io controller

// the configuration string is returned to the io controller to allow
// it to control the menu on the OSD 
parameter CONF_STR = {
        "QL;;",
        "F,MDV,Load MDV1;",
        "F,MDV,Load MDV2;",
        "F,ROM;",
        "O2,QL Speed,YES,NO;",
        "O3,RAM,128k,640k;",
        "O4,Video mode,PAL,NTSC;",
        "O56,Scanlines,Off,25%,50%,75%;",
        "T0,Reset"
};

// the status register is controlled by the on screen display (OSD)
wire [63:0] status;
wire tv15khz;
wire [1:0] buttons;
wire ypbpr, no_csync;

wire [7:0] js0, js1;

wire       ntsc      = status[4];
wire [1:0] scanlines = status[6:5];

wire ps2_kbd_clk, ps2_kbd_data;
wire ps2_mouse_clk, ps2_mouse_data;

// include user_io module for arm controller communication
user_io #(.STRLEN($size(CONF_STR)>>3)) user_io (
	.clk_sys        ( clk21          ),
	.clk_sd         ( clk42          ),
	.conf_str       ( CONF_STR       ),

	.SPI_CLK        ( SPI_SCK        ),
	.SPI_SS_IO      ( CONF_DATA0     ),
	.SPI_MISO       ( SPI_DO         ),
	.SPI_MOSI       ( SPI_DI         ),

	.scandoubler_disable ( tv15khz   ),
	.buttons        ( buttons        ),

	.joystick_0     ( js0            ),
	.joystick_1     ( js1            ),

	// ps2 interface
	.ps2_kbd_clk    ( ps2_kbd_clk    ),
	.ps2_kbd_data   ( ps2_kbd_data   ),
	.ps2_mouse_clk  ( ps2_mouse_clk  ),
	.ps2_mouse_data ( ps2_mouse_data ),

	.status         ( status         ),
	.ypbpr          ( ypbpr          ),
	.no_csync       ( no_csync       ),

	// interface to embedded legacy sd card wrapper
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
	.sd_buff_addr   ( sd_buff_addr   )
);

// -------------------------------------------------------------------------
// ---------------- fake sd card for use with ql-sd ------------------------
// -------------------------------------------------------------------------

// conections between user_io (implementing the SPIU communication 
// to the io controller) and the legacy 
wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack, sd_ack_conf;
wire sd_conf;
wire sd_sdhc; 
wire [7:0] sd_dout;
wire sd_dout_strobe;
wire [7:0] sd_din;
wire sd_din_strobe;
wire [8:0] sd_buff_addr;

sd_card sd_card (
	.clk_sys         ( clk42          ),   // at least 2xsd_sck
	// connection to io controller
	.sd_lba          ( sd_lba         ),
	.sd_rd           ( sd_rd          ),
	.sd_wr           ( sd_wr          ),
	.sd_ack          ( sd_ack         ),
	.sd_conf         ( sd_conf        ),
	.sd_ack_conf     ( sd_ack_conf    ),
	.sd_sdhc         ( sd_sdhc        ),
	.sd_buff_dout    ( sd_dout        ),
	.sd_buff_wr      ( sd_dout_strobe ),
	.sd_buff_din     ( sd_din         ),
	.sd_buff_addr    ( sd_buff_addr   ),

	.allow_sdhc 	( 1'b1            ),   // QLSD supports SDHC

	// connection to local CPU
	.sd_cs   		( sd_cs           ),
	.sd_sck  		( sd_sck          ),
	.sd_sdi  		( sd_sdi          ),
	.sd_sdo  		( sd_sdo          )
);

wire qlsd_rd = cpu_rom && (cpu_addr[15:0] == 16'hfee4);  // only one register actually returns data
wire [7:0] qlsd_dout;
wire sd_cs, sd_sck, sd_sdi, sd_sdo;

qlromext qlromext (
	.clk           ( clk21          ),   // fastest we can offer
	.clk_bus       ( clk2           ),
	.romoel        ( !(cpu_rom && cpu_cycle) ),
	.a             ( cpu_addr[15:0]	),
	.d             ( qlsd_dout      ),
	.sd_do         ( sd_sdo         ),
	.sd_cs1l       ( sd_cs          ),
	.sd_clk        ( sd_sck         ),
	.sd_di         ( sd_sdi         ),
	.io2           ( 1'b0           )
);

// -------------------------------------------------------------------------
// ---------------- interface to the external sdram ------------------------
// -------------------------------------------------------------------------

// SDRAM control signals
assign SDRAM_CKE = 1'b1;

// CPU and data_io share the same bus cycle. Thus the CPU cannot run while
// (ROM) data is being downloaded which wouldn't make any sense, anyway
// during ROM download data_io writes the ram. Otherwise the CPU
wire [24:0] sys_addr = dio_download?dio_addr[24:0]:{ 6'b000000, cpu_addr[19:1]} ;
wire sys_uds = dio_download?1'b1:cpu_uds;
wire sys_lds = dio_download?1'b1:cpu_lds;
wire [15:0] sys_dout = dio_download?dio_data:cpu_dout;
wire sys_wr =          dio_download?dio_write:(cpu_wr && cpu_ram);
wire sys_oe =          dio_download?1'b0:(cpu_rd && cpu_mem);

// microdrive emulation and video share the video cycle time slot
// only one drive at a time is accessed
wire [24:0] video_cycle_addr = (mdv_read || mdv2_read)?(mdv_seldrive?mdv2_addr:mdv_addr):{6'd0, video_addr};
wire video_cycle_rd = (mdv_read || mdv2_read)?1'b1:video_rd;


// video and CPU/data_io time share the sdram bus
wire [24:0] sdram_addr = video_cycle?video_cycle_addr:sys_addr;
wire sdram_wr = video_cycle?1'b0:sys_wr;
wire sdram_oe = video_cycle?video_cycle_rd:sys_oe;
wire sdram_uds = video_cycle?1'b1:sys_uds;
wire sdram_lds = video_cycle?1'b1:sys_lds;
wire [15:0] sdram_dout;
wire [15:0] sdram_din = sys_dout;

sdram sdram (
   // interface to the W9864G6JT chip
   .sd_data        ( SDRAM_DQ                  ),
   .sd_addr        ( SDRAM_A                   ),
   .sd_dqm         ( {SDRAM_DQMH, SDRAM_DQML}  ),
   .sd_cs          ( SDRAM_nCS                 ),
   .sd_ba          ( SDRAM_BA                  ),
   .sd_we          ( SDRAM_nWE                 ),
   .sd_ras         ( SDRAM_nRAS                ),
   .sd_cas         ( SDRAM_nCAS                ),

   // system interface
   .clk            ( clk21                    ),
   .clkref         ( clk2                  ),
   .init           ( !pll_locked               ),

   // cpu interface
   .din            ( sdram_din                 ),
   .addr           ( sdram_addr                ),
   .we             ( sdram_wr                  ),
   .oe             ( sdram_oe                  ),
	.uds            ( sdram_uds                 ),
	.lds            ( sdram_lds                 ),
   .dout           ( sdram_dout                )
);


// ---------------------------------------------------------------------------------
// ------------------------------------- data io -----------------------------------
// ---------------------------------------------------------------------------------

wire dio_download;
wire [4:0] dio_index;
wire [24:0] dio_addr;
wire [15:0] dio_data;
wire dio_write;

// include ROM download helper
// this receives a byte stream from the arm io controller via spi and 
// writes it into sdram
data_io data_io (
	// io controller spi interface
	.sck ( SPI_SCK ),
	.ss  ( SPI_SS2 ),
	.sdi ( SPI_DI  ),

	.downloading ( dio_download ),  // signal indicating an active rom download
	.index       ( dio_index ),
  
	// external ram interface
	.clk   ( cpu_cycle ),
	.wr    ( dio_write ),
	.addr  ( dio_addr  ),
	.data  ( dio_data  )
);

// ---------------------------------------------------------------------------------
// -------------------------------------- video ------------------------------------
// ---------------------------------------------------------------------------------

wire video_r, video_g, video_b;
wire video_hs, video_vs;
wire VBlank;

wire [18:0] video_addr;
wire video_rd;

// the zx8301 has only one write-only register at $18063
wire zx8301_cs = cpu_cycle && cpu_io && 
	({cpu_addr[6:5], cpu_addr[1]} == 3'b111)&& cpu_wr && cpu_lds;	

zx8301 zx8301 (
	.reset        ( reset         ),
	.clk_vga      ( clk21        ),
	.clk_video    ( clk10      ),
	.video_cycle  ( video_cycle   ),

	.ntsc         ( ntsc     ),

	.clk_bus      ( clk2     ),
	.cpu_cs       ( zx8301_cs     ),
	.cpu_data     ( cpu_dout[7:0] ),

	.mdv_men      ( mdv_men       ),
	 
	.addr         ( video_addr    ),
	.din          ( sdram_dout    ),
	.rd           ( video_rd      ),
	 
	.hs           ( video_hs      ),
	.vs           ( video_vs      ),
	.r            ( video_r       ),
	.g            ( video_g       ),
	.b            ( video_b       ),
	.VBlank			( VBlank			 )
);

mist_video #(.COLOR_DEPTH(1), .OSD_COLOR(3'd5), .SD_HCNT_WIDTH(11)) mist_video (
	.clk_sys     ( clk21      ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b1       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( tv15khz ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( video_r    ),
	.G           ( video_g    ),
	.B           ( video_b    ),

	.HSync       ( video_hs   ),
	.VSync       ( ~video_vs  ),

	// MiST video output signals
	.VGA_R       ( mist_vga_r      ),
	.VGA_G       ( mist_vga_g      ),
	.VGA_B       ( mist_vga_b      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

reg [5:0] mist_vga_r;
reg [5:0] mist_vga_g;
reg [5:0] mist_vga_b;
assign VGA_R = mist_vga_r[5:2];
assign VGA_G = mist_vga_g[5:2];
assign VGA_B = mist_vga_b[5:2];

// ---------------------------------------------------------------------------------
// -------------------------------------- reset ------------------------------------
// ---------------------------------------------------------------------------------

wire rom_download = dio_download && (dio_index == 0 || dio_index == 3);
reg [11:0] reset_cnt;
wire reset = (reset_cnt != 0);
always @(posedge clk2) begin
	if(buttons[1] || status[0] || !pll_locked || rom_download)
		reset_cnt <= 12'hfff;
	else if(reset_cnt != 0)
		reset_cnt <= reset_cnt - 1'd1;
end

// ---------------------------------------------------------------------------------
// --------------------------------------- IO --------------------------------------
// ---------------------------------------------------------------------------------

wire zx8302_sel = cpu_cycle && cpu_io && !cpu_addr[6];
wire [1:0] zx8302_addr = {cpu_addr[5], cpu_addr[1]};
wire [15:0] zx8302_dout;

wire mdv_download = (dio_index == 1) && dio_download;		//signal for active download from SD
wire mdv2_download = (dio_index == 2) && dio_download;	//signal for active download from SD
wire mdv_men;        //signal telling mdv emulation that it may use the video
wire mdv_read;
wire mdv2_read;
wire [24:0] mdv_addr;
wire [24:0] mdv2_addr;
wire mdv_seldrive;	//1 for MDV2_ active, 0 for MDV1_ active or nothing
wire mdv_active;		//Any active mdv

wire audio;
assign AUDIO_L = audio;
assign AUDIO_R = audio;

zx8302 zx8302 (
	.reset        ( reset        ),
	.init         ( !pll_locked  ),
	.clk_sys      ( CLK12M  ),
	.clk          ( clk21        ),

	.xint         ( qimi_irq     ),
	.ipl          ( cpu_ipl      ),
	.led          ( LED          ),
	.audio        ( audio        ),
	
	// CPU connection
	.clk_bus      ( clk2         ),
	.cpu_sel      ( zx8302_sel   ),
	.cpu_wr       ( cpu_wr       ),
	.cpu_addr     ( zx8302_addr  ),
	.cpu_uds      ( cpu_uds      ),
	.cpu_lds      ( cpu_lds      ),
	.cpu_din      ( cpu_dout     ),
	.cpu_dout     ( zx8302_dout  ),

	// joysticks 
	.js0          ( js0[4:0]     ),
	.js1          ( js1[4:0]     ),
	
	.ps2_kbd_clk  ( ps2_kbd_clk  ),
	.ps2_kbd_data ( ps2_kbd_data ),
	
	.vs           ( video_vs     ),

	// microdrive sdram interface
	.mdv_addr     ( mdv_addr     ),
	.mdv2_addr    ( mdv2_addr    ),
	.mdv_din      ( sdram_dout   ),
	.mdv_read     ( mdv_read     ),
	.mdv2_read    ( mdv2_read    ),
	.mdv_men      ( mdv_men      ),
	.video_cycle  ( video_cycle  ),
	
	.mdv_download ( mdv_download ),
	.mdv2_download ( mdv2_download ),
	
	.mdv_seldrive ( mdv_seldrive ),
	.mdv_active	  ( mdv_active   ),
	
	.mdv_dl_addr  ( dio_addr     )

);
	 
// ---------------------------------------------------------------------------------
// --------------------------- QIMI compatible mouse -------------------------------
// ---------------------------------------------------------------------------------

// qimi is at 1bfxx
wire qimi_sel = cpu_io && (cpu_addr[13:8] == 6'b111111);
wire [7:0] qimi_data;
wire qimi_irq;
	
qimi qimi(
   .reset     ( reset          ),
	.clk       ( clk2           ),

	.cpu_sel   ( qimi_sel       ),
	.cpu_addr  ( { cpu_addr[5], cpu_addr[1] } ),
	.cpu_data  ( qimi_data      ),
	.irq       ( qimi_irq       ),
	
	.ps2_clk   ( ps2_mouse_clk  ),
	.ps2_data  ( ps2_mouse_data )
);

// ---------------------------------------------------------------------------------
// -------------------------------------- CPU --------------------------------------
// ---------------------------------------------------------------------------------

// address decoding
wire cpu_act = cpu_rd || cpu_wr;
wire cpu_io   = cpu_act && ({cpu_addr[19:14], 2'b00} == 8'h18);   // internal IO $18000-$1bffff
wire cpu_bram = cpu_act &&(cpu_addr[19:17] == 3'b001);           	// 128k RAM at $20000
wire cpu_xram = cpu_act && status[3] && ((cpu_addr[19:18] == 2'b01) ||
							(cpu_addr[19:18] == 2'b10));      				// 512k RAM at $40000 if enabled
wire cpu_ram = cpu_bram || cpu_xram;                   				// any RAM
wire cpu_rom  = cpu_act && (cpu_addr[19:16] == 4'h0);             // 64k ROM at $0
wire cpu_mem  = cpu_ram || cpu_rom;                    				// any memory mapped to sdram

wire [15:0] io_dout = 
	qimi_sel?{qimi_data, qimi_data}:
	(!cpu_addr[6])?zx8302_dout:
	16'h0000;	

// demultiplex the various data sources
wire [15:0] cpu_din =
	qlsd_rd?{qlsd_dout, qlsd_dout}:    // qlsd maps into rom area
	cpu_mem?sdram_dout:
	cpu_io?io_dout:
	16'hffff;

wire [31:0] cpu_addr;
wire [15:0] cpu_dout;
wire [1:0] cpu_ipl;
wire [1:0] cpu_ds;
wire cpu_uds_n;
wire cpu_lds_n;
wire cpu_uds = !cpu_uds_n;
wire cpu_lds = !cpu_lds_n;
wire cpu_rw;
wire [1:0] cpu_busstate;
wire cpu_rd = (cpu_busstate == 2'b00) || (cpu_busstate == 2'b10);
wire cpu_wr = (cpu_busstate == 2'b11) && !cpu_rw;
wire cpu_idle = (cpu_busstate == 2'b01);

reg cpu_enable;
always @(negedge clk2)
	cpu_enable <= ((cpu_cycle && !dio_download) || cpu_idle) && !ram_delay_dtack;

TG68KdotC_Kernel #(0,0,0,0,0,0) tg68k (
        .clk            ( clk2      ),
        .nReset         ( ~reset         ),
        .clkena_in      ( cpu_enable     ), 
        .data_in        ( cpu_din        ),
        .IPL            ( {cpu_ipl[0], cpu_ipl }),  // ipl 0 and 2 are tied together on 68008
        .IPL_autovector ( 1'b1           ),
        .berr           ( 1'b0           ),
        .clr_berr       ( 1'b0           ),
        .CPU            ( 2'b00          ),   // 00=68000
		  .addr_out       ( cpu_addr       ),
        .data_write     ( cpu_dout       ),
        .nUDS           ( cpu_uds_n      ),
        .nLDS           ( cpu_lds_n      ),
        .nWr            ( cpu_rw         ),
        .busstate       ( cpu_busstate   ), // 00-> fetch code 10->read data 11->write data 01->no memaccess
        .nResetOut      (                ),
        .FC             (                )
);

// -------------------------------------------------------------------------
// -------------------------- clock generation -----------------------------
// -------------------------------------------------------------------------
					
reg clk10;  // 10.5 MHz QL pixel clock
wire clk21, clk42;
always @(posedge clk21)
	clk10 <= !clk10;

reg clk5;  // 5.25 MHz CPU clock
always @(posedge clk10)
	clk5 <= !clk5;

reg clk2;  // 2.625 MHz bus clock
always @(posedge clk5)
	clk2 <= !clk2;

// CPU and Video share the bus
reg video_cycle;
wire cpu_cycle = !video_cycle;
always @(posedge clk2)
	video_cycle <= !video_cycle;

wire pll_locked;

assign SDRAM_CLK = clk21;
	
// A PLL to derive the system clock from the MiSTs 27MHz
pll pll (
	.inclk0( CLK12M ),
	.c0    ( clk21       ),       // 21.000 MHz
	.c1    ( clk42       ),       // 42.000 MHz
	.locked( pll_locked  )
);

// ---------------------------------------------------------------------------------
// -------------------------------------- QL RAM timing-----------------------------
// ---------------------------------------------------------------------------------

wire ram_delay_dtack;

ql_timing ql_timing (
	.clk_sys		( clk21 ),
	.reset		( reset ),
	.enable		( !status[2] ),
	.ce_bus_p	( clk2 ),
	.cpu_uds		( cpu_uds),
	.cpu_lds		( cpu_lds),
	.sdram_wr	( sdram_wr ),
	.sdram_oe	( sdram_oe ),
	.mdv_active	( mdv_active ),
	.ram_delay_dtack (ram_delay_dtack)
);

endmodule
