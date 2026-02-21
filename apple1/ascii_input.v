// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
// Description: ascii file load interface
//
// Author.....: Alan Steremberg
// Date.......: 13-8-2019
//
module clock_divider(
    input clock_in,
    output clock_out
);
    reg[27:0] counter = 28'd0;
    parameter DIVISOR = 28'd2;
    // The frequency of the output clk_out
    //  = The frequency of the input clk_in divided by DIVISOR
    // For example: Fclk_in = 50Mhz, if you want to get 1Hz signal to blink LEDs
    // You will modify the DIVISOR parameter value to 28'd50.000.000
    // Then the frequency of the output clk_out = 50Mhz/50.000.000 = 1Hz
    always @(posedge clock_in) begin
        counter <= counter + 28'd1;
        if (counter >= (DIVISOR - 1))
            counter <= 28'd0;
    end
    assign clock_out = (counter < DIVISOR / 2) ? 1'b0 : 1'b1;

endmodule

module ascii_input(
    input       clk25,      // 25MHz clock
    input       rst,        // active high reset

    // I/O interface to keyboard
    input       key_clk,    // clock input from keyboard / device
    
    input ioctl_download,
    input [7:0] ioctl_dout,
    input [15:0] ioctl_addr,
    input ioctl_wr,

    output [15:0] sdram_addr,
    output [7:0] sdram_din,
    input [7:0] sdram_dout,
    output sdram_rd,
    output sdram_wr,
    input sdram_ready,
    
    // I/O interface to computer
    input       cs,         // chip select, active high
    input       address,    // =0 RX buffer, =1 RX status
    output reg [7:0] dout,   // 8-bit output bus.
    output data_ready
);

    wire read_clk;
    clock_divider #(.DIVISOR(40000)) cdiv(
        .clock_in(clk25),
        .clock_out(read_clk)
    );

    assign sdram_addr = ioctl_download ? ioctl_addr : read_addr;
    assign sdram_wr = ioctl_download ? ioctl_wr : 1'b0;
    assign sdram_rd = ioctl_download ? 1'b0 : read_en;
    assign sdram_din = ioctl_wr ? ioctl_dout : 8'd0;
    
    reg [15:0] stream_last_addr = 16'b0;
    reg [15:0] read_addr = 16'd0;
    reg in_dl = 1'b0;

    wire data_available = in_dl & ~ioctl_download;
    
    assign data_ready = in_dl & ~ioctl_download;
    
    reg read_clk_last;    // previous clock state (in clk25 domain)
    
    // keyboard translation signals
    reg [6:0] ascii /* synthesis keep */;       // ASCII code of received character
    reg ascii_rdy /* synthesis keep */;         // new ASCII character received
    
    reg read_en;
    reg [2:0] cur_state;
    reg [2:0] next_state;

    always @(posedge clk25 or posedge rst) begin
        if (rst) begin
            read_clk_last <= 1'b0;
            ascii_rdy <= 1'b0;
            read_addr <= 16'd0;
            read_en <= 1'b0;
        end else begin
            read_clk_last <= read_clk;
            if (read_clk_last & ~read_clk) begin
                if (data_available && ~read_en && read_addr <= stream_last_addr) begin
                    read_en <= 1'b1;
                end
            end
            
            if (data_available & read_en & sdram_ready) begin
                ascii <= sdram_dout[6:0] == 7'h0a ? 7'h0d : sdram_dout[6:0];
                ascii_rdy <= 1;
                read_addr <= read_addr + 1'b1;
                read_en <= 1'b0;
            end


            if (ioctl_download) begin
                stream_last_addr <= ioctl_addr;
                in_dl <= 1'b1;
                read_addr <= 16'd0;
            end else begin
                if (in_dl && read_addr > stream_last_addr) begin
                    in_dl  <= 1'b0;
                end
            end

            // handle I/O from CPU
            if (cs == 1'b1) begin
                if (address == 1'b0) begin
                    // RX buffer address
                    dout <= {1'b1, ascii};
                    ascii_rdy <= 1'b0;
                end else begin
                    // RX status register
                    dout <= {ascii_rdy, 7'b0};
                end
            end
        end
    end

endmodule

