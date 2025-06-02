//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019 Gyorgy Szombathelyi
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

module sdram (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // two byte masks
	output reg        SDRAM_DQMH, // two byte masks
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock
	input             refresh_en,

	input             reqA,       // cpu requests data
	input  [24:0]     addrA,      // 25 bit byte address
	input             weA,        // cpu requests write
	input   [7:0]     dinA,       // data input from cpu
	output [15:0]     doutA,      // data output to cpu
	output reg        cpuwait,
	output reg        cpuwait2,

	input             reqB,       // ppu requests data
	input  [24:0]     addrB,      // 25 bit byte address
	output [15:0]     doutB,      // data output to ppu

	input             reqC,       // tzxplayer requests data
	input  [24:0]     addrC,      // 25 bit byte address
	input             weC,        // IO controller requests write
	input   [7:0]     dinC,       // tzx input from IO controller
	output [15:0]     doutC,      // data output to tzxplayer
	output reg        ackC
);

localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 Simple SDRAM state machine
 1 word burst, CL2
cmd issued  registered
 0 RAS0
 1          ras0
 2 CAS0
 3          cas0
 4
 5          data0 returned
*/

localparam STATE_RAS0      = 3'd0;   // first state in cycle
localparam STATE_RCD       = 3'd1; // RAS-CAS delay state
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; // CAS phase - 3
localparam STATE_CL0       = STATE_RAS0 + RASCAS_DELAY + 1'd1; // CAS phase - 3
localparam STATE_READ0     = 3'd0;//STATE_CAS0 + CAS_LATENCY + 2'd2; // 8
localparam STATE_LAST      = 3'd7;

reg [2:0] t;

always @(posedge clk) begin
	case(t)
		3'd0: if (init | actA | actB | actC | refresh_en) t <= 3'd1;
		3'd1: t <= 3'd2;
		3'd2: t <= 3'd3;
		3'd3: t <= 3'd4;
		3'd4: t <= 3'd5;
		3'd5: t <= 3'd6;
		3'd6: t <= 3'd7;
		default: t <= 3'd0;
	endcase
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [5:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if(!init_n) begin
		reset <= 6'h3f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 6'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0]  sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg  [7:0] column_addr;
reg [24:0] addr_cache;
reg [15:0] din_latch;
reg        oe_latch;
reg        we_latch;
reg  [1:0] ds;

localparam IDLE = 3'd0;
localparam PORTA = 3'd1;
localparam PORTB = 3'd2;
localparam PORTC = 3'd3;
localparam PORTREF = 3'd4;

reg  [2:0] port;
reg [15:0] sd_data;
reg        cacheA_valid;
reg        reqA_d;
reg        ackA;
reg        addr_match;
reg        reqB_d, reqB_d2;
reg [24:0] addrB_prev;

always @(posedge clk) addr_match <= addr_cache[24:1] == addrA[24:1];

wire       actCacheA = cacheA_valid & !weA & addr_match;
wire       actA = reqA & !ackA & !actCacheA;
wire       actB = (addrB_prev[24:1] != addrB[24:1]) & ((reqB_d ^ reqB) | reqB_d2);
wire       actC = (reqC ^ ackC) & (port != PORTC);

reg [15:0] doutAreg;
reg [15:0] doutBreg;
reg [15:0] doutCreg;
assign     doutA = doutAreg;//(t == STATE_READ0 && port == PORTA) ? sd_data : doutAreg;
assign     doutB = (t == STATE_READ0 && port == PORTB) ? sd_data : doutBreg;
assign     doutC = doutCreg;

always @(posedge clk) begin

	sd_data <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle

	if(init) begin
		cpuwait <= 0;
		ackA <= 0;
		cacheA_valid <= 0;

		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 10) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset <= 9 || reset > 1) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 1) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		reqA_d <= reqA;
		if (!reqA_d) begin
			ackA <= 0;
			cpuwait <= 1;
			cpuwait2 <= 1;
		end

		if (reqA & !ackA & actCacheA) begin
			ackA <= 1;
			cpuwait <= 0;
			cpuwait2 <= 0;
		end

		reqB_d <= reqB;
		if (reqB_d ^ reqB) reqB_d2 <= 1;

		// RAS phase
		if(t == STATE_RAS0) begin
			{ oe_latch, we_latch } <= 2'b00;
			port <= IDLE;

			if (actB) begin
				reqB_d2 <= 0;
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrB[20:9];
				SDRAM_BA <= addrB[22:21];
				column_addr <= addrB[8:1];
				addrB_prev <= addrB;
				{ oe_latch, we_latch } <= 2'b10;
				ds <= 2'b11;
				port <= PORTB;
			end else if (actA) begin
				cpuwait <= 0;
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrA[20:9];
				SDRAM_BA <= addrA[22:21];
				column_addr <= addrA[8:1];
				addr_cache <= addrA;
				port <= PORTA;
			end else if (actC) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addrC[20:9];
				SDRAM_BA <= addrC[22:21];
				column_addr <= addrC[8:1];
				{ oe_latch, we_latch } <= { ~weC, weC };
				ds <= weC ? { ~addrC[0], addrC[0] } : 2'b11;
				din_latch <= { dinC, dinC };
				port <= PORTC;
			end else if (refresh_en) begin
				sd_cmd <= CMD_AUTO_REFRESH;
				port <= PORTREF;
			end
		end

		if(t == STATE_RCD && port == PORTA) begin
			ackA <= 1;
			cpuwait <= 0;
			{ oe_latch, we_latch } <= { ~weA, weA };
			ds <= weA ? { ~addrA[0], addrA[0] } : 2'b11;
			din_latch <= { dinA, dinA };
		end

		// CAS phase
		if(t == STATE_CAS0 && (oe_latch || we_latch)) begin
			if (port == PORTA) cpuwait <= 0;
			sd_cmd <= we_latch?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds;
			if (we_latch) begin
				SDRAM_DQ <= din_latch;
				if (port == PORTA) begin
					cpuwait2 <= 0;
					cacheA_valid <= 0;
				end else begin //PORTC
					ackC <= reqC;
				end
			end
			SDRAM_A <= { 5'b00100, column_addr };  // auto precharge
		end

		if(t == STATE_CL0 && oe_latch)
			{ SDRAM_DQMH, SDRAM_DQML } <= 2'b00;

		// Data returned
		if(t == STATE_READ0 && oe_latch) begin
			case(port)
			PORTA: begin doutAreg <= sd_data; cpuwait2 <= 0; cacheA_valid <= 1; end
			PORTB: doutBreg <= sd_data;
			PORTC: begin doutCreg <= sd_data; ackC <= reqC; end
			default :;
			endcase
		end

	end
end

endmodule
