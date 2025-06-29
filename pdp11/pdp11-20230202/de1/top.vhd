
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
--      rts : out std_logic;
--      cts : in std_logic;

      tx2 : out std_logic;
      rx2 : in std_logic;
      rts2 : out std_logic;
      cts2 : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

--       sdcard2_cs : out std_logic;
--       sdcard2_mosi : out std_logic;
--       sdcard2_sclk : out std_logic;
--       sdcard2_miso : in std_logic;

-- ethernet, enc424j600 controller interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;

      sram_addr : out std_logic_vector(17 downto 0);
      sram_dq : inout std_logic_vector(15 downto 0);
      sram_we_n : out std_logic;
      sram_oe_n : out std_logic;
      sram_ub_n : out std_logic;
      sram_lb_n : out std_logic;
      sram_ce_n : out std_logic;

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
signal cpuclk : std_logic;

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

signal cpu_addr_v : std_logic_vector(15 downto 0);

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
signal vga_fb : std_logic;
signal vga_ht : std_logic;

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
signal sram_match : std_logic;
signal data_valid : std_logic;

signal slowreset : std_logic;
signal slowresetdelay : integer range 0 to 4095 := 4095;


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
      addr_match => sram_match,

      ifetch => ifetch,
      iwait => iwait,
      cpu_addr_v => cpu_addr_v,

      have_rl => 1,
      rl_sdcard_cs => cs,
      rl_sdcard_mosi => mosi,
      rl_sdcard_sclk => sclk,
      rl_sdcard_miso => miso,
      rl_sdcard_debug => sddebug,

      have_kl11 => 1,
      rx0 => rxrx,
      tx0 => txtx,
      kl0_force7bit => 1,

      modelcode => 44,

      clk => cpuclk,
      clk50mhz => clkin,
      reset => slowreset
   );

   vt0: vt10x port map(
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_fb => vga_fb,
      vga_ht => vga_ht,

      rx => txtx,
      tx => rxrx,

      ps2k_c => ps2k_c,
      ps2k_d => ps2k_d,

      cpuclk => cpuclk,
      clk50mhz => clkin,
      reset => reset
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


   reset <= (not resetbtn);

   greenled <=  sddebug2 & sddebug;

   sdcard_cs <= cs;
   sdcard_mosi <= mosi;
   sdcard_sclk <= sclk;
   miso <= sdcard_miso;

   vgag <= "1111" when vga_fb = '1' else "1000" when vga_ht = '1' else "0000";
   vgab <= "0000";
   vgar <= "0000";
   vgav <= vga_vsync;
   vgah <= vga_hsync;

   sram_match <= '1' when addr(21 downto 19) = "000" else '0';
   sram_addr <= addr(18 downto 1);

   process(c0)
   begin
      if c0='1' and c0'event then
         case clk_fsm is

            when clk_n =>
               clk_fsm <= clk_ne;
-- read
               if sram_match = '1' and control_dati = '1' then
                  sram_ce_n <= '0';
                  sram_oe_n <= '0';
                  sram_ub_n <= '0';
                  sram_lb_n <= '0';
                  sram_we_n <= '1';
                  sram_dq <= "ZZZZZZZZZZZZZZZZ";
                  addrq <= addr;
               end if;

-- write
               if sram_match = '1' and control_dato = '1' then
                  sram_ce_n <= '0';
                  sram_oe_n <= '1';
               end if;
               if sram_match = '1' and control_dato = '1' then
                  sram_we_n <= '0';
                  sram_dq <= dato;
                  if control_datob = '1' then
                     if addr(0) = '0' then
                        sram_lb_n <= '0';
                     else
                        sram_ub_n <= '0';
                     end if;
                  else
                     sram_lb_n <= '0';
                     sram_ub_n <= '0';
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

               if sram_match = '1' and control_dati = '1' then
                  dati <= sram_dq(15 downto 0);
               end if;

            when clk_sw =>
               clk_fsm <= clk_w;

            when clk_w =>
               clk_fsm <= clk_nw;
               sram_oe_n <= '1';
               sram_ce_n <= '1';
               sram_we_n <= '1';
               sram_lb_n <= '1';
               sram_ub_n <= '1';
               sram_dq <= "ZZZZZZZZZZZZZZZZ";
            cpuclk <= '1';

            when clk_nw =>
               clk_fsm <= clk_n;

            when clk_idle =>
               sram_ce_n <= '1';
               sram_oe_n <= '1';
               sram_we_n <= '1';
               sram_lb_n <= '1';
               sram_ub_n <= '1';
               sram_dq <= "ZZZZZZZZZZZZZZZZ";
               clk_fsm <= clk_n;

            when others =>
               null;

         end case;

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
            else
               slowreset <= '1';
               if clk_fsm = clk_nw then
                  slowresetdelay <= slowresetdelay - 1;
               end if;
            end if;
         end if;
      end if;
   end process;

end implementation;

