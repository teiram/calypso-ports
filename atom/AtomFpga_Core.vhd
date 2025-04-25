 --------------------------------------------------------------------------------
-- Copyright (c) 2019 David Banks
--
-- based on work by Alan Daly. Copyright(c) 2009. All rights reserved.
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : AtomFpga_Core
-- /___/   /\     Timestamp : 02/03/2013 06:17:50
-- \   \  /  \
--  \___\/\___\
--
--Design Name: Atomic_top.vhf
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity AtomFpga_Core is
    port (
        -- Clocking
        clk_vid          : in    std_logic; -- nominally 25.175MHz VGA clock
        clk_vid_en       : in    std_logic; -- nominally 25.175MHz VGA clock
        clk_main         : in    std_logic; -- clock for the main system
        clk_dac          : in    std_logic; -- fast clock for the 1-bit DAC
		  clk_avr          : in    std_logic; -- clock for the AtoMMC AVR
        pixel_clock : out std_logic;
		  
        -- Keyboard/mouse
		  ps2_key			 : in 	std_logic_vector (10 downto 0);
		  layout				 : in    std_logic_vector(1 downto 0);
		  BLACK_BACKGND	 : in    std_logic;
		  computer 			 : in    std_logic;

        -- Resets
--        powerup_reset_n  : in    std_logic := '1'; -- power up reset only (optional)
        ext_reset_n      : in    std_logic := '1'; -- external bus reset (optional)

        -- Video
        red              : out   std_logic_vector (1 downto 0);
        green            : out   std_logic_vector (1 downto 0);
        blue             : out   std_logic_vector (1 downto 0);
        vsync            : out   std_logic;
        hsync            : out   std_logic;
        vblank           : out   std_logic;
		  hblank           : out   std_logic;
		  
        -- External 6502 bus interface
        ExternWE         : out   std_logic;
        ExternA          : out   std_logic_vector (17 downto 0);
        ExternDin        : out   std_logic_vector (7 downto 0);
        ExternDout       : in    std_logic_vector (7 downto 0);
		ExternROM			 : out   std_logic;
        cpuphi2          : out std_logic;
        -- Audio
        sid_audio_d      : out   std_logic_vector (17 downto 0);
        sid_audio        : out   std_logic;
        atom_audio       : out   std_logic;
		  
        -- SD Card
        SDMISO           : in    std_logic;
        SDSS             : out   std_logic;
        SDCLK            : out   std_logic;
        SDMOSI           : out   std_logic;
		  
        -- Serial
--        uart_RxD         : in    std_logic;
--        uart_TxD         : out   std_logic;

        -- Cassette
        cas_in           : in    std_logic := '0';
        cas_out          : out   std_logic;
		  
        -- Misc
        LED1             : out   std_logic;
        LED2             : out   std_logic;
        charSet          : in    std_logic;
        Joystick1        : in    std_logic_vector (15 downto 0) := (others => '1');
        Joystick2        : in    std_logic_vector (15 downto 0) := (others => '1');
		  
		  avr_TxD			 : out   std_logic;
		  avr_RxD			 : in 	std_logic
        );
		  
end AtomFpga_Core;

architecture BEHAVIORAL of AtomFpga_Core is

-------------------------------------------------
-- Clocks and enables
-------------------------------------------------
    signal clk_counter     : std_logic_vector(4 downto 0);
    signal cpu_clken       : std_logic;
    signal pia_clken       : std_logic;
    signal sample_data     : std_logic;
	 signal phi2				: std_logic;

-------------------------------------------------
-- CPU signals
-------------------------------------------------
    signal powerup_reset_n_sync 	: std_logic;
    signal ext_reset_n_sync     	: std_logic;
    signal RSTn              		: std_logic;
	 signal reset              	: std_logic;
    signal cpu_R_W_n         		: std_logic;
    signal not_cpu_R_W_n     		: std_logic;
    signal cpu_addr          		: std_logic_vector (15 downto 0);
    signal cpu_din           		: std_logic_vector (7 downto 0);
    signal cpu_dout          		: std_logic_vector (7 downto 0);


---------------------------------------------------
-- VDG signals
---------------------------------------------------
    signal vdg_fs_n        : std_logic;
	 signal vdg_hs_n        : std_logic;
    signal vdg_an_g        : std_logic;
	 signal vdg_an_s        : std_logic;
	 signal vdg_int_ex      : std_logic;
    signal vdg_gm          : std_logic_vector(2 downto 0);
    signal vdg_css         : std_logic;
	 signal vdg_inv         : std_logic;

	 signal char_d_o 			: std_logic_vector (7 downto 0);
	 signal char_do 			: std_logic_vector (7 downto 0);
	 signal charx_do 			: std_logic_vector (7 downto 0);
	 signal char_a 			: std_logic_vector (11 downto 0);
	 
    -- Set this to 0 if you want dark green/dark orange background on text
    -- Set this to 1 if you want black background on text (authentic Atom)
--    constant BLACK_BACKGND : std_logic := '1';

    signal clock_vga_en 	: std_logic := '0';
    
    -- VGA colour signals out of mc6847, only top 2 bits are used
    signal vga_red   	: std_logic_vector (7 downto 0);
    signal vga_green 	: std_logic_vector (7 downto 0);
    signal vga_blue  	: std_logic_vector (7 downto 0);
    signal vga_vsync 	: std_logic;
    signal vga_hsync 	: std_logic;
	 signal vga_vblank 	: std_logic;
	 signal vga_hblank 	: std_logic;
    signal vga_blank  	: std_logic;
	 
    -- 8Kx8 Dual port video RAM signals
    -- Port A connects to Atom and is read/write
    -- Port B connects to MC6847 and is read only
    signal vid_dout : std_logic_vector (7 downto 0);
    signal vid_addr : std_logic_vector (12 downto 0);
    signal vid_data : std_logic_vector (7 downto 0);

	     -- Colour palette registers
    signal logical_colour  : std_logic_vector(3 downto 0);
    signal physical_colour : std_logic_vector(5 downto 0);
	 
    type palette_type is array (0 to 15) of std_logic_vector(5 downto 0);

    signal palette : palette_type := (
        0  => "000000",
        1  => "000011",
        2  => "000100",
        3  => "000111",
        4  => "001000",
        5  => "001011",
        6  => "001100",
        7  => "001111",
        8  => "110000",
        9  => "110011",
        10 => "110100",
        11 => "110111",
        12 => "111000",
        13 => "111011",
        14 => "111100",
        15 => "111111"
        );

----------------------------------------------------
-- Device enables
----------------------------------------------------
    signal via_cs     	: std_logic;
    signal pia_cs      	: std_logic;
    signal ext_ram_cs 	: std_logic;
	 signal ext_rom_cs 	: std_logic;
    signal vid_cs  		: std_logic;
    signal sid_cs       : std_logic;
    signal video_ram_we : std_logic;
	 signal palette_cs	: std_logic;

----------------------------------------------------
-- External data
----------------------------------------------------
    signal ram_dout       	: std_logic_vector(7 downto 0);
	 signal sid_dout			: std_logic_vector(7 downto 0);

----------------------------------------------------
-- 6522 signals
----------------------------------------------------
    signal via4_clken        : std_logic;
    signal via1_clken        : std_logic;
    signal via_dout       : std_logic_vector(7 downto 0);
    signal mc6522_irq        : std_logic;
    signal mc6522_ca1        : std_logic;
    signal mc6522_ca2        : std_logic;
    signal mc6522_cb1        : std_logic;
    signal mc6522_cb2        : std_logic;
    signal mc6522_porta      : std_logic_vector(7 downto 0);
    signal mc6522_portb      : std_logic_vector(7 downto 0);

----------------------------------------------------
-- 8255 signals
----------------------------------------------------
    signal i8255_pa_data     : std_logic_vector(7 downto 0);
    signal i8255_pb_idata    : std_logic_vector(7 downto 0);
    signal i8255_pc_data     : std_logic_vector(7 downto 0);
    signal i8255_pc_idata    : std_logic_vector(7 downto 0);
    signal pia_dout          : std_logic_vector(7 downto 0);
    signal i8255_rd          : std_logic;

    signal ps2dataout        : std_logic_vector(5 downto 0);
    signal key_shift         : std_logic;
    signal key_ctrl          : std_logic;
    signal key_repeat        : std_logic;
    signal key_break         : std_logic;
    signal key_turbo         : std_logic_vector(1 downto 0);

    signal cas_divider       : std_logic_vector(15 downto 0);
    signal cas_tone          : std_logic;

--    signal turbo             : std_logic_vector(1 downto 0);
    signal turbo_synced      : std_logic_vector(1 downto 0);

----------------------------------------------------
-- AtoMMC signals
----------------------------------------------------

    signal pl8_cs       : std_logic;
	 signal spi_cs			: std_logic;
	 signal A000_cs		: std_logic;
	 signal RomLatch     : std_logic_vector (2 downto 0); 
	 signal BFFF_Enable : std_logic;    
    signal RegBFFF     : std_logic_vector (7 downto 0);
	 signal spi_dout     : std_logic_vector (7 downto 0);
    signal pl8_data     : std_logic_vector (7 downto 0);
    signal nARD         : std_logic;
    signal nAWR         : std_logic;
    signal AVRA0        : std_logic;
    signal AVRInt       : std_logic;
    signal AVRDataIn    : std_logic_vector (7 downto 0);
    signal AVRDataOut   : std_logic_vector (7 downto 0);
    signal ioport       : std_logic_vector (7 downto 0);
    signal LED1n        : std_logic;
    signal LED2n        : std_logic;

	 
    -- Internal 1MHz clocks for SID
 
    signal clk_sid_1MHz : std_logic;
	 
	 signal reset_vid : std_logic;

--------------------------------------------------------------------
--                   here it begin :)
--------------------------------------------------------------------

component keyboard 

        port(
            clk      	: in  std_logic;
				clk_en		: in  std_logic;
            reset    	: in  std_logic;
				layout		: in  std_logic_vector(1 downto 0);
				ps2_key		: in  std_logic_vector(10 downto 0);
				row			: in  std_logic_vector(3  downto 0);
				joy1			: in  std_logic_vector(15 downto 0);
				joy2			: in  std_logic_vector(15 downto 0);
            keyout   	: out std_logic_vector(5 downto 0);
            shift_out   : out std_logic;
            ctrl_out    : out std_logic;
				repeat_out	: out std_logic;
				break_out   : out std_logic;
				turbo			: out  std_logic_vector(1 downto 0)
            );
    end component;
	 
	 component sid6581
	 
		port(
			clk_1MHz 	: in  std_logic;
         clk32 		: in  std_logic;
         clk_DAC 		: in  std_logic;
         reset 		: in  std_logic;
         cs  			: in  std_logic;
         we  			: in  std_logic;
         addr  		: in  std_logic_vector(4 downto 0);
         di 			: in  std_logic_vector(7 downto 0);
         dout 			: out std_logic_vector(7 downto 0);
         pot_x 		: in  std_logic;
         pot_y 		: in  std_logic;
         audio_out 	: out std_logic;
         audio_data 	: out std_logic_vector(17 downto 0)
			);
    end component;
		


begin

---------------------------------------------------------------------
-- 6502 CPU (using T65 core)
---------------------------------------------------------------------
    cpu : entity work.T65 port map (
        Mode           => "00",
        Abort_n        => '1',
        SO_n           => '1',
        Res_n          => RSTn,
        Enable         => cpu_clken,
        Clk            => clk_main,
        Rdy            => '1',
        IRQ_n          => mc6522_irq,
        NMI_n          => '1',
        R_W_n          => cpu_R_W_n,
        Sync           => open,
        A(23 downto 16) => open,
        A(15 downto 0) => cpu_addr(15 downto 0),
        DI(7 downto 0) => cpu_din(7 downto 0),
        DO(7 downto 0) => cpu_dout(7 downto 0));

    not_cpu_R_W_n <= not cpu_R_W_n;
	 
    -- reset logic
	 process (clk_main) 
	 begin
	 if rising_edge(clk_main) then
		RSTn			<= key_break and ext_reset_n;
	end if;
	end process;
	
	
	process (clk_vid)
	begin
	if rising_edge(clk_vid) then
		reset_vid <=not ext_reset_n;
	end if;
	end process;
	
	 reset		<= not RSTn;
--    process(clk_main)
--    begin
--        if rising_edge(clk_main) then
--            	powerup_reset_n_sync <= powerup_reset_n;
--            	ext_reset_n_sync     <= ext_reset_n;
 --           	RSTn                 <= key_break and powerup_reset_n_sync and ext_reset_n_sync;
--					reset						<= not RSTn;
--            	int_reset_n          <= key_break;
 --       end if;
 --   end process;

    -- write enables

    video_ram_we  <= not_cpu_R_W_n and vid_cs;

	 
    -- Motorola MC6847
    -- Original version: https://svn.pacedev.net/repos/pace/sw/src/component/video/mc6847.vhd
    -- Updated by AlanD for his Atom FPGA: http://stardot.org.uk/forums/viewtopic.php?f=3&t=6313
    -- A further few bugs fixed by myself
    Inst_mc6847 : entity work.mc6847
        port map (
            clk            => clk_vid,
            clk_ena        => clk_vid_en,
            reset          => reset_vid,
            da0            => open,
            videoaddr      => vid_addr,
            dd             => vid_data,
            hs_n           => vdg_hs_n,
            fs_n           => vdg_fs_n,
            an_g           => vdg_an_g,
            an_s           => vdg_an_s,
            intn_ext       => vdg_int_ex,
            gm             => vdg_gm,
            css            => vdg_css,
            inv            => vdg_inv,
            red            => vga_red,
            green          => vga_green,
            blue           => vga_blue,
            hsync          => vga_hsync,
            vsync          => vga_vsync,
            artifact_en    => '0',
            artifact_set   => '0',
            artifact_phase => '0',
            hblank         => vga_hblank,
            vblank         => vga_vblank,
            cvbs           => open,
            black_backgnd  => BLACK_BACKGND,
            char_a         => char_a,
            char_d_o       => char_d_o,
				pixel_clock    => pixel_clock
            );

       -- 8Kx8 Dual port video RAM
        -- Port A connects to Atom and is read/write
        -- Port B connects to MC6847 and is read only    
        Inst_VideoRam : entity work.VideoRam
            port map (
                clka  => clk_main,
                wea   => video_ram_we,
                addra => cpu_addr(12 downto 0),
                dina  => cpu_dout,
                douta => vid_dout,
                clkb  => clk_vid,
                web   => '0',
                addrb => vid_addr,
                dinb  => (others => '0'),
                doutb => vid_data
                );

				
        ---- ram for char generator      
        charrom_inst : entity work.CharRom
            port map(
                CLK  => clk_vid,
                ADDR => char_a,
                DATA => char_do
            );
 
        ---- ram for xtra char generator      
        charromx_inst : entity work.CharRomx
            port map(
                CLK  => clk_vid,
                ADDR => char_a,
                DATA => charx_do
            ); 
    -----------------------------------------------------------------------------
    -- Optional SID
    -----------------------------------------------------------------------------


        Inst_sid6581: sid6581
            port map (
                clk_1MHz => clk_sid_1MHz,
                clk32 => clk_main,
                clk_DAC => clk_dac,
                reset => reset,
                cs => cpu_clken,
                we => (sid_cs and not_cpu_R_W_n),
                addr => cpu_addr(4 downto 0),
                di => cpu_dout,
                dout => sid_dout,
                pot_x => '0',
                pot_y => '0',
                audio_out => sid_audio,
                audio_data => sid_audio_d 
            );

        -- Clock_Sid_1MHz is derived by dividing down the 32MHz clock      
        clk_sid_1MHz <= clk_counter(4);
		  
    --------------------------------------------------------
   -- Colour palette control
    --------------------------------------------------------

    process (clk_main)
    begin
        if rising_edge(clk_main) then
            if RSTn = '0' then
                -- initializing like this mean the palette will be
                -- implemented with LUTs rather than as a block RAM
                palette(0)  <= "000000";
                palette(1)  <= "000011";
                palette(2)  <= "000100";
                palette(3)  <= "000111";
                palette(4)  <= "001000";
                palette(5)  <= "001011";
                palette(6)  <= "001100";
                palette(7)  <= "001111";
                palette(8)  <= "110000";
                palette(9)  <= "110011";
                palette(10) <= "110100";
                palette(11) <= "110111";
                palette(12) <= "111000";
                palette(13) <= "111011";
                palette(14) <= "111100";
                palette(15) <= "111111";
            else
                -- write colour palette registers
                if palette_cs = '1' and cpu_R_W_n = '0' and phi2 = '1' then
                    palette(conv_integer(cpu_addr(3 downto 0))) <= cpu_dout(7 downto 2);
                end if;
            end if;
        end if;
    end process;

    logical_colour <= vga_red(7) & vga_green(7) & vga_green(6) & vga_blue(7);
	 vga_blank <= (vga_vblank or vga_hblank);
    -- Making this a synchronous process should improve the timing
    -- and potentially make the pixels more defined
    process (clk_vid)
    begin
        if rising_edge(clk_vid) then
            if vga_blank = '1' then
                physical_colour <= (others => '0');
            else
                physical_colour <= palette(conv_integer(logical_colour));
            end if;
            -- Also register hsync/vsync so they are correctly
            -- aligned with the colour changes
            vsync		<= vga_vsync;
				hsync    <= vga_hsync;
				vblank   <= vga_vblank;
				hblank   <= vga_hblank;
				-- character set selection
				if charset = '0' then
					char_d_o 	<= char_do;
					vdg_inv 		<= vid_data(7);
					vdg_an_s 	<= vid_data(6);
					vdg_int_ex 	<= vid_data(6);
				else
					char_d_o 	<= charx_do;
					vdg_inv 		<= '0';
					vdg_an_s 	<= vid_data(6);
					vdg_int_ex 	<= vid_data(6);
				end if;
        end if;
    end process;

    red(1)   <= physical_colour(5);
    red(0)   <= physical_colour(4);
    green(1) <= physical_colour(3);
    green(0) <= physical_colour(2);
    blue(1)  <= physical_colour(1);
    blue(0)  <= physical_colour(0);

	 
	 


---------------------------------------------------------------------
-- 8255 PIA
---------------------------------------------------------------------

    pia : entity work.I82C55 port map(
        I_ADDR => cpu_addr(1 downto 0),  -- A1-A0
        I_DATA => cpu_dout,  -- D7-D0
        O_DATA => pia_dout,
        CS_H   => pia_cs,
        WR_L   => cpu_R_W_n,
        O_PA   => i8255_pa_data,
        I_PB   => i8255_pb_idata,
        I_PC   => i8255_pc_idata(7 downto 4),
        O_PC   => i8255_pc_data(3 downto 0),
        RESET  => RSTn,
        ENA    => pia_clken,
        CLK    => clk_main);

    -- Port A
    --   bits 7..4 (output) determine the 6847 graphics mode
    --   bits 3..0 (output) drive the keyboard matrix
	 
    --vdg_gm        <= i8255_pa_data(7 downto 5) when RSTn='1' else "000";
    --vdg_an_g      <= i8255_pa_data(4)          when RSTn='1' else '0';
    --vdg_css       <= i8255_pc_data(3)          when RSTn='1' else '0';

	 
    process (clk_vid)
    begin
        if rising_edge(clk_vid) then

    if (RSTn='1') then vdg_gm        <= i8255_pa_data(7 downto 5); else vdg_gm<= "000"; end if;
    if (RSTn='1') then vdg_an_g      <= i8255_pa_data(4);          else  vdg_an_g<='0'; end if;
    if (RSTn='1') then vdg_css       <= i8255_pc_data(3) ;         else vdg_css<='0'; end if;
end if;
end process;

    -- Port B
    --   bits 7..0 (input) read the keyboard matrix
    i8255_pb_idata <= (key_shift & key_ctrl & ps2dataout);-- and (kbd_pb);


    -- Port C
    --    bit 7 (input) FS from the 6847
    --    bit 6 (input) Repeat from the keyboard matrix
    --    bit 5 (input) Cassette input
    --    bit 4 (input) 2.4KHz tone input
    --    bit 3 (output) CSS to the 6847
    --    bit 2 (output) Audio
    --    bit 1 (output) Enable 2.4KHz tone to casette output
    --    bit 0 (output) Cassette output
   -- vdg_css       <= i8255_pc_data(3)          when RSTn='1' else '0';
    atom_audio    <= i8255_pc_data(2);

    i8255_pc_idata <= vdg_fs_n & key_repeat & cas_in & cas_tone & i8255_pc_data (3 downto 0);

    -- this is a direct translation of the logic in the atom
    -- (two NAND gates and an inverter)
    cas_out <= not(not((not cas_tone) and i8255_pc_data(1)) and i8255_pc_data(0));

---------------------------------------------------------------------
-- PS/2 Keyboard Emulation
---------------------------------------------------------------------


    input : keyboard port map(
        clk      => clk_main,
		  clk_en		=> pia_clken,
        reset     => not ext_reset_n,
        layout    => layout,
        PS2_key   => ps2_key,
        keyout     => ps2dataout,
        row        => i8255_pa_data(3 downto 0),
        shift_out  => key_shift,
        ctrl_out   => key_ctrl,
        repeat_out => key_repeat,
        break_out  => key_break,
        turbo      => key_turbo,
        joy1  => Joystick1,
        joy2  => Joystick2
        );

---------------------------------------------------------------------
-- 6522 VIA
---------------------------------------------------------------------

        via : entity work.M6522 
		  port map(
            I_RS    => cpu_addr(3 downto 0),
            I_DATA  => cpu_dout,
            O_DATA  => via_dout,
				O_DATA_OE_L => open,
            I_RW_L  => cpu_R_W_n,
            I_CS1   => via_cs,
            I_CS2_L => '0',
            O_IRQ_L => mc6522_irq,
            I_CA1   => mc6522_ca1,
            I_CA2   => mc6522_ca2,
            O_CA2   => mc6522_ca2,
				O_CA2_OE_L => open,
            I_PA    => mc6522_porta(7 downto 0),
            O_PA    => mc6522_porta(7 downto 0),
				O_PA_OE_L => open,
            I_CB1   => mc6522_cb1,
            O_CB1   => mc6522_cb1,
				O_CB1_OE_L => open,
            I_CB2   => mc6522_cb2,
            O_CB2   => mc6522_cb2,
				O_CB2_OE_L => open,
            I_PB    => mc6522_portb(7 downto 0),
            O_PB    => mc6522_portb(7 downto 0),
				O_PB_OE_L => open,
            RESET_L => RSTn,
            I_P2_H  => via1_clken,
            ENA_4   => via4_clken,
            CLK     => clk_main);

        mc6522_ca1    <= '1';

--------------------------------------------------------
-- AtomMMC
--------------------------------------------------------

        Inst_AVR8: entity work.AVR8
        generic map(
            CDATAMEMSIZE         => 4096,
            CPROGMEMSIZE         => 10240
        )
        port map(
            clk16M            => clk_avr,
            nrst              => RSTn,
            portain           => AVRDataOut,
            portaout          => AVRDataIn,

            portbin(0)        => '0',
            portbin(1)        => '0',
            portbin(2)        => '0',
            portbin(3)        => '0',
            portbin(4)        => AVRInt,
            portbin(5)        => '0',
            portbin(6)        => '0',
            portbin(7)        => '0',

            portbout(0)       => nARD,
            portbout(1)       => nAWR,
            portbout(2)       => open,
            portbout(3)       => AVRA0,
            portbout(4)       => open,
            portbout(5)       => open,
            portbout(6)       => LED1n,
            portbout(7)       => LED2n,

            portdin           => (others => '0'),
            portdout(0)       => open,
            portdout(1)       => open,
            portdout(2)       => open,
            portdout(3)       => open,
            portdout(4)       => SDSS,
            portdout(5)       => open,
            portdout(6)       => open,
            portdout(7)       => open,

            -- FUDLR
            portein           => ioport,
            porteout          => open,

            spi_mosio         => SDMOSI,
            spi_scko          => SDCLK,
            spi_misoi         => SDMISO,

            rxd               => avr_RxD,
            txd               => avr_TxD
            );

        ioport <= "111" & Joystick1(5) & Joystick1(0) & Joystick1(1) & Joystick1(2) & Joystick1(3);

        Inst_AtomPL8: entity work.AtomPL8 port map(
            clk               => clk_main,
            enable            => pl8_cs,
            nRST              => RSTn,
            RW                => cpu_R_W_n,
            Addr              => cpu_addr(2 downto 0),
            DataIn            => cpu_dout,
            DataOut           => pl8_data,
            AVRDataIn         => AVRDataIn,
            AVRDataOut        => AVRDataOut,
            nARD              => nARD,
            nAWR              => nAWR,
            AVRA0             => AVRA0,
            AVRINTOut         => AVRInt,
            AtomIORDOut       => open,
            AtomIOWROut       => open
            );
        LED1 <= not key_break;
        LED2 <= '0';

---------------------------------------------------------------------
-- Ram Rom board functionality
---------------------------------------------------------------------

			ExternA     <= "10" & cpu_addr(15 downto 0) when computer = '1' else "010" & RomLatch & cpu_addr(11 downto 0) when A000_cs = '1' else "00" & cpu_addr;
			ExternDin   <= cpu_dout;
			ram_dout 	<= ExternDout;
			ExternWE    <= (not_cpu_R_W_n and not ext_rom_cs and phi2);
			ExternROM	<= ext_rom_cs;
            cpuphi2     <= phi2;
			RomLatch    <= RegBFFF(2 downto 0);
			
			BFFF_Enable <= '1' when cpu_addr(15 downto 0) = "1011111111111111" else '0';

			RomLatchProcess : process (RSTn, clk_main)
			begin
				if RSTn = '0' then
					RegBFFF <= (others => '0');
				elsif rising_edge(clk_main) then
					if BFFF_Enable = '1' and not_cpu_R_W_n = '1' then
						RegBFFF <= cpu_dout;
					end if;
				end if;
			end process;
---------------------------------------------------------------------
-- Device enables
---------------------------------------------------------------------

    process(cpu_addr,computer)
    begin
        -- All regions normally de-selected
        via_cs     	<= '0';
        pia_cs     	<= '0';
        vid_cs  		<= '0';
        sid_cs       <= '0';
        pl8_cs       <= '0';
		  spi_cs       <= '0';
		  palette_cs	<= '0';
		  ext_rom_cs 	<= '0';
        ext_ram_cs 	<= '0';
		  A000_cs    	<= '0';



        case cpu_addr(15 downto 12) is
            when x"0" => ext_ram_cs <= '1';  -- 0x0000 -- 0x03ff is RAM
            when x"1" => ext_ram_cs <= '1';
            when x"2" => ext_ram_cs <= '1';
            when x"3" => ext_ram_cs <= '1';
            when x"4" => ext_ram_cs <= '1';
            when x"5" => ext_ram_cs <= '1';
            when x"6" => 
						if computer = '1' then
							ext_rom_cs <= '1';
						else
							ext_ram_cs <= '1';
						end if;
            when x"7" => 
						if computer = '1' then
							ext_rom_cs <= '1';
						else
							ext_ram_cs <= '1';
						end if;
            when x"8" => vid_cs  	<= '1';  -- 0x8000 -- 0x9fff is RAM
            when x"9" => 
						if cpu_addr(11) = '0' then
							vid_cs  <= '1';
						else
							ext_ram_cs <= '1';
						end if;
            when x"A" => 
						ext_rom_cs <= '1';
						A000_cs	<= '1';
						if RegBFFF(2 downto 0) = "111" then
							ext_rom_cs <= '0';
						end if; 
            when x"B" =>
                if cpu_addr(11 downto 4)          		= x"00" then --  0xB00x 8255 PIA
                     pia_cs <= '1';
                elsif cpu_addr(11 downto 4)       		= x"40" then --  0xB40x AtoMMC
                     pl8_cs <= '1';
                elsif cpu_addr(11 downto 4)       		= x"80" then --  0xB80x 6522 VIA
                     via_cs <= '1';
					 elsif cpu_addr(11 downto 4) 		  		= x"C0" then --  SDOS
							spi_cs <= '1';
					 elsif cpu_addr(11 downto 4)				= x"D0" then --  PALETTE
							palette_cs <= '1';
                elsif cpu_addr(11 downto 5) & '0' 		= x"DC" then --  SID
                     sid_cs <= '1';
					 else ext_ram_cs <= '1';
                end if;
            when x"C"   => ext_rom_cs <= '1';
            when x"D"   => ext_rom_cs <= '1';
            when x"E"   => ext_rom_cs <= '1';
            when x"F"   => ext_rom_cs <= '1';
            when others => null;
        end case;

    end process;

---------------------------------------------------------------------
-- CPU data input multiplexor
---------------------------------------------------------------------

    cpu_din <=
        vid_dout     when vid_cs = '1'   		else
        pia_dout     when pia_cs = '1'       else
		  via_dout     when via_cs = '1'      	else
		  pl8_data 		when pl8_cs = '1'			else
		  spi_dout     when spi_cs = '1'    	else	
		  sid_dout		when sid_cs = '1'       else  
		  RegBFFF	 	when BFFF_Enable ='1'   else
		  ram_dout		when A000_cs ='1'    	else
        ram_dout	 	when ext_ram_cs ='1'    else
		  ram_dout		when ext_rom_cs ='1'    else
		  x"EA";    

--------------------------------------------------------
-- Clock enable generator
--------------------------------------------------------

    process(clk_main)
        variable mask4        : std_logic_vector(4 downto 0);
        variable limit        : integer;
        variable phi2l        : integer;
        variable phi2h        : integer;
        variable sampl        : integer;
    begin
        -- Don't include reset here, so 6502 continues to be clocked during reset
        if rising_edge(clk_main) then
            -- Counter:
            --   main_clock = 32MHz
            --      1MHz 0..31
            --      2MHz 0..15
            --      4MHz 0..7
            --      8MHz 0..3

            --   main_clock = 16MHz
            --      1MHz 0..15
            --      2MHz 0..7
            --      4MHz 0..3
            --      8MHz not supported

            -- Work out optimal timing
            --   mask4  - mask to give a 4x speed clock
            --   limit  - maximum value of clk_counter so it wraps at 1MHz
            --   phi2l  - when phi2 should go low
            --   phi2h  - when phi2 should go high
            --   sample - when sample_data should asserted

            -- none of the variables are stateful

                -- 32MHz
                case (turbo_synced) is
                    when "11"   => mask4 := "00000"; limit :=  3; phi2l :=  3; phi2h :=  1; sampl :=  2; -- 8MHz
                    when "10"   => mask4 := "00001"; limit :=  7; phi2l :=  7; phi2h :=  3; sampl :=  6; -- 4MHz
                    when "01"   => mask4 := "00011"; limit := 15; phi2l := 15; phi2h :=  7; sampl := 14; -- 2MHz
                    when others => mask4 := "00111"; limit := 31; phi2l := 31; phi2h := 15; sampl := 30; -- 1MHz
                end case;
            

            if clk_counter = limit then
                turbo_synced <= "00";
                clk_counter <= (others => '0');
            else
                clk_counter <= clk_counter + 1;
            end if;

            -- Assert cpu_clken in cycle 0
            if clk_counter = limit then
                cpu_clken <= '1';
            else
                cpu_clken <= '0';
            end if;

            -- Assert pia_clken in anti-phase with cpu_clken
            if clk_counter = phi2h then
                pia_clken <= '1';
            else
                pia_clken <= '0';
            end if;

            -- Assert via1_clken in cycle 0
            if clk_counter = limit then
                via1_clken <= '1';
            else
                via1_clken <= '0';
            end if;

            -- Assert via4 at 4x the rate of via1
            if (clk_counter and mask4) = (std_logic_vector(to_unsigned(limit,5)) and mask4) then
                via4_clken <= '1';
            else
                via4_clken <= '0';
            end if;

            -- Assert phi2 at the specified times
            if clk_counter = phi2h then
                phi2 <= '1';
            elsif clk_counter = phi2l then
                phi2 <= '0';
            end if;

            -- Assert sample_data at the specified time
            if clk_counter = sampl then
                sample_data <= '1';
            else
                sample_data <= '0';
            end if;
				
				-- Cassette divider
				-- 32 MHz / 2 / 13 / 16 / 16 = 4807 Hz
				
				if cas_divider = 0 then
                cas_divider <= x"19FF";
                cas_tone    <= not cas_tone;
            else
                cas_divider <= cas_divider - 1;
            end if;
		

        end if;
    end process;


end BEHAVIORAL;
