
module imsai8080(
    input clk,
    input f1,
    input f2,
    input reset,
    
    input hold_in,
    input ready_in,
    input intr_in,
    
    output cpu_sync,
    output reg interrupt_ack,
    output reg mem_wr_n,
    output reg io_stack,
    output reg halt_ack,
    output reg io_wr,
    output reg m1,
    output reg io_rd,
    output reg mem_rd,
    output cpu_inte_o,
    output cpu_hlda_o,
    output cpu_wait_o,
    output run_o,
    
    output reg [7:0] fdc_data_in,
    output reg fdc_we,
    output reg [15:0] cpu_addr,
    input [7:0] fdc_data_out,
    
    output reg [7:0] data_leds,
    output reg [7:0] programmed_output_leds = 8'd0,
    
    input [7:0] data_addr_in,
    input [7:0] addr_sense_in,
    
    input step_switch,
    input examine_switch,
    input examine_next_switch,
    input deposit_switch,
    input deposit_next_switch,
    input reset_switch,
    input clear_switch,
    
    input run_switch,
    input stop_switch,
    
    output [7:0] debug_leds,
    
    output [15:0] extram_addr,
    output [7:0] extram_data_in,
    input [7:0] extram_data_out,
    output extram_rd,
    output extram_we,
    
    output reg [7:0] sio_in,
    output sio_addr,
    input [7:0] sio_out,
    output reg sio_rd,
    output reg sio_we
);

    parameter SYS_CLK = 36000000;
    
    reg intr = 0;
    reg [7:0] idata;
    wire [15:0] addr;
    wire wr_n;
    wire inta_n;
    wire [7:0] odata;


    wire cpu_ce;

    reg [7:0] sysctl;
    reg xrdy = 1'b0;
    reg run = 1'b0;
    assign run_o = run;
    
    reg sync_last;
    
    always @(posedge clk) begin
        sync_last <= cpu_sync;
        if (~sync_last & cpu_sync) begin 
            sysctl <= odata;
        end
    end
    
    always @(posedge clk) begin
        reg last_f2 = 1'b0;
        last_f2 <= f2;
        
        if (f2 & ~last_f2) begin
            if (sysctl[5] & stop_switch) run <= 1'b0;
            else if (run_switch) run <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (run) xrdy <= ready_in;
        else begin
            if (xrdy) begin
                if (~sync_last & cpu_sync) xrdy <= 1'b0;
            end
            else begin
                if (deposit_next_ce |
                    examine_ce |
                    examine_next_ce |
                    reset_ce |
                    step_switch_down) xrdy <= 1'b1;
            end
        end
    end
    
    wire [7:0] examine_out;
    wire [7:0] examine_next_out;
    wire [7:0] reset_out;
    wire [7:0] sense_sw_out;
    wire [7:0] turnmon_out;
    wire [7:0] rammain_out;
    wire [7:0] boot_out;

    wire [7:0] deposit_in;
    wire [7:0] deposit_next_in;
    reg [7:0] rammain_in;

    wire boot;

    wire deposit_switch_down;
    wire deposit_we;
    wire deposit_next_switch_down;
    wire deposit_next_ce;
    wire deposit_next_we;
    wire examine_switch_down;
    wire examine_ce;
    wire examine_next_switch_down;
    wire examine_next_ce;
    wire reset_switch_down;
    wire reset_ce;
    wire step_switch_down;

    reg wr_rammain;

    wire rd;

    reg rd_boot;
    reg rd_rammain;
    reg rd_turnmon;
    reg rd_examine;
    reg rd_examine_next;
    reg rd_deposit_examine_next;
    reg rd_sense;

    reg  [7:0] rcnt = 8'h00;

    ///////// CHIP SELECT - input to cpu ////////////
    always @(*) begin
        rd_boot = 0;
        rd_rammain = 0;
        rd_turnmon = 0;
        sio_rd = 0;
        rd_sense = 0;

        casex ({
            boot,
            io_rd,
            examine_ce,
            examine_next_ce,
            deposit_next_ce,
            reset_ce,
            addr[15:8]})
            // Deposit Next
            {6'b000010,8'bxxxxxxxx}: begin idata = deposit_next_in; end
            // Examine
            {6'b001000,8'bxxxxxxxx}: begin idata = examine_out; end
            // Examine Next
            {6'b000100,8'bxxxxxxxx}: begin idata = examine_next_out; end
            // Reset
            {6'b000001,8'bxxxxxxxx}: begin idata = reset_out; end
            // MEM MAP
            {6'b000000,8'bxxxxxxxx}: begin idata = rammain_out; rd_rammain = rd; end
            default: begin idata = 8'h00; end
        endcase

        casex ({io_rd, examine_ce, examine_next_ce, reset_ce, addr[7:0]})
            // I/O MAP - addr[15:8] == addr[7:0] for this section
            {4'b1000,8'b00xx00xx}: begin idata = sio_out; sio_rd = rd; end
            {4'b1000,8'b11111111}: begin idata = sense_sw_out; rd_sense = rd; end       // sense switch port at 0xff
            {4'b1000,8'b01100xxx}: begin idata = fdc_data_out; end                      // Versafloppy port 60h-67h
            default: begin end
        endcase

    end

    ///////// CHIP SELECT - output from cpu or deposit ////////////
    always @(*) begin
        sio_we = 0;
        wr_rammain = 0;
        rammain_in = 8'b0;
        sio_in = 8'b0;
        fdc_data_in = 8'b0;
        fdc_we = 0;

        casex ({io_wr,
            examine_ce,
            examine_next_ce,
            deposit_we,
            deposit_next_we,
            reset_ce,
            addr[15:8]})
        
            // MEM MAP
            {6'b000000,8'bxxxxxxxx}: begin rammain_in = odata; wr_rammain = ~wr_n; end
            {6'b000100,8'bxxxxxxxx}: begin rammain_in = deposit_in; wr_rammain = 1; end
            {6'b000010,8'bxxxxxxxx}: begin rammain_in = deposit_next_in; wr_rammain = 1; end
            default: begin end // Add this default case
        endcase
        casex ({io_wr, examine_ce, examine_next_ce, addr[7:0]})
            // I/O MAP - addr[15:8] == addr[7:0] for this section
            {3'b100,8'b11111111}: if (~wr_n) programmed_output_leds <= odata;
            {3'b100,8'b00xx00xx}: begin sio_in = odata; sio_we = ~wr_n; end
            {3'b100,8'b01100xxx}: begin fdc_data_in = odata; fdc_we = ~wr_n; end                    // Versafloppy port 60h-67h
            default: begin end // Add this default case
        endcase
    end

    ///////// CLOCKS and RESET ////////////
    reg [15:0] div1ms;
    reg ms, intrq;
    wire rst_n;
    
    always @(posedge clk) begin
        if (div1ms == ((SYS_CLK / 1000) - 1)) begin
            div1ms <= 16'h0000;
            ms <= 1;
        end else begin
            div1ms <= div1ms + 16'h0001;
            ms <= 0;
        end

        if (ms) intrq <= 1;
        if (interrupt_ack) intrq <= 0;

        if (reset) begin 
            rcnt <= 8'h00; 
        end else if (rcnt != 8'hFF) rcnt <= rcnt + 8'h01;
    end



    always @(*) begin
        interrupt_ack <= sysctl[0];
        mem_wr_n <= ~sysctl[1];
        io_stack <= sysctl[2];
        halt_ack <= sysctl[3];
        io_wr <= sysctl[4];
        m1 <= sysctl[5];
        io_rd <= sysctl[6];
        mem_rd <= sysctl[7];

        debug_leds[0] <= rd_boot;
        debug_leds[1] <= rd_turnmon;
        debug_leds[4] <= rd_rammain;
        debug_leds[5] <= wr_rammain;
        debug_leds[6] <= sio_rd;
        debug_leds[7] <= sio_we;

        cpu_addr <= addr;
        data_leds <= rammain_out;
        rst_n = (rcnt == 8'hFF);
  
        extram_addr[15:0] = addr[15:0];
        extram_rd = rd_rammain;
        extram_we = wr_rammain;
        rammain_out = extram_data_out;
        extram_data_in = rammain_in;
        
        sio_addr = addr[0];
    end


    vm80a_core cpu(
        .pin_clk(clk),
        .pin_f1(f1),
        .pin_f2(f2),
        .pin_reset(~rst_n),
        .pin_a(addr),
        .pin_dout(odata),
        .pin_din(idata),
        .pin_hold(hold_in),
        .pin_ready(xrdy),
        .pin_int(intr_in),
        .pin_wr_n(wr_n),
        .pin_dbin(rd),
        .pin_inte(cpu_inte_o),
        .pin_hlda(cpu_hlda_o),
        .pin_wait(cpu_wait_o),
        .pin_sync(cpu_sync)
    );

    debouncer step_debouncer(
        .clk(clk),
        .i_btn(step_switch & ~run), 
        .o_state(),
        .o_ondn(step_switch_down),
        .o_onup()
    );

    debouncer deposit_debouncer(
        .clk(clk),
        .i_btn(deposit_switch & ~run), 
        .o_state(),
        .o_ondn(deposit_switch_down),
        .o_onup()
    );

    deposit deposit_fsm(
        .clk(clk),
        .reset(~rst_n),
        .deposit(deposit_switch_down),
        .data_sw(data_addr_in),
        .data_out(deposit_in),
        .we(deposit_we)
    );


    debouncer deposit_next_debouncer(
        .clk(clk), 
        .i_btn(deposit_next_switch & ~run), 
        .o_state(),
        .o_ondn(deposit_next_switch_down),
        .o_onup()
    );

    deposit_next deposit_next_fsm(
        .clk(clk),
        .reset(~rst_n),
        .sync(cpu_sync),
        .deposit(deposit_next_switch_down),
        .data_sw(data_addr_in),
        .ce(deposit_next_ce),
        .we(deposit_next_we),
        .data_out(deposit_next_in)
    );

  
    debouncer examine_debouncer(
        .clk(clk), 
        .i_btn(examine_switch & ~run),
        .o_state(),
        .o_ondn(examine_switch_down),
        .o_onup()
    );

    examine examine_fsm(
        .clk(clk),
        .reset(~rst_n),
        .sync(cpu_sync),
        .examine(examine_switch_down),
        .data_out(examine_out),
        .lo_addr(data_addr_in),
        .hi_addr(addr_sense_in),
        .ce(examine_ce)
    );
  
    debouncer examine_next_debouncer(
        .clk(clk), 
        .i_btn(examine_next_switch & ~run),
        .o_state(),
        .o_ondn(examine_next_switch_down),
        .o_onup()
    );

    examine_next examine_next_fsm(
        .clk(clk),
        .reset(~rst_n),
        .sync(cpu_sync),
        .examine(examine_next_switch_down),
        .data_out(examine_next_out),
        .ce(examine_next_ce)
    );
  
    debouncer reset_debouncer(
        .clk(clk), 
        .i_btn(reset_switch & ~run),
        .o_state(),
        .o_ondn(reset_switch_down),
        .o_onup()
    );

    reset reset_fsm(
        .clk(clk),
        .reset(~rst_n),
        .sync(cpu_sync),
        .reset_in(reset_switch_down),
        .data_out(reset_out),
        .ce(reset_ce)
    );

    sense_switch sense_sw(
        .clk(clk),
        .rd(rd_sense),
        .data_out(sense_sw_out),
        .switch_settings(addr_sense_in)
    );

endmodule
