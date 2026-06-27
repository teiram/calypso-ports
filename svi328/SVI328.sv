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

assign LED[0]  =  ~ioctl_download;
assign LED[1] = ~motor;
assign LED[2] = megarom;
assign LED[3] = tape_loaded;

`include "build_id.v"
localparam CONF_STR = {
    "SVI328;;",
    "S0U,DSK,Mount drive 0;",
    "F1,BINROM,Load Cartridge;",
    `SEP
    "F2,CAS,Load Tape;",
    "OF,Tape Input,File,Line;",
    "TD,Rewind Tape;",
    "O4,Tape Audio,On,Off;",
    `SEP
    "O79,Scanlines,None,25%,50%,75%;",
    "O6,Show border,No,Yes;",
    "O3,Swap joysticks,No,Yes;",
    `SEP
    "OE,SVI806,Enabled,Disabled;",
    "OA,Video output,VDP,SVI806;",
    "OBC,SVI806 Console Color,White,Green,Amber,Cyan;",
    `SEP
    "T0,Reset;",
    "T1,Hard reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire clk_sys;
wire clk_21m3;
wire clk_24m;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .c1(clk_21m3),
    .locked(pll_locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
// Megarom logic
reg megarom;
reg [5:0] megarom_index;

always @(posedge clk_sys) begin
    reg [2:0] div;
    reg [19:0] megarom_cnt;
    div <= div + 1'd1;
    ce_10m7 <= !div[1:0];
    ce_5m3  <= !div[2:0];
    if (!div[2:0]) begin
        if (megarom_cnt == 20'd666666) begin
            megarom_cnt <= 20'd0;
            megarom_index <= megarom_index + 6'd1;
        end else megarom_cnt <= megarom_cnt + 20'd1;
    end
end

wire ce_fdc = cpu_ce && &cnt_fdc;
reg [1:0] cnt_fdc = 'd0;

always @(posedge clk_sys) begin
    if (cpu_ce == 1'b1) begin
        cnt_fdc <= cnt_fdc + 1'b1;
    end
end

wire [31:0] status;
wire  [1:0] buttons;

wire [31:0] joy0, joy1;

wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire [8:0] sd_buff_addr;
wire [7:0] sd_buff_dout;
wire [7:0] sd_buff_din;
wire sd_buff_wr;

wire img_mounted;
wire img_readonly;

wire [63:0] img_size;
wire [31:0] img_ext;


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
    .clk_sd(clk_sys),
    
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
    .status(status),
    
    .sd_sdhc(1'b1),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack_x(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size)
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
reg tape_loaded;

always @(posedge clk_sys) begin
    reg hard_reset_last;
    reg ce_last;
    
    hard_reset_last <= hard_reset;
    ce_last <= ce_5m3;
    if (~hard_reset_last & hard_reset) begin
        cleanup_addr <= 16'hffff;
        cleanup_we <= 1'b1;
        megarom <= 1'b0;
        tape_loaded <= 1'b0;
    end
    else begin
        if (~ce_last & ce_5m3) begin
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
        if (ioctl_index[1:0] == 2'b01 && ioctl_download == 1'b1) begin
            megarom <= |ioctl_addr[19:16];
        end
        if (ioctl_index[1:0] == 2'b10 && ioctl_download == 1'b1) tape_loaded <= 1'b1;
        else if (reset == 1'b1) tape_loaded <= 1'b0;
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
wire [8:0] megarom_page = megarom ? 
    megarom_index < 6'd4 ? {6'd0, 1'b1, megarom_index[1:0]} : {3'b100, megarom_index[5:0]} 
    : {6'd0, 1'b1, ram_a[15:14]};

assign sdram_we = ioctl_wr |
                  (isRam & svi806_ramdis_n & ~(ram_we_n | ram_ce_n)) | 
                  (in_hard_reset & cleanup_we);

assign sdram_addr = 
        (ioctl_download && ioctl_isROM && ~|ioctl_addr[24:16]) ? {6'd0, ioctl_index[0], ioctl_addr[15:0]} : //ioctl: ROM and Cartridge (64K)
        (ioctl_download && ioctl_isROM && |ioctl_addr[24:16]) ? {3'b100,  ioctl_addr[19:0]} :               //ioctl: Cartridge (> 64K)
        ioctl_cas_download ? {2'b11, ioctl_addr[20:0]} :                                                    //ioctl: Cassette
        in_hard_reset ? {1'b1, cleanup_addr} :                                                              //Hard reset
        sdram_cas_rd ? {2'b11, sdram_cas_addr[20:0]} :                                                      //Cassette: Play
        ram_a[17:16] == 2'b01 ? {megarom_page, ram_a[13:0]} : ram_a;                                        //CPU&Mapper accesses

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

// Mapper returns an address of 18 bits (256Kb)
// 00000 - 0FFFF. 64Kb  - ROM
// 10000 - 1FFFF. 64Kb  - Cartridge ROM
// 20000 - 3FFFF. 128Kb - RAM

svi_mapper RamMapper(
    .addr_i(cpu_ram_a),
    .RegMap_i(ay_port_b),
    .addr_o(ram_a),
    .ram(isRam)
);

wire [10:0] core_audio;

// Select audio source based on cassette status
wire [10:0] audio = (cas_status != 0 && !status[4]) ? {svi_audio_in, 10'b0000000000} : core_audio;

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

wire [7:0] R,G,B, ay_port_b;
wire hblank, vblank;
wire hsync, vsync;
wire cpu_rfsh_n;
wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

wire svi_audio_in = status[15] ? tape_in : (cas_status != 0 ? cas_data_out : 1'b0);
wire ce_10m7_gated = ioctl_cas_download ? 1'b0 : ce_10m7;

wire cpu_ce;
wire cpu_wait;
wire cpu_ioreq_n;
wire cpu_mreq_n;
wire cpu_rd_n;

wire ext_io_ena = fdc_io_ena | svi806_io_ena;
wire [7:0] ext_io_data = fdc_data_out | svi806_data_out;

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
    .cpu_ram_d_i(svi806_ramdis_n == 1'b1 ? ram_di : svi806_data_out),
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

    .audio_o(core_audio),

    .clk_en_3m58_p_o(cpu_ce),
    .wait_n_i(~cpu_wait),
    .cpu_ioreq_n_o(cpu_ioreq_n),
    .cpu_mreq_n_o(cpu_mreq_n),
    
    .ext_io_en_n_i(~ext_io_ena),
    .ext_io_data_i(ext_io_data)
);

wire svi806_video;
wire svi806_hsync;
wire svi806_vsync;
wire svi806_de;
wire svi806_ramdis_n;
wire svi806_io_ena;
wire [7:0] svi806_data_out;

svi806_top crt80(
    .clk(clk_sys),
    .pix_ce(ce_10m7),
    .cpu_ce(cpu_ce),
    .reset(reset),
    
    .io_ena(svi806_io_ena),
    .cpu_addr(cpu_ram_a),
    .cpu_data_in(ram_do),
    .cpu_mreq_n(cpu_mreq_n),
    .cpu_ioreq_n(cpu_ioreq_n | status[14]),
    .cpu_rd_n(ram_rd_n),
    .cpu_wr_n(ram_we_n),
    
    .cpu_data_out(svi806_data_out),
    .cpu_wait(cpu_wait),
    .ramdis_n(svi806_ramdis_n),
    
    .video(svi806_video),
    .hsync(svi806_hsync),
    .vsync(svi806_vsync),
    .de(svi806_de)
);

wire [7:0] fdc_data_out;
wire fdc_io_ena;

wire fdc_ce = toggle;
reg toggle = 1'd0;
always @(posedge clk_sys) begin
    if (cpu_ce) toggle <= ~toggle;
end

sv801 fdc(
    .clk(clk_sys),
    .ce(cpu_ce),
    .reset(reset),

    .ioreq(~cpu_ioreq_n),
    .rd(~ram_rd_n),
    .wr(~ram_we_n),
    .bus_addr(cpu_ram_a),
    .fdc_data_in(ram_do),
    .fdc_data_out(fdc_data_out),
    .fdc_ena(fdc_io_ena),
    
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din),
    .sd_buff_wr(sd_buff_wr),
    
    .img_mounted(img_mounted),
    .img_size(img_size),
    
    .write_protect(1'b0)
);


wire [2:0] scanlines = status[9:7];

wire [23:0] rgb_t_white = svi806_video == 1'b1 ? 24'hffffff : 24'd0;
wire [23:0] rgb_t_green = svi806_video == 1'b1 ? 24'h00ff00 : 24'd0;
wire [23:0] rgb_t_amber = svi806_video == 1'b1 ? 24'hff7e00 : 24'd0;
wire [23:0] rgb_t_cyan = svi806_video == 1'b1 ? 24'h00ffff : 24'd0;

wire [23:0] rgb_svi806 = svi806_de ? 
    status[12:11] == 2'b00 ? rgb_t_white :
    status[12:11] == 2'b01 ? rgb_t_green :
    status[12:11] == 2'b10 ? rgb_t_amber :
    rgb_t_cyan :
    24'd0;

mist_video #(.COLOR_DEPTH(8),
             .SD_HCNT_WIDTH(11),
             .OUT_COLOR_DEPTH(VGA_BITS),
             .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    
    .R(status[10] == 1'b0 ? R : rgb_svi806[23:16]),
    .G(status[10] == 1'b0 ? G : rgb_svi806[15:8]),
    .B(status[10] == 1'b0 ? B : rgb_svi806[7:0]),
    .HSync(status[10] == 1'b0 ? hsync : ~svi806_hsync),
    .VSync(status[10] == 1'b0 ? vsync : ~svi806_vsync),
    .HBlank(status[10] == 1'b0 ? hblank : 1'b0),
    .VBlank(status[10] == 1'b0 ? vblank : 1'b0),
    
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .scanlines(scanlines),
    .ce_divider(status[10] == 1'b0 ? 3'd0 : 3'd1),

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

assign play = ~motor & tape_loaded;
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
