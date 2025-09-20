//--------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation by Kyp
// https://github.com/Kyp069/lynx
//--------------------------------------------------------------------
module main
//--------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       power,
	input  wire       reset,
	output wire       ce,

	input  wire       ramX,
	input  wire       romS,
	input  wire       casM,

	output wire       hSync,
	output wire       vSync,
	output wire       r,
	output wire       g,
	output wire       b,

	input  wire       tape,
	output wire       sound,
    output wire [5:0] audio,

	input  wire       keyPrss,
	input  wire       keyStrb,
	input  wire[ 7:0] keyCode,

	input  wire[ 5:0] joy,
`ifdef ZX1
	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
`elsif SIDI
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBa,
	output wire[12:0] ramA,
    input wire clockSdram
`endif
);
//-------------------------------------------------------------------------------------------------

reg[5:0] ce6;
always @(negedge clock) ce6 <= ce6+1'd1;

wire pe06M = ~ce6[0] &  ce6[1];
wire peM75 = ~ce6[0] & ~ce6[1] & ~ce6[2] & ~ce6[3] &  ce6[4];

reg[3:0] ce4;
always @(negedge clock) if(pe04M) ce4 <= 1'd0; else ce4 <= ce4+1'd1;

wire pe04M =  ce4[0]          &  ce4[2];
wire ne04M = ~ce4[0] & ce4[1] & ~ce4[2];

assign ce = pe06M;

//-------------------------------------------------------------------------------------------------

wire cpurs = power & reset & init;
wire mi = ~cursor;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;
wire rfsh;
wire mreq;
wire iorq;
wire rd;
wire wr;
wire ready;
wire crtcDe;
wire cursor;

cpu Cpu
(
	.clock  (clock  ),
	.reset  (cpurs  ),
	.pe     (pe04M  ),
	.ne     (ne04M  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.mi     (mi     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

reg[7:0] reg7F;
wire wr7F = !(!iorq && !wr && a[6:0] == 7'h7F);
always @(negedge cpurs, posedge clock) if(!cpurs) reg7F <= 1'd0; else if(pe04M) if(!wr7F) reg7F <= q;

//-------------------------------------------------------------------------------------------------

reg[5:1] reg80;
wire wr80 = !(!iorq && !wr && a[7] && !a[6] && !a[2] && !a[1]);
always @(negedge cpurs, posedge  clock) if(!cpurs) reg80 <= 1'd0; else if(pe04M) if(!wr80) reg80 <= q[5:1];

//-------------------------------------------------------------------------------------------------

reg[5:0] reg84;
wire wr84 = !(!iorq && !wr && a[7] && !a[6] &&  a[2] && !a[1]);
always @(posedge clock) if(pe04M) if(!wr84) reg84 <= q[5:0];

//-------------------------------------------------------------------------------------------------

reg[17:0] ic;
wire init = ic[17];
always @(posedge clock) if(pe06M) if(!ready) ic <= 1'd0; else if(!init) ic <= ic+1'd1;

//-------------------------------------------------------------------------------------------------

wire[ 7:0] vrbQ1;
wire[13:0] vrbA1 = init ? { vduB[0], vmmA } : ic[15:2];

wire[ 7:0] vrbQ2;
wire[13:0] vrbA2 = { a[14], a[12:0] };
wire       vrbWe2 = !mreq && !wr && reg7F[1] && reg80[5];

dprf #(.KB(16), .FN("rom00.rom01.hex")) Vrb
(
	.clock1 (clock  ),
//	.ce1    (pe06M  ),
	.we1    (1'b0   ),
	.d1     (8'hFF  ),
	.q1     (vrbQ1  ),
	.a1     (vrbA1  ),
	.clock2 (clock  ),
//	.ce2    (pe04M  ),
	.we2    (vrbWe2 ),
	.d2     (q      ),
	.q2     (vrbQ2  ),
	.a2     (vrbA2  )
);

//-------------------------------------------------------------------------------------------------

wire[12:0] vmmA = { crtcMa[10:5], crtcRa[1:0], crtcMa[4:0] };

wire[ 7:0] vggQ1;
wire[13:0] vggA1 = init ? { vduB[0], vmmA } : ic[15:2];

wire[ 7:0] vggQ2;
wire[13:0] vggA2 = { a[14], a[12:0] };
wire       vggWe2 = !mreq && !wr && reg7F[2] && reg80[5];

dprf #(.KB(16), .FN("rom10.rom10s.hex")) Vgg
(
	.clock1 (clock  ),
//	.ce1    (pe06M  ),
	.we1    (1'b0   ),
	.d1     (8'hFF  ),
	.q1     (vggQ1  ),
	.a1     (vggA1  ),
	.clock2 (clock  ),
//	.ce2    (pe04M  ),
	.we2    (vggWe2 ),
	.d2     (q      ),
	.q2     (vggQ2  ),
	.a2     (vggA2  )
);

//-------------------------------------------------------------------------------------------------

wire[15:0] iniA = { 1'b0, ic[16:2] };
wire[15:0] romA = ramX ? { a[15:14], (romS & a[14]) ^ a[13], a[12:0] } : { 2'b00, a[13:0] };
wire[15:0] usrA = ramX ? a : { 2'b00, a[14], a[12:0] };

`ifdef ZX1

wire ready = 1'b1;

assign ramWe = init ? !(!mreq && !wr && !reg7F[0]) : !ic[1] && !ic[0];
assign ramDQ = ramWe ? 8'hZZ : init ? q : ic[16] ? vggQ1 : vrbQ1;
assign ramA = { 4'd0, init ? (!rd && !reg7F[4] && a[15:13] <= 2 ? { 1'b0, romA } : { 1'b1, usrA }) : { 1'b0, iniA } };

wire[7:0] ramQ = ramDQ;

`elsif SIDI

wire sdrRd = !(!mreq && !rd);
wire sdrWr = init ? !(!mreq && !wr && !reg7F[0]) : !ic[1] && !ic[0];
wire sdrRf = init ? rfsh : ic[1] && !ic[0];

wire[15:0] sdrD =  {2{ init ? q : ic[16] ? vggQ1 : vrbQ1}};
wire[15:0] sdrQ;
wire[23:0] sdrA  = { 7'd0, init ? (!rd && !reg7F[4] && a[15:13] <= 2 ? { 1'b0, romA } : { 1'b1, usrA }) : { 1'b0, iniA } };

wire[7:0] ramQ = ramDQ[7:0];

sdram SDram
(
	.clock  (clockSdram  ),
	.reset  (power  ),
	.ready  (ready  ),
	.refresh(rfsh   ),
	.write  (sdrWr  ),
	.read   (sdrRd  ),
	.portD  (sdrD   ),
	.portQ  (sdrQ   ),
	.portA  (sdrA   ),
	.ramCs  (ramCs  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramWe  (ramWe  ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBa  (ramBa  ),
	.ramA   (ramA   )
);

`endif
//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!iorq && !wr && a[7] && !a[6] && a[2] && a[1]);
wire crtcRs = a[0];
wire crtcRw = wr;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (peM75  ),
	.nRESET (cpurs  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (q      ),
	.DO     (       ),
	.HSYNC  (hSync  ),
	.VSYNC  (vSync  ),
	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

//-------------------------------------------------------------------------------------------------

wire altg = reg80[4];

wire[7:0] vduDi = vduB[1] ? (!casM || !reg80[3] ? vggQ1 : 8'h00) : (!casM || !reg80[2] ? vrbQ1 : 8'h00);
wire[1:0] vduB;

video Video
(
	.clock  (clock  ),
	.hSync  (hSync  ),
	.ce     (pe06M  ),
	.de     (crtcDe ),
	.altg   (altg   ),
	.d      (vduDi  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.bank   (vduB   )
);

//-------------------------------------------------------------------------------------------------

assign audio = reg84;
audio Audio
(
	.clock  (clock  ),
	.reset  (cpurs  ),
	.tape   (tape   ),
	.dac    (reg84  ),
	.q      (sound  )
);

//-------------------------------------------------------------------------------------------------

wire[3:0] keybRow = a[11:8];
wire[7:0] keybCol;

keyboard Keyboard
(
	.clock  (clock  ),
	.ce     (pe06M  ),
	.pressed(keyPrss),
	.strobe (keyStrb),
	.code   (keyCode),
	.row    (keybRow),
	.q      (keybCol)
);

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq && !reg7F[4] && a[15:14] == 2'b00 ? ramQ
	: !mreq && !reg7F[4] && a[15:13] == 3'b010 ? ramQ
	: !mreq && !reg7F[5] ? ramQ
	: !mreq &&  reg7F[6] && !reg80[3] ? vggQ2
	: !mreq &&  reg7F[6] && !reg80[2] ? vrbQ2
	: !iorq && a[7:0] == 8'h80 ? { keybCol[7:1], reg80[1] ? tape : keybCol[0] }
	: !iorq && a[6:0] == 8'h7A ? { 2'b00, joy }
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
