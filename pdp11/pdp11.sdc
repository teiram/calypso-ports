create_clock -name "CLK12M" -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK}  -period 41.666 [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks pll|altpll_component|auto_generated|pll1|clk[*]]


# SDRAM delays
set_input_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -min 3.2 [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {VGA_*}]
set_multicycle_path -to [get_ports {VGA_*}] -setup 3
set_multicycle_path -to [get_ports {VGA_*}] -hold 2

set_false_path -to [get_ports {LED[*]}]
set_false_path -to [get_ports {AUX[*]}]