SIO_BD equ 0x41
SIO_BC equ 0x43

CR equ 0x0D
LF equ 0x0A


GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


  org 0x8000
  push hl
  push bc


start:
; disable receiver:
  ld   a, 0b00000011 ; wr3
  out  (SIO_BC),a
  ld   a,0b11000000 ; disable receiver
  out  (SIO_BC),a

; prepare data
  ld   a,0xFF
  out  (SIO_BD),a

  ; enable transmitter
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11101010;   ; DTR low, 8bits, enable TX, RTS low
  out  (SIO_BC), a
  
  ; pull clock low to get keyboard to respond
  call makelow
  call makehigh
  call makelow
  ld   b,60
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

;enable receiver
  ld   a, 0b00000011 ; wr3
  out  (SIO_BC),a
  ld   a,0b11000001 ; enable receiver
  out  (SIO_BC),a

; disable transmitter
  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b11100010;   ; DTR low, 8bits, enable TX, RTS low
  out  (SIO_BC), a

  pop bc
  pop hl
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
