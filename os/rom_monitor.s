; Z80 homebrew single board computer ROM Monitor firmware
; Author: Jaap Geurts
; Date: 2021-02-01
;

;rc2014=1
magnolia=1

; IO peripheral port definitions
CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02
CTC_D equ 0x03

RTC    equ 0x20
; 16 more registers up to 0x2F


SIO_BD equ 0x41
SIO_BC equ 0x43
  ifdef magnolia
SIO_AD equ 0x40
SIO_AC equ 0x42
  endif

PIO_AC equ 0x60

;CTC_A equ 0x00
  ifdef rc2014
SIO_AC equ 0x80
SIO_AD equ 0x81
  endif

; constants
STACK_TOP          equ 0x9FFF
STACK_SIZE         equ 0x80 ; 128 bytes
VAR_TOP            equ STACK_TOP - STACK_SIZE
KEYB_BUF_TOP       equ 0x9F00
KEYB_BUF_SIZE      equ 0x100
READLINE_BUF_SIZE  equ 0x40 ; 64 chars
RTC_REG_COUNT      equ 0x0d

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

;ram variables; first 128 bytes for the stack
; next 128 bytes for general variables
readline_buf equ VAR_TOP - READLINE_BUF_SIZE ; 64 bytes for the readline buffer
                                    ; 64 bytes for the rest
v_shifted    equ readline_buf - 1 ; shift keystate
keyb_buf_wr  equ v_shifted - 2     ; write index
keyb_buf_rd  equ keyb_buf_wr - 2  ; read index
v_timestruct equ keyb_buf_rd - RTC_REG_COUNT ; time structure

; ring buffer. Lives at 0x100 below the top
keyb_buf     equ KEYB_BUF_TOP - KEYB_BUF_SIZE; // 8 bytes keyboard ring buffer


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
INTISR:
  push af
  ; interrupts are already disabled

  ; reset the interrupt in the SIO
  ld   a,0b00111000
  out  (SIO_AC),a

.intisr_check_channel_a
  ld   a, 0b00000000 ; write to WR1. Next byte is RR0
  out  (SIO_AC), a
  in   a,(SIO_AC)
  bit  0, a
  jr   z,.intisr_check_channel_b  ; no char available

  ;  if char waiting in channel a
  in   a,(SIO_AD)
  call putKey
  jr   .intisr_end

.intisr_check_channel_b

  ld   a, 0b00000000 ; write to WR0. Next byte is RR0
  out  (SIO_BC), a
  in   a,(SIO_BC)
  bit  0, a
  jr   z,.intisr_end  ; no char available
  
  ; if char waiting in channel b
  in   a,(SIO_BD)
  call handleKeyboard
  ;call putKey
  ;out  (SIO_AD),a

  ; enable next char int
  ld   a, 0b00100000 ; write to WR0. to reenable rx interrupt
  out  (SIO_BC), a

.intisr_end:
  pop  af
  ei
  reti

  org 0x0066: ; NMI ISR
  ei
  reti
  
  ; reserve some bytes for the interrupt handler
  ; put jump table here.
  org 0x0100

rom_entry:

  ; init variables
  ld   hl,keyb_buf
  ld   (keyb_buf_wr),hl
  ld   (keyb_buf_rd),hl
  ld   a,0
  ld   (v_shifted),a

  ; init realtime clock

  ifdef magnolia
  ld   hl,rom_time
  call RTCInit
  endif

; init ctc timer
  ; baudrates - Time constant @ 1.8432 MHz
  ; 9600      - 12
  ; 19200     - 6
  ; 57600     - 2
  ; 115200    - 1
  ; baudrate in a
  ld a, 12
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

; main menu loop
; TODO: add arguments
main_loop:
  ld   hl, prompt_msg     ; print the prompt
  call printk

  call readLine        ; read an input line; result in hl
  call println

  push hl   ; put command entered into de
  pop  de
  ld   hl, command_table
  ld   a,(de) ; check if user entered a command or just hit enter
  cp   0
  jr   z,main_loop
.search_table
  ld   b,0
  ld   c,(hl) ; length of command in table
  ld   a,c
  cp   0      ; if the last byte is a 0, then we reached end of table
  jr   z,.cmd_notfound
  call stringCompare
  cp   1    ; is str equal; compare with true
  jr   nz,.next_command ; if false do next next_command
  ; found command. load address to jump to
  push hl
  pop  ix
  inc  c
  add  ix,bc
  ld   h,(ix+1)
  ld   l,(ix)
  ld   iy,main_loop ; push return address
  push iy
  jp   (hl)
.next_command:
  inc  c
  inc  c
  inc  c
  add  hl,bc
  jr   .search_table
.cmd_notfound
  ld   hl,error_msg
  call printk
  jr   main_loop

menu_help:
  ld   hl, help_msg
  call printk
  ret 

menu_halt:
  ld   hl, halted_msg
  call printk
  halt

menu_date:
  ; print date
  ld   hl,v_timestruct
  call RTCRead

  ld   b,0
  ld   c,7  ; 10 day
  add  hl,bc
  ld   a,(hl)
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl) ; 1day
  add  '0'
  call putSerialChar
  ld   a,'/'
  call putSerialChar
  inc  hl
  inc  hl
  inc  hl ; 10 month
  ld   a,(hl)
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl) ; 1 month
  add  '0'
  call putSerialChar
  ld   a,'/'
  call putSerialChar
  inc  hl
  inc  hl
  inc  hl ; 10 year
  ld   a,(hl)
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl) ; 1 year
  add  '0'
  call putSerialChar
  ld   a,' '
  call putSerialChar

  ld   hl,v_timestruct
  ld   c,5
  add  hl,bc
  ld   a,(hl)  ; 10 hour
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl)  ; 1 hour
  add  '0'
  call putSerialChar
  ld   a,':'
  call putSerialChar
  dec  hl
  ld   a,(hl)  ; 10 min
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl)  ; 1 min
  add  '0'
  call putSerialChar
  ld   a,':'
  call putSerialChar
  dec  hl
  ld   a,(hl)  ; 10 sec
  add  '0'
  call putSerialChar
  dec  hl
  ld   a,(hl)  ; 11 sec
  add  '0'
  call putSerialChar

  call println

  ret

menu_load:
  ld   hl, loading_msg
  call printk
  call loadProgram
  cp   1
  jr   nz, .ln1
  ld   hl,error_load_msg
  call printk 
  ret
.ln1:
  cp   2
  jr   nz, .ln2
  ld   hl,error_checksum
  call printk 
  ret
.ln2:
  ld   hl, loading_done_msg
  call printk
  ret

menu_dump:
  ; do work
  ld   bc,0x80
  ld   d,16
  ld   hl,0x8000
.dump_loop:
  ld   a,(hl)
  call printhex
  ld   a,' '
  call putSerialChar
  inc  hl
  dec  bc
  dec  d
  jr   nz,.skip_newl
  ld   a, CR
  call putSerialChar
  ld   a, LF
  call putSerialChar
  ld   d,16
.skip_newl:
  ld   a,b
  or   c
  jr   nz, .dump_loop
  call println
  ret

menu_run:
  call 0x8000 ; jump to loaded code
  ret

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

loadProgram:
  push bc
  push hl
  ld   hl, 0x8000
  ld   a,NAK ; send initial nak
  call putSerialChar
.load_program_next_block:
  ld   b,0 
  ld   c,0
.load_program_loop:
  call getKey     ; get character
  jr   nz, .block_start
  inc  b
  ld   a,b
  cp   255  ; loop in circles of 255  
  jr   nz,.load_program_loop
  ld   b,0
  inc  c    
  ld   a,c
  cp   255 ; loop 133*255 = 1s
  jr   nz,.load_program_loop
  ld   a,NAK ; 7ms expired, send a nack
  call putSerialChar
  ld   c,0
  jr   .load_program_loop ; try to read again
.block_start:
  cp   EOT   ; is it end of text
  jr   nz, .block_check_header     ; return if equal
  ld   a,ACK 
  call putSerialChar
  jr   .load_program_end
.block_check_header:
  cp   SOH   ; is it start of header
  jr   nz, .error_load ; error if not SOH
  call getKeyWait  ; blocknumber
;  cpl              ; invert blocknumber
;  ld   b, a
  call getKeyWait  ; 255-blocknumber
;  cp   b ; should be the same
;  jr   nz, .error_load
  ; load 128 bytes
  ld   c,0 ; checksum
  ld   b,128
  push hl   ; save HL in case there is a retransmit so we car restart from the beginning
.load_program_read_data: ; start reading the data
  call getKeyWait
  ld   (hl),a         ; write data to memory 
  inc  hl
  ; calc the checksum
  add  c ( a + c = char + current sum)
  ld   c,a ; move result back in b (current sum = new sum)
  ; compare 
  djnz .load_program_read_data ; did we read 128 bytes yet

  call getKeyWait ; get the checksum char
  cp   c  ; does checksum match?
  jr   nz, .error_send_nak ; TODO: uncomment
  ld   a,ACK ; 
  call putSerialChar
  inc  sp
  inc  sp ; get rid of hl
  jr   .load_program_next_block ; next block
.error_send_nak:
  pop  hl  ;; restore HL in case of error
  ld   a, NAK
  call putSerialChar
  jr   .load_program_next_block ; next block
.error_load:
  ld   a,CAN
  call putSerialChar
.load_program_end
  pop  hl
  pop  bc
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

printhex_nibble: ; converts a nibble to hex char
  push bc
  push hl
  ld   hl,hexconv_table
  and  0x0F ; take bottom nibble only
  ld   b,0
  ld   c,a
  adc  hl,bc
  ld   a,(hl)
printhex_end:
  call putSerialChar
  pop hl
  pop bc
  ret

;********************
; rom library routines
;********************

RTCInit:
  push bc
  push hl

; start counting
  ld   a,0b00000000 ; test=0, 24hr, stop=0, reset=0
  out  (RTC+0x0f),a
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0, hold=0
  out  (RTC+0x0d),a

  call RTCCheckBusy

; stop and reset
  ld   a,0b00000001 ; reset
  out  (RTC+0x0f),a 
  ld   b,83 ; delay 270us @ 921MHz
.RTCInit_delay:
  djnz .RTCInit_delay ; decrease 100 times. takes 3cycles ecah loop = ~350ms
  ld   a,0b00000011 ; stop + reset 
  out  (RTC+0x0f),a

; set current time
  ld   b,RTC_REG_COUNT
  ld   c,RTC
.RTCInit_next:
  ld   a,(hl)
  out  (c),a
  inc  c
  inc  hl
  djnz .RTCInit_next

; start counter and release hold
  ld   a,0b00000100 ; test=0, 24hr, stop=0, reset=0
  out  (RTC+0x0f),a
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC+0x0d),a

  pop  hl
  pop  bc
  ret
; done init

RTCRead:

  push bc
  push hl

  ld   b,RTC_REG_COUNT
  ld   c,RTC
  call RTCCheckBusy

.RTCRead_loop:

  in   a,(c) ;
  and  0x0F ; chop off high nibble
  ld   (hl),a
  inc  c
  inc  hl
  djnz .RTCRead_loop

; release hold
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC+0x0d),a

  pop  hl
  pop  bc
  ret

RTCCheckBusy:
  push bc
  ld   a,0b00000001  
  out  (RTC+0x0d),a  ; set hold to 1
  in   a,(RTC+0x0d)  ; read busy bit
  bit  1,a
  jr   z,.RTCCheckBusy_end
  ld   b,65  ; still busy
  ld   a,0b00000000
  out  (RTC+0x0d),a ; set hold to 0
.RTCCheckBusy_delay:
  djnz .RTCCheckBusy_delay ; decrease 65 times. takes 3cycles each run = ~211us
  jr   RTCCheckBusy
.RTCCheckBusy_end:
  pop  bc
  ret

stringCompare: ; hl = src, de = dst
  push bc
  push de
  push hl
  ld   b,(hl)
  ; compare one by one
.str_cmp_next:
  ld   a,(de)
  cp   (hl)  ; if(sr[i] != src[i]) // compare bytes
  jr   nz, .str_cmp_ne ; false -> not equal
  inc  hl
  inc  de
  djnz .str_cmp_next
  ld   a,1  ; true
  jr   .str_cmp_end
.str_cmp_ne:
  ld   a,0 ; false
.str_cmp_end:
  pop  hl
  pop  de
  pop  bc
  ret

readLine: ; result in input_buf & hl
  push bc
  push de
  ld   de, readline_buf+1
  ld   b,0
.read_line_again:
  call getKeyWait     ; get character

  cp   CR   ; if (a ==  '\r') CR
  jr   z,.read_line_end ;
  cp   LF   ; if (a ==  '\n') LF
  jr   z,.read_line_end;
  ; not any of the above so print and store
  call putSerialChar
  cp   BS ;  if (a == '\h') BS
  jr   nz, .read_line_next
  ld   a,' '
  call putSerialChar
  ld   a,BS
  dec  b   ; one less char in the string
  call putSerialChar
  jr   .read_line_again
.read_line_next:
  ld   (de), a    ; input_buf[b] = a
  inc  de  ; next char
  inc  b  ; one more char in the string
  ; TODO: check for buffer overruns
  jr   .read_line_again
.read_line_end:
  ld   a,b
  ld   (readline_buf), a ; input_buf[0] = b
  ld   hl,readline_buf
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
.printk_loop:
  call waitSerialTX
  inc  hl
  ld   a, (hl)
  out  (SIO_AD), a
  djnz .printk_loop
  pop  bc
  pop  hl
  ret


getKeyWait:
  call getKey
  jr   z, getKeyWait
  ret

getKey:
  push hl
  push de
  di                        ; disable interrupts
  ; compare if buffer is empty
  ld   hl, (keyb_buf_wr)
  ld   de, (keyb_buf_rd) ; read pointer
  ld   a,l 
  cp   e                     ; is it equal then buffer is empty
  jr   z,.getKey_end
.getKey_take:
  ld   a,(de) ; read from position
  push af
  inc  e
  ld  (keyb_buf_rd),de ; pointer pointer back into mem
  pop  af
.getKey_end:
  ei
  pop  de
  pop  hl
  ret

putKey:
  push hl
  push de
  push bc
  ld   b,a
  ; begin
  ld   hl,(keyb_buf_wr)
  ld   de,(keyb_buf_rd)
  dec  e
  ld   a,l
  cp   e
  jr   z, .putKey_end  ; head = tail -1 => buffer full
.putKey_put
  ld   hl,(keyb_buf_wr)
  ld   (hl),b
  inc  l
  ld   (keyb_buf_wr),hl
.putKey_end:
  pop  bc
  pop  de
  pop  hl
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
  push af ; store af. it contains the baud rate time constant
; clock is 3,686,400 Hz
; clock frequency of the CTC must be 2x trigger frequency in other words:
; input frequency on TRG0 is 1,843,200Hz (must be at least than half clock freq)
  ld a, 0b01010101 ; control register, external trigger, counter mode, rising edge 
  out  (CTC_A), a
  ; baudrates - Time constant @ 1.8432 MHz
  ; 9600      - 12
  ; 19200     - 6
  ; 57600     - 2
  ; 115200    - 1
  ;ld a, 1 ; 115200 @ 1.8432 MHz
  pop  af
  out  (CTC_A), a
  ret

; KEYBOARD FUNCTIONS

handleKeyboard:

  push hl
  push bc
  ; translate scan code
  ; ignore release codes
  cp   0xf0 ; break code
  jr   nz, .read_kbd_make
.read_kbd_break:
  call getKeyboardChar  ;read the next char
  cp   L_SHIFT
  jr   z,.read_kbd_unshifted:
  cp   R_SHIFT
  jr   nz,.read_kbd_end:
.read_kbd_unshifted:
  ld   a,0
  ld   (v_shifted),a
  jr   .read_kbd_end

.read_kbd_make:
  push af
  cp   L_SHIFT
  jr   z,.read_kbd_set_shifted:
  cp   R_SHIFT
  jr   nz,.read_kbd_fetch:
.read_kbd_set_shifted:
  ld   a,1
  ld   (v_shifted),a
  pop  af
  jr   .read_kbd_end
  
.read_kbd_fetch:
  ld   hl,trans_table_normal
  ld   a,(v_shifted)
  cp   1
  jr   nz,.read_kbd_fetch_2
  ld   hl,trans_table_shifted
.read_kbd_fetch_2:
  pop  af
  ld   b, 0
  ld   c, a
  add  hl, bc
  ld   a,(hl)

  call putKey  ; store the key in the ring buffer

.read_kbd_end:
  pop  bc
  pop  hl
  ret

; support routines

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

  ; init the serial port
initSerialKeyboard:
; reset channel B
  ld   a, 0b00110000
  out  (SIO_BC), a

; prepare for writing WR4, must write WR4 first
  ld   a, 0b00000100 ; write to WR0. Next byte is WR4
  out  (SIO_BC), a
  ld   a, 0b00000101              ; set clock rate, odd parity, 1 stopbit
  out  (SIO_BC), a

  ; enable interrupt on char (WR1)
  ld   a, 0b00000001 ; 
  out  (SIO_BC), a
  ld   a, 0b00001000 ; int on first Rx char
  out  (SIO_BC), a

; enable receive (WR3)
  ld   a, 0b00000011
  out  (SIO_BC), a
  ld   a, 0b11000001             ; recv enable; 8bits/char
  out  (SIO_BC), a

  ret

rom_msg:          db 22,"Z80 ROM Monitor v0.2",CR,LF
author_msg:       db 30,"(C) January 2021 Jaap Geurts",CR,LF
help_msg:         db 45,"Commands: help, halt, load, dump, date, run",CR,LF
halted_msg:       db 13,"System halted"
prompt_msg:       db 2, "> "
error_msg:        db 26,"Error - unknown command.",CR,LF
loading_msg:      db 49,"Load program at 0x8000. Send data using Xmodem.",CR,LF
loading_done_msg: db 16,CR,LF,"Loading done",CR,LF
error_load_msg:   db 20,"Error loading data",CR,LF 
error_checksum:   db 10,"Checksum",CR,LF
hexconv_table:    db "0123456789ABCDEF"
rom_time:         db 0,0,0,4,5,1,5,0,3,0,1,2,5

; command jump table
command_table:
cmd_help:    db 4,"help"
             dw menu_help
cmd_halt:    db 4,"halt"
             dw menu_halt
cmd_load:    db 4,"load"
             dw menu_load
cmd_dump:    db 4,"dump"
             dw menu_dump
cmd_date:    db 4,"date"
             dw menu_date
cmd_run:     db 3,"run"
             dw menu_run
cmd_tab_end: db    0

    

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
  db 0x00,0x08,0x00, '1',0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78
trans_table_shifted:
  db 0x00,0x00,0x00,0x00,0x00,0x00 ; 0
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
  db 0x00,0x08,0x00, '1',0x00, '4', '7',0x00 ; 68
  db 0x00,0x00, '0', '.', '2', '5', '6', '8' ; 70
  db 0x1b,0x00,0x00, '+', '3', '-', '*', '9' ; 78

  ifdef magnolia
  org 0x0800
  endif
  ifdef rc2014
  org 0x2000
  endif

