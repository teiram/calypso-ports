// Dave Wood 2020



module keyboard(
    input clk,
    input clk_en,
    input reset,
    input [1:0] layout,
    input [10:0] ps2_key,
    input [3:0] row,
    input [15:0] joy1,
    input [15:0] joy2,
    output reg [5:0] keyout,
    output reg shift_out,
    output reg ctrl_out,
    output reg repeat_out,
    output reg break_out,
    output reg [1:0] turbo = 2'b00
);

wire [8:0] code = ps2_key[8:0];
reg [5:0] keys [0:9];
reg [5:0] keydata;
reg shift_press = 1'b1;
wire key_strobe = ps2_key[10];
wire key_press = ps2_key[9];
reg left_alt;

//https://github.com/hoglet67/AtomFpga/blob/e72d68a968c0833ed34a4582b6c9f1b58265f5fc/src/ps2kybrd/keyboard.vhd
always @(posedge clk) begin
    keydata <= keys[row];
    //-- 0 U R D L F

    if (row == 4'b0000)
        keyout <= keydata & {1'b1, joy1[3], joy1[0], joy1[2], joy1[1], joy1[4]};
    else
    if (row == 4'b0001)
        keyout <= keydata & {1'b1, joy2[3], joy2[0], joy2[2], joy2[1], joy2[4]};
    else
        keyout <= keydata;
end

always @(posedge clk) begin
    if(reset) begin
        break_out <= 1'b1;
        shift_out <= 1'b1;
        shift_press <= 1'b1;
        ctrl_out <= 1'b1;
        repeat_out <= 1'b1;
        left_alt <= 1'b0;
        keys[0] <= 6'b111111;
        keys[1] <= 6'b111111;
        keys[2] <= 6'b111111;
        keys[3] <= 6'b111111;
        keys[4] <= 6'b111111;
        keys[5] <= 6'b111111;
        keys[6] <= 6'b111111;
        keys[7] <= 6'b111111;
        keys[8] <= 6'b111111;
        keys[9] <= 6'b111111;
        turbo <= 2'b00;
    end

    if (key_strobe)
//	  if(clk_en == 1'b1)
		if (layout == 2'b00) // uk
			if (shift_press)
			begin
				shift_out  <= 1'b1;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (Right alt)	
				'h012, 'h059: 
							begin
								shift_press <= ~key_press;  // Left SHIFT // Right SHIFT
								shift_out  	<= ~key_press;
							end
				'h011: left_alt				<= key_press;   // Left ALT
				'h014, 'h114: ctrl_out		<= ~key_press;  // Left ctrl
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // left sq bracket [
				'h05D: begin
							keys[0][1] 		<= ~key_press;  // # uk only
							shift_out  		<= ~key_press;
						end
					
				'h056, 'h061 : keys[7][0] 	<= ~key_press;  // back slash h056 UK
										
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
//				'h00D: keys[5][0] 			<= ~key_press;  // UP moved to shift 6
				'h058: keys[4][0] 			<= ~key_press;  // Shift Lock (CAPS LOCK)
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx6B: begin
							keys[3][0] 		<= ~key_press;  // LEFT
							shift_out  		<= ~key_press;
						end
				'hx75: keys[2][0] 			<= ~key_press;  // UP
				'hx72: begin
							keys[2][0] 		<= ~key_press;  // DOWN
							shift_out  		<= ~key_press;
						end
				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'h00D: keys[5][1] 			<= ~key_press;  // COPY (TAB)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Backspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h00E: keys[2][1] 			<= ~key_press;  // 1 layout indentifier
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h052: begin
							keys[6][2] 		<= ~key_press;  // ' was shift 7 
							shift_out 		<= ~key_press;
						end
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
//            	'h052: keys[3][2] 			<= ~key_press;  //  : moved to shift ;
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -
			
				'h055: begin
							keys[0][2] 		<= ~key_press;  // = was shift - 
							shift_out 		<= ~key_press;
						end

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
//            	'h055: keys[7][3] 			<= ~key_press;  //  @ moved to shift ' 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
			else
			begin
				shift_out  <= 1'b0;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (Right alt)	
				'h012, 'h059: 
							begin
								shift_press <= ~key_press;  // Left SHIFT // Right SHIFT
								shift_out  	<= ~key_press;
							end
				'h011: left_alt				<= key_press;   // Left ALT
				'h014, 'h114: ctrl_out		<= ~key_press;  // Left ctrl
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // left sq bracket [
					
				'h056, 'h061 : keys[7][0] 	<= ~key_press;  // back slash h056 UK
										
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h036: begin
							keys[5][0] 		<= ~key_press;  // UP now shift 6 or shifted with left alt
							if (left_alt)
								shift_out  	<= ~key_press;
							else
								shift_out  	<= key_press;
						end
				'h058: keys[4][0] 			<= ~key_press;  // LOCK (CAPS LOCK)
				'hx74: begin
							keys[3][0] 		<= ~key_press;  // RIGHT
							shift_out  		<= key_press;
						end
					'hx6B: keys[3][0] 		<= ~key_press;  // LEFT				
					'hx75: begin
							keys[2][0] 		<= ~key_press;  // UP
							shift_out  		<= key_press;
						end
				'hx72: keys[2][0] 			<= ~key_press;  // DOWN
					

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'h00D: keys[5][1] 			<= ~key_press;  // COPY (TAB)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Backspace)

				'h016: keys[2][1] 			<= ~key_press;  // 1 !
				'h01E: keys[1][1] 			<= ~key_press;  // 2 "
//				'h026: keys[0][1] 			<= ~key_press;  // 3 # shift 3 non uk
						
				'h025: keys[9][2] 			<= ~key_press;  // 4 $
				'h02E: keys[8][2] 			<= ~key_press;  // 5 %
			// 6 key moved to up
				'h03D: keys[7][2] 			<= ~key_press;  // 7 originally 6 &
 //           	'h03E: keys[6][2] 			<= ~key_press;  // 8 originally 7 now moved 
				'h046: keys[5][2] 			<= ~key_press;  // 9 originally 8 (
				'h045: if (left_alt)
							keys[3][1] 		<= ~key_press;  // 0 shifted
						else
							keys[4][2] 		<= ~key_press;  // 0 originally 9 )
							
				'h03E: keys[3][2] 			<= ~key_press;  // * shift 8 was shift colon
				'h04C: begin
							keys[3][2] 		<= ~key_press;  // : now shift ;
							shift_out 		<= key_press;
						end
							
				'h055: keys[2][2] 			<= ~key_press;  // shift = was shift semi colon
				'h041: keys[1][2] 			<= ~key_press;  // ,
//            	'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h052: begin 
							keys[7][3] 		<= ~key_press;  // ' shifted for @
							if (left_alt)
								shift_out 	<= ~key_press;
							else
								shift_out 	<= key_press;
						end
					
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
		else
		if (layout == 2'b01) //usa
			if (shift_press)
			begin
            

				shift_out  <= 1'b1;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (Right alt)	
				'h012, 'h059: shift_press  	<= ~key_press;  // Left SHIFT // Right SHIFT
				'h011: left_alt				<= key_press;   // Left ALT
				'h014, 'h114: ctrl_out		<= ~key_press;  // Left ctrl
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // left sq bracket [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash h05d							
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
//				'h00D: keys[5][0] 			<= ~key_press;  // UP moved to shift 6
				'h058: keys[4][0] 			<= ~key_press;  // LOCK (CAPS LOCK)
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx6B: begin
							keys[3][0] 		<= ~key_press;  // LEFT
							shift_out  		<= 1'b0;
						end
				'hx75: keys[2][0] 			<= ~key_press;  // UP
				'hx72: begin
							keys[2][0] 		<= ~key_press;  // DOWN
							shift_out  		<= 1'b0;
						end
				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'h00D: keys[5][1] 			<= ~key_press;  // COPY (TAB)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Backspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h00E: keys[1][1] 			<= ~key_press;  // 2 layout indentifier
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h052: begin
							keys[6][2] 		<= ~key_press;  // '
							shift_out 		<= 1'b0;
						end
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
//            	'h052: keys[3][2] 			<= ~key_press;  //  : moved to shift ;
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -
			
				'h055: begin
							keys[0][2] 		<= ~key_press;  // = was shift - 
							shift_out 		<= 1'b0;
						end

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
//            	'h055: keys[7][3] 			<= ~key_press;  // moved to shift 2 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
			else
			begin
				shift_out  <= 1'b0;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (Right alt)	
				'h012, 'h059: shift_press   <= ~key_press;  // Left SHIFT // Right SHIFT
				'h011: left_alt				<= key_press;   // Left ALT
				'h014, 'h114: ctrl_out		<= ~key_press;  // Left ctrl
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // left sq bracket [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash h05d									
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h036: begin
							keys[5][0] 		<= ~key_press;  // UP
							if (left_alt)
								shift_out  	<= 1'b0;
							else
								shift_out  	<= 1'b1;
						end
				'h058: keys[4][0] 			<= ~key_press;  // LOCK (CAPS LOCK)
				'hx74: begin
							keys[3][0] 		<= ~key_press;  // RIGHT
							shift_out  		<= 1'b1;
						end
					'hx6B: keys[3][0] 		<= ~key_press;  // LEFT				
					'hx75: begin
							keys[2][0] 		<= ~key_press;  // UP
							shift_out  		<= 1'b1;
						end
				'hx72: keys[2][0] 			<= ~key_press;  // DOWN
					

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'h00D: keys[5][1] 			<= ~key_press;  // TAB (COPY)
				'h066: keys[4][1] 			<= ~key_press;  // BACKSPACE (DELETE)

				'h016: keys[2][1] 			<= ~key_press;  // 1 !
				'h052: keys[1][1] 			<= ~key_press;  // ' shifted for "
				'h026: keys[0][1] 			<= ~key_press;  // 3 # shift 3 non uk
						
				'h025: keys[9][2] 			<= ~key_press;  // 4 $
				'h02E: keys[8][2] 			<= ~key_press;  // 5 %
			// 6 key moved to up
				'h03D: keys[7][2] 			<= ~key_press;  // 7 originally 6 &
 //           	'h03E: keys[6][2] 			<= ~key_press;  // 8 originally 7 now moved 
				'h046: keys[5][2] 			<= ~key_press;  // 9 originally 8 (
				'h045: if (left_alt)
							keys[3][1] 		<= ~key_press;  // 0 shifted
						else
							keys[4][2] 		<= ~key_press;  // 0 originally 9 )
							
				'h03E: keys[3][2] 			<= ~key_press;  // shift 8 was shift colon
				'h04C: begin
							keys[3][2] 		<= ~key_press;  // : now shift ;
							shift_out 		<= 1'b1;
						end
							
				'h055: keys[2][2] 			<= ~key_press;  // shift = was shift semi colon
				'h041: keys[1][2] 			<= ~key_press;  // ,
//            	'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h01E: begin 
							keys[7][3] 		<= ~key_press;  // 2 shifted for @
							if (left_alt)
								shift_out 	<= 1'b0;
							else
								shift_out 	<= 1'b1;
						end
					
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
		else
		if (layout == 2'b10) //orig
			if (shift_press)
			begin
            

				shift_out  <= 1'b1;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h011: repeat_out			<= ~key_press;  // Repeat (Left ALT)
				'h012, 'h059: shift_press  	<= ~key_press;  // Left SHIFT // Right SHIFT
//				'h011: left_alt				<= key_press;   // Left ALT
				'h014: ctrl_out				<= ~key_press;  // Left ctrl
				'h114: ctrl_out				<= ~key_press;  // Right ctrl
				
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash 				
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h00D: keys[5][0] 			<= ~key_press;  // UP (TAB)
				'h058: keys[4][0] 			<= ~key_press;  // Shift Lock (CAPS LOCK)
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx75: keys[2][0] 			<= ~key_press;  // UP

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'hx69: keys[5][1] 			<= ~key_press;  // COPY (END)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Bacspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
				'h052: keys[3][2] 			<= ~key_press;  // :(')
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h055: keys[7][3] 			<= ~key_press;  // @ (=) 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
			else
			begin
				shift_out  <= 1'b0;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h011: repeat_out			<= ~key_press;  // Repeat (Left Alt)
				'h012, 'h059: shift_press  	<= ~key_press;  // Left SHIFT // Right SHIFT
				'h014: ctrl_out				<= ~key_press;  // Left ctrl
				'h114: ctrl_out				<= ~key_press;  // Right ctrl
				
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  //  [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash 				
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h00D: keys[5][0] 			<= ~key_press;  // UP (TAB)
				'h058: keys[4][0] 			<= ~key_press;  // CAPS LOCK
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx75: keys[2][0] 			<= ~key_press;  // UP

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'hx69: keys[5][1] 			<= ~key_press;  // COPY (END)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Backspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
				'h052: keys[3][2] 			<= ~key_press;  // :(')
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h055: keys[7][3] 			<= ~key_press;  // @ (=) 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
		else
		if (layout == 2'b11) //game shift and ctrl swapped
            if (shift_press)
			begin
            

				shift_out  <= 1'b1;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (right ALT)
				'h014, 'h059: shift_press  	<= ~key_press;  // Left ctrl // Right SHIFT
//				'h011: left_alt				<= key_press;   // Left ALT
				'h012: ctrl_out				<= ~key_press;  // Left shift
				'h114: ctrl_out				<= ~key_press;  // Right ctrl
				
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  // [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash 				
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h00D: keys[5][0] 			<= ~key_press;  // UP (TAB)
				'h058: keys[4][0] 			<= ~key_press;  // Shift Lock (CAPS LOCK)
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx75: keys[2][0] 			<= ~key_press;  // UP

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'hx69: keys[5][1] 			<= ~key_press;  // COPY (END)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Bacspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
				'h052: keys[3][2] 			<= ~key_press;  // :(')
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h055: keys[7][3] 			<= ~key_press;  // @ (=) 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
			else
			begin
				shift_out  <= 1'b0;
				casex(code)
				'h005: turbo	      		<= 2'b00;  // f1
				'h006: turbo	      		<= 2'b01;  // f2
				'h004: turbo	      		<= 2'b10;  // f3
				'h00C: turbo	      		<= 2'b11;  // f4
				'h009: break_out      		<= ~key_press;  // F10 break			
				'h111: repeat_out			<= ~key_press;  // Repeat (right Alt)
				'h014, 'h059: shift_press  	<= ~key_press;  // Left ctrl // Right SHIFT
				'h012: ctrl_out				<= ~key_press;  // Left shift
				'h114: ctrl_out				<= ~key_press;  // Right ctrl
				
				
				'h029: keys[9][0] 			<= ~key_press;  // space
				'h054: keys[8][0]			<= ~key_press;  //  [
				'h05D: keys[7][0] 			<= ~key_press;  // back slash 				
				'h05B: keys[6][0] 			<= ~key_press;  // ]		
				'h00D: keys[5][0] 			<= ~key_press;  // UP (TAB)
				'h058: keys[4][0] 			<= ~key_press;  // CAPS LOCK
				'hx74: keys[3][0] 			<= ~key_press;  // RIGHT
				'hx75: keys[2][0] 			<= ~key_press;  // UP

				'h05A: keys[6][1] 			<= ~key_press;  // RETURN
				'hx69: keys[5][1] 			<= ~key_press;  // COPY (END)
				'h066: keys[4][1] 			<= ~key_press;  // DELETE (Backspace)
				'h045: keys[3][1] 			<= ~key_press;  // 0
				'h016: keys[2][1] 			<= ~key_press;  // 1
				'h01E: keys[1][1] 			<= ~key_press;  // 2
				'h026: keys[0][1] 			<= ~key_press;  // 3

				'h025: keys[9][2] 			<= ~key_press;  // 4
				'h02E: keys[8][2] 			<= ~key_press;  // 5
				'h036: keys[7][2] 			<= ~key_press;  // 6
				'h03D: keys[6][2] 			<= ~key_press;  // 7
				'h03E: keys[5][2] 			<= ~key_press;  // 8
				'h046: keys[4][2] 			<= ~key_press;  // 9
				'h052: keys[3][2] 			<= ~key_press;  // :(')
				'h04C: keys[2][2] 			<= ~key_press;  // ;
				'h041: keys[1][2] 			<= ~key_press;  // ,
				'h04E: keys[0][2] 			<= ~key_press;  // -

				'h049: keys[9][3] 			<= ~key_press;  // .
				'h04A: keys[8][3] 			<= ~key_press;  // /
				'h055: keys[7][3] 			<= ~key_press;  // @ (=) 
				'h01C: keys[6][3] 			<= ~key_press;  // A
				'h032: keys[5][3] 			<= ~key_press;  // B
				'h021: keys[4][3] 			<= ~key_press;  // C
				'h023: keys[3][3] 			<= ~key_press;  // D
				'h024: keys[2][3] 			<= ~key_press;  // E
				'h02B: keys[1][3] 			<= ~key_press;  // F
				'h034: keys[0][3] 			<= ~key_press;  // G

				'h033: keys[9][4] 			<= ~key_press;  // H
				'h043: keys[8][4] 			<= ~key_press;  // I
				'h03B: keys[7][4] 			<= ~key_press;  // J
				'h042: keys[6][4] 			<= ~key_press;  // K
				'h04B: keys[5][4] 			<= ~key_press;  // L
				'h03A: keys[4][4] 			<= ~key_press;  // M
				'h031: keys[3][4] 			<= ~key_press;  // N
				'h044: keys[2][4] 			<= ~key_press;  // O
				'h04D: keys[1][4] 			<= ~key_press;  // P
				'h015: keys[0][4] 			<= ~key_press;  // Q

				'h02D: keys[9][5] 			<= ~key_press;  // R
				'h01B: keys[8][5] 			<= ~key_press;  // S
				'h02C: keys[7][5] 			<= ~key_press;  // T
				'h03C: keys[6][5] 			<= ~key_press;  // U
				'h02A: keys[5][5] 			<= ~key_press;  // V
				'h01D: keys[4][5] 			<= ~key_press;  // W
				'h022: keys[3][5] 			<= ~key_press;  // X
				'h035: keys[2][5] 			<= ~key_press;  // Y
				'h01A: keys[1][5] 			<= ~key_press;  // Z
				'h076: keys[0][5] 			<= ~key_press;  // ESCAPE
			
			
			
				endcase
			end
			
end

endmodule

