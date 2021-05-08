   include "consts.inc"

   global initSerialKeyboard
   global handleKeyboard

; keyboard codes 
L_SHIFT equ 0x12
R_SHIFT equ 0x59


  section .bss

    dsect
      v_shifted:    db 0 ; shift keystate
    dend


  section .text

getKeyboardChar:
; check if character available
  ld   a, 0b00000000 ; write to WR1. Next byte is RR0
  out  (SIO_BC), a
  in   a,(SIO_BC)
  bit  0, a
  jr   z,getKeyboardChar  ; no char available
; if yes, then read and return in a
  in   a,(SIO_BD)
  ret

  ; init the serial port
initSerialKeyboard:

  ld   a,0
  ld   (v_shifted),a

; reset channel B
  ld   a, 0b00110000
  out  (SIO_BC), a

; prepare for writing WR4, must write WR4 first
  ld   a, 0b00000100 ; write to WR0. Next byte is WR4
  out  (SIO_BC), a
  ld   a, 0b00000101              ; set clock rate, odd parity, 1 stopbit
  out  (SIO_BC), a

  ; write to register 5

  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b10000010;   ; DTR low and RTS low (results in clock and data high)
  out  (SIO_BC), a

  ; enable interrupt on char (WR1)
  ld   a, 0b00000001 ; 
  out  (SIO_BC), a
  ld   a, 0b00001000 ; int on first Rx char
  out  (SIO_BC), a

; enable receive (WR3)
  ld   a, 0b00000011
  out  (SIO_BC), a
  ld   a, 0b11000001             ; recv enable; 8bits/char
  out  (SIO_BC), a

  ret

; KEYBOARD FUNCTIONS

handleKeyboard:

  push hl
  push bc
  ; translate scan code
  ; ignore release codes
  cp   0xf0 ; break code
  jr   nz, .check7bit
.read_kbd_break:
  call getKeyboardChar  ;read the next char
  cp   L_SHIFT
  jr   z,.read_kbd_unshifted:
  cp   R_SHIFT
  jr   nz,.read_kbd_end:
.read_kbd_unshifted:
  ld   a,0
  ld   (v_shifted),a
  jr   .read_kbd_end

.check7bit:
  ; if larger than 80; just store it otherwise translate
  cp   0x80
  jr   nc, .store
  push af
  cp   L_SHIFT
  jr   z,.read_kbd_set_shifted:
  cp   R_SHIFT
  jr   nz,.read_kbd_fetch:
.read_kbd_set_shifted:
  ld   a,1
  ld   (v_shifted),a
  pop  af
  jr   .read_kbd_end
 
.read_kbd_fetch:
  ld   hl,trans_table_normal
  ld   a,(v_shifted)
  cp   1
  jr   nz,.read_kbd_fetch_2
  ld   hl,trans_table_shifted
.read_kbd_fetch_2:
  pop  af
  ld   b, 0
  ld   c, a
  add  hl, bc
  ld   a,(hl)

.store:
  call putKey  ; store the key in the ring buffer

.read_kbd_end:
  pop  bc
  pop  hl
  ret

SQOT equ 0x27


;; PS2/ scancode set 2

  section .rodata

trans_table_normal:
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0  ; number at the start the array
  db 0x00,0x00,0x00,0x00,0x00,0x09, '`',0x00 ; 8
  db 0x00,0x00,0x00,0x00,0x00, 'q', '1',0x00 ; 10
  db 0x00,0x00, 'z', 's', 'a', 'w', '2',0x00 ; 18
  db 0x00, 'c', 'x', 'd', 'e', '4', '3',0x00 ; 20
  db 0x00, ' ', 'v', 'f', 't', 'r', '5',0x00 ; 28
  db 0x00, 'n', 'b', 'h', 'g', 'y', '6',0x00 ; 30
  db 0x00,0x00, 'm', 'j', 'u', '7', '8',0x00 ; 38
  db 0x00, ',', 'k', 'i', 'o', '0', '9',0x00 ; 40
  db 0x00, '.', '/', 'l', ';', 'p', '-',0x00 ; 48
  db 0x00,0x00, "'",0x00, '[', '=',0x00,0x00 ; 50
  db 0x98,0x00,0x0D, ']',0x00, "\",0x00,0x00 ; 58 ; added 58=98
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x08,0x00 ; 60
  db 0x00, '1',0x00, '4', '7',0x00,0x00,0x00 ; 68
  db  '0', '.', '2', '5', '6', '8',0x1b,0xb7 ; 70 ; added 77=b7
  db 0x00, '+', '3', '-', '*', '9',0xbe,0x00 ; 78 ; added 7e=0xbe
trans_table_shifted:
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0   ; number at the start the array
  db 0x00,0x00,0x00,0x00,0x00,0x09, '~',0x00 ; 8
  db 0x00,0x00,0x00,0x00,0x00, 'Q', '!',0x00 ; 10
  db 0x00,0x00, 'Z', 'S', 'A', 'W', '@',0x00 ; 18
  db 0x00, 'C', 'X', 'D', 'E', '$', '#',0x00 ; 20
  db 0x00, ' ', 'V', 'F', 'T', 'R', '%',0x00 ; 28
  db 0x00, 'N', 'B', 'H', 'G', 'Y', '^',0x00 ; 30
  db 0x00,0x00, 'M', 'J', 'U', '&', '*',0x00 ; 38
  db 0x00, '<', 'M', 'I', 'O', ')', '(',0x00 ; 40
  db 0x00, '>', '?', 'L', ':', 'P', '_',0x00 ; 48
  db 0x00,0x00, '"',0x00, '{', '+',0x00,0x00 ; 50
  db 0x98,0x00,0x0D, '}',0x00, "|",0x00,0x00 ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x08,0x00 ; 60
  db 0x00, '1',0x00, '4', '7',0x00,0x00,0x00 ; 68
  db  '0', '.', '2', '5', '6', '8',0x1b,0xb7 ; 70
  db 0x00, '+', '3', '-', '*', '9',0xbe,0x00 ; 78

