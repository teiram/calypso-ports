/*
SENSE SWITCHES 

input data from sense switches

port 0xFF

used to configure various I/O boards 
- 2SIO serial board
- 

also to play killbits game

use 0xFD 11 111 101 for 4k basic

*/

module sense_switch(
  input clk,
  input rd,
  input [7:0] switch_settings,
  output reg [7:0] data_out
);
  
  always @(posedge clk)
    begin
	  if (rd)
	  begin
		 data_out <= switch_settings;
	  end
    end
endmodule