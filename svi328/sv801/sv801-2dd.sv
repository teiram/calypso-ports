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

    input write_protect
);

wire io_we = wr == 1'b1 && ioreq == 1'b1;
wire fdc_we = io_we && bus_addr[7:4] == 4'h3;
wire io_rd = rd == 1'b1 && ioreq == 1'b1;
wire fdc_rd = io_rd && bus_addr[7:4] == 4'h3;

wire [7:0] fdcs_data_out[2];
wire [31:0] sd_lba[2];
wire [7:0] sd_buff_din[2];
wire [1:0] fdd_sel= ~drivesel[1:0];
assign fdc_ena = fdc_rd;

assign sd_lba_mux = fdd_sel[1] ? sd_lba[1] : sd_lba[0];
assign sd_buff_din_mux = fdd_sel[1] ? sd_buff_din[1] : sd_buff_din[0];

always @(*) begin
    casex ({io_rd, drivesel[1:0], bus_addr[7:0]})
        11'b1_10_0011_0100: fdc_data_out = {{4{intrq[0]}}, {4{drq[0]}}};
        11'b1_01_0011_0100: fdc_data_out = {{4{intrq[1]}}, {4{drq[1]}}};
        11'b1_10_0011_00xx: fdc_data_out = fdcs_data_out[0];
        11'b1_01_0011_00xx: fdc_data_out = fdcs_data_out[1];
        //Hack to circumvent the double controller (setting and reading
        //track/sector with no drive selected must work)
        11'b1_xx_0011_00xx: fdc_data_out = fdcs_data_out[0];
        default: fdc_data_out = 8'h00;
    endcase
end

reg [3:0] drivesel = 4'b0000;
reg [1:0] side_density = 2'd0;
reg [1:0] fdd_ready = 2'b00;
wire [1:0] drq;
wire [1:0] intrq;


always @(posedge clk) begin
    reg [1:0] old_mounted;
    old_mounted <= img_mounted;

    if (~old_mounted[0] & img_mounted[0]) fdd_ready[0] <= |img_size;
    if (~old_mounted[1] & img_mounted[1]) fdd_ready[1] <= |img_size;
    
end

reg [1:0] cnt =  
always @(posedge clk) begin
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
    .intrq(intrq[0]),
    .drq(drq[0]),
    .busy(),
    
    .rd(io_rd),
    .wr(fdc_we),
    .addr(bus_addr[1:0]),
    .din(fdc_data_in),
    .dout(fdcs_data_out[0]),

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

    .size_code(3'd5), // SVI328 disks 
    
    .layout(1),
    .side(side_density[0]),
    .ready(1'b1),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din()
);

wd1793 #(.RWMODE(1), .EDSK(0)) fdc2(
    .clk_sys(clk),
    .ce(ce),
    .reset(reset),
    .io_en(1'b1),
    .intrq(intrq[1]),
    .drq(drq[1]),
    .busy(),
    
    .rd(io_rd),
    .wr(fdc_we),
    .addr(bus_addr[1:0]),
    .din(fdc_data_in),
    .dout(fdcs_data_out[1]),

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

    .size_code(3'd5), // SVI328 disks 
    
    .layout(1),
    .side(side_density[1]),
    .ready(1'b1),
    .prepare(),

    .input_active(),
    .input_addr(),
    .input_data(),
    .input_wr(),
    .buff_din()
);
endmodule
