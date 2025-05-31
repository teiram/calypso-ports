----------------------------------------------------------------------------------
-- Galaksija
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity galaksija is port(
    SYS_CLK : in std_logic;
    PIX_CLK : in std_logic;
    RESET_IN_n: in std_logic;
    PS2_CLK : in std_logic;
    PS2_DATA : in std_logic;
    
    VIDEO_DATA : out std_logic;
    VIDEO_SYNC : out std_logic;
    VIDEO_HSYNC: out std_logic;
    VIDEO_VSYNC: out std_logic;

    LINE_IN : in std_logic;
    AUX: out std_logic_vector(7 downto 0)

);
end galaksija;

architecture rtl of galaksija is
    --
    -- Z80A signals
    --
    signal A : std_logic_vector(15 downto 0);
    signal D : std_logic_vector(7 downto 0);

    signal RESET1_n : std_logic;
    signal RESET2_n : std_logic;

    signal RESET_n : std_logic;
    signal RFSH_n : std_logic;
    signal CPU_CLK_n : std_logic;
    signal CPU_CLK : std_logic;
    signal MREQ_n : std_logic;
    signal IORQ_n : std_logic;
    signal M1_n : std_logic;
    signal WAIT_n : std_logic;
    signal INT_n : std_logic;
    signal NMI_n : std_logic := '1';
    signal WR_n : std_logic;

    signal RFSH : std_logic;

    signal RD_n : std_logic;

    -- Video related signals
    signal HSYNC_DIV : std_logic_vector(9 downto 0) := "0000000000";
    signal VSYNC_DIV : std_logic_vector(9 downto 0) := "0000000001";
    
    signal HSYNC : std_logic;
    signal VSYNC : std_logic;
    signal VIDEO_INT : std_logic;

    signal HSYNC_Q, HSYNC_Q_n : std_logic;
    signal VSYNC_Q, VSYNC_Q_n : std_logic;
    
    signal SYNC1, SYNC2 : std_logic;
    signal SYNC : std_logic;

    signal LOAD_SCAN_LINE_n : std_logic;
    signal LOAD_SCAN_LINE_n_int : std_logic;

    signal dRFSH : std_logic;
    --
    -- End of Z80A signals
    --

    --
    -- Pixel clock
    -- 
    signal PDIV : std_logic_vector(3 downto 0) := "0000";
 --   signal PIX_CLK_COUNTER : std_logic_vector(2 downto 0) := "000";
--    signal PIX_CLK : std_logic;-- Pixel clock, should be 6.144 MHz
    
--    signal iPIX_CLK : std_logic;

    --
    -- Address decoder
    --
    signal ROM_OE_n : std_logic;
    signal ROM_A : std_logic_vector(12 downto 0);
    signal ROM_DATA: std_logic_vector(7 downto 0);
    
    signal RAM_A7 : std_logic;
    signal RAM_A : std_logic_vector(12 downto 0);
    signal RAM_DATA: std_logic_vector(7 downto 0);
    
    signal LATCH_KBD_CS_n : std_logic;
    signal DECODER_EN : std_logic;
    
    signal LATCH_DATA : std_logic_vector(5 downto 0) := "111111"; -- Signal from latch
    signal LATCH_D5 : std_logic;
    signal LATCH_CLK : std_logic;

    signal RAM_WR_n : std_logic;
    
    signal RAM_CS1_n, RAM_CS2_n, RAM_CS3_n, RAM_CS4_n, RAM_CS_n : std_logic;
    
    --
    -- Keyboard
    --
    signal KR : std_logic_vector(7 downto 0);                  -- row select for keyboard
    signal KS : std_logic_vector(7 downto 0) := "11111111";    -- Scanline for keyboard
    signal KSout : std_logic;
    signal KRsel : std_logic_vector(2 downto 0);
    signal KSsel : std_logic_vector(2 downto 0);

    --
    -- Character generator
    --
    signal LATCH_IN : std_logic_vector(5 downto 0);
    signal CHROM_A : std_logic_vector(10 downto 0);
    signal CHROM_D : std_logic_vector(7 downto 0);
    signal SHREG : std_logic_vector(7 downto 0);

    signal VIDEO_DATA_int : std_logic;

    signal CHROM_CLK : std_logic;

    signal WAIT_CLK : std_logic;
    signal WAIT_CLK_P: std_logic;

    --
    -- Misc
    --
    signal ESC_STATE : std_logic;
    signal KEY_CODE : std_logic_vector(7 downto 0);
    signal KEY_STROBE : std_logic;

    signal port_FFFF : std_logic_vector(2 downto 0) := "111";
    
    --
    -- Components
    -- 
    
    component T80a is
        generic(
            mode : integer := 0     -- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
        );
        port(
            RESET_n : in std_logic;
            CLK_n : in std_logic;
            WAIT_n : in std_logic;
            INT_n : in std_logic;
            NMI_n : in std_logic;
            BUSRQ_n : in std_logic;
            M1_n : out std_logic;
            MREQ_n : out std_logic;
            IORQ_n : out std_logic;
            RD_n : out std_logic;
            WR_n : out std_logic;
            RFSH_n : out std_logic;
            HALT_n : out std_logic;
            BUSAK_n : out std_logic;
            A : out std_logic_vector(15 downto 0);
            D : inout std_logic_vector(7 downto 0)
        );
    end component T80a;

    component reset_gen is
        generic(
            CycleCount : integer := 1000000
        );
        port(
            RESET_n : out  std_logic;
            CLK : in  std_logic
        );
    end component reset_gen;

    component MMV is
        generic(Period : integer := 1000);
        port(
            CLK : in std_logic;
            TRIG : in std_logic;
            Q : out std_logic;
            Q_n : out std_logic
        );
    end component MMV;
    
    component brom is
        port(
            a: in std_logic_vector(12 downto 0);
            clk: in std_logic;
            rd_n: in std_logic;
            d: inout std_logic_vector(7 downto 0)
        );
    end component brom;

    component charrom is
        port(
            address: in std_logic_vector(10 downto 0);
            clock: in std_logic;
            q: out std_logic_vector(7 downto 0)
        );
    end component charrom;

    component galaksija_keyboard_v2 is
        port(
            CLK : in  STD_LOGIC;
            PS2_DATA : in  STD_LOGIC;
            PS2_CLK : in  STD_LOGIC;
            LINE_IN : in  STD_LOGIC := '0';
            KR : in  STD_LOGIC_VECTOR (7 downto 0);
            KS : out  STD_LOGIC_VECTOR (7 downto 0);
            NMI_n : out std_logic;
            RST_n : out std_logic;
            ESC : out std_logic;
            KEY_CODE : out std_logic_vector(7 downto 0);
            KEY_STROBE : out std_logic;
            RESET_n : in STD_LOGIC
        );
    end component galaksija_keyboard_v2;

    component tristate_bit is
        port(
            DIN : in  STD_LOGIC;
            DOUT : out  STD_LOGIC;
            EN_n : in  STD_LOGIC
        );
    end component tristate_bit;

    component tristate_buff is
        port(
            DIN : in  STD_LOGIC_VECTOR(7 downto 0);
            DOUT : out  STD_LOGIC_VECTOR(7 downto 0);
            EN_n : in  STD_LOGIC
        );
    end component tristate_buff;

    component bram is
        port(
            a: in std_logic_vector(12 downto 0);
            d: inout std_logic_vector(7 downto 0);
            clk: in std_logic;
            rd_n: in std_logic;
            we_n: in std_logic
        );
    end component bram;

    --
    -- End of components
    --
    
    signal TMP : std_logic_vector(7 downto 0);
    
    signal KSBUF_en : std_logic;
    signal KSTMP : std_logic_vector(7 downto 0);


    signal port_FFFE : std_logic := '0';
    
    
    attribute keep: boolean;
    attribute keep of A: signal is true;
    attribute keep of WAIT_n: signal is true;
    attribute keep of RFSH_n: signal is true;
    attribute keep of RESET_n: signal is true;
    attribute keep of CPU_CLK_n: signal is true;
    attribute keep of CHROM_A: signal is true;
    attribute keep of CHROM_D: signal is true;
    attribute keep of VIDEO_DATA: signal is true;
    attribute keep of INT_n: signal is true;
    attribute keep of SHREG: signal is true;
    attribute keep of RAM_CS1_n: signal is true;
    attribute keep of RAM_CS2_n: signal is true;
    attribute keep of RAM_CS3_n: signal is true;
    attribute keep of RAM_CS_n: signal is true;
    attribute keep of ROM_OE_n: signal is true;
    attribute keep of LATCH_D5: signal is true;


begin

    --
    -- CPU instantation
    --

    CPU: T80a
        generic map(
            mode => 0
        )
        port map(
            A => A,
            D => D,
            BUSRQ_n => '1',
            RESET_n => RESET_n,
            RFSH_n => RFSH_n,
            CLK_n => CPU_CLK_n,
            MREQ_n => MREQ_n,
            IORQ_n => IORQ_n,
            M1_n => M1_n,
            WAIT_n => WAIT_n,
            INT_n => INT_n,
            NMI_n => NMI_n,
            WR_n => WR_n,
            RD_n => RD_n
        );

    RFSH <= not RFSH_n;
    RESET_n <= RESET1_n and RESET2_n and RESET_IN_n;

    --
    -- Reset generator
    --
    RST_GEN: reset_gen
    generic map(
        CycleCount => 100
    )
    port map(
        RESET_n => RESET1_n,
        CLK => CPU_CLK
    );
    
    --
    -- WAIT_n signal generator
    -- Waits for the Z80 interrupt ack until the first HSYNC happens
    -- to synchronize the video driver with the beam
    -- WAIT_CLK goes high after the second wait state of the interrupt ack
    WAIT_CLK <= not(not(M1_n) and not(IORQ_n));
    
    process (PIX_CLK, WAIT_CLK, HSYNC_Q_n)
    begin
        if HSYNC_Q_n = '0' then
            WAIT_n <= '1';
        else 
            if rising_edge(PIX_CLK) then
                WAIT_CLK_P <= WAIT_CLK;
                if WAIT_CLK_P = '0' and WAIT_CLK = '1' then
                    WAIT_n <= '0';
                end if;
            end if;
        end if;
    end process;

    -- This process implements the counters for frequency division in galaksija
    -- PDIV is a counter to 12 on the pixel clock giving 512Khz (6144khz -> 512Khz)
    -- HSYNC_DIV is a 10 bit counter up to 1024 giving divisors down to 500hz
    -- VSYNC_DIV is a ring counter to provide 10 states on HSYNC_DIV 500hz
    -- providing 10 50hz enablers on different phases
    process (PIX_CLK, HSYNC_DIV, PDIV)
    begin
        if falling_edge(PIX_CLK) then
            if (PDIV = "1011") then
                PDIV <= "0000";
                HSYNC_DIV <= HSYNC_DIV + 1;
                if HSYNC_DIV = "1111111111" then
                    VSYNC_DIV <= VSYNC_DIV(8 downto 0) & VSYNC_DIV(9);
                end if;
            else
                PDIV <= PDIV + 1;
            end if;
        end if;
    end process;
    
    --
    -- Clock management
    --
    CPU_CLK <= PDIV(0);
    CPU_CLK_n <= not CPU_CLK;

    -- HSYNC on the 5th divisor of 6144khz -> 6144 / 32 = 16khz
    HSYNC <= HSYNC_DIV(4);
    -- VSYNC on the shift register: 50hz
    VSYNC <= VSYNC_DIV(9);
    -- The interrupt happens 2/500 s after the vsync start (4 ms after)
    VIDEO_INT <= VSYNC_DIV(1);
    
    INT_n <= not VIDEO_INT;

    -- Video sync signal generation
    -- These components just stretch the vsync and hsync signals as needed
    -- Simulating a monostable multivibrator (74HC123)
    -- HSYNC MMV C3 = 5 nF R12 = 390 T=1.95 us. 11,98 cycles at 6,144 Mhz
    HSYNC_MMV: MMV
    generic map(Period => 12)
    port map(
        TRIG => HSYNC,
        CLK => PIX_CLK,
        Q => HSYNC_Q,
        Q_n => HSYNC_Q_n
    );

    
    -- VSYNC MMV C4 = 100 nF R13 = 27 K, T = 2.7 mS. 16588 cycles at 6,144 Mhz
    VSYNC_MMV: MMV
    generic map(Period => 16588)
    port map(
        TRIG => VSYNC,
        CLK => PIX_CLK,
        Q => VSYNC_Q,
        Q_n => VSYNC_Q_n
    );

    SYNC1 <= not(HSYNC_Q and VSYNC_Q);
    SYNC2 <= not(VSYNC_Q_n and HSYNC_Q_n);
    
    SYNC <= not(SYNC1 and SYNC2);
    VIDEO_SYNC <= SYNC;
    VIDEO_HSYNC <= HSYNC_Q_n;
    VIDEO_VSYNC <= VSYNC_Q_n;
    
    -- Load scan line FF
    -- LOAD_SCAN_LINE_n <= LOAD_SCAN_LINE_n_int;

    process (CPU_CLK, LATCH_KBD_CS_n)
    begin
        if rising_edge(CPU_CLK) then
            dRFSH <= LATCH_KBD_CS_n;
        end if;
    end process;

--    process (MREQ_n, CPU_CLK_n, RFSH, PIX_CLK, dRFSH)
--    begin
--        if ((RFSH = '0') and (PIX_CLK = '1')) or (dRFSH = '0') then
--            LOAD_SCAN_LINE_n_int <= '1';
--        else
--            if rising_edge(CPU_CLK_n) then
--                LOAD_SCAN_LINE_n_int <= not MREQ_n;
--            end if;
--        end if;
--    end process;

    process (PIX_CLK, MREQ_n, CPU_CLK_n, RFSH_n)
    begin
        if rising_edge(PIX_CLK) then
            LOAD_SCAN_LINE_n <= MREQ_n or CPU_CLK_n or RFSH_n;
        end if;
    end process;
    --
    -- Address decoder
    --
        
    DECODER_EN <= '1' when MREQ_n = '0' and A(15 downto 14) = "00" else '0';
    
    -- Keyboard and latch address decoding
    LATCH_KBD_CS_n <= '0' when A(13 downto 11) = "100" and DECODER_EN = '1' and RFSH_n = '1'
        else '1';
    ROM_OE_n <= '0' when A(14 downto 13) = "00" and DECODER_EN = '1' and RFSH = '0' else '1';

    ROM_A <= A(12 downto 0);

    RAM_CS1_n <= '0' when (DECODER_EN = '1' and A(13 downto 11) = "101") or RFSH = '1' else '1';
    RAM_CS2_n <= '0' when DECODER_EN = '1' and A(13 downto 11) = "110" else '1';
    RAM_CS3_n <= '0' when DECODER_EN = '1' and A(13 downto 11) = "111" else '1';

    -- Extended RAM (+2k)
    RAM_CS4_n <= '0' when A(15 downto 11) = "01000" else '1';

    RAM_CS_n <= RAM_CS1_n and RAM_CS2_n and RAM_CS3_n and RAM_CS4_n;
    
    RAM_WR_n <= WR_n;

    RAM_A7 <= not(not(A(7)) and LATCH_D5);
    
    RAM_A <=
        "00" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS1_n = '0' else
        "01" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS2_n = '0' else
        "10" & A(10 downto 8) & RAM_A7 & A(6 downto 0) when RAM_CS3_n = '0' else
        "11" & A(10 downto 8) & RAM_A7 & A(6 downto 0);

    --
    -- RAM and ROM
    --
    MRAM: bram
    port map (
        clk => PIX_CLK,
        a => RAM_A,
        d => D,
        rd_n => RAM_CS_n,
        we_n => RAM_WR_n
    );

    MROM: brom
    port map (
        clk => PIX_CLK,
        a => ROM_A,
        d => D,
        rd_n => ROM_OE_n
    );
    
    --
    -- Keyboard.
    --
    KRsel <= A(5) & A(4) & A(3);
    -- Select keyboard row or select latch
    process (KRsel, LATCH_KBD_CS_n)
    begin
        if (LATCH_KBD_CS_n = '0') then
            case (KRsel) is
                when "000" => KR <= "11111110";
                when "001" => KR <= "11111101";
                when "010" => KR <= "11111011";
                when "011" => KR <= "11110111";
                when "100" => KR <= "11101111";
                when "101" => KR <= "11011111";
                when "110" => KR <= "10111111";
                when "111" => KR <= "01111111";
                when others => KR <= "11111111";
            end case;
        else
            KR <= "11111111";
        end if;
    end process;
    
    KSsel <= A(2) & A(1) & A(0);
    -- Multiplex the keyboard scanlines
    process (KSsel, LATCH_KBD_CS_n, KS, RD_n)
    begin
        case KSsel is
            when "000" => KSout <= KS(0);
            when "001" => KSout <= KS(1);
            when "010" => KSout <= KS(2);
            when "011" => KSout <= KS(3);
            when "100" => KSout <= KS(4);
            when "101" => KSout <= KS(5);
            when "110" => KSout <= KS(6);
            when "111" => KSout <= KS(7);
            when others => KSout <= '1';
        end case;
    end process;

    KSBUF_en <= LATCH_KBD_CS_n when RD_n = '0' else '1';

    KSBUF : tristate_bit
    port map (
        DIN => KSOut,
        DOUT => D(0),
        EN_n => KSBUF_en
    );

    --
    -- PS2 Keyboard
    --
    PS2_KBD: galaksija_keyboard_v2
    port map (
        CLK => SYS_CLK,
        NMI_n => NMI_n,
        PS2_DATA => PS2_DATA,
        PS2_CLK => PS2_CLK,
        LINE_IN => LINE_IN,
        KR => KR,
        KS => KS,
        RST_n => RESET2_n,
        ESC => ESC_STATE,
        KEY_CODE => KEY_CODE,
        KEY_STROBE => KEY_STROBE,
        RESET_n => RESET1_n
    );
    
    --
    -- Character generator
    --
    
    -- Latch
    LATCH_CLK <= PIX_CLK;
    LATCH_IN <= D(7 downto 2);
    
    process (LATCH_CLK, LATCH_IN, KR(7))
    begin
        if rising_edge(LATCH_CLK) then
            if (KR(7) = '0') then
                LATCH_DATA <= LATCH_IN;
            end if;
        end if;
    end process;
    
    LATCH_D5 <= LATCH_DATA(5);


    process(D, PIX_CLK)
    begin
        if rising_edge(PIX_CLK) then
            TMP <= D;
        end if;
    end process;
    
    -- Character generator address
    CHROM_A <= LATCH_DATA(3 downto 0) & TMP(7) & TMP(5 downto 0);

    MCHARROM: charrom
    port map (
        clock => PIX_CLK,
        address => CHROM_A,
        q => CHROM_D
    );

    -- Video shift register
    process(PIX_CLK, LOAD_SCAN_LINE_n, SHREG)
    begin
        if rising_edge(PIX_CLK) then
            if (LOAD_SCAN_LINE_n = '0') then
                SHREG <= CHROM_D;
            else
                SHREG <= SHREG(6 downto 0) & '0';
            end if;
        end if;
    end process;

    VIDEO_DATA_int <=  not SHREG(7) when SYNC = '1' else '0';

    VIDEO_DATA <= VIDEO_DATA_int;

    AUX(0) <= CPU_CLK_n;
    AUX(1) <= PIX_CLK;
    AUX(2) <= HSYNC_Q_n;
    AUX(3) <= VSYNC_Q_n;
    AUX(4) <= INT_n;
    AUX(5) <= WAIT_n;
    AUX(6) <= RFSH_n;
    AUX(7) <= M1_n;

    
end rtl;
