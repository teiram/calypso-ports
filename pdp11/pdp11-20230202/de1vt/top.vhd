
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
      greenled : out std_logic_vector(7 downto 0);
      redled : out std_logic_vector(9 downto 0);

      sseg3 : out std_logic_vector(6 downto 0);
      sseg2 : out std_logic_vector(6 downto 0);
      sseg1 : out std_logic_vector(6 downto 0);
      sseg0 : out std_logic_vector(6 downto 0);

      vgar : out std_logic_vector(3 downto 0);
      vgag : out std_logic_vector(3 downto 0);
      vgab : out std_logic_vector(3 downto 0);
      vgah : out std_logic;
      vgav : out std_logic;

      ps2k_c : in std_logic;
      ps2k_d : in std_logic;

      clkin : in std_logic;

      sw : in std_logic_vector(9 downto 0);

      tx : out std_logic;
      rx : in std_logic;

		tx2 : out std_logic;
		rx2 : in std_logic;

      resetbtn : in std_logic
   );
end top;

architecture implementation of top is

component ssegdecoder is
   port(
      i : in std_logic_vector(3 downto 0);
      idle : in std_logic := '0';
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
signal reset: std_logic;
signal vga_hsync : std_logic;
signal vga_vsync : std_logic;
signal vga_fb : std_logic;
signal vga_ht : std_logic;
signal vga_debug : std_logic_vector(15 downto 0);

signal txtx : std_logic;
signal rxrx : std_logic;


begin
   pll0: pll port map(
      inclk0 => clkin,
      c0 => c0
   );

--   c0 <= clkin;

   vt0: vt10x port map(
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_fb => vga_fb,
      vga_ht => vga_ht,

      rx => rxrx,
      tx => txtx,

      ps2k_c => ps2k_c,
      ps2k_d => ps2k_d,
      teste => sw(0),
      testf => sw(1),
      vga_cursor_block => not sw(2),
      vga_cursor_blink => sw(3),
      vga_debug => vga_debug,
      vga_bl => redled,

      vttype => 105,

      cpuclk => c0,
      clk50mhz => clkin,
      reset => reset
   );

   ssegd3: ssegdecoder port map(
      i => vga_debug(15 downto 12),
      u => sseg3
   );
   ssegd2: ssegdecoder port map(
      i => vga_debug(11 downto 8),
      u => sseg2
   );
   ssegd1: ssegdecoder port map(
      i => vga_debug(7 downto 4),
      u => sseg1
   );
   ssegd0: ssegdecoder port map(
      i => vga_debug(3 downto 0),
      u => sseg0
   );

   reset <= (not resetbtn);

   tx <= txtx when sw(9) = '1' else '1';
   tx2 <= txtx when sw(9) = '0' else '1';
   rxrx <= rx when sw(9) = '1' else rx2;

   vgag <= "1111" when vga_fb = '1' else "1000" when vga_ht = '1' else "0000";
   vgab <= "0000";
   vgar <= "0000";
   vgav <= vga_vsync;
   vgah <= vga_hsync;


end implementation;

