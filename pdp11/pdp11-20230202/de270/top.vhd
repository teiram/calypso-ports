
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
      xu_srdy : in std_logic;
      xu_debug_tx : out std_logic;

      -- ssram
      sram_addr : out std_logic_vector(18 downto 0);
      sram_dq : inout std_logic_vector(31 downto 0);
      sram_adsc_n : out std_logic;
      sram_adsp_n : out std_logic;
      sram_adv_n : out std_logic;
      sram_be_n0 : out std_logic;
      sram_be_n1 : out std_logic;
      sram_be_n2 : out std_logic;
      sram_be_n3 : out std_logic;
      sram_ce1_n : out std_logic;
      sram_ce2 : out std_logic;
      sram_ce3_n : out std_logic;
      sram_clk : out std_logic;
      sram_dpa0 : out std_logic;
      sram_dpa1 : out std_logic;
      sram_dpa2 : out std_logic;
      sram_dpa3 : out std_logic;
      sram_gw_n : out std_logic;
      sram_oe_n : out std_logic;
      sram_we_n : out std_logic;

      -- board peripherals
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

      sw : in std_logic_vector(17 downto 0);

      key3 : in std_logic;
      key2 : in std_logic;
      key1 : in std_logic;
      key0 : in std_logic;
      clkin : in std_logic
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


signal power_on_reset : std_logic := '1';

signal c0 : std_logic;

signal reset : std_logic;
signal cpuclk : std_logic := '0';
signal cpureset : std_logic := '1';
signal cpuresetlength : integer range 0 to 4095 := 4095;
signal slowreset : std_logic;
signal slowresetdelay : integer range 0 to 4095 := 4095;

signal ifetch: std_logic;
signal iwait: std_logic;
signal txtx : std_logic;
signal rxrx : std_logic;
signal txtx1 : std_logic;
signal rxrx1 : std_logic;
signal txtx2 : std_logic;
signal rxrx2 : std_logic;
signal txtx3 : std_logic;
signal rxrx3 : std_logic;

signal sddebug : std_logic_vector(3 downto 0);

signal addr : std_logic_vector(21 downto 0);
signal addrq : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

signal sram_match : std_logic;
signal sram_ce_n : std_logic;

signal ad_start : std_logic;
signal ad_done : std_logic;
signal ad_channel : std_logic_vector(5 downto 0);
signal ad_nxc : std_logic;
signal ad_sample : std_logic_vector(11 downto 0);
signal ad_type : std_logic_vector(3 downto 0);
signal ad_chgbits : std_logic_vector(3 downto 0);
signal ad_wcgbits : std_logic;

signal ch16type : std_logic_vector(3 downto 0);
signal ch24type : std_logic_vector(3 downto 0);

signal cons_consphy : std_logic_vector(21 downto 0);
signal cons_dr : std_logic_vector(15 downto 0);


begin

   pll0: pll port map(
      inclk0 => clkin,
      c0 => c0
   );

--   c0 <= clkin;

   pdp11: unibus port map(
      modelcode => 70,

      have_kl11 => 1,
      tx0 => txtx,
      rx0 => rxrx,
      kl0_force7bit => 1,

      have_rh => 1,
      rh_sdcard_cs => sdcard_cs,
      rh_sdcard_mosi => sdcard_mosi,
      rh_sdcard_sclk => sdcard_sclk,
      rh_sdcard_miso => sdcard_miso,
      rh_sdcard_debug => sddebug,

      have_xu => 1,
      have_xu_esp => 1,
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,
      xu_srdy => xu_srdy,
      xu_debug_tx => xu_debug_tx,

      cons_consphy => cons_consphy,
      cons_dr => cons_dr,

      addr => addr,
      dati => dati,
      dato => dato,
      control_dati => control_dati,
      control_dato => control_dato,
      control_datob => control_datob,
      addr_match => sram_match,

      ifetch => ifetch,
      iwait => iwait,

      reset => cpureset,
      clk50mhz => clkin,
      clk => cpuclk
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


   sseg7dp <= '1';
   sseg6dp <= '1';
   sseg5dp <= '1';
   sseg4dp <= '1';
   sseg3dp <= '1';
   sseg2dp <= '1';
   sseg1dp <= '1';
   sseg0dp <= '1';

   redled <= "00" & cons_dr;
   addrq <= cons_consphy;
--   console_switches <= sw(15 downto 0);

   greenled(8) <= ifetch;
	greenled(3 downto 0) <= sddebug;

   tx <= txtx;
   rxrx <= rx;
   tx1 <= txtx1;
   rxrx1 <= rx1;

   sram_match <= '1' when addr(21) = '0' else '0';
   sram_addr <= addr(20 downto 2);

   sram_ce1_n <= sram_ce_n;
   sram_ce2 <= not sram_ce_n;
   sram_ce3_n <= sram_ce_n;

   sram_adv_n <= '1';
   sram_gw_n <= '1';

   sram_dpa3 <= '0';
   sram_dpa2 <= '0';
   sram_dpa1 <= '0';
   sram_dpa0 <= '0';

	reset <= not key0;

   process(c0)
   begin
      if c0='1' and c0'event then
         if reset = '1' or power_on_reset = '1' then
            power_on_reset <= '0';
            cpureset <= '1';
            cpuresetlength <= 4095;
         end if;

         case clk_fsm is

            when clk_n =>
               clk_fsm <= clk_ne;
               sram_clk <= '0';

-- read -- set ce etc
               if sram_match = '1' and control_dati = '1' then
                  sram_ce_n <= '0';
                  sram_adsp_n <= '0';
                  sram_adsc_n <= '0';
               end if;

            when clk_ne =>
               clk_fsm <= clk_e;
               sram_clk <= '1';

            when clk_e =>
               clk_fsm <= clk_se;
               sram_clk <= '0';

-- read -- reset ce etc
               if sram_match = '1' and control_dati = '1' then
                  sram_ce_n <= '1';
                  sram_adsp_n <= '1';
                  sram_adsc_n <= '1';
               end if;

-- write -- set ce etc
               if sram_match = '1' and control_dato = '1' then
                  sram_ce_n <= '0';
                  sram_adsp_n <= '0';
                  sram_adsc_n <= '0';
               end if;

            when clk_se =>
               clk_fsm <= clk_s;
               sram_clk <= '1';

               cpuclk <= '0';
               if cpuresetlength = 0 then
                  cpureset <= '0';
               else
                  cpuresetlength <= cpuresetlength - 1;
               end if;

            when clk_s =>
               clk_fsm <= clk_sw;
               sram_clk <= '0';

               if sram_match = '1' and control_dati = '1' then
                  sram_ce_n <= '0';
                  sram_adsp_n <= '0';
                  sram_adsc_n <= '0';
                  sram_oe_n <= '0';
               end if;

               if sram_match = '1' and control_dato = '1' then
                  sram_ce_n <= '1';
                  sram_adsp_n <= '1';
                  sram_adsc_n <= '1';
                  sram_we_n <= '0';
                  sram_dq(15 downto 0) <= dato;
                  sram_dq(31 downto 16) <= dato;
                  if control_datob = '1' then
                     if addr(1) = '0' then
                        if addr(0) = '0' then
                           sram_be_n3 <= '1';
                           sram_be_n2 <= '1';
                           sram_be_n1 <= '1';
                           sram_be_n0 <= '0';
                        else
                           sram_be_n3 <= '1';
                           sram_be_n2 <= '1';
                           sram_be_n1 <= '0';
                           sram_be_n0 <= '1';
                        end if;
                     else
                        if addr(0) = '0' then
                           sram_be_n3 <= '1';
                           sram_be_n2 <= '0';
                           sram_be_n1 <= '1';
                           sram_be_n0 <= '1';
                        else
                           sram_be_n3 <= '0';
                           sram_be_n2 <= '1';
                           sram_be_n1 <= '1';
                           sram_be_n0 <= '1';
                        end if;
                     end if;
                  else
                     if addr(1) = '0' then
                        sram_be_n3 <= '1';
                        sram_be_n2 <= '1';
                        sram_be_n1 <= '0';
                        sram_be_n0 <= '0';
                     else
                        sram_be_n3 <= '0';
                        sram_be_n2 <= '0';
                        sram_be_n1 <= '1';
                        sram_be_n0 <= '1';
                     end if;
                  end if;
               end if;

            when clk_sw =>
               clk_fsm <= clk_w;
               sram_clk <= '1';

            when clk_w =>
               clk_fsm <= clk_nw;
               sram_clk <= '0';
               if sram_match = '1' and control_dato = '1' then
                  sram_we_n <= '1';
                  sram_be_n3 <= '1';
                  sram_be_n2 <= '1';
                  sram_be_n1 <= '1';
                  sram_be_n0 <= '1';
                  sram_dq(31 downto 16) <= "ZZZZZZZZZZZZZZZZ";
                  sram_dq(15 downto 0) <= "ZZZZZZZZZZZZZZZZ";
               end if;

               if sram_match = '1' and control_dati = '1' then
                  if (addr(1) = '0') then
                     dati <= sram_dq(15 downto 0);
                  else
                     dati <= sram_dq(31 downto 16);
                  end if;
                  sram_oe_n <= '1';
               end if;

            when clk_nw =>
               clk_fsm <= clk_n;
               sram_clk <= '1';

               cpuclk <= '1';

            when clk_idle =>
               clk_fsm <= clk_n;

            when others =>
               null;

         end case;

      end if;
   end process;

end implementation;

