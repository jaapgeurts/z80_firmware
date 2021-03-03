; Z80 homebrew single board computer ROM Monitor firmware
; Author: Jaap Geurts
; Date: 2021-02-01
;

CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02
CTC_D equ 0x03
SIO_BD equ 0x41
SIO_BC equ 0x43
SIO_AD equ 0x40
SIO_AC equ 0x42

;CTC_A equ 0x00
;SIO_AC equ 0x80
;SIO_AD equ 0x81

; constants
STACK_TOP     equ 0x9FFF
STACK_SIZE    equ 0x80 ; 128 bytes
KEYB_BUF_SIZE equ 0x08

; keyboard codes 
L_SHIFT equ 0x12
R_SHIFT equ 0x59

; char literals
SOH equ 0x01
EOT equ 0x04
ACK equ 0x06
BS  equ 0x08 ; backspace code
LF  equ 0x0A
CR  equ 0x0D
NAK equ 0x15
ETB equ 0x17
CAN equ 0x18

;ram variables
BUF_SIZE     equ 0x40 ; 64 chars
readline_buf equ 0x9FFF - STACK_SIZE - BUF_SIZE
keyb_buf     equ  readline_buf - KEYB_BUF_SIZE; // 8 bytes keyboard ring buffer
keyb_buf_wr  equ  keyb_buf - 1 ; write index
keyb_buf_rd  equ  keyb_buf_wr - 1 ; read index
v_shifted    equ  keyb_buf_rd - 1 ; shift keystate


; rst jump table

  org 0x0000  ; RST 0

start:
  ld   sp, STACK_TOP    ; stack pointer at 40k (base = 32k + 8k -1)
  jp   rom_entry

  org 0x0008 ; RST 1 getKey
    jp   getKey
  org 0x0010 ; RST 2 putSerialChar
    jp   putSerialChar
  org 0x0018 ; RST 3 printk
    jp   printk
  org 0x0020 ; RST 4 readline
    jp   readLine
  org 0x0028 ; RST 5
  org 0x0030 ; RST 6

  org 0x0038: ; RST 7 or  Mode 1 ISR
    push af
    ; interrupts are already disabled
    in   a,(SIO_AD)
    call putKey

    ; reset the interrupt
    ;ld   a,0b00111000
   ; out  (SIO_AC),a

    pop  af
    ei
    reti

  org 0x0066: ; NMI ISR
    reti
  
  ; reserve some bytes for the interrupt handler
  ; put jump table here.
  org 0x0200

rom_entry:

  ; init variables
  ld   a,0
  ld   (keyb_buf_wr),a

; init ctc timer
  call initCtc

; init serial
  call initSerialConsole

  call initSerialKeyboard

; setup interrupt
  im 1
  ei

welcome:
  ld hl,rom_msg
  call printk
  ld hl,author_msg
  call printk

main_loop:
  ld   hl, prompt_msg     ; print the prompt
  call printk

  call readLine        ; read an input line
  call println

  ld   hl, readline_buf    ; parse input

  ld   a, (hl)   ; if strlen(input_buf) == 0
  cp   0
  jr   z, main_loop

  ld   de, help_cmd
  call stringCompare            ; compare if help command
  jr   nz, main_next_help
  ld   hl, help_msg
  call printk
  jp   main_loop

main_next_help:

  ld   de, halt_cmd
  call stringCompare            ; compare if halt command
  jr   nz, main_next_halt
  ld   hl, halted_msg
  call printk
  halt

main_next_halt:
  ld   de, load_cmd
  call stringCompare            ; compare if load command
  jr   nz, main_next_load
  ld   hl, loading_msg
  call printk
  call load_program
  cp   1
  jr   nz, ln1
  ld   hl,error_load_msg
  call printk 
  jp   main_loop
ln1:
  cp   2
  jr   nz, ln2
  ld   hl,error_checksum
  call printk 
  jp   main_loop
ln2:
  ld   hl, loading_done_msg
  call printk
  jp   main_loop

main_next_load:
  ld   de, dump_cmd
  call stringCompare            ; compare if halt command
  jr   nz, main_next_dump
  ; do work
  ld  bc,0x80
  ld   d,16
  ld   hl,0x8000
dump_loop:
  ld   a,(hl)
  call printhex
  ld   a,' '
  call putSerialChar
  inc  hl
  dec  bc
  dec  d
  jr   nz,skip_newl
  ld   a, CR
  call putSerialChar
  ld   a, LF
  call putSerialChar
  ld   d,16
skip_newl:
  ld   a,b
  or   c
  jr   nz, dump_loop
  call println
  jp   main_loop

main_next_dump:
  ld   de, run_cmd
  call stringCompare            ; compare if halt command
  jr  nz, main_next_run
  call 0x8000 ; jump to loaded code
  jp main_loop

main_next_run:
main_loop_error:
  ld   hl,error_msg
  call printk
  jp   main_loop

panic:
  ld   hl, kernel_panic_msg
  call printk
  halt

rts_off:
  ld   a,005h     ;write into WR0: select WR5
  out  (SIO_AC),A
  ld   a,0E8h     ;DTR active, TX 8bit, BREAK off, TX on, RTS inacive
  out  (SIO_AC),A
  ret
  
rts_on:
  ld   a,005h     ;write into WR0: select WR5
  out  (SIO_AC),A
  ld   a,0EAh     ;DTR active, TX 8bit, BREAK off, TX on, RTS active
  out  (SIO_AC),A
  ret

load_program:
  ld   hl, 0x8000
  ld   a,NAK ; send initial nak
  out  (SIO_AD),a
load_program_next_block:
  ld   b,0 
  ld   c,0
load_program_loop:
  call getSerialChar     ; get character
  jr   nz, block_start
  inc  b
  ld   a,b
  cp   255  ; loop in circles of 255  
  jr   nz,load_program_loop
  ld   b,0
  inc  c    
  ld   a,c
  cp   255 ; loop 133*255 = 1s
  jr   nz,load_program_loop
  ld   a,NAK ; 7ms expired, send a nack
  out  (SIO_AD),a
  ld   c,0
  jr   load_program_loop ; try to read again
block_start:
  cp   EOT   ; is it end of text
  jr   nz, block_check_header     ; return if equal
  ld   a,ACK 
  out  (SIO_AD),a
  ld   a,0
  ret
block_check_header:
  cp   SOH   ; is it start of header
  jr   nz, error_load ; error if not SOH
  call getSerialCharWait  ; blocknumber
;  cpl       ; invert blocknumber
;  ld   b, a
  call getSerialCharWait  ; 255-blocknumber
;  cp   b ; should be the same
;  jr   nz, error_load
  ; load 128 bytes
  ld   c,0 ; checksum
  ld   b,128
  push hl   ; save HL in case there isa retransmit
load_program_read_data: ; start reading the data
  call getSerialCharWait
  ld   (hl),a         ; write data to memory 
  inc  hl
  ; calc the checksum
  add  c ( a + c = char + current sum)
  ld   c,a ; move result back in b (current sum = new sum)
  ; compare 
  djnz load_program_read_data ; did we read 128 bytes yet

  call getSerialCharWait ; get the checksum char
  cp   c  ; does checksum match?
  jr   nz, error_send_nak
  ld   a,ACK ; 
  out  (SIO_AD),a
  inc  sp
  inc  sp ; get rid of hl
  jr   load_program_next_block ; next block
error_send_nak:
  pop  hl  ;; restore HL in case of error
  ld   a, NAK
  out  (SIO_AD),a
  jr   load_program_next_block ; next block
error_load:
  ld   a,CAN
  out  (SIO_AD),a
  ret

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
  call putSerialChar
  pop bc
  ret

;********************
; rom library routines
;********************

stringCompare: ; hl = src, de = dst
  push bc
  push de
  push hl
  ld   b,(hl)
  ld   a,(de)
  ; compare one by one
str_cmp_next:
  ld   a,(de)
  cp   (hl)  ; if(sr[i] != src[i]) // compare bytes
  jr   nz, str_cmp_ne ; false -> not equal
  inc  hl
  inc  de
  djnz str_cmp_next
  ld   a,1  ; true
  jr   str_cmp_end
str_cmp_ne:
  ld   a,0 ; false
str_cmp_end:
  pop  bc
  pop  de
  pop  hl
  ret

readLine: ; result in input_buf
  push bc
  push de
  ld   de, readline_buf+1
  ld   b,0
read_line_again:
  call getKeyWait     ; get character

  cp   CR   ; if (a ==  '\r') CR
  jr   z,read_line_end ;
  cp   LF   ; if (a ==  '\n') LF
  jr   z,read_line_end;
  ; not any of the above so print and store
  call putSerialChar
  cp   BS ;  if (a == '\h') BS
  jr   nz, read_line_next
  ld   a,' '
  call putSerialChar
  ld   a,BS
  call putSerialChar
  jr   read_line_again
read_line_next:
  ld   (de), a    ; input_buf[b] = a
  inc  de  ; next char
  inc  b  ; increase counter
  ; TODO: check for buffer overruns
  jr   read_line_again
read_line_end:
  ld   a,b
  ld   (readline_buf), a ; input_buf[0] = b
  pop  de
  pop  bc
  ret  ; return to caller

println:
  ld   a,CR
  call putSerialChar
  ld   a,LF
  call putSerialChar
  ret


; hl = source address
printk: ; print kernel message to serial (uses pascal strings)
  push hl
  push bc
  ld   b,(hl)
printk_loop:
  call waitSerialTX
  inc  hl
  ld   a, (hl)
  out  (SIO_AD), a
  djnz printk_loop
  pop  bc
  pop  hl
  ret

getKey:
  push bc
  push hl
  di                        ; disable interrupts
  ld  a,(keyb_buf_wr)
  cp  0                     ; is it empty then return
  jr  nz, getKey_take
  ld  a,0
  jr getKey_end
getKey_take:
  dec a
  ld  (keyb_buf_wr),a
  ld  hl, keyb_buf
  ld  b,0
  ld  c,a
  add hl,bc
  ld  a,(hl)
getKey_end:
  ei
  pop  hl
  pop  bc
  ret

putKey:
  push bc
  push hl
  push af
  ld   a,(keyb_buf_wr)
  ld   c,a
  ld   a,KEYB_BUF_SIZE-1
  cp   c                     ; is it empty then return
  jr   nc, putKey_put
  ld   a,0
  jr   putKey_end
putKey_put:
  ld   hl, keyb_buf
  ld   b,0
  add  hl,bc
  inc  c
  ld   a,c
  ld   (keyb_buf_wr),a
  pop  af
  ld   (hl),a
  dec  sp  ; place fake af on the stack
  dec  sp
putKey_end:
  pop  af
  pop  hl
  pop  bc
  ret

getKeyWait:
  call getKey
  cp   0
  jr   z, getKeyWait
  ret

putSerialChar:
  push af
  call waitSerialTX  ; make sure we can send
  pop  af
  out  (SIO_AD), a
  ret

getSerialChar:
; check if character available
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  0, a
  ret  z  ; no char available
; if yes, then read and return in a
  in   a,(SIO_AD)
  ret

getSerialCharWait:
; check if character available
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  0, a
  jr   z,getSerialCharWait  ; no char available
; if yes, then read and return in a
  in   a,(SIO_AD)
  ret

readline:
  ret

waitSerialTX:  ; wait for serial port to be free
  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_AC), a
  in   a, (SIO_AC)
  bit  2,a
  jr   z, waitSerialTX
  ret

  ; init the serial port
initSerialConsole:
; reset channel 0
  ld	a, 0b00110000
  out (SIO_AC), a

; prepare for writing WR4 - datasheet says write to WR4 first then other registers
  ld	a, 0b00000100 ; write to WR0. Next byte is WR4
  out	(SIO_AC), a
  ld	a, 0b01000100               ; 16x prescaler, No parity, 1 stopbit
  out	(SIO_AC), a

; enable interrupt on char (WR1)
  ld	a, 0b00000001 ; 
  out	(SIO_AC), a
  ld	a, 0b00011000 ; int on all Rx chars
  out	(SIO_AC), a

; enable receive (WR3)
  ld	a, 0b00000011
  out	(SIO_AC), a
  ld	a, 0b11000001             ; recv enable; 8bits / char
  out	(SIO_AC), a

; write register 5
  ld	a, 0b00000101
  out	(SIO_AC), a
  ld	a, 0b01101000            ; send enable
  out	(SIO_AC), a

  ret

initCtc:
; clock is 3,686,400 Hz
; clock frequency of the CTC must be 2x trigger frequency in other words:
; input frequency on TRG0 is 1,843,200Hz (must be at least than half clock freq)
  ld a, 0b01010101 ; control register, external trigger, counter mode, rising edge 
  out (CTC_A), a
  ; baudrates - Time constant @ 1.8432 MHz
  ; 9600      - 12
  ; 19200     - 6
  ; 57600     - 2
  ; 115200    - 1
  ld a, 1 ; 115200 @ 1.8432 MHz
  out (CTC_A), a
  ret

readKeyboard:
  ld   a,0
  ld   (v_shifted),a

again:
  call getKeyboardChar
  ; translate scan code
  ; ignore release codes
  cp 0xf0 ; break code
  jr nz, make
break:
  call getKeyboardChar
  cp   L_SHIFT
  jr   z,unshifted:
  cp   R_SHIFT
  jr   nz,again:
unshifted:
  ld   a,0
  ld   (v_shifted),a
  jr   again

make:
  push af
  cp   L_SHIFT
  jr   z,set_shifted:
  cp   R_SHIFT
  jr   nz,fetch:
set_shifted:
  ld   a,1
  ld   (v_shifted),a
  jr   again
  
fetch:
  ld   hl,trans_table_normal
  ld   a,(v_shifted)
  cp   1
  jr   nz,fetch_2
  ld   hl, trans_table_shifted
fetch_2:
  pop  af
  ld   b, 0
  ld   c, a
  add  hl, bc
  ld   a,(hl)

  call putKey

next2:
  jr   again

;; support routines

getKeyboardChar:
; check if character available
  ld   a, 0b00000000 ; write to WR1. Next byte is RR0
  out  (SIO_BC), a
  in   a,(SIO_BC)
  bit  0, a
  jr   z,getKeyboardChar  ; no char available
; if yes, then read and return in a
  in   a,(SIO_BD)
  ret

waitSerialKbd:  ; wait for serial port to be free
  ld	a, 0b00000000 ; write to WR1. Next byte is RR0
  out	(SIO_BC), a
  in a, (SIO_BC)
  bit 2,a
  jr  z, waitSerialKbd
  ret

  ; init the serial port
initSerialKeyboard:
; reset channel 1
  ld	a, 0b00110000
  out (SIO_BC), a

; prepare for writing WR4
  ld	a, 0b00000100 ; write to WR1. Next byte is WR4
  out	(SIO_BC), a
  ld	a, 0b00000101              ; set clock rate, odd parity, 1 stopbit
  out	(SIO_BC), a

; enable receive (WR3)
  ld	a, 0b00000011
  out	(SIO_BC), a
  ld	a, 0b11000001             ; recv enable; 8bits/char
  out	(SIO_BC), a

  ret

rom_msg:          ascii 22,"Z80 ROM Monitor v0.1",CR,LF
author_msg:       ascii 30,"(C) January 2021 Jaap Geurts",CR,LF
help_msg:         ascii 39,"Commands: help, halt, load, dump, run",CR,LF
halted_msg:       ascii 13,"System halted"
prompt_msg:       ascii 2, "> "
error_msg:        ascii 26,"Error - unknown command.",CR,LF
kernel_panic_msg: ascii 12,"Kernel panic"
loading_msg:      ascii 49,"Load program at 0x8000. Send data using Xmodem.",CR,LF
loading_done_msg: ascii 16,CR,LF,"Loading done",CR,LF
error_load_msg:   ascii 20,"Error loading data",CR,LF 
error_checksum:   ascii 10,"Checksum",CR,LF

; TODO: make command jump table
command_table:
help_cmd:         ascii 4,"help"
halt_cmd:         ascii 4,"halt"
load_cmd:         ascii 4,"load"
dump_cmd:         ascii 4,"dump"
run_cmd:          ascii 3,"run"

;; PS2/ scancode set 2

SQOT equ 0x27

trans_table_normal:
  db 0x00,0x00,0x00,0x00,0x00,0x00 ; 0
  db 0x00,0x00,0x00,0x00,0x00,0x0D,0x09,0x0E ; 8
  db  '`',0x00,0x00,0x00,0x00,0x00,0x00, 'q' ; 10
  db  '1',0x00,0x00,0x00, 'z', 's', 'a', 'w' ; 18
  db  '2',0x00,0x00, 'c', 'x', 'd', 'e', '4' ; 20
  db  '3',0x00,0x00, ' ', 'v', 'f', 't', 'r' ; 28
  db  '5',0x00,0x00, 'n', 'b', 'h', 'g', 'y' ; 30
  db  '6',0x00,0x00,0x00, 'm', 'j', 'u', '7' ; 38
  db  '8',0x00,0x00, ',', 'k', 'i', 'o', '0' ; 40
  db  '9',0x00,0x00, '.', '/', 'l', ';', 'p' ; 48
  db  '-',0x00,0x00,0x00, "'",0x00, '[', '=' ; 50
  db 0x00,0x00,0x00,0x00,0x00, ']',0x00, "\" ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 60
  db 0x00,0x08,0x00,'1' ,0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78
trans_table_shifted:
  db  0x00,0x00,0x00,0x00,0x00,0x00 ; 0
  db 0x00,0x00,0x00,0x00,0x00,0x0D,0x09,0x0E ; 8
  db  '~',0x00,0x00,0x00,0x00,0x00,0x00, 'Q' ; 10
  db  '!',0x00,0x00,0x00, 'Z', 'S', 'A', 'W' ; 18
  db  '@',0x00,0x00, 'C', 'X', 'D', 'E', '$' ; 20
  db  '#',0x00,0x00, ' ', 'V', 'F', 'T', 'R' ; 28
  db  '%',0x00,0x00, 'N', 'B', 'H', 'G', 'Y' ; 30
  db  '^',0x00,0x00,0x00, 'M', 'K', 'U', '&' ; 38
  db  '*',0x00,0x00, '<', 'K', 'I', 'O', ')' ; 40
  db  '(',0x00,0x00, '>', '?', 'L', ':', 'P' ; 48
  db  '_',0x00,0x00,0x00, '"',0x00, '{', '+' ; 50
  db 0x00,0x00,0x00,0x00,0x00, '}',0x00, '|' ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 60
  db 0x00,0x08,0x00,'1' ,0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78

  org 0x0800
;  org 0x2000

