# Information
IMSAI8080 calypso core

# Credits
- Viacheslav Slavinsky and Sorgelig: WD1793 implementation.
- Fred VanEijk and Cyril Venditti: Altair8800 core, from which I took some code and ideas.
- 1801BM1@gmail.com for the 8080 implementation.

# Current status
The IMSAI8080 runs and supports two disc drivers.
On startup a monitor ROM MEMON/80 is loaded at address F800. You would need to jump to that address (using the panel address switches, examine and run) to load the monitor and eventually boot a disk
Disks must be in format EDSK, with the following format:
- 77 tracks
- 26 sectors of 128 bytes per sector
- 64 directory entries
- 2 system tracks

# Usage
You need two roms in the SD root folder or the IMSAI8080 folder:
- IMSAI8080.ROM. The panel image. It is a indexed raw image with a palette of 16 colors.
- IMSAI8080.R01. The monitor ROM. It is loaded at address F800.

On startup the panel is preselected and the computer boots in WAIT mode.

Keys 1-8 are used to toggle the address switches

Keys Q-I are used to toggle the data switches

Keys A/Z, S/X, D/C, F/V are used to operate the momentary switches on the right side.

Control-F1 can be used to assign the keyboard to the panel or to the console

Control-F2 can be used to swap the location of panel and console on the screen.

Typical usage sesion:
- Set the address switches to the address F800 (pressing 1,2,3,4,5)
- Press EXAMINE to jump to that address (key A). You should see the value F3 on the data bus.
- Press RUN to start running at the current examined address (key F). The console should show the MEMON/80 banner.
- Mount a bootable disk on drive 0, and boot from the monitor (command BO). To do that you need to switch the keyboard to the console (Control-F1)

# Special Keys
- 1-8. Toggles for the address bus
- Q-I. Toggles for the data switches
- A, Z, S, X, D, C, F, V. Momentary switches (EXAMINE, EXAMINE NEXT), (DEPOSIT, DEPOSIT NEXT), (RESET, EXT CLR), (RUN,STOP), (SINGLE STEP)
- Control-F1. Toggles keyboard assignment between panel and console
- Control-F2. Swaps position of panel and console

# Known issues
On startup sometimes the panel is drawn 8 pixel to the right, producing some other issues on the rendering of the toggle bars or the disk leds. The computer will work anyways and resetting from the OSD normally fixes it after one or two attempts.

The monitor ROM is currently loaded at F800, but it can be overwritten, for instance if you start CP/M afterwards. So you cannot go back to the monitor unless you:
- Completely reload the core again.
- Go back to the console, stop the IMSAI8080 (key V)
- Reload the ROM from the OSD (you need to copy it somewhere with extension ROM)
- Examine F800, Run

# Changelog
- 0.1. First version.


