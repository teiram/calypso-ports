`timescale 1ns / 1ps
`default_nettype none

//    This file is part of the ZXUNO Spectrum core.
//    Creation date is 17:42:40 2015-06-01 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.

module scancode_to_speccy (
    input wire clk,  // el mismo clk de ps/2
    input wire rst,
    input wire scan_received,
    input wire [6:0] scan,
    input wire extended,
    input wire released,
    input wire shift_pressed,
    input wire ctrl_pressed,
    input wire alt_pressed,
    input wire kbclean,
    //------------------------
    input wire [7:0] sp_row,
    output reg [4:0] sp_col,
    //------------------------
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire cpuwrite,
    input wire cpuread,
    input wire rewind
    );

    // las 40 teclas del Spectrum. Se inicializan a "no pulsadas".
    reg [4:0] row[0:7];
    initial begin
        row[0] = 5'b11111;
        row[1] = 5'b11111;
        row[2] = 5'b11111;
        row[3] = 5'b11111;
        row[4] = 5'b11111;
        row[5] = 5'b11111;
        row[6] = 5'b11111;
        row[7] = 5'b11111;
    end

    // El gran mapa de teclado y sus registros de acceso
    wire [7:0] keymap1_q /* synthesis keep */;
    wire [7:0] keymap2_q /* synthesis keep */;
    reg keymap1_we = 1'b0;
    reg keymap2_we = 1'b0;
    
    keymap1 keymap1(
        .address(addr),
        .clock(clk),
        .q(keymap1_q),
        .data(din),
        .wren(keymap1_we)
    );
    keymap2 keymap2(
        .address(addr),
        .clock(clk),
        .q(keymap2_q),
        .data(din),
        .wren(keymap2_we)
    );
    reg [10:0] addr = 11'h0000;
    reg [11:0] cpuaddr = 12'h0000;  // Direcci�n E/S desde la CPU. Se autoincrementa en cada acceso

    reg [2:0] keyrow1 = 3'h0;
    reg [4:0] keycol1 = 5'h00;
    reg [2:0] keyrow2 = 3'h0;
    reg [4:0] keycol2 = 5'h00;

    // Asi funciona la matriz de teclado cuando se piden semifilas
    // desde la CPU.
    integer r;
    always @(*) begin
        sp_col = 5'b11111;
        for (r = 0; r <= 7; r = r + 1) begin
            if (sp_row[r] == 1'b0) sp_col = sp_col & row[r];
        end
    end
    
    parameter
        CLEANMATRIX     = 4'd0,
        IDLE            = 4'd1,
        READSPKEY       = 4'd2,
        READSPKEY2      = 4'd3,
        READSPKEY3      = 4'd4,
        TRANSLATE1      = 4'd5,
        TRANSLATE2      = 4'd6,
        CPUTIME         = 4'd7,
        CPUREAD         = 4'd8,
        CPUREAD2        = 4'd9,
        CPUREAD3        = 4'd10,
        CPUWRITE        = 4'd11,
        CPUINCADD       = 4'd12;

    reg [3:0] state = CLEANMATRIX;
    reg key_is_pending = 1'b0;
    wire [2:0] modifiers = {alt_pressed, ctrl_pressed, shift_pressed};

    always @(posedge clk) begin
        keymap1_we <= 1'b0;
        keymap2_we <= 1'b0;
        if (scan_received == 1'b1)
            key_is_pending <= 1'b1;
            if (rst == 1'b1 || (kbclean == 1'b1 && state == IDLE && key_is_pending == 1'b0)) state <= CLEANMATRIX;
            else begin
                case (state)
                    CLEANMATRIX: begin  //TODO: para evitar tener que usar el limpiador de teclado, hay que modificar esta FSM para que cuando se suelte una tecla, no solo actualice la matriz para esa combinaci�n de tecla+modificadores, sino tambi�n para las otras 7 combinaciones.
                        row[0] <= 5'b11111;
                        row[1] <= 5'b11111;
                        row[2] <= 5'b11111;
                        row[3] <= 5'b11111;
                        row[4] <= 5'b11111;
                        row[5] <= 5'b11111;
                        row[6] <= 5'b11111;
                        row[7] <= 5'b11111;
                        if (cpuread == 1'b1 || cpuwrite == 1'b1 || rewind == 1'b1) state <= CPUTIME;
                        else state <= IDLE;
                    end
                    IDLE: begin
                        if (key_is_pending == 1'b1) begin
                            addr <= {modifiers, extended, scan};  // 1 scan tiene 7 bits + 1 bit para indicar scan extendido + 3 bits para el modificador usado
                            state <= READSPKEY;
                            key_is_pending <= 1'b0;
                        end
                        else if (cpuread == 1'b1 || cpuwrite == 1'b1 || rewind == 1'b1) state <= CPUTIME;
                    end
                    READSPKEY: begin
                        state <= READSPKEY2;  // wait for the keymap_q output (addr sampled by RAM on this edge)
                    end
                    READSPKEY2: begin
                        state <= READSPKEY3;  // wait another cycle: q becomes valid on the next edge
                    end
                    READSPKEY3: begin
                        {keyrow1, keycol1} <= keymap1_q;
                        {keyrow2, keycol2} <= keymap2_q;
                        state <= TRANSLATE1;
                    end
                    TRANSLATE1: begin
                        // Actualiza las 8 semifilas del teclado con la primera tecla
                        if (~released) row[keyrow1] <= row[keyrow1] & ~keycol1;
                        else row[keyrow1] <= row[keyrow1] | keycol1;
                        state <= TRANSLATE2;
                    end
                    TRANSLATE2: begin
                        // Actualiza las 8 semifilas del teclado con la segunda tecla
                        if (~released) row[keyrow2] <= row[keyrow2] & ~keycol2;
                        else row[keyrow2] <= row[keyrow2] | keycol2;
                        state <= IDLE;
                    end
                    CPUTIME: begin
                        if (rewind == 1'b1) begin
                            cpuaddr <= 12'h0000;
                            state <= IDLE;
                        end
                        else if (cpuread == 1'b1) begin
                            addr <= cpuaddr[11:1];
                            state <= CPUREAD;
                        end
                        else if (cpuwrite == 1'b1) begin
                            addr <= cpuaddr[11:1];
                            state <= CPUWRITE;
                        end
                        else state <= IDLE;
                    end
                    CPUREAD: begin   // wait: addr sampled by RAM on this edge
                        state <= CPUREAD2;
                    end
                    CPUREAD2: begin   // wait another cycle: q becomes valid on the next edge
                        state <= CPUREAD3;
                    end
                    CPUREAD3: begin   // CPU wants to read from keymap
                        if (cpuaddr[0] == 1'b0)  dout <= keymap1_q;
                        else dout <= keymap2_q;
                        state <= CPUINCADD;
                    end
                    CPUWRITE: begin
                        if (cpuaddr[0] == 1'b0) keymap1_we <= 1'b1;
                        else keymap2_we <= 1'b1;
                        state <= CPUINCADD;
                    end
                    CPUINCADD: begin
                        if (cpuread == 1'b0 && cpuwrite == 1'b0) begin
                            cpuaddr <= cpuaddr + 12'd1;
                            state <= IDLE;
                        end
                    end
                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
    end
endmodule

module keyboard_pressed_status (
    input wire clk,
    input wire rst,
    input wire scan_received,
    input wire [6:0] scancode,
    input wire extended,
    input wire released,
    output reg kbclean
);

    reg [255:0] keybstat;  // keymap
    initial begin
      kbclean = 1'b1;
      keybstat = 256'h0;
    end

    always @(posedge clk) kbclean <= ~(|keybstat);

    always @(posedge clk) begin
        if (rst == 1'b1) keybstat <= 256'h0;
        else if (scan_received == 1'b1) keybstat[{extended,scancode}] <= ~released;
    end
    
endmodule

module kb_special_functions (
  input wire clk,  // el mismo clk de ps/2
  input wire rst,
  input wire scan_received,
  input wire [7:0] scancode,
  input wire extended,
  input wire released,
  output reg shift_pressed,
  output reg ctrl_pressed,
  output reg alt_pressed,
  output reg user_reset,
  output reg master_reset,
  output reg user_nmi,
  output reg joyup,
  output reg joydown,
  output reg joyleft,
  output reg joyright,
  output reg joyfire,
  output reg joyfire2,
  output reg video_output_change,
  output reg [13:0] user_fnt,
  output reg [1:0] monochrome_switcher
  );

  parameter
    LEFT_SHIFT  = 9'h012,
    RIGHT_SHIFT = 9'h059,
    LEFT_CTRL   = 9'h014,
    RIGHT_CTRL  = 9'h114,
    LEFT_ALT    = 9'h011,
    RIGHT_ALT   = 9'h111,
    LEFT_GUI    = 9'h11F,
    RIGHT_GUI   = 9'h127,
    BACKSPACE   = 9'h066,
    SUPR        = 9'h171,
    SUPRNUMPAD  = 9'h071,
    SCRLK       = 9'h07E,
    F1          = 9'h005,
    F2          = 9'h006,
    F3          = 9'h004,
    F4          = 9'h00C,
    F5          = 9'h003,
    F6          = 9'h00B,
    F7          = 9'h083,
    F8          = 9'h00A,
    F9          = 9'h001,
    F10         = 9'h009,
    F11         = 9'h078,
    F12         = 9'h007,
    PAD0        = 9'h070,
    PAD1        = 9'h069,
    PAD2        = 9'h072,
    PAD3        = 9'h07A,
    PAD4        = 9'h06B,
    PAD5        = 9'h073,
    PAD6        = 9'h074,
    PAD7        = 9'h06C,
    PAD8        = 9'h075,
    PAD9        = 9'h07D,
    PLAY        = 9'h134,
    STOP        = 9'h13b,
    PREVTRACK   = 9'h115,
    FF          = 9'h130,
    END         = 9'h169
    ;

  initial begin
    master_reset = 1'b0;
    user_reset = 1'b0;
    user_nmi = 1'b0;
    joyup = 1'b0;
    joydown = 1'b0;
    joyleft = 1'b0;
    joyright = 1'b0;
    joyfire = 1'b0;
    joyfire2 = 1'b0;
    video_output_change = 1'b0;
    user_fnt = 14'h0000;
    shift_pressed = 1'b0;
    ctrl_pressed = 1'b0;
    alt_pressed = 1'b0;
    monochrome_switcher = 2'b00;

  end

  always @(posedge clk) begin
    if (rst == 1'b1) begin
      user_nmi <= 1'b0;
      joyup <= 1'b0;
      joydown <= 1'b0;
      joyleft <= 1'b0;
      joyright <= 1'b0;
      joyfire <= 1'b0;
	  joyfire2 <= 1'b0;
      video_output_change <= 1'b0;
      user_fnt <= 14'h0000;
      shift_pressed <= 1'b0;
      ctrl_pressed <= 1'b0;
      alt_pressed <= 1'b0;
    end
    else begin
      if (video_output_change == 1'b1)
        video_output_change <= 1'b0;

      if (scan_received == 1'b1) begin
		  if (released == 1'b1) begin

				case ({extended, scancode})
				  END					: monochrome_switcher <= monochrome_switcher + 1; // MonochromeRGB
				  F11                   : user_fnt[1] <= ~user_fnt[1]; // WiFi ON/OFF
				  F12                   : user_fnt[0] <= ~user_fnt[0]; // Turbo-boost ON/OFF
				endcase

		  end

        case ({extended, scancode})
          LEFT_SHIFT,RIGHT_SHIFT: shift_pressed <= ~released;
          LEFT_CTRL,RIGHT_CTRL  : ctrl_pressed <= ~released;
          LEFT_ALT,RIGHT_ALT    : begin
                                    alt_pressed <= ~released;
                                    joyfire <= ~released;
                                  end
          LEFT_GUI,RIGHT_GUI, PAD0 : joyfire2 <= ~released;
          BACKSPACE             : if (released == 1'b0 && ctrl_pressed == 1'b1 && alt_pressed == 1'b1)
                                    master_reset <= 1'b1;
                                  else
                                    master_reset <= 1'b0;
          SUPR,SUPRNUMPAD       : if (released == 1'b0 && ctrl_pressed == 1'b1 && alt_pressed == 1'b1)
                                    user_reset <= 1'b1;
                                  else
                                    user_reset <= 1'b0;
          F5                    : user_nmi <= ~released;
          SCRLK                 : video_output_change <= ~released;
          PAD8                  : joyup <= ~released;
          PAD5,PAD2             : joydown <= ~released;
          PAD4                  : joyleft <= ~released;
          PAD6                  : joyright <= ~released;
          PAD7                  : begin
                                    joyup <= ~released;
                                    joyleft <= ~released;
                                  end
          PAD9                  : begin
                                    joyup <= ~released;
                                    joyright <= ~released;
                                  end
          PAD1                  : begin
                                    joydown <= ~released;
                                    joyleft <= ~released;
                                  end
          PAD3                  : begin
                                    joydown <= ~released;
                                    joyright <= ~released;
                                  end
          F1                    : user_fnt[8] <= ~released;
          F3                    : user_fnt[7] <= ~released;
          F4                    : user_fnt[6] <= ~released;
          F6                    : user_fnt[5] <= ~released;
          F7                    : user_fnt[4] <= ~released;
          F8                    : begin
                                      if (ctrl_pressed) user_fnt[13] <= (~released);
                                      else user_fnt[3] <= (~released);
                                  end
          F9                    : user_fnt[2] <= ~released;
          //F11                   : user_fnt[1] <= ~released;
          //F12                   : user_fnt[0] <= ~released;
          PLAY                  : user_fnt[9] <= ~released;
          PREVTRACK             : user_fnt[10] <= ~released;
          STOP                  : user_fnt[11] <= ~released;
          FF                    : user_fnt[12] <= ~released;
          // 12 funciones especiales. Usaremos FF, STOP, PREVTRACK, PLAY, F1 F3 F4 F6 F7 F8 F9 F11 y F12
        endcase
      end
    end
  end
endmodule
