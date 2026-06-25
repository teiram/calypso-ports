module sv801(
    input clk,
    input ce,
    input reset,
    
    input ioreq,
    input rd,
    input wr,
    input [15:0] bus_addr,
    input [7:0] fdc_data_in,
    output [7:0] fdc_data_out,
    output fdc_ena,

    output [31:0] sd_lba,
    output sd_rd,
    output sd_wr,
    input sd_ack,
    input  [8:0] sd_buff_addr,
    input  [7:0] sd_buff_dout,
    output [7:0] sd_buff_din,
    input sd_buff_wr,

    input img_mounted,
    input [63:0] img_size,

    input write_protect
);

wire io_we = wr == 1'b1 && ioreq == 1'b1;
wire fdc_we = io_we && bus_addr[7:4] == 4'h3;
wire io_rd = rd == 1'b1 && ioreq == 1'b1;
wire fdc_rd = io_rd && bus_addr[7:4] == 4'h3;

wire [7:0] fdc_dout;
wire fdd_sel= drivesel[0];
assign fdc_ena = fdc_rd;

always @(*) begin
    casex ({io_rd, bus_addr[7:0]})
        11'b1_00110100: fdc_data_out = {intrq, drq, 6'd0};
        11'b1_001100xx: fdc_data_out = fdc_dout;
        default: fdc_data_out = 8'h00;
    endcase
end

reg [3:0] drivesel = 4'b0000;
reg [1:0] side_density = 2'd0;
reg [1:0] fdd_ready = 2'b00;
wire drq;
wire intrq;


always @(posedge clk) begin
    reg old_mounted;
    old_mounted <= img_mounted;

    if (~old_mounted & img_mounted) fdd_ready <= |img_size;
end

always @(posedge clk) begin
    reg last_fdc_we = 1'b0;
    if (reset) begin
        last_fdc_we <= 1'b0;
    end else begin
        last_fdc_we <= fdc_we;

        if (~last_fdc_we & fdc_we) begin
            if (bus_addr[7:0] == 8'h34) drivesel <= fdc_data_in[3:0];
            else if (bus_addr[7:0] == 8'h38) side_density <= fdc_data_in[1:0];
        end
    end
end

wd1793 #(.RWMODE(1), .EDSK(0)) fdc1(
    .clk_sys(clk),
    .ce(ce),
    .reset(reset),
    .io_en(1'b1),
    .intrq(intrq),
    .drq(drq),
    .busy(),
    
    .rd(fdc_rd == 1'b1 && bus_addr[3:2] == 2'b00),
    .wr(fdc_we == 1'b1 && bus_addr[3:2] == 2'b00),
    .addr(bus_addr[1:0]),
    .din(fdc_data_in),
    .dout(fdc_dout),

    .img_mounted(img_mounted),
    .img_size(img_size[19:0]),

    .sd_lba(sd_lba),
    .sd_rd(sd_rd),
    .sd_wr(sd_wr),
    .sd_ack(sd_ack),
    .sd_buff_addr(sd_buff_addr),
    .sd_buff_dout(sd_buff_dout),
    .sd_buff_din(sd_buff_din),
    .sd_buff_wr(sd_buff_wr),

    .wp(write_protect),

    .size_code(3'd5), // SVI328 disks 
    
    .layout(1),
    .side(side_density[0]),
    .ready(fdd_ready),
//    .ready(1'b1),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din()
);

endmodule
