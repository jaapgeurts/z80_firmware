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

  ld   hl, welcome_msg
  rst  PRINTK ; call printk

  rst READLINE ; result in hl
  ; parse YYMMDD HHmmss
  ; time struct:  s,s,m,m,H,H,D,D,M,M,Y,Y,W
  push hl
  pop  ix
  inc  ix ; skip first byte (length)
  ld   iy,v_timestruct
  ld   a,(ix+0)
  ld   (iy+11),a  ; 10 year digit
  ld   a,(ix+1)
  ld   (iy+10),a  ; 1 year digit
  ld   a,(ix+2)
  ld   (iy+9),a   ; 10 month
  ld   a,(ix+3)
  ld   (iy+8),a   ; 1 month
  ld   a,(ix+4)
  ld   (iy+7),a   ; 10 day
  ld   a,(ix+5)
  ld   (iy+6),a   ; 1 day
  ld   a,(ix+7)
  ld   (iy+5),a  ; 10 hour
  ld   a,(ix+8)
  ld   (iy+4),a  ; 1 hour
  ld   a,(ix+9)
  ld   (iy+3),a  ; 10 minute
  ld   a,(ix+10)
  ld   (iy+2),a  ; 1 minute
  ld   a,(ix+11)
  ld   (iy+1),a  ; 10 second
  ld   a,(ix+12)
  ld   (iy+0),a  ; 1 second

; set actual data

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

  ld   hl, done_msg
  rst  PRINTK ; call printk

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

welcome_msg: ascii 34,"Set date & time: 'YYMMDD HHmmss': "
done_msg:   db 8,CR,LF,"Done",CR,LF

  org 0x8100
v_timestruct:  db 0,0,6,1,9,0,6,0,3,0,1,2,5

