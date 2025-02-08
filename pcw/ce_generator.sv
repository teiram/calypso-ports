module ce_generator(
    input wire clk,
    input wire reset,
    output logic cpu_ce_p,
    output logic cpu_ce_n,
    output logic sdram_clk_ref,
    output logic ce_16mhz,
    output logic ce_4mhz,
    output logic ce_1mhz
);

    reg [5:0] counter;
    always @(posedge clk or posedge reset) begin
        if (reset) counter <= 'b0;
        else counter <= counter + 1'b1;
    end
    
    assign cpu_ce_p = ~counter[3] & ~counter[2] & ~counter[1] & ~counter[0]; //  4mhz
    assign cpu_ce_n =  counter[3] & ~counter[2] & ~counter[1] & ~counter[0]; //  4mhz
    assign ce_1mhz  = ~|counter;                                            //  1mhz
    assign ce_16mhz = ~counter[1] & ~counter[0];                             // 16mhz
    assign ce_4mhz = cpu_ce_p;
    assign sdram_clk_ref = cpu_ce_p;
    
endmodule
    