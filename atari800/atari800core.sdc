#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name CLK12M -period 83.333  [get_ports {CLK12M}]
create_clock -name {SPI_SCK}  -period 40  [get_ports {SPI_SCK}]

set sdram_clk "atari800core_calypso|pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[2]"
set mem_clk   "atari800core_calypso|pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[0]"
set sys_clk   "atari800core_calypso|pll_switcher|generic_pll2|altpll_component|auto_generated|pll1|clk[1]"

#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks

#**************************************************************
# Set Clock Latency
#**************************************************************


#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty;

#**************************************************************
# Set Input Delay
#**************************************************************

# SDRAM is clocked from sd1clk_pin, but the SDRAM controller uses memclk
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -min 3.2 [get_ports SDRAM_DQ[*]]


#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports SDRAM_CLK] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_output_delay -clock [get_clocks $sys_clk] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports {VGA_*}]

#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {atari800core_calypso|pll_switcher|*}]
set_clock_groups -asynchronous -group [get_clocks {CLK12M}] -group [get_clocks {atari800core_calypso|pll_switcher|*}]
set_clock_groups -asynchronous -group [get_clocks {atari800core_calypso|reconfig_pll|*}] -group [get_clocks {atari800core_calypso|pll_switcher|*}]

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_ports {UART_TX}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {LED[0]}]

#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -to {VGA_*[*]} -setup 2
set_multicycle_path -to {VGA_*[*]} -hold 1

set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup 2

#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************
