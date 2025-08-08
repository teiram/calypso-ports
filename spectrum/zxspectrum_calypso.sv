//============================================================================
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
`default_nettype none

module zxspectrum_calypso(
    input CLK12M,
`ifdef USE_CLOCK_50
    input CLOCK_50,
`endif

    output [7:0] LED,
    output [VGA_BITS-1:0] VGA_R,
    output [VGA_BITS-1:0] VGA_G,
    output [VGA_BITS-1:0] VGA_B,
    output VGA_HS,
    output VGA_VS,

    input SPI_SCK,
    inout SPI_DO,
    input SPI_DI,
    input SPI_SS2,
    input SPI_SS3,
    input CONF_DATA0,

`ifndef NO_DIRECT_UPLOAD
    input SPI_SS4,
`endif

`ifdef I2S_AUDIO
    output I2S_BCK,
    output I2S_LRCK,
    output I2S_DATA,
`endif

`ifdef USE_AUDIO_IN
    input AUDIO_IN,
`endif

    output [12:0] SDRAM_A,
    inout [15:0] SDRAM_DQ,
    output SDRAM_DQML,
    output SDRAM_DQMH,
    output SDRAM_nWE,
    output SDRAM_nCAS,
    output SDRAM_nRAS,
    output SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CLK,
    output SDRAM_CKE,
    
    output UART_TX,
    input UART_RX

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
localparam bit USE_AUDIO_IN = 1;
wire TAPE_SOUND=AUDIO_IN;
`else
localparam bit USE_AUDIO_IN = 0;
wire TAPE_SOUND=UART_RX;
`endif


assign LED[0] = ~(ioctl_download | tape_led | |unouart_act);

localparam CONF_BDI   = "(BDI)";
localparam CONF_PLUSD = "(+D) ";

localparam ROM_ADDR  = 25'h100000; // boot rom
localparam TAPE_ADDR = 25'h200000; // tape buffer at 2MB
localparam SNAP_ADDR = 25'h400000; // snapshot buffer at 4MB

localparam ARCH_ZX48  = 5'b011_00; // ZX 48
localparam ARCH_ZX128 = 5'b000_01; // ZX 128/+2
localparam ARCH_ZX3   = 5'b100_01; // ZX 128 +3
localparam ARCH_P48   = 5'b011_10; // Pentagon 48
localparam ARCH_P128  = 5'b000_10; // Pentagon 128
localparam ARCH_P1024 = 5'b001_10; // Pentagon 1024

`include "build_id.v"
localparam CONF_STR = {
    "SPECTRUM;;",
    "S1U,TRDIMGDSKMGT,Load Disk;",
    "F2,TAPCSWTZX,Load Tape;",
    "F3,Z80SNA,Load Snapshot;",
    `SEP
    "P1,Profiles;",
    "P1I,48k Issue 2,0xc20,0x1fa0;",  // 48k video, 48k mem, snowing, Issue 2
    "P1I,48k Issue 3,0xc00,0x1fa0;",  // 48k video, 48k mem, snowing, Issue 3
    "P1I,Standard 128k,0x100,0x1fa0;", // 128k video, 128k mem, snowing
    "P1I,Spectrum +3,0x1180,0x1fa0;",  // 128k video, +3 mem, unrained
    "P1I,Pentagon 1024k,0x680,0x1fa0;",// Pentagon video, Pentagon mem, unrained
    `SEP
    "O89,Video timings,ULA-48,ULA-128,Pentagon;",
    "OAC,Memory,Standard 128K,Pentagon 1024K,Profi 1024K,Standard 48K,+2A/+3;",
    "O12,Joystick 1,Sinclair I,Sinclair II,Kempston,Cursor;",
    "O34,Joystick 2,Sinclair I,Sinclair II,Kempston,Cursor;",
    "O6,Fast tape load,On,Off;",
    "OFG,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
    "ODE,Features,ULA+ & Timex,ULA+,Timex,None;",
    "OHI,MMC Card,Off,divMMC,ZXMMC,divMMC+ESXDOS;",
    "OKL,General Sound,512KB,1MB,2MB,Disabled;",
    "OJ,Currah uSpeech,Off,On;",
    "OQ,Covox/SounDrive,Off,On;",
    "O5,Keyboard,Issue 3,Issue 2;",
    "O7,Snowing,Enabled,Unrained;",
    "OM,CPU type,NMOS,CMOS;",
    "ONP,CPU frequency,3.5 MHz,7 MHz,14 MHz,28 MHz,56 MHz;",
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire [1:0] st_ula_type    = status[9:8];
wire [2:0] st_memory_mode = status[12:10];
wire       st_fast_tape   = status[6];
wire [1:0] st_joy1        = status[2:1];
wire [1:0] st_joy2        = status[4:3];
wire [1:0] st_scanlines   = status[16:15];
wire [1:0] st_mmc         = status[18:17];
wire [1:0] st_gs_memory   = status[21:20];
wire       st_issue2      = status[5];
wire       st_unrainer    = status[7];
wire       st_uspeech     = status[19];
wire       st_out0        = status[22];
wire [2:0] st_cpu_freq    = status[25:23];
wire       st_covox       = status[26];

////////////////////   CLOCKS   ///////////////////
wire clk_sys /* synthesis keep */;
wire clk_sdram;
wire locked;
assign SDRAM_CLK = clk_sdram;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sdram),
    .c1(clk_sys),
    .locked(locked)
);

reg  ce_psg;  //1.75MHz
reg  ce_7mp;
reg  ce_7mn;
reg  ce_14m;

reg  pause;
reg  cpu_en = 1;
reg  ce_cpu_tp;
reg  ce_cpu_tn;

wire ce_cpu_p = cpu_en & cpu_p;
wire ce_cpu_n = cpu_en & cpu_n;
wire ce_cpu   = cpu_en & ce_cpu_tp;
wire ce_u765 = ce_cpu;
wire ce_tape = ce_cpu;

wire cpu_p = ~&turbo ? ce_cpu_tp : ce_cpu_sp;
wire cpu_n = ~&turbo ? ce_cpu_tn : ce_cpu_sn;

always @(posedge clk_sys) begin
    reg [5:0] counter = 0;

    counter <=  counter + 1'd1;

    ce_14m  <= !counter[2:0];
    ce_7mp  <= !counter[3] & !counter[2:0];
    ce_7mn  <=  counter[3] & !counter[2:0];
    ce_psg  <= !counter[5:0] & ~pause;

    ce_cpu_tp <= !(counter & turbo);
    ce_cpu_tn <= !((counter & turbo) ^ turbo ^ turbo[4:1]);
end

reg  ce_8m;
always @(posedge clk_sys) begin
    reg [5:0] counter = 0;
    counter <= counter + 1'd1;
    ce_8m <= 0;
    if (counter == 13) begin
        ce_8m <= 1;
        counter <= 0;
    end
end

reg [4:0] turbo = 5'b11111, turbo_reg = 5'b11111;
always @(posedge clk_sys) begin
    reg [9:4] old_Fn;
    reg [2:0] old_st;
    old_Fn <= Fn[9:4];
    old_st <= st_cpu_freq;

    if(reset) pause <= 0;

    if(!mod) begin
        if(~old_Fn[4] & Fn[4]) turbo_reg <= 5'b11111; //3.5 MHz
        if(~old_Fn[5] & Fn[5]) turbo_reg <= 5'b01111; //  7 Mhz
        if(~old_Fn[6] & Fn[6]) turbo_reg <= 5'b00111; // 14 MHz
        if(~old_Fn[7] & Fn[7]) turbo_reg <= 5'b00011; // 28 MHz
        if(~old_Fn[8] & Fn[8]) turbo_reg <= 5'b00001; // 56 MHz
        if(~old_Fn[9] & Fn[9]) pause <= ~pause;
    end

    if(st_cpu_freq != old_st) begin
        case(st_cpu_freq)
            3'd0:    turbo_reg <= 5'b11111; //3.5 MHz
            3'd1:    turbo_reg <= 5'b01111; //  7 Mhz
            3'd2:    turbo_reg <= 5'b00111; // 14 MHz
            3'd3:    turbo_reg <= 5'b00011; // 28 MHz
            3'd4:    turbo_reg <= 5'b00001; // 56 MHz
            default: turbo_reg <= 5'b11111; //3.5 MHz
        endcase
    end
end

wire [4:0] turbo_req = (tape_active & ~st_fast_tape) ? 5'b00001 : turbo_reg;
always @(posedge clk_sys) begin
    reg [1:0] timeout;

    if(cpu_n) begin
        if(timeout) timeout <= timeout + 1'd1;
        if(turbo != turbo_req) begin
            cpu_en  <= 0;
            timeout <= 1;
            turbo   <= turbo_req;
        end else if(!cpu_en & !timeout & ram_ready) begin
            cpu_en  <= ~pause;
        end else if(!turbo[4:3] & !ram_ready) begin // SDRAM wait for 14MHz/28MHz/56MHz turbo
            cpu_en  <= 0;
        end else if(cpu_en & pause) begin
            cpu_en  <= 0;
        end
    end
end


//////////////////   MIST ARM I/O   ///////////////////
wire  [31:0] joystick_0;
wire  [31:0] joystick_1;

wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;
wire [63:0] status;

wire        sd_rd_plus3;
wire        sd_wr_plus3;
wire [31:0] sd_lba_plus3;
wire [7:0]  sd_buff_din_plus3;

wire        sd_rd_wd;
wire        sd_wr_wd;
wire [31:0] sd_lba_wd;
wire [7:0]  sd_buff_din_wd;

wire        sd_busy_mmc;
wire        sd_rd_mmc;
wire        sd_wr_mmc;
wire [31:0] sd_lba_mmc;
wire  [7:0] sd_buff_din_mmc;

wire [31:0] sd_lba = sd_busy_mmc ? sd_lba_mmc : (plus3_fdd_ready ? sd_lba_plus3 : sd_lba_wd);
wire  [1:0] sd_rd = { sd_rd_plus3 | sd_rd_wd, sd_rd_mmc };
wire  [1:0] sd_wr = { sd_wr_plus3 | sd_wr_wd, sd_wr_mmc };

wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din = sd_busy_mmc ? sd_buff_din_mmc : (plus3_fdd_ready ? sd_buff_din_plus3 : sd_buff_din_wd);
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [63:0] img_size;

wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc;

wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

wire [24:0] ps2_mouse = { mouse_strobe_level, mouse_y[7:0], mouse_x[7:0], mouse_flags };
reg         mouse_strobe_level;
always @(posedge clk_sys) if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;

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

user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(2), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(
    .clk_sys(clk_sys),
    .clk_sd(clk_sys),
    .conf_str(CONF_STR),

    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MOSI(SPI_DI),
    .SPI_MISO(SPI_DO),

    .img_mounted(img_mounted),
    .img_size(img_size),
    .sd_conf(sd_conf),
    .sd_ack_conf(sd_ack_conf),
    .sd_sdhc(sd_sdhc),
    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_din(sd_buff_din),
    .sd_dout(sd_buff_dout),
    .sd_dout_strobe(sd_buff_wr),

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_flags(mouse_flags),
    .mouse_strobe(mouse_strobe),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1),

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

    .buttons(buttons),
    .status(status),
    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync)

);
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [5:0] ioctl_index;
wire  [1:0] ioctl_ext_index;

data_io data_io
(
    .clk_sys(clk_sys),

    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),

    .clkref_n(1'b0),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_download(ioctl_download),
    .ioctl_index({ioctl_ext_index, ioctl_index})
);
///////////////////   CPU   ///////////////////
wire [15:0] addr;
wire  [7:0] cpu_din;
wire  [7:0] cpu_dout;
wire        nM1;
wire        nMREQ;
wire        nIORQ;
wire        nRD;
wire        nWR;
wire        nRFSH;
wire        nBUSACK;
wire        nINT;
wire        nBUSRQ = ~ioctl_download;

wire        io_wr = ~nIORQ & ~nWR & nM1;
wire        io_rd = ~nIORQ & ~nRD & nM1;
wire        m1    = ~nM1 & ~nMREQ;

// for edge detection
reg         old_wr;
reg         old_rd;
reg         old_m1;

wire[211:0] cpu_reg;  // IFF2, IFF1, IM, IY, HL', DE', BC', IX, HL, DE, BC, PC, SP, R, I, F', A', F, A
wire [15:0] reg_DE  = cpu_reg[111:96];
wire  [7:0] reg_A   = cpu_reg[7:0];

T80pa cpu(
    .RESET_n(~reset),
    .CLK(clk_sys),
    .CEN_p(ce_cpu_p),
    .CEN_n(ce_cpu_n),
    .WAIT_n(1),
    .INT_n(nINT),
    .NMI_n(~NMI),
    .BUSRQ_n(nBUSRQ),
    .M1_n(nM1),
    .MREQ_n(nMREQ),
    .IORQ_n(nIORQ),
    .RD_n(nRD),
    .WR_n(nWR),
    .RFSH_n(nRFSH),
    .HALT_n(1),
    .BUSAK_n(nBUSACK),
    .A(addr),
    .DO(cpu_dout),
    .DI(cpu_din),
    .REG(cpu_reg),
    .DIR(snap_REG),
    .DIRSet(snap_REGSet),
    .OUT0(st_out0)
);

always_comb begin
    casex({sp0256_sel, nMREQ, tape_dout_en, ~nM1 | nIORQ | nRD, fdd_sel | fdd_sel2 | plus3_fdd, mf3_port, mmc_sel, addr[5:0]==6'h1F, portBF, gs_sel, psg_enable, unouart_dout_oe, ulap_sel, addr[0]})
        'b1XXXXXXXXXXXXX: cpu_din = {7'b1111111, ~sp0256_rdy};
        'b001XXXXXXXXXXX: cpu_din = tape_dout;
        'b000XXXXXXXXXXX: cpu_din = ram_dout;
        'b01X01XXXXXXXXX: cpu_din = fdd_dout;
        'b01X001XXXXXXXX: cpu_din = (addr[14:13] == 2'b11 ? page_reg : page_reg_plus3);
        'b01X0001XXXXXXX: cpu_din = mmc_dout;
        'b01X00001XXXXXX: cpu_din = mouse_sel ? mouse_data : joy_kempston;
        'b01X000001XXXXX: cpu_din = {page_scr_copy, 7'b1111111};
        'b01X0000001XXXX: cpu_din = gs_dout;
        'b01X00000001XXX: cpu_din = (addr[14] ? sound_data : 8'hFF);
        'b01X000000001XX: cpu_din = unouart_dout;
        'b01X0000000001X: cpu_din = ulap_dout;
        'b01X00000000000: cpu_din = {1'b1, ula_tape_in, 1'b1, key_data[4:0] & joy_kbd & rst_kbd};
        default: cpu_din = port_ff;
    endcase
end

reg init_reset = 1;
reg old_download;

always @(posedge clk_sys) begin
    old_download <= ioctl_download;
    if(old_download & ~ioctl_download) init_reset <= 0;
end

reg  NMI;
reg  NMI_old;
reg  NMI_pending;
reg  reset /* synthesis keep */;
reg  cold_reset_btn;
reg  warm_reset_btn;
reg  auto_reset_btn;
wire cold_reset = cold_reset_btn | init_reset;
wire warm_reset = warm_reset_btn;
wire auto_reset = auto_reset_btn;

always @(posedge clk_sys) begin
    reg old_F10;

    old_F10 <= Fn[10];

    reset <= status[0] | cold_reset | warm_reset | snap_reset | auto_reset | ~locked;

    if (reset | ~Fn[10]) NMI <= 0;
    else if (~old_F10 & Fn[10] & (mod[2:1] == 0)) NMI <= 1;

    warm_reset_btn <= (mod[2:1] == 0) & Fn[11];
    cold_reset_btn <= (mod[2:1] == 1) & Fn[11]; // alt+F11
    auto_reset_btn <= (mod[2:1] == 2) & Fn[11]; // ctrl+F11
end

always @(posedge clk_sys) begin
    old_rd <= io_rd;
    old_wr <= io_wr;
    old_m1 <= m1;
    NMI_old <= NMI;
end

always @(posedge clk_sys) begin
    if (reset) NMI_pending <= 0;
    else if (~NMI_old & NMI) NMI_pending <= 1;
    else if (~m1 && old_m1 && (addr == 'h66)) NMI_pending <= 0;
end

// To reset esxDOS on cold reset we need to hold Space key
reg [5:0] esxdos_reset_cnt = 0;
always @(posedge clk_sys) begin
    if (cold_reset && st_mmc == 2'b11)
        esxdos_reset_cnt <= 1'd1;
    else if (esxdos_reset_cnt && VSync && !VSync_old)
        esxdos_reset_cnt <= esxdos_reset_cnt + 1'd1;
end
wire [4:0] rst_kbd = {5{addr[15]}} | {4'b1111, ~|esxdos_reset_cnt};


//////////////////   MEMORY   //////////////////
wire        dma = (reset | ~nBUSACK) & ~nBUSRQ;
reg  [23:0] ram_addr;
reg   [7:0] ram_din;
reg         ram_we;
reg         ram_rd;
wire  [7:0] ram_dout;
wire        ram_ready;

always_comb begin
    casex({snap_dl | snap_reset, mmc_ram_en, page_special, addr[15:14]})
        'b1_X_X_XX: ram_addr = snap_rd ? (SNAP_ADDR + snap_dl_addr) : snap_addr;
        'b0_1_0_00: ram_addr = { 5'b01100, mmc_ram_bank, addr[12:0] };
        'b0_0_0_00: ram_addr = { 4'b0100, page_rom, addr[13:0] }; //ROM
        'b0_X_0_01: ram_addr = {   5'd0, 3'd5,     addr[13:0] }; //Non-special page modes
        'b0_X_0_10: ram_addr = {   5'd0, 3'd2,     addr[13:0] };
        'b0_X_0_11: ram_addr = {   2'd0, page_ram, addr[13:0] };
        'b0_X_1_00: ram_addr = {   5'd0,                       |page_reg_plus3[2:1], 2'b00, addr[13:0] }; //Special page modes
        'b0_X_1_01: ram_addr = {   5'd0, |page_reg_plus3[2:1], &page_reg_plus3[2:1],  1'b1, addr[13:0] };
        'b0_X_1_10: ram_addr = {   5'd0,                       |page_reg_plus3[2:1], 2'b10, addr[13:0] };
        'b0_X_1_11: ram_addr = {   5'd0,     ~page_reg_plus3[2] & page_reg_plus3[1], 2'b11, addr[13:0] };
    endcase

    casex({snap_dl | snap_reset, dma, tape_req})
        'b1XX: ram_din = snap_data;
        'b01X: ram_din = ioctl_dout;
        'b001: ram_din = 0;
        'b000: ram_din = cpu_dout;
    endcase

    casex({snap_dl | snap_reset, dma, tape_req})
        'b1XX: ram_rd = snap_rd;
        'b01X: ram_rd = 0;
        'b001: ram_rd = ~nMREQ;
        'b000: ram_rd = ~nMREQ & ~nRD;
    endcase

    casex({snap_dl | snap_reset, dma, tape_req})
        'b1XX: ram_we = snap_wr;
        'b01X: ram_we = ioctl_wr;
        'b001: ram_we = 0;
        'b000: ram_we = (mmc_ram_en | page_special | addr[15] | addr[14] | ((plusd_mem | mf128_mem) & addr[13])) & ~nMREQ & ~nWR;
    endcase
end


sdram ram(
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),
    
    .init_n(locked),
    .clk(clk_sys),
    .clkref(ce_14m),

    // port1 is CPU/tape
    .port1_req(sdram_req),
    .port1_a(sdram_addr[23:1]),
    .port1_ds(sdram_we ? {sdram_addr[0], ~sdram_addr[0]} : 2'b11),
    .port1_d({sdram_din, sdram_din}),
    .port1_q(sdram_dout),
    .port1_we(sdram_we),
    .port1_ack(sdram_ack),

    // port 2 is General Sound CPU
    .port2_req(gs_sdram_req),
    .port2_a(gs_sdram_addr[23:1]),
    .port2_ds(gs_sdram_we ? {gs_sdram_addr[0], ~gs_sdram_addr[0]} : 2'b11),
    .port2_q(gs_sdram_dout),
    .port2_d({gs_sdram_din, gs_sdram_din}),
    .port2_we(gs_sdram_we),
    .port2_ack(gs_sdram_ack)
);

assign SDRAM_CKE = 1;

// CPU/tape port control
reg  [24:0] sdram_addr;
wire [15:0] sdram_dout;
reg   [7:0] sdram_din;
wire        sdram_ack;
reg         sdram_req;
reg         sdram_we;

reg         ram_rd_old;
reg         ram_rd_old2; // use the delayed signal to wait for mf128_mem, plusd_mem, etc...
reg         ram_we_old;
wire        new_ram_req = (~ram_rd_old2 & ram_rd_old) || (~ram_we_old & ram_we);

always @(posedge clk_sys) begin

    ram_rd_old  <= ram_rd;
    ram_rd_old2 <= ram_rd_old;
    ram_we_old <= ram_we;

    if (new_ram_req) begin

        sdram_req <= ~sdram_req;
        sdram_we <= ram_we;
        sdram_din <= ram_din;

        casex({dma, tape_req})
            'b1X: sdram_addr <= ioctl_addr + (ioctl_index == 0 ? ROM_ADDR : ioctl_index == 2 ? TAPE_ADDR : SNAP_ADDR);
            'b01: sdram_addr <= tape_addr + TAPE_ADDR;
            'b00: sdram_addr <= {1'b0, ram_addr};
        endcase;

    end
end

assign ram_dout = sdram_addr[0] ? sdram_dout[15:8] : sdram_dout[7:0];
assign ram_ready = (sdram_ack == sdram_req) & ~new_ram_req;

// GS port control
wire [20:0] gs_mem_addr;
wire  [7:0] gs_mem_dout;
wire  [7:0] gs_mem_din;
wire        gs_mem_rd;
wire        gs_mem_wr;
wire        gs_mem_ready;
reg   [7:0] gs_mem_mask;

always_comb begin
    gs_mem_mask = 0;
    case(st_gs_memory)
        0: if(gs_mem_addr[20:19]) gs_mem_mask = 8'hFF; // 512K
        1: if(gs_mem_addr[20])    gs_mem_mask = 8'hFF; // 1024K
        2,3:                      gs_mem_mask = 0;
    endcase
end

reg  [24:0] gs_sdram_addr;
wire [15:0] gs_sdram_dout;
reg   [7:0] gs_sdram_din;
wire        gs_sdram_ack;
reg         gs_sdram_req;
reg         gs_sdram_we;

wire        gs_rom_we = ioctl_wr && (ioctl_index == 0);
reg         gs_mem_rd_old;
reg         gs_mem_wr_old;
wire        new_gs_mem_req = (~gs_mem_rd_old & gs_mem_rd) || (~gs_mem_wr_old & gs_mem_wr) || gs_rom_we;

always @(posedge clk_sys) begin

    gs_mem_rd_old <= gs_mem_rd;
    gs_mem_wr_old <= gs_mem_wr;

    if (new_gs_mem_req) begin
        // don't issue a new request if a read followed by a read and the current word address is the same as the previous
        if (gs_sdram_we | gs_rom_we | gs_mem_wr | gs_sdram_addr[20:1] != gs_mem_addr[20:1]) begin
            gs_sdram_req <= ~gs_sdram_req;
            gs_sdram_we <= gs_rom_we | gs_mem_wr;
            gs_sdram_din <= gs_rom_we ? ioctl_dout : gs_mem_din;
        end
        gs_sdram_addr <= gs_rom_we ? (ioctl_addr - 24'h30000) : gs_mem_addr;
    end
end

assign gs_mem_dout = gs_sdram_addr[0] ? gs_sdram_dout[15:8] : gs_sdram_dout[7:0];
assign gs_mem_ready = (gs_sdram_ack == gs_sdram_req) & ~new_gs_mem_req;

// VRAM
wire vram_sel = (ram_addr[20:16] == 1) & ram_addr[14] & ~dma & ~tape_req;

vram vram
(
    .clock(clk_sys),

    .wraddress({ram_addr[15], ram_addr[13:0]}),
    .data(ram_din),
    .wren(ram_we & vram_sel),

    .rdaddress(vram_addr),
    .q(vram_dout)
);

(* maxfan = 10 *) reg   zx48;
(* maxfan = 10 *) reg   p1024;
(* maxfan = 10 *) reg   pf1024;
(* maxfan = 10 *) reg   plus3;
reg        page_scr_copy;
reg  [7:0] page_reg;
reg  [7:0] page_reg_plus3;
reg  [7:0] page_reg_p1024;
wire       page_disable = zx48 | (~p1024 & page_reg[5]) | (p1024 & page_reg_p1024[2] & page_reg[5]);
wire       page_scr     = page_reg[3];
wire [5:0] page_ram     = {page_128k, page_reg[2:0]};
wire       page_write   = ~addr[15] & ~addr[1] & (addr[14] | ~plus3) & ~page_disable; //7ffd
wire       page_write_plus3 = ~addr[1] & addr[12] & ~addr[13] & ~addr[14] & ~addr[15] & plus3 & ~page_disable; //1ffd
wire       page_special = page_reg_plus3[0];
wire       motor_plus3 = page_reg_plus3[3];
wire       page_p1024 = addr[15] & addr[14] & addr[13] & ~addr[12] & ~addr[3]; //eff7
reg  [2:0] page_128k;

reg  [3:0] page_rom;
wire       active_48_rom = ~(mmc_rom_en | trdos_en | plusd_mem | uspeech_en) & (zx48 | (page_reg[4] & ~plus3) | (plus3 & page_reg[4] & page_reg_plus3[2] & ~page_special));

reg  [1:0] ula_type;
reg  [2:0] memory_mode;

always @(posedge clk_sys) begin
    reg [1:0] st_ula_type_old;
    reg [2:0] st_memory_mode_old;

    st_ula_type_old <= st_ula_type;
    st_memory_mode_old <= st_memory_mode;

    if(reset) begin
        ula_type <= st_ula_type;
        memory_mode <= st_memory_mode;
    end else begin
        if (st_ula_type_old != st_ula_type) ula_type <= st_ula_type;
        if (st_memory_mode_old != st_memory_mode) memory_mode <= st_memory_mode;
    end

    if(snap_hwset) {memory_mode, ula_type} <= snap_hw;
end

assign page_rom = mmc_rom_en ? 4'b0000 : //esxdos
                    trdos_en ? 4'b0001 : //trdos
                   plusd_mem ? 4'b1000 : //plusd
                   mf128_mem ? { 2'b10, plus3, ~plus3 } : //MF128/+3
                       plus3 ? { 2'b01, page_reg_plus3[2], page_reg[4] } : //+3
                  uspeech_en ? 4'b1110 : // Currah uSpeech
                               { zx48, 2'b01, zx48 | page_reg[4] }; //up to +2

reg  auto_reset_r;

always @(posedge clk_sys) begin
    reg old_reset;
    reg [2:0] rmod;

    auto_reset_r <= auto_reset;

    old_reset <= reset;
    if(~old_reset & reset) rmod <= mod;

    if(reset) begin
        page_scr_copy <= 0;
        page_reg    <= 0;
        page_reg_plus3 <= 0; 
        page_reg_p1024 <= 0;
        page_128k   <= 0;
        page_reg[4] <= auto_reset_r;
        page_reg_plus3[2] <= auto_reset_r;
        if(auto_reset_r && (rmod == 1)) begin
            p1024  <= 0;
            pf1024 <= 0;
            zx48   <= ~plus3;
        end else begin
            p1024 <= (memory_mode == 1);
            pf1024<= (memory_mode == 2);
            zx48  <= (memory_mode == 3);
            plus3 <= (memory_mode == 4);
        end
    end else if(snap_REGSet) begin
        if((snap_hw == ARCH_ZX128) || (snap_hw == ARCH_P128) || (snap_hw == ARCH_ZX3)) page_reg <= snap_7ffd;
        if(snap_hw == ARCH_ZX3) page_reg_plus3 <= snap_1ffd;
    end else begin

        if(io_wr & ~old_wr) begin
            if(page_write) begin
                page_reg  <= cpu_dout;
                if(p1024 & ~page_reg_p1024[2])  page_128k[2:0] <= { cpu_dout[5], cpu_dout[7:6] };
                if(~plusd_mem) page_scr_copy <= cpu_dout[3];
            end else if (page_write_plus3) begin
                page_reg_plus3 <= cpu_dout; 
            end
            if(pf1024 & (addr == 'hDFFD)) page_128k <= cpu_dout[2:0];
            if(p1024 & page_p1024) page_reg_p1024 <= cpu_dout;
        end
    end
end


////////////////////  ULA PORT  ///////////////////
reg [2:0] border_color;
reg       ear_out;
reg       mic_out;

always @(posedge clk_sys) begin

    if(reset) {ear_out, mic_out} <= 2'b00;
    else if(~ula_nWR) begin
        border_color <= cpu_dout[2:0];
        ear_out <= cpu_dout[4]; 
        mic_out <= cpu_dout[3];
    end
    if(snap_REGSet) border_color <= snap_border;
end


////////////////////   AUDIO   ///////////////////
wire  [7:0] sound_data;
wire [10:0] psg_left;
wire [10:0] psg_right;
wire        psg_enable = addr[0] & addr[15] & ~addr[1];
wire        psg_we     = psg_enable & ~nIORQ & ~nWR & nM1;
reg         psg_reset;

wire [7:0] ioa_out, ioa_in;
wire       midi_out = ioa_out[2];
wire       uart_out = ioa_out[3];
`ifdef SIDI128_EXPANSION
assign     UART_RTS = ioa_out[2];
`endif
assign ioa_in[5:0] = 6'd0;
`ifdef SIDI128_EXPANSION
assign ioa_in[6] = UART_CTS;
`else
assign ioa_in[6] = 1'b0;
`endif
assign ioa_in[7] = UART_RX;

// Turbosound card (Dual AY/YM chips)
turbosound turbosound
(
    .CLK(clk_sys),
    .CE(ce_psg),
    .RESET(reset | psg_reset),
    .BDIR(psg_we),
    .BC(addr[14]),
    .DI(cpu_dout),
    .DO(sound_data),
    .AUDIO_L(psg_left),
    .AUDIO_R(psg_right),

    .IOA_in(ioa_in),
    .IOA_out(ioa_out),
    .IOB_in(0),
    .IOB_out()

);

// General Sound
wire  [7:0] gs_dout;
wire [14:0] gs_l, gs_r;
wire gs_sel = (addr[7:0] ==? 'b1011?011) & ~&st_gs_memory;

reg [3:0] gs_ce_count;

always @(posedge clk_sys) begin
    reg gs_no_wait;

    if(reset) begin
        gs_ce_count <= 0;
        gs_no_wait <= 1;
    end else begin
        if (gs_ce_p) gs_no_wait <= 0;
        if (gs_mem_ready) gs_no_wait <= 1;
        if (gs_ce_count == 4'd7) begin
            if (gs_mem_ready | gs_no_wait) gs_ce_count <= 0;
        end else
            gs_ce_count <= gs_ce_count + 1'd1;

    end
end

// 14 MHz (112MHz/8) clock enable for GS card
wire gs_ce_p = gs_ce_count == 0;
wire gs_ce_n = gs_ce_count == 4;

gs #(.INT_DIV(373)) gs
(
    .RESET(reset),
    .CLK(clk_sys),
    .CE_N(gs_ce_n),
    .CE_P(gs_ce_p),

    .A(addr[3]),
    .DI(cpu_dout),
    .DO(gs_dout),
    .CS_n(~nM1 | nIORQ | ~gs_sel),
    .WR_n(nWR),
    .RD_n(nRD),

    .MEM_ADDR(gs_mem_addr),
    .MEM_DI(gs_mem_din),
    .MEM_DO(gs_mem_dout | gs_mem_mask),
    .MEM_RD(gs_mem_rd),
    .MEM_WR(gs_mem_wr),
    .MEM_WAIT(~gs_mem_ready),

    .OUTL(gs_l),
    .OUTR(gs_r)
);

// Covox/SounDrive
reg [7:0] sd_l0, sd_l1, sd_r0, sd_r1;

wire ext_mem = trdos_en | plusd_mem | uspeech_en;
wire covox_cs = ~ext_mem & ~nIORQ & ~nWR & nM1 && addr[7:0] == 8'hFB;
wire soundrive_a_cs = ~ext_mem & ~nIORQ & ~nWR & nM1 && addr[7:0] == 8'h0F;
wire soundrive_b_cs = ~ext_mem & ~nIORQ & ~nWR & nM1 && addr[7:0] == 8'h1F;
wire soundrive_c_cs = ~ext_mem & ~nIORQ & ~nWR & nM1 && addr[7:0] == 8'h4F;
wire soundrive_d_cs = ~ext_mem & ~nIORQ & ~nWR & nM1 && addr[7:0] == 8'h5F;

always @(posedge clk_sys) begin
    if (reset | ~st_covox) begin
        sd_l0 <= 8'h0;
        sd_l1 <= 8'h0;
        sd_r0 <= 8'h0;
        sd_r1 <= 8'h0;
    end
    else begin
        if (covox_cs || soundrive_a_cs) sd_l0 <= cpu_dout;
        if (covox_cs || soundrive_b_cs) sd_l1 <= cpu_dout;
        if (covox_cs || soundrive_c_cs) sd_r0 <= cpu_dout;
        if (covox_cs || soundrive_d_cs) sd_r1 <= cpu_dout;
    end
end

// Currah uSpeech
reg         uspeech_en;
reg   [8:0] uspeech_clk_cnt;
reg         uspeech_clk_en; // 250 kHz
reg         uspeech_hifreq; // intonation flag, ~7% more clock frequency to SP0256
wire        sp0256_sel = uspeech_en && addr[15:12] == 4'h1;
wire        sp0256_rdy;
wire  [9:0] sp0256_out;

always @(posedge clk_sys) begin

    reg old_nRD, old_nWR;
    old_nRD <= nRD;
    old_nWR <= nWR;

    if(reset) begin
        uspeech_en <= 0;
        uspeech_clk_en <= 0;
        uspeech_clk_cnt <= 0;
        uspeech_hifreq <= 0;
    end else begin
        if(((old_nRD & ~nRD) | (old_nWR & ~nWR)) && addr == 16'h0038 && st_uspeech) begin
            //page in/out for port IN
            uspeech_en <= !uspeech_en;
        end

        if (uspeech_en && ~nWR && addr[15:12] == 4'h3)
            uspeech_hifreq <= addr[0];

        uspeech_clk_en <= 0;
        uspeech_clk_cnt <= uspeech_clk_cnt + 1'd1;
        if (uspeech_clk_cnt == 447 || (uspeech_hifreq && uspeech_clk_cnt == 415)) begin
            uspeech_clk_en <= 1;
            uspeech_clk_cnt <= 0;
        end
    end
end

sp0256 sp0256 (
    .clock(clk_sys),
    .clock_250k_en(uspeech_clk_en),
    .reset(reset),

    .input_rdy(sp0256_rdy),
    .allophone(cpu_dout[5:0]),
    .trig_allophone(sp0256_sel & ~nWR),

    .audio_out(sp0256_out)
);

// Final audio signal mixing
wire [15:0] audio_mix_l = {~gs_l[14], gs_l[13:0]} + {1'd0, psg_left,  3'd0} + {2'd0, sd_l0, 4'd0} + {2'd0, sd_l1, 4'd0} + {3'd0, ear_out, mic_out, tape_in, 9'd0} + {sp0256_out, 4'd0};
wire [15:0] audio_mix_r = {~gs_r[14], gs_r[13:0]} + {1'd0, psg_right, 3'd0} + {2'd0, sd_r0, 4'd0} + {2'd0, sd_r1, 4'd0} + {3'd0, ear_out, mic_out, tape_in, 9'd0} + {sp0256_out, 4'd0};


////////////////////   VIDEO   ///////////////////
(* maxfan = 10 *) wire        ce_cpu_sn;
(* maxfan = 10 *) wire        ce_cpu_sp;
wire [14:0] vram_addr;
wire  [7:0] vram_dout;
wire  [7:0] port_ff;
wire        ulap_sel;
wire  [7:0] ulap_dout;
wire        ula_tape_in;

reg mZX, m128;
always_comb begin
    case(ula_type)
              0: {mZX, m128} <= 2'b10;
              1: {mZX, m128} <= 2'b11;
        default: {mZX, m128} <= 2'b00;
    endcase
end

wire [2:0] Rx, Gx, Bx;
wire       HSync, VSync, HBlank, VBlank;
wire       ulap_ena, ulap_mono, mode512;
wire       ulap_avail = ~status[14] & ~trdos_en;
wire       tmx_avail = ~status[13] & ~trdos_en;
wire       snow_ena = &turbo & ~plus3 & ~st_unrainer;
wire       ula_nWR;

ULA ULA(.*, .nPortRD(), .nPortWR(ula_nWR), .din(cpu_dout), .page_ram(page_ram[2:0]));

mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(11), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (
    .clk_sys     ( clk_sys    ),

    // OSD SPI interface
    .SPI_SCK     ( SPI_SCK    ),
    .SPI_SS3     ( SPI_SS3    ),
    .SPI_DI      ( SPI_DI     ),

    // scanlines (00-none 01-25% 10-50% 11-75%)
    .scanlines   ( st_scanlines  ),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider  ( 3'd7       ),

    // 0 = HVSync 31KHz, 1 = CSync 15KHz
    .scandoubler_disable ( scandoubler_disable ),
    // disable csync without scandoubler
    .no_csync    ( no_csync   ),
    // YPbPr always uses composite sync
    .ypbpr       ( ypbpr      ),
    // Rotate OSD [0] - rotate [1] - left or right
    .rotate      ( 2'b00      ),
    // composite-like blending
    .blend       ( 1'b0       ),

    // video in
    .R           ( Rx ),
    .G           ( Gx ),
    .B           ( Bx ),

    .HSync       ( HSync      ),
    .VSync       ( VSync      ),

    // MiST video output signals
    .VGA_R       ( VGA_R      ),
    .VGA_G       ( VGA_G      ),
    .VGA_B       ( VGA_B      ),
    .VGA_VS      ( VGA_VS     ),
    .VGA_HS      ( VGA_HS     )
);

`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd112_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(audio_mix_l),
    .right_chan(audio_mix_r)
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
    HDMI_BCK <= I2S_BCK;
    HDMI_LRCK <= I2S_LRCK;
    HDMI_SDATA <= I2S_DATA;
end
`endif
`endif



////////////////////   HID   ////////////////////
wire [11:1] Fn;
wire  [2:0] mod;
wire  [4:0] key_data;
keyboard kbd( .* );

reg   [7:0] joy_kempston;
reg   [4:0] joy_sinclair1;
reg   [4:0] joy_sinclair2;
reg   [4:0] joy_cursor;

always @(*) begin
    joy_kempston = 8'h0;
    joy_sinclair1 = 5'h0;
    joy_sinclair2 = 5'h0;
    joy_cursor = 5'h0;
    case (st_joy1)
        2'b00: joy_sinclair1 |= joystick_0[4:0];
        2'b01: joy_sinclair2 |= joystick_0[4:0];
        2'b10: joy_kempston  |= {joystick_0[9:8], joystick_0[5:0]};
        2'b11: joy_cursor    |= joystick_0[4:0];
        default: ;
    endcase
    case (st_joy2)
        2'b00: joy_sinclair1 |= joystick_1[4:0];
        2'b01: joy_sinclair2 |= joystick_1[4:0];
        2'b10: joy_kempston  |= {joystick_1[9:8], joystick_1[5:0]};
        2'b11: joy_cursor    |= joystick_1[4:0];
        default: ;
    endcase
end

wire [4:0] joy_kbd = ({5{addr[12]}} | ~({joy_sinclair1[1:0], joy_sinclair1[2], joy_sinclair1[3], joy_sinclair1[4]} | {joy_cursor[2], joy_cursor[3], joy_cursor[0], 1'b0, joy_cursor[4]})) & 
                     ({5{addr[11]}} | ~({joy_sinclair2[4:2], joy_sinclair2[0], joy_sinclair2[1]} | {joy_cursor[1], 4'b0000}));

reg         mouse_sel;
wire  [7:0] mouse_data;
mouse mouse( .*, .reset(cold_reset), .addr(addr[10:8]), .sel(), .dout(mouse_data));

always @(posedge clk_sys) begin
    reg old_status = 0;
    old_status <= ps2_mouse[24];

    if(joy_kempston[7:0]) mouse_sel <= 0;
    if(old_status != ps2_mouse[24]) mouse_sel <= 1;
end


//////////////////   MF128   ///////////////////
reg         mf128_mem;
reg         mf128_en; // enable MF128 page-in from NMI till reset (or soft off)
wire        mf128_port = ~addr[6] & addr[5] & addr[4] & addr[1];
// read paging registers saved in MF3 (7f3f, 1f3f)
wire        mf3_port = mf128_port & ~addr[7] & (addr[12:8] == 'h1f) & plus3 & mf128_en;

always @(posedge clk_sys) begin

    if(reset) {mf128_mem, mf128_en} <= 0;
    else if(~old_rd & io_rd) begin
        //page in/out for port IN
        if(mf128_port) mf128_mem <= (addr[7] ^ plus3) & mf128_en;
    end else if(~old_wr & io_wr) begin
        //Soft hide
        if(mf128_port) mf128_en <= addr[7] & mf128_en;
    end

    if(~old_m1 & m1 & (mod[0] | ~plusd_en) & st_mmc != 2'b11 & NMI_pending & (addr == 'h66)) {mf128_mem, mf128_en} <= 2'b11;
end

//////////////////   MMC   //////////////////
wire        mmc_sel;
wire  [7:0] mmc_dout;
wire        mmc_mem_en;
wire        mmc_rom_en;
wire        mmc_ram_en;
wire  [3:0] mmc_ram_bank;

wire        spi_ss;
wire        spi_clk;
wire        spi_di;
wire        spi_do;

divmmc divmmc
(
    .*,
    .enable(1),
    .disable_pagein(tape_loaded),
    .mode(st_mmc), //00-off, 01-divmmc, 10-zxmmc, 11-divmmc+esxdos
    .din(cpu_dout),
    .dout(mmc_dout),
    .active_io(mmc_sel),

    .rom_active(mmc_rom_en),
    .ram_active(mmc_ram_en),
    .ram_bank(mmc_ram_bank)
);

sd_card sd_card
(
    .clk_sys(clk_sys),
    .img_mounted(img_mounted[0]), //first slot for SD-card emulation
    .img_size(img_size),
    .sd_busy(sd_busy_mmc),
    .sd_rd(sd_rd_mmc),
    .sd_wr(sd_wr_mmc),
    .sd_lba(sd_lba_mmc),

    .sd_buff_din(sd_buff_din_mmc),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_wr(sd_buff_wr),
    .sd_buff_addr(sd_buff_addr),

    .sd_ack(sd_ack),
    .sd_ack_conf(sd_ack_conf),

    .allow_sdhc(1),
    .sd_sdhc(sd_sdhc),
    .sd_conf(sd_conf),

    .sd_cs(spi_ss),
    .sd_sck(spi_clk),
    .sd_sdi(spi_do),
    .sd_sdo(spi_di)
);

///////////////////   FDC   ///////////////////
reg         plusd_mounted;
reg         trd_mounted;
wire        plusd_en = plusd_mounted & ~plus3;
reg         plusd_mem;
wire        plusd_ena = plusd_stealth ? plusd_mem : plusd_en;
wire        fdd_sel2 = plusd_ena & &addr[7:5] & ~addr[2] & &addr[1:0];

reg         trdos_en;
wire  [7:0] wd_dout;
wire        fdd_rd;
wire        fdd_ready = (plusd_mounted & ~plus3) | trd_mounted;
reg         fdd_drive1;
reg         fdd_side;
reg         fdd_reset;
wire        fdd_intrq;
wire        fdd_drq;
wire        fdd_sel  = trdos_en & addr[2] & addr[1];
wire  [7:0] wdc_dout = (addr[7] & ~plusd_en) ? {fdd_intrq, fdd_drq, 6'h3F} : wd_dout;

reg         plus3_fdd_ready;
wire        plus3_fdd = ~addr[1] & addr[13] & ~addr[14] & ~addr[15] & plus3 & ~page_disable;
wire [7:0]  u765_dout;

wire  [7:0] fdd_dout = plus3_fdd ? u765_dout : wdc_dout;

//
// current +D implementation notes:
// 1) all +D ports (except page out port) are disabled if +D memory isn't paged in.
// 2) only possible way to page in is through hooks at h08, h3A, h66 addresses.
//
// This may break compatibility with some apps written specifically for +D using 
// direct port access (badly written apps), but won't introduce
// incompatibilities with +D unaware apps.
//
wire        plusd_stealth = 1;

// read video page.
// available for MF128 and PlusD(patched).
wire        portBF = mf128_port & addr[7] & (mf128_mem | plusd_mem);

always @(posedge clk_sys) begin
    reg old_mounted;

    old_mounted <= img_mounted[1];
    if(~old_mounted & img_mounted[1])   begin
        plus3_fdd_ready <= ioctl_ext_index == 2 & |img_size;
        trd_mounted     <= ioctl_ext_index == 0 & |img_size;
        plusd_mounted   <= (ioctl_ext_index == 1 | ioctl_ext_index == 3) & |img_size;
    end

    psg_reset <= 0;
    if(reset) {plusd_mem, trdos_en} <= 0;
    else if(plusd_en) begin
        trdos_en <= 0;
        if(~old_wr & io_wr  & (addr[7:0] == 'hEF) & plusd_ena) {fdd_side, fdd_drive1} <= {cpu_dout[7], cpu_dout[1:0] != 2};
        if(~old_wr & io_wr  & (addr[7:0] == 'hE7)) plusd_mem <= 0;
        if(~old_rd & io_rd  & (addr[7:0] == 'hE7) & ~plusd_stealth) plusd_mem <= 1;
        if(~old_m1 & m1 & st_mmc != 2'b11 & ((addr == 'h08) | (addr == 'h3A) | (~mod[0] & addr == 'h66))) {psg_reset,plusd_mem} <= {(addr == 'h66), 1'b1};
    end else begin
        plusd_mem <= 0;
        if(~old_wr & io_wr & fdd_sel & addr[7]) {fdd_side, fdd_reset, fdd_drive1} <= {~cpu_dout[4], ~cpu_dout[2], !cpu_dout[1:0]};
        if(m1 && ~old_m1) begin
            if(addr[15:14]) trdos_en <= 0;
                else if((addr[13:8] == 'h3D) & active_48_rom & st_mmc != 2'b11) trdos_en <= 1;
                //else if(~mod[0] & (addr == 'h66)) trdos_en <= 1;
        end
    end
end

fdc1772 #(.FD_NUM(1), .INVERT_HEAD_RA(1), .MODEL(3)) fdc1772
(
    .clkcpu(clk_sys),
    .clk8m_en(ce_8m),

    .floppy_drive(!fdd_drive1),
    .floppy_side(!fdd_side),
    .floppy_reset(!((fdd_reset & ~plusd_en) | reset)),
    .floppy_step(),
    .floppy_motor(),
    .floppy_ready(),

    // interrupts
    .irq(fdd_intrq),
    .drq(fdd_drq), // data request

    .cpu_addr(plusd_en ? addr[4:3] : addr[6:5]),
    .cpu_sel((fdd_sel2 | (fdd_sel & ~addr[7])) & ~nIORQ & nM1 & (~nWR | ~nRD)),
    .cpu_rw(nWR),
    .cpu_din(cpu_dout),
    .cpu_dout(wd_dout),

    .img_type(ioctl_ext_index == 1 ? 3'd5 : (ioctl_ext_index == 3 ? 3'd1 : 3'd4)),
    .img_mounted(img_mounted[1]),
    .img_size(ioctl_ext_index == 2 ? 0 : img_size),
    .img_ds(1'b1),
    .sd_lba(sd_lba_wd),
    .sd_rd(sd_rd_wd),
    .sd_wr(sd_wr_wd),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din_wd),
    .sd_dout_strobe(sd_buff_wr)
);

u765 #(20'd1800,1) u765
(
    .clk_sys(clk_sys),
    .ce(ce_u765),
    .reset(reset),
    .a0(addr[12]),
    .ready(plus3_fdd_ready),
    .motor(motor_plus3),
    .available(2'b01),
    .fast(1),
    .nRD(~plus3_fdd | nIORQ | ~nM1 | nRD),
    .nWR(~plus3_fdd | nIORQ | ~nM1 | nWR),
    .din(cpu_dout),
    .dout(u765_dout),

    .img_mounted(img_mounted[1]),
    .img_size(ioctl_ext_index == 2 ? img_size : 0),
    .img_wp(0),
    .sd_lba(sd_lba_plus3),
    .sd_rd(sd_rd_plus3),
    .sd_wr(sd_wr_plus3),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din_plus3),
    .sd_buff_wr(sd_buff_wr)
);

///////////////////   TAPE   ///////////////////
wire [24:0] tape_addr;
wire        tape_req;
wire        tape_dout_en;
wire        tape_turbo;
wire  [7:0] tape_dout;
wire        tape_led;
wire        tape_active;
wire        tape_loaded;
wire        tape_in;
wire        tape_vin;

smart_tape tape
(
    .*,
    .reset(cold_reset),
    .ce(ce_tape),

    .turbo(tape_turbo),
    .mode48k(page_disable),
    .pause(Fn[1]),
    .prev(Fn[2]),
    .next(Fn[3]),
    .audio_out(tape_vin),
    .led(tape_led),
    .active(tape_active),
    .available(tape_loaded),
    .req_hdr((reg_DE == 'h11) & !reg_A),

    .buff_rd_en(~nRFSH),
    .buff_rd(tape_req),
    .buff_addr(tape_addr),
    .buff_din(ram_dout),

    .ioctl_download(ioctl_download & (ioctl_index == 2)),
    .tape_size(ioctl_addr + 1'b1),
    .tape_mode(ioctl_ext_index),

    .m1(~nM1 & ~nMREQ),
    .rom_en(active_48_rom),
    .dout_en(tape_dout_en),
    .dout(tape_dout)
);

reg tape_loaded_reg = 0;
always @(posedge clk_sys) begin
    int timeout = 0;
    
    if(tape_loaded) begin
        tape_loaded_reg <= 1;
        timeout <= 100000000;
    end else begin
        if(timeout) begin
            timeout <= timeout - 1;
        end else begin
            tape_loaded_reg <= 0;
        end
    end
end

wire ear_in;
`ifdef USE_AUDIO_IN
assign ear_in = ~AUDIO_IN;
`else
assign ear_in = |unouart_act? 1'b1 : UART_RX;
`endif
assign tape_in = ~(tape_loaded_reg ? tape_vin : ear_in);
assign ula_tape_in = tape_in | ear_out | (st_issue2 & !tape_active & mic_out);

//////////////////  SNAPSHOT  //////////////////
reg          snap_dl = 0;
reg   [24:0] snap_dl_addr;
wire   [7:0] snap_dl_data;
wire         snap_dl_wr;
wire         snap_dl_wait;
reg          snap_rd = 0;
reg          snap_rd_old;
reg          snap_rd_state;

always @(posedge clk_sys) begin
    snap_rd_old <= snap_rd;

    if (ioctl_index == 3 && old_download && ~ioctl_download) begin
        snap_dl <= 1;
        snap_dl_addr <= 0;
        snap_rd_state <= 0;
        snap_dl_wr <= 0;
    end

    snap_dl_wr <= 0;
    if (snap_dl) begin
        case (snap_rd_state)
        0: // read RAM
        if (snap_dl_addr == ioctl_addr + 2'd2) begin
            snap_dl <= 0;
        end else begin
            if (snap_dl_wr) snap_dl_addr <= snap_dl_addr + 1'd1;
            if (ram_ready & ~snap_wr & ~snap_dl_wr & ~snap_dl_wait) begin
                if (~snap_rd | ~snap_rd_old)
                    snap_rd <= 1;
                else begin
                    snap_rd <= 0;
                    snap_rd_state <= 1;
                end
            end
        end
        1: // write to snapshot handler module
        begin
            snap_dl_wr <= 1;
            snap_dl_data <= ram_dout;
            snap_rd_state <= 0;
        end
        default :;
        endcase
    end
end

wire [211:0] snap_REG;
wire         snap_REGSet;
wire  [24:0] snap_addr;
wire   [7:0] snap_data;
wire         snap_wr;
wire         snap_reset;
wire         snap_hwset;
wire   [4:0] snap_hw;
wire  [31:0] snap_status;
wire   [2:0] snap_border;
wire   [7:0] snap_1ffd;
wire   [7:0] snap_7ffd;

snap_loader #(ARCH_ZX48, ARCH_ZX128, ARCH_ZX3, ARCH_P128) snap_loader
(
    .clk_sys(clk_sys),

    .ioctl_download(snap_dl),
    .ioctl_addr(snap_dl_addr),
    .ioctl_data(snap_dl_data),
    .ioctl_wr(snap_dl_wr),
    .ioctl_wait(snap_dl_wait),
    .snap_sna(ioctl_ext_index[0]),

    .ram_ready(ram_ready),

    .REG(snap_REG),
    .REGSet(snap_REGSet),

    .addr(snap_addr),
    .dout(snap_data),
    .wr(snap_wr),

    .reset(snap_reset),
    .hwset(snap_hwset),
    .hw(snap_hw),
    .hw_ack({memory_mode, ula_type}),

    .border(snap_border),
    .reg_1ffd(snap_1ffd),
    .reg_7ffd(snap_7ffd)
);


////////////////// UNO UART (WiFi)  //////////////////
wire [7:0] unouart_dout;
wire unouart_dout_oe;
wire unouart_tx;
unouart #( .CLK(112_000_000), .BPS(115200) ) unouart0(
    .clk(clk_sys),
    .rst_n(~reset),
    .nWR(nWR),
    .nRD(nRD),
    .nIORQ(nIORQ),
    .addr(addr),
    .din(cpu_dout),
    .dout(unouart_dout),
    .oe(unouart_dout_oe),
    .uart_rx(UART_RX),
    .uart_tx(unouart_tx)
);

reg VSync_old = 1'b0;
always @(posedge clk_sys)
    VSync_old <= VSync;
reg [4:0] unouart_act = 5'd0;
always @(posedge clk_sys) begin
    if (unouart_dout_oe)
        unouart_act <= 5'd1;
    else if (|unouart_act && VSync && !VSync_old)
        unouart_act <= unouart_act + 1'd1;
end


//////////////////  UART_TX  //////////////////
reg uart_tx = 1'b1;
reg mic_out_old = 1'b0;
reg midi_out_old = 1'b0;
reg unouart_tx_old = 1'b0;
reg uart_out_old = 1'b0;

always @(posedge clk_sys) begin
    if (uart_out_old != uart_out) begin
        uart_out_old <= uart_out;
        uart_tx <= uart_out;
    end
    if (mic_out_old != mic_out) begin
        mic_out_old <= mic_out;
        uart_tx <= mic_out;
    end
`ifndef USE_MIDI_PINS
    if (midi_out_old != midi_out) begin
        midi_out_old <= midi_out;
        uart_tx <= midi_out;
    end
`endif
    if (unouart_tx_old != unouart_tx || |unouart_act) begin
        unouart_tx_old <= unouart_tx;
        uart_tx <= unouart_tx;
    end
end

assign UART_TX = uart_tx;
`ifdef USE_MIDI_PINS
assign MIDI_OUT = midi_out;
`endif

endmodule
