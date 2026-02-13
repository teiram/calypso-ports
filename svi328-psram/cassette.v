module cassette(
    input clk,
    input play,
    input rewind,
    input reset,

    output reg [20:0] sdram_addr,
    input [7:0] sdram_data,
    output reg sdram_rd = 1'b0,
    input sdram_available,
    input sdram_ready,
    output data,
    output [2:0] status
);



reg  [7:0] ibyte;
reg  [2:0] state = IDLE;
reg sq_start;
reg  [1:0] eof;
reg [20:0] blk_addr;

wire done;
wire svi_CAS_Lead =  ((blk_addr >= 21'h0 && blk_addr <= 21'h0F) || (blk_addr >= 21'h23 && blk_addr <= 21'h32)); 
reg  [4:0] svi_cnt;
wire [4:0] svi_CAS_Lead_Mult =  5'd25; //Multiply factor 16 0x55 bytes PROD : d25 --- TEST : d2
wire svi_CAS_Sync =  (blk_addr == 21'h10 || blk_addr == 21'h33); 
wire svi_CAS_Lead_Sync =   svi_CAS_Lead || svi_CAS_Sync;

wire extend = ~svi_CAS_Lead_Sync;

assign status = state;

parameter
  IDLE      = 3'h0,
  START     = 3'h1,
  NEXT      = 3'h2,
  READ1     = 3'h3,
  READ2     = 3'h4,
  READ3     = 3'h5,
  READ4     = 3'h6,
  LEADLOOP  = 3'h7;

always @(posedge clk or posedge reset) begin
    reg ffplay;
    reg ffrewind;
    reg ffsdram_available;
    reg ffsdram_ready;
    
    if (reset == 1'b1) begin
        state <= IDLE;
        blk_addr <= 21'd0;
        sdram_addr <= 21'd0;
    end else begin
        ffplay <= play;
        ffrewind <= rewind;
        ffsdram_available <= sdram_available;
        ffsdram_ready <= sdram_ready;
        
        if (play == 1'b1) begin
            case (state)
                START: begin
                    state <= NEXT;
                end
                NEXT: begin
                    state <= READ1;
                    sdram_rd <= 1'b0;
                    svi_cnt <= 5'b0;
                end
                READ1: begin
                    if (~ffsdram_available & sdram_available) begin
                        sdram_rd <= 1'b1;
                        state <= READ2;
                    end
                end
                READ2: begin
                    if (~ffsdram_ready & sdram_ready) begin
                        ibyte <= sdram_data;
                        sdram_rd <= 1'b0;
                        state <= READ3;
                        sq_start <= 1'b1;
                    end
                end
                LEADLOOP: begin
                    sq_start <= 1'b1;
                    state <= READ3;
                end
                READ3: begin
                    sq_start <= 1'b0;
                    state <= done ? READ4 : READ3;
                end
                READ4: begin
                    if (svi_CAS_Lead && (svi_cnt < svi_CAS_Lead_Mult-1)) begin
                        svi_cnt <= svi_cnt + 5'b1;
                        state   <= LEADLOOP;
                    end else begin
                        sdram_addr <= sdram_addr + 21'd1;
                        blk_addr   <= blk_addr   + 21'd1;
                        state      <= NEXT;
                    end
                end
            endcase      
        end
        if (~ffplay & play) begin
            state <= START;
            blk_addr <= 21'd0;
        end else if (ffplay & ~play) begin
            state <= IDLE;
            blk_addr <= 21'd0;
        end else if (~ffrewind & rewind) begin
            sdram_addr <= 21'd0;
            blk_addr   <= 21'd0;
            state      <= IDLE;
        end 

    end
end

square_gen sq(
    .clk(clk),
    .start(sq_start),
    .din(ibyte),
    .extend(extend),
    .done(done),
    .dout(data)
);

endmodule