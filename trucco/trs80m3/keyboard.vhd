--
-- Multicore 2 / Multicore 2+
--
-- Copyright (c) 2017-2020 - Victor Trucco
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
		
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--

-- PS/2 scancode to TRS-80 matrix conversion
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.keyscans.all;

entity keyboard is
	generic (
		clkfreq		: integer										-- This is the system clock value in kHz
	);
	port (
		clock_i		: in    std_logic;
		por_i			: in    std_logic;
		reset_i		: in    std_logic;
		-- PS/2 interface
		ps2_clk_i	: in std_logic;
		ps2_data_i	: in std_logic;
        ps2_clk_o   : out std_logic;
        ps2_data_o  : out std_logic;
		-- uC interface
		rows_i		: in    std_logic_vector(7 downto 0);
		cols_o		: out   std_logic_vector(7 downto 0);
		teclasF_o	: out   std_logic_vector(12 downto 1)
	);
end entity;

architecture rtl of keyboard is

	-- Interface to PS/2 block
	signal keyb_data    		:   std_logic_vector(7 downto 0);
	signal keyb_valid   		:   std_logic;

	-- Internal signals
	type key_matrix is array (7 downto 0) of std_logic_vector(7 downto 0);
	signal keys     			:   key_matrix;
	signal release  			:   std_logic;
	signal extended 			:   std_logic;
	signal k1, k2, k3, k4,
		k5, k6, k7, k8 		: std_logic_vector(7 downto 0);
	signal idata           	: std_logic_vector(7 downto 0);
	signal idata_rdy       	: std_logic                     := '0';

begin

	-- PS/2 interface
	ps2 : entity work.ps2_iobase
	generic map (
		clkfreq			=> clkfreq
	)
	port map (
		enable_i			=> '1',
		clock_i			=> clock_i,
		reset_i			=> por_i,			-- power-on reset
		ps2_data_i		=> ps2_data_i,
		ps2_clk_i		=> ps2_clk_i,
        ps2_data_o      => ps2_data_o,
        ps2_clk_o       => ps2_clk_o,
		data_rdy_i		=> idata_rdy,
		data_i			=> idata,
		send_rdy_o		=> open,
		data_rdy_o		=> keyb_valid,
		data_o			=> keyb_data
	);

	-- Mesclagem das linhas
	k1 <= keys(0) when rows_i(0) = '1' else (others => '1');
	k2 <= keys(1) when rows_i(1) = '1' else (others => '1');
	k3 <= keys(2) when rows_i(2) = '1' else (others => '1');
	k4 <= keys(3) when rows_i(3) = '1' else (others => '1');
	k5 <= keys(4) when rows_i(4) = '1' else (others => '1');
	k6 <= keys(5) when rows_i(5) = '1' else (others => '1');
	k7 <= keys(6) when rows_i(6) = '1' else (others => '1');
	k8 <= keys(7) when rows_i(7) = '1' else (others => '1');
	cols_o <= not (k1 and k2 and k3 and k4 and k5 and k6 and k7 and k8);

	process (por_i, clock_i)
		variable keyb_valid_edge : std_logic_vector(1 downto 0)	:= "00";
		variable sendresp        : std_logic := '0';
	begin

		if por_i = '1' then

			keyb_valid_edge	:= "00";
			release <= '0';
			extended <= '0';

			keys(0) <= (others => '1');
			keys(1) <= (others => '1');
			keys(2) <= (others => '1');
			keys(3) <= (others => '1');
			keys(4) <= (others => '1');
			keys(5) <= (others => '1');
			keys(6) <= (others => '1');
			keys(7) <= (others => '1');

			teclasF_o <= (others => '0');

		elsif rising_edge(clock_i) then

			keyb_valid_edge := keyb_valid_edge(0) & keyb_valid;

			if keyb_valid_edge = "01" then

				if keyb_data = X"AA" then
					sendresp := '1';
				elsif keyb_data = X"E0" then
					-- Extended key code follows
					extended <= '1';
				elsif keyb_data = X"F0" then
					-- Release code follows
					release <= '1';
				else
					-- Cancel extended/release flags for next time
					release	<= '0';
					extended	<= '0';

					if (extended = '0') then
						-- Normal scancodes
						case keyb_data is

							when KEY_BL				=> keys(0)(0) <= release; -- ' "
							when KEY_A 				=> keys(0)(1) <= release; -- A
							when KEY_B 				=> keys(0)(2) <= release; -- B
							when KEY_C 				=> keys(0)(3) <= release; -- C
							when KEY_D 				=> keys(0)(4) <= release; -- D
							when KEY_E 				=> keys(0)(5) <= release; -- E
							when KEY_F 				=> keys(0)(6) <= release; -- F
							when KEY_G 				=> keys(0)(7) <= release; -- G

							when KEY_H 				=> keys(1)(0) <= release; -- H
							when KEY_I 				=> keys(1)(1) <= release; -- I
							when KEY_J 				=> keys(1)(2) <= release; -- J
							when KEY_K 				=> keys(1)(3) <= release; -- K
							when KEY_L 				=> keys(1)(4) <= release; -- L
							when KEY_M 				=> keys(1)(5) <= release; -- M
							when KEY_N 				=> keys(1)(6) <= release; -- N
							when KEY_O 				=> keys(1)(7) <= release; -- O

							when KEY_P 				=> keys(2)(0) <= release; -- P
							when KEY_Q 				=> keys(2)(1) <= release; -- Q
							when KEY_R 				=> keys(2)(2) <= release; -- R
							when KEY_S 				=> keys(2)(3) <= release; -- S
							when KEY_T 				=> keys(2)(4) <= release; -- T
							when KEY_U 				=> keys(2)(5) <= release; -- U
							when KEY_V 				=> keys(2)(6) <= release; -- V
							when KEY_W 				=> keys(2)(7) <= release; -- W

							when KEY_X 				=> keys(3)(0) <= release; -- X
							when KEY_Y 				=> keys(3)(1) <= release; -- Y
							when KEY_Z      		=> keys(3)(2) <= release; -- Z
							
							when KEY_0 				=> keys(4)(0) <= release; -- 0 )
							when KEY_1 				=> keys(4)(1) <= release; -- 1 !
							when KEY_2 				=> keys(4)(2) <= release; -- 2 @
							when KEY_3 				=> keys(4)(3) <= release; -- 3 #
							when KEY_4 				=> keys(4)(4) <= release; -- 4 $
							when KEY_5 				=> keys(4)(5) <= release; -- 5 %
							when KEY_6 				=> keys(4)(6) <= release; -- 6 ¨
							when KEY_7 				=> keys(4)(7) <= release; -- 7 &

							when KEY_8 				=> keys(5)(0) <= release; -- 8 *
							when KEY_9 				=> keys(5)(1) <= release; -- 9 (
							when KEY_MINUS			=> keys(5)(2) <= release; -- - _
							when KEY_TWOPOINT		=> keys(5)(3) <= release; -- ; :
							when KEY_COMMA			=> keys(5)(4) <= release; -- , <
							when KEY_EQUAL			=> keys(5)(5) <= release; -- = +
							when KEY_POINT			=> keys(5)(6) <= release; -- . >
							when KEY_SLASH			=> keys(5)(7) <= release; -- / ?

							when KEY_ENTER 		=> keys(6)(0) <= release; -- ENTER
							when KEY_ESC			=> keys(6)(1) <= release; -- CLEAR
							when KEY_BACKSPACE	=> keys(6)(5) <= release; -- Backspace
							when KEY_SPACE 		=> keys(6)(7) <= release; -- SPACE

							when KEY_LSHIFT		=> keys(7)(0) <= release; -- Left shift
							when KEY_RSHIFT 		=> keys(7)(1) <= release; -- Right shift

							when KEY_KP0         => keys(4)(0) <= release; -- 0
							when KEY_KP1			=> keys(4)(1) <= release; -- 1
							when KEY_KP2			=> keys(4)(2) <= release; -- 2
							when KEY_KP3			=> keys(4)(3) <= release; -- 3
							when KEY_KP4			=> keys(4)(4) <= release; -- 4
							when KEY_KP5			=> keys(4)(5) <= release; -- 5
							when KEY_KP6			=> keys(4)(6) <= release; -- 6
							when KEY_KP7			=> keys(4)(7) <= release; -- 7
							when KEY_KP8			=> keys(5)(0) <= release; -- 8
							when KEY_KP9			=> keys(5)(1) <= release; -- 9

							when KEY_CAPSLOCK		=> keys(4)(6) <= release; -- 6
														   keys(7)(0) <= release; -- Left shift

--							-- Teclas para o FPGA e nao para o TRS-80
							when KEY_F1				=> teclasF_o(1)	<= not release;
							when KEY_F2				=> teclasF_o(2)	<= not release;
							when KEY_F3				=> teclasF_o(3)	<= not release;
							when KEY_F4				=> teclasF_o(4)	<= not release;
							when KEY_F5				=> teclasF_o(5)	<= not release;
							when KEY_F6				=> teclasF_o(6)	<= not release;
							when KEY_F7				=> teclasF_o(7)	<= not release;
							when KEY_F8				=> teclasF_o(8)	<= not release;
							when KEY_F9				=> teclasF_o(9)	<= not release;
							when KEY_F10			=> teclasF_o(10)	<= not release;
							when KEY_F11			=> teclasF_o(11)	<= not release;
							when KEY_F12			=> teclasF_o(12)	<= not release;

							when others =>
								null;
						end case;
					else
						-- Extended scancodes
						case keyb_data is

							when KEY_HOME	 		=> keys(6)(1) <= release; -- CLEAR
							when KEY_DEL	 		=> keys(6)(2) <= release; -- BREAK

							when KEY_KPENTER 		=> keys(6)(0) <= release; -- ENTER

							-- Cursor keys
							when KEY_UP				=>	keys(6)(3) <= release; -- Up
							when KEY_DOWN			=>	keys(6)(4) <= release; -- Down
							when KEY_LEFT			=>	keys(6)(5) <= release; -- Left
							when KEY_RIGHT			=>	keys(6)(6) <= release; -- Right

							when others =>
								null;
						end case;

					end if; -- if extended = 0

				end if; -- keyb_data = xx

			else -- keyb_valid_edge = 01
				if sendresp = '1' then
					sendresp 	:= '0';
					idata			<= X"55";
					idata_rdy	<= '1';
				else
					idata_rdy	<= '0';
				end if;

			end if; -- keyb_valid_edge = 01

		end if; -- if risingedge

	end process;

end architecture;
