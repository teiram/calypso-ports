; z80dasm 1.1.6
; command line: z80dasm -g0 -alt ROM1.bin

	org	00000h

l0000h:
	di			;0000	f3 	. 
	sub a			;0001	97 	. 
	jp l03dah		;0002	c3 da 03 	. . . 
sub_0005h:
	rst 18h			;0005	df 	. 
	inc l			;0006	2c 	, 
	inc l			;0007	2c 	, 
	call sub_0ab2h		;0008	cd b2 0a 	. . . 
	jp l0a6dh		;000b	c3 6d 0a 	. m . 
	di			;000e	f3 	. 
	ret			;000f	c9 	. 
l0010h:
	ld a,h			;0010	7c 	| 
	cp d			;0011	ba 	. 
	ret nz			;0012	c0 	. 
	ld a,l			;0013	7d 	} 
	cp e			;0014	bb 	. 
	ret			;0015	c9 	. 
	ei			;0016	fb 	. 
	ret			;0017	c9 	. 
l0018h:
	ex (sp),hl			;0018	e3 	. 
	call sub_0105h		;0019	cd 05 01 	. . . 
	cp (hl)			;001c	be 	. 
	jp l0194h		;001d	c3 94 01 	. . . 
l0020h:
	exx			;0020	d9 	. 
	cp 020h		;0021	fe 20 	.   
	call sub_09b5h		;0023	cd b5 09 	. . . 
	exx			;0026	d9 	. 
	ret			;0027	c9 	. 
	ld hl,l0000h		;0028	21 00 00 	! . . 
	ret			;002b	c9 	. 
l002ch:
	call z,0cccch		;002c	cc cc cc 	. . . 
	ld a,(hl)			;002f	7e 	~ 
	pop af			;0030	f1 	. 
	call sub_0414h		;0031	cd 14 04 	. . . 
	jp 0078fh		;0034	c3 8f 07 	. . . 
	inc e			;0037	1c 	. 
	push af			;0038	f5 	. 
	push bc			;0039	c5 	. 
	push de			;003a	d5 	. 
	push hl			;003b	e5 	. 
	ld hl,02bb0h		;003c	21 b0 2b 	! . + 
	ld a,0c0h		;003f	3e c0 	> . 
	sub (hl)			;0041	96 	. 
	sub (hl)			;0042	96 	. 
	sub (hl)			;0043	96 	. 
	ld e,a			;0044	5f 	_ 
	ld a,(hl)			;0045	7e 	~ 
	rrca			;0046	0f 	. 
	rrca			;0047	0f 	. 
	rrca			;0048	0f 	. 
	ld b,a			;0049	47 	G 
	or a			;004a	b7 	. 
	jr z,l004dh		;004b	28 00 	( . 
l004dh:
	jr z,l0054h		;004d	28 05 	( . 
	dec (hl)			;004f	35 	5 
	xor a			;0050	af 	. 
l0051h:
	ret c			;0051	d8 	. 
	djnz l0051h		;0052	10 fd 	. . 
l0054h:
	inc hl			;0054	23 	# 
	ld (hl),a			;0055	77 	w 
	ld b,e			;0056	43 	C 
	ld hl,0207fh		;0057	21 7f 20 	!    
	ld c,l			;005a	4d 	M 
	ld a,(02ba8h)		;005b	3a a8 2b 	: . + 
	rra			;005e	1f 	. 
	jr c,l0061h		;005f	38 00 	8 . 
l0061h:
	dec a			;0061	3d 	= 
	jr nz,l0061h		;0062	20 fd 	  . 
	jr l006dh		;0064	18 07 	. . 
	di			;0066	f3 	. 
l0067h:
	ld sp,02ba8h		;0067	31 a8 2b 	1 . + 
	jp l0317h		;006a	c3 17 03 	. . . 
l006dh:
	inc c			;006d	0c 	. 
	ld a,c			;006e	79 	y 
	and 008h		;006f	e6 08 	. . 
	rrca			;0071	0f 	. 
	rrca			;0072	0f 	. 
	rrca			;0073	0f 	. 
	or 028h		;0074	f6 28 	. ( 
	ld i,a		;0076	ed 47 	. G 
	inc de			;0078	13 	. 
	ld de,l080ch		;0079	11 0c 08 	. . . 
	ld a,c			;007c	79 	y 
	rrca			;007d	0f 	. 
	rrca			;007e	0f 	. 
	rrca			;007f	0f 	. 
	ccf			;0080	3f 	? 
	rr d		;0081	cb 1a 	. . 
	or 01fh		;0083	f6 1f 	. . 
	rlca			;0085	07 	. 
	sub 040h		;0086	d6 40 	. @ 
	rrca			;0088	0f 	. 
	ld r,a		;0089	ed 4f 	. O 
l008bh:
	ld (hl),d			;008b	72 	r 
	inc d			;008c	14 	. 
	inc d			;008d	14 	. 
	inc d			;008e	14 	. 
	inc d			;008f	14 	. 
	xor a			;0090	af 	. 
	scf			;0091	37 	7 
	rra			;0092	1f 	. 
	rra			;0093	1f 	. 
	xor d			;0094	aa 	. 
	ld d,a			;0095	57 	W 
	ld h,c			;0096	61 	a 
	ld a,b			;0097	78 	x 
l0098h:
	ld b,d			;0098	42 	B 
	ld d,d			;0099	52 	R 
	ld b,l			;009a	45 	E 
	ld b,c			;009b	41 	A 
	ld c,e			;009c	4b 	K 
	nop			;009d	00 	. 
	ld b,a			;009e	47 	G 
	ld c,h			;009f	4c 	L 
l00a0h:
	nop			;00a0	00 	. 
	nop			;00a1	00 	. 
	add a,b			;00a2	80 	. 
	nop			;00a3	00 	. 
	xor a			;00a4	af 	. 
	scf			;00a5	37 	7 
	rra			;00a6	1f 	. 
	rra			;00a7	1f 	. 
	rra			;00a8	1f 	. 
	ld h,a			;00a9	67 	g 
	rla			;00aa	17 	. 
	ld (hl),a			;00ab	77 	w 
	dec b			;00ac	05 	. 
	jr z,l00beh		;00ad	28 0f 	( . 
	ld a,r		;00af	ed 5f 	. _ 
	sub 027h		;00b1	d6 27 	. ' 
	and l			;00b3	a5 	. 
	ld r,a		;00b4	ed 4f 	. O 
	dec e			;00b6	1d 	. 
	jp nz,l008bh		;00b7	c2 8b 00 	. . . 
	ld a,003h		;00ba	3e 03 	> . 
	jr l0061h		;00bc	18 a3 	. . 
l00beh:
	ld (hl),0bch		;00be	36 bc 	6 . 
	ld a,(02a82h)		;00c0	3a 82 2a 	: . * 
	cp 03ah		;00c3	fe 3a 	. : 
	jr nz,l00fbh		;00c5	20 34 	  4 
	ld a,(02bafh)		;00c7	3a af 2b 	: . + 
	rlca			;00ca	07 	. 
	jr nc,l00fbh		;00cb	30 2e 	0 . 
	ld hl,02a8ah		;00cd	21 8a 2a 	! . * 
	ld de,03930h		;00d0	11 30 39 	. 0 9 
	ld b,008h		;00d3	06 08 	. . 
	ld a,d			;00d5	7a 	z 
	inc (hl)			;00d6	34 	4 
	inc (hl)			;00d7	34 	4 
	cp (hl)			;00d8	be 	. 
	jr l00dfh		;00d9	18 04 	. . 
l00dbh:
	inc (hl)			;00db	34 	4 
	cp (hl)			;00dc	be 	. 
	ld a,035h		;00dd	3e 35 	> 5 
l00dfh:
	jr nc,l00ebh		;00df	30 0a 	0 . 
	ld (hl),e			;00e1	73 	s 
	dec hl			;00e2	2b 	+ 
	bit 0,b		;00e3	cb 40 	. @ 
	jr z,l00e9h		;00e5	28 02 	( . 
	dec hl			;00e7	2b 	+ 
	ld a,d			;00e8	7a 	z 
l00e9h:
	djnz l00dbh		;00e9	10 f0 	. . 
l00ebh:
	dec b			;00eb	05 	. 
	djnz l00fbh		;00ec	10 0d 	. . 
	ld a,(hl)			;00ee	7e 	~ 
	cp 034h		;00ef	fe 34 	. 4 
	jr c,l00fbh		;00f1	38 08 	8 . 
	dec hl			;00f3	2b 	+ 
	bit 1,(hl)		;00f4	cb 4e 	. N 
	jr z,l00fbh		;00f6	28 03 	( . 
	ld (hl),e			;00f8	73 	s 
	inc hl			;00f9	23 	# 
	ld (hl),e			;00fa	73 	s 
l00fbh:
	jp (iy)		;00fb	fd e9 	. . 
l00fdh:
	pop hl			;00fd	e1 	. 
	pop de			;00fe	d1 	. 
	pop bc			;00ff	c1 	. 
	pop af			;0100	f1 	. 
	ei			;0101	fb 	. 
	reti		;0102	ed 4d 	. M 
l0104h:
	inc de			;0104	13 	. 
sub_0105h:
	ld a,(de)			;0105	1a 	. 
	cp 020h		;0106	fe 20 	.   
	jr z,l0104h		;0108	28 fa 	( . 
	ret			;010a	c9 	. 
	inc hl			;010b	23 	# 
	xor a			;010c	af 	. 
	call sub_0df3h		;010d	cd f3 0d 	. . . 
	ld (02a99h),hl		;0110	22 99 2a 	" . * 
	rst 30h			;0113	f7 	. 
sub_0114h:
	rst 8			;0114	cf 	. 
	inc hl			;0115	23 	# 
	xor a			;0116	af 	. 
	call sub_0df3h		;0117	cd f3 0d 	. . . 
	push de			;011a	d5 	. 
	ld de,(02a99h)		;011b	ed 5b 99 2a 	. [ . * 
	inc de			;011f	13 	. 
	rst 10h			;0120	d7 	. 
	jr nc,l0154h		;0121	30 31 	0 1 
	jr l0146h		;0123	18 21 	. ! 
sub_0125h:
	call sub_0105h		;0125	cd 05 01 	. . . 
	sub 041h		;0128	d6 41 	. A 
	ret c			;012a	d8 	. 
	cp 01ah		;012b	fe 1a 	. . 
	ccf			;012d	3f 	? 
	ret c			;012e	d8 	. 
	inc de			;012f	13 	. 
	and a			;0130	a7 	. 
	jr nz,l015eh		;0131	20 2b 	  + 
	rst 18h			;0133	df 	. 
	jr z,l015dh		;0134	28 27 	( ' 
	rst 8			;0136	cf 	. 
	inc hl			;0137	23 	# 
	add hl,hl			;0138	29 	) 
	add hl,hl			;0139	29 	) 
	push de			;013a	d5 	. 
	jr c,l0154h		;013b	38 17 	8 . 
	ld de,(02a99h)		;013d	ed 5b 99 2a 	. [ . * 
	add hl,de			;0141	19 	. 
	pop de			;0142	d1 	. 
	push de			;0143	d5 	. 
	jr c,$+15		;0144	38 0d 	8 . 
l0146h:
	pop de			;0146	d1 	. 
	rst 18h			;0147	df 	. 
	add hl,hl			;0148	29 	) 
	add hl,bc			;0149	09 	. 
	push de			;014a	d5 	. 
	ex de,hl			;014b	eb 	. 
	call sub_0183h		;014c	cd 83 01 	. . . 
	rst 10h			;014f	d7 	. 
	jr nc,l0188h		;0150	30 36 	0 6 
	ld a,0d5h		;0152	3e d5 	> . 
l0154h:
	call sub_0799h		;0154	cd 99 07 	. . . 
	ld d,e			;0157	53 	S 
	ld c,a			;0158	4f 	O 
	ld d,d			;0159	52 	R 
	ld d,d			;015a	52 	R 
	ld e,c			;015b	59 	Y 
	dec c			;015c	0d 	. 
l015dh:
	xor a			;015d	af 	. 
l015eh:
	ld h,02ah		;015e	26 2a 	& * 
	rla			;0160	17 	. 
	rla			;0161	17 	. 
	ld l,a			;0162	6f 	o 
	xor a			;0163	af 	. 
	ret			;0164	c9 	. 
sub_0165h:
	call sub_0172h		;0165	cd 72 01 	. r . 
	ret nc			;0168	d0 	. 
	cp 041h		;0169	fe 41 	. A 
	ret c			;016b	d8 	. 
	add a,009h		;016c	c6 09 	. . 
	cp 050h		;016e	fe 50 	. P 
	jr l0178h		;0170	18 06 	. . 
sub_0172h:
	ld a,(de)			;0172	1a 	. 
	cp 030h		;0173	fe 30 	. 0 
	ret c			;0175	d8 	. 
	cp 03ah		;0176	fe 3a 	. : 
l0178h:
	ccf			;0178	3f 	? 
	ret c			;0179	d8 	. 
	inc de			;017a	13 	. 
l017bh:
	and 00fh		;017b	e6 0f 	. . 
	ret			;017d	c9 	. 
sub_017eh:
	ld (hl),a			;017e	77 	w 
sub_017fh:
	inc hl			;017f	23 	# 
	ld a,l			;0180	7d 	} 
	jr l017bh		;0181	18 f8 	. . 
sub_0183h:
	push de			;0183	d5 	. 
	ld de,(02c38h)		;0184	ed 5b 38 2c 	. [ 8 , 
l0188h:
	ld hl,(02a6ah)		;0188	2a 6a 2a 	* j * 
	ld a,l			;018b	7d 	} 
	and 0f0h		;018c	e6 f0 	. . 
	ld l,a			;018e	6f 	o 
	sbc hl,de		;018f	ed 52 	. R 
	pop de			;0191	d1 	. 
	xor a			;0192	af 	. 
	ret			;0193	c9 	. 
l0194h:
	inc hl			;0194	23 	# 
	jr z,l019eh		;0195	28 07 	( . 
	push bc			;0197	c5 	. 
	ld c,(hl)			;0198	4e 	N 
	ld b,000h		;0199	06 00 	. . 
	add hl,bc			;019b	09 	. 
	pop bc			;019c	c1 	. 
	dec de			;019d	1b 	. 
l019eh:
	inc de			;019e	13 	. 
	inc hl			;019f	23 	# 
	ex (sp),hl			;01a0	e3 	. 
	ret			;01a1	c9 	. 
sub_01a2h:
	call sub_0248h		;01a2	cd 48 02 	. H . 
	ld b,000h		;01a5	06 00 	. . 
	ld c,b			;01a7	48 	H 
	call sub_0105h		;01a8	cd 05 01 	. . . 
l01abh:
	call sub_01b0h		;01ab	cd b0 01 	. . . 
	jr l01abh		;01ae	18 fb 	. . 
sub_01b0h:
	call sub_0172h		;01b0	cd 72 01 	. r . 
	jr c,l01d5h		;01b3	38 20 	8   
	set 6,b		;01b5	cb f0 	. . 
	bit 7,b		;01b7	cb 78 	. x 
	jr nz,l01d0h		;01b9	20 15 	  . 
	call sub_01c3h		;01bb	cd c3 01 	. . . 
	bit 0,b		;01be	cb 40 	. @ 
	ret z			;01c0	c8 	. 
	dec c			;01c1	0d 	. 
	ret			;01c2	c9 	. 
sub_01c3h:
	call sub_024fh		;01c3	cd 4f 02 	. O . 
	ret z			;01c6	c8 	. 
	exx			;01c7	d9 	. 
	ld h,d			;01c8	62 	b 
	ld l,e			;01c9	6b 	k 
	ex af,af'			;01ca	08 	. 
	ld c,a			;01cb	4f 	O 
	exx			;01cc	d9 	. 
	set 7,b		;01cd	cb f8 	. . 
	pop af			;01cf	f1 	. 
l01d0h:
	bit 0,b		;01d0	cb 40 	. @ 
	ret nz			;01d2	c0 	. 
	inc c			;01d3	0c 	. 
	ret			;01d4	c9 	. 
l01d5h:
	rst 18h			;01d5	df 	. 
	ld l,005h		;01d6	2e 05 	. . 
	bit 0,b		;01d8	cb 40 	. @ 
	set 0,b		;01da	cb c0 	. . 
	ret z			;01dc	c8 	. 
	pop af			;01dd	f1 	. 
	bit 6,b		;01de	cb 70 	. p 
l01e0h:
	ret z			;01e0	c8 	. 
	ld hl,l0018h		;01e1	21 18 00 	! . . 
	push bc			;01e4	c5 	. 
	push de			;01e5	d5 	. 
	exx			;01e6	d9 	. 
	call sub_0914h		;01e7	cd 14 09 	. . . 
	pop de			;01ea	d1 	. 
	ld bc,l01f3h		;01eb	01 f3 01 	. . . 
	push bc			;01ee	c5 	. 
	push de			;01ef	d5 	. 
	jp l0b6dh		;01f0	c3 6d 0b 	. m . 
l01f3h:
	pop bc			;01f3	c1 	. 
	push de			;01f4	d5 	. 
	rst 18h			;01f5	df 	. 
	ld b,l			;01f6	45 	E 
	dec de			;01f7	1b 	. 
	rst 18h			;01f8	df 	. 
	dec hl			;01f9	2b 	+ 
	ld (bc),a			;01fa	02 	. 
	jr l0202h		;01fb	18 05 	. . 
	rst 18h			;01fd	df 	. 
	dec l			;01fe	2d 	- 
	ld (bc),a			;01ff	02 	. 
	set 1,b		;0200	cb c8 	. . 
l0202h:
	call sub_024ah		;0202	cd 4a 02 	. J . 
l0205h:
	call sub_0172h		;0205	cd 72 01 	. r . 
	jr c,l0217h		;0208	38 0d 	8 . 
	set 5,b		;020a	cb e8 	. . 
	call sub_024fh		;020c	cd 4f 02 	. O . 
	jr nz,l0225h		;020f	20 14 	  . 
	jr l0205h		;0211	18 f2 	. . 
l0213h:
	pop de			;0213	d1 	. 
	xor a			;0214	af 	. 
	jr l022eh		;0215	18 17 	. . 
l0217h:
	bit 5,b		;0217	cb 68 	. h 
	jr z,l0213h		;0219	28 f8 	( . 
	pop af			;021b	f1 	. 
	exx			;021c	d9 	. 
	ld a,c			;021d	79 	y 
	or h			;021e	b4 	. 
	ld a,l			;021f	7d 	} 
	exx			;0220	d9 	. 
	jr nz,l0225h		;0221	20 02 	  . 
	bit 7,a		;0223	cb 7f 	.  
l0225h:
	jp nz,0065ah		;0225	c2 5a 06 	. Z . 
	bit 1,b		;0228	cb 48 	. H 
	jr z,l022eh		;022a	28 02 	( . 
	neg		;022c	ed 44 	. D 
l022eh:
	add a,c			;022e	81 	. 
l022fh:
	and a			;022f	a7 	. 
	jr z,l0245h		;0230	28 13 	( . 
	bit 7,a		;0232	cb 7f 	.  
	jr z,l023dh		;0234	28 07 	( . 
	inc a			;0236	3c 	< 
	push af			;0237	f5 	. 
	call sub_0af4h		;0238	cd f4 0a 	. . . 
	jr l0242h		;023b	18 05 	. . 
l023dh:
	dec a			;023d	3d 	= 
	push af			;023e	f5 	. 
	call sub_0ae3h		;023f	cd e3 0a 	. . . 
l0242h:
	pop af			;0242	f1 	. 
	jr l022fh		;0243	18 ea 	. . 
l0245h:
	bit 6,b		;0245	cb 70 	. p 
	ret			;0247	c9 	. 
sub_0248h:
	res 6,b		;0248	cb b0 	. . 
sub_024ah:
	exx			;024a	d9 	. 
	rst 28h			;024b	ef 	. 
	ld c,l			;024c	4d 	M 
	exx			;024d	d9 	. 
	ret			;024e	c9 	. 
sub_024fh:
	ex af,af'			;024f	08 	. 
	exx			;0250	d9 	. 
	ld d,h			;0251	54 	T 
	ld e,l			;0252	5d 	] 
	ld a,c			;0253	79 	y 
	ld b,000h		;0254	06 00 	. . 
	push af			;0256	f5 	. 
	add hl,hl			;0257	29 	) 
	rl c		;0258	cb 11 	. . 
	rl b		;025a	cb 10 	. . 
	add hl,hl			;025c	29 	) 
	rl c		;025d	cb 11 	. . 
	rl b		;025f	cb 10 	. . 
	add hl,de			;0261	19 	. 
	adc a,c			;0262	89 	. 
	ld c,a			;0263	4f 	O 
	ld a,000h		;0264	3e 00 	> . 
	adc a,b			;0266	88 	. 
	ld b,a			;0267	47 	G 
	pop af			;0268	f1 	. 
	push de			;0269	d5 	. 
	ld d,000h		;026a	16 00 	. . 
	add hl,hl			;026c	29 	) 
	rl c		;026d	cb 11 	. . 
	rl b		;026f	cb 10 	. . 
	ex af,af'			;0271	08 	. 
	ld e,a			;0272	5f 	_ 
	add hl,de			;0273	19 	. 
	ld a,d			;0274	7a 	z 
	adc a,c			;0275	89 	. 
	ld c,a			;0276	4f 	O 
	ld a,d			;0277	7a 	z 
	adc a,b			;0278	88 	. 
	ld b,a			;0279	47 	G 
	pop de			;027a	d1 	. 
	exx			;027b	d9 	. 
	ret			;027c	c9 	. 
l027dh:
	ld e,l			;027d	5d 	] 
	ld d,h			;027e	54 	T 
l027fh:
	inc de			;027f	13 	. 
	ld a,(de)			;0280	1a 	. 
	dec de			;0281	1b 	. 
	ld (de),a			;0282	12 	. 
	inc de			;0283	13 	. 
	cp 00dh		;0284	fe 0d 	. . 
	jr nz,l027fh		;0286	20 f7 	  . 
	jr l02afh		;0288	18 25 	. % 
l028ah:
	ld a,l			;028a	7d 	} 
	cp 0b6h		;028b	fe b6 	. . 
	jr z,l02afh		;028d	28 20 	(   
	dec hl			;028f	2b 	+ 
	jr l02afh		;0290	18 1d 	. . 
l0292h:
	ld a,(hl)			;0292	7e 	~ 
	cp 00dh		;0293	fe 0d 	. . 
	jr z,l02afh		;0295	28 18 	( . 
	jr l02eah		;0297	18 51 	. Q 
	call sub_0cd3h		;0299	cd d3 0c 	. . . 
	call sub_07f2h		;029c	cd f2 07 	. . . 
	jp c,0065ah		;029f	da 5a 06 	. Z . 
	ld a,00ch		;02a2	3e 0c 	> . 
	rst 20h			;02a4	e7 	. 
	ld hl,02bb6h		;02a5	21 b6 2b 	! . + 
	ld (02a68h),hl		;02a8	22 68 2a 	" h * 
	call sub_0931h		;02ab	cd 31 09 	. 1 . 
	exx			;02ae	d9 	. 
l02afh:
	ld de,02800h		;02af	11 00 28 	. . ( 
	ld (02a68h),de		;02b2	ed 53 68 2a 	. S h * 
	ld de,02bb6h		;02b6	11 b6 2b 	. . + 
	ld c,(hl)			;02b9	4e 	N 
	ld (hl),000h		;02ba	36 00 	6 . 
	call sub_0937h		;02bc	cd 37 09 	. 7 . 
	ld a,05fh		;02bf	3e 5f 	> _ 
	call sub_07b6h		;02c1	cd b6 07 	. . . 
	call sub_0cf5h		;02c4	cd f5 0c 	. . . 
	cp 00dh		;02c7	fe 0d 	. . 
	jr z,l033ch		;02c9	28 71 	( q 
	or a			;02cb	b7 	. 
	jr z,l027dh		;02cc	28 af 	( . 
	cp 01dh		;02ce	fe 1d 	. . 
	jr z,l028ah		;02d0	28 b8 	( . 
	cp 01eh		;02d2	fe 1e 	. . 
	jr z,l0292h		;02d4	28 bc 	( . 
	jr c,l02afh		;02d6	38 d7 	8 . 
	ld b,a			;02d8	47 	G 
	push hl			;02d9	e5 	. 
	ld hl,02c34h		;02da	21 34 2c 	! 4 , 
	rst 10h			;02dd	d7 	. 
	pop hl			;02de	e1 	. 
	jr c,l02afh		;02df	38 ce 	8 . 
l02e1h:
	dec de			;02e1	1b 	. 
	ld a,(de)			;02e2	1a 	. 
	inc de			;02e3	13 	. 
	ld (de),a			;02e4	12 	. 
	dec de			;02e5	1b 	. 
	rst 10h			;02e6	d7 	. 
	jr nz,l02e1h		;02e7	20 f8 	  . 
	ld (hl),b			;02e9	70 	p 
l02eah:
	inc hl			;02ea	23 	# 
	jr l02afh		;02eb	18 c2 	. . 
sub_02edh:
	ld a,(02a68h)		;02ed	3a 68 2a 	: h * 
	and 01fh		;02f0	e6 1f 	. . 
	ld a,00dh		;02f2	3e 0d 	> . 
	ld (02bb5h),a		;02f4	32 b5 2b 	2 . + 
	ret z			;02f7	c8 	. 
	rst 20h			;02f8	e7 	. 
	ret			;02f9	c9 	. 
l02fah:
	ld a,(02033h)		;02fa	3a 33 20 	: 3   
	rrca			;02fd	0f 	. 
	ret c			;02fe	d8 	. 
sub_02ffh:
	ld a,(02031h)		;02ff	3a 31 20 	: 1   
	rrca			;0302	0f 	. 
	jr c,l02fah		;0303	38 f5 	8 . 
l0305h:
	call sub_02edh		;0305	cd ed 02 	. . . 
	ld de,l0098h		;0308	11 98 00 	. . . 
	call sub_0937h		;030b	cd 37 09 	. 7 . 
	ld de,(02a9fh)		;030e	ed 5b 9f 2a 	. [ . * 
	ld a,d			;0312	7a 	z 
	or e			;0313	b3 	. 
	call nz,sub_08edh		;0314	c4 ed 08 	. . . 
l0317h:
	ei			;0317	fb 	. 
	call sub_02edh		;0318	cd ed 02 	. . . 
	ld de,l0f07h		;031b	11 07 0f 	. . . 
	call sub_0937h		;031e	cd 37 09 	. 7 . 
l0321h:
	rst 28h			;0321	ef 	. 
	ld de,03031h		;0322	11 31 30 	. 1 0 
	ld sp,02aa7h		;0325	31 a7 2a 	1 . * 
	push de			;0328	d5 	. 
	push hl			;0329	e5 	. 
	push hl			;032a	e5 	. 
	push hl			;032b	e5 	. 
	ld hl,(02c36h)		;032c	2a 36 2c 	* 6 , 
	inc hl			;032f	23 	# 
	inc hl			;0330	23 	# 
	push hl			;0331	e5 	. 
	ld sp,02ba8h		;0332	31 a8 2b 	1 . + 
	ld ix,02aach		;0335	dd 21 ac 2a 	. ! . * 
	call sub_07bbh		;0339	cd bb 07 	. . . 
l033ch:
	push de			;033c	d5 	. 
	ld de,02bb6h		;033d	11 b6 2b 	. . + 
	call sub_0cd3h		;0340	cd d3 0c 	. . . 
	pop bc			;0343	c1 	. 
	jp z,l038ch		;0344	ca 8c 03 	. . . 
	dec de			;0347	1b 	. 
	ld a,h			;0348	7c 	| 
	ld (de),a			;0349	12 	. 
	dec de			;034a	1b 	. 
	ld a,l			;034b	7d 	} 
	ld (de),a			;034c	12 	. 
	push bc			;034d	c5 	. 
	push de			;034e	d5 	. 
	ld a,c			;034f	79 	y 
	sub e			;0350	93 	. 
	push af			;0351	f5 	. 
	call sub_07f2h		;0352	cd f2 07 	. . . 
	push de			;0355	d5 	. 
	jr nz,l0368h		;0356	20 10 	  . 
	push de			;0358	d5 	. 
	call sub_0811h		;0359	cd 11 08 	. . . 
	pop bc			;035c	c1 	. 
	ld hl,(02c38h)		;035d	2a 38 2c 	* 8 , 
	call sub_0944h		;0360	cd 44 09 	. D . 
	ld h,b			;0363	60 	` 
	ld l,c			;0364	69 	i 
	ld (02c38h),hl		;0365	22 38 2c 	" 8 , 
l0368h:
	pop bc			;0368	c1 	. 
	ld hl,(02c38h)		;0369	2a 38 2c 	* 8 , 
	pop af			;036c	f1 	. 
	push hl			;036d	e5 	. 
	cp 003h		;036e	fe 03 	. . 
	jr z,l0321h		;0370	28 af 	( . 
	ld e,a			;0372	5f 	_ 
	ld d,000h		;0373	16 00 	. . 
	add hl,de			;0375	19 	. 
	ld de,(02a6ah)		;0376	ed 5b 6a 2a 	. [ j * 
	rst 10h			;037a	d7 	. 
	jp nc,00153h		;037b	d2 53 01 	. S . 
	ld (02c38h),hl		;037e	22 38 2c 	" 8 , 
	pop de			;0381	d1 	. 
	call sub_094ch		;0382	cd 4c 09 	. L . 
	pop de			;0385	d1 	. 
	pop hl			;0386	e1 	. 
	call sub_0944h		;0387	cd 44 09 	. D . 
	jr l0321h		;038a	18 95 	. . 
l038ch:
	ld hl,l0317h		;038c	21 17 03 	! . . 
	push hl			;038f	e5 	. 
	ld l,00eh		;0390	2e 0e 	. . 
	ld bc,09b2eh		;0392	01 2e 9b 	. . . 
	ld bc,0ee2eh		;0395	01 2e ee 	. . . 
l0398h:
	ld h,00fh		;0398	26 0f 	& . 
l039ah:
	call sub_0105h		;039a	cd 05 01 	. . . 
	push de			;039d	d5 	. 
	inc de			;039e	13 	. 
	inc hl			;039f	23 	# 
	cp (hl)			;03a0	be 	. 
	jr z,l03a9h		;03a1	28 06 	( . 
	bit 7,(hl)		;03a3	cb 7e 	. ~ 
	jr nz,l03b3h		;03a5	20 0c 	  . 
	jr l03bah		;03a7	18 11 	. . 
l03a9h:
	ld a,(de)			;03a9	1a 	. 
	inc de			;03aa	13 	. 
	inc hl			;03ab	23 	# 
	cp (hl)			;03ac	be 	. 
	jr z,l03a9h		;03ad	28 fa 	( . 
	bit 7,(hl)		;03af	cb 7e 	. ~ 
	jr z,l03b6h		;03b1	28 03 	( . 
l03b3h:
	dec de			;03b3	1b 	. 
	jr l03c8h		;03b4	18 12 	. . 
l03b6h:
	cp 02eh		;03b6	fe 2e 	. . 
	jr z,l03c3h		;03b8	28 09 	( . 
l03bah:
	inc hl			;03ba	23 	# 
	bit 7,(hl)		;03bb	cb 7e 	. ~ 
	jr z,l03bah		;03bd	28 fb 	( . 
	inc hl			;03bf	23 	# 
	pop de			;03c0	d1 	. 
	jr l039ah		;03c1	18 d7 	. . 
l03c3h:
	inc hl			;03c3	23 	# 
	bit 7,(hl)		;03c4	cb 7e 	. ~ 
	jr z,l03c3h		;03c6	28 fb 	( . 
l03c8h:
	ld a,(hl)			;03c8	7e 	~ 
	inc hl			;03c9	23 	# 
	ld l,(hl)			;03ca	6e 	n 
	and 07fh		;03cb	e6 7f 	.  
	ld h,a			;03cd	67 	g 
	pop af			;03ce	f1 	. 
	bit 6,h		;03cf	cb 74 	. t 
	res 6,h		;03d1	cb b4 	. . 
	push hl			;03d3	e5 	. 
	call nz,sub_0a6ah		;03d4	c4 6a 0a 	. j . 
	jp 02ba9h		;03d7	c3 a9 2b 	. . + 
l03dah:
	im 1		;03da	ed 56 	. V 
	ld iy,l00fdh		;03dc	fd 21 fd 00 	. ! . . 
	ld hl,027ffh		;03e0	21 ff 27 	! . ' 
	ld (hl),l			;03e3	75 	u 
	ld b,l			;03e4	45 	E 
l03e5h:
	inc hl			;03e5	23 	# 
	ld (hl),b			;03e6	70 	p 
	inc (hl)			;03e7	34 	4 
	jr nz,l03edh		;03e8	20 03 	  . 
	or (hl)			;03ea	b6 	. 
	jr z,l03e5h		;03eb	28 f8 	( . 
l03edh:
	ld (02a6ah),hl		;03ed	22 6a 2a 	" j * 
	ld sp,02badh		;03f0	31 ad 2b 	1 . + 
	ld hl,0c90bh		;03f3	21 0b c9 	! . . 
	push hl			;03f6	e5 	. 
	dec sp			;03f7	3b 	; 
	push hl			;03f8	e5 	. 
	ld a,00ch		;03f9	3e 0c 	> . 
	rst 20h			;03fb	e7 	. 
	call sub_0cd3h		;03fc	cd d3 0c 	. . . 
	ld de,02c3ah		;03ff	11 3a 2c 	. : , 
	add hl,de			;0402	19 	. 
	ld sp,02c3ah		;0403	31 3a 2c 	1 : , 
	push hl			;0406	e5 	. 
	push hl			;0407	e5 	. 
l0408h:
	jp l0067h		;0408	c3 67 00 	. g . 
	call sub_0cd3h		;040b	cd d3 0c 	. . . 
	ld de,(02c36h)		;040e	ed 5b 36 2c 	. [ 6 , 
l0412h:
	jr l0422h		;0412	18 0e 	. . 
sub_0414h:
	ld (02bb5h),a		;0414	32 b5 2b 	2 . + 
	rst 18h			;0417	df 	. 
	ld a,(0f103h)		;0418	3a 03 f1 	: . . 
	jr l042dh		;041b	18 10 	. . 
	rst 18h			;041d	df 	. 
	dec c			;041e	0d 	. 
	jr nz,l0412h		;041f	20 f1 	  . 
l0421h:
	rst 28h			;0421	ef 	. 
l0422h:
	call sub_07f6h		;0422	cd f6 07 	. . . 
	jr c,l0408h		;0425	38 e1 	8 . 
l0427h:
	ld (02a9fh),de		;0427	ed 53 9f 2a 	. S . * 
	inc de			;042b	13 	. 
	inc de			;042c	13 	. 
l042dh:
	call sub_02ffh		;042d	cd ff 02 	. . . 
	ld ix,02aach		;0430	dd 21 ac 2a 	. ! . * 
	ld l,02fh		;0434	2e 2f 	. / 
	jp l0398h		;0436	c3 98 03 	. . . 
sub_0439h:
	call sub_068eh		;0439	cd 8e 06 	. . . 
	call sub_0b10h		;043c	cd 10 0b 	. . . 
	rst 28h			;043f	ef 	. 
	ret			;0440	c9 	. 
	rst 8			;0441	cf 	. 
	ld a,h			;0442	7c 	| 
	or l			;0443	b5 	. 
	jr nz,l042dh		;0444	20 e7 	  . 
	call sub_081ch		;0446	cd 1c 08 	. . . 
l0449h:
	jr nc,l0427h		;0449	30 dc 	0 . 
	jr l0408h		;044b	18 bb 	. . 
	rst 28h			;044d	ef 	. 
	call sub_0813h		;044e	cd 13 08 	. . . 
	jr l0449h		;0451	18 f6 	. . 
	rst 8			;0453	cf 	. 
	push de			;0454	d5 	. 
	call sub_07f2h		;0455	cd f2 07 	. . . 
	jp nz,l065bh		;0458	c2 5b 06 	. [ . 
l045bh:
	pop af			;045b	f1 	. 
	jr l0427h		;045c	18 c9 	. . 
	call sub_0cd3h		;045e	cd d3 0c 	. . . 
l0461h:
	call sub_02edh		;0461	cd ed 02 	. . . 
	call sub_07f2h		;0464	cd f2 07 	. . . 
l0467h:
	jr c,l0408h		;0467	38 9f 	8 . 
l0469h:
	call sub_0931h		;0469	cd 31 09 	. 1 . 
	call sub_07f6h		;046c	cd f6 07 	. . . 
	jr c,l0467h		;046f	38 f6 	8 . 
l0471h:
	call sub_02ffh		;0471	cd ff 02 	. . . 
	ld a,(02030h)		;0474	3a 30 20 	: 0   
	ld hl,02034h		;0477	21 34 20 	! 4   
	and (hl)			;047a	a6 	. 
	rrca			;047b	0f 	. 
	jr nc,l0469h		;047c	30 eb 	0 . 
	jr l0471h		;047e	18 f1 	. . 
	rst 18h			;0480	df 	. 
	ld a,(03e05h)		;0481	3a 05 3e 	: . > 
	dec c			;0484	0d 	. 
	rst 20h			;0485	e7 	. 
	jr l042dh		;0486	18 a5 	. . 
	rst 18h			;0488	df 	. 
	dec c			;0489	0d 	. 
	ld b,(hl)			;048a	46 	F 
	rst 20h			;048b	e7 	. 
l048ch:
	jr l0421h		;048c	18 93 	. . 
	rst 18h			;048e	df 	. 
	ld (0cd54h),hl		;048f	22 54 cd 	" T . 
	jr c,l049dh		;0492	38 09 	8 . 
	jr nz,l048ch		;0494	20 f6 	  . 
	jr l04adh		;0496	18 15 	. . 
	ld l,05ch		;0498	2e 5c 	. \ 
	ld bc,0602eh		;049a	01 2e 60 	. . ` 
l049dh:
	ld h,02ah		;049d	26 2a 	& * 
	call sub_060eh		;049f	cd 0e 06 	. . . 
l04a2h:
	ld a,(hl)			;04a2	7e 	~ 
	inc hl			;04a3	23 	# 
	or a			;04a4	b7 	. 
	jr z,l04adh		;04a5	28 06 	( . 
	rst 20h			;04a7	e7 	. 
	ld a,l			;04a8	7d 	} 
	and 00fh		;04a9	e6 0f 	. . 
	jr nz,l04a2h		;04ab	20 f5 	  . 
l04adh:
	rst 18h			;04ad	df 	. 
	inc l			;04ae	2c 	, 
	dec de			;04af	1b 	. 
l04b0h:
	ld a,(02a68h)		;04b0	3a 68 2a 	: h * 
	and 007h		;04b3	e6 07 	. . 
	jr z,l04ceh		;04b5	28 17 	( . 
	ld a,020h		;04b7	3e 20 	>   
	rst 20h			;04b9	e7 	. 
	jr l04b0h		;04ba	18 f4 	. . 
	rst 8			;04bc	cf 	. 
	ld a,h			;04bd	7c 	| 
	or 028h		;04be	f6 28 	. ( 
	and 029h		;04c0	e6 29 	. ) 
	ld h,a			;04c2	67 	g 
	ld (02a68h),hl		;04c3	22 68 2a 	" h * 
	rst 18h			;04c6	df 	. 
	inc l			;04c7	2c 	, 
	ld (bc),a			;04c8	02 	. 
	jr l04ceh		;04c9	18 03 	. . 
	rst 18h			;04cb	df 	. 
	dec sp			;04cc	3b 	; 
	inc de			;04cd	13 	. 
l04ceh:
	call sub_0414h		;04ce	cd 14 04 	. . . 
	ld l,0e0h		;04d1	2e e0 	. . 
	jp l0398h		;04d3	c3 98 03 	. . . 
	call sub_0cd3h		;04d6	cd d3 0c 	. . . 
	ld (02a6ch),hl		;04d9	22 6c 2a 	" l * 
	jr nz,l04e4h		;04dc	20 06 	  . 
	ld a,00ch		;04de	3e 0c 	> . 
	ld bc,l0d3eh		;04e0	01 3e 0d 	. > . 
	rst 20h			;04e3	e7 	. 
l04e4h:
	rst 30h			;04e4	f7 	. 
	call 00396h		;04e5	cd 96 03 	. . . 
	jr nz,$+9		;04e8	20 07 	  . 
	call sub_0ab2h		;04ea	cd b2 0a 	. . . 
	call sub_08f6h		;04ed	cd f6 08 	. . . 
	ld a,0e7h		;04f0	3e e7 	> . 
	jr l04adh		;04f2	18 b9 	. . 
	call sub_0974h		;04f4	cd 74 09 	. t . 
	rst 8			;04f7	cf 	. 
	push de			;04f8	d5 	. 
	call sub_07f2h		;04f9	cd f2 07 	. . . 
	jp nz,l065bh		;04fc	c2 5b 06 	. [ . 
	ld hl,(02a9fh)		;04ff	2a 9f 2a 	* . * 
	push hl			;0502	e5 	. 
	ld hl,(02aa3h)		;0503	2a a3 2a 	* . * 
	push hl			;0506	e5 	. 
	rst 28h			;0507	ef 	. 
	ld (02aa1h),hl		;0508	22 a1 2a 	" . * 
	add hl,sp			;050b	39 	9 
	ld (02aa3h),hl		;050c	22 a3 2a 	" . * 
	jp l0427h		;050f	c3 27 04 	. ' . 
	ld hl,(02aa3h)		;0512	2a a3 2a 	* . * 
	ld a,h			;0515	7c 	| 
	or l			;0516	b5 	. 
	jp z,0065ah		;0517	ca 5a 06 	. Z . 
	ld sp,hl			;051a	f9 	. 
	pop hl			;051b	e1 	. 
	ld (02aa3h),hl		;051c	22 a3 2a 	" . * 
	pop hl			;051f	e1 	. 
	ld (02a9fh),hl		;0520	22 9f 2a 	" . * 
	pop de			;0523	d1 	. 
l0524h:
	call sub_0959h		;0524	cd 59 09 	. Y . 
	rst 30h			;0527	f7 	. 
	rst 8			;0528	cf 	. 
	ld bc,023efh		;0529	01 ef 23 	. . # 
	ld (02a91h),hl		;052c	22 91 2a 	" . * 
	ld hl,(02a9fh)		;052f	2a 9f 2a 	* . * 
	ld (02a93h),hl		;0532	22 93 2a 	" . * 
	ex de,hl			;0535	eb 	. 
	ld (02a95h),hl		;0536	22 95 2a 	" . * 
	ld bc,0000ah		;0539	01 0a 00 	. . . 
	ld hl,(02aa1h)		;053c	2a a1 2a 	* . * 
	ex de,hl			;053f	eb 	. 
	rst 28h			;0540	ef 	. 
	add hl,sp			;0541	39 	9 
	ld a,009h		;0542	3e 09 	> . 
	ld a,(hl)			;0544	7e 	~ 
	inc hl			;0545	23 	# 
	or (hl)			;0546	b6 	. 
	jr z,l055fh		;0547	28 16 	( . 
	ld a,(hl)			;0549	7e 	~ 
	dec hl			;054a	2b 	+ 
	cp d			;054b	ba 	. 
	jr nz,$-9		;054c	20 f5 	  . 
	ld a,(hl)			;054e	7e 	~ 
	cp e			;054f	bb 	. 
	jr nz,$-13		;0550	20 f1 	  . 
	ex de,hl			;0552	eb 	. 
	rst 28h			;0553	ef 	. 
	add hl,sp			;0554	39 	9 
	ld b,h			;0555	44 	D 
	ld c,l			;0556	4d 	M 
	ld hl,0000ah		;0557	21 0a 00 	! . . 
	add hl,de			;055a	19 	. 
	call sub_094ch		;055b	cd 4c 09 	. L . 
	ld sp,hl			;055e	f9 	. 
l055fh:
	ld hl,(02a95h)		;055f	2a 95 2a 	* . * 
	ex de,hl			;0562	eb 	. 
	rst 30h			;0563	f7 	. 
	call 0078bh		;0564	cd 8b 07 	. . . 
	ld (02a9bh),hl		;0567	22 9b 2a 	" . * 
l056ah:
	push de			;056a	d5 	. 
	ex de,hl			;056b	eb 	. 
	ld hl,(02aa1h)		;056c	2a a1 2a 	* . * 
	ld a,h			;056f	7c 	| 
	or l			;0570	b5 	. 
	jp z,l065bh		;0571	ca 5b 06 	. [ . 
	rst 10h			;0574	d7 	. 
	jr z,l0580h		;0575	28 09 	( . 
	pop de			;0577	d1 	. 
	call sub_0959h		;0578	cd 59 09 	. Y . 
	ld hl,(02a9bh)		;057b	2a 9b 2a 	* . * 
	jr l056ah		;057e	18 ea 	. . 
l0580h:
	call sub_0a45h		;0580	cd 45 0a 	. E . 
	call l0a6dh		;0583	cd 6d 0a 	. m . 
	ex de,hl			;0586	eb 	. 
	ld hl,(02a91h)		;0587	2a 91 2a 	* . * 
	push hl			;058a	e5 	. 
	add hl,de			;058b	19 	. 
	push hl			;058c	e5 	. 
	call sub_0abch		;058d	cd bc 0a 	. . . 
	ld hl,(02aa1h)		;0590	2a a1 2a 	* . * 
	call sub_073bh		;0593	cd 3b 07 	. ; . 
	pop de			;0596	d1 	. 
	ld hl,(02a6eh)		;0597	2a 6e 2a 	* n * 
	pop af			;059a	f1 	. 
	rlca			;059b	07 	. 
	jr nc,l059fh		;059c	30 01 	0 . 
	ex de,hl			;059e	eb 	. 
l059fh:
	ld a,h			;059f	7c 	| 
	xor d			;05a0	aa 	. 
	jp p,l05a5h		;05a1	f2 a5 05 	. . . 
	ex de,hl			;05a4	eb 	. 
l05a5h:
	rst 10h			;05a5	d7 	. 
	pop de			;05a6	d1 	. 
	jp c,l0524h		;05a7	da 24 05 	. $ . 
	ld hl,(02a93h)		;05aa	2a 93 2a 	* . * 
	ld (02a9fh),hl		;05ad	22 9f 2a 	" . * 
	jr l055fh		;05b0	18 ad 	. . 
sub_05b2h:
	jp z,l0736h		;05b2	ca 36 07 	. 6 . 
l05b5h:
	push hl			;05b5	e5 	. 
	call sub_05fch		;05b6	cd fc 05 	. . . 
	jr c,l05cah		;05b9	38 0f 	8 . 
	jr z,l05e2h		;05bb	28 25 	( % 
	ex (sp),hl			;05bd	e3 	. 
	pop bc			;05be	c1 	. 
l05bfh:
	ld a,(bc)			;05bf	0a 	. 
	or a			;05c0	b7 	. 
	jr z,l05edh		;05c1	28 2a 	( * 
	inc bc			;05c3	03 	. 
	call sub_017eh		;05c4	cd 7e 01 	. ~ . 
	jr nz,l05bfh		;05c7	20 f6 	  . 
	ret			;05c9	c9 	. 
l05cah:
	pop hl			;05ca	e1 	. 
	rst 18h			;05cb	df 	. 
	ld (0cd00h),hl		;05cc	22 00 cd 	" . . 
	exx			;05cf	d9 	. 
	dec b			;05d0	05 	. 
	jr z,l05edh		;05d1	28 1a 	( . 
	inc de			;05d3	13 	. 
	call sub_017eh		;05d4	cd 7e 01 	. ~ . 
	jr nz,$-9		;05d7	20 f5 	  . 
	ld a,(de)			;05d9	1a 	. 
	cp 00dh		;05da	fe 0d 	. . 
	ret z			;05dc	c8 	. 
	cp 022h		;05dd	fe 22 	. " 
	ret nz			;05df	c0 	. 
	inc de			;05e0	13 	. 
	ret			;05e1	c9 	. 
l05e2h:
	dec de			;05e2	1b 	. 
	call 00396h		;05e3	cd 96 03 	. . . 
	jr z,l05cah		;05e6	28 e2 	( . 
	pop hl			;05e8	e1 	. 
	call sub_017eh		;05e9	cd 7e 01 	. ~ . 
	ret z			;05ec	c8 	. 
l05edh:
	rst 18h			;05ed	df 	. 
	dec hl			;05ee	2b 	+ 
	ld (bc),a			;05ef	02 	. 
	jr l05b5h		;05f0	18 c3 	. . 
	ld (hl),000h		;05f2	36 00 	6 . 
l05f4h:
	call sub_017fh		;05f4	cd 7f 01 	.  . 
	ret z			;05f7	c8 	. 
	ld (hl),030h		;05f8	36 30 	6 0 
	jr l05f4h		;05fa	18 f8 	. . 
sub_05fch:
	call sub_0125h		;05fc	cd 25 01 	. % . 
	ret c			;05ff	d8 	. 
l0600h:
	dec de			;0600	1b 	. 
	ld a,(de)			;0601	1a 	. 
	inc de			;0602	13 	. 
	cp 029h		;0603	fe 29 	. ) 
	ret z			;0605	c8 	. 
	ld a,(de)			;0606	1a 	. 
	cp 024h		;0607	fe 24 	. $ 
	jr z,l060dh		;0609	28 02 	( . 
	xor a			;060b	af 	. 
	ret			;060c	c9 	. 
l060dh:
	inc de			;060d	13 	. 
sub_060eh:
	ld a,l			;060e	7d 	} 
	sub 05ch		;060f	d6 5c 	. \ 
	jr nz,l061dh		;0611	20 0a 	  . 
	ld l,070h		;0613	2e 70 	. p 
	rst 18h			;0615	df 	. 
	jr z,l061bh		;0616	28 03 	( . 
	call sub_0114h		;0618	cd 14 01 	. . . 
l061bh:
	or h			;061b	b4 	. 
	ret			;061c	c9 	. 
l061dh:
	cp 007h		;061d	fe 07 	. . 
	jp nc,0078fh		;061f	d2 8f 07 	. . . 
	ld l,080h		;0622	2e 80 	. . 
	or h			;0624	b4 	. 
	ret			;0625	c9 	. 
l0626h:
	call sub_05fch		;0626	cd fc 05 	. . . 
	jr c,l0663h		;0629	38 38 	8 8 
	push de			;062b	d5 	. 
	push af			;062c	f5 	. 
	push hl			;062d	e5 	. 
	ld de,(02a9dh)		;062e	ed 5b 9d 2a 	. [ . * 
	ld hl,(02c38h)		;0632	2a 38 2c 	* 8 , 
l0635h:
	rst 18h			;0635	df 	. 
	inc hl			;0636	23 	# 
	ld (bc),a			;0637	02 	. 
	jr l063dh		;0638	18 03 	. . 
	rst 18h			;063a	df 	. 
	inc l			;063b	2c 	, 
	rrca			;063c	0f 	. 
l063dh:
	pop hl			;063d	e1 	. 
	pop af			;063e	f1 	. 
	call sub_05b2h		;063f	cd b2 05 	. . . 
l0642h:
	ld (02a9dh),de		;0642	ed 53 9d 2a 	. S . * 
	pop de			;0646	d1 	. 
	rst 18h			;0647	df 	. 
	inc l			;0648	2c 	, 
	ld b,e			;0649	43 	C 
	jr l0626h		;064a	18 da 	. . 
l064ch:
	ld a,(de)			;064c	1a 	. 
	inc de			;064d	13 	. 
	cp 00dh		;064e	fe 0d 	. . 
	jr nz,l064ch		;0650	20 fa 	  . 
	inc de			;0652	13 	. 
	inc de			;0653	13 	. 
	rst 10h			;0654	d7 	. 
	jr nc,l0635h		;0655	30 de 	0 . 
	pop hl			;0657	e1 	. 
l0658h:
	pop af			;0658	f1 	. 
	ld c,0d5h		;0659	0e d5 	. . 
l065bh:
	call sub_0799h		;065b	cd 99 07 	. . . 
	ld c,b			;065e	48 	H 
	ld c,a			;065f	4f 	O 
	ld d,a			;0660	57 	W 
	ccf			;0661	3f 	? 
	dec c			;0662	0d 	. 
l0663h:
	rst 8			;0663	cf 	. 
	push de			;0664	d5 	. 
	call sub_07f2h		;0665	cd f2 07 	. . . 
	inc de			;0668	13 	. 
	inc de			;0669	13 	. 
	jr l0642h		;066a	18 d6 	. . 
	push de			;066c	d5 	. 
	ld a,03fh		;066d	3e 3f 	> ? 
	call sub_07bdh		;066f	cd bd 07 	. . . 
	ld de,02bb6h		;0672	11 b6 2b 	. . + 
	rst 18h			;0675	df 	. 
	dec c			;0676	0d 	. 
	dec b			;0677	05 	. 
	pop de			;0678	d1 	. 
	call sub_05fch		;0679	cd fc 05 	. . . 
	rst 30h			;067c	f7 	. 
	pop de			;067d	d1 	. 
	push de			;067e	d5 	. 
	call sub_05fch		;067f	cd fc 05 	. . . 
	jr c,l065bh		;0682	38 d7 	8 . 
	push de			;0684	d5 	. 
	ld de,02bb6h		;0685	11 b6 2b 	. . + 
	call sub_05b2h		;0688	cd b2 05 	. . . 
	pop de			;068b	d1 	. 
	pop af			;068c	f1 	. 
	rst 30h			;068d	f7 	. 
sub_068eh:
	rst 18h			;068e	df 	. 
	dec l			;068f	2d 	- 
	ld b,0efh		;0690	06 ef 	. . 
	call sub_0abch		;0692	cd bc 0a 	. . . 
	jr l06abh		;0695	18 14 	. . 
	rst 18h			;0697	df 	. 
	dec hl			;0698	2b 	+ 
	nop			;0699	00 	. 
	call sub_06b3h		;069a	cd b3 06 	. . . 
l069dh:
	rst 18h			;069d	df 	. 
	dec hl			;069e	2b 	+ 
	ex af,af'			;069f	08 	. 
	call sub_06b3h		;06a0	cd b3 06 	. . . 
	call sub_0b32h		;06a3	cd 32 0b 	. 2 . 
	jr l069dh		;06a6	18 f5 	. . 
	rst 18h			;06a8	df 	. 
	dec l			;06a9	2d 	- 
	rst 18h			;06aa	df 	. 
l06abh:
	call sub_06b3h		;06ab	cd b3 06 	. . . 
	call sub_0b1eh		;06ae	cd 1e 0b 	. . . 
	jr l069dh		;06b1	18 ea 	. . 
sub_06b3h:
	call 00393h		;06b3	cd 93 03 	. . . 
l06b6h:
	rst 18h			;06b6	df 	. 
	ld hl,(0cd08h)		;06b7	2a 08 cd 	* . . 
	sub e			;06ba	93 	. 
	inc bc			;06bb	03 	. 
	call sub_0ae6h		;06bc	cd e6 0a 	. . . 
	jr l06b6h		;06bf	18 f5 	. . 
	rst 18h			;06c1	df 	. 
	cpl			;06c2	2f 	/ 
	add a,0cdh		;06c3	c6 cd 	. . 
	sub e			;06c5	93 	. 
	inc bc			;06c6	03 	. 
	call sub_0af7h		;06c7	cd f7 0a 	. . . 
	jr l06b6h		;06ca	18 ea 	. . 
	ld a,001h		;06cc	3e 01 	> . 
	ld bc,0803eh		;06ce	01 3e 80 	. > . 
	push af			;06d1	f5 	. 
	rst 18h			;06d2	df 	. 
	ld hl,(0f105h)		;06d3	2a 05 f1 	* . . 
	ld (02bafh),a		;06d6	32 af 2b 	2 . + 
	rst 30h			;06d9	f7 	. 
	pop af			;06da	f1 	. 
	ld b,0afh		;06db	06 af 	. . 
	and a			;06dd	a7 	. 
	push af			;06de	f5 	. 
	rst 8			;06df	cf 	. 
	push hl			;06e0	e5 	. 
	call sub_0005h		;06e1	cd 05 00 	. . . 
	push de			;06e4	d5 	. 
	ex de,hl			;06e5	eb 	. 
	ld bc,l0020h		;06e6	01 20 00 	.   . 
	inc e			;06e9	1c 	. 
	ld hl,02800h		;06ea	21 00 28 	! . ( 
l06edh:
	ld d,003h		;06ed	16 03 	. . 
	ld a,001h		;06ef	3e 01 	> . 
l06f1h:
	dec e			;06f1	1d 	. 
	jr z,l06feh		;06f2	28 0a 	( . 
	rlca			;06f4	07 	. 
	rlca			;06f5	07 	. 
	dec d			;06f6	15 	. 
	jr nz,l06f1h		;06f7	20 f8 	  . 
	add hl,bc			;06f9	09 	. 
	res 1,h		;06fa	cb 8c 	. . 
	jr l06edh		;06fc	18 ef 	. . 
l06feh:
	ld b,a			;06fe	47 	G 
	pop de			;06ff	d1 	. 
	ex (sp),hl			;0700	e3 	. 
	res 7,l		;0701	cb bd 	. . 
	res 6,l		;0703	cb b5 	. . 
	srl l		;0705	cb 3d 	. = 
	jr nc,l070ah		;0707	30 01 	0 . 
	rlca			;0709	07 	. 
l070ah:
	ld h,000h		;070a	26 00 	& . 
	pop bc			;070c	c1 	. 
	add hl,bc			;070d	09 	. 
	ld b,a			;070e	47 	G 
	pop af			;070f	f1 	. 
	ld a,b			;0710	78 	x 
	jr nz,l071fh		;0711	20 0c 	  . 
	bit 7,(hl)		;0713	cb 7e 	. ~ 
	jr z,l0718h		;0715	28 01 	( . 
	and (hl)			;0717	a6 	. 
l0718h:
	rst 28h			;0718	ef 	. 
	jr z,l071ch		;0719	28 01 	( . 
	inc hl			;071b	23 	# 
l071ch:
	jp sub_0abch		;071c	c3 bc 0a 	. . . 
l071fh:
	push af			;071f	f5 	. 
	bit 7,(hl)		;0720	cb 7e 	. ~ 
	jr nz,l0726h		;0722	20 02 	  . 
	ld (hl),080h		;0724	36 80 	6 . 
l0726h:
	pop af			;0726	f1 	. 
	jp m,0072dh		;0727	fa 2d 07 	. - . 
	cpl			;072a	2f 	/ 
	and (hl)			;072b	a6 	. 
	ld b,0b6h		;072c	06 b6 	. . 
	ld (hl),a			;072e	77 	w 
	rst 30h			;072f	f7 	. 
sub_0730h:
	call 0078bh		;0730	cd 8b 07 	. . . 
	rst 18h			;0733	df 	. 
	dec a			;0734	3d 	= 
	ld e,c			;0735	59 	Y 
l0736h:
	push hl			;0736	e5 	. 
	call sub_0ab2h		;0737	cd b2 0a 	. . . 
	pop hl			;073a	e1 	. 
sub_073bh:
	call sub_090eh		;073b	cd 0e 09 	. . . 
	ld bc,00004h		;073e	01 04 00 	. . . 
	push de			;0741	d5 	. 
	push hl			;0742	e5 	. 
	ex de,hl			;0743	eb 	. 
	push ix		;0744	dd e5 	. . 
	pop hl			;0746	e1 	. 
	ldir		;0747	ed b0 	. . 
	ex de,hl			;0749	eb 	. 
	dec hl			;074a	2b 	+ 
	dec hl			;074b	2b 	+ 
	rl (hl)		;074c	cb 16 	. . 
	inc hl			;074e	23 	# 
	ld a,(ix+004h)		;074f	dd 7e 04 	. ~ . 
	rla			;0752	17 	. 
	rr (hl)		;0753	cb 1e 	. . 
	dec hl			;0755	2b 	+ 
	rr (hl)		;0756	cb 1e 	. . 
	pop hl			;0758	e1 	. 
	pop de			;0759	d1 	. 
	ret			;075a	c9 	. 
	call sub_05fch		;075b	cd fc 05 	. . . 
	jr c,l0768h		;075e	38 08 	8 . 
	push af			;0760	f5 	. 
	rst 18h			;0761	df 	. 
	dec a			;0762	3d 	= 
	dec hl			;0763	2b 	+ 
	pop af			;0764	f1 	. 
	call sub_05b2h		;0765	cd b2 05 	. . . 
l0768h:
	rst 30h			;0768	f7 	. 
	ld h,d			;0769	62 	b 
	ld l,e			;076a	6b 	k 
	call sub_05fch		;076b	cd fc 05 	. . . 
	jr l071ch		;076e	18 ac 	. . 
	push de			;0770	d5 	. 
	ex de,hl			;0771	eb 	. 
	call sub_0ab2h		;0772	cd b2 0a 	. . . 
	pop de			;0775	d1 	. 
	ret			;0776	c9 	. 
	call sub_0125h		;0777	cd 25 01 	. % . 
	jp nc,sub_0a45h		;077a	d2 45 0a 	. E . 
	call sub_01a2h		;077d	cd a2 01 	. . . 
	ret nz			;0780	c0 	. 
sub_0781h:
	rst 18h			;0781	df 	. 
	jr z,$+13		;0782	28 0b 	( . 
	call sub_0ab2h		;0784	cd b2 0a 	. . . 
	rst 18h			;0787	df 	. 
	add hl,hl			;0788	29 	) 
	ld bc,0cdc9h		;0789	01 c9 cd 	. . . 
	dec h			;078c	25 	% 
	ld bc,0d5d0h		;078d	01 d0 d5 	. . . 
	call sub_0799h		;0790	cd 99 07 	. . . 
	ld d,a			;0793	57 	W 
	ld c,b			;0794	48 	H 
	ld b,c			;0795	41 	A 
	ld d,h			;0796	54 	T 
	ccf			;0797	3f 	? 
	dec c			;0798	0d 	. 
sub_0799h:
	pop de			;0799	d1 	. 
	call sub_0937h		;079a	cd 37 09 	. 7 . 
	ld de,(02a9fh)		;079d	ed 5b 9f 2a 	. [ . * 
	ld a,e			;07a1	7b 	{ 
	or d			;07a2	b2 	. 
	ld hl,l0317h		;07a3	21 17 03 	! . . 
	ex (sp),hl			;07a6	e3 	. 
	ret z			;07a7	c8 	. 
	rst 10h			;07a8	d7 	. 
	ret c			;07a9	d8 	. 
	ld c,(hl)			;07aa	4e 	N 
	push bc			;07ab	c5 	. 
	ld (hl),000h		;07ac	36 00 	6 . 
	push hl			;07ae	e5 	. 
	call sub_0931h		;07af	cd 31 09 	. 1 . 
	pop hl			;07b2	e1 	. 
	pop bc			;07b3	c1 	. 
	ld a,03fh		;07b4	3e 3f 	> ? 
sub_07b6h:
	dec de			;07b6	1b 	. 
	ld (hl),c			;07b7	71 	q 
	jp l0936h		;07b8	c3 36 09 	. 6 . 
sub_07bbh:
	ld a,03eh		;07bb	3e 3e 	> > 
sub_07bdh:
	ld de,02bb6h		;07bd	11 b6 2b 	. . + 
	rst 20h			;07c0	e7 	. 
l07c1h:
	exx			;07c1	d9 	. 
	ld (hl),05fh		;07c2	36 5f 	6 _ 
	exx			;07c4	d9 	. 
l07c5h:
	call sub_0cf5h		;07c5	cd f5 0c 	. . . 
	rst 20h			;07c8	e7 	. 
	exx			;07c9	d9 	. 
	ld (hl),05fh		;07ca	36 5f 	6 _ 
	exx			;07cc	d9 	. 
	cp 00dh		;07cd	fe 0d 	. . 
	jr z,l07ddh		;07cf	28 0c 	( . 
	cp 01dh		;07d1	fe 1d 	. . 
	jr z,l07eah		;07d3	28 15 	( . 
	cp 00ch		;07d5	fe 0c 	. . 
	jr z,sub_07bbh		;07d7	28 e2 	( . 
	cp 020h		;07d9	fe 20 	.   
	jr c,l07c5h		;07db	38 e8 	8 . 
l07ddh:
	ld (de),a			;07dd	12 	. 
	inc de			;07de	13 	. 
	cp 00dh		;07df	fe 0d 	. . 
	ret z			;07e1	c8 	. 
	ld a,e			;07e2	7b 	{ 
	cp 034h		;07e3	fe 34 	. 4 
	jr nz,l07c5h		;07e5	20 de 	  . 
	ld a,01dh		;07e7	3e 1d 	> . 
	rst 20h			;07e9	e7 	. 
l07eah:
	ld a,e			;07ea	7b 	{ 
	cp 0b6h		;07eb	fe b6 	. . 
	jr z,sub_07bbh		;07ed	28 cc 	( . 
	dec de			;07ef	1b 	. 
	jr l07c1h		;07f0	18 cf 	. . 
sub_07f2h:
	ld de,(02c36h)		;07f2	ed 5b 36 2c 	. [ 6 , 
sub_07f6h:
	push hl			;07f6	e5 	. 
	ld hl,(02c36h)		;07f7	2a 36 2c 	* 6 , 
	dec hl			;07fa	2b 	+ 
	rst 10h			;07fb	d7 	. 
	jp nc,l0317h		;07fc	d2 17 03 	. . . 
	ld hl,(02c38h)		;07ff	2a 38 2c 	* 8 , 
	dec hl			;0802	2b 	+ 
	rst 10h			;0803	d7 	. 
	pop hl			;0804	e1 	. 
	ret c			;0805	d8 	. 
	ld a,(de)			;0806	1a 	. 
	sub l			;0807	95 	. 
	ld b,a			;0808	47 	G 
	inc de			;0809	13 	. 
	ld a,(de)			;080a	1a 	. 
	sbc a,h			;080b	9c 	. 
l080ch:
	jr c,l0812h		;080c	38 04 	8 . 
	dec de			;080e	1b 	. 
	or b			;080f	b0 	. 
	ret			;0810	c9 	. 
sub_0811h:
	inc de			;0811	13 	. 
l0812h:
	inc de			;0812	13 	. 
sub_0813h:
	ld a,(de)			;0813	1a 	. 
	cp 00dh		;0814	fe 0d 	. . 
	jr nz,l0812h		;0816	20 fa 	  . 
l0818h:
	inc de			;0818	13 	. 
	jr sub_07f6h		;0819	18 db 	. . 
l081bh:
	inc de			;081b	13 	. 
sub_081ch:
	ld a,(de)			;081c	1a 	. 
	rst 28h			;081d	ef 	. 
	cp 00dh		;081e	fe 0d 	. . 
	jr z,l0818h		;0820	28 f6 	( . 
	cp 021h		;0822	fe 21 	. ! 
	jr z,l0812h		;0824	28 ec 	( . 
	cp 022h		;0826	fe 22 	. " 
	jr nz,l0834h		;0828	20 0a 	  . 
l082ah:
	inc de			;082a	13 	. 
	ld a,(de)			;082b	1a 	. 
	cp 00dh		;082c	fe 0d 	. . 
	jr z,l0818h		;082e	28 e8 	( . 
	cp 022h		;0830	fe 22 	. " 
	jr nz,l082ah		;0832	20 f6 	  . 
l0834h:
	cp 045h		;0834	fe 45 	. E 
	jr nz,l081bh		;0836	20 e3 	  . 
	ld l,0f6h		;0838	2e f6 	. . 
	jp l0398h		;083a	c3 98 03 	. . . 
l083dh:
	ld a,(ix-001h)		;083d	dd 7e ff 	. ~ . 
	and a			;0840	a7 	. 
	ld a,020h		;0841	3e 20 	>   
	jr z,l0847h		;0843	28 02 	( . 
	ld a,02dh		;0845	3e 2d 	> - 
l0847h:
	rst 20h			;0847	e7 	. 
	xor a			;0848	af 	. 
	ld (ix-001h),a		;0849	dd 77 ff 	. w . 
	dec a			;084c	3d 	= 
l084dh:
	push af			;084d	f5 	. 
	ld hl,l002ch		;084e	21 2c 00 	! , . 
	call sub_0b05h		;0851	cd 05 0b 	. . . 
	jr nc,l0863h		;0854	30 0d 	0 . 
	call sub_0ae3h		;0856	cd e3 0a 	. . . 
	pop af			;0859	f1 	. 
	dec a			;085a	3d 	= 
	jr l084dh		;085b	18 f0 	. . 
l085dh:
	call sub_0af4h		;085d	cd f4 0a 	. . . 
	pop af			;0860	f1 	. 
	inc a			;0861	3c 	< 
	push af			;0862	f5 	. 
l0863h:
	ld hl,l00a0h		;0863	21 a0 00 	! . . 
	call sub_0b05h		;0866	cd 05 0b 	. . . 
	jr nc,l085dh		;0869	30 f2 	0 . 
	ld a,(ix-002h)		;086b	dd 7e fe 	. ~ . 
	neg		;086e	ed 44 	. D 
l0870h:
	jr z,l087dh		;0870	28 0b 	( . 
	exx			;0872	d9 	. 
	srl c		;0873	cb 39 	. 9 
	rr h		;0875	cb 1c 	. . 
	rr l		;0877	cb 1d 	. . 
	exx			;0879	d9 	. 
	dec a			;087a	3d 	= 
	jr l0870h		;087b	18 f3 	. . 
l087dh:
	ld b,007h		;087d	06 07 	. . 
	push ix		;087f	dd e5 	. . 
	pop hl			;0881	e1 	. 
	ld (hl),000h		;0882	36 00 	6 . 
	inc hl			;0884	23 	# 
l0885h:
	xor a			;0885	af 	. 
	call sub_024fh		;0886	cd 4f 02 	. O . 
	exx			;0889	d9 	. 
	ld a,b			;088a	78 	x 
	exx			;088b	d9 	. 
	ld (hl),a			;088c	77 	w 
	inc hl			;088d	23 	# 
	djnz l0885h		;088e	10 f5 	. . 
	ld bc,l0600h		;0890	01 00 06 	. . . 
	dec hl			;0893	2b 	+ 
	ld a,(hl)			;0894	7e 	~ 
	cp 005h		;0895	fe 05 	. . 
l0897h:
	ccf			;0897	3f 	? 
	ld a,000h		;0898	3e 00 	> . 
	dec hl			;089a	2b 	+ 
	adc a,(hl)			;089b	8e 	. 
	sla c		;089c	cb 21 	. ! 
	cp 00ah		;089e	fe 0a 	. . 
	jr c,l08a4h		;08a0	38 02 	8 . 
	ld a,000h		;08a2	3e 00 	> . 
l08a4h:
	ld (hl),a			;08a4	77 	w 
	push af			;08a5	f5 	. 
	and a			;08a6	a7 	. 
	jr z,l08abh		;08a7	28 02 	( . 
	set 0,c		;08a9	cb c1 	. . 
l08abh:
	pop af			;08ab	f1 	. 
	djnz l0897h		;08ac	10 e9 	. . 
	ld a,c			;08ae	79 	y 
	pop bc			;08af	c1 	. 
	jr c,l08b8h		;08b0	38 06 	8 . 
	inc b			;08b2	04 	. 
	push bc			;08b3	c5 	. 
	ld b,001h		;08b4	06 01 	. . 
	jr l0897h		;08b6	18 df 	. . 
l08b8h:
	ld c,a			;08b8	4f 	O 
	ld a,b			;08b9	78 	x 
	inc a			;08ba	3c 	< 
	jp m,l08c8h		;08bb	fa c8 08 	. . . 
	cp 007h		;08be	fe 07 	. . 
	jr nc,l08c8h		;08c0	30 06 	0 . 
	ld b,a			;08c2	47 	G 
	call sub_091ch		;08c3	cd 1c 09 	. . . 
	jr l090bh		;08c6	18 43 	. C 
l08c8h:
	push bc			;08c8	c5 	. 
	ld b,001h		;08c9	06 01 	. . 
	call sub_091ch		;08cb	cd 1c 09 	. . . 
	ld a,045h		;08ce	3e 45 	> E 
	rst 20h			;08d0	e7 	. 
	pop bc			;08d1	c1 	. 
	bit 7,b		;08d2	cb 78 	. x 
	ld a,02bh		;08d4	3e 2b 	> + 
	jr z,l08e0h		;08d6	28 08 	( . 
	ld a,02dh		;08d8	3e 2d 	> - 
	rst 20h			;08da	e7 	. 
	ld a,b			;08db	78 	x 
	neg		;08dc	ed 44 	. D 
	jr l08e2h		;08de	18 02 	. . 
l08e0h:
	rst 20h			;08e0	e7 	. 
	ld a,b			;08e1	78 	x 
l08e2h:
	ld b,030h		;08e2	06 30 	. 0 
l08e4h:
	cp 00ah		;08e4	fe 0a 	. . 
	jr c,l0904h		;08e6	38 1c 	8 . 
	add a,0f6h		;08e8	c6 f6 	. . 
	inc b			;08ea	04 	. 
	jr l08e4h		;08eb	18 f7 	. . 
sub_08edh:
	ld a,(de)			;08ed	1a 	. 
	ld l,a			;08ee	6f 	o 
	inc de			;08ef	13 	. 
	ld a,(de)			;08f0	1a 	. 
	ld h,a			;08f1	67 	g 
	inc de			;08f2	13 	. 
	call sub_0abch		;08f3	cd bc 0a 	. . . 
sub_08f6h:
	push de			;08f6	d5 	. 
	push bc			;08f7	c5 	. 
	push hl			;08f8	e5 	. 
	ld a,(ix-002h)		;08f9	dd 7e fe 	. ~ . 
	cp 080h		;08fc	fe 80 	. . 
	jp nz,l083dh		;08fe	c2 3d 08 	. = . 
	xor a			;0901	af 	. 
	ld b,020h		;0902	06 20 	.   
l0904h:
	or 030h		;0904	f6 30 	. 0 
	ld c,a			;0906	4f 	O 
	ld a,b			;0907	78 	x 
	rst 20h			;0908	e7 	. 
	ld a,c			;0909	79 	y 
	rst 20h			;090a	e7 	. 
l090bh:
	pop hl			;090b	e1 	. 
	pop bc			;090c	c1 	. 
l090dh:
	pop de			;090d	d1 	. 
sub_090eh:
	ld bc,0fffbh		;090e	01 fb ff 	. . . 
l0911h:
	add ix,bc		;0911	dd 09 	. . 
	ret			;0913	c9 	. 
sub_0914h:
	call sub_0c4ch		;0914	cd 4c 0c 	. L . 
sub_0917h:
	ld bc,0000ah		;0917	01 0a 00 	. . . 
	jr l0911h		;091a	18 f5 	. . 
sub_091ch:
	inc b			;091c	04 	. 
l091dh:
	djnz l0922h		;091d	10 03 	. . 
	ld a,02eh		;091f	3e 2e 	> . 
	rst 20h			;0921	e7 	. 
l0922h:
	ld a,(hl)			;0922	7e 	~ 
	or 030h		;0923	f6 30 	. 0 
	rst 20h			;0925	e7 	. 
	inc hl			;0926	23 	# 
	srl c		;0927	cb 39 	. 9 
	jr nz,l091dh		;0929	20 f2 	  . 
	dec b			;092b	05 	. 
	dec b			;092c	05 	. 
	ret m			;092d	f8 	. 
	inc b			;092e	04 	. 
	jr sub_091ch		;092f	18 eb 	. . 
sub_0931h:
	call sub_08edh		;0931	cd ed 08 	. . . 
	ld a,020h		;0934	3e 20 	>   
l0936h:
	rst 20h			;0936	e7 	. 
sub_0937h:
	xor a			;0937	af 	. 
	ld b,a			;0938	47 	G 
l0939h:
	ld a,(de)			;0939	1a 	. 
	inc de			;093a	13 	. 
	cp b			;093b	b8 	. 
	ret z			;093c	c8 	. 
	rst 20h			;093d	e7 	. 
	cp 00dh		;093e	fe 0d 	. . 
	jr nz,l0939h		;0940	20 f7 	  . 
	inc a			;0942	3c 	< 
	ret			;0943	c9 	. 
sub_0944h:
	rst 10h			;0944	d7 	. 
	ret z			;0945	c8 	. 
	ld a,(de)			;0946	1a 	. 
	ld (bc),a			;0947	02 	. 
	inc de			;0948	13 	. 
	inc bc			;0949	03 	. 
	jr sub_0944h		;094a	18 f8 	. . 
sub_094ch:
	ld a,b			;094c	78 	x 
	sub d			;094d	92 	. 
	jr nz,l0953h		;094e	20 03 	  . 
	ld a,c			;0950	79 	y 
	sub e			;0951	93 	. 
	ret z			;0952	c8 	. 
l0953h:
	dec de			;0953	1b 	. 
	dec hl			;0954	2b 	+ 
	ld a,(de)			;0955	1a 	. 
	ld (hl),a			;0956	77 	w 
	jr sub_094ch		;0957	18 f3 	. . 
sub_0959h:
	pop bc			;0959	c1 	. 
	pop hl			;095a	e1 	. 
	ld (02aa1h),hl		;095b	22 a1 2a 	" . * 
	ld a,h			;095e	7c 	| 
	or l			;095f	b5 	. 
	jr z,l0972h		;0960	28 10 	( . 
	pop hl			;0962	e1 	. 
	ld (02a91h),hl		;0963	22 91 2a 	" . * 
	pop hl			;0966	e1 	. 
	ld (02a6eh),hl		;0967	22 6e 2a 	" n * 
	pop hl			;096a	e1 	. 
	ld (02a93h),hl		;096b	22 93 2a 	" . * 
	pop hl			;096e	e1 	. 
	ld (02a95h),hl		;096f	22 95 2a 	" . * 
l0972h:
	push bc			;0972	c5 	. 
	ret			;0973	c9 	. 
sub_0974h:
	ld hl,0d4c8h		;0974	21 c8 d4 	! . . 
	pop bc			;0977	c1 	. 
	add hl,sp			;0978	39 	9 
	jp nc,00153h		;0979	d2 53 01 	. S . 
	ld hl,(02aa1h)		;097c	2a a1 2a 	* . * 
	ld a,h			;097f	7c 	| 
	or l			;0980	b5 	. 
	jr z,l0996h		;0981	28 13 	( . 
	ld hl,(02a95h)		;0983	2a 95 2a 	* . * 
	push hl			;0986	e5 	. 
	ld hl,(02a93h)		;0987	2a 93 2a 	* . * 
	push hl			;098a	e5 	. 
	ld hl,(02a6eh)		;098b	2a 6e 2a 	* n * 
	push hl			;098e	e5 	. 
	ld hl,(02a91h)		;098f	2a 91 2a 	* . * 
	push hl			;0992	e5 	. 
	ld hl,(02aa1h)		;0993	2a a1 2a 	* . * 
l0996h:
	push hl			;0996	e5 	. 
	push bc			;0997	c5 	. 
	ret			;0998	c9 	. 
sub_0999h:
	rst 18h			;0999	df 	. 
	ld a,007h		;099a	3e 07 	> . 
	call sub_0439h		;099c	cd 39 04 	. 9 . 
	ret z			;099f	c8 	. 
	ret c			;09a0	d8 	. 
	inc hl			;09a1	23 	# 
	ret			;09a2	c9 	. 
	rst 18h			;09a3	df 	. 
	dec a			;09a4	3d 	= 
	ld b,0cdh		;09a5	06 cd 	. . 
	add hl,sp			;09a7	39 	9 
	inc b			;09a8	04 	. 
	ret nz			;09a9	c0 	. 
	inc hl			;09aa	23 	# 
	ret			;09ab	c9 	. 
	rst 18h			;09ac	df 	. 
	inc a			;09ad	3c 	< 
	ld d,e			;09ae	53 	S 
	call sub_0439h		;09af	cd 39 04 	. 9 . 
	ret nc			;09b2	d0 	. 
	inc hl			;09b3	23 	# 
	ret			;09b4	c9 	. 
sub_09b5h:
	push af			;09b5	f5 	. 
	call 02bach		;09b6	cd ac 2b 	. . + 
	ld hl,(02a68h)		;09b9	2a 68 2a 	* h * 
	jr c,l0a04h		;09bc	38 46 	8 F 
	ld (hl),a			;09be	77 	w 
	inc hl			;09bf	23 	# 
l09c0h:
	ld a,02ah		;09c0	3e 2a 	> * 
	cp h			;09c2	bc 	. 
	jr nz,l09ffh		;09c3	20 3a 	  : 
	ld hl,02bb0h		;09c5	21 b0 2b 	! . + 
	call sub_0a3dh		;09c8	cd 3d 0a 	. = . 
	push hl			;09cb	e5 	. 
	inc hl			;09cc	23 	# 
	inc (hl)			;09cd	34 	4 
	call sub_0a3dh		;09ce	cd 3d 0a 	. = . 
	or a			;09d1	b7 	. 
	ld de,(02a6ch)		;09d2	ed 5b 6c 2a 	. [ l * 
	res 1,d		;09d6	cb 8a 	. . 
	ld hl,l01e0h		;09d8	21 e0 01 	! . . 
	sbc hl,de		;09db	ed 52 	. R 
	jr z,l09edh		;09dd	28 0e 	( . 
	jr c,l09edh		;09df	38 0c 	8 . 
	ld b,h			;09e1	44 	D 
	ld c,l			;09e2	4d 	M 
	set 3,d		;09e3	cb da 	. . 
	set 5,d		;09e5	cb ea 	. . 
	ld hl,l0020h		;09e7	21 20 00 	!   . 
	add hl,de			;09ea	19 	. 
	ldir		;09eb	ed b0 	. . 
l09edh:
	ld hl,(02a6ch)		;09ed	2a 6c 2a 	* l * 
	ld a,h			;09f0	7c 	| 
	or l			;09f1	b5 	. 
	pop hl			;09f2	e1 	. 
	jr nz,l09f7h		;09f3	20 02 	  . 
	ld (hl),003h		;09f5	36 03 	6 . 
l09f7h:
	ld hl,029e0h		;09f7	21 e0 29 	! . ) 
	push hl			;09fa	e5 	. 
	call sub_0a34h		;09fb	cd 34 0a 	. 4 . 
	pop hl			;09fe	e1 	. 
l09ffh:
	ld (02a68h),hl		;09ff	22 68 2a 	" h * 
	pop af			;0a02	f1 	. 
	ret			;0a03	c9 	. 
l0a04h:
	cp 00dh		;0a04	fe 0d 	. . 
	jr nz,l0a16h		;0a06	20 0e 	  . 
	ld a,h			;0a08	7c 	| 
	cp 02bh		;0a09	fe 2b 	. + 
	jr c,l0a11h		;0a0b	38 04 	8 . 
	ld (hl),00dh		;0a0d	36 0d 	6 . 
	jr l09ffh		;0a0f	18 ee 	. . 
l0a11h:
	call sub_0a34h		;0a11	cd 34 0a 	. 4 . 
	jr l09c0h		;0a14	18 aa 	. . 
l0a16h:
	cp 00ch		;0a16	fe 0c 	. . 
	jr nz,l0a27h		;0a18	20 0d 	  . 
	ld hl,029ffh		;0a1a	21 ff 29 	! . ) 
l0a1dh:
	ld (hl),020h		;0a1d	36 20 	6   
	dec hl			;0a1f	2b 	+ 
	bit 1,h		;0a20	cb 4c 	. L 
	jr z,l0a1dh		;0a22	28 f9 	( . 
l0a24h:
	inc hl			;0a24	23 	# 
	jr l09ffh		;0a25	18 d8 	. . 
l0a27h:
	cp 01dh		;0a27	fe 1d 	. . 
	jr nz,l09ffh		;0a29	20 d4 	  . 
	ld (hl),020h		;0a2b	36 20 	6   
	dec hl			;0a2d	2b 	+ 
	bit 1,h		;0a2e	cb 4c 	. L 
	jr nz,l0a24h		;0a30	20 f2 	  . 
	jr l09ffh		;0a32	18 cb 	. . 
sub_0a34h:
	ld (hl),020h		;0a34	36 20 	6   
	inc hl			;0a36	23 	# 
	ld a,l			;0a37	7d 	} 
	and 01fh		;0a38	e6 1f 	. . 
	jr nz,sub_0a34h		;0a3a	20 f8 	  . 
	ret			;0a3c	c9 	. 
sub_0a3dh:
	ld a,i		;0a3d	ed 57 	. W 
	ret po			;0a3f	e0 	. 
l0a40h:
	ld a,(hl)			;0a40	7e 	~ 
	or a			;0a41	b7 	. 
	jr nz,l0a40h		;0a42	20 fc 	  . 
	ret			;0a44	c9 	. 
sub_0a45h:
	push de			;0a45	d5 	. 
	push hl			;0a46	e5 	. 
	push af			;0a47	f5 	. 
	ld bc,00004h		;0a48	01 04 00 	. . . 
	push ix		;0a4b	dd e5 	. . 
	pop de			;0a4d	d1 	. 
	ldir		;0a4e	ed b0 	. . 
	rl (ix+002h)		;0a50	dd cb 02 16 	. . . . 
	rl (ix+003h)		;0a54	dd cb 03 16 	. . . . 
	ld a,b			;0a58	78 	x 
	rra			;0a59	1f 	. 
	ld (ix+004h),a		;0a5a	dd 77 04 	. w . 
	scf			;0a5d	37 	7 
	rr (ix+002h)		;0a5e	dd cb 02 1e 	. . . . 
	ld c,005h		;0a62	0e 05 	. . 
	add ix,bc		;0a64	dd 09 	. . 
	pop af			;0a66	f1 	. 
	pop hl			;0a67	e1 	. 
	pop de			;0a68	d1 	. 
	ret			;0a69	c9 	. 
sub_0a6ah:
	call sub_0781h		;0a6a	cd 81 07 	. . . 
l0a6dh:
	exx			;0a6d	d9 	. 
	call sub_090eh		;0a6e	cd 0e 09 	. . . 
	ld de,l0000h		;0a71	11 00 00 	. . . 
	ld a,(ix+003h)		;0a74	dd 7e 03 	. ~ . 
	ld c,(ix+004h)		;0a77	dd 4e 04 	. N . 
	cp 080h		;0a7a	fe 80 	. . 
	jr z,l0aaah		;0a7c	28 2c 	( , 
	cp 001h		;0a7e	fe 01 	. . 
	jp m,l0aaeh		;0a80	fa ae 0a 	. . . 
	cp 010h		;0a83	fe 10 	. . 
	exx			;0a85	d9 	. 
	jp p,0065ah		;0a86	f2 5a 06 	. Z . 
	exx			;0a89	d9 	. 
	ld b,a			;0a8a	47 	G 
	ld a,(ix+000h)		;0a8b	dd 7e 00 	. ~ . 
	ld l,(ix+001h)		;0a8e	dd 6e 01 	. n . 
	ld h,(ix+002h)		;0a91	dd 66 02 	. f . 
l0a94h:
	sla a		;0a94	cb 27 	. ' 
	adc hl,hl		;0a96	ed 6a 	. j 
	rl e		;0a98	cb 13 	. . 
	rl d		;0a9a	cb 12 	. . 
	djnz l0a94h		;0a9c	10 f6 	. . 
l0a9eh:
	sla c		;0a9e	cb 21 	. ! 
	jr nc,l0aaah		;0aa0	30 08 	0 . 
	or h			;0aa2	b4 	. 
	or l			;0aa3	b5 	. 
	jr z,l0aa7h		;0aa4	28 01 	( . 
	inc de			;0aa6	13 	. 
l0aa7h:
	call sub_0ad7h		;0aa7	cd d7 0a 	. . . 
l0aaah:
	push de			;0aaa	d5 	. 
	exx			;0aab	d9 	. 
	pop hl			;0aac	e1 	. 
	ret			;0aad	c9 	. 
l0aaeh:
	ld a,0ffh		;0aae	3e ff 	> . 
	jr l0a9eh		;0ab0	18 ec 	. . 
sub_0ab2h:
	call sub_068eh		;0ab2	cd 8e 06 	. . . 
	call sub_0999h		;0ab5	cd 99 09 	. . . 
	ld bc,00a21h		;0ab8	01 21 0a 	. ! . 
	nop			;0abb	00 	. 
sub_0abch:
	push de			;0abc	d5 	. 
l0abdh:
	ex de,hl			;0abd	eb 	. 
	call sub_0917h		;0abe	cd 17 09 	. . . 
	call sub_0ad4h		;0ac1	cd d4 0a 	. . . 
	push de			;0ac4	d5 	. 
	ld hl,l0010h		;0ac5	21 10 00 	! . . 
	rr h		;0ac8	cb 1c 	. . 
	exx			;0aca	d9 	. 
	pop de			;0acb	d1 	. 
	rst 28h			;0acc	ef 	. 
	ld h,e			;0acd	63 	c 
	ld c,d			;0ace	4a 	J 
	call sub_0c4ch		;0acf	cd 4c 0c 	. L . 
	jr l0b03h		;0ad2	18 2f 	. / 
sub_0ad4h:
	xor a			;0ad4	af 	. 
	add a,d			;0ad5	82 	. 
	ret p			;0ad6	f0 	. 
sub_0ad7h:
	ld a,e			;0ad7	7b 	{ 
	neg		;0ad8	ed 44 	. D 
	ld e,a			;0ada	5f 	_ 
	ld a,d			;0adb	7a 	z 
	cpl			;0adc	2f 	/ 
	ccf			;0add	3f 	? 
	adc a,000h		;0ade	ce 00 	. . 
	ld d,a			;0ae0	57 	W 
	scf			;0ae1	37 	7 
	ret			;0ae2	c9 	. 
sub_0ae3h:
	call 00ab9h		;0ae3	cd b9 0a 	. . . 
sub_0ae6h:
	call sub_0c68h		;0ae6	cd 68 0c 	. h . 
	jr z,l0b29h		;0ae9	28 3e 	( > 
	cp e			;0aeb	bb 	. 
	jp z,00b6bh		;0aec	ca 6b 0b 	. k . 
	call sub_0b81h		;0aef	cd 81 0b 	. . . 
	jr l0b03h		;0af2	18 0f 	. . 
sub_0af4h:
	call 00ab9h		;0af4	cd b9 0a 	. . . 
sub_0af7h:
	call sub_0c68h		;0af7	cd 68 0c 	. h . 
	jr z,l0b29h		;0afa	28 2d 	( - 
	cp e			;0afc	bb 	. 
	jp z,l065bh		;0afd	ca 5b 06 	. [ . 
	call sub_0baeh		;0b00	cd ae 0b 	. . . 
l0b03h:
	jr l0b6dh		;0b03	18 68 	. h 
sub_0b05h:
	call sub_0a45h		;0b05	cd 45 0a 	. E . 
	call sub_0c68h		;0b08	cd 68 0c 	. h . 
	ld bc,0fffbh		;0b0b	01 fb ff 	. . . 
	jr l0b16h		;0b0e	18 06 	. . 
sub_0b10h:
	call sub_0c68h		;0b10	cd 68 0c 	. h . 
	ld bc,0fff6h		;0b13	01 f6 ff 	. . . 
l0b16h:
	add ix,bc		;0b16	dd 09 	. . 
	cp l			;0b18	bd 	. 
	call sub_0be6h		;0b19	cd e6 0b 	. . . 
	pop de			;0b1c	d1 	. 
	ret			;0b1d	c9 	. 
sub_0b1eh:
	call sub_0c68h		;0b1e	cd 68 0c 	. h . 
	jr nz,l0b28h		;0b21	20 05 	  . 
	call sub_0b62h		;0b23	cd 62 0b 	. b . 
	jr l0b58h		;0b26	18 30 	. 0 
l0b28h:
	cp e			;0b28	bb 	. 
l0b29h:
	jr z,l0b7eh		;0b29	28 53 	( S 
	xor d			;0b2b	aa 	. 
	ld d,a			;0b2c	57 	W 
	jr l0b3ah		;0b2d	18 0b 	. . 
	call sub_0a45h		;0b2f	cd 45 0a 	. E . 
sub_0b32h:
	call sub_0c68h		;0b32	cd 68 0c 	. h . 
	jr z,l0b63h		;0b35	28 2c 	( , 
	cp e			;0b37	bb 	. 
	jr z,l0b7eh		;0b38	28 44 	( D 
l0b3ah:
	call sub_0c04h		;0b3a	cd 04 0c 	. . . 
	jr z,l0b4dh		;0b3d	28 0e 	( . 
	jr nc,l0b48h		;0b3f	30 07 	0 . 
	ex de,hl			;0b41	eb 	. 
	exx			;0b42	d9 	. 
	ex de,hl			;0b43	eb 	. 
	ld a,c			;0b44	79 	y 
	ld c,b			;0b45	48 	H 
	ld b,a			;0b46	47 	G 
	exx			;0b47	d9 	. 
l0b48h:
	call sub_0c17h		;0b48	cd 17 0c 	. . . 
	jr l0b6dh		;0b4b	18 20 	.   
l0b4dh:
	ld a,h			;0b4d	7c 	| 
	xor d			;0b4e	aa 	. 
	jr nz,$+28		;0b4f	20 1a 	  . 
	ld e,001h		;0b51	1e 01 	. . 
	call sub_0c3fh		;0b53	cd 3f 0c 	. ? . 
	jr l0b6dh		;0b56	18 15 	. . 
l0b58h:
	ld a,(ix-001h)		;0b58	dd 7e ff 	. ~ . 
	xor 080h		;0b5b	ee 80 	. . 
	ld (ix-001h),a		;0b5d	dd 77 ff 	. w . 
	pop de			;0b60	d1 	. 
	ret			;0b61	c9 	. 
sub_0b62h:
	push de			;0b62	d5 	. 
l0b63h:
	ld h,d			;0b63	62 	b 
	ld l,e			;0b64	6b 	k 
	exx			;0b65	d9 	. 
	ld l,e			;0b66	6b 	k 
	ld h,d			;0b67	62 	b 
	ld c,b			;0b68	48 	H 
	exx			;0b69	d9 	. 
	ld bc,0802eh		;0b6a	01 2e 80 	. . . 
l0b6dh:
	ld (ix-006h),h		;0b6d	dd 74 fa 	. t . 
	ld (ix-007h),l		;0b70	dd 75 f9 	. u . 
	exx			;0b73	d9 	. 
	ld (ix-00ah),l		;0b74	dd 75 f6 	. u . 
	ld (ix-009h),h		;0b77	dd 74 f7 	. t . 
	ld (ix-008h),c		;0b7a	dd 71 f8 	. q . 
	exx			;0b7d	d9 	. 
l0b7eh:
	jp l090dh		;0b7e	c3 0d 09 	. . . 
sub_0b81h:
	ld a,h			;0b81	7c 	| 
	xor d			;0b82	aa 	. 
	ld h,a			;0b83	67 	g 
	dec e			;0b84	1d 	. 
	push hl			;0b85	e5 	. 
	push bc			;0b86	c5 	. 
	ld b,018h		;0b87	06 18 	. . 
	call sub_0c81h		;0b89	cd 81 0c 	. . . 
	xor a			;0b8c	af 	. 
	rst 28h			;0b8d	ef 	. 
	ld c,a			;0b8e	4f 	O 
l0b8fh:
	exx			;0b8f	d9 	. 
	srl c		;0b90	cb 39 	. 9 
	rr h		;0b92	cb 1c 	. . 
	rr l		;0b94	cb 1d 	. . 
	exx			;0b96	d9 	. 
	jr nc,l0b9dh		;0b97	30 04 	0 . 
	add hl,de			;0b99	19 	. 
	ld a,c			;0b9a	79 	y 
	adc a,b			;0b9b	88 	. 
	ld c,a			;0b9c	4f 	O 
l0b9dh:
	exx			;0b9d	d9 	. 
	djnz l0ba5h		;0b9e	10 05 	. . 
	pop bc			;0ba0	c1 	. 
	pop hl			;0ba1	e1 	. 
	exx			;0ba2	d9 	. 
	jr l0bd5h		;0ba3	18 30 	. 0 
l0ba5h:
	exx			;0ba5	d9 	. 
	rr c		;0ba6	cb 19 	. . 
	rr h		;0ba8	cb 1c 	. . 
	rr l		;0baa	cb 1d 	. . 
	jr l0b8fh		;0bac	18 e1 	. . 
sub_0baeh:
	ld a,e			;0bae	7b 	{ 
	neg		;0baf	ed 44 	. D 
	ld e,a			;0bb1	5f 	_ 
	ld a,h			;0bb2	7c 	| 
	xor d			;0bb3	aa 	. 
	ld h,a			;0bb4	67 	g 
	push hl			;0bb5	e5 	. 
	push bc			;0bb6	c5 	. 
	ld b,019h		;0bb7	06 19 	. . 
	exx			;0bb9	d9 	. 
l0bbah:
	sbc hl,de		;0bba	ed 52 	. R 
	ld a,c			;0bbc	79 	y 
	sbc a,b			;0bbd	98 	. 
	ld c,a			;0bbe	4f 	O 
	jr nc,l0bc4h		;0bbf	30 03 	0 . 
	add hl,de			;0bc1	19 	. 
	adc a,b			;0bc2	88 	. 
	ld c,a			;0bc3	4f 	O 
l0bc4h:
	exx			;0bc4	d9 	. 
	ccf			;0bc5	3f 	? 
	adc hl,hl		;0bc6	ed 6a 	. j 
	rl c		;0bc8	cb 11 	. . 
	djnz l0bd7h		;0bca	10 0b 	. . 
	push hl			;0bcc	e5 	. 
	push bc			;0bcd	c5 	. 
	exx			;0bce	d9 	. 
	pop bc			;0bcf	c1 	. 
	pop hl			;0bd0	e1 	. 
	exx			;0bd1	d9 	. 
	pop bc			;0bd2	c1 	. 
	pop hl			;0bd3	e1 	. 
	exx			;0bd4	d9 	. 
l0bd5h:
	jr l0c35h		;0bd5	18 5e 	. ^ 
l0bd7h:
	exx			;0bd7	d9 	. 
	add hl,hl			;0bd8	29 	) 
	rl c		;0bd9	cb 11 	. . 
	jr nc,l0bbah		;0bdb	30 dd 	0 . 
	ccf			;0bdd	3f 	? 
	sbc hl,de		;0bde	ed 52 	. R 
	ld a,c			;0be0	79 	y 
	sbc a,b			;0be1	98 	. 
	ld c,a			;0be2	4f 	O 
	or a			;0be3	b7 	. 
	jr l0bc4h		;0be4	18 de 	. . 
sub_0be6h:
	jr z,l0bf2h		;0be6	28 0a 	( . 
	cp e			;0be8	bb 	. 
	jr z,l0bfah		;0be9	28 0f 	( . 
	ld a,h			;0beb	7c 	| 
	xor d			;0bec	aa 	. 
	call z,sub_0c04h		;0bed	cc 04 0c 	. . . 
	jr l0bf9h		;0bf0	18 07 	. . 
l0bf2h:
	cp e			;0bf2	bb 	. 
	ret z			;0bf3	c8 	. 
	scf			;0bf4	37 	7 
	bit 7,d		;0bf5	cb 7a 	. z 
	jr l0bfch		;0bf7	18 03 	. . 
l0bf9h:
	ret z			;0bf9	c8 	. 
l0bfah:
	bit 7,h		;0bfa	cb 7c 	. | 
l0bfch:
	ccf			;0bfc	3f 	? 
	ret nz			;0bfd	c0 	. 
	ccf			;0bfe	3f 	? 
	rra			;0bff	1f 	. 
	scf			;0c00	37 	7 
	rl a		;0c01	cb 17 	. . 
	ret			;0c03	c9 	. 
sub_0c04h:
	ld a,l			;0c04	7d 	} 
	sub e			;0c05	93 	. 
	jr z,l0c0fh		;0c06	28 07 	( . 
	jp po,l0c0dh		;0c08	e2 0d 0c 	. . . 
	neg		;0c0b	ed 44 	. D 
l0c0dh:
	rlca			;0c0d	07 	. 
	ret			;0c0e	c9 	. 
l0c0fh:
	exx			;0c0f	d9 	. 
	ld a,c			;0c10	79 	y 
	cp b			;0c11	b8 	. 
	jr nz,l0c15h		;0c12	20 01 	  . 
	rst 10h			;0c14	d7 	. 
l0c15h:
	exx			;0c15	d9 	. 
	ret			;0c16	c9 	. 
sub_0c17h:
	ld a,l			;0c17	7d 	} 
	sub e			;0c18	93 	. 
	jr z,l0c29h		;0c19	28 0e 	( . 
	cp 018h		;0c1b	fe 18 	. . 
	ret nc			;0c1d	d0 	. 
	exx			;0c1e	d9 	. 
l0c1fh:
	srl b		;0c1f	cb 38 	. 8 
	rr d		;0c21	cb 1a 	. . 
	rr e		;0c23	cb 1b 	. . 
	dec a			;0c25	3d 	= 
	jr nz,l0c1fh		;0c26	20 f7 	  . 
	exx			;0c28	d9 	. 
l0c29h:
	ld e,000h		;0c29	1e 00 	. . 
	ld a,h			;0c2b	7c 	| 
	xor d			;0c2c	aa 	. 
	jp m,l0c46h		;0c2d	fa 46 0c 	. F . 
	exx			;0c30	d9 	. 
	add hl,de			;0c31	19 	. 
	ld a,c			;0c32	79 	y 
	adc a,b			;0c33	88 	. 
	ld c,a			;0c34	4f 	O 
l0c35h:
	jr nc,l0c3eh		;0c35	30 07 	0 . 
	rr c		;0c37	cb 19 	. . 
	rr h		;0c39	cb 1c 	. . 
	rr l		;0c3b	cb 1d 	. . 
	scf			;0c3d	37 	7 
l0c3eh:
	exx			;0c3e	d9 	. 
sub_0c3fh:
	ld a,l			;0c3f	7d 	} 
	adc a,e			;0c40	8b 	. 
l0c41h:
	jp pe,l0c61h		;0c41	ea 61 0c 	. a . 
	ld l,a			;0c44	6f 	o 
	ret			;0c45	c9 	. 
l0c46h:
	exx			;0c46	d9 	. 
	sbc hl,de		;0c47	ed 52 	. R 
	ld a,c			;0c49	79 	y 
	sbc a,b			;0c4a	98 	. 
	ld c,a			;0c4b	4f 	O 
sub_0c4ch:
	ld b,018h		;0c4c	06 18 	. . 
	xor a			;0c4e	af 	. 
	inc c			;0c4f	0c 	. 
	dec c			;0c50	0d 	. 
l0c51h:
	jp m,l0c5dh		;0c51	fa 5d 0c 	. ] . 
	dec a			;0c54	3d 	= 
	add hl,hl			;0c55	29 	) 
	rl c		;0c56	cb 11 	. . 
	djnz l0c51h		;0c58	10 f7 	. . 
l0c5ah:
	ld l,080h		;0c5a	2e 80 	. . 
	ret			;0c5c	c9 	. 
l0c5dh:
	exx			;0c5d	d9 	. 
	add a,l			;0c5e	85 	. 
	jr l0c41h		;0c5f	18 e0 	. . 
l0c61h:
	ld a,h			;0c61	7c 	| 
	or a			;0c62	b7 	. 
	jp p,l0658h		;0c63	f2 58 06 	. X . 
	jr l0c5ah		;0c66	18 f2 	. . 
sub_0c68h:
	pop hl			;0c68	e1 	. 
	push de			;0c69	d5 	. 
	push hl			;0c6a	e5 	. 
	ld d,(ix-001h)		;0c6b	dd 56 ff 	. V . 
	ld e,(ix-002h)		;0c6e	dd 5e fe 	. ^ . 
	ld h,(ix-006h)		;0c71	dd 66 fa 	. f . 
	ld l,(ix-007h)		;0c74	dd 6e f9 	. n . 
	exx			;0c77	d9 	. 
	ld e,(ix-005h)		;0c78	dd 5e fb 	. ^ . 
	ld d,(ix-004h)		;0c7b	dd 56 fc 	. V . 
	ld b,(ix-003h)		;0c7e	dd 46 fd 	. F . 
sub_0c81h:
	ld l,(ix-00ah)		;0c81	dd 6e f6 	. n . 
	ld h,(ix-009h)		;0c84	dd 66 f7 	. f . 
	ld c,(ix-008h)		;0c87	dd 4e f8 	. N . 
	exx			;0c8a	d9 	. 
	ld a,080h		;0c8b	3e 80 	> . 
	cp l			;0c8d	bd 	. 
	ret			;0c8e	c9 	. 
	push de			;0c8f	d5 	. 
	exx			;0c90	d9 	. 
	ld hl,02aa7h		;0c91	21 a7 2a 	! . * 
	push hl			;0c94	e5 	. 
	ld e,(hl)			;0c95	5e 	^ 
	inc hl			;0c96	23 	# 
	ld d,(hl)			;0c97	56 	V 
	inc hl			;0c98	23 	# 
	ld b,(hl)			;0c99	46 	F 
	exx			;0c9a	d9 	. 
	call sub_0248h		;0c9b	cd 48 02 	. H . 
	rst 28h			;0c9e	ef 	. 
	ld c,003h		;0c9f	0e 03 	. . 
l0ca1h:
	ld b,008h		;0ca1	06 08 	. . 
	ld d,(hl)			;0ca3	56 	V 
l0ca4h:
	exx			;0ca4	d9 	. 
	add hl,hl			;0ca5	29 	) 
	rl c		;0ca6	cb 11 	. . 
	exx			;0ca8	d9 	. 
	rl d		;0ca9	cb 12 	. . 
	jr nc,l0cb3h		;0cab	30 06 	0 . 
	exx			;0cad	d9 	. 
	add hl,de			;0cae	19 	. 
	ld a,c			;0caf	79 	y 
	adc a,b			;0cb0	88 	. 
	ld c,a			;0cb1	4f 	O 
	exx			;0cb2	d9 	. 
l0cb3h:
	djnz l0ca4h		;0cb3	10 ef 	. . 
	inc hl			;0cb5	23 	# 
	dec c			;0cb6	0d 	. 
	jr nz,l0ca1h		;0cb7	20 e8 	  . 
	rst 28h			;0cb9	ef 	. 
	exx			;0cba	d9 	. 
	pop de			;0cbb	d1 	. 
	ld a,l			;0cbc	7d 	} 
	add a,065h		;0cbd	c6 65 	. e 
	ld (de),a			;0cbf	12 	. 
	inc de			;0cc0	13 	. 
	ld l,a			;0cc1	6f 	o 
	ld a,h			;0cc2	7c 	| 
	adc a,0b0h		;0cc3	ce b0 	. . 
	ld (de),a			;0cc5	12 	. 
	inc de			;0cc6	13 	. 
	ld h,a			;0cc7	67 	g 
	ld a,c			;0cc8	79 	y 
	adc a,005h		;0cc9	ce 05 	. . 
	ld (de),a			;0ccb	12 	. 
	ld c,a			;0ccc	4f 	O 
	call sub_0914h		;0ccd	cd 14 09 	. . . 
	jp l0b6dh		;0cd0	c3 6d 0b 	. m . 
sub_0cd3h:
	rst 28h			;0cd3	ef 	. 
	call sub_0105h		;0cd4	cd 05 01 	. . . 
	call sub_0172h		;0cd7	cd 72 01 	. r . 
	jr c,l0ce3h		;0cda	38 07 	8 . 
	dec de			;0cdc	1b 	. 
	call sub_01a2h		;0cdd	cd a2 01 	. . . 
	call l0a6dh		;0ce0	cd 6d 0a 	. m . 
l0ce3h:
	ld a,h			;0ce3	7c 	| 
	or l			;0ce4	b5 	. 
	ret			;0ce5	c9 	. 
l0ce6h:
	cp h			;0ce6	bc 	. 
	jr nz,l0cebh		;0ce7	20 02 	  . 
	ld h,000h		;0ce9	26 00 	& . 
l0cebh:
	cp l			;0ceb	bd 	. 
	jr nz,l0cf0h		;0cec	20 02 	  . 
	ld l,000h		;0cee	2e 00 	. . 
l0cf0h:
	dec e			;0cf0	1d 	. 
	jr nz,l0cfeh		;0cf1	20 0b 	  . 
	jr l0cfbh		;0cf3	18 06 	. . 
sub_0cf5h:
	exx			;0cf5	d9 	. 
	ld hl,(02aa5h)		;0cf6	2a a5 2a 	* . * 
	ld c,00eh		;0cf9	0e 0e 	. . 
l0cfbh:
	ld de,02034h		;0cfb	11 34 20 	. 4   
l0cfeh:
	ld a,(de)			;0cfe	1a 	. 
	rrca			;0cff	0f 	. 
	ld a,e			;0d00	7b 	{ 
	jr c,l0ce6h		;0d01	38 e3 	8 . 
	cp 032h		;0d03	fe 32 	. 2 
	jr nz,l0d0fh		;0d05	20 08 	  . 
	dec c			;0d07	0d 	. 
	jr nz,l0ce6h		;0d08	20 dc 	  . 
	ld a,(02bb4h)		;0d0a	3a b4 2b 	: . + 
	jr l0d54h		;0d0d	18 45 	. E 
l0d0fh:
	cp h			;0d0f	bc 	. 
	jr z,l0cf0h		;0d10	28 de 	( . 
	cp l			;0d12	bd 	. 
	jr z,l0cf0h		;0d13	28 db 	( . 
	ld b,000h		;0d15	06 00 	. . 
l0d17h:
	rst 10h			;0d17	d7 	. 
	ld a,(de)			;0d18	1a 	. 
	rrca			;0d19	0f 	. 
	jr c,l0ce6h		;0d1a	38 ca 	8 . 
	djnz l0d17h		;0d1c	10 f9 	. . 
	ld a,h			;0d1e	7c 	| 
	or a			;0d1f	b7 	. 
	jr nz,l0d25h		;0d20	20 03 	  . 
	ld h,e			;0d22	63 	c 
	jr l0d2ah		;0d23	18 05 	. . 
l0d25h:
	ld a,l			;0d25	7d 	} 
	or a			;0d26	b7 	. 
	jr nz,l0cfeh		;0d27	20 d5 	  . 
	ld l,e			;0d29	6b 	k 
l0d2ah:
	ld (02aa5h),hl		;0d2a	22 a5 2a 	" . * 
	rst 28h			;0d2d	ef 	. 
	ld a,e			;0d2e	7b 	{ 
	cp 034h		;0d2f	fe 34 	. 4 
	jp z,l0461h		;0d31	ca 61 04 	. a . 
	cp 031h		;0d34	fe 31 	. 1 
	jp z,l0305h		;0d36	ca 05 03 	. . . 
	cp 01bh		;0d39	fe 1b 	. . 
	ld hl,02035h		;0d3b	21 35 20 	! 5   
l0d3eh:
	jr c,l0d59h		;0d3e	38 19 	8 . 
	cp 01fh		;0d40	fe 1f 	. . 
	jr c,l0d54h		;0d42	38 10 	8 . 
	sub 01fh		;0d44	d6 1f 	. . 
	rr (hl)		;0d46	cb 1e 	. . 
	rla			;0d48	17 	. 
	ld c,a			;0d49	4f 	O 
	ld hl,l0d70h		;0d4a	21 70 0d 	! p . 
	add hl,bc			;0d4d	09 	. 
	ld a,r		;0d4e	ed 5f 	. _ 
	ld (02aa8h),a		;0d50	32 a8 2a 	2 . * 
	ld a,(hl)			;0d53	7e 	~ 
l0d54h:
	ld (02bb4h),a		;0d54	32 b4 2b 	2 . + 
	exx			;0d57	d9 	. 
	ret			;0d58	c9 	. 
l0d59h:
	add a,040h		;0d59	c6 40 	. @ 
	rr (hl)		;0d5b	cb 1e 	. . 
	jr c,l0d54h		;0d5d	38 f5 	8 . 
	ld hl,l0d94h		;0d5f	21 94 0d 	! . . 
	ld bc,l045bh		;0d62	01 5b 04 	. [ . 
l0d65h:
	cp (hl)			;0d65	be 	. 
	jr z,$+7		;0d66	28 05 	( . 
	inc hl			;0d68	23 	# 
	inc c			;0d69	0c 	. 
	djnz l0d65h		;0d6a	10 f9 	. . 
	ld c,079h		;0d6c	0e 79 	. y 
	jr l0d54h		;0d6e	18 e4 	. . 
l0d70h:
	jr nz,l0d92h		;0d70	20 20 	    
	ld e,a			;0d72	5f 	_ 
	jr nc,l0d96h		;0d73	30 21 	0 ! 
	ld sp,03222h		;0d75	31 22 32 	1 " 2 
	inc hl			;0d78	23 	# 
	inc sp			;0d79	33 	3 
	inc h			;0d7a	24 	$ 
	inc (hl)			;0d7b	34 	4 
	dec h			;0d7c	25 	% 
	dec (hl)			;0d7d	35 	5 
	ld h,036h		;0d7e	26 36 	& 6 
	cp a			;0d80	bf 	. 
	scf			;0d81	37 	7 
	jr z,$+58		;0d82	28 38 	( 8 
	add hl,hl			;0d84	29 	) 
	add hl,sp			;0d85	39 	9 
	dec hl			;0d86	2b 	+ 
	dec sp			;0d87	3b 	; 
	ld hl,(03c3ah)		;0d88	2a 3a 3c 	* : < 
	inc l			;0d8b	2c 	, 
	dec l			;0d8c	2d 	- 
	dec a			;0d8d	3d 	= 
	ld a,02eh		;0d8e	3e 2e 	> . 
	ccf			;0d90	3f 	? 
	cpl			;0d91	2f 	/ 
l0d92h:
	dec c			;0d92	0d 	. 
	dec c			;0d93	0d 	. 
l0d94h:
	ld e,b			;0d94	58 	X 
	ld b,e			;0d95	43 	C 
l0d96h:
	ld e,d			;0d96	5a 	Z 
	ld d,e			;0d97	53 	S 
	inc c			;0d98	0c 	. 
	nop			;0d99	00 	. 
	call sub_0183h		;0d9a	cd 83 01 	. . . 
	ld bc,(02a99h)		;0d9d	ed 4b 99 2a 	. K . * 
	sbc hl,bc		;0da1	ed 42 	. B 
	jr l0dbfh		;0da3	18 1a 	. . 
	ld c,(hl)			;0da5	4e 	N 
	inc hl			;0da6	23 	# 
	ld h,(hl)			;0da7	66 	f 
	ld l,c			;0da8	69 	i 
	jr l0dbfh		;0da9	18 14 	. . 
	ld a,h			;0dab	7c 	| 
	or l			;0dac	b5 	. 
	jr nz,l0db4h		;0dad	20 05 	  . 
	call sub_0cf5h		;0daf	cd f5 0c 	. . . 
	jr l0dbah		;0db2	18 06 	. . 
l0db4h:
	set 5,h		;0db4	cb ec 	. . 
	ld a,(hl)			;0db6	7e 	~ 
	cpl			;0db7	2f 	/ 
l0db8h:
	and 001h		;0db8	e6 01 	. . 
l0dbah:
	ld l,a			;0dba	6f 	o 
	ld a,06eh		;0dbb	3e 6e 	> n 
	ld h,000h		;0dbd	26 00 	& . 
l0dbfh:
	jp sub_0abch		;0dbf	c3 bc 0a 	. . . 
	call sub_05fch		;0dc2	cd fc 05 	. . . 
	push hl			;0dc5	e5 	. 
	rst 18h			;0dc6	df 	. 
	inc l			;0dc7	2c 	, 
	nop			;0dc8	00 	. 
	call sub_05fch		;0dc9	cd fc 05 	. . . 
	pop bc			;0dcc	c1 	. 
l0dcdh:
	ld a,(bc)			;0dcd	0a 	. 
	cp (hl)			;0dce	be 	. 
	jr nz,$+13		;0dcf	20 0b 	  . 
	or a			;0dd1	b7 	. 
	jr z,l0ddbh		;0dd2	28 07 	( . 
	inc hl			;0dd4	23 	# 
	inc bc			;0dd5	03 	. 
	ld a,l			;0dd6	7d 	} 
	and 00fh		;0dd7	e6 0f 	. . 
	jr nz,l0dcdh		;0dd9	20 f2 	  . 
l0ddbh:
	ld a,0afh		;0ddb	3e af 	> . 
	jr l0db8h		;0ddd	18 d9 	. . 
	call sub_0165h		;0ddf	cd 65 01 	. e . 
	jr c,l0df8h		;0de2	38 14 	8 . 
	dec de			;0de4	1b 	. 
	rst 28h			;0de5	ef 	. 
l0de6h:
	call sub_0165h		;0de6	cd 65 01 	. e . 
	jr c,l0dbfh		;0de9	38 d4 	8 . 
	rlca			;0deb	07 	. 
	rlca			;0dec	07 	. 
	rlca			;0ded	07 	. 
	rlca			;0dee	07 	. 
	ld bc,l0de6h		;0def	01 e6 0d 	. . . 
	push bc			;0df2	c5 	. 
sub_0df3h:
	ld b,004h		;0df3	06 04 	. . 
l0df5h:
	rlca			;0df5	07 	. 
	adc hl,hl		;0df6	ed 6a 	. j 
l0df8h:
	jp c,0065ah		;0df8	da 5a 06 	. Z . 
	djnz l0df5h		;0dfb	10 f8 	. . 
	ret			;0dfd	c9 	. 
	or 0afh		;0dfe	f6 af 	. . 
	push af			;0e00	f5 	. 
	rst 8			;0e01	cf 	. 
	push hl			;0e02	e5 	. 
	call sub_0005h		;0e03	cd 05 00 	. . . 
	ex (sp),hl			;0e06	e3 	. 
	pop bc			;0e07	c1 	. 
	ld (hl),c			;0e08	71 	q 
	pop af			;0e09	f1 	. 
	jr z,l0e0eh		;0e0a	28 02 	( . 
	inc hl			;0e0c	23 	# 
	ld (hl),b			;0e0d	70 	p 
l0e0eh:
	rst 30h			;0e0e	f7 	. 
	push de			;0e0f	d5 	. 
	ld de,l0abdh		;0e10	11 bd 0a 	. . . 
	push de			;0e13	d5 	. 
	jp (hl)			;0e14	e9 	. 
	or d			;0e15	b2 	. 
	ld a,l			;0e16	7d 	} 
	ret			;0e17	c9 	. 
	call sub_0974h		;0e18	cd 74 09 	. t . 
	call sub_0730h		;0e1b	cd 30 07 	. 0 . 
	ld (02aa1h),hl		;0e1e	22 a1 2a 	" . * 
	rst 18h			;0e21	df 	. 
	ld d,h			;0e22	54 	T 
	or d			;0e23	b2 	. 
	rst 18h			;0e24	df 	. 
	ld c,a			;0e25	4f 	O 
	xor a			;0e26	af 	. 
	rst 8			;0e27	cf 	. 
	ld (02a6eh),hl		;0e28	22 6e 2a 	" n * 
	ld l,0d8h		;0e2b	2e d8 	. . 
	jp l0398h		;0e2d	c3 98 03 	. . . 
	ld hl,02c36h		;0e30	21 36 2c 	! 6 , 
	push hl			;0e33	e5 	. 
	ld hl,(02c38h)		;0e34	2a 38 2c 	* 8 , 
	rst 18h			;0e37	df 	. 
	dec c			;0e38	0d 	. 
	ld (bc),a			;0e39	02 	. 
	jr l0e42h		;0e3a	18 06 	. . 
	rst 8			;0e3c	cf 	. 
	ex (sp),hl			;0e3d	e3 	. 
	call sub_0005h		;0e3e	cd 05 00 	. . . 
	inc hl			;0e41	23 	# 
l0e42h:
	pop de			;0e42	d1 	. 
	ld b,060h		;0e43	06 60 	. ` 
	di			;0e45	f3 	. 
l0e46h:
	xor a			;0e46	af 	. 
	call sub_0e68h		;0e47	cd 68 0e 	. h . 
	djnz l0e46h		;0e4a	10 fa 	. . 
	ld a,0a5h		;0e4c	3e a5 	> . 
	call sub_0e68h		;0e4e	cd 68 0e 	. h . 
	call sub_0e62h		;0e51	cd 62 0e 	. b . 
	call sub_0e62h		;0e54	cd 62 0e 	. b . 
	dec hl			;0e57	2b 	+ 
l0e58h:
	ld a,(de)			;0e58	1a 	. 
	inc de			;0e59	13 	. 
	call sub_0e68h		;0e5a	cd 68 0e 	. h . 
	jr nc,l0e58h		;0e5d	30 f9 	0 . 
	ld a,b			;0e5f	78 	x 
	cpl			;0e60	2f 	/ 
	ld e,a			;0e61	5f 	_ 
sub_0e62h:
	ex de,hl			;0e62	eb 	. 
	ld a,l			;0e63	7d 	} 
	call sub_0e68h		;0e64	cd 68 0e 	. h . 
	ld a,h			;0e67	7c 	| 
sub_0e68h:
	exx			;0e68	d9 	. 
	ld c,010h		;0e69	0e 10 	. . 
	ld hl,02038h		;0e6b	21 38 20 	! 8   
l0e6eh:
	bit 0,c		;0e6e	cb 41 	. A 
	jr z,l0e77h		;0e70	28 05 	( . 
	rrca			;0e72	0f 	. 
	ld b,064h		;0e73	06 64 	. d 
	jr nc,l0e86h		;0e75	30 0f 	0 . 
l0e77h:
	ld (hl),0fch		;0e77	36 fc 	6 . 
	ld b,032h		;0e79	06 32 	. 2 
l0e7bh:
	djnz l0e7bh		;0e7b	10 fe 	. . 
	ld (hl),0b8h		;0e7d	36 b8 	6 . 
	ld b,032h		;0e7f	06 32 	. 2 
l0e81h:
	djnz l0e81h		;0e81	10 fe 	. . 
	ld (hl),0bch		;0e83	36 bc 	6 . 
	inc b			;0e85	04 	. 
l0e86h:
	djnz l0e86h		;0e86	10 fe 	. . 
l0e88h:
	djnz l0e88h		;0e88	10 fe 	. . 
	dec c			;0e8a	0d 	. 
	jr nz,l0e6eh		;0e8b	20 e1 	  . 
l0e8dh:
	inc bc			;0e8d	03 	. 
	bit 1,b		;0e8e	cb 48 	. H 
	jr z,l0e8dh		;0e90	28 fb 	( . 
	exx			;0e92	d9 	. 
l0e93h:
	add a,b			;0e93	80 	. 
	ld b,a			;0e94	47 	G 
	rst 10h			;0e95	d7 	. 
	ret			;0e96	c9 	. 
	rst 18h			;0e97	df 	. 
	ccf			;0e98	3f 	? 
	nop			;0e99	00 	. 
	push af			;0e9a	f5 	. 
	rst 18h			;0e9b	df 	. 
	dec c			;0e9c	0d 	. 
	ld (bc),a			;0e9d	02 	. 
	rst 28h			;0e9e	ef 	. 
	ld a,0cfh		;0e9f	3e cf 	> . 
	push hl			;0ea1	e5 	. 
	di			;0ea2	f3 	. 
l0ea3h:
	call sub_0eddh		;0ea3	cd dd 0e 	. . . 
	ld a,c			;0ea6	79 	y 
	cp 0a5h		;0ea7	fe a5 	. . 
	jr nz,l0ea3h		;0ea9	20 f8 	  . 
	ld b,a			;0eab	47 	G 
	call sub_0ed9h		;0eac	cd d9 0e 	. . . 
	ld h,c			;0eaf	61 	a 
	pop de			;0eb0	d1 	. 
	push de			;0eb1	d5 	. 
	add hl,de			;0eb2	19 	. 
	ex de,hl			;0eb3	eb 	. 
	call sub_0ed9h		;0eb4	cd d9 0e 	. . . 
	ld h,c			;0eb7	61 	a 
	dec hl			;0eb8	2b 	+ 
	ld a,b			;0eb9	78 	x 
	pop bc			;0eba	c1 	. 
	add hl,bc			;0ebb	09 	. 
	ld b,a			;0ebc	47 	G 
l0ebdh:
	ex de,hl			;0ebd	eb 	. 
	call sub_0eddh		;0ebe	cd dd 0e 	. . . 
	ex af,af'			;0ec1	08 	. 
	ld a,c			;0ec2	79 	y 
	cp (hl)			;0ec3	be 	. 
	jr z,l0ecbh		;0ec4	28 05 	( . 
	pop af			;0ec6	f1 	. 
	jr z,l0ed6h		;0ec7	28 0d 	( . 
	push af			;0ec9	f5 	. 
	ld (hl),c			;0eca	71 	q 
l0ecbh:
	inc hl			;0ecb	23 	# 
	ex de,hl			;0ecc	eb 	. 
	ex af,af'			;0ecd	08 	. 
	jr c,l0ebdh		;0ece	38 ed 	8 . 
	call sub_0eddh		;0ed0	cd dd 0e 	. . . 
	pop af			;0ed3	f1 	. 
	inc b			;0ed4	04 	. 
	ret z			;0ed5	c8 	. 
l0ed6h:
	jp 0078fh		;0ed6	c3 8f 07 	. . . 
sub_0ed9h:
	call sub_0eddh		;0ed9	cd dd 0e 	. . . 
	ld l,c			;0edc	69 	i 
sub_0eddh:
	exx			;0edd	d9 	. 
	ld b,001h		;0ede	06 01 	. . 
l0ee0h:
	ld a,0a7h		;0ee0	3e a7 	> . 
l0ee2h:
	add a,b			;0ee2	80 	. 
	ld hl,02000h		;0ee3	21 00 20 	! .   
	bit 0,(hl)		;0ee6	cb 46 	. F 
	jr z,l0ef1h		;0ee8	28 07 	( . 
	dec a			;0eea	3d 	= 
	jr nz,l0ee2h		;0eeb	20 f5 	  . 
	exx			;0eed	d9 	. 
	ld a,c			;0eee	79 	y 
	jr l0e93h		;0eef	18 a2 	. . 
l0ef1h:
	ld b,0dah		;0ef1	06 da 	. . 
l0ef3h:
	ld a,0a9h		;0ef3	3e a9 	> . 
	djnz l0ef3h		;0ef5	10 fc 	. . 
	ld b,05ah		;0ef7	06 5a 	. Z 
l0ef9h:
	ld c,(hl)			;0ef9	4e 	N 
	rr c		;0efa	cb 19 	. . 
	adc a,000h		;0efc	ce 00 	. . 
	djnz l0ef9h		;0efe	10 f9 	. . 
	rlca			;0f00	07 	. 
	exx			;0f01	d9 	. 
	rr c		;0f02	cb 19 	. . 
	exx			;0f04	d9 	. 
	jr l0ee0h		;0f05	18 d9 	. . 
l0f07h:
	ld b,b			;0f07	40 	@ 
	daa			;0f08	27 	' 
	ld d,d			;0f09	52 	R 
	ld b,l			;0f0a	45 	E 
	ld b,c			;0f0b	41 	A 
	ld b,h			;0f0c	44 	D 
	ld e,c			;0f0d	59 	Y 
	dec c			;0f0e	0d 	. 
	ld c,h			;0f0f	4c 	L 
	ld c,c			;0f10	49 	I 
	ld d,e			;0f11	53 	S 
	ld d,h			;0f12	54 	T 
	add a,h			;0f13	84 	. 
	ld e,(hl)			;0f14	5e 	^ 
	ld d,d			;0f15	52 	R 
	ld d,l			;0f16	55 	U 
	ld c,(hl)			;0f17	4e 	N 
	add a,h			;0f18	84 	. 
	dec bc			;0f19	0b 	. 
	ld c,(hl)			;0f1a	4e 	N 
	ld b,l			;0f1b	45 	E 
	ld d,a			;0f1c	57 	W 
	add a,e			;0f1d	83 	. 
	call m,04153h		;0f1e	fc 53 41 	. S A 
	ld d,(hl)			;0f21	56 	V 
	ld b,l			;0f22	45 	E 
	adc a,(hl)			;0f23	8e 	. 
	jr nc,l0f75h		;0f24	30 4f 	0 O 
	ld c,h			;0f26	4c 	L 
	ld b,h			;0f27	44 	D 
	adc a,(hl)			;0f28	8e 	. 
	sub a			;0f29	97 	. 
	ld b,l			;0f2a	45 	E 
	ld b,h			;0f2b	44 	D 
	ld c,c			;0f2c	49 	I 
	ld d,h			;0f2d	54 	T 
	add a,d			;0f2e	82 	. 
	sbc a,c			;0f2f	99 	. 
	ld c,(hl)			;0f30	4e 	N 
	ld b,l			;0f31	45 	E 
	ld e,b			;0f32	58 	X 
	ld d,h			;0f33	54 	T 
	add a,l			;0f34	85 	. 
	ld h,h			;0f35	64 	d 
	ld c,c			;0f36	49 	I 
	ld c,(hl)			;0f37	4e 	N 
	ld d,b			;0f38	50 	P 
	ld d,l			;0f39	55 	U 
	ld d,h			;0f3a	54 	T 
	add a,(hl)			;0f3b	86 	. 
	ld l,h			;0f3c	6c 	l 
	ld c,c			;0f3d	49 	I 
	ld b,(hl)			;0f3e	46 	F 
	add a,h			;0f3f	84 	. 
	ld b,c			;0f40	41 	A 
	ld b,a			;0f41	47 	G 
	ld c,a			;0f42	4f 	O 
	ld d,h			;0f43	54 	T 
	ld c,a			;0f44	4f 	O 
	add a,h			;0f45	84 	. 
	ld d,e			;0f46	53 	S 
	ld b,e			;0f47	43 	C 
	ld b,c			;0f48	41 	A 
	ld c,h			;0f49	4c 	L 
	ld c,h			;0f4a	4c 	L 
	add a,h			;0f4b	84 	. 
	call p,04e55h		;0f4c	f4 55 4e 	. U N 
	ld b,h			;0f4f	44 	D 
	ld c,a			;0f50	4f 	O 
	ld d,h			;0f51	54 	T 
	add a,(hl)			;0f52	86 	. 
	call z,04552h		;0f53	cc 52 45 	. R E 
	ld d,h			;0f56	54 	T 
	add a,l			;0f57	85 	. 
	ld (de),a			;0f58	12 	. 
	ld d,h			;0f59	54 	T 
	ld b,c			;0f5a	41 	A 
	ld c,e			;0f5b	4b 	K 
	ld b,l			;0f5c	45 	E 
	add a,(hl)			;0f5d	86 	. 
	ld h,021h		;0f5e	26 21 	& ! 
	add a,h			;0f60	84 	. 
	ld c,l			;0f61	4d 	M 
	inc hl			;0f62	23 	# 
	add a,h			;0f63	84 	. 
	ld c,l			;0f64	4d 	M 
l0f65h:
	ld b,(hl)			;0f65	46 	F 
	ld c,a			;0f66	4f 	O 
	ld d,d			;0f67	52 	R 
	adc a,(hl)			;0f68	8e 	. 
	jr l0fbbh		;0f69	18 50 	. P 
	ld d,d			;0f6b	52 	R 
	ld c,c			;0f6c	49 	I 
	ld c,(hl)			;0f6d	4e 	N 
	ld d,h			;0f6e	54 	T 
	add a,h			;0f6f	84 	. 
	add a,b			;0f70	80 	. 
	ld b,h			;0f71	44 	D 
	ld c,a			;0f72	4f 	O 
	ld d,h			;0f73	54 	T 
	add a,(hl)			;0f74	86 	. 
l0f75h:
	rst 8			;0f75	cf 	. 
	ld b,l			;0f76	45 	E 
	ld c,h			;0f77	4c 	L 
	ld d,e			;0f78	53 	S 
	ld b,l			;0f79	45 	E 
	add a,h			;0f7a	84 	. 
	ld c,l			;0f7b	4d 	M 
	ld b,d			;0f7c	42 	B 
	ld e,c			;0f7d	59 	Y 
	ld d,h			;0f7e	54 	T 
	ld b,l			;0f7f	45 	E 
	adc a,l			;0f80	8d 	. 
	rst 38h			;0f81	ff 	. 
	ld d,a			;0f82	57 	W 
	ld c,a			;0f83	4f 	O 
	ld d,d			;0f84	52 	R 
	ld b,h			;0f85	44 	D 
	adc a,l			;0f86	8d 	. 
	cp 041h		;0f87	fe 41 	. A 
	ld d,d			;0f89	52 	R 
	ld d,d			;0f8a	52 	R 
	inc h			;0f8b	24 	$ 
	pop bc			;0f8c	c1 	. 
	dec bc			;0f8d	0b 	. 
	ld d,e			;0f8e	53 	S 
	ld d,h			;0f8f	54 	T 
	ld c,a			;0f90	4f 	O 
	ld d,b			;0f91	50 	P 
	add a,e			;0f92	83 	. 
	rla			;0f93	17 	. 
	ld c,b			;0f94	48 	H 
	ld c,a			;0f95	4f 	O 
	ld c,l			;0f96	4d 	M 
	ld b,l			;0f97	45 	E 
	add a,h			;0f98	84 	. 
	sub 087h		;0f99	d6 87 	. . 
	ld e,e			;0f9b	5b 	[ 
	ld d,d			;0f9c	52 	R 
	ld c,(hl)			;0f9d	4e 	N 
	ld b,h			;0f9e	44 	D 
	adc a,h			;0f9f	8c 	. 
	adc a,a			;0fa0	8f 	. 
	ld c,l			;0fa1	4d 	M 
	ld b,l			;0fa2	45 	E 
	ld c,l			;0fa3	4d 	M 
	adc a,l			;0fa4	8d 	. 
	sbc a,d			;0fa5	9a 	. 
	ld c,e			;0fa6	4b 	K 
	ld b,l			;0fa7	45 	E 
	ld e,c			;0fa8	59 	Y 
	call 042abh		;0fa9	cd ab 42 	. . B 
	ld e,c			;0fac	59 	Y 
	ld d,h			;0fad	54 	T 
	ld b,l			;0fae	45 	E 
	call 057bch		;0faf	cd bc 57 	. . W 
	ld c,a			;0fb2	4f 	O 
	ld d,d			;0fb3	52 	R 
	ld b,h			;0fb4	44 	D 
	call 050a5h		;0fb5	cd a5 50 	. . P 
	ld d,h			;0fb8	54 	T 
	ld d,d			;0fb9	52 	R 
	add a,a			;0fba	87 	. 
l0fbbh:
	ld l,c			;0fbb	69 	i 
	ld d,(hl)			;0fbc	56 	V 
	ld b,c			;0fbd	41 	A 
	ld c,h			;0fbe	4c 	L 
	rst 0			;0fbf	c7 	. 
	ld (hl),b			;0fc0	70 	p 
	ld b,l			;0fc1	45 	E 
	ld d,c			;0fc2	51 	Q 
	adc a,l			;0fc3	8d 	. 
	jp nz,04e49h		;0fc4	c2 49 4e 	. I N 
	ld d,h			;0fc7	54 	T 
	jp z,026bch		;0fc8	ca bc 26 	. . & 
	adc a,l			;0fcb	8d 	. 
	rst 18h			;0fcc	df 	. 
	ld d,l			;0fcd	55 	U 
	ld d,e			;0fce	53 	S 
	ld d,d			;0fcf	52 	R 
	adc a,00fh		;0fd0	ce 0f 	. . 
	ld b,h			;0fd2	44 	D 
	ld c,a			;0fd3	4f 	O 
	ld d,h			;0fd4	54 	T 
	add a,(hl)			;0fd5	86 	. 
	call c,07787h		;0fd6	dc 87 77 	. . w 
	ld d,e			;0fd9	53 	S 
	ld d,h			;0fda	54 	T 
	ld b,l			;0fdb	45 	E 
	ld d,b			;0fdc	50 	P 
	add a,l			;0fdd	85 	. 
	jr z,l0f65h		;0fde	28 85 	( . 
	ld hl,(05441h)		;0fe0	2a 41 54 	* A T 
	add a,h			;0fe3	84 	. 
	cp h			;0fe4	bc 	. 
	ld e,b			;0fe5	58 	X 
	inc h			;0fe6	24 	$ 
	add a,h			;0fe7	84 	. 
	sbc a,b			;0fe8	98 	. 
	ld e,c			;0fe9	59 	Y 
	inc h			;0fea	24 	$ 
	add a,h			;0feb	84 	. 
	sbc a,e			;0fec	9b 	. 
	add a,h			;0fed	84 	. 
	adc a,(hl)			;0fee	8e 	. 
	ld b,e			;0fef	43 	C 
	ld c,b			;0ff0	48 	H 
	ld d,d			;0ff1	52 	R 
	inc h			;0ff2	24 	$ 
	adc a,015h		;0ff3	ce 15 	. . 
	add a,(hl)			;0ff5	86 	. 
	dec bc			;0ff6	0b 	. 
	ld b,l			;0ff7	45 	E 
	ld c,h			;0ff8	4c 	L 
	ld d,e			;0ff9	53 	S 
	ld b,l			;0ffa	45 	E 
	add a,h			;0ffb	84 	. 
	ld a,(de)			;0ffc	1a 	. 
	adc a,b			;0ffd	88 	. 
	dec de			;0ffe	1b 	. 
	nop			;0fff	00 	. 
