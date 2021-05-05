; IO peripheral port definitions
; CTC ports
CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02
CTC_D equ 0x03


initCtc:
  push af ; store af. it contains the baud rate time constant
; clock is 3,686,400 Hz
; clock frequency of the CTC must be 2x trigger frequency in other words:
; input frequency on TRG0 is 1,843,200Hz (must be at least than half clock freq)
  ld a, 0b01010101 ; control register, external trigger, counter mode, rising edge 
  out  (CTC_A), a
  ; baudrates - Time constant @ 1.8432 MHz
  ; 9600      - 12
  ; 19200     - 6
  ; 57600     - 2
  ; 115200    - 1
  ;ld a, 1 ; 115200 @ 1.8432 MHz
  pop  af
  out  (CTC_A), a
  ret
