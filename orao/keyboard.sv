
/* Keyboard matrix diagram
        ROW  A0   A1        A2    A3    A4    A5    A6    A7    A8    A9    A10
    D4  1     0   LEFT     PF1    R     O     E     L     D     F     Č     P
    D5  2     0   RIGHT    PF2    Z     I     Q     J     A     H     Ć     Đ
    D6  3     0   UP       PF3    T     U     W     K     S     G     Ž     Š
    D7  4     0   DOWN     PF4    6     7     1     M     Y     N     :     ;
    D4  5     1   CR     SPACE    5     8     2     <     X     B     /     -
    D5  6     1   CTL    SHIFT    4     9     3     >     C     V     ^     0
 */

module keyboard
(
   input             reset,
   input             clk,

   input      [10:0] ps2_key,

   input      [15:0] addr,
   output reg [7:0]  kbd_data_out
);

wire pressed    = ps2_key[9];
wire [8:0] code = ps2_key[8:0];

reg  [3:0] keyA[10:0];
reg  [1:0] keyB[10:0];

reg old_state;
reg d4, d5, d6, d7;

reg [15:0] read_addr;


always @(posedge clk)
begin
   old_state <= ps2_key[10];

   if (~addr[0])
      kbd_data_out <= {(~addr[10] ? ~keyA[10] : 4'b1111)
                     & (~addr[9]  ? ~keyA[9]  : 4'b1111)
                     & (~addr[8]  ? ~keyA[8]  : 4'b1111)
                     & (~addr[7]  ? ~keyA[7]  : 4'b1111)
                     & (~addr[6]  ? ~keyA[6]  : 4'b1111)
                     & (~addr[5]  ? ~keyA[5]  : 4'b1111)
                     & (~addr[4]  ? ~keyA[4]  : 4'b1111)
                     & (~addr[3]  ? ~keyA[3]  : 4'b1111)
                     & (~addr[2]  ? ~keyA[2]  : 4'b1111)
                     & (~addr[1]  ? ~keyA[1]  : 4'b1111)
                  , 4'b1111};
   else
      kbd_data_out <= {2'b11,
                      (~addr[10] ? ~keyB[10] : 2'b11)
                    & (~addr[9]  ? ~keyB[9]  : 2'b11)
                    & (~addr[8]  ? ~keyB[8]  : 2'b11)
                    & (~addr[7]  ? ~keyB[7]  : 2'b11)
                    & (~addr[6]  ? ~keyB[6]  : 2'b11)
                    & (~addr[5]  ? ~keyB[5]  : 2'b11)
                    & (~addr[4]  ? ~keyB[4]  : 2'b11)
                    & (~addr[3]  ? ~keyB[3]  : 2'b11)
                    & (~addr[2]  ? ~keyB[2]  : 2'b11)
                    & (~addr[1]  ? ~keyB[1]  : 2'b11)
                  , 4'b1111};

   if(ps2_key[10]) begin

      case(code[7:0])

          8'h6B,
             8'h66: keyA[1][0] <= pressed; // d4,  left or backspace
          8'h75: keyA[1][1] <= pressed; // d5,  right
          8'h72: keyA[1][2] <= pressed; // d6,  up
          8'h74: keyA[1][3] <= pressed; // d7,  down

          8'h05: keyA[2][0] <= pressed; // d4,  pf1
          8'h06: keyA[2][1] <= pressed; // d5,  pf2
          8'h04: keyA[2][2] <= pressed; // d6,  pf3
          8'h0C: keyA[2][3] <= pressed; // d7,  pf4

          8'h2D: keyA[3][0] <= pressed; // d4,  R
          8'h1A: keyA[3][1] <= pressed; // d5,  Z
          8'h2C: keyA[3][2] <= pressed; // d6,  T
          8'h36: keyA[3][3] <= pressed; // d7,  6

          8'h44: keyA[4][0] <= pressed; // d4,  O
          8'h43: keyA[4][1] <= pressed; // d5,  I
          8'h3C: keyA[4][2] <= pressed; // d6,  U
          8'h3D: keyA[4][3] <= pressed; // d7,  7

          8'h24: keyA[5][0] <= pressed; // d4,  E
          8'h15: keyA[5][1] <= pressed; // d5,  Q
          8'h1D: keyA[5][2] <= pressed; // d6,  W
          8'h16: keyA[5][3] <= pressed; // d7,  1

          8'h4B: keyA[6][0] <= pressed; // d4,  L
          8'h3B: keyA[6][1] <= pressed; // d5,  J
          8'h42: keyA[6][2] <= pressed; // d6,  K
          8'h3A: keyA[6][3] <= pressed; // d7,  M

          8'h23: keyA[7][0] <= pressed; // d4,  D
          8'h1C: keyA[7][1] <= pressed; // d5,  A
          8'h1B: keyA[7][2] <= pressed; // d6,  S
          8'h35: keyA[7][3] <= pressed; // d7,  Y

          8'h2B: keyA[8][0] <= pressed; // d4,  F
          8'h33: keyA[8][1] <= pressed; // d5,  H
          8'h34: keyA[8][2] <= pressed; // d6,  G
          8'h31: keyA[8][3] <= pressed; // d7,  N

          8'h4C: keyA[9][0] <= pressed; // d4,  Č - ;
          8'h52: keyA[9][1] <= pressed; // d5,  Ć - "
          8'h5D: keyA[9][2] <= pressed; // d6,  Ž - \ 
          8'h55: keyA[9][3] <= pressed; // d7,  : (+, =)

          8'h4D: keyA[10][0] <= pressed; // d4,  P
          8'h5B: keyA[10][1] <= pressed; // d5,  Đ - ]
          8'h54: keyA[10][2] <= pressed; // d6,  Š - [
          8'h4C: keyA[10][3] <= pressed; // d7,  ;

          /* Keyboard Bank B */

          8'h5A: keyB[1][0] <= pressed; // d4,  CR
          8'h14: keyB[1][1] <= pressed; // d5,  CTRL

          8'h29: keyB[2][0] <= pressed; // d4,  SPACE
          8'h12,
          8'h59: keyB[2][1] <= pressed; // d5,  SHIFT, both left and right

          8'h2E: keyB[3][0] <= pressed; // d4,  5
          8'h25: keyB[3][1] <= pressed; // d5,  4

          8'h3E: keyB[4][0] <= pressed; // d4,  8
          8'h46: keyB[4][1] <= pressed; // d5,  9

          8'h1E: keyB[5][0] <= pressed; // d4,  2
          8'h26: keyB[5][1] <= pressed; // d5,  3

          8'h41: keyB[6][0] <= pressed; // d4,  < ,
          8'h49: keyB[6][1] <= pressed; // d5,  > .

          8'h22: keyB[7][0] <= pressed; // d4,  X
          8'h21: keyB[7][1] <= pressed; // d5,  C

          8'h32: keyB[8][0] <= pressed; // d4,  B
          8'h2A: keyB[8][1] <= pressed; // d5,  V

          8'h4A: keyB[9][0] <= pressed; // d4,  /
          8'h0E: keyB[1][1] <= pressed; // d5,  ^ (arrow up, at)

          8'h4E: keyB[10][0] <= pressed; // d4,  -
          8'h45: keyB[10][1] <= pressed; // d5,  0

      endcase
   end

end

endmodule
