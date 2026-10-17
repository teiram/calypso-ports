// Comprueba que tx_byte/tx_stb (para user_io de la Calypso) repite exactamente lo que sale por midi_tx.
`timescale 1ns/1ps
module tb_txbyte;
    localparam integer CLK_HZ = 4000000;
    localparam real TCLK = 1.0e9 / CLK_HZ, TBIT = 1.0e9 / 31250;
    reg clk = 0, reset = 1; always #(TCLK/2) clk = ~clk;
    reg psg_wr = 0, psg_a0 = 0; reg [7:0] psg_d = 0;
    wire midi_tx, active, tx_stb; wire [7:0] tx_byte, dbi;
    msx2midi #(.CLK_HZ(CLK_HZ)) dut (.clk(clk), .reset(reset), .psg_en(1'b1), .opll_en(1'b0),
        .ext_en(1'b0), .stable_n(2'd0), .psg_thr(2'd2), .mpac_en(1'b0),
        .psg_wr(psg_wr), .psg_a0(psg_a0), .psg_d(psg_d), .opll_wr(1'b0), .opll_a0(1'b0), .opll_d(8'd0),
        .ext_rx(1'b1), .midi_tx(midi_tx), .active(active), .mpac_dbi(dbi), .tx_byte(tx_byte), .tx_stb(tx_stb));
    task psg(input [3:0] rg, input [7:0] v); begin
        @(negedge clk); psg_a0 = 0; psg_d = rg; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0; repeat (10) @(negedge clk);
        psg_a0 = 1; psg_d = v; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0; repeat (10) @(negedge clk); end endtask
    reg [7:0] q [0:1023]; integer wp = 0, rp = 0, nok = 0, nbad = 0;
    always @(posedge clk) if (tx_stb) begin q[wp] = tx_byte; wp = wp + 1; end
    reg [7:0] rx; integer k;
    initial forever begin
        @(negedge midi_tx); #(TBIT * 1.5);
        for (k = 0; k < 8; k = k + 1) begin rx[k] = midi_tx; #(TBIT); end
        if (rp < wp && q[rp] == rx) nok = nok + 1; else nbad = nbad + 1;
        rp = rp + 1;
    end
    initial begin
        repeat (20) @(posedge clk); reset = 0;
        wait (dut.init_done); #(5000000.0);
        psg(0, 254); psg(1, 0); psg(8, 15); psg(7, 8'hBE); #(60000000.0);
        psg(8, 0); #(60000000.0);
        $display("bytes por tx_stb: %0d, por la UART: %0d, iguales: %0d, distintos: %0d", wp, rp, nok, nbad);
        $finish;
    end
endmodule
