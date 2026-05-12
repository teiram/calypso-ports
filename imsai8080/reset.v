/*
    RESET

    sets the program counter back to 0 000 000 000 000 000.
    Provides a rapid way to get back to the 1st step of a program.

*/

module reset(
    input clk,
    input reset,
    input sync,
    input reset_in,
    output reg [7:0] data_out,
    output reg ce
);

    reg [1:0] state = 2'b00;

    always @(posedge clk) begin
        reg prev_sync = 1'b0;
        prev_sync <= sync;
        
        if (reset) begin
            state <= 2'b00;
            ce <= 1'b0;
        end
        else if (reset_in) begin
            state <= 2'b01;
            ce <= 1'b1;
            data_out <= 8'hc3; // JMP
        end
        else if (~prev_sync & sync) begin
            case (state)
                2'b01 : begin
                    ce <= 1'b1;
                    state <= 2'b10;
                    data_out <= 8'h00;
                end
                2'b10 : begin
                    ce <= 1'b1;
                    data_out <= 8'h00;
                    state <= 2'b11;
                end
                2'b11: begin
                    ce <= 1'b0;
                end
            endcase
        end
    end

endmodule