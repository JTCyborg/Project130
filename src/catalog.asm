; Project130 ATM-host TR-DOS file selector.
; Ported from Project126's proven catalogue navigation rules.
; Directory buffer: #C800, 128 x 16-byte TR-DOS descriptors.
; No disk writes, blocking key-release waits, or unbounded I/O.

SECTION CODE
EXTERN _p130_trdos_result
PUBLIC _p130_catalog_init
PUBLIC _p130_catalog_poll
PUBLIC _p130_catalog_load_request
PUBLIC _p130_catalog_selected_index
PUBLIC _p130_catalog_selected_entry

_p130_catalog_init:
        xor     a
        ld      (p130_cat_enabled),a
        ld      (p130_cat_selected),a
        ld      (p130_cat_scroll),a
        ld      (p130_cat_total),a
        ld      (p130_cat_key_latched),a
        ld      (_p130_catalog_load_request),a
        ld      (_p130_catalog_selected_index),a
        ld      (_p130_catalog_selected_entry),a
        ld      (_p130_catalog_selected_entry+1),a

        ld      a,(_p130_trdos_result)
        or      a
        jr      nz,p130_cat_init_empty
        call    p130_cat_count_files
        ld      a,(p130_cat_total)
        or      a
        jr      nz,p130_cat_init_ready
        ld      hl,p130_cat_no_files
        ld      a,2
        ld      c,1
        call    0A009h
        ret
p130_cat_init_ready:
        ld      a,1
        ld      (p130_cat_enabled),a
        call    p130_cat_draw
        ret

p130_cat_init_empty:
        ld      hl,p130_cat_no_files
        ld      a,2
        ld      c,1
        call    0A009h
        ret

; One key transition per poll. Holding a key cannot repeat the action and
; the scan never waits indefinitely for key release.
_p130_catalog_poll:
        ld      a,(p130_cat_enabled)
        or      a
        ret     z
        call    p130_cat_scan_keys
        or      a
        jr      nz,p130_cat_key_down
        xor     a
        ld      (p130_cat_key_latched),a
        ret
p130_cat_key_down:
        ld      b,a
        ld      a,(p130_cat_key_latched)
        or      a
        ret     nz
        ld      a,1
        ld      (p130_cat_key_latched),a
        ld      a,b
        bit     4,a
        jp      nz,p130_cat_confirm
        bit     2,a
        jp      nz,p130_cat_page_up
        bit     3,a
        jp      nz,p130_cat_page_down
        bit     0,a
        jp      nz,p130_cat_move_up
        bit     1,a
        jp      nz,p130_cat_move_down
        ret

; P126 mapping: CAPS+7/6 = up/down, CAPS+5/8 = page up/down.
; ENTER is accepted without CAPS SHIFT. Result bits: 0..4.
p130_cat_scan_keys:
        push    bc
        push    hl
        xor     a
        ld      (p130_cat_scan_result),a
        ld      bc,0BFFEh
        in      a,(c)
        bit     0,a
        jr      nz,p130_cat_scan_caps
        ld      a,16
        ld      (p130_cat_scan_result),a
p130_cat_scan_caps:
        ld      bc,0FEFEh
        in      a,(c)
        bit     0,a
        jr      nz,p130_cat_scan_done
        ld      bc,0EFFEh
        in      a,(c)
        bit     3,a
        jr      nz,p130_cat_scan_down
        ld      a,(p130_cat_scan_result)
        or      1
        ld      (p130_cat_scan_result),a
p130_cat_scan_down:
        ld      bc,0EFFEh
        in      a,(c)
        bit     4,a
        jr      nz,p130_cat_scan_page_up
        ld      a,(p130_cat_scan_result)
        or      2
        ld      (p130_cat_scan_result),a
p130_cat_scan_page_up:
        ld      bc,0F7FEh
        in      a,(c)
        bit     4,a
        jr      nz,p130_cat_scan_page_down
        ld      a,(p130_cat_scan_result)
        or      4
        ld      (p130_cat_scan_result),a
p130_cat_scan_page_down:
        ld      bc,0EFFEh
        in      a,(c)
        bit     2,a
        jr      nz,p130_cat_scan_done
        ld      a,(p130_cat_scan_result)
        or      8
        ld      (p130_cat_scan_result),a
p130_cat_scan_done:
        ld      a,(p130_cat_scan_result)
        pop     hl
        pop     bc
        ret

p130_cat_move_up:
        ld      a,(p130_cat_selected)
        or      a
        ret     z
        dec     a
        ld      (p130_cat_selected),a
        ld      b,a
        ld      a,(p130_cat_scroll)
        cp      b
        jp      c,p130_cat_redraw
        jp      z,p130_cat_redraw
        dec     a
        ld      (p130_cat_scroll),a
        jp      p130_cat_redraw

p130_cat_move_down:
        ld      a,(p130_cat_selected)
        inc     a
        ld      b,a
        ld      a,(p130_cat_total)
        cp      b
        ret     c
        ret     z
        ld      a,b
        ld      (p130_cat_selected),a
        ld      a,(p130_cat_scroll)
        add     a,8
        ld      b,a
        ld      a,(p130_cat_selected)
        cp      b
        jp      c,p130_cat_redraw
        jp      z,p130_cat_redraw
        ld      a,(p130_cat_scroll)
        inc     a
        ld      (p130_cat_scroll),a
        jp      p130_cat_redraw

p130_cat_page_up:
        ld      a,(p130_cat_selected)
        cp      9
        jr      nc,p130_cat_page_up_sub
        xor     a
        jr      p130_cat_page_up_store
p130_cat_page_up_sub:
        sub     9
p130_cat_page_up_store:
        ld      (p130_cat_selected),a
        ld      (p130_cat_scroll),a
        jp      p130_cat_redraw

p130_cat_page_down:
        ld      a,(p130_cat_total)
        or      a
        ret     z
        dec     a
        ld      b,a
        ld      a,(p130_cat_selected)
        add     a,9
        jr      c,p130_cat_page_down_clamp
        cp      b
        jr      c,p130_cat_page_down_store
        jr      z,p130_cat_page_down_store
p130_cat_page_down_clamp:
        ld      a,b
p130_cat_page_down_store:
        ld      (p130_cat_selected),a
        cp      8
        jr      nc,p130_cat_page_down_scroll
        xor     a
        jr      p130_cat_page_down_scroll_store
p130_cat_page_down_scroll:
        ld      a,(p130_cat_total)
        sub     9
        jr      nc,p130_cat_page_down_min_ok
        xor     a
p130_cat_page_down_min_ok:
        ld      b,a
        ld      a,(p130_cat_selected)
        cp      b
        jr      c,p130_cat_page_down_use_selected
        ld      a,b
        jr      p130_cat_page_down_scroll_store
p130_cat_page_down_use_selected:
        ld      a,(p130_cat_selected)
p130_cat_page_down_scroll_store:
        ld      (p130_cat_scroll),a
        jp      p130_cat_redraw

p130_cat_confirm:
        ld      a,(p130_cat_selected)
        call    p130_cat_find_index
        ret     c
        ld      (_p130_catalog_selected_entry),hl
        ld      a,(p130_cat_selected)
        ld      (_p130_catalog_selected_index),a
        ld      a,1
        ld      (_p130_catalog_load_request),a
        ld      hl,p130_cat_load_prefix
        call    p130_cat_debug_string
        ld      hl,(_p130_catalog_selected_entry)
        ld      b,8
p130_cat_confirm_name:
        ld      a,(hl)
        inc     hl
        push    bc
        push    hl
        ld      bc,00EFh
        out     (c),a
        pop     hl
        pop     bc
        djnz    p130_cat_confirm_name
        ld      a,'.'
        ld      bc,00EFh
        out     (c),a
        ld      hl,(_p130_catalog_selected_entry)
        ld      de,8
        add     hl,de
        ld      a,(hl)
        ld      bc,00EFh
        out     (c),a
        ld      hl,p130_cat_load_pending
        call    p130_cat_debug_string
        ld      hl,p130_cat_enter_status
        ld      a,11
        ld      c,1
        call    0A009h
        ret

p130_cat_debug_string:
        push    af
        push    bc
        ld      bc,00EFh
p130_cat_debug_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,p130_cat_debug_done
        out     (c),a
        jr      p130_cat_debug_loop
p130_cat_debug_done:
        pop     bc
        pop     af
        ret

p130_cat_redraw:
        call    p130_cat_draw
        ret

; Count valid 16-byte TR-DOS descriptors in the 2 KiB catalogue.
p130_cat_count_files:
        xor     a
        ld      (p130_cat_total),a
        ld      hl,0C800h
        ld      b,128
p130_cat_count_loop:
        call    p130_cat_entry_valid
        jr      c,p130_cat_count_next
        ld      a,(p130_cat_total)
        inc     a
        ld      (p130_cat_total),a
p130_cat_count_next:
        ld      de,16
        add     hl,de
        djnz    p130_cat_count_loop
        ret

; HL=descriptor. Valid file types: B, C, D, #.
p130_cat_entry_valid:
        ld      a,(hl)
        or      a
        jr      z,p130_cat_entry_invalid
        cp      1
        jr      z,p130_cat_entry_invalid
        push    hl
        ld      de,8
        add     hl,de
        ld      a,(hl)
        pop     hl
        cp      'B'
        jr      z,p130_cat_entry_valid_yes
        cp      'C'
        jr      z,p130_cat_entry_valid_yes
        cp      'D'
        jr      z,p130_cat_entry_valid_yes
        cp      '#'
        jr      z,p130_cat_entry_valid_yes
p130_cat_entry_invalid:
        scf
        ret
p130_cat_entry_valid_yes:
        or      a
        ret

; A=logical valid-file index. HL=descriptor on success.
p130_cat_find_index:
        ld      (p130_cat_target),a
        ld      hl,0C800h
        ld      b,128
        ld      c,0
p130_cat_find_loop:
        call    p130_cat_entry_valid
        jr      c,p130_cat_find_next
        ld      a,(p130_cat_target)
        cp      c
        jr      z,p130_cat_find_found
        inc     c
p130_cat_find_next:
        ld      de,16
        add     hl,de
        djnz    p130_cat_find_loop
        scf
        ret
p130_cat_find_found:
        or      a
        ret

; Nine rows, 12 columns: >NAME    .T
p130_cat_draw:
        push    af
        push    bc
        push    de
        push    hl
        xor     a
        ld      (p130_cat_row),a
p130_cat_draw_loop:
        ld      a,(p130_cat_scroll)
        ld      b,a
        ld      a,(p130_cat_row)
        add     a,b
        ld      (p130_cat_target),a
        ld      hl,p130_cat_line
        ld      b,12
        ld      a,' '
p130_cat_clear_line:
        ld      (hl),a
        inc     hl
        djnz    p130_cat_clear_line
        xor     a
        ld      (hl),a
        ld      a,'.'
        ld      (p130_cat_line+9),a

        ld      a,(p130_cat_target)
        ld      b,a
        ld      a,(p130_cat_total)
        cp      b
        jr      c,p130_cat_print_line
        jr      z,p130_cat_print_line
        ld      a,(p130_cat_target)
        call    p130_cat_find_index
        jr      c,p130_cat_print_line

        ld      a,(p130_cat_target)
        ld      b,a
        ld      a,(p130_cat_selected)
        cp      b
        ld      a,' '
        jr      nz,p130_cat_store_marker
        ld      a,'>'
p130_cat_store_marker:
        ld      (p130_cat_line),a
        ld      de,p130_cat_line+1
        ld      b,8
p130_cat_copy_name:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        djnz    p130_cat_copy_name
        ld      a,(hl)
        ld      (p130_cat_line+10),a

p130_cat_print_line:
        ld      hl,p130_cat_line
        ld      a,(p130_cat_row)
        add     a,2
        ld      c,1
        call    0A009h
        ld      a,(p130_cat_row)
        inc     a
        ld      (p130_cat_row),a
        cp      9
        jp      nz,p130_cat_draw_loop
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_cat_no_files: db "NO TR-DOS FILES",0
p130_cat_load_prefix: db "[TR-DOS] SELECTED: ",0
p130_cat_load_pending: db " (LOAD PENDING - NEO GS/DMA NOT READY)",13,10,0
p130_cat_enter_status: db "LOAD REQUEST RECORDED - WAITING FOR NEO GS/DMA",0
p130_cat_line: db "            ",0
p130_cat_enabled: db 0
p130_cat_selected: db 0
p130_cat_scroll: db 0
p130_cat_total: db 0
p130_cat_target: db 0
p130_cat_row: db 0
p130_cat_key_latched: db 0
p130_cat_scan_result: db 0

_p130_catalog_load_request: db 0
_p130_catalog_selected_index: db 0
_p130_catalog_selected_entry: dw 0
