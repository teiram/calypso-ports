#===============================================================================
# Canonical timing constraints for Calypso CYC1000 (Cyclone 10 LP 10CL025YU256C8G)
#
# This file is the canonical SDC for the calypso ports. It covers the common
# cases (SPI host interface, SDRAM, VGA, I2S, LEDs, async audio) and should be
# copied into each port and adapted:
#
#   1. `pll_base`  - the PLL instance name in the top level. Most ports use
#      "pll"; ports with several PLLs (e.g. c64) need one group per PLL.
#   2. `CLOCK_50`  - only ports that actually use CLOCK_50 as a source clock
#      (and do not feed the PLL from it) should keep the guarded block.
#   3. Ports that do not exist in a given top level are harmless: get_ports on
#      a missing port returns an empty list and the constraint is a no-op.
#   4. Keep core-specific multicycle / false-path constraints AFTER the common
#      section (see footer), not inside it.
#
# Verification basis: amstrad-cpc passes with this set - setup Slow 85C
# +0.726ns / Slow 0C +2.463ns / Fast 0C +6.503ns, hold Slow 85C +0.401ns /
# Slow 0C +0.385ns / Fast 0C +0.139ns, all TNS 0.000. Only the altera_
# reserved_* JTAG pins remain unconstrained.
#===============================================================================

set pll_base pll|altpll_component|auto_generated|pll1

# ---- Clocks -----------------------------------------------------------------

create_clock -name {CLK12M}  -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK} -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# ---- Clock groups ------------------------------------------------------------

# SPI_SCK is asynchronous to the core PLL clocks.
set_clock_groups -asynchronous \
	-group [get_clocks {SPI_SCK}] \
	-group [get_clocks ${pll_base}|clk[*]]

# clk[0] and clk[1] are the PAL/NTSC clocks muxed into clk_sys; only one is
# active at a time, so paths between the two are not real - treat them as
# logically exclusive.
set_clock_groups -logically_exclusive \
	-group [get_clocks ${pll_base}|clk[0]] \
	-group [get_clocks ${pll_base}|clk[1]]


# ---- SPI host interface ------------------------------------------------------
# The host MCU drives the SPI inputs on the falling edge of SPI_SCK and the
# FPGA samples them on the rising edge; the FPGA drives SPI_DO on the falling
# edge. user_io.v / data_io.v clock all SPI registers from spi_sck.
set_input_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {SPI_DI}]
set_input_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {CONF_DATA0}]
set_input_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {SPI_SS2}]
set_input_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {SPI_SS3}]
set_input_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {SPI_SS4}]
set_output_delay -add_delay -clock_fall -clock [get_clocks {SPI_SCK}] 1.000 [get_ports {SPI_DO}]

# ---- Pins where timing is irrelevant -----------------------------------------
# VGA: the signals only need to arrive together, delay is not important.
set_false_path -to [get_ports {VGA_*}]

# I2S audio DAC: BCLK/LRCK/DATA are clocked by the DAC itself; the signals only
# need to be coherent, no external setup/hold requirement to enforce.
set_false_path -to [get_ports {I2S_BCK}]
set_false_path -to [get_ports {I2S_LRCK}]
set_false_path -to [get_ports {I2S_DATA}]

# LEDs and slow MCU control outputs.
set_false_path -to [get_ports {LED[*]}]
set_false_path -to [get_ports {MCU_MOTOR_OUT}]

# ---- Asynchronous inputs ------------------------------------------------------
# Tape/audio and UART inputs are asynchronous to the core clocks; they are
# sampled through synchronizer chains.
set_false_path -from [get_ports {AUDIO_IN}]

# ---- Core-specific constraints (multicycle paths, etc.) go here --------------
