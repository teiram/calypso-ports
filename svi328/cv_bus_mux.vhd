-------------------------------------------------------------------------------
--
-- FPGA SVI-328 based on Colecovision 
--
-- $Id: cv_bus_mux.vhd,v 1.3 2006/01/05 22:22:29 arnim Exp $
--
-- Bus Multiplexer
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

entity cv_bus_mux is

  port (
    ram_ce_n_i      : in  std_logic;
    vdp_r_n_i       : in  std_logic;
    ay_data_rd_n_i  : in  std_logic;
    u8255_cs_n_i    : in  std_logic;
    ext_io_en_n_i   : in std_logic;
    cpu_ram_d_i     : in  std_logic_vector(7 downto 0);
    vdp_d_i         : in  std_logic_vector(7 downto 0);
    ay_d_i          : in  std_logic_vector(7 downto 0);
    joyfire         : in  std_logic_vector(1 downto 0);
    d_from_8255     : in  std_logic_vector(7 downto 0);
    ext_io_data_i   : in std_logic_vector(7 downto 0);
    d_o             : out std_logic_vector(7 downto 0)
  );

end cv_bus_mux;


architecture rtl of cv_bus_mux is

begin

  -----------------------------------------------------------------------------
  -- Process mux
  --
  -- Purpose:
  --   Masks the data buses and ands them together
  --
  mux: process (
                ram_ce_n_i,      cpu_ram_d_i,
                vdp_r_n_i,       vdp_d_i,
                joyfire,
                u8255_cs_n_i,    d_from_8255,
                ay_data_rd_n_i,  ay_d_i,
                ext_io_en_n_i,   ext_io_data_i)
    constant d_inact_c : std_logic_vector(7 downto 0) := (others => '1');
    variable 
             d_ram_v,
             d_vdp_v,
             d_8255_v,
             d_ay_v,
             d_ext_io_v : std_logic_vector(7 downto 0);
  begin
    -- default assignments
    d_ram_v  := d_inact_c;
    d_vdp_v  := d_inact_c;
    d_ay_v   := d_inact_c;
    d_8255_v := d_inact_c;
    d_ext_io_v := d_inact_c;

    if ram_ce_n_i = '0' then
      d_ram_v  := cpu_ram_d_i;
    end if;
    if vdp_r_n_i = '0' then
      d_vdp_v  := vdp_d_i;
    end if;
    if ay_data_rd_n_i = '0' then
      d_ay_v := ay_d_i;
    end if;
    if u8255_cs_n_i = '0' then
      d_8255_v:= d_from_8255;
    end if;
    if ext_io_en_n_i = '0' then
      d_ext_io_v := ext_io_data_i;
    end if;

    d_o <= 
           d_ram_v  and
           d_vdp_v  and
           d_8255_v and
           d_ay_v and
           d_ext_io_v;

  end process mux;
  --
  -----------------------------------------------------------------------------

end rtl;
