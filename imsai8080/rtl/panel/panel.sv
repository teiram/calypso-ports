module panel(
    input clk,
    input f1,
    input f2,
    input reset,
    input ready_in,
    
    input [10:0] col,
    input [9:0] row,
    input hblank,
    input vblank,
    output reg [16:2] ram_addr, // 32 bit address
    input [31:0] ram_value,     // 8 pixels (4 bits per pixel)
    
    input [7:0] disk_leds,

    input [15:0] bus_addr,
    input [7:0] bus_data_in,
    input [7:0] bus_cpu_data_in,
    output [7:0] bus_data_out,
    input [7:0] bus_cpu_sysctl,
    input bus_cpu_sync,
    input bus_cpu_wait,
    input bus_cpu_inte,
    input bus_cpu_hlda,
    input bus_cpu_rd,
    input bus_cpu_wr_n,
    
    output reg bus_xrdy = 1'b0,
    output panel_ce,
    output panel_we,
    
    input key_pressed,
    input [7:0] key_code,
    input key_strobe,
    input key_extended,
    
    output reg [3:0] r,
    output reg [3:0] g,
    output reg [3:0] b,
    
    output [15:0] audio
);

// GIMP Palette, divide by 16
// 00,00,00  
// 01,02,11
// 13,17,00
// 43,02,03
// 4A,B9,E0
// 68,00,01
// B6,00,00
// 2C,2E,2C
// 4F,51,4F
// 79,7C,79
// 86,88,85
// 95,97,94
// A2,A4,A1
// AF,B2,AE
// BE,C1,BD
// FF,FF,FF

// Indexed palette
reg [3:0] red[16]   = '{4'h0, 4'h0, 4'h1, 4'h4, 4'h3, 4'h6, 4'hb, 4'h2, 4'h4, 4'h7, 4'h8, 4'h9, 4'ha, 4'ha, 4'hb, 4'hf};
reg [3:0] green[16] = '{4'h0, 4'h0, 4'h1, 4'h0, 4'ha, 4'h0, 4'h0, 4'h2, 4'h5, 4'h7, 4'h8, 4'h9, 4'ha, 4'hb, 4'hc, 4'hf};
reg [3:0] blue[16]  = '{4'h0, 4'h1, 4'h0, 4'h0, 4'ha, 4'h0, 4'h0, 4'h2, 4'h4, 4'h7, 4'h8, 4'h9, 4'ha, 4'ha, 4'hb, 4'hf};

reg [10:0] led_cols[20] = '{
    11'd37, 11'd68, 11'd99, 11'd130, 11'd161, 11'd191, 11'd222, 11'd253,
    11'd313, 11'd344, 11'd375, 11'd405, 11'd436, 11'd467, 11'd497, 11'd528, 
    11'd654, 11'd683, 11'd711, 11'd739};
reg [10:0] led_rows[3] = '{11'd35, 11'd86, 11'd137};

reg [4:0] led_index_cols[44] = '{
    5'd19, 5'd18, 5'd17, 5'd16,
    5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0,
    5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0,
    5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0};

reg [1:0] led_index_rows[44] = '{
    2'd2, 2'd2, 2'd2, 2'd2,
    2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 2'd2, 
    2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1, 2'd1,
    2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0, 2'd0};

reg [10:0] switch_cols[16] = '{
    11'd521, 11'd490, 11'd459, 11'd429, 11'd399, 11'd369, 11'd338, 11'd307,
    11'd246, 11'd215, 11'd184, 11'd154, 11'd125, 11'd94, 11'd63, 11'd32};

reg [10:0] m_switch_cols[5] = '{
    11'd583, 11'd615, 11'd644, 11'd673, 11'd703};

reg [10:0] disk_led_cols[4] = '{11'd445, 11'd472, 11'd624, 11'd719};
reg [10:0] disk_led_rows[2] = '{11'd248, 11'd264};
reg [1:0] disk_led_index_cols[8] = '{2'd0, 2'd0, 2'd1, 2'd1, 2'd2, 2'd2, 2'd3, 2'd3};
reg disk_led_index_rows[8] = '{1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1, 1'd0, 1'd1};
 
localparam LED_WIDTH = 32;
localparam LED_HEIGHT = 16;
localparam LED_COUNT = 44;

localparam DISK_LED_WIDTH = 26;
localparam DISK_LED_HEIGHT = 10;
localparam DISK_LED_COUNT = 8;

localparam SWITCH_ROW_ON = 198;
localparam SWITCH_ROW_OFF = 220;
localparam M_SWITCH_ROW_IDLE = 210;
localparam SWITCH_NOTCH_HEIGHT = 4;
localparam SWITCH_WIDTH = 23;
localparam SWITCH_COUNT = 16;

localparam M_SWITCH_COUNT = 5;

parameter [9:0] PANEL_WIDTH = 10'd800;
parameter [8:0] PANEL_HEIGHT = 9'd280;

// Holds 8 pixels, 4 bpp, taken in each memory read
reg [31:0] pixel_value = 32'd0;

// Pixel packing adjustments
wire [3:0] pixel_values[8] = '{
    pixel_value[7:4],
    pixel_value[3:0],
    pixel_value[15:12],
    pixel_value[11:8],
    pixel_value[23:20],
    pixel_value[19:16],
    pixel_value[31:28],
    pixel_value[27:24]
};

integer led_index;
integer switch_index;
integer m_switch_index;
integer disk_led_index;

reg [15:0] switches;
// EXAMINE, EXAMINE NEXT, DEPOSIT, DEPOSIT NEXT, RESET, EXT CLR, RUN, STOP, SINGLE STEP, SINGLE STEP
reg [9:0] m_switches;

wire [1:0] m_switches_p[M_SWITCH_COUNT] = '{
    {m_switches[0], m_switches[1]},
    {m_switches[2], m_switches[3]},
    {m_switches[4], m_switches[5]},
    {m_switches[6], m_switches[7]},
    {m_switches[8], m_switches[9]}
};
reg [7:0] programmed_output_leds;

wire [43:0] leds = {
    programmed_output_leds,
    bus_cpu_sysctl,
    bus_cpu_data_in,
    bus_addr,
    bus_cpu_inte,
    run,
    bus_cpu_wait,
    bus_cpu_hlda
};

// To avoid flickering and painting LEDs on several states at once
reg [43:0] leds_latched;
reg [7:0] disk_leds_latched;

always @(posedge clk) begin
    if (reset) begin
        ram_addr <= 15'd0;
    end
    else begin
        if (row == PANEL_HEIGHT && col == PANEL_WIDTH - 8) begin
            ram_addr <= 15'd0;
            leds_latched <= leds;
            disk_leds_latched <= disk_leds;
        end
        if (row == PANEL_HEIGHT && col == PANEL_WIDTH) begin
            pixel_value <= ram_value;
        end
        
        if (~vblank & ~hblank & row < PANEL_HEIGHT) begin
            if (col[2:0] == 3'd0) begin
                ram_addr <= ram_addr + 15'd1;
            end else if (col[2:0] == 3'd7) begin
                pixel_value <= ram_value;
            end
            r <= red[pixel_values[col[2:0]]];
            g <= green[pixel_values[col[2:0]]];
            b <= blue[pixel_values[col[2:0]]];
            
            // Replace LED color in enabled LEDs
            for (led_index = 0; led_index < LED_COUNT; led_index = led_index + 1) begin
                if (col > led_cols[led_index_cols[led_index]] && 
                    col < led_cols[led_index_cols[led_index]] + LED_WIDTH &&
                    row > led_rows[led_index_rows[led_index]] &&
                    row < led_rows[led_index_rows[led_index]] + LED_HEIGHT &&
                    leds_latched[led_index] == 1'b1 &&
                    pixel_values[col[2:0]] == 4'd3) begin
                    r <= 4'hf;
                    g <= 4'h0;
                    b <= 4'h0;
                end
            end
            
            // Disk LEDs
            for (disk_led_index = 0; disk_led_index < DISK_LED_COUNT; disk_led_index = disk_led_index + 1) begin
                if (col > disk_led_cols[disk_led_index_cols[disk_led_index]] && 
                    col < disk_led_cols[disk_led_index_cols[disk_led_index]] + DISK_LED_WIDTH &&
                    row > disk_led_rows[disk_led_index_rows[disk_led_index]] &&
                    row < disk_led_rows[disk_led_index_rows[disk_led_index]] + DISK_LED_HEIGHT &&
                    disk_leds_latched[disk_led_index] == 1'b1 &&
                    pixel_values[col[2:0]] == 4'd3) begin
                    r <= 4'hf;
                    g <= 4'h0;
                    b <= 4'h0;
                end
            end

            //Draw the bar in switches on and off
            for (switch_index = 0; switch_index < SWITCH_COUNT; switch_index = switch_index + 1) begin
                if (col > switch_cols[switch_index] + 4'd8 && 
                    col < switch_cols[switch_index] + SWITCH_WIDTH + 4'd8 &&
                    row > SWITCH_ROW_ON &&
                    row < SWITCH_ROW_ON + SWITCH_NOTCH_HEIGHT &&
                    pixel_values[col[2:0]] != 4'd0 &&
                    switches[switch_index] == 1'b1) begin
                    r <= 4'hb;
                    g <= 4'hb;
                    b <= 4'hb;
                end
                else if (col > switch_cols[switch_index] + 4'd8 && 
                    col < switch_cols[switch_index] + SWITCH_WIDTH + 4'd8 &&
                    row > SWITCH_ROW_OFF &&
                    row < SWITCH_ROW_OFF + SWITCH_NOTCH_HEIGHT &&
                    pixel_values[col[2:0]] != 4'd0 &&
                    switches[switch_index] == 1'b0) begin
                    r <= 4'hb;
                    g <= 4'hb;
                    b <= 4'hb;
                end
            end
            
            //Draw the bar on momentary switches
            for (m_switch_index = 0; m_switch_index < M_SWITCH_COUNT; m_switch_index = m_switch_index + 1) begin
               if (col > m_switch_cols[m_switch_index] + 4'd8 && 
                    col < m_switch_cols[m_switch_index] + SWITCH_WIDTH + 4'd8 &&
                    row > SWITCH_ROW_ON &&
                    row < SWITCH_ROW_ON + SWITCH_NOTCH_HEIGHT &&
                    pixel_values[col[2:0]] != 4'd0 &&
                    m_switches_p[m_switch_index][0] == 1'b1) begin
                    r <= 4'hb;
                    g <= 4'hb;
                    b <= 4'hb;
                end
                else if (col > m_switch_cols[m_switch_index] + 4'd8 && 
                    col < m_switch_cols[m_switch_index] + SWITCH_WIDTH + 4'd8 &&
                    row > SWITCH_ROW_OFF &&
                    row < SWITCH_ROW_OFF + SWITCH_NOTCH_HEIGHT &&
                    pixel_values[col[2:0]] != 4'd0 &&
                    m_switches_p[m_switch_index][1] == 1'b1) begin
                    r <= 4'hb;
                    g <= 4'hb;
                    b <= 4'hb;
                end
                else if (col > m_switch_cols[m_switch_index] + 4'd8 && 
                    col < m_switch_cols[m_switch_index] + SWITCH_WIDTH + 4'd8 &&
                    row > M_SWITCH_ROW_IDLE &&
                    row < M_SWITCH_ROW_IDLE + SWITCH_NOTCH_HEIGHT &&
                    pixel_values[col[2:0]] != 4'd0 &&
                    m_switches_p[m_switch_index] == 2'b00) begin
                    r <= 4'hb;
                    g <= 4'hb;
                    b <= 4'hb;
                end
            end
        end
        else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end
end

always @(posedge clk) begin
    if (reset == 1'b1) begin
        switches <= 'd0;
        m_switches <= 'd0;
    end
    else if (key_strobe == 1'b1) begin
        case (key_code)
            8'h1a: m_switches[0] <= key_pressed; //Z
            8'h1c: m_switches[1] <= key_pressed; //A
            
            8'h22: m_switches[2] <= key_pressed; //X
            8'h1b: m_switches[3] <= key_pressed; //S
            
            8'h21: m_switches[4] <= key_pressed; //C
            8'h23: m_switches[5] <= key_pressed; //D
            
            8'h2a: m_switches[6] <= key_pressed; //V
            8'h2b: m_switches[7] <= key_pressed; //F
            
            8'h32: m_switches[8] <= key_pressed; //B
            8'h34: m_switches[9] <= key_pressed; //G
        endcase
        if (key_pressed == 1'b0) begin
            case (key_code)
                8'h16: switches[15] <= ~switches[15]; //1
                8'h1e: switches[14] <= ~switches[14]; //2
                8'h26: switches[13] <= ~switches[13]; //3
                8'h25: switches[12] <= ~switches[12]; //4
                8'h2e: switches[11] <= ~switches[11]; //5
                8'h36: switches[10] <= ~switches[10]; //6
                8'h3d: switches[9] <= ~switches[9]; //7
                8'h3e: switches[8] <= ~switches[8]; //8
                
                8'h15: switches[7] <= ~switches[7]; //Q
                8'h1d: switches[6] <= ~switches[6]; //W
                8'h24: switches[5] <= ~switches[5]; //E
                8'h2d: switches[4] <= ~switches[4]; //R
                8'h2c: switches[3] <= ~switches[3]; //T
                8'h35: switches[2] <= ~switches[2]; //Y
                8'h3c: switches[1] <= ~switches[1]; //U
                8'h43: switches[0] <= ~switches[0]; //I
            endcase
        end
    end
end

reg trigger = 1'b0;

clicker #(
    .CLK_HZ(36000000),
    .AUDIO_HZ(22050)
) clicker(
    .clk(clk),
    .trigger(trigger),
    .audio(audio)
);

always @(posedge clk) begin
    reg [26:0] switches_last;
    switches_last <= {switches, m_switches};
    trigger <= switches_last != {switches, m_switches};
end


wire [7:0] data_addr_switches = switches[7:0];
wire [7:0] addr_sense_switches = switches[15:8];
    
wire step_switch = m_switches[8] | m_switches[9];
wire step_switch_down;

wire examine_switch = m_switches[1];
wire examine_switch_down;
wire examine_ce;
wire [7:0] examine_out;

wire examine_next_switch = m_switches[0];
wire examine_next_switch_down;
wire examine_next_ce;
wire [7:0] examine_next_out;

    
wire deposit_switch = m_switches[3];
wire deposit_switch_down;
wire [7:0] deposit_out;
wire deposit_we;

wire deposit_next_switch = m_switches[2];
wire deposit_next_switch_down;
wire deposit_next_ce;
wire deposit_next_we;
wire [7:0] deposit_next_out;

wire reset_switch = m_switches[5];
wire reset_switch_down;
wire reset_ce;
wire [7:0] reset_out;

wire [7:0] sense_sw_out;
wire rd_sense;

wire run_switch = m_switches[7];
wire stop_switch = m_switches[6];

wire io_wr = bus_cpu_sysctl[4];
wire m1 = bus_cpu_sysctl[5];
wire io_rd = bus_cpu_sysctl[6];

reg run = 1'b0;

always @(posedge clk) begin
    reg last_f2 = 1'b0;
    last_f2 <= f2;
        
    if (f2 & ~last_f2) begin
        if (m1 & stop_switch) run <= 1'b0;
        else if (run_switch) run <= 1'b1;
    end
end

always @(posedge clk) begin
    reg sync_last = 1'b0;
    sync_last <= bus_cpu_sync;
    
    if (run) bus_xrdy <= ready_in;
    else begin
        if (bus_xrdy) begin
            if (~sync_last & bus_cpu_sync) bus_xrdy <= 1'b0;
        end
        else begin
            if (deposit_next_ce |
                examine_ce |
                examine_next_ce |
                reset_ce |
                step_switch_down) bus_xrdy <= 1'b1;
        end
    end
end

debouncer step_debouncer(
    .clk(clk),
    .i_btn(step_switch & ~run),
    .o_state(),
    .o_ondn(step_switch_down),
    .o_onup()
);

debouncer deposit_debouncer(
    .clk(clk),
    .i_btn(deposit_switch & ~run),
    .o_state(),
    .o_ondn(deposit_switch_down),
    .o_onup()
);

deposit deposit_fsm(
    .clk(clk),
    .reset(reset),
    .deposit(deposit_switch_down),
    .data_sw(data_addr_switches),
    .data_out(deposit_out),
    .we(deposit_we)
);

debouncer deposit_next_debouncer(
    .clk(clk),
    .i_btn(deposit_next_switch & ~run),
    .o_state(),
    .o_ondn(deposit_next_switch_down),
    .o_onup()
);

deposit_next deposit_next_fsm(
    .clk(clk),
    .reset(reset),
    .sync(bus_cpu_sync),
    .deposit(deposit_next_switch_down),
    .data_sw(data_addr_switches),
    .ce(deposit_next_ce),
    .we(deposit_next_we),
    .data_out(deposit_next_out)
);


debouncer examine_debouncer(
    .clk(clk),
    .i_btn(examine_switch & ~run),
    .o_state(),
    .o_ondn(examine_switch_down),
    .o_onup()
);

examine examine_fsm(
    .clk(clk),
    .reset(reset),
    .sync(bus_cpu_sync),
    .examine(examine_switch_down),
    .data_out(examine_out),
    .lo_addr(data_addr_switches),
    .hi_addr(addr_sense_switches),
    .ce(examine_ce)
);

debouncer examine_next_debouncer(
    .clk(clk),
    .i_btn(examine_next_switch & ~run),
    .o_state(),
    .o_ondn(examine_next_switch_down),
    .o_onup()
);

examine_next examine_next_fsm(
    .clk(clk),
    .reset(reset),
    .sync(bus_cpu_sync),
    .examine(examine_next_switch_down),
    .data_out(examine_next_out),
    .ce(examine_next_ce)
);

debouncer reset_debouncer(
    .clk(clk),
    .i_btn(reset_switch & ~run),
    .o_state(),
    .o_ondn(reset_switch_down),
    .o_onup()
);

reset reset_fsm(
    .clk(clk),
    .reset(reset),
    .sync(bus_cpu_sync),
    .reset_in(reset_switch_down),
    .data_out(reset_out),
    .ce(reset_ce)
);

sense_switch sense_sw(
    .clk(clk),
    .rd(rd_sense),
    .data_out(sense_sw_out),
    .switch_settings(addr_sense_switches)
);

// The panel takes over the data bus 
assign panel_ce = examine_ce | examine_next_ce | deposit_next_ce | reset_ce | rd_sense;
// The panel asserts the bus write signal and takes over the data bus
assign panel_we = deposit_we | deposit_next_we;

always @(*) begin
    rd_sense = 1'b0;
    casex ({io_rd,
            examine_ce, examine_next_ce, deposit_next_ce, reset_ce,
            deposit_we, deposit_next_we,
            bus_addr[7:0]})
        // Deposit (Write memory stage)
        {15'bx_0000_10_xxxxxxxx}: bus_data_out = deposit_out;
        // Deposit next (write memory stage)
        {15'bx_0000_01_xxxxxxxx}: bus_data_out = deposit_next_out;
        // Deposit Next
        {15'bx_0010_00_xxxxxxxx}: bus_data_out = deposit_next_out;
        // Examine
        {15'bx_1000_00_xxxxxxxx}: bus_data_out = examine_out;
        // Examine Next
        {15'bx_0100_00_xxxxxxxx}: bus_data_out = examine_next_out;
        // Reset
        {15'bx_0001_00_xxxxxxxx}: bus_data_out = reset_out;
        // Sense switches in
        {15'b1_0000_00_11111111}: begin
            bus_data_out = sense_sw_out;
            rd_sense = bus_cpu_rd;
        end
        default: bus_data_out = 8'h00;
    endcase
end


always @(posedge clk) begin
    casex ({io_wr, examine_ce, examine_next_ce, bus_addr[7:0]})
        {3'b100,8'b11111111}: if (~bus_cpu_wr_n) programmed_output_leds <= bus_data_in;
        default: begin end // Add this default case
    endcase
end

endmodule
