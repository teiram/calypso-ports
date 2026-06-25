-------------------------------------------------------------------------------
--
-- FPGA SVI-328 based on Colecovision
--
-- $Id: cv_addr_dec.vhd,v 1.3 2006/01/05 22:22:29 arnim Exp $
--
-- Address Decoder
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

entity cv_addr_dec is

  port (
    clk_i           : in  std_logic;
    reset_n_i       : in  std_logic;
    a_i             : in  std_logic_vector(15 downto 0);
    d_i             : in  std_logic_vector(7 downto 0);
    iorq_n_i        : in  std_logic;
    rd_n_i          : in  std_logic;
    wr_n_i          : in  std_logic;
    mreq_n_i        : in  std_logic;
    rfsh_n_i        : in  std_logic;
    m1_n_i          : in  std_logic;
    ram_ce_n_o      : out std_logic;
    vdp_r_n_o       : out std_logic;
    vdp_w_n_o       : out std_logic;
    ay_addr_we_n_o  : out std_logic;
    ay_data_we_n_o  : out std_logic;
    ay_data_rd_n_o  : out std_logic;
    u8255_cs_n_o    : out std_logic
  );

end cv_addr_dec;


architecture rtl of cv_addr_dec is


begin

  -----------------------------------------------------------------------------
  -- Process dec
  --
  -- Purpose:
  --   Implements the address decoding logic.
  --
  dec: process (a_i,
                iorq_n_i,
                rd_n_i, wr_n_i,
                mreq_n_i,
                rfsh_n_i,
                m1_n_i
    )
  variable mux_v : std_logic_vector(2 downto 0);
  begin
    -- default assignments
    ram_ce_n_o      <= '1';

    vdp_r_n_o       <= '1';
    vdp_w_n_o       <= '1';

    ay_addr_we_n_o  <= '1';
    ay_data_we_n_o  <= '1';
    ay_data_rd_n_o  <= '1';

    u8255_cs_n_o    <= '1';

 if rfsh_n_i = '1' then 
    -- Memory access ----------------------------------------------------------
    if mreq_n_i = '0' then
        ram_ce_n_o <= '0';
    end if;

    -- I/O access -------------------------------------------------------------
    if iorq_n_i = '0' and m1_n_i = '1' then

      --VDP	
      if a_i(7 downto 0) = x"80" and wr_n_i = '0' then
        vdp_w_n_o <= '0';
      elsif a_i(7 downto 0) = x"81" and wr_n_i = '0' then
        vdp_w_n_o <= '0';
      end if;
      if a_i(7 downto 0) = x"84" and rd_n_i = '0' then
        vdp_r_n_o <= '0';
      elsif a_i(7 downto 0) = x"85" and rd_n_i = '0' then
        vdp_r_n_o <= '0';
      end if;

      --AY
      if a_i(7 downto 0) = x"88" and wr_n_i = '0' then
        ay_addr_we_n_o  <= '0';
      elsif a_i(7 downto 0) = x"8C" and wr_n_i = '0' then
        ay_data_we_n_o  <= '0';
      elsif a_i(7 downto 0) = x"90" and rd_n_i = '0' then
        ay_data_rd_n_o  <= '0';
      end if;

      --8255
      if a_i(7 downto 0) >= x"94" and a_i(7 downto 0) <= x"9B" then
        u8255_cs_n_o <= '0';
      end if;

      
    end if;
  end if;	 
 end process dec;

end rtl;
