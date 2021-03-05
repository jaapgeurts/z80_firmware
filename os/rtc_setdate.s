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

  call RTCCheckBusy

  ld   hl,v_timestruct
  ld   b,RTC_REG_COUNT
  ld   c,RTC
next:
  ld   a,(hl)
  out  (c),a
  inc  c
  inc  hl
  djnz next

  ; release hold
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC+0x0d),a

  pop  bc
  pop  hl
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

