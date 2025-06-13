library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library mist;
use mist.mist.ALL;

entity MIST_Toplevel is
	generic
	(
		DIRECT_UPLOAD : boolean := true;
		USE_QSPI : boolean := false;
		BIG_OSD : boolean := false;
		HDMI : boolean := false;
		VGA_BITS : integer := 6;
		INTERNAL_VRAM : boolean := false;
		BUILD_DATE : string := "";
        BUILD_VERSION: string := ""
	);
	port
	(
		CLK12M		:	 in std_logic;
		
		LED			: 	out std_logic_vector(7 downto 0);

		UART_TX		:	 out STD_LOGIC;
		UART_RX		:	 in STD_LOGIC;

		SDRAM_DQ		:	 inout std_logic_vector(15 downto 0);
		SDRAM_A	:	 out std_logic_vector(12 downto 0);
		SDRAM_DQMH	:	 out STD_LOGIC;
		SDRAM_DQML	:	 out STD_LOGIC;
		SDRAM_nWE	:	 out STD_LOGIC;
		SDRAM_nCAS	:	 out STD_LOGIC;
		SDRAM_nRAS	:	 out STD_LOGIC;
		SDRAM_nCS	:	 out STD_LOGIC;
		SDRAM_BA		:	 out std_logic_vector(1 downto 0);
		SDRAM_CLK	:	 out STD_LOGIC;
		SDRAM_CKE	:	 out STD_LOGIC;

		SPI_DO	: inout std_logic;
		SPI_DI	: in std_logic;
		SPI_SCK		:	 in STD_LOGIC;
		SPI_SS2		:	 in STD_LOGIC; -- FPGA
		SPI_SS3		:	 in STD_LOGIC; -- OSD
		SPI_SS4		:	 in STD_LOGIC; -- "sniff" mode
		CONF_DATA0  : in std_logic; -- SPI_SS for user_io

		QCSn : in std_logic;
		QSCK : in std_logic;
		QDAT : in std_logic_vector(3 downto 0);

		VGA_HS		:	buffer STD_LOGIC;
		VGA_VS		:	buffer STD_LOGIC;
		VGA_R		:	out std_logic_vector(VGA_BITS-1 downto 0);
		VGA_G		:	out std_logic_vector(VGA_BITS-1 downto 0);
		VGA_B		:	out std_logic_vector(VGA_BITS-1 downto 0);
   -- HDMI
		HDMI_R     : out   std_logic_vector(7 downto 0) := (others => '0');
		HDMI_G     : out   std_logic_vector(7 downto 0) := (others => '0');
		HDMI_B     : out   std_logic_vector(7 downto 0) := (others => '0');
		HDMI_HS    : out   std_logic := '0';
		HDMI_VS    : out   std_logic := '0';
		HDMI_DE    : out   std_logic := '0';
		HDMI_PCLK  : out   std_logic := '0';
		HDMI_SCL   : inout std_logic;
		HDMI_SDA   : inout std_logic;

		AUDIO_L : out std_logic;
		AUDIO_R : out std_logic;

		I2S_BCK    : out   std_logic;
		I2S_LRCK   : out   std_logic;
		I2S_DATA   : out   std_logic;
		SPDIF_O    : out   std_logic
	);
END entity;

architecture rtl of MIST_Toplevel is

signal reset_n : std_logic;
signal reset_d : std_logic;
signal pll_locked : std_logic;
signal MCLK      : std_logic;
signal memclk      : std_logic;

signal audiol : std_logic_vector(15 downto 0);
signal audior : std_logic_vector(15 downto 0);
alias audiol_sign : std_logic is audiol(15);
alias audior_sign : std_logic is audior(15);
alias audiol_adj : std_logic is audiol(14);
alias audior_adj : std_logic is audior(14);
signal audiol_clamp : std_logic_vector(14 downto 0);
signal audior_clamp : std_logic_vector(14 downto 0);

signal gen_red    : std_logic_vector(3 downto 0);
signal gen_green  : std_logic_vector(3 downto 0);
signal gen_blue   : std_logic_vector(3 downto 0);
signal gen_hs     : std_logic;
signal gen_vs     : std_logic;
signal gen_hbl    : std_logic;
signal gen_vbl    : std_logic;
signal gen_border : std_logic;
signal gen_ce_pix : std_logic;

signal i2c_start : std_logic;
signal i2c_read : std_logic;
signal i2c_addr : std_logic_vector(6 downto 0);
signal i2c_subaddr : std_logic_vector(7 downto 0);
signal i2c_wdata : std_logic_vector(7 downto 0);
signal i2c_rdata : std_logic_vector(7 downto 0);
signal i2c_end : std_logic;
signal i2c_ack : std_logic;

signal red_out    : std_logic_vector(3 downto 0);
signal green_out  : std_logic_vector(3 downto 0);
signal blue_out   : std_logic_vector(3 downto 0);

-- controllers
signal DINA       : std_logic_vector(7 downto 0);
signal DOUTA      : std_logic_vector(7 downto 0);
signal OEA        : std_logic_vector(7 downto 0);
signal DINB       : std_logic_vector(7 downto 0);
signal DOUTB      : std_logic_vector(7 downto 0);
signal OEB        : std_logic_vector(7 downto 0);
signal DOUT_CTRLA : std_logic_vector(7 downto 0);
signal DOUT_CTRLB : std_logic_vector(7 downto 0);
signal DOUT_CTRLC : std_logic_vector(7 downto 0);
signal DOUT_CTRLD : std_logic_vector(7 downto 0);
signal DAT_CTRLA  : std_logic_vector(7 downto 0);
signal DAT_CTRLB  : std_logic_vector(7 downto 0);
signal DAT_CTRLC  : std_logic_vector(7 downto 0);
signal DAT_CTRLD  : std_logic_vector(7 downto 0);
signal OE_CTRLA   : std_logic_vector(7 downto 0);
signal OE_CTRLB   : std_logic_vector(7 downto 0);
signal OE_CTRLC   : std_logic_vector(7 downto 0);
signal OE_CTRLD   : std_logic_vector(7 downto 0);
signal JCART_TH   : std_logic;
signal JCART_DO   : std_logic_vector(15 downto 0);

signal DOUT_4WAY1 : std_logic_vector(7 downto 0);
signal DOUT_4WAY2 : std_logic_vector(7 downto 0);

signal JOY_SWAP   : std_logic;
signal JOY_Y_SWAP : std_logic;
signal JOY_1      : std_logic_vector(11 downto 0);
signal JOY_2      : std_logic_vector(11 downto 0);
signal JOY_3      : std_logic_vector(11 downto 0);
signal JOY_4      : std_logic_vector(11 downto 0);
signal JOY_3BUT   : std_logic;
signal MSEL       : std_logic_vector(1 downto 0);
signal MULTITAP   : std_logic_vector(1 downto 0);
signal TEAMPLAY   : std_logic;
signal EA_MULTITAP: std_logic;
signal JCART      : std_logic;
signal LG_SEL     : std_logic_vector(1 downto 0);
signal LG_TARGET  : std_logic;
signal LG_SENSOR  : std_logic;
signal LG_A       : std_logic;
signal LG_B       : std_logic;
signal LG_C       : std_logic;
signal LG_START   : std_logic;
signal LG_TARGET2 : std_logic;
signal LG_SENSOR2 : std_logic;
signal LG_A2      : std_logic;
signal LG_START2  : std_logic;
signal LG1_CH     : std_logic;
signal LG2_CH     : std_logic;
-- user_io
signal buttons: std_logic_vector(1 downto 0);
signal status:  std_logic_vector(63 downto 0) := (others => '0');
signal joya: std_logic_vector(31 downto 0);
signal joyb: std_logic_vector(31 downto 0);
signal joyc: std_logic_vector(31 downto 0);
signal joyd: std_logic_vector(31 downto 0);
signal ypbpr: std_logic;
signal scandoubler_disable: std_logic;
signal no_csync : std_logic;
signal mouse_x: signed(8 downto 0);
signal mouse_y: signed(8 downto 0);
signal mouse_flags: std_logic_vector(7 downto 0);
signal mouse_strobe: std_logic;
signal mouse_idx: std_logic;

-- sd io
signal sd_lba:  unsigned(31 downto 0);
signal sd_rd:   std_logic_vector(1 downto 0) := "00";
signal sd_wr:   std_logic_vector(1 downto 0) := "00";
signal sd_ack:  std_logic;
signal sd_ackD:  std_logic;
signal sd_conf: std_logic;
signal sd_sdhc: std_logic;
signal sd_din:  std_logic_vector(7 downto 0);
signal sd_din_strobe:  std_logic;
signal sd_dout: std_logic_vector(7 downto 0);
signal sd_dout_strobe:  std_logic;
signal sd_buff_addr: std_logic_vector(8 downto 0);
signal img_mounted  : std_logic_vector(1 downto 0);
signal img_mountedD : std_logic;
signal img_size : std_logic_vector(63 downto 0);

-- backup ram controller
signal bk_state : std_logic := '0';
signal bk_ena   : std_logic := '0';
signal bk_load  : std_logic := '0';
signal bk_loadD : std_logic := '0';
signal bk_saveD : std_logic := '0';

-- data_io
signal downloading      : std_logic;
signal data_io_wr       : std_logic;
signal data_io_clkref   : std_logic;
signal data_io_d        : std_logic_vector(15 downto 0);
signal downloadingD     : std_logic;
signal downloadingD_MCLK: std_logic;
signal d_state          : std_logic_vector(1 downto 0);

-- external controller signals
signal ext_reset_n      : std_logic_vector(15 downto 0) := x"FFFF";
signal ext_bootdone     : std_logic := '0';
signal ext_data         : std_logic_vector(15 downto 0);
signal ext_data_req     : std_logic;
signal ext_data_ack     : std_logic := '0';
signal ext_sw           : std_logic_vector( 15 downto 0); --DIP switches
signal core_led         : std_logic;

function bool_to_sl(X:boolean) return std_logic is
begin
	if X then return '1'; else return '0'; end if;
end function;

function SEP return string is
begin
        if BIG_OSD then return "-;"; else return ""; end if;
end function;

constant CONF_DBG_STR : string := "";
--constant CONF_DBG_STR : string :=
--    "O3,VRAM Speed,Slow,Fast;"&
--    "O4,FM Sound,Enable,Disable;"&
--    "O5,PSG Sound,Enable,Disable;";

constant CONF_STR : string :=
    "MEGADRIVE;BINGENMD ;"&
    "S,SAV,Mount;"&
    "TE,Write Save RAM;"&
    SEP&
    "P1,Video & Audio;"&
    "P2,Controls;"&
    "P3,System;"&
    "P1OBC,Scanlines,Off,25%,50%,75%;"&
    "P1OH,PCM HiFi sound,Disable,Enable;"&
    "P1OJ,Border,Disable,Enable;"&
    "P1OK,Blending,Disable,Enable;"&
    "P1OL,CRAM dots,Disable,Enable;"&
    "P2O6,Joystick swap,Off,On;"&
    "P2O9,Swap Y axis,Off,On;"&
    "P2OA,Only 3 buttons,Off,On;"&
    "P2OMN,Lightgun,Off,Menacer,Justifier 1P,Justifier 2P;"&
    "P2OFG,Mouse,Off,Port 1,Port 2;"&
    "P2OOP,Multitap,Off,Sega Team Player,EA 4 Way Play,J-Cart;"&
    "P3O78,Region,Auto,EU,JP,US;"&
    "P3OD,Fake EEPROM,Off,On;"&
    "P3OI,CPU Turbo,Off,On;"&
    SEP&
    CONF_DBG_STR&
    "T0,Reset;"&
    "V,"&BUILD_VERSION&"-"&BUILD_DATE;

-- convert string to std_logic_vector to be given to user_io
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

-- Sigma Delta audio
COMPONENT hybrid_pwm_sd_2ndorder
	PORT (
		clk : in std_logic;
		reset_n : in std_logic;
		d_l : in std_logic_vector(15 downto 0);
		q_l : out std_logic;
		d_r : in std_logic_vector(15 downto 0);
		q_r : out std_logic
);
END COMPONENT;

-- Sigma Delta audio
COMPONENT hybrid_pwm_sd
	PORT
	(
		clk		:	 IN STD_LOGIC;
		n_reset		:	 IN STD_LOGIC;
		din		:	 IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		dout		:	 OUT STD_LOGIC
	);
END COMPONENT;

component data_io
    generic ( ROM_DIRECT_UPLOAD : boolean := false;
              USE_QSPI : boolean := false;
              DOUT_16 : boolean := true
        );
    port (  clk_sys        : in std_logic;
            clkref_n       : in std_logic;
            ioctl_wr       : out std_logic;
            ioctl_addr     : out std_logic_vector(24 downto 0);
            ioctl_dout     : out std_logic_vector(15 downto 0);
            ioctl_download : out std_logic;
            ioctl_index    : out std_logic_vector(7 downto 0);

            SPI_SCK        : in std_logic;
            SPI_SS2        : in std_logic;
            SPI_SS4        : in std_logic;
            SPI_DI         : in std_logic;
            SPI_DO         : inout std_logic;  -- yes, sdo used as input

            QCSn           : in std_logic := '1';
            QSCK           : in std_logic := '0';
            QDAT           : in std_logic_vector(3 downto 0) := "0000"
        );
    end component data_io;

component i2s
    generic (
        I2S_Freq   : integer := 48000;
        AUDIO_DW   : integer := 16
    );
    port
    (
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

component spdif port
    (
        clk_i      : in    std_logic;
        rst_i      : in    std_logic;
        clk_rate_i : in    integer;
        spdif_o    : out   std_logic;
        sample_i   : in    std_logic_vector(31 downto 0)
    );
end component spdif;

begin

LED(0) <= not core_led and not downloading and not bk_ena;

U00 : entity work.pll
    port map(
        inclk0 => CLK12M,	-- 12 MHz external
        c0     => MCLK,			-- 54 MHz internal
        c1     => memclk,			-- 108 Mhz
        c2     => SDRAM_CLK,		-- 108 Mhz external
        locked => pll_locked
    );

--SDRAM_A(12)<='0';

-- reset from IO controller
-- status bit 0 is always triggered by the io controller on its own reset
-- button 1 is the core specfic button in the mists front
-- reset <= '0' when status(0)='1' or buttons(1)='1' or pll_locked='0' else '1';

process(MCLK)
begin
	if rising_edge(MCLK) then
		reset_d<=not (status(0) or buttons(1)) and pll_locked;
		reset_n<=reset_d;
	end if;
end process;

ext_sw(3) <= status(5); --psg en
ext_sw(4) <= status(4); --fm en
ext_sw(5) <= status(7); --Export
ext_sw(6) <= not status(8); --PAL
ext_sw(9) <= not status(3); -- VRAM speed emulation
ext_sw(10) <= status(13); -- Fake EEPROM
ext_sw(13) <= status(17); -- HiFi PCM
ext_sw(14) <= status(18); -- CPU Turbo
ext_sw(15) <= status(19); -- Border
ext_sw(0) <= status(21); -- CRAM dots

JOY_SWAP <= status(6);
JOY_Y_SWAP <= status(9);
JOY_3BUT <= status(10);
MSEL <= status(16 downto 15);
LG_SEL <= status(23 downto 22);
MULTITAP <= status(25 downto 24);
TEAMPLAY <= '1' when MULTITAP = "01" else '0';
EA_MULTITAP <= '1' when MULTITAP = "10" else '0';
JCART <= '1' when MULTITAP = "11" else '0';

JOY_1 <= joya(11 downto 0) when JOY_SWAP = '0' else joyb(11 downto 0);
JOY_2 <= joyb(11 downto 0) when JOY_SWAP = '0' else joya(11 downto 0);
JOY_3 <= joyc(11 downto 0);
JOY_4 <= joyd(11 downto 0);

--SDRAM_A(12)<='0';
sdram_top : entity work.fpgagen_sdram_top
generic map (
	INTERNAL_VRAM => INTERNAL_VRAM
)
port map(
	reset_n => reset_n,
	MCLK => MCLK,
	SDR_CLK => memclk,
	DL_CLK => memclk,

	FPGA_INIT_N => pll_locked,
    DRAM_CKE => SDRAM_CKE,
    DRAM_CS_N => SDRAM_nCS,
    DRAM_RAS_N => SDRAM_nRAS,
    DRAM_CAS_N => SDRAM_nCAS,
    DRAM_WE_N => SDRAM_nWE,
    DRAM_UDQM => SDRAM_DQMH,
    DRAM_LDQM => SDRAM_DQML,
    DRAM_BA_1 => SDRAM_BA(1),
    DRAM_BA_0 => SDRAM_BA(0),
    DRAM_ADDR => SDRAM_A,
    DRAM_DQ => SDRAM_DQ,

	-- Joystick ports (Port_A, Port_B)
	DINA => DINA,
	DOUTA => DOUTA,
	OEA => OEA,

	DINB => DINB,
	DOUTB => DOUTB,
	OEB => OEB,

	-- JCART signals
	JCART_EN => JCART,
	JCART_TH => JCART_TH,
	JCART_DO => JCART_DO,

	-- Video, Audio/CMT ports
	RED => gen_red,
	GREEN => gen_green,
	BLUE => gen_blue,

	HS => gen_hs,
	VS => gen_vs,
	CE_PIX => gen_ce_pix,
	VBL => gen_vbl,
	IN_BORDER => gen_border,
	HBL => gen_hbl,

	LED => core_led,

    DAC_LDATA => audiol,
    DAC_RDATA => audior,

    -- save ram
    saveram_addr    => std_logic_vector(sd_lba)(5 downto 0) & sd_buff_addr,
    saveram_we      => sd_dout_strobe,
    saveram_din     => sd_dout,
    saveram_rd      => sd_din_strobe,
    saveram_dout    => sd_din,

    ext_reset_n  => ext_reset_n(15),
    ext_bootdone => ext_bootdone,
    ext_data     => ext_data,
    ext_data_req => ext_data_req,
    ext_data_ack => ext_data_ack,
    
    ext_sw       => ext_sw
);

DINA <= DOUT_CTRLA when EA_MULTITAP = '0' else DOUT_4WAY1;
DINB <= DOUT_CTRLB when EA_MULTITAP = '0' else DOUT_4WAY2;

DAT_CTRLA <= DOUTA;
OE_CTRLA <= OEA;

gen_ctrlA : entity work.gen_ctrl
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	-- controller port pins
	DAT          => DAT_CTRLA,
	DOUT         => DOUT_CTRLA,
	CTL          => OE_CTRLA,

	J3BUT        => JOY_3BUT,
	SWAP_Y       => JOY_Y_SWAP,
	TEAMPLAY     => TEAMPLAY,

	UP           => not JOY_1(3),
	DOWN         => not JOY_1(2),
	LEFT         => not JOY_1(1),
	RIGHT        => not JOY_1(0),
	A            => not JOY_1(4),
	B            => not JOY_1(5),
	C            => not JOY_1(6),
	START        => not JOY_1(7),
	X            => not JOY_1(8),
	Y            => not JOY_1(9),
	Z            => not JOY_1(10),
	MODE         => not JOY_1(11),

	UP2          => not JOY_2(3),
	DOWN2        => not JOY_2(2),
	LEFT2        => not JOY_2(1),
	RIGHT2       => not JOY_2(0),
	A2           => not JOY_2(4),
	B2           => not JOY_2(5),
	C2           => not JOY_2(6),
	START2       => not JOY_2(7),
	X2           => not JOY_2(8),
	Y2           => not JOY_2(9),
	Z2           => not JOY_2(10),
	MODE2        => not JOY_2(11),

	UP3          => not JOY_3(3),
	DOWN3        => not JOY_3(2),
	LEFT3        => not JOY_3(1),
	RIGHT3       => not JOY_3(0),
	A3           => not JOY_3(4),
	B3           => not JOY_3(5),
	C3           => not JOY_3(6),
	START3       => not JOY_3(7),
	X3           => not JOY_3(8),
	Y3           => not JOY_3(9),
	Z3           => not JOY_3(10),
	MODE3        => not JOY_3(11),

	UP4          => not JOY_4(3),
	DOWN4        => not JOY_4(2),
	LEFT4        => not JOY_4(1),
	RIGHT4       => not JOY_4(0),
	A4           => not JOY_4(4),
	B4           => not JOY_4(5),
	C4           => not JOY_4(6),
	START4       => not JOY_4(7),
	X4           => not JOY_4(8),
	Y4           => not JOY_4(9),
	Z4           => not JOY_4(10),
	MODE4        => not JOY_4(11),

	LG_SEL       => "00",
	LG_SENSOR    => '0',
	LG_A         => '0',
	LG_B         => '0',
	LG_C         => '0',
	LG_START     => '0',
	LG_SENSOR2   => '0',
	LG_A2        => '0',
	LG_START2    => '0',

	MSEL         => MSEL(0),
	mouse_x      => std_logic_vector(mouse_x(7 downto 0)),
	mouse_y      => std_logic_vector(mouse_y(7 downto 0)),
	mouse_flags  => mouse_flags,
	mouse_strobe => mouse_strobe
);

DAT_CTRLB <= DOUTB when EA_MULTITAP = '0' else DOUTA;
OE_CTRLB <= OEB when EA_MULTITAP = '0' else OEA;

gen_ctrlB : entity work.gen_ctrl
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	-- controller port pins
	DAT          => DAT_CTRLB,
	DOUT         => DOUT_CTRLB,
	CTL          => OE_CTRLB,

	J3BUT        => JOY_3BUT,
	SWAP_Y       => JOY_Y_SWAP,
	UP           => not JOY_2(3),
	DOWN         => not JOY_2(2),
	LEFT         => not JOY_2(1),
	RIGHT        => not JOY_2(0),
	A            => not JOY_2(4),
	B            => not JOY_2(5),
	C            => not JOY_2(6),
	START        => not JOY_2(7),
	X            => not JOY_2(8),
	Y            => not JOY_2(9),
	Z            => not JOY_2(10),
	MODE         => not JOY_2(11),

	LG_SEL       => LG_SEL,
	LG_SENSOR    => LG_SENSOR,
	LG_A         => LG_A,
	LG_B         => LG_B,
	LG_C         => LG_C,
	LG_START     => LG_START,
	LG_SENSOR2   => LG_SENSOR2,
	LG_A2        => LG_A2,
	LG_START2    => LG_START2,

	MSEL         => MSEL(1),
	mouse_x      => std_logic_vector(mouse_x(7 downto 0)),
	mouse_y      => std_logic_vector(mouse_y(7 downto 0)),
	mouse_flags  => mouse_flags,
	mouse_strobe => mouse_strobe
);

DAT_CTRLC <= DOUTA when JCART = '0' else '1'&JCART_TH&"111111";
OE_CTRLC <= OEA when JCART = '0' else x"00";

gen_ctrlC : entity work.gen_ctrl
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	-- controller port pins
	DAT          => DAT_CTRLC,
	DOUT         => DOUT_CTRLC,
	CTL          => OE_CTRLC,

	J3BUT        => JOY_3BUT,
	SWAP_Y       => JOY_Y_SWAP,
	UP           => not JOY_3(3),
	DOWN         => not JOY_3(2),
	LEFT         => not JOY_3(1),
	RIGHT        => not JOY_3(0),
	A            => not JOY_3(4),
	B            => not JOY_3(5),
	C            => not JOY_3(6),
	START        => not JOY_3(7),
	X            => not JOY_3(8),
	Y            => not JOY_3(9),
	Z            => not JOY_3(10),
	MODE         => not JOY_3(11)
);

DAT_CTRLD <= DOUTA when JCART = '0' else '1'&JCART_TH&"111111";
OE_CTRLD <= OEA when JCART = '0' else x"00";

gen_ctrlD : entity work.gen_ctrl
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	-- controller port pins
	DAT          => DAT_CTRLD,
	DOUT         => DOUT_CTRLD,
	CTL          => OE_CTRLD,

	J3BUT        => JOY_3BUT,
	SWAP_Y       => JOY_Y_SWAP,
	UP           => not JOY_4(3),
	DOWN         => not JOY_4(2),
	LEFT         => not JOY_4(1),
	RIGHT        => not JOY_4(0),
	A            => not JOY_4(4),
	B            => not JOY_4(5),
	C            => not JOY_4(6),
	START        => not JOY_4(7),
	X            => not JOY_4(8),
	Y            => not JOY_4(9),
	Z            => not JOY_4(10),
	MODE         => not JOY_4(11)
);

JCART_DO <= "00"&DOUT_CTRLD(5 downto 0) & '0'&JCART_TH&DOUT_CTRLC(5 downto 0);

gen_4wayplay : entity work.gen_4wayplay
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	-- controller port pins
	DATA         => DOUT_CTRLA,
	DATB         => DOUT_CTRLB,
	DATC         => DOUT_CTRLC,
	DATD         => DOUT_CTRLD,

	DOUT1        => DOUT_4WAY1,
	DAT2         => DOUTB,
	DOUT2        => DOUT_4WAY2,
	CTL2         => OEB
);

gen_lg : entity work.gen_lightgun
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	CE_PIX       => gen_ce_pix,
	VBL          => gen_border,
	HBL          => gen_hbl,

	mouse_x      => std_logic_vector(mouse_x(7 downto 0)),
	mouse_y      => std_logic_vector(mouse_y(7 downto 0)),
	mouse_flags  => mouse_flags,
	mouse_strobe => mouse_strobe and (not mouse_idx or not LG_SEL(1)), -- mouse 0 only with Justifier

	JUSTIFIER    => LG_SEL(1),
	TARGET       => LG_TARGET,
	SENSOR       => LG_SENSOR,
	A            => LG_A,
	B            => LG_B,
	C            => LG_C,
	START        => LG_START
);

LG1_CH <= '1' when LG_TARGET = '1' and LG_SEL(1) = '1' else '0';

-- second Justifier
gen_lg2 : entity work.gen_lightgun
port map (
	RST_N        => reset_n,
	CLK          => MCLK,

	CE_PIX       => gen_ce_pix,
	VBL          => gen_border,
	HBL          => gen_hbl,

	mouse_x      => std_logic_vector(mouse_x(7 downto 0)),
	mouse_y      => std_logic_vector(mouse_y(7 downto 0)),
	mouse_flags  => mouse_flags,
	mouse_strobe => mouse_strobe and mouse_idx, -- mouse 1 only

	JUSTIFIER    => '1',
	TARGET       => LG_TARGET2,
	SENSOR       => LG_SENSOR2,
	A            => LG_A2,
	B            => open,
	C            => open,
	START        => LG_START2
);

LG2_CH <= '1' when LG_TARGET2 = '1' and LG_SEL = "11" else '0';

sd_conf <= '0';

user_io_inst : user_io
    generic map (
        STRLEN => CONF_STR'length,
        ROM_DIRECT_UPLOAD => DIRECT_UPLOAD,
        FEATURES => x"0000"&'0'&bool_to_sl(HDMI)&bool_to_sl(BIG_OSD)&'0'&x"00"&'0'&bool_to_sl(USE_QSPI)&"00"
    )
    port map (
        clk_sys => MCLK,
        clk_sd => MCLK,
        SPI_CLK => SPI_SCK,
        SPI_SS_IO => CONF_DATA0,
        SPI_MISO => SPI_DO,
        SPI_MOSI => SPI_DI,
        conf_str => to_slv(CONF_STR),
        status => status,
        ypbpr => ypbpr,
        no_csync => no_csync,
        scandoubler_disable => scandoubler_disable,

        i2c_start => i2c_start,
        i2c_read => i2c_read,
        i2c_addr => i2c_addr,
        i2c_subaddr => i2c_subaddr,
        i2c_dout => i2c_wdata,
        i2c_din => i2c_rdata,
        i2c_end => i2c_end,
        i2c_ack => i2c_ack,

        joystick_0 => joya,
        joystick_1 => joyb,
        joystick_2 => joyc,
        joystick_3 => joyd,
        joystick_analog_0 => open,
        joystick_analog_1 => open,
--      switches => switches,
        buttons => buttons,

        sd_lba  => std_logic_vector(sd_lba),
        sd_rd   => sd_rd,
        sd_wr   => sd_wr,
        sd_ack  => sd_ack,
        sd_sdhc => '1',
        sd_conf => sd_conf,
        sd_dout => sd_dout,
        sd_dout_strobe => sd_dout_strobe,
        sd_din => sd_din,
        sd_din_strobe => sd_din_strobe,
        sd_buff_addr => sd_buff_addr,
        img_mounted => img_mounted,
        img_size => img_size,

        ps2_kbd_clk => open,
        ps2_kbd_data => open,
        ps2_mouse_clk => open,
        ps2_mouse_data => open,
        mouse_x => mouse_x,
        mouse_y => mouse_y,
        mouse_flags => mouse_flags,
        mouse_strobe => mouse_strobe,
        mouse_idx => mouse_idx
 );

process (MCLK) begin
    if rising_edge(MCLK) then

        downloadingD_MCLK <= downloading;
        if downloadingD_MCLK = '0' and downloading = '1' then
            bk_ena <= '0';
        end if;

        img_mountedD <= img_mounted(0);
        if img_mountedD = '0' and img_mounted(0) = '1' and img_size /= x"0000000000000000" then
            bk_ena <= '1';
            bk_load <= '1';
        end if;

        bk_loadD <= bk_load;
        bk_saveD <= status(14);
        sd_ackD  <= sd_ack;

        if sd_ackD = '0' and sd_ack = '1' then
            sd_rd(0) <= '0';
            sd_wr(0) <= '0';
        end if;

        if bk_state = '0' then
            if bk_ena = '1' and ((bk_loadD = '0' and bk_load = '1') or (bk_saveD = '0' and status(14) = '1')) then
                bk_state <= '1';
                sd_lba <= (others =>'0');
                sd_rd(0) <= bk_load;
                sd_wr(0) <= not bk_load;
            end if;
        else
            if sd_ackD = '1' and sd_ack = '0' then
                if sd_lba(5 downto 0) = "111111" then
                    bk_load <= '0';
                    bk_state <= '0';
                else
                    sd_lba <= sd_lba + 1;
                    sd_rd(0)  <= bk_load;
                    sd_wr(0)  <= not bk_load;
                end if;
            end if;
        end if;
    end if;
end process;

data_io_inst: data_io
    generic map (
        ROM_DIRECT_UPLOAD => DIRECT_UPLOAD,
        USE_QSPI => USE_QSPI
    )
    port map (
        clk_sys        => memclk,
        clkref_n       => not data_io_clkref,
        ioctl_wr       => data_io_wr,
        ioctl_addr     => open,
        ioctl_dout     => data_io_d,
        ioctl_download => downloading,
        ioctl_index    => open,

        SPI_SCK        => SPI_SCK,
        SPI_SS2        => SPI_SS2,
        SPI_SS4        => SPI_SS4,
        SPI_DI         => SPI_DI,
        SPI_DO         => SPI_DO,

        QCSn           => QCSn,
        QSCK           => QSCK,
        QDAT           => QDAT
    );

process(memclk)
begin
    if rising_edge( memclk ) then
        downloadingD <= downloading;
        ext_reset_n <= ext_reset_n(14 downto 0)&'1'; --stretch reset
        ext_data_ack <= '0';
        if (downloadingD = '0' and downloading = '1') then
            -- ROM downloading start
            ext_bootdone <= '0';
            ext_reset_n <= x"0000";
            d_state <= "00";
            data_io_clkref <= '1';
        elsif (downloading = '0') then
            -- ROM downloading finished
            ext_bootdone <= '1';
            data_io_clkref <= '0';
        elsif (downloading = '1') then
            -- ROM downloading in progress
            case d_state is
            when "00" =>
                if data_io_wr = '1' then
                    ext_data <= data_io_d(7 downto 0) & data_io_d(15 downto 8);
                    data_io_clkref <= '0';
                    d_state <= "10";
                end if;
            when "10" =>
                if ext_data_req = '1' then
                    ext_data_ack <= '1';
                    d_state <= "11";
                end if;
            when "11" =>
                data_io_clkref <= '1';
                d_state <= "00";
            when others => null;
            end case;
        end if;
    end if;
end process;

red_out   <= (gen_red and not (LG1_CH&LG1_CH&LG1_CH&LG1_CH)) or (LG2_CH&LG2_CH&LG2_CH&LG2_CH);
green_out <= gen_green and not ((LG1_CH or LG2_CH)&(LG1_CH or LG2_CH)&(LG1_CH or LG2_CH)&(LG1_CH or LG2_CH));
blue_out  <= (gen_blue and not (LG2_CH&LG2_CH&LG2_CH&LG2_CH)) or (LG1_CH&LG1_CH&LG1_CH&LG1_CH);

vga_video : mist_video
    generic map (
        SD_HCNT_WIDTH => 10,
        COLOR_DEPTH => 4,
        BIG_OSD => BIG_OSD,
        USE_BLANKS => true,
        OUT_COLOR_DEPTH => VGA_BITS,
        OSD_COLOR => "001" --blue
    )
    port map (
        clk_sys     => MCLK,
        scanlines   => status(12 downto 11),
        scandoubler_disable => scandoubler_disable,
        ypbpr       => ypbpr,
        no_csync    => no_csync,
        rotate      => "00",
        blend       => status(20),

        SPI_SCK     => SPI_SCK,
        SPI_SS3     => SPI_SS3,
        SPI_DI      => SPI_DI,

        HBlank      => gen_hbl,
        VBlank      => gen_vbl,
        HSync       => gen_hs,
        VSync       => gen_vs,
        R           => red_out,
        G           => green_out,
        B           => blue_out,

        VGA_HS      => VGA_HS,
        VGA_VS      => VGA_VS,
        VGA_R       => VGA_R,
        VGA_G       => VGA_G,
        VGA_B       => VGA_B
    );

audiol_clamp <= audiol(audiol'high-1 downto 0) when audiol_sign=audiol_adj else -- Pass through
				(audiol_clamp'high=>audiol_sign,others=>audiol_adj); -- Clamp
audior_clamp <= audior(audior'high-1 downto 0) when audior_sign=audior_adj else -- Pass through
				(audior_clamp'high=>audior_sign,others=>audior_adj); -- Clamp

hdmi_block : if HDMI generate

	i2c_master_d : i2c_master
	generic map (
		CLK_Freq => 54000000
	)
	port map (
		CLK => MCLK,
		I2C_START => i2c_start,
		I2C_READ => i2c_read,
		I2C_ADDR => i2c_addr,
		I2C_SUBADDR => i2c_subaddr,
		I2C_WDATA => i2c_wdata,
		I2C_RDATA => i2c_rdata,
		I2C_END => i2c_end,
		I2C_ACK => i2c_ack,
		I2C_SCL => HDMI_SCL,
		I2C_SDA => HDMI_SDA
	);

hdmi_video : mist_video
    generic map (
        SD_HCNT_WIDTH => 10,
        COLOR_DEPTH => 4,
        BIG_OSD => BIG_OSD,
        USE_BLANKS => true,
        OUT_COLOR_DEPTH => 8,
        OSD_COLOR => "001" --blue
    )
    port map (
        clk_sys     => MCLK,
        scanlines   => status(12 downto 11),
        scandoubler_disable => '0',
        ypbpr       => '0',
        no_csync    => '1',
        rotate      => "00",
        blend       => status(20),

        SPI_SCK     => SPI_SCK,
        SPI_SS3     => SPI_SS3,
        SPI_DI      => SPI_DI,

        HBlank      => gen_hbl,
        VBlank      => gen_vbl,
        HSync       => not gen_hs,
        VSync       => not gen_vs,
        R           => red_out,
        G           => green_out,
        B           => blue_out,

        VGA_HS      => HDMI_HS,
        VGA_VS      => HDMI_VS,
        VGA_DE      => HDMI_DE,
        VGA_R       => HDMI_R,
        VGA_G       => HDMI_G,
        VGA_B       => HDMI_B
    );

    HDMI_PCLK <= MCLK;
end generate;


my_i2s : i2s
port map (
    clk => MCLK,
    reset => '0',
    clk_rate => 54000000,
    sclk => I2S_BCK,
    lrclk => I2S_LRCK,
    sdata => I2S_DATA,
    left_chan  => audiol_sign & audiol_clamp(13 downto 0) & '0',
    right_chan => audior_sign & audior_clamp(13 downto 0) & '0'
	);

my_spdif : spdif
port map (
    rst_i => '0',
    clk_i => MCLK,
    clk_rate_i => 54000000,
    spdif_o => SPDIF_O,
    sample_i => audior_sign & audior_clamp(13 downto 0) & '0' & audiol_sign & audiol_clamp(13 downto 0) & '0'
	);

end architecture;
