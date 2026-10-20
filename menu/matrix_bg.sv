// matrix_bg.sv - "Digital rain" background for the Calypso Menu core
// Shaeon (Carlos Palmero), 2026
//
// Columns of green glyphs falling on a black background, with a bright head
// and a fading trail. Each column has its own speed, phase and trail length
// from a small hash; the glyphs keep changing while they fall. The glyphs
// are 5x7 katakana-like shapes, drawn mirrored. No memory is used apart from
// a tiny glyph table.

`default_nettype none

module matrix_bg (
    input  wire        clk,               // pixel clock
    input  wire  [9:0] hc,
    input  wire  [8:0] vc,
    input  wire [15:0] frame,             // frame counter
    output reg   [7:0] r,
    output reg   [7:0] g,
    output reg   [7:0] b
);

// 5x7 glyphs, row 0 at the top, bit 4 = leftmost pixel
function automatic [4:0] glyph_row(input [3:0] code, input [2:0] row);
    reg [34:0] gl;
    begin
        case (code)
            4'd0:  gl = {5'b11111, 5'b00001, 5'b00110, 5'b00100, 5'b00100, 5'b01000, 5'b00000};
            4'd1:  gl = {5'b00001, 5'b00010, 5'b00100, 5'b01100, 5'b10100, 5'b00100, 5'b00100};
            4'd2:  gl = {5'b00100, 5'b11111, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000};
            4'd3:  gl = {5'b00000, 5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b11111, 5'b00000};
            4'd4:  gl = {5'b00010, 5'b11111, 5'b00110, 5'b01010, 5'b10010, 5'b00010, 5'b00110};
            4'd5:  gl = {5'b01000, 5'b11111, 5'b01001, 5'b01001, 5'b01001, 5'b10001, 5'b10110};
            4'd6:  gl = {5'b01000, 5'b11111, 5'b00100, 5'b11111, 5'b00010, 5'b00010, 5'b00010};
            4'd7:  gl = {5'b01000, 5'b01111, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000};
            4'd8:  gl = {5'b01010, 5'b11111, 5'b01010, 5'b01010, 5'b00010, 5'b00100, 5'b01000};
            4'd9:  gl = {5'b11000, 5'b00001, 5'b11001, 5'b00001, 5'b00010, 5'b00100, 5'b11000};
            4'd10: gl = {5'b01110, 5'b00000, 5'b11111, 5'b00100, 5'b00100, 5'b01000, 5'b10000};
            4'd11: gl = {5'b01000, 5'b01000, 5'b01100, 5'b01010, 5'b01000, 5'b01000, 5'b01000};
            4'd12: gl = {5'b00000, 5'b01010, 5'b01010, 5'b10001, 5'b10001, 5'b10001, 5'b00000};
            4'd13: gl = {5'b11110, 5'b00001, 5'b00000, 5'b11110, 5'b00001, 5'b00000, 5'b11111};
            4'd14: gl = {5'b01110, 5'b10001, 5'b10011, 5'b10101, 5'b11001, 5'b10001, 5'b01110};
            default: gl = {5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b01000};
        endcase
        glyph_row = gl[34 - row * 5 -: 5];
    end
endfunction

function automatic [11:0] hash(input [11:0] c);
    reg [11:0] k;
    reg [23:0] m;
    begin
        k    = c ^ {c[6:0], 5'b0} ^ 12'h5A3;
        m    = {12'd0, k} * 24'd40503;
        hash = m[19:8] ^ {m[23:20], m[7:0]};
    end
endfunction

// cell = 8 pixels x 10 lines
reg [7:0] green;
reg       head;

always @(*) begin
    reg  [6:0] col;
    reg  [4:0] row;
    reg  [3:0] gy;
    reg  [2:0] gx;
    reg [11:0] hc_col, hc_cell;
    reg  [3:0] speed;
    reg [19:0] pos;
    reg  [5:0] headrow, dst;
    reg  [4:0] trail;
    reg [11:0] epoch;
    reg [15:0] cnt;
    reg  [3:0] code;
    reg  [4:0] bits;
    reg        on;
    reg [17:0] vmul;
    reg  [8:0] fade;

    col   = hc[9:3];
    vmul  = ({9'd0, vc} * 18'd205) >> 11;          // vc / 10 (exact for vc < 1029)
    row   = vmul[4:0];
    gy    = vc - row * 4'd10;
    gx    = hc[2:0];

    // per column: speed (rows per 16 frames), phase and trail length
    hc_col  = hash({5'd0, col});
    speed   = 4'd3 + {1'b0, hc_col[2:0]};          // 3..10 rows per 32 frames
    pos     = frame * speed + {hc_col[11:4], 5'b0};
    headrow = pos[10:5];                            // 64-row cycle
    dst    = headrow - {1'b0, row};
    trail   = 5'd12 + {2'b0, hc_col[5:3]};

    // glyph of the cell: every cell keeps changing at its own pace (every
    // 8 to 64 frames, with its own phase) and the head changes faster
    hc_cell = hash({col, row} ^ 12'hC3A);
    cnt     = frame + {hc_cell[11:6], 4'd0};
    case (hc_cell[1:0])
        2'd0:    epoch = cnt[14:3];
        2'd1:    epoch = {1'b0, cnt[15:5]};
        2'd2:    epoch = {2'b0, cnt[15:6]};
        default: epoch = {1'b0, cnt[15:4], 1'b0} >> 1;
    endcase
    if (dst == 6'd0) epoch = {1'b0, frame[13:3]} ^ 12'h5A5;
    code    = hash(hc_cell ^ epoch);

    // glyph 5x7 at x 1..5, lines 1..7 of the cell, drawn mirrored
    bits = glyph_row(code, gy[2:0] - 3'd1);
    on   = (gx >= 3'd1 && gx <= 3'd5 && gy >= 4'd1 && gy <= 4'd7) ? bits[gx - 3'd1] : 1'b0;

    head  = 1'b0;
    green = 8'd0;
    fade  = 9'd0;
    if (on && dst < {1'b0, trail}) begin
        if (dst == 6'd0) begin
            head  = 1'b1;
            green = 8'd255;
        end else begin
            fade  = 9'd250 - {dst, 3'b0} - {1'b0, dst, 2'b0};   // 250 - 12*dst
            green = (fade[8] || fade < 9'd24) ? 8'd24 : fade[7:0];
        end
    end
end

always @(posedge clk) begin
    if (head) begin
        r <= 8'd190; g <= 8'd255; b <= 8'd200;
    end else begin
        r <= {2'b0, green[7:2]};
        g <= green;
        b <= {1'b0, green[7:1]} >> 1;
    end
end

endmodule
