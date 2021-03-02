SIO_BD equ 0x41
SIO_BC equ 0x43

CR equ 0x13
LF equ 0x10

L_SHIFT equ 0x12
R_SHIFT equ 0x59

v_shifted: equ 0x8250 ; variable

  org 0x8000

  ld ix,(0x0200 + 8)

  ld hl, hello_msg

  ld bc, next  ; ROM call printk
  push bc
  jp (ix)

next:

  call init_serial

  ld   a,0
  ld   (v_shifted),a

again:
  call get_char
  ; translate scan code
  ; ignore release codes
  cp 0xf0 ; break code
  jr nz, make
break:
  call get_char
  cp   L_SHIFT
  jr   z,unshifted:
  cp   R_SHIFT
  jr   nz,again:
unshifted:
  ld   a,0
  ld   (v_shifted),a
  jr   again

make:
  push af
  cp   L_SHIFT
  jr   z,set_shifted:
  cp   R_SHIFT
  jr   nz,fetch:
set_shifted:
  ld   a,1
  ld   (v_shifted),a
  jr   again
  
fetch:
  ld   hl,trans_table_normal
  ld   a,(v_shifted)
  cp   1
  jr   nz,fetch_2
  ld   hl, trans_table_shifted
fetch_2:
  pop  af
  ld   b, 0
  ld   c, a
  add  hl, bc
  ld   a,(hl)

  ld   bc, next2  ; ROM call putchar
  push bc ; push return address on stack
  ld   ix,(0x0200 + 4)
  jp   (ix)
next2:
  jr   again

;; support routines

put_char: ; char in a
  push af
  call wait_serial  ; make sure we can send
  pop af
  out (SIO_BD), a
  ret

get_char:
; check if character available
  ld   a, 0b00000000 ; write to WR1. Next byte is RR0
  out  (SIO_BC), a
  in   a,(SIO_BC)
  bit  0, a
  jr   z,get_char  ; no char available
; if yes, then read and return in a
  in   a,(SIO_BD)
  ret


wait_serial:  ; wait for serial port to be free
  ld	a, 0b00000000 ; write to WR1. Next byte is RR0
  out	(SIO_BC), a
  in a, (SIO_BC)
  bit 2,a
  jr  z, wait_serial
  ret

  ; init the serial port
init_serial:
; reset channel 1
  ld	a, 0b00110000
  out (SIO_BC), a

; prepare for writing WR4
  ld	a, 0b00000100 ; write to WR1. Next byte is WR4
  out	(SIO_BC), a
  ld	a, 0b00000101              ; set clock rate, odd parity, 1 stopbit
  out	(SIO_BC), a

; enable receive (WR3)
  ld	a, 0b00000011
  out	(SIO_BC), a
  ld	a, 0b11000001             ; recv enable; 8bits/char
  out	(SIO_BC), a

; write register 5
;  ld	a, 0b00000101
;  out	(SIO_BC), a
;  ld	a, 0b01100000            ; send disable
;  out	(SIO_BC), a

  ret


hello_msg: ascii 14,"Keyboard TST",CR,LF

;; PS2/ scancode set 2

SQOT equ 0x27
trans_table_normal:
  db 0x00,0x00,0x00,0x00,0x00,0x00 ; 0
  db 0x00,0x00,0x00,0x00,0x00,0x0D,0x09,0x0E ; 8
  db  '`',0x00,0x00,0x00,0x00,0x00,0x00, 'q' ; 10
  db  '1',0x00,0x00,0x00, 'z', 's', 'a', 'w' ; 18
  db  '2',0x00,0x00, 'c', 'x', 'd', 'e', '4' ; 20
  db  '3',0x00,0x00, ' ', 'v', 'f', 't', 'r' ; 28
  db  '5',0x00,0x00, 'n', 'b', 'h', 'g', 'y' ; 30
  db  '6',0x00,0x00,0x00, 'm', 'j', 'u', '7' ; 38
  db  '8',0x00,0x00, ',', 'k', 'i', 'o', '0' ; 40
  db  '9',0x00,0x00, '.', '/', 'l', ';', 'p' ; 48
  db  '-',0x00,0x00,0x00, "'",0x00, '[', '=' ; 50
  db 0x00,0x00,0x00,0x00,0x00, ']',0x00, "\" ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 60
  db 0x00,0x08,0x00,'1' ,0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78
trans_table_shifted:
  db  0x00,0x00,0x00,0x00,0x00,0x00 ; 0
  db 0x00,0x00,0x00,0x00,0x00,0x0D,0x09,0x0E ; 8
  db  '~',0x00,0x00,0x00,0x00,0x00,0x00, 'Q' ; 10
  db  '!',0x00,0x00,0x00, 'Z', 'S', 'A', 'W' ; 18
  db  '@',0x00,0x00, 'C', 'X', 'D', 'E', '$' ; 20
  db  '#',0x00,0x00, ' ', 'V', 'F', 'T', 'R' ; 28
  db  '%',0x00,0x00, 'N', 'B', 'H', 'G', 'Y' ; 30
  db  '^',0x00,0x00,0x00, 'M', 'K', 'U', '&' ; 38
  db  '*',0x00,0x00, '<', 'K', 'I', 'O', ')' ; 40
  db  '(',0x00,0x00, '>', '?', 'L', ':', 'P' ; 48
  db  '_',0x00,0x00,0x00, '"',0x00, '{', '+' ; 50
  db 0x00,0x00,0x00,0x00,0x00, '}',0x00, '|' ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 60
  db 0x00,0x08,0x00,'1' ,0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78