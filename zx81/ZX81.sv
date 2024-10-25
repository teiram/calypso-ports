//============================================================================
//
//  ZX80-ZX81 replica for MiST
//  Copyright (C) 2018 Szombathelyi Gyorgy
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

module zx8x_calypso
(
	input         CLK12M,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output       [7:0] LED,
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
	output        UART_TX,
    
    output        AUX_0,
    output        AUX_1,
    output        AUX_2,
    output        AUX_3,
    output        AUX_4,
    output        AUX_5,
    output        AUX_6,
    output        AUX_7
    
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

assign LED[0]  = ~ioctl_download & ~tape_ready;

`include "build_id.v"
localparam CONF_STR = {
	"ZX81;;",
	"F,O  P  ,Load tape;",
	"-;",
	"O6,Video frequency,50Hz,60Hz;",
	"O7,Inverse video,Off,On;",
	"O5,Black border,Off,On;",
	"OCD,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"-;",
	"O23,Stereo mix,none,25%,50%,100%;", 
	"-;",
	"O4,Model,ZX81,ZX80;",
    "OL,Composite,No,Yes;",
	"OHI,Slow mode speed,Original,NoWait,x2,x8;",
	"OAB,Main RAM,16KB,32KB,48KB,1KB;",
	"OG,Low RAM,Off,8KB;",
    "OEF,CHR$128/UDG,128 Chars,64 Chars,Disabled;",
    "OJ,CHRS,Enabled(F1),Disabled;",
	"OK,CHROMA81,Disabled,Enabled;",
	"-;",
	"O89,Joystick,Cursor,Sinclair,ZX81;",
	"OQR,Keyboard,Normal,Ghosting,Recreated ZX,Recr+Ghosting;",
	"-;",
	"T0,Reset;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire locked;

`ifdef USE_CLOCK_50
pll pll
(
	.inclk0(CLOCK_50),
	.c0(clk_sys),	      // 52Mhz
	.locked(locked)
);


`else

pll pll
(
	.inclk0(CLK12M),
	.c0(clk_sys),	      // 52 MHz
	.locked(locked)
);

`endif

reg  ce_cpu_p;
reg  ce_cpu_n;
reg  ce_6m5,ce_3m25,ce_psg;

always @(negedge clk_sys) begin
	reg [4:0] counter = 0;
	reg [1:0] turbo = 0;

	counter <= counter + 1'd1;
	if(~slow_mode) turbo <= status[18:17];

	if(slow_mode & turbo[1]) begin
		ce_cpu_p <= (!counter[2] & !counter[1:0]) | turbo[0];
		ce_cpu_n <= ( counter[2] & !counter[1:0]) | turbo[0];
	end
	else begin
		ce_cpu_p <= !counter[3] & !counter[2:0];
		ce_cpu_n <=  counter[3] & !counter[2:0];
	end
	ce_3m25  <= !counter[3:0];
	ce_6m5   <= !counter[2:0];
	ce_psg   <= !counter[4:0];
end

//////////////////////  HPS I/O  //////////////////////

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;

wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire  [1:0] buttons;
wire  [4:0] joystick_0;
wire  [4:0] joystick_1;
wire [31:0] status;

wire        scandoubler_disable;


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

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;
wire        ypbpr;
wire        no_csync;

assign ps2_key = {key_strobe,key_pressed,key_extended,key_code}; 


user_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(750),.SD_IMAGES(1), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(	
	.clk_sys        	(clk_sys         	),
	.clk_sd           (clk_sys          ),
	.conf_str       	(CONF_STR       	),
	.SPI_CLK        	(SPI_SCK        	),
	.SPI_SS_IO      	(CONF_DATA0     	),
	.SPI_MISO       	(SPI_DO        	),
	.SPI_MOSI       	(SPI_DI         	),

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

	.buttons        	(buttons        	),
	.scandoubler_disable (scandoubler_disable	),
	.ypbpr          	(ypbpr          	),
	.no_csync         ( no_csync),

	.joystick_0       ( joystick_0      ),
	.joystick_1       ( joystick_1      ),
	.status         	(status         	),
//	
   .key_strobe(key_strobe),
   .key_code(key_code),
   .key_pressed(key_pressed),
   .key_extended(key_extended)
);

data_io  data_io(
	.clk_sys       ( clk_sys      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
`ifdef USE_QSPI
	.QSCK          ( QSCK         ),
	.QCSn          ( QCSn         ),
	.QDAT          ( QDAT         ),
`endif
`ifdef NO_DIRECT_UPLOAD
	.SPI_SS4       ( 1'b1         ),
`else
	.SPI_SS4       ( SPI_SS4      ),
`endif
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	//.clkref_n      ( ~clkref      ),
	.ioctl_download( ioctl_download  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   )
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

always_comb begin
	case({nMREQ, ~nM1 | nIORQ | nRD})
	    'b01: cpu_din = (~nM1 & nopgen) ? 8'h00 : mem_out;
	    'b10: cpu_din = io_dout;
	 default: cpu_din = 8'hFF;
	endcase
end

wire tape_in = TAPE_SOUND;


wire [7:0] io_dout;
always_comb begin
	casex({~kbd_n, zxp_sel, ch81_sel, psg_sel})
		'b1XXX: io_dout = { tape_in, hz50, 1'b0, key_data[4:0] & joy_kbd };
		'b01XX: io_dout = zxp_out;
		'b001X: io_dout = 8'hDF;
		'b0001: io_dout = psg_out;
		'b0000: io_dout = 8'hFF;
	endcase
end

wire  [7:0] mem_out;
always_comb begin
	casex({ tapeloader, ~status[19] & qs_e, ch81_e, rom_e, ram_e })
		  'b1_XX_XX: mem_out = tape_loader_patch[addr - (zx81 ? 13'h0347 : 13'h0207)];
		  'b0_1X_XX: mem_out = qs_out;
		  'b0_01_XX: mem_out = ch81_out;
		  'b0_00_1X: mem_out = rom_out;
		  'b0_00_01: mem_out = ram_out;
		default: mem_out = 8'hFF;
	endcase
end

//////////////////   MEMORY   //////////////////
wire low16k_e = ~addr[15] | ~mem_size[1];
wire ramLo_e  = ~addr[14] & addr[13] & low16k_e;
wire ramHi_e  = addr[15] & mem_size[1] & (~addr[14] | (nM1 & mem_size[0]));
wire ram_e    = addr[14] | ramHi_e | (ramLo_e & status[16]);

wire [15:0] ram_a;
always_comb begin
	casex({tapeloader, ramLo_e, mem_size, addr[15:14]})
		'b1_X_XX_XX: ram_a = {2'b01, tape_type ? tape_addr + 4'd8 : tape_addr-1'd1}; // loading address

		'b0_1_XX_XX: ram_a = {3'b001,  ~status[15] ? rom_a : addr[12:0] }; //8K at 2000h
		'b0_0_00_XX: ram_a = {6'b010000, addr[9:0] }; //1k

		'b0_0_01_XX,                                  //16K 
		'b0_0_1X_0X,                                  //main 16k for 32K/48K
		'b0_0_10_11: ram_a = {2'b01,     addr[13:0]}; //mirrored main 16k for 32K

		'b0_0_1X_10: ram_a = {2'b10,     addr[13:0]}; //data 16k for 32K/48K
		'b0_0_11_11: ram_a = {nM1, 1'b1, addr[13:0]}; //48K: last 16k on non-M1 cycle, mirrored main 16K on M1 cycle
	endcase
end

wire [7:0] ram_out;
wire ram_ready;
//////////////////   MEMORY   //////////////////
assign SDRAM_CLK = clk_sys;

sdram ram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.wtbt(0),
	.dout(ram_out),
	.din (tapeloader ? tape_in_byte_r : cpu_dout),
	.addr(ram_a),
	.we((~nWR & ~nMREQ & ram_e & ~ch81_e) | tapewrite_we),
	.rd(ram_e & (~nRFSH | (~nRD & ~nMREQ)) & ~ce_cpu_n & ~tapeloader),
    .ready(ram_ready)
);


wire [12:0] rom_a = nRFSH ? addr[12:0] : { addr[12:9]+(addr[13] & ram_data_latch[7] & addr[8] & ~status[14]), ram_data_latch[5:0], row_counter };
wire        rom_e = ~addr[14] & ~addr[13] & (~addr[12] | zx81) & low16k_e;
wire  [7:0] rom_out;
dpram #(.ADDRWIDTH(14), .NUMWORDS(12288), .MEM_INIT_FILE("Sinclair_ZX8X/rtl/zx8x.mif")) rom
(
	.clock(clk_sys),
	.address_a({(zx81 ? rom_a[12] : 2'h2), rom_a[11:0]}),
	.q_a(rom_out),

	.address_b(ioctl_addr[13:0]),
	.wren_b(ioctl_wr && !ioctl_index),
	.data_b(ioctl_dout)
);

reg        zx81;
reg  [1:0] mem_size; //0 - 1k, 1 - 16k, 2 - 32k, 3 - 48k
wire       hz50 = ~status[6];

always @(posedge clk_sys) begin
	int timeout;

	reset <= buttons[1] | status[0] | (mod[1] & Fn[11]) | |timeout;
	if (reset) begin
		zx81 <= ~status[4];
		mem_size <= status[11:10] + 1'd1;
	end

	if(timeout) timeout <= timeout - 1;
	if(zx81 != ~status[4] || mem_size != (status[11:10] + 1'd1)) timeout <= 1000000;
end

////////////////////  TAPE  //////////////////////
reg         tape_type;
reg   [7:0] tape_ram[16384];
reg         tapeloader, tapewrite_we;
reg  [13:0] tape_addr;
reg  [13:0] tape_size;
reg   [7:0] tape_in_byte,tape_in_byte_r;
wire        tape_ready = |tape_size;  // there is data in the tape memory
// patch the load ROM routines to loop until the memory is filled from $4000(.o file ) $4009 (.p file)
// xor a; loop: nop or scf, jr nc loop, jp h0207 (jp h0203 - ZX80)
reg   [7:0] tape_loader_patch[7] = '{8'haf, 8'h00, 8'h30, 8'hfd, 8'hc3, 8'h07, 8'h02};

always @(posedge clk_sys) begin
	reg old_download;

	if (reset) tape_size <= 0;
	
	if(ioctl_index[4:0] && !ioctl_index[7] && !ioctl_index[5]) begin
		if (ioctl_wr) tape_ram[ioctl_addr] <= ioctl_dout;
		
		old_download <= ioctl_download;
		if(old_download && ~ioctl_download) begin
			tape_size <= ioctl_addr[13:0];
			tape_type <= ioctl_index[6];
		end
	end
end

always @(posedge clk_sys) tape_in_byte <= tape_ram[tape_addr];

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
		if (tape_addr < tape_size) begin
			tape_addr <= tape_addr + 1'h1;
			tape_in_byte_r <= tape_in_byte;
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
wire      data_latch_enable = nRFSH & ce_cpu_p & ~nMREQ;
reg [7:0] ram_data_latch;
reg       nopgen_store;
reg [2:0] row_counter;
wire      shifter_start = nMREQ & nopgen_store & ce_cpu_p & shifter_en & ~NMIlatch;
reg [7:0] shifter_reg;
reg       inverse;
wire      video_out = (~status[7] ^ shifter_reg[7] ^ inverse);
reg [7:0] paper_reg;
wire      border = ~paper_reg[7];
reg [7:0] attr, attr_latch;
reg       shifter_en;

always @(posedge clk_sys) begin
	reg old_hsync, old_hblank;
	reg old_shifter_start;

	if (ce_6m5) begin
		old_hsync <= hsync;

		if (data_latch_enable) begin
			ram_data_latch <= mem_out;
			nopgen_store <= nopgen;
			attr_latch <= ch81_out;
		end

		if (nMREQ & ce_cpu_p) inverse <= 0;

		old_shifter_start <= shifter_start;
		shifter_reg <= { shifter_reg[6:0], 1'b0 };
		paper_reg   <= { paper_reg[6:0], 1'b0 };
		
		if (~old_shifter_start & shifter_start) begin
			shifter_reg <= (~nM1 & nopgen) ? 8'h0 : mem_out;
			inverse <= ram_data_latch[7];
			paper_reg <= 'hFF;
			attr <= ch81_dat[4] ? attr_latch : ch81_out;
		end

		if (~old_hsync & hsync)	row_counter <= row_counter + 1'd1;
		if (vs) row_counter <= 0;

		//extended suppress to reduce garbage
		old_hblank <= hblank;
		if(~old_hblank & hblank) shifter_en <= 0;
		if(old_hblank & ~hblank) shifter_en <= ~NMIlatch;
	end
end

// vsync generator
reg vsync; // cleaned version
reg vs;    // momentary version, sometimes used for row_counter reset trick
always @(posedge clk_sys) begin
	if (~nIORQ & ~nWR & ~NMIlatch) vs <= 0;
	if (~kbd_n & ~NMIlatch)        vs <= 1;
	if(!hsync) vsync<=vs;
end

// ZX81 upgrade
// http://searle.hostei.com/grant/zx80/zx80nmi.html
wire nWAIT = ~nHALT | nNMI | (slow_mode & |status[18:17]);
wire nNMI = ~NMIlatch | ~hsync;

reg slow_mode = 0;
always @(posedge clk_sys) begin
	reg [6:0] fcnt;
	reg old_halt, old_latch;

	old_latch <= NMIlatch;
	old_halt  <= nHALT;

	// Time out to enable turbo modes after reset,
	// otherwise ZX81 FW won't enter slow mode!
	if(~old_latch & NMIlatch) begin
		if(&fcnt) slow_mode <= 1;
		else fcnt <= fcnt + 1'd1;
	end
	if(old_halt & ~nHALT) slow_mode <= 0;
	
	if(reset) {fcnt,slow_mode} <= 0;
end

reg [7:0] sync_counter;
reg       NMIlatch;
reg       hsync;
always @(posedge clk_sys) begin
	if(ce_3m25) begin
		sync_counter <= sync_counter + 1'd1;
		if(sync_counter == 206) sync_counter <= 0;
		if(sync_counter == 15)  hsync <= 1;
		if(sync_counter == 31)  hsync <= 0;
	end

	if (~nM1 & ~nIORQ) {hsync,sync_counter} <= 0;

	if (zx81) begin
		if (~nIORQ & ~nWR & (addr[0] ^ addr[1])) NMIlatch <= addr[1];
	end
	else begin
		NMIlatch <= 0;
	end
end

//re-sync
reg hsync2, vsync2;
reg hblank, vblank;
always @(posedge clk_sys) begin
	reg [8:0] cnt;
	reg [10:0] vreg;
	reg       old_hsync;

	if(ce_6m5) begin
		cnt <= cnt + 1'd1;
		if(cnt == 413) cnt <= 0;

		if(cnt == 0)   hsync2 <= 1;
		if(cnt == 32)  hsync2 <= 0;

		if(cnt == 400) hblank <= 1;
		if(cnt == 72)  hblank <= 0;

		old_hsync <= hsync;
		if(~old_hsync & hsync) begin
			vreg <= {vreg[9:0], vsync};
			vblank <= |{vreg,vsync};
			vsync2 <= vreg[2] & ~vreg[10]; //Get also rid of long vsync pulses
			if(&vreg[3:2]) cnt <= 0;
		end
        
	end
end

wire i,g,r,b;
always_comb begin
	casex({status[5] & border, ch81_dat[5], border, video_out})
		'b1XXX: {i,g,r,b} = 0;
		'b00XX: {i,g,r,b} = {4{video_out}};
		'b011X: {i,g,r,b} = ch81_dat[3:0];
		'b0101: {i,g,r,b} = attr[7:4];
		'b0100: {i,g,r,b} = attr[3:0];
	endcase
end

reg VSync, HSync;
always @(posedge clk_sys) begin
	HSync <= hsync2;
	if(~HSync & hsync2) VSync <= vsync2;
end


//////////////////// CHROMA81 ////////////////////
// mapped at C000 and accessible only in non-M1 cycle
wire      ch81_e = status[20] & ~nMREQ & nM1 & &addr[15:14];
wire      ch81_sel = ~nIORQ & (addr == 'h7FEF) & status[20];
reg [7:0] ch81_dat = 0;

always @(posedge clk_sys) begin
	reg set_m0 = 0;
	reg old_tapeloader = 0;

	if(reset | ~status[20]) {set_m0, ch81_dat} <= 0;
	else if(ch81_sel & ~nWR) ch81_dat = cpu_dout;
	
	if(ioctl_wr) begin
		if(ioctl_index[4:0] && (ioctl_index[7:5]==1)) begin
			set_m0 <= 1;
			if(ioctl_addr == 1024) ch81_dat <= ioctl_dout[3:0];
		end
		else if(~ioctl_index[5]) set_m0 <= 0;
	end
	
	old_tapeloader <= tapeloader;
	if(old_tapeloader & ~tapeloader & set_m0 & status[20]) ch81_dat[5:4] <= 2'b10;
end

wire [7:0] ch81_out;
dpram #(.ADDRWIDTH(14)) chroma81
(
	.clock(clk_sys),
	.address_a(nRFSH ? addr[13:0] : {ram_data_latch[7], rom_a[8:0]}),
	.wren_a(~nWR & ~nMREQ & ch81_e),
	.data_a(cpu_dout),
	.q_a(ch81_out),
	
	.address_b(ioctl_addr[13:0]),
	.data_b(ioctl_dout),
	.wren_b(ioctl_wr && ioctl_index[4:0] && (ioctl_index[7:5]==1) && !ioctl_addr[24:10])
);

//////////////////// QS CHRS /////////////////////
wire       qs_e = nRFSH ? (addr[15:10] == 'b100001) : (qs & (addr[15:9] == 'b0001111)); //8400-87FF / 1E00-1F00
wire [7:0] qs_out;

dpram #(.ADDRWIDTH(10)) qschrs
(
	.clock(clk_sys),
	.address_a(nRFSH ? addr[9:0] : {ram_data_latch[7], rom_a[8:0]}),
	.wren_a(~nWR & ~nMREQ & qs_e),
	.data_a(cpu_dout),
	.q_a(qs_out),
	
	.address_b(ioctl_addr[9:0]),
	.wren_b(ioctl_wr && ioctl_index[4:0] && (ioctl_index[7:5]==3) && !ioctl_addr[24:10]),
	.data_b(ioctl_dout)
);

reg qs = 0;
always @(posedge clk_sys) begin
	reg qs_set = 0;
	reg old_f1;
	reg old_tapeloader = 0;
	
	old_f1 <= Fn[1];
	if(~old_f1 & Fn[1]) qs <= ~qs;
	
	if(ioctl_wr) begin
		if(ioctl_index[4:0] && (ioctl_index[7:5]==3)) qs_set <= 1;
		else if(~ioctl_index[5]) qs_set <= 0;
	end
	
	old_tapeloader <= tapeloader;
	if(old_tapeloader & ~tapeloader & qs_set) qs <= 1;

	if(reset) {qs_set,qs} <= 0;
end

////////////////////  SOUND //////////////////////
wire [7:0] psg_out;
wire       psg_sel = ~nIORQ & &addr[3:0]; //xF
wire [7:0] psg_ch_a, psg_ch_b, psg_ch_c;

ym2149 psg
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

wire [9:0] audio_l = { 1'b0, psg_ch_a, 1'b0 } + { 2'b00, psg_ch_b };
wire [9:0] audio_r = { 1'b0, psg_ch_c, 1'b0 } + { 2'b00, psg_ch_b };

wire [15:0] DAC_L,DAC_R;

assign DAC_L   = {audio_l, 6'd0};
assign DAC_R   = {audio_r, 6'd0};

////////////////////   HID   /////////////////////

wire kbd_n = nIORQ | nRD | addr[0];

wire [11:1] Fn;
wire  [2:0] mod;
wire  [4:0] key_data;
wire        recreated_zx = status[27];
wire        ghosting     = status[26];

keyboard kbd( .* );

wire [1:0] jsel = status[9:8];
wire [4:0] joy = joystick_0 | joystick_1;

//ZX81 67890
wire [4:0] joyzx = ({5{jsel[1]}} & {joy[2], joy[3], joy[0], joy[1], joy[4]});

//Sinclair 1 67890
wire [4:0] joys1 = ({5{jsel[0]}} & {joy[1:0], joy[2], joy[3], joy[4]});

//Cursor 56780
wire [4:0] joyc1 = {5{!jsel}} & {joy[2], joy[3], joy[0], 1'b0, joy[4]};
wire [4:0] joyc2 = {5{!jsel}} & {joy[1], 4'b0000};

//map to keyboard
wire [4:0] joy_kbd = {5{zxp_use}} | (({5{addr[12]}} | ~(joys1 | joyc1 | joyzx)) & ({5{addr[11]}} | ~joyc2));


reg [7:0] zxp_out = 'hFF;
reg       zxp_use = 0;
wire      zxp_sel = ~nIORQ & (addr == 'hE007);

always @(posedge clk_sys) begin
	if(reset) {zxp_use,zxp_out} <= 'hFF;
	else if(zxp_sel & ~nWR) begin
		zxp_out <= 'hFF;
		if(cpu_dout == 'hAA) zxp_out <= 'hF0;
		if(cpu_dout == 'h55) zxp_out <= 'h0F;
		if(cpu_dout == 'hA0) {zxp_use,zxp_out} <= {1'b1, ~joy[3:0],~joy[4],3'b000};
	end
end

	mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(11), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (	
	.clk_sys      (clk_sys     ),
	.SPI_SCK      (SPI_SCK    ),
	.SPI_SS3      (SPI_SS3    ),
	.SPI_DI       (SPI_DI     ),

	.HSync        (HSync         ),
	.VSync        (VSync         ),
	.R({r,{3{i & r}}}),
	.G({g,{3{i & g}}}),
	.B({b,{3{i & b}}}),
	.HBlank(hblank),
	.VBlank(vblank),
	.VGA_R        (vga_r      ),
	.VGA_G        (vga_g      ),
	.VGA_B        (vga_b      ),
	.VGA_VS       (vga_vs     ),
	.VGA_HS       (vga_hs     ),
	.ce_divider   (1'b1       ),
	.scandoubler_disable(status[21]),
	.no_csync     (no_csync	),
	.scanlines    (status[13:12]),
	.ypbpr        (ypbpr      )
	);

reg vga_hs;
reg vga_vs;
reg [3:0] vga_r;
reg [3:0] vga_g;
reg [3:0] vga_b;
    
assign VGA_HS = status[21] ? ~(vga_hs ^ vga_vs) : vga_hs;
assign VGA_VS = status[21] ? 1'b0 : vga_vs;
assign VGA_R =  status[21] ? 4'd0 : vga_r;
assign VGA_G = status[21] ? {2'b00, vga_r[1] | vga_g[1] | vga_b[1], vga_r[0] | vga_g[0] | vga_g[0]} : vga_g;
assign VGA_B = status[21] ? {2'b00, vga_r[3] | vga_g[3] | vga_b[3], vga_r[2] | vga_g[2] | vga_b[2]} : vga_b;

`ifdef USE_HDMI
i2c_master #(52_000_000) i2c_master (
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

mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(11),.OUT_COLOR_DEPTH(8), .USE_BLANKS(1), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1)) hdmi_video (
	.*,
	.clk_sys     ( clk_sys   ),
	.scanlines   (status[13:12]),
	.ce_divider  ( 3'd1       ),
	.scandoubler_disable (scandoubler_disable),
	.rotate      ( 2'b00      ),
	.blend       ( 1'b0       ),
	.no_csync    ( no_csync),
	.R({r,{3{i & r}}}),
	.G({g,{3{i & g}}}),
	.B({b,{3{i & b}}}),
	.HBlank(hblank),
	.VBlank(vblank),	
	.HSync       (HSync),
	.VSync       (VSync),
	.VGA_R       ( HDMI_R      ),
	.VGA_G       ( HDMI_G      ),
	.VGA_B       ( HDMI_B      ),
	.VGA_VS      ( HDMI_VS     ),
	.VGA_HS      ( HDMI_HS     ),
	.VGA_HB(),
	.VGA_VB(),
   .VGA_DE      ( HDMI_DE     )
);
assign HDMI_PCLK = clk_sys;
`endif

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd52_000_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(DAC_L),
	.right_chan(DAC_R)
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
	.clk_rate_i(32'd52_000_000),
	.spdif_o(SPDIF),
	.sample_i({DAC_R, DAC_L})
);
`endif


endmodule
