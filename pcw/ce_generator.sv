module ce_generator(
    input wire clk,
    input wire reset,
    output logic cpu_ce_p,
    output logic cpu_ce_n,
    output logic sdram_clk_ref,
    output logic ce_16mhz,
    output logic ce_4mhz,
    output logic ce_2mhz    
);	 
    reg [5:0] counter;
    always @(posedge clk or posedge reset) begin
        if (reset) counter <= 'b0;
        else counter <= counter + 1'b1;
    end
    
    // Keep the original clock enables
    assign cpu_ce_p = ~counter[3] & ~counter[2] & ~counter[1] & ~counter[0]; // 4MHz positive CE
    assign cpu_ce_n =  counter[3] & ~counter[2] & ~counter[1] & ~counter[0]; // 4MHz negative CE
    //assign ce_1mhz  = ~|counter;                                             // 1MHz
    assign ce_16mhz = ~counter[1] & ~counter[0];                             // 16MHz
    assign ce_4mhz = cpu_ce_p;
    assign sdram_clk_ref = cpu_ce_p;
    assign ce_2mhz = counter[4];

endmodule