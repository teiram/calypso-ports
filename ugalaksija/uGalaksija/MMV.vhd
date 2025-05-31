----------------------------------------------------------------------------------
-- Monostable multivibrator emulation
-- Outputs are active for a time specified in clock ticks
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;



entity MMV is
	 generic( Period : integer := 1000);
    Port ( CLK : in  STD_LOGIC;
           TRIG : in  STD_LOGIC;
           Q : out  STD_LOGIC;
           Q_n : out  STD_LOGIC);
end MMV;

architecture rtl of MMV is
	signal dTRIG : std_logic;
	signal Counter : integer;
	signal Load : std_logic := '0';
begin
	process(CLK, Load, Counter)
	begin
		if (Load = '1') then
			Counter <= Period;
		else
			if (CLK'event) and (CLK='1') then
				if Counter>0 then
					Counter <= Counter-1;
				end if;
			end if;
		end if;
	end process;

	process(TRIG, CLK)
	begin
		if (CLK'event) and (CLK = '1') then
			dTRIG <= TRIG;
		end if;
	end process;

	process(dTRIG, TRIG)
	begin
		if (dTRIG = '0') and (TRIG = '1') then
			LOAD <= '1';
		else
			LOAD <= '0';
		end if;
	end process;
	
	Q <= '1' when Counter > 0 else
			'0';
	Q_n <= '0' when Counter > 0 else
			'1';
end rtl;

