//============================================================================
//  SNES memory bus to PSRAM arbiter (Calypso SNES port)
//
//  Copyright (c) 2026 Shaeon (Carlos Palmero)
//
//  Serves, from a single byte-wide PSRAM:
//    - WRAM   (128 KB)   CPU / DMA / HDMA accesses, always 8 master clocks
//    - BSRAM  (512 KB)   cartridge save RAM, normally 8 master clocks
//    - ROMH   (4 MB)     cartridge ROM above 4 MB (ExHiROM 6 MB games)
//    - LD               loader port (cart download, save RAM copy engine)
//
//  PSRAM map (byte addresses):
//    0x000000-0x3FFFFF  ROM bytes 4MB..8MB
//    0x400000-0x41FFFF  WRAM
//    0x480000-0x4FFFFF  BSRAM
//
//  All CPU-side clients share the single 5A22 bus, so they never need the
//  PSRAM at the same time, except during DMA, where the A-bus and the B-bus
//  are used in the same cycle (e.g. ROM/SRAM -> $2180 or $2180 -> SRAM).
//  For that case reads have priority over writes, and a write can be issued
//  in the same cycle the previous read completes. Its data is taken when it
//  is issued and taken again one clk_sys cycle later if the write strobe is
//  still active: by then the read result has gone through the core and is
//  the value to write. The PSRAM controller samples the data only ~70 ns
//  after the request, so the second capture is the one written.
//
//  Worst case DMA cycle (8 master clocks = 375 ns) at 106.67 MHz (107 MHz in the final PLL):
//    read issued 23 ns, data at 211 ns, write issued 211 ns, done 352 ns.
//
//  Reads are cached: a read is only issued when the address changes or the
//  read strobe rises, so a CPU cycle that keeps the same address costs
//  nothing.
//
//  Runs on the falling edge of clk_sys like the MiST SDRAM request logic.
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//============================================================================

module snes_psram_bus #(
    // default map (WRAM/BSRAM/ROM above 4MB); ROM_IN_PSRAM build: ROM_W = 23,
    // BSRAM_BASE = 23'h780000, WRAM unused
    parameter        ROM_W      = 22,
    parameter [22:0] WRAM_BASE  = 23'h400000,
    parameter [22:0] BSRAM_BASE = 23'h480000
)(
    input             clk,          // clk_sys, logic on falling edge
    input             en,           // CPU side clients enabled

    // WRAM
    input      [16:0] wram_addr,
    input             wram_rd,
    input             wram_wr,
    input       [7:0] wram_d,
    output reg  [7:0] wram_q,

    // BSRAM
    input      [18:0] bsram_addr,
    input             bsram_rd,
    input             bsram_wr,
    input       [7:0] bsram_d,
    output reg  [7:0] bsram_q,

    // ROM (read only): above 4MB, or all of it in the ROM_IN_PSRAM build
    input [ROM_W-1:0] romh_addr,
    input             romh_rd,
    input             romh_flush,    // invalidate the ROMH read cache
    output reg  [7:0] romh_q,

    // loader
    input             ld_req,        // pulse
    input             ld_we,
    input      [22:0] ld_addr,
    input       [7:0] ld_din,
    output reg  [7:0] ld_q,
    output reg        ld_done,       // pulse, ld_q valid for reads
    output            ld_busy,

    // PSRAM controller
    output reg        p_req = 1'b0,
    output reg        p_we,
    output reg [22:0] p_addr,
    output reg  [7:0] p_din,
    input       [7:0] p_dout,
    input             p_ack,
    input             p_ready
);


localparam SRC_NONE  = 3'd0;
localparam SRC_LD    = 3'd1;
localparam SRC_ROMH  = 3'd2;
localparam SRC_BSR   = 3'd3;
localparam SRC_WRR   = 3'd4;
localparam SRC_BSW   = 3'd5;
localparam SRC_WRW   = 3'd6;

// ------------------------------------------------------------------
// request detection
// ------------------------------------------------------------------
reg        wram_rdD, wram_wrD, bsram_rdD, bsram_wrD, romh_rdD;
reg [16:0] wram_last;
reg [18:0] bsram_last;
reg [ROM_W-1:0] romh_last;
reg        romh_valid;

wire wram_rd_trig  = en & wram_rd  & (~wram_rdD  | wram_addr  != wram_last);
wire bsram_rd_trig = en & bsram_rd & (~bsram_rdD | bsram_addr != bsram_last);
wire romh_rd_trig  = en & romh_rd  & (~romh_valid | romh_addr != romh_last);
wire wram_wr_trig  = en & wram_wr  & ~wram_wrD;
wire bsram_wr_trig = en & bsram_wr & ~bsram_wrD;

// pending requests (not yet issued)
reg        wram_rd_p, bsram_rd_p, romh_rd_p, wram_wr_p, bsram_wr_p, ld_p;
reg [16:0] wram_rd_a, wram_wr_a;
reg [18:0] bsram_rd_a, bsram_wr_a;
reg [ROM_W-1:0] romh_a;
reg        ld_we_l;
reg [22:0] ld_a;
reg  [7:0] ld_d;

// "want" = pending or triggered in this very cycle (saves a clk_sys cycle)
wire        wram_rd_w  = wram_rd_p  | wram_rd_trig;
wire        bsram_rd_w = bsram_rd_p | bsram_rd_trig;
wire        romh_rd_w  = romh_rd_p  | romh_rd_trig;
wire        wram_wr_w  = wram_wr_p  | wram_wr_trig;
wire        bsram_wr_w = bsram_wr_p | bsram_wr_trig;
wire        ld_w       = ld_p | ld_req;

wire [16:0] wram_rd_aw  = wram_rd_trig  ? wram_addr  : wram_rd_a;
wire [18:0] bsram_rd_aw = bsram_rd_trig ? bsram_addr : bsram_rd_a;
wire [ROM_W-1:0] romh_aw     = romh_rd_trig  ? romh_addr  : romh_a;
wire [16:0] wram_wr_aw  = wram_wr_trig  ? wram_addr  : wram_wr_a;
wire [18:0] bsram_wr_aw = bsram_wr_trig ? bsram_addr : bsram_wr_a;
wire        ld_we_w     = ld_req ? ld_we   : ld_we_l;
wire [22:0] ld_aw       = ld_req ? ld_addr : ld_a;
wire  [7:0] ld_dw       = ld_req ? ld_din  : ld_d;

// a read must not overtake a pending write to the same location
wire wram_hazard  = wram_wr_w  & (wram_wr_aw  == wram_rd_aw);
wire bsram_hazard = bsram_wr_w & (bsram_wr_aw == bsram_rd_aw);

reg  [2:0] pick;
always @(*) begin
    if (ld_w)                             pick = SRC_LD;
    else if (romh_rd_w)                   pick = SRC_ROMH;
    else if (bsram_rd_w & ~bsram_hazard)  pick = SRC_BSR;
    else if (wram_rd_w  & ~wram_hazard)   pick = SRC_WRR;
    else if (bsram_wr_w)                  pick = SRC_BSW;
    else if (wram_wr_w)                   pick = SRC_WRW;
    else                                  pick = SRC_NONE;
end

// ------------------------------------------------------------------
// issue / complete
// ------------------------------------------------------------------
reg        busy = 1'b0;
reg  [2:0] src;
wire       done  = busy & (p_ack == p_req);      // completes in this cycle
wire       can_issue = p_ready & (~busy | done);
wire       issue = can_issue & (pick != SRC_NONE);
reg        wr_refresh = 1'b0;                    // second data capture pending

assign ld_busy = ld_p | (busy & src == SRC_LD);

always @(negedge clk) begin
    ld_done <= 1'b0;

    wram_rdD  <= wram_rd;
    wram_wrD  <= wram_wr;
    bsram_rdD <= bsram_rd;
    bsram_wrD <= bsram_wr;
    romh_rdD  <= romh_rd;

    if (wram_rd_trig)  wram_last  <= wram_addr;
    if (bsram_rd_trig) bsram_last <= bsram_addr;
    if (romh_rd_trig) begin
        romh_last  <= romh_addr;
        romh_valid <= 1'b1;
    end
    if (romh_flush) romh_valid <= 1'b0;

    // late write data capture (see above)
    wr_refresh <= 1'b0;
    if (wr_refresh) begin
        if (src == SRC_WRW && wram_wr  && wram_addr  == p_addr[16:0]) p_din <= wram_d;
        if (src == SRC_BSW && bsram_wr && bsram_addr == p_addr[18:0]) p_din <= bsram_d;
    end

    // completion
    if (done) begin
        busy <= 1'b0;
        case (src)
        SRC_LD:   begin ld_q <= p_dout; ld_done <= 1'b1; end
        SRC_ROMH: romh_q  <= p_dout;
        SRC_BSR:  bsram_q <= p_dout;
        SRC_WRR:  wram_q  <= p_dout;
        default: ;
        endcase
    end

    // latch triggers into pending registers (a newer trigger replaces an
    // older pending request of the same kind)
    if (wram_rd_trig)  begin wram_rd_p  <= 1'b1; wram_rd_a  <= wram_addr;  end
    if (bsram_rd_trig) begin bsram_rd_p <= 1'b1; bsram_rd_a <= bsram_addr; end
    if (romh_rd_trig)  begin romh_rd_p  <= 1'b1; romh_a     <= romh_addr;  end
    if (wram_wr_trig)  begin wram_wr_p  <= 1'b1; wram_wr_a  <= wram_addr;  end
    if (bsram_wr_trig) begin bsram_wr_p <= 1'b1; bsram_wr_a <= bsram_addr; end
    if (ld_req) begin
        ld_p    <= 1'b1;
        ld_we_l <= ld_we;
        ld_a    <= ld_addr;
        ld_d    <= ld_din;
    end

    // issue (overrides the pending flag set above for the picked client)
    if (issue) begin
        busy  <= 1'b1;
        src   <= pick;
        p_req <= ~p_req;
        wr_refresh <= (pick == SRC_BSW) | (pick == SRC_WRW);
        case (pick)
        SRC_LD: begin
            ld_p   <= 1'b0;
            p_we   <= ld_we_w;
            p_addr <= ld_aw;
            p_din  <= ld_dw;
        end
        SRC_ROMH: begin
            romh_rd_p <= 1'b0;
            p_we   <= 1'b0;
            p_addr <= 23'(romh_aw);
        end
        SRC_BSR: begin
            bsram_rd_p <= 1'b0;
            p_we   <= 1'b0;
            p_addr <= BSRAM_BASE | 23'(bsram_rd_aw);
        end
        SRC_WRR: begin
            wram_rd_p <= 1'b0;
            p_we   <= 1'b0;
            p_addr <= WRAM_BASE | 23'(wram_rd_aw);
        end
        SRC_BSW: begin
            bsram_wr_p <= 1'b0;
            p_we   <= 1'b1;
            p_addr <= BSRAM_BASE | 23'(bsram_wr_aw);
            p_din  <= bsram_d;     // first capture, see wr_refresh
        end
        SRC_WRW: begin
            wram_wr_p <= 1'b0;
            p_we   <= 1'b1;
            p_addr <= WRAM_BASE | 23'(wram_wr_aw);
            p_din  <= wram_d;      // first capture, see wr_refresh
        end
        default: ;
        endcase
    end

    if (!en) begin
        wram_rd_p  <= 1'b0;
        bsram_rd_p <= 1'b0;
        romh_rd_p  <= 1'b0;
        wram_wr_p  <= 1'b0;
        bsram_wr_p <= 1'b0;
    end
end

initial begin
    wram_rd_p = 0; bsram_rd_p = 0; romh_rd_p = 0;
    wram_wr_p = 0; bsram_wr_p = 0; ld_p = 0;
    romh_valid = 0;
end

endmodule
