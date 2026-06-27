module svi806_top(
    input clk,
    input cpu_ce,
    input pix_ce,
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
    output reg de = 1'b0
);

wire ioreq_n = cpu_ioreq_n | (cpu_rd_n & cpu_wr_n);

wire crten_n = ~(cpu_addr[7:4] == 4'h5 && ioreq_n == 1'b0);
wire crtcs_n = cpu_addr[3] | crten_n; // Address 58h for bank switch
wire crtex_en = crten_n | ~cpu_addr[3]; //Zero during the IOREQ on 58

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
always @(posedge clk) begin
    if (crtc_ce_n == 1'b1) pre_wait_clr <= ~wait_n;
end

// IC25
always @(posedge clk) begin
    if (crtc_ce == 1'b1) wait_clr <= pre_wait_clr;
end

wire mpx = pre_wait_clr | wait_clr;

reg crtc_en = 1'b0;
always @(posedge clk) begin
    if (cpu_ce == 1'b1) crtc_en <= ~ioreq_n;
    else if (ioreq_n == 1'b1) crtc_en <= 1'b0;
end

// 000
// 001 <- Positive edge
// 010
// 011
// 100 <- Negative edge
// 101
// 110
// 111 <- End, load char
reg [2:0] cnt = 3'b001;
always @(posedge clk) begin
    if (pix_ce == 1'b1) begin
        cnt <= cnt + 1'd1;
        if (cnt == 3'b111) cnt <= 3'b001;
    end
end

wire crtc_ce = pix_ce == 1'b1 && cnt == 3'b001;
wire crtc_ce_n = pix_ce == 1'b1 && cnt == 3'b100;
wire chrld = pix_ce == 1'b1 && cnt == 3'b111;

wire [7:0] rom_data;
wire [11:0] rom_addr = {vram_q[7:0], crtc_ra[3:0]};

svi806_rom rom(
    .clock(clk),
    .address(rom_addr),
    .q(rom_data)
);

wire [7:0] vram_q;
wire [7:0] vram_cpu_q;
wire [10:0] ram_addr;

svi806_ram ram(
    .clock(clk),
    .data_a(8'd0),
    .address_a(crtc_ma[10:0]),
    .q_a(vram_q),
    .wren_a(1'b0),
    
    .address_b(cpu_addr[10:0]),
    .q_b(vram_cpu_q),
    .wren_b(mpx & ~cpu_wr_n),
    .data_b(cpu_data_in)
);

reg cursor = 1'b0;

always @(posedge clk) begin
    reg [7:0] pixel_data;
    if (pix_ce == 1'b1) begin
        video <= pixel_data[7] | cursor;
        pixel_data <= {pixel_data[6:0], 1'b0};
        if (chrld == 1'b1) pixel_data <= rom_data;
    end
end

wire [13:0] crtc_ma;
wire [4:0] crtc_ra;
wire [7:0] crtc_do;
wire crtc_de;
wire crtc_cursor;

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
    .DE(crtc_de),
    .FIELD(),
    .CURSOR(crtc_cursor),

    .MA(crtc_ma),
    .RA(crtc_ra)
);


always @(posedge clk) begin
    if (reset) de <= 1'b0;
    else if (crtc_ce == 1'b1) begin
        de <= crtc_de;
    end
end


always @(posedge clk) begin
    if (reset) cursor <= 1'b0;
    else if (chrld == 1'b1) begin
        cursor <= crtc_cursor;
    end
end

assign cpu_data_out = crten_n == 1'b1 ? 
    vram == 1 && cpu_rd_n == 1'b0 ? vram_cpu_q: 8'd0 : 
    crtc_do;
assign io_ena = (crten_n == 1'b0 || vram == 1) && cpu_rd_n == 1'b0;

endmodule
