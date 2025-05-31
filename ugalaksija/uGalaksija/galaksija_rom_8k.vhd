----------------------------------------------------------------------------------
-- Galaksija ROM (8K) wrapper
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity galaksija_rom_8k is
    Port ( A : in  STD_LOGIC_VECTOR (12 downto 0);
           DO : out  STD_LOGIC_VECTOR (7 downto 0);
           OE_n : in  STD_LOGIC;
           CE_n : in  STD_LOGIC;
			  CLK : in STD_LOGIC);
end galaksija_rom_8k;

architecture rtl of galaksija_rom_8k is
	component rom_mem2 is
		 generic ( AddrWidth : integer := 10;
					  ROMFileName : string := "romfile.txt");
		 Port ( A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
				  DO : out  STD_LOGIC_VECTOR (7 downto 0);
				  OE_n : in  STD_LOGIC;
				  CE_n : in  STD_LOGIC;
				  CLK : in STD_LOGIC);
	end component rom_mem2;
begin
	ROM: rom_mem2
	generic map (AddrWidth => 13, ROMFileName => "./osrom_patched.txt")
	port map (
					A => A,
					DO => DO,
					OE_n => OE_n,
					CE_n => CE_n,
					CLK => CLK
				);
end rtl;

