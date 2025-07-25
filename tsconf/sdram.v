//                25        26        27        28        29        30        31        20        21        22        23        24        25
// cpu_strobe ________________________________________________________________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__________________________________
// cyc        ‾‾‾‾\_____________________________________________________________________________________________________________/‾‾‾‾‾‾‾‾‾\____
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
//                5.95ns
//
// REFRESH        RASCAS                                                      RASCAS
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
// clk_ram       ‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
//                        REFRSH                                                      REFRSH
//
// READ+NOP       RAS                 CAS                           latch     set do
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
// clk_ram       ‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
//                        ACT                 READ           DQDQDQDQD
//
// WRITE+NOP      RAS                 CASWEDQ
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
// clk_ram       ‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
//                        ACT                 WRITE
//
// NOP+READ                                     RAS                           CAS                           latch     set do
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
// clk_ram       ‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
//                                                      ACT                           READ           DQDQDQDQD
//
// NOP+WRITE                                    RAS                           CASWEDQ
// clk_sys    ____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾
// clk_ram       ‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____/‾‾‾‾\____
//                                                      ACT                           WRITE
//

module sdram
(
    input             clk,
    input             cyc,

    // Memory port 1
    input             port1_curr_cpu,
    input       [1:0] port1_bsel,
    input      [23:0] port1_a,
    input      [15:0] port1_di,
    output reg [15:0] port1_do,
    output reg [15:0] port1_do_cpu,
    input             port1_req,
    input             port1_rnw,

    // Memory port 2
    input       [1:0] port2_bsel,
    input      [23:0] port2_a,
    input      [15:0] port2_di,
    output reg [15:0] port2_do,
    input             port2_req,
    input             port2_rnw,
    output reg        port2_ack = 0,

    // SDRAM Pin
    inout  reg [15:0] SDRAM_DQ,
    output reg [12:0] SDRAM_A = 0,
    output reg  [1:0] SDRAM_BA = 0,
    output            SDRAM_DQML,
    output            SDRAM_DQMH,
    output            SDRAM_nCS,
    output            SDRAM_nCAS,
    output            SDRAM_nRAS,
    output            SDRAM_nWE,
    output            SDRAM_CKE,
    output            SDRAM_CLK
);

reg [2:0] sdr_cmd;

localparam SdrCmd_xx = 3'b111; // no operation
localparam SdrCmd_ac = 3'b011; // activate
localparam SdrCmd_rd = 3'b101; // read
localparam SdrCmd_wr = 3'b100; // write
localparam SdrCmd_pr = 3'b010; // precharge all
localparam SdrCmd_re = 3'b001; // refresh
localparam SdrCmd_ms = 3'b000; // mode regiser set

reg  [5:0] state = 0;
reg [15:0] data;
reg  [7:0] col;
reg [23:0] Ar1, Ar2;
reg  [1:0] dqm1, dqm2;
reg        rq1, rq2;
reg        rd1, rd2 = 0;

always @(posedge clk) begin
    sdr_cmd <= SdrCmd_xx;
    data <= SDRAM_DQ;
    SDRAM_DQ <= {16{1'bZ}};
    state <= state + 1'd1;
    port2_ack <= 1'b0;

    case (state)

    // Init
    0:	begin
        sdr_cmd <= SdrCmd_pr;		// PRECHARGE
    end

    // REFRESH
    3,10: begin
        sdr_cmd <= SdrCmd_re;
    end

    // LOAD MODE REGISTER
    17: begin
        sdr_cmd <= SdrCmd_ms;
        SDRAM_A <= {3'b000, 1'b1, 2'b00, 3'b010, 1'b0, 3'b000};
    end

    // Idle
    24: begin
        state <= state;
        Ar1 <= port1_a;
        Ar2 <= port2_a;
        dqm1 <= port1_rnw ? 2'b00 : ~port1_bsel;
        dqm2 <= port2_rnw ? 2'b00 : ~port2_bsel;
        rq1 <= port1_req;
        rd1 <= port1_req & port1_rnw;
        rq2 <= port2_req;
        rd2 <= port2_req & port2_rnw;
        if (cyc)
            state <= state + 1'd1;
    end

    // Start - activate (port1) or refresh
    25: begin
        {SDRAM_BA, SDRAM_A[11:0], col} <= Ar1;
        if (rq1) begin
            sdr_cmd <= SdrCmd_ac;
        end
        else if (rq2) begin
            // start at state 28
        end
        else begin
            sdr_cmd <= SdrCmd_re;
        end
    end

    // Single read/write (port1) - with auto precharge
    27: begin
        SDRAM_A <= {dqm1, 3'b1xx, col};
        if (rq1) begin
            if (rd1) begin
                sdr_cmd <= SdrCmd_rd;
            end
            else begin
                sdr_cmd <= SdrCmd_wr;
                SDRAM_DQ <= port1_di;
            end
        end
    end

    // Start - activate (port2) or refresh
    28: begin
        {SDRAM_BA, SDRAM_A[11:0], col} <= Ar2;
        if (rq2) begin
            sdr_cmd <= SdrCmd_ac;
        end
    end

    // Latch read (port 1) and Single read/write (port2) - with auto precharge
    31: begin
        if (rd1) begin
            port1_do <= data;
            if (port1_curr_cpu) port1_do_cpu <= data;
        end

        SDRAM_A <= {dqm2, 3'b1xx, col};
        if (rq2) begin
            if (rd2) begin
                sdr_cmd <= SdrCmd_rd;
            end
            else begin
                sdr_cmd <= SdrCmd_wr;
                SDRAM_DQ <= port2_di;
                port2_ack <= 1'b1;
            end
        end

        if (!rq1 && !rq2) begin
            sdr_cmd <= SdrCmd_re;
        end

        state <= 20;
    end

    // Latch read (port 2)
    23: begin
        if (rd2) begin
            port2_do <= data;
            port2_ack <= 1'b1;
        end
    end

    endcase
end

assign SDRAM_CKE  = 1;
assign SDRAM_nCS  = 0;
assign SDRAM_nRAS = sdr_cmd[2];
assign SDRAM_nCAS = sdr_cmd[1];
assign SDRAM_nWE  = sdr_cmd[0];
assign SDRAM_DQML = SDRAM_A[11];
assign SDRAM_DQMH = SDRAM_A[12];
assign SDRAM_CLK = clk;

endmodule
