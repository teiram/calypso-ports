module sio2(
    input clk,
    input reset,

    input [7:0] bus_cpu_sysctl,
    input bus_cpu_rd,
    input bus_cpu_wr_n,
    input [15:0] bus_addr,
    input [7:0] bus_data_in,
    output [7:0] bus_data_out,

    input cts,
    input rts,
    input [7:0] serial_in,
    output reg serial_in_strobe = 1'b0,
    output reg [7:0] serial_out = 8'd0,
    output reg serial_out_strobe = 1'b0
);

parameter [3:0] CARD_ADDR = 4'd0;  // SIO2 Address 0000
parameter [1:0] CARD_PORT = 2'b01; // SIO2 Port A

wire io_rd = bus_cpu_sysctl[6];
wire io_we = bus_cpu_sysctl[4];
wire sio_rd = io_rd == 1'b1 &&
    bus_addr[7:1] == {CARD_ADDR, 1'b0, CARD_PORT} &&
    bus_cpu_rd == 1'b1;
wire sio_we = io_we == 1'b1 &&
    bus_addr[7:1] == {CARD_ADDR, 1'b0, CARD_PORT} &&
    bus_cpu_wr_n == 1'b0;
reg [7:0] io_data_out /* synthesis keep */;
assign bus_data_out = sio_rd == 1'b1 ? io_data_out : 8'd0;

always @(posedge clk) begin
    
    reg sio_rd_last = 1'b0;
    reg sio_we_last = 1'b0;
    
    sio_rd_last <= sio_rd;
    sio_we_last <= sio_we;
    
    serial_out_strobe <= 1'b0;
    serial_in_strobe <= 1'b0;

    if (reset == 1'b1) begin
        sio_rd_last <= 1'b0;
        sio_we_last <= 1'b0;
        serial_out <= 8'd0;
    end
    else if (~sio_rd_last & sio_rd) begin
        if (bus_addr[0] == 1'b1) begin          // CSTAT
            io_data_out <= {6'd0, rts, cts};
        end
        else                                    // CDATA
        begin
            io_data_out <= serial_in;
            serial_in_strobe <= 1'b1;
        end
    end
    else if (~sio_we_last & sio_we) begin
        if (bus_addr[0] == 1'b0) begin          // CDATA
            serial_out <= bus_data_in;
            serial_out_strobe <= 1'b1;
        end
    end

end

endmodule
