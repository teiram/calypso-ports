----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity picoblaze_soc is
    Port (
		CLK_50M : in  STD_LOGIC;
		RESET_n : in STD_LOGIC;
		KEY_STROBE : in STD_LOGIC;
		KEY_CODE : in STD_LOGIC_VECTOR(7 downto 0);
		ESC_STATE : in STD_LOGIC;
		VIDEO_ADDR : out STD_LOGIC_VECTOR(15 downto 0);
		VIDEO_DATA : out STD_LOGIC;
		VIDEO_WR	  : out STD_LOGIC;
		
		CH_ADDR	: out STD_LOGIC_VECTOR(10 downto 0);
		CH_DATA	: in STD_LOGIC_VECTOR(7 downto 0);
		
		CLK_SEL : out STD_LOGIC_VECTOR(1 downto 0);

	   PRAM_CLK2 : out STD_LOGIC;
	   PRAM_WR2 : out STD_LOGIC;
	   PRAM_DIN2 : in STD_LOGIC_VECTOR(7 downto 0);
	   PRAM_DOUT2 : out STD_LOGIC_VECTOR(7 downto 0);
	   PRAM_ADDR2 : out STD_LOGIC_VECTOR(12 downto 0);

		LINE_IN : in STD_LOGIC;
		LINE_OUT : out STD_LOGIC		
	 );
end picoblaze_soc;

architecture rtl of picoblaze_soc is
	signal KEY_STICKY : std_logic;
	signal KEY_PRESSED : std_logic_vector(7 downto 0);
	signal KEY_READ : std_logic := '0';


	signal port_id : std_logic_vector(7 downto 0);
	signal write_strobe : std_logic;
	signal out_port : std_logic_vector(7 downto 0);
	signal read_strobe : std_logic;
	signal in_port : std_logic_vector(7 downto 0);
	signal interrupt : std_logic := '0';
	signal interrupt_ack : std_logic;
	signal reset : std_logic;

	signal iVIDEO_ADDR : std_logic_vector(15 downto 0) := X"0000";
	signal iVIDEO_DATA : std_logic := '0';
	signal iVIDEO_WR : std_logic := '0';
	signal iLINE_OUT : std_logic := '0';

	signal CH_ADDR_L : std_logic_vector(6 downto 0) := "0000000";
	signal CH_ADDR_H : std_logic_vector(3 downto 0) := "0000";

	signal CPU_FREQ_SEL : std_logic_vector(1 downto 0) := "00";

	signal PRAM_ADDR2_H : std_logic_vector(4 downto 0) := "00000";
	signal PRAM_ADDR2_L : std_logic_vector(7 downto 0) := X"00";

	-- SPI FLASH signals
	signal mosi, miso, cs_b, sck : std_logic;
	-- Device DNA access port
	signal dna_din, dna_read, dna_shift, dna_dout, dna_clk : std_logic;

	component picoblaze is
		generic ( ROMFileName : string := "test_simple.rom");
		 Port ( 
						 port_id: out    std_logic_vector( 7 downto 0);
						 write_strobe: out    std_logic;
						 out_port: out    std_logic_vector( 7 downto 0);
						 read_strobe: out    std_logic;
						 in_port: in    std_logic_vector( 7 downto 0);
						 interrupt: in    std_logic;
						 interrupt_ack: out    std_logic;
						 reset: in    std_logic;
						 clk: in    std_logic
				);
	end component picoblaze;

begin

	--reset <= not RESET_n;
	--reset <= '0';
	reset <= not ESC_STATE;

	CLK_SEL <= CPU_FREQ_SEL;
	
	CH_ADDR <= CH_ADDR_H & CH_ADDR_L;

	PRAM_ADDR2 <= PRAM_ADDR2_H & PRAM_ADDR2_L;
	
	--
	-- Capture keyboard input
	--
		process (KEY_STROBE, KEY_READ, CLK_50M)
		begin
			if (CLK_50M'event) and (CLK_50M = '1') then
				if (KEY_READ = '1') then
					KEY_STICKY <= '0';
				elsif KEY_STROBE = '1' then
					KEY_STICKY <= '1';
				end if;
			end if;
		end process;
		
		process (KEY_STROBE, KEY_CODE)
		begin
			if (KEY_STROBE'event) and (KEY_STROBE = '1') then
				KEY_PRESSED <= KEY_CODE;
			end if;
		end process;


	--
	-- Input port mapping
	--



	process (port_id, in_port, KEY_CODE, KEY_STICKY, ESC_STATE, LINE_IN, CLK_50M)
	begin
	if (CLK_50M'event) and (CLK_50M = '1') then
		case port_id(2 downto 0) is
			when "000" => in_port <= KEY_PRESSED;
			when "001" => in_port <= "0000000" & KEY_STICKY;
			when "010" => in_port <= "0000000" & ESC_STATE;
			when "011" => in_port <= PRAM_DIN2;
			when "100" => in_port <= "0000000" & LINE_IN;
			when "101" => in_port <= "0000000" & miso;
			when "110" => in_port <= "0000000" & dna_dout;
			when "111" => in_port <= CH_DATA;
			when others => null;
		end case;
	end if;
	end process;
	
	--
	-- Output port mapping
	--

	VIDEO_ADDR <= iVIDEO_ADDR;
	VIDEO_DATA <= iVIDEO_DATA;
	VIDEO_WR <= iVIDEO_WR;
	LINE_OUT <= iLINE_OUT;
	
	process (port_id, out_port, write_strobe, CLK_50M)
	begin
		if (CLK_50M'event) and (CLK_50M = '1') then
			if (write_strobe = '1') then
					if (port_id(7 downto 3) = "00000") then
						case port_id(2 downto 0) is
							when "000" => iVIDEO_ADDR(7 downto 0) <= out_port;
							when "001" => iVIDEO_ADDR(15 downto 8) <= out_port;
							when "010" => iVIDEO_DATA <= out_port(0);
							when "011" => iVIDEO_WR <= out_port(0);
							when "100" => iLINE_OUT <= out_port(0);
							when "101" => CH_ADDR_L <= out_port(6 downto 0);
							when "110" => CH_ADDR_H <= out_port(3 downto 0);
							when "111" => KEY_READ <= out_port(0);
							when others => null;
						end case;
					end if;

				  -- SPI signals to FLASH at port 8 hex 
				  if port_id(3)='1' then
					 sck <= out_port(0);      
					 cs_b <= out_port(1);    
					 mosi <= out_port(7);     
				  end if;

				  -- Control device DNA input signals at addresses 10 hex.
				  if port_id(4)='1' then
					 dna_clk <= out_port(0);
					 dna_shift <= out_port(1);
					 dna_read <= out_port(2);
					 dna_din <= out_port(3);
				  end if;

				  -- CPU frequency selector
				  if port_id(5)='1' then
					 CPU_FREQ_SEL <= out_port(1 downto 0);
				  end if;

					if port_id(7)='1' then
						case port_id(1 downto 0) is
							when "00" => 
											PRAM_CLK2 <= out_port(0); 
											PRAM_WR2 <= out_port(1);
							when "01" => PRAM_DOUT2 <= out_port;
							when "10" => PRAM_ADDR2_L <= out_port;
							when "11" => PRAM_ADDR2_H <= out_port(4 downto 0);
							when others => null;
						end case;
					end if;
			end if;
		end if;
	end process;

	interrupt <= '0';

	pblaze_cpu: picoblaze
		generic map ( ROMFileName => "picoblaze_sw/pblaze_v2.rom")
		 Port map( 
						 port_id => port_id,
						 write_strobe => write_strobe,
						 out_port => out_port,
						 read_strobe => read_strobe,
						 in_port => in_port,
						 interrupt => interrupt,
						 interrupt_ack => interrupt_ack,
						 reset => reset,
						 clk => CLK_50M
				);


	--
	-- SPI FLASH access port
	--

  spi_flash_port: SPI_ACCESS      
  generic map ( SIM_DEVICE => "3S200AN")
  port map( MOSI => mosi,
            MISO => miso,
             CSB => cs_b,
             CLK => sck );	


	--
	-- Device DNA port
	--
  device_dna: dna_port
    port map(   din => dna_din,
               read => dna_read,
              shift => dna_shift,                       
               dout => dna_dout,                       
                clk => dna_clk);

end rtl;

