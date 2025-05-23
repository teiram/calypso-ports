-------------------------------------------------------------------------------
--
-- FPGA Videopac
--
-- $Id: jop_vp.vhd,v 1.11 2007/04/10 21:29:02 arnim Exp $
-- $Name: videopac_rel_1_0 $
--
-- Toplevel of the Cyclone port for MiST board by wsoltys in 2014.
--   https://github.com/wsoltys/mist-cores
--
-- Ported to Calypso board by overCLK in 2024.
--   https://github.com/teiram/calypso-ports
-------------------------------------------------------------------------------
--
-- Copyright (c) 2007, Arnim Laeuger (arnim.laeuger@gmx.net)
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
use ieee.std_logic_1164.all;

entity calypso_videopac is

  port (
    -- Clocks
    
    CLK12M    : in std_logic; -- 12 MHz


    -- SDRAM
    SDRAM_nCS : out std_logic; -- Chip Select
    SDRAM_CLK : out std_logic; -- SDRAM Clock
    SDRAM_CKE: out std_logic; -- SDRAM Clock Enable
    
    -- SPI
    SPI_SCK : in std_logic;
    SPI_DI : in std_logic;
    SPI_DO : out std_logic;
    SPI_SS2 : in std_logic;
    SPI_SS3 : in std_logic;
    CONF_DATA0 : in std_logic;

    -- VGA output
    

    VGA_HS,                                             -- H_SYNC
    VGA_VS : out std_logic;                             -- V_SYNC
    VGA_R,                                              -- Red[3:0]
    VGA_G,                                              -- Green[3:0]
    VGA_B : out std_logic_vector(3 downto 0);           -- Blue[3:0]
    
	 -- I2S audio
    I2S_BCK    : out   std_logic;
    I2S_LRCK   : out   std_logic;
    I2S_DATA   : out   std_logic;

    
    -- LEDG
    LED : out std_logic_vector(7 downto 0)
  );

end calypso_videopac;


library ieee;
use ieee.numeric_std.all;

library altera_mf;

use work.tech_comp_pack.vp_por;
use work.board_misc_comp_pack.dac;
use work.vp_console_comp_pack.vp_console;
use work.board_misc_comp_pack.mc_ctrl;
use work.board_misc_comp_pack.dblscan;
use work.i8244_col_pack.all;
use work.board_misc_comp_pack.vp_keymap;
use work.ps2_keyboard_comp_pack.ps2_keyboard_interface;

architecture struct of calypso_videopac is

  component vp_por
    generic (
      delay_g     : integer := 4;
      cnt_width_g : integer := 2
    );
    port (
      clk_i   : in  std_logic;
      por_n_o : out std_logic
    );
  end component;

  constant CONF_STR : string := "VIDEOPAC;BIN;O3,Swap Joysticks,off,on;T0,Reset;";

  function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable rval: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
  
  begin 
    for i in ss'range loop
      p := 8 * i;
      c := character'pos(ss(i));
      rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return rval; 

  end function;
  
  component user_io generic(STRLEN : integer := 0 );
  port
  (
        clk_sys : in std_logic;
        SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
        SPI_MISO : out std_logic;
        conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
        joystick_0 : out std_logic_vector(31 downto 0);
        joystick_1 : out std_logic_vector(31 downto 0);
        joystick_2 : out std_logic_vector(31 downto 0);
        joystick_3 : out std_logic_vector(31 downto 0);
        joystick_4 : out std_logic_vector(31 downto 0);
        joystick_analog_0 : out std_logic_vector(15 downto 0);
        joystick_analog_1 : out std_logic_vector(15 downto 0);
        status: out std_logic_vector(31 downto 0);
        switches : out std_logic_vector(1 downto 0);
        buttons : out std_logic_vector(1 downto 0);
        scandoubler_disable : out std_logic;
        ypbpr : out std_logic;

        ps2_kbd_clk       : out std_logic;
        ps2_kbd_data      : out std_logic
        );
  end component user_io;

  component osd
  generic ( OSD_COLOR : integer := 1 );  -- blue
  port (
        clk_sys     : in std_logic;

        R_in        : in std_logic_vector(5 downto 0);
        G_in        : in std_logic_vector(5 downto 0);
        B_in        : in std_logic_vector(5 downto 0);
        HSync       : in std_logic;
        VSync       : in std_logic;

        R_out       : out std_logic_vector(5 downto 0);
        G_out       : out std_logic_vector(5 downto 0);
        B_out       : out std_logic_vector(5 downto 0);

        SPI_SCK     : in std_logic;
        SPI_SS3     : in std_logic;
        SPI_DI      : in std_logic
  );
  end component osd;

  COMPONENT RGB2YPbPr
  PORT (
        red     :        IN std_logic_vector(5 DOWNTO 0);
        green   :        IN std_logic_vector(5 DOWNTO 0);
        blue    :        IN std_logic_vector(5 DOWNTO 0);
        y       :        OUT std_logic_vector(5 DOWNTO 0);
        pb      :        OUT std_logic_vector(5 DOWNTO 0);
        pr      :        OUT std_logic_vector(5 DOWNTO 0)
        );
  END COMPONENT;

  component data_io is
      port(sck: in std_logic;
           ss: in std_logic;
           sdi: in std_logic;
           downloading: out std_logic;
           size: out std_logic_vector(15 downto 0);
           clk: in std_logic;
           we: in std_logic;
           a: in std_logic_vector(12 downto 0);
           din: in std_logic_vector(7 downto 0);
           dout: out std_logic_vector(7 downto 0));
  end component;

  component i2s
    generic (
          I2S_Freq   : integer := 48000;
          AUDIO_DW   : integer := 16
    );
    port (
        clk        : in    std_logic;
        reset      : in    std_logic;
        clk_rate   : in    integer;
        sclk       : out   std_logic;
        lrclk      : out   std_logic;
        sdata      : out   std_logic;
        left_chan  : in    std_logic_vector(AUDIO_DW-1 downto 0);
        right_chan : in    std_logic_vector(AUDIO_DW-1 downto 0)
  );
  end component i2s;
  
  signal clk_43m_s      : std_logic;
  signal clk_21m5_s     : std_logic;

  -- CPU clock = PLL clock 21.5 MHz / 4
  constant cnt_cpu_c    : unsigned(1 downto 0) := to_unsigned(3, 2);
  -- VDC clock = PLL clock 21.5 MHz / 3
  -- note: VDC core runs with double frequency than compared with 8244 chip
  constant cnt_vdc_c    : unsigned(1 downto 0) := to_unsigned(2, 2);
  -- VGA clock = PLL clock 43 MHz / 3 (2x VDC clock)
  constant cnt_vga_c    : unsigned(1 downto 0) := to_unsigned(2, 2);
  --
  signal cnt_cpu_q      : unsigned(1 downto 0);
  signal cnt_vdc_q      : unsigned(1 downto 0);
  signal cnt_vga_q      : unsigned(1 downto 0);
  signal clk_cpu_en_s,
         clk_vdc_en_s,
         clk_vga_en_q   : std_logic;

  signal pll_locked_s   : std_logic;
  signal reset_n_s,
         reset_s        : std_logic;
  signal por_n_s        : std_logic;

  signal cart_a_s       : std_logic_vector(11 downto 0);
  signal rom_a_s        : std_logic_vector(12 downto 0);
  signal cart_d_s,
         rom_d_s        : std_logic_vector( 7 downto 0);
  signal cart_bs0_s,
         cart_bs1_s,
         cart_psen_n_s  : std_logic;

  signal r_s,
         g_s,
         b_s,
         l_s            : std_logic_vector( 7 downto 0);
  signal hsync_n_s,
         vsync_n_s      : std_logic;

  signal snd_s          : std_logic;
  signal snd_vec_s      : std_logic_vector(3 downto 0);

  signal joy_up_n_s,
         joy_down_n_s,
         joy_left_n_s,
         joy_right_n_s,
         joy_action_n_s : std_logic_vector( 1 downto 0);
  signal but_a_s,
         but_b_s,
         but_x_s,
         but_y_s,
         but_start_s,
         but_sel_s,
         but_tl_s,
         but_tr_s       : std_logic_vector( 1 downto 0);
  signal but_up_s,
         but_down_s,
         but_left_s,
         but_right_s    : std_logic_vector( 1 downto 0);

  signal dac_audio_s    : std_logic_vector( 7 downto 0);
  signal audio_s        : std_logic;
  
  -- user_io
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr      : std_logic;
  signal joya       : std_logic_vector(31 downto 0);
  signal joyb       : std_logic_vector(31 downto 0);
  signal joy0       : std_logic_vector(5 downto 0);
  signal joy1       : std_logic_vector(5 downto 0);
  signal joy_an0    : std_logic_vector(15 downto 0);
  signal joy_an1    : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(31 downto 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal audio      : std_logic;
  
  -- double scan
  signal rgb_r_s,
         rgb_g_s,
         rgb_b_s,
         rgb_l_s        : std_logic;
  signal rgb_hsync_n_s,
         rgb_hsync_s,
         rgb_vsync_n_s,
         rgb_vsync_s    : std_logic;
  signal vga_r_s,
         vga_g_s,
         vga_b_s,
         vga_l_s        : std_logic;
  signal vga_hsync_s,
         vga_vsync_s    : std_logic;
  signal blank_s        : std_logic;

  signal osd_red_o      : std_logic_vector(5 downto 0);
  signal osd_green_o    : std_logic_vector(5 downto 0);
  signal osd_blue_o     : std_logic_vector(5 downto 0);
  signal vga_y_o        : std_logic_vector(5 downto 0);
  signal vga_pb_o       : std_logic_vector(5 downto 0);
  signal vga_pr_o       : std_logic_vector(5 downto 0);

  -- data io
  signal downl : std_logic := '0';
  signal size : std_logic_vector(15 downto 0) := (others=>'0');
  signal forceReset : std_logic := '0';
  
  --keyboard
  signal keyb_dec_s      : std_logic_vector( 6 downto 1);
  signal keyb_enc_s      : std_logic_vector(14 downto 7);
  signal rx_data_ready_s : std_logic;
  signal rx_ascii_s      : std_logic_vector( 7 downto 0);
  signal rx_released_s   : std_logic;
  signal rx_read_s       : std_logic;
  
  signal gnd8_s : std_logic_vector(7 downto 0);

begin
  
  gnd8_s <= (others => '0');
  reset_s   <= not reset_n_s;


  por_b : vp_por
    generic map (
       delay_g     => 3,
       cnt_width_g => 2
    )
    port map (
       clk_i   => clk_21m5_s,
       por_n_o => por_n_s
    );


  reset_n_s <= not buttons(1) and pll_locked_s and por_n_s and not forceReset and not status(0);


  -----------------------------------------------------------------------------
  -- The PLL
  -----------------------------------------------------------------------------
  pll_b : entity work.pll
    port map (
      inclk0 => CLK12M,
      c0     => clk_43m_s,
      c1     => clk_21m5_s,
      locked => pll_locked_s
    );
  -- disable SDRAM
  SDRAM_CKE <= '0';
  SDRAM_CLK <= '0';
  SDRAM_nCS <= '1';

  -----------------------------------------------------------------------------
  -- Process clk_en
  --
  -- Purpose:
  --   Generates the CPU and VDC clock enables.
  --
  clk_en: process (clk_21m5_s, reset_n_s)
  begin
    if reset_n_s = '0' then
      cnt_cpu_q <= cnt_cpu_c;
      cnt_vdc_q <= cnt_vdc_c;
    elsif rising_edge(clk_21m5_s) then
      if clk_cpu_en_s = '1' then
        cnt_cpu_q <= cnt_cpu_c;
      else
        cnt_cpu_q <= cnt_cpu_q - 1;
      end if;
      --
      if clk_vdc_en_s = '1' then
        cnt_vdc_q <= cnt_vdc_c;
      else
        cnt_vdc_q <= cnt_vdc_q - 1;
      end if;
    end if;
  end process clk_en;
  --
  clk_cpu_en_s <= '1' when cnt_cpu_q = 0 else '0';
  clk_vdc_en_s <= '1' when cnt_vdc_q = 0 else '0';
  --
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Process vga_clk_en
  --
  -- Purpose:
  --   Generates the VGA clock enable.
  --
  vga_clk_en: process (clk_43m_s, reset_n_s)
  begin
    if reset_n_s = '0' then
      cnt_vga_q    <= cnt_vga_c;
      clk_vga_en_q <= '0';
    elsif rising_edge(clk_43m_s) then
      if cnt_vga_q = 0 then
        cnt_vga_q    <= cnt_vga_c;
        clk_vga_en_q <= '1';
      else
        cnt_vga_q    <= cnt_vga_q - 1;
        clk_vga_en_q <= '0';
      end if;
    end if;
  end process vga_clk_en;
  --

  -----------------------------------------------------------------------------
  -- The Videopac console
  -----------------------------------------------------------------------------
  vp_console_b : vp_console
    generic map (
      is_pal_g => 0
    )
    port map (
      clk_i          => clk_21m5_s,
      clk_cpu_en_i   => clk_cpu_en_s,
      clk_vdc_en_i   => clk_vdc_en_s,
      res_n_i        => reset_n_s,
      cart_cs_o      => open,
      cart_cs_n_o    => open,
      cart_wr_n_o    => open,
      cart_a_o       => cart_a_s,
      cart_d_i       => cart_d_s,
      cart_bs0_o     => cart_bs0_s,
      cart_bs1_o     => cart_bs1_s,
      cart_psen_n_o  => cart_psen_n_s,
      cart_t0_i      => gnd8_s(0),
      cart_t0_o      => open,
      cart_t0_dir_o  => open,
      -- idx = 0 : left joystick
      -- idx = 1 : right joystick
      joy_up_n_i     => joy_up_n_s,
      joy_down_n_i   => joy_down_n_s,
      joy_left_n_i   => joy_left_n_s,
      joy_right_n_i  => joy_right_n_s,
      joy_action_n_i => joy_action_n_s,
      keyb_dec_o     => keyb_dec_s,
      keyb_enc_i     => keyb_enc_s,
      r_o            => rgb_r_s,
      g_o            => rgb_g_s,
      b_o            => rgb_b_s,
      l_o            => rgb_l_s,
      hsync_n_o      => rgb_hsync_n_s,
      vsync_n_o      => rgb_vsync_n_s,
      hbl_o          => open,
      vbl_o          => open,
      snd_o          => open,
      snd_vec_o      => snd_vec_s
    );
  --
  -----------------------------------------------------------------------------
  -- VGA Scan Doubler
  -----------------------------------------------------------------------------
  rgb_hsync_s <= not rgb_hsync_n_s;
  rgb_vsync_s <= not rgb_vsync_n_s;
  --
  dblscan_b : dblscan
    port map (
      RGB_R_IN   => rgb_r_s,
      RGB_G_IN   => rgb_g_s,
      RGB_B_IN   => rgb_b_s,
      RGB_L_IN   => rgb_l_s,
      HSYNC_IN   => rgb_hsync_s,
      VSYNC_IN   => rgb_vsync_s,
      VGA_R_OUT  => vga_r_s,
      VGA_G_OUT  => vga_g_s,
      VGA_B_OUT  => vga_b_s,
      VGA_L_OUT  => vga_l_s,
      HSYNC_OUT  => vga_hsync_s,
      VSYNC_OUT  => vga_vsync_s,
      BLANK_OUT  => blank_s,
      CLK_RGB    => clk_21m5_s,
      CLK_EN_RGB => clk_vdc_en_s,
      CLK_VGA    => clk_43m_s,
      CLK_EN_VGA => clk_vga_en_q,
      RESET_N_I  => reset_n_s
    );
  --
 
  vga_rgb: process (clk_43m_s, reset_n_s)
    variable col_v : natural range 0 to 15;
  begin
    if reset_n_s ='0' then
      r_s <= (others => '0');
      g_s <= (others => '0');
      b_s <= (others => '0');
      hsync_n_s <= '1';
      vsync_n_s <= '1';
    elsif rising_edge(clk_43m_s) then
      if clk_vga_en_q = '1' then
        if scandoubler_disable = '0' then
          col_v := to_integer(unsigned'(vga_l_s & vga_r_s & vga_g_s & vga_b_s));
          r_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(r_c), 8));
          g_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(g_c), 8));
          b_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(b_c), 8));
          hsync_n_s <= not vga_hsync_s;
          vsync_n_s <= not vga_vsync_s;
        else
          col_v := to_integer(unsigned'(rgb_l_s & rgb_r_s & rgb_g_s & rgb_b_s));
          r_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(r_c), 8));
          g_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(g_c), 8));
          b_s <= std_logic_vector(to_unsigned(full_rgb_table_c(col_v)(b_c), 8));
          hsync_n_s <= not rgb_hsync_s;
          vsync_n_s <= not rgb_vsync_s;
        end if;
      end if;
    end if;
  end process vga_rgb;


  -----------------------------------------------------------------------------
  -- The cartridge ROM
  -----------------------------------------------------------------------------

  process(downl, rom_d_s)
  begin
    if(downl = '0') then
      cart_d_s <= rom_d_s;
      forceReset <= '0';
    else
      cart_d_s <= (others => '1');
      forceReset <= '1';
    end if;
  end process;
  
  process(size, cart_a_S, cart_bs1_s, cart_bs0_s)
  begin
    if(size <= x"0800") then       -- 2k
      rom_a_s <= "00" & cart_a_s(11) & cart_a_s(9 downto 0);
    elsif(size <= x"1000") then    -- 4k
      rom_a_s <= '0' & cart_bs0_s & cart_a_s(11) & cart_a_s(9 downto 0);
    elsif(size <= x"2000") then    -- 8k
      rom_a_s <= cart_bs1_s & cart_bs0_s & cart_a_s(11) & cart_a_s(9 downto 0);
    else
      rom_a_s <= "00" & cart_a_s(11) & cart_a_s(9 downto 0);
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Joysticks
  -----------------------------------------------------------------------------

  joy_up_n_s     <= (0 => not joy1(3),
                     1 => not joy0(3));
  joy_down_n_s   <= (0 => not joy1(2),
                     1 => not joy0(2));
  joy_left_n_s   <= (0 => not joy1(1),
                     1 => not joy0(1));
  joy_right_n_s  <= (0 => not joy1(0),
                     1 => not joy0(0));
  joy_action_n_s <= (0 => not joy1(4),
                     1 => not joy0(4));
    
  -----------------------------------------------------------------------------
  -- I2S sound
  -----------------------------------------------------------------------------    
  i2scomponent : i2s
      port map (
        clk => clk_21m5_s,
        reset => '0',
        clk_rate => 21_500_000,
        sclk => I2S_BCK,
        lrclk => I2S_LRCK,
        sdata => I2S_DATA,
        left_chan  => "0000" & snd_vec_s & "00000000",
        right_chan => "0000" & snd_vec_s & "00000000"
      );

      
  -----------------------------------------------------------------------------
  -- Keyboard components
  -----------------------------------------------------------------------------
  vp_keymap_b : vp_keymap
    port map (
      clk_i           => clk_21m5_s,
      res_n_i         => reset_n_s,
      keyb_dec_i      => keyb_dec_s,
      keyb_enc_o      => keyb_enc_s,
      rx_data_ready_i => rx_data_ready_s,
      rx_ascii_i      => rx_ascii_s,
      rx_released_i   => rx_released_s,
      rx_read_o       => rx_read_s
    );
  --
  ps2_keyboard_b : ps2_keyboard_interface
    generic map (
      TIMER_60USEC_VALUE_PP => 1290, -- Number of sys_clks for 60usec
      TIMER_60USEC_BITS_PP  =>   11, -- Number of bits needed for timer
      TIMER_5USEC_VALUE_PP  =>  107, -- Number of sys_clks for debounce
      TIMER_5USEC_BITS_PP   =>    7  -- Number of bits needed for timer
    )
    port map (
      clk             => clk_21m5_s,
      reset           => reset_s,
      ps2_clk         => ps2Clk,
      ps2_data        => ps2Data,
      rx_extended     => open,
      rx_released     => rx_released_s,
      rx_shift_key_on => open,
      rx_ascii        => rx_ascii_s,
      rx_data_ready   => rx_data_ready_s,
      rx_read         => rx_read_s,
      tx_data         => gnd8_s,
      tx_write        => gnd8_s(0),
      tx_write_ack    => open,
      tx_error_no_keyboard_ack => open
    );

  -----------------------------------------------------------------------------
  -- MiST 
  -----------------------------------------------------------------------------

  user_io_d : user_io
    generic map (STRLEN => CONF_STR'length)
    
    port map ( 
      clk_sys => clk_21m5_s,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,    
      SPI_MISO => SPI_DO,    
      SPI_MOSI => SPI_DI,       
      conf_str => to_slv(CONF_STR),
      status => status,   
      joystick_0 => joya,   
      joystick_1 => joyb,
      joystick_analog_0 => joy_an0,
      joystick_analog_1 => joy_an1,
      SWITCHES => switches,   
      BUTTONS => buttons,
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );

  joy0 <= joya(5 downto 0) when status(3) = '0' else joyb(5 downto 0);
  joy1 <= joyb(5 downto 0) when status(3) = '0' else joya(5 downto 0);

  osd_inst : osd
    port map (
      clk_sys => clk_43m_s,
      SPI_DI => SPI_DI,
      SPI_SCK => SPI_SCK,
      SPI_SS3 => SPI_SS3,
      R_in => r_s(7 downto 2),
      G_in => g_s(7 downto 2),
      B_in => b_s(7 downto 2),
      HSync => not hsync_n_s,
      VSync => not vsync_n_s,
      R_out => osd_red_o,
      G_out => osd_green_o,
      B_out => osd_blue_o
    );

  rgb2component: component RGB2YPbPr
    port map (
      red => osd_red_o,
      green => osd_green_o,
      blue => osd_blue_o,
      y => vga_y_o,
      pb => vga_pb_o,
      pr => vga_pr_o
    );

  VGA_HS <= not (hsync_n_s xor vsync_n_s) when scandoubler_disable='1' or ypbpr = '1' else hsync_n_s;
  VGA_VS <= '1' when scandoubler_disable='1' or ypbpr='1' else vsync_n_s;
  VGA_R <= vga_pr_o(5 downto 2) when ypbpr='1' else osd_red_o(5 downto 2);
  VGA_G <= vga_y_o(5 downto 2)  when ypbpr='1' else osd_green_o(5 downto 2);
  VGA_B <= vga_pb_o(5 downto 2) when ypbpr='1' else osd_blue_o(5 downto 2);

  LED(0) <= not downl;
  data_io_inst: data_io
    port map(SPI_SCK, SPI_SS2, SPI_DI, downl, size, clk_21m5_s, '0', rom_a_s(12 downto 0), (others=>'0'), rom_d_s);
    
end struct;
