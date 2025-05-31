----------------------------------------------------------------------------------
-- One bit RAM, used for video memory
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ram_bit is
	generic( 
					AddrWidth : integer := 17;
					Capacity : integer := 256*312
				);
    Port ( CLKR : in  STD_LOGIC;
			  CLKW : in STD_LOGIC;
           WR : in  STD_LOGIC;
           ARD : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
			  AWR : in STD_LOGIC_VECTOR(AddrWidth-1 downto 0);
           DIN : in  STD_LOGIC;
           DOUT : out  STD_LOGIC);
end ram_bit;

architecture rtl of ram_bit is
	-- Data types
	type Mem_Image is array(natural range <>) of bit;
--	type Mem_Image is array(natural range <>) of bit_vector(7 downto 0);
	
	-- RAM array
	signal RAM : Mem_Image(0 to Capacity-1);
	
	signal EnableR, EnableW : std_logic;
begin
	
	EnableW <= '1' when (conv_integer(AWR) < Capacity) else
				 '0';

	EnableR <= '1' when (conv_integer(ARD) < Capacity) else
				 '0';

	process(CLKR, ARD, EnableR)
	begin
		if (CLKR'event) and (CLKR = '1') then
			if (EnableR = '1') then
				DOUT <= to_stdulogic(RAM(conv_integer(ARD)));
			else
				DOUT <= '0';
			end if;
		end if;
	end process;

	process(CLKW, WR, AWR, DIN, EnableW)
	begin
		if (CLKW'event) and (CLKW = '1') then
			if (WR = '1') and (EnableW = '1') then
				RAM(conv_integer(AWR)) <= to_bit(DIN);
			end if;
		end if;
	end process;
end rtl;

