TFT_C equ 0xA0
TFT_D equ 0xA1

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
  
  ld   a,0x01   ; reset TFT display
  out  (TFT_C),a

  ld   b,0xff
delay1:
  djnz  delay1


  ld   a,0xd3h  ; read id
  out  (TFT_C),a
  in   a,(TFT_D); dummy data
  in   a,(TFT_D) ; not relevant
  in   a,(TFT_D)
  call printhex
  in   a,(TFT_D)
  call printhex

  ld   a,0x28  ; dpy off
  out  (TFT_C),a

  ld   a,0x11   ; wake up
  out  (TFT_C),a



; initialization table
;   ld   a,0xc0
;   out  (TFT_C),a
;   ld   a,0x10
;   out (TFT_D),a
;   out (TFT_D),a
;
;   ld   a,0xc1
;   out  (TFT_C),a
;   ld   a,0x41
;   out (TFT_D),a
;
;   ld   a,0xc5
;   out  (TFT_C),a
;   ld   a,0x00
;   out (TFT_D),a
;   ld   a,0x22
;   out (TFT_D),a
;   ld   a,0x80
;   out (TFT_D),a
;   ld   a,0x40
;   out (TFT_D),a
;
;   ld   a,0xb0
;   out  (TFT_C),a
;   ld   a,0x00
;   out (TFT_D),a
;
;   ld   a,0xb1
;   out  (TFT_C),a
;   ld   a,0xb0
;   out (TFT_D),a
;   ld   a,0x11
;   out (TFT_D),a
;
;   ld   a,0xb4
;   out  (TFT_C),a
;   ld   a,0x02
;   out (TFT_D),a
;
;   ld   a,0xb6
;   out  (TFT_C),a
;   ld   a,0x02
;   out (TFT_D),a
;   out (TFT_D),a
;   ld   a,0x3b
;   out (TFT_D),a
;
;   ld   a,0xb7
;   out  (TFT_C),a
;   ld   a,0xc6
;   out (TFT_D),a
;
;   ld   a,0xf7
;   out  (TFT_C),a
;   ld   a,0xa9
;   out (TFT_D),a
;   ld   a,0x51
;   out (TFT_D),a
;   ld   a,0x2c
;   out (TFT_D),a
;   ld   a,0x82
;   out (TFT_D),a

  ld   a,0x53   ; CTRL display
  out  (TFT_C),a ; 
  ld   a,0b00100100
  out  (TFT_D),a

  ld   a,0x51   ; write brightness
  out  (TFT_C),a ; 
  ld   a,0xff
  out  (TFT_D),a
   
  ld   a,0x36     ; set address mode
  out  (TFT_C),a
  ld   a,0b00100000
  out   (TFT_D),a

  ld   a,0x3A
  out  (TFT_C),a ; set pixel format
  ld   a,0b00000101
  out  (TFT_D),a

  ld   a,0x13
  out  (TFT_D),a

  ld   b,0xff
delay2:
  djnz  delay2

  ld   a,0x29  ; dpy on
  out  (TFT_C),a

  ld   a,':'
  rst  PUTC

;  ld   a,0x09  ; get display status
;  out  (TFT_C),a

;  in   a,(TFT_D); dummy data
;  in   a,(TFT_D) ; not relevant
;  call printhex
;  in   a,(TFT_D)
;  call printhex
;  in   a,(TFT_D)
;  call printhex
;  in   a,(TFT_D)
;  call printhex

;  ld   a,0x22 ; all pixels off
;  out  (TFT_C),a
;  ld   b,0xff
;delay2:
;  djnz  delay2
  ;ld   a,0x23 ; all pixels on
  ;out  (TFT_C),a


  ; draw rect
  ld   a,0x2a   ; set x1,x2
  out  (TFT_C),a
  ld   a,0
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
  ld   a,1
  out  (TFT_D),a
  ld   a,0xe0
  out  (TFT_D),a

  ld   a,0x2b   ; set y1,y1
  out  (TFT_C),a
  ld   a,0
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
  ld   a,1
  out  (TFT_D),a
  ld   a,0x40
  out  (TFT_D),a

  ld   a,0x2c    ; do write
  out  (TFT_C),a

  ld   d,0x03
  ld   b,0x58    ; = 64
  ld   c,0x00
again:
  ld   a,0x40
  out  (TFT_D),a
  ld   a,0xaf
  out  (TFT_D),a
  dec  bc
  ld   a,b
  cp   0
  jr   nz, again
  dec  d
  ld   a,d
  cp   0
  jr   z,end
  ld   b,0xff
  ld   c,0xff
  jr   again

end:
  pop  bc
  pop  hl
  ret


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

welcome_msg: ascii 18,"TFT Display test",CR,LF
hexconv_table:    db "0123456789ABCDEF"
