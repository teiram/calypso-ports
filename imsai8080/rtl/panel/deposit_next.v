/*

DEP NXT

The Deposit Next circuit simply causes a sequential operation 
of the EXM NXT and the DEP circuits.

*/

module deposit_next(
    input clk,
    input reset,
    input sync,
    input deposit,
    input [7:0] data_sw,
    output reg [7:0] data_out,
    output reg we = 1'b0,
    output reg ce = 1'b0
);

    reg [1:0] state = 2'b00;
    reg prev_sync = 1'b0;
    
    always @(posedge clk) begin
        if (reset) begin
            we <= 1'b0;
            ce <= 1'b0;
            state <= 2'b00;
        end
        else if (deposit) begin
            state <= 2'b01;
            ce <= 1'b1;
            data_out <= 8'd0; // NOP
        end
        else begin
            if (state == 2'b01) begin
                if (~prev_sync & sync) begin
                    ce <= 1'b0;
                    we <= 1'b1;
                    state <= 2'b10;
                    data_out <= data_sw;
                end
            end else if (state == 2'b10) begin
                ce <= 1'b0;
                we <= 1'b0;
                state <= 2'b00;
            end 
            prev_sync <= sync;
        end
    end
    
endmodule
