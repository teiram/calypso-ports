/*
    EXM
    
    The Examine circuit consists of a dual single shot (IC L) for debounce, 
    a 2-bit counter (IC J), the top 3 sets of 7405 1 s on schematic 880-106 
    (!C's A, B, C and 2 gates of D), and some gating. 

    When the Examine switch is depressed the counter (IC J) is started. 
    On the first count, a jump instruction (JMP 303) is strobed directly 
    onto the bi­directional data bus at the processor. This is accomplished 
    by enabling 2 gates of ICC and 2 gates of IC D through the output pin 6 
    of one gate of IC T. These open collector gates then pull down data 
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
    input sync,
    input examine,
    input [7:0] lo_addr,
    input [7:0] hi_addr,
    output reg [7:0] data_out,
    output reg ce = 1'b0
);

    reg [1:0] state = 'd0;
    reg prev_sync = 1'b0;
  
    always @(posedge clk) begin
        prev_sync <= sync;
        if (reset) begin
            ce <= 1'b0;
            state <= 2'b00;
        end
        else if (examine) begin
            state <= 2'b01;
            ce <= 1'b1;
            data_out <= 8'b11000011; // JMP
        end
        else begin
            if (~prev_sync & sync) begin
                case (state)
                    2'b01 : begin
                        data_out <= lo_addr;
                        state <= 2'b10;
                        ce <= 1'b1;
                    end
                    2'b10 : begin
                        data_out <= hi_addr;
                        state <= 2'b11;
                        ce <= 1'b1;
                    end
                    2'b11 : begin
                        state <= 2'b11;
                        ce <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule