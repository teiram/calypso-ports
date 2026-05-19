module terminal(
    input clk36m,
    input reset,

    input [10:0] col,
    input [9:0] row,
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

/*
    To ease video wrapping implementation we need a power of 2 line length
    For 80 chars, we need to go to the next power of 2: 128 = 80h
    Total RAM for 25 lines of 80h = 3200 bytes
    Wrap at: 80hx25 = c80h = addr[11:7] = 11001
*/
reg [4:0] video_start_row = 5'd0;
wire [11:0] video_addr /* synthesis keep */;
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

localparam [6:0] V_OFFSET = 7'd80;
localparam [6:0] H_OFFSET = 7'd80;
localparam [9:0] H_SIZE = 640;
localparam [8:0] V_SIZE = 200;
localparam [6:0] MAX_X = 7'd79;
localparam [4:0] MAX_Y = 5'd24;

wire [9:0] vrow = row - V_OFFSET;
wire [6:0] wrow = (vrow[9:3] + video_start_row) < 5'd25 ?
    vrow[9:3] + video_start_row :
    vrow[9:3] + video_start_row - 5'd25;

always @(posedge clk36m) begin
    if (row >= V_OFFSET && row < (V_SIZE + V_OFFSET)) begin
        if (col < H_OFFSET) begin
            video_addr <= {wrow[4:0], 7'd0};
            if (col[2:0] == 3'd1) begin
                char_addr <= {char_code, row[2:0]};
            end else if (col[2:0] == 3'd7) begin
                pixels <= video_val;
            end
            vout <= 1'b0;
        end else if (col < (H_OFFSET + H_SIZE)) begin
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


reg [6:0] cursor_x = 7'd0;
reg [4:0] cursor_y = 5'd0;

reg [7:0] kbd_buffer[8];
reg [2:0] kbd_buffer_rdpos = 3'd0;
reg [2:0] kbd_buffer_wrpos = 3'd0;
wire buffered_key = kbd_buffer_rdpos != kbd_buffer_wrpos;
reg [11:0] video_wr_addr = 'd0;
reg [11:0] video_wr_addr_end = 'd0;

wire [11:0] video_cursor_addr /* synthesis keep */ = {cursor_y + video_start_row, cursor_x[6:0]}; //128 bytes per line
reg [7:0] video_data;
reg video_we;

always @(posedge clk36m) begin
    
    reg sio_rd_last = 1'b0;
    reg sio_we_last = 1'b0;
    reg written = 1'b0;
    reg clear = 1'b0;
    reg lf = 1'b0;
    reg wr_toggle = 1'b0;
    video_we <= 1'b0;
    
    sio_rd_last <= sio_rd;
    sio_we_last <= sio_we;
    
    if (reset == 1'b1) begin
        sio_rd_last <= 1'b0;
        sio_we_last <= 1'b0;
        cursor_x <= 'd0;
        cursor_y <= 'd0;
        kbd_buffer_rdpos <= 1'b0;
        written <= 1'b0;
        clear <= 1'b1;
        lf <= 1'b0;
        wr_toggle <= 1'b0;
        video_wr_addr <= 'd0;
        video_wr_addr_end <= 'd3200;
        video_start_row <= 'd0;
    end
    else if (~sio_we_last & sio_we) begin
        if (sio_addr == 1'b0) begin           // CDATA
            case (sio_in)
                8'd13: begin                  // CR
                    cursor_x <= 'd0;
                end
                8'd10: begin                  // LF
                    lf <= 1'b1;
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
            sio_out <= {6'd0, buffered_key, 1'b1}; // bit1: Ready to send, bit0: Ready to receive
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
            lf <= 1'b1;
        end
        else cursor_x <= cursor_x + 1'd1;
    end
    if (lf == 1'b1) begin
        lf <= 1'b0;
        if (cursor_y == MAX_Y) begin
            clear <= 1'b1;
            wr_toggle <= 1'b0;
            video_wr_addr <= {video_start_row, 7'd0};
            video_wr_addr_end <= {video_start_row + 1'd1, 7'd0};
            if (video_start_row < MAX_Y) video_start_row <= video_start_row + 1'd1;
            else video_start_row <= 5'd0;
        end
        else cursor_y <= cursor_y + 1'd1;
    end
    if (clear == 1'b1) begin
        wr_toggle <= ~wr_toggle;
        if (wr_toggle == 1'b0) begin
            video_we <= 1'b1;
            video_data <= 8'd32;
        end else begin
            video_we <= 1'b0;
            if (video_wr_addr < video_wr_addr_end) video_wr_addr <= video_wr_addr + 1'd1;
            else clear <= 1'b0;
        end
    end
end

always @(posedge clk36m) begin
    reg ctrl = 1'b0;
    reg shift = 1'b0;
    reg capslock = 1'b0;
    if (reset == 1'b1) begin
        kbd_buffer_wrpos <= 1'b0;
        shift <= 1'b0;
        ctrl <= 1'b0;
        capslock <= 1'b0;
    end
    else if (key_strobe == 1'b1) begin
        casex ({ctrl, shift, key_pressed, key_code})
        
            {3'b???, 9'h?14}: ctrl <= key_pressed;
            {3'b??1, 8'h76}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h1b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Escape

            {3'b001, 8'h0e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h60; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // grave
            {3'b001, 8'h16}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h31; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 1
            {3'b001, 8'h1e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h32; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 2
            {3'b001, 8'h26}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h33; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 3
            {3'b001, 8'h25}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h34; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 4
            {3'b001, 8'h2e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h35; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 5
            {3'b001, 8'h36}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h36; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 6
            {3'b001, 8'h3d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h37; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 7
            {3'b001, 8'h3e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h38; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 8
            {3'b001, 8'h46}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h39; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 9
            {3'b001, 8'h45}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h30; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // 0
            {3'b001, 8'h4e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // -
            {3'b001, 8'h55}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // =
            {3'b0?1, 8'h66}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h08; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Backspace

            {3'b011, 8'h0e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // tilde
            {3'b011, 8'h16}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h21; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // !
            {3'b011, 8'h1e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h40; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // @
            {3'b011, 8'h26}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h23; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // #
            {3'b011, 8'h25}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h24; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // $
            {3'b011, 8'h2e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h25; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // %
            {3'b011, 8'h36}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // ^
            {3'b011, 8'h3d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h26; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // &
            {3'b011, 8'h3e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // *
            {3'b011, 8'h46}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h28; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // (
            {3'b011, 8'h45}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h29; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // )   
            {3'b011, 8'h4e}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // _
            {3'b011, 8'h55}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // +

            {3'b0?1, 8'h0d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h09; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // TAB
            {3'b0?1, 8'h15}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h51; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Q
            {3'b1?1, 8'h15}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h11; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-Q Continue transmission
            {3'b0?1, 8'h1d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h57; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // W
            {3'b0?1, 8'h24}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h45; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // E
            {3'b0?1, 8'h2d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h52; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // R
            {3'b0?1, 8'h2c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h54; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // T
            {3'b0?1, 8'h35}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h59; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Y
            {3'b0?1, 8'h3c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h55; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // U
            {3'b0?1, 8'h43}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h49; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // I
            {3'b0?1, 8'h44}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // O
            {3'b0?1, 8'h4d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h50; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // P
            {3'b001, 8'h54}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // [
            {3'b011, 8'h54}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // {
            {3'b001, 8'h5b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // ]
            {3'b011, 8'h5b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // }
            {3'b001, 8'h5d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // backslash
            {3'b011, 8'h5d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // |

            {3'b??1, 9'h058}: capslock <= ~capslock;
//            {3'b0?1, 8'h1c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h41 | {3'd0, ~(capslock ^ shift), 4'd0}; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // A
            {3'b0?1, 8'h1c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h41; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // A
            {3'b0?1, 8'h1b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h53; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // S
            {3'b1?1, 8'h1b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h13; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-S Pause transmission
            {3'b0?1, 8'h23}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h44; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // D
            {3'b1?1, 8'h23}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h04; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-D
            {3'b0?1, 8'h2b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h46; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // F
            {3'b0?1, 8'h34}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h47; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // G
            {3'b1?1, 8'h34}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h07; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-G (Bell)
            {3'b0?1, 8'h33}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h48; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // H
            {3'b1?1, 8'h33}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h08; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-H (Backspace)
            {3'b0?1, 8'h3b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // J
            {3'b0?1, 8'h42}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // K
            {3'b0?1, 8'h4b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // L
            {3'b001, 8'h4c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ;
            {3'b011, 8'h4c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // :
            {3'b001, 8'h52}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h27; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // '
            {3'b011, 8'h52}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h22; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // "

            {3'b??1, 8'h5a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'd13; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'd1; end     // Enter
            
            {3'b???, 8'h12}: shift <= key_pressed;
            {3'b0?1, 8'h1a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Z
            {3'b0?1, 8'h22}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h58; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // X
            {3'b0?1, 8'h21}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h43; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // C
            {3'b1?1, 8'h21}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h03; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-C
            {3'b0?1, 8'h2a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h56; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // V
            {3'b0?1, 8'h32}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h42; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // B
            {3'b0?1, 8'h31}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // N
            {3'b0?1, 8'h3a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // M
            {3'b001, 8'h41}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ,
            {3'b011, 8'h41}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // <
            {3'b001, 8'h49}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // .
            {3'b011, 8'h49}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // >
            {3'b001, 8'h4a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // /
            {3'b011, 8'h4a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ?
            {3'b???, 8'h59}: shift <= key_pressed;
        endcase
    end
end


endmodule
