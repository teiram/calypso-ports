
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

entity mncadtpg is
   port(
      ad_channel : in std_logic_vector(5 downto 0);                  -- the current channel on the ad mux
      ad_basechannel : in integer range 0 to 63;                     -- the channel that this mncadtpg instance is for
      ad_type : out std_logic_vector(3 downto 0);                    -- gain bits and/or channel type code for the current channel
      ad_chgbits : in std_logic_vector(3 downto 0);                  -- new gain bits for the current channel
      ad_wcgbits : in std_logic;                                     -- when '1' program the chgbits into the current channel

      tp_gain0 : out std_logic_vector(3 downto 0);                   -- channel 0 output gain bits for programmable gain component
      tp_gain1 : out std_logic_vector(3 downto 0);                   -- channel 1 output gain bits for programmable gain component
      tp_gain2 : out std_logic_vector(3 downto 0);                   -- channel 2 output gain bits for programmable gain component
      tp_gain3 : out std_logic_vector(3 downto 0);                   -- channel 3 output gain bits for programmable gain component
      tp_gain4 : out std_logic_vector(3 downto 0);                   -- channel 4 output gain bits for programmable gain component
      tp_gain5 : out std_logic_vector(3 downto 0);                   -- channel 5 output gain bits for programmable gain component
      tp_gain6 : out std_logic_vector(3 downto 0);                   -- channel 6 output gain bits for programmable gain component
      tp_gain7 : out std_logic_vector(3 downto 0);                   -- channel 7 output gain bits for programmable gain component

      reset : in std_logic;
      clk : in std_logic
   );
end mncadtpg;


architecture implementation of mncadtpg is

subtype gain_unit is std_logic_vector(3 downto 0);
type gain_array_type is array(0 to 7) of gain_unit;
signal gain_bits : gain_array_type := gain_array_type'(
   "0000", "0000", "0000", "0000", "0000", "0000", "0000", "0000"
);

signal basechannel : std_logic_vector(5 downto 0);

begin

   tp_gain0 <= gain_bits(0);
   tp_gain1 <= gain_bits(1);
   tp_gain2 <= gain_bits(2);
   tp_gain3 <= gain_bits(3);
   tp_gain4 <= gain_bits(4);
   tp_gain5 <= gain_bits(5);
   tp_gain6 <= gain_bits(6);
   tp_gain7 <= gain_bits(7);
   basechannel <= conv_std_logic_vector(ad_basechannel,basechannel'length);

   process(clk, reset)
   begin

      if clk = '0' and clk'event then
         if reset = '1' then

         else

            if ad_channel(5 downto 3) = basechannel(5 downto 3) then
               if ad_wcgbits = '1' then
                  gain_bits(conv_integer(ad_channel(2 downto 0))) <= ad_chgbits;
                  ad_type <= ad_chgbits;
               else
                  ad_type <= gain_bits(conv_integer(ad_channel(2 downto 0)));
               end if;
            end if;
         end if;

      end if;

   end process;

end implementation;

