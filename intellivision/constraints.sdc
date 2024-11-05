set topmodule "clocks"

create_clock -name {CLK12M} -period 83.333 [get_ports {CLK12M}]
create_clock -name spiclk  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

set SYS_CLK   "clocks|pll|altpll_component|auto_generated|pll1|clk[0]"
set SDRAM_CLK "clocks|pll|altpll_component|auto_generated|pll1|clk[1]"

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks {CLK12M}] -group [get_clocks {clocks|pll|altpll_component|auto_generated|pll1|clk[*]}]


set RAM_CLK {SDRAM_CLK}
set RAM_OUT {SDRAM_nCS SDRAM_CKE SDRAM_DQ[*] SDRAM_A* SDRAM_DQM* SDRAM_BA* SDRAM_nRAS SDRAM_nCAS SDRAM_nWE}
set RAM_IN {SDRAM_DQ[*]}

set VGA_OUT {VGA_R* VGA_G* VGA_B* VGA_HS VGA_VS}
set FALSE_OUT {I2S_LRCK I2S_BCK I2S_DATA}

# SDRAM delays
set_input_delay -clock [get_clocks $SDRAM_CLK] -reference_pin [get_ports ${RAM_CLK}] -max 6.6 [get_ports ${RAM_IN}]
set_input_delay -clock [get_clocks $SDRAM_CLK] -reference_pin [get_ports ${RAM_CLK}] -min 3.5 [get_ports ${RAM_IN}]

set_output_delay -clock [get_clocks $SDRAM_CLK] -reference_pin [get_ports ${RAM_CLK}] -max 1.5 [get_ports ${RAM_OUT}]
set_output_delay -clock [get_clocks $SDRAM_CLK] -reference_pin [get_ports ${RAM_CLK}] -min -0.8 [get_ports ${RAM_OUT}]

#SDRAM_CLK to internal memory clock
set_multicycle_path -from [get_clocks $SDRAM_CLK] -to [get_clocks $SYS_CLK] -setup -end 2

# False paths

set_false_path -to ${VGA_OUT}
set_false_path -to ${FALSE_OUT}
