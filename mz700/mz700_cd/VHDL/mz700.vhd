--
-- mz700.vhd
--
-- SHARP MZ-700 compatible logic, main module
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity mz700 is
  port(
    -- Clock, Reset ports
    pClk21m     : in std_logic;				-- VDP clock ... 21.48MHz
    pExtClk     : in std_logic;				-- Reserved (for multi FPGAs)
    pCpuClk     : out std_logic;			-- CPU clock ... 3.58MHz (up to 10.74MHz/21.48MHz)
--  pCpuRst_n   : out std_logic;			-- CPU reset

    -- MSX cartridge slot ports
    pSltClk     : in std_logic;                         -- pCpuClk returns here, for Z80, etc.
    pSltRst_n   : in std_logic;                         -- pCpuRst_n returns here
    pSltSltsl_n : inout std_logic;
    pSltSlts2_n : inout std_logic;
    pSltIorq_n  : inout std_logic;
    pSltRd_n    : inout std_logic;
    pSltWr_n    : inout std_logic;
    pSltAdr     : inout std_logic_vector(15 downto 0);
    pSltDat     : inout std_logic_vector(7 downto 0);
    pSltBdir_n  : out std_logic;                        -- Bus direction (not used in master mode)

    pSltCs1_n   : inout std_logic;
    pSltCs2_n   : inout std_logic;
    pSltCs12_n  : inout std_logic;
    pSltRfsh_n  : inout std_logic;
    pSltWait_n  : inout std_logic;
    pSltInt_n   : inout std_logic;
    pSltM1_n    : inout std_logic;
    pSltMerq_n  : inout std_logic;

    pSltRsv5    : out std_logic;                        -- Reserved
    pSltRsv16   : out std_logic;                        -- Reserved (w/ external pull-up)
    pSltSw1     : inout std_logic;                      -- Reserved (w/ external pull-up)
    pSltSw2     : inout std_logic;                      -- Reserved

    -- SD-RAM ports
    pMemClk     : out std_logic;                        -- SD-RAM Clock
    pMemCke     : out std_logic;                        -- SD-RAM Clock enable
    pMemCs_n    : out std_logic;                        -- SD-RAM Chip select
    pMemRas_n   : out std_logic;                        -- SD-RAM Row/RAS
    pMemCas_n   : out std_logic;                        -- SD-RAM /CAS
    pMemWe_n    : out std_logic;                        -- SD-RAM /WE
    pMemUdq     : out std_logic;                        -- SD-RAM UDQM
    pMemLdq     : out std_logic;                        -- SD-RAM LDQM
    pMemBa1     : out std_logic;                        -- SD-RAM Bank select address 1
    pMemBa0     : out std_logic;                        -- SD-RAM Bank select address 0
    pMemAdr     : out std_logic_vector(12 downto 0);    -- SD-RAM Address
    pMemDat     : inout std_logic_vector(15 downto 0);  -- SD-RAM Data

    -- PS/2 keyboard ports
    pPs2Clk     : inout std_logic;
    pPs2Dat     : inout std_logic;

    -- Joystick ports (Port_A, Port_B)
    pJoyA       : inout std_logic_vector( 5 downto 0);
--    pJoyA       : out std_logic_vector( 5 downto 0);	-- for debug
    pStrA       : out std_logic;
    pJoyB       : inout std_logic_vector( 5 downto 0);
    pStrB       : out std_logic;

    -- SD/MMC slot ports
    pSd_Ck      : out std_logic;                        -- pin 5
    pSd_Cm      : out std_logic;                        -- pin 2
    pSd_Dt      : inout std_logic_vector( 3 downto 0);  -- pin 1(D3), 9(D2), 8(D1), 7(D0)

    -- DIP switch, Lamp ports
    pDip        : in std_logic_vector( 7 downto 0);     -- 0=ON,  1=OFF(default on shipment)
    pLed        : out std_logic_vector( 7 downto 0);    -- 0=OFF, 1=ON(green)
    pLedPwr     : out std_logic;                        -- 0=OFF, 1=ON(red) ...Power & SD/MMC access lamp

    -- Video, Audio/CMT ports
    pDac_VR     : inout std_logic_vector( 5 downto 0);  -- RGB_Red / Svideo_C
    pDac_VG     : inout std_logic_vector( 5 downto 0);  -- RGB_Grn / Svideo_Y
    pDac_VB     : inout std_logic_vector( 5 downto 0);  -- RGB_Blu / CompositeVideo
    pDac_SL     : out   std_logic_vector( 5 downto 0);  -- Sound-L
    pDac_SR     : inout std_logic_vector( 5 downto 0);  -- Sound-R / CMT

    pVideoHS_n  : out std_logic;                        -- Csync(RGB15K), HSync(VGA31K)
    pVideoVS_n  : out std_logic;                        -- Audio(RGB15K), VSync(VGA31K)

    pVideoClk   : out std_logic;                        -- (Reserved)
    pVideoDat   : out std_logic;                        -- (Reserved)

    -- Reserved ports (USB)
    pUsbP1      : inout std_logic;
    pUsbN1      : inout std_logic;
    pUsbP2      : inout std_logic;
    pUsbN2      : inout std_logic;

    -- Reserved ports
    pIopRsv14   : out std_logic;
    pIopRsv15   : out std_logic;
    pIopRsv16   : out std_logic;
    pIopRsv17   : out std_logic;
    pIopRsv18   : out std_logic;
    pIopRsv19   : out std_logic;
    pIopRsv20   : out std_logic;
    pIopRsv21   : out std_logic
  );
end mz700;

architecture rtl of mz700 is

--
-- Reset
--
signal RCOUNT : std_logic_vector(10 downto 0);
signal URST : std_logic;
--
-- T80
--
signal MREQ : std_logic;
signal IORQ : std_logic;
signal ZWR : std_logic;
signal ZRD : std_logic;
signal M1 : std_logic;
--signal RFSH : std_logic;
signal ZWAIT : std_logic;
signal ZA16 : std_logic_vector(15 downto 0);
signal A16 : std_logic_vector(15 downto 0);
signal DO : std_logic_vector(7 downto 0);
signal ZDO : std_logic_vector(7 downto 0);
signal DI : std_logic_vector(7 downto 0);
signal ZRST : std_logic;
signal ZBREQ : std_logic;
signal ZBACK : std_logic;
--signal ZCS00 : std_logic;
signal ZCSD0 : std_logic;
signal ZCSD8 : std_logic;
--
-- Clock
--
--signal clk21m : std_logic;
signal CLK25  : std_logic;
signal DCLK   : std_logic;
signal memclk : std_logic;
signal CPUCLK : std_logic;
signal SCLK : std_logic;
signal HCLK : std_logic;
signal HCLK0 : std_logic;
signal DIV4 : std_logic_vector(1 downto 0);
signal CASCADE : std_logic;
--
-- Video
--
signal HSPLS : std_logic;
signal CSVRAM : std_logic;
signal CVDI : std_logic_vector(7 downto 0);
signal WECV : std_logic;
signal CSCG : std_logic;
signal AVDI : std_logic_vector(7 downto 0);
signal WEAV : std_logic;
signal VADR : std_logic_vector(10 downto 0);
signal DCODE : std_logic_vector(7 downto 0);
signal CGADR : std_logic_vector(11 downto 0);
signal CSEL : std_logic;
signal GCS  : std_logic;
signal FADR : std_logic_vector(15 downto 0);
signal CGDAT : std_logic_vector(31 downto 0);
signal CGSEL : std_logic_vector(1 downto 0);
signal VBLNK : std_logic;
signal CSPCG : std_logic;
signal PCGA   : std_logic_vector(10 downto 0);
signal PCGD   : std_logic_vector(7 downto 0);
signal PCGWP  : std_logic;
signal PCGCPY : std_logic;
signal PCGREG : std_logic_vector(7 downto 0);
--signal VO : std_logic_vector(5 downto 0);
--signal HS : std_logic;
--signal VS : std_logic;
--signal HC : std_logic_vector(8 downto 0);
--signal HEN : std_logic;
--signal VEN : std_logic;
--signal R : std_logic;
--signal G : std_logic_vector(5 downto 0);
--signal B : std_logic_vector(5 downto 0);
--
-- Decodes, misc
--
signal WR : std_logic;
signal WEMM : std_logic;
signal CS1 : std_logic;
signal RAMDI : std_logic_vector(7 downto 0);
--signal MDI : std_logic_vector(15 downto 0);
signal RAMDO : std_logic_vector(15 downto 0);
signal MDOE : std_logic;
signal RAMA : std_logic_vector(22 downto 0);
signal RAMCS : std_logic;
signal BSEL : std_logic_vector(6 downto 0);
signal CS00 : std_logic;
signal CS367 : std_logic;
signal MRDI : std_logic_vector(7 downto 0);
signal DO367 : std_logic_vector(7 downto 0);
signal CSPRT : std_logic;
signal DOPS : std_logic_vector(7 downto 0);
signal PCGSW : std_logic;
--signal BUF : std_logic_vector(9 downto 0);
signal CSFDD : std_logic;
signal FDD1 : std_logic;
signal FDD2 : std_logic;
--
-- PPI
--
signal CSPPI : std_logic;
signal DOPPI : std_logic_vector(7 downto 0);
signal TXDi : std_logic;
signal RBIT : std_logic;
signal MOTOR : std_logic;
signal PLYSW : std_logic;
signal INTMSK : std_logic;
--
-- PIT
--
signal CSPIT : std_logic;
signal DOPIT : std_logic_vector(7 downto 0);
signal SOUNDEN : std_logic;
signal XSPKOUT : std_logic;
signal INT : std_logic;
signal INTX : std_logic;
--
-- Extend ROM
--
signal CSE8 : std_logic;
--signal EMDI : std_logic_vector(7 downto 0);
--
-- Sub processor
--
signal SA16 : std_logic_vector(15 downto 0);
signal SEA6 : std_logic_vector(5 downto 0);
signal SDO : std_logic_vector(7 downto 0);
signal SRD : std_logic;
signal SWR : std_logic;
signal SCSM : std_logic;
signal SCSD0 : std_logic;
signal SCSD8 : std_logic;
signal SRAMDI : std_logic_vector(7 downto 0);
signal SRAMCS : std_logic;
signal SWAIT : std_logic;
signal KEY_UP : std_logic;
signal KEY_DOWN : std_logic;
signal KEY_LEFT : std_logic;
signal KEY_RIGHT : std_logic;
signal KEY_CR : std_logic;
signal KEY_SPACE : std_logic;
signal ALT_ALT : std_logic;
signal ALT_EXIT : std_logic;
signal ALT_PLAY : std_logic;
signal ALT_STOP : std_logic;
signal ALT_CG : std_logic;
signal ALT_PCG : std_logic;
--
-- Debug
--
--signal MA : std_logic_vector(12 downto 0);
--signal MCAS : std_logic;
--signal MRAS : std_logic;
--signal TASR : std_logic;
--signal TARD : std_logic;
--signal TAEN : std_logic;
signal LDDAT : std_logic_vector(7 downto 0);
signal MMCCK : std_logic;
signal MMCCS : std_logic;
signal MMCDI : std_logic;
signal MMCDO : std_logic;
--signal TEPCS : std_logic;
--signal TEPDO : std_logic;
--signal TEPDI : std_logic;
--signal TEPCK : std_logic;
--signal TRFSH : std_logic;
signal TPMI : std_logic_vector(15 downto 0);
signal TPMA : std_logic_vector(7 downto 0);
signal TMRD : std_logic;
signal TMWR : std_logic;
signal TINT : std_logic;
--signal TWE : std_logic;
signal TEPCCK : std_logic;
signal TEPCDO : std_logic;
signal TEPCCS : std_logic;
signal TEPCDI : std_logic;
--signal TBMASK : std_logic_vector(7 downto 0);
--signal TFMASK : std_logic_vector(7 downto 0);
signal TVADRC : std_logic_vector(9 downto 0);
signal TBUFWP : std_logic_vector(5 downto 0);
signal TBUFPT : std_logic_vector(5 downto 0);
signal THDEN : std_logic;
signal TBWEN : std_logic;
signal TBWD : std_logic_vector(7 downto 0);
signal TSDAT : std_logic_vector(7 downto 0);
signal TPC : std_logic;

--
-- Components
--
component T80s
	generic(
		Mode : integer := 0;	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
		T2Write : integer := 0;	-- 0 => WR_n active in T3, /=0 => WR_n active in T2
		IOWait : integer := 1	-- 0 => Single cycle I/O, 1 => Std I/O cycle
	);
	port(
		RESET_n		: in std_logic;
		CLK_n		: in std_logic;
		WAIT_n		: in std_logic;
		INT_n		: in std_logic;
		NMI_n		: in std_logic;
		BUSRQ_n		: in std_logic;
		M1_n		: out std_logic;
		MREQ_n		: out std_logic;
		IORQ_n		: out std_logic;
		RD_n		: out std_logic;
		WR_n		: out std_logic;
		RFSH_n		: out std_logic;
		HALT_n		: out std_logic;
		BUSAK_n		: out std_logic;
		A			: out std_logic_vector(15 downto 0);
		DI			: in std_logic_vector(7 downto 0);
		DO			: out std_logic_vector(7 downto 0)
	);
end component;

component pll25                       -- Altera specific component
    port(
      inclk0 : in std_logic := '0';     -- 21.48MHz input to PLL    (external I/O pin, from crystal oscillator)
      c0     : out std_logic ;          -- 25.05MHz output from PLL (internal LEs, for VDP, internal-bus, etc.)
      c1     : out std_logic ;          -- 85.92MHz output from PLL (internal LEs, for SD-RAM)
      e0     : out std_logic            -- 85.92MHz output from PLL (external I/O pin, for SD-RAM)
    );
end component;

component ckgen
	PORT(
		CLK21	: IN	STD_LOGIC;
		CPUCLK	: OUT	STD_LOGIC
	);
end component;

component memsel
    Port(
		RST   : in std_logic;
		CLK   : in std_logic;
		M1    : in std_logic;
		MREQ  : in std_logic;
		IORQ  : in std_logic;
		RD    : in std_logic;
		WR	  : in std_logic;
		A : in std_logic_vector(15 downto 0);
		DI : in std_logic_vector(7 downto 0);
		LED0 : out std_logic;
		LED1 : out std_logic;
		ZWAIT : out std_logic;
		CS00 : out std_logic;
		CSVRAM : out std_logic;
		CSCG : out std_logic;
		CGSEL : out std_logic_vector(1 downto 0);
		CSE8 : out std_logic;
		CSPPI : out std_logic;
		CSPIT : out std_logic;
		CS367 : out std_logic;
		CSPCG : out std_logic;
		CS1 : out std_logic
	);
end component;	 

component pcg
    Port (
		PCGA   : out std_logic_vector(10 downto 0);
		PCGD   : out std_logic_vector(7 downto 0);
		PCGWP  : out std_logic;
		PCGCPY : out std_logic;
		CSPCG  : in std_logic;
		WR     : in std_logic;
		A      : in std_logic_vector(1 downto 0);
		DI     : in std_logic_vector(7 downto 0);
		DO     : out std_logic_vector(7 downto 0);
		MCLK   : in std_logic);
end component;

--component dpram2k
--	PORT(
--		address_a	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
--		address_b	: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
--		clock_a		: IN STD_LOGIC ;
--		clock_b		: IN STD_LOGIC ;
--		data_a		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
--		data_b		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
--		wren_a		: IN STD_LOGIC  := '1';
--		wren_b		: IN STD_LOGIC  := '1';
--		q_a			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
--		q_b			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
--	);
--end component;

component vgaout
	Port( 
		RST		: in std_logic;
--		HC : out std_logic_vector(8 downto 0);
--		HEN : out std_logic;
--		VEN : out std_logic;
--		SD : out std_logic;
		TVADRC : out std_logic_vector(9 downto 0);
		TBUFWP : out std_logic_vector(5 downto 0);
		TBUFPT : out std_logic_vector(5 downto 0);
		THDEN : out std_logic;
		TBWEN : out std_logic;
		TBWD : out std_logic_vector(7 downto 0);
		TSDAT : out std_logic_vector(7 downto 0);
		CLK21	: in std_logic;
		CLK25	: in std_logic;
		DCLK	: out std_logic;
		RED		: out std_logic_vector(5 downto 0);
		GRN		: out std_logic_vector(5 downto 0);
		BLUE	: out std_logic_vector(5 downto 0);
		HSOUT	: out std_logic;
		VSOUT	: out std_logic;
		VBLNK	: out std_logic;
		FDAT	: in std_logic_vector(31 downto 0);
		FADR	: out std_logic_vector(15 downto 0);
		CSO		: out std_logic;
		-- from/to Main CPU
		ZCLK	: in std_logic;
		ZADR	: in std_logic_vector(15 downto 0);
		ZDI		: in std_logic_vector(7 downto 0);
		IORQ	: in std_logic;
		ZWR		: in std_logic;
		SW		: in std_logic_vector(1 downto 0);
		PCGSW	: in std_logic
	);
end component;

component sdram
	port(
		RST		: in std_logic;
		MEMCLK	: in std_logic;
		TPC	: out std_logic;
		-- RAM access(port1)
		AA		: in std_logic_vector(22 downto 0);
		DAI		: in std_logic_vector(7 downto 0);
		DAO		: out std_logic_vector(7 downto 0);
		CSA		: in std_logic;
		WRA		: in std_logic;
		-- RAM access(port2)
		AB		: in std_logic_vector(22 downto 0);
		DBI		: in std_logic_vector(7 downto 0);
		DBO		: out std_logic_vector(7 downto 0);
		CSB		: in std_logic;
		RDB		: in std_logic;
		WRB		: in std_logic;
		WAITB	: out std_logic;
		-- RAM access(port3)
		AC		: in std_logic_vector(22 downto 0);
		DCO		: out std_logic_vector(31 downto 0);
		CSC		: in std_logic;
		-- RAM access(port4:for PCG)
		AD		: in std_logic_vector(22 downto 0);
		DDI		: in std_logic_vector(7 downto 0);
		CSD		: in std_logic;
		CPYMODE : in std_logic;
		-- SDRAM signal
		MA		: out std_logic_vector(12 downto 0);
		MBA0	: out std_logic;
		MBA1	: out std_logic;
		MDI		: in std_logic_vector(15 downto 0);
		MDO		: out std_logic_vector(15 downto 0);
		MDOE	: out std_logic;
		MLDQ	: out std_logic;
		MUDQ	: out std_logic;
		MCAS	: out std_logic;
		MRAS	: out std_logic;
		MCS		: out std_logic;
		MWE		: out std_logic;
		MCKE	: out std_logic
	);
end component;

component ls367
	Port( 
		RST : in std_logic;
		CLKIN : in std_logic;
		CLKOUT : out std_logic;
		GATE : out std_logic;
		CS : in std_logic;
		WR : in std_logic;
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0)
	);
end component;

component i8255
	Port(
		RST : in std_logic;
		A : in std_logic_vector(1 downto 0);
		CS : in std_logic;
		WR : in std_logic;
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		LDDAT : out std_logic_vector(7 downto 0);
--		LDDAT2 : out std_logic;
--		LDSNS : out std_logic;
		CLKIN : in std_logic;
		KCLK : in std_logic;
--		FCLK : in std_logic;
		VBLNK : in std_logic;
		INTMSK : out std_logic;
		RBIT : in std_logic;
		SENSE : in std_logic;
		MOTOR : out std_logic;
		PS2CK : in std_logic;
		PS2DT : in std_logic;
		-- for Sub processor
		KEY_UP : out std_logic;
		KEY_DOWN : out std_logic;
		KEY_LEFT : out std_logic;
		KEY_RIGHT : out std_logic;
		KEY_CR : out std_logic;
		KEY_SPACE : out std_logic;
		ALT_ALT : out std_logic;
		ALT_EXIT : out std_logic;
		ALT_PLAY : out std_logic;
		ALT_STOP : out std_logic;
		ALT_CG : out std_logic;
		ALT_PCG : out std_logic;
		-- for Joystick
		JOYA : in std_logic_vector(5 downto 0);
		JOYB : in std_logic_vector(5 downto 0)
	);
end component;

component psio
	Port (
		-- common
		RST  : in std_logic;
		FCLK : in std_logic;
		CLK  : in std_logic;
		ADR  : out std_logic_vector(15 downto 0);
		EADR : out std_logic_vector(5 downto 0);
		DI	 : in std_logic_vector(7 downto 0);
		RAMDI : in std_logic_vector(7 downto 0);
		DO	 : out std_logic_vector(7 downto 0);
		RD	 : out std_logic;
		WR	 : out std_logic;
		CSM  : out std_logic;
		RAMCS : out std_logic;
		CSD0 : out std_logic;
		CSD8 : out std_logic;
		SWAIT : in std_logic;
		KEY_UP : in std_logic;
		KEY_DOWN : in std_logic;
		KEY_LEFT : in std_logic;
		KEY_RIGHT : in std_logic;
		KEY_CR : in std_logic;
		KEY_SPACE : in std_logic;
		ALT_ALT : in std_logic;
		ALT_EXIT : in std_logic;
		ALT_PLAY : in std_logic;
		ALT_STOP : in std_logic;
		TPMA : out std_logic_vector(7 downto 0);
		TPMI : out std_logic_vector(15 downto 0);
		TMRD : out std_logic;
		TMWR : out std_logic;
		--TINT : out std_logic;
		TEPCCK : out std_logic;
		TEPCDO : out std_logic;
		TEPCCS : out std_logic;
		TEPCDI : out std_logic;
		-- from/to Main CPU
		ZRST : out std_logic;
		ZADR : in std_logic_vector(15 downto 0);
		ZDI  : in std_logic_vector(7 downto 0);
		ZDO  : out std_logic_vector(7 downto 0);
		MREQ : in std_logic;
		IORQ : in std_logic;
		ZWR	 : in std_logic;
		ZRD	 : in std_logic;
		ZBRQ : out std_logic;
		ZBAK : in std_logic;
		-- MMC I/F
		MMCCK : out std_logic;
		MMCCS : out std_logic;
		MMCDI : in std_logic;
		MMCDO : out std_logic;
		-- FDD
		CSFDD : out std_logic;
		INUSE1 : out std_logic;
		INUSE2 : out std_logic;
		-- I/O
		CSPRT : out std_logic;
		RBIT : out std_logic;
		PLYSW : out std_logic;
		MOTOR : in std_logic
	);
end component;

component i8253
	Port(
		RST : in std_logic;
		CLK : in std_logic;
		A : in std_logic_vector(1 downto 0);
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		CS : in std_logic;
		WR : in std_logic;
		RD : in std_logic;
		CLK0 : in std_logic;
		GATE0 : in std_logic;
		OUT0 : out std_logic;
		CLK1 : in std_logic;
		GATE1 : in std_logic;
		OUT1 : out std_logic;
		CLK2 : in std_logic;
		GATE2 : in std_logic;
		OUT2 : out std_logic
	);
end component;

begin

	--
	-- Instantiation
	--
	CPU0 : T80s port map (
			RESET_n => ZRST,
			CLK_n => CPUCLK,
			WAIT_n => ZWAIT,
			INT_n => INT,
			NMI_n => '1',
			BUSRQ_n => ZBREQ,
			M1_n => M1,
			MREQ_n => MREQ,
			IORQ_n => IORQ,
			RD_n => ZRD,
			WR_n => ZWR,
			RFSH_n => open,	--RFSH,
			HALT_n => open,
			BUSAK_n => ZBACK,
			A => ZA16,
			DI => DI,
			DO => ZDO);

	PLL0 : pll25 port map(
			inclk0 => pClk21m,        -- 21.48MHz
			c0     => CLK25,          -- 25MHz
			c1     => memclk,         -- 85.92MHz = 21.48MHz x 4
			e0     => pMemClk);       -- 85.92MHz external

	CGEN0 : ckgen PORT MAP (
			CLK21	=> pClk21m,
			CPUCLK	=> CPUCLK);

	DEC0 : memsel port map (
			RST		=> URST,
			CLK		=> CPUCLK,
			M1		=> M1,
			MREQ	=> MREQ,
			IORQ	=> IORQ,
			RD		=> ZRD,
			WR		=> WR,
			A		=> A16,
			DI		=> DO,
			LED0	=> open,
			LED1	=> open,
			ZWAIT	=> ZWAIT,
			CS00	=> CS00,
			CSVRAM  => CSVRAM,
			CSCG	=> CSCG,
			CGSEL	=> CGSEL,
			CSE8	=> CSE8,
			CSPPI	=> CSPPI,
			CSPIT	=> CSPIT,
			CS367	=> CS367,
			CSPCG	=> CSPCG,
			CS1		=> CS1);

	PCG0 : pcg PORT MAP (
			PCGA   => PCGA,
			PCGD   => PCGD,
			PCGWP  => PCGWP,
			PCGCPY => PCGCPY,
			CSPCG  => CSPCG,
			WR	   => WR,
			A	   => A16(1 downto 0),
			DI	   => DO,
			DO     => PCGREG,
			MCLK	=> CPUCLK);

--	CVRAM0 : dpram2k PORT MAP (
--			address_a	=> A16(10 downto 0),
--			address_b	=> VADR,
--			clock_a		=> CPUCLK,
--			clock_b		=> DCLK,
--			data_a		=> DO,
--			data_b		=> "00000000",
--			wren_a		=> WECV,
--			wren_b		=> '1',
--			q_a			=> CVDI,
--			q_b			=> DCODE);

--	AVRAM0 : dpram2k PORT MAP (
--			address_a	=> A16(10 downto 0),
--			address_b	=> VADR,
--			clock_a		=> CPUCLK,
--			clock_b		=> DCLK,
--			data_a		=> DO,
--			data_b		=> "00000000",
--			wren_a		=> WEAV,
--			wren_b		=> '1',
--			q_a			=> AVDI,
--			q_b			=> ATDAT);

	VGA0 : vgaout port map (
			RST		=> URST,
--			HC => HC,
--			HEN => HEN,
--			VEN => VEN,
--			SD => R,
			TVADRC => TVADRC,
			TBUFWP => TBUFWP,
			TBUFPT => TBUFPT,
			THDEN => THDEN,
			TBWEN => TBWEN,
			TBWD => TBWD,
			TSDAT => TSDAT,
			CLK21	=> pClk21m,
			CLK25	=> CLK25,
			DCLK	=> DCLK,
			RED		=> pDac_VR,
			GRN		=> pDac_VG,
			BLUE	=> pDac_VB,
			HSOUT	=> HSPLS,		-- pVideoHS_n,
			VSOUT	=> pVideoVS_n,
			VBLNK	=> VBLNK,
			FDAT	=> CGDAT,
			FADR	=> FADR,
			CSO		=> GCS,
			-- from/to Main CPU
			ZCLK	=> CPUCLK,
			ZADR	=> ZA16,
			ZDI		=> DO,
			IORQ	=> IORQ,
			ZWR		=> WR,
			SW		=> pDip(1 downto 0),
			PCGSW	=> PCGSW);

	RAM0 : sdram port map (
			RST		=> URST,
			MEMCLK	=> memclk,
			TPC => TPC,
			AA		=> RAMA,
			DAI		=> DO,
			DAO		=> RAMDI,
			CSA		=> RAMCS,
			WRA		=> WEMM,
			AB		=> "1000000"&SA16,
			DBI		=> SDO,
			DBO		=> SRAMDI,
			CSB		=> SRAMCS,
			RDB		=> SRD,
			WRB	 	=> SWR,
			WAITB	=> SWAIT,
			AC		=> "00000"&FADR&"00",
			DCO		=> CGDAT,
			CSC		=> GCS,
			AD		=> "00000"&"1011"&PCGA(10)&'1'&PCGA(9 downto 0)&"00",
			DDI		=> PCGD,
			CSD		=> PCGWP,
			CPYMODE => PCGCPY,
			MA		=> pMemAdr,
			MBA0	=> pMemBa0,
			MBA1	=> pMemBa1,
			MDI		=> pMemDat,
			MDO		=> RAMDO,
			MDOE	=> MDOE,
			MLDQ	=> pMemLdq,
			MUDQ	=> pMemUdq,
			MCAS	=> pMemCas_n,
			MRAS	=> pMemRas_n,
			MCS		=> pMemCs_n,
			MWE		=> pMemWe_n,
			MCKE	=> pMemCke);

	BSEL<="000000"&(not (CS00 and CSE8)) when ZRST='1' and ZBACK='1' else '0' & SEA6;
	RAMCS<=(CS1 and CS00 and CSE8 and CSVRAM and CSCG) when ZRST='1' and ZBACK='1' else SCSM;
	RAMA<="0000010"&"0000"&A16(9 downto 0)&A16(11)&A16(10) when CSVRAM='0' else
		  "0000010"&'1'&(not A16(12))&A16(11 downto 0)&CGSEL			   when CSCG='0'   else
		  BSEL & A16;

	GPIO0 : ls367 port map (
			RST => URST,
			CLKIN => CPUCLK,
			CLKOUT => SCLK,
			GATE => SOUNDEN,
			CS => CS367,
			WR => WR,
			DI => DO,
			DO => DO367);

	PPI0 : i8255 port map (
			RST => URST,
			A => A16(1 downto 0),
			CS => CSPPI,
			WR => WR,
			DI => DO,
			DO => DOPPI,
			LDDAT => open,
--			LDDAT2 => LD(5),
--			LDSNS => LD(6),
			CLKIN => SCLK,
			KCLK => CPUCLK,
--			FCLK => NTSCCLK,
			VBLNK => VBLNK,
			INTMSK => INTMSK,
			RBIT => RBIT,
			SENSE => PLYSW,		-- SW(0),
			MOTOR => MOTOR,
			PS2CK => pPs2Clk,
			PS2DT => pPs2Dat,
			-- for Sub processor
			KEY_UP => KEY_UP,
			KEY_DOWN => KEY_DOWN,
			KEY_LEFT => KEY_LEFT,
			KEY_RIGHT => KEY_RIGHT,
			KEY_CR => KEY_CR,
			KEY_SPACE => KEY_SPACE,
			ALT_ALT => ALT_ALT,
			ALT_EXIT => ALT_EXIT,
			ALT_PLAY => ALT_PLAY,
			ALT_STOP => ALT_STOP,
			ALT_CG => ALT_CG,
			ALT_PCG => ALT_PCG,
			-- for Joystick
--			JOYA => "000000",
--			JOYB => "000000");
			JOYA => not pJoyA,
			JOYB => not pJoyB);

--	PSIO0 : psio port map (
--			-- common
--			RST  => URST,
--			FCLK => pClk21m,
--			CLK  => not CPUCLK,
--			ADR  => SA16,
--			EADR => SEA6,
--			DI	 => RAMDI,
--			RAMDI => SRAMDI,
--			DO	 => SDO,
--			RD	 => SRD,
--			WR	 => SWR,
--			CSM  => SCSM,
--			RAMCS => SRAMCS,
--			CSD0 => SCSD0,
--			CSD8 => SCSD8,
--			SWAIT => SWAIT,
--			-- for Sub-Z80
--			KEY_UP => KEY_UP,
--			KEY_DOWN => KEY_DOWN,
--			KEY_LEFT => KEY_LEFT,
--			KEY_RIGHT => KEY_RIGHT,
--			KEY_CR => KEY_CR,
--			KEY_SPACE => KEY_SPACE,
--			ALT_ALT => ALT_ALT,
--			ALT_EXIT => ALT_EXIT,
--			ALT_PLAY => ALT_PLAY,
--			ALT_STOP => ALT_STOP,
--			TPMA => TPMA,
--			TPMI => TPMI,
--			TMRD => TMRD,
--			TMWR => TMWR,
--			--TINT => TINT,
--			TEPCCK => TEPCCK,
--			TEPCDO => TEPCDO,
--			TEPCCS => TEPCCS,
--			TEPCDI => TEPCDI,
--			-- from/to Main CPU
--			ZRST => ZRST,
--			ZADR => A16,
--			ZDI  => DO,
--			ZDO  => DOPS,
--			MREQ => MREQ,
--			IORQ => IORQ,
--			ZWR	 => ZWR,
--			ZRD	 => ZRD,
--			ZBRQ => ZBREQ,
--			ZBAK => ZBACK,
--			-- MMC I/F
--			MMCCK => MMCCK,	--pSd_Ck,	--MMCCK,
--			MMCCS => MMCCS,	--pSd_Dt(3),	--MMCCS,
--			MMCDI => MMCDI,	--pSd_Dt(0),	--MMCDI,
--			MMCDO => MMCDO,	--pSd_Cm,	--MMCDO,
--			-- FDD
--			CSFDD => CSFDD,
--			INUSE1 => FDD1,
--			INUSE2 => FDD2,
--			-- I/O
--			CSPRT => CSPRT,
--			RBIT => RBIT,
--			PLYSW => PLYSW,
--			MOTOR => MOTOR);

	PIT0 : i8253 port map (
			RST => URST,
			CLK => CPUCLK,
			A => A16(1 downto 0),
			DI => DO,
			DO => DOPIT,
			CS => CSPIT,
			WR => WR,
			RD => ZRD,
			CLK0 => DIV4(1),
			GATE0 => SOUNDEN,
			OUT0 => XSPKOUT,
			CLK1 => HCLK,
			GATE1 => '1',
			OUT1 => CASCADE,
			CLK2 => CASCADE,
			GATE2 => '1',
			OUT2 => INTX);

	--
	-- Reset
	--
	process( pSltRst_n, CPUCLK ) begin
		if( pSltRst_n='0' ) then
			RCOUNT<=(others=>'0');
		elsif( CPUCLK'event and CPUCLK='1' ) then
			if( RCOUNT(10)='0' ) then
				RCOUNT<=RCOUNT+'1';
			end if;
		end if;
	end process;
	URST<=RCOUNT(10);

	--
	-- Clock for TONE
	--
	process( CPUCLK, URST ) begin
		if( URST='0' ) then
			DIV4<=(others=>'0');
		elsif( CPUCLK'event and CPUCLK='1' ) then
			DIV4<=DIV4+'1';
		end if;
	end process;

	--
	-- clock for Timer
	--
	process( HSPLS, URST ) begin
		if( URST='0' ) then
			HCLK0<='0';
		elsif( HSPLS'event and HSPLS='1' ) then
			HCLK0<=not HCLK0;
		end if;
	end process;
	HCLK<=HCLK0 when pDip(0)='0' else HSPLS;

	--
	-- Data Bus
	--
	--DI<=CVDI when CSD0='0' else
	--	AVDI when CSD8='0' else
	DI<=RAMDI when CS1='0' or CS00='0' or CSE8='0' or ((ZRST='0' or ZBACK='0') and SCSM='0') or CSVRAM='0' or CSCG='0' else
		DO367 when CS367='0' else
		DOPPI when CSPPI='0' else
		DOPIT when CSPIT='0' else
		DOPS when CSPRT='0' or CSFDD='0' else
		PCGREG when CSPCG='0' else
		(others=>'1');
	pMemDat<=RAMDO when MDOE='1' else (others=>'Z');

	--
	-- Write enable
	--
	--WECV<=WR or CSD0;
	--WEAV<=WR or CSD8;
	WEMM<=ZWR or (not (CS00 and CSE8) or (not (CGSEL(0) or CGSEL(1) or CSCG))) when ZRST='1' and ZBACK='1' else SWR;

	--
	-- LED
	--
--	pLed<=(others=>'0');
--	pLed<=TBWD;	--TBUFPT&"00";
	pLed<=(not MMCCS)&MOTOR&'0'&FDD1&FDD2&"00"&PCGSW;
	pLedPwr<='1';

	--
	-- Bus control
	--
	A16 <=ZA16  when ZRST='1' and ZBACK='1' else SA16;
	--CSD0<=ZCSD0 when ZRST='1' and ZBACK='1' else SCSD0;
	--CSD8<=ZCSD8 when ZRST='1' and ZBACK='1' else SCSD8;
	DO  <=ZDO   when ZRST='1' and ZBACK='1' else SDO;
	WR  <=ZWR   when ZRST='1' and ZBACK='1' else SWR;

	--
	-- Misc
	--
	pVideoHS_n<=HSPLS;
	pDac_SL<=not (XSPKOUT&XSPKOUT&XSPKOUT&XSPKOUT&XSPKOUT&XSPKOUT);
	pDac_SR<="000000";
	INT<=not (INTX and INTMSK);
	process( ALT_CG, ALT_PCG ) begin
		if( ALT_CG='1' ) then
			PCGSW<='0';
		elsif( ALT_PCG='1' ) then
			PCGSW<='1';
		end if;
	end process;

	--
	-- Debug
	--
--	pJoyA(0)<=TEPCCK;		-- IO[0]
--	pJoyA(4)<=TEPCCS;		-- IO[1]
--	pJoyA(1)<=TEPCDO;		-- IO[2]
--	pJoyA(5)<=TEPCDI;		-- IO[3]
--	pJoyA(2)<=MMCCS;		-- IO[4]
--	pStrA<=TVADRC(3);			-- IO[5]
--	pJoyA(3)<=TVADRC(4);		-- IO[6]
--	pJoyB(0)<=TVADRC(5);		-- IO[7]
--	pJoyB(4)<=TVADRC(6);		-- IO[8]
--	pJoyB(1)<=TVADRC(7);		-- IO[9]
--	pJoyB(5)<=TVADRC(8);		-- IO[10]
--	pJoyB(2)<=TVADRC(9);		-- IO[11]
--	pStrB<=TBUFWP(0);		-- IO[12]
--	pJoyB(3)<=TBUFWP(1);			-- IO[13]
--	pIopRsv14<=TBUFWP(2);
--	pIopRsv15<=TBUFWP(3);
--	pIopRsv16<=TBUFWP(4);
--	pIopRsv17<=TBUFWP(5);
--	pIopRsv18<=GCS;
--	pIopRsv19<=TPC;
--	pIopRsv20<=TBMASK(6);
--	pIopRsv21<=TBMASK(7);

--	pLed<=SDO when SWR='0' else TDI when SRD='0' else (others=>'0');
--	pJoyA(0)<='1' when TDI=X"CD" and TM1='0' and CPUCLK='0' else '0';		-- IO[0]
--	pJoyA(4)<=SWR;			-- IO[1]
--	pJoyA(1)<=SRD;			-- IO[2]
--	pJoyA(5)<=TM1;			-- IO[3]
--	pJoyA(2)<=SRAMCS;		-- IO[4]
--	pStrA<=CPUCLK;			-- IO[5]
--	pJoyA(3)<=TADR(0);		-- IO[6]
--	pJoyB(0)<=TADR(1);		-- IO[7]
--	pJoyB(4)<=TADR(2);		-- IO[8]
--	pJoyB(1)<=TADR(3);		-- IO[9]
--	pJoyB(5)<=TADR(4);		-- IO[10]
--	pJoyB(2)<=TADR(5);		-- IO[11]
--	pStrB<=TADR(6);			-- IO[12]
--	pJoyB(3)<=TADR(7);		-- IO[13]
--	pIopRsv14<=TADR(8);
--	pIopRsv15<=TADR(9);
--	pIopRsv16<=TADR(10);
--	pIopRsv17<=TADR(11);
--	pIopRsv18<=TADR(12);
--	pIopRsv19<=TADR(13);
--	pIopRsv20<=TADR(14);
--	pIopRsv21<=TADR(15);

--	pLed<=ZDO when ZWR='0' else DI when ZRD='0' else (others=>'0');
--	pJoyA(0)<='1' when A16(15 downto 10)="110100" and CPUCLK='0' else '0';		-- IO[0]
--	pJoyA(0)<=RAMCS;		-- IO[0]
--	pJoyA(4)<=ZWR;			-- IO[1]
--	pJoyA(1)<=ZRD;			-- IO[2]
--	pJoyA(5)<=M1;			-- IO[3]
--	pJoyA(2)<=CS00;			-- IO[4]
--	pStrA<=CSVRAM;			-- IO[5]
--	pJoyA(3)<=A16(0);		-- IO[6]
--	pJoyB(0)<=A16(1);		-- IO[7]
--	pJoyB(4)<=A16(2);		-- IO[8]
--	pJoyB(1)<=A16(3);		-- IO[9]
--	pJoyB(5)<=A16(4);		-- IO[10]
--	pJoyB(2)<=A16(5);		-- IO[11]
--	pStrB<=A16(6);			-- IO[12]
--	pJoyB(3)<=A16(7);		-- IO[13]
--	pIopRsv14<=A16(8);
--	pIopRsv15<=A16(9);
--	pIopRsv16<=A16(10);
--	pIopRsv17<=A16(11);
--	pIopRsv18<=A16(12);
--	pIopRsv19<=A16(13);
--	pIopRsv20<=A16(14);
--	pIopRsv21<=A16(15);


--	pDac_VR<=R;
--	pDac_VG<=G;
--	pDac_VB<=B;
--	pVideoHS_n<=HS;
--	pVideoVS_n<=VS;
--	pMemAdr<=MA;
--	pMemCas_n<=MCAS;
--	pMemRas_n<=MRAS;
--	pMemCs_n<=MCS;
--	pMemWe_n<=TWE;
	pSd_Ck<=MMCCK;
	pSd_Cm<=MMCDO;
	pSd_Dt(3)<=MMCCS;
	MMCDI<=pSd_Dt(0);

end rtl;
