--
-- psio.vhd
--
-- Peripheral and Storage I/O module
-- for MZ-80A on FPGA
--
-- Peripheral : Printer(status only)
-- Storage : Tape/FD/QD support with SD-card/MMC
--
-- Nibbles Lab. 2007
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity psio is
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
		ZCLK : in std_logic;
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
		MOTOR : in std_logic);
end psio;

architecture Behavioral of psio is

--
-- Sub AVR
--
signal ARST : std_logic;
signal PMA : std_logic_vector(15 downto 0);
signal PMI : std_logic_vector(15 downto 0);
signal IOA : std_logic_vector(5 downto 0);
signal IORE : std_logic;
signal IOWE : std_logic;
signal AB : std_logic_vector(15 downto 0);
signal RAMR : std_logic;
signal RAMW : std_logic;
signal SDI : std_logic_vector(7 downto 0);
signal SDO : std_logic_vector(7 downto 0);
signal SDOi : std_logic_vector(7 downto 0);
signal PAGE : std_logic_vector(7 downto 0);
signal MODE : std_logic;
signal MODEi : std_logic;
signal RAMCSi : std_logic;
signal CSMi : std_logic;
signal CSD0i : std_logic;
signal CSD8i : std_logic;
signal P1O : std_logic_vector(7 downto 0);
signal P2O : std_logic_vector(7 downto 0);
signal P1I : std_logic_vector(7 downto 0);
signal P2I : std_logic_vector(7 downto 0);
signal P3I : std_logic_vector(7 downto 0);
signal AVRWAIT : std_logic;
--
-- EPCS
--
signal EPR : std_logic;
signal EPRR : std_logic;
signal EPW : std_logic;
signal EPWR : std_logic;
signal ECOUNT : std_logic_vector(4 downto 0);
signal EPCD : std_logic_vector(7 downto 0);
signal EPMODE : std_logic;
signal EPWD : std_logic_vector(7 downto 0);
signal EPCR : std_logic_vector(7 downto 0);
signal EPCCK : std_logic;
signal EPCDO : std_logic;
signal EPCCS : std_logic;
signal EPCDI : std_logic;
signal EPCOE : std_logic;
signal EPWi : std_logic;
signal EPWRi : std_logic;
signal EPRi : std_logic;
--
-- MMC
--
signal MCOUNT : std_logic_vector(4 downto 0);
signal MMWi : std_logic;
signal MMW : std_logic;
signal MMRi : std_logic;
signal MMR : std_logic;
signal MMMODE : std_logic;
signal MMCD : std_logic_vector(7 downto 0);
signal MMWD : std_logic_vector(7 downto 0);
signal MMCR : std_logic_vector(7 downto 0);
--
-- MB8877(FDD)
--
signal CSFDD0 : std_logic;
signal FDCMD : std_logic_vector(7 downto 0);
signal FDTR : std_logic_vector(7 downto 0);
signal FDSR : std_logic_vector(7 downto 0);
signal FDWD : std_logic_vector(7 downto 0);
signal FDMTR : std_logic;
signal FDSEL : std_logic;
signal FDDRV : std_logic_vector(1 downto 0);
signal FDTR0 : std_logic_vector(1 downto 0);
signal FDSID : std_logic;
signal FDSTS : std_logic_vector(7 downto 0);
signal FDRD : std_logic_vector(7 downto 0);
signal FDINT : std_logic_vector(1 downto 0);
signal FDCMDINT : std_logic;
signal FDWRINT : std_logic;
signal FDRDINT : std_logic;
--
-- Printer
--
signal CSPRT0 : std_logic;
--
-- SHARP PWM
--
signal BCTR : std_logic_vector(11 downto 0);
signal BP : std_logic;
signal BBUSY : std_logic;

attribute keep: boolean;
attribute keep of MMCCK: signal is true;
attribute keep of MMCCS: signal is true;
attribute keep of MMCDI: signal is true;
attribute keep of MMCDO: signal is true;
attribute keep of ARST: signal is true;
attribute keep of IOA: signal is true;
attribute keep of CLK: signal is true;

--
-- Buffer
--
--
-- for Debug
--

--
-- Components
--
component AVR_Core
	port
	(
		--Clock and reset
		cp2         : in  std_logic;
		cp2en       : in  std_logic;
		ireset      : in  std_logic;
		-- JTAG OCD support
		valid_instr : out std_logic;
		insert_nop  : in  std_logic;
		block_irq   : in  std_logic;
		change_flow : out std_logic;
		-- Program Memory
		pc          : out std_logic_vector(15 downto 0);
		inst        : in  std_logic_vector(15 downto 0);
		-- I/O control
		adr         : out std_logic_vector(5 downto 0);
		iore        : out std_logic;
		iowe        : out std_logic;
		-- Data memory control
		ramadr      : out std_logic_vector(15 downto 0);
		ramre       : out std_logic;
		ramwe       : out std_logic;
		cpuwait     : in  std_logic;
		-- Data paths
		dbusin      : in  std_logic_vector(7 downto 0);
		dbusout     : out std_logic_vector(7 downto 0);
		-- Interrupt
		irqlines    : in  std_logic_vector(22 downto 0);
		irqack      : out std_logic;
		irqackad    : out std_logic_vector(4 downto 0);
		--Sleep Control
		sleepi	    : out std_logic;
		irqok	    : out std_logic;
		globint	    : out std_logic;
		--Watchdog
		wdri	    : out std_logic
	);
end component;

component avrrom
	port (
		-- ROM
		address		: in std_logic_vector(12 downto 0);
		clock		: in STD_LOGIC ;
		q			: out std_logic_vector(15 downto 0);
		-- DPRAM
		WADR		: in std_logic_vector(13 downto 0);
		WDAT		: in std_logic_vector(7 downto 0);
		WREN		: in std_logic;
		MODE		: in std_logic);
end component;

component cyclone_asmiblock
	port
	( 
		data0out	:	OUT STD_LOGIC;
		dclkin		:	IN STD_LOGIC;
		oe			:	IN STD_LOGIC := '1';
		scein		:	IN STD_LOGIC;
		sdoin		:	IN STD_LOGIC
	); 
end component;

begin

	--
	-- Instantiation
	--
	CPU1 : AVR_Core port map (
		--Clock and reset
		cp2		   => CLK,
		cp2en	   => '1',
		ireset	   => ARST,
		-- JTAG OCD support
		valid_instr=> open,
		insert_nop => '0',
		block_irq  => '0',
		change_flow=> open,
		-- Program Memory
		pc		   => PMA,
		inst	   => PMI(7 downto 0)&PMI(15 downto 8),
		-- I/O control
		adr		   => IOA,
		iore	   => IORE,
		iowe	   => IOWE,
		-- Data memory control
		ramadr	   => AB,
		ramre	   => RAMR,
		ramwe	   => RAMW,
		cpuwait	   => SWAIT,	--'0',
		-- Data paths
		dbusin	   => SDI,
		dbusout	   => SDO,
		-- Interrupt
		irqlines   => "00000000000000000000"&FDRDINT&FDWRINT&FDCMDINT,
		irqack	   => open,
		irqackad   => open,
		--Sleep Control
		sleepi	   => open,
		irqok	   => open,
		globint	   => open,
		--Watchdog
		wdri	   => open
		);

	SubROM : avrrom port map (
		-- ROM
		address	=> PMA(12 downto 0),
		clock	=> not CLK,
		q		=> PMI,
		-- DPRAM
		WADR	=> AB(13 downto 0),
		WDAT	=> SDO,
		WREN	=> RAMW,
		MODE	=> MODE);

TPMA<=PMA(6 downto 0)&'0';
--TPMA<=SDO;
--TPMA<=SDI;
--TPMA<=EPCR;
--TPMI<=SDO&"00000000";
--TPMI<=AB;
TPMI<=PMA;
--TPMI<=PMI(7 downto 0)&PMI(15 downto 8);
TMRD<=RAMR;
TMWR<=RAMW;

	EPCS0 : cyclone_asmiblock port map (
			data0out => EPCDI,
			dclkin	 => EPCCK,
			oe		 => EPCOE,
			scein	 => EPCCS,
			sdoin	 => EPCDO); 

	--
	-- Address decode
	--
	-- Memory:
	--   0000 - 7FFF  MEMCS
	--   8000 - FFFF  CSM
	--
	-- CSM area:
	--   PAGE
	--    00    main RAM (0000 - 7FFF)
	--    01    main RAM (8000 - FFFF)
	--    02    Monitor ROM (0000 - 0FFF)
	--    03    SubMon ROM (E800 - FFFF)
	--    04    VRAM/AttRAM (D000 - DFFF) interleave
	--    05    CGROM(D000 - DFFF), PCG(D000 - EFFF) interleave
	--
	-- I/O:
	--       R      W
	--   00 P1I    P1O
	--   01 P2I    P2O
	--   02 P3I
	--   03 
	--   04 
	--   05        EPCCS
	--   06 EPCR   EPWD
	--   07 EPCRR  EPWDR
	--   08        PAGE
	--   09        MMCCS
	--   0A MMCR   MMWD
	--   0B
	--   0C
	--   0D
	--   0E        PRST
	--   0F BBUSY  POUT
	--   10 FDCMD  FDSTS
	--   11 FDTR
	--   12 FDSR
	--   13 FDmisc
	--   14 FDWD   FDRD
	--   15        FDINT
	--
	RAMCSi<=AB(15);
	CSMi  <='0' when AB(15)='1' and PAGE(7)='0' else '1';
	CSD0i <='0' when AB(15 downto 11)="11010" and PAGE(7)='1' else '1';
	CSD8i <='0' when AB(15 downto 11)="11011" and PAGE(7)='1' else '1';
	EPR   <='1' when IORE='1' and IOA="000110" else '0';
	EPRR  <='1' when IORE='1' and IOA="000111" else '0';
	EPW   <='1' when IOWE='1' and IOA="000110" else '0';
	EPWR  <='1' when IOWE='1' and IOA="000111" else '0';
	MMR   <='1' when IORE='1' and IOA="001010" else '0';
	MMW   <='1' when IOWE='1' and IOA="001010" else '0';

	--
	-- Data bus
	--
	SDI<=RAMDI when RAMR='1' and RAMCSi='0' else
		 --DI    when RAMR='1' and (CSD0i='0' or CSD8i='0') else
		 DI   when RAMR='1' and CSMi='0' else
		 MMCR  when MMR='1'   else
		 P1I   when IORE='1' and IOA="000000" else
		 P2I   when IORE='1' and IOA="000001" else
		 P3I   when IORE='1' and IOA="000010" else
		 EPCR  when EPR='1'   else
		 "0000000"&BBUSY when IORE='1' and IOA="001111" else
		 EPCR(0)&EPCR(1)&EPCR(2)&EPCR(3)&EPCR(4)&EPCR(5)&EPCR(6)&EPCR(7) when EPRR='1'   else
		 FDCMD when IORE='1' and IOA="010000" else
		 FDTR  when IORE='1' and IOA="010001" else
		 FDSR  when IORE='1' and IOA="010010" else
		 FDMTR&FDSEL&FDDRV&"000"&FDSID when IORE='1' and IOA="010011" else
		 FDWD  when IORE='1' and IOA="010100" else
		 (others=>'1');

	WR<=not RAMW;
	RD<=not RAMR;
	DO<=SDOi;
	RAMCS<='0' when RAMCSi='0' and (RAMR='1' or RAMW='1') and CLK='1' else '1';
	CSM<='0' when CSMi='0' and (RAMR='1' or RAMW='1') else '1';
	CSD0<='0' when CSD0i='0' and (RAMR='1' or RAMW='1') else '1';
	CSD8<='0' when CSD8i='0' and (RAMR='1' or RAMW='1') else '1';

	ADR(14 downto 0)<=AB(14 downto 0);
	ADR(15)<=PAGE(0) when AB(15)='1' else '0';
	EADR<=PAGE(6 downto 1);

	--
	-- Timing conditioning
	--
	process( RST, CLK ) begin
		if( RST='0' ) then
			SDOi<=(others=>'0');
		elsif( CLK'event and CLK='1' ) then
			SDOi<=SDO;
		end if;
	end process;

	--
	-- Registers
	--
	process( RST, CLK ) begin
		if( RST='0' ) then
			P1O<=(others=>'0');
			P2O<=(others=>'0');
			EPCCS<='1';
			MMCCS<='1';
			MODE<='0';
			FDSTS<=(others=>'0');
			FDRD<=(others=>'0');
			FDINT<=(others=>'0');
		elsif( CLK'event and CLK='0' ) then
			MODEi<=MODE;
			if( IOWE='1' ) then
				if( IOA="000000" ) then
					if( MODE='0' ) then
						MODE<='1';
					else
						P1O<=SDO;
					end if;
				elsif( IOA="000001" ) then
					P2O<=SDO;
				elsif( IOA="000101" ) then
					EPCCS<=SDO(0);
				elsif( IOA(5 downto 1)="00011" ) then
					EPWD<=SDO;
				elsif( IOA="001000" ) then
					PAGE<=SDO;
				elsif( IOA="001001" ) then
					MMCCS<=SDO(0);
				elsif( IOA="001010" ) then
					MMWD<=SDO;
				elsif( IOA="010000" ) then
					FDSTS<=SDO;
				elsif( IOA="010011" ) then
					if( FDDRV="00" ) then
						FDTR0(0)<=SDO(0);
					elsif( FDDRV="00" ) then
						FDTR0(1)<=SDO(0);
					end if;
				elsif( IOA="010100" ) then
					FDRD<=SDO;
				elsif( IOA="010101" ) then
					FDINT<=SDO(1 downto 0);
				end if;
			end if;
		end if;
	end process;
	ZRST<=P1O(7);
	ZBRQ<=not P1O(6);
	P1I<="0"&ZBAK&"000000";
	P2I<="00"  &KEY_UP  &KEY_DOWN&KEY_LEFT&KEY_RIGHT&KEY_CR  &KEY_SPACE;
	P3I<="0000"                  &ALT_STOP&ALT_PLAY &ALT_EXIT&ALT_ALT;

	ARST<=RST and (MODEi or (not MODE));
--	TARST<=MODE;
--	TARST<=ARST;

--TADR<=MMCR;

	--
	-- EPCS I/F
	--
	process( RST, FCLK ) begin
		if( RST='0' ) then
			ECOUNT<="10000";
			EPCD<=(others=>'1');
		elsif( FCLK'event and FCLK='1' ) then
			EPWi<=EPW;
			EPWRi<=EPWR;
			EPRi<=EPR;
			if( EPWi='1' and EPW='0' ) then
				ECOUNT<=(others=>'0');
				EPMODE<='1';
				EPCD<=EPWD;
			elsif( EPWRi='1' and EPWR='0' ) then
				ECOUNT<=(others=>'0');
				EPMODE<='1';
				EPCD<=EPWD(0)&EPWD(1)&EPWD(2)&EPWD(3)&EPWD(4)&EPWD(5)&EPWD(6)&EPWD(7);
			elsif( EPRi='1' and EPR='0' ) then
				ECOUNT<=(others=>'0');
				EPMODE<='0';
			end if;

			if( ECOUNT(4)='0' ) then
				ECOUNT<=ECOUNT+'1';
				if( ECOUNT(0)='1' and EPMODE='1' ) then
					EPCD<=EPCD(6 downto 0)&'1';
				elsif( ECOUNT(0)='0' and EPMODE='0' ) then
					EPCR<=EPCR(6 downto 0)&EPCDI;
				end if;
			end if;
		end if;
	end process;
	EPCCK<=ECOUNT(0) or ECOUNT(4);
	EPCDO<=EPCD(7);
	EPCOE<='1' when RST='0' else '0';

TEPCCK<=EPCCK;
TEPCDO<=EPCDO;
TEPCCS<=EPCCS or not MODE;
TEPCDI<=EPCDI;

	--
	-- MMC I/F
	--
	process( RST, FCLK ) begin
		if( RST='0' ) then
			MCOUNT<="10000";
			MMCD<=(others=>'1');
		elsif( FCLK'event and FCLK='1' ) then
			MMWi<=MMW;
			MMRi<=MMR;
			if( MMWi='1' and MMW='0' ) then
				MCOUNT<=(others=>'0');
				MMMODE<='1';
				MMCD<=MMWD;
			elsif( MMRi='1' and MMR='0' ) then
				MCOUNT<=(others=>'0');
				MMMODE<='0';
			end if;

			if( MCOUNT(4)='0' ) then
				MCOUNT<=MCOUNT+'1';
				if( MCOUNT(0)='1' and MMMODE='1' ) then
					MMCD<=MMCD(6 downto 0)&'1';
				elsif( MCOUNT(0)='0' and MMMODE='0' ) then
					MMCR<=MMCR(6 downto 0)&MMCDI;
				end if;
			end if;
		end if;
	end process;
	MMCCK<=MCOUNT(0) or MCOUNT(4);
	MMCDO<=MMCD(7);

	--
	-- Genarate bit by SHARP PWM
	--
	process( CLK, RST ) begin
		if( RST='0' ) then
			BP<='0';
			BBUSY<='0';
		elsif( CLK'event and CLK='0' ) then
			if( IOWE='1' ) then
				if( IOA="001111" ) then -- set '0'/'1' from AVR-core
					BP<=SDO(7);
					BBUSY<='1';
					BCTR<=(others=>'0');
				elsif( IOA="001110" ) then -- reset counter
					PLYSW<=SDO(0);
					BBUSY<='0';
					BCTR<=(others=>'0');
				end if;
			end if;
			if( BBUSY='1' and MOTOR='1' ) then
				if( BCTR=0 ) then
					RBIT<='1';
				elsif( BCTR=766 and BP='0' ) then
					RBIT<='0';
				elsif( BCTR=1507 and BP='1' ) then
					RBIT<='0';
				end if;
				if(( BCTR=1533 and BP='0' ) or ( BCTR=3040 and BP='1' )) then
					BCTR<=(others=>'0');
					BBUSY<='0';
				else
					BCTR<=BCTR+1;
				end if;
			end if;
		end if;
	end process;

	--
	-- Main access
	--
	ZDO<="00000010" when CSPRT0='0' and ZADR(0)='0'			  else
		(not (FDSTS(7 downto 3)&FDTR0(0)&FDSTS(1 downto 0))) when CSFDD0='0' and ZADR(2 downto 0)="000" and FDCMD(7)='0' and FDDRV="00" else
		(not (FDSTS(7 downto 3)&FDTR0(1)&FDSTS(1 downto 0))) when CSFDD0='0' and ZADR(2 downto 0)="000" and FDCMD(7)='0' and FDDRV="01" else
		(not FDSTS)	when CSFDD0='0' and ZADR(2 downto 0)="000" and FDCMD(7)='1' else
		 (not FDTR)	when CSFDD0='0' and ZADR(2 downto 0)="001" else
		 (not FDSR)	when CSFDD0='0' and ZADR(2 downto 0)="010" else
		 (not FDRD)	when CSFDD0='0' and ZADR(2 downto 0)="011" else (others=>'0');

	--
	-- Printer
	--
	CSPRT0<='0' when ZADR(7 downto 1)="1111111" and IORQ='0' else '1';
	CSPRT<=CSPRT0;

	--
	-- FDD
	--
	CSFDD0<='0' when ZADR(7 downto 3)="11011" and IORQ='0' else '1';
	CSFDD<=CSFDD0;

	--
	-- FDC registers
	--
	process( ZCLK, ZWR, P1O(7), CSFDD0 ) begin
		if( P1O(7)='0' ) then
			FDCMD<=(others=>'0');
			FDTR<=(others=>'0');
			FDSR<=(others=>'0');
			FDWD<=(others=>'0');
			FDMTR<='0';
			FDSEL<='0';
			FDDRV<=(others=>'0');
			FDSID<='0';
--		elsif( CLK'event and CLK='0' and ZWR='0' and CSFDD0='0' ) then
		elsif( ZCLK'event and ZCLK='0' ) then
			if( ZWR='0' and CSFDD0='0' ) then
				if( ZADR(2 downto 0)="000" ) then
					FDCMD<=not ZDI;
				elsif( ZADR(2 downto 0)="001" ) then
					FDTR<=not ZDI;
				elsif( ZADR(2 downto 0)="010" ) then
					FDSR<=not ZDI;
				elsif( ZADR(2 downto 0)="011" ) then
					FDWD<=not ZDI;
				elsif( ZADR(2 downto 0)="100" ) then
					FDMTR<=ZDI(7);
					FDSEL<=ZDI(2);
					FDDRV<=ZDI(1 downto 0);
				elsif( ZADR(2 downto 0)="101" ) then
					FDSID<=ZDI(0);
				end if;
			end if;
			if( IOWE='1' ) then
				if( IOA="010001" ) then
					FDTR<=SDO;
				elsif( IOA="010010" ) then
					FDSR<=SDO;
				end if;
			end if;
		end if;
	end process;
	INUSE1<='1' when FDMTR='1' and FDSEL='1' and FDDRV="00" else '0';
	INUSE2<='1' when FDMTR='1' and FDSEL='1' and FDDRV="01" else '0';

	--
	-- FD interrupt
	--
	process( P1O(7), CLK ) begin
		if( P1O(7)='0' ) then
			FDCMDINT<='0';
			FDWRINT<='0';
			FDRDINT<='0';
		elsif( CLK'event and CLK='1' ) then
			if( ZWR='0' and CSFDD0='0' and ZADR(2 downto 0)="000" ) then
				FDCMDINT<='1';
			elsif( ZWR='0' and CSFDD0='0' and ZADR(2 downto 0)="011" ) then
				FDWRINT<=FDINT(1);
			elsif( ZRD='0' and CSFDD0='0' and ZADR(2 downto 0)="011" ) then
				FDRDINT<=FDINT(0);
			end if;
			if( IORE='1' and IOA="010000" ) then
				FDCMDINT<='0';
			elsif( IORE='1' and IOA="010100" ) then
				FDWRINT<='0';
			elsif( IOWE='1' and IOA="010100" ) then
				FDRDINT<='0';
			end if;
		end if;
	end process;

end Behavioral;
