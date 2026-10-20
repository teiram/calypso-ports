// lcd_clock.sv - LCD style clock for the Calypso Menu core
// Shaeon (Carlos Palmero), 2026
//
// Draws an LCD style panel over the menu background with the date in small
// digits (DD-MM-YYYY, MM-DD-YYYY or YYYY-MM-DD) and the time in big digits
// (HH:MM, smaller seconds), at 1x or 2x size,
// using the time the firmware sends to the core every second through
// user_io (rtc[63:0], BCD: sec, min, hour, day, month, year, weekday, 0x40).
//
// The bottom and top positions keep the OSD area free in PAL mode
// (128-line OSD, centered).
//
// The panel is only shown while there is an RTC: the flag byte is 0x40 and
// the seconds keep changing (it is hidden if they stop for 3 s).

`default_nettype none

module lcd_clock #(
    parameter int CLK_HZ  = 12_500_000    // pixel clock
) (
    input  wire        clk,               // pixel clock
    input  wire  [9:0] hc,                // 0..639 visible
    input  wire  [8:0] vc,
    input  wire  [8:0] line_max,          // 312 PAL / 262 NTSC
    input  wire [63:0] rtc,               // from user_io
    input  wire        enable,            // clock on/off
    input  wire  [1:0] vpos,              // 0 bottom, 1 top, 2 center
    input  wire  [1:0] hpos,              // 0 center, 1 left, 2 right
    input  wire  [2:0] palette,           // color scheme, see below
    input  wire        size,              // 0 = 1x, 1 = 2x (every pixel doubled)
    input  wire  [1:0] datefmt,           // 0 DD-MM-YYYY, 1 MM-DD-YYYY, 2 YYYY-MM-DD
    input  wire        pointed,           // 0 flat segments, 1 pointed <=> segments
    input  wire  [1:0] weekday,           // 0 off, 1 English, 2 Spanish
    input  wire        no_panel,          // 1 = only the digits, over the background
    input  wire        no_shadow,         // 1 = hide the unlit segments

    output reg         active,            // pixel belongs to the clock
    output reg   [1:0] alpha,             // 3 opaque, 1 translucent shadow (25%)
    output reg   [7:0] r,
    output reg   [7:0] g,
    output reg   [7:0] b
);

// ---------------------------------------------------------------------------
// RTC detection and colon blinking
// ---------------------------------------------------------------------------
reg [63:0] rtc_m = 64'd0, rtc_s = 64'd0;  // clock domain crossing (clk_x2 -> clk_pix)
reg  [7:0] last_sec = 8'd0;
reg [26:0] since_change = 27'd0;
reg        seen = 1'b0;

always @(posedge clk) begin
    rtc_m <= rtc;
    rtc_s <= rtc_m;
    if (rtc_s[63:56] == 8'h40 && rtc_s[7:0] != last_sec) begin
        last_sec     <= rtc_s[7:0];
        since_change <= 27'd0;
        seen         <= 1'b1;
    end else if (since_change != {27{1'b1}}) begin
        since_change <= since_change + 27'd1;
    end
end

wire rtc_valid = seen && (rtc_s[63:56] == 8'h40) && (since_change < 3 * CLK_HZ);
wire colon_on  = since_change < CLK_HZ / 2;

// ---------------------------------------------------------------------------
// Layout (1x units). 2x draws exactly the same layout with every pixel and
// line doubled, so all segments keep the same shape at both sizes.
// ---------------------------------------------------------------------------
localparam int PANEL_W = 186, PANEL_H = 44;

// Date (small): 10 characters
localparam int DW = 8,  DH = 11, DTH = 1, DTV = 2, DPITCH = 11;
localparam int DX0 = (PANEL_W - 10 * DPITCH + (DPITCH - DW)) / 2, DY0 = 4;

// Time (big): HH:MM
localparam int TW = 24, TH_ = 23, TTH = 3, TTV = 5, TPITCH = 29;
localparam int HX0 = 16, HX1 = HX0 + TPITCH;
localparam int CX  = HX1 + TW + 4;                 // colon
localparam int MX0 = CX + TTV + 5, MX1 = MX0 + TPITCH;
localparam int TY0 = 17;
// Pointed style: hexagonal segments with 45 degree ends (see hex_hit),
// defined in units of half a 1x pixel/line so 2x is drawn at full
// resolution. Big digits 48x46 units, seconds 28x28 units.
localparam int PW_ = 48, PH_ = 46, PTH = 6, PTV = 10, PG = 2, PGY = 1;
localparam int QW_ = 28, QH_ = 28, QTH = 4, QTV = 6, QG = 2, QGY = 1;

// Seconds (medium), bottom aligned with the big digits
localparam int SW = 12, SH = 16, STH = 2, STV = 3, SPITCH = 15;
localparam int SX0 = MX1 + TW + 6, SX1 = SX0 + SPITCH;
localparam int SY0 = TY0 + TH_ - SH;
localparam int QX0 = MX1 + TW + 6, QX1 = QX0 + 17;   // pointed seconds (14 px)
localparam int QY0 = TY0 + TH_ - QH_ / 2;

// Weekday (3 letters, 5x7) to the left of the date
localparam int WPITCH = 6;
localparam int WX0 = (PANEL_W - (3 * WPITCH - 1) - 7 - (9 * DPITCH + DW)) / 2;
localparam int WDX0 = WX0 + 3 * WPITCH - 1 + 7;     // date start with weekday
localparam int WY0 = DY0 + (DH - 7) / 2;

// ---------------------------------------------------------------------------
// Panel position
// ---------------------------------------------------------------------------
localparam int MARGIN_X = 24;

wire [9:0] PW = size ? PANEL_W[9:0] << 1 : PANEL_W[9:0];
wire [8:0] PH = size ? PANEL_H[8:0] << 1 : PANEL_H[8:0];

reg [9:0] x0;
always @(*) begin
    case (hpos)
        2'd1:    x0 = MARGIN_X[9:0];                           // left
        2'd2:    x0 = 10'd640 - PW - MARGIN_X[9:0];            // right
        default: x0 = (10'd640 - PW) >> 1;                     // center
    endcase
end

reg [8:0] y0;
always @(*) begin
    case (vpos)
        2'd1:    y0 = 9'd4;                                    // top
        2'd2:    y0 = (line_max - PH) >> 1;                    // center
        default: y0 = line_max - PH - 9'd6;                    // bottom
    endcase
end

wire       in_x = (hc >= x0) && (hc < x0 + PW);
wire       in_y = (vc >= y0) && (vc < y0 + PH);
wire [9:0] px   = hc - x0;
wire [8:0] py   = vc - y0;

// coordinates in the 1x layout
wire [9:0] lx   = size ? {1'b0, px[9:1]} : px;
wire [8:0] ly   = size ? {1'b0, py[8:1]} : py;

// ---------------------------------------------------------------------------
// 7-segment digits
// ---------------------------------------------------------------------------
// Segments {g,f,e,d,c,b,a}
function automatic [6:0] seg7(input [3:0] v);
    case (v)
        4'd0: seg7 = 7'b0111111;
        4'd1: seg7 = 7'b0000110;
        4'd2: seg7 = 7'b1011011;
        4'd3: seg7 = 7'b1001111;
        4'd4: seg7 = 7'b1100110;
        4'd5: seg7 = 7'b1101101;
        4'd6: seg7 = 7'b1111101;
        4'd7: seg7 = 7'b0000111;
        4'd8: seg7 = 7'b1111111;
        4'd9: seg7 = 7'b1101111;
        4'hA: seg7 = 7'b1000000;   // dash
        default: seg7 = 7'b0000000;
    endcase
endfunction

// Mask of the segments containing point (x, y), relative to the digit box.
// W/H: size, TH: horizontal segment thickness (lines), TV: vertical segment
// thickness (pixels). H - TH must be even so that the middle segment is
// centered and the upper and lower halves are identical.
//
// Flat segments (P = 0):
//   a: lines [0, TH)            x [1, W-1)
//   g: lines [M, M+TH)          M = (H-TH)/2
//   d: lines [H-TH, H)
//   f/b: lines [1, M)           x [0, TV) / [W-TV, W)
//   e/c: lines [M+TH, H-1)
//
// Pointed segments (P = 1), "<=>" ends as in big LED/LCD clocks: every
// segment runs between the centers of the segments it meets and its ends
// are cut at an angle, so the corners meet in a mitre.

function automatic integer iabs(input integer v);
    iabs = (v < 0) ? -v : v;
endfunction

// pointed horizontal segment with its top line at ys
function automatic hseg(
    input integer x, input integer y, input integer ys,
    input integer W, input integer TH, input integer TV);
    integer hx0, hx1, sh;
    begin
        // between the centers of the vertical segments; the outer lines are
        // shorter, which makes the point (about TV/2 px)
        hx0 = (TV - 1) / 2 + 1;
        hx1 = W - (TV - 1) / 2 - 1;
        sh = (TH > 1) ? (iabs(2 * (y - ys) - (TH - 1)) * TV) / (2 * (TH - 1)) : 0;
        hseg = (y >= ys && y < ys + TH && x >= hx0 + sh && x < hx1 - sh);
    end
endfunction

// pointed vertical segment with its left column at xs, lines [ya, yb)
function automatic vseg(
    input integer x, input integer y, input integer xs,
    input integer ya, input integer yb, input integer TH, input integer TV);
    integer sh;
    begin
        sh = (TV > 1) ? (iabs(2 * (x - xs) - (TV - 1)) * (TH + 1)) / (2 * (TV - 1)) : 0;
        vseg = (x >= xs && x < xs + TV && y >= ya + sh && y < yb - sh);
    end
endfunction

function automatic [6:0] seg_hit(
    input integer x, input integer y,
    input integer W, input integer H,
    input integer TH, input integer TV,
    input integer P);
    integer m, c;
    begin
        seg_hit = 7'd0;
        m = (H - TH) / 2;
        c = (TH - 1) / 2;                      // center line of a horizontal
        if (x >= 0 && x < W && y >= 0 && y < H) begin
            if (P == 0) begin
                if (x >= 1 && x < W - 1) begin
                    if (y < TH)                  seg_hit[0] = 1'b1;   // a
                    if (y >= m && y < m + TH)    seg_hit[6] = 1'b1;   // g
                    if (y >= H - TH)             seg_hit[3] = 1'b1;   // d
                end
                if (x < TV) begin
                    if (y >= 1 && y < m)              seg_hit[5] = 1'b1;  // f
                    if (y >= m + TH && y < H - 1)     seg_hit[4] = 1'b1;  // e
                end
                if (x >= W - TV) begin
                    if (y >= 1 && y < m)              seg_hit[1] = 1'b1;  // b
                    if (y >= m + TH && y < H - 1)     seg_hit[2] = 1'b1;  // c
                end
            end else begin
                seg_hit[0] = hseg(x, y, 0,      W, TH, TV);                      // a
                seg_hit[6] = hseg(x, y, m,      W, TH, TV);                      // g
                seg_hit[3] = hseg(x, y, H - TH, W, TH, TV);                      // d
                seg_hit[5] = vseg(x, y, 0,      c + 1,     m + c,     TH, TV);   // f
                seg_hit[4] = vseg(x, y, 0,      m + c + 1, H - 1 - c, TH, TV);   // e
                seg_hit[1] = vseg(x, y, W - TV, c + 1,     m + c,     TH, TV);   // b
                seg_hit[2] = vseg(x, y, W - TV, m + c + 1, H - 1 - c, TH, TV);   // c
            end
        end
    end
endfunction

// Hexagonal segments. X, Y: sample point in half units relative to the digit
// box (pixel centers are odd). W, H, TH, TV, G (gap at the ends, x) and GY
// (gap, y) in units. The ends are cut at 45 degrees on screen: lines are
// 5/3 taller than pixels are wide.
function automatic [6:0] hex_hit(
    input integer X, input integer Y,
    input integer W, input integer H,
    input integer TH, input integer TV,
    input integer G, input integer GY);
    integer xl, xr, ya, yg, yd, lh, lv, cu, cl, dx, dy;
    begin
        hex_hit = 7'd0;
        xl = TV;  xr = 2 * W - TV;               // centers of the verticals
        ya = TH;  yg = H;  yd = 2 * H - TH;      // centers of the horizontals
        lh = (xr - xl) / 2 - 2 * G;              // half length, horizontal
        lv = (yg - ya) / 2 - 2 * GY;             // half length, vertical
        cu = (ya + yg) / 2;
        cl = (yg + yd) / 2;
        if (X >= 0 && X < 2 * W && Y >= 0 && Y < 2 * H) begin
            dx = iabs(X - W);
            dy = iabs(Y - ya); if (dy < TH && 3 * dx + 5 * dy <= 3 * lh) hex_hit[0] = 1'b1; // a
            dy = iabs(Y - yg); if (dy < TH && 3 * dx + 5 * dy <= 3 * lh) hex_hit[6] = 1'b1; // g
            dy = iabs(Y - yd); if (dy < TH && 3 * dx + 5 * dy <= 3 * lh) hex_hit[3] = 1'b1; // d
            dx = iabs(X - xl);
            dy = iabs(Y - cu); if (dx < TV && 5 * dy + 3 * dx <= 5 * lv) hex_hit[5] = 1'b1; // f
            dy = iabs(Y - cl); if (dx < TV && 5 * dy + 3 * dx <= 5 * lv) hex_hit[4] = 1'b1; // e
            dx = iabs(X - xr);
            dy = iabs(Y - cu); if (dx < TV && 5 * dy + 3 * dx <= 5 * lv) hex_hit[1] = 1'b1; // b
            dy = iabs(Y - cl); if (dx < TV && 5 * dy + 3 * dx <= 5 * lv) hex_hit[2] = 1'b1; // c
        end
    end
endfunction

// 5x7 letters for the weekday, row 0 at the top, bit 4 = leftmost pixel
//   0 A  1 B  2 D  3 E  4 F  5 H  6 I  7 J  8 L  9 M  10 N  11 O
//   12 R  13 S  14 T  15 U  16 V  17 W
function automatic [4:0] letter_row(input [4:0] c, input [2:0] row);
    reg [34:0] gl;
    begin
        case (c)
            5'd0:  gl = {5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001};
            5'd1:  gl = {5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10001, 5'b10001, 5'b11110};
            5'd2:  gl = {5'b11110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b11110};
            5'd3:  gl = {5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111};
            5'd4:  gl = {5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b10000};
            5'd5:  gl = {5'b10001, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001};
            5'd6:  gl = {5'b01110, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110};
            5'd7:  gl = {5'b00111, 5'b00010, 5'b00010, 5'b00010, 5'b00010, 5'b10010, 5'b01100};
            5'd8:  gl = {5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b10000, 5'b11111};
            5'd9:  gl = {5'b10001, 5'b11011, 5'b10101, 5'b10101, 5'b10001, 5'b10001, 5'b10001};
            5'd10: gl = {5'b10001, 5'b11001, 5'b10101, 5'b10011, 5'b10001, 5'b10001, 5'b10001};
            5'd11: gl = {5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110};
            5'd12: gl = {5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001};
            5'd13: gl = {5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110};
            5'd14: gl = {5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100};
            5'd15: gl = {5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110};
            5'd16: gl = {5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01010, 5'b00100};
            5'd17: gl = {5'b10001, 5'b10001, 5'b10001, 5'b10101, 5'b10101, 5'b10101, 5'b01010};
            default: gl = 35'd0;
        endcase
        letter_row = gl[34 - row * 5 -: 5];
    end
endfunction

// Weekday names, 3 letters each. Weekday from the firmware: 0 = Sunday.
function automatic [14:0] day_name(input [2:0] wd, input spanish);
    // letter codes, see letter_row
    localparam [4:0] A=0, B=1, D=2, E=3, F=4, H=5, I=6, J=7, L=8, M=9, N=10,
                     O=11, R=12, S=13, T=14, U=15, V=16, W=17;
    begin
        if (!spanish) case (wd)
            3'd0: day_name = {S, U, N};
            3'd1: day_name = {M, O, N};
            3'd2: day_name = {T, U, E};
            3'd3: day_name = {W, E, D};
            3'd4: day_name = {T, H, U};
            3'd5: day_name = {F, R, I};
            default: day_name = {S, A, T};
        endcase else case (wd)
            3'd0: day_name = {D, O, M};
            3'd1: day_name = {L, U, N};
            3'd2: day_name = {M, A, R};
            3'd3: day_name = {M, I, E};
            3'd4: day_name = {J, U, E};
            3'd5: day_name = {V, I, E};
            default: day_name = {S, A, B};
        endcase
    end
endfunction

reg [6:0] lit, ghost;   // lit segments / all segments at this pixel
reg       text_px;      // weekday letters
reg       colon_px;

always @(*) begin
    integer x, y, i, m, P, dx0, Xh, Yh, gx, gy;
    reg [6:0] h;
    reg [3:0] v;
    reg [14:0] dn;
    reg  [4:0] code, bits;
    x = lx;
    y = ly;
    P = pointed;
    lit   = 7'd0;
    ghost = 7'd0;
    text_px = 1'b0;

    // sample point in half units for the pointed segments
    Xh = size ? 2 * px + 1 : 4 * lx + 2;
    Yh = size ? 2 * py + 1 : 4 * ly + 2;

    // Weekday
    dx0 = DX0;
    if (weekday != 2'd0 && weekday != 2'd3 && rtc_s[55:48] < 8'd7) begin
        dx0 = WDX0;
        dn  = day_name(rtc_s[50:48], weekday[1]);
        for (i = 0; i < 3; i = i + 1) begin
            gx = x - (WX0 + i * WPITCH);
            gy = y - WY0;
            code = dn[14 - i * 5 -: 5];
            if (gx >= 0 && gx < 5 && gy >= 0 && gy < 7) begin
                bits = letter_row(code, gy);
                if (bits[4 - gx]) text_px = 1'b1;
            end
        end
    end else if (weekday != 2'd0 && weekday != 2'd3) begin
        dx0 = WDX0;                            // keep the layout, no name
    end

    // Date
    for (i = 0; i < 10; i = i + 1) begin
        if (datefmt == 2'd2) begin
            // YYYY-MM-DD
            case (i)
                0: v = 4'd2;
                1: v = 4'd0;
                2: v = rtc_s[47:44];  // year
                3: v = rtc_s[43:40];
                4: v = 4'hA;
                5: v = rtc_s[39:36];  // month
                6: v = rtc_s[35:32];
                7: v = 4'hA;
                8: v = rtc_s[31:28];  // day
                default: v = rtc_s[27:24];
            endcase
        end else begin
            // DD-MM-YYYY or MM-DD-YYYY
            case (i)
                0: v = datefmt[0] ? rtc_s[39:36] : rtc_s[31:28];
                1: v = datefmt[0] ? rtc_s[35:32] : rtc_s[27:24];
                2: v = 4'hA;
                3: v = datefmt[0] ? rtc_s[31:28] : rtc_s[39:36];
                4: v = datefmt[0] ? rtc_s[27:24] : rtc_s[35:32];
                5: v = 4'hA;
                6: v = 4'd2;
                7: v = 4'd0;
                8: v = rtc_s[47:44];  // year
                default: v = rtc_s[43:40];
            endcase
        end
        // the date digits are too small for pointed ends: always flat
        h = seg_hit(x - (dx0 + i * DPITCH), y - DY0, DW, DH, DTH, DTV, 0);
        if (v != 4'hA) ghost = ghost | h;      // dashes have no ghost segments
        lit = lit | (h & seg7(v));
    end

    // Hours and minutes
    h = (P ? hex_hit(Xh - 4 * HX0, Yh - 4 * TY0, PW_, PH_, PTH, PTV, PG, PGY) : seg_hit(x - HX0, y - TY0, TW, TH_, TTH, TTV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7(rtc_s[23:20]));
    h = (P ? hex_hit(Xh - 4 * HX1, Yh - 4 * TY0, PW_, PH_, PTH, PTV, PG, PGY) : seg_hit(x - HX1, y - TY0, TW, TH_, TTH, TTV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7(rtc_s[19:16]));
    h = (P ? hex_hit(Xh - 4 * MX0, Yh - 4 * TY0, PW_, PH_, PTH, PTV, PG, PGY) : seg_hit(x - MX0, y - TY0, TW, TH_, TTH, TTV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7(rtc_s[15:12]));
    h = (P ? hex_hit(Xh - 4 * MX1, Yh - 4 * TY0, PW_, PH_, PTH, PTV, PG, PGY) : seg_hit(x - MX1, y - TY0, TW, TH_, TTH, TTV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7(rtc_s[11:8]));

    // Seconds
    h = (P ? hex_hit(Xh - 4 * QX0, Yh - 4 * QY0, QW_, QH_, QTH, QTV, QG, QGY) : seg_hit(x - SX0, y - SY0, SW, SH, STH, STV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7({1'b0, rtc_s[6:4]}));
    h = (P ? hex_hit(Xh - 4 * QX1, Yh - 4 * QY0, QW_, QH_, QTH, QTV, QG, QGY) : seg_hit(x - SX1, y - SY0, SW, SH, STH, STV, 0));
    ghost = ghost | h;  lit = lit | (h & seg7(rtc_s[3:0]));

    // Colon: two squares as thick as the segments, centered in each half
    m = (TH_ - TTH) / 2;
    colon_px = (x >= CX && x < CX + TTV) &&
               ((y >= TY0 + (TTH + m - TTH) / 2 &&
                 y <  TY0 + (TTH + m - TTH) / 2 + TTH) ||
                (y >= TY0 + (m + TH_ - TTH) / 2 &&
                 y <  TY0 + (m + TH_ - TTH) / 2 + TTH));
end

// ---------------------------------------------------------------------------
// Color schemes: frame, inner shadow, background, unlit segments, lit segments
// ---------------------------------------------------------------------------
//   0 Green LCD     classic reflective LCD
//   1 Gray LCD      wristwatch style
//   2 Blue          blue backlight, white segments
//   3 Amber         amber backlight, dark segments
//   4 Game Boy      DMG green tones
//   5 Red LED       red segments on black
//   6 VFD           cyan-green segments on black
//   7 Inverted      white segments on black
reg [23:0] C_FRAME, C_BEZEL, C_BG, C_GHOST, C_LIT;

always @(*) begin
    C_FRAME = 24'h2A2C2A;
    case (palette)
        3'd1: begin C_BEZEL = 24'h7E8278; C_BG = 24'hBABEB2; C_GHOST = 24'hADB1A5; C_LIT = 24'h1A1A1A; end
        3'd2: begin C_BEZEL = 24'h17397A; C_BG = 24'h2C62C8; C_GHOST = 24'h3A6ECF; C_LIT = 24'hEAF2FF; end
        3'd3: begin C_BEZEL = 24'h9A6420; C_BG = 24'hE9A43E; C_GHOST = 24'hD9963A; C_LIT = 24'h2A1906; end
        3'd4: begin C_BEZEL = 24'h306230; C_BG = 24'h9BBC0F; C_GHOST = 24'h8BAC0F; C_LIT = 24'h0F380F; end
        3'd5: begin C_FRAME = 24'h3A3A3A; C_BEZEL = 24'h000000; C_BG = 24'h120404; C_GHOST = 24'h2C0909; C_LIT = 24'hFF3424; end
        3'd6: begin C_FRAME = 24'h3A3A3A; C_BEZEL = 24'h000000; C_BG = 24'h050C0A; C_GHOST = 24'h0F2621; C_LIT = 24'h45FFD2; end
        3'd7: begin C_FRAME = 24'h4A4A4A; C_BEZEL = 24'h000000; C_BG = 24'h101010; C_GHOST = 24'h202020; C_LIT = 24'hE8E8E8; end
        default: begin C_BEZEL = 24'h6F7A64; C_BG = 24'hA9B897; C_GHOST = 24'h9DAC8B; C_LIT = 24'h1B2418; end
    endcase
end

always @(posedge clk) begin
    reg [23:0] c;
    reg  [1:0] a;
    reg        lit_px, ghost_px;

    lit_px   = |lit || (colon_px && colon_on) || text_px;
    ghost_px = (|ghost || colon_px) && !no_shadow;

    if (!no_panel) begin
        // panel: frame 2 px / 1 line and inner shadow 1 px (1x units)
        a = 2'd3;
        if (lx < 2 || lx >= PANEL_W - 2 || ly < 1 || ly >= PANEL_H - 1)
            c = C_FRAME;
        else if (lx < 3 || ly < 2)
            c = C_BEZEL;
        else if (lit_px)
            c = C_LIT;
        else if (ghost_px)
            c = C_GHOST;
        else
            c = C_BG;
    end else begin
        // no panel: lit segments opaque, unlit ones as a faint shadow
        c = C_LIT;
        a = lit_px ? 2'd3 : ghost_px ? 2'd1 : 2'd0;
    end

    if (!(rtc_valid && enable && in_x && in_y)) a = 2'd0;

    alpha  <= a;
    active <= (a != 2'd0);
    {r, g, b} <= c;
end

endmodule
