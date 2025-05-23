//
// sdram.v
//
// sdram controller implementation for Calypso (Winbond W9864G6JT)
//
// Based on sdram module by Till Harbaum
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

module sdram
(
	// interface to the W9864G6JT chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [11:0] SDRAM_A,    // 12 bit multiplexed address bus
	output reg        SDRAM_DQML, // byte mask
	output reg        SDRAM_DQMH, // byte mask
	output reg  [1:0] SDRAM_BA,   // two banks
	output reg        SDRAM_nCS,  // a single chip select
	output reg        SDRAM_nWE,  // write enable
	output reg        SDRAM_nRAS, // row address select
	output reg        SDRAM_nCAS, // columns address select
	output            SDRAM_CKE,

	// cpu/chipset interface
	input             init,			// init signal after FPGA config to initialize RAM
	input             clk,			// sdram is accessed at up to 128MHz
	input             clkref,		// reference clock to sync to
	
	input       [1:0] bank,
	input       [7:0] din,			// data input from chipset/cpu
	output      [7:0] dout,			// data output to chipset/cpu
	input      [22:0] addr,       // 23 bit byte address
	input             oe,         // cpu/chipset requests read
	input             we,         // cpu/chipset requests write

	output reg [15:0] vram_dout,
	input      [22:0] vram_addr,
    
    output     ready
);

assign SDRAM_CKE = ~init;
assign dout = oe ? ram_dout : 8'h00;
assign ready = reg_ready;
// no burst configured
localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@64MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

localparam STATE_START = 3'd0;   // state in which a new command can be started
localparam STATE_CONT  = STATE_START  + RASCAS_DELAY; // 2 command can be continued
localparam STATE_READ  = STATE_CONT + CAS_LATENCY + 2'd2; // 6 data ready
localparam STATE_LAST  = 3'd7;   // last state in cycle

reg  [2:0] q /* synthesis keep */;
reg [22:0] a, addr_next;
reg        wr /* synthesis keep */, wr_next;
reg        ram_req /* synthesis keep */=0, ram_req_next;
reg        vram_req /* synthesis keep */=0, vram_req_next;

reg [22:0] old_vram_addr;
reg old_rd, old_we;

// access manager
always @(posedge clk) begin
	reg old_ref;

	old_rd <= oe;
	old_we <= we;
	old_ref <= clkref;

	q <= q + 3'd1;
	if (~old_ref & clkref) q <= 3'd0;

	if (q == STATE_START) begin
		ram_req <= ram_req_next;
		vram_req <= vram_req_next;
		wr <= wr_next;
		a <= addr_next;
		if (vram_req_next) old_vram_addr <= vram_addr;
	end
end

always @(*) begin

	ram_req_next = 0;
	vram_req_next = 0;
	wr_next = 0;
	addr_next = 0;

	if ((~old_rd & oe) | (~old_we & we)) begin
		ram_req_next = 1;
		wr_next = we;
		addr_next = addr;
	end else if (old_vram_addr[15:1] != vram_addr[15:1]) begin
		vram_req_next = 1;
		addr_next = vram_addr;
	end
end

localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

// initialization 
reg [1:0] mode;
reg [7:0] reset = 8'd200;
reg reg_ready = 0;
always @(posedge clk) begin
	reg init_old = 0;
	init_old <= init;

	if (init_old & ~init) reset <= 8'd200;
	else if (q == STATE_LAST) begin
		if (reset != 0) begin
			reset <= reset - 8'd1;
			if (reset == 10)                  mode <= MODE_PRE;
            else if (reset < 10 && reset > 1) mode <= MODE_NORMAL; //To perform auto refresh
			else if (reset == 1)              mode <= MODE_LDM;
			else                              mode <= MODE_RESET;
		end
		else begin
            mode <= MODE_NORMAL;
            reg_ready <= 1'b1;
        end
	end
end

localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;


reg  [7:0] ram_dout;
reg [15:0] sdram_din;
// SDRAM state machine
always @(posedge clk) begin

	// latch input in Fast Input Register
	sdram_din <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;

	case ({mode,q})
		{MODE_LDM, STATE_START}:
		begin
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
			SDRAM_A <= MODE;
		end

		{MODE_PRE, STATE_START}:
		begin
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;
			SDRAM_A <= 12'b010000000000;
		end

		{MODE_NORMAL, STATE_START}:
		if (ram_req_next | vram_req_next) begin
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
			SDRAM_A <= addr_next[20:9];
			SDRAM_BA <= bank;
			if(ram_req_next & wr_next) ram_dout <= din;
		end else
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;

		{MODE_NORMAL, STATE_CONT}:
		if (ram_req | vram_req) begin
			SDRAM_A <= {4'b0100, a[8:1]};
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= wr ? CMD_WRITE : CMD_READ;
			if (wr) SDRAM_DQ <= {din, din};
			{SDRAM_DQMH, SDRAM_DQML} <= {~a[0] & wr, a[0] & wr};
		end

		{MODE_NORMAL, STATE_READ}:
		begin
			if (~wr & ram_req) ram_dout <= a[0] ? sdram_din[15:8] : sdram_din[7:0];
			else if (vram_req) vram_dout <= sdram_din;
		end

		default: ;

	endcase
end

endmodule
