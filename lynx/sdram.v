//-------------------------------------------------------------------------------------------------
module sdram
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       reset,
	output reg        ready,

	input  wire       refresh,
	input  wire       write,
	input  wire       read,
	input  wire[15:0] portD,
	output reg [15:0] portQ,
	input  wire[23:0] portA,

	output reg        ramCs,
	output reg        ramRas,
	output reg        ramCas,
	output reg        ramWe,
	output reg [ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output reg [ 1:0] ramBa,
	output reg [12:0] ramA
);
//-------------------------------------------------------------------------------------------------
`include "sdram_cmd.v"
//-------------------------------------------------------------------------------------------------

reg[15:0] ramQ = 1'd0;
assign ramDQ = ramWe ? 16'bZ : ramQ;

//-----------------------------------------------------------------------------

reg rs = 1'b0, rs2 = 1'b0;
reg rd = 1'b0, rd2 = 1'b0;
reg wr = 1'b0, wr2 = 1'b0;
reg rf = 1'b0, rf2 = 1'b0;

always @(negedge clock)
begin
	rs2 <= reset;
	rs  <= !reset && rs2;

	rd2 <= read;
	rd  <= !read && rd2;

	wr2 <= write;
	wr  <= !write && wr2;

	rf2 <= refresh;
	rf  <= !refresh && rf2;
end

//-----------------------------------------------------------------------------

localparam sINIT = 0;
localparam sIDLE = 1;
localparam sREAD = 2;
localparam sWRITE = 3;
localparam sREFRESH = 4;

reg counting = 1'b0;
reg[4:0] count = 1'd0;
reg[2:0] state = 1'd0;

always @(posedge clock)
if(rs) state <= sINIT;
else
begin
	NOP;														// default state is NOP
	if(counting) count <= count+1'd1; else count <= 1'd0;

	case(state)
	sINIT:
	begin
		counting <= 1'b1;

		case(count)
		 0: ready <= 1'b0;
		 4: PRECHARGE(1'b1);									// PRECHARGE: all, tRP's minimum value is 20ns
		 8: REFRESH;											// REFRESH, tRFC's minimum value is 60ns
		12: REFRESH;											// REFRESH, tRFC's minimum value is 60ns
		16: LMR(13'b000_1_00_010_0_000);						// LDM: CL = 2, BT = seq, BL = 1, 20ns
		31:
		begin
			ready <= 1'b1;
			state <= sIDLE;
		end
		endcase
	end
	sIDLE:
	begin
		counting <= 1'b0;

		if(rd) state <= sREAD; else
		if(wr) state <= sWRITE; else
		if(rf) state <= sREFRESH;
	end
	sREAD:
	begin
		counting <= 1'b1;

		case(count)
		0: ACTIVE(portA[21:20], portA[19:8]);
		3: READ(2'b00, 2'b00, portA[7:0], 1'b1);
		6: portQ <= ramDQ;
		7: state <= sIDLE;
		endcase
	end
	sWRITE:
	begin
		counting <= 1'b1;

		case(count)
		0: ACTIVE(portA[21:20], portA[19:8]);
		3: WRITE(2'b00, portD, 2'b00, portA[7:0], 1'b1);
		7: state <= sIDLE;
		endcase
	end
	sREFRESH:
	begin
		counting <= 1'b1;
		case(count)
		1: REFRESH;
		7: state <= sIDLE;
		endcase
	end
	endcase
end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
