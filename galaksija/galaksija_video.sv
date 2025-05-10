module galaksija_video(
    input clk,
    input cpuclk,
    input resetn,
    output reg [7:0] vga_dat,
    output reg vga_hsync,
    output reg vga_vsync,
    output reg vga_hblank,
    output reg vga_vblank,
    input rd_ram1,
    input wr_ram1,
    input [10:0] addr,
    output [7:0] ram1_out,
    input [7:0] data,
    input [13:0] addr_max,
    input [13:0] read_counter,
    input download_active,
    output reg wait_n  
);

reg [9:0] h_pos;
reg [9:0] v_pos;
reg [23:0] rgb_data;

parameter h_visible = 10'd320;
parameter h_front = 10'd20;
parameter h_sync = 10'd30;
parameter h_back = 10'd38;
parameter h_total = h_visible + h_front + h_sync + h_back;

parameter v_visible = 10'd240;
parameter v_front = 10'd4;
parameter v_sync = 10'd3;
parameter v_back = 10'd15;
parameter v_total = v_visible + v_front + v_sync + v_back;

wire h_active, v_active, visible;

reg [3:0] text_v_pos;
reg [4:0] font_line;
reg old_vsync;

wire [9:0] screen_x = h_pos > 9'd31 ? h_pos - 9'd31 : 10'd0;
reg  [9:0] prev_x, prev_prev_x;

always @(posedge clk) begin
    if (resetn == 0) begin
        h_pos <= 0;
        v_pos <= 0;
        text_v_pos <= 0;
        font_line  <= 0;
    end else begin
        //Pixel counters
        if (h_pos == h_total - 1) begin
            h_pos <= 0;
            if (v_pos == v_total - 1) begin
                v_pos <= 0;
                text_v_pos <= 0;
                font_line <= 0;
            end else begin
                v_pos <= v_pos + 1;
                if (font_line != 24)
                    font_line <= font_line + 1;
                else begin
                    font_line <= 0;
                    text_v_pos <= text_v_pos + 1;
                end
            end
        end else begin
            h_pos <= h_pos + 1;
      
            // Default display (main content)
            rgb_data <= (h_pos > 5 && h_pos < 32*8*2+4 && v_pos < 200*2) ? 
                         data_out_rotated[h_pos[3:1]] ? 24'h000000 : 24'hffffff : 
                         24'h000000;
      
            // Progress bar - thin version (2 pixels tall)
            if (download_active) begin
                // Show progress bar in last 10 lines of screen (adjust as needed)
                if (v_pos >= (v_visible - 20) && v_pos < (v_visible - 8)) begin
                    // Progress calculation - adjust multiplier for proper width
                    if (h_pos < ((addr_max[13:4] - read_counter[13:4]) * h_visible / 256)) 
                        rgb_data <= 24'hffffff;  // White progress bar
                end
            end
        end
    
        vga_hblank <= ~h_active;
        vga_vblank <= ~v_active;
        vga_hsync <= !((h_pos >= (h_visible + h_front)) && (h_pos < (h_visible + h_front + h_sync)));
        vga_vsync <= !((v_pos >= (v_visible + v_front)) && (v_pos < (v_visible + v_front + v_sync)));
        vga_dat <= rgb_data[7:0];
    end
end

assign h_active = (h_pos < h_visible);
assign v_active = (v_pos < v_visible);
assign visible = h_active && v_active;

wire [7:0] data_out;
wire [7:0] data_out_rotated; // Shift for proper font appearance
assign data_out_rotated = {data_out[6:0], data_out[7]};


wire [10:0] video_addr;

wire [6:0] char;

wire [7:0] code;

assign char = ((code > 63 && code < 96) || (code > 127 && code < 192)) ? code - 64 :
              (code > 191) ? code - 128 : code;

sprom #(
    .init_file("./GalaksijaPLUS_poseidon-ep4cgx150/roms/CHRGEN.hex"),
    .widthad_a(11),
    .width_a(8))
font_rom(
    .address({font_line[4:1], char}),
    .clock(clk),
    .q(data_out)
);

assign video_addr = {text_v_pos,5'b00000} + h_pos[9:4];

reg [7:0] video_ram[0:2047];

always @(posedge clk) begin
    if (wr_ram1)
        video_ram[addr[10:0]] <= data;
    if (rd_ram1)
        ram1_out <= video_ram[addr[10:0]];
    code <= video_ram[video_addr[10:0]];
end


endmodule
