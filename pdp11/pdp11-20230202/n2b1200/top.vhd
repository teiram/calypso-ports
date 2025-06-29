
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

-- n2b1200 board

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.pdp2011.all;

entity top is
   port(
      led : out std_logic_vector(7 downto 0);
      seg : out std_logic_vector(6 downto 0);
      an : out std_logic_vector(3 downto 0);
      dp : out std_logic;
      clkin : in std_logic;
      sw : in std_logic_vector(7 downto 0);

      tx : out std_logic;
      rx : in std_logic;
      tx2 : out std_logic;
      rx2 : in std_logic;
      cts2 : in std_logic;
      rts2 : out std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

      sdcard2_cs : out std_logic;
      sdcard2_mosi : out std_logic;
      sdcard2_sclk : out std_logic;
      sdcard2_miso : in std_logic;

-- ethernet, enc424j600 controller interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;

      vgar : out std_logic_vector(2 downto 0);
      vgag : out std_logic_vector(2 downto 0);
      vgab : out std_logic_vector(2 downto 1);
      vgah : out std_logic;
      vgav : out std_logic;

      ps2k_c : in std_logic;
      ps2k_d : in std_logic;

      psdram_addr : out std_logic_vector(22 downto 0);
      psdram_data : inout std_logic_vector(15 downto 0);
      psdram_we : out std_logic;
      psdram_oe : out std_logic;
      psdram_ub : out std_logic;
      psdram_lb : out std_logic;
      psdram_cs : out std_logic;
      psdram_cre : out std_logic;
      psdram_adv : out std_logic;
      psdram_clk : out std_logic;
      psdram_wait : in std_logic;

      reset : in std_logic
   );
end top;

architecture implementation of top is

component qsseg is
   port(
      d3 : in std_logic_vector(3 downto 0);
      d2 : in std_logic_vector(3 downto 0);
      d1 : in std_logic_vector(3 downto 0);
      d0 : in std_logic_vector(3 downto 0);
      dp3 : in std_logic;
      dp2 : in std_logic;
      dp1 : in std_logic;
      dp0 : in std_logic;
      seg : out std_logic_vector(6 downto 0);
      an : out std_logic_vector(3 downto 0);
      dp : out std_logic;
      clk : in std_logic;
      reset : in std_logic
   );
end component;

component clkdiv50k is
   port(
      clkin : in std_logic;
      clkout : out std_logic
   );
end component;

component genlineclock is
   port(
      clk50mhz : in std_logic;
      lineclock : out std_logic
   );
end component;

type clk_fsm_type is (
   clk_idle,
   clk_n,
   clk_ne,
   clk_e,
   clk_se,
   clk_s,
   clk_sw,
   clk_w,
   clk_nw
);
signal clk_fsm : clk_fsm_type := clk_idle;

signal lcdclk : std_logic;
signal dummyclk : std_logic;

signal cpuclk : std_logic;
signal ifetch: std_logic;
signal iwait : std_logic;

signal addrq : std_logic_vector(21 downto 0);

signal addr : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;
signal console_switches : std_logic_vector(15 downto 0);
signal console_displays : std_logic_vector(15 downto 0);

signal psdram_match : std_logic;

signal cs : std_logic;
signal mosi : std_logic;
signal miso : std_logic;
signal sclk : std_logic;
signal sddebug : std_logic_vector(3 downto 0);

signal cs2 : std_logic;
signal mosi2 : std_logic;
signal miso2 : std_logic;
signal sclk2 : std_logic;
signal sddebug2 : std_logic_vector(3 downto 0);

signal vga_hsync : std_logic;
signal vga_vsync : std_logic;
signal vga_out : std_logic;
signal txtx0 : std_logic;
signal rxrx0 : std_logic;


begin

   pdp11: unibus port map(
      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
      addr_match => psdram_match,

      ifetch => ifetch,
      iwait => iwait,

      have_rl => 1,
      rl_sdcard_cs => cs,
      rl_sdcard_mosi => mosi,
      rl_sdcard_sclk => sclk,
      rl_sdcard_miso => miso,
      rl_sdcard_debug => sddebug,

      have_kl11 => 1,
      rx0 => rx,
      tx0 => tx,
      kl0_force7bit => 1,
      rx1 => rx2,
      tx2 => tx2,
      rts1 => rts2,
      cts1 => cts2,
      kl1_rtscts => 1,

      have_xu => 0,
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,

      modelcode => 45,
--       have_fp => 0,

      clk => cpuclk,
      clk50mhz => clkin,
      reset => reset
   );

--    tx <= '0';
--    vt0: vt10x port map(
--       vga_hsync => vga_hsync,
--       vga_vsync => vga_vsync,
--       vga_out => vga_out,
--
--       rx => txtx0,
--       tx => rxrx0,
--
--       ps2k_c => ps2k_c,
--       ps2k_d => ps2k_d,
--
--       cpuclk => cpuclk,
--       clk50mhz => clkin,
--       reset => reset
--    );

   qsseg0: qsseg port map(
      d3 => addrq(15 downto 12),
      d2 => addrq(11 downto 8),
      d1 => addrq(7 downto 4),
      d0 => addrq(3 downto 0),
      dp3 => '0',
      dp2 => '0',
      dp1 => '0',
      dp0 => '0',
      seg => seg,
      an => an,
      dp => dp,
      clk => lcdclk,
      reset => reset
   );

   clkdiv2: clkdiv50k port map(
      clkin => clkin,
      clkout => lcdclk
   );

   console_switches <= "0000000000000000";

   sdcard_cs <= cs;
   sdcard_mosi <= mosi;
   sdcard_sclk <= sclk;
   miso <= sdcard_miso;

   sdcard2_cs <= cs2;
   sdcard2_mosi <= mosi2;
   sdcard2_sclk <= sclk2;
   miso2 <= sdcard2_miso;

   led <= sddebug & sddebug2;

   vgag <= "111" when vga_out = '1' else "000";
   vgab <= "00";
   vgar <= "000";
   vgav <= vga_vsync;
   vgah <= vga_hsync;

   psdram_match <= '1' when addr(21 downto 13) /= "111111111" else '0';
--   psdram_match <= '1' when addr(21) = '0' else '0';
   psdram_addr(22) <= '0';
   psdram_addr(21) <= '0';
   psdram_addr(20 downto 0) <= addr(21 downto 1);
   psdram_clk <= '0';
   psdram_adv <= '0';
   psdram_cre <= '0';

   process(clkin)
   begin
      if clkin='1' and clkin'event then

         case clk_fsm is

            when clk_n =>
               clk_fsm <= clk_ne;
-- read
               if psdram_match = '1' and control_dati = '1' then
                  psdram_cs <= '0';
                  psdram_oe <= '0';
                  psdram_ub <= '0';
                  psdram_lb <= '0';
                  psdram_we <= '1';
                  psdram_data <= "ZZZZZZZZZZZZZZZZ";
               end if;

-- blinkenlights
               if control_dati = '1' or control_dato = '1' or control_datob = '1' then
                  addrq <= addr;
               end if;

-- write
               if psdram_match = '1' and control_dato = '1' then
                  psdram_cs <= '0';
                  psdram_oe <= '1';
                  psdram_we <= '0';
                  psdram_data <= dato;
                  if control_datob = '1' then
                     if addr(0) = '0' then
                        psdram_lb <= '0';
                     else
                        psdram_ub <= '0';
                     end if;
                  else
                     psdram_lb <= '0';
                     psdram_ub <= '0';
                  end if;
               end if;

            when clk_ne =>
               clk_fsm <= clk_e;

            when clk_e =>
               clk_fsm <= clk_se;
            cpuclk <= '0';

            when clk_se =>
               clk_fsm <= clk_s;

            when clk_s =>
               clk_fsm <= clk_sw;

               if psdram_match = '1' and control_dati = '1' then
                  dati <= psdram_data;
               end if;

            when clk_sw =>
               clk_fsm <= clk_w;

            when clk_w =>
               clk_fsm <= clk_nw;
               psdram_cs <= '1';
               psdram_oe <= '1';
               psdram_we <= '1';
               psdram_lb <= '1';
               psdram_ub <= '1';
               psdram_data <= "ZZZZZZZZZZZZZZZZ";
            cpuclk <= '1';

            when clk_nw =>
               clk_fsm <= clk_n;

            when clk_idle =>
               clk_fsm <= clk_n;
               psdram_cs <= '1';
               psdram_oe <= '1';
               psdram_we <= '1';
               psdram_lb <= '1';
               psdram_ub <= '1';
               psdram_data <= "ZZZZZZZZZZZZZZZZ";

            when others =>
               null;

         end case;

      end if;
   end process;

end implementation;

