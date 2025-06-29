
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
      redled : out std_logic_vector(9 downto 0);

      sseg5 : out std_logic_vector(6 downto 0);
      sseg4 : out std_logic_vector(6 downto 0);
      sseg3 : out std_logic_vector(6 downto 0);
      sseg2 : out std_logic_vector(6 downto 0);
      sseg1 : out std_logic_vector(6 downto 0);
      sseg0 : out std_logic_vector(6 downto 0);

      clkin : in std_logic;

      sw : in std_logic_vector(9 downto 0);

      tx : out std_logic;
      rx : in std_logic;
      tx1 : out std_logic;
      rx1 : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

      panel_xled : out std_logic_vector(5 downto 0);
      panel_col : inout std_logic_vector(11 downto 0);
      panel_row : out std_logic_vector(2 downto 0);

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

      button0 : in std_logic;
      button1 : in std_logic
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
      inclk0 : in std_logic := '0';
      c0 : out std_logic;
		locked : out std_logic
   );
end component;

signal c0 : std_logic;
signal c0_locked : std_logic;

signal cpuclk : std_logic := '0';
signal cpureset : std_logic := '1';
signal cpuresetlength : integer range 0 to 63 := 63;
signal reset: std_logic := '1';

signal ifetch: std_logic;
signal iwait: std_logic;
signal txtx0 : std_logic;
signal rxrx0 : std_logic;
signal txtx1 : std_logic;
signal rxrx1 : std_logic;

signal addr : std_logic_vector(21 downto 0);
signal addrq : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

signal sddebug : std_logic_vector(3 downto 0);

signal dram_match : std_logic;

signal cons_load : std_logic;
signal cons_exa : std_logic;
signal cons_dep : std_logic;
signal cons_cont : std_logic;
signal cons_ena : std_logic;
signal cons_start : std_logic;
signal cons_sw : std_logic_vector(21 downto 0);
signal cons_adss_mode : std_logic_vector(1 downto 0);
signal cons_adss_id : std_logic;
signal cons_adss_cons : std_logic;

signal cons_consphy : std_logic_vector(21 downto 0);
signal cons_progphy : std_logic_vector(21 downto 0);
signal cons_br : std_logic_vector(15 downto 0);
signal cons_shfr : std_logic_vector(15 downto 0);
signal cons_maddr : std_logic_vector(15 downto 0);
signal cons_dr : std_logic_vector(15 downto 0);
signal cons_parh : std_logic;
signal cons_parl : std_logic;

signal cons_adrserr : std_logic;
signal cons_run : std_logic;
signal cons_pause : std_logic;
signal cons_master : std_logic;
signal cons_kernel : std_logic;
signal cons_super : std_logic;
signal cons_user : std_logic;
signal cons_id : std_logic;
signal cons_map16 : std_logic;
signal cons_map18 : std_logic;
signal cons_map22 : std_logic;
signal cons_reset : std_logic;

begin

   pll0: pll port map(
      inclk0 => clkin,
      c0 => c0,
		locked => c0_locked
   );

   pdp11: unibus port map(
      modelcode => 70,

      have_kl11 => 1,
      kl0_force7bit => 1,
      kl1_force7bit => 1,
      rx0 => rxrx0,
      tx0 => txtx0,
      rx1 => rxrx1,
      tx1 => txtx1,

      have_rh => 1,
      rh_sdcard_cs => sdcard_cs,
      rh_sdcard_mosi => sdcard_mosi,
      rh_sdcard_sclk => sdcard_sclk,
      rh_sdcard_miso => sdcard_miso,
      rh_sdcard_debug => sddebug,

      cons_load => cons_load,
      cons_exa => cons_exa,
      cons_dep => cons_dep,
      cons_cont => cons_cont,
      cons_ena => cons_ena,
      cons_start => cons_start,
      cons_sw => cons_sw,
      cons_adss_mode => cons_adss_mode,
      cons_adss_id => cons_adss_id,
      cons_adss_cons => cons_adss_cons,

      cons_consphy => cons_consphy,
      cons_progphy => cons_progphy,
      cons_shfr => cons_shfr,
      cons_maddr => cons_maddr,
      cons_br => cons_br,
      cons_dr => cons_dr,
      cons_parh => cons_parh,
      cons_parl => cons_parl,

      cons_adrserr => cons_adrserr,
      cons_run => cons_run,
      cons_pause => cons_pause,
      cons_master => cons_master,
      cons_kernel => cons_kernel,
      cons_super => cons_super,
      cons_user => cons_user,
      cons_id => cons_id,
      cons_map16 => cons_map16,
      cons_map18 => cons_map18,
      cons_map22 => cons_map22,

      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
      addr_match => dram_match,

      ifetch => ifetch,
      iwait => iwait,

      reset => cpureset,
      clk50mhz => clkin,
      clk => cpuclk
   );

   panel: paneldriver port map(
      panel_xled => panel_xled,
      panel_col => panel_col,
      panel_row => panel_row,

      cons_load => cons_load,
      cons_exa => cons_exa,
      cons_dep => cons_dep,
      cons_cont => cons_cont,
      cons_ena => cons_ena,
      cons_start => cons_start,
      cons_sw => cons_sw,
      cons_adss_mode => cons_adss_mode,
      cons_adss_id => cons_adss_id,
      cons_adss_cons => cons_adss_cons,

      cons_consphy => cons_consphy,
      cons_progphy => cons_progphy,
      cons_shfr => cons_shfr,
      cons_maddr => cons_maddr,
      cons_br => cons_br,
      cons_dr => cons_dr,
      cons_parh => cons_parh,
      cons_parl => cons_parl,

      cons_adrserr => cons_adrserr,
      cons_run => cons_run,
      cons_pause => cons_pause,
      cons_master => cons_master,
      cons_kernel => cons_kernel,
      cons_super => cons_super,
      cons_user => cons_user,
      cons_id => cons_id,
      cons_map16 => cons_map16,
      cons_map18 => cons_map18,
      cons_map22 => cons_map22,

      cons_reset => cons_reset,

      paneltype => 0,       -- my current test setup doesn't like the console. It might be due to the long cable I have on the de10l... not sure.

      clkin => cpuclk,
      reset => reset
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
      c0 => c0
   );

   ssegd5: ssegdecoder port map(
      i => "0" & addrq(17 downto 15),
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

   rxrx0 <= rx;
   tx <= txtx0;
--   rxrx1 <= rx1;
--   tx1 <= txtx1;

   redled <= '0' & '0' & '0' & ifetch & not rxrx0 & not txtx0 & sddebug;

   dram_match <= '1' when addr(21 downto 18) /= "1111" else '0';

   process(c0)
   begin
      if c0='1' and c0'event then

         if ifetch = '1' then
            addrq <= addr;
         end if;
         
         if button0 = '1' and c0_locked = '1' then
            reset <= '0';
         else
            if button0 = '0' then
               reset <= '1';
            end if;
         end if;

      end if;
   end process;

end implementation;

