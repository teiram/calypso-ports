/*
DEP 

The Deposit circuit places a write pulse on the MWRITE line 
and enables the switches SA O through SA 7. This causes the 
contents of these ei_ght switches to be stored in the memory 
location currently addressed. 

*/

module deposit(
  input clk,
  input reset,
  input deposit,
  input [7:0] data_sw,
  output reg [7:0] data_out,
  output deposit_latch
);

  reg [2:0] state = 3'b000;
  reg de_lt = 1'b0;
  
  always @(posedge clk)
    begin
      if (reset)
      begin
		  de_lt <= 1'b0;
		end  
      else if (deposit)
      begin
		  state <= 3'b000;
        de_lt <= 1'b1;
		end  
      else
		begin
		case (state)
			3'b000 : begin
			  de_lt <= 1'b1;
			  state <= 3'b001;
		   end
			3'b001 : begin
			  data_out <= data_sw;
			  state <= 3'b010;
			end
			3'b010 : begin
			  state <= 3'b010;
			  de_lt <= 1'b0;
			end
		endcase
		end
    end
	 assign deposit_latch = de_lt;
endmodule
