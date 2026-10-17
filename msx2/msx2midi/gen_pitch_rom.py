#!/usr/bin/env python3
# Genera psg2midi_pitch_rom.v: período de tono del PSG (12 bits) -> tono MIDI fino
# (nota*256 + fracción). 16'hFFFF = fuera del rango MIDI (no se toca).
# Uso: python3 gen_pitch_rom.py [reloj_psg_hz]
import math, sys
PSG_HZ = float(sys.argv[1]) if len(sys.argv) > 1 else 3579545 / 2
lines = []
for tp in range(4096):
    t = max(tp, 1)
    f = PSG_HZ / (16 * t)
    fine = round((69 + 12 * math.log2(f / 440.0)) * 256)
    v = fine if 0 <= fine <= 127 * 256 else 0xFFFF
    lines.append(f"            12'd{tp}: q <= 16'h{v:04X};")
with open("psg2midi_pitch_rom.v", "w") as fo:
    fo.write(f"""// Generado por gen_pitch_rom.py (PSG clock = {PSG_HZ:.1f} Hz). No editar a mano.
// Período de tono (12 bits) -> nota MIDI * 256 (8 bits de fracción). FFFF = fuera de rango.
module psg2midi_pitch_rom (
    input  wire        clk,
    input  wire [11:0] addr,
    output reg  [15:0] q
);
    always @(posedge clk) begin
        case (addr)
{chr(10).join(lines)}
            default: q <= 16'hFFFF;
        endcase
    end
endmodule
""")
