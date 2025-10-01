# Information

Timex Sinclair 2068 port from Kyp069 [core](https://github.com/Kyp069/ts2068)

# Usage

Place TS2068.ROM in the root of the SD card or the core folder.

The ROM is build up from the following parts
- 0000 - 3FFF. Main TS2068 ROM (16Kb)
- 4000 - 5FFF. Extra TS2068 ROM (8kb)
- 6000 - 7FFF. ESXDOS DIVMMC ROM (8Kb)
 
For DivMMC a Spectrum 48K ROM must be loaded using the OSD

Remember to reset using Space + F9 once DivMMC is enabled

# Changelog
- 0.4. Fix swap joysticks OSD option
- 0.3. Enable PageUp and PageDown to start/stop internal TZX player
- 0.2. Fixed DivMMC support (You need a Spectrum 48K ROM to use DivMMC)
- 0.1. Initial release

