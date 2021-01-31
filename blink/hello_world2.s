; blink test via arduino

.equiv DELAY, 0x05
.equiv ARD_OUT, 0x20
.equiv CTC_A, 0x00

  .org 0x0000

start:
  ld sp, 0x9FFF    ; stack pointer at 40k (base = 32k + 8k -1)

  ld a,'%'
  ld (0x8000),a
  ld a,'*'
  ld a, (0x8000)
  out  (ARD_OUT), a

  ld bc, hello_msg
  call printk

  ld bc, rom_msg
  call printk

  ld bc, author_msg
  call printk

  ld bc, result_msg  ; copy string to ram
  ld de, 0x8000
str_copy:
  ld a,(bc)  ; load current char
  ld (de),a  ; write current char (including \0 char)
  cp a, 0
  jr  z, end_copy ; get out if \0 char
  inc c      ; next src chr
  inc e      ; next dst chr
  jr str_copy
end_copy:

  ld a,1     ; add two values and put in the string
  ld b,2
  add a,b
  add a,'0'
  ld  (0x8000),a

  ld bc, 0x8000
  call printk

; set up CTC
  ld a, 0b00000101 ; control register, prescaler to 16, timer mode
  out (CTC_A), a
  ld a, 26; time constant for 2400 baud, 0.16% error
  out (CTC_A), a

  halt

printk:
  ld	a, (bc)
  cp a, 0
  jp z, end_printk
  out  (ARD_OUT), a
  inc c
  jr printk
end_printk:
  ret


hello_msg:
  .string "Hello from Z80\n\r"

rom_msg:
  .string "Z80 rom monitor v0.1\n\r"
author_msg:
  .string "(C) January 2021 Jaap Geurts\n\r"
result_msg:
  .string "  is the answer.\n\r"

  .balign 0x800
