; =========================================================================
; PROJECT126 — VGA text to ATM-native frame converter
; Module ID06, dynamic overlay page09.
; VGA behavior is obtained only through the X86VGA public gate API.
; Initial ATM target: RG6 80x25 text, compact frame layout:
;   bytes 0000..07CF = 2000 character codes
;   bytes 07D0..0F9F = 2000 attribute bytes
; The current 4000-byte RG6 frame is written directly into page42h at payload offset 18, ready for reverse DMA. Pages40h..41h remain available for larger future frame formats.
; =========================================================================

x86_video_overlay_probe:
        ld      a,#56
        ld      hl,#A55A
        ret

; X86VGA is a separate dynamic overlay (module 05/page08).
; Capture is performed inside that overlay in one call, matching the
; Project125 bulk plane-gather contract while retaining the P126 frame ABI.
x86_video_vga_capture_text_frame:
        ld      a,P126_NGS_X86VGA_MODULE_ID
        ld      ix,x86_vga_capture_text_frame_gate_impl
        jp      p126_overlay_call_module

; Convert one complete 80x25 B800 text page.
; OUT: A=0, HL=frame byte count, CF=0.
x86_video_convert_impl:
        xor     a
        ld      (x86_video_frame_ready),a
        ld      a,(p126_ngs_video_mode_ready)
        or      a
        jp      z,.video_convert_no_mode

        ld      a,(p126_ngs_video_mode_desc)
        cp      P126_VIDEO_DESC_VERSION
        jp      nz,.video_convert_bad_mode
        ld      a,(p126_ngs_video_mode_desc+1)
        cp      P126_ATM_MODE_RG6_TEXT80X25
        jp      nz,.video_convert_bad_mode
        ld      a,(p126_ngs_video_mode_desc+2)
        cp      P126_VIDEO_TEXT80_WIDTH
        jp      nz,.video_convert_bad_mode
        ld      a,(p126_ngs_video_mode_desc+3)
        cp      P126_VIDEO_TEXT80_HEIGHT
        jp      nz,.video_convert_bad_mode
        ld      a,(p126_ngs_video_mode_desc+4)
        cp      P126_VIDEO_FORMAT_TEXT80X25
        jp      nz,.video_convert_bad_mode
        ld      hl,(p126_ngs_video_mode_desc+6)
        ld      de,P126_VIDEO_TEXT80_FRAME_SIZE
        or      a
        sbc     hl,de
        jp      nz,.video_convert_bad_mode

        ; Project125's essential operation: gather plane 0 and plane 1
        ; into contiguous char[2000] + attr[2000] arrays before presenting.
        ; The VGA overlay owns the physical 256 KiB backing-store mapping.
        call    x86_video_vga_capture_text_frame
        push    af
        push    bc
        push    hl
        ld      hl,x86_video_trace_capture_msg
        call    x86_video_trace_string
        pop     hl
        pop     bc
        pop     af
        jr      c,.video_capture_failed

        ; Dump the first eight bytes from the actual DMA producer page.
        ; This verifies that VGA capture populated the frame before IPC.
        call    x86_video_trace_dump_payload
        ld      hl,x86_video_trace_capture_ok
        call    x86_video_trace_string
        ld      hl,P126_VIDEO_TEXT80_FRAME_SIZE
        ld      (x86_video_frame_size),hl
        ld      a,1
        ld      (x86_video_frame_ready),a
        ld      hl,P126_VIDEO_TEXT80_FRAME_SIZE
        xor     a
        ret

.video_capture_failed:
        push    af
        ld      hl,x86_video_trace_capture_failed
        call    x86_video_trace_string
        pop     af
        scf
        ret

.video_convert_no_mode:
        ld      a,#F1
        scf
        ret
.video_convert_bad_mode:
        ld      a,#F3
        scf
        ret

; IN: HL=logical frame offset (0..7FFFh), A=byte.
; OUT: writes the current RG6 frame into page42h after the 18-byte ABI
; header. The sender later fills the header/padding and DMA-transfers this
; exact 16 KiB staging buffer.
x86_video_write_frame_byte:
        ld      (x86_video_frame_data),a
        ld      (x86_video_frame_offset),hl
        ld      a,P126_NGS_DMA_PROD_PAGE
        rrca
        out     (P126_NGS_BANK_WINDOW_PORT),a
        ld      hl,(x86_video_frame_offset)
        ld      de,P126_IPC_HEADER_SIZE
        add     hl,de
        ld      a,h
        and     #3F
        or      #C0
        ld      h,a
        ld      a,(x86_video_frame_data)
        ld      (hl),a
        ret

x86_video_text_base_mid: db 0
x86_video_row_offset:    dw 0
x86_video_cell_offset:   dw 0
x86_video_stride:        dw 0
x86_video_frame_index:   dw 0
x86_video_frame_offset:  dw 0
x86_video_frame_size:    dw 0
x86_video_frame_data:    db 0
x86_video_frame_ready:   db 0
x86_video_trace_capture_msg: db "[TRACE] VGA CAPTURE RETURNED",13,10,0
x86_video_trace_capture_ok: db "[VGA DBG] CAPTURE STATUS OK",13,10,0
x86_video_trace_capture_failed: db "[VGA DBG] CAPTURE FAILED",13,10,0
x86_video_trace_chars: db "[VGA DBG] FRAME CHARS[0..7]=",0
x86_video_trace_attrs: db "[VGA DBG] FRAME ATTRS[0..7]=",0

; Dump frame bytes from page42h staging area to NeoGS #EF.
x86_video_trace_dump_payload:
        push    af
        push    bc
        push    hl
        ld      hl,x86_video_trace_chars
        call    x86_video_trace_string
        ld      a,P126_NGS_DMA_PROD_PAGE
        rrca
        out     (P126_NGS_BANK_WINDOW_PORT),a
        ld      hl,#C000+P126_IPC_HEADER_SIZE
        ld      b,8
.x86_video_trace_char_loop:
        ld      a,(hl)
        inc     hl
        call    x86_video_trace_hex8
        djnz    .x86_video_trace_char_loop
        ld      hl,x86_video_trace_attrs
        call    x86_video_trace_string
        ld      a,P126_NGS_DMA_PROD_PAGE
        rrca
        out     (P126_NGS_BANK_WINDOW_PORT),a
        ld      hl,#C000+P126_IPC_HEADER_SIZE+P126_VIDEO_TEXT80_CELLS
        ld      b,8
.x86_video_trace_attr_loop:
        ld      a,(hl)
        inc     hl
        call    x86_video_trace_hex8
        djnz    .x86_video_trace_attr_loop
        ld      a,13
        out     (#EF),a
        ld      a,10
        out     (#EF),a
        pop     hl
        pop     bc
        pop     af
        ret

; IN A=value; preserve AF/BC.
x86_video_trace_hex8:
        push    af
        push    bc
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     #0F
        call    x86_video_trace_hex_nibble
        ld      a,b
        and     #0F
        call    x86_video_trace_hex_nibble
        pop     bc
        pop     af
        ret

x86_video_trace_hex_nibble:
        add     a,'0'
        cp      '9'+1
        jr      c,.x86_video_trace_hex_emit
        add     a,7
.x86_video_trace_hex_emit:
        out     (#EF),a
        ret

; Emit a fixed trace marker on NeoGS #EF without changing the caller's regs.
x86_video_trace_string:
        push    af
        push    bc
        push    hl
        ld      bc,#00EF
.x86_video_trace_loop:
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,.x86_video_trace_done
        out     (c),a
        jr      .x86_video_trace_loop
.x86_video_trace_done:
        pop     hl
        pop     bc
        pop     af
        ret

x86_video_row:           db 0
x86_video_col:           db 0
x86_video_char:          db 0
x86_video_attr:          db 0

; Project125-compatible BIOS INT 10h text services.
INCLUDE "reference/project126/neogs_sub/x86_bios_video.asm"
