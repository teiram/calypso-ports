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

	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [11:0] SDRAM_A,    // 13 bit multiplexed address bus
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
	input             clkref,

	input             port1_req,
	output reg        port1_ack,
	input             port1_we,
	input      [22:1] port1_a,
	input       [1:0] port1_ds,
	input      [15:0] port1_d,
	output     [31:0] port1_q,

	input      [22:2] cpu1_addr,
	output reg [31:0] cpu1_q,
	input             cpu1_oe
);

parameter MHZ = 80; // 80 MHz default clock, adjust to calculate the refresh rate correctly

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b001; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// 64ms/4096 rows = 15.6us
localparam RFRSH_CYCLES = 16'd156*MHZ/10;
localparam RST_COUNT = 11'd10 + 11'd25 * MHZ;

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 SDRAM state machine
 1 word burst, CL2
cmd issued  registered
 0 RAS0
 1
 2 CAS0
 3
 4
 5
 6 data ready
 7
*/

localparam STATE_RAS0      = 3'd0;
localparam STATE_CAS0      = STATE_RAS0 + RASCAS_DELAY; //0 + 2 = 2
localparam STATE_DS1       = STATE_RAS0 + RASCAS_DELAY + 1'd1; // 0 + 2 + 1 = 3
localparam STATE_READ0     = STATE_CAS0 + CAS_LATENCY + 2'd2; // 2 + 2 + 2 = 6
localparam STATE_READ1     = STATE_CAS0 + CAS_LATENCY + 2'd3; // 2 + 2 + 3 = 7
localparam STATE_LAST      = 3'd7;

reg [2:0] t;

always @(posedge clk) begin
	reg clkref_d;
	clkref_d <= clkref;

	t <= t + 1'd1;
	if (t == STATE_LAST) t <= STATE_RAS0;
	if (~clkref_d & clkref) t <= 3'd0;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

reg [10:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if (!init_n) begin
		reset <= RST_COUNT;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 11'd1;
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

reg  [3:0] sd_cmd;   // current command sent to sd ram
reg [15:0] sd_din;
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg [22:1] addr_latch;
reg [22:1] addr_latch_next;
reg [15:0] din_latch;
reg        oe_latch;
reg        we_latch;
reg  [1:0] ds;

localparam PORT_NONE  = 2'd0;
localparam PORT_CPU1  = 2'd1;
localparam PORT_REQ   = 2'd2;

reg  [2:0] next_port;
reg  [2:0] port;
reg        port1_state;

// PORT1
always @(*) begin
	if (port1_req ^ port1_state) begin
		next_port = PORT_REQ;
		addr_latch_next = port1_a;
	end else if (cpu1_oe) begin
		next_port = PORT_CPU1;
		addr_latch_next = {cpu1_addr, 1'b0};
	end else begin
		next_port = PORT_NONE;
		addr_latch_next = addr_latch;
	end
end

always @(posedge clk) begin

	// permanently latch ram data to reduce delays
	sd_din <= SDRAM_DQ;
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	sd_cmd <= CMD_NOP;  // default: idle
	
	if(init) begin
		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 10) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset <= 9 && reset > 1) begin
				sd_cmd <= CMD_AUTO_REFRESH;		//8 auto refresh commands
			end

			if(reset == 1) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		// RAS phase
		if(t == STATE_RAS0) begin
			addr_latch <= addr_latch_next;
			port <= next_port;
			{ oe_latch, we_latch } <= 2'b00;

			if (next_port != PORT_NONE) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_latch_next[20:9];
				SDRAM_BA <= addr_latch_next[22:21];
				if (next_port == PORT_REQ) begin
					{ oe_latch, we_latch } <= { ~port1_we, port1_we };
					ds <= port1_ds;
					din_latch <= port1_d;
					port1_state <= port1_req;
				end else begin
					{ oe_latch, we_latch } <= 2'b10;
					ds <= 2'b11;
				end
			end else begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end
		end

		// CAS phase
		if(t == STATE_CAS0 && (we_latch || oe_latch)) begin
			sd_cmd <= we_latch?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds;
			if (we_latch) begin
				SDRAM_DQ <= din_latch;
				port1_ack <= port1_req;
			end
			SDRAM_A <= {4'b0100, addr_latch[8:1]};  // auto precharge
			SDRAM_BA <= addr_latch[22:21];
		end

		if(t == STATE_DS1 && oe_latch) begin
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds;
		end

		// Data returned
		if(t == STATE_READ0 && oe_latch) begin
			case(port)
				PORT_REQ:  begin port1_q[15:0] <= sd_din; end
				PORT_CPU1: begin cpu1_q[15:0]  <= sd_din; end
				default: ;
			endcase;
		end
		if(t == STATE_READ1 && oe_latch) begin
			case(port)
				PORT_REQ:  begin port1_q[31:16] <= sd_din; port1_ack <= port1_req; end
				PORT_CPU1: begin cpu1_q[31:16]  <= sd_din; end
				default: ;
			endcase;
		end
	end
end

endmodule
