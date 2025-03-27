//-----------------------------------------------------------------------------
//
// FPGA Colecovision
//
// $Id: cv_console.vhd,v 1.13 2006/02/28 22:29:55 arnim Exp $
//
// Toplevel of the Colecovision console
//
// References:
//
//   * Dan Boris' schematics of the Colecovision board
//     http://www.atarihq.com/danb/files/colecovision.pdf
//
//   * Schematics of the Colecovision controller, same source
//     http://www.atarihq.com/danb/files/ColecoController.pdf
//
//   * Technical information, same source
//     http://www.atarihq.com/danb/files/CV-Tech.txt
//
//-----------------------------------------------------------------------------
//
// Copyright (c) 2006, Arnim Laeuger (arnim.laeuger@gmx.net)
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author, but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
// SystemVerilog conversion (c) 2022 Frank Bruno (fbruno@asicsolutions.com)
//
//-----------------------------------------------------------------------------

module cv_console
  #
  (
   parameter     is_pal_g     = 0,
   parameter     compat_rgb_g = 0,
   parameter     NUM_DISKS    = 1,
   parameter     NUM_TAPES    = 4,
   parameter     USE_REQ      = 1,
   parameter     TOT_DISKS    = NUM_DISKS + NUM_TAPES
   )
  (
   // Global Interface -------------------------------------------------------
   input                        clk_i,
   input                        clk_adamnet_i,
	input                        clk_100_i,
	input                        clk_25_i,
	input                        sprite_max_i,
	input                        scan_lines_i,
   input                        clk_en_10m7_i,
   input                        clk_en_5m3_i,
   input                        reset_n_i,
        input                        mode,
   output logic                 por_n_o,
   // Controller Interface ---------------------------------------------------
   input [1:0]                  ctrl_p1_i,
   input [1:0]                  ctrl_p2_i,
   input [1:0]                  ctrl_p3_i,
   input [1:0]                  ctrl_p4_i,
   output [1:0]                 ctrl_p5_o,
   input [1:0]                  ctrl_p6_i,
   input [1:0]                  ctrl_p7_i,
   output [1:0]                 ctrl_p8_o,
   input [1:0]                  ctrl_p9_i,
   input [7:0]                  joy0_i,
   input [7:0]                  joy1_i,
   // BIOS ROM Interface -----------------------------------------------------
   output [12:0]                bios_rom_a_o,
   output                       bios_rom_ce_n_o,
   input [7:0]                  bios_rom_d_i,
   output [12:0]                eos_rom_a_o,
   output                       eos_rom_ce_n_o,
   input [7:0]                  eos_rom_d_i,
   output [14:0]                writer_rom_a_o,
   output                       writer_rom_ce_n_o,
   input [7:0]                  writer_rom_d_i,
   // CPU RAM Interface ------------------------------------------------------
   output [14:0]                cpu_ram_a_o,
   output                       cpu_ram_ce_n_o,
   output                       cpu_ram_rd_n_o,
   output                       cpu_ram_we_n_o,
   input [7:0]                  cpu_ram_d_i,
   output [7:0]                 cpu_ram_d_o,
   // CPU RAM Interface ------------------------------------------------------
   output [14:0]                cpu_lowerexpansion_ram_a_o,
   output                       cpu_lowerexpansion_ram_ce_n_o,
   output                       cpu_lowerexpansion_ram_rd_n_o,
   output                       cpu_lowerexpansion_ram_we_n_o,
   input [7:0]                  cpu_lowerexpansion_ram_d_i,
   output [7:0]                 cpu_lowerexpansion_ram_d_o,
   //  cpu upper memory
   output [14:0]                cpu_upper_ram_a_o,
   output                       cpu_upper_ram_ce_n_o,
   output                       cpu_upper_ram_rd_n_o,
   output                       cpu_upper_ram_we_n_o,
   input [7:0]                  cpu_upper_ram_d_i,
   output [7:0]                 cpu_upper_ram_d_o,
   // adamnet
   output logic [15:0]          ramb_addr,
   output logic                 ramb_wr,
   output logic                 ramb_rd,
   output logic [7:0]           ramb_dout,
   input        [7:0]           ramb_din,
   input                        ramb_wr_ack,
   input                        ramb_rd_ack,

   // Cartridge ROM Interface ------------------------------------------------
   output [19:0]                cart_a_o,
   input [7:0]                  cart_d_i,
   output                       cart_rd,
   input [5:0]                  cart_pages_i,
   // extended ROM Interface ------------------------------------------------
   output [19:0]                ext_rom_a_o,
   input [7:0]                  ext_rom_d_i,

   // RGB Video Interface ----------------------------------------------------
   input                        border_i,
   output [3:0]                 col_o,
   output [7:0]                 rgb_r_o,
   output [7:0]                 rgb_g_o,
   output [7:0]                 rgb_b_o,
   output                       hsync_n_o,
   output                       vsync_n_o,
   output                       blank_n_o,
   output                       hblank_o,
   output                       vblank_o,
   output                       comp_sync_n_o,
	output                       ce_pix_o,
   // Audio Interface --------------------------------------------------------
   output [13:0]                audio_o,

   // Disk interface
   input [TOT_DISKS-1:0]        disk_present,
   output logic [31:0]          disk_sector, // sector
   output logic [TOT_DISKS-1:0] disk_load, // load the 512 byte sector
   input [TOT_DISKS-1:0]        disk_sector_loaded, // set high when sector ready
   output logic [8:0]           disk_addr, // Byte to read or write from sector
   output logic [TOT_DISKS-1:0] disk_wr, // Write data into sector (read when low)
	input logic [TOT_DISKS-1:0]  disk_flushed, // sector access done; so flush (hint)
   output logic [TOT_DISKS-1:0] disk_flush, // sector access done; so flush (hint)
   input logic [TOT_DISKS-1:0]  disk_error, // out of bounds (?)
   input logic [7:0]            disk_data[TOT_DISKS],
   output logic [7:0]           disk_din,
   // Need data for writes
   // Keyboard interface
   input logic [10:0]           ps2_key
   );
  // pragma translate_off
  // pragma translate_on

  logic [7:0]            adamnet_dout;

  // Bus Direction (0 - read , 1 - write)
  // Bus control
  logic          reset_n_s;

  logic          clk_en_3m58_p_s;
  logic          clk_en_3m58_p1_s;
  logic          clk_en_3m58_n_s;

  // CPU signals
  logic          wait_n_s /* synthesis keep */;
  logic          nmi_n_s;
  logic          int_n_s;
  logic          iorq_n_s;
  logic          m1_n_s;
  logic          m1_wait_q;
  logic          rd_n_s, rd_n_s_d;
  logic          wr_n_s, wr_n_s_d;
  logic          mreq_n_s;
  logic          rfsh_n_s /* synthesis keep */;
  logic [15:0]   a_s;
  logic [7:0]    d_to_cpu_s;
  logic [7:0]    d_from_cpu_s;
  logic          adamnet_req_n /* synthesis keep */;
  logic          adamnet_ack_n /* synthesis keep */;

  // VDP18 signal
  logic [7:0]    d_from_vdp_s;
  logic          vdp_int_n_s;
  logic [3:0]    red_s;
  logic [3:0]    grn_s;
  logic [3:0]    blu_s;

  // SN76489 signal
  logic           psg_ready_s;
  logic [13:0]    psg_a_audio_s;

  // AY-8910 signal
  logic [7:0]    ay_d_s;
  logic [13:0]   psg_b_audio_s;

  // Controller signals
  logic [7:0]    d_from_ctrl_s;
  logic [7:0]    d_to_ctrl_s;
  logic          ctrl_int_n_s;

  // Address decoder signals
  logic          bios_rom_ce_n_s;
  logic          eos_rom_ce_n_s;
  logic          writer_rom_ce_n_s;
  logic          upper_ram_ce_n_s;
  logic          expansion_ram_ce_n_s;
  logic          expansion_rom_ce_n_s;
  logic          cartridge_rom_ce_n_s;
  logic          ram_ce_n_s;
  logic          lowerexpansion_ram_ce_n_s;
  logic          vdp_r_n_s;
  logic          vdp_w_n_s;
  logic          psg_we_n_s;
  logic          ay_addr_we_n_s;
  logic          ay_data_we_n_s;
  logic          ay_data_rd_n_s;
  logic          adam_reset_pcb_n_s;
  logic          ctrl_r_n_s;
  logic          ctrl_en_key_n_s;
  logic          ctrl_en_joy_n_s;
  logic [5:0]    cart_page_s;

  // misc signals
  logic          vdd_s;

  // pragma translate_off
  // pragma translate_on

  initial begin
    //$dumpfile("test.vcd");
    //$dumpvars;
  end

  assign vdd_s   = '1;
  assign audio_o = psg_a_audio_s + psg_b_audio_s;

  assign int_n_s =  ctrl_int_n_s;
  assign nmi_n_s =  vdp_int_n_s;

  //---------------------------------------------------------------------------
  // Reset generation
  //   Generate a power-on reset for 4 clock cycles.
  //---------------------------------------------------------------------------
  logic          por_n_q;
  logic [1:0]    por_cnt_q;
  always @(posedge clk_i) begin : por_cnt
    if (&por_cnt_q) por_n_o   <= '1;
    else            por_cnt_q <= por_cnt_q + 1'b1;
  end

  assign reset_n_s = por_n_o & reset_n_i;

  //---------------------------------------------------------------------------
  // Clock generation
  //   Implements the counter which is used to generate the clock enable
  //   for the 3.58 MHz clock.
  //---------------------------------------------------------------------------
  logic [1:0] clk_cnt_q;
  always @(posedge clk_i, negedge reset_n_s) begin : clk_cnt
    if (~reset_n_s) begin
      clk_cnt_q <= '0;
    end else begin
      if (clk_en_10m7_i) begin
        if (clk_cnt_q == 0) clk_cnt_q <= 2'b10;
        else                clk_cnt_q <= clk_cnt_q - 1'b1;
      end
    end
  end : clk_cnt
  assign clk_en_3m58_p_s = (clk_cnt_q == 2'b00) ? clk_en_10m7_i : '0;
  always @(posedge clk_i) clk_en_3m58_p1_s <= clk_en_3m58_p_s;
  assign clk_en_3m58_n_s = (clk_cnt_q == 2'b10) ? clk_en_10m7_i : '0;

  //---------------------------------------------------------------------------
  // T80 CPU
  //---------------------------------------------------------------------------

  `ifdef VERILATOR

  tv80e Cpu
    (
     .reset_n     (reset_n_s),
     .clk         (clk_i),
     .cen         (clk_en_3m58_p_s),
     //.cen_n(clk_en_3m58_n_s),
     .wait_n      (wait_n_s),
     .int_n       (int_n_s),
     .nmi_n       (nmi_n_s),
     .busrq_n     (vdd_s),
     .m1_n        (m1_n_s),
     .mreq_n      (mreq_n_s),
     .iorq_n      (iorq_n_s),
     .rd_n        (rd_n_s),
     .wr_n        (wr_n_s),
     .rfsh_n      (rfsh_n_s),
     .halt_n      (),
     .busak_n     (),
     .A           (a_s),
     .di          (d_to_cpu_s),
     .dout        (d_from_cpu_s)
     );

  `else

  T80pa #(.mode(0)) t80a_b(
                           .reset_n(reset_n_s),
                           .clk(clk_i),
                           .cen_p(clk_en_3m58_p_s),
                           .cen_n(clk_en_3m58_n_s),
                           .wait_n(wait_n_s),
                           .int_n(int_n_s),
                           .nmi_n(nmi_n_s),
                           .busrq_n((USE_REQ == 1) ? adamnet_req_n : vdd_s),
                           .m1_n(m1_n_s),
                           .mreq_n(mreq_n_s),
                           .iorq_n(iorq_n_s),
                           .rd_n(rd_n_s),
                           .wr_n(wr_n_s),
                           .rfsh_n(rfsh_n_s),
                           .halt_n(),
                           .busak_n(adamnet_ack_n),
                           .a(a_s),
                           .di(d_to_cpu_s),
                           .DO(d_from_cpu_s)
                           );

`endif



  //---------------------------------------------------------------------------
  // Process m1_wait
  //
  // Purpose:
  //   Implements flip-flop U8A which asserts a wait states controlled by M1.
  //

  logic bad_reset;
  assign bad_reset = reset_n_s | ~m1_n_s;
  always @(posedge clk_i or posedge bad_reset) //reset_n_s or posedge m1_n_s)
    begin: m1_wait
      if (bad_reset) //reset_n_s == 1'b0 | m1_n_s == 1'b1)
        m1_wait_q <= 1'b0;
      else
        begin
          if (clk_en_3m58_p_s == 1'b1)
            m1_wait_q <= '1; //(~m1_wait_q);
        end
    end
  logic adamnet_wait_n;
  assign wait_n_s = psg_ready_s & (~m1_wait_q) & (USE_REQ == 0 ? adamnet_wait_n : '1);

  //
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // TMS9928A Video Display Processor
  //---------------------------------------------------------------------------

//  vdp18_core #(.is_pal_g(is_pal_g), .compat_rgb_g(compat_rgb_g)) vdp18_b(
//                                                                         .clk_i(clk_i),
//                                                                         .clk_en_10m7_i(clk_en_10m7_i),
//                                                                         .reset_n_i(reset_n_s),
//                                                                         .csr_n_i(vdp_r_n_s),
//                                                                         .csw_n_i(vdp_w_n_s),
//                                                                         .mode_i(a_s[0]),
//                                                                         .int_n_o(vdp_int_n_s),
//                                                                         .cd_i(d_from_cpu_s),
//                                                                         .cd_o(d_from_vdp_s),
//                                                                         .vram_we_o(vram_we_o),
//                                                                         .vram_a_o(vram_a_o),
//                                                                         .vram_d_o(vram_d_o),
//                                                                         .vram_d_i(vram_d_i),
//                                                                         .col_o(col_o),
//                                                                         .rgb_r_o(rgb_r_o),
//                                                                         .rgb_g_o(rgb_g_o),
//                                                                         .rgb_b_o(rgb_b_o),
//                                                                         .hsync_n_o(hsync_n_o),
//                                                                         .vsync_n_o(vsync_n_o),
//                                                                         .blank_n_o(blank_n_o),
//                                                                         .border_i(border_i),
//                                                                         .hblank_o(hblank_o),
//                                                                         .vblank_o(vblank_o),
//                                                                         .comp_sync_n_o(comp_sync_n_o)
//                                                                         );
//																								 
																								 
																								 
   // F18A VDP
   //
   // The soft button reset is sent to the F18A (unlike the real CV) to ensure
   // a game will not leave enhanced F18A settings enabled which will cause
   // problems for legacy or non-F18A games.
   //
   f18a_core vdp_18b
   ( 
	 .clk_100m0_i    (clk_100_i),  // must be 100MHz
    .clk_25m0_i     (clk_25_i),   // must be an actual 25MHz clock, NOT an enable
   // 9918A to Host interface
    .reset_n_i      (reset_n_s),    // active low, the F18A gets soft reset
    .mode_i         (a_s[0]),
    .csw_n_i        (vdp_w_n_s),
    .csr_n_i        (vdp_r_n_s),
    .int_n_o        (vdp_int_n_s),
    .cd_i           (d_from_cpu_s),
    .cd_o           (d_from_vdp_s),
   // Video Output
    .blank_o        (blank_n_o),    // active high during active video
    .hsync_o        (hsync_n_o),
    .vsync_o        (vsync_n_o),
	 .vblank_o       (vblank_o),
	 .hblank_o       (hblank_o),
	 .ce_pix         (ce_pix_o),
    .red_o          (red_s),        // 4-bit red
    .grn_o          (grn_s),        // 4-bit green
    .blu_o          (blu_s),        // 4-bit blue
   // Feature Selection
    .sprite_max_i   (sprite_max_i), // default sprite max, '0'=32, '1'=4
    .scanlines_i    (scan_lines_i), // simulated scan lines, '0'=no, '1'=yes
   // SPI for GPU access, not enabled in the Phoenix
    .spi_clk_o      (),
    .spi_cs_o       (),
    .spi_mosi_o     (),
    .spi_miso_i     (1'b0)
   );

	assign rgb_r_o = {red_s,4'b0};
	assign rgb_g_o = {grn_s,4'b0};
	assign rgb_b_o = {blu_s,4'b0};
	
  //---------------------------------------------------------------------------
  // SN76489 Programmable Sound Generator
  //---------------------------------------------------------------------------
`ifdef VERILATOR
  assign psg_ready_s=1;
`else

 sn76489_audio #(.FAST_IO_G(1'b0),.MIN_PERIOD_CNT_G(17)) psg_a(
                                          .clk_i(clk_i),
                                          .en_clk_psg_i(clk_en_3m58_n_s),
                                          .ce_n_i(psg_we_n_s),
                                          .wr_n_i(psg_we_n_s),
                                          .ready_o(psg_ready_s),
                                          .data_i(d_from_cpu_s),
                                                                                                                .mix_audio_o(psg_a_audio_s)
                                          //.pcm14s_o(psg_audio_s)
                                          );


 ym2149_audio psg_b(
                     .clk_i(clk_i),
                     .en_clk_psg_i(clk_en_3m58_p_s),
                     .reset_n_i((reset_n_s)),
                     .bdir_i((~ay_addr_we_n_s) | (~ay_data_we_n_s)),
                     .bc_i((~ay_addr_we_n_s) | (~ay_data_rd_n_s)),
                     .data_i(d_from_cpu_s),
                     .data_r_o(ay_d_s),
                     .sel_n_i(1'b0),
                                                        .mix_audio_o(psg_b_audio_s)
                     );

`endif
  //---------------------------------------------------------------------------
  // Controller ports
  //---------------------------------------------------------------------------

  cv_ctrl ctrl_b(
                 .clk_i(clk_i),
                 .clk_en_3m58_i(clk_en_3m58_p_s),
                 .reset_n_i(reset_n_s),
                 .ctrl_en_key_n_i(ctrl_en_key_n_s),
                 .ctrl_en_joy_n_i(ctrl_en_joy_n_s),
                 .a1_i(a_s[1]),
                 .ctrl_p1_i(ctrl_p1_i),
                 .ctrl_p2_i(ctrl_p2_i),
                 .ctrl_p3_i(ctrl_p3_i),
                 .ctrl_p4_i(ctrl_p4_i),
                 .ctrl_p5_o(ctrl_p5_o),
                 .ctrl_p6_i(ctrl_p6_i),
                 .ctrl_p7_i(ctrl_p7_i),
                 .ctrl_p8_o(ctrl_p8_o),
                 .ctrl_p9_i(ctrl_p9_i),
                 .d_o(d_from_ctrl_s),
                                          .int_n_o(ctrl_int_n_s)
                 );

  //---------------------------------------------------------------------------
  // Address decoder
  //---------------------------------------------------------------------------

  cv_addr_dec addr_dec_b(
                         .clk_i(clk_i),
                         .reset_n_i(reset_n_i),
                                                                 .mode(mode),
                         .a_i(a_s),
                         .d_i(d_from_cpu_s),
                         .cart_pages_i(cart_pages_i),
                         .cart_page_o(cart_page_s),
                         .iorq_n_i(iorq_n_s),
                         .rd_n_i(rd_n_s),
                         .wr_n_i(wr_n_s),
                         .mreq_n_i(mreq_n_s),
                         .rfsh_n_i(rfsh_n_s),
                         .bios_rom_ce_n_o(bios_rom_ce_n_s),
                         .eos_rom_ce_n_o(eos_rom_ce_n_s),
                         .writer_rom_ce_n_o(writer_rom_ce_n_s),
                         .ram_ce_n_o(ram_ce_n_s),
                         .lowerexpansion_ram_ce_n_o(lowerexpansion_ram_ce_n_s),
                         .upper_ram_ce_n_o(upper_ram_ce_n_s),
                         .expansion_ram_ce_n_o(expansion_ram_ce_n_s),
                         .expansion_rom_ce_n_o(expansion_rom_ce_n_s),
                         .cartridge_rom_ce_n_o(cartridge_rom_ce_n_s),
                         .vdp_r_n_o(vdp_r_n_s),
                         .vdp_w_n_o(vdp_w_n_s),
                         .psg_we_n_o(psg_we_n_s),
                         .ay_addr_we_n_o(ay_addr_we_n_s),
                         .ay_data_we_n_o(ay_data_we_n_s),
                         .ay_data_rd_n_o(ay_data_rd_n_s),
                         .adam_reset_pcb_n_o(adam_reset_pcb_n_s),
                         .ctrl_r_n_o(ctrl_r_n_s),
                         .ctrl_en_key_n_o(ctrl_en_key_n_s),
                         .ctrl_en_joy_n_o(ctrl_en_joy_n_s)
                                                                 );

  reg wr_z80;
  reg rd_z80;


   // Keyboard interface. Not sure how we should do this
  logic [7:0]  kbd_status;
  logic        kbd_status_upd;
  logic        lastkey_in_valid = 1; // FIXME!!!
  logic [7:0]  lastkey_in;
  logic        lastkey_in_ack;
  logic [7:0]  lastkey_out;

  logic        rd_z80_c, wr_z80_c;
  logic        adamnet_sel;

  cv_adamnet
    #
    (.NUM_DISKS (NUM_DISKS),
     .NUM_TAPES (NUM_TAPES),
     .USE_REQ   (USE_REQ)
     )
  adamnet
    (
    .clk_i(clk_i),
    .adam_reset_pcb_n_i(adam_reset_pcb_n_s),
     //.z80_wr(clk_en_3m58_p1_s && ~wr_n_s && wr_z80), //wr_z80),
    //.z80_rd(clk_en_3m58_p1_s && ~rd_n_s && rd_z80),
    .z80_wr(wr_z80_c),
    .z80_rd(rd_z80_c),
    .z80_rd_lvl(~rd_n_s),
    .z80_addr(a_s),
    .z80_data_wr(d_from_cpu_s),
    .z80_data_rd(d_to_cpu_s),
    .z80_rfsh(rfsh_n_s),
     // Dual port or mux into ADAM system memory
     .ramb_addr,
     .ramb_wr,
     .ramb_rd,
     .ramb_dout,
     .ramb_din,
     .ramb_wr_ack,
     .ramb_rd_ack,

     // Keyboard interface. Not sure how we should do this
     .kbd_status,
     .kbd_status_upd,
     .lastkey_in_valid,
     .lastkey_in,
     .lastkey_in_ack,
     .lastkey_out,

     // Disk interface
     .disk_present,
     .disk_sector, // sector
     .disk_load, // load the 512 byte sector
     .disk_sector_loaded, // set high when sector ready
     .disk_addr, // Byte to read or write from sector
     .disk_wr, // Write data into sector (read when low)
     .disk_flush, // sector access done, so flush (hint)
     .disk_flushed, // sector access done, so flush (hint)
     .disk_error, // out of bounds (?)
     .disk_data,
     .disk_din,

     .adamnet_req_n,
     .adamnet_ack_n,

     .adamnet_wait_n,
     .adamnet_sel,
     .adamnet_dout,

     .ps2_key
     );
  //always_comb
  //  $display("%s %h, %h", adamnet.adam_state.name(), adamnet_req_n, adamnet_ack_n);
  assign bios_rom_ce_n_o = bios_rom_ce_n_s;
  assign eos_rom_ce_n_o = eos_rom_ce_n_s;
  assign writer_rom_ce_n_o = writer_rom_ce_n_s;
  assign cpu_ram_ce_n_o = ram_ce_n_s;
  assign cpu_lowerexpansion_ram_ce_n_o = lowerexpansion_ram_ce_n_s;
  assign cpu_upper_ram_ce_n_o = upper_ram_ce_n_s;

 // assign cpu_expansion_rom_ce_n_o = expansion_rom_ce_n_s;

  assign cpu_ram_we_n_o = wr_n_s;
  assign cpu_lowerexpansion_ram_we_n_o = wr_n_s;
  assign cpu_upper_ram_we_n_o = wr_n_s;
  assign cpu_ram_rd_n_o = rd_n_s;
  assign cpu_lowerexpansion_ram_rd_n_o = rd_n_s;
  assign cpu_upper_ram_rd_n_o = rd_n_s;
  assign cart_rd = ~cartridge_rom_ce_n_s || ~expansion_rom_ce_n_s;

  //---------------------------------------------------------------------------
  // Bus multiplexer
  //---------------------------------------------------------------------------

  assign d_to_ctrl_s = d_from_ctrl_s ;


    //---------------------------------------------------------------------------
    // Process mux
    //
    // Purpose:
    //   Masks the data buses and ands them together
    //
    // was in:  cv_bus_mux bus_mux_b

  always_comb begin: mux
    logic [7:0]        d_bios_v;
    logic [7:0]        d_eos_v;
    logic [7:0]        d_writer_v;
    logic [7:0]        d_ram_v;
    logic [7:0]        d_lowerexpansion_ram_v;
    logic [7:0]        d_upper_ram_v;
    logic [7:0]        d_expansion_rom_v;
         logic [7:0]        d_cartridge_rom_v;
    logic [7:0]        d_vdp_v;
    logic [7:0]        d_ctrl_v;
         logic [7:0]        d_ay_v;

    // default assignments
    d_bios_v = '1;
    d_eos_v = '1;
    d_writer_v = '1;
    d_ram_v  = '1;
    d_upper_ram_v  = '1;
         d_expansion_rom_v = '1;
         d_cartridge_rom_v = '1;
    d_lowerexpansion_ram_v  = '1;
    d_vdp_v  = '1;
    d_ctrl_v = '1;
         d_ay_v   = '1;

    if (~bios_rom_ce_n_s)       d_bios_v = bios_rom_d_i;
    if (~eos_rom_ce_n_s)        d_eos_v = eos_rom_d_i;
    if (~writer_rom_ce_n_s)     d_writer_v = writer_rom_d_i;
    if (~ram_ce_n_s)            d_ram_v  = cpu_ram_d_i;
    if (~lowerexpansion_ram_ce_n_s)            d_lowerexpansion_ram_v  = cpu_lowerexpansion_ram_d_i;
    if (~upper_ram_ce_n_s)      d_upper_ram_v = adamnet_sel ? adamnet_dout : cpu_upper_ram_d_i;
    //if (~expansion_rom_ce_n_s)  d_expansion_rom_v = ext_rom_d_i;
	 if (~expansion_rom_ce_n_s)  d_expansion_rom_v = cart_d_i;
    if (~cartridge_rom_ce_n_s)  d_cartridge_rom_v = cart_d_i;
    if (~vdp_r_n_s)             d_vdp_v  = d_from_vdp_s;
    if (~ctrl_r_n_s)            d_ctrl_v = d_to_ctrl_s;
         if (~ay_data_rd_n_s)        d_ay_v   = ay_d_s;

    d_to_cpu_s = d_bios_v & d_eos_v & d_writer_v & d_ram_v & d_upper_ram_v
                    & d_expansion_rom_v & d_cartridge_rom_v & d_vdp_v
                                        & d_ctrl_v & d_lowerexpansion_ram_v & d_ay_v;
  end


always @(posedge clk_i)
  begin
    rd_z80 <= rd_n_s;
    wr_z80 <= wr_n_s;

if (~mreq_n_s && rfsh_n_s && iorq_n_s && (~rd_n_s | ~wr_n_s)) begin
if (clk_en_3m58_p_s)
begin
  if (rd_n_s && ~rd_z80) begin
        //$display("%t RdZ80: %x %x",$stime, a_s,d_to_cpu_s);
        //rd_z80 <= 1;

  end
  if (wr_n_s && ~wr_z80) begin
        //$display("%t WrZ80: %x %x",$stime, a_s,d_from_cpu_s);
        //wr_z80 <= 1;
  end

end
end
if (mreq_n_s && rfsh_n_s && ~iorq_n_s && (~rd_n_s | ~wr_n_s)) begin
if (clk_en_3m58_p_s)
begin
      //if (~wr_n_s) $display("OutZ80(0x%X,0x%X)",a_s[7:0],d_from_cpu_s);
      //if (~rd_n_s) $display("InZ80(0x%X) result: %x",a_s[7:0],d_to_cpu_s);
end
end


end

    always_comb begin
      rd_z80_c = 0;
      wr_z80_c = 0;
      if (~mreq_n_s && rfsh_n_s && iorq_n_s && (~rd_n_s | ~wr_n_s)) begin
        if (clk_en_3m58_p_s)
          begin
            rd_z80_c = 0;
            wr_z80_c = 0;
            if (~rd_n_s) begin
              //$display("%t RdZ80: %x %x",$stime, a_s,d_to_cpu_s);
              rd_z80_c = 1;

            end
            if (~wr_n_s) begin
              //$display("%t WrZ80: %x %x",$stime, a_s,d_from_cpu_s);
              wr_z80_c = 1;
            end
          end
      end // if (~mreq_n_s && rfsh_n_s && iorq_n_s && (~rd_n_s | ~wr_n_s))
    end // always_comb

  //---------------------------------------------------------------------------
  // Misc outputs
  //---------------------------------------------------------------------------
  assign writer_rom_a_o    = a_s[14:0];
  assign eos_rom_a_o       = a_s[13:0];
  assign bios_rom_a_o      = a_s[12:0];
  assign cpu_ram_a_o       = a_s[14:0];
  assign cpu_lowerexpansion_ram_a_o = a_s[14:0];
  assign cpu_upper_ram_a_o = a_s[14:0];
  assign cpu_ram_d_o       = d_from_cpu_s;
  assign cpu_lowerexpansion_ram_d_o       = d_from_cpu_s;
  assign cpu_upper_ram_d_o = d_from_cpu_s;
  assign cart_a_o ={cart_page_s, a_s[13:0]};

endmodule
