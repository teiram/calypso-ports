module sync_normalizer(
    input clk,
    input [31:0] clk_rate, 
    input sync_in,
    output reg sync_out = 1'b0);

parameter [7:0] SYNC_LENGTH_US = 192;
parameter [7:0] CLK_RATE_MHZ = 12;


localparam [11:0] PULSE_TICKS = CLK_RATE_MHZ * SYNC_LENGTH_US;

reg [11:0] sync_duration;
reg sync_ff;
always @(posedge clk) begin
    sync_ff <= sync_in;
    if (~sync_ff & sync_in) begin
        sync_out <= 1'b1;
        sync_duration <= 12'd0;
    end 
    if (sync_out == 1'b1) begin
        sync_duration <= sync_duration + 12'd1;
        if (sync_duration == PULSE_TICKS) sync_out <= 1'b0;
    end
end

endmodule
