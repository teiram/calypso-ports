module SVI328(       
    input         CLK12M,
    output [7:0]  LED,
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
    input         SPI_SS2,    // data_io
    input         SPI_SS3,    // OSD
    input         CONF_DATA0, // SPI_SS for user_io

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

`ifdef I2S_AUDIO
    output        I2S_BCK,
    output        I2S_LRCK,
    output        I2S_DATA,
`endif
`ifdef SPDIF_AUDIO
    output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
    input         AUDIO_IN,
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

`ifdef USE_AUDIO_IN
wire TAPE_SOUND = AUDIO_IN;
`else
wire TAPE_SOUND = UART_RX;
`endif

assign LED[0]  =  svi_audio_in;

`include "build_id.v" 
localparam CONF_STR = {
    "SVI328;;",
    "F,BINROM,Load Cartridge;",
    "F2,CAS,Cas File;",
    "OF,Tape Input,File,Line;",
    "TD,Rewind Tape;",
    "O79,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
    "O6,Show border,No,Yes;",
    "O3,Swap joysticks,No,Yes;",
    "T0,Reset;",
    "T1,Hard reset;",
    "V,calypso-",`BUILD_DATE
};

wire clk_sys;
wire clk_21m3;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .c1(clk_21m3),
    .locked(pll_locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
    reg [2:0] div;

    div <= div + 1'd1;
    ce_10m7 <= !div[1:0];
    ce_5m3  <= !div[2:0];
end

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire        ypbpr;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))

user_io(

    .clk_sys(clk_sys),
    .conf_str(CONF_STR),
    
    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),
    .buttons(buttons),
    .ypbpr(ypbpr),
    
    .key_strobe(key_strobe),
    .key_pressed(key_pressed),
    .key_extended(key_extended),
    .key_code(key_code),
    
    .joystick_0(joy0),
    .joystick_1(joy1),
    .status(status)
);

data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_SS4(SPI_SS4),
    .SPI_DI(SPI_DI),
    .clkref_n(1'b0),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);


wire reset = status[0] | (ioctl_download && ioctl_isROM) | in_hard_reset;

wire hard_reset = status[1];
reg [15:0] cleanup_addr = 16'd0;
reg cleanup_we;
wire in_hard_reset = |cleanup_addr;

always @(posedge clk_sys) begin
    reg hard_reset_last;
    reg ce_last;
    
    hard_reset_last <= hard_reset;
    ce_last <= ce_5m3;
    if (~hard_reset_last & hard_reset) begin
        cleanup_addr <= 16'hffff;
        cleanup_we <= 1'b1;
    end
    else if (~ce_last & ce_5m3) begin
        if (|cleanup_addr) begin
            case (cleanup_we) 
                1'b0: cleanup_we <= 1'b1;
                1'b1: begin
                    cleanup_we <= 1'b0;
                    cleanup_addr <= cleanup_addr - 1'b1;
                end
            endcase
        end
    end
end


wire [3:0] svi_row;
wire [7:0] svi_col;
sviKeyboard KeyboardSVI(
    .clk(clk_sys),
    .reset(reset),

    .key(key_code),
    .strobe(key_strobe),
    .pressed(key_pressed),
    .extended(key_extended),
    
    .svi_row(svi_row),
    .svi_col(svi_col)
);


wire [15:0] cpu_ram_a;
wire        ram_we_n, ram_rd_n, ram_ce_n;
wire  [7:0] ram_di;
wire  [7:0] ram_do;


wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_di;
wire  [7:0] vram_do;

spram #(14) vram(
    .clock(clk_sys),
    .address(vram_a),
    .wren(vram_we),
    .data(vram_do),
    .q(vram_di)
);

wire sdram_ready;
wire sdram_we;
wire sdram_rd;
wire sdram_cas_rd;
wire [20:0] sdram_cas_addr;
wire [22:0] sdram_addr;
wire  [7:0] sdram_din;
wire ioctl_isROM = ioctl_index[5:0] < 6'd2; //OSD file index is 0 (ROM) or 1 (ROM Cartridge)
wire ioctl_cas_download = ioctl_download & ioctl_index[5:0] == 6'd2;

assign sdram_we = ioctl_wr | 
                  (isRam & ~(ram_we_n | ram_ce_n)) | 
                  (in_hard_reset & cleanup_we);

assign sdram_addr = (ioctl_download && ioctl_isROM) ? {6'd0, ioctl_index[0], ioctl_addr[15:0]} : 
        ioctl_cas_download ? {2'b11, ioctl_addr[20:0]} :
        in_hard_reset ? {1'b1, cleanup_addr} :
        sdram_cas_rd ? {2'b11, sdram_cas_addr[20:0]} :
        ram_a;

assign sdram_din = ioctl_wr ? ioctl_dout : 
    in_hard_reset ? 8'h00 :
    ram_do;

assign sdram_rd = ~(ram_rd_n | ram_ce_n) | sdram_cas_rd;
assign SDRAM_CLK = clk_sys;

sdram sdram(
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_CKE(SDRAM_CKE),
    
    .init(~pll_locked),
    .clk(clk_sys),

    .wtbt(0),
    .addr(sdram_addr), 
    .rd(sdram_rd),
    .we(sdram_we),
    .din(sdram_din),
    .dout(ram_di),
    
    .ready(sdram_ready)
);

wire [17:0] ram_a;
wire isRam;

wire motor;

svi_mapper RamMapper(
    .addr_i(cpu_ram_a),
    .RegMap_i(ay_port_b),
    .addr_o(ram_a),
    .ram(isRam)
);

wire [10:0] audio;

`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd42_660_000;
i2s i2s(
    .reset(reset),
    .clk(clk_sys),
    .clk_rate(clk_rate),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio, 5'b00000}),
    .right_chan({audio, 5'b00000})
);
`endif

wire [7:0] R,G,B,ay_port_b;
wire hblank, vblank;
wire hsync, vsync;
wire cpu_rfsh_n;
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire svi_audio_in = status[15] ? tape_in : (cas_status != 0 ? cas_data_out : 1'b0);
wire ce_10m7_gated = ioctl_cas_download ? 1'b0 : ce_10m7;

cv_console console(
    .clk_i(clk_sys),
    .clk_en_10m7_i(ce_10m7_gated),
    .clk_en_5m3_i(ce_5m3),
    .reset_n_i(~reset),

    .svi_row_o(svi_row),
    .svi_col_i(svi_col),	

    .svi_tap_i(svi_audio_in),

    .motor_o(motor),

    .joy0_i(~{joya[4],joya[0],joya[1],joya[2],joya[3]}),
    .joy1_i(~{joyb[4],joyb[0],joyb[1],joyb[2],joyb[3]}),

    .cpu_ram_a_o(cpu_ram_a),
    .cpu_ram_we_n_o(ram_we_n),
    .cpu_ram_ce_n_o(ram_ce_n),
    .cpu_ram_rd_n_o(ram_rd_n),
    .cpu_ram_d_i(ram_di),
    .cpu_ram_d_o(ram_do),
    .cpu_rfsh_n_o(cpu_rfsh_n),
    .ay_port_b(ay_port_b),
	
    .vram_a_o(vram_a),
    .vram_we_o(vram_we),
    .vram_d_o(vram_do),
    .vram_d_i(vram_di),

    .border_i(status[6]),
    .rgb_r_o(R),
    .rgb_g_o(G),
    .rgb_b_o(B),
    .hsync_n_o(hsync),
    .vsync_n_o(vsync),
    .hblank_o(hblank),
    .vblank_o(vblank),

    .audio_o(audio)
);

wire [1:0] scanlines = status[9:7];

mist_video #(.COLOR_DEPTH(8),
             .SD_HCNT_WIDTH(11),
             .OUT_COLOR_DEPTH(VGA_BITS),
             .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    
    .R(R),
    .G(G),
    .B(B),
    .HSync(hsync),
    .VSync(vsync),
    .HBlank(hblank),
    .VBlank(vblank),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .scanlines(scanlines),
    .ce_divider(1'b0),

    .scandoubler_disable(1'b0),
    .ypbpr(ypbpr),
    .rotate(2'b00),
    .blend(1'b0)
);

wire tape_in;
assign tape_in = TAPE_SOUND;

wire cas_data_out;
wire [2:0] cas_status;
wire play, rewind;

assign play = ~motor;
assign rewind = status[13] | ioctl_cas_download | reset;

cassette CASReader(
    .clk(clk_21m3),
    .play(play),
    .rewind(rewind),
    .reset(reset),

    .sdram_addr(sdram_cas_addr),
    .sdram_data(ram_di),
    .sdram_rd(sdram_cas_rd),
    .sdram_available(~cpu_rfsh_n),
    .sdram_ready(sdram_ready),
    .data(cas_data_out),
    .status(cas_status)
);

endmodule