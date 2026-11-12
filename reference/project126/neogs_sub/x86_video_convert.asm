; =========================================================================
; PROJECT126 — VGA text to ATM-native frame converter
; Module ID06, dynamic overlay page09.
; VGA behavior is obtained only through the X86VGA public gate API.
; Initial ATM target: RG6 80x25 text, compact frame layout:
;   bytes 0000..07CF = 2000 character codes
;   bytes 07D0..0F9F = 2000 attribute bytes
; The exact 4000-byte Project125 text payload is staged at page42h:C000h for reverse DMA.
; =========================================================================

x86_video_overlay_probe:
        ld      a,#56
        ld      hl,#A55A
        ret

; X86VGA is a separate dynamic overlay (module 05/page08). Never call
; its routines directly while X86VID (module 06/page09) occupies WIN2.
x86_video_vga_get_text_snapshot:
        ld      a,P126_NGS_X86VGA_MODULE_ID
        ld      ix,x86_vga_get_text_snapshot_impl
        jp      p126_overlay_call_module

x86_video_vga_read_text_cell:
        ld      a,P126_NGS_X86VGA_MODULE_ID
        ld      ix,x86_vga_read_text_cell_raw_gate_impl
        jp      p126_overlay_call_module

; Convert one complete 80x25 B800 text page using the Project125 capture
; contract. OUT: A=0, HL=frame byte count, CF=0.
x86_video_convert_impl:
        xor     a
        ld      (x86_video_frame_ready),a
        ld      a,(p126_ngs_video_mode_ready)
        or      a
        jp      z,.video_convert_no_mode

        ; Revalidate the resident descriptor at the point of use.
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

        ; Exact Project125 capture layout: 2000 character bytes followed
        ; by 2000 attribute bytes. Project130 stores VGA planes in its 256 KiB
        ; backing VRAM, so the X86VGA raw-plane gate reads plane 0/1 directly.
        ld      hl,0
        ld      (x86_video_frame_index),hl
.video_convert_cell:
        ld      hl,(x86_video_frame_index)
        call    x86_video_vga_read_text_cell
        ld      (x86_video_char),a
        ld      a,d
        ld      (x86_video_attr),a

        ld      hl,(x86_video_frame_index)
        ld      a,(x86_video_char)
        call    x86_video_write_frame_byte
        ld      hl,(x86_video_frame_index)
        ld      de,P126_VIDEO_TEXT80_CELLS
        add     hl,de
        ld      a,(x86_video_attr)
        call    x86_video_write_frame_byte

        ld      hl,(x86_video_frame_index)
        inc     hl
        ld      (x86_video_frame_index),hl
        ld      de,P126_VIDEO_TEXT80_CELLS
        or      a
        sbc     hl,de
        jr      c,.video_convert_cell

        ld      hl,P126_VIDEO_TEXT80_FRAME_SIZE
        ld      (x86_video_frame_size),hl
        ld      a,1
        ld      (x86_video_frame_ready),a
        ld      hl,P126_VIDEO_TEXT80_FRAME_SIZE
        xor     a
        ret

.video_convert_no_mode:
        ld      a,#F1
        scf
        ret
.video_convert_unsupported:
        ld      a,#F2
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
        ld      de,#C000
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
x86_video_row:           db 0
x86_video_col:           db 0
x86_video_char:          db 0
x86_video_attr:          db 0

; Project125-compatible BIOS INT 10h text services.
INCLUDE "reference/project126/neogs_sub/x86_bios_video.asm"
