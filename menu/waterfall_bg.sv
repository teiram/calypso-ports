// waterfall_bg.sv - Animated waterfall background for the Calypso Menu core
// Shaeon (Carlos Palmero), 2026
//
// Vertical streams of water falling at different speeds, with white foam
// at the bottom of the screen. Each column
// gets its own phase and speed from a small hash, and three layers of
// different width are mixed. Everything is computed per pixel, no
// memory is used.

`default_nettype none

module waterfall_bg (
    input  wire        clk,               // pixel clock
    input  wire  [9:0] hc,
    input  wire  [8:0] vc,
    input  wire  [8:0] line_max,
    input  wire  [9:0] frame,             // frame counter
    input  wire  [7:0] noise,             // random bits (LFSR, unused)
    output reg   [7:0] r,
    output reg   [7:0] g,
    output reg   [7:0] b
);

// Small hash for per-column phase and speed
function automatic [11:0] hash(input [7:0] c);
    reg  [7:0] k;
    reg [15:0] m;
    begin
        k    = c ^ {c[4:0], 3'b0} ^ 8'h5A;
        m    = {8'd0, k} * 16'd40503;
        m    = m ^ {5'd0, m[15:5]};
        k    = k ^ {k[3:0], k[7:4]};
        m    = m ^ ({8'd0, k} * 16'd113);
        hash = m[11:0];
    end
endfunction

// Position of a pixel inside the moving pattern of a column: the pattern
// scrolls down at a per-column speed and starts at a per-column phase.
function automatic [11:0] flow(
    input [7:0] col, input [8:0] y, input [9:0] t, input [1:0] base_speed);
    reg [11:0] h;
    reg  [2:0] speed;
    begin
        h     = hash(col);
        speed = {1'b0, base_speed} + {1'b0, h[11:10]};
        flow  = {3'b0, y} - t * speed + {h[8:0], 3'b0};
    end
endfunction

reg [7:0] intensity, intensity_q = 8'd0;

always @(*) begin
    reg  [9:0] x;
    reg [11:0] p1, p2;
    reg [15:0] q;
    reg  [7:0] l1, l2, base;
    reg [11:0] h3;
    reg  [7:0] x3;
    reg [14:0] fade;
    reg  [9:0] i_sum;
    reg  [8:0] foam_y;
    reg  [6:0] d;
    reg [13:0] fsq, fnz;
    reg [11:0] fr, fh;

    fade = 15'd0;
    d    = 7'd0;
    fsq  = 14'd0;
    fnz  = 14'd0;
    fr   = 12'd0;
    fh   = 12'd0;

    // streams are strictly vertical: no sideways ripple
    x      = hc;
    x3     = ({8'd0, x} * 18'd85) >> 8;       // x / 3

    // L1: thin fast streaks (3 px) with a smooth profile (no hard edges)
    p1 = flow(x3, vc, frame, 2'd3);
    l1 = p1[8] ? ~p1[7:0] : p1[7:0];               // triangle, 512 lines
    q  = l1 * l1;
    l1 = q[15:8];                                  // sharper highlights

    // L2: wide slow bands (8 px), smooth triangle profile
    p2 = flow({1'b0, x[9:3]}, vc, frame, 2'd1);
    l2 = p2[8] ? ~p2[7:0] : p2[7:0];

    // L3: static thickness of the water per 16 px column
    h3   = hash({2'b0, x[9:4]} + 8'd77);
    base = 8'd70 + {2'b0, h3[5:0]};

    i_sum = {2'b0, base[7:1]} + {2'b0, l1[7:2]} + {2'b0, l1[7:3]} + {2'b0, l2[7:1]};

    // water starts falling at the top: fade in over the first 32 lines
    if (vc < 9'd34) begin
        fade  = i_sum * (vc - 9'd2);
        i_sum = fade[14:5];
    end


    // foam at the bottom: brighter and noisier in the last 80 lines
    foam_y = line_max - 9'd85;
    if (vc > foam_y) begin
        d     = vc - foam_y;                          // 1..80
        fsq   = d * d;
        // foam texture that falls with the water (no per-frame flicker)
        fr    = {3'b0, vc} - frame * 10'd3;
        fh    = hash(x[8:1] ^ fr[9:2]);
        fnz   = fh[6:0] * d;
        i_sum = i_sum + fsq[12:4] + fnz[13:6];
    end

    intensity = (i_sum > 10'd255) ? 8'd255 : i_sum[7:0];
end

// pipeline stage
always @(posedge clk) intensity_q <= intensity;

// Color: deep blue -> cyan -> white
always @(posedge clk) begin
    reg [15:0] sq;
    reg  [8:0] gg, bb;
    sq = intensity_q * intensity_q;
    gg = {1'b0, intensity_q[7:1]} + {1'b0, sq[15:9]};
    bb = 9'd64 + {1'b0, intensity_q} - {3'b0, intensity_q[7:2]};
    r <= sq[15:8];
    g <= (gg > 9'd255) ? 8'd255 : gg[7:0];
    b <= (bb > 9'd255) ? 8'd255 : bb[7:0];
end

endmodule
