; blink test via arduino

.equiv DELAY, 0x05
.equiv ARD_OUT, 0x20
.equiv CTC_A, 0x00
.equiv SIO_AD, 0x40
.equiv SIO_BD, 0x41
.equiv SIO_AC, 0x42
.equiv SIO_BC, 0x43


  .org 0x0000

start:
  ld sp, 0x9FFF    ; stack pointer at 40k (base = 32k + 8k -1)


;  ld bc, result_msg  ; copy string to ram
;  ld de, 0x8000

;  ld a,1     ; add two values and put in the string
;  ld b,2
;  add a,b
;  add a,'0'
;  ld  (0x8000),a

;  ld bc, 0x8000
;  call printk


; init ctc timer
  call init_ctc

; init serial
  call init_serial

say:
  ld hl,hello_msg
  call printk
  ld hl,rom_msg
  call printk
  ld hl,author_msg
  call printk

read_ser:
  call get_char
  jr   z, read_ser
  call put_char
  jr   read_ser

panic:
  ld hl, kernel_panic_msg
  call printk
  halt

;********************
; rom library routines
;********************
; char in a

put_char:

  out (SIO_AD), a
  ret

get_char:
; check if character available
  ld	a, 0b00000000 ; write to WR1. Next byte is RR0
  out	(SIO_AC), a
  in a, (SIO_AC)
  bit 0, a
  ret z  ; no char available
; if yes, then read and return in a
  in a,(SIO_AD)
  ret


; hl = source address
printk: ; print kernel message to serial (uses pascal strings)
  ld b, (hl)
printk_loop:
  call wait_serial
  inc hl
  ld	a, (hl)
  out  (SIO_AD), a
  djnz printk_loop
  ret

wait_serial:  ; wait for serial port to be free
  ld	a, 0b00000000 ; write to WR1. Next byte is RR0
  out	(SIO_AC), a
wait_serial_again:
  in a, (SIO_AC)
  bit 2,a
  jr  z, wait_serial_again
  ret

  ; init the serial port
init_serial:
; reset channel 0
  ld	a, 0b00110000
  out (SIO_AC), a

; prepare for writing WR4
  ld	a, 0b00000100 ; write to WR1. Next byte is WR4
  out	(SIO_AC), a
  ld	a, 0b00000100               ; set clock rate, No parity, 1 stopbit
  out	(SIO_AC), a

; enable receive (WR3)
  ld	a, 0b00000011
  out	(SIO_AC), a
  ld	a, 0b11000001             ; recv enable
  out	(SIO_AC), a

; write register 5
  ld	a, 0b00000101
  out	(SIO_AC), a
  ld	a, 0b01101000            ; send enable
  out	(SIO_AC), a

  ret

init_ctc:
; set up CTC  - 4800 baud is max achievable with 1MHz
  ld a, 0b00000101 ; control register, prescaler to 16, timer mode
  out (CTC_A), a
;  ld a, 26; time constant for 2400 baud, 0.16% error
  ld a, 13; time constant for 4800 baud, 0.16% error
  out (CTC_A), a

  ret


hello_msg:
  .ascii 16,"Hello from Z80\n\r"
rom_msg:
  .ascii 22,"Z80 rom monitor v0.1\n\r"
author_msg:
  .ascii 30,"(C) January 2021 Jaap Geurts\n\r"
result_msg:
  .ascii 18,"  is the answer.\n\r"
kernel_panic_msg:
  .ascii 12,"Kernel panic"

  .balign 0x800
