--
-- counter2.vhd
--
-- Intel 8253 counter module for #2
-- for MZ-700 on FPGA
--
-- Count only mode 0 and read out counter
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

entity counter2 is
    Port ( DI : in std_logic_vector(7 downto 0);
           DO : out std_logic_vector(7 downto 0);
           WRD : in std_logic;
           WRM : in std_logic;
           KCLK : in std_logic;
		 RD : in std_logic;
           CLK : in std_logic;
           GATE : in std_logic;
           POUT : out std_logic);
end counter2;

architecture Behavioral of counter2 is

--
-- counter
--
signal CREG : std_logic_vector(15 downto 0);
--
-- initialize and read out
--
signal INIV : std_logic_vector(15 downto 0);
signal RL : std_logic_vector(1 downto 0);
signal WUL : std_logic;
signal RUL : std_logic;
--
-- count control
--
signal PO : std_logic;
signal CD : std_logic_vector(15 downto 0);
signal DTEN : std_logic;
signal CEN : std_logic;
signal LEN : std_logic;

begin

	--
	-- Counter latch
	--
	process( KCLK, WRM ) begin
		if( KCLK'event and KCLK='0' and WRM='0' ) then
			if( DI(5 downto 4)="00" ) then
				CD<=CREG;
			else
				RL<=DI(5 downto 4);
			end if;
		end if;
	end process;

	--
	-- Initialize
	--
	process( KCLK, WRD, WRM, DI(5 downto 4) ) begin
		if( KCLK'event and KCLK='0' ) then
			if( WRM='0' ) then
				if( DI(5 downto 4)/="00" ) then
					WUL<='0';
				end if;
			elsif( WRD='0' ) then
				if( RL="01" ) then
					INIV(7 downto 0)<=DI;
					LEN<='1';
					CEN<='1';
				elsif( RL="10" ) then
					INIV(15 downto 8)<=DI;
					LEN<='1';
					CEN<='1';
				elsif( RL="11" ) then
					if( WUL='0' ) then
						INIV(7 downto 0)<=DI;
						WUL<='1';
						LEN<='0';
						CEN<='0';
					else
						INIV(15 downto 8)<=DI;
						WUL<='0';
						LEN<='1';
						CEN<='1';
					end if;
				end if;
			else
				LEN<='0';
			end if;
		end if;
	end process;

	--
	-- Read control
	--
	process( RD, WRM, DI(5 downto 4) ) begin
		if( WRM='0' ) then
			if( DI(5 downto 4)="00" ) then
				DTEN<='1';
			else
				RUL<='0';
			end if;
		elsif( RD'event and RD='1' ) then
			RUL<=not RUL;
			if( DTEN='1' and RUL='1' ) then
				DTEN<='0';
			end if;
		end if;
	end process;

	DO<=CD(7 downto 0)	  when RUL='0' and DTEN='1' else
	    CD(15 downto 8)	  when RUL='1' and DTEN='1' else
	    CREG(7 downto 0)  when RUL='0' and DTEN='0' else
	    CREG(15 downto 8) when RUL='1' and DTEN='0' else (others=>'1');

	--
	-- Count (mode 0)
	--
	process( CLK, WRM, WRD, DI(5 downto 4), RL, WUL ) begin
		if( LEN='1' ) then
			CREG<=INIV;
			PO<='0';
		elsif( CLK'event and CLK='1' ) then
			if( WRM='0' ) then
				if( DI(5 downto 4)/="00" ) then
					PO<='0';
				end if;
			elsif( GATE='1' and CEN='1' ) then
				if( CREG=1 ) then
					PO<='1';
				end if;
				CREG<=CREG-1;
			end if;
		end if;
	end process;

	POUT<=PO;

end Behavioral;
