  include "consts.inc"

PSG_FINEA   equ 0
PSG_COARSEA equ 1
PSG_AMPLA   equ 8

PSG_FINEB   equ 2
PSG_COARSEB equ 3
PSG_AMPLB   equ 9

PSG_FINEC   equ 4
PSG_COARSEC equ 5
PSG_AMPLC   equ 10

PSG_ENABLE  equ 7
PSG_PORTA   equ 14
PSG_PORTB   equ 15

  global initPSG
  global setLed

  section .text

; b led value
setLed:
; TODO: change to set led
  ; set leds to 0
  ld   a,PSG_PORTB
  out  (PSG_REG),a
  ld   a,b
  out  (PSG_DATA),a
  ret

initPSG:  ; set PSG ports to correct input and output
  ld   a,PSG_ENABLE
  out  (PSG_REG),a
  ld   a,0b10111111
  out  (PSG_DATA),a
