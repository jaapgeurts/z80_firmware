RTC    equ 0x20

CR equ 0x0D
LF equ 0x0A

RTC_REG_COUNT equ 0x0d

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline


  org 0x8000
  push hl
  push bc

  ld   hl, hello_msg
  rst  PRINTK ; call printk

  ld   hl,v_timestruct
  ld   b,RTC_REG_COUNT
  ld   c,RTC
next:
  ld   a,(hl)
  out  (c),a
  inc  c
  inc  hl
  djnz next

  pop  bc
  pop  hl
  ret

start:

  push hl
  push bc

  ld   hl, hello_msg
  rst  PRINTK ; call printk

  ld   hl,v_timestruct
  ;call RTCInit
  call RTCRead

  ld   b,6
again:
  ld   a,(hl)
  inc  hl
  add  '0'
  rst  PUTC
  djnz again

  ld   hl, done_msg
  rst  PRINTK ; call printk

  pop  bc
  pop  hl
  ret

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

hello_msg: ascii 14,"Setting date. "
done_msg:   db 6,"Done",CR,LF

  org 0x8100
v_timestruct:  db 0,0,8,5,0,2,5,0,3,0,1,2,5


;; PS2/ scancode set 2
