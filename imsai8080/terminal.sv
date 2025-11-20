module terminal(
    input clk36m,
    input reset,

    input [10:0] col,
    input [9:0] row /* synthesis keep */,
    input hblank,
    input vblank,
    
    input key_pressed,
    input [7:0] key_code,
    input key_strobe,
    input key_extended,
    
    output reg vout /* synthesis keep */
);


reg [10:0] video_addr /* synthesis keep */;
reg [10:0] char_addr /* synthesis keep */;
wire [7:0] char_code /* synthesis keep */;
wire [7:0] video_val /* synthesis keep */;
reg [7:0] pixels /* synthesis keep */;

font_rom font(
    .clock(clk36m),
    .address(char_addr),
    .q(video_val)
);

videoram ram(
    .clock(clk36m),
    .wren(1'b0),
    .data(),
    .address(video_addr),
    .q(char_code)
);

wire [9:0] vrow /* synthesis keep */= row - 10'd80;

always @(posedge clk36m) begin
    if (row >= 9'd80 && row < 9'd280) begin
        if (col < 12'd80) begin
            video_addr <= vrow[9:3] * 7'd80;
            if (col[2:0] == 3'd1) begin
                char_addr <= {char_code, row[2:0]};
            end else if (col[2:0] == 3'd7) begin
                pixels <= video_val;
            end
            vout <= 1'b0;
        end else if (col < 11'd720) begin
            pixels <= {pixels[6:0], 1'b0};
            vout <= pixels[7];
            if (col[2:0] == 3'd1) begin
                video_addr <= video_addr + 1'd1;
            end else if (col[2:0] == 3'd4) begin
                char_addr <= {char_code, row[2:0]};
            end else if (col[2:0] == 3'd7) begin
                pixels <= video_val;
            end
        end else begin
            vout <= 1'b0;
        end
    end else begin
        video_addr <= 'd0;
        vout <= 1'b0;
    end
end

always @(posedge clk36m) begin

end



endmodule
