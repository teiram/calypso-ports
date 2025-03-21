library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

use work.kbd_pkg.all;

entity sviKeyboard is
port
(
    clk       : in      std_logic;
    reset     : in      std_logic;

    key       : in      std_logic_vector(7 downto 0);
    strobe    : in      std_logic;
    pressed   : in      std_logic;
    extended  : in      std_logic;

    -- Svi-3x8 matrix
    svi_row   : in      std_logic_vector(3 downto 0);
    svi_col  : out      std_logic_vector(7 downto 0)
);
end sviKeyboard;

architecture SYN of sviKeyboard is

  type key_matrix is array (0 to 15) of std_logic_vector(7 downto 0);
  signal svi_matrix  : key_matrix;

begin

    svi_col <= not svi_matrix(CONV_INTEGER(svi_row));

   decoder: process (clk, reset, key)
   begin
       if reset = '1' then
               svi_matrix(0) <= (others => '0');
               svi_matrix(1) <= (others => '0');
               svi_matrix(2) <= (others => '0');
               svi_matrix(3) <= (others => '0');
               svi_matrix(4) <= (others => '0');
               svi_matrix(5) <= (others => '0');
               svi_matrix(6) <= (others => '0');
               svi_matrix(7) <= (others => '0');
               svi_matrix(8) <= (others => '0');
               svi_matrix(9) <= (others => '0');
               svi_matrix(10) <= (others => '0');
               svi_matrix(11) <= (others => '0');
               svi_matrix(12) <= (others => '0');
               svi_matrix(13) <= (others => '0');
               svi_matrix(14) <= (others => '0');
               svi_matrix(15) <= (others => '0');

        elsif rising_edge (clk) then
         -- note: all inputs are active HIGH
         -- svi key matrix
            if (strobe = '1') then
                case key is
                    when SCANCODE_7         => svi_matrix(0)(7) <= pressed;
                    when SCANCODE_6         => svi_matrix(0)(6) <= pressed;
                    when SCANCODE_5         => svi_matrix(0)(5) <= pressed;
                    when SCANCODE_4         => svi_matrix(0)(4) <= pressed;
                    when SCANCODE_3         => svi_matrix(0)(3) <= pressed;
                    when SCANCODE_2         => svi_matrix(0)(2) <= pressed;
                    when SCANCODE_1         => svi_matrix(0)(1) <= pressed;
                    when SCANCODE_0         => svi_matrix(0)(0) <= pressed;

                    when SCANCODE_SLASH     => svi_matrix(1)(7) <= pressed;
                    when SCANCODE_PERIOD    => svi_matrix(1)(6) <= pressed;
                    when SCANCODE_EQUALS    => svi_matrix(1)(5) <= pressed;
                    when SCANCODE_COMMA     => svi_matrix(1)(4) <= pressed;
                    when SCANCODE_QUOTE     => svi_matrix(1)(3) <= pressed;
                    when SCANCODE_SEMICOLON => svi_matrix(1)(2) <= pressed;
                    when SCANCODE_9         => svi_matrix(1)(1) <= pressed;
                    when SCANCODE_8         => svi_matrix(1)(0) <= pressed;


                    when SCANCODE_G         => svi_matrix(2)(7) <= pressed;
                    when SCANCODE_F         => svi_matrix(2)(6) <= pressed;
                    when SCANCODE_E         => svi_matrix(2)(5) <= pressed;
                    when SCANCODE_D         => svi_matrix(2)(4) <= pressed;
                    when SCANCODE_C         => svi_matrix(2)(3) <= pressed;
                    when SCANCODE_B         => svi_matrix(2)(2) <= pressed;
                    when SCANCODE_A         => svi_matrix(2)(1) <= pressed;
                    when SCANCODE_MINUS     => svi_matrix(2)(0) <= pressed;


                    when SCANCODE_O         => svi_matrix(3)(7) <= pressed;
                    when SCANCODE_N         => svi_matrix(3)(6) <= pressed;
                    when SCANCODE_M         => svi_matrix(3)(5) <= pressed;
                    when SCANCODE_L         => svi_matrix(3)(4) <= pressed;
                    when SCANCODE_K         => svi_matrix(3)(3) <= pressed;
                    when SCANCODE_J         => svi_matrix(3)(2) <= pressed;
                    when SCANCODE_I         => svi_matrix(3)(1) <= pressed;
                    when SCANCODE_H         => svi_matrix(3)(0) <= pressed;


                    when SCANCODE_W         => svi_matrix(4)(7) <= pressed;
                    when SCANCODE_V         => svi_matrix(4)(6) <= pressed;
                    when SCANCODE_U         => svi_matrix(4)(5) <= pressed;
                    when SCANCODE_T         => svi_matrix(4)(4) <= pressed;
                    when SCANCODE_S         => svi_matrix(4)(3) <= pressed;
                    when SCANCODE_R         => svi_matrix(4)(2) <= pressed;
                    when SCANCODE_Q         => svi_matrix(4)(1) <= pressed;
                    when SCANCODE_P         => svi_matrix(4)(0) <= pressed;

                    when SCANCODE_UP        => svi_matrix(5)(7) <= pressed; 
                    when SCANCODE_BACKSPACE => svi_matrix(5)(6) <= pressed;
                    when SCANCODE_CLOSEBRKT => svi_matrix(5)(5) <= pressed;
                    when SCANCODE_BACKSLASH => svi_matrix(5)(4) <= pressed;
                    when SCANCODE_OPENBRKT  => svi_matrix(5)(3) <= pressed;
                    when SCANCODE_Z         => svi_matrix(5)(2) <= pressed;
                    when SCANCODE_Y         => svi_matrix(5)(1) <= pressed;
                    when SCANCODE_X         => svi_matrix(5)(0) <= pressed;

                    when SCANCODE_LEFT      => svi_matrix(6)(7) <= pressed; 
                    when SCANCODE_ENTER     => svi_matrix(6)(6) <= pressed; 
                    when SCANCODE_F8        => svi_matrix(6)(5) <= pressed; --Stop/Break
                    when SCANCODE_ESC       => svi_matrix(6)(4) <= pressed;
                    when SCANCODE_RGUI      => svi_matrix(6)(3) <= pressed; -- RGraph
                    when SCANCODE_LGUI      => svi_matrix(6)(2) <= pressed; -- LGraph
                    when SCANCODE_LCTRL     => svi_matrix(6)(1) <= pressed;
                    when SCANCODE_LSHIFT    => svi_matrix(6)(0) <= pressed;
                    when SCANCODE_RSHIFT    => svi_matrix(6)(0) <= pressed;

                    when SCANCODE_DOWN      => svi_matrix(7)(7) <= pressed; 
--                    when SCANCODE_UP        => svi_matrix(7)(6) <= pressed; -- CLS
                    when SCANCODE_INS       => svi_matrix(7)(5) <= pressed;
                    when SCANCODE_F5        => svi_matrix(7)(4) <= pressed;	
                    when SCANCODE_F4        => svi_matrix(7)(3) <= pressed;
                    when SCANCODE_F3        => svi_matrix(7)(2) <= pressed;
                    when SCANCODE_F2        => svi_matrix(7)(1) <= pressed;
                    when SCANCODE_F1        => svi_matrix(7)(0) <= pressed;


                    when SCANCODE_RIGHT     => svi_matrix(8)(7) <= pressed;
--                    when SCANCODE_UP        => svi_matrix(8)(6) <= pressed;  -- NULL/VOID/VACIO/NADA
--                    when SCANCODE_RIGHT     => svi_matrix(8)(5) <= pressed;  -- PRINT
--                    when SCANCODE_M         => svi_matrix(8)(4) <= pressed;  -- SEL  
                    when SCANCODE_CAPSLOCK  => svi_matrix(8)(3) <= pressed;
                    when SCANCODE_DELETE    => svi_matrix(8)(2) <= pressed;
                    when SCANCODE_TAB       => svi_matrix(8)(1) <= pressed;
                    when SCANCODE_SPACE     => svi_matrix(8)(0) <= pressed;

                    when SCANCODE_PAD7      => svi_matrix(9)(7) <= pressed;
--                    when SCANCODE_PAD6      => svi_matrix(9)(6) <= pressed; -- Overlaps
                    when SCANCODE_PAD5      => svi_matrix(9)(5) <= pressed;
--                    when SCANCODE_PAD4      => svi_matrix(9)(4) <= pressed; -- Overlaps 
                    when SCANCODE_PAD3      => svi_matrix(9)(3) <= pressed;
--                    when SCANCODE_PAD2      => svi_matrix(9)(2) <= pressed; -- Overlaps
                    when SCANCODE_PAD1      => svi_matrix(9)(1) <= pressed;
--                    when SCANCODE_PAD0      => svi_matrix(9)(0) <= pressed; -- Overlaps
 
--TODO
--                    when SCANCODE_ESC       => svi_matrix(10)(7) <= pressed; -- NUM,
--                    when SCANCODE_UP        => svi_matrix(10)(6) <= pressed; -- NUM.
--                    when SCANCODE_RIGHT     => svi_matrix(10)(5) <= pressed; -- NUM/
                    when SCANCODE_PADTIMES  => svi_matrix(10)(4) <= pressed;  
                    when SCANCODE_PADMINUS  => svi_matrix(10)(3) <= pressed;
                    when SCANCODE_PADPLUS   => svi_matrix(10)(2) <= pressed;
                    when SCANCODE_PAD9      => svi_matrix(10)(1) <= pressed;
--                    when SCANCODE_PAD8      => svi_matrix(10)(0) <= pressed; -- Overlaps
                    when others          => null;
                end case;
            end if;
        end if;
    end process decoder;

  
end SYN;
