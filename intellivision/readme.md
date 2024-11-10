# Information
Intellivision port based on the MiST port  [available here](https://github.com/robinsonb5/Intv_DeMiSTified)
# Current status
No known issues at this point.
# How to run
This core needs a ROM file, called INTV.ROM, on the root of the SD card.

The ROM file has the following format:

Size	Original name	Content
8Kb	exec.bin	System ROM
2kb	grom.bin	Character generator ROM
2kb	sp0256-012.bin	Intellivoice ROM
24kb	ecs.bin	ECS extension ROM
The INTV.ROM file can be constructed like this:

    cp exec.bin boot.rom
    cat grom.bin >>boot.rom
    cat sp0256-012.bin >>boot.rom
    cat ecs.bin >>boot.rom
