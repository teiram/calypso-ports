# FPGA-based Soviet Computer Reconstructor

## DVK-1, DVK-2, DVK-3, DVK-4, Electronika-60(-1), Electronika-79

## Project Description

# 1. Introduction

This development is an FPGA-based constructor kit that allows you to assemble FPGA versions of old Soviet PDP11-compatible computers from a set of ready-made modules. The project covers microcomputers of the DVK-1, DVK-2, DVK-3, DVK-4, and Electronika-60/60M series, as well as the Electronika-79 computer, which are architectural replicas of the corresponding DEC PDP-11 series computers.

Initially, I was forced to undertake this development to replace a processor board that had completely failed in a test bench controller in our laboratory. At this point, the great VSLAV opportunely gifted the world with an FPGA version of the 1801VM2 processor, which saved our equipment. During development, it turned out to be easier to make the entire controller on an FPGA rather than emulate the asynchronous MPI bus, resulting in a DVK-compatible machine controlling our test bench. This development has been operating in our laboratory for six months in a fairly intensive mode, and all obvious bugs have been more or less identified and fixed.

The project is based on all processor cores for which VSLAV has performed reverse engineering and created working HDL descriptions, as well as on the universal synthetic PDP2011 core. Possibly, someday the list of supported processors will be expanded, everything depends on our great digital archaeologist.

# 2. General Project Structure

All Soviet microcomputers supported by the project were modular and consisted of a backplane into which a processor board and several peripheral boards were installed. This project has the same structure, containing a number of ready-made processor and peripheral boards, and also allows adding user devices. In this project, instead of the asynchronous MPI, a synchronous Wishbone bus is used as the common bus.

The project includes processor boards based on the available processor cores:

- K1801VM1
- K1801VM2
- K1801VM3
- M2 (LSI-11)
- M4 (LSI-11M)
- F11 (KDF11B)
- PDP2011 (pdp11/70)

The features of these boards are discussed in the corresponding section.

The project also includes peripheral device modules from which the computer configuration is built:

- IRPS serial port used to connect a console terminal (TT:), as well as additional terminals, serial printers (LS:), and communication links with other computers (XL:). The default configuration includes two such modules.
- IRPR parallel port (LP:) for connecting a parallel printer. The module's external interface uses the Centronics protocol, as real IRPR printers no longer exist in nature.
- RK11 disk controller (RK:) with 8 RK05 disks connected to it. The Soviet analog is SM5400.
- RK611 disk controller (DM:) with 8 RK07 disks connected to it. The Soviet analog is SM5408.
- RH-11/RH-70 disk controller (DB:) with 8 RP06 disks connected to it. The Soviet analog is ES5067.
- RX11 disk controller (DX:) with two RX01 disks connected to it (also known as GMD-70)
- KMD disk controller (MY:) with two NGMD-6121 floppy drives connected to it (4 logical disks).
- RD50C hard disk controller (DW:) with a 64M HDD connected to it. The controller is implemented in the DVK standard, not the original DEC one, and requires a DW driver specifically for DVK (the standard DW driver from the RT-11 distribution will not work).
- KSM text terminal (Symbol Monitor Controller) with VGA output, connected to the console IRPS. The terminal and IRPS speeds are hardware-synchronized.
- KGD graphics controller (monochrome Graphic Display Controller).
- SDRAM dynamic memory with a size of 4 Mbytes.
- 1K ROM with console emulator and a set of loaders, corresponding to DEC M9312.
- 8K user ROM

Any unnecessary module can be easily removed from the configuration to save FPGA resources. Some modules can only work together (KGD does not work without KSM). In addition, other custom-made modules can be connected to the common bus, creating a computer configuration needed by the user. For example, my configuration includes DAC, ADC, and discrete I/O modules for connecting to the test bench. Recommendations for writing such modules are in a separate document build-own-modules.

In its full composition, the board is a single-board version of the corresponding computer with a built-in terminal. Here is an example of a KSM display screen with RT-11 loaded:

![RT-11 Screen](Pictures/10000000000005A0000004387D2B1F7898D114B5.png)

Since the resulting computer's performance is much higher than the prototype, the circuit includes the ability to reduce the clock frequency using the sw_cpuslow switch for working with games and other interactive programs.

# 3. FPGAs Used

The development is based on Altera's Cyclone 4 series FPGA (now, unfortunately, Intel). In full composition, the circuit occupies just under 9000 cells and fits into an EP4CE10 chip when using processors with 16-bit addresses without MMU. If you remove some of the disk controllers and KGD, the circuit will fit into the smallest chip of this series – EP4CE6. Variants with MMU occupy more than 15000 cells and no longer fit into the younger Cyclone 4 variants.

Of the Cyclone hardware features, the scheme uses only static memory (altsyncram) and the PLL clock generator. Therefore, the circuit can easily be ported to Cyclone of other series and generally anywhere, as long as there are enough resources.

The project uses the following altsyncram static memory modules:

- rom000 - ROM of size 4096*16 bits, preloaded with ROM 000 (rom/000.mif) - shadow monitor of the MS1201.01 board.
- rom055 - ROM of size 4096*16 bits, preloaded with ROM 055 (rom/055.mif) or 279 (rom/279.mif) - shadow monitor of the MS1201.02 board.
- rom134 - ROM of size 4096*16 bits, preloaded with ROM 134 (rom/134.mif) - shadow monitor of the MS1201.03/04 board.
- boot_diag_rom - ROM of size 2048*16, preloaded with the boot/diagnostic ROM of the kdf11b board (rom/f11/boot_diag_rom.mif).
- fontrom - ROM of size 32768*1 bit, preloaded with the screen font file ksm-firmware/font/font-main.mif or ksm-firmware/font/font-ksm.mif.
- vtmem - RAM of size 2048*16, preloaded with the terminal microprogram ksm-firmware/terminal.mif
- kgdram - dual-port RAM of size 16384*8, which is the video memory of the KGD graphics controller. The second port of this module has a 1-bit data bus.
- sectorbuf - dual-port RAM of size 256*16, used by the SDSPI module as a sector buffer.
- bootrom - ROM of size 512*16 bits, containing the console emulator and a set of DEC M9312 loaders.
- userrom - ROM of size 4096*16 bits for storing the user's ROM image.

If you use an FPGA series other than Altera Cyclone, the PLL descriptors and memory modules will have to be redesigned or created from scratch.

For convenience, all files related to megafunctions are placed in the ip-components directory, separate for each FPGA board. When porting the project to another board, these megafunctions will depend on the specific FPGA used.

# 4. Project File Tree Structure

The project tree has the following directories:

- boards/ - repository of projects for each supported FPGA board.
- doc/ - project documentation
- disk/ - utilities for reading and writing disk images and a test disk bank
- hdl/ - verilog files of the main project
- hdl/ksm/ - verilog files of the KSM module
- hdl/sdram_ip - SDRAM controller
- rom/ - ROM image files
- ksm-firmware/ - files related to the KSM firmware and screen fonts.
- screenshots/ - examples of text and graphic screens

The head module of the project is an interface module, unique for each FPGA board. This module adapts the project core to the specific board - defines the purpose of switches and indicators, and also contains the SDRAM controller, PLL clock generator, and VGA DAC control circuit.

Below the interface module is the topboard module. This module is the core of the project - a backplane to which a processor module and a set of peripheral devices are connected. The module presents a unified external interface, independent of the FPGA board used. The project has 2 variants of the module - topboard16, for processors with a 16-bit address bus, and topboard22, for processors with a 22-bit address bus.

The following are connected to the external ports of the module:

- Clock frequency - **clk_p**, **clk_n**, **sdclk** 12.5 MHz, **clk50** 50 MHz.
- Control buttons
- Configuration switches
- Indicator LEDs
- Interface for RAM access (SDRAM)
- SD card
- VGA monitor signals
- PS/2 keyboard
- BUZZER
- Additional UART lines
- Centronics lines for the printer

Of course, not all of these ports need to be connected anywhere. For example, hardly anyone will actually use a printer. The specific connection of these ports is determined by the interface module and depends on the FPGA board used.

# 5. Configuration Settings for the Created Computer

At the root of the project lies the file config.v, which is used to configure the project. One of the processor boards is included in the configuration, as well as a set of necessary peripheral devices. In addition, using the configuration file, you can configure the parameters of some components - initial speeds of serial ports, screen font type, video signal parameters, etc. More detailed information is contained in the description of the corresponding modules, as well as in the comments inside the config.v file itself.

In addition to global settings, you can also define settings for a specific processor board - its clock frequency, initial timer state, processor slowdown factor, name of the ROM image file, etc.

# 6. External Controls and Indicators

Four buttons, three switches, and several LEDs are connected to the external ports of the circuit. In the topboard module interface, each of these elements has a fixed symbolic name. Their mapping to the LEDs, buttons, and switches of a specific FPGA board is done at the level of the interface module.

Button functions:

- bt_reset - general reset button. Initializes all subsystems except the terminal module.
- bt_halt - console interrupt button. When pressed, the current program's operation is interrupted, and the computer enters console mode. Instead of this button, you can install a two-position switch (program-console), as is done in the original computers - then there will be the ability to step through programs. For processors that do not have a console mode, this button resumes program operation after the processor stops by the HALT command. Currently, only the PDP2011 processor belongs to this category.
- bt_terminal_rst - terminal module reset button, helps when it hangs or simply to clear the screen.
- bt_timer - enable/disable timer interrupts. Each press of the button switches the timer mode (on-off). For configurations that use the KW-11L or LTC network timer, this button is not used, and enabling/disabling is done through the control register.

Switch functions:

- sw_diskbank - these switches select the disk bank on the SD card (described later in the "disk subsystem" section).
- sw_console - reassignment of the console port. If this switch is on, then external lines (irps_txd, irps_rxd) are connected to console port IRPS 1, and the hardware terminal is switched to additional port IRPS 2. This can be used, for example, if you need to use a computer with a terminal program running on it as a console.
- sw_cpuslow - enable processor slowdown mode. When the switch is off, the processor operates at full clock frequency. If the switch is on, the clock frequency is reduced to 4.5 MHz, which approximately corresponds to the clock frequency of the original board. This mode is necessary for games and other interactive programs that work too fast. The MS1280 board does not support this mode.

Indicator functions:

- rk_led - RK disk access
- dm_led - DM disk access
- dw_led - DW disk access
- dx_led - DX disk access
- my_led - MY disk access
- db_led - DB disk access
- timer_led - timer state indication (lit - timer on).

For 22-bit processor boards, three more indicator lines are added - led1, led2, led3. Their purpose depends on the specific processor board used and is described in the documentation for it.

In this case, it is assumed that:

- A button outputs 1 when pressed, 0 when released
- A switch outputs 0 in the off position, 1 in the on position
- An LED lights up when its port is set to 0.

# 7. Interface Module

The interface module adapts the project to a specific FPGA board. It is an intermediary between the topboard connection module and the physical ports of the FPGA. In addition, the module contains a PLL, SDRAM controller, and a control circuit for the VGA interface color DACs.

The interface module is developed individually for each FPGA board. The project tree already contains ready-made modules for some boards, which can be used as a basis for creating your own module when porting to your board.

## 7.1. SDRAM Controller

This controller forms the computer's RAM block. The module must provide 4 megabytes of RAM, but 64K is sufficient for the full implementation of processor boards without a memory manager.

The controller implementation depends on the specific SDRAM chip on the FPGA board. The project includes one of the controller variants that can work with 16-bit SDRAM chips with a capacity of up to 16 MB, organized as 4 banks of 4Mb each. The main timing parameter - Cas Latency, is set to 2. If the SDRAM only supports CL3, then the cas_latency value in the config.v file should be corrected. But then one memory access cycle will take 12 cycles.

If you have a different type of SDRAM chip on your board, such as DDR2, you will have to make the controller yourself.

The topboard module provides a unified interface for working with memory. The signals of this interface mainly correspond to the standard set of wishbone bus signals:

- **sdram_reset** - reset signal. By this signal, the controller reinitializes the SDRAM chip
- **sdram_stb** - strobe of the beginning of exchange with memory
- **sdram_we** - a high level of this signal tells the controller that a write operation is in progress.
- **sdram_sel[1:0]** - mask that determines which bytes (high, low, or both) will be written. When reading, this mask is ignored, both bytes are always read.
- **sdram_ack** - response from the controller (reply), confirming the end of the transaction.
- **sdram_adr[21:0]** - address bus
- **sdram_out[15:0]** - input data bus (from host to memory)
- **sdram_dat[15:0]** - output data bus (from memory to host)
- **sdram_ready** - output signal, formed by the controller at the end of the memory initialization process.

For all SDRAM controllers in the project, a clock frequency doubling mode is implemented. This means that the memory clock frequency is always exactly 2 times higher than the processor clock frequency. This allows increasing system performance by approximately 80% without the need to take measures to filter signals from metastability.

## 7.2. PLL Clock Generator

The PLL should output 4 clock signals:

1. **clk_p** direct phase (0°) - main clock signal
2. **clk_n** inverse phase (180°) - additional clock signal of the processor module.
3. **sdclk** 12.5 MHz direct phase (0°) - clock signal of the SD controller and memory card.
4. **sdram_clk** direct phase (0°) - doubled frequency of the clk_p signal.

The frequency of the main clock signal depends on the processor board and the FPGA used, and is set in the configuration file. Accordingly, the PLL module accepts 2 macros - PLL_MUL and PLL_DIV, which set the divider and multiplier of the main clock frequency. For Cyclone 4, this is done like this:

```
altpll_component.clk0_divide_by = `PLL_DIV,
altpll_component.clk0_duty_cycle = 50,
altpll_component.clk0_multiply_by = `PLL_MUL,
altpll_component.clk0_phase_shift = "0",
altpll_component.clk1_divide_by = `PLL_DIV,
altpll_component.clk1_duty_cycle = 50,
altpll_component.clk1_multiply_by = `PLL_MUL,
altpll_component.clk1_phase_shift = "5000",
altpll_component.clk2_divide_by = 4,
altpll_component.clk2_duty_cycle = 50,
altpll_component.clk2_multiply_by = 1,
altpll_component.clk2_phase_shift = "0"
```

The pll description file is ip-components/pll.v

The board's own generator should provide a frequency of 50 MHz, which is used by the PLL to synthesize the above three signals, and also directly by the KSM terminal module to form the VGA video signal. If your board has a generator of a different frequency, then 50 MHz will also have to be synthesized using PLL.

## 7.3. VGA DAC Color Control Circuit

The topboard module provides 3 single-bit signals that enable the corresponding color: vgared, vgagreen, vgablue.

Depending on the connection of the VGA connector on a specific FPGA board, a circuit is required to convert these single-bit colors into a multi-bit bus going to the input of each video DAC, for example:

```
// select the brightness of each color
assign vgag = (vgagreen == 1'b1) ? 6'b111111 : 6'b000000;
assign vgab = (vgablue == 1'b1) ? 5'b11111 : 5'b00000;
assign vgar = (vgared == 1'b1) ? 5'b11111 : 5'b00000;
```

If your board has a different DAC bit depth, this circuit needs to be adjusted to your needs. If there is no DAC at all and the R, G, B lines of the VGA connector are connected directly to the FPGA ports, then a converter is not required at all.

# 8. Top Level Connection Module

The topboard module is essentially a connection panel (backplane) to which other modules are connected. This is how the original computers were designed - the processor and all peripherals are on separate boards, and the backplane provides them with power and connects them to a common MPI bus.

In this project, the topboard connection board provides a common Wishbone bus, and also contains a number of auxiliary components:

- System reset generator (DCLO and ACLO)
- Circuit for forming selection signals for each peripheral device (xxx_stb)
- Interrupt controller(s)
- DMA arbiter and Wishbone bus signal source switch.
- SD card access arbiter
- VGA DAC control signal generator
- Serial port line switch.
- ROM with resident user program (switchable)

The composition of devices included in the connection board is determined by the config.v configuration file. The configuration must include one (and only one) processor board and one serial port (system console). All other components are optional and are connected to the circuit as needed.

The connection board provides a unified interface, independent of the FPGA used. The interface module, which is the top-level module of the project, is responsible for matching with a specific FPGA board.

## 8.1. User ROM

As in the original microcomputers, this project provides for connecting user ROM to the address space 140000-157777 instead of the corresponding RAM bank. In the DVK-1 computer, this ROM typically contained a BASIC or FOCAL interpreter, allowing the computer to be used in a completely diskless configuration. In other machines, an empty socket is provided on the processor board for installing user ROM.

In this project, an altsyncram megafunction named userrom is provided for forming this ROM. To include the ROM in the configuration, uncomment the line `define userrom in the config.v file, and specify the name of the mif file with the loaded ROM image. The rom/ directory contains ready-to-use ROM images 013 (basic) and 058 (focal).

The ability to connect user ROM is only available for boards with 16-bit addresses.

## 8.2 Reset Generator

This module produces a coordinated pair of signals designed to reset the processor core - ACLO and DCLO. The input signal leading to a reset is the reset button sw[0], as well as the PLL and SDRAM ready signal - the processor starts only after the PLL and dynamic memory enter operating mode.

In addition to the processor reset signal, the module also forms a dynamic memory reset signal. This signal is formed only based on the button and PLL readiness.

## 8.3 Interrupt Controller

The interrupt controller implements the processor's vector interrupt mechanism. Upon receiving an IRQ request signal issued by one of the peripheral devices, the module issues a vector interrupt signal VM_VIRQ to the processor, then puts the interrupt vector corresponding to the device on the bus, and transmits an interrupt acknowledgment signal IACK to the interrupting peripheral device.

All vector addresses are transmitted through the input bus IVEC, which is an array of 16-bit numbers. New vectors can be added to this list if new modules requiring interrupt service are added to the circuit. The N parameter of the module determines the number of vectors it serves.

Two interrupt controllers are installed on the topboard22 board, since processors with MMU support several interrupt inputs of different priorities. Priority 4 interrupts (less priority) are used for slow devices like terminals, and priority 5 for fast devices like disks.

## 8.4. DMA Arbiter

The arbiter is designed to service direct memory access (DMA) requests coming from peripheral devices.

Any device on the bus can take control of the bus and exchange data with memory and other peripheral devices without processor involvement. To do this, the device issues a DMA_REQ request. In response to this request, the arbiter waits for the completion of the current transaction on the bus, after which it removes the CPU_GNT signal, thereby prohibiting the processor from working with the bus. More precisely, this signal disables the internal bus timer in the processor and infinitely stretches the next transaction. After this, the arbiter issues a DMA_ACK response to the requesting device, upon which the device takes control of the bus. Bus multiplexers disconnect the processor from the bus and connect the requesting device instead.

At the end of the DMA exchange, the device removes the DMA_REQ signal, the processor is reconnected to the bus and continues operation.

The arbiter circuit also includes a Wishbone bus signal switch, connecting the bus to one of the devices that requested a DMA exchange, or to the processor if there are no DMA requests.

For 22-bit processors, a Unibus Mapping mode is implemented, allowing unibus devices capable of forming only an 18-bit DMA address to work with a full 22-bit address bus. In this case, the address, as well as the ram_stb memory access strobe, is formed by the UMR module, working in conjunction with the processor's memory manager. This module, if enabled, translates the 18-bit address put on the address bus by the device into a full 22-bit address, based on pre-configured translation tables.

## 8.5 SD Card Arbiter

The SD card arbiter allows all disk controllers to use the same SD card for storing disk arrays. Each controller is allocated a separate section in the SD card block space.

A disk controller wishing to access the card issues an SDREQ request. The arbiter checks if the card is busy exchanging with another controller, and if the card is free, connects it to the controller requesting access, and signals this with an SDACK response. After finishing working with the card, the controller removes the SDREQ request, the arbiter disconnects the card from the controller and goes into a state of waiting for the next request. If the card is busy with another controller at the time of the request, the request is queued and will be served immediately after the card is free.

In the circuit, there is one disk controller to which the card is connected by default if there are no other active requests. This controller initializes the card. Any of the disk controllers can be declared as the default controller.

## 8.6. VGA DAC Control Signal Generator

Typically, on debug FPGA boards with a VGA connector, a DAC is installed for each of the color signals. Usually, such a DAC has 4-5 bits and is needed to control the brightness of each color. Since this project's video signals do not use brightness gradations, fixed values are fed to the video DAC - 0 for a dark point and some value (usually the maximum, like 5'b11111) for a bright point.

The generator circuit depends on the bit depth of the DAC on the specific board and may require correction when adapting the project. Here is an example of a generator for 6-bit green and 5-bit red and blue signals:

```
assign vgag = (vgagreen == 1'b1) ? 6'b111111 : 6'b000000;
assign vgab = (vgablue == 1'b1) ? 5'b11111 : 5'b00000;
assign vgar = (vgared == 1'b1) ? 5'b11110 : 5'b00000;
```

The vgar, vgag, vgab buses are the output ports of the topboard module, connected to the video DAC on the board.

## 8.7. Serial Port Line Switch

This device controls the connection of the output lines of the IRPS1 and IRPS2 modules. By default, IRPS1 is connected to the KSM terminal module, and IRPS2 to the output ports of the irps_txd and irps_rxd board. Using the sw_console switch, it is possible to swap these signals - then IRPS2 is connected to the terminal, and IRPS1 to the external ports. This is needed, for example, to output the console terminal to the PC serial port, to use a terminal program running on the PC as a console.

In addition, this device controls the speed of serial ports. The speed of the IRPS connected to the KSM terminal is determined by the KSM module itself (and can be changed with the F5/F6 keys of the KSM keyboard). The speed of the other IRPS port is fixed and is set in the config.v configuration file.

## 8.8. Features of a 22-bit Connection Board

The topboard22 board is designed to connect processors that have a memory management unit (MMU) as part of them. In this case, the address space is increased to 4MB and is distributed as follows:

00000000 - 16777777 = RAM
17000000 - 17757777 = Unibus Mapping area
17760000 - 17777777 = I/O page

With MMU disabled, the address space distribution is the same as for 16-bit processors: up to 175777 RAM, 176000-177777 I/O page.

Unlike 16-bit processors, here two separate strobes are formed on the bus - ram_stb for accessing RAM and bus_stb for accessing the I/O page. Peripheral devices supporting 22-bit DMA form the same signals. Other devices use the Unibus Mapping mechanism for this purpose.

The 22-bit connection board forms additional indication signals - led1, led2, led3. Their purpose is determined by the specific processor board used.

# 9. Processor Boards

The project includes the following processor boards:

| Board      | Processor    | Computer                | Bits | Instructions | Variants |
|------------|--------------|-------------------------|------|--------------|----------|
| MS1201.01  | K1801VM1     | DVK-1, DVK-2           | 16   | MUL          |          |
| MS1201.02  | K1801VM2     | DVK-3                  | 16   | EIS, FIS     |          |
| MS1201.03  | K1801VM3     | DVK-3M, 4              | 22   | EIS, MMU     |          |
| MS1201.04  | K1801VM3     | DVK-4                  | 22   | EIS, MMU     |          |
| MS1260     | M2 (LSI-11)  | Electronika-60         | 16   | EIS, FIS     |          |
| MS1280     | M4 (LSI-11M) |                        | 16   | EIS, FIS     |          |
| KDF11B     | F11          | Electronika-60-1, PDP11/23 | 22 | EIS, FPP, MMU |        |
| PDP2011    | PDP 11/70    | Electronika-79, PDP11/70 | 22 | EIS, FPP, MMU |         |

Only one board out of all possible can be included in the circuit. The type of connection board (16 or 22) depending on the processor type is selected automatically.

Each processor board, in addition to the processor core itself, also contains some auxiliary components:

- Interval timer that causes processor interrupts with a frequency of 50 Hz.
- Timer control circuit.
- Processor slowdown circuit, which allows reducing the processor performance to the level of the original board without changing the clock frequency of the common bus.
- Shadow ROM with debug monitor and a set of loaders.
- Console panel ROM with a set of loaders.

The interval timer generates a pulse with a width of one period of the bus clock frequency, repeating at a frequency of 50 Hz. This signal is fed to the timer interrupt input of the processor and is used to organize the system clock. The timer control circuit allows turning these interrupts on and off with the bt_timer button (as in the original microcomputers - the "timer" switch or button).

For 22-bit processors, a full-fledged KW-11L or LTC network timer is installed on the processor board, causing a priority 6 interrupt. In this case, the manual timer activation button is not used.

In addition to the timer interrupt, there is a console mode interrupt, called by the bt_halt button. In the original microcomputers, this function was performed by the "program-console" switch. By this interrupt, the main program's operation is stopped, and control is transferred to the debug monitor built into the ROM or processor microcode. For boards that do not have a console mode, this button resumes processor operation after stopping by the HALT instruction.

## 9.1. MS1201.01 Board

This board is based on the KR1801VM1 processor. The processor does not support FIS commands, and from EIS it only supports the MUL command, because of which RT-11 erroneously assumes full EIS support.

The board contains 64Kb of RAM, divided into 8 banks, with bank 7 excluded from the user address space (the I/O page is located in its place)

The board has a special initial start register, the contents of the lower two bits of which determine the computer's start mode. It is possible to start with an exit to the debug monitor, autoload from a floppy disk, or start a program from user ROM. Other bits of this register control the address space map and determine the initial start address (the address of the monitor ROM in the address space).

By default, after power-on, interrupts from the timer are allowed, and pressing the reset button does not change the timer state.

The monitor ROM contains a single loader from DX floppy disks (GMD-70). Loading is possible from either of the DX0 or DX1 disks and is done with the D0 and D1 commands. Loading from other types of disks is only possible from an operating system already loaded from DX, or by entering the loader into memory with monitor commands.

The DVK-1 and DVK-2 microcomputers were based on this board. The 1801RE2-000 ROM was used as the monitor ROM. DVK-1 was typically equipped with additional user ROM with Basic (1801RE2-013) or Focal (1801RE2-057). Images of all these ROMs are in the rom/ directory.

Unlike DVK-3, DVK-1 or DVK-2 machines were equipped not with a KSM controller, but with a hardware Fryazino terminal 15IE-00-013. However, both KSM and the Fryazino display are fully compatible with DEC VT52, and the vast majority of software was operated in this mode. Those who need the Fryazino display specifically can replace the KSM controller with a hardware terminal https://github.com/forth32/vt52. This will lose the ability to use the KGD graphics module.

## 9.2. MS1201.02 Board

This board is based on the KR1801VM2 processor. The processor fully supports the EIS instruction set, and emulates FIS commands using shadow ROM subroutines.

Like the previous one, this board contains 64Kb of RAM, of which 56K are available to the user.

There is also an initial start register, but the start mode is now determined by three bits, and, accordingly, there are 8 start modes. The 1801VM2 processor has full hardware support for shadow mode, so special registers for controlling the memory map are not required. The processor mode is determined by the SEL signal, represented in the wishbone core as an additional address line wb_adr[16].

By default, after power-on, interrupts from the timer are allowed, and pressing the reset button does not change the timer state.

The 1801RE2-055 ROM was normally installed on the board. There is also an updated version of this ROM - 279, which has an extended set of commands and additional loaders. Each of these ROMs has a rich set of loaders and supports loading from any of the disks available in the project (with the exception of the MY loader, which is only available in ROM 279). System loading is done with the B command, in response to the "¤" prompt, you need to enter the name and number of the device to be loaded.

Both ROM versions contain an error, as a result of which loading from an RK disk becomes impossible. The essence of this error is in the incorrect length of the area read from the disk during initial loading. When the monitor command B RK is entered, the monitor copies the initial boot code to memory at address 1000 and transfers control there. This boot code starts reading the RK disk, starting from sector 0, but reads not one 512-byte block, but two - this is the error. As a result, the loader code, starting from address 1000, is overwritten in DMA mode with data from sector 1, and at the end of the exchange with the disk, control is given to garbage instead of the boot code. I made corrections to both ROM versions, and corrected versions are already in the rom directory.

The DVK-3 microcomputer was based on this board.

## 9.3. MS1260 Board

This board is based on the M2 sectional processor (its prototype is DEC LSI-11). This processor has an external microcode ROM and allows connecting additional user microcode. The debug monitor is also implemented at the microcode level, and there are no additional ROMs in the address space. Accordingly, there is neither a shadow mode of the processor, nor any switching of the memory map. The processor has hardware support for the EIS and FIS command sets.

As on all other boards, the lower 56Kb of address space is occupied by a dynamic memory module, and the I/O page is above.

The board has 4 start modes, of which only one mode has practical use - the debug monitor start.

By default, after power-on, interrupts from the timer are disabled, and pressing the reset button disables interrupts from the timer. This is done because enabled timer interrupts cause a failure in loading the operating system. The timer can be turned on after the OS loading is completed for the system clock to work.

The microcode built-in monitor does not have any loaders other than paper tape, and disk loading can only be done by entering a loader dump into memory using monitor commands, or by including the M9312 console emulator/loader ROM in the configuration.

The Electronika-60 microcomputer was based on this board, which was mainly used in various control systems. It was extremely rarely used as a full-fledged desktop computer, if it was ever used at all.

## 9.4. MS1280 Board

This board is based on the M4 sectional processor (prototype - DEC LSI-11M). Unlike all previous boards, this processor core operates at a lower clock frequency - for Cyclone 4, not higher than 50 MHz. In other respects, this board is schematically similar to MS1260.

I do not know what computers were assembled on this board.

## 9.5. PDP2011, KDF11B, MS1201.03/04 Boards

These boards are described in separate documents located in the doc directory of the project tree.

## 9.6. M9312 Loader/Console Panel

Since most processor boards contain a rather poor set of disk loaders in their ROM/microcode (or do not have them at all), a "loader/console panel" ROM has been added to the project. Such ROM is found on many DEC machines and on all our SM computers. The ROM consists of two parts - a console emulator at address 165000, and a set of initial loaders at address 173000. The images of these ROMs are combined into a single file bootrom.mif.

In large PDP-11 computers (and SM computers), this ROM gets control immediately after the processor starts (when the START button on the processor console is pressed). This is how the PDP2011 processor behaves.

In other cases, when the processor starts, the shadow or microprogram monitor is launched, and the console emulator is started manually by transferring control to address 165020:

```
@165020G
140001 141432 000776 137652 
$
```

In response to the "$" prompt, you can enter one of the following commands:

| Command | Description |
|---------|-------------|
| L addr  | Set the current address to addr |
| E<space> | Display the value of the cell at the current address |
| D val   | Write the value val to the current address |

There is little practical use for these commands, since it is much more convenient to use the commands of the shadow/microprogram monitor. But, in addition to these commands, the emulator allows loading the operating system from many types of devices. To do this, in response to the "$" prompt, you need to enter the name and number of the device, for example:

```
@165020G
140001 130050 000776 000000 
$DM3
?MY-I-My/Dz-emulater handler. Un_Soft 1991. V3.04
DW Handler V6.5, (c) D.S.C., 1992-2016
RT-11FB (S) V05.04 D
.SET TT QUIET
```

Currently, the loader supports DK, DM, DP, DB, DT, DX devices. Note that the RK05 device is called DK here, not RK as in RT-11.

Unlike the shadow loader of the MS1201.02 board, this loader allows loading from any of the 8 devices connected to the controller. DW and MY devices are not supported as they are not on the list of standard DEC devices.

The M9312 ROM works **only with the timer turned off**. If the timer is turned on at the moment the console panel is started, an unplanned interrupt will occur due to a double bus error.

The source texts of the current version of the emulator/loader are in the rom/m9312 directory.

# 10. Disk Subsystem

All disk controllers store their data on an SD card. Only SDHC cards up to 64GB are supported. SDSC cards are not supported to simplify the circuit - such cards are no longer made and are problematic to obtain. It should be noted that many cheap Chinese SDHC cards (sold on AliExpress for pennies) work incorrectly in SPI mode. The incorrectness is expressed in the complete hanging of the card at the first write command. The card stops responding to incoming commands, and it can only be brought out of this state by removing power. At the same time, reading from the card works without any problems. Brand name cards - Transcend, Kingston, Samsung, etc., do not have this bug.

## 10.1. Address Distribution on the SD Card

The map of SD card block addresses allocation for disk images used in this project is described in the card-layout.ods file.

All disk controllers share the same card. A set of 8 RK disks, one DW disk, two DX disks, 4 MY disks, 8 DB disks, and 8 DM disks forms a disk bank of 2 GB. Part of this space for disks is not used and is lost for the sake of simplifying address generators. Since such a volume is tiny for modern cards, several disk banks can be placed on the card. This circuit supports 16 banks, switched using a 4-bit sw_diskbank switch. All 16 banks occupy 32GB on the card. Of course, it is not necessary to output all 4 bits to a physical switch. Usually 2 bits are enough, which gives 4 banks. But some of the sw_diskbank bits can be used to set the offset of the beginning of the disk array on the SD card, for the case when some additional information is stored on the card.

Each disk controller module has an input bus "start_offset", which determines from which absolute block number the disk images of this type begin. By changing this value, you can move the disk array to any place on the SD card. You can make switchable banks for each type of disk separately, you can even put any type of disk on a separate SD card. Everything is determined by your needs. The main thing to remember is that the starting address of the disk array should be a multiple of the sum of the image sizes of all disks connected to this controller. For example, the MY disk image occupies 2048 blocks on the card, so the size of 4 disks will be 8192 blocks. The starting address of the disk array must be a multiple of 8192.

To write disk images to an SD card, the sd-store program is used, and to extract images from the card - the sd-extract program. Both programs use DSK containers (sector-by-sector disk images), which are recognized by the simh emulator. The source texts of these programs are in the disk/ directory. The block address allocation map is stored in the devtable.h file.

Also, to facilitate the initial launch of the project, there is a complete disk bank image in the file initdisk.img in the disk directory. This image contains the following operating systems:

| Disk | Contents |
|------|----------|
| DM0  | RT-11 V5.5 full distribution |
| DM1  | XXDP V2.5 |
| DM2  | RSX-11M V4.8 full distribution |
| DM3  | RSTS/E V10.1 |
| DB0  | RSX-11M-PLUS V4.6 full distribution |
| DX0  | XXDP with basic PDP11/70 test set |
| DX1  | RT-11 V5.04 minimal |
| MY0  | RT-11 V5.01 with a set of games from DVK |
| DK0  | RT-11 V5.04 |
| DK1  | FODOS-TMOS with a set of tests |
| DK2  | RAFOS+ v2.1 |
| DW0  | RT-11 V5.04 D full distribution |

In the RT-11 systems presented above, there is a variant of the DW driver that divides the HDD into 4 identical 16 MB disks (you can repartition the disk if desired with the set dw part command). The source texts of the DW.MAC driver and the DWBLD.COM command file for building the driver for a specific system are on the RK0, DM0, and DW0 disks. The source texts of the MY driver are also on these disks. RSX and RSTS/E systems do not support DW and MY devices.

The initdisk.img starter set can be written directly to an SD card from block zero with the command

```
dd if=initdisk.img of=/dev/sdx
```

where sdx is the name of the SD card device, for example /dev/sdc. After installing the recorded card in the board, you can boot the system from any of the above disks.

## 10.2. SDSPI

The SDSPI module - an SD card controller - is used to work with the memory card. It is based on the module of the same name from the pdp2011 project, rewritten from nasty VHDL to kosher Verilog and redesigned for my needs. The module contains a dual-port sector buffer of 512 bytes with an organization of 256*16, and can perform 2 simple operations - read a block from the card to the buffer and write a block from the buffer to the card. Working with the buffer takes place at the full speed of the common bus (wb_clk), and I/O operations to the SD card do not occupy the bus at all and are performed asynchronously to the processor. This allows combining I/O and main program operation, as in a real DVK.

The module can work in two modes - master and slave. The master controller gets access to the card by default, immediately after startup. It performs the primary initialization of the SD card. The master SDSPI is connected to only one disk controller out of all. The rest of the disk controllers are connected to SDSPI in slave mode - in this mode, card initialization is not performed. The sdspi operating mode of each disk controller is set through the sdmode port (0 - slave, 1 - master).

Any of the RK, DX, MY, or DW disks can also be moved to a separate SD card. To do this, the sdmode port of the controller should be assigned a value of 1, and the ports sdcard_cs, sdcard_mosi, sdcard_miso, sdcard_sclk should be connected to the corresponding pins of the separate sd-card. The sdreq (card access request) and sdack (access confirmation) lines in this case should simply be closed to each other, disconnecting them from the SD card arbiter, since the controller in this case controls the card exclusively.

## 10.3. Disk Controller Modules

Each disk controller is represented by a separate module, connected to the common wishbone bus and the SD card dispatcher (or real card). There are the following disk modules:

- rk11.v - RK11 disk controller (RK:)
- rx01.v - 8-inch floppy drive RX01 controller (DX:)
- fdd-my.v - 5-inch floppy drive controller (MY:)
- dw.v - RD50C hard disk controller (DW:)
- rk611.v - RK611 disk controller (DM:)
- rh70.v - RH-11/RH-70 disk controller (DB:)

Any of these controllers can be painlessly removed from the circuit if not needed.

Summary table of disk controllers:

| Parameter | RK11/RK05 | RX01 | MY | RD50C | RK611/RK07 | RP06 |
|-----------|-----------|------|----|----|------|------|
| Capacity, blocks | 4872 | 475 | 1600 | 131072 | 53790 | 341088 |
| Capacity, KB | 2436 | 237 | 800 | 65536 | 26895 | 170544 |
| Size on SD | 6144 | 4096 | 2048 | 131072 | 65536 | 393216 |
| Number of drives | 8 | 2 | 4 | 1 | 8 | 8 |
| Address | 177400-177416 | 177170-177172 | 172140-172142 | 174000-174026 | 177440-177476 | 176700-176776 |
| Vector | 220 | 264 | 170 | 300 | 210 | 254 |
| DMA | 18 | - | 22 | - | 18 | 18/22 |
| CYL | 312 | 76 | 80 | 1024 | 815 | 815 |
| HD | 2 | 1 | 2 | 8 | 3 | 19 |
| SPT | 10 | 25 | 10 | 16 | 22 | 22 |
| Sector size | 512 | 128 | 512 | 512 | 512 | 512 |

Explanation to the table:

- Capacity - how many logical blocks of 512 bytes fit on the device
- Size on SD - how much space the virtual image occupies on the SD card. Part of this space may not be used and contain garbage.
- Number of drives - how many virtual drives are connected to the controller.
- DMA - bit depth of the DMA address
- CYL - number of cylinders of the emulated drive
- HD - number of heads
- SPT - number of sectors per track
- Sector size - the size of the physical sector processed by this controller. The SPT parameter reflects the number of sectors of this size per track. Operating systems always use logical blocks of 512 bytes, and it is in blocks of this size that the first parameter, disk capacity, is calculated.

Each of the disk modules is described in detail below.

### 10.3.1. RK11/RK05 Controller (RK/DK)

This module implements the DEC RK11 controller (RK: in rt-11), with 8 RK05 disks of 3 MB connected to it. The Soviet analog of this device is SM-5400. This disk controller is one of the fastest - it uses DMA for reading and writing disk buffers. This controller was implemented first, and has been working in our laboratory for half a year as a working disk.

The RK05 disk block size is 512 bytes, which perfectly corresponds to the SD card block size. Therefore, disk images on the SD card represent a sector-by-sector copy of a real disk - each logical block number LBN coincides with the physical block number from the beginning of the image. These images can be used directly in simh, setting the RAW format (with the set RKn format=raw command).

In real life, SM-5300 disks were very rarely connected to DVK and other desktop computers - they were more often found as part of large computers, for example, SM-4. But this disk is fast and convenient for real work. The exchange speed with this disk is the same as with the MY floppy disk (in this implementation, of course), and the capacity is much larger.

### 10.3.2. RD50C Controller (DW)

The RD50C controller (DW: in RT-11) provides an interface to a 64M hard disk - this is the maximum volume supported by the DW driver. The original DEC RD50C controller was designed to work in DECpro-350 machines, and used an interrupt system specific to this machine. In the DVK variant, the controller works with a regular vector interrupt system, like all other devices, and it is in this variant that this module is implemented. Therefore, the official DW.SYS driver from the RT-11 kit will not work with this controller - a driver written specifically for DVK is required. There are many different variants, you can use any of them. But it should be noted that the maximum disk volume supported by the RT-11 file system is 32MB, so all 64MB of the virtual hard disk can only be used if the driver can divide the disk into several partitions. I used a driver that calls itself "DW Handler V6.5, (c) D.S.C" - it can divide the HDD into 4 logical disks.

Note that only the driver under which the hard disk was divided into partitions will work correctly with the hard disk image. Unlike the IBM PC world, there are no standard disk partitioning formats here, and the partition table is most often stored not on the disk, but in the driver itself. When using someone else's driver (or a native one, but with a different partition setting), the result is unpredictable - from loss of access to data and inability to boot the OS to complete destruction of information on the disk. Since the DW.SYS driver is often found on diskette images available on the network, be careful when loading from such diskettes.

Unlike RK11, this controller cannot work through DMA - reading/writing buffers is done programmatically, one word at a time. Therefore, the DW controller is significantly slower than the RK controller. In our test bench, the DW disk is used only as a common file dump, and all the main work is done only with RK disks.

The HDD sector size is 512 bytes, the same as the sd-card. As in the case of RK11, the logical block number of the virtual HDD corresponds to the absolute block number from the beginning of the disk image. Nevertheless, if the disk is divided into several partitions, you can only work with the very first partition in simh - the rest will be inaccessible, because the DVK DW.SYS driver will not work in simh. Under simh, you need to mount the image as an MSCP disk DU:, not forgetting to specify format=raw.

### 10.3.3. RX11/RX01 Controller (DX)

The module implements the RX11 controller with two RX01 drives connected to it. Our analog of such a drive is GMD-70. Of course, the days of 8-inch floppy disks passed a quarter of a century ago, and there are probably almost no such disks left in nature. But this controller was built into the MS1201.02 board, and for completeness, I implemented it too. There is very little practical use for it, it is mainly needed for working with DX-diskette images found on the network.

This controller, like DW, cannot work through DMA. What's even worse, it does not support word exchange over the bus - data transfer to/from the buffer occurs byte by byte, which slows down the process of loading and unloading the buffer by a factor of two. The sector size of this disk is only 128 bytes, and the RT-11 logical block corresponds to 4 diskette sectors. The total disk size is 251 KB, but track 0 is not used by the system for data storage.

To simplify the circuit and save FPGA resources, I did not compact the data, and the DX disk image on the SD card occupies 4MB. At the same time, the data is stored only in the lower bytes of the SD card block, and only half of each block is used (128 words, each of which stores 1 byte of data and 1 byte of garbage). The disk geometry is 76 tracks and 25 sectors per track, with sectors numbered 1-26, and sector 0 does not exist. But since 7 bits are allocated for storing the cylinder number, and 5 bits for the sector number, the image lying on the SD card contains 128 cylinders and 32 tracks. Unused data fields can contain anything - the controller ignores this information.

Since the disk image on the SD card lies in a rather perverted format, conversion of formats has been introduced into the sd-store and sd-extract utilities for extracting sector-by-sector images of DX-disks and writing them back to the card. The sd-extract utility outputs an image suitable for mounting in simh to the rx device. The sd-store utility writes such an image to the card in a format suitable for use by the controller.

### 10.3.4. MY NGMD Controller

This is probably the most complex and developed floppy disk controller of all those used in DVK. This is a purely Soviet development, which has no DEC analog. In the official documentation, the controller is called the cumbersome abbreviation "SCHI3.057.136", but I do not recall that anyone in real life called it that, everyone calls it simply MY according to the name of the MY.SYS driver that serves it.

The controller is designed to work with two NGMD-6022 or 6121 floppy drives. Each drive is dual-disk, 6022 supports 40 tracks (floppy capacity 400 Kb), and 6121 - 80 tracks (800 Kb). The drive has 2 heads. For data transfer, the controller uses DMA, which gives performance no worse than RK11. The MY controller forms a full 22-bit address in DMA mode and does not require Unibus Mapping support from the processor.

The original controller can work with sectors of 256, 512, and 1024 bytes. The format of a specific sector is stored in its header, written to the diskette track before the data field. Since there is no service information in the DSK container, this controller implementation only supports 512-byte sectors (10 sectors per track), which is more than enough for working with diskette images from DVK. There are also the following functional differences from the real controller:

- The "formatting" and "reading headers" commands are not supported. For a virtual disk on an SD card, these operations make no sense.
- The "read with mark" and "write with mark" commands work like regular read-write commands. There is nowhere to store marks, and in general, I have not encountered software that uses work with marked sectors.
- The controller only emulates an 80-track drive. At the same time, images of 40-track diskettes recorded on an SD card will be correctly read and written, but it is impossible to create an empty image of a 40-track diskette using the controller.

In other respects, the controller's behavior more or less corresponds to its real prototype. No problems with reading, writing files, creating a file system, and loading the OS have been identified.

### 10.3.5. RK611/RK07 Controller (DM)

The RK611 controller (Soviet analog - SM5408) was never used in personal dec-compatible computers. Such a controller with RK06/RK07 disks was installed on large SM computers - I encountered this on SM-1600 and SM-1420. Nevertheless, I included this controller in the project. Of the disks officially supported by the RT-11 system, RK07 is the largest - 53790 blocks (more than 26 Mbytes). The DW disk, which can formally be 64 MB in size, is not officially supported by RT-11 and requires a separate driver build (of which there are many different and incompatible with each other). Since the device size in RT-11 cannot exceed 32MB, 8 disks of 26 MB each are a good help for storing file dumps.

In operating systems, these disks are called DM:. They are supported by almost all operating systems, which finally allows you to start having fun with the RSX-11M OS. There are 2 types of disks - RK06 and RK07. They differ only in the number of tracks - RK06 has half as many. Therefore, I did not implement support for RK06 - there is no point in implementing a device with less capacity. Thus, we have an RK611 controller and 8 RK07 disks connected to it.

The original RK611 has a powerful built-in diagnostic subsystem that allows programmatically emulating the operation of a disk device, and even forming controller timing programmatically. I, of course, did not implement all this - it would increase the circuit size by a factor of 3 without improving functionality - this diagnostic mode is only used by test programs. In addition, I did not implement the commands for reading/writing headers. This would require hardware implementation of the SILO buffer, which is pointless - the SILO functions are performed by the SDSPI sector buffer. Thus, formatting DM disks is impossible (FORMAT.SAV and FMT.TSK utilities will not work), but it is not required either - we have an SD card, not a magnetic disk.

Since the disk sector size is 512 bytes, the disk image fits perfectly on the SD card. You can use disk images from the simh emulator without any changes.

### 10.3.6. RH70/RH-11 + RP06 Controller (DB)

This controller can be presented in two variants - RH-11 and RH-70. Which of the variants will be included in the circuit is determined by the presence of the massbus configuration variable in the config.v file. If the variable is defined, then the RH-70 variant is included, if not defined - then RH-11.

RH-11 is designed to connect to the common UNIBUS/QBUS bus, can only work with an 18-bit address, and requires UNIBUS Mapping hardware to work in systems with more than 256M RAM.

RH-70 represents an implementation of the MASSBUS bus that appeared in PDP11/70, and supports a full 22-bit address. Formally, in massbus mode, the controller can only be included with the PDP2011 processor board, but in real life, RSX-11M(+) and RSTS/E systems work correctly with the RH-70 controller in any processor configuration.

The controller has 8 RP06 disks connected to it. These are the largest pack disks of all the disk devices nomenclature, they have a capacity of just over 160 MB. The Soviet analog of such disks were ES-5067 devices. In my past life, I never encountered such disks in the flesh, the largest disks I saw were ES-5066 with a capacity of 100 MB (these are analogs of DEC RP05 and IBM 3330). A pack of such disks consisted of 12 platters, and required considerable physical strength to install it on the drive. In the perestroika years, decent decimeter antennas were made from such disks.

In operating systems, RP06 disks are called DB:. RT-11 does not have drivers for this type of disk, so it is pointless to include this controller in 16-bit configurations. Other operating systems perfectly support these disks, and a capacity of 160MB is quite sufficient for placing even the most resource-hungry RSX-11M-PLUS OS along with the DECUS library. If desired, the controller can be modified to support RP03/04 disks (DP:), which are also supported in RT-11, but there is not much point to this.

Since the disk sector size is 512 bytes, the disk image fits perfectly on the SD card. You can use disk images from the simh emulator without any changes.

## 10.4. Manual Loading of the Operating System from Disks

Not all boards contain loaders from all available disk devices. A full set of loaders is only in the 279 monitor of the MS1201.02 board. The monitor of the MS1201.01 board can only load the system from DX disks, and the MS1260 and MS1280 boards do not contain a single loader.

For loading from most disks, you can use the M9312 console emulator/loader. Nevertheless, you can, as in the good old days, load from any disk using monitor commands that work with memory cells. For devices operating in DMA mode, it is enough to enter the command code in the CSR register and command parameters in some other registers. For devices using programmatic exchange, a boot program is entered into RAM and executed.

### 10.4.1 Loading from RK

**Commands for loading from RK0 disk:**

```
@177406/000000 177400^
177404/000200 5 <CR>
@0G
```

The first command writes the word counter. 177400 is 1 disk sector. The second command starts the reading process. The sector is read from the disk and placed in RAM starting from address 0. The third command transfers control there.

### 10.4.2. Loading from MY Disk

The MY disk controller has a specialized command for OS loading. The loading process:

```
@172140/000040 37 <LF>
172142/000000 <CR>
@0G
```

The first command puts the controller in boot mode, the second sets the boot drive number - 0. After executing these two commands, the boot sector is read into memory from address 0. The third command transfers control there.

# 11. IRPS Controller

IRPS controllers implement a serial code communication line with a speed from 1200 to 115200 bits/s. The project includes two controllers:

IRPS1, at address 177560, is a console terminal through which the monitor and operating system communicate with the user. This port must be present in the circuit. In this project, the port is mated with the KSM terminal, but this is not necessary - you can output its signals outside and use an external terminal. The speed of the IRPS1 port is controlled by the KSM module (if it exists), the initial speed is set by the TERMINAL_SPEED parameter in the configuration file.

IRPS2, at address 176500, is an additional serial interface that can be used for many purposes. You can connect an additional terminal to it (RT-11 can work in a multi-terminal configuration). You can connect a printer with a serial port - this is much easier than making an interface adapter for centronics. In this case, the printer will work through the LS: device in RT-11. It can also be used to transfer files between computers. In this circuit, this interface uses a non-standard interrupt vector - 330-334 instead of 300-304. This is because vector 300 is occupied by the DW: HDD controller. When generating the system, you should specify the correct vector address for LS, XL devices and the additional terminal.

The speed of IRPS2 is fixed and is determined by the UART2SPEED parameter in the configuration file.

It is possible to swap both ports using the sw_console switch. Then IRPS2 is connected to the KSM module, IRPS1 signals are output externally, and the IRPS1 speed is fixed.

# 12. IRPR Controller

This module implements half of the IRPR interface - only the transmitter. The original IRPR, located on the MS1201 board, can also input data via a 16-bit bus, but I have never seen anyone use this. Everyone used this port exclusively for connecting printers. In RT-11, the port is serviced by the LP: driver.

Since real IRPR printers have become extinct like dinosaurs today, the module's external interface implements the centronics protocol, which in principle allows connecting any PC printer with a parallel interface. Naturally, you will have to make an interface circuit that converts FPGA 3.3V levels to the standard 5V for centronics, and buffers the output data lines. I deeply doubt that anyone will actually want to connect a physical printer, but the module is quite functional and let it remain in the project. Those who don't need it can remove it from the circuit and save about 50 FPGA cells.

# 13. Terminal Subsystem

The set of video controllers for the DVK-3 computer represents an amusing mixture of very ancient and more modern technologies. The set consists of two boards - the KSM text terminal and the KGD graphics controller. Both controllers are implemented in this project.

In the original computer, a monochrome MS6105 video monitor was used for display, and an MS7004 keyboard for input. In this project, any monitor with a VGA input is used for display, and a PS/2 keyboard for input. The controller uses a 800*600*75 Hz video mode. This mode is mandatory for all monitors, both CRT and modern LCD, even 4K monitors can display this. If the monitor doesn't have a VGA input, you can use a VGA2HDMI adapter - it has been tested and works. For monitors that incorrectly place the picture on the screen (image shift beyond the left edge), there is a correction of the horizontal sync pulse phase, set in the config.v configuration file.

## 13.1. KSM Controller

This controller is a full-fledged alphanumeric terminal, roughly compatible with DEC VT52. The controller is installed in the DVK backplane as a full-size board, but does not use the MPI bus - it only receives power from the backplane. Data transmission is carried out through a serial port, connected by a jumper to the IRPS connector of the MS1201 board. This way of connecting the operator console to the computer was used back in the days of teletypes and typewriters, and is more characteristic of large computers, not personal ones. The KSM board supports exchange speeds from 75 to 9600 baud. In this project, the range of supported speeds is changed - speeds from 1200 to 115200 baud are supported. Speeds below 1200 have no practical meaning, and speeds above 9600 the original controller probably could not support due to low performance.

The terminal screen consists of 25 lines of 80 characters each. The top line is for service information, displaying information about the terminal's settings and modes. The remaining 24 lines contain user data. This corresponds to the DEC VT52 terminal - it also used an 80*24 screen.

### 13.1.1. Controller Internal Structure

The controller is a full-fledged microprocessor device. The original KSM was built on the K580VM80A processor and several LSIs from the 580 series. The controller has a static working memory block with a capacity of 1K, ROM with a control program with a capacity of 2K, ROM with a character generator with a capacity of 2K, and video memory with a capacity of 16K, made on K565RU6 DRAM chips. The video memory is used rather wastefully - half of it is intended only to store a sign of the cursor's presence in a given character position. The rest of the video memory is organized as a buffer for storing 2 pages of text - 48 lines of 80 characters.

In this project, the controller is built on the K1801VM2 processor core from the respected VSLAV. Writing a control program for the PDP-11 command system, and even with EIS, is much more pleasant and easier than for the poor Intel 8080. In addition to the processor core, the controller includes a 4K RAM module, designed to store the control program and working variables, a 4K ROM module for storing fonts, and a 2K dual-port RAM module as video memory. Thus, the total size of memory used is significantly reduced compared to the original.

### 13.1.2. Supported Operating Modes

The control program fully supports the command system of the original controller, including the HOLD SCREEN mode and non-standard ESC sequences "line expansion" and "page expansion".

Pseudographics is supported, and it differs from the original DEC VT52 pseudographics both in the form of characters and in their codes (100-137 instead of 137-177).

An autonomous mode (local loop) is implemented, which is activated by the F10 button. In this mode, characters and commands entered from the keyboard immediately appear on the screen, and no exchange is made via the interface. This mode can be used to test and debug the keyboard and display module. This mode is also available in the original KSM.

Support for an audible signal (beeper) is implemented, as in all DEC terminals, as well as in 15IE-00-013. There is no beeper on the KSM board, but many programs, and the RT-11 OS itself, use the sound signal (by sending code 007), and it's quite easy to implement this feature. The ability to turn off the sound with the F9 button has been added to the control program. And for those who don't need sound at all - just don't connect the buzzer port anywhere.

Half-duplex mode (local echo) is not implemented due to its complete uselessness. The change of the serial interface frame format is also not implemented - transmission always goes in 8-bit mode without parity check.

Also not implemented is the automatic cursor movement to the next line mode. This mode is not present in DEC VT52, and there is little practical use for it. On the contrary, in this mode, the operation of full-screen text editors and other similar programs is disrupted. But, if desired, adding this mode to the control program is not at all difficult.

### 13.1.3. Character Encoding

The terminal works in 7-bit mode. The serial port frame format is 8-bit (8-N-1), but the highest bit of the byte is ignored. Two sets of character encodings are supported - KOI7 N0/1, and KOI7 N2.

In KOI7 N0 mode (default mode), the terminal works with the standard ASCII table, exactly like the original VT52. Small and large Latin letters are displayed. From encoding N0 (LAT), you can switch to encoding N1 (RUS), and the terminal displays small Russian letters instead of large Latin, and large Russian instead of small Latin. A mixture of characters from both encodings can be displayed on the screen. Switching between encodings is done with control codes 016 and 017.

In KOI7 N2 mode, the terminal displays only large Latin and Russian letters, with Russian letters occupying the place of small Latin letters in the standard ASCII table. This mode was used by terminals operated in conjunction with SM computers, for example, SM7209 or VTA-2000-3. Switching to this mode and back to N0/N1 mode is done with the F11 key.

In N2 mode, operation of original DEC operating systems is impossible, because all messages are output in a distorted form (the famous INVALID DEVICE). But in this mode, systems adapted in the USSR (RAFOS, for example) will work correctly, as well as many programs written at that time that used the Russian language, for example, the USED screen editor.

Non-displayable characters from the range 00-37, not recognized by the terminal as control commands, are displayed on the screen as Latin alphabet characters with code 100-137, flashing at a frequency of about 3 Hz. This display feature is present not only in the original KSM module but also in many terminals, for example, 15IE-00-013 and SM7209. The original DEC VT52 does not have this feature, and all unrecognized control codes are ignored.

### 13.1.4. Screen Format

The KSM display block works in the standard resolution for all such terminals: 24 user lines of 80 characters. The very top line of the terminal screen is the service line. Red letter indicators of operating modes are displayed in this line:

| Indicator | Description |
|-----------|-------------|
| LINE      | Communication mode with the computer. |
| LOCAL     | Autonomous mode (local loop) |
| CAPS      | CAPS LOCK is on. |
| ALT       | The alternative mode of the additional keyboard is on. |
| KOI7      | KOI7 N2 encoding is on |
| LAT       | N0 encoding is on |
| RUS       | N1 encoding is on |
| HOLD      | HOLD SCREEN mode is on |
| WAIT      | The terminal is waiting for the Scroll command to continue output |
| MUTE      | Sound signal is off. |

At the right edge of the service line, the current speed of the serial interface is displayed, as well as the time elapsed since the display was turned on.

The status line of this controller differs in appearance from the corresponding line of the original KSM. In the original, keywords were output in Russian letters, and some abbreviations were hard to understand (like ZVYV or DKL). Some parameters were displayed in the form of even more obscure bit fields. I believe that, for example, HOLD looks more understandable than ZVYV. However, if someone wants to be nostalgic about the old appearance of the line, it is not at all difficult to correct the inscriptions in the text of the control program.

The terminal screen itself starts from line 2. User data is displayed in green. It all looks like this:

![KSM Screen](Pictures/10000000000005A00000043854C5B096B7F1F94D.png)

The module supports 2 types of cursor - underline and a block the size of a character position. The cursor shape is switched with the F8 key. In the case of a block cursor, the character under it is displayed inverted. The cursor can also be blinking or non-blinking, this mode is switched with the F7 key.

The cursor is displayed in yellow.

### 13.1.5. Keyboard

The alphanumeric field of the keyboard is used to enter letters, numbers, and symbols. The layout of letters and symbols in all modes roughly corresponds to the standard AT keyboard layout (qwerty/йцукен) with small differences, which are easy to identify by experiment (too lazy to draw a picture with the layout).

The numeric keypad field is used exactly the same as on the MS7004 keyboard - in standard mode, numbers are entered, in the alternative mode - control codes. The - and + keys correspond to the up and down arrows. The Numlock, /, * keys correspond to the PF1, PF2, and PF3 codes of the standard VT52 keyboard (and are located in the same places). The missing left-right keys are moved to the cursor control field, and the up-down arrows are duplicated there.

The AT keyboard control keys have the following meanings:

| Key | Function |
|-----|----------|
| F5  | Decrease the serial interface speed by one step |
| F6  | Increase the serial interface speed by one step |
| F7  | Switch cursor shape - block/underline |
| F8  | Turn cursor blinking on/off |
| F9  | Turn the sound signal off/on. |
| F10 | Switch Line (connection to the computer)/Local (autonomous mode) modes |
| F11 | Turn KOI7 N2 encoding on/off (all capital letters) |
| L-ALT | Switch RUS (N1) / LAT (N0) encoding |
| R-ALT | Enter LF code - new line |
| Scrollock | Output the next line in HoldScreen mode (with shift - output the page) |
| PgDn | Expand the screen downward |
| PgUp | Expand the screen upward |
| Home | Set the cursor to the beginning of the screen |
| Ins  | Expand the line to the right |

### 13.1.6. Font

The original KSM controller displays 8*8 character positions. In this development, character positions have a size of 8*12, which allows the use of a clearer and more legible font.

The circuit includes a 4K ROM (created in the FPGA's static memory) with the image of the character generator font. The original font images are in ksm-firmware/font/font-*.bin. The layout of character codes inside the font file:

00-1f (000-037) capital Latin letters (for indicating control codes)
20-3f (040-077) numbers and common symbols
40-5f (100-137) capital Latin letters
60-7f (140-177) small Latin letters
80-9f (200-237) pseudographics
a0-bf (240-277) not used
c0-df (300-337) small Russian letters
e0-ff (340-377) capital Russian letters

Two font files are attached to the project.

**font-main.bin** - the main 8*12 font, mostly ripped from some ancient DOS Russifier. Most of the symbol lines have a thickness of 2 pixels, and the font looks quite decent on modern TFT monitors.

**font-ksm.bin** - 8*8 font, ripped from the KSM board's character generator (the 15IE terminal uses the same font). When using this font, the screen looks exactly the same as the KSM screen. I attached this font for those nostalgic for the old times, as well as for a visual comparison of the crooked ancient fonts with modern ones.

Here is an example of an image formed by the KSM font:

![KSM Font Example](Pictures/10000000000005A0000004387B3E092973ABCF00.png)

The font used is connected to the fontrom megafunction. The font selection is made in the config.v configuration file.

Also in the ksm-firmware/font directory are some utilities for processing font files:

**font2mif** - converter of a font file (bin) to mif format for loading into FPGA.
**fontlist** - displays images of all fonts of the specified bin file on the screen
**fontextract** - extracts the font of the specified or all characters from the bin file
**fontreplace** - replaces the specified character in the bin file.

The character image extracted from the binary file is a text rectangle of 8*12 characters, in which pixels forming the image are denoted by the character O, the rest - by a dot:

```
..OOO...
.OO.OO..
OO...OO.
OO...OO.
OO...OO.
OOOOOOO.
OO...OO.
OO...OO.
OO...OO.
.......
.......
```

This form is convenient for editing the character image. It's better not to use the 2 lower lines to place the image, since the cursor in underline mode is placed on these lines.

## 13.2. KGD Controller

KGD (Graphic Display Controller) is a monochrome graphic controller that displays an image of 400*286 on the screen. The controller connects directly to the MPI bus and is represented on it by four registers. This approach is more modern compared to connection through a serial port.

KGD is not a full-fledged video controller - it cannot form a complete set of video signals, and only works in pair with the KSM module. Since KSM forms an 800*600 image, each graphic pixel occupies 2 points horizontally and vertically. At the same time, a dark field with a height of 28 points remains in the upper part of the screen. Video data formed by the text and graphic controllers can be output to the screen simultaneously, overlapping each other. Also, using the KGD registers, you can prohibit the output of text or graphic information.

The controller contains a 16K dual-port video memory, which is accessible through address and data registers. The video memory is formed as a 2-port altsyncram megafunction from the FPGA's internal memory. This imposes serious restrictions on the type of FPGA used - the smallest of the Cyclone 4 series, the EP4CE6 chip, does not contain a sufficient amount of memory.

Note that the KGD controller occupies memory addresses reserved by the DEC standard for one of the local DL11 serial ports. Therefore, when loading the RSTS/E OS, during the initial hardware initialization, the text screen is erroneously turned off and the image disappears. Therefore, for configurations that provide for loading RSTS/E, the KGD controller should be excluded from the circuit.

## 13.3. Hardware Features of the Terminal Subsystem

The KSM module can control the sound signal by code 007 - this feature was not in the original controller. The signal is transmitted through the buzzer port and takes the value 1 when sound needs to be turned on. It can be directly fed to a piezo buzzer with a built-in sound generator. Or create a timer/divider at a frequency of about 400 Hz and use it to generate sound. Or do without sound at all, as in the real KSM.

On the screen, the image has the following colors:

- Status line - red color
- Clock - purple color
- User data - green color
- KGD graphics - white color
- Cursor - yellow color.

If you want to get a completely monochrome image, as on ancient monitors, then the vgared, vgagreen, vgablue signals coming out of the KSM module, as well as the vgavideo signal coming out of the KGD module, should be combined using an OR circuit and fed to all 3 video DACs, configuring these DACs to form the desired shade of the image. This way, you can get black-green, black-yellow, black-white, and any other monochrome image.

The PS/2 keyboard Clock and Data lines should be pulled up to 3.3V power. For this, you can enable internal pull-up resistors in the FPGA (the weak pull-up resistor option in the assignments editor), or solder external resistors of 2-5k between each line and 3.3V, if there are none on your board.

Some monitors and video capture devices incorrectly display the picture - it partially goes beyond the left edge of the screen. In this case, you should correct the phase of the horizontal sync pulse. In the config.v file, you need to uncomment the line

```
`define hsync_shift 11'd27
```

and specify by how many pixels the picture should be shifted (in this example - 27).
