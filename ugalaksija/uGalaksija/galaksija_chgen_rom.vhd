----------------------------------------------------------------------------------
-- Character generator ROM wrapper
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity galaksija_chgen_rom is
    Port ( A : in  STD_LOGIC_VECTOR (10 downto 0);
           DO : out  STD_LOGIC_VECTOR (7 downto 0);
           OE_n : in  STD_LOGIC;
           CE_n : in  STD_LOGIC;
			  CLK : in STD_LOGIC);
end galaksija_chgen_rom;

architecture rtl of galaksija_chgen_rom is
	component rom_mem2 is
		 generic ( AddrWidth : integer := 10;
					  ROMFileName : string := "osrom.txt");
		 Port ( A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
				  DO : out  STD_LOGIC_VECTOR (7 downto 0);
				  OE_n : in  STD_LOGIC;
				  CE_n : in  STD_LOGIC;
				  CLK : in STD_LOGIC);
	end component rom_mem2;
begin

	CH_GEN_ROM: rom_mem2
	generic map( AddrWidth => 11, ROMFileName => "./chrgenrom.txt")
	port map (
					A => A,
					DO => DO,
					OE_n => OE_n,
					CE_n => CE_n,
					CLK => CLK
				);

end rtl;

