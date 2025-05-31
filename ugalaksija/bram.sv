module bram(
    input clk,
    input [12:0] a,
    inout [7:0] d,
    input we_n,
    input rd_n
);

wire [7:0] din;
wire [7:0] dout;

assign d = ~rd_n ? dout : 'z;
assign din = ~we_n ? d : 8'h00;

ram ram(
    .clock(clk),
    .address(a),
    .data(din),
    .q(dout),
    .wren(~we_n)
);

endmodule
