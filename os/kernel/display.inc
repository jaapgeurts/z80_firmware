; TFT display
TFT_C equ 0xA0
TFT_D equ 0xA1

; *********************
; *** DPY REGISTERS ***
; *********************

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

; terminal size, total chars, font sizes
; 40x20,  800, 12x16
; 60x20, 1200,  8x16
; 60x40, 2400,  8x8
; 80x40, 3200,  6x8
FONTW equ 8
FONTH equ 16
BYTESPERFONT equ (FONTW * FONTH) / 8
COLS equ DPYWIDTH / FONTW
ROWS equ DPYHEIGHT / FONTH
TOTALCHARS equ COLS * ROWS
DPYWIDTH equ 480
DPYHEIGHT equ 320
SCROLL_LINES equ COLS*4

; print char to lcd
; char in A
putDisplayChar: 
  push hl
  push de
  push bc

  ld   de,(v_cursor)
 
  cp   BS
  jr   nz,.checkCR
  ; handle BS - remove previous char
  ; TODO: make sure de != 0
  dec  de
  ld   (v_cursor),de
  jr   .end_nodraw

.checkCR:
  cp   CR
  jr   nz,.checkLF
  ; recalculate the cursor position
  ld   c,COLS
  push de
  ex   de,hl ; put cursor in hl
  call division ; a = remainder
  or   a ; clear carry flag
  ld   b,0
  ld   c,a
  pop  hl
  sbc  hl,bc
  ld   (v_cursor),hl
  jr   .end_nodraw

.checkLF:
  cp   LF
  jr   nz,.placeChar
  ;   line feed
  ld   hl,COLS
  add  hl,de 
  ex   de,hl
  call checkScrollCursor ; scroll screen if de > 1200
  ld   (v_cursor),de
  jr   .end_nodraw

.placeChar
  push de  ; store start location
  push de
  pop  hl ; ld   hl,de
  ; add cursor index to screenbuf start
  ld   c,a ; store char
  ld   a,h
  or   SCREEN_BASE_MASK_H
  ld   h,a
  ld   (hl),c ; save char
  inc  de

  call checkScrollCursor

  ld   (v_cursor),de
  pop  bc ; load original cursor back

  or   a ; clear carry
  ld   hl,(v_cursor)
  sbc  hl,bc
  jr   z,.end_nodraw
  jp   m,.end_nodraw ; TODO: why is start after the end?
  
  ; update screen
  call displayRepaint ; bc start; de end

.end_nodraw:
  pop  bc
  pop  de
  pop  hl
  ret

initDisplay:
  push bc

  ld   a,0x01   ; reset TFT display
  out  (TFT_C),a

  ld   b,0xff
delay1:
  djnz  delay1

 ; TODO: print what has been detected
;  ld   a,ILI_READ_ID4  ; read id
;  out  (TFT_C),a
;  in   a,(TFT_D); dummy data
;  in   a,(TFT_D) ; not relevant
;  in   a,(TFT_D)
;  call printhex
;  in   a,(TFT_D)
;  call printhex

; TODO: reduce by writing a loop and sending data from an array
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

  pop  bc
  ret


; push the string into the buffer; then redraw the screen
; string in hl
printd: 
  push hl
  push bc
  push de

  ld  de,(v_cursor) ; remember start pos
  ld  (v_tmp),de

  ; add cursor index to screenbuf start
  ld   a,d
  or   SCREEN_BASE_MASK_H
  ld   d,a

  ld   b,(hl) ; load counter
.printd_loop:
  inc  hl
  ld   a, (hl)
  ; check for CR and LF
  cp   CR
  jr   nz, .checkLF
  ; move cursor to home
  ; get remainder
  push hl ; store the str pointer
  push bc ; store the str index counter
  push de ; ld hl,de
  pop  hl ; hl contains the v_cursor
  
  ld   a,h ; convert screen_buf ptr into cursor
  and  SCREEN_PTR_MASK_H
  ld   h,a

  ld   c,COLS
  call division ; a = remainder
  scf
  ccf ; clear carry flag
  ld   b,0
  ld   c,a
  ex   de,hl ; ld hl with v_cursor(de)
  sbc  hl,bc
  ex   de,hl ; ld result back into v_cursor(de)
  pop  bc  ; restore the str index counter
  pop  hl  ; restore the str pointer
  jr   .endif
.checkLF:
  cp   LF
  jr   nz,.storeChar

  push hl ; store the str pointer

  ; add cols to cursor (= LF)
  ld   hl,COLS
  add  hl,de 
  ex   de,hl  ;push result back into de (screen_buf ptr)


  call checkScrollBuffer

  pop  hl ; restore the str pointer
  jr   .endif
.storeChar:
  ld   (de),a
  inc  de
  call checkScrollBuffer
.endif:
  djnz .printd_loop

  ; subtract screenbuf
  ld   a,d ; convert screen_buf ptr into cursor
  and  SCREEN_PTR_MASK_H
  ld   d,a
  ld   (v_cursor),de
  
  ; if both are same, then don't paint
  ; TODO: bugfix for CR
  ld   hl,(v_tmp)
  sbc  hl,de
  jr   z,.skippaint

  ld   bc,(v_tmp)
;  ld   de,(v_cursor)
  call displayRepaint
.skippaint:
  pop  de
  pop  bc
  pop  hl

  ret

checkScrollCursor:
  push hl
  push bc

  or   a ; clear carry
  ; check if screen if de > 1200 then scroll
  ld   hl, TOTALCHARS-1
  sbc  hl,de
  ; hl contains result
  jp   p,.noscroll 

  call displayScrollBuffer

  push de
  ld   bc,0
  ld   de,TOTALCHARS
  call displayRepaint
  pop  de

  ; subtract COLS from de
  or   a ; clear carry
  ld   hl,SCROLL_LINES
  ex   de,hl
  sbc  hl,de
  ex   de,hl

.noscroll:
  pop  bc
  pop  hl
  ret 

; TODO: there are two versions; check if we can merge
checkScrollBuffer:
  push hl
  push bc

  or   a ; clear carry
  ; check if screen if de >= 1200 then scroll
  ld   hl, (v_screenbuf+TOTALCHARS)-1
  sbc  hl,de
  ; hl contains result
  jp   p,.noscroll 

  call displayScrollBuffer

  push de
  ld   bc,0
  ld   de,TOTALCHARS
  call displayRepaint
  pop  de

  ; subtract COLS from de
  or   a ; clear carry
  ld   hl,SCROLL_LINES
  ex   de,hl
  sbc  hl,de
  ex   de,hl

.noscroll:
  pop  bc
  pop  hl
  ret 

; bc: start, de: end
displayRepaint:
  push hl
  push bc
  push de

  ; draw from start(bc) to end(de)
  ld   hl,v_screenbuf
  add  hl,de ; save end location
  ld   (v_tmp2),hl

  ; calculate startx = (start%60 ) * fontw
  ; calculate starty = (start/60) * fonth
  push bc
  push bc
  pop  hl ; ld hl,bc
  ld   c,60
  call division ; hl / c = hl rem a
  push hl ; push quotient (y)
  ; calc x
  ld   b,a
  ld   c,FONTW
  call multiply ; result in hl
  ld   (vt_xstart),hl
  ; calc y
  pop  hl
  ld   b,l
  ld   c,FONTH
  call multiply ; result in hl
  ld   (vt_ystart),hl
  
  ; go through the array. if dirty draw

  pop  bc
  ld   hl,v_screenbuf
  add  hl,bc
  push hl
  pop  bc ; ld bc,hl: bc contains start location in screenbuf

.nextGlyph:

  ; set display start and end position
  push bc
  ld   hl,(vt_xstart)
  push hl ; save start
  ld   bc,FONTW-1
  add  hl,bc
  ex   de,hl ; end in de
  pop  hl ; restore start
  call displaySetX1X2  ; from hl -> de
  ld   hl,(vt_ystart)
  push hl   ; save start
  ld   bc,FONTH-1
  add  hl,bc
  ex   de,hl ; end in de
  pop  hl
  call displaySetY1Y2
  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a
  pop  bc

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
;  ld   a,0xff
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
  ld   de,(v_tmp2)
  ld   a,b
  cp   d
  jr   nz,.incxy
  ld   a,c
  cp   e
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
  ; increase y
  ld  hl,(vt_ystart)
  ld  de,FONTH
  add hl,de
  ld  (vt_ystart),hl
  ld  hl,0  ;set x-start to zero
.next1:
  ld  (vt_xstart),hl
  jp  .nextGlyph

.printLetEnd:
  pop  de
  pop  bc
  pop  hl
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

displayClearBuffer:
  push hl
  push bc
 ; first clear backing store
  ld   hl,v_screenbuf
  ld   bc,TOTALCHARS
.nextclear:
  ld   (hl),0
  inc  hl
  dec  bc
  ld   a,b
  or   c
  jr   nz,.nextclear
  pop  bc
  pop  hl
  ret

displayClear:
  push bc
  push de
  push hl

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
  pop  hl
  pop  de
  pop  bc
  ret

displayScrollBuffer:
  push hl
  push bc
  push de

  ld   bc,TOTALCHARS - SCROLL_LINES ; scroll quarter of the screen
  ld   de,v_screenbuf
  ld   hl,v_screenbuf+SCROLL_LINES
.dpyLoopScroll:
  ld   a,(hl)
  ld   (de),a
  inc  hl
  inc  de
  dec  bc
  ld   a,b
  or   c
  jr   nz,.dpyLoopScroll

; clear last line
  ld   b,SCROLL_LINES
  ld   hl,v_screenbuf+TOTALCHARS-SCROLL_LINES
.dpyLoopEmpty
  ld   (hl),0
  inc  hl
  djnz .dpyLoopEmpty

  pop  de
  pop  bc
  pop  hl
  ret