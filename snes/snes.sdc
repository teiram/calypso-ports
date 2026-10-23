# SNES for Calypso, SNESTang-style memory (snes_calypso.sv)

create_clock -name "CLK12M" -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK}  -period 40.000 [get_ports {SPI_SCK}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set sdram_clk "pll|altpll_component|auto_generated|pll1|clk[0]"
set mem_clk   "pll|altpll_component|auto_generated|pll1|clk[1]"
set sys_clk   "pll|altpll_component|auto_generated|pll1|clk[2]"
set psram_clk "pll|altpll_component|auto_generated|pll1|clk[3]"

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks pll|altpll_component|auto_generated|pll1|clk[*]]

# VGA
set_output_delay -clock [get_clocks $sys_clk] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports {VGA_*}]
set_multicycle_path -to {VGA_*[*]} -setup 2
set_multicycle_path -to {VGA_*[*]} -hold 1

# SDRAM (W9864G6, CL2 at 86 MHz)
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.5 [get_ports SDRAM_DQ[*]]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

# controller -> core (clk_mem = 4 x clk_sys): the port data is written when
# an access ends and read by the core in a later clk_sys cycle
set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -setup -start 3
set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -hold -start 2

# PSRAM (powerpack, optional). Outputs change on the falling edge of
# clk_psram, the chip samples them on the rising edge of PSRAM_CLK (c4).
create_generated_clock -name psram_clk_pin -source [get_pins -compatibility_mode {*pll1|clk[4]}] [get_ports {PSRAM_CLK}]
set_output_delay -clock psram_clk_pin -max  2.0 [get_ports {PSRAM_SIO[*] PSRAM_CE}]
set_output_delay -clock psram_clk_pin -min -1.5 [get_ports {PSRAM_SIO[*] PSRAM_CE}]
# PSRAM controller -> clk_sys (clk_sys = clk_psram / 5): every 5th edge
# coincides but the rounded PLL periods make them 2 ps apart for the timing
# analyzer; the real requirement is one clk_psram period.
set_max_delay -from [get_registers {psram_ctrl:psram|*}] -to [get_clocks $sys_clk] 9.0
set_min_delay -from [get_registers {psram_ctrl:psram|*}] -to [get_clocks $sys_clk] 0.0
# the read sampling point is calibrated at run time
set_false_path -from [get_ports {PSRAM_SIO[*]}]
set_false_path -to [get_ports {PSRAM_CLK}]

set_false_path -to [get_ports {SDRAM_CLK}]
set_false_path -to [get_ports {LED[*]}]

