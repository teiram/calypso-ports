--
-- sdram.vhd
--
-- SDRAM access module with self refresh and dual ports
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2007
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sdram is
	port (
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
end sdram;

architecture rtl of sdram is

signal A : std_logic_vector(22 downto 0);
signal DI : std_logic_vector(7 downto 0);
signal WR : std_logic;
signal SEQCNT : std_logic_vector(6 downto 0);
signal BUF    : std_logic_vector(7 downto 0);
signal CSAi   : std_logic;
signal CSAii  : std_logic;
signal CSAiii : std_logic;
signal CSAiiii : std_logic;
signal CSBi   : std_logic;
signal CSBii  : std_logic;
signal CSBiii : std_logic;
signal CSBiiii : std_logic;
signal CSCi   : std_logic;
signal CSCii  : std_logic;
signal CSCiii : std_logic;
signal CSCiiii : std_logic;
signal CSDi   : std_logic;
signal CSDii  : std_logic;
signal CSDiii : std_logic;
signal CSDiiii : std_logic;
signal CSEi   : std_logic;
signal REFCNT : std_logic_vector(9 downto 0);
signal RFSHi  : std_logic;
signal PA : std_logic;
signal PB : std_logic;
signal PC : std_logic;
signal PD : std_logic;
signal PE : std_logic;
signal WB : std_logic;
signal DAIR : std_logic_vector(7 downto 0);
signal DBIR : std_logic_vector(7 downto 0);
signal WAITBi   : std_logic;
signal WAITBii  : std_logic;
signal WAITBiii  : std_logic;
signal WAITBiv  : std_logic;

begin

	process( RST, MEMCLK )
		type typsdramcmds is (DSEL, PALL, REF, MRS, NOP, ACT, RDWR, RDWR2, GETD, GETD2, PRE);
		type typseq is (RES, IDLE, REFS, T0, T1, T2, T3, T4, T5, T6, T7, T8, TR0, TR1, TR2, TR3, TR4);
		variable CMDS : typsdramcmds := DSEL;
		variable SEQ : typseq :=RES;
	begin
		if( RST='0' ) then
			MCS<='1';
			MLDQ<='1';
			MUDQ<='1';
			SEQCNT<="1110000";
			MDOE<='0';
			CSAi<='0';
			CSBi<='0';
			CSCi<='0';
			CSDi<='0';
			CSEi<='0';
			CSAii<='1';
			CSBii<='1';
			CSCii<='1';
			CSDii<='1';
			CSAiii<='1';
			CSBiii<='1';
			CSCiii<='1';
			CSDiii<='1';
			REFCNT<=(others=>'0');
			RFSHi<='0';
			PA<='0';
			PB<='0';
			PC<='0';
			PD<='0';
			PE<='0';
			WB<='0';
		elsif( MEMCLK'event and MEMCLK='1' ) then

			--
			-- Seqence control
			--
			if( SEQ=RES ) then
				SEQCNT<=SEQCNT+'1';
				if( SEQCNT="1111110" ) then
					CMDS:=PALL;
				elsif( SEQCNT="1111111" ) then
					CMDS:=NOP;
				elsif( SEQCNT(6)='0' ) then
					if( SEQCNT(2 downto 0)="000" ) then
						CMDS:=REF;
					else
						CMDS:=NOP;
					end if;
				elsif( SEQCNT="1000000" ) then
					CMDS:=MRS;
					SEQ:=IDLE;
				else
					CMDS:=DSEL;
				end if;
			elsif( SEQ=IDLE ) then
				if( CSAi='1' ) then
					SEQ:=T0;
					CSAi<='0';
					PA<='1';
				elsif( CSBi='1' ) then
					SEQ:=T0;
					CSBi<='0';
					PB<='1';
				elsif( CSCi='1' ) then
					SEQ:=T0;
					CSCi<='0';
					PC<='1';
				elsif( CSDi='1' ) then
					SEQ:=T0;
					CSDi<='0';
					PD<='1';
				elsif( CSEi='1' ) then
					SEQ:=T0;
					CSEi<='0';
					PE<='1';
				elsif( RFSHi='1' ) then
					SEQ:=REFS;
					RFSHi<='0';
				else
					CMDS:=NOP;
				end if;
			elsif( SEQ=REFS ) then
				CMDS:=REF;
				SEQ:=TR0;
			elsif( SEQ=T0 ) then
				CMDS:=ACT;
				SEQ:=T1;
			elsif( SEQ=T1 ) then
				CMDS:=NOP;
				SEQ:=T2;
			elsif( SEQ=T2 ) then
				CMDS:=RDWR;
				SEQ:=T3;
			elsif( SEQ=T3 ) then
				CMDS:=RDWR2;
				SEQ:=T4;
			elsif( SEQ=T4 ) then
				if( PC='1' ) then
					CMDS:=NOP;
				else
					CMDS:=PRE;
				end if;
				SEQ:=T5;
			elsif( SEQ=T5 ) then
				CMDS:=GETD;
				if( PC='1' ) then
					SEQ:=T6;
				else
					SEQ:=T7;
				end if;
				WB<='0';
			elsif( SEQ=T6 ) then
				CMDS:=GETD2;
				SEQ:=T7;
			elsif( SEQ=T7 ) then
				CMDS:=NOP;
				SEQ:=T8;
			elsif( SEQ=T8 ) then
				PA<='0';
				PB<='0';
				PC<='0';
				PD<='0';
				PE<='0';
				if( PE='1' ) then
					CSDi<='1';
				end if;
				SEQ:=IDLE;
			elsif( SEQ=TR0 ) then
				CMDS:=NOP;
				SEQ:=TR1;
			elsif( SEQ=TR1 ) then
				SEQ:=TR2;
			elsif( SEQ=TR2 ) then
				SEQ:=TR3;
			elsif( SEQ=TR3 ) then
				SEQ:=TR4;
			elsif( SEQ=TR4 ) then
				SEQ:=IDLE;
			end if;

			--
			-- Sense signals
			--
			CSAiiii<=CSAiii;
			CSAiii<=CSAii;
			CSAii<=CSA;
			if( CSAiii='0' and CSAiiii='1' ) then
				CSAi<='1';
				DAIR<=DAI;
			end if;
			CSBiiii<=CSBiii;
			CSBiii<=CSBii;
			CSBii<=CSB;
			if( CSBiii='0' and CSBiiii='1' ) then
				CSBi<='1';
				DBIR<=DBI;
				WB<='1';
			end if;
			CSCiiii<=CSCiii;
			CSCiii<=CSCii;
			CSCii<=CSC;
			if( CSCiii='0' and CSCiiii='1' ) then
				CSCi<='1';
			end if;
			CSDiiii<=CSDiii;
			CSDiii<=CSDii;
			CSDii<=CSD;
			if( CSDiii='0' and CSDiiii='1' ) then
				CSDi<=not CPYMODE;
				CSEi<=CPYMODE;
			end if;

			--
			-- Command operation
			--
			case CMDS is
				when DSEL =>	-- deselect
					MCS<='1';
					MRAS<='1';
					MCAS<='1';
					MLDQ<='1';
					MUDQ<='1';
				when PALL =>	-- precharge all
					MCS<='0';
					MRAS<='0';
					MCAS<='1';
					MWE<='0';
					MA(10)<='1';
				when REF =>		-- auto refresh
					MCS<='0';
					MRAS<='0';
					MCAS<='0';
					MWE<='1';
				when MRS =>		-- mode regiser set
					MCS<='0';
					MRAS<='0';
					MCAS<='0';
					MWE<='0';
					--MA<="00010" & "0" & "010" & "0" & "000";	-- single,CL=2,WT=0(seq),BL=1
					MA <= "000" & "1" & "00" & "010" & "0" & "001";	-- single,CL=2,WT=0(seq),BL=2
					MLDQ<='1';
					MUDQ<='1';
				when NOP =>		-- no operation
					MCS<='0';
					MRAS<='1';
					MCAS<='1';
					MWE<='1';
					MLDQ<='1';
					MUDQ<='1';
					MDO<=(others=>'0');
					MDOE<='0';
				when ACT =>		-- activate
					MCS<='0';
					MRAS<='0';
					MCAS<='1';
					MWE<='1';
					MA<='0' & A(20 downto 9);
				when RDWR =>	-- read/write
					MCS<='0';
					MRAS<='1';
					MCAS<='0';
					MA(12 downto 9)<="0010";	-- auto precharge
					--MA(12 downto 9)<="0000";	-- manual precharge
					MWE<=WR;
					MA(7 downto 0)<=A(8 downto 1);
					if( WR='0' ) then
						MDO<=DI&DI;
						MLDQ<=A(0);
						MUDQ<=not A(0);
						MDOE<='1';
					else
						MDO<=(others=>'0');
						MDOE<='0';
						MLDQ<='0';
						MUDQ<='0';
					end if;
				when RDWR2 =>	-- read/write(next data)
					MCS<='0';
					if( PC='1' ) then
						MRAS<='1';
						MCAS<='0';
						MA(12 downto 9)<="0000";	-- manual precharge
						MWE<='1';
						MA(7 downto 0)<=A(8 downto 2) & '0';
						MDO<=(others=>'0');
						MDOE<='0';
						MLDQ<='0';
						MUDQ<='0';
					else
						MRAS<='0';
						MCAS<='1';
						MWE<='0';
						MA(12 downto 9)<="0000";
					end if;
				when GETD =>	-- read data
					MCS<='0';
					if( PA='1' ) then
						if( AA(0)='1' ) then
							DAO<=MDI(15 downto 8);
						else
							DAO<=MDI(7 downto 0);
						end if;
					elsif( PB='1' ) then
						if( AB(0)='1' ) then
							DBO<=MDI(15 downto 8);
						else
							DBO<=MDI(7 downto 0);
						end if;
					elsif( PC='1' ) then
						DCO(31 downto 24)<=MDI(15 downto 8);
						DCO(23 downto 16)<=MDI(7 downto 0);
					elsif( PE='1' ) then
						if( AD(0)='1' ) then
							BUF<=MDI(15 downto 8);
						else
							BUF<=MDI(7 downto 0);
						end if;
					end if;
					if( PC='1' ) then
						MRAS<='0';
						MCAS<='1';
						MWE<='0';
						MA(12 downto 9)<="0000";
					else
						MRAS<='1';
						MCAS<='1';
						MWE<='1';
					end if;
				when GETD2 =>	-- read data
					MCS<='0';
					if( PC='1' ) then
						DCO(15 downto 8)<=MDI(15 downto 8);
						DCO(7 downto 0)<=MDI(7 downto 0);
					else
						MRAS<='1';
						MCAS<='1';
						MWE<='1';
					end if;
				when PRE =>		-- precharge
					if( PC='1' ) then
						MRAS<='1';
						MCAS<='1';
						MWE<='1';
					else
						MCS<='0';
						MRAS<='0';
						MCAS<='1';
						MWE<='0';
						MA(12 downto 9)<="0000";
					end if;
				when others =>	-- same as no operation
					MCS<='0';
					MRAS<='1';
					MCAS<='1';
					MWE<='1';
			end case;

			--
			-- refresh counter
			--
			if( REFCNT="0110000000" ) then
				REFCNT<=(others=>'0');
				RFSHi<='1';
			else
				REFCNT<=REFCNT+'1';
			end if;

		end if;
	end process;

TPC<=PC;

	--
	-- SDRAM ports
	--
	MCKE<='1';
	MBA0<='0';
	MBA1<='0';

	--
	-- Ports select
	--
	WR<=WRA when PA='1' else
		WRB when PB='1' else
		'0' when PD='1' else  '1';
	A <=AA when PA='1' else
		AB when PB='1' else
		AC when PC='1' else
		AD when PD='1' else
		AD(22 downto 15)&'0'&AD(13 downto 0) when PE='1' else (others=>'0');
	DI<=DAIR when PA='1' else
		DBIR when PB='1' else
		DDI when PD='1' and CPYMODE='0' else
		BUF when PD='1' and CPYMODE='1' else (others=>'0');

	--
	-- Wait
	--
	process( RST, MEMCLK ) begin
		if( RST='0' ) then
			WAITB<='0';
			WAITBi<='0';
			WAITBii<='0';
		elsif( MEMCLK'event and MEMCLK='1' ) then
			WAITB<=WAITBi;
			WAITBi<=WAITBii;
			WAITBii<=WAITBiii;
			WAITBiii<=WAITBiv;
			WAITBiv<=(CSBi or PB) and not RDB;	--WB;
		end if;
	end process;

end rtl;
