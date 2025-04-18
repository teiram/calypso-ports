
//-------------------------------------------------------------------------------------------------
module i2s_decoder_kyp
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire[ 2:0] i2s, //[sDi,WS,sClk]
	output reg [15:0] left,
	output reg [15:0] right
);
//-------------------------------------------------------------------------------------------------

reg[1:0] cks;
always @(posedge clock) cks <= { cks[0], i2s[0] };

//-------------------------------------------------------------------------------------------------

reg ckd;
wire ckp = cks[1] && !ckd;
always @(posedge clock) ckd <= cks[1];

reg lrd;
wire lrp = i2s[1] != lrd;
always @(posedge clock) if(ckp) lrd <= i2s[1];

//-------------------------------------------------------------------------------------------------

reg[16:0] sr = 17'd1;
always @(posedge clock) if(ckp) begin
	if(lrp) begin
		sr <= 17'd1;
		if(lrd) right <= sr[15:0]; else left <= sr[15:0];
	end
	else if(!sr[16]) sr <= { sr[15:0], i2s[2] };
end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------