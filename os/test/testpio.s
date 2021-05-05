PIO_AD equ 0x60
PIO_AC equ 0x62
PIO_BD equ 0x61
PIO_BC equ 0x63

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

  ld   a,0b00001111
  out  (PIO_AC),a

again:
  ld   a,0xff
  out  (PIO_AD),a
  call delay
  ld   a,0x00
  out  (PIO_AD),a
  call delay

  jp   again

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


welcome_msg: db 15,"PIO Test app.",CR,LF
