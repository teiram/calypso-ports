
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

entity miodi is
   port(
      mi_scl : inout std_logic;                                      -- scl - clock line to the i2c target
      mi_sda : inout std_logic;                                      -- sda - data line to the i2c target

      mi_data : out std_logic_vector(15 downto 0);                   -- the input data
      mi_event : in std_logic;                                       -- the event output on the module front panel
      mi_reply : in std_logic;                                       -- the reply output

      reset : in std_logic;
      clk50mhz : in std_logic
   );
end miodi;


architecture implementation of miodi is


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

signal byte1 : std_logic_vector(7 downto 0);

signal scl1 : std_logic;
signal scl : std_logic;
signal sda1 : std_logic;
signal sda : std_logic;

signal idletime : integer range 0 to 65535;

begin

   process(clk50mhz, reset)
   begin

      if clk50mhz = '1' and clk50mhz'event then
         if reset = '1' then
            clkdiv_i2c <= 0;
            state <= state_idle;
            idletime <= 65535;
            mi_scl <= 'Z';
            mi_sda <= 'Z';
            mi_data <= (others => '0');
         else
            clkdiv_i2c <= clkdiv_i2c + 1;

            scl1 <= mi_scl;
            scl <= scl1;
            sda1 <= mi_sda;
            sda <= sda1;

            case state is
               when state_rec1 =>
                  mi_sda <= 'Z';
                  mi_scl <= 'Z';
                  if clkdiv_i2c = 0 then
                     state <= state_rec2;
                  end if;

               when state_rec2 =>
                  if clkdiv_i2c = 0 then
                     state <= state_idle;
                     idletime <= 65535;
                  end if;

               when state_idle =>
                  mi_sda <= 'Z';
                  mi_scl <= 'Z';
                  if idletime > 0 then
                     if clkdiv_i2c = 0 then
                        idletime <= idletime - 1;
                     end if;
                  else
                     state <= state_addr;
                  end if;

-- send read command

               when state_addr =>
                  byte_out <= "10000" & mi_event & not mi_reply & "1";
                  bitcount <= 7;
                  state <= state_send;
                  nextstate <= state_byte1;

               when state_byte1 =>
                  byte_out <= (others => '1');
                  bitcount <= 7;
                  sendack <= 1;
                  state <= state_send1;
                  nextstate <= state_byte2;

               when state_byte2 =>
                  byte1 <= byte_in;
                  byte_out <= (others => '1');
                  bitcount <= 7;
                  sendack <= 1;
                  state <= state_send1;
                  nextstate <= state_stop;

-- end transaction

               when state_stop =>
                  mi_data(7 downto 0) <= byte_in;
                  mi_data(15 downto 8) <= byte1;
                  if clkdiv_i2c = 0 then
                     mi_sda <= '0';
                     state <= state_stop1;
                  end if;

               when state_stop1 =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= 'Z';
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
                     mi_sda <= 'Z';
                     state <= state_idle;
                     idletime <= 65535;
                  end if;

-- setup for start

               when state_send =>
                  mi_sda <= 'Z';
                  mi_scl <= 'Z';
                  if scl = '0' then
                     clkdiv_i2c <= 1;
                  end if;
                  if clkdiv_i2c = 0 then
                     mi_sda <= '0';
                     state <= state_start;
                  end if;

-- start

               when state_start =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= '0';
                     state <= state_send1;
                  end if;

-- send - four phases

               when state_send1 =>
                  if clkdiv_i2c = 0 then
                     if byte_out(7) = '0' then
                        mi_sda <= '0';
                     else
                        mi_sda <= 'Z';
                     end if;
                     byte_out <= byte_out(6 downto 0) & byte_out(7);
                     state <= state_send2;
                  end if;

               when state_send2 =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= 'Z';
                     state <= state_send3;
                  end if;

               when state_send3 =>
                  mi_scl <= 'Z';
                  if scl = '0' then                     -- allow clock stretching
                     clkdiv_i2c <= 1;
                  else
                     if clkdiv_i2c = 0 then
                        state <= state_send4;
                     end if;
                  end if;

               when state_send4 =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= '0';
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
                        mi_sda <= '0';
                        sendack <= 0;
                     else
                        mi_sda <= 'Z';
                     end if;
                     state <= state_ack2;
                  end if;

               when state_ack2 =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= 'Z';
                     state <= state_ack3;
                  end if;

               when state_ack3 =>
                  mi_scl <= 'Z';
                  if scl = '0' then                     -- allow clock stretching
                     clkdiv_i2c <= 1;
                  else
                     if clkdiv_i2c = 0 then
                        state <= state_ack4;
                     end if;
                  end if;

               when state_ack4 =>
                  if clkdiv_i2c = 0 then
                     mi_scl <= '0';
                     state <= nextstate;
                  end if;

               when others =>
                  state <= state_rec1;

            end case;

         end if;
      end if;

   end process;

end implementation;
