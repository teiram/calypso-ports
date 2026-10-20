`default_nettype none

module menu_calypso(
    input CLK12M,
    
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

    output [11:0] SDRAM_A,
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
    
        
    input I2S_MIDI_BCK,
    input I2S_MIDI_LRCK,
    input I2S_MIDI_DATA
    
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
localparam SEP = "-;";
`else
localparam bit BIG_OSD = 0;
localparam SEP = "";
`endif

`include "build_id.v"

localparam CONF_STR = {
    "MENU;;",
    "F1,BMP,Change background;",
    "O1,Video mode,PAL,NTSC;",
    "O23,Rotate,Off,Left,Right;",
    "O4,KITT Mode,Off,On;",
    "P2pMID,MID,xx,MIDI Player;",
    "O57,OSD HPos,0,-64,-48,-32,-16,+16,+32,+48;",
    "O8A,OSD VPos,0,-64,-48,-32,-16,+16,+32,+48;",
    "OBD,OSD Color,Black,Blue,Green,Cyan,Red,Magenta,Yellow,White;",
    "P2,Background;",
    "P2OMO,Type,Waterfall,Matrix,Sea,Classic,File;",
    "P2OPQ,Speed,Normal,Slow,Very slow,Fast;",
    "P2OR,Calypso Logo,On,Off;",
    "P1,Clock;",
    "P1OE,Clock,On,Off;",
    "P1OS,Size,1x,2x;",
    "P1OV,Segments,Flat,Pointed;",
    "P1OW,Panel,On,Off;",
    "P1OX,Shadow,On,Off;",
    "P1OFG,Vertical,Bottom,Top,Center;",
    "P1OHI,Horizontal,Center,Left,Right;",
    "P1OTU,Date,DD-MM-YYYY,MM-DD-YYYY,YYYY-MM-DD;",
    "P1OYZ,Weekday,Off,English,Spanish;",
    "P1OJL,Color,Green LCD,Gray LCD,Blue,Amber,Game Boy,Red LED,VFD,Inverted;",
    "V,",`BUILD_VERSION,"-",`BUILD_DATE
};
wire clk_x2, clk_pix, clk_sys, clk_ram, pll_locked;
pll pll(
    .inclk0(CLK12M),
    .c0(clk_ram),
    .c1(clk_sys),
    .c2(clk_x2),
    .c3(clk_pix),
    .locked(pll_locked)
);

reg signed [10:0] osd_x_offset = 11'd0;
reg signed [10:0] osd_y_offset = 11'd0;
reg [2:0] osd_color = 3'd2;

always @(posedge clk_x2) begin
    case (status[7:5])
        3'd0: osd_x_offset <= 11'd0;
        3'd1, 3'd2, 3'd3, 3'd4: osd_x_offset <= {4'b1111, status[7:5], 4'd0};
        3'd5, 3'd6, 3'd7: osd_x_offset <= {5'd0, status[6:5], 4'd0};
    endcase
    case (status[10:8])
        3'd0: osd_y_offset <= 11'd0;
        3'd1, 3'd2, 3'd3, 3'd4: osd_y_offset <= {4'b1111, status[10:8], 4'd0};
        3'd5, 3'd6, 3'd7: osd_y_offset <= {5'd0, status[9:8], 4'd0};
    endcase
    osd_color = status[13:11];
end

wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire [63:0] status;
wire [63:0] rtc;

user_io #(
    .STRLEN($size(CONF_STR)>>3),
    .FEATURES(32'd1 | (BIG_OSD << 13) | (HDMI << 14)),
    .ROM_DIRECT_UPLOAD(DIRECT_UPLOAD))
    user_io(
    .clk_sys(clk_x2),
    .conf_str(CONF_STR),

    .SPI_CLK(SPI_SCK),
    .SPI_SS_IO(CONF_DATA0),
    .SPI_MISO(SPI_DO),
    .SPI_MOSI(SPI_DI),
    .status(status),
    .rtc(rtc),

    .scandoubler_disable(scandoubler_disable),
    .ypbpr(ypbpr),
    .no_csync(no_csync)
);

wire ntsc = status[1];
wire [1:0] rotate = status[3:2];

wire [8:0] line_max = ntsc ? 9'd262 : 9'd312;

wire ioctl_downl;
wire ioctl_upl;
wire [7:0] ioctl_index;
wire ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_din;
wire [7:0] ioctl_dout;

data_io #(.ROM_DIRECT_UPLOAD(DIRECT_UPLOAD))
    data_io(
    .clk_sys(clk_sys),
    .SPI_SCK(SPI_SCK),
    .SPI_SS2(SPI_SS2),
    .SPI_SS4(SPI_SS4),
    .SPI_DI(SPI_DI),
    .SPI_DO(SPI_DO),
    .ioctl_download(ioctl_downl),
    .ioctl_upload(ioctl_upl),
    .ioctl_index(ioctl_index),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_din(ioctl_din),
    .ioctl_dout(ioctl_dout)
);

reg [19:0] ce_counter;
reg [7:0] zylon = 8'b00000001;
reg led_dir = 1'b0;
assign LED = status[4] ? zylon : {7'd0, ~ioctl_downl};

always @(posedge clk_pix) begin
    reg last_status;
    last_status <= status[4];
    if (~last_status & status[4]) begin 
        ce_counter <= 1'b0;
        zylon = 8'b00000001;
        led_dir <= 1'b0;
    end
    ce_counter <= ce_counter + 20'd1;
    if (ce_counter == 20'd745000) begin
        ce_counter <= 20'd0;
        if (zylon == 8'd0) begin
            led_dir <= ~led_dir;
            zylon <= led_dir ? 8'b10000000 : 8'b00000001;
        end
        else begin
            zylon <= led_dir ?  {zylon[6:0], 1'b0} : {1'b0, zylon[7:1]};
        end
    end
end

kitt audio(
    .address(kitt_audio_addr),
    .clock(clk_pix),
    .q(kitt_audio_data)
);


reg [14:0] kitt_audio_addr = 15'd0;
reg [9:0] audio_cnt = 10'd0;
wire [7:0] kitt_audio_data;

always @(posedge clk_pix) begin
    reg last_status;
    last_status <= status[4];
    if (~last_status & status[4]) begin
        audio_cnt <= 10'd0;
        kitt_audio_addr <= 15'd0;
    end
    audio_cnt <= audio_cnt + 10'd1;
    if (audio_cnt == 10'd519) begin
        audio_cnt <= 10'd0;
        kitt_audio_addr <= kitt_audio_addr + 15'd1;
        if (kitt_audio_addr == 15'd28215) kitt_audio_addr <= 15'd0;
    end
end

wire kitt_bck;
wire kitt_lrck;
wire kitt_data;

assign I2S_BCK = status[4] ? kitt_bck : I2S_MIDI_BCK;
assign I2S_LRCK = status[4] ? kitt_lrck : I2S_MIDI_LRCK;
assign I2S_DATA = status[4] ? kitt_data : I2S_MIDI_DATA;

wire [7:0] i2s_audio = status[4] ? kitt_audio_data : 8'd0;
i2s i2s (
    .reset(1'b0),
    .clk(clk_pix),
    .clk_rate(32'd12_500_000),

    .sclk(kitt_bck),
    .lrclk(kitt_lrck),
    .sdata(kitt_data),

    .left_chan({i2s_audio[7], i2s_audio, 7'd0}),
    .right_chan({i2s_audio[7], i2s_audio, 7'd0})
);


reg  [23:0] bmp_data_start;
wire [22:0] downl_addr = ioctl_addr[22:0] - bmp_data_start[22:0];
reg bmp_loaded = 0;
reg port1_req;

always @(posedge clk_sys) begin
    reg ioctl_wr_last = 0;
    reg ioctl_downl_last = 0;

    ioctl_wr_last <= ioctl_wr;
    ioctl_downl_last <= ioctl_downl;

    if (ioctl_downl) begin
        if (~ioctl_wr_last & ioctl_wr) begin
            if (ioctl_addr == 10) bmp_data_start[7:0] <= ioctl_dout;
            else if (ioctl_addr == 11) bmp_data_start[15:8] <= ioctl_dout;
            else if (ioctl_addr == 12) bmp_data_start[23:16] <= ioctl_dout;
            port1_req <= ~port1_req;
        end
    end
    if (ioctl_downl_last & ~ioctl_downl) bmp_loaded <= 1;
end

wire [31:0] cpu_q;
reg [22:0] cpu1_addr;

// max is ((312 - 1) * 512) + 639) * 4 = 639484 . 20 bits
always @(posedge clk_ram) begin
    cpu1_addr <= (((line_max - 1'd1 - vc) * 640) + hc) << 2;
end

assign SDRAM_CLK = clk_ram;
assign SDRAM_CKE = 1;

sdram #(.MHZ(100)) sdram(
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),

    .init_n(pll_locked),
    .clk( clk_ram),
    .clkref(),

    .port1_req(port1_req),
    .port1_ack(),
    .port1_a(downl_addr[22:1]),
    .port1_ds({downl_addr[0], ~downl_addr[0]}),
    .port1_we(ioctl_downl),
    .port1_d({ioctl_dout, ioctl_dout}),
    .port1_q(),

    .cpu1_addr(cpu1_addr[22:2]),
    .cpu1_q(cpu_q),
    .cpu1_oe(~ioctl_downl)
);

//______________________________________________________________________________
//
// Video 
//

reg[9:0] hc;
reg[8:0] vc;
reg[9:0] vvc;
reg[1:0] vvc_frac;   // fractional part, for the speed of the classic background
reg[15:0] frame_cnt;
reg[17:0] anim_acc;     // animation counter with 2 fractional bits
wire[15:0] anim = anim_acc[17:2];

reg [22:0] rnd_reg;
wire [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

wire [22:0] rnd;
lfsr random(rnd);

always @(posedge clk_pix) begin
    if(hc == 799) begin
        hc <= 0;
        if(vc == line_max - 1) begin
            vc <= 0;
            // classic background: 6 per frame at Normal speed
            case (status[26:25])
                2'd1:    {vvc, vvc_frac} <= {vvc, vvc_frac} + 12'd12;   // 3
                2'd2:    {vvc, vvc_frac} <= {vvc, vvc_frac} + 12'd6;    // 1.5
                2'd3:    {vvc, vvc_frac} <= {vvc, vvc_frac} + 12'd48;   // 12
                default: {vvc, vvc_frac} <= {vvc, vvc_frac} + 12'd24;   // 6
            endcase
            frame_cnt <= frame_cnt + 1'd1;
            // Speed: Normal 1, Slow 1/2, Very slow 1/4, Fast 2 steps per frame
            case (status[26:25])
                2'd1:    anim_acc <= anim_acc + 18'd2;
                2'd2:    anim_acc <= anim_acc + 18'd1;
                2'd3:    anim_acc <= anim_acc + 18'd8;
                default: anim_acc <= anim_acc + 18'd4;
            endcase
        end else begin
            vc <= vc + 1'd1;
        end
    end else begin
        hc <= hc + 1'd1;
    end
    
    rnd_reg <= rnd;
end

reg HBlank;
reg HSync, HSync_VGA;
reg VBlank;
reg VSync;

always @(posedge clk_pix) begin
   if (hc == 640+2) begin
       HBlank <= 1;
       if (vc == line_max - 5) VBlank <= 1;
   end
   if (hc == 2) begin
       HBlank <= 0;
       if (vc == 2) VBlank <= 0;
   end

   if (hc == 655) begin
       HSync <= 1;
       HSync_VGA <= 1;
   end
   if (hc == 655+64) HSync <= 0;
   if (hc == 655+96) HSync_VGA <= 0;

   if(vc == line_max-3 && hc == 655) VSync <= 1;
        else if (vc == 0 && hc == 751) VSync <= 0;

end

///// Noise
reg  [7:0] cos_out;
wire [7:0] cos_g = cos_out[7:1]+6'd32;
cos cos(vvc + {vc, 2'b00}, cos_out);

wire [7:0] comp_v = (cos_g >= rnd_c) ? cos_g - rnd_c : 8'd0;

///// Waterfall background
wire [7:0] wf_r, wf_g, wf_b;

waterfall_bg waterfall_bg (
    .clk(clk_pix),
    .hc(hc),
    .vc(vc),
    .line_max(line_max),
    .frame(anim[9:0]),
    .noise(rnd_reg[7:0]),
    .r(wf_r),
    .g(wf_g),
    .b(wf_b)
);

///// Matrix background
wire [7:0] mx_r, mx_g, mx_b;

matrix_bg matrix_bg (
    .clk(clk_pix),
    .hc(hc),
    .vc(vc),
    .frame(anim),
    .r(mx_r),
    .g(mx_g),
    .b(mx_b)
);

///// Sea background
wire [7:0] sea_r, sea_g, sea_b;

sea_bg sea_bg (
    .clk(clk_pix),
    .hc(hc),
    .vc(vc),
    .line_max(line_max),
    .frame(anim),
    .r(sea_r),
    .g(sea_g),
    .b(sea_b)
);

///// Calypso logo (on the animated and classic backgrounds)
wire [1:0] logo_a;

calypso_logo calypso_logo (
    .clk(clk_pix),
    .hc(hc),
    .vc(vc),
    .line_max(line_max),
    .alpha(logo_a)
);

// Background type: 0 waterfall, 1 matrix, 2 sea, 3 classic, 4 file (MENU.ROM
// or a loaded BMP; classic if there is none)
wire [2:0] bg_sel   = status[24:22];
wire       animated = (bg_sel <= 3'd2);
wire       use_file = (bg_sel == 3'd4) && bmp_loaded;
// the logo goes on every background except a picture file (it has its own)
wire       show_logo = !use_file && ~status[27];

reg [7:0] anim_r, anim_g, anim_b;
always @(*) begin
    case (bg_sel)
        3'd1:    {anim_r, anim_g, anim_b} = {mx_r,  mx_g,  mx_b};
        3'd2:    {anim_r, anim_g, anim_b} = {sea_r, sea_g, sea_b};
        default: {anim_r, anim_g, anim_b} = {wf_r,  wf_g,  wf_b};
    endcase
end

// logo blending: red as in menu.rom, 2-bit alpha
localparam [7:0] LOGO_R = 8'd226, LOGO_G = 8'd0, LOGO_B = 8'd17;
wire [1:0] la = show_logo ? logo_a : 2'd0;

function automatic [7:0] blend(input [7:0] bg, input [7:0] fg, input [1:0] a);
    reg [9:0] t;
    begin
        case (a)
            2'd3:    t = fg;
            2'd2:    t = (bg + fg) >> 1;
            2'd1:    t = (bg + bg + bg + fg) >> 2;
            default: t = bg;
        endcase
        blend = t[7:0];
    end
endfunction

wire [7:0] base_r = animated ? anim_r : use_file ? cpu_q[23:16] : comp_v;
wire [7:0] base_g = animated ? anim_g : use_file ? cpu_q[15: 8] : comp_v;
wire [7:0] base_b = animated ? anim_b : use_file ? cpu_q[ 7: 0] : comp_v;

wire [7:0] bg_r = blend(base_r, LOGO_R, la);
wire [7:0] bg_g = blend(base_g, LOGO_G, la);
wire [7:0] bg_b = blend(base_b, LOGO_B, la);

///// LCD clock (only shown when the firmware sends the time from a USB RTC)
wire       clock_active;
wire [1:0] clock_a;
wire [7:0] clock_r, clock_g, clock_b;

lcd_clock #(.CLK_HZ(12_500_000)) lcd_clock (
    .clk(clk_pix),
    .hc(hc),
    .vc(vc),
    .line_max(line_max),
    .rtc(rtc),
    .enable(~status[14]),
    .vpos(status[16:15]),
    .hpos(status[18:17]),
    .palette(status[21:19]),
    .size(status[28]),
    .datefmt(status[30:29]),
    .pointed(status[31]),
    .weekday(status[35:34]),
    .no_panel(status[32]),
    .no_shadow(status[33]),
    .active(clock_active),
    .alpha(clock_a),
    .r(clock_r),
    .g(clock_g),
    .b(clock_b)
);

// clock over the background: opaque, or the shadow of the unlit segments at
// 1/8 when there is no panel
function automatic [7:0] clock_mix(input [7:0] bg, input [7:0] fg, input [1:0] a);
    reg [10:0] t;
    begin
        case (a)
            2'd3:    t = fg;
            2'd1:    t = ({3'd0, bg} * 11'd7 + fg) >> 3;
            default: t = bg;
        endcase
        clock_mix = t[7:0];
    end
endfunction

wire [7:0] R_in = clock_mix(bg_r, clock_r, clock_a);
wire [7:0] G_in = clock_mix(bg_g, clock_g, clock_a);
wire [7:0] B_in = clock_mix(bg_b, clock_b, clock_a);

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(10),
    .OSD_AUTO_CE(0),
    .OUT_COLOR_DEPTH(VGA_BITS),
    .USE_BLANKS(1),
    .BIG_OSD(BIG_OSD)
) mist_video (
    .clk_sys(clk_x2),
    .SPI_SCK(SPI_SCK),
    .SPI_SS3(SPI_SS3),
    .SPI_DI(SPI_DI),
    .R(R_in),
    .G(G_in),
    .B(B_in),
    .HBlank(HBlank),
    .VBlank(VBlank),
    .HSync(scandoubler_disable ? ~HSync : ~HSync_VGA),
    .VSync(~VSync),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_VS(VGA_VS),
    .VGA_HS(VGA_HS),
    .ce_divider(1'b1),
    .rotate({rotate[0], |rotate}),
    .blend(1'b0),
    .scandoubler_disable(scandoubler_disable),
    .scanlines(2'b00),
    .ypbpr(ypbpr),
    .osd_color(osd_color),
    .osd_x_offset(osd_x_offset),
    .osd_y_offset(osd_y_offset),
    .no_csync(no_csync)
);


endmodule
