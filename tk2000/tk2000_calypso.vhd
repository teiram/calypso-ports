--
-- tk2000_calypso.vhd
--
-- Apple II+ toplevel for the Calypso board
-- Based on:
-- https://github.com/wsoltys/mist_apple2
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library mist;
use mist.mist.ALL;
use work.calypso_version.ALL;

entity tk2000_calypso is
port (
    -- Clocks
    
    CLK12M    : in std_logic; -- 27 MHz

    -- SDRAM
    SDRAM_nCS : out std_logic; -- Chip Select
    SDRAM_DQ : inout std_logic_vector(15 downto 0); -- SDRAM Data bus 16 Bits
    SDRAM_A : out std_logic_vector(12 downto 0); -- SDRAM Address bus 13 Bits
    SDRAM_DQMH : out std_logic; -- SDRAM High Data Mask
    SDRAM_DQML : out std_logic; -- SDRAM Low-byte Data Mask
    SDRAM_nWE : out std_logic; -- SDRAM Write Enable
    SDRAM_nCAS : out std_logic; -- SDRAM Column Address Strobe
    SDRAM_nRAS : out std_logic; -- SDRAM Row Address Strobe
    SDRAM_BA : out std_logic_vector(1 downto 0); -- SDRAM Bank Address
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
    
    -- Audio
    I2S_BCK    : out   std_logic;
    I2S_LRCK   : out   std_logic;
    I2S_DATA   : out   std_logic;
    
    -- UART


    -- LEDS
    LED : out std_logic_vector(7 downto 0)

);

end tk2000_calypso;

architecture datapath of tk2000_calypso is

  constant CONF_STR : string :=
   "TK2000;;"&
   "S0U,NIB,Load Disk 0;"&
   "S1U,NIB,Load Disk 1;"&
   "ODE,Write Protect,None,Disk 0,Disk 1, Disk 0&1;"&
   "O34,Monitor,Color,B&W,Green,Amber;"&
--   "OBC,Scanlines,Off,25%,50%,75%;"&
   "O5,Color Type,TK2000, Apple2p;"&
   "O6,Apple2p Joysticks,Normal,Swapped;"&
   "O7,Saturn 128K,Off,On;"&
   "T9,Cold reset;"&
    "V,"&BUILD_VERSION&"-"&BUILD_DATE;


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

  component mist_sd_card
    port (
            sd_lba         : out std_logic_vector(31 downto 0);
            sd_rd          : out std_logic;
            sd_wr          : out std_logic;
            sd_ack         : in  std_logic;

            sd_buff_addr   : in  std_logic_vector(8 downto 0);
            sd_buff_dout   : in  std_logic_vector(7 downto 0);
            sd_buff_din    : out std_logic_vector(7 downto 0);
            sd_buff_wr     : in  std_logic;

            ram_addr       : in  unsigned(12 downto 0);
            ram_di         : in  unsigned( 7 downto 0);
            ram_do         : out unsigned( 7 downto 0);
            ram_we         : in  std_logic;

            change         : in  std_logic;                     -- Force reload as disk may have changed
            mount          : in  std_logic;                     -- umount(0)/mount(1)
            track          : in  std_logic_vector(5 downto 0);  -- Track number (0-34)
            busy           : out std_logic;
            ready          : out std_logic;
            active         : in  std_logic;

            clk            : in  std_logic;     -- System clock
            reset          : in  std_logic
        );
  end component mist_sd_card;

  component sdram is
    port( sd_data : inout std_logic_vector(15 downto 0);
          sd_addr : out std_logic_vector(12 downto 0);
          sd_dqm : out std_logic_vector(1 downto 0);
          sd_ba : out std_logic_vector(1 downto 0);
          sd_cs : out std_logic;
          sd_we : out std_logic;
          sd_ras : out std_logic;
          sd_cas : out std_logic;
          init : in std_logic;
          clk : in std_logic;
          clkref : in std_logic;
          din : in std_logic_vector(7 downto 0);
          dout : out std_logic_vector(7 downto 0);
          addr : in std_logic_vector(24 downto 0);
          we : in std_logic
    );
  end component;

  component pll is
    port(
        inclk0: in std_logic;
        c0: out std_logic;
        c1: out std_logic;
        locked: out std_logic
    );
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

  signal CLK_28M, CLK_14M, CLK_2M, PHASE_ZERO, PHASE_ONE, PHASE_TWO, Q3, CLK_12k : std_logic;
  signal IO_SELECT, DEVICE_SELECT : std_logic_vector(7 downto 0);
  signal IO_STROBE : std_logic; 
  signal TAPE_INPUT, TAPE_OUTPUT, TAPE_MOTOR : std_logic;
  signal LPT_BUSY, LPT_STB : std_logic;
  signal ADDR : unsigned(15 downto 0);
  signal D, PD: unsigned(7 downto 0);
  signal DISK_DO: unsigned(7 downto 0);
  signal cpu_we : std_logic;
  signal psg_irq_n, psg_nmi_n : std_logic;

  signal we_ram : std_logic;
  signal VIDEO, HSYNC_N, VSYNC_N, HBL, VBL, LD194, COLOR_TYPE : std_logic;
  signal COLOR_LINE : std_logic;
  signal COLOR_LINE_CONTROL : std_logic;
  signal SCREEN_MODE : std_logic_vector(1 downto 0);
  signal GAMEPORT : std_logic_vector(7 downto 0);
  signal cpu_pc : unsigned(15 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr : std_logic;
  signal no_csync : std_logic;

  signal flash_clk : unsigned(22 downto 0) := (others => '0');
  signal power_on_reset : std_logic := '1';
  signal reset : std_logic;

  signal D1_ACTIVE, D2_ACTIVE : std_logic;
  signal TRACK1_RAM_BUSY : std_logic;
  signal TRACK1_RAM_ADDR : unsigned(12 downto 0);
  signal TRACK1_RAM_DI : unsigned(7 downto 0);
  signal TRACK1_RAM_DO : unsigned(7 downto 0);
  signal TRACK1_RAM_WE : std_logic;
  signal TRACK1 : unsigned(5 downto 0);
  signal TRACK2_RAM_BUSY : std_logic;
  signal TRACK2_RAM_ADDR : unsigned(12 downto 0);
  signal TRACK2_RAM_DI : unsigned(7 downto 0);
  signal TRACK2_RAM_DO : unsigned(7 downto 0);
  signal TRACK2_RAM_WE : std_logic;
  signal TRACK2 : unsigned(5 downto 0);
  signal DISK_READY : std_logic_vector(1 downto 0);
  signal disk_change : std_logic_vector(1 downto 0);
  signal disk_size : std_logic_vector(63 downto 0);
  signal disk_mount : std_logic;

  signal downl : std_logic := '0';
  signal io_index : std_logic_vector(4 downto 0);
  signal size : std_logic_vector(24 downto 0) := (others=>'0');
  signal a_ram: unsigned(17 downto 0);
  signal r : unsigned(7 downto 0);
  signal g : unsigned(7 downto 0);
  signal b : unsigned(7 downto 0);
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal sd_we : std_logic;
  signal sd_oe : std_logic;
  signal sd_addr : std_logic_vector(18 downto 0);
  signal sd_di : std_logic_vector(7 downto 0);
  signal sd_do : std_logic_vector(7 downto 0);
  signal io_we : std_logic;
  signal io_addr : std_logic_vector(24 downto 0);
  signal io_do : std_logic_vector(7 downto 0);
  signal io_ram_we : std_logic;
  signal io_ram_d : std_logic_vector(7 downto 0);
  signal io_ram_addr : std_logic_vector(18 downto 0);

  -- sdram 
  signal ram_we : std_logic;
  signal ram_di : std_logic_vector(7 downto 0);
  signal ram_addr : std_logic_vector(24 downto 0);
  signal DO : std_logic_vector(7 downto 0);
  
  -- joysticks apple2p
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy        : std_logic_vector(5 downto 0);
  signal joy0       : std_logic_vector(31 downto 0);
  signal joy1       : std_logic_vector(31 downto 0);
  signal joy_an0    : std_logic_vector(31 downto 0);
  signal joy_an1    : std_logic_vector(31 downto 0);
  signal joy_an     : std_logic_vector(15 downto 0);
        
  -- status signals
  signal status     : std_logic_vector(63 downto 0);
  -- status(0)    reset_warm
  -- status(3-4)  monitor ->  00:Color, 01:B&W, 10:Green, 11:Amber
  -- status(5)    Color Type -> 0:Apple2, 1:TK2000
  -- status(6)    joystick swap
  -- status(7)    saturn 128k enabled
  -- status(9)    reset_cold
  -- status(11-12) scanlines -> 00:Off, 01:25%, 02:50%, 03:75%
  -- status(13-14) write protect

  -- keyboard apple2p 
  -- signal ps2Clk     : std_logic;
  -- signal ps2Data    : std_logic;
  signal K : unsigned(7 downto 0);
  -- signal read_key : std_logic;

  -- keyboard tk2000
  signal ps2_clk_io     : std_logic := 'Z';
  signal ps2_data_io    : std_logic := 'Z';
  signal ps2_clk_io_i   : std_logic := 'Z';
  signal ps2_data_io_i  : std_logic := 'Z';
  signal div            : std_logic_vector(2 downto 0) := "000";
  signal kbd_ctrl       : std_logic;
  signal kbd_rows       : unsigned(7 downto 0);
  signal kbd_cols       : unsigned(5 downto 0);
  signal FKeys          : unsigned(12 downto 1);
      
  -- audio
  signal audio       : std_logic;
  signal psg_audio_l : unsigned(9 downto 0) := ("0000000000");
  signal psg_audio_r : unsigned(9 downto 0) := ("0000000000");

  -- write protect
  signal st_wp      : std_logic_vector(1 downto 0);

  -- signals to connect sd card emulation with io controller
  signal sd_lba:  std_logic_vector(31 downto 0);
  signal sd_rd:   std_logic_vector(1 downto 0) := (others => '0');
  signal sd_wr:   std_logic_vector(1 downto 0) := (others => '0');
  signal sd_ack:  std_logic_vector(1 downto 0);

  signal SD_LBA1:  std_logic_vector(31 downto 0);
  signal SD_LBA2:  std_logic_vector(31 downto 0);
  
  -- data from io controller to sd card emulation
  signal sd_data_in: std_logic_vector(7 downto 0);
  signal sd_data_out: std_logic_vector(7 downto 0);
  signal sd_data_out_strobe:  std_logic;
  signal sd_buff_addr: std_logic_vector(8 downto 0);

  signal SD_DATA_IN1: std_logic_vector(7 downto 0);
  signal SD_DATA_IN2: std_logic_vector(7 downto 0);
  
  -- sd card emulation
  signal sd_cs:	   std_logic;
  signal sd_sck:   std_logic;
  signal sd_sdi:   std_logic;
  signal sd_sdo:   std_logic;
  
  signal pll_locked: std_logic;
  signal sdram_dqm:  std_logic_vector(1 downto 0);
  signal joyx:       std_logic;
  signal joyy:       std_logic;
  signal pdl_strobe: std_logic;

begin

  st_wp <= status(14 downto 13);

  -- In the Apple ][, this was a 555 timer
  power_on : process(CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      reset <= status(0) or power_on_reset;

      if buttons(1)='1' or status(9) = '1' then
        power_on_reset <= '1';
        flash_clk <= (others=>'0');
      else
		  if flash_clk(22) = '1' then
          power_on_reset <= '0';
			end if;
			 
        flash_clk <= flash_clk + 1;
      end if;
    end if;
  end process;

  SDRAM_CLK <= CLK_28M;  
   
  pll_inst : pll 
  port map (
    inclk0 => CLK12M,
    c0     => CLK_28M,
    c1     => CLK_14M,
    locked => pll_locked
  );
 
  -- Paddle buttons
  -- GAMEPORT input bits:
  --  7    6    5    4    3   2   1   0
  -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 pb0
  GAMEPORT <=  "00" & joyy & joyx & "0" & joy(5) & joy(4) & "0";
  
  joy_an <= joy_an0(15 downto 0) when status(6)='0' else joy_an1(15 downto 0);
  joy <= joy0(5 downto 0) when status(6)='0' else joy1(5 downto 0);

  process(CLK_2M, pdl_strobe)
    variable cx, cy : integer range -100 to 5800 := 0;
  begin
    if rising_edge(CLK_2M) then
      if cx > 0 then
        cx := cx -1;
        joyx <= '1';
      else
        joyx <= '0';
      end if;
      if cy > 0 then
        cy := cy -1;
        joyy <= '1';
      else
        joyy <= '0';
      end if;
      if pdl_strobe = '1' then
        cx := 2800+(22*to_integer(signed(joy_an(15 downto 8))));
        cy := 2800+(22*to_integer(signed(joy_an(7 downto 0)))); -- max 5650
        if cx < 0 then
          cx := 0;
        elsif cx >= 5590 then
          cx := 5650;
        end if;
        if cy < 0 then
          cy := 0;
        elsif cy >= 5590 then
          cy := 5650;
        end if;
      end if;
    end if;
  end process;

  COLOR_LINE_CONTROL <= COLOR_LINE and not (status(3) or status(4));  -- Color or B&W mode
  SCREEN_MODE <= status(4 downto 3); -- 00: Color, 01: B&W, 10:Green, 11: Amber
  
  -- sdram interface
  SDRAM_CKE <= '1';
  SDRAM_DQMH <= sdram_dqm(1);
  SDRAM_DQML <= sdram_dqm(0);

  sdram_inst : sdram
    port map( sd_data => SDRAM_DQ,
              sd_addr => SDRAM_A,
              sd_dqm => sdram_dqm,
              sd_cs => SDRAM_nCS,
              sd_ba => SDRAM_BA,
              sd_we => SDRAM_nWE,
              sd_ras => SDRAM_nRAS,
              sd_cas => SDRAM_nCAS,
              clk => CLK_28M,
              clkref => CLK_2M,
              init => not pll_locked,
              din => ram_di,
              addr => ram_addr,
              we => ram_we,
              dout => DO
    );
  
  -- Simulate power up on cold reset to go to the disk boot routine
  ram_we   <= we_ram when status(9) = '0' else '1';
  ram_addr <= "0000000" & std_logic_vector(a_ram) when status(9) = '0' else std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4  
  ram_di   <= std_logic_vector(D) when status(9) = '0' else "00000000";

  PD <= DISK_DO;

  core : entity work.tk2000 port map (
    -- clocks --
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    PHASE_ONE      => PHASE_ONE,
    PHASE_TWO      => PHASE_TWO,
    FLASH_CLK      => flash_clk(22),
   -- cpu -- 
    ADDR           => ADDR,
    ram_addr       => a_ram,
    saturn128k     => status(7),
    D              => D,
    ram_do         => unsigned(DO),
    PD             => PD,
    CPU_WE         => cpu_we,
    ram_we         => we_ram,
    CPU_WAIT       => '0',
    reset          => reset,
    IRQ_N          => '1',
    NMI_N          => '1',
    -- video --
    VIDEO          => VIDEO,
    COLOR_LINE     => COLOR_LINE,
    HSYNC_N        => HSYNC_N,
    VSYNC_N        => VSYNC_N,
    HBL            => HBL,
    VBL            => VBL,
    LD194          => LD194, 
   -- keyboard tk2000 --
    KBD_ROWS    => KBD_ROWS,
    KBD_COLS    => KBD_COLS,    
    KBD_CTRL	=> KBD_CTRL,
   -- keyboard apple 2p --
    K              => K,
   -- read_key       => read_key,  
   -- cassete --
    TAPE_INPUT     => '0',
    TAPE_OUTPUT    => open,
    TAPE_MOTOR     => open,
   -- printer --
    LPT_STB        => open,
    LPT_BUSY	   => '0',
   -- analog joystick --
    GAMEPORT       => GAMEPORT,
    PDL_strobe     => pdl_strobe,
   -- apple2p / tk2000 -- i/o signals --
    IO_SELECT      => IO_SELECT,
    DEVICE_SELECT  => DEVICE_SELECT,
    IO_STROBE      => IO_STROBE,
    ROM_DISABLE    => '0',
   -- speaker --
    speaker        => audio,
   -- debug --
    pcDebugOut     => cpu_pc
    );

  COLOR_TYPE <= status(5); 

  vga : entity work.vga_controller port map (
    CLK_28M    => CLK_28M,
    VIDEO      => VIDEO,
    COLOR_LINE => COLOR_LINE_CONTROL,
    SCREEN_MODE => SCREEN_MODE,
    HBL        => HBL,
    VBL        => VBL,
    LD194      => LD194,
    COLOR_TYPE => not COLOR_TYPE,
    VGA_CLK    => open,
    VGA_HS     => hsync,
    VGA_VS     => vsync,
    VGA_BLANK  => open,
    VGA_R      => r,
    VGA_G      => g,
    VGA_B      => b
    );

  -- keyboard apple2p
  --  keyboard_apple2p : entity work.keyboard_apple2p port map (
  --    PS2_Clk  => ps2Clk,
  --    PS2_Data => ps2Data,
  --    CLK_14M  => CLK_14M,
  --    reset    => reset,
  --    reads    => read_key,
  --    K        => K
  --    );

  -- Keyboard tk2000
  keyboard_tk2000 : entity work.keyboard_tk2000
    generic map (
        clkfreq_g           => 7000 --28000
    )
    port map (
        clock_i             => CLK_14M,
        reset_i             => reset,
        ps2_clk_io          => ps2_clk_io,
        ps2_data_io         => ps2_data_io,
        ps2_clk_io_i        => ps2_clk_io_i,
        ps2_data_io_i       => ps2_data_io_i,
        rows_i              => kbd_rows,
        row_ctrl_i          => kbd_ctrl,
        cols_o              => kbd_cols,
        FKeys_o             => FKeys
     );

  K <= "0" & LPT_BUSY & KBD_COLS;

  disk : entity work.disk_ii port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PHASE_ZERO     => PHASE_ZERO,
    IO_SELECT      => IO_SELECT(1),
    DEVICE_SELECT  => DEVICE_SELECT(1),
    RESET          => reset,
    DISK_READY     => DISK_READY,
    A              => ADDR,
    D_IN           => D,
    D_OUT          => DISK_DO,
    D1_ACTIVE      => D1_ACTIVE,
    D2_ACTIVE      => D2_ACTIVE,
    WP             => st_wp,
    -- track buffer interface for disk 1
    TRACK1         => TRACK1,
    TRACK1_ADDR    => TRACK1_RAM_ADDR,
    TRACK1_DO      => TRACK1_RAM_DO,
    TRACK1_DI      => TRACK1_RAM_DI,
    TRACK1_WE      => TRACK1_RAM_WE,
    TRACK1_BUSY    => TRACK1_RAM_BUSY,
    -- track buffer interface for disk 2
    TRACK2         => TRACK2,
    TRACK2_ADDR    => TRACK2_RAM_ADDR,
    TRACK2_DO      => TRACK2_RAM_DO,
    TRACK2_DI      => TRACK2_RAM_DI,
    TRACK2_WE      => TRACK2_RAM_WE,
    TRACK2_BUSY    => TRACK2_RAM_BUSY
    );

  disk_mount <= '0' when disk_size = x"0000000000000000" else '1';
  sd_lba <= SD_LBA2 when sd_rd(1) = '1' or sd_wr(1) = '1' else SD_LBA1;
  sd_data_in <= SD_DATA_IN2 when sd_ack(1) = '1' else SD_DATA_IN1;
  
  sdcard_interface1: mist_sd_card port map (
    clk          => CLK_14M,
    reset        => reset,

    ram_addr     => TRACK1_RAM_ADDR, -- in unsigned(12 downto 0);
    ram_di       => TRACK1_RAM_DI,   -- in unsigned(7 downto 0);
    ram_do       => TRACK1_RAM_DO,   -- out unsigned(7 downto 0);
    ram_we       => TRACK1_RAM_WE,

    track        => std_logic_vector(TRACK1),
    busy         => TRACK1_RAM_BUSY,
    change       => DISK_CHANGE(0),
    mount        => disk_mount,
    ready        => DISK_READY(0),
    active       => D1_ACTIVE,

    sd_buff_addr => sd_buff_addr,
    sd_buff_dout => sd_data_out,
    sd_buff_din  => SD_DATA_IN1,
    sd_buff_wr   => sd_data_out_strobe,

    sd_lba       => SD_LBA1,
    sd_rd        => sd_rd(0),
    sd_wr        => sd_wr(0),
    sd_ack       => sd_ack(0)
  );

  sdcard_interface2: mist_sd_card port map (
    clk          => CLK_14M,
    reset        => reset,

    ram_addr     => TRACK2_RAM_ADDR, -- in unsigned(12 downto 0);
    ram_di       => TRACK2_RAM_DI,   -- in unsigned(7 downto 0);
    ram_do       => TRACK2_RAM_DO,   -- out unsigned(7 downto 0);
    ram_we       => TRACK2_RAM_WE,

    track        => std_logic_vector(TRACK2),
    busy         => TRACK2_RAM_BUSY,
    change       => DISK_CHANGE(1),
    mount        => disk_mount,
    ready        => DISK_READY(1),
    active       => D2_ACTIVE,

    sd_buff_addr => sd_buff_addr,
    sd_buff_dout => sd_data_out,
    sd_buff_din  => SD_DATA_IN2,
    sd_buff_wr   => sd_data_out_strobe,

    sd_lba       => SD_LBA2,
    sd_rd        => sd_rd(1),
    sd_wr        => sd_wr(1),
    sd_ack       => sd_ack(1)
  );

  LED(0) <= D1_ACTIVE;
  LED(1) <= D2_ACTIVE;

    tk2000_i2s : i2s
        port map (
            clk => clk_28M,
            reset => '0',
            clk_rate => 28000000,
            sclk => I2S_BCK,
            lrclk => I2S_LRCK,
            sdata => I2S_DATA,
            left_chan  => std_logic_vector(psg_audio_l + (audio & "0000000")) & "000000",
            right_chan => std_logic_vector(psg_audio_r + (audio & "0000000")) & "000000"
        );
    
  user_io_inst : user_io
    generic map (
        STRLEN => CONF_STR'length,
        FEATURES => x"00002000"
    )
    port map (
      clk_sys => CLK_14M,
      clk_sd => CLK_14M,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,    
      SPI_MISO => SPI_DO,    
      SPI_MOSI => SPI_DI,       
      conf_str => to_slv(CONF_STR),
      status => status,   
      joystick_0 => joy0,   
      joystick_1 => joy1,
      joystick_analog_0 => joy_an0,
      joystick_analog_1 => joy_an1,
      SWITCHES => switches,
      BUTTONS => buttons,
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      no_csync => no_csync,
      -- connection to io controller
      sd_lba  => sd_lba,
      sd_rd   => sd_rd,
      sd_wr   => sd_wr,
      sd_ack_x => sd_ack,
      sd_ack_conf => open,
      sd_sdhc => '1',
      sd_conf => '0',
      sd_dout => sd_data_out,
      sd_dout_strobe => sd_data_out_strobe,
      sd_din => sd_data_in,
      sd_buff_addr => sd_buff_addr,
      img_mounted => disk_change,
      img_size => disk_size,
      -- ps2_kbd_clk => ps2Clk,
      -- ps2_kbd_data => ps2Data,
      ps2_kbd_clk => ps2_clk_io_i,
      ps2_kbd_data => ps2_data_io_i,
      ps2_kbd_clk_i => ps2_clk_io,
      ps2_kbd_data_i => ps2_data_io
    );

 video_inst: mist_video
    generic map(
        SD_HCNT_WIDTH => 10,
        OUT_COLOR_DEPTH => 4,
        COLOR_DEPTH => 8,
        BIG_OSD => true,
        OSD_AUTO_CE => false
    )
    port map (
      clk_sys => CLK_28M,
      scanlines   => status(12 downto 11),
      ce_divider => "001",
      scandoubler_disable => '1',
      ypbpr => ypbpr,
      no_csync => no_csync,
      rotate => "00",

      SPI_DI => SPI_DI,
      SPI_SCK => SPI_SCK,
      SPI_SS3 => SPI_SS3,

      R => std_logic_vector(r),
      G => std_logic_vector(g),
      B => std_logic_vector(b),
      HSync => hsync,
      VSync => vsync,
      VGA_HS => VGA_HS,
      VGA_VS => VGA_VS,
      VGA_R  => VGA_R,
      VGA_G  => VGA_G,
      VGA_B  => VGA_B
    );

end datapath;
