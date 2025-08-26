# Information
Amstrad CPC port based on the [MiST Core](https://github.com/sorgelig/Amstrad_MiST)

# Current status
No known issues at this point.

# Limitations
SDRAM layout was reduced from the original port, to cope with more limited SDRAM on the Cyc 1000

# How to run
A customized AMSTRAD.ROM file have to be provided in the SD card root folder, with the following layout:

OS6128 + BASIC1.1 + AMSDOS + MF2 + OS664 + BASIC664 + AMSDOS + MF2

Each part with 16KB size, so a file of 128KB

# Changelog

- 0.4. Upgrade framewors. Big OSD. Menu reorganization
- 0.3. Increase audio volume

