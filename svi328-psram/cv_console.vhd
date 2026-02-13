-------------------------------------------------------------------------------
--
-- FPGA SVI-328 based on Colecovision
--
-- $Id: cv_console.vhd,v 1.13 2006/02/28 22:29:55 arnim Exp $
--
-- Toplevel of the Colecovision console
--
-- References:
--
--   * Dan Boris' schematics of the Colecovision board
--     http://www.atarihq.com/danb/files/colecovision.pdf
--
--   * Schematics of the Colecovision controller, same source
--     http://www.atarihq.com/danb/files/ColecoController.pdf
--
--   * Technical information, same source
--     http://www.atarihq.com/danb/files/CV-Tech.txt
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------


library ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity cv_console is

  generic (
    is_pal_g        : integer := 1;
    compat_rgb_g    : integer := 0
  );
  port (
    -- Global Interface -------------------------------------------------------
    clk_i           : in  std_logic;
    clk_en_10m7_i   : in  std_logic;
	 clk_en_5m3_i   : in  std_logic;
    reset_n_i       : in  std_logic;

    svi_row_o       : out std_logic_vector(3 downto 0);
    svi_col_i       : in  std_logic_vector(7 downto 0);	 

	 svi_tap_i	     : in  std_logic;	 
    motor_o			  : out std_logic;	 
	 
    por_n_o         : out std_logic;
    -- Controller Interface ---------------------------------------------------
    joy0_i          : in  std_logic_vector( 4 downto 0);
    joy1_i          : in  std_logic_vector( 4 downto 0);
    -- CPU RAM Interface ------------------------------------------------------
    cpu_ram_a_o     : out std_logic_vector(15 downto 0);
    cpu_ram_ce_n_o  : out std_logic;
    cpu_ram_rd_n_o  : out std_logic;
    cpu_ram_we_n_o  : out std_logic;
    cpu_ram_d_i     : in  std_logic_vector( 7 downto 0);
    cpu_ram_d_o     : out std_logic_vector( 7 downto 0);
    cpu_rfsh_n_o    : out std_logic;
    -- RAM Mapper Reg ---------------------------------------------------------
	 ay_port_b		  : out std_logic_vector( 7 downto 0);
    -- Video RAM Interface ----------------------------------------------------
    vram_a_o        : out std_logic_vector(13 downto 0);
    vram_we_o       : out std_logic;
    vram_d_o        : out std_logic_vector( 7 downto 0);
    vram_d_i        : in  std_logic_vector( 7 downto 0);
    -- RGB Video Interface ----------------------------------------------------
    border_i        : in  std_logic;
    col_o           : out std_logic_vector( 3 downto 0);
    rgb_r_o         : out std_logic_vector( 7 downto 0);
    rgb_g_o         : out std_logic_vector( 7 downto 0);
    rgb_b_o         : out std_logic_vector( 7 downto 0);
    hsync_n_o       : out std_logic;
    vsync_n_o       : out std_logic;
    blank_n_o       : out std_logic;
    hblank_o        : out std_logic;
    vblank_o        : out std_logic;
    comp_sync_n_o   : out std_logic;
    -- Audio Interface --------------------------------------------------------
    audio_o         : out std_logic_vector(10 downto 0)
  );

end cv_console;


-- pragma translate_off
use std.textio.all;
-- pragma translate_on

architecture struct of cv_console is


  component jt8255
  port (
    rst         : in  std_logic;
    clk         : in  std_logic;

    -- CPU interface

    addr      : in  std_logic_vector(1 downto 0);
    din       : in  std_logic_vector(7 downto 0);
    dout      : out  std_logic_vector(7 downto 0);
    rdn       : in  std_logic;
    wrn       : in  std_logic;
    csn       : in  std_logic;

    -- External pins to peripherals
	 porta_din : in  std_logic_vector(7 downto 0);
    portb_din : in  std_logic_vector(7 downto 0);
	 portc_din : in  std_logic_vector(7 downto 0);

    porta_dout: out  std_logic_vector(7 downto 0);
    portb_dout: out  std_logic_vector(7 downto 0);
    portc_dout: out  std_logic_vector(7 downto 0)

    );
  end component;
  
  component jt49_bus
	 port (
				clk : IN STD_LOGIC;
				clk_en : IN STD_LOGIC;
				rst_n : IN STD_LOGIC;
				bdir : IN STD_LOGIC;
				bc1 : IN STD_LOGIC;
				sel : IN STD_LOGIC;
				din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				sound : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
				A : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				B : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				C : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				sample : OUT STD_LOGIC;
				IOA_In : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				IOA_Out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				IOB_In : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				IOB_Out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	 );
	end component;
  
  component ls74 IS
  port(d,
	  clr,
     pre,
     clk   : IN std_logic;
     q     : OUT std_logic);
  end component;
  
  signal por_n_s          : std_logic;
  signal reset_n_s        : std_logic;

  signal clk_en_3m58_p_s  : std_logic;
  signal clk_en_3m58_n_s  : std_logic;
  signal clk_en_1m79_p_s  : std_logic;
  signal clk_en_1m79_n_s  : std_logic;  

  -- CPU signals
  signal wait_n_s         : std_logic;
  signal nmi_n_s          : std_logic;
  signal int_n_s          : std_logic;
  signal iorq_n_s         : std_logic;
  signal m1_n_s           : std_logic;
  signal m1_wait_q        : std_logic;
  signal rd_n_s,
         wr_n_s           : std_logic;
  signal mreq_n_s         : std_logic;
  signal rfsh_n_s         : std_logic;
  signal a_s              : std_logic_vector(15 downto 0);
  signal d_to_cpu_s,
         d_from_cpu_s     : std_logic_vector( 7 downto 0);

  -- VDP18 signal
  signal d_from_vdp_s     : std_logic_vector( 7 downto 0);
  signal vdp_int_n_s      : std_logic;

  -- SN76489 signal
  signal psg_ready_s      : std_logic;
  signal psg_audio_s      : std_logic_vector( 7 downto 0);

  -- AY-8910 signal
  signal ay_d_s           : std_logic_vector( 7 downto 0);
  signal AySound          : std_logic_vector( 9 downto 0);

  signal audio_mix        : std_logic_vector( 9 downto 0);

  -- Address decoder signals
  signal ram_ce_n_s       : std_logic;
  signal vdp_r_n_s,
         vdp_w_n_s        : std_logic;
  signal psg_we_n_s       : std_logic;
  signal ay_addr_we_n_s   : std_logic;
  signal ay_data_we_n_s   : std_logic;
  signal ay_data_rd_n_s   : std_logic;
  signal u8255_cs_n_s     : std_logic;  
  
-- 8255 data Signal  
  signal d_from_8255      : std_logic_vector( 7 downto 0);
  signal PortC_8255       : std_logic_vector( 7 downto 0);
  
  -- misc signals
  signal vdd_s            : std_logic;

--  -- pragma translate_off
--  file logfile: text is out "access.txt";
--  -- pragma translate_on

  signal keyBeep : std_logic;
  signal motor : std_logic;
  
begin

  cpu_rfsh_n_o <= rfsh_n_s;
  vdd_s <= '1';
  audio_o <=  (keyBeep & ((PortC_8255(6) and svi_tap_i) or PortC_8255(5)) & "000000000") or AySound & "0";
  motor_o <= motor;


  -----------------------------------------------------------------------------
  -- CPU INT/NMI
  -----------------------------------------------------------------------------

  int_n_s <= vdp_int_n_s;
  nmi_n_s <= '1';

  
  
  -----------------------------------------------------------------------------
  -- Reset generation
  -----------------------------------------------------------------------------
  por_b : work.cv_por
    port map (
      clk_i   => clk_i,
      por_n_o => por_n_s
    );
  por_n_o   <= por_n_s;
  reset_n_s <= por_n_s and reset_n_i;

  -----------------------------------------------------------------------------
  -- Clock generation
  -----------------------------------------------------------------------------
  clock_b : work.cv_clock
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_10m7_i,
      reset_n_i     => reset_n_s,
      clk_en_3m58_p_o => clk_en_3m58_p_s,
      clk_en_3m58_n_o => clk_en_3m58_n_s
    );

  clock_b2 : work.cv_clock
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_5m3_i,
      reset_n_i     => reset_n_s,
      clk_en_3m58_p_o => clk_en_1m79_p_s,
      clk_en_3m58_n_o => clk_en_1m79_n_s
    );

  -----------------------------------------------------------------------------
  -- T80 CPU
  -----------------------------------------------------------------------------
  t80a_b : work.T80pa
    generic map (
      Mode       => 0
    )
    port map(
      RESET_n    => reset_n_s,
      CLK        => clk_i,
      CEN_p      => clk_en_3m58_p_s,
      CEN_n      => clk_en_3m58_n_s,
      WAIT_n     => wait_n_s,
      INT_n      => int_n_s,
      NMI_n      => nmi_n_s,
      BUSRQ_n    => vdd_s,
      M1_n       => m1_n_s,
      MREQ_n     => mreq_n_s,
      IORQ_n     => iorq_n_s,
      RD_n       => rd_n_s,
      WR_n       => wr_n_s,
      RFSH_n     => rfsh_n_s,
      HALT_n     => open,
      BUSAK_n    => open,
      A          => a_s,
      DI         => d_to_cpu_s,
      DO         => d_from_cpu_s
    );

	 
inst_psg : jt49_bus
  PORT MAP(
		 clk => clk_i,
		 clk_en => clk_en_1m79_p_s,
		 sel => '0',
		 rst_n => reset_n_s,
		 bc1 => not ay_addr_we_n_s or not ay_data_rd_n_s,
		 bdir => not ay_addr_we_n_s or not ay_data_we_n_s,
		 din => d_from_cpu_s,
		 dout => ay_d_s,
		 sample => open,
		 sound => AySound,
		 A => open,
		 B => open,
		 C => open,
		 IOA_In => joy1_i(3 downto 0) & joy0_i(3 downto 0), 
		 IOA_out     => open,
		 IOB_Out => ay_port_b,
		 IOB_In => (others => '0')
 );



	 
	 -- SVI 8255
	 
--Port A (Port address: 98H) (I/O Status: Input) (Operating mode: 0)
--Bit 7: Cassette: Read data
--Bit 6: Cassette: Ready (0=on/ready, 1=off/not ready)
--Bit 5: Joystick 2: Trigger (0=Pressed 1=NoPressed)
--Bit 4: Joystick 1: Trigger (0=Pressed 1=NoPressed)
--Bit 3: Joystick 2: EOC
--Bit 2: Joystick 2: /SENSE
--Bit 1: Joystick 1: EOC
--Bit 0: Joystick 1: /SENSE
--Port B (Port address: 99H) (I/O Status: Input) (Operating mode: 0)
--Bit 7: Keyboard: Column status of selected line
--Bit 6: Keyboard: Column status of selected line
--Bit 5: Keyboard: Column status of selected line
--Bit 4: Keyboard: Column status of selected line
--Bit 3: Keyboard: Column status of selected line
--Bit 2: Keyboard: Column status of selected line
--Bit 1: Keyboard: Column status of selected line
--Bit 0: Keyboard: Column status of selected line
--Port C (Port address: 97H) (I/O Status: Output) (Operating mode: 0)
--Bit 7: Keyboard: Click sound bit (pulse)
--Bit 6: Cassette: Audio out (pulse) (0=Disable mix audioin, 1=enable mix audio in)
--Bit 5: Cassette: Write data
--Bit 4: Cassette: Motor relay control (0=on, 1=off)
--Bit 3: Keyboard: Line select 3
--Bit 2: Keyboard: Line select 2
--Bit 1: Keyboard: Line select 1
--Bit 0: Keyboard: Line select 0	 
	 
  U8255_inst: jt8255
  port map(
    rst         => not reset_n_s,
    clk         => clk_i,

    -- CPU interface

    addr      => a_s (1 downto 0),
    din       => d_from_cpu_s,
    dout      => d_from_8255,
    rdn       => rd_n_s,
    wrn       => wr_n_s,
    csn       => u8255_cs_n_s,

    -- External pins to peripherals
	 porta_din => svi_tap_i & '0' & joy1_i(4) & joy0_i(4) &"1111",
    portb_din => svi_col_i,
	 portc_din => (others => '0'),

    porta_dout=> open,
    portb_dout=> open,
    portc_dout=> PortC_8255

    );


	 
  -----------------------------------------------------------------------------
  -- Z80 Wait Signal
  ls74_inst : ls74
  port map 
  (	d   => m1_n_s,
	   clr => '1',
      pre => m1_wait_q,
      clk => clk_en_3m58_p_s,
      q   => wait_n_s
  );

  ls74_inst2 : ls74
  port map 
  (	d   => wait_n_s,
	   clr => '1',
      pre => '1',
      clk => clk_en_3m58_p_s,
      q   => m1_wait_q
  );


  
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- TMS9928A Video Display Processor
  -----------------------------------------------------------------------------
  vdp18_b : work.vdp18_core
    generic map (
      is_pal_g      => is_pal_g,
      compat_rgb_g  => compat_rgb_g
    )
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_10m7_i,
      reset_n_i     => reset_n_s,
      csr_n_i       => vdp_r_n_s,
      csw_n_i       => vdp_w_n_s,
      mode_i        => a_s(0),
      int_n_o       => vdp_int_n_s,
      cd_i          => d_from_cpu_s,
      cd_o          => d_from_vdp_s,
      vram_we_o     => vram_we_o,
      vram_a_o      => vram_a_o,
      vram_d_o      => vram_d_o,
      vram_d_i      => vram_d_i,
      col_o         => col_o,
      rgb_r_o       => rgb_r_o,
      rgb_g_o       => rgb_g_o,
      rgb_b_o       => rgb_b_o,
      hsync_n_o     => hsync_n_o,
      vsync_n_o     => vsync_n_o,
      blank_n_o     => blank_n_o,
      border_i      => border_i,
      hblank_o      => hblank_o,
      vblank_o      => vblank_o,
      comp_sync_n_o => comp_sync_n_o
    );




  -----------------------------------------------------------------------------
  -- Address decoder
  -----------------------------------------------------------------------------
  addr_dec_b : work.cv_addr_dec
    port map (
      clk_i           => clk_i,
      reset_n_i       => reset_n_i,
      a_i             => a_s,
      d_i             => d_from_cpu_s,
      iorq_n_i        => iorq_n_s,
      rd_n_i          => rd_n_s,
      wr_n_i          => wr_n_s,
      mreq_n_i        => mreq_n_s,
      rfsh_n_i        => rfsh_n_s,
		m1_n_i			 => m1_n_s,
      ram_ce_n_o      => ram_ce_n_s,
      vdp_r_n_o       => vdp_r_n_s,
      vdp_w_n_o       => vdp_w_n_s,
      ay_addr_we_n_o  => ay_addr_we_n_s,
      ay_data_we_n_o  => ay_data_we_n_s,
      ay_data_rd_n_o  => ay_data_rd_n_s,
		u8255_cs_n_o	 => u8255_cs_n_s
    );

  cpu_ram_ce_n_o  <= ram_ce_n_s;
  cpu_ram_we_n_o  <= wr_n_s;
  cpu_ram_rd_n_o  <= rd_n_s;

  -----------------------------------------------------------------------------
  -- Bus multiplexer
  -----------------------------------------------------------------------------

  bus_mux_b : work.cv_bus_mux
    port map (
      ram_ce_n_i      => ram_ce_n_s,
      vdp_r_n_i       => vdp_r_n_s,
      ay_data_rd_n_i  => ay_data_rd_n_s,
		u8255_cs_n_i    => u8255_cs_n_s,
      cpu_ram_d_i     => cpu_ram_d_i,
      vdp_d_i         => d_from_vdp_s,
      ay_d_i          => ay_d_s,
		joyfire         => joy1_i(4) & joy0_i(4),		
		d_from_8255 	 => d_from_8255,
      d_o             => d_to_cpu_s
    );



  svi_row : process (clk_i, reset_n_s, m1_n_s)
  begin
    if reset_n_s = '0' then
		svi_row_o <= (others => '0');
		keyBeep   <= '0';
		motor     <= '1';
    elsif clk_i'event and clk_i = '1' then 
		svi_row_o <= PortC_8255(3 downto 0);
		keyBeep   <= PortC_8255(7);
		motor     <= PortC_8255(4);
    end if;
  end process svi_row;


  -----------------------------------------------------------------------------
  -- Misc outputs
  -----------------------------------------------------------------------------
  cpu_ram_a_o  <= a_s(15 downto 0);
  cpu_ram_d_o  <= d_from_cpu_s;

end struct;
