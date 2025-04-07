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
   -- hps_io --------------------------------------------------------
   ioctl_addr             : in std_logic_vector( 24 downto 0);
   ioctl_dout             : in std_logic_vector( 7 downto 0);
   ioctl_index            : in std_logic_vector( 7 downto 0);
   ioctl_wr               : in std_logic;
   ioctl_download         : in std_logic;

   --SRAM
   SRAM_A			:	 OUT STD_LOGIC_VECTOR(20 DOWNTO 0);
   SRAM_Q			:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
   SRAM_WE			:	 OUT STD_LOGIC

  );

end sordM5_rams;


architecture rtl of sordM5_rams is
   type MMU_RAM_t is array(0 to 15) of std_logic_vector(7 downto 0);
   signal mmu_q_s         : std_logic_vector(19 downto 12);
   signal mmu_wr_s        : std_logic;
   signal rom_mmu_s       : std_logic_vector(4 downto 0);
   signal ramD1_q_s       : std_logic_vector(7 downto 0);
   signal ramD1_we_s      : std_logic;
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
   
   FUNCTION inv(s1:std_logic_vector) return std_logic_vector is 
     VARIABLE Z : std_logic_vector(s1'high downto s1'low);
     BEGIN
     FOR i IN (s1'low) to s1'high LOOP
         Z(i) := NOT(s1(i));
     END LOOP;
     RETURN Z;
   END inv; 

   component spram_sram
        port (
        clka : in std_logic;
        ena : in std_logic;
        wea : in std_logic;
        addra : in std_logic_vector (17 downto 0);
        dina : in std_logic_vector (7 downto 0);
        douta : out std_logic_vector (7 downto 0);
        SRAM_ADDR : out std_logic_vector (20 downto 0);
        SRAM_DATA : inout std_logic_vector (15 downto 0);
        SRAM_WE_n : out std_logic
      );
    end component;
    
   
begin

   mmu_wr_s       <= '1' when iorq_n_i = '0' and m1_n_i = '1' and a_i(7 downto 2) = "011001" AND wr_n_i = '0' else '0'; -- mmu 0x64 - 0x67    
   d_o            <= ram_q_s  when ram_cs_s  = '1' else
                     rom_q_s  when rom_cs_s   = '1' else
                     ramD1_q_s when mmu_q_s(19 downto 18) = "00" and ramD_cs_s  = '1' else
                     (others => '1');
   
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

   ramD1_we_s <= '1' when ramD_cs_s = '1' and mmu_q_s(19 downto 18) = "00" and wr_n_i ='0' else '0';

   -- Original on BRAM

   -- ramD1 : work.spram
   -- generic map (
   --    addr_width => 18 --18
   -- )
   -- port map (
   --    clock => clk_i,
   --    address => mmu_q_s(17 downto 12)&a_i(11 downto 0),
   --    wren => ramD1_we_s,
   --    data => d_i,
   --    q => ramD1_q_s
   -- );   

   
   -- SRAM version

   ramD1 : spram_sram
   -- generic map (
   --    AW => 18 
   -- )
   port map (
      clka => clk_i,
      ena => '1',
      addra => mmu_q_s(17 downto 12)&a_i(11 downto 0),
      wea => ramD1_we_s,
      dina => d_i,
      douta => ramD1_q_s,

      SRAM_ADDR		=> SRAM_A,
      SRAM_DATA		=> SRAM_Q,
      SRAM_WE_n		=> SRAM_WE
   );   



   
   rom_ioctl_we_s <= '1' when ioctl_index = "00000001" 
                          AND ioctl_wr = '1' 
                          AND ioctl_download = '1' 
                          AND ioctl_addr(24 downto 13) = "000000000000"    -- Memory limit
                         else '0';   
   RAM : work.dpram
   generic map (
      addr_width => 16
   )
   port map (
      clock => clk_i,
      address_a => a_i(15 downto 0),
      wren_a => ram_cs_s and not wr_n_i and not ram_wp_en_s,
      data_a => d_i,
      q_a => ram_q_s,
      wren_b => '0'
   );   
   
   ROM : work.dpram
   generic map (
      addr_width => 17,
      mem_init_file => "rom/rom.MIF"
   )
   
   port map (   
      clock => clk_i,
      address_a => rom_mmu_s(4 downto 0)&a_i(11 downto 0),
      q_a => rom_q_s,
      address_b => "1100"&ioctl_addr(12 downto 0),
      data_b => ioctl_dout,
      wren_b => rom_ioctl_we_s 
   );   
 
   process (clk_i)
      variable ram_addr_id : natural range 0 to 15;
   begin
      ram_addr_id := to_integer(unsigned(a_i(15 downto 12)));
      if (clk_i'event AND clk_i = '1') then
         if (mmu_wr_s = '1') then
            mmu_r_s(ram_addr_id) <= inv(d_i);
         end if; 
         mmu_q_s <=mmu_r_s(ram_addr_id);
      end if;
   end process;
   
end rtl;