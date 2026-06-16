module vga(
    input clk36m,
    input reset,
    input clkref,
    
    output reg [10:0] col = 'd0,
    output reg [9:0] row = 'd0,
    output reg hsync = 'd0,
    output reg vsync = 'd0,
    output reg hblank = 'd1,
    output reg vblank = 'd1
);


always @(posedge clk36m) begin
    reg resync = 1'b0;
    reg clkref_last = 1'b0;
    clkref_last <= clkref;
    if (reset == 1'b1) begin
        col <= 11'd0;
        row <= 10'd0;
        hsync <= 1'b0;
        vsync <= 1'b0;
        hblank <= 1'b0;
        vblank <= 1'b0;
        resync <= 1'b1;
    end
    else if (resync == 1'b1) begin
        // To force col and memory accesses to be aligned in a deterministic way
        if (~clkref_last & clkref) resync <= 1'b0;
    end
    else begin
        if (col == 11'd1023) begin
            col <= 11'd0;
            if (row == 10'd624) begin
                row <= 10'd0;
            end
            else begin
                row <= row + 1'b1;
            end
        end
        else begin
            col <= col + 1'b1;
        end

        if (col > 11'd824 && col < 11'd896) hsync <= 1'b1;
        else hsync <= 1'b0;

        if (col > 11'd800) hblank <= 1'b1;
        else hblank <= 1'b0;

        if (row > 10'd600) vblank <= 1'b1;  
        else vblank <= 1'b0;

        if (row > 10'd603 && row < 10'd606) vsync <= 1'b1;
        else vsync <= 1'b0;
    end

end



endmodule