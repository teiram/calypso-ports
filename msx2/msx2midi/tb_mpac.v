// Testbench de la interfaz MIDI-PAC de msx2midi: reproduce las rutinas Z80 de
// MIDIPLAY.COM / MPSTATUS.COM (detección, sincronización, versión, ID, modo y MIDI
// directo con EDh/EEh) y decodifica el MIDI que sale.
//   iverilog -o tbm tb_mpac.v msx2midi.v psg2midi_conv.v opll2midi_conv.v opll_patch_class.v \
//            msx2midi_fifo.v psg2midi_pitch_rom.v opll2midi_fnum_rom.v && vvp tbm
`timescale 1ns/1ps
module tb_mpac;
    localparam integer CLK_HZ = 4000000;
    localparam real    TCLK   = 1.0e9 / CLK_HZ;
    localparam real    TBIT   = 1.0e9 / 31250;

    reg clk = 0, reset = 1;
    reg opll_wr = 0, opll_a0 = 0; reg [7:0] opll_d = 0;
    wire midi_tx, active;
    wire [7:0] st;                     // lo que lee la CPU en 7Ch
    always #(TCLK/2) clk = ~clk;

    msx2midi #(.CLK_HZ(CLK_HZ)) dut (
        .clk(clk), .reset(reset), .psg_en(1'b0), .opll_en(1'b1), .ext_en(1'b0),
        .stable_n(2'd0), .psg_thr(2'd2), .mpac_en(1'b1),
        .psg_wr(1'b0), .psg_a0(1'b0), .psg_d(8'd0),
        .opll_wr(opll_wr), .opll_a0(opll_a0), .opll_d(opll_d),
        .ext_rx(1'b1), .midi_tx(midi_tx), .active(active), .mpac_dbi(st));

    task out7c(input [7:0] v); begin
        @(negedge clk); opll_a0 = 0; opll_d = v; opll_wr = 1; repeat (3) @(negedge clk); opll_wr = 0;
        repeat (8) @(negedge clk); end endtask
    task out7d(input [7:0] v); begin
        @(negedge clk); opll_a0 = 1; opll_d = v; opll_wr = 1; repeat (3) @(negedge clk); opll_wr = 0;
        repeat (8) @(negedge clk); end endtask
    // como sub_1d27h: escribe 7Dh y espera a que cambie el bit 1 (ack); 1 = ok
    task out7d_ack(input [7:0] v, output ok);
        reg b; integer t;
        begin
            b = st[1]; out7d(v); ok = 0;
            for (t = 0; t < 10000 && !ok; t = t + 1) begin if (st[1] != b) ok = 1; @(negedge clk); end
        end
    endtask
    // como sub_1dcah / sub_1e1eh: lee 4 bytes con FEh, sel = 40h (ID) o 20h (versión)
    task read32(input [7:0] sel, output [31:0] w);
        integer i, b; reg ok; reg [7:0] d [0:3];
        begin
            d[0] = 8'h17; d[1] = 8'h0F; d[2] = 8'h07; d[3] = 8'hFF;
            out7c(8'hFE); w = 0;
            for (i = 0; i < 4; i = i + 1)
                for (b = 8; b >= 1; b = b - 1) begin
                    out7d_ack(((d[i] + b) & 8'hFF) | sel, ok);
                    w = {w[30:0], st[0]};
                end
        end
    endtask

    // ---- decodificador MIDI ----
    reg [7:0] rx; integer k;
    initial forever begin
        @(negedge midi_tx); #(TBIT * 1.5);
        for (k = 0; k < 8; k = k + 1) begin rx[k] = midi_tx; #(TBIT); end
        if (dut.init_done) $display("%0d ms  MIDI %02h", $time / 1000000, rx);
    end

    integer i; reg ok; reg c; reg [31:0] w; reg [2:0] mode;
    initial begin
        repeat (20) @(posedge clk); reset = 0;
        wait (dut.init_done == 1'b1); #(5000000.0);

        $display("---- Detección (sub_1d75h)");
        c = ~st[2]; out7c(8'hF5); ok = (st[2] == c);
        c = ~st[3]; out7d(8'hFF); ok = ok && (st[3] == c);
        $display("     MIDI-PAC %s", ok ? "encontrado" : "NO encontrado");

        $display("---- Sincronización (sub_1d9dh): 16 x FFh/FFh con ack");
        for (i = 0; i < 16; i = i + 1) begin out7c(8'hFF); out7d_ack(8'hFF, ok); if (!ok) $display("     timeout"); end
        $display("     ok");

        read32(8'h40, w);
        $display("---- ID (FEh, 40h|n): \"%s\"", w);
        read32(8'h20, w);
        $display("---- Versión (FEh, 20h|n): \"%s\"", w);
        out7c(8'hFE); mode = 0;
        for (i = 3; i >= 1; i = i - 1) begin out7d_ack((8'hFF + i) & 8'hFF, ok); mode = {mode[1:0], st[0]}; end
        $display("---- Modo (FEh, 02h..00h): %b (bit2 = aplicación, bit1 = MPC correcto)", mode);

        $display("---- Modo directo: ED 1, Note On 60, running status 64, Note Off, ED 0");
        out7c(8'hED); out7d_ack(8'h01, ok);
        // mientras tanto el juego escribe en el OPLL: no debe salir nada del conversor
        out7c(8'h30); out7d(8'h30); out7c(8'h10); out7d(8'h21); out7c(8'h20); out7d(8'h19);
        begin : envio
            reg [7:0] msg [0:6]; integer j;
            msg[0] = 8'h90; msg[1] = 8'd60; msg[2] = 8'd100; msg[3] = 8'd64; msg[4] = 8'd90;
            msg[5] = 8'd60; msg[6] = 8'd0;
            for (j = 0; j < 7; j = j + 1) begin
                while (st[0]) @(negedge clk);           // l0118h: esperar a que no esté ocupado
                out7c(8'hEE); out7d_ack(msg[j], ok);
            end
        end
        #(20000000.0);
        out7c(8'hED); out7d_ack(8'h00, ok);
        out7c(8'h20); out7d(8'h09);                     // key off del canal 0 del OPLL
        #(60000000.0);
        $display("---- fin");
        $finish;
    end
endmodule
