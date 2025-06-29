#!/bin/bash

for i in `find . -name *.qsf`
do
   echo $i;
   sed -i '/VHDL_FILE.*\.\./d' $i
   cat <<HERE >>$i

set_global_assignment -name VHDL_FILE ../unibus.vhd
set_global_assignment -name VHDL_FILE ../pdp2011.vhd
set_global_assignment -name VHDL_FILE ../sdram.vhd
set_global_assignment -name VHDL_FILE ../panelos.vhd
set_global_assignment -name VHDL_FILE ../paneldb.vhd
set_global_assignment -name VHDL_FILE ../paneldriver.vhd
set_global_assignment -name VHDL_FILE ../cpu.vhd
set_global_assignment -name VHDL_FILE ../cpuregs.vhd
set_global_assignment -name VHDL_FILE ../fpuregs.vhd
set_global_assignment -name VHDL_FILE ../cr.vhd
set_global_assignment -name VHDL_FILE ../mmu.vhd
set_global_assignment -name VHDL_FILE ../kl11.vhd
set_global_assignment -name VHDL_FILE ../kw11l.vhd
set_global_assignment -name VHDL_FILE ../csdr.vhd
set_global_assignment -name VHDL_FILE ../rh11.vhd
set_global_assignment -name VHDL_FILE ../rl11.vhd
set_global_assignment -name VHDL_FILE ../rk11.vhd
set_global_assignment -name VHDL_FILE ../sdspi.vhd
set_global_assignment -name VHDL_FILE ../dr11c.vhd
set_global_assignment -name VHDL_FILE ../xu.vhd
set_global_assignment -name VHDL_FILE ../xubl.vhd
set_global_assignment -name VHDL_FILE ../xubm.vhd
set_global_assignment -name VHDL_FILE ../xubr.vhd
set_global_assignment -name VHDL_FILE ../xubf.vhd
set_global_assignment -name VHDL_FILE ../xubw.vhd
set_global_assignment -name VHDL_FILE ../mncdo.vhd
set_global_assignment -name VHDL_FILE ../mncdi.vhd
set_global_assignment -name VHDL_FILE ../mncaa.vhd
set_global_assignment -name VHDL_FILE ../mnckw.vhd
set_global_assignment -name VHDL_FILE ../mncad.vhd
set_global_assignment -name VHDL_FILE ../ibv11.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/miodi.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/miodo.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/mncadagg.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/mncadtpg.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/pmodcolor.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/pmodda2.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/pmodda4.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/pmodhygro.vhd
set_global_assignment -name VHDL_FILE ../mincdrv/pmodnav.vhd
set_global_assignment -name VHDL_FILE ../vt.vhd
set_global_assignment -name VHDL_FILE ../vtbr.vhd
set_global_assignment -name VHDL_FILE ../vga.vhd
set_global_assignment -name VHDL_FILE ../vgacr.vhd
set_global_assignment -name VHDL_FILE ../vgafont.vhd
set_global_assignment -name VHDL_FILE ../ps2.vhd
set_global_assignment -name VHDL_FILE "../m9312h-pdp2011.vhd"
set_global_assignment -name VHDL_FILE "../m9312l-pdp2011.vhd"
set_global_assignment -name VHDL_FILE "../m9312h-odt.vhd"
set_global_assignment -name VHDL_FILE "../m9312l-odt.vhd"
set_global_assignment -name VHDL_FILE "../m9312h-minc.vhd"
set_global_assignment -name VHDL_FILE "../m9312l-minc.vhd"

HERE
done
