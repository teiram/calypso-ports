// Super Cassette Vision - an emulator
//
// Copyright (c) 2024-2025 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

// References:
// . https://forums.atariage.com/topic/130365-atari-7800-vs-epoch-super-cassette-vision/ - [takeda.txt]
// . http://takeda-toshiya.my.coocan.jp/scv/index.html


`timescale 1us / 1ns

import scv_pkg::*;

module scv
  (
   input         CLK, // clock (video XTAL * 2)
   input         RESB,

   input         ROMINIT_SEL_BOOT,
   input         ROMINIT_SEL_CHR,
   input         ROMINIT_SEL_CART,
   input         ROMINIT_SEL_APU,
   input [24:0]  ROMINIT_ADDR,
   input [7:0]   ROMINIT_DATA,
   input         ROMINIT_VALID,

   input         mapper_t MAPPER,
   input         palette_t VDC_PALETTE,
   input         overscan_mask_t VDC_OVERSCAN_MASK,

   input         hmi_t HMI,

   output        VID_PCE,
   output        VID_DE,
   output        VID_HS,
   output        VID_VS,
   output [23:0] VID_RGB,

   output [8:0]  AUD_PCM,
   
   output [17:0] ram_addr,
   output [7:0] ram_din,
   input [7:0] ram_dout,
   output ram_oe,
   output ram_we
   );

wire        cp1p, cp1n, cp2p, cp2n;
wire        vdc_ce, aud_ce;

wire [15:0] cpu_a, cpu_a_o;
wire        cpu_a_oe;
reg [7:0]   cpu_db;
wire [7:0]  cpu_db_o;
wire        cpu_db_oe;
wire        cpu_rdb, cpu_wrb;

wire        cart_ncs;
wire [7:0]  cart_db;
wire        cart_db_oe;

wire [7:0]  vdc_db_o;
wire        vdc_db_oe;
wire        vdc_ncs;
wire        vdc_waitb;
wire        vdc_scpub;
wire [10:0] va;
wire [7:0]  vd_i, vd_o, vrama_do, vramb_do;
wire        nvwe;
wire [1:0]  nvcs;
wire        vbl;
wire        de, hs, vs;
wire [23:0] rgb;

wire        apu_ncs;
wire        apu_ack;
wire [7:0]  apu_pb_o;

wire [7:0]  pao, pbi, pci, pco;

clkgen clkgen
  (
   .CLK(CLK),
   .CP1_POSEDGE(cp1p),
   .CP1_NEGEDGE(cp1n),
   .CP2_POSEDGE(cp2p),
   .CP2_NEGEDGE(cp2n),
   .VDC_CE(vdc_ce),
   .AUD_CE(aud_ce)
   );

upd7801 cpu
  (
   .CLK(CLK),
   .CP1_POSEDGE(cp1p),
   .CP1_NEGEDGE(cp1n),
   .CP2_POSEDGE(cp2p),
   .CP2_NEGEDGE(cp2n),
   .RESETB(RESB),

   .INIT_SEL_BOOT(ROMINIT_SEL_BOOT),
   .INIT_ADDR(ROMINIT_ADDR),
   .INIT_DATA(ROMINIT_DATA),
   .INIT_VALID(ROMINIT_VALID),

   .INT0(1'b0),
   .INT1(apu_ack),
   .INT2(vbl),
   .A(cpu_a_o),
   .A_OE(cpu_a_oe),
   .DB_I(cpu_db),
   .DB_O(cpu_db_o),
   .DB_OE(cpu_db_oe),
   .WAITB(vdc_waitb),
   .M1(),
   .RDB(cpu_rdb),
   .WRB(cpu_wrb),
   .PA_O(pao),
   .PB_I(pbi),
   .PB_O(),
   .PB_OE(),
   .PC_I(pci),
   .PC_O(pco),
   .PC_OE()
   );

epochtv1 vdc
  (
   .CLK(CLK),
   .CE(vdc_ce),

   .CFG_PALETTE(VDC_PALETTE),
   .CFG_OVERSCAN_MASK(VDC_OVERSCAN_MASK),

   .ROMINIT_SEL_CHR(ROMINIT_SEL_CHR),
   .ROMINIT_ADDR(ROMINIT_ADDR[9:0]),
   .ROMINIT_DATA(ROMINIT_DATA),
   .ROMINIT_VALID(ROMINIT_VALID),

   .CP1_POSEDGE(cp1p),
   .A(cpu_a[12:0]),
   .DB_I(cpu_db),
   .DB_O(vdc_db_o),
   .DB_OE(vdc_db_oe),
   .RDB(cpu_rdb),
   .WRB(cpu_wrb),
   .CSB(vdc_ncs),
   .WAITB(vdc_waitb),
   .SCPUB(vdc_scpub),

   .VA(va),
   .VD_I(vd_i),
   .VD_O(vd_o),
   .nVWE(nvwe),
   .nVCS(nvcs),

   .VBL(vbl),
   .DE(de),
   .HS(hs),
   .VS(vs),
   .RGB(rgb)
   );

dpram #(.DWIDTH(8), .AWIDTH(11)) vrama
  (
   .CLK(CLK),

   .nCE(nvcs[0]),
   .nWE(nvwe),
   .nOE(~nvwe),
   .A(va),
   .DI(vd_o),
   .DO(vrama_do),

   .nCE2(1'b1),
   .nWE2(1'b1),
   .nOE2(1'b1),
   .A2(),
   .DI2(),
   .DO2()
   );

dpram #(.DWIDTH(8), .AWIDTH(11)) vramb
  (
   .CLK(CLK),

   .nCE(nvcs[1]),
   .nWE(nvwe),
   .nOE(~nvwe),
   .A(va),
   .DI(vd_o),
   .DO(vramb_do),

   .nCE2(1'b1),
   .nWE2(1'b1),
   .nOE2(1'b1),
   .A2(),
   .DI2(),
   .DO2()
   );

assign vd_i = (~nvcs[0]) ? vrama_do : (~nvcs[1]) ? vramb_do : 8'hxx;
assign apu_ack = apu_pb_o[0];

upd1771c apu
  (
   .CLK(CLK),
   .CKEN(aud_ce),
   .RESB(pco[3]),
   .INIT_SEL(ROMINIT_SEL_APU),
   .INIT_ADDR(ROMINIT_ADDR[9:0]),
   .INIT_DATA(ROMINIT_DATA),
   .INIT_VALID(ROMINIT_VALID),
   .CH1('1),
   .CH2('0),
   .PA_I(cpu_db),
   .PA_O(),
   .PA_OE(),
   .PB_I({vdc_scpub, cpu_wrb, ~6'b0}),
   .PB_O(apu_pb_o),
   .PB_OE(),
   .PCM_OUT(AUD_PCM)
   );

hmi2key hmi2key
  (
   .HMI(HMI),

   .KEY_COL(pao),
   .KEY_ROW(pbi),
   .PAUSE(pci[0])
   );

cart cart
  (
   .CLK(CLK),

   .INIT_SEL(ROMINIT_SEL_CART),
   .INIT_ADDR(ROMINIT_ADDR[16:0]),
   .INIT_DATA(ROMINIT_DATA),
   .INIT_VALID(ROMINIT_VALID),

   .MAPPER(MAPPER),

   .A(cpu_a[14:0]),
   .DB_I(cpu_db),
   .DB_O(cart_db),
   .DB_OE(cart_db_oe),
   .CSB(cart_ncs),
   .RDB(cpu_rdb),
   .WRB(cpu_wrb),
   .PC(pco[6:5]),
   
   .ram_addr(ram_addr),
   .ram_din(ram_din),
   .ram_dout(ram_dout),
   .ram_oe(ram_oe),
   .ram_we(ram_we)
   );

// A[15] is externally pulled up, effectively making it VDC chip select.
assign cpu_a = {~cpu_a_oe | cpu_a_o[15], cpu_a_o[14:0]};
assign vdc_ncs = cpu_a[15];
assign cart_ncs = ~vdc_ncs;

always_comb begin
  cpu_db = 8'hxx;
  if (cpu_db_oe)
    cpu_db = cpu_db_o;
  else if (vdc_db_oe)
    cpu_db = vdc_db_o;
  else if (cart_db_oe)
    cpu_db = cart_db;
end

assign pci[7:1] = 0;            // unused

assign VID_PCE = vdc_ce;
assign VID_DE = de;
assign VID_HS = hs;
assign VID_VS = vs;
assign VID_RGB = rgb;

endmodule

//////////////////////////////////////////////////////////////////////

module clkgen
  (
   // CLK: 2 * video XTAL = 2 * 14.318181 MHz
   input  CLK,

   // 2-phase CPU clock: (CLK * 88 / 315) / 4 = 2.000000 MHz
   output CP1_POSEDGE, // clock phase 1, +ve edge
   output CP1_NEGEDGE, //  "             -ve edge
   output CP2_POSEDGE, // clock phase 2, +ve edge
   output CP2_NEGEDGE, //  "             -ve edge

   // VDC clock: CLK / 7 = 4.090909 MHz
   output VDC_CE,

   // Audio clock: CLK * 22 / 105 = 6.000000 MHz
   output AUD_CE
   );

reg [8:0] c4cnt, c4cntn;        // 8.0 MHz
reg [1:0] ccnt;                 // 2.0 MHz
reg [2:0] vcnt;
reg [6:0] acnt, acntn;
wire      cpu4_ce;

localparam [8:0] CPU4_MUL = 9'd88;
localparam [8:0] CPU4_DIV = 9'd315;
localparam [6:0] AUD_MUL = 7'd22;
localparam [6:0] AUD_DIV = 7'd105;

initial begin
  c4cnt = 0;
  ccnt = 0;
  vcnt = 0;
  acnt = 0;
end

assign c4cntn = c4cnt + CPU4_MUL;
assign acntn = acnt + AUD_MUL;

always_ff @(posedge CLK) begin
  c4cnt <= cpu4_ce ? (c4cntn - CPU4_DIV) : c4cntn;
  acnt <= AUD_CE ? (acntn - AUD_DIV) : acntn;

  ccnt <= cpu4_ce ? ccnt + 1'd1 : ccnt;

  vcnt <= VDC_CE ? 0 : vcnt + 1'd1;
end

assign cpu4_ce = c4cntn >= CPU4_DIV;
assign AUD_CE = acntn >= AUD_DIV;

assign CP2_NEGEDGE = cpu4_ce & (ccnt == 2'd0);
assign CP1_POSEDGE = cpu4_ce & (ccnt == 2'd1);
assign CP1_NEGEDGE = cpu4_ce & (ccnt == 2'd2);
assign CP2_POSEDGE = cpu4_ce & (ccnt == 2'd3);

assign VDC_CE = vcnt == 3'd6;

endmodule
