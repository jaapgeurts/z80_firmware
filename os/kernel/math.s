  section .text

  global multiply
  global multiply16
  global divide

;   hl = b * c
; TODO: improve to fast multiply
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

; multiplies de by a and places the result in ahl
multiply16:
  push bc
  ld   c, 0
  ld   h, c
  ld   l, h

  add  a, a      ; optimised 1st iteration
  jr   nc, $+4
  ld   h,d
  ld   l,e

  ld   b, 7
.loop:
  add  hl, hl
  rla
  jr   nc, $+4
  add  hl, de
  adc  a, c            ; yes this is actually adc a, 0 but since c is free we set it to zero and so we can save 1 byte and up to 3 T-states per iteration
   
  djnz .loop
  pop  bc
  ret



; hl by c, quotient in hl, remainder in a
divide:
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
  