--
-- keymatrix.vhd
--
-- Convert from PS/2 key-matrix to MZ-700 key-matrix module
-- for MZ-700 on FPGA
--
-- Nibbles Lab. 2005
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity keymatrix is port (
    RST : in std_logic;
    PA : in std_logic_vector(3 downto 0);
    PB : out std_logic_vector(7 downto 0);
    KCLK : in std_logic;
    PS2KEY : in std_logic_vector(10 downto 0);
    -- for Joystick
    JOYA : in std_logic_vector(5 downto 0);
    JOYB : in std_logic_vector(5 downto 0)
);
end keymatrix;

architecture Behavioral of keymatrix is

--
-- extended flag
--
signal FLGE0 : std_logic;
signal KEY_FLAG : std_logic;
signal KEY_PRESS : std_logic;
signal KEY_EXTENDED : std_logic;
signal KEY_VALID : std_logic;

--
-- MZ-700 matrix registers
--
signal SCAN01 : std_logic_vector(7 downto 0);
signal SCAN02 : std_logic_vector(7 downto 0);
signal SCAN03 : std_logic_vector(7 downto 0);
signal SCAN04 : std_logic_vector(7 downto 0);
signal SCAN05 : std_logic_vector(7 downto 0);
signal SCAN06 : std_logic_vector(7 downto 0);
signal SCAN07 : std_logic_vector(7 downto 0);
signal SCAN08 : std_logic_vector(7 downto 0);
signal SCAN09 : std_logic_vector(7 downto 0);
signal SCAN10 : std_logic_vector(7 downto 0);

begin

    KEY_PRESS <= PS2KEY(9);
    KEY_EXTENDED <= PS2KEY(8);
    KEY_VALID <= PS2KEY(10);
    
    process (RST, KCLK) begin
        if RST = '0' then
            SCAN01 <= (others => '0');
            SCAN02 <= (others => '0');
            SCAN03(7 downto 6) <= (others => '0');
            SCAN03(4 downto 1) <= (others => '0');
            SCAN04(7 downto 1) <= (others => '0');
            SCAN05(6) <= '0';
            SCAN05(4 downto 2) <= (others => '0');
            SCAN05(0) <='0';
            SCAN06 <= (others => '0');
            SCAN07 <= (others => '0');
            SCAN08 <= (others => '0');
            SCAN09 <= (others => '0');
            SCAN10 <= (others => '0');
        elsif rising_edge(KCLK) then
            if KEY_VALID = '1' then
                case PS2KEY(7 downto 0) is
                    when X"07" => SCAN01(7) <= PS2KEY(9); -- KANA
                    when X"0E" => SCAN01(6) <= PS2KEY(9); -- GRAPH
                    when X"01" | X"78" => SCAN01(5) <= PS2KEY(9); -- =
                    when X"0D" => SCAN01(4) <= PS2KEY(9); -- EISUU
                    when X"4C" => SCAN01(2) <= PS2KEY(9); -- ;
                    when X"52" => SCAN01(1) <= PS2KEY(9); -- :
                    when X"5A" => SCAN01(0) <= PS2KEY(9); -- CR
                    when X"35" => SCAN02(7) <= PS2KEY(9); -- Y
                    when X"1A" => SCAN02(6) <= PS2KEY(9); -- Z
                    when X"54" => SCAN02(5) <= PS2KEY(9); -- @
                    when X"5B" => SCAN02(4) <= PS2KEY(9); -- (
                    when X"5D" => SCAN02(3) <= PS2KEY(9); -- )
                    when X"15" => SCAN03(7) <= PS2KEY(9); -- Q
                    when X"2D" => SCAN03(6) <= PS2KEY(9); -- R
                    when X"1B" => SCAN03(5) <= PS2KEY(9); -- S
                    when X"2C" => SCAN03(4) <= PS2KEY(9); -- T
                    when X"3C" => SCAN03(3) <= PS2KEY(9); -- U
                    when X"2A" => SCAN03(2) <= PS2KEY(9); -- V
                    when X"1D" => SCAN03(1) <= PS2KEY(9); -- W
                    when X"22" => SCAN03(0) <= PS2KEY(9); -- X
                    when X"43" => SCAN04(7) <= PS2KEY(9); -- I
                    when X"3B" => SCAN04(6) <= PS2KEY(9); -- J
                    when X"42" => SCAN04(5) <= PS2KEY(9); -- K
                    when X"4B" => SCAN04(4) <= PS2KEY(9); -- L
                    when X"3A" => SCAN04(3) <= PS2KEY(9); -- M
                    when X"31" => SCAN04(2) <= PS2KEY(9); -- N
                    when X"44" => SCAN04(1) <= PS2KEY(9); -- O
                    when X"4D" => SCAN04(0) <= PS2KEY(9); -- P
                    when X"1C" => SCAN05(7) <= PS2KEY(9); -- A
                    when X"32" => SCAN05(6) <= PS2KEY(9); -- B
                    when X"21" => SCAN05(5) <= PS2KEY(9); -- C
                    when X"23" => SCAN05(4) <= PS2KEY(9); -- D
                    when X"24" => SCAN05(3) <= PS2KEY(9); -- E
                    when X"2B" => SCAN05(2) <= PS2KEY(9); -- F
                    when X"34" => SCAN05(1) <= PS2KEY(9); -- G
                    when X"33" => SCAN05(0) <= PS2KEY(9); -- H
                    when X"16" => SCAN06(7) <= PS2KEY(9); -- 1
                    when X"1E" => SCAN06(6) <= PS2KEY(9); -- 2
                    when X"26" => SCAN06(5) <= PS2KEY(9); -- 3
                    when X"25" => SCAN06(4) <= PS2KEY(9); -- 4
                    when X"2E" => SCAN06(3) <= PS2KEY(9); -- 5
                    when X"36" => SCAN06(2) <= PS2KEY(9); -- 6
                    when X"3D" => SCAN06(1) <= PS2KEY(9); -- 7
                    when X"3E" => SCAN06(0) <= PS2KEY(9); -- 8
                    when X"6A" => SCAN07(7) <= PS2KEY(9); -- *
                    when X"55" => SCAN07(6) <= PS2KEY(9); -- +
                    when X"4E" => SCAN07(5) <= PS2KEY(9); -- -
                    when X"29" => SCAN07(4) <= PS2KEY(9); -- ' '
                    when X"45" => SCAN07(3) <= PS2KEY(9); -- 0
                    when X"46" => SCAN07(2) <= PS2KEY(9); -- 9
                    when X"41" => SCAN07(1) <= PS2KEY(9); -- ,
                    when X"49" => SCAN07(0) <= PS2KEY(9); -- .
                    when X"70" => SCAN08(7) <= PS2KEY(9); -- INST
                    when X"71" => SCAN08(6) <= PS2KEY(9); -- DEL
                    when X"75" => SCAN08(5) <= PS2KEY(9); -- UP
                    when X"72" => SCAN08(4) <= PS2KEY(9); -- DOWN
                    when X"74" => SCAN08(3) <= PS2KEY(9); -- RIGHT
                    when X"6B" => SCAN08(2) <= PS2KEY(9); -- LEFT
                    when X"51" => SCAN08(1) <= PS2KEY(9); -- ?
                    when X"4A" => SCAN08(0) <= PS2KEY(9); -- /
                    when X"66" => SCAN09(7) <= PS2KEY(9); -- BREAK
                    when X"58" => SCAN09(6) <= PS2KEY(9); -- CTRL
                    when X"12" | X"59" => SCAN09(0) <= PS2KEY(9);
                    when X"05" => SCAN10(7) <= PS2KEY(9); -- F1
                    when X"06" => SCAN10(6) <= PS2KEY(9); -- F2
                    when X"04" => SCAN10(5) <= PS2KEY(9); -- F3
                    when X"0C" => SCAN10(4) <= PS2KEY(9); -- F4
                    when X"03" => SCAN10(3) <= PS2KEY(9); -- F5
                    when others =>
                end case;
            end if;
        end if;
    end process;

    --
    -- response from key access
    --
    PB <=
        (not SCAN01) when PA = "0000" else
        (not SCAN02) when PA = "0001" else
        (not SCAN03) when PA = "0010" else
        (not SCAN04) when PA = "0011" else
        (not SCAN05) when PA = "0100" else
        (not SCAN06) when PA = "0101" else
        (not (SCAN07(7 downto 5) & (SCAN07(4) or JOYB(4)) & SCAN07(3 downto 0))) when PA="0110" else
        (not (SCAN08(7 downto 6) & (SCAN08(5) or JOYA(0) or JOYB(0)) & (SCAN08(4) or JOYA(1) or JOYB(1)) & (SCAN08(3) or JOYA(3) or JOYB(3)) & (SCAN08(2) or JOYA(2) or JOYB(2)) & SCAN08(1 downto 0))) when PA = "0111" else
        (not (SCAN09(7) & (SCAN09(6) or JOYA(4)) & SCAN09(5 downto 1) & (SCAN09(0) or JOYA(5)))) when PA = "1000" else
        (not SCAN10) when PA = "1001"
        else (others=>'1');


end Behavioral;
