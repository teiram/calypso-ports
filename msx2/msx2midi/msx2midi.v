// =============================================================================
// msx2midi.v - PSG + OPLL -> MIDI para cores MSX, con mezcla de un MIDI externo
//
//  - psg2midi_conv : PSG  -> MIDI canales 1-3 y percusión (10)
//  - opll2midi_conv: OPLL -> MIDI canales 4-9, 11-13 y percusión (10)
//  - ext_rx        : línea MIDI serie de otra fuente (p. ej. el MIDI de OCM), que se
//                    mezcla respetando los límites de mensaje (inserta el status
//                    cuando la fuente usa running status y cierra SysEx cortados)
//  - Interfaz MIDI-PAC v2 (WORP3) en 7Ch/7Dh: detección, lectura de versión e ID,
//    sincronización y modo MIDI directo (ED/EE), para que funcione MIDIPLAY.COM.
//  - Secuencia de arranque GM, serializador y UART 31250 8-N-1.
//
// Cualquier cambio de configuración (OSD) reinicia la salida y repite el arranque.
//
// Autor: Shaeon (Carlos Palmero)
// =============================================================================
module msx2midi #(
    parameter integer CLK_HZ   = 21477270,
    parameter integer PSG_HZ   = 1789773,
    parameter integer BAUD     = 31250,
    parameter integer FRAME_HZ = 50,
    parameter integer BEND_HZ  = 100,
    // Ajustes para sintetizadores sencillos (p. ej. el de la MCU de la Calypso):
    parameter integer EXPR_CC  = 11,    // 11 = CC#11 expresión (GM); 7 = CC#7 si el sinte ignora CC#11
    parameter integer PANIC    = 1,     // 0 = no mandar CC#123 por canal (si el sinte lo aplica a todos)
    parameter integer KEEPALIVE_MS = 0, // >0 = Active Sensing (FEh) si la línea lleva ese tiempo callada
    parameter integer RUNNING_STATUS = 0, // 1 = omitir el status repetido (menos bytes por la línea)
    parameter integer QUIET_ANO_MS = 0  // >0 = un CC#123 global cuando ningún conversor tiene notas
                                        //      sonando desde hace ese tiempo (limpia notas colgadas)
)(
    input  wire       clk,
    input  wire       reset,        // reset del MSX
    input  wire       psg_en,       // OSD: convertir PSG
    input  wire       opll_en,      // OSD: convertir OPLL
    input  wire       ext_en,       // OSD: mezclar la entrada ext_rx
    input  wire [1:0] stable_n,     // OSD: estabilidad de nota 0 = off, 1..3 = 2..4 frames
    input  wire [1:0] psg_thr,      // OSD: umbral de silencio del PSG (volumen <= thr = apagado)
    input  wire       mpac_en,      // OSD: interfaz MIDI-PAC (lectura de 7Ch y comandos E0h-FFh)

    input  wire       psg_wr,  input wire psg_a0,  input wire [7:0] psg_d,
    input  wire       opll_wr, input wire opll_a0, input wire [7:0] opll_d,
    input  wire       ext_rx,       // MIDI serie externo (reposo = 1)

    output wire       midi_tx,
    output wire       active,
    output wire [7:0] mpac_dbi,     // dato que devuelve una lectura de 7Ch/7Dh
    output reg  [7:0] tx_byte,      // byte MIDI que empieza a salir por midi_tx...
    output reg        tx_stb        // ...con un pulso de un ciclo (para user_io serial_data)
);
    // ---------------- reinicio por cambio de configuración ----------------
    wire [7:0] cfg = {psg_en, opll_en, ext_en, stable_n, psg_thr, mpac_en};
    reg  [7:0] cfg_q;
    reg  [7:0] rcnt;
    always @(posedge clk) begin
        cfg_q <= cfg;
        if (reset || cfg != cfg_q) rcnt <= 8'hFF;
        else if (rcnt != 0)        rcnt <= rcnt - 8'd1;
    end
    wire rst = (rcnt != 0);

    // ---------------- ticks ----------------
    localparam integer FDIV = CLK_HZ / FRAME_HZ;
    localparam integer BDIV = CLK_HZ / BEND_HZ;
    reg [31:0] fcnt, bcnt;
    reg        tick_frame, tick_bend;
    always @(posedge clk) begin
        tick_frame <= 1'b0; tick_bend <= 1'b0;
        if (rst) begin fcnt <= 0; bcnt <= 0; end
        else begin
            if (fcnt == FDIV - 1) begin fcnt <= 0; tick_frame <= 1'b1; end else fcnt <= fcnt + 1;
            if (bcnt == BDIV - 1) begin bcnt <= 0; tick_bend  <= 1'b1; end else bcnt <= bcnt + 1;
        end
    end

    // ---------------- conversores ----------------
    reg         init_done;
    reg         mp_direct;                     // MIDI-PAC en modo MIDI directo (MIDIPLAY)
    wire [7:0]  ef_level;                      // ocupación de la FIFO externa (declarada abajo)
    wire [25:0] psg_msg,  opll_msg;
    wire        psg_empty, opll_empty;
    wire        psg_any, opll_any;
    reg         psg_pop,  opll_pop;

    psg2midi_conv #(.CLK_HZ(CLK_HZ), .PSG_HZ(PSG_HZ), .EXPR_CC(EXPR_CC), .PANIC(PANIC)) psg_u (
        .clk(clk), .rst_regs(reset), .rst(rst | ~init_done | ~psg_en),
        .stable_n(stable_n), .thr(psg_thr), .tick_frame(tick_frame), .tick_bend(tick_bend),
        .psg_wr(psg_wr), .psg_a0(psg_a0), .psg_d(psg_d),
        .any_on(psg_any), .msg(psg_msg), .msg_empty(psg_empty), .msg_pop(psg_pop));

    opll2midi_conv #(.EXPR_CC(EXPR_CC), .PANIC(PANIC)) opll_u (
        .clk(clk), .rst_regs(reset), .rst(rst | ~init_done | ~opll_en | mp_direct),
        .stable_n(stable_n), .tick_frame(tick_frame), .tick_bend(tick_bend),
        .opll_wr(opll_wr), .opll_a0(opll_a0), .opll_d(opll_d),
        .any_on(opll_any), .msg(opll_msg), .msg_empty(opll_empty), .msg_pop(opll_pop));

    // ---------------- interfaz MIDI-PAC v2 ----------------
    // Lectura de 7Ch: bit0 = bit leído (FEh/FBh) u ocupado (resto), bit1 = ack (cambia
    // tras cada comando Ex/Fx), bit2/bit3 = cambian con cada escritura a 7Ch/7Dh.
    // Comandos (dirección escrita en 7Ch, dato en 7Dh), según MIDIPLAY y el firmware 2.18:
    //   EDh  1 = entrar / 0 = salir del modo MIDI directo (se para la conversión del OPLL)
    //   EEh  byte MIDI crudo (solo en modo directo)
    //   FEh  dato = {sel[6:5], bit[4:0]}: sel 0 modo, 1 versión "2.18", 2 ID "MP-A", 3 eco
    //   FBh  bit de un byte de configuración (se devuelve 0)
    //   FFh  sincronización; el resto de Ex/Fx: solo ack
    reg        mw_q;
    wire       mw_stb = opll_wr & ~mw_q;
    reg  [7:0] mp_adr;
    reg        mp_t2, mp_t3, mp_ack, mp_rbit;
    reg        mp_bvalid;
    reg  [7:0] mp_byte;
    reg  [31:0] mp_word;
    wire       mp_busy = (ef_level >= 8'd96);
    wire       an_en   = ext_en | mpac_en;     // analizador de MIDI externo / directo activo

    function [31:0] fe_word(input [7:0] d);
        case (d[6:5])
            2'd0:    fe_word = 32'h0000_0006;                        // aplicación, MPC correcto
            2'd1:    fe_word = {8'h32, 8'h2E, 8'h31, 8'h38};         // "2.18"
            2'd2:    fe_word = {8'h4D, 8'h50, 8'h2D, 8'h41};         // "MP-A"
            default: fe_word = {24'd0, d};                           // eco (prueba de datos)
        endcase
    endfunction
    wire [31:0] fe_w = fe_word(opll_d);

    always @(posedge clk) begin
        mw_q      <= opll_wr;
        mp_bvalid <= 1'b0;
        if (rst || !mpac_en) begin
            mp_adr <= 8'h00; mp_t2 <= 1'b0; mp_t3 <= 1'b0; mp_ack <= 1'b0;
            mp_rbit <= 1'b0; mp_direct <= 1'b0; mp_word <= 32'd0;
        end else if (mw_stb) begin
            if (!opll_a0) begin
                mp_adr <= opll_d; mp_t2 <= ~mp_t2;
            end else begin
                mp_t3 <= ~mp_t3;
                if (mp_adr[7:5] == 3'b111) begin
                    mp_ack <= ~mp_ack;
                    case (mp_adr)
                        8'hED: mp_direct <= (opll_d == 8'h01);
                        8'hEE: if (mp_direct) begin mp_bvalid <= 1'b1; mp_byte <= opll_d; end
                        8'hFE: begin
                                   if (opll_d[6:5] != 2'd3 || opll_d[4:3] == 2'b01) begin
                                       mp_word <= fe_w;  mp_rbit <= fe_w[opll_d[4:0]];
                                   end else
                                       mp_rbit <= mp_word[opll_d[4:0]];
                               end
                        8'hFB: mp_rbit <= 1'b0;
                        default: ;
                    endcase
                end
            end
        end
    end
    wire mp_bit0 = (mp_adr == 8'hFE || mp_adr == 8'hFB) ? mp_rbit : mp_busy;
    assign mpac_dbi = {4'b1111, mp_t3, mp_t2, mp_ack, mp_bit0};

    // ---------------- receptor UART de la fuente externa ----------------
    localparam integer UDIV = (CLK_HZ + BAUD/2) / BAUD;
    reg  [2:0]  rx_s;
    reg  [15:0] rx_cnt;
    reg  [3:0]  rx_bit;
    reg  [7:0]  rx_sh;
    reg         rx_busy, rx_valid;
    reg  [7:0]  rx_byte;
    always @(posedge clk) begin
        rx_s     <= {rx_s[1:0], ext_rx};
        rx_valid <= 1'b0;
        if (rst || !ext_en) begin
            rx_busy <= 1'b0;
        end else if (!rx_busy) begin
            if (rx_s[2:1] == 2'b10) begin            // flanco de bajada: bit de start
                rx_busy <= 1'b1; rx_cnt <= UDIV + UDIV/2 - 1; rx_bit <= 0;
            end
        end else if (rx_cnt != 0) rx_cnt <= rx_cnt - 16'd1;
        else begin
            rx_cnt <= UDIV - 1;
            if (rx_bit == 4'd8) begin                 // bit de stop
                rx_busy <= 1'b0;
                if (rx_s[1]) begin rx_valid <= 1'b1; rx_byte <= rx_sh; end
            end else begin
                rx_sh  <= {rx_s[1], rx_sh[7:1]};
                rx_bit <= rx_bit + 4'd1;
            end
        end
    end

    // ---------------- analizador de la fuente externa ----------------
    // Escribe bytes en ext_fifo con la marca "último byte del mensaje" (bit 8).
    function [1:0] dlen(input [7:0] s);       // bytes de datos de un status
        dlen = (s[7:4] == 4'hC || s[7:4] == 4'hD || s == 8'hF1 || s == 8'hF3) ? 2'd1 :
               (s == 8'hF6) ? 2'd0 : 2'd2;
    endfunction

    reg  [7:0] ext_rs;                         // running status (0 = ninguno)
    reg  [1:0] ext_need;                       // datos que faltan del mensaje actual
    reg        ext_sysex;
    reg        e1_v, e2_v;                     // hasta dos bytes que escribir
    reg  [8:0] e1, e2;
    reg        ef_push;
    reg  [8:0] ef_din;
    wire [8:0] ef_dout;
    wire       ef_empty, ef_full;
    reg        ef_pop;

    msx2midi_fifo #(.W(9), .AW(7)) ext_fifo (
        .clk(clk), .rst(rst | ~an_en), .push(ef_push), .din(ef_din),
        .pop(ef_pop), .dout(ef_dout), .empty(ef_empty), .full(ef_full), .level(ef_level));

    // fuente del analizador: UART externa, o los bytes EEh del MIDI-PAC en modo directo
    wire       an_valid = mp_direct ? mp_bvalid : rx_valid;
    wire [7:0] an_byte  = mp_direct ? mp_byte   : rx_byte;

    always @(posedge clk) begin
        ef_push <= 1'b0;
        if (rst || !an_en) begin
            ext_rs <= 0; ext_need <= 0; ext_sysex <= 1'b0; e1_v <= 1'b0; e2_v <= 1'b0;
        end else if (e1_v) begin
            ef_push <= 1'b1; ef_din <= e1; e1_v <= e2_v; e1 <= e2; e2_v <= 1'b0;
        end else if (an_valid) begin
            if (an_byte >= 8'hF8) begin                                      // tiempo real
                e1_v <= 1'b1; e1 <= {!(ext_sysex || ext_need != 0), an_byte};
            end else if (an_byte[7]) begin                                   // status
                if (an_byte == 8'hF7 || an_byte == 8'hF4 || an_byte == 8'hF5) begin
                    if (ext_sysex) begin e1_v <= 1'b1; e1 <= {1'b1, 8'hF7}; end   // fin de SysEx
                    ext_sysex <= 1'b0;
                    if (an_byte != 8'hF7) begin ext_rs <= 8'h00; ext_need <= 2'd0; end
                end else begin
                    if (ext_sysex) begin                                     // cerrar SysEx cortado
                        e1_v <= 1'b1; e1 <= {1'b1, 8'hF7};
                        e2_v <= 1'b1; e2 <= {(an_byte == 8'hF6), an_byte};
                    end else begin
                        e1_v <= 1'b1; e1 <= {(an_byte == 8'hF6), an_byte};
                    end
                    ext_sysex <= (an_byte == 8'hF0);
                    ext_need  <= (an_byte == 8'hF0) ? 2'd0 : dlen(an_byte);
                    ext_rs    <= (an_byte < 8'hF0) ? an_byte : 8'h00;
                end
            end else begin                                                   // dato
                if (ext_sysex) begin
                    e1_v <= 1'b1; e1 <= {1'b0, an_byte};
                end else if (ext_need != 0) begin
                    e1_v <= 1'b1; e1 <= {(ext_need == 2'd1), an_byte};
                    ext_need <= ext_need - 2'd1;
                end else if (ext_rs != 0) begin                              // running status
                    e1_v <= 1'b1; e1 <= {1'b0, ext_rs};
                    e2_v <= 1'b1; e2 <= {(dlen(ext_rs) == 2'd1), an_byte};
                    ext_need <= dlen(ext_rs) - 2'd1;
                end
            end
        end
    end

    // ---------------- secuencia de arranque ----------------
    // canales melódicos: 0-2 PSG, 3-8 y 10-12 OPLL
    function [3:0] ich(input [3:0] n);
        ich = (n < 9) ? n : n + 4'd1;
    endfunction
    function [7:0] ipan(input [3:0] c);
        case (c)
            4'd0: ipan = 48;  4'd1: ipan = 64;  4'd2: ipan = 80;  4'd3: ipan = 40;
            4'd4: ipan = 88;  4'd5: ipan = 52;  4'd6: ipan = 76;  4'd7: ipan = 64;
            4'd8: ipan = 58;  4'd10: ipan = 70; 4'd11: ipan = 46; default: ipan = 82;
        endcase
    endfunction

    localparam integer INIT_N = 193;
    reg  [7:0] ii;
    function [25:0] init_rom(input [7:0] i);
        reg [3:0] c; reg [7:0] t; reg [3:0] s;
        begin
            init_rom = 26'd0;
            if (i < 32) init_rom = {2'd3, 4'hB, i[4:1], i[0] ? 8'd121 : 8'd120, 8'd0};   // ASO + reset
            else if (i == 32) init_rom = {2'd3, 8'hF0, 8'h7E, 8'h7F};                    // GM System On
            else if (i == 33) init_rom = {2'd3, 8'h09, 8'h01, 8'hF7};
            else if (i == 34) init_rom = 26'd0;                                          // espera
            else if (i < 191) begin
                t = i - 8'd35;
                c = ich(t / 13);
                s = t % 13;
                case (s)
                    0:  init_rom = {2'd2, 4'hC, c, (c < 3) ? 8'd80 : 8'd0, 8'd0};        // programa
                    1:  init_rom = {2'd3, 4'hB, c, 8'd7,  8'd100};
                    2:  init_rom = {2'd3, 4'hB, c, 8'd10, ipan(c)};
                    3:  init_rom = {2'd3, 4'hB, c, 8'd91, (c < 3) ? 8'd0 : 8'd32};       // reverb
                    4:  init_rom = {2'd3, 4'hB, c, 8'd93, 8'd0};
                    5:  init_rom = {2'd3, 4'hB, c, 8'd11, 8'd0};
                    6:  init_rom = {2'd3, 4'hB, c, 8'd101, 8'd0};                        // RPN 0/0
                    7:  init_rom = {2'd3, 4'hB, c, 8'd100, 8'd0};
                    8:  init_rom = {2'd3, 4'hB, c, 8'd6,  8'd2};                         // +-2 semitonos
                    9:  init_rom = {2'd3, 4'hB, c, 8'd38, 8'd0};
                    10: init_rom = {2'd3, 4'hB, c, 8'd101, 8'd127};
                    11: init_rom = {2'd3, 4'hB, c, 8'd100, 8'd127};
                    default: init_rom = {2'd3, 4'hE, c, 8'd0, 8'd64};
                endcase
            end
            else if (i == 191) init_rom = {2'd3, 8'hB9, 8'd7,  8'd90};
            else               init_rom = {2'd3, 8'hB9, 8'd11, 8'd127};
        end
    endfunction
    wire [25:0] init_w = init_rom(ii);

    // ---------------- serializador + UART TX ----------------
    reg  [15:0] ubaud;
    reg  [9:0]  ush;
    reg  [3:0]  ubits;
    wire        ubusy = (ubits != 0);
    reg  [1:0]  mleft;
    reg  [23:0] mbuf;
    reg  [1:0]  src;           // 0 msg, 1 ext
    reg         lock_ext;
    reg  [1:0]  rr;            // turno: 0 ext, 1 psg, 2 opll
    reg  [23:0] wcnt;
    reg         waiting;
    reg  [23:0] ext_to;        // tiempo sin bytes dentro de un mensaje externo
    localparam integer KA_DIV = (KEEPALIVE_MS > 0) ? (CLK_HZ / 1000) * KEEPALIVE_MS : 1;
    reg  [31:0] ka_cnt;        // tiempo con la línea callada
    reg  [7:0]  last_st;       // último status de canal enviado (running status)
    // All Notes Off global cuando no suena nada: tras QUIET_ANO_MS sin notas en ningún conversor
    // (y sin fuente externa ni modo directo, cuyas notas no conocemos) se manda un CC#123.
    localparam integer QA_DIV = (QUIET_ANO_MS > 0) ? (CLK_HZ / 1000) * QUIET_ANO_MS : 1;
    reg  [31:0] qa_cnt;
    reg         qa_pend, qa_done, qa_clr;
    always @(posedge clk) begin
        if (rst || QUIET_ANO_MS == 0 || psg_any || opll_any || ext_en || mp_direct) begin
            qa_cnt <= 0; qa_pend <= 1'b0; qa_done <= 1'b0;
        end else if (!qa_done) begin
            if (qa_cnt >= QA_DIV - 1) begin qa_pend <= 1'b1; qa_done <= 1'b1; end
            else qa_cnt <= qa_cnt + 32'd1;
        end else if (qa_clr) qa_pend <= 1'b0;
    end
    // carga de un mensaje de 2 o 3 bytes, quitando el status si se repite
    function rs_skip(input [7:0] b0);
        rs_skip = (RUNNING_STATUS != 0) && b0[7] && (b0 < 8'hF0) && (b0 == last_st);
    endfunction

    always @(posedge clk) begin
        psg_pop <= 1'b0; opll_pop <= 1'b0; ef_pop <= 1'b0; qa_clr <= 1'b0;
        if (rst) begin
            ubits <= 0; ush <= 10'h3FF; ubaud <= 0; mleft <= 0; lock_ext <= 1'b0;
            rr <= 0; ii <= 0; init_done <= 1'b0; waiting <= 1'b0; wcnt <= 0; ext_to <= 0; ka_cnt <= 0;
            last_st <= 8'h00; qa_clr <= 1'b0;
        end else if (ubusy) begin
            ka_cnt <= 0;
            if (ubaud == UDIV - 1) begin
                ubaud <= 0; ush <= {1'b1, ush[9:1]}; ubits <= ubits - 4'd1;
            end else ubaud <= ubaud + 16'd1;
        end else if (psg_pop || opll_pop || ef_pop) begin
            // un ciclo para que la FIFO avance
        end else if (mleft != 0) begin                       // bytes de un mensaje
            ush   <= {1'b1, mbuf[23:16], 1'b0}; ubits <= 4'd10; ubaud <= 0;
            mbuf  <= {mbuf[15:0], 8'h00};
            mleft <= mleft - 2'd1;
        end else if (!init_done) begin                       // arranque
            if (waiting) begin
                if (wcnt == CLK_HZ / 10) begin waiting <= 1'b0; ii <= ii + 8'd1; end
                else wcnt <= wcnt + 24'd1;
            end else if (init_w[25:24] == 2'd0) begin waiting <= 1'b1; wcnt <= 0; end
            else begin
                mbuf <= init_w[23:0]; mleft <= init_w[25:24];
                if (init_w[23]) last_st <= (init_w[23:16] < 8'hF0) ? init_w[23:16] : 8'h00;
                if (ii == INIT_N - 1) init_done <= 1'b1; else ii <= ii + 8'd1;
            end
        end else if (lock_ext) begin                         // dentro de un mensaje externo
            if (!ef_empty) begin
                ush <= {1'b1, ef_dout[7:0], 1'b0}; ubits <= 4'd10; ubaud <= 0;
                ef_pop <= 1'b1; ext_to <= 0;
                if (ef_dout[7] && ef_dout[7:0] < 8'hF8) last_st <= (ef_dout[7:0] < 8'hF0) ? ef_dout[7:0] : 8'h00;
                if (ef_dout[8]) lock_ext <= 1'b0;
            end else if (ext_to == CLK_HZ / 50) lock_ext <= 1'b0;   // 20 ms sin datos: soltar
            else ext_to <= ext_to + 24'd1;
        end else if (qa_pend && ef_empty && psg_empty && opll_empty) begin
            // All Notes Off global (canal 1; el sinte de la Calypso lo aplica a todos)
            mbuf <= rs_skip(8'hB0) ? {8'd123, 8'd0, 8'd0} : {8'hB0, 8'd123, 8'd0};
            mleft <= rs_skip(8'hB0) ? 2'd2 : 2'd3;
            last_st <= 8'hB0; qa_clr <= 1'b1;
        end else if (KEEPALIVE_MS > 0 && ef_empty && psg_empty && opll_empty) begin
            // nada que mandar: Active Sensing periódico para que el sinte no suelte las notas
            if (ka_cnt >= KA_DIV - 1) begin
                ush <= {1'b1, 8'hFE, 1'b0}; ubits <= 4'd10; ubaud <= 0; ka_cnt <= 0;
            end else ka_cnt <= ka_cnt + 32'd1;
        end else begin                                       // elegir fuente (turno rotativo)
            rr <= (rr == 2'd2) ? 2'd0 : rr + 2'd1;
            case (rr)
                2'd0: if (!ef_empty) begin
                          ush <= {1'b1, ef_dout[7:0], 1'b0}; ubits <= 4'd10; ubaud <= 0;
                          ef_pop <= 1'b1; ext_to <= 0; lock_ext <= !ef_dout[8];
                          if (ef_dout[7] && ef_dout[7:0] < 8'hF8) last_st <= (ef_dout[7:0] < 8'hF0) ? ef_dout[7:0] : 8'h00;
                      end
                2'd1: if (!psg_empty) begin
                          mbuf  <= rs_skip(psg_msg[23:16]) ? {psg_msg[15:0], 8'h00} : psg_msg[23:0];
                          mleft <= psg_msg[25:24] - (rs_skip(psg_msg[23:16]) ? 2'd1 : 2'd0);
                          if (psg_msg[23]) last_st <= (psg_msg[23:16] < 8'hF0) ? psg_msg[23:16] : 8'h00;
                          psg_pop <= 1'b1;
                      end
                default: if (!opll_empty) begin
                          mbuf  <= rs_skip(opll_msg[23:16]) ? {opll_msg[15:0], 8'h00} : opll_msg[23:0];
                          mleft <= opll_msg[25:24] - (rs_skip(opll_msg[23:16]) ? 2'd1 : 2'd0);
                          if (opll_msg[23]) last_st <= (opll_msg[23:16] < 8'hF0) ? opll_msg[23:16] : 8'h00;
                          opll_pop <= 1'b1;
                      end
            endcase
        end
    end

    // copia en paralelo de cada byte que entra en la UART (ya va al ritmo de 31250 baudios)
    reg ubusy_q;
    always @(posedge clk) begin
        ubusy_q <= ubusy;
        tx_stb  <= 1'b0;
        if (rst) ubusy_q <= 1'b0;
        else if (ubusy && !ubusy_q) begin tx_byte <= ush[8:1]; tx_stb <= 1'b1; end
    end

    assign midi_tx = ubusy ? ush[0] : 1'b1;
    assign active  = ubusy;
endmodule
