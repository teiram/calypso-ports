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

module pcxt_calypso(
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

assign LED[0] = ~ioctl_download; 
assign LED[1] = reset_cpu;
assign LED[2] = pause_core;
//
///////////////////////   MiST FRAMEWORK   ///////////////////////
//
// Bitmap for MiST config string options
//
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV WXYZabcdefghijklmnopqrstuvwxyz
// XttXX..XttXXXXXXXXXttXXXXXXXXtXX aaaaaattaaDDDDDD...XX.........

`include "build_id.v"
parameter CONF_STR = {
    "PCXT;;",
    "O3,Model,IBM PCXT,Tandy 1000;",
    "OHI,CPU Speed,4.77MHz,7.16MHz,9.54MHz,PC/AT 3.5MHz;",
    `SEP
    "P1,BIOS;",
    "P1F,ROM,PCXT BIOS:;",
    "P1F,ROM,Tandy BIOS:;",
    "P1F,ROM,EC00 BIOS:;",
    "P1OUV,BIOS Writable,None,EC00,PCXT/Tandy,All;",
    "P1O7,Boot Splash Screen,Yes,No;",
    "P2,Audio;",
    "P2OA,C/MS Audio,Enabled,Disabled;",
    "P2Oef,OPL2,Adlib 388h,SB FM 388h/228h, Disabled;",     //[41:40]
    "P2OWX,Speaker Volume,1,2,3,4;",
    "P2OYZ,Tandy Volume,1,2,3,4;",
    "P2Oab,Audio Boost,No,2x,4x;",
    "P3,Video;",
    "P3O4,Video Output,CGA/Tandy,MDA;",
    "P3OEG,Display,Full Color,Green,Amber,B&W,Red,Blue,Fuchsia,Purple;",
    "P3Oh,Composite Blending,No,Yes;",
    "P3Oi,Composite,Off,On;",
    "P3Ol,VGA+Compos(1pin no.osd),Off,On;",
    "P3Og,EXPER.YPbPr,Off,On;",
    "P4,Hardware;",
    "P4OB,Lo-tech 2MB EMS,Enabled,Disabled;",
    "P4OCD,EMS Frame,C000,D000,E000;",
    "P4Op,A000 UMB,Enabled,Disabled;",           //[51]
    "P4ONO,Joystick 1, Analog, Digital, Disabled;",
    "P4OPQ,Joystick 2, Analog, Digital, Disabled;",
    "P4OR,Sync Joy to CPU Speed,No,Yes;",
    "P4OS,Swap Joysticks,No,Yes;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

wire forced_scandoubler;
wire [1:0] buttons;
wire [63:0] status;
wire [7:0]  xtctl;

//Keyboard Ps2
wire        ps2_kbd_clk_out;
wire        ps2_kbd_data_out;
wire        ps2_kbd_clk_in;
wire        ps2_kbd_data_in;

//Mouse PS2
wire        ps2_mouse_clk_out;
wire        ps2_mouse_data_out;
wire        ps2_mouse_clk_in;
wire        ps2_mouse_data_in;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0]  ioctl_data;
reg         ioctl_wait;

wire [63:0] rtc_data;

wire [31:0] joy0, joy1;
wire [31:0] joya0, joya1;
wire [4:0]  joy_opts = status[27:23];

wire mda_mode = status[4] | xtctl[5];
wire [2:0] screen_mode = status[16:14];
wire a000h = ~status[51] & ~xtctl[6];
wire composite_on = status[44];
wire vga_composite = status[47];
assign forced_scandoubler = composite_on;
    
reg         mda_mode_video_ff;
reg [2:0]   screen_mode_video_ff;

wire pause_core;

// Virtual HDD Bus
wire        hdd_cmd_req;
wire        hdd_dat_req;
wire  [2:0] hdd_addr;
wire [15:0] hdd_data_out;
wire [15:0] hdd_data_in;
wire        hdd_wr;
wire        hdd_status_wr;
wire        hdd_data_wr;
wire        hdd_data_rd;
wire  [1:0] hdd0_ena;

wire  [3:0] ide0_addr;
wire [15:0] ide0_writedata;
wire [15:0] ide0_readdata;
wire        ide0_read;
wire        ide0_write;

always @(posedge clk_vid)
begin
    mda_mode_video_ff       <= mda_mode;
    screen_mode_video_ff    <= screen_mode;
end

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .PS2DIV(2000),
    .PS2BIDIR(1),
    .FEATURES(32'h1050 | (BIG_OSD << 13) | (HDMI << 14)) /* FEAT_PS2REP | FEAT_IDE0_ATA | FEAT_IDE1_ATA*/
) user_io(
    .conf_str(CONF_STR),
    .clk_sys(clk_chipset),

    // the spi interface
    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),   // tristate handling inside user_io
    .SPI_MOSI(SPI_DI),

    .status(status),
    .buttons(buttons),
    .rtc(rtc_data),

    .ps2_kbd_clk_i(ps2_kbd_clk_out),
    .ps2_kbd_data_i(ps2_kbd_data_out),
    .ps2_kbd_clk(ps2_kbd_clk_in),
    .ps2_kbd_data(ps2_kbd_data_in),

    .ps2_mouse_clk_i(ps2_mouse_clk_out),
    .ps2_mouse_data_i(ps2_mouse_data_out),
    .ps2_mouse_clk(ps2_mouse_clk_in),
    .ps2_mouse_data(ps2_mouse_data_in),

    .joystick_0(joy0),
    .joystick_1(joy1),
    .joystick_analog_0(joya0),
    .joystick_analog_1(joya1)
);

data_io #(.ENABLE_IDE(1'b1)) data_io(
    .clk_sys(clk_chipset ),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_SS4(SPI_SS4),
    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),

    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),

    // ram interface
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_data),

    .hdd_clk(clk_chipset),
    .hdd_cmd_req(hdd_cmd_req),
    .hdd_dat_req(hdd_dat_req),
    .hdd_status_wr(hdd_status_wr),
    .hdd_addr(hdd_addr),
    .hdd_wr(hdd_wr),
    .hdd_data_out(hdd_data_out ),
    .hdd_data_in(hdd_data_in),
    .hdd_data_rd(hdd_data_rd),
    .hdd_data_wr(hdd_data_wr),
    .hdd0_ena(hdd0_ena)
);

ide ide (
    .clk           ( clk_chipset ),
    .clk_en        ( 1'b1 ),
    .reset         ( reset ),
    .address_in    ( (ide0_read && ide0_addr == 4'hE) ? 3'd7 : ide0_addr[2:0] ),
    .sel_secondary ( 1'b0 ),
    .data_in       ( ide0_writedata  ),
    .data_out      ( ide0_readdata   ),
    .rd            ( ide0_read  ),
    .hwr           ( ide0_write ),
    .lwr           ( ide0_write ),
    .sel_ide       ( ide0_read | (ide0_write & !ide0_addr[3]) ),
    .intreq_ack    ( 1'b0 ),     // interrupt clear
    .hdd0_ena      ( hdd0_ena ), // enables Master & Slave drives on primary channel
    .hdd1_ena      ( 2'b00 ),    // enables Master & Slave drives on secondary channel

    // connection to the IO-Controller
    .hdd_cmd_req   ( hdd_cmd_req ),
    .hdd_dat_req   ( hdd_dat_req ),
    .hdd_status_wr ( hdd_status_wr ),
    .hdd_addr      ( hdd_addr ),
    .hdd_wr        ( hdd_wr ),
    .hdd_data_in   ( hdd_data_in ),
    .hdd_data_out  ( hdd_data_out ),
    .hdd_data_rd   ( hdd_data_rd ),
    .hdd_data_wr   ( hdd_data_wr )
);
    

//
///////////////////////   CLOCKS   /////////////////////////////
//

wire clk_sys;
wire pll_locked;

wire clk_100;
wire clk_28_636;
wire clk_56_875;
reg clk_25 = 1'b0;
reg clk_14_318 = 1'b0;
reg clk_9_54 = 1'b0;
reg clk_7_16 = 1'b0;
wire clk_4_77;
reg clk_cpu;
reg pclk;
wire clk_chipset;
reg peripheral_clock;
wire clk_uart;

localparam [27:0] cur_rate = 28'd50000000; // clk_chipset freq


pll pll(
    .inclk0(CLK12M),
    .c0(clk_100),           //100                           CLOCK_CORE
    .c1(clk_chipset),       //50                            CLOCK_CHIP
    .c2(SDRAM_CLK),         //50 -2ns
    .c3(clk_uart),          //14.7456 MHz                   CLOCK_UART
    .locked(pll_locked)
);

pllvideo pllvideo(
    .inclk0(CLK12M),
    .c0(clk_28_636),        //28.636 -> 28.636      CLOCK_VGA_CGA
    .c1(clk_56_875),        //56.875 -> 57.272      CLOCK_VGA_MDA
    .locked()
);

wire reset_wire = status[0] | buttons[1] | ~pll_locked | bios_access_request;   //bios_access_request by kitune-san to supply ioctl_wait signal

wire reset_sdram_wire = ~pll_locked;

//////////////////////////////////////////////////////////////////

// TODO: messy, use a single clock domain at least
always @(posedge clk_28_636)
    clk_14_318 <= ~clk_14_318;  // 14.318Mhz

reg [4:0] clk_9_54_cnt = 1'b0;
always @(posedge clk_chipset)
    if (4'd0 == clk_9_54_cnt) begin
        if (clk_9_54)
            clk_9_54_cnt  <= 4'd3 - 4'd1;
        else
            clk_9_54_cnt  <= 4'd2 - 4'd1;
        clk_9_54      <= ~clk_9_54;
    end
    else begin
        clk_9_54_cnt  <= clk_9_54_cnt - 4'd1;
        clk_9_54      <= clk_9_54;
    end

always @(posedge clk_chipset)
    clk_25 <= ~clk_25;

always @(posedge clk_14_318)
    clk_7_16 <= ~clk_7_16;      // 7.16Mhz

clk_div3 clk_normal             // 4.77MHz
(
    .clk(clk_14_318),
    .clk_out(clk_4_77)
);

always @(posedge clk_4_77)
    peripheral_clock <= ~peripheral_clock; // 2.385Mhz

//////////////////////////////////////////////////////////////////

logic  biu_done;
logic  [7:0] clock_cycle_counter_division_ratio;
logic  [7:0] clock_cycle_counter_decrement_value;
logic        shift_read_timing;
logic  [1:0] ram_read_wait_cycle;
logic  [1:0] ram_write_wait_cycle;
logic        cycle_accrate;
logic  [1:0] clk_select;


always @(posedge clk_chipset, posedge reset)
begin
    if (reset)
        clk_select  <= 2'b00;

    else if (biu_done)
        clk_select  <= (xtctl[3:2] == 2'b00 & ~xtctl[7]) ? status[18:17] : xtctl[7] ? 2'b11 : xtctl[3:2] - 2'b01;

    else
        clk_select  <= clk_select;

end

logic  clk_cpu_ff_1;
logic  clk_cpu_ff_2;

logic  pclk_ff_1;
logic  pclk_ff_2;

always @(posedge clk_chipset, posedge reset)
begin
    if (reset)
    begin
        clk_cpu_ff_1    <= 1'b0;
        clk_cpu_ff_2    <= 1'b0;
        clk_cpu         <= 1'b0;
        pclk_ff_1       <= 1'b0;
        pclk_ff_2       <= 1'b0;
        pclk            <= 1'b0;
        cycle_accrate   <= 1'b1;
        clock_cycle_counter_division_ratio  <= 8'd1 - 8'd1;
        clock_cycle_counter_decrement_value <= 8'd1;
        shift_read_timing                   <= 1'b0;
        ram_read_wait_cycle                 <= 2'd0;
        ram_write_wait_cycle                <= 2'd0;
    end
    else
    begin
        clk_cpu_ff_2    <= clk_cpu_ff_1;
        clk_cpu         <= clk_cpu_ff_2;
        pclk_ff_1       <= peripheral_clock;
        pclk_ff_2       <= pclk_ff_1;
        pclk            <= pclk_ff_2;
        casez (clk_select)
            2'b00: begin
                clk_cpu_ff_1    <= clk_4_77;
                clock_cycle_counter_division_ratio  <= 8'd1 - 8'd1;
                clock_cycle_counter_decrement_value <= 8'd1;
                shift_read_timing                   <= 1'b0;
                ram_read_wait_cycle                 <= 2'd0;
                ram_write_wait_cycle                <= 2'd0;
                cycle_accrate                       <= 1'b1;
            end
            2'b01: begin
                clk_cpu_ff_1    <= clk_7_16;
                clock_cycle_counter_division_ratio  <= 8'd2 - 8'd1;
                clock_cycle_counter_decrement_value <= 8'd3;
                shift_read_timing                   <= 1'b0;
                ram_read_wait_cycle                 <= 2'd0;
                ram_write_wait_cycle                <= 2'd0;
                cycle_accrate                       <= 1'b1;
            end
            2'b10: begin
                clk_cpu_ff_1    <= clk_9_54;
                clock_cycle_counter_division_ratio  <= 8'd10 - 8'd1;
                clock_cycle_counter_decrement_value <= 8'd21;
                shift_read_timing                   <= 1'b0;
                ram_read_wait_cycle                 <= 2'd0;
                ram_write_wait_cycle                <= 2'd0;
                cycle_accrate                       <= 1'b1;

            end
            2'b11: begin
                clk_cpu_ff_1    <= clk_25;
                clock_cycle_counter_division_ratio  <= 8'd1 - 8'd1;
                clock_cycle_counter_decrement_value <= 8'd5;
                shift_read_timing                   <= 1'b1;
                ram_read_wait_cycle                 <= 2'd1;
                ram_write_wait_cycle                <= 2'd0;
                cycle_accrate                       <= 1'b0;
            end
        endcase
    end
end

//////////////////////////////////////////////////////////////////

logic reset = 1'b1;
logic [15:0] reset_count = 16'h0000;
logic reset_sdram = 1'b1;
logic [15:0] reset_sdram_count = 16'h0000;

always @(posedge clk_chipset, posedge reset_wire)
begin
    if (reset_wire)
    begin
        reset <= 1'b1;
        reset_count <= 16'h0000;
    end
    else if (reset)
    begin
        if (reset_count != 16'hffff)
        begin
            reset <= 1'b1;
            reset_count <= reset_count + 16'h0001;
        end
        else
        begin
            reset <= 1'b0;
            reset_count <= reset_count;
        end
    end
    else
    begin
        reset <= 1'b0;
        reset_count <= reset_count;
    end
end

logic reset_cpu_ff = 1'b1;
logic reset_cpu = 1'b1;
logic [15:0] reset_cpu_count = 16'h0000;

always @(negedge clk_chipset, posedge reset)
begin
    if (reset)
        reset_cpu_ff <= 1'b1;
    else
        reset_cpu_ff <= reset;
end

reg tandy_mode = 0;

always @(negedge clk_chipset, posedge reset)
begin
    if (reset)
    begin
        tandy_mode <= status[3];
        reset_cpu <= 1'b1;
        reset_cpu_count <= 16'h0000;
    end
    else if (reset_cpu)
    begin
        reset_cpu <= reset_cpu_ff;
        reset_cpu_count <= 16'h0000;
    end
    else
    begin
        if (reset_cpu_count != 16'h002A)
        begin
            reset_cpu <= reset_cpu_ff;
            reset_cpu_count <= reset_cpu_count + 16'h0001;
        end
        else
        begin
            reset_cpu <= 1'b0;
            reset_cpu_count <= reset_cpu_count;
        end
    end
end

always @(posedge clk_chipset, posedge reset_sdram_wire)
begin
    if (reset_sdram_wire)
    begin
        reset_sdram <= 1'b1;
        reset_sdram_count <= 16'h0000;
    end
    else if (reset_sdram)
    begin
        if (reset_sdram_count != 16'hffff)
        begin
            reset_sdram <= 1'b1;
            reset_sdram_count <= reset_sdram_count + 16'h0001;
        end
        else
        begin
            reset_sdram <= 1'b0;
            reset_sdram_count <= reset_sdram_count;
        end
    end
    else
    begin
        reset_sdram <= 1'b0;
        reset_sdram_count <= reset_sdram_count;
    end
end

//
///////////////////////   BIOS LOADER   ////////////////////////////
//

reg [4:0]  bios_load_state = 4'h0;
reg [1:0]  bios_protect_flag;
reg        bios_access_request;
reg [19:0] bios_access_address;
reg [15:0] bios_write_data;
reg        bios_write_n;
reg [7:0]  bios_write_wait_cnt;
reg        bios_write_byte_cnt;
reg        tandy_bios_write;

wire select_pcxt  = (ioctl_index[5:0] <  2) && (ioctl_addr[24:16] == 9'b000000000);
wire select_tandy = (ioctl_index[5:0] == 2) && (ioctl_addr[24:16] == 9'b000000000);
wire select_xtide = ioctl_index == 3;

wire [19:0] bios_access_address_wire = select_pcxt  ? { 4'b1111, ioctl_addr[15:0]} :
     select_tandy ? { 4'b1111, ioctl_addr[15:0]} :
     select_xtide ? { 6'b111011, ioctl_addr[13:0]} :
     20'hFFFFF;

wire bios_load_n = ~(ioctl_download & (select_pcxt | select_tandy | select_xtide));

always @(posedge clk_chipset, posedge reset_sdram)
begin
    if (reset_sdram)
    begin
        bios_protect_flag   <= 2'b11;
        bios_access_request <= 1'b0;
        bios_access_address <= 20'hFFFFF;
        bios_write_data     <= 16'hFFFF;
        bios_write_n        <= 1'b1;
        bios_write_wait_cnt <= 'h0;
        bios_write_byte_cnt <= 1'h0;
        tandy_bios_write    <= 1'b0;
        ioctl_wait          <= 1'b1;
        bios_load_state     <= 4'h00;
    end
    else if (~initilized_sdram)
    begin
        bios_protect_flag   <= 2'b11;
        bios_access_request <= 1'b0;
        bios_access_address <= 20'hFFFFF;
        bios_write_data     <= 16'hFFFF;
        bios_write_n        <= 1'b1;
        bios_write_wait_cnt <= 'h0;
        bios_write_byte_cnt <= 1'h0;
        ioctl_wait          <= 1'b1;
        bios_load_state     <= 4'h00;
    end
    else
    begin
        casez (bios_load_state)
            4'h00:
            begin
                bios_protect_flag   <= ~status[31:30];  // bios_writable
                bios_access_address <= 20'hFFFFF;
                bios_write_data     <= 16'hFFFF;
                bios_write_n        <= 1'b1;
                bios_write_wait_cnt <= 'h0;
                bios_write_byte_cnt <= 1'h0;
                tandy_bios_write    <= 1'b0;

                if (~ioctl_download)
                begin
                    bios_access_request <= 1'b0;
                    ioctl_wait          <= 1'b0;
                end
                else
                begin
                    bios_access_request <= 1'b1;
                    ioctl_wait          <= 1'b1;
                end

                if ((ioctl_download) && (~processor_ready) && (address_direction))
                    bios_load_state <= 4'h01;
                else
                    bios_load_state <= 4'h00;
            end
            4'h01:
            begin
                bios_protect_flag   <= 2'b00;
                bios_access_request <= 1'b1;
                bios_write_byte_cnt <= 1'h0;
                tandy_bios_write    <= select_tandy;

                if (~ioctl_download)
                begin
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    ioctl_wait          <= 1'b0;
                    bios_load_state     <= 4'h00;
                end
                else if ((~ioctl_wr) || (bios_load_n))
                begin
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    ioctl_wait          <= 1'b0;
                    bios_load_state     <= 4'h01;
                end
                else
                begin
                    bios_access_address <= bios_access_address_wire;
                    bios_write_data     <= {8'hFF,ioctl_data};
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    ioctl_wait          <= 1'b1;
                    bios_load_state     <= 4'h02;
                end
            end
            4'h02:
            begin
                bios_protect_flag   <= 2'b00;
                bios_access_request <= 1'b1;
                bios_access_address <= bios_access_address;
                bios_write_data     <= bios_write_data;
                bios_write_byte_cnt <= bios_write_byte_cnt;
                tandy_bios_write    <= select_tandy;
                ioctl_wait          <= 1'b1;
                bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                if (bios_write_wait_cnt != 'd20)
                begin
                    bios_write_n        <= 1'b0;
                    bios_load_state     <= 4'h02;
                end
                else
                begin
                    bios_write_n        <= 1'b1;
                    bios_load_state     <= 4'h03;
                end
            end
            4'h03:
            begin
                bios_protect_flag   <= 2'b00;
                bios_access_request <= 1'b1;
                bios_access_address <= 20'hFFFFF;
                bios_write_data     <= 16'hFFFF;
                bios_write_n        <= 1'b1;
                bios_write_byte_cnt <= bios_write_byte_cnt;
                tandy_bios_write    <= 1'b0;
                ioctl_wait          <= 1'b1;
                bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                if (bios_write_wait_cnt != 'd40)       //'h40 does not load BIOS
                    bios_load_state     <= 4'h03;
                else
                    bios_load_state     <= 4'h01;
            end
            default:
            begin
                bios_protect_flag   <= 2'b11;
                bios_access_request <= 1'b0;
                bios_access_address <= 20'hFFFFF;
                bios_write_data     <= 16'hFFFF;
                bios_write_n        <= 1'b1;
                bios_write_wait_cnt <= 'h0;
                bios_write_byte_cnt <= 1'h0;
                tandy_bios_write    <= 1'b0;
                ioctl_wait          <= 1'b0;
                bios_load_state     <= 4'h00;
            end
        endcase
    end
end

wire device_clock = ps2_kbd_clk_in;
wire device_data  = ps2_kbd_data_in;

wire [7:0] data_bus;
wire INTA_n;
wire [19:0] cpu_ad_out;
reg  [19:0] cpu_address;
wire [7:0] cpu_data_bus;
wire processor_ready;
wire interrupt_to_cpu;
wire address_latch_enable;
wire address_direction;

wire lock_n;
wire [2:0] processor_status;

wire [3:0]   dma_acknowledge_n;

logic   [7:0]   port_b_out;
logic   [7:0]   port_c_in;
reg     [7:0]   sw;

assign  sw = mda_mode ? 8'b00111101 : 8'b00101101; // PCXT DIP Switches (MDA or CGA 80)
assign  port_c_in[3:0] = port_b_out[3] ? sw[7:4] : sw[3:0];

wire tandy_bios_flag = bios_write_n ? tandy_mode : tandy_bios_write;

always @(posedge clk_chipset)
begin
    if (address_latch_enable)
        cpu_address <= cpu_ad_out;
    else
        cpu_address <= cpu_address;
end
    
CHIPSET #(.clk_rate(cur_rate)) u_CHIPSET(
    .clock                              (clk_chipset),
    .cpu_clock                          (clk_cpu),
    .clk_sys                            (clk_chipset),
    .peripheral_clock                   (pclk),
    .clk_select                         (clk_select),
    .color                              (color),
    .reset                              (reset_cpu),
    .sdram_reset                        (reset_sdram),
    .cpu_address                        (cpu_address),
    .cpu_data_bus                       (cpu_data_bus),
    .processor_status                   (processor_status),
    .processor_lock_n                   (lock_n),
    .processor_ready                    (processor_ready),
    .interrupt_to_cpu                   (interrupt_to_cpu),
    .splashscreen                       (1'b0),
    .video_output                       (mda_mode_video_ff),
    .clk_vga_cga                        (clk_28_636),
    .enable_cga                         (1'b1),
    .clk_vga_mda                        (clk_56_875),
    .enable_mda                         (1'b1),
    .mda_rgb                            (2'b10),
    .VGA_R                              (r_in),
    .VGA_G                              (g_in),
    .VGA_B                              (b_in),
    .VGA_HSYNC                          (vga_hs),
    .VGA_VSYNC                          (vga_vs),
    .VGA_HBlank                         (HBlank),
    .VGA_VBlank                         (VBlank),
    .scandoubler                        (~forced_scandoubler),
    .comp_video                         (comp_video),
    .composite_on                       (composite_on),
    .vga_composite                      (vga_composite),
    .composite_out                      (),
    .rgb_18b                            (rgb_18b),
    .address_ext                        (bios_access_address),
    .ext_access_request                 (bios_access_request),
    .address_direction                  (address_direction),
    .data_bus                           (data_bus),
    .data_bus_ext                       (bios_write_data[7:0]),
    .address_latch_enable               (address_latch_enable),
    .io_channel_ready                   (1'b1),
    .interrupt_request                  (0),    // use? -> It does not seem to be necessary.
    .io_read_n_ext                      (1'b1),
    .io_write_n_ext                     (1'b1),
    .memory_read_n_ext                  (1'b1),
    .memory_write_n_ext                 (bios_write_n),
    .dma_request                        (0),    // use? -> I don't know if it will ever be necessary, at least not during testing.
    .dma_acknowledge_n                  (dma_acknowledge_n),
    .port_b_out                         (port_b_out),
    .port_c_in                          (port_c_in),
    .port_b_in                          (port_b_out),
    .speaker_out                        (speaker_out),
    .ps2_clock                          (device_clock),
    .ps2_data                           (device_data),
    .ps2_clock_out                      (ps2_kbd_clk_out),
    .ps2_data_out                       (ps2_kbd_data_out),
    .ps2_mouseclk_in                    (ps2_mouse_clk_in),
    .ps2_mousedat_in                    (ps2_mouse_data_in),
    .ps2_mouseclk_out                   (ps2_mouse_clk_out),
    .ps2_mousedat_out                   (ps2_mouse_data_out),
    .joy_opts                           (joy_opts),           //Joy0-Disabled, Joy0-Type, Joy1-Disabled, Joy1-Type, turbo_sync
    .joy0                               (status[28] ? joy1 : joy0),
    .joy1                               (status[28] ? joy0 : joy1),
    .joya0                              (status[28] ? joya1[15:0] : joya0[15:0]),
    .joya1                              (status[28] ? joya0[15:0] : joya1[15:0]),
    .jtopl2_snd_e                       (jtopl2_snd_e),
    .tandy_snd_e                        (tandy_snd_e),
    .opl2_io                            (xtctl[4] ? 2'b10 : status[41:40]),
    .cms_en                             (~status[10]),
    .o_cms_l                            (cms_l_snd_e),
    .o_cms_r                            (cms_r_snd_e),
    .tandy_video                        (tandy_mode),
    .tandy_bios_flag                    (tandy_bios_flag),
    .clk_uart                           (clk_uart),
    .clk_uart2                          (clk_uart2_en),
    .uart_rx                            (),
    .uart_tx                            (),
    .uart_cts_n                         (),
    .uart_dcd_n                         (1'b0),     //(uart_dcd),
    .uart_dsr_n                         (1'b0),     //(uart_dsr),
    .uart_rts_n                         (),
    .enable_sdram                       (1'b1),
    .initilized_sdram                   (initilized_sdram),
    .sdram_clock                        (clk_chipset),
    .sdram_address                      (SDRAM_A),
    .sdram_cke                          (SDRAM_CKE),
    .sdram_cs                           (SDRAM_nCS),
    .sdram_ras                          (SDRAM_nRAS),
    .sdram_cas                          (SDRAM_nCAS),
    .sdram_we                           (SDRAM_nWE),
    .sdram_ba                           (SDRAM_BA),
    .sdram_dq_in                        (SDRAM_DQ_IN),
    .sdram_dq_out                       (SDRAM_DQ_OUT),
    .sdram_dq_io                        (SDRAM_DQ_IO),
    .sdram_ldqm                         (SDRAM_DQML),
    .sdram_udqm                         (SDRAM_DQMH),
    .ems_enabled                        (~status[11]),
    .ems_address                        (status[13:12]),
    .bios_protect_flag                  (bios_protect_flag),
    .ide0_addr                          (ide0_addr),
    .ide0_writedata                     (ide0_writedata),
    .ide0_readdata                      (ide0_readdata),
    .ide0_read                          (ide0_read),
    .ide0_write                         (ide0_write),
    .rtc_data                           (rtc_data),
    .xtctl                              (xtctl),
    .enable_a000h                       (a000h),
    .wait_count_clk_en                  (~clk_cpu & clk_cpu_ff_2),
    .ram_read_wait_cycle                (ram_read_wait_cycle),
    .ram_write_wait_cycle               (ram_write_wait_cycle),
    .pause_core                         (pause_core)
);

wire [15:0] SDRAM_DQ_IN;
wire [15:0] SDRAM_DQ_OUT;
wire        SDRAM_DQ_IO;
wire        initilized_sdram;

assign SDRAM_DQ_IN = SDRAM_DQ;
assign SDRAM_DQ = ~SDRAM_DQ_IO ? SDRAM_DQ_OUT : 16'hZZZZ;

wire s6_3_mux;
wire [2:0] SEGMENT;

i8088 B1(
    .CORE_CLK(clk_100),
    .CLK(clk_cpu),

    .RESET(reset_cpu),
    .READY(processor_ready && ~pause_core),
    .NMI(1'b0),
    .INTR(interrupt_to_cpu),

    .ad_out(cpu_ad_out),
    .dout(cpu_data_bus),
    .din(data_bus),

    .lock_n(lock_n),
    .s6_3_mux(s6_3_mux),
    .s2_s0_out(processor_status),
    .SEGMENT(SEGMENT),

    .biu_done(biu_done),
    .cycle_accrate(cycle_accrate),
    .clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
    .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
    .shift_read_timing(shift_read_timing)
);

//
////////////////////////////  AUDIO  ///////////////////////////////////
//

wire [15:0] cms_l_snd_e;
wire [16:0] cms_l_snd = {cms_l_snd_e[15],cms_l_snd_e};
wire [15:0] cms_r_snd_e;
wire [16:0] cms_r_snd = {cms_r_snd_e[15],cms_r_snd_e};
 
wire [15:0] jtopl2_snd_e;
wire [16:0] jtopl2_snd = {jtopl2_snd_e[15], jtopl2_snd_e};
wire [10:0] tandy_snd_e;
wire [16:0] tandy_snd = {{{2{tandy_snd_e[10]}}, {4{tandy_snd_e[10]}}, tandy_snd_e} << status[35:34], 2'b00};
wire [16:0] spk_vol =  {2'b00, {3'b000,~speaker_out} << status[33:32], 11'd0};
wire        speaker_out;

localparam [3:0] comp_f1 = 4;
localparam [3:0] comp_a1 = 2;
localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b1 = comp_x1 * comp_a1;

localparam [3:0] comp_f2 = 8;
localparam [3:0] comp_a2 = 4;
localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b2 = comp_x2 * comp_a2;

function [15:0] compr;
    input [15:0] inp;
    reg [15:0] v, v1, v2;
    begin
        v  = inp[15] ? (~inp) + 1'd1 : inp;
        v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
        v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
        v  = status[37] ? v2 : v1;
        compr = inp[15] ? ~(v-1'd1) : v;
    end
endfunction

reg [15:0] cmp_l;
reg [15:0] out_l;
always @(posedge clk_chipset)
begin
    reg [16:0] tmp_l;

    tmp_l <= jtopl2_snd + cms_l_snd + tandy_snd + spk_vol;

    // clamp the output
    out_l <= (^tmp_l[16:15]) ? {tmp_l[16], {15{tmp_l[15]}}} : tmp_l[15:0];

    cmp_l <= compr(out_l);
end
 
reg [15:0] cmp_r;
reg [15:0] out_r;
always @(posedge clk_chipset)
begin
    reg [16:0] tmp_r;

    tmp_r <= jtopl2_snd + cms_r_snd + tandy_snd + spk_vol;

    // clamp the output
    out_r <= (^tmp_r[16:15]) ? {tmp_r[16], {15{tmp_r[15]}}} : tmp_r[15:0];

    cmp_r <= compr(out_r);
end

wire [15:0] laudio, raudio;
assign laudio = pause_core ? 1'b0 : status[37:36] ? cmp_l : out_l;
assign raudio = pause_core ? 1'b0 : status[37:36] ? cmp_r : out_r;


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_chipset),
    .clk_rate(32'd50_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(laudio),
    .right_chan(raudio)
);
`endif


//
////////////////////////////  UART  ///////////////////////////////////
//

logic clk_uart_ff_1;
logic clk_uart_ff_2;
logic clk_uart_ff_3;
logic clk_uart_en;
logic clk_uart2_en;
logic [2:0] clk_uart2_counter;

always @(posedge clk_chipset)
begin
    clk_uart_ff_1 <= clk_uart;
    clk_uart_ff_2 <= clk_uart_ff_1;
    clk_uart_ff_3 <= clk_uart_ff_2;
    clk_uart_en <= ~clk_uart_ff_3 & clk_uart_ff_2;
end

always @(posedge clk_chipset)
begin
    if (clk_uart_en)
    begin
        if (3'd7 != clk_uart2_counter)
        begin
            clk_uart2_counter <= clk_uart2_counter +3'd1;
            clk_uart2_en <= 1'b0;
        end
        else
        begin
            clk_uart2_counter <= 3'd0;
            clk_uart2_en <= 1'b1;
        end
    end
    else
    begin
        clk_uart2_counter <= clk_uart2_counter;
        clk_uart2_en <= 1'b0;
    end
end

// UART1 connected to external cable to host for serdrive
// UART2 connected internally in Peripherals.sv for serial mouse


//
///////////////////////   VIDEO   ///////////////////////
//

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;

wire [5:0] r_in, g_in, b_in;
wire [3:0] r_mist, g_mist, b_mist;

wire vga_hs;
wire vga_vs;
wire vga_hs_o;
wire vga_vs_o;

wire [6:0] comp_video;
wire [17:0] rgb_18b;
wire clk_vid;

assign clk_vid = mda_mode_video_ff ? clk_56_875 : clk_28_636;

wire color = (screen_mode_video_ff == 3'd0);


mist_video #(
    .COLOR_DEPTH(6),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD)) mist_video(

    .clk_sys(clk_vid),
    
    // OSD SPI interface
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),

    // scanlines (00-none 01-25% 10-50% 11-75%)     //only works if scandoubler enabled
    .scanlines(2'b00),

    // non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
    .ce_divider(1'b0),

    // 0 = HVSync 31KHz, 1 = CSync 15KHz            //using Graphics Gremlin scandoubler
    .scandoubler_disable(1'b1),
    // disable csync without scandoubler
    .no_csync(~forced_scandoubler), 
    // YPbPr always uses composite sync
    .ypbpr(status[42]),
    // Rotate OSD [0] - rotate [1] - left or right
    .rotate(2'b00),
    // composite-like blending
    .blend(status[43]), 

    // video in
    .R(r_in),
    .G(g_in),
    .B(b_in),
    .HSync(~vga_hs),
    .VSync(~vga_vs),

    // MiST video output signals
    .VGA_R(r_mist),
    .VGA_G(g_mist),
    .VGA_B(b_mist),
    .VGA_VS(VGA_VS),
    .VGA_HS(vga_hs_o)
);

assign rgb_18b = {r_mist, 2'b00, g_mist, 2'b00, b_mist, 2'b00};    // for composite real video output

assign VGA_HS = composite_on ? ~(vga_hs ^ vga_vs): ~vga_hs_o;
assign VGA_R = composite_on ?   4'd0                     : r_mist;
assign VGA_G = composite_on ?  {2'b00, comp_video[4:3]}  : g_mist;
assign VGA_B = composite_on ?  {2'b00, comp_video[6:5]}  : b_mist;


endmodule
