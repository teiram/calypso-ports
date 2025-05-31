----------------------------------------------------------------------------------
-- Asynchronous RAM
-- Used to emulate 6264 and similar
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;


entity ram_mem_v3 is
    generic (
        AddrWidth : integer := 13
    );
    port (
        A : in  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
        DQ : inout  STD_LOGIC_VECTOR (7 downto 0);
        WE_n : in  STD_LOGIC;
        OE_n : in  STD_LOGIC;
        CS1_n : in  STD_LOGIC;
        CS2 : in  STD_LOGIC;
        CLK : in STD_LOGIC
    );
end ram_mem_v3;

architecture rtl of ram_mem_v3 is
    -- Data types
    type Mem_Image is array(natural range <>) of bit_vector(7 downto 0);
    
    -- RAM array
    signal RAM : Mem_Image(0 to 2**AddrWidth-1);
    
    -- Composite enable signal
    signal Enable : std_logic;
    
    signal w : std_logic;

    signal dint : std_logic_vector(7 downto 0);
begin
    Enable <= CS2 and not(CS1_n);
    
    process(Enable, WE_n)
    begin
        if (Enable = '1') then
            w <= not WE_n;
        else
            w <= '0';
        end if;
    end process;
    
    process(A, OE_n, WE_n, CLK, Enable, w)
    begin
        if (CLK'event) and (CLK = '1') then
            dint <= to_stdlogicvector(RAM(conv_integer(A)));
            if (w = '1') then
                RAM(conv_integer(A)) <= to_bitvector(DQ);
            end if;
        end if;
    end process;

    -- Output buffer
    process(Enable, OE_n, dint, w)
    begin
        if (Enable = '1') and (OE_n = '0') and (w = '0') then
            DQ <= dint;
        else
            DQ <= (others => 'Z');
        end if;
    end process;

end rtl;

