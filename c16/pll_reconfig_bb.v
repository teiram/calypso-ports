// megafunction wizard: %ALTPLL_RECONFIG%VBB%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altpll_reconfig 

// ============================================================
// File Name: pll_reconfig.v
// Megafunction Name(s):
// 			altpll_reconfig
//
// Simulation Library Files(s):
// 			altera_mf;cyclone10lp;lpm
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 22.1std.2 Build 922 07/20/2023 SC Lite Edition
// ************************************************************

//Copyright (C) 2023  Intel Corporation. All rights reserved.
//Your use of Intel Corporation's design tools, logic functions 
//and other software and tools, and any partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Intel Program License 
//Subscription Agreement, the Intel Quartus Prime License Agreement,
//the Intel FPGA IP License Agreement, or other applicable license
//agreement, including, without limitation, that your use is for
//the sole purpose of programming logic devices manufactured by
//Intel and sold by Intel or its authorized distributors.  Please
//refer to the applicable agreement for further details, at
//https://fpgasoftware.intel.com/eula.

module pll_reconfig (
	clock,
	counter_param,
	counter_type,
	data_in,
	pll_areset_in,
	pll_scandataout,
	pll_scandone,
	read_param,
	reconfig,
	reset,
	reset_rom_address,
	rom_data_in,
	write_from_rom,
	write_param,
	busy,
	data_out,
	pll_areset,
	pll_configupdate,
	pll_scanclk,
	pll_scanclkena,
	pll_scandata,
	rom_address_out,
	write_rom_ena)/* synthesis synthesis_clearbox = 1 */;

	input	  clock;
	input	[2:0]  counter_param;
	input	[3:0]  counter_type;
	input	[8:0]  data_in;
	input	  pll_areset_in;
	input	  pll_scandataout;
	input	  pll_scandone;
	input	  read_param;
	input	  reconfig;
	input	  reset;
	input	  reset_rom_address;
	input	  rom_data_in;
	input	  write_from_rom;
	input	  write_param;
	output	  busy;
	output	[8:0]  data_out;
	output	  pll_areset;
	output	  pll_configupdate;
	output	  pll_scanclk;
	output	  pll_scanclkena;
	output	  pll_scandata;
	output	[7:0]  rom_address_out;
	output	  write_rom_ena;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  pll_areset_in;
	tri0	  reset_rom_address;
	tri0	  rom_data_in;
	tri0	  write_from_rom;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: CHAIN_TYPE NUMERIC "0"
// Retrieval info: PRIVATE: INIT_FILE_NAME STRING "./c16/pll_c16_pal.mif"
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone 10 LP"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: PRIVATE: USE_INIT_FILE STRING "1"
// Retrieval info: CONSTANT: INIT_FROM_EXTERNAL_ROM_CHECKBOX_CHECKED STRING "YES"
// Retrieval info: CONSTANT: INIT_FROM_ROM STRING "NO"
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone 10 LP"
// Retrieval info: CONSTANT: SCAN_INIT_FILE STRING "./c16/pll_c16_pal.mif"
// Retrieval info: USED_PORT: busy 0 0 0 0 OUTPUT NODEFVAL "busy"
// Retrieval info: USED_PORT: clock 0 0 0 0 INPUT NODEFVAL "clock"
// Retrieval info: USED_PORT: counter_param 0 0 3 0 INPUT NODEFVAL "counter_param[2..0]"
// Retrieval info: USED_PORT: counter_type 0 0 4 0 INPUT NODEFVAL "counter_type[3..0]"
// Retrieval info: USED_PORT: data_in 0 0 9 0 INPUT NODEFVAL "data_in[8..0]"
// Retrieval info: USED_PORT: data_out 0 0 9 0 OUTPUT NODEFVAL "data_out[8..0]"
// Retrieval info: USED_PORT: pll_areset 0 0 0 0 OUTPUT NODEFVAL "pll_areset"
// Retrieval info: USED_PORT: pll_areset_in 0 0 0 0 INPUT GND "pll_areset_in"
// Retrieval info: USED_PORT: pll_configupdate 0 0 0 0 OUTPUT NODEFVAL "pll_configupdate"
// Retrieval info: USED_PORT: pll_scanclk 0 0 0 0 OUTPUT NODEFVAL "pll_scanclk"
// Retrieval info: USED_PORT: pll_scanclkena 0 0 0 0 OUTPUT NODEFVAL "pll_scanclkena"
// Retrieval info: USED_PORT: pll_scandata 0 0 0 0 OUTPUT NODEFVAL "pll_scandata"
// Retrieval info: USED_PORT: pll_scandataout 0 0 0 0 INPUT NODEFVAL "pll_scandataout"
// Retrieval info: USED_PORT: pll_scandone 0 0 0 0 INPUT NODEFVAL "pll_scandone"
// Retrieval info: USED_PORT: read_param 0 0 0 0 INPUT NODEFVAL "read_param"
// Retrieval info: USED_PORT: reconfig 0 0 0 0 INPUT NODEFVAL "reconfig"
// Retrieval info: USED_PORT: reset 0 0 0 0 INPUT NODEFVAL "reset"
// Retrieval info: USED_PORT: reset_rom_address 0 0 0 0 INPUT GND "reset_rom_address"
// Retrieval info: USED_PORT: rom_address_out 0 0 8 0 OUTPUT NODEFVAL "rom_address_out[7..0]"
// Retrieval info: USED_PORT: rom_data_in 0 0 0 0 INPUT GND "rom_data_in"
// Retrieval info: USED_PORT: write_from_rom 0 0 0 0 INPUT GND "write_from_rom"
// Retrieval info: USED_PORT: write_param 0 0 0 0 INPUT NODEFVAL "write_param"
// Retrieval info: USED_PORT: write_rom_ena 0 0 0 0 OUTPUT NODEFVAL "write_rom_ena"
// Retrieval info: CONNECT: @clock 0 0 0 0 clock 0 0 0 0
// Retrieval info: CONNECT: @counter_param 0 0 3 0 counter_param 0 0 3 0
// Retrieval info: CONNECT: @counter_type 0 0 4 0 counter_type 0 0 4 0
// Retrieval info: CONNECT: @data_in 0 0 9 0 data_in 0 0 9 0
// Retrieval info: CONNECT: @pll_areset_in 0 0 0 0 pll_areset_in 0 0 0 0
// Retrieval info: CONNECT: @pll_scandataout 0 0 0 0 pll_scandataout 0 0 0 0
// Retrieval info: CONNECT: @pll_scandone 0 0 0 0 pll_scandone 0 0 0 0
// Retrieval info: CONNECT: @read_param 0 0 0 0 read_param 0 0 0 0
// Retrieval info: CONNECT: @reconfig 0 0 0 0 reconfig 0 0 0 0
// Retrieval info: CONNECT: @reset 0 0 0 0 reset 0 0 0 0
// Retrieval info: CONNECT: @reset_rom_address 0 0 0 0 reset_rom_address 0 0 0 0
// Retrieval info: CONNECT: @rom_data_in 0 0 0 0 rom_data_in 0 0 0 0
// Retrieval info: CONNECT: @write_from_rom 0 0 0 0 write_from_rom 0 0 0 0
// Retrieval info: CONNECT: @write_param 0 0 0 0 write_param 0 0 0 0
// Retrieval info: CONNECT: busy 0 0 0 0 @busy 0 0 0 0
// Retrieval info: CONNECT: data_out 0 0 9 0 @data_out 0 0 9 0
// Retrieval info: CONNECT: pll_areset 0 0 0 0 @pll_areset 0 0 0 0
// Retrieval info: CONNECT: pll_configupdate 0 0 0 0 @pll_configupdate 0 0 0 0
// Retrieval info: CONNECT: pll_scanclk 0 0 0 0 @pll_scanclk 0 0 0 0
// Retrieval info: CONNECT: pll_scanclkena 0 0 0 0 @pll_scanclkena 0 0 0 0
// Retrieval info: CONNECT: pll_scandata 0 0 0 0 @pll_scandata 0 0 0 0
// Retrieval info: CONNECT: rom_address_out 0 0 8 0 @rom_address_out 0 0 8 0
// Retrieval info: CONNECT: write_rom_ena 0 0 0 0 @write_rom_ena 0 0 0 0
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig_inst.v FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL pll_reconfig_bb.v TRUE
// Retrieval info: LIB_FILE: altera_mf
// Retrieval info: LIB_FILE: cyclone10lp
// Retrieval info: LIB_FILE: lpm