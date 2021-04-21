TFT_C equ 0xA0
TFT_D equ 0xA1

CF_DATA    equ 0xC0
CF_ERRFT   equ 0xC1
CF_SECCNT  equ 0xC2
CF_LBA0    equ 0xC3
CF_LBA1    equ 0xC4
CF_LBA2    equ 0xC5
CF_LBA3    equ 0xC6
CF_STATCMD equ 0xC7


CR equ 0x0D
LF equ 0x0A

GETC     equ 0x0008 ; RST 1 getKey
PUTC     equ 0x0010 ; RST 2 putSerialChar
PRINTK   equ 0x0018 ; RST 3 printk
READLINE equ 0x0020 ; RST 4 readline

ILI_WAKEUP         equ 0x11
ILI_DPY_NORMAL     equ 0x13
ILI_DPY_OFF        equ 0x28 
ILI_DPY_ON         equ 0x29
ILI_SET_COLADR     equ 0x2a
ILI_SET_ROWADR     equ 0x2b
ILI_MEM_WRITE      equ 0x2c
ILI_MEM_ACCESS_CTL equ 0x36
ILI_DPY_VSSA       equ 0x37
ILI_PXL_FMT        equ 0x3a
ILI_SET_DPY_BRIGHT equ 0x51
ILI_DPY_CTRL_VAL   equ 0x53
ILI_READ_ID4       equ 0xd3

DPYWIDTH equ 480
DPYHEIGHT equ 320

  org 0x4000

  push hl
  push bc

  ld   hl,welcome_msg
  rst  PRINTK

;   ld   a,0x0B  ; get display status
;   out  (TFT_C),a

;   in   a,(TFT_D); dummy data
;   in   a,(TFT_D) ; [D7:0]
;   call printhex

;   ld   a,ILI_MEM_ACCESS_CTL     ; set address mode
;   out  (TFT_C),a
;   ld   a,0b00100000
; ;  ld   a,0b00000000
;   out   (TFT_D),a

  call initCompactFlash

  call viewImage

  ld   hl,done_msg
  rst  PRINTK

  pop  bc
  pop  hl
  ret


; bc: start, de: end
viewImage:
  push hl
  push bc
  push de

  ; setup display 

   
  ; set display start and end position
  ld   hl,0
  ld   de,DPYWIDTH-1
  call displaySetX1X2  ; from hl -> de
  ld   hl,0
  ld   de,DPYHEIGHT-1
  call displaySetY1Y2

  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a

  ; prepare compact flash read
  ld   a,'D'
  rst  PUTC

  ld   hl,0 ; start at 0
  ld   de,0 ; start at 0
  ld   b,200 ; = sector count, 512 bytes
  call cfSetBlock
  call cfIssueCommand

  ld   a,'C'
  rst  PUTC

; loop 480x320 times = 3 * 200 * 256 * 2
  ld   d,3
  ld   bc,200 ; b = 0 , c = 200
.viewloop:

  call cfReadByte
  out  (TFT_D),a ; send to display
  call cfReadByte
  out  (TFT_D),a ; send to display

  djnz .viewloop

  ld   b,0  ; dnjz decreases first then compares so is actually 256
  dec  c
  jr   nz,.viewloop

  push bc
  push de
  ld   a,4
  sub  d
  ld   c,a
  ld   b,200
  call multiply
  ex   de,hl
  ld   hl,0 ; start at 0
  ld   b,200 ; = sector count, 512 bytes
  call cfSetBlock
  call cfIssueCommand

  pop  de
  pop  bc

  ld   c,200
  dec  d
  jr   nz,.viewloop

.end:
  pop  de
  pop  bc
  pop  hl
  ret


multiply:
  push de
  push bc
  ld   hl,0
  ld   a,b
  or   a
  jr   z,.end
  ld   d,0
  ld   e,c
.mul_loop:
  add  hl,de
  djnz .mul_loop
.end:
  pop  bc
  pop  de
  ret
  
printhex:
  push af
  srl a
  srl a
  srl a
  srl a
  call printhex_nibble
  pop af
  call printhex_nibble
  ret

printhex_nibble: ; converts a nibble to hex char
  push bc
  push hl
  ld   hl,hexconv_table
  and  0x0F ; take bottom nibble only
  ld   b,0
  ld   c,a
  adc  hl,bc
  ld   a,(hl)
printhex_end:
  rst PUTC
  pop hl
  pop bc
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

displayClear:
  push bc
  ld   hl,0
  ld   de,0x01e0
  call displaySetX1X2
  ld   hl,0
  ld   de,0x0140
  call displaySetY1Y2
  ld   a,ILI_MEM_WRITE    ; do write
  out  (TFT_C),a
; loop 480x320 times = 3 * 200 * 256
  ld   d,3
  ld   bc,200
.dpyClearLoop:
  ld   a,0xf8  ; background blue TODO: move to var
  out  (TFT_D),a
  ld   a,0x00
  out  (TFT_D),a
  djnz .dpyClearLoop
  dec  c
  ld   b,0  ; dnjz decreases first then compares so is actually 256
  jr   nz,.dpyClearLoop
  dec  d
  ld   c,200
  jr   nz,.dpyClearLoop

  pop  bc
  ret


initCompactFlash:

  ld   a,0x04 ; reset
  out  (CF_STATCMD),a ;  
  call cfWaitBusy

  ld   a,0xe0 ; lba3=0, master,mode=lba
  out  (CF_LBA3),a
  
  ld   a,0x01      ; set 8 bit
  out  (CF_ERRFT),a
  
  call cfWaitBusy
  ld   a,0xef
  out  (CF_STATCMD),a ; enable the 8 bit feature

  ld   a,'I'
  rst  PUTC

  ret

; hl,de (src), b = count
cfSetBlock:
  call cfWaitBusy
  ld   a,b
  out  (CF_SECCNT),a

  call cfWaitBusy
  ld   a,e ; bits 0..7 of the block address 
  out  (CF_LBA0),a

  call cfWaitBusy
  ld   a,d ; bits 8..15 of the block address 
  out  (CF_LBA1),a

  call cfWaitBusy
  ld   a,l ; 16..23 of the block address
  out  (CF_LBA2),a

  call cfWaitBusy
  ld   a,h ; 24..27 of the block address
  and  0x0f
  or   0xe0   ; lba mode
  out  (CF_LBA3),a
  ret
  
cfIssueCommand:
  call  cfWaitCmdReady
  ; issue read command
  ld   a, 0x20 
  ;ld   a, 0xec  ; $ec = drive id
  out  (CF_STATCMD),a
  call cfWaitDataReady
  in   a,(CF_STATCMD)					;Read status
  and  %00000001					;mask off error bit
  jr   nz,cfIssueCommand				;Try again if error
  ret

cfReadByte:
; read byte
  call cfWaitDataReady
  in   a,(CF_DATA)
  ret

cfWaitBusy:
  in   a, (CF_STATCMD)					;Read status
  and  0b10000000					;Mask busy bit
  jr   nz,cfWaitBusy				;Loop until busy(7) is 0
  ret

cfWaitCmdReady:
  in   a,(CF_STATCMD)					;Read status
  and  0b11000000					;mask off busy and rdy bits
  xor  0b01000000					;we want busy(7) to be 0 and drvrdy(6) to be 1
  jr   nz,cfWaitCmdReady
  ret

cfWaitDataReady:
  in   a,(CF_STATCMD)					;Read status
  and  0b10001000					;mask off busy and drq bits
  xor  0b00001000					;we want busy(7) to be 0 and drq(3) to be 1
  jr   nz,cfWaitDataReady
  ret

welcome_msg:   db 13,"View image",CR,LF
done_msg:      db 6,"Done",CR,LF
hexconv_table: db "0123456789ABCDEF"
