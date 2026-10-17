module i2s_decoder(
    input wire clock,
    input wire i2s_bck,
    input wire i2s_lrck,
    input wire i2s_data,

    output reg [15:0] audio_left,
    output reg [15:0] audio_right
);

reg[1:0] cks;
always @(posedge clock) cks <= {cks[0], i2s_bck};

reg ckd;
wire ckp = cks[1] & ~ckd;
always @(posedge clock) ckd <= cks[1];

reg lrd;
wire lrp = i2s_lrck != lrd;
always @(posedge clock) if (ckp) lrd <= i2s_lrck;

reg [16:0] sr = 17'd1;
always @(posedge clock) begin
    if (ckp) begin
        if (lrp) begin
            sr <= 17'd1;
            if (lrd) audio_right <= {sr[14:0], i2s_data};
            else audio_left <= {sr[14:0], i2s_data};
        end
        else if (~sr[16]) sr <= {sr[15:0], i2s_data};
    end
end

endmodule