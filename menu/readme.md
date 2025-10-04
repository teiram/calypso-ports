# Information
Core Menu, to select the core to run from the SD card, ported from the [MiST Menu](https://github.com/mist-devel/Menu_MIST)
# Current status
Seems to work properly
# How to run
Drop the menu rbf file on your SD Card root, name it as CORE.RBF and the [firmware](https://github.com/teiram/calypso-firmware) will upload via JTAG the core into the FPGA, allowing you to select the core to run.

You can optionally provide a background image in raw format (RGBA) of 640x312 pixels named as MENU.ROM in the root of the SD card.

You can find a sample image as [menu.rom](menu.rom) in this folder, which would look like this, but with a slightly different aspect ratio and less colors:

![Sample](menu.rom?raw=true "Sample Background")

# Changelog
- 0.4. The KITT mode
- 0.3. Configuration option to change the background

