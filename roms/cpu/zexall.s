; zexall.s - Z80 instruction set exerciser, as a Rally-X program ROM
;
; Frank D. Cringle's zexall (Copyright (C) 1994 Frank D. Cringle), with the
; ZMAC syntax changes Copyright (C) 2002 J.G. Harston, ported to the Rally-X
; board for the openFPGA-RallyX CPU test. GPL version 2 or later, as the
; original:
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version 2
; of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; What changed from the CP/M program, and why:
;
; + It runs from ROM at $0000 instead of from RAM at $0100. Everything the
;   exerciser writes lives in work RAM at $9800, including the test harness
;   (the routine at test:), which patches the instruction under test into
;   itself. It is assembled into ROM at test_rom: and copied up at start.
;   Its one jump is relative, so it runs wherever it lands.
; + msbt, the machine state before each test, moved from $0103 to $9800.
;   28 of the 67 tests put msbt's address in a register, so their CRCs
;   change with it; they are marked "from T80 with msbt at $9800". Those
;   expected CRCs come from running this ROM on T80 in simulation, where T80
;   already matched every real-Z80 CRC of the CP/M zexall with msbt at
;   $0103. The other 39 tests keep Cringle's CRCs, and T80 reproduces them
;   here too.
; + Output goes to the playfield tilemap instead of the CP/M console. The
;   character ROM is ASCII-coded, with $40 as the space.
; + Any control on player 1 steps the text colour through the 64 palette
;   lines, for when the default one draws nothing visible.
;
; The test vectors, expected CRCs (bar those 28), CRC table and the counter,
; shifter and CRC routines are Cringle's, converted to sdasz80 syntax.
; Build: python tools/build_test_rom.py

	.module	zexall
	.area	ROM (ABS)

; Rally-X hardware, from src/fpga/rtl/fpga_nrx.v and nrx_video.v.
VRAM_CODE	= 0x8000	; tile codes: panel $8000-$83FF, playfield $8400-$87FF
VRAM_ATTR	= 0x8800	; attributes, the same layout 2 KB up
PLAY_CODE	= 0x8400
ATTR_OFFSET	= 0x0800
RADAR		= 0xA000	; sprite and radar dot positions, $A000-$A00F (write)
IN0		= 0xA000	; player 1 controls, active low (read)
SOUND		= 0xA100	; WSG registers, $A100-$A11F
HSCROLL		= 0xA130
VSCROLL		= 0xA140
INTENABLE	= 0xA181
BLANK		= 0x40		; the character ROM's space
DEFAULT_ATTR	= 0x21		; palette line 1, drawn in front of sprites

; Work RAM, $9800-$9FFF.
msbt		= 0x9800	; machine state before test: memop,iy,ix,hl,de,bc,af
spbt		= msbt+14	; and sp
msbtlo		= msbt & 0xff
msbthi		= msbt >> 8
test		= 0x9810	; the test harness, copied from test_rom
iut		= test + (iut_rom - test_rom)
flgmsk		= test + (flgmsk_rom - test_rom)
msat		= 0x9880	; machine state after test: memop,iy,ix,hl,de,bc,af
spat		= msat+14	; and sp
flgsat		= spat-2	; the flags
spsav		= spat+2	; the driver's own stack pointer
cntbit		= 0x98A0
cntbyt		= cntbit+1
shfbit		= cntbit+3
shfbyt		= cntbit+4
counter		= 0x98B0	; 2*20 bytes
shifter		= 0x98D8	; 2*20 bytes
crcval		= 0x9900	; 4 bytes
cursor		= 0x9904	; the next playfield cell putc writes
attr		= 0x9906	; text colour
lastin		= 0x9907	; IN0 at the last poll
pollcnt		= 0x9908	; polls the controls once every 256 test cases
testnum		= 0x9909	; the running test, counted from 1
passed		= 0x990A
failed		= 0x990B
STACK		= 0xA000

; Screen rows, counted from the top visible row.
ROW_TITLE	= 0
ROW_NAME	= 1
ROW_GRID	= 3		; 17 rows by 4 columns of "NN OK"
ROW_COUNTS	= 21
ROW_ERROR	= 23
ROW_DONE	= 27

	.org	0x0000
	jp	start
	; Fixed addresses for tools/sim.py: the test table, and the loop the ROM
	; idles in once every test has run.
	.dw	tests
	.dw	idle

start:	di
	ld	sp,#STACK

	; Quiet the board: interrupts and sound off, sprites and radar dots
	; parked, the playfield scrolled so tile column 0 is at the left edge.
	xor	a
	ld	(INTENABLE),a
	ld	hl,#SOUND
	ld	b,#0x20
1$:	ld	(hl),a
	inc	hl
	djnz	1$
	ld	hl,#RADAR
	ld	b,#0x10
2$:	ld	(hl),a
	inc	hl
	djnz	2$
	ld	(VSCROLL),a
	inc	a
	ld	(HSCROLL),a

	ld	hl,#VRAM_CODE
	ld	de,#VRAM_CODE+1
	ld	bc,#0x07ff
	ld	(hl),#BLANK
	ldir
	ld	a,#DEFAULT_ATTR
	ld	(attr),a
	call	paint

	ld	hl,#test_rom
	ld	de,#test
	ld	bc,#test_rom_end-test_rom
	ldir

	xor	a
	ld	(pollcnt),a
	ld	(testnum),a
	ld	(passed),a
	ld	(failed),a
	ld	a,(IN0)
	or	#0x01		; bit 0 is not a control
	ld	(lastin),a

	ld	de,#ROW_TITLE*256+1
	call	locate
	ld	hl,#msg1
	call	puts
	call	counts

	ld	hl,#tests
loop:	ld	a,(hl)		; end of list ?
	inc	hl
	or	(hl)
	jp	z,done
	dec	hl
	call	stt
	jp	loop

done:	ld	de,#ROW_DONE*256+1
	call	locate
	ld	hl,#msg2
	call	puts
idle:	call	poll
	jr	idle

; start test pointed to by (hl)
stt:	push	hl
	ld	a,(hl)		; get pointer to test
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)		; flag mask
	ld	(flgmsk+1),a
	inc	hl
	push	hl
	ld	de,#20
	add	hl,de		; point to incmask
	ld	de,#counter
	call	initmask
	pop	hl
	push	hl
	ld	de,#20+20
	add	hl,de		; point to scanmask
	ld	de,#shifter
	call	initmask
	ld	hl,#shifter
	ld	(hl),#1		; first bit
	pop	hl
	push	hl
	ld	de,#iut		; copy initial instruction under test
	ld	bc,#4
	ldir
	ld	de,#msbt	; copy initial machine state
	ld	bc,#16
	ldir
	ld	de,#20+20+4	; skip incmask, scanmask and expcrc
	add	hl,de
	ex	de,hl
	call	shownm		; show test name
	call	initcrc		; initialise crc
; test loop
tlp:	ld	hl,#pollcnt
	dec	(hl)
	call	z,poll
	ld	a,(iut)
	cp	#0x76		; pragmatically avoid halt intructions
	jp	z,tlp2
	and	#0xdf
	cp	#0xdd
	jp	nz,tlp1
	ld	a,(iut+1)
	cp	#0x76
tlp1:	call	nz,test		; execute the test instruction
tlp2:	call	count		; increment the counter
	call	nz,shift	; shift the scan bit
	pop	hl		; pointer to test case
	jp	z,tlp3		; done if shift returned NZ
	ld	de,#20+20+20
	add	hl,de		; point to expected crc
	call	cmpcrc
	call	report
	pop	hl
	inc	hl
	inc	hl
	ret

tlp3:	push	hl
	ld	a,#1		; initialise count and shift scanners
	ld	(cntbit),a
	ld	(shfbit),a
	ld	hl,#counter
	ld	(cntbyt),hl
	ld	hl,#shifter
	ld	(shfbyt),hl

	ld	b,#4		; bytes in iut field
	pop	hl		; pointer to test case
	push	hl
	ld	de,#iut
	call	setup		; setup iut
	ld	b,#16		; bytes in machine state
	ld	de,#msbt
	call	setup		; setup machine state
	jp	tlp

; setup a field of the test case
; b  = number of bytes
; hl = pointer to base case
; de = destination
setup:	call	subyte
	inc	hl
	dec	b
	jp	nz,setup
	ret

subyte:	push	bc
	push	de
	push	hl
	ld	c,(hl)		; get base byte
	ld	de,#20
	add	hl,de		; point to incmask
	ld	a,(hl)
	cp	#0
	jp	z,subshf
	ld	b,#8		; 8 bits
subclp:	rrca
	push	af
	ld	a,#0
	call	c,nxtcbit	; get next counter bit if mask bit was set
	xor	c		; flip bit if counter bit was set
	rrca
	ld	c,a
	pop	af
	dec	b
	jp	nz,subclp
	ld	b,#8
subshf:	ld	de,#20
	add	hl,de		; point to shift mask
	ld	a,(hl)
	cp	#0
	jp	z,substr
	ld	b,#8		; 8 bits
sbshf1:	rrca
	push	af
	ld	a,#0
	call	c,nxtsbit	; get next shifter bit if mask bit was set
	xor	c		; flip bit if shifter bit was set
	rrca
	ld	c,a
	pop	af
	dec	b
	jp	nz,sbshf1
substr:	pop	hl
	pop	de
	ld	a,c
	ld	(de),a		; mangled byte to destination
	inc	de
	pop	bc
	ret

; get next counter bit in low bit of a
nxtcbit: push	bc
	push	hl
	ld	hl,(cntbyt)
	ld	b,(hl)
	ld	hl,#cntbit
	ld	a,(hl)
	ld	c,a
	rlca
	ld	(hl),a
	cp	#1
	jp	nz,ncb1
	ld	hl,(cntbyt)
	inc	hl
	ld	(cntbyt),hl
ncb1:	ld	a,b
	and	c
	pop	hl
	pop	bc
	ret	z
	ld	a,#1
	ret

; get next shifter bit in low bit of a
nxtsbit: push	bc
	push	hl
	ld	hl,(shfbyt)
	ld	b,(hl)
	ld	hl,#shfbit
	ld	a,(hl)
	ld	c,a
	rlca
	ld	(hl),a
	cp	#1
	jp	nz,nsb1
	ld	hl,(shfbyt)
	inc	hl
	ld	(shfbyt),hl
nsb1:	ld	a,b
	and	c
	pop	hl
	pop	bc
	ret	z
	ld	a,#1
	ret

; clear memory at hl, bc bytes
clrmem:	push	af
	push	bc
	push	de
	push	hl
	ld	(hl),#0
	ld	d,h
	ld	e,l
	inc	de
	dec	bc
	ldir
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; initialise counter or shifter
; de = pointer to work area for counter or shifter
; hl = pointer to mask
initmask:
	push	de
	ex	de,hl
	ld	bc,#20+20
	call	clrmem		; clear work area
	ex	de,hl
	ld	b,#20		; byte counter
	ld	c,#1		; first bit
	ld	d,#0		; bit counter
imlp:	ld	e,(hl)
imlp1:	ld	a,e
	and	c
	jp	z,imlp2
	inc	d
imlp2:	ld	a,c
	rlca
	ld	c,a
	cp	#1
	jp	nz,imlp1
	inc	hl
	dec	b
	jp	nz,imlp
; got number of 1-bits in mask in reg d
	ld	a,d
	and	#0xf8
	rrca
	rrca
	rrca			; divide by 8 (get byte offset)
	ld	l,a
	ld	h,#0
	ld	a,d
	and	#7		; bit offset
	inc	a
	ld	b,a
	ld	a,#0x80
imlp3:	rlca
	dec	b
	jp	nz,imlp3
	pop	de
	add	hl,de
	ld	de,#20
	add	hl,de
	ld	(hl),a
	ret

; multi-byte counter
count:	push	bc
	push	de
	push	hl
	ld	hl,#counter	; 20 byte counter starts here
	ld	de,#20		; somewhere in here is the stop bit
	ex	de,hl
	add	hl,de
	ex	de,hl
cntlp:	inc	(hl)
	ld	a,(hl)
	cp	#0
	jp	z,cntlp1	; overflow to next byte
	ld	b,a
	ld	a,(de)
	and	b		; test for terminal value
	jp	z,cntend
	ld	(hl),#0		; reset to zero
cntend:	pop	bc
	pop	de
	pop	hl
	ret

cntlp1:	inc	hl
	inc	de
	jp	cntlp

; multi-byte shifter
shift:	push	bc
	push	de
	push	hl
	ld	hl,#shifter	; 20 byte shift register starts here
	ld	de,#20		; somewhere in here is the stop bit
	ex	de,hl
	add	hl,de
	ex	de,hl
shflp:	ld	a,(hl)
	or	a
	jp	z,shflp1
	ld	b,a
	ld	a,(de)
	and	b
	jp	nz,shlpe
	ld	a,b
	rlca
	cp	#1
	jp	nz,shflp2
	ld	(hl),#0
	inc	hl
	inc	de
shflp2:	ld	(hl),a
	xor	a		; set Z
shlpe:	pop	hl
	pop	de
	pop	bc
	ret
shflp1:	inc	hl
	inc	de
	jp	shflp

; The test harness. Runs from RAM at test: so stt can patch iut and flgmsk.
test_rom:
	push	af
	push	bc
	push	de
	push	hl
	di			; disable interrupts
	ld	(spsav),sp	; save stack pointer
	ld	sp,#msbt+2	; point to test-case machine state
	pop	iy		; and load all regs
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ld	sp,(spbt)
iut_rom:
	.db	0,0,0,0		; max 4 byte instruction under test
	ld	(spat),sp	; save stack pointer
	ld	sp,#spat
	push	af		; save other registers
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	sp,(spsav)	; restore stack pointer
	ei			; enable interrupts
	ld	hl,(msbt)	; copy memory operand
	ld	(msat),hl
	ld	hl,#flgsat	; flags after test
	ld	a,(hl)
flgmsk_rom:
	and	#0xd7		; mask-out irrelevant bits (self-modified code!)
	ld	(hl),a
	ld	b,#16		; total of 16 bytes of state
	ld	de,#msat
	ld	hl,#crcval
tcrc:	ld	a,(de)
	inc	de
	call	updcrc		; accumulate crc of this test case
	dec	b
	jr	nz,tcrc
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret
test_rom_end:

; compare crc
; hl points to value to compare to crcval
cmpcrc:	push	bc
	push	de
	push	hl
	ld	de,#crcval
	ld	b,#4
cclp:	ld	a,(de)
	cp	(hl)
	jp	nz,cce
	inc	hl
	inc	de
	dec	b
	jp	nz,cclp
cce:	pop	hl
	pop	de
	pop	bc
	ret

; 32-bit crc routine
; entry: a contains next byte, hl points to crc
; exit:  crc updated
updcrc:	push	af
	push	bc
	push	de
	push	hl
	push	hl
	ld	de,#3
	add	hl,de		; point to low byte of old crc
	xor	(hl)		; xor with new byte
	ld	l,a
	ld	h,#0
	add	hl,hl		; use result as index into table of 4 byte entries
	add	hl,hl
	ex	de,hl
	ld	hl,#crctab
	add	hl,de		; point to selected entry in crctab
	ex	de,hl
	pop	hl
	ld	bc,#4		; c = byte count, b = accumulator
crclp:	ld	a,(de)
	xor	b
	ld	b,(hl)
	ld	(hl),a
	inc	de
	inc	hl
	dec	c
	jp	nz,crclp
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

initcrc: push	af
	push	bc
	push	hl
	ld	hl,#crcval
	ld	a,#0xff
	ld	b,#4
icrclp:	ld	(hl),a
	inc	hl
	dec	b
	jp	nz,icrclp
	pop	hl
	pop	bc
	pop	af
	ret

;----------------------------------------------------------------------------
;  Screen output, in place of CP/M's console
;----------------------------------------------------------------------------

; Points the cursor at row d, column e. The playfield is 32 tiles square at
; $8400, scrolled so tile row 2 is the top visible row, and 28 rows and 28
; columns show.
locate:	push	af
	push	hl
	ld	a,d
	add	a,#2
	ld	l,a
	ld	h,#0
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl		; row * 32 leaves the low five bits clear
	ld	a,l
	or	e
	ld	l,a
	ld	a,h
	add	a,#>PLAY_CODE
	ld	h,a
	ld	(cursor),hl
	pop	hl
	pop	af
	ret

; Prints the ASCII character in a at the cursor, in the current colour.
putc:	push	af
	push	de
	push	hl
	call	glyph
	ld	hl,(cursor)
	ld	(hl),a
	ld	de,#ATTR_OFFSET
	add	hl,de
	ld	a,(attr)
	ld	(hl),a
	ld	hl,(cursor)
	inc	hl
	ld	(cursor),hl
	pop	hl
	pop	de
	pop	af
	ret

; ASCII to tile code. The character ROM has upper case, digits and
; -.,!()' at their ASCII codes, and its space at $40.
glyph:	cp	#0x61		; 'a'
	jr	c,1$
	cp	#0x7b		; 'z'+1
	jr	nc,1$
	sub	#0x20
	ret
1$:	cp	#0x20		; ' '
	jr	nz,2$
	ld	a,#BLANK
	ret
2$:	cp	#0x3c		; '<'
	jr	nz,3$
	ld	a,#0x28		; '('
	ret
3$:	cp	#0x3e		; '>'
	ret	nz
	ld	a,#0x29		; ')'
	ret

; Prints the '$'-terminated string at hl. putsn stops after b characters.
puts:	ld	b,#0
putsn:	ld	a,(hl)
	cp	#0x24		; '$'
	ret	z
	call	putc
	inc	hl
	djnz	putsn
	ret

; Prints a (0-99) as two decimal digits.
pdec2:	push	bc
	ld	b,#0x2f		; '0'-1
1$:	inc	b
	sub	#10
	jr	nc,1$
	add	a,#0x3a		; 10+'0'
	ld	c,a
	ld	a,b
	call	putc
	ld	a,c
	call	putc
	pop	bc
	ret

; Prints the big-endian 32-bit value at hl in hex.
phex8:	push	af
	push	bc
	push	hl
	ld	b,#4
1$:	ld	a,(hl)
	call	phex2
	inc	hl
	djnz	1$
	pop	hl
	pop	bc
	pop	af
	ret

phex2:	push	af
	rrca
	rrca
	rrca
	rrca
	call	phex1
	pop	af
phex1:	push	af
	and	#0x0f
	cp	#10
	jr	c,1$
	add	a,#7		; 'A'-'9'-1
1$:	add	a,#0x30		; '0'
	call	putc
	pop	af
	ret

; Row and column of the running test's "NN OK" in d and e.
slot:	push	af
	ld	a,(testnum)
	dec	a
	ld	e,#1
1$:	cp	#17
	jr	c,2$
	sub	#17
	push	af
	ld	a,e
	add	a,#6
	ld	e,a
	pop	af
	jr	1$
2$:	add	a,#ROW_GRID
	ld	d,a
	pop	af
	ret

; Shows the name at de and marks the test as running in the grid.
shownm:	push	de
	ld	hl,#testnum
	inc	(hl)
	ld	de,#ROW_NAME*256+1
	call	locate
	ld	b,#26
1$:	ld	a,#0x20		; ' '
	call	putc
	djnz	1$
	call	locate
	pop	hl
	push	hl
	ld	b,#26
	call	putsn
	call	slot
	call	locate
	ld	a,(testnum)
	call	pdec2
	ld	hl,#runmsg
	call	puts
	pop	de
	ret

; Records the result of the test just run: z set if its crc matched, hl at
; the expected crc.
report:	jr	z,rpass
	push	hl
	ld	hl,#failed
	inc	(hl)
	ld	hl,#ermsg
	call	mark
	ld	de,#ROW_ERROR*256+1
	call	locate
	ld	hl,#lastmsg
	call	puts
	ld	a,(testnum)
	call	pdec2
	ld	de,#(ROW_ERROR+1)*256+1
	call	locate
	ld	hl,#expmsg
	call	puts
	pop	hl
	call	phex8
	ld	de,#(ROW_ERROR+2)*256+1
	call	locate
	ld	hl,#gotmsg
	call	puts
	ld	hl,#crcval
	call	phex8
	jr	counts
rpass:	ld	hl,#passed
	inc	(hl)
	ld	hl,#okmsg
	call	mark
counts:	ld	de,#ROW_COUNTS*256+1
	call	locate
	ld	hl,#passmsg
	call	puts
	ld	a,(passed)
	call	pdec2
	ld	hl,#failmsg
	call	puts
	ld	a,(failed)
	jp	pdec2

; Prints the string at hl after the running test's number in the grid.
mark:	push	hl
	call	slot
	inc	e
	inc	e
	call	locate
	pop	hl
	jp	puts

; Steps the text colour when a control is pressed.
poll:	push	af
	push	bc
	push	de
	push	hl
	ld	a,(IN0)
	or	#0x01		; bit 0 is not a control
	ld	hl,#lastin
	cp	(hl)
	jr	z,1$		; no change
	ld	(hl),a
	inc	a		; $FF, nothing held, becomes 0
	jr	z,1$		; a release
	ld	hl,#attr
	ld	a,(hl)
	inc	a
	and	#0x3f		; bits 6 and 7 would flip the tiles
	ld	(hl),a
	call	paint
1$:	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; Sets every attribute to the current colour.
paint:	ld	a,(attr)
	ld	hl,#VRAM_ATTR
	ld	de,#VRAM_ATTR+1
	ld	bc,#0x07ff
	ld	(hl),a
	ldir
	ret

msg1:	.ascii	"Z80 CPU TEST   ZEXALL$"
msg2:	.ascii	"ALL TESTS DONE$"
runmsg:	.ascii	" ..$"
okmsg:	.ascii	" OK$"
ermsg:	.ascii	" ER$"
passmsg: .ascii	"PASSED $"
failmsg: .ascii	"   FAILED $"
lastmsg: .ascii	"LAST ERROR IN TEST $"
expmsg:	.ascii	"EXPECTED $"
gotmsg:	.ascii	"GOT      $"

tests:
	.dw	adc16
	.dw	add16
	.dw	add16x
	.dw	add16y
	.dw	alu8i
	.dw	alu8r
	.dw	alu8rx
	.dw	alu8x
	.dw	bitx
	.dw	bitz80
	.dw	cpd1
	.dw	cpi1
	.dw	daaop
	.dw	inca
	.dw	incb
	.dw	incbc
	.dw	incc
	.dw	incd
	.dw	incde
	.dw	ince
	.dw	inch
	.dw	inchl
	.dw	incix
	.dw	inciy
	.dw	incl
	.dw	incm
	.dw	incsp
	.dw	incx
	.dw	incxh
	.dw	incxl
	.dw	incyh
	.dw	incyl
	.dw	ld161
	.dw	ld162
	.dw	ld163
	.dw	ld164
	.dw	ld165
	.dw	ld166
	.dw	ld167
	.dw	ld168
	.dw	ld16im
	.dw	ld16ix
	.dw	ld8bd
	.dw	ld8im
	.dw	ld8imx
	.dw	ld8ix1
	.dw	ld8ix2
	.dw	ld8ix3
	.dw	ld8ixy
	.dw	ld8rr
	.dw	ld8rrx
	.dw	lda
	.dw	ldd1
	.dw	ldd2
	.dw	ldi1
	.dw	ldi2
	.dw	negop
	.dw	rldop
	.dw	rot8080
	.dw	rotxy
	.dw	rotz80
	.dw	srz80
	.dw	srzx
	.dw	st8ix1
	.dw	st8ix2
	.dw	st8ix3
	.dw	stabd
	.dw	0

;----------------------------------------------------------------------------
;  Test vectors
;----------------------------------------------------------------------------
;
; Each test is a flag mask, three 20-byte vectors (base case, increment mask,
; shift mask: insn[4], memop, iy, ix, hl, de, bc, flags, a, sp), the expected
; crc, and a 30-character name ending in '$'.

; <adc,sbc> hl,<bc,de,hl,sp> (38,912 cycles)
adc16:	.db	0xff ; flag mask
	.db	0xed,0x42,0,0
	.dw	0x832c,0x4f88,0xf22b,0xb339,0x7e1f,0x1563
	.db	0xd3,0x89
	.dw	0x465e
	.db	0,0x38,0,0 ; (1024 cycles)
	.dw	0,0,0,0xf821,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (38 cycles)
	.dw	0,0,0,0xffff,0xffff,0xffff
	.db	0xd7,0
	.dw	0xffff
	.db	0xd4,0x8a,0xd5,0x19 ; expected crc
	.ascii	"<adc,sbc> hl,<bc,de,hl,sp>...."
	.db	0x24

; add hl,<bc,de,hl,sp> (19,456 cycles)
add16:	.db	0xff ; flag mask
	.db	9,0,0,0
	.dw	0xc4a5,0xc4c7,0xd226,0xa050,0x58ea,0x8566
	.db	0xc6,0xde
	.dw	0x9bc9
	.db	0x30,0,0,0 ; (512 cycles)
	.dw	0,0,0,0xf821,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (38 cycles)
	.dw	0,0,0,0xffff,0xffff,0xffff
	.db	0xd7,0
	.dw	0xffff
	.db	0xd9,0xa4,0xca,0x05 ; expected crc
	.ascii	"add hl,<bc,de,hl,sp>.........."
	.db	0x24

; add ix,<bc,de,ix,sp> (19,456 cycles)
add16x:	.db	0xff ; flag mask
	.db	0xdd,9,0,0
	.dw	0xddac,0xc294,0x635b,0x33d3,0x6a76,0xfa20
	.db	0x94,0x68
	.dw	0x36f5
	.db	0,0x30,0,0 ; (512 cycles)
	.dw	0,0,0xf821,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (38 cycles)
	.dw	0,0,0xffff,0,0xffff,0xffff
	.db	0xd7,0
	.dw	0xffff
	.db	0xb1,0xdf,0x8e,0xc0 ; expected crc
	.ascii	"add ix,<bc,de,ix,sp>.........."
	.db	0x24

; add iy,<bc,de,iy,sp> (19,456 cycles)
add16y:	.db	0xff ; flag mask
	.db	0xfd,9,0,0
	.dw	0xc7c2,0xf407,0x51c1,0x3e96,0x0bf4,0x510f
	.db	0x92,0x1e
	.dw	0x71ea
	.db	0,0x30,0,0 ; (512 cycles)
	.dw	0,0xf821,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (38 cycles)
	.dw	0,0xffff,0,0,0xffff,0xffff
	.db	0xd7,0
	.dw	0xffff
	.db	0x39,0xc8,0x58,0x9b ; expected crc
	.ascii	"add iy,<bc,de,iy,sp>.........."
	.db	0x24

; aluop a,nn (28,672 cycles)
alu8i:	.db	0xff ; flag mask
	.db	0xc6,0,0,0
	.dw	0x9140,0x7e3c,0x7a67,0xdf6d,0x5b61,0x0b29
	.db	0x10,0x66
	.dw	0x85b2
	.db	0x38,0,0,0 ; (2048 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0xff,0,0 ; (14 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x51,0xc1,0x9c,0x2e ; expected crc
	.ascii	"aluop a,nn...................."
	.db	0x24

; aluop a,<b,c,d,e,h,l,(hl),a> (753,664 cycles)
alu8r:	.db	0xff ; flag mask
	.db	0x80,0,0,0
	.dw	0xc53e,0x573a,0x4c4d,msbt,0xe309,0xa666
	.db	0xd0,0x3b
	.dw	0xadbb
	.db	0x3f,0,0,0 ; (16,384 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (46 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0xd7,0
	.dw	0
	.db	0x58,0x63,0x61,0xa3 ; expected crc, from T80 with msbt at $9800
	.ascii	"aluop a,<b,c,d,e,h,l,(hl),a>.."
	.db	0x24

; aluop a,<ixh,ixl,iyh,iyl> (376,832 cycles)
alu8rx:	.db	0xff ; flag mask
	.db	0xdd,0x84,0,0
	.dw	0xd6f7,0xc76e,0xaccf,0x2847,0x22dd,0xc035
	.db	0xc5,0x38
	.dw	0x234b
	.db	0x20,0x39,0,0 ; (8,192 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (46 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0xd7,0
	.dw	0
	.db	0xa8,0x86,0xcc,0x44 ; expected crc
	.ascii	"aluop a,<ixh,ixl,iyh,iyl>....."
	.db	0x24

; aluop a,(<ix,iy>+1) (229,376 cycles)
alu8x:	.db	0xff ; flag mask
	.db	0xdd,0x86,1,0
	.dw	0x90b7,msbt-1,msbt-1,0x32fd,0x406e,0xc1dc
	.db	0x45,0x6e
	.dw	0xe5fa
	.db	0x20,0x38,0,0 ; (16,384 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (14 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xf5,0x34,0xcc,0x90 ; expected crc, from T80 with msbt at $9800
	.ascii	"aluop a,(<ix,iy>+1)..........."
	.db	0x24

; bit n,(<ix,iy>+1) (2048 cycles)
bitx:	.db	0xff ; flag mask
	.db	0xdd,0xcb,1,0x46
	.dw	0x2075,msbt-1,msbt-1,0x3cfc,0xa79a,0x3d74
	.db	0x51,0x27
	.dw	0xca14
	.db	0x20,0,0,0x38 ; (256 cycles)
	.dw	0,0,0,0,0,0
	.db	0x53,0
	.dw	0
	.db	0,0,0,0 ; (8 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xca,0xd9,0xc0,0x69 ; expected crc, from T80 with msbt at $9800
	.ascii	"bit n,(<ix,iy>+1)............."
	.db	0x24

; bit n,<b,c,d,e,h,l,(hl),a> (49,152 cycles)
bitz80:	.db	0xff ; flag mask
	.db	0xcb,0x40,0,0
	.dw	0x3ef1,0x9dfc,0x7acc,msbt,0xbe61,0x7a86
	.db	0x50,0x24
	.dw	0x1998
	.db	0,0x3f,0,0 ; (1024 cycles)
	.dw	0,0,0,0,0,0
	.db	0x53,0
	.dw	0
	.db	0,0,0,0 ; (48 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0,0xff
	.dw	0
	.db	0x2c,0x21,0xab,0xc8 ; expected crc, from T80 with msbt at $9800
	.ascii	"bit n,<b,c,d,e,h,l,(hl),a>...."
	.db	0x24

; cpd<r> (1) (6144 cycles)
cpd1:	.db	0xff ; flag mask
	.db	0xed,0xa9,0,0
	.dw	0xc7b6,0x72b4,0x18f6,msbt+17,0x8dbd,1
	.db	0xc0,0x30
	.dw	0x94a3
	.db	0,0x10,0,0 ; (1024 cycles)
	.dw	0,0,0,0,0,0x000a
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x55,0x39,0xbc,0xf4 ; expected crc, from T80 with msbt at $9800
	.ascii	"cpd<r>........................"
	.db	0x24

; cpi<r> (1) (6144 cycles)
cpi1:	.db	0xff ; flag mask
	.db	0xed,0xa1,0,0
	.dw	0x4d48,0xaf4a,0x906b,msbt,0x4e71,1
	.db	0x93,0x6a
	.dw	0x907c
	.db	0,0x10,0,0 ; (1024 cycles)
	.dw	0,0,0,0,0,0x000a
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x06,0x15,0x57,0xdc ; expected crc, from T80 with msbt at $9800
	.ascii	"cpi<r>........................"
	.db	0x24

; <daa,cpl,scf,ccf>
daaop:	.db	0xff ; flag mask
	.db	0x27,0,0,0
	.dw	0x2141,0x09fa,0x1d60,0xa559,0x8d5b,0x9079
	.db	0x04,0x8e
	.dw	0x299d
	.db	0x18,0,0,0 ; (65,536 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0xff
	.dw	0
	.db	0,0,0,0 ; (1 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x6d,0x2d,0xd2,0x13 ; expected crc
	.ascii	"<daa,cpl,scf,ccf>............."
	.db	0x24

; <inc,dec> a (3072 cycles)
inca:	.db	0xff ; flag mask
	.db	0x3c,0,0,0
	.dw	0x4adf,0xd5d8,0xe598,0x8a2b,0xa7b0,0x431b
	.db	0x44,0x5a
	.dw	0xd030
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x81,0xfa,0x81,0x00 ; expected crc
	.ascii	"<inc,dec> a..................."
	.db	0x24

; <inc,dec> b (3072 cycles)
incb:	.db	0xff ; flag mask
	.db	0x04,0,0,0
	.dw	0xd623,0x432d,0x7a61,0x8180,0x5a86,0x1e85
	.db	0x86,0x58
	.dw	0x9bbb
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0,0,0xff00
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x77,0xf3,0x5a,0x73 ; expected crc
	.ascii	"<inc,dec> b..................."
	.db	0x24

; <inc,dec> bc (1536 cycles)
incbc:	.db	0xff ; flag mask
	.db	0x03,0,0,0
	.dw	0xcd97,0x44ab,0x8dc9,0xe3e3,0x11cc,0xe8a4
	.db	0x02,0x49
	.dw	0x2a4d
	.db	0x08,0,0,0 ; (256 cycles)
	.dw	0,0,0,0,0,0xf821
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xd2,0xae,0x3b,0xec ; expected crc
	.ascii	"<inc,dec> bc.................."
	.db	0x24

; <inc,dec> c (3072 cycles)
incc:	.db	0xff ; flag mask
	.db	0x0c,0,0,0
	.dw	0xd789,0x0935,0x055b,0x9f85,0x8b27,0xd208
	.db	0x95,0x05
	.dw	0x0660
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0,0,0x00ff
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x1a,0xf6,0x12,0xa7 ; expected crc
	.ascii	"<inc,dec> c..................."
	.db	0x24

; <inc,dec> d (3072 cycles)
incd:	.db	0xff ; flag mask
	.db	0x14,0,0,0
	.dw	0xa0ea,0x5fba,0x65fb,0x981c,0x38cc,0xdebc
	.db	0x43,0x5c
	.dw	0x03bd
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0,0xff00,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xd1,0x46,0xbf,0x51 ; expected crc
	.ascii	"<inc,dec> d..................."
	.db	0x24

; <inc,dec> de (1536 cycles)
incde:	.db	0xff ; flag mask
	.db	0x13,0,0,0
	.dw	0x342e,0x131d,0x28c9,0x0aca,0x9967,0x3a2e
	.db	0x92,0xf6
	.dw	0x9d54
	.db	0x08,0,0,0 ; (256 cycles)
	.dw	0,0,0,0,0xf821,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xae,0xc6,0xd4,0x2c ; expected crc
	.ascii	"<inc,dec> de.................."
	.db	0x24

; <inc,dec> e (3072 cycles)
ince:	.db	0xff ; flag mask
	.db	0x1c,0,0,0
	.dw	0x602f,0x4c0d,0x2402,0xe2f5,0xa0f4,0xa10a
	.db	0x13,0x32
	.dw	0x5925
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0,0x00ff,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xca,0x8c,0x6a,0xc2 ; expected crc
	.ascii	"<inc,dec> e..................."
	.db	0x24

; <inc,dec> h (3072 cycles)
inch:	.db	0xff ; flag mask
	.db	0x24,0,0,0
	.dw	0x1506,0xf2eb,0xe8dd,0x262b,0x11a6,0xbc1a
	.db	0x17,0x06
	.dw	0x2818
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0xff00,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x56,0x0f,0x95,0x5e ; expected crc
	.ascii	"<inc,dec> h..................."
	.db	0x24

; <inc,dec> hl (1536 cycles)
inchl:	.db	0xff ; flag mask
	.db	0x23,0,0,0
	.dw	0xc3f4,0x07a5,0x1b6d,0x4f04,0xe2c2,0x822a
	.db	0x57,0xe0
	.dw	0xc3e1
	.db	0x08,0,0,0 ; (256 cycles)
	.dw	0,0,0,0xf821,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xfc,0x0d,0x6d,0x4a ; expected crc
	.ascii	"<inc,dec> hl.................."
	.db	0x24

; <inc,dec> ix (1536 cycles)
incix:	.db	0xff ; flag mask
	.db	0xdd,0x23,0,0
	.dw	0xbc3c,0x0d9b,0xe081,0xadfd,0x9a7f,0x96e5
	.db	0x13,0x85
	.dw	0x0be2
	.db	0,8,0,0 ; (256 cycles)
	.dw	0,0,0xf821,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xa5,0x4d,0xbe,0x31 ; expected crc
	.ascii	"<inc,dec> ix.................."
	.db	0x24

; <inc,dec> iy (1536 cycles)
inciy:	.db	0xff ; flag mask
	.db	0xfd,0x23,0,0
	.dw	0x9402,0x637a,0x3182,0xc65a,0xb2e9,0xabb4
	.db	0x16,0xf2
	.dw	0x6d05
	.db	0,8,0,0 ; (256 cycles)
	.dw	0,0xf821,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x50,0x5d,0x51,0xa3 ; expected crc
	.ascii	"<inc,dec> iy.................."
	.db	0x24

; <inc,dec> l (3072 cycles)
incl:	.db	0xff ; flag mask
	.db	0x2c,0,0,0
	.dw	0x8031,0xa520,0x4356,0xb409,0xf4c1,0xdfa2
	.db	0xd1,0x3c
	.dw	0x3ea2
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0,0,0,0x00ff,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xa0,0xa1,0xb4,0x9f ; expected crc
	.ascii	"<inc,dec> l..................."
	.db	0x24

; <inc,dec> (hl) (3072 cycles)
incm:	.db	0xff ; flag mask
	.db	0x34,0,0,0
	.dw	0xb856,0x0c7c,0xe53e,msbt,0x877e,0xda58
	.db	0x15,0x5c
	.dw	0x1f37
	.db	0x01,0,0,0 ; (512 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xaf,0xca,0xaf,0xb4 ; expected crc, from T80 with msbt at $9800
	.ascii	"<inc,dec> (hl)................"
	.db	0x24

; <inc,dec> sp (1536 cycles)
incsp:	.db	0xff ; flag mask
	.db	0x33,0,0,0
	.dw	0x346f,0xd482,0xd169,0xdeb6,0xa494,0xf476
	.db	0x53,0x02
	.dw	0x855b
	.db	0x08,0,0,0 ; (256 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0xf821
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x5d,0xac,0xd5,0x27 ; expected crc
	.ascii	"<inc,dec> sp.................."
	.db	0x24

; <inc,dec> (<ix,iy>+1) (6144 cycles)
incx:	.db	0xff ; flag mask
	.db	0xdd,0x34,1,0
	.dw	0xfa6e,msbt-1,msbt-1,0x2c28,0x8894,0x5057
	.db	0x16,0x33
	.dw	0x286f
	.db	0x20,1,0,0 ; (1024 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xb4,0x9a,0x23,0xa1 ; expected crc, from T80 with msbt at $9800
	.ascii	"<inc,dec> (<ix,iy>+1)........."
	.db	0x24

; <inc,dec> ixh (3072 cycles)
incxh:	.db	0xff ; flag mask
	.db	0xdd,0x24,0,0
	.dw	0xb838,0x316c,0xc6d4,0x3e01,0x8358,0x15b4
	.db	0x81,0xde
	.dw	0x4259
	.db	0,1,0,0 ; (512 cycles)
	.dw	0,0xff00,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x6f,0x46,0x36,0x62 ; expected crc
	.ascii	"<inc,dec> ixh................."
	.db	0x24

; <inc,dec> ixl (3072 cycles)
incxl:	.db	0xff ; flag mask
	.db	0xdd,0x2c,0,0
	.dw	0x4d14,0x7460,0x76d4,0x06e7,0x32a2,0x213c
	.db	0xd6,0xd7
	.dw	0x99a5
	.db	0,1,0,0 ; (512 cycles)
	.dw	0,0x00ff,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x02,0x7b,0xef,0x2c ; expected crc
	.ascii	"<inc,dec> ixl................."
	.db	0x24

; <inc,dec> iyh (3072 cycles)
incyh:	.db	0xff ; flag mask
	.db	0xdd,0x24,0,0
	.dw	0x2836,0x9f6f,0x9116,0x61b9,0x82cb,0xe219
	.db	0x92,0x73
	.dw	0xa98c
	.db	0,1,0,0 ; (512 cycles)
	.dw	0xff00,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x2d,0x96,0x6c,0xf3 ; expected crc
	.ascii	"<inc,dec> iyh................."
	.db	0x24

; <inc,dec> iyl (3072 cycles)
incyl:	.db	0xff ; flag mask
	.db	0xdd,0x2c,0,0
	.dw	0xd7c6,0x62d5,0xa09e,0x7039,0x3e7e,0x9f12
	.db	0x90,0xd9
	.dw	0x220f
	.db	0,1,0,0 ; (512 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x36,0xc1,0x1e,0x75 ; expected crc
	.ascii	"<inc,dec> iyl................."
	.db	0x24

; ld <bc,de>,(nnnn) (32 cycles)
ld161:	.db	0xff ; flag mask
	.db	0xed,0x4b,msbtlo,msbthi
	.dw	0xf9a8,0xf559,0x93a4,0xf5ed,0x6f96,0xd968
	.db	0x86,0xe6
	.dw	0x4bd8
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x4d,0x45,0xa9,0xac ; expected crc
	.ascii	"ld <bc,de>,(nnnn)............."
	.db	0x24

; ld hl,(nnnn) (16 cycles)
ld162:	.db	0xff ; flag mask
	.db	0x2a,msbtlo,msbthi,0
	.dw	0x9863,0x7830,0x2077,0xb1fe,0xb9fa,0xabb8
	.db	0x04,0x06
	.dw	0x6015
	.db	0,0,0,0 ; (1 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x5f,0x97,0x24,0x87 ; expected crc
	.ascii	"ld hl,(nnnn).................."
	.db	0x24

; ld sp,(nnnn) (16 cycles)
ld163:	.db	0xff ; flag mask
	.db	0xed,0x7b,msbtlo,msbthi
	.dw	0x8dfc,0x57d7,0x2161,0xca18,0xc185,0x27da
	.db	0x83,0x1e
	.dw	0xf460
	.db	0,0,0,0 ; (1 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x7a,0xce,0xa1,0x1b ; expected crc
	.ascii	"ld sp,(nnnn).................."
	.db	0x24

; ld <ix,iy>,(nnnn) (32 cycles)
ld164:	.db	0xff ; flag mask
	.db	0xdd,0x2a,msbtlo,msbthi
	.dw	0xded7,0xa6fa,0xf780,0x244c,0x87de,0xbcc2
	.db	0x16,0x63
	.dw	0x4c96
	.db	0x20,0,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x85,0x8b,0xf1,0x6d ; expected crc
	.ascii	"ld <ix,iy>,(nnnn)............."
	.db	0x24

; ld (nnnn),<bc,de> (64 cycles)
ld165:	.db	0xff ; flag mask
	.db	0xed,0x43,msbtlo,msbthi
	.dw	0x1f98,0x844d,0xe8ac,0xc9ed,0xc95d,0x8f61
	.db	0x80,0x3f
	.dw	0xc7bf
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (32 cycles)
	.dw	0,0,0,0,0xffff,0xffff
	.db	0,0
	.dw	0
	.db	0x64,0x1e,0x87,0x15 ; expected crc
	.ascii	"ld (nnnn),<bc,de>............."
	.db	0x24

; ld (nnnn),hl (16 cycles)
ld166:	.db	0xff ; flag mask
	.db	0x22,msbtlo,msbthi,0
	.dw	0xd003,0x7772,0x7f53,0x3f72,0x64ea,0xe180
	.db	0x10,0x2d
	.dw	0x35e9
	.db	0,0,0,0 ; (1 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0,0,0,0xffff,0,0
	.db	0,0
	.dw	0
	.db	0xa3,0x60,0x8b,0x47 ; expected crc
	.ascii	"ld (nnnn),hl.................."
	.db	0x24

; ld (nnnn),sp (16 cycles)
ld167:	.db	0xff ; flag mask
	.db	0xed,0x73,msbtlo,msbthi
	.dw	0xc0dc,0xd1d6,0xed5a,0xf356,0xafda,0x6ca7
	.db	0x44,0x9f
	.dw	0x3f0a
	.db	0,0,0,0 ; (1 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0xffff
	.db	0x16,0x58,0x5f,0xd7 ; expected crc
	.ascii	"ld (nnnn),sp.................."
	.db	0x24

; ld (nnnn),<ix,iy> (64 cycles)
ld168:	.db	0xff ; flag mask
	.db	0xdd,0x22,msbtlo,msbthi
	.dw	0x6cc3,0x0d91,0x6900,0x8ef8,0xe3d6,0xc3f7
	.db	0xc6,0xd9
	.dw	0xc2df
	.db	0x20,0,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (32 cycles)
	.dw	0,0xffff,0xffff,0,0,0
	.db	0,0
	.dw	0
	.db	0xba,0x10,0x2a,0x6b ; expected crc
	.ascii	"ld (nnnn),<ix,iy>............."
	.db	0x24

; ld <bc,de,hl,sp>,nnnn (64 cycles)
ld16im:	.db	0xff ; flag mask
	.db	1,0,0,0
	.dw	0x5c1c,0x2d46,0x8eb9,0x6078,0x74b1,0xb30e
	.db	0x46,0xd1
	.dw	0x30cc
	.db	0x30,0,0,0 ; (4 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0xff,0xff,0 ; (16 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xde,0x39,0x19,0x69 ; expected crc
	.ascii	"ld <bc,de,hl,sp>,nnnn........."
	.db	0x24

; ld <ix,iy>,nnnn (32 cycles)
ld16ix:	.db	0xff ; flag mask
	.db	0xdd,0x21,0,0
	.dw	0x87e8,0x2006,0xbd12,0xb69b,0x7253,0xa1e5
	.db	0x51,0x13
	.dw	0xf1bd
	.db	0x20,0,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0xff,0xff ; (16 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0x22,0x7d,0xd5,0x25 ; expected crc
	.ascii	"ld <ix,iy>,nnnn..............."
	.db	0x24

; ld a,<(bc),(de)> (44 cycles)
ld8bd:	.db	0xff ; flag mask
	.db	0x0a,0,0,0
	.dw	0xb3a8,0x1d2a,0x7f8e,0x42ac,msbt,msbt
	.db	0xc6,0xb1
	.dw	0xef8e
	.db	0x10,0,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0xd7,0xff
	.dw	0
	.db	0x79,0xbd,0x5f,0xd0 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld a,<(bc),(de)>.............."
	.db	0x24

; ld <b,c,d,e,h,l,(hl),a>,nn (64 cycles)
ld8im:	.db	0xff ; flag mask
	.db	6,0,0,0
	.dw	0xc407,0xf49d,0xd13d,0x0339,0xde89,0x7455
	.db	0x53,0xc0
	.dw	0x5509
	.db	0x38,0,0,0 ; (8 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (8 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0xf1,0xda,0xb5,0x56 ; expected crc
	.ascii	"ld <b,c,d,e,h,l,(hl),a>,nn...."
	.db	0x24

; ld (<ix,iy>+1),nn (32 cycles)
ld8imx:	.db	0xff ; flag mask
	.db	0xdd,0x36,1,0
	.dw	0x1b45,msbt-1,msbt-1,0xd5c1,0x61c7,0xbdc4
	.db	0xc0,0x85
	.dw	0xcd16
	.db	0x20,0,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0xff ; (16 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0x89,0xc5,0x33,0x22 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld (<ix,iy>+1),nn............."
	.db	0x24

; ld <b,c,d,e>,(<ix,iy>+1) (512 cycles)
ld8ix1:	.db	0xff ; flag mask
	.db	0xdd,0x46,1,0
	.dw	0xd016,msbt-1,msbt-1,0x4260,0x7f39,0x0404
	.db	0x97,0x4a
	.dw	0xd085
	.db	0x20,0x18,0,0 ; (32 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xc2,0xa7,0xa6,0xe1 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld <b,c,d,e>,(<ix,iy>+1)......"
	.db	0x24

; ld <h,l>,(<ix,iy>+1) (256 cycles)
ld8ix2:	.db	0xff ; flag mask
	.db	0xdd,0x66,1,0
	.dw	0x84e0,msbt-1,msbt-1,0x9c52,0xa799,0x49b6
	.db	0x93,0x00
	.dw	0xeead
	.db	0x20,0x08,0,0 ; (16 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xee,0x00,0x86,0x56 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld <h,l>,(<ix,iy>+1).........."
	.db	0x24

; ld a,(<ix,iy>+1) (128 cycles)
ld8ix3:	.db	0xff ; flag mask
	.db	0xdd,0x7e,1,0
	.dw	0xd8b6,msbt-1,msbt-1,0xc612,0xdf07,0x9cd0
	.db	0x43,0xa6
	.dw	0xa0e5
	.db	0x20,0,0,0 ; (8 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (16 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xef,0x07,0x18,0x13 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld a,(<ix,iy>+1).............."
	.db	0x24

; ld <ixh,ixl,iyh,iyl>,nn (32 cycles)
ld8ixy:	.db	0xff ; flag mask
	.db	0xdd,0x26,0,0
	.dw	0x3c53,0x4640,0xe179,0x7711,0xc107,0x1afa
	.db	0x81,0xad
	.dw	0x5d9b
	.db	0x20,8,0,0 ; (4 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (8 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0x24,0xe8,0x82,0x8b ; expected crc
	.ascii	"ld <ixh,ixl,iyh,iyl>,nn......."
	.db	0x24

; ld <b,c,d,e,h,l,a>,<b,c,d,e,h,l,a> (3456 cycles)
ld8rr:	.db	0xff ; flag mask
	.db	0x40,0,0,0
	.dw	0x72a4,0xa024,0x61ac,msbt,0x82c7,0x718f
	.db	0x97,0x8f
	.dw	0xef8e
	.db	0x3f,0,0,0 ; (64 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (54 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0xd7,0xff
	.dw	0
	.db	0xe9,0x94,0x9b,0x79 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld <bcdehla>,<bcdehla>........"
	.db	0x24

; ld <b,c,d,e,ixy,a>,<b,c,d,e,ixy,a> (6912 cycles)
ld8rrx:	.db	0xff ; flag mask
	.db	0xdd,0x40,0,0
	.dw	0xbcc5,msbt,msbt,msbt,0x2fc2,0x98c0
	.db	0x83,0x1f
	.dw	0x3bcd
	.db	0x20,0x3f,0,0 ; (128 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (54 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0xd7,0xff
	.dw	0
	.db	0xb3,0x33,0xff,0x5b ; expected crc, from T80 with msbt at $9800
	.ascii	"ld <bcdexya>,<bcdexya>........"
	.db	0x24

; ld a,(nnnn) / ld (nnnn),a (44 cycles)
lda:	.db	0xff ; flag mask
	.db	0x32,msbtlo,msbthi,0
	.dw	0xfd68,0xf4ec,0x44a0,0xb543,0x0653,0xcdba
	.db	0xd2,0x4f
	.dw	0x1fd8
	.db	0x08,0,0,0 ; (2 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0xd7,0xff
	.dw	0
	.db	0xc9,0x26,0x2d,0xe5 ; expected crc
	.ascii	"ld a,(nnnn) / ld (nnnn),a....."
	.db	0x24

; ldd<r> (1) (44 cycles)
ldd1:	.db	0xff ; flag mask
	.db	0xed,0xa8,0,0
	.dw	0x9852,0x68fa,0x66a1,msbt+3,msbt+1,1
	.db	0xc1,0x68
	.dw	0x20b7
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x63,0xbd,0xb5,0x2d ; expected crc, from T80 with msbt at $9800
	.ascii	"ldd<r> (1)...................."
	.db	0x24

; ldd<r> (2) (44 cycles)
ldd2:	.db	0xff ; flag mask
	.db	0xed,0xa8,0,0
	.dw	0xf12e,0xeb2a,0xd5ba,msbt+3,msbt+1,2
	.db	0x47,0xff
	.dw	0xfbe4
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x79,0x37,0x02,0x90 ; expected crc, from T80 with msbt at $9800
	.ascii	"ldd<r> (2)...................."
	.db	0x24

; ldi<r> (1) (44 cycles)
ldi1:	.db	0xff ; flag mask
	.db	0xed,0xa0,0,0
	.dw	0xfe30,0x03cd,0x6058,msbt+2,msbt,1
	.db	0x04,0x60
	.dw	0x2688
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x54,0xcb,0x8c,0x5d ; expected crc, from T80 with msbt at $9800
	.ascii	"ldi<r> (1)...................."
	.db	0x24

; ldi<r> (2) (44 cycles)
ldi2:	.db	0xff ; flag mask
	.db	0xed,0xa0,0,0
	.dw	0x4ace,0xc26e,0xb188,msbt+2,msbt,2
	.db	0x14,0x2d
	.dw	0xa39f
	.db	0,0x10,0,0 ; (2 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (22 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0xa1,0x00,0x01,0x0c ; expected crc, from T80 with msbt at $9800
	.ascii	"ldi<r> (2)...................."
	.db	0x24

; neg (16,384 cycles)
negop:	.db	0xff ; flag mask
	.db	0xed,0x44,0,0
	.dw	0x38a2,0x5f6b,0xd934,0x57e4,0xd2d6,0x4642
	.db	0x43,0x5a
	.dw	0x09cc
	.db	0,0,0,0 ; (16,384 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0xff
	.dw	0
	.db	0,0,0,0 ; (1 cycle)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0xd6,0x38,0xdd,0x6a ; expected crc
	.ascii	"neg..........................."
	.db	0x24

; <rld,rrd> (7168 cycles)
rldop:	.db	0xff ; flag mask
	.db	0xed,0x67,0,0
	.dw	0x91cb,0xc48b,0xfa62,msbt,0xe720,0xb479
	.db	0x40,0x06
	.dw	0x8ae2
	.db	0,8,0,0 ; (512 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (14 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0xff
	.dw	0
	.db	0x64,0xd8,0xea,0x20 ; expected crc, from T80 with msbt at $9800
	.ascii	"<rrd,rld>....................."
	.db	0x24

; <rlca,rrca,rla,rra> (6144 cycles)
rot8080:	.db	0xff ; flag mask
	.db	7,0,0,0
	.dw	0xcb92,0x6d43,0x0a90,0xc284,0x0c53,0xf50e
	.db	0x91,0xeb
	.dw	0x40fc
	.db	0x18,0,0,0 ; (1024 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0,0,0,0 ; (6 cycles)
	.dw	0,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x9b,0xa3,0x80,0x7c ; expected crc
	.ascii	"<rlca,rrca,rla,rra>..........."
	.db	0x24

; shift/rotate (<ix,iy>+1) (416 cycles)
rotxy:	.db	0xff ; flag mask
	.db	0xdd,0xcb,1,6
	.dw	0xddaf,msbt-1,msbt-1,0xff3c,0xdbf6,0x94f4
	.db	0x82,0x80
	.dw	0x61d9
	.db	0x20,0,0,0x38 ; (32 cycles)
	.dw	0,0,0,0,0,0
	.db	0x80,0
	.dw	0
	.db	0,0,0,0 ; (13 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0x57,0
	.dw	0
	.db	0x69,0xe7,0x33,0x5d ; expected crc, from T80 with msbt at $9800
	.ascii	"shf/rot (<ix,iy>+1)..........."
	.db	0x24

; shift/rotate <b,c,d,e,h,l,(hl),a> (6784 cycles)
rotz80:	.db	0xff ; flag mask
	.db	0xcb,0,0,0
	.dw	0xcceb,0x5d4a,0xe007,msbt,0x1395,0x30ee
	.db	0x43,0x78
	.dw	0x3dad
	.db	0,0x3f,0,0 ; (128 cycles)
	.dw	0,0,0,0,0,0
	.db	0x80,0
	.dw	0
	.db	0,0,0,0 ; (53 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0x57,0xff
	.dw	0
	.db	0x18,0xd6,0x4b,0xa8 ; expected crc, from T80 with msbt at $9800
	.ascii	"shf/rot <b,c,d,e,h,l,(hl),a>.."
	.db	0x24

; <set,res> n,<b,c,d,e,h,l,(hl),a> (7936 cycles)
srz80:	.db	0xff ; flag mask
	.db	0xcb,0x80,0,0
	.dw	0x2cd5,0x97ab,0x39ff,msbt,0xd14b,0x6ab2
	.db	0x53,0x27
	.dw	0xb538
	.db	0,0x7f,0,0 ; (128 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (62 cycles)
	.dw	0x00ff,0,0,0,0xffff,0xffff
	.db	0xd7,0xff
	.dw	0
	.db	0xb9,0xf2,0xb2,0x02 ; expected crc, from T80 with msbt at $9800
	.ascii	"<set,res> n,<bcdehl(hl)a>....."
	.db	0x24

; <set,res> n,(<ix,iy>+1) (1792 cycles)
srzx:	.db	0xff ; flag mask
	.db	0xdd,0xcb,1,0x86
	.dw	0xfb44,msbt-1,msbt-1,0xba09,0x68be,0x32d8
	.db	0x10,0x5e
	.dw	0xa867
	.db	0x20,0,0,0x78 ; (128 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ;(14 cycles)
	.dw	0x00ff,0,0,0,0,0
	.db	0xd7,0
	.dw	0
	.db	0x93,0x74,0x11,0x31 ; expected crc, from T80 with msbt at $9800
	.ascii	"<set,res> n,(<ix,iy>+1)......."
	.db	0x24

; ld (<ix,iy>+1),<b,c,d,e> (1024 cycles)
st8ix1:	.db	0xff ; flag mask
	.db	0xdd,0x70,1,0
	.dw	0x270d,msbt-1,msbt-1,0xb73a,0x887b,0x99ee
	.db	0x86,0x70
	.dw	0xca07
	.db	0x20,0x03,0,0 ; (32 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (32 cycles)
	.dw	0,0,0,0,0xffff,0xffff
	.db	0,0
	.dw	0
	.db	0xc5,0x50,0x11,0x6f ; expected crc, from T80 with msbt at $9800
	.ascii	"ld (<ix,iy>+1),<b,c,d,e>......"
	.db	0x24

; ld (<ix,iy>+1),<h,l> (256 cycles)
st8ix2:	.db	0xff ; flag mask
	.db	0xdd,0x74,1,0
	.dw	0xb664,msbt-1,msbt-1,0xe8ac,0xb5f5,0xaafe
	.db	0x12,0x10
	.dw	0x9566
	.db	0x20,0x01,0,0 ; (16 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (32 cycles)
	.dw	0,0,0,0xffff,0,0
	.db	0,0
	.dw	0
	.db	0xa4,0xc5,0xb9,0xde ; expected crc, from T80 with msbt at $9800
	.ascii	"ld (<ix,iy>+1),<h,l>.........."
	.db	0x24

; ld (<ix,iy>+1),a (64 cycles)
st8ix3:	.db	0xff ; flag mask
	.db	0xdd,0x77,1,0
	.dw	0x67af,msbt-1,msbt-1,0x4f13,0x0644,0xbcd7
	.db	0x50,0xac
	.dw	0x5faf
	.db	0x20,0,0,0 ; (8 cycles)
	.dw	0,1,1,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (8 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0x98,0xe0,0x10,0x90 ; expected crc, from T80 with msbt at $9800
	.ascii	"ld (<ix,iy>+1),a.............."
	.db	0x24

; ld (<bc,de>),a (96 cycles)
stabd:	.db	0xff ; flag mask
	.db	2,0,0,0
	.dw	0x0c3b,0xb592,0x6cff,0x959e,msbt,msbt+1
	.db	0xc1,0x21
	.dw	0xbde7
	.db	0x18,0,0,0 ; (4 cycles)
	.dw	0,0,0,0,0,0
	.db	0,0
	.dw	0
	.db	0,0,0,0 ; (24 cycles)
	.dw	0xffff,0,0,0,0,0
	.db	0,0xff
	.dw	0
	.db	0xe2,0x3f,0x9a,0xce ; expected crc, from T80 with msbt at $9800
	.ascii	"ld (<bc,de>),a................"
	.db	0x24


;----------------------------------------------------------------------------
;  CRC-32 table
;----------------------------------------------------------------------------

crctab:
	.db	0x00,0x00,0x00,0x00
	.db	0x77,0x07,0x30,0x96
	.db	0xee,0x0e,0x61,0x2c
	.db	0x99,0x09,0x51,0xba
	.db	0x07,0x6d,0xc4,0x19
	.db	0x70,0x6a,0xf4,0x8f
	.db	0xe9,0x63,0xa5,0x35
	.db	0x9e,0x64,0x95,0xa3
	.db	0x0e,0xdb,0x88,0x32
	.db	0x79,0xdc,0xb8,0xa4
	.db	0xe0,0xd5,0xe9,0x1e
	.db	0x97,0xd2,0xd9,0x88
	.db	0x09,0xb6,0x4c,0x2b
	.db	0x7e,0xb1,0x7c,0xbd
	.db	0xe7,0xb8,0x2d,0x07
	.db	0x90,0xbf,0x1d,0x91
	.db	0x1d,0xb7,0x10,0x64
	.db	0x6a,0xb0,0x20,0xf2
	.db	0xf3,0xb9,0x71,0x48
	.db	0x84,0xbe,0x41,0xde
	.db	0x1a,0xda,0xd4,0x7d
	.db	0x6d,0xdd,0xe4,0xeb
	.db	0xf4,0xd4,0xb5,0x51
	.db	0x83,0xd3,0x85,0xc7
	.db	0x13,0x6c,0x98,0x56
	.db	0x64,0x6b,0xa8,0xc0
	.db	0xfd,0x62,0xf9,0x7a
	.db	0x8a,0x65,0xc9,0xec
	.db	0x14,0x01,0x5c,0x4f
	.db	0x63,0x06,0x6c,0xd9
	.db	0xfa,0x0f,0x3d,0x63
	.db	0x8d,0x08,0x0d,0xf5
	.db	0x3b,0x6e,0x20,0xc8
	.db	0x4c,0x69,0x10,0x5e
	.db	0xd5,0x60,0x41,0xe4
	.db	0xa2,0x67,0x71,0x72
	.db	0x3c,0x03,0xe4,0xd1
	.db	0x4b,0x04,0xd4,0x47
	.db	0xd2,0x0d,0x85,0xfd
	.db	0xa5,0x0a,0xb5,0x6b
	.db	0x35,0xb5,0xa8,0xfa
	.db	0x42,0xb2,0x98,0x6c
	.db	0xdb,0xbb,0xc9,0xd6
	.db	0xac,0xbc,0xf9,0x40
	.db	0x32,0xd8,0x6c,0xe3
	.db	0x45,0xdf,0x5c,0x75
	.db	0xdc,0xd6,0x0d,0xcf
	.db	0xab,0xd1,0x3d,0x59
	.db	0x26,0xd9,0x30,0xac
	.db	0x51,0xde,0x00,0x3a
	.db	0xc8,0xd7,0x51,0x80
	.db	0xbf,0xd0,0x61,0x16
	.db	0x21,0xb4,0xf4,0xb5
	.db	0x56,0xb3,0xc4,0x23
	.db	0xcf,0xba,0x95,0x99
	.db	0xb8,0xbd,0xa5,0x0f
	.db	0x28,0x02,0xb8,0x9e
	.db	0x5f,0x05,0x88,0x08
	.db	0xc6,0x0c,0xd9,0xb2
	.db	0xb1,0x0b,0xe9,0x24
	.db	0x2f,0x6f,0x7c,0x87
	.db	0x58,0x68,0x4c,0x11
	.db	0xc1,0x61,0x1d,0xab
	.db	0xb6,0x66,0x2d,0x3d
	.db	0x76,0xdc,0x41,0x90
	.db	0x01,0xdb,0x71,0x06
	.db	0x98,0xd2,0x20,0xbc
	.db	0xef,0xd5,0x10,0x2a
	.db	0x71,0xb1,0x85,0x89
	.db	0x06,0xb6,0xb5,0x1f
	.db	0x9f,0xbf,0xe4,0xa5
	.db	0xe8,0xb8,0xd4,0x33
	.db	0x78,0x07,0xc9,0xa2
	.db	0x0f,0x00,0xf9,0x34
	.db	0x96,0x09,0xa8,0x8e
	.db	0xe1,0x0e,0x98,0x18
	.db	0x7f,0x6a,0x0d,0xbb
	.db	0x08,0x6d,0x3d,0x2d
	.db	0x91,0x64,0x6c,0x97
	.db	0xe6,0x63,0x5c,0x01
	.db	0x6b,0x6b,0x51,0xf4
	.db	0x1c,0x6c,0x61,0x62
	.db	0x85,0x65,0x30,0xd8
	.db	0xf2,0x62,0x00,0x4e
	.db	0x6c,0x06,0x95,0xed
	.db	0x1b,0x01,0xa5,0x7b
	.db	0x82,0x08,0xf4,0xc1
	.db	0xf5,0x0f,0xc4,0x57
	.db	0x65,0xb0,0xd9,0xc6
	.db	0x12,0xb7,0xe9,0x50
	.db	0x8b,0xbe,0xb8,0xea
	.db	0xfc,0xb9,0x88,0x7c
	.db	0x62,0xdd,0x1d,0xdf
	.db	0x15,0xda,0x2d,0x49
	.db	0x8c,0xd3,0x7c,0xf3
	.db	0xfb,0xd4,0x4c,0x65
	.db	0x4d,0xb2,0x61,0x58
	.db	0x3a,0xb5,0x51,0xce
	.db	0xa3,0xbc,0x00,0x74
	.db	0xd4,0xbb,0x30,0xe2
	.db	0x4a,0xdf,0xa5,0x41
	.db	0x3d,0xd8,0x95,0xd7
	.db	0xa4,0xd1,0xc4,0x6d
	.db	0xd3,0xd6,0xf4,0xfb
	.db	0x43,0x69,0xe9,0x6a
	.db	0x34,0x6e,0xd9,0xfc
	.db	0xad,0x67,0x88,0x46
	.db	0xda,0x60,0xb8,0xd0
	.db	0x44,0x04,0x2d,0x73
	.db	0x33,0x03,0x1d,0xe5
	.db	0xaa,0x0a,0x4c,0x5f
	.db	0xdd,0x0d,0x7c,0xc9
	.db	0x50,0x05,0x71,0x3c
	.db	0x27,0x02,0x41,0xaa
	.db	0xbe,0x0b,0x10,0x10
	.db	0xc9,0x0c,0x20,0x86
	.db	0x57,0x68,0xb5,0x25
	.db	0x20,0x6f,0x85,0xb3
	.db	0xb9,0x66,0xd4,0x09
	.db	0xce,0x61,0xe4,0x9f
	.db	0x5e,0xde,0xf9,0x0e
	.db	0x29,0xd9,0xc9,0x98
	.db	0xb0,0xd0,0x98,0x22
	.db	0xc7,0xd7,0xa8,0xb4
	.db	0x59,0xb3,0x3d,0x17
	.db	0x2e,0xb4,0x0d,0x81
	.db	0xb7,0xbd,0x5c,0x3b
	.db	0xc0,0xba,0x6c,0xad
	.db	0xed,0xb8,0x83,0x20
	.db	0x9a,0xbf,0xb3,0xb6
	.db	0x03,0xb6,0xe2,0x0c
	.db	0x74,0xb1,0xd2,0x9a
	.db	0xea,0xd5,0x47,0x39
	.db	0x9d,0xd2,0x77,0xaf
	.db	0x04,0xdb,0x26,0x15
	.db	0x73,0xdc,0x16,0x83
	.db	0xe3,0x63,0x0b,0x12
	.db	0x94,0x64,0x3b,0x84
	.db	0x0d,0x6d,0x6a,0x3e
	.db	0x7a,0x6a,0x5a,0xa8
	.db	0xe4,0x0e,0xcf,0x0b
	.db	0x93,0x09,0xff,0x9d
	.db	0x0a,0x00,0xae,0x27
	.db	0x7d,0x07,0x9e,0xb1
	.db	0xf0,0x0f,0x93,0x44
	.db	0x87,0x08,0xa3,0xd2
	.db	0x1e,0x01,0xf2,0x68
	.db	0x69,0x06,0xc2,0xfe
	.db	0xf7,0x62,0x57,0x5d
	.db	0x80,0x65,0x67,0xcb
	.db	0x19,0x6c,0x36,0x71
	.db	0x6e,0x6b,0x06,0xe7
	.db	0xfe,0xd4,0x1b,0x76
	.db	0x89,0xd3,0x2b,0xe0
	.db	0x10,0xda,0x7a,0x5a
	.db	0x67,0xdd,0x4a,0xcc
	.db	0xf9,0xb9,0xdf,0x6f
	.db	0x8e,0xbe,0xef,0xf9
	.db	0x17,0xb7,0xbe,0x43
	.db	0x60,0xb0,0x8e,0xd5
	.db	0xd6,0xd6,0xa3,0xe8
	.db	0xa1,0xd1,0x93,0x7e
	.db	0x38,0xd8,0xc2,0xc4
	.db	0x4f,0xdf,0xf2,0x52
	.db	0xd1,0xbb,0x67,0xf1
	.db	0xa6,0xbc,0x57,0x67
	.db	0x3f,0xb5,0x06,0xdd
	.db	0x48,0xb2,0x36,0x4b
	.db	0xd8,0x0d,0x2b,0xda
	.db	0xaf,0x0a,0x1b,0x4c
	.db	0x36,0x03,0x4a,0xf6
	.db	0x41,0x04,0x7a,0x60
	.db	0xdf,0x60,0xef,0xc3
	.db	0xa8,0x67,0xdf,0x55
	.db	0x31,0x6e,0x8e,0xef
	.db	0x46,0x69,0xbe,0x79
	.db	0xcb,0x61,0xb3,0x8c
	.db	0xbc,0x66,0x83,0x1a
	.db	0x25,0x6f,0xd2,0xa0
	.db	0x52,0x68,0xe2,0x36
	.db	0xcc,0x0c,0x77,0x95
	.db	0xbb,0x0b,0x47,0x03
	.db	0x22,0x02,0x16,0xb9
	.db	0x55,0x05,0x26,0x2f
	.db	0xc5,0xba,0x3b,0xbe
	.db	0xb2,0xbd,0x0b,0x28
	.db	0x2b,0xb4,0x5a,0x92
	.db	0x5c,0xb3,0x6a,0x04
	.db	0xc2,0xd7,0xff,0xa7
	.db	0xb5,0xd0,0xcf,0x31
	.db	0x2c,0xd9,0x9e,0x8b
	.db	0x5b,0xde,0xae,0x1d
	.db	0x9b,0x64,0xc2,0xb0
	.db	0xec,0x63,0xf2,0x26
	.db	0x75,0x6a,0xa3,0x9c
	.db	0x02,0x6d,0x93,0x0a
	.db	0x9c,0x09,0x06,0xa9
	.db	0xeb,0x0e,0x36,0x3f
	.db	0x72,0x07,0x67,0x85
	.db	0x05,0x00,0x57,0x13
	.db	0x95,0xbf,0x4a,0x82
	.db	0xe2,0xb8,0x7a,0x14
	.db	0x7b,0xb1,0x2b,0xae
	.db	0x0c,0xb6,0x1b,0x38
	.db	0x92,0xd2,0x8e,0x9b
	.db	0xe5,0xd5,0xbe,0x0d
	.db	0x7c,0xdc,0xef,0xb7
	.db	0x0b,0xdb,0xdf,0x21
	.db	0x86,0xd3,0xd2,0xd4
	.db	0xf1,0xd4,0xe2,0x42
	.db	0x68,0xdd,0xb3,0xf8
	.db	0x1f,0xda,0x83,0x6e
	.db	0x81,0xbe,0x16,0xcd
	.db	0xf6,0xb9,0x26,0x5b
	.db	0x6f,0xb0,0x77,0xe1
	.db	0x18,0xb7,0x47,0x77
	.db	0x88,0x08,0x5a,0xe6
	.db	0xff,0x0f,0x6a,0x70
	.db	0x66,0x06,0x3b,0xca
	.db	0x11,0x01,0x0b,0x5c
	.db	0x8f,0x65,0x9e,0xff
	.db	0xf8,0x62,0xae,0x69
	.db	0x61,0x6b,0xff,0xd3
	.db	0x16,0x6c,0xcf,0x45
	.db	0xa0,0x0a,0xe2,0x78
	.db	0xd7,0x0d,0xd2,0xee
	.db	0x4e,0x04,0x83,0x54
	.db	0x39,0x03,0xb3,0xc2
	.db	0xa7,0x67,0x26,0x61
	.db	0xd0,0x60,0x16,0xf7
	.db	0x49,0x69,0x47,0x4d
	.db	0x3e,0x6e,0x77,0xdb
	.db	0xae,0xd1,0x6a,0x4a
	.db	0xd9,0xd6,0x5a,0xdc
	.db	0x40,0xdf,0x0b,0x66
	.db	0x37,0xd8,0x3b,0xf0
	.db	0xa9,0xbc,0xae,0x53
	.db	0xde,0xbb,0x9e,0xc5
	.db	0x47,0xb2,0xcf,0x7f
	.db	0x30,0xb5,0xff,0xe9
	.db	0xbd,0xbd,0xf2,0x1c
	.db	0xca,0xba,0xc2,0x8a
	.db	0x53,0xb3,0x93,0x30
	.db	0x24,0xb4,0xa3,0xa6
	.db	0xba,0xd0,0x36,0x05
	.db	0xcd,0xd7,0x06,0x93
	.db	0x54,0xde,0x57,0x29
	.db	0x23,0xd9,0x67,0xbf
	.db	0xb3,0x66,0x7a,0x2e
	.db	0xc4,0x61,0x4a,0xb8
	.db	0x5d,0x68,0x1b,0x02
	.db	0x2a,0x6f,0x2b,0x94
	.db	0xb4,0x0b,0xbe,0x37
	.db	0xc3,0x0c,0x8e,0xa1
	.db	0x5a,0x05,0xdf,0x1b
	.db	0x2d,0x02,0xef,0x8d
