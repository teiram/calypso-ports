module clicker (
    input clk,
    input trigger,
    output signed [15:0] audio
);

parameter CLK_HZ = 36000000;
parameter AUDIO_HZ = 22050;

localparam CNT_MAX = CLK_HZ / AUDIO_HZ;
localparam NUM_AUDIO_QUEUES = 4;

reg [11:0] audio_queue_ptrs[NUM_AUDIO_QUEUES];
reg signed[15:0] audio_queue_values[NUM_AUDIO_QUEUES];
reg [11:0] click_rom_addr;
wire [15:0] click_rom_data;
reg [1:0] next_queue = 2'd0;
reg [NUM_AUDIO_QUEUES - 1:0] enabled_audio_queues = 'd0;

click_sound_rom sound_rom(
    .clock(clk),
    .address(click_rom_addr),
    .q(click_rom_data)
);

always @(posedge clk) begin
    reg [10:0] cnt = 'd0;
    
    if (trigger == 1'b1) begin
        audio_queue_ptrs[next_queue] <= 'd0;
        enabled_audio_queues[next_queue] <= 1'b1;
        next_queue <= next_queue + 1'd1;
    end
    
    cnt <= cnt + 1'd1;
    if (cnt == CNT_MAX) begin
        cnt <= 'd0;
        audio_out <= audio_queue_values[0] + audio_queue_values[1] + audio_queue_values[2] + audio_queue_values[3];
        for (int i = 0; i < NUM_AUDIO_QUEUES; i++) begin
            if (audio_queue_ptrs[i] == 12'hfff) enabled_audio_queues[i] <= 1'b0;
            else audio_queue_ptrs[i] <= audio_queue_ptrs[i] + 1'd1;
        end
    end
end

reg signed [18:0] audio_out;
assign audio = audio_out[18:3];

always @(posedge clk) begin
    reg [1:0] queue = 'd0;
    reg [1:0] status = 2'b00;
    
    status <= status + 1'd1;
    case (status)
        2'b00: click_rom_addr <= audio_queue_ptrs[queue];
        2'b01:;
        2'b10:; 
        2'b11: begin
            audio_queue_values[queue] <= enabled_audio_queues[queue] == 1'b1 ? click_rom_data : 16'd0;
            queue <= queue + 1'd1;
        end
    endcase
end

endmodule