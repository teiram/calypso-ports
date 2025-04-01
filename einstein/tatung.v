
module tatung(
  input clk_sys, // 32
  input clk_cpu, // 4
  input clk_vdp, // 10,7
  input clk_fdc, // cen 4
  input reset,

  output [7:0] vga_red,
  output [7:0] vga_green,
  output [7:0] vga_blue,
  output vga_hsync,
  output vga_vsync,
  output vga_hblank,
  output vga_vblank,

  output [9:0] sound,

  output [7:0] kb_row,
  input [7:0] kb_col,
  input kb_shift,
  input kb_ctrl,
  input kb_graph,
  input kb_down,

  input [1:0] img_mounted,
  input [1:0] img_readonly,
  input [31:0] img_size,

  output [31:0] sd_lba,
  output [1:0] sd_rd,
  output [1:0] sd_wr,
  input sd_ack,
  input [8:0] sd_buff_addr,
  input [7:0] sd_dout,
  output [7:0] sd_din,
  input sd_dout_strobe,

  input [15:0] joystick_0,
  input [15:0] joystick_1,
  input [15:0] joystick_analog_0,
  input [15:0] joystick_analog_1,

  input diagnostic,
  input border,
  input analog,
  
  output [15:0] sdram_addr,
  output [7:0] sdram_din,
  input [7:0] sdram_dout,
  output ram_rd,
  output ram_wr,
  output roma_rd,
  output romb_rd
);

wire [15:0] cpu_addr;
wire [7:0] cpu_dout;
wire iorq_n;
wire m1_n;
wire mreq_n;
wire rd_n;
wire wr_n;

wire io_en = ~iorq_n & m1_n;
wire rom_en = ~io_en && cpu_addr < 16'h8000 && ~I025a && ~rd_n;
wire ram_en = ~io_en;

// CPU data bus
assign sdram_addr = cpu_addr;
assign sdram_din = cpu_dout;
assign ram_rd = ~(rd_n | mreq_n);
assign ram_wr = ~(wr_n | mreq_n);
assign roma_rd = rom_a;
assign romb_rd = rom_b;

wire [7:0] cpu_din =
  ~PSG_n & ~rd_n ? I030_dout :
  ~VDP_n & ~rd_n ? vdp_dout :
  ~I054c ? int_vect :
  ~KB_MSK_n & ~rd_n ? { kb_shift, kb_ctrl, kb_graph, 3'b100, ~joystick_1[4], ~joystick_0[4] } : // todo: add I036 (printer/fire)
  ~FDC_n & ~rd_n ? fdc_dout :
  ~ADC_n & ~rd_n ? adc_dout :
  ctc_doe ? ctc_dout :
  rom_a | rom_b | ram_rd ? sdram_dout : 8'hff;

// interrupts
// see bottom left section of schematic: I055, I056 & I057
reg int_n;
reg I054c;
wire T148gs;
wire INA_n = m1_n | iorq_n;
wire [3:0] T75q;
wire [2:0] T148q;
wire [7:0] int_vect;
reg old_T148gs, old_ctc_int_n;

always @(posedge clk_sys) begin
  old_T148gs <= T148gs;
  old_ctc_int_n <= ctc_int_n;
  I054c <= INA_n | T148gs;
  if (reset | ~INA_n)
    int_n <= 1'b1;
  else if ((~T148gs & old_T148gs)|(old_ctc_int_n & ~ctc_int_n))
    int_n <= 1'b0;
end

T7475 T7475(
  .d({ 1'b1, adc_int_n, fire_int_n, kb_int_n }),
  .en(I054c),
  .q(T75q)
);

// priority encoder
T74148 T74148(
  .I({ 4'b1111, T75q[0], T75q[1], T75q[2], T75q[3] }),
  .EN(1'b0),
  .GS(T148gs),
  .Q(T148q)
);

T74244 T74244(
  .A({ 1'b0, T148q[0], T148q[1], T148q[2], 4'b0 }),
  .OE({ I054c, I054c }),
  .Y({
    int_vect[0], int_vect[1], int_vect[2], int_vect[3],
    int_vect[4], int_vect[5], int_vect[6], int_vect[7]
  })
);

// keyboard interrupt & mask

wire kb_int_n = I031a | I031b;

reg I031a, oldkb;
always @(posedge clk_sys) begin
  oldkb <= kb_down;
  if (reset | (~KB_MSK_n & ~rd_n)) I031a <= 1'b1;
  else if (oldkb ^ kb_down) I031a <= ~kb_down;
end

reg I031b; // kb int mask
always @(posedge clk_sys) begin
  if (reset) I031b <= 1'b1;
//else if (~wr_n & ~KB_MSK_n) I031b <= cpu_dout[0];
  else if (~wr_n & ~KB_MSK_n) I031b <= cpu_dout[0];
end

// fire interrupt & mask

reg fire_int_n = 1;
reg fire_int_mask = 1;
always @(posedge clk_sys) begin
  fire_int_n <= ~(joystick_0[4]|joystick_1[4]) | fire_int_mask | ~ctc_ieo;
  if (reset) begin
    fire_int_mask <= 1'b1;
    fire_int_n <= 1'b1;
  end
  else if (~wr_n & ~FIREINT_MSK_n) begin
    fire_int_mask <= cpu_dout[0];
  end
end

// adc interrupt & mask

reg adc_int_n = 1;
reg adc_int_mask = 1;
always @(posedge clk_sys) begin
  adc_int_n <= (adc_intr_n | adc_int_mask) | ~ctc_ieo;
  if (reset) begin
    adc_int_mask <= 1'b1;
    adc_int_n <= 1'b1;
  end
  else if (~wr_n & ~ADC_MSK_n) begin
    adc_int_mask <= cpu_dout[0];
  end
end


// 2M clock & enable

reg [3:0] clk_cnt;
wire clk_2 = clk_cnt[3];
wire cen_2 = clk_cnt == 4'b1111;
always @(posedge clk_sys) clk_cnt <= clk_cnt + 4'd1;

// CPU

t80s t80s(
  .RESET_n(~reset),
  .CLK(clk_cpu),
  .CEN(1'b1),
  .WAIT_n(1'b1),
  .INT_n(int_n),
  .NMI_n(1'b1),
  .BUSRQ_n(1'b1),
  .M1_n(m1_n),
  .MREQ_n(mreq_n),
  .IORQ_n(iorq_n),
  .RD_n(rd_n),
  .WR_n(wr_n),
  .RFSH_n(),
  .HALT_n(),
  .BUSAK_n(),
  .A(cpu_addr),
  .DI(cpu_din),
  .DO(cpu_dout)
);


// I/O enables

wire ADC_n, PIO, CTC_n, I026_Y4, FDC_n, PCI, VDP_n, PSG_n;
wire JR, MB, FIREINT_MSK_n, ROM_n, DRSEL_n, APH, ADC_MSK_n, KB_MSK_n;

x74138 I026(
  .G1(~(iorq_n|~m1_n)),
  .G2A(cpu_addr[6]),
  .G2B(cpu_addr[7]),
  .A(cpu_addr[5:3]),
  .Y({ ADC_n, PIO, CTC_n, I026_Y4, FDC_n, PCI, VDP_n, PSG_n })
);

x74138 I027(
  .G1(1'b1),
  .G2A(I026_Y4),
  .G2B(1'b0),
  .A(cpu_addr[2:0]),
  .Y({ JR, MB, FIREINT_MSK_n, ROM_n, DRSEL_n, APH, ADC_MSK_n, KB_MSK_n })
);

// ROM status toggler

reg I025a;
always @(posedge ROM_n, posedge reset)
  if (reset)
    I025a <= 1'b0;
  else
    I025a <= ~I025a;


// Memories

   
wire [7:0] rom_a_dout, rom_b_dout;

wire rom_a = rom_en && ~I025a && ~cpu_addr[14];
wire rom_b = rom_en && ~I025a && cpu_addr[14] && diagnostic;

/*
rom #(.ROMFILE("roms/rom.mem"), .SIZE(16383)) I023(
  .clk(clk_sys),
  .cs(~rom_a),
  .addr(cpu_addr[13:0]),
  .q(rom_a_dout)
);

rom #(.ROMFILE("roms/diagnostic.mem"), .SIZE(1625)) I024(
  .clk(clk_sys),
  .cs(~rom_b),
  .addr(cpu_addr[13:0]),
  .q(rom_b_dout)
);

wire [7:0] ram_dout;

ram #(.ADDRWIDTH(16), .DATAWIDTH(8)) ram(
  .clk(clk_sys),
  .addr(cpu_addr),
  .din(cpu_dout),
  .q(ram_dout),
  .wr_n(wr_n),
  .ce_n(~ram_en)
);
*/

wire vram_we;
wire [13:0] vram_addr;
wire [7:0] vram_din, vram_dout;

// 16k for TC01, 32x6 for 256
ram #(.ADDRWIDTH(14), .DATAWIDTH(8)) vram(
  .clk(clk_sys),
  .addr(vram_addr),
  .din(vram_din),
  .q(vram_dout),
  .wr_n(~vram_we),
  .ce_n(1'b0)
);


// VDP

wire [7:0] vdp_dout;

vdp18_core vdp18(
  .clk_i(clk_vdp),
  .clk_en_10m7_i(1'b1),
  .reset_n_i(~reset),

  .csr_n_i(VDP_n|rd_n),
  .csw_n_i(VDP_n|wr_n),
  .mode_i(cpu_addr[0]),
  .int_n_o(),
  .cd_i(cpu_dout),
  .cd_o(vdp_dout),

  .vram_we_o(vram_we),
  .vram_a_o(vram_addr),
  .vram_d_o(vram_din),
  .vram_d_i(vram_dout),

  .border_i(border),
  .col_o(),
  .rgb_r_o(vga_red),
  .rgb_g_o(vga_green),
  .rgb_b_o(vga_blue),
  .hsync_n_o(vga_hsync),
  .vsync_n_o(vga_vsync),
  .blank_n_o(),
  .hblank_o(vga_hblank),
  .vblank_o(vga_vblank),
  .comp_sync_n_o()
);


// AUDIO

wire [7:0] I030_dout;

wire soft_reset = ~(~(PSG_n|cpu_addr[1]) | reset);

jt49_bus I030(
  .rst_n(soft_reset),
  .clk(clk_sys),
  .clk_en(cen_2),
  .bdir(~(PSG_n|wr_n)),
  .bc1(~(PSG_n|cpu_addr[0])),
  .din(cpu_dout),
  .sel(1'b1),
  .dout(I030_dout),
  .sound(sound),
  .A(),
  .B(),
  .C(),
  .sample(),
  .IOA_in(8'hff),
  .IOA_out(kb_row),
  .IOB_in(kb_col),
  .IOB_out()
);

// CTC - Timer

wire [3:0] zc_to;
wire ctc_int_n;
wire ctc_doe;
wire [7:0] ctc_dout;
wire clk_ctc = clk_cpu;
wire ctc_ieo;

wire zreti;
wire zspm1;

z80reti z80reti(
  .I_RESET(reset),
  .I_CLK(clk_ctc),
  .I_CLKEN(1'b1),
  .I_M1_n(m1_n),
  .I_MREQ_n(mreq_n),
  .I_IORQ_n(iorq_n),
  .O_RETI(zreti),
  .O_SPM1(zspm1)
);

z80ctc ctc(
  .I_RESET(reset),
  .I_CLK(clk_ctc),
  .I_CLKEN(1'b1),
  .I_A(cpu_addr[1:0]),
  .I_D(cpu_dout),
  .O_D(ctc_dout),
  .O_DOE(ctc_doe),
  .I_M1_n(m1_n),
  .I_CS_n(CTC_n),
  .I_WR_n(wr_n),
  .I_RD_n(rd_n),
  .I_SPM1(zspm1),
  .I_RETI(zreti),
  .O_INT_n(ctc_int_n),
  .I_IEI(kb_int_n),
  .O_IEO(ctc_ieo),
  .I_TI({ zc_to[2], {3{clk_2}} }),
  .O_TO(zc_to)
);


// FDC - disk controller

reg [3:0] I043_q; // drive-select
reg floppy_side;
wire [7:0] fdc_dout;

always @(posedge clk_sys)
  if (~DRSEL_n && ~wr_n) { floppy_side, I043_q } <= ~cpu_dout[4:0];

reg fdd_ready = 0;
always @(posedge clk_sys)
  if (img_mounted) fdd_ready <= 1'b1;

wd1793 #(.RWMODE(1), .EDSK(1)) fdc(
  .clk_sys(clk_sys),
  .ce(clk_fdc),
  .reset(~soft_reset),
  .io_en(~FDC_n),
  .rd(~rd_n),
  .wr(~wr_n),
  .addr(cpu_addr[1:0]),
  .din(cpu_dout),
  .dout(fdc_dout),
  .drq(),
  .intrq(),
  .busy(),
  .wp(img_readonly),
  .size_code(3'b100),
  .layout(0),
  .side(~floppy_side),
  .ready(fdd_ready | diagnostic),
  .img_mounted(img_mounted),
  .img_size(img_size),
  .prepare(),
  .sd_lba(sd_lba),
  .sd_rd(sd_rd),
  .sd_wr(sd_wr),
  .sd_ack(sd_ack),
  .sd_buff_addr(sd_buff_addr),
  .sd_buff_dout(sd_dout),
  .sd_buff_din(sd_din),
  .sd_buff_wr(sd_dout_strobe)
);


// ADC

wire [7:0] adc_dout;
wire adc_intr_n;

wire [3:0] dj1 = { joystick_0[2], joystick_0[3], joystick_0[1], joystick_0[0] };
wire [3:0] dj2 = { joystick_1[2], joystick_1[3], joystick_1[1], joystick_1[0] };

ADC0844 adc(
  .clk(clk_sys),
  .ma(cpu_dout[3:0]),
  .db(adc_dout),
  .rd_n(rd_n),
  .wr_n(wr_n),
  .cs_n(ADC_n),
  .intr_n(adc_intr_n),
  .ch1(joystick_analog_0[7:0]+127),
  .ch2(255-(joystick_analog_0[15:8]+127)),
  .ch3(joystick_analog_1[7:0]+127),
  .ch4(255-(joystick_analog_1[15:8]+127)),
  .analog(analog),
  .dj1(dj1),
  .dj2(dj2)
);

endmodule
