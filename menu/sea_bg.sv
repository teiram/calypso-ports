// sea_bg.sv - Animated sea background for the Calypso Menu core
// Shaeon (Carlos Palmero), 2026
//
// Inspired by the Calypso menu.rom picture: cyan sky, horizon and a deep
// blue sea. Waves are drawn in perspective (wider and slower near the
// viewer); the wave field sways left and right with a slow "tide" and the
// water comes and goes on a sandy shore at the bottom.
// Everything is computed per pixel with two small tables (sine and depth).

`default_nettype none

module sea_bg (
    input  wire        clk,               // pixel clock
    input  wire  [9:0] hc,
    input  wire  [8:0] vc,
    input  wire  [8:0] line_max,
    input  wire [15:0] frame,             // animation counter
    output reg   [7:0] r,
    output reg   [7:0] g,
    output reg   [7:0] b
);

localparam [8:0] HORIZON = 9'd100;

function automatic signed [7:0] sin8(input [7:0] i);
    case (i)
        8'd0: sin8 = 8'h00;
        8'd1: sin8 = 8'h03;
        8'd2: sin8 = 8'h06;
        8'd3: sin8 = 8'h09;
        8'd4: sin8 = 8'h0c;
        8'd5: sin8 = 8'h10;
        8'd6: sin8 = 8'h13;
        8'd7: sin8 = 8'h16;
        8'd8: sin8 = 8'h19;
        8'd9: sin8 = 8'h1c;
        8'd10: sin8 = 8'h1f;
        8'd11: sin8 = 8'h22;
        8'd12: sin8 = 8'h25;
        8'd13: sin8 = 8'h28;
        8'd14: sin8 = 8'h2b;
        8'd15: sin8 = 8'h2e;
        8'd16: sin8 = 8'h31;
        8'd17: sin8 = 8'h33;
        8'd18: sin8 = 8'h36;
        8'd19: sin8 = 8'h39;
        8'd20: sin8 = 8'h3c;
        8'd21: sin8 = 8'h3f;
        8'd22: sin8 = 8'h41;
        8'd23: sin8 = 8'h44;
        8'd24: sin8 = 8'h47;
        8'd25: sin8 = 8'h49;
        8'd26: sin8 = 8'h4c;
        8'd27: sin8 = 8'h4e;
        8'd28: sin8 = 8'h51;
        8'd29: sin8 = 8'h53;
        8'd30: sin8 = 8'h55;
        8'd31: sin8 = 8'h58;
        8'd32: sin8 = 8'h5a;
        8'd33: sin8 = 8'h5c;
        8'd34: sin8 = 8'h5e;
        8'd35: sin8 = 8'h60;
        8'd36: sin8 = 8'h62;
        8'd37: sin8 = 8'h64;
        8'd38: sin8 = 8'h66;
        8'd39: sin8 = 8'h68;
        8'd40: sin8 = 8'h6a;
        8'd41: sin8 = 8'h6b;
        8'd42: sin8 = 8'h6d;
        8'd43: sin8 = 8'h6f;
        8'd44: sin8 = 8'h70;
        8'd45: sin8 = 8'h71;
        8'd46: sin8 = 8'h73;
        8'd47: sin8 = 8'h74;
        8'd48: sin8 = 8'h75;
        8'd49: sin8 = 8'h76;
        8'd50: sin8 = 8'h78;
        8'd51: sin8 = 8'h79;
        8'd52: sin8 = 8'h7a;
        8'd53: sin8 = 8'h7a;
        8'd54: sin8 = 8'h7b;
        8'd55: sin8 = 8'h7c;
        8'd56: sin8 = 8'h7d;
        8'd57: sin8 = 8'h7d;
        8'd58: sin8 = 8'h7e;
        8'd59: sin8 = 8'h7e;
        8'd60: sin8 = 8'h7e;
        8'd61: sin8 = 8'h7f;
        8'd62: sin8 = 8'h7f;
        8'd63: sin8 = 8'h7f;
        8'd64: sin8 = 8'h7f;
        8'd65: sin8 = 8'h7f;
        8'd66: sin8 = 8'h7f;
        8'd67: sin8 = 8'h7f;
        8'd68: sin8 = 8'h7e;
        8'd69: sin8 = 8'h7e;
        8'd70: sin8 = 8'h7e;
        8'd71: sin8 = 8'h7d;
        8'd72: sin8 = 8'h7d;
        8'd73: sin8 = 8'h7c;
        8'd74: sin8 = 8'h7b;
        8'd75: sin8 = 8'h7a;
        8'd76: sin8 = 8'h7a;
        8'd77: sin8 = 8'h79;
        8'd78: sin8 = 8'h78;
        8'd79: sin8 = 8'h76;
        8'd80: sin8 = 8'h75;
        8'd81: sin8 = 8'h74;
        8'd82: sin8 = 8'h73;
        8'd83: sin8 = 8'h71;
        8'd84: sin8 = 8'h70;
        8'd85: sin8 = 8'h6f;
        8'd86: sin8 = 8'h6d;
        8'd87: sin8 = 8'h6b;
        8'd88: sin8 = 8'h6a;
        8'd89: sin8 = 8'h68;
        8'd90: sin8 = 8'h66;
        8'd91: sin8 = 8'h64;
        8'd92: sin8 = 8'h62;
        8'd93: sin8 = 8'h60;
        8'd94: sin8 = 8'h5e;
        8'd95: sin8 = 8'h5c;
        8'd96: sin8 = 8'h5a;
        8'd97: sin8 = 8'h58;
        8'd98: sin8 = 8'h55;
        8'd99: sin8 = 8'h53;
        8'd100: sin8 = 8'h51;
        8'd101: sin8 = 8'h4e;
        8'd102: sin8 = 8'h4c;
        8'd103: sin8 = 8'h49;
        8'd104: sin8 = 8'h47;
        8'd105: sin8 = 8'h44;
        8'd106: sin8 = 8'h41;
        8'd107: sin8 = 8'h3f;
        8'd108: sin8 = 8'h3c;
        8'd109: sin8 = 8'h39;
        8'd110: sin8 = 8'h36;
        8'd111: sin8 = 8'h33;
        8'd112: sin8 = 8'h31;
        8'd113: sin8 = 8'h2e;
        8'd114: sin8 = 8'h2b;
        8'd115: sin8 = 8'h28;
        8'd116: sin8 = 8'h25;
        8'd117: sin8 = 8'h22;
        8'd118: sin8 = 8'h1f;
        8'd119: sin8 = 8'h1c;
        8'd120: sin8 = 8'h19;
        8'd121: sin8 = 8'h16;
        8'd122: sin8 = 8'h13;
        8'd123: sin8 = 8'h10;
        8'd124: sin8 = 8'h0c;
        8'd125: sin8 = 8'h09;
        8'd126: sin8 = 8'h06;
        8'd127: sin8 = 8'h03;
        8'd128: sin8 = 8'h00;
        8'd129: sin8 = 8'hfd;
        8'd130: sin8 = 8'hfa;
        8'd131: sin8 = 8'hf7;
        8'd132: sin8 = 8'hf4;
        8'd133: sin8 = 8'hf0;
        8'd134: sin8 = 8'hed;
        8'd135: sin8 = 8'hea;
        8'd136: sin8 = 8'he7;
        8'd137: sin8 = 8'he4;
        8'd138: sin8 = 8'he1;
        8'd139: sin8 = 8'hde;
        8'd140: sin8 = 8'hdb;
        8'd141: sin8 = 8'hd8;
        8'd142: sin8 = 8'hd5;
        8'd143: sin8 = 8'hd2;
        8'd144: sin8 = 8'hcf;
        8'd145: sin8 = 8'hcd;
        8'd146: sin8 = 8'hca;
        8'd147: sin8 = 8'hc7;
        8'd148: sin8 = 8'hc4;
        8'd149: sin8 = 8'hc1;
        8'd150: sin8 = 8'hbf;
        8'd151: sin8 = 8'hbc;
        8'd152: sin8 = 8'hb9;
        8'd153: sin8 = 8'hb7;
        8'd154: sin8 = 8'hb4;
        8'd155: sin8 = 8'hb2;
        8'd156: sin8 = 8'haf;
        8'd157: sin8 = 8'had;
        8'd158: sin8 = 8'hab;
        8'd159: sin8 = 8'ha8;
        8'd160: sin8 = 8'ha6;
        8'd161: sin8 = 8'ha4;
        8'd162: sin8 = 8'ha2;
        8'd163: sin8 = 8'ha0;
        8'd164: sin8 = 8'h9e;
        8'd165: sin8 = 8'h9c;
        8'd166: sin8 = 8'h9a;
        8'd167: sin8 = 8'h98;
        8'd168: sin8 = 8'h96;
        8'd169: sin8 = 8'h95;
        8'd170: sin8 = 8'h93;
        8'd171: sin8 = 8'h91;
        8'd172: sin8 = 8'h90;
        8'd173: sin8 = 8'h8f;
        8'd174: sin8 = 8'h8d;
        8'd175: sin8 = 8'h8c;
        8'd176: sin8 = 8'h8b;
        8'd177: sin8 = 8'h8a;
        8'd178: sin8 = 8'h88;
        8'd179: sin8 = 8'h87;
        8'd180: sin8 = 8'h86;
        8'd181: sin8 = 8'h86;
        8'd182: sin8 = 8'h85;
        8'd183: sin8 = 8'h84;
        8'd184: sin8 = 8'h83;
        8'd185: sin8 = 8'h83;
        8'd186: sin8 = 8'h82;
        8'd187: sin8 = 8'h82;
        8'd188: sin8 = 8'h82;
        8'd189: sin8 = 8'h81;
        8'd190: sin8 = 8'h81;
        8'd191: sin8 = 8'h81;
        8'd192: sin8 = 8'h81;
        8'd193: sin8 = 8'h81;
        8'd194: sin8 = 8'h81;
        8'd195: sin8 = 8'h81;
        8'd196: sin8 = 8'h82;
        8'd197: sin8 = 8'h82;
        8'd198: sin8 = 8'h82;
        8'd199: sin8 = 8'h83;
        8'd200: sin8 = 8'h83;
        8'd201: sin8 = 8'h84;
        8'd202: sin8 = 8'h85;
        8'd203: sin8 = 8'h86;
        8'd204: sin8 = 8'h86;
        8'd205: sin8 = 8'h87;
        8'd206: sin8 = 8'h88;
        8'd207: sin8 = 8'h8a;
        8'd208: sin8 = 8'h8b;
        8'd209: sin8 = 8'h8c;
        8'd210: sin8 = 8'h8d;
        8'd211: sin8 = 8'h8f;
        8'd212: sin8 = 8'h90;
        8'd213: sin8 = 8'h91;
        8'd214: sin8 = 8'h93;
        8'd215: sin8 = 8'h95;
        8'd216: sin8 = 8'h96;
        8'd217: sin8 = 8'h98;
        8'd218: sin8 = 8'h9a;
        8'd219: sin8 = 8'h9c;
        8'd220: sin8 = 8'h9e;
        8'd221: sin8 = 8'ha0;
        8'd222: sin8 = 8'ha2;
        8'd223: sin8 = 8'ha4;
        8'd224: sin8 = 8'ha6;
        8'd225: sin8 = 8'ha8;
        8'd226: sin8 = 8'hab;
        8'd227: sin8 = 8'had;
        8'd228: sin8 = 8'haf;
        8'd229: sin8 = 8'hb2;
        8'd230: sin8 = 8'hb4;
        8'd231: sin8 = 8'hb7;
        8'd232: sin8 = 8'hb9;
        8'd233: sin8 = 8'hbc;
        8'd234: sin8 = 8'hbf;
        8'd235: sin8 = 8'hc1;
        8'd236: sin8 = 8'hc4;
        8'd237: sin8 = 8'hc7;
        8'd238: sin8 = 8'hca;
        8'd239: sin8 = 8'hcd;
        8'd240: sin8 = 8'hcf;
        8'd241: sin8 = 8'hd2;
        8'd242: sin8 = 8'hd5;
        8'd243: sin8 = 8'hd8;
        8'd244: sin8 = 8'hdb;
        8'd245: sin8 = 8'hde;
        8'd246: sin8 = 8'he1;
        8'd247: sin8 = 8'he4;
        8'd248: sin8 = 8'he7;
        8'd249: sin8 = 8'hea;
        8'd250: sin8 = 8'hed;
        8'd251: sin8 = 8'hf0;
        8'd252: sin8 = 8'hf4;
        8'd253: sin8 = 8'hf7;
        8'd254: sin8 = 8'hfa;
        8'd255: sin8 = 8'hfd;
        default: sin8 = 8'h0;
    endcase
endfunction

function automatic [11:0] depth(input [7:0] i);
    case (i)
        8'd0: depth = 12'hfff;
        8'd1: depth = 12'he10;
        8'd2: depth = 12'hc80;
        8'd3: depth = 12'hb40;
        8'd4: depth = 12'ha3a;
        8'd5: depth = 12'h960;
        8'd6: depth = 12'h8a7;
        8'd7: depth = 12'h809;
        8'd8: depth = 12'h780;
        8'd9: depth = 12'h708;
        8'd10: depth = 12'h69e;
        8'd11: depth = 12'h640;
        8'd12: depth = 12'h5eb;
        8'd13: depth = 12'h5a0;
        8'd14: depth = 12'h55b;
        8'd15: depth = 12'h51d;
        8'd16: depth = 12'h4e4;
        8'd17: depth = 12'h4b0;
        8'd18: depth = 12'h480;
        8'd19: depth = 12'h453;
        8'd20: depth = 12'h42a;
        8'd21: depth = 12'h404;
        8'd22: depth = 12'h3e1;
        8'd23: depth = 12'h3c0;
        8'd24: depth = 12'h3a1;
        8'd25: depth = 12'h384;
        8'd26: depth = 12'h368;
        8'd27: depth = 12'h34f;
        8'd28: depth = 12'h336;
        8'd29: depth = 12'h320;
        8'd30: depth = 12'h30a;
        8'd31: depth = 12'h2f5;
        8'd32: depth = 12'h2e2;
        8'd33: depth = 12'h2d0;
        8'd34: depth = 12'h2be;
        8'd35: depth = 12'h2ad;
        8'd36: depth = 12'h29d;
        8'd37: depth = 12'h28e;
        8'd38: depth = 12'h280;
        8'd39: depth = 12'h272;
        8'd40: depth = 12'h264;
        8'd41: depth = 12'h258;
        8'd42: depth = 12'h24b;
        8'd43: depth = 12'h240;
        8'd44: depth = 12'h234;
        8'd45: depth = 12'h229;
        8'd46: depth = 12'h21f;
        8'd47: depth = 12'h215;
        8'd48: depth = 12'h20b;
        8'd49: depth = 12'h202;
        8'd50: depth = 12'h1f9;
        8'd51: depth = 12'h1f0;
        8'd52: depth = 12'h1e8;
        8'd53: depth = 12'h1e0;
        8'd54: depth = 12'h1d8;
        8'd55: depth = 12'h1d0;
        8'd56: depth = 12'h1c9;
        8'd57: depth = 12'h1c2;
        8'd58: depth = 12'h1bb;
        8'd59: depth = 12'h1b4;
        8'd60: depth = 12'h1ad;
        8'd61: depth = 12'h1a7;
        8'd62: depth = 12'h1a1;
        8'd63: depth = 12'h19b;
        8'd64: depth = 12'h195;
        8'd65: depth = 12'h190;
        8'd66: depth = 12'h18a;
        8'd67: depth = 12'h185;
        8'd68: depth = 12'h180;
        8'd69: depth = 12'h17a;
        8'd70: depth = 12'h176;
        8'd71: depth = 12'h171;
        8'd72: depth = 12'h16c;
        8'd73: depth = 12'h168;
        8'd74: depth = 12'h163;
        8'd75: depth = 12'h15f;
        8'd76: depth = 12'h15a;
        8'd77: depth = 12'h156;
        8'd78: depth = 12'h152;
        8'd79: depth = 12'h14e;
        8'd80: depth = 12'h14b;
        8'd81: depth = 12'h147;
        8'd82: depth = 12'h143;
        8'd83: depth = 12'h140;
        8'd84: depth = 12'h13c;
        8'd85: depth = 12'h139;
        8'd86: depth = 12'h135;
        8'd87: depth = 12'h132;
        8'd88: depth = 12'h12f;
        8'd89: depth = 12'h12c;
        8'd90: depth = 12'h128;
        8'd91: depth = 12'h125;
        8'd92: depth = 12'h122;
        8'd93: depth = 12'h120;
        8'd94: depth = 12'h11d;
        8'd95: depth = 12'h11a;
        8'd96: depth = 12'h117;
        8'd97: depth = 12'h114;
        8'd98: depth = 12'h112;
        8'd99: depth = 12'h10f;
        8'd100: depth = 12'h10d;
        8'd101: depth = 12'h10a;
        8'd102: depth = 12'h108;
        8'd103: depth = 12'h105;
        8'd104: depth = 12'h103;
        8'd105: depth = 12'h101;
        8'd106: depth = 12'h0fe;
        8'd107: depth = 12'h0fc;
        8'd108: depth = 12'h0fa;
        8'd109: depth = 12'h0f8;
        8'd110: depth = 12'h0f6;
        8'd111: depth = 12'h0f4;
        8'd112: depth = 12'h0f2;
        8'd113: depth = 12'h0f0;
        8'd114: depth = 12'h0ee;
        8'd115: depth = 12'h0ec;
        8'd116: depth = 12'h0ea;
        8'd117: depth = 12'h0e8;
        8'd118: depth = 12'h0e6;
        8'd119: depth = 12'h0e4;
        8'd120: depth = 12'h0e2;
        8'd121: depth = 12'h0e1;
        8'd122: depth = 12'h0df;
        8'd123: depth = 12'h0dd;
        8'd124: depth = 12'h0db;
        8'd125: depth = 12'h0da;
        8'd126: depth = 12'h0d8;
        8'd127: depth = 12'h0d6;
        8'd128: depth = 12'h0d5;
        8'd129: depth = 12'h0d3;
        8'd130: depth = 12'h0d2;
        8'd131: depth = 12'h0d0;
        8'd132: depth = 12'h0cf;
        8'd133: depth = 12'h0cd;
        8'd134: depth = 12'h0cc;
        8'd135: depth = 12'h0ca;
        8'd136: depth = 12'h0c9;
        8'd137: depth = 12'h0c8;
        8'd138: depth = 12'h0c6;
        8'd139: depth = 12'h0c5;
        8'd140: depth = 12'h0c3;
        8'd141: depth = 12'h0c2;
        8'd142: depth = 12'h0c1;
        8'd143: depth = 12'h0c0;
        8'd144: depth = 12'h0be;
        8'd145: depth = 12'h0bd;
        8'd146: depth = 12'h0bc;
        8'd147: depth = 12'h0bb;
        8'd148: depth = 12'h0b9;
        8'd149: depth = 12'h0b8;
        8'd150: depth = 12'h0b7;
        8'd151: depth = 12'h0b6;
        8'd152: depth = 12'h0b5;
        8'd153: depth = 12'h0b4;
        8'd154: depth = 12'h0b2;
        8'd155: depth = 12'h0b1;
        8'd156: depth = 12'h0b0;
        8'd157: depth = 12'h0af;
        8'd158: depth = 12'h0ae;
        8'd159: depth = 12'h0ad;
        8'd160: depth = 12'h0ac;
        8'd161: depth = 12'h0ab;
        8'd162: depth = 12'h0aa;
        8'd163: depth = 12'h0a9;
        8'd164: depth = 12'h0a8;
        8'd165: depth = 12'h0a7;
        8'd166: depth = 12'h0a6;
        8'd167: depth = 12'h0a5;
        8'd168: depth = 12'h0a4;
        8'd169: depth = 12'h0a3;
        8'd170: depth = 12'h0a2;
        8'd171: depth = 12'h0a1;
        8'd172: depth = 12'h0a0;
        8'd173: depth = 12'h0a0;
        8'd174: depth = 12'h09f;
        8'd175: depth = 12'h09e;
        8'd176: depth = 12'h09d;
        8'd177: depth = 12'h09c;
        8'd178: depth = 12'h09b;
        8'd179: depth = 12'h09a;
        8'd180: depth = 12'h09a;
        8'd181: depth = 12'h099;
        8'd182: depth = 12'h098;
        8'd183: depth = 12'h097;
        8'd184: depth = 12'h096;
        8'd185: depth = 12'h096;
        8'd186: depth = 12'h095;
        8'd187: depth = 12'h094;
        8'd188: depth = 12'h093;
        8'd189: depth = 12'h092;
        8'd190: depth = 12'h092;
        8'd191: depth = 12'h091;
        8'd192: depth = 12'h090;
        8'd193: depth = 12'h090;
        8'd194: depth = 12'h08f;
        8'd195: depth = 12'h08e;
        8'd196: depth = 12'h08d;
        8'd197: depth = 12'h08d;
        8'd198: depth = 12'h08c;
        8'd199: depth = 12'h08b;
        8'd200: depth = 12'h08b;
        8'd201: depth = 12'h08a;
        8'd202: depth = 12'h089;
        8'd203: depth = 12'h089;
        8'd204: depth = 12'h088;
        8'd205: depth = 12'h087;
        8'd206: depth = 12'h087;
        8'd207: depth = 12'h086;
        8'd208: depth = 12'h085;
        8'd209: depth = 12'h085;
        8'd210: depth = 12'h084;
        8'd211: depth = 12'h084;
        8'd212: depth = 12'h083;
        8'd213: depth = 12'h082;
        8'd214: depth = 12'h082;
        8'd215: depth = 12'h081;
        8'd216: depth = 12'h081;
        8'd217: depth = 12'h080;
        8'd218: depth = 12'h080;
        8'd219: depth = 12'h07f;
        8'd220: depth = 12'h07e;
        8'd221: depth = 12'h07e;
        8'd222: depth = 12'h07d;
        8'd223: depth = 12'h07d;
        8'd224: depth = 12'h07c;
        8'd225: depth = 12'h07c;
        8'd226: depth = 12'h07b;
        8'd227: depth = 12'h07b;
        8'd228: depth = 12'h07a;
        8'd229: depth = 12'h07a;
        8'd230: depth = 12'h079;
        8'd231: depth = 12'h079;
        8'd232: depth = 12'h078;
        8'd233: depth = 12'h078;
        8'd234: depth = 12'h077;
        8'd235: depth = 12'h077;
        8'd236: depth = 12'h076;
        8'd237: depth = 12'h076;
        8'd238: depth = 12'h075;
        8'd239: depth = 12'h075;
        8'd240: depth = 12'h074;
        8'd241: depth = 12'h074;
        8'd242: depth = 12'h073;
        8'd243: depth = 12'h073;
        8'd244: depth = 12'h072;
        8'd245: depth = 12'h072;
        8'd246: depth = 12'h071;
        8'd247: depth = 12'h071;
        8'd248: depth = 12'h070;
        8'd249: depth = 12'h070;
        8'd250: depth = 12'h070;
        8'd251: depth = 12'h06f;
        8'd252: depth = 12'h06f;
        8'd253: depth = 12'h06e;
        8'd254: depth = 12'h06e;
        8'd255: depth = 12'h06d;
        default: depth = 12'h0;
    endcase
endfunction

// linear interpolation between two colors, f = 0..255
function automatic [7:0] mix(input [7:0] c0, input [7:0] c1, input [7:0] f);
    reg [16:0] t;
    begin
        t   = c0 * (9'd256 - f) + c1 * f;
        mix = t[15:8];
    end
endfunction

reg  [7:0] r0, g0, b0;          // stage 1

always @(*) begin
    reg  [8:0] d;
    reg  [7:0] z, ph, ph2, f;
    reg [11:0] zf;            // depth with 4 fractional bits
    reg signed [7:0] wob, s3;
    reg [18:0] u;
    integer    sh, edge_d, phi, lm, vi, zi, fr1, fr0, ti, wi;
    reg signed [7:0] s, s2, tide;
    reg  [9:0] crest;
    reg [17:0] xw;
    reg  [8:0] shore;  // for reference
    reg  [7:0] bl;
    reg  [9:0] tmp;
    reg signed [9:0]  sway;
    integer           xs, xp;

    r0 = 8'd0; g0 = 8'd0; b0 = 8'd0;
    d = 9'd0; z = 8'd0; ph = 8'd0; ph2 = 8'd0; wob = 8'd0; f = 8'd0;
    zf = 12'd0; zi = 0; fr1 = 0; fr0 = 0; ti = 0; wi = 0;
    s = 8'sd0; s2 = 8'sd0; phi = 0; lm = 0; vi = 0; s3 = 8'sd0; u = 18'd0; wob = 8'sd0; sh = 0; edge_d = 0; crest = 10'd0; xw = 18'd0; shore = 9'd0; bl = 8'd0;
    tmp = 10'd0; sway = 10'sd0; xs = 0; xp = 0;

    // the tide: water comes and goes with a slow sine
    tide = sin8(frame[11:4]);

    if (vc < HORIZON) begin
        // sky: deeper cyan at the top, lighter near the horizon
        f  = (vc < 9'd2) ? 8'd0 : {vc[7:0] - 8'd2} << 1;
        r0 = mix(8'd0,   8'd40,  f);
        g0 = mix(8'd200, 8'd247, f);
        b0 = mix(8'd235, 8'd250, f);
        // faint shimmer line on the horizon
        if (vc >= HORIZON - 9'd2) begin
            r0 = 8'd150; g0 = 8'd250; b0 = 8'd255;
        end
    end else begin
        d = vc - HORIZON;                               // 0..~210

        // base sea color, as in menu.rom: blue near the horizon, dark below
        f  = (d > 9'd127) ? 8'd255 : {d[6:0], 1'b0};
        r0 = mix(8'd40,  8'd0,  f);
        g0 = mix(8'd117, 8'd4,  f);
        b0 = mix(8'd169, 8'd46, f);

        // waves in perspective: phase advances with depth and time; the tide
        // pushes the wave field towards the viewer and back
        zf  = depth(d[7:0]);
        z   = zf[11:4];
        // the whole wave field sways left and right with the tide, so the
        // water comes and goes horizontally; less far away (perspective)
        sway = {{2{tide[7]}}, tide} + {{3{tide[7]}}, tide[7:1]};   // -190..190 px
        xs   = $signed({1'b0, hc}) + ((sway * $signed({1'b0, z})) >>> 8);
        // horizontal ripple: higher frequency far away (perspective)
        xp  = xs + 256;                                 // always positive
        u   = xp[10:0] * z;
        xw  = u;
        wob = sin8(u[14:7] + frame[9:2]);
        // all terms as signed integers (tide and wob are signed)
        zi  = zf;
        fr1 = frame[8:1];
        fr0 = frame[9:0];
        ti  = tide;
        wi  = wob;
        phi = ((zi * 3) >>> 2) + fr1 + (ti >>> 1) + (wi >>> 2) + (xs >>> 3);
        ph  = phi[7:0];
        s   = sin8(ph);
        phi = ((zi * 3) >>> 1) + fr0 + (wi >>> 1) + (xs >>> 2);
        ph2 = phi[7:0];
        s2  = sin8(ph2);

        // crests: only the top of the sine, attenuated near the horizon
        // troughs a little darker
        if (s < -8'sd60) begin
            r0 = r0 - (r0 >> 2); g0 = g0 - (g0 >> 2); b0 = b0 - (b0 >> 3);
        end
        if (s > 8'sd60) begin
            crest = (s - 8'sd60) * 2;
            if (d < 9'd32) crest = (crest * d[4:0]) >> 5;
            tmp = r0 + (crest >> 1); r0 = tmp[8] ? 8'd255 : tmp[7:0];
            tmp = g0 + crest;        g0 = tmp[8] ? 8'd255 : tmp[7:0];
            tmp = b0 + crest;        b0 = tmp[8] ? 8'd255 : tmp[7:0];
        end
        if (s2 > 8'sd105 && d > 9'd16) begin
            tmp = g0 + 10'd24; g0 = tmp[8] ? 8'd255 : tmp[7:0];
            tmp = b0 + 10'd24; b0 = tmp[8] ? 8'd255 : tmp[7:0];
        end

        // shore: the water edge moves up and down with the tide
        s3    = sin8(hc[8:1] + frame[10:2]);
        lm    = line_max;
        vi    = vc;
        sh    = lm - 40 - ((ti * 43) >>> 8) + ((s3 * 11) >>> 8);   // tide/6, s3/24
        shore = sh;
        edge_d = vi - sh;
        if (edge_d > 5) begin
            // wet sand near the water, dry sand below
            bl = (edge_d > 36) ? 8'd255 : (edge_d - 5) * 8;
            r0 = mix(8'd150, 8'd214, bl);
            g0 = mix(8'd128, 8'd190, bl);
            b0 = mix(8'd88,  8'd140, bl);
        end else if (edge_d > 0) begin
            // foam at the water edge
            r0 = 8'd235; g0 = 8'd248; b0 = 8'd255;
        end else if (edge_d > -14) begin
            // shallow water: turquoise sheet over the sand
            bl = (edge_d + 14) * 16;
            r0 = mix(r0, 8'd70,  bl);
            g0 = mix(g0, 8'd190, bl);
            b0 = mix(b0, 8'd200, bl);
        end
    end
end

always @(posedge clk) begin
    r <= r0;
    g <= g0;
    b <= b0;
end

endmodule
