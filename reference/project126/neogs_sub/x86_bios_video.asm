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
        ; Match Project125 diagnostics: trace the INT10 register image before
        ; dispatch, bounded so a verbose BIOS cannot flood the #EF log.
        call    bios_video_trace_int10
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
        cp      #06
        jp      z,bios_int10_scroll_up
        cp      #07
        jp      z,bios_int10_scroll_down
        cp      #0E
        jp      z,bios_int10_teletype
        or      a
        ret

; AH=00h, AL=03h.
bios_int10_set_mode:
        ld      a,l
        cp      BIOS_VIDEO_MODE
        jr      z,.supported_mode
        ; Project125 treats unsupported mode requests as successful no-ops;
        ; never leak CP's carry flag into the x86 execution fault path.
        or      a
        ret
.supported_mode:
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
        ld      a,d
        ld      (bios_video_vga_data),a
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
        ld      a,P126_NGS_X86VGA_MODULE_ID
        ld      ix,x86_vga_io_write8_impl
        jp      p126_overlay_call_module

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

; INT 10h AH=06h/07h — Project125 text-window scrolling.
; AL=lines (0=clear), BH=fill attribute, CH/CL=top-left, DH/DL=bottom-right.
bios_int10_scroll_up:
        xor     a
        ld      (bios_scroll_direction),a
        jr      bios_int10_scroll_common
bios_int10_scroll_down:
        ld      a,1
        ld      (bios_scroll_direction),a
bios_int10_scroll_common:
        ld      a,(x86_reg_cx+1)
        cp      BIOS_VIDEO_ROWS
        ret     nc
        ld      (bios_scroll_top),a
        ld      a,(x86_reg_cx)
        cp      BIOS_VIDEO_COLUMNS
        ret     nc
        ld      (bios_scroll_left),a
        ld      a,(x86_reg_dx+1)
        cp      BIOS_VIDEO_ROWS
        ret     nc
        ld      (bios_scroll_bottom),a
        ld      a,(x86_reg_dx)
        cp      BIOS_VIDEO_COLUMNS
        ret     nc
        ld      (bios_scroll_right),a
        ld      a,(bios_scroll_top)
        ld      b,a
        ld      a,(bios_scroll_bottom)
        cp      b
        ret     c
        ld      a,(bios_scroll_left)
        ld      b,a
        ld      a,(bios_scroll_right)
        cp      b
        ret     c
        ld      a,(x86_reg_ax)
        ld      (bios_scroll_lines),a
        ld      a,(x86_reg_bx+1)
        ld      (bios_scroll_attr),a
        ld      a,(bios_scroll_bottom)
        ld      b,a
        ld      a,(bios_scroll_top)
        ld      c,a
        ld      a,b
        sub     c
        inc     a
        ld      (bios_scroll_height),a
        ld      a,(bios_scroll_lines)
        or      a
        jp      z,.clear_all
        ld      b,a
        ld      a,(bios_scroll_height)
        cp      b
        jr      nc,.count_valid
        ld      a,b
        ld      (bios_scroll_lines),a
        jp      .clear_all
.count_valid:
        ld      a,(bios_scroll_lines)
        ld      (bios_scroll_remaining),a
        ld      a,(bios_scroll_direction)
        or      a
        jr      nz,.down_start
        ld      a,(bios_scroll_top)
        ld      (bios_scroll_row),a
.up_copy:
        ld      a,(bios_scroll_bottom)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        ld      c,a
        ld      a,b
        sub     c
        ld      b,a
        ld      a,(bios_scroll_row)
        cp      b
        jr      c,.up_copy_row
        jr      z,.up_copy_row
        jr      .up_clear_start
.up_copy_row:
        ld      a,(bios_scroll_row)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        add     a,b
        ld      (bios_scroll_source_row),a
        call    bios_scroll_copy_row
        ld      a,(bios_scroll_row)
        inc     a
        ld      (bios_scroll_row),a
        jr      .up_copy
.up_clear_start:
        ld      a,(bios_scroll_bottom)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        ld      c,a
        ld      a,b
        sub     c
        inc     a
        ld      (bios_scroll_row),a
        ld      a,(bios_scroll_bottom)
        ld      (bios_scroll_clear_limit),a
        jr      .clear_rows
.down_start:
        ld      a,(bios_scroll_bottom)
        ld      (bios_scroll_row),a
.down_copy:
        ld      a,(bios_scroll_top)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        add     a,b
        ld      b,a
        ld      a,(bios_scroll_row)
        cp      b
        jr      nc,.down_copy_row
        jr      .down_clear_start
.down_copy_row:
        ld      a,(bios_scroll_row)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        ld      c,a
        ld      a,b
        sub     c
        ld      (bios_scroll_source_row),a
        call    bios_scroll_copy_row
        ld      a,(bios_scroll_row)
        dec     a
        ld      (bios_scroll_row),a
        jr      .down_copy
.down_clear_start:
        ld      a,(bios_scroll_top)
        ld      b,a
        ld      a,(bios_scroll_remaining)
        add     a,b
        dec     a
        ld      (bios_scroll_clear_limit),a
        ld      a,(bios_scroll_top)
        ld      (bios_scroll_row),a
        jr      .clear_rows
.clear_all:
        ld      a,(bios_scroll_bottom)
        ld      (bios_scroll_clear_limit),a
        ld      a,(bios_scroll_top)
        ld      (bios_scroll_row),a
.clear_rows:
        ld      a,(bios_scroll_row)
        ld      b,a
        ld      a,(bios_scroll_clear_limit)
        cp      b
        jr      c,.scroll_done
        call    bios_scroll_clear_row
        ld      a,(bios_scroll_row)
        inc     a
        ld      (bios_scroll_row),a
        jr      .clear_rows
.scroll_done:
        or      a
        ret

; Copy source row to destination row, preserving character and attribute.
bios_scroll_copy_row:
        ld      a,(bios_scroll_left)
        ld      (bios_scroll_col),a
.copy_cell:
        ld      a,(bios_scroll_source_row)
        ld      b,a
        ld      a,(bios_scroll_col)
        ld      c,a
        call    bios_video_calc_cell_offset
        call    bios_video_read_offset
        ret     c
        ld      (bios_scroll_char),a
        ld      hl,(bios_scroll_guest_offset)
        inc     hl
        call    bios_video_read_offset
        ret     c
        ld      (bios_scroll_cell_attr),a
        ld      a,(bios_scroll_row)
        ld      b,a
        ld      a,(bios_scroll_col)
        ld      c,a
        call    bios_video_calc_cell_offset
        ld      a,(bios_scroll_char)
        call    bios_video_write_offset
        ret     c
        ld      hl,(bios_scroll_guest_offset)
        inc     hl
        ld      a,(bios_scroll_cell_attr)
        call    bios_video_write_offset
        ret     c
        ld      a,(bios_scroll_col)
        ld      b,a
        ld      a,(bios_scroll_right)
        cp      b
        ret     z
        inc     b
        ld      a,b
        ld      (bios_scroll_col),a
        jr      .copy_cell

bios_scroll_clear_row:
        ld      a,(bios_scroll_left)
        ld      (bios_scroll_col),a
.clear_cell:
        ld      a,(bios_scroll_row)
        ld      b,a
        ld      a,(bios_scroll_col)
        ld      c,a
        call    bios_video_calc_cell_offset
        ld      a,32
        call    bios_video_write_offset
        ret     c
        ld      hl,(bios_scroll_guest_offset)
        inc     hl
        ld      a,(bios_scroll_attr)
        call    bios_video_write_offset
        ret     c
        ld      a,(bios_scroll_col)
        ld      b,a
        ld      a,(bios_scroll_right)
        cp      b
        ret     z
        inc     b
        ld      a,b
        ld      (bios_scroll_col),a
        jr      .clear_cell

; IN B=row, C=column. OUT HL=byte offset within B800 text aperture.
bios_video_calc_cell_offset:
        ld      hl,0
        ld      de,160
        ld      a,b
        or      a
        jr      z,.row_done
        ld      b,a
.row_loop:
        add     hl,de
        djnz    .row_loop
.row_done:
        ld      a,c
        add     a,a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (bios_scroll_guest_offset),hl
        ret

bios_video_read_offset:
        ld      (bios_scroll_guest_offset),hl
        ld      hl,#B800
        ld      de,(bios_scroll_guest_offset)
        call    x86_cpu_calc_phys
        jp      x86_guest_mem_read8

bios_video_write_offset:
        ld      (bios_scroll_guest_offset),hl
        ld      (bios_video_guest_value),a
        ld      hl,#B800
        ld      de,(bios_scroll_guest_offset)
        call    x86_cpu_calc_phys
        ld      a,(bios_video_guest_value)
        jp      x86_guest_mem_write8

bios_scroll_top:          db 0
bios_scroll_bottom:       db 0
bios_scroll_clear_limit:  db 0
bios_scroll_left:         db 0
bios_scroll_right:        db 0
bios_scroll_lines:        db 0
bios_scroll_remaining:   db 0
bios_scroll_height:       db 0
bios_scroll_direction:    db 0
bios_scroll_row:          db 0
bios_scroll_source_row:   db 0
bios_scroll_col:          db 0
bios_scroll_attr:         db BIOS_VIDEO_ATTR
bios_scroll_char:         db 0
bios_scroll_cell_attr:    db 0
bios_scroll_guest_offset: dw 0

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

; Bounded Project125-style INT10 trace on NeoGS debug port #EF.
bios_video_trace_int10:
        ld      a,(bios_video_trace_count)
        cp      48
        ret     nc
        inc     a
        ld      (bios_video_trace_count),a
        push    af
        push    bc
        push    de
        push    hl
        ld      hl,bios_video_trace_prefix
        call    bios_video_trace_string
        ld      hl,(x86_reg_ax)
        call    bios_video_trace_hex16
        ld      a,' '
        out     (#EF),a
        ld      hl,(x86_reg_bx)
        call    bios_video_trace_hex16
        ld      a,' '
        out     (#EF),a
        ld      hl,(x86_reg_cx)
        call    bios_video_trace_hex16
        ld      a,' '
        out     (#EF),a
        ld      hl,(x86_reg_dx)
        call    bios_video_trace_hex16
        ld      a,' '
        out     (#EF),a
        ld      hl,(x86_reg_cs)
        call    bios_video_trace_hex16
        ld      a,':'
        out     (#EF),a
        ld      hl,(x86_reg_ip)
        call    bios_video_trace_hex16
        ld      a,13
        out     (#EF),a
        ld      a,10
        out     (#EF),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

bios_video_trace_string:
        ld      a,(hl)
        inc     hl
        or      a
        ret     z
        out     (#EF),a
        jr      bios_video_trace_string

bios_video_trace_hex16:
        ld      a,h
        call    bios_video_trace_hex8
        ld      a,l
        jp      bios_video_trace_hex8

bios_video_trace_hex8:
        push    af
        push    bc
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        call    bios_video_trace_nibble
        ld      a,b
        and     #0F
        call    bios_video_trace_nibble
        pop     bc
        pop     af
        ret

bios_video_trace_nibble:
        and     #0F
        add     a,'0'
        cp      '9'+1
        jr      c,.emit
        add     a,7
.emit:
        out     (#EF),a
        ret

bios_video_trace_prefix:
        db "[BIOS INT10] AX BX CX DX CS:IP=",0
bios_video_trace_count: db 0

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
