
CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

READFILE equ 0x002b ; 

INIT_COMPACTFLASH equ 0x003b
INIT_FAT          equ INIT_COMPACTFLASH+3

STATFILE  equ 0x0028


  org 0x5000

  push hl
  push bc
  push de

  ld   hl,welcome_msg
  rst  PRINTK

;  ld  a,'1'
;  rst PUTC

  ;; init sd card
  call INIT_COMPACTFLASH

;  ld  a,'2'
;  rst PUTC

  ;; init FAT
  call INIT_FAT

;  ld  a,'3'
;  rst PUTC

  ld	hl,0x0000 ; start at the beginning
  ld	(file_count), hl
  ld	(total_size), hl
  ld	(total_size+2), hl

  ld   a,0 ; last action succeeded

  rst STATFILE

.next:
  call printlnz

  ld   hl,0x0000
  ld   a,1
  rst  STATFILE
  cp   0xff
  jr   nz,.next

  ld   hl, fname
  ld   a,0 ; read whole file
  ld   de,0x8000

  call READFILE
  jr   nz,.error2

 cp   0
  jr   nz,.error1
  ld   hl,msg_start
  rst  PRINTK

  ld   a,b
  call printhex
  ld   a,c
  call printhex


  jr   .end
  call 0x8000
  jr   .end
.error1:
  ld   hl,msg_loaderr
  rst  PRINTK
  jr   .end
.error2:
  ld   hl,msg_loaderr2
  rst  PRINTK

.end:
  pop  de
  pop  bc
  pop  hl
  ret

; pointer in hl
printlnz:
  ld   a,(hl)
  cp   0
  jr   z, .done:
  rst  PUTC
  inc  hl
  jr   printlnz
.done:
  ld   a,CR
  rst  PUTC
  ld   a,LF
  rst  PUTC
  ret

printhex:
  push af
  srl  a
  srl  a
  srl  a
  srl  a
  call printhex_nibble
  pop  af
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
  rst  PUTC
  pop hl
  pop bc
  ret

welcome_msg:    db 12,"Disk Test.",CR,LF
msg_loaderr:    db 15,"loading err 1",CR,LF
msg_loaderr2:   db 15,"loading err 2",CR,LF
msg_start:      db 10,"starting",CR,LF
hexconv_table:  db "0123456789ABCDEF"
fname:          db "NEWS.TXT",0
; Ls vars
file_count:		db 1
total_size:		dw 2

