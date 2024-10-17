//
// sdram.v
//
// sdram controller implementation for bbc micro on the Calypso board
//
// Based on Mist work: Copyright (c) 2015 Till Harbaum <till@harbaum.org> 
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

	// interface to the winbond W9864G6JT chip
	inout  reg [15:0] sd_data, // 16 bit bidirectional data bus
	output reg [11:0]	sd_addr, // 12 bit multiplexed address bus
	output reg [1:0]  sd_dqm,  // two byte masks
	output reg[1:0]   sd_ba,   // two banks
	output            sd_cs,   // a single chip select
	output            sd_we,   // write enable
	output            sd_ras,  // row address select
	output            sd_cas,  // columns address select

	// cpu/chipset interface
	input 		 		init,			// init signal after FPGA config to initialize RAM
	input 		 		clk,			// sdram is accessed at up to 128MHz
	input					sync,			// signal to sync to state counter to
	output            ready,      // sdram is done initializing

	input					vid_blnk,

	input [7:0]  		cpu_di,		// data input from cpu
	input [24:0]   	cpu_adr,    // 24 bit cpu word address
	output reg [7:0] 	cpu_do,		// data output to cpu needs to be latched
	input 		 		cpu_we      // cpu requests write
);

// no burst configured
localparam RASCAS_DELAY   = 3'd1;   // tRCD>=20ns -> 1 cycle@32MHz
localparam BURST_LENGTH   = 3'b000; // 000=none, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_IDLE      = 4'd0;   // first state in cycle
localparam STATE_CMD_START = 4'd1;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY - 3'd1; // 4 command can be continued
localparam STATE_LAST      = 4'd11;   // last state in cycle

// the state counter runs through four full memory cycles @ 8 clocks each. It synchronizes 
// itself to the cpu cycle. The first fill memory cycle is used for the CPU and the second
// and fourth is used for video. The third cycle is refresh

reg [3:0] q;
reg       vid_cyc;
reg       cpu_cyc;

always @(posedge clk) begin
	// 48Mhz counter synchronous to cpu
	if( sync ) begin
		vid_cyc <= 1;
		cpu_cyc <= 0;
		q <= 0;
	end else if (q == STATE_LAST) begin
		vid_cyc <= 0;
		cpu_cyc <= 1;
		q <= 0;
	end
	else q <= q + 1'd1;
end

// switch between video and cpu address
wire [24:0] addr = cpu_adr;

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

assign ready = (reset == 0);

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate
// 64ms/4096 rows = 15.6us
localparam RFRSH_CYCLES = 16'd156 * MHZ / 10;
localparam RST_COUNT = 11'd10 + 11'd25 * MHZ;

// wait 1ms (32 clkref cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [10:0] reset;
always @(posedge clk) begin
	if(init)	reset <= RST_COUNT;
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

always @(posedge clk) begin

	sd_cmd <= CMD_INHIBIT;
	sd_data <= 16'bZZZZZZZZZZZZZZZZ;

	if(reset != 0) begin
		sd_ba <= 2'b00;
		sd_dqm <= 2'b00;
			
		if(reset == 10) sd_addr <= 12'b001000000000;
		else   			 sd_addr <= MODE;

		if(q == STATE_IDLE) begin
			if(reset == 10)  sd_cmd <= CMD_PRECHARGE;
            if(reset <= 9 && reset > 1) sd_cmd <= CMD_AUTO_REFRESH;
			if(reset ==  1)  sd_cmd <= CMD_LOAD_MODE;
		end
	end else begin

		if(q == STATE_IDLE) begin
			sd_cmd <= CMD_AUTO_REFRESH;

			if(cpu_cyc || (vid_cyc && !vid_blnk)) begin// CPU or video transfers data
				sd_cmd <= CMD_ACTIVE;
				sd_addr <= addr[20:9];
				sd_ba <= addr[22:21];
				sd_dqm <= { addr[0], !addr[0] };
			end

		end else if(q == STATE_CMD_CONT) begin
			sd_addr <= { 4'b0100, addr[8:1]};
			if(cpu_cyc) begin  			// CPU reads or writes
				if(cpu_we) begin
					sd_cmd <= CMD_WRITE;
					sd_data <= {cpu_di,cpu_di};
				end
				else 			 sd_cmd <= CMD_READ;
			end else if(vid_cyc && !vid_blnk)      // video always reads
								 sd_cmd <= CMD_READ;
		end else if (q == 5) begin
			cpu_do <= addr[0]?sd_data[7:0]:sd_data[15:8];
		end
	end

end

endmodule
