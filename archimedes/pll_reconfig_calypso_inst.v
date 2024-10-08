pll_reconfig_calypso	pll_reconfig_calypso_inst (
	.clock ( clock_sig ),
	.counter_param ( counter_param_sig ),
	.counter_type ( counter_type_sig ),
	.data_in ( data_in_sig ),
	.pll_areset_in ( pll_areset_in_sig ),
	.pll_scandataout ( pll_scandataout_sig ),
	.pll_scandone ( pll_scandone_sig ),
	.read_param ( read_param_sig ),
	.reconfig ( reconfig_sig ),
	.reset ( reset_sig ),
	.reset_rom_address ( reset_rom_address_sig ),
	.rom_data_in ( rom_data_in_sig ),
	.write_from_rom ( write_from_rom_sig ),
	.write_param ( write_param_sig ),
	.busy ( busy_sig ),
	.data_out ( data_out_sig ),
	.pll_areset ( pll_areset_sig ),
	.pll_configupdate ( pll_configupdate_sig ),
	.pll_scanclk ( pll_scanclk_sig ),
	.pll_scanclkena ( pll_scanclkena_sig ),
	.pll_scandata ( pll_scandata_sig ),
	.rom_address_out ( rom_address_out_sig ),
	.write_rom_ena ( write_rom_ena_sig )
	);
