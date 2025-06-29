
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

entity unibus is
   port(
-- bus interface
      addr : out std_logic_vector(21 downto 0);                      -- physical address driven out to the bus by cpu or busmaster peripherals
      dati : in std_logic_vector(15 downto 0);                       -- data input to cpu or busmaster peripherals
      dato : out std_logic_vector(15 downto 0);                      -- data output from cpu or busmaster peripherals
      control_dati : out std_logic;                                  -- if '1', this is an input cycle
      control_dato : out std_logic;                                  -- if '1', this is an output cycle
      control_datob : out std_logic;                                 -- if '1', the current output cycle is for a byte
      addr_match : in std_logic;                                     -- '1' if the address is recognized

-- debug & blinkenlights
      ifetch : out std_logic;                                        -- '1' if this cycle is an ifetch cycle
      iwait : out std_logic;                                         -- '1' if the cpu is in wait state
      cpu_addr_v : out std_logic_vector(15 downto 0);                -- virtual address from cpu, for debug and general interest

-- rl controller
      have_rl : in integer range 0 to 1 := 0;                        -- enable conditional compilation
      rl_sdcard_cs : out std_logic;
      rl_sdcard_mosi : out std_logic;
      rl_sdcard_sclk : out std_logic;
      rl_sdcard_miso : in std_logic := '0';
      rl_sdcard_debug : out std_logic_vector(3 downto 0);            -- debug/blinkenlights

-- rk controller
      have_rk : in integer range 0 to 1 := 0;                        -- enable conditional compilation
      have_rk_num : in integer range 1 to 8 := 8;                    -- active number of drives on the controller; set to < 8 to save core
      rk_sdcard_cs : out std_logic;
      rk_sdcard_mosi : out std_logic;
      rk_sdcard_sclk : out std_logic;
      rk_sdcard_miso : in std_logic := '0';
      rk_sdcard_debug : out std_logic_vector(3 downto 0);            -- debug/blinkenlights

-- rh controller
      have_rh : in integer range 0 to 1 := 0;                        -- enable conditional compilation
      rh_sdcard_cs : out std_logic;
      rh_sdcard_mosi : out std_logic;
      rh_sdcard_sclk : out std_logic;
      rh_sdcard_miso : in std_logic := '0';
      rh_sdcard_debug : out std_logic_vector(3 downto 0);            -- debug/blinkenlights
      rh_type : in integer range 1 to 7 := 6;                        -- 1:RM06; 2:RP2G; 3:-;4:RP04/RP05; 5:RM05; 6:RP06; 7:RP07
      rh_noofcyl : in integer range 128 to 8192 := 1024;             -- for RM06 and RP2G: how many cylinders are available

-- xu esp32/enc424j600 controller interface
      have_xu : in integer range 0 to 1 := 0;                        -- enable conditional compilation
      have_xu_debug : in integer range 0 to 1 := 1;                  -- enable debug core
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic := '0';
      xu_srdy : in std_logic := '0';
      xu_debug_tx : out std_logic;                                   -- rs232, 115200/8/n/1 debug output from microcode
      have_xu_enc : in integer range 0 to 1 := 0;                    -- include frontend for enc424j600
      have_xu_esp : in integer range 0 to 1 := 0;                    -- include frontend for esp32

-- kl11, console ports
      have_kl11 : in integer range 0 to 4 := 1;                      -- conditional compilation - number of kl11 controllers to include. Should normally be at least 1

      tx0 : out std_logic;
      rx0 : in std_logic := '1';
      rts0 : out std_logic;
      cts0 : in std_logic := '0';
      kl0_bps : in integer range 300 to 230400 := 9600;              -- bps rate - don't set over 38400 for interrupt control applications
      kl0_force7bit : in integer range 0 to 1 := 0;                  -- zero out high order bit on transmission and reception
      kl0_rtscts : in integer range 0 to 1 := 0;                     -- conditional compilation switch for rts and cts signals; also implies to include core that implements a silo buffer

      tx1 : out std_logic;
      rx1 : in std_logic := '1';
      rts1 : out std_logic;
      cts1 : in std_logic := '0';
      kl1_bps : in integer range 300 to 230400 := 9600;
      kl1_force7bit : in integer range 0 to 1 := 0;
      kl1_rtscts : in integer range 0 to 1 := 0;

      tx2 : out std_logic;
      rx2 : in std_logic := '1';
      rts2 : out std_logic;
      cts2 : in std_logic := '0';
      kl2_bps : in integer range 300 to 230400 := 9600;
      kl2_force7bit : in integer range 0 to 1 := 0;
      kl2_rtscts : in integer range 0 to 1 := 0;

      tx3 : out std_logic;
      rx3 : in std_logic := '1';
      rts3 : out std_logic;
      cts3 : in std_logic := '0';
      kl3_bps : in integer range 300 to 230400 := 9600;
      kl3_force7bit : in integer range 0 to 1 := 0;
      kl3_rtscts : in integer range 0 to 1 := 0;

-- dr11c, universal interface

      have_dr11c : in integer range 0 to 1 := 0;                     -- conditional compilation
      have_dr11c_loopback : in integer range 0 to 1 := 0;            -- for testing only - zdrc
      have_dr11c_signal_stretch : in integer range 0 to 127 := 7;    -- the signals ndr*, dxm, init will be stretched to this many cpu cycles

      dr11c_in : in std_logic_vector(15 downto 0) := (others => '0');
      dr11c_out : out std_logic_vector(15 downto 0);
      dr11c_reqa : in std_logic := '0';
      dr11c_reqb : in std_logic := '0';
      dr11c_csr0 : out std_logic;
      dr11c_csr1 : out std_logic;
      dr11c_ndr : out std_logic;                                     -- new data ready : dr11c_out has new data
      dr11c_ndrlo : out std_logic;                                   -- new data ready : dr11c_out(7 downto 0) has new data
      dr11c_ndrhi : out std_logic;                                   -- new data ready : dr11c_out(15 downto 8) has new data
      dr11c_dxm : out std_logic;                                     -- data transmitted : dr11c_in data has been read by the cpu
      dr11c_init : out std_logic;                                    -- unibus reset propagated out to the user device

-- minc-11

      have_mncad : in integer range 0 to 1 := 0;                     -- mncad: a/d, max one card in a system
      have_mnckw : in integer range 0 to 2 := 0;                     -- mnckw: clock, either one or two
      have_mncaa : in integer range 0 to 4 := 0;                     -- mncaa: d/a
      have_mncdi : in integer range 0 to 4 := 0;                     -- mncdi: digital in
      have_mncdo : in integer range 0 to 4 := 0;                     -- mncdo: digital out
      have_mnckw_pulse_stretch : integer range 0 to 127 := 5;        -- the st1out, st2out, and clkov outputs from mnckw are stretched to this many cpu cycles
      have_mnckw_pulse_invert : integer range 0 to 1 := 0;           -- the st1out, st2out, and clkov outputs are inverted when 1 - 0 is a negative pulse (normal); 1 is a postitive pulse (inverted)
      have_mncdi_loopback : in integer range 0 to 1 := 0;            -- set to 1 to loop back mncdoX to mncdiX internally for testing
      have_mncdi_pulse_stretch : integer range 0 to 127 := 10;       -- the reply and pgmout outputs from mncdi are stretched to this many cpu cycles
      have_mncdi_pulse_invert : integer range 0 to 1 := 0;           -- the reply, pgmout, and event outputs from mncdi are inverted when 1 - 0 is a negative pulse (normal); 1 is a postitive pulse (inverted)
      have_ibv11 : in integer range 0 to 1 := 0;                     -- ibv11 ieee488 bus controller for minc

      mncad0_start : out std_logic;                                  -- interface from mncad to a/d hardware : '1' signals to start converting
      mncad0_done : in std_logic := '1';                             -- interface from mncad to a/d hardware : '1' signals to the mncad that the a/d has completed a conversion
      mncad0_channel : out std_logic_vector(5 downto 0);             -- interface from mncad to a/d hardware : the channel number for the current command
      mncad0_nxc : in std_logic := '1';                              -- interface from mncad to a/d hardware : '1' signals to the mncad that the required channel does not exist
      mncad0_sample : in std_logic_vector(11 downto 0) := "000000000000";      -- interface from mncad to a/d hardware : the value of the last sample
      mncad0_chtype : in std_logic_vector(3 downto 0) := "0000";               -- interface from mncad to a/d hardware : gain bits and/or channel type code for the current channel
      mncad0_chgbits : out std_logic_vector(3 downto 0);             -- interface from mncad to a/d hardware : new gain bits for the current channel
      mncad0_wcgbits : out std_logic;                                -- interface from mncad to a/d hardware : write strobe for new gain bits

      mnckw0_st1in : in std_logic := '0';                            -- mnckw0 st1 signal input, active on rising edge
      mnckw0_st2in : in std_logic := '0';                            -- mnckw0 st2 signal input, active on rising edge
      mnckw0_st1out : out std_logic;                                 -- mnckw0 st1 output pulse
      mnckw0_st2out : out std_logic;                                 -- mnckw0 st2 output pulse
      mnckw0_clkov : out std_logic;                                  -- mnckw0 clkovf output pulse

      mncaa0_dac0 : out std_logic_vector(11 downto 0);               -- da channel 0(0) - mncaa unit 0
      mncaa0_dac1 : out std_logic_vector(11 downto 0);               -- da channel 1
      mncaa0_dac2 : out std_logic_vector(11 downto 0);               -- da channel 2
      mncaa0_dac3 : out std_logic_vector(11 downto 0);               -- da channel 3
      mncaa1_dac0 : out std_logic_vector(11 downto 0);               -- da channel 0(4) - mncaa unit 1
      mncaa1_dac1 : out std_logic_vector(11 downto 0);               -- da channel 1
      mncaa1_dac2 : out std_logic_vector(11 downto 0);               -- da channel 2
      mncaa1_dac3 : out std_logic_vector(11 downto 0);               -- da channel 3
      mncaa2_dac0 : out std_logic_vector(11 downto 0);               -- da channel 0(8) - mncaa unit 2
      mncaa2_dac1 : out std_logic_vector(11 downto 0);               -- da channel 1
      mncaa2_dac2 : out std_logic_vector(11 downto 0);               -- da channel 2
      mncaa2_dac3 : out std_logic_vector(11 downto 0);               -- da channel 3
      mncaa3_dac0 : out std_logic_vector(11 downto 0);               -- da channel 0(12)- mncaa unit 3
      mncaa3_dac1 : out std_logic_vector(11 downto 0);               -- da channel 1
      mncaa3_dac2 : out std_logic_vector(11 downto 0);               -- da channel 2
      mncaa3_dac3 : out std_logic_vector(11 downto 0);               -- da channel 3

      mncdi0_dir : in std_logic_vector(15 downto 0) := "0000000000000000";    -- mncdi unit 0 data input register
      mncdi0_strobe : in std_logic := '0';                           -- mncdi0 strobe
      mncdi0_reply : out std_logic;                                  -- mncdi0 reply
      mncdi0_pgmout : out std_logic;                                 -- mncdi0 pgmout
      mncdi0_event : out std_logic;                                  -- mncdi0 event
      mncdi1_dir : in std_logic_vector(15 downto 0) := "0000000000000000";    -- mncdi unit 1 data input register
      mncdi1_strobe : in std_logic := '0';                           -- mncdi1 strobe
      mncdi1_reply : out std_logic;                                  -- mncdi1 reply
      mncdi1_pgmout : out std_logic;                                 -- mncdi1 pgmout
      mncdi1_event : out std_logic;                                  -- mncdi1 event
      mncdi2_dir : in std_logic_vector(15 downto 0) := "0000000000000000";    -- mncdi unit 2 data input register
      mncdi2_strobe : in std_logic := '0';                           -- mncdi2 strobe
      mncdi2_reply : out std_logic;                                  -- mncdi2 reply
      mncdi2_pgmout : out std_logic;                                 -- mncdi2 pgmout
      mncdi2_event : out std_logic;                                  -- mncdi2 event
      mncdi3_dir : in std_logic_vector(15 downto 0) := "0000000000000000";    -- mncdi unit 3 data input register
      mncdi3_strobe : in std_logic := '0';                           -- mncdi3 strobe
      mncdi3_reply : out std_logic;                                  -- mncdi3 reply
      mncdi3_pgmout : out std_logic;                                 -- mncdi3 pgmout
      mncdi3_event : out std_logic;                                  -- mncdi3 event

      mncdo0_dor : out std_logic_vector(15 downto 0);                -- mncdo unit 0 data output
      mncdo0_hb_strobe : out std_logic;                              -- mncdo0 high byte strobe
      mncdo0_lb_strobe : out std_logic;                              -- mncdo0 low byte strobe
      mncdo0_reply : in std_logic := '0';                            -- mncdo0 reply input
      mncdo0_ie : out std_logic;                                     -- mncdo0 interrupt enabled
      mncdo1_dor : out std_logic_vector(15 downto 0);                -- mncdo unit 1 data output
      mncdo1_hb_strobe : out std_logic;                              -- mncdo1 high byte strobe
      mncdo1_lb_strobe : out std_logic;                              -- mncdo1 low byte strobe
      mncdo1_reply : in std_logic := '0';                            -- mncdo1 reply input
      mncdo1_ie : out std_logic;                                     -- mncdo1 interrupt enabled
      mncdo2_dor : out std_logic_vector(15 downto 0);                -- mncdo unit 2 data output
      mncdo2_hb_strobe : out std_logic;                              -- mncdo2 high byte strobe
      mncdo2_lb_strobe : out std_logic;                              -- mncdo2 low byte strobe
      mncdo2_reply : in std_logic := '0';                            -- mncdo2 reply input
      mncdo2_ie : out std_logic;                                     -- mncdo2 interrupt enabled
      mncdo3_dor : out std_logic_vector(15 downto 0);                -- mncdo unit 3 data output
      mncdo3_hb_strobe : out std_logic;                              -- mncdo3 high byte strobe
      mncdo3_lb_strobe : out std_logic;                              -- mncdo3 low byte strobe
      mncdo3_reply : in std_logic := '0';                            -- mncdo3 reply input
      mncdo3_ie : out std_logic;                                     -- mncdo3 interrupt enabled

-- cpu console, switches and display register
      have_csdr : in integer range 0 to 1 := 1;

-- clock
      have_kw11l : in integer range 0 to 1 := 1;                     -- conditional compilation
      kw11l_hz : in integer range 50 to 800 := 60;                   -- valid values are 50, 60, 800

-- model code
      modelcode : in integer range 0 to 255;                         -- mostly used are 20,34,44,45,70,94; others are less well tested
      have_fp : in integer range 0 to 2 := 2;                        -- fp11 switch; 0=don't include; 1=include; 2=include if the cpu model can support fp11
      have_fpa : in integer range 0 to 1 := 1;                       -- floating point accelerator present with J11 cpu
      have_eis : in integer range 0 to 2 := 2;                       -- eis instructions; 0=force disable; 1=force enable; 2=follow default for cpu model
      have_fis : in integer range 0 to 2 := 2;                       -- fis instructions; 0=force disable; 1=force enable; 2=follow default for cpu model
      have_sillies : in integer range 0 to 1 := 0;                   -- whether to include core that is only there to pass maindec tests

-- cpu initial r7 and psw
      init_r7 : in std_logic_vector(15 downto 0) := x"ea10";         -- start address after reset f600 = o'173000' = m9312 hi rom; ea10 = 165020 = m9312 lo rom
      init_psw : in std_logic_vector(15 downto 0) := x"00e0";        -- initial psw for kernel mode, primary register set, priority 7

-- console
      cons_load : in std_logic := '0';
      cons_exa : in std_logic := '0';
      cons_dep : in std_logic := '0';
      cons_cont : in std_logic := '0';                               -- continue, pulse '1'
      cons_ena : in std_logic := '1';                                -- ena/halt, '1' is enable
      cons_start : in std_logic := '0';
      cons_sw : in std_logic_vector(21 downto 0) := (others => '0');
      cons_adss_mode : in std_logic_vector(1 downto 0) := (others => '0');
      cons_adss_id : in std_logic := '0';
      cons_adss_cons : in std_logic := '0';
      cons_consphy : out std_logic_vector(21 downto 0);
      cons_progphy : out std_logic_vector(21 downto 0);
      cons_br : out std_logic_vector(15 downto 0);
      cons_shfr : out std_logic_vector(15 downto 0);
      cons_maddr : out std_logic_vector(15 downto 0);                -- microcode address fpu/cpu
      cons_dr : out std_logic_vector(15 downto 0);
      cons_parh : out std_logic;
      cons_parl : out std_logic;

      cons_adrserr : out std_logic;
      cons_run : out std_logic;                                      -- '1' if executing instructions (incl wait)
      cons_pause : out std_logic;                                    -- '1' if bus has been relinquished to npr
      cons_master : out std_logic;                                   -- '1' if cpu is bus master and not running
      cons_kernel : out std_logic;                                   -- '1' if kernel mode
      cons_super : out std_logic;                                    -- '1' if super mode
      cons_user : out std_logic;                                     -- '1' if user mode
      cons_id : out std_logic;                                       -- '0' if instruction, '1' if data AND data mapping is enabled in the mmu
      cons_map16 : out std_logic;                                    -- '1' if 16-bit mapping
      cons_map18 : out std_logic;                                    -- '1' if 18-bit mapping
      cons_map22 : out std_logic;                                    -- '1' if 22-bit mapping

-- boot rom selection
      bootrom : in integer range 0 to 3 := boot_pdp2011;             -- select boot roms

-- clocks and reset
      clk : in std_logic;                                            -- cpu clock
      clk50mhz : in std_logic;                                       -- 50Mhz clock for peripherals
      reset : in std_logic                                           -- active '1' synchronous reset
   );
end unibus;

architecture implementation of unibus is

component csdr is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      have_csdr : in integer range 0 to 1;

      cs_reg : in std_logic_vector(15 downto 0);
      cd_reg : out std_logic_vector(15 downto 0);

      reset : in std_logic;
      clk : in std_logic
   );
end component;

component kw11l is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      have_kw11l : in integer range 0 to 1;
      kw11l_hz : in integer range 50 to 800;

      reset : in std_logic;
      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;

component rl11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      npr : out std_logic;
      npg : in std_logic;

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      bus_master_addr : out std_logic_vector(17 downto 0);
      bus_master_dati : in std_logic_vector(15 downto 0);
      bus_master_dato : out std_logic_vector(15 downto 0);
      bus_master_control_dati : out std_logic;
      bus_master_control_dato : out std_logic;
      bus_master_nxm : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;
      sdcard_debug : out std_logic_vector(3 downto 0);

      have_rl : in integer range 0 to 1;
      reset : in std_logic;
      clk50mhz : in std_logic;
      nclk : in std_logic;
      clk : in std_logic
   );
end component;

component rk11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      npr : out std_logic;
      npg : in std_logic;

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      bus_master_addr : out std_logic_vector(17 downto 0);
      bus_master_dati : in std_logic_vector(15 downto 0);
      bus_master_dato : out std_logic_vector(15 downto 0);
      bus_master_control_dati : out std_logic;
      bus_master_control_dato : out std_logic;
      bus_master_nxm : in std_logic;

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;
      sdcard_debug : out std_logic_vector(3 downto 0);

      have_rk : in integer range 0 to 1;
      have_rk_num : in integer range 1 to 8;
      reset : in std_logic;
      clk50mhz : in std_logic;
      nclk : in std_logic;
      clk : in std_logic
   );
end component;

component rh11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      npr : out std_logic;
      npg : in std_logic;

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      bus_master_addr : out std_logic_vector(17 downto 0);
      bus_master_dati : in std_logic_vector(15 downto 0) := (others => '0');
      bus_master_dato : out std_logic_vector(15 downto 0);
      bus_master_control_dati : out std_logic;
      bus_master_control_dato : out std_logic;
      bus_master_nxm : in std_logic := '0';

      rh70_bus_master_addr : out std_logic_vector(21 downto 0);
      rh70_bus_master_dati : in std_logic_vector(15 downto 0) := (others => '0');
      rh70_bus_master_dato : out std_logic_vector(15 downto 0);
      rh70_bus_master_control_dati : out std_logic;
      rh70_bus_master_control_dato : out std_logic;
      rh70_bus_master_nxm : in std_logic := '0';

      sdcard_cs : out std_logic;
      sdcard_mosi : out std_logic;
      sdcard_sclk : out std_logic;
      sdcard_miso : in std_logic;
      sdcard_debug : out std_logic_vector(3 downto 0);

      have_rh : in integer range 0 to 1 := 0;
      have_rh70 : in integer range 0 to 1 := 0;
      rh_type : in integer range 1 to 7 := 6;              -- 1:RM06; 2:RP2G; 3:-;4:RP04/RP05; 5:RM05; 6:RP06; 7:RP07
      rh_noofcyl : in integer range 128 to 8192 := 1024;   -- for RM06 and RP2G: how many cylinders are available

      reset : in std_logic;
      clk50mhz : in std_logic;
      nclk : in std_logic;
      clk : in std_logic
   );
end component;

component xu is
   port(
-- standard bus master interface
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      npr : out std_logic;
      npg : in std_logic;

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      bus_master_addr : out std_logic_vector(17 downto 0);
      bus_master_dati : in std_logic_vector(15 downto 0) := (others => '0');
      bus_master_dato : out std_logic_vector(15 downto 0);
      bus_master_control_dati : out std_logic;
      bus_master_control_dato : out std_logic;
      bus_master_nxm : in std_logic := '0';

-- ethernet, enc424j600/esp32 frontend interface
      xu_cs : out std_logic;
      xu_mosi : out std_logic;
      xu_sclk : out std_logic;
      xu_miso : in std_logic;
      xu_srdy : in std_logic;

-- flags
      have_xu : in integer range 0 to 1 := 0;
      have_xu_debug : in integer range 0 to 1 := 1;
      have_xu_enc : in integer range 0 to 1 := 0;
      have_xu_esp : in integer range 0 to 1 := 0;

-- debug & blinkenlights
      tx : out std_logic;
      ifetch : out std_logic;
      iwait : out std_logic;

-- clock & reset
      cpuclk : in std_logic;
      nclk : in std_logic;
      clk50mhz : in std_logic;
      reset : in std_logic
   );
end component;

component dr11c is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec1 : in std_logic_vector(8 downto 0);
      ivec2 : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      have_dr11c : in integer range 0 to 1 := 0;
      have_dr11c_loopback : in integer range 0 to 1 := 0;
      have_dr11c_signal_stretch : in integer range 0 to 127 := 7;

      dr11c_in : in std_logic_vector(15 downto 0) := (others => '0');
      dr11c_out : out std_logic_vector(15 downto 0);
      dr11c_reqa : in std_logic := '0';
      dr11c_reqb : in std_logic := '0';
      dr11c_csr0 : out std_logic;
      dr11c_csr1 : out std_logic;
      dr11c_ndr : out std_logic;
      dr11c_ndrlo : out std_logic;
      dr11c_ndrhi : out std_logic;
      dr11c_dxm : out std_logic;
      dr11c_init : out std_logic;

      reset : in std_logic;

      clk50mhz : in std_logic;

      clk : in std_logic
   );
end component;

component mncad is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      st1 : in std_logic;
      clkov : in std_logic;

      ad_start : out std_logic;                                      -- '1' pulse signals to start converting
      ad_done : in std_logic := '0';                                 -- '1' signals to the mncad that the a/d has completed a conversion
      ad_channel : out std_logic_vector(5 downto 0);                 -- the current a/d channel
      ad_nxc : in std_logic := '0';                                  -- '1' when the current channel does not exist
      ad_sample : in std_logic_vector(11 downto 0) := "000000000000";          -- the last conversion result
      ad_type : in std_logic_vector(3 downto 0) := "0000";           -- gain bits and/or channel type code for the current channel
      ad_chgbits : out std_logic_vector(3 downto 0);                 -- new gain bits for the current channel
      ad_wcgbits : out std_logic;                                    -- when '1' program the chgbits into the current channel

      have_mncad : in integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;

component mnckw is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      st1in : in std_logic := '0';
      st2in : in std_logic := '0';
      st1out : out std_logic;
      st2out : out std_logic;
      clkov : out std_logic;

      have_mnckw : in integer range 0 to 1 := 0;
      have_mnckw_pulse_stretch : integer range 0 to 127 := 5;
      have_mnckw_pulse_invert : integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;


component mncaa is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      da_dac0 : out std_logic_vector(11 downto 0);
      da_dac1 : out std_logic_vector(11 downto 0);
      da_dac2 : out std_logic_vector(11 downto 0);
      da_dac3 : out std_logic_vector(11 downto 0);

      have_mncaa : in integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;

component mncdi is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      d : in std_logic_vector(15 downto 0) := "0000000000000000";
      strobe : in std_logic := '0';
      reply : out std_logic;
      pgmout : out std_logic;
      event : out std_logic;

      have_mncdi : in integer range 0 to 1 := 0;
      have_mncdi_pulse_stretch : integer range 0 to 127 := 10;
      have_mncdi_pulse_invert : integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;

component mncdo is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      d : out std_logic_vector(15 downto 0);
      hb_strobe : out std_logic;
      lb_strobe : out std_logic;
      ie : out std_logic;
      reply : in std_logic := '0';

      have_mncdo : in integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;

component ibv11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      have_ibv11 : in integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end component;


signal cpu_init_r7 : std_logic_vector(15 downto 0);
signal cpu_addr : std_logic_vector(15 downto 0);
signal cpu_datain : std_logic_vector(15 downto 0);
signal cpu_dataout : std_logic_vector(15 downto 0);
signal cpu_wr : std_logic;
signal cpu_rd : std_logic;
signal cpu_psw : std_logic_vector(15 downto 0);
signal cpu_psw_in : std_logic_vector(15 downto 0);
signal cpu_psw_we_even : std_logic;
signal cpu_psw_we_odd : std_logic;
signal cpu_pir_in : std_logic_vector(15 downto 0);
signal cpu_dw8 : std_logic;
signal cpu_cp : std_logic;
signal cpu_id : std_logic;
signal cpu_init : std_logic;
signal cpu_addr_match : std_logic;
signal cpu_sr0_ic : std_logic;
signal cpu_sr1 : std_logic_vector(15 downto 0);
signal cpu_sr2 : std_logic_vector(15 downto 0);
signal cpu_dstfreference : std_logic;
signal cpu_sr3csmenable : std_logic;

signal cpu_br7 : std_logic;
signal cpu_bg7 : std_logic;
signal cpu_int_vector7 : std_logic_vector(8 downto 0);
signal cpu_br6 : std_logic;
signal cpu_bg6 : std_logic;
signal cpu_int_vector6 : std_logic_vector(8 downto 0);
signal cpu_br5 : std_logic;
signal cpu_bg5 : std_logic;
signal cpu_int_vector5 : std_logic_vector(8 downto 0);
signal cpu_br4 : std_logic;
signal cpu_bg4 : std_logic;
signal cpu_int_vector4 : std_logic_vector(8 downto 0);

signal mmu_trap : std_logic;
signal mmu_abort : std_logic;
signal mmu_oddabort : std_logic;
signal cpu_ack_mmuabort : std_logic;
signal cpu_ack_mmutrap : std_logic;

signal cpu_npr : std_logic;
signal cpu_npg : std_logic;

signal nxmabort : std_logic;
signal oddabort : std_logic;
signal illhalt : std_logic;
signal ysv : std_logic;
signal rsv : std_logic;
signal ifetchcopy : std_logic;
signal cpu_cons_run : std_logic;
signal cpu_cons_consphy : std_logic_vector(21 downto 0);

signal bus_unibus_mapped : std_logic;

signal bus_addr : std_logic_vector(21 downto 0);
signal bus_dati : std_logic_vector(15 downto 0);
signal bus_dato : std_logic_vector(15 downto 0);
signal bus_control_dati : std_logic;
signal bus_control_dato : std_logic;
signal bus_control_datob : std_logic;

signal busmaster_nxmabort : std_logic;

signal unibus_addr_match : std_logic;

signal unibus_addr : std_logic_vector(17 downto 0);
signal unibus_dati : std_logic_vector(15 downto 0);
signal unibus_dato : std_logic_vector(15 downto 0);
signal unibus_control_dati : std_logic;
signal unibus_control_dato : std_logic;
signal unibus_control_datob : std_logic;

signal unibus_busmaster_addr : std_logic_vector(17 downto 0);
signal unibus_busmaster_dati : std_logic_vector(15 downto 0);
signal unibus_busmaster_dato : std_logic_vector(15 downto 0);
signal unibus_busmaster_control_dati : std_logic;
signal unibus_busmaster_control_dato : std_logic;
signal unibus_busmaster_control_datob : std_logic;
signal unibus_busmaster_control_npg : std_logic;

type npr_states is (
   npr_idle,
   npr_rl0,
   npr_rk0,
   npr_rh0,
   npr_xu0
);
signal npr_state : npr_states := npr_idle;

type br6_states is (
   br6_kw0,
   br6_mncad0,
   br6_idle
);
signal br6_state : br6_states := br6_idle;

type br5_states is (
   br5_rh0,
   br5_xu0,
   br5_rl0,
   br5_rk0,
   br5_dr11c0,
   br5_idle
);
signal br5_state : br5_states := br5_idle;

type br4_states is (
   br4_kl0,
   br4_kl1,
   br4_kl2,
   br4_kl3,
   br4_mnckw0,
   br4_mnckw1,
   br4_mncdi0,
   br4_mncdi1,
   br4_mncdi2,
   br4_mncdi3,
   br4_mncdo0,
   br4_mncdo1,
   br4_mncdo2,
   br4_mncdo3,
   br4_ibv11,
   br4_idle
);
signal br4_state : br4_states := br4_idle;

signal mem_addr_match : std_logic;
signal mem_dati : std_logic_vector(15 downto 0);

signal bootrom0_minc_addr_match : std_logic;
signal bootrom0_minc_dati : std_logic_vector(15 downto 0);
signal bootrom1_minc_addr_match : std_logic;
signal bootrom1_minc_dati : std_logic_vector(15 downto 0);

signal bootrom0_pdp2011_addr_match : std_logic;
signal bootrom0_pdp2011_dati : std_logic_vector(15 downto 0);
signal bootrom1_pdp2011_addr_match : std_logic;
signal bootrom1_pdp2011_dati : std_logic_vector(15 downto 0);

signal bootrom0_odt_addr_match : std_logic;
signal bootrom0_odt_dati : std_logic_vector(15 downto 0);
signal bootrom1_odt_addr_match : std_logic;
signal bootrom1_odt_dati : std_logic_vector(15 downto 0);

signal csdr_addr_match : std_logic;
signal csdr_dati : std_logic_vector(15 downto 0);

signal have_kl0 : integer range 0 to 1;
signal kl0_addr_match : std_logic;
signal kl0_dati : std_logic_vector(15 downto 0);
signal kl0_bg : std_logic;
signal kl0_br : std_logic;
signal kl0_ivec : std_logic_vector(8 downto 0);

signal have_kl1 : integer range 0 to 1;
signal kl1_addr_match : std_logic;
signal kl1_dati : std_logic_vector(15 downto 0);
signal kl1_bg : std_logic;
signal kl1_br : std_logic;
signal kl1_ivec : std_logic_vector(8 downto 0);

signal have_kl2 : integer range 0 to 1;
signal kl2_addr_match : std_logic;
signal kl2_dati : std_logic_vector(15 downto 0);
signal kl2_bg : std_logic;
signal kl2_br : std_logic;
signal kl2_ivec : std_logic_vector(8 downto 0);

signal have_kl3 : integer range 0 to 1;
signal kl3_addr_match : std_logic;
signal kl3_dati : std_logic_vector(15 downto 0);
signal kl3_bg : std_logic;
signal kl3_br : std_logic;
signal kl3_ivec : std_logic_vector(8 downto 0);

signal kw0_addr_match : std_logic;
signal kw0_dati : std_logic_vector(15 downto 0);
signal kw0_bg : std_logic;
signal kw0_br : std_logic;
signal kw0_ivec : std_logic_vector(8 downto 0);

signal rl0_addr_match : std_logic;
signal rl0_dati : std_logic_vector(15 downto 0);
signal rl0_npr : std_logic;
signal rl0_npg : std_logic;

signal rl0_bg : std_logic;
signal rl0_br : std_logic;
signal rl0_ivec : std_logic_vector(8 downto 0);

signal rl0_addr : std_logic_vector(17 downto 0);
signal rl0_dato : std_logic_vector(15 downto 0);
signal rl0_control_dati : std_logic;
signal rl0_control_dato : std_logic;

signal rk0_bg : std_logic;
signal rk0_br : std_logic;
signal rk0_ivec : std_logic_vector(8 downto 0);

signal rk0_addr_match : std_logic;
signal rk0_dati : std_logic_vector(15 downto 0);
signal rk0_npr : std_logic;
signal rk0_npg : std_logic;

signal rk0_addr : std_logic_vector(17 downto 0);
signal rk0_dato : std_logic_vector(15 downto 0);
signal rk0_control_dati : std_logic;
signal rk0_control_dato : std_logic;

signal rh0_bg : std_logic;
signal rh0_br : std_logic;
signal rh0_ivec : std_logic_vector(8 downto 0);

signal rh0_addr_match : std_logic;
signal rh0_dati : std_logic_vector(15 downto 0);
signal rh0_npr : std_logic;
signal rh0_npg : std_logic;

signal rh0_addr : std_logic_vector(17 downto 0);
signal rh0_dato : std_logic_vector(15 downto 0);
signal rh0_control_dati : std_logic;
signal rh0_control_dato : std_logic;

signal rh70_bus_master_addr : std_logic_vector(21 downto 0);
signal rh70_bus_master_dati : std_logic_vector(15 downto 0);
signal rh70_bus_master_dato : std_logic_vector(15 downto 0);
signal rh70_bus_master_control_dati : std_logic;
signal rh70_bus_master_control_dato : std_logic;
signal rh70_bus_master_nxm : std_logic;

signal have_rh70 : integer range 0 to 1;

signal xu0_bg : std_logic;
signal xu0_br : std_logic;
signal xu0_ivec : std_logic_vector(8 downto 0);

signal xu0_addr_match : std_logic;
signal xu0_dati : std_logic_vector(15 downto 0);
signal xu0_npr : std_logic;
signal xu0_npg : std_logic;

signal xu0_addr : std_logic_vector(17 downto 0);
signal xu0_dato : std_logic_vector(15 downto 0);
signal xu0_control_dati : std_logic;
signal xu0_control_dato : std_logic;

signal dr11c0_addr_match : std_logic;
signal dr11c0_dati : std_logic_vector(15 downto 0);
signal dr11c0_bg : std_logic;
signal dr11c0_br : std_logic;
signal dr11c0_ivec : std_logic_vector(8 downto 0);
signal dr11c0_ivec1 : std_logic_vector(8 downto 0);
signal dr11c0_ivec2 : std_logic_vector(8 downto 0);

signal mncad0_addr_match : std_logic;
signal mncad0_dati : std_logic_vector(15 downto 0);
signal mncad0_bg : std_logic;
signal mncad0_br : std_logic;
signal mncad0_ivec : std_logic_vector(8 downto 0);

signal mnckw0_addr_match : std_logic;
signal mnckw0_dati : std_logic_vector(15 downto 0);
signal mnckw0_bg : std_logic;
signal mnckw0_br : std_logic;
signal mnckw0_ivec : std_logic_vector(8 downto 0);
signal kw0_st1in : std_logic;
signal kw0_st2in : std_logic;
signal kw0_st1out : std_logic;
signal kw0_st2out : std_logic;
signal kw0_clkov : std_logic;
signal have_mnckw0 : integer range 0 to 1;

signal mnckw1_addr_match : std_logic;
signal mnckw1_dati : std_logic_vector(15 downto 0);
signal mnckw1_bg : std_logic;
signal mnckw1_br : std_logic;
signal mnckw1_ivec : std_logic_vector(8 downto 0);
signal have_mnckw1 : integer range 0 to 1;

signal mncaa0_addr_match : std_logic;
signal mncaa0_dati : std_logic_vector(15 downto 0);
signal have_mncaa0 : integer range 0 to 1;
signal mncaa1_addr_match : std_logic;
signal mncaa1_dati : std_logic_vector(15 downto 0);
signal have_mncaa1 : integer range 0 to 1;
signal mncaa2_addr_match : std_logic;
signal mncaa2_dati : std_logic_vector(15 downto 0);
signal have_mncaa2 : integer range 0 to 1;
signal mncaa3_addr_match : std_logic;
signal mncaa3_dati : std_logic_vector(15 downto 0);
signal have_mncaa3 : integer range 0 to 1;

signal mncdi0_addr_match : std_logic;
signal mncdi0_dati : std_logic_vector(15 downto 0);
signal mncdi0_bg : std_logic;
signal mncdi0_br : std_logic;
signal mncdi0_ivec : std_logic_vector(8 downto 0);
signal di0_d : std_logic_vector(15 downto 0);
signal di0_strobe : std_logic;
signal di0_reply : std_logic;
signal di0_pgmout : std_logic;
signal di0_event : std_logic;
signal have_mncdi0 : integer range 0 to 1;
signal mncdi1_addr_match : std_logic;
signal mncdi1_dati : std_logic_vector(15 downto 0);
signal mncdi1_bg : std_logic;
signal mncdi1_br : std_logic;
signal mncdi1_ivec : std_logic_vector(8 downto 0);
signal di1_d : std_logic_vector(15 downto 0);
signal di1_strobe : std_logic;
signal di1_reply : std_logic;
signal di1_pgmout : std_logic;
signal di1_event : std_logic;
signal have_mncdi1 : integer range 0 to 1;
signal mncdi2_addr_match : std_logic;
signal mncdi2_dati : std_logic_vector(15 downto 0);
signal mncdi2_bg : std_logic;
signal mncdi2_br : std_logic;
signal mncdi2_ivec : std_logic_vector(8 downto 0);
signal di2_d : std_logic_vector(15 downto 0);
signal di2_strobe : std_logic;
signal di2_reply : std_logic;
signal di2_pgmout : std_logic;
signal di2_event : std_logic;
signal have_mncdi2 : integer range 0 to 1;
signal mncdi3_addr_match : std_logic;
signal mncdi3_dati : std_logic_vector(15 downto 0);
signal mncdi3_bg : std_logic;
signal mncdi3_br : std_logic;
signal mncdi3_ivec : std_logic_vector(8 downto 0);
signal di3_d : std_logic_vector(15 downto 0);
signal di3_strobe : std_logic;
signal di3_reply : std_logic;
signal di3_pgmout : std_logic;
signal di3_event : std_logic;
signal have_mncdi3 : integer range 0 to 1;

signal mncdo0_addr_match : std_logic;
signal mncdo0_dati : std_logic_vector(15 downto 0);
signal mncdo0_bg : std_logic;
signal mncdo0_br : std_logic;
signal mncdo0_ivec : std_logic_vector(8 downto 0);
signal do0_d : std_logic_vector(15 downto 0);
signal do0_hb_strobe : std_logic;
signal do0_lb_strobe : std_logic;
signal do0_reply : std_logic;
signal do0_ie : std_logic;
signal have_mncdo0 : integer range 0 to 1;
signal mncdo1_addr_match : std_logic;
signal mncdo1_dati : std_logic_vector(15 downto 0);
signal mncdo1_bg : std_logic;
signal mncdo1_br : std_logic;
signal mncdo1_ivec : std_logic_vector(8 downto 0);
signal do1_d : std_logic_vector(15 downto 0);
signal do1_hb_strobe : std_logic;
signal do1_lb_strobe : std_logic;
signal do1_reply : std_logic;
signal do1_ie : std_logic;
signal have_mncdo1 : integer range 0 to 1;
signal mncdo2_addr_match : std_logic;
signal mncdo2_dati : std_logic_vector(15 downto 0);
signal mncdo2_bg : std_logic;
signal mncdo2_br : std_logic;
signal mncdo2_ivec : std_logic_vector(8 downto 0);
signal do2_d : std_logic_vector(15 downto 0);
signal do2_hb_strobe : std_logic;
signal do2_lb_strobe : std_logic;
signal do2_reply : std_logic;
signal do2_ie : std_logic;
signal have_mncdo2 : integer range 0 to 1;
signal mncdo3_addr_match : std_logic;
signal mncdo3_dati : std_logic_vector(15 downto 0);
signal mncdo3_bg : std_logic;
signal mncdo3_br : std_logic;
signal mncdo3_ivec : std_logic_vector(8 downto 0);
signal do3_d : std_logic_vector(15 downto 0);
signal do3_hb_strobe : std_logic;
signal do3_lb_strobe : std_logic;
signal do3_reply : std_logic;
signal do3_ie : std_logic;
signal have_mncdo3 : integer range 0 to 1;

signal ibv11_addr_match : std_logic;
signal ibv11_dati : std_logic_vector(15 downto 0);
signal ibv11_bg : std_logic;
signal ibv11_br : std_logic;
signal ibv11_ivec : std_logic_vector(8 downto 0);

signal cer_nxmabort : std_logic;
signal cer_ioabort : std_logic;

signal cpu_stack_limit : std_logic_vector(15 downto 0);
signal cpu_kmillhalt : std_logic;
signal cons_exadep : std_logic;

signal mmu_lma_c0 : std_logic;
signal mmu_lma_c1 : std_logic;
signal mmu_lma_eub : std_logic_vector(21 downto 0);

signal cr_addr_match : std_logic;
signal cr_dati : std_logic_vector(15 downto 0);

signal nclk : std_logic;

signal have_oddabort : integer range 0 to 1;

signal have_m9312h_minc : integer range 0 to 1 := 0;
signal have_m9312l_minc : integer range 0 to 1 := 0;
signal have_m9312h_pdp2011 : integer range 0 to 1 := 0;
signal have_m9312l_pdp2011 : integer range 0 to 1 := 0;
signal have_m9312h_odt : integer range 0 to 1 := 0;
signal have_m9312l_odt : integer range 0 to 1 := 0;


begin

   with bootrom select have_m9312h_minc <=
      1 when boot_minc,
      0 when others;

   with bootrom select have_m9312l_minc <=
      1 when boot_minc,
      0 when others;

   with bootrom select have_m9312h_pdp2011 <=
      1 when boot_pdp2011,
      0 when others;

   with bootrom select have_m9312l_pdp2011 <=
      1 when boot_pdp2011,
      0 when others;

   with bootrom select have_m9312h_odt <=
      1 when boot_odt,
      0 when others;

   with bootrom select have_m9312l_odt <=
      1 when boot_odt,
      0 when others;

   with bootrom select cpu_init_r7 <=
      x"fa10" when boot_minc,
      x"ea10" when boot_odt,
      x"ea10" when boot_pdp2011,
      init_r7 when others;


   cpu0: cpu port map(
      addr_v => cpu_addr,
      datain => cpu_datain,
      dataout => cpu_dataout,
      wr => cpu_wr,
      rd => cpu_rd,
      dw8 => cpu_dw8,
      cp => cpu_cp,
      ifetch => ifetchcopy,
      iwait => iwait,
      id => cpu_id,
      init => cpu_init,
      br7 => cpu_br7,
      bg7 => cpu_bg7,
      int_vector7 => cpu_int_vector7,
      br6 => cpu_br6,
      bg6 => cpu_bg6,
      int_vector6 => cpu_int_vector6,
      br5 => cpu_br5,
      bg5 => cpu_bg5,
      int_vector5 => cpu_int_vector5,
      br4 => cpu_br4,
      bg4 => cpu_bg4,
      int_vector4 => cpu_int_vector4,
      mmutrap => mmu_trap,
      ack_mmutrap => cpu_ack_mmutrap,
      mmuabort => mmu_abort,
      ack_mmuabort => cpu_ack_mmuabort,
      npr => cpu_npr,
      npg => cpu_npg,
      nxmabort => nxmabort,
      oddabort => oddabort,
      illhalt => illhalt,
      ysv => ysv,
      rsv => rsv,
      cpu_stack_limit => cpu_stack_limit,
      cpu_kmillhalt => cpu_kmillhalt,
      sr0_ic => cpu_sr0_ic,
      sr1 => cpu_sr1,
      sr2 => cpu_sr2,
      dstfreference => cpu_dstfreference,
      sr3csmenable => cpu_sr3csmenable,
      psw_in => cpu_psw_in,
      psw_out => cpu_psw,
      psw_in_we_even => cpu_psw_we_even,
      psw_in_we_odd => cpu_psw_we_odd,
      pir_in => cpu_pir_in,
      modelcode => modelcode,
      have_fp => have_fp,
      have_fpa => have_fpa,
      have_eis => have_eis,
      have_fis => have_fis,
      have_sillies => have_sillies,
      init_r7 => cpu_init_r7,
      init_psw => init_psw,
      cons_load => cons_load,
      cons_exa => cons_exa,
      cons_dep => cons_dep,
      cons_cont => cons_cont,
      cons_ena => cons_ena,
      cons_start => cons_start,
      cons_sw => cons_sw,
      cons_consphy => cpu_cons_consphy,
      cons_exadep => cons_exadep,
      cons_adrserr => cons_adrserr,
      cons_br => cons_br,
      cons_shfr => cons_shfr,
      cons_maddr => cons_maddr,
      cons_run => cpu_cons_run,
      cons_pause => cons_pause,
      cons_master => cons_master,
      cons_kernel => cons_kernel,
      cons_super => cons_super,
      cons_user => cons_user,
      clk => clk,
      reset => reset
   );

   mmu0: mmu port map(
      cpu_addr_v => cpu_addr,
      cpu_datain => cpu_datain,
      cpu_dataout => cpu_dataout,
      cpu_rd => cpu_rd,
      cpu_wr => cpu_wr,
      cpu_dw8 => cpu_dw8,
      cpu_cp => cpu_cp,
      sr0_ic => cpu_sr0_ic,
      sr1_in => cpu_sr1,
      sr2_in => cpu_sr2,
      dstfreference => cpu_dstfreference,
      sr3csmenable => cpu_sr3csmenable,
      ifetch => ifetchcopy,
      mmutrap => mmu_trap,
      ack_mmutrap => cpu_ack_mmutrap,
      mmuabort => mmu_abort,
      ack_mmuabort => cpu_ack_mmuabort,

      mmuoddabort => mmu_oddabort,

      mmu_lma_c1 => mmu_lma_c1,
      mmu_lma_c0 => mmu_lma_c0,
      mmu_lma_eub => mmu_lma_eub,

      bus_unibus_mapped => bus_unibus_mapped,

      bus_addr => bus_addr,
      bus_dati => bus_dati,
      bus_dato => bus_dato,
      bus_control_dati => bus_control_dati,
      bus_control_dato => bus_control_dato,
      bus_control_datob => bus_control_datob,

      unibus_addr => unibus_addr,
      unibus_dati => unibus_dati,
      unibus_dato => unibus_dato,
      unibus_control_dati => unibus_control_dati,
      unibus_control_dato => unibus_control_dato,
      unibus_control_datob => unibus_control_datob,

      unibus_busmaster_addr => unibus_busmaster_addr,
      unibus_busmaster_dati => unibus_busmaster_dati,
      unibus_busmaster_dato => unibus_busmaster_dato,
      unibus_busmaster_control_dati => unibus_busmaster_control_dati,
      unibus_busmaster_control_dato => unibus_busmaster_control_dato,
      unibus_busmaster_control_datob => unibus_busmaster_control_datob,
      unibus_busmaster_control_npg => unibus_busmaster_control_npg,

      cons_exadep => cons_exadep,
      cons_consphy => cpu_cons_consphy,
      cons_adss_mode => cons_adss_mode,
      cons_adss_id => cons_adss_id,
      cons_adss_cons => cons_adss_cons,
      cons_map16 => cons_map16,
      cons_map18 => cons_map18,
      cons_map22 => cons_map22,
      cons_id => cons_id,

      modelcode => modelcode,
      have_odd_abort => have_oddabort,

      psw => cpu_psw,
      id => cpu_id,
      reset => cpu_init,
      clk => nclk
   );

   cr0: cr11 port map(
      bus_addr_match => cr_addr_match,
      bus_addr => unibus_addr,
      bus_dati => cr_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      psw_in => cpu_psw_in,
      psw_in_we_even => cpu_psw_we_even,
      psw_in_we_odd => cpu_psw_we_odd,
      psw_out => cpu_psw,

      cpu_stack_limit => cpu_stack_limit,

      pir_in => cpu_pir_in,

      cpu_illegal_halt => illhalt,
      cpu_address_error => oddabort,
      cpu_nxm => cer_nxmabort,
      cpu_iobus_timeout => cer_ioabort,
      cpu_ysv => ysv,
      cpu_rsv => rsv,

      mmu_lma_c1 => mmu_lma_c1,
      mmu_lma_c0 => mmu_lma_c0,
      mmu_lma_eub => mmu_lma_eub,

      cpu_kmillhalt => cpu_kmillhalt,

      modelcode => modelcode,
      have_fpa => have_fpa,

      reset => cpu_init,
      clk => nclk
   );

   bootrom0_minc: m9312l_minc port map(
      base_addr => o"775000",                   -- m9312 lo rom - changed address though

      bus_addr_match => bootrom0_minc_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom0_minc_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312l_minc => have_m9312l_minc,

      clk => nclk
   );

   bootrom1_minc: m9312h_minc port map(
      base_addr => o"773000",                   -- m9312 hi rom

      bus_addr_match => bootrom1_minc_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom1_minc_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312h_minc => have_m9312h_minc,

      clk => nclk
   );

   bootrom0_pdp2011: m9312l_pdp2011 port map(
      base_addr => o"765000",                   -- m9312 lo rom

      bus_addr_match => bootrom0_pdp2011_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom0_pdp2011_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312l_pdp2011 => have_m9312l_pdp2011,

      clk => nclk
   );

   bootrom1_pdp2011: m9312h_pdp2011 port map(
      base_addr => o"773000",                   -- m9312 hi rom

      bus_addr_match => bootrom1_pdp2011_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom1_pdp2011_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312h_pdp2011 => have_m9312h_pdp2011,

      clk => nclk
   );

   bootrom0_odt: m9312l_odt port map(
      base_addr => o"765000",                   -- m9312 lo rom

      bus_addr_match => bootrom0_odt_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom0_odt_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312l_odt => have_m9312l_odt,

      clk => nclk
   );

   bootrom1_odt: m9312h_odt port map(
      base_addr => o"773000",                   -- m9312 hi rom

      bus_addr_match => bootrom1_odt_addr_match,
      bus_addr => unibus_addr,
      bus_dati => bootrom1_odt_dati,
      bus_control_dati => unibus_control_dati,

      have_m9312h_odt => have_m9312h_odt,

      clk => nclk
   );

--    blockram0: blockram port map(
--       base_addr => o"000000",
--
--       bus_addr_match => rom_addr_match,
--       bus_addr => bus_addr,
--       bus_dati => rom_dati,
--       bus_dato => bus_dato,
--       bus_control_dati => bus_control_dati,
--       bus_control_dato => bus_control_dato,
--       bus_control_datob => bus_control_datob,
--
--       reset => reset,
--       clk => nclk
--    );

  kw0: kw11l port map(
      base_addr => o"777546",
      ivec => o"100",

      br => kw0_br,
      bg => kw0_bg,
      int_vector => kw0_ivec,

      bus_addr_match => kw0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => kw0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      have_kw11l => have_kw11l,
      kw11l_hz => kw11l_hz,
      reset => cpu_init,
      clk50mhz => clk50mhz,
      clk => nclk
   );

   have_kl0 <= 1 when have_kl11 >= 1 else 0;
   kl0: kl11 port map(
      base_addr => o"777560",
      ivec => o"060",
      ovec => o"064",

      br => kl0_br,
      bg => kl0_bg,
      int_vector => kl0_ivec,

      bus_addr_match => kl0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => kl0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      tx => tx0,
      rx => rx0,
      rts => rts0,
      cts => cts0,
      have_kl11_bps => kl0_bps,
      have_kl11_force7bit => kl0_force7bit,
      have_kl11_rtscts => kl0_rtscts,

      have_kl11 => have_kl0,
      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_kl1 <= 1 when have_kl11 >= 2 else 0;
   kl1: kl11 port map(
      base_addr => o"776500",
      ivec => o"300",
      ovec => o"304",

      br => kl1_br,
      bg => kl1_bg,
      int_vector => kl1_ivec,

      bus_addr_match => kl1_addr_match,
      bus_addr => unibus_addr,
      bus_dati => kl1_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      tx => tx1,
      rx => rx1,
      rts => rts1,
      cts => cts1,
      have_kl11_bps => kl1_bps,
      have_kl11_force7bit => kl1_force7bit,
      have_kl11_rtscts => kl1_rtscts,

      have_kl11 => have_kl1,
      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_kl2 <= 1 when have_kl11 >= 3 else 0;
   kl2: kl11 port map(
      base_addr => o"776510",
      ivec => o"310",
      ovec => o"314",

      br => kl2_br,
      bg => kl2_bg,
      int_vector => kl2_ivec,

      bus_addr_match => kl2_addr_match,
      bus_addr => unibus_addr,
      bus_dati => kl2_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      tx => tx2,
      rx => rx2,
      rts => rts2,
      cts => cts2,
      have_kl11_bps => kl2_bps,
      have_kl11_force7bit => kl2_force7bit,
      have_kl11_rtscts => kl2_rtscts,

      have_kl11 => have_kl2,
      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_kl3 <= 1 when have_kl11 >= 4 else 0;
   kl3: kl11 port map(
      base_addr => o"776520",
      ivec => o"320",
      ovec => o"324",

      br => kl3_br,
      bg => kl3_bg,
      int_vector => kl3_ivec,

      bus_addr_match => kl3_addr_match,
      bus_addr => unibus_addr,
      bus_dati => kl3_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      tx => tx3,
      rx => rx3,
      rts => rts3,
      cts => cts3,
      have_kl11_bps => kl3_bps,
      have_kl11_force7bit => kl3_force7bit,
      have_kl11_rtscts => kl3_rtscts,

      have_kl11 => have_kl3,
      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   csdr0: csdr port map(
      base_addr => o"777570",

      bus_addr_match => csdr_addr_match,
      bus_addr => unibus_addr,
      bus_dati => csdr_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      have_csdr => have_csdr,

      cs_reg => cons_sw(15 downto 0),
      cd_reg => cons_dr,

      reset => reset,
      clk => nclk
   );

   rl0: rl11 port map(
      base_addr => o"774400",
      ivec => o"160",

      br => rl0_br,
      bg => rl0_bg,
      int_vector => rl0_ivec,

      npr => rl0_npr,
      npg => rl0_npg,

      bus_addr_match => rl0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => rl0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      bus_master_addr => rl0_addr,
      bus_master_dati => unibus_busmaster_dati,
      bus_master_dato => rl0_dato,
      bus_master_control_dati => rl0_control_dati,
      bus_master_control_dato => rl0_control_dato,
      bus_master_nxm => busmaster_nxmabort,

      sdcard_cs => rl_sdcard_cs,
      sdcard_mosi => rl_sdcard_mosi,
      sdcard_sclk => rl_sdcard_sclk,
      sdcard_miso => rl_sdcard_miso,
      sdcard_debug => rl_sdcard_debug,

      have_rl => have_rl,
      reset => cpu_init,
      clk50mhz => clk50mhz,
      nclk => nclk,
      clk => clk
   );

   rk0: rk11 port map(
      base_addr => o"777400",
      ivec => o"220",

      br => rk0_br,
      bg => rk0_bg,
      int_vector => rk0_ivec,

      npr => rk0_npr,
      npg => rk0_npg,

      bus_addr_match => rk0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => rk0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      bus_master_addr => rk0_addr,
      bus_master_dati => unibus_busmaster_dati,
      bus_master_dato => rk0_dato,
      bus_master_control_dati => rk0_control_dati,
      bus_master_control_dato => rk0_control_dato,
      bus_master_nxm => busmaster_nxmabort,

      sdcard_cs => rk_sdcard_cs,
      sdcard_mosi => rk_sdcard_mosi,
      sdcard_sclk => rk_sdcard_sclk,
      sdcard_miso => rk_sdcard_miso,
      sdcard_debug => rk_sdcard_debug,

      have_rk => have_rk,
      have_rk_num => have_rk_num,
      reset => cpu_init,
      clk50mhz => clk50mhz,
      nclk => nclk,
      clk => clk
   );

   rh70_bus_master_nxm <= '1' when addr_match = '0' and cpu_npg = '1' and rh0_npr = '1' and have_rh70 = 1 else '0';
   rh0: rh11 port map(
      base_addr => o"776700",
      ivec => o"254",

      br => rh0_br,
      bg => rh0_bg,
      int_vector => rh0_ivec,

      npr => rh0_npr,
      npg => rh0_npg,

      bus_addr_match => rh0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => rh0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      bus_master_addr => rh0_addr,
      bus_master_dati => unibus_busmaster_dati,
      bus_master_dato => rh0_dato,
      bus_master_control_dati => rh0_control_dati,
      bus_master_control_dato => rh0_control_dato,
      bus_master_nxm => busmaster_nxmabort,

      rh70_bus_master_addr => rh70_bus_master_addr,
      rh70_bus_master_dati => rh70_bus_master_dati,
      rh70_bus_master_dato => rh70_bus_master_dato,
      rh70_bus_master_control_dati => rh70_bus_master_control_dati,
      rh70_bus_master_control_dato => rh70_bus_master_control_dato,
      rh70_bus_master_nxm => rh70_bus_master_nxm,

      sdcard_cs => rh_sdcard_cs,
      sdcard_mosi => rh_sdcard_mosi,
      sdcard_sclk => rh_sdcard_sclk,
      sdcard_miso => rh_sdcard_miso,
      sdcard_debug => rh_sdcard_debug,

      rh_type => rh_type,
      rh_noofcyl => rh_noofcyl,

      have_rh => have_rh,
      have_rh70 => have_rh70,
      reset => cpu_init,
      clk50mhz => clk50mhz,
      nclk => nclk,
      clk => clk
   );

   xu0: xu port map(
      base_addr => o"774510",
      ivec => o"120",

      br => xu0_br,
      bg => xu0_bg,
      int_vector => xu0_ivec,

      npr => xu0_npr,
      npg => xu0_npg,

      bus_addr_match => xu0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => xu0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      bus_master_addr => xu0_addr,
      bus_master_dati => unibus_busmaster_dati,
      bus_master_dato => xu0_dato,
      bus_master_control_dati => xu0_control_dati,
      bus_master_control_dato => xu0_control_dato,
      bus_master_nxm => busmaster_nxmabort,

-- ethernet, enc424j600 controller interface
      xu_cs => xu_cs,
      xu_mosi => xu_mosi,
      xu_sclk => xu_sclk,
      xu_miso => xu_miso,
      xu_srdy => xu_srdy,

-- flags
      have_xu => have_xu,
      have_xu_debug => have_xu_debug,
      have_xu_enc => have_xu_enc,
      have_xu_esp => have_xu_esp,

-- clock & reset
      tx => xu_debug_tx,
      cpuclk => clk,
      nclk => nclk,
      clk50mhz => clk50mhz,
      reset => reset
   );

   dr11c0_ivec1 <= o"300" when have_kl11 = 1
      else o"310" when have_kl11 = 2
      else o"320" when have_kl11 = 3
      else o"330" when have_kl11 = 4
      else o"370";                                                   -- least likely to be in the way
   dr11c0_ivec2 <= dr11c0_ivec1 + o"004";

   dr11c0: dr11c port map(
      base_addr => o"767770",
      ivec1 => dr11c0_ivec1,
      ivec2 => dr11c0_ivec2,

      br => dr11c0_br,
      bg => dr11c0_bg,
      int_vector => dr11c0_ivec,

      bus_addr_match => dr11c0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => dr11c0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      have_dr11c => have_dr11c,
      have_dr11c_loopback => have_dr11c_loopback,
      have_dr11c_signal_stretch => have_dr11c_signal_stretch,
      dr11c_in => dr11c_in,
      dr11c_out => dr11c_out,
      dr11c_reqa => dr11c_reqa,
      dr11c_reqb => dr11c_reqb,
      dr11c_csr0 => dr11c_csr0,
      dr11c_csr1 => dr11c_csr1,
      dr11c_ndr => dr11c_ndr,
      dr11c_ndrlo => dr11c_ndrlo,
      dr11c_ndrhi => dr11c_ndrhi,
      dr11c_dxm => dr11c_dxm,
      dr11c_init => dr11c_init,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

-- minc cards

   mncad0: mncad port map(
      base_addr => o"771000",
      ivec => o"400",

      br => mncad0_br,
      bg => mncad0_bg,
      int_vector => mncad0_ivec,

      bus_addr_match => mncad0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncad0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      st1 => kw0_st1out,
      clkov => kw0_clkov,

      ad_start => mncad0_start,
      ad_done => mncad0_done,
      ad_channel => mncad0_channel,
      ad_nxc => mncad0_nxc,
      ad_sample => mncad0_sample,
      ad_type => mncad0_chtype,
      ad_chgbits => mncad0_chgbits,
      ad_wcgbits => mncad0_wcgbits,

      have_mncad => have_mncad,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mnckw0 <= 1 when have_mnckw >= 1 else 0;
   mnckw0: mnckw port map(
      base_addr => o"771020",
      ivec => o"440",

      br => mnckw0_br,
      bg => mnckw0_bg,
      int_vector => mnckw0_ivec,

      bus_addr_match => mnckw0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mnckw0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      st1in => kw0_st1in,
      st2in => kw0_st2in,
      st1out => kw0_st1out,
      st2out => kw0_st2out,
      clkov => kw0_clkov,

      have_mnckw => have_mnckw0,
      have_mnckw_pulse_stretch => have_mnckw_pulse_stretch,
      have_mnckw_pulse_invert => have_mnckw_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   kw0_st1in <= mnckw0_st1in;
   kw0_st2in <= mnckw0_st2in;
   mnckw0_st1out <= kw0_st1out;
   mnckw0_st2out <= kw0_st2out;
   mnckw0_clkov <= kw0_clkov;

   have_mnckw1 <= 1 when have_mnckw >= 2 else 0;
   mnckw1: mnckw port map(
      base_addr => o"771024",
      ivec => o"450",

      br => mnckw1_br,
      bg => mnckw1_bg,
      int_vector => mnckw1_ivec,

      bus_addr_match => mnckw1_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mnckw1_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      have_mnckw => have_mnckw1,
      have_mnckw_pulse_stretch => have_mnckw_pulse_stretch,
      have_mnckw_pulse_invert => have_mnckw_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mncaa0 <= 1 when have_mncaa >= 1 else 0;
   mncaa0: mncaa port map(
      base_addr => o"771060",

      bus_addr_match => mncaa0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncaa0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      da_dac0 => mncaa0_dac0,
      da_dac1 => mncaa0_dac1,
      da_dac2 => mncaa0_dac2,
      da_dac3 => mncaa0_dac3,

      have_mncaa => have_mncaa0,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mncaa1 <= 1 when have_mncaa >= 2 else 0;
   mncaa1: mncaa port map(
      base_addr => o"771070",

      bus_addr_match => mncaa1_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncaa1_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      da_dac0 => mncaa1_dac0,
      da_dac1 => mncaa1_dac1,
      da_dac2 => mncaa1_dac2,
      da_dac3 => mncaa1_dac3,

      have_mncaa => have_mncaa1,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mncaa2 <= 1 when have_mncaa >= 3 else 0;
   mncaa2: mncaa port map(
      base_addr => o"771100",

      bus_addr_match => mncaa2_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncaa2_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      da_dac0 => mncaa2_dac0,
      da_dac1 => mncaa2_dac1,
      da_dac2 => mncaa2_dac2,
      da_dac3 => mncaa2_dac3,

      have_mncaa => have_mncaa2,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mncaa3 <= 1 when have_mncaa >= 4 else 0;
   mncaa3: mncaa port map(
      base_addr => o"771110",

      bus_addr_match => mncaa3_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncaa3_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      da_dac0 => mncaa3_dac0,
      da_dac1 => mncaa3_dac1,
      da_dac2 => mncaa3_dac2,
      da_dac3 => mncaa3_dac3,

      have_mncaa => have_mncaa3,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );

   have_mncdi0 <= 1 when have_mncdi >= 1 else 0;
   mncdi0: mncdi port map(
      base_addr => o"771160",
      ivec => o"120",

      br => mncdi0_br,
      bg => mncdi0_bg,
      int_vector => mncdi0_ivec,

      bus_addr_match => mncdi0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdi0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => di0_d,
      strobe => di0_strobe,
      reply => di0_reply,
      pgmout => di0_pgmout,
      event => di0_event,

      have_mncdi => have_mncdi0,
      have_mncdi_pulse_stretch => have_mncdi_pulse_stretch,
      have_mncdi_pulse_invert => have_mncdi_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   di0_d <= mncdi0_dir when have_mncdi_loopback = 0 else do0_d;
   di0_strobe <= mncdi0_strobe when have_mncdi_loopback = 0 else do0_hb_strobe;
   mncdi0_reply <= di0_reply;
   mncdi0_pgmout <= di0_pgmout;
   mncdi0_event <= di0_event;

   have_mncdi1 <= 1 when have_mncdi >= 2 else 0;
   mncdi1: mncdi port map(
      base_addr => o"771170",
      ivec => o"130",

      br => mncdi1_br,
      bg => mncdi1_bg,
      int_vector => mncdi1_ivec,

      bus_addr_match => mncdi1_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdi1_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => di1_d,
      strobe => di1_strobe,
      reply => di1_reply,
      pgmout => di1_pgmout,
      event => di1_event,

      have_mncdi => have_mncdi1,
      have_mncdi_pulse_stretch => have_mncdi_pulse_stretch,
      have_mncdi_pulse_invert => have_mncdi_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   di1_d <= mncdi1_dir when have_mncdi_loopback = 0 else do1_d;
   di1_strobe <= mncdi1_strobe when have_mncdi_loopback = 0 else do1_hb_strobe;
   mncdi1_reply <= di1_reply;
   mncdi1_pgmout <= di1_pgmout;
   mncdi1_event <= di1_event;

   have_mncdi2 <= 1 when have_mncdi >= 3 else 0;
   mncdi2: mncdi port map(
      base_addr => o"771200",
      ivec => o"140",

      br => mncdi2_br,
      bg => mncdi2_bg,
      int_vector => mncdi2_ivec,

      bus_addr_match => mncdi2_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdi2_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => di2_d,
      strobe => di2_strobe,
      reply => di2_reply,
      pgmout => di2_pgmout,
      event => di2_event,

      have_mncdi => have_mncdi2,
      have_mncdi_pulse_stretch => have_mncdi_pulse_stretch,
      have_mncdi_pulse_invert => have_mncdi_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   di2_d <= mncdi2_dir when have_mncdi_loopback = 0 else do2_d;
   di2_strobe <= mncdi2_strobe when have_mncdi_loopback = 0 else do2_hb_strobe;
   mncdi2_reply <= di2_reply;
   mncdi2_pgmout <= di2_pgmout;
   mncdi2_event <= di2_event;

   have_mncdi3 <= 1 when have_mncdi >= 4 else 0;
   mncdi3: mncdi port map(
      base_addr => o"771210",
      ivec => o"150",

      br => mncdi3_br,
      bg => mncdi3_bg,
      int_vector => mncdi3_ivec,

      bus_addr_match => mncdi3_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdi3_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => di3_d,
      strobe => di3_strobe,
      reply => di3_reply,
      pgmout => di3_pgmout,
      event => di3_event,

      have_mncdi => have_mncdi3,
      have_mncdi_pulse_stretch => have_mncdi_pulse_stretch,
      have_mncdi_pulse_invert => have_mncdi_pulse_invert,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   di3_d <= mncdi3_dir when have_mncdi_loopback = 0 else do3_d;
   di3_strobe <= mncdi3_strobe when have_mncdi_loopback = 0 else do3_hb_strobe;
   mncdi3_reply <= di3_reply;
   mncdi3_pgmout <= di3_pgmout;
   mncdi3_event <= di3_event;

   have_mncdo0 <= 1 when have_mncdo >= 1 else 0;
   mncdo0: mncdo port map(
      base_addr => o"771260",
      ivec => o"340",

      br => mncdo0_br,
      bg => mncdo0_bg,
      int_vector => mncdo0_ivec,

      bus_addr_match => mncdo0_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdo0_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => do0_d,
      hb_strobe => do0_hb_strobe,
      lb_strobe => do0_lb_strobe,
      reply => do0_reply,
      ie => do0_ie,

      have_mncdo => have_mncdo0,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   do0_reply <= mncdo0_reply when have_mncdi_loopback = 0 else di0_reply;
   mncdo0_dor <= do0_d;
   mncdo0_hb_strobe <= do0_hb_strobe;
   mncdo0_lb_strobe <= do0_lb_strobe;
   mncdo0_ie <= do0_ie;

   have_mncdo1 <= 1 when have_mncdo >= 2 else 0;
   mncdo1: mncdo port map(
      base_addr => o"771264",
      ivec => o"344",

      br => mncdo1_br,
      bg => mncdo1_bg,
      int_vector => mncdo1_ivec,

      bus_addr_match => mncdo1_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdo1_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => do1_d,
      hb_strobe => do1_hb_strobe,
      lb_strobe => do1_lb_strobe,
      reply => do1_reply,
      ie => do1_ie,

      have_mncdo => have_mncdo1,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   do1_reply <= mncdo1_reply when have_mncdi_loopback = 0 else di1_reply;
   mncdo1_dor <= do1_d;
   mncdo1_hb_strobe <= do1_hb_strobe;
   mncdo1_lb_strobe <= do1_lb_strobe;
   mncdo1_ie <= do1_ie;

   have_mncdo2 <= 1 when have_mncdo >= 3 else 0;
   mncdo2: mncdo port map(
      base_addr => o"771270",
      ivec => o"350",

      br => mncdo2_br,
      bg => mncdo2_bg,
      int_vector => mncdo2_ivec,

      bus_addr_match => mncdo2_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdo2_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => do2_d,
      hb_strobe => do2_hb_strobe,
      lb_strobe => do2_lb_strobe,
      reply => do2_reply,
      ie => do2_ie,

      have_mncdo => have_mncdo2,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   do2_reply <= mncdo2_reply when have_mncdi_loopback = 0 else di2_reply;
   mncdo2_dor <= do2_d;
   mncdo2_hb_strobe <= do2_hb_strobe;
   mncdo2_lb_strobe <= do2_lb_strobe;
   mncdo2_ie <= do2_ie;

   have_mncdo3 <= 1 when have_mncdo >= 4 else 0;
   mncdo3: mncdo port map(
      base_addr => o"771274",
      ivec => o"354",

      br => mncdo3_br,
      bg => mncdo3_bg,
      int_vector => mncdo3_ivec,

      bus_addr_match => mncdo3_addr_match,
      bus_addr => unibus_addr,
      bus_dati => mncdo3_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      d => do3_d,
      hb_strobe => do3_hb_strobe,
      lb_strobe => do3_lb_strobe,
      reply => do3_reply,
      ie => do3_ie,

      have_mncdo => have_mncdo3,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
   do3_reply <= mncdo3_reply when have_mncdi_loopback = 0 else di3_reply;
   mncdo3_dor <= do3_d;
   mncdo3_hb_strobe <= do3_hb_strobe;
   mncdo3_lb_strobe <= do3_lb_strobe;
   mncdo3_ie <= do3_ie;


   ibv0: ibv11 port map(
      base_addr => o"771420",
      ivec => o"420",

      br => ibv11_br,
      bg => ibv11_bg,
      int_vector => ibv11_ivec,

      bus_addr_match => ibv11_addr_match,
      bus_addr => unibus_addr,
      bus_dati => ibv11_dati,
      bus_dato => unibus_dato,
      bus_control_dati => unibus_control_dati,
      bus_control_dato => unibus_control_dato,
      bus_control_datob => unibus_control_datob,

      have_ibv11 => have_ibv11,

      clk50mhz => clk50mhz,
      reset => cpu_init,
      clk => nclk
   );
--

   nclk <= not clk;
   ifetch <= ifetchcopy;

-- console logic

   cons_run <= cpu_cons_run;
   cons_consphy <= cpu_cons_consphy;
   process(nclk)
   begin
      if nclk = '1' and nclk'event then
         if unibus_control_dati = '1' or unibus_control_dato = '1' then
            cons_progphy <= "1111" & unibus_addr;
         else
--            if bus_control_dati = '1' or bus_control_dato = '1' then
               cons_progphy <= bus_addr;
--             end if;
--             if cpu_cons_run = '1' then                                            -- this bit is to set the addr display to the incremented r7 value during wait/reset
--                cons_progphy <= bus_addr;
--             end if;
--             if cons_exadep = '1' then        -- ehh, what needs to happen is that for the halt states, exadep is driven so the mmu drives the right translation. Then maybe, the
--                cons_progphy <= bus_addr;     -- actual mapping here can be on bus_addr always.
--             end if;
         end if;

         cons_parh <= dati(15) xor dati(14) xor dati(13) xor dati(12) xor dati(11) xor dati(10) xor dati(9) xor dati(8);
         cons_parl <= dati(7) xor dati(6) xor dati(5) xor dati(4) xor dati(3) xor dati(2) xor dati(1) xor dati(0);

      end if;
   end process;

   have_rh70 <= 1 when modelcode = 70 else 0;


   unibus_dati <=
      cr_dati when cr_addr_match = '1'
      else kl0_dati when kl0_addr_match = '1'
      else kl1_dati when kl1_addr_match = '1'
      else kl2_dati when kl2_addr_match = '1'
      else kl3_dati when kl3_addr_match = '1'
      else kw0_dati when kw0_addr_match = '1'
      else csdr_dati when csdr_addr_match = '1'
      else bootrom0_minc_dati when bootrom0_minc_addr_match = '1'
      else bootrom1_minc_dati when bootrom1_minc_addr_match = '1'
      else bootrom0_pdp2011_dati when bootrom0_pdp2011_addr_match = '1'
      else bootrom1_pdp2011_dati when bootrom1_pdp2011_addr_match = '1'
      else bootrom0_odt_dati when bootrom0_odt_addr_match = '1'
      else bootrom1_odt_dati when bootrom1_odt_addr_match = '1'
      else rl0_dati when rl0_addr_match = '1'
      else rk0_dati when rk0_addr_match = '1'
      else rh0_dati when rh0_addr_match = '1'
      else xu0_dati when xu0_addr_match = '1'
      else dr11c0_dati when dr11c0_addr_match = '1'
      else mncad0_dati when mncad0_addr_match = '1'
      else mnckw0_dati when mnckw0_addr_match = '1'
      else mnckw1_dati when mnckw1_addr_match = '1'
      else mncaa0_dati when mncaa0_addr_match = '1'
      else mncaa1_dati when mncaa1_addr_match = '1'
      else mncaa2_dati when mncaa2_addr_match = '1'
      else mncaa3_dati when mncaa3_addr_match = '1'
      else mncdi0_dati when mncdi0_addr_match = '1'
      else mncdi1_dati when mncdi1_addr_match = '1'
      else mncdi2_dati when mncdi2_addr_match = '1'
      else mncdi3_dati when mncdi3_addr_match = '1'
      else mncdo0_dati when mncdo0_addr_match = '1'
      else mncdo1_dati when mncdo1_addr_match = '1'
      else mncdo2_dati when mncdo2_addr_match = '1'
      else mncdo3_dati when mncdo3_addr_match = '1'
      else ibv11_dati when ibv11_addr_match = '1'
      else "0000000000000000";

   unibus_addr_match <= '1'
      when cr_addr_match = '1'
      or kl0_addr_match = '1'
      or kl1_addr_match = '1'
      or kl2_addr_match = '1'
      or kl3_addr_match = '1'
      or kw0_addr_match = '1'
      or csdr_addr_match = '1'
      or bootrom0_minc_addr_match = '1'
      or bootrom1_minc_addr_match = '1'
      or bootrom0_pdp2011_addr_match = '1'
      or bootrom1_pdp2011_addr_match = '1'
      or bootrom0_odt_addr_match = '1'
      or bootrom1_odt_addr_match = '1'
      or rl0_addr_match = '1'
      or rk0_addr_match = '1'
      or rh0_addr_match = '1'
      or xu0_addr_match = '1'
      or dr11c0_addr_match = '1'
      or mncad0_addr_match = '1'
      or mnckw0_addr_match = '1'
      or mnckw1_addr_match = '1'
      or mncaa0_addr_match = '1'
      or mncaa1_addr_match = '1'
      or mncaa2_addr_match = '1'
      or mncaa3_addr_match = '1'
      or mncdi0_addr_match = '1'
      or mncdi1_addr_match = '1'
      or mncdi2_addr_match = '1'
      or mncdi3_addr_match = '1'
      or mncdo0_addr_match = '1'
      or mncdo1_addr_match = '1'
      or mncdo2_addr_match = '1'
      or mncdo3_addr_match = '1'
      or ibv11_addr_match = '1'
--      or addr_match = '1'
      else '0';

   cer_nxmabort <= '1'
      when addr_match = '0'
      and (bus_control_dati = '1' or bus_control_dato = '1')
      and bus_unibus_mapped = '0'
      and cpu_npg = '0'
      else '0';

   cer_ioabort <= '1'
      when unibus_addr_match = '0' and (unibus_control_dati = '1' or unibus_control_dato = '1') and unibus_addr(17 downto 13) = "11111" and cpu_npg = '0'
      else '1' when addr_match = '0' and bus_unibus_mapped = '1' and (bus_control_dati = '1' or bus_control_dato = '1') and cpu_npg = '0'
      else '0';

   nxmabort <= '1' when cer_nxmabort = '1' or cer_ioabort = '1' else '0';

   oddabort <=
      '1' when bus_control_dato = '1' and bus_control_datob = '0' and bus_addr(0) = '1' and have_oddabort = 1
      else '1' when ifetchcopy = '1' and unibus_control_dati = '1' and unibus_addr(17 downto 13) = "11111"
         and bootrom0_minc_addr_match /= '1' and bootrom1_minc_addr_match /= '1'
         and bootrom0_pdp2011_addr_match /= '1' and bootrom1_pdp2011_addr_match /= '1'
         and bootrom0_odt_addr_match /= '1' and bootrom1_odt_addr_match /= '1'
         and have_oddabort = 1
      else '1' when mmu_oddabort = '1' and have_oddabort = 1
      else '0';

   busmaster_nxmabort <=
      '1' when cpu_npg = '1' and unibus_addr_match = '0' and (unibus_control_dati = '1' or unibus_control_dato = '1') and unibus_addr(17 downto 13) = "11111"      -- FIXME, why is this needed again?
      else '1' when cpu_npg = '1' and addr_match = '0' and (bus_control_dati = '1' or bus_control_dato = '1') and have_rh70 = 0
      else '0';

   unibus_busmaster_addr <= rl0_addr when rl0_npg = '1'
      else rk0_addr when rk0_npg = '1'
      else rh0_addr when rh0_npg = '1' and have_rh70 = 0
      else xu0_addr when xu0_npg = '1'
      else "000000000000000000";
   unibus_busmaster_dato <= rl0_dato when rl0_npg = '1'
      else rk0_dato when rk0_npg = '1'
      else rh0_dato when rh0_npg = '1' and have_rh70 = 0
      else xu0_dato when xu0_npg = '1'
      else "0000000000000000";
   unibus_busmaster_control_dati <= rl0_control_dati when rl0_npg = '1'
      else rk0_control_dati when rk0_npg = '1'
      else rh0_control_dati when rh0_npg = '1' and have_rh70 = 0
      else xu0_control_dati when xu0_npg = '1'
      else '0';
   unibus_busmaster_control_dato <= rl0_control_dato when rl0_npg = '1'
      else rk0_control_dato when rk0_npg = '1'
      else rh0_control_dato when rh0_npg = '1' and have_rh70 = 0
      else xu0_control_dato when xu0_npg = '1'
      else '0';
   unibus_busmaster_control_datob <= '0' when rl0_npg = '1'
      else '0' when rk0_npg = '1'
      else '0' when rh0_npg = '1' and have_rh70 = 0
      else '0' when xu0_npg = '1'
      else '0';
   unibus_busmaster_control_npg <= '1' when rl0_npg = '1'
      else '1' when rk0_npg = '1'
      else '1' when rh0_npg = '1' and have_rh70 = 0
      else '1' when xu0_npg = '1'
      else '0';

-- regular memory interface and rh70 interface to it
   addr <= rh70_bus_master_addr when rh0_npg = '1' and have_rh70 = 1
      else bus_addr;
   dato <= rh70_bus_master_dato when rh0_npg = '1' and have_rh70 = 1
      else bus_dato;
   bus_dati <= dati;
   rh70_bus_master_dati <= dati;
   control_dati <= rh70_bus_master_control_dati when rh0_npg = '1' and have_rh70 = 1
      else bus_control_dati;
   control_dato <= rh70_bus_master_control_dato when rh0_npg = '1' and have_rh70 = 1
      else bus_control_dato;
   control_datob <= '0' when rh0_npg = '1' and have_rh70 = 1
      else bus_control_datob;

   cpu_addr_v <= cpu_addr;

   cpu_br7 <= '0';

-- npr logic

   process(nclk, reset)
   begin
      if nclk = '1' and nclk'event then
         if reset = '1' then
            cpu_npr <= '0';
--            cpu_br7 <= '0';
            cpu_br6 <= '0';
            cpu_br5 <= '0';
            cpu_br4 <= '0';
         else

            case npr_state is
               when npr_idle =>
                  cpu_npr <= '0';
                  rl0_npg <= '0';
                  rk0_npg <= '0';
                  rh0_npg <= '0';
                  xu0_npg <= '0';

                  if rl0_npr = '1' then
                     npr_state <=   npr_rl0;
                  elsif rk0_npr = '1' then
                     npr_state <= npr_rk0;
                  elsif rh0_npr = '1' then
                     npr_state <= npr_rh0;
                  elsif xu0_npr = '1' then
                     npr_state <= npr_xu0;
                  end if;

               when npr_rl0 =>
                  cpu_npr <= '1';
                  if rl0_npr = '0' then
                     npr_state <= npr_idle;
                     rl0_npg <= '0';
                  else
                     rl0_npg <= cpu_npg;
                  end if;

               when npr_rk0 =>
                  cpu_npr <= '1';
                  if rk0_npr = '0' then
                     npr_state <= npr_idle;
                     rk0_npg <= '0';
                  else
                     rk0_npg <= cpu_npg;
                  end if;

               when npr_rh0 =>
                  cpu_npr <= '1';
                  if rh0_npr = '0' then
                     npr_state <= npr_idle;
                     rh0_npg <= '0';
                  else
                     rh0_npg <= cpu_npg;
                  end if;

               when npr_xu0 =>
                  cpu_npr <= '1';
                  if xu0_npr = '0' then
                     npr_state <= npr_idle;
                     xu0_npg <= '0';
                  else
                     xu0_npg <= cpu_npg;
                  end if;

               when others =>
                  npr_state <= npr_idle;

            end case;

            case br6_state is
               when br6_idle =>
                  if kw0_br = '1' then
                     br6_state <= br6_kw0;
                     cpu_br6 <= kw0_br;
                  elsif mncad0_br = '1' then
                     br6_state <= br6_mncad0;
                     cpu_br6 <= mncad0_br;
                  else
                     cpu_br6 <= '0';
                  end if;

               when br6_kw0 =>
                  cpu_br6 <= kw0_br;
                  kw0_bg <= cpu_bg6;
                  cpu_int_vector6 <= kw0_ivec;
                  if kw0_br = '0' and kw0_bg = '0' then
                     br6_state <= br6_idle;
                  end if;

               when br6_mncad0 =>
                  cpu_br6 <= mncad0_br;
                  mncad0_bg <= cpu_bg6;
                  cpu_int_vector6 <= mncad0_ivec;
                  if mncad0_br = '0' and mncad0_bg = '0' then
                     br6_state <= br6_idle;
                  end if;

               when others =>
                  br6_state <= br6_idle;

            end case;

            case br5_state is

               when br5_idle =>
                  if rh0_br = '1' then
                     br5_state <= br5_rh0;
                     cpu_br5 <= rh0_br;
                  elsif xu0_br = '1' then
                     br5_state <= br5_xu0;
                     cpu_br5 <= xu0_br;
                  elsif rl0_br = '1' then
                     br5_state <= br5_rl0;
                     cpu_br5 <= rl0_br;
                  elsif rk0_br = '1' then
                     br5_state <= br5_rk0;
                     cpu_br5 <= rk0_br;
                  elsif dr11c0_br = '1' then
                     br5_state <= br5_dr11c0;
                     cpu_br5 <= dr11c0_br;
                  else
                     cpu_br5 <= '0';
                  end if;

               when br5_rh0 =>
                  cpu_br5 <= rh0_br;
                  rh0_bg <= cpu_bg5;
                  cpu_int_vector5 <= rh0_ivec;
                  if rh0_br = '0' and rh0_bg = '0' then
                     br5_state <= br5_idle;
                  end if;

               when br5_xu0 =>
                  cpu_br5 <= xu0_br;
                  xu0_bg <= cpu_bg5;
                  cpu_int_vector5 <= xu0_ivec;
                  if xu0_br = '0' and xu0_bg = '0' then
                     br5_state <= br5_idle;
                  end if;

               when br5_rl0 =>
                  cpu_br5 <= rl0_br;
                  rl0_bg <= cpu_bg5;
                  cpu_int_vector5 <= rl0_ivec;
                  if rl0_br = '0' and rl0_bg = '0' then
                     br5_state <= br5_idle;
                  end if;

               when br5_rk0 =>
                  cpu_br5 <= rk0_br;
                  rk0_bg <= cpu_bg5;
                  cpu_int_vector5 <= rk0_ivec;
                  if rk0_br = '0' and rk0_bg = '0' then
                     br5_state <= br5_idle;
                  end if;

               when br5_dr11c0 =>
                  cpu_br5 <= dr11c0_br;
                  dr11c0_bg <= cpu_bg5;
                  cpu_int_vector5 <= dr11c0_ivec;
                  if dr11c0_br = '0' and dr11c0_bg = '0' then
                     br5_state <= br5_idle;
                  end if;

               when others =>
                  br5_state <= br5_idle;

            end case;

            case br4_state is

               when br4_idle =>
                  if kl0_br = '1' then
                     br4_state <= br4_kl0;
                     cpu_br4 <= kl0_br;
                  elsif kl1_br = '1' then
                     br4_state <= br4_kl1;
                     cpu_br4 <= kl1_br;
                  elsif kl2_br = '1' then
                     br4_state <= br4_kl2;
                     cpu_br4 <= kl2_br;
                  elsif kl3_br = '1' then
                     br4_state <= br4_kl3;
                     cpu_br4 <= kl3_br;
                  elsif mnckw0_br = '1' then
                     br4_state <= br4_mnckw0;
                     cpu_br4 <= mnckw0_br;
                  elsif mnckw1_br = '1' then
                     br4_state <= br4_mnckw1;
                     cpu_br4 <= mnckw1_br;
                  elsif mncdi0_br = '1' then
                     br4_state <= br4_mncdi0;
                     cpu_br4 <= mncdi0_br;
                  elsif mncdi1_br = '1' then
                     br4_state <= br4_mncdi1;
                     cpu_br4 <= mncdi1_br;
                  elsif mncdi2_br = '1' then
                     br4_state <= br4_mncdi2;
                     cpu_br4 <= mncdi2_br;
                  elsif mncdi3_br = '1' then
                     br4_state <= br4_mncdi3;
                     cpu_br4 <= mncdi3_br;
                  elsif mncdo0_br = '1' then
                     br4_state <= br4_mncdo0;
                     cpu_br4 <= mncdo0_br;
                  elsif mncdo1_br = '1' then
                     br4_state <= br4_mncdo1;
                     cpu_br4 <= mncdo1_br;
                  elsif mncdo2_br = '1' then
                     br4_state <= br4_mncdo2;
                     cpu_br4 <= mncdo2_br;
                  elsif mncdo3_br = '1' then
                     br4_state <= br4_mncdo3;
                     cpu_br4 <= mncdo3_br;
                  elsif ibv11_br = '1' then
                     br4_state <= br4_ibv11;
                     cpu_br4 <= ibv11_br;
                  else
                     cpu_br4 <= '0';
                  end if;

               when br4_kl0 =>
                  cpu_br4 <= kl0_br;
                  kl0_bg <= cpu_bg4;
                  cpu_int_vector4 <= kl0_ivec;
                  if kl0_br = '0' and kl0_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_kl1 =>
                  cpu_br4 <= kl1_br;
                  kl1_bg <= cpu_bg4;
                  cpu_int_vector4 <= kl1_ivec;
                  if kl1_br = '0' and kl1_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_kl2 =>
                  cpu_br4 <= kl2_br;
                  kl2_bg <= cpu_bg4;
                  cpu_int_vector4 <= kl2_ivec;
                  if kl2_br = '0' and kl2_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_kl3 =>
                  cpu_br4 <= kl3_br;
                  kl3_bg <= cpu_bg4;
                  cpu_int_vector4 <= kl3_ivec;
                  if kl3_br = '0' and kl3_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mnckw0 =>
                  cpu_br4 <= mnckw0_br;
                  mnckw0_bg <= cpu_bg4;
                  cpu_int_vector4 <= mnckw0_ivec;
                  if mnckw0_br = '0' and mnckw0_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mnckw1 =>
                  cpu_br4 <= mnckw1_br;
                  mnckw1_bg <= cpu_bg4;
                  cpu_int_vector4 <= mnckw1_ivec;
                  if mnckw1_br = '0' and mnckw1_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdi0 =>
                  cpu_br4 <= mncdi0_br;
                  mncdi0_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdi0_ivec;
                  if mncdi0_br = '0' and mncdi0_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdi1 =>
                  cpu_br4 <= mncdi1_br;
                  mncdi1_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdi1_ivec;
                  if mncdi1_br = '0' and mncdi1_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdi2 =>
                  cpu_br4 <= mncdi2_br;
                  mncdi2_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdi2_ivec;
                  if mncdi2_br = '0' and mncdi2_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdi3 =>
                  cpu_br4 <= mncdi3_br;
                  mncdi3_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdi3_ivec;
                  if mncdi3_br = '0' and mncdi3_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdo0 =>
                  cpu_br4 <= mncdo0_br;
                  mncdo0_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdo0_ivec;
                  if mncdo0_br = '0' and mncdo0_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdo1 =>
                  cpu_br4 <= mncdo1_br;
                  mncdo1_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdo1_ivec;
                  if mncdo1_br = '0' and mncdo1_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdo2 =>
                  cpu_br4 <= mncdo2_br;
                  mncdo2_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdo2_ivec;
                  if mncdo2_br = '0' and mncdo2_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_mncdo3 =>
                  cpu_br4 <= mncdo3_br;
                  mncdo3_bg <= cpu_bg4;
                  cpu_int_vector4 <= mncdo3_ivec;
                  if mncdo3_br = '0' and mncdo3_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when br4_ibv11 =>
                  cpu_br4 <= ibv11_br;
                  ibv11_bg <= cpu_bg4;
                  cpu_int_vector4 <= ibv11_ivec;
                  if ibv11_br = '0' and ibv11_bg = '0' then
                     br4_state <= br4_idle;
                  end if;

               when others =>
                  br4_state <= br4_idle;

            end case;


         end if;
      end if;
   end process;

end implementation;

