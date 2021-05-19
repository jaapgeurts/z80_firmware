  include "consts.inc"

  global initSerialConsole
  global putSerialChar
  global prints


  section .text

prints:
  push hl
  push bc
  ld   b,(hl)
.printk_loop:
  call waitSerialTX
  inc  hl
  ld   a, (hl)
  out  (SIO_AD), a
  djnz .printk_loop
  pop  bc
  pop  hl
  ret

  ; init the serial port
initSerialConsole:
; reset channel 0
  ld	a, 0b00110000
  out (SIO_AC), a

; prepare for writing WR4 - datasheet says write to WR4 first then other registers
  ld	a, 0b00000100 ; write to WR0. Next byte is WR4
  out	(SIO_AC), a
  ld	a, 0b01000100               ; 16x prescaler, No parity, 1 stopbit
  out	(SIO_AC), a

; enable interrupt on char (WR1)
  ld	a, 0b00000001 ; 
  out	(SIO_AC), a
  ld	a, 0b00011000 ; int on all Rx chars
  out	(SIO_AC), a

; enable receive (WR3)
  ld	a, 0b00000011
  out	(SIO_AC), a
  ld	a, 0b11000001             ; recv enable; 8bits / char
  out	(SIO_AC), a

; write register 5
  ld	a, 0b00000101
  out	(SIO_AC), a
  ld	a, 0b01101000            ; send enable
  out	(SIO_AC), a

  ld   a,0b00000010 ; prepare WR2 (interrupt vector)
  out  (SIO_BC),a
  ld   a,0x08
  out  (SIO_BC),a

  ret

putSerialChar:
  push af
  call waitSerialTX  ; make sure we can send
  pop  af
  out  (SIO_AD), a
  ret

getSerialChar:
; check if character available
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  0, a
  ret  z  ; no char available
; if yes, then read and return in a
  in   a,(SIO_AD)
  ret

getSerialCharWait:
; check if character available
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  0, a
  jr   z,getSerialCharWait  ; no char available
; if yes, then read and return in a
  in   a,(SIO_AD)
  ret

waitSerialTX:  ; wait for serial port to be free
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  2,a
  jr   z, waitSerialTX
  ret

rts_off:
  ld   a,005h     ;write into WR0: select WR5
  out  (SIO_AC),A
  ld   a,0E8h     ;DTR active, TX 8bit, BREAK off, TX on, RTS inacive
  out  (SIO_AC),A
  ret
  
rts_on:
  ld   a,005h     ;write into WR0: select WR5
  out  (SIO_AC),A
  ld   a,0EAh     ;DTR active, TX 8bit, BREAK off, TX on, RTS active
  out  (SIO_AC),A
  ret