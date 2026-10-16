#===============================================================================
# Timing constraints for the Calypso CYC1000 TSConf port
# (Cyclone 10 LP 10CL025YU256C8G)
#
# The common section below is common/template/machine.sdc (the canonical Calypso
# SDC); keep the two in sync. Port-specific constraints live in the footer.
#
# Port notes:
#   1. The PLL (`pll`, ALTPLL) has a single output: clk[0] = 12 MHz * 7 = 84 MHz.
#      Upstream's VGA-on-clk[1] output delays therefore do not apply here (VGA is
#      driven from clk[0] and false-pathed). The core instead runs on the gated
#      28 MHz clock `fclk = clk & ce` (tsconf.v:354), which TimeQuest analyses as
#      clk[0], while the SDRAM FSM runs on the ungated clk[0] and `sdram.v` drives
#      SDRAM_CLK from fabric. The core -> SDRAM command capture is consequently a
#      clk[0]-to-clk[0] crossing here and is given upstream's multicycle in the
#      footer (see "SDRAM command capture").
#   2. CLOCK_50 is not used (the board clocks the design from CLK12M).
#   3. I2S_AUDIO, USE_AUDIO_IN and BIG_OSD are on and NO_DIRECT_UPLOAD is on, so
#      there is no SPI_SS4 port; the get_ports call for it is a no-op.
#   4. The MIDI output path (serial_packer -> user_io serial FIFO) uses a strobe
#      as a clock; it is declared in the footer so it is analysed instead of
#      being reported as an unconstrained clock.
#===============================================================================

set pll_base pll|altpll_component|auto_generated|pll1

# ---- Clocks -------------------------------------------------------------------

create_clock -name {CLK12M}  -period 83.333 [get_ports {CLK12M}]
create_clock -name {SPI_SCK} -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# Optional 50 MHz reference (only used by some ports, see header note 2).
if {[llength [get_ports {CLOCK_50}]]} {
	create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]
}

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# ---- Clock groups -------------------------------------------------------------

# SPI_SCK and CLOCK_50 are asynchronous to the core PLL clocks.
set_clock_groups -asynchronous \
	-group [get_clocks {SPI_SCK}] \
	-group [get_clocks ${pll_base}|clk[*]]

if {[llength [get_ports {CLOCK_50}]]} {
	set_clock_groups -asynchronous \
		-group [get_clocks {CLOCK_50}] \
		-group [get_clocks ${pll_base}|clk[*]]
}

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

# ---- SDRAM -------------------------------------------------------------------
# Read side (SDRAM_DQ driven by the SDRAM, sampled on clk[0]).
set_input_delay -clock [get_clocks ${pll_base}|clk[0]] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks ${pll_base}|clk[0]] -reference_pin [get_ports {SDRAM_CLK}] -min 3.2 [get_ports SDRAM_DQ[*]]

# Write side. -max 1.5 models the SDRAM access time; -min 1.0 models the SDRAM
# hold time (tDH ~1ns). NOTE on polarity: a MORE negative -min TIGHTENS hold
# (the -min delay is subtracted from the data required time), so relaxing hold
# means making -min MORE positive. -0.8 failed on ports generating SDRAM_CLK in
# fabric (`assign SDRAM_CLK = clk`, which this port does); 1.0 passes.
set_output_delay -clock [get_clocks ${pll_base}|clk[0]] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks ${pll_base}|clk[0]] -reference_pin [get_ports {SDRAM_CLK}] -min 1.0 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_false_path -to [get_ports {SDRAM_CLK}]

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

# Sigma-delta DACs / analog audio outputs.
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]

# ---- Asynchronous inputs ------------------------------------------------------
# Tape/audio and UART inputs are asynchronous to the core clocks; they are
# sampled through synchronizer chains.
set_false_path -from [get_ports {AUDIO_IN}]
set_false_path -from [get_ports {MCU_AUDIO_IN}]
set_false_path -from [get_ports {UART_RX}]

# The audio return link from the RP2040 (i2s_decoder) runs at its own bit rate,
# unrelated to clk[0], and is sampled through cks/ckd synchronizers.
set_false_path -from [get_ports {I2S_MIDI_BCK}]
set_false_path -from [get_ports {I2S_MIDI_LRCK}]
set_false_path -from [get_ports {I2S_MIDI_DATA}]

# ---- Core-specific constraints (multicycle paths, etc.) -----------------------
# SAA1099. The chip is only enabled on 2 of every 7 clk[0] cycles (`ce_saa` in
# tsconf.v, ~24 MHz), so its amplitude -> output mixer adder tree has at least
# two 84 MHz cycles of budget. This is the upstream MiST constraint
# (TSConf_MiST/TSConf.sdc) that the port's original SDC dropped; with it absent
# the mixer path misses setup by ~7 ns and the port does not close.
set_multicycle_path -to {tsconf|saa1099|*} -setup 2
set_multicycle_path -to {tsconf|saa1099|*} -hold 1

# Z80 and Turbosound CPU: multi-cycle bus timing, as in the upstream SDC.
set_multicycle_path -from {tsconf|CPU|*} -setup 2
set_multicycle_path -from {tsconf|CPU|*} -hold 1
set_multicycle_path -to {tsconf|CPU|*} -setup 2
set_multicycle_path -to {tsconf|CPU|*} -hold 1

set_multicycle_path -to {tsconf|gs_top|gs|CPU|*} -setup 2
set_multicycle_path -to {tsconf|gs_top|gs|CPU|*} -hold 1

# SDRAM command capture. `sdram` is clocked by the *ungated* clk (tsconf.v:450
# `.clk(clk)`), so its FSM runs at clk[0] = 84 MHz, but the commands it captures
# (Ar1/Ar2, dqm1/dqm2, rq1/rq2, rd1/rd2) are driven by the core, which runs on
# the gated 28 MHz `fclk = clk & ce` (tsconf.v:354). The state-24 latch block
# re-samples those inputs on *every* clk[0] edge, but the state only leaves 24 on
# a `cyc` (= `ce & c3`, tsconf.v:451) cycle, and `cyc` can only rise on an fclk
# edge (ce is high only at fclk edges): launch and capture are always a whole
# 28 MHz period (= 3 clk[0] cycles, 35.7 ns) apart. `-setup 2` (23.8 ns) is one
# clk[0] cycle *tighter* than the hardware needs, and pairs with `-hold 1` to
# leave the hold check where it was. This is upstream MiST's constraint for the
# same crossing (`-from clk[0] -to clk[1] -setup 2`); without it the capture
# misses by ~2.2 ns and the whole run reports "Timing requirements not met".
# Only the state-24 latch registers are listed: `sdram|data` (the SDRAM_DQ input
# capture) must keep its single-cycle relationship, and it does.
set_multicycle_path -to {tsconf|sdram|Ar1[*] tsconf|sdram|Ar2[*] tsconf|sdram|dqm1[*] tsconf|sdram|dqm2[*] tsconf|sdram|rq1 tsconf|sdram|rq2 tsconf|sdram|rd1 tsconf|sdram|rd2} -setup 2
set_multicycle_path -to {tsconf|sdram|Ar1[*] tsconf|sdram|Ar2[*] tsconf|sdram|dqm1[*] tsconf|sdram|dqm2[*] tsconf|sdram|rq1 tsconf|sdram|rq2 tsconf|sdram|rd1 tsconf|sdram|rd2} -hold 1

# NOTE -- the 0.000 ns path. After the fix above the design closes with TNS 0 and
# no violated paths, but the worst remaining setup path (clk[0], slack 0.000) is
# an *upstream* property rather than a constraint gap, so nobody should "fix" it
# by hand. The MC146818A RTC is clocked by the *ungated* clk and enabled from a
# free-running /192 counter (tsconf.v:963-977, `.CLK(clk)` at :976), so it
# captures the 28 MHz core data bus at a clk[0] edge: 11.904 ns relationship,
# launch on the gated fclk network which sits ~4.1 ns *later* in the clock tree
# (clk -> LUT -> clkctrl -> global) than the RTC's raw clk[0], leaving ~7.6 ns of
# logic. It is met, but with no margin, so a refit can flip it. A multicycle is
# not honest here (the enable's phase against `ce` is a power-up state STA cannot
# rely on); the real fixes are upstream (register the RTC data inputs) or a real
# 28 MHz PLL output for the core, which removes the LUT+clkctrl insertion penalty
# at the cost of patching tsconf.v to keep the SDRAM FSM on 84 MHz.

# MIDI output. serial_packer asserts `serial_strobe_out` once per MIDI frame,
# and user_io.v clocks its serial FIFO write pointer directly from that strobe
# (always @(posedge serial_strobe ...)), so Quartus infers a clock. The strobe
# comes ~1.02 * 84 MHz / 31250 = 2742 clk[0] cycles apart; model it as a divided
# clock (1024 is conservative) so the path into the FIFO is analysed rather than
# reported as unconstrained. The target must be named as a *register*
# (get_registers); the same name via get_pins does not match and the whole
# constraint is dropped with a Critical Warning.
create_generated_clock -name {midi_strobe} \
	-source [get_pins ${pll_base}|clk[0]] \
	-divide_by 1024 \
	[get_registers {serial_packer:midi_packer|serial_strobe_out}]

# ... and its read side is unrelated to SPI_SCK. user_io.v:213-239 crosses the
# serial-out FIFO with a bare (non-gray) pointer compare: `serial_out_wptr` runs
# on the strobe, `serial_out_rptr` and the drain on SPI_SCK, and
# `serial_out_data_available` compares them across the two domains. The strobe is
# a ~31 kHz bit edge and SPI_SCK is ~24 MHz, so the crossing is asynchronous by
# construction (this is mist-modules' shared design, unconstrained in every MiST
# core); declaring it async keeps STA from analysing it as a synchronous path.
# Without this, activating the clock above turns the crossing into ~5.6 ns setup
# violations that are meaningless.
set_clock_groups -asynchronous \
	-group [get_clocks {midi_strobe}] \
	-group [get_clocks {SPI_SCK}]
