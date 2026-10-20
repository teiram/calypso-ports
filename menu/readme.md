# Information
Core Menu, to select the core to run from the SD card, ported from the [MiST Menu](https://github.com/mist-devel/Menu_MIST)
# Current status
Seems to work properly
# How to run
Drop the menu rbf file on your SD Card root, name it as CORE.RBF and the [firmware](https://github.com/teiram/calypso-firmware) will upload via JTAG the core into the FPGA, allowing you to select the core to run.

You can optionally provide a background image in raw format (RGBA) of 640x312 pixels named as MENU.ROM in the root of the SD card.

You can find a sample image as [menu.rom](menu.rom) in this folder, which would look like this, but with a slightly different aspect ratio and less colors:

![Sample](menu.rom?raw=true "Sample Background")

# Background

The **Background** submenu selects what is shown behind the OSD:

- **Type**: Waterfall (default), Matrix ("digital rain"), Sea (waves that
  sway left and right and water coming and going on a sandy shore), Classic
  (the original background) or File (the MENU.ROM picture or a BMP loaded
  with *Change background*; Classic if there is none). By @shaeon
- **Speed**: animation speed of every background except File: Normal, Slow,
  Very slow or Fast.
- **Calypso Logo**: On / Off. The red "Calypso" logo from menu.rom is drawn in
  the bottom right corner of every background except File (the picture
  already has it).

# LCD clock

If a USB RTC is connected and the firmware sends the time to the core (MiST
`UIO_SET_RTC`), the menu shows an LCD style clock panel with the date in
small digits and the time (HH:MM, with smaller seconds) in big digits. The
panel only appears while the RTC is present. Its options are in the
**Clock** submenu:

- **Clock**: On / Off.
- **Size**: 1x (default) or 2x.
- **Segments**: Flat (default) or Pointed: hexagonal segments with 45 degree
  "<=>" ends, as in big LED clocks, drawn at full resolution in 2x (the small
  date digits are always flat).
- **Panel**: On (default) or Off (only the digits, drawn over the background).
- **Shadow**: On (default) or Off: the unlit segments. Without the panel they
  are drawn as a faint shadow over the background.
- **Vertical**: Bottom (default), Top or Center.
- **Horizontal**: Center (default), Left or Right.
- **Date**: DD-MM-YYYY (default), MM-DD-YYYY or YYYY-MM-DD.
- **Weekday**: Off (default), English (MON) or Spanish (LUN), shown to the
  left of the date. The day is the one set in the firmware's Date & Time page.
- **Color**: Green LCD, Gray LCD, Blue, Amber, Game Boy, Red LED, VFD or
  Inverted.

The bottom and top positions keep the OSD area free in PAL mode.

See [rtc-usb-mist-rp2040](https://github.com/shaeon/rtc-usb-mist-rp2040) for a
USB RTC based on a Raspberry Pi Pico. On the Calypso it needs a firmware with
USB RTC support.

# Changelog
- 0.6. Animated backgrounds (Waterfall, Matrix, Sea) with speed option and Calypso logo; File/animated selection. LCD clock when a USB RTC is present, with size, segment style, weekday, panel, shadow, position, date format and color options
- 0.5. Configurable OSD position and color
- 0.4. The KITT mode
- 0.3. Configuration option to change the background

