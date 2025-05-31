module brom(
    input clk,
    input [12:0] a,
    inout [7:0] d,
    input rd_n
);

wire [7:0] dout;

assign d = ~rd_n ? dout : 'z;

rom rom(
    .clock(clk),
    .address(a),
    .q(dout)
);

endmodule
