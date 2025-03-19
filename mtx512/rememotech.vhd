--
-- rememotech.vhd - Top Level file for the REMEMOTECH project
--
-- An attempt to REimplement a MEMOTECH compatible computer.
-- Hardware implemented in VHDL, software in Z80 assembler.
-- Targetting Cyclone II and surrounding chips, on Altera DE1.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rememotech is
  port
    (
    CLOCK_50            : in  std_logic;
    -- S29AL032D70TFI04 4Mx8bit 70ns Flash,
    -- wired in byte mode
    -- arranged as 8x8KB and 63x64KB sectors
    FL_RST_N            : out std_logic;
    FL_CE_N             : out std_logic;
    FL_ADDR             : out std_logic_vector(21 downto 0);
    FL_OE_N             : out std_logic;
    FL_WE_N             : out std_logic;
    FL_DQ               : inout std_logic_vector(7 downto 0);
    -- 256Kx16bit 10ns SRAM
    SRAM_CE_N           : out std_logic;
    SRAM_ADDR           : out std_logic_vector(22 downto 0);
    SRAM_LB_N           : out std_logic;
    SRAM_UB_N           : out std_logic;
    SRAM_OE_N           : out std_logic;
    SRAM_WE_N           : out std_logic;
    SRAM_D              : out std_logic_vector(7 downto 0);
    SRAM_Q              : in std_logic_vector(7 downto 0);
	 SRAM_RDY            : in std_logic;
    -- SD card
    SD_CLK              : out std_logic;
    SD_CMD              : out std_logic;
    SD_DAT              : in  std_logic;
    SD_DAT3             : out std_logic;

    -- switches
    SW                  : in  std_logic_vector(9 downto 0);
    -- key switches
    KEY                 : in  std_logic_vector(3 downto 0);
    -- LEDs
    LEDR                : out std_logic_vector(9 downto 0);
    LEDG                : out std_logic_vector(7 downto 0);
    -- 7 segment displays
    HEX3,HEX2,HEX1,HEX0 : out std_logic_vector(6 downto 0);
    -- VGA output
    VGA_R,VGA_G,VGA_B   : out std_logic_vector(3 downto 0);
    VGA_HS,VGA_VS       : out std_logic;
	 VGA_HB,VGA_VB       : out std_logic;
    -- I2C
    I2C_SCLK            : inout std_logic;
    I2C_SDAT            : inout std_logic;
    -- UART
    UART_RXD            : in  std_logic;
    UART_TXD            : out std_logic;
    -- Daughter board, LED
    G0_LED              : out std_logic;
    -- Daughter board, Centronics
    G0_PRD              : out std_logic_vector(7 downto 0);
    G0_STROBE_n         : out std_logic;
    G0_SLCT             : in  std_logic;
    G0_ERROR_n          : in  std_logic;
    G0_BUSY             : in  std_logic;
    G0_PE               : in  std_logic;
    -- Daughter board, port 7
    G0_POT              : out std_logic_vector(7 downto 0);
    G0_OTSTB_N          : out std_logic;
    G0_PIN              : in  std_logic_vector(7 downto 0);
    G0_INSTB            : in  std_logic;
    -- Daughter board, EEPROM slot
    G0_A                : out std_logic_vector(15 downto 12);
    G1_A                : out std_logic_vector(11 downto 0);
    G1_D                : in  std_logic_vector(7 downto 0);
    G1_OE_n             : out std_logic;
    G1_CE_n             : out std_logic;
    -- Daughter board, 2nd monitor
    G1_R,G1_G,G1_B      : out std_logic_vector(3 downto 0);
    G1_HS,G1_VS         : out std_logic;
	 -- Clocks
	 clk_video_i         : in std_logic;
 	 clk_cpu_o			   : out std_logic;

    --
	 LED                 : out std_logic;
	 --
	 PS2_CLK             : in std_logic;
	 PS2_DAT             : in std_logic;
	 EKey           		: in std_logic;
    key_ready  			: in  std_logic;
    key_stroke 			: in  std_logic;
    key_code   			: in  std_logic_vector(9 downto 0);
	 -- Audio
	 sound_out	    		: out std_logic_vector(7 downto 0)	 
    );
end rememotech;



architecture behavior of rememotech is

  component clock_divider
    port
      (
      clk_50mhz   : in  std_logic;
		ram_ready   : in  std_logic;
      div_cpu     : in  std_logic_vector(2 downto 0);
      clk_cpu     : out std_logic;
      clk_timer16 : out std_logic;
      clk_counter : out std_logic;
      clk_25mhz   : out std_logic;
      clk_4mhz    : out std_logic;
      clk_1mhz    : out std_logic
      );
  end component;

  component mon_cell
    port
      (
      clk_host    : in  std_logic;
      d_host_atr  : in  std_logic_vector(7 downto 0);
      d_host_asc  : in  std_logic_vector(7 downto 0);
      addr_host   : in  std_logic_vector(11 downto 0);
      we_host_atr : in  std_logic;
      we_host_asc : in  std_logic;
      q_host_atr  : out std_logic_vector(7 downto 0);
      q_host_asc  : out std_logic_vector(7 downto 0);
      clk_mon     : in  std_logic;
      addr_mon    : in  std_logic_vector(11 downto 0);
      q_mon_atr   : out std_logic_vector(7 downto 0);
      q_mon_asc   : out std_logic_vector(7 downto 0)
      );
  end component;

  component mon
    port
      (
      clk_25mhz     : in  std_logic;
      cell_addr     : out std_logic_vector(11 downto 0);
      cell_data_atr : in  std_logic_vector(7 downto 0);
      cell_data_asc : in  std_logic_vector(7 downto 0);
      base          : in  std_logic_vector(11 downto 0);
      cursor        : in  std_logic_vector(11 downto 0);
      cursor_vis    : in  std_logic;
      mode          : in  std_logic;
      cursor_r      : in  std_logic;
      cursor_g      : in  std_logic;
      cursor_b      : in  std_logic;
      vga_r         : out std_logic;
      vga_g         : out std_logic;
      vga_b         : out std_logic;
      vga_hsync     : out std_logic;
      vga_vsync     : out std_logic;
      vga_hblank    : out std_logic;
      vga_vblank    : out std_logic		
      );
  end component;

  component vdp_vram
    port
      (
      clk_host  : in  std_logic;
      d_host    : in  std_logic_vector(7 downto 0);
      addr_host : in  std_logic_vector(13 downto 0);
      we_host   : in  std_logic;
      q_host    : out std_logic_vector(7 downto 0);
      clk_vdp   : in  std_logic;
      addr_vdp  : in  std_logic_vector(13 downto 0);
      q_vdp     : out std_logic_vector(7 downto 0)
      );
  end component;

  
  component Memory
    port
      (
      
      clk_host  : in  std_logic;

      addr_host : in  std_logic_vector(17 downto 0);
      d_host    : in  std_logic_vector(15 downto 0);
      lb_host   : in  std_logic;
      ub_host   : in  std_logic;
      we_host   : in  std_logic;
      ce_host   : in  std_logic;
      oe_host   : in  std_logic;
	 
      q_host    : out std_logic_vector(15 downto 0)

    );
  end component;  
  
  
  component RamRom
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (17 DOWNTO 0);
		byteena		: IN STD_LOGIC_VECTOR (1 DOWNTO 0) :=  (OTHERS => '1');
		clken		: IN STD_LOGIC  := '1';
		clock		: IN STD_LOGIC  := '1';
		rden     : IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
  end component;
  
  
  component vdp
    port
      (
      clk_25mhz     : in  std_logic;
      vram_addr     : out std_logic_vector(13 downto 0);
      vram_q        : in  std_logic_vector(7 downto 0);
      clk_cpu       : in  std_logic;
      reg_re        : in  std_logic;
      reg_we        : in  std_logic;
      reg_number    : in  std_logic_vector(2 downto 0);
      reg_value     : in  std_logic_vector(7 downto 0);
      status        : out std_logic_vector(7 downto 0);
      interrupt     : out std_logic;
      hw_pal        : in  std_logic;
      frame_rate    : in  std_logic;
      debug_patnam  : in  std_logic;
      debug_patgen  : in  std_logic;
      debug_patcol  : in  std_logic;
      debug_sprgen  : in  std_logic;
      vga_r         : out std_logic_vector(3 downto 0);
      vga_g         : out std_logic_vector(3 downto 0);
      vga_b         : out std_logic_vector(3 downto 0);
      vga_hsync     : out std_logic;
      vga_vsync     : out std_logic;
      vga_hblank    : out std_logic;
      vga_vblank    : out std_logic
      );
  end component;

  component sound
    port
      (
      -- processor interface
      clk_cpu   : in  std_logic;
      reset     : in  std_logic;
      reg_we    : in  std_logic;
      reg_value : in  std_logic_vector(7 downto 0);
      -- how to further divide clk_cpu
      div_cpu   : in  std_logic_vector(2 downto 0);
      -- sound output
      output    : out std_logic_vector(7 downto 0)
      );
  end component;

  component i2s_intf is
    generic(
      mclk_rate   : positive := 12000000;
      sample_rate : positive := 8000;
      preamble    : positive := 1; -- I2S
      word_length : positive := 16
      );
    port(
      CLK       : in  std_logic;
      nRESET    : in  std_logic;
      PCM_INL   : out std_logic_vector(word_length - 1 downto 0);
      PCM_INR   : out std_logic_vector(word_length - 1 downto 0);
      PCM_OUTL  : in  std_logic_vector(word_length - 1 downto 0);
      PCM_OUTR  : in  std_logic_vector(word_length - 1 downto 0);
      I2S_MCLK  : out std_logic;
      I2S_LRCLK : out std_logic;
      I2S_BCLK  : out std_logic;
      I2S_DOUT  : out std_logic;
      I2S_DIN   : in std_logic
      );
  end component;

  component i2c_loader is
    generic (
      device_address : integer := 16#1a#;
      num_retries    : integer := 0;
      log2_divider   : integer := 6
      );
    port(
      CLK      : in    std_logic;
      nRESET   : in    std_logic;
      I2C_SCL  : inout std_logic;
      I2C_SDA  : inout std_logic;
      IS_DONE  : out   std_logic;
      IS_ERROR : out   std_logic
      );
  end component;

  component sd_card_De1
    port
      (
      clk_50mhz : in std_logic;
      reset     : in std_logic;
      divider   : in std_logic_vector(5 downto 0);
      SD_CLK    : out std_logic;
      SD_CMD    : out std_logic;
      SD_DAT    : in  std_logic;
      SD_DAT3   : out std_logic;
      clk_cpu   : in  std_logic;
      sel       : in  std_logic;
      cmd       : in  std_logic;
      cmd_ff    : in  std_logic;
      do        : in  std_logic_vector(7 downto 0);
      ready     : out std_logic;
      di        : out std_logic_vector(7 downto 0)
      );
  end component;

  component ps2_kbd
    port
      (
      clk_1mhz   : in    std_logic;
      PS2_CLK    : in    std_logic;
      PS2_DAT    : in    std_logic;
      key_ready  : out   std_logic;
      key_stroke : out   std_logic;
      key_code   : out   std_logic_vector(9 downto 0)
      );
  end component;

  component mtx_kbd
    port
      (
      clk_1mhz   : in  std_logic;
      key_ready  : in  std_logic;
      key_stroke : in  std_logic;
      key_code   : in  std_logic_vector(9 downto 0);
      drive      : in  std_logic_vector(7 downto 0);
      sense5     : out std_logic_vector(7 downto 0);
      sense6     : out std_logic_vector(7 downto 0);
      extra_keys : out std_logic_vector(13 downto 0)
      );
  end component;

  component ctc
    port
      (
      clk_cpu    : in  std_logic;
      reset      : in  std_logic;
      channel    : in  std_logic_vector(1 downto 0);
      we         : in  std_logic;
      data_write : in  std_logic_vector(7 downto 0);
      data_read  : out std_logic_vector(7 downto 0);
      interrupt  : out std_logic;
      re_vector  : in  std_logic;
      vector     : out std_logic_vector(7 downto 1);
      timer16    : in  std_logic;
      count0     : in  std_logic;
      count1     : in  std_logic;
      count2     : in  std_logic;
      count3     : in  std_logic;
      zcto0      : out std_logic;
      zcto1      : out std_logic;
      zcto2      : out std_logic
      );
  end component;

  component dart
    port
      (
      clk_cpu : in  std_logic;
      reset   : in  std_logic;
      b_not_a : in  std_logic;
      c_not_d : in  std_logic;
      cs      : in  std_logic;
      iorq_n  : in  std_logic;
      rd_n    : in  std_logic;
      wr_n    : in  std_logic;
      data_i  : in  std_logic_vector(7 downto 0);
      stat_a  : out std_logic_vector(7 downto 0);
      data_a  : out std_logic_vector(7 downto 0);
      stat_b  : out std_logic_vector(7 downto 0);
      data_b  : out std_logic_vector(7 downto 0);
      clk_a   : in  std_logic; -- 4MHz/13/n (n=1,2,4,...)
      clk_b   : in  std_logic; -- 4MHz/13/n (n=1,2,4,...)
      rx_a    : in  std_logic;
      tx_a    : out std_logic;
      rx_b    : in  std_logic;
      tx_b    : out std_logic
      );
  end component;

  component boot_rom
    port
      (
      addr : in  std_logic_vector(9 downto 0);
      q    : out std_logic_vector(7 downto 0)
      );
  end component;

  component digit_to_seven
    port
      (
      digit : in  std_logic_vector(3 downto 0);
      seven : out std_logic_vector(6 downto 0)
      );
  end component;

  component T80se
    generic
      (
      Mode    : integer := 0; -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
      T2Write : integer := 0; -- 0 => WR_n active in T3, /=0 => WR_n active in T2
      IOWait  : integer := 1  -- 0 => Single cycle I/O, 1 => Std I/O cycle
      );
    port
      (
      RESET_n         : in  std_logic;
      CLK_n           : in  std_logic;
      CLKEN           : in  std_logic;
      WAIT_n          : in  std_logic;
      INT_n           : in  std_logic;
      NMI_n           : in  std_logic;
      BUSRQ_n         : in  std_logic;
      M1_n            : out std_logic;
      MREQ_n          : out std_logic;
      IORQ_n          : out std_logic;
      RD_n            : out std_logic;
      WR_n            : out std_logic;
      RFSH_n          : out std_logic;
      HALT_n          : out std_logic;
      BUSAK_n         : out std_logic;
      A               : out std_logic_vector(15 downto 0);
      DI              : in  std_logic_vector(7 downto 0);
      DO              : out std_logic_vector(7 downto 0)
      );
  end component;

  component memory_map
    port
      (
      iobyte    : in std_logic_vector(7 downto 0);
      page1     : in std_logic_vector(7 downto 0);
      page2     : in std_logic_vector(7 downto 0);
      addr      : in std_logic_vector(15 downto 13);
      erom      : in std_logic;
      oe        : out std_logic;
      se        : out std_logic;
      fe        : out std_logic;
      ere       : out std_logic;
      we        : out std_logic;
      phys_addr : out std_logic_vector(21 downto 13)
      );
  end component;
  
  component speculator is
    port
      (
      extras    : in    std_logic;
      RESET     : in    std_logic; 
      m49       : in    std_logic;
      PHI       : in    std_logic;
      MREQ_n    : in    std_logic;
      IORQ_n    : in    std_logic;
      RD_n      : in    std_logic;
      WR_n      : in    std_logic;
      iobyte    : in    std_logic_vector( 7 downto 0);
      A         : in    std_logic_vector(15 downto 0);
      DI        : in    std_logic_vector( 7 downto 0);
      DO        : out   std_logic_vector( 7 downto 0);
      DO_valid  : out   std_logic;
      INT_n     : in    std_logic;
      NMI_n     : out   std_logic
      );
  end component;

  component accelerator is
    port
      (
      enabled  : in    std_logic;
      RESET    : in    std_logic; 
      PHI      : in    std_logic;
      IORQ_n   : in    std_logic;
      RD_n     : in    std_logic;
      WR_n     : in    std_logic;
      A        : in    std_logic_vector( 7 downto 0);
      DI       : in    std_logic_vector( 7 downto 0);
      DO       : out   std_logic_vector( 7 downto 0);
      DO_valid : out   std_logic
      );
  end component;

  signal one : std_logic;

  -- Clock related
  signal clk_cpu     : std_logic;
  signal div_cpu     : std_logic_vector(2 downto 0);
  signal clk_25mhz   : std_logic;
  signal cpu_counter : std_logic_vector(23 downto 0);
  signal clk_4mhz    : std_logic;
  signal clk_1mhz    : std_logic;

  -- Cell memory related
  signal host_cell_write  : std_logic;
  signal host_cell_ascm   : std_logic;
  signal host_cell_atrm   : std_logic;
  signal host_cell_we_atr : std_logic;
  signal host_cell_we_asc : std_logic;
  signal host_cell_addr   : std_logic_vector(11 downto 0);
  signal host_cell_d_atr  : std_logic_vector(7 downto 0);
  signal host_cell_d_asc  : std_logic_vector(7 downto 0);
  signal host_cell_q_atr  : std_logic_vector(7 downto 0);
  signal host_cell_q_asc  : std_logic_vector(7 downto 0);
  signal mon_cell_addr    : std_logic_vector(11 downto 0);
  signal mon_cell_q_atr   : std_logic_vector(7 downto 0);
  signal mon_cell_q_asc   : std_logic_vector(7 downto 0);

  -- Monitor chip related
  signal crtc_reg        : std_logic_vector(4 downto 0)  := "00000";
  signal crtc_base       : std_logic_vector(11 downto 0) := "000000000000";
  signal crtc_cursor     : std_logic_vector(11 downto 0) := "000000000000";
  signal crtc_cursor_vis : std_logic := '1';
  signal crtc_mode       : std_logic := '0'; -- 24 lines
  signal cursor_r        : std_logic;
  signal cursor_g        : std_logic;
  signal cursor_b        : std_logic;
  signal mon_r           : std_logic;
  signal mon_g           : std_logic;
  signal mon_b           : std_logic;
  signal mon_hsync       : std_logic;
  signal mon_vsync       : std_logic;
  signal mon_hblank		 : std_logic;
  signal mon_vblank 		 : std_logic;

  -- VRAM related
  signal host_vram_addr     : std_logic_vector(13 downto 0) := "00000000000000";
  signal host_vram_addr_inc : std_logic := '0';
  signal host_vram_d        : std_logic_vector(7 downto 0);
  signal host_vram_we       : std_logic := '0';
  signal host_vram_q        : std_logic_vector(7 downto 0);
  signal vdp_vram_addr      : std_logic_vector(13 downto 0) := "00000000000000";
  signal vdp_vram_q         : std_logic_vector(7 downto 0);

  -- VDP chip related
  signal vdp_latched     : std_logic := '0';
  signal vdp_reg_re      : std_logic;
  signal vdp_reg_we      : std_logic := '0';
  signal vdp_reg_number  : std_logic_vector(2 downto 0);
  signal vdp_reg_value   : std_logic_vector(7 downto 0);
  signal vdp_status      : std_logic_vector(7 downto 0);
  signal vdp_interrupt   : std_logic;
  signal vdp_r           : std_logic_vector(3 downto 0);
  signal vdp_g           : std_logic_vector(3 downto 0);
  signal vdp_b           : std_logic_vector(3 downto 0);
  signal vdp_hsync       : std_logic;
  signal vdp_vsync       : std_logic;
  signal vdp_hblank      : std_logic;
  signal vdp_vblank      : std_logic;

  -- Sound chip related
  signal sound_reg_we    : std_logic := '0';
  signal sound_reg_value : std_logic_vector(7 downto 0);
  signal sound_output    : std_logic_vector(7 downto 0);
  signal sound_to_codec  : std_logic_vector(15 downto 6);

  -- SD card related
  signal sd_divider    : std_logic_vector(5 downto 0);
  signal sd_sel        : std_logic := '0';
  signal sd_command    : std_logic := '0';
  signal sd_command_ff : std_logic := '0';
  signal sd_ready      : std_logic;
  signal sd_data       : std_logic_vector(7 downto 0);
  signal sd_temp       : std_logic_vector(24 downto 0) := (others => '0');

  -- keyboard related
--  signal key_ready  : std_logic;
--  signal key_stroke : std_logic;
--  signal key_code   : std_logic_vector(9 downto 0);
  signal drive      : std_logic_vector(7 downto 0);
  signal sense5     : std_logic_vector(7 downto 0);
  signal sense6     : std_logic_vector(7 downto 0);
  signal extra_keys : std_logic_vector(13 downto 0);
  signal extra_keys_bak : std_logic_vector(13 downto 0);

  -- CTC related
  signal ctc_we        : std_logic;
  signal ctc_data_read : std_logic_vector(7 downto 0);
  signal ctc_interrupt : std_logic;
  signal ctc_re_vector : std_logic;
  signal ctc_vector    : std_logic_vector(7 downto 1);
  signal ctc_counter   : std_logic;
  signal ctc_timer16   : std_logic;
  signal ctc_zcto1     : std_logic;
  signal ctc_zcto2     : std_logic;

  -- DART related
  signal dart_cs        : std_logic := '0';
  signal dart_data_a    : std_logic_vector(7 downto 0);
  signal dart_stat_a    : std_logic_vector(7 downto 0);
  signal dart_data_b    : std_logic_vector(7 downto 0);
  signal dart_stat_b    : std_logic_vector(7 downto 0);
  signal dart_rx_a      : std_logic;
  signal dart_tx_a      : std_logic;
  signal dart_rx_b      : std_logic;
  signal dart_tx_b      : std_logic;
  signal dart_ch        : std_logic := '1'; -- port B
  signal dart_key2_prev : std_logic := '1';

  -- Boot ROM related
  signal rom_q : std_logic_vector(7 downto 0);

  -- Memory map related
  signal iobyte    : std_logic_vector(7 downto 0) := x"8f";
  signal page1     : std_logic_vector(7 downto 0) := "00000000";
  signal page2     : std_logic_vector(7 downto 0) := "00000000";
  signal oe        : std_logic;
  signal se        : std_logic;
  signal fe        : std_logic;
  signal ere       : std_logic;
  signal we        : std_logic;
  signal phys_addr : std_logic_vector(21 downto 13);
  signal flash_vis : std_logic;

  -- Speculator
  signal spec_extras   : std_logic := '0';
  signal spec_DO       : std_logic_vector(7 downto 0);
  signal spec_DO_valid : std_logic;
  
  signal romswe        : std_logic;
  signal real_cassete  : std_logic;
  
  
  -- Accelerator
  signal accel_enabled  : std_logic := '0';
  signal accel_DO       : std_logic_vector(7 downto 0);
  signal accel_DO_valid : std_logic;
            
  -- Port 7 related
  signal pot     : std_logic_vector(7 downto 0) := "00000000";
  signal otstb_n : std_logic := '1';
  signal pin     : std_logic_vector(7 downto 0);

  -- Centronics related
  signal prd      : std_logic_vector(7 downto 0);
  signal strobe_n : std_logic := '1';

  -- ROM 2 related
  signal rom2subpage : std_logic_vector(2 downto 0) := "000";

  -- Relating to 7 segment display
  signal digit3, digit2, digit1, digit0 : std_logic_vector(3 downto 0) := "1100"; --AAAA

  -- Green LEDs
  signal ledg_int : std_logic_vector(7 downto 0);

  -- Z80 related
  signal RESET_n : std_logic;
  signal M1_n    : std_logic;
  signal MREQ_n  : std_logic;
  signal IORQ_n  : std_logic;
  signal RD_n    : std_logic;
  signal WR_n    : std_logic;
  signal NMI_n   : std_logic;
  signal A       : std_logic_vector(15 downto 0);
  signal DI      : std_logic_vector(7 downto 0);
  signal DO      : std_logic_vector(7 downto 0);

  -- so can see A in SignalTap
  -- attribute keep : boolean;
  -- attribute keep of A : signal is true;

--  signal SRAM_CE_N: std_logic;
--  signal SRAM_ADDR: std_logic_vector(17 downto 0);
--  signal SRAM_LB_N: std_logic;
--  signal SRAM_UB_N: std_logic;
--  signal SRAM_OE_N: std_logic;
--  signal SRAM_WE_N: std_logic;
--  signal SRAM_D	: std_logic_vector(15 downto 0);
--  signal SRAM_Q	: std_logic_vector(15 downto 0);  
  

  
begin

  U_DIVIDER : clock_divider
    port map
      (
      clk_50mhz   => CLOCK_50,
		ram_ready   => SRAM_RDY,
      div_cpu     => div_cpu,
      clk_cpu     => clk_cpu,
      clk_timer16 => ctc_timer16,
      clk_counter => ctc_counter,
      clk_25mhz   => open,
      clk_4mhz    => clk_4mhz,
      clk_1mhz    => clk_1mhz
      );

  U_CELL : mon_cell
    port map
      (
      clk_host    => clk_cpu,
      d_host_atr  => host_cell_d_atr,
      d_host_asc  => host_cell_d_asc,
      addr_host   => host_cell_addr,
      we_host_atr => host_cell_we_atr,
      we_host_asc => host_cell_we_asc,
      q_host_atr  => host_cell_q_atr,
      q_host_asc  => host_cell_q_asc,
      clk_mon     => clk_25mhz,
      addr_mon    => mon_cell_addr,
      q_mon_atr   => mon_cell_q_atr,
      q_mon_asc   => mon_cell_q_asc
      );

  U_MON : mon
    port map
      (
      clk_25mhz     => clk_25mhz,
      cell_addr     => mon_cell_addr,
      cell_data_atr => mon_cell_q_atr,
      cell_data_asc => mon_cell_q_asc,
      base          => crtc_base,
      cursor        => crtc_cursor,
      cursor_vis    => crtc_cursor_vis,
      mode          => crtc_mode,
      cursor_r      => cursor_r,
      cursor_g      => cursor_g,
      cursor_b      => cursor_b,
      vga_r         => mon_r,
      vga_g         => mon_g,
      vga_b         => mon_b,
      vga_hsync     => mon_hsync,
      vga_vsync     => mon_vsync,
      vga_hblank    => mon_hblank,
      vga_vblank    => mon_vblank
      );

  U_VRAM : vdp_vram
    port map (
      clk_host  => clk_cpu,
      d_host    => host_vram_d,
      addr_host => host_vram_addr,
      we_host   => host_vram_we,
      q_host    => host_vram_q,
      clk_vdp   => clk_25mhz,
      addr_vdp  => vdp_vram_addr,
      q_vdp     => vdp_vram_q
      );


		
		
  U_VDP : vdp
    port map
      (
      clk_25mhz     => clk_25mhz,
      vram_addr     => vdp_vram_addr,
      vram_q        => vdp_vram_q,
      clk_cpu       => clk_cpu,
      reg_re        => vdp_reg_re,
      reg_we        => vdp_reg_we,
      reg_number    => vdp_reg_number,
      reg_value     => vdp_reg_value,
      status        => vdp_status,
      interrupt     => vdp_interrupt,
      hw_pal        => SW(5),
      frame_rate    => SW(4),
      debug_patnam  => not extra_keys(0), -- F9
      debug_patgen  => not extra_keys(1), -- F10
      debug_patcol  => not extra_keys(2), -- F11
      debug_sprgen  => not extra_keys(3), -- F12
      vga_r         => vdp_r,
      vga_g         => vdp_g,
      vga_b         => vdp_b,
      vga_hsync     => vdp_hsync,
      vga_vsync     => vdp_vsync,
		vga_hblank    => vdp_hblank,
      vga_vblank    => vdp_vblank
      );

  U_SOUND : sound
    port map
      (
      clk_cpu   => clk_cpu,
      reset     => not RESET_n,
      reg_we    => sound_reg_we,
      reg_value => sound_reg_value,
      div_cpu   => div_cpu,
      output    => sound_output
      );

  U_I2C_LOADER : i2c_loader 
    generic map
      (
      log2_divider => 7
      )
    port map
      (
      clk_4mhz,
      RESET_n,
      I2C_SCLK,
      I2C_SDAT,
      open, -- is done
      open  -- is error
      );

  U_SD : sd_card_De1
    port map
      (
      clk_50mhz => clk_25mhz,
      reset     => not RESET_n,
      divider   => sd_divider,
      SD_CLK    => SD_CLK,
      SD_CMD    => SD_CMD,
      SD_DAT    => SD_DAT,
      SD_DAT3   => SD_DAT3,
      clk_cpu   => clk_cpu,
      sel       => sd_sel,
      cmd       => sd_command,
      cmd_ff    => sd_command_ff,
      do        => DO,
      ready     => sd_ready,
      di        => sd_data
      );

--  U_PS2KBD : ps2_kbd
--    port map
--      (
--      clk_1mhz   => clk_1mhz,
--      PS2_CLK    => PS2_CLK,
--      PS2_DAT    => PS2_DAT,
--      key_ready  => key_ready,
--      key_stroke => key_stroke,
--      key_code   => key_code
--      );

  U_MTXKBD : mtx_kbd
    port map
      (
      clk_1mhz   => clk_25Mhz,
      key_ready  => key_ready,
      key_stroke => not key_stroke,
      key_code   => key_code,
      drive      => drive,
      sense5     => sense5,
      sense6     => sense6,
      extra_keys => extra_keys --_bak
      );

  U_CTC : ctc
    port map
      (
      clk_cpu    => clk_cpu,
      reset      => not RESET_n,
      channel    => A(1 downto 0),
      we         => ctc_we,         -- write register
      data_write => DO,             -- new register value
      data_read  => ctc_data_read,  -- read counter
      interrupt  => ctc_interrupt,  -- CTC asserting interrupt
      re_vector  => ctc_re_vector,  -- CPU acknowledging interrupt
      vector     => ctc_vector,     -- CTC supplies vector to CPU
      timer16    => ctc_timer16,    -- 4MHz/16 approx
      count0     => vdp_interrupt,  -- VDP
      count1     => ctc_counter,    -- 4MHz/13 approx
      count2     => ctc_counter,    -- 4MHz/13 approx
      count3     => one,            -- no cassette
      zcto0      => open,           -- doesn't drive anything
      zcto1      => ctc_zcto1,      -- drives RS232 A
      zcto2      => ctc_zcto2       -- drives RS232 B
      );

  U_DART : dart
    port map
      (
      clk_cpu => clk_cpu,
      reset   => not RESET_n,
      b_not_a => A(0),
      c_not_d => A(1),
      cs      => dart_cs,
      iorq_n  => IORQ_n,
      rd_n    => RD_n,
      wr_n    => WR_n,
      data_i  => DO,
      data_a  => dart_data_a,
      stat_a  => dart_stat_a,
      data_b  => dart_data_b,
      stat_b  => dart_stat_b,
      clk_a   => ctc_zcto1,
      clk_b   => ctc_zcto2,
      rx_a    => dart_rx_a,
      tx_a    => dart_tx_a,
      rx_b    => dart_rx_b,
      tx_b    => dart_tx_b
      );

  U_ROM : boot_rom
    port map
      (
      addr => A(9 downto 0),
      q    => rom_q
      );

  U_MEMORYMAP : memory_map
    port map
      (
      iobyte    => iobyte,
      page1     => page1,
      page2     => page2,
      addr      => A(15 downto 13),
      erom      => SW(1) or SW(0),
      oe        => oe,
      se        => se,
      fe        => fe,
      ere       => ere,
      we        => we,
      phys_addr => phys_addr
      );

	U_SPECULATOR : speculator
    port map
      (
      extras   => spec_extras,
      RESET    => not RESET_n,
      m49      => CLOCK_50,
      PHI      => clk_cpu,
      MREQ_n   => MREQ_n,
      IORQ_n   => IORQ_n,
      RD_n     => RD_n,
      WR_n     => WR_n,
      iobyte   => iobyte,
      A        => A,
      DI       => DO,
      DO       => spec_DO,
      DO_valid => spec_DO_valid,
      INT_n    => not ctc_interrupt,
      NMI_n    => NMI_n
      );	
		
  U_ACCELERATOR : accelerator
    port map
      (
      enabled  => accel_enabled,
      RESET    => not RESET_n,
      PHI      => clk_cpu,
      IORQ_n   => IORQ_n,
      RD_n     => RD_n,
      WR_n     => WR_n,
      A        => A(7 downto 0),
      DI       => DO,
      DO       => accel_DO,
      DO_valid => accel_DO_valid
      );

  U_SEVEN3 : digit_to_seven
    port map
      (
      digit => digit3,
      seven => HEX3
      );

  U_SEVEN2 : digit_to_seven
    port map
      (
      digit => digit2,
      seven => HEX2
      );

  U_SEVEN1 : digit_to_seven
    port map
      (
      digit => digit1,
      seven => HEX1
      );

  U_SEVEN0 : digit_to_seven
    port map
      (
      digit => digit0,
      seven => HEX0
      );

  one <= '1';
  U_Z80 : t80se
    generic map
      (
      Mode    => 0, -- Fast Z80 (Non-M1 cycles shortened to 3T)
      T2Write => 0, -- WR_n active in T3
      IOWait  => 1  -- Std I/O cycle
      )
    port map
      (
      RESET_n => RESET_n,
      CLK_n   => clk_cpu,
      CLKEN   => one,
      WAIT_n  => SRAM_RDY,
      INT_n   => not ctc_interrupt,
      NMI_n   => NMI_n,
      BUSRQ_n => one,
      M1_n    => M1_n,
      MREQ_n  => MREQ_n,
      IORQ_n  => IORQ_n,
      RD_n    => RD_n,
      WR_n    => WR_n,
      RFSH_n  => open,
      HALT_n  => open,
      BUSAK_n => open,
      A       => A,
      DI      => DI,
      DO      => DO
      );

  -- Reset
  RESET_n <= not KEY(3);-- and ( extra_keys(12) or extra_keys(13) );
  --extra_keys <= "11111111111111";-- & EKey; 
  
  clk_25Mhz <= clk_video_i;
  clk_cpu_o   <= clk_cpu;
  sound_out <= sound_output;
  
  
  -- Is the Flash memory visible in the Z80 address space?
  flash_vis <= '1' when ( iobyte(3 downto 0) = "1111" ) else '0';
    

  -- Set clock speed according to user choice
  -- but as I can't easily get wait states to work
  -- slow down clock if Flash is visible through the memory map
  -- Flash is 70ns, and at 25MHz, cycle time is 40ns, so halve it
  -- div_cpu <= "001" when ( flash_vis = '1' and SW(9 downto 7) = "000" ) else SW(9 downto 7);
  div_cpu <= SW(9 downto 7);
  
  -- See clock speed setting
  LEDR(9 downto 7) <= div_cpu;
  process ( clk_cpu )
  begin
    if rising_edge(clk_cpu) then
      cpu_counter <= cpu_counter+1;
    end if;
  end process;

  -- accesses to Flash
  --   if not in RAM page 15
  --     raise FL_CE_N, allowing the device to go into "standby mode"
  FL_RST_N <= '1';
  FL_CE_N  <= not flash_vis;
  FL_ADDR  <= phys_addr(21 downto 13) & A(12 downto 0);
  FL_OE_N  <= '0' when ( RD_n = '0' and MREQ_n = '0' and fe = '1' ) else '1';
  FL_WE_N  <= '0' when ( WR_n = '0' and MREQ_n = '0' and fe = '1' ) else '1';
  FL_DQ    <= DO  when ( WR_n = '0' and MREQ_n = '0' and fe = '1' ) else (others => 'Z');

  -- accesses to SRAM
  SRAM_CE_N <= '0';
  SRAM_ADDR <= '0' & phys_addr(21 downto 13) & A(12 downto 0);
  SRAM_LB_N <= '0'      when A(0) = '0' else '1';
  SRAM_UB_N <= '0'      when A(0) = '1' else '1';
  SRAM_OE_N <= '0'      when ( RD_n = '0' and MREQ_n = '0' and se = '1'              ) else '1';
  SRAM_WE_N <= '0'      when ( WR_n = '0' and MREQ_n = '0' and se = '1' and we = '1' ) else '1';
  SRAM_D   <=  DO when ( WR_n = '0' and MREQ_n = '0' and se = '1'              ); --SRAM_DQ   <=  DO & DO when ( WR_n = '0' and MREQ_n = '0' and se = '1'              ) else (others => 'Z');
  

  -- access to external EEPROM
  G1_CE_n  <= not ere;
  G1_OE_n  <= MREQ_n or RD_n;
  -- 27512 has A15, others have Vpp, which must be high
  G0_A(15) <= rom2subpage(2) when ( SW(1 downto 0) = "11" ) else '1';
  -- 27512 and 27256 have A14, others have /PGM, which must be high
  G0_A(14) <= rom2subpage(1) when ( SW(1)          = '1'  ) else '1';
  -- 27512, 27256 and 27128 have A13, 2764 is NC so we can always pass A13
  G0_A(13) <= rom2subpage(0);
  -- all have the lower address bits
  G0_A(12) <= A(12);
  G1_A     <= A(11 downto 0);

  -- accesses to DART
  dart_cs <= '1' when ( IORQ_n = '0' and A(7 downto 2) = "000011" ) else '0';

  -- write to SD card data output register, and trigger sending
  sd_command    <= '1' when ( WR_n = '0' and IORQ_n = '0' and A(7 downto 0) = x"d6" ) else '0';
  sd_command_ff <= '1' when ( RD_n = '0' and IORQ_n = '0' and A(7 downto 0) = x"d7" ) else '0';

  -- IO writes, and side effects of reads
  process ( clk_cpu, RESET_n )
  begin
    if RESET_n = '0' then
      host_vram_addr     <= "00000000000000";
      host_vram_we       <= '0';
      host_vram_addr_inc <= '0';
      vdp_latched        <= '0';
      vdp_reg_we         <= '0';
      sd_sel             <= '0';        -- deselect SD card
      iobyte             <= x"8f";      -- RELCPMH=1, RAM page 15
      page1              <= "00000000"; -- backdoor page register 1
      page2              <= "00000000"; -- backdoor page register 2
      pot                <= "00000000";
      otstb_n            <= '1';
      strobe_n           <= '1';
      rom2subpage        <= "000";
		spec_extras        <= '0';
    elsif rising_edge(clk_cpu) then
      host_cell_addr     <= host_cell_addr;
      host_cell_write    <= host_cell_write;
      host_cell_ascm     <= host_cell_ascm;
      host_cell_atrm     <= host_cell_atrm;
      host_cell_we_atr   <= '0';
      host_cell_we_asc   <= '0';
      host_cell_d_atr    <= host_cell_d_atr;
      host_cell_d_asc    <= host_cell_d_asc;
      crtc_reg           <= crtc_reg;
      crtc_base          <= crtc_base;
      crtc_cursor        <= crtc_cursor;
      crtc_cursor_vis    <= crtc_cursor_vis;
      crtc_mode          <= crtc_mode;
      iobyte             <= iobyte;
      drive              <= drive;
      page1              <= page1;
      page2              <= page2;
      pot                <= pot;
      otstb_n            <= '1';
      strobe_n           <= strobe_n;
      rom2subpage        <= rom2subpage;
      host_vram_we       <= '0';
      if host_vram_addr_inc = '1' then
        host_vram_addr <= host_vram_addr+1;
      end if;
      host_vram_addr_inc <= '0';
      vdp_latched        <= vdp_latched;
      vdp_reg_we         <= '0';
      if sd_temp /= "00000000000000000000000000" then
        sd_temp <= sd_temp-1;
      end if;
      if WR_n = '0' and IORQ_n = '0' then
        case A(7 downto 0) is
          when x"00" =>
            -- set the IOBYTE
            iobyte <= DO;
          when x"01" =>
            -- VDP data
            -- present data to VRAM
            -- on next clock it'll be latched
            host_vram_d        <= DO;
            host_vram_we       <= '1';
            host_vram_addr_inc <= '1';
            vdp_latched        <= '0';
          when x"02" =>
            -- VDP control
            if vdp_latched = '0' then
              host_vram_addr(7 downto 0) <= DO;
              vdp_latched <= '1';
            else
              case DO(7 downto 6) is
                when "00" | "01" =>
                  -- set up for reading or writing
                  host_vram_addr(13 downto 8) <= DO(5 downto 0);
                when "10" =>
                  -- write VDP register
                  vdp_reg_number <= DO(2 downto 0);
                  vdp_reg_value  <= host_vram_addr(7 downto 0);
                  vdp_reg_we     <= '1';
                when others =>
              end case;
              vdp_latched <= '0';
            end if;
          when x"04" =>
            prd <= DO;
          when x"05" =>
            -- set keyboard drive
            drive <= DO;
          when x"06" =>
            -- data is latched
            -- sound chip notices when port 3 is read
            sound_reg_value <= DO;
          when x"07" =>
            -- write to port 7
            pot     <= DO;
            otstb_n <= '0';
          when x"30" =>
            -- set address low and copy to screen
            -- present address and data to cell memory
            -- on next clock it'll be latched
            host_cell_addr(7 downto 0) <= DO;
            host_cell_we_atr <= host_cell_write and host_cell_atrm;
            host_cell_we_asc <= host_cell_write and host_cell_ascm;
          when x"31" =>
            -- set address high, including write flag and masks
            host_cell_addr(11 downto 8) <= DO(3 downto 0);
            host_cell_write <= DO(7);
            host_cell_ascm  <= DO(6);
            host_cell_atrm  <= DO(5);
          when x"32" =>
            -- present ascd to cell memory
            host_cell_d_asc <= DO;
          when x"33" =>
            -- present atrd to cell memory
            host_cell_d_atr <= DO;
          when x"38" =>
            -- select CRTC register
            crtc_reg <= DO(4 downto 0);
          when x"39" =>
            -- write to selected CRTC register
            -- we only support a subset of these
            case crtc_reg is
              when "01010" =>
                -- We honor the cursor visible bit,
                -- but we don't honor the flash rate bit
                crtc_cursor_vis <= DO(6);
              when "01100" =>
                crtc_base(11 downto 8) <= DO(3 downto 0);
              when "01101" =>
                crtc_base( 7 downto 0) <= DO;
              when "01110" =>
                crtc_cursor(11 downto 8) <= DO(3 downto 0);
              when "01111" =>
                crtc_cursor( 7 downto 0) <= DO;
              when "11111" =>
                -- special register to control mode
                crtc_mode <= DO(0);
              when others =>
                -- register write goes into the ether
            end case;
          when x"c0" =>
            digit1 <= DO(7 downto 4);
            digit0 <= DO(3 downto 0);
          when x"c1" =>
            digit3 <= DO(7 downto 4);
            digit2 <= DO(3 downto 0);
          when x"c4" =>
            ledg_int <= DO;
          when x"d0" =>
            page1 <= DO;
          when x"d1" =>
            page2 <= DO;
          when x"d4" =>
            -- SD control
            sd_sel     <= DO(7);
            sd_divider <= DO(5 downto 0);
          when x"d6" | x"d7" =>
            sd_temp    <= (others => '1');
          when x"da" =>
            spec_extras   <= DO(7);
            accel_enabled <= DO(6);
          when others =>
            -- nothing
        end case;
      elsif RD_n = '0' and IORQ_n = '0' then
        case A(7 downto 0) is
          when x"00" =>
            strobe_n <= '0';
          when x"01" =>
            -- VDP data
            host_vram_addr_inc <= '1';
            vdp_latched        <= '0';
          when x"02" =>
            -- VDP status
            vdp_latched <= '0';
          when x"04" =>
            strobe_n <= '1';
          when others =>
            -- nothing
        end case;
      elsif WR_n = '0' and MREQ_n = '0' and A(15 downto 13) = "000" and iobyte(7) = '0' then
        rom2subpage <= DO(2 downto 0);
      end if;
      if G0_INSTB = '1' then
        pin <= G0_PIN;
      end if;

      -- toggling serial
      dart_key2_prev <= KEY(2);
      if dart_key2_prev = '1' and KEY(2) = '0' then
        dart_ch <= not dart_ch;
      end if;

    end if;

  end process;

  -- Ensure VDP knows of CPU intent to read status
  vdp_reg_re <= '1' when ( RD_n = '0' and IORQ_n = '0' and A(7 downto 0) = x"02" ) else '0';

  -- Ensure sound chip knows of write register
  sound_reg_we <= '1' when ( RD_n = '0' and IORQ_n = '0' and A(7 downto 0) = x"03" ) else '0';

  -- Ensure CTC knows of CPU intent to write register
  ctc_we <= '1' when ( WR_n = '0' and IORQ_n = '0' and A(7 downto 2) = "000010" ) else '0';

  -- Ensure CTC knows when CPU reads the vector
  ctc_re_vector <= '1' when ( M1_n = '0' and IORQ_n = '0' ) else '0';

  -- input to Z80
  -- combinatorial process rather than deep when-else
  -- process(all) -- supported in VHDL 2008, but we're using 1993
  -- simply ignore the warnings about all the other inputs
  process(M1_n, IORQ_n, MREQ_n, RD_n, oe, se, fe, ere, A)
  begin
    if MREQ_n = '0' then
      -- memory read
      if oe = '1' then
        DI <= rom_q;
      elsif se = '1' then --and SRAM_OE_N = '0' then
        DI <= SRAM_Q;--SRAM_DQ(15 downto 8);
      elsif fe = '1' then
        DI <= FL_DQ;
		elsif spec_DO_valid = '1'then 
		  DI <= spec_DO;
      elsif ere = '1' then
        DI <= G1_D;
      else
        DI <= "XXXXXXXX";
      end if;
    elsif IORQ_n = '0' then
      if M1_n = '0' then
        -- interrupt vector
        DI <= ctc_vector & "0";
      else
        -- I/O reads
        case A(7 downto 0) is
          when x"01" => DI <= host_vram_q; 
          when x"02" => DI <= vdp_status;
          when x"03" => DI <= x"03";
          when x"04" => DI <= "0000" & G0_SLCT & G0_PE & G0_ERROR_n & G0_BUSY;
          when x"05" => DI <= sense5;
          when x"06" => DI <= sense6;
          when x"07" => DI <= pin;
          when x"08"|x"09"|x"0a"|x"0b" => DI <= ctc_data_read;
          when x"0c" => DI <= dart_data_a;
          when x"0d" => DI <= dart_data_b;
          when x"0e" => DI <= dart_stat_a;
          when x"0f" => DI <= dart_stat_b;
          when x"32" => DI <= host_cell_q_asc;
          when x"33" => DI <= host_cell_q_atr;
          when x"38" => DI <= "000" & crtc_reg;
          when x"39" =>
            case crtc_reg is
              when "01010" => DI <= "0" & crtc_cursor_vis & "000000";
              when "01100" => DI <= "0000" & crtc_base(11 downto 8);
              when "01101" => DI <= crtc_base( 7 downto 0);
              when "01110" => DI <= "0000" & crtc_cursor(11 downto 8);
              when "01111" => DI <= crtc_cursor( 7 downto 0);
              when others => DI <= "XXXXXXXX";
            end case;
          when x"a0"|x"a1"|x"a2"|x"a3"|x"a4"|x"a5" => DI <= accel_DO;
          when x"c0" => DI <= digit1 & digit0;
          when x"c1" => DI <= digit3 & digit2;
          when x"c4" => DI <= ledg_int;
          when x"c5" => DI <= "11111" & KEY(2 downto 0);
          when x"c7" => DI <= extra_keys(11 downto 4);
          when x"d0" => DI <= page1;
          when x"d1" => DI <= page2;
          when x"d4" => DI <= sd_ready & sd_temp(24) & "000000";
          when x"d6"|x"d7" => DI <= sd_data;
          when x"d8" => DI <= "00000" & div_cpu;
			 when x"d9" => DI <= "00000000"; --rememorizer
          when x"da" => DI <= spec_extras & accel_enabled & "000000"; -- speculator
          when others => DI <= "XXXXXXXX";
        end case;
      end if;
    else
      DI <= "XXXXXXXX";
    end if;
  end process;

  -- 80 column
  cursor_r <= '1';
  cursor_g <= '1';
  cursor_b <= '1';

  -- green LEDs reflect processor choice
  LEDG <= ledg_int;

  -- flicker light if SD card recently spoken to
  -- 25 bit counter, 2**25/25000000 = 1.34s of flickering, and the SD Card
  -- driver should consider drive warm for the first half of that
  --LED <= '0' when ( sd_temp = "00000000000000000000000000" ) else sd_temp(19);
  --AUX(0) <= key_ready;
  --AUX(1) <= key_stroke;
  --AUX(2) <= sense5(3);
  
  -- VGA monitor displays either 80 column or VDP
  VGA_R  <= vdp_r      when ( SW(6) = '1' ) else mon_r&mon_r&mon_r&mon_r;
  VGA_G  <= vdp_g      when ( SW(6) = '1' ) else mon_g&mon_g&mon_g&mon_g;
  VGA_B  <= vdp_b      when ( SW(6) = '1' ) else mon_b&mon_b&mon_b&mon_b;
  VGA_HS <= vdp_hsync  when ( SW(6) = '1' ) else mon_hsync;
  VGA_VS <= vdp_vsync  when ( SW(6) = '1' ) else mon_vsync;
  VGA_HB <= vdp_hblank when ( SW(6) = '1' ) else mon_hblank;
  VGA_VB <= vdp_vblank when ( SW(6) = '1' ) else mon_vblank;


  
  -- 2nd VGA monitor displays the opposite
  G1_R   <= vdp_r     when ( SW(6) = '0' ) else mon_r&mon_r&mon_r&mon_r;
  G1_G   <= vdp_g     when ( SW(6) = '0' ) else mon_g&mon_g&mon_g&mon_g;
  G1_B   <= vdp_b     when ( SW(6) = '0' ) else mon_b&mon_b&mon_b&mon_b;
  G1_HS  <= vdp_hsync when ( SW(6) = '0' ) else mon_hsync;
  G1_VS  <= vdp_vsync when ( SW(6) = '0' ) else mon_vsync;

  -- so we can see video choices
  LEDR(6 downto 4) <= SW(6 downto 4);

  -- control the volume of the sound
  sound_to_codec <= (others => '0')
    when ( SW(3 downto 2) = "00" )
  else sound_output(7)&sound_output(7)&sound_output
    when ( SW(3 downto 2) = "01" )
  else sound_output(7)&sound_output&"0"
    when ( SW(3 downto 2) = "10" )
  else sound_output&"00";

  -- so we can see volume choices
  LEDR(3 downto 2) <= SW(3 downto 2);

  -- drive centronics
  G0_PRD <= prd;
  G0_STROBE_n <= strobe_n;

  -- drive port 7
  G0_POT     <= pot;
  G0_OTSTB_n <= otstb_n;

  -- connect serial port
  dart_rx_a <= UART_RXD when ( dart_ch = '0' ) else '1';
  dart_rx_b <= UART_RXD when ( dart_ch = '1' ) else '1';
  UART_TXD <= dart_tx_a when ( dart_ch = '0' ) else dart_tx_b;
  LEDR(1) <= dart_ch;

  -- LED on Daughter board shows if ROM 2 activated
  G0_LED <= SW(1) or SW(0);

end behavior;
