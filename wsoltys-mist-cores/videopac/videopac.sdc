#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.1.4 Build 182 03/12/2014 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2014 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "CLK12M" -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# Clock groups
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {pll_b|altpll_component|auto_generated|pll1|clk[*]}]

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks {pll_b|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks {pll_b|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {VGA_*}]

set_multicycle_path -to {VGA_*[*]} -setup 4
set_multicycle_path -to {VGA_*[*]} -hold 3

set_false_path -to [get_ports {LED[*]}]
