
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
      -- pmodhygro
      hg_scl : inout std_logic;
      hg_sda : inout std_logic;

      -- pmodcolor
      co_scl : inout std_logic;
      co_sda : inout std_logic;

      -- pmodnav
      nv_csag : out std_logic;                   -- cs acc/gyro
      nv_mosi : out std_logic;
      nv_miso : in std_logic;
      nv_sclk : out std_logic;
      nv_csm : out std_logic;                    -- cs magnetometer
      nv_csa : out std_logic;                    -- cs altimeter

      -- board leds and switches
      redled : out std_logic_vector(9 downto 0);
      sseg5 : out std_logic_vector(6 downto 0);
      sseg4 : out std_logic_vector(6 downto 0);
      sseg3 : out std_logic_vector(6 downto 0);
      sseg2 : out std_logic_vector(6 downto 0);
      sseg1 : out std_logic_vector(6 downto 0);
      sseg0 : out std_logic_vector(6 downto 0);
      sw : in std_logic_vector(9 downto 0);

      -- vga and ps2
      vgar : out std_logic_vector(3 downto 0);
      vgag : out std_logic_vector(3 downto 0);
      vgab : out std_logic_vector(3 downto 0);
      vgah : out std_logic;
      vgav : out std_logic;
      ps2k_c : in std_logic;
      ps2k_d : in std_logic;

      -- serial ports
      tx : out std_logic;
      rx : in std_logic;
      tx1 : out std_logic;
      rx1 : in std_logic;

      -- sd card
      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;

      -- pidp console
      panel_xled : out std_logic_vector(5 downto 0);
      panel_col : inout std_logic_vector(11 downto 0);
      panel_row : out std_logic_vector(2 downto 0);

      -- dram
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
      button1 : in std_logic;
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
signal txtx : std_logic;
signal rxrx : std_logic;
signal txtx1 : std_logic;
signal rxrx1 : std_logic;
signal txtx2 : std_logic;
signal rxrx2 : std_logic;
signal txtx3 : std_logic;
signal rxrx3 : std_logic;

signal vga_hsync : std_logic;
signal vga_vsync : std_logic;
signal vga_fb : std_logic;
signal vga_ht : std_logic;
signal vga_white : std_logic;
signal vga_amber : std_logic;
signal vga_green : std_logic;
signal rfb : std_logic_vector(3 downto 0);
signal rht : std_logic_vector(3 downto 0);
signal gfb : std_logic_vector(3 downto 0);
signal ght : std_logic_vector(3 downto 0);
signal bfb : std_logic_vector(3 downto 0);
signal bht : std_logic_vector(3 downto 0);
signal act : integer range 1 to 2;

signal addr : std_logic_vector(21 downto 0);
signal addrq : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

signal ad_start : std_logic;
signal ad_done : std_logic;
signal ad_channel : std_logic_vector(5 downto 0);
signal ad_nxc : std_logic;
signal ad_sample : std_logic_vector(11 downto 0);
signal ad_type : std_logic_vector(3 downto 0);
signal ad_chgbits : std_logic_vector(3 downto 0);
signal ad_wcgbits : std_logic;

signal hg_rh : std_logic_vector(13 downto 0);
signal hg_temp : std_logic_vector(13 downto 0);
signal co_clear : std_logic_vector(15 downto 0);
signal co_red : std_logic_vector(15 downto 0);
signal co_green : std_logic_vector(15 downto 0);
signal co_blue : std_logic_vector(15 downto 0);
signal nv_temp : std_logic_vector(11 downto 0);
signal nv_pressure : std_logic_vector(11 downto 0);
signal nv_pressure_f : std_logic_vector(11 downto 0);

signal kw_st1in : std_logic;
signal kw_st2in : std_logic;
signal kw_clkov : std_logic;
signal kw_st1out : std_logic;
signal kw_st2out : std_logic;

signal da_dac0 : std_logic_vector(11 downto 0);
signal da_dac1 : std_logic_vector(11 downto 0);
signal da_dac2 : std_logic_vector(11 downto 0);
signal da_dac3 : std_logic_vector(11 downto 0);
signal di_dir : std_logic_vector(15 downto 0);
signal do_dor : std_logic_vector(15 downto 0);

signal sddebug : std_logic_vector(3 downto 0);

signal dram_match : std_logic;

begin

   pll0: pll port map(
      inclk0 => clkin,
      c0 => c0,
		locked => c0_locked
   );

   adc0: de10ladc port map(
      ad_start => ad_start,
      ad_done => ad_done,
      ad_channel => ad_channel,
      ad_nxc => ad_nxc,
      ad_sample => ad_sample,
      ad_type => ad_type,

      ad_ch8 => hg_rh(13 downto 2),
      ad_ch9 => hg_temp(13 downto 2),
      ad_ch10 => co_clear(15 downto 4),
      ad_ch11 => co_red(15 downto 4),
      ad_ch12 => co_green(15 downto 4),
      ad_ch13 => co_blue(15 downto 4),
      ad_ch24 => nv_pressure,
      ad_ch25 => nv_pressure_f,
      ad_ch26 => nv_temp,

      reset => cpureset,
      clk50mhz => clkin,
      clk => cpuclk
   );

   hg0: pmodhygro port map(
      hg_scl => hg_scl,
      hg_sda => hg_sda,
      hg_rh => hg_rh,
      hg_temp => hg_temp,
      reset => cpureset,
      clk50mhz => clkin
   );

   co0: pmodcolor port map(
      co_scl => co_scl,
      co_sda => co_sda,
      co_clear => co_clear,
      co_red => co_red,
      co_green => co_green,
      co_blue => co_blue,
      reset => cpureset,
      clk50mhz => clkin
   );

   nv0: pmodnav port map(
      nv_csag => nv_csag,
      nv_mosi => nv_mosi,
      nv_miso => nv_miso,
      nv_sclk => nv_sclk,
      nv_csm => nv_csm,
      nv_csa => nv_csa,

      nv_temp => nv_temp,
      nv_pressure => nv_pressure,
      nv_pressure_f => nv_pressure_f,

      reset => reset,
      clk => cpuclk
   );

--   c0 <= clkin;

   pdp11: unibus port map(
      modelcode => 3,
      have_sillies => 1,
      bootrom => boot_minc,

      have_mncad => 1,
      have_mnckw => 2,
      have_mncaa => 1,
      have_mncdi => 1,
      have_mncdo => 1,
      have_ibv11 => 1,

      mncad0_start => ad_start,
      mncad0_done => ad_done,
      mncad0_channel => ad_channel,
      mncad0_nxc => ad_nxc,
      mncad0_sample => ad_sample,
      mncad0_chtype => ad_type,
      mncad0_chgbits => ad_chgbits,
      mncad0_wcgbits => ad_wcgbits,

      mnckw0_st1in => kw_st1in,
      mnckw0_st2in => kw_st2in,
      mnckw0_st1out => kw_st1out,
      mnckw0_st2out => kw_st2out,
      mnckw0_clkov => kw_clkov,

      mncdi0_dir => di_dir,
      mncdo0_dor => do_dor,

      have_kl11 => 4,
      tx0 => txtx,
      rx0 => rxrx,
      kl0_bps => 19200,
      kl0_force7bit => 1,
      tx1 => txtx1,
      rx1 => txtx1,
      kl1_bps => 9600,
      tx2 => txtx2,
      rx2 => txtx2,
      kl2_bps => 1200,
      tx3 => txtx3,
      rx3 => txtx3,
      kl3_bps => 300,

      have_rk => 1,
      rk_sdcard_cs => sdcard_cs,
      rk_sdcard_mosi => sdcard_mosi,
      rk_sdcard_sclk => sdcard_sclk,
      rk_sdcard_miso => sdcard_miso,
      rk_sdcard_debug => sddebug,

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
      vttype => 105,
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      vga_fb => vga_fb,
      vga_ht => vga_ht,

      rx => txtx,
      tx => rxrx,
      bps => 19200,

      ps2k_c => ps2k_c,
      ps2k_d => ps2k_d,

      vga_cursor_block => not sw(0),
      vga_cursor_blink => sw(1),
      teste => sw(2),
      testf => sw(3),

      have_act_seconds => 900,
      have_act => act,

      cpuclk => cpuclk,
      clk50mhz => clkin,
      reset => cpureset
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

   di_dir <= "000000" & sw;
   redled <= do_dor(9 downto 0);
--   redled <= kw_clkov & kw_st1out & kw_st2out & ifetch & not rxrx & not txtx & sddebug;
   kw_st2in <= not button1;

   act <= 2 when sw(4) = '1' else 1;
   vga_white <= '1' when sw(5) = '1' else '0';
   vga_amber <= '1' when sw(6) = '1' else '0';
   vga_green <= '1' when sw(5) = '0' and sw(6) = '0' else '0';
   rfb <= "1111" when vga_white = '1' else "1111" when vga_amber = '1' else "0000";
   rht <= "1000" when vga_white = '1' else "1111" when vga_amber = '1' else "0000";
   gfb <= "1111" when vga_green = '1' or vga_white = '1' else "1110" when vga_amber = '1' else "0000";
   ght <= "1000" when vga_green = '1' or vga_white = '1' else "1101" when vga_amber = '1' else "0000";
   bfb <= "1111" when vga_white = '1' else "0000";
   bht <= "1000" when vga_white = '1' else "0000";
   vgar <= rfb when vga_fb = '1' else rht when vga_ht = '1' else "0000";
   vgag <= gfb when vga_fb = '1' else ght when vga_ht = '1' else "0000";
   vgab <= bfb when vga_fb = '1' else bht when vga_ht = '1' else "0000";
   vgav <= vga_vsync;
   vgah <= vga_hsync;


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

