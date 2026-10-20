// calypso_logo.sv - "Calypso" logo for the animated backgrounds
// Shaeon (Carlos Palmero), 2026
//
// The logo is taken from the Calypso menu.rom (red "Calypso" text in the
// bottom right corner) and stored as a 126x22, 2-bit alpha bitmap. It is
// drawn at the same place as in menu.rom: right margin 12 px, 17 lines from
// the bottom.

`default_nettype none

module calypso_logo (
    input  wire        clk,               // pixel clock
    input  wire  [9:0] hc,
    input  wire  [8:0] vc,
    input  wire  [8:0] line_max,
    output reg   [1:0] alpha              // 0 transparent .. 3 opaque
);

localparam int LW = 126;
localparam int LH = 22;
localparam int LX = 503;

function automatic [2*LW-1:0] logo_row(input [4:0] row);
    case (row)
        5'd0: logo_row = 252'h000000000000000000000000000000000000000000000000000000000000000;
        5'd1: logo_row = 252'h0000000000000000000005aa400000000000000000000000000000000000000;
        5'd2: logo_row = 252'h00006bffa0000000000007ff800000000000000000000000000000000000000;
        5'd3: logo_row = 252'h001bfffffe000000000007ff800000000000000000000000000000000000000;
        5'd4: logo_row = 252'h01bfffffff000000000007ff800000000000000000000000000000000000000;
        5'd5: logo_row = 252'h06fffe96bf001555550007ff815540015541554555000015555400015555000;
        5'd6: logo_row = 252'h0bffe0000601bfffff9007ff86ffc007ff87ffafff9002fffffe001bffff900;
        5'd7: logo_row = 252'h1bff80000001fffffff407ff81ffe00bff47fffffff80bfffffe40bffffff90;
        5'd8: logo_row = 252'h1fff00000001a941bff807ff80bff41ffe07ffe47ffd1ffe45aa02ffe46ffe4;
        5'd9: logo_row = 252'h1fff000000001bfffffc07ff806ff82ffd07ffd01ffe5fffa90007ffd01bff4;
        5'd10: logo_row = 252'h1fff40000001fffffffc07ff801ffd7ff807ff801bff4bfffff907ff900bff4;
        5'd11: logo_row = 252'h1bff80000007ffeabffc07ff801bfebfe007ff801bff42bfffff47ff900bff4;
        5'd12: logo_row = 252'h07fff5016a0bff807ffc07ff8007ffffd007ffd01ffe4005abff87ffd01bff4;
        5'd13: logo_row = 252'h02ffffffff07ff96fffc07ff8001ffff8007ffe47ffd1aa507ff82ffe46ffe4;
        5'd14: logo_row = 252'h006fffffff06fffffffc07ff8001bfff4007fffffff81bffffff40bffffff90;
        5'd15: logo_row = 252'h0006fffffa01bfffaffc07ff80007ffe0007ffafff901bfffff9001bffff900;
        5'd16: logo_row = 252'h00005555500015551554015540002ffd0007ff8555000155555000015555000;
        5'd17: logo_row = 252'h00000000000000000000000000006ff80007ff8000000000000000000000000;
        5'd18: logo_row = 252'h000000000000000000000000006fffe00007ff8000000000000000000000000;
        5'd19: logo_row = 252'h000000000000000000000000006fff800007ff8000000000000000000000000;
        5'd20: logo_row = 252'h000000000000000000000000001aa5000005aa4000000000000000000000000;
        5'd21: logo_row = 252'h000000000000000000000000000000000000000000000000000000000000000;
        default: logo_row = '0;
    endcase
endfunction

wire [8:0] ly0 = line_max - 9'd38;     // first line of the logo

always @(posedge clk) begin
    reg [2*LW-1:0] bits;
    reg [9:0] x;
    reg [8:0] y;
    alpha <= 2'd0;
    if (hc >= LX && hc < LX + LW && vc >= ly0 && vc < ly0 + LH) begin
        x    = hc - LX[9:0];
        y    = vc - ly0;
        bits = logo_row(y[4:0]);
        alpha <= bits[2*(LW-1-x) +: 2];
    end
end

endmodule
