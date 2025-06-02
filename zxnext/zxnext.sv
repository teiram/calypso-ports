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

module zxnext_calypso(
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
    output SDRAM_CKE

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


`include "build_id.v"
localparam CONF_STR = {
    "ZXN;;",
    "F,TZX,Load;",
    "T1,Start/Stop TZX;",
    `SEP
    "O34,Scanlines,Off,25%,50%,75%;",
    "O5,Blend,Off,On;",
    "O6,Joystick Swap,Off,On;",
`ifndef USE_AUDIO_IN
    "O7,Userport,Tape,UART;",
`endif
    "O8,Invert tape input,Off,On;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire  [1:0] scanlines = status[4:3];
wire        blend = status[5];
wire        joyswap = status[6];
wire        userport = status[7];
wire        pausetzx = status[1];
wire        invtapein = status[8];

assign      LED[0] = ~ioctl_downl & (tzxplayer_pause | tape_motor_led);
assign      SDRAM_CKE = 1;

// Clock generation
wire sdclk, clk_112, clk_28, clk_28n = ~clk_28, clk_14, clk_7, pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(SDRAM_CLK),
    .c1(clk_112),
    .c2(clk_28),
    .c3(clk_14),
    .c4(clk_7),
    .locked(pll_locked)
);

reg clk_28_psg_en;
reg [3:0] clk_28_div;

always @(posedge clk_28) begin
    clk_28_div <= clk_28_div + 1'd1;
    clk_28_psg_en <= clk_28_div == 0;
end

// CPU clock gen
wire        zxn_clock_contend;
wire        zxn_clock_lsb;
wire  [1:0] zxn_cpu_speed;
reg         clk_3m5_cont;
wire        clk_cpu;

always @(posedge clk_7, posedge reset) begin
    if (reset)
        clk_3m5_cont <= 0;
    else if (zxn_clock_lsb & !zxn_clock_contend)
        clk_3m5_cont <= 0;
    else if (!zxn_clock_lsb)
        clk_3m5_cont <= 1;
end

reg  [3:0] clk_select;
always @(posedge clk_28, posedge reset) begin
    if (reset) begin
        clk_select <= 4'b0001;
    end
    else if (zxn_ram_a_rfsh) begin
        case (zxn_cpu_speed)
        2'b00: clk_select <= 4'b0001;
        2'b01: clk_select <= 4'b0010;
        2'b10: clk_select <= 4'b0100;
        2'b11: clk_select <= 4'b1000;
        endcase
    end
end

clock_mux clocks({clk_28, clk_14, clk_7, clk_3m5_cont},clk_select,clk_cpu);

// Reset
reg        reset = 1;
wire       zxn_reset_soft;
wire       zxn_reset_hard;
reg [27:0] reset_cnt;

always @(posedge clk_28, negedge pll_locked) begin
    if (!pll_locked) begin
        reset <= 1;
        reset_cnt <= 28'hfffffff;
    end else begin
        if (status[0] | buttons[1] | zxn_reset_soft | zxn_reset_hard)
            reset_cnt <= 16'hffff;
        else if (reset_cnt != 0)
            reset_cnt <= reset_cnt - 1'd1;

        reset <= (reset_cnt != 0);
    end
end


/////////////////  IO  ///////////////////////////

wire [63:0] status;
wire [1:0] buttons;

wire [15:0] joy0, joy1;

wire scandoubler_disable;
wire no_csync;
wire ypbpr;


wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire signed [8:0] mouse_x;
wire signed [8:0] mouse_y;
wire signed [3:0] mouse_z;
wire  [7:0] mouse_flags;
wire        mouse_strobe;

wire        sd_busy;
wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
wire        sd_conf;
wire        sd_sdhc;
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire  [8:0] sd_buff_addr;
wire        sd_ack_conf;
wire  [1:0] img_mounted;
wire [31:0] img_size;


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .ROM_DIRECT_UPLOAD(DIRECT_UPLOAD),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
    .clk_sys(clk_28),
    .clk_sd(clk_28),

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

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .mouse_x(mouse_x),
    .mouse_y(mouse_y),
    .mouse_z(mouse_z),
    .mouse_flags(mouse_flags),
    .mouse_strobe(mouse_strobe),

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_conf(sd_conf),
    .sd_sdhc(sd_sdhc),
    .sd_dout(sd_dout),
    .sd_dout_strobe(sd_dout_strobe),
    .sd_din(sd_din),
    .sd_buff_addr(sd_buff_addr),
    .sd_ack_conf(sd_ack_conf),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joy0),
    .joystick_1(joy1)
);

reg signed  [3:0] zxn_mouse_wheel;
reg signed  [7:0] zxn_mouse_x;
reg signed  [7:0] zxn_mouse_y;
reg   [2:0] zxn_mouse_button;

always @(posedge clk_28) begin
    if (mouse_strobe) begin
        zxn_mouse_x <= zxn_mouse_x + mouse_x;
        zxn_mouse_y <= zxn_mouse_y + mouse_y;
        zxn_mouse_wheel <= zxn_mouse_wheel + mouse_z;
        zxn_mouse_button <= mouse_flags[2:0];
    end
end

wire [10:0] zxn_joy_left =  joyswap ? joy0[10:0] : joy1[10:0];
wire [10:0] zxn_joy_right = joyswap ? joy1[10:0] : joy0[10:0];
wire  [2:0] zxn_joy_left_type;
wire  [2:0] zxn_joy_right_type;
wire        zxn_joy_io_mode_en;

// SD Card
wire zxn_spi_ss_sd0_n;
wire zxn_spi_sck;
wire zxn_spi_mosi;
wire sd_miso_i;

sd_card sd_card (
    // connection to io controller
    .clk_sys      ( clk_28         ),
    .sd_lba       ( sd_lba         ),
    .sd_rd        ( sd_rd[0]       ),
    .sd_wr        ( sd_wr[0]       ),
    .sd_ack       ( sd_ack         ),
    .sd_ack_conf  ( sd_ack_conf    ),
    .sd_conf      ( sd_conf        ),
    .sd_sdhc      ( sd_sdhc        ),
    .sd_buff_dout ( sd_dout        ),
    .sd_buff_wr   ( sd_dout_strobe ),
    .sd_buff_din  ( sd_din         ),
    .sd_buff_addr ( sd_buff_addr   ),
    .img_mounted  ( img_mounted[0] ),
    .img_size     ( img_size       ),
    .allow_sdhc   ( 1'b1           ),
    .sd_busy      ( sd_busy        ),

    // connection to local CPU
    .sd_cs        ( zxn_spi_ss_sd0_n ),
    .sd_sck       ( zxn_spi_sck      ),
    .sd_sdi       ( zxn_spi_mosi     ),
    .sd_sdo       ( sd_miso_i        )
);



// data io (TZX upload)
wire        ioctl_downl;
wire        ioctl_upl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD)) data_io(
    .clk_sys       ( clk_28       ),
    .SPI_SCK       ( SPI_SCK      ),
    .SPI_SS2       ( SPI_SS2      ),
    .SPI_SS4       ( SPI_SS4      ),
    .SPI_DI        ( SPI_DI       ),
    .SPI_DO        ( SPI_DO       ),
    .ioctl_download( ioctl_downl  ),
    .ioctl_upload  ( ioctl_upl    ),
    .ioctl_index   ( ioctl_index  ),
    .ioctl_wr      ( ioctl_wr     ),
    .ioctl_addr    ( ioctl_addr   ),
    .ioctl_dout    ( ioctl_dout   ),
    .ioctl_din     ( ioctl_din    )
);

wire        tzx_download = ioctl_downl & ioctl_index == 1;
reg         tzx_ram_req_t;
wire [24:0] tzx_ram_addr = tzx_download ? {3'b001, ioctl_addr[21:0]} : {3'b001, tzxplayer_addr[21:0]};
wire [15:0] tzx_ram_di;
wire        tzx_ram_we = tzx_download;
wire  [7:0] tzx_ram_do = ioctl_dout;
wire        tzx_ram_ack, tzx_ram_ackD;
reg         tzx_ram_dirty;
reg         ioctl_tzx_req_t;

// TZX Player
reg  [23:0] tzxplayer_addr;
reg  [23:0] tzxplayer_last_addr;
reg  [23:0] tzxplayer_loop_addr;
wire        tzxplayer_req, tzxplayer_reqD;
wire        tzxplayer_ack;
wire        tzxplayer_audio;
reg   [7:0] tzxplayer_din;
reg         tzxplayer_pause = 1;
wire        tzxplayer_running;
reg         status_pauseD;
wire        tzxplayer_loop_start, tzxplayer_loop_startD;
wire        tzxplayer_loop_next, tzxplayer_loop_nextD;
wire        tzxplayer_stop, tzxplayer_stopD;
wire        tzxplayer_stop48k;

always @(posedge clk_28) begin
    tzx_ram_ackD <= tzx_ram_ack;
    tzxplayer_loop_startD <= tzxplayer_loop_start;
    tzxplayer_loop_nextD <= tzxplayer_loop_next;
    tzxplayer_stopD <= tzxplayer_stop;
    tzxplayer_reqD <= tzxplayer_req;
    tzx_ram_ackD <= tzx_ram_ack;

    if (reset) begin
        tzxplayer_addr <= 0;
        tzxplayer_last_addr <= 0;
        tzxplayer_loop_addr <= 0;
        tzxplayer_pause <= 1;
        tzx_ram_dirty <= 0;
    end else if (tzx_download) begin
        if (ioctl_wr) tzx_ram_req_t <= ~tzx_ram_req_t;
        tzxplayer_addr <= 0;
        tzxplayer_last_addr <= ioctl_addr[23:0];
        tzxplayer_loop_addr <= 0;
        tzxplayer_pause <= 1;
        tzx_ram_dirty <= 0;
    end else begin
        if (tzxplayer_reqD ^ tzxplayer_req) begin
            // TZXPlayer requests a new byte
            if (tzxplayer_addr == tzxplayer_last_addr + 1'd1) // end?
                tzxplayer_pause <= 1;
            else if (tzx_ram_dirty | ~tzxplayer_addr[0]) // ask the sdram for even bytes only
                tzx_ram_req_t <= ~tzx_ram_req_t;
        end
        if ((tzx_ram_ackD ^ tzx_ram_ack) | (~tzx_ram_dirty & tzxplayer_addr[0] & (tzxplayer_reqD ^ tzxplayer_req))) begin
            tzxplayer_din <= tzxplayer_addr[0] ? tzx_ram_di[7:0] : tzx_ram_di[15:8];
            tzxplayer_ack <= tzxplayer_req;
            tzxplayer_addr <= tzxplayer_addr + 1'd1;
            tzx_ram_dirty <= 0;
        end

        if (!tzxplayer_stopD & tzxplayer_stop) tzxplayer_pause <= 1;
        if (!tzxplayer_loop_startD & tzxplayer_loop_start) tzxplayer_loop_addr <= tzxplayer_addr;
        if (!tzxplayer_loop_nextD & tzxplayer_loop_next) begin
            tzxplayer_addr <= tzxplayer_loop_addr;
            tzx_ram_dirty <= 1;
        end

        status_pauseD <= pausetzx;
        if (!status_pauseD & pausetzx) tzxplayer_pause <= ~tzxplayer_pause;
    end
end

reg [24:0] tape_motor_cnt;
wire       tape_motor_led = tape_motor_cnt[24] ? tape_motor_cnt[23:16] > tape_motor_cnt[7:0] : tape_motor_cnt[23:16] <= tape_motor_cnt[7:0];
always @(posedge clk_28) tape_motor_cnt <= tape_motor_cnt + 1'd1;

reg        tzx_ce;
always @(*) begin
    case (clk_select)
    4'b0001: tzx_ce <= clk_28_div[2:0] == 0;
    4'b0010: tzx_ce <= clk_28_div[1:0] == 0;
    4'b0100: tzx_ce <= !clk_28_div[0];
    default: tzx_ce <= 1;
    endcase
end

tzxplayer #(.TZX_MS(3500)) tzxplayer
(
    .clk(clk_28),
    .ce(tzx_ce),
    .tzx_req(tzxplayer_req),
    .tzx_ack(tzxplayer_ack),
    .loop_start(tzxplayer_loop_start),
    .loop_next(tzxplayer_loop_next),
    .stop(tzxplayer_stop),
    .stop48k(tzxplayer_stop48k),
    .restart_tape(tzx_download),
    .host_tap_in(tzxplayer_din),
    .cass_read(tzxplayer_audio),
    .cass_motor(!tzxplayer_pause),
    .cass_running(tzxplayer_running)
);


// SDRAM
// Port A (CPU)
wire [20:0] zxn_ram_a_addr;
wire        zxn_ram_a_req;
wire        zxn_ram_a_rd_n;
wire [15:0] zxn_ram_a_di;
wire  [7:0] zxn_ram_a_do;
wire        zxn_ram_a_rfsh;
// Port B is read only (LAYER 2)
wire [20:0] zxn_ram_b_addr;
wire        zxn_ram_b_req_t;
wire [15:0] zxn_ram_b_di;

wire        sdram_cpuwait;
wire        sdram_cpuwait2;

sdram sdram(
    .*,
    .init_n        ( pll_locked      ),
    .clk           ( clk_112         ),
    .refresh_en    ( /*zxn_cpu_rfsh_n*/zxn_ram_a_rfsh & ~zxn_rgb_hb_n ),
    .reqA          ( zxn_ram_a_req_reg ),
    .addrA         ( zxn_ram_a_addr  ),
    .weA           ( zxn_ram_a_rd_n  ),
    .dinA          ( zxn_ram_a_do    ),
    .doutA         ( zxn_ram_a_di    ),      // data output to cpu
    .cpuwait       ( sdram_cpuwait   ),
    .cpuwait2      ( sdram_cpuwait2  ),

    .reqB          ( zxn_ram_b_req_t ),
    .addrB         ( zxn_ram_b_addr  ),
    .doutB         ( zxn_ram_b_di    ),

    .reqC          ( tzx_ram_req_t   ),
    .addrC         ( tzx_ram_addr    ),
    .doutC         ( tzx_ram_di      ),
    .weC           ( tzx_ram_we      ),
    .dinC          ( tzx_ram_do      ),
    .ackC          ( tzx_ram_ack     )
);

// Wait generator
reg         sdram_cpuwaitD;
reg         cpu_mreqD;
reg         wait_t1t2;
reg         zxn_ram_a_req_reg;

always @(posedge clk_112) zxn_ram_a_req_reg <= zxn_ram_a_req;

always @(posedge clk_cpu)   sdram_cpuwaitD <= sdram_cpuwait;

wire        zxn_ram_a_wait = (clk_select[2] & ((sdram_cpuwait & ~zxn_cpu_wr_n) | (sdram_cpuwaitD & ~zxn_cpu_rd_n))) | // for 14MHz (wait when necessary)
                             (clk_select[3] & sdram_cpuwait2); // for 28MHz

wire        zxn_ram_a_wait_n = ~(zxn_ram_a_wait & zxn_ram_a_req);

reg         zxn_spi_miso;
always @(posedge clk_cpu)   zxn_spi_miso <= sd_miso_i;

// ZX Next instance

wire        zxn_bus_wait_n = 1;
wire        zxn_bus_nmi_n = 1;
wire        zxn_bus_int_n = 1;
wire        zxn_bus_busreq_n = 1;
wire        zxn_bus_romcs_n = 1;
wire        zxn_bus_iorqula_n = 1;
wire        zxn_cpu_rfsh_n;
wire        zxn_cpu_mreq_n;
wire        zxn_cpu_iorq_n;
wire        zxn_cpu_rd_n;
wire        zxn_cpu_wr_n;

wire  [8:0] zxn_rgb;
wire        zxn_rgb_cs_n;
wire        zxn_rgb_hs_n;
wire        zxn_rgb_vs_n;
wire  [1:0] zxn_video_scanlines;
wire        zxn_rgb_vb_n;
wire        zxn_rgb_hb_n;
wire  [2:0] zxn_machine_timing;
wire        zxn_video_scandouble_en;

zxnext #(
    .g_machine_id(`MACHINE_ID),
    .g_version(8'h32),
    .g_sub_version(8'h0A),
    .g_board_issue(4'h2),
    .g_video_def(3'h0)
) zxnext_instance (

    // CLOCK

    .i_CLK_28            (clk_28),
    .i_CLK_28_n          (clk_28n),
    .i_CLK_14            (clk_14),
    .i_CLK_7             (clk_7),
    .i_CLK_CPU           (clk_cpu),
    .i_CLK_PSG_EN        (clk_28_psg_en),

    .o_CPU_SPEED         (zxn_cpu_speed),
    .o_CPU_CONTEND       (zxn_clock_contend),
    .o_CPU_CLK_LSB       (zxn_clock_lsb),

    // RESET

    .i_RESET             (reset),

    .o_RESET_SOFT        (zxn_reset_soft),
    .o_RESET_HARD        (zxn_reset_hard),
    .o_RESET_PERIPHERAL  (/*zxn_reset_peripheral*/),

    // FLASH BOOT

    .o_FLASH_BOOT        (/*zxn_flashboot*/),
    .o_CORE_ID           (/*zxn_coreid*/),

    // SPECIAL KEYS

    .i_SPKEY_FUNCTION    (zxn_function_keys),
    .i_SPKEY_BUTTONS     (zxn_buttons),

    // MEMBRANE KEYBOARD

    .o_KBD_CANCEL        (zxn_cancel_extended_entries),

    .o_KBD_ROW           (zxn_key_row),
    .i_KBD_COL           (zxn_key_col),

    .i_KBD_EXTENDED_KEYS (zxn_extended_keys),

    // PS/2 KEYBOARD AND KEY JOYSTICK SETUP

    .o_KEYMAP_ADDR       (/*zxn_keymap_addr*/),
    .o_KEYMAP_DATA       (/*zxn_keymap_dat*/),
    .o_KEYMAP_WE         (/*zxn_keymap_we*/),
    .o_JOYMAP_WE         (/*zxn_joymap_we*/),

    // JOYSTICK

    .i_JOY_LEFT          (zxn_joy_left),
    .i_JOY_RIGHT         (zxn_joy_right),

    .o_JOY_IO_MODE_EN    (zxn_joy_io_mode_en),
    .o_JOY_IO_MODE_PIN_7 (/*zxn_joy_io_mode_pin_7*/),

    .o_JOY_LEFT_TYPE     (zxn_joy_left_type),
    .o_JOY_RIGHT_TYPE    (zxn_joy_right_type),

    // MOUSE

    .i_MOUSE_X           (zxn_mouse_x),
    .i_MOUSE_Y           (zxn_mouse_y),
    .i_MOUSE_BUTTON      (zxn_mouse_button),
    .i_MOUSE_WHEEL       (zxn_mouse_wheel[3:0]),

    .o_PS2_MODE          (/*zxn_ps2_mode*/),
    .o_MOUSE_CONTROL     (/*zxn_mouse_control*/),

    // I2C

    .i_I2C_SCL_n         (zxn_i2c_scl_n_i),
    .i_I2C_SDA_n         (zxn_i2c_sda_n_i),

    .o_I2C_SCL_n         (zxn_i2c_scl_n_o),
    .o_I2C_SDA_n         (zxn_i2c_sda_n_o),

    // SPI

    .o_SPI_SS_FLASH_n    (/*zxn_spi_ss_flash_n*/),
    .o_SPI_SS_SD1_n      (/*zxn_spi_ss_sd1_n*/),
    .o_SPI_SS_SD0_n      (zxn_spi_ss_sd0_n),

    .o_SPI_SCK           (zxn_spi_sck),
    .o_SPI_MOSI          (zxn_spi_mosi),

    .i_SPI_SD_MISO       (zxn_spi_miso),
    .i_SPI_FLASH_MISO    (/*flash_miso_i*/),

    // UART

    .i_UART0_RX          (zxn_uart0_rx),
    .o_UART0_TX          (zxn_uart0_tx),

    // VIDEO
    // synchronized to i_CLK_14

    .o_RGB               (zxn_rgb),
    .o_RGB_CS_n          (zxn_rgb_cs_n),
    .o_RGB_VS_n          (zxn_rgb_vs_n),
    .o_RGB_HS_n          (zxn_rgb_hs_n),
    .o_RGB_VB_n          (zxn_rgb_vb_n),
    .o_RGB_HB_n          (zxn_rgb_hb_n),

    .o_VIDEO_50_60       (/*zxn_video_50_60*/),
    .o_VIDEO_SCANLINES   (/*zxn_video_scanlines*/),
    .o_VIDEO_SCANDOUBLE  (/*zxn_video_scandouble_en*/),

    .o_VIDEO_MODE        (/*zxn_video_mode*/),                     // VGA 0-6, HDMI
    .o_MACHINE_TIMING    (/*zxn_machine_timing*/),                 // video timing: 00X = 48k, 010 = 128k, 011 = +3, 100 = pentagon

    .o_HDMI_RESET        (/*zxn_hdmi_reset*/),

    // AUDIO

    .o_AUDIO_HDMI_AUDIO_EN(/*zxn_hdmi_audio*/),

    .o_AUDIO_SPEAKER_EN  (/*zxn_speaker_en*/),
    .o_AUDIO_SPEAKER_BEEP(/*zxn_speaker_beep*/),

    .i_AUDIO_EAR         (ear_port_i_qq),
    .o_AUDIO_MIC         (/*zxn_tape_mic*/),

    .o_AUDIO_SPEAKER_EAR (/*zxn_audio_ear*/),
    .o_AUDIO_SPEAKER_MIC (/*zxn_audio_mic*/),

    .o_AUDIO_L           (zxn_audio_L_pre),
    .o_AUDIO_R           (zxn_audio_R_pre),

    // EXTERNAL SRAM (synchronized to i_CLK_28)
    //memory transactions complete in one cycle, data read is registered but available asap

    // Port A is read/write (CPU)

    .o_RAM_A_ADDR        (zxn_ram_a_addr),
    .o_RAM_A_REQ2        (zxn_ram_a_req),
    .i_RAM_A_REQ_ALLOW   (!clk_select[zxn_cpu_speed]),
    .o_RAM_A_RFSH        (zxn_ram_a_rfsh),
    .o_RAM_A_RD_n        (zxn_ram_a_rd_n),
    .i_RAM_A_DI          (zxn_ram_a_addr[0] ? zxn_ram_a_di[7:0] : zxn_ram_a_di[15:8]),
    .o_RAM_A_DO          (zxn_ram_a_do),
    .i_RAM_A_WAIT_n      (zxn_ram_a_wait_n),

    // Port B is read only (LAYER 2)

    .o_RAM_B_ADDR        (zxn_ram_b_addr),
    .o_RAM_B_REQ_T       (zxn_ram_b_req_t),
    .i_RAM_B_DI          (zxn_ram_b_addr[0] ? zxn_ram_b_di[7:0] : zxn_ram_b_di[15:8]),

    // EXPANSION BUS

    .o_BUS_ADDR          (/*zxn_cpu_a*/),
    .i_BUS_DI            (/*zxn_bus_di*/),
    .o_BUS_DO            (/*zxn_cpu_do*/),
    .o_BUS_MREQ_n        (zxn_cpu_mreq_n),
    .o_BUS_IORQ_n        (zxn_cpu_iorq_n),
    .o_BUS_RD_n          (zxn_cpu_rd_n),
    .o_BUS_WR_n          (zxn_cpu_wr_n),
    .o_BUS_M1_n          (/*zxn_cpu_m1_n*/),
    .i_BUS_WAIT_n        (zxn_bus_wait_n),
    .i_BUS_NMI_n         (zxn_bus_nmi_n),
    .i_BUS_INT_n         (zxn_bus_int_n),
    .o_BUS_INT_n         (/*zxn_cpu_int_n*/),
    .i_BUS_BUSREQ_n      (zxn_bus_busreq_n),
    .o_BUS_BUSAK_n       (/*zxn_cpu_busak_n*/),
    .o_BUS_HALT_n        (/*zxn_cpu_halt_n*/),
    .o_BUS_RFSH_n        (zxn_cpu_rfsh_n),
    .o_BUS_IEO           (/*zxn_cpu_ieo*/),

    .i_BUS_ROMCS_n       (zxn_bus_romcs_n),
    .i_BUS_IORQULA_n     (zxn_bus_iorqula_n),

    .o_BUS_EN            (/*zxn_bus_en*/),
    .o_BUS_CLKEN         (/*zxn_bus_clken*/),

    .o_BUS_NMI_DEBOUNCE_DISABLE (/*zxn_bus_nmi_debounce_disable*/),

    // ESP GPIO

    .i_ESP_GPIO_20       (/*zxn_esp_gpio20_i*/),

    .o_ESP_GPIO_0        (/*zxn_esp_gpio0_o*/),
    .o_ESP_GPIO_0_EN     (/*zxn_esp_gpio0_en_o*/),

    // PI GPIO

    .i_GPIO              (/*zxn_pi_gpio_i*/),

    .o_GPIO              (/*zxn_gpio_o*/),
    .o_GPIO_EN           (/*zxn_gpio_en*/)
);

// Keyboard
wire [10:1] zxn_function_keys;
wire  [1:0] zxn_buttons;
wire        zxn_cancel_extended_entries;
wire  [7:0] zxn_key_row;
wire  [4:0] zxn_key_col = membrane_keys & joy_kbd;
wire [15:0] zxn_extended_keys;

wire  [4:0] membrane_keys;

keyboard keyboard (
    .reset        ( reset         ),
    .clk_sys      ( clk_28        ),

    .key_strobe   ( key_strobe    ),
    .key_pressed  ( key_pressed   ),
    .key_extended ( key_extended  ),
    .key_code     ( key_code      ),

    .addr         ( zxn_key_row   ),
    .key_data     ( membrane_keys ),

    .Fn           ( zxn_function_keys ),
    .mod          ( )
);

reg   [5:0] joy_kempston;
reg   [4:0] joy_sinclair1;
reg   [4:0] joy_sinclair2;
reg   [4:0] joy_cursor;

always @(*) begin
    joy_sinclair1 = 5'h0;
    joy_sinclair2 = 5'h0;
    joy_cursor = 5'h0;
    case (zxn_joy_left_type)
        3'b011: joy_sinclair1 |= zxn_joy_left[4:0];
        3'b000: joy_sinclair2 |= zxn_joy_left[4:0];
        3'b010: joy_cursor    |= zxn_joy_left[4:0];
        default: ;
    endcase
    case (zxn_joy_right_type)
        3'b011: joy_sinclair1 |= zxn_joy_right[4:0];
        3'b000: joy_sinclair2 |= zxn_joy_right[4:0];
        3'b010: joy_cursor    |= zxn_joy_right[4:0];
        default: ;
    endcase
end

wire [4:0] joy_kbd = ({5{zxn_key_row[4]}} | ~({joy_sinclair1[1:0], joy_sinclair1[2], joy_sinclair1[3], joy_sinclair1[4]} | {joy_cursor[2], joy_cursor[3], joy_cursor[0], 1'b0, joy_cursor[4]})) &
                     ({5{zxn_key_row[3]}} | ~({joy_sinclair2[1:0], joy_sinclair2[2], joy_sinclair2[3], joy_sinclair2[4]} | {joy_cursor[1], 4'b0000}));

// Video out
mist_video #(.COLOR_DEPTH(3), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video(
    .clk_sys        ( clk_28           ),
    .SPI_SCK        ( SPI_SCK          ),
    .SPI_SS3        ( SPI_SS3          ),
    .SPI_DI         ( SPI_DI           ),
    .R              ( zxn_rgb[8:6]     ),
    .G              ( zxn_rgb[5:3]     ),
    .B              ( zxn_rgb[2:0]     ),
    .HSync          ( zxn_rgb_hs_n     ),
    .VSync          ( zxn_rgb_vs_n     ),
    .VGA_R          ( VGA_R            ),
    .VGA_G          ( VGA_G            ),
    .VGA_B          ( VGA_B            ),
    .VGA_VS         ( VGA_VS           ),
    .VGA_HS         ( VGA_HS           ),
    .ce_divider     ( 1'b1             ),
    .rotate         ( 2'b00            ),
    .blend          ( blend            ),
    .scandoubler_disable(1'b1),
    .scanlines      ( scanlines        ),
    .ypbpr          ( ypbpr            ),
    .no_csync       ( no_csync         )
);

// Sound out
wire [12:0] zxn_audio_L_pre;
wire [12:0] zxn_audio_R_pre;


`ifdef I2S_AUDIO
mist_i2s_master i2s (
    .reset(1'b0),
    .clk(clk_28),
    .clk_rate(32'd28_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({~zxn_audio_L_pre[12], zxn_audio_L_pre[11:0], 3'd0}),
    .right_chan({~zxn_audio_R_pre[12], zxn_audio_R_pre[11:0], 3'd0})
);

`endif


// RTC
wire zxn_i2c_scl_n_i;
wire zxn_i2c_sda_n_i;

wire zxn_i2c_scl_n_o;
wire zxn_i2c_sda_n_o;

i2cSlaveTop DS1307 (
    .clk            ( clk_28          ),
    .rst            ( ~pll_locked     ),
    .sdaIn          ( zxn_i2c_sda_n_o ),
    .sdaOut         ( zxn_i2c_sda_n_i ),
    .scl            ( zxn_i2c_scl_n_o ),
    .we             ( 1'b0            ),
    .rd             ( 1'b0            ),
    .addr           (  ),
    .din            (  ),
    .dout           (  ),
    .RTC            (/* rtc */            )
);

// Userport
wire        zxn_uart0_rx;
wire        zxn_uart0_tx;
wire        ear_port_i_qq;

reg UART_RXd, UART_RXd2;
// always @(posedge clk_28) { UART_RXd2, UART_RXd } <= { UART_RXd, UART_RX };

`ifdef USE_AUDIO_IN
assign      ear_port_i_qq = tzxplayer_running ? ~tzxplayer_audio : (invtapein ^ AUDIO_IN);
assign      zxn_uart0_rx  = UART_RXd2;
//assign      UART_TX       = zxn_uart0_tx;
`else
assign      ear_port_i_qq = tzxplayer_running ? ~tzxplayer_audio : userport ? 1'b0 : (invtapein ^ UART_RXd2);
assign      zxn_uart0_rx  = userport ? UART_RXd2 : 1'b0;
assign      UART_TX       = userport ? zxn_uart0_tx : 1'b1;
`endif

endmodule

// From Recommended HDL Coding Styles, Quartus II 8.0 Handbook
module clock_mux (clk,clk_select,clk_out);
    parameter num_clocks = 4;
    input [num_clocks-1:0] clk;
    input [num_clocks-1:0] clk_select; // one hot
    output clk_out;
    genvar i;
    reg [num_clocks-1:0] ena_r0;
    reg [num_clocks-1:0] ena_r1;
    reg [num_clocks-1:0] ena_r2;
    wire [num_clocks-1:0] qualified_sel;
    // A look-up-table (LUT) can glitch when multiple inputs
    // change simultaneously. Use the keep attribute to
    // insert a hard logic cell buffer and prevent
    // the unrelated clocks from appearing on the same LUT.
    wire [num_clocks-1:0] gated_clks /* synthesis keep */;
    initial begin
        ena_r0 = 0;
        ena_r1 = 0;
        ena_r2 = 0;
    end
    generate
    for (i=0; i<num_clocks; i=i+1)
    begin : lp0
        wire [num_clocks-1:0] tmp_mask;

        assign qualified_sel[i] = clk_select[i] & (~|(ena_r2 & tmp_mask));
        always @(posedge clk[i]) begin
            ena_r0[i] <= qualified_sel[i];
            ena_r1[i] <= ena_r0[i];
        end
        always @(negedge clk[i]) begin
            ena_r2[i] <= ena_r1[i];
        end
        assign gated_clks[i] = clk[i] & ena_r2[i];
    end
    endgenerate
    // These will not exhibit simultaneous toggle by construction
    assign clk_out = |gated_clks;
endmodule

`ifdef I2S_AUDIO
module mist_i2s_master
(
    input        reset,
    input        clk,
    input [31:0] clk_rate,

    output reg sclk,
    output reg lrclk,
    output reg sdata,

    input [AUDIO_DW-1:0]    left_chan,
    input [AUDIO_DW-1:0]    right_chan
);

// Clock Setting
parameter I2S_Freq = 48_000;     // 48 KHz
parameter AUDIO_DW = 16;

localparam I2S_FreqX2 = I2S_Freq*2*AUDIO_DW*2;

reg  [31:0] cnt;
wire [31:0] cnt_next = cnt + I2S_FreqX2;

reg         ce;

always @(posedge clk) begin
    ce <= 0;
    cnt <= cnt_next;
    if(cnt_next >= clk_rate) begin
        cnt <= cnt_next - clk_rate;
        ce <= 1;
    end
end


always @(posedge clk) begin
    reg  [4:0] bit_cnt = 1;

    reg [AUDIO_DW-1:0] left;
    reg [AUDIO_DW-1:0] right;

    if (reset) begin
        bit_cnt <= 1;
        lrclk   <= 1;
        sclk    <= 1;
        sdata   <= 1;
        sclk    <= 1;
    end
    else begin
        if(ce) begin
            sclk <= ~sclk;
            if(sclk) begin
                if(bit_cnt == AUDIO_DW) begin
                    bit_cnt <= 1;
                    lrclk <= ~lrclk;
                    if(lrclk) begin
                        left  <= left_chan;
                        right <= right_chan;
                    end
                end
                else begin
                    bit_cnt <= bit_cnt + 1'd1;
                end
                sdata <= lrclk ? right[AUDIO_DW - bit_cnt] : left[AUDIO_DW - bit_cnt];
            end
        end
    end
end

`endif

endmodule


