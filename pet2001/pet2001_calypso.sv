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

module pet2001_calypso(
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
    
    output [7:0] AUX

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

`include "build_id.v"
parameter CONF_STR = {
    "PET2001;;",
    "F0,ROM,Load System ROM;",
    "F1,TAP,Load Tape;",
    "F2,PRG,Load Program;",
    "O2,Diag Jumper,Off,On;",
    `SEP
    "O3,Tape Input,File,Line;",
    "O6,Tape Sound,On,Off;",
    `SEP
    "O7,Drive #8 Type,8250,4040;",
    "S0U,D80D82D64,Mount drive #8;",
    "TF,Reset Drives;",
    `SEP
    "O1,Color,Green,White;",
    "O45,Scanlines,Off,25%,50%,75%;",
    `SEP
    "T0,Reset;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys /* synthesis keep */;
wire pll_locked;

pll pll(
    .inclk0(CLK12M),
    .c0(clk_sys),
    .locked(pll_locked)
);

reg reset /* synthesis keep */ = 1;
always @(posedge clk_sys) begin
    integer initRESET = 10000000;
    reg [3:0] reset_cnt;

    if ((!(status[0] || buttons[1] || (ioctl_download && ioctl_index == 0)) && reset_cnt==4'd14) && !initRESET)
        reset <= 0;
    else begin
        if(initRESET) initRESET <= initRESET - 1;
        reset <= 1;
        reset_cnt <= reset_cnt+4'd1;
    end
end

reg  ce_7mp;
reg  ce_7mn;
reg  ce_1m /* synthesis keep */;

always @(posedge clk_sys) begin
    reg  [2:0] div = 0;
    reg  [6:0] cpu_div = 0;

    div <= div + 1'd1;
    ce_7mp  <= !div[2] & !div[1:0];
    ce_7mn  <=  div[2] & !div[1:0];

    cpu_div <= cpu_div + 1'd1;
    if (cpu_div == 7'd55) begin
        cpu_div  <= 0;
    end
    ce_1m <= !cpu_div;
end

/////////////////  IO  ///////////////////////////

wire [31:0] status;
wire [1:0] buttons;

wire [31:0] joy0, joy1;

wire ioctl_download /* synthesis keep */;
wire [7:0] ioctl_index /* synthesis keep */;
wire ioctl_wr /* synthesis keep */;
wire [24:0] ioctl_addr /* synthesis keep */;
wire [7:0] ioctl_dout /* synthesis keep */;
wire scandoubler_disable;
wire no_csync;
wire ypbpr;

wire [31:0] sd_lba[1];
reg sd_rd /* synthesis keep */;
reg sd_wr;
wire sd_ack /* synthesis keep */;
wire sd_ack_x /* synthesis keep */;
wire [8:0] sd_buff_addr /* synthesis keep */;
wire [7:0] sd_buff_dout /* synthesis keep */;
wire [7:0] sd_buff_din[1];
wire sd_buff_wr /* synthesis keep */;

wire img_mounted;
wire img_readonly;
wire [31:0] img_size;
wire [23:0] img_ext /* synthesis keep */;

wire key_pressed;
wire [7:0] key_code;
wire key_strobe;
wire key_extended;

wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code}; 


user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .SD_IMAGES(1'b1),
    .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)))
user_io(
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

    .key_strobe(key_strobe),
    .key_code(key_code),
    .key_pressed(key_pressed),
    .key_extended(key_extended),

    .sd_sdhc(1),
    .sd_lba(sd_lba[0]),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_ack_x(sd_ack_x),
    .sd_buff_addr(sd_buff_addr),
    .sd_dout(sd_buff_dout),
    .sd_din(sd_buff_din[0]),
    .sd_dout_strobe(sd_buff_wr),

    .img_mounted(img_mounted),
    .img_size(img_size),

    .joystick_0(joy0),
    .joystick_1(joy1)
);


data_io data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),

`ifdef NO_DIRECT_UPLOAD
    .SPI_SS4(1'b1),
`else
    .SPI_SS4(SPI_SS4),
`endif

    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),
    .ioctl_fileext(img_ext),
    .ioctl_download(ioctl_download),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout)
);

wire rom_download = ioctl_download && ioctl_index == 8'h00;
wire tape_download = ioctl_download && ioctl_index == 8'h01;
wire prg_download = ioctl_download && ioctl_index == 8'h02;

reg [3:0] prg_load_state = 4'd0;
reg [15:0] dl_addr /* synthesis keep */;
reg [7:0] dl_data /* synthesis keep */;
reg dl_wr /* synthesis keep */;

wire prg_writing = prg_download || prg_load_state != 2'b00;

always @(posedge clk_sys) begin
    reg old_download = 0;
    reg [15:0] loadaddr;

    dl_wr <= 0;
    old_download <= prg_download;

    if (prg_download) begin
        prg_load_state <= 4'd0;
        if (ioctl_wr) begin  
            if (ioctl_addr == 0) loadaddr[7:0]  <= ioctl_dout;
            else if (ioctl_addr == 1) loadaddr[15:8] <= ioctl_dout;
            else begin
                if (loadaddr < 'h8000) begin
                    dl_addr <= loadaddr;
                    dl_data <= ioctl_dout;
                    dl_wr <= 1;
                    loadaddr <= loadaddr + 1'd1;
                end
            end
        end
    end

    if (old_download && ~prg_download) prg_load_state <= 1;
    if (prg_load_state) prg_load_state <= prg_load_state + 4'd1;

    case (prg_load_state)
        4'd1: begin dl_addr <= 16'h2a; dl_data <= loadaddr[7:0];  dl_wr <= 1; end
        4'd9: begin dl_addr <= 16'h2b; dl_data <= loadaddr[15:8]; dl_wr <= 1; end
    endcase

    if (rom_download) begin
        prg_load_state <= 0;
        if (ioctl_wr) begin
            if (ioctl_addr < 'h8000) begin
                dl_addr <= {1'b1,ioctl_addr[14:0]};
                dl_data <= ioctl_dout;
                dl_wr <= 1;
            end
        end
    end
end


/////////////////  Memory  ////////////////////////
wire [22:0] sdram_addr /* synthesis keep */;
wire [7:0] sdram_din /* synthesis keep */;
wire [7:0] sdram_dout /* synthesis keep */;
wire sdram_rd /* synthesis keep */;
wire sdram_we /* synthesis keep */;
wire sdram_ready;

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
    .dout(sdram_dout),
    .din(sdram_din),
    .we(sdram_we),
    .ready(sdram_ready)
);

reg [16:0] ce_1m_seq;
reg [7:0] sdram_data /* synthesis keep */;

always @(posedge clk_sys) begin
    sdram_rd <= 1'b0;
    sdram_we <= 1'b0;
    ce_1m_seq <= {ce_1m_seq[7:0], ce_1m};
    if (rom_download == 1'b1 || prg_writing == 1'b1) begin
        sdram_addr <= {7'd0, dl_addr};
        sdram_rd <= 1'b0;
        sdram_we <= dl_wr;
        sdram_din <= dl_data;
    end else if (tape_download == 1'b1) begin
        sdram_addr <= {3'b001, ioctl_addr[19:0]};
        sdram_rd <= 1'b0;
        sdram_we <= ioctl_wr;
        sdram_din <= ioctl_dout;
    end else if (ce_1m_seq[0] == 1'b1) begin
        sdram_addr <= {7'd0, addr};
        sdram_rd <= rnw;
        sdram_we <= ~rnw;
        sdram_din <= cpu_data_out;
    end else if (ce_1m_seq[8] == 1'b1) begin
        sdram_data <= sdram_dout;
        sdram_addr <= {3'b001, tape_addr[19:0]};
        sdram_rd <= tape_active;
    end else if (ce_1m_seq[16] == 1'b1) begin
        tape_data <= sdram_dout;
    end
end

///////////////////////////////////////////////////
// CPU
///////////////////////////////////////////////////
wire [15:0] addr /* synthesis keep */;
wire [7:0] cpu_data_out /* synthesis keep */;
wire [7:0] cpu_data_in /* synthesis keep */;
wire rnw;

wire we = ~rnw;
wire irq;
wire ce_1m_gated = ce_1m & ~tape_download & ~rom_download & ~prg_writing;

T65 cpu(
    .Mode(0),
    .Res_n(~reset),
    .Enable(ce_1m_gated),
    .Clk(clk_sys),
    .Rdy(1),
    .Abort_n(1),
    .IRQ_n(~irq),
    .NMI_n(1),
    .SO_n(1),
    .R_W_n(rnw),
    .A(addr),
    .DI(cpu_data_in),
    .DO(cpu_data_out)
);


///////////////////////////////////////////////////
// Commodore Pet hardware
///////////////////////////////////////////////////
wire hblank, vblank;
wire hsync, vsync;
wire pix;
wire audioDat;

pet2001hw hw(
    .clk(clk_sys),
    .ce_7mp(ce_7mp),
    .ce_7mn(ce_7mn),
    .ce_1m(ce_1m),
    .reset(reset),

    .addr(addr),
    .data_out(cpu_data_in),
    .data_in(cpu_data_out),
    .we(we),
    .sdram_data(sdram_data),
    
    .keyrow(keyrow),
    .keyin(keyin),
    
    .irq(irq),
    .pix(pix),
    .HSync(hsync),
    .VSync(vsync),
    .HBlank(hblank),
    .VBlank(vblank),

    .cass_motor_n(),
    .cass_write(tape_write),
    .audio(audioDat),
    .cass_sense_n(0),
    .cass_read(status[3] ? TAPE_SOUND : tape_audio),
    .diag_l(~status[2]),

    .ieee_i(ieee_bus_te),
    .ieee_o(ieee_bus_dc)
);


////////////////////////////////////////////////////////////////////
// Audio
////////////////////////////////////////////////////////////////////
wire [1:0] audio = {audioDat ^ tape_write, tape_audio & tape_active & (status[6] == 1'b0)};
wire tape_audio;
wire tape_rd;
wire [24:0] tape_addr;
wire [7:0] tape_data;
wire tape_pause = 0;
wire tape_active;
wire tape_write;

tape tape(
    .clk(clk_sys),
    .reset(reset),
    .ce_1m(ce_1m),
    
    .ioctl_download(tape_download),
    .tape_pause(tape_pause),
    .tape_audio(tape_audio),
    .tape_active(tape_active),
    
    .tape_rd(tape_rd),
    .tape_addr(tape_addr),
    .tape_data(tape_data)
);

reg [18:0] act_cnt;
wire       tape_led = act_cnt[18] ? act_cnt[17:10] <= act_cnt[7:0] : act_cnt[17:10] > act_cnt[7:0];
always @(posedge clk_sys) if((|status[8:7] ? ce_1m : ce_7mp) && (tape_active || act_cnt[18] || act_cnt[17:0])) act_cnt <= act_cnt + 1'd1; 

//////////////////////////////////////////////////////////////////////
// IEEE Drives
//////////////////////////////////////////////////////////////////////

st_ieee_bus ieee_bus_te /* synthesis keep */;
st_ieee_bus ieee_bus_dc /* synthesis keep */;

wire drive_reset = reset | status[15];
wire [1:0] drive_led;

// hps_io has BLKSZ configured to 1 (256 bytes)
// Default and minimum in Mist is 512 bytes
// We need to transfer sd_blk_cnt / 2 512 byte blocks per hps_io transfer

reg drive_mounted = 0;
wire [5:0] sd_blk_cnt[1] /* synthesis keep */;
reg [4:0] blkcnt;
reg sd_ieee_ack = 1'b0;
reg [4:0] blk;
wire sd_ieee_rd /* synthesis keep */;
wire sd_ieee_wr;

wire [31:0] sd_ieee_lba[1] /* synthesis keep */;
wire [12:0] sd_ieee_buff_addr /* synthesis keep */ = {blk[3:0], sd_buff_addr[8:0]} - {3'd0, sd_ieee_lba[0][0], 8'd0};
wire sd_ieee_buff_wr /* synthesis keep */= sd_ieee_lba[0][0] == 1'b0 ? sd_buff_wr :
    blk == 5'd0 ? sd_buff_wr & sd_buff_addr[8] :
    blk == blkcnt - 5'd1 ? sd_buff_wr & ~sd_buff_addr[8] :
    sd_buff_wr;
    
reg [31:0] sd_blk_lba /* synthesis keep */;
assign sd_lba[0] = sd_blk_lba;
wire drive_type = status[7];

assign LED[2] = drive_type;
assign LED[3] = sd_rd;
assign LED[4] = sd_ieee_rd;
assign LED[5] = sd_ack;
assign LED[6] = sd_ieee_ack;
assign LED[7] = sd_blk_cnt[0][0];

localparam STATE_IDLE = 3'd0;
localparam STATE_START = 3'd1;
localparam STATE_WAITACK = 3'd2;
localparam STATE_LOOP = 3'd3;
localparam STATE_NEXT = 3'd4;
localparam STATE_DONE = 3'd5;

always @(posedge clk_sys) begin 
    reg [1:0] operation;
    reg [2:0] state = STATE_IDLE;
    reg sd_ieee_rd_last;
    reg sd_ieee_wr_last;
    reg sd_ack_last;
    reg img_mounted_last;
    
    sd_ieee_rd_last <= sd_ieee_rd;
    sd_ieee_wr_last <= sd_ieee_wr;
    sd_ack_last <= sd_ack;
    img_mounted_last <= img_mounted;
    
    if (~img_mounted_last & img_mounted) begin
        drive_mounted <= |img_size;
    end

    if (drive_reset | ~drive_mounted) begin
        sd_ieee_ack <= 1'b0;
        blk <= 5'd0;
        blkcnt <= 5'd0;
        operation <= 2'b00;
        state <= STATE_IDLE;
    end else if (drive_mounted == 1'b1) begin
        case (state)
            STATE_IDLE: begin
                if ((~sd_ieee_rd_last & sd_ieee_rd) | (~sd_ieee_wr_last & sd_ieee_wr)) begin
                    blk <= 5'd0;
                    blkcnt <= sd_blk_cnt[0][5:1] + sd_ieee_lba[0][0]; //IEEE blocks of 256 bytes with hps_io, MiST of 512 bytes
                    sd_blk_lba <= {1'b0, sd_ieee_lba[0][31:1]}; //Block address divided by two (due to the block size difference)
                    sd_ieee_ack <= 1'b0;
                    sd_rd <= sd_ieee_rd;
                    sd_wr <= sd_ieee_wr;
                    operation <= {sd_ieee_wr, sd_ieee_rd};
                    state <= STATE_START;
                end
            end
            STATE_START: begin
                if (sd_ack == 1'b1) begin
                    sd_ieee_ack <= 1'b1;
                    state <= STATE_WAITACK;
                end
            end
            STATE_WAITACK: begin
                if (sd_ack_last & ~sd_ack) begin
                    blk = blk + 5'd1;
                    state <= STATE_LOOP;
                end
            end
            STATE_LOOP: begin
                if (blk == blkcnt) begin
                    operation <= 2'b00;
                    state <= STATE_DONE;
                end else begin
                    {sd_wr, sd_rd}  <= 2'b00;
                    state <= STATE_NEXT;
                end
            end
            STATE_NEXT: begin
                sd_blk_lba <= sd_blk_lba + 32'd1;
                {sd_wr, sd_rd} <= operation;
                state <= STATE_START;
            end
            STATE_DONE: begin
                sd_ieee_ack <= 1'b0;
                {sd_wr, sd_rd} <= operation;
                state <= STATE_IDLE;
            end
        endcase
    end
end

ieee_drive #(
    .DRIVES(1),
    .SUBDRV(1)
) ieee_drive(
    .CLK(56_000_000),
    .clk_sys(clk_sys),
    .reset(drive_reset),
    .pause(1'b0),

    .led(LED[1]),

    .bus_i(ieee_bus_dc),
    .bus_o(ieee_bus_te),

    .drv_type(status[7]),

    .img_mounted(drive_mounted),
    .img_size(img_size),
    .img_readonly(img_readonly),

    .sd_lba(sd_ieee_lba),
    .sd_blk_cnt(sd_blk_cnt),
    .sd_rd(sd_ieee_rd),
    .sd_wr(sd_ieee_wr),
    .sd_ack(sd_ieee_ack),
    .sd_buff_addr(sd_ieee_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din),
    .sd_buff_wr(sd_ieee_buff_wr),

    .rom_wr(0),
    .rom_sel(0),
    .rom_addr(0),
    .rom_data(0)
);
// CPU out
assign AUX[0] = ieee_bus_dc.dav; //Host data valid
assign AUX[1] = ieee_bus_dc.atn; //Host attention
assign AUX[2] = ieee_bus_dc.nrfd; //Host not ready for data
assign AUX[3] = ieee_bus_dc.ndac; //Host no data ack

// IEEE drive out
assign AUX[4] = ieee_bus_te.dav; //Drive data valid
assign AUX[5] = ieee_bus_te.atn; //Drive attention
assign AUX[6] = ieee_bus_te.nrfd; //Drive not ready for data
assign AUX[7] = ieee_bus_te.ndac; //Drive no data ack

//////////////////////////////////////////////////////////////////////
// PS/2 to PET keyboard interface
//////////////////////////////////////////////////////////////////////
wire [7:0] keyin;
wire [3:0] keyrow;
wire shift_lock;

keyboard keyboard(
    .clk(clk_sys),
    .reset(reset),
    
    .ps2_key(ps2_key),
    
    .keyrow(keyrow),
    .keyin(keyin),
    .shift_lock(shift_lock),
    
    .Fn(),
    .mod()
);


`ifdef I2S_AUDIO
i2s i2s (
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(32'd56_000_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan({audio, 14'd0}),
    .right_chan({audio, 14'd0})
);
`endif

mist_video #(
    .COLOR_DEPTH(1),
    .SD_HCNT_WIDTH(11),
    .USE_BLANKS(1'b1),
    .OSD_COLOR(3'b001),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .BIG_OSD(BIG_OSD))
mist_video(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(status[1] ? pix : 1'b0),
    .G(pix),
    .B(status[1] ? pix : 1'b0),
    .HBlank(hblank),
    .VBlank(vblank),
    .HSync(hsync),
    .VSync(vsync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(3'd7),
    .scandoubler_disable(scandoubler_disable),
    .no_csync(no_csync),
    .scanlines(status[5:4]),
    .ypbpr(ypbpr)
);


endmodule
