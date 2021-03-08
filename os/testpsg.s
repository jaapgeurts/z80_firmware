PSG_REG equ 0x80
PSG_DATA equ 0x81

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


  org 0x8000
  push hl
  push bc

  ld   hl, welcome_msg
  rst  PRINTK ; call printk

  ; set port to output
  ld   a,7
  out  (PSG_REG),a
  ld   a,0b01111111
  out  (PSG_DATA),a

again:
  ld   a,14
  out  (PSG_REG),a
  ld   a, 0xff
  out  (PSG_DATA),a
  call delay
  ld   a,14
  out  (PSG_REG),a
  ld   a, 0x00
  out  (PSG_DATA),a
  call delay
  jr   again


  pop  bc
  pop  hl
  ret

delay:
  push hl
  push bc
  ld   h,0xff
  ld   l,0xff
  ld   b,0
  ld   c,0
.delay_again:
  sbc  hl,bc
  jr   z,.delay_end
  dec  hl
  jr   .delay_again
.delay_end:
  pop  bc
  pop  hl
  ret


welcome_msg: db 14,"PSG test app",CR,LF