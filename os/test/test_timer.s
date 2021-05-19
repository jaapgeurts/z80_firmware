
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

MILLIS_CORRECTION equ 145 ; at 145 ticks skip increment by 1. effectively 145->144

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
  dw  IncCounter
  dw  0
  dw  0


  org 0x4110
SIOISR_TABLE:
  dw 0x0038

IncCounter:
  di
  push hl
  push af

  ld   a,(v_millis_corr)
  inc  a
  cp   MILLIS_CORRECTION
  jp   nz, .skipCorrection
  ld   a,0
  ld   (v_millis_corr),a
  jp   .endInc

.skipCorrection:
  ; takes minimally 31  T states
  ; maximally 129 T states
  ld   hl,v_millis  ; 10

  inc  (hl)         ; 11
  ; byte 1
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 2
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 3
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 4
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  
.endInc:
  pop  af
  pop  hl
  ei
  reti

; printdot:
;   di

;   push hl
;   push bc
;   push af

;   ld   hl,(counter)
;   dec  hl
;   ld   a,h
;   or   l
;   jr   nz,.endisr

;   ld   a,(val)
;   cpl
;   ld   (val),a
;   and  0xfe
;   ld   b,a
;   call setLed

; ;  ld   a,'.'
; ;  rst  PUTC

;   ld   hl,1000
; .endisr
;   ld   (counter),hl
;   pop  af
;   pop  bc
;   pop  hl
;   ei  ; re-enable interrupts
;   reti

initSerial:
  ld   a,0b00000010 ; prepare WR2 (interrupt vector)
  out  (SIO_BC),a
  ld   a,0x10
  out  (SIO_BC),a
  ret

initTimer:
  ld   a,0b10110101; int, timer, scale 256, rising, autostart,timeconst,cont,vector
  out  (CTC_B),a
  ld   a,29 ; 1ms (0.00100694444444s) ; after 145ms skip one increment
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


  org  0x4300
v_millis:      dw  0
               dw  0
v_millis_corr: db  0
welcome_msg:   db  13,"Timer test.",CR,LF
val:           db  0
mymsg:         db  19,"This is my world!",CR,LF