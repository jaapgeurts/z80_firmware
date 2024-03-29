; Z80 homebrew single board computer ROM Monitor firmware
; Author: Jaap Geurts
; Date: 2021-02-01
;

  include "consts.inc"

; *****************
; *** CONSTANTS ***
; *****************

  section .consts

DUMP_ROWCOUNT    equ 0x10 ; 16 rows
DUMP_BYTESPERROW equ 0x08 ; 8 bytes per row

; led masks
LED1 equ 0x02
LED2 equ 0x04
LED3 equ 0x08


; *****************
; *** VARIABLES ***
; *****************

; constants
STACK_SIZE        equ 0x40 ; 64 words
STACK_TOP         equ 0x0000
SER_BUF_SIZE      equ 0x20
READLINE_BUF_SIZE equ 0x40 ; 64 chars

  global putKey
  global getKey
  global putChar
  global printk
  global stringCompare

; variables
  section .bss
    ; must be at the top so it can be aligned correctly in the linker
    keyb_buf:     dsb SER_BUF_SIZE;  32 bytes keyboard ring buffer ; must be aligned to 256 bit addres
    keyb_buf_wr:  dsw 1  ; write index
    keyb_buf_rd:  dsw 1  ; read index
    ; keyboard
    readline_buf: dsb READLINE_BUF_SIZE; ; 64 bytes for the readline buffer
    ; real time clock
    v_timestruct: dsb RTC_REG_COUNT ; time structure
    num_tokens:   dsb  1 ; number of tokens when parsing arguments
  section .stack
    dsw STACK_SIZE

; rst jump table

  section .start
start:
  ld   sp, STACK_TOP    ; stack pointer at 40k (base = 32k + 8k -1)
  jp   rom_entry

; RST points
  section .rst_table
JT_1:
  jp   getKey        ; 0x08
  jp   stringCompare ; 0x0b
  align 3
  jp   putChar       ; 0x10
  align 3
  jp   printk        ; 0x18
  align 3
  jp   readLine      ; 0x20
  align 3
  jp   statFile      ; 0x28
  jp   readFile      ; 0x2b
  align 3
  ret                ; 0x30

  ; RST 7 or  Mode 1 ISR
  section .isr_int
  ei
  reti

JT_2:
  dsb  3  ; 0x3b
  dsb  3  ; 0x3e
  jp   nextToken         ; 0x41
  jp   displayClear      ; 0x44


  ; NMI ISR
  section .isr_nmi
  ei
  retn

; Empty ISR
ISR_Nothing:
  ei
  reti

; my isr table

; TODO: ultimately setup this table into RAM
; so it's easy redefinable by users
  section .isr_table
Main_ISR_Table:
CTC_ISR_Table:
  dw  ISR_Nothing  ; interrupt is disabled in CTC because timer0 is baudrate gen.
  dw  ISR_Timer1_IncCounter  ; see ctc_timer.s
  dw  ISR_Nothing ; free for user purposes
  dw  ISR_Nothing ; free for user purposes

PIO_ISR_Table:
  dw  ISR_Nothing ; not in use
; padding
  dw  0 ; alignment word
  dw  0 ; alignment word
  dw  0 ; alignment word

SIO_ISR_Table:
  ; Channel B
  dw  ISR_Nothing ; Channel B  TX Buf Empty
  dw  ISR_Nothing ; Channel B  External Stat Change
  dw  ISR_SerialB_Keyboard ; Channel B RX Char available
  dw  ISR_Nothing ; Channel B  Special recv condition
  ; Channel A
  dw  ISR_Nothing ; Channel A  TX Buf Empty
  dw  ISR_Nothing ; Channel A  External Stat Change
  dw  ISR_SerialA_Console ; Channel A RX char available
  dw  ISR_Nothing ; Channel A  Special recv condition

  section .text

rom_entry:

; set all PSG ports to output
  call initPSG

; set leds to 1
  ld   b,1<<1
  call setLed

; init variables
  ld   hl,keyb_buf
  ld   (keyb_buf_wr),hl
  ld   (keyb_buf_rd),hl

; init ctc timer
  ; baudrates - Time constant @ 3.6864 MHz
  ; 9600      - 24
  ; 19200     - 12
  ; 57600     - 4
  ; 115200    - 2
  ; baudrate in a
  ld a, 24
  call initCTC

  ; set leds to 2
  ld   b,2<<1
  call setLed

; init serial
  call initSerialConsole

  ; set leds to 3
  ld   b,3<<1
  call setLed

  call initDisplay

; set leds to 4
  ld   b,4<<1
  call setLed

  call initSerialKeyboard

  ; set leds to 5
  ld   b,5<<1
  call setLed


; setup interrupts
  ld   a,0x01
  ld   i,a

; enable interrupts
  im 2
  ei

welcome:
  ld   hl,rom_msg
  call prints
  ld   hl,author_msg
  call prints
  ld   hl,url_msg
  call prints

  call displayClear

  ; set leds to 6
  ld   b,6<<1
  call setLed

  ld   hl,rom_msg
  call printd
  ld   hl,author_msg
  call printd
  ld   hl,url_msg
  call printd

 ; set leds to 7
  ld   b,7<<1
  call setLed

  call initCompactFlash
  call initFAT

  ld   b,0
  call setLed

; main menu loop
main_loop:
  ld   hl, prompt_msg     ; print the prompt
  call printk

  ld   hl,readline_buf
  call readLine        ; read an input line; result in hl
  call println

; break string into tokens
; and get the first argument (this is the command)
  call tokenize

  ld   a,c
  cp   0
  jr   z,main_loop ; nothing to do

  push hl ; save str ptr
  push bc ; save token counters

  ex   de,hl ; now DE is cmdline
  ld   hl, command_table
.search_table:
  ld   b,0    ; upper byte of bc
  ld   c,(hl) ; strlength of command in table
  ld   a,c ; put in A for comparison
  cp   0      ; if the last byte is a 0, then we reached end of table
  jr   z,.trydisk
.search_compare:
  call stringCompare
  cp   1    ; is str equal; compare with true
  jr   z,.exec_command ; if true do execute command
  inc  c    ; skip. vector to menu
  inc  c
  inc  c   ; one extra byte for the string size
  add  hl,bc
  jr   .search_table
.trydisk:

  pop  bc ; restore counters for args
  pop  hl ; restore string for read file
  push bc
  push hl
  ld   a,0 ; read whole file
  ld   de,0x4000
  call readFile
  cp   0
  jr   nz,.failed
  pop  de ; arguments to command
  pop  bc ; argcount
  call 0x4000
  jr   main_loop

.exec_command:
  ; found command. load address to jump to
  push hl ; current index into command table (at command)
  pop  ix  ; ld  ix,hl
  inc  c  ; C contains the strlen of current commend.
  add  ix,bc  ;  find the vector
  ld   iy,main_loop ; push return address
  pop  bc ; restore token counters
  pop  de ; the str
  ld   h,(ix+1) ; load func pointer
  ld   l,(ix)
  push iy ; push return address
  jp   (hl)  ; jump to function pointer; de is the start of the arg string; hl points to function

.failed:
  ; end of the table, cleanup, print error and return
  inc  sp
  inc  sp
  inc  sp
  inc  sp ; restore the stack
  ld   hl,error_msg
  call printk
  jr   main_loop

menu_help:
  ex   de,hl
  ld   hl, command_table
.search_table:
  ld   b,0    ; upper byte of bc
  ld   c,(hl) ; strlength of command in table
  ld   a,c ; put in A for comparison
  cp   0      ; if the last byte is a 0, then we reached end of table
  jr   z,.end
  call printk
  ld   a,TAB
  call putChar
  inc  c    ; skip. vector to menu
  inc  c
  inc  c   ; one extra byte for the string size
  add  hl,bc
  jr   .search_table
.end:
  call println
  ret


; TODO: improve this
menu_date:
  ; print date
  ld   hl,v_timestruct
  call RTCRead

  ld   bc,7 ; 10 day
  add  hl,bc
  ld   a,(hl)
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl) ; 1day
  add  '0'
  call putChar
  ld   a,'/'
  call putChar
  inc  hl
  inc  hl
  inc  hl ; 10 month
  ld   a,(hl)
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl) ; 1 month
  add  '0'
  call putChar
  ld   a,'/'
  call putChar
  inc  hl
  inc  hl
  inc  hl ; 10 year
  ld   a,(hl)
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl) ; 1 year
  add  '0'
  call putChar
  ld   a,' '
  call putChar

  ld   hl,v_timestruct
  ld   c,5
  add  hl,bc
  ld   a,(hl)  ; 10 hour
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl)  ; 1 hour
  add  '0'
  call putChar
  ld   a,':'
  call putChar
  dec  hl
  ld   a,(hl)  ; 10 min
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl)  ; 1 min
  add  '0'
  call putChar
  ld   a,':'
  call putChar
  dec  hl
  ld   a,(hl)  ; 10 sec
  add  '0'
  call putChar
  dec  hl
  ld   a,(hl)  ; 1 sec
  add  '0'
  call putChar

  call println

  ret

menu_files:

  ld   hl,0x0000 ; start at the beginning

  ld   a,0 ; last action succeeded

  call statFile

.next:
  call printk
  ld   hl,files_spacer_msg
  call printk
  ld   a,d
  call printhex
  ld   a,e
  call printhex
  call println

  ld   hl,0x0000 ; continue to read the next file
  ld   a,1
  call statFile
  cp   0xff
  jr   nz,.next

  ret

menu_fload:
  ld   h,d
  ld   l,e ; ld hl,de
  call nextToken

  call getAddress
  ret  z   ; result in de

  call nextToken

  ld   a,0 ; read whole file
  call readFile
  cp   0
  jr   z,.end
  ld   hl,nosuchfile_msg
  call printk
.end:
  ret

; serial load
menu_sload:
  ld   h,d
  ld   l,e ; ld hl,de
  call nextToken
  push hl

  call getAddress
  ret  z   ;  result in de
  push hl

  ld   hl, loading_msg
  call printk

  pop  hl ; addr str
  call printk
  call println

  ld   h,d
  ld   l,e ; ld hl,de
  call loadProgram  ; do actual work
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

; src address in hl
; cmdline in de
menu_dump:
  push bc
  push hl

  ld   h,d
  ld   l,e ; ld hl,de
  call nextToken

  call getAddress ; result in de
  jr   z, .dump_end
  ld   h,d
  ld   l,e ; ld hl,de

  ; do work
  ld   c,DUMP_ROWCOUNT    ; 16 rows maximum
.dump_row:
  ld   b,DUMP_BYTESPERROW    ; 8 bytes per row
  ; print address
  ld   a,'0'
  call putChar
  ld   a,'x'
  call putChar
  push hl
  ld   a,h
  call printhex
  ld   a,l
  call printhex
  pop  hl
  push hl
.dump_hex_val:
  ; print value as hex duplets
  ld   a,' '
  call putChar
  ld   a,(hl)
  call printhex
  inc  hl
  djnz .dump_hex_val
  ld   a,' '
  call putChar
  ld   b,DUMP_BYTESPERROW
  pop  hl
.dump_ascii_val:
  ld   a,(hl)
  cp   32
  jr   nc, .printable
  ld   a,'.'
.printable
  call putChar
  inc  hl
  djnz .dump_ascii_val
  call println
  dec  c
  jr   nz,.dump_row
.dump_end:
  pop  hl
  pop  bc
  ret

menu_run:
; TODO: make ctrl-c work
  ld   h,d
  ld   l,e ; ld hl,de
  call nextToken

  call getAddress
  ret  z   ; result in de
  ex   de,hl ; now de contains str and hl contains address
  jp   (hl); jump to loaded code which will return

menu_cls:
  call displayClear
  ret

menu_basic:
  jp   BASIC_START

; B = red ; max lower 5 bits (0-31)
; C = green ; max lower 6 bits (0-63)
; D = blue ; max lower 5 bits (0-31)
menu_fgcolor:
  call setColor
  call displaySetForeground

  ld   bc,0
  ld   de,0 ; roll over from start to end
  call displayRepaint
  ret

menu_bgcolor:
  call setColor
  call displaySetBackground

  ld   bc,0
  ld   de,0 ; roll over from start to end
  call displayRepaint
  ret

setColor:
  ld   h,d
  ld   l,e
; get the values
  call nextToken
  call parseDecStr
  push af
  call nextToken
  call parseDecStr
  push af
  call nextToken
  call parseDecStr
  ld   d,a
  pop  af
  ld   c,a
  pop  af
  ld   b,a
  ret

; parses an address string into hl
; input: HL : string
; returns address in DE
; TODO: fix argument  error messages
getAddress:
  ld   a,(hl)
  cp   0 ; no argument given.
  jr   nz,.getadr_start
  ld   hl,argerror_msg
  call printk
  cp   a ; set zero flag
  ret

.getadr_start:
  push bc
  push hl

; MSB
  inc  hl
  ; parse it
  ld   a,(hl)
  ld   b,a
  inc  hl
  ld   a,(hl)
  ld   c,a
  call parseHexStr
  ld   d,a
; LSB
  inc  hl
  ld   a,(hl)
  ld   b,a
  inc  hl
  ld   a,(hl)
  ld   c,a
  call parseHexStr
  ld   e,a

  pop  hl
  pop  bc
  or   1; reset zero flag
  ret


; ****************
; ***
; ****************



; hl contains destination address
loadProgram:
  push bc
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
  pop  bc
  ret


;********************
; rom library routines
;********************

; returns result in a
; IN: digit str
parseDecStr:
  push hl
  push bc
  push de

  ld   b,(hl) ; count in hl
  ld   d,0
  ld   a,0

.loop:
  sla  a  ; multiply by 10 as (d*8+d+d)
  sla  a
  sla  a
  add  d
  add  d ; add the two more times
  ld   d,a ; store results in d

  inc  hl
  ld   a,(hl)
  sub  '0'
  add  d
  ld   d,a
  djnz .loop

  pop  de
  pop  bc
  pop  hl
  ret

; parses a hex string(two values only)
; src str in bc
; result in a
parseHexStr:
  push bc
  ;b is higher order nibble, c is lower order nibble
  ld   a,b
  call char_to_nibble
  ld   b,a  ; put result back in b
  ld   a,c
  call char_to_nibble
  ld   c,a  ; put result back in c

  ;b is higher order nibble, c is lower order nibble
  ; b << 4 | c
  sla  b
  sla  b
  sla  b
  sla  b
  ld   a,b  ; but b in a
  or   c ; or with c
  pop  bc
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
  srl  a
  srl  a
  srl  a
  srl  a
  call printhex_nibble
  pop  af
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
  call putChar
  pop hl
  pop bc
  ret

; Prepare a string for extracting tokens
; destructive to string
; pre:
;   HL pointer to string
; post:
;   HL pointer to first token
;   C number of tokens
tokenize:
  push hl
  push de
  push bc
  ld   b,(hl) ; total str len
  ld   d,h
  ld   e,l ; ld de,hl ; DE = write pointer, HL = read pointer
  ld   a,0
  ld   (num_tokens),a
  ld   c,0 ; current str len
  push de
  pop  ix ; ld ix,de ; ix is start of current string

  inc  hl
  inc  de

.tokenloop:
  ld   a,b ; check if there is any left over
  cp   0
  jr   z,.end ;  while(i>0) {
  ld   a,(hl)
  cp   ' '
  jr   nz,.notspace ; if (*rd == ' ')
  ld   a,c
  cp   0
  jr   z,.next ;if (cnt>0)
  ld   (ix),c
  ld   c,0
  push de
  pop  ix
  inc  de
  jr   .next
.notspace: ; else
  ld   a,c
  cp   0   ;if (cnt==0)
  jr   nz,.nextchar
  ld   a,(num_tokens)
  inc  a
  ld   (num_tokens),a
.nextchar:
  inc  c
  ld   a,(hl)
  ld   (de),a
  inc  de
.next:
  inc  hl
  dec  b
  jr   .tokenloop
.end:
  ld   a,c
  cp   0
  jr   z,.done:
  ld   (ix),c
.done:
  pop  bc
  ld   a,(num_tokens)
  ld   c,a
  pop  de
  pop  hl
  ret

; returns the next token in a string
; IN: last token in HL
; OUT: next token in HL
nextToken:
  push bc
  ld   a,(hl)
  inc  a ; skip length element
  ld   b,0
  ld   c,a
  add  hl,bc
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
  cp   (hl)  ; if(src[i] != dst[i]) // compare bytes
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
  push hl ; keep original hl
  inc  hl
  ld   b,0
.read_line_again:
  call getKeyWait     ; get character

  cp   CR   ; if (a ==  '\r') CR
  jr   z,.read_line_end ;
  cp   LF   ; if (a ==  '\n') LF
  jr   z,.read_line_end;
  cp   BS ;  if (a == '\h') BS
  jr   nz, .if_not_bs
  ld   a,b
  cp   0
  jr   z,.read_line_again ; at the beginning -> do nothing
  ld   a,BS  ; put the cursor one back
  call putChar
  ld   a,' '  ; erase the char from the screen
  call putChar
  ld   a,BS   ; put the cursor one back
  call putChar
  dec  b   ; one less char in the string
  dec  hl
  jr   .read_line_again
.if_not_bs:
  ld   (hl), a    ; input_buf[b] = a
  call putChar
  inc  hl  ; next char
  inc  b  ; one more char in the string
  ; TODO: check for buffer overruns
  jr   .read_line_again
.read_line_end:
  ld   a,b
  pop  hl
  ld   (hl), a ; input_buf[0] = b
  pop  bc
  ret  ; return to caller

println:
  ld   a,CR
  call putChar
  ld   a,LF
  call putChar
  ret


; hl = source address
printk: ; print kernel message to serial (uses pascal strings)

  ; TODO: check if serial is enabled
  call prints; print to serial

  call printd; print to display
  ret


getKeyWait:
  call getKey
  jr   z, getKeyWait
  ret

; result in a, if no data available zero bit is set
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
  ld   a,e
  and  SER_BUF_SIZE-1
  ld   e,a
  ld  (keyb_buf_rd),de ; write pointer back into mem
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
  ld   a,e
  and  SER_BUF_SIZE-1
  ld   e,a
  ld   a,l
  cp   e
  jr   z, .putKey_end  ; head = tail -1 => buffer full
.putKey_put
  ld   hl,(keyb_buf_wr)
  ld   (hl),b
  inc  l
  ld   a,l
  and  SER_BUF_SIZE-1
  ld   l,a
  ld   (keyb_buf_wr),hl
.putKey_end:
  pop  bc
  pop  de
  pop  hl
  ret

putChar:
  push af
  call putSerialChar
  pop  af
  call putDisplayChar
  ret

  section .rodata

rom_msg:          db 22,"Z80 ROM Monitor v0.9",CR,LF
author_msg:       db 30,"(C) January 2021 Jaap Geurts",CR,LF
url_msg:          db 36,"github.com/jaapgeurts/z80_computer",CR,LF
prompt_msg:       db 2, "> "
error_msg:        db 26,"Error - unknown command.",CR,LF
loading_msg:      db 42,"Send data using Xmodem. Load program at 0x"
loading_done_msg: db 16,CR,LF,"Loading done",CR,LF
error_load_msg:   db 20,"Error loading data",CR,LF
nosuchfile_msg:   db 14,"No such file",CR,LF
files_spacer_msg: db 3,TAB,": "
argerror_msg:     db 27,"Wrong or missing argument",CR,LF
error_checksum:   db 10,"Checksum",CR,LF
hexconv_table:    db "0123456789ABCDEF"
rom_time:         db 0,0,0,4,5,1,5,0,3,0,1,2,5

; command jump table
command_table:
cmd_help:    db 4,"help"
             dw menu_help
cmd_files:   db 5,"files"
             dw menu_files
cmd_sload:   db 5,"sload"
             dw menu_sload
cmd_fload:   db 5,"fload"
             dw menu_fload
cmd_dump:    db 4,"dump"
             dw menu_dump
cmd_date:    db 4,"date"
             dw menu_date
cmd_run:     db 3,"run"
             dw menu_run
cmd_cls:     db 3,"cls"
             dw menu_cls
cmd_basic:   db 5,"basic"
             dw menu_basic
cmd_fgcolor: db 7,"fgcolor"
             dw menu_fgcolor
cmd_bgcolor: db 7,"bgcolor"
             dw menu_bgcolor
cmd_tab_end: db 0

