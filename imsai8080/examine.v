/*
EXM 
The Examine circuit consists of a dual single shot (IC L) for debounce, 
a 2-bit counter (IC J), the top 3 sets of 7405 1 s on schematic 880-106 
(!C's A, B, C and 2 gates of D), and some gating. 

When the Examine switch is depressed the counter (IC J) is started. 
On the first count, a jump instruction (JMP 303) is strobed directly 
onto the bi­directional data bus at the processor. This is accomplished 
by enabling 2 gates of ICC and 2 gates of IC D through the output pin 6 
of one gate of IC T. These open coll ecter gates then pull down data 
lines 02, 03, 04 and D5. This puts a 303 on the data bus, which is the 
code for a JMP.

On the second count, the settings of switches SAO through SA 7 are 
strobed onto the data bus iri a similar manner to the JMP instruction 
through IC A and 2 gates of B. This provides the first byte of the JMP 
address. 

The third count strobes the settings for switches SA 8 through SA 15 
onto the bus. This provides the second byte of the JMP address. The 
processor will then execute the JMP to the location set on the 
switches SAO through SA 15, allowing the examination of the contents 
of that particular memory location. 

The fourth count:resets the counter and pulls the EXM line low, which 
in turn pulls PRDY low and stops the processor. 
*/

module examine(
  input clk,
  input reset,
  input rd,
  input examine,
  input [7:0] lo_addr,
  input [7:0] hi_addr,
  output reg [7:0] data_out,
  output examine_latch
);

  reg [2:0] state = 3'b000;
  reg prev_rd = 1'b0;
  reg en_lt = 1'b0;
  
  always @(posedge clk)
    begin
      if (reset)
      begin
		  en_lt <= 1'b0;
		end  
      else if (examine)
      begin
		  state <= 3'b000;
        en_lt <= 1'b1;
		end  
      else
		begin
   	  if (rd && prev_rd==1'b0)
		  begin
          case (state)
            3'b000 : begin
              en_lt <= 1'b1;
              state <= 3'b001;
				end
            3'b001 : begin
              data_out <= 8'b11000011; // JMP
              state <= 3'b010;
            end
            3'b010 : begin
              data_out <= lo_addr;
              state <= 3'b011;
            end
            3'b011 : begin
              data_out <= hi_addr;
              state <= 3'b100;
            end
            3'b100 : begin						
              state <= 3'b100;
   		     en_lt <= 1'b0;
            end
          endcase
		  end
		  prev_rd = rd;  
      end
    end
	 assign examine_latch = en_lt;
endmodule