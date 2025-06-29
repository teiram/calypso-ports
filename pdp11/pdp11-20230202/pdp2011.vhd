
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


package pdp2011 is

--
-- main section: major components that go into a top.vhd
--

constant boot_pdp2011 : integer := 1;                                -- the original pdp2011 'hello world' bootrom that boots the first available disk from rk, rl, rp - in that order
constant boot_minc : integer := 2;                                   -- a variant of the pdp2011 bootrom that lists the minc devices instead
constant boot_odt : integer := 3;                                    -- the 11/34 mini odt console simulator bootrom; see m9312 documentation

component unibus is
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
end component;


component paneldriver is
   port(
      panel_xled : out std_logic_vector(5 downto 0);
      panel_col : inout std_logic_vector(11 downto 0);
      panel_row : out std_logic_vector(2 downto 0);

      cons_load : out std_logic;
      cons_exa : out std_logic;
      cons_dep : out std_logic;
      cons_cont : out std_logic;
      cons_ena : out std_logic;
      cons_inst : out std_logic;
      cons_start : out std_logic;
      cons_sw : out std_logic_vector(21 downto 0);
      cons_adss_mode : out std_logic_vector(1 downto 0);
      cons_adss_id : out std_logic;
      cons_adss_cons : out std_logic;

      cons_consphy : in std_logic_vector(21 downto 0);
      cons_progphy : in std_logic_vector(21 downto 0);
      cons_shfr : in std_logic_vector(15 downto 0);
      cons_maddr : in std_logic_vector(15 downto 0);                 -- microcode address fpu/cpu
      cons_br : in std_logic_vector(15 downto 0);
      cons_dr : in std_logic_vector(15 downto 0);
      cons_parh : in std_logic;
      cons_parl : in std_logic;

      cons_adrserr : in std_logic;
      cons_run : in std_logic;
      cons_pause : in std_logic;
      cons_master : in std_logic;
      cons_kernel : in std_logic;
      cons_super : in std_logic;
      cons_user : in std_logic;
      cons_id : in std_logic;
      cons_map16 : in std_logic;
      cons_map18 : in std_logic;
      cons_map22 : in std_logic;

      sample_cycles : in std_logic_vector(15 downto 0) := x"0400";   -- a sample is this many runs of the panel state machine (which has 16 cycles, so multiply by that)
      minon_cycles : in std_logic_vector(15 downto 0) := x"0400";    -- if a signal has been on for this many cycles in a sample, then the corresponding output will be on - note 16, above.

      paneltype : in integer range 0 to 3 := 0;                      -- 0 - no console; 1 - PiDP11, regular; 2 - PiDP11, widdershins; 3 - PDP2011 nanocons

      cons_reset : out std_logic;                                    -- a request for a reset from the console

      clkin : in std_logic;
      reset : in std_logic
   );
end component;


component vt10x is
   port(
      vga_hsync : out std_logic;                                     -- horizontal sync
      vga_vsync : out std_logic;                                     -- vertical sync
      vga_fb : out std_logic;                                        -- output - full
      vga_ht : out std_logic;                                        -- output - half

-- serial port
      tx : out std_logic;                                            -- transmit
      rx : in std_logic;                                             -- receive
      rts : out std_logic;                                           -- request to send
      cts : in std_logic := '0';                                     -- clear to send
      bps : in integer range 1200 to 230400 := 9600;                 -- bps rate - don't set to more than 38400
      force7bit : in integer range 0 to 1 := 0;                      -- zero out high order bit on transmission and reception
      rtscts : in integer range 0 to 1 := 0;                         -- conditional compilation switch for rts and cts signals; also implies to include core that implements a silo buffer

-- ps2 keyboard
      ps2k_c : in std_logic;                                         -- clock
      ps2k_d : in std_logic;                                         -- data

-- debug & blinkenlights
      ifetch : out std_logic;                                        -- ifetch : the cpu is running an instruction fetch cycle
      iwait : out std_logic;                                         -- iwait : the cpu is in wait state
      teste : in std_logic := '0';                                   -- teste : display 24*80 capital E without changing the display buffer
      testf : in std_logic := '0';                                   -- testf : display 24*80 all pixels on
      vga_debug : out std_logic_vector(15 downto 0);                 -- debug output from microcode
      vga_bl : out std_logic_vector(9 downto 0);                     -- blinkenlight vector

-- vt type code : 100 or 105
      vttype : in integer range 100 to 105 := 100;                   -- vt100 or vt105
      vga_cursor_block : in std_logic := '1';                        -- cursor is block ('1') or underline ('0')
      vga_cursor_blink : in std_logic := '0';                        -- cursor blinks ('1') or not ('0')
      have_act_seconds : in integer range 0 to 7200 := 900;          -- auto screen off time, in seconds; 0 means disabled
      have_act : in integer range 1 to 2 := 2;                       -- auto screen off counter reset by keyboard and serial port activity (1) or keyboard only (2)

-- clock & reset
      cpuclk : in std_logic;                                         -- cpuclk : should be around 10MHz, give or take a few
      clk50mhz : in std_logic;                                       -- clk50mhz : used for vga signal timing
      reset : in std_logic                                           -- reset
   );
end component;


component sdram is
   port(
      addr: in std_logic_vector(21 downto 0);
      dati: out std_logic_vector(15 downto 0);
      dato: in std_logic_vector(15 downto 0);
      control_dati : in std_logic;
      control_dato : in std_logic;
      control_datob : in std_logic;
      dram_match : in std_logic;

      dram_addr : out std_logic_vector(12 downto 0);
      dram_dq : inout std_logic_vector(15 downto 0);
      dram_ba_1 : out std_logic;
      dram_ba_0 : out std_logic;
      dram_udqm : out std_logic;
      dram_ldqm : out std_logic;
      dram_ras_n : out std_logic;
      dram_cas_n : out std_logic;
      dram_we_n : out std_logic;
      dram_cs_n : out std_logic;
      dram_clk : out std_logic;
      dram_cke : out std_logic;
      dram_addr13 : out std_logic;

      reset : in std_logic;
      ext_reset : in std_logic := '0';
      cpureset : out std_logic;
      cpuclk : out std_logic;
      c0 : in std_logic
   );
end component;

--
-- components that go into the unibus - either of the main system, or of the vt and xu components
--

component cpu is
   port(
      addr_v : out std_logic_vector(15 downto 0);                    -- the virtual address that the cpu drives out to the bus for the current read or write
      datain : in std_logic_vector(15 downto 0);                     -- when doing a read, the data input to the cpu
      dataout : out std_logic_vector(15 downto 0);                   -- when doing a write, the data output from the cpu
      wr : out std_logic;                                            -- if '1', the cpu is doing a write to the bus and drives addr_v and dataout
      rd : out std_logic;                                            -- if '1', the cpu is doing a read from the bus, drives addr_v and reads datain
      dw8 : out std_logic;                                           -- if '1', the read or write initiated by the cpu is 8 bits wide
      cp : out std_logic;                                            -- if '1', the read or write should use the previous cpu mode
      ifetch : out std_logic;                                        -- if '1', this read is for an instruction fetch
      id : out std_logic;                                            -- if '1', the read or write should use data space
      init : out std_logic;                                          -- if '1', the devices on the bus should reset

      iwait : out std_logic;                                         -- if '1', the cpu is waiting for an interrupt

      br7 : in std_logic;                                            -- interrupt request, 7
      bg7 : out std_logic;                                           -- interrupt grant, 7
      int_vector7 : in std_logic_vector(8 downto 0);                 -- interrupt vector, 7
      br6 : in std_logic;                                            -- interrupt request, 6
      bg6 : out std_logic;                                           -- interrupt grant, 6
      int_vector6 : in std_logic_vector(8 downto 0);                 -- interrupt vector, 6
      br5 : in std_logic;                                            -- interrupt request, 5
      bg5 : out std_logic;                                           -- interrupt grant, 5
      int_vector5 : in std_logic_vector(8 downto 0);                 -- interrupt vector, 5
      bg4 : out std_logic;                                           -- interrupt request, 4
      br4 : in std_logic;                                            -- interrupt grant, 4
      int_vector4 : in std_logic_vector(8 downto 0);                 -- interrupt vector, 4

      mmutrap : in std_logic;                                        -- if '1', the mmu requests a trap to be serviced after the current instruction completes
      ack_mmutrap : out std_logic;                                   -- if '1', the mmu trap request is being acknowledged
      mmuabort : in std_logic;                                       -- if '1', the mmu requests that the current instruction is aborted because of a mmu fault
      ack_mmuabort : out std_logic;                                  -- if '1', the mmu abort request is being acknowledged

      npr : in std_logic;                                            -- non-processor request
      npg : out std_logic;                                           -- non-processor grant

      nxmabort : in std_logic;                                       -- nxm abort - a memory access cycle by the cpu refers to an address that does not exist
      oddabort : in std_logic;                                       -- odd abort - a memory access cycle by the cpu is for a full word, but uses an odd address
      illhalt : out std_logic;                                       -- a halt instruction was not executed because it was illegal in the current mode; for use in the cer cpu error register
      ysv : out std_logic;                                           -- a yellow stack trap is in progress - for use in the cer cpu error register
      rsv : out std_logic;                                           -- a red stack trap is in progress - for use in the cer cpu error register

      cpu_stack_limit : in std_logic_vector(15 downto 0);            -- the cpu stack limit control register value
      cpu_kmillhalt : in std_logic;                                  -- the control register setting for kernel mode illegal halt

      sr0_ic : out std_logic;                                        -- sr0/mmr0 instruction complete flag
      sr1 : out std_logic_vector(15 downto 0);                       -- sr1/mmr1, address of the current instruction
      sr2 : out std_logic_vector(15 downto 0);                       -- sr2, register autoincrement/autodecrement information for instruction restart
      dstfreference : out std_logic;                                 -- if '1', the destination reference is the final reference for this addressing mode
      sr3csmenable : in std_logic;                                   -- if '1', the enable csm instruction flag in sr3/mmr3 is set

      psw_in : in std_logic_vector(15 downto 0);                     -- psw input from the control register address @ 177776
      psw_in_we_even : in std_logic;                                 -- psw input from the control register address @ 177776, write enable for the even address part
      psw_in_we_odd : in std_logic;                                  -- psw input from the control register address @ 177776, write enable for the odd address part
      psw_out : out std_logic_vector(15 downto 0);                   -- psw output, current psw that the cpu uses

      pir_in : in std_logic_vector(15 downto 0);                     -- pirq value input from the control register

      modelcode : in integer range 0 to 255;                         -- cpu model code
      have_fp : in integer range 0 to 2 := 2;                        -- floating point; 0=force disable; 1=force enable; 2=follow default for cpu model
      have_fpa : in integer range 0 to 1 := 0;                       -- floating point accelerator present with J11 cpu
      have_eis : in integer range 0 to 2 := 2;                       -- eis instructions; 0=force disable; 1=force enable; 2=follow default for cpu model
      have_fis : in integer range 0 to 2 := 2;                       -- fis instructions; 0=force disable; 1=force enable; 2=follow default for cpu model
      have_sillies : in integer range 0 to 1 := 0;                   -- whether to include core that is only there to pass maindec tests
      init_r7 : in std_logic_vector(15 downto 0) := x"f600";         -- start address after reset = o'173000' = m9312 hi rom
      init_psw : in std_logic_vector(15 downto 0) := x"00e0";        -- initial psw for kernel mode, primary register set, priority 7

      cons_load : in std_logic := '0';                               -- load, pulse '1'
      cons_exa : in std_logic := '0';                                -- examine, pulse '1'
      cons_dep : in std_logic := '0';                                -- deposit, pulse '1'
      cons_cont : in std_logic := '0';                               -- continue, pulse '1'
      cons_ena : in std_logic := '1';                                -- ena/halt, '1' is enable, '0' is halt
      cons_start : in std_logic := '0';                              -- start, pulse '1'
      cons_sw : in std_logic_vector(21 downto 0) := (others => '0'); -- front panel switches
      cons_consphy : out std_logic_vector(21 downto 0);              -- console address
      cons_exadep : out std_logic;                                   -- '1' when running an examine or deposit memory cycle from the console
      cons_adrserr : out std_logic;                                  -- '1' when last access from console caused an nxmabort
      cons_br : out std_logic_vector(15 downto 0);                   -- bus register for the console displays
      cons_shfr : out std_logic_vector(15 downto 0);                 -- shfr register for the console displays
      cons_maddr : out std_logic_vector(15 downto 0);                -- microcode address fpu/cpu

      cons_run : out std_logic;                                      -- '1' if executing instructions (incl wait)
      cons_pause : out std_logic;                                    -- '1' if bus has been relinquished to npr
      cons_master : out std_logic;                                   -- '1' if cpu is bus master and not running
      cons_kernel : out std_logic;                                   -- '1' if kernel mode
      cons_super : out std_logic;                                    -- '1' if super mode
      cons_user : out std_logic;                                     -- '1' if user mode

      clk : in std_logic;                                            -- input clock
      reset : in std_logic                                           -- reset cpu, also causes init signal to devices on the bus to be asserted
   );
end component;


component mmu is
   port(
      cpu_addr_v : in std_logic_vector(15 downto 0);
      cpu_datain : out std_logic_vector(15 downto 0);
      cpu_dataout : in std_logic_vector(15 downto 0);
      cpu_rd : in std_logic;
      cpu_wr : in std_logic;
      cpu_dw8 : in std_logic;
      cpu_cp : in std_logic;

      mmutrap : out std_logic;
      ack_mmutrap : in std_logic;
      mmuabort : out std_logic;
      ack_mmuabort : in std_logic;

      mmuoddabort : out std_logic;

      sr0_ic : in std_logic;
      sr1_in : in std_logic_vector(15 downto 0);
      sr2_in : in std_logic_vector(15 downto 0);
      dstfreference : in std_logic;
      sr3csmenable : out std_logic;
      ifetch : in std_logic;

      -- lma (f11)
      mmu_lma_c1 : out std_logic;
      mmu_lma_c0 : out std_logic;
      mmu_lma_eub : out std_logic_vector(21 downto 0);

      bus_unibus_mapped : out std_logic;

      bus_addr : out std_logic_vector(21 downto 0);
      bus_dati : in std_logic_vector(15 downto 0);
      bus_dato : out std_logic_vector(15 downto 0);
      bus_control_dati : out std_logic;
      bus_control_dato : out std_logic;
      bus_control_datob : out std_logic;

      unibus_addr : out std_logic_vector(17 downto 0);
      unibus_dati : in std_logic_vector(15 downto 0);
      unibus_dato : out std_logic_vector(15 downto 0);
      unibus_control_dati : out std_logic;
      unibus_control_dato : out std_logic;
      unibus_control_datob : out std_logic;

      unibus_busmaster_addr : in std_logic_vector(17 downto 0);
      unibus_busmaster_dati : out std_logic_vector(15 downto 0);
      unibus_busmaster_dato : in std_logic_vector(15 downto 0);
      unibus_busmaster_control_dati : in std_logic;
      unibus_busmaster_control_dato : in std_logic;
      unibus_busmaster_control_datob : in std_logic;
      unibus_busmaster_control_npg : in std_logic;

      cons_exadep : in std_logic := '0';
      cons_consphy : in std_logic_vector(21 downto 0) := (others => '0');
      cons_adss_mode : in std_logic_vector(1 downto 0) := (others => '0');
      cons_adss_id : in std_logic := '0';
      cons_adss_cons : in std_logic := '0';
      cons_map16 : out std_logic;
      cons_map18 : out std_logic;
      cons_map22 : out std_logic;
      cons_id : out std_logic;

      modelcode : in integer range 0 to 255;
      sr0out_debug : out std_logic_vector(15 downto 0);
      have_odd_abort : out integer range 0 to 255;

      psw : in std_logic_vector(15 downto 0);
      id : in std_logic;
      reset : in std_logic;
      clk : in std_logic
   );
end component;


component cr11 is
   port(
      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

-- psw
      psw_in : out std_logic_vector(15 downto 0);
      psw_in_we_even : out std_logic;
      psw_in_we_odd : out std_logic;
      psw_out : in std_logic_vector(15 downto 0);

-- stack limit
      cpu_stack_limit : out std_logic_vector(15 downto 0);

-- pirq
      pir_in : out std_logic_vector(15 downto 0);

-- cer
      cpu_illegal_halt : in std_logic;
      cpu_address_error : in std_logic;
      cpu_nxm : in std_logic;
      cpu_iobus_timeout : in std_logic;
      cpu_ysv : in std_logic;
      cpu_rsv : in std_logic;

-- lma (f11)
      mmu_lma_c1 : in std_logic := '0';
      mmu_lma_c0 : in std_logic := '0';
      mmu_lma_eub : in std_logic_vector(21 downto 0) := (others => '0');

-- maintenance register (j11)
      cpu_kmillhalt : out std_logic;

-- model code

      modelcode : in integer range 0 to 255;
      have_fpa : in integer range 0 to 1 := 0;                       -- floating point accelerator present with J11 cpu

--
      reset : in std_logic;
      clk : in std_logic
   );
end component;


component m9312h_minc is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312h_minc : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component m9312l_minc is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312l_minc : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component m9312h_pdp2011 is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312h_pdp2011 : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component m9312l_pdp2011 is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312l_pdp2011 : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component m9312h_odt is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312h_odt : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component m9312l_odt is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;

      have_m9312l_odt : in integer range 0 to 1 := 0;

      clk : in std_logic
   );
end component;


component kl11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);
      ovec : in std_logic_vector(8 downto 0);

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

      tx : out std_logic;
      rx : in std_logic;
      rts : out std_logic;
      cts : in std_logic;

      have_kl11 : in integer range 0 to 1;
      have_kl11_force7bit : in integer range 0 to 1;
      have_kl11_rtscts : in integer range 0 to 1;
      have_kl11_bps : in integer range 300 to 230400;

      reset : in std_logic;

      clk50mhz : in std_logic;

      clk : in std_logic
   );
end component;


--
-- drivers for minc peripherals
--


component pmodda2 is
   port(
      da_daca : in std_logic_vector(11 downto 0);
      da_dacb : in std_logic_vector(11 downto 0);

      da_sync : out std_logic;
      da_dina : out std_logic;
      da_dinb : out std_logic;
      da_sclk : out std_logic;

      reset : in std_logic;
      clk : in std_logic
    );
end component;


component pmodda4 is
   port(
      da_daca : in std_logic_vector(11 downto 0) := "000000000000";
      da_dacb : in std_logic_vector(11 downto 0) := "000000000000";
      da_dacc : in std_logic_vector(11 downto 0) := "000000000000";
      da_dacd : in std_logic_vector(11 downto 0) := "000000000000";
      da_dace : in std_logic_vector(11 downto 0) := "000000000000";
      da_dacf : in std_logic_vector(11 downto 0) := "000000000000";
      da_dacg : in std_logic_vector(11 downto 0) := "000000000000";
      da_dach : in std_logic_vector(11 downto 0) := "000000000000";

      da_cs : out std_logic;
      da_mosi : out std_logic;
      da_sclk : out std_logic;

      reset : in std_logic;
      clk : in std_logic
   );
end component;


component pmodhygro is
   port(
      -- pmodhygro
      hg_scl : inout std_logic;
      hg_sda : inout std_logic;

      hg_rh : out std_logic_vector(13 downto 0);
      hg_temp : out std_logic_vector(13 downto 0);

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end component;


component pmodcolor is
   port(
      -- pmodcolor
      co_scl : inout std_logic;
      co_sda : inout std_logic;

      co_clear : out std_logic_vector(15 downto 0);
      co_red : out std_logic_vector(15 downto 0);
      co_green : out std_logic_vector(15 downto 0);
      co_blue : out std_logic_vector(15 downto 0);

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end component;


component pmodnav is
   port(
      nv_csag : out std_logic;                   -- cs acc/gyro
      nv_mosi : out std_logic;
      nv_miso : in std_logic;
      nv_sclk : out std_logic;
      nv_csm : out std_logic;                    -- cs magnetometer
      nv_csa : out std_logic;                    -- cs altimeter

      nv_temp : out std_logic_vector(11 downto 0);         -- divide by 30, add to 42.5 (signed arithmetic!) to get temp
      nv_pressure : out std_logic_vector(11 downto 0);     -- pressure in mbar/hPa
      nv_pressure_f : out std_logic_vector(11 downto 0);   -- pressure fraction

      nv_xlt : out std_logic_vector(11 downto 0);
      nv_xlx : out std_logic_vector(11 downto 0);
      nv_xly : out std_logic_vector(11 downto 0);
      nv_xlz : out std_logic_vector(11 downto 0);
      nv_gx : out std_logic_vector(11 downto 0);
      nv_gy : out std_logic_vector(11 downto 0);
      nv_gz : out std_logic_vector(11 downto 0);
      nv_mx : out std_logic_vector(11 downto 0);
      nv_my : out std_logic_vector(11 downto 0);
      nv_mz : out std_logic_vector(11 downto 0);

      reset : in std_logic;
      clk : in std_logic
   );
end component;


component miodi is
   port(
      mi_scl : inout std_logic;                                      -- scl - clock line to the i2c target
      mi_sda : inout std_logic;                                      -- sda - data line to the i2c target

      mi_data : out std_logic_vector(15 downto 0);                   -- the input data
      mi_event : in std_logic;                                       -- the event output on the module front panel
      mi_reply : in std_logic;                                       -- the reply output

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end component;


component miodo is
   port(
      mo_scl : inout std_logic;                                      -- scl - clock line to the i2c target
      mo_sda : inout std_logic;                                      -- sda - data line to the i2c target

      mo_data : in std_logic_vector(15 downto 0);                    -- the data to be output
      mo_hb : in std_logic;                                          -- high byte strobe
      mo_lb : in std_logic;                                          -- low byte strobe
      mo_ie : in std_logic;                                          -- '1' when the module is interrupt enabled and waiting for a reply
      mo_reply : out std_logic := '0';                               -- reply towards the module

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end component;


component mncadagg is
   port(
      ad_channel : in std_logic_vector(5 downto 0);                  -- the current channel on the ad mux
      ad_basechannel : in integer range 0 to 63;                     -- the channel that this mncadtpg instance is for
      ad_type : out std_logic_vector(3 downto 0);                    -- gain bits and/or channel type code for the current channel
      ad_chgbits : in std_logic_vector(3 downto 0);                  -- new gain bits for the current channel
      ad_wcgbits : in std_logic;                                     -- when '1' program the chgbits into the current channel

      ag_type0 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type1 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type2 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type3 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type4 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type5 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type6 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default
      ag_type7 : in std_logic_vector(1 downto 0) := "11";            -- "01" for A channel; "10" for R channel; "11" for V channel. V is default

      ag_gain0 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain1 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain2 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain3 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain4 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain5 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain6 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component
      ag_gain7 : out std_logic_vector(1 downto 0);                   -- output gain bits for programmable gain component

      reset : in std_logic;
      clk : in std_logic
   );
end component;


component mncadtpg is
   port(
      ad_channel : in std_logic_vector(5 downto 0);                  -- the current channel on the ad mux
      ad_basechannel : in integer range 0 to 63;                     -- the channel that this mncadtpg instance is for
      ad_type : out std_logic_vector(3 downto 0);                    -- gain bits and/or channel type code for the current channel
      ad_chgbits : in std_logic_vector(3 downto 0);                  -- new gain bits for the current channel
      ad_wcgbits : in std_logic;                                     -- when '1' program the chgbits into the current channel

      tp_gain0 : out std_logic_vector(3 downto 0);                   -- channel 0 output gain bits for programmable gain component
      tp_gain1 : out std_logic_vector(3 downto 0);                   -- channel 1 output gain bits for programmable gain component
      tp_gain2 : out std_logic_vector(3 downto 0);                   -- channel 2 output gain bits for programmable gain component
      tp_gain3 : out std_logic_vector(3 downto 0);                   -- channel 3 output gain bits for programmable gain component
      tp_gain4 : out std_logic_vector(3 downto 0);                   -- channel 4 output gain bits for programmable gain component
      tp_gain5 : out std_logic_vector(3 downto 0);                   -- channel 5 output gain bits for programmable gain component
      tp_gain6 : out std_logic_vector(3 downto 0);                   -- channel 6 output gain bits for programmable gain component
      tp_gain7 : out std_logic_vector(3 downto 0);                   -- channel 7 output gain bits for programmable gain component

      reset : in std_logic;
      clk : in std_logic
   );
end component;


component adc is
   port(
      ad_start : in std_logic;
      ad_done : out std_logic := '0';
      ad_channel : in std_logic_vector(5 downto 0);
      ad_nxc : out std_logic := '0';
      ad_sample : out std_logic_vector(11 downto 0) := "000000000000";
      ad_type : out std_logic_vector(3 downto 0);

      ad_ch0 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch1 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch2 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch3 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch4 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch5 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch6 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch7 : in std_logic_vector(11 downto 0) := "000000000000";
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

      reset : in std_logic;
      clk : in std_logic
   );
end component;


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


component de10ladc is
   port(
      ad_start : in std_logic;
      ad_done : out std_logic := '0';
      ad_channel : in std_logic_vector(5 downto 0);
      ad_nxc : out std_logic := '0';
      ad_sample : out std_logic_vector(11 downto 0) := "000000000000";
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

      clk : in std_logic;
      clk50mhz : in std_logic;
      reset : in std_logic
   );
end component;

end package;

