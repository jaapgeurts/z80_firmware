   include "consts.inc"

   global initSerialKeyboard
   global ISR_SerialB_Keyboard

; keyboard codes 
SC_L_SHIFT equ 0x12
SC_R_SHIFT equ 0x59

; special codes
SC_BAT_OK  equ 0xaa
SC_RELEASE equ 0xf0
SC_ACK     equ 0xfa
SC_ERR     equ 0xfc

KBD_MASK_RELEASE  equ 0x01 ; for F0 codes
KBD_MASK_EXTENDED equ 0x02 ; for E0 codes
KBD_MASK_SHIFT    equ 0x04 ; for shift down
KBD_MASK_CTRL     equ 0x08 ; for ctrl down 
KBD_MASK_ALT      equ 0x10 ; for alt down
KBD_MASK_META     equ 0x20 ; for meta down
KBD_MASK_CAPS     equ 0x40 ; for caps lock ON
KBD_MASK_NUM      equ 0x40 ; for num lock ON

  section .bss

  v_kbdstate:    dsb 1 ; keyboard state


  section .text

ISR_SerialB_Keyboard:
  di
  push af
  push bc
  push hl

  ; reset the interrupt in the SIO
  ; This is only necessary if we use MODE 1 interrupts.
  ; reti takes care of this.
;   ld   a,0b00111000
;   out  (SIO_AC),a

  ; check if we're expecting a key that's being released
  ld   a,(v_kbdstate)
  ld   c,a ; store a
  and  KBD_MASK_RELEASE
  jp   z, .read_key ; not waiting for release?
  ; incoming scancode being released
  ld   a,c ; c contains v_kbdstate
  and  ~KBD_MASK_RELEASE ; set release to false
  ld   (v_kbdstate),a 
  ld   c,a
  ;   read it and check what was being released
  in   a,(SIO_BD)

  ; check if left or right shift
  cp   SC_L_SHIFT
  jp   z,.shiftOff
  cp   SC_R_SHIFT
  jp   nz,.isr_kbd_end
.shiftOff:
  ; shift off
  ld   a,c ; get keystate
  and  ~KBD_MASK_SHIFT
  ld   (v_kbdstate),a

  jp   .isr_kbd_end ; done

.read_key:
  in   a,(SIO_BD) ; read byte sent by kbd
  cp   SC_RELEASE
  jr   nz,.key_press
  ; key release code
  ld   a,c ; c contains v_kbdstate
  or   KBD_MASK_RELEASE ; set release to true
  ld   (v_kbdstate),a
  jp  .isr_kbd_end
.key_press:

  ; check if left or right shift
  cp   SC_L_SHIFT
  jp   z,.shiftOn
  cp   SC_R_SHIFT
  jp   z,.shiftOn
  cp   SC_BAT_OK
  jp   z,.isr_kbd_end
  cp   SC_ACK
  jp   z,.isr_kbd_end
  ; none of the above so probably a normal key => translate it to ascii
  jp   .translate
  ; shift on
.shiftOn:
  ld   a,c ; get keystate
  or   KBD_MASK_SHIFT
  ld   (v_kbdstate),a
  jp   .isr_kbd_end

.translate:
  call translateScancode
  ; put into ringbuffer
  call putKey
  
.isr_kbd_end:
  pop  hl
  pop  bc
  pop  af
  ei
  reti

; getKeyboardChar:
; ; check if character available
;   ld   a, 0b00000000 ; write to WR1. Next byte is RR0
;   out  (SIO_BC), a
;   in   a,(SIO_BC)
;   bit  0, a
;   jr   z,getKeyboardChar  ; no char available
; ; if yes, then read and return in a
;   in   a,(SIO_BD)
;   ret


; KEYBOARD FUNCTIONS

; TODO: don't translate in the interrupt, instead translate later

translateScancode:
;   ; if larger than 80; just store it otherwise translate
   cp   0x80
   ret  nc

   ld   c,a ; store the key we're translating
   ld   hl,trans_table_normal
   ld   a,(v_kbdstate)
   and  KBD_MASK_SHIFT
   jp   z,.translate:
   ld   hl,trans_table_shifted
 .translate:
   ld   b, 0
   add  hl, bc ; add the offset to the start
   ld   a,(hl) ; return they key
   ret

; init the serial port
initSerialKeyboard:

  ld   a,0
  ld   (v_kbdstate),a

; reset channel B
  ld   a, 0b00110000
  out  (SIO_BC), a

; prepare for writing WR4, must write WR4 first
  ld   a, 0b00000100 ; write to WR0. Next byte is WR4
  out  (SIO_BC), a
  ld   a, 0b00000101              ; set clock rate, odd parity, 1 stopbit
  out  (SIO_BC), a

  ; write to register 5

  ld   a, 0b00000101
  out  (SIO_BC), a
  ld   a, 0b10000010;   ; DTR low and RTS low (results in clock and data high)
  out  (SIO_BC), a

; enable receive (WR3)
  ld   a, 0b00000011
  out  (SIO_BC), a
  ld   a, 0b11000001             ; recv enable; 8bits/char
  out  (SIO_BC), a

; **********
; * Serial interrupts
; **********

    ; enable interrupt on char (WR1)
  ld   a, 0b00000001 ; 
  out  (SIO_BC), a
  ld   a, 0b00011100 ; int on all Rx chars; status affects vector
  out  (SIO_BC), a

  ld   a,0b00000010 ; prepare WR2 (interrupt vector)
  out  (SIO_BC),a
  ld   a,0x10 ; 
  out  (SIO_BC),a

  ret

;; PS2/ scancode set 2

  section .rodata

trans_table_normal:
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0  ; number at the start the array
  db 0x00,0x00,0x00,0x00,0x00,0x09, '`',0x00 ; 8
  db 0x00,0x00,0x00,0x00,0x00, 'q', '1',0x00 ; 10
  db 0x00,0x00, 'z', 's', 'a', 'w', '2',0x00 ; 18
  db 0x00, 'c', 'x', 'd', 'e', '4', '3',0x00 ; 20
  db 0x00, ' ', 'v', 'f', 't', 'r', '5',0x00 ; 28
  db 0x00, 'n', 'b', 'h', 'g', 'y', '6',0x00 ; 30
  db 0x00,0x00, 'm', 'j', 'u', '7', '8',0x00 ; 38
  db 0x00, ',', 'k', 'i', 'o', '0', '9',0x00 ; 40
  db 0x00, '.', '/', 'l', ';', 'p', '-',0x00 ; 48
  db 0x00,0x00, "'",0x00, '[', '=',0x00,0x00 ; 50
  db 0x98,0x00,0x0D, ']',0x00, "\",0x00,0x00 ; 58 ; added 58=98 caps lock
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x08,0x00 ; 60
  db 0x00, '1',0x00, '4', '7',0x00,0x00,0x00 ; 68
  db  '0', '.', '2', '5', '6', '8',0x1b,0xb7 ; 70 ; added 77=b7 num lock
  db 0x00, '+', '3', '-', '*', '9',0xbe,0x00 ; 78 ; added 7e=0xbe scroll lock
trans_table_shifted:
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0   ; number at the start the array
  db 0x00,0x00,0x00,0x00,0x00,0x09, '~',0x00 ; 8
  db 0x00,0x00,0x00,0x00,0x00, 'Q', '!',0x00 ; 10
  db 0x00,0x00, 'Z', 'S', 'A', 'W', '@',0x00 ; 18
  db 0x00, 'C', 'X', 'D', 'E', '$', '#',0x00 ; 20
  db 0x00, ' ', 'V', 'F', 'T', 'R', '%',0x00 ; 28
  db 0x00, 'N', 'B', 'H', 'G', 'Y', '^',0x00 ; 30
  db 0x00,0x00, 'M', 'J', 'U', '&', '*',0x00 ; 38
  db 0x00, '<', 'M', 'I', 'O', ')', '(',0x00 ; 40
  db 0x00, '>', '?', 'L', ':', 'P', '_',0x00 ; 48
  db 0x00,0x00, '"',0x00, '{', '+',0x00,0x00 ; 50
  db 0x98,0x00,0x0D, '}',0x00, "|",0x00,0x00 ; 58
  db 0x00,0x00,0x00,0x00,0x00,0x00,0x08,0x00 ; 60
  db 0x00, '1',0x00, '4', '7',0x00,0x00,0x00 ; 68
  db  '0', '.', '2', '5', '6', '8',0x1b,0xb7 ; 70
  db 0x00, '+', '3', '-', '*', '9',0xbe,0x00 ; 78

