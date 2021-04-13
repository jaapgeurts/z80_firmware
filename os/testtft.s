TFT_C equ 0xA0
TFT_D equ 0xA1

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

ILI_WAKEUP         equ 0x11
ILI_DPY_NORMAL     equ 0x13
ILI_DPY_OFF        equ 0x28 
ILI_DPY_ON         equ 0x29
ILI_SET_COLADR     equ 0x2a
ILI_SET_ROWADR     equ 0x2b
ILI_MEM_WRITE      equ 0x2c
ILI_MEM_ACCESS_CTL equ 0x36
ILI_PXL_FMT        equ 0x3a
ILI_SET_DPY_BRIGHT equ 0x51
ILI_DPY_CTRL_VAL   equ 0x53
ILI_READ_ID4       equ 0xd3

v_cursor_x equ  0x8000
v_cursor_y equ  0x8001


; terminal size, total chars, font sizes
; 40x20,  800, 12x16
; 60x20, 1200,  8x16
; 60x40, 2400,  8x8
; 80x40, 3200,  6x8
FONTW equ 8
FONTH equ 16
FONTBYTES equ (FONTW * FONTH) / 8
COLS equ 60
ROWS equ 20

  org 0x4000

  push hl
  push bc

  ld a,0
  ld (v_cursor_x),a
  ld (v_cursor_y),a

  ld   hl,welcome_msg
  rst  PRINTK
  
  ld   a,0x01   ; reset TFT display
  out  (TFT_C),a

  ld   b,0xff
delay1:
  djnz  delay1


  ld   a,ILI_READ_ID4  ; read id
  out  (TFT_C),a
  in   a,(TFT_D); dummy data
  in   a,(TFT_D) ; not relevant
  in   a,(TFT_D)
  call printhex
  in   a,(TFT_D)
  call printhex

  ld   a,ILI_DPY_OFF  ; dpy off
  out  (TFT_C),a

  ld   a,ILI_WAKEUP   ; wake up
  out  (TFT_C),a

  ld   a,ILI_DPY_CTRL_VAL   ; CTRL display
  out  (TFT_C),a ; 
  ld   a,0b00100100
  out  (TFT_D),a

  ld   a,ILI_SET_DPY_BRIGHT   ; write brightness
  out  (TFT_C),a ; 
  ld   a,0xff
  out  (TFT_D),a
   
  ld   a,ILI_MEM_ACCESS_CTL     ; set address mode
  out  (TFT_C),a
  ld   a,0b00100000
;  ld   a,0b00000000
  out   (TFT_D),a

  ld   a,ILI_PXL_FMT
  out  (TFT_C),a ; set pixel format
  ld   a,0b00000101
  out  (TFT_D),a

  ld   a,ILI_DPY_NORMAL
  out  (TFT_D),a

  ld   b,0xff
delay2:
  djnz  delay2

  ld   a,ILI_DPY_ON  ; dpy on
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

  ld   hl,lorumipsum
  call printd
  call printd
  call printd
  call printd
  ld   hl,lorumipsum2
  call printd

  pop  bc
  pop  hl
  ret

printd: ; print display
  push hl
  push bc
  ld   b,(hl)
.printk_loop:
  inc  hl
  ld   a, (hl)
  call printd_let
  djnz .printk_loop
  pop  bc
  pop  hl
  ret
  

printd_let:
  push hl
  push bc
  push de
  push af

  ; set start x1,x2
  ld   a,(v_cursor_x)
  ld   c,a
  ld   b,FONTW ; font width
  call multiply

  ; set start x1,x2
  ld   a,ILI_SET_COLADR   ; set x1,x2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   b,0
  ld   c, FONTW-1; font width
  add  hl,bc
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a

; set start y1,y2
  ld   a,(v_cursor_y)
  ld   c,a
  ld   b,FONTH ; font height
  call multiply
  
; set start y1,y2
  ld   a,ILI_SET_ROWADR   ; set y1,y2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   b,0
  ld   c,FONTH-1  ; font height
  add  hl,bc
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a

  ld   a,(v_cursor_x); // inc x position
  inc  a
;  cp   40  ; 40 columns
  cp   COLS  ; 80 columns
  jr   nz,.endif_lf
  ld   a,0   ; inc y position in case over edge
  ld   hl,v_cursor_y
  inc  (hl)
.endif_lf:
  ld  (v_cursor_x),a

  ; copy letter A to screen
  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a

  ; set up letter
  ;ld   hl,letter65
  pop  af ; get letter back from stack
  sub  32 ; remove 32 because the char set starts at 32
  ld   de,FONTBYTES  ; font small
  ld   hl,allletters
  cp   0
  jr   z,.skipspace
  ld   b,a
.mul:
  add  hl,de
  djnz .mul

.skipspace:
  ; pixels to set
  ld   b,FONTBYTES ; font small
.next_byte:
  ld   a,(hl)
  ld   c, 8
.shift_bit:
  ld   d,a
  ;and  0x80
  bit  7,a
  jr   z,.pix_off
  ld   a,0xff   ; foreground white
  out  (TFT_D),a
  ld   a,0xff
  out  (TFT_D),a
  jr   .continue
.pix_off 
  ld   a,0xf8  ; background blue
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
.continue:
  ld   a,d
  sla  a
  dec  c
  jr   nz,.shift_bit
  inc  hl
  djnz .next_byte
  
  pop  de
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

;   hl = b * c
multiply:
  push de
  push bc
  ld   hl,0
  ld   a,b
  or   a
  jr   z,.end
  ld   d,0
  ld   e,c
.loop:
  add  hl,de
  djnz .loop
.end:
  pop  bc
  pop  de
  ret

welcome_msg:   db 18,"TFT Display test",CR,LF
hexconv_table: db "0123456789ABCDEF"
lorumipsum:    db 255,"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent placerat consequat bibendum. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Sed ante urna, interdum at diam a, vulputate consectetur lorem. Nunc impe"
lorumipsum2:   db 35,"Lorem ipsum dolor sit amet, consect"

allletters:
allletters_08x16:
letter32:  ; ' '
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter33:  ; '!'
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter34:  ; '"'
  db 0b00000000
  db 0b01100110
  db 0b01100110
  db 0b01100110
  db 0b01100110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter35:  ; '#'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01101100
  db 0b01101100
  db 0b11111110
  db 0b01101100
  db 0b01101100
  db 0b01101100
  db 0b11111110
  db 0b01101100
  db 0b01101100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter36:  ; '$'
  db 0b00010000
  db 0b00010000
  db 0b01111100
  db 0b11010110
  db 0b11010010
  db 0b11010000
  db 0b01111100
  db 0b00010110
  db 0b00010110
  db 0b10010110
  db 0b11010110
  db 0b01111100
  db 0b00010000
  db 0b00010000
  db 0b00000000
  db 0b00000000

letter37:  ; '%'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000010
  db 0b11000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b11000110
  db 0b10000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter38:  ; '&'
  db 0b00000000
  db 0b00000000
  db 0b00111000
  db 0b01101100
  db 0b01101100
  db 0b00111000
  db 0b01110110
  db 0b11011100
  db 0b11001100
  db 0b11001100
  db 0b11001100
  db 0b01110110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter39:  ; '''
  db 0b00000000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b01100000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter40:  ; '('
  db 0b00000000
  db 0b00000000
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00011000
  db 0b00001100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter41:  ; ')'
  db 0b00000000
  db 0b00000000
  db 0b00110000
  db 0b00011000
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter42:  ; '*'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01100110
  db 0b00111100
  db 0b11111111
  db 0b00111100
  db 0b01100110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter43:  ; '+'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b01111110
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter44:  ; ','
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00110000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter45:  ; '-'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter46:  ; '.'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter47:  ; '/'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000010
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b11000000
  db 0b10000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter48:  ; '0'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11010110
  db 0b11010110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter49:  ; '1'
  db 0b00000000
  db 0b00000000
  db 0b00001100
  db 0b00011100
  db 0b00111100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter50:  ; '2'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b11000000
  db 0b11000000
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter51:  ; '3'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b00000110
  db 0b00000110
  db 0b00111100
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter52:  ; '4'
  db 0b00000000
  db 0b00000000
  db 0b00001110
  db 0b00011110
  db 0b00110110
  db 0b01100110
  db 0b11000110
  db 0b11111110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter53:  ; '5'
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111100
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter54:  ; '6'
  db 0b00000000
  db 0b00000000
  db 0b00111000
  db 0b01100000
  db 0b11000000
  db 0b11000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter55:  ; '7'
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter56:  ; '8'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter57:  ; '9'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00001100
  db 0b01111000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter58:  ; ':'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter59:  ; ';'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00110000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter60:  ; '<'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b00110000
  db 0b00011000
  db 0b00001100
  db 0b00000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter61:  ; '='
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter62:  ; '>'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01100000
  db 0b00110000
  db 0b00011000
  db 0b00001100
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter63:  ; '?'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b00001100
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter64:  ; '@'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11011110
  db 0b11011110
  db 0b11011110
  db 0b11011100
  db 0b11000000
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter65:  ; 'A'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter66:  ; 'B'
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter67:  ; 'C'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter68:  ; 'D'
  db 0b00000000
  db 0b00000000
  db 0b11111000
  db 0b11001100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11001100
  db 0b11111000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter69:  ; 'E'
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter70:  ; 'F'
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter71:  ; 'G'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11011110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111010
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter72:  ; 'H'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter73:  ; 'I'
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter74:  ; 'J'
  db 0b00000000
  db 0b00000000
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter75:  ; 'K'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11001100
  db 0b11011000
  db 0b11110000
  db 0b11110000
  db 0b11011000
  db 0b11001100
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter76:  ; 'L'
  db 0b00000000
  db 0b00000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter77:  ; 'M'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11101110
  db 0b11111110
  db 0b11111110
  db 0b11010110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter78:  ; 'N'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11100110
  db 0b11110110
  db 0b11111110
  db 0b11011110
  db 0b11001110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter79:  ; 'O'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter80:  ; 'P'
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter81:  ; 'Q'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00001100
  db 0b00000110
  db 0b00000000
  db 0b00000000

letter82:  ; 'R'
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b11011000
  db 0b11001100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter83:  ; 'S'
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000000
  db 0b11000000
  db 0b01111100
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter84:  ; 'T'
  db 0b00000000
  db 0b00000000
  db 0b11111111
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter85:  ; 'U'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter86:  ; 'V'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01101100
  db 0b00111000
  db 0b00010000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter87:  ; 'W'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11010110
  db 0b11010110
  db 0b11010110
  db 0b11111110
  db 0b11101110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter88:  ; 'X'
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01101100
  db 0b00111000
  db 0b00111000
  db 0b01101100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter89:  ; 'Y'
  db 0b00000000
  db 0b00000000
  db 0b11000011
  db 0b11000011
  db 0b11000011
  db 0b01100110
  db 0b00111100
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter90:  ; 'Z'
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b00000110
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b11000000
  db 0b11000000
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter91:  ; '['
  db 0b00000000
  db 0b00000000
  db 0b00111100
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00110000
  db 0b00111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter92:  ; '\'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b10000000
  db 0b11000000
  db 0b01100000
  db 0b00110000
  db 0b00011000
  db 0b00001100
  db 0b00000110
  db 0b00000010
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter93:  ; ']'
  db 0b00000000
  db 0b00000000
  db 0b00111100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00001100
  db 0b00111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter94:  ; '^'
  db 0b00010000
  db 0b00111000
  db 0b01101100
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter95:  ; '_'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111111
  db 0b00000000
  db 0b00000000

letter96:  ; '`'
  db 0b00110000
  db 0b00110000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter97:  ; 'a'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b00000110
  db 0b01111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter98:  ; 'b'
  db 0b00000000
  db 0b00000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter99:  ; 'c'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter100:  ; 'd'
  db 0b00000000
  db 0b00000000
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b01111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter101:  ; 'e'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11111110
  db 0b11000000
  db 0b11000000
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter102:  ; 'f'
  db 0b00000000
  db 0b00000000
  db 0b00111100
  db 0b01100000
  db 0b01100000
  db 0b01100000
  db 0b11110000
  db 0b01100000
  db 0b01100000
  db 0b01100000
  db 0b01100000
  db 0b01100000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter103:  ; 'g'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000110
  db 0b00000110
  db 0b01111100
  db 0b00000000

letter104:  ; 'h'
  db 0b00000000
  db 0b00000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter105:  ; 'i'
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter106:  ; 'j'
  db 0b00000000
  db 0b00000000
  db 0b00000110
  db 0b00000110
  db 0b00000000
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000

letter107:  ; 'k'
  db 0b00000000
  db 0b00000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000110
  db 0b11001100
  db 0b11111000
  db 0b11110000
  db 0b11011000
  db 0b11001100
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter108:  ; 'l'
  db 0b00000000
  db 0b00000000
  db 0b00111000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter109:  ; 'm'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11111110
  db 0b11010110
  db 0b11010110
  db 0b11010110
  db 0b11010110
  db 0b11010110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter110:  ; 'n'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter111:  ; 'o'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter112:  ; 'p'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11111100
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b00000000

letter113:  ; 'q'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000110
  db 0b00000110
  db 0b00000110
  db 0b00000000

letter114:  ; 'r'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111100
  db 0b11000110
  db 0b11000110
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b11000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter115:  ; 's'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b01111100
  db 0b11000110
  db 0b11000000
  db 0b01111100
  db 0b00000110
  db 0b11000110
  db 0b01111100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter116:  ; 't'
  db 0b00000000
  db 0b00000000
  db 0b00001000
  db 0b00011000
  db 0b00011000
  db 0b01111110
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00001110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter117:  ; 'u'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter118:  ; 'v'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01101100
  db 0b00111000
  db 0b00010000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter119:  ; 'w'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11010110
  db 0b11010110
  db 0b11111110
  db 0b11101110
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter120:  ; 'x'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b01101100
  db 0b00111000
  db 0b00111000
  db 0b00111000
  db 0b01101100
  db 0b11000110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter121:  ; 'y'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b11000110
  db 0b01111110
  db 0b00000110
  db 0b00000110
  db 0b01111100
  db 0b00000000

letter122:  ; 'z'
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b11111110
  db 0b00001100
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b11000000
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter123:  ; '{'
  db 0b00000000
  db 0b00000000
  db 0b00001110
  db 0b00011000
  db 0b00011000
  db 0b00110000
  db 0b01100000
  db 0b00110000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00001110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter124:  ; '|'
  db 0b00000000
  db 0b00000000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter125:  ; '}'
  db 0b00000000
  db 0b00000000
  db 0b01110000
  db 0b00011000
  db 0b00011000
  db 0b00001100
  db 0b00000110
  db 0b00001100
  db 0b00011000
  db 0b00011000
  db 0b00011000
  db 0b01110000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter126:  ; '~'
  db 0b00000000
  db 0b00000000
  db 0b01110110
  db 0b11011100
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000

letter127:  ; ''
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00010000
  db 0b00111000
  db 0b01101100
  db 0b11000110
  db 0b11000110
  db 0b11111110
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  db 0b00000000
  
; allletters_06x08:
; letter32:  ; ' '
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter33:  ; '!'
;   db 0b00010000
;   db 0b11100011
;   db 0b10000100
;   db 0b00010000
;   db 0b00000001
;   db 0b00000000

; letter34:  ; '"'
;   db 0b01101101
;   db 0b10110100
;   db 0b10000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter35:  ; '#'
;   db 0b00000000
;   db 0b10100111
;   db 0b11001010
;   db 0b00101001
;   db 0b11110010
;   db 0b10000000

; letter36:  ; '$'
;   db 0b00100000
;   db 0b11100100
;   db 0b00001100
;   db 0b00001001
;   db 0b11000001
;   db 0b00000000

; letter37:  ; '%'
;   db 0b01100101
;   db 0b10010000
;   db 0b10000100
;   db 0b00100001
;   db 0b00110100
;   db 0b11000000

; letter38:  ; '&'
;   db 0b00100001
;   db 0b01000101
;   db 0b00001000
;   db 0b01010101
;   db 0b00100011
;   db 0b01000000

; letter39:  ; '''
;   db 0b00110000
;   db 0b11000010
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter40:  ; '('
;   db 0b00010000
;   db 0b10000010
;   db 0b00001000
;   db 0b00100000
;   db 0b10000001
;   db 0b00000000

; letter41:  ; ')'
;   db 0b00100000
;   db 0b01000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000010
;   db 0b00000000

; letter42:  ; '*'
;   db 0b00000000
;   db 0b10100011
;   db 0b10011111
;   db 0b00111000
;   db 0b10100000
;   db 0b00000000

; letter43:  ; '+'
;   db 0b00000000
;   db 0b01000001
;   db 0b00011111
;   db 0b00010000
;   db 0b01000000
;   db 0b00000000

; letter44:  ; ','
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b11000011
;   db 0b00001000

; letter45:  ; '-'
;   db 0b00000000
;   db 0b00000000
;   db 0b00011111
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter46:  ; '.'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b11000011
;   db 0b00000000

; letter47:  ; '/'
;   db 0b00000000
;   db 0b00010000
;   db 0b10000100
;   db 0b00100001
;   db 0b00000000
;   db 0b00000000

; letter48:  ; '0'
;   db 0b00111001
;   db 0b00010100
;   db 0b11010101
;   db 0b01100101
;   db 0b00010011
;   db 0b10000000

; letter49:  ; '1'
;   db 0b00010000
;   db 0b11000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000011
;   db 0b10000000

; letter50:  ; '2'
;   db 0b00111001
;   db 0b00010000
;   db 0b01000110
;   db 0b00100001
;   db 0b00000111
;   db 0b11000000

; letter51:  ; '3'
;   db 0b00111001
;   db 0b00010000
;   db 0b01001110
;   db 0b00000101
;   db 0b00010011
;   db 0b10000000

; letter52:  ; '4'
;   db 0b00001000
;   db 0b01100010
;   db 0b10010010
;   db 0b01111100
;   db 0b00100000
;   db 0b10000000

; letter53:  ; '5'
;   db 0b01111101
;   db 0b00000100
;   db 0b00011110
;   db 0b00000101
;   db 0b00010011
;   db 0b10000000

; letter54:  ; '6'
;   db 0b00011000
;   db 0b10000100
;   db 0b00011110
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter55:  ; '7'
;   db 0b01111100
;   db 0b00010000
;   db 0b10000100
;   db 0b00100000
;   db 0b10000010
;   db 0b00000000

; letter56:  ; '8'
;   db 0b00111001
;   db 0b00010100
;   db 0b01001110
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter57:  ; '9'
;   db 0b00111001
;   db 0b00010100
;   db 0b01001111
;   db 0b00000100
;   db 0b00100011
;   db 0b00000000

; letter58:  ; ':'
;   db 0b00000000
;   db 0b00000011
;   db 0b00001100
;   db 0b00000000
;   db 0b11000011
;   db 0b00000000

; letter59:  ; ';'
;   db 0b00000000
;   db 0b00000011
;   db 0b00001100
;   db 0b00000000
;   db 0b11000011
;   db 0b00001000

; letter60:  ; '<'
;   db 0b00001000
;   db 0b01000010
;   db 0b00010000
;   db 0b00100000
;   db 0b01000000
;   db 0b10000000

; letter61:  ; '='
;   db 0b00000000
;   db 0b00000111
;   db 0b11000000
;   db 0b00000001
;   db 0b11110000
;   db 0b00000000

; letter62:  ; '>'
;   db 0b00100000
;   db 0b01000000
;   db 0b10000001
;   db 0b00001000
;   db 0b01000010
;   db 0b00000000

; letter63:  ; '?'
;   db 0b00111001
;   db 0b00010000
;   db 0b01000110
;   db 0b00010000
;   db 0b00000001
;   db 0b00000000

; letter64:  ; '@'
;   db 0b00111001
;   db 0b00010101
;   db 0b11010101
;   db 0b01011101
;   db 0b00000011
;   db 0b10000000

; letter65:  ; 'A'
;   db 0b00111001
;   db 0b00010100
;   db 0b01010001
;   db 0b01111101
;   db 0b00010100
;   db 0b01000000

; letter66:  ; 'B'
;   db 0b01111001
;   db 0b00010100
;   db 0b01011110
;   db 0b01000101
;   db 0b00010111
;   db 0b10000000

; letter67:  ; 'C'
;   db 0b00111001
;   db 0b00010100
;   db 0b00010000
;   db 0b01000001
;   db 0b00010011
;   db 0b10000000

; letter68:  ; 'D'
;   db 0b01111001
;   db 0b00010100
;   db 0b01010001
;   db 0b01000101
;   db 0b00010111
;   db 0b10000000

; letter69:  ; 'E'
;   db 0b01111101
;   db 0b00000100
;   db 0b00011110
;   db 0b01000001
;   db 0b00000111
;   db 0b11000000

; letter70:  ; 'F'
;   db 0b01111101
;   db 0b00000100
;   db 0b00011110
;   db 0b01000001
;   db 0b00000100
;   db 0b00000000

; letter71:  ; 'G'
;   db 0b00111001
;   db 0b00010100
;   db 0b00010111
;   db 0b01000101
;   db 0b00010011
;   db 0b11000000

; letter72:  ; 'H'
;   db 0b01000101
;   db 0b00010100
;   db 0b01011111
;   db 0b01000101
;   db 0b00010100
;   db 0b01000000

; letter73:  ; 'I'
;   db 0b00111000
;   db 0b01000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000011
;   db 0b10000000

; letter74:  ; 'J'
;   db 0b00000100
;   db 0b00010000
;   db 0b01000001
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter75:  ; 'K'
;   db 0b01000101
;   db 0b00100101
;   db 0b00011000
;   db 0b01010001
;   db 0b00100100
;   db 0b01000000

; letter76:  ; 'L'
;   db 0b01000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000001
;   db 0b00000111
;   db 0b11000000

; letter77:  ; 'M'
;   db 0b01000101
;   db 0b10110101
;   db 0b01010001
;   db 0b01000101
;   db 0b00010100
;   db 0b01000000

; letter78:  ; 'N'
;   db 0b01000101
;   db 0b10010101
;   db 0b01010011
;   db 0b01000101
;   db 0b00010100
;   db 0b01000000

; letter79:  ; 'O'
;   db 0b00111001
;   db 0b00010100
;   db 0b01010001
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter80:  ; 'P'
;   db 0b01111001
;   db 0b00010100
;   db 0b01011110
;   db 0b01000001
;   db 0b00000100
;   db 0b00000000

; letter81:  ; 'Q'
;   db 0b00111001
;   db 0b00010100
;   db 0b01010001
;   db 0b01010101
;   db 0b00100011
;   db 0b01000000

; letter82:  ; 'R'
;   db 0b01111001
;   db 0b00010100
;   db 0b01011110
;   db 0b01001001
;   db 0b00010100
;   db 0b01000000

; letter83:  ; 'S'
;   db 0b00111001
;   db 0b00010100
;   db 0b00001110
;   db 0b00000101
;   db 0b00010011
;   db 0b10000000

; letter84:  ; 'T'
;   db 0b01111100
;   db 0b01000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000001
;   db 0b00000000

; letter85:  ; 'U'
;   db 0b01000101
;   db 0b00010100
;   db 0b01010001
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter86:  ; 'V'
;   db 0b01000101
;   db 0b00010100
;   db 0b01010001
;   db 0b01000100
;   db 0b10100001
;   db 0b00000000

; letter87:  ; 'W'
;   db 0b01000101
;   db 0b00010101
;   db 0b01010101
;   db 0b01010101
;   db 0b01010010
;   db 0b10000000

; letter88:  ; 'X'
;   db 0b01000101
;   db 0b00010010
;   db 0b10000100
;   db 0b00101001
;   db 0b00010100
;   db 0b01000000

; letter89:  ; 'Y'
;   db 0b01000101
;   db 0b00010100
;   db 0b01001010
;   db 0b00010000
;   db 0b01000001
;   db 0b00000000

; letter90:  ; 'Z'
;   db 0b01111000
;   db 0b00100001
;   db 0b00001000
;   db 0b01000001
;   db 0b00000111
;   db 0b10000000

; letter91:  ; '['
;   db 0b00111000
;   db 0b10000010
;   db 0b00001000
;   db 0b00100000
;   db 0b10000011
;   db 0b10000000

; letter92:  ; '\'
;   db 0b00000001
;   db 0b00000010
;   db 0b00000100
;   db 0b00001000
;   db 0b00010000
;   db 0b00000000

; letter93:  ; ']'
;   db 0b00111000
;   db 0b00100000
;   db 0b10000010
;   db 0b00001000
;   db 0b00100011
;   db 0b10000000

; letter94:  ; '^'
;   db 0b00010000
;   db 0b10100100
;   db 0b01000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter95:  ; '_'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00111111

; letter96:  ; '`'
;   db 0b00110000
;   db 0b11000001
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter97:  ; 'a'
;   db 0b00000000
;   db 0b00000011
;   db 0b10000001
;   db 0b00111101
;   db 0b00010011
;   db 0b11000000

; letter98:  ; 'b'
;   db 0b01000001
;   db 0b00000111
;   db 0b10010001
;   db 0b01000101
;   db 0b00010111
;   db 0b10000000

; letter99:  ; 'c'
;   db 0b00000000
;   db 0b00000011
;   db 0b10010001
;   db 0b01000001
;   db 0b00010011
;   db 0b10000000

; letter100:  ; 'd'
;   db 0b00000100
;   db 0b00010011
;   db 0b11010001
;   db 0b01000101
;   db 0b00010011
;   db 0b11000000

; letter101:  ; 'e'
;   db 0b00000000
;   db 0b00000011
;   db 0b10010001
;   db 0b01111001
;   db 0b00000011
;   db 0b10000000

; letter102:  ; 'f'
;   db 0b00011000
;   db 0b10000010
;   db 0b00011110
;   db 0b00100000
;   db 0b10000010
;   db 0b00000000

; letter103:  ; 'g'
;   db 0b00000000
;   db 0b00000011
;   db 0b11010001
;   db 0b01000100
;   db 0b11110000
;   db 0b01001110

; letter104:  ; 'h'
;   db 0b01000001
;   db 0b00000111
;   db 0b00010010
;   db 0b01001001
;   db 0b00100100
;   db 0b10000000

; letter105:  ; 'i'
;   db 0b00010000
;   db 0b00000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000001
;   db 0b10000000

; letter106:  ; 'j'
;   db 0b00001000
;   db 0b00000001
;   db 0b10000010
;   db 0b00001000
;   db 0b00100100
;   db 0b10001100

; letter107:  ; 'k'
;   db 0b01000001
;   db 0b00000100
;   db 0b10010100
;   db 0b01100001
;   db 0b01000100
;   db 0b10000000

; letter108:  ; 'l'
;   db 0b00010000
;   db 0b01000001
;   db 0b00000100
;   db 0b00010000
;   db 0b01000001
;   db 0b10000000

; letter109:  ; 'm'
;   db 0b00000000
;   db 0b00000110
;   db 0b10010101
;   db 0b01010101
;   db 0b00010100
;   db 0b01000000

; letter110:  ; 'n'
;   db 0b00000000
;   db 0b00000111
;   db 0b00010010
;   db 0b01001001
;   db 0b00100100
;   db 0b10000000

; letter111:  ; 'o'
;   db 0b00000000
;   db 0b00000011
;   db 0b10010001
;   db 0b01000101
;   db 0b00010011
;   db 0b10000000

; letter112:  ; 'p'
;   db 0b00000000
;   db 0b00000111
;   db 0b10010001
;   db 0b01000101
;   db 0b00010111
;   db 0b10010000

; letter113:  ; 'q'
;   db 0b00000000
;   db 0b00000011
;   db 0b11010001
;   db 0b01000101
;   db 0b00010011
;   db 0b11000001

; letter114:  ; 'r'
;   db 0b00000000
;   db 0b00000101
;   db 0b10001001
;   db 0b00100000
;   db 0b10000111
;   db 0b00000000

; letter115:  ; 's'
;   db 0b00000000
;   db 0b00000011
;   db 0b10010000
;   db 0b00111000
;   db 0b00010011
;   db 0b10000000

; letter116:  ; 't'
;   db 0b00000000
;   db 0b10000111
;   db 0b10001000
;   db 0b00100000
;   db 0b10100001
;   db 0b00000000

; letter117:  ; 'u'
;   db 0b00000000
;   db 0b00000100
;   db 0b10010010
;   db 0b01001001
;   db 0b01100010
;   db 0b10000000

; letter118:  ; 'v'
;   db 0b00000000
;   db 0b00000100
;   db 0b01010001
;   db 0b01000100
;   db 0b10100001
;   db 0b00000000

; letter119:  ; 'w'
;   db 0b00000000
;   db 0b00000100
;   db 0b01010001
;   db 0b01010101
;   db 0b11110010
;   db 0b10000000

; letter120:  ; 'x'
;   db 0b00000000
;   db 0b00000100
;   db 0b10010010
;   db 0b00110001
;   db 0b00100100
;   db 0b10000000

; letter121:  ; 'y'
;   db 0b00000000
;   db 0b00000100
;   db 0b10010010
;   db 0b01001000
;   db 0b11100001
;   db 0b00011000

; letter122:  ; 'z'
;   db 0b00000000
;   db 0b00000111
;   db 0b10000010
;   db 0b00110001
;   db 0b00000111
;   db 0b10000000

; letter123:  ; '{'
;   db 0b00011000
;   db 0b10000010
;   db 0b00011000
;   db 0b00100000
;   db 0b10000001
;   db 0b10000000

; letter124:  ; '|'
;   db 0b00010000
;   db 0b01000001
;   db 0b00000000
;   db 0b00010000
;   db 0b01000001
;   db 0b00000000

; letter125:  ; '}'
;   db 0b00110000
;   db 0b00100000
;   db 0b10000011
;   db 0b00001000
;   db 0b00100011
;   db 0b00000000

; letter126:  ; '~'
;   db 0b00101001
;   db 0b01000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter127:  ; ''
;   db 0b00010000
;   db 0b11100110
;   db 0b11010001
;   db 0b01000101
;   db 0b11110000
;   db 0b00000000



allletters_12x16:
; letter32:  ; ' '
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter33:  ; '!'
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001111
;   db 0b00000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter34:  ; '"'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00011001
;   db 0b10000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000001
;   db 0b10011000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter35:  ; '#'
;   db 0b00000000
;   db 0b00000000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00111111
;   db 0b11110000
;   db 0b11001100
;   db 0b00001100
;   db 0b11000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000111
;   db 0b11111100
;   db 0b00110011
;   db 0b00000011
;   db 0b00110000
;   db 0b00110011
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter36:  ; '$'
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00011111
;   db 0b10000011
;   db 0b11111100
;   db 0b00110110
;   db 0b00000011
;   db 0b01100000
;   db 0b00111111
;   db 0b10000001
;   db 0b11111100
;   db 0b00000110
;   db 0b11000000
;   db 0b01101100
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter37:  ; '%'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00010011
;   db 0b10000011
;   db 0b00111000
;   db 0b01110011
;   db 0b10001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000111
;   db 0b00000000
;   db 0b11100000
;   db 0b00011100
;   db 0b00000011
;   db 0b10001110
;   db 0b01110000
;   db 0b11100110
;   db 0b00001110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter38:  ; '&'
;   db 0b00000000
;   db 0b00000000
;   db 0b01110000
;   db 0b00001101
;   db 0b10000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000001
;   db 0b10110000
;   db 0b00001110
;   db 0b00000001
;   db 0b11100000
;   db 0b00111110
;   db 0b00000011
;   db 0b00110110
;   db 0b00110011
;   db 0b11000011
;   db 0b00011000
;   db 0b00111011
;   db 0b11000001
;   db 0b11100110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter39:  ; '''
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter40:  ; '('
;   db 0b00000011
;   db 0b10000000
;   db 0b01100000
;   db 0b00001110
;   db 0b00000000
;   db 0b11000000
;   db 0b00011100
;   db 0b00000001
;   db 0b11000000
;   db 0b00011100
;   db 0b00000001
;   db 0b11000000
;   db 0b00011100
;   db 0b00000001
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b11100000
;   db 0b00000110
;   db 0b00000000
;   db 0b00111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter41:  ; ')'
;   db 0b00011100
;   db 0b00000000
;   db 0b01100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b10000000
;   db 0b00111000
;   db 0b00000011
;   db 0b10000000
;   db 0b00111000
;   db 0b00000011
;   db 0b10000000
;   db 0b00111000
;   db 0b00000011
;   db 0b00000000
;   db 0b01110000
;   db 0b00000110
;   db 0b00000001
;   db 0b11000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter42:  ; '*'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b01101100
;   db 0b00110110
;   db 0b11000001
;   db 0b11111000
;   db 0b00001111
;   db 0b00000011
;   db 0b11111100
;   db 0b00001111
;   db 0b00000001
;   db 0b11111000
;   db 0b00110110
;   db 0b11000011
;   db 0b01101100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter43:  ; '+'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000011
;   db 0b11111100
;   db 0b00111111
;   db 0b11000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter44:  ; ','
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000

; letter45:  ; '-'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b11111100
;   db 0b00111111
;   db 0b11000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter46:  ; '.'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter47:  ; '/'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b00000000
;   db 0b00110000
;   db 0b00000111
;   db 0b00000000
;   db 0b11100000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b01110000
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000111
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter48:  ; '0'
;   db 0b00001111
;   db 0b10000011
;   db 0b11111110
;   db 0b00110000
;   db 0b01100110
;   db 0b00000111
;   db 0b01100000
;   db 0b11110110
;   db 0b00011011
;   db 0b01100011
;   db 0b00110110
;   db 0b01100011
;   db 0b01101100
;   db 0b00110111
;   db 0b10000011
;   db 0b01110000
;   db 0b00110011
;   db 0b00000110
;   db 0b00111111
;   db 0b11100000
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter49:  ; '1'
;   db 0b00000011
;   db 0b00000000
;   db 0b01110000
;   db 0b00011111
;   db 0b00000001
;   db 0b11110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00011111
;   db 0b11100001
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter50:  ; '2'
;   db 0b00011111
;   db 0b11000011
;   db 0b11111110
;   db 0b01110000
;   db 0b01110110
;   db 0b00000011
;   db 0b01100000
;   db 0b01110000
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000111
;   db 0b00000000
;   db 0b11100000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b01111111
;   db 0b11110111
;   db 0b11111111
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter51:  ; '3'
;   db 0b00011111
;   db 0b11000011
;   db 0b11111110
;   db 0b01110000
;   db 0b01110110
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000111
;   db 0b00001111
;   db 0b11100000
;   db 0b11111100
;   db 0b00000000
;   db 0b01100000
;   db 0b00000011
;   db 0b01100000
;   db 0b00110111
;   db 0b00000111
;   db 0b00111111
;   db 0b11100001
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter52:  ; '4'
;   db 0b00000001
;   db 0b11000000
;   db 0b00111100
;   db 0b00000111
;   db 0b11000000
;   db 0b11101100
;   db 0b00011100
;   db 0b11000011
;   db 0b10001100
;   db 0b01110000
;   db 0b11000110
;   db 0b00001100
;   db 0b01111111
;   db 0b11110111
;   db 0b11111111
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter53:  ; '5'
;   db 0b01111111
;   db 0b11110111
;   db 0b11111111
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000111
;   db 0b11111100
;   db 0b00111111
;   db 0b11100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b01100000
;   db 0b00110111
;   db 0b00000111
;   db 0b00111111
;   db 0b11100001
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter54:  ; '6'
;   db 0b00000011
;   db 0b11000000
;   db 0b01111100
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000011
;   db 0b00000000
;   db 0b01111111
;   db 0b11000111
;   db 0b11111110
;   db 0b01110000
;   db 0b01110110
;   db 0b00000011
;   db 0b01100000
;   db 0b00110111
;   db 0b00000111
;   db 0b00111111
;   db 0b11100001
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter55:  ; '7'
;   db 0b01111111
;   db 0b11110111
;   db 0b11111111
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001100
;   db 0b00000000
;   db 0b11000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter56:  ; '8'
;   db 0b00001111
;   db 0b10000001
;   db 0b11111100
;   db 0b00111000
;   db 0b11100011
;   db 0b00000110
;   db 0b00110000
;   db 0b01100011
;   db 0b10001110
;   db 0b00011111
;   db 0b11000011
;   db 0b11111110
;   db 0b01110000
;   db 0b01110110
;   db 0b00000011
;   db 0b01100000
;   db 0b00110111
;   db 0b00000111
;   db 0b00111111
;   db 0b11100001
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter57:  ; '9'
;   db 0b00011111
;   db 0b11000011
;   db 0b11111110
;   db 0b01110000
;   db 0b01110110
;   db 0b00000011
;   db 0b01100000
;   db 0b00110111
;   db 0b00000111
;   db 0b00111111
;   db 0b11110001
;   db 0b11111111
;   db 0b00000000
;   db 0b01100000
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00011111
;   db 0b00000001
;   db 0b11100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter58:  ; ':'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter59:  ; ';'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000

; letter60:  ; '<'
;   db 0b00000000
;   db 0b11000000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b01110000
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000011
;   db 0b10000000
;   db 0b00011100
;   db 0b00000000
;   db 0b11100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00111000
;   db 0b00000001
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter61:  ; '='
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b11111110
;   db 0b00111111
;   db 0b11100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b11111110
;   db 0b00111111
;   db 0b11100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter62:  ; '>'
;   db 0b00110000
;   db 0b00000011
;   db 0b10000000
;   db 0b00011100
;   db 0b00000000
;   db 0b11100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00111000
;   db 0b00000001
;   db 0b11000000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b01110000
;   db 0b00001110
;   db 0b00000001
;   db 0b11000000
;   db 0b00111000
;   db 0b00000011
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter63:  ; '?'
;   db 0b00011111
;   db 0b10000011
;   db 0b11111100
;   db 0b01110000
;   db 0b11100110
;   db 0b00000110
;   db 0b01100000
;   db 0b11100000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b01110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter64:  ; '@'
;   db 0b00011111
;   db 0b11000011
;   db 0b11111110
;   db 0b00110000
;   db 0b01100110
;   db 0b01111011
;   db 0b01101111
;   db 0b10110110
;   db 0b11011011
;   db 0b01101101
;   db 0b10110110
;   db 0b11011011
;   db 0b01101101
;   db 0b10110110
;   db 0b11111110
;   db 0b01100111
;   db 0b11000111
;   db 0b00000000
;   db 0b00111111
;   db 0b11000000
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter65:  ; 'A'
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001111
;   db 0b00000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000001
;   db 0b10011000
;   db 0b00110000
;   db 0b11000011
;   db 0b11111100
;   db 0b00111111
;   db 0b11000110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter66:  ; 'B'
;   db 0b01111111
;   db 0b00000111
;   db 0b11111000
;   db 0b01100001
;   db 0b11000110
;   db 0b00001100
;   db 0b01100000
;   db 0b11000110
;   db 0b00011100
;   db 0b01111111
;   db 0b10000111
;   db 0b11111100
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00001110
;   db 0b01111111
;   db 0b11000111
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter67:  ; 'C'
;   db 0b00001111
;   db 0b10000001
;   db 0b11111100
;   db 0b00111000
;   db 0b11100011
;   db 0b00000110
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b00110000
;   db 0b01100011
;   db 0b10001110
;   db 0b00011111
;   db 0b11000000
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter68:  ; 'D'
;   db 0b01111111
;   db 0b00000111
;   db 0b11111000
;   db 0b01100001
;   db 0b11000110
;   db 0b00001100
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b11000110
;   db 0b00011100
;   db 0b01111111
;   db 0b10000111
;   db 0b11110000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter69:  ; 'E'
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01111111
;   db 0b10000111
;   db 0b11111000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter70:  ; 'F'
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01111111
;   db 0b10000111
;   db 0b11111000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter71:  ; 'G'
;   db 0b00001111
;   db 0b11000001
;   db 0b11111110
;   db 0b00111000
;   db 0b01100011
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100011
;   db 0b11100110
;   db 0b00111110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00110000
;   db 0b01100011
;   db 0b10000110
;   db 0b00011111
;   db 0b11100000
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter72:  ; 'H'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter73:  ; 'I'
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter74:  ; 'J'
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00001100
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter75:  ; 'K'
;   db 0b01100000
;   db 0b01100110
;   db 0b00001110
;   db 0b01100001
;   db 0b11000110
;   db 0b00111000
;   db 0b01100111
;   db 0b00000110
;   db 0b11100000
;   db 0b01111100
;   db 0b00000111
;   db 0b11000000
;   db 0b01101110
;   db 0b00000110
;   db 0b01110000
;   db 0b01100011
;   db 0b10000110
;   db 0b00011100
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter76:  ; 'L'
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter77:  ; 'M'
;   db 0b01100000
;   db 0b01100111
;   db 0b00001110
;   db 0b01110000
;   db 0b11100111
;   db 0b10011110
;   db 0b01111001
;   db 0b11100110
;   db 0b11110110
;   db 0b01101111
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter78:  ; 'N'
;   db 0b01100000
;   db 0b01100111
;   db 0b00000110
;   db 0b01110000
;   db 0b01100111
;   db 0b10000110
;   db 0b01101100
;   db 0b01100110
;   db 0b11000110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100011
;   db 0b01100110
;   db 0b00110110
;   db 0b01100001
;   db 0b11100110
;   db 0b00001110
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter79:  ; 'O'
;   db 0b00001111
;   db 0b00000001
;   db 0b11111000
;   db 0b00111001
;   db 0b11000011
;   db 0b00001100
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00110000
;   db 0b11000011
;   db 0b10011100
;   db 0b00011111
;   db 0b10000000
;   db 0b11110000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter80:  ; 'P'
;   db 0b01111111
;   db 0b10000111
;   db 0b11111100
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b11100111
;   db 0b11111100
;   db 0b01111111
;   db 0b10000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter81:  ; 'Q'
;   db 0b00001111
;   db 0b00000001
;   db 0b11111000
;   db 0b00111001
;   db 0b11000011
;   db 0b00001100
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00110110
;   db 0b00110011
;   db 0b11000011
;   db 0b10011100
;   db 0b00011111
;   db 0b11100000
;   db 0b11110110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter82:  ; 'R'
;   db 0b01111111
;   db 0b10000111
;   db 0b11111100
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b11100111
;   db 0b11111100
;   db 0b01111111
;   db 0b10000110
;   db 0b01110000
;   db 0b01100011
;   db 0b10000110
;   db 0b00011100
;   db 0b01100000
;   db 0b11100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter83:  ; 'S'
;   db 0b00011111
;   db 0b10000011
;   db 0b11111100
;   db 0b01110000
;   db 0b11100110
;   db 0b00000110
;   db 0b01100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00111111
;   db 0b10000001
;   db 0b11111100
;   db 0b00000000
;   db 0b11100000
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00001110
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter84:  ; 'T'
;   db 0b00111111
;   db 0b11000011
;   db 0b11111100
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter85:  ; 'U'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100011
;   db 0b00001100
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter86:  ; 'V'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100011
;   db 0b00001100
;   db 0b00110000
;   db 0b11000011
;   db 0b00001100
;   db 0b00011001
;   db 0b10000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000000
;   db 0b11110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter87:  ; 'W'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b11110110
;   db 0b01111001
;   db 0b11100111
;   db 0b00001110
;   db 0b01110000
;   db 0b11100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter88:  ; 'X'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00110000
;   db 0b11000011
;   db 0b00001100
;   db 0b00011001
;   db 0b10000000
;   db 0b11110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001111
;   db 0b00000001
;   db 0b10011000
;   db 0b00110000
;   db 0b11000011
;   db 0b00001100
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter89:  ; 'Y'
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b00110000
;   db 0b11000011
;   db 0b00001100
;   db 0b00011001
;   db 0b10000001
;   db 0b10011000
;   db 0b00001111
;   db 0b00000000
;   db 0b11110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter90:  ; 'Z'
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000001
;   db 0b10000000
;   db 0b00110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001100
;   db 0b00000001
;   db 0b10000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter91:  ; '['
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter92:  ; '\'
;   db 0b00000000
;   db 0b00000100
;   db 0b00000000
;   db 0b01100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00111000
;   db 0b00000001
;   db 0b11000000
;   db 0b00001110
;   db 0b00000000
;   db 0b01110000
;   db 0b00000011
;   db 0b10000000
;   db 0b00011100
;   db 0b00000000
;   db 0b11100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00110000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter93:  ; ']'
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter94:  ; '^'
;   db 0b00000010
;   db 0b00000000
;   db 0b01110000
;   db 0b00001111
;   db 0b10000001
;   db 0b11011100
;   db 0b00111000
;   db 0b11100111
;   db 0b00000111
;   db 0b01100000
;   db 0b00110000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter95:  ; '_'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b01111111
;   db 0b11110111
;   db 0b11111111

; letter96:  ; '`'
;   db 0b00000000
;   db 0b00000000
;   db 0b01110000
;   db 0b00000111
;   db 0b00000000
;   db 0b01110000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000011
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter97:  ; 'a'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111100
;   db 0b00111111
;   db 0b11100000
;   db 0b00000110
;   db 0b00011111
;   db 0b11100011
;   db 0b11111110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01111111
;   db 0b11100011
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter98:  ; 'b'
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b11111000
;   db 0b01111111
;   db 0b11000111
;   db 0b00001110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00001110
;   db 0b01111111
;   db 0b11000111
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter99:  ; 'c'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111000
;   db 0b00111111
;   db 0b11000111
;   db 0b00000110
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000111
;   db 0b00000110
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter100:  ; 'd'
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100001
;   db 0b11110110
;   db 0b00111111
;   db 0b11100111
;   db 0b00011110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00000110
;   db 0b00111111
;   db 0b11100001
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter101:  ; 'e'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111000
;   db 0b00111111
;   db 0b11000111
;   db 0b00000110
;   db 0b01111111
;   db 0b11100111
;   db 0b11111100
;   db 0b01100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter102:  ; 'f'
;   db 0b00000111
;   db 0b10000000
;   db 0b11111000
;   db 0b00011100
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b01111111
;   db 0b00000111
;   db 0b11110000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter103:  ; 'g'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111110
;   db 0b00111111
;   db 0b11100111
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00001110
;   db 0b00111111
;   db 0b11100001
;   db 0b11110110
;   db 0b00000000
;   db 0b01100000
;   db 0b00001110
;   db 0b00111111
;   db 0b11000011
;   db 0b11111000

; letter104:  ; 'h'
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b11110000
;   db 0b01111111
;   db 0b10000111
;   db 0b00011100
;   db 0b01100000
;   db 0b11000110
;   db 0b00001100
;   db 0b01100000
;   db 0b11000110
;   db 0b00001100
;   db 0b01100000
;   db 0b11000110
;   db 0b00001100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter105:  ; 'i'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b11100000
;   db 0b00001110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter106:  ; 'j'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000000
;   db 0b00000000
;   db 0b00111000
;   db 0b00000011
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000001
;   db 0b10011000
;   db 0b00011111
;   db 0b10000000
;   db 0b11110000

; letter107:  ; 'k'
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00011000
;   db 0b00110011
;   db 0b10000011
;   db 0b01110000
;   db 0b00111110
;   db 0b00000011
;   db 0b11100000
;   db 0b00110111
;   db 0b00000011
;   db 0b00111000
;   db 0b00110001
;   db 0b11000011
;   db 0b00001100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter108:  ; 'l'
;   db 0b00001110
;   db 0b00000000
;   db 0b11100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00011111
;   db 0b10000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter109:  ; 'm'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000101
;   db 0b10011000
;   db 0b01111111
;   db 0b11000111
;   db 0b11111110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter110:  ; 'n'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b11111000
;   db 0b00111111
;   db 0b11000011
;   db 0b00001110
;   db 0b00110000
;   db 0b01100011
;   db 0b00000110
;   db 0b00110000
;   db 0b01100011
;   db 0b00000110
;   db 0b00110000
;   db 0b01100011
;   db 0b00000110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter111:  ; 'o'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111000
;   db 0b00111111
;   db 0b11000111
;   db 0b00001110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00001110
;   db 0b00111111
;   db 0b11000001
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter112:  ; 'p'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000111
;   db 0b11111000
;   db 0b01111111
;   db 0b11000110
;   db 0b00001110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01110000
;   db 0b11100111
;   db 0b11111100
;   db 0b01101111
;   db 0b10000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000

; letter113:  ; 'q'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000001
;   db 0b11111110
;   db 0b00111111
;   db 0b11100111
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01110000
;   db 0b11100011
;   db 0b11111110
;   db 0b00011111
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110

; letter114:  ; 'r'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b01111100
;   db 0b00111111
;   db 0b11100011
;   db 0b10000110
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter115:  ; 's'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b11110000
;   db 0b01111111
;   db 0b10000110
;   db 0b00000000
;   db 0b01111111
;   db 0b00000011
;   db 0b11111000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b01111111
;   db 0b10000011
;   db 0b11110000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter116:  ; 't'
;   db 0b00000000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000111
;   db 0b11110000
;   db 0b01111111
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011000
;   db 0b00000001
;   db 0b10000000
;   db 0b00011111
;   db 0b10000000
;   db 0b11111000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter117:  ; 'u'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100111
;   db 0b00001110
;   db 0b00111111
;   db 0b11100001
;   db 0b11110110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter118:  ; 'v'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000110
;   db 0b01100000
;   db 0b01100011
;   db 0b00001100
;   db 0b00110000
;   db 0b11000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter119:  ; 'w'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01100110
;   db 0b01101111
;   db 0b01100011
;   db 0b11111100
;   db 0b00111001
;   db 0b11000001
;   db 0b00001000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter120:  ; 'x'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00001100
;   db 0b01110001
;   db 0b11000011
;   db 0b10111000
;   db 0b00011111
;   db 0b00000000
;   db 0b11100000
;   db 0b00011111
;   db 0b00000011
;   db 0b10111000
;   db 0b01110001
;   db 0b11000110
;   db 0b00001100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter121:  ; 'y'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000011
;   db 0b00001100
;   db 0b00110000
;   db 0b11000001
;   db 0b10011000
;   db 0b00011001
;   db 0b10000000
;   db 0b11110000
;   db 0b00001111
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000001
;   db 0b10000000

; letter122:  ; 'z'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000111
;   db 0b11111100
;   db 0b01111111
;   db 0b10000000
;   db 0b00110000
;   db 0b00000110
;   db 0b00000000
;   db 0b11000000
;   db 0b00011000
;   db 0b00000011
;   db 0b00000000
;   db 0b01111111
;   db 0b11000111
;   db 0b11111100
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter123:  ; '{'
;   db 0b00000011
;   db 0b11000000
;   db 0b01111100
;   db 0b00001110
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b11000000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b00011100
;   db 0b00000000
;   db 0b11000000
;   db 0b00001100
;   db 0b00000000
;   db 0b11000000
;   db 0b00001110
;   db 0b00000000
;   db 0b01111100
;   db 0b00000011
;   db 0b11000000
;   db 0b00000000

; letter124:  ; '|'
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000110
;   db 0b00000000
;   db 0b01100000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter125:  ; '}'
;   db 0b00111100
;   db 0b00000011
;   db 0b11100000
;   db 0b00000111
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000011
;   db 0b10000000
;   db 0b00011100
;   db 0b00000011
;   db 0b10000000
;   db 0b00110000
;   db 0b00000011
;   db 0b00000000
;   db 0b00110000
;   db 0b00000111
;   db 0b00000011
;   db 0b11100000
;   db 0b00111100
;   db 0b00000000
;   db 0b00000000

; letter126:  ; '~'
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00011100
;   db 0b01100011
;   db 0b01101100
;   db 0b01100011
;   db 0b10000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

; letter127:  ; ''
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000110
;   db 0b00000000
;   db 0b11110000
;   db 0b00011001
;   db 0b10000011
;   db 0b00001100
;   db 0b01100000
;   db 0b01100110
;   db 0b00000110
;   db 0b01111111
;   db 0b11100111
;   db 0b11111110
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000
;   db 0b00000000

