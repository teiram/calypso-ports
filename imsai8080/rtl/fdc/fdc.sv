module fdc(
    input clk,
    input ce,
    input reset,
    
    input [7:0] bus_cpu_sysctl,
    input bus_cpu_wr_n,
    input bus_cpu_rd,

    input [15:0] bus_addr,
    input [7:0] bus_data_in,
    output [7:0] bus_data_out,

    output [31:0] sd_lba_mux,
    output [1:0] sd_rd,
    output [1:0] sd_wr,
    input [1:0] sd_ack,
    input  [8:0] sd_buff_addr,
    input  [7:0] sd_buff_dout,
    output [7:0] sd_buff_din_mux,
    input sd_buff_wr,

    input [1:0] img_mounted,
    input [63:0] img_size,

    input write_protect,
    output fdc_cpu_ready,
    
    output [7:0] disk_leds
);

assign disk_leds = {
    fdd_sel[0],
    fdd_ready[0],
    fdd_sel[1],
    fdd_ready[1],
    ~write_protect,
    |sd_wr,
    (head_loaded[0] & fdd_sel[0] & fdd_ready[0]) | (head_loaded[1] & fdd_sel[1] & fdd_ready[1]),
    (track_zero[0] & fdd_sel[0] & fdd_ready[0]) | (track_zero[1] & fdd_sel[1] & fdd_ready[1])
};


wire io_rd = bus_cpu_sysctl[6];
wire io_wr = bus_cpu_sysctl[4];
wire fdc_we = io_wr == 1'b1 && bus_addr[7:3] == 5'b01100 && bus_cpu_wr_n == 1'b0; // Versafloppy port 60h-67h
always @(*) begin
    casex ({io_rd, fdd_sel, bus_addr[7:0]})
        11'b1_xx_01100011: bus_data_out = vdrsel;
        11'b1_01_011001xx: bus_data_out = fdc_data_out[0];
        11'b1_10_011001xx: bus_data_out = fdc_data_out[1];
        default: bus_data_out = 8'h00;
    endcase
end

reg [7:0] vdrsel = 8'd0;
wire [1:0] head_loaded;
wire [1:0] track_zero;
reg [1:0] fdd_ready = 2'b00;
wire [1:0] fdd_sel = {vdrsel[1], vdrsel[0]};
wire fdd_side = vdrsel[4];
wire [7:0] fdc_data_out[2];
wire [31:0] sd_lba[2];
wire [7:0] sd_buff_din[2];
wire [1:0] drq;
wire [1:0] fdd_io_ena = {bus_addr[2] & fdd_ready[1] & fdd_sel[1], bus_addr[2] & fdd_ready[0] & fdd_sel[0]};

wire fdc1_cpu_ready = ~(vdrsel[7] == 1'b1 && bus_addr[7:0] == 8'h67 && fdd_ready[0] == 1'b1 && fdd_sel[0] == 1'b1 && drq[0] == 1'b0 && (io_rd | io_wr));
wire fdc2_cpu_ready = ~(vdrsel[7] == 1'b1 && bus_addr[7:0] == 8'h67 && fdd_ready[1] == 1'b1 && fdd_sel[1] == 1'b1 && drq[1] == 1'b0 && (io_rd | io_wr));
assign fdc_cpu_ready = fdc1_cpu_ready & fdc2_cpu_ready;

always @(posedge clk) begin
    reg [1:0] old_mounted;
    old_mounted <= img_mounted;

    if (~old_mounted[0] & img_mounted[0]) fdd_ready[0] <= |img_size;
    if (~old_mounted[1] & img_mounted[1]) fdd_ready[1] <= |img_size;
    
end

assign sd_lba_mux = fdd_sel[1] ? sd_lba[1] : sd_lba[0];
assign sd_buff_din_mux = fdd_sel[1] ? sd_buff_din[1] : sd_buff_din[0];

//For a Versafloppy II controller
//With DIBASE 60H
// VDRSEL   equ     DIBASE+3    ;Drive select port
// VDCOM    equ     DIBASE+4    ;WD1793 Command port
// VDSTAT   equ     DIBASE+4    ;WD1793 Status port
// VTRACK   equ     DIBASE+5    ;WD1793 Track port
// VSECT    equ     DIBASE+6    ;WD1793 Sector Register
// VDDATA   equ     DIBASE+7    ;WD1793 Data Register

// Versafloppy II VDRSEL bit assignments (all active-high)

// VDSEL0   equ     00000001b   ;select drive 0
// VDSEL1   equ     00000010b   ;select drive 1
// VDSEL2   equ     00000100b   ;select drive 2
// VDSEL3   equ     00001000b   ;select drive 3
// VSIDE1   equ     00010000b   ;Select side 1
// VMINI    equ     00100000b   ;Set up for minidisk
// VDDEN    equ     01000000b   ;Enable double-density
// VWAIT    equ     10000000b   ;Enable auto-wait circuit

always @(posedge clk) begin
    reg last_fdc_we = 1'b0;
    if (reset) begin
        last_fdc_we <= 1'b0;
    end else begin
        last_fdc_we <= fdc_we;
        
        if (~last_fdc_we & fdc_we & io_wr) begin
            if (bus_addr[7:0] == 8'h63) begin
                vdrsel <= bus_data_in;
            end
        end
    end
end

wd1793 #(.RWMODE(1), .EDSK(1)) fdc1(
    .clk_sys(clk),
    .ce(ce),
    .reset(reset),
    .io_en(fdd_io_ena[0]),
    .intrq(),
    .drq(drq[0]),
    .busy(),
    
    .rd(io_rd),
    .wr(io_wr & fdc_we),
    .addr(bus_addr[1:0]),
    .din(bus_data_in),
    .dout(fdc_data_out[0]),

    .img_mounted(img_mounted[0]),
    .img_size(img_size[19:0]),
    .sd_lba(sd_lba[0]),
    .sd_rd(sd_rd[0]),
    .sd_wr(sd_wr[0]),
    .sd_ack(sd_ack[0]),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[0]),
    .sd_buff_wr(sd_buff_wr),

    .wp(write_protect),

    .size_code(3'd0), // 26 sectors per track x 128 bytes per sector  = 3.3KB
    .layout(0),
    .side(fdd_side),
    .ready(fdd_ready[0]),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din(),
    
    .track_zero(track_zero[0]),
    .head_loaded(head_loaded[0])
);

wd1793 #(.RWMODE(1), .EDSK(1)) fdc2(
    .clk_sys(clk),
    .ce(ce),
    .reset(reset),
    .io_en(fdd_io_ena[1]),
    .intrq(),
    .drq(drq[1]),
    .busy(),
    
    .rd(io_rd),
    .wr(io_wr & fdc_we),
    .addr(bus_addr[1:0]),
    .din(bus_data_in),
    .dout(fdc_data_out[1]),

    .img_mounted(img_mounted[1]),
    .img_size(img_size[19:0]),
    .sd_lba(sd_lba[1]),
    .sd_rd(sd_rd[1]),
    .sd_wr(sd_wr[1]),
    .sd_ack(sd_ack[1]),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din[1]),
    .sd_buff_wr(sd_buff_wr),

    .wp(write_protect),

    .size_code(3'd0), // 26 sectors per track x 128 bytes per sector  = 3.3KB
    .layout(0),
    .side(fdd_side),
    .ready(fdd_ready[1]),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din(),
    
    .track_zero(track_zero[1]),
    .head_loaded(head_loaded[1])
);

endmodule
