
--
-- Copyright (c) 2008-2023 Sytse van Slooten
--
-- Permission is hereby granted to any person obtaining a copy of these VHDL source files and
-- other language source files and associated documentation files ("the materials") to use
-- these materials solely for personal, non-commercial purposes.
-- You are also granted permission to make changes to the materials, on the condition that this
-- copyright notice is retained unchanged.
--
-- The materials are distributed in the hope that they will be useful, but WITHOUT ANY WARRANTY;
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--

-- $Revision$

-- FIXME, this hasn't been tested in a while - I don't have a de2 board...

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.pdp2011.all;

entity top is
   port(
      greenled : out std_logic_vector(8 downto 0);
      redled : out std_logic_vector(17 downto 0);

      sseg7 : out std_logic_vector(6 downto 0);
      sseg7dp : out std_logic;
      sseg6 : out std_logic_vector(6 downto 0);
      sseg6dp : out std_logic;
      sseg5 : out std_logic_vector(6 downto 0);
      sseg5dp : out std_logic;
      sseg4 : out std_logic_vector(6 downto 0);
      sseg4dp : out std_logic;
      sseg3 : out std_logic_vector(6 downto 0);
      sseg3dp : out std_logic;
      sseg2 : out std_logic_vector(6 downto 0);
      sseg2dp : out std_logic;
      sseg1 : out std_logic_vector(6 downto 0);
      sseg1dp : out std_logic;
      sseg0 : out std_logic_vector(6 downto 0);
      sseg0dp : out std_logic;

      clkin : in std_logic;

      sw : in std_logic_vector(17 downto 0);

      tx : out std_logic;
      rx : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

-- ethernet, enc424j600 controller interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;

      dram_addr : out std_logic_vector(12 downto 0);                 -- FIXME, dram_addr(12) isn't defined for de2?
      dram_dq : inout std_logic_vector(15 downto 0);
      dram_ba_1 : out std_logic;
      dram_ba_0 : out std_logic;
      dram_udqm : out std_logic;
      dram_ldqm : out std_logic;
      dram_ras_n : out std_logic;
      dram_cas_n : out std_logic;
      dram_cke : out std_logic;
      dram_clk : out std_logic;
      dram_we_n : out std_logic;
      dram_cs_n : out std_logic;

      resetbtn : in std_logic
   );
end top;

architecture implementation of top is

component ssegdecoder is
	port(
		i : in std_logic_vector(3 downto 0);
		idle : in std_logic;
		u : out std_logic_vector(6 downto 0)
	);
end component;

component pll is
   port(
      inclk0 : in std_logic  := '0';
      c0 : out std_logic
   );
end component;


signal cpuclk : std_logic;
signal cpureset : std_logic;
signal cpuresetlength : integer range 0 to 4095 := 4095;

signal ifetch: std_logic;
signal iwait: std_logic;
signal reset: std_logic;
signal txtx : std_logic;
signal rxrx : std_logic;

signal addr : std_logic_vector(21 downto 0);
signal addrq : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

signal rh_cs : std_logic;
signal rh_mosi : std_logic;
signal rh_miso : std_logic;
signal rh_sclk : std_logic;
signal rh_sddebug : std_logic_vector(3 downto 0);

signal sddebug : std_logic_vector(3 downto 0);

signal power_on_reset : std_logic := '1';

signal c0 : std_logic;

signal slowreset : std_logic;
signal slowresetdelay : integer range 0 to 4095 := 4095;

signal lineclock: std_logic;
signal sluclock: std_logic;


signal cs : std_logic;
signal mosi : std_logic;
signal miso : std_logic;
signal sclk : std_logic;

signal dram_match : std_logic;

begin

   pll0: pll port map(
      inclk0 => clkin,
      c0 => c0
   );
--   c0 <= clkin;

   pdp11: unibus port map(
      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
--      addr_match => sram_match,
      addr_match => dram_match,

      ifetch => ifetch,
      iwait => iwait,

      have_rl => 1,
      rl_sdcard_cs => sdcard_cs,
      rl_sdcard_mosi => sdcard_mosi,
      rl_sdcard_sclk => sdcard_sclk,
      rl_sdcard_miso => sdcard_miso,
      rl_sdcard_debug => sddebug,

      have_xu => 0,
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,

      rx0 => rx,
      tx0 => txtx,
      kl0_force7bit => 1,

      modelcode => 44,

      clk => cpuclk,
      clk50mhz => clkin,
      reset => cpureset
   );

   sdram0: sdram port map(
      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
      dram_match => dram_match,

      dram_addr => dram_addr,
      dram_dq => dram_dq,
      dram_ba_1 => dram_ba_1,
      dram_ba_0 => dram_ba_0,
      dram_udqm => dram_udqm,
      dram_ldqm => dram_ldqm,
      dram_ras_n => dram_ras_n,
      dram_cas_n => dram_cas_n,
      dram_we_n => dram_we_n,
      dram_cs_n => dram_cs_n,
      dram_cke => dram_cke,
      dram_clk => dram_clk,

      reset => reset,
--      ext_reset => cons_reset,
      cpureset => cpureset,
      cpuclk => cpuclk,
      c0 => c0
   );

   ssegd7: ssegdecoder port map(
      i => '0' & '0' & '0' & addrq(21),
      idle => iwait,
      u => sseg7
   );
   ssegd6: ssegdecoder port map(
      i => '0' & addrq(20 downto 18),
      idle => iwait,
      u => sseg6
   );
   ssegd5: ssegdecoder port map(
      i => '0' & addrq(17 downto 15),
      idle => iwait,
      u => sseg5
   );
   ssegd4: ssegdecoder port map(
      i => '0' & addrq(14 downto 12),
      idle => iwait,
      u => sseg4
   );
   ssegd3: ssegdecoder port map(
		i => '0' & addrq(11 downto 9),
      idle => iwait,
		u => sseg3
	);
   ssegd2: ssegdecoder port map(
		i => '0' & addrq(8 downto 6),
      idle => iwait,
		u => sseg2
	);
   ssegd1: ssegdecoder port map(
		i => '0' & addrq(5 downto 3),
      idle => iwait,
		u => sseg1
	);
   ssegd0: ssegdecoder port map(
		i => '0' & addrq(2 downto 0),
      idle => iwait,
		u => sseg0
	);

   reset <= (not resetbtn);

   sseg7dp <= '1';
   sseg6dp <= '1';
   sseg5dp <= '1';
   sseg4dp <= '1';
   sseg3dp <= '1';
   sseg2dp <= '1';
   sseg1dp <= '1';
   sseg0dp <= '1';

   redled <= (others => '0');
   greenled <= ifetch & ifetch & '0' & sw(17) & sw(16) & sddebug;
   tx <= txtx;
   rxrx <= rx;

   dram_match <= '1' when addr(21 downto 18) /= "1111" else '0';

   process(cpuclk)
   begin
      if cpuclk = '1' and cpuclk'event then
         if ifetch = '1' then
            addrq <= addr;
         end if;
      end if;
   end process;

end implementation;

