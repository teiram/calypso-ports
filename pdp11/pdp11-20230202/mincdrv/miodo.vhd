
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

entity miodo is
   port(
      mo_scl : inout std_logic;                                      -- scl - clock line to the i2c target
      mo_sda : inout std_logic;                                      -- sda - data line to the i2c target

      mo_data : in std_logic_vector(15 downto 0);                    -- the data to be output
      mo_hb : in std_logic;                                          -- high byte strobe
      mo_lb : in std_logic;                                          -- low byte strobe
      mo_ie : in std_logic;                                          -- '1' when the module is interrupt enabled and waiting for a reply
      mo_reply : out std_logic := '0';                               -- reply towards the module

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end miodo;


architecture implementation of miodo is


signal clkdiv_i2c : integer range 0 to 127;

signal i2c_byte : std_logic_vector(7 downto 0);
type state_type is (
   state_idle,
   state_rec1, state_rec2,
   state_addr, state_cmd1, state_byte1, state_byte2,
   state_send, state_send1, state_send2, state_send3, state_send4,
   state_start,
   state_ack1, state_ack2, state_ack3, state_ack4,
   state_stop, state_stop1, state_stop2
);
signal state : state_type;
signal nextstate : state_type;
signal byte_out : std_logic_vector(7 downto 0);
signal byte_in : std_logic_vector(7 downto 0);
signal bitcount : integer range 0 to 10;

signal sendack : integer range 0 to 1 := 0;

signal data1 : std_logic_vector(15 downto 0);
signal data2 : std_logic_vector(15 downto 0);

signal scl1 : std_logic;
signal scl : std_logic;
signal sda1 : std_logic;
signal sda : std_logic;

signal ie1 : std_logic;
signal ie2 : std_logic;
signal ie3 : std_logic;

signal hb1 : std_logic;
signal hb2 : std_logic;
signal hb3 : std_logic;
signal lb1 : std_logic;
signal lb2 : std_logic;
signal lb3 : std_logic;

signal replycounter : integer range 127 downto 0;

begin

   process(clk50mhz, reset)
   begin

      if clk50mhz = '1' and clk50mhz'event then
         if reset = '1' then
            clkdiv_i2c <= 0;
            state <= state_idle;
            mo_scl <= 'Z';
            mo_sda <= 'Z';
            mo_reply <= '0';
            replycounter <= 0;
         else
            clkdiv_i2c <= clkdiv_i2c + 1;

            data1 <= mo_data;
            data2 <= data1;
            ie1 <= mo_ie;
            ie2 <= ie1;
            hb1 <= mo_hb;
            hb2 <= hb1;
            lb1 <= mo_lb;
            lb2 <= lb1;

            scl1 <= mo_scl;
            scl <= scl1;
            sda1 <= mo_sda;
            sda <= sda1;

            if replycounter /= 0 then
               replycounter <= replycounter - 1;
               mo_reply <= '1';
            else
               mo_reply <= '0';
            end if;

            case state is
               when state_rec1 =>
                  mo_sda <= 'Z';
                  mo_scl <= 'Z';
                  if clkdiv_i2c = 0 then
                     state <= state_rec2;
                  end if;

               when state_rec2 =>
                  if clkdiv_i2c = 0 then
                     state <= state_idle;
                  end if;

               when state_idle =>
                  mo_sda <= 'Z';
                  mo_scl <= 'Z';
                  if hb2 = '1' or lb2 = '1' then
                     state <= state_addr;
                     hb3 <= hb2;
                     lb3 <= lb2;
                     ie3 <= ie2;
                  end if;

-- send data

               when state_addr =>
                  byte_out <= "10000000";
                  bitcount <= 7;
                  state <= state_send;
                  nextstate <= state_cmd1;

               when state_cmd1 =>
                  byte_out <= "10000" & ie3 & hb3 & lb3;
                  bitcount <= 7;
                  state <= state_send1;
                  nextstate <= state_byte1;

               when state_byte1 =>
                  byte_out <= data2(15 downto 8);
                  bitcount <= 7;
                  state <= state_send1;
                  nextstate <= state_byte2;

               when state_byte2 =>
                  byte_out <= data2(7 downto 0);
                  bitcount <= 7;
                  state <= state_send1;
                  nextstate <= state_stop;


-- end transaction

               when state_stop =>
                  if clkdiv_i2c = 0 then
                     mo_sda <= '0';
                     state <= state_stop1;
                  end if;

               when state_stop1 =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= 'Z';
                     if scl = '0' then                     -- allow clock stretching
                        clkdiv_i2c <= 1;
                     else
                        if clkdiv_i2c = 0 then
                           state <= state_stop2;
                        end if;
                     end if;
                  end if;

               when state_stop2 =>
                  if clkdiv_i2c = 0 then
                     mo_sda <= 'Z';
                     state <= state_idle;
                     if ie3 = '1' then
                        replycounter <= 25;
                     end if;
                  end if;

-- setup for start

               when state_send =>
                  mo_sda <= 'Z';
                  mo_scl <= 'Z';
                  if scl = '0' then
                     clkdiv_i2c <= 1;
                  end if;
                  if clkdiv_i2c = 0 then
                     mo_sda <= '0';
                     state <= state_start;
                  end if;

-- start

               when state_start =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= '0';
                     state <= state_send1;
                  end if;

-- send - four phases

               when state_send1 =>
                  if clkdiv_i2c = 0 then
                     if byte_out(7) = '0' then
                        mo_sda <= '0';
                     else
                        mo_sda <= 'Z';
                     end if;
                     byte_out <= byte_out(6 downto 0) & byte_out(7);
                     state <= state_send2;
                  end if;

               when state_send2 =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= 'Z';
                     state <= state_send3;
                  end if;

               when state_send3 =>
                  mo_scl <= 'Z';
                  if scl = '0' then                     -- allow clock stretching
                     clkdiv_i2c <= 1;
                  else
                     if clkdiv_i2c = 0 then
                        state <= state_send4;
                     end if;
                  end if;

               when state_send4 =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= '0';
                     byte_in <= byte_in(6 downto 0) & sda;
                     bitcount <= bitcount - 1;
                     if bitcount = 0 then
                        state <= state_ack1;
                     else
                        state <= state_send1;
                     end if;
                  end if;

-- ack - four phases

               when state_ack1 =>
                  if clkdiv_i2c = 0 then
                     if sendack = 1 then
                        mo_sda <= '0';
                        sendack <= 0;
                     else
                        mo_sda <= 'Z';
                     end if;
                     state <= state_ack2;
                  end if;

               when state_ack2 =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= 'Z';
                     state <= state_ack3;
                  end if;

               when state_ack3 =>
                  mo_scl <= 'Z';
                  if scl = '0' then                     -- allow clock stretching
                     clkdiv_i2c <= 1;
                  else
                     if clkdiv_i2c = 0 then
                        state <= state_ack4;
                     end if;
                  end if;

               when state_ack4 =>
                  if clkdiv_i2c = 0 then
                     mo_scl <= '0';
                     state <= nextstate;
                  end if;

               when others =>
                  state <= state_rec1;

            end case;

         end if;
      end if;

   end process;

end implementation;
