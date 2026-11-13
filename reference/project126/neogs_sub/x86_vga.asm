; PROJECT 125 — resident VGA planar core.
; Implemented: Sequencer/GC indexed registers, Attribute Controller
; index/data flip-flop and palette-enable latch, Misc Output, Status 1,
; aperture selection with aperture-relative offsets, four 64 KiB planes,
; read modes 0/1, write modes 0/1, chain-2 odd/even text addressing,
; latches, set/reset, rotate, logical ops, bit mask and Sequencer Map Mask.
; Pending: CRTC, DAC, scanout, chain-4 and write modes 2/3.
; Guest VRAM accesses use the original Project125 four-plane physical pages 83..98
; decimal (#53..#62), with no remapping to a different physical allocation.
; No NeoGS I/O ports are used by the VGA device.

x86_vga_io_read8_impl:
        ld      (x86_vga_io_port),hl
        ld      hl,(x86_vga_io_port)
        ld      de,#03C4
        or      a
        sbc     hl,de
        jp      z,.seq_index
        ld      hl,(x86_vga_io_port)
        ld      de,#03C5
        or      a
        sbc     hl,de
        jp      z,.seq_data
        ld      hl,(x86_vga_io_port)
        ld      de,#03CE
        or      a
        sbc     hl,de
        jp      z,.gc_index
        ld      hl,(x86_vga_io_port)
        ld      de,#03CF
        or      a
        sbc     hl,de
        jp      z,.gc_data
        ld      hl,(x86_vga_io_port)
        ld      de,#03CC
        or      a
        sbc     hl,de
        jp      z,.misc
        ld      hl,(x86_vga_io_port)
        ld      de,#03C0
        or      a
        sbc     hl,de
        jp      z,.attr_index_read
        ld      hl,(x86_vga_io_port)
        ld      de,#03C1
        or      a
        sbc     hl,de
        jp      z,.attr_data
        ld      hl,(x86_vga_io_port)
        ld      de,#03DA
        or      a
        sbc     hl,de
        jp      z,.status
        scf
        ret
.seq_index:
        ld      a,(x86_vga_seq_index)
        or      a
        ret
.seq_data:
        ld      a,(x86_vga_seq_index)
        cp      5
        jr      nc,.ff
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_seq_regs
        add     hl,de
        ld      a,(hl)
        or      a
        ret
.gc_index:
        ld      a,(x86_vga_gc_index)
        or      a
        ret
.gc_data:
        ld      a,(x86_vga_gc_index)
        cp      9
        jr      nc,.ff
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_gc_regs
        add     hl,de
        ld      a,(hl)
        or      a
        ret
.misc:
        ld      a,(x86_vga_misc_output)
        or      a
        ret
.attr_index_read:
        ld      a,(x86_vga_attr_index)
        ld      b,a
        ld      a,(x86_vga_attr_palette_enable)
        or      b
        or      a
        ret
.attr_data:
        ld      a,(x86_vga_attr_index)
        and     #1F
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_attr_regs
        add     hl,de
        ld      a,(hl)
        or      a
        ret
.status:
        xor     a
        ld      (x86_vga_attr_data_phase),a
        ld      a,(x86_vga_status_toggle)
        xor     #08
        ld      (x86_vga_status_toggle),a
        or      1
        ret
.ff:
        ld      a,#FF
        or      a
        ret

x86_vga_io_write8_impl:
        ld      (x86_vga_io_port),hl
        ld      (x86_io_value),a
        ld      hl,(x86_vga_io_port)
        ld      de,#03C4
        or      a
        sbc     hl,de
        jp      z,.seq_index
        ld      hl,(x86_vga_io_port)
        ld      de,#03C5
        or      a
        sbc     hl,de
        jp      z,.seq_data
        ld      hl,(x86_vga_io_port)
        ld      de,#03CE
        or      a
        sbc     hl,de
        jp      z,.gc_index
        ld      hl,(x86_vga_io_port)
        ld      de,#03CF
        or      a
        sbc     hl,de
        jp      z,.gc_data
        ld      hl,(x86_vga_io_port)
        ld      de,#03C2
        or      a
        sbc     hl,de
        jp      z,.misc
        ld      hl,(x86_vga_io_port)
        ld      de,#03C0
        or      a
        sbc     hl,de
        jp      z,.attr
        scf
        ret
.seq_index:
        ld      a,(x86_io_value)
        and     7
        ld      (x86_vga_seq_index),a
        or      a
        ret
.seq_data:
        ld      a,(x86_vga_seq_index)
        cp      5
        jr      nc,.done
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_seq_regs
        add     hl,de
        ld      a,(x86_io_value)
        ld      (hl),a
        or      a
        ret
.gc_index:
        ld      a,(x86_io_value)
        and     #0F
        ld      (x86_vga_gc_index),a
        or      a
        ret
.gc_data:
        ld      a,(x86_vga_gc_index)
        cp      9
        jr      nc,.done
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_gc_regs
        add     hl,de
        ld      a,(x86_io_value)
        ld      (hl),a
        or      a
        ret
.misc:
        ld      a,(x86_io_value)
        ld      (x86_vga_misc_output),a
        or      a
        ret
.attr:
        ld      a,(x86_vga_attr_data_phase)
        or      a
        jr      nz,.attr_data
        ld      a,(x86_io_value)
        and     #1F
        ld      (x86_vga_attr_index),a
        ld      a,(x86_io_value)
        and     #20
        ld      (x86_vga_attr_palette_enable),a
        ld      a,1
        ld      (x86_vga_attr_data_phase),a
        or      a
        ret
.attr_data:
        ld      a,(x86_vga_attr_index)
        and     #1F
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_attr_regs
        add     hl,de
        ld      a,(x86_io_value)
        ld      (hl),a
        xor     a
        ld      (x86_vga_attr_data_phase),a
.done:
        or      a
        ret

; Carry set: address is outside the active VGA aperture.
x86_vga_decode_aperture:
        ld      a,(x86_mem_addr+2)
        cp      #0A
        jr      z,.a000
        cp      #0B
        jr      nz,.no
        ld      a,(x86_vga_gc_regs+6)
        and     #0C
        or      a
        jr      z,.offset_full
        cp      #08
        jr      z,.b000
        cp      #0C
        jr      nz,.no
        ld      a,(x86_mem_addr+1)
        bit     7,a
        jr      z,.no
        jr      .offset_32_b800
.b000:
        ; B0000h has middle byte 00h; this is already the aperture offset.
        ld      a,(x86_mem_addr+1)
        bit     7,a
        jr      nz,.no
        ld      a,(x86_mem_addr+1)
        jr      .store_offset_hi
.offset_32_b800:
        ; B8000h starts at middle byte 80h, not B8h.
        ld      a,(x86_mem_addr+1)
        sub     #80
        jr      .store_offset_hi
.a000:
        ld      a,(x86_vga_gc_regs+6)
        and     #0C
        cp      #08
        jr      z,.no
        cp      #0C
        jr      z,.no
.offset_full:
        ; The 20-bit physical address is stored as low/middle/high bytes.
        ; A0000h has middle byte 00h, so its aperture offset high byte is
        ; already zero-based. Do not subtract A0h here.
        ld      a,(x86_mem_addr+1)
.store_offset_hi:
        ld      (x86_vga_offset+1),a
        ld      a,(x86_mem_addr)
        ld      (x86_vga_offset),a
        or      a
        ret
.no:
        scf
        ret

; A=plane; page = plane_base + offset[15:14].
x86_vga_map_plane:
        add     a,a
        add     a,a
        add     a,VGA_PLANE0_FIRST_PAGE
        ld      c,a
        ld      a,(x86_vga_offset+1)
        rlca
        rlca
        and     3
        add     a,c
        rrca
        out     (MPAGEX),a
        ld      a,(x86_vga_offset+1)
        and     #3F
        or      #C0
        ld      h,a
        ld      a,(x86_vga_offset)
        ld      l,a
        ret

x86_vga_mem_read8_impl:
        call    x86_vga_decode_aperture
        ret     c
        ; Load VGA latches from the unmodified aperture address, as PCem does.
        ; In chain-2 mode CPU A0 selects the plane; the plane offset is
        ; aperture_offset >> 1 (CPU A0 is removed from the address).
        ld      a,(x86_vga_gc_regs+5)
        and     #10
        jr      z,.read_plane_normal
        ld      a,(x86_vga_offset)
        and     1
        ld      b,a
        ld      a,(x86_vga_gc_regs+4)
        and     2
        or      b
        ld      (x86_vga_read_plane),a
        ; Normalize the plane offset before loading any of the four latches.
        call    x86_vga_offset_even
        jr      .read_latches
.read_plane_normal:
        ld      a,(x86_vga_gc_regs+4)
        and     3
        ld      (x86_vga_read_plane),a
.read_latches:
        xor     a
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_latches),a
        ld      a,1
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_latches+1),a
        ld      a,2
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_latches+2),a
        ld      a,3
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_latches+3),a
        ld      a,(x86_vga_gc_regs+5)
        and     #08
        jr      nz,.read_mode1
        ; Chain-2 mode-0 reads use the selected plane at aperture_offset >> 1.
        ld      a,(x86_vga_gc_regs+5)
        and     #10
        jr      z,.read_mode0_latch
        ; x86_vga_offset was normalized before the latch fetch above.
        ld      a,(x86_vga_read_plane)
        call    x86_vga_map_plane
        ld      a,(hl)
        or      a
        ret
.read_mode0_latch:
        ld      a,(x86_vga_read_plane)
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_latches
        add     hl,de
        ld      a,(hl)
        or      a
        ret
.read_mode1:
        xor     a
        ld      (x86_vga_compare_result),a
        xor     a
        call    x86_vga_compare_one
        ld      a,1
        call    x86_vga_compare_one
        ld      a,2
        call    x86_vga_compare_one
        ld      a,3
        call    x86_vga_compare_one
        ld      a,(x86_vga_compare_result)
        cpl
        ret

; A=plane; OR its mismatch byte into the accumulated comparator result.
x86_vga_compare_one:
        ld      (x86_vga_plane),a
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_latches
        add     hl,de
        ld      b,(hl)
        ld      a,(x86_vga_bit_table)
        ld      c,a
        ld      a,(x86_vga_plane)
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_bit_table
        add     hl,de
        ld      a,(hl)
        ld      c,a
        ld      a,(x86_vga_gc_regs+7)
        and     c
        ret     z
        ld      a,(x86_vga_gc_regs+2)
        and     c
        jr      z,.zero
        ld      a,b
        cpl
        jr      .acc
.zero:
        ld      a,b
.acc:
        ld      b,a
        ld      a,(x86_vga_compare_result)
        or      b
        ld      (x86_vga_compare_result),a
        ret

x86_vga_mem_write8_impl:
        ld      (x86_mem_data),a
        call    x86_vga_decode_aperture
        ret     c
        ; Chain-2 writes use A0 to choose plane pair member and address>>1.
        ld      a,(x86_vga_seq_regs+4)
        bit     2,a
        jr      nz,.write_planar
        ld      a,(x86_vga_offset)
        and     1
        ld      b,a
        call    x86_vga_offset_even
        ; In odd/even text mode CPU A0 selects exactly one plane:
        ; even addresses use Sequencer Map Mask bit 0 (plane 0),
        ; odd addresses use bit 1 (plane 1). Do not let the other enabled
        ; map-mask bit leak into the write; that corrupts both text planes.
        ld      a,(x86_vga_seq_regs+2)
        and     1
        ld      c,a
        ld      a,b
        or      a
        jr      z,.odd_even_even
        ld      a,(x86_vga_seq_regs+2)
        and     2
        jr      .odd_even_mask_ready
.odd_even_even:
        ld      a,c
.odd_even_mask_ready:
        ld      (x86_vga_effective_mask),a
        jr      .write_mode_decode
.write_planar:
        ld      a,(x86_vga_seq_regs+2)
        ld      (x86_vga_effective_mask),a
.write_mode_decode:
        ld      a,(x86_vga_gc_regs+5)
        and     3
        cp      1
        jp      z,.mode1
        or      a
        jp      nz,.unsupported
        ld      a,(x86_mem_value)
        ld      b,a
        ld      a,(x86_vga_gc_regs+3)
        and     7
        ld      c,a
.rotate:
        ld      a,c
        or      a
        jr      z,.rotated
        ld      a,b
        rrca
        ld      b,a
        dec     c
        jr      .rotate
.rotated:
        ld      a,b
        ld      (x86_vga_rotated),a
        xor     a
        ld      (x86_vga_plane),a
.plane_loop:
        ld      a,(x86_vga_plane)
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_bit_table
        add     hl,de
        ld      a,(hl)
        ld      b,a
        ld      a,(x86_vga_effective_mask)
        and     b
        jr      z,.next_plane
        ; GC1 selects set/reset on this plane; otherwise use rotated CPU data.
        ld      a,(x86_vga_plane)
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_bit_table
        add     hl,de
        ld      b,(hl)
        ld      a,(x86_vga_gc_regs+1)
        and     b
        jr      z,.cpu_source
        ld      a,(x86_vga_gc_regs)
        and     b
        ld      b,0
        jr      z,.source_ready
        dec     b
        jr      .source_ready
.cpu_source:
        ld      a,(x86_vga_rotated)
        ld      b,a
.source_ready:
        ld      a,(x86_vga_plane)
        call    x86_vga_get_latch
        ld      c,a
        ld      a,(x86_vga_gc_regs+3)
        and     #18
        call    x86_vga_logic
        ld      b,a
        ld      a,(x86_vga_gc_regs+8)
        ld      d,a
        and     b
        ld      e,a
        ld      a,d
        cpl
        and     c
        or      e
        ld      (x86_vga_write_byte),a
        ld      a,(x86_vga_plane)
        call    x86_vga_map_plane
        ld      a,(x86_vga_write_byte)
        ld      (hl),a
        ; Do not report a successful VGA bus write until the selected
        ; physical plane actually retains the byte. This catches bad
        ; MPAGEX/page selection at the point of failure, before frame DMA.
        cp      (hl)
        jr      nz,.write_verify_failed
.next_plane:
        ld      a,(x86_vga_plane)
        inc     a
        ld      (x86_vga_plane),a
        cp      4
        jr      c,.plane_loop
        call    x86_vga_dump_full_vram_once
        or      a
        ret
.mode1:
        xor     a
        ld      (x86_vga_plane),a
.mode1_loop:
        ld      a,(x86_vga_plane)
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_bit_table
        add     hl,de
        ld      a,(hl)
        ld      b,a
        ld      a,(x86_vga_effective_mask)
        and     b
        jr      z,.mode1_next
        ld      a,(x86_vga_plane)
        call    x86_vga_get_latch
        ld      (x86_vga_write_byte),a
        ld      a,(x86_vga_plane)
        call    x86_vga_map_plane
        ld      a,(x86_vga_write_byte)
        ld      (hl),a
        cp      (hl)
        jr      nz,.write_verify_failed
.mode1_next:
        ld      a,(x86_vga_plane)
        inc     a
        ld      (x86_vga_plane),a
        cp      4
        jr      c,.mode1_loop
        call    x86_vga_dump_full_vram_once
        or      a
        ret
.write_verify_failed:
        ; Carry is the existing x86 guest-memory write fault ABI.
        scf
        ret
.unsupported:
        or      a
        ret

x86_vga_offset_even:
        ; Chain-2/odd-even: CPU A0 selects plane 0/1. The remaining
        ; aperture address bits are shifted right once to form the plane
        ; byte offset, exactly as the 8086 VGA odd/even address decoder.
        ld      hl,(x86_vga_offset)
        srl     h
        rr      l
        ld      (x86_vga_offset),hl
        ret

x86_vga_get_latch:
        ld      e,a
        ld      d,0
        ld      hl,x86_vga_latches
        add     hl,de
        ld      a,(hl)
        ret

; A=GC3 function, B=source, C=latch.
x86_vga_logic:
        cp      #08
        jr      z,.and_op
        cp      #10
        jr      z,.or_op
        cp      #18
        jr      z,.xor_op
        ld      a,b
        ret
.and_op:
        ld      a,b
        and     c
        ret
.or_op:
        ld      a,b
        or      c
        ret
.xor_op:
        ld      a,b
        xor     c
        ret

 ; Project130 compatibility aliases for the Project125 register core.
MPAGEX                  EQU P126_NGS_BANK_WINDOW_PORT
x86_mem_addr            EQU x86_phys_addr
x86_mem_value           EQU x86_mem_data
x86_vga_io_port:        dw 0
x86_io_value:           db 0

x86_vga_seq_index:       db 0
x86_vga_gc_index:        db 0
x86_vga_attr_index:      db 0
x86_vga_attr_palette_enable: db 0
x86_vga_attr_data_phase: db 0
x86_vga_misc_output:     db 1
x86_vga_status_toggle:   db 0
x86_vga_seq_regs:        db 3,0,#0F,0,6
x86_vga_gc_regs:         db 0,0,0,0,0,0,0,0,#FF
x86_vga_attr_regs:       defs 32,0
x86_vga_bit_table:       db 1,2,4,8
x86_vga_offset:          dw 0
x86_vga_plane:           db 0
x86_vga_read_plane:       db 0
x86_vga_effective_mask:   db #0F
x86_vga_latches:         db 0,0,0,0
x86_vga_compare_result:  db 0
x86_vga_write_byte:      db 0
x86_vga_rotated:         db 0

; Project130 overlay ABI adapter: reset the Project125 VGA core.
x86_vga_reset_impl:
        xor     a
        ld      (x86_vga_seq_index),a
        ld      (x86_vga_gc_index),a
        ld      (x86_vga_attr_index),a
        ld      (x86_vga_attr_palette_enable),a
        ld      (x86_vga_attr_data_phase),a
        ld      (x86_vga_status_toggle),a
        ld      (x86_vga_misc_output),a
        ld      a,3
        ld      (x86_vga_seq_regs),a
        xor     a
        ld      (x86_vga_seq_regs+1),a
        ld      a,#0F
        ld      (x86_vga_seq_regs+2),a
        xor     a
        ld      (x86_vga_seq_regs+3),a
        ld      a,6
        ld      (x86_vga_seq_regs+4),a
        ld      hl,x86_vga_gc_regs
        ld      b,8
.reset_gc:
        xor     a
        ld      (hl),a
        inc     hl
        djnz    .reset_gc
        ld      a,#FF
        ld      (x86_vga_gc_regs+8),a
        ld      hl,x86_vga_attr_regs
        ld      b,32
.reset_attr:
        xor     a
        ld      (hl),a
        inc     hl
        djnz    .reset_attr
        ld      hl,x86_vga_latches
        ld      b,4
.reset_latches:
        xor     a
        ld      (hl),a
        inc     hl
        djnz    .reset_latches
        or      a
        ret

; The P125 plane implementation stores the text page as plane 0/1.
; This compatibility reader is used by the P130 frame converter.
x86_vga_read_text_cell_impl:
        ; IN HL=cell index, A=B800 aperture selector; OUT A=character,D=attribute.
        push    bc
        push    de
        push    hl
        add     hl,hl
        ld      (x86_vga_offset),hl
        xor     a
        ld      (x86_mem_addr),a
        ld      a,l
        ld      (x86_mem_addr),a
        ld      a,h
        add     a,#80
        ld      (x86_mem_addr+1),a
        ld      a,#0B
        ld      (x86_mem_addr+2),a
        call    x86_vga_decode_aperture
        jr      c,.read_cell_fail
        call    x86_vga_offset_even
        xor     a
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_text_char),a
        ld      a,1
        call    x86_vga_map_plane
        ld      a,(hl)
        ld      (x86_vga_text_attr),a
        ld      a,(x86_vga_text_char)
        pop     hl
        pop     de
        ld      a,(x86_vga_text_attr)
        ld      d,a
        ld      a,(x86_vga_text_char)
        pop     bc
        or      a
        ret
.read_cell_fail:
        pop     hl
        pop     de
        pop     bc
        scf
        ret

x86_vga_text_char: db 0
x86_vga_text_attr: db 0

; Capture follows the Project125 live-video data path:
;   plane 0 -> 2000 character bytes
;   plane 1 -> 2000 attribute bytes
; The two planes are copied through the free WIN1 staging area because
; Project130 executes this overlay from WIN2 and uses WIN3 for banked RAM.
; WIN1 stack ends below #5000; host input mailbox starts at #7000.
X86_VGA_CAPTURE_STAGE EQU #5000
x86_vga_capture_saved_addr: db 0,0,0

x86_vga_capture_text_frame_gate_impl:
        push    af
        push    bc
        push    de
        push    hl

        ; Resolve the actual B8000 aperture offset through the same VGA
        ; decoder used by guest CPU writes. In a 128 KiB GC6 mapping B8000
        ; is offset 8000h into each plane (page + 2); in the 32 KiB B8000
        ; mapping it is offset zero. Capturing plane base pages unconditionally
        ; silently returned blank text even though guest writes succeeded.
        ld      a,(x86_mem_addr)
        ld      (x86_vga_capture_saved_addr),a
        ld      a,(x86_mem_addr+1)
        ld      (x86_vga_capture_saved_addr+1),a
        ld      a,(x86_mem_addr+2)
        ld      (x86_vga_capture_saved_addr+2),a
        xor     a
        ld      (x86_mem_addr),a
        ld      a,#80
        ld      (x86_mem_addr+1),a
        ld      a,#0B
        ld      (x86_mem_addr+2),a
        call    x86_vga_decode_aperture
        jp      c,.capture_restore_fail

        ; Text mode uses VGA odd/even (chain-2) addressing: CPU A0 selects
        ; plane 0/1 and the physical byte offset is aperture_offset >> 1.
        ; Guest writes already apply this normalization before mapping a
        ; plane; capture must do exactly the same or it reads page + 2
        ; instead of the page containing the BIOS text bytes (page + 1).
        call    x86_vga_offset_even

        ; Plane 0: exactly the B8000 character bytes selected by GC6.
        xor     a
        call    x86_vga_map_plane
        ld      de,X86_VGA_CAPTURE_STAGE
        ld      bc,#07D0
        ldir
        ld      hl,x86_vga_trace_chars
        call    p126_ngs_resident_log
        ld      hl,X86_VGA_CAPTURE_STAGE
        call    x86_vga_trace_dump8

        ; Plane 1: same decoded aperture offset, attribute bytes.
        ld      a,1
        call    x86_vga_map_plane
        ld      de,X86_VGA_CAPTURE_STAGE+#07D0
        ld      bc,#07D0
        ldir
        ld      hl,x86_vga_trace_attrs
        call    p126_ngs_resident_log
        ld      hl,X86_VGA_CAPTURE_STAGE+#07D0
        call    x86_vga_trace_dump8

        ; Publish the captured text planes in the page-42 DMA frame.
        ; Restore the normal page-42 DMA producer mapping and publish the
        ; exact Project125 payload layout at the P126 frame payload offset.
        ld      a,P126_NGS_DMA_PAGE
        rrca
        out     (P126_NGS_BANK_WINDOW_PORT),a
        ld      hl,X86_VGA_CAPTURE_STAGE
        ld      de,#C000+P126_IPC_HEADER_SIZE
        ld      bc,#0FA0
        ldir
        ; Verify the final DMA payload independently of the staging buffer.
        ld      hl,x86_vga_trace_dma_chars
        call    p126_ngs_resident_log
        ld      hl,#C000+P126_IPC_HEADER_SIZE
        call    x86_vga_trace_dump8
        ld      hl,x86_vga_trace_dma_attrs
        call    p126_ngs_resident_log
        ld      hl,#C000+P126_IPC_HEADER_SIZE+#07D0
        call    x86_vga_trace_dump8

        ld      a,(x86_vga_capture_saved_addr)
        ld      (x86_mem_addr),a
        ld      a,(x86_vga_capture_saved_addr+1)
        ld      (x86_mem_addr+1),a
        ld      a,(x86_vga_capture_saved_addr+2)
        ld      (x86_mem_addr+2),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ld      hl,#0FA0
        xor     a
        ret

.capture_restore_fail:
        ld      a,(x86_vga_capture_saved_addr)
        ld      (x86_mem_addr),a
        ld      a,(x86_vga_capture_saved_addr+1)
        ld      (x86_mem_addr+1),a
        ld      a,(x86_vga_capture_saved_addr+2)
        ld      (x86_mem_addr+2),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ld      hl,0
        scf
        ret


; Dump the complete 4-plane VGA backing store once, immediately after the
; first successful guest VGA write. Each plane is 64 KiB (four 16 KiB pages).
; Output is intentionally raw hex on debug port #EF: 256 KiB total.
x86_vga_dump_full_vram_once:
        ld      a,(x86_vga_full_dump_done)
        or      a
        ret     nz
        inc     a
        ld      (x86_vga_full_dump_done),a
        push    af
        push    bc
        push    de
        push    hl
        xor     a
        ld      (x86_vga_full_dump_plane),a
.plane:
        ld      a,(x86_vga_full_dump_plane)
        ld      hl,x86_vga_full_dump_plane_header
        call    p126_ngs_resident_log
        ld      a,(x86_vga_full_dump_plane)
        call    x86_vga_trace_hex_nibble
        ld      a,13
        out     (#EF),a
        ld      a,10
        out     (#EF),a
        xor     a
        ld      (x86_vga_full_dump_page),a
.page:
        ; Map one 16 KiB physical page of this plane into WIN3.
        ld      a,(x86_vga_full_dump_page)
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      h,a
        ld      l,0
        ld      (x86_vga_offset),hl
        ld      a,(x86_vga_full_dump_plane)
        call    x86_vga_map_plane
        ld      bc,#4000
        ld      a,16
        ld      (x86_vga_full_dump_line_count),a
.byte:
        ld      a,(hl)
        ld      e,a
        rrca
        rrca
        rrca
        rrca
        and     #0F
        call    x86_vga_trace_hex_nibble
        ld      a,e
        and     #0F
        call    x86_vga_trace_hex_nibble
        inc     hl
        dec     bc
        ld      a,c
        and     #0F
        jr      nz,.no_newline
        push    bc
        ld      a,13
        out     (#EF),a
        ld      a,10
        out     (#EF),a
        pop     bc
.no_newline:
        ld      a,b
        or      c
        jr      nz,.byte
        ld      a,(x86_vga_full_dump_page)
        inc     a
        ld      (x86_vga_full_dump_page),a
        cp      4
        jr      c,.page
        ld      a,(x86_vga_full_dump_plane)
        inc     a
        ld      (x86_vga_full_dump_plane),a
        cp      4
        jr      c,.plane
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

x86_vga_full_dump_done:       db 0
x86_vga_full_dump_plane:      db 0
x86_vga_full_dump_page:       db 0
x86_vga_full_dump_line_count: db 0
x86_vga_full_dump_plane_header: db "[FULL VGA VRAM] PLANE=",0

; One-shot capture diagnostics: dump eight bytes from the supplied
; WIN1/WIN3 pointer without changing the caller's register state.
x86_vga_trace_dump8:
        push    af
        push    bc
        push    hl
        ld      b,8
.dump_loop:
        ld      a,(hl)
        inc     hl
        push    hl
        ld      c,a
        rrca
        rrca
        rrca
        rrca
        and     #0F
        call    x86_vga_trace_hex_nibble
        ld      a,c
        and     #0F
        call    x86_vga_trace_hex_nibble
        pop     hl
        djnz    .dump_loop
        ld      a,13
        out     (#EF),a
        ld      a,10
        out     (#EF),a
        pop     hl
        pop     bc
        pop     af
        ret

x86_vga_trace_hex_nibble:
        add     a,'0'
        cp      '9'+1
        jr      c,.hex_emit
        add     a,7
.hex_emit:
        out     (#EF),a
        ret

x86_vga_trace_chars:     db "[VGA CAP] PLANE0 STAGE=",0
x86_vga_trace_attrs:     db "[VGA CAP] PLANE1 STAGE=",0
x86_vga_trace_dma_chars: db "[VGA CAP] DMA CHARS=",0
x86_vga_trace_dma_attrs: db "[VGA CAP] DMA ATTRS=",0

; Project130 dynamic-overlay ABI.
x86_vga_overlay_probe:
        ld      a,#56
        ld      hl,#A55A
        ret

x86_vga_register_selftest_impl:
        call    x86_vga_reset_impl
        ld      a,(x86_vga_seq_regs)
        cp      3
        jr      nz,.selftest_fail
        ld      a,(x86_vga_gc_regs+8)
        cp      #FF
        jr      nz,.selftest_fail
        ld      a,#5A
        ld      hl,#A55A
        ret
.selftest_fail:
        xor     a
        ld      hl,0
        scf
        ret

; Compatibility snapshot API. The converter uses the bulk capture entry
; below; legacy callers receive the text register-state block.
x86_vga_get_text_snapshot_impl:
        ld      hl,x86_vga_seq_regs
        xor     a
        ret

; The BIOS video overlay passes the port in HL and the byte in B.
x86_vga_io_write8_gate_impl:
        ld      a,b
        ld      (x86_io_value),a
        ld      (x86_io_port),hl
        jp      x86_vga_io_write8_impl

; The BIOS video overlay passes the physical address in x86_phys_addr
; and the byte in B.
x86_vga_mem_write8_gate_impl:
        ld      a,b
        ld      (x86_mem_data),a
        jp      x86_vga_mem_write8_impl
