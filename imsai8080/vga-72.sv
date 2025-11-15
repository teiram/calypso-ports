module vga(
    input clk50m,
    input reset,

    output reg [10:0] col,
    output reg [9:0] row,
    output reg hsync,
    output reg vsync,
    output reg hblank,
    output reg vblank
);

always @(posedge clk50m) begin
    if (reset == 1'b1) begin
        col <= 11'd0;
        row <= 10'd0;
    end
    else begin
        if (col == 11'd1055) begin
            col <= 11'd0;
            if (row == 10'd627) begin
                row <= 10'd0;
            end
            else begin
                row <= row + 1'b1;
            end
        end
        else begin
            col <= col + 1'b1;
        end

        if (col > 11'd927) hsync <= 1'b0;
        else hsync <= 1'b1;

        if ((col < 11'd39) || (col > 11'd838)) hblank <= 1'b1;
        else hblank <= 1'b0;

        if ((row < 10'd23) || (row > 10'd622)) vblank <= 1'b1;  
        else vblank <= 1'b0;

        if (row > 10'd624) vsync <= 1'b0;
        else vsync <= 1'b1;
    end

end



endmodule