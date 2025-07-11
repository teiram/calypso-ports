
--
-- Copyright (c) 2008-2023 Sytse van Slooten
--
-- Permission is hereby granted to any person obtaining a copy of these VHDL source files and
-- other language source files and associated documentation files ("the materials") to use
-- these materials solely for personal, non-commercial purposes.
-- You are also granted permission to make changes to the materials, on the condition that this
-- copyright notice is retained unchanged.
--
-- The materials are distributed in the hope that they will be useful, but WITHOUT ANY WARRANTY;
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--

-- $Revision$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity adc is
   port(
      ad_start : in std_logic;
      ad_done : out std_logic := '0';
      ad_channel : in std_logic_vector(5 downto 0);
      ad_nxc : out std_logic := '0';
      ad_sample : out std_logic_vector(11 downto 0) := "000000000000";
      ad_type : out std_logic_vector(3 downto 0);

      ad_ch0 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch1 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch2 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch3 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch4 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch5 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch6 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch7 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch8 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch9 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch10 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch11 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch12 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch13 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch14 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch15 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch16 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch17 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch18 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch19 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch20 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch21 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch22 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch23 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch24 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch25 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch26 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch27 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch28 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch29 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch30 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch31 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch32 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch33 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch34 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch35 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch36 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch37 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch38 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch39 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch40 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch41 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch42 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch43 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch44 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch45 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch46 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch47 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch48 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch49 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch50 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch51 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch52 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch53 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch54 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch55 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch56 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch57 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch58 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch59 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch60 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch61 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch62 : in std_logic_vector(11 downto 0) := "000000000000";
      ad_ch63 : in std_logic_vector(11 downto 0) := "000000000000";

      ad_ch8_15 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch16_23 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch24_31 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch32_39 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch40_47 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch48_55 : in std_logic_vector(3 downto 0) := "0000";
      ad_ch56_63 : in std_logic_vector(3 downto 0) := "0000";

      reset : in std_logic;
      clk : in std_logic
   );
end adc;


architecture implementation of adc is

signal delay : integer range 0 to 63;

begin
   ad_nxc <= '0';

   ad_sample <= ad_ch0 when ad_channel = "000000" else
      ad_ch1 when ad_channel = "000001" else
      ad_ch2 when ad_channel = "000010" else
      ad_ch3 when ad_channel = "000011" else
      ad_ch4 when ad_channel = "000100" else
      ad_ch5 when ad_channel = "000101" else
      ad_ch6 when ad_channel = "000110" else
      ad_ch7 when ad_channel = "000111" else
      ad_ch8 when ad_channel = "001000" else
      ad_ch9 when ad_channel = "001001" else
      ad_ch10 when ad_channel = "001010" else
      ad_ch11 when ad_channel = "001011" else
      ad_ch12 when ad_channel = "001100" else
      ad_ch13 when ad_channel = "001101" else
      ad_ch14 when ad_channel = "001110" else
      ad_ch15 when ad_channel = "001111" else
      ad_ch16 when ad_channel = "010000" else
      ad_ch17 when ad_channel = "010001" else
      ad_ch18 when ad_channel = "010010" else
      ad_ch19 when ad_channel = "010011" else
      ad_ch20 when ad_channel = "010100" else
      ad_ch21 when ad_channel = "010101" else
      ad_ch22 when ad_channel = "010110" else
      ad_ch23 when ad_channel = "010111" else
      ad_ch24 when ad_channel = "011000" else
      ad_ch25 when ad_channel = "011001" else
      ad_ch26 when ad_channel = "011010" else
      ad_ch27 when ad_channel = "011011" else
      ad_ch28 when ad_channel = "011100" else
      ad_ch29 when ad_channel = "011101" else
      ad_ch30 when ad_channel = "011110" else
      ad_ch31 when ad_channel = "011111" else
      ad_ch32 when ad_channel = "100000" else
      ad_ch33 when ad_channel = "100001" else
      ad_ch34 when ad_channel = "100010" else
      ad_ch35 when ad_channel = "100011" else
      ad_ch36 when ad_channel = "100100" else
      ad_ch37 when ad_channel = "100101" else
      ad_ch38 when ad_channel = "100110" else
      ad_ch39 when ad_channel = "100111" else
      ad_ch40 when ad_channel = "101000" else
      ad_ch41 when ad_channel = "101001" else
      ad_ch42 when ad_channel = "101010" else
      ad_ch43 when ad_channel = "101011" else
      ad_ch44 when ad_channel = "101100" else
      ad_ch45 when ad_channel = "101101" else
      ad_ch46 when ad_channel = "101110" else
      ad_ch47 when ad_channel = "101111" else
      ad_ch48 when ad_channel = "110000" else
      ad_ch49 when ad_channel = "110001" else
      ad_ch50 when ad_channel = "110010" else
      ad_ch51 when ad_channel = "110011" else
      ad_ch52 when ad_channel = "110100" else
      ad_ch53 when ad_channel = "110101" else
      ad_ch54 when ad_channel = "110110" else
      ad_ch55 when ad_channel = "110111" else
      ad_ch56 when ad_channel = "111000" else
      ad_ch57 when ad_channel = "111001" else
      ad_ch58 when ad_channel = "111010" else
      ad_ch59 when ad_channel = "111011" else
      ad_ch60 when ad_channel = "111100" else
      ad_ch61 when ad_channel = "111101" else
      ad_ch62 when ad_channel = "111110" else
      ad_ch63 when ad_channel = "111111" else
      "000000000000";

   ad_type <=
      ad_ch8_15  when ad_channel(5 downto 3) = "001" else
      ad_ch16_23 when ad_channel(5 downto 3) = "010" else
      ad_ch24_31 when ad_channel(5 downto 3) = "011" else
      ad_ch32_39 when ad_channel(5 downto 3) = "100" else
      ad_ch40_47 when ad_channel(5 downto 3) = "101" else
      ad_ch48_55 when ad_channel(5 downto 3) = "110" else
      ad_ch56_63 when ad_channel(5 downto 3) = "111" else
      "0000";


   process(clk, reset, ad_start)
   begin

      if clk = '0' and clk'event then
         if reset = '1' then
            ad_done <= '0';
            delay <= 0;
         else

            if ad_start = '1' then
               delay <= 1;
            end if;
            if delay /= 0 then
               delay <= delay + 1;
            end if;
            if delay = 63 then                             -- yeah, this is dirty. Not sure why, but it is necessary to pass vmna.
               ad_done <= '1';
            end if;
            if ad_start = '0' then
               ad_done <= '0';
            end if;
         end if;

      end if;

   end process;

end implementation;

