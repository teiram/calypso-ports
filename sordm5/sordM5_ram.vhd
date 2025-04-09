--//============================================================================
--//  Sord M5
--//  Memory
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
use ieee.std_logic_1164.all;
-- use IEEE.STD_LOGIC_ARITH.ALL;
-- use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity sordM5_rams is
port (
   clk_i                  : in  std_logic;
   reset_n_i              : in  std_logic;
   a_i                    : in  std_logic_vector(15 downto 0);
   d_i                    : in  std_logic_vector(7 downto 0);
   d_o                    : out std_logic_vector(7 downto 0);
   iorq_n_i               : in  std_logic;
   mreq_n_i               : in  std_logic;
   rfsh_n_i               : in  std_logic;
   m1_n_i                 : in  std_logic;
   rd_n_i                 : in  std_logic;
   wr_n_i                 : in  std_logic;
   ramMode_i              : in  std_logic_vector(8 downto 0);
   -- data io --------------------------------------------------------
   ioctl_addr             : in std_logic_vector( 24 downto 0);
   ioctl_dout             : in std_logic_vector( 7 downto 0);
   ioctl_index            : in std_logic_vector( 7 downto 0);
   ioctl_wr               : in std_logic;
   ioctl_download         : in std_logic;
   --SDRAM
    SDRAM_A               : out std_logic_vector(12 downto 0);
    SDRAM_DQ              : inout std_logic_vector(15 downto 0);
    SDRAM_DQML            : out std_logic;
    SDRAM_DQMH            : out std_logic;
    SDRAM_nWE             : out std_logic;
    SDRAM_nCAS            : out std_logic;
    SDRAM_nRAS            : out std_logic;
    SDRAM_nCS             : out std_logic;
    SDRAM_BA              : out std_logic_vector(1 downto 0);
    SDRAM_CLK             : out std_logic;
    SDRAM_CKE             : out std_logic;
    pll_locked_i          : in std_logic
  );

end sordM5_rams;


architecture rtl of sordM5_rams is
   type MMU_RAM_t is array(0 to 15) of std_logic_vector(7 downto 0);
   signal mmu_q_s         : std_logic_vector(19 downto 12);
   signal mmu_wr_s        : std_logic;
   signal rom_mmu_s       : std_logic_vector(4 downto 0);
   signal ramD1_q_s       : std_logic_vector(7 downto 0);
   signal ramD1_s         : std_logic;
   signal ramD1_we_s      : std_logic;
   signal ramD1_rd_s      : std_logic;
   signal rami_q_s        : std_logic_vector(7 downto 0);
   signal ram_q_s         : std_logic_vector(7 downto 0);
   signal rom_q_s         : std_logic_vector(7 downto 0);
   signal rom0_q_s        : std_logic_vector(7 downto 0);
   signal rom1_q_s        : std_logic_vector(7 downto 0);
   signal rom2_q_s        : std_logic_vector(7 downto 0);
   signal ramen_q_s       : std_logic_vector(7 downto 0);
   signal casen_q_s       : std_logic_vector(7 downto 0);
   signal ram_cs_s        : std_logic;
   signal ramD_cs_s       : std_logic;
   signal rom_cs_s        : std_logic;  
   signal rom_ioctl_we_s  : std_logic;
   signal ram_wp_en_s     : std_logic;
   signal em64_boot_ram_s : std_logic;
   signal kbf_mode_s      : std_logic_vector(7 downto 0);
   signal krx_mode_s      : std_logic_vector(7 downto 0);
   signal mmu_r_s         : MMU_RAM_t;
   signal sdram_addr      : std_logic_vector(22 downto 0);
   signal sdram_din       : std_logic_vector(15 downto 0);
   signal sdram_dout      : std_logic_vector(15 downto 0);
   signal sdram_we        : std_logic;
   signal sdram_rd        : std_logic;
   
   attribute keep: boolean;
   attribute keep of sdram_addr: signal is true;
   attribute keep of sdram_din: signal is true;
   attribute keep of sdram_dout: signal is true;
   attribute keep of sdram_we: signal is true;
   attribute keep of sdram_rd: signal is true;
   attribute keep of iorq_n_i: signal is true;
   attribute keep of mreq_n_i: signal is true;
   attribute keep of rfsh_n_i: signal is true;
   attribute keep of m1_n_i: signal is true;
   attribute keep of rd_n_i: signal is true;
   attribute keep of wr_n_i: signal is true;
   attribute keep of ram_cs_s: signal is true;
   attribute keep of rom_cs_s: signal is true;
   attribute keep of ramD_cs_s: signal is true;
   attribute keep of ioctl_wr: signal is true;
   attribute keep of ioctl_download: signal is true;
   attribute keep of ioctl_index: signal is true;

   
   FUNCTION inv(s1:std_logic_vector) return std_logic_vector is 
     VARIABLE Z : std_logic_vector(s1'high downto s1'low);
     BEGIN
     FOR i IN (s1'low) to s1'high LOOP
         Z(i) := NOT(s1(i));
     END LOOP;
     RETURN Z;
   END inv;

   component sdram
        port (
        init : in std_logic;
        clk  : in std_logic;
        SDRAM_DQ: inout std_logic_vector(15 downto 0);
        SDRAM_A: out std_logic_vector(12 downto 0);
        SDRAM_DQML : out std_logic;
        SDRAM_DQMH : out std_logic;
        SDRAM_nWE : out std_logic;
        SDRAM_nCAS : out std_logic;
        SDRAM_nRAS : out std_logic;
        SDRAM_nCS : out std_logic;
        SDRAM_BA : out std_logic_vector(1 downto 0);
        SDRAM_CKE : out std_logic;
        wtbt : in std_logic_vector(1 downto 0);
        addr : in std_logic_vector(22 downto 0);
        dout : out std_logic_vector (15 downto 0);
        din : in std_logic_vector (15 downto 0);
        we : in std_logic;
        rd : in std_logic;
        ready : out std_logic
      );
    end component;
    
   
begin

   ramD1_s <= '1' when ramD_cs_s = '1' and mmu_q_s(19 downto 18) = "00" else '0';
   ramD1_we_s <= '1' when ramD1_s = '1' and wr_n_i ='0' else '0';
   ramD1_rd_s <= '1' when ramD1_s = '1' and rd_n_i ='0' else '0';
   
   mmu_wr_s       <= '1' when iorq_n_i = '0' and m1_n_i = '1' and a_i(7 downto 2) = "011001" AND wr_n_i = '0' else '0'; -- mmu 0x64 - 0x67    
   d_o            <= sdram_dout(7 downto 0) when ram_cs_s  = '1' or rom_cs_s   = '1' or ramD1_s = '1' 
       else (others => '1');
   
   em64_boot_ram_s <= '1' when ramMode_i(2 downto 0) = "010" and ramMode_i(8) = '1' else '0';
   
   brno_ramen : work.io_latch
   generic map (
      compare_width => 6,
      compare_value => X"6C"
   )
   port map (
      clk_i       => clk_i,
      reset_n_i   => reset_n_i,
      d_i         => d_i,
      a_i         => a_i(7 downto 0),
      iorq_n_i    => iorq_n_i,
      m1_n_i      => m1_n_i,
      wr_n_i      => wr_n_i,
      q_o         => ramen_q_s,
      default_i   => (0 => em64_boot_ram_s, others => '0')
   );
   
   brno_casen : work.io_latch
   generic map (
      compare_width => 6,
      compare_value => X"68"
   )
   port map (
      clk_i       => clk_i,
      reset_n_i   => reset_n_i,
      d_i         => d_i,
      a_i         => a_i(7 downto 0),
      iorq_n_i    => iorq_n_i,
      m1_n_i      => m1_n_i,
      wr_n_i      => wr_n_i,
      q_o         => casen_q_s,
      default_i   => (others => '0')
   );
   
   em64kbf : work.io_latch
   generic map (
      compare_width => 8,
      compare_value => X"30"
   )
   port map (
      clk_i       => clk_i,
      reset_n_i   => reset_n_i,
      d_i         => d_i,
      a_i         => a_i(7 downto 0),
      iorq_n_i    => iorq_n_i,
      m1_n_i      => m1_n_i,
      wr_n_i      => wr_n_i,
      q_o         => kbf_mode_s,
      default_i   => (others => '0')
   );
   
   em64krx : work.io_latch
   generic map (
      compare_width => 8,
      compare_value => X"7F"
   )
   port map (
      clk_i       => clk_i,
      reset_n_i   => reset_n_i,
      d_i         => d_i,
      a_i         => a_i(7 downto 0),
      iorq_n_i    => iorq_n_i,
      m1_n_i      => m1_n_i,
      wr_n_i      => wr_n_i,
      q_o         => krx_mode_s,
      default_i   => (7=>'0', 6=>'0', others => '1')
   );

     
   ram_dec : work.ram_dec
   port map (
      a_i            => a_i(15 downto 0),
      mreq_n_i       => mreq_n_i,
      rfsh_n_i       => rfsh_n_i,
      wr_n_i         => wr_n_i,
      em64_ram_en_i  => ramen_q_s(0),
      brno_cas_en_i  => NOT casen_q_s(0),
      brno_ram_en_i  => ramen_q_s(0),
      brno_rom2_en_i => casen_q_s(7),
      ramD_cs_o      => ramD_cs_s,
      ram_cs_o       => ram_cs_s,
      rom_mmu_o      => rom_mmu_s,
      rom_cs_o       => rom_cs_s,
      ramMode_i      => ramMode_i, 
      ram_wp_en_o    => ram_wp_en_s,
      kbf_mode_i     => kbf_mode_s(2 downto 0),
      krx_mode_i     => krx_mode_s
      
   );
   
   rom_ioctl_we_s <= '1' when ioctl_wr = '1' and ioctl_download = '1'
      else '0';
     

--   sdram_addr <= 
--            "000000" & ioctl_addr(16 downto 0) when (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "00")           -- ROM upload 00000 - 17FFF
--       else "000000" & "1100" & ioctl_addr(12 downto 0) when (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "01")  -- ROM upload 18000 - 1FFFF
--       else "000000" & rom_mmu_s(4 downto 0) & a_i(11 downto 0) when rom_cs_s = '1'                           -- ROM access 
--       else "0000010"  & a_i(15 downto 0) when ram_cs_s  = '1'                                                -- Normal RAM 20000 - 2FFFF
--       else "00001" & mmu_q_s(17 downto 12) & a_i(11 downto 0) when ramD1_s = '1'                             -- Extra RAM  200000 - ?
--       else "00010" & ioctl_addr(17 downto 0) when (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "10")
--       else (others => '0');

   ramaddressprocess: process (clk_i) begin
       if rising_edge(clk_i) then
           if (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "00") then
             sdram_addr <= "000000" & ioctl_addr(16 downto 0);
           elsif (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "01") then
             sdram_addr <= "000000" & "1100" & ioctl_addr(12 downto 0);
           elsif rom_cs_s = '1' then
             sdram_addr <= "000000" & rom_mmu_s(4 downto 0) & a_i(11 downto 0);
           elsif ram_cs_s = '1' then
             sdram_addr <= "0000010"  & a_i(15 downto 0);
           elsif ramD1_s = '1' then
             sdram_addr <= "00001" & mmu_q_s(17 downto 12) & a_i(11 downto 0);
           elsif (rom_ioctl_we_s = '1' and ioctl_index(1 downto 0) = "10") then
             sdram_addr <= "00010" & ioctl_addr(17 downto 0);
           else
             sdram_addr <= sdram_addr;
           end if;
           if rd_n_i = '0' and mreq_n_i = '0' and rfsh_n_i = '1' then
             sdram_rd <= '1';
           else 
             sdram_rd <= '0';
           end if;
           if ioctl_wr = '1' or (wr_n_i = '0' and (ram_cs_s = '1' or ramD1_s = '1')) then
             sdram_we <= '1';
           else 
             sdram_we <= '0';
           end if;
           if rom_ioctl_we_s = '1' then
             sdram_din <= "00000000" & ioctl_dout;
           else 
             sdram_din <= "00000000" & d_i;
           end if;
       end if;
   end process;
--   sdram_rd <= '1' when rd_n_i = '0' and mreq_n_i = '0' and rfsh_n_i = '1' else '0';
--   sdram_we <= '1' when ioctl_wr = '1' or (wr_n_i = '0' and (ram_cs_s = '1' or ramD1_s = '1')) else '0';
--   sdram_din <= "00000000" & ioctl_dout when rom_ioctl_we_s = '1' else "00000000" & d_i;
   
   SDRAM_CLK <= clk_i;
   ramD1 : sdram
   port map (
      init => not pll_locked_i,
      clk => clk_i,
      SDRAM_DQ => SDRAM_DQ,
      SDRAM_A => SDRAM_A,
      SDRAM_DQML => SDRAM_DQML,
      SDRAM_DQMH => SDRAM_DQMH,
      SDRAM_nWE => SDRAM_nWE,
      SDRAM_nCAS => SDRAM_nCAS,
      SDRAM_nRAS => SDRAM_nRAS,
      SDRAM_nCS => SDRAM_nCS,
      SDRAM_BA => SDRAM_BA,
      SDRAM_CKE => SDRAM_CKE,
      wtbt => "00",
      addr => sdram_addr,
      din => sdram_din,
      dout => sdram_dout,
      we => sdram_we,
      rd => sdram_rd
   );
  

   process (clk_i)
      variable ram_addr_id : natural range 0 to 15;
   begin
      ram_addr_id := to_integer(unsigned(a_i(15 downto 12)));
      if (clk_i'event AND clk_i = '1') then
         if (mmu_wr_s = '1') then
            mmu_r_s(ram_addr_id) <= inv(d_i);
         end if; 
         mmu_q_s <= mmu_r_s(ram_addr_id);
      end if;
   end process;
   
end rtl;