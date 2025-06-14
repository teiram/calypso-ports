--
-- ckgen.vhd
--
-- Generate CPUCLK(3.58MHz) from 21.47727MHz
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

ENTITY ckgen IS
	PORT
	(
		CLK21	: IN	STD_LOGIC;
		CPUCLK	: OUT	STD_LOGIC
	);
END ckgen;

ARCHITECTURE rtl OF ckgen IS

signal DIV3 : std_logic_vector(1 downto 0);
signal CK	: std_logic;

BEGIN

	process( CLK21 ) begin
		if( CLK21'event and CLK21='1' ) then
			if( DIV3="10" ) then
				DIV3<=(others=>'0');
			else
				DIV3<=DIV3+'1';
			end if;
		end if;
	end process;

	process( DIV3(1) ) begin
		if( DIV3(1)'event and DIV3(1)='1' ) then
			CK<=not CK;
		end if;
	end process;
	
	CPUCLK<=CK;

END rtl;
