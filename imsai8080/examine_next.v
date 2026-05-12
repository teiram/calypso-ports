/*
    EXM NXT
    Examine Next operates in the same manner as Examine, except 
    a NOP is strobed onto the data lines through 4 gates of IC D 
    and 4 gates of ICE. This causes the processor to step the program counter. 
*/

module examine_next(
    input clk,
    input reset,
    input sync,
    input examine,
    output reg [7:0] data_out,
    output reg ce = 1'b0
);

    always @(posedge clk) begin
        reg prev_sync = 1'b0;
        prev_sync <= sync;
        if (reset) begin
            ce <= 1'b0;
            prev_sync <= 1'b0;
        end
        else if (examine) begin
            ce <= 1'b1;
            data_out <= 8'd0; // NOP
        end
        else begin
            if (~prev_sync & sync) begin
                if (ce == 1'b1) begin
                    ce <= 1'b0;
                end
            end
        end
    end
    
endmodule
