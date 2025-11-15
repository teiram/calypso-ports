module panel(
    input clk36m,
    input reset,

    input [10:0] col,
    input [9:0] row,
    input hblank,
    input vblank,
    output reg [16:2] ram_addr /* synthesis keep */, //32 bit address
    input [31:0] ram_value,     //8 pixels (4 bits per pixel)
    
    input [43:0] leds,
    input [10:0] ps2_key,
    
    output reg [3:0] r,
    output reg [3:0] g,
    output reg [3:0] b
);

// GIMP Palette, divide by 16
// 00,00,00  
// 01,02,11
// 01,0A,46
// 43,02,03
// 00,0F,7E
// 68,00,01
// B6,00,00
// 2C,2E,2C
// 4F,51,4F
// 79,7C,79
// 86,88,85
// 95,97,94
// A2,A4,A1
// AF,B2,AE
// BE,C1,BD
// FF,FF,FF

//                                        LED OFF
reg [3:0] red[16]   = '{4'h0, 4'h0, 4'h0, 4'h4, 4'h0, 4'h6, 4'hb, 4'h2, 4'h4, 4'h7, 4'h8, 4'h9, 4'ha, 4'ha, 4'hb, 4'hf};
reg [3:0] green[16] = '{4'h0, 4'h0, 4'h0, 4'h0, 4'h0, 4'h0, 4'h0, 4'h2, 4'h5, 4'h7, 4'h8, 4'h9, 4'ha, 4'hb, 4'hc, 4'hf};
reg [3:0] blue[16]  = '{4'h0, 4'h1, 4'h4, 4'h0, 4'h7, 4'h0, 4'h0, 4'h2, 4'h4, 4'h7, 4'h8, 4'h9, 4'ha, 4'ha, 4'hb, 4'hf};

reg [11:0] led_cols[20] = '{
    11'd37, 11'd68, 11'd99, 11'd130, 11'd161, 11'd191, 11'd222, 11'd253,
    11'd313, 11'd344, 11'd375, 11'd405, 11'd436, 11'd467, 11'd497, 11'd528, 
    11'd654, 11'd683, 11'd711, 11'd739};
reg [10:0] led_rows[3] = '{11'd38, 11'd89, 11'd140};

reg [4:0] led_index_cols[44] = '{
    5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7,
    5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15, 
    5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15,
    5'd16, 5'd17, 5'd18, 5'd19};

reg [1:0] led_index_rows[44] = '{
    2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0,
    2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1,
    2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 
    2'd2, 2'd2, 2'd2, 2'd2};

localparam LED_WIDTH = 32;
localparam LED_HEIGHT = 16;
localparam LED_COUNT = 44;

reg [31:0] pixel_value = 32'd0;

wire [3:0] pixel_values[8] = '{
    pixel_value[7:4],
    pixel_value[3:0],
    pixel_value[15:12],
    pixel_value[11:8],
    pixel_value[23:20],
    pixel_value[19:16],
    pixel_value[31:28],
    pixel_value[27:24]
};

integer led_index;

always @(posedge clk36m) begin
    if (row == 11'd624) begin
        ram_addr <= 15'd0;
    end
    if (row == 11'd624 && col == 11'd1020) begin
        pixel_value <= ram_value;
    end
    
    else if (~vblank & ~hblank & row < 10'd240) begin
        if (col[2:0] == 3'd0) begin
            ram_addr <= ram_addr + 15'd1;
        end else if (col[2:0] == 3'd7) begin
            pixel_value <= ram_value;
        end
        r <= red[pixel_values[col[2:0]]];
        g <= green[pixel_values[col[2:0]]];
        b <= blue[pixel_values[col[2:0]]];
        for (led_index = 0; led_index < LED_COUNT; led_index = led_index + 1) begin
            if (col > led_cols[led_index_cols[led_index]] && 
                col < led_cols[led_index_cols[led_index]] + LED_WIDTH &&
                row > led_rows[led_index_rows[led_index]] &&
                row < led_rows[led_index_rows[led_index]] + LED_HEIGHT &&
                leds[led_index] == 1'b1 &&
                pixel_values[col[2:0]] == 4'd3) begin
                r <= 4'hf;
                g <= 4'h0;
                b <= 4'h0;
            end
        end
    end
    else begin
        r <= 4'd0;
        g <= 4'd0;
        b <= 4'd0;
    end
end


endmodule