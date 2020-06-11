
;  SG-1000, FG-1000 & a few MarkIII ROM Loader for

; MSX + Musical Memory Mapper or Playsoniq cartridge

; Version 0.96 by GDX

; Assembled with zasm cross assembler
; http://sourceforge.net/projects/zasm/

BDOS	equ	00005h
DMA	equ	00080h

CALSLT	equ	0001Ch
ENASLT	equ	00024h
FCB	equ	0005ch
MSXVER	equ	0002dh
RDSLT	equ	0000Ch
WRSLT	equ	00014h

;System variables
EXPTBL	equ	0FCC1h
MNROM	equ	0FCC1h
RAMAD2	equ	0F343h
RG16SAV	equ	0FFEFh
VDP_DW	equ	00007h

DATA:	equ	0600h		; Patch loading data location
BUFTOP	equ	01000h		; Rom loading location
Joypads	equ	0F420h

CR	equ	0Dh
LF	equ	0Ah
PSGo	equ	03Fh		; SN76489 port for MMM cartridge

	org	0100h

	jp	Prog
MainMessage:
	db	"SG-1000 ROM Loader",LF,CR
	db	"v0.96 by GDX",LF,CR,LF,"$",1ah
LoadingTXT:
	db	"Loading...",LF,CR,"$"

PatchingTXT:
	db	"Patching...",LF,CR,"$"

DataTXT:
	db	"Data "
RomTXT:
	db	"ROM "

FileNotFound:
	db	"File not found!$"

TPANotEnough:
	db	"TPA is not enough!$"

FileTooBig:
	db	"File is too big!$"

Sparam:
	db	1

CALMNROM:
	ld	iy,(MNROM-1)
	jp	CALSLT

Prog:
	ld	hl,(0006h)
	ld	de,0D080h
	or	a		; Clear carry flag
	sbc	hl,de
	ld	de,TPANotEnough
	jp	c,Error		; Jump if TPA < 0D100h

	ld	de,MainMessage
	call	Print		; Print Main Message

	ld	HL,VDP_DW
	ld	a,(EXPTBL)
	call	RDSLT
	inc	a		; A = Writing port 1 of VDP
	ld	(VDPWP1),a

	ld	c,046h		; "F"
	call	Param_Srch
	jr	nz,NoFranky

	ld	a,046h
	ld	(DataFileFCB+7),a	; Rename "SG1000.DAT" as "SG1000F.DAT"
NoFranky:
	ld	c,053h		; "S"
	call	Param_Srch
	jr	nz,NoSparam
	xor	a
	ld	(Sparam),a
NoSparam:
	ld	bc,24		; Prepare the FCB
	ld	de,FCB+13
	ld	hl,FCB+12
	ld	(hl),b
	ldir			; Initialize the second half with zero

	ld	c,0Fh
	ld	de,FCB
	call	BDOS		; Open file
	ld	hl,1
	ld	(FCB+14),hl	; Record size = 1 byte
	ld	de,RomTXT
	or	a
	jp	nz,Error	; Jump if File not found

	ld	de,LoadingTXT
	call	Print		; Print Main Message

	ld	c,1ah
	ld	de,BUFTOP
	call	BDOS		; Set disk transfer address (buffer start at BUFTOP)

	ld	c,27h
	ld	de,FCB
	ld	hl,0C000h	; Number of records to read
	call	BDOS		; Read a block in file (48Ko max.)

	ld	hl,(FCB+16)	; HL = file size
	ld	(FileSize),hl
	
	ld	bc,BUFTOP 
	add	hl,bc
	ld	d,h
	ld	e,l
	inc	de
	ld	bc,07Fh 
	ld	(hl),b
	ldir		; Fill 128 bytes with 0 behind the rom (useful if patch exceeds the Rom size)

	ld	c,10h
	ld	de,FCB
	call	BDOS		; Close file

LoadComplete:
	ld	H,080h
	call	MMM_Srch	; MMM detection

	cp	0ffh
	jr	z,No_MMM

	ld	a,080h
	out	(03Ch),a
	ld	a,040h
	ld	(0803Ch),a	; Enable SN76489AN port of MMM
No_MMM:
	ld	a,01Eh		;
	out	(02Ah),a	; Add
	ld	a,PSGo		; Playsoniq
	out	(02Bh),a	; support

	ld	b,4
	ld	a,09Fh
Volume0:
	out	(PSGo),a	; Set the
	add	a,020h		; volume of SN76489AN
	djnz	Volume0		; to zero

	ld	h,80h		; Restore the slot of bank 08000h~0BFFFh
	ld	a,(RAMAD2)
	call	ENASLT

	di
; Replace "OUT 0BEh,A", "IN A,(0BEh)", "OUT 0BFh,A" and "IN A,(0BFh)"
; by "OUT 098h,A", "IN A,(098h)", "OUT 099h,A" and "IN A,(099h)"

	ld	hl,(FileSize)
	ld	b,h
	ld	c,l
	ld	hl,BUFTOP
PatchVDPport:
	ld	a,(hl)
	cp	0D3h
	jr	z,CheckValue
	cp	0DBh
	jr	nz,No_In_Out
CheckValue:
	inc	hl
	ld	a,(hl)
	cp	0BEh
	jr	nz,No_0BEH
	ld	(hl),098h
No_0BEH:
	cp	0BFh
	jr	nz,No_In_Out
	ld	(hl),099h
No_In_Out:
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,PatchVDPport

	ei
	ld	de,PatchingTXT
	call	Print		; Print Main Message

	ld	c,0Fh
	ld	de,DataFileFCB
	call	BDOS		; Open file
	ld	hl,1
	ld	(DataFileFCB+14),hl	; Record size = 1 byte
	ld	de,FileNotFound
	or	a
	jp	nz,Error	; Jump if File not found

	ld	de,FileTooBig
	ld	a,(DataFileFCB+17)	; File size bit 15
	and	080h
	jp	nz,Error	; Jump if File too big
	ld	hl,(DataFileFCB+18)	; File size MSB
	ld	a,l
	cp	h
	jp	nz,Error	; Jump if File too big

	ld	c,1ah
	ld	de,DATA
	call	BDOS		; Set disk transfer address
PatchBCL:
	ld	c,27h
	ld	de,DataFileFCB
	ld	hl,1		; Number of records to read
	call	BDOS		; Read a block in file

	ld	a,(DATA)
	ld	(BytesNumber),a
	or	a
	jr	z,PatchingEnd

	ld	c,27h
	ld	de,DataFileFCB

	ld	h,0
	ld	l,a
	rl	l
	rl	h
	rl	l
	rl	h		; HL = Number of records to read (4 x A)

	call	BDOS		; Read a block in file

	ld	hl,DATA
	call	ROMpatch
	jr	nc,PatchBCL	; Jump if the patch is not appliqued

PatchingEnd:

	xor	a
	ld	(0FCA9h),a	; Hide the cursor
	ld	(0F3EAh),a	; Border color = 0
	ld	(0F3EBh),a	; Border color = 0
	inc	a
	ld	ix,005Fh
	call	CALMNROM	; SCREEN 1 mode

	ld	a,(Sparam)
	or	a
	call	z,SMSpalette	; Call if S option

	ld	hl,ExeRoutine
	ld	de,0F000h
	ld	bc,Joypad1-ExeRoutine
	ldir			; Move ROM copy routine

	ld	hl,MSXVER
	ld	a,(0FCC1H)	; A = Main ROM Slot number
	call	RDSLT		; Read MSXVER
	cp	3

	di
	ld	a,080h
	ld	ix,00180h
	call	p,CALMNROM	; Z80 mode

	di
	ld	a,(VDPWP1)
	ld	c,a		; C= Writing port 1 of VDP
	ld	b,0		; Address in VRAM (LSB)
	out	(c),b
	ld	a,040h		; Address in VRAM (MSB + bit 6-7 = 01 to write)
	out	(c),a
	dec	c
	ld	hl,04000h
VRAM_Init:
	dec	hl
	ld	a,l
	out	(c),b		; Send 00h to VRAM
	or	h
	jr	nz,VRAM_Init

	jp	0F000h		; Jump to moved ROM copy routine

VDPWP1:
	db	099h		; VDP writing port 1 

DataFileNotFnd:
	ld	de,DataTXT
	call	Print		; Print the text
	ld	de,FileNotFound
Error:
	call	Print		; Print the text 
	
	ld	b,55
Wait1S:
	halt
	djnz	Wait1S
	ret			; Exit the program

Print:
	ld	c,9
	jp	BDOS

; -- Parameter search routine
; Entry: C = Character used as option (A~Z or a~z)
; Output: F = NZ if Parameter not found
; Modify: AF, BC, HL

Param_Srch:
	ld	a,c
	or	020h		; Upper case
	ld	c,a
	ld	hl,DMA
	ld	b,(hl)
	inc	b
ParamBCL:
	inc	hl
	ld	a,(hl)
	cp	02Fh		; Seek '/' character
	jr	nz,SLSH_NTFND	; Jump if '/' is not found
	inc	hl
	ld	a,(hl)
	or	020h		; Upper case
	cp	c		; Compare found character with the input character
	ret	z		; Back if character is found
SLSH_NTFND:
	djnz	ParamBCL
	ret

SMSpalette:
	ld	HL,002dh
	ld	a,(EXPTBL)
	call	RDSLT
	or	a
	ret	z	; Back if MSX1

	ld	a,(VDPWP1)
	ld	c,a		; C= Writing port 1 of VDP

	xor	a		; Set color 0 ...
	di
	out	(c),a
	ld	(RG16SAV),a
	ld	a,80h+16	; ...into register 16 (+80h)
	out	(c),a
	ei

	inc	c		; C= Writing port 2 of VDP
	ld	b,31
	ld	hl,SMSpaletteData
	otir
	ret			; Back to MSX-DOS

SMSpaletteData:
	db	00h,0	;0
	db	00h,0	;1
	db	00h,4	;2
	db	00h,7	;3
	db	03h,0	;4
	db	07h,0	;5
	db	30h,0	;6
	db	07h,7	;7
	db	40h,0	;8
	db	70h,0	;9
	db	30h,3	;A
	db	70h,7	;B
	db	00h,2	;C
	db	77h,0	;D
	db	22h,2	;E
	db	77h,7	;F

; Musical Memory Mapper Search Routine
;
; Input: HL = address bank (8000h~BFFFh)
; Output: A = Slot number (0FFh if not found)

MMM_Srch:
	ld	l,0FFh
	ld	b,16

MMM_Srch_Loop:
	push	hl

	ld	a,b
	dec	a
	and	3

	ld	hl,MNROM
	add	a,l
	ld	l,a

	ld	a,b
	dec	a
	or	(hl)

	pop    hl

	jp	m,Sec_SLT	; Jump if secondary Slot

	and	%00001111
	cp	4
	jr	nc,NextMMM_Srch ; Jump if 3-3 Slot

Sec_SLT:
	ld	c,a

	push	bc
	push	hl
	call	ENASLT		; Slot to search
	pop	hl
	pop	bc

	di

	ld	a,080h		; Enable acces to
	out	(03Ch),a	; registers by memory address mode (MMM)

	ld	a,(hl)
	and	%00011111
	inc	a

	out	(0FFh),a

	or	%11000000
	cp	(hl)		; Same value?

	ld	a,0
	out	(03Ch),a	; for MMM
	out	(0FFh),a	; Restore initial mapper page in bank 0C000H~0FFFFH

	ei

	ld	a,c		; A = Found Slot Number (F000SSPP)
	jr	z,MMM_Found

NextMMM_Srch:
	djnz	MMM_Srch_Loop	; Jump if MMM is not found

	ld	a,0FFh		; MMM not found value
	ret

MMM_Found:
	dec	b
	ret

; Routine to patch Megaroms

ROMpatch:
	ld	a,(BytesNumber)		; B = Number of byte to patch
	ld	b,a
	push	hl
VERdata:
	ld	c,(hl)		; C = Original value in Rom
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl		; hl = address to apply patch
	ld	a,c
	cp	(hl)
	jr	nz,NOpatch	; Jump if a data differs
	ex	de,hl
	inc	hl
	djnz	VERdata
	pop	hl
	ld	a,(BytesNumber)		; B = Number of byte to patch
	ld	b,a
BCLpatch:
	inc	hl
	ld	c,(hl)		; B = New value
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl		; hl = address to apply patch
	ld	(hl),c		; change select page address
	ex	de,hl
	inc	hl
	djnz	BCLpatch
	scf			; Carry = 1 (patch is applied)
	ret
NOpatch:
	pop	hl
	xor	a		; Carry = 0 (patch is not applied)
	ret

BytesNumber:
	db	0
	
ExeRoutine:
	ld	hl,Joypad1
	ld	de,Joypads
	ld	bc,041h
	ldir

	ld	bc,080h 
	ld	hl,(FileSize)
	add	hl,bc
	ld	b,h
	ld	c,l
	ld	hl,BUFTOP
	ld	de,0000h
	ldir			; Move the ROM + 100h bytes to 0000h

	ld	hl,0C000h
	ld	(hl),0
	ld	de,0C001h
	ld	bc,301Fh
	ldir			; Init RAM
	ld	hl,0F460h
	ld	(hl),0
	ld	de,0F461h
	ld	bc,0B6Fh
	ldir			; Init RAM

	ld	a,15
	out	(0A0h),a
	in	a,(0A2h)	; Read register 15
	and	08Fh		; and 10001111
	out	(0A1h),a	; Select joystick port 1

	ld	a,14
	out	(0A0h),a	; Prepare to read always joystick port 1 with R#14

	rst	0		; Execute SG ROM

; MSX Joypad routines

Joypad1:			; Start at 0F420h
	push	bc
	ld	a,15
	out	(0A0h),a
	in	a,(0A2h)	; Read register 15
	and	08Fh		; and 10001111
	out	(0A1h),a	; Select Joystick port 1

	ld	a,14
	out	(0A0h),a
	in	a,(0A2h)	; Read register 14
	and	03Fh
	ld	b,a
	
	ld	a,15
	out	(0A0h),a
	in	a,(0A2h)	; Read register 15
	or	040h		; and 01000000
	out	(0A1h),a	; Select Joystick port 2

	ld	a,14
	out	(0A0h),a
	in	a,(0A2h)	; Read register 14
	rra
	rra
	rra
	and	0C0h
	or	b
	pop	bc
	ret
	
Joypad2:			; Start at 0F44Ch
;	ld	a,15
;	out	(0A0h),a
;	in	a,(0A2h)	; Read register 15
;	or	040h		; and 01000000
;	out	(0A1h),a	; Select Joystick port 2

;	ld	a,14
;	out	(0A0h),a
	in	a,(0A2h)	; Read register 14
	rra
	rra
	or	0F0h
	ret

FileSize:
	dw	0

DataFileFCB:
	db	0
	db	"SG1000  DAT"
	ds	26,0
