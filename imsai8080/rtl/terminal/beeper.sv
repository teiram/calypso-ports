module beeper (
    input clk,
    input trigger,
    output reg signed [15:0] audio
);

parameter CLK_HZ = 36000000;
parameter AUDIO_HZ = 1000;

localparam CNT_MAX = CLK_HZ / AUDIO_HZ;

reg [7:0] audio_ptr;
reg enabled = 1'd0;
wire signed[15:0] audio_lo = 16'b1_110000000000000;
wire signed[15:0] audio_hi = 16'b0_001111111111111;

always @(posedge clk) begin
    reg [15:0] cnt = 'd0;
    reg toggle = 'd0;
    
    if (trigger == 1'b1) begin
        audio_ptr <= 'd0;
        enabled <= 1'b1;
    end
    
    cnt <= cnt + 1'd1;
    if (cnt == CNT_MAX) begin
        cnt <= 'd0;
        toggle <= ~toggle;
        audio <= enabled ?
            toggle ? audio_lo : audio_hi :
            16'd0;
        if (audio_ptr == 8'hff) enabled <= 1'b0;
        else audio_ptr <= audio_ptr + 1'd1;
    end
end

endmodule