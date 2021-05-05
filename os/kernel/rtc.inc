
; RTC ports
RTC           equ 0x20
RTC_CD        equ RTC+0x0d
RTC_CE        equ RTC+0x0e
RTC_CF        equ RTC+0x0f
RTC_REG_COUNT equ 0x0d

; 16 more registers up to 0x2F


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

  ld   a,0b00000000 ; clear hold
  out  (RTC_CD),a

  pop  hl
  pop  bc
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