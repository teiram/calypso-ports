# Report timing in ns to 3 decimal places.
set_time_format -unit ns -decimal_places 3

# This is the external oscillator of the board.
create_clock -name clkin -period "50.0 MHz" [get_ports {clkin}]

# There are two plls.  The ADC gets a 10 MHz clock called clk10mhz and
# the SDRAM gets a 100 MHz clock called c0 internally, and dram_clk
# externally.  c0 and dram_clk differ by the delay from the pll to the
# output pin of the FPGA.
derive_pll_clocks

# In the netlist, c0 would normally be called
# pll0|altpll_component|auto_generated|pll1|clk[0].
#
# But, the Quartus fitter combines the ADC and SDRAM plls, so c0 winds
# up as adc0|adcpll|altpll_component|auto_generated|pll1|clk[1].
#set c0 {adc0|adcpll|altpll_component|auto_generated|pll1|clk[1]}
set c0 {pll0|altpll_component|auto_generated|pll1|clk[0]}

# clk10mhz winds up as adc0|adcpll|altpll_component|auto_generated|pll1|clk[0].
#set clk10mhz {adc0|adcpll|altpll_component|auto_generated|pll1|clk[0]}

# The SDRAM will use the dram_clk, which is just an external representation
# of c0.
create_generated_clock -name dram_clk -source [get_pins $c0] [get_ports {dram_clk}]

# The CPU clock is produced by dividing c0 by 14 in the DRAM state machine.
create_generated_clock -name cpuclk -source [get_pins $c0] -divide_by 14 [get_nets {sdram0|cpuclk}]

# The SD SPI interface has two clock speeds.  In both cases, the clock is
# derived from clkin.  During initialization, clkin is divided by 128, so
# the clock is around 391 kHz.  During normal operation, clkin is divided
# by 4, so the SPI interface runs at 12.5 MHz.
create_generated_clock -name sdcard_sclk -source [get_ports {clkin}] \
	-divide_by 4 [get_keepers {unibus:pdp11|rh11:rh0|sdspi:sd1|clk sdcard_sclk}]

derive_clock_uncertainty

# SDRAM Interface input paths
#
# The SDRAM produces data 5.4 ns after the clock edge and holds the data
# for 2.5 ns.  We will derate that by 0.1 ns for skew and by 0.4 ns for
# trace delay on the PCB.  The trace delay is always positive, but the
# skew is +/-.
#
# max 5.4 + 0.4 + 0.1 = 5.9
# min 2.5 + 0.4 - 0.1 = 2.8
set_input_delay -max -clock dram_clk 5.9 [get_ports dram_dq*]
set_input_delay -min -clock dram_clk 2.8 [get_ports dram_dq*]

# SDRAM Interface output paths
#
# The SDRAM needs 1.5 ns setup and 0.8 ns hold.  We will derate that by
# 0.1 ns to account for skew.
#
# max  1.5 + 0.1 =  1.6
# min -0.8 - 0.1 = -0.9
set_output_delay -max -clock dram_clk  1.6 [get_ports {dram_dq* dram_*dqm dram_addr* dram_ba* }]
set_output_delay -min -clock dram_clk -0.9 [get_ports {dram_dq* dram_*dqm dram_addr* dram_ba* }]
set_output_delay -max -clock dram_clk  1.6 [get_ports {dram_ras_n dram_cas_n dram_we_n dram_cke dram_cs_n}]
set_output_delay -min -clock dram_clk -0.9 [get_ports {dram_ras_n dram_cas_n dram_we_n dram_cke dram_cs_n}]

# SDRAM Interface multi-paths
#
# The read command to the SDRAM is clocked out of the FPGA in state "dram_c8" and it
# is received by the SDRAM in state "dram_c9".  The SDRAM was programmed for CAS = 3,
# so the data will be produced by the SDRAM in state "dram_c12", and the FPGA can
# receive it in state "dram_c13".
#
# There is one additional state, "dram_c14", before we go back to state "dram_c1".
# The CPU state machine clocks in data on a rising edge, which occurs in state
# "dram_c1", therefore, we have a multicycle path of 2 on SDRAM data input.
#
# Because the dram_dq clock (source) is faster than the CPU clock (sink), we will
# use the -start flag.  We spec the hold as one less than the setup, which is
# essentially "0 ns" if I understand the manual correctly.
set_multicycle_path -start -from [get_clocks {dram_clk}] -to [get_clocks {cpuclk}] -setup 2
set_multicycle_path -start -from [get_clocks {dram_clk}] -to [get_clocks {cpuclk}] -hold  1

set_multicycle_path -start -from [get_clocks $c0] -to [get_clocks {cpuclk}] -setup 2
set_multicycle_path -start -from [get_clocks $c0] -to [get_clocks {cpuclk}] -hold  1

# The CPU changes its internal states on the rising edge of its clock.  The internal
# state determines what data will be available from the CPU, after some propagation
# delay.  The write command to the SDRAM is clocked out of the FPGA in state "dram_c8"
# along with the data.  The SDRAM receives it in state "dram_c9".
#
# We should have 6 cycles of the SDRAM clock for the data to propagate and be captured.
# Because the CPU clock (source) is slower than the dram_dq clock (sink) we will use
# the -end flag.
#
# Note that we are not taking the RH70 bus master into account here, because we don't
# have one in this configuration.
set_multicycle_path -end -from [get_clocks {cpuclk}] -to [get_clocks {dram_clk}] -setup 6
set_multicycle_path -end -from [get_clocks {cpuclk}] -to [get_clocks {dram_clk}] -hold  5

set_multicycle_path -end -from [get_clocks {cpuclk}] -to [get_clocks $c0] -setup 6
set_multicycle_path -end -from [get_clocks {cpuclk}] -to [get_clocks $c0] -hold  5

# SD Card Interface
set_input_delay  -add_delay -clock [get_clocks {sdcard_sclk}] 1 [get_ports {sdcard_miso}]
set_output_delay -add_delay -clock [get_clocks {sdcard_sclk}] 1 [get_ports {sdcard_cs sdcard_mosi}]

# Note that the choice of "from" and "to" in set_false_path is important.
# Inputs must be "from" and outputs must be "to".  Otherwise, the timing
# analyzer will ignore them.
set_false_path -from [get_ports {sw*}] -to *
set_false_path -from [get_ports {button*}] -to *
set_false_path -from [get_ports {rx*}] -to *
set_false_path -from [get_ports {panel_col*}] -to *

set_false_path -from * -to [get_ports {redled*}]
set_false_path -from * -to [get_ports {sseg*}]
set_false_path -from * -to [get_ports {tx*}]
set_false_path -from * -to [get_ports {panel_col*}]
set_false_path -from * -to [get_ports {panel_row*}]
set_false_path -from * -to [get_ports {panel_xled*}]
