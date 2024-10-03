module sdram
(

	// interface to the MT48LC16M16 chip
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
	input      [22:0] addr,       // Restrict to a bank. 8MB total, 1MB@16 per bank: 20 + 1 bit
	input             oe,         // cpu/chipset requests read
	input             we,         // cpu/chipset requests write

	output reg [15:0] vram_dout,
	input      [22:0] vram_addr,

	input      [22:0] tape_addr,
	input       [7:0] tape_din,
	output reg  [7:0] tape_dout,
	input             tape_wr,
	input             tape_rd,
	output reg        tape_ack
);

assign SDRAM_CKE = ~init;
assign dout = oe ? ram_dout : 8'hFF;

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

reg  [2:0] q;
reg [22:0] a, addr_next;
reg        wr, wr_next;
reg        ram_req=0, ram_req_next;
reg        vram_req=0, vram_req_next;
reg        tape_req=0, tape_req_next;

reg [22:0] old_addr;
reg old_rd, old_we;

// access manager
always @(posedge clk) begin
	reg old_ref;

	old_rd<=oe;
	old_we<=we;
	old_ref<=clkref;

	q <= q + 3'd1;
	if(~old_ref & clkref) q <= 0;

	if (q == STATE_START) begin
		ram_req <= ram_req_next;
		vram_req <= vram_req_next;
		tape_req <= tape_req_next;
		wr <= wr_next;
		a <= addr_next;
		if (vram_req_next) old_addr <= vram_addr;
	end
end

always @(*) begin

	ram_req_next = 0;
	vram_req_next = 0;
	tape_req_next = 0;
	wr_next = 0;
	addr_next = 0;

	if((~old_rd & oe) | (~old_we & we)) begin
		ram_req_next = 1;
		wr_next = we;
		addr_next = addr;
	end
	else if(tape_rd | tape_wr) begin
		tape_req_next = 1;
		wr_next = tape_wr;
		addr_next = tape_addr;
	end else if(old_addr[15:1] != vram_addr[15:1]) begin
		vram_req_next = 1;
		addr_next = vram_addr;
	end
end

localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

localparam RST_COUNT =  11'd1610; //11'd10 (conf cycles) + (11'd25 * 64Mhz)

// initialization 
reg [1:0] mode;
always @(posedge clk) begin
	reg [10:0] reset = RST_COUNT;
	reg init_old=0;
	init_old <= init;

	if(init_old & ~init) reset <= RST_COUNT;
	else if (q == STATE_LAST) begin
		if(reset != 0) begin
			reset <= reset - 11'd1;
			if(reset == 10) begin
				mode <= MODE_PRE;
			end
			if(reset <= 9 && reset > 1) begin
				mode <= MODE_NORMAL;
			end
			if(reset == 1) begin
				mode <= MODE_LDM;
			end
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
   {SDRAM_DQMH,SDRAM_DQML} <= 2'b11;
	
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
		if(ram_req_next | vram_req_next | tape_req_next) begin
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
			SDRAM_A <= addr_next[19:8];
			SDRAM_BA <= tape_req_next ? 2'b10 : bank;
			if(ram_req_next & wr_next) ram_dout <= din;
		end else
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;

		{MODE_NORMAL, STATE_CONT}:
		if(ram_req | vram_req | tape_req) begin
			SDRAM_A <= {4'b0100, a[20], a[7:1]};
			{SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= wr ? CMD_WRITE : CMD_READ;
			if (wr) SDRAM_DQ <= tape_req ? {tape_din, tape_din} : {din, din};
			{SDRAM_DQMH,SDRAM_DQML} <= {~a[0] & wr, a[0] & wr};
		end

		{MODE_NORMAL, STATE_READ}:
		begin
			if (~wr & ram_req) ram_dout <= a[0] ? sdram_din[15:8] : sdram_din[7:0];
			else if (vram_req) vram_dout <= sdram_din;
			else if (~wr & tape_req) tape_dout <= a[0] ? sdram_din[15:8] : sdram_din[7:0];
			if (tape_req) tape_ack <= ~tape_ack;
		end

		default: ;

	endcase
end

endmodule
