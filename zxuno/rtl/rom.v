`timescale 1ns / 1ps

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 04:12:52 2014-02-09 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.

module rom (
    input wire clk,
    input wire [13:0] a,
    output reg [7:0] dout
    );

`include "config.vh"

`ifdef LOAD_ROM_FROM_FLASH_OPTION
   reg [7:0] mem[0:16383];
   initial begin  
      $readmemh ("bootloader_to_bios_and_easter_egg.hex", mem, 0);      
   end
`else
   reg [7:0] mem [0:9215];
   initial begin  
      $readmemh (`BOOTLOADER_STANDARD, mem, 0);
      $readmemh (`DEFAULT_DIVMMC_ROM, mem, 512);
   end
`endif

   always @(posedge clk) dout <= mem[a];
endmodule
