; Project130 TR-DOS catalogue preload.
; Read-only mirror of the proven Project127 ROM call contract:
;   ROM entry #3D13, E=zero-based sector, HL=destination, B=1, C=5.
; Reads track 0 sectors 1..8 into the host W3/page-0 buffer at #C800.
; No disk writes or interrupt mode changes are performed here. The
; TR-DOS shadow-off trampoline briefly reenables interrupts on return.

SECTION CODE
PUBLIC _p130_trdos_preload
PUBLIC _p130_trdos_result

_p130_trdos_preload:
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy
        exx
        push    bc
        push    de
        push    hl
        exx
        ex      af,af'
        push    af
        ex      af,af'

        ld      (p130_trdos_saved_sp),sp
        ; Isolated scratch stack, matching the working Project127 reader.
        ld      sp,0B7F0h
        xor     a
        ld      (p130_trdos_io_error),a
        ld      (p130_trdos_io_status),a
        ld      (p130_trdos_sector),a
        ld      hl,0C800h
        ld      (p130_trdos_buffer_ptr),hl

p130_trdos_read_sector:
        ld      a,(p130_trdos_sector)
        cp      8
        jr      nc,p130_trdos_read_complete

        ld      e,a
        ld      d,0
        ld      hl,(p130_trdos_buffer_ptr)
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a

        ld      b,1
        ld      c,5
        call    p130_trdos_rom_call

        ld      bc,00EFh
        ld      a,'r'
        out     (c),a
        ld      a,(p130_trdos_sector)
        add     a,'0'
        out     (c),a
        ld      a,13
        out     (c),a
        ld      a,10
        out     (c),a

        ld      a,(05D0Fh)
        ld      (p130_trdos_io_error),a
        ld      b,a
        ld      a,(05D10h)
        ld      (p130_trdos_io_status),a
        or      b
        jr      nz,p130_trdos_read_failed

        ld      hl,(p130_trdos_buffer_ptr)
        ld      de,0100h
        add     hl,de
        ld      (p130_trdos_buffer_ptr),hl
        ld      a,(p130_trdos_sector)
        inc     a
        ld      (p130_trdos_sector),a
        jr      p130_trdos_read_sector

p130_trdos_read_complete:
        xor     a
        ld      (_p130_trdos_result),a
        jr      p130_trdos_restore

p130_trdos_read_failed:
        ld      a,1
        ld      (_p130_trdos_result),a

p130_trdos_restore:
        ld      sp,(p130_trdos_saved_sp)
        ex      af,af'
        pop     af
        ex      af,af'
        exx
        pop     hl
        pop     de
        pop     bc
        exx
        pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af

        ; Z88DK SDCC 16-bit return value: HL=0 on success, HL=1 on error.
        ld      a,(_p130_trdos_result)
        ld      l,a
        ld      h,0
        ret

; Project127-compatible TR-DOS ROM-call trampoline.
; A plain CALL #3D13 is not sufficient: TR-DOS returns through ERR_SP
; (#5C3D), and its DOS/shadow mapping must be restored through #3D2F.
; Preserve the host's W2/W3 pages around the DOS ROM mapping.
p130_trdos_rom_call:
        ; Shadow-off transition changes BC; restore the sector-read ABI
        ; registers afterwards, immediately before entering the ROM.
        push    af
        push    bc
        push    de
        push    hl
        ld      a,083h
        ld      bc,0FFF7h
        out     (c),a
        ld      a,0C3h
        ld      bc,0FF77h
        out     (c),a
        pop     hl
        pop     de
        pop     bc
        pop     af

        ld      hl,p130_trdos_rom_return
        push    hl
        ld      (23613),sp
        xor     a
        ld      (23801),a
        ld      (23823),a
        ld      (23824),a
        jp      03D13h

p130_trdos_rom_return:
        di
        ld      bc,p130_trdos_video_restored
        push    bc
        ld      bc,02A53h
        push    bc
        ld      bc,00177h
        ld      a,0C3h
        jp      03D2Fh

p130_trdos_video_restored:
        ld      a,07Ah
        ld      bc,07FF7h
        out     (c),a
        ld      a,07Fh
        ld      bc,0FFF7h
        out     (c),a
        ei
        ret

p130_trdos_saved_sp:     dw 0
p130_trdos_buffer_ptr:   dw 0C800h
p130_trdos_sector:       db 0
p130_trdos_io_error:     db 0
p130_trdos_io_status:    db 0
_p130_trdos_result:      db 0
