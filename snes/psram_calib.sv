//============================================================================
//  PSRAM timing calibration at start-up
//
//  The PSRAM read window depends on the board, the compilation (routing) and
//  the temperature, so the core finds it by itself, like a DDR controller:
//
//    for each PSRAM_CLK phase offset (48 steps of 194.7 ps = one 107 MHz
//    period, moved with the PLL dynamic phase shift):
//        restart the PSRAM controller (a bad phase can leave the chip in a
//        wrong mode), write 64 bytes in a scratch area, read them back with
//        each read sampling point (rd_delay 0..3)
//    then, for each rd_delay, the longest run of passing phases (circular,
//    it is one period) and its centre; the widest one wins.
//
//  About 10 ms. In manual mode (or if no phase passes at all) it just uses
//  the OSD values. While it runs the core is held in reset and the PSRAM
//  loader port belongs to the calibration.
//
//  Scratch area: 0x7FFFC0-0x7FFFFF (end of the BSRAM in the ROM_IN_PSRAM /
//  CPU_IN_PSRAM maps, unused in the default map). It is written again on
//  every calibration, so it does not hold anything.
//
//  Shaeon (Carlos Palmero), 2026
//============================================================================

module psram_calib (
    input             clk,             // clk_sys
    input             start,           // level: memories may be used (PLL locked)
    input             restart,         // pulse: recalibrate (OSD options changed)
    input             manual,          // use man_rd / man_phase instead
    input       [1:0] man_rd,
    input signed [6:0] man_phase,

    // PSRAM controller
    output reg        ctrl_rst_n = 1'b0,
    input             ctrl_ready,      // psram_ctrl ready (other clock domain)
    output reg  [1:0] rd_delay = 2'd2,
    output reg signed [6:0] phase = 7'sd0,   // PSRAM_CLK offset, pll_phase steps
    input             phase_settled,

    // loader port of snes_psram_bus
    output reg        ld_req = 1'b0,
    output reg        ld_we,
    output reg [22:0] ld_addr,
    output reg  [7:0] ld_din,
    input       [7:0] ld_q,
    input             ld_done,

    output reg        done = 1'b0,
    output reg  [5:0] win_len = 6'd0,  // width of the window found (steps), for the LEDs/debug
    output reg        found = 1'b0
);

localparam [22:0] BASE  = 23'h7FFFC0;
localparam        NPH   = 48;          // phase steps per period

reg  [1:0] rdy_s;
always @(posedge clk) rdy_s <= {rdy_s[0], ctrl_ready};
wire       ready = rdy_s[1];

// results: pass[rd][ph]
reg [47:0] pass [4];

reg  [3:0] st = 4'd0;
reg  [5:0] ph;
reg  [5:0] k;
reg  [1:0] rd;
reg        fail;
reg [15:0] cnt;

// analysis
reg  [6:0] ai;                 // 0..95, two turns
reg  [5:0] run, run_start, best_len, best_start;
reg  [1:0] best_rd;
reg  [1:0] arow;
wire [6:0] csum   = {1'b0, best_start} + {2'b00, best_len[5:1]};
wire [5:0] centre = csum >= 7'd48 ? 6'(csum - 7'd48) : csum[5:0];

function automatic [7:0] pat(input [5:0] a, input [5:0] p);
    reg [7:0] x;
    begin
        x   = {a, 2'b00} ^ {p, a[5:4]} ^ 8'h5A;
        pat = x ^ {x[3:0], x[7:4]} ^ (a[0] ? 8'hFF : 8'h00);
    end
endfunction

localparam S_IDLE = 4'd0, S_PHASE = 4'd1, S_SETTLE = 4'd2, S_RST = 4'd3, S_READY = 4'd4,
           S_WR = 4'd5, S_WRW = 4'd6, S_RD = 4'd7, S_RDW = 4'd8, S_NEXT = 4'd9,
           S_ANA = 4'd10, S_FINAL = 4'd11, S_DONE = 4'd12;

reg final_pass = 1'b0;         // last restart at the chosen phase

always @(posedge clk) begin
    ld_req <= 1'b0;

    if (!start || restart) begin
        st         <= S_IDLE;
        done       <= 1'b0;
        ctrl_rst_n <= 1'b0;
        if (!start) found <= 1'b0;
    end else case (st)

    S_IDLE: begin
        done <= 1'b0;
        ph   <= 0;
        if (manual) begin
            rd_delay   <= man_rd;
            phase      <= man_phase;
            final_pass <= 1'b1;
        end else begin
            phase      <= -7'sd24;
            final_pass <= 1'b0;
        end
        cnt <= 0;
        st  <= S_SETTLE;
    end

    // phase moving: wait until the PLL is there
    S_SETTLE: begin
        ctrl_rst_n <= 1'b0;
        cnt <= cnt + 1'd1;
        if (cnt > 16'd8 && phase_settled) begin
            cnt <= 0;
            st  <= S_RST;
        end
    end

    // restart the controller (QPI reset, SPI reset, enter QPI)
    S_RST: begin
        cnt <= cnt + 1'd1;
        if (cnt == 16'd16) begin
            ctrl_rst_n <= 1'b1;
            cnt <= 0;
            st  <= S_READY;
        end
    end

    S_READY:
        if (ready) begin
            if (final_pass) begin
                done <= 1'b1;
                st   <= S_DONE;
            end else begin
                k  <= 0;
                st <= S_WR;
            end
        end

    // write the pattern
    S_WR: begin
        ld_req  <= 1'b1;
        ld_we   <= 1'b1;
        ld_addr <= BASE + k;
        ld_din  <= pat(k, ph);
        st      <= S_WRW;
    end
    S_WRW:
        if (ld_done) begin
            k <= k + 1'd1;
            if (k == 6'd63) begin
                k    <= 0;
                rd   <= 0;
                fail <= 1'b0;
                cnt  <= 0;
                rd_delay <= 2'd0;
                st   <= S_RD;
            end else
                st <= S_WR;
        end

    // read it back with each sampling point
    S_RD: begin
        cnt <= cnt + 1'd1;
        if (cnt > 16'd4) begin            // rd_delay settles in the PSRAM clock domain
            ld_req  <= 1'b1;
            ld_we   <= 1'b0;
            ld_addr <= BASE + k;
            st      <= S_RDW;
        end
    end
    S_RDW:
        if (ld_done) begin
            if (ld_q != pat(k, ph)) fail <= 1'b1;
            k   <= k + 1'd1;
            cnt <= 5'd5;
            if (k == 6'd63) begin
                pass[rd][ph] <= !(fail || ld_q != pat(k, ph));
                k    <= 0;
                fail <= 1'b0;
                cnt  <= 0;
                if (rd == 2'd3) st <= S_NEXT;
                else begin
                    rd       <= rd + 1'd1;
                    rd_delay <= rd + 1'd1;
                    st       <= S_RD;
                end
            end else
                st <= S_RD;
        end

    S_NEXT:
        if (ph == NPH - 1) begin
            ai       <= 0;
            arow     <= 0;
            run      <= 0;
            best_len <= 0;
            best_rd  <= 0;
            best_start <= 0;
            st       <= S_ANA;
        end else begin
            ph    <= ph + 1'd1;
            phase <= phase + 7'sd1;
            cnt   <= 0;
            st    <= S_SETTLE;
        end

    // longest circular run of passes, per rd_delay (two turns of 48)
    S_ANA: begin
        if (pass[arow][ai >= NPH ? ai - NPH : ai]) begin
            if (run == 0) run_start <= ai >= NPH ? ai - NPH : ai;
            if (run != NPH) run <= run + 1'd1;
            if (run + 1'd1 > best_len && run != NPH) begin
                best_len   <= run + 1'd1;
                best_rd    <= arow;
                best_start <= run == 0 ? (ai >= NPH ? ai - NPH : ai) : run_start;
            end
        end else
            run <= 0;
        if (ai == 2 * NPH - 1) begin
            ai  <= 0;
            run <= 0;
            if (arow == 2'd3) st <= S_FINAL;
            arow <= arow + 1'd1;
        end else
            ai <= ai + 1'd1;
    end

    // go to the centre of the widest window and restart the controller there
    S_FINAL: begin
        win_len    <= best_len;
        final_pass <= 1'b1;
        cnt        <= 0;
        if (best_len == 0) begin
            found    <= 1'b0;              // nothing passed: OSD values
            rd_delay <= man_rd;
            phase    <= man_phase;
        end else begin
            found    <= 1'b1;
            rd_delay <= best_rd;
            // centre (0..47 = offsets -24..+23)
            phase    <= $signed({1'b0, centre}) - 7'sd24;
        end
        st <= S_SETTLE;
    end

    S_DONE: ;

    default: st <= S_IDLE;
    endcase
end

endmodule
