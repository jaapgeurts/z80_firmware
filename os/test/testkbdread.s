SIO_BD equ 0x41
SIO_BC equ 0x43

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

KBID  equ 0xf2
KBRST equ 0xff
KBACK equ 0xfa
KBLED equ 0xed


  org 0x8000

start:
  push hl

  ld   hl,welcome_msg
  rst  PRINTK

  ld   a,'.'
  rst  PUTC

  call initSerialKeyboard

.getKeyboardChar:
; check if character available
  ld   a, 0b00000000 ; write to WR1. Next byte is RR0
  out  (SIO_BC), a
  in   a,(SIO_BC)
  bit  0, a
  jr   z,.getKeyboardChar  ; no char available
; if yes, then read and return in a
  in   a,(SIO_BD)
  
  rst  PUTC

  jr   .getKeyboardChar

  pop hl
  ret

initSerialKeyboard:
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

  welcome_msg: ascii 23,"Keyboard polling test",CR,LF