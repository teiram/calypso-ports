//  Проект DVK-FPGA
//
//  Интерфейсный модуль для платы MiST
//=================================================================
//

`include "config.v"

module mist(
   input          CLOCK_27,     // clock input 27 MHz
   output         LED,          // индикаторный светодиод   

   // VGA
   output [5:0]   VGA_R,        // красный видеосигнал
   output [5:0]   VGA_G,        // зеленый видеосигнал
   output [5:0]   VGA_B,        // синий видеосигнал
   output         VGA_HS,       // горизонтальная синхронизация
   output         VGA_VS,       // вертикакльная синхронизация

   // AUDIO
   output         AUDIO_L,
   output         AUDIO_R,

   // Интерфейс SDRAM
   output [12:0]  SDRAM_A,      //   SDRAM Address bus 12 Bits
   inout  [15:0]  SDRAM_DQ,     //   SDRAM Data bus 16 Bits
   output         SDRAM_DQML,   //   SDRAM Low-byte Data Mask 
   output         SDRAM_DQMH,   //   SDRAM High-byte Data Mask
   output         SDRAM_nWE,    //   SDRAM Write Enable
   output         SDRAM_nCAS,   //   SDRAM Column Address Strobe
   output         SDRAM_nRAS,   //   SDRAM Row Address Strobe
   output         SDRAM_nCS,    //   SDRAM Chip Select
   output [1:0]   SDRAM_BA,     //   SDRAM Bank Address 0,1
   output         SDRAM_CLK,    //   SDRAM Clock
   output         SDRAM_CKE,    //   SDRAM Clock Enable

   // дополнительный UART 
   output         UART_TX,
   input          UART_RX,
   
   // SPI interface to arm io controller
   output         SPI_DO,
   input          SPI_DI,
   input          SPI_SCK,
   input          SPI_SS2,
   input          SPI_SS3,
//	input          SPI_SS4,
   input          CONF_DATA0

);
//--------------------------------------------
   // интерфейс SD-карты
   wire           sdcard_cs;
   wire           sdcard_mosi;
   wire           sdcard_sclk;
   wire           sdcard_miso;

   // PS/2
   wire           ps2_clk;
   wire           ps2_data;

   // VGA RGB
   wire [5:0] video_r, video_g, video_b;

   // пищалка
   wire nbuzzer;
   wire buzzer=~nbuzzer;

   assign AUDIO_L   = {buzzer};
   assign AUDIO_R   = {buzzer};

//********************************************
//* Светодиоды
//********************************************
wire dm_led, rk_led, dw_led, my_led, dx_led, timer_led;

//************************************************
//* тактовый генератор 
//************************************************
wire clk_p;
wire clk_n;
wire sdclock;
wire clkrdy;
wire clk50;
wire pixelclk;

pll pll1 (
   .inclk0(CLOCK_27),
   .c0(clk_p),     // 100МГц прямая фаза, основная тактовая частота
   .c1(clk_n),     // 100МГц инверсная фаза
//   .c2(sdclock),   // 12.5 МГц тактовый сигнал SD-карты
   .c3(clk50),     // 50 МГц, тактовый сигнал терминальной подсистемы
   .c4(pixelclk),  // 40 МГц тактовый сигнал pixelclock
   .locked(clkrdy) // флаг готовности PLL
);

reg [2:0] counter = 0;   // 12.5 МГц тактовый сигнал SD-карты
always @(posedge clk_p)  // Делитель частоты на 8 для SD-Card
    counter <= counter + 1'b1;

assign sdclock = counter[2]; // 12.5 МГц тактовый сигнал SD-карты

//**********************************
//* Модуль динамической памяти
//**********************************
wire       sdram_reset;
reg        sdram_ready;

reg  [1:0] dreset;
reg  [1:0] dr_cnt;
reg        drs;

always @(posedge clk_p)
   begin
      if (sdram_reset) sdram_ready <= 1'b0;
      else sdram_ready <= sdram_ready | sdr_ack;
   end
// формирователь сброса
always @(posedge clk_p)
begin
   dreset[0] <= sdram_reset; // 1 - сброс
   dreset[1] <= dreset[0];
   if (dreset[1] == 1) begin
     // системный сброс активен
     drs<=0;         // активируем сброс DRAM
     dr_cnt<=2'b0;   // запускаем счетчик задержки
   end  
   else 
     // системный сброс снят
     if (dr_cnt != 2'd3) dr_cnt<=dr_cnt+1'b1; // счетчик задержки ++
     else drs<=1'b1;                          // задержка окончена - снимаем сигнал сброса DRAM
end

//------- SDRAM -------------------------------------
// стробы чтения и записи в sdram
wire        sdram_we;
wire        sdram_stb;
wire  [1:0] sdram_sel;
wire        sdram_ack;
wire [21:1] sdram_adr;
wire [15:0] sdram_out;
wire [15:0] sdram_dat;
wire        sdram_wr = sdram_we & sdram_stb;
wire        sdram_rd = (~sdram_we) & sdram_stb;

// стробы подтверждения
wire sdr_ack;
// тактовый сигнал на память - инверсия синхросигнала шины
assign SDRAM_CLK=clk_n;

sdram sdram(
   .clk        (clk_p),
   .init       (~drs),          // запускаем модуль, как только pll выйдет в рабочий режим, запуска процессора не ждем
   .we         (sdram_wr),      // cpu requests write
   .rd         (sdram_rd),      // cpu requests read
   .ready      (sdr_ack),       // dout is valid. Ready to accept new read/write.
   .wtbt       (sdram_sel),     // 16bit mode:  bit1 - write high byte, bit0 - write low byte,
                                // 8bit mode:  2'b00 - use addr[0] to decide which byte to write
                                // Ignored while reading.
   .addr       ({3'b000, sdram_adr[21:1], 1'b0}),  // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
   .din        (sdram_out),     // data input from cpu
   .dout       (sdram_dat),     // data output to cpu

   .SDRAM_CKE  (SDRAM_CKE),     // clock enable
   .SDRAM_nCS  (SDRAM_nCS),     // a single chip select
   .SDRAM_nRAS (SDRAM_nRAS),    // row address select
   .SDRAM_nCAS (SDRAM_nCAS),    // columns address select
   .SDRAM_nWE  (SDRAM_nWE),     // write enable
   .SDRAM_BA   (SDRAM_BA),      // two banks
   .SDRAM_A    (SDRAM_A[12:0]), // 13 bit multiplexed address bus
   .SDRAM_DQ   (SDRAM_DQ),      // 16 bit bidirectional data bus
   .SDRAM_DQML (SDRAM_DQML),    // two byte masks
   .SDRAM_DQMH (SDRAM_DQMH)
   );

// формирователь сигнала подверждения транзакции
//reg  [1:0] dack;
reg        dack;

//assign sdram_ack = sdram_stb & (dack[1]);
assign sdram_ack = sdram_stb & dack & sdr_ack ;

// задержка сигнала подтверждения на 1 такт clk
always @ (posedge clk_p)  begin
//   dack[0] <= sdram_stb & sdr_ack;
//   dack[1] <= sdram_stb & dack[0];
   dack <= sdram_stb;
end

//************************************
//*  Управление VGA DAC
//************************************
wire vgagreen,vgared,vgablue;
// выбор яркости каждого цвета  - сигнал, подаваемый на видео-ЦАП для светящейся и темной точки.   
assign video_g = (vgagreen == 1'b1) ? 6'b111111 : 6'b000000 ;
assign video_b = (vgablue == 1'b1)  ? 6'b111111 : 6'b000000 ;
assign video_r = (vgared == 1'b1)   ? 6'b111110 : 6'b000000 ;

//************************************
//* Соединительная плата
//************************************
topboard kernel(

   .clk50(clk50),                   // 50 МГц
   .clk_p(clk_p),                   // тактовая частота процессора, прямая фаза
   .clk_n(clk_n),                   // тактовая частота процессора, инверсная фаза
   .sdclock(sdclock),               // тактовая частота SD-карты
   .pixelclk(pixelclk),             // тактовая частота Pixelclock
   .clkrdy(clkrdy),                 // готовность PLL

   .bt_reset(status[2]),            // общий сброс
   .bt_halt(status[3]),             // режим программа-пульт
   .bt_terminal_rst(status[5]),     // сброс терминальной подсистемы
   .bt_timer(status[4]),            // выключатель таймера
   
   .sw_diskbank({2'b00,status[9:8]}),   // выбор дискового банка
   .sw_console(status[7]),          // выбор консольного порта: 0 - терминальный модуль, 1 - ИРПС 2
   .sw_cpuslow(status[6]),          // режим замедления процессора
   
   // индикаторные светодиоды      
   .rk_led(rk_led),               // запрос обмена диска RK
   .dm_led(dm_led),               // запрос обмена диска DM
   .dw_led(dw_led),               // запрос обмена диска DW
   .my_led(my_led),               // запрос обмена диска MY
   .dx_led(dx_led),               // запрос обмена диска DX
   .timer_led(timer_led),         // индикация включения таймера
   
   // Интерфейс SDRAM
   .sdram_reset(sdram_reset),     // сброс
   .sdram_stb(sdram_stb),         // строб начала транзакции
   .sdram_we(sdram_we),           // разрешение записи
   .sdram_sel(sdram_sel),         // выбор байтов
   .sdram_ack(sdram_ack),         // подтверждение транзакции
   .sdram_adr(sdram_adr),         // шина адреса
   .sdram_out(sdram_out),         // выход шины данных
   .sdram_dat(sdram_dat),         // вход шины данных
   .sdram_ready(sdram_ready),     // флаг готовности SDRAM
   
   // интерфейс SD-карты
   .sdcard_cs(sdcard_cs), 
   .sdcard_mosi(sdcard_mosi), 
   .sdcard_sclk(sdcard_sclk), 
   .sdcard_miso(sdcard_miso), 

   // VGA
   .vgah(VGA_HS),         // горизонтальная синхронизация
   .vgav(VGA_VS),         // вертикакльная синхронизация
   .vgared(vgared),     // красный видеосигнал
   .vgagreen(vgagreen), // зеленый видеосигнал
   .vgablue(vgablue),   // синий видеосигнал

   // PS/2
   .ps2_clk(ps2_clk), 
   .ps2_data(ps2_data),
   
   // пищалка    
   .buzzer(nbuzzer), 
    
   // дополнительный UART 
   .irps_txd(UART_TX),
   .irps_rxd(UART_RX)
);

//**********************************
//*  MIST
//**********************************

// the configuration string is returned to the io controller to allow
// it to control the menu on the OSD 
parameter CONF_STR = {
			"DVK-FPGA;;",
			"S0,DSKIMG,Drive;",
			"O4,Timer,On,Off;",
			"O6,CPU slow,Off,On;",
			"O7,Console,Termianl,UART;",
			"O89,Disk bank,0,1,2,3;",
			"O3,ODT,On,Off;",
			"T5,Reset Terminal;",
			"T2,Reset;"
};

parameter CONF_STR_LEN = 10+16+16+19+25+22+14+18+9;

parameter PS2DIV = 14'd3332;

// the status register is controlled by the on screen display (OSD)
wire [31:0] status;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_conf;
wire        sd_ack;
wire        sd_ack_conf;
wire        sd_sdhc;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [31:0] img_size;

reg sd_act;
always @(posedge clk_p) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sdcard_mosi;
	old_miso <= sdcard_miso;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ sdcard_mosi) || (old_miso ^ sdcard_miso)) timeout <= 0;
end
assign 	   LED = sd_act;

user_io #(.STRLEN(CONF_STR_LEN),.PS2DIV(PS2DIV)) user_io (

        .conf_str(CONF_STR),
        .clk_sys(clk_p),
        .clk_sd(clk_p),
        .SPI_CLK(SPI_SCK),
        .SPI_SS_IO(CONF_DATA0),
        .SPI_MISO(SPI_DO),
        .SPI_MOSI(SPI_DI),

        .status(status),

        .sd_conf(sd_conf),
        .sd_ack(sd_ack),
        .sd_ack_conf(sd_ack_conf),
        .sd_sdhc(sd_sdhc),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_lba(sd_lba),
        .sd_buff_addr(sd_buff_addr),
        .sd_din(sd_buff_din),
        .sd_dout(sd_buff_dout),
        .sd_dout_strobe(sd_buff_wr),

        // ps2 interface
        .ps2_kbd_clk(ps2_clk),
        .ps2_kbd_data(ps2_data)
);

sd_card sd_card
(
        .clk_sys(clk_p),
        .reset(status[2]),
        .sd_lba(sd_lba),
        .sd_rd(sd_rd),
        .sd_wr(sd_wr),
        .sd_ack(sd_ack),
        .sd_ack_conf(sd_ack_conf),
        .sd_conf(sd_conf),
        .sd_sdhc(sd_sdhc),

        .img_mounted(img_mounted),
        .img_size(img_size),

        .sd_buff_dout(sd_buff_dout),
        .sd_buff_wr(sd_buff_wr),
        .sd_buff_din(sd_buff_din),
        .sd_buff_addr(sd_buff_addr),
        .allow_sdhc(1),

        .sd_cs(sdcard_cs),
        .sd_sck(sdcard_sclk),
        .sd_sdi(sdcard_mosi),
        .sd_sdo(sdcard_miso)
);

osd  osd ( 	

        .clk_sys( clk50 ),
        .ce(0),
        .rotate(0),
        .SPI_SCK(SPI_SCK),
        .SPI_SS3(SPI_SS3),
        .SPI_DI(SPI_DI),

        .R_in(video_r),
        .G_in(video_g),
        .B_in(video_b),
        .HSync(VGA_HS),
        .VSync(VGA_VS),

        .R_out(VGA_R),
        .G_out(VGA_G),
        .B_out(VGA_B)
);

endmodule
