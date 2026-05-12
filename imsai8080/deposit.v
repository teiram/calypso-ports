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
    output reg we = 1'b0
);

    reg [1:0] state = 2'b00;
  
    always @(posedge clk) begin
        if (reset) begin
            state <= 2'b00;
        end
        else if (deposit) begin
            state <= 2'b01;
            data_out <= data_sw;
            we <= 1'b1;
        end
        else begin
            if (state == 2'b01) begin
                state <= 2'b00;
                we <= 1'b0;
            end
        end
    end

endmodule
