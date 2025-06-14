--
-- counter1.vhd
--
-- Intel 8253 counter module for #1
-- for MZ-700 on FPGA
--
-- Count only mode 2
--
-- Nibbles Lab. 2005
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity counter1 is
    Port ( DI : in std_logic_vector(7 downto 0);
           DO : out std_logic_vector(7 downto 0);
           WRD : in std_logic;
           WRM : in std_logic;
           KCLK : in std_logic;
           CLK : in std_logic;
           GATE : in std_logic;
           POUT : out std_logic);
end counter1;

architecture Behavioral of counter1 is

--
-- counter
--
signal CREG : std_logic_vector(15 downto 0);
--
-- initialize
--
signal INIV : std_logic_vector(15 downto 0);
signal RL : std_logic_vector(1 downto 0);
signal PO : std_logic;
signal UL : std_logic;
signal NEWM : std_logic;
--
-- count control
--
signal CEN : std_logic;
signal GT : std_logic;

begin

	--
	-- Counter access mode
	--
	process( KCLK, WRM ) begin
		if( KCLK'event and KCLK='0' and WRM='0' ) then
			RL<=DI(5 downto 4);
		end if;
	end process;

	--
	-- Counter initialize
	--
	process( KCLK ) begin
		if( KCLK'event and KCLK='0' ) then
			if( WRM='0' ) then
				NEWM<='1';
				UL<='0';
			elsif( WRD='0' ) then
				if( RL="01" ) then
					INIV(7 downto 0)<=DI;
					NEWM<='0';
				elsif( RL="10" ) then
					INIV(15 downto 8)<=DI;
					NEWM<='0';
				elsif( RL="11" ) then
					if( UL='0' ) then
						INIV(7 downto 0)<=DI;
						UL<='1';
					else
						INIV(15 downto 8)<=DI;
						UL<='0';
						NEWM<='0';
					end if;
				end if;
			end if;
		end if;
	end process;

	--
	-- Count enable
	--
	CEN<='1' when NEWM='0' and GATE='1' else '0';

	--
	-- Count (mode 2)
	--
	process( CLK ) begin
		if( CLK'event and CLK='1' ) then
			GT<=GATE;
			if( WRM='0' ) then
				PO<='1';
			elsif( (GT='0' and GATE='1') or CREG=1 ) then
				CREG<=INIV;
				PO<='1';
			elsif( CREG=2 ) then
				PO<='0';
				CREG<=CREG-1;
			elsif( CEN='1' ) then
				CREG<=CREG-1;
			end if;
		end if;
	end process;

	POUT<=PO when GATE='1' else '1';

end Behavioral;
