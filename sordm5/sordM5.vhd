--//============================================================================
--//  Sord M5
--//
--//  Port to MiSTer
--//  Copyright (C) 2021 molekula
--//
--//  This program is free software; you can redistribute it and/or modify it
--//  under the terms of the GNU General Public License as published by the Free
--//  Software Foundation; either version 2 of the License, or (at your option)
--//  any later version.
--//
--//  This program is distributed in the hope that it will be useful, but WITHOUT
--//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
--//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
--//  more details.
--//
--//  You should have received a copy of the GNU General Public License along
--//  with this program; if not, write to the Free Software Foundation, Inc.,
--//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--//
--//============================================================================

library ieee;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity sordM5 is

  generic (
    is_pal_g        : integer := 1;
    compat_rgb_g    : integer := 1
  );
  port (
    -- Global Interface -------------------------------------------------------
    clk_i           : in  std_logic;
    clk_en_10m7_i   : in  std_logic;
    reset_n_i       : in  std_logic;
    por_n_o         : out std_logic;
    -- Interface
    ps2_key_i       : in  std_logic_vector(10 downto 0);
    ramMode_i       : in  std_logic_vector(8 downto 0);
    tape_sound_i    : in  std_logic;
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
    audio_o         : out std_logic_vector(10 downto 0);
    -- hps_io --------------------------------------------------------
    ioctl_addr      : in std_logic_vector( 24 downto 0);
    ioctl_dout      : in std_logic_vector( 7 downto 0);
    ioctl_index     : in std_logic_vector( 7 downto 0);
    ioctl_wr        : in std_logic;
    ioctl_download  : in std_logic;
    casSpeed        : in std_logic;
    -- DDRAM --------------------------------------------------------
    -- DDRAM_CLK       : out std_logic;
    -- DDRAM_BUSY      : in std_logic;
    -- DDRAM_BURSTCNT  : out std_logic_vector( 7 downto 0);
    -- DDRAM_ADDR      : out std_logic_vector( 28 downto 0);
    -- DDRAM_DOUT      : in std_logic_vector( 63 downto 0);
    -- DDRAM_DOUT_READY :in std_logic;
    -- DDRAM_RD        : out std_logic;
    -- DDRAM_DIN       : out std_logic_vector( 63 downto 0);
    -- DDRAM_BE        : out std_logic_vector( 7 downto 0);
    -- DDRAM_WE        : out std_logic

    AUDIO_INPUT : in std_logic;

    --SRAM
    SRAM_A			:	 OUT STD_LOGIC_VECTOR(20 DOWNTO 0);
    SRAM_Q			:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    SRAM_WE			:	 OUT STD_LOGIC

  );

end sordM5;


architecture struct of sordM5 is


  signal por_n_s          : std_logic;
  signal reset_n_s        : std_logic;

  signal clk_en_3m58_p_s  : std_logic;
  signal clk_en_3m58_n_s  : std_logic;

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
  signal RETI_n_s         : std_logic;

  -- VDP18 signal
  signal d_from_vdp_s     : std_logic_vector( 7 downto 0);
  signal vdp_int_n_s      : std_logic;

  -- SN76489 signal
  signal psg_ready_s      : std_logic;
  signal psg_audio_s      : std_logic_vector( 7 downto 0);

  signal audio_mix        : std_logic_vector( 9 downto 0);
  
  -- Keyboard decoder
  signal kb_do_s          : std_logic_vector( 7 downto 0);
  signal kb_rst_s         : std_logic;
  signal kb_ce_n_s        : std_logic;
  
  -- Cassete interface
  signal cas_ce_n_s       : std_logic;
  signal casOut_s         : std_logic;
  signal casOn_s          : std_logic;
  
  -- CTC interface
  signal d_from_ctc_s     : std_logic_vector(7 downto 0);
  signal int_ctc_s        : std_logic_vector(3 downto 0);
  signal int_ctc_ack_s    : std_logic_vector(3 downto 0);
  
  -- Address decoder signals
  signal vdp_r_n_s		    : std_logic;
  signal vdp_w_n_s        : std_logic;
  signal psg_we_n_s       : std_logic;
  signal ctc_ce_n_s       : std_logic;
  signal ctrl_r_n_s       : std_logic;
  signal int_vect_ce_n_s  : std_logic;
  
  -- misc signals
  signal vdd_s            : std_logic;


  -- vram 
  signal vram_a_s         : std_logic_vector(13 downto 0);
  signal vram_we_s        : std_logic;
  signal vram_do_s        : std_logic_vector( 7 downto 0);
  signal vram_di_s        : std_logic_vector( 7 downto 0);
  
  -- ram/rom
  signal ram_d_s         : std_logic_vector( 7 downto 0);
  
  -- ddram buffer
  signal buff_mem_addr    : std_logic_vector(27 downto 0);
  signal buff_mem_dout    : std_logic_vector(7 downto 0);
  signal buff_mem_din     : std_logic_vector(7 downto 0);
  signal buff_mem_wr      : std_logic;
  signal buff_mem_rd      : std_logic;
  signal buff_mem_ready   : std_logic;
  
  -- component ddram is
  --   port (
  --     DDRAM_CLK       : in  std_logic;
  --     DDRAM_BUSY      : in  std_logic;
  --     DDRAM_BURSTCNT  : out std_logic_vector( 7 downto 0);
  --     DDRAM_ADDR      : out std_logic_vector( 28 downto 0);
  --     DDRAM_DOUT      : in  std_logic_vector( 63 downto 0);
  --     DDRAM_DOUT_READY :in  std_logic;
  --     DDRAM_RD        : out std_logic;
  --     DDRAM_DIN       : out std_logic_vector( 63 downto 0);
  --     DDRAM_BE        : out std_logic_vector( 7 downto 0);
  --     DDRAM_WE        : out std_logic;
  --     addr            : in  std_logic_vector( 27 downto 0);
  --     dout            : out std_logic_vector( 7 downto 0);
  --     din             : in  std_logic_vector( 7 downto 0);
  --     we              : in  std_logic; 
  --     rd              : in  std_logic; 
  --     ready           : out std_logic;  
  --     reset           : in  std_logic
  --   );
  -- end component ddram;  

begin

  vdd_s <= '1';
  audio_o <= (casOut_s&psg_audio_s&"00") when tape_sound_i = '0' else ('0'&psg_audio_s&"00");
  nmi_n_s <= '1'; 

  -----------------------------------------------------------------------------
  -- Reset generation
  -----------------------------------------------------------------------------
  por : work.cv_por
    port map (
      clk_i   => clk_i,
      por_n_o => por_n_s
    );
  por_n_o   <= por_n_s;
  reset_n_s <= por_n_s and reset_n_i;

  -----------------------------------------------------------------------------
  -- Clock generation
  -----------------------------------------------------------------------------
  clock : work.cv_clock
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_10m7_i,
      reset_n_i     => reset_n_s,
      clk_en_3m58_p_o => clk_en_3m58_p_s,
      clk_en_3m58_n_o => clk_en_3m58_n_s
    );
    
  -----------------------------------------------------------------------------
  -- T80 CPU
  -----------------------------------------------------------------------------
  t80a : work.T80pa
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


  -----------------------------------------------------------------------------
  -- Process m1_wait
  --
  -- Purpose:
  --   Implements flip-flop U8A which asserts a wait states controlled by M1.
  --
  m1_wait: process (clk_i, reset_n_s, m1_n_s)
  begin
    if reset_n_s = '0' or m1_n_s = '1' then
      m1_wait_q   <= '0';
    elsif clk_i'event and clk_i = '1' then
      if clk_en_3m58_p_s = '1' then
        m1_wait_q <= not m1_wait_q;
      end if;
    end if;
  end process m1_wait;

  wait_n_s  <= (psg_ready_s and not m1_wait_q);

  -----------------------------------------------------------------------------
  -- TMS9928A Video Display Processor
  -----------------------------------------------------------------------------
  vdp18 : work.vdp18_core
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
      vram_we_o     => vram_we_s,
      vram_a_o      => vram_a_s,
      vram_d_o      => vram_do_s,
      vram_d_i      => vram_di_s,
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
  -- SN76489 Programmable Sound Generator
  -----------------------------------------------------------------------------
  psg : work.sn76489_top
    generic map (
      clock_div_16_g => 1
    )
    port map (
      clock_i    => clk_i,
      clock_en_i => clk_en_3m58_p_s,
      res_n_i    => reset_n_s,
      ce_n_i     => psg_we_n_s,
      we_n_i     => psg_we_n_s,
      ready_o    => psg_ready_s,
      d_i        => d_from_cpu_s,
      aout_o     => psg_audio_s
    );
  
  -----------------------------------------------------------------------------
  -- Keyboard decoder
  -----------------------------------------------------------------------------
  keyboard : work.keyboard
    port map (
      reset_n_i    => reset_n_s,
      clk_i        => clk_i,
      ps2_code_i   => ps2_key_i,
      kb_addr_i	   => a_s(2 downto 0),
      kb_data_o	   => kb_do_s,
      kb_rst_o     => kb_rst_s
    );
   
  -----------------------------------------------------------------------------
  -- Address decoder
  -----------------------------------------------------------------------------
  addr_dec : work.addr_dec
    port map (
      clk_i           => clk_i,
      reset_n_i       => reset_n_i,
      a_i             => a_s,
      d_i             => d_from_cpu_s,
      iorq_n_i        => iorq_n_s,
      rd_n_i          => rd_n_s,
      wr_n_i          => wr_n_s,
      m1_n_i          => m1_n_s,
      vdp_r_n_o       => vdp_r_n_s,
      vdp_w_n_o       => vdp_w_n_s,
      psg_we_n_o      => psg_we_n_s,
      kb_ce_n_o       => kb_ce_n_s,
      cas_ce_n_o      => cas_ce_n_s, 
      ctc_ce_n_o      => ctc_ce_n_s,
      int_vect_ce_n_o => int_vect_ce_n_s,
      casOn_o         => casOn_s 
    );

  -----------------------------------------------------------------------------
  -- Bus multiplexer
  -----------------------------------------------------------------------------

  bus_mux : work.bus_mux
    port map (
      mreq_n_i        => mreq_n_s,
      rfsh_n_i        => rfsh_n_s,
      vdp_r_n_i       => vdp_r_n_s,
      vdp_d_i         => d_from_vdp_s,
      d_o             => d_to_cpu_s, 
      kb_d_i          => kb_do_s,
      kb_rst_i        => kb_rst_s,
      kb_ce_n_i       => kb_ce_n_s,
      cas_ce_n_i      => cas_ce_n_s,
      ctc_ce_n_i      => ctc_ce_n_s,
      ctc_d_i         => d_from_ctc_s,
      int_vect_ce_n_i => int_vect_ce_n_s,
--      casOut_i        => casOut_s,
	  casOut_i			=> AUDIO_INPUT,
      rd_n_i          => rd_n_s,
      ram_d_i         => ram_d_s 
    );
	 
  -----------------------------------------------------------------------------
  -- Memory 
  -----------------------------------------------------------------------------
	 
  vram : work.spram
    generic map (
      addr_width => 14,
		mem_name => "VRAM"
    )
    port map (
		clock => clk_i,
		address => vram_a_s,
		wren => vram_we_s,
		data => vram_do_s,
		q => vram_di_s
	 );
	 
   sordM5_ram : work.sordM5_rams
    port map (
      clk_i          => clk_i,
      reset_n_i      => reset_n_i,
      a_i            => a_s,
      d_i            => d_from_cpu_s,
      d_o            => ram_d_s,
      iorq_n_i       => iorq_n_s,
      m1_n_i         => m1_n_s,
      rd_n_i         => rd_n_s,
      wr_n_i         => wr_n_s,
      mreq_n_i       => mreq_n_s,
      rfsh_n_i       => rfsh_n_s,
      ramMode_i      => ramMode_i,
      ioctl_addr     => ioctl_addr,
      ioctl_dout     => ioctl_dout,
      ioctl_index    => ioctl_index,
      ioctl_wr       => ioctl_wr,
      ioctl_download => ioctl_download,

      SRAM_A		=> SRAM_A,
      SRAM_Q		=> SRAM_Q,
      SRAM_WE		=> SRAM_WE

	 );

 -----------------------------------------------------------------------------
 -- Interupt CTC
 -----------------------------------------------------------------------------
   
  ctc : work.ctc 
    port map (
      clk       => clk_i,
      res_n     => reset_n_i,
      en        => ctc_ce_n_s,        
      dIn       => d_from_cpu_s,
      dOut      => d_from_ctc_s,        
      dInCpu    => d_to_cpu_s,      
		cs        => a_s(1 downto 0),
      m1_n      => m1_n_s,
      iorq_n    => iorq_n_s,
      rd_n      => rd_n_s,
      int_n     => int_n_s,
      clk_trg   => (vdp_int_n_s & "000"),
      clk_sys_i => clk_en_3m58_p_s
    );
 
 -----------------------------------------------------------------------------
 -- CAS player
 -----------------------------------------------------------------------------
 
  -- tape : work.casPlayer
  --   port map (
  --   clk_i            => clk_i,
  --   reset_n          => reset_n_i,
  --   ioctl_addr_i     => ioctl_addr,
  --   ioctl_dout_i     => ioctl_dout,
  --   ioctl_index_i    => ioctl_index,
  --   ioctl_wr_i       => ioctl_wr,
  --   ioctl_download_i => ioctl_download,
  --   casOut_o         => casOut_s,
  --   mem_addr_o       => buff_mem_addr,
  --   mem_dout_i       => buff_mem_dout,
  --   mem_din_o        => buff_mem_din,
  --   mem_wr_o         => buff_mem_wr,
  --   mem_rd_o         => buff_mem_rd,
  --   mem_ready_i      => buff_mem_ready,
  --   casOn_i          => casOn_s,
  --   casSpeed_i       => casSpeed
  --   );
    
-----------------------------------------------------------------------------
-- BUFFER DDRAM
-----------------------------------------------------------------------------

  -- DDRAM_CLK <= clk_i;
  
  -- buff : ddram
  --   port map (
  --     DDRAM_CLK => clk_i,
  --     DDRAM_BUSY => DDRAM_BUSY,
  --     DDRAM_BURSTCNT => DDRAM_BURSTCNT,
  --     DDRAM_ADDR => DDRAM_ADDR,
  --     DDRAM_DOUT => DDRAM_DOUT,
  --     DDRAM_DOUT_READY => DDRAM_DOUT_READY,
  --     DDRAM_RD => DDRAM_RD,
  --     DDRAM_DIN => DDRAM_DIN,
  --     DDRAM_BE => DDRAM_BE,
  --     DDRAM_WE => DDRAM_WE,
  --     addr => buff_mem_addr,
  --     dout => buff_mem_dout,
  --     din => buff_mem_din,
  --     we => buff_mem_wr,
  --     rd => buff_mem_rd,
  --     ready => buff_mem_ready,
  --     reset => not reset_n_i
  --   ); 

  
  end struct;

