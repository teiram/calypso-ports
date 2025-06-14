--
-- avrrom.vhd
--
-- ROM block for embedded AVR processor
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity avrrom is
	port (
		-- ROM
		address		: in std_logic_vector(12 downto 0);
		clock		: in STD_LOGIC ;
		q			: out std_logic_vector(15 downto 0);
		-- DPRAM
		WADR		: in std_logic_vector(13 downto 0);
		WDAT		: in std_logic_vector(7 downto 0);
		WREN		: in std_logic;
		MODE		: in std_logic);
end avrrom;

architecture Behavioral of avrrom is

signal RAM1_WE : std_logic;
signal RAM2_WE : std_logic;
signal ROM_q : std_logic_vector(15 downto 0);
signal RAM_q : std_logic_vector(15 downto 0);
signal RAM1_q : std_logic_vector(15 downto 0);
signal RAM2_q : std_logic_vector(15 downto 0);

component rom
	port
	(
		address		: in std_logic_vector(7 downto 0);
		clock		: in std_logic;
		q			: out std_logic_vector(15 downto 0)
	);
end component;

component dpram8k
	PORT
	(
		data		: IN std_logic_vector(7 downto 0);
		rdaddress	: IN std_logic_vector(11 downto 0);
		rdclock		: IN std_logic;
		wraddress	: IN std_logic_vector(12 downto 0);
		wrclock		: IN std_logic;
		wren		: IN std_logic  := '1';
		q			: OUT std_logic_vector(15 downto 0)
	);
end component;

--component dpram4k
--	PORT
--	(
--		data		: IN std_logic_vector(7 downto 0);
--		rdaddress	: IN std_logic_vector(10 downto 0);
--		rdclock		: IN std_logic;
--		wraddress	: IN std_logic_vector(11 downto 0);
--		wrclock		: IN std_logic;
--		wren		: IN std_logic  := '1';
--		q			: OUT std_logic_vector(15 downto 0)
--	);
--end component;

begin

	--
	-- Instantiation
	--
	ROM1 : rom port map (
			address	=> address(7 downto 0),
			clock	=> clock,
			q		=> ROM_q);

	RAM1 : dpram8k port map (
			data		=> WDAT,
			rdaddress	=> address(11 downto 0),
			rdclock		=> clock,
			wraddress	=> WADR(12 downto 1)&(not WADR(0)),
			wrclock		=> not clock,
			wren		=> RAM1_WE,
			q			=> RAM1_q);

--	RAM2 : dpram4k port map (
	RAM2 : dpram8k port map (
			data		=> WDAT,
--			rdaddress	=> address(10 downto 0),
			rdaddress	=> address(11 downto 0),
			rdclock		=> clock,
--			wraddress	=> WADR(11 downto 1)&(not WADR(0)),
			wraddress	=> WADR(12 downto 1)&(not WADR(0)),
			wrclock		=> not clock,
			wren	 	=> RAM2_WE,
			q			=> RAM2_q);

	--
	-- Output and Control
	--
	q<=ROM_q when MODE='0' else RAM_q;
	RAM_q<=RAM1_q when address(12)='0' else RAM2_q;
	RAM1_WE<='1' when MODE='0' and WREN='1' and WADR(13)='0' else '0';
	RAM2_WE<='1' when MODE='0' and WREN='1' and WADR(13)='1' else '0';
	
end Behavioral;
