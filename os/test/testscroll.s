
CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

TOTALCHARS equ 1200

  dsect
    org 0x9000
    v_charstart: dsw 1
    v_cursor:  dsw 1
  dend

  org 0x5000

  push hl
  push bc
  push de

  ld   bc,1160
  ld   (v_charstart),bc
  

  ld   hl,welcome_msg
  rst  PRINTK

  ld   bc,1159
  ld   (v_cursor),bc
  ld   de,1160

  call checkScrollCursor


.end:
  pop  de
  pop  bc
  pop  hl
  ret

checkScrollCursor:
  push hl
  push bc

  ; if de is over the edge
  ; reset to start
  ld   a,d
  cp   TOTALCHARS >> 8
  jr   nz, .endrollover
  ld   a,e
  cp   TOTALCHARS & 0xff
  jr   nz, .endrollover
  ld   de,0 ; set DE to 0
.endrollover:

  ld  bc,(v_cursor)

 ; check if we've crossed the bounds
  or   a ; clear carry
  ; check if screen is part charstart
  ld   hl, (v_charstart)
  sbc  hl,de
  ; hl contains result
  jr   z,.doscroll ; end is just over the linestart
  jp   p,.noscroll ; end is before the linestart so no scroll
.checkscroll1:
  ld   a,'1'
  rst PUTC
  ; cursor is after linestart
  or   a ; clear carry
  ld   hl,(v_charstart) ; check if bc is before linestart
  sbc  hl,bc
  jr   z,.checkscroll2
  jp   p, .doscroll ; if before start then must scroll
.checkscroll2
  ld   a,'2'
  rst PUTC
  ; bc was after the start, one more check
  ; check if bc < de
  or   a ; clear carry
  ld   h,d
  ld   l,e
  sbc  hl,bc    
  jp   p,.noscroll

.doscroll:
  ld   hl,scroll_msg
  rst  PRINTK

.noscroll:
  pop  bc
  pop  hl
  ret 

welcome_msg:   db 20,"Test scrollcursor.",CR,LF
scroll_msg:    db  8,"scroll",CR,LF