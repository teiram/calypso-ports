----------------------------------------------------------------------------------
-- Galaksija keyboard emulator
-- PS2 keyboard is the real input
-- but the KR (row select) and KS (column out) emulate the original Galaksija keyboard
-- LINE_IN (when '0') pulls the KR1 line low. If not used, it can be left open
-- since the default value is '1'.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity galaksija_keyboard_v2 is
    Port ( CLK : in  STD_LOGIC;
           PS2_DATA : in  STD_LOGIC;
           PS2_CLK : in  STD_LOGIC;
           LINE_IN : in  STD_LOGIC := '1';
           KR : in  STD_LOGIC_VECTOR (7 downto 0);
           KS : out  STD_LOGIC_VECTOR (7 downto 0);
			  NMI_n : out std_logic;
			  RST_n : out std_logic;
			  ESC : out std_logic;
			  KEY_CODE : out std_logic_vector(7 downto 0);
			  KEY_STROBE : out std_logic;
			  RESET_n : in STD_LOGIC
			  );
end galaksija_keyboard_v2;

architecture rtl of galaksija_keyboard_v2 is
	component keyboard IS
		PORT(	keyboard_clk, keyboard_data, clock , 
				reset, read		: IN	STD_LOGIC;
				scan_code		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
				scan_ready		: OUT	STD_LOGIC);
	end component keyboard;
	
	signal kbd_rd : std_logic; -- read scancode from keyboard
	signal scan_code, scan_code_int : std_logic_vector(7 downto 0);
	signal scan_ready, scan_ready_int : std_logic;
	
	type arr is array(0 to 63) of std_logic;
	-- Galaksija keyboard array row col
	signal key_array : arr := X"FFFFFFFFFFFFFFFF";	
	
	signal KR_bin : std_logic_vector(2 downto 0);
	
	signal row, col : std_logic_vector(2 downto 0);
	signal set, clr : std_logic;
	
	signal special, special_set, special_clr : std_logic := '0';
	
	type STATES is (WAIT_CODE, RELEASE);
	signal CState, NState : STATES := WAIT_CODE;
	
	signal CTRL, ALT, DEL : std_logic := '0';

	signal SHIFT_RIGHT : std_logic := '0';
	
	signal ESC_STATE : std_logic := '0';
begin
		PS2KEYBOARD: keyboard
		port map (
						keyboard_clk => PS2_CLK,
						keyboard_data => PS2_DATA,
						clock => CLK,
						reset => RESET_n,
						read => kbd_rd,
						scan_code => scan_code_int,
						scan_ready => scan_ready_int
					);

		-- scan_ready_int has asynchronous reset
		process(scan_ready_int, CLK)
		begin
			if (CLK'event) and (CLK='1') then
				scan_ready <= scan_ready_int;
				scan_code <= scan_code_int;
			end if;
		end process;
		
		
		-- Encoder for KR
		process (KR)
		begin
			case KR is
				when "11111110" => KR_bin <= "000";
				when "11111101" => KR_bin <= "001";
				when "11111011" => KR_bin <= "010";
				when "11110111" => KR_bin <= "011";
				when "11101111" => KR_bin <= "100";
				when "11011111" => KR_bin <= "101";
				when "10111111" => KR_bin <= "110";
				when "01111111" => KR_bin <= "111";
				when others => KR_bin <= "000";
			end case;
		end process;
		
		-- Galaksija keyboard array
		process(KR_bin, row, col, set, clr, CLK, LINE_IN, key_array)
		begin
			if (LINE_IN = '1') then
				if (KR_bin /= "000") then
					KS(0) <= key_array(conv_integer("000" & KR_bin));
				else
					KS(0) <= '1';
				end if;
			else
				KS(0) <= '0';
			end if;
			KS(1) <= key_array(conv_integer("001" & KR_bin));
			KS(2) <= key_array(conv_integer("010" & KR_bin));
			KS(3) <= key_array(conv_integer("011" & KR_bin));
			KS(4) <= key_array(conv_integer("100" & KR_bin));
			KS(5) <= key_array(conv_integer("101" & KR_bin));
			KS(6) <= key_array(conv_integer("110" & KR_bin));
			KS(7) <= key_array(conv_integer("111" & KR_bin));
			
			if (CLK'event) and (CLK = '1') then
				if (set = '1') then
					key_array(conv_integer(row & col)) <= '1';
				elsif (clr = '1') then
					key_array(conv_integer(row & col)) <= '0';
				end if;
			end if;
		end process;
		
		-- Bit for special characters
		process(special_set, special_clr, CLK)
		begin
			if (CLK'event) and (CLK = '1') then
				if (special_clr = '1') then
					special <= '0';
				elsif (special_set = '1') then
					special <= '1';
				end if;
			end if;
		end process;

		-- Capture special codes
		process(scan_code, scan_ready)
		begin
			if (scan_ready = '1') then
				if (scan_code = X"E0") then
					special_set <= '1';
				else
					special_set <= '0';
				end if;
			else
				special_set <= '0';
			end if;
		end process;

		-- State machine state propagation
		process(CLK, NState, RESET_n)
		begin
			if (RESET_n = '0') then
				CState <= WAIT_CODE;
			else
				if (CLK'event) and (CLK = '1') then
					CState <= NState;
				end if;
			end if;
		end process;
		
		-- State machine
		process(CState, scan_code, scan_ready)
		begin
			case CState is
				when WAIT_CODE =>
					set <= '0';
					special_clr <= '0';
					if (scan_ready = '1') then
						kbd_rd <= '1';
						if (scan_code = X"F0") then
							NState <= RELEASE;
							clr <= '0';
						else
							NState <= WAIT_CODE;
							clr <= '1';
						end if;
					else
						kbd_rd <= '0';
						clr <= '0';
						NState <= WAIT_CODE;
					end if;
				when RELEASE =>
					clr <= '0';
					if (scan_ready = '1') then
						kbd_rd <= '1';
						set <= '1';
						NState <= WAIT_CODE;
						special_clr <= '1';
					else
						kbd_rd <= '0';
						set <= '0';
						NState <= RELEASE;
						special_clr <= '0';
					end if;
			end case;
		end process;

		
		-- Generate row & col for keyboard from received scan code & special flag
		process(special, scan_code)
		begin
			if (special = '0') then
				case scan_code is
					when X"1C" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(0, 3);	-- A
					when X"32" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(0, 3);	-- B
					when X"21" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(0, 3);	-- C
					when X"23" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(0, 3);	-- D
					when X"24" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(0, 3);	-- E
					when X"2B" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(0, 3);	-- F
					when X"34" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(0, 3);	-- G
					

					when X"33" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(1, 3);	-- H
					when X"43" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(1, 3);	-- I
					when X"3B" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(1, 3);	-- J
					when X"42" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(1, 3);	-- K
					when X"4B" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(1, 3);	-- L
					when X"3A" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(1, 3);	-- M
					when X"31" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(1, 3);	-- N
					when X"44" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(1, 3);	-- O
				
					when X"4D" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(2, 3);	-- P
					when X"15" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(2, 3);	-- Q
					when X"2D" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(2, 3);	-- R
					when X"1B" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(2, 3);	-- S
					when X"2C" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(2, 3);	-- T
					when X"3C" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(2, 3);	-- U
					when X"2A" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(2, 3);	-- V
					when X"1D" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(2, 3);	-- W
				
					when X"22" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(3, 3);	-- X
					when X"35" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(3, 3);	-- Y
					when X"1A" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(3, 3);	-- Z
					
					when X"29" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(3, 3);	-- SPACE
				
					when X"45" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(4, 3);	-- 0
					when X"16" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(4, 3);	-- 1
					when X"1E" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(4, 3);	-- 2
					when X"26" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(4, 3);	-- 3
					when X"25" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(4, 3);	-- 4
					when X"2E" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(4, 3);	-- 5
					when X"36" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(4, 3);	-- 6
					when X"3D" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(4, 3);	-- 7
				

					when X"3E" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(5, 3);	-- 8
					when X"46" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(5, 3);	-- 9
					when X"4C" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(5, 3);	-- ;
					when X"54" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(5, 3);	-- : (PS2 equ = [)
					when X"41" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(5, 3);	-- ,
					when X"55" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(5, 3);	-- =
					
					when X"71" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(5, 3);	-- .
					when X"49" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(5, 3);	-- .
					
	
					when X"5A" => row <= conv_std_logic_vector(0, 3); col <= conv_std_logic_vector(6, 3);	-- ret
					
					when X"12" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(6, 3);	-- shift (left)
					when X"59" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(6, 3);	-- shift (right)
				
				
					when X"4A" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(5, 3);	-- /							
					
					when others => row <= "111"; col <= "111";
				end case;
			else
				case scan_code is
					when X"75" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(3, 3);	-- UP
					when X"72" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(3, 3);	-- DOWN
					when X"6B" => row <= conv_std_logic_vector(5, 3); col <= conv_std_logic_vector(3, 3);	-- LEFT
					when X"74" => row <= conv_std_logic_vector(6, 3); col <= conv_std_logic_vector(3, 3);	-- RIGHT
			
			
					when X"4A" => row <= conv_std_logic_vector(7, 3); col <= conv_std_logic_vector(5, 3);	-- /			


					when X"69" => row <= conv_std_logic_vector(1, 3); col <= conv_std_logic_vector(6, 3);	-- brk = end
					when X"6C" => row <= conv_std_logic_vector(2, 3); col <= conv_std_logic_vector(6, 3);	-- rpt = home
					when X"71" => row <= conv_std_logic_vector(3, 3); col <= conv_std_logic_vector(6, 3);	-- del
					when X"7D" => row <= conv_std_logic_vector(4, 3); col <= conv_std_logic_vector(6, 3);	-- lst = page up
					
					when others => row <= "111"; col <= "111";
				end case;
			end if;
		end process;

		-- CTRL, ALT and DEL
		process (CLK, set, clr, scan_code)
		begin
			if (CLK'event) and (CLK = '1') then
				
				if (scan_code = X"14") then
					if (clr = '1') then
						CTRL <= '1';
					elsif (set = '1') then
						CTRL <= '0';
					end if;
				end if;

				if (scan_code = X"11") then
					if (clr = '1') then
						ALT <= '1';
					elsif (set = '1') then
						ALT <= '0';
					end if;
				end if;

				if (scan_code = X"71") then
					if (clr = '1') then
						DEL <= '1';
					elsif (set = '1') then
						DEL <= '0';
					end if;
				end if;

				if (scan_code = X"59") then
					if (clr = '1') then
						SHIFT_RIGHT <= '1';
					elsif (set = '1') then
						SHIFT_RIGHT <= '0';
					end if;
				end if;
			end if;
		end process;

	process(CTRL, ALT, DEL, SHIFT_RIGHT, CLK)
	begin
		if (CLK'event) and (CLK = '1') then
			if ((CTRL = '1') and (ALT = '1') and (SHIFT_RIGHT = '1')) then
				NMI_n <= '0';
			else
				NMI_n <= '1';
			end if;
	
			if ((CTRL = '1') and (ALT = '1') and (DEL = '1')) then
				RST_n <= '0';
			else
				RST_n <= '1';
			end if;
		end if;
	end process;

	--
	-- Process ESC key
	--
	
	process(CLK, scan_ready, scan_code, ESC_STATE)
	begin
		if (CLK'event) and (CLK='1') then
			if (set = '1') and (scan_code = X"76") then
				ESC_STATE <= not ESC_STATE;
			end if;
		end if;	
	end process;
	ESC <= ESC_STATE;

	process(CLK, special, scan_code, clr)
	begin
		if (CLK'event) and (CLK='1') then
			KEY_CODE <= special & scan_code(6 downto 0);
			KEY_STROBE <= clr;
		end if;
	end process;
end rtl;

