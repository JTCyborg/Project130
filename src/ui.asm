; Project130 ATM-native host console.
; UI ABI is fixed at #A000 (init) and #A003 (putc). The module executes
; from ATM window 2 while window 1 is temporarily mapped to video RAM.
; Layout and physical text-plane addressing are ported from Project126.

        ORG     #A000
p130_ui_entry:
        jp      p130_ui_init_impl
        jp      p130_ui_putc_impl

P130_UI_COLUMNS EQU 80
P130_UI_ROWS    EQU 13
P130_UI_TOP     EQU 12
P130_VIDEO_PAGE7 EQU #78
P130_VIDEO_PAGE3 EQU #7C
P130_HOST_PAGE5  EQU #7A
P130_HOST_PAGE0  EQU #7F

p130_ui_init_impl:
        push    af
        push    bc
        push    de
        push    hl
        call    p130_atm_video_init
        call    p130_ui_clear
        call    p130_ui_draw
        xor     a
        ld      (p130_ui_row),a
        ld      (p130_ui_col),a
        ld      a,1
        ld      (p130_ui_ready),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; ATM shadow-port activation and RG=6 text-mode setup from Project126.
p130_atm_video_init:
        push    af
        push    bc
        push    de
        push    hl
        xor     a
        ld      bc,#EFF7
        out     (c),a
        ld      a,#18
        ld      bc,#7FFD
        out     (c),a
        ld      (#5C3B),a
        ld      bc,p130_shadow_ports_done
        push    bc
        ld      bc,#2A53
        push    bc
        ld      bc,#0177
        ld      a,#C3
        jp      #3D2F

p130_shadow_ports_done:
        ld      a,#BF
        ld      bc,#3FF7
        out     (c),a
        ld      a,P130_VIDEO_PAGE7
        ld      bc,#7FF7
        out     (c),a
        ld      a,P130_VIDEO_PAGE3
        ld      bc,#FFF7
        out     (c),a
        ld      hl,#FFEC
        ld      (hl),#01
        inc     hl
        ld      (hl),#77
        inc     hl
        ld      (hl),#01
        inc     hl
        ld      (hl),#ED
        inc     hl
        ld      (hl),#79
        inc     hl
        ld      (hl),#C3
        inc     hl
        ld      (hl),p130_video_mode_ready & #FF
        inc     hl
        ld      (hl),p130_video_mode_ready >> 8
        ld      a,#C6
        jp      #FFEC

p130_video_mode_ready:
        ld      a,P130_HOST_PAGE5
        ld      bc,#7FF7
        out     (c),a
        ld      a,P130_HOST_PAGE0
        ld      bc,#FFF7
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_ui_clear:
        push    af
        push    bc
        push    de
        push    hl
        call    p130_screen_map
        ld      hl,#41C0
        ld      de,#41C1
        ld      (hl),32
        ld      bc,#063F
        ldir
        ld      hl,#61C0
        ld      de,#61C1
        ld      (hl),32
        ld      bc,#063F
        ldir
        ld      hl,#E1C0
        ld      de,#E1C1
        ld      (hl),#44
        ld      bc,#063F
        ldir
        ld      hl,#C1C1
        ld      de,#C1C2
        ld      (hl),#44
        ld      bc,#063F
        ldir
        ; Header panel: rows 0..11, 12 * 64 bytes in both attribute planes.
        ld      hl,#E1C0
        ld      de,#E1C1
        ld      (hl),#4F
        ld      bc,#02FF
        ldir
        ld      hl,#C1C1
        ld      de,#C1C2
        ld      (hl),#4F
        ld      bc,#02FF
        ldir
        call    p130_screen_restore
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_ui_draw:
        push    af
        push    bc
        push    hl
        ld      hl,p130_ui_line0
        ld      a,0
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line2
        ld      a,2
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line3
        ld      a,3
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line4
        ld      a,4
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line5
        ld      a,5
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line6
        ld      a,6
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line7
        ld      a,7
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line9
        ld      a,9
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line10
        ld      a,10
        ld      c,1
        call    p130_ui_print_at
        ld      hl,p130_ui_line11
        ld      a,11
        ld      c,1
        call    p130_ui_print_at
        pop     hl
        pop     bc
        pop     af
        ret

; HL=zero-terminated text, A=row, C=column.
p130_ui_print_at:
        push    af
        push    bc
        push    de
        push    hl
        ld      (p130_ui_text_ptr),hl
        ld      (p130_ui_print_row),a
        ld      a,c
        ld      (p130_ui_print_col),a
.p130_print_loop:
        ld      hl,(p130_ui_text_ptr)
        ld      a,(hl)
        or      a
        jr      z,.p130_print_done
        inc     hl
        ld      (p130_ui_text_ptr),hl
        ld      (p130_ui_char),a
        ld      a,(p130_ui_print_row)
        ld      d,a
        ld      a,(p130_ui_print_col)
        ld      e,a
        ld      a,(p130_ui_char)
        call    p130_screen_write_char
        ld      a,(p130_ui_print_col)
        inc     a
        cp      P130_UI_COLUMNS
        jr      c,.p130_print_col_ok
        jr      .p130_print_done
.p130_print_col_ok:
        ld      (p130_ui_print_col),a
        jr      .p130_print_loop
.p130_print_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; A=character. Printable ASCII, CR/LF/BS. Called by ATM #EF logger.
p130_ui_putc_impl:
        push    af
        push    bc
        push    de
        push    hl
        ld      (p130_ui_char),a
        ld      a,(p130_ui_ready)
        or      a
        jr      z,.p130_putc_done
        ld      a,(p130_ui_char)
        cp      13
        jr      z,.p130_putc_cr
        cp      10
        jr      z,.p130_putc_lf
        cp      8
        jr      z,.p130_putc_bs
        cp      32
        jr      c,.p130_putc_done
        cp      128
        jr      c,.p130_putc_printable
        ld      a,'?'
.p130_putc_printable:
        ld      (p130_ui_char),a
        ld      a,(p130_ui_row)
        add     a,P130_UI_TOP
        ld      d,a
        ld      a,(p130_ui_col)
        ld      e,a
        ld      a,(p130_ui_char)
        call    p130_screen_write_char
        ld      a,(p130_ui_col)
        inc     a
        cp      P130_UI_COLUMNS
        jr      c,.p130_putc_store_col
        xor     a
        ld      (p130_ui_col),a
        call    p130_ui_newline
        jr      .p130_putc_done
.p130_putc_store_col:
        ld      (p130_ui_col),a
        jr      .p130_putc_done
.p130_putc_cr:
        xor     a
        ld      (p130_ui_col),a
        jr      .p130_putc_done
.p130_putc_lf:
        call    p130_ui_newline
        jr      .p130_putc_done
.p130_putc_bs:
        ld      a,(p130_ui_col)
        or      a
        jr      z,.p130_putc_done
        dec     a
        ld      (p130_ui_col),a
        ld      a,(p130_ui_row)
        add     a,P130_UI_TOP
        ld      d,a
        ld      a,(p130_ui_col)
        ld      e,a
        ld      a,32
        call    p130_screen_write_char
.p130_putc_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_ui_newline:
        ld      a,(p130_ui_row)
        inc     a
        cp      P130_UI_ROWS
        jr      c,.p130_newline_store
        call    p130_ui_scroll
        ld      a,P130_UI_ROWS-1
.p130_newline_store:
        ld      (p130_ui_row),a
        xor     a
        ld      (p130_ui_col),a
        ret

; IN A=char, D=absolute row, E=column. Preserves caller registers.
p130_screen_write_char:
        push    af
        push    bc
        push    de
        push    hl
        ld      (p130_ui_char),a
        ld      a,d
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,#01C0
        add     hl,de
        ld      a,e
        ld      c,a
        and     1
        ld      (p130_ui_parity),a
        ld      a,c
        srl     a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (p130_ui_offset),hl
        ld      a,d
        ; Re-read row for attribute selection (D was used as offset high byte).
        ld      a,(p130_ui_write_row)
        cp      P130_UI_TOP
        ld      a,#44
        jr      nc,.p130_attr_ready
        ld      a,#4F
.p130_attr_ready:
        ld      (p130_ui_attr),a
        call    p130_screen_map
        ld      hl,(p130_ui_offset)
        ld      a,(p130_ui_parity)
        or      a
        jr      nz,.p130_write_odd
        ld      de,#4000
        add     hl,de
        ld      a,(p130_ui_char)
        ld      (hl),a
        ld      hl,(p130_ui_offset)
        ld      de,#E000
        add     hl,de
        ld      a,(p130_ui_attr)
        ld      (hl),a
        jr      .p130_write_done
.p130_write_odd:
        ld      de,#6000
        add     hl,de
        ld      a,(p130_ui_char)
        ld      (hl),a
        ld      hl,(p130_ui_offset)
        ld      de,#C000
        add     hl,de
        inc     hl
        ld      a,(p130_ui_attr)
        ld      (hl),a
.p130_write_done:
        call    p130_screen_restore
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_screen_map:
        ld      a,P130_VIDEO_PAGE7
        ld      bc,#7FF7
        out     (c),a
        ld      a,P130_VIDEO_PAGE3
        ld      bc,#FFF7
        out     (c),a
        ret

p130_screen_restore:
        ld      a,P130_HOST_PAGE5
        ld      bc,#7FF7
        out     (c),a
        ld      a,P130_HOST_PAGE0
        ld      bc,#FFF7
        out     (c),a
        ret

p130_ui_scroll:
        push    af
        push    bc
        push    de
        push    hl
        call    p130_screen_map
        ld      hl,#4500
        ld      de,#44C0
        ld      bc,#0300
        ldir
        ld      hl,#6500
        ld      de,#64C0
        ld      bc,#0300
        ldir
        ld      hl,#E500
        ld      de,#E4C0
        ld      bc,#0300
        ldir
        ld      hl,#C501
        ld      de,#C4C1
        ld      bc,#0300
        ldir
        ld      hl,#47C0
        ld      de,#47C1
        ld      (hl),32
        ld      bc,#003F
        ldir
        ld      hl,#67C0
        ld      de,#67C1
        ld      (hl),32
        ld      bc,#003F
        ldir
        ld      hl,#E7C0
        ld      de,#E7C1
        ld      (hl),#44
        ld      bc,#003F
        ldir
        ld      hl,#C7C1
        ld      de,#C7C2
        ld      (hl),#44
        ld      bc,#003F
        ldir
        call    p130_screen_restore
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_ui_line0:  db "PROJECT130  |  ATM TURBO 2+  |  HOST CONSOLE",0
p130_ui_line2:  db "SYSTEM / HOST STATUS",0
p130_ui_line3:  db "HOST CPU      : Z80 / ATM TURBO 2+",0
p130_ui_line4:  db "GUEST CPU     : 8086 REAL MODE / NeoGS",0
p130_ui_line5:  db "BIOS          : GUEST ROM NOT LOADED",0
p130_ui_line6:  db "VIDEO         : ATM RG=6 TEXT 80x25",0
p130_ui_line7:  db "REAL TIME CLK : HOST RTC SERVICE PENDING",0
p130_ui_line9:  db "NEOGS / IPC",0
p130_ui_line10: db "DEBUG STREAM  : ATM #EF -> HOST LOG",0
p130_ui_line11: db "GUEST CLOCK   : VIRTUAL / HOST LOG: LIVE",0

p130_ui_ready:       db 0
p130_ui_row:         db 0
p130_ui_col:         db 0
p130_ui_char:        db 0
p130_ui_parity:      db 0
p130_ui_attr:        db 0
p130_ui_write_row:   db 0
p130_ui_offset:      dw 0
p130_ui_text_ptr:    dw 0
p130_ui_print_row:   db 0
p130_ui_print_col:   db 0

p130_ui_end:
        ASSERT  p130_ui_end <= #B000
