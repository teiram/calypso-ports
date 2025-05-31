create_clock -name "CLK12M" -period 83.333 [get_ports {CLK12M}]
create_clock -name "SPI_SCK"  -period 40.000 [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set_clock_groups -asynchronous \
    -group {sys_clks \
       pll|altpll_component|auto_generated|pll1|clk[0] \
       pll|altpll_component|auto_generated|pll1|clk[1] \
    } \
    -group {spi_clk SPI_SCK}
