//
// sdram.v
//
// sdram controller implementation for Calypso
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

	// interface to the Winbond W9864G6JT chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [11:0] SDRAM_A,    // 13 bit multiplexed address bus
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
	input             we         // cpu/chipset requests write
);

assign SDRAM_CKE = ~init;

// no burst configured
localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

localparam STATE_IDLE  = 3'd0;   // first state in cycle
localparam STATE_START = 3'd1;   // state in which a new command can be started
localparam STATE_CONT  = STATE_START  + RASCAS_DELAY; // 4 command can be continued
localparam STATE_LAST  = 3'd7;   // last state in cycle

reg  [2:0] q;
reg [22:0] a;
reg        wr;
reg        ram_req=0;
reg [15:0] i;

// access manager
always @(posedge clk) begin
    reg [22:0] old_addr;
    reg old_rd, old_we, old_ref;

    old_ref<=clkref;

    if(q==STATE_IDLE) begin
        old_rd<=oe;
        old_we<=we;
        ram_req <= 0;
        wr <= 0;

        if((~old_rd & oe) | (~old_we & we)) begin
            ram_req <= 1;
            wr <= we;
            a <= addr;
        end
    end

    q <= q + 3'd1;
    if(old_ref ^ clkref) begin
        if (clkref) q <= 0;
        old_rd <= 0;
        old_we <= 0;
    end
end

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate

localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

// 64ms/4096 rows = 15.6us
localparam RFRSH_CYCLES = 16'd156*MHZ/10;
localparam RST_COUNT = 11'd10 + 11'd25 * MHZ;

// initialization 
reg [1:0] mode=MODE_RESET;
reg [10:0] reset=RST_COUNT;
always @(posedge clk, posedge init) begin
	if (init) begin
		reset <= RST_COUNT;
		mode <= MODE_RESET;
	end
	else if(q == STATE_LAST) begin
		if(reset != 0) begin
			reset <= reset - 11'd1;
			if(reset == 10)     mode <= MODE_PRE;
			else if(reset <= 9 && reset > 1) mode <= MODE_NORMAL;
			else if(reset == 1) mode <= MODE_LDM;
			else                mode <= MODE_RESET;
		end
		else mode <= MODE_NORMAL;
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

wire [7:0] ram_dout = a[0] ? i[15:8] : i[7:0];
assign dout = oe ? ram_dout : 8'h00;

// SDRAM state machines
always @(posedge clk) begin
	casex({ram_req,wr,mode,q})
		{2'b1X, MODE_NORMAL, STATE_START}: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
		{2'b11, MODE_NORMAL, STATE_CONT }: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_WRITE;
		{2'b10, MODE_NORMAL, STATE_CONT }: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;
		{2'b0X, MODE_NORMAL, STATE_START}: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;

		// init
		{2'bXX,    MODE_LDM, STATE_START}: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
		{2'bXX,    MODE_PRE, STATE_START}: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;

		                          default: {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_INHIBIT;
	endcase

	casex({ram_req,mode,q})
		{1'b1,  MODE_NORMAL, STATE_START}: SDRAM_A <= a[20:9];
		{1'b1,  MODE_NORMAL, STATE_CONT }: SDRAM_A <= {4'b0100, a[8:1]};

		// init
		{1'bX,     MODE_LDM, STATE_START}: SDRAM_A <= MODE;
		{1'bX,     MODE_PRE, STATE_START}: SDRAM_A <= 12'b010000000000;

		                          default: SDRAM_A <= 12'b000000000000;
	endcase

	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;

	if(q == STATE_START) begin
		SDRAM_BA <= (mode == MODE_NORMAL) ? bank : 2'b00;
		{SDRAM_DQMH,SDRAM_DQML} <= {~a[0] & wr,a[0] & wr};
	end

	if (q == STATE_CONT) begin
		if(wr) SDRAM_DQ <= { din, din };
	end

	if (q == STATE_CONT+CAS_LATENCY+1) begin
		if (~wr & ram_req) i <= SDRAM_DQ;
	end
end

endmodule
