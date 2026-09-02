---------------------------------------------------------------------------------
-- Games consoles with Signetics 2650 CPU and 2637 VIDEO

-- Emerson Arcadia 2001 & clones

---------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

USE std.textio.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY arcadia_core IS
  PORT (
    -- Master input clock
    clk              : IN    std_logic;
    
    -- OSD Status needed for pause on OSD
    OSD_STATUS : IN std_logic;
    pause_osd  : IN std_logic;

    -- Async reset from top-level module. Can be used as initial reset.
    reset            : IN    std_logic;

    -- Must be passed to hps_io module
    ntsc_pal         : IN    std_logic;
    swapxy           : IN    std_logic;
    swap_controllers : IN    std_logic;
    
    -- Base video clock. Usually equals to CLK_SYS.
    clk_video        : OUT   std_logic;

    -- Multiple resolutions are supported using different CE_PIXEL rates.
    -- Must be based on CLK_VIDEO
    ce_pixel         : OUT   std_logic;

    -- VGA
    vga_r            : OUT   std_logic_vector(7 DOWNTO 0);
    vga_g            : OUT   std_logic_vector(7 DOWNTO 0);
    vga_b            : OUT   std_logic_vector(7 DOWNTO 0);
    vga_hs           : OUT   std_logic; -- positive pulse!
    vga_vs           : OUT   std_logic; -- positive pulse!
    vga_de           : OUT   std_logic; -- = not (VBlank or HBlank)

    -- AUDIO
    sound            : OUT   std_logic_vector(7 DOWNTO 0);
    
    ps2_key           : IN  std_logic_vector(10 DOWNTO 0);    
    joystick_0        : IN  std_logic_vector(31 DOWNTO 0);
    joystick_1        : IN  std_logic_vector(31 DOWNTO 0);
    joystick_analog_0 : IN  std_logic_vector(15 DOWNTO 0);
    joystick_analog_1 : IN  std_logic_vector(15 DOWNTO 0);
    dpad_analog_en    : IN  std_logic;
    
    ioctl_download    : IN  std_logic;
    ioctl_index       : IN  std_logic_vector(7 DOWNTO 0);
    ioctl_wr          : IN  std_logic;
    ioctl_addr        : IN  std_logic_vector(24 DOWNTO 0);
    ioctl_dout        : IN  std_logic_vector(7 DOWNTO 0);
    ioctl_wait        : OUT std_logic;

    vga_hblank       : OUT   std_logic;
    vga_vblank       : OUT   std_logic
    );
END arcadia_core;

ARCHITECTURE struct OF arcadia_core IS

  CONSTANT CDIV : natural := 4 * 8;
  
  --------------------------------------
  SIGNAL keypad1_1, keypad1_2, keypad1_3 : unsigned(7 DOWNTO 0);
  SIGNAL keypad2_1, keypad2_2, keypad2_3 : unsigned(7 DOWNTO 0);
  SIGNAL p1_joy, p2_joy : std_logic_vector(31 DOWNTO 0);
  SIGNAL keypanel, keypanel_raw, volnoise : unsigned(7 DOWNTO 0);
  SIGNAL vrst_key_d : std_logic;
  
  --------------------------------------
  SIGNAL vol : unsigned(1 DOWNTO 0);
  SIGNAL icol,explo,explo2,noise,snd : std_logic;
  SIGNAL sound1 : unsigned(7 DOWNTO 0);
  SIGNAL lfsr : uv15;
  SIGNAL nexplo : natural RANGE 0 TO 1000000;
  SIGNAL divlfsr : uint8;
  
  SIGNAL pot1,pot2 : unsigned(7 DOWNTO 0);
  SIGNAL potl_a,potl_b,potr_a,potr_b : unsigned(7 DOWNTO 0);
  SIGNAL potl_v,potl_h,potr_v,potr_h : unsigned(7 DOWNTO 0);
  SIGNAL pot0_a,pot0_b,pot1_a,pot1_b : unsigned(7 DOWNTO 0);
  SIGNAL dpad0,dpad1 : std_logic;
  SIGNAL tick_cpu_cpt : natural RANGE 0 TO CDIV-1;
  SIGNAL tick_cpu : std_logic;
  
  SIGNAL ad,ad_delay,ad_rom : unsigned(14 DOWNTO 0);
  SIGNAL ad_uvi_delay : unsigned(9 DOWNTO 0);
  SIGNAL dr,dw,dr_uvi,dr_rom,dr_key : unsigned(7 DOWNTO 0);
  SIGNAL req,req_uvi,req_mem : std_logic;
  SIGNAL ack,ackp,ack_uvi,ack_mem : std_logic;
  SIGNAL sel_uvi,sel_mem : std_logic;
  SIGNAL ack_mem_p,ack_mem_p2 : std_logic :='0';
  -- Deterministic normal-memory handshake.
  -- 0=idle, 1=request observed/data settling, 2=ACK issued/wait for REQ low.
  SIGNAL mem_ack_state : unsigned(1 DOWNTO 0) := "00";
  SIGNAL ack_mem_i : std_logic := '0';
  SIGNAL int,intack,creset : std_logic;
  SIGNAL sense,flag : std_logic;
  SIGNAL mio,ene,dc,wr : std_logic;
  SIGNAL ph : unsigned(1 DOWNTO 0);
  SIGNAL ivec : unsigned(7 DOWNTO 0);
  
  SIGNAL reset_na : std_logic;
  SIGNAL w_d : unsigned(7 DOWNTO 0);
  SIGNAL w_a : unsigned(12 DOWNTO 0);
  SIGNAL w_wr : std_logic;
  TYPE arr_cart IS ARRAY(natural RANGE <>) OF unsigned(7 DOWNTO 0);
  --SIGNAL cart : arr_cart(0 TO 4095);
  --ATTRIBUTE ramstyle : string;
  --ATTRIBUTE ramstyle OF cart : SIGNAL IS "no_rw_check";
  
  SHARED VARIABLE cart : arr_cart(0 TO 16383) :=(OTHERS =>x"00");
  ATTRIBUTE ramstyle : string;
  ATTRIBUTE ramstyle OF cart : VARIABLE IS "no_rw_check";
  
  SIGNAL wcart : std_logic;
  
  SIGNAL vga_argb : unsigned(3 DOWNTO 0);
  SIGNAL vga_dei  : std_logic;
  SIGNAL vga_hsyn : std_logic;
  SIGNAL vga_vsyn : std_logic;
  SIGNAL vga_ce   : std_logic;
  
  SIGNAL vrst : std_logic;
  
  SIGNAL vga_r_i,vga_g_i,vga_b_i : uv8;
  
  -- Auto X/Y swap signals
  SIGNAL crc32_reg          : unsigned(31 DOWNTO 0);
  SIGNAL crc32_final        : unsigned(31 DOWNTO 0);
  SIGNAL ioctl_download_d   : std_logic;
  SIGNAL dl_start, dl_done  : std_logic;
  SIGNAL auto_swapxy        : std_logic := '0';
  SIGNAL golf_cart          : std_logic := '0';
  SIGNAL swapxy_eff         : std_logic;
  SIGNAL ctrl_swap          : std_logic := '0';
  SIGNAL swap_ctrl_eff      : std_logic;

  FILE fil : text OPEN write_mode IS "trace_mem.log";

  -- Convert MiSTer signed analog (-128..+127) to the Arcadia paddle range.
  -- Real machines typically centre near $66-$70, not $80.  Clamp at $00/$FE.
  FUNCTION paddle_value(a : std_logic_vector(7 DOWNTO 0)) RETURN unsigned IS
    VARIABLE v : integer;
  BEGIN
    v := 16#70# + to_integer(signed(a));
    IF v < 0 THEN v := 0; END IF;
    IF v > 254 THEN v := 254; END IF;
    RETURN to_unsigned(v, 8);
  END FUNCTION;
  
  -- Bit-serial reflected CRC-32 (poly 0xEDB88320)
  FUNCTION crc32_update(crc_in : unsigned(31 DOWNTO 0); data : unsigned(7 DOWNTO 0))
    RETURN unsigned IS
    VARIABLE crc : unsigned(31 DOWNTO 0);
  BEGIN
    crc := crc_in XOR (x"000000" & data);
    FOR i IN 0 TO 7 LOOP
      IF crc(0) = '1' THEN
        crc := ('0' & crc(31 DOWNTO 1)) XOR x"EDB88320";
      ELSE
        crc := '0' & crc(31 DOWNTO 1);
      END IF;
    END LOOP;
    RETURN crc;
  END FUNCTION;

BEGIN
  
  ----------------------------------------------------------
  -- Emerson Arcadia & clones
  --  x00 aaaa aaaa aaaa : Cardtrige 4kb
  --  x01 1000 aaaa aaaa : Video UVI RAM  : 1800
  --  x01 1001 0xxx aaaa : Key inputs     : 1900
  --  x01 1001 1xxx xxxx : Video UVI regs : 1980
  --  x01 1010 aaaa aaaa : Video UVI RAM  : 1A00
  --  x10 aaaa aaaa aaaa : Cardridge high : 2000
  
  i_sgs2637: ENTITY work.sgs2637
    PORT MAP (
      ad        => ad,
      dw        => dw,
      dr        => dr_uvi,
      req       => req_uvi,
      ack       => ack_uvi,
      wr        => wr,
      tick      => tick_cpu,
      vid_argb  => vga_argb,
      vid_de    => vga_de,
      vid_hblank => vga_hblank,
      vid_vblank => vga_vblank,
      vid_hsyn  => vga_hsyn,
      vid_vsyn  => vga_vsyn,
      vid_ce    => vga_ce,
      vrst      => vrst,
      sound     => sound1,
      pot1      => potr_v,
      pot2      => potl_v,
      pot3      => potr_h,
      pot4      => potl_h,
      np        => ntsc_pal,
      reset     => reset,
      clk       => clk,
      reset_na  => reset_na);
  
  --   1 2 3
  --   4 5 6
  --   7 8 9
  -- ENT 0 CLR
  -- start,a,b,enter,clr,0,1,2,3,4,5,6,7,8,9
    
  p1_joy <= joystick_1 WHEN swap_ctrl_eff='1' ELSE joystick_0;
  p2_joy <= joystick_0 WHEN swap_ctrl_eff='1' ELSE joystick_1;

  keypad1_1<="0000" & p1_joy(10) & p1_joy(13) & p1_joy(16) & p1_joy(8) ; -- 1900 : 1 4 7 CLEAR
  keypad1_2<="0000" & (p1_joy(11) OR p1_joy(19) OR p1_joy(20)) & p1_joy(14) & p1_joy(17) & p1_joy(9) ; -- 1901 : 2 5 8 0 (fire buttons parallel "2" per PCB schematic)
  keypad1_3<="0000" & p1_joy(12) & p1_joy(15) & p1_joy(18) & p1_joy(7) ; -- 1902 : 3 6 9 ENTER
  
  keypad2_1<="0000" & p2_joy(10) & p2_joy(13) & p2_joy(16) & p2_joy(8) ; -- 1904 : 1 4 7 CLEAR
  keypad2_2<="0000" & (p2_joy(11) OR p2_joy(19) OR p2_joy(20)) & p2_joy(14) & p2_joy(17) & p2_joy(9) ; -- 1905 : 2 5 8 0 (fire buttons parallel "2" per PCB schematic)
  keypad2_3<="0000" & p2_joy(12) & p2_joy(15) & p2_joy(18) & p2_joy(7) ; -- 1906 : 3 6 9 ENTER
  
  -- $1908 panel register: bit 0 START, bit 1 OPTION, bit 2 SELECT/DIFFICULTY.
  -- The previous mapping swapped SELECT and OPTION.  Panel keys are
  -- frame-latched on the original hardware, so retain a press until the
  -- next frame rather than exposing only the instantaneous MiSTer state.
  keypanel_raw <= "00000" &
                  ((p1_joy(5) OR p2_joy(5)) &  -- bit 2: SELECT / Difficulty
                   (p1_joy(6) OR p2_joy(6)) &  -- bit 1: OPTION
                   (p1_joy(4) OR p2_joy(4)));  -- bit 0: START

  PROCESS(clk,reset_na) IS
  BEGIN
    IF reset_na='0' THEN
      keypanel <= (OTHERS => '0');
      vrst_key_d <= '0';
    ELSIF rising_edge(clk) THEN
      vrst_key_d <= vrst;
      IF vrst_key_d='1' AND vrst='0' THEN
        keypanel <= keypanel_raw;
      ELSE
        keypanel <= keypanel OR keypanel_raw;
      END IF;
    END IF;
  END PROCESS;
  
  dr_key<=keypad1_1 WHEN ad_delay(3 DOWNTO 0)=x"0" ELSE -- 1900
          keypad1_2 WHEN ad_delay(3 DOWNTO 0)=x"1" ELSE -- 1901
          keypad1_3 WHEN ad_delay(3 DOWNTO 0)=x"2" ELSE -- 1902
          keypad2_1 WHEN ad_delay(3 DOWNTO 0)=x"4" ELSE -- 1904
          keypad2_2 WHEN ad_delay(3 DOWNTO 0)=x"5" ELSE -- 1905
          keypad2_3 WHEN ad_delay(3 DOWNTO 0)=x"6" ELSE -- 1906
          keypanel  WHEN ad_delay(3 DOWNTO 0)=x"8" ELSE -- 1908
          x"00";
  
  


  -- flag : Joystick : 0=Horizontal 1=Vertical
  pot2<=potr_v WHEN flag='1' ELSE potr_h;
  pot1<=potl_v WHEN flag='1' ELSE potl_h;

  sound <= std_logic_vector(sound1) WHEN (OSD_STATUS='0' OR pause_osd='0') ELSE (OTHERS => '0');
  
  ----------------------------------------------------------
  sense <=vrst;
  
  Joysticks:PROCESS (clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      -------------------------------------------------------------------------------
      IF dpad0='0' THEN
        pot0_a<=paddle_value(joystick_analog_0(15 DOWNTO 8));
        pot0_b<=paddle_value(joystick_analog_0( 7 DOWNTO 0));
      ELSE
        pot0_a<=x"70";
        pot0_b<=x"70";
        IF joystick_0(0)='1' THEN pot0_b<=x"00"; END IF; -- up
        IF joystick_0(1)='1' THEN pot0_b<=x"FE"; END IF; -- down
        IF joystick_0(2)='1' THEN pot0_a<=x"00"; END IF; -- left
        IF joystick_0(3)='1' THEN pot0_a<=x"FE"; END IF; -- right
      END IF;
      
      IF dpad_analog_en='0' THEN
        IF joystick_0(3 DOWNTO 0)/="0000" THEN
          dpad0<='1';
        END IF;
        IF joystick_analog_0(7 DOWNTO 5)="100" OR joystick_analog_0(7 DOWNTO 5)="011" OR
           joystick_analog_0(15 DOWNTO 13)="100" OR joystick_analog_0(15 DOWNTO 13)="011" THEN
          dpad0<='0';
        END IF;
      ELSE
        dpad0<='0';
      END IF;
      
      -------------------------------------------------------------------------------
      IF dpad1='0' THEN
        pot1_a<=paddle_value(joystick_analog_1(15 DOWNTO 8));
        pot1_b<=paddle_value(joystick_analog_1( 7 DOWNTO 0));
      ELSE
        pot1_a<=x"70";
        pot1_b<=x"70";
        IF joystick_1(0)='1' THEN pot1_b<=x"00"; END IF; -- up
        IF joystick_1(1)='1' THEN pot1_b<=x"FE"; END IF; -- down
        IF joystick_1(2)='1' THEN pot1_a<=x"00"; END IF; -- left
        IF joystick_1(3)='1' THEN pot1_a<=x"FE"; END IF; -- right
      END IF;
      
      IF dpad_analog_en='0' THEN
        IF joystick_1(3 DOWNTO 0)/="0000" THEN
          dpad1<='1';
        END IF;
        IF joystick_analog_1(7 DOWNTO 5)="100" OR joystick_analog_1(7 DOWNTO 5)="011" OR
           joystick_analog_1(15 DOWNTO 13)="100" OR joystick_analog_1(15 DOWNTO 13)="011" THEN
          dpad1<='0';
        END IF;
      ELSE
        dpad1<='0';
      END IF;

      -------------------------------------------------------------------------------
      potl_a<=mux(swap_ctrl_eff, pot0_a, pot1_a);
      potl_b<=mux(swap_ctrl_eff, pot0_b, pot1_b);
      potr_a<=mux(swap_ctrl_eff, pot1_a, pot0_a);
      potr_b<=mux(swap_ctrl_eff, pot1_b, pot0_b);
      -------------------------------------------------------------------------------
      IF reset_na='0' THEN
        dpad0<='0';
        dpad1<='0';
      END IF;
      
    END IF;
  END PROCESS Joysticks;

  dl_start <= ioctl_download AND NOT ioctl_download_d;
  dl_done  <= NOT ioctl_download AND ioctl_download_d;

  ComputeCRC32:PROCESS(clk) IS
    VARIABLE crc_final : unsigned(31 DOWNTO 0);
  BEGIN
    IF rising_edge(clk) THEN
      ioctl_download_d <= ioctl_download;

      IF dl_start = '1' THEN
        crc32_reg <= x"FFFFFFFF";
      ELSIF ioctl_download = '1' AND ioctl_wr = '1' THEN
        crc32_reg <= crc32_update(crc32_reg, unsigned(ioctl_dout));
      END IF;

      IF dl_done = '1' THEN
        crc_final := crc32_reg XOR x"FFFFFFFF";
        crc32_final <= crc_final;

      END IF;
    END IF;
  END PROCESS ComputeCRC32;


  auto_swapxy <= '1' WHEN
       crc32_final = x"4DA68DF8"  -- 3D Soccer (Emerson)
    OR crc32_final = x"1B5BE22A"  -- 3D Soccer (Tele-Fever)
    OR crc32_final = x"77C19320"  -- Funky Fish
    OR crc32_final = x"97060A54"  -- Jump Bug (Emerson)
    OR crc32_final = x"DC0264B8"  -- Jump Bug (Tele-Fever)
    OR crc32_final = x"BB88DAEA"  -- Spiders
    OR crc32_final = x"F9D9EC5B"  -- Spiders (overdump)
    OR crc32_final = x"E66F362D"  -- The End
    OR crc32_final = x"566C78A0"  -- The End (enhanced)
    OR crc32_final = x"306E39C1"  -- Turtles/Turpin
    ELSE '0';

  ctrl_swap <= '1' WHEN
       crc32_final = x"4DA68DF8"  -- 3D Soccer (Emerson)
    OR crc32_final = x"1B5BE22A"  -- 3D Soccer (Tele-Fever)
    OR crc32_final = x"76E773FA"  -- Crazy Climber
    OR crc32_final = x"E84DF2EF"  -- Crazy Gobbler
    OR crc32_final = x"77C19320"  -- Funky Fish
    OR crc32_final = x"1CEC4B21"  -- Hobo
    OR crc32_final = x"97060A54"  -- Jump Bug (Emerson)
    OR crc32_final = x"DC0264B8"  -- Jump Bug (Tele-Fever)
    OR crc32_final = x"A0626E23"  -- R2D Tank
    OR crc32_final = x"A06F284B"  -- Red Clash
    OR crc32_final = x"E3794A2C"  -- Space Attack (Emerson)
    OR crc32_final = x"669632EC"  -- Space Attack (Schmid)
    OR crc32_final = x"C91828CB"  -- Space War (prototype)
    OR crc32_final = x"BB88DAEA"  -- Spiders
    OR crc32_final = x"E66F362D"  -- The End
    OR crc32_final = x"306E39C1"  -- Turtles/Turpin
    OR crc32_final = x"566C78A0"  -- The End (enhanced)
    OR crc32_final = x"617EEB43"  -- Hobo (enhanced)
    OR crc32_final = x"06A86F4A"  -- Red Clash (overdump)
    OR crc32_final = x"F9D9EC5B"  -- Spiders (overdump)
    ELSE '0';

  -- Manual O4 toggle now acts as an override on top of auto-detection,
  -- for homebrews/unknown dumps not in the table above.
  swapxy_eff <= swapxy XOR auto_swapxy;
  swap_ctrl_eff <= swap_controllers XOR ctrl_swap;

  -- Golf is the one known commercial cartridge with the Palladium/VCG
  -- 6 KiB layout: 4 KiB at $0000 plus 2 KiB at $4000.
  golf_cart <= '1' WHEN crc32_final = x"A23C7A01" ELSE '0';

  potl_h<=mux(swapxy_eff,potl_a,potl_b);
  potl_v<=mux(swapxy_eff,potl_b,potl_a);
  potr_h<=mux(swapxy_eff,potr_a,potr_b);
  potr_v<=mux(swapxy_eff,potr_b,potr_a);

  ----------------------------------------------------------
  -- The 1 KiB UVI window at $1800-$1BFF is mirrored throughout every
  -- odd 4 KiB CPU page ($1000-$1FFF, $3000-$3FFF, ...).  $1B00-$1BFF
  -- mirrors the keyboard/UVI register page at $1900-$19FF.
  ad_uvi_delay <= ('0' & ad_delay(8 DOWNTO 0)) WHEN ad_delay(9 DOWNTO 8)="11" ELSE
                  ad_delay(9 DOWNTO 0);

  dr <= dr_key WHEN ad_delay(12)='1' AND ad_uvi_delay(9 DOWNTO 7)="010" ELSE -- $100-$17F: key matrix
        dr_uvi WHEN ad_delay(12)='1' ELSE
        dr_rom;
  
  -- A12 selects the complete Arcadia UVI mirror family.  This also covers
  -- the documented $1000/$1400/$1C00 and $3000/$5000/$7000 aliases.
  -- Experimental direct CPU address decode.
  -- Horse Racing exposed a stall at $0C03 with REQ='1'/A12='0' while
  -- the chained memory-select path remained inactive.
  sel_uvi <= ad(12);
  sel_mem <= NOT ad(12);

  req_uvi <= ad(12) AND req;
  req_mem <= (NOT ad(12)) AND req;

  -- Deterministic normal-memory ACK handshake.
  --
  -- Horse Racing proves that the old ack_mem_p/ack_mem_p2 feedback pulse
  -- shaper can leave REQ asserted forever without producing ACK.  Immediate
  -- ACK removes that deadlock but is too early for the synchronous cartridge
  -- ROM.  Instead:
  --   state 0: wait for a normal-memory REQ
  --   state 1: hold for one CPU tick (many clk cycles; ROM settles)
  --   state 2: assert ACK on one CPU tick, then remain armed-off until REQ drops
  --
  -- This guarantees exactly one ACK per request and gives synchronous ROM
  -- substantially more than its required one clk cycle before the CPU samples DR.
  ackp <= tick_cpu AND ack_uvi WHEN ad(12)='1' ELSE
          tick_cpu WHEN mem_ack_state="10" ELSE '0';

  PROCESS (clk, reset_na) IS
  BEGIN
    IF reset_na='0' THEN
      mem_ack_state <= "00";
      ack_mem_i <= '0';
      ack_mem_p <= '0';
      ack_mem_p2 <= '0';
    ELSIF rising_edge(clk) THEN
      IF mem_ack_state="10" THEN ack_mem_i <= '1'; ELSE ack_mem_i <= '0'; END IF;

      -- Preserve diagnostic outputs: p=waiting, p2=completed/wait-release.
      IF mem_ack_state="01" THEN ack_mem_p <= '1'; ELSE ack_mem_p <= '0'; END IF;
      IF mem_ack_state="10" THEN ack_mem_p2 <= '1'; ELSE ack_mem_p2 <= '0'; END IF;

      CASE mem_ack_state IS
        WHEN "00" =>
          IF req_mem='1' THEN
            mem_ack_state <= "01";
          END IF;

        WHEN "01" =>
          -- One full clksys settling cycle for synchronous cartridge ROM.
          -- Then become ACK-ready without waiting an extra CPU period.
          IF req_mem='0' THEN
            mem_ack_state <= "00";
          ELSE
            mem_ack_state <= "10";
          END IF;

        WHEN OTHERS => -- "10": ACK already issued; no retrigger until REQ falls.
          IF req_mem='0' THEN
            mem_ack_state <= "00";
          END IF;
      END CASE;
    END IF;
  END PROCESS;

  ack_mem <= '1' WHEN mem_ack_state="10" ELSE '0';
  
  --ack<='0';
  
  ack<=ackp WHEN rising_edge(clk);
  
  -- Cartridge decode.  Standard Emerson-family carts expose the second
  -- 4 KiB ROM at $2000 and mirror the first block in the other even pages.
  -- Golf uses the Palladium/VCG exception: its final 2 KiB is at $4000.
  ad_rom <= "001" & ad(11 DOWNTO 0) WHEN ad(14 DOWNTO 12)="010" ELSE
            "001" & ad(11 DOWNTO 0) WHEN golf_cart='1' AND ad(14 DOWNTO 12)="100" ELSE
            "000" & ad(11 DOWNTO 0);
  
  -- CPU
  i_sgs2650: ENTITY work.sgs2650
    PORT MAP (
      req      => req,
      ack      => ack,
      ad       => ad,
      wr       => wr,
      dw       => dw,
      dr       => dr,
      mio      => mio,
      ene      => ene,
      dc       => dc,
      ph       => ph,
      int      => int,
      intack   => intack,
      ivec     => ivec,
      sense    => sense,
      flag     => flag,
      reset    => creset,
      clk      => clk,
      reset_na => reset_na);
  
  int<='0';
  ad_delay<=ad WHEN rising_edge(clk);
  
  ----------------------------------------------------------
--pragma synthesis_off
  Dump:PROCESS IS
    VARIABLE lout : line;
    VARIABLE doread : boolean := false;
    VARIABLE adr : uv15;
  BEGIN
    wure(clk);
    IF doread THEN
      write(lout,"RD(" & to_hstring('0' & adr) & ")=" & to_hstring(dr));
      writeline(fil,lout);
      doread:=false;
    END IF;
    IF req='1' AND ack='1' AND reset='0' AND reset_na='1' THEN
      IF wr='1' THEN
        write(lout,"WR(" & to_hstring('0' & ad) & ")=" & to_hstring(dw));
        writeline(fil,lout);
      ELSE
        doread:=true;
        adr:=ad;
      END IF;
    END IF;
  END PROCESS Dump;

--pragma synthesis_on
  ----------------------------------------------------------
  -- MUX VIDEO
  clk_video<=clk;
  ce_pixel<=vga_ce WHEN rising_edge(clk);
  
--  vga_de<=vga_dei  WHEN rising_edge(clk);
--  vga_hs<=vga_hsyn WHEN rising_edge(clk);
--  vga_vs<=vga_vsyn WHEN rising_edge(clk);
  vga_hs <= vga_hsyn;
  vga_vs <= vga_vsyn;
  
--  vga_argb<=vga_argb  WHEN rising_edge(clk);
  vga_r_i<=(7=>(vga_argb(2) XOR flag) AND vga_argb(3), OTHERS => (vga_argb(2) XOR flag));
  vga_g_i<=(7=>(vga_argb(1) XOR flag) AND vga_argb(3), OTHERS => (vga_argb(1) XOR flag));
  vga_b_i<=(7=>(vga_argb(0) XOR flag) AND vga_argb(3), OTHERS => (vga_argb(0) XOR flag));
  vga_r<=std_logic_vector(vga_r_i);
  vga_g<=std_logic_vector(vga_g_i);
  vga_b<=std_logic_vector(vga_b_i);
  
  ----------------------------------------------------------
  -- ROM / RAM

  wcart<='0'; -- cartridge is ROM; CPU writes must never modify it
  
  icart:PROCESS(clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      dr_rom<=cart(to_integer(ad_rom(13 DOWNTO 0))); -- 8kB
      
      IF wcart='1' THEN
        -- RAM
        cart(to_integer(ad_rom(13 DOWNTO 0))):=dw;
      END IF;
    END IF;
  END PROCESS icart;

  icart2:PROCESS(clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      -- Download
      IF w_wr='1' THEN
        cart(to_integer(w_a)):=w_d;
      END IF;
    END IF;
  END PROCESS icart2; 
  
  PROCESS(clk) IS
  BEGIN
    IF rising_edge(clk) THEN
      w_wr<=ioctl_download AND ioctl_wr;
      w_d <=unsigned(ioctl_dout);
      w_a <=unsigned(ioctl_addr(12 DOWNTO 0));
    END IF;
  END PROCESS;
  
  ioctl_wait<='0';
  
  ----------------------------------------------------------
  -- CPU CLK
  DivCLK:PROCESS (clk,reset_na) IS
  BEGIN
    IF reset_na='0' THEN
      tick_cpu<='0';
    ELSIF rising_edge(clk) THEN
      IF OSD_STATUS='1' AND pause_osd='1' THEN
        tick_cpu<='0';
      ELSIF tick_cpu_cpt=CDIV - 1 THEN
        tick_cpu_cpt<=0;
        tick_cpu<='1';
      ELSE
        tick_cpu_cpt<=tick_cpu_cpt+1;
        tick_cpu<='0';
      END IF;
    END IF;
  END PROCESS DivCLK;
  
  reset_na<=NOT reset;
  creset<=ioctl_download;
  
END struct;
