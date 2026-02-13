module psram64(
   input init,
   input clk,

   inout reg [3:0] PSRAM_SIO,
   output PSRAM_CE,

   input [22:0] addr,
   output reg [7:0] dout,
   input [7:0] din,
   input we,
   input rd,
   output reg ready = 1'b0
);

parameter MHZ = 133;

localparam startup_cycles = MHZ * 150;            // 150 us delay

// PSRAM commands
localparam CMD_RESET = 8'h99;
localparam CMD_RESET_ENABLE = 8'h66;
localparam CMD_ENTER_QUAD_MODE = 8'h35;
localparam CMD_QUAD_WRITE = 8'h38;
localparam CMD_FAST_READ_QUAD = 8'heb;
localparam CMD_READ_ID = 8'h9f;
localparam CMD_NOP = 8'h00;

reg [15:0] init_counter;
reg [6:0] cnt /* synthesis keep */;

reg rd_w;
reg [23:0] latched_addr;
reg [7:0] latched_din;
reg [7:0] command;

typedef enum bit [2:0] {
    STATE_PRE_STARTUP,
    STATE_STARTUP,
    STATE_RESET_ENABLE,
    STATE_RESET,
    STATE_READ_ID,
    STATE_ENTER_QUAD_MODE,
    STATE_READY,
    STATE_OP
} state_t;

typedef enum bit [2:0] {
    PHASE_IDLE,
    PHASE_SEND_SPI_CMD,
    PHASE_WAIT_ID,
    PHASE_SEND_QUAD_CMD,
    PHASE_SEND_QUAD_ADDR,
    PHASE_WAIT_DATA,
    PHASE_SEND_DATA
} phase_t;

state_t state = STATE_PRE_STARTUP;
phase_t phase = PHASE_IDLE;

always @(negedge clk) begin
    reg old_we, old_rd, old_init;
    reg [7:0] cmd;

    old_we <= we;
    old_rd <= rd;
    old_init <= init;
    
    if (old_init & ~init) begin 
        state <= STATE_STARTUP;
        init_counter <= startup_cycles;
        PSRAM_CE <= 1'b1;
        PSRAM_SIO <= 4'bZZZZ;
    end

    case (state)
        STATE_STARTUP: begin
            ready <= 1'b0;
            if (init_counter == 5'd0) begin
                state <= STATE_RESET_ENABLE;
                command <= CMD_RESET_ENABLE;
                phase <= PHASE_SEND_SPI_CMD;
                cnt <= 5'd0;
            end else begin
                init_counter <= init_counter - 1'd1;
            end
        end

        STATE_RESET_ENABLE: begin
            if (phase == PHASE_IDLE) begin
                state <= STATE_RESET;
                command <= CMD_RESET;
                phase <= PHASE_SEND_SPI_CMD;
                cnt <= 5'd0;
            end else begin
                cnt <= cnt + 1'd1;
            end
        end

        STATE_RESET: begin
            if (phase == PHASE_IDLE) begin
                state <= STATE_READ_ID;
                command <= CMD_READ_ID;
                phase <= PHASE_SEND_SPI_CMD;
                cnt <= 5'd0;
            end else begin
                cnt <= cnt + 1'd1;
            end
        end

        STATE_READ_ID: begin
            if (phase == PHASE_IDLE) begin
                state <= STATE_ENTER_QUAD_MODE;
                command <= CMD_ENTER_QUAD_MODE;
                phase <= PHASE_SEND_SPI_CMD;
                cnt <= 5'd0;
            end else begin 
                cnt <= cnt + 1'd1;
            end
        end
        
        STATE_ENTER_QUAD_MODE: begin
            if (phase == PHASE_IDLE) begin
                state <= STATE_READY;
                ready <= 1'b1;
            end
            cnt <= cnt + 1'd1;
        end

        STATE_READY: begin
            if (~old_rd & rd) begin
                latched_addr <= {1'b0, addr};
                ready <= 1'b0;
                state <= STATE_OP;
                command <= CMD_FAST_READ_QUAD;
                cnt <= 5'd0;
                phase <= PHASE_SEND_QUAD_CMD;
                rd_w <= 1'b1;
            end else if (~old_we & we) begin
                latched_addr <= {1'b0, addr};
                latched_din <= din;
                ready <= 1'b0;
                state <= STATE_OP;
                command <= CMD_QUAD_WRITE;
                cnt <= 5'd0;
                phase <= PHASE_SEND_QUAD_CMD;
                rd_w <= 1'b0;
            end
        end

        STATE_OP: begin
            if (phase == PHASE_IDLE) begin
                state <= STATE_READY;
                ready <= 1'b1;
            end
            cnt <= cnt + 1'd1;
        end
        
        STATE_PRE_STARTUP: begin end

    endcase

    case (phase)
        PHASE_SEND_SPI_CMD: begin
            if (cnt < 5'd8) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO[0] <= command[7];
                PSRAM_SIO[3:1] <= 3'bZZZ;
                command <= {command[6:0], 1'b0};
            end else begin
                if (state == STATE_READ_ID) begin
                    PSRAM_SIO <= 4'bZZZZ;
                    PSRAM_CE <= 1'b0;
                    phase <= PHASE_WAIT_ID;
                end else begin 
                    PSRAM_CE <= 1'b1;
                    PSRAM_SIO <= 4'bZZZZ;
                    phase <= PHASE_IDLE;
                end
            end
        end

        PHASE_WAIT_ID: begin
            if (cnt < 7'd104) begin
                PSRAM_CE <= 1'b0;
            end else begin
                PSRAM_CE <= 1'b1;
                phase <= PHASE_IDLE;
            end
        end
        
        PHASE_SEND_QUAD_CMD: begin
            if (cnt == 5'd0) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO <= command[7:4];
            end
            else if (cnt == 5'd1) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO <= command[3:0];
                phase <= PHASE_SEND_QUAD_ADDR;
            end
        end

        PHASE_SEND_QUAD_ADDR: begin
            if (cnt < 5'd8) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO <= latched_addr[23:20];
                latched_addr <= {latched_addr[19:0], 4'd0};
            end else begin
                if (rd_w == 1'b1) begin
                    PSRAM_SIO <= 4'bZZZZ;
                    phase <= PHASE_WAIT_DATA;
                    PSRAM_CE <= 1'b0;
                end else begin
                    PSRAM_SIO <= latched_din[7:4];
                    PSRAM_CE <= 1'b0;
                    phase <= PHASE_SEND_DATA;
                end
            end
        end

        PHASE_WAIT_DATA: begin
            if (cnt < 5'd15) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO <= 4'bZZZZ;
            end else begin
                if (cnt == 5'd15) begin 
                    dout[7:4] <= PSRAM_SIO;
                    PSRAM_CE <= 1'b0;
                end else if (cnt == 5'd16) begin
                    dout[3:0] <= PSRAM_SIO;
                    PSRAM_CE <= 1'b0;
                    ready <= 1'b1;
                end else begin 
                    PSRAM_CE <= 1'b1;
                    phase <= PHASE_IDLE;
                end
            end
        end

        PHASE_SEND_DATA: begin
            if (cnt == 5'd9) begin
                PSRAM_CE <= 1'b0;
                PSRAM_SIO <= latched_din[3:0];
            end else begin
                PSRAM_CE <= 1'b1;
                ready <= 1'b1;
                phase <= PHASE_IDLE;
            end
        end
    endcase

end

endmodule
