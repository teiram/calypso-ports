# Information
Amstrad CPC port based on the [MiST Core](https://github.com/sorgelig/Amstrad_MiST)
# Current status
Not working. The core doesn't even start video. It seems the CRTC is disabling the sync signals, maybe some initialization problem or bad SDRAM setup so that ROM is not stored/running properly.
# How to run
A customized AMSTRAD.ROM file have to be provided in the SD card root folder, with the following layout:

OS6128 + BASIC1.1 + AMSDOS + MF2 + OS664 + BASIC664 + AMSDOS + MF2

Each part with 16KB size, so a file of 128KB
