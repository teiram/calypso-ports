#define ctrl0	 _SFR_IO8(0x00)
#define ctrl1	 _SFR_IO8(0x01)
#define ctrl2	 _SFR_IO8(0x02)
#define epccs	 _SFR_IO8(0x05)
#define epcs	 _SFR_IO8(0x06)
#define epcs_rev _SFR_IO8(0x07)
#define page	 _SFR_IO8(0x08)
#define mmccs	 _SFR_IO8(0x09)
#define mmc		 _SFR_IO8(0x0a)
#define prst	 _SFR_IO8(0x0e)
#define bbusy	 _SFR_IO8(0x0f)
#define pout	 _SFR_IO8(0x0f)
#define fdcmd	 _SFR_IO8(0x10)
#define fdsts	 _SFR_IO8(0x10)
#define fdtrk	 _SFR_IO8(0x11)
#define fdsect	 _SFR_IO8(0x12)
#define fdetc	 _SFR_IO8(0x13)
#define fddat	 _SFR_IO8(0x14)
#define fdint	 _SFR_IO8(0x15)

const unsigned char dcode[]={ 0x00, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
							  0x68, 0x69, 0x6b, 0x6a, 0x2f, 0x2a, 0x2e, 0x2d,
							  0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
							  0x28, 0x29, 0x4f, 0x2c, 0x51, 0x2b, 0x57, 0x49,
							  0x55, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
							  0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
							  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
							  0x18, 0x19, 0x1a, 0x52, 0x59, 0x54, 0xce, 0x3c };

const unsigned int low[]={ 0x8000, 0x80a0, 0x8140, 0x81e0, 0x8280, 0x8320,
						   0x83c0, 0x8460, 0x8500, 0x85a0, 0x8640, 0x86e0,
						   0x8780, 0x8820, 0x88c0, 0x8960, 0x8a00, 0x8aa0,
						   0x8b40, 0x8be0, 0x8c80, 0x8d20, 0x8dc0, 0x8e60,
						   0x8f00										  };

const char mmenu[]="\004FILE\010SETUP\011EXIT";
const char smenu[]="\004ROM\010PLDLOAD\006PLDSAVE";
const char rmenu[6][29]={ "MONITOR ROM      (0000-0FFF)",
						  "SUB MONITOR ROM  (E800-FFFF)",
						  "QD BOOT/MON. ROM (E800-EFFF)",
						  "FD BOOT ROM      (F000-FFFF)",
						  "CG ROM",
						  "CG ROM (REVERSE)"				};
const char dmenu[5][18]={ "   DIRECT LOAD",
						  "$CMT:(NONE)      ",
						  "$FD1:(NONE)      ",
						  "$FD2:(NONE)      ",
						  "$QD :(NONE)      "	};
const char mes_filefor[]="SELECT FILE FOR";
const char mes_foerr[]="FILE OPEN ERROR.";
char mes_waiting[]="WAIT......";
const char mes_fpga[]="FPGA DATA";
const char mes_update[]=" NOW UPDATING  ";

const unsigned char bcdt[]={ 0x00, 0x06, 0x12, 0x18, 0x24, 0x30, 0x36 };

FATFS fs;
DIR dirs;
FILINFO finfo;

DWORD d88table[2][164];
unsigned char d88wp[2];			// write protect
unsigned char d88trk[2];		// track position
FIL d88fo[2];
char d88open[2];				// open flag(opened=-1)
unsigned char fdcsts, fdcbuf[256], fdcptr, fdcmode, fdcsect;
char fdcstep;
unsigned char cbup;

void wait20ms(void);
int pulseout(unsigned char, int);
int z11000(void);
int z20(void);
int o20(void);
int sumout(unsigned int);
void cls(void);
void clsline(unsigned char, unsigned char);
void disp(char *, unsigned char, unsigned char);
void save(void);
void restore(void);
void xfer_mon(void);
void xfer_submon(void);
void epcsread(DWORD, WORD, char *, char);
unsigned char hmenu(const char *);
void rev(char *, unsigned char);
void nom(char *, unsigned char);
unsigned char vmenu(const char *menu, unsigned char, unsigned char);
unsigned int fmenu(char *);
void flist(unsigned int);
void epcswrite(DWORD, char *, char);
void epcsbusy(void);
void epcscmd(unsigned char);
void romupdate(DWORD, DWORD, char *, char);
void pldload(char *);
void progress(unsigned char);
void hex_BYTE(BYTE, unsigned char, unsigned char);
void hex_WORD(WORD, unsigned char, unsigned char);
void hex_DWORD(DWORD, unsigned char, unsigned char);
void disp_s_dir(DIR *);
void disp_s_filinfo(FILINFO *);
void disp_err(FRESULT);
