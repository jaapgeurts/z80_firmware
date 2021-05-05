; ***********************
; *** PORT IO MAPPING ***
; ***********************
; IO peripheral port definitions
; CTC ports
CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02
CTC_D equ 0x03

; RTC ports
RTC           equ 0x20
RTC_CD        equ RTC+0x0d
RTC_CE        equ RTC+0x0e
RTC_CF        equ RTC+0x0f

; SIO ports 
SIO_AD equ 0x40
SIO_AC equ 0x42
SIO_BD equ 0x41
SIO_BC equ 0x43

; PSG ports
PSG_REG equ 0x80
PSG_DATA equ 0x81

; TFT display
TFT_C equ 0xA0
TFT_D equ 0xA1


;*****
;** Display constants
;*****

; terminal size, total chars, font sizes
; 40x20,  800, 12x16
; 60x20, 1200,  8x16
; 60x40, 2400,  8x8
; 80x40, 3200,  6x8
FONTW equ 8
FONTH equ 16
BYTESPERFONT equ (FONTW * FONTH) / 8
COLS equ DPYWIDTH / FONTW
ROWS equ DPYHEIGHT / FONTH

DPYWIDTH equ 480
DPYHEIGHT equ 320

TOTALCHARS equ COLS * ROWS

;*****
;** Real time clock
;*****

RTC_REG_COUNT equ 0x0d
; 16 more registers up to 0x2F


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