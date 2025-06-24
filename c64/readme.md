# Information
Commodore 64 port based on the [MiST core](https://github.com/mist-devel/c64) 
# Current status
The computer starts and can run BASIC programs
Cartridges and D64 disk images seem to work too
# Usage
A C64.ROM file must be at the root of the SD Card. The ROM format is basic+kernal+1541. The file size can be 16k (basic+kernal) or 32k (basic+kernal+1541).
# Special Keys (from the original documentation)
- F9 - Pound
- F10 - Plus
- F11 - Restore/Freeze
- CTRL+F11 - Soft reset
- Page Up - Start/Stop tape
# Changelog
- 0.1. First version.
- 0.2. Fixed disk support
- 0.3. Replaced SID with rampa069 version
- 0.4. Simplify clocks, fix TAP load, hpos/vpos 

