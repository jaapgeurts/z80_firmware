CF_DATA    equ 0x60
CF_ERRFT   equ 0x61
CF_SECCNT  equ 0x62
CF_LBA0    equ 0x63
CF_LBA1    equ 0x64
CF_LBA2    equ 0x65
CF_LBA3    equ 0x66
CF_STATCMD equ 0x67

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


  org 0x8000

  push hl
  push bc

  ld   hl,welcome_msg
  rst  PRINTK

  ld   a,0x04 ; reset
  out  (CF_STATCMD),a ;  
  call LOOP_BUSY

  ld   a,0xe0 ; lba3=0, master,mode=lba
  out  (CF_LBA3),a
  
  ld   a,0x01      ; set 8 bit
  out  (CF_ERRFT),a
  
  call LOOP_BUSY
  ld   a,0xef
  out  (CF_STATCMD),a ; enable the 8 bit feature

  ld   a,'1'
  rst  PUTC

  ; read 512 bytes (= 1sector)
  call LOOP_BUSY
  ld   a,0x01
  out  (CF_SECCNT),a

  call LOOP_BUSY
  ld   a,0 ; read sector 0
  out  (CF_LBA0),a

  call LOOP_BUSY
  ld   a,0 ; read sector 0
  out  (CF_LBA1),a

  call LOOP_BUSY
  ld   a,0 ; read sector 0
  out  (CF_LBA2),a

  call LOOP_BUSY
  ld   a,0xe0   ; lba mode
  out  (CF_LBA3),a

  ld   a,'2'
  rst  PUTC


CF_RD_CMD:
  call  LOOP_CMD_RDY
  ld   a,'.'
  rst  PUTC
  ; issue read command
  ld   a, 0x20 
  ;ld   a, 0xec  ; $ec = drive id
  out  (CF_STATCMD),a
  call LOOP_DAT_RDY
  IN		A,(CF_STATCMD)					;Read status
  AND		%00000001					;mask off error bit
  JP		NZ,CF_RD_CMD				;Try again if error

  ld   a,'3'
  rst  PUTC

  ld   bc,0x0200
again:
  call LOOP_DAT_RDY
  in   a,(CF_DATA)
  rst PUTC
  ld   a,c
  dec  bc
  ld   a,c
  and  0b00011111
  cp   0
  jr   nz,cont
  ld   a,10
  rst  PUTC
  ld   a,13
  rst  PUTC
cont:
  ld   a,c
  cp   0
  jr   nz, again  
  ld   a,b
  cp   0
  jr   nz, again

  pop  bc
  pop  hl
  ret

LOOP_BUSY:
	IN		A, (CF_STATCMD)					;Read status
	AND		0b10000000					;Mask busy bit
	JP		NZ,LOOP_BUSY				;Loop until busy(7) is 0
	RET
  
LOOP_CMD_RDY:
	IN		A,(CF_STATCMD)					;Read status
    and		0b11000000					;mask off busy and rdy bits
	XOR		0b01000000					;we want busy(7) to be 0 and drvrdy(6) to be 1
	JP		NZ,LOOP_CMD_RDY
	RET

LOOP_DAT_RDY:
	IN		A,(CF_STATCMD)					;Read status
	AND		0b10001000					;mask off busy and drq bits
	XOR		0b00001000					;we want busy(7) to be 0 and drq(3) to be 1
	JP		NZ,LOOP_DAT_RDY
	RET

printhex:
  push af
  srl a
  srl a
  srl a
  srl a
  call printhex_nibble
  pop af
  call printhex_nibble
  ret

printhex_nibble: ; converts a nibble to hex char
  push bc
  push hl
  ld   hl,hexconv_table
  and  0x0F ; take bottom nibble only
  ld   b,0
  ld   c,a
  adc  hl,bc
  ld   a,(hl)
printhex_end:
  rst PUTC
  pop hl
  pop bc
  ret

welcome_msg: ascii 20,"Compact Flash Test",CR,LF
hexconv_table:    db "0123456789ABCDEF"
