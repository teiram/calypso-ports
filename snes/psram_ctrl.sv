//============================================================================
//  ESP-PSRAM64H (8MB, QSPI) controller for the Calypso powerpack add-on
//
//  Derived from psram64.sv by Manuel Teira (teiram/calypso-ports), keeping
//  its bus timing (command/address/wait/data cycle counts and negedge driven
//  I/O), which is the one proven on the board.
//
//  Changes for the SNES port (Shaeon / Carlos Palmero):
//  - Toggle based req/ack handshake. The requester lives in a related clock
//    domain (same PLL), so no synchronizers are needed: Quartus times it.
//  - On startup a QPI-mode RESET is sent before the SPI-mode RESET. If a
//    previous core left the chip in QPI mode (reconfiguring the FPGA does not
//    power cycle the PSRAM) the SPI-mode commands alone would not be
//    understood. In SPI mode the 2-clock QPI command is just ignored.
//  - CE# is kept high for at least CE_HIGH cycles between operations.
//  - Write data is sampled late (6 cycles after the command starts), so the
//    requester can issue a write before its data is final.
//
//  - Selectable read sampling point (rd_delay, half clock steps), so the
//    data window can be centred at higher clock rates than the proven ones
//    (42.7 MHz in the SVI-328, 72 MHz in the IMSAI 8080).
//
//  Timing at 106.667 MHz (9.375 ns period), counted from the clock edge where
//  the request is seen:
//    read : 19-21 cycles until dout/ack (178-197 ns, depends on rd_delay)
//    write: 12 cycles until ack         (112 ns)
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//============================================================================

module psram_ctrl #(
    parameter MHZ = 107,          // clock frequency, used for the power-up delay
    parameter CE_HIGH = 3         // minimum CE# high cycles between operations
)(
    input             clk,        // controller clock, also drives PSRAM_CLK
    input             rst_n,      // PLL locked

    inout       [3:0] PSRAM_SIO,
    output reg        PSRAM_CE = 1'b1,

    input             req,        // toggle: new operation requested
    input             we,         // 1 = write, 0 = read
    input      [22:0] addr,       // byte address
    input       [7:0] din,
    output reg  [7:0] dout,
    output reg        ack = 1'b0, // toggle: equals req when the operation is done
    output reg        ready = 1'b0, // initialization finished

    // Read sampling point, in half clock periods after the proven one
    // (0 = same as psram64.sv). Compensates the round trip delay
    // FPGA -> PSRAM -> FPGA, which at 106 MHz is about one clock period.
    // Changing it costs nothing, so it is wired to the OSD for tuning.
    input       [1:0] rd_delay
);

localparam [15:0] STARTUP_CYCLES = MHZ * 160;   // >150 us after power-up

localparam CMD_RESET_ENABLE    = 8'h66;
localparam CMD_RESET           = 8'h99;
localparam CMD_ENTER_QUAD_MODE = 8'h35;
localparam CMD_QUAD_WRITE      = 8'h38;
localparam CMD_FAST_READ_QUAD  = 8'heb;

typedef enum bit [3:0] {
    ST_WAIT_LOCK,
    ST_STARTUP,
    ST_QPI_RESET_ENABLE,
    ST_QPI_RESET,
    ST_RESET_ENABLE,
    ST_RESET,
    ST_ENTER_QUAD,
    ST_IDLE,
    ST_READ,
    ST_WRITE,
    ST_GAP
} state_t;

state_t     state = ST_WAIT_LOCK;
reg  [15:0] wait_cnt;
reg   [4:0] cnt;
reg   [7:0] cmd;
reg  [23:0] addr_sh;
reg   [7:0] din_l;
reg         req_l = 1'b0;

// SIO output registers, one enable per line (only SIO0 is driven in SPI mode)
reg   [3:0] sio_o;
reg   [3:0] sio_oe = 4'b0000;
assign PSRAM_SIO[0] = sio_oe[0] ? sio_o[0] : 1'bZ;
assign PSRAM_SIO[1] = sio_oe[1] ? sio_o[1] : 1'bZ;
assign PSRAM_SIO[2] = sio_oe[2] ? sio_o[2] : 1'bZ;
assign PSRAM_SIO[3] = sio_oe[3] ? sio_o[3] : 1'bZ;

// input data sampled on the rising edge, used for the odd rd_delay values
reg   [3:0] sio_p;
always @(posedge clk) sio_p <= PSRAM_SIO;

// first data nibble is taken at cnt == rd_first, from the pin (even delay)
// or from the half period older rising edge sample (odd delay)
wire  [4:0] rd_first = 5'd15 + {3'd0, rd_delay[1]} + {4'd0, rd_delay[0]};
wire  [3:0] rd_nib   = rd_delay[0] ? sio_p : PSRAM_SIO;

// Everything runs on the falling edge: the PSRAM samples on the rising edge
// of PSRAM_CLK (= clk), so outputs get half a period of setup and hold, and
// input data is sampled in the middle of the valid window.
always @(negedge clk) begin
    if (!rst_n) begin
        state     <= ST_WAIT_LOCK;
        PSRAM_CE  <= 1'b1;
        sio_oe <= 4'b0000;
        ready     <= 1'b0;
    end else begin
        case (state)

        ST_WAIT_LOCK: begin
            wait_cnt <= STARTUP_CYCLES;
            state    <= ST_STARTUP;
        end

        ST_STARTUP: begin
            PSRAM_CE  <= 1'b1;
            sio_oe <= 4'b0000;
            if (wait_cnt == 16'd0) begin
                state <= ST_QPI_RESET_ENABLE;
                cnt   <= 5'd0;
                cmd   <= CMD_RESET_ENABLE;
            end else
                wait_cnt <= wait_cnt - 1'd1;
        end

        // QPI format commands: 2 cycles, 4 bits per cycle
        ST_QPI_RESET_ENABLE, ST_QPI_RESET: begin
            cnt <= cnt + 1'd1;
            case (cnt)
            5'd0: begin PSRAM_CE <= 1'b0; sio_oe <= 4'b1111; sio_o <= cmd[7:4]; end
            5'd1: begin PSRAM_CE <= 1'b0; sio_oe <= 4'b1111; sio_o <= cmd[3:0]; end
            5'd2: begin PSRAM_CE <= 1'b1; sio_oe <= 4'b0000;  end
            5'd7: begin
                cnt <= 5'd0;
                if (state == ST_QPI_RESET_ENABLE) begin
                    state <= ST_QPI_RESET;
                    cmd   <= CMD_RESET;
                end else begin
                    state <= ST_RESET_ENABLE;
                    cmd   <= CMD_RESET_ENABLE;
                end
            end
            default: ;
            endcase
        end

        // SPI format commands: 8 cycles, 1 bit per cycle on SIO0
        ST_RESET_ENABLE, ST_RESET, ST_ENTER_QUAD: begin
            cnt <= cnt + 1'd1;
            if (cnt < 5'd8) begin
                PSRAM_CE     <= 1'b0;
                sio_oe <= 4'b0001;
                sio_o  <= {3'b000, cmd[7]};
                cmd <= {cmd[6:0], 1'b0};
            end else if (cnt == 5'd8) begin
                PSRAM_CE  <= 1'b1;
                sio_oe <= 4'b0000;
            end else if (cnt == 5'd15) begin
                cnt <= 5'd0;
                case (state)
                ST_RESET_ENABLE: begin state <= ST_RESET;      cmd <= CMD_RESET;           end
                ST_RESET:        begin state <= ST_ENTER_QUAD; cmd <= CMD_ENTER_QUAD_MODE; end
                default:         begin state <= ST_IDLE;       ready <= 1'b1;              end
                endcase
            end
        end

        ST_IDLE: begin
            PSRAM_CE  <= 1'b1;
            sio_oe <= 4'b0000;
            if (req != req_l) begin
                req_l   <= req;
                addr_sh <= {1'b0, addr};
                cnt     <= 5'd1;
                // first command nibble goes out right away
                PSRAM_CE  <= 1'b0;
                begin sio_oe <= 4'b1111; sio_o <= we ? CMD_QUAD_WRITE[7:4] : CMD_FAST_READ_QUAD[7:4]; end
                cmd       <= we ? CMD_QUAD_WRITE : CMD_FAST_READ_QUAD;
                state     <= we ? ST_WRITE : ST_READ;
            end
        end

        // cnt: 1 = cmd low nibble, 2..7 = address, 8.. = wait,
        //      rd_first, rd_first+1 = data, then CE# high
        ST_READ: begin
            cnt <= cnt + 1'd1;
            if (cnt == 5'd1) begin
                begin sio_oe <= 4'b1111; sio_o <= cmd[3:0]; end
            end else if (cnt < 5'd8) begin
                begin sio_oe <= 4'b1111; sio_o <= addr_sh[23:20]; end
                addr_sh   <= {addr_sh[19:0], 4'd0};
            end else if (cnt < rd_first) begin
                sio_oe <= 4'b0000;
            end else if (cnt == rd_first) begin
                dout[7:4] <= rd_nib;
            end else if (cnt == rd_first + 1'd1) begin
                dout[3:0] <= rd_nib;
                ack       <= req_l;
            end else begin
                PSRAM_CE <= 1'b1;
                cnt      <= 5'd0;
                state    <= ST_GAP;
            end
        end

        // cnt: 1 = cmd low nibble, 2..7 = address, 8,9 = data, 10 = CE# high
        // din is taken at cnt 7, not with the request: the requester may
        // still update it (see snes_psram_bus.sv, DMA writes)
        ST_WRITE: begin
            cnt <= cnt + 1'd1;
            if (cnt == 5'd7) din_l <= din;
            if (cnt == 5'd1) begin
                begin sio_oe <= 4'b1111; sio_o <= cmd[3:0]; end
            end else if (cnt < 5'd8) begin
                begin sio_oe <= 4'b1111; sio_o <= addr_sh[23:20]; end
                addr_sh   <= {addr_sh[19:0], 4'd0};
            end else if (cnt == 5'd8) begin
                begin sio_oe <= 4'b1111; sio_o <= din_l[7:4]; end
            end else if (cnt == 5'd9) begin
                begin sio_oe <= 4'b1111; sio_o <= din_l[3:0]; end
            end else begin
                PSRAM_CE  <= 1'b1;
                sio_oe <= 4'b0000;
                ack       <= req_l;
                cnt       <= 5'd0;
                state     <= ST_GAP;
            end
        end

        // keep CE# high before the next operation (tCPH)
        ST_GAP: begin
            PSRAM_CE  <= 1'b1;
            sio_oe <= 4'b0000;
            cnt <= cnt + 1'd1;
            if (cnt == CE_HIGH - 2) state <= ST_IDLE;
        end

        default: state <= ST_WAIT_LOCK;
        endcase
    end
end

endmodule
