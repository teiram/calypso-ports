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
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}]

# SDRAM delays
set_input_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -min 3.2 [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {pll_1|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {pll_1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 35 -divide_by 44 -master_clock {CLK12M} [get_pins {pll_1|altpll_component|auto_generated|pll1|clk[0]}] 
create_generated_clock -name {pll_1|altpll_component|auto_generated|pll1|clk[1]} -source [get_pins {pll_1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 35 -divide_by 11 -master_clock {CLK12M} [get_pins {pll_1|altpll_component|auto_generated|pll1|clk[1]}] 
create_generated_clock -name {pll_1|altpll_component|auto_generated|pll1|clk[2]} -source [get_pins {pll_1|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 35 -divide_by 11 -phase -45.000 -master_clock {CLK12M} [get_pins {pll_1|altpll_component|auto_generated|pll1|clk[2]}] 
create_generated_clock -name {sd1clk_pin} -source [get_pins {pll_1|altpll_component|auto_generated|pll1|clk[2]}] -master_clock {pll_1|altpll_component|auto_generated|pll1|clk[2]} [get_ports {sdram_clk_o}] 
create_generated_clock -name {sysclk} -source [get_pins {pll_1|altpll_component|auto_generated|pll1|clk[1]}] -master_clock {pll_1|altpll_component|auto_generated|pll1|clk[1]} 

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {VGA_*}]
set_multicycle_path -to [get_ports {VGA_*}] -setup 5
set_multicycle_path -to [get_ports {VGA_*}] -hold 4

set_multicycle_path -from {video:video|video_mixer:video_mixer|scandoubler:scandoubler|Hq2x:Hq2x|*} -setup 6
set_multicycle_path -from {video:video|video_mixer:video_mixer|scandoubler:scandoubler|Hq2x:Hq2x|*} -hold 5


# False paths

# Don't bother optimizing sigma_delta_dac
set_false_path -to {sigma_delta_dac:*}

#set_false_path -to [get_ports {VGA_*}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {LED[*]}]
set_false_path -from [get_ports {UART_RX}]