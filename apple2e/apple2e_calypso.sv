module apple2e_calypso(
    input CLK12M,

    output [7:0] LED,
    output [VGA_BITS-1:0] VGA_R,
    output [VGA_BITS-1:0] VGA_G,
    output [VGA_BITS-1:0] VGA_B,
    output VGA_HS,
    output VGA_VS,

    input SPI_SCK,
    inout SPI_DO,
    input SPI_DI,
    input SPI_SS2, 
    input SPI_SS3,
    input CONF_DATA0, 

`ifndef NO_DIRECT_UPLOAD
    input SPI_SS4,
`endif

`ifdef I2S_AUDIO
    output I2S_BCK,
    output I2S_LRCK,
    output I2S_DATA,
`endif
`ifdef USE_AUDIO_IN
    input AUDIO_IN,
`endif

    output [12:0] SDRAM_A,
    inout [15:0] SDRAM_DQ,
    output SDRAM_DQML,
    output SDRAM_DQMH,
    output SDRAM_nWE,
    output SDRAM_nCAS,
    output SDRAM_nRAS,
    output SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CLK,
    output SDRAM_CKE
);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 4;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef USE_AUDIO_IN
localparam bit USE_AUDIO_IN = 1;
`else
localparam bit USE_AUDIO_IN = 0;
`endif

`include "build_id.v"

assign SDRAM_CLK = sdram_clk;

apple2e_top
#(
    .VGA_BITS(VGA_BITS),
    .BIG_OSD(BIG_OSD ? "true" : "false"),
    .HDMI("false"),
    .BUILD_DATE(`BUILD_DATE),
    .BUILD_VERSION(`BUILD_VERSION)
)
apple2e_top(
    .CLOCK_IN(CLK12M),

    .LED(LED),

    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),

`ifdef USE_AUDIO_IN
    .AUDIO_IN(AUDIO_IN),
`else
    .AUDIO_IN(UART_RX),
`endif
`ifdef I2S_AUDIO
    .I2S_BCK(I2S_BCK),
    .I2S_LRCK(I2S_LRCK),
    .I2S_DATA(I2S_DATA),
`endif
    .SPI_SCK(SPI_SCK),
    .SPI_DO(SPI_DO),
    .SPI_DI(SPI_DI),
    .SPI_SS2(SPI_SS2),
    .SPI_SS3(SPI_SS3),
    .SPI_SS4(SPI_SS4),
    .CONF_DATA0(CONF_DATA0),

    .SDRAM_A(SDRAM_A),
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_CLK(sdram_clk),
    .SDRAM_CKE(SDRAM_CKE)
);
endmodule 
