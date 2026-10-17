#!/usr/bin/env python3
# Genera opll2midi_fnum_rom.v: F-number del YM2413 (9 bits, bloque 0) -> nota MIDI * 256
# (con signo). Para el bloque B: fino = base + B * 3072. 16'h8000 = F-number 0 (no suena).
# f = fnum * (fclk / 72) / 2^(19 - bloque)
import math, sys
FCLK = float(sys.argv[1]) if len(sys.argv) > 1 else 3579545.0
lines = []
for fn in range(512):
    if fn == 0:
        v = 0x8000
    else:
        f = fn * (FCLK / 72) / 2**19
        v = round((69 + 12 * math.log2(f / 440.0)) * 256) & 0xFFFF
    lines.append(f"            9'd{fn}: q <= 16'h{v:04X};")
open("opll2midi_fnum_rom.v", "w").write(f"""// Generado por gen_opll_rom.py (OPLL clock = {FCLK:.0f} Hz). No editar a mano.
// F-number (bloque 0) -> nota MIDI * 256 con signo. 8000 = F-number 0.
module opll2midi_fnum_rom (
    input  wire       clk,
    input  wire [8:0] addr,
    output reg [15:0] q
);
    always @(posedge clk) begin
        case (addr)
{chr(10).join(lines)}
            default: q <= 16'h8000;
        endcase
    end
endmodule
""")
