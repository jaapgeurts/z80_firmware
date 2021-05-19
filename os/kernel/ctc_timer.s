  include "consts.inc"

  global initCTC
  global ISR_Timer1_IncCounter

; MILLIS_CORRECTION equ 145 ; at 145 ticks skip increment by 1. effectively 145->144

  section .bss

    v_millis:      dsb 4 ; 4 bytes long (32 bits = 49 days)
    ; v_millis_corr: dsb 1 ; keep track of time correction (skip one tick at 145 counts)


  section .text

ISR_Timer1_IncCounter:
  di
  push hl
  push af

; In case time correction has to happen
;   ld   a,(v_millis_corr)
;   inc  a
;   cp   MILLIS_CORRECTION
;   jp   nz, .skipCorrection
;   ld   a,0
;   ld   (v_millis_corr),a
;   jp   .endInc

.skipCorrection:
  ; takes minimally 31  T states
  ; maximally 129 T states
  ld   hl,v_millis  ; 10

  inc  (hl)         ; 11
  ; byte 1
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 2
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 3
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  ; byte 4
  jp   nz,.endInc   ; 10
  inc  hl           ; 6
  inc  (hl)         ; 11
  
.endInc:
  pop  af
  pop  hl
  ei
  reti


initCTC:

  push af ; store af. it contains the baud rate time constant

  ld   bc,0
  ld   (v_millis),bc
  ld   (v_millis+2),bc
;   ld   a,0
;   ld   (v_millis_corr),a

  ; setup baud rate generator

; clock is 7,372,800 Hz
; clock frequency of the CTC must be 2x trigger frequency. In other words:
; input frequency on TRG0 is 3,686,400 Hz (must be at least half the clock freq)
  ld a, 0b01010101 ; control register, external trigger, counter mode, rising edge 
  out  (CTC_A), a
  ; baudrates - 3.6853 MHz
  ; 9600      - 24
  ; 19200     - 12
  ; 57600     - 4
  ; 115200    - 2
  pop  af
  out  (CTC_A), a

  ; setup millis timer

  ld   a,0b10110101; int, timer, scale 256, rising, autostart,timeconst,cont,vector
  out  (CTC_B),a
  ld   a,29 ; 1ms (0.00100694444444s) ; after 145ms skip one increment
  out  (CTC_B),a

  ld   a,0       ; set interrupt vector
  out  (CTC_A),a
  out  (CTC_A),a

  ret
