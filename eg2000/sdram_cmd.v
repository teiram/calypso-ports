//-------------------------------------------------------------------------------------------------
// ram commands
//-------------------------------------------------------------------------------------------------

task INHIBIT;
begin
	ramCs  <= 1'b1;
	ramRas <= 1'b1;
	ramCas <= 1'b1;
	ramWe  <= 1'b1;
	ramDqm <= 2'b11;
	ramBA  <= 2'b00;
	ramA   <= 13'h0000;
end
endtask

task NOP;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b1;
	ramCas <= 1'b1;
	ramWe  <= 1'b1;
	ramDqm <= 2'b11;
	ramBA  <= 2'b00;
	ramA   <= 13'h0000;
end
endtask

task REFRESH;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b0;
	ramCas <= 1'b0;
	ramWe  <= 1'b1;
	ramDqm <= 2'b11;
	ramBA  <= 2'b00;
	ramA   <= 13'h0000;
end
endtask

task PRECHARGE;
input pca;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b0;
	ramCas <= 1'b1;
	ramWe  <= 1'b0;
	ramDqm <= 2'b11;
	ramBA  <= 2'b00;
	ramA   <= { 2'b00, pca, 9'b0 };
end
endtask

task LMR;
input[12:0] mode;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b0;
	ramCas <= 1'b0;
	ramWe  <= 1'b0;
	ramDqm <= 2'b11;
	ramBA  <= 2'b00;
	ramA   <= mode;
end
endtask

task ACTIVE;
input[ 1:0] ba;
input[12:0] a;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b0;
	ramCas <= 1'b1;
	ramWe  <= 1'b1;
	ramDqm <= 2'b11;
	ramBA  <= ba;
	ramA   <= a;
end
endtask

task WRITE;
input[ 1:0] dqm;
input[15:0] d;
input[ 1:0] ba;
input[ 8:0] a;
input pca;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b1;
	ramCas <= 1'b0;
	ramWe  <= 1'b0;
	ramDqm <= dqm;
	ramQ   <= d;
	ramBA  <= ba;
	ramA   <= { 2'b00, pca, 1'b0, a };
end
endtask

task READ;
input[ 1:0] dqm;
input[ 1:0] ba;
input[ 8:0] a;
input pca;
begin
	ramCs  <= 1'b0;
	ramRas <= 1'b1;
	ramCas <= 1'b0;
	ramWe  <= 1'b1;
	ramDqm <= dqm;
	ramBA  <= ba;
	ramA   <= { 2'b00, pca, 1'b0, a };
end
endtask

//-------------------------------------------------------------------------------------------------
