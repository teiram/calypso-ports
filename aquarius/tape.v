// tape.v

module tape(
    input clk, 
    input ce_tape,
    input reset,

    input [7:0] data, 
    input [15:0] length,
    output reg [15:0] addr,
    output reg req,

    input loaded,
    input sdram_available,
    input sdram_ready,
    output reg out
);

always @(posedge clk) begin
    reg [2:0] state = 0;
    reg [10:0] byte_reg;
    reg [3:0] bit_cnt;
    reg [3:0] tape_state;
    reg [7:0] data_reg;
    reg sdram_available_last;
    reg sdram_ready_last;
    if (reset | loaded) begin
        state <= {1'b0, loaded};
        req <= 0;
        addr <= 0;
        out <= 0;
    end else begin
        sdram_available_last <= sdram_available;
        sdram_ready_last <= sdram_ready;
        
        case (state)
            // Wait for SDRAM available
            1: begin
                if (~sdram_available_last & sdram_available) begin
                    req <= 1;
                    state <= 2;
                end
            end
            // Wait for data to be available
            2: begin
                if (~sdram_ready_last & sdram_ready) begin
                    state <= 3;
                    data_reg <= data;
                    req <= 0;
                end
            end
            
            // Fetch byte to send
            3: begin
                req <= 0;
                if (addr >= length) begin
                    state <= 0;
                end else begin
                    byte_reg <= {1'b0, data_reg, 2'b11};
                    addr <= addr + 1'd1;
                    bit_cnt <= 11;
                    state <= 4; // START sending
                end
            end

            // Send byte
            4: begin
                if (bit_cnt == 0) begin
                    state <= 1; // Fetch next byte
                end else begin
                    bit_cnt <= bit_cnt - 1'd1;
                    tape_state <= 0;
                    state <= byte_reg[bit_cnt - 1'd1] ? 3'd5 : 3'd6;
                end
            end

            // Send 1
            5: if (ce_tape) begin
                tape_state <= tape_state + 1'd1;
                case(tape_state)
                    0: out <= 1;
                    1: out <= 0;
                    2: out <= 1;
                    3: begin
                        out <= 0;
                        state <= 4;
                    end
                endcase
            end

            // Send 0
            6: if (ce_tape) begin
                tape_state <= tape_state + 1'd1;
                case(tape_state)
                    0: out <= 1;
                    2: out <= 0;
                    4: out <= 1;
                    6: out <= 0;
                    7: state <= 4;
                endcase
            end
        endcase
    end
end

endmodule
