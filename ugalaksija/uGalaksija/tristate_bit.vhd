----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:42:19 01/19/2010 
-- Design Name: 
-- Module Name:    tristate_bit - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tristate_bit is
    Port ( DIN : in  STD_LOGIC;
           DOUT : out  STD_LOGIC;
           EN_n : in  STD_LOGIC);
end tristate_bit;

architecture rtl of tristate_bit is

begin
	process(EN_n, DIN)
	begin
		if (EN_n = '0') then
			DOUT <= DIN;
		else
			DOUT <= 'Z';
		end if;
	end process;
end rtl;

