; ============================================================================
; Project127 FAT16 root-directory reader
; Module version: 0.1.0
; Derived from Project127/113 FAT16 BPB/root-directory flow.
; Uses the Project130 NEMO-DIVIDE LBA28 single-sector transport; Project127 is the protocol reference.
; Read-only: no writes, DMA, IRQ, IM/EI or paging OUT.
; Output: each root entry is displayed in the ATM UI and mirrored to debug port #EF.
; ============================================================================
P130_HDD_FAT16_VERSION_MAJOR EQU 0
P130_HDD_FAT16_VERSION_MINOR EQU 1
P130_HDD_FAT16_VERSION_PATCH EQU 0

SECTION CODE
EXTERN _p130_hdd_read_sector_lba28
EXTERN _p130_hdd_lba
EXTERN _p130_hdd_sector
EXTERN _p130_hdd_error
EXTERN _p130_debug_putc
PUBLIC _p130_hdd_list_root
PUBLIC _p130_hdd_fat_file_count

; Parse the FAT16 BPB at LBA 63, calculate the absolute root-directory LBA,
; read every root-directory sector and print each valid 8.3 entry.
; IN: _p130_hdd_sector contains the partition boot sector from probe.
; OUT: carry=1 on invalid BPB or sector-read failure.
_p130_hdd_list_root:
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy

        xor     a
        ld      (p130_hdd_fat_error),a
        ld      (_p130_hdd_fat_file_count),a
        ld      (_p130_hdd_fat_file_count+1),a
        ld      hl,p130_hdd_fat_msg_begin
        call    p130_hdd_puts

        ; The transport already validated bytes/sector=512 and 55AA.
        ; Validate the FAT16 fields needed to locate the fixed root directory.
        ld      a,(_p130_hdd_sector+13)
        or      a
        jp      z,p130_hdd_fat_bad_bpb
        ld      a,(_p130_hdd_sector+16)
        or      a
        jp      z,p130_hdd_fat_bad_bpb
        ld      hl,(_p130_hdd_sector+17)
        ld      a,h
        or      l
        jp      z,p130_hdd_fat_bad_bpb

        ; Bound root entries to 4096 (256 sectors) to reject corrupt BPBs.
        ld      a,h
        cp      10h
        jr      c,p130_hdd_fat_root_size_ok
        jp      nz,p130_hdd_fat_bad_bpb
        ld      a,l
        or      a
        jp      nz,p130_hdd_fat_bad_bpb
p130_hdd_fat_root_size_ok:
        ld      (p130_hdd_fat_entries_left),hl

        ld      de,(_p130_hdd_sector+22)
        ld      a,d
        or      e
        jp      z,p130_hdd_fat_bad_bpb

        ; ROOT_LBA = partition LBA 63 + reserved sectors + FAT count * FAT size.
        ld      hl,63
        ld      (p130_hdd_fat_root_lba),hl
        ld      hl,0
        ld      (p130_hdd_fat_root_lba+2),hl

        ld      de,(_p130_hdd_sector+14)
        ld      hl,(p130_hdd_fat_root_lba)
        add     hl,de
        ld      (p130_hdd_fat_root_lba),hl
        jr      nc,p130_hdd_fat_reserved_no_carry
        ld      hl,(p130_hdd_fat_root_lba+2)
        inc     hl
        ld      (p130_hdd_fat_root_lba+2),hl
p130_hdd_fat_reserved_no_carry:
        ld      a,(_p130_hdd_sector+16)
        ld      (p130_hdd_fat_fat_count),a
        ld      de,(_p130_hdd_sector+22)
p130_hdd_fat_add_fat_loop:
        ld      hl,(p130_hdd_fat_root_lba)
        add     hl,de
        ld      (p130_hdd_fat_root_lba),hl
        jr      nc,p130_hdd_fat_add_no_carry
        ld      hl,(p130_hdd_fat_root_lba+2)
        inc     hl
        ld      (p130_hdd_fat_root_lba+2),hl
p130_hdd_fat_add_no_carry:
        ld      a,(p130_hdd_fat_fat_count)
        dec     a
        ld      (p130_hdd_fat_fat_count),a
        jr      nz,p130_hdd_fat_add_fat_loop

        ; RootDirSectors = ceil(RootEntCnt / 16), since sector size is 512.
        ld      hl,(p130_hdd_fat_entries_left)
        ld      de,15
        add     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      (p130_hdd_fat_sectors_left),hl

        ld      hl,p130_hdd_fat_msg_root
        call    p130_hdd_puts

p130_hdd_fat_sector_loop:
        ld      hl,(p130_hdd_fat_entries_left)
        ld      a,h
        or      l
        jp      z,p130_hdd_fat_complete
        ld      hl,(p130_hdd_fat_sectors_left)
        ld      a,h
        or      l
        jp      z,p130_hdd_fat_complete

        ; Copy the calculated 32-bit root LBA to the transport request.
        ld      hl,(p130_hdd_fat_root_lba)
        ld      (_p130_hdd_lba),hl
        ld      hl,(p130_hdd_fat_root_lba+2)
        ld      (_p130_hdd_lba+2),hl
        call    _p130_hdd_read_sector_lba28
        jp      c,p130_hdd_fat_read_failed

        ld      ix,_p130_hdd_sector
        ld      a,16
        ld      (p130_hdd_fat_slots_left),a

p130_hdd_fat_entry_loop:
        ld      hl,(p130_hdd_fat_entries_left)
        ld      a,h
        or      l
        jp      z,p130_hdd_fat_complete

        ; FAT directory entry 00h terminates the directory.
        ld      a,(ix+0)
        or      a
        jp      z,p130_hdd_fat_complete
        cp      0E5h
        jr      z,p130_hdd_fat_skip_entry

        ; Ignore long-name and volume-label entries. Keep ordinary files
        ; and subdirectories, matching the Project113 directory presentation.
        ld      a,(ix+11)
        cp      0Fh
        jr      z,p130_hdd_fat_skip_entry
        bit     3,a
        jr      nz,p130_hdd_fat_skip_entry
        ld      a,(ix+0)
        cp      '.'
        jr      z,p130_hdd_fat_skip_entry

        ld      a,(ix+11)
        ld      (p130_hdd_fat_entry_attr),a
        call    p130_hdd_fat_emit_entry

        ld      hl,(_p130_hdd_fat_file_count)
        inc     hl
        ld      (_p130_hdd_fat_file_count),hl

p130_hdd_fat_skip_entry:
        ; Consume one BPB root entry and advance by its 32-byte record size.
        ld      hl,(p130_hdd_fat_entries_left)
        dec     hl
        ld      (p130_hdd_fat_entries_left),hl

        push    de
        ld      de,32
        push    ix
        pop     hl
        add     hl,de
        push    hl
        pop     ix
        pop     de

        ld      a,(p130_hdd_fat_slots_left)
        dec     a
        ld      (p130_hdd_fat_slots_left),a
        jr      nz,p130_hdd_fat_entry_loop

        ; Advance the absolute root LBA and read the next sector.
        ld      hl,(p130_hdd_fat_root_lba)
        inc     hl
        ld      (p130_hdd_fat_root_lba),hl
        ld      a,h
        or      l
        jr      nz,p130_hdd_fat_no_lba_carry
        ld      hl,(p130_hdd_fat_root_lba+2)
        inc     hl
        ld      (p130_hdd_fat_root_lba+2),hl
p130_hdd_fat_no_lba_carry:
        ld      hl,(p130_hdd_fat_sectors_left)
        dec     hl
        ld      (p130_hdd_fat_sectors_left),hl
        jp      p130_hdd_fat_sector_loop

p130_hdd_fat_bad_bpb:
        ld      a,6
        ld      (p130_hdd_fat_error),a
        jp      p130_hdd_fat_finish

p130_hdd_fat_read_failed:
        ld      a,(_p130_hdd_error)
        ld      (p130_hdd_fat_error),a
        jp      p130_hdd_fat_finish

p130_hdd_fat_complete:
        ld      hl,p130_hdd_fat_msg_done
        call    p130_hdd_puts
        ld      hl,p130_hdd_fat_msg_count
        call    p130_hdd_puts
        ld      a,(_p130_hdd_fat_file_count+1)
        call    p130_hdd_put_hex8
        ld      a,(_p130_hdd_fat_file_count)
        call    p130_hdd_put_hex8
        ld      a,13
        call    p130_hdd_put_char
        ld      a,10
        call    p130_hdd_put_char
        jp      p130_hdd_fat_finish

p130_hdd_fat_finish:
        ld      a,(p130_hdd_fat_error)
        or      a
        jr      z,p130_hdd_fat_restore
        ld      hl,p130_hdd_fat_msg_error
        call    p130_hdd_puts
        ld      a,(p130_hdd_fat_error)
        call    p130_hdd_put_hex8
        ld      a,13
        call    p130_hdd_put_char
        ld      a,10
        call    p130_hdd_put_char

p130_hdd_fat_restore:
        pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ld      a,(p130_hdd_fat_error)
        or      a
        ret     z
        scf
        ret

; Format and emit one 8.3 entry. IX points to the 32-byte FAT entry.
; The output line is mirrored through p130_hdd_put_char/p130_hdd_puts to #EF.
p130_hdd_fat_emit_entry:
        push    af
        push    bc
        push    de
        push    hl
        push    ix

        push    ix
        pop     hl
        ld      (p130_hdd_fat_entry_ptr),hl

        ; Copy the base name until its first padding space.
        ld      de,p130_hdd_fat_name
        xor     a
        ld      (p130_hdd_fat_name_len),a
        ld      b,8
p130_hdd_fat_name_base_loop:
        ld      a,(hl)
        inc     hl
        cp      ' '
        jr      z,p130_hdd_fat_name_base_done
        ld      (de),a
        inc     de
        ld      a,(p130_hdd_fat_name_len)
        inc     a
        ld      (p130_hdd_fat_name_len),a
        djnz    p130_hdd_fat_name_base_loop
p130_hdd_fat_name_base_done:
        ld      a,(p130_hdd_fat_name_len)
        or      a
        jp      z,p130_hdd_fat_emit_done

        ; Copy non-space extension bytes to a temporary 3-byte buffer.
        ld      hl,(p130_hdd_fat_entry_ptr)
        ld      de,8
        add     hl,de
        ld      de,p130_hdd_fat_ext
        ld      b,3
        xor     a
        ld      (p130_hdd_fat_ext_len),a
p130_hdd_fat_name_ext_loop:
        ld      a,(hl)
        inc     hl
        cp      ' '
        jr      z,p130_hdd_fat_name_ext_next
        ld      (de),a
        inc     de
        ld      a,(p130_hdd_fat_ext_len)
        inc     a
        ld      (p130_hdd_fat_ext_len),a
p130_hdd_fat_name_ext_next:
        djnz    p130_hdd_fat_name_ext_loop

        ; Append .EXT only when an extension exists.
        ld      a,(p130_hdd_fat_ext_len)
        or      a
        jr      z,p130_hdd_fat_name_terminate
        ld      hl,p130_hdd_fat_name
        ld      a,(p130_hdd_fat_name_len)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (hl),'.'
        inc     hl
        ld      de,p130_hdd_fat_ext
        ld      a,(p130_hdd_fat_ext_len)
        ld      b,a
p130_hdd_fat_name_ext_copy:
        ld      a,(de)
        inc     de
        ld      (hl),a
        inc     hl
        djnz    p130_hdd_fat_name_ext_copy
        jr      p130_hdd_fat_name_terminate_at_hl

p130_hdd_fat_name_terminate:
        ld      hl,p130_hdd_fat_name
        ld      a,(p130_hdd_fat_name_len)
        ld      e,a
        ld      d,0
        add     hl,de
p130_hdd_fat_name_terminate_at_hl:
        ld      (hl),0

        ld      hl,p130_hdd_fat_msg_file
        call    p130_hdd_puts
        ld      hl,p130_hdd_fat_name
        call    p130_hdd_puts
        ld      a,(p130_hdd_fat_entry_attr)
        bit     4,a
        jr      z,p130_hdd_fat_emit_newline
        ld      hl,p130_hdd_fat_msg_dir
        call    p130_hdd_puts
p130_hdd_fat_emit_newline:
        ld      a,13
        call    p130_hdd_put_char
        ld      a,10
        call    p130_hdd_put_char

p130_hdd_fat_emit_done:
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret


; Local output bridge: A=character. The C diagnostic API mirrors #EF to the ATM UI.
p130_hdd_put_char:
        push    af
        push    bc
        push    de
        push    hl
        ld      l,a
        call    _p130_debug_putc
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; HL -> zero-terminated string.
p130_hdd_puts:
        ld      a,(hl)
        or      a
        ret     z
        call    p130_hdd_put_char
        inc     hl
        jr      p130_hdd_puts

; A -> two uppercase hexadecimal digits.
p130_hdd_put_hex8:
        push    af
        rrca
        rrca
        rrca
        rrca
        and     0Fh
        call    p130_hdd_hex_digit
        pop     af
        and     0Fh
p130_hdd_hex_digit:
        cp      10
        jr      c,p130_hdd_hex_num
        add     a,'A'-10
        jr      p130_hdd_hex_emit
p130_hdd_hex_num:
        add     a,'0'
p130_hdd_hex_emit:
        jp      p130_hdd_put_char

p130_hdd_fat_msg_begin: db "[HDD] FAT16 ROOT DIRECTORY",13,10,0
p130_hdd_fat_msg_root:  db "[HDD] ROOT SCAN BEGIN",13,10,0
p130_hdd_fat_msg_file:  db "[HDD] ",0
p130_hdd_fat_msg_dir:   db " <DIR>",0
p130_hdd_fat_msg_done:  db "[HDD] DIRECTORY READ OK",13,10,0
p130_hdd_fat_msg_count: db "[HDD] FILE COUNT=",0
p130_hdd_fat_msg_error: db "[HDD] FAT16 ERROR=",0

p130_hdd_fat_error:        db 0
p130_hdd_fat_fat_count:    db 0
p130_hdd_fat_slots_left:   db 0
p130_hdd_fat_entry_attr:   db 0
p130_hdd_fat_name_len:     db 0
p130_hdd_fat_ext_len:      db 0
p130_hdd_fat_root_lba:     db 0,0,0,0
p130_hdd_fat_sectors_left: dw 0
p130_hdd_fat_entries_left: dw 0
_p130_hdd_fat_file_count:  dw 0
p130_hdd_fat_entry_ptr:    dw 0
p130_hdd_fat_name:         ds 13,0
p130_hdd_fat_ext:          ds 3,0
