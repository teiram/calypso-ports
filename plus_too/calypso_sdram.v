//
// sdram.v
//
// sdram controller implementation for the cyc1000 FPGA board
// 
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

	inout  reg [15:0]   sd_data,    // 16 bit bidirectional data bus
	output reg [11:0]   sd_addr,    // 12 bit multiplexed address bus
	output reg [1:0]    sd_dqm,     // two byte masks
	output reg [1:0]    sd_ba,      // two banks
	output              sd_cs,      // a single chip select
	output              sd_we,      // write enable
	output              sd_ras,     // row address select
	output              sd_cas,     // columns address select

	// cpu/chipset interface
	input               init,       // init signal after FPGA config to initialize RAM
	input               clk_64,     // sdram is accessed at 64MHz
	input               clk_8,      // 8MHz chipset clock to which sdram state machine is synchonized

	input [15:0]        din,        // data input from chipset/cpu
	output reg [15:0]   dout,       // data output to chipset/cpu
	input [23:0]        addr,       // 24 bit word address
	input [1:0]         ds,         // upper/lower data strobe
	input               oe,         // cpu/chipset requests read
	input               we          // cpu/chipset requests write
);

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 2'b00, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 


// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

// The state machine runs at 128Mhz synchronous to the 8 Mhz chipset clock.
// It wraps from T15 to T0 on the rising edge of clk_8

localparam STATE_FIRST     = 3'd0;   // first state in cycle
localparam STATE_CMD_START = 3'd0;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // command can be continued
localparam STATE_READ      = STATE_CMD_CONT + CAS_LATENCY + 4'd1;
localparam STATE_LAST      = 3'd7;  // last state in cycle

reg [2:0] t;
always @(posedge clk_64) begin
	// 128Mhz counter synchronous to 8 Mhz clock
	// force counter to pass state 0 exactly after the rising edge of clk_8
	if(((t == STATE_LAST)  && ( clk_8 == 0)) ||
		((t == STATE_FIRST) && ( clk_8 == 1)) ||
		((t != STATE_LAST) && (t != STATE_FIRST)))
			t <= t + 3'd1;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// 64ms/4096 rows = 15.6us
// Refresh cycles: 15.6us * 64Mhz = 999
// Reset counter: 10 + 25 * 64Mhz = 1610


// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [10:0] reset;
always @(posedge clk_64) begin
	if(init)	reset <= 11'd1609;
	else if((t == STATE_LAST) && (reset != 0))
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

reg oe_latch, we_latch;

always @(posedge clk_64) begin
	sd_cmd <= CMD_INHIBIT;  // default: idle
	sd_data <= 16'bZZZZZZZZZZZZZZZZ;
    sd_ba <= 2'b11;
    
	if(reset != 0) begin
		// initialization takes place at the end of the reset phase
		if(t == STATE_CMD_START) begin

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
                sd_ba <= 2'b00;
			end

		end
	end else begin
		// normal operation

		// RAS phase
		// -------------------  cpu/chipset read/write ----------------------
		if(t == STATE_CMD_START) begin
			{oe_latch, we_latch} <= {oe, we};
			if (we || oe) begin
				sd_cmd <= CMD_ACTIVE;
				sd_addr <= addr[19:8];
				sd_ba <= addr[21:20];
			end
		// ------------------------ no access --------------------------
			else begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end
		end

		// CAS phase 
		if(t == STATE_CMD_CONT && (we_latch || oe_latch)) begin
			sd_cmd <= we_latch?CMD_WRITE:CMD_READ;
			if (we_latch) sd_data <= din;
			// always return both bytes in a read. The cpu may not
			// need it, but the caches need to be able to store everything
			if(!we_latch) sd_dqm <= 2'b00;
			else          sd_dqm <= ~ds;
			sd_addr <= { 3'b001, addr[22], addr[7:0] };  // auto precharge
		end

		// Data ready
		if (t == STATE_READ && oe_latch) dout <= sd_data;

	end
end

endmodule
