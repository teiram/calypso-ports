
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

      -- pidp11 console
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

      -- pmodda2
      da2_dina0 : out std_logic;
      da2_dinb0 : out std_logic;
      da2_sclk0 : out std_logic;
      da2_sync0 : out std_logic;

      -- pmodda4
      da4_cs : out std_logic;
      da4_mosi : out std_logic;
      da4_sclk : out std_logic;

      -- miodi
      mi0_scl : inout std_logic;
      mi0_sda : inout std_logic;

      -- miodo
      mo0_scl : inout std_logic;
      mo0_sda : inout std_logic;
      mo1_scl : inout std_logic;
      mo1_sda : inout std_logic;

      -- kw
      mnckw0_st1in : in std_logic;
      mnckw0_st1out : out std_logic;
      mnckw0_st2in : in std_logic;
      mnckw0_st2out : out std_logic;
      mnckw0_clkov : out std_logic;

      -- board peripherals
      adc_cs_n : out std_logic;
      adc_saddr : out std_logic;
      adc_sdat : in std_logic;
      adc_sclk : out std_logic;

      adxl345_scl : inout std_logic;
      adxl345_sda : inout std_logic;
      adxl345_cs : out std_logic;

      sw : in std_logic_vector(3 downto 0);
      greenled : out std_logic_vector(7 downto 0);
      key0 : in std_logic;
      key1 : in std_logic;
      clkin : in std_logic
   );
end top;

architecture implementation of top is

component de0nadc is
   port(
      ad_start : in std_logic;
      ad_done : out std_logic := '0';
      ad_channel : in std_logic_vector(5 downto 0);
      ad_nxc : out std_logic := '0';
      ad_sample : out std_logic_vector(11 downto 0);
      ad_type : out std_logic_vector(3 downto 0);

      ad_ch8 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch9 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch10 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch11 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch12 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch13 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch14 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch15 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch16 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch17 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch18 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch19 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch20 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch21 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch22 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch23 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch24 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch25 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch26 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch27 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch28 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch29 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch30 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch31 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch32 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch33 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch34 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch35 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch36 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch37 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch38 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch39 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch40 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch41 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch42 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch43 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch44 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch45 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch46 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch47 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch48 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch49 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch50 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch51 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch52 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch53 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch54 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch55 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch56 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch57 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch58 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch59 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch60 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch61 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch62 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch63 : in std_logic_vector(11 downto 0) := "000000000000";

      ad_ch8_15 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch16_23 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch24_31 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch32_39 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch40_47 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch48_55 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch56_63 : in std_logic_vector(3 downto 0) := "0000";

      adc_cs_n : out std_logic;
      adc_saddr : out std_logic;
      adc_sdat : in std_logic;
      adc_sclk : out std_logic;

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end component;

component de0nadxl345 is
   port(
      -- de0n adxl345
      adxl345_scl : inout std_logic;
      adxl345_sda : inout std_logic;
      adxl345_cs : out std_logic;

      adxl345_x0 : out std_logic_vector(7 downto 0);
      adxl345_x1 : out std_logic_vector(7 downto 0);
      adxl345_y0 : out std_logic_vector(7 downto 0);
      adxl345_y1 : out std_logic_vector(7 downto 0);
      adxl345_z0 : out std_logic_vector(7 downto 0);
      adxl345_z1 : out std_logic_vector(7 downto 0);

      reset : in std_logic;
      clk50mhz : in std_logic
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

signal reset: std_logic := '1';
signal cpuclk : std_logic := '0';
signal cpureset : std_logic := '1';
signal cpuresetlength : integer range 0 to 63 := 63;

signal ifetch: std_logic;
signal cpu_addr_v : std_logic_vector(15 downto 0);
signal txtx : std_logic;
signal rxrx : std_logic;
signal txtx1 : std_logic;
signal rxrx1 : std_logic;
signal txtx2 : std_logic;
signal rxrx2 : std_logic;
signal txtx3 : std_logic;
signal rxrx3 : std_logic;

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

signal hg_rh : std_logic_vector(13 downto 0);
signal hg_temp : std_logic_vector(13 downto 0);
signal co_clear : std_logic_vector(15 downto 0);
signal co_red : std_logic_vector(15 downto 0);
signal co_green : std_logic_vector(15 downto 0);
signal co_blue : std_logic_vector(15 downto 0);

signal nv_temp : std_logic_vector(11 downto 0);
signal nv_pressure : std_logic_vector(11 downto 0);
signal nv_pressure_f : std_logic_vector(11 downto 0);

signal da_dac0 : std_logic_vector(11 downto 0);
signal da_dac1 : std_logic_vector(11 downto 0);
signal da_dac2 : std_logic_vector(11 downto 0);
signal da_dac3 : std_logic_vector(11 downto 0);
signal da_dac4 : std_logic_vector(11 downto 0);
signal da_dac5 : std_logic_vector(11 downto 0);
signal da_dac6 : std_logic_vector(11 downto 0);
signal da_dac7 : std_logic_vector(11 downto 0);

signal di_dir0 : std_logic_vector(15 downto 0);
signal di_event0 : std_logic;
signal di_reply0 : std_logic;

signal do_dor0 : std_logic_vector(15 downto 0);
signal do_hb_strobe0 : std_logic;
signal do_lb_strobe0 : std_logic;
signal do_reply0 : std_logic;
signal do_ie0 : std_logic;
signal do_dor1 : std_logic_vector(15 downto 0);
signal do_hb_strobe1 : std_logic;
signal do_lb_strobe1 : std_logic;
signal do_reply1 : std_logic;
signal do_ie1 : std_logic;

signal sddebug : std_logic_vector(3 downto 0);

signal addr : std_logic_vector(21 downto 0);
signal dati : std_logic_vector(15 downto 0);
signal dato : std_logic_vector(15 downto 0);
signal control_dati : std_logic;
signal control_dato : std_logic;
signal control_datob : std_logic;

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

signal dram_match : std_logic;

begin

   pll0: pll port map(
      inclk0 => clkin,
      locked => c0_locked,
      c0 => c0
   );

   tpg16: mncadtpg port map(
      ad_channel => ad_channel,
      ad_chgbits => ad_chgbits,
      ad_wcgbits => ad_wcgbits,
      ad_basechannel => 16,
      ad_type => ch16type,
      reset => cpureset,
      clk => cpuclk
   );

   agg24: mncadagg port map(
      ad_channel => ad_channel,
      ad_chgbits => ad_chgbits,
      ad_wcgbits => ad_wcgbits,
      ad_basechannel => 24,
      ad_type => ch24type,
      reset => cpureset,
      clk => cpuclk
   );

   adc0: de0nadc port map(
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
      ad_ch14 => nv_pressure_f,
      ad_ch15 => nv_pressure,

      ad_ch16_23 => ch16type,
      ad_ch24_31 => ch24type,

      adc_cs_n => adc_cs_n,
      adc_saddr => adc_saddr,
      adc_sdat => adc_sdat,
      adc_sclk => adc_sclk,

      reset => cpureset,
      clk50mhz => clkin
   );

   adxl0: de0nadxl345 port map(
      -- de0n adxl345
      adxl345_scl => adxl345_scl,
      adxl345_sda => adxl345_sda,
      adxl345_cs => adxl345_cs,

      reset => cpureset,
      clk50mhz => clkin
   );

   dac0: pmodda4 port map(
      da_daca => da_dac0,
      da_dacb => da_dac1,
      da_dacc => da_dac2,
      da_dacd => da_dac3,
      da_dace => da_dac4,
      da_dacf => da_dac5,
      da_dacg => da_dac6,
      da_dach => da_dac7,

      da_cs => da4_cs,
      da_mosi => da4_mosi,
      da_sclk => da4_sclk,

      reset => reset,
      clk => cpuclk
   );

   mi0: miodi port map(
      mi_scl => mi0_scl,
      mi_sda => mi0_sda,
      mi_data => di_dir0,
      mi_event => di_event0,
      mi_reply => di_reply0,
      reset => cpureset,
      clk50mhz => clkin
   );
   mo0: miodo port map(
      mo_scl => mo0_scl,
      mo_sda => mo0_sda,
      mo_data => do_dor0,
      mo_hb => do_hb_strobe0,
      mo_lb => do_lb_strobe0,
      mo_ie => do_ie0,
      mo_reply => do_reply0,
      reset => cpureset,
      clk50mhz => clkin
   );
   mo1: miodo port map(
      mo_scl => mo1_scl,
      mo_sda => mo1_sda,
      mo_data => do_dor1,
      mo_hb => do_hb_strobe1,
      mo_lb => do_lb_strobe1,
      mo_ie => do_ie1,
      mo_reply => do_reply1,
      reset => cpureset,
      clk50mhz => clkin
   );


--   c0 <= clkin;

   pdp11: unibus port map(
      modelcode => 3,
      have_sillies => 1,
      bootrom => boot_minc,

      have_mncad => 1,
      have_mnckw => 2,
      have_mncaa => 0,
      have_mncdi => 1,
      have_mncdo => 1,
      have_mnckw_pulse_stretch => 10,
--      have_mncdi_loopback => 1,
      have_ibv11 => 0,

      mncad0_start => ad_start,
      mncad0_done => ad_done,
      mncad0_channel => ad_channel,
      mncad0_nxc => ad_nxc,
      mncad0_sample => ad_sample,
      mncad0_chtype => ad_type,
      mncad0_chgbits => ad_chgbits,
      mncad0_wcgbits => ad_wcgbits,

      mnckw0_st1in => mnckw0_st1in,
      mnckw0_st1out => mnckw0_st1out,
      mnckw0_st2in => mnckw0_st2in,
      mnckw0_st2out => mnckw0_st2out,
      mnckw0_clkov => mnckw0_clkov,

      mncaa0_dac0 => da_dac0,
      mncaa0_dac1 => da_dac1,
      mncaa0_dac2 => da_dac2,
      mncaa0_dac3 => da_dac3,
      mncaa1_dac0 => da_dac4,
      mncaa1_dac1 => da_dac5,
      mncaa1_dac2 => da_dac6,
      mncaa1_dac3 => da_dac7,

      mncdi0_dir => di_dir0,
      mncdi0_event => di_event0,
      mncdi0_reply => di_reply0,

      mncdo0_dor => do_dor0,
      mncdo0_hb_strobe => do_hb_strobe0,
      mncdo0_lb_strobe => do_lb_strobe0,
      mncdo0_reply => do_reply0,
      mncdo0_ie => do_ie0,
      mncdo1_dor => do_dor1,
      mncdo1_hb_strobe => do_hb_strobe1,
      mncdo1_lb_strobe => do_lb_strobe1,
      mncdo1_reply => do_reply1,
      mncdo1_ie => do_ie1,

      have_kl11 => 4,
      tx0 => txtx,
      rx0 => rxrx,
--      cts0 => cts,
--      rts0 => rts,
      kl0_bps => 9600,
      kl0_force7bit => 1,
--      kl0_rtscts => 1,

      tx1 => txtx1,
      rx1 => txtx1,
      kl1_bps => 9600,

      tx2 => txtx2,
      rx2 => txtx2,
      kl2_bps => 1200,

      tx3 => txtx3,
      rx3 => txtx3,
      kl3_bps => 300,

      have_rl => 1,
      rl_sdcard_cs => sdcard_cs,
      rl_sdcard_mosi => sdcard_mosi,
      rl_sdcard_sclk => sdcard_sclk,
      rl_sdcard_miso => sdcard_miso,
      rl_sdcard_debug => sddebug,

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
		cpu_addr_v => cpu_addr_v,
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

		paneltype => 3,

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
      ext_reset => cons_reset,
      cpureset => cpureset,
      cpuclk => cpuclk,
      c0 => c0
   );

   tx <= txtx;
	rxrx <= rx;
   tx1 <= txtx1;
   rxrx1 <= rx1;

   greenled <= ifetch & not rxrx & not rxrx1 & not txtx1 & sddebug;

--   dram_match <= '1' when addr(21 downto 13) /= "111111111" else '0';
   dram_match <= '1' when addr(21 downto 18) /= "1111" else '0';

   process(c0)
   begin
      if c0='1' and c0'event then

         if key0 = '1' and c0_locked = '1' then
            reset <= '0';
         else
            if key0 = '0' then
               reset <= '1';
            end if;
         end if;

      end if;
   end process;

end implementation;

