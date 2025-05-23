
# time information
set_time_format -unit ns -decimal_places 3


#create clocks
create_clock -name pll_in_clk -period 83.333 [get_ports {CLK12M}]
create_clock -name spi_clk -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# pll clocks
derive_pll_clocks


# generated clocks


# name PLL clocks
set clk_sdram "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[0]"
set clk_114   "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[1]"
set clk_28    "amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[2]"


# name SDRAM ports
set sdram_outputs [get_ports {SDRAM_DQ[*] SDRAM_A[*] SDRAM_DQML SDRAM_DQMH SDRAM_nWE SDRAM_nCAS SDRAM_nRAS SDRAM_nCS SDRAM_BA[*] SDRAM_CKE}]
set sdram_inputs  [get_ports {SDRAM_DQ[*]}]


# clock groups
set_clock_groups -exclusive -group [get_clocks {amiga_clk|amiga_clk_i|altpll_component|auto_generated|pll1|clk[*]}] -group [get_clocks {spi_clk}]


# clock uncertainty
derive_clock_uncertainty


# input delay
set_input_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -max 6.4 $sdram_inputs
set_input_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -min 3.2 $sdram_inputs

#output delay
set_output_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -max  1.5 $sdram_outputs
set_output_delay -clock $clk_sdram -reference_pin [get_ports SDRAM_CLK] -min -0.8 $sdram_outputs


# false paths
set_false_path -from * -to [get_ports {SDRAM_CLK}]
set_false_path -from * -to [get_ports {LED[0]}]
set_false_path -from * -to [get_ports {UART_TX}]
set_false_path -from [get_ports {UART_RX}] -to *
set_false_path -from * -to [get_ports {VGA_*}]
set_false_path -from * -to [get_ports {AUDIO_L}]
set_false_path -from * -to [get_ports {AUDIO_R}]


# multicycle paths

set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -setup 4
set_multicycle_path -from {TG68K:tg68k|TG68KdotC_Kernel:pf68K_Kernel_inst|*} -hold 3

set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -setup 4
set_multicycle_path -from [get_clocks $clk_28] -to [get_clocks $clk_114] -hold 3

set_multicycle_path -from [get_clocks $clk_sdram] -to [get_clocks $clk_114] -setup 2

# JTAG
set ports [get_ports -nowarn {altera_reserved_tck}]
if {[get_collection_size $ports] == 1} {
  create_clock -name tck -period 100.000 [get_ports {altera_reserved_tck}]
  set_clock_groups -exclusive -group altera_reserved_tck
  set_output_delay -clock tck 20 [get_ports altera_reserved_tdo]
  set_input_delay  -clock tck 20 [get_ports altera_reserved_tdi]
  set_input_delay  -clock tck 20 [get_ports altera_reserved_tms]
  set tck altera_reserved_tck
  set tms altera_reserved_tms
  set tdi altera_reserved_tdi
  set tdo altera_reserved_tdo
  set_false_path -from *                -to [get_ports $tdo]
  set_false_path -from [get_ports $tms] -to *
  set_false_path -from [get_ports $tdi] -to *
}
