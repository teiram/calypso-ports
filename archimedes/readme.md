# Information
Acorn Archimedes port based on this [MiST Core](https://github.com/mist-devel/archimedes)
# Current status
The core starts and runs RISCOS. Games and applications seem to run.
During boot the display can go out of sync for a while, but eventually it will show boot messages and the desktop.
# How to run
The following files are needed:
- RISCOS.ROM


Additionally, you can provide the following files:
- FLOPPY0.AFD. Will be mounted as first floppy drive
- FLOPPY1.AFD. Will be mounted as second floppy drive.
- ARCHIE1.HDF. Will be mounted as first IDE drive
- ARCHIE2.HDF. WIll be mounted as second IDE drive.
- CMOS.RAM. Not sure if this is relevant or not for the core behavior.
