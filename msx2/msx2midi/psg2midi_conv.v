// =============================================================================
// psg2midi_conv.v - Conversor PSG (AY-3-8910 / YM2149) -> mensajes MIDI
//
// Canales MIDI 1-3 (0-2): tonos A, B, C.  Canal 10 (9): ruido -> percusión GM.
// Saca mensajes {len[1:0], b0, b1, b2} por una FIFO; msx2midi los serializa.
//
// Estabilidad de nota (stable_n, como el MIDI-PAC): un cambio de tono entre 1 y 2
// semitonos se toca como pitch bend sobre la nota actual hasta que el tono nuevo se
// mantiene stable_n + 1 frames; los saltos de más de 2 semitonos relanzan siempre.
//
// Autor: Shaeon (Carlos Palmero)
// =============================================================================
module psg2midi_conv #(
    parameter integer CLK_HZ = 21477270,
    parameter integer PSG_HZ = 1789773,
    parameter integer EXPR_CC = 11,      // controlador del volumen: 11 (expresión) o 7 (volumen)
    parameter integer PANIC   = 1        // 1 = CC#123 por canal tras 1 s de silencio; 2 = repetir el
                                         //     note off de la última nota a los 0,5 s y a 1 s
)(
    input  wire        clk,
    input  wire        rst_regs,     // reset del MSX: borra la sombra de registros
    input  wire        rst,          // reset del conversor (estado MIDI)
    input  wire [1:0]  stable_n,     // 0 = off, 1..3 = 2..4 frames
    input  wire [1:0]  thr,          // umbral de silencio: volumen <= thr -> nota apagada
    input  wire        tick_frame,
    input  wire        tick_bend,
    input  wire        psg_wr,
    input  wire        psg_a0,
    input  wire [7:0]  psg_d,
    output wire        any_on,       // hay alguna nota sonando en este conversor
    output wire [25:0] msg,
    output wire        msg_empty,
    input  wire        msg_pop
);
    localparam integer WIN1 = 256;   // 1 semitono
    localparam integer WIN2 = 512;   // 2 semitonos (rango del bend)

    // ---------------- sombra de registros ----------------
    reg  [7:0] r [0:15];
    reg  [3:0] ptr;
    reg        wr_q, env_restart;
    wire       wr_stb = psg_wr & ~wr_q;
    integer    k;
    always @(posedge clk) begin
        wr_q        <= psg_wr;
        env_restart <= 1'b0;
        if (rst_regs) begin
            ptr <= 0;
            for (k = 0; k < 16; k = k + 1) r[k] <= 8'h00;
            r[7] <= 8'hFF;
        end else if (wr_stb) begin
            if (!psg_a0) ptr <= psg_d[3:0];
            else begin
                r[ptr] <= psg_d;
                if (ptr == 4'd13) env_restart <= 1'b1;
            end
        end
    end

    // ---------------- reloj del PSG ----------------
    reg [31:0] pacc;
    reg        psg_ce;
    wire [32:0] pnext = {1'b0, pacc} + PSG_HZ;
    always @(posedge clk) begin
        if (rst_regs) begin pacc <= 0; psg_ce <= 1'b0; end
        else if (pnext >= CLK_HZ) begin pacc <= pnext - CLK_HZ; psg_ce <= 1'b1; end
        else begin pacc <= pnext[31:0]; psg_ce <= 1'b0; end
    end

    // ---------------- envolvente YM2149 (32 pasos) ----------------
    wire [15:0] ep    = {r[12], r[11]};
    wire [3:0]  shape = r[13][3:0];
    reg  [2:0]  epre;
    reg  [15:0] ecnt;
    reg  [4:0]  estep, ehlvl;
    reg         eatt, ehold;
    wire [4:0]  env_lvl = ehold ? ehlvl : (eatt ? estep : ~estep);
    always @(posedge clk) begin
        if (rst_regs || env_restart) begin
            epre <= 0; ecnt <= 0; estep <= 0; ehold <= 1'b0; ehlvl <= 0;
            eatt <= rst_regs ? 1'b0 : shape[2];
        end else if (psg_ce) begin
            epre <= epre + 3'd1;
            if (epre == 3'd7) begin
                if (ecnt + 16'd1 >= ep) begin
                    ecnt <= 0;
                    if (!ehold) begin
                        if (estep == 5'd31) begin
                            if (!shape[3]) begin ehold <= 1'b1; ehlvl <= 5'd0; end
                            else if (shape[0]) begin
                                ehold <= 1'b1; ehlvl <= (eatt ^ shape[1]) ? 5'd31 : 5'd0;
                            end else begin
                                estep <= 5'd0;
                                if (shape[1]) eatt <= ~eatt;
                            end
                        end else estep <= estep + 5'd1;
                    end
                end else ecnt <= ecnt + 16'd1;
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
    // Nivel 0..31 -> CC#11. Curva logarítmica real del YM2149 (1,5 dB por paso de 5 bits,
    // 3 dB por paso del volumen fijo de 4 bits). CC#11 en GM ~ 40*log10(cc/127) dB.
    function [6:0] vol_tab(input [4:0] l);
        case (l)
            5'd0: vol_tab = 0;     5'd1: vol_tab = 10;    5'd2: vol_tab = 10;    5'd3: vol_tab = 11;
            5'd4: vol_tab = 12;    5'd5: vol_tab = 13;    5'd6: vol_tab = 15;    5'd7: vol_tab = 16;
            5'd8: vol_tab = 17;    5'd9: vol_tab = 19;    5'd10: vol_tab = 21;   5'd11: vol_tab = 23;
            5'd12: vol_tab = 25;   5'd13: vol_tab = 27;   5'd14: vol_tab = 29;   5'd15: vol_tab = 32;
            5'd16: vol_tab = 35;   5'd17: vol_tab = 38;   5'd18: vol_tab = 41;   5'd19: vol_tab = 45;
            5'd20: vol_tab = 49;   5'd21: vol_tab = 54;   5'd22: vol_tab = 58;   5'd23: vol_tab = 64;
            5'd24: vol_tab = 69;   5'd25: vol_tab = 76;   5'd26: vol_tab = 82;   5'd27: vol_tab = 90;
            5'd28: vol_tab = 98;   5'd29: vol_tab = 107;  5'd30: vol_tab = 116;  default: vol_tab = 127;
        endcase
    endfunction

    function [6:0] drum_tab(input [4:0] np, input [1:0] v);
        reg [2:0] band;
        begin
            band = (np <= 2)  ? 3'd0 : (np <= 6)  ? 3'd1 : (np <= 11) ? 3'd2 :
                   (np <= 17) ? 3'd3 : (np <= 24) ? 3'd4 : 3'd5;
            case ({band, v})
                {3'd0,2'd0}: drum_tab = 42; {3'd0,2'd1}: drum_tab = 37; {3'd0,2'd2}: drum_tab = 44;
                {3'd1,2'd0}: drum_tab = 46; {3'd1,2'd1}: drum_tab = 51; {3'd1,2'd2}: drum_tab = 59;
                {3'd2,2'd0}: drum_tab = 38; {3'd2,2'd1}: drum_tab = 39; {3'd2,2'd2}: drum_tab = 40;
                {3'd3,2'd0}: drum_tab = 45; {3'd3,2'd1}: drum_tab = 47; {3'd3,2'd2}: drum_tab = 48;
                {3'd4,2'd0}: drum_tab = 36; {3'd4,2'd1}: drum_tab = 41; {3'd4,2'd2}: drum_tab = 43;
                default:                    drum_tab = (v == 2'd0) ? 7'd35 : (v == 2'd1) ? 7'd36 : 7'd41;
            endcase
        end
    endfunction

    // ---------------- FIFO de salida ----------------
    reg         fpush;
    reg  [25:0] fdin;
    wire        ffull;
    msx2midi_fifo #(.W(26), .AW(4)) ofifo (
        .clk(clk), .rst(rst), .push(fpush), .din(fdin),
        .pop(msg_pop), .dout(msg), .empty(msg_empty), .full(ffull), .level());

    // ---------------- ROM de afinación ----------------
    reg  [1:0]  ch;
    wire [11:0] rom_addr = (ch == 2'd0) ? {r[1][3:0], r[0]} :
                           (ch == 2'd1) ? {r[3][3:0], r[2]} : {r[5][3:0], r[4]};
    wire [15:0] fine;
    psg2midi_pitch_rom pitch_rom (.clk(clk), .addr(rom_addr), .q(fine));

    // ---------------- estado por canal ----------------
    reg         is_frame;
    reg  [2:0]  cur_on, drum_on;
    reg  [6:0]  cur_note [0:2];
    reg  [13:0] cur_bend [0:2];
    reg  [6:0]  cur_expr [0:2];
    reg  [6:0]  cur_drum [0:2];
    reg  [6:0]  cand     [0:2];      // nota candidata (estabilidad)
    reg  [1:0]  ccnt     [0:2];      // frames que lleva estable la candidata (sat. 3)
    reg  [6:0]  sil      [0:2];      // frames en silencio (watchdog de notas colgadas)

    // ---------------- evaluación del canal actual ----------------
    wire        tone_en  = ~r[7][ch];
    wire        noise_en = ~r[7][ch + 3'd3];
    wire [7:0]  vreg     = r[8 + ch];
    wire        envm     = vreg[4];
    wire [4:0]  lvl      = envm ? env_lvl : (vreg[3:0] == 0 ? 5'd0 : {vreg[3:0], 1'b1});
    wire        fvalid   = (fine != 16'hFFFF);
    wire [6:0]  near     = fvalid ? ((fine + 16'd128) >> 8) : 7'd0;
    wire signed [17:0] dcur = $signed({2'b00, fine}) - $signed({3'b000, cur_note[ch], 8'h00});
    wire        in1      = (dcur <= WIN1) && (dcur >= -WIN1);
    wire        in2      = (dcur <= WIN2) && (dcur >= -WIN2);
    // la candidata cuenta un frame más si coincide; estable cuando supera stable_n
    wire [1:0]  ccnt_nx  = (cand[ch] == near) ? ((ccnt[ch] == 2'd3) ? 2'd3 : ccnt[ch] + 2'd1) : 2'd1;
    wire        stable   = (ccnt_nx > stable_n);
    wire        in_win   = cur_on[ch] && (in1 || (stable_n != 0 && in2 && (!is_frame || !stable)));
    wire [6:0]  refn     = in_win ? cur_note[ch] : near;
    wire signed [17:0] dref = $signed({2'b00, fine}) - $signed({3'b000, refn, 8'h00});
    wire signed [21:0] bcalc = 22'sd8192 + (dref <<< 4);
    wire [13:0] bend     = (bcalc < 0) ? 14'd0 : (bcalc > 22'sd16383) ? 14'd16383 : bcalc[13:0];
    wire [6:0]  expr     = vol_tab(lvl);
    // umbral: fijo 0 -> solo volumen 0; 1..3 -> volumen fijo <= thr (nivel 5 bits <= 2*thr+1)
    wire [4:0]  lim      = (thr == 2'd0) ? 5'd0 : {2'b00, thr, 1'b1};
    // envolvente repetitiva (CONT=1, HOLD=0): la nota se mantiene y suena por CC#11
    wire        env_rep  = envm && shape[3] && !shape[0];

    // ---------------- FSM ----------------
    localparam S_IDLE = 4'd0, S_ADDR = 4'd1, S_ROM = 4'd2, S_EVAL = 4'd3, S_OFF = 4'd4,
               S_EXPR = 4'd5, S_BEND = 4'd6, S_ON = 4'd7, S_DOFF = 4'd8, S_DON = 4'd9,
               S_NEXT = 4'd10, S_PANIC = 4'd11;
    reg  [3:0]  st;
    reg         w_gate, w_within, w_dgate;
    reg  [6:0]  w_note, w_expr, w_vel, w_drum;
    reg  [13:0] w_bend;

    reg         need;
    reg  [25:0] m;
    always @* begin
        need = 1'b0; m = 26'd0;
        case (st)
            S_OFF:  begin need = is_frame && cur_on[ch] && (!w_gate || !w_within);
                          m = {2'd3, 6'b100000, ch, 1'b0, cur_note[ch], 8'd0}; end
            S_EXPR: begin need = is_frame && w_gate && (w_expr != cur_expr[ch]);
                          m = {2'd3, 6'b101100, ch, EXPR_CC[7:0], 1'b0, w_expr}; end
            S_BEND: begin need = w_gate && (is_frame || (cur_on[ch] && w_within)) && (w_bend != cur_bend[ch]);
                          m = {2'd3, 6'b111000, ch, 1'b0, w_bend[6:0], 1'b0, w_bend[13:7]}; end
            S_ON:   begin need = is_frame && w_gate && !cur_on[ch];
                          m = {2'd3, 6'b100100, ch, 1'b0, w_note, 1'b0, w_vel}; end
            S_DOFF: begin need = is_frame && drum_on[ch] && (!w_dgate || w_drum != cur_drum[ch]);
                          m = {2'd3, 8'h89, 1'b0, cur_drum[ch], 8'd0}; end
            S_DON:  begin need = is_frame && w_dgate && !drum_on[ch];
                          m = {2'd3, 8'h99, 1'b0, w_drum, 1'b0, w_vel}; end
            // red de seguridad: tras 1 s en silencio, All Notes Off (CC#123) una vez
            S_PANIC: begin
                         if (PANIC == 2) begin
                             need = is_frame && !cur_on[ch] && (sil[ch] == 7'd25 || sil[ch] == 7'd50);
                             m    = {2'd3, 6'b100000, ch, 1'b0, cur_note[ch], 8'd0};
                         end else begin
                             need = (PANIC != 0) && is_frame && !cur_on[ch] && (sil[ch] == 7'd50);
                             m    = {2'd3, 6'b101100, ch, 8'd123, 8'd0};
                         end
                     end
            default: ;
        endcase
    end

    assign any_on = (|cur_on) | (|drum_on);

    integer j;
    always @(posedge clk) begin
        fpush <= 1'b0; clr_frame <= 1'b0; clr_bend <= 1'b0;
        if (rst) begin
            st <= S_IDLE; ch <= 0; cur_on <= 0; drum_on <= 0; is_frame <= 1'b0;
            for (j = 0; j < 3; j = j + 1) begin
                cur_note[j] <= 0; cur_bend[j] <= 14'd8192; cur_expr[j] <= 0; cur_drum[j] <= 0;
                cand[j] <= 0; ccnt[j] <= 0; sil[j] <= 7'd51;
            end
        end else if (fpush) begin
            // ciclo de respiro: ffull se actualiza
        end else if (need && ffull) begin
            // esperar hueco
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
                    w_gate   <= tone_en && fvalid && (env_rep || lvl > lim);
                    w_within <= in_win;
                    w_note   <= refn;
                    w_bend   <= bend;
                    w_expr   <= expr;
                    w_vel    <= 7'd63 + {1'b0, expr[6:1]};
                    w_dgate  <= noise_en && !tone_en && (lvl > lim);
                    w_drum   <= drum_tab(r[6][4:0], ch);
                    if (is_frame) begin                      // seguimiento de la candidata
                        if (!cur_on[ch] || in1) begin cand[ch] <= near; ccnt[ch] <= 2'd0; end
                        else begin cand[ch] <= near; ccnt[ch] <= ccnt_nx; end
                    end
                    st <= S_OFF;
                end
                S_OFF:  begin if (need) cur_on[ch] <= 1'b0;   st <= S_EXPR; end
                S_EXPR: begin if (need) cur_expr[ch] <= w_expr; st <= S_BEND; end
                S_BEND: begin if (need) cur_bend[ch] <= w_bend; st <= S_ON;   end
                S_ON:   begin if (need) begin cur_on[ch] <= 1'b1; cur_note[ch] <= w_note;
                                               ccnt[ch] <= 2'd0; end
                              st <= S_DOFF; end
                S_DOFF: begin if (need) drum_on[ch] <= 1'b0;  st <= S_DON;  end
                S_DON:  begin if (need) begin drum_on[ch] <= 1'b1; cur_drum[ch] <= w_drum; end
                              st <= S_PANIC; end
                S_PANIC: begin
                    if (is_frame) begin
                        if (cur_on[ch])            sil[ch] <= 7'd0;
                        else if (sil[ch] != 7'd51) sil[ch] <= sil[ch] + 7'd1;
                    end
                    st <= S_NEXT;
                end
                S_NEXT: begin
                    if (ch == 2'd2) st <= S_IDLE;
                    else begin ch <= ch + 2'd1; st <= S_ADDR; end
                end
                default: st <= S_IDLE;
            endcase
        end
    end
endmodule
