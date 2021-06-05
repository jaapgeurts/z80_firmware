TFT_C equ 0xA0
TFT_D equ 0xA1



SIO_BD equ 0x41
SIO_BC equ 0x43

CTC_A equ 0x00
CTC_B equ 0x01
CTC_C equ 0x02

PSG_REG equ 0x80
PSG_DATA equ 0x81

PSG_ENABLE  equ 7
PSG_PORTA   equ 14
PSG_PORTB   equ 15

CR equ 0x0D
LF equ 0x0A

GETC      equ 0x0008 ; RST 1 getKey
PUTC      equ 0x0010 ; RST 2 putChar
PRINTK    equ 0x0018 ; RST 3 printk
READLINE  equ 0x0020 ; RST 4 readline
READFILE  equ 0x002b ; readfile
INITCF    equ 0x003b ; initCompactflash
INITFAT   equ 0x003e ; initFat
NEXTTOKEN equ 0x0041 ; nextToken

ILI_WAKEUP         equ 0x11
ILI_DPY_NORMAL     equ 0x13
ILI_DPY_OFF        equ 0x28 
ILI_DPY_ON         equ 0x29
ILI_SET_COLADR     equ 0x2a
ILI_SET_ROWADR     equ 0x2b
ILI_MEM_WRITE      equ 0x2c
ILI_REG_MADCTL equ 0x36
ILI_DPY_VSSA       equ 0x37
ILI_PXL_FMT        equ 0x3a
ILI_SET_DPY_BRIGHT equ 0x51
ILI_DPY_CTRL_VAL   equ 0x53
ILI_READ_ID4       equ 0xd3

ILI_MASK_MADCTL_MY  equ 0x80
ILI_MASK_MADCTL_MX  equ 0x40
ILI_MASK_MADCTL_MV  equ 0x20
ILI_MASK_MADCTL_ML  equ 0x10
ILI_MASK_MADCTL_BGR equ 0x08
ILI_MASK_MADCTL_MH  equ 0x04

DPYWIDTH equ 480
DPYHEIGHT equ 320

DELAY equ 20000 ; 20sec
MAX_IMAGES equ 7 ; current absolute max is 109 photos

v_millis equ 0xf571

BUFFER equ 0x5000

  org 0x4000

  push hl
  push bc
  push de

  ld   h,d
  ld   l,e

;  call NEXTTOKEN
  ld   a,c
  cp   0
  jr   nz,.printarg
  ld   hl,usage_msg
  rst  PRINTK
  jr   .end

.printarg:
  push hl
;  rst PRINTK

    ; set port to A to input and port B to output
  ld   a,PSG_ENABLE
  ld   b,0b10111111
  call psgWrite

  call INITCF
  call INITFAT

  ; set the last time to the current time
;  ld   bc,(v_millis)
;  ld   (v_last),bc


.loop:

  pop  hl
  call viewImage
  cp   0
  jr   nz,.checkagain

  ld    hl,load_error
  rst   PRINTK
  jr    .end

.checkagain:
  ; read button
  ld   a,PSG_PORTA
  call psgRead
  bit  0,a
  jr   z,.end ; if pushed 

  ; has the boolean been flipped because interval elapsed?
  ; if (current - last < interval)
  ; loop
;   ld   hl,(v_millis)
;   ld   (v_current),hl
;   ld   de,(v_last)
;   or   a ; clear carry
;   sbc  hl,de
;   ld   de,DELAY
;   or   a
;   sbc  hl,de
;   jp   m,.checkagain

;   ; set last time to current
;   ld   de,(v_current)
;   ld   (v_last),de

  jr   .checkagain 

.end:



  pop  de
  pop  bc
  pop  hl
  ret

; bc: start, de: end
viewImage:
  push hl
  push bc


  ; load file
  ld   a,1 ; read one sector
  ld   de,BUFFER
  call READFILE

  jr   z,.checkbytes
  jr   .stop
.checkbytes
  ld   a,b
  or   c
  jr   nz,.start
.stop:
  ld   a,0
  jr   .end

.start:
  ; setup display 
  ld   a,ILI_REG_MADCTL     ; set address mode
  out  (TFT_C),a
  ;ld   a,0b00100000
  ld   a,ILI_MASK_MADCTL_ML | ILI_MASK_MADCTL_MV
  out  (TFT_D),a

  ; reset scrolling
  ld   a,ILI_DPY_VSSA
  out  (TFT_C),a
  ld   a, 0
  out  (TFT_D),a
  out  (TFT_D),a  

  ; set display start and end position
  ld   hl,0
  ld   de,DPYWIDTH-1
  call displaySetX1X2  ; from hl -> de
  ld   hl,0
  ld   de,DPYHEIGHT-1
  call displaySetY1Y2

  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a

  ; BC contains bytes read.
  ; write as many bytes to the screen as are in the file
.readloop:
  ld   hl,BUFFER
.writeloop:
  ld   a,(hl)
  inc  hl
  out  (TFT_D),a ; send to display
  dec  bc
  ld   a,b
  or   c   ; 16 bit loop
  jr   nz,.writeloop

  ; load next cluster
  ld   hl,0 ; continue current file
  ld   a,1 ; read one sector
  ld   de,BUFFER
  call READFILE
  jr   z,.checkbytes2
  jr   .stop2
.checkbytes2
  ld   a,b
  or   c
  jr   nz,.readloop
.stop2:
  ld   a,0

  ; reset display orientation

  ld   a,ILI_REG_MADCTL     ; set address mode
  out  (TFT_C),a
  ;ld   a,0b00100000
  ld   a,ILI_MASK_MADCTL_ML | ILI_MASK_MADCTL_MY
  out   (TFT_D),a

  ld   a,1

.end:
  pop  bc
  pop  hl
  ret


; hl = x1,de = x2
displaySetX1X2:
  ld   a,ILI_SET_COLADR   ; set x1,x2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   a,d
  out  (TFT_D),a
  ld   a,e
  out  (TFT_D),a
  ret
  
; set start y1,y2
; hl = y1,de = y2
displaySetY1Y2:
  ld   a,ILI_SET_ROWADR   ; set y1,y2
  out  (TFT_C),a
  ld   a,h
  out  (TFT_D),a
  ld   a,l
  out  (TFT_D),a
  ld   a,d
  out  (TFT_D),a
  ld   a,e
  out  (TFT_D),a
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


imgindex:      db 1
v_last:        dw 0
v_current:     dw 0
welcome_msg:   db 12,"View image",CR,LF
load_error:    db 21,"Error loading image",CR,LF
done_msg:      db 6,"Done",CR,LF
usage_msg:     db 21,"view.com <filename>",CR,LF

