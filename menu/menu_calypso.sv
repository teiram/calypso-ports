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


wire scandoubler_disable;
wire ypbpr;
wire no_csync;
wire [63:0] status;

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

wire [7:0] i2s_audio = status[4] ? kitt_audio_data : 8'd0;
i2s i2s (
    .reset(1'b0),
    .clk(clk_pix),
    .clk_rate(32'd12_500_000),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

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

reg [22:0] rnd_reg;
wire [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

wire [22:0] rnd;
lfsr random(rnd);

always @(posedge clk_pix) begin
    if(hc == 799) begin
        hc <= 0;
        if(vc == line_max - 1) begin
            vc <= 0;
            vvc <= vvc + 9'd6;
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

wire [7:0] R_in = bmp_loaded ? cpu_q[23:16] : comp_v;
wire [7:0] G_in = bmp_loaded ? cpu_q[15: 8] : comp_v;
wire [7:0] B_in = bmp_loaded ? cpu_q[7 : 0] : comp_v;

mist_video #(
    .COLOR_DEPTH(8),
    .SD_HCNT_WIDTH(10),
    .OSD_X_OFFSET(10),
    .OSD_Y_OFFSET(0),
    .OSD_COLOR(2),
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
    .no_csync(no_csync)
);


endmodule
