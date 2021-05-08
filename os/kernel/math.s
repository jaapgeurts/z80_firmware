  section .text

  global multiply
  global division

;   hl = b * c
multiply:
  push de
  push bc
  ld   hl,0
  ld   a,b
  or   a
  jr   z,.end
  ld   d,0
  ld   e,c
.mul_loop:
  add  hl,de
  djnz .mul_loop
.end:
  pop  bc
  pop  de
  ret

; hl by c, quotient in hl, remainder in a
division:
  push bc
  xor	a
  ld	b, 16

.loop:
  add	hl, hl
  rla
  jr	c, $+5
  cp	c
  jr	c, $+4

  sub	c
  inc	l
   
  djnz	.loop
  pop   bc 
  ret
  