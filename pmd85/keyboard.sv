
// Keyboard for PMD85
// following layout from PMD85 emulator 
// https://pmd85.borik.net/wiki/Obr%C3%A1zok:Keyboard_layout_emulator.png

module keyboard (
		input        reset,
		input        clk,
	
		input [10:0] ps2_key,	
		input [3:0] row,
		inout [7:0] columns
);
	
wire pressed = ps2_key[9];
wire  input_strobe = ~ps2_key[8];
wire extended = ps2_key[8];
wire [7:0] code = ps2_key[7:0];	
reg [4:0]keys[14:0];
wire shift;
reg capsLock;
reg shiftL;
reg shiftR;
reg shiftExtra; // used when I need use shift to map extra PC key
reg stop;


assign shift = shiftExtra & ((shiftL & shiftR) ^ capsLock);
assign columns = (~reset) ? {1'b0, stop, shift, keys[row]} : 8'hz;
	

reg old_stb;
reg old_reset = 0;

always @(posedge clk) 
begin
	    
	old_stb <= ps2_key[10];
	old_reset <= reset;
	
	if(~old_reset & reset)
	begin
		keys[00] <= 5'b11111;
		keys[01] <= 5'b11111;
		keys[02] <= 5'b11111;
		keys[03] <= 5'b11111;
		keys[04] <= 5'b11111;
		keys[05] <= 5'b11111;
		keys[06] <= 5'b11111;
		keys[07] <= 5'b11111;
		keys[08] <= 5'b11111;
		keys[09] <= 5'b11111;
		keys[10] <= 5'b11111;
		keys[11] <= 5'b11111;
		keys[12] <= 5'b11111;
		keys[13] <= 5'b11111;
		keys[14] <= 5'b11111;
		
		capsLock <= 0;
		shiftL <= 1;
		shiftR <= 1;
		shiftExtra <= 1;
		stop <= 1;
	end
		
	if(old_stb != ps2_key[10]) 
	begin		
		if (extended) 
		begin
			/* Extended keys */
			case(code)
				8'h7d : keys[14][0] <= ~pressed; // (R)CL = PageUp (E07D)
				8'h70 : keys[12][1] <= ~pressed; // INS (e070)	
				8'h7a : keys[14][1] <= ~pressed; // CLR = PageDown (E07A)		
				8'h6b : keys[12][2] <= ~pressed; // <--- = sipka vlevo (E06b)
				8'h6c : keys[13][2] <= ~pressed; // šikmá <--- vlevo nahoru =  Home (E06C)
				8'h74 : keys[14][2] <= ~pressed; // ---> = sipka vpravo (e074)
				8'h75 : keys[12][3] <= ~pressed; // |<--- = sipka nahoru (e075)
				8'h69 : keys[13][3] <= ~pressed; // END (e069)
				8'h72 : keys[14][3] <= ~pressed; // --->| = sipka dolu (e072)		
				8'h4a : keys[10][4] <= ~pressed; // /	NUMPAD				
				8'h5a : keys[13][4] <= ~pressed; // EOL = ENTER NUMPAD							  
			endcase	
		end
		else
		begin
			/* character keys */		
			case(code)//		
				8'h59: shiftR <= ~pressed; // right shift
				8'h12: shiftL <= ~pressed; // Left shift			
				8'h76 : stop <= ~pressed; //  STOP = ESC		
				8'h58 : if (~pressed) capsLock <= ~capsLock ; //  toggle Caps Lock
	
				// column PB0
				8'h05 : keys[00][0] <= ~pressed; // K0 = F1
				8'h06 : keys[01][0] <= ~pressed; // K1 = F2
				8'h04 : keys[02][0] <= ~pressed; // K2 = F3
				8'h0c : keys[03][0] <= ~pressed; // K3 = F4 
				8'h03 : keys[04][0] <= ~pressed; // K4 = F5 
				8'h0b : keys[05][0] <= ~pressed; // K5 = F6 
				8'h83 : keys[06][0] <= ~pressed; // K6 = F7 
				8'h0a : keys[07][0] <= ~pressed; // K7 = F8 
				8'h01 : keys[08][0] <= ~pressed; // K8 = F9 
				8'h09 : keys[09][0] <= ~pressed; // K9 = F10
				8'h78 : keys[10][0] <= ~pressed; // K10 = F11
//				8'h07 : keys[11][0] <= ~pressed; // K11 = F12			
				8'h0e : keys[12][0] <= ~pressed; // WRK = ~
				8'h0d : keys[13][0] <= ~pressed; // C-D = TAB		
				
			endcase

			case(code)
				// column PB1
				8'h16 : keys[00][1] <= ~pressed; // 1
				8'h69 : keys[00][1] <= ~pressed; // 1 NUMPAD
				8'h1e : keys[01][1] <= ~pressed; // 2
				8'h72 : keys[01][1] <= ~pressed; // 2 NUMPAD
				8'h26 : keys[02][1] <= ~pressed; // 3
				8'h7a : keys[02][1] <= ~pressed; // 3 NUMPAD
				8'h25 : keys[03][1] <= ~pressed; // 4
				8'h6b : keys[03][1] <= ~pressed; // 4 NUMPAD
				8'h2e : keys[04][1] <= ~pressed; // 5
				8'h73 : keys[04][1] <= ~pressed; // 5 NUMPAD
				8'h36 : keys[05][1] <= ~pressed; // 6
				8'h74 : keys[05][1] <= ~pressed; // 6 NUMPAD
				8'h3d : keys[06][1] <= ~pressed; // 7
				8'h6c : keys[06][1] <= ~pressed; // 7 NUMPAD
				8'h3e : keys[07][1] <= ~pressed; // 8
				8'h75 : keys[07][1] <= ~pressed; // 8 NUMPAD
				8'h46 : keys[08][1] <= ~pressed; // 9
				8'h7d : keys[08][1] <= ~pressed; // 9 NUMPAD
				8'h45 : keys[09][1] <= ~pressed; // 0
				8'h70 : keys[09][1] <= ~pressed; // 0 NUMPAD										
				8'h7B : begin
								keys[09][1] <= ~pressed; // -	NUMPAD
								shiftExtra <=  ~pressed; 
						  end				
				8'h4e : keys[10][1] <= ~pressed; // _
				8'h55 : keys[11][1] <= ~pressed; // } = =
				8'h66 : keys[13][1] <= ~pressed; // DEL = Backspace
			endcase

			case(code)
				// column PB2
				8'h15 : keys[00][2] <= ~pressed; // Q
				8'h1d : keys[01][2] <= ~pressed; // W
				8'h24 : keys[02][2] <= ~pressed; // E
				8'h2d : keys[03][2] <= ~pressed; // R
				8'h2c : keys[04][2] <= ~pressed; // T
				8'h1a : keys[05][2] <= ~pressed; // Z
				8'h3c : keys[06][2] <= ~pressed; // U
				8'h43 : keys[07][2] <= ~pressed; // I
				8'h44 : keys[08][2] <= ~pressed; // O
				8'h4d : keys[09][2] <= ~pressed; // P
				8'h54 : keys[10][2] <= ~pressed; // @ = [
				8'h5d : keys[11][2] <= ~pressed; // \
			endcase

			case(code)			
				// column PB3
				8'h1c : keys[00][3] <= ~pressed; // A
				8'h1b : keys[01][3] <= ~pressed; // S
				8'h23 : keys[02][3] <= ~pressed; // D
				8'h2b : keys[03][3] <= ~pressed; // F
				8'h34 : keys[04][3] <= ~pressed; // G
				8'h33 : keys[05][3] <= ~pressed; // H
				8'h3b : keys[06][3] <= ~pressed; // J
				8'h42 : keys[07][3] <= ~pressed; // K
				8'h4b : keys[08][3] <= ~pressed; // L
				8'h4c : keys[09][3] <= ~pressed; // ; +
				8'h79 : begin
								keys[09][3] <= ~pressed; // + NUMPAD
								shiftExtra <=  ~pressed; 
						  end							  
				8'h52 : keys[10][3] <= ~pressed; // : *
				8'h7c : begin
								keys[10][3] <= ~pressed; // * NUMPAD
								shiftExtra <=  ~pressed; 
						  end	
				8'h5b : keys[11][3] <= ~pressed; // ]		
			endcase

			case(code)
				// column PB4
				8'h29 : keys[00][4] <= ~pressed; // Space
				8'h35 : keys[01][4] <= ~pressed; // Y
				8'h22 : keys[02][4] <= ~pressed; // X
				8'h21 : keys[03][4] <= ~pressed; // C
				8'h2a : keys[04][4] <= ~pressed; // V
				8'h32 : keys[05][4] <= ~pressed; // B
				8'h31 : keys[06][4] <= ~pressed; // N
				8'h3a : keys[07][4] <= ~pressed; // M
				8'h41 : keys[08][4] <= ~pressed; // , <
				8'h71 : keys[08][4] <= ~pressed; // , NUMPAD
				8'h49 : keys[09][4] <= ~pressed; // . >
				8'h4a : keys[10][4] <= ~pressed; // /		
				8'h5a : keys[14][4] <= ~pressed; // EOL = ENTER 					 
			endcase	
		end
	end	
end 
 
			
endmodule //keyboard			