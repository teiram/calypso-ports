/*

DEP NXT 

The Deposit Next circuit simply causes a sequential operation 
of the EXM NXT and the DEP circuits. 

*/

module deposit_next(
  input clk,
  input reset,
  input rd,
  input deposit,
  input [7:0] data_sw,
  output reg [7:0] deposit_out,
  output deposit_latch,
  output reg [7:0] data_out,
  output examine_latch
);

  reg [2:0] state = 3'b000;
  reg prev_rd = 1'b0;
  reg de_lt = 1'b0;
  reg en_lt = 1'b0;
  
  always @(posedge clk)
    begin
      if (reset)
      begin
		    de_lt <= 1'b0;
		    en_lt <= 1'b0;
		  end  
      else if (deposit)
      begin
		    state <= 3'b000;
        de_lt <= 1'b0;
        en_lt <= 1'b1;
		  end  
      else
		begin
   	  if (rd && prev_rd==1'b0 || de_lt == 1'b1)
		  begin
			case (state)
            3'b000 : begin
              en_lt <= 1'b1;
   		        de_lt <= 1'b1;
              state <= 3'b111;
              data_out <= 8'b00000000; // NOP
				      deposit_out <= data_sw;
				    end
				    3'b111 : begin
				      state <= 3'b111;
   		        en_lt <= 1'b0;
				      de_lt <= 1'b0;
				    end
			endcase
		  end
		  prev_rd = rd;  
		end
    end
	 assign examine_latch = en_lt;
	 assign deposit_latch = de_lt;
endmodule
