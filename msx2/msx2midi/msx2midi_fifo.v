// FIFO pequeña con lectura combinacional (dout = siguiente dato, pop lo consume)
module msx2midi_fifo #(
    parameter integer W  = 26,
    parameter integer AW = 4          // profundidad 2^AW
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         push,
    input  wire [W-1:0] din,
    input  wire         pop,
    output wire [W-1:0] dout,
    output wire         empty,
    output wire         full,
    output wire [AW:0]  level
);
    reg [W-1:0] mem [0:(1<<AW)-1];
    reg [AW-1:0] wp, rp;
    reg [AW:0]   cnt;
    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    assign dout  = mem[rp];
    assign empty = (cnt == 0);
    assign full  = (cnt == (1 << AW));
    assign level = cnt;

    always @(posedge clk) begin
        if (do_push) mem[wp] <= din;
        if (rst) begin
            wp <= 0; rp <= 0; cnt <= 0;
        end else begin
            if (do_push) wp <= wp + 1'd1;
            if (do_pop)  rp <= rp + 1'd1;
            cnt <= cnt + (do_push ? 1'd1 : 1'd0) - (do_pop ? 1'd1 : 1'd0);
        end
    end
endmodule
