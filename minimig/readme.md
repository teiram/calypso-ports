# Information
Amiga (Minimig-AGA) core based on the MiST core that can be found [here](https://github.com/mist-devel/minimig-mist)
# Current status
Boots into the kickstart floppy screen. Can open .afd files and run some games succesfully. 
Was not tested extensively yet.
Needs at least calypso-firmware 0.5 on the MCU.
# Changelog
- v0.6. Expose TX and RX to the AUX connector
- v0.5. Check RAM and Fast RAM supported (Slow RAM hungs before kickstart)
- v0.4. Kickstart loads now with fast RAM
- v0.3. Slight memory changes. Seems to load the kickstart more safely
- v0.2. Sound support added.
- v0.1. Initial version. No sound support
# How to run
You need a kickstart ROM, by default should be placed on the root directory of the SD-Card with name KICK.ROM.
