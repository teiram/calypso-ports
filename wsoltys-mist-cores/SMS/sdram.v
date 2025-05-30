//
// sdram.v
//
// sdram controller implementation for the MiST board
// http://code.google.com/p/mist-board/
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
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
	inout [15:0]  		sd_data,    // 16 bit bidirectional data bus
	output reg [11:0]	sd_addr,    // 13 bit multiplexed address bus
	output reg [1:0] 	sd_dqm,     // two byte masks
	output reg [1:0] 	sd_ba,      // two banks
	output 				sd_cs,      // a single chip select
	output 				sd_we,      // write enable
	output 				sd_ras,     // row address select
	output 				sd_cas,     // columns address select

	// cpu/chipset interface
	input 		 		init,			// init signal after FPGA config to initialize RAM
	input 		 		clk,			// sdram is accessed at up to 128MHz
	input					clkref,		// reference clock to sync to
	
	input [7:0]  		din,			// data input from chipset/cpu
	output [7:0]      dout,			// data output to chipset/cpu
	input [24:0]   	addr,       // 25 bit byte address
	input 		 		oe,         // cpu/chipset requests read
	input 		 		we          // cpu/chipset requests write
);

// falling edge on oe/we/rfsh starts state machine

// no burst configured
localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 


// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_IDLE      = 3'd0;   // first state in cycle
localparam STATE_CMD_START = 3'd0;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // 4 command can be continued
localparam STATE_READ      = STATE_CMD_CONT + CAS_LATENCY + 4'd1;   // 
localparam STATE_LAST      = 3'd7;   // last state in cycle

assign dout = addr[0]?sd_data[7:0]:sd_data[15:8];

reg [2:0] q /* synthesis noprune */;
always @(posedge clk) begin
	// 112Mhz counter synchronous to 14 Mhz clock
   // force counter to pass state 5->6 exactly after the rising edge of clkref
	// since clkref is two clocks early
   if(((q == 7) && ( clkref == 0)) ||
		((q == 0) && ( clkref == 1)) ||
      ((q != 7) && (q != 0)))
			q <= q + 3'd1;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------
// 64ms/4096 rows = 15.6us refresh
// Refresh cycles: 15.6us * 64Mhz = 999
// Reset counter: 10 + 25 * 64Mhz = 1610

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [10:0] reset;
always @(posedge clk) begin
	if(init)	reset <= 11'd1610;
	else if((q == STATE_LAST) && (reset != 0))
		reset <= reset - 11'd1;
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

reg [3:0] sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign sd_cs  = sd_cmd[3];
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];

// drive ram data lines when writing, set them as inputs otherwise
// the eight bits are sent on both bytes ports. Which one's actually
// written depends on the state of dqm of which only one is active
// at a time when writing
assign sd_data = we?{din, din}:16'bZZZZZZZZZZZZZZZZ;

// assign dout = addr[0]?sd_data[7:0]:sd_data[15:8];

always @(posedge clk) begin
	sd_cmd <= CMD_INHIBIT;  // default: idle
	
	if(reset != 0) begin
		// initialization takes place at the end of the reset phase
		if(q == STATE_CMD_START) begin

			if(reset == 10) begin
				sd_cmd <= CMD_PRECHARGE;
				sd_addr[10] <= 1'b1;      // precharge all banks
			end
            
            if(reset <= 9 && reset > 1) begin
                sd_cmd <= CMD_AUTO_REFRESH;
            end
				
			if(reset == 1) begin
				sd_cmd <= CMD_LOAD_MODE;
				sd_addr <= MODE;
			end
			
		end
	end else begin
		// normal operation
		
		// -------------------  cpu/chipset read/write ----------------------
		if(we || oe) begin
		
			// RAS phase
			if(q == STATE_CMD_START) begin
				sd_cmd <= CMD_ACTIVE;
				sd_addr <= addr[20:9];
				sd_ba <= addr[22:21];
				
				// always return both bytes in a read. Only the correct byte
				// is being stored during read. On write only one of the two
				// bytes is enabled
				if(!we) sd_dqm <= 2'b00;
				else    sd_dqm <= { addr[0], ~addr[0] };
			end
				
			// CAS phase 
			if(q == STATE_CMD_CONT) begin
				sd_cmd <= we?CMD_WRITE:CMD_READ;
				sd_addr <= { 4'b0100, addr[8:1] };  // auto precharge
			end
		end

      // read phase
//		if(oe) begin
//			if(q == STATE_READ)
//				dout <= addr[0]?sd_data[7:0]:sd_data[15:8];
//		end
		
		// ------------------------ no access --------------------------
		else begin
			if(q == STATE_CMD_START)
				sd_cmd <= CMD_AUTO_REFRESH;
		end
	end
end

endmodule
