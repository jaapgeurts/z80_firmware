; Code borrowed from
; lmaurits
; https://github.com/lmaurits/lm512

; To use FAT formatted disks make sure to use the following parameters

; 1. FAT volume must be in primary partition
; 2. primary partition must be smaller than 65536 sectors
; 3. sector size must be 512 bytes
; 4. cluster/sectors must be 1


  global initFAT
  global statFile
  global FindFile
  global WriteFile
  global readFile
  global DeleteFile
  global AppendFile
  global CopyFile
  global RenameFile

  section .bss
  ; Stuff for the FAT driver
    fat_sector_buffer:	defs 512	
    fat_buffer_index:	defs 2

    ; FAT specs table ;;;;;;;;;;;
    partition_start_sec:	defs 4
    fat_spec_table:		
    bytes_per_sector:	defs 2
    sectors_per_cluster:	defs 1
    reserved_sectors:	defs 2
    no_of_fats:		defs 1
    no_of_root_dir_ents:	defs 2
    small_total_sectors:	defs 2
    media_descriptor:	defs 1
    sectors_per_fat:	defs 2

    ; Derived FAT specs ;;;;;;;;;;;
    start_of_fat:		defs 2
    start_of_root_dir:	defs 2
    start_of_data:		defs 2

    fat_buffer:		defs 512
    fat_sector:		defs 2
    fat_cluster:		defs 2
    fat_index:		defs 1
    fat_mem_index:		defs 2

    root_dir_buffer:	defs 512
    root_dir_sector:	defs 2
    root_dir_index:		defs 1
    root_dir_mem_index:	defs 2

    ; Directory entry ;;;;;;;;;;;;
    dir_entry_buffer:
    filename:		defs 8
    extension:		defs 3
    attribs:		defs 1
        more_attribs:		defs 1
        creation_millis:	defs 1
        creation_h_m_s:		defs 2
        creation_date:		defs 2
        last_access_date:	defs 2
        yet_more_attribs:	defs 2
    last_write_time:	defs 2
    last_write_date:	defs 2
    starting_cluster:	defs 2
    size_in_bytes:		defs 4


    ; File loading stuff ;;;;;;;;;;;;;;
    fat_dirty:		defs 1
    current_cluster:	defs 2
    memory_pointer:		defs 2
    bytes_remaining:	defs 2
    bytes_read:		defs 2
    total_bytes:		defs 2
    new_file_start_clu:	defs 2
    filename_buffer:	defs 16
    all_done:		defs 1
    read_cluster:		defs 2
    write_cluster:		defs 2
    ; Scratch stuff ;;;;;;;;;;;;;;
    target_filename_ptr:	defs 2
    need_to_add_dir_end:	defs 1


  section .text

; ; TODO: replace
; StrictStrCmp:
; 	; Load next chars of each string
; 	ld a, (de)
; 	ld b, a
; 	ld a, (hl)
; 	; Compare
; 	cp b
; 	; Return non-zero if chars don't match
; 	ret nz
; 	; Check for end of both strings
; 	cp 0x00
; 	; Return if strings have ended
; 	ret z
; 	; Otherwise, advance to next chars
; 	inc hl
; 	inc de
; 	jr StrictStrCmp


initFAT:
	ld	a, 0
	ld	(fat_dirty), a
.readMBR:
	; The MBR is the first sector of the disk.
	ld	hl, fat_sector_buffer
	ld	a, 01	; MBR is one sector
	ld	bc, 00	; MBR starts at sector 0
	ld	de, 00
	call cfRead	; call CF_READ
.readVBR:
	; The MBR contains the address of the first sector of partition 1
	; Store this in memory for future reference, then read that sector
	; (the VBR) into memory.
	ld	ix, fat_sector_buffer+0x1BE  ;partition entry 1
	ld	c, (ix+0x08) ; LBA of first absolute sector in partition
	ld	a, c  ; load into c directly for later use with cfREad
	ld	(partition_start_sec+0), a
	ld	b, (ix+0x09)
	ld	a, b
	ld	(partition_start_sec+1), a
	ld	e, (ix+0x0A)
	ld	a, e
	ld	(partition_start_sec+2), a
	ld	d, (ix+0x0B)
	ld	a, d
	ld	(partition_start_sec+3), a
	ld	a, 01	; VBR is one sector
	ld	hl, fat_sector_buffer
	call cfRead	; call CF_READ
.readBPB:
	; The VBR contains essential information on the FAT filesystem
	; Store all of this in memory for future reference
	ld	hl, fat_sector_buffer+0x0B
	ld	de, fat_spec_table
	ld	bc, 13
	ldir

ComputeSectors:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Assuming that the fat_spec_table is correctly populated, compute
; the address of the first sector of the root directory, and load
; it into the sector buffer.  Note that this function is currently
; LAZY, i.e. it makes assumptions about the FAT spec, e.g. that there
; are 2 FATs.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Compute the starting sectors of various regions of the FAT
	ld	hl, (partition_start_sec)	; Start HL at partition start
	ld	bc, (reserved_sectors)
	add	hl, bc				; Skip past reserved sectors
	ld	(start_of_fat), hl
	ld	bc, (sectors_per_fat)
	add	hl, bc			; Skip past first FAT
	add	hl, bc			; Skip past second FAT
	ld	(start_of_root_dir), hl
	ld	bc, 32			; TODO: Skip past root directory - LAZY
	add	hl, bc
	ld	(start_of_data), hl
	ret

;;;;;;;;;;;;

ClusterToSector:
; Load b,c,d,e with the sector corresponding to the cluster in hl
	ld   bc, (start_of_data)
	add  hl, bc			; add 1 sector per cluster
	or   a			; Clear carry flag
	ld   bc, 2
	sbc  hl, bc			; Subtract 2 (clusters 0, 1 don't map to data region)
	ld   b, h
	ld   c, l
	ld   de, 0
	ret

ClusterToSectorGeneric:
    ; first convert cluster in hl to sector
    or	a			; Clear carry flag
	ld	bc, 2
	sbc	hl, bc			; Subtract 2 (clusters 0, 1 don't map to data region)

    ; multiply by sec/cluster (4 for 32Mb disk)
    ld  a,(sectors_per_cluster)
    ex  de,hl

    ; this can replaced by a shift since sectors/cluster is a power of 2
    call multiply16
    ; ahl now contains the sectors

	ld	d, 0x00 ; de is high byte of sectors
    ld  e,a

	; Load b,c,d,e with the sector corresponding to the cluster in hl
	ld	bc, (start_of_data) ; low byte
	add	hl, bc			; add start offset to sector
    
    jr   nc,.nooverflow   ; if overflow add one to e
    inc  e
.nooverflow:
	ld   b, h
	ld   c, l
	ret

;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; FAT handling stuff
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ResetFat:
	; First save any pending changes
	call	SaveFat
	; Read first sector of FAT off disk
	ld	hl, fat_buffer
	ld	bc, (start_of_fat)
	ld	(fat_sector), bc
ResetFatAdvanceSectorEntryPoint:
	ld	de, 0
	ld	a, 0x01
	call cfRead	; call CF_READ
	; Skip over reserved clusters
	ld	hl, fat_buffer+4
	; Update indexes
	ld	(fat_mem_index), hl
	ld	hl, 0x0002
	ld	(fat_cluster), hl
	ld	a, 2
	ld	(fat_index), a
	ret

;;;;;;;;;;;;

AdvanceCluster:
	;; Increment cluster
	ld	hl, (fat_cluster)
	inc	hl
	ld	(fat_cluster), hl

	;; Increment index and figure out if we need to read new sec
	ld	hl, fat_index
	inc	(hl)
	ld	a, (hl)
	cp	0	; If index has wrapped, we need to read a new sector
	jr	z, AdvanceCluster_ReadNewSector

	;; Increment FAT memory index
	ld	hl, (fat_mem_index)
	inc	hl
	inc	hl
	ld	(fat_mem_index), hl

	ret
AdvanceCluster_ReadNewSector:
	; First save any pending changes
	call	SaveFat
	;; Read new sector
	ld	hl, fat_buffer
	ld	bc, (fat_sector)
	inc	bc
	ld	(fat_sector), bc
	ld	de, 0
	ld	a, 0x01
	call cfRead	; call CF_READ

	;; Reset index and mem_index
	ld	hl, fat_buffer
	ld	(fat_mem_index), hl
	ret

;;;;;;;;;;;;

FindFirstAvailCluster:
	call	ResetFat
	; Check if the first non-reserved cluster is available...
	ld	hl, (fat_mem_index)
	ld	a, (hl)
	inc	hl
	or	(hl)
	cp	0
	; ...if it is, return here
	ret	z
	; ...but if not, fall through into FindNextAvailCluster
;;;;;;;;;;;;

FindNextAvailCluster:
	call	AdvanceCluster
	ld	hl, (fat_mem_index)
	ld	a, (hl)
	inc	hl
	or	(hl)
	cp	0
	ret	z
	jr	FindNextAvailCluster

;;;;;;;;;;;;

ChainClusters:
	;	Chain cluster HL to DE
	ld	bc, (fat_cluster)	; Back up current cluster
	push	bc
	push	de			; Back up dest. cluster
	call	SeekCluster		; Seek cluster HL
	pop	de			; Restore dest. cluster
	ld	hl, (fat_mem_index)	; Set HL to FAT buffer index
	ld	(hl), e			; Write DE (littleendian)
	inc	hl
	ld	(hl), d
	; Mark FAT dirty
	ld	a, 0xFF
	ld	(fat_dirty), a
	pop	hl			; Get back to where we were
	call	SeekCluster
	ret

;;;;;;;;;;;;

TerminateChain:
	ld	hl, (fat_mem_index)	; Set HL to FAT buffer index
	ld	(hl), 0xF8		; Write 0xFFF8 (EOF)
	inc	hl
	ld	(hl), 0xFF
	; Mark FAT dirty
	ld	a, 0xFF
	ld	(fat_dirty), a
	ret

;;;;;;;;;;;;

SeekCluster:
	; jump to cluster in HL
	push	hl
	push	hl
	ld	(fat_cluster), hl	; Keep target cluster
	ex	de,hl			; Now cluster is in DE
	ld	hl, (start_of_fat)
	ld	e, d			; Set DE to 0D
	ld	d, 0
	add	hl, de			; HL is now desired FAT sector

	; Do we need to hit the disk?
	ld	de, (fat_sector)	; Get current sector in DE
	ld	(fat_sector), hl	; Write new sector from  HL
	ex	de, hl			; HL=old, DE=new
	or	a 			; Clear carry flag before sbc
	sbc	hl, de			; If HL-DE=0, HL=DE
	ld	a, h
	or	l
	jr	z, SeekClusterBufferUpToDate

	; First save any pending changes
	call	SaveFat
	ld	b, d			; Setup registers for CF_READ
	ld	c, e
	ld	de, 0
	ld	hl, fat_buffer
	ld	a, 1
	call cfRead	; call CF_READ

SeekClusterBufferUpToDate:
	ld	hl, fat_buffer
	pop	de
	ld	d, 0			; Set DE to 0E
	add	hl, de
	add	hl, de
	ld	(fat_mem_index), hl
	ld	a, e
	ld	(fat_index), a

	pop	hl			; Don't clobber HL
	ret

;;;;;;;;;;;;

TestEOF:
	; Set Zero flag if current cluster value is 0xFFF8 - 0xFFFF
	; Clear Zero flag if not
	ld	hl, (fat_mem_index)	; Get pointer to current cluster
	ld	e, (hl)			; Read next cluster into DE
	inc	hl
	ld	d, (hl)
	ld	a, 0xFF
	cp	d
	ret	nz			; If D != 0xFF, this ain't EOF
	; We're EOF if E is 0xF8, 0xF9, 0xFA, ..., 0xFF.
	; In other words, if the first 5 bits of E are set
	; So let's set the last 3 bits to 1 and then test
	; against 0xFF
	ld	a, e
	or	00000111b
	cp	0xFF
	ret

;;;;;;;;;;;;

FollowClusterChain:
	; Sector we want is start_of_fat + high order byte of current cluster
	ld	hl, (fat_mem_index)	; Get pointer to current cluster
	ld	e, (hl)			; Read next cluster into DE
	inc	hl
	ld	d, (hl)
	ex	de, hl
	call	SeekCluster
	ret

;;;;;;;;;;;;

SaveFat:
	ld	a, (fat_dirty)
	cp	0
	ret	z
	push	hl
	push	bc
	push	de
	ld	hl, fat_buffer
	ld	bc, (fat_sector)
	ld	de, 0
	ld	a, 1
	call	cfWrite
	ld	a, 0
	ld	(fat_dirty), a
	pop	de
	pop	bc
	pop	hl
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Root directory handling stuff
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ResetRootDir:
	; Read first sector of root dir off disk
	ld	hl, root_dir_buffer
	ld	bc, (start_of_root_dir)
	ld	(root_dir_sector), bc
ResetRootDirAdvanceDirEntryPoint:
	ld	de, 0
	ld	a, 0x01
	call cfRead	; call CF_READ
	; Update indexes
	ld	a, 0
	ld	(root_dir_index), a
	ld	hl, root_dir_buffer
	ld	(root_dir_mem_index), hl
	; Copy first entry into dir_ent_buffer
	ld	de, dir_entry_buffer
	ld	bc, 32
	ldir
	ret

;;;;;;;;;;;;

AdvanceDirEnt:
	ld	a, (root_dir_index)
	inc	a
	cp	16	; 16 dir entries / sector
	jr	z, AdvanceDirEnt_ReadNewSector
	ld	(root_dir_index), a
	ld	hl, (root_dir_mem_index)
	ld	bc, 32
	add	hl, bc
	ld	(root_dir_mem_index), hl
	ld	de, dir_entry_buffer
	ldir
	ret
AdvanceDirEnt_ReadNewSector:
	ld	hl, root_dir_buffer
	ld	bc, (root_dir_sector)
	inc	bc
	ld	(root_dir_sector), bc
	jr	ResetRootDirAdvanceDirEntryPoint

;;;;;;;;;;;;

TestLFN:
	ld	a, (attribs)
	cp	0x0F
	ret

;;;;;;;;;;;;

TestEndDir:
	ld	a, (filename)
	cp	0x00
	ret

;;;;;;;;;;;;

TestFreeEntry:
	ld	a, (filename)
	cp	0xE5
	ret

;;;;;;;;;;;;

FindFirstAvailDirEnt:
	call	ResetRootDir
FindFirstAvailDirEntLoop:
	call	TestLFN
	jr	z, FindFirstAvailDirEntNext
	call	TestEndDir
	jr	z, FindFirstAvailDirEnt_DirEnd
	call	TestFreeEntry
	jr	z, FindFirstAvailDirEnt_Free
FindFirstAvailDirEntNext:
	call	AdvanceDirEnt
	jr	FindFirstAvailDirEntLoop
FindFirstAvailDirEnt_Free:
	ld	a, 0x00
	ret
FindFirstAvailDirEnt_DirEnd:
	ld	a, 0xFF
	ret

;;;;;;;;;;;;

MakeDirEndEntry:
	ld	a, 0x00
	ld	(filename), a
	ret

;;;;;;;;;;;;

MakeAvailEntry:
	ld	a, 0xE5
	ld	(filename), a
	ret

;;;;;;;;;;;;

ZeroFilename:
	ld  hl, filename
	ld   a," "
	ld   b, 11
.zeroname_loop:
	ld   (hl), a
	inc  hl
	djnz .zeroname_loop
	ret

;;;;;;;;;;;;

BuildFilenameString:
	; This populates filename_buffer with a human friendly
	; version of the filename of the current dir entry.
	; i.e. it removes padding from the filename, puts a
	; period before extension and a slash after directories.
	ld   hl, filename
	ld   de, filename_buffer	; DE at filename, HL at dir entry
	ld	 c,0			; Copy max 8 chars to filename buffer
    inc  de  ; next pos (first is for strlen)
.loopcpy:
    ld   a,(hl)
    cp   " " ; is it a space
    jr   z,.checkextension:
    ld   (de),a
    inc  hl
    inc  de
    inc  c
    cp   8
    jr   nz,.loopcpy
.checkextension:
    ex   de,hl  ; de = dir entry, hl = filename_buffer

	ld   de, extension		; Check if there is a file extension
	ld   a, (de)
	cp   " "
	jr   z, .addSlash
    
    ; append the extension.
    ld   (hl),'.' 
    inc  hl
    inc  c
    ld   b,3
.loopcpyext:
    ld   a,(de)
    ld   (hl),a
    inc  hl
    inc  de
    inc  c
    djnz .loopcpyext

.addSlash:
	ld   a,(attribs)    ; Get attribute byte
	and  00010000b;		; Mask out the directory bit
	jp   z, .end	    ; If not a dir, we're done
	ld   (hl), '/'		; If we're a dir, add a slash
    inc  c
.end:
	; Terminate string
    ld   a,c
	ld	 (filename_buffer), a
	ret

;;;;;;;;;;;;
; TODO:fix this code too

ReverseBuildFilenameString:
	; This is the reverse of BuildFilenameString
	call	ZeroFilename
	;;;;; Copy filename
	ld	hl, filename
	ld	de, filename_buffer
	ld	b, 8
WriteNameLoop:
	ld	a, (de)
	inc	de
	; If we've hit the end of the string at this point,
	; there is no extension, so we're done with filename
	; wrangling.
	cp	0x00
	ret	z
	; If we've encountered a period, we're done with the
	; filename proper and need to handle the extension
	cp	"."
	jr	z, WriteExtension
	; Otherwise, we can add this char to the filename and
	; then see if we've hit the 8 char limit
	ld	(hl), a
	inc	hl
	djnz	WriteNameLoop
	; At this point we've copied 8 chars.  If we're now
	; pointing at a period, we need to jump over it and then
	; handle the extension
	ld	a, (de)
	cp	"."
	jr	z, SkipPeriod
	; If we're pointing at anything else here, truncate the
	; string and we're done.
	ret
SkipPeriod:
	inc	de
WriteExtension:
	ld	hl, extension
	ld	b, 3
WriteExtensionLoop:
	ld	a, (de)
	inc	de
	cp	0x00
	ret	z
	ld	(hl), a
	inc	hl
	djnz	WriteExtensionLoop


;;;;;;;;;;;;

UpdateRootDir:
	ld	hl, dir_entry_buffer
	ld	de, (root_dir_mem_index)
	ld	bc, 32
	ldir
	ret

;;;;;;;;;;;;

SaveRootDir:
	ld	hl, root_dir_buffer
	ld	bc, (root_dir_sector)
	ld	de, 0
	ld	a, 1
	call	cfWrite
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; File reading and writing stuff
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

readFile:
	; INPUTS
	;
	; A:  Number of consecutive sectors to read (0=whole file)
	; HL: Pointer to filename or 0x0000 to continue file
	; DE: Memory location to load file to
	;
	; OUTPUTS
	;
	; A:  0 if success, else error code
	; HL: 0x0000
	; DE: Pointer to next byte after read data
	; BC: Bytes read
	ld	(memory_pointer), de
	ex	af, af'
	ld	a, h
	or	l
	cp	0
	jr	z, .readFileContinue

	; Find file
	call FindFile
	ret  nz	; FindFileFailed
	ld   hl, (starting_cluster)
	call SeekCluster
	ld   a, 00
	ld   (all_done), a
	jr   .fileNotEmpty

.readFileContinue:
	ld	a, (all_done)
	cp	0xFF
	jr	nz, .fileNotEmpty
	ld	a, 0 ; when done return success and 0 bytes read
	ld	bc, 0x0000
	ld	de, (memory_pointer)
	ret

.fileNotEmpty:
	ld	hl, 0x0000
	ld	(bytes_read), hl
	ld	hl, (memory_pointer)

	ex	af, af'
	cp	0
	jr	z, .readWholeFileLoop

.readFilePartial:
	ld   b, a
.readFilePartialLoop:
	push bc
	call ReadSector
	pop  bc
	jr   z,.readFileAdjustBytes
	djnz .readFilePartialLoop
	jr   .readFileReturn

.readWholeFileLoop:
	call ReadSector
	jr   nz, .readWholeFileLoop
.readFileAdjustBytes:
	ld   a, 0xFF
	ld   (all_done), a
	ld   de, (size_in_bytes)
	ld   a, d
	and  1
	ld   d, a
	ld   hl, (bytes_read)
	ld   bc, 512
	or   a ; Clear carry flag before sbc
	sbc  hl, bc
	add  hl, de
	ld   (bytes_read), hl

.readFileReturn:
	ld   a, 0
	cp   a	; Set zero flag
	ex   de, hl
	ld   hl, 0x000
	ld   bc, (bytes_read)
	ret

ReadSector:
	; READ ONE SECTOR OF CURRENT FILE TO HL
	; If this is the last sector of the file, return with Z flag
	; Otherwise, advance sector pointer and return without Z
	; At exit, HL points to END of copied memory
	push	hl
	; Convert current_cluster to sector in b,c,d,e
	ld	hl, (fat_cluster)
	call	ClusterToSector
	; Read one sector
	pop	hl
	ld	a, 0x01
	call cfRead	; call CF_READ
	push	hl
	ld	hl, (bytes_read)
	ld	de, 0x200
	add	hl, de	; FIX oh god, need to be 32 bit!
	ld	(bytes_read), hl
	; Is there another cluster?
	call	TestEOF
	pop	hl
	ret	z
	push	hl
	call	FollowClusterChain
	pop	hl
	or	1	; Reset zero flag
	ret

;;;;;;;;;;;;

WriteFile:
	; Write BC bytes from memory, starting at DE, to disk.
	; Give filename pointed to by HL.

	; First, save params to memory
	ld	(memory_pointer), de
	ld	(total_bytes), bc
	ld	(bytes_remaining), bc
	ld	(target_filename_ptr), hl

	; Now, find an empty sector to start the chain
	; and remember it
	call	FindFirstAvailCluster
	ld	hl, (fat_cluster)
	ld	(new_file_start_clu), hl

	call	WriteFileWriteAllSectors
	; Now add the corresponding directory entry
	call	ResetRootDir
	call	FindFirstAvailDirEnt
	push	af		; Store A, which tells us whether
				; or not we need to add a new
				; dir end marker

	;; Copy the provided filename into the buffer
	ld	hl, (target_filename_ptr)
	ld	de, filename_buffer
	ld	bc, 16
	ldir
	;; Now fill the dent with it
	call	ReverseBuildFilenameString


	;; Starting cluster
	ld	de, (new_file_start_clu)
	ld	hl, starting_cluster
	ld	(hl), e
	inc	hl
	ld	(hl), d
	;; Total size
	ld	de, (total_bytes)
	ld	hl, size_in_bytes
	ld	(hl), e
	inc	hl
	ld	(hl), d
	inc	hl
	ld	(hl), 0x00
	inc	hl
	ld	(hl), 0x00
	;; Attribs
	ld	a, 0
	ld	(attribs), a

	;; Write theupdated directory entry back to disk
	call	UpdateRootDir
	call	SaveRootDir
	pop	af		; Restore A, which flags whether
				; or not we need to write a dir end
	cp	0
	ret	z

WriteFileMakeNewEndOfDir:
	; If we're here, we need to add a new end-of-dir marker
	; dent, because we clobbered the old one.
	call	AdvanceDirEnt
	call	MakeDirEndEntry
	call	UpdateRootDir
	call	SaveRootDir
	ret

WriteFileWriteAllSectors:
	; Now write all the sectors in the chain
WriteFileWriteSector:
	;; Write a sector
	ld	hl, (fat_cluster)
	call	ClusterToSector
	ld	hl, (memory_pointer)
	ld	a, 1
	call	cfWrite
	;; Save memory pointer
	ld	(memory_pointer), hl
	;; Figure out if we're done or need another sector
	ld	hl, (bytes_remaining)
	ld	de, 512
	or	a ; Clear carry flag before sbc
	sbc	hl, de
WriteFileAppendFileEntry:
	;; If that sbc went negative, we're done
	jr	c, WriteFileEndChain
	;; If not, we need to allocate another sector in the chain
	ld	(bytes_remaining), hl

	ld	hl, (fat_cluster)
	push	hl
	call	FindNextAvailCluster
	pop	hl
	ld	de, (fat_cluster)
	call	ChainClusters
	jr	WriteFileWriteSector
WriteFileEndChain:
	call	TerminateChain
	ret

;;;;;;;;;

AppendFile:
	; Write BC bytes from memory, starting at DE, to disk,
	; appending to file whose filename is pointed to by HL.
	; First, save params to memory
	ld	(memory_pointer), de
	ld	(total_bytes), bc
	ld	(bytes_remaining), bc
	call	FindFile
	ret	nz

	; Skip to the final cluster
	ld	hl, (starting_cluster)
	call	SeekCluster

AppendFileLoop:
	call	TestEOF
	jr	z, AppendFileFinalFound
	call	FollowClusterChain
	jr	AppendFileLoop

AppendFileFinalFound:
	; Read final sector into buffer
	ld	hl, fat_sector_buffer
	call	ReadSector
	; Find number of bytes used in last sector
	ld	de, (size_in_bytes)
	ld	a, d
	and	1
	ld	d, a
	; First figure out amount of free space in final sector
	or	a			; Clear carry flag
	ld	hl, 512
	sbc	hl, de
	push	hl	; Two copies of free space
	push	hl
	; Now find address at which this free space starts
	ld	hl, fat_sector_buffer
	add	hl, de
	; Append to final sector
	pop	bc 	; BC = free space
	ex	de,hl	; DE = start of free space
	; Do we actually have less to copy than we do free space?
	ld	hl, (bytes_remaining)
	or	a			; Clear carry flag
	sbc	hl, bc
	jr	nc, AppendFileFoo
	; If so, use bytes_remaining, not free space for bc
	ld	bc, (bytes_remaining)
AppendFileFoo:
	ld	hl, (memory_pointer)
	ldir
	push	hl	; Pointer to rest of data to append
	; Write updated final sector to disk
	ld	hl, (fat_cluster)
	call	ClusterToSector
	ld	hl, fat_sector_buffer
	ld	a, 1
	call	cfWrite
	; Now we are basically in the middle of a standard
	; WriteFile, just need to set some things up...
	pop	hl
	ld	(memory_pointer), hl
	ld	hl, (bytes_remaining)
	pop	bc ; free space in final sector
	or	a			; Clear carry flag
	sbc	hl, bc
	call	WriteFileAppendFileEntry
	; Update dir entry
	ld	de, (total_bytes)
	ld	hl, (size_in_bytes)
	add	hl, de
	ld	(size_in_bytes), hl
	jr	nc, AppendSaveRootDir
	ld	hl, (size_in_bytes+2)
	inc	hl
	ld	(size_in_bytes+2), hl
AppendSaveRootDir:
	call	UpdateRootDir
	call	SaveRootDir
	ret


;;;;;;;;;

CopyFile:
; HL old
; DE new
	push	de
	call	FindFile
	pop	de
	ret	nz
	ld	(target_filename_ptr), de
	ld	hl, (starting_cluster)
	ld	(read_cluster), hl

	call	FindFirstAvailCluster
	ld	hl, (fat_cluster)
	ld	(new_file_start_clu), hl
	ld	(write_cluster), hl

CopyFileLoop:
	; Read
	ld	hl, (read_cluster)
	call	SeekCluster
	ld	hl, fat_sector_buffer
	call	ReadSector
	jr	nz, CopyFileWrite	
	ld	a, 0xff
	ld	(all_done), a
CopyFileWrite:
	; Write
	ld	hl, (fat_cluster)
	ld	(read_cluster), hl
	ld	hl, (write_cluster)
	call	SeekCluster
	call	ClusterToSector
	ld	hl, fat_sector_buffer
	ld	a, 0x01
	call	cfWrite
	ld	a, (all_done)
	cp	0xff
	jr	z, CopyFileDone
	ld	hl, (fat_cluster)	; Put prev cluster on stack
	push	hl
	call	FindNextAvailCluster
	pop	hl			; Chain new to old cluster
	ld	de, (fat_cluster)
	ld	(write_cluster), de
	call	ChainClusters
	jr	CopyFileLoop

CopyFileDone:
	call	TerminateChain

CopyFileMakeDent:
	; Copy other dent to sector_buffer
	ld	hl, dir_entry_buffer
	ld	de, fat_sector_buffer
	ld	bc, 32
	push	bc
	push	de
	push	hl
	ldir

	call	ResetRootDir
	call	FindFirstAvailDirEnt
	ex	af,af'		; Store A, which tells us whether
				; or not we need to add a new
				; dir end marker
	pop	de
	pop	hl
	pop	bc
	ldir

	;; Copy the provided filename into the buffer
	ld	hl, (target_filename_ptr)
	ld	de, filename_buffer
	ld	bc, 16
	ldir
	;; Now fill the dent with it
	call	ReverseBuildFilenameString

	;; Replace starting sector
	ld	hl, (new_file_start_clu)
	ld	(starting_cluster), hl

	;; Write theupdated directory entry back to disk
	call	UpdateRootDir
	call	SaveRootDir
	ex	af,af'		; Restore A, which flags whether
				; or not we need to write a dir end
	cp	0
	ret	z
	jp	WriteFileMakeNewEndOfDir

;;;;;;;;;;;;

FindFile:
	; Advance directory pointer to find file matching string
	; pointed to by HL
	ld	(target_filename_ptr), hl
	call	ResetRootDir		; Jump to start of root dir
FindFileLoop:
	call	TestEndDir
	jr	z, FindFileNotFound
	call	TestFreeEntry
	jr	z, FindFileNext
	call	TestLFN
	jr	z, FindFileNext
	; Compare names
	call	BuildFilenameString
	ld	hl, filename_buffer
	ld	de, (target_filename_ptr)
	call	stringCompare
	; If match, jump to end
	jr	z, FindFileFound
	; Otherwise check next entry
FindFileNext:
	call	AdvanceDirEnt
	jr	FindFileLoop
FindFileFound:
	; We found it, and the dir entry now points at it
	ld	a, 0	; Success
	cp	0
	ret
FindFileNotFound:
	; We did NOT find it! :(
	ld	a, 0xFF	; Fail!
	cp	0
	ret


;;;;;;;;;;


DeleteFile:
	; Delete file corresponding to the current directory entry
	; First, remove the directory entry
	call	FindFile
	ret	nz
	call	MakeAvailEntry
	call	UpdateRootDir
	call	SaveRootDir
	; Now free up the blocks in the FAT
	ld	hl, (starting_cluster)
	call	SeekCluster
RmLoop:
	call	TestEOF
	push	af			; Preserve results of EOF test
	ld	hl, (fat_mem_index)	; Get pointer to current cluster
	ld	e, (hl)			; Read next cluster into DE
	inc	hl
	ld	d, (hl)
	push	de
	;; Mark this cluster free
	ld	hl, (fat_mem_index)
	ld	a, 0x00
	ld	(hl), a
	inc	hl
	ld	(hl), a
	; Mark FAT dirty
	ld	a, 0xFF
	ld	(fat_dirty), a
	;; Get next cluster back in HL
	pop	hl
	pop	AF			; Restore results of EOF test
	ret	z			; If this was the last cluster, return
	call	SeekCluster		; Otherwise, jump to the next
	jr	RmLoop

;;;;;;;;;;

RenameFile:
	; HL points to old name
	; DE points to new name
	push		de		; Backup new name pointer
	call		FindFile
	jr		nz, RenameAbort
	; Dent *should* now be pointed at our target
	; Copy the new name into the filename buffer
	pop		hl		; New name pointer in HL
	ld		de, filename_buffer
	ld		bc, 12
	ldir
	; Overwrite the filename in the dent buffer
	call		ReverseBuildFilenameString
	; Save new dent to disk
	call		UpdateRootDir
	call		SaveRootDir
	ret
RenameAbort:
	pop		de
	ld		a, 0xff
	ret

;;;;;;;;;;;;

statFile:
	ld	b, a
	ld	a, h
	or	l
	jr	z, .statFileSearch
	; HL points to a filename, find it
	call	FindFile
	ret	nz
.statFilePopulateResults:
	call	BuildFilenameString
	ld	hl, filename_buffer
	ld	de, (size_in_bytes)
	ld	bc, (size_in_bytes+2)
	ld	a, 0
	ret
.statFileSearch:
	ld	a, b
	cp	0
	jr	nz, .statFileSearchNext
	call	ResetRootDir		; Jump to start of root dir
.statFileSearchLoop:
	call	TestEndDir
	jr	z, .statFileEnd
	call	TestFreeEntry
	jr	z, .statFileSearchNext
	call	TestLFN
	jr	nz, .statFilePopulateResults
.statFileSearchNext:
	call	AdvanceDirEnt
	jr	.statFileSearchLoop
.statFileEnd:
	ld	a, 0xFF
	ret
