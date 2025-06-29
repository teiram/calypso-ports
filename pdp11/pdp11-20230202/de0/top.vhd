
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
      greenled : out std_logic_vector(9 downto 0);

      sseg3 : out std_logic_vector(6 downto 0);
      sseg2 : out std_logic_vector(6 downto 0);
      sseg1 : out std_logic_vector(6 downto 0);
      sseg0 : out std_logic_vector(6 downto 0);

      vgar : out std_logic_vector(3 downto 0);
      vgag : out std_logic_vector(3 downto 0);
      vgab : out std_logic_vector(3 downto 0);
      vgah : out std_logic;
      vgav : out std_logic;

      clkin : in std_logic;

      sw : in std_logic_vector(9 downto 0);

      ps2k_c : in std_logic;
      ps2k_d : in std_logic;

      tx1 : out std_logic;
      rx1 : in std_logic;
      rts1 : out std_logic;
      cts1 : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

-- ethernet, enc424j600 controller interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;
      xu_debug_tx : out std_logic;                                   -- rs232, 115200/8/n/1 debug output from microcode

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

      button1 : in std_logic;
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
      inclk0 : in std_logic := '0';
      c0 : out std_logic
   );
end component;

signal c0 : std_logic;

signal cpuclk : std_logic := '0';
signal cpureset : std_logic := '1';
signal cpuresetlength : integer range 0 to 63 := 63;
signal slowreset : std_logic;
signal slowresetdelay : integer range 0 to 4095 := 4095;
signal vtreset : std_logic := '1';

signal ifetch: std_logic;
signal iwait: std_logic;
signal reset: std_logic;
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

signal have_rl : integer range 0 to 1;
signal rl_cs : std_logic;
signal rl_mosi : std_logic;
signal rl_miso : std_logic;
signal rl_sclk : std_logic;
signal rl_sddebug : std_logic_vector(3 downto 0);

signal have_rk : integer range 0 to 1;
signal rk_cs : std_logic;
signal rk_mosi : std_logic;
signal rk_miso : std_logic;
signal rk_sclk : std_logic;
signal rk_sddebug : std_logic_vector(3 downto 0);

signal have_rh : integer range 0 to 1;
signal rh_cs : std_logic;
signal rh_mosi : std_logic;
signal rh_miso : std_logic;
signal rh_sclk : std_logic;
signal rh_sddebug : std_logic_vector(3 downto 0);

signal sddebug : std_logic_vector(3 downto 0);

signal vga_hsync : std_logic;
signal vga_vsync : std_logic;
signal vga_fb : std_logic;
signal vga_ht : std_logic;

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
      addr_match => dram_match,

      ifetch => ifetch,
      iwait => iwait,

      have_rl => have_rl,
      rl_sdcard_cs => rl_cs,
      rl_sdcard_mosi => rl_mosi,
      rl_sdcard_sclk => rl_sclk,
      rl_sdcard_miso => rl_miso,
      rl_sdcard_debug => rl_sddebug,

      have_rk => have_rk,
      rk_sdcard_cs => rk_cs,
      rk_sdcard_mosi => rk_mosi,
      rk_sdcard_sclk => rk_sclk,
      rk_sdcard_miso => rk_miso,
      rk_sdcard_debug => rk_sddebug,

      have_rh => have_rh,
      rh_sdcard_cs => rh_cs,
      rh_sdcard_mosi => rh_mosi,
      rh_sdcard_sclk => rh_sclk,
      rh_sdcard_miso => rh_miso,
      rh_sdcard_debug => rh_sddebug,

      have_kl11 => 1,
      rx0 => rxrx0,
      tx0 => txtx0,

      have_xu => 0,
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,
      xu_debug_tx => xu_debug_tx,

      modelcode => 44,

      reset => cpureset,
      clk50mhz => clkin,
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
      c0 => c0
   );

   vt0: vt10x port map(
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_fb => vga_fb,
      vga_ht => vga_ht,

      rx => txtx0,
      tx => rxrx0,

      ps2k_c => ps2k_c,
      ps2k_d => ps2k_d,

      vttype => 100,

      cpuclk => cpuclk,
      clk50mhz => clkin,
      reset => vtreset
   );

   ssegd3: ssegdecoder port map(
      i => addrq(15 downto 12),
      idle => iwait,
      u => sseg3
   );
   ssegd2: ssegdecoder port map(
      i => addrq(11 downto 8),
      idle => iwait,
      u => sseg2
   );
   ssegd1: ssegdecoder port map(
      i => addrq(7 downto 4),
      idle => iwait,
      u => sseg1
   );
   ssegd0: ssegdecoder port map(
      i => addrq(3 downto 0),
      idle => iwait,
      u => sseg0
   );


   reset <= (not resetbtn) ; -- or power_on_reset;

   greenled <= not ps2k_c & not ps2k_d & ifetch & not rxrx0 & not txtx1 & not rxrx1 & sddebug;

   tx1 <= txtx1;
   rxrx1 <= rx1;

   sddebug <= rh_sddebug when have_rh = 1 else rl_sddebug when have_rl = 1 else rk_sddebug;
   sdcard_cs <= rh_cs when have_rh = 1 else rl_cs when have_rl = 1 else rk_cs;
   sdcard_mosi <= rh_mosi when have_rh = 1 else rl_mosi when have_rl = 1 else rk_mosi;
   sdcard_sclk <= rh_sclk when have_rh = 1 else rl_sclk when have_rl = 1 else rk_sclk;
   rh_miso <= sdcard_miso;
   rl_miso <= sdcard_miso;
   rk_miso <= sdcard_miso;

   vgag <= "1111" when vga_fb = '1' else "1000" when vga_ht = '1' else "0000";
   vgab <= "0000";
   vgar <= "0000";
   vgav <= vga_vsync;
   vgah <= vga_hsync;

   dram_match <= '1' when addr(21 downto 18) /= "1111" else '0';
--   dram_match <= '1' when addr(21) /= '1' else '0';

   have_rl <= 1;

   process(cpuclk)
   begin
      if cpuclk = '1' and cpuclk'event then
         if ifetch = '1' then
            addrq <= addr;
         end if;
      end if;
   end process;

   process (c0)
   begin
      if c0='1' and c0'event then
         if reset = '1' then
            slowreset <= '1';
            slowresetdelay <= 4095;
         else
            if slowresetdelay = 0 then
               slowreset <= '0';
               vtreset <= '0';
            else
               slowreset <= '1';
               slowresetdelay <= slowresetdelay - 1;
            end if;
         end if;
      end if;
   end process;

end implementation;

