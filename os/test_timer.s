
CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02


PSG_REG    equ 0x80
PSG_DATA   equ 0x81
PSG_ENABLE equ 7
PSG_PORTA  equ 14
PSG_PORTB  equ 15

SIO_BD equ 0x41
SIO_BC equ 0x43

  org 0x4000

  push hl
  push bc
  push de

  di

  ; set all PSG ports to output
  ld   a,PSG_ENABLE
  out  (PSG_REG),a
  ld   a,0b11111111
  out  (PSG_DATA),a

  ld   b,1<<3
  call setLed

  ld   hl,welcome_msg
  rst  PRINTK

  ld   a,0x41
  ld   i,a

  call initTimer

  call initSerial

  im   2; set interrupt mode 2

  ei

.end:
  pop  de
  pop  bc
  pop  hl
  ret

  org 0x4100
MYISR_TABLE:
  dw  0
  dw  printdot
  dw  0
  dw  0


  org 0x4110
SIOISR_TABLE:
  dw 0x0038

printdot:
  di

  push hl
  push bc
  push af

  ld   hl,(counter)
  dec  hl
  ld   a,h
  or   l
  jr   nz,.endisr

  ld   a,(val)
  cpl
  ld   (val),a
  and  0xfe
  ld   b,a
  call setLed

;  ld   a,'.'
;  rst  PUTC

  ld   hl,1000
.endisr
  ld   (counter),hl
  pop  af
  pop  bc
  pop  hl
  ei  ; re-enable interrupts
  reti

initSerial:
  ld   a,0b00000010 ; prepare WR2 (interrupt vector)
  out  (SIO_BC),a
  ld   a,0x10
  out  (SIO_BC),a
  ret

initTimer:
  ld   a,0b10110101; int, timer, scale 256, rising, autostart,timeconst,cont,vector
  out  (CTC_B),a
  ld   a,29 ; 1ms (0.001006944..s)
  out  (CTC_B),a

  ld   a,0       ; set interrupt vector
  out  (CTC_A),a
  ld   a,0
  out  (CTC_A),a

  ret


; b led value
setLed:
; TODO: change to set led
  ; set leds to 0
  ld   a,PSG_PORTB
  out  (PSG_REG),a
  ld   a,b
  out  (PSG_DATA),a
  ret


welcome_msg:   db 15,"Test program.",CR,LF
counter:       dw  1000
val:           db  0
mymsg:         db  19,"This is my world!",CR,LF