module cpu(
    input clk,
    input f1,
    input f2,
    input reset,
    
    input bus_cpu_hold,
    input bus_cpu_intr,
    
    output bus_cpu_sync,
    output bus_cpu_wait,
    output bus_cpu_inte,
    output bus_cpu_hlda,
    output bus_cpu_rd,
    output bus_cpu_wr_n,
    input bus_cpu_xrdy,

    output [15:0] bus_addr,
    output [7:0] bus_data_out,
    input [7:0] bus_data_in,
    output [7:0] bus_cpu_sysctl
);

assign bus_data_out = odata;
assign bus_cpu_sysctl = sysctl;

wire [7:0] odata;
reg [7:0] sysctl;
reg sync_last;

always @(posedge clk) begin
    sync_last <= bus_cpu_sync;
    if (~sync_last & bus_cpu_sync) begin 
        sysctl <= odata;
    end
end

wire rst_n = &rcnt;
reg  [7:0] rcnt = 8'h00;
always @(posedge clk) begin
    if (reset) rcnt <= 8'h00;
    else if (~&rcnt) rcnt <= rcnt + 1'd1;
end

vm80a_core cpu(
    .pin_clk(clk),
    .pin_f1(f1),
    .pin_f2(f2),
    .pin_reset(~rst_n),
    .pin_a(bus_addr),
    .pin_dout(odata),
    .pin_din(bus_data_in),
    .pin_hold(bus_cpu_hold),
    .pin_ready(bus_cpu_xrdy),
    .pin_int(bus_cpu_intr),
    .pin_wr_n(bus_cpu_wr_n),
    .pin_dbin(bus_cpu_rd),
    .pin_inte(bus_cpu_inte),
    .pin_hlda(bus_cpu_hlda),
    .pin_wait(bus_cpu_wait),
    .pin_sync(bus_cpu_sync)
);

endmodule
