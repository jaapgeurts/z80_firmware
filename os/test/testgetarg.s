
CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

 org 0x8000

start:

  push hl
  push bc

  ld   hl,welcome_msg
  rst  PRINTK

  rst  READLINE
  call println

  call firstToken
.nextArg:
  ld   a,c
  cp   0
  jr   z,.done
  rst  PRINTK
  call println
  call nextToken
  jr   .nextArg

.done:
  ld   hl,done_msg
  rst  PRINTK

  pop  bc
  pop  hl
  ret

println:
  ld   a,CR
  rst  PUTC
  ld   a,LF
  rst  PUTC
  ret

; returns first token in hl. Tokens separated by spaces only
; destructive to string
; pre:
;   HL pointer to string
; post:
;   HL pointer to first token
;   B chars remaining in original string after the token
;   C chars in the current token 
firstToken:
  ld   b,(hl)
  ld   c,0
getToken: ; do not call directly
  call skipSpace
  ; store hl (start of string)
  push hl
  call findSpace
  pop  hl
  ld   a,c  ; amount
  ld   (hl),a
  ret

nextToken:
  push de
  ld   c,0
  ld   d,0
  ld   e,(hl)
  add  hl,de
  inc  hl
  pop  de
  call getToken
  ret

; post:
;   B returns amount of spaces skipped
skipSpace:
  ld   a,b
  cp   0  ; string is empty
  ret  z
.nextSpace
  ; move forward until we discover a letter
  ld   a,b
  cp   0  ; while we're not at the end of the string
  jr   z,.done
  inc  hl
  dec  b
  ld   a,(hl)
  cp   ' ' ; if a space
  jr   z, .nextSpace ; found space
.done:
  inc  b
  dec  hl ; set pointer to start of string
  ret

; C returns amount of letters skipped
findSpace:
  ld   a,b
  cp   0    ; while we're not at the end of the string
  ret  z ; nothing in the string
.next_letter:
  ; move forward until we discover a space
  ld   a,b
  cp   0  ; while we're not at the end of the string
  jr   z,.done
  inc  hl
  inc  c
  dec  b
  ld   a,(hl)
  cp   ' ' ; if not a space
  jr   nz, .next_letter ; found space
  dec  c
.done:
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

welcome_msg:   db 17,"Argument tester",CR,LF
done_msg:      db 6,"Done",CR,LF
hexconv_table:    db "0123456789ABCDEF"