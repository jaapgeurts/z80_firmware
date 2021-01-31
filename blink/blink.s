; blink test via arduino

.equ DELAY, 0x05

  .org 0x0000

.start:
.on:
  ld a, 0x01
  out (0x00),a
  ld b,DELAY
.delay:
  djnz .delay
.off:
  ld a, 0x00
  out (0x00),a
  ld b,DELAY
.delay2:
  djnz .delay2
  jr .on

  .balign 0x800
