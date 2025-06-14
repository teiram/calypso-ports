--
-- vgaout.vhd
--
-- VGA display signal generator 
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity vgaout is
    Port ( RST : in std_logic;
-- for sim
--		HC : out std_logic_vector(8 downto 0);
--		VC : out std_logic_vector(9 downto 0);
--		HEN : out std_logic;
--		VEN : out std_logic;
--		SD : out std_logic;
-- for sim
		TVADRC : out std_logic_vector(9 downto 0);
		TBUFWP : out std_logic_vector(5 downto 0);
		TBUFPT : out std_logic_vector(5 downto 0);
		THDEN : out std_logic;
		TBWEN : out std_logic;
		TBWD : out std_logic_vector(7 downto 0);
		TSDAT : out std_logic_vector(7 downto 0);
		CLK21 : in std_logic;
		CLK25 : in std_logic;
		DCLK  : out std_logic;
		RED   : out std_logic_vector(5 downto 0);
		GRN   : out std_logic_vector(5 downto 0);
		BLUE  : out std_logic_vector(5 downto 0);
		HSOUT : out std_logic;
		VSOUT : out std_logic;
		VBLNK : out std_logic;
		FDAT  : in std_logic_vector(31 downto 0);
		FADR  : out std_logic_vector(15 downto 0);
		CSO   : out std_logic;
		-- from/to Main CPU
		ZCLK  : in std_logic;
		ZADR  : in std_logic_vector(15 downto 0);
		ZDI   : in std_logic_vector(7 downto 0);
		IORQ  : in std_logic;
		ZWR	  : in std_logic;
		SW	  : in std_logic_vector(1 downto 0);
		PCGSW : in std_logic
		);
end vgaout;

architecture Behavioral of vgaout is

component vencode
  port(
    -- VDP clock ... 21.477MHz
    clk21m  : in std_logic;
    reset   : in std_logic;

    -- Video Input
    videoR : in std_logic_vector( 5 downto 0);
    videoG : in std_logic_vector( 5 downto 0);
    videoB : in std_logic_vector( 5 downto 0);
    videoHS_n : in std_logic;
    videoVS_n : in std_logic;
    
    -- Video Output
    videoY    : out std_logic_vector( 5 downto 0);
    videoC    : out std_logic_vector( 5 downto 0);
    videoV    : out std_logic_vector( 5 downto 0)
    );
end component;

component dpram05k
  PORT(
	data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
	rdaddress	: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
	rdclock		: IN STD_LOGIC ;
	wraddress	: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
	wrclock		: IN STD_LOGIC ;
	wren		: IN STD_LOGIC  := '1';
	q			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
end component;

--
-- Clock
--
signal CLK : std_logic;
signal DIV3 : std_logic_vector(1 downto 0);
signal CTR10 : std_logic_vector(3 downto 0);
--
-- SYNC timing
--
signal HCOUNT : std_logic_vector(8 downto 0);
signal VCOUNT : std_logic_vector(9 downto 0);
signal HDISPEN : std_logic;
signal VDISPEN : std_logic;
--
-- CGROM/VRAM access
--
signal SDAT0 : std_logic_vector(7 downto 0);
signal SDAT1 : std_logic_vector(7 downto 0);
signal SDAT2 : std_logic_vector(7 downto 0);
signal SDAT : std_logic_vector(2 downto 0);
signal VADRL : std_logic_vector(9 downto 0);
signal VADRC : std_logic_vector(9 downto 0);
signal BUFD  : std_logic_vector(31 downto 0);
signal BUFPT : std_logic_vector(5 downto 0);
signal BUFWP : std_logic_vector(5 downto 0);
signal RADR	 : STD_LOGIC_VECTOR(6 DOWNTO 0);
signal WADR	 : STD_LOGIC_VECTOR(6 DOWNTO 0);
signal BUFENV : std_logic;
signal BUFENH : std_logic;
signal BWEN  : std_logic;
signal BWD0  : std_logic_vector(7 downto 0);
signal BWD1  : std_logic_vector(7 downto 0);
signal BWD2  : std_logic_vector(7 downto 0);
signal VCS   : std_logic;
signal GCS   : std_logic;
signal FCS   : std_logic;
signal DCODE : std_logic_vector(7 downto 0);
signal CSEL  : std_logic;
signal PCGEN : std_logic;
signal PCGD0 : std_logic_vector(7 downto 0);
signal PCGD1 : std_logic_vector(7 downto 0);
signal PCGD2 : std_logic_vector(7 downto 0);
signal CSPRI : std_logic;
signal CSPLT : std_logic;
--
-- forward/back color
--
signal PRIOL : std_logic;
signal DSP2EN : std_logic;
signal BMASK  : std_logic_vector(7 downto 0);
signal FMASK  : std_logic_vector(7 downto 0);
signal FMASK1 : std_logic_vector(7 downto 0);
signal FMASK2 : std_logic_vector(7 downto 0);
signal PMASK  : std_logic_vector(7 downto 0);
signal PMASK1 : std_logic_vector(7 downto 0);
signal PMASK2 : std_logic_vector(7 downto 0);
signal COLR : std_logic;
signal COLG : std_logic;
signal COLB : std_logic;
signal FCOL : std_logic_vector(2 downto 0);
signal BCOL : std_logic_vector(2 downto 0);
signal PLT0 : std_logic_vector(2 downto 0);
signal PLT1 : std_logic_vector(2 downto 0);
signal PLT2 : std_logic_vector(2 downto 0);
signal PLT3 : std_logic_vector(2 downto 0);
signal PLT4 : std_logic_vector(2 downto 0);
signal PLT5 : std_logic_vector(2 downto 0);
signal PLT6 : std_logic_vector(2 downto 0);
signal PLT7 : std_logic_vector(2 downto 0);
--
-- video signal
--
signal DR : std_logic_vector(5 downto 0);
signal DG : std_logic_vector(5 downto 0);
signal DB : std_logic_vector(5 downto 0);
signal HS : std_logic;
signal VS : std_logic;
signal VY : std_logic_vector(5 downto 0);
signal VC : std_logic_vector(5 downto 0);
signal VV : std_logic_vector(5 downto 0);

begin

	bufram : dpram05k PORT MAP (
		data	 	=> BWD0&BWD1&BWD2&"00000000",
		rdaddress	=> RADR,	--VCOUNT(1)&BUFPT,
		rdclock	 	=> CLK,
		wraddress	=> WADR,	--(not VCOUNT(1))&BUFWP,
		wrclock	 	=> CLK,
		wren		=> BWEN,
		q	 		=> BUFD
	);

	RADR<=VCOUNT(1)&BUFPT 		when SW(0)='0' else VCOUNT(0)&BUFPT;
	WADR<=(not VCOUNT(1))&BUFWP when SW(0)='0' else (not VCOUNT(0))&BUFWP;

	--
	-- Main clock select
	--
	CLK<=CLK21 when SW(0)='1' else CLK25;
	DCLK<=CLK;

	--
	-- 1/3 clock
	--
	process( RST, CLK ) begin
		if( RST='0' ) then
			DIV3<=(others=>'0');
		elsif( CLK'event and CLK='1' ) then
			if( SW(0)='1' ) then
				if( DIV3="10" ) then
					DIV3<=(others=>'0');
				else
					DIV3<=DIV3+'1';
				end if;
			else
				DIV3(1)<=not DIV3(1);
			end if;
		end if;
	end process;

	--
	-- BCD counter for 15kHz
	--
	process( RST, CLK, DIV3(1) ) begin
		if( RST='0' ) then
			CTR10<=(others=>'0');
		elsif( CLK'event and CLK='1' and DIV3(1)='1' ) then
			if( CTR10=9 or HCOUNT=1 ) then
				CTR10<=(others=>'0');
			else
				CTR10<=CTR10+'1';
			end if;
		end if;
	end process;

	--
	-- Encode Timing
	--
	process( RST, CLK, DIV3(1), HCOUNT, VCOUNT ) begin
		if( RST='0' ) then
			HCOUNT<="111111011"; -- -4
			VCOUNT<=(others=>'0');
			VS<='1';
			VDISPEN<='0';
			HS<='1';
			HDISPEN<='0';
			--SDAT<=(others=>'0');
			SDAT0<=(others=>'0');
			SDAT1<=(others=>'0');
			SDAT2<=(others=>'0');
			VADRL<=(others=>'1');
			VADRC<=(others=>'1');
			BUFPT<=(others=>'1');
			BWEN<='0';
			BUFWP<=(others=>'0');
			VCS<='1';
			GCS<='1';
			VCS<='1';
		elsif( CLK'event and CLK='1' and DIV3(1)='1' ) then
			if( ( HCOUNT=450 and SW(0)='1' )
			 or ( HCOUNT=393 and SW(0)='0' ) ) then
				HCOUNT<="111111011"; -- -4
--				VADRC<=VADRL;
				BUFPT<=(others=>'0');
--				BUFPT(6)<=VCOUNT(1); -- xor VCOUNT(0);
				if(( VCOUNT(0)='1' and SW(0)='0' ) or SW(0)='1' ) then
					BUFWP<=(others=>'0');
					VADRC<=VADRL;
				end if;
--				if( VCOUNT=261 and SW(0)='1' ) then
				if( ( VCOUNT=259 and SW(0)='1' )
				 or ( VCOUNT=518 and SW(0)='0' ) )then
					VCOUNT<=(others=>'0');
					BUFENV<='1';
					VADRL<=(others=>'0');
					VADRC<=(others=>'0');
--				elsif( VCOUNT=520 and SW(0)='0' ) then
--					VCOUNT<=(others=>'0');
--					VADRL<=(others=>'0');
--					VADRC<=(others=>'0');
				else
					VCOUNT<=VCOUNT+'1';
				end if;
			else
				HCOUNT<=HCOUNT+'1';
			end if;

			--
			-- Vertical sync
			--
			if( ( VCOUNT=1 and SW(0)='1' )
				or ( VCOUNT=2 and SW(0)='0' ) ) then
				VDISPEN<='1';
			elsif( ( VCOUNT=200 and SW(0)='1' )
				or ( VCOUNT=400 and SW(0)='0' ) ) then
				BUFENV<='0';
			elsif( ( VCOUNT=201 and SW(0)='1' )
				or ( VCOUNT=402 and SW(0)='0' ) ) then
				VDISPEN<='0';
			elsif( ( VCOUNT=222 and SW(0)='1' )
				or ( VCOUNT=452 and SW(0)='0' ) ) then
				VS<='0';
			elsif( ( VCOUNT=225 and SW(0)='1' )
				or ( VCOUNT=454 and SW(0)='0' ) ) then
				VS<='1';
			end if;

			--
			-- Horizontal sync
			--
			if( HCOUNT=1 ) then
				HDISPEN<=VDISPEN;	--'1';
				BUFENH<=BUFENV;
			--elsif( ( HCOUNT=319 and VCOUNT(2 downto 0)="111"  and SW(0)='1' )
			elsif( HCOUNT=399 and VCOUNT(2 downto 0)="111"  and SW(0)='1' ) then
				VADRL<=VADRC;
			elsif( HCOUNT=319 and VCOUNT(3 downto 0)="1111" and SW(0)='0' ) then
				VADRL<=VADRC-5;
			--elsif( HCOUNT=318 ) then
			elsif( HCOUNT=401 ) then
				BUFENH<='0';
			elsif( HCOUNT=321 ) then
				HDISPEN<='0';
--				BUFENH<='0';
			elsif( ( HCOUNT=361 and SW(0)='1' )
				or ( HCOUNT=329 and SW(0)='0' ) ) then
				HS<='0';
			elsif( ( HCOUNT=394 and SW(0)='1' )
				or ( HCOUNT=377 and SW(0)='0' ) ) then
				HS<='1';
			end if;

--			if( ( HCOUNT(2 downto 0)="111" and SW(0)='1' )
--			 or ( HCOUNT(2 downto 0)="000" and SW(0)='0' ) ) then
			if( HCOUNT(2 downto 0)="111" ) then
--				VADRC<=VADRC+'1';
				BUFPT<=BUFPT+'1';
			end if;

			--
			-- SDRAM access & buffer entry
			--
			if((( BUFENV='1' and HCOUNT="111111111" ) and SW(0)='0' )
				or (( BUFENH='1' and HCOUNT(3 downto 0)="1111" ) and SW(0)='0')
				--or (( BUFENH='1' and HCOUNT(2 downto 0)="111"  ) and SW(0)='1')) then
				or ((( BUFENV='1' and HCOUNT="000000010" ) and SW(0)='1' )
				  or (( BUFENH='1' and CTR10=0  ) and SW(0)='1' ))) then
				VADRC<=VADRC+'1';
				BUFWP<=BUFWP+'1';
				VCS<='0';
				FADR<="100"&"000"&VADRC;
			elsif(( HCOUNT(3 downto 0)="0010" and SW(0)='0' )
			--	or ( HCOUNT(2 downto 0)="000" and SW(0)='1' )) then
				or ( CTR10=1 and SW(0)='1' )) then
				VCS<='1';
			end if;
			if(( BUFENH='1' and HCOUNT(3 downto 0)="0100" and SW(0)='0' )
				--or ( BUFENH='1' and HCOUNT(2 downto 0)="001" and SW(0)='1' )) then
				or ( BUFENH='1' and CTR10=3 and SW(0)='1' )) then
				DCODE<=FDAT(23 downto 16);
				CSEL<=FDAT(7);
				FCOL<=FDAT(6 downto 4);
				BCOL<=FDAT(2 downto 0);
				PCGEN<=FDAT(11);
				GCS<='0';
				if( SW(0)='0' ) then
					FADR<="101"&FDAT(15)&FDAT(14)&FDAT(31 downto 24)&VCOUNT(3 downto 1);
				else
					FADR<="101"&FDAT(15)&FDAT(14)&FDAT(31 downto 24)&VCOUNT(2 downto 0);
				end if;
			elsif(( HCOUNT(3 downto 0)="0111" and SW(0)='0' )
			--	or ( HCOUNT(2 downto 0)="010" and SW(0)='1' )) then
				or ( CTR10=4 and SW(0)='1' )) then
				GCS<='1';
			end if;
			if(( BUFENH='1' and HCOUNT(3 downto 0)="1001" and SW(0)='0' )
				--or ( BUFENH='1' and HCOUNT(2 downto 0)="011" and SW(0)='1' )) then
				or ( BUFENH='1' and CTR10=6 and SW(0)='1' )) then
				if( PCGEN='1' and DSP2EN='1' ) then
					PCGD0<=FDAT(31 downto 24);
					PCGD1<=FDAT(7 downto 0);
					PCGD2<=FDAT(15 downto 8);
				else
					PCGD0<=(others=>'0');
					PCGD1<=(others=>'0');
					PCGD2<=(others=>'0');
				end if;
				FCS<='0';
				if( SW(0)='0' ) then
					FADR<="101"&PCGSW&CSEL&DCODE&VCOUNT(3 downto 1);
				else
					FADR<="101"&PCGSW&CSEL&DCODE&VCOUNT(2 downto 0);
				end if;
			elsif(( HCOUNT(3 downto 0)="1100" and SW(0)='0' )
			--	or ( HCOUNT(2 downto 0)="100" and SW(0)='1' )) then
				or ( CTR10=7 and SW(0)='1' )) then
				FCS<='1';
			end if;
			if(( BUFENH='1' and HCOUNT(3 downto 0)="1110" and SW(0)='0' )
				or ( BUFENH='1' and CTR10=9 and SW(0)='1' )) then
				--or ( BUFENH='1' and HCOUNT(2 downto 0)="101" and SW(0)='1' )) then
				BWEN<='1';
--				BWD0<=(BMASK and (BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)))
--				   or (FMASK and (FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)))
--				   or (PMASK and PCGD0);
--				BWD1<=(BMASK and (BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)))
--				   or (FMASK and (FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)))
--				   or (PMASK and PCGD1);
--				BWD2<=(BMASK and (BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)))
--				   or (FMASK and (FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)))
--				   or (PMASK and PCGD2);
			else
				BWEN<='0';
			end if;

			--
			-- Color
			--
			if( HCOUNT(2 downto 0)="001" ) then
				SDAT0<=BUFD(31 downto 24);
				SDAT1<=BUFD(23 downto 16);
				SDAT2<=BUFD(15 downto 8);
			else
				SDAT0<=SDAT0(6 downto 0)&'0';
				SDAT1<=SDAT1(6 downto 0)&'0';
				SDAT2<=SDAT2(6 downto 0)&'0';
			end if;
			
		end if;
	end process;

	VENC : vencode port map (
	    clk21m => CLK,
    	reset => RST,
		videoR => DR,
		videoG => DG,
		videoB => DB,
		videoHS_n => HS,
		videoVS_n => VS,
		videoY => VY,
		videoC => VC,
		videoV => VV
    );

	--
	-- Pattern Synthesys
	--
	BMASK<=not(PCGD0 or PCGD1 or PCGD2 or FDAT(23 downto 16));
	FMASK1<=FDAT(23 downto 16);
	FMASK2<=(not(PCGD0 or PCGD1 or PCGD2)) and FDAT(23 downto 16);
	FMASK<=FMASK1 when PRIOL='0' else FMASK2;
	PMASK1<=(PCGD0 or PCGD1 or PCGD2) and (not FDAT(23 downto 16));
	PMASK2<=PCGD0 or PCGD1 or PCGD2;
	PMASK<=PMASK1 when PRIOL='0' else PMASK2;

				BWD0<=(BMASK and (BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)&BCOL(0)))
				   or (FMASK and (FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)&FCOL(0)))
				   or (PMASK and PCGD0);
				BWD1<=(BMASK and (BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)&BCOL(1)))
				   or (FMASK and (FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)&FCOL(1)))
				   or (PMASK and PCGD1);
				BWD2<=(BMASK and (BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)&BCOL(2)))
				   or (FMASK and (FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)&FCOL(2)))
				   or (PMASK and PCGD2);

	--
	-- Output
	--
	SDAT<=SDAT2(7)&SDAT1(7)&SDAT0(7);
	process( SDAT, PLT0, PLT1, PLT2, PLT3, PLT4, PLT5, PLT6, PLT7 ) begin
		case SDAT is
			when "000" =>
				COLG<=PLT0(2);
				COLR<=PLT0(1);
				COLB<=PLT0(0);
			when "001" =>
				COLG<=PLT1(2);
				COLR<=PLT1(1);
				COLB<=PLT1(0);
			when "010" =>
				COLG<=PLT2(2);
				COLR<=PLT2(1);
				COLB<=PLT2(0);
			when "011" =>
				COLG<=PLT3(2);
				COLR<=PLT3(1);
				COLB<=PLT3(0);
			when "100" =>
				COLG<=PLT4(2);
				COLR<=PLT4(1);
				COLB<=PLT4(0);
			when "101" =>
				COLG<=PLT5(2);
				COLR<=PLT5(1);
				COLB<=PLT5(0);
			when "110" =>
				COLG<=PLT6(2);
				COLR<=PLT6(1);
				COLB<=PLT6(0);
			when "111" =>
				COLG<=PLT7(2);
				COLR<=PLT7(1);
				COLB<=PLT7(0);
			when others =>
				COLG<='X';
				COLR<='X';
				COLB<='X';
		end case;
	end process;
	CSO<=FCS and GCS and VCS;
	DR<=COLR&COLR&COLR&COLR&COLR&COLR when HDISPEN='1' else "000000";
	DG<=COLG&COLG&COLG&COLG&COLG&COLG when HDISPEN='1' else "000000";
	DB<=COLB&COLB&COLB&COLB&COLB&COLB when HDISPEN='1' else "000000";
	RED<=DR when HDISPEN='1' and ( SW="01" or SW(0)='0' ) else
		 VC when SW="11" else "000000";
	GRN<=DG	when HDISPEN='1' and ( SW="01" or SW(0)='0' ) else
		 VY when SW="11" else "000000";
	BLUE<=DB when HDISPEN='1' and ( SW="01" or SW(0)='0' ) else
		 VV when SW="11" else "000000";
	VBLNK<=VDISPEN;
	HSOUT<=HS;
	VSOUT<=VS;

	--
	-- CRTC registers
	--
	CSPRI<='0' when ZADR(7 downto 0)="11110000" and IORQ='0' else '1';
	CSPLT<='0' when ZADR(7 downto 0)="11110001" and IORQ='0' else '1';
	process( ZCLK, ZWR, RST, CSPRI, CSPLT ) begin
		if( RST='0' ) then
			PRIOL<='0';
			DSP2EN<='0';
			PLT0<="000";
			PLT1<="001";
			PLT2<="010";
			PLT3<="011";
			PLT4<="100";
			PLT5<="101";
			PLT6<="110";
			PLT7<="111";
		elsif( ZCLK'event and ZCLK='0' and ZWR='0' ) then
			if( CSPRI='0' ) then
				PRIOL<=ZDI(1);
				DSP2EN<=ZDI(0);
			elsif( CSPLT='0' ) then
				if( ZDI(6 downto 4)="000" ) then
					PLT0<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="001" ) then
					PLT1<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="010" ) then
					PLT2<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="011" ) then
					PLT3<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="100" ) then
					PLT4<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="101" ) then
					PLT5<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="110" ) then
					PLT6<=ZDI(2 downto 0);
				elsif( ZDI(6 downto 4)="111" ) then
					PLT7<=ZDI(2 downto 0);
				end if;
			end if;
		end if;
	end process;

TVADRC<=VADRC;
TBUFWP<=BUFWP;
THDEN<=HDISPEN;
TBWEN<=BWEN;
TBUFPT<=BUFPT;
TBWD<=FDAT(23 downto 20)&BWD2(7 downto 4);	--BWD2;
TSDAT<=BUFD(15 downto 8);

-- for sim
--	HC<=HCOUNT(2 downto 0);
--	HC<=HCOUNT;
--	VC<=VCOUNT;
--	HEN<=HDISPEN;
--	VEN<=VDISPEN;
--	SD<=SDAT(7);
-- for sim

end Behavioral;
