
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.pdp2011.all;

entity top is
   port(
      -- console serial port
      rx : in std_logic;
      tx : out std_logic;
      cts : in std_logic;
      rts : out std_logic;
      -- second serial port
      rx1: in std_logic;
      tx1: out std_logic;

      -- sd card
      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

      -- enc424j600 backend for xu
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;
		xu_debug_tx : out std_logic;

      -- dram
		dram_addr13 : out std_logic;
      dram_addr : out std_logic_vector(12 downto 0);
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

      -- board peripherals
      redled : out std_logic_vector(7 downto 0);
      key0 : in std_logic;
      clkin : in std_logic
   );
end top;

architecture implementation of top is

component pll is
   port(
      inclk0 : in std_logic := '0';
      c0 : out std_logic;
		c1 : out std_logic;
		c2 : out std_logic;
		locked : out std_logic
   );
end component;

component m1kadc is
   port(
      ad_start : in std_logic;
      ad_done : out std_logic := '0';
      ad_channel : in std_logic_vector(5 downto 0);
      ad_nxc : out std_logic := '0';
      ad_sample : out std_logic_vector(11 downto 0) := "000000000000";

      clk10mhz : in std_logic;
      clk10mhzlocked : in std_logic;
      clk50mhz : in std_logic;
      clk : in std_logic;
      reset : in std_logic
   );
end component;


signal clk10mhz : std_logic;
signal clk50mhz : std_logic;
signal clkdram : std_logic;
signal plllocked : std_logic;

signal reset: std_logic;
signal cpuclk : std_logic := '0';
signal cpureset : std_logic := '1';
signal cpuresetlength : integer range 0 to 63 := 63;

signal ifetch: std_logic;
signal txtx : std_logic;
signal rxrx : std_logic;
signal txtx1 : std_logic;
signal rxrx1 : std_logic;

signal ad_start : std_logic;
signal ad_done : std_logic;
signal ad_channel : std_logic_vector(5 downto 0);
signal ad_nxc : std_logic;
signal ad_sample : std_logic_vector(11 downto 0);

signal kw_st1in : std_logic;
signal kw_st2in : std_logic;
signal kw_clkov : std_logic;
signal kw_st1out : std_logic;
signal kw_st2out : std_logic;

signal da_dac1 : std_logic_vector(11 downto 0);
signal da_dac2 : std_logic_vector(11 downto 0);
signal da_dac3 : std_logic_vector(11 downto 0);
signal da_dac4 : std_logic_vector(11 downto 0);
signal di_dir : std_logic_vector(15 downto 0);
signal do_dor : std_logic_vector(15 downto 0);

signal sddebug : std_logic_vector(3 downto 0);

signal addr : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

signal dram_match : std_logic;

begin

   pll0: pll port map(
      inclk0 => clkin,
      c0 => clk10mhz,
		c1 => clkdram,
		c2 => clk50mhz,
		locked => plllocked
   );

   adc0: m1kadc port map(
      ad_start => ad_start,
      ad_done => ad_done,
      ad_channel => ad_channel,
      ad_nxc => ad_nxc,
      ad_sample => ad_sample,

      clk10mhz => clk10mhz,
      clk10mhzlocked => plllocked,
      clk50mhz => clk50mhz,
      clk => cpuclk,
      reset => cpureset
   );

   pdp11: unibus port map(
      modelcode => 24,
      have_mncad => 1,
      have_mnckw => 2,
      have_mncaa => 1,
      have_mncdi => 1,
      have_mncdo => 1,

      mncad0_start => ad_start,
      mncad0_done => ad_done,
      mncad0_channel => ad_channel,
      mncad0_nxc => ad_nxc,
      mncad0_sample => ad_sample,
      mnckw0_st2in => kw_st2in,
      mnckw0_st1out => kw_st1out,
      mnckw0_st2out => kw_st2out,
      mnckw0_clkov => kw_clkov,
		mncdi0_dir => di_dir,
		mncdo0_dor => do_dor,

      have_kl11 => 1,
      tx0 => txtx,
      rx0 => rxrx,
      kl0_force7bit => 1,

      have_rk => 1,
      rk_sdcard_cs => sdcard_cs,
      rk_sdcard_miso => sdcard_miso,
      rk_sdcard_mosi => sdcard_mosi,
      rk_sdcard_sclk => sdcard_sclk,
      rk_sdcard_debug => sddebug,

      have_xu => 0,
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,
      xu_debug_tx => xu_debug_tx,

      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
      addr_match => dram_match,

      ifetch => ifetch,
      reset => cpureset,
      clk50mhz => clk50mhz,
      clk => cpuclk
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
      cpureset => cpureset,
      cpuclk => cpuclk,
      c0 => clkdram
   );

   reset <= (not key0) ; -- or power_on_reset;

   tx <= txtx;
   rxrx <= rx;
   tx1 <= txtx1;
   rxrx1 <= rx1;

   redled <= not rxrx1 & not txtx1 & not rxrx & not txtx & sddebug;

   dram_match <= '1' when addr(21 downto 18) /= "1111" else '0';
--   dram_match <= '1' when addr(21 downto 20) /= "11" else '0';

end implementation;

