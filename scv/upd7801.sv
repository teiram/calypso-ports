// NEC uPD7801 - uPD7800 + internal ROM + RAM
//
// Copyright (c) 2024 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.


`timescale 1us / 1ns

module upd7801
  (
   input         CLK,
   input         CP1_POSEDGE, // clock phase 1, +ve edge
   input         CP1_NEGEDGE, //  "             -ve edge
   input         CP2_POSEDGE, // clock phase 2, +ve edge
   input         CP2_NEGEDGE, //  "             -ve edge
   input         RESETB, // reset (active-low)

   input         INIT_SEL_BOOT,
   input [24:0]  INIT_ADDR,
   input [7:0]   INIT_DATA,
   input         INIT_VALID,

   input         INT0,
   input         INT1,
   input         INT2,
   output [15:0] A,
   output        A_OE,
   input [7:0]   DB_I,
   output [7:0]  DB_O,
   output        DB_OE,
   input         WAITB, // extend T2 request (memory not ready)
   output        M1, // opcode fetch cycle
   output        RDB, // read
   output        WRB, // write
   output [7:0]  PA_O, // Port A
   input [7:0]   PB_I, // Port B
   output [7:0]  PB_O,
   output [7:0]  PB_OE,
   input [7:0]   PC_I, // Port C
   output [7:0]  PC_O,
   output [7:0]  PC_OE
   );


wire [15:0] a;

wire [15:0] core_a;
reg [7:0]   core_db;
wire [7:0]  core_db_o;
wire        core_db_oe;
wire        core_rdb, core_wrb;

wire [7:0]  rom_db;
wire        rom_db_oe;
wire        rom_ncs;

wire [7:0]  wram_db;
wire        wram_db_oe;
wire        wram_ncs;

upd7800 core
  (
   .CLK(CLK),
   .CP1_POSEDGE(CP1_POSEDGE),
   .CP1_NEGEDGE(CP1_NEGEDGE),
   .CP2_POSEDGE(CP2_POSEDGE),
   .CP2_NEGEDGE(CP2_NEGEDGE),
   .RESETB(RESETB),
   .INT0(INT0),
   .INT1(INT1),
   .INT2(INT2),
   .A(core_a),
   .DB_I(core_db),
   .DB_O(core_db_o),
   .DB_OE(core_db_oe),
   .WAITB(WAITB),
   .M1(M1),
   .RDB(core_rdb),
   .WRB(core_wrb),
   .PA_O(PA_O),
   .PB_I(PB_I),
   .PB_O(PB_O),
   .PB_OE(PB_OE),
   .PC_I(PC_I),
   .PC_O(PC_O),
   .PC_OE(PC_OE)
   );

rom rom
  (
   .INIT_CLK(CLK),
   .INIT_ADDR(INIT_ADDR[11:0]),
   .INIT_DATA(INIT_DATA),
   .INIT_VALID(INIT_SEL_BOOT & INIT_VALID),
   .A(core_a[11:0]),
   .DB(rom_db),
   .nCS(rom_ncs)
   );

wram wram
  (
   .CLK(CLK),
   .nCE(wram_ncs),
   .nWE(core_wrb),
   .nOE(~wram_db_oe),
   .A(core_a[6:0]),
   .DI(core_db),
   .DO(wram_db)
   );

assign rom_ncs = |core_a[15:12];  // 'h0000-'h0FFF
assign wram_ncs = ~&core_a[15:7]; // 'hFF80-'hFFFF

assign rom_db_oe = ~(rom_ncs | core_rdb);
assign wram_db_oe = ~(wram_ncs | core_rdb);

always_comb begin
  if (core_db_oe)
    core_db = core_db_o;
  else if (rom_db_oe)
    core_db = rom_db;
  else if (wram_db_oe)
    core_db = wram_db;
  else
    core_db = DB_I;
end

// External memory bus is disabled when internal memory is addressed.
assign A_OE = RESETB & rom_ncs & wram_ncs;
assign A = A_OE ? core_a : 0;

assign DB_OE = core_db_oe & A_OE;
assign DB_O = DB_OE ? core_db_o : 0;

assign RDB = core_rdb | ~A_OE;
assign WRB = core_wrb | ~A_OE;

endmodule


//////////////////////////////////////////////////////////////////////

module rom
  (
   input        INIT_CLK,
   input [11:0] INIT_ADDR,
   input [7:0]  INIT_DATA,
   input        INIT_VALID,
   input [11:0] A,
   output [7:0] DB,
   input        nCS
   );

logic [7:0] mem [1 << 12];

//assign DB = ~nCS ? mem[A] : 'X;

always @(posedge INIT_CLK) begin
    DB <= ~nCS ? mem[A] : 'X;
end

always @(posedge INIT_CLK) begin
  if (INIT_VALID) begin
    mem[INIT_ADDR] = INIT_DATA;
  end
end

endmodule


//////////////////////////////////////////////////////////////////////

module wram
  (
   input        CLK,
   input        nCE,
   input        nWE,
   input        nOE,
   input [6:0]  A,
   input [7:0]  DI,
   output [7:0] DO
   );

reg [7:0] mem [1 << 7];
reg [7:0] dor;

// Undefined RAM contents make simulation eventually die.
initial begin
int i;
  for (i = 0; i < (1 << 7); i++)
    mem[i] = 0;
end

always @(posedge CLK)
  dor <= mem[A];

assign DO = ~(nCE | nOE) ? dor : 'X;

always @(negedge CLK) begin
  if (~(nCE | nWE)) begin
    mem[A] <= DI;
  end
end

endmodule
