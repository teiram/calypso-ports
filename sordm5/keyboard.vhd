--//============================================================================
--//  Sord M5
--//  Keyboard matrix maping
--//  Copyright (C) 2021 molekula
--//
--//  This program is free software; you can redistribute it and/or modify it
--//  under the terms of the GNU General Public License as published by the Free
--//  Software Foundation; either version 2 of the License, or (at your option)
--//  any later version.
--//
--//  This program is distributed in the hope that it will be useful, but WITHOUT
--//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
--//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
--//  more details.
--//
--//  You should have received a copy of the GNU General Public License along
--//  with this program; if not, write to the Free Software Foundation, Inc.,
--//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--//
--//============================================================================
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity keyboard is

  port (
   reset_n_i    : in  std_logic;
	 clk_i        : in  std_logic;
	 ps2_code_i   : in  std_logic_vector(10 downto 0);
	 joy0_i       : in  std_logic_vector(5 downto 0);
	 joy1_i       : in  std_logic_vector(5 downto 0);
	 kb_addr_i		: in  std_logic_vector(2 downto 0);
	 kb_data_o		: out std_logic_vector(7 downto 0);
	 kb_rst_o     : out std_logic
  );

end keyboard;


architecture rtl of keyboard is
  type keyMatrixType is array(7 downto 0) of std_logic_vector(7 downto 0);
  signal keyMatrix : keyMatrixType := (others => (others => '0'));
  signal scancode : std_logic_vector(7 downto 0);
  signal resetKey, release, changed : std_logic := '0';
  signal key1, key2, key5, key6: std_logic := '0';
	
begin
  kb_rst_o <= resetKey;
  kb_data_o <= keyMatrix(to_integer(unsigned(kb_addr_i)))(7 downto 0);
    
  change : process (clk_i)
  variable old_code : std_logic_vector(10 downto 0) := (others=>'0');  
  begin
    if clk_i'event and clk_i = '1' then	
      if old_code /= ps2_code_i then
        release <=  ps2_code_i(9);
        scancode <= ps2_code_i(7 downto 0);
        changed <= '1';
      else
        changed <= '0';
      end if;
		  old_code := ps2_code_i;
	  end if;
  end process;
  
  decode : process (clk_i)
  begin
    if clk_i'event and clk_i = '1' then	
	    if changed = '1' then
        case scancode is
          -- port 30
          when x"14" => keyMatrix(0)(0) <= release; -- CTRL
          when x"1f" => keyMatrix(0)(1) <= release; -- FUNC
          when x"12" => keyMatrix(0)(2) <= release; -- L. SHIFT
          when x"59" => keyMatrix(0)(3) <= release; -- R. SHIFT    
          when x"29" => keyMatrix(0)(6) <= release; -- SPACE
          when x"5a" => keyMatrix(0)(7) <= release; -- ENTER
          --- port 31
          when x"16" => key1 <= release; -- 1
          when x"1e" => key2 <= release; -- 2
          when x"26" => keyMatrix(1)(2) <= release; -- 3
          when x"25" => keyMatrix(1)(3) <= release; -- 4
          when x"2e" => key5 <= release; -- 5
          when x"36" => key6 <= release; -- 6
          when x"3d" => keyMatrix(1)(6) <= release; -- 7
          when x"3e" => keyMatrix(1)(7) <= release; -- 8
          --- port 32
          when x"15" => keyMatrix(2)(0) <= release; -- Q
          when x"1d" => keyMatrix(2)(1) <= release; -- W
          when x"24" => keyMatrix(2)(2) <= release; -- E
          when x"2d" => keyMatrix(2)(3) <= release; -- R
          when x"2c" => keyMatrix(2)(4) <= release; -- T
          when x"35" => keyMatrix(2)(5) <= release; -- Y
          when x"3c" => keyMatrix(2)(6) <= release; -- U
          when x"43" => keyMatrix(2)(7) <= release; -- I                  
          --- Port 33
          when x"1c" => keyMatrix(3)(0) <= release; -- A
          when x"1b" => keyMatrix(3)(1) <= release; -- S
          when x"23" => keyMatrix(3)(2) <= release; -- D
          when x"2b" => keyMatrix(3)(3) <= release; -- F
          when x"34" => keyMatrix(3)(4) <= release; -- G
          when x"33" => keyMatrix(3)(5) <= release; -- H
          when x"3b" => keyMatrix(3)(6) <= release; -- J
          when x"42" => keyMatrix(3)(7) <= release; -- K      
          --- Port 34				 
          when x"1a" => keyMatrix(4)(0) <= release; -- Z
          when x"22" => keyMatrix(4)(1) <= release; -- X
          when x"21" => keyMatrix(4)(2) <= release; -- C
          when x"2a" => keyMatrix(4)(3) <= release; -- V
          when x"32" => keyMatrix(4)(4) <= release; -- B
          when x"31" => keyMatrix(4)(5) <= release; -- N
          when x"3a" => keyMatrix(4)(6) <= release; -- M
          when x"41" => keyMatrix(4)(7) <= release; -- ,
          --- port 35
          when x"46" => keyMatrix(5)(0) <= release; -- 9
          when x"45" => keyMatrix(5)(1) <= release; -- 0
          when x"4e" => keyMatrix(5)(2) <= release; -- -
          when x"55" => keyMatrix(5)(3) <= release; -- ^
          when x"49" => keyMatrix(5)(4) <= release; -- .
          when x"4a" => keyMatrix(5)(5) <= release; -- /
          when x"0e" => keyMatrix(5)(6) <= release; -- _
          when x"5d" => keyMatrix(5)(7) <= release; -- \        
          --- Port 36
          when x"44" => keyMatrix(6)(0) <= release; -- O
          when x"4d" => keyMatrix(6)(1) <= release; -- P
          -- when x"" => keyMatrix(6)(2) <= release; -- 
          when x"54" => keyMatrix(6)(3) <= release; -- [
          when x"4b" => keyMatrix(6)(4) <= release; -- L
          when x"4c" => keyMatrix(6)(5) <= release; -- ;
          when x"52" => keyMatrix(6)(6) <= release; -- :
          when x"5b" => keyMatrix(6)(7) <= release; -- ]
          --- multy
          when x"66" => keyMatrix(3)(5) <= release; keyMatrix(0)(0) <= release; -- BACKSPACE       
          when x"76" => resetKey <= release; -- 
          when others =>null; 
        end case;
      end if;
      keyMatrix(7) <= (joy1_i(2)&joy1_i(1)&joy1_i(3)&joy1_i(0)&joy0_i(2)&joy0_i(1)&joy0_i(3)&joy0_i(0));
      keyMatrix(1)(0) <= key1 OR joy0_i(4);
      keyMatrix(1)(1) <= key2 OR joy0_i(5);
      keyMatrix(1)(4) <= key5 OR joy1_i(4);
      keyMatrix(1)(5) <= key6 OR joy1_i(5);
    end if;
  end process;
end; 
