# Calypso Ports
## Motivation
This repository provides a centralized, curated collection of core implementations ready to be used on your [Calypso Board](https://github.com/teiram/calypso-cyc1000-board). 
Such cores expect a running firmware on the board pico MCU like the one you can find [here](https://github.com/teiram/calypso-firmware)

You are very welcome to contribute to this repository by mean of pull requests if you have ported a new core or improved any core already available. The aim is to have a single spot to find cores that are ready to be used on Calypso.

## Porting a core
Most of the cores I´ve ported are based on some existing Mist version. Since the Calypso firmware is mainly compatible with the Mist interfaces (in fact it embeds the official mist firmware) very few changes should be needed.

The points you must pay attention to are:

- General layout. My approach is to add a git submodule for the upstream version (mostly the Mist core) and then on the root folder of the core to be ported, add the needed files for Calypso, always trying to leave the upstream repository untouched.
  - Each port will be stored in a folder
  - Upstream code should be added as git submodules. This will ease the task of updating the upstream code.
  - There will be only a Quartus project file (.qpf) on the root folder of the port.
  - A readme.md file will be provided on the root folder of the port, stating basic information including:
      - Upstream code provider (original author or github repository)
      - Current status of the core. If it works or not, and in case it doesn't, information about what are the known issues. This will allow others to support.
      - Some information about how to run the core (needed files, ...)
   - I also plan to add a metadata file to each port root folder, this file will be used to automate the generation of binaries from the sources, and its definition is a work in progress.
- Pinout. The pinout is of course different and documented in [the calypso board repository](https://github.com/teiram/calypso-cyc1000-board). You can also find inspiration in the existing cores, where the pinout is already exposed in the qsf file.
- IP elements. IP elements provided by Quartus normally need to be upgraded or redefined for the Cyclone 10. Take also into account the master clock of the Cyclone 10 runs at 12Mhz what must be carefully taken into account in order to correctly calculate PLL factors.
- SDRAM. The cyc1000 board sitting on Calypso has 8MB of SDRAM. Also the SDRAM initialization sequence is slightly different to the one on MiST hardware. This must also be considered during porting if the core uses SDRAM.
- Timing constraints. Since timing constraints (.sdc files) take into account the master clock frequency (period) it´s somehow recommended to provide a .sdc file for Calypso with the proper adaptations.

## Binaries
This repository is only intended to store source code. My plan is to try to automate the creation of the binaries by means of github actions, but that it still under planning and so far you would need to use Quartus to generate the binaries from the available sources.
