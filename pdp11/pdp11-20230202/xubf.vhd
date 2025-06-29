
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

entity xubf is
   port(
      base_addr : in std_logic_vector(17 downto 0);

      npr : out std_logic;
      npg : in std_logic;

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      bus_master_addr : out std_logic_vector(17 downto 0);
      bus_master_dati : in std_logic_vector(15 downto 0);
      bus_master_dato : out std_logic_vector(15 downto 0);
      bus_master_control_dati : out std_logic;
      bus_master_control_dato : out std_logic;
      bus_master_nxm : in std_logic;

      xubf_cs : out std_logic;
      xubf_mosi : out std_logic;
      xubf_sclk : out std_logic;
      xubf_miso : in std_logic;
      xubf_srdy : in std_logic;

      have_xu_esp : in integer range 0 to 1 := 0;

      reset : in std_logic;
      xubfclk : in std_logic;
      clk : in std_logic
   );
end xubf;

architecture implementation of xubf is


-- regular bus interface

signal base_addr_match : std_logic;

-- registers for the bus interface - remember addresses for the xu cpu are at most 16 bits long, as there is no mmu

signal xubf_xf : std_logic_vector(15 downto 0);            -- xmit from this address
signal xubf_rt : std_logic_vector(15 downto 0);            -- receive to this address
signal xubf_rl : std_logic_vector(10 downto 0);            -- run length, in bytes - lsb should be 0

-- internal buffered versions of the registers

signal xf : std_logic_vector(15 downto 0);                 -- xmit from
signal rt : std_logic_vector(15 downto 0);                 -- receive to

signal xl : std_logic_vector(13 downto 0);                 -- xmit length, in bits

signal xmitwork : std_logic_vector(15 downto 0);           -- xmit shift register
signal recvwork : std_logic_vector(15 downto 0);           -- recv shift register
signal firstword : std_logic;                              -- are we on the first word of the run

signal run : std_logic;
signal cs : std_logic;

signal srdy : std_logic;
signal srdy1 : std_logic;

signal bitcount : integer range 0 to 15;

type cmd_state_type is (
   cmd_start,
   cmd_xmit,
   cmd_recv,
   cmd_recv2,
   cmd_done,
   cmd_wait
);
signal cmd_state : cmd_state_type := cmd_done;

begin


-- regular bus interface

   base_addr_match <= '1' when have_xu_esp = 1 and base_addr(17 downto 4) = bus_addr(17 downto 4) else '0';
   bus_addr_match <= base_addr_match;

   xubf_cs <= cs;
   xubf_sclk <= clk; -- when cs = '0' else '0';

-- regular bus interface : handle register contents and dependent logic

   process(clk, reset)
   begin
      if clk = '1' and clk'event then
         if reset = '1' then
            if have_xu_esp = 1 then
               npr <= '0';

               xubf_xf <= (others => '0');
               xubf_rt <= (others => '0');

               run <= '0';

               srdy1 <= '1';
               srdy <= '1';

            else
               npr <= '0';
            end if;

         else
            if have_xu_esp = 1 then

               srdy1 <= xubf_srdy;
               srdy <= srdy1;

               if base_addr_match = '1' and bus_control_dati = '1' then

                  case bus_addr(2 downto 1) is
                     when "00" =>
                        bus_dati <= srdy & "0000000" & srdy & "0000000";

                     when others =>
                        bus_dati <= (others => '0');

                  end case;
               end if;

               if base_addr_match = '1' and bus_control_dato = '1' then
                  case bus_addr(2 downto 1) is
                     when "00" =>
                        xubf_xf <= bus_dato;

                     when "01" =>
                        xubf_rt <= bus_dato;
                        run <= '1';

                     when "10" =>
                        xubf_rl <= bus_dato(10 downto 0);

                     when others =>
                        null;

                  end case;
               end if;

               if run = '1' then
                  npr <= '1';
                  if npg = '1' then
                     if cmd_state = cmd_done then
                        run <= '0';
                        npr <= '0';
                     end if;
                  end if;
               end if;

            end if;

         end if;
      end if;
   end process;


-- state machine for spi communication to the esp32
-- it is a bit unusual for spi, in that the streams from and
-- to esp32 are full duplex - and such the esp-to-xubf stream
-- cannot depend on the xubf-to-esp stream.


   process(xubfclk, reset)
   begin
      if xubfclk = '1' and xubfclk'event then
         if reset = '1' then
            if have_xu_esp = 1 then
               bus_master_addr <= (others => '0');
               bus_master_dato <= (others => '0');
               bus_master_control_dati <= '0';
               bus_master_control_dato <= '0';

               cs <= '1';
            end if;

         else
            if have_xu_esp = 1 then
               if run = '1' then
                  if npg = '1' and srdy = '0' then

                     case cmd_state is

                        when cmd_start =>
                           rt <= xubf_rt;
                           xf <= xubf_xf + 2;
                           xl <= xubf_rl & "000";

                           bitcount <= 15;
                           bus_master_addr <= "00" & xubf_xf;
                           bus_master_control_dati <= '1';
                           cmd_state <= cmd_xmit;
                           firstword <= '1';
                           recvwork <= (others => '0');

                        when cmd_xmit =>
                           bitcount <= bitcount - 1;
                           if bitcount = 15 then
                              bus_master_control_dati <= '0';
                              xmitwork <= bus_master_dati(14 downto 0) & bus_master_dati(15);
                              xubf_mosi <= bus_master_dati(7);
                              cs <= '0';
                           else
                              xubf_mosi <= xmitwork(7);
                              xmitwork <= xmitwork(14 downto 0) & xmitwork(15);
                              if bitcount = 14 then
                                 if firstword = '0' then
                                    bus_master_addr <= "00" & rt;
                                    rt <= rt + 2;
                                    bus_master_control_dato <= '1';
                                    bus_master_dato <= recvwork;
                                 else
                                    firstword <= '0';
                                 end if;
                              else
                                 bus_master_control_dato <= '0';
                              end if;
                              if bitcount = 0 then
                                 bitcount <= 15;
                                 bus_master_addr <= "00" & xf;
                                 xf <= xf + 2;
                                 bus_master_control_dati <= '1';
                              end if;
                           end if;
                           recvwork <= recvwork(14 downto 8) & xubf_miso & recvwork(6 downto 0) & recvwork(15);
                           if xl = "00000000000000" then
                              cmd_state <= cmd_recv;
                              cs <= '1';
                           else
                              xl <= xl - 1;
                           end if;

                        when cmd_recv =>
                           bus_master_addr <= "00" & rt;
                           bus_master_control_dato <= '1';
                           bus_master_dato <= recvwork;
                           cmd_state <= cmd_recv2;

                        when cmd_recv2 =>
                           bus_master_control_dato <= '0';
                           cmd_state <= cmd_done;

                        when cmd_done =>

                        when cmd_wait =>
                           cmd_state <= cmd_start;

                        when others =>
                           null;
                     end case;

                  end if;

               else
                  cmd_state <= cmd_wait;
                  cs <= '1';
               end if;

            end if;

         end if;
      end if;
   end process;
end implementation;
