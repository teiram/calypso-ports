// =============================================================================
// opll2midi_conv.v - Conversor OPLL (YM2413, MSX-MUSIC) -> mensajes MIDI
//
// Escucha las escrituras a 7Ch (registro) / 7Dh (dato) y mantiene una sombra de
// los registros del YM2413. No depende de la implementación del OPLL del core.
//
//  Canales OPLL 0-5 -> MIDI 4-9 (3-8);  canales 6-8 -> MIDI 11-13 (10-12).
//  Modo ritmo (R#0Eh bit 5): BD, SD, TOM, TCY, HH -> percusión GM en el canal 10.
//  Instrumento OPLL -> Program Change GM;  volumen (3 dB/paso) -> CC#11.
//  Key-on (R#20h-28h bit 4) relanza la nota aunque sea la misma.
//
// Autor: Shaeon (Carlos Palmero)
// =============================================================================
module opll2midi_conv #(
    parameter integer EXPR_CC = 11,      // controlador del volumen: 11 (expresión) o 7 (volumen)
    parameter integer PANIC   = 1        // 1 = CC#123 por canal tras 1 s de silencio; 2 = repetir el
                                         //     note off de la última nota a los 0,5 s y a 1 s
)(
    input  wire        clk,
    input  wire        rst_regs,
    input  wire        rst,
    input  wire [1:0]  stable_n,
    input  wire        tick_frame,
    input  wire        tick_bend,
    input  wire        opll_wr,
    input  wire        opll_a0,
    input  wire [7:0]  opll_d,
    output wire        any_on,       // hay alguna nota sonando en este conversor
    output wire [25:0] msg,
    output wire        msg_empty,
    input  wire        msg_pop
);
    localparam integer WIN1 = 256;
    localparam integer WIN2 = 512;

    // ---------------- sombra de registros ----------------
    reg  [7:0] r [0:63];
    reg  [7:0] adr;
    reg        wr_q;
    wire       wr_stb = opll_wr & ~wr_q;
    reg  [8:0] kon_pend, clr_kon;      // key-on visto desde el último frame
    reg  [4:0] rh_pend,  clr_rh;       // golpes de ritmo vistos desde el último frame
    integer    k;
    wire [3:0] wch = adr[3:0];

    always @(posedge clk) begin
        wr_q <= opll_wr;
        if (rst_regs) begin
            adr <= 0; kon_pend <= 0; rh_pend <= 0;
            for (k = 0; k < 64; k = k + 1) r[k] <= 8'h00;
        end else begin
            kon_pend <= kon_pend & ~clr_kon;
            rh_pend  <= rh_pend  & ~clr_rh;
            if (wr_stb) begin
                if (!opll_a0) adr <= opll_d;
                else if (adr[7:6] == 2'b00) begin
                    r[adr[5:0]] <= opll_d;
                    if (adr[5:4] == 2'b10 && wch <= 4'd8 && opll_d[4] && !r[adr[5:0]][4])
                        kon_pend[wch] <= 1'b1;
                    if (adr[5:0] == 6'h0E && opll_d[5])
                        rh_pend <= (rh_pend & ~clr_rh) | (opll_d[4:0] & ~(r[14][5] ? r[14][4:0] : 5'd0));
                end
            end
        end
    end

    // ---------------- ticks pendientes ----------------
    reg pend_frame, pend_bend, clr_frame, clr_bend;
    always @(posedge clk) begin
        if (rst) begin pend_frame <= 1'b0; pend_bend <= 1'b0; end
        else begin
            if (tick_frame) pend_frame <= 1'b1; else if (clr_frame) pend_frame <= 1'b0;
            if (tick_bend)  pend_bend  <= 1'b1; else if (clr_bend)  pend_bend  <= 1'b0;
        end
    end

    // ---------------- tablas ----------------
    // atenuación OPLL (0 = máximo, 3 dB por paso) -> CC#11
    function [6:0] vol_tab(input [3:0] v);
        case (v)
            4'd0:  vol_tab = 127; 4'd1:  vol_tab = 107; 4'd2:  vol_tab = 90;  4'd3:  vol_tab = 76;
            4'd4:  vol_tab = 64;  4'd5:  vol_tab = 54;  4'd6:  vol_tab = 45;  4'd7:  vol_tab = 38;
            4'd8:  vol_tab = 32;  4'd9:  vol_tab = 27;  4'd10: vol_tab = 23;  4'd11: vol_tab = 19;
            4'd12: vol_tab = 16;  4'd13: vol_tab = 13;  4'd14: vol_tab = 11;  default: vol_tab = 10;
        endcase
    endfunction

    // instrumento OPLL -> programa GM (0-based)
    function [6:0] gm_prog(input [3:0] i);
        case (i)
            4'd0:  gm_prog = 80;   // Original (usuario) -> Square Lead
            4'd1:  gm_prog = 40;   // Violin
            4'd2:  gm_prog = 24;   // Guitar -> Nylon Guitar
            4'd3:  gm_prog = 0;    // Piano
            4'd4:  gm_prog = 73;   // Flute
            4'd5:  gm_prog = 71;   // Clarinet
            4'd6:  gm_prog = 68;   // Oboe
            4'd7:  gm_prog = 56;   // Trumpet
            4'd8:  gm_prog = 16;   // Organ
            4'd9:  gm_prog = 60;   // Horn -> French Horn
            4'd10: gm_prog = 81;   // Synthesizer -> Saw Lead
            4'd11: gm_prog = 6;    // Harpsichord
            4'd12: gm_prog = 11;   // Vibraphone
            4'd13: gm_prog = 38;   // Synthesizer Bass
            4'd14: gm_prog = 32;   // Acoustic Bass
            default: gm_prog = 27; // Electric Guitar -> Clean Guitar
        endcase
    endfunction

    // ---------------- FIFO de salida ----------------
    reg         fpush;
    reg  [25:0] fdin;
    wire        ffull;
    msx2midi_fifo #(.W(26), .AW(4)) ofifo (
        .clk(clk), .rst(rst), .push(fpush), .din(fdin),
        .pop(msg_pop), .dout(msg), .empty(msg_empty), .full(ffull), .level());

    // ---------------- instrumento de usuario (R#00-R#07) ----------------
    wire [6:0] u_prog_c, u_vel_c, u_mod_c;
    wire       u_silent_c, u_vib_c;
    wire [3:0] u_group_c;
    reg  [6:0] u_prog, u_vel, u_mod;
    reg        u_silent, u_vib;
    opll_patch_class patch_class (
        .r0(r[0]), .r1(r[1]), .r2(r[2]), .r3(r[3]), .r4(r[4]), .r5(r[5]), .r6(r[6]), .r7(r[7]),
        .prog(u_prog_c), .group(u_group_c), .silent(u_silent_c), .vib(u_vib_c),
        .vel(u_vel_c), .modw(u_mod_c));
    always @(posedge clk) begin
        u_prog <= u_prog_c; u_silent <= u_silent_c; u_vib <= u_vib_c;
        u_vel  <= u_vel_c;  u_mod    <= u_mod_c;
    end

    // velocidad de los 15 instrumentos de fábrica (valores propios)
    function [6:0] preset_vel(input [3:0] i);
        case (i)
            4'd1: preset_vel = 90;   4'd2: preset_vel = 95;   4'd3: preset_vel = 110;  4'd4: preset_vel = 95;
            4'd5: preset_vel = 100;  4'd6: preset_vel = 95;   4'd7: preset_vel = 112;  4'd8: preset_vel = 90;
            4'd9: preset_vel = 100;  4'd10: preset_vel = 105; 4'd11: preset_vel = 115; 4'd12: preset_vel = 90;
            4'd13: preset_vel = 90;  4'd14: preset_vel = 90;  4'd15: preset_vel = 90;  default: preset_vel = 100;
        endcase
    endfunction

    // ---------------- canal actual y ROM ----------------
    reg  [3:0]  ch;                      // 0-8 melódicos, 0-4 en la fase de ritmo
    reg         is_frame;
    wire [7:0]  r1x = r[6'h10 + ch];
    wire [7:0]  r2x = r[6'h20 + ch];
    wire [7:0]  r3x = r[6'h30 + ch];
    wire [15:0] base;
    opll2midi_fnum_rom fnum_rom (.clk(clk), .addr({r2x[0], r1x}), .q(base));

    wire [3:0]  mch      = (ch < 4'd6) ? ch + 4'd3 : ch + 4'd4;
    wire        rhythm   = r[14][5];
    wire [15:0] boff     = {2'b00, r2x[3:1], 11'd0} + {3'b000, r2x[3:1], 10'd0};   // bloque * 3072
    wire signed [17:0] fine_r = $signed({{2{base[15]}}, base}) + $signed({2'b00, boff});
    // Notas por debajo del rango MIDI: el firmware las sube de octava en octava hasta que
    // caben. Aquí solo si les faltan 1 o 2 octavas; más abajo es un truco de silencio.
    wire signed [17:0] fine_s = (fine_r >= 0) ? fine_r :
                                (fine_r >= -18'sd3072) ? fine_r + 18'sd3072 :
                                (fine_r >= -18'sd6144) ? fine_r + 18'sd6144 : fine_r;
    wire        fvalid   = (base != 16'h8000) && (fine_s >= 0) && (fine_s <= 18'sd32512);
    wire [15:0] fine     = fine_s[15:0];
    wire [6:0]  near     = fvalid ? ((fine + 16'd128) >> 8) : 7'd0;

    // estado por canal
    reg  [8:0]  cur_on;
    reg  [6:0]  cur_note [0:8];
    reg  [13:0] cur_bend [0:8];
    reg  [6:0]  cur_expr [0:8];
    reg  [6:0]  cur_prog [0:8];
    reg  [6:0]  cand     [0:8];
    reg  [1:0]  ccnt     [0:8];
    reg  [4:0]  drum_on;
    reg  [6:0]  sil      [0:8];      // frames en silencio (watchdog)
    reg  [6:0]  cur_mod  [0:8];      // CC#1 enviado
    wire        user_i   = (r3x[7:4] == 4'd0);   // instrumento 0 = de usuario

    wire        kon      = kon_pend[ch];
    wire signed [17:0] dcur = $signed({2'b00, fine}) - $signed({3'b000, cur_note[ch], 8'h00});
    wire        in1      = (dcur <= WIN1) && (dcur >= -WIN1);
    wire        in2      = (dcur <= WIN2) && (dcur >= -WIN2);
    wire [1:0]  ccnt_nx  = (cand[ch] == near) ? ((ccnt[ch] == 2'd3) ? 2'd3 : ccnt[ch] + 2'd1) : 2'd1;
    wire        stable   = (ccnt_nx > stable_n);
    wire        in_win   = cur_on[ch] && !(is_frame && kon) &&
                           (in1 || (stable_n != 0 && in2 && (!is_frame || !stable)));
    wire [6:0]  refn     = in_win ? cur_note[ch] : near;
    wire signed [17:0] dref = $signed({2'b00, fine}) - $signed({3'b000, refn, 8'h00});
    wire signed [21:0] bcalc = 22'sd8192 + (dref <<< 4);
    wire [13:0] bend     = (bcalc < 0) ? 14'd0 : (bcalc > 22'sd16383) ? 14'd16383 : bcalc[13:0];

    // ritmo: bit 0 HH, 1 TCY, 2 TOM, 3 SD, 4 BD
    wire [2:0]  dr = ch[2:0];
    wire [6:0]  dnote = (dr == 0) ? 7'd42 : (dr == 1) ? 7'd49 : (dr == 2) ? 7'd45 : (dr == 3) ? 7'd38 : 7'd36;
    wire [3:0]  dvol  = (dr == 0) ? r[6'h37][7:4] : (dr == 1) ? r[6'h38][3:0] :
                        (dr == 2) ? r[6'h38][7:4] : (dr == 3) ? r[6'h37][3:0] : r[6'h36][3:0];
    wire [6:0]  dexpr = vol_tab(dvol);

    // ---------------- FSM ----------------
    localparam S_IDLE = 4'd0,  S_ADDR = 4'd1,  S_ROM  = 4'd2,  S_EVAL = 4'd3,
               S_OFF  = 4'd4,  S_PROG = 4'd5,  S_EXPR = 4'd6,  S_BEND = 4'd7,
               S_ON   = 4'd8,  S_NEXT = 4'd9,  S_REVAL = 4'd10, S_ROFF = 4'd11,
               S_RON  = 4'd12, S_RNEXT = 4'd13, S_PANIC = 4'd14, S_MOD = 4'd15;
    reg  [3:0]  st;
    reg         w_gate, w_within, w_dgate, w_dpend;
    reg  [6:0]  w_note, w_expr, w_vel, w_prog, w_mod;
    reg  [13:0] w_bend;

    reg         need;
    reg  [25:0] m;
    always @* begin
        need = 1'b0; m = 26'd0;
        case (st)
            S_OFF:  begin need = is_frame && cur_on[ch] && (!w_gate || !w_within);
                          m = {2'd3, 4'h8, mch, 1'b0, cur_note[ch], 8'd0}; end
            S_PROG: begin need = is_frame && w_gate && !cur_on[ch] && (w_prog != cur_prog[ch]);
                          m = {2'd2, 4'hC, mch, 1'b0, w_prog, 8'd0}; end
            S_EXPR: begin need = is_frame && w_gate && (w_expr != cur_expr[ch]);
                          m = {2'd3, 4'hB, mch, EXPR_CC[7:0], 1'b0, w_expr}; end
            S_MOD:  begin need = is_frame && w_gate && (w_mod != cur_mod[ch]);
                          m = {2'd3, 4'hB, mch, 8'd1, 1'b0, w_mod}; end
            S_BEND: begin need = w_gate && (is_frame || (cur_on[ch] && w_within)) && (w_bend != cur_bend[ch]);
                          m = {2'd3, 4'hE, mch, 1'b0, w_bend[6:0], 1'b0, w_bend[13:7]}; end
            S_ON:   begin need = is_frame && w_gate && !cur_on[ch];
                          m = {2'd3, 4'h9, mch, 1'b0, w_note, 1'b0, w_vel}; end
            S_PANIC: begin
                         if (PANIC == 2) begin
                             need = is_frame && !cur_on[ch] && (sil[ch] == 7'd25 || sil[ch] == 7'd50);
                             m    = {2'd3, 4'h8, mch, 1'b0, cur_note[ch], 8'd0};
                         end else begin
                             need = (PANIC != 0) && is_frame && !cur_on[ch] && (sil[ch] == 7'd50);
                             m    = {2'd3, 4'hB, mch, 8'd123, 8'd0};
                         end
                     end
            S_ROFF: begin need = drum_on[dr] && (!w_dgate || w_dpend);
                          m = {2'd3, 8'h89, 1'b0, dnote, 8'd0}; end
            S_RON:  begin need = (w_dgate || w_dpend) && !drum_on[dr];
                          m = {2'd3, 8'h99, 1'b0, dnote, 1'b0, w_vel}; end
            default: ;
        endcase
    end

    assign any_on = (|cur_on) | (|drum_on);

    integer j;
    always @(posedge clk) begin
        fpush <= 1'b0; clr_frame <= 1'b0; clr_bend <= 1'b0; clr_kon <= 0; clr_rh <= 0;
        if (rst) begin
            st <= S_IDLE; ch <= 0; cur_on <= 0; drum_on <= 0; is_frame <= 1'b0;
            for (j = 0; j < 9; j = j + 1) begin
                cur_note[j] <= 0; cur_bend[j] <= 14'd8192; cur_expr[j] <= 0;
                cur_prog[j] <= 7'h7F; cand[j] <= 0; ccnt[j] <= 0; sil[j] <= 7'd51; cur_mod[j] <= 0;
            end
        end else if (fpush) begin
        end else if (need && ffull) begin
        end else begin
            if (need) begin fpush <= 1'b1; fdin <= m; end
            case (st)
                S_IDLE: begin
                    ch <= 0;
                    if (pend_frame)     begin is_frame <= 1'b1; clr_frame <= 1'b1; clr_bend <= 1'b1; st <= S_ADDR; end
                    else if (pend_bend) begin is_frame <= 1'b0; clr_bend  <= 1'b1; st <= S_ADDR; end
                end
                S_ADDR: st <= S_ROM;
                S_ROM:  st <= S_EVAL;
                S_EVAL: begin
                    w_gate   <= (r2x[4] || (is_frame && kon)) && fvalid && !(rhythm && ch >= 4'd6) &&
                                !(user_i && u_silent);
                    w_within <= in_win;
                    w_note   <= refn;
                    w_bend   <= bend;
                    w_expr   <= vol_tab(r3x[3:0]);
                    w_vel    <= user_i ? u_vel : preset_vel(r3x[7:4]);
                    w_prog   <= user_i ? u_prog : gm_prog(r3x[7:4]);
                    w_mod    <= user_i ? u_mod : 7'd0;          // AM/PM del patch -> CC#1
                    if (is_frame) begin
                        if (!cur_on[ch] || in1) begin cand[ch] <= near; ccnt[ch] <= 2'd0; end
                        else begin cand[ch] <= near; ccnt[ch] <= ccnt_nx; end
                    end
                    st <= S_OFF;
                end
                S_OFF:  begin if (need) cur_on[ch] <= 1'b0;     st <= S_PROG; end
                S_PROG: begin if (need) cur_prog[ch] <= w_prog; st <= S_EXPR; end
                S_EXPR: begin if (need) cur_expr[ch] <= w_expr; st <= S_MOD;  end
                S_MOD:  begin if (need) cur_mod[ch]  <= w_mod;  st <= S_BEND; end
                S_BEND: begin if (need) cur_bend[ch] <= w_bend; st <= S_ON;   end
                S_ON:   begin if (need) begin cur_on[ch] <= 1'b1; cur_note[ch] <= w_note; ccnt[ch] <= 2'd0; end
                              st <= S_PANIC; end
                S_PANIC: begin
                    if (is_frame) begin
                        if (cur_on[ch])            sil[ch] <= 7'd0;
                        else if (sil[ch] != 7'd51) sil[ch] <= sil[ch] + 7'd1;
                    end
                    st <= S_NEXT;
                end
                S_NEXT: begin
                    if (is_frame) clr_kon[ch] <= 1'b1;
                    if (ch == 4'd8) begin
                        ch <= 0;
                        st <= is_frame ? S_REVAL : S_IDLE;
                    end else begin ch <= ch + 4'd1; st <= S_ADDR; end
                end
                // ---- ritmo (solo en frames) ----
                S_REVAL: begin
                    w_dgate <= rhythm && r[14][dr];
                    w_dpend <= rhythm && rh_pend[dr];
                    w_vel   <= 7'd63 + {1'b0, dexpr[6:1]};
                    st <= S_ROFF;
                end
                S_ROFF: begin if (need) drum_on[dr] <= 1'b0; st <= S_RON; end
                S_RON:  begin if (need) drum_on[dr] <= 1'b1; st <= S_RNEXT; end
                S_RNEXT: begin
                    clr_rh[dr] <= 1'b1;
                    if (ch == 4'd4) st <= S_IDLE;
                    else begin ch <= ch + 4'd1; st <= S_REVAL; end
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
