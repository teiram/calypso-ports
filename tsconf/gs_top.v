module gs_top
(
   input         RESET,
   input         CLK,

   input         A,
   input   [7:0] DI,
   output  [7:0] DO,
   input         CS_n,
   input         WR_n,
   input         RD_n,

   output [23:0] DRAM_ADDR,
   output  [2:0] DRAM_BSEL,
   output [15:0] DRAM_DI,
   input  [15:0] DRAM_DO,
   output        DRAM_REQ,
   output        DRAM_RNW,
   input         DRAM_ACK,

   output [14:0] OUTL,
   output [14:0] OUTR,

   input         ROM_INITING
);

  wire [20:0] mem_addr;
//  assign DRAM_ADDR = {4'b0100, mem_addr[20:1]};
  assign DRAM_ADDR = {4'b0011, mem_addr[20:1]};

  assign DRAM_BSEL = {mem_addr[0], ~mem_addr[0]};

  wire [15:0] mem_do16 = cache_hit? cache_do : DRAM_DO;
  wire [7:0] mem_do =  mem_addr[0]? mem_do16[15:8] : mem_do16[7:0];
  wire [7:0] mem_di;
  assign DRAM_DI = {mem_di, mem_di};

  wire mem_rd;
  wire mem_wr;
  assign DRAM_RNW = ~mem_wr;
  reg dram_req = 0;
  assign DRAM_REQ = dram_req && !DRAM_ACK;
  reg mem_rdwr = 0;

  always @(posedge CLK) begin
    if (((mem_rd && !cache_hit) || mem_wr) && !mem_rdwr)
      dram_req <= 1'b1;
    else if (DRAM_ACK)
      dram_req <= 1'b0;
    mem_rdwr <= mem_rd || mem_wr;
  end


  wire [7:0] cache_al = mem_addr[8:1];
  wire [11:0] cache_ah = mem_addr[20:9];
  wire [15:0] cache_do;
  wire [11:0] cache_rd_ah;
  wire cache_rd_v;
  wire cache_hit = (cache_ah == cache_rd_ah) && cache_rd_v;
  wire cache_inv = (cache_ah == cache_rd_ah) && mem_wr;

  dpram #(.DATAWIDTH(16), .ADDRWIDTH(8)) cache_data
  (
    .clock(CLK),
    .address_a(cache_al),
    .data_a(DRAM_DO),
    .wren_a(DRAM_ACK && mem_rd),
    .address_b(cache_al),
    .q_b(cache_do)
  );

  dpram #(.DATAWIDTH(13), .ADDRWIDTH(8)) cache_addr
  (
    .clock(CLK),
    .address_a(cache_al),
    .data_a({~cache_inv, cache_ah}),
    .wren_a(DRAM_ACK && (mem_rd || cache_inv)),
    .address_b(cache_al),
    .q_b({cache_rd_v, cache_rd_ah})
  );


  reg rom_inited = 1'b0, rom_initing = 1'b0;
  always @(posedge CLK) begin
    if (!ROM_INITING && rom_initing)
      rom_inited <= 1'b1;
    rom_initing <= ROM_INITING;
  end

  reg reset;
  always @(posedge CLK)
    reset <= RESET || !rom_inited;

  reg ce_14m;
  always @(negedge CLK) begin
    reg [2:0] div;
    div <= div + 1'd1;
    if(div == 5) div <= 0;
    ce_14m <= !div;
  end


  gs #(.INT_DIV(373)) gs
  (
    .RESET(reset),
    .CLK(CLK),
    .CE(ce_14m),

    .A(A),
    .DI(DI),
    .DO(DO),
    .CS_n(CS_n),
    .WR_n(WR_n),
    .RD_n(RD_n),

    .MEM_ADDR(mem_addr),
    .MEM_DI(mem_di),
    .MEM_DO(mem_do),
    .MEM_RD(mem_rd),
    .MEM_WR(mem_wr),
    .MEM_WAIT(DRAM_REQ),

    .OUTL(OUTL),
    .OUTR(OUTR)
  );

endmodule
