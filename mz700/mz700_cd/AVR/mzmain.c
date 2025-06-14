#include <string.h>
#include <avr/interrupt.h>
#include <avr/io.h> 
#include "tff.h"
#include "diskio.h"
#include "integer.h"

#include "mzmain.h"

ISR(INT0_vect)
{
	unsigned char drv,i,side;
	FRESULT res;
	WORD r;

	fdcmode=fdcmd >> 4;
/*	drv=(fdetc>>4)&1;
	side=fdetc&1;
	fdcsts|=1;		// BUSY flag set
	fdsts=fdcsts;
	if((fdetc&0xc0)==0xc0){
		fdcsts&=0x7f;		// NOT Ready flag clear
		switch(fdcmode){
			case 0:		// TYPE I:Restore
				while(d88trk[drv]>0){
					wait20ms();
					fdtrk=--d88trk[drv];
				}
				d88trk[drv]=0;
				fdcsts&=0xfe;	// BUSY flag clear
				fdetc=1;		// TRACK00 flag set
				break;
			case 1:		// TYPE I:Seek
				i=fdtrk;
				if(i>fddat){
					while(i>fddat){
						wait20ms();
						fdtrk=--i;
						d88trk[drv]--;
						if(d88trk[drv]==0) break;
					}
					fdcstep=-1;
				} else {
					while(i<fddat){
						wait20ms();
						fdetc=0;		// TRACK00 flag clear
						fdtrk=++i;
						d88trk[drv]++;
						if(d88trk[drv]==39) break;
					}
					fdcstep=1;
				}
				if(d88trk[drv]==0) fdetc=1;		// TRACK00 flag set
				fdcsts&=0xfe;	// BUSY flag clear
				break;
			case 2:		// TYPE I:Step
			case 3:		// TYPE I:Step(update)
				wait20ms();
				if(fdcstep==-1 && d88trk[drv]>0){
					d88trk[drv]--;
				} else if(fdcstep==1 && d88trk[drv]<39){
					d88trk[drv]++;
				}
				if(fdcmode==3) fdtrk=d88trk[drv];
				if(d88trk[drv]==0) fdetc=1;		// TRACK00 flag set
				fdcsts&=0xfe;	// BUSY flag clear
				break;
			case 4:		// TYPE I:Step in
			case 5:		// TYPE I:Step in(update)
				wait20ms();
				if(d88trk[drv]>0) d88trk[drv]--;
				if(fdcmode==5) fdtrk=d88trk[drv];
				fdcstep=-1;
				if(d88trk[drv]==0) fdetc=1;		// TRACK00 flag set
				fdcsts&=0xfe;	// BUSY flag clear
				break;
			case 6:		// TYPE I:Step out
			case 7:		// TYPE I:Step out(update)
				wait20ms();
				fdetc=0;		// TRACK00 flag clear
				if(d88trk[drv]<39) d88trk[drv]++;
				if(fdcmode==7) fdtrk=d88trk[drv];
				fdcstep=1;
				fdcsts&=0xfe;	// BUSY flag clear
				break;
			case 8:		// TYPE II:Read data(single)
			case 9:		// TYPE II:Read data(multiple)
				res=f_lseek(&d88fo[drv], d88table[drv][d88trk[drv]+side]+fdcsect*(256+16)+16);
				res=f_read(&d88fo[drv], (char *)fdcbuf, 256, &r);
				fddat=fdcbuf[0];
				fdcptr=0;
				fdcsts|=2;		// DRQ flag set
				fdint=1;
				break;
			case 10:	// TYPE II:Write data(single)
			case 11:	// TYPE II:Write data(multiple)
				break;
			case 12:	// TYPE III:Read address
				res=f_lseek(&d88fo[drv], d88table[drv][d88trk[drv]+side]);
				res=f_read(&d88fo[drv], (char *)fdcbuf, 6, &r);
				fddat=fdcbuf[0];
				fdcptr=0;
				fdcsts|=2;		// DRQ flag set
				fdsect=d88trk[drv];
				fdint=1;
				break;
			case 15:	// TYPE VI:Force inturrupt
				fdint=0;
				fdcsts&=0xfe;	// BUSY flag clear
				break;
			case 13:	// TYPE III:Read track
			case 14:	// TYPE III:Write track
			default:
				break;
		}
	} else {
		fdcsts|=0x80;		// NOT Ready flag set
	}
	fdsts=fdcsts;*/
}

ISR(INT1_vect)
{
}

ISR(INT2_vect)
{
	unsigned char drv,side;
	FRESULT res;
	WORD r;

	fdcsts&=0xfd;		// DRQ flag clear
	fdsts=fdcsts;
	fdcptr++;
	fddat=fdcbuf[fdcptr];
	if(fdcptr==6 && fdcmode==12){
		fdcptr--;
		fdint=0;
	} else if(fdcptr==0xff && fdcmode==9){
		fdcsect++;
		fdsect=fdcsect;
		drv=(fdetc>>4)&1;
		side=fdetc&1;
		res=f_lseek(&d88fo[drv], d88table[drv][d88trk[drv]+side]+fdcsect*(256+16)+16);
		res=f_read(&d88fo[drv], (char *)fdcbuf, 256, &r);
		fddat=fdcbuf[0];
		fdcptr=0;
		fdcsts|=2;		// DRQ flag set
	} else if(fdcptr==0xff && fdcmode==8){
		fdint=0;
	}
	fdsts=fdcsts;
}

void wait20ms(void)
{
	volatile int count;
	for(count=0;count<7144;count++);
}

int main(void)
{
	unsigned int p,size,step,sum;
	unsigned char stored,sel1,drv,c;
	char sel2[13], *addr, q;
	FIL fobj;
	FRESULT res;
	WORD r,start;

	FatFs=&fs;
	memset(&fs, 0, sizeof(FATFS));

	// Attribute RAM initialize
	//		for NEW-MONITOR
	page=0x04;
	addr=(char *)0x8002;
	for(p=0;p<1000;p++){
		*(addr)=0x71;
		//*(addr)=0x40;
		addr+=4;
	}

	disk_initialize();
	d88open[0]=0;
	d88open[1]=0;

	//page=0x04;
	//addr=(char *)0x8000;
	//for(p=0;p<16384;p++)
	//	*(addr++)=0;
	page=0x05;
	//addr=(char *)0x8000;
	//for(p=0;p<32768;p++)
	//	*(addr++)=0;
	epcsread(0x45000, 0x1000, (char *)0x8000, 4);	// CG-ROM
	epcsread(0x45000, 0x400, (char *)0xC000, 4);	// CG-ROM
	epcsread(0x45800, 0x400, (char *)0xE000, 4);	// CG-ROM
	page=0x02;
	epcsread(0x46000, 0x1000, (char *)0x8000, 1);	// MONITOR
	page=0x03;
	epcsread(0x47000, 0x1800, (char *)0xE800, 1);	// SUB MONITOR

// page=4
// 8000 D000 23-16
// 8001 D400 31-24
// 8002 D800  7- 0
// 8003 DC00 15- 8
// page=5
// 8000 PCG0  CGROM 23-16
// 8001 PCG1  PCG0  31-24
// 8002 PCG2  PCG1   7- 0
// 8003 CGROM PCG2  15- 8

	sel1=0;
	page=0x80;
	ctrl0=0x80;		// Reset release
	stored=0;
	sei();
	while(1){
		if((ctrl2&0x01)==0x01 && stored==0){
			ctrl0=0xc0;		// Bus request
			while((ctrl0&0x40));
			save();
			cls();
			stored=1;
			switch(hmenu(mmenu)){
				case 1:		// SETUP
					cls();
					switch(hmenu(smenu)){
						case 0:		// ROM
							disp("SELECT ROM AREA",13,5);
							sel1=vmenu((char *)rmenu,29,6);
							clsline(5,24);
							disp((char *)mes_filefor,13,5);
							addr=(char *)(rmenu+sel1);
							disp(addr,6,7);
							if(fmenu(sel2)==99) break;
							disp((char *)mes_update,13,5);
							disp(addr,6,7);
							switch(sel1){
								case 0:
									romupdate(0x6000,0x1000,sel2,0);		//0x46000-0x46FFF
									break;
								case 1:
									romupdate(0x7000,0x1800,sel2,0);		//0x47000-0x487FF
									break;
								case 2:
									romupdate(0x7000,0x800,sel2,0);			//0x47000-0x477FF
									break;
								case 3:
									romupdate(0x7800,0x1000,sel2,0);		//0x47800-0x487FF
									break;
								case 4:
									romupdate(0x5000,0x1000,sel2,0);		//0x45000-0x45FFF
									break;
								case 5:
									romupdate(0x5000,0x1000,sel2,1);		//0x45000-0x45FFF
									break;
								default:
									break;
							}
							break;
						case 1:		// PLDLOAD
							disp((char *)mes_filefor,13,5);
							disp((char *)mes_fpga,16,7);
							if(fmenu(sel2)==99) break;
							disp((char *)mes_update,13,5);
							disp((char *)mes_fpga,16,7);
							pldload(sel2);
							break;
						case 2:		// PLDSAVE
						case 99:
						default:
							restore();
							ctrl0=0x80;		// Bus release
							stored=0;
							break;
					}
					break;
				case 0:		// FILE
					disp("SELECT DEVICE",14,5);
					sel1=vmenu((char *)dmenu,18,5);
					if(sel1==99){
						break;
					} else if(sel1>49){
						memcpy((char *)&dmenu[sel1-50][5], "(NONE )     ", 12);
						if(sel1==52||sel1==53){
							drv=sel1&1;
							if(d88open[drv]==-1) res=f_close(&d88fo[drv]);
							d88open[drv]=0;
						}
						break;
					}
					clsline(5,24);
					disp((char *)mes_filefor,13,5);
					addr=(char *)(dmenu+sel1);
					disp(addr,12,7);
					if(fmenu(sel2)==99) break;
					//clsline(5,24);
					res=f_open(&fobj, sel2, FA_OPEN_EXISTING | FA_READ);
					if(res){
						disp((char *)mes_foerr,12,12);
						//disp(sel2,12,12);
						//disp_err(res);
						while(ctrl1!=0);
						while(ctrl1==0);
						break;
					} else {
						switch(sel1){
							case 1:
							case 2:
							case 3:
							case 4:
								memcpy((char *)&dmenu[sel1][5], sel2, 12);
							default:
								break;
						}
						switch(sel1){
							case 0:		// Direct Load
								res=f_read(&fobj, (char *)0x2000, 128, &r);
								page=0;
								memcpy((char *)0x90f0, (char *)0x2000, 32);
								*(char *)(0x9105)=0xc3;
								start=*(WORD *)(0x2014);
								size=*(WORD *)(0x2012);
								if(start<0x8000){
									page=0;
									if(start+size<0x8001){
										res=f_read(&fobj, (char *)(start+0x8000), (WORD)size, &r);
									} else {
										res=f_read(&fobj, (char *)(start+0x8000), (WORD)(0x8000-start), &r);
										page=1;
										res=f_read(&fobj, (char *)(0x8000), (WORD)(size-(0x8000-start)), &r);
									}
								} else {	// start >= 0x8000
									page=1;
									res=f_read(&fobj, (char *)start, (WORD)size, &r);
								}
								res=f_close(&fobj);
								break;
							case 2:		// FDD1
							case 3:		// FDD2
								drv=sel1&1;
								if(d88open[drv]==-1) res=f_close(&d88fo[drv]);
								res=f_lseek(&fobj, (DWORD)0x001a);
								res=f_read(&fobj, &d88wp[drv], 1, &r);			// write protect
								res=f_lseek(&fobj, (DWORD)0x0020);
								res=f_read(&fobj, &d88table[drv], 4*164, &r);	// track table
								//memcpy((char *)&dmenu[sel1][5], sel2, 12);
								res=f_close(&fobj);
								res=f_open(&d88fo[drv], sel2, FA_OPEN_EXISTING | FA_READ);
								d88open[drv]=-1;
								break;
							case 4:		// QD
								//memcpy((char *)&dmenu[sel1][5], sel2, 12);
							case 1:		// CMT
								res=f_close(&fobj);
							case 99:
							default:
								break;
						}
						while(ctrl1!=0);
						break;
					}
				case 2:		// EXIT
				case 99:
				default:
					break;
			}
			restore();
			ctrl0=0x80;		// Bus release
			stored=0;
		} else if((ctrl2&0x04)==0x04 && stored==0){
			res=f_open(&fobj, (char *)&dmenu[1][5], FA_OPEN_EXISTING | FA_READ);
			if(res==FR_OK){
				prst=1;		// Motor ON
				while(1){
					res=f_read(&fobj, (char *)0x7800, 128, &r);
					if(r==0) break;
					if(z11000()<0) break;
					if(z11000()<0) break;
					if(o20()<0) break;
					if(o20()<0) break;
					if(z20()<0) break;
					if(z20()<0) break;
					if(pulseout(0x80,1)<0) break;
					addr=(char *)0x7800;
					sum=0;
					for(p=0;p<128;p++){
						if(pulseout(0x80,1)<0) goto RTAPEE;
						c=*(addr++);
						q=pulseout(c,8);
						if(q<0) goto RTAPEE;
						sum+=q;
					}
					if(sumout(sum)<0) break;
					if(z11000()<0) break;
					if(o20()<0) break;
					if(z20()<0) break;
					if(pulseout(0x80,1)<0) break;
					sum=0;
					size=*(WORD *)(0x7812);
					while(1){
						if(size<128) step=size; else step=128;
						res=f_read(&fobj, (char *)0x7800, step, &r);
						addr=(char *)0x7800;
						for(p=0;p<r;p++){
							if(pulseout(0x80,1)<0) goto RTAPEE;
							c=*(addr++);
							q=pulseout(c,8);
							if(q<0) goto RTAPEE;
							sum+=q;
						}
						if(size>128) size-=128; else break;
					}
					if(sumout(sum)<0) break;
				}
			}
		RTAPEE:
			res=f_close(&fobj);
			prst=0;		// Motor OFF
		}
//		if((ctrl2&0x02)==0x02 && stored==1){
//			restore();
//			ctrl0=0x80;		// Bus release
//			stored=0;
//		}
	}

}

int pulseout(unsigned char c, int num)
{
	int sum=0;

	while(num>0){
		do{
			if((ctrl2&0x08)==0x08) return -1;
		}while(bbusy);
		pout=c;
		if(c&0x80) sum++;
		c=c<<1;
		num--;
	}

	return sum;
}

int z11000(void)
{
	int p;

	for(p=0;p<1375;p++)	// 11000bit
		if(pulseout(0,8)<0) return -1;
	return 0;
}

int z20(void)
{
	int p;

	for(p=0;p<4;p++)	// 20bit
		if(pulseout(0,5)<0) return -1;
	return 0;
}

int o20(void)
{
	int p;

	for(p=0;p<4;p++)	// 20bit
		if(pulseout(0xff,5)<0) return -1;
	return 0;
}

int sumout(unsigned int sum)
{
	if(pulseout(0x80,1)<0) return -1;
	if(pulseout((sum>>8)&0xff,8)<0) return -1;
	if(pulseout(0x80,1)<0) return -1;
	if(pulseout(sum&0xff,8)<0) return -1;
	if(pulseout(0x80,1)<0) return -1;
	return 0;
}

void cls(void)
{
	unsigned char * addr;
	unsigned int p;

	page=0x04;
	addr=(unsigned char *)0x8000;
	for(p=0;p<1000;p++){
		*(addr)=0;
		addr+=4;
	}

	addr=(unsigned char *)0x8002;
	for(p=0;p<1000;p++){
		*(addr)=0x70;
		addr+=4;
	}
}

void clsline(unsigned char begin, unsigned char end)
{
	unsigned char * addr;
	unsigned int p,q;

	page=0x04;
	q=low[end]-low[begin]+40;
	addr=(unsigned char *)low[begin];
	for(p=0;p<q;p++){
		*(addr)=0;
		addr+=4;
	}

	addr=(unsigned char *)(low[begin]+2);
	for(p=0;p<q;p++){
		*(addr)=0x70;
		addr+=4;
	}
}

void disp(char * text, unsigned char x, unsigned char y)
{
	unsigned char * addr, i, p;

	if(y>24 || x>39) return;
	addr=(unsigned char *)(low[y]+(x<<2));

	page=0x04;
	while(*text!=0){
		p=*(text++);
		if( p<0x20 ){
			for(i=0;i<p;i++){
				*(addr)=0;
				addr+=4;
			}
		} else {
			*(addr)=dcode[p-0x20];
			addr+=4;
		}
		if(addr==(unsigned char *)0x8fa1) break;
	}
}

void save(void)
{
	unsigned char * vram;
	unsigned char * buff;
	unsigned int p;

	page=0x04;
	vram=(unsigned char *)0x8000;
	buff=(unsigned char *)0x7800;
	for(p=0;p<1024;p++){
		*(buff++)=*(vram);
		vram+=4;
	}

	vram=(unsigned char *)0x8002;
	buff=(unsigned char *)0x7c00;
	for(p=0;p<1024;p++){
		*(buff++)=*(vram);
		vram+=4;
	}
}

void restore(void)
{
	unsigned char * vram;
	unsigned char * buff;
	unsigned int p;

	page=0x04;
	vram=(unsigned char *)0x8000;
	buff=(unsigned char *)0x7800;
	for(p=0;p<1024;p++){
		*(vram)=*(buff++);
		vram+=4;
	}

	vram=(unsigned char *)0x8002;
	buff=(unsigned char *)0x7c00;
	for(p=0;p<1024;p++){
		*(vram)=*(buff++);
		vram+=4;
	}
}

void epcsread(DWORD addr, WORD size, char *mem, char step)
{
	WORD p;
	unsigned char c;
//	unsigned char * addr;

//	page=0x02;

	// CS=L
	epccs=0;

	epcs=0x03;	//Read bytes command
	epcs=addr >> 16;
	epcs=addr >> 8;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=addr;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=0;	// dummy
	c=epcs;		// dummy
//	addr=(unsigned char *)0x8000;
	for(p=0;p<size;p++){
		*(mem)=epcs;
		mem+=step;
	}

	// CS=H
	epccs=1;
}

unsigned char hmenu(const char *menu)
{
	char * addr;
	unsigned char p,q;

	page=0x04;

	addr=(char *)0x8004;
	for(p=0;p<38;p++){
		*addr=0x70;
		*(addr+0x140)=0x3c;
		addr+=4;
	}
	*(char *)(0x8000)=0x72;
	*(char *)(0x809c)=0x73;
	*(char *)(0x80a0)=0x71;
	*(char *)(0x813c)=0x3d;
	*(char *)(0x8140)=0x32;
	*(char *)(0x81dc)=0x33;
	disp((char *)menu,1,1);

	p=0;
	q=0;
	rev((char *)0x80a6,12);
	while(1){
		if(q==1){
			if(ctrl1!=0)
				continue;
			else
				q=0;
		}

		addr=(char *)(0x80a6+p*13*4);
		if((ctrl1&0x04)==0x04 && p!=2){			// RIGHT
			nom(addr,12);
			p++;
			rev(addr+13*4,12);
			q=1;
		} else if((ctrl1&0x08)==0x08 && p!=0){	// LEFT
			nom(addr,12);
			p--;
			rev(addr-13*4,12);
			q=1;
		} else if((ctrl1&0x02)==0x02){		// CR
			break;
		} else if((ctrl2&0x02)==0x02){		// ALT+X
			p=99;
			break;
		}
	}

	while(ctrl1!=0);
	return p;
}

void rev(char * aram, unsigned char len)
{
	unsigned char p;

	for(p=0;p<len;p++){
		*(aram)=0x07;
		aram+=4;
	}
//	cbup=*(aram+len*4-6);
//	*(aram+len*4-6)=0x45;
}

void nom(char * aram, unsigned char len)
{
	unsigned char p;

	for(p=0;p<len;p++){
		*(aram)=0x70;
		aram+=4;
	}
//	*(aram+len*4-6)=cbup;
}

unsigned char vmenu(const char *menu, unsigned char len, unsigned char item)
{
	unsigned char p,q;
	char *addr;

	page=0x04;

	q=20-(len>>1);
	for(p=0;p<item;p++)//{
		disp((char *)(menu+p*len),q,10+p);
//		hex_WORD((WORD)menu[p],0,10+p);}

	p=0;
	q=0;
	rev((char *)0x8642,40);
	while(1){
		if(q==1){
			if(ctrl1!=0)
				continue;
			else
				q=0;
		}

		addr=(char *)(0x8642+p*40*4);
		if((ctrl1&0x10)==0x10 && p!=item-1){	// DOWN
			nom(addr,40);
			p++;
			rev(addr+40*4,40);
			q=1;
		} else if((ctrl1&0x20)==0x20 && p!=0){	// UP
			nom(addr,40);
			p--;
			rev(addr-40*4,40);
			q=1;
		} else if((ctrl1&0x02)==0x02){		// CR
			break;
		} else if((ctrl1&0x01)==0x01){		// SPACE
			p+=50;
			break;
		} else if((ctrl2&0x02)==0x02){		// ALT+X
			p=99;
			break;
		}
	}

	while(ctrl1!=0);
	return p;
}

unsigned int fmenu(char *fname)
{
	unsigned char p,q;
	char *buff,*addr;
	int sel,top,total;
	FRESULT f;

	total=0;
	f=f_opendir(&dirs, "/");
	//disp_s_dir(&dirs);
	buff=(char *)0x6000;
	switch(f){
		case FR_OK:
			total=0;
			while((f_readdir(&dirs, &finfo) == FR_OK) && finfo.fname[0]){
				//disp_s_dir(&dirs);
				if(!(finfo.fattrib & AM_DIR)){
					//disp_s_filinfo(&finfo);
					memcpy(buff, finfo.fname, 13);
					buff+=13;
					*buff='\0';
					total++;
				}
			}
		case FR_NO_FILE:
			if(total==0) disp("FILE NOT FOUND.",13,10);
			break;
		case FR_NOT_READY:
			disp("DRIVE NOT READY.",12,10);
			break;
		case FR_RW_ERROR:
			disp("READ ERROR.",15,10);
			break;
		default:
			disp("ERROR.",17,10);
			break;
	}

	if(f==FR_OK&&total!=0){
		q=0;
		sel=0;
		top=0;
		flist(0);
		rev((char *)0x8642,12);
		addr=(char *)0x8642;
		//hex_WORD((WORD)addr,0,3);
		while(1){
			if(q==1){
				if(ctrl1!=0)
					continue;
				else
					q=0;
			}

			if((ctrl1&0x04)==0x04 && sel+top+15<total){			// RIGHT
				nom(addr,12);
				if(sel>29){
					sel-=30;
					addr-=26*4;
					top+=45;
					flist(top);
				} else {
					sel+=15;
					addr+=13*4;
				}
				rev(addr,12);
				q=1;
			} else if((ctrl1&0x08)==0x08 && sel+top-15>=0){	// LEFT
				nom(addr,12);
				if(sel<15){
					sel+=30;
					addr+=26*4;
					top-=45;
					flist(top);
				} else {
					sel-=15;
					addr-=13*4;
				}
				rev(addr,12);
				q=1;
			} else if((ctrl1&0x10)==0x10 && sel+top+1<total){	// DOWN
				nom(addr,12);
				switch(sel){
					case 14:
					case 29:
						sel++;
						addr-=547*4;
						break;
					case 44:
						sel=0;
						addr=(char *)0x8642;
						top+=45;
						flist(top);
						break;
					default:
						sel++;
						addr+=40*4;
						break;
				}
				rev(addr,12);
				q=1;
				//hex_WORD((WORD)addr,0,3);
			} else if((ctrl1&0x20)==0x20 && sel+top>0){	// UP
				nom(addr,12);
				switch(sel){
					case 15:
					case 30:
						sel--;
						addr+=547*4;
						break;
					case 0:
						sel=44;
						addr=(char *)0x8f6a;
						top-=45;
						flist(top);
						break;
					default:
						sel--;
						addr-=40*4;
						break;
				}
				rev(addr,12);
				q=1;
				//hex_WORD((WORD)addr,0,3);
			} else if((ctrl1&0x02)==0x02){		// CR
				clsline(5,24);
				memcpy(fname, (char *)(0x6000+(sel+top)*13), 13);
				p=0;
				break;
			} else if((ctrl2&0x02)==0x02){		// ALT+X
				p=99;
				break;
			}
		}
		
		return p;
 	} else {
		while((ctrl2&0x02)!=0x02);		// ALT+X
		return 99;
	}
}

void flist(unsigned int num)
{
	unsigned char x, y;
	char *buff=(char *)0x6000;

	buff+=num*13;
	clsline(10,24);
	for(x=0;x<39;x+=13)
		for(y=10;y<25;y++)
			if(*buff!='\0'){
				disp(buff,x,y);
				buff+=13;
			}
}

void epcswrite(DWORD addr, char *buff, char revsw)
{
	WORD p;

	epcscmd(0x06);	// Write enable command

	epccs=0;	// CS=L
	epcs=0x02;	// Write bytes command
	epcs=addr >> 16;
	epcs=addr >> 8;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0;		// address last byte(0xxxx00)
	for(p=0;p<256;p++){
		if(revsw) epcs_rev=*(buff++); else epcs=*(buff++);
	}
	epccs=0;	// dummy
	epccs=1;	// CS=H

	epcsbusy();
}

void epcsbusy(void)
{
	char c;

	epccs=0;	// CS=L
	epcs=0x05;	// Read status command
	epccs=0;	// dummy
	epccs=0;	// dummy
	c=epcs;		// dummy
	epccs=0;	// dummy
	c=epcs;		// dummy
	while(epcs&0x01);
	epccs=1;	// CS=H
}

void epcscmd(unsigned char cmd)
{
	epccs=0;	// CS=L
	epcs=cmd;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=1;	// CS=H
}

void romupdate(DWORD addr, DWORD size, char *fname, char revsw)
{
	FIL fobj;
	FRESULT res;
	WORD loop,rbyte,pg;
	char *buff,rev;

	progress(70);
	page=0x7e;
	epcsread(0x40000, 0x8000, (char *)0x8000, 1);
	progress(69);
	page=0x7f;
	epcsread(0x48000, 0x8000, (char *)0x8000, 1);
	progress(68);

	res=f_open(&fobj, fname, FA_OPEN_EXISTING | FA_READ);
	if(res){
		disp((char *)mes_foerr,12,12);
		return;
	} else {
		page=0x7e;
		buff=(char *)0x8000+addr;
		res=f_read(&fobj, buff, size, &rbyte);
		progress(67);
	}
	res=f_close(&fobj);

	epcscmd(0x06);	// Write enable command
	progress(66);

	epccs=0;	// CS=L
	epcs=0xd8;	// Erase sector command
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0x04;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=0;	// dummy
	epccs=1;	// CS=H
	progress(65);

	epcsbusy();
	progress(64);

	pg=256;
	buff=(char *)0x8000;
	for(loop=0;loop<32768;loop+=256){
		page=0x7e;
		if(loop>=0x5000 && loop<0x6000) rev=revsw; else rev=0;
		epcswrite(loop+0x40000, buff, rev);
		buff+=256;
		progress(pg>>2);
		pg--;
	}
	buff=(char *)0x8000;
	for(loop=0;loop<32768;loop+=256){
		page=0x7f;
		epcswrite(loop+0x48000, buff, 0);
		buff+=256;
		progress(pg>>2);
		pg--;
	}

	epcscmd(0x04);	// Write disable command

}

void pldload(char *fname)
{
	FIL fobj;
	FRESULT res;
	WORD r,pg;
	DWORD loop;

	res=f_open(&fobj, fname, FA_OPEN_EXISTING | FA_READ);
	if(res){
		disp((char *)mes_foerr,12,12);
		return;
	} else {
		epcscmd(0x06);	// Write enable command
		progress(66);

		epcscmd(0xc7);	// Erase bulk command
		progress(65);

		epcsbusy();
		progress(64);

		pg=2048;
		for(loop=0;loop<0x80000;loop+=256){
			res=f_read(&fobj, (char *)0x2000, 256, &r);
			epcswrite(loop, (char *)0x2000, 1);
			progress(pg>>5);
			pg--;
		}

		epcscmd(0x04);	// Write disable command
	}
	res=f_close(&fobj);
}

void progress(unsigned char percent)
{
	char *addr;
	unsigned int p10;

	if(percent==100){
		p10=0x100;
	} else {
		p10=percent+bcdt[percent>>4];		// convert to BCD
		if((p10 & 0x0f)>9) p10+=6;
	}
	addr=mes_waiting;
	*(addr+9)=(p10&0x0f)+0x30;
	*(addr+8)=((p10&0xf0)>>4)+0x30;
	*(addr+7)=((p10&0x100)>>8)+0x30;
	if(*(addr+7)=='0'){
		*(addr+7)='.';
		if(*(addr+8)=='0')
			*(addr+8)='.';
	}

	disp(mes_waiting,15,12);
}
/*
void hex_BYTE(BYTE num, unsigned char x, unsigned char y)
{
	unsigned char c, * addr;

	addr=(unsigned char *)(low[y]+x);
	c=((num >> 4) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=(num & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*addr=c;
}
*/
/*
void hex_WORD(WORD num, unsigned char x, unsigned char y)
{
	unsigned char c, * addr;

	addr=(unsigned char *)(low[y]+x);
	c=((num >> 12) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 8) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 4) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=(num & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*addr=c;
}
*/
/*
void hex_DWORD(DWORD num, unsigned char x, unsigned char y)
{
	unsigned char c, * addr;

	addr=(unsigned char *)(low[y]+x);
	c=((num >> 28) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 24) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 20) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 16) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 12) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 8) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=((num >> 4) & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*(addr++)=c;
	c=(num & 0x0f)+0x20;
	if(c>0x29) c-=0x29;
	*addr=c;
}

void disp_s_dir(DIR *dir)
{
	clsline(10,24);
	disp("SCLUST:",10,12); hex_WORD(dir->sclust,17,12);
	disp("CLUST :",10,13); hex_WORD(dir->clust,17,13);
	disp("SECT  :",10,14); hex_DWORD(dir->sect,17,14);
	disp("INDEX :",10,15); hex_WORD(dir->index,17,15);

	while(ctrl2!=0);
	while((ctrl2&0x02)!=0x02);		// ALT+X
}

void disp_s_filinfo(FILINFO *finfo)
{
	char i;
	clsline(10,24);
	disp("FSIZE  :",5,12); hex_DWORD(finfo->fsize,13,12);
	disp("FDATE  :",5,13); hex_WORD(finfo->fdate,13,13);
	disp("FTIME  :",5,14); hex_WORD(finfo->ftime,13,14);
	disp("FATTRIB:",5,15); hex_BYTE(finfo->fattrib,13,15);
	disp("FNAME  :",5,16); for(i=0;i<13;i++) hex_BYTE(finfo->fname[i],13+i*2,16);

	while(ctrl2!=0);
	while((ctrl2&0x02)!=0x02);		// ALT+X
}
*/
/*
void disp_err(FRESULT res)
{
	switch(res){
		case FR_NO_FILE:
			disp("FR_NO_FILE",12,12);
			break;
		case FR_NO_PATH:
			disp("FR_NO_PATH",12,12);
			break;
		case FR_INVALID_NAME:
			disp("FR_INVALID_NAME",12,12);
			break;
		case FR_DENIED:
			disp("FR_DENIED",12,12);
			break;
		case FR_NOT_READY:
			disp("FR_NOT_READY",12,12);
			break;
		case FR_WRITE_PROTECTED:
			disp("FR_WRITE_PROTECTED",12,12);
			break;
		case FR_RW_ERROR:
			disp("FR_RW_ERROR",12,12);
			break;
		case FR_INCORRECT_DISK_CHANGE:
			disp("FR_INCORRECT_DISK_CHANGE",12,12);
			break;
		case FR_NOT_ENABLED:
			disp("FR_NOT_ENABLED",12,12);
			break;
		case FR_NO_FILESYSTEM:
			disp("FR_NO_FILESYSTEM",12,12);
			break;
		default:
			disp("FR_OK",12,12);
			break;
	}
}
*/
