----------------------------------------------------------------------------------
-- Color RAM extension
--
-- Mapped to 0xE000
--
-- Location in color RAM determines the color of the corresponding dot
-- There are 64 (width) x 48 (height) dots
-- The address of the dot at location (X,Y) can be calulated as:
-- addr = 0xE000 + Y * 0x40 + X
--
-- Each bit turns on the corresponding color when set to 0
-- | D7 | D6 | D5 | D4 | D3 | D2 | D1 | D0 |
-- | XX | XX | XX | XX | XX | R  | G  | B  |
--
-- XX means not implemented, read as 1
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity color_ram is
    Port ( 
				CLK_WR : in  STD_LOGIC;
				A : in  STD_LOGIC_VECTOR (15 downto 0);
				D : inout  STD_LOGIC_VECTOR (2 downto 0);
				WR_n : in  STD_LOGIC;
				OE_n : in STD_LOGIC;
				MREQ_n : in  STD_LOGIC;
				VADDR : in  STD_LOGIC_VECTOR (5 downto 0);
				HADDR : in  STD_LOGIC_VECTOR (5 downto 0);
				CLK_RD : in  STD_LOGIC;
				COLORS : out STD_LOGIC_VECTOR(2 downto 0)
			);
end color_ram;

architecture rtl of color_ram is
	constant BaseAddr : integer := 57344;	-- 0xE000
	constant RAMSIZE : integer := 3072;
	type Mem_Image is array(natural range <>) of bit_vector(2 downto 0);

	signal RAM : Mem_Image(0 to RAMSIZE-1);
	
	-- Memory enable signal
	signal Enable : std_logic;
	
	signal w : std_logic;

	signal dint : std_logic_vector(2 downto 0);

	signal VGA_ADDR : std_logic_vector(11 downto 0);
	
	signal AInRange : std_logic;
	signal ALOW : std_logic_vector(15 downto 0);
	signal AHIGH : std_logic_vector(15 downto 0);
begin
	-- Limits for color RAM
	ALOW <= conv_std_logic_vector(BaseAddr,16);
	AHIGH <= conv_std_logic_vector(BaseAddr + RAMSIZE, 16);

	-- Check if the address is in range
	AInRange <= '1' when (A >= ALOW) and (A < AHIGH) else '0';

	VGA_ADDR <= VADDR & HADDR;
	
	-- Enable memory access if the address is in range and if it is a memory cycle
	Enable <= '1' when ((MREQ_n= '0') and (AInRange = '1')) else '0';
	
	process(Enable, WR_n)
	begin
		if (Enable = '1') then
			w <= not WR_n;
		else
			w <= '0';
		end if;
	end process;
	
	process(A, WR_n, CLK_WR, Enable, w)
	begin
		if (CLK_WR'event) and (CLK_WR = '1') then
				dint <= to_stdlogicvector(RAM(conv_integer(A(11 downto 0))));
				if (w = '1') then
					RAM(conv_integer(A(11 downto 0))) <= to_bitvector(D(2 downto 0));
				end if;
		end if;
	end process;
		
	-- Secondary RAM port for Picoblaze access	
	process (CLK_RD, VGA_ADDR)
	begin
		if (CLK_RD'event) and (CLK_RD = '1') then
			COLORS <= to_stdlogicvector(RAM(conv_integer(VGA_ADDR)));
		end if;
	end process;

	-- Output tri-state buffer connected to system bus
	process(Enable, OE_n, dint, w)
	begin
		if (Enable = '1') and (OE_n = '0') and (w = '0') then
			D <= dint;
		else
			D <= (others => 'Z');
		end if;
	end process;

end rtl;


