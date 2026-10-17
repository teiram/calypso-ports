// Testbench de msx2midi: PSG (con estabilidad de nota), OPLL y mezcla de MIDI externo.
//   iverilog -o tb tb_msx2midi.v msx2midi.v psg2midi_conv.v opll2midi_conv.v \
//            msx2midi_fifo.v psg2midi_pitch_rom.v opll2midi_fnum_rom.v && vvp tb
`timescale 1ns/1ps
module tb_opll;
    localparam integer CLK_HZ = 4000000;
    localparam real    TCLK   = 1.0e9 / CLK_HZ;
    localparam real    TBIT   = 1.0e9 / 31250;

    reg clk = 0, reset = 1;
    reg psg_en = 1, opll_en = 1, ext_en = 1;
    reg [1:0] stable_n = 2'd2;                       // 3 frames
    reg [1:0] psg_thr  = 2'd2;                       // volumen <= 2 = silencio
    reg psg_wr = 0, psg_a0 = 0;  reg [7:0] psg_d = 0;
    reg opll_wr = 0, opll_a0 = 0; reg [7:0] opll_d = 0;
    reg ext_rx = 1;
    wire midi_tx, active;
    always #(TCLK/2) clk = ~clk;

    msx2midi #(.CLK_HZ(CLK_HZ)) dut (
        .clk(clk), .reset(reset), .psg_en(psg_en), .opll_en(opll_en), .ext_en(ext_en),
        .stable_n(stable_n), .psg_thr(psg_thr), .mpac_en(1'b0),
        .psg_wr(psg_wr), .psg_a0(psg_a0), .psg_d(psg_d),
        .opll_wr(opll_wr), .opll_a0(opll_a0), .opll_d(opll_d),
        .ext_rx(ext_rx), .midi_tx(midi_tx), .active(active), .mpac_dbi());

    task psg(input [3:0] rg, input [7:0] v);
        begin
            @(negedge clk); psg_a0 = 0; psg_d = rg; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0;
            repeat (10) @(negedge clk); psg_a0 = 1; psg_d = v; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0;
            repeat (10) @(negedge clk);
        end
    endtask
    task opll(input [7:0] rg, input [7:0] v);
        begin
            @(negedge clk); opll_a0 = 0; opll_d = rg; opll_wr = 1; repeat (4) @(negedge clk); opll_wr = 0;
            repeat (10) @(negedge clk); opll_a0 = 1; opll_d = v; opll_wr = 1; repeat (4) @(negedge clk); opll_wr = 0;
            repeat (10) @(negedge clk);
        end
    endtask
    task ext_byte(input [7:0] b);           // fuente MIDI externa (como el 8251 de OCM)
        integer n;
        begin
            ext_rx = 0; #(TBIT);
            for (n = 0; n < 8; n = n + 1) begin ext_rx = b[n]; #(TBIT); end
            ext_rx = 1; #(TBIT);
        end
    endtask
    task ms(input integer t); begin #(t * 1000000.0); end endtask

    // ---- decodificador MIDI de la salida ----
    reg show = 0;
    reg [7:0] rx; integer b;
    reg [7:0] m [0:2]; integer mi = 0, need = 0;
    initial forever begin
        @(negedge midi_tx);
        #(TBIT * 1.5);
        for (b = 0; b < 8; b = b + 1) begin rx[b] = midi_tx; #(TBIT); end
        if (midi_tx !== 1'b1) $display("%0d ms  ERROR de stop bit", $time / 1000000);
        if (rx[7] && rx < 8'hF0) begin mi = 0; need = (rx[7:4] == 4'hC || rx[7:4] == 4'hD) ? 2 : 3; end
        if (rx >= 8'hF0 || need == 0) begin
            if (show) $display("%0d ms  byte %02h", $time / 1000000, rx);
        end else begin
            m[mi] = rx; mi = mi + 1;
            if (!rx[7] && mi == 1) $display("%0d ms  ERROR: dato sin status %02h", $time / 1000000, rx);
            if (mi == need) begin
                if (show) begin
                    $write("%0d ms  ch%0d ", $time / 1000000, m[0][3:0] + 1);
                    case (m[0][7:4])
                        4'h8: $write("NOTE OFF %0d\n", m[1]);
                        4'h9: $write("NOTE ON  %0d vel %0d\n", m[1], m[2]);
                        4'hB: $write("CC%0d = %0d\n", m[1], m[2]);
                        4'hC: $write("PROGRAM %0d\n", m[1] + 1);
                        4'hE: $write("BEND %0d centimos\n", ($signed({18'd0, m[2][6:0], m[1][6:0]}) - 8192) * 200 / 8192);
                    endcase
                end
                mi = 0; need = 0;
            end
        end
    end

    integer f;
    initial begin
        repeat (20) @(posedge clk); reset = 0;
        wait (dut.init_done == 1'b1); ms(5);
        $display("---- arranque terminado a los %0d ms", $time / 1000000);
        show = 1;

        $display("---- OPLL 1) canal 0: piano, vol 0, F-num 289 bloque 4 (A4), key on");
        opll(8'h30, 8'h30); opll(8'h10, 8'h21); opll(8'h20, 8'h19); ms(60);
        $display("---- OPLL 2) key off / key on en el mismo frame: relanza");
        opll(8'h20, 8'h09); opll(8'h20, 8'h19); ms(40);
        $display("---- OPLL 3) key off");
        opll(8'h20, 8'h09); ms(40);
        $display("---- OPLL 4) ritmo: bombo y caja");
        opll(8'h36, 8'h02); opll(8'h37, 8'h04); opll(8'h0E, 8'h20); opll(8'h0E, 8'h38); ms(40);
        opll(8'h0E, 8'h20); ms(40);

        $display("---- OPLL 5) instrumento de usuario tipo bajo (percusivo, MULT 1/1) -> Finger Bass");
        opll(8'h00, 8'h01); opll(8'h01, 8'h01); opll(8'h02, 8'h18); opll(8'h03, 8'h02);
        opll(8'h04, 8'hF4); opll(8'h05, 8'hF5); opll(8'h06, 8'h44); opll(8'h07, 8'h45);
        opll(8'h31, 8'h00); opll(8'h11, 8'h21); opll(8'h21, 8'h15); ms(40);
        opll(8'h21, 8'h05); ms(40);
        $display("---- OPLL 6) usuario sostenido, modulación débil, con vibrato -> Flute + CC1");
        opll(8'h00, 8'h61); opll(8'h01, 8'h61); opll(8'h02, 8'h30); opll(8'h03, 8'h00);
        opll(8'h04, 8'hD2); opll(8'h05, 8'hC2); opll(8'h06, 8'h12); opll(8'h07, 8'h13);
        opll(8'h21, 8'h19); ms(40);
        opll(8'h21, 8'h09); ms(40);
        $display("---- OPLL 7) usuario sostenido, modulación fuerte y feedback 7 -> Saw Lead");
        opll(8'h00, 8'h21); opll(8'h01, 8'h21); opll(8'h02, 8'h08); opll(8'h03, 8'h07);
        opll(8'h04, 8'hF2); opll(8'h05, 8'hF2);
        opll(8'h21, 8'h19); ms(40);
        opll(8'h21, 8'h09); ms(40);
        $display("---- OPLL 8) patch con AR del portador 0 (silencio): no suena");
        opll(8'h05, 8'h02); opll(8'h21, 8'h19); ms(40);
        opll(8'h21, 8'h09); ms(40);

        $display("---- OPLL 9) nota por debajo del rango MIDI (F-num 64, bloque 0): se sube una octava");
        opll(8'h05, 8'hF2); opll(8'h32, 8'h30); opll(8'h12, 8'h40); opll(8'h22, 8'h10); ms(40);
        opll(8'h22, 8'h00); ms(40);

        $display("---- fin");
        $finish;
    end
endmodule
