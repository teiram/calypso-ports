
module imsai8080(
    input clk,
    input reset,
    input rx,
    input hold_in,
    input ready_in,
    
    output tx,
    output cpu_sync,
    output reg interrupt_ack,
    output reg mem_wr_n,
    output reg io_stack,
    output reg halt_ack,
    output reg io_wr,
    output reg m1,
    output reg io_rd,
    output reg mem_rd,
    output inte_o,
    output hlda_o,
    output wait_o,

    output reg [7:0] data_leds,
    output reg [15:0] addr_leds,

    output [7:0] programmed_output_leds,
    
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
    output extram_we
);

    parameter SYS_CLK = 36000000;
    
    reg intr = 0;
    reg [7:0] idata;
    wire [15:0] addr;
    wire wr_n;
    wire inta_n;
    wire [7:0] odata;
    reg f1, f2;
    reg [2:0] div;
    reg [15:0] div1ms;
    reg ms, intrq;
    wire rst_n;

    ////////////////////   STEP & GO   ////////////////////
    reg onestep;
    //reg cpu_flag;
    //reg[10:0] cpu_cnt;
    wire cpu_ce2;
    wire sio_clk;

    ///////// SINGLE STEP CONTROL ////////////
    frequency_divider #(.N(25), .WIDTH(20)) freq_cpu(
        .clk_in(clk),
        .clk_out(cpu_ce2),
        .rst(reset)
    );
  
    frequency_divider #(.N(25),.WIDTH(20)) freq_sio(
        .clk_in(clk),
        .clk_out(sio_clk),
        .rst(reset)
    );

    always @(posedge clk) begin
        reg step_switch_last;
        step_switch_last <= step_switch;
        onestep <= step_switch_last & ~step_switch;
    end

    reg pause_on = 1'b0;
    always @(posedge clk) begin
        reg stop_switch_last = 1'b0;
        reg run_switch_last = 1'b0;
        
        stop_switch_last <= stop_switch;
        run_switch_last <= run_switch;
        
        if (pause_on & ~run_switch_last & run_switch) pause_on <= 1'b0;
        if (~pause_on & ~stop_switch_last & stop_switch) pause_on <= 1'b1;
    end
    
    wire cpu_ce = onestep | 
        (cpu_ce2 & examine_latch & pause_on) |
        (cpu_ce2 & reset_latch & pause_on) |
        (cpu_ce2 & examine_next_latch & pause_on) |
        (cpu_ce2 & deposit_examine_next_latch & pause_on) |
        (cpu_ce2 & ~pause_on);

    reg[7:0] sysctl;

    wire [7:0] examine_out;
    wire [7:0] examine_next_out;
    wire [7:0] deposit_next_out;
    wire [7:0] reset_out;
    wire [7:0] sense_sw_out;
    wire [7:0] turnmon_out;
    wire [7:0] stack_out;
    wire [7:0] rammain_out;
    wire [7:0] boot_out;
    wire [7:0] sio_out;

    reg [7:0] sio_in;
    wire [7:0] deposit_in;
    wire [7:0] deposit_next_in;
    reg [7:0] stack_in;
    reg [7:0] rammain_in;

    wire boot;

    wire deposit_switch_down;
    wire deposit_latch;
    wire deposit_next_switch_down;
    wire deposit_next_latch;
    wire deposit_examine_next_latch;
    wire examine_switch_down;
    wire examine_latch;
    wire examine_next_switch_down;
    wire examine_next_latch;
    wire reset_switch_down;
    wire reset_latch;

    reg wr_stack;
    reg wr_rammain;
    reg wr_sio;

    wire rd;

    reg rd_boot;
    reg rd_stack;
    reg rd_rammain;
    reg rd_turnmon;
    reg rd_sio;
    reg rd_examine;
    reg rd_examine_next;
    reg rd_deposit_examine_next;
    reg rd_reset;
    reg rd_sense;


    reg  [7:0] rcnt = 8'h00;
    assign rst_n = (rcnt == 8'hFF);
  
    assign extram_addr[15:0] = addr[15:0];
    assign extram_rd = rd_rammain;
    assign extram_we = wr_rammain;
    assign rammain_out = extram_data_out;
    assign extram_data_in = rammain_in;

    assign programmed_output_leds = sense_sw_out;
    
    ///////// CHIP SELECT - input to cpu ////////////
    always @(*) begin
        rd_examine = 0;
        rd_examine_next = 0;
        rd_deposit_examine_next = 0;
        rd_reset = 0;
        rd_boot = 0;
        rd_stack = 0;
        rd_rammain = 0;
        rd_turnmon = 0;
        rd_sio = 0;
        rd_sense = 0;

        casex ({boot, io_rd, examine_latch & pause_on, examine_next_latch & pause_on,
            deposit_examine_next_latch & pause_on, reset_latch & pause_on, addr[15:8]})
            // Deposit Examine Next
            {6'b000010,8'bxxxxxxxx}: begin idata = deposit_next_out; rd_deposit_examine_next = rd; end // any address
            // Examine
            {6'b001000,8'bxxxxxxxx}: begin idata = examine_out; rd_examine = rd; end                   // any address
            // Examine Next
            {6'b000100,8'bxxxxxxxx}: begin idata = examine_next_out; rd_examine_next = rd; end         // any address
            // Reset
            {6'b000001,8'bxxxxxxxx}: begin idata = reset_out; rd_reset = rd; end                       // any address
            // Turn-key BOOT
            {6'b100000,8'bxxxxxxxx}: begin idata = boot_out; rd_boot = rd; end                         // any address
        
            // MEM MAP
            {6'b000000,8'b000xxxxx}: begin idata = rammain_out; rd_rammain = rd; end                   // 0x0000-0x1fff basic
            {6'b000000,8'b11111011}: begin idata = stack_out; rd_stack = rd; end                       // 0xfb00-0xfbff stack
            {6'b000000,8'b11111101}: begin idata = turnmon_out; rd_turnmon = rd & enable_turn_mon; end // 0xfd00-0xfdff turn-key rom
            default: begin idata = 8'h00; end // Add this default case
        endcase

        casex ({io_rd, examine_latch & pause_on, examine_next_latch & pause_on, reset_latch & pause_on, addr[7:0]})
            // I/O MAP - addr[15:8] == addr[7:0] for this section
            {4'b1000,8'b000x000x}: begin idata = sio_out; rd_sio = rd; end                             // 0x00-0x01 0x10-0x11 
            {4'b1000,8'b11111111}: begin idata = sense_sw_out; rd_sense = rd; end                      // sense switch port at 0xff
            default: begin end // Add this default case
        endcase

    end

    ///////// CHIP SELECT - output from cpu or deposit ////////////
    always @(*) begin
        wr_stack = 0;
        wr_sio = 0;
        wr_rammain = 0;
        rammain_in = 8'b0;
        stack_in = 8'b0;
        sio_in = 8'b0;
  
        casex ({io_wr, examine_latch & pause_on, examine_next_latch & pause_on,
            deposit_latch & pause_on, deposit_next_latch & pause_on, reset_latch & pause_on, addr[15:8]})
        
            // MEM MAP
            {6'b000000,8'b000xxxxx}: begin rammain_in = odata; wr_rammain = ~wr_n; end      // 0x0000-0x1fff basic
            {6'b000000,8'b11111011}: begin stack_in = odata; wr_stack = ~wr_n; end          // 0xfb00-0xfbff
            {6'b000100,8'bxxxxxxxx}: 
            begin 
                casex({io_wr, deposit_latch & pause_on, addr[15:8]})
                    {2'b01,8'b000xxxxx}: begin rammain_in = deposit_in; wr_rammain = 1; end      // 0x0000-0x1fff
                    {2'b01,8'b11111011}: begin stack_in = deposit_in; wr_stack = 1; end          // 0xfb00-0xfbff
                    default: begin end // Add this default case
                endcase
            end
            {6'b000010,8'bxxxxxxxx}: 
            begin 
                casex({io_wr, deposit_next_latch & pause_on, addr[15:8]})
                    {2'b01,8'b000xxxxx}: begin rammain_in = deposit_next_in; wr_rammain = 1; end // 0x0000-0x1fff
                    {2'b01,8'b11111011}: begin stack_in = deposit_next_in; wr_stack = 1; end     // 0xfb00-0xfbff
                    default: begin end // Add this default case
                endcase
            end
            // 0xfd00-0xfdff read-only turn-key rom
            default: begin end // Add this default case
        endcase
        casex ({io_wr, examine_latch & pause_on, examine_next_latch & pause_on, addr[7:0]})
            // I/O MAP - addr[15:8] == addr[7:0] for this section
            {3'b100,8'b000x000x}: begin sio_in = odata; wr_sio = ~wr_n; end                 // 0x00-0x01 0x10-0x11 
            default: begin end // Add this default case
        endcase
    end

    ///////// CLOCKS and RESET ////////////
    always @(posedge clk) begin
        div <= div + 3'b001;
        f1  <= div[0];
        f2  <= ~div[0];

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

    ///////// STATUS system control ////////////
    always @(posedge clk) begin
        reg sync_last;
        sync_last <= cpu_sync;
        if (~sync_last & cpu_sync) sysctl <= odata;
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
        debug_leds[2] <= rd_stack;
        debug_leds[3] <= wr_stack;
        debug_leds[4] <= rd_rammain;
        debug_leds[5] <= wr_rammain;
        debug_leds[6] <= rd_sio;
        debug_leds[7] <= wr_sio;

        data_leds <= idata;
        addr_leds <= addr;
    end


    ///////// CPU ////////////
    vm80a_core cpu(
        .pin_clk(clk),
        .pin_f1(cpu_ce),
        .pin_f2(~cpu_ce),
        .pin_reset(~rst_n),
        .pin_a(addr),
        .pin_dout(odata),
        .pin_din(idata),
        .pin_hold(hold_in),
        .pin_ready(ready_in),
        .pin_int(intr),
        .pin_wr_n(wr_n),
        .pin_dbin(rd),
        .pin_inte(inte_o),
        .pin_hlda(hlda_o),
        .pin_wait(wait_o),
        .pin_sync(cpu_sync)
    );


    ///////// BOOT ROM TURN-KEY ////////////
    reg enable_turn_mon = 1'b0;
    
    jmp_boot boot_ff(
        .clk(clk),
        .reset(~rst_n),
        .rd(rd_boot),
        .lo_addr(8'h00), // if turnmon use FD00
        .hi_addr(enable_turn_mon ? 8'hfd : 8'h00), // if turnmon use FD00 else 0000
        .data_out(boot_out),
        .valid(boot)
    );


    ///////// DEPOSIT ////////////
    debouncer deposit_debouncer(
        .clk(clk),
        .i_btn(deposit_switch & pause_on), 
        .o_state(),
        .o_ondn(deposit_switch_down),
        .o_onup()
    );

    deposit deposit_ff(
        .clk(clk),
        .reset(~rst_n),
        .deposit(deposit_switch_down),
        .data_sw(data_addr_in),
        .data_out(deposit_in),
        .deposit_latch(deposit_latch)
    );
  
  
    ///////// DEPOSIT NEXT ////////////
    debouncer deposit_next_debouncer(
        .clk(clk), 
        .i_btn(deposit_next_switch & pause_on), 
        .o_state(),
        .o_ondn(deposit_next_switch_down),
        .o_onup()
    );

    deposit_next deposit_next_ff(
        .clk(clk),
        .reset(~rst_n),
        .rd(rd_deposit_examine_next),
        .deposit(deposit_next_switch_down),
        .data_sw(data_addr_in),
        .deposit_out(deposit_next_in),
        .deposit_latch(deposit_next_latch),
        .data_out(deposit_next_out),
        .examine_latch(deposit_examine_next_latch)
    );
  
  
    ///////// EXAMINE ////////////
    debouncer examine_debouncer(
        .clk(clk), 
        .i_btn(examine_switch & pause_on),
        .o_state(),
        .o_ondn(examine_switch_down),
        .o_onup()
    );

    examine examine_ff(
        .clk(clk),
        .reset(~rst_n),
        .rd(rd_examine),
        .examine(examine_switch_down),
        .data_out(examine_out),
        .lo_addr(data_addr_in),
        .hi_addr(addr_sense_in),
        .examine_latch(examine_latch)
    );
  
    ///////// EXAMINE NEXT ////////////
    debouncer examine_next_debouncer(
        .clk(clk), 
        .i_btn(examine_next_switch & pause_on),
        .o_state(),
        .o_ondn(examine_next_switch_down),
        .o_onup()
    );

    examine_next examine_next_ff(
        .clk(clk),
        .reset(~rst_n),
        .rd(rd_examine_next),
        .examine(examine_next_switch_down),
        .data_out(examine_next_out),
        .examine_latch(examine_next_latch)
    );
  
    ///////// RESET ////////////
    debouncer reset_debouncer(
        .clk(clk), 
        .i_btn(reset_switch & pause_on),
        .o_state(),
        .o_ondn(reset_switch_down),
        .o_onup()
    );

    reset reset_ff(
        .clk(clk),
        .reset(~rst_n),
        .rd(rd_reset),
        .reset_in(reset_switch_down),
        .data_out(reset_out),
        .reset_latch(reset_latch)
    );

    ///////// SENSE SWITCHES ////////////
    sense_switch sense_sw(
        .clk(clk),
        .rd(rd_sense),
        .data_out(sense_sw_out),
        .switch_settings(addr_sense_in) // 0xFD for basic
    );


//  turnmon_mem #(.DATA_WIDTH(8),.ADDR_WIDTH(8)) turnmon(.clk(clk),.addr(addr[7:0]),.rd(rd_turnmon),.data_out(turnmon_out));

    bram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(8)
    ) stack_mem(
        .clk(clk),
        .addr(addr[7:0]),
        .data_in(stack_in),
        .rd(rd_stack),
        .we(wr_stack),
        .data_out(stack_out));

    // Pass ROM loading signals to memory module
    /*
    samples_mem_bin_io mainmem
    (
        .clk(clk),
        .addr(addr[12:0]),
        .data_in(rammain_in),
        .rd(rd_rammain),
        .we(wr_rammain),
        .data_out(rammain_out),
        .ioctl_download(ioctl_download),
        .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr),
        .ioctl_data(ioctl_dout),
        .ioctl_wait(ioctl_wait),  // Add this connection
        .rom_loaded(rom_loaded)
    );
    */
    /////////SERIAL TERMINAL////////////

    mc6850 #(
        .CLOCK(2000000),
        .BAUD(19200)) 
    sio(
        .clk(sio_clk),
        .reset(~rst_n),
        .addr(addr[0]),
        .data_in(sio_in),
        .rd(rd_sio),
        .we(wr_sio),
        .data_out(sio_out),
        .ce(0),
        .rx(rx),
        .tx(tx)
    );

endmodule
