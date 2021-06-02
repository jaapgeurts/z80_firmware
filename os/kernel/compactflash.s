
  global initCompactFlash
  global cfRead
  global cfWrite

  section .consts
CF_DATA    equ 0xC0
CF_ERRFT   equ 0xC1
CF_SECCNT  equ 0xC2
CF_LBA0    equ 0xC3
CF_LBA1    equ 0xC4
CF_LBA2    equ 0xC5
CF_LBA3    equ 0xC6
CF_STATCMD equ 0xC7

  section .text

; A = number of sectors
; BCDE = startsector
; HL = destination
cfRead:
  push af
  call cfSetSectorCount
  call cfSetBlock
  call cfIssueReadCommand
  pop  af
  ld   c,a
  ld   b,0 ; read 256 * 2 * numsec bytes
.cfReadLoop:
  call cfWaitDataReady
  in   a,(CF_DATA)
  ld   (hl),a
  inc  hl
  in   a,(CF_DATA)
  ld   (hl),a
  inc  hl
  djnz .cfReadLoop
  dec  c
  jr   nz,.cfReadLoop

  ret

cfWrite:
  ; TODO:
  ret

cfSetSectorCount:
  push af
  call cfWaitBusy
  pop  af
  out  (CF_SECCNT),a
  ret

  ; de,bc (src)
cfSetBlock:
  ; remember 2 byte nums are in little endian
  call cfWaitBusy
  ld   a,c ; bits 0..7 of the block address 
  out  (CF_LBA0),a

  call cfWaitBusy
  ld   a,b ; bits 8..15 of the block address 
  out  (CF_LBA1),a

  call cfWaitBusy
  ld   a,e ; 16..23 of the block address
  out  (CF_LBA2),a

  call cfWaitBusy
  ld   a,d ; 24..27 of the block address
  and  0x0f
  or   0xe0   ; lba mode
  out  (CF_LBA3),a
  ret
  
cfIssueReadCommand:
  call  cfWaitCmdReady
  ; issue read command
  ld   a, 0x20 
  ;ld   a, 0xec  ; $ec = drive id
  out  (CF_STATCMD),a
  call cfWaitDataReady
  in   a,(CF_STATCMD)					;Read status
  and  %00000001					;mask off error bit
  jr   nz,cfIssueReadCommand				;Try again if error
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

initCompactFlash:

  ld   a,0x04 ; reset
  out  (CF_STATCMD),a ;  

  call cfWaitBusy
  ld   a,0x01      ; set 8 bit
  out  (CF_ERRFT),a
  
  call cfWaitBusy
  ld   a,0xef
  out  (CF_STATCMD),a ; enable the 8 bit feature

; DEBUG SERIAL
;   ld   a,'I'
;   rst  PUTC

  ret