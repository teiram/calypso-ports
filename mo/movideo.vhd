--------------------------------------------------------------------------------
-- Thomson MO5/MO6 Video
--------------------------------------------------------------------------------
-- DO 12/2019
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

-- WEDC : Enable A7DC write
-- TA[12:0] : Light pen position
-- H1,H2,H4 :
-- LT3  : Light pen : 0= Left border 1=Right border
-- INIL : Light pen : 0=Offscreen 1=On screen
-- 

-- 40 µs / 64 µs.   40µs *  8MHz = 320
--                  40µs * 16MHz = 640

-- 13 ms / 20 ms 
-- Horloge base 16MHz = Fréquence max pixels
-- Accès RAM

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;

LIBRARY work;
USE work.base_pack.ALL;

ENTITY movideo IS
  PORT (
    ------------------------------------
    vram_a  : OUT uv14;
    vram_dr : IN uv8;
    
    ------------------------------------
    pal_a    : IN  uv5;
    pal_dw   : IN  uv8;
    pal_dr   : OUT uv8;
    pal_wr   : IN  std_logic;
    
    ------------------------------------
    mo5     : IN  std_logic;
    vmode   : IN  uv3;
    vborder : IN  uv4;
    vtrame  : IN  std_logic;

    pulse50hz : OUT std_logic;
    ------------------------------------
    -- Video out
    vid_r  : OUT uv8;
    vid_g  : OUT uv8;
    vid_b  : OUT uv8;
    vid_hs : OUT std_logic;
    vid_vs : OUT std_logic;
    vid_de : OUT std_logic;
    vid_ce : OUT std_logic;

    vid_hpos : OUT uint11;
    vid_vpos : OUT uint11;
    vid_vde  : OUT std_logic;
    
    ------------------------------------
    clk      : IN std_logic; -- 32MHz
    counter  : IN uint5;
    reset_na : IN std_logic
    );
END ENTITY movideo;

-- 0000:1FFF : Color MEM
-- 2000:3FFF : Pixel MEM

--------------------------------------------------------------------------------

ARCHITECTURE rtl OF movideo IS
  FUNCTION sel_mo5(col : uv8; pix : uv8; pos : natural) RETURN uv IS
  BEGIN
    IF pos<4     THEN RETURN mux(pix(7),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<8  THEN RETURN mux(pix(6),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<12 THEN RETURN mux(pix(5),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<16 THEN RETURN mux(pix(4),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<20 THEN RETURN mux(pix(3),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<24 THEN RETURN mux(pix(2),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSIF pos<28 THEN RETURN mux(pix(1),col(7 DOWNTO 4),col(3 DOWNTO 0));
    ELSE              RETURN mux(pix(0),col(7 DOWNTO 4),col(3 DOWNTO 0));
    END IF;
  END FUNCTION;
  
  FUNCTION sel_bm4(col : uv8; pix : uv8; pos : natural) RETURN uv IS
    VARIABLE i : natural := (pos MOD 32) / 4;
  BEGIN
    RETURN "00" & col(7-i) & pix(7-i);
  END FUNCTION;
  
  FUNCTION sel_80c(col : uv8; pix : uv8; pos : natural) RETURN uv IS
    VARIABLE t : uv16 := col & pix;
    VARIABLE i : natural := (pos MOD 32) / 2;
  BEGIN
    RETURN "000" & t(7-i);
  END FUNCTION;
  
  FUNCTION sel_bm16(col : uv8; pix : uv8; pos : natural) RETURN uv IS
    VARIABLE i : natural := (pos MOD 32) / 8;
    VARIABLE t : uv16 := pix & col;
  BEGIN
    --RETURN col(7-i) & col(3-i) & pix(7-i) & pix(3-i);
    RETURN t((3-i)*4+3 DOWNTO (3-i)*4);
  END FUNCTION;
  
  FUNCTION sel_2col(col : uv8; pos : natural) RETURN uv IS
    VARIABLE i : natural := (pos MOD 32) / 4;
  BEGIN
    RETURN "000" & col(7-i);
  END FUNCTION;
  
  FUNCTION sel_over2(col : uv8; pix : uv8; pos : natural) RETURN uv IS
    VARIABLE i : natural := (pos MOD 32) / 4;
  BEGIN
    RETURN "000" & (col(7-i) AND pix(7-i));
  END FUNCTION;
  
  FUNCTION sel_over4(col : uv8; pix : uv8; pos : natural) RETURN uv IS
    VARIABLE i : natural := (pos MOD 32) / 8;
  BEGIN
    IF col(7-i)='1' THEN RETURN "0001";
    ELSIF col(7-i-4)='1' THEN RETURN "0010";
    ELSIF pix(7-i)='1' THEN RETURN "0011";
    ELSE
      RETURN "000" & pix(i+4);
    END IF;
  END FUNCTION;
  
  SIGNAL col : uv4;
  SIGNAL plo,phi : uv8;
  SIGNAL hcpt,vcpt : uint11;
  --SIGNAL divcpt : uint5;
  SIGNAL pos : uv14;
  
  CONSTANT PAL_MO5_B : arr_uv8(0 TO 15) := (
    x"00",x"55",x"00",x"00",x"FF",x"FF",x"FF",x"FF",
    x"AA",x"AA",x"AA",x"AA",x"FF",x"FF",x"FF",x"55");
  
  CONSTANT PAL_MO5_V : arr_uv8(0 TO 15) := (
    x"00",x"55",x"FF",x"FF",x"55",x"00",x"FF",x"FF",
    x"AA",x"AA",x"FF",x"FF",x"AA",x"AA",x"FF",x"AA");
    
  CONSTANT PAL_MO5_R : arr_uv8(0 TO 15) := (
    x"00",x"FF",x"00",x"FF",x"55",x"FF",x"55",x"FF",
    x"AA",x"FF",x"AA",x"FF",x"55",x"FF",x"AA",x"FF");
  
  SIGNAL pal_lo : arr_uv8(0 TO 15) :=(
    x"00",x"5F",x"F0",x"FF",x"55",x"0F",x"F5",x"FF",
    x"AA",x"AF",x"FA",x"FF",x"A5",x"AF",x"FA",x"AF");
  SIGNAL pal_hi : arr_uv8(0 TO 15) :=(
    x"00",x"05",x"00",x"00",x"0F",x"0F",x"0F",x"0F",
    x"0A",x"0A",x"0A",x"0A",x"0F",x"0F",x"0F",x"05");
  
  CONSTANT h_offset : uint11 := 100;
  CONSTANT v_offset : uint11 := 40;
  CONSTANT h_length : uint11 := 1024;
  CONSTANT v_lines50 : uint11 := 262;
  CONSTANT v_lines60 : uint11 := 312;
  CONSTANT h_visible : uint11 := 640;
  
  ---------------------
  SIGNAL dr_col,dr_precol,dr_pix, dr_prepix : uv8;
  SIGNAL vid_vs1,vid_vs2,vid_vs3 : std_logic;
  SIGNAL vid_hs1,vid_hs2,vid_hs3 : std_logic;
  SIGNAL vid_vde1,vid_vde2,vid_vde3 : std_logic;
  SIGNAL vid_de1,vid_de2,vid_de3 : std_logic;
    
  attribute keep: boolean;
  attribute keep of dr_col: signal is true;
  attribute keep of dr_pix: signal is true;
  attribute keep of counter: signal is true;
  attribute keep of vmode: signal is true;
  attribute keep of pal_a: signal is true;
  attribute keep of pal_dw: signal is true;
  attribute keep of pal_dr: signal is true;
  attribute keep of pal_wr: signal is true;
  attribute keep of pos: signal is true;

BEGIN
  
  PROCESS(clk, reset_na) IS
  BEGIN
    IF reset_na = '0' THEN
      pulse50hz <= '0';
      pos <= (OTHERS =>'0');
      hcpt <= 0;
      vcpt <= 0;
      
    ELSIF rising_edge(clk) THEN
      -----------------------------------
      IF pal_wr='1' AND pal_a(0)='0' THEN
        pal_lo(to_integer(pal_a(4 DOWNTO 1)))<=pal_dw;
      END IF;
      IF pal_wr='1' AND pal_a(0)='1' THEN
        pal_hi(to_integer(pal_a(4 DOWNTO 1)))<=pal_dw;
      END IF;
      
      IF pal_a(0)='0' THEN
        pal_dr<=pal_lo(to_integer(pal_a(4 DOWNTO 1)));
      ELSE
       pal_dr<=pal_hi(to_integer(pal_a(4 DOWNTO 1)));
      END IF;
      
      -- 24 : R
      -- 25 : V
      -- 26 : B
      -- 27 : Pastel
      
      -- CA : 5 => 1 => 16 : R
      -- CB : 6 => 4 => 13 : V
      -- CC : 4 => 6 => 11 : B
      
      -----------------------------------
        
      IF counter = 0 THEN
        vram_a <= pos;
      ELSIF counter = 6 THEN
        dr_precol <= vram_dr;
      ELSIF counter = 11 THEN
        vram_a <= pos + 16#2000#;
      ELSIF counter = 17 THEN
        dr_prepix <= vram_dr;
      ELSIF counter = 31 THEN
        dr_pix <= dr_prepix;
        dr_col <= dr_precol;
      END IF;


      -----------------------------------
      CASE vmode IS
        ------------------------------------
        WHEN "000" => -- 40 cols 2 x 8 bits 320x200 2col [palette] 8MHz (MO5)
          col<=sel_mo5(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 4=2);
          
        WHEN "001" => -- Bit map 4,  2 x 8 bits 320x200 4col 8MHz
          col<=sel_bm4(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 4=2);
          
        WHEN "010" => -- 80 cols 16bits 640x200 2col 16MHz
          col<=sel_80c(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 2=0);
          
        WHEN "011" => -- Bit map 16, 4 x 4 bits 160x200 16col 4MHz
          col<=sel_bm16(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 8=6);
          
        WHEN "100" => -- Page 1, 8bits 2col 320x200 8MHz
          col<=sel_2col(dr_col,counter);
          vid_ce<=to_std_logic(counter MOD 4=2);
          
        WHEN "101" => -- Page 2, 8bits 2col 320x200 8MHz
          col<=sel_2col(dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 4=2);
          
        WHEN "110" => -- Surimpression 2 x 8 bits 320x200 2col + 2c 8MHz
          col<=sel_over2(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 4=2);
          
        WHEN OTHERS => -- Surimpression 4 x 4 bits 160x200 2col +2c+2c+2c 8MHz
          col<=sel_over4(dr_col,dr_pix,counter);
          vid_ce<=to_std_logic(counter MOD 8=6);
          
        ------------------------------------
      END CASE;

      plo<=pal_lo(to_integer(col));
      phi<=pal_hi(to_integer(col));
      
      -----------------------------------
      vid_r<=plo(3 DOWNTO 0) & plo(3 DOWNTO 0);
      vid_g<=plo(7 DOWNTO 4) & plo(7 DOWNTO 4);
      vid_b<=phi(3 DOWNTO 0) & phi(3 DOWNTO 0);
      
      IF mo5='1' THEN
        col<=sel_mo5(dr_col,dr_pix,counter);
        vid_ce<=to_std_logic(counter MOD 4=2);
        
        vid_r<=PAL_MO5_R(to_integer(col));
        vid_g<=PAL_MO5_V(to_integer(col));
        vid_b<=PAL_MO5_B(to_integer(col));
      END IF;

      pulse50hz <= '0';
      IF counter = 31 AND vcpt > v_offset AND hcpt > h_offset AND hcpt < h_visible + h_offset - 1 THEN
        pos <= pos + 1;
      ELSIF vcpt = 0 AND counter = 0 THEN
        pos <= (OTHERS => '0');
      END IF;
      
--        CONSTANT h_offset : uint11 := 16;
--        CONSTANT v_offset : uint11 := 10;
--        CONSTANT h_length : uint11 := 1024;
--        CONSTANT v_lines50 : uint11 := 262;
--        CONSTANT v_lines60 : uint11 := 312;
--        CONSTANT h_visible : uint11 := 640;

        
--      -- Video Sweep
      IF counter MOD 2 = 0 THEN
        IF hcpt = h_length - 1 THEN
          hcpt <= 0;
          IF (vcpt < (v_lines60 - 1) AND vtrame = '0') OR (vcpt < (v_lines50 - 1) AND vtrame = '1') THEN
            vcpt <= vcpt + 1;
          ELSE
            vcpt <= 0;
          END IF;
        ELSE
          hcpt <= hcpt + 1;
        END IF;
        

        
        pulse50hz <= to_std_logic(vcpt = 240 AND hcpt = 0);
        vid_de3 <= to_std_logic(vcpt < (200 + v_offset) AND vcpt > v_offset AND hcpt > h_offset AND hcpt < (640 + h_offset));
        vid_vde3 <= to_std_logic(vcpt < (200 + v_offset)  and vcpt > v_offset);
        vid_hs3 <= to_std_logic(hcpt >= h_length - 160);
        IF vtrame='0' THEN
          vid_vs3<=to_std_logic(vcpt > v_lines60 - 5);
        ELSE
          vid_vs3<=to_std_logic(vcpt > v_lines50 - 5);
        END IF;

        vid_vs2<=vid_vs3;
        vid_hs2<=vid_hs3;
        vid_de2<=vid_de3;
        vid_vde2<=vid_vde3;
        
        vid_vs1<=vid_vs2;
        vid_hs1<=vid_hs2;
        vid_de1<=vid_de2;
        vid_vde1<=vid_vde2;
        
      END IF;

      vid_vs<=vid_vs3;
      vid_hs<=vid_hs3;
      vid_de<=vid_de3;
      vid_vde<=vid_vde3;
      
      -----------------------------------
    END IF;
    
  END PROCESS;

  vid_vpos<=vcpt;
  vid_hpos<=hcpt;
  
    --      VRAM_A  DR_PIX   DR_COL   000,001  010
    -----------------------------------------------------------
    -- 0  : POS                      Pix 7    Pix 14
    -- 1  : POS+2k                   Pix 7    Pix 14
    -- 2  :         DR_PIXP          Pix 7    Pix 15
    -- 3  :         DR_PIX   DR_COL  Pix 7    Pix 15
    -- 4  :                          Pix 0    Pix 0
    -- 5  :                          Pix 0    Pix 0
    -- 6  :                          Pix 0    Pix 1
    -- 7  :                          Pix 0    Pix 1
    -- 8  :                          Pix 1    Pix 2
    -- 9  :                          Pix 1    Pix 2
    -- 10 :                          Pix 1
    -- 11 :                          Pix 1
    -- 12 :                          Pix 2
    -- 13 :                          Pix 2
    -- 14 :                          Pix 2
    -- 15 :                          Pix 2
    -- 16 :
    -- 17 :
    -- 18 :
    -- 19 :
    -- 20 :
    -- 21 :
    -- 22 :
    -- 23 :
    -- 24 :
    -- 25 :
    -- 26 :
    -- 27 :
    -- 28 :
    
END ARCHITECTURE rtl;

