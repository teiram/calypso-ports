module terminal(
    input clk36m,
    input reset,

    input [10:0] xpos,
    input [9:0] ypos,
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
    
    output reg vout,
    
    output reg [7:0] serial_echo,
    output reg serial_echo_strobe
);

// Terminal emulation tries to implement Zenith H19, sort of extended VT52
// Supported in Wordstar and other mainstream CP/M applications

wire [11:0] raster_addr;
reg [10:0] char_addr;
wire [7:0] char_code;
wire [9:0] video_val;
reg [9:0] pixels;

font_rom font(
    .clock(clk36m),
    .address(char_addr),
    .q(video_val)
);

videoram ram(
    .clock(clk36m),
    
    .address_a(video_addr),
    .wren_a(video_we),
    .data_a(video_data),
    .q_a(video_q),
    
    .wren_b(1'b0),
    .data_b('d0),
    .address_b(raster_addr),
    .q_b(char_code)
);

localparam [9:0] H_SIZE = 800;
localparam [8:0] V_SIZE = 300;
localparam [6:0] MAX_COL = 7'd79;
localparam [4:0] MAX_ROW = 5'd23;

wire [6:0] char_codebase = char_code < 7'h20 ? 7'd0 : char_code[6:0] - 7'h20;
wire [10:0] char_addr_base = 
    {char_codebase[6:0], 2'd0} 
    + {char_codebase[6:0], 2'd0} 
    + {char_codebase[6:0], 2'd0};
    
// Tracking of the current raster position
// Since our font dimension is not a power of 2
reg [4:0] row; // Current raster row (0-24)
reg [6:0] col; // Current raster col (0-79)
reg [3:0] x;   // Raster x pixel position on char (0-9)
reg [4:0] y;   // Raster y pixel position on char (0-11)

wire cursor_enable = cursor_on == 1'b1 &&
    row == cursor_row &&
    col == cursor_col &&
    (cursor_block == 1'b1 || y[3] == 1'b1);

always @(posedge clk36m) begin
    reg [9:0] last_ypos;
    
    last_ypos <= ypos;
    
    if (last_ypos != ypos) begin
        col <= 7'd0;
        if (y < 5'd11) y <= y + 1'd1;
        else begin
            y <= 5'd0;
            row <= row + 1'd1;
        end
    end
    if (ypos >= 10'd0 && ypos < V_SIZE) begin
        if (xpos > H_SIZE) begin
            //Prepare for next line
            raster_addr <= {y < 5'd11 ? row : row + 1, 7'd0};
            if (xpos[2:0] == 3'd1) begin
                char_addr <= char_addr_base + (y < 5'd11 ? y + 1'd1 : 5'd0);
            end else if (xpos[2:0] == 3'd7) begin
                pixels <= char_code[7] ? ~video_val : video_val;
            end
            vout <= 1'b0;
            x <= 4'd0;
        end else if (xpos < H_SIZE) begin
            pixels <= {pixels[8:0], 1'b0};
            vout <= pixels[9] | cursor_enable;
            if (x == 4'd1) begin
                raster_addr <= raster_addr + 1'd1;
            end else if (x == 4'd4) begin
                char_addr <= char_addr_base + y;
            end else if (x == 4'd9) begin
                pixels <= char_code[7] ? ~video_val : video_val;
            end
            if (x == 4'd9) begin
                x <= 4'd0;
                col <= col + 1'd1;
            end
            else x <= x + 1'd1;
        end else begin
            vout <= 1'b0;
        end
    end else begin
        raster_addr <= 'd0;
        vout <= 1'b0;
        y <= 5'd0;
        row <= 5'd0;
    end
end

reg cursor_on = 1'b1;
reg cursor_block = 1'b1;
reg l25_enabled = 1'b0;
reg graphics_mode = 1'b0;

reg [6:0] cursor_col = 7'd0;
reg [4:0] cursor_row = 5'd0;
reg [6:0] saved_cursor_col = 'd0;
reg [4:0] saved_cursor_row = 'd0;

reg [7:0] kbd_buffer[8];
reg [2:0] kbd_buffer_rdpos = 3'd0;
reg [2:0] kbd_buffer_wrpos = 3'd0;
wire has_buffered_key = kbd_buffer_rdpos != kbd_buffer_wrpos;

localparam [2:0] CMD_INSERT_LINE = 3'd0;
localparam [2:0] CMD_CLEAR_LINE  = 3'd1;
localparam [2:0] CMD_LINE_UP = 3'd2;
localparam [2:0] CMD_CLEAR_LINE24 = 3'd3;
localparam [2:0] CMD_SCR_UP = 3'd4;

reg [2:0] cmd_buffer[4];
reg [1:0] cmd_buffer_rdpos = 2'd0;
reg [1:0] cmd_buffer_wrpos = 2'd0;
wire has_cmd = cmd_buffer_rdpos != cmd_buffer_wrpos;
reg cmd_running = 1'b0;

wire [11:0] video_addr = video_we ? video_wr_addr : video_rd_addr;
reg [11:0] video_wr_addr = 'd0;
reg [11:0] video_rd_addr = 'd0;
reg [11:0] video_wr_addr_end = 'd0;
reg [11:0] video_xfer_size = 'd0;
reg [7:0] video_q;


wire [11:0] video_cursor_addr = {cursor_row[4:0], cursor_col[6:0]}; //128 bytes per line
reg [7:0] video_data;
reg video_we;

always @(posedge clk36m) begin
    
    reg sio_rd_last = 1'b0;
    reg sio_we_last = 1'b0;
    reg update_cursor_pos = 1'b0;
    reg clear = 1'b0;
    reg xfer = 1'b0;
    reg xferr = 1'b0;
    reg [1:0] mem_status = 2'b00;
    reg wr_toggle = 1'b0;
    reg lf = 1'b0;
    reg escape = 1'b0;
    reg [1:0] escape_y = 2'b00;
    reg reverse_mode = 1'b0;
    reg escape_sx = 1'b0;
    reg escape_ry = 1'b0;
    
    video_we <= 1'b0;
    serial_echo <= 8'd0;
    serial_echo_strobe <= 1'b0;
    
    sio_rd_last <= sio_rd;
    sio_we_last <= sio_we;
    
    if (reset == 1'b1) begin
        sio_rd_last <= 1'b0;
        sio_we_last <= 1'b0;
        cursor_col <= 'd0;
        cursor_row <= 'd0;
        saved_cursor_col <= 'd0;
        saved_cursor_row <= 'd0;
        kbd_buffer_rdpos <= 1'b0;
        update_cursor_pos <= 1'b0;
        clear <= 1'b1;
        xfer <= 1'b0;
        xferr <= 1'b0;
        mem_status <= 2'b00;
        lf <= 1'b0;
        video_wr_addr <= 'd0;
        video_wr_addr_end <= 'd3200;
        escape_y <= 2'b00;
        reverse_mode <= 1'b0;
        escape_sx <= 1'b0;
        escape_ry <= 1'b0;
        l25_enabled <= 1'b0;
        cursor_on <= 1'b1;
        cursor_block <= 1'b1;
        serial_echo <= 8'd0;
        serial_echo_strobe <= 1'b0;
    end
    else if (has_cmd == 1'b1 && cmd_running == 1'b0) begin
        case (cmd_buffer[cmd_buffer_rdpos])
            CMD_INSERT_LINE: begin
                video_rd_addr <= {MAX_ROW - 1'd1, 7'h7f};
                video_wr_addr <= {MAX_ROW, 7'h7f};
                video_xfer_size <= {MAX_ROW - cursor_row, 7'd0};
                {xferr, mem_status, cmd_running} <= 4'b1001;
            end
            CMD_CLEAR_LINE: begin
                video_wr_addr <= {cursor_row[4:0], 7'd0};
                video_wr_addr_end <= {cursor_row[4:0], 7'h7f};
                {clear, mem_status, cmd_running} <= 4'b1001;
            end
            CMD_LINE_UP: begin
                video_rd_addr <= {cursor_row[4:0] + 1'd1, 7'd0};
                video_wr_addr <= {cursor_row[4:0], 7'd0};
                video_xfer_size <= {MAX_ROW - cursor_row, 7'd0};
                {xfer, mem_status, cmd_running} <= 4'b1001;
            end
            CMD_CLEAR_LINE24: begin
                video_wr_addr <= {MAX_ROW, 7'd0};
                video_wr_addr_end <= {MAX_ROW, 7'h7f};
                {clear, mem_status, cmd_running} <= 4'b1001;
            end
            CMD_SCR_UP: begin
                video_rd_addr <= {5'd1, 7'd0};
                video_wr_addr <= {5'd0, 7'd0};
                video_xfer_size <= {MAX_ROW, 7'd0};
                {xfer, mem_status, cmd_running} <= 4'b1001;
            end
        endcase
        cmd_buffer_rdpos <= cmd_buffer_rdpos + 1'd1;
    end
    else if (~sio_rd_last & sio_rd) begin
        if (sio_addr == 1'b1) begin          // CSTAT
            sio_out <= {6'd0, has_buffered_key, ~(clear | xfer | lf | update_cursor_pos | cmd_running | has_cmd)}; // bit1: Ready to send, bit0: Ready to receive
        end
        else                                 // CDATA
        begin
            sio_out <= kbd_buffer[kbd_buffer_rdpos];
            kbd_buffer_rdpos <= kbd_buffer_rdpos + 1'd1;
        end
    end
    else if (~sio_we_last & sio_we) begin
        if (sio_addr == 1'b0) begin           // CDATA
            serial_echo <= sio_in;
            serial_echo_strobe <= 1'b1;
            if (escape == 1'b0) begin
                case (sio_in)
                    8'd8: begin                   // BACKSPACE
                        if (|cursor_col) cursor_col <= cursor_col - 1'd1;
                    end
                    8'd13: begin                  // CR
                        cursor_col <= 'd0;
                    end
                    8'd10: begin                  // LF
                        lf <= 1'b1;
                    end
                    8'd27: escape <= 1'b1;
                    default: begin
                        video_wr_addr <= video_cursor_addr;
                        video_data <= {reverse_mode, sio_in[6:0]};
                        video_we <= 1'b1;
                        update_cursor_pos <= 1'b1;
                    end
                endcase
            end
            else begin
                if (escape_y == 2'b00 && escape_sx == 1'b0 && escape_ry == 1'b0) begin
                    case (sio_in)
                        "A": begin                   // CURSOR UP
                            if (|cursor_row) cursor_row <= cursor_row - 1'd1;
                            escape <= 1'b0;
                        end
                        "B": begin                   // CURSOR DOWN
                            if (cursor_row < MAX_ROW) cursor_row <= cursor_row + 1'd1;
                            escape <= 1'b0;
                        end
                        "C": begin                   // CURSOR RIGHT
                            if (cursor_col < MAX_COL) cursor_col <= cursor_col + 1'd1;
                            escape <= 1'b0;
                        end
                        "D": begin                   // CURSOR LEFT
                            if (|cursor_col) cursor_col <= cursor_col - 1'd1;
                            escape <= 1'b0;
                        end
                        "E": begin                   // ERASE SCREEN
                            clear <= 1'b1;
                            video_wr_addr <= 'd0;
                            video_wr_addr_end <= 'd3200;
                            cursor_col <= 'd0;
                            cursor_row <= 'd0;
                            escape <= 1'b0;
                        end
                        "F": begin                   // ENTER GRAPHICS MODE
                            graphics_mode <= 1'b1;
                            escape <= 1'b0;
                        end
                        "G": begin                   // EXIT GRAPHICS MODE
                            graphics_mode <= 1'b0;
                            escape <= 1'b0;
                        end
                        "H": begin                   // CURSOR HOME
                            cursor_col <= 'd0;
                            cursor_row <= 'd0;
                            escape <= 1'b0;
                        end
                        "I": begin                   // REVERSE LINE FEED
                            if (|cursor_row) cursor_row <= cursor_row - 1'd1;
                            cmd_buffer[cmd_buffer_wrpos] <= CMD_INSERT_LINE;
                            cmd_buffer_wrpos <= cmd_buffer_wrpos + 1'd1;
                            escape <= 1'b0;
                        end
                        "J": begin                  // ERASE TO END OF PAGE
                            video_wr_addr <= video_cursor_addr;
                            video_wr_addr_end <= {MAX_ROW, 7'h7f};
                            {clear, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "K": begin                  // ERASE TO THE END OF THE LINE
                            video_wr_addr <= video_cursor_addr;
                            video_wr_addr_end <= {cursor_row[4:0], 7'h7f};
                            {clear, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "L": begin                  //L: OPEN ROW IN CURSOR
                            cmd_buffer[cmd_buffer_wrpos] <= CMD_INSERT_LINE;
                            cmd_buffer[cmd_buffer_wrpos + 1'd1] <= CMD_CLEAR_LINE;
                            cmd_buffer_wrpos <= cmd_buffer_wrpos + 2'd2;
                            cursor_col <= 'd0;
                            escape <= 1'b0;
                        end
                        "M": begin                   // DELETE LINE
                            cmd_buffer[cmd_buffer_wrpos] <= CMD_LINE_UP;
                            cmd_buffer[cmd_buffer_wrpos + 1'd1] <= CMD_CLEAR_LINE24;
                            cmd_buffer_wrpos <= cmd_buffer_wrpos + 2'd2;
                            cursor_col <= 'd0;
                            escape <= 1'b0;
                        end
                        "N": begin                   // DELETE CHAR
                            video_wr_addr <= video_cursor_addr;
                            video_rd_addr <= video_cursor_addr + 1'd1;
                            video_xfer_size <= MAX_COL - cursor_col;
                            {xfer, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "Y": begin
                            escape_y <= 2'b01;
                        end
                        "b": begin                  // ERASE BEGINNING OF DISPLAY
                            video_wr_addr <= 'd0;
                            video_wr_addr_end <= video_cursor_addr;
                            {clear, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "j": begin                  // SAVE CURSOR POSITION
                            saved_cursor_row <= cursor_row;
                            saved_cursor_col <= cursor_col;
                            escape <= 1'b0;
                        end
                        "k": begin                  // RESTORE CURSOR POSITION
                            cursor_row <= saved_cursor_row;
                            cursor_col <= saved_cursor_col;
                            escape <= 1'b0;
                        end
                        "l": begin                  // ERASE CURSOR ENTIRE LINE
                            video_wr_addr <= {cursor_row[4:0], 7'd0};
                            video_wr_addr_end <= {cursor_row[4:0], 7'h7f};
                            {clear, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "o": begin                 // ERASE FROM BEGINNING OF LINE TO CURSOR
                            video_wr_addr <= {cursor_row[4:0], 7'd0};
                            video_wr_addr_end <= video_cursor_addr;
                            {clear, mem_status} <= 3'b100;
                            escape <= 1'b0;
                        end
                        "p": begin
                            reverse_mode <= 1'b1;
                            escape <= 1'b0;
                        end
                        "q": begin
                            reverse_mode <= 1'b0;
                            escape <= 1'b0;
                        end
                        "x": begin
                            escape_sx <= 1'b1;
                        end
                        "y": begin
                            escape_ry <= 1'b1;
                        end
                        default: begin
                            escape <= 1'b0;
                            video_wr_addr <= video_cursor_addr;
                            video_data <= {1'b0, sio_in[6:0]};
                            video_we <= 1'b1;
                            update_cursor_pos <= 1'b1;
                        end
                    endcase
                end
                else if (escape_sx == 1'b1) begin
                    escape <= 1'b0;
                    escape_sx <= 1'b0;
                    case (sio_in)
                        "1": begin
                            l25_enabled <= 1'b1;
                        end
                        "4": begin
                            cursor_block <= 1'b1;
                        end
                        "5": begin
                            cursor_on <= 1'b0;
                        end
                    endcase
                end
                else if (escape_ry == 1'b1) begin
                    escape <= 1'b0;
                    escape_ry <= 1'b0;
                    case (sio_in)
                        "1": begin
                            l25_enabled <= 1'b0;
                        end
                        "4": begin
                            cursor_block <= 1'b0;
                        end
                        "5": begin
                            cursor_on <= 1'b1;
                        end
                    endcase
                end
                else if (escape_y == 2'b01) begin
                    cursor_row <= sio_in - 8'd32;
                    escape_y <= 2'b10;
                end
                else if (escape_y == 2'b10) begin
                    cursor_col <= sio_in - 8'd32;
                    escape_y <= 2'b00;
                    escape <= 1'b0;
                end
            end
        end
    end
    else if (update_cursor_pos == 1'b1) begin
        update_cursor_pos <= 1'b0;
        if (cursor_col == MAX_COL) begin
            cursor_col <= 'd0;
            lf <= 1'b1;
        end
        else cursor_col <= cursor_col + 1'd1;
    end
    else if (lf == 1'b1) begin
        lf <= 1'b0;
        if (cursor_row == MAX_ROW) begin
            cmd_buffer[cmd_buffer_wrpos] <= CMD_SCR_UP;
            cmd_buffer[cmd_buffer_wrpos + 1'd1] <= CMD_CLEAR_LINE24;
            cmd_buffer_wrpos <= cmd_buffer_wrpos + 2'd2;
        end
        else cursor_row <= cursor_row + 1'd1;
    end
    else if (clear == 1'b1) begin
        mem_status <= mem_status + 1'd1;
        if (~&mem_status) begin
            video_we <= 1'b1;
            video_data <= 8'd32;
        end 
        else begin
            video_we <= 1'b0;
            if (video_wr_addr < video_wr_addr_end) video_wr_addr <= video_wr_addr + 1'd1;
            else begin
                clear <= 1'b0;
                cmd_running <= 1'b0;
            end
        end
    end
    else if (xfer == 1'b1) begin
        mem_status <= mem_status + 1'd1;
        if (mem_status == 2'b10) begin
            video_data <= video_q;
            video_we <= 1'b1;
        end
        else if (mem_status == 2'b11) begin
            video_we <= 1'b0;
            if (|video_xfer_size) begin
                video_wr_addr <= video_wr_addr + 1'b1;
                video_rd_addr <= video_rd_addr + 1'b1;
                video_xfer_size <= video_xfer_size - 1'b1;
            end else begin
                xfer <= 1'b0;
                cmd_running <= 1'b0;
            end
        end
    end
    else if (xferr == 1'b1) begin
        mem_status <= mem_status + 1'd1;
        if (mem_status == 2'b10) begin
            video_data <= video_q;
            video_we <= 1'b1;
        end
        else if (mem_status == 2'b11) begin
            video_we <= 1'b0;
            if (|video_xfer_size) begin
                video_wr_addr <= video_wr_addr - 1'b1;
                video_rd_addr <= video_rd_addr - 1'b1;
                video_xfer_size <= video_xfer_size - 1'b1;
            end else begin
                xferr <= 1'b0;
                cmd_running <= 1'b0;
            end
        end
    end

end

reg ctrl = 1'b0;
reg shift = 1'b0;
reg capslock = 1'b0;
wire [7:0] lowercasemask = {2'd0, ~(capslock ^ shift), 5'd0};
always @(posedge clk36m) begin

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
            {3'b0?1, 8'h15}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h51 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Q
            {3'b1?1, 8'h15}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h11; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-Q Continue transmission
            {3'b0?1, 8'h1d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h57 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // W
            {3'b1?1, 8'h1d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h17; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-W
            {3'b0?1, 8'h24}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h45 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // E
            {3'b1?1, 8'h24}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h05; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-E
            {3'b??1, 8'h75}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h05; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Cursor Up
            {3'b0?1, 8'h2d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h52 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // R
            {3'b1?1, 8'h2d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h12; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-R
            {3'b0?1, 8'h2c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h54 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // T
            {3'b1?1, 8'h2c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h14; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-T
            {3'b0?1, 8'h35}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h59 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Y
            {3'b1?1, 8'h35}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h19; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-Y
            {3'b0?1, 8'h3c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h55 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // U
            {3'b1?1, 8'h3c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h15; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-U
            {3'b0?1, 8'h43}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h49 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // I
            {3'b1?1, 8'h43}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h19; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-I
            {3'b0?1, 8'h44}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4f | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // O
            {3'b1?1, 8'h44}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-O
            {3'b0?1, 8'h4d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h50 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // P
            {3'b1?1, 8'h4d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h10; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Control-P
            {3'b001, 8'h54}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // [
            {3'b011, 8'h54}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // {
            {3'b001, 8'h5b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // ]
            {3'b011, 8'h5b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // }
            {3'b001, 8'h5d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // backslash
            {3'b011, 8'h5d}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h7c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // |

            {3'b??1, 9'h058}: capslock <= ~capslock;
            {3'b0?1, 8'h1c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h41 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // A
            {3'b1?1, 8'h1c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h01; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-A
            {3'b0?1, 8'h1b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h53 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // S
            {3'b1?1, 8'h1b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h13; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Ctrl-S Pause transmission
            {3'b??1, 8'h6b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h13; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end   // Cursor left
            {3'b0?1, 8'h23}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h44 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // D
            {3'b1?1, 8'h23}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h04; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-D
            {3'b??1, 8'h74}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h04; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Cursor right
            {3'b0?1, 8'h2b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h46 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // F
            {3'b1?1, 8'h2b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h06; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-F
            {3'b0?1, 8'h34}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h47 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // G
            {3'b1?1, 8'h34}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h07; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-G (Bell)
            {3'b0?1, 8'h33}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h48 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // H
            {3'b1?1, 8'h33}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h08; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-H (Backspace)
            {3'b0?1, 8'h3b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4a | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // J
            {3'b1?1, 8'h3b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-J
            {3'b0?1, 8'h42}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4b | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // K
            {3'b1?1, 8'h42}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-K
            {3'b0?1, 8'h4b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4c | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // L
            {3'b1?1, 8'h4b}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-L
            {3'b001, 8'h4c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3b; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ;
            {3'b011, 8'h4c}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // :
            {3'b001, 8'h52}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h27; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // '
            {3'b011, 8'h52}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h22; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // "

            {3'b??1, 8'h5a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'd13; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'd1; end     // Enter
            
            {3'b???, 8'h12}: shift <= key_pressed;
            {3'b0?1, 8'h1a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h5a | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Z
            {3'b1?1, 8'h1a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h1a; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Ctrl-Z
            {3'b0?1, 8'h22}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h58 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // X
            {3'b1?1, 8'h22}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h18; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-X
            {3'b???, 8'h72}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h18; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Cursor down
            {3'b0?1, 8'h21}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h43 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // C
            {3'b1?1, 8'h21}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h03; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-C
            {3'b0?1, 8'h2a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h56 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // V
            {3'b1?1, 8'h2a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h16; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-V
            {3'b0?1, 8'h32}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h42 | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // B
            {3'b1?1, 8'h32}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h02; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-B
            {3'b0?1, 8'h31}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4e | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // N
            {3'b1?1, 8'h31}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-N
            {3'b0?1, 8'h3a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h4d | lowercasemask; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // M
            {3'b1?1, 8'h3a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h0d; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // Control-M
            {3'b001, 8'h41}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ,
            {3'b011, 8'h41}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3c; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // <
            {3'b001, 8'h49}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // .
            {3'b011, 8'h49}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3e; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // >
            {3'b001, 8'h4a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h2f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // /
            {3'b011, 8'h4a}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h3f; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // ?
            {3'b???, 8'h59}: shift <= key_pressed;
            
            {3'b0?1, 8'h29}: begin kbd_buffer[kbd_buffer_wrpos] <= 8'h20; kbd_buffer_wrpos <= kbd_buffer_wrpos + 1'b1; end     // space
        endcase
    end
end


endmodule
