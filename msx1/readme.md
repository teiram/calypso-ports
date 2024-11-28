# Information
MSX1 port based on the [BigMiST Core](https://github.com/BigMist/msx1fpga)
# Current status
Sound output seems to be a bit low
# How to run
So far a MSX.VHD virtual drive is needed on the root of the SD-Card with the following layout/information:

Put the NEXTOR.SYS and COMMAND2.COM files, create a directory called 'MSX1FGPA', put the CONFIG.TXT and KEYMAPs in this directory. Put ROMs and Utilities in the SD Card for MSX use. PS: Due to a Nextor bug, FAT16 partitions with ID 0x0E are not recognized, only with ID 0x06.
# Changelog
- 0.2 AUDIO_IN support added
- 0.1 First version
