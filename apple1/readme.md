# Information
Apple-I port from [the MiSTer version here](https://github.com/MiSTer-devel/Apple-I_MiSTer)

# How to run
The needed ROMs are embedded into the core
Software can be loaded from ASCII (TXT) files or also with the TAPE
module, which supports BINary files.

## Loading from Tape:
1. Execute the tape loader at C100 from Woz Monitor:
`C100R
2. Find out the start and end addreses for loading the binary
`<START ADDRESS>.<END ADDRESS>R
3. Don't press enter yet, go to the tape loader and start the TAPE
4. After around 5 seconds (once the pilot pulses start playing), press enter on Woz Monitor
5. Once the tape is loaded, the computer will return control
6. Jump to the start address with
`<START ADDRESS>R


# Changelog
- 0.2. ACI support (Tape device)
- 0.1. Initial release
