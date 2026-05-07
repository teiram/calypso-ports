module frequency_divider(
  input	 clk_in,
  input	 rst,
  output clk_out
);

  parameter	N = 2;      // divide factor
  parameter	WIDTH = 6;  // counter bits
  
  reg clk_pos;
  reg [WIDTH:0] cnt_pos;
  always @(posedge clk_in or posedge rst)
    begin
      if(rst)
        begin
          cnt_pos		<=	10'd0;
          clk_pos	<=	1'd0;
        end
      else
        begin
          if(N==2)
            clk_pos <= ~clk_pos;
          else
            if(cnt_pos <= ((N-1'd1)/2)- 1'd1)
              begin
                cnt_pos <= cnt_pos + 1'd1;
                clk_pos <= 1'd1;
              end
          else
            if(cnt_pos <= (N-2'd2))
              begin
                cnt_pos <= cnt_pos + 1'd1;
                clk_pos <= 1'd0;
              end
          else
            begin
              cnt_pos <= 10'd0;
              clk_pos <= 1'd0;
            end
        end
    end


  reg clk_neg;
  reg [WIDTH:0] cnt_neg;
  always @(negedge clk_in or posedge rst)
    begin
      if(rst)
        begin
          cnt_neg <= 10'd0;
          clk_neg <= 1'd0;
        end
      else
        begin
          if(N==2)
            clk_neg <= ~clk_neg;
          else
            if(cnt_neg <= ((N-1'd1)/2)- 1'd1)
              begin
                cnt_neg <= cnt_neg + 1'd1;
                clk_neg <= 1'd1;
              end
          else
            if(cnt_neg <= (N-2'd2))
              begin
                cnt_neg <= cnt_neg + 1'd1;
                clk_neg <= 1'd0;
              end
          else
            begin
              cnt_neg <= 10'd0;
              clk_neg <= 1'd0;
            end
        end
    end	

  assign	clk_out = clk_pos | clk_neg;	

endmodule
