-- megafunction wizard: %ALTCLKCTRL%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altclkctrl 

-- ============================================================
-- File Name: clkctrl.vhd
-- Megafunction Name(s):
-- 			altclkctrl
--
-- Simulation Library Files(s):
-- 			cyclone10lp
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 22.1std.2 Build 922 07/20/2023 SC Lite Edition
-- ************************************************************


--Copyright (C) 2023  Intel Corporation. All rights reserved.
--Your use of Intel Corporation's design tools, logic functions 
--and other software and tools, and any partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Intel Program License 
--Subscription Agreement, the Intel Quartus Prime License Agreement,
--the Intel FPGA IP License Agreement, or other applicable license
--agreement, including, without limitation, that your use is for
--the sole purpose of programming logic devices manufactured by
--Intel and sold by Intel or its authorized distributors.  Please
--refer to the applicable agreement for further details, at
--https://fpgasoftware.intel.com/eula.


--altclkctrl CBX_AUTO_BLACKBOX="ALL" CLOCK_TYPE="Global Clock" DEVICE_FAMILY="Cyclone 10 LP" ENA_REGISTER_MODE="falling edge" USE_GLITCH_FREE_SWITCH_OVER_IMPLEMENTATION="OFF" clkselect ena inclk outclk
--VERSION_BEGIN 22.1 cbx_altclkbuf 2023:07:20:14:03:03:SC cbx_cycloneii 2023:07:20:14:03:03:SC cbx_lpm_add_sub 2023:07:20:14:03:03:SC cbx_lpm_compare 2023:07:20:14:03:03:SC cbx_lpm_decode 2023:07:20:14:03:02:SC cbx_lpm_mux 2023:07:20:14:03:03:SC cbx_mgl 2023:07:20:14:14:26:SC cbx_nadder 2023:07:20:14:03:03:SC cbx_stratix 2023:07:20:14:03:03:SC cbx_stratixii 2023:07:20:14:03:03:SC cbx_stratixiii 2023:07:20:14:03:03:SC cbx_stratixv 2023:07:20:14:03:03:SC  VERSION_END

 LIBRARY cyclone10lp;
 USE cyclone10lp.all;

--synthesis_resources = clkctrl 1 
 LIBRARY ieee;
 USE ieee.std_logic_1164.all;

 ENTITY  clkctrl_altclkctrl_0ji IS 
	 PORT 
	 ( 
		 clkselect	:	IN  STD_LOGIC_VECTOR (1 DOWNTO 0) := (OTHERS => '0');
		 ena	:	IN  STD_LOGIC := '1';
		 inclk	:	IN  STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
		 outclk	:	OUT  STD_LOGIC
	 ); 
 END clkctrl_altclkctrl_0ji;

 ARCHITECTURE RTL OF clkctrl_altclkctrl_0ji IS

	 SIGNAL  wire_clkctrl1_outclk	:	STD_LOGIC;
	 SIGNAL  clkselect_wire :	STD_LOGIC_VECTOR (1 DOWNTO 0);
	 SIGNAL  inclk_wire :	STD_LOGIC_VECTOR (3 DOWNTO 0);
	 COMPONENT  cyclone10lp_clkctrl
	 GENERIC 
	 (
		clock_type	:	STRING;
		ena_register_mode	:	STRING := "falling edge";
		lpm_type	:	STRING := "cyclone10lp_clkctrl"
	 );
	 PORT
	 ( 
		clkselect	:	IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		ena	:	IN STD_LOGIC;
		inclk	:	IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		outclk	:	OUT STD_LOGIC
	 ); 
	 END COMPONENT;
 BEGIN

	clkselect_wire <= ( clkselect);
	inclk_wire <= ( inclk);
	outclk <= wire_clkctrl1_outclk;
	clkctrl1 :  cyclone10lp_clkctrl
	  GENERIC MAP (
		clock_type => "Global Clock",
		ena_register_mode => "falling edge"
	  )
	  PORT MAP ( 
		clkselect => clkselect_wire,
		ena => ena,
		inclk => inclk_wire,
		outclk => wire_clkctrl1_outclk
	  );

 END RTL; --clkctrl_altclkctrl_0ji
--VALID FILE


LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY clkctrl IS
	PORT
	(
		ena		: IN STD_LOGIC  := '1';
		inclk		: IN STD_LOGIC ;
		outclk		: OUT STD_LOGIC 
	);
END clkctrl;


ARCHITECTURE RTL OF clkctrl IS

	SIGNAL sub_wire0	: STD_LOGIC ;
	SIGNAL sub_wire1_bv	: BIT_VECTOR (1 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (1 DOWNTO 0);
	SIGNAL sub_wire2	: STD_LOGIC ;
	SIGNAL sub_wire3	: STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL sub_wire4_bv	: BIT_VECTOR (2 DOWNTO 0);
	SIGNAL sub_wire4	: STD_LOGIC_VECTOR (2 DOWNTO 0);



	COMPONENT clkctrl_altclkctrl_0ji
	PORT (
			clkselect	: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
			ena	: IN STD_LOGIC ;
			inclk	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			outclk	: OUT STD_LOGIC 
	);
	END COMPONENT;

BEGIN
	sub_wire1_bv(1 DOWNTO 0) <= "00";
	sub_wire1    <= To_stdlogicvector(sub_wire1_bv);
	sub_wire4_bv(2 DOWNTO 0) <= "000";
	sub_wire4    <= To_stdlogicvector(sub_wire4_bv);
	outclk    <= sub_wire0;
	sub_wire2    <= inclk;
	sub_wire3    <= sub_wire4(2 DOWNTO 0) & sub_wire2;

	clkctrl_altclkctrl_0ji_component : clkctrl_altclkctrl_0ji
	PORT MAP (
		clkselect => sub_wire1,
		ena => ena,
		inclk => sub_wire3,
		outclk => sub_wire0
	);



END RTL;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone 10 LP"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: clock_inputs NUMERIC "1"
-- Retrieval info: CONSTANT: ENA_REGISTER_MODE STRING "falling edge"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone 10 LP"
-- Retrieval info: CONSTANT: USE_GLITCH_FREE_SWITCH_OVER_IMPLEMENTATION STRING "OFF"
-- Retrieval info: CONSTANT: clock_type STRING "Global Clock"
-- Retrieval info: USED_PORT: ena 0 0 0 0 INPUT VCC "ena"
-- Retrieval info: USED_PORT: inclk 0 0 0 0 INPUT NODEFVAL "inclk"
-- Retrieval info: USED_PORT: outclk 0 0 0 0 OUTPUT NODEFVAL "outclk"
-- Retrieval info: CONNECT: @clkselect 0 0 2 0 GND 0 0 2 0
-- Retrieval info: CONNECT: @ena 0 0 0 0 ena 0 0 0 0
-- Retrieval info: CONNECT: @inclk 0 0 3 1 GND 0 0 3 0
-- Retrieval info: CONNECT: @inclk 0 0 1 0 inclk 0 0 0 0
-- Retrieval info: CONNECT: outclk 0 0 0 0 @outclk 0 0 0 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL clkctrl_inst.vhd FALSE
-- Retrieval info: LIB_FILE: cyclone10lp