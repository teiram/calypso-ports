------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- Copyright (c) 2009-2011 Tobias Gubener                                   --
-- Subdesign fAMpIGA by TobiFlex                                            --
--                                                                          --
-- This is the TOP-Level for TG68KdotC_Kernel to generate 68K Bus signals   --
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity TG68K is
  port(
    clk           : in      std_logic;
    reset         : in      std_logic;
    clkena_in     : in      std_logic:='1';
    IPL           : in      std_logic_vector(2 downto 0):="111";
    dtack         : in      std_logic;
    vpa           : in      std_logic:='1';
    ein           : in      std_logic:='1';
    addr          : buffer  std_logic_vector(31 downto 0);
    data_read     : in      std_logic_vector(15 downto 0);
    data_write    : buffer  std_logic_vector(15 downto 0);
    as            : out     std_logic;
    uds           : out     std_logic;
    lds           : out     std_logic;
    rw            : out     std_logic;
    vma           : buffer  std_logic:='1';
    wrd           : out     std_logic;
    ena7RDreg     : in      std_logic:='1';
    ena7WRreg     : in      std_logic:='1';
    fromram       : in      std_logic_vector(15 downto 0);
    ramready      : in      std_logic:='0';
    cpu           : in      std_logic_vector(1 downto 0);
    fastramcfg    : in      std_logic_vector(2 downto 0);
    eth_en        : in      std_logic:='0';
    sel_eth       : buffer  std_logic;
    frometh       : in      std_logic_vector(15 downto 0);
    ethready      : in      std_logic;
    turbochipram  : in      std_logic;
    turbokick     : in      std_logic;
    cache_inhibit : out     std_logic;
    ramaddr       : out     std_logic_vector(31 downto 0);
    cpustate      : out     std_logic_vector(1 downto 0);
    nResetOut     : buffer  std_logic;
    skipFetch     : buffer  std_logic;
    ramcs         : out     std_logic;
    ramlds        : out     std_logic;
    ramuds        : out     std_logic;
    CACR_out      : buffer  std_logic_vector(3 downto 0);
    VBR_out       : buffer  std_logic_vector(31 downto 0)
  );
end TG68K;


ARCHITECTURE logic OF TG68K IS

SIGNAL addrtg68         : std_logic_vector(31 downto 0);
SIGNAL cpuaddr          : std_logic_vector(31 downto 0);
SIGNAL r_data           : std_logic_vector(15 downto 0);
SIGNAL cpuIPL           : std_logic_vector(2 downto 0);
SIGNAL as_s             : std_logic;
SIGNAL as_e             : std_logic;
SIGNAL uds_s            : std_logic;
SIGNAL uds_e            : std_logic;
SIGNAL lds_s            : std_logic;
SIGNAL lds_e            : std_logic;
SIGNAL rw_s             : std_logic;
SIGNAL rw_e             : std_logic;
SIGNAL vpad             : std_logic;
SIGNAL waitm            : std_logic;
SIGNAL clkena_e         : std_logic;
SIGNAL S_state          : std_logic_vector(1 downto 0);
SIGNAL decode           : std_logic;
SIGNAL wr               : std_logic;
SIGNAL uds_in           : std_logic;
SIGNAL lds_in           : std_logic;
SIGNAL state            : std_logic_vector(1 downto 0);
SIGNAL clkena           : std_logic;
SIGNAL vmaena           : std_logic;
SIGNAL eind             : std_logic;
SIGNAL eindd            : std_logic;
SIGNAL sel_autoconfig   : std_logic;
SIGNAL autoconfig_out   : std_logic_vector(1 downto 0); -- We use this as a counter since we have two cards to configure
SIGNAL autoconfig_data  : std_logic_vector(3 downto 0); -- Zorro II RAM
SIGNAL autoconfig_data2 : std_logic_vector(3 downto 0); -- Zorro III RAM
SIGNAL autoconfig_data3 : std_logic_vector(3 downto 0); -- Zorro III ethernet
SIGNAL sel_ram          : std_logic;
SIGNAL sel_chipram      : std_logic;
SIGNAL turbochip_ena    : std_logic := '0';
SIGNAL turbochip_d      : std_logic := '0';
SIGNAL turbokick_d      : std_logic := '0';
SIGNAL slower           : std_logic_vector(3 downto 0);

TYPE   sync_states      IS (sync0, sync1, sync2, sync3, sync4, sync5, sync6, sync7, sync8, sync9);
SIGNAL sync_state       : sync_states;
SIGNAL datatg68         : std_logic_vector(15 downto 0);

SIGNAL z2ram_ena        : std_logic;
SIGNAL z3ram_base       : std_logic_vector(7 downto 0);
SIGNAL z3ram_ena        : std_logic;
SIGNAL eth_base         : std_logic_vector(7 downto 0);
SIGNAL eth_cfgd         : std_logic;
SIGNAL sel_z2ram        : std_logic;
SIGNAL sel_z3ram        : std_logic;
SIGNAL sel_kick         : std_logic;
SIGNAL sel_kickram      : std_logic;
SIGNAL sel_slow         : std_logic;
SIGNAL sel_slowram      : std_logic;
SIGNAL sel_cart         : std_logic;

SIGNAL NMI_addr         : std_logic_vector(31 downto 0);
SIGNAL sel_nmi_vector   : std_logic;


BEGIN

  -- NMI
  PROCESS(reset, clk) BEGIN
    IF reset='0' THEN
      NMI_addr <= X"0000007c";
    ELSE
      NMI_addr <= VBR_out + X"0000007c";
    END IF;
    IF rising_edge(clk) THEN
      sel_nmi_vector <= '0';
      IF (cpuaddr(31 downto 2) = NMI_addr(31 downto 2)) AND state="10" THEN
        sel_nmi_vector <= '1';
      END IF;
    END IF;
  END PROCESS;

  wrd <= wr;
  addr <= cpuaddr;
  datatg68 <= fromram                         WHEN sel_ram='1'
    ELSE autoconfig_data&r_data(11 downto 0)  WHEN sel_autoconfig='1' AND autoconfig_out="01" -- Zorro II RAM autoconfig
    ELSE autoconfig_data2&r_data(11 downto 0) WHEN sel_autoconfig='1' AND autoconfig_out="10" -- Zorro III RAM autoconfig
    ELSE r_data;

  sel_autoconfig  <= '1' WHEN fastramcfg(2 downto 0)/="000" AND cpuaddr(23 downto 19)="11101" AND autoconfig_out/="00" ELSE '0'; --$E80000 - $EFFFFF
  sel_z3ram       <= '1' WHEN (cpuaddr(31 downto 24)=z3ram_base) AND z3ram_ena='1' ELSE '0';
  sel_z2ram       <= '1' WHEN (cpuaddr(31 downto 24) = "00000000") AND ((cpuaddr(23 downto 21) = "001") OR (cpuaddr(23 downto 21) = "010") OR (cpuaddr(23 downto 21) = "011") OR (cpuaddr(23 downto 21) = "100")) AND z2ram_ena='1' ELSE '0';
  sel_chipram     <= '1' WHEN (cpuaddr(31 downto 24) = "00000000") AND (cpuaddr(23 downto 21)="000") AND turbochip_d='1' ELSE '0'; --$000000 - $1FFFFF
  sel_kick        <= '1' WHEN (cpuaddr(31 downto 24) = "00000000") AND ((cpuaddr(23 downto 19)="11111") OR (cpuaddr(23 downto 19)="11100")) AND state/="11" ELSE '0'; -- $F8xxxx, $E0xxxx
  sel_kickram     <= '1' WHEN sel_kick='1' AND turbokick_d='1' ELSE '0';
  sel_slow        <= '1' WHEN (cpuaddr(31 downto 24) = "00000000") AND ((cpuaddr(23 downto 20)="1100") OR (cpuaddr(23 downto 19)="11010")) ELSE '0'; -- $C00000 - $D7FFFF
  sel_slowram     <= '1' WHEN sel_slow='1' AND turbokick_d='1' ELSE '0';
  sel_cart        <= '1' WHEN (cpuaddr(31 downto 24) = "00000000") AND (cpuaddr(23 downto 20)="1010") ELSE '0'; -- $A00000 - $A7FFFF

  sel_ram         <= '1' WHEN state/="01" AND sel_nmi_vector='0' AND (
         sel_z2ram='1'
      OR sel_z3ram='1'
      OR sel_chipram='1'
      OR sel_slowram='1'
      OR sel_kickram='1'
    ) ELSE '0';

  cache_inhibit <= '1' WHEN sel_chipram='1' OR sel_kickram='1' ELSE '0';

  ramcs <= (NOT sel_ram) or slower(0);-- OR (state(0) AND NOT state(1));
  cpustate <= state;
  ramlds <= lds_in;
  ramuds <= uds_in;

  -- This is the mapping to the sram
  -- All non-fastram goes into the first 4M block.
  -- This map should be the same as in minimig_sram_bridge.v
  -- 4M Zorro II RAM $20-5F goes to $40-$7F
  ramaddr(31 downto 25) <= "0000000";
  ramaddr(24) <= sel_z3ram; -- Remap the Zorro III RAM to 0x1000000
  ramaddr(23 downto 19)     -- Remap the Zorro II RAM $200000-$5FFFFF to $400000-$7FFFFF
      <=   '0' & cpuaddr(22 downto 19) when sel_z2ram = '1'
      else "00" & "111" when sel_kick = '1'
      else "00" & "100" when sel_slow & cpuaddr(20 downto 19) = "100"
      else "00" & "101" when sel_slow & cpuaddr(20 downto 19) = "101"
      else "00" & "110" when sel_slow & cpuaddr(20 downto 19) = "110"
      else cpuaddr(23 downto 19);

  ramaddr(18 downto 0) <= cpuaddr(18 downto 0);

  -- 32bit address space for 68020, limit address space to 24bit for 68000/68010
  cpuaddr <= addrtg68 WHEN cpu(1) = '1' ELSE "00000000" & addrtg68(23 downto 0);

pf68K_Kernel_inst: work.TG68KdotC_Kernel
  generic map (
    SR_Read         => 2, -- 0=>user,   1=>privileged,    2=>switchable with CPU(0)
    VBR_Stackframe  => 2, -- 0=>no,     1=>yes/extended,  2=>switchable with CPU(0)
    extAddr_Mode    => 2, -- 0=>no,     1=>yes,           2=>switchable with CPU(1)
    MUL_Mode        => 2, -- 0=>16Bit,  1=>32Bit,         2=>switchable with CPU(1),  3=>no MUL,
    DIV_Mode        => 2, -- 0=>16Bit,  1=>32Bit,         2=>switchable with CPU(1),  3=>no DIV,
    BitField        => 2, -- 0=>no,     1=>yes,           2=>switchable with CPU(1)
    MUL_Hardware    => 1  -- 0=>no,     1=>yes
  )
  PORT MAP (
    clk             => clk,           -- : in std_logic;
    nReset          => reset,         -- : in std_logic:='1';      --low active
    clkena_in       => clkena,        -- : in std_logic:='1';
    data_in         => datatg68,      -- : in std_logic_vector(15 downto 0);
    IPL             => cpuIPL,        -- : in std_logic_vector(2 downto 0):="111";
    IPL_autovector  => '1',           -- : in std_logic:='0';
    CPU             => cpu,
    regin_out       => open,          -- : out std_logic_vector(31 downto 0);
    addr_out        => addrtg68,      -- : buffer std_logic_vector(31 downto 0);
    data_write      => data_write,    -- : out std_logic_vector(15 downto 0);
    busstate        => state,         -- : buffer std_logic_vector(1 downto 0);
    nWr             => wr,            -- : out std_logic;
    nUDS            => uds_in,
    nLDS            => lds_in,        -- : out std_logic;
    nResetOut       => nResetOut,
    skipFetch       => skipFetch,     -- : out std_logic
    CACR_out        => CACR_out,
    VBR_out         => VBR_out
  );


PROCESS (clk, turbochipram, turbokick) BEGIN
  IF rising_edge(clk) THEN
    IF (reset='0' OR nResetOut='0') THEN
      turbochip_d <= '0';
      turbokick_d <= '0';
    ELSIF state="01" THEN -- No mem access, so safe to switch chipram access mode
      turbochip_d <= turbochipram and turbochip_ena;
      turbokick_d <= turbokick and turbochip_ena;
    END IF;
  END IF;
END PROCESS;

PROCESS (clk, fastramcfg, cpuaddr, cpu) BEGIN
  -- Zorro II RAM (Up to 8 meg at 0x200000)
  autoconfig_data <= "1111";
  IF fastramcfg/="000" THEN
    CASE cpuaddr(6 downto 1) IS
      WHEN "000000" => autoconfig_data <= "1110";    -- Zorro-II card, add mem, no ROM
      WHEN "000001" => --autoconfig_data <= "0111";   -- 4MB
        CASE fastramcfg(1 downto 0) IS
          WHEN "01" => autoconfig_data <= "0110";    -- 2MB
          WHEN "10" => autoconfig_data <= "0111";    -- 4MB
          WHEN OTHERS => autoconfig_data <= "0000";  -- 8MB
        END CASE;
      WHEN "001000" => autoconfig_data <= "1110";    -- Manufacturer ID: 0x139c
      WHEN "001001" => autoconfig_data <= "1100";
      WHEN "001010" => autoconfig_data <= "0110";
      WHEN "001011" => autoconfig_data <= "0011";
      WHEN "010011" => autoconfig_data <= "1110";    --serial=1
      WHEN OTHERS => null;
    END CASE;
  END IF;

  -- Zorro III RAM (Up to 16 meg, address assigned by ROM)
  autoconfig_data2 <= "1111";
  IF fastramcfg(2)='1' AND cpu(1)='1' THEN -- Zorro III 32bit RAM, 68020
    CASE cpuaddr(6 downto 1) IS
      WHEN "000000" => autoconfig_data2 <= "1010";    -- Zorro-III card, add mem, no ROM
      WHEN "000001" => autoconfig_data2 <= "0000";    -- 8MB (extended to 16 in reg 08)
      WHEN "000010" => autoconfig_data2 <= "1110";    -- ProductID=0x10 (only setting upper nibble)
      WHEN "000100" => autoconfig_data2 <= "0000";    -- Memory card, not silenceable, Extended size (16 meg), reserved.
      WHEN "000101" => autoconfig_data2 <= "1111";    -- 0000 - logical size matches physical size TODO change this to 0001, so it is autosized by the OS, WHEN it will be 24MB.
      WHEN "001000" => autoconfig_data2 <= "1110";    -- Manufacturer ID: 0x139c
      WHEN "001001" => autoconfig_data2 <= "1100";
      WHEN "001010" => autoconfig_data2 <= "0110";
      WHEN "001011" => autoconfig_data2 <= "0011";
      WHEN "010011" => autoconfig_data2 <= "1101";    -- serial=2
      WHEN OTHERS => null;
    END CASE;
  END IF;

  -- Zorro III ethernet
  autoconfig_data3 <= "1111";
  IF eth_en='1' THEN
    CASE cpuaddr(6 downto 1) IS
      WHEN "000000" => autoconfig_data3 <= "1000";    -- 00H: Zorro-III card, no link, no ROM
      WHEN "000001" => autoconfig_data3 <= "0001";    -- 00L: next board not related, size 64K
      WHEN "000010" => autoconfig_data3 <= "1101";    -- 04H: ProductID=0x20 (only setting upper nibble)
      WHEN "000100" => autoconfig_data3 <= "1110";    -- 08H: Not memory, silenceable, normal size, Zorro III
      WHEN "000101" => autoconfig_data3 <= "1101";    -- 08L: Logical size 64K
      WHEN "001000" => autoconfig_data3 <= "1110";    -- Manufacturer ID: 0x139c
      WHEN "001001" => autoconfig_data3 <= "1100";
      WHEN "001010" => autoconfig_data3 <= "0110";
      WHEN "001011" => autoconfig_data3 <= "0011";
      WHEN "010011" => autoconfig_data3 <= "1100";    -- serial=2
      WHEN OTHERS => null;
    END CASE;
  END IF;

  IF rising_edge(clk) THEN
    IF (reset='0' OR nResetOut='0') THEN
      autoconfig_out <= "01";    --autoconfig on
      turbochip_ena <= '0';  -- disable turbo_chipram until we know kickstart's running...
      z2ram_ena <='0';
      z3ram_ena <='0';
      z3ram_base<=X"01";
    ELSIF clkena_in='1' THEN
      IF sel_autoconfig='1' AND state="11"AND uds_in='0' AND clkena='1' THEN
        CASE cpuaddr(6 downto 1) IS
          WHEN "100100" => -- Register 0x48 - config
            IF autoconfig_out="01" THEN
              z2ram_ena <= '1';
              autoconfig_out<=fastramcfg(2)&'0';
            END IF;
            turbochip_ena <= '1';  -- enable turbo_chipram after autoconfig has been done...
                            -- FIXME - this is a hack to allow ROM overlay to work.
          WHEN "100010" => -- Register 0x44, assign base address to ZIII RAM.
                      -- We ought to take 16 bits here, but for now we take liberties and use a single byte.
            IF autoconfig_out="10" THEN
              z3ram_base<=data_write(15 downto 8);
              z3ram_ena <='1';
              autoconfig_out <= "00";
            END IF;

          WHEN others =>
            null;
        END CASE;
      END IF;
    END IF;
  END IF;
END PROCESS;

PROCESS (clk) BEGIN
  IF rising_edge(clk) THEN
    IF ena7WRreg='1' THEN
      eind <= ein;
      eindd <= eind;
      CASE sync_state IS
        WHEN sync0  => sync_state <= sync1;
        WHEN sync1  => sync_state <= sync2;
        WHEN sync2  => sync_state <= sync3;
        WHEN sync3  => sync_state <= sync4;
                 vma <= vpa;
        WHEN sync4  => sync_state <= sync5;
        WHEN sync5  => sync_state <= sync6;
        WHEN sync6  => sync_state <= sync7;
        WHEN sync7  => sync_state <= sync8;
        WHEN sync8  => sync_state <= sync9;
        WHEN OTHERS => sync_state <= sync0;
                 vma <= '1';
      END CASE;
      IF eind='1' AND eindd='0' THEN
        sync_state <= sync7;
      END IF;
    END IF;
  END IF;
END PROCESS;

clkena <= '1' WHEN (clkena_in='1' AND (state="01" OR (ena7RDreg='1' AND clkena_e='1') OR ramready='1')) ELSE '0';

PROCESS (clk) BEGIN
  IF rising_edge(clk) THEN
    IF clkena='1' THEN
      slower <= "0111"; -- rokk
    ELSE
      slower(3 downto 0) <= '0'&slower(3 downto 1); -- enaWRreg&slower(3 downto 1);
    END IF;
  END IF;
END PROCESS;


PROCESS (clk, reset, state, as_s, as_e, rw_s, rw_e, uds_s, uds_e, lds_s, lds_e, sel_ram)
  BEGIN
    IF state="01" THEN
      as <= '1';
      rw <= '1';
      uds <= '1';
      lds <= '1';
    ELSE
      as <= (as_s AND as_e) OR sel_ram;
      rw <= rw_s AND rw_e;
      uds <= uds_s AND uds_e;
      lds <= lds_s AND lds_e;
    END IF;
    IF reset='0' THEN
      S_state <= "00";
      as_s <= '1';
      rw_s <= '1';
      uds_s <= '1';
      lds_s <= '1';
    ELSIF rising_edge(clk) THEN
      IF ena7WRreg='1' THEN
        as_s <= '1';
        rw_s <= '1';
        uds_s <= '1';
        lds_s <= '1';
          CASE S_state IS
            WHEN "00" => IF state/="01" AND sel_ram='0' THEN
                     uds_s <= uds_in;
                     lds_s <= lds_in;
                    S_state <= "01";
                   END IF;
            WHEN "01" => as_s <= '0';
                   rw_s <= wr;
                   uds_s <= uds_in;
                   lds_s <= lds_in;
                   S_state <= "10";
            WHEN "10" =>
                   r_data <= data_read;
                   IF waitm='0' OR (vma='0' AND sync_state=sync9) THEN
                    S_state <= "11";
                   ELSE
                     as_s <= '0';
                     rw_s <= wr;
                     uds_s <= uds_in;
                     lds_s <= lds_in;
                   END IF;
            WHEN "11" =>
                   S_state <= "00";
            WHEN OTHERS => null;
          END CASE;
      END IF;
    END IF;
    IF reset='0' THEN
      as_e <= '1';
      rw_e <= '1';
      uds_e <= '1';
      lds_e <= '1';
      clkena_e <= '0';
    ELSIF rising_edge(clk) THEN
      IF ena7RDreg='1' THEN
        as_e <= '1';
        rw_e <= '1';
        uds_e <= '1';
        lds_e <= '1';
        clkena_e <= '0';
        CASE S_state IS
          WHEN "00" =>
                 cpuIPL <= IPL;
                 IF sel_ram='0' THEN
                   IF state/="01" THEN
                    as_e <= '0';
                   END IF;
                   rw_e <= wr;
                   IF wr='1' THEN
                     uds_e <= uds_in;
                     lds_e <= lds_in;
                   END IF;
                 END IF;
          WHEN "01" =>
                  as_e <= '0';
                   rw_e <= wr;
                   uds_e <= uds_in;
                   lds_e <= lds_in;
          WHEN "10" => rw_e <= wr;
                 cpuIPL <= IPL;
                 waitm <= dtack;
          WHEN OTHERS => --null;
                   clkena_e <= '1';
        END CASE;
      END IF;
    END IF;
END PROCESS;

END;
