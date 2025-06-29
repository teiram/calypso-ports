
m9312hs = m9312h40.vhd

bootroms = m9312l-minc.vhd m9312h-minc.vhd m9312l-pdp2011.vhd m9312h-pdp2011.vhd m9312l-odt.vhd m9312h-odt.vhd

blockram = blockramt25.vhd blockramt27.vhd

vtbr = vtbr.vhd
xubr = xubr.vhd
xubw = xubw.vhd

allromram = $(bootroms) $(vtbr) $(xubr) $(xubw) $(m9312hs) vgafont.vhd

all: $(allromram)

vgafont.vhd: vgafont.txt vgafont.mem
	fontconvert vgafont.txt|sed -e '/INSERT/r /dev/stdin' vgafont.mem >$@

%.obj: %.mac
	macro11 $< -o $*.obj -l $*.lst

$(bootroms): %.vhd: %.obj %.mem
	genblkram -s 16 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

$(m9312hs): %.vhd: %.obj %.mem
	genblkram -s 1 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

$(blockram): %.vhd: %.obj %.mem
	genblkram -s 512 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

$(vtbr): %.vhd: %.obj %.mem
	genblkram -s 256 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

$(xubr): %.vhd: %.obj %.mem
	genblkram -s 256 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

$(xubw): %.vhd: %.obj %.mem
	genblkram -s 512 -i $*.obj|sed -e '/INSERT/r /dev/stdin' $*.mem >$@

clean:
	rm -f $(allromram) $(allromram:.vhd=.obj) $(allromram:.vhd=.lst)


