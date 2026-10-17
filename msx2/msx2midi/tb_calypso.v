// Configuración de la Calypso: EXPR_CC=7, PANIC=0, KEEPALIVE_MS=300. Una nota sostenida 1,5 s
// debe mantenerse (FEh periódicos), el volumen va por CC7 y no sale ningún CC123 al callar.
`timescale 1ns/1ps
module tb_calypso;
    localparam integer CLK_HZ = 4000000;
    localparam real TCLK = 1.0e9 / CLK_HZ;
    reg clk = 0, reset = 1; always #(TCLK/2) clk = ~clk;
    reg psg_wr = 0, psg_a0 = 0; reg [7:0] psg_d = 0;
    wire midi_tx, active, tx_stb; wire [7:0] tx_byte, dbi;
    msx2midi #(.CLK_HZ(CLK_HZ), .EXPR_CC(7), .PANIC(2), .KEEPALIVE_MS(300), .RUNNING_STATUS(1), .QUIET_ANO_MS(1500), .BEND_HZ(50)) dut (
        .clk(clk), .reset(reset), .psg_en(1'b1), .opll_en(1'b1), .ext_en(1'b0), .stable_n(2'd0),
        .psg_thr(2'd2), .mpac_en(1'b0), .psg_wr(psg_wr), .psg_a0(psg_a0), .psg_d(psg_d),
        .opll_wr(1'b0), .opll_a0(1'b0), .opll_d(8'd0), .ext_rx(1'b1),
        .midi_tx(midi_tx), .active(active), .mpac_dbi(dbi), .tx_byte(tx_byte), .tx_stb(tx_stb));
    task psg(input [3:0] rg, input [7:0] v); begin
        @(negedge clk); psg_a0 = 0; psg_d = rg; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0; repeat (10) @(negedge clk);
        psg_a0 = 1; psg_d = v; psg_wr = 1; repeat (4) @(negedge clk); psg_wr = 0; repeat (10) @(negedge clk); end endtask
    // decodificador sobre tx_byte (lo que recibe la MCU)
    reg show = 0; reg [7:0] m [0:2]; integer mi = 0, need = 0, nfe = 0, ncc11 = 0, ncc123 = 0;
    always @(posedge clk) if (tx_stb && show) begin
        if (tx_byte == 8'hFE) begin nfe = nfe + 1; $display("%0d ms  FE (active sensing)", $time/1000000); end
        else begin
            if (tx_byte[7]) begin mi = 0; need = (tx_byte[7:4] == 4'hC) ? 2 : 3; m[0] = tx_byte; mi = 1; end
            else begin if (mi == 0) begin mi = 1; $display("%0d ms  (running status %02h)", $time/1000000, m[0]); end m[mi] = tx_byte; mi = mi + 1; end
            if (mi == need) begin
                if (m[0][7:4] == 4'hB) begin
                    $display("%0d ms  ch%0d CC%0d = %0d", $time/1000000, m[0][3:0]+1, m[1], m[2]);
                    if (m[1] == 11) ncc11 = ncc11 + 1;
                    if (m[1] == 123) ncc123 = ncc123 + 1;
                end else if (m[0][7:4] == 4'h9) $display("%0d ms  ch%0d NOTE ON  %0d", $time/1000000, m[0][3:0]+1, m[1]);
                else if (m[0][7:4] == 4'h8) $display("%0d ms  ch%0d NOTE OFF %0d", $time/1000000, m[0][3:0]+1, m[1]);
                mi = 0;
            end
        end
    end
    integer nbytes = 0; always @(posedge clk) if (tx_stb && show) nbytes = nbytes + 1;
    initial begin
        repeat (20) @(posedge clk); reset = 0;
        wait (dut.init_done); #(5000000.0); show = 1;
        $display("---- nota A4 sostenida 0,7 s a volumen 15, luego volumen 10, luego silencio 1,8 s");
        psg(0, 254); psg(1, 0); psg(8, 15); psg(7, 8'hBE); #(700000000.0);
        psg(8, 10); #(100000000.0);
        psg(8, 0); #(1800000000.0);
        $display("---- FE: %0d   CC11: %0d (debe ser 0)   CC123: %0d   bytes: %0d", nfe, ncc11, ncc123, nbytes);
        $finish;
    end
endmodule
