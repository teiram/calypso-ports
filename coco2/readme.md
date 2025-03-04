# Information
CoCo2/Dragon port based on the [MiST Core](https://github.com/gyurco/CoCo2-FPGA)
# How to run
A customized COCO2.ROM file must be provided in the SD card root folder (or core folder), with the following layout, based on the mame project ROMS:

- bas12.rom.     Tandy CoCo2 basic ROM (8Kb) 0000 -  1FFF
- extbas11.rom.  Extended Basic ROM (8Kb)    2000 -  3FFF
- disk11.rom.    Disk ROM (8Kb)              4000 -  5FFF
- d32.rom.       Dragon 32 ROM (16Kb)        6000 -  9FFF
- d64_1.rom      Dragon 64 ROM1 (16Kb)       A000 -  FFFF
- d64_2.rom      Dragon 64 ROM2 (16Kb)      10000 - 13FFF
- ddos10.rom     Disk OS (8Kb)              14000 - 15FFF

# Changelog
- 0.1. Initial release
