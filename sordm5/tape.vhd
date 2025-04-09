--//============================================================================
--//  Sord M5
--//
--//  Tape player
--//  Copyright (C) 2021 molekula
--//
--//  This program is free software; you can redistribute it and/or modify it
--//  under the terms of the GNU General Public License as published by the Free
--//  Software Foundation; either version 2 of the License, or (at your option)
--//  any later version.
--//
--//  This program is distributed in the hope that it will be useful, but WITHOUT
--//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
--//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
--//  more details.
--//
--//  You should have received a copy of the GNU General Public License along
--//  with this program; if not, write to the Free Software Foundation, Inc.,
--//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--//
--//============================================================================

library ieee;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

entity casPlayer is
  port (
    clk_i           : in  std_logic;
    reset_n         : in  std_logic;
    ioctl_addr_i    : in  std_logic_vector( 24 downto 0);
    ioctl_dout_i    : in  std_logic_vector( 7 downto 0);
    ioctl_index_i   : in  std_logic_vector( 7 downto 0);
    ioctl_wr_i      : in  std_logic;
    ioctl_download_i: in  std_logic;
    casOut_o        : out std_logic;
    mem_addr_o      : out std_logic_vector( 27 downto 0);
	  mem_dout_i      : in  std_logic_vector( 7 downto 0);
	  mem_din_o       : out std_logic_vector( 7 downto 0);
	  mem_wr_o        : out std_logic;
	  mem_rd_o        : out std_logic;
	  mem_ready_i     : in  std_logic;
    cas_border_o    : out std_logic_vector( 4 downto 0);
    casOn_i         : in  std_logic;
    casSpeed_i      : in  std_logic
  );

end casPlayer;


architecture rtl of casPlayer is
  signal data_lenght_s      : unsigned( 24 downto 0) := (others => '0');
  signal addr_play_s        : unsigned( 24 downto 0) := (others => '0');
  signal cas_write_buffer_s : std_logic;
  signal cas_buffer_valid_s : std_logic := '0';
  signal cas_mem_rd_s       : std_logic;
  signal data_s             : std_logic_vector(7 downto 0);
  signal start_s            : std_logic;
  signal sync_s             : std_logic;
  signal end_s              : std_logic;
  signal busy_s             : std_logic;
  signal casOut_s           : std_logic;
  signal casSpeed_s         : std_logic := '0';
  
begin  
  
  cas_write_buffer_s <= ioctl_wr_i and ioctl_download_i;
  mem_addr_o <= ("000"&ioctl_addr_i) when ioctl_download_i = '1' else ("000"&std_logic_vector(addr_play_s));
  mem_din_o <= ioctl_dout_i;
  mem_wr_o <= cas_write_buffer_s;
  mem_rd_o <= cas_mem_rd_s;
  casOut_o <= casOut_s;
  cas_border_o <= (casOut_s&data_s(3 downto 0));
  
  last : process(cas_write_buffer_s)
  begin
    if rising_edge(cas_write_buffer_s) then
      data_lenght_s <= unsigned(ioctl_addr_i);
    end if;
  end process;
  
  validCheck: process(cas_write_buffer_s)
  begin
    if rising_edge(cas_write_buffer_s) then
      if (ioctl_addr_i=(ioctl_addr_i'range=>'0'))  then 
         cas_buffer_valid_s <= '1';
      end if;
      if ioctl_addr_i(24 downto 4) = (ioctl_addr_i(24 downto 4)'range=>'0') then
        case (ioctl_addr_i(3 downto 0)) is
          when x"0" =>
            if ioctl_dout_i /= X"53" then
              cas_buffer_valid_s <= '0';
            end if;
          when x"1" =>
            if ioctl_dout_i /= X"4f" then
              cas_buffer_valid_s <= '0';
            end if;
          when x"2" =>
            if ioctl_dout_i /= X"52" then
              cas_buffer_valid_s <= '0';
            end if;
          when x"3" =>
            if ioctl_dout_i /= X"44" then
              cas_buffer_valid_s <= '0';
            end if;
          when x"4" =>
            if ioctl_dout_i /= X"4D" then
              cas_buffer_valid_s <= '0';
            end if;
          when x"5" =>
            if ioctl_dout_i /= X"35" then
              cas_buffer_valid_s <= '0';
            end if;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;
  
  
  play: process(clk_i)
    type play_state_t is (PLAY_START, PLAY_READ_TYPE, PLAY_READ_LENGHT, PLAY_SYNC, PLAY_DATA, PLAY_STOP, PLAY_IDLE);    
    variable count_v       : integer;
    variable packet_type_v : std_logic_vector (7 downto 0);
    variable play_state_v  : play_state_t := PLAY_IDLE;
  begin
    if rising_edge(clk_i) then
      if ioctl_download_i = '1' then 
        addr_play_s <= (4 => '1', others=>'0');
        play_state_v := PLAY_START;
        cas_mem_rd_s <= '0';
        start_s <= '0';
        end_s <= '0';
        casSpeed_s <= casSpeed_i;
      end if;

      if ioctl_download_i = '0' and cas_buffer_valid_s = '1' and casOn_i = '1' then
        if data_lenght_s < addr_play_s and play_state_v /= PLAY_IDLE then
          play_state_v := PLAY_STOP;
        end if;
        case play_state_v is
          when PLAY_START =>
            if mem_ready_i = '1' then 
              cas_mem_rd_s <= '1';
              play_state_v := PLAY_READ_TYPE;
              start_s <= '0';
            end if;
          when PLAY_READ_TYPE =>
            cas_mem_rd_s <= '0';
            if mem_ready_i = '1' and cas_mem_rd_s = '0' then 
              if mem_dout_i = X"48" then 
                count_v := 1000;
              else
                count_v := 64;
              end if;
              addr_play_s <= addr_play_s + 1;
              cas_mem_rd_s <= '1';
              play_state_v := PLAY_SYNC;
            end if;
          when PLAY_SYNC => 
            start_s <= '0';
            if busy_s = '0' then
              data_s <= (others => '1');
              start_s <= '1';
              sync_s <= '1';
              count_v := count_v - 1;
            end if;
            if count_v = 0 then
              play_state_v := PLAY_READ_LENGHT;
            end if;
          when PLAY_READ_LENGHT =>
            cas_mem_rd_s <= '0';
            if mem_ready_i = '1' and cas_mem_rd_s = '0' then 
              if mem_dout_i = (mem_dout_i'range=>'0') then 
                count_v := 16#103#;
              else 
                count_v := to_integer(unsigned(mem_dout_i)) + 3;
              end if;
              play_state_v := PLAY_DATA;
              addr_play_s <= addr_play_s -1;
              cas_mem_rd_s <= '1';
            end if;
          when PLAY_DATA => 
            start_s <= '0';
            cas_mem_rd_s <= '0';
            if busy_s = '0'  and  start_s = '0' and  mem_ready_i = '1' and cas_mem_rd_s = '0' then
              data_s <= mem_dout_i;
              start_s <= '1';
              sync_s <= '0';
              count_v := count_v - 1;
              addr_play_s <= addr_play_s + 1;
              cas_mem_rd_s <= '1';
              end if;
            if count_v = 0 then
              if data_lenght_s < addr_play_s then
                play_state_v := PLAY_STOP;
              else
                play_state_v := PLAY_READ_TYPE;
              end if;
            end if;
          when PLAY_STOP => 
            start_s <= '0';
            if busy_s = '0' and start_S = '0' then
              start_s <= '1';
              sync_s <= '0';
              end_s <= '1';
              play_state_v := PLAY_IDLE;
            end if;
          when PLAY_IDLE =>
            start_s <= '0';
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  
  pulse : work.pulse
  port map (
    clk_i => clk_i,
    data_i => data_s, 
    start_i => start_s,
    sync_i => sync_s, 
    busy_o => busy_s, 
    cmtOut_o => casOut_s,
    end_i => end_s,
    casSpeed_i => casSpeed_s
  );

  
end rtl;


library ieee;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;


entity pulseClock is
  port (
    clk_i           : in   std_logic;
    pulse_o         : out  std_logic := '0';
    casSpeed_i      : in   std_logic
  );

end pulseClock;


architecture rtl of pulseClock is

begin
  pulse: process (clk_i)
  variable counter_v : integer := 5208;  
  variable pulse_v : std_logic := '0';
  begin
    if clk_i'event and clk_i = '1' then
      if counter_v = 0 then
        pulse_v := not pulse_v;
        if casSpeed_i = '1' then
          counter_v := 2604;  
        else
          counter_v := 5208;  
        end if;
      else
        counter_v := counter_v - 1;
      end if;
    end if;
  pulse_o <= pulse_v; 
  end process;     
end rtl;


library ieee;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;


entity pulse is
  port (
    clk_i           : in  std_logic;
    data_i          : in  std_logic_vector( 7 downto 0);
    start_i         : in  std_logic;
    sync_i          : in  std_logic;
    end_i           : in  std_logic;
    busy_o          : out std_logic := '0';
    cmtOut_o        : out std_logic := '0';
    casSpeed_i      : in  std_logic
  );

end pulse;


architecture rtl of pulse is
  signal count_s : integer := 0;
  signal pulse_s : std_logic;

begin
  
  busy_o <= '0' when count_s = 0 else '1';    

  byteSend: process (clk_i, start_i, pulse_s, sync_i, end_i)
    variable cmtOut_v     : std_logic := '0';    
    variable add_v        : std_logic := '0';
    variable send_v       : std_logic_vector( 9 downto 0);
    variable prev_start_v : std_logic := '0';
    variable prev_pulse_v : std_logic := '0';
    variable mode_v       : std_logic_vector ( 1 downto 0);
  begin
    mode_v := end_i & sync_i;
    if rising_edge(clk_i) then
      if count_s = 0 then
        if start_i = '1' and prev_start_v = '0' then
          case (mode_v) is
            when "00" =>
              send_v := '1' & data_i & '0';
              count_s <= 10;
            when "01" =>
              send_v := "00" & data_i;
              count_s <= 8;
            when others  =>
              send_v := (others => '1');
              count_s <= 1;
          end case;          
        end if;
      else
        if prev_pulse_v = '0' and pulse_s = '1' then
          if add_v = '1' then
            add_v := '0';
          else
            if cmtOut_v = '0' then
              cmtOut_v := '1';
              add_v := not send_v(0);
            else
              cmtOut_v := '0';
              add_v :=not send_v(0); 
              send_v := '0' & send_v(9 downto 1);
              count_s <= count_s - 1 ;
            end if;
          end if;
        end if;
      end if;
      prev_start_v := start_i;
      prev_pulse_v := pulse_s;
      cmtOut_o <= cmtOut_v;
    end if;    
  end process;

  
  
  clock : work.pulseClock
    port map (
      clk_i => clk_i,
      pulse_o => pulse_s,
      casSpeed_i => casSpeed_i
    );
  
end rtl;