----------------------------------------------------------------------------------
--
-- ROM block
-- Can be used to emulate 27Cxxx style EEPROMs
-- Memory contents initialization file is specified as generic
-- ROM initialization file format:
-- Every line should contain exactly 8 zeros or ones
-- representing the byte value in binary notation (MSB is on the left)
-- First line represents the byte at address 0, second line at address 1 etc.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;

entity rom_mem2 is
	 generic ( AddrWidth : integer := 10;
				  ROMFileName : string := "osrom.txt");
    Port ( A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
           DO : out  STD_LOGIC_VECTOR (7 downto 0);
           OE_n : in  STD_LOGIC;
           CE_n : in  STD_LOGIC;
			  CLK : in STD_LOGIC);
end rom_mem2;

architecture rtl of rom_mem2 is

    type Mem_Image is array(natural range <>) of bit_vector(7 downto 0);    
	 
	 -- Function to load ROM contents from file
    impure function LoadROM (ROMFileName : in string) return Mem_Image is
       FILE ROMFile		: text is in ROMFileName;                       
       variable str_line	: line;                                 
       variable ROM		: Mem_Image(0 to 2**AddrWidth-1);                                      
    begin                                                        
       for I in ROM'range loop                                  
           readline (ROMFile, str_line);                             
           read (str_line, ROM(I));                                  
       end loop;                                                    
       return ROM;                                                  
    end function;                                                

    signal ROM : Mem_Image(0 to 2**AddrWidth-1) := LoadROM(ROMFileName);

	signal DQ : std_logic_vector(7 downto 0);
begin
	
	--
	-- Output data or high impedance, depending on the state of OE_n and CE_n
	--
	
	process(A, OE_n, CE_n, ROM, CLK)
	begin
		if (CLK'event) and (CLK='1') then
			DQ <= to_stdlogicvector(ROM(conv_integer(A)));
		end if;
	end process;

	process(A, OE_n, CE_n, ROM, DQ)
	begin	
			if (OE_n = '0') and (CE_n = '0') then
				DO <= DQ;
			else
				DO <= (others => 'Z');
			end if;
	end process;
	
end rtl;

