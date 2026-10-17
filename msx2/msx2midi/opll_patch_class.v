// =============================================================================
// opll_patch_class.v - Clasifica el instrumento de usuario del YM2413 (R#00-R#07)
// en una familia General MIDI.
//
// Idea del MIDI-PAC v2 (WORP3): reducir el patch a una "firma" de 40 bits y
// asignarla a uno de 16 grupos (G-Piano, G-Basses, G-Strings...). El MIDI-PAC lo hace
// buscando la firma en una base de datos de patches conocidos; aquí se usa un
// árbol de decisión propio sobre los mismos rasgos, con reglas de síntesis FM:
//
//  - EG del portador (R#01 b5): 1 = sostenido (órgano, cuerdas, viento, leads)
//                               0 = percusivo (piano, guitarra, bajo, láminas)
//  - Ataque del portador lento          -> cuerdas / ensemble
//  - Modulación débil (TL del modulador alto) -> casi seno: flauta / órgano
//  - Modulación fuerte + feedback alto  -> lead de sintetizador / guitarra
//  - Relación MULT mod/portador no entera o alta -> timbre metálico: láminas
//  - MULT del portador <= 1 y modulador <= 2 -> bajo
//  - AR del portador = 0 -> el patch no suena ("Silence")
//
// Autor: Shaeon (Carlos Palmero)
// =============================================================================
module opll_patch_class (
    input  wire [7:0] r0, r1, r2, r3, r4, r5, r6, r7,
    output reg  [6:0] prog,        // programa GM (0-based)
    output reg  [3:0] group,       // 0 Default .. 15 Special (informativo)
    output wire       silent,      // el patch no suena
    output wire       vib,         // el patch tiene vibrato (PM)
    output reg  [6:0] vel,         // velocidad de la familia (equilibrio entre instrumentos)
    output wire [6:0] modw         // CC#1 a partir de los bits AM/PM del patch
);
    // ---- rasgos ----
    wire [3:0] m_mult = r0[3:0];
    wire [3:0] c_mult = r1[3:0];
    wire       c_eg   = r1[5];               // portador sostenido
    wire [5:0] m_tl   = r2[5:0];             // 0 = modulación máxima, 63 = nula
    wire       c_dc   = r3[4];               // portador semirrectificado
    wire       m_dm   = r3[3];               // modulador semirrectificado
    wire [2:0] fb     = r3[2:0];
    wire [3:0] m_ar   = r4[7:4];
    wire [3:0] c_ar   = r5[7:4];
    wire [3:0] c_dr   = r5[3:0];
    wire [3:0] c_sl   = r7[7:4];
    wire [3:0] c_rr   = r7[3:0];

    // "Silence": portador sin ataque, o patch todo a cero (como la voz Silence del MIDI-PAC)
    assign silent = (c_ar == 4'd0) || ({r0, r1, r2, r3, r4, r5, r6, r7} == 64'd0);
    assign vib    = r0[6] | r1[6];
    // Modulación como el firmware 2.18: banderas {PM mod, AM mod, PM port, AM port} x 4,
    // por el multiplicador (aquí x2): 0..120
    wire [3:0] modf = {r0[6], r0[7], r1[6], r1[7]};
    assign modw = {modf, 3'b000};

    wire mod_strong   = (m_tl < 6'd20);          // mucha modulación: timbre brillante
    wire mod_weak     = (m_tl >= 6'd36);         // poca modulación: casi seno
    wire buzzy    = (fb >= 3'd5) || m_dm || c_dc;
    // relación de frecuencias "rara": metálico / campanas
    wire metal    = (m_mult >= 4'd7) || (c_mult >= 4'd4) ||
                    (m_mult == 4'd5 && c_mult != 4'd5) || (m_mult == 4'd3 && c_mult == 4'd2);
    wire low      = (c_mult <= 4'd1) && (m_mult <= 4'd2);
    wire slow_att = (c_ar <= 4'd7);
    wire fast_dec = (c_dr >= 4'd9);

    localparam G_DEFAULT = 4'd0,  G_PIANO = 4'd1,  G_CHROMAT = 4'd2,  G_ORGAN = 4'd3,
               G_GUITAR  = 4'd4,  G_BASS  = 4'd5,  G_STRINGS = 4'd6,  G_ENSEMB = 4'd7,
               G_BRASS   = 4'd8,  G_REEDS = 4'd9,  G_PIPE    = 4'd10, G_SYNTH = 4'd11,
               G_ETHNIC  = 4'd12, G_SNARE = 4'd13, G_BASSDR  = 4'd14, G_SPECIAL = 4'd15;

    always @* begin
        if (c_eg) begin                                   // ---- sostenidos ----
            if (slow_att)                 group = mod_strong ? G_STRINGS : G_ENSEMB;
            else if (mod_weak)                group = vib ? G_PIPE : G_ORGAN;
            else if (low && !buzzy)       group = G_BASS;
            else if (buzzy && mod_strong)     group = G_SYNTH;
            else if (m_mult == c_mult)    group = G_BRASS;
            else if (m_mult == {c_mult[2:0], 1'b0}) group = G_REEDS;   // mod = 2x portador
            else if (metal)               group = G_ORGAN;
            else                          group = G_DEFAULT;
        end else begin                                    // ---- percusivos ----
            if (fast_dec && fb >= 3'd6 && m_mult >= 4'd6) group = G_SNARE;
            else if (fast_dec && low && mod_strong && c_rr >= 4'd8) group = G_BASSDR;
            else if (low)                 group = G_BASS;
            else if (metal)               group = G_CHROMAT;
            else if (buzzy && mod_strong)     group = (m_mult >= 4'd3) ? G_ETHNIC : G_GUITAR;
            else if (c_dr <= 4'd4)        group = G_PIANO;
            else                          group = G_GUITAR;
        end
    end

    always @* begin
        case (group)
            G_PIANO:   prog = 7'd0;    // Acoustic Grand Piano
            G_CHROMAT: prog = 7'd11;   // Vibraphone
            G_ORGAN:   prog = 7'd16;   // Drawbar Organ
            G_GUITAR:  prog = 7'd25;   // Steel Guitar
            G_BASS:    prog = c_eg ? 7'd38 : 7'd33;   // Synth Bass 1 / Finger Bass
            G_STRINGS: prog = 7'd40;   // Violin
            G_ENSEMB:  prog = 7'd48;   // String Ensemble 1
            G_BRASS:   prog = 7'd61;   // Brass Section
            G_REEDS:   prog = 7'd65;   // Alto Sax
            G_PIPE:    prog = 7'd73;   // Flute
            G_SYNTH:   prog = (fb >= 3'd6) ? 7'd81 : 7'd80;  // Saw / Square Lead
            G_ETHNIC:  prog = 7'd107;  // Koto
            G_SNARE:   prog = 7'd118;  // Synth Drum
            G_BASSDR:  prog = 7'd116;  // Taiko Drum
            G_SPECIAL: prog = 7'd89;   // Warm Pad
            default:   prog = 7'd80;   // Square Lead (sonido "chip")
        endcase
    end

    // Velocidad por familia: el MIDI-PAC da a cada tipo de voz su propio volumen
    // (velocidad = vol * 4 + 3) y deja el volumen del canal para los controladores.
    // Valores propios: bajos, percusión y pads más suaves; pianos y metales más fuertes.
    always @* begin
        case (group)
            G_PIANO:   vel = 7'd110;  G_CHROMAT: vel = 7'd95;   G_ORGAN:   vel = 7'd90;
            G_GUITAR:  vel = 7'd100;  G_BASS:    vel = 7'd85;   G_STRINGS: vel = 7'd100;
            G_ENSEMB:  vel = 7'd105;  G_BRASS:   vel = 7'd110;  G_REEDS:   vel = 7'd105;
            G_PIPE:    vel = 7'd105;  G_SYNTH:   vel = 7'd95;   G_ETHNIC:  vel = 7'd95;
            G_SNARE:   vel = 7'd90;   G_BASSDR:  vel = 7'd80;   G_SPECIAL: vel = 7'd70;
            default:   vel = 7'd100;
        endcase
    end
endmodule
