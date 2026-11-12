; =========================================================================
; PROJECT130 — Project125-compatible BIOS INT 10h text services
; X86VID overlay ID06/page09. 80x25 VGA text mode 03h, B800:0000.
; Guest memory uses the Project126 20-bit mapper; VGA uses the X86VGA gate.
; Interrupt frame and IRET are handled by X86EXEC.
; =========================================================================
BIOS_VIDEO_COLUMNS EQU 80
BIOS_VIDEO_ROWS    EQU 25
BIOS_VIDEO_MODE    EQU #03
BIOS_VIDEO_ATTR    EQU #07

bios_int10_dispatch_impl:
        ld      hl,(x86_reg_ax)
        ld      a,h
        cp      #00
        jp      z,bios_int10_set_mode
        cp      #0F
        jp      z,bios_int10_get_mode
        cp      #02
        jp      z,bios_int10_set_cursor
        cp      #03
        jp      z,bios_int10_get_cursor
        cp      #0E
        jp      z,bios_int10_teletype
        or      a
        ret

; AH=00h, AL=03h.
bios_int10_set_mode:
        ld      a,l
        cp      BIOS_VIDEO_MODE
        ret     nz
        call    bios_video_set_vga_text_state
        ret     c
        ld      hl,#0449
        ld      a,BIOS_VIDEO_MODE
        call    bios_video_write_bda
        ret     c
        ld      hl,#044A
        ld      a,BIOS_VIDEO_COLUMNS
        call    bios_video_write_bda
        ret     c
        ld      hl,#044C
        xor     a
        call    bios_video_write_bda
        ret     c
        ld      hl,#044D
        ld      a,#10
        call    bios_video_write_bda
        ret     c
        ld      hl,#0462
        xor     a
        call    bios_video_write_bda
        ret     c
        ld      hl,#0484
        ld      a,BIOS_VIDEO_ROWS-1
        call    bios_video_write_bda
        ret     c
        ld      hl,#0485
        ld      a,16
        call    bios_video_write_bda
        ret     c
        xor     a
        ld      (bios_video_row),a
        ld      (bios_video_col),a
        ld      hl,#0450
        ld      de,0
        call    bios_video_write_bda_word
        ret     c
        call    bios_video_clear_page
        or      a
        ret

; Mode 03 VGA register setup through the software X86VGA I/O gate.
bios_video_set_vga_text_state:
        ld      hl,#03C4
        ld      a,2
        ld      d,3
        call    bios_video_vga_index_data
        ret     c
        ld      hl,#03C4
        ld      a,4
        ld      d,2
        call    bios_video_vga_index_data
        ret     c
        ld      hl,#03CE
        ld      a,4
        ld      d,0
        call    bios_video_vga_index_data
        ret     c
        ld      hl,#03CE
        ld      a,5
        ld      d,#10
        call    bios_video_vga_index_data
        ret     c
        ld      hl,#03CE
        ld      a,6
        ld      d,#0E
        call    bios_video_vga_index_data
        ret     c
        ld      hl,#03CE
        ld      a,8
        ld      d,#FF
        call    bios_video_vga_index_data
        ret

bios_video_vga_index_data:
        ld      (bios_video_vga_data),d
        ld      (bios_video_vga_port),hl
        call    bios_video_vga_write
        ret     c
        ld      hl,(bios_video_vga_port)
        inc     hl
        ld      a,(bios_video_vga_data)
        jp      bios_video_vga_write

bios_video_vga_write:
        ld      (bios_video_vga_port),hl
        ld      (bios_video_vga_value),a
        ld      hl,(bios_video_vga_port)
        ld      a,(bios_video_vga_value)
        jp      x86_vga_io_write8

bios_video_clear_page:
        xor     a
        ld      (bios_video_row),a
.clear_row:
        xor     a
        ld      (bios_video_col),a
.clear_cell:
        ld      a,32
        ld      (bios_video_char),a
        ld      a,BIOS_VIDEO_ATTR
        ld      (bios_video_attr),a
        call    bios_video_write_cell
        ret     c
        ld      a,(bios_video_col)
        inc     a
        ld      (bios_video_col),a
        cp      BIOS_VIDEO_COLUMNS
        jr      c,.clear_cell
        ld      a,(bios_video_row)
        inc     a
        ld      (bios_video_row),a
        cp      BIOS_VIDEO_ROWS
        jr      c,.clear_row
        xor     a
        ld      (bios_video_row),a
        ld      (bios_video_col),a
        ret

; AH=0Fh — AL=mode, AH=columns, BH=active page.
bios_int10_get_mode:
        ld      hl,#5003
        ld      (x86_reg_ax),hl
        xor     a
        ld      (x86_reg_bx+1),a
        or      a
        ret

; AH=02h — set cursor, BH=page, DH=row, DL=column.
bios_int10_set_cursor:
        ld      a,(x86_reg_bx+1)
        or      a
        ret     nz
        ld      hl,(x86_reg_dx)
        ld      a,h
        cp      BIOS_VIDEO_ROWS
        ret     nc
        ld      a,l
        cp      BIOS_VIDEO_COLUMNS
        ret     nc
        ld      a,h
        ld      (bios_video_row),a
        ld      a,l
        ld      (bios_video_col),a
        jp      bios_video_store_cursor

; AH=03h — get cursor from BDA.
bios_int10_get_cursor:
        ld      a,(x86_reg_bx+1)
        or      a
        ret     nz
        ld      hl,#0450
        call    bios_video_read_bda_word
        ret     c
        ld      (x86_reg_dx),hl
        or      a
        ret

; AH=0Eh — BIOS teletype output, AL=character, BH=page 0.
bios_int10_teletype:
        ld      a,(x86_reg_bx+1)
        or      a
        ret     nz
        ld      a,(x86_reg_ax)
        ld      (bios_video_char),a
        or      a
        ret     z
        cp      13
        jr      z,.cr
        cp      10
        jr      z,.lf
        cp      8
        jr      z,.bs
        cp      7
        jr      z,.done
        cp      32
        jr      c,.done
        ld      a,BIOS_VIDEO_ATTR
        ld      (bios_video_attr),a
        call    bios_video_write_cell
        ret     c
        ld      a,(bios_video_col)
        inc     a
        ld      (bios_video_col),a
        cp      BIOS_VIDEO_COLUMNS
        jr      c,.store
        xor     a
        ld      (bios_video_col),a
        jr      .lf
.cr:
        xor     a
        ld      (bios_video_col),a
        jr      .store
.bs:
        ld      a,(bios_video_col)
        or      a
        jr      z,.done
        dec     a
        ld      (bios_video_col),a
        ld      a,32
        ld      (bios_video_char),a
        ld      a,BIOS_VIDEO_ATTR
        ld      (bios_video_attr),a
        call    bios_video_write_cell
        ret     c
        jr      .store
.lf:
        ld      a,(bios_video_row)
        inc     a
        cp      BIOS_VIDEO_ROWS
        jr      c,.row_ok
        ld      a,BIOS_VIDEO_ROWS-1
.row_ok:
        ld      (bios_video_row),a
.store:
        call    bios_video_store_cursor
        ret
.done:
        or      a
        ret

; Character/attribute pair at B8000h + row*160 + column*2.
bios_video_write_cell:
        push    bc
        push    de
        push    hl
        ld      hl,0
        ld      de,160
        ld      a,(bios_video_row)
        ld      b,a
        ld      a,b
        or      a
        jr      z,.row_product_done
.row_product:
        add     hl,de
        djnz    .row_product
.row_product_done:
        ld      a,(bios_video_col)
        add     a,a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (bios_video_guest_offset),hl
        ld      a,(bios_video_char)
        ld      (bios_video_guest_value),a
        call    bios_video_write_guest_byte
        jr      c,.write_done
        ld      hl,(bios_video_guest_offset)
        inc     hl
        ld      (bios_video_guest_offset),hl
        ld      a,(bios_video_attr)
        ld      (bios_video_guest_value),a
        call    bios_video_write_guest_byte
.write_done:
        pop     hl
        pop     de
        pop     bc
        ret

bios_video_write_guest_byte:
        ld      hl,#B800
        ld      de,(bios_video_guest_offset)
        call    x86_cpu_calc_phys
        ld      a,(bios_video_guest_value)
        jp      x86_guest_mem_write8

bios_video_write_bda:
        ld      (bios_video_guest_value),a
        ld      (bios_video_guest_offset),hl
        ld      hl,0
        ld      de,(bios_video_guest_offset)
        call    x86_cpu_calc_phys
        ld      a,(bios_video_guest_value)
        jp      x86_guest_mem_write8

bios_video_write_bda_word:
        ld      (bios_video_bda_word),de
        ld      a,e
        call    bios_video_write_bda
        ret     c
        ld      hl,(bios_video_guest_offset)
        inc     hl
        ld      a,(bios_video_bda_word+1)
        jp      bios_video_write_bda

bios_video_read_bda_word:
        ld      (bios_video_guest_offset),hl
        ld      hl,0
        ld      de,(bios_video_guest_offset)
        call    x86_cpu_calc_phys
        call    x86_guest_mem_read8
        ret     c
        ld      (bios_video_bda_word),a
        ld      hl,(bios_video_guest_offset)
        inc     hl
        ld      d,h
        ld      e,l
        ld      hl,0
        call    x86_cpu_calc_phys
        call    x86_guest_mem_read8
        ret     c
        ld      h,a
        ld      a,(bios_video_bda_word)
        ld      l,a
        or      a
        ret

bios_video_store_cursor:
        ld      hl,#0450
        ld      a,(bios_video_col)
        ld      e,a
        ld      a,(bios_video_row)
        ld      d,a
        jp      bios_video_write_bda_word

bios_video_row:           db 0
bios_video_col:           db 0
bios_video_char:          db 0
bios_video_attr:          db BIOS_VIDEO_ATTR
bios_video_guest_offset:  dw 0
bios_video_guest_value:   db 0
bios_video_bda_word:      dw 0
bios_video_vga_data:      db 0
bios_video_vga_port:      dw 0
bios_video_vga_value:     db 0
