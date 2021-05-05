SIO_BD equ 0x41
SIO_BC equ 0x43

CR equ 0x0D
LF equ 0x0A

v_ledstate = 0x8300

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

KBID  equ 0xf2
KBRST equ 0xff
KBACK equ 0xfa
KBLED equ 0xed


  org 0x8000

  ld   hl,welcome_msg
  rst  PRINTK

  ld   a,0
  ld   (v_ledstate),a

  ld   d, KBRST ; kbdid
  call sendKbd

readAgain:
  rst  GETC
  jr   z, readAgain

  cp   a,0x98 ; capslock (added 0x40)
  jr   nz,.checkNum  
  ld   d,0xed  ; set/reset leds
  call sendKbd
  ld   a,(v_ledstate)
  xor  4
  ld   (v_ledstate),a
  ld   d,a
  call waitAck
  call sendKbd
  jr   readAgain
.checkNum
  cp   a,0xb7 ; numlock
  jr   nz,.checkScroll  
  ld   d,0xed  ; set/reset leds
  call sendKbd
  ld   a,(v_ledstate)
  xor  2
  ld   (v_ledstate),a
  ld   d,a
  call waitAck
  call sendKbd
  jr   readAgain
.checkScroll
  cp   a,0xbe ; scrolllock
  jr   nz,.printChar
  ld   d,0xed  ; set/reset leds
  call sendKbd
  ld   a,(v_ledstate)
  xor  1
  ld   (v_ledstate),a
  ; wait for ack
  ld   d,a
  call waitAck
  call sendKbd
  jr   readAgain
.printChar
  rst  PUTC
  jr   readAgain

 ; jr  dontwait

  ld  c,2
waitagain:
  ld   b,200
sleep:
  djnz sleep
  dec c
  jr  nz,waitagain

dontwait:
  ld   d,0b00000110
  call sendKbd  

  pop bc
  pop hl
  ret

waitAck:
  ; wait for ack
  rst  GETC
  jr   z, waitAck
  ; compare
  ret


sendKbd:

; disable receiver:
  ld   a, 0b00000011 ; wr3
  out  (SIO_BC),a
  ld   a,0b11000000 ; disable receiver
  out  (SIO_BC),a

; prepare data
  ld   a,d
  out  (SIO_BD),a

  ; enable transmitter
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11101010;   ; DTR low, 8bits, enable TX, RTS low
  out  (SIO_BC), a

  ; generate a pulses until the start bit appears
.genpulse
  ; reset external status
  ld   a,0b00010000
  out  (SIO_BC), a
  call makehigh
  call makelow

  ; wait for DCD to go HIGH (= clock low)
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_BC), a
  in   a, (SIO_BC)
  bit  3,a
  jr   z,.genpulse

  ld   b,40
.delay0:
  djnz .delay0

  ; release clock, data & enable send
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11101010;   ; DTR low, 8bits, enable TX, RTS low
  out  (SIO_BC), a

.waitmore
  ld   a,0b00000001
  out  (SIO_BC),a
  in   a,(SIO_BC)
  bit  0,a
  jr   z, .waitmore

; disable transmitter
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11100010;   ; DTR low, 8bits, enable TX, RTS low
  out  (SIO_BC), a

;enable receiver
  ld   a, 0b00000011 ; wr3
  out  (SIO_BC),a
  ld   a,0b11000001 ; enable receiver
  out  (SIO_BC),a

  ret


makelow:
  ; pull clock low  (DTR low)
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b01101010;   ; DTR high
  out  (SIO_BC), a
  ; wait 100us
  ld   b,5
.delay0:
  djnz .delay0
  ret

makehigh:
  ; pull clock low  (DTR low)
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11101010;   ; DTR high
  out  (SIO_BC), a
  ; wait 100us
  ld   b,5
.delay0:
  djnz .delay0
  ret





;; ****************
; coded using bitbanging

  ; wait 100us
  ld   b,40  
delay1:
  djnz delay1

  ; set to synchronous mode to be able to control RTS
  ld   a,0b00000100 ; WR4
  out  (SIO_BC),a
  ld   a,0b00000001
  out  (SIO_BC),a

  ; pull data low
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b00000000;   ;  RTS high
  out  (SIO_BC), a

  ; release clock
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b10000000;   ; DTR low
  out  (SIO_BC), a

  ld   b,10 ; send 8 data bits, 1 parity bt, 1 stop bit

waitClockLow: 
  ; reset external status
  ld   a,0b00010000
  out  (SIO_BC), a
  ; wait for CTS to go HIGH (= clock low)
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_BC), a
  in   a, (SIO_BC)
  bit  5,a
  jr   z, waitClockLow

; send data 
  ld   a, 0b00000101  ; WR5
  out  (SIO_BC), a
  ld   a, 0b11100010;   ; DTR low, 8bits, disable TX, RTS low
  out  (SIO_BC), a

waitClockHigh: 
  ; reset external status
  ld   a,0b00010000
  out  (SIO_BC), a
  ; wait for CTS to go HIGH (= clock low)
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_BC), a
  in   a, (SIO_BC)
  bit  5,a
  jr   nz, waitClockHigh

  djnz waitClockLow


; set back to asynchronous 
  ld   a,0b00000100 ; WR4
  out  (SIO_BC),a
  ld   a,0b00000101 ; clock 1, 1 stop bit, odd parity
  out  (SIO_BC),a

  ; release clock, data & disable send
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11100010;   ; DTR low, 8bits, disable TX, RTS low
  out  (SIO_BC), a


  ; wait until transmission complete
;waitSerialTX:  ; wait for serial port to be free
;  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
;  out  (SIO_BC), a
;  in   a, (SIO_BC)
;  bit  2,a
;  jr   z, waitSerialTX

  ; start sending data (8bits + parity)


  ; wait for data low (can't wait, no connection)

  ; wait for clock low  (can't wait, no connection)

  ; wait for data & clock release
  

  pop bc
  pop hl
  ret

welcome_msg: ascii 30,"Keyboard host-to-device test",CR,LF
