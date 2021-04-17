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
ILI_DPY_VSSA       equ 0x37
ILI_PXL_FMT        equ 0x3a
ILI_SET_DPY_BRIGHT equ 0x51
ILI_DPY_CTRL_VAL   equ 0x53
ILI_READ_ID4       equ 0xd3

v_screenbuf  equ 0x8034 ; must be aligned to multiple of 60
v_cursor     equ v_screenbuf + TOTALCHARS; 1200 chars
;v_cursor_y   equ v_cursor_x + 1
v_foreground equ v_cursor + 1
v_background equ v_foreground + 1
vt_xstart    equ v_background + 1
vt_xend      equ vt_xstart + 2
vt_ystart    equ vt_xend + 2
vt_yend      equ vt_ystart + 2

; terminal size, total chars, font sizes
; 40x20,  800, 12x16
; 60x20, 1200,  8x16
; 60x40, 2400,  8x8
; 80x40, 3200,  6x8
FONTW equ 8
FONTH equ 16
BYTESPERFONT equ (FONTW * FONTH) / 8
COLS equ 60
ROWS equ 20
DPYWIDTH equ 480
DPYHEIGHT equ 320
TOTALCHARS equ COLS * ROWS

  org 0x4000

  push hl
  push bc

  ld   a,0
  ld   (v_cursor),a
  ld   (v_background),a
  ld   a, 0xf8
  ld   (v_foreground),a

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

  call displayClearBuffer

  call displayClear

  ld   hl,welcome_msg
  call printd

  ld   hl,lorumipsum
  call printd

  ;call displayScrollLastLine

  pop  bc
  pop  hl
  ret


printd: ; push it into the buffer; then redraw the screen
  push hl
  push bc
  push de

  ; add cursor index 
  push hl
  ld   d,0
  ld   a,(v_cursor)
  ld   e,a
  ld   hl,v_screenbuf
  add  hl,de
  ex   de,hl
  pop  hl

  ld   b,(hl)
.printd_loop:
  inc  hl
  ld   a, (hl)
  ; check for CR and LF
  cp   CR
  jr   nz, .checkLF
  ; move cursor to home
  ; get remainder
  push hl
  push bc
  push de ;; ld hl,de
  pop  hl 
  ld   c,COLS
  call division ; a = remainder
  ld   b,0
  ld   c,a
  ex   de,hl ; de is v_cursor
  sbc  hl,bc
  ex   de,hl
  pop  bc
  pop  hl
  jr   .endif
.checkLF:
  cp   LF
  jr   nz,.storeChar
  push hl
  ld   hl,COLS
  add  hl,de ; TODO: scroll screen if de > 1200
  ex   de,hl
  pop  hl
  jr   .endif
.storeChar:
  ld   (de),a
  inc  de
.endif:
  djnz .printd_loop

  ; subtract screenbuf
  ld   hl,v_screenbuf
  ex   de,hl
  sbc  hl,de
  ld   (v_cursor),hl

  pop  de
  pop  bc
  pop  hl
  call displayRepaint
  ret


displayRepaint:
  push hl
  push bc
  push de

  ;; TODO currently assumes from start to end.
  ; rewrite draw from start cursor to end cursor

  ld   hl,0
  ld   (vt_xstart),hl
  ld   (vt_ystart),hl
  ld   hl,FONTW-1
  ld   (vt_xend),hl
  ld   hl,FONTH-1
  ld   (vt_yend),hl

  ; go through the array. if dirty draw
  ld   bc, v_screenbuf

.nextGlyph

  ; set display start and end position
  ld   hl,(vt_xend)
  ex   de,hl
  ld   hl,(vt_xstart)
  call displaySetX1X2
  ld   hl,(vt_yend)
  ex   de,hl
  ld   hl,(vt_ystart)
  call displaySetY1Y2
  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a

  ld   a,(bc) ; load letter
  
  ; get the glyph
  ld   de,BYTESPERFONT  ; font small
  ld   hl,allletters
.findGlyph
  cp   0
  jr   z,.drawGlyph
  add  hl,de
  dec  a
  jr   nz,.findGlyph
  ; hl now points to the correct glyph

.drawGlyph:

  push bc ; contains the index into the screenbuf

  ; pixels to set
  ld   b,BYTESPERFONT ; font small
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
  ld   a,0xf8  ; background blue TODO: move to var
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
.continue: ;
  ld   a,d
  sla  a
  dec  c
  jr   nz,.shift_bit
  inc  hl
  djnz .next_byte

  pop  bc
  
  ; done with the glyph. goto next cell
  inc  bc   ; if bc < 1200 continue at .incxy
  ld   a,b
  cp   (v_screenbuf + TOTALCHARS) >> 8
  jr   nz,.incxy
  ld   a,c
  cp   (v_screenbuf + TOTALCHARS) & 0xff
  jr   nz,.incxy
  ; done drawing
  jr   .printLetEnd

.incxy:

  ld  hl,(vt_xstart)
  ld  de,FONTW
  add hl,de
  ld  a,h
  cp  1
  jr  nz, .next1
  ld  a,l
  cp  0xe0  ; one beyond the last column
  jr  nz, .next1
  ; over edge; increase y and set x to zero
  ld  hl,FONTW-1
  ld  (vt_xend),hl
  ; increase y
  ld  hl,(vt_ystart)
  ld  de,FONTH
  add hl,de
  ld  (vt_ystart),hl
  ld  de,FONTH-1
  add hl,de
  ld  (vt_yend),hl
  ld  hl,0  ;set x-start to zero
.next1:
  ld  (vt_xstart),hl
  ld  de,FONTW-1
  add hl,de
  ld  (vt_xend),hl
  jp  .nextGlyph

.printLetEnd:
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

; hl by c, quotient in hl, remainder in a
division:
  push bc
  xor	a
  ld	b, 16

.loop:
  add	hl, hl
  rla
  jr	c, $+5
  cp	c
  jr	c, $+4

  sub	c
  inc	l
   
  djnz	.loop
  pop  bc 
  ret

; hl = x1,de = x2
displaySetX1X2:
  ld   a,ILI_SET_COLADR   ; set x1,x2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   a,d
  out  (TFT_D),a
  ld   a,e
  out  (TFT_D),a
  ret
  
; set start y1,y2
; hl = y1,de = y2
displaySetY1Y2:
  ld   a,ILI_SET_ROWADR   ; set y1,y2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   a,d
  out  (TFT_D),a
  ld   a,e
  out  (TFT_D),a
  ret

displayClear:
  push bc
  ld   hl,0
  ld   de,0x01e0
  call displaySetX1X2
  ld   hl,0
  ld   de,0x0140
  call displaySetY1Y2
  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a
; loop 480x320 times = 3 * 200 * 256
  ld   d,3
  ld   bc,200
.dpyClearLoop:
  ld   a,0xf8  ; background blue TODO: move to var
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
  djnz .dpyClearLoop
  dec  c
  ld   b,0  ; dnjz decreases first then compares so is actually 256
  jr   nz,.dpyClearLoop
  dec  d
  ld   c,200
  jr   nz,.dpyClearLoop

  pop  bc
  ret

displayClearBuffer:
  push hl
  push bc
 ; first clear backing store
  ld   hl,v_screenbuf
  ld   c,(TOTALCHARS >> 8) + 1
  ld   b,TOTALCHARS & 0xff
.nextclear:
  ld   (hl),0
  inc  hl
  djnz .nextclear
  dec  c
  jr   nz,.nextclear
  pop  bc
  pop  hl
  ret

displayScrollLastLine:
  ld   a,ILI_DPY_VSSA ; start vertical scrolling
  out  (TFT_C),a
  ld   a,0
  out  (TFT_D),a
  ld   a,FONTH
  out  (TFT_D),a


welcome_msg:   db 18,"TFT Display test",CR,LF
hexconv_table: db "0123456789ABCDEF"
lorumipsum:    db 255,"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent placerat consequat bibendum. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Sed ante urna, interdum at diam a, vulputate consectetur lorem. Nunc impe"
lorumipsum2:   db 35,"Lorem ipsum dolor sit amet, consect"

allletters:
allletters_08x16:
letter0:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '\x0'
letter1:    db 0x00,0x00,0x7e,0x81,0xa5,0x81,0x81,0xa5,0x99,0x81,0x81,0x7e,0x00,0x00,0x00,0x00 ; '\x1'
letter2:    db 0x00,0x00,0x7e,0xff,0xdb,0xff,0xff,0xdb,0xe7,0xff,0xff,0x7e,0x00,0x00,0x00,0x00 ; '\x2'
letter3:    db 0x00,0x00,0x00,0x00,0x6c,0xfe,0xfe,0xfe,0xfe,0x7c,0x38,0x10,0x00,0x00,0x00,0x00 ; '\x3'
letter4:    db 0x00,0x00,0x00,0x00,0x10,0x38,0x7c,0xfe,0x7c,0x38,0x10,0x00,0x00,0x00,0x00,0x00 ; '\x4'
letter5:    db 0x00,0x00,0x00,0x18,0x3c,0x3c,0xe7,0xe7,0xe7,0x18,0x18,0x3c,0x00,0x00,0x00,0x00 ; '\x5'
letter6:    db 0x00,0x00,0x00,0x18,0x3c,0x7e,0xff,0xff,0x7e,0x18,0x18,0x3c,0x00,0x00,0x00,0x00 ; '\x6'
letter7:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x3c,0x3c,0x18,0x00,0x00,0x00,0x00,0x00,0x00 ; '\x7'
letter8:    db 0xff,0xff,0xff,0xff,0xff,0xff,0xe7,0xc3,0xc3,0xe7,0xff,0xff,0xff,0xff,0xff,0xff ; '\x8'
letter9:    db 0x00,0x00,0x00,0x00,0x00,0x3c,0x42,0x42,0x42,0x42,0x3c,0x00,0x00,0x00,0x00,0x00 ; '\x9'
letter10:    db 0x00,0x00,0x00,0x00,0x00,0x3c,0x7e,0x7e,0x7e,0x7e,0x3c,0x00,0x00,0x00,0x00,0x00 ; '\x10'
letter11:    db 0x00,0x00,0x1e,0x0e,0x1a,0x32,0x78,0xcc,0xcc,0xcc,0xcc,0x78,0x00,0x00,0x00,0x00 ; '\x11'
letter12:    db 0x00,0x00,0x3c,0x66,0x66,0x66,0x66,0x3c,0x18,0x7e,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x12'
letter13:    db 0x00,0x00,0x3f,0x33,0x3f,0x30,0x30,0x30,0x30,0x70,0xf0,0xe0,0x00,0x00,0x00,0x00 ; '\x13'
letter14:    db 0x00,0x00,0x7f,0x63,0x7f,0x63,0x63,0x63,0x63,0x67,0xe7,0xe6,0xc0,0x00,0x00,0x00 ; '\x14'
letter15:    db 0x00,0x00,0x00,0x10,0x92,0x54,0x38,0xee,0x38,0x54,0x92,0x10,0x00,0x00,0x00,0x00 ; '\x15'
letter16:    db 0x00,0x80,0xc0,0xe0,0xf0,0xf8,0xfc,0xf8,0xf0,0xe0,0xc0,0x80,0x00,0x00,0x00,0x00 ; '\x16'
letter17:    db 0x00,0x02,0x06,0x0e,0x1e,0x3e,0x7e,0x3e,0x1e,0x0e,0x06,0x02,0x00,0x00,0x00,0x00 ; '\x17'
letter18:    db 0x00,0x00,0x18,0x3c,0x7e,0x18,0x18,0x18,0x7e,0x3c,0x18,0x00,0x00,0x00,0x00,0x00 ; '\x18'
letter19:    db 0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x66,0x66,0x00,0x00,0x00,0x00 ; '\x19'
letter20:    db 0x00,0x00,0x7f,0xdb,0xdb,0xdb,0x7b,0x1b,0x1b,0x1b,0x1b,0x1b,0x00,0x00,0x00,0x00 ; '\x20'
letter21:    db 0x00,0x7c,0xc6,0x60,0x38,0x6c,0xc6,0xc6,0x6c,0x38,0x0c,0xc6,0x7c,0x00,0x00,0x00 ; '\x21'
letter22:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0xfe,0xfe,0xfe,0x00,0x00,0x00,0x00 ; '\x22'
letter23:    db 0x00,0x00,0x18,0x3c,0x7e,0x18,0x18,0x18,0x7e,0x3c,0x18,0x7e,0x00,0x00,0x00,0x00 ; '\x23'
letter24:    db 0x00,0x10,0x38,0x7c,0xfe,0x38,0x38,0x38,0x38,0x38,0x38,0x38,0x00,0x00,0x00,0x00 ; '\x24'
letter25:    db 0x00,0x38,0x38,0x38,0x38,0x38,0x38,0x38,0xfe,0x7c,0x38,0x10,0x00,0x00,0x00,0x00 ; '\x25'
letter26:    db 0x00,0x00,0x00,0x00,0x08,0x0c,0xfe,0xff,0xfe,0x0c,0x08,0x00,0x00,0x00,0x00,0x00 ; '\x26'
letter27:    db 0x00,0x00,0x00,0x00,0x10,0x30,0x7f,0xff,0x7f,0x30,0x10,0x00,0x00,0x00,0x00,0x00 ; '\x27'
letter28:    db 0x00,0x00,0x00,0x00,0x00,0x00,0xc0,0xc0,0xc0,0xfe,0x00,0x00,0x00,0x00,0x00,0x00 ; '\x28'
letter29:    db 0x00,0x00,0x00,0x00,0x00,0x28,0x6c,0xfe,0x6c,0x28,0x00,0x00,0x00,0x00,0x00,0x00 ; '\x29'
letter30:    db 0x00,0x00,0x00,0x00,0x10,0x38,0x38,0x7c,0x7c,0xfe,0xfe,0x00,0x00,0x00,0x00,0x00 ; '\x30'
letter31:    db 0x00,0x00,0x00,0x00,0xfe,0xfe,0x7c,0x7c,0x38,0x38,0x10,0x00,0x00,0x00,0x00,0x00 ; '\x31'
letter32:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; ' '
letter33:    db 0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00 ; '!'
letter34:    db 0x00,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '"'
letter35:    db 0x00,0x00,0x00,0x6c,0x6c,0xfe,0x6c,0x6c,0x6c,0xfe,0x6c,0x6c,0x00,0x00,0x00,0x00 ; '#'
letter36:    db 0x10,0x10,0x7c,0xd6,0xd2,0xd0,0x7c,0x16,0x16,0x96,0xd6,0x7c,0x10,0x10,0x00,0x00 ; '$'
letter37:    db 0x00,0x00,0x00,0x00,0xc2,0xc6,0x0c,0x18,0x30,0x60,0xc6,0x86,0x00,0x00,0x00,0x00 ; '%'
letter38:    db 0x00,0x00,0x38,0x6c,0x6c,0x38,0x76,0xdc,0xcc,0xcc,0xcc,0x76,0x00,0x00,0x00,0x00 ; '&'
letter39:    db 0x00,0x30,0x30,0x30,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '''
letter40:    db 0x00,0x00,0x0c,0x18,0x30,0x30,0x30,0x30,0x30,0x30,0x18,0x0c,0x00,0x00,0x00,0x00 ; '('
letter41:    db 0x00,0x00,0x30,0x18,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x18,0x30,0x00,0x00,0x00,0x00 ; ')'
letter42:    db 0x00,0x00,0x00,0x00,0x00,0x66,0x3c,0xff,0x3c,0x66,0x00,0x00,0x00,0x00,0x00,0x00 ; '*'
letter43:    db 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x7e,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00 ; '+'
letter44:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x30,0x00,0x00,0x00 ; ','
letter45:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x7e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '-'
letter46:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00 ; '.'
letter47:    db 0x00,0x00,0x00,0x00,0x02,0x06,0x0c,0x18,0x30,0x60,0xc0,0x80,0x00,0x00,0x00,0x00 ; '/'
letter48:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xd6,0xd6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '0'
letter49:    db 0x00,0x00,0x0c,0x1c,0x3c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x00,0x00,0x00,0x00 ; '1'
letter50:    db 0x00,0x00,0x7c,0xc6,0x06,0x0c,0x18,0x30,0x60,0xc0,0xc0,0xfe,0x00,0x00,0x00,0x00 ; '2'
letter51:    db 0x00,0x00,0x7c,0xc6,0x06,0x06,0x3c,0x06,0x06,0x06,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '3'
letter52:    db 0x00,0x00,0x0e,0x1e,0x36,0x66,0xc6,0xfe,0x06,0x06,0x06,0x06,0x00,0x00,0x00,0x00 ; '4'
letter53:    db 0x00,0x00,0xfe,0xc0,0xc0,0xc0,0xfc,0x06,0x06,0x06,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '5'
letter54:    db 0x00,0x00,0x38,0x60,0xc0,0xc0,0xfc,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '6'
letter55:    db 0x00,0x00,0xfe,0x06,0x06,0x06,0x0c,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '7'
letter56:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0x7c,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '8'
letter57:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0x7e,0x06,0x06,0x06,0x0c,0x78,0x00,0x00,0x00,0x00 ; '9'
letter58:    db 0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00 ; ':'
letter59:    db 0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x18,0x18,0x30,0x00,0x00,0x00,0x00 ; ';'
letter60:    db 0x00,0x00,0x00,0x06,0x0c,0x18,0x30,0x60,0x30,0x18,0x0c,0x06,0x00,0x00,0x00,0x00 ; '<'
letter61:    db 0x00,0x00,0x00,0x00,0x00,0x7e,0x00,0x00,0x7e,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '='
letter62:    db 0x00,0x00,0x00,0x60,0x30,0x18,0x0c,0x06,0x0c,0x18,0x30,0x60,0x00,0x00,0x00,0x00 ; '>'
letter63:    db 0x00,0x00,0x7c,0xc6,0xc6,0x0c,0x18,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00 ; '?'
letter64:    db 0x00,0x00,0x00,0x7c,0xc6,0xc6,0xde,0xde,0xde,0xdc,0xc0,0x7c,0x00,0x00,0x00,0x00 ; '@'
letter65:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'A'
letter66:    db 0x00,0x00,0xfc,0xc6,0xc6,0xc6,0xfc,0xc6,0xc6,0xc6,0xc6,0xfc,0x00,0x00,0x00,0x00 ; 'B'
letter67:    db 0x00,0x00,0x7c,0xc6,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'C'
letter68:    db 0x00,0x00,0xf8,0xcc,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xcc,0xf8,0x00,0x00,0x00,0x00 ; 'D'
letter69:    db 0x00,0x00,0xfe,0xc0,0xc0,0xc0,0xf8,0xc0,0xc0,0xc0,0xc0,0xfe,0x00,0x00,0x00,0x00 ; 'E'
letter70:    db 0x00,0x00,0xfe,0xc0,0xc0,0xc0,0xf8,0xc0,0xc0,0xc0,0xc0,0xc0,0x00,0x00,0x00,0x00 ; 'F'
letter71:    db 0x00,0x00,0x7c,0xc6,0xc0,0xc0,0xc0,0xde,0xc6,0xc6,0xc6,0x7a,0x00,0x00,0x00,0x00 ; 'G'
letter72:    db 0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'H'
letter73:    db 0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'I'
letter74:    db 0x00,0x00,0x06,0x06,0x06,0x06,0x06,0x06,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'J'
letter75:    db 0x00,0x00,0xc6,0xc6,0xcc,0xd8,0xf0,0xf0,0xd8,0xcc,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'K'
letter76:    db 0x00,0x00,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xfe,0x00,0x00,0x00,0x00 ; 'L'
letter77:    db 0x00,0x00,0xc6,0xee,0xfe,0xfe,0xd6,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'M'
letter78:    db 0x00,0x00,0xc6,0xe6,0xf6,0xfe,0xde,0xce,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'N'
letter79:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'O'
letter80:    db 0x00,0x00,0xfc,0xc6,0xc6,0xc6,0xc6,0xfc,0xc0,0xc0,0xc0,0xc0,0x00,0x00,0x00,0x00 ; 'P'
letter81:    db 0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x0c,0x06,0x00,0x00 ; 'Q'
letter82:    db 0x00,0x00,0xfc,0xc6,0xc6,0xc6,0xfc,0xd8,0xcc,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'R'
letter83:    db 0x00,0x00,0x7c,0xc6,0xc0,0xc0,0x7c,0x06,0x06,0x06,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'S'
letter84:    db 0x00,0x00,0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'T'
letter85:    db 0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'U'
letter86:    db 0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x6c,0x38,0x10,0x00,0x00,0x00,0x00 ; 'V'
letter87:    db 0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xd6,0xd6,0xd6,0xfe,0xee,0xc6,0x00,0x00,0x00,0x00 ; 'W'
letter88:    db 0x00,0x00,0xc6,0xc6,0xc6,0x6c,0x38,0x38,0x6c,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'X'
letter89:    db 0x00,0x00,0xc3,0xc3,0xc3,0x66,0x3c,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'Y'
letter90:    db 0x00,0x00,0xfe,0x06,0x06,0x0c,0x18,0x30,0x60,0xc0,0xc0,0xfe,0x00,0x00,0x00,0x00 ; 'Z'
letter91:    db 0x00,0x00,0x3c,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x3c,0x00,0x00,0x00,0x00 ; '['
letter92:    db 0x00,0x00,0x00,0x00,0x80,0xc0,0x60,0x30,0x18,0x0c,0x06,0x02,0x00,0x00,0x00,0x00 ; '\'
letter93:    db 0x00,0x00,0x3c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x0c,0x3c,0x00,0x00,0x00,0x00 ; ']'
letter94:    db 0x10,0x38,0x6c,0xc6,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '^'
letter95:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0x00,0x00 ; '_'
letter96:    db 0x30,0x30,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '`'
letter97:    db 0x00,0x00,0x00,0x00,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; 'a'
letter98:    db 0x00,0x00,0xc0,0xc0,0xc0,0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xfc,0x00,0x00,0x00,0x00 ; 'b'
letter99:    db 0x00,0x00,0x00,0x00,0x00,0x7c,0xc6,0xc0,0xc0,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'c'
letter100:    db 0x00,0x00,0x06,0x06,0x06,0x7e,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; 'd'
letter101:    db 0x00,0x00,0x00,0x00,0x00,0x7c,0xc6,0xc6,0xfe,0xc0,0xc0,0x7c,0x00,0x00,0x00,0x00 ; 'e'
letter102:    db 0x00,0x00,0x3c,0x60,0x60,0x60,0xf0,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00 ; 'f'
letter103:    db 0x00,0x00,0x00,0x00,0x00,0x7e,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x06,0x06,0x7c,0x00 ; 'g'
letter104:    db 0x00,0x00,0xc0,0xc0,0xc0,0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'h'
letter105:    db 0x00,0x00,0x18,0x18,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'i'
letter106:    db 0x00,0x00,0x06,0x06,0x00,0x06,0x06,0x06,0x06,0x06,0x06,0x06,0xc6,0xc6,0x7c,0x00 ; 'j'
letter107:    db 0x00,0x00,0xc0,0xc0,0xc0,0xc6,0xcc,0xf8,0xf0,0xd8,0xcc,0xc6,0x00,0x00,0x00,0x00 ; 'k'
letter108:    db 0x00,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'l'
letter109:    db 0x00,0x00,0x00,0x00,0x00,0xfc,0xfe,0xd6,0xd6,0xd6,0xd6,0xd6,0x00,0x00,0x00,0x00 ; 'm'
letter110:    db 0x00,0x00,0x00,0x00,0x00,0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'n'
letter111:    db 0x00,0x00,0x00,0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 'o'
letter112:    db 0x00,0x00,0x00,0x00,0x00,0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xfc,0xc0,0xc0,0xc0,0x00 ; 'p'
letter113:    db 0x00,0x00,0x00,0x00,0x00,0x7e,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x06,0x06,0x06,0x00 ; 'q'
letter114:    db 0x00,0x00,0x00,0x00,0x00,0xfc,0xc6,0xc6,0xc0,0xc0,0xc0,0xc0,0x00,0x00,0x00,0x00 ; 'r'
letter115:    db 0x00,0x00,0x00,0x00,0x00,0x7c,0xc6,0xc0,0x7c,0x06,0xc6,0x7c,0x00,0x00,0x00,0x00 ; 's'
letter116:    db 0x00,0x00,0x08,0x18,0x18,0x7e,0x18,0x18,0x18,0x18,0x18,0x0e,0x00,0x00,0x00,0x00 ; 't'
letter117:    db 0x00,0x00,0x00,0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; 'u'
letter118:    db 0x00,0x00,0x00,0x00,0x00,0xc6,0xc6,0xc6,0xc6,0x6c,0x38,0x10,0x00,0x00,0x00,0x00 ; 'v'
letter119:    db 0x00,0x00,0x00,0x00,0x00,0xc6,0xc6,0xd6,0xd6,0xfe,0xee,0xc6,0x00,0x00,0x00,0x00 ; 'w'
letter120:    db 0x00,0x00,0x00,0x00,0x00,0xc6,0x6c,0x38,0x38,0x38,0x6c,0xc6,0x00,0x00,0x00,0x00 ; 'x'
letter121:    db 0x00,0x00,0x00,0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x06,0x06,0x7c,0x00 ; 'y'
letter122:    db 0x00,0x00,0x00,0x00,0x00,0xfe,0x0c,0x18,0x30,0x60,0xc0,0xfe,0x00,0x00,0x00,0x00 ; 'z'
letter123:    db 0x00,0x00,0x0e,0x18,0x18,0x30,0x60,0x30,0x18,0x18,0x18,0x0e,0x00,0x00,0x00,0x00 ; '{'
letter124:    db 0x00,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '|'
letter125:    db 0x00,0x00,0x70,0x18,0x18,0x0c,0x06,0x0c,0x18,0x18,0x18,0x70,0x00,0x00,0x00,0x00 ; '}'
letter126:    db 0x00,0x00,0x76,0xdc,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '~'
letter127:    db 0x00,0x00,0x00,0x00,0x10,0x38,0x6c,0xc6,0xc6,0xfe,0x00,0x00,0x00,0x00,0x00,0x00 ; '\x127'
letter128:    db 0x00,0x00,0x3c,0x66,0xc2,0xc0,0xc0,0xc0,0xc2,0x66,0x3c,0x0c,0x06,0x7c,0x00,0x00 ; '\x128'
letter129:    db 0x00,0x00,0xc6,0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x129'
letter130:    db 0x00,0x0c,0x18,0x30,0x00,0x7c,0xc6,0xc6,0xfe,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x130'
letter131:    db 0x00,0x10,0x38,0x6c,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x131'
letter132:    db 0x00,0x00,0xc6,0x00,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x132'
letter133:    db 0x00,0x60,0x30,0x18,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x133'
letter134:    db 0x00,0x38,0x6c,0x38,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x134'
letter135:    db 0x00,0x00,0x00,0x00,0x3c,0x66,0x60,0x60,0x66,0x3c,0x0c,0x06,0x3c,0x00,0x00,0x00 ; '\x135'
letter136:    db 0x00,0x10,0x38,0x6c,0x00,0x7c,0xc6,0xc6,0xfe,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x136'
letter137:    db 0x00,0x00,0xc6,0x00,0x00,0x7c,0xc6,0xc6,0xfe,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x137'
letter138:    db 0x00,0x60,0x30,0x18,0x00,0x7c,0xc6,0xc6,0xfe,0xc0,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x138'
letter139:    db 0x00,0x00,0x66,0x00,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x139'
letter140:    db 0x00,0x18,0x3c,0x66,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x140'
letter141:    db 0x00,0x60,0x30,0x18,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x141'
letter142:    db 0x00,0xc6,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; '\x142'
letter143:    db 0x38,0x6c,0x38,0x00,0x7c,0xc6,0xc6,0xc6,0xfe,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; '\x143'
letter144:    db 0x18,0x30,0x60,0x00,0xfe,0x66,0x60,0x7c,0x60,0x60,0x66,0xfe,0x00,0x00,0x00,0x00 ; '\x144'
letter145:    db 0x00,0x00,0x00,0x00,0x6c,0xfe,0xb2,0x32,0x7e,0xd8,0xd8,0x6e,0x00,0x00,0x00,0x00 ; '\x145'
letter146:    db 0x00,0x00,0x3f,0x6c,0xcc,0xcc,0xff,0xcc,0xcc,0xcc,0xcc,0xcf,0x00,0x00,0x00,0x00 ; '\x146'
letter147:    db 0x00,0x10,0x38,0x6c,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x147'
letter148:    db 0x00,0x00,0xc6,0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x148'
letter149:    db 0x00,0x60,0x30,0x18,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x149'
letter150:    db 0x00,0x30,0x78,0xcc,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x150'
letter151:    db 0x00,0x60,0x30,0x18,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '\x151'
letter152:    db 0x00,0x00,0xc6,0x00,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x06,0x0c,0x78,0x00 ; '\x152'
letter153:    db 0x00,0xc6,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x153'
letter154:    db 0x00,0xc6,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '\x154'
letter155:    db 0x00,0x18,0x18,0x3c,0x66,0x60,0x60,0x60,0x66,0x3c,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x155'
letter156:    db 0x00,0x38,0x6c,0x64,0x60,0xf0,0x60,0x60,0x60,0x60,0xe6,0xfc,0x00,0x00,0x00,0x00 ; '\x156'
letter157:    db 0x00,0x00,0x66,0x66,0x3c,0x18,0x7e,0x18,0x7e,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '\x157'
letter158:    db 0x00,0xf8,0xcc,0xcc,0xf8,0xc4,0xcc,0xde,0xcc,0xcc,0xcc,0xc6,0x00,0x00,0x00,0x00 ; '\x158'
letter159:    db 0x00,0x0e,0x1b,0x18,0x18,0x18,0x7e,0x18,0x18,0x18,0x18,0x18,0xd8,0x70,0x00,0x00 ; '\x159'
letter160:    db 0x00,0x18,0x30,0x60,0x00,0x7c,0x06,0x7e,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; ' '
letter161:    db 0x00,0x0c,0x18,0x30,0x00,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '¡'
letter162:    db 0x00,0x18,0x30,0x60,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '¢'
letter163:    db 0x00,0x18,0x30,0x60,0x00,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x7e,0x00,0x00,0x00,0x00 ; '£'
letter164:    db 0x00,0x00,0x76,0xdc,0x00,0xfc,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; '¤'
letter165:    db 0x76,0xdc,0x00,0xc6,0xe6,0xf6,0xfe,0xde,0xce,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; '¥'
letter166:    db 0x00,0x3c,0x6c,0x6c,0x3e,0x00,0x7e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '¦'
letter167:    db 0x00,0x38,0x6c,0x6c,0x38,0x00,0x7c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '§'
letter168:    db 0x00,0x00,0x30,0x30,0x00,0x30,0x30,0x60,0xc0,0xc6,0xc6,0x7c,0x00,0x00,0x00,0x00 ; '¨'
letter169:    db 0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0xc0,0xc0,0xc0,0xc0,0x00,0x00,0x00,0x00,0x00 ; '©'
letter170:    db 0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0x06,0x06,0x06,0x06,0x00,0x00,0x00,0x00,0x00 ; 'ª'
letter171:    db 0x00,0x18,0x38,0x18,0x18,0x3c,0x00,0xff,0x00,0x7c,0x06,0x3c,0x60,0x7e,0x00,0x00 ; '«'
letter172:    db 0x00,0x18,0x38,0x18,0x18,0x3c,0x00,0xff,0x00,0x1e,0x36,0x66,0xfe,0x06,0x00,0x00 ; '¬'
letter173:    db 0x00,0x00,0x18,0x18,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; '­'
letter174:    db 0x00,0x00,0x00,0x00,0x00,0x22,0x66,0xee,0x66,0x22,0x00,0x00,0x00,0x00,0x00,0x00 ; '®'
letter175:    db 0x00,0x00,0x00,0x00,0x00,0x88,0xcc,0xee,0xcc,0x88,0x00,0x00,0x00,0x00,0x00,0x00 ; '¯'
letter176:    db 0x11,0x44,0x11,0x44,0x11,0x44,0x11,0x44,0x11,0x44,0x11,0x44,0x11,0x44,0x11,0x44 ; '°'
letter177:    db 0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa ; '±'
letter178:    db 0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77 ; '²'
letter179:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; '³'
letter180:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; '´'
letter181:    db 0x18,0x18,0x18,0x18,0x18,0xf8,0x18,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'µ'
letter182:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0xf6,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; '¶'
letter183:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; '·'
letter184:    db 0x00,0x00,0x00,0x00,0x00,0xf8,0x18,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; '¸'
letter185:    db 0x36,0x36,0x36,0x36,0x36,0xf6,0x06,0xf6,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; '¹'
letter186:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'º'
letter187:    db 0x00,0x00,0x00,0x00,0x00,0xfe,0x06,0xf6,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; '»'
letter188:    db 0x36,0x36,0x36,0x36,0x36,0xf6,0x06,0xfe,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '¼'
letter189:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0xfe,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '½'
letter190:    db 0x18,0x18,0x18,0x18,0x18,0xf8,0x18,0xf8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; '¾'
letter191:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xf8,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; '¿'
letter192:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x1f,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'À'
letter193:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Á'
letter194:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Â'
letter195:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x1f,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Ã'
letter196:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ä'
letter197:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Å'
letter198:    db 0x18,0x18,0x18,0x18,0x18,0x1f,0x18,0x1f,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Æ'
letter199:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x37,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Ç'
letter200:    db 0x36,0x36,0x36,0x36,0x36,0x37,0x30,0x3f,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'È'
letter201:    db 0x00,0x00,0x00,0x00,0x00,0x3f,0x30,0x37,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'É'
letter202:    db 0x36,0x36,0x36,0x36,0x36,0xf7,0x00,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ê'
letter203:    db 0x00,0x00,0x00,0x00,0x00,0xff,0x00,0xf7,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Ë'
letter204:    db 0x36,0x36,0x36,0x36,0x36,0x37,0x30,0x37,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Ì'
letter205:    db 0x00,0x00,0x00,0x00,0x00,0xff,0x00,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Í'
letter206:    db 0x36,0x36,0x36,0x36,0x36,0xf7,0x00,0xf7,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Î'
letter207:    db 0x18,0x18,0x18,0x18,0x18,0xff,0x00,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ï'
letter208:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ð'
letter209:    db 0x00,0x00,0x00,0x00,0x00,0xff,0x00,0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Ñ'
letter210:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Ò'
letter211:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x3f,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ó'
letter212:    db 0x18,0x18,0x18,0x18,0x18,0x1f,0x18,0x1f,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ô'
letter213:    db 0x00,0x00,0x00,0x00,0x00,0x1f,0x18,0x1f,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Õ'
letter214:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x3f,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; 'Ö'
letter215:    db 0x36,0x36,0x36,0x36,0x36,0x36,0x36,0xff,0x36,0x36,0x36,0x36,0x36,0x36,0x36,0x36 ; '×'
letter216:    db 0x18,0x18,0x18,0x18,0x18,0xff,0x18,0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Ø'
letter217:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0xf8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'Ù'
letter218:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x1f,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'Ú'
letter219:    db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff ; 'Û'
letter220:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff ; 'Ü'
letter221:    db 0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0,0xf0 ; 'Ý'
letter222:    db 0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f,0x0f ; 'Þ'
letter223:    db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ß'
letter224:    db 0x00,0x00,0x00,0x00,0x00,0x76,0xdc,0xd8,0xd8,0xd8,0xdc,0x76,0x00,0x00,0x00,0x00 ; 'à'
letter225:    db 0x00,0x00,0x78,0xcc,0xcc,0xcc,0xd8,0xcc,0xc6,0xc6,0xc6,0xcc,0xc0,0xc0,0x00,0x00 ; 'á'
letter226:    db 0x00,0x00,0xfe,0xc6,0xc6,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0x00,0x00,0x00,0x00 ; 'â'
letter227:    db 0x00,0x00,0x00,0x00,0xfe,0x6c,0x6c,0x6c,0x6c,0x6c,0x6c,0x6c,0x00,0x00,0x00,0x00 ; 'ã'
letter228:    db 0x00,0x00,0x00,0xfe,0xc6,0x60,0x30,0x18,0x30,0x60,0xc6,0xfe,0x00,0x00,0x00,0x00 ; 'ä'
letter229:    db 0x00,0x00,0x00,0x00,0x00,0x7e,0xd8,0xd8,0xd8,0xd8,0xd8,0x70,0x00,0x00,0x00,0x00 ; 'å'
letter230:    db 0x00,0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x7c,0x60,0x60,0xc0,0x00,0x00,0x00 ; 'æ'
letter231:    db 0x00,0x00,0x00,0x00,0x76,0xdc,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00 ; 'ç'
letter232:    db 0x00,0x00,0x00,0x7e,0x18,0x3c,0x66,0x66,0x66,0x3c,0x18,0x7e,0x00,0x00,0x00,0x00 ; 'è'
letter233:    db 0x00,0x00,0x00,0x38,0x6c,0xc6,0xc6,0xfe,0xc6,0xc6,0x6c,0x38,0x00,0x00,0x00,0x00 ; 'é'
letter234:    db 0x00,0x00,0x38,0x6c,0xc6,0xc6,0xc6,0x6c,0x6c,0x6c,0x6c,0xee,0x00,0x00,0x00,0x00 ; 'ê'
letter235:    db 0x00,0x00,0x1e,0x30,0x18,0x0c,0x3e,0x66,0x66,0x66,0x66,0x3c,0x00,0x00,0x00,0x00 ; 'ë'
letter236:    db 0x00,0x00,0x00,0x00,0x00,0x7e,0xdb,0xdb,0xdb,0x7e,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ì'
letter237:    db 0x00,0x00,0x00,0x03,0x06,0x7e,0xdb,0xdb,0xf3,0x7e,0x60,0xc0,0x00,0x00,0x00,0x00 ; 'í'
letter238:    db 0x00,0x00,0x00,0x00,0x3c,0x60,0x60,0x7c,0x60,0x60,0x3c,0x00,0x00,0x00,0x00,0x00 ; 'î'
letter239:    db 0x00,0x00,0x00,0x7c,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0xc6,0x00,0x00,0x00,0x00 ; 'ï'
letter240:    db 0x00,0x00,0x00,0x00,0xff,0x00,0x00,0xff,0x00,0x00,0xff,0x00,0x00,0x00,0x00,0x00 ; 'ð'
letter241:    db 0x00,0x00,0x00,0x00,0x18,0x18,0x7e,0x18,0x18,0x00,0x00,0xff,0x00,0x00,0x00,0x00 ; 'ñ'
letter242:    db 0x00,0x00,0x00,0x30,0x18,0x0c,0x06,0x0c,0x18,0x30,0x00,0x7e,0x00,0x00,0x00,0x00 ; 'ò'
letter243:    db 0x00,0x00,0x00,0x0c,0x18,0x30,0x60,0x30,0x18,0x0c,0x00,0x7e,0x00,0x00,0x00,0x00 ; 'ó'
letter244:    db 0x00,0x00,0x0e,0x1b,0x1b,0x1b,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18 ; 'ô'
letter245:    db 0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0xd8,0xd8,0xd8,0x70,0x00,0x00,0x00,0x00 ; 'õ'
letter246:    db 0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x7e,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00 ; 'ö'
letter247:    db 0x00,0x00,0x00,0x00,0x00,0x76,0xdc,0x00,0x76,0xdc,0x00,0x00,0x00,0x00,0x00,0x00 ; '÷'
letter248:    db 0x00,0x38,0x6c,0x6c,0x38,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ø'
letter249:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ù'
letter250:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ú'
letter251:    db 0x00,0x0f,0x0c,0x0c,0x0c,0x0c,0x0c,0xec,0x6c,0x6c,0x3c,0x1c,0x00,0x00,0x00,0x00 ; 'û'
letter252:    db 0x00,0xd8,0x6c,0x6c,0x6c,0x6c,0x6c,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ü'
letter253:    db 0x00,0x70,0xd8,0x30,0x60,0xc8,0xf8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ý'
letter254:    db 0x00,0x00,0x00,0x00,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0x7e,0x00,0x00,0x00,0x00,0x00 ; 'þ'
letter255:    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 'ÿ'
  