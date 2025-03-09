#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks

derive_clock_uncertainty

#**************************************************************
# Create Clock
#**************************************************************
set sys_clk "pll1|altpll_component|auto_generated|pll1|clk[2]"
create_clock -name {clk} -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK}  -period 41.666 [get_ports {SPI_SCK}]
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks $sys_clk]

#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk}] -setup 0.100  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk}] -hold 0.070  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk}] -setup 0.100  
#set_clock_uncertainty -rise_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk}] -hold 0.070  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk}] -setup 0.100  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -rise_to [get_clocks {clk}] -hold 0.070  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk}] -setup 0.100  
#set_clock_uncertainty -fall_from [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -fall_to [get_clocks {clk}] -hold 0.070  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
#set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -setup 0.070  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -hold 0.100  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.020  
#set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.020  




#**************************************************************
# Set Input Delay
#**************************************************************
set_input_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -min 3.2 [get_ports SDRAM_DQ[*]]



#**************************************************************
# Set Output Delay
#**************************************************************
set_output_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_output_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {VGA_*}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

#set_false_path -from [get_keepers {topboard:kernel|wbc_rst:reset|key_down}] -to [get_keepers {topboard:kernel|wbc_rst:reset|key_syn[0]}]
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|count_dc[*]}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|count_ac[*]}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|count_pw[*]}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|sys_dclo}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|sys_rst}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|sys_aclo}
#set_false_path -from {topboard:kernel|wbc_rst:reset|pwr_event} -to {topboard:kernel|wbc_rst:reset|pwr_rst}

#set_false_path -from {topboard:kernel|ksm:terminal|vga:video|row[*]} -to {topboard:kernel|kgd:graphics|wb_dat_o[*]}
#set_false_path -from {topboard:kernel|ksm:terminal|vga:video|col[*]} -to {topboard:kernel|kgd:graphics|wb_dat_o[*]}

#set_false_path -from {topboard:kernel|ksm:terminal|wbc_uart:uart|tx_csr_brk} -to {topboard:kernel|wbc_uart:uart1|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|ksm:terminal|wbc_uart:uart|tx_csr_brk} -to {topboard:kernel|wbc_uart:uart2|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|wbc_uart:uart1|tx_csr_brk} -to {topboard:kernel|ksm:terminal|wbc_uart:uart|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|wbc_uart:uart2|tx_csr_brk} -to {topboard:kernel|ksm:terminal|wbc_uart:uart|rx_rdata_reg[0]}

#set_false_path -from {topboard:kernel|ksm:terminal|wbc_uart:uart|tx_shr[0]} -to {topboard:kernel|wbc_uart:uart1|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|ksm:terminal|wbc_uart:uart|tx_shr[0]} -to {topboard:kernel|wbc_uart:uart2|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|wbc_uart:uart1|tx_shr[0]} -to {topboard:kernel|ksm:terminal|wbc_uart:uart|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|wbc_uart:uart2|tx_shr[0]} -to {topboard:kernel|ksm:terminal|wbc_uart:uart|rx_rdata_reg[0]}

#set_false_path -from {topboard:kernel|ksm:terminal|vregs:videoreg|vtcsr[0]} -to {topboard:kernel|wbc_uart:uart1|rx_rdata_reg[0]}
#set_false_path -from {topboard:kernel|ksm:terminal|vregs:videoreg|vtcsr[0]} -to {topboard:kernel|wbc_uart:uart2|rx_rdata_reg[0]}

#set_false_path -from {topboard:kernel|ksm:terminal|vregs:videoreg|vtcsr[*]} -to {topboard:kernel|wbc_uart:uart1|baud_div[*]}
#set_false_path -from {topboard:kernel|ksm:terminal|vregs:videoreg|vtcsr[*]} -to {topboard:kernel|wbc_uart:uart2|baud_div[*]}

#set_false_path -from {topboard:kernel|wbc_rst:reset|sys_aclo} -to {topboard:kernel|mc1201_02:cpu|vm2_wb:cpu|io_st[*]}


#**************************************************************
# Set Multicycle Path
#**************************************************************

set_multicycle_path -to [get_ports {VGA_*}] -setup 3
set_multicycle_path -to [get_ports {VGA_*}] -hold 2


#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

