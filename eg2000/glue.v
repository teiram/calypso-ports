//-------------------------------------------------------------------------------------------------
module glue
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       power,
	output wire       boot,

	output wire       hsync,
	output wire       vsync,
	output wire       pixel,
	output wire[ 3:0] color,

	input  wire       tape,
	output wire       sound,
    output wire [9:0] pcm,
    
	input  wire[ 1:0] ps2,
`ifdef ZX1
	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
`elsif SIDI
	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBA,
	output wire[12:0] ramA
`endif
);
//-------------------------------------------------------------------------------------------------

reg[4:0] ce;
always @(negedge clock) ce <= ce+1'd1;

wire pe8M8 = ~ce[0] &  ce[1];
wire ne8M8 = ~ce[0] & ~ce[1];

wire ne4M4 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe2M2 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] &  ce[4];

//-------------------------------------------------------------------------------------------------

wire ioF8 = !(!iorq && a[7:0] == 8'hF8); // psg addr
wire ioF9 = !(!iorq && a[7:0] == 8'hF9); // psg data

wire ioFA = !(!iorq && a[7:0] == 8'hFA); // crtc addr
wire ioFB = !(!iorq && a[7:0] == 8'hFB); // crtc data

wire ioFF = !(!iorq && a[7:0] == 8'hFF);

//-------------------------------------------------------------------------------------------------

wire reset = power & kreset;
wire rfsh;
wire mreq;
wire iorq;
wire rd;
wire wr;
wire nmi;
wire crtcDe;
wire cursor;
wire kreset;
wire ven;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (pe2M2  ),
	.cen    (ne2M2  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.nmi    (nmi    ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!ioFA || !ioFB);
wire crtcRs = a[0];
wire crtcRw = wr;

wire[ 7:0] crtcQ;

wire[13:0] crtcMa;
wire[ 4:0] crtcRa;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (pe1M1  ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (q      ),
	.DO     (crtcQ  ),
	.VSYNC  (vsync  ),
	.HSYNC  (hsync  ),
	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

reg[1:0] cur;
always @(posedge clock) if(pe1M1) cur <= { cur[0], cursor };

//-------------------------------------------------------------------------------------------------

wire bdir = (!wr && !ioF8) || (!wr && !ioF9);
wire bc1  = (!wr && !ioF8) || (!rd && !ioF9);

wire[7:0] psgA;
wire[7:0] psgB;
wire[7:0] psgC;
wire[7:0] psgQ;

jt49_bus Psg
(
	.clk    (clock  ),
	.clk_en (pe2M2  ),
	.rst_n  (reset  ),
	.bdir   (bdir   ),
	.bc1    (bc1    ),
	.din    (q      ),
	.dout   (psgQ   ),
	.A      (psgA   ),
	.B      (psgB   ),
	.C      (psgC   ),
	.sel    (1'b0   )
);

//-------------------------------------------------------------------------------------------------

wire[9:0] dacD = { 2'b00, psgA } + { 2'b00, psgB } + { 2'b00, psgC };
assign pcm = dacD;

dac #(.MSBI(9)) Dac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (dacD   ),
	.q      (sound  )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] keyQ;
wire[7:0] keyA = a[7:0];

`ifdef ZX1
keyboard Keyboard
`elsif SIDI
keyboard #(.BOOT(8'h0A), .RESET(8'h78)) Keyboard
`endif
(
	.clock  (clock  ),
	.ce     (pe8M8  ),
	.ps2    (ps2    ),
	.nmi    (nmi    ),
	.boot   (boot   ),
	.reset  (kreset ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

reg mode, c, b;
always @(posedge clock) if(pe2M2) if(!ioFF && !wr) { mode, c, b } <= q[5:3];

//-------------------------------------------------------------------------------------------------

wire[13:0] vma = crtcMa;
wire[ 2:0] vra = crtcRa[2:0];

wire[ 7:0] memQ;

memory Memory
(
	.clock  (clock  ),
	.hsync  (hsync  ),
	.vcep   (pe8M8  ),
	.vcen   (ne8M8  ),
	.hrce   (ne4M4  ),
	.vma    (vma    ),
	.vra    (vra    ),
	.b      (b      ),
	.c      (c      ),
	.mode   (mode   ),
	.ven    (ven    ),
	.color  (color  ),
	.ce     (pe2M2  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.keyQ   (keyQ   ),
`ifdef ZX1
	.ramWe  (ramWe  ),
	.ramDQ  (ramDQ  ),
	.ramA   (ramA   )
`elsif SIDI
	.ramCk  (ramCk  ),
	.ramCe  (ramCe  ),
	.ramCs  (ramCs  ),
	.ramWe  (ramWe  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBA  (ramBA  ),
	.ramA   (ramA   )
`endif
);

assign pixel = (ven || cur[1]) && crtcDe;

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq ? memQ
	: !ioF9 ? psgQ
	: !ioFB ? crtcQ
	: !ioFF ? { 7'd0, tape }
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
