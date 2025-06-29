
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

      clkin : in std_logic;

      sw : in std_logic_vector(9 downto 0);

      tx : out std_logic;
      rx : in std_logic;

      sram_addr : out std_logic_vector(17 downto 0);
      sram_dq : inout std_logic_vector(15 downto 0);
      sram_we_n : out std_logic;
      sram_oe_n : out std_logic;
      sram_ub_n : out std_logic;
      sram_lb_n : out std_logic;
      sram_ce_n : out std_logic;

      lpddr2_ca : out std_logic_vector(9 downto 0);
      lpddr2_dq : inout std_logic_vector(31 downto 0);
      lpddr2_dqsp : inout std_logic_vector(3 downto 0);
      lpddr2_dqsn : inout std_logic_vector(3 downto 0);
      lpddr2_dm : out std_logic_vector(3 downto 0);
      lpddr2_ckp : out std_logic;
      lpddr2_ckn : out std_logic;
      lpddr2_cke0 : out std_logic;
      lpddr2_cke1 : out std_logic;
      lpddr2_cs0 : out std_logic;
      lpddr2_cs1 : out std_logic;
      lpddr2_rqz : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

-- ethernet, enc424j600 controller interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;

      clkout : out std_logic;
      clkout2 : out std_logic;
      pod : out std_logic_vector(7 downto 0);

      runbtn : in std_logic;
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
      refclk : in std_logic  := '0';
      rst : in std_logic := '0';
      outclk_0 : out std_logic;
      locked : out std_logic
   );
end component;

-- signal clk : std_logic;

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


signal cpuclk : std_logic;
signal power_on_reset : std_logic := '1';

signal ifetch: std_logic;
signal iwait: std_logic;
signal reset: std_logic;
signal run: std_logic;
signal txtx : std_logic;
signal rxrx : std_logic;

signal addr : std_logic_vector(21 downto 0);
signal addrq : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;
signal sram_match : std_logic;
signal clk : std_logic;

signal cs : std_logic;
signal mosi : std_logic;
signal miso : std_logic;
signal sclk : std_logic;
signal sddebug : std_logic_vector(3 downto 0);

signal c0 : std_logic;

begin

   pll0: pll port map(
      refclk => clkin,
      outclk_0 => c0
   );

--   c0 <= clkin;
   clk <= c0;

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

      have_rl => 1,
      rl_sdcard_cs => cs,
      rl_sdcard_mosi => mosi,
      rl_sdcard_sclk => sclk,
      rl_sdcard_miso => miso,
      rl_sdcard_debug => sddebug,

      have_kl11 => 1,
      rx0 => rx,
      tx0 => txtx,
      kl0_force7bit => 1,

      modelcode => 44,

      clk => cpuclk,
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

   reset <= (not resetbtn) or power_on_reset;
   run <= (not runbtn);

   sdcard_cs <= cs;
   sdcard_mosi <= mosi;
   sdcard_sclk <= sclk;
   miso <= sdcard_miso;

   addrq <= addr;

   greenled <= ifetch & "000" & sddebug;
   tx <= txtx;
   rxrx <= rx;

   sram_match <= '1' when addr(21 downto 19) = "000" else '0';
   sram_addr <= addr(18 downto 1);

   clkout <= cpuclk;
   clkout2 <= ifetch;
   pod(2) <= cpuclk;
   pod(3) <= ifetch;

   lpddr2_ckp <= '0';
   lpddr2_ckn <= '1';
   lpddr2_dqsp <= "0000";
   lpddr2_dqsn <= "1111";
   lpddr2_cs0 <= '1';
   lpddr2_cke0 <= '0';

   process(cpuclk)
   begin
      if cpuclk='1' and cpuclk'event then
         if power_on_reset = '1' then
            power_on_reset <= '0';
         end if;
      end if;
   end process;

   process(clk)
   begin
      if clk='1' and clk'event then

         case clk_fsm is

            when clk_n =>
               clk_fsm <= clk_ne;
               pod(0) <= '0';
               pod(1) <= '0';

-- read
               if sram_match = '1' and control_dati = '1' then
                  pod(0) <= '1';
                  sram_ce_n <= '0';
                  sram_oe_n <= '0';
                  sram_ub_n <= '0';
                  sram_lb_n <= '0';
                  sram_we_n <= '1';
                  sram_dq <= "ZZZZZZZZZZZZZZZZ";
               end if;

-- write
               if sram_match = '1' and control_dato = '1' then
                  pod(1) <= '1';
                  sram_ce_n <= '0';
                  sram_oe_n <= '1';
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
               sram_ce_n <= '1';
               sram_oe_n <= '1';
               sram_we_n <= '1';
               sram_lb_n <= '1';
               sram_ub_n <= '1';
               sram_dq <= "ZZZZZZZZZZZZZZZZ";
            cpuclk <= '1';

            when clk_nw =>
               clk_fsm <= clk_n;

            when clk_idle =>
               clk_fsm <= clk_n;
               sram_ce_n <= '1';
               sram_oe_n <= '1';
               sram_we_n <= '1';
               sram_lb_n <= '1';
               sram_ub_n <= '1';
               sram_dq <= "ZZZZZZZZZZZZZZZZ";

            when others =>
               null;

         end case;

      end if;
   end process;

end implementation;

