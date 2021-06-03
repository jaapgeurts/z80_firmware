RTC    equ 0x20
RTC_CD  equ RTC+0x0d
RTC_CE  equ RTC+0x0e
RTC_CF  equ RTC+0x0f

CR equ 0x0D
LF equ 0x0A

RTC_REG_COUNT equ 0x0c

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

  org 0x4000
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
  ; sub  '0' unnecessary since only lower nibble is connected.
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
  ld   (iy+5),a   ; 10 hour
  ld   a,(ix+8)
  ld   (iy+4),a   ; 1 hour
  ld   a,(ix+9)
  ld   (iy+3),a   ; 10 minute
  ld   a,(ix+10)
  ld   (iy+2),a   ; 1 minute
  ld   a,(ix+11)
  ld   (iy+1),a   ; 10 second
  ld   a,(ix+12)
  ld   (iy+0),a   ; 1 second

; start counting
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0, hold=0
  out  (RTC_CD),a
  ld   a,0b00000000 ; all clear
  out  (RTC_CE),a
  ld   a,0b00000100 ; test=0, 24hr, stop=0(=>start), reset=0
  out  (RTC_CF),a

  call RTCCheckBusy

  call RTCStopReset

; set actual time data
  ld   hl,v_timestruct
  ld   b,RTC_REG_COUNT
  ld   c,RTC
  call RTCCheckBusy
next:
  ld   a,(hl)
  out  (c),a
  inc  c
  inc  hl
  djnz next

; start counter and release hold
  ld   a,0b00000100 ; test=0, 24hr, stop=0, reset=0
  out  (RTC_CF),a
  ld   a,0b00000000 ; 30s-adj=0, irq=0, busy=0,hold=0
  out  (RTC_CD),a


  ld   hl, done_msg
  rst  PRINTK ; call printk

  pop  bc
  pop  hl
  ret

RTCCheckBusy:
  ld   a,0b00000001  
  out  (RTC_CD),a  ; set hold to 1
  in   a,(RTC_CD)  ; read busy bit;
  bit  1,a
  ; don't delay. unnecesary and is extra code
  ret  z
  ld   a,0b00000000
  out  (RTC_CD),a  ; clear hold bit
  jr   RTCCheckBusy

RTCStopReset:
  push  bc
; stop and reset
  ld   a,0b00000001 ; reset
  out  (RTC_CF),a 
  ld   b,153 ; delay 270us @ 7,372,800 MHz
.RTCInit_delay:
  djnz .RTCInit_delay ; decrease 255 times. takes 13 T-states each loop
  ld   a,0b00000111 ; stop + reset  + 24h ; TODO: setting 24h makes the difference
  out  (RTC_CF),a
  pop  bc
  ret

welcome_msg: ascii 34,"Set date & time: 'YYMMDD HHmmss': "
done_msg:   db 8,CR,LF,"Done",CR,LF

  rorg 0x8100
v_timestruct:  db 0,0,6,1,9,0,6,0,3,0,1,2,5

