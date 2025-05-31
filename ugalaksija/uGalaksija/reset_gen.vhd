----------------------------------------------------------------------------------
-- Reset circuit
-- Holds RESET_n low for specified number of clock cycles
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity reset_gen is
	 generic (CycleCount : integer := 1000000);
    Port ( RESET_n : out  STD_LOGIC;
           CLK : in  STD_LOGIC);
end reset_gen;

architecture rtl of reset_gen is
	signal Counter : integer := 0;  -- Counts the number of clock cycles
	signal Reset : std_logic := '0';
begin
	process (Clk, Counter, Reset)
	begin
		if (Reset = '0') then
			if (Clk'event) and (Clk = '1') then
				Counter <= Counter + 1;
			end if;
		end if;
	end process;

	Reset <= '0' when (Counter < CycleCount) else
				'1';

	RESET_n <= Reset;
end rtl;

