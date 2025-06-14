--
-- pcg.vhd
--
-- MZ-700 PCG module(HAL Laboratory compatible)
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pcg is
    Port (
		PCGA   : out std_logic_vector(10 downto 0);
		PCGD   : out std_logic_vector(7 downto 0);
		PCGWP  : out std_logic;
		PCGCPY : out std_logic;
		CSPCG  : in std_logic;
		WR     : in std_logic;
		A      : in std_logic_vector(1 downto 0);
		DI     : in std_logic_vector(7 downto 0);
		DO     : out std_logic_vector(7 downto 0);
		MCLK   : in std_logic);
end pcg;

architecture Behavioral of pcg is

--
-- PCG
--
signal TMPA : std_logic_vector(7 downto 0);
signal BUFD : std_logic_vector(7 downto 0);
signal CNTL : std_logic_vector(7 downto 0);

begin

	--
	-- Access Registers
	--
	process( MCLK ) begin
		if( MCLK'event and MCLK='1' ) then
			--PCGA(10 downto 8)<=TMPA;
			if( CSPCG='0' and WR='0' ) then
				if( A="00" ) then
					BUFD<=DI;
				elsif( A="01" ) then
					TMPA<=DI;
				elsif( A="10" ) then
					CNTL<=DI;
				end if;
			end if;
		end if;
	end process;
	PCGA<=CNTL(2 downto 0)&TMPA;
	PCGWP<=not CNTL(4);
	PCGCPY<=CNTL(5);
	PCGD<=BUFD;
	DO<=BUFD when CSPCG='0' and A="00" else
		TMPA when CSPCG='0' and A="01" else
		CNTL when CSPCG='0' and A="10" else (others=>'0');

end Behavioral;
