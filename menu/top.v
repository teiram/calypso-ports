module menu_top(
  input wire CLK12M,

  output wire [3:0] VGA_R,
  output wire [3:0] VGA_G,
  output wire [3:0] VGA_B,
  output wire VGA_HS,
  output wire VGA_VS,

  inout wire SPI_DO,
  input wire SPI_DI,
  input wire SPI_SCK,
  input wire CONF_DATA0,
  input wire SPI_SS2,
  input wire SPI_SS3,
  input wire SPI_SS4,
  output wire SDRAM_CLK,
  output wire SDRAM_CKE,
  output wire SDRAM_DQMH,
  output wire SDRAM_DQML,
  output wire SDRAM_nCAS,
  output wire SDRAM_nRAS,
  output wire SDRAM_nWE,
  output wire SDRAM_nCS,
  output wire[1:0] SDRAM_BA,
  output wire[12:0] SDRAM_A,
  inout wire[15:0] SDRAM_DQ,
  
  output wire I2S_LCK,
  output wire I2S_BCK,
  output wire I2S_DIN,
  
  output wire[7:0] LED,
  input wire EAR
);

MENU menu_mist(
   .CLOCK12(CLK12M),
   .SPI_DO(SPI_DO),
   .SPI_DI(SPI_DI),
   .SPI_SCK(SPI_SCK),
   .CONF_DATA0(CONF_DATA0),
   .SPI_SS2(SPI_SS2),
   .SPI_SS3(SPI_SS3),
   .VGA_HS(VGA_HS),
   .VGA_VS(VGA_VS),
   .VGA_R(VGA_R),
   .VGA_G(VGA_G),
   .VGA_B(VGA_B),
   .LED(LED[0]),
   .SDRAM_A(SDRAM_A), //std_logic_vector(12 downto 0)
   .SDRAM_DQ(SDRAM_DQ),  // std_logic_vector(15 downto 0);
   .SDRAM_DQML(SDRAM_DQML), // out
   .SDRAM_DQMH(SDRAM_DQMH), // out
   .SDRAM_nWE(SDRAM_nWE), //	:  out 		std_logic;
   .SDRAM_nCAS(SDRAM_nCAS), //	:  out 		std_logic;
   .SDRAM_nRAS(SDRAM_nRAS), //	:  out 		std_logic;
   .SDRAM_nCS(SDRAM_nCS), //	:  out 		std_logic;
   .SDRAM_BA(SDRAM_BA), //		:  out 		std_logic_vector(1 downto 0);
   .SDRAM_CLK(SDRAM_CLK), //	:  out 		std_logic;
   .SDRAM_CKE(SDRAM_CKE), //	:  out 		std_logic;
   .I2S_BCK(I2S_BCK),
   .I2S_LRCK(I2S_LCK),
   .I2S_DATA(I2S_DIN),
   .AUDIO_IN(EAR)
);

endmodule

