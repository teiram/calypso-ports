----------------------------------------------------------------------------------
-- Captures Galaksija composite video output into video RAM
-- and generates VGA video
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity composite_to_vga is
    Port ( 
				CLK : in  STD_LOGIC;	-- Pixel clock
				RESET_n : in STD_LOGIC;
				VIDEO_DATA : in  STD_LOGIC;
				VIDEO_SYNC : in  STD_LOGIC;
				START_FRAME_n : in  STD_LOGIC;	-- Should be connected to WAIT_n signal
				HPOS : in STD_LOGIC;	-- Horizontal position indicator 2BA8: '1' when horizontal position = 11 else '0'
			  
				ESC_STATE : in STD_LOGIC;	-- State of the ESC key - signals if Galaksija or Picoblaze are in charge
				CLK_W2 : in STD_LOGIC;		-- Clock for second VRAM port
				WR2 : in STD_LOGIC;			-- Write signal for second VRAM port
				AWR2 : in STD_LOGIC_VECTOR(15 downto 0);	-- Address for second VRAM port
				DIN2 : in STD_LOGIC;	-- Data fro second VRAM port
			  
				COL_VADDR : out STD_LOGIC_VECTOR(5 downto 0);	-- Vertical address for color RAM, in sync with VGA data
				COL_HADDR : out STD_LOGIC_VECTOR(5 downto 0);	-- Horizontal address for color RAM, in sync
				COL_CLK : out STD_LOGIC;	-- Clock for color RAM
			  
			  -- VGA controller signals
				CLK_50M	: in std_logic;
				VGA_HSYNC : inout std_logic;
				VGA_VSYNC : inout std_logic;
				VGA_VIDEO : out std_logic
			 );
end composite_to_vga;

architecture rtl of composite_to_vga is

	constant XRES : integer range 0 to 2047 := 256;	-- Galaksija X resolution
	constant YRES : integer range 0 to 2047 := 256;	-- Galaksija Y resolution
	constant YMAX : integer range 0 to 2047 := 207;	-- Galaksija Y resolution

	signal dSTART_FRAME_n : std_logic;
	signal START_OF_FRAME : std_logic;
	
	signal dVIDEO_SYNC : std_logic;
	signal SYNC : std_logic;
	
	-- Counters
	signal PIX_CNT : integer range 0 to 1023;
	signal PIX_CNT_RST : std_logic;	-- Reset for PIX_CNT
	
	signal SYNC_CNT : integer range 0 to 1023;
	signal SYNC_CNT_RST : std_logic; -- Reset for SYNC_CNT
	
	-- Video address
	-- 256 pixels horizontal resolution
	-- 312 pixels verical resolution
	signal X : std_logic_vector(7 downto 0);
	signal Y : std_logic_vector(8 downto 0);
	
	signal Xint : integer range 0 to 1023;
	signal Yint : integer range 0 to 1023;
		
	signal NPIX : integer range 0 to 1023 := 51+11;	-- Number of pixels to skip after SYNC pulse (horizontal blanking)
	signal NPIX_MAX : integer range 0 to 1023; -- := NPIX+XRES;

	constant NPIX1 : integer range 0 to 1023 := 51+11;	-- Number of pixels to skip after SYNC pulse (horizontal blanking)
	constant NPIX_MAX1 : integer range 0 to 1023 := NPIX+XRES;

	constant NPIX2 : integer range 0 to 1023 := 51+11+3*8-2;	-- Number of pixels to skip after SYNC pulse (horizontal blanking)
	constant NPIX_MAX2 : integer range 0 to 1023 := NPIX+XRES;


	constant NSYNC : integer range 0 to 1023:= 3;	-- Number of SYNC pulses to skip after START_OF_FRAME (vertical blanking)
		
	constant NSYNC_MAX : integer range 0 to 1023 := 3+YRES;
	
	-- Capture state machine signals
	type STATES is (IDLE, WAIT_BLANK, CONVERT_LINE, WAIT_SYNC);
	
	signal CState : STATES := IDLE;
	signal NState : STATES := IDLE;
	
	signal WR, WR1 : std_logic;
	
	signal ADDR : STD_LOGIC_VECTOR(16 downto 0);
	signal ADDR2 : STD_LOGIC_VECTOR(16 downto 0);

	-- VGA related signals
	signal VGA_CLK : std_logic;
	signal VGA_ADDR : std_logic_vector(16 downto 0);

	signal CLK_25M : std_logic := '0';
	signal RESET : std_logic;

	signal HADDR : std_logic_vector(10 downto 0);
	signal VADDR : std_logic_vector(10 downto 0);
	signal VGA_VIDEO_int : std_logic;
	signal VGA_BLANK : std_logic;	
	signal BLANK_int : std_logic;

	signal XOVER, YOVER : std_logic;

	signal XS, YS : std_logic_vector(9 downto 0);
	
	signal BLANK : std_logic;

	signal CLKW, DIN : std_logic;
	signal AWR : std_logic_vector(16 downto 0);

	signal cnt1 : integer;
	
	signal vaddr2 : std_logic_vector(5 downto 0);
	--
	-- Components
	--
	
	component ram_bit is
		generic( 
					AddrWidth : integer := 17;
					Capacity : integer := XRES*YRES
				);
		 Port ( 
					CLKR	: in  STD_LOGIC;
					CLKW	: in STD_LOGIC;
					WR		: in  STD_LOGIC;
					ARD	: in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
					AWR	: in STD_LOGIC_VECTOR(AddrWidth-1 downto 0);
					DIN	: in  STD_LOGIC;
					DOUT	: out  STD_LOGIC
				);
	end component ram_bit;	


	component vga_controller_640_60 is
		Port(
					rst : in std_logic;
					pixel_clk : in std_logic;
					HS	: out std_logic;
					VS	: out std_logic;
					hcount : out std_logic_vector(10 downto 0);
					vcount : out std_logic_vector(10 downto 0);
					blank: out std_logic
			);
	end component vga_controller_640_60;
	
	--
	-- End of components
	--
	
begin
	NPIX <= NPIX1 when HPOS = '1' else
			  NPIX2;

	NPIX_MAX <= NPIX_MAX1 when HPOS = '1' else
					NPIX_MAX2;

	-- Pixel counter
	process(CLK, PIX_CNT, PIX_CNT_RST)
	begin
		if (CLK'event) and (CLK = '1') then
			if (PIX_CNT_RST = '1') then
				PIX_CNT <= 0;
			else
				PIX_CNT <= PIX_CNT + 1;
			end if;
		end if;
	end process;

	Xint <= conv_integer(conv_std_logic_vector(PIX_CNT,10) - conv_std_logic_vector(NPIX,10));
	Yint <= conv_integer(conv_std_logic_vector(SYNC_CNT,10) - conv_std_logic_vector(NSYNC,10));
	
	X <= conv_std_logic_vector(Xint,8);
	Y <= conv_std_logic_vector(Yint,9);

	ADDR <= Y & X;

	-- SYNC counter
	process(CLK, SYNC, SYNC_CNT, SYNC_CNT_RST)
	begin
		if (CLK'event) and (CLK = '1') then
			if (SYNC_CNT_RST = '1') then
				SYNC_CNT <= 0;
			else
				if (SYNC = '1') then
					SYNC_CNT <= SYNC_CNT + 1;
				end if;
			end if;
		end if;
	end process;
	
	-- Detect START_FRAME_n 0 -> 1
	process(CLK, START_FRAME_n)
	begin
		if (CLK'event) and (CLK = '1') then	
			dSTART_FRAME_n <= START_FRAME_n;
		end if;
	end process;

	process(START_FRAME_n, dSTART_FRAME_n)
	begin
		if (dSTART_FRAME_n = '0') and (START_FRAME_n = '1') then
			START_OF_FRAME <= '1';
		else
			START_OF_FRAME <= '0';
		end if;
	end process;
	
	-- Detect VIDEO_SYNC 0 -> 1
	process(CLK, VIDEO_SYNC)
	begin
		if (CLK'event) and (CLK = '1') then
			dVIDEO_SYNC <= VIDEO_SYNC;
		end if;
	end process;
	
	process(dVIDEO_SYNC, VIDEO_SYNC)
	begin
		if (dVIDEO_SYNC = '0') and (VIDEO_SYNC = '1') then
			SYNC <= '1';
		else
			SYNC <= '0';
		end if;
	end process;
	
	-- Capture state machine
	
	-- Propagate new state
	process(CLK, NState, RESET_n)
	begin
		if (RESET_n = '0') then
			CState <= IDLE;
		else
			if (CLK'event) and (CLK = '1') then
				CState <= NState;
			end if;
		end if;
	end process;

	-- Main state machine process
	process (CState, START_OF_FRAME, Xint, Yint, PIX_CNT, SYNC_CNT, SYNC, NPIX_MAX, NPIX)
	begin
		case CState is
			when IDLE =>
				-- Wait start of frame. Keep counters in reset
				if (START_OF_FRAME = '0') then
					NState <= IDLE;
				else
					NState <= WAIT_BLANK;
				end if;
				PIX_CNT_RST <= '1';
				SYNC_CNT_RST <= '1';
				WR <= '0';
			when WAIT_BLANK =>
				-- Wait for first non-blank line
				WR <= '0';
				SYNC_CNT_RST <= '0';
				if (Yint = 1023) and (SYNC = '1') then
					NState <= CONVERT_LINE;
					PIX_CNT_RST <= '1'; -- Don't count pixels
				else
					NState <= WAIT_BLANK;
					PIX_CNT_RST <= '1'; -- Don't count pixels
				end if;
			when CONVERT_LINE =>
				PIX_CNT_RST <= '0';
				SYNC_CNT_RST <= '0';
				if (PIX_CNT < NPIX_MAX) then
					if (PIX_CNT >= NPIX) then
						WR <= '1';
					else
						WR <= '0';
					end if;
					NState <= CONVERT_LINE;
				else
					WR <= '0';
					if (SYNC_CNT < NSYNC_MAX) then
						NState <= WAIT_SYNC; -- Wait for next line start
					else
						NState <= IDLE;	-- Whole frame is converted
					end if;
				end if;
			when WAIT_SYNC =>
				SYNC_CNT_RST <= '0';
				WR <= '0';
				if (SYNC = '0') then
					PIX_CNT_RST <= '1';
					NState <= WAIT_SYNC;
				else
					PIX_CNT_RST <= '1';
					NState <= CONVERT_LINE;
				end if;
		end case;
	end process;

	--
	-- Video RAM
	--

	VRAM: ram_bit 
		generic map( 
						AddrWidth => 17,
						Capacity => XRES*YMAX
					)
		 Port map ( 
						CLKW => CLKW,
						CLKR => VGA_CLK,
						WR => WR1,
						ARD => VGA_ADDR,
						AWR => AWR,
						DIN => DIN,
						DOUT => VGA_VIDEO_int
					);

	WR1 <= WR when ESC_STATE = '0' else
          WR2;
	
	ADDR2 <= '0' & AWR2;


	CLKW <= CLK when ESC_STATE = '0' else
	        CLK_W2;

	AWR <= ADDR when ESC_STATE = '0' else
			 ADDR2;

	DIN <= VIDEO_DATA when ESC_STATE = '0' else
			 DIN2;
				
	-- Color RAM addresses
	COL_VADDR <= vaddr2;
	COL_HADDR <= HADDR(8 downto 3);

	-- "Dot" heights are not equal in pixels
	-- Heights are : 3(+1) 4(+1) 3(+1) 3(+1) 4(+1) 3(+1) 3(+1) 4(+1) ...
	process (cnt1, VADDR, VGA_HSYNC)
	begin
		if (VADDR = "0000000000") then
			cnt1 <= 1;
		else
			if (VGA_HSYNC'event) and (VGA_HSYNC = '1') then
				if (cnt1 = 25) then
					cnt1 <= 0;
				else
					cnt1 <= cnt1 + 1;
				end if;
			end if;
		end if;
	end process;

	-- Generate vertical color RAM position
	process (cnt1, VADDR, VGA_HSYNC)
	begin
		if (VADDR = "0000000000") then
			vaddr2 <= (others => '0');
		else
			if (VGA_HSYNC'event) and (VGA_HSYNC = '1') then
				if (cnt1 = 7) or (cnt1 = 17) or (cnt1=25) then
					vaddr2 <= vaddr2 + 1;
				end if;
			end if;
		end if;
	end process;

	VGA_CLK <= CLK_25M;
	VGA_ADDR <= VADDR(9 downto 1) & HADDR(8 downto 1);

	XS <= conv_std_logic_vector(2*XRES-1, 10);
	YS <= conv_std_logic_vector(YMAX, 10);

	YOVER <= '1' when (VADDR(10 downto 1) > YS) else '0';
	XOVER <= '0' when (HADDR(10 downto 0) < XS) else '1';
	
	BLANK_int <= YOVER or XOVER;

	RESET <= not RESET_n;
	
	BLANK <= BLANK_int or VGA_BLANK;
	
	VGA_VIDEO <= VGA_VIDEO_int when (BLANK = '0') else
					 '0';
	
	process(CLK_50M, CLK_25M)
	begin
		if (CLK_50M'event) and (CLK_50M = '1') then
			CLK_25M <= not CLK_25M;
		end if;
	end process;
	
	COL_CLK <= CLK_25M;

	VGA_CTRL: vga_controller_640_60
	port map(
		rst => RESET,
		pixel_clk => CLK_25M,

		HS => VGA_HSYNC,
		VS => VGA_VSYNC,
		hcount => HADDR,
		vcount => VADDR,
		blank => VGA_BLANK
	);
	
end rtl;
