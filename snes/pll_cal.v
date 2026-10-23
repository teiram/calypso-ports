// PLL for the SNES on Calypso with optional PSRAM (12 MHz in)
// VCO 864 MHz (12 * 72):
//   c0  86.4 MHz  SDRAM_CLK, -2985 ps (sdram_test_tang: window 25 of 80 steps,
//                 centre at -1 step; fixed phase stable 999+ runs, max load)
//   c1  86.4 MHz  clk_mem   (4 x clk_sys)
//   c2  21.6 MHz  clk_sys
//   c3 108.0 MHz  clk_psram (5 x clk_sys)
//   c4 108.0 MHz  PSRAM_CLK pin, +2142 ps, moved by the PSRAM calibration
// c0 and c4 are stepped at run time by pll_phase.sv (144.7 ps steps).
`timescale 1 ps / 1 ps
// synopsys translate_on
module pll_cal (
	inclk0,
	c0,
	c1,
	c2,
	c3,
	c4,
	locked,
	scanclk,
	phasecounterselect,
	phaseupdown,
	phasestep,
	phasedone);

	input	  inclk0;
	output	  c0;
	output	  c1;
	output	  c2;
	output	  c3;
	output	  c4;
	output	  locked;
	input	  scanclk;
	input	  [2:0] phasecounterselect;
	input	  phaseupdown;
	input	  phasestep;
	output	  phasedone;

	wire [4:0] sub_wire0;
	wire  sub_wire4;
	wire [0:0] sub_wire7 = 1'h0;
	wire  c0 = sub_wire0[0];
	wire  c1 = sub_wire0[1];
	wire  c2 = sub_wire0[2];
	wire  c3 = sub_wire0[3];
	wire  c4 = sub_wire0[4];
	wire  locked = sub_wire4;
	wire  sub_wire5 = inclk0;
	wire [1:0] sub_wire6 = {sub_wire7, sub_wire5};

	altpll	altpll_component (
				.inclk (sub_wire6),
				.clk (sub_wire0),
				.locked (sub_wire4),
				.activeclock (),
				.areset (1'b0),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b0),
				.enable0 (),
				.enable1 (),
				.extclk (),
				.extclkena ({4{1'b1}}),
				.fbin (1'b1),
				.fbmimicbidir (),
				.fbout (),
				.fref (),
				.icdrclk (),
				.pfdena (1'b1),
				.phasecounterselect (phasecounterselect),
				.phasedone (phasedone),
				.phasestep (phasestep),
				.phaseupdown (phaseupdown),
				.pllena (1'b1),
				.scanaclr (1'b0),
				.scanclk (scanclk),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.bandwidth_type = "AUTO",
		altpll_component.clk0_divide_by = 20,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 144,
		altpll_component.clk0_phase_shift = "-2985",
		altpll_component.clk1_divide_by = 20,
		altpll_component.clk1_duty_cycle = 50,
		altpll_component.clk1_multiply_by = 144,
		altpll_component.clk1_phase_shift = "0",
		altpll_component.clk2_divide_by = 80,
		altpll_component.clk2_duty_cycle = 50,
		altpll_component.clk2_multiply_by = 144,
		altpll_component.clk2_phase_shift = "0",
		altpll_component.clk3_divide_by = 16,
		altpll_component.clk3_duty_cycle = 50,
		altpll_component.clk3_multiply_by = 144,
		altpll_component.clk3_phase_shift = "0",
		altpll_component.clk4_divide_by = 16,
		altpll_component.clk4_duty_cycle = 50,
		altpll_component.clk4_multiply_by = 144,
		altpll_component.clk4_phase_shift = "2142",
		altpll_component.compensate_clock = "CLK0",
		altpll_component.inclk0_input_frequency = 83333,
		altpll_component.intended_device_family = "Cyclone 10 LP",
		altpll_component.lpm_hint = "CBX_MODULE_PREFIX=pll_cal",
		altpll_component.lpm_type = "altpll",
		altpll_component.operation_mode = "NORMAL",
		altpll_component.pll_type = "AUTO",
		altpll_component.port_activeclock = "PORT_UNUSED",
		altpll_component.port_areset = "PORT_UNUSED",
		altpll_component.port_clkbad0 = "PORT_UNUSED",
		altpll_component.port_clkbad1 = "PORT_UNUSED",
		altpll_component.port_clkloss = "PORT_UNUSED",
		altpll_component.port_clkswitch = "PORT_UNUSED",
		altpll_component.port_configupdate = "PORT_UNUSED",
		altpll_component.port_fbin = "PORT_UNUSED",
		altpll_component.port_inclk0 = "PORT_USED",
		altpll_component.port_inclk1 = "PORT_UNUSED",
		altpll_component.port_locked = "PORT_USED",
		altpll_component.port_pfdena = "PORT_UNUSED",
		altpll_component.port_phasecounterselect = "PORT_USED",
		altpll_component.port_phasedone = "PORT_USED",
		altpll_component.port_phasestep = "PORT_USED",
		altpll_component.port_phaseupdown = "PORT_USED",
		altpll_component.port_pllena = "PORT_UNUSED",
		altpll_component.port_scanaclr = "PORT_UNUSED",
		altpll_component.port_scanclk = "PORT_USED",
		altpll_component.port_scanclkena = "PORT_UNUSED",
		altpll_component.port_scandata = "PORT_UNUSED",
		altpll_component.port_scandataout = "PORT_UNUSED",
		altpll_component.port_scandone = "PORT_UNUSED",
		altpll_component.port_scanread = "PORT_UNUSED",
		altpll_component.port_scanwrite = "PORT_UNUSED",
		altpll_component.port_clk0 = "PORT_USED",
		altpll_component.port_clk1 = "PORT_USED",
		altpll_component.port_clk2 = "PORT_USED",
		altpll_component.port_clk3 = "PORT_USED",
		altpll_component.port_clk4 = "PORT_USED",
		altpll_component.port_clk5 = "PORT_UNUSED",
		altpll_component.port_clkena0 = "PORT_UNUSED",
		altpll_component.port_clkena1 = "PORT_UNUSED",
		altpll_component.port_clkena2 = "PORT_UNUSED",
		altpll_component.port_clkena3 = "PORT_UNUSED",
		altpll_component.port_clkena4 = "PORT_UNUSED",
		altpll_component.port_clkena5 = "PORT_UNUSED",
		altpll_component.port_extclk0 = "PORT_UNUSED",
		altpll_component.port_extclk1 = "PORT_UNUSED",
		altpll_component.port_extclk2 = "PORT_UNUSED",
		altpll_component.port_extclk3 = "PORT_UNUSED",
		altpll_component.self_reset_on_loss_lock = "OFF",
		altpll_component.width_clock = 5,
		altpll_component.width_phasecounterselect = 3;

endmodule
