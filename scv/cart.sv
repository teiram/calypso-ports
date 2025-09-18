// Cartridge slot and cartridge

import scv_pkg::mapper_t;

module cart(
    input CLK,

    input INIT_SEL,
    input [16:0] INIT_ADDR,
    input [7:0] INIT_DATA,
    input INIT_VALID,

    input mapper_t MAPPER,
   
    input [14:0] A,
    input [7:0] DB_I,
    output reg [7:0] DB_O,
    output DB_OE,
    input RDB,
    input WRB,
    input CSB,
    input [6:5] PC,
   
    output [17:0] ram_addr,
    output [7:0] ram_din,
    input [7:0] ram_dout,
    output ram_oe,
    output ram_we
);

mapper_t id_mapper;

wire [4:0]  rom_size_log2;
wire [31:0] rom_cksum;
wire [16:0] rom_a;
wire rom_db_oe;
wire rom_csb /* synthesis keep */;

wire [12:0] ram_a;
wire ram_db_oe;
wire ram_csb /* synthesis keep */, ram_nwe, ram_noe;

cart_id id(
    .CLK(CLK),

    .ROM_SIZE_LOG2(rom_size_log2),
    .ROM_CKSUM(rom_cksum),

    .IN_MAPPER(MAPPER),
    .OUT_MAPPER(id_mapper)
);

cart_mapper mapper(
    .CLK(CLK),

    .MAPPER(id_mapper),

    .A(A),
    .RDB(RDB),
    .WRB(WRB),
    .CSB(CSB),
    .PC(PC),

    .ROM_A(rom_a),
    .ROM_CSB(rom_csb),

    .RAM_A(ram_a),
    .RAM_CSB(ram_csb)
);


/*
cart_rom rom
  (
   .CLK(CLK),

   .INIT_SEL(INIT_SEL),
   .INIT_ADDR(INIT_ADDR),
   .INIT_DATA(INIT_DATA),
   .INIT_VALID(INIT_VALID),

   .SIZE_LOG2(rom_size_log2),
   .CKSUM(rom_cksum),

   .A(rom_a),
   .DB(rom_db_o),
   .CSB(rom_csb)
   );



cart_ram ram
  (
   .CLK(CLK),

   .A(ram_a),
   .DI(DB_I),
   .DO(ram_db_o),
   .nCE(ram_csb),
   .nWE(ram_nwe),
   .nOE(ram_noe)
   );
*/
assign ram_nwe = WRB;
assign ram_noe = RDB;
assign rom_db_oe = ~rom_csb;
assign ram_db_oe = ~(ram_csb | ram_noe);
assign DB_OE = rom_db_oe | ram_db_oe;

always_comb begin
  DB_O = 8'hxx;
  if (DB_OE)
    DB_O = ram_dout;
end

assign ram_addr = INIT_SEL ? {1'b0, INIT_ADDR} :
    ~rom_csb ? {1'b0, rom_a} :
    ~ram_csb ? {5'b10000, ram_a} :
    {1'b0, rom_a};

assign ram_din = INIT_SEL ? INIT_DATA : DB_I;
assign ram_oe = INIT_SEL ? 1'b0 : ~(RDB | CSB);
assign ram_we = INIT_SEL ? INIT_VALID : ~(WRB | CSB);

function [4:0] size_log2_from_addr(input [16:0] addr);
  size_log2_from_addr = 5'd0;
  if (~|addr[16:13] & &addr[12:0])
    size_log2_from_addr = 5'd13; // 8K
  else if (~|addr[16:14] & &addr[13:0])
    size_log2_from_addr = 5'd14;
  else if (~|addr[16:15] & &addr[14:0])
    size_log2_from_addr = 5'd15;
  else if (~|addr[16:16] & &addr[15:0])
    size_log2_from_addr = 5'd16;
  else if (&addr[16:0])
    size_log2_from_addr = 5'd17; // 128K
endfunction

logic [31:0] cksum;
logic [4:0]  size_log2;
logic        init_sel_d;

always @(posedge CLK) begin
  if (INIT_SEL & ~init_sel_d) begin
    size_log2 <= 0;
    cksum <= 0;
  end
  else if (INIT_SEL & INIT_VALID) begin
    size_log2 <= size_log2_from_addr(INIT_ADDR);
    cksum <= cksum + 32'(INIT_DATA);
  end
  else if (~INIT_SEL & init_sel_d) begin
    rom_size_log2 <= size_log2;
    rom_cksum <= cksum;
  end

  init_sel_d <= INIT_SEL;
end

endmodule
