//============================================================================
//  Triple-channel CL2 SDRAM controller for the SNES core on Calypso
//
//  After sdram_cl2_3ch.v of SNESTang (nand2mario, Tang Primer 25K / Nano 20K),
//  where the whole SNES (ROM, WRAM, BSRAM, ARAM, VRAM) lives in one SDRAM.
//  Adapted to the Calypso SDRAM (W9864G6, 8MB: 4 banks x 4096 rows x 256
//  columns x 16 bit) and to an 8MB memory map without PSRAM:
//
//    channel 0  banks 0,1  ROM 0-3.75MB, BSRAM (128KB) at 0x3C0000, WRAM at
//                          0x3E0000 (as SNESTang: the CPU uses ROM and WRAM
//                          one at a time, DMA aside)
//    channel 1  bank 2     ARAM 0x000000, last 256KB of a 4MB ROM 0x1C0000
//    channel 2  bank 3     VRAM
//  The ARAM has a channel of its own: the DSP takes the data ~18 cycles
//  after the address, it cannot wait behind other accesses.
//
//  The SDRAM clock is 4x clk_sys (~86 MHz) and an 8 cycle frame is 2 clk_sys
//  cycles. Each channel opens its own bank once per frame at most (93 ns
//  between ACTIVEs of a bank: tRC is 60 ns), CAS latency 2:
//
//     cyc  ch0 (ROM)   ch1 (bank 2)        ch2 (VRAM)
//                      normal   delayed
//      0   RAS                             (data of the previous frame)
//      1               RAS
//      2   CAS                             data -> port
//      3               CAS      RAS
//      4                                   RAS
//      5   data->port
//      6               data     CAS
//      7                                   CAS
//      (only writes are delayed, so the delayed column has no read data)
//
//  "Delayed write" (from SNESTang): when channel 0 reads and channel 1
//  writes, the channel 1 write goes 3 cycles later, so its data is not on DQ
//  while the SDRAM still drives the channel 0 read data.
//
//  Handshake: toggle req with the inputs ready; ack becomes equal to req when
//  the access is done (read data valid). VRAM: ack at RAS, data 8 cycles later
//  (as sdram_cl3.sv of the MiST core).
//
//  Shaeon (Carlos Palmero), 2026, after nand2mario's SNESTang controller.
//  GPL v3 or later.
//============================================================================

module sdram_calypso #(
    parameter [11:0] RFRSH_CYCLES = 12'd1300     // 4096 rows / 64 ms at 86 MHz (15.1 us)
)(
    inout      [15:0] SDRAM_DQ,
    output reg [11:0] SDRAM_A,
    output reg        SDRAM_DQML,
    output reg        SDRAM_DQMH,
    output reg  [1:0] SDRAM_BA,
    output            SDRAM_nCS,
    output            SDRAM_nWE,
    output            SDRAM_nRAS,
    output            SDRAM_nCAS,
    output reg        SDRAM_CKE = 1'b0,

    input             init_n,
    input             clk,             // 4 x clk_sys
    input             clkref,          // dot clock enable (aligns the frame)
    output            ready,

    // channel 0: ROM (16 bit)
    input             rom_req,
    output reg        rom_ack = 1'b0,
    input      [21:1] rom_addr,
    input      [15:0] rom_din,
    input             rom_we,
    output reg [15:0] rom_dout,

    // channel 1: ARAM (16 bit read, byte or word write)
    input             aram_req,
    output reg        aram_ack = 1'b0,
    input      [15:0] aram_addr,
    input      [15:0] aram_din,
    input             aram_we,
    input             aram_16,
    output reg [15:0] aram_dout,

    // channel 1: WRAM writes and reads (separate, so a write is never lost
    // behind a read; writes go first)
    input             wramw_req,
    output reg        wramw_ack = 1'b0,
    input      [16:0] wramw_addr,
    input       [7:0] wramw_din,
    input             wramr_req,
    output reg        wramr_ack = 1'b0,
    input      [16:0] wramr_addr,
    output reg [15:0] wramr_dout,

    // channel 1: BSRAM (byte), also used by the save RAM engine
    input             bs_req,
    output reg        bs_ack = 1'b0,
    input      [18:0] bs_addr,
    input       [7:0] bs_din,
    input             bs_we,
    output reg  [7:0] bs_dout,

    // channel 2: VRAM
    input             vram1_req,
    output reg        vram1_ack = 1'b0,
    input      [14:0] vram1_addr,
    input       [7:0] vram1_din,
    output reg  [7:0] vram1_dout,
    input             vram1_we,

    input             vram2_req,
    output reg        vram2_ack = 1'b0,
    input      [14:0] vram2_addr,
    input       [7:0] vram2_din,
    output reg  [7:0] vram2_dout,
    input             vram2_we
);

localparam MODE = { 2'b00, 1'b1, 2'b00, 3'd2, 1'b0, 3'b000 };   // single write, CL2, BL1

localparam CMD_NOP          = 4'b0111;
localparam CMD_ACTIVE       = 4'b0011;
localparam CMD_READ         = 4'b0101;
localparam CMD_WRITE        = 4'b0100;
localparam CMD_PRECHARGE    = 4'b0010;
localparam CMD_AUTO_REFRESH = 4'b0001;
localparam CMD_LOAD_MODE    = 4'b0000;

reg  [3:0] cmd = CMD_NOP;
assign {SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = cmd;

// DQ: one output and one output enable register per pin (I/O cell packing)
(* preserve *) reg [15:0] dq_o;
(* preserve *) reg [15:0] dq_oe = 16'h0000;
genvar gi;
generate for (gi = 0; gi < 16; gi = gi + 1) begin : dqbuf
    assign SDRAM_DQ[gi] = dq_oe[gi] ? dq_o[gi] : 1'bZ;
end endgenerate
wire [15:0] dq_in = SDRAM_DQ;

// ---------------------------------------------------------------------
// initialization: ~250 us, precharge all, 9 refreshes, load mode
// ---------------------------------------------------------------------
reg [15:0] reset = 16'hffff;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
    if (!init_n) begin
        reset <= 16'd22000;
        init  <= 1'b1;
    end else begin
        if (reset != 0) reset <= reset - 1'd1;
        init <= reset != 0;
    end
end
assign ready = !init;

// ---------------------------------------------------------------------
// frame counter (one-hot in SNESTang, binary here), aligned to clkref
// ---------------------------------------------------------------------
reg  [2:0] cyc = 3'd0;
reg        clkref_d;

// channel latches
reg        c0_on, c0_we;
reg [20:0] c0_a;  reg [15:0] c0_din;  reg [1:0] c0_ds;  reg [2:0] c0_port;
reg        c1_on, c1_we, c1_del;
reg  [2:0] c1_port;  reg [20:0] c1_a;  reg [15:0] c1_din;  reg [1:0] c1_ds;
reg        c2_on, c2_we;
reg  [1:0] c2_port;  reg [7:0] c2_col;  reg [15:0] c2_din;  reg [1:0] c2_ds;
reg        c2_cap = 1'b0;                         // VRAM data due at cycle 2

localparam P1_ARAM = 3'd1, P1_ROMH = 3'd2;
localparam P0_ROM = 3'd1, P0_WW = 3'd2, P0_WR = 3'd3, P0_BS = 3'd4;
localparam P2_V16 = 2'd1, P2_V1 = 2'd2, P2_V2 = 2'd3;

wire r0 = rom_req ^ rom_ack;
wire ra = aram_req ^ aram_ack;
wire rw = wramw_req ^ wramw_ack;
wire rr = wramr_req ^ wramr_ack;
wire rb = bs_req ^ bs_ack;
wire v1 = vram1_req ^ vram1_ack;
wire v2 = vram2_req ^ vram2_ack;

wire romhi = &rom_addr[21:18];          // last 256KB of 4MB: channel 1

// channel 0: WRAM write, WRAM read, ROM, BSRAM
wire [2:0] c0_pick = rw ? P0_WW : rr ? P0_WR : (r0 && !romhi) ? P0_ROM : rb ? P0_BS : 3'd0;
wire       c0_pick_rd = (c0_pick == P0_WR) || (c0_pick == P0_ROM && !rom_we) || (c0_pick == P0_BS && !bs_we);
// channel 1: ARAM, then the top of a 4MB ROM
wire [2:0] c1_pick = ra ? P1_ARAM : (r0 && romhi) ? P1_ROMH : 3'd0;
wire       c1_pick_we = c1_pick == P1_ARAM ? aram_we : rom_we;

reg [11:0] refresh_cnt = 0;
reg        refresh = 1'b0;

always @(posedge clk) begin
    clkref_d <= clkref;
    cmd      <= CMD_NOP;
    SDRAM_A  <= 12'd0;
    SDRAM_BA <= 2'd0;
    { SDRAM_DQMH, SDRAM_DQML } <= 2'b11;

    // write data on DQ at the CAS of a write (plain registers)
    dq_oe <= {16{!init && ((cyc == 3'd2 && c0_on && c0_we) ||
                           (((cyc == 3'd3 && !c1_del) || (cyc == 3'd6 && c1_del)) && c1_on && c1_we) ||
                           (cyc == 3'd7 && c2_on && c2_we))}};
    dq_o  <= cyc == 3'd2 ? c0_din : cyc == 3'd7 ? c2_din : c1_din;

    if (~&refresh_cnt) refresh_cnt <= refresh_cnt + 1'd1;

    if (init) begin
        cyc     <= 3'd0;
        c0_on   <= 1'b0; c1_on <= 1'b0; c2_on <= 1'b0;
        c2_cap  <= 1'b0;
        refresh <= 1'b0;
        refresh_cnt <= 0;
        if (reset == 16'd1000) SDRAM_CKE <= 1'b1;
        if (reset == 16'd200) begin
            cmd <= CMD_PRECHARGE;
            SDRAM_A[10] <= 1'b1;
        end
        if (reset < 16'd190 && reset >= 16'd50 && reset[3:0] == 4'd0)
            cmd <= CMD_AUTO_REFRESH;
        if (reset == 16'd20) begin
            cmd     <= CMD_LOAD_MODE;
            SDRAM_A <= MODE;
        end
    end else begin
        cyc <= cyc + 1'd1;
        // align the frame to the dot clock, only when nothing is in flight
        if (~clkref_d && clkref && !c0_on && !c1_on && !c2_on && !c2_cap && !refresh)
            cyc <= 3'd3;

        // ---------------- cycle 0: ch0 RAS, ch1 choice ----------------
        if (cyc == 3'd0) begin
            refresh <= 1'b0;
            c0_on   <= c0_pick != 3'd0;
            c0_port <= c0_pick;
            case (c0_pick)
            P0_WW:  begin c0_a <= {5'b11111, wramw_addr[16:1]}; c0_we <= 1'b1;   c0_din <= {wramw_din, wramw_din};
                          c0_ds <= {wramw_addr[0], ~wramw_addr[0]}; end
            P0_WR:  begin c0_a <= {5'b11111, wramr_addr[16:1]}; c0_we <= 1'b0;   c0_ds <= 2'b11; end
            P0_ROM: begin c0_a <= rom_addr[21:1];               c0_we <= rom_we; c0_din <= rom_din; c0_ds <= 2'b11; end
            P0_BS:  begin c0_a <= {4'b1111, 1'b0, bs_addr[16:1]}; c0_we <= bs_we; c0_din <= {bs_din, bs_din};
                          c0_ds <= {bs_addr[0], ~bs_addr[0]}; end
            default: ;
            endcase
            if (c0_pick != 3'd0) begin
                cmd      <= CMD_ACTIVE;
                SDRAM_BA <= {1'b0, c0_pick == P0_ROM ? rom_addr[21] : 1'b1};
                SDRAM_A  <= c0_pick == P0_WW ? {4'b1111, wramw_addr[16:9]} :
                            c0_pick == P0_WR ? {4'b1111, wramr_addr[16:9]} :
                            c0_pick == P0_BS ? {4'b1110, bs_addr[16:9]} : rom_addr[20:9];
            end
            // channel 1: decided now, so the delayed write is known
            c1_on   <= c1_pick != 3'd0;
            c1_port <= c1_pick;
            c1_del  <= c0_pick_rd && c1_pick_we;
            case (c1_pick)
            P1_ARAM: begin c1_a <= {5'b00000, aram_addr[15:0]};  c1_we <= aram_we; c1_din <= aram_din;
                           c1_ds <= aram_16 ? 2'b11 : {aram_addr[0], ~aram_addr[0]}; end
            P1_ROMH: begin c1_a <= {3'b111, rom_addr[17:1], 1'b0}; c1_we <= rom_we; c1_din <= rom_din; c1_ds <= 2'b11; end
            default: ;
            endcase
        end

        // ---------------- ch1 RAS (cycle 1, or 3 when delayed) ----------------
        if (c1_on && ((cyc == 3'd1 && !c1_del) || (cyc == 3'd3 && c1_del))) begin
            cmd      <= CMD_ACTIVE;
            SDRAM_BA <= 2'b10;
            SDRAM_A  <= c1_a[20:9];
        end

        // ---------------- cycle 2: ch0 CAS, VRAM data, refresh ----------------
        if (cyc == 3'd2) begin
            if (c0_on) begin
                cmd      <= c0_we ? CMD_WRITE : CMD_READ;
                SDRAM_BA <= {1'b0, c0_a[20]};
                SDRAM_A  <= {4'b0100, c0_a[7:0]};   // A10: auto precharge
                if (c0_we) { SDRAM_DQMH, SDRAM_DQML } <= ~c0_ds;
            end
            if (c2_cap) begin
                c2_cap <= 1'b0;
                case (c2_port)
                P2_V16: { vram2_dout, vram1_dout } <= c2_we ? c2_din : dq_in;
                P2_V1:  vram1_dout <= c2_we ? c2_din[7:0]  : dq_in[7:0];
                P2_V2:  vram2_dout <= c2_we ? c2_din[15:8] : dq_in[15:8];
                default: ;
                endcase
            end
            // refresh when ch0 and ch1 are idle in this frame and no VRAM
            // request is waiting (the VRAM RAS of this frame is then skipped)
            if (refresh_cnt >= RFRSH_CYCLES && !c0_on && !c1_on && !v1 && !v2) begin
                cmd         <= CMD_AUTO_REFRESH;
                refresh     <= 1'b1;
                refresh_cnt <= refresh_cnt - RFRSH_CYCLES;
            end
        end

        // ---------------- ch1 CAS (cycle 3, or 6 when delayed) ----------------
        if (c1_on && ((cyc == 3'd3 && !c1_del) || (cyc == 3'd6 && c1_del))) begin
            cmd      <= c1_we ? CMD_WRITE : CMD_READ;
            SDRAM_BA <= 2'b10;
            SDRAM_A  <= {4'b0100, c1_a[8:1]};
            if (c1_we) { SDRAM_DQMH, SDRAM_DQML } <= ~c1_ds;
        end

        // read DQM (CL2: one cycle before the data is fine with DQM latency 2
        // when set at the CAS): low for reads at their CAS cycle
        if (cyc == 3'd2 && c0_on && !c0_we) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
        if (c1_on && !c1_we && ((cyc == 3'd3 && !c1_del) || (cyc == 3'd6 && c1_del))) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;
        if (cyc == 3'd7 && c2_on && !c2_we) { SDRAM_DQMH, SDRAM_DQML } <= 2'b00;

        // ---------------- cycle 4: ch2 RAS (VRAM) ----------------
        if (cyc == 3'd4) begin
            c2_on <= 1'b0;
            if ((v1 || v2) && !refresh) begin
                c2_on    <= 1'b1;
                cmd      <= CMD_ACTIVE;
                SDRAM_BA <= 2'b11;
                if (v1 && v2 && vram1_addr == vram2_addr && vram1_we == vram2_we) begin
                    SDRAM_A <= vram1_addr[14:8]; c2_col <= vram1_addr[7:0]; c2_we <= vram1_we;
                    c2_din  <= {vram2_din, vram1_din}; c2_ds <= 2'b11; c2_port <= P2_V16;
                    vram1_ack <= vram1_req; vram2_ack <= vram2_req;
                end else if (v1) begin
                    SDRAM_A <= vram1_addr[14:8]; c2_col <= vram1_addr[7:0]; c2_we <= vram1_we;
                    c2_din  <= {vram1_din, vram1_din}; c2_ds <= 2'b01; c2_port <= P2_V1;
                    vram1_ack <= vram1_req;
                end else begin
                    SDRAM_A <= vram2_addr[14:8]; c2_col <= vram2_addr[7:0]; c2_we <= vram2_we;
                    c2_din  <= {vram2_din, vram2_din}; c2_ds <= 2'b10; c2_port <= P2_V2;
                    vram2_ack <= vram2_req;
                end
            end
        end

        // ---------------- cycle 5: ch0 data ----------------
        if (cyc == 3'd5 && c0_on) begin
            case (c0_port)
            P0_ROM: begin if (!c0_we) rom_dout <= dq_in; rom_ack <= ~rom_ack; end
            P0_WW:  wramw_ack <= ~wramw_ack;
            P0_WR:  begin wramr_dout <= dq_in; wramr_ack <= ~wramr_ack; end
            P0_BS:  begin if (!c0_we) bs_dout <= c0_ds[1] ? dq_in[15:8] : dq_in[7:0]; bs_ack <= ~bs_ack; end
            default: ;
            endcase
            c0_on <= 1'b0;
        end

        // ---------------- ch1 done at cycle 6 ----------------
        // normal: read data at the pins now (CAS at 3); delayed: always a
        // write (only writes are delayed), done with its CAS now
        if (c1_on && cyc == 3'd6) begin
            case (c1_port)
            P1_ARAM: begin if (!c1_we) aram_dout <= dq_in; aram_ack <= ~aram_ack; end
            P1_ROMH: begin if (!c1_we) rom_dout <= dq_in; rom_ack <= ~rom_ack; end
            default: ;
            endcase
            c1_on <= 1'b0;
        end

        // ---------------- cycle 7: ch2 CAS ----------------
        if (cyc == 3'd7 && c2_on) begin
            cmd      <= c2_we ? CMD_WRITE : CMD_READ;
            SDRAM_BA <= 2'b11;
            SDRAM_A  <= {4'b0100, c2_col};
            if (c2_we) { SDRAM_DQMH, SDRAM_DQML } <= ~c2_ds;
            c2_on  <= 1'b0;
            c2_cap <= 1'b1;
        end
    end
end

endmodule
