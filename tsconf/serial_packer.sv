module serial_packer(
    input wire clock,
    input wire serial_in,

    output reg [7:0] serial_out = 8'd0,
    output reg serial_strobe_out = 1'b0
);

localparam
    WAIT_START   = 4'h0,
    START        = 4'h1,
    GET_BITS     = 4'h2,
    WAIT_STOP    = 4'h3,
    TX_DATA      = 4'h4;

parameter CLK_SYS_HZ = 84000000;
parameter CLK_SERIAL_HZ = 31250;
localparam SERIAL_PULSE_TICKS = 1.02 * (CLK_SYS_HZ / CLK_SERIAL_HZ);

reg [3:0] serial_status = WAIT_START;

always @(posedge clock) begin
    reg serial_in_last;
    reg [3:0] serial_bitcnt;
    reg [13:0] serial_cnt;
    serial_in_last <= serial_in;
    case (serial_status)
        WAIT_START: begin
            serial_strobe_out <= 1'b0;
            if (serial_in_last & ~serial_in) begin
                serial_status <= START;
                serial_cnt <= SERIAL_PULSE_TICKS;
            end
        end
        START: begin
            serial_cnt <= serial_cnt - 1'd1;
            if (~|serial_cnt) begin
                serial_status <= GET_BITS;
                serial_bitcnt <= 4'd7;
                serial_out[7] <= serial_in; 
                serial_cnt <= SERIAL_PULSE_TICKS;
            end
        end
        GET_BITS: begin
            if (~|serial_bitcnt) begin
                serial_status <= WAIT_STOP;
                serial_cnt <= SERIAL_PULSE_TICKS;
            end else begin
                serial_cnt <= serial_cnt - 1'd1;
                if (~|serial_cnt) begin
                    serial_bitcnt <= serial_bitcnt - 1'd1;
                    serial_out <= {serial_in, serial_out[7:1]};
                    serial_cnt <= SERIAL_PULSE_TICKS;
                end
            end
        end
        WAIT_STOP: begin
            serial_cnt <= serial_cnt - 1'd1;
            if (~|serial_cnt) begin
                serial_status <= TX_DATA;
            end
        end
        TX_DATA: begin
            serial_strobe_out <= 1'b1;
            serial_status <= WAIT_START;
        end
    endcase
end

endmodule