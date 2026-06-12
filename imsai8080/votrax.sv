module votrax(
    input clk36m,
    input clk2m5,
    input reset,

    input [7:0] serial_data,
    input serial_strobe,

    output [17:0] audio,
    output audio_valid,
    
    output [7:0] acia_status
);

wire [15:0] address;
wire [7:0] data_out;
reg [7:0] data_in;
wire rw;
wire vma;

wire sc01_ar;
wire [17:0] sc01_audio;
wire sc01_audio_valid;
//reg sc01_stb = 1'b0;

wire [7:0] ram_q;

ram ram(
    .clock(clk36m),
    .address(address[9:0]),
    .data(data_out),
    .wren(ram_we),
    .q(ram_q)
);

wire [7:0] rom_q;
rom rom(
    .clock(clk36m),
    .address(address[11:0]),
    .q(rom_q)
);

wire [7:0] sc01_q = 8'd0;

// ACIA status register
// Bit 0. Receive Data Register Full (RDRF)
// Bit 1. Transmit Data Register Empty (TDRE)
// Bit 2. Data Carrier Detect (/DCD). 1 means no carrier
// Bit 3. Clear to Send (/CTS). 
// Bit 4. Framing Error (FE).
// Bit 5. Receiver overrun (OVRN).
// Bit 6. Parity Error (PE).
// Bit 7. Interrupt Request (/IRQ)

/*
reg [7:0] serial_data_buffer[32];
reg [4:0] serial_data_rd;
reg [4:0] serial_data_wr;

wire has_serial_data = serial_data_rd != serial_data_wr;



always @(posedge clk36m) begin
    if (reset == 1'b1) begin
        serial_data_wr <= 'd0;
    end
    else if (serial_strobe == 1'b1) begin
        serial_data_buffer[serial_data_wr] <= serial_data;
        serial_data_wr <= serial_data_wr + 1'd1;
    end
end
*/

wire ram_we = address[14:13] == 2'b00 && rw == 1'b0;
wire sc01_stb = address[14:13] == 2'b10 && rw == 1'b0;

reg has_serial_data = 1'b0;
reg [7:0] serial_reg;

assign acia_status = {7'b0000001, has_serial_data};

always @(posedge clk36m) begin

    if (reset == 1'b1) begin
        has_serial_data <= 1'b0;
    end
    else begin
        if (serial_strobe == 1'b1) begin
            serial_reg <= serial_data;
            has_serial_data <= 1'b1;
        end
        casex ({rw, address[14:12]})
            4'b1_00x: data_in <= ram_q;            // | $0000-$1FFF | $8000-$9FFF |   1K    | RAM    |
            4'b1_01x: begin                        // | $2000-$3FFF | $A000-$BFFF | 2 bytes | ACIA   |
                casex (address[1:0])
                    2'b10: data_in <= {7'b0000001, has_serial_data};
                    2'b11: begin                   // ACIA data register
                        data_in <= serial_reg;
                        has_serial_data <= 1'b0;
                        //serial_data_rd <= serial_data_rd + 1'd1;
                    end
                    default: data_in <= 8'b00000001;
                endcase
            end
            4'b1_10x: data_in <= sc01_q;          // | $4000-$5FFF | $C000-$DFFF | 1 byte  | SC-01  |
            4'b1_11x: data_in <= rom_q;           // | $6000-$7FFF | $E000-$FFFF |   4K    | ROM    |
            default:;
        endcase
    end
end

cpu68 cpu(
    .clk(clk2m5),
    .rst(reset),
    .rw(rw),
    .vma(vma),
    .address(address),
    .data_in(data_in),
    .data_out(data_out),
    .hold(1'b0),
    .halt(1'b0),
    .irq(sc01_ar),
    .nmi(1'b0)
);

sc01a sc01a(
    .clk(clk36m),
    .reset_n(~reset),

    .p(data_out[5:0]),
    .inflection(2'b00),
    .stb(sc01_stb),

    .ar(sc01_ar),

    .sclock_en(sclock_en),
    .cclock_en(cclock_en),

    .audio_out(sc01_audio),
    .audio_valid(sc01_audio_valid)
);


localparam int SC01_HZ = 64'd756_000;
localparam CLK_HZ = 64'd36_000_000;
localparam RESAMP_FREQ = 32'd48000;
localparam int INC_SC01 = (SC01_HZ * (64'd2 ** 32)) / (CLK_HZ * 18);
localparam int PHASE_INC_RESAMPL = (32'd32768 * RESAMP_FREQ * 18) / SC01_HZ;

reg sclock_en = 1'b0;
reg cclock_en = 1'b0;
reg [31:0] phase_sc01 = 'd0;

always_ff @(posedge clk36m) begin
    logic [32:0] sum;
    logic toggle;
    
    if (reset) begin
        phase_sc01 <= 'd0;
        sclock_en <= 1'b0;
        cclock_en <= 1'b0;
        toggle = 1'b0;
    end
    else begin
        sum = {1'b0, phase_sc01} + {1'b0, INC_SC01};
        phase_sc01 <= sum[31:0];
        sclock_en <= sum[32];
        cclock_en <= 1'b0;
        if (sum[32] == 1'b1) begin
            toggle = ~toggle;
            if (toggle == 1'b1) cclock_en <= 1'b1;
        end
    end
end

sc01a_resamp #(
    .CLK_HZ(CLK_HZ),
    .SAMPLE_BITS(18)
) resampler (
    .clk(clk36m),
    .reset_n(~reset),
    .s_in(sc01_audio),
    .s_valid(sc01_audio_valid),
    .phase_inc_in(PHASE_INC_RESAMPL),
    .s_out(audio),
    .s_out_valid(audio_valid)
);

endmodule
