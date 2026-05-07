/*
EXM NXT 
Examine Next operates in the same manner as Examine, except 
a NOP is strobed onto the data lines through 4 gates of IC D 
and 4 gates of ICE. This causes the processor to step the program counter. 

*/

module examine_next(
  input clk,
  input reset,
  input rd,
  input examine,
  output reg [7:0] data_out,
  output examine_latch
);

  reg [2:0] state = 3'b000;
  reg prev_rd = 1'b0;
  reg en_lt = 1'b0;
  
  always @(posedge clk)
    begin
      if (reset) begin 
        en_lt <= 1'b0; 
      end  
      else if (examine) 
      begin 
        state <= 3'b000; 
        en_lt <= 1'b1; 
      end
      else begin
     	  if (rd && prev_rd==1'b0)
		    begin
          case (state)
          3'b000 : begin
              en_lt <= 1'b1;
              state <= 3'b101;
              data_out <= 8'b00000000; // NOP
				    end
          3'b101 : begin						
              state <= 3'b101;
     		      en_lt <= 1'b0;
            end
          endcase
		    end
		  prev_rd = rd;  
      end
    end
	  assign examine_latch = en_lt;
endmodule
