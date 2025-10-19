
module PMD85_2A (

    input clk_50M, // 50MHz main clock
    input clk_8M,  // 8MHz clock for audio (SAA1099)
    input clk_sys, // PMD85 system clock (for 8224) is 18.432MHz
    input reset_main,
    
    input [10:0] ps2_key,
    input [24:0] ps2_mouse,

    output clk_video,
    output SR_n,
    output SD_n,
    output ZAT_n,
    output pixel,

    input tape_in,
    input  wire RxD,
    output wire TxD,

    input audioMode,                // 0 = Beeper, 1 = Beeper + MIF85
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,

    input [1:0] joystickPort,       // 00 = None, 01 = K3, 10 = K4
    input [15:0] joy0,
    input [15:0] joy1,
    input mouseEnabled,

    input [1:0] ColorMode,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,

    output LED_YELLOW,
    output LED_RED,
    output allRam_n,

    input ioctl_download,          // signal indicating an active download
    input [7:0] ioctl_index,       // menu index used to upload the file
    input ioctl_wr,
    input [26:0] ioctl_addr,       // in WIDE mode address will be incremented by 2
    input [7:0] ioctl_dout,
    
    output [15:0] sdram_addr,
    output [7:0] sdram_data_in,
    input [7:0] sdram_data_out,
    output sdram_wr,
    output sdram_rd
);


//---------------------------------------------- i8224 + i8080 + i8228 ---------------------------------------------------------
//
wire osc;
wire phi1;
wire phi2;
wire sync;
wire reset; // reset from i8224 to 8080
wire ststb_n; // strobe from 8224 to 8228


wire hold = 0; // 8080 hold pin
wire [15:0] address_bus;
wire [7:0] data_bus;
wire [7:0] data8080;
wire int8080_n;
wire int8080Enable;
wire wait8080;
wire dbin;
wire wr_n;
wire hlda;

wire readyin = 'b1;
wire ready;


wire memr_n;
wire memw_n;
wire ior_n;
wire iow_n;
wire inta_n;
wire ststb_nX;

i8224 i8224(
    .osc(osc),
    .phi1(phi1),
    .phi2(phi2),
    .ststb_n(ststb_n),
    .reset(reset),
    .ready(ready),
    .clk(clk_sys),
    .sync(sync),
    .resetin_n(~reset_main),
    .readyin(readyin)
);


// 8080 not ready when VIDEO
reg last_status_D1;
wire ready8080;
assign ready8080 = last_status_D1 ^ VIDEO; 

always @(posedge ststb_n) begin
    last_status_D1 <= data8080[1];
end


vm80a cpu (
    .pin_clk(osc),
    .pin_f1(phi1),
    .pin_f2(phi2),
    .pin_reset(reset),
    .pin_hold(hold),
    .pin_ready(ready8080), 
    .pin_int(~int8080_n),
    .pin_inte(int8080Enable),
    .pin_a(address_bus),
    .pin_d(data8080),
    .pin_dbin(dbin),
    .pin_wr_n(wr_n),
    .pin_hlda(hlda),
    .pin_sync(sync),
    .pin_wait(wait8080)
);


wire busen_n;
assign busen_n = VIDEO;

i8228 i8228(
    .memr_n(memr_n),
    .memw_n(memw_n),
    .ior_n(ior_n),
    .iow_n(iow_n),
    .inta_n(inta_n),
    .inta_12V(1'b1),
    .d8080(data8080),
    .db(data_bus),
    .busen_n(busen_n),
    .ststb_n(ststb_n),
    .dbin(dbin),
    .wr_n(wr_n),
    .hlda(hlda)
);


//------------------------------- Interface board (ifc) ------------------------------------------------
//  
//
reg clk_1Hz; // 1Hz clock - replacement for original U114/MHA1116
reg [25:0] cnt_1Hz;

always @(posedge osc) begin
    if (cnt_1Hz == 26'd18432000) begin
        clk_1Hz <= ~clk_1Hz;
        cnt_1Hz <= 26'd0;
    end else
        cnt_1Hz <= cnt_1Hz  + 1;
end


wire ifc_CS1_n;
wire ifc_CS4_n;
wire ifc_CS5_n;
wire ifc_CS7_n;
wire [7:0] data_bus_K2;
wire ifc_k2_OE;

wire ifc_clk0;
wire ifc_gate0;
wire ifc_out0;
wire ifc_gate1;
wire ifc_out1;

wire [7:0] ifc_PA_K34;
wire [7:0] ifc_PB_K34;
wire [7:0] ifc_PC_K34;

assign ifc_CS1_n = ~(address_bus[4] & ~address_bus[5] & ~address_bus[6] & ~address_bus[7]);
assign ifc_CS4_n = ~(~address_bus[4] & ~address_bus[5] & address_bus[6] & ~address_bus[7]);
assign ifc_CS5_n = ~(address_bus[4] & ~address_bus[5] & address_bus[6] & ~address_bus[7]);
assign ifc_CS7_n = ~(address_bus[4] & address_bus[5] & address_bus[6] & ~address_bus[7]);
assign ifc_k2_OE = address_bus[3] & address_bus[2] & address_bus[7];
assign data_bus_K2 = (ifc_k2_OE & ior_n & ~iow_n) ? data_bus : 8'bzz;
wire RTS_CTS;

i8251 ifc_i8251(
    .CLK(phi2),
    .RESET(reset),
    .CS_n(ifc_CS1_n),
    .WR_n(iow_n),
    .RD_n(ior_n),
    .CD(address_bus[0]),
    .D(data_bus),

    .TxD(TxD),
    .TxC_n(ifc_out1),
    
    .RxD(RxD),
    .RxC_n(ifc_out1),
    
    .DSR_n(~tape_in),
    
    .CTS_n(RTS_CTS),
    .RTS_n(RTS_CTS)
);


assign ifc_gate0 = 1;
assign ifc_gate1 = 1;

k580vi53 ifc_i8253(
    .clk_sys(osc),
    .reset(reset),
    .addr({address_bus[1], address_bus[0]}),
    .din(data_bus),
    .dout(data_bus),
    .wr(~iow_n & ~ifc_CS5_n),
    .rd(~ior_n & ~ifc_CS5_n),
    .clk_timer({clk_1Hz, phi2, ifc_clk0}),
    .gate({1'b1, ifc_gate1, ifc_gate0}),
    .out({ ifc_out1, ifc_out0})
);


i8255 ifc_i8255_K34(
    .PA(ifc_PA_K34),
    .PB(ifc_PB_K34),
    .PC(ifc_PC_K34),
    .DIn(data_bus),
    .DOut(data_bus),
    .clk(osc),
    .RD_n(ior_n),
    .WR_n(iow_n),
    .A({address_bus[1], address_bus[0]}),
    .RESET(reset),
    .CS_n(ifc_CS4_n)
);


//-------------------------------------------------------------------------------
// Joystick

wire [15:0] joy;
assign joy = joy0 | joy1;

assign ifc_PA_K34 = ifc_PC_K34[4] ? 
    ((joystickPort == 2'b01) ? {3'b111, (joy[7:4] == 4'b0000), ~joy[1], ~joy[0], ~joy[3], ~joy[2] } : 8'hFF) : 
    8'hzz; // Joy 1 = K3 GPIO 0
assign ifc_PB_K34 = ifc_PC_K34[0] ? 
    ((joystickPort == 2'b10) ? {3'b111, (joy[7:4] == 4'b0000), ~joy[1], ~joy[0], ~joy[3], ~joy[2] } : 8'hFF) : 
    8'hzz; // Joy 1 = K4 GPIO 1

//-------------------------------------------------------------------------------	
// Mouse

wire [7:0] MouseData;
wire MouseLButton;
wire MouseRButton;
wire [7:0] MouseXMovement;
wire MouseXMovementSign;
wire [7:0] MouseYMovement;
wire MouseYMovementSign;
reg MouseX1;
reg MouseX2;
reg MouseY1;
reg MouseY2;
wire MouseEvent;
reg MouseEventLast;
reg MouseStop;


assign data_bus = (ifc_k2_OE && ~ior_n && iow_n && mouseEnabled) ? MouseData : 8'bzz;
assign MouseData = {MouseRButton, MouseLButton, 2'b00, MouseX2, MouseX1, MouseY1, MouseY2};


assign ifc_clk0 = mouseEnabled ? ifc_out1 : 1'bz;
assign int8080_n = mouseEnabled ? ifc_out0 : 1'bz;

assign MouseEvent = ps2_mouse[24];
assign MouseLButton = ps2_mouse[0];
assign MouseRButton = ps2_mouse[1];
assign MouseXMovement = (MouseXMovementSign) ? ~ps2_mouse[15:8] : ps2_mouse[15:8];
assign MouseYMovement = (MouseYMovementSign) ? ~ps2_mouse[23:16] : ps2_mouse[23:16];
assign MouseXMovementSign = ps2_mouse[4]; // 1 = left
assign MouseYMovementSign = ps2_mouse[5]; // 1 = down
 
  
wire clk_4Hz; // 4Hz clock 
wire clk_260Hz; // 260Hz clock 
reg [25:0] cnt_4Hz;
reg [25:0] cnt_260Hz;
reg [8:0] mouseFreq;

always @(clk_50M or MouseEvent) begin
    if (MouseEvent != MouseEventLast)
    begin
        MouseEventLast <= MouseEvent;
        MouseStop <= 0;
        cnt_4Hz <= 26'd0;
    end
    else 
        if (cnt_4Hz == 26'd25_000_000) begin
        clk_4Hz <= ~clk_4Hz;
        cnt_4Hz <= 26'd0;
        MouseStop <= 1;
    end else
        cnt_4Hz <= cnt_4Hz  + 1'd1;
end 

always @(posedge clk_50M) begin
    if (cnt_260Hz == 26'd192_307) begin	// 260 Hz
    //if (cnt_260Hz == 26'd384_615) begin	// 130 Hz
        clk_260Hz <= ~clk_260Hz;
        cnt_260Hz <= 26'd0;
        mouseFreq <= mouseFreq + 1'd1;
    end else
        cnt_260Hz <= cnt_260Hz  + 1'd1;
end 
  
wire MouseXclk;  
assign MouseXclk = (MouseStop) ? 1'b0 :
    (MouseXMovement[7:6] != 2'b00) ? mouseFreq[0] :
    (MouseXMovement[5:4] != 2'b00) ? mouseFreq[1] :
    (MouseXMovement[3] != 1'b0) ? mouseFreq[2] :
    (MouseXMovement[2] != 1'b0) ? mouseFreq[3] :
    (MouseXMovement[1] != 1'b0) ? mouseFreq[4] :
    // (MouseXMovement[0] != 1'b0) ? mouseFreq[5] :
    1'b0;

always @(posedge MouseXclk)
begin
    MouseX1 <= MouseX2 ^ (~MouseXMovementSign);
    MouseX2 <= MouseX1 ^ MouseXMovementSign;
end

wire MouseYclk;  
assign MouseYclk = (MouseStop) ? 1'b0 :
    (MouseYMovement[7:6] != 2'b00) ? mouseFreq[0] :
    (MouseYMovement[5:4] != 2'b00) ? mouseFreq[1] :
    (MouseYMovement[3] != 1'b0) ? mouseFreq[2] :
    (MouseYMovement[2] != 1'b0) ? mouseFreq[3] :
    (MouseYMovement[1] != 1'b0) ? mouseFreq[4] :
    //(MouseYMovement[0] != 1'b0) ? mouseFreq[5] : 
    1'b0;

always @(posedge MouseYclk)
begin
    MouseY1 <= MouseY2 ^ (~MouseYMovementSign);
    MouseY2 <= MouseY1 ^ MouseYMovementSign;
end	
 
 
 
//-------------------------------------------------------------------------------	
// MIF85 - Sound card
//
wire MIF85_CS_n;
wire [7:0] MIF85_L;
wire [7:0] MIF85_R;
wire MIF85_IntWrite_CS;
reg MIF85_IntEnable;
reg [6:0] MIF85_cnt;
wire MIF85Enabled;

assign MIF85Enabled = (audioMode == 1'b1);

initial begin
    MIF85_IntEnable = 1;
    MIF85_cnt = 7'd0;
end

assign MIF85_CS_n =  ~(address_bus[7:1] == 7'b1110111); // 0xEE, 0xEF
assign MIF85_IntWrite_CS = (address_bus == 8'b11101100) & ~iow_n; // 0xEC
assign int8080_n = (MIF85Enabled && MIF85_IntEnable) ? ~(MIF85_cnt != 7'd0) : 1'bz; 
assign ifc_clk0 = (MIF85Enabled) ? ~phi2 : 1'bz;
 

always @(posedge clk_8M)  // 12us pulse for INT
begin
    if (~ifc_out0 & MIF85_IntEnable & (MIF85_cnt == 7'd0))
        MIF85_cnt <= 7'd100;
    else
    if (MIF85_cnt != 7'd0)
        MIF85_cnt <= MIF85_cnt - 1;
end

always @(posedge MIF85_IntWrite_CS)
begin
    MIF85_IntEnable <= data_bus[0];
end
  
saa1099 MIF85(
    .clk_sys(clk_sys),
    .ce(clk_8M),
    .rst_n(~reset),
    .cs_n(MIF85_CS_n),
    .a0(address_bus[0]),
    .wr_n(iow_n),
    .din(data_bus),
    .out_l(MIF85_L),
    .out_r(MIF85_R)
);
  
  
//-------------------------------------------------------------------------------
//  Keyboard + Beeper
//
wire [7:0] PA;
wire [7:0] PB;
wire [7:0] PC;
wire PCHisInput;
 
i8255 Key8255(
    .PA(PA),
    .PB(PB),
    .PC(PC),
    .DIn(data_bus),
    .DOut(data_bus),
    .PCHisInput(PCHisInput),
    .clk(osc),
    .RD_n(ior_n),
    .WR_n(iow_n),
    .A({address_bus[1], address_bus[0]}),
    .RESET(reset),
    .CS_n(address_bus[3])
);


keyboard keyboard(
    .reset(reset), 
    .clk(osc), 
    .ps2_key(ps2_key), 
    .row(PA[3:0]), 
    .columns(PB)
);

wire Beeper;
assign Beeper = PC[0] & r[9] | PC[1] & r[7] | PC[2];
assign LED_RED = PC[3];
assign LED_YELLOW = Beeper;

assign AUDIO_L = (Beeper ? 16'h0FFF : 16'h00) | (audioMode ? { MIF85_L, MIF85_L } : 16'h00);
assign AUDIO_R = (Beeper ? 16'h0FFF : 16'h00) | (audioMode ? { MIF85_R, MIF85_R } : 16'h00);

//-------------------------------------------------------------------------------
//  ROMPack module
//
wire [15:0] ROMPack_address;
wire [7:0] ROMPack_data;
wire [7:0] ROMPack_dataX;


i8255 ROMPack8255(
    .PA(ROMPack_data),
    .PB(ROMPack_address[7:0]),
    .PC(ROMPack_address[15:8]),
    .DIn(data_bus), 
    .DOut(data_bus),
    .clk(osc),
    .RD_n(ior_n),
    .WR_n(iow_n),
    .A({address_bus[1], address_bus[0]}),
    .RESET(reset),
    .CS_n(address_bus[2])
);

assign ROMPack_data = (~reset ? ROMPack_dataX : 8'hzz);

dpram #(.ADDRWIDTH(15)) myROMPack(
    .clock(osc),
    .address_a(ROMPack_address),
    .q_a(ROMPack_dataX),
    
    .wren_a(0),
    .address_b(ioctl_addr),
    .data_b(ioctl_dout),
    .wren_b((ioctl_index == 8'd1) & ioctl_wr & ioctl_download)
);
 
 
//-------------------------------------------------------------------------------
// RAS + CAS + AMUX + STB + VIDEO signal generator - originaly with 74LS164
//

reg [7:0] clk_shift;
reg VIDEO; // video signal for driving address multiplexer
wire RAS_n;
wire CAS;
wire STB_n;
wire AMUX;

initial begin
    clk_shift = 0;
    VIDEO = 0;
end

assign RAS_n = ~clk_shift[2];
//assign CAS = clk_shift[4]; // takto je to nakresleno ve schematu barevnem <-- asi chyba!
assign CAS = ~( clk_shift[1] & clk_shift[7] ); // schema v3?
//assign STB_n = ~( VIDEO & clk_shift[4] & clk_shift[6] ); // IC51C -- takhle je to nakresleno ve schematu
assign STB_n = ~( VIDEO & clk_shift[4] & clk_shift[7] ); // IC51C -- tohle je z opravarenskeho manualu asi PMD v1?
assign AMUX = clk_shift[7];
assign clk_video = ~( ~( clk_shift[1] & clk_shift[7] ) & // IC38D
    ~( clk_shift[1] & clk_shift[4] ) & // IC38B
    ~( clk_shift[3] & clk_shift[7] )); // IC38C

 
always @(posedge osc) 
begin
    clk_shift <= { clk_shift[6:0], phi2 };
end

 
always @(posedge CAS) // 74LS93 is sensitive on negative edge
begin 
    VIDEO <= ~VIDEO; 
end 


//-------------------------------------------------------------------------------
// refresh (+ video) address generator - originaly with 4x 74LS93 (sensitive on negative edge)
//
reg [14:0] r; // refresh + video mem address
wire [14:0] rNext;

assign rNext = r + 1;

initial begin
    r = 0;
end

always @(posedge STB_n) begin // 74LS93 is sensitive on negative edge
    if (rNext[12] & rNext[14]) begin
        r <= 15'd0;
    end
    else begin
        r <= r + 1;
    end
end


//-------------------------------------------------------------------------------
// CS + CAS7 coder - originaly made with 2x 3205
wire [3:0] csTmp;
wire [3:0] cs; // driving eprom chips CS
// wire allRam_n; // 1 .. ROM, 0 .. RAM only - declared in module ports
wire CAS7_n;
reg postReset;

initial begin
    postReset = 1;
end


assign allRam_n = PCHisInput ? 1'b1 : PC[4]; // if 8255 PC Hi port is setup as input, pullup rezistor do it's job


always @(posedge clk_sys) begin

    if (reset)
        postReset <= 1;
    else if (~iow_n) 
        postReset <= 0;
end


wire isEprom = (~memr_n & ~address_bus[12] & ~address_bus[14] & allRam_n & ~VIDEO & (address_bus[15] | postReset));
assign csTmp = (address_bus[12:10] == 3'b000) ? 4'b0001 :
               (address_bus[12:10] == 3'b001) ? 4'b0010 :
               (address_bus[12:10] == 3'b010) ? 4'b0100 :
               (address_bus[12:10] == 3'b011) ? 4'b1000 : 4'b0000;
assign cs = isEprom ? csTmp : 4'b0000;

assign CAS7_n = ~((~memr_n | ~memw_n | VIDEO) & CAS & ~isEprom);


//------------------------------- ADDRESS MULTIPLEXER + SWITCHER ------------------------------------------------
//
// RAM addresses mux - originaly made with 4x 74LS153
// AMUX = 0 => cols; AMUX = 1 => rows
// VIDEO = 0 => cpu address; VIDEO = 1 => refresh + video address

wire [7:0] addrRam;

assign addrRam = // this is address shown to DRAM module
    (({AMUX, VIDEO}) == 2'b00) ? address_bus[14:7] :  // address cols
    (({AMUX, VIDEO}) == 2'b01) ? {1'b1, r[13:7]} :  // refresh + video cols
    (({AMUX, VIDEO}) == 2'b10) ? {address_bus[15], address_bus[6:0]} :  // address rows
    (({AMUX, VIDEO}) == 2'b11) ? {1'b1, r[6:0]} : 8'bzzzzzzz;  //refresh + video cols


wire [15:0] addrRamMAX =            // this is address shown to DRAM module
    (VIDEO) ? { 2'b11, r[13:0] } :  // refresh + video cols
    address_bus[15:0] ;             // address cols
 
//-------------------------------------------------------------------------------------------------------------
// VIDEOPROCESSOR
// MOD = Modularní videosignál = pixel
// SD_n = Vertical Sync
// SR_n = Horizontal Sync
// ZAT = blank signal (ZAT_n ... 1 = display ON, 0 = display off) 
wire blink;
wire rowActive_n;
wire rowActiveReset_n;
wire rowActiveSet_n;

reg rowActive;
reg [5:0] pixelBuffer; // 6 pixels to be rolled out with video clock
reg [1:0] pixelFunction; // attributes to these 6 pixels; pixelFunction[1] = F2, pixelFunction[0] = F1

initial begin
    rowActive = 0;
end

assign SD_n = ~((~r[8] & ~r[9] & ~r[10] ) & r[11] & r[14]);
assign SR_n = ~(r[2] & ~r[3] & rowActive_n);
assign ZAT_n = (~r[14] & ~rowActive_n);

assign rowActive_n = ~rowActive;
assign rowActiveReset_n = ~(r[5] & r[4] & r[0]); // this is when row is beyond display area
assign rowActiveSet_n = ~(~r[5] & r[0]); // this is when row begins to be active


always @(rowActiveReset_n or rowActiveSet_n) begin
    if (~rowActiveReset_n) rowActive <= 0;
    else if (~rowActiveSet_n) rowActive <= 1;
end


// blink signal for pixel function bits (should be 500ms)
reg [13:0] blinkCounter;
always @(posedge r[9]) begin
    blinkCounter <= blinkCounter + 1;
end

assign blink = blinkCounter[9];
assign pixel = pixelBuffer[5] & ZAT_n;
 
always @(posedge ~STB_n or posedge clk_video) begin
    if (~STB_n) begin
        pixelBuffer <= {data_bus[0], data_bus[1], data_bus[2], data_bus[3], data_bus[4], data_bus[5]};
        pixelFunction <=  data_bus[7:6];
    end
    else
    if (clk_video) begin
        pixelBuffer <= { pixelBuffer[4:0], 1'b0 };
    end
end


assign VGA_R = (ColorMode == 2'b00) ? ColorGreen_R : 
    (ColorMode == 2'b01) ? ColorTV_R : 
    (ColorMode == 2'b10) ? ColorRGB_R : 
    ColorAce_R;

assign VGA_G = (ColorMode == 2'b00) ? ColorGreen_G : 
    (ColorMode == 2'b01) ? ColorTV_G : 
    (ColorMode == 2'b10) ? ColorRGB_G : 
    ColorAce_G;

assign VGA_B = (ColorMode == 2'b00) ? ColorGreen_B : 
    (ColorMode == 2'b01) ? ColorTV_B : 
    (ColorMode == 2'b10) ? ColorRGB_B : 
    ColorAce_B;

//-----------------------------Color Green-----------------------------

wire [7:0] ColorGreen_R = 8'h00;
wire [7:0] ColorGreen_G = (pixel & (pixelFunction[1] ? blink : 1'b1)) ? (pixelFunction[0] ? 8'h80 : 8'hFF): 8'h00;
wire [7:0] ColorGreen_B = 8'h00;

//-----------------------------Color TV--------------------------------
//7 6 	TV 								TV - PMD 85-3 		RGB
//-----------------------------------------------------------------------
//0 0 	normálny jas 	  	 			#FFFFFF				#008000 zelený
//0 1 	zní?ený jas 	  	 			#DFDFDF				#FF0000 ?ervený
//1 0 	normálny jas s blikaním 	#BFBFBF				#0000FF modrý
//1 1 	zní?ený jas s blikaním		#9F9F9F				#FF00FF r??ový

wire [7:0] ColorTV_R = 	~pixel ? 8'h00 : 
    pixelFunction == 2'b00 ? 8'hFF : 
    pixelFunction == 2'b01 ? 8'hDF :
    pixelFunction == 2'b10 ? 8'hBF : 8'h9F;
wire [7:0] ColorTV_G = ColorTV_R;
wire [7:0] ColorTV_B = ColorTV_R;

//-----------------------------Color RGB-------------------------------
wire [7:0] ColorRGB_R = pixel & pixelFunction[0] ? 8'hFF : 8'h00;
wire [7:0] ColorRGB_G = pixel & (pixelFunction == 2'b00) ? 8'h80 : 8'h00;
wire [7:0] ColorRGB_B = pixel & pixelFunction[1] ? 8'hFF : 8'h00;

//----------------------------- Color ACE ----------------------------------
wire [15:0] colorAceAddr;
wire [7:0] colorAceRAMData;
reg [1:0] colorAcePixelFunction;

assign colorAceAddr = {addrRamMAX[15:7], ~addrRamMAX[6], addrRamMAX[5:0]};

always @(posedge ~STB_n)
begin
    colorAcePixelFunction <= colorAceRAMData[7:6];
end


wire [7:0] ColorAce_R   = ((pixelFunction[0] | colorAcePixelFunction[0]) & pixel) ? 8'hFF : 8'h00;
wire [7:0] ColorAce_G = (((pixelFunction == 2'b00) | (colorAcePixelFunction == 2'b00)) & pixel) ? 8'hFF : 8'h00;
wire [7:0] ColorAce_B  = ((pixelFunction[1] | colorAcePixelFunction[1]) & pixel) ? 8'hFF : 8'h00;


//-------------------------------------- EPROM ----------------------------------------------------------------------
wire [7:0] data_EPROM_out;
assign data_bus = (isEprom) ? data_EPROM_out : 8'bzz;
 
dpram #(
    .ADDRWIDTH(12),
    .MEM_INIT_FILE("./monit2A.mif")
) myEPPROM(
    .clock(clk_sys),
    .address_a(addrRamMAX[12:0]),
    .wren_a(0),
    .q_a(data_EPROM_out)
);

//-------------------------------------- RAM ----------------------------------------------------------------------
wire [7:0] data_RAM_out;

assign data_bus = (~CAS7_n & memw_n) ? data_RAM_out : 8'bzz;

assign sdram_addr = addrRamMAX;
assign sdram_rd =  ~CAS7_n & memw_n;
assign sdram_wr = ~CAS7_n & ~memw_n;
assign sdram_data_in = data_bus;
assign data_RAM_out = sdram_data_out;


endmodule