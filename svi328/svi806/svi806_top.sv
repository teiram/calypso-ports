module svi806_top(
    input clk,
    input clk_vid,
    input cpu_ce,
    input reset,

    input [15:0] cpu_addr,
    input [7:0] cpu_data_in,
    input cpu_mreq_n,
    input cpu_ioreq_n,
    input cpu_rd_n,
    input cpu_wr_n,

    output [7:0] cpu_data_out,
    output io_ena,
    output cpu_wait,

    output ramdis_n,

    output reg video = 1'b0,
    output hsync,
    output vsync,
    output de
);

wire ioreq_n = cpu_ioreq_n | (cpu_rd_n & cpu_wr_n);

wire crten_n /* synthesis keep */ = ~(cpu_addr[7:4] == 4'h5 && ioreq_n == 1'b0);
wire crtcs_n = cpu_addr[3] | crten_n; // Address 58h for bank switch
wire crtex_en = crten_n | ~cpu_addr[3]; //Zero during the IOREQ on 58

// It seems that 00 is used to disable the banking and FF to enable it on port 58

reg crtex = 1'b0;
always @(posedge clk) begin
    reg crtex_en_last = 1'b0;
    crtex_en_last <= crtex_en;

    if (reset == 1'b1) crtex <= 1'b0;
    else if (~crtex_en_last & crtex_en) crtex <= cpu_data_in[0];
end

wire vram = cpu_mreq_n == 1'b0 && cpu_addr[15:11] == 5'b11110 && crtex == 1'b1;
assign ramdis_n = ~vram;
reg wait_n = 1'b1;
reg wait_clr = 1'b0;
assign cpu_wait = ~wait_n;

// IC24-1
always @(posedge clk) begin
    reg last_vram = 1'b0;
    last_vram <= vram;
    if (wait_clr == 1'b1) wait_n <= 1'b1;
    else if (~last_vram & vram) begin
        wait_n <= 1'b0;
    end
end

// IC24-2
reg pre_wait_clr = 1'b0;
reg last_crtc_ce = 1'b0;
always @(posedge clk) begin
    last_crtc_ce <= crtc_ce;
    if (last_crtc_ce & ~crtc_ce) pre_wait_clr <= ~wait_n;
end

// IC25
always @(posedge clk) begin
    if (~last_crtc_ce & crtc_ce) wait_clr <= pre_wait_clr;
end

wire mpx /* synthesis keep */= pre_wait_clr & wait_clr;


reg crtc_en = 1'b0;
always @(posedge clk) begin
    reg last_cpu_ce = 1'b0;
    last_cpu_ce <= cpu_ce;
    if (ioreq_n == 1'b1) crtc_en <= 1'b0;
    else if (~last_cpu_ce & cpu_ce) crtc_en <= ~ioreq_n;
end


reg [2:0] cnt = 3'd1;
// 001
// 010
// 011
// 100
// 101
// 110
// 111
// clk: 0001111. 1 pulses per 7 12mhz cycles 12/7 = 1.71mhz
// For R00 = 109, that gives 109/0.85 us = 63,7us 
always @(posedge clk_vid) begin
    cnt <= cnt + 1'd1;
    if (cnt == 3'b111) cnt <= 3'd1;
end

wire crtc_ce = cnt[2];
wire chrld = &cnt;

wire [7:0] rom_data;
wire [11:0] rom_addr = {ram_data[7:0], crtc_ra[3:0]};

svi806_rom rom(
    .clock(clk),
    .address(rom_addr),
    .q(rom_data)
);

wire [7:0] ram_data;
wire [10:0] ram_addr;
svi806_ram ram(
    .clock(clk),
    .address(mpx == 1'b1 ? cpu_addr[10:0] : crtc_ma[10:0]),
    .wren(mpx & ~cpu_wr_n),
    .data(cpu_data_in),
    .q(ram_data)
);

always @(posedge clk) begin
    reg [7:0] pixel_data;
    video <= pixel_data[7];
    pixel_data <= {pixel_data[6:0], 1'b0};
    if (chrld == 1'b1) pixel_data <= rom_data;
end

wire [13:0] crtc_ma;
wire [4:0] crtc_ra;
wire [7:0] crtc_do;

um6845r crtc(
    .CLOCK(clk),
    .CLKEN(crtc_ce),
    .nRESET(~reset),
    .CRTC_TYPE(1'b0),

    .ENABLE(crtc_en),
    .nCS(crtcs_n),
    .R_nW(~cpu_rd_n),
    .RS(cpu_addr[0]),
    .DI(cpu_data_in),
    .DO(crtc_do),

    .VSYNC(vsync),
    .HSYNC(hsync),
    .DE(de),
    .FIELD(),
    .CURSOR(),

    .MA(crtc_ma),
    .RA(crtc_ra)
);

assign cpu_data_out = crten_n == 1'b1 ? 
    vram == 1 && cpu_rd_n == 1'b0 ? ram_data: 8'd0 : 
    crtc_do;
assign io_ena = (crten_n == 1'b0 || vram == 1) && cpu_rd_n == 1'b0;

endmodule
