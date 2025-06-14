#include <avr/io.h>

#include	"diskio.h"
#include	"integer.h"

#define ctrl0	 _SFR_IO8(0x00)
#define ctrl1	 _SFR_IO8(0x01)
#define ctrl2	 _SFR_IO8(0x02)
#define epccs	 _SFR_IO8(0x05)
#define epcs	 _SFR_IO8(0x06)
#define epcs_rev _SFR_IO8(0x07)
#define page	 _SFR_IO8(0x08)
#define mmccs	 _SFR_IO8(0x09)
#define mmc		 _SFR_IO8(0x0a)

DSTATUS status;

void mmc_cmd(unsigned char cmd, DWORD addr)
{
	unsigned char c;

	mmc=0x40+cmd;
	mmc=addr >> 24;
	mmc=addr >> 16;
	mmc=addr >> 8;
	mmccs=0; // dummy
	mmccs=0; // dummy
	mmccs=0; // dummy
	mmc=addr;
	mmccs=0; // dummy
	mmccs=0; // dummy
	mmccs=0; // dummy
	mmc=0x95;
	mmccs=0; // dummy
	mmccs=0; // dummy
	mmccs=0; // dummy

	c=mmc;	// dummy read
	mmccs=0; // dummy
	mmccs=0; // dummy
}

DSTATUS disk_initialize(void)
{
	unsigned char c=0xff;
	unsigned int i;

	// CS=H
	mmccs=1;

	// dummy clock
	for(i=0;i<15;i++)
		mmc=0xff;

	// CS=L
	mmccs=0;

	// CMD0
	mmc_cmd(0,0);

	// wait idle state
	for(i=0;i<16;i++){
		c=mmc;
		mmccs=0; // dummy
		if(c!=0xff) break;
	}
	if(i==16){
		// CS=H
		mmccs=1;
		status=STA_NOINIT+STA_NODISK;
		return status;
	}
	while(c!=0x01){
		c=mmc;
		mmccs=0; // dummy
	}

	// check idle state
	do{
		// ACMD41
//		mmc_cmd(55,0);
		// wait busy
//		c=0xff;
//		while(c==0xff)
//			c=mmc;

//		mmc_cmd(41,0);
		mmc_cmd(1,0);
		// wait busy
		c=0xff;
		while(c==0xff){
			c=mmc;
			mmccs=0; // dummy
		}

	}while(c!=0x00);

	// CS=H
	mmccs=1;

	status=0;
	return 0;

}

DSTATUS disk_status(void)
{
	return status;
}

DRESULT disk_read(
  BYTE* Buffer,        // 読み出しバッファへのポインタ
  DWORD SectorNumber,  // 読み出し開始セクタ番号
  BYTE SectorCount     // 読み出しセクタ数
)
{
	BYTE i,c;
	WORD cnt;

	if(status!=0) return RES_NOTRDY;

	// CS=L
	mmccs=0;

	for(i=0;i<SectorCount;i++){
		mmc_cmd(17, SectorNumber<<9);
		SectorNumber++;
		// wait busy
		c=0xff;
		while(c==0xff){
			c=mmc;
			mmccs=0; // dummy
		}
		if(c!=0x00) return RES_ERROR;

		// wait token
		c=0xff;
		while(c==0xff){
			c=mmc;
			mmccs=0; // dummy
		}
		if(c<0x80) return RES_ERROR;
		for(cnt=0;cnt<512;cnt++)
			*(Buffer++)=mmc;

		c=mmc;
		mmccs=0; // dummy
		mmccs=0; // dummy
		c=mmc;	// CRC
	}

	// CS=H
	mmccs=1;

	return RES_OK;
}


DRESULT disk_write(
  const BYTE* Buffer,  // 書き込むデータへのポインタ
  DWORD SectorNumber,  // 書き込み開始セクタ番号
  BYTE SectorCount     // 書き込みセクタ数
)
{
	BYTE i,c;
	WORD cnt;

	if(status!=0) return RES_NOTRDY;

	// CS=L
	mmccs=0;

	for(i=0;i<SectorCount;i++){
		mmc_cmd(24, SectorNumber<<9);
		SectorNumber++;
		// wait busy
		c=0xff;
		while(c==0xff){
			c=mmc;
			mmccs=0; // dummy
		}
		if(c!=0x00) return RES_ERROR;

		// wait and send token
		mmc=0xff;
		mmccs=0; // dummy
		mmccs=0; // dummy
		mmc=0xfe;

		for(cnt=0;cnt<512;cnt++)
			mmc=*(Buffer++);

		mmc=0xff;
		c=mmc;		// mmc=0xff; // CRC
		while(c!=0xff){
			if((c&0x1f)==0x0c) return RES_ERROR;
			 c=mmc;
		}
	}

	// CS=H
	mmccs=1;

	return RES_OK;
}

DWORD get_fattime(void)
{
	return 0x36210000;	// 2007/1/1 0:00:00
}
