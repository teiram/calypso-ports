-------------------------------------------------------------------------------
--
-- MSX1 FPGA project
--
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
--
-- TOP created by Victor Trucco (c) 2018
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.msx_pack.all;

entity Mist_top is
	port (
		-- Clocks
--		clock_50_i			: in    std_logic;

		clock_sdram_s		: in 		std_logic;
		clock_master_s		: in 		std_logic;
		clock_vga_s			: in 		std_logic;
		pll_locked_s		: in 		std_logic;
		reset					: in 		std_logic;
		soft_reset_osd    : in     std_logic;
		-- F18A
		clk_100_i         : in std_logic;
		clk_25_i          : in std_logic;
	   sprite_max_i      : in std_logic;
	   scan_lines_i      : in std_logic;

		-- Buttons
		btn_n_i				: in    std_logic_vector(4 downto 1)	:= (others => '1');

		-- SRAM (AS7C34096)
--		sram_addr_o			: out   std_logic_vector(18 downto 0)	:= (others => '0');
--		sram_data_io		: inout std_logic_vector( 7 downto 0)	:= (others => 'Z');
--		sram_we_n_o			: out   std_logic								:= '1';
--		sram_oe_n_o			: out   std_logic								:= '1';

		-- SDRAM	(H57V256 = 16Mx16 = 32MB)
		sdram_clk_o			: out   std_logic								:= '0';
		sdram_cke_o			: out   std_logic								:= '0';
		sdram_ad_o			: out   std_logic_vector(12 downto 0)	:= (others => '0');
		sdram_da_io			: inout std_logic_vector(15 downto 0)	:= (others => 'Z');
		sdram_ba_o			: out   std_logic_vector( 1 downto 0)	:= (others => '0');
		sdram_dqm_o			: out   std_logic_vector( 1 downto 0)	:= (others => '1');
		sdram_ras_o			: out   std_logic								:= '1';
		sdram_cas_o			: out   std_logic								:= '1';
		sdram_cs_o			: out   std_logic								:= '1';
		sdram_we_o			: out   std_logic								:= '1';
		sdram_ready			: out   std_logic								:= '0'; --sdram mister

		-- PS2
--		ps2_clk_io			: inout std_logic								:= 'Z';
--		ps2_data_io			: inout std_logic								:= 'Z';
		ps2_clk_i			: inout std_logic;--								:= 'Z';
		ps2_data_i			: inout std_logic;--								:= 'Z';
		ps2_clk_o			: inout std_logic;--								:= 'Z';
		ps2_data_o			: inout std_logic;--								:= 'Z';
		ps2_mouse_clk_io  : inout std_logic								:= 'Z';
		ps2_mouse_data_io : inout std_logic								:= 'Z';

		-- SD Card
		sd_cs_n_o			: out   std_logic								:= '1';
		sd_sclk_o			: out   std_logic								:= '0';
		sd_mosi_o			: out   std_logic								:= '0';
		sd_miso_i			: in    std_logic;
      sd_pres_n_i       : in    std_logic;
		-- Joysticks
		joy1_up_i			: in    std_logic								:= '0';
		joy1_down_i			: in    std_logic								:= '0';
		joy1_left_i			: in    std_logic								:= '0';
		joy1_right_i		: in    std_logic								:= '0';
		joy1_p6_i			: in    std_logic								:= '0';
		joy1_p9_i			: in    std_logic								:= '0';
		joy2_up_i			: in    std_logic								:= '0';
		joy2_down_i			: in    std_logic								:= '0';
		joy2_left_i			: in    std_logic								:= '0';
		joy2_right_i		: in    std_logic								:= '0';
		joy2_p6_i			: in    std_logic								:= '0';
		joy2_p9_i			: in    std_logic								:= '0';
		joyX_p7_o			: out   std_logic								:= '1';

		-- Audio
		dac_l_o				: out   std_logic								:= '0';
		dac_r_o				: out   std_logic								:= '0';
		PreDac_l_s			: out   std_logic_vector(15 downto 0);
		PreDac_r_s			: out   std_logic_vector(15 downto 0);
		ear_i					: in    std_logic;
		mic_o					: out   std_logic								:= '0';

		-- VGA
		vga_r_o				: out   std_logic_vector(3 downto 0)	:= (others => '0');
		vga_g_o				: out   std_logic_vector(3 downto 0)	:= (others => '0');
		vga_b_o				: out   std_logic_vector(3 downto 0)	:= (others => '0');
		vga_hsync_n_o		: out   std_logic;
		vga_vsync_n_o		: out   std_logic;
		vga_blank			: out	  std_logic;
		HBlank  			   : out	  std_logic;
		VBlank			   : out	  std_logic;
		vga_DE				: out	  std_logic;
        
        f18a_i              : in std_logic
		
		-- HDMI
--		tmds_o				: out   std_logic_vector(7 downto 0)	:= (others => '0');

		--STM32
--		stm_rx_o				: out   std_logic		:= 'Z'; -- stm RX pin, so, is OUT on the slave
--		stm_tx_i				: in    std_logic		:= 'Z'; -- stm TX pin, so, is IN on the slave
--		stm_rst_o			: out   std_logic		:= '0'; -- '0' to hold the microcontroller reset line, to free the SD card
--		stm_a15_io			: inout std_logic;
--		stm_b8_io			: inout std_logic		:= 'Z';
--		stm_b9_io			: inout std_logic		:= 'Z';
--		stm_b12_io			: inout std_logic		:= 'Z';
--		stm_b13_io			: inout std_logic		:= 'Z';
--		stm_b14_io			: inout std_logic		:= 'Z';
--		stm_b15_io			: inout std_logic		:= 'Z'
	);
end entity;

architecture behavior of Mist_top is



--  	component sdramMister
--	port (
--		init			: in    std_logic;
--		clk			: in    std_logic;
--
----		refresh_i	=> '1',
--
--		SDRAM_DQ		: inout std_logic_vector(15 downto 0);
--		SDRAM_A		: out   std_logic_vector(12 downto 0);
--		SDRAM_DQML	: out   std_logic;
--		SDRAM_DQMH	: out   std_logic;
--		SDRAM_BA		: out   std_logic_vector( 1 downto 0);
--		SDRAM_nCS	: out   std_logic;
--		SDRAM_nWE	: out   std_logic;
--		SDRAM_nRAS	: out   std_logic;
--		SDRAM_nCAS	: out   std_logic;
--		SDRAM_CKE	: out   std_logic;		
--		SDRAM_CLK	: out   std_logic;
--
--
--		-- Static RAM bus
--		addr			: in    std_logic_vector(24 downto 0);		-- 32MB
--		dout			: out   std_logic_vector( 7 downto 0);
--		din			: in    std_logic_vector( 7 downto 0);
----		cs_i			=> ram_ce_s,
--		we				: in    std_logic;
--		rd				: in    std_logic;
--		ready			: buffer   std_logic
--		
--
--      );
--  end component;

  

	-- Buttons
	signal btn_por_n_s		: std_logic;
	signal btn_reset_n_s		: std_logic;
	signal btn_scan_s			: std_logic;

	-- Resets
--	signal pll_locked_s		: std_logic;
	signal por_s				: std_logic;
	signal reset_s				: std_logic;
	signal soft_reset_k_s	: std_logic;
	signal soft_reset_s_s	: std_logic;
	signal soft_por_s			: std_logic;
	signal soft_rst_cnt_s	: unsigned(7 downto 0)	:= X"FF";

	-- Clocks
--	signal clock_sdram_s		: std_logic;
--	signal clock_master_s	: std_logic;
	signal clock_vdp_s		: std_logic;
	signal clock_cpu_s		: std_logic;
	signal clock_psg_en_s	: std_logic;
	signal clock_3m_s			: std_logic;
	signal turbo_on_s			: std_logic;
--	signal clock_vga_s		: std_logic;
	signal clock_dvi_s		: std_logic;
	signal clock_vga2x_s		: std_logic;

	-- RAM
	signal ram_addr_s			: std_logic_vector(22 downto 0);		-- 8MB
	signal ram_data_from_s	: std_logic_vector( 7 downto 0);
	signal ram_data_to_s		: std_logic_vector( 7 downto 0);
	signal ram_ce_s			: std_logic;
	signal ram_oe_s			: std_logic;
	signal ram_we_s			: std_logic;

	-- VRAM memory
	signal vram_addr_s		: std_logic_vector(13 downto 0);		-- 16K
	signal vram_do_s			: std_logic_vector( 7 downto 0);
	signal vram_di_s			: std_logic_vector( 7 downto 0);
	signal vram_ce_s			: std_logic;
	signal vram_oe_s			: std_logic;
	signal vram_we_s			: std_logic;

	-- Audio
	signal audio_scc_s		: signed(14 downto 0);
	signal audio_psg_s		: unsigned( 7 downto 0);
	signal beep_s				: std_logic;
	signal audio_l_s			: unsigned(15 downto 0);
	signal audio_r_s			: unsigned(15 downto 0);
	signal audio_l_amp_s		: unsigned(15 downto 0);
	signal audio_r_amp_s		: unsigned(15 downto 0);
	signal volumes_s			: volumes_t;

	-- Video
--	signal rgb_col_s			: std_logic_vector( 3 downto 0);
--	signal cnt_hor_s			: std_logic_vector( 8 downto 0);
--	signal cnt_ver_s			: std_logic_vector( 7 downto 0);
--	signal vga_hsync_n_s		: std_logic;
--	signal vga_vsync_n_s		: std_logic;
--	signal vga_blank_s		: std_logic;
--	signal vga_hblank_s		: std_logic;
--	signal vga_vblank_s		: std_logic;
--	signal vga_DE_s			: std_logic;
--	signal vga_col_s			: std_logic_vector( 3 downto 0);
--	signal vga_r_s				: std_logic_vector( 3 downto 0);
--	signal vga_g_s				: std_logic_vector( 3 downto 0);
--	signal vga_b_s				: std_logic_vector( 3 downto 0);
--	signal scanlines_en_s	: std_logic;
--	signal odd_line_s			: std_logic;
--	signal sound_hdmi_l_s	: std_logic_vector(15 downto 0);
--	signal sound_hdmi_r_s	: std_logic_vector(15 downto 0);
--	signal tdms_r_s			: std_logic_vector( 9 downto 0);
--	signal tdms_g_s			: std_logic_vector( 9 downto 0);
--	signal tdms_b_s			: std_logic_vector( 9 downto 0);
--	signal tdms_p_s			: std_logic_vector( 3 downto 0);
--	signal tdms_n_s			: std_logic_vector( 3 downto 0);

	-- Keyboard
	signal rows_s				: std_logic_vector( 3 downto 0);
	signal cols_s				: std_logic_vector( 7 downto 0);
	signal caps_en_s			: std_logic;
	signal extra_keys_s		: std_logic_vector( 3 downto 0);
	signal keyb_valid_s		: std_logic;
	signal keyb_data_s		: std_logic_vector( 7 downto 0);
	signal keymap_addr_s		: std_logic_vector( 8 downto 0);
	signal keymap_data_s		: std_logic_vector( 7 downto 0);
	signal keymap_we_s		: std_logic;

	-- Joystick
	signal joy1_out_s			: std_logic;
	signal joy2_out_s			: std_logic;

	-- Bus
	signal bus_addr_s			: std_logic_vector(15 downto 0);
	signal bus_data_from_s	: std_logic_vector( 7 downto 0)	:= (others => '1');
	signal bus_data_to_s		: std_logic_vector( 7 downto 0);
	signal bus_rd_n_s			: std_logic;
	signal bus_wr_n_s			: std_logic;
	signal bus_m1_n_s			: std_logic;
	signal bus_iorq_n_s		: std_logic;
	signal bus_mreq_n_s		: std_logic;
	signal bus_sltsl1_n_s	: std_logic;
	signal bus_sltsl2_n_s	: std_logic;
	signal bus_int_n_s		: std_logic;
	signal bus_wait_n_s		: std_logic;

	-- JT51
	signal jt51_cs_n_s		: std_logic;
	signal jt51_data_from_s	: std_logic_vector( 7 downto 0)	:= (others => '1');
	signal jt51_hd_s			: std_logic								:= '0';
	signal jt51_left_s		: signed(15 downto 0)				:= (others => '0');
	signal jt51_right_s		: signed(15 downto 0)				:= (others => '0');
		
	-- OPLL
	signal opll_cs_n_s		: std_logic							:= '1';
	signal opll_mo_s			: signed(12 downto 0)			:= (others => '0');
	signal opll_ro_s			: signed(12 downto 0)			:= (others => '0');

	signal Go					: std_logic := '0';
    
    --F18a
    signal f18a_tile_active_s : std_logic;
    signal f18a_tile_addr_s : std_logic_vector(0 to 13);
    signal f18a_tile_dout_s : std_logic_vector(0 to 7);
    signal f18a_sprt_addr_s : std_logic_vector(0 to 13);
    
    signal vram_clk_s: std_logic;
	
begin



	-- Clocks
	clks: entity work.clocks
	port map (
		clock_i			=> clock_master_s,
		por_i				=> not pll_locked_s,
		turbo_on_i		=> turbo_on_s,
		clock_vdp_o		=> clock_vdp_s,
		clock_5m_en_o	=> open,
		clock_cpu_o		=> clock_cpu_s,
		clock_psg_en_o	=> clock_psg_en_s,
		clock_3m_o		=> clock_3m_s
	);

	-- The MSX1
	the_msx: entity work.msx
	generic map (
		hw_id_g			=> 8,  -- 10 Mister, 8 Mist
		hw_txt_g			=> "Calypso",
		hw_version_g	=> actual_version,
		video_opt_g		=> 0,				
		ramsize_g		=> 8192, --8192,
		hw_hashwds_g	=> '0'  --0->Nextor.rom, 1->NextorH.rom ; Por cambios en el driver de Nextor pasan a ser iguales
	)
	port map (
		-- Clocks
		clock_i			=> clock_master_s,
		clock_vdp_i		=> clock_vdp_s,
		clock_cpu_i		=> clock_cpu_s,
		clock_psg_en_i	=> clock_psg_en_s,
		-- Turbo
		turbo_on_k_i	=> extra_keys_s(3),	-- F11
		turbo_on_o		=> turbo_on_s,
		-- Resets
		reset_i			=> reset_s,
		por_i				=> por_s,
		softreset_o		=> soft_reset_s_s,
		-- Options
		opt_nextor_i	=> '1',
		opt_mr_type_i	=> "00",
		opt_vga_on_i	=> '1',
		-- RAM
		ram_addr_o		=> ram_addr_s,
		ram_data_i		=> ram_data_from_s,
		ram_data_o		=> ram_data_to_s,
		ram_ce_o			=> ram_ce_s,
		ram_we_o			=> ram_we_s,
		ram_oe_o			=> ram_oe_s,
		-- ROM
		rom_addr_o		=> open,
		rom_data_i		=> ram_data_from_s,
		rom_ce_o			=> open,
		rom_oe_o			=> open,
		-- External bus
		bus_addr_o		=> bus_addr_s,
		bus_data_i		=> bus_data_from_s,
		bus_data_o		=> bus_data_to_s,
		bus_rd_n_o		=> bus_rd_n_s,
		bus_wr_n_o		=> bus_wr_n_s,
		bus_m1_n_o		=> bus_m1_n_s,
		bus_iorq_n_o	=> bus_iorq_n_s,
		bus_mreq_n_o	=> bus_mreq_n_s,
		bus_sltsl1_n_o	=> bus_sltsl1_n_s,
		bus_sltsl2_n_o	=> bus_sltsl2_n_s,
		bus_wait_n_i	=> bus_wait_n_s,
		bus_nmi_n_i		=> '1',
		bus_int_n_i		=> bus_int_n_s,
				-- F18A
		clk_100_i      => clk_100_i,
		clk_25_i       => clk_25_i,
	   sprite_max_i   => sprite_max_i,
	   scan_lines_i   => scan_lines_i,


		-- Keyboard
		rows_o			=> rows_s,
		cols_i			=> cols_s,
		caps_en_o		=> caps_en_s,
		keyb_valid_i	=> keyb_valid_s,
		keyb_data_i		=> keyb_data_s,
		keymap_addr_o	=> keymap_addr_s,
		keymap_data_o	=> keymap_data_s,
		keymap_we_o		=> keymap_we_s,
		-- Audio
		audio_scc_o		=> audio_scc_s,
		audio_psg_o		=> audio_psg_s,
		beep_o			=> beep_s,
		volumes_o		=> volumes_s,
		-- K7
		k7_motor_o		=> open,
		k7_audio_o		=> mic_o,
		k7_audio_i		=> ear_i,
		-- Joystick
		joy1_up_i		=> joy1_up_i,
		joy1_down_i		=> joy1_down_i,
		joy1_left_i		=> joy1_left_i,
		joy1_right_i	=> joy1_right_i,
		joy1_btn1_i		=> joy1_p6_i,
		joy1_btn1_o		=> open,
		joy1_btn2_i		=> joy1_p9_i,
		joy1_btn2_o		=> open,
		joy1_out_o		=> joy1_out_s,
		joy2_up_i		=> joy2_up_i,
		joy2_down_i		=> joy2_down_i,
		joy2_left_i		=> joy2_left_i,
		joy2_right_i	=> joy2_right_i,
		joy2_btn1_i		=> joy2_p6_i,
		joy2_btn1_o		=> open,
		joy2_btn2_i		=> joy2_p9_i,
		joy2_btn2_o		=> open,
		joy2_out_o		=> joy2_out_s,
		-- Video

		rgb_r_o			=> vga_r_o,
		rgb_g_o			=> vga_g_o,
		rgb_b_o			=> vga_b_o,
		hsync_n_o		=> vga_hsync_n_o,
		vsync_n_o		=> vga_vsync_n_o,
		hblank_o       => HBlank,
		vblank_o       => VBlank,
		ntsc_pal_o		=> open,
		vga_on_k_i		=> '0',
		scanline_on_k_i=> '0',
		vga_en_o			=> open,
		-- SPI/SD
		spi_cs_n_o		=> sd_cs_n_o,
		spi_sclk_o		=> sd_sclk_o,
		spi_mosi_o		=> sd_mosi_o,
		spi_miso_i		=> sd_miso_i,
		sd_pres_n_i		=> sd_pres_n_i,  --Sd Presente/Insertada
		sd_wp_i			=> '0',  --Write Protect
		-- DEBUG
		D_wait_o			=> open,
		D_slots_o		=> open,
		D_ipl_en_o		=> open,
        
        vram_addr_o => vram_addr_s,         -- out std_logic_vector(13 downto 0)
        vram_data_i => vram_di_s,           -- in  std_logic_vector( 7 downto 0)
        vram_data_o => vram_do_s,           -- out std_logic_vector( 7 downto 0)
        vram_ce_o =>   vram_ce_s,           -- out std_logic
        vram_oe_o => vram_oe_s,             -- out std_logic
        vram_we_o => vram_we_s,             -- out std_logic
        f18a_i => f18a_i,
        f18a_tile_active_o => f18a_tile_active_s,
        f18a_tile_addr_o => f18a_tile_addr_s,
        f18a_tile_dout_i => f18a_tile_dout_s,
        f18a_sprt_addr_o => f18a_sprt_addr_s

	);

	joyX_p7_o <= not joy1_out_s;		-- for Sega Genesis joypad
	

    vram_clk_s <= clk_100_i when f18a_i = '1' else clock_master_s;
    
vram: entity work.f18a_vram
    port map(
        clk => vram_clk_s,
        cpu_din => vram_do_s,
        cpu_dout => vram_di_s,
        cpu_addr => vram_addr_s,
        cpu_we => vram_we_s,
        tile_active => f18a_tile_active_s,
        tile_addr => f18a_tile_addr_s,
        tile_dout => f18a_tile_dout_s,
        sprt_addr => f18a_sprt_addr_s
    );

ram: entity work.ssdram
        generic map (
                freq_g          => 86
        )
        port map (
                clock_i         => clock_sdram_s,
                reset_i         => reset_s,
                refresh_i       => '1',
                -- Static RAM bus
                addr_i          => ram_addr_s,
                data_i          => ram_data_to_s,
                data_o          => ram_data_from_s,
                cs_i                    => ram_ce_s,
                oe_i                    => ram_oe_s,
                we_i                    => ram_we_s,
                -- SD-RAM ports
                mem_cke_o       => sdram_cke_o,
                mem_cs_n_o      => sdram_cs_o,
                mem_ras_n_o     => sdram_ras_o,
                mem_cas_n_o     => sdram_cas_o,
                mem_we_n_o      => sdram_we_o,
                mem_udq_o       => sdram_dqm_o(1),
                mem_ldq_o       => sdram_dqm_o(0),
                mem_ba_o                => sdram_ba_o,
                mem_addr_o      => sdram_ad_o(11 downto 0),
                mem_data_io     => sdram_da_io                

        );
	

	-- Keyboard PS/2
	keyb: entity work.keyboard
	port map (
		clock_i			=> clock_3m_s,
		reset_i			=> reset_s,
		-- MSX
		rows_coded_i	=> rows_s,
		cols_o			=> cols_s,
		keymap_addr_i	=> keymap_addr_s,
		keymap_data_i	=> keymap_data_s,
		keymap_we_i		=> keymap_we_s,
		-- LEDs
		led_caps_i		=> caps_en_s,
		-- PS/2 interface
--		ps2_clk_io		=> ps2_clk_io,
--		ps2_data_io		=> ps2_data_io,
		ps2_clk_i		=> ps2_clk_i,
		ps2_data_i		=> ps2_data_i,
		ps2_clk_o		=> ps2_clk_o,
		ps2_data_o		=> ps2_data_o,
		-- Direct Access
		keyb_valid_o	=> keyb_valid_s,
		keyb_data_o		=> keyb_data_s,
		--
		reset_o			=> soft_reset_k_s,
		por_o				=> soft_por_s,
		reload_core_o	=> open,
		extra_keys_o	=> extra_keys_s
	);

	-- Audio
	mixer: entity work.mixeru
	port map (
		clock_i			=> clock_master_s,
		reset_i			=> reset_s,
		volumes_i		=> volumes_s,
		beep_i			=> beep_s,
		ear_i				=> ear_i,
		audio_scc_i		=> audio_scc_s,
		audio_psg_i		=> audio_psg_s,
		jt51_left_i		=> jt51_left_s,
		jt51_right_i	=> jt51_right_s,
		opll_mo_i		=> opll_mo_s,
		opll_ro_i		=> opll_ro_s,
		audio_mix_l_o	=> audio_l_s,
		audio_mix_r_o	=> audio_r_s
	);

	audio_l_amp_s	<= audio_l_s(15) & audio_l_s(13 downto 0) & "0";
	audio_r_amp_s	<= audio_r_s(15) & audio_r_s(13 downto 0) & "0";
	PreDac_l_s		<= std_logic_vector(audio_l_s);
	PreDac_r_s		<= std_logic_vector(audio_r_s);


	-- Glue logic

	-- Resets
	btn_por_n_s		<= btn_n_i(2) or btn_n_i(4);
	btn_reset_n_s	<= btn_n_i(3) or btn_n_i(4);

	por_s			<= '1'	when pll_locked_s = '0' or soft_por_s = '1' or btn_por_n_s = '0' 		or reset = '1'	else '0';
	reset_s		<= '1'	when soft_rst_cnt_s = X"01"                 or btn_reset_n_s = '0'		else '0';


	process(reset_s, clock_master_s)
	begin
		if reset_s = '1' then
			soft_rst_cnt_s	<= X"00";
		elsif rising_edge(clock_master_s) then
			if (soft_reset_k_s = '1' or soft_reset_s_s = '1' or por_s = '1' or soft_reset_osd = '1') and soft_rst_cnt_s = X"00" then
				soft_rst_cnt_s	<= X"FF";
			elsif soft_rst_cnt_s /= X"00" then
				soft_rst_cnt_s <= soft_rst_cnt_s - 1;
			end if;
		end if;
	end process;

	---------------------------------
	-- scanlines
	btnscl: entity work.debounce
	generic map (
		counter_size_g	=> 16
	)
	port map (
		clk_i				=> clock_master_s,
		button_i			=> btn_n_i(1) or btn_n_i(2),
		result_o			=> btn_scan_s
	);




	-- Peripheral BUS control
	bus_data_from_s	<= jt51_data_from_s	when jt51_hd_s = '1'	else
--							   midi_data_from_s	when midi_hd_s = '1'	else
								(others => '1');
	bus_wait_n_s	<= '1';--midi_wait_n_s;
	bus_int_n_s		<= '1';--midi_int_n_s;

	-- JT51
	jt51_cs_n_s <= '0' when bus_addr_s(7 downto 1) = "0010000" and bus_iorq_n_s = '0' and bus_m1_n_s = '1'	else '1';	-- 0x20 - 0x21

	jt51: entity work.jt51_wrapper
	port map (
		clock_i			=> clock_3m_s,
		reset_i			=> reset_s,
		addr_i			=> bus_addr_s(0),
		cs_n_i			=> jt51_cs_n_s,
		wr_n_i			=> bus_wr_n_s,
		rd_n_i			=> bus_rd_n_s,
		data_i			=> bus_data_to_s,
		data_o			=> jt51_data_from_s,
		has_data_o		=> jt51_hd_s,
		ct1_o				=> open,
		ct2_o				=> open,
		irq_n_o			=> open,
		p1_o				=> open,
		-- Low resolution output (same as real chip)
		sample_o			=> open,
		left_o			=> open,
		right_o			=> open,
		-- Full resolution output
		xleft_o			=> jt51_left_s,
		xright_o			=> jt51_right_s,
		-- unsigned outputs for sigma delta converters, full resolution		
		dacleft_o		=> open,
		dacright_o		=> open
	);

	-- OPLL
	opll_cs_n_s	<= '0' when bus_addr_s(7 downto 1) = "0111110" and bus_iorq_n_s = '0' and bus_m1_n_s = '1'	else '1';	-- 0x7C - 0x7D

	opll1 : entity work.opll 
	port map (
		clock_i		=> clock_master_s,
		clock_en_i	=> clock_psg_en_s,
		reset_i		=> reset_s,
		data_i		=> bus_data_to_s,
		addr_i		=> bus_addr_s(0),
		cs_n        => opll_cs_n_s,
		we_n        => bus_wr_n_s,
		melody_o		=> opll_mo_s,
		rythm_o		=> opll_ro_s
	);

		-- MIDI
--	midi_cs_n_s	<= '0' when bus_addr_s(7 downto 1) = "0111111" and bus_iorq_n_s = '0' and bus_m1_n_s = '1'	else '1';	-- 0x7E - 0x7F

	-- MIDI interface
--	midi: entity work.midiIntf
--	port map (
--		clock_i			=> clock_8m_s,
--		reset_i			=> reset_s,
--		addr_i			=> bus_addr_s(0),
--		cs_n_i			=> midi_cs_n_s,
--		wr_n_i			=> bus_wr_n_s,
--		rd_n_i			=> bus_rd_n_s,
--		data_i			=> bus_data_to_s,
--		data_o			=> midi_data_from_s,
--		has_data_o		=> midi_hd_s,
--		-- Outs
--		int_n_o			=> midi_int_n_s,
--		wait_n_o			=> midi_wait_n_s,
--		tx_o				=> uart_tx_o
--	);

	-- DEBUG
--	leds_n_o(0)		<= not turbo_on_s;
--	leds_n_o(1)		<= not caps_en_s;
--	leds_n_o(2)		<= not soft_reset_k_s;
--	leds_n_o(3)		<= not soft_por_s;

end architecture;