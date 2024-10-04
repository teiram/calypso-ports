//
// sdram.v
//
// sdram controller implementation for the Calypso board
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

	output reg [11:0] sd_addr,    // 12 bit multiplexed address bus
	inout  reg [15:0] sd_data,
	output reg [ 1:0] sd_ba,      // two banks
	output            sd_cs,      // a single chip select
	output            sd_we,      // write enable
	output            sd_ras,     // row address select
	output            sd_cas,     // columns address select
	output reg        sd_dqml,
	output reg        sd_dqmh,

	// cpu/chipset interface
	input             init,     // init signal after FPGA config to initialize RAM
	input             clk,      // sdram is accessed at up to 128MHz

	input   [1:0]     bs,         // byte selects
	input  [23:0]     addr,       // address (with byte selects we can only cover 4MB@16bits)
	input  [15:0]     din,
	output reg [15:0] dout,

	input             refresh,    // refresh cycle
	input             ce,         // cpu/chipset access
	input             we          // cpu/chipset requests write
);

// no burst configured
localparam RASCAS_DELAY   = 3'd2;   // tRCD>=20ns -> 2 cycles@64MHz
localparam BURST_LENGTH   = 3'b000; // 000=none, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_IDLE      = 3'd0;   // first state in cycle
localparam STATE_CMD_START = 3'd0;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // 2 command can be continued
localparam STATE_CMD_DATA  = STATE_CMD_CONT + CAS_LATENCY + 1'd1;
localparam STATE_LAST      = 3'd7;   // last state in cycle

reg [2:0] q /* synthesis noprune */;
reg last_ce, last_refresh;
always @(posedge clk) begin
	last_ce <= ce;
	last_refresh <= refresh;

	// start a new cycle in rising edge of ce or refresh
	if((ce && !last_ce) || (refresh && !last_refresh))
		q <= 3'd1;

	if(q != 0)
		q <= q + 3'd1;

end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------
// 64ms/4096 rows = 15.6us refresh
// Refresh cycles: 15.6us * 64Mhz = 999
// Reset counter: 10 + 25 * 64Mhz = 1610


// wait 1ms (32 clkref cycles) after FPGA config is done before going
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
wire [11:0] reset_addr = (reset == 10) ? 12'b010000000000 : MODE;
wire [11:0] run_addr = (q == STATE_CMD_START) ? addr[19:8] : {4'b0100, addr[7:0]};

always @(posedge clk) begin
	sd_cmd  <= CMD_INHIBIT;
	sd_addr <= (reset != 0) ? reset_addr : run_addr;
	sd_ba   <= addr[21:20];
	sd_data <= 16'bZZZZZZZZZZZZZZZZ;
	sd_dqml <= 1;
	sd_dqmh <= 1;

	if(reset != 0) begin
		if(q == STATE_IDLE) begin
			if(reset == 10)  sd_cmd <= CMD_PRECHARGE;
            if(reset <= 9 && reset > 1) sd_cmd <= CMD_AUTO_REFRESH;
			if(reset ==  1)  sd_cmd <= CMD_LOAD_MODE;
		end
	end else begin
		if(q == STATE_IDLE) begin
			if(ce && !last_ce)           sd_cmd <= CMD_ACTIVE;
			if(refresh && !last_refresh) sd_cmd <= CMD_AUTO_REFRESH;
		end else if((q == STATE_CMD_CONT)&&(!refresh)) begin
			if(we) begin
				sd_cmd <= CMD_WRITE;
				sd_data <= din;
				sd_dqml <= ~bs[0];
				sd_dqmh <= ~bs[1];
			end else if(ce) begin
				sd_cmd <= CMD_READ;
				sd_dqml <= 0;
				sd_dqmh <= 0;
			end
		end else if((q == STATE_CMD_DATA) && ce && !we && !refresh) begin
			dout <= sd_data;
		end
	end
end

endmodule
