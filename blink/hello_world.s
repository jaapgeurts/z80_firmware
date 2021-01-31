; blink test via arduino

.equiv DELAY, 0x05

  .org 0x0000

start:
  ld bc, hello_msg
loop:
  ld	a, (bc)
  out	(0x00), a
  inc c
  jr  nz,loop

  halt

hello_msg:
  .string "hello from Z80\n\r"

  .balign 0x800
