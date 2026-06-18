ASL = asl
P2BIN = p2bin
ASLARGS = -L

all: sectors.bin

sectors.bin: bdos.blocks ccp.blocks loader.blocks imsai-bios.blocks
	cat loader.blocks ccp.blocks bdos.blocks imsai-bios.blocks > sectors.bin

loader.blocks: loader.bin
	cat loader.bin /dev/zero | dd iflag=fullblock of=loader.blocks bs=128 count=1

loader.bin: loader.p
	$(P2BIN) loader.p

bdos.blocks: bdos.bin
	cat bdos.bin /dev/zero | dd iflag=fullblock of=bdos.blocks bs=128 count=28

bdos.bin: bdos.p
	$(P2BIN) bdos.p

ccp.blocks: ccp.bin
	cat ccp.bin /dev/zero | dd iflag=fullblock of=ccp.blocks bs=128 count=16
	
ccp.bin: ccp.p
	$(P2BIN) ccp.p

imsai-bios.blocks: imsai-bios.bin 
	cat imsai-bios.bin /dev/zero | dd iflag=fullblock of=imsai-bios.blocks bs=128 count=4

imsai-bios.bin: imsai-bios.p
	$(P2BIN) imsai-bios.p

loader.p: loader.asm
	$(ASL) $(ASLARGS) loader.asm

bdos.p: bdos.asm
	$(ASL) $(ASLARGS) -D origin=0e400h bdos.asm

ccp.p: ccp.asm
	$(ASL) $(ASLARGS) -D origin=0dc00h ccp.asm

imsai-bios.p: imsai-bios.asm
	$(ASL) $(ASLARGS) imsai-bios.asm

clean:
	rm *.p *.bin *.blocks *.lst
