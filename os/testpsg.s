PSG_REG equ 0x80
PSG_DATA equ 0x81

CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

; tp10 = 131
; ct10 = 0
; ft10 = 131
PSG_FINEA   equ 0
PSG_COARSEA equ 1
PSG_AMPLA   equ 8

PSG_FINEB   equ 2
PSG_COARSEB equ 3
PSG_AMPLB   equ 9

PSG_FINEC   equ 4
PSG_COARSEC equ 5
PSG_AMPLC   equ 10

PSG_ENABLE  equ 7
PSG_PORTA   equ 14
PSG_PORTB   equ 15

  org 0x8000
  push hl
  push bc

  ld   hl, welcome_msg
  rst  PRINTK ; call printk

 start:
  ; set port to output
  ld   a,PSG_ENABLE
  ld   b,0b10111111
  call psgWrite

  ld   b,2
  ld   a,PSG_PORTB ; write out to port
  call psgWrite
.again:
  ld   a,PSG_PORTA
  call psgRead
  bit  0,a
  jr   nz,.nextbut
  ; delay
  call delay_long
  ld   a,PSG_PORTA
  call psgRead
  bit  0,a
  jr   nz,.nextbut
  sla  b
  ld   a,b
  cp   0x10
  jr   nz,.next
  ld   b,2
.next:
  ld   a,PSG_PORTB ; write out to port
  call psgWrite
  jr   .again

.nextbut:
  bit  1,a
  jr   nz,.again

  ld   a,PSG_PORTB ; write out to port
  ld   b,0
  call psgWrite

  pop  bc
  pop  hl
  ret

psgWrite:
  out  (PSG_REG),a
  ld   a,b
  out  (PSG_DATA),a
  ret

psgRead:
  out  (PSG_REG),a
  in   a,(PSG_DATA)
  ret

sound:

  ld   a,PSG_FINEA          ; fine tone = @ 1.8Mhz => 262 ~ 440hz
  out  (PSG_REG),a
  ld   a,30
  out  (PSG_DATA),a

  ld   a,PSG_COARSEA          ; course tone = 0
  out  (PSG_REG),a
  ld   a,1
  out  (PSG_DATA),a

  ld   a,PSG_AMPLA          ; set volume to max
  out  (PSG_REG),a
  ld   a,0x0f
  out  (PSG_DATA),a

  ld   a,PSG_ENABLE          ; enable channel 
  out  (PSG_REG),a
  ld   a,0b00111110
  out  (PSG_DATA),a

  ;jr   begin
  ret

flash:

  ; set port to output
  ld   a,7
  out  (PSG_REG),a
  ld   a,0b11111111
  out  (PSG_DATA),a

again:
  ld   a,15
  out  (PSG_REG),a
  ld   a, 0xff
  out  (PSG_DATA),a
  ld   b,15
.sleep1:
  call delay
  djnz .sleep1
  ld   a,15
  out  (PSG_REG),a
  ld   a, 0x00
  out  (PSG_DATA),a
  ld   b,15
.sleep2:
  call delay
  djnz .sleep2
  jr   again


  pop  bc
  pop  hl
  ret

delay:
  push bc
  ld   b,0x80
.loop:
  djnz .loop
  pop  bc
  ret



delay_long:
  push hl
  push bc
  ld   hl,0x6000
  ld   bc,00
.delay_again:
  sbc  hl,bc
  jr   z,.delay_end
  dec  hl
  jr   .delay_again
.delay_end:
  pop  bc
  pop  hl
  ret


welcome_msg: db 14,"PSG test app",CR,LF