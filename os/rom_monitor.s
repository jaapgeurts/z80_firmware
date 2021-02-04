; Z80 homebrew single board computer ROM Monitor firmware
; Author: Jaap Geurts
; Date: 2021-02-01
;

;.equiv CTC_A, 0x00
;.equiv SIO_AD, 0x40
;.equiv SIO_BD, 0x41
;.equiv SIO_AC, 0x42
;.equiv SIO_BC, 0x43

.equiv CTC_A, 0x00
.equiv SIO_AC, 0x80
.equiv SIO_AD, 0x81

; constants
.equiv STACK_TOP, 0x9FFF
.equiv BS, 0x08 ; backspace code

;ram variables
.equiv input_buf, 0x9000


  .org 0x0000

start:
  ld sp, STACK_TOP    ; stack pointer at 40k (base = 32k + 8k -1)
  jp rom_entry

  .byte 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
  .byte 0x08,0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F

  .org 0x0200
  .word  str_cmp
  .word  read_line
  .word  put_char
  .word  get_char
  .word  printk


rom_entry:
; init ctc timer
  call init_ctc

; init serial
  call init_serial

welcome:
  ld hl,rom_msg
  call printk
  ld hl,author_msg
  call printk

main_loop:
  ld hl, prompt_msg     ; print the prompt
  call printk

  call read_line        ; read an input line
  call print_newline

  ld   hl, input_buf    ; parse input

  ld a, (hl)   ; if strlen(input_buf) == 0
  cp 0
  jr  z, main_loop

  ld   de, help_cmd
  call str_cmp            ; compare if help command
  jr  nz, main_next_help
  ld  hl, help_msg
  call printk
  jp main_loop

main_next_help:

  ld   de, halt_cmd
  call str_cmp            ; compare if halt command
  jr  nz, main_next_halt
  ld  hl, halted_msg
  call printk
  halt

main_next_halt:
  ld   de, load_cmd
  call str_cmp            ; compare if load command
  jr  nz, main_next_load
  ld  hl, loading_msg
  call printk
  call load_program
  ld hl, loading_done_msg
  call printk
  jp main_loop

main_next_load:
  ld   de, dump_cmd
  call str_cmp            ; compare if halt command
  jr  nz, main_next_dump
  ; do work
  ld bc,80
  ld hl,0x8000
dump_loop:
  ld a,(hl)
  call printhex
  ld a,' '
  call put_char
  inc hl
  dec bc
  ld  a,b
  or c
  jr   nz, dump_loop
  call print_newline
  jp main_loop

main_next_dump:
  ld   de, run_cmd
  call str_cmp            ; compare if halt command
  jr  nz, main_next_run
  call 0x8000 ; jump to loaded code
  jp main_loop

main_next_run:
main_loop_error:
  ld hl, error_msg
  call printk
  jp main_loop

panic:
  ld hl, kernel_panic_msg
  call printk
  halt

load_program:
  ld de, 0x8000
load_program_loop:
  call get_char     ; get character
  jr   z, load_program_loop  ; nothing read: read again else result in a
  cp a, ' '
  jr z, load_program_loop
  cp a, '#'   ; if (a ==  '#')
  ret z
  ld b,a  ; store first char in b

load_program_loop2:
  call get_char     ; get character
  jr   z, load_program_loop2  ; nothing read: read again else result in a
  cp a, '#'   ; if (a ==  '#')
  ret z
  ld c, a ; store second char in c

  ; b is higher order char, c is lower order char
  call hex_to_byte ; result in a
  ld (de), a
  inc de ; next

;  ld a,'.'      ; show dot for each byte
;  call put_char
  call printhex

  jr load_program_loop

hex_to_byte: ; input bc; output a
  ;b is higher order nibble, c is lower order nibble
  ld a,b
  call char_to_nibble
  ld b,a  ; put result back in b
  ld a,c
  call char_to_nibble
  ld c,a  ; put result back in c

  ;b is higher order nibble, c is lower order nibble
  ; b << 4 | c
  sla b
  sla b
  sla b
  sla b
  ld a,b  ; but b in a
  or c ; or with c
  ret

char_to_nibble: ; char in a
; TODO: no error checking
  push af
  sub 'A'
  jr c, htb_to_next1 ; carry was borrowed
  ; it was not negative
  add 10
  inc sp
  inc sp
  ret
htb_to_next1:
  pop af
  sub '0'
  ret


printhex:
  push af
  srl a
  srl a
  srl a
  srl a
  call printhex_nibble
  pop af
  call printhex_nibble
  ret

printhex_nibble:
  push bc
  and 0x0f
  ld b,a
  sub 10
  jr c, printhex_addzero
  add 'A'
  jr printhex_end
printhex_addzero:
  ld a,b
  add '0'
printhex_end:
  call put_char
  pop bc
  ret

;********************
; rom library routines
;********************

str_cmp: ; hl = src, de = dst
  ld b, (hl)
  ld a, (de)
  cp b  ; if src[0] != dst[0]  // compare length first
  ret   nz  ; false -> not equal
  push hl
  push de
   ; compare one by one
str_cmp_next:
  inc hl
  inc de
  ld a,(de)
  cp (hl)  ; if(sr[i] != src[i]) // compare bytes
  jr nz, str_cmp_end ; false -> not equal
  djnz str_cmp_next ; reached end?
str_cmp_end:
  pop de
  pop hl
  ret

read_line: ; result in input_buf
  ld de, input_buf+1
  ld b,0
read_line_again:
  call get_char     ; get character
  jr   z, read_line_again  ; nothing read: read again else result in a

  cp a, '\r'   ; if (a ==  '\r') CR
  jr z,read_line_end ;
  cp a, '\n'   ; if (a ==  '\n') LF
  jr z,read_line_end;
  ; not any of the above so print and store
  call put_char
  cp a, BS ;  if (a == '\h') BS
  jr nz, read_line_next
  ld a,' '
  call put_char
  ld a,BS
  call put_char
  jr   read_line_again
read_line_next:
  ld (de), a    ; input_buf[b] = a
  inc de  ; next char
  inc b  ; increase counter
  ; TODO: check for buffer overruns
  jr   read_line_again
read_line_end:
  ld a,b
  ld (input_buf), a ; input_buf[0] = b
  ret  ; return to caller

print_newline:
; newline '\n', '\r' problem.
  ld a,'\r'
  call put_char
  ld a,'\n'
  call put_char
  ret

put_char: ; char in a
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
  push hl
  ld b, (hl)
printk_loop:
  call wait_serial
  inc hl
  ld	a, (hl)
  out  (SIO_AD), a
  djnz printk_loop
  pop hl
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


rom_msg:          .ascii 22,"Z80 ROM Monitor v0.1\r\n"
author_msg:       .ascii 30,"(C) January 2021 Jaap Geurts\r\n"
help_msg:         .ascii 28,"Commands: help, halt, load\r\n"
halted_msg:       .ascii 13,"System halted"
prompt_msg:       .ascii 2, "> "
error_msg:        .ascii 26,"Error - unknown command.\r\n"
kernel_panic_msg: .ascii 12,"Kernel panic"
loading_msg:      .ascii 99,"Load program at 0x8000. Send HEX bytes as two ASCII chars, no separators.\r\nSend # to end. Waiting: "
loading_done_msg: .ascii 16,"\r\nLoading done\r\n"

command_table:
help_cmd:         .ascii 4,"help"
halt_cmd:         .ascii 4,"halt"
load_cmd:         .ascii 4,"load"
dump_cmd:         .ascii 4,"dump"
run_cmd:          .ascii 3,"run"

  ;.balign 0x800
  .balign 0x2000
