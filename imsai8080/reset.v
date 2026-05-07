/*
RESET 

sets the program counter back to 0 000 000 000 000 000.
Provides a rapid way to get back to the 1st step of a program.

*/

module reset(
  input clk,
  input reset,
  input rd,
  input reset_in,
  output reg [7:0] data_out,
  output reset_latch
);

  reg [2:0] state = 3'b000;
  reg prev_rd = 1'b0;
  reg rs_lt = 1'b0;
  
  always @(posedge clk)
    begin
      if (reset)
      begin
		  rs_lt <= 1'b0;
		end  
      else if (reset_in)
      begin
		  state <= 3'b000;
        rs_lt <= 1'b1;
		end  
      else
		begin
   	  if (rd && prev_rd==1'b0)
		  begin
          case (state)
            3'b000 : begin
              rs_lt <= 1'b1;
              state <= 3'b001;
				end
            3'b001 : begin
              data_out <= 8'b11000011; // JMP
              state <= 3'b010;
            end
            3'b010 : begin
              data_out <= 8'h00;
              state <= 3'b011;
            end
            3'b011 : begin
              data_out <= 8'h00;
              state <= 3'b100;
            end
            3'b100 : begin						
              state <= 3'b100;
   		     rs_lt <= 1'b0;
            end
          endcase
		  end
		  prev_rd = rd;  
      end
    end
	 assign reset_latch = rs_lt;
endmodule