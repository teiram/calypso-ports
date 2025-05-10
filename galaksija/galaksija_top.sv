module galaksija_top(
    input vidclk,
    input cpuclk,
    input audclk,
    input ramclk,
    input reset_in,
    input [10:0] ps2_key,
    output [9:0] audio_l,
    output [9:0] audio_r,
    input tape_audio,
    output [7:0] video_dat,
    output video_hsync,
    output video_vsync,
    output video_hblank,
    output video_vblank,
    input [31:0] status,
    input ioctl_download,
    input ioctl_wr,
    input [26:0] ioctl_addr,
    input [7:0] ioctl_dout,
    input [7:0] ioctl_index,
    input pll_locked,
    output [11:0] SDRAM_A,
    inout [15:0] SDRAM_DQ,
    output SDRAM_DQML,
    output SDRAM_DQMH,
    output SDRAM_nWE,
    output SDRAM_nCAS,
    output SDRAM_nRAS,
    output SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CLK,
    output SDRAM_CKE
);

reg [6:0] reset_cnt = 0;
wire cpu_resetn = reset_cnt[6];
reg [31:0] int_cnt = 0;
reg [31:0] clock_correct = 0;
reg old_vsync;

assign wait_n = (clock_correct < 3072000) & wait_n_reg;
reg wait_n_reg;

always @(posedge cpuclk) begin
    if(reset_in == 0) 
        reset_cnt <= 0;
    else if(cpu_resetn == 0) 
        reset_cnt <= reset_cnt + 1;

    old_vsync <= video_vsync;
    int_cnt <= int_cnt + 1'b1;

    clock_correct <= clock_correct > 3125000 ? 0 : clock_correct + 1'b1;

    if (old_vsync & ~video_vsync)
        int_cnt <= 0;

    int_n <= ~(int_cnt > 12500 && int_cnt < 18750);

    wait_n_reg <= (iorq_n | mreq_n) & (wait_n_reg | ~video_hsync);

end

wire m1_n;
wire iorq_n;
wire rd_n;
wire wr_n;
wire rfsh_n;
wire halt_n;
wire busak_n;
reg int_n = 1'b1;
wire nmi_n = ~status[5]; // Break
wire busrq_n = 1'b1;
wire mreq_n;
wire [15:0] addr;
wire [7:0] odata;
reg [7:0] idata;

wire wait_n;

T80s #(
    .Mode(0),
    .T2Write(0),
    .IOWait(1))
cpu(
    .RESET_n(cpu_resetn), 
    .CLK(~cpuclk),
    .WAIT_n(wait_n),
    .INT_n(int_n),
    .NMI_n(nmi_n),
    .BUSRQ_n(busrq_n),
    .M1_n(m1_n),
    .MREQ_n(mreq_n),
    .IORQ_n(iorq_n),
    .RD_n(rd_n),
    .WR_n(wr_n),
    .RFSH_n(rfsh_n),
    .HALT_n(halt_n),
    .BUSAK_n(busak_n),
    .A(addr),
    .DI(idata),
    .DO(odata)
);


wire [7:0] rom1_out;
reg rd_rom1;

sprom #(//4k
    .init_file("./GalaksijaPLUS_poseidon-ep4cgx150/roms/ROM1.hex"), 
    .widthad_a(12),
    .width_a(8))
rom1(
    .address(addr[11:0]),
    .clock(cpuclk & rd_rom1),
    .q(rom1_out)
);

wire [7:0] rom2_out;
reg rd_rom2;

sprom #(//4k
    .init_file("./GalaksijaPLUS_poseidon-ep4cgx150/roms/ROM2.hex"),
    .widthad_a(12),
    .width_a(8))
rom2(
    .address(addr[11:0]),
    .clock(cpuclk & rd_rom2),
    .q(rom2_out)
);

wire [7:0] rom3_out;
reg rd_rom3;

sprom #(//4k
    .init_file("./GalaksijaPLUS_poseidon-ep4cgx150/roms/galplus.hex"),
    .widthad_a(12),
    .width_a(8))
rom3(
    .address(addr[11:0]),
    .clock(cpuclk & rd_rom3),
    .q(rom3_out)
);

wire [7:0] rom4_out;
reg rd_rom4;


sprom #(//2k
    .init_file("./GalaksijaPLUS_poseidon-ep4cgx150/roms/ROM4.hex"),  // Path to the initialization file
    .widthad_a(11),  // 2^11 = 2048 bytes = 2 KB
    .width_a(8)      // Data width remains 8 bits
)
rom4 (
    .address(addr[10:0]),  // Address width reduced to 11 bits
    .clock(cpuclk & rd_rom4),
    .q(rom4_out)
);


reg rd_mram0, wr_mram0;
wire cs_mram0 = ~addr[15] & ~addr[14];
wire we_mram0 = wr_mram0 & cs_mram0;
wire [7:0] mram0_out;

spram #(//2k
    .widthad_a(11),
    .width_a(8))
ram00(
    .address(addr[10:0]),
    .clock(cpuclk),
    .wren(wr_mram0),
    .data(odata),
    .q(mram0_out)
);

reg rd_mram1, wr_mram1;
wire cs_mram1 = ~addr[15] &  addr[14];
wire we_mram1 = wr_mram1 & cs_mram1;
wire [7:0] mram1_out;

spram #(//2k
    .widthad_a(11),
    .width_a(8))
ram01(
    .address(addr[10:0]),
    .clock(cpuclk),
    .wren(wr_mram1),
    .data(odata),
    .q(mram1_out)
);

reg rd_mram2, wr_mram2;	
wire cs_mram2 =  addr[15] & ~addr[14];
wire we_mram2 = wr_mram2 & cs_mram2;
wire [7:0] mram2_out;

spram #(//16k
    .widthad_a(14),
    .width_a(8))
ram02(
    .address(addr[13:0]),
    .clock(cpuclk),
    .wren(we_mram2),
    .data(odata),
    .q(mram2_out)
);

reg rd_mram3, wr_mram3;	
wire cs_mram3 =  addr[15] &  addr[14];
wire we_mram3 = wr_mram3 & cs_mram3;
wire [7:0] 	mram3_out;

spram #(//16k
    .widthad_a(14),
    .width_a(8))
ram03(
    .address(addr[13:0]),
    .clock(cpuclk),
    .wren(we_mram3),
    .data(odata),
    .q(mram3_out)
);

reg rd_vram1;
reg wr_vram1;
wire [7:0] vram_out1;


reg rd_vram2;
reg wr_vram2;
wire [7:0] vram_out2;

galaksija_video#(
    .h_visible(10'd640),
    .h_front(10'd16),
    .h_sync(10'd96),
    .h_back(10'd48),
    .v_visible(10'd480),
    .v_front(10'd10),
    .v_sync(10'd2),
    .v_back(10'd33))
galaksija_video(
    .clk(vidclk),
    .cpuclk(cpuclk),
    .resetn(reset_in),
    .vga_dat(video_dat),
    .vga_hsync(video_hsync),
    .vga_vsync(video_vsync),
    .vga_hblank(video_hblank),
    .vga_vblank(video_vblank),
    .rd_ram1(rd_vram1),
    .wr_ram1(wr_vram1),
    .ram1_out(vram_out1),
    .addr(addr[10:0]),
    .data(odata),

    // Tape progress bar
    .addr_max(addr_max),
    .read_counter(read_counter[19:6]),
    .download_active(reading_tape)
);

reg [7:0] g_latch = 8'b10111100;

always @(*) begin
    rd_rom1 = 1'b0;
    rd_rom2 = 1'b0;
    rd_rom3 = 1'b0;
    rd_rom4 = 1'b0;
    rd_vram1 = 1'b0;
    rd_vram2 = 1'b0;
    rd_mram0 = 1'b0;
    rd_mram1 = 1'b0;
    rd_mram2 = 1'b0;
    rd_mram3 = 1'b0;
    wr_vram1 = 1'b0;
    wr_vram2 = 1'b0;
    wr_mram0 = 1'b0;
    wr_mram1 = 1'b0;
    wr_mram2 = 1'b0;
    wr_mram3 = 1'b0;
    rd_key = 1'b0;
    idata = 8'hff;
    casex ({~wr_n,~rd_n,mreq_n,addr[15:0]})
        //$0000...$0FFF — ROM "A" or "1" – 4 KB contains bootstrap, core control and Galaksija BASIC interpreter code
        {3'b010,16'b0000xxxxxxxxxxxx}: begin idata = rom1_out; rd_rom1 = 1'b1; end

        //$1000...$1FFF — ROM "B" or "2" – 4 KB (optional) – additional Galaksija BASIC commands, assembler, machine code monitor, etc.
        {3'b010,16'b0001xxxxxxxxxxxx}: begin idata = rom2_out; rd_rom2 = 1'b1; end

        //$2000... Tape
        {3'b010,16'b0010000000000000}: begin idata = 8'hff & tape_bit_out; end

        //$2000...$27FF — keyboard and latch			
        {3'b010,16'b00100xxxxxxxxxxx}: begin idata = 8'hff & key_out; rd_key = 1'b1; end
        {3'b100,16'b00100xxxxx111xxx}: g_latch = odata;

        //$2800...$2BFF — RAM "C": 2 KB ($2800...$2BFF – Video RAM, 2C00-2fff 1st part of ram D)
        {3'b010,16'b00101xxxxxxxxxxx}: begin idata = vram_out1; rd_vram1 = 1'b1; end
        {3'b100,16'b00101xxxxxxxxxxx}: wr_vram1 = 1'b1;

        //$3000...$37FF — RAM "D": 2 KB
        {3'b010,16'b00110xxxxxxxxxxx}: begin idata = mram0_out; rd_mram0 = 1'b1; end
        {3'b100,16'b00110xxxxxxxxxxx}: wr_mram0 = 1'b1;

        //$3800...$3FFF — RAM "E": 2 KB
        {3'b010,16'b00111xxxxxxxxxxx}: begin idata = mram1_out; rd_mram1 = 1'b1; end
        {3'b100,16'b00111xxxxxxxxxxx}: wr_mram1 = 1'b1;

        //$4000...$7FFF — RAM IC9, IC10: 16 KB
        {3'b010,16'b01xxxxxxxxxxxxxx}: begin idata = mram2_out; rd_mram2 = 1'b1; end 
        {3'b100,16'b01xxxxxxxxxxxxxx}: wr_mram2 = 1'b1;

        //$8000...$BFFF — RAM IC11, IC12: 16 KB
        {3'b010,16'b10xxxxxxxxxxxxxx}: begin idata = mram3_out; rd_mram3 = 1'b1; end 
        {3'b100,16'b10xxxxxxxxxxxxxx}: wr_mram3 = 1'b1;

        // $C600...$DFFF — High res Video RAM
        {3'b010,16'b110xxxxxxxxxxxxx}: begin idata = vram_out2; rd_vram2 = 1'b1; end
        {3'b100,16'b110xxxxxxxxxxxxx}: wr_vram2 = 1'b1;

        //$E000...$FFFF — ROM "3" + "4" IC13: 8 KB – Graphic primitives in BASIC language, Full Screen Source Editor and soft scrolling
        {3'b010,16'b1110xxxxxxxxxxxx}: begin idata = rom3_out; rd_rom3 = 1'b1; end
        
        //$F800...$FFFF   ROM D/M aka ROM4 also known as The Artist formerly known as Prince
        {3'b010,16'b1111xxxxxxxxxxxx}: begin idata = rom4_out; rd_rom4 = 1'b1; end

        default : idata = 8'hff;
    endcase
end

wire key_out;
wire rd_key;

galaksija_keyboard galaksija_keyboard(
    .clk(vidclk),
    .addr(addr[5:0]),
    .reset(~reset_in),
    .ps2_key(ps2_key),
    .key_out(key_out)
);



//////////////////////////////////////////////////////////////////////
// Tape interface
//////////////////////////////////////////////////////////////////////

wire [7:0] tape_buf_out;
reg [19:0] read_counter = 0;
reg [15:0] delay_counter = 0;
reg [13:0] addr_max = 0;

wire [21:0] sdram_addr = ioctl_download ? ioctl_addr[21:0] : read_counter[19:6];
wire sdram_we = ioctl_download & ioctl_wr;
wire [7:0] sdram_din = ioctl_dout;
reg sdram_rd;
assign SDRAM_CLK = ramclk;

sdram sdram(
    .SDRAM_DQ(SDRAM_DQ),
    .SDRAM_A(SDRAM_A),
    .SDRAM_DQML(SDRAM_DQML),
    .SDRAM_DQMH(SDRAM_DQMH),
    .SDRAM_BA(SDRAM_BA),
    .SDRAM_nCS(SDRAM_nCS),
    .SDRAM_nWE(SDRAM_nWE),
    .SDRAM_nRAS(SDRAM_nRAS),
    .SDRAM_nCAS(SDRAM_nCAS),
    .SDRAM_CKE(SDRAM_CKE),
    
    .init(~pll_locked),
    .clk(ramclk),

    .wtbt(0),
    .addr(sdram_addr),
    .rd(sdram_rd),
    .dout(tape_buf_out),
    .din(sdram_din),
    .we(sdram_we)
);

wire tape_bit_out = |read_counter[1:0] | (read_counter[2] > tape_buf_out[read_counter[5:3]]);
reg reading_tape = 0;
reg old_ioctl_download;

always @(posedge cpuclk) begin
    if (~reset_in) begin
        reading_tape <= 1'b0;
        read_counter <= 20'h0;
        addr_max <= 14'd0;
    end else begin
        old_ioctl_download <= ioctl_download;
        
        if (ioctl_download & ioctl_wr)
            addr_max <= ioctl_addr[13:0];

        if (old_ioctl_download & ~ioctl_download) begin
            reading_tape <= 1'b1;
            read_counter <= 20'h0;
        end
        else if (read_counter[19:6] > addr_max)
            reading_tape <= 1'b0;
            
        if (clock_correct < 3072000 & reading_tape) begin
            delay_counter <= delay_counter > (read_counter[5:0] == 6'b111111 ? 16'd13000 : 16'd1150) ? 16'd0 : delay_counter + 1'b1;
           
            if (delay_counter == 0) begin
                read_counter <= read_counter + 1'b1;
                sdram_rd <= 1'b1;
            end
            else sdram_rd <= 1'b0;
        end
    end
end 

wire PIN_A = (1'b1 & 1'b1 & wr_n);
wire [7:0] chan_A, chan_B, chan_C;
wire A02 = ~(C00 | PIN_A);
wire B02 = ~(C00 | addr[0]);
wire D02 = ~(addr[6] | iorq_n);
wire C00 = ~(D02 & m1_n);

assign audio_l = (reading_tape & tape_audio) ? {2'b00, tape_bit_out, 7'b0} : ({chan_A, 1'b0} + {1'b0, chan_B});
assign audio_r = (reading_tape & tape_audio) ? {2'b00, tape_bit_out, 7'b0} : ({chan_C, 1'b0} + {1'b0, chan_B});

AY8912 AY8912(
    .CLK(vidclk),
    .CE(audclk),
    .RESET(~reset_in),
    .BDIR(A02),
    .BC(B02),
    .DI(odata),
    .DO(),//not used
    .CHANNEL_A(chan_A),
    .CHANNEL_B(chan_B),
    .CHANNEL_C(chan_C),
    .SEL(1'b1),//
    .IO_in(),//not used
    .IO_out()//not used
);

endmodule
