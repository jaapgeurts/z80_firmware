
CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


org 0x4000

  push hl
  push bc
  push de

  ld   hl,welcome_msg
  rst  PRINTK


.end:
  pop  de
  pop  bc
  pop  hl
  ret

welcome_msg:   db 15,"Test program.",CR,LF