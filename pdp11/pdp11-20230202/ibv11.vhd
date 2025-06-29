
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
-- without even the implibs_ied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--

-- $Revision$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ibv11 is
   port(
      base_addr : in std_logic_vector(17 downto 0);
      ivec : in std_logic_vector(8 downto 0);

      br : out std_logic;
      bg : in std_logic;
      int_vector : out std_logic_vector(8 downto 0);

      bus_addr_match : out std_logic;
      bus_addr : in std_logic_vector(17 downto 0);
      bus_dati : out std_logic_vector(15 downto 0);
      bus_dato : in std_logic_vector(15 downto 0);
      bus_control_dati : in std_logic;
      bus_control_dato : in std_logic;
      bus_control_datob : in std_logic;

      have_ibv11 : in integer range 0 to 1 := 0;

      reset : in std_logic;

      clk50mhz : in std_logic;
      clk : in std_logic
   );
end ibv11;

architecture implementation of ibv11 is


-- bus interface
signal base_addr_match : std_logic;

-- interrupt system
type interrupt_state_type is (
   i_idle,
   i_req,
   i_wait
);
signal interrupt_state : interrupt_state_type := i_idle;

-- logic
signal ibs : std_logic_vector(15 downto 0);
signal ibs_srq : std_logic;
signal ibs_er2 : std_logic;
signal ibs_er1 : std_logic;
signal ibs_cmd : std_logic;
signal ibs_tkr : std_logic;
signal ibs_lnr : std_logic;
signal ibs_acc : std_logic;
signal ibs_ie : std_logic;
signal ibs_ton : std_logic;
signal ibs_lon : std_logic;
signal ibs_ibc : std_logic;
signal ibs_rem : std_logic;
signal ibs_eop : std_logic;
signal ibs_tcs : std_logic;

signal ibd : std_logic_vector(15 downto 0);
signal ibd_eoi : std_logic := '0';
signal ibd_atn : std_logic := '0';
signal ibd_ifc : std_logic := '0';
signal ibd_ren : std_logic := '0';
signal ibd_srq : std_logic := '0';
signal ibd_rfd : std_logic := '0';
signal ibd_dav : std_logic := '0';
signal ibd_dac : std_logic := '0';
signal ibd_dio : std_logic_vector(7 downto 0) := "00000000";

signal ifc_counter : integer range 0 to 31;
signal dav_counter : integer range 0 to 31;
signal rfd_counter : integer range 0 to 31;
signal cmd_counter : integer range 0 to 31;

begin

   base_addr_match <= '1' when base_addr(17 downto 3) = bus_addr(17 downto 3) and have_ibv11 = 1 else '0';
   bus_addr_match <= base_addr_match;

   ibs <= ibs_srq & ibs_er2 & ibs_er1 & '0' & '0' & ibs_cmd & ibs_tkr & ibs_lnr & ibs_acc & ibs_ie & ibs_ton & ibs_lon & ibs_ibc & ibs_rem & ibs_eop & ibs_tcs;
   ibd <= ibd_eoi & ibd_atn & ibd_ifc & ibd_ren & ibd_srq & ibd_rfd & ibd_dav & ibd_dac & ibd_dio;

   process(clk, base_addr_match, reset, have_ibv11)
   begin
      if clk = '1' and clk'event then

         if have_ibv11 = 1 then
            if reset = '1' then
               interrupt_state <= i_idle;
               br <= '0';
            else

               case interrupt_state is

                  when i_idle =>
                     br <= '0';
                     if ibs_ie = '1' and (ibs_er2 = '1' or ibs_er1 = '1' or ibs_srq = '1' or ibs_tkr = '1' or ibs_cmd = '1' or ibs_lnr = '1') then
                        interrupt_state <= i_req;
                        br <= '1';
                     end if;

                  when i_req =>
                     if bg = '1' then
                        int_vector <= ivec;
                        if ibs_er2 = '1' or ibs_er1 = '1' then
                           int_vector <= ivec;
                        elsif ibs_srq = '1' then
                           int_vector <= ivec + o"004";
                           ibs_srq <= '0';
                        elsif ibs_tkr = '1' or ibs_cmd = '1' then
                           int_vector <= ivec + o"010";
                           ibs_tkr <= '0';
                           ibs_cmd <= '0';
                        elsif ibs_lnr = '1' then
                           int_vector <= ivec + o"014";
                           ibs_lnr <= '0';
                        end if;
                        br <= '0';
                        interrupt_state <= i_wait;
                     end if;

                  when i_wait =>
                     if bg = '0' then
                        interrupt_state <= i_idle;
                     end if;

                  when others =>
                     interrupt_state <= i_idle;

               end case;

            end if;
         else
            br <= '0';
         end if;

         if have_ibv11 = 1 then
            if reset = '1' then

               ibs_srq <= '0';
               ibs_er2 <= '0';
               ibs_er1 <= '0';
               ibs_cmd <= '0';
               ibs_tkr <= '0';
               ibs_lnr <= '0';
               ibs_acc <= '0';
               ibs_ie <= '0';
               ibs_ton <= '0';
               ibs_lon <= '0';
               ibs_ibc <= '0';
               ibs_rem <= '0';
               ibs_eop <= '0';
               ibs_tcs <= '0';

               ibd_dac <= '1';
               ibd_dio <= (others => '0');
               ibd_srq <= '0';

               ifc_counter <= 0;
               dav_counter <= 0;
               rfd_counter <= 0;
               cmd_counter <= 0;

            else

               if base_addr_match = '1' and bus_control_dati = '1' then
                  case bus_addr(2 downto 1) is
                     when "00" =>
                        bus_dati <= ibs;
                     when "01" =>
                        bus_dati <= ibd;
                        if ibs_acc = '0' then
                           ibd_dac <= '0';
                           ibs_lnr <= '0';
                        end if;
                     when others =>
                        bus_dati <= (others => '0');
                  end case;
               end if;

               if base_addr_match = '1' and bus_control_dato = '1' then

                  if bus_control_datob = '0' or (bus_control_datob = '1' and bus_addr(0) = '0') then
                     case bus_addr(2 downto 1) is
                        when "00" =>
                           ibs_acc <= bus_dato(7);
                           ibs_ie <= bus_dato(6);
                           ibs_ton <= bus_dato(5);
                           if bus_dato(5) = '1' then
                              ibs_tkr <= '1';
                           end if;
                           if bus_dato(5) = '0' then
                              ibs_tkr <= '0';
                           end if;
                           ibs_lon <= bus_dato(4);
                           ibs_ibc <= bus_dato(3);
                           if bus_dato(3) = '1' then
                              ifc_counter <= 20;
                           end if;
                           ibs_rem <= bus_dato(2);
                           if bus_dato(2) = '1' then
                              ibd_ren <= '1';
                           end if;
                           if bus_dato(2) = '0' then
                              ibd_ren <= '0';
                           end if;
                           ibs_eop <= bus_dato(1);
                           ibs_tcs <= bus_dato(0);
                           if bus_dato(0) = '1' then
                              ibs_tkr <= '0';
                              rfd_counter <= 3;
                              cmd_counter <= 6;
                              ibs_cmd <= '1';
                           end if;
                           if bus_dato(0) = '0' then
                              ibs_cmd <= '0';
                           end if;
                        when "01" =>
                           if ibs_ton = '1' or ibs_lon = '1' then
                              ibd_dio <= bus_dato(7 downto 0);
                              dav_counter <= 20;
                              if ibs_lon = '1' then
                                 ibd_dac <= '0';
                              else
                                 ibs_er2 <= '1';
                              end if;
                              ibs_tkr <= '0';
                           end if;
                        when others =>
                           null;
                     end case;
                  end if;
                  if bus_control_datob = '0' or (bus_control_datob = '1' and bus_addr(0) = '1') then
                     case bus_addr(2 downto 1) is
                        when "00" =>
                           ibs_srq <= bus_dato(15);
                        when "01" =>
                        when others =>
                           null;
                     end case;
                  end if;

               end if;

               if ibs = "0000000000000000" then
                  ibd_dac <= '1';
                  ibd_rfd <= '1';
               end if;

               if ibs_acc = '1' then
                  ibd_rfd <= '0';
               end if;

               if ibs_eop = '1' then
                  ibd_eoi <= '1';
               else
                  ibd_eoi <= '0';
               end if;

               if ibs_tcs = '1' then
                  ibd_atn <= '1';
               else
                  ibd_atn <= '0';
               end if;

               if rfd_counter > 0 then
                  rfd_counter <= rfd_counter - 1;
                  ibd_rfd <= '1';
               elsif rfd_counter = 1 then
                  ibd_rfd <= '0';
                  rfd_counter <= 0;
               end if;

               if cmd_counter > 0 then
                  cmd_counter <= cmd_counter - 1;
               elsif cmd_counter = 1 then
                  ibs_cmd <= '1';
                  cmd_counter <= 0;
               end if;

               if dav_counter > 0 then
                  dav_counter <= dav_counter - 1;
                  ibd_dav <= '1';
                  if ibs_lon = '1' then
                     ibs_lnr <= '1';
                  end if;
               else
                  ibd_dav <= '0';
               end if;

               if ifc_counter > 1 then
                  ifc_counter <= ifc_counter - 1;
                  ibd_ifc <= '1';
               elsif ifc_counter = 1 then
                  ibs_tcs <= '1';
                  ibs_cmd <= '1';
                  ibs_ibc <= '0';

                  ibs_tkr <= '0';
                  ibs_lnr <= '0';
                  ibs_acc <= '0';
                  ibs_ton <= '0';
                  ibs_lon <= '0';
                  ibs_rem <= '0';
                  ibs_eop <= '0';
                  ibd_ifc <= '0';
                  ibd_dac <= '1';
                  ifc_counter <= 0;
               end if;

            end if;
         end if;
      end if;
   end process;

end implementation;

