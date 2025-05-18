//============================================================================
//  MSX top level for MiST
// 
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module msx2plus
(
	input         CLK12M,

	output [7:0]       LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif
	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,
	input         SPI_SS3,
	input         CONF_DATA0,

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif
	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
`ifdef USE_MIDI_PINS
	input         MIDI_IN,
	output        MIDI_OUT,
`endif
	input         UART_RX,
	output        UART_TX
);


`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 4;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 0;
assign SDRAM2_nRAS = 0;
assign SDRAM2_nWE = 0;
`endif

`include "build_id.v" 

assign LED  = leds;

parameter CONF_STR = {
    "MSX2+;;",
    "S0,VHD,Mount;",
    `SEP
    "O2,CPU Clock,Normal,Turbo;",
    "O3,Slot1,Empty,MegaSCC+ 1MB;",
    "O45,Slot2,Empty,MegaSCC+ 2MB,MegaRAM 1MB,MegaRAM 2MB;",
    "O6,RAM,2048kB,4096kB;",
    `SEP
    "O7,Swap joysticks,No,Yes;",
    `SEP
    "O8,VGA Output,CRT,LCD;",
//    "OAB,Scanlines,Off,25%,50%,75%;",
    "O9,Tape sound,OFF,ON;",
`ifndef USE_MIDI_PINS
//    "OA,UART TX,MIDI,WiFi;",
`endif
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire        uart_sel = status[10];

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;
wire memclk;
`ifdef USE_HDMI
wire hdmiclk;
`endif

pll pll(
    .inclk0(CLK12M),
    .c0(memclk),
    .c1(clk_sys),
`ifdef USE_HDMI
    .c2(hdmiclk),
`endif
    .locked(locked)
);

assign SDRAM_CLK = memclk;

//////////////////   MiST I/O   ///////////////////
wire  [7:0] joy_0;
wire  [7:0] joy_1;
wire  [1:0] buttons;
wire [63:0] status;
wire        ypbpr;
wire        no_csync;
wire        scandoubler_disable;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_conf;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        ps2_kbd_clk;
wire        ps2_kbd_data;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

wire [63:0] rtc;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(100), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(
        .clk_sys(clk_sys),
        .clk_sd(clk_sys),
        .SPI_SS_IO(CONF_DATA0),
        .SPI_CLK(SPI_SCK),
        .SPI_MOSI(SPI_DI),
        .SPI_MISO(SPI_DO),

        .conf_str(CONF_STR),

        .status(status),
        .scandoubler_disable(scandoubler_disable),
        .ypbpr(ypbpr),
        .no_csync(no_csync),
        .buttons(buttons),
        .rtc(rtc),
`ifdef USE_HDMI
        .i2c_start      (i2c_start      ),
        .i2c_read       (i2c_read       ),
        .i2c_addr       (i2c_addr       ),
        .i2c_subaddr    (i2c_subaddr    ),
        .i2c_dout       (i2c_dout       ),
        .i2c_din        (i2c_din        ),
        .i2c_ack        (i2c_ack        ),
        .i2c_end        (i2c_end        ),
`endif
        .joystick_0(joy_0),
        .joystick_1(joy_1),

        .img_mounted(img_mounted),
        .img_size(img_size),
        .sd_conf(sd_conf),
        .sd_ack(sd_ack),
        .sd_ack_conf(sd_ack_conf),
        .sd_sdhc(sd_sdhc),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_lba(sd_lba),
        .sd_buff_addr(sd_buff_addr),
        .sd_din(sd_buff_din),
        .sd_dout(sd_buff_dout),
        .sd_dout_strobe(sd_buff_wr),

        .ps2_kbd_clk(ps2_kbd_clk),
        .ps2_kbd_data(ps2_kbd_data),

        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .mouse_flags(mouse_flags),
        .mouse_strobe(mouse_strobe),

        // unused
        .switches(),
        .ps2_mouse_clk(),
        .ps2_mouse_data(),
        .joystick_analog_0(),
        .joystick_analog_1()
);

sd_card sd_card
(
        .clk_sys(clk_sys),
        .img_mounted(img_mounted),
        .img_size(img_size),
        .sd_conf(sd_conf),
        .sd_ack(sd_ack),
        .sd_ack_conf(sd_ack_conf),
        .sd_sdhc(sd_sdhc),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_lba(sd_lba),
        .sd_buff_addr(sd_buff_addr),
        .sd_buff_din(sd_buff_din),
        .sd_buff_dout(sd_buff_dout),
        .sd_buff_wr(sd_buff_wr),
        .allow_sdhc(1),
        .sd_sck(Sd_Ck),
        .sd_cs(Sd_Dt[3]),
        .sd_sdi(Sd_Cm),
        .sd_sdo(Sd_Dt[0])
);

wire [5:0] joya = status[7] ? ~joy_1[5:0] : ~joy_0[5:0];
wire [5:0] joyb = status[7] ? ~joy_0[5:0] : ~joy_1[5:0];
wire [5:0] msx_joya;
wire [5:0] msx_joyb;
wire       msx_stra;
wire       msx_strb;

wire       Sd_Ck;
wire       Sd_Cm;
wire [3:0] Sd_Dt;

wire       msx_ps2_kbd_clk = ps2_kbd_clk;
wire       msx_ps2_kbd_data = (ps2_kbd_data == 1'b0 ? ps2_kbd_data : 1'bZ);
reg  [7:0] dipsw;
wire [7:0] leds;

reg reset;
reg  [27:0] img_reset_cnt = 0;
wire resetW = status[0] | buttons[1] | img_reset_cnt != 0 | ~locked;

always @(posedge clk_sys) begin
	if (img_reset_cnt != 0) img_reset_cnt <= img_reset_cnt - 1'd1;
	if (img_mounted) img_reset_cnt <= 28'h2000000;
	reset <= resetW;
	dipsw <= {1'b0, ~status[6], ~status[5:4], ~status[3], ~scandoubler_disable & status[8], scandoubler_disable, ~status[2]};
end

always_comb begin
    for (integer i=0; i<=5; i++) begin
        msx_joya[i] <= mouse_en ? (mouse[i] ? 1'bZ : mouse[i]) : (~joya[i] & ~msx_stra ? joya[i] : 1'bZ);
        msx_joyb[i] <= (~joyb[i] & ~msx_strb ? joyb[i] : 1'bZ);
    end
end

reg        mouse_en = 0;
reg  [5:0] mouse;

always @(posedge clk_sys) begin

    reg        stra_d;
    reg  [8:0] mouse_x_latch;
    reg  [8:0] mouse_y_latch;
    reg  [1:0] mouse_state;
    reg [17:0] mouse_timeout;

    if (reset) begin
        mouse_en <= 0;
        mouse_state <= 0;
    end
    else if (mouse_strobe) mouse_en <= 1;
    else if (~&joya) mouse_en <= 0;

    if (mouse_strobe) begin
        mouse_x_latch <= ~mouse_x + 1'd1; //2nd complement of x
        mouse_y_latch <= mouse_y;
    end

    mouse[5:4] <= ~mouse_flags[1:0];
    if (mouse_en) begin
        if (mouse_timeout) begin
            mouse_timeout <= mouse_timeout - 1'd1;
            if (mouse_timeout == 1) mouse_state <= 0;
        end

        stra_d <= msx_stra;
        if (stra_d ^ msx_stra) begin
            mouse_timeout <= 18'd100000;
            mouse_state <= mouse_state + 1'd1;
            case (mouse_state)
            2'b00: mouse[3:0] <= {mouse_x_latch[5],mouse_x_latch[6],mouse_x_latch[7],mouse_x_latch[8]};
            2'b01: mouse[3:0] <= {mouse_x_latch[1],mouse_x_latch[2],mouse_x_latch[3],mouse_x_latch[4]};
            2'b10: mouse[3:0] <= {mouse_y_latch[5],mouse_y_latch[6],mouse_y_latch[7],mouse_y_latch[8]};
            2'b11:
            begin
                mouse[3:0] <= {mouse_y_latch[1],mouse_y_latch[2],mouse_y_latch[3],mouse_y_latch[4]};
                mouse_x_latch <= 0;
                mouse_y_latch <= 0;
            end
            endcase
        end
    end
end

wire  [5:0] Dac_SL, Dac_SR;
wire        Cmt_Out;
wire        esp_tx, midi_tx;
reg         rx, rxD;
always @(posedge clk_sys) begin
	rxD <= UART_RX;
	rx <= rxD;
`ifdef USE_MIDI_PINS
	UART_TX <= esp_tx;
	MIDI_OUT <= midi_tx;
`else
	UART_TX <= uart_sel ? esp_tx : midi_tx;
`endif
end

wire        ear_in;
`ifdef USE_AUDIO_IN
assign      ear_in = AUDIO_IN;
`else
assign      ear_in = rx;
`endif

wire  [5:0] R_O;
wire  [5:0] G_O;
wire  [5:0] B_O;
wire        HSync, VSync, Blank;
wire [13:0] audio;

emsx_top emsx
(
//        -- Clock, Reset ports
        .clk21m     (clk_sys),
        .memclk     (memclk),
        .pSltRst_n  (~reset),

//        -- SD-RAM ports
        .pMemAdr   ( SDRAM_A ),
        .pMemDat   ( SDRAM_DQ ),
        .pMemLdq   ( SDRAM_DQML ),
        .pMemUdq   ( SDRAM_DQMH ),
        .pMemWe_n  ( SDRAM_nWE ),
        .pMemCas_n ( SDRAM_nCAS ),
        .pMemRas_n ( SDRAM_nRAS ),
        .pMemCs_n  ( SDRAM_nCS ),
        .pMemBa0   ( SDRAM_BA[0] ),
        .pMemBa1   ( SDRAM_BA[1] ),
        .pMemCke   ( SDRAM_CKE ),

//        -- PS/2 keyboard ports
        .pPs2Clk   (msx_ps2_kbd_clk),
        .pPs2Dat   (msx_ps2_kbd_data),

//        -- Joystick ports (Port_A, Port_B)
        .pJoyA      ( {msx_joya[5:4], msx_joya[0], msx_joya[1], msx_joya[2], msx_joya[3]} ),
        .pStra      ( msx_stra ),
        .pJoyB      ( {msx_joyb[5:4], msx_joyb[0], msx_joyb[1], msx_joyb[2], msx_joyb[3]} ),
        .pStrb      ( msx_strb ),

//        -- SD/MMC slot ports
        .pSd_Ck     (Sd_Ck),
        .pSd_Cm     (Sd_Cm),
        .pSd_Dt     (Sd_Dt),

//        -- DIP switch, Lamp ports
        .pDip       (dipsw),
        .pLed       (leds),

//        -- Video, Audio/CMT ports
        .CmtIn      (ear_in),
        .CmtOut     (Cmt_Out),
        .pDac_VR    (R_O),      // RGB_Red / Svideo_C
        .pDac_VG    (G_O),      // RGB_Grn / Svideo_Y
        .pDac_VB    (B_O),      // RGB_Blu / CompositeVideo
        .pVideoHS_n (HSync),    // HSync(RGB15K, VGA31K)
        .pVideoVS_n (VSync),    // VSync(RGB15K, VGA31K)
        .pVideoBlank(Blank),

        .audio_o    (audio),

        .pDac_SL    (Dac_SL),
        .pDac_SR    (Dac_SR),

        .iRTC       (rtc),
        .oMidi      (midi_tx),
        .pUsbP1     (rx),
        .pUsbN1     (esp_tx)
);

assign AUDIO_L = Dac_SL[0];
assign AUDIO_R = status[9] ? Cmt_Out : Dac_SR[0];

//////////////////   VIDEO   //////////////////

wire [5:0] osd_r_o, osd_g_o, osd_b_o;

osd #(.OUT_COLOR_DEPTH(6), .BIG_OSD(BIG_OSD), .OSD_COLOR(3'b001)) osd(
    .clk_sys(clk_sys),
    .SPI_DI(SPI_DI),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .R_in(R_O),
    .G_in(G_O),
    .B_in(B_O),
    .HSync(HSync),
    .VSync(VSync),
    .R_out(osd_r_o),
    .G_out(osd_g_o),
    .B_out(osd_b_o)
    );

wire [5:0] r, g, b;
wire       cs, hs, vs, bl;

RGBtoYPbPr #(6) RGBtoYPbPr
(
	.clk      ( clk_sys ),
	.ena      ( ypbpr   ),
	.red_in   ( osd_r_o ),
	.green_in ( osd_g_o ),
	.blue_in  ( osd_b_o ),
	.hs_in    ( HSync   ),
	.vs_in    ( VSync   ),
	.cs_in    ( ~(HSync ^ VSync) ),
	.hb_in    ( Blank   ),
	.red_out  ( r       ),
	.green_out( g       ),
	.blue_out ( b       ),
	.hs_out   ( hs      ),
	.vs_out   ( vs      ),
	.cs_out   ( cs      ),
	.hb_out   ( bl      )
);

always @(posedge clk_sys) begin
	VGA_R <= r[5:2];
	VGA_G <= g[5:2];
	VGA_B <= b[5:2];
	// a minimig vga->scart cable expects a composite sync signal on the VGA_HS output.
	// and VCC on VGA_VS (to switch into rgb mode)
	VGA_HS <= ((~no_csync & scandoubler_disable) || ypbpr)? cs : hs;
	VGA_VS <= ((~no_csync & scandoubler_disable) || ypbpr)? 1'b1 : vs;
end


`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd21_000_000),
	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),
	.left_chan({1'b0, audio, 1'b0}),
	.right_chan({1'b0, audio, 1'b0})
);
`endif


endmodule
