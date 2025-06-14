.SUFFIXES: .hex .ROM .jp

PRG            = mzmain
OBJ            = mzmain.o tff.o diskio.o
SREC           = srec_cat
CC             = avr-gcc
MCU_TARGET     = atmega103
OPTIMIZE       = -Os

DEFS           =
LIBS           =

override CFLAGS        = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) $(DEFS)
override LDFLAGS       = -Wl,-Map,$(PRG).map

OBJCOPY        = avr-objcopy
OBJDUMP        = avr-objdump

all: lst mzdata.hex

mzdata.hex: temp3.hex
	$(SREC) temp3.hex -intel -fill 0xff 0x00000 0x40000 -o $@ -intel;cp mzdata.hex /cygdrive/c/develop/mz700/.

temp3.hex: temp2.hex newmon7.hex
	$(SREC) temp2.hex -intel newmon7.hex -intel -offset 0x6000 -o $@ -intel

temp2.hex: temp1.hex mz700fon.hex
	$(SREC) temp1.hex -intel mz700fon.hex -intel -offset 0x5000 -o $@ -intel

newmon7.hex: NEWMON7.ROM
	$(SREC) NEWMON7.ROM -binary -o $@ -intel
#newmon7.hex: MZ700.ROM
#	$(SREC) MZ700.ROM -binary -o $@ -intel
#newmon7.hex: SA1510.ROM
#	$(SREC) SA1510.ROM -binary -o $@ -intel

mz700fon.hex: mz700fon.jp
	$(SREC) mz700fon.jp -binary -o $@ -intel
#mz700fon.hex: mz-80acg.rom
#	$(SREC) mz-80acg.rom -binary -o $@ -intel

temp1.hex: mzmain.hex
#	$(SREC) mzmain.hex -intel -offset 0xfffffd80 -o $@ -intel
	cp mzmain.hex temp1.hex

$(PRG).elf: $(OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

lst:  $(PRG).lst

%.lst: %.elf
	$(OBJDUMP) -h -S $< > $@

hex:  $(PRG).hex

%.hex: %.elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@

clean:
	-rm *.hex *.o *.lst *.map *.elf

.c.o:
	$(CC) $(CFLAGS) -c $<

mz700fon.hex: mz700fon.jp
