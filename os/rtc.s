RTC    equ 0x20

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


  org 0x8000

start:

  ld   hl, hello_msg
  rst  PRINTK ; call printk

  ; code for accessing rtc
  push bc
  push hl

  jp   ReadRTC

RTCInit:

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
  ld   a,0b00000000 ; set all counts to 0
  ld   b,0x0d
  ld   c,RTC
.RTCInit_next:
  out  (c),a
  inc  c
  djnz .RTCInit_next

; start counter and release hold
  ld   a,0b00000100 ; test=0, 24hr, stop=0, reset=0
  out  (RTC+0x0f),a
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC+0x0d),a

; done init

ReadRTC:
  ld   b,6
  ld   c,RTC+5
  call RTCCheckBusy

.ReadRTC_loop:

  in   a,(c) ;

  and  0x0F ; chop off high nibble
  add  '0'
  rst  PUTC ; call putSerialChar
  dec  c
  djnz .ReadRTC_loop

; release hold
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC+0x0d),a

  ld   hl,newline
  rst  PRINTK ; call printk

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

hello_msg: ascii 11,"Date test: "
newline:   db 3,CR,LF

;; PS2/ scancode set 2
