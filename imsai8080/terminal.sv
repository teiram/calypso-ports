module terminal(
    input clk36m,
    input reset,

    input [10:0] col,
    input [9:0] row /* synthesis keep */,
    input hblank,
    input vblank,
    
    input key_pressed,
    input [7:0] key_code,
    input key_strobe,
    input key_extended,
    
    input sio_we,
    input sio_rd,
    input sio_addr,
    input [7:0] sio_in,
    output reg [7:0] sio_out,
    
    output reg vout /* synthesis keep */
);


reg [10:0] video_addr /* synthesis keep */;
reg [10:0] char_addr /* synthesis keep */;
wire [7:0] char_code /* synthesis keep */;
wire [7:0] video_val /* synthesis keep */;
reg [7:0] pixels /* synthesis keep */;



font_rom font(
    .clock(clk36m),
    .address(char_addr),
    .q(video_val)
);

videoram ram(
    .clock(clk36m),
    .wraddress(video_wr_addr),
    .wren(video_we),
    .data(video_data),
    .rdaddress(video_addr),
    .q(char_code)
);

wire [9:0] vrow /* synthesis keep */= row - 10'd80;

always @(posedge clk36m) begin
    if (row >= 9'd80 && row < 9'd280) begin
        if (col < 12'd80) begin
            video_addr <= vrow[9:3] * 7'd80;
            if (col[2:0] == 3'd1) begin
                char_addr <= {char_code, row[2:0]};
            end else if (col[2:0] == 3'd7) begin
                pixels <= video_val;
            end
            vout <= 1'b0;
        end else if (col < 11'd720) begin
            pixels <= {pixels[6:0], 1'b0};
            vout <= pixels[7];
            if (col[2:0] == 3'd1) begin
                video_addr <= video_addr + 1'd1;
            end else if (col[2:0] == 3'd4) begin
                char_addr <= {char_code, row[2:0]};
            end else if (col[2:0] == 3'd7) begin
                pixels <= video_val;
            end
        end else begin
            vout <= 1'b0;
        end
    end else begin
        video_addr <= 'd0;
        vout <= 1'b0;
    end
end

localparam [6:0] MAX_X = 79;
localparam [6:0] MAX_Y = 24;

reg [6:0] cursor_x = 7'd0;
reg [4:0] cursor_y = 5'd0;

reg [7:0] kbd_buffer[8];
reg [2:0] kbd_buffer_rdpos = 3'd0;
reg [2:0] kbd_buffer_wrpos = 3'd0;
wire buffered_key = kbd_buffer_rdpos != kbd_buffer_wrpos;
reg [10:0] video_wr_addr = 'd0;
wire [10:0] video_cursor_addr /* synthesis keep */ = cursor_y * 7'd80 + cursor_x;
reg [7:0] video_data;
reg video_we;

always @(posedge clk36m) begin
    
    reg sio_rd_last = 1'b0;
    reg sio_we_last = 1'b0;
    reg written = 1'b0;
    reg clear = 1'b0;
    reg toggle = 1'b0;
    video_we <= 1'b0;
    
    sio_rd_last <= sio_rd;
    sio_we_last <= sio_we;
    
    if (reset == 1'b1) begin
        sio_rd_last <= 1'b0;
        sio_we_last <= 1'b0;
        cursor_x <= 'd0;
        cursor_y <= 'd0;
        written <= 1'b0;
        clear <= 1'b1;
        toggle <= 1'b0;
        video_wr_addr <= 'd0;
    end
    else if (~sio_we_last & sio_we) begin
        if (sio_addr == 1'b0) begin           // CDATA
            case (sio_in)
                8'd13: begin                  // CR
                    cursor_x <= 'd0;
                end
                8'd10: begin                  // LF
                    if (cursor_y == MAX_Y) cursor_y <= 'd0;
                    else cursor_y <= cursor_y + 1'd1;
                end
                default: begin
                    video_wr_addr <= video_cursor_addr;
                    video_data <= sio_in;
                    video_we <= 1'b1;
                    written <= 1'b1;
                end
            endcase
        end
    end
    else if (~sio_rd_last & sio_rd) begin
        if (sio_addr == 1'b1) begin          // CSTAT
            sio_out <= {6'd0, buffered_key, 1'b1};
        end
        else                                 // CDATA
        begin
            sio_out <= kbd_buffer[kbd_buffer_rdpos];
            kbd_buffer_rdpos <= kbd_buffer_rdpos + 1'd1;
        end
    end
    if (written == 1'b1) begin
        written <= 1'b0;
        if (cursor_x == MAX_X) begin
            cursor_x <= 'd0;
            if (cursor_y == MAX_Y) cursor_y <= 'd0;
            else cursor_y <= cursor_y + 1'd1; // TODO: Hardware scroll
        end
        else cursor_x <= cursor_x + 1'd1;
    end
    if (clear == 1'b1) begin
        toggle <= ~toggle;
        if (toggle == 1'b0) begin
            video_we <= 1'b1;
            video_data <= 8'd32;
        end else begin
            video_we <= 1'b0;
            if (video_wr_addr < 11'h7ff) video_wr_addr <= video_wr_addr + 1'd1;
            else clear <= 1'b0;
        end
    end
end


endmodule
