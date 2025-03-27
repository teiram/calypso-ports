//-----------------------------------------------------------------------------
//
// FPGA Colecovision AdamNet
//
// Adamnet implementation for Disk, Tape and Printer
//
// Based upon:
// ColEm: portable Coleco emulator
//
//                       AdamNet.c
//
// This file contains implementation for the AdamNet I/O
// interface found in Coleco Adam home computer.
//
// Copyright (C) Marat Fayzullin 1994-2021
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
// Copyright (c) 2022, Frank Bruno (fbruno@asicsolutions.com)
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
//-----------------------------------------------------------------------------

module cv_adamnet
  #
  (
   parameter NUM_DISKS = 1,
   parameter NUM_TAPES = 1,
   parameter USE_REQ = 1,
   parameter TOT_DISKS = NUM_DISKS + NUM_TAPES
   )
  (
   input                        clk_i,
   input                        adam_reset_pcb_n_i /*verilator public_flat*/,
   input                        z80_wr/*verilator public_flat*/,
   input                        z80_rd/*verilator public_flat*/,
   input                        z80_rd_lvl,
   input [15:0]                 z80_addr/*verilator public_flat*/,
   input [7:0]                  z80_data_wr/*verilator public_flat*/,
   input [7:0]                  z80_data_rd/*verilator public_flat*/,
   input                        z80_rfsh,
   // Dual port or mux into ADAM system memory
   output logic [15:0]          ramb_addr,
   output logic                 ramb_wr,
   output logic                 ramb_rd,
   output logic [7:0]           ramb_dout,
   input  [7:0]                 ramb_din,
   input                        ramb_wr_ack,
   input                        ramb_rd_ack,

   // Keyboard interface. Not sure how we should do this
   output logic [7:0]           kbd_status,
   output logic                 kbd_status_upd,
   output logic                 lastkey_in_valid,
   input logic [7:0]            lastkey_in,
   output logic                 lastkey_in_ack,
   output logic [7:0]           lastkey_out,
   input logic [10:0]           ps2_key,

   // Disk interface
   input logic [TOT_DISKS-1:0]  disk_present,
   output logic [31:0]          disk_sector, // sector
   output logic [TOT_DISKS-1:0] disk_load, // load the 512 byte sector
   input logic [TOT_DISKS-1:0]  disk_sector_loaded, // set high when sector ready
   output logic [8:0]           disk_addr, // Byte to read or write from sector
   output logic [TOT_DISKS-1:0] disk_wr, // Write data into sector (read when low)
   output logic [TOT_DISKS-1:0] disk_flush, // sector access done, so flush (hint)
   input logic [TOT_DISKS-1:0]  disk_flushed, // sector access done, so flush (hint)
   input logic [TOT_DISKS-1:0]  disk_error, // out of bounds (?)
   input logic [7:0]            disk_data[TOT_DISKS],
   output logic [7:0]           disk_din,

   output logic                 adamnet_req_n,
   input logic                  adamnet_ack_n,
   output logic                 adamnet_wait_n,
   output logic                 adamnet_sel,
   output logic [7:0]           adamnet_dout
   );

  //assign adamnet_dout = ramb_dout;

  localparam PCB_BASE_INIT = 16'hFEC0; // PCB base address on reset

  /** PCB Field Offsets ****************************************/
  localparam PCB_CMD_STAT   = 0;
  localparam PCB_BA_LO      = 1;
  localparam PCB_BA_HI      = 2;
  localparam PCB_MAX_DCB    = 3;
  localparam PCB_SIZE       = 4;

  typedef struct {
    logic [7:0]  pcb_cmd_stat;
    logic [7:0]  pcb_ba_lo;
    logic [7:0]  pcb_ba_hi;
    logic [7:0]  pcb_max_dcb;
  } pcb_table_t;

  pcb_table_t pcb_table;

  /** DCB Field Offsets ****************************************/
  localparam DCB_CMD_STAT   = 0;
  localparam DCB_BA_LO      = 1;
  localparam DCB_BA_HI      = 2;
  localparam DCB_BUF_LEN_LO = 3;
  localparam DCB_BUF_LEN_HI = 4;
  localparam DCB_SEC_NUM_0  = 5;
  localparam DCB_SEC_NUM_1  = 6;
  localparam DCB_SEC_NUM_2  = 7;
  localparam DCB_SEC_NUM_3  = 8;
  localparam DCB_DEV_NUM    = 9;
  localparam DCB_RETRY_LO   = 14;
  localparam DCB_RETRY_HI   = 15;
  localparam DCB_ADD_CODE   = 16;
  localparam DCB_MAXL_LO    = 17;
  localparam DCB_MAXL_HI    = 18;
  localparam DCB_DEV_TYPE   = 19;
  localparam DCB_NODE_TYPE  = 20;
  localparam DCB_SIZE       = 21;

  typedef struct {
    logic [7:0]  dcb_cmd_stat;
    logic [7:0]  dcb_ba_lo;
    logic [7:0]  dcb_ba_hi;
    logic [7:0]  dcb_buf_len_lo;
    logic [7:0]  dcb_buf_len_hi;
    logic [7:0]  dcb_sec_num_0;
    logic [7:0]  dcb_sec_num_1;
    logic [7:0]  dcb_sec_num_2;
    logic [7:0]  dcb_sec_num_3;
    logic [7:0]  dcb_dev_num;
    logic [7:0]  dcb_retry_lo;
    logic [7:0]  dcb_retry_hi;
    logic [7:0]  dcb_add_code;
    logic [7:0]  dcb_maxl_lo;
    logic [7:0]  dcb_maxl_hi;
    logic [7:0]  dcb_dev_type;
    logic [7:0]  dcb_node_type;
  } dcb_table_t;

  dcb_table_t dcb_table[15];

  /** PCB Commands *********************************************/
  localparam CMD_PCB_IDLE   = 8'h00;
  localparam CMD_PCB_SYNC1  = 8'h01;
  localparam CMD_PCB_SYNC2  = 8'h02;
  localparam CMD_PCB_SNA    = 8'h03;
  localparam CMD_PCB_RESET  = 8'h04;
  localparam CMD_PCB_WAIT   = 8'h05;

  /** DCB Commands *********************************************/
  localparam CMD_RESET      = 8'h00;
  localparam CMD_STATUS     = 8'h01;
  localparam CMD_ACK        = 8'h02;
  localparam CMD_CLEAR      = 8'h03;
  localparam CMD_RECEIVE    = 8'h04;
  localparam CMD_CANCEL     = 8'h05;
  localparam CMD_SEND       = 8'h06; /* + SIZE_HI + SIZE_LO + DATA + CRC */
  localparam CMD_NACK       = 8'h07;

  localparam CMD_SOFT_RESET = 8'h02;
  localparam CMD_WRITE      = 8'h03;
  localparam CMD_READ       = 8'h04;

  /** Response Codes *******************************************/
  localparam RSP_STATUS     = 8'h80; /* + SIZE_HI + SIZE_LO + TXCODE + STATUS + CRC */
  localparam RSP_ACK        = 8'h90;
  localparam RSP_CANCEL     = 8'hA0;
  localparam RSP_SEND       = 8'hB0; /* + SIZE_HI + SIZE_LO + DATA + CRC */
  localparam RSP_NACK       = 8'hC0;
  localparam RSP_BUSY       = 8'h9B;

  localparam CB_RANGE = PCB_SIZE + (15*DCB_SIZE);

  logic [15:0]  pcb_base; /* Base of the PCB/ DCB in memory
                           * The size of the memory segment is
                           * pcb_base + PCB_SIZE + (15*DCB_SIZE) - 1
                           */
  logic [15:0]  pcb_addr;
  logic [15:0]  dcb_base; // precompute the dcb_base
  logic [15:0]  dcb_counter, data_counter /* synthesis keep */;
  logic [3:0]   max_dcb;
  logic [2:0]   diskid;
  logic [1:0]   tapeid;
  logic [15:0]  dcb_base_cmd[15];
  logic [14:0]  dcb_cmd_hit;
  logic [3:0]   dcb_cmd_dev;
  logic         dcb_dev_hit_any;
  logic [14:0]  dcb_dev_hit;
  logic [3:0]   dcb_dev;
  // Disk access
  logic [15:0]  buffer /*synthesis keep */;
  logic [15:0]  len /* synthesis keep */;
  logic [31:0]  sec;
  logic         disk_req;   // Request a disk acccess
  logic         disk_rd;    // Read or ~write
  logic         disk_done;  // Disk transfer complete
  logic [3:0]   disk_dev;   // Device that is done
  logic         tape_req;
  logic [3:0]   done_dev;   // Device that is done
  logic [31:0]  disk_lastblock[4]; // Last block accessed by the disk
  logic         set_lastblock;
  logic [31:0]  tape_lastblock[4]; // Last block accessed by the disk
  logic         set_lastblock_tape;

  //
  logic         kbd_req;
  logic         kbd_done;
  logic [3:0]   kbd_dev;

  assign max_dcb = pcb_table.pcb_max_dcb;
  typedef enum bit
               {
                MOVE_PCB,
                IDLE
                } adam_state_t;

  adam_state_t adam_state, return_state, next_state;

  function logic [2:0] InterleaveTable(input logic [2:0] sector);
    case (sector)
      0: InterleaveTable = 0;
      1: InterleaveTable = 5;
      2: InterleaveTable = 2;
      3: InterleaveTable = 7;
      4: InterleaveTable = 4;
      5: InterleaveTable = 1;
      6: InterleaveTable = 6;
      7: InterleaveTable = 3;
    endcase // case (sector)
  endfunction

  bit [14:0] is_dsk[2];
  bit [14:0] is_kbd;
  bit [14:0] is_prn;
  bit [14:0] is_tap;

  always_ff @(posedge clk_i) begin
    dcb_cmd_hit     <= '0;
    dcb_cmd_dev     <= '0;
    dcb_dev         <= '0;
    dcb_dev_hit     <= '0;
    dcb_dev_hit_any <= '0;
    is_dsk          <= '{default: '0};
    is_kbd          <= '0;
    is_prn          <= '0;
    is_tap          <= '0;
    diskid          <= '0;
    tapeid          <= '0;

    for (int i = 0; i < 15; i++) begin
      if ((z80_addr >= dcb_base_cmd[i]) &&
          (z80_addr < (dcb_base_cmd[i] + DCB_SIZE))  &&
          (i < max_dcb)) begin
        dcb_dev_hit_any <= '1;
        dcb_dev_hit[i]  <= '1;
        dcb_dev         <= i;
      end
      if ((z80_addr == dcb_base_cmd[i]) && (i < max_dcb)) begin
        dcb_cmd_hit[i] <= '1;
        dcb_cmd_dev    <= i;
        diskid         <= {dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} - 4;
        //tapeid         <= {dcb_table[i].dcb_dev_num[0], dcb_table[i].dcb_add_code[0]};
        tapeid         <= {dcb_table[i].dcb_add_code[0], dcb_table[i].dcb_dev_num[0]};
      end
      //if (i < max_dcb) begin
        is_dsk[0][i] <= ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h4) |
                       ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h5) |
                       ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h6) |
                       ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h7) & (i < max_dcb);
        is_dsk[1][i] <= ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h52) & (i < max_dcb);
        is_kbd[i] <= ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h1) & (i < max_dcb);
        is_prn[i] <= ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h2) & (i < max_dcb);
        is_tap[i] <= ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h8) |
                    ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h9) |
                    ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h18) |
                    ({dcb_table[i].dcb_dev_num[3:0], dcb_table[i].dcb_add_code[3:0]} == 8'h19) & (i < max_dcb);
      //end // if (i < pcb_table.pcb_max_dcb)
    end
  end

  logic [15:0] dcb_reg;

  assign pcb_base = {pcb_table.pcb_ba_hi, pcb_table.pcb_ba_lo};
  assign dcb_reg = z80_addr - dcb_base_cmd[dcb_dev];
  logic [7:0]  temp_reg;
  assign temp_reg = {dcb_table[0].dcb_dev_num[3:0], dcb_table[0].dcb_add_code[3:0]};
  always_ff @(posedge clk_i) begin
    // defaults
    adamnet_wait_n <= '0;
    kbd_status_upd <= '0;
    disk_req       <= '0;
    tape_req       <= '0;
    kbd_req        <= '0;

    for (int i = 0; i < 15; i++) begin
      dcb_base_cmd[i]    <= (pcb_base + PCB_SIZE) + i * DCB_SIZE;
    end

    case (adam_state)
      /** MovePCB() ************************************************/
      /** Move PCB and related DCBs to a new address.             **/
      /*************************************************************/
      // static void MovePCB(word NewAddr,byte MaxDCB)
      MOVE_PCB: begin
        $display("Adamnet (HDL): MovePCB Address: %x", pcb_addr);
        pcb_table.pcb_cmd_stat <= CMD_PCB_IDLE;
        pcb_table.pcb_ba_lo    <= pcb_addr[7:0];
        pcb_table.pcb_ba_hi    <= pcb_addr[15:8];
        pcb_table.pcb_max_dcb  <= 15;

        for (int i = 0; i < 15; i++) begin
          dcb_table[i].dcb_cmd_stat <= '0;
          dcb_table[i].dcb_dev_num  <= '0;
          dcb_table[i].dcb_add_code <= i;
        end
        for (int i = 0; i < 4; i++) begin
          disk_lastblock[i] <= '1;
          tape_lastblock[i] <= '1;
        end
        adam_state   <= IDLE;
      end // case: MOVE_PCB

      IDLE: begin
        //$display("IDLE");
        adamnet_wait_n       <= '1;
        if ((USE_REQ == 1) ? adamnet_ack_n : adamnet_wait_n) begin
          // Snoop PCB/ DCB Writes
          if ((z80_addr - pcb_base) < PCB_SIZE) begin
            case (z80_addr - pcb_base)
              PCB_CMD_STAT: begin
                if (z80_wr) begin
                  case (z80_data_wr)
                    CMD_PCB_SYNC1: begin
                      $display("Adamnet (HDL): SyncZ80: %x, %x",PCB_CMD_STAT,RSP_STATUS|CMD_PCB_SYNC1);
                      pcb_table.pcb_cmd_stat <= z80_data_wr | RSP_STATUS;
                    end
                    CMD_PCB_SYNC2: begin
                      $display("Adamnet (HDL): Sync6801: %x, %x",PCB_CMD_STAT,RSP_STATUS|CMD_PCB_SYNC2);
                      pcb_table.pcb_cmd_stat <= z80_data_wr | RSP_STATUS;
                    end
                    CMD_PCB_SNA: begin
                      // Todo: add in movepcb
                      $display("Adamnet (HDL): Rellocate PCB: %x, %x",PCB_CMD_STAT,RSP_STATUS|CMD_PCB_SNA);
                      pcb_table.pcb_cmd_stat <= z80_data_wr | RSP_STATUS;
                      $finish;
                    end
                    default: begin
                      $display("Adamnet (HDL): Unimplemented PCB Operation");
                      pcb_table.pcb_cmd_stat <= z80_data_wr;
                    end
                  endcase
                end
              end
              PCB_BA_LO: begin
                //if (z80_wr) pcb_table.pcb_ba_lo <= z80_data_wr;
                if (z80_wr) pcb_addr[7:0] <= z80_data_wr;
              end
              PCB_BA_HI: begin
                //if (z80_wr) pcb_table.pcb_ba_hi <= z80_data_wr;
                if (z80_wr) pcb_addr[15:8] <= z80_data_wr;
              end
              PCB_MAX_DCB: begin
                if (z80_wr) pcb_table.pcb_max_dcb <= z80_data_wr;
              end
              default: begin
              end
            endcase // case (z80_addr - pcb_base)
          end
          if (dcb_dev_hit_any) begin
            case (dcb_reg)// (pcb_base + PCB_SIZE + DCB_SIZE * dcb_dev))
              DCB_CMD_STAT: begin
                if (|z80_data_wr[6:0] && ~z80_data_wr[7]) begin
                  if (is_kbd[dcb_dev]) begin
                    if (z80_rd_lvl) begin
                      kbd_status <= RSP_STATUS;
                      kbd_status_upd <= '1;
                      lastkey_out    <= '0;
                    end else if (z80_wr) begin
                      case (z80_data_wr)
                        CMD_STATUS, CMD_SOFT_RESET: begin
                          kbd_status     <= RSP_STATUS;
                          kbd_status_upd <= '1;
                          lastkey_out    <= '0;
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                          dcb_table[dcb_dev].dcb_maxl_lo  <= 8'h01;
                          dcb_table[dcb_dev].dcb_maxl_hi  <= 8'h00;
                          dcb_table[dcb_dev].dcb_dev_type <= '0;
                        end
                        CMD_WRITE: begin
                          kbd_status     <= RSP_STATUS;
                          kbd_status_upd <= '1;
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_BUSY; // RSP_ACK + 8'h0B;
                        end
                        CMD_READ: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= '0;
                          //A = GetDCBBase(Dev);
                          //N = GetDCBLen(Dev);
                          buffer <= {dcb_table[dcb_dev].dcb_ba_hi, dcb_table[dcb_dev].dcb_ba_lo};
                          len    <= {dcb_table[dcb_dev].dcb_buf_len_hi, dcb_table[dcb_dev].dcb_buf_len_lo};
                          kbd_req <= '1;
                          // FIXME!!!!!
                          //for(J=0 ; (J<N) && (V=GetKBD()) ; ++J, A=(A+1)&0xFFFF)
                          //  RAM(A) = V;
                          //KBDStatus = RSP_STATUS+(J<N? 0x0C:0x00);
                        end // case: CMD_READ
                        default: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                      endcase
                    end // if (z80_wr)
                  end else if (is_prn[dcb_dev]) begin
                    if (z80_wr) begin
                      case (z80_data_wr)
                        CMD_STATUS, CMD_SOFT_RESET: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                          dcb_table[dcb_dev].dcb_maxl_lo  <= 8'h01;
                          dcb_table[dcb_dev].dcb_maxl_hi  <= 8'h00;
                          dcb_table[dcb_dev].dcb_dev_type <= '0;
                        end
                        CMD_READ: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_BUSY; // RSP_ACK + 8'h0B;
                        end
                        CMD_WRITE: begin
                          //dcb_table[dcb_dev].dcb_cmd_stat <= '0;
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                          //for(J=0 ; (J<N) && (V=GetKBD()) ; ++J, A=(A+1)&0xFFFF)
                          //  RAM(A) = V;
                        end
                        default: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                      endcase
                    end else if (z80_rd_lvl) begin // if (z80_wr)
                      dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                    end
                  end else if (is_dsk[0][dcb_dev]) begin
                    $display("Adamnet (HDL): UpdateDSK N %x Dev %x V %x",diskid,dcb_dev,z80_data_wr);
                    if (z80_rd_lvl && dcb_cmd_hit[dcb_dev]) begin
                      //dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                    end else if (z80_wr) begin
                      dcb_table[dcb_dev].dcb_node_type[3:0] <= disk_present[diskid] ? '0 : 4'h3;
                      case (z80_data_wr)
                        CMD_RESET: begin
                          disk_lastblock[diskid]          <= '1;
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                        CMD_STATUS: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                          dcb_table[dcb_dev].dcb_maxl_lo  <= 8'h00;
                          dcb_table[dcb_dev].dcb_maxl_hi  <= 8'h04;
                          dcb_table[dcb_dev].dcb_dev_type <= 8'h01;
                        end
                        CMD_SOFT_RESET: begin
                          $display("Adamnet (HDL): Disk %s: Soft reset",diskid+65);
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                        CMD_WRITE, CMD_READ: begin
                          buffer <= {dcb_table[dcb_dev].dcb_ba_hi, dcb_table[dcb_dev].dcb_ba_lo};
                          len    <= {dcb_table[dcb_dev].dcb_buf_len_hi, dcb_table[dcb_dev].dcb_buf_len_lo} < 16'h400 ?
                                    16'h400 : {dcb_table[dcb_dev].dcb_buf_len_hi, dcb_table[dcb_dev].dcb_buf_len_lo};
                          sec <= {dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                  dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0};
                          if (disk_present[diskid] &&
                              (({dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                  dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0} == disk_lastblock[diskid]) ||
                               (z80_data_wr == CMD_WRITE))) begin
                            dcb_table[dcb_dev].dcb_cmd_stat <= '0;
                            $display("Adamnet (HDL): Disk %s: %s %d bytes, sector 0x%X, memory 0x%04X",
                                     dcb_dev+65,z80_data_wr==CMD_READ? "Reading":"Writing",len,sec<<1,buffer);
                            disk_req                        <= '1;
                            disk_rd                         <= z80_data_wr == CMD_READ;
                            dcb_table[dcb_dev].dcb_cmd_stat <= '0;
                            disk_lastblock[diskid]          <= '1;
                          end else begin // if (disk_present[diskid] &&...
                            dcb_table[dcb_dev].dcb_cmd_stat <= RSP_BUSY;
                            disk_lastblock[diskid]          <= {dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                                                dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0};
                          end
                        end
                        default: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                      endcase
                    end
                  end else if (is_dsk[1][dcb_dev]) begin
                    $display("Adamnet (HDL): UpdateDSK N %x Dev %x V %x",4,dcb_dev,z80_data_wr);
                    if (z80_rd_lvl && dcb_cmd_hit[dcb_dev]) begin
                      dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                    end
                  end else if (is_tap[dcb_dev]) begin
                    $display("Adamnet (HDL): UpdateTAP N %x Dev %x V %x",tapeid,dcb_dev,z80_rd_lvl ? -1 : z80_data_wr);
                    if (z80_rd_lvl && dcb_cmd_hit[dcb_dev]) begin
                      //dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                    end else if (z80_wr) begin
                      if (tapeid < 2) begin
                        $display("SetDCB A ff56 Value %4h%4h, tape_present %h",
                                 (disk_present[NUM_DISKS+1] ? 4'h0 : 4'h3),
                                 (disk_present[NUM_DISKS+0] ? 4'h0 : 4'h3), disk_present);
                        dcb_table[dcb_dev].dcb_node_type[3:0] <= disk_present[NUM_DISKS+0] ? 4'h0 : 4'h3;
                        dcb_table[dcb_dev].dcb_node_type[7:4] <= disk_present[NUM_DISKS+1] ? 4'h0 : 4'h3;
                      end else begin
                        $display("SetDCB A ff56 Value %4h%4h, tape_present %h",
                                 (disk_present[NUM_DISKS+2] ? 4'h0 : 4'h3),
                                 (disk_present[NUM_DISKS+3] ? 4'h0 : 4'h3), disk_present);
                        //dcb_table[dcb_dev].dcb_node_type[3:0] <= disk_present[NUM_DISKS+2] ? 4'h0 : 4'h3;
                        //dcb_table[dcb_dev].dcb_node_type[7:4] <= disk_present[NUM_DISKS+3] ? 4'h0 : 4'h3;
                      end
                      case (z80_data_wr)
                        CMD_RESET: begin
                          tape_lastblock[tapeid]          <= '1;
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                        CMD_STATUS: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                          dcb_table[dcb_dev].dcb_maxl_lo  <= 8'h00;
                          dcb_table[dcb_dev].dcb_maxl_hi  <= 8'h04;
                          dcb_table[dcb_dev].dcb_dev_type <= 8'h01;
                        end
                        CMD_SOFT_RESET: begin
                          $display("Adamnet (HDL): Tape %s: Soft reset",tapeid+65);
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                        CMD_WRITE, CMD_READ: begin
                          buffer <= {dcb_table[dcb_dev].dcb_ba_hi, dcb_table[dcb_dev].dcb_ba_lo};
                          len    <= {dcb_table[dcb_dev].dcb_buf_len_hi, dcb_table[dcb_dev].dcb_buf_len_lo} < 16'h400 ?
                                    16'h400 : {dcb_table[dcb_dev].dcb_buf_len_hi, dcb_table[dcb_dev].dcb_buf_len_lo};
                          sec <= {dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                  dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0};
                          if (disk_present[NUM_DISKS+tapeid] &&
                              (({dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                  dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0} == tape_lastblock[tapeid]) ||
                               (z80_data_wr == CMD_WRITE))) begin
                            dcb_table[dcb_dev].dcb_cmd_stat <= '0;
                            $display("Adamnet (HDL): Tape %s: %s %d bytes, sector 0x%X, memory 0x%04X",
                                     dcb_dev+65,z80_data_wr==CMD_READ? "Reading":"Writing",len,sec<<1,buffer);
                            tape_req                        <= '1;
                            disk_rd                         <= z80_data_wr == CMD_READ;
                            tape_lastblock[tapeid]          <= '1;
                          end else begin // if (disk_present[diskid] &&...
                            dcb_table[dcb_dev].dcb_cmd_stat <= RSP_BUSY;
                            tape_lastblock[tapeid]          <= {dcb_table[dcb_dev].dcb_sec_num_3, dcb_table[dcb_dev].dcb_sec_num_2,
                                                                dcb_table[dcb_dev].dcb_sec_num_1, dcb_table[dcb_dev].dcb_sec_num_0};
                          end
                        end // case: CMD_WRITE, CMD_READ
                        default: begin
                          dcb_table[dcb_dev].dcb_cmd_stat <= RSP_STATUS;
                        end
                      endcase
                    end // if (z80_wr)
                  end else if (dcb_cmd_hit[dcb_dev]) begin // if (is_tap[dcb_dev])
                    dcb_table[dcb_dev].dcb_cmd_stat <= RSP_BUSY; // RSP_ACK + 8'h0B;
                    $display("Adamnet (HDL): %s Unknown device #%d",
                             z80_data_wr==CMD_READ? "Reading":"Writing", dcb_dev);
                  end
                end // if (|z80_data_wr[6:0] && ~z80_data_wr[7])
              end // case: DCB_CMD_STAT
              DCB_BA_LO: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_ba_lo <= z80_data_wr;
              end
              DCB_BA_HI: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_ba_hi <= z80_data_wr;
              end
              DCB_BUF_LEN_LO: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_buf_len_lo <= z80_data_wr;
              end
              DCB_BUF_LEN_HI: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_buf_len_hi <= z80_data_wr;
              end
              DCB_SEC_NUM_0: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_sec_num_0 <= z80_data_wr;
              end
              DCB_SEC_NUM_1: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_sec_num_1 <= z80_data_wr;
              end
              DCB_SEC_NUM_2: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_sec_num_2 <= z80_data_wr;
              end
              DCB_SEC_NUM_3: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_sec_num_3 <= z80_data_wr;
              end
              DCB_DEV_NUM: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_dev_num <= z80_data_wr;
              end
              DCB_RETRY_LO: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_retry_lo <= z80_data_wr;
              end
              DCB_RETRY_HI: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_retry_hi <= z80_data_wr;
              end
              DCB_ADD_CODE: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_add_code <= z80_data_wr;
              end
              DCB_MAXL_LO: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_maxl_lo <= z80_data_wr;
              end
              DCB_MAXL_HI: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_maxl_hi <= z80_data_wr;
              end
              DCB_DEV_TYPE: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_dev_type <= z80_data_wr;
              end
              DCB_NODE_TYPE: begin
                if (z80_wr) dcb_table[dcb_dev].dcb_node_type <= z80_data_wr;
              end
              default: begin
              end
            endcase // case (z80_addr - DCB_SIZE * dcb_dev)
          end // if (dcb_dev_hit_any)
        end // if ((USE_REQ == 1) ? adamnet_ack_n : adamnet_wait_n)
      end // case: IDLE
    endcase // case (adam_state)

    // We don't handle the error
    if (disk_done) dcb_table[done_dev].dcb_cmd_stat <= RSP_STATUS;
    if (kbd_done)  dcb_table[kbd_dev].dcb_cmd_stat <= RSP_STATUS;
    if (set_lastblock) begin
      disk_lastblock[done_dev] <= sec;
    end

    if (~adam_reset_pcb_n_i) begin
      // On reset setup PCB table
      pcb_addr       <= PCB_BASE_INIT;
      adam_state     <= MOVE_PCB;
      adamnet_wait_n <= '1;
      kbd_status     <= RSP_STATUS;
    end
  end

  initial begin
    // On reset setup PCB table
    pcb_addr       = PCB_BASE_INIT;
    adam_state     = MOVE_PCB;
    adamnet_req_n  = '1;
    adamnet_wait_n = '1;
    kbd_status     = RSP_STATUS;
  end

  logic pcb_hit;
  assign pcb_hit = (z80_addr - pcb_base) < PCB_SIZE;

  // Readback
  always_comb begin
    adamnet_dout = '0;
    adamnet_sel  = '0;
    if (pcb_hit) begin
      adamnet_sel  = '1;
      case (z80_addr - pcb_base)
        PCB_CMD_STAT: adamnet_dout = pcb_table.pcb_cmd_stat;
        PCB_BA_LO:    adamnet_dout = pcb_addr[7:0];
        PCB_BA_HI:    adamnet_dout = pcb_addr[15:8];
        PCB_MAX_DCB:  adamnet_dout = pcb_table.pcb_max_dcb;
        default:      adamnet_dout = '0;
      endcase // case (z80_addr - pcb_base)
    end else if (dcb_dev_hit_any) begin
      adamnet_sel  = '1;
      case (dcb_reg)
        DCB_CMD_STAT:   adamnet_dout = dcb_table[dcb_dev].dcb_cmd_stat;
        DCB_BA_LO:      adamnet_dout = dcb_table[dcb_dev].dcb_ba_lo;
        DCB_BA_HI:      adamnet_dout = dcb_table[dcb_dev].dcb_ba_hi;
        DCB_BUF_LEN_LO: adamnet_dout = dcb_table[dcb_dev].dcb_buf_len_lo;
        DCB_BUF_LEN_HI: adamnet_dout = dcb_table[dcb_dev].dcb_buf_len_hi;
        DCB_SEC_NUM_0:  adamnet_dout = dcb_table[dcb_dev].dcb_sec_num_0;
        DCB_SEC_NUM_1:  adamnet_dout = dcb_table[dcb_dev].dcb_sec_num_1;
        DCB_SEC_NUM_2:  adamnet_dout = dcb_table[dcb_dev].dcb_sec_num_2;
        DCB_SEC_NUM_3:  adamnet_dout = dcb_table[dcb_dev].dcb_sec_num_3;
        DCB_DEV_NUM:    adamnet_dout = dcb_table[dcb_dev].dcb_dev_num;
        DCB_RETRY_LO:   adamnet_dout = dcb_table[dcb_dev].dcb_retry_lo;
        DCB_RETRY_HI:   adamnet_dout = dcb_table[dcb_dev].dcb_retry_hi;
        DCB_ADD_CODE:   adamnet_dout = dcb_table[dcb_dev].dcb_add_code;
        DCB_MAXL_LO:    adamnet_dout = dcb_table[dcb_dev].dcb_maxl_lo;
        DCB_MAXL_HI:    adamnet_dout = dcb_table[dcb_dev].dcb_maxl_hi;
        DCB_DEV_TYPE:   adamnet_dout = dcb_table[dcb_dev].dcb_dev_type;
        DCB_NODE_TYPE:  adamnet_dout = dcb_table[dcb_dev].dcb_node_type;
        default:        adamnet_dout = '0;
      endcase // case (z80_addr - DCB_SIZE * dcb_dev)
    end
  end // always_comb

  logic [15:0] ram_buffer;
  logic [15:0] disk_len;
  logic [31:0] disk_sec /* synthesis keep */;
  logic        kbd_sel;
  logic [7:0]  kbd_data;

  //assign ramb_dout    = clear_strobe ? code : disk_data;
  assign ramb_dout    = kbd_sel ? kbd_data : disk_data[disk_dev];

  typedef enum bit [3:0]
               {
                DISK_IDLE,
                WAIT_RAM[2],
                DISK_READ[4],
                DISK_WRITE[4],
                TAPE_READ[4],
                TAPE_WRITE[1]
                } disk_state_t;

  disk_state_t disk_state, tape_state, next_disk_state;

  typedef enum bit [2:0]
               {
                KBD_IDLE,
                KBD_KEY,
                KBD_PAUSE
                } kbd_state_t;

  kbd_state_t kbd_state;

  logic        lastpress;
  logic        press_btn;
  logic [7:0]  code;
  logic        input_strobe;
  logic [15:0] kbd_buffer;
  logic [15:0] kbd_len;
  logic [15:0] kbd_ramb_addr;
  logic        clear_strobe;
  logic [7:0]  key_code;
  logic [7:0]  shift_key_code;
  logic [7:0]  ctrl_key_code;
  logic        shift;
  logic        ctrl;
  logic        caps_lock;
  logic        osd;
  logic        watch_key;
  logic [22:0] key_rep_timer;
  logic        disk_active;
  wire         kbd_write;
  
  initial begin
    disk_state = DISK_IDLE;
    tape_state = DISK_IDLE;
    kbd_state  = KBD_IDLE;
  end

  assign watch_key = (kbd_state == KBD_KEY) && (disk_state == DISK_IDLE);

  assign disk_sector = disk_active ? {disk_sec[31:3], InterleaveTable(disk_sec[2:0])} : disk_sec;

  always_ff @(posedge clk_i) begin
    
    kbd_data <= ctrl ? ctrl_key_code : (shift|caps_lock) ? shift_key_code : key_code;
    disk_done <= '0;
    disk_wr <= '0;
    disk_flush <= '0;
    kbd_done <= '0;
    kbd_sel <= watch_key && input_strobe & ~clear_strobe;
    adamnet_req_n <= '1;
    set_lastblock <= '0;
    ramb_wr <= '0;
    ramb_rd <= '0;
    
    if (watch_key & input_strobe & ~clear_strobe & ~z80_rfsh) begin
        ramb_addr <= kbd_buffer;
        ramb_wr <= '1;
        ramb_rd <= '0;
        clear_strobe <= '1;
    end
    else begin
        case (disk_state)
          DISK_IDLE: begin
            disk_active <= '0;
            if (disk_req) begin
              disk_active <= '1;
              ram_buffer  <= buffer;
              disk_len    <= len;
              dcb_counter <= len;
              disk_sec    <= sec<<1;
              disk_dev    <= diskid;
              done_dev    <= dcb_dev;
              disk_state  <= DISK_READ0;
            end else if (tape_req) begin
              ram_buffer  <= buffer;
              disk_len    <= len;
              dcb_counter <= len;
              disk_sec    <= sec<<1;
              disk_dev    <= NUM_DISKS+tapeid;
              done_dev    <= dcb_dev;
              disk_state  <= TAPE_READ0;
            end
          end // case: DISK_IDLE
          DISK_READ0: begin
            ramb_addr   <= ram_buffer;
            //disk_sector <= {disk_sec[31:3], InterleaveTable(disk_sec[2:0])};
            disk_load[disk_dev]   <= '1;
            adamnet_req_n <= '0;
            if (disk_sector_loaded[disk_dev]) begin
              ramb_addr <= ram_buffer - 1'b1; // We will advance automatically in next state
              disk_load[disk_dev] <= '0;
              data_counter        <= '0;
              disk_state          <= disk_rd ? DISK_READ1 : DISK_WRITE0;
            end
          end // case: DISK_READ0
          DISK_READ1: begin
            adamnet_req_n <= '0;
            if (~adamnet_ack_n || USE_REQ == 0) disk_state   <= disk_rd ? DISK_READ2 : DISK_WRITE0;
          end
          DISK_READ2: begin
            adamnet_req_n <= '0;
            // Read up to 512 bytes (might be less)
            disk_addr <= data_counter;
            if (data_counter < dcb_counter && data_counter < 16'h200) begin
              // We are within the sector
              ramb_addr <= ramb_addr + 1'b1;
              ramb_wr <= '1;
              data_counter <= data_counter + 1'b1;
              ram_buffer   <= ram_buffer + 1'b1;
              disk_state <= WAIT_RAM0;
              next_disk_state <= DISK_READ2;
            end else if (data_counter < dcb_counter) begin
              // We are leaving the sector, but we have more data to read.
              // Flush the current sector
              disk_wr[disk_dev] <= '0;
              disk_flush[disk_dev]   <= '1;
              data_counter <= '0;
              disk_sec     <= disk_sec + 1'b1; // Advance for next sector
              dcb_counter  <= dcb_counter - 16'h200;
              disk_state   <= DISK_READ3;
            end else begin
              // Done reading
              disk_wr[disk_dev]    <= '0;
              disk_flush[disk_dev] <= '1;
              disk_state <= DISK_IDLE;
              disk_done  <= '1;
              adamnet_req_n <= '1;
            end // else: !if(data_counter < dcb_counter)
          end // case: DISK_READ1
          WAIT_RAM0: begin
            adamnet_req_n <= '0;
            ramb_wr <= '0;
            ramb_rd <= '0;
            disk_state <= WAIT_RAM1;
          end
          WAIT_RAM1: begin
            adamnet_req_n <= '0;
            ramb_wr <= '0;
            ramb_rd <= '0;
            if (ramb_wr_ack == 1'b1 || ramb_rd_ack == 1'b1) begin
                disk_state <= next_disk_state;
                disk_addr <= data_counter;
            end
          end
          DISK_READ3: begin
            adamnet_req_n <= '0;
            if (~disk_sector_loaded[disk_dev]) disk_state <= DISK_READ0;
          end
          DISK_WRITE0: begin
            adamnet_req_n <= '0;
            ramb_addr     <= ramb_addr + 1'b1;
            ramb_rd       <= '1;
            disk_state    <= DISK_WRITE1;
          end
          DISK_WRITE1: begin
            ramb_addr    <= ramb_addr;
            // Write up to 512 bytes (might be less)
            disk_addr         <= data_counter;
            disk_din          <= ramb_din;
            if (data_counter < dcb_counter && data_counter < 16'h200) begin
              // We are within the sector
              disk_wr[disk_dev] <= '1;
              ramb_addr    <= ramb_addr + 1'b1;
              ramb_rd      <= '1;
              data_counter <= data_counter + 1'b1;
              ram_buffer   <= ram_buffer + 1'b1;
              disk_state <= WAIT_RAM0;
              next_disk_state <= DISK_WRITE1;
            end else if (data_counter < dcb_counter) begin
              // We are leaving the sector, but we have more data to read.
              // Flush the current sector
              disk_flush[disk_dev]   <= '1;
              disk_state   <= DISK_WRITE2;
            end else begin
              // Done reading
              disk_flush[disk_dev] <= '1;
              disk_state <= DISK_IDLE;
              disk_done  <= '1;
              adamnet_req_n <= '1;
            end // else: !if(data_counter < dcb_counter)
          end // case: DISK_READ1
          DISK_WRITE2: begin
            ramb_addr <= ramb_addr;
            if (disk_flushed) begin
              ramb_addr    <= ramb_addr - 1'b1;
              data_counter <= '0;
              disk_sec     <= disk_sec + 1'b1; // Advance for next sector
              dcb_counter  <= dcb_counter - 16'h200;
              disk_state   <= DISK_WRITE3;
            end
          end
          DISK_WRITE3: begin
            $display("write0 %0h, %0h", ramb_addr, dcb_counter);
            ramb_addr     <= ramb_addr + 1'b1;
            ramb_rd       <= '1;
            disk_state    <= DISK_WRITE1;
          end
          TAPE_READ0: begin
            //disk_sector <= disk_sec[31:0];
            disk_load[disk_dev]   <= '1;
            adamnet_req_n <= '0;
            if (disk_sector_loaded[disk_dev]) begin
              $display("Adamnet (HDL): Disk %s: %s %d bytes, sector 0x%X, memory 0x%04X\n",
                       dcb_dev+65,disk_rd? "Reading":"Writing",dcb_counter,{disk_sec[31:3], InterleaveTable(disk_sec[2:0])},ram_buffer);
              ramb_addr <= ram_buffer - 1'b1; // We will advance automatically in next state
              disk_load[disk_dev]    <= '0;
              data_counter <= '0;
              disk_state   <= disk_rd ? TAPE_READ1 : TAPE_WRITE0;
            end
          end // case: DISK_READ0
          TAPE_READ1: begin
            adamnet_req_n <= '0;
            if (~adamnet_ack_n || USE_REQ == 0) disk_state   <= disk_rd ? TAPE_READ2 : TAPE_WRITE0;
          end
          TAPE_READ2: begin
            adamnet_req_n <= '0;
            // Read up to 512 bytes (might be less)
            disk_addr <= data_counter;
            if (data_counter < dcb_counter && data_counter < 16'h200) begin
              // We are within the sector
              ramb_addr <= ramb_addr + 1'b1;
              ramb_wr <= '1;
              data_counter <= data_counter + 1'b1;
              ram_buffer   <= ram_buffer + 1'b1;
              disk_state <= WAIT_RAM0;
              next_disk_state <= TAPE_READ2;
            end else if (data_counter < dcb_counter) begin
              // We are leaving the sector, but we have more data to read.
              // Flush the current sector
              disk_wr[disk_dev]      <= '0;
              disk_flush[disk_dev]   <= '1;
              data_counter <= '0;
              disk_sec     <= disk_sec + 1'b1; // Advance for next sector
              dcb_counter  <= dcb_counter - 16'h200;
              disk_state   <= TAPE_READ3;
            end else begin
              // Done reading
              disk_wr[disk_dev]    <= '0;
              disk_flush[disk_dev] <= '1;
              disk_state <= DISK_IDLE;
              disk_done  <= '1;
              adamnet_req_n <= '1;
            end // else: !if(data_counter < dcb_counter)
          end // case: DISK_READ1
          TAPE_READ3: begin
            adamnet_req_n <= '0;
            if (~disk_sector_loaded[disk_dev]) disk_state <= TAPE_READ0;
          end
          TAPE_WRITE0: begin
            $display("Write not supported");
            $finish;
          end
          default: begin
          end
        endcase

        lastpress <= ps2_key[10];
    //    if(lastpress != ps2_key[10]) begin
        if (ps2_key[10] == 1'b1) begin
            if (ps2_key[8:0] == 9'h014) ctrl <= ps2_key[9]; //CTRL
            else if (ps2_key[8:0] == 9'h012) shift <= ps2_key[9]; //LEFT SHIFT
            else if (ps2_key[8:0] == 9'h058) begin 
                if (ps2_key[9]) caps_lock <= ~caps_lock;
            end  //CAPSLOCK
            else if (ps2_key[8:0] == 9'h059) shift <= ps2_key[9]; //RIGHT SHIFT
            else if (ps2_key[8:0] == 9'h007) osd <= ps2_key[9]; //OSD ignore key
            else begin
                press_btn    <= ps2_key[9];
                code         <= ps2_key[7:0];
                input_strobe <= '1;
                key_rep_timer <= 'd7000000;
            end
        end else if (clear_strobe) begin
            input_strobe <= '0;
        end else begin
            key_rep_timer <= key_rep_timer-1;
            if (key_rep_timer==0) begin
                 key_rep_timer <= 933333;
                 input_strobe<= ps2_key[10];
            end
        end
        clear_strobe <= '0;

        case (kbd_state)
            KBD_IDLE: begin
                if (kbd_req) begin
                    kbd_buffer <= buffer;
                    kbd_len    <= len;
                    kbd_state  <= KBD_KEY;
                    kbd_dev    <= dcb_dev;
                end
            end
            KBD_KEY: begin
                if (clear_strobe == 1'b1) begin
                    if (press_btn) begin
                        // Keyboard data is available and disk is idle so we can
                        // write to the keyboard buffer
                        kbd_buffer <= kbd_buffer + 1'b1;
                        kbd_len <= kbd_len - 1'b1;

                        if (kbd_len == 1) begin
                            kbd_state <= KBD_IDLE;
                            kbd_done  <= '1;
                        end else begin
                            kbd_state <= KBD_PAUSE;
                        end
                    end // if (~press_btn)
                end
            end // case: KBD_KEY
            KBD_PAUSE: kbd_state  <= KBD_KEY;
            default: begin
            end
        endcase // case (kbd_state)
      end
  end

always @(*) begin
  key_code = 'h000;
        case (ps2_key[8:0])
        9'h000 : key_code = 'h00;
        9'h001 : key_code = 'h87;	//F9
        9'h002 : key_code = 'h87;
        9'h003 : key_code = 'h85;	//F5
        9'h004 : key_code = 'h83;	//F3
        9'h005 : key_code = 'h81;	//F1
        9'h006 : key_code = 'h82;	//F2
        9'h007 : key_code = 'h87;	//F12 <OSD>
        9'h008 : key_code = 'h87;
        9'h009 : key_code = 'h87;	//F10
        9'h00a : key_code = 'h87;	//F8
        9'h00b : key_code = 'h86;	//F6
        9'h00c : key_code = 'h84;	//F4
        9'h00d : key_code = 'h09;	//TAB
        9'h00e : key_code = 'h7E;	//~ (`)
        9'h00f : key_code = 'h87;
        9'h010 : key_code = 'h87;
        9'h011 : key_code = 'h6f;	//LEFT ALT (command)
          //9'h012 : key_code = 'h87;      //key_code = 'h071;	//LEFT SHIFT
        9'h013 : key_code = 'h87;
          //9'h014 : key_code = 'h87;	//CTRL (not mapped)
        9'h015 : key_code = 'h71;	//q
        9'h016 : key_code = 'h31;	//1
        9'h017 : key_code = 'h87;
        9'h018 : key_code = 'h87;
        9'h019 : key_code = 'h87;
        9'h01a : key_code = 'h7a;	//z
        9'h01b : key_code = 'h73;	//s
        9'h01c : key_code = 'h61;	//a
        9'h01d : key_code = 'h77;	//w
        9'h01e : key_code = 'h32;	//2
        9'h01f : key_code = 'h87;
        9'h020 : key_code = 'h87;
        9'h021 : key_code = 'h63;	//c
        9'h022 : key_code = 'h78;	//x
        9'h023 : key_code = 'h64;	//d
        9'h024 : key_code = 'h65;	//e
        9'h025 : key_code = 'h34;	//4
        9'h026 : key_code = 'h33;	//3
        9'h027 : key_code = 'h87;
        9'h028 : key_code = 'h87;
        9'h029 : key_code = 'h20;	//SPACE
        9'h02a : key_code = 'h76;	//v
        9'h02b : key_code = 'h66;	//f
        9'h02c : key_code = 'h74;	//t
        9'h02d : key_code = 'h72;	//r
        9'h02e : key_code = 'h35;	//5
        9'h02f : key_code = 'h87;
        9'h030 : key_code = 'h87;
        9'h031 : key_code = 'h6e;	//n
        9'h032 : key_code = 'h62;	//b
        9'h033 : key_code = 'h68;	//h
        9'h034 : key_code = 'h67;	//g
        9'h035 : key_code = 'h79;	//y
        9'h036 : key_code = 'h36;	//6
        9'h037 : key_code = 'h87;
        9'h038 : key_code = 'h87;
        9'h039 : key_code = 'h87;
        9'h03a : key_code = 'h6d;	//m
        9'h03b : key_code = 'h6a;	//j
        9'h03c : key_code = 'h75;	//u
        9'h03d : key_code = 'h37;	//7
        9'h03e : key_code = 'h38;	//8
        9'h03f : key_code = 'h87;
        9'h040 : key_code = 'h87;
        9'h041 : key_code = 'h2c;	//<,
        9'h042 : key_code = 'h6b;	//k
        9'h043 : key_code = 'h69;	//i
        9'h044 : key_code = 'h6f;	//o
        9'h045 : key_code = 'h30;	//0
        9'h046 : key_code = 'h39;	//9
        9'h047 : key_code = 'h87;
        9'h048 : key_code = 'h87;
        9'h049 : key_code = 'h2e;	//>.
        9'h04a : key_code = 'h2f;	//FORWARD SLASH
        9'h04b : key_code = 'h6c;	//l
        9'h04c : key_code = 'h3b;	//;
        9'h04d : key_code = 'h70;	//p
        9'h04e : key_code = 'h2d;	//-
        9'h04f : key_code = 'h87;
        9'h050 : key_code = 'h87;
        9'h051 : key_code = 'h87;
        9'h052 : key_code = 'h27;	//'"
        9'h053 : key_code = 'h87;
        9'h054 : key_code = 'h5b;	//[
        9'h055 : key_code = 'h3d;	// =
        9'h056 : key_code = 'h87;
        9'h057 : key_code = 'h87;
          //9'h058 : key_code = 'h87;      //CAPSLOCK
          //9'h059 : key_code = 'h87;      //key_code = 'h071;	//RIGHT SHIFT
        9'h05a : key_code = 'h0d;	//ENTER
        9'h05b : key_code = 'h5d;	//]
        9'h05c : key_code = 'h87;
        9'h05d : key_code = 'h5c;	//BACKSLASH
        9'h05e : key_code = 'h87;
        9'h05f : key_code = 'h87;
        9'h060 : key_code = 'h87;
        9'h061 : key_code = 'h71;	//international left shift cut out (German '<>' key), 0x56 Set#1 code
        9'h062 : key_code = 'h87;
        9'h063 : key_code = 'h87;
        9'h064 : key_code = 'h87;
        9'h065 : key_code = 'h87;
        9'h066 : key_code = 'h08;	//BACKSPACE
        9'h067 : key_code = 'h87;
        9'h068 : key_code = 'h87;
        9'h069 : key_code = 'h27;	//KP 1
        9'h06a : key_code = 'h87;
        9'h06b : key_code = 'h2d;	//KP 4
        9'h06c : key_code = 'h33;	//KP 7
        9'h06d : key_code = 'h87;
        9'h06e : key_code = 'h87;
        9'h06f : key_code = 'h87;
        9'h070 : key_code = 'h25;	//KP 0
        9'h071 : key_code = 'h03;	//KP .
        9'h072 : key_code = 'h29;	//KP 2
        9'h073 : key_code = 'h2f;	//KP 5
        9'h074 : key_code = 'h31;	//KP 6
        9'h075 : key_code = 'h37;	//KP 8
        9'h076 : key_code = 'h1b;	//ESCAPE
        9'h077 : key_code = 'h87;	//NUMLOCK (Mac keypad clear?)
        9'h078 : key_code = 'h87;	//F11 <OSD>
        9'h079 : key_code = 'h0d;	//KP +
        9'h07a : key_code = 'h2b;	//KP 3
        9'h07b : key_code = 'h1d;	//KP -
        9'h07c : key_code = 'h05;	//KP *
        9'h07d : key_code = 'h39;	//KP 9
        9'h07e : key_code = 'h87;	//SCROLL LOCK / KP )
        9'h07f : key_code = 'h87;
        9'h080 : key_code = 'h87;
        9'h081 : key_code = 'h87;
        9'h082 : key_code = 'h87;
        9'h083 : key_code = 'h87;	//F7
        9'h084 : key_code = 'h87;
        9'h085 : key_code = 'h87;
        9'h086 : key_code = 'h87;
        9'h087 : key_code = 'h87;
        9'h088 : key_code = 'h87;
        9'h089 : key_code = 'h87;
        9'h08a : key_code = 'h87;
        9'h08b : key_code = 'h87;
        9'h08c : key_code = 'h87;
        9'h08d : key_code = 'h87;
        9'h08e : key_code = 'h87;
        9'h08f : key_code = 'h87;
        9'h090 : key_code = 'h87;
        9'h091 : key_code = 'h87;
        9'h092 : key_code = 'h87;
        9'h093 : key_code = 'h87;
        9'h094 : key_code = 'h87;
        9'h095 : key_code = 'h87;
        9'h096 : key_code = 'h87;
        9'h097 : key_code = 'h87;
        9'h098 : key_code = 'h87;
        9'h099 : key_code = 'h87;
        9'h09a : key_code = 'h87;
        9'h09b : key_code = 'h87;
        9'h09c : key_code = 'h87;
        9'h09d : key_code = 'h87;
        9'h09e : key_code = 'h87;
        9'h09f : key_code = 'h87;
        9'h0a0 : key_code = 'h87;
        9'h0a1 : key_code = 'h87;
        9'h0a2 : key_code = 'h87;
        9'h0a3 : key_code = 'h87;
        9'h0a4 : key_code = 'h87;
        9'h0a5 : key_code = 'h87;
        9'h0a6 : key_code = 'h87;
        9'h0a7 : key_code = 'h87;
        9'h0a8 : key_code = 'h87;
        9'h0a9 : key_code = 'h87;
        9'h0aa : key_code = 'h87;
        9'h0ab : key_code = 'h87;
        9'h0ac : key_code = 'h87;
        9'h0ad : key_code = 'h87;
        9'h0ae : key_code = 'h87;
        9'h0af : key_code = 'h87;
        9'h0b0 : key_code = 'h87;
        9'h0b1 : key_code = 'h87;
        9'h0b2 : key_code = 'h87;
        9'h0b3 : key_code = 'h87;
        9'h0b4 : key_code = 'h87;
        9'h0b5 : key_code = 'h87;
        9'h0b6 : key_code = 'h87;
        9'h0b7 : key_code = 'h87;
        9'h0b8 : key_code = 'h87;
        9'h0b9 : key_code = 'h87;
        9'h0ba : key_code = 'h87;
        9'h0bb : key_code = 'h87;
        9'h0bc : key_code = 'h87;
        9'h0bd : key_code = 'h87;
        9'h0be : key_code = 'h87;
        9'h0bf : key_code = 'h87;
        9'h0c0 : key_code = 'h87;
        9'h0c1 : key_code = 'h87;
        9'h0c2 : key_code = 'h87;
        9'h0c3 : key_code = 'h87;
        9'h0c4 : key_code = 'h87;
        9'h0c5 : key_code = 'h87;
        9'h0c6 : key_code = 'h87;
        9'h0c7 : key_code = 'h087;
        9'h0c8 : key_code = 'h087;
        9'h0c9 : key_code = 'h087;
        9'h0ca : key_code = 'h087;
        9'h0cb : key_code = 'h087;
        9'h0cc : key_code = 'h087;
        9'h0cd : key_code = 'h087;
        9'h0ce : key_code = 'h087;
        9'h0cf : key_code = 'h087;
        9'h0d0 : key_code = 'h087;
        9'h0d1 : key_code = 'h087;
        9'h0d2 : key_code = 'h087;
        9'h0d3 : key_code = 'h087;
        9'h0d4 : key_code = 'h087;
        9'h0d5 : key_code = 'h087;
        9'h0d6 : key_code = 'h087;
        9'h0d7 : key_code = 'h087;
        9'h0d8 : key_code = 'h087;
        9'h0d9 : key_code = 'h087;
        9'h0da : key_code = 'h087;
        9'h0db : key_code = 'h087;
        9'h0dc : key_code = 'h087;
        9'h0dd : key_code = 'h087;
        9'h0de : key_code = 'h087;
        9'h0df : key_code = 'h087;
        9'h0e0 : key_code = 'h087;	//ps2 extended key
        9'h0e1 : key_code = 'h087;
        9'h0e2 : key_code = 'h087;
        9'h0e3 : key_code = 'h087;
        9'h0e4 : key_code = 'h087;
        9'h0e5 : key_code = 'h087;
        9'h0e6 : key_code = 'h087;
        9'h0e7 : key_code = 'h087;
        9'h0e8 : key_code = 'h087;
        9'h0e9 : key_code = 'h087;
        9'h0ea : key_code = 'h087;
        9'h0eb : key_code = 'h087;
        9'h0ec : key_code = 'h087;
        9'h0ed : key_code = 'h087;
        9'h0ee : key_code = 'h087;
        9'h0ef : key_code = 'h087;
        9'h0f0 : key_code = 'h087;	//ps2 release code
        9'h0f1 : key_code = 'h087;
        9'h0f2 : key_code = 'h087;
        9'h0f3 : key_code = 'h087;
        9'h0f4 : key_code = 'h087;
        9'h0f5 : key_code = 'h087;
        9'h0f6 : key_code = 'h087;
        9'h0f7 : key_code = 'h087;
        9'h0f8 : key_code = 'h087;
        9'h0f9 : key_code = 'h087;
        9'h0fa : key_code = 'h087;	//ps2 ack code
        9'h0fb : key_code = 'h087;
        9'h0fc : key_code = 'h087;
        9'h0fd : key_code = 'h087;
        9'h0fe : key_code = 'h087;
        9'h0ff : key_code = 'h087;
        9'h100 : key_code = 'h087;
        9'h101 : key_code = 'h087;
        9'h102 : key_code = 'h087;
        9'h103 : key_code = 'h087;
        9'h104 : key_code = 'h087;
        9'h105 : key_code = 'h087;
        9'h106 : key_code = 'h087;
        9'h107 : key_code = 'h087;
        9'h108 : key_code = 'h087;
        9'h109 : key_code = 'h087;
        9'h10a : key_code = 'h087;
        9'h10b : key_code = 'h087;
        9'h10c : key_code = 'h087;
        9'h10d : key_code = 'h087;
        9'h10e : key_code = 'h087;
        9'h10f : key_code = 'h087;
        9'h110 : key_code = 'h087;
        9'h111 : key_code = 'h06f;	//RIGHT ALT (command)
        9'h112 : key_code = 'h087;
        9'h113 : key_code = 'h087;
        9'h114 : key_code = 'h087;
        9'h115 : key_code = 'h087;
        9'h116 : key_code = 'h087;
        9'h117 : key_code = 'h087;
        9'h118 : key_code = 'h087;
        9'h119 : key_code = 'h087;
        9'h11a : key_code = 'h087;
        9'h11b : key_code = 'h087;
        9'h11c : key_code = 'h087;
        9'h11d : key_code = 'h087;
        9'h11e : key_code = 'h087;
        9'h11f : key_code = 'h075;	//WINDOWS OR APPLICATION KEY (option)
        9'h120 : key_code = 'h087;
        9'h121 : key_code = 'h087;
        9'h122 : key_code = 'h087;
        9'h123 : key_code = 'h087;
        9'h124 : key_code = 'h087;
        9'h125 : key_code = 'h087;
        9'h126 : key_code = 'h087;
        9'h127 : key_code = 'h87;
        9'h128 : key_code = 'h87;
        9'h129 : key_code = 'h87;
        9'h12a : key_code = 'h87;
        9'h12b : key_code = 'h87;
        9'h12c : key_code = 'h87;
        9'h12d : key_code = 'h87;
        9'h12e : key_code = 'h87;
        9'h12f : key_code = 'h87;
        9'h130 : key_code = 'h87;
        9'h131 : key_code = 'h87;
        9'h132 : key_code = 'h87;
        9'h133 : key_code = 'h87;
        9'h134 : key_code = 'h87;
        9'h135 : key_code = 'h87;
        9'h136 : key_code = 'h87;
        9'h137 : key_code = 'h87;
        9'h138 : key_code = 'h87;
        9'h139 : key_code = 'h87;
        9'h13a : key_code = 'h87;
        9'h13b : key_code = 'h87;
        9'h13c : key_code = 'h87;
        9'h13d : key_code = 'h87;
        9'h13e : key_code = 'h87;
        9'h13f : key_code = 'h87;
        9'h140 : key_code = 'h87;
        9'h141 : key_code = 'h87;
        9'h142 : key_code = 'h87;
        9'h143 : key_code = 'h87;
        9'h144 : key_code = 'h87;
        9'h145 : key_code = 'h87;
        9'h146 : key_code = 'h87;
        9'h147 : key_code = 'h87;
        9'h148 : key_code = 'h87;
        9'h149 : key_code = 'h87;
        9'h14a : key_code = 'h1b;	//KP /
        9'h14b : key_code = 'h87;
        9'h14c : key_code = 'h87;
        9'h14d : key_code = 'h87;
        9'h14e : key_code = 'h87;
        9'h14f : key_code = 'h87;
        9'h150 : key_code = 'h87;
        9'h151 : key_code = 'h87;
        9'h152 : key_code = 'h87;
        9'h153 : key_code = 'h87;
        9'h154 : key_code = 'h87;
        9'h155 : key_code = 'h87;
        9'h156 : key_code = 'h87;
        9'h157 : key_code = 'h87;
        9'h158 : key_code = 'h87;
        9'h159 : key_code = 'h87;
        9'h15a : key_code = 'h19;	//KP ENTER
        9'h15b : key_code = 'h87;
        9'h15c : key_code = 'h87;
        9'h15d : key_code = 'h87;
        9'h15e : key_code = 'h87;
        9'h15f : key_code = 'h87;
        9'h160 : key_code = 'h87;
        9'h161 : key_code = 'h87;
        9'h162 : key_code = 'h87;
        9'h163 : key_code = 'h87;
        9'h164 : key_code = 'h87;
        9'h165 : key_code = 'h87;
        9'h166 : key_code = 'h87;
        9'h167 : key_code = 'h87;
        9'h168 : key_code = 'h87;
        9'h169 : key_code = 'h87;	//END
        9'h16a : key_code = 'h87;
        9'h16b : key_code = 'hA3;	//ARROW LEFT
        9'h16c : key_code = 'h80;	//HOME
        9'h16d : key_code = 'h87;
        9'h16e : key_code = 'h87;
        9'h16f : key_code = 'h87;
        9'h170 : key_code = 'h87;	//INSERT = HELP
        9'h171 : key_code = 'h0f;	//DELETE (KP clear?)
        9'h172 : key_code = 'hA2;	//ARROW DOWN
        9'h173 : key_code = 'h87;
        9'h174 : key_code = 'hA1;	//ARROW RIGHT
        9'h175 : key_code = 'hA0;	//ARROW UP
        9'h176 : key_code = 'h87;
        9'h177 : key_code = 'h87;
        9'h178 : key_code = 'h87;
        9'h179 : key_code = 'h87;
        9'h17a : key_code = 'h87;	//PGDN <OSD>
        9'h17b : key_code = 'h87;
        9'h17c : key_code = 'h87;	//PRTSCR <OSD>
        9'h17d : key_code = 'h87;	//PGUP <OSD>
        9'h17e : key_code = 'h87;	//ctrl+break
        9'h17f : key_code = 'h87;
        9'h180 : key_code = 'h87;
        9'h181 : key_code = 'h87;
        9'h182 : key_code = 'h87;
        9'h183 : key_code = 'h87;
        9'h184 : key_code = 'h87;
        9'h185 : key_code = 'h87;
        9'h186 : key_code = 'h87;
        9'h187 : key_code = 'h87;
        9'h188 : key_code = 'h87;
        9'h189 : key_code = 'h87;
        9'h18a : key_code = 'h87;
        9'h18b : key_code = 'h87;
        9'h18c : key_code = 'h87;
        9'h18d : key_code = 'h87;
        9'h18e : key_code = 'h87;
        9'h18f : key_code = 'h87;
        9'h190 : key_code = 'h87;
        9'h191 : key_code = 'h87;
        9'h192 : key_code = 'h87;
        9'h193 : key_code = 'h87;
        9'h194 : key_code = 'h87;
        9'h195 : key_code = 'h87;
        9'h196 : key_code = 'h87;
        9'h197 : key_code = 'h87;
        9'h198 : key_code = 'h87;
        9'h199 : key_code = 'h87;
        9'h19a : key_code = 'h87;
        9'h19b : key_code = 'h87;
        9'h19c : key_code = 'h87;
        9'h19d : key_code = 'h87;
        9'h19e : key_code = 'h87;
        9'h19f : key_code = 'h87;
        9'h1a0 : key_code = 'h87;
        9'h1a1 : key_code = 'h87;
        9'h1a2 : key_code = 'h87;
        9'h1a3 : key_code = 'h87;
        9'h1a4 : key_code = 'h87;
        9'h1a5 : key_code = 'h87;
        9'h1a6 : key_code = 'h87;
        9'h1a7 : key_code = 'h87;
        9'h1a8 : key_code = 'h87;
        9'h1a9 : key_code = 'h87;
        9'h1aa : key_code = 'h87;
        9'h1ab : key_code = 'h87;
        9'h1ac : key_code = 'h87;
        9'h1ad : key_code = 'h87;
        9'h1ae : key_code = 'h87;
        9'h1af : key_code = 'h87;
        9'h1b0 : key_code = 'h87;
        9'h1b1 : key_code = 'h87;
        9'h1b2 : key_code = 'h87;
        9'h1b3 : key_code = 'h87;
        9'h1b4 : key_code = 'h87;
        9'h1b5 : key_code = 'h87;
        9'h1b6 : key_code = 'h87;
        9'h1b7 : key_code = 'h87;
        9'h1b8 : key_code = 'h87;
        9'h1b9 : key_code = 'h87;
        9'h1ba : key_code = 'h87;
        9'h1bb : key_code = 'h87;
        9'h1bc : key_code = 'h87;
        9'h1bd : key_code = 'h87;
        9'h1be : key_code = 'h87;
        9'h1bf : key_code = 'h87;
        9'h1c0 : key_code = 'h87;
        9'h1c1 : key_code = 'h87;
        9'h1c2 : key_code = 'h87;
        9'h1c3 : key_code = 'h87;
        9'h1c4 : key_code = 'h87;
        9'h1c5 : key_code = 'h87;
        9'h1c6 : key_code = 'h87;
        9'h1c7 : key_code = 'h87;
        9'h1c8 : key_code = 'h87;
        9'h1c9 : key_code = 'h87;
        9'h1ca : key_code = 'h87;
        9'h1cb : key_code = 'h87;
        9'h1cc : key_code = 'h87;
        9'h1cd : key_code = 'h87;
        9'h1ce : key_code = 'h87;
        9'h1cf : key_code = 'h87;
        9'h1d0 : key_code = 'h87;
        9'h1d1 : key_code = 'h87;
        9'h1d2 : key_code = 'h87;
        9'h1d3 : key_code = 'h87;
        9'h1d4 : key_code = 'h87;
        9'h1d5 : key_code = 'h87;
        9'h1d6 : key_code = 'h87;
        9'h1d7 : key_code = 'h87;
        9'h1d8 : key_code = 'h87;
        9'h1d9 : key_code = 'h87;
        9'h1da : key_code = 'h87;
        9'h1db : key_code = 'h87;
        9'h1dc : key_code = 'h87;
        9'h1dd : key_code = 'h87;
        9'h1de : key_code = 'h87;
        9'h1df : key_code = 'h87;
        9'h1e0 : key_code = 'h87;	//ps2 extended key(duplicate, see $e0)
        9'h1e1 : key_code = 'h87;
        9'h1e2 : key_code = 'h87;
        9'h1e3 : key_code = 'h87;
        9'h1e4 : key_code = 'h87;
        9'h1e5 : key_code = 'h87;
        9'h1e6 : key_code = 'h87;
        9'h1e7 : key_code = 'h87;
        9'h1e8 : key_code = 'h87;
        9'h1e9 : key_code = 'h87;
        9'h1ea : key_code = 'h87;
        9'h1eb : key_code = 'h87;
        9'h1ec : key_code = 'h87;
        9'h1ed : key_code = 'h87;
        9'h1ee : key_code = 'h87;
        9'h1ef : key_code = 'h87;
        9'h1f0 : key_code = 'h87;	//ps2 release code(duplicate, see $f0)
        9'h1f1 : key_code = 'h87;
        9'h1f2 : key_code = 'h87;
        9'h1f3 : key_code = 'h87;
        9'h1f4 : key_code = 'h87;
        9'h1f5 : key_code = 'h87;
        9'h1f6 : key_code = 'h87;
        9'h1f7 : key_code = 'h87;
        9'h1f8 : key_code = 'h87;
        9'h1f9 : key_code = 'h87;
        9'h1fa : key_code = 'h87;	//ps2 ack code(duplicate see $fa)
        9'h1fb : key_code = 'h87;
        9'h1fc : key_code = 'h87;
        9'h1fd : key_code = 'h87;
        9'h1fe : key_code = 'h87;
        9'h1ff : key_code = 'h87;
        default: key_code = 'h000;
    endcase
end


always @(*) begin
  shift_key_code = '0;
case (key_code)
    8'h00 : shift_key_code = 'h00;
    8'h01 : shift_key_code = 'h01;
    8'h02 : shift_key_code = 'h02;
    8'h03 : shift_key_code = 'h03;
    8'h04 : shift_key_code = 'h04;
    8'h05 : shift_key_code = 'h05;
    8'h06 : shift_key_code = 'h06;
    8'h07 : shift_key_code = 'h07;
    8'h08 : shift_key_code = 'hb8;
    8'h09 : shift_key_code = 'hb9;
    8'h0a : shift_key_code = 'h0a;
    8'h0b : shift_key_code = 'h0b;
    8'h0c : shift_key_code = 'h0c;
    8'h0d : shift_key_code = 'h0d;
    8'h0e : shift_key_code = 'h0e;
    8'h0f : shift_key_code = 'h0f;
    8'h10 : shift_key_code = 'h10;
    8'h11 : shift_key_code = 'h11;
    8'h12 : shift_key_code = 'h12;
    8'h13 : shift_key_code = 'h13;
    8'h14 : shift_key_code = 'h14;
    8'h15 : shift_key_code = 'h15;
    8'h16 : shift_key_code = 'h16;
    8'h17 : shift_key_code = 'h17;
    8'h18 : shift_key_code = 'h18;
    8'h19 : shift_key_code = 'h19;
    8'h1a : shift_key_code = 'h1a;
    8'h1b : shift_key_code = 'h1b;
    8'h1c : shift_key_code = 'h1c;
    8'h1d : shift_key_code = 'h1d;
    8'h1e : shift_key_code = 'h1e;
    8'h1f : shift_key_code = 'h1f;
    8'h20 : shift_key_code = 'h20;
    8'h21 : shift_key_code = 'h21;
    8'h22 : shift_key_code = 'h22;
    8'h23 : shift_key_code = 'h23;
    8'h24 : shift_key_code = 'h24;
    8'h25 : shift_key_code = 'h25;
    8'h26 : shift_key_code = 'h26;
    8'h27 : shift_key_code = 'h22;
    8'h28 : shift_key_code = 'h28;
    8'h29 : shift_key_code = 'h29;
    8'h2a : shift_key_code = 'h2a;
    8'h2b : shift_key_code = 'h2b;
    8'h2c : shift_key_code = 'h3c;
    8'h2d : shift_key_code = 'h5f;
    8'h2e : shift_key_code = 'h3e;
    8'h2f : shift_key_code = 'h3f;
    8'h30 : shift_key_code = 'h29;
    8'h31 : shift_key_code = 'h21;
    8'h32 : shift_key_code = 'h40;
    8'h33 : shift_key_code = 'h23;
    8'h34 : shift_key_code = 'h24;
    8'h35 : shift_key_code = 'h25;
    8'h36 : shift_key_code = 'h5e;
    8'h37 : shift_key_code = 'h26;
    8'h38 : shift_key_code = 'h2a;
    8'h39 : shift_key_code = 'h28;
    8'h3a : shift_key_code = 'h3a;
    8'h3b : shift_key_code = 'h3a;
    8'h3c : shift_key_code = 'h3c;
    8'h3d : shift_key_code = 'h2b;
    8'h3e : shift_key_code = 'h3e;
    8'h3f : shift_key_code = 'h3f;
    8'h40 : shift_key_code = 'h40;
    8'h41 : shift_key_code = 'h61;
    8'h42 : shift_key_code = 'h62;
    8'h43 : shift_key_code = 'h63;
    8'h44 : shift_key_code = 'h64;
    8'h45 : shift_key_code = 'h65;
    8'h46 : shift_key_code = 'h66;
    8'h47 : shift_key_code = 'h67;
    8'h48 : shift_key_code = 'h68;
    8'h49 : shift_key_code = 'h69;
    8'h4a : shift_key_code = 'h6a;
    8'h4b : shift_key_code = 'h6b;
    8'h4c : shift_key_code = 'h6c;
    8'h4d : shift_key_code = 'h6d;
    8'h4e : shift_key_code = 'h6e;
    8'h4f : shift_key_code = 'h6f;
    8'h50 : shift_key_code = 'h70;
    8'h51 : shift_key_code = 'h71;
    8'h52 : shift_key_code = 'h72;
    8'h53 : shift_key_code = 'h73;
    8'h54 : shift_key_code = 'h74;
    8'h55 : shift_key_code = 'h75;
    8'h56 : shift_key_code = 'h76;
    8'h57 : shift_key_code = 'h77;
    8'h58 : shift_key_code = 'h78;
    8'h59 : shift_key_code = 'h79;
    8'h5a : shift_key_code = 'h7a;
    8'h5b : shift_key_code = 'h7b;
    8'h5c : shift_key_code = 'h7c;
    8'h5d : shift_key_code = 'h7d;
    8'h5e : shift_key_code = 'h5e;
    8'h5f : shift_key_code = 'h5f;
    8'h60 : shift_key_code = 'h7e;
    8'h61 : shift_key_code = 'h41;
    8'h62 : shift_key_code = 'h42;
    8'h63 : shift_key_code = 'h43;
    8'h64 : shift_key_code = 'h44;
    8'h65 : shift_key_code = 'h45;
    8'h66 : shift_key_code = 'h46;
    8'h67 : shift_key_code = 'h47;
    8'h68 : shift_key_code = 'h48;
    8'h69 : shift_key_code = 'h49;
    8'h6a : shift_key_code = 'h4a;
    8'h6b : shift_key_code = 'h4b;
    8'h6c : shift_key_code = 'h4c;
    8'h6d : shift_key_code = 'h4d;
    8'h6e : shift_key_code = 'h4e;
    8'h6f : shift_key_code = 'h4f;
    8'h70 : shift_key_code = 'h50;
    8'h71 : shift_key_code = 'h51;
    8'h72 : shift_key_code = 'h52;
    8'h73 : shift_key_code = 'h53;
    8'h74 : shift_key_code = 'h54;
    8'h75 : shift_key_code = 'h55;
    8'h76 : shift_key_code = 'h56;
    8'h77 : shift_key_code = 'h57;
    8'h78 : shift_key_code = 'h58;
    8'h79 : shift_key_code = 'h59;
    8'h7a : shift_key_code = 'h5a;
    8'h7b : shift_key_code = 'h7b;
    8'h7c : shift_key_code = 'h7c;
    8'h7d : shift_key_code = 'h7d;
    8'h7e : shift_key_code = 'h7e;
    8'h7f : shift_key_code = 'h7f;
    8'h80 : shift_key_code = 'h80;
    8'h81 : shift_key_code = 'h89;
    8'h82 : shift_key_code = 'h8a;
    8'h83 : shift_key_code = 'h8b;
    8'h84 : shift_key_code = 'h8c;
    8'h85 : shift_key_code = 'h8d;
    8'h86 : shift_key_code = 'h8e;
    8'h87 : shift_key_code = 'h87;
    8'h88 : shift_key_code = 'h88;
    8'h89 : shift_key_code = 'h89;
    8'h8a : shift_key_code = 'h8a;
    8'h8b : shift_key_code = 'h8b;
    8'h8c : shift_key_code = 'h8c;
    8'h8d : shift_key_code = 'h8d;
    8'h8e : shift_key_code = 'h8e;
    8'h8f : shift_key_code = 'h8f;
    8'h90 : shift_key_code = 'h98;
    8'h91 : shift_key_code = 'h99;
    8'h92 : shift_key_code = 'h9a;
    8'h93 : shift_key_code = 'h9b;
    8'h94 : shift_key_code = 'h9c;
    8'h95 : shift_key_code = 'h9d;
    8'h96 : shift_key_code = 'h9e;
    8'h97 : shift_key_code = 'h9f;
    8'h98 : shift_key_code = 'h98;
    8'h99 : shift_key_code = 'h99;
    8'h9a : shift_key_code = 'h9a;
    8'h9b : shift_key_code = 'h9b;
    8'h9c : shift_key_code = 'h9c;
    8'h9d : shift_key_code = 'h9d;
    8'h9e : shift_key_code = 'h9e;
    8'h9f : shift_key_code = 'h9f;
    8'ha0 : shift_key_code = 'ha0;
    8'ha1 : shift_key_code = 'ha1;
    8'ha2 : shift_key_code = 'ha2;
    8'ha3 : shift_key_code = 'ha3;
    8'ha4 : shift_key_code = 'ha4;
    8'ha5 : shift_key_code = 'ha5;
    8'ha6 : shift_key_code = 'ha6;
    8'ha7 : shift_key_code = 'ha7;
    8'ha8 : shift_key_code = 'ha8;
    8'ha9 : shift_key_code = 'ha9;
    8'haa : shift_key_code = 'haa;
    8'hab : shift_key_code = 'hab;
    8'hac : shift_key_code = 'hac;
    8'had : shift_key_code = 'had;
    8'hae : shift_key_code = 'hae;
    8'haf : shift_key_code = 'haf;
    8'hb0 : shift_key_code = 'hb0;
    8'hb1 : shift_key_code = 'hb1;
    8'hb2 : shift_key_code = 'hb2;
    8'hb3 : shift_key_code = 'hb3;
    8'hb4 : shift_key_code = 'hb4;
    8'hb5 : shift_key_code = 'hb5;
    8'hb6 : shift_key_code = 'hb6;
    8'hb7 : shift_key_code = 'hb7;
    8'hb8 : shift_key_code = 'hb8;
    8'hb9 : shift_key_code = 'hb9;
    8'hba : shift_key_code = 'hba;
    8'hbb : shift_key_code = 'hbb;
    8'hbc : shift_key_code = 'hbc;
    8'hbd : shift_key_code = 'hbd;
    8'hbe : shift_key_code = 'hbe;
    8'hbf : shift_key_code = 'hbf;
    8'hc0 : shift_key_code = 'hc0;
    8'hc1 : shift_key_code = 'hc1;
    8'hc2 : shift_key_code = 'hc2;
    8'hc3 : shift_key_code = 'hc3;
    8'hc4 : shift_key_code = 'hc4;
    8'hc5 : shift_key_code = 'hc5;
    8'hc6 : shift_key_code = 'hc6;
    8'hc7 : shift_key_code = 'hc7;
    8'hc8 : shift_key_code = 'hc8;
    8'hc9 : shift_key_code = 'hc9;
    8'hca : shift_key_code = 'hca;
    8'hcb : shift_key_code = 'hcb;
    8'hcc : shift_key_code = 'hcc;
    8'hcd : shift_key_code = 'hcd;
    8'hce : shift_key_code = 'hce;
    8'hcf : shift_key_code = 'hcf;
    8'hd0 : shift_key_code = 'hd0;
    8'hd1 : shift_key_code = 'hd1;
    8'hd2 : shift_key_code = 'hd2;
    8'hd3 : shift_key_code = 'hd3;
    8'hd4 : shift_key_code = 'hd4;
    8'hd5 : shift_key_code = 'hd5;
    8'hd6 : shift_key_code = 'hd6;
    8'hd7 : shift_key_code = 'hd7;
    8'hd8 : shift_key_code = 'hd8;
    8'hd9 : shift_key_code = 'hd9;
    8'hda : shift_key_code = 'hda;
    8'hdb : shift_key_code = 'hdb;
    8'hdc : shift_key_code = 'hdc;
    8'hdd : shift_key_code = 'hdd;
    8'hde : shift_key_code = 'hde;
    8'hdf : shift_key_code = 'hdf;
    8'he0 : shift_key_code = 'he0;
    8'he1 : shift_key_code = 'he1;
    8'he2 : shift_key_code = 'he2;
    8'he3 : shift_key_code = 'he3;
    8'he4 : shift_key_code = 'he4;
    8'he5 : shift_key_code = 'he5;
    8'he6 : shift_key_code = 'he6;
    8'he7 : shift_key_code = 'he7;
    8'he8 : shift_key_code = 'he8;
    8'he9 : shift_key_code = 'he9;
    8'hea : shift_key_code = 'hea;
    8'heb : shift_key_code = 'heb;
    8'hec : shift_key_code = 'hec;
    8'hed : shift_key_code = 'hed;
    8'hee : shift_key_code = 'hee;
    8'hef : shift_key_code = 'hef;
    8'hf0 : shift_key_code = 'hf0;
    8'hf1 : shift_key_code = 'hf1;
    8'hf2 : shift_key_code = 'hf2;
    8'hf3 : shift_key_code = 'hf3;
    8'hf4 : shift_key_code = 'hf4;
    8'hf5 : shift_key_code = 'hf5;
    8'hf6 : shift_key_code = 'hf6;
    8'hf7 : shift_key_code = 'hf7;
    8'hf8 : shift_key_code = 'hf8;
    8'hf9 : shift_key_code = 'hf9;
    8'hfa : shift_key_code = 'hfa;
    8'hfb : shift_key_code = 'hfb;
    8'hfc : shift_key_code = 'hfc;
    8'hfd : shift_key_code = 'hfd;
    8'hfe : shift_key_code = 'hfe;
    default: shift_key_code = '0;
endcase
end


always @(*) begin
  ctrl_key_code = 'h00;
case (key_code)
    8'h00 : ctrl_key_code = 'h00;
    8'h01 : ctrl_key_code = 'h01;
    8'h02 : ctrl_key_code = 'h02;
    8'h03 : ctrl_key_code = 'h03;
    8'h04 : ctrl_key_code = 'h04;
    8'h05 : ctrl_key_code = 'h05;
    8'h06 : ctrl_key_code = 'h06;
    8'h07 : ctrl_key_code = 'h07;
    8'h08 : ctrl_key_code = 'h08;
    8'h09 : ctrl_key_code = 'h09;
    8'h0a : ctrl_key_code = 'h0a;
    8'h0b : ctrl_key_code = 'h0b;
    8'h0c : ctrl_key_code = 'h0c;
    8'h0d : ctrl_key_code = 'h0d;
    8'h0e : ctrl_key_code = 'h0e;
    8'h0f : ctrl_key_code = 'h0f;
    8'h10 : ctrl_key_code = 'h10;
    8'h11 : ctrl_key_code = 'h11;
    8'h12 : ctrl_key_code = 'h12;
    8'h13 : ctrl_key_code = 'h13;
    8'h14 : ctrl_key_code = 'h14;
    8'h15 : ctrl_key_code = 'h15;
    8'h16 : ctrl_key_code = 'h16;
    8'h17 : ctrl_key_code = 'h17;
    8'h18 : ctrl_key_code = 'h18;
    8'h19 : ctrl_key_code = 'h19;
    8'h1a : ctrl_key_code = 'h1a;
    8'h1b : ctrl_key_code = 'h1b;
    8'h1c : ctrl_key_code = 'h1c;
    8'h1d : ctrl_key_code = 'h1d;
    8'h1e : ctrl_key_code = 'h1e;
    8'h1f : ctrl_key_code = 'h1f;
    8'h20 : ctrl_key_code = 'h20;
    8'h21 : ctrl_key_code = 'h21;
    8'h22 : ctrl_key_code = 'h22;
    8'h23 : ctrl_key_code = 'h23;
    8'h24 : ctrl_key_code = 'h24;
    8'h25 : ctrl_key_code = 'h25;
    8'h26 : ctrl_key_code = 'h26;
    8'h27 : ctrl_key_code = 'h27;
    8'h28 : ctrl_key_code = 'h28;
    8'h29 : ctrl_key_code = 'h29;
    8'h2a : ctrl_key_code = 'h2a;
    8'h2b : ctrl_key_code = 'h2b;
    8'h2c : ctrl_key_code = 'h2c;
    8'h2d : ctrl_key_code = 'h2d;
    8'h2e : ctrl_key_code = 'h2e;
    8'h2f : ctrl_key_code = 'h2f;
    8'h30 : ctrl_key_code = 'h30;
    8'h31 : ctrl_key_code = 'h31;
    8'h32 : ctrl_key_code = 'h00;
    8'h33 : ctrl_key_code = 'h33;
    8'h34 : ctrl_key_code = 'h34;
    8'h35 : ctrl_key_code = 'h35;
    8'h36 : ctrl_key_code = 'h1f;
    8'h37 : ctrl_key_code = 'h37;
    8'h38 : ctrl_key_code = 'h38;
    8'h39 : ctrl_key_code = 'h39;
    8'h3a : ctrl_key_code = 'h3a;
    8'h3b : ctrl_key_code = 'h3b;
    8'h3c : ctrl_key_code = 'h3c;
    8'h3d : ctrl_key_code = 'h3d;
    8'h3e : ctrl_key_code = 'h3e;
    8'h3f : ctrl_key_code = 'h3f;
    8'h40 : ctrl_key_code = 'h40;
    8'h41 : ctrl_key_code = 'h01;
    8'h42 : ctrl_key_code = 'h02;
    8'h43 : ctrl_key_code = 'h03;
    8'h44 : ctrl_key_code = 'h04;
    8'h45 : ctrl_key_code = 'h05;
    8'h46 : ctrl_key_code = 'h06;
    8'h47 : ctrl_key_code = 'h07;
    8'h48 : ctrl_key_code = 'h08;
    8'h49 : ctrl_key_code = 'h09;
    8'h4a : ctrl_key_code = 'h0a;
    8'h4b : ctrl_key_code = 'h0b;
    8'h4c : ctrl_key_code = 'h0c;
    8'h4d : ctrl_key_code = 'h0d;
    8'h4e : ctrl_key_code = 'h0e;
    8'h4f : ctrl_key_code = 'h0f;
    8'h50 : ctrl_key_code = 'h10;
    8'h51 : ctrl_key_code = 'h11;
    8'h52 : ctrl_key_code = 'h12;
    8'h53 : ctrl_key_code = 'h13;
    8'h54 : ctrl_key_code = 'h14;
    8'h55 : ctrl_key_code = 'h15;
    8'h56 : ctrl_key_code = 'h16;
    8'h57 : ctrl_key_code = 'h17;
    8'h58 : ctrl_key_code = 'h18;
    8'h59 : ctrl_key_code = 'h19;
    8'h5a : ctrl_key_code = 'h1a;
    8'h5b : ctrl_key_code = 'h1b;
    8'h5c : ctrl_key_code = 'h1c;
    8'h5d : ctrl_key_code = 'h1d;
    8'h5e : ctrl_key_code = 'h1e;
    8'h5f : ctrl_key_code = 'h5f;
    8'h60 : ctrl_key_code = 'h60;
    8'h61 : ctrl_key_code = 'h01;
    8'h62 : ctrl_key_code = 'h02;
    8'h63 : ctrl_key_code = 'h03;
    8'h64 : ctrl_key_code = 'h04;
    8'h65 : ctrl_key_code = 'h05;
    8'h66 : ctrl_key_code = 'h06;
    8'h67 : ctrl_key_code = 'h07;
    8'h68 : ctrl_key_code = 'h08;
    8'h69 : ctrl_key_code = 'h09;
    8'h6a : ctrl_key_code = 'h0a;
    8'h6b : ctrl_key_code = 'h0b;
    8'h6c : ctrl_key_code = 'h0c;
    8'h6d : ctrl_key_code = 'h0d;
    8'h6e : ctrl_key_code = 'h0e;
    8'h6f : ctrl_key_code = 'h0f;
    8'h70 : ctrl_key_code = 'h10;
    8'h71 : ctrl_key_code = 'h11;
    8'h72 : ctrl_key_code = 'h12;
    8'h73 : ctrl_key_code = 'h13;
    8'h74 : ctrl_key_code = 'h14;
    8'h75 : ctrl_key_code = 'h15;
    8'h76 : ctrl_key_code = 'h16;
    8'h77 : ctrl_key_code = 'h17;
    8'h78 : ctrl_key_code = 'h18;
    8'h79 : ctrl_key_code = 'h19;
    8'h7a : ctrl_key_code = 'h1a;
    8'h7b : ctrl_key_code = 'h1b;
    8'h7c : ctrl_key_code = 'h1c;
    8'h7d : ctrl_key_code = 'h1d;
    8'h7e : ctrl_key_code = 'h1e;
    8'h7f : ctrl_key_code = 'h7f;
    8'h80 : ctrl_key_code = 'h80;
    8'h81 : ctrl_key_code = 'h81;
    8'h82 : ctrl_key_code = 'h82;
    8'h83 : ctrl_key_code = 'h83;
    8'h84 : ctrl_key_code = 'h84;
    8'h85 : ctrl_key_code = 'h85;
    8'h86 : ctrl_key_code = 'h86;
    8'h87 : ctrl_key_code = 'h87;
    8'h88 : ctrl_key_code = 'h88;
    8'h89 : ctrl_key_code = 'h89;
    8'h8a : ctrl_key_code = 'h8a;
    8'h8b : ctrl_key_code = 'h8b;
    8'h8c : ctrl_key_code = 'h8c;
    8'h8d : ctrl_key_code = 'h8d;
    8'h8e : ctrl_key_code = 'h8e;
    8'h8f : ctrl_key_code = 'h8f;
    8'h90 : ctrl_key_code = 'h90;
    8'h91 : ctrl_key_code = 'h91;
    8'h92 : ctrl_key_code = 'h92;
    8'h93 : ctrl_key_code = 'h93;
    8'h94 : ctrl_key_code = 'h94;
    8'h95 : ctrl_key_code = 'h95;
    8'h96 : ctrl_key_code = 'h96;
    8'h97 : ctrl_key_code = 'h7f;
    8'h98 : ctrl_key_code = 'h98;
    8'h99 : ctrl_key_code = 'h99;
    8'h9a : ctrl_key_code = 'h9a;
    8'h9b : ctrl_key_code = 'h9b;
    8'h9c : ctrl_key_code = 'h9c;
    8'h9d : ctrl_key_code = 'h9d;
    8'h9e : ctrl_key_code = 'h9e;
    8'h9f : ctrl_key_code = 'h9f;
    8'ha0 : ctrl_key_code = 'ha4;
    8'ha1 : ctrl_key_code = 'ha5;
    8'ha2 : ctrl_key_code = 'ha6;
    8'ha3 : ctrl_key_code = 'ha7;
    8'ha4 : ctrl_key_code = 'ha4;
    8'ha5 : ctrl_key_code = 'ha5;
    8'ha6 : ctrl_key_code = 'ha6;
    8'ha7 : ctrl_key_code = 'ha7;
    8'ha8 : ctrl_key_code = 'ha8;
    8'ha9 : ctrl_key_code = 'ha9;
    8'haa : ctrl_key_code = 'haa;
    8'hab : ctrl_key_code = 'hab;
    8'hac : ctrl_key_code = 'hac;
    8'had : ctrl_key_code = 'had;
    8'hae : ctrl_key_code = 'hae;
    8'haf : ctrl_key_code = 'haf;
    8'hb0 : ctrl_key_code = 'hb0;
    8'hb1 : ctrl_key_code = 'hb1;
    8'hb2 : ctrl_key_code = 'hb2;
    8'hb3 : ctrl_key_code = 'hb3;
    8'hb4 : ctrl_key_code = 'hb4;
    8'hb5 : ctrl_key_code = 'hb5;
    8'hb6 : ctrl_key_code = 'hb6;
    8'hb7 : ctrl_key_code = 'hb7;
    8'hb8 : ctrl_key_code = 'hb8;
    8'hb9 : ctrl_key_code = 'hb9;
    8'hba : ctrl_key_code = 'hba;
    8'hbb : ctrl_key_code = 'hbb;
    8'hbc : ctrl_key_code = 'hbc;
    8'hbd : ctrl_key_code = 'hbd;
    8'hbe : ctrl_key_code = 'hbe;
    8'hbf : ctrl_key_code = 'hbf;
    8'hc0 : ctrl_key_code = 'hc0;
    8'hc1 : ctrl_key_code = 'hc1;
    8'hc2 : ctrl_key_code = 'hc2;
    8'hc3 : ctrl_key_code = 'hc3;
    8'hc4 : ctrl_key_code = 'hc4;
    8'hc5 : ctrl_key_code = 'hc5;
    8'hc6 : ctrl_key_code = 'hc6;
    8'hc7 : ctrl_key_code = 'hc7;
    8'hc8 : ctrl_key_code = 'hc8;
    8'hc9 : ctrl_key_code = 'hc9;
    8'hca : ctrl_key_code = 'hca;
    8'hcb : ctrl_key_code = 'hcb;
    8'hcc : ctrl_key_code = 'hcc;
    8'hcd : ctrl_key_code = 'hcd;
    8'hce : ctrl_key_code = 'hce;
    8'hcf : ctrl_key_code = 'hcf;
    8'hd0 : ctrl_key_code = 'hd0;
    8'hd1 : ctrl_key_code = 'hd1;
    8'hd2 : ctrl_key_code = 'hd2;
    8'hd3 : ctrl_key_code = 'hd3;
    8'hd4 : ctrl_key_code = 'hd4;
    8'hd5 : ctrl_key_code = 'hd5;
    8'hd6 : ctrl_key_code = 'hd6;
    8'hd7 : ctrl_key_code = 'hd7;
    8'hd8 : ctrl_key_code = 'hd8;
    8'hd9 : ctrl_key_code = 'hd9;
    8'hda : ctrl_key_code = 'hda;
    8'hdb : ctrl_key_code = 'hdb;
    8'hdc : ctrl_key_code = 'hdc;
    8'hdd : ctrl_key_code = 'hdd;
    8'hde : ctrl_key_code = 'hde;
    8'hdf : ctrl_key_code = 'hdf;
    8'he0 : ctrl_key_code = 'he0;
    8'he1 : ctrl_key_code = 'he1;
    8'he2 : ctrl_key_code = 'he2;
    8'he3 : ctrl_key_code = 'he3;
    8'he4 : ctrl_key_code = 'he4;
    8'he5 : ctrl_key_code = 'he5;
    8'he6 : ctrl_key_code = 'he6;
    8'he7 : ctrl_key_code = 'he7;
    8'he8 : ctrl_key_code = 'he8;
    8'he9 : ctrl_key_code = 'he9;
    8'hea : ctrl_key_code = 'hea;
    8'heb : ctrl_key_code = 'heb;
    8'hec : ctrl_key_code = 'hec;
    8'hed : ctrl_key_code = 'hed;
    8'hee : ctrl_key_code = 'hee;
    8'hef : ctrl_key_code = 'hef;
    8'hf0 : ctrl_key_code = 'hf0;
    8'hf1 : ctrl_key_code = 'hf1;
    8'hf2 : ctrl_key_code = 'hf2;
    8'hf3 : ctrl_key_code = 'hf3;
    8'hf4 : ctrl_key_code = 'hf4;
    8'hf5 : ctrl_key_code = 'hf5;
    8'hf6 : ctrl_key_code = 'hf6;
    8'hf7 : ctrl_key_code = 'hf7;
    8'hf8 : ctrl_key_code = 'hf8;
    8'hf9 : ctrl_key_code = 'hf9;
    8'hfa : ctrl_key_code = 'hfa;
    8'hfb : ctrl_key_code = 'hfb;
    8'hfc : ctrl_key_code = 'hfc;
    8'hfd : ctrl_key_code = 'hfd;
    8'hfe : ctrl_key_code = 'hfe;
    default: ctrl_key_code = 'h00;
endcase
end

endmodule
