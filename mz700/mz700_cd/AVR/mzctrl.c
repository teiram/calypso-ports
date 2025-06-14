#include <avr/io.h> 

#define ctrl0	 _SFR_IO8(0x00)
#define ctrl1	 _SFR_IO8(0x01)
#define ctrl2	 _SFR_IO8(0x02)
#define epccs	 _SFR_IO8(0x05)
#define epcs	 _SFR_IO8(0x06)
#define epcs_rev _SFR_IO8(0x07)
#define page	 _SFR_IO8(0x08)

int main(void)
{
	unsigned int p;
	unsigned char c;
	unsigned char * prog; 

	// CS=L
	epccs=0;

	epcs=0x03;	//Read bytes command
	epccs=0;	// dummy
	epcs=0x04;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0x00;
	epccs=0;	// dummy
	epccs=0;	// dummy
	epcs=0x00;
	epccs=0;	// dummy
	epccs=0;	// dummy
	c=epcs;		// dummy
	prog=(unsigned char *)0x8000;
	for(p=0;p<0x4000;p++)
		*(prog++)=epcs;

	// CS=H
	epccs=1;

	// Memory change and restart
	ctrl0=0;

	while(1);

}
