; Project130 ATM-side GS105a bootstrap launcher.
; Legacy GSDAT is restricted to transferring NEOBOOT.C (<=256 bytes).
; After #13, only the bootstrap-ready A1 acknowledgement is accepted.
; No resident core or application payload is sent over GSDAT.

SECTION CODE
PUBLIC _p130_neogs_startup

P130_GSCOM       EQU 0BBh
P130_GSSTAT      EQU 0BBh
P130_GSDAT       EQU 0B3h
P130_CMD_JUMP    EQU 013h
P130_CMD_RECV    EQU 014h
P130_CMD_RESET   EQU 0F4h
P130_ACK_READY   EQU 0A1h
P130_GFX_MODE    EQU 0C3h
P130_HOST_PAGE5  EQU 07Ah
P130_HOST_PAGE0  EQU 07Fh

_p130_neogs_startup:
        ; TR-DOS ROM calls require the Project127 ATM bank/port transition.
; Current Project130 RG6 80x25 mode is #C3 (set by ui.asm via #3D2F).
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
        ld      (p130_ngs_saved_sp),sp
        ld      sp,0B7F0h
        xor     a
        ld      (p130_ngs_result),a

        ; Project127 path: the complete TR-DOS directory is already
        ; resident at #C800. Find NEOBOOT.C in that snapshot and use only
        ; the known-working C=5 sector-read entry. Do not call C=0A/C=08.
        ld      ix,0C800h
        ld      a,128
        ld      (p130_ngs_scan_left),a
        ld      bc,00EFh
        ld      a,'R'
        out     (c),a
p130_ngs_scan_entry:
        ld      a,(ix+0)
        cp      'N'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+1)
        cp      'E'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+2)
        cp      'O'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+3)
        cp      'B'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+4)
        cp      'O'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+5)
        cp      'O'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+6)
        cp      'T'
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+7)
        cp      ' '
        jr      nz,p130_ngs_scan_next
        ld      a,(ix+8)
        cp      'C'
        jr      z,p130_ngs_scan_found
p130_ngs_scan_next:
        ld      de,16
        add     ix,de
        ld      a,(p130_ngs_scan_left)
        dec     a
        ld      (p130_ngs_scan_left),a
        jr      nz,p130_ngs_scan_entry
        jp      p130_ngs_fail

p130_ngs_scan_found:
        ld      bc,00EFh
        ld      a,'r'
        out     (c),a

        ; TR-DOS descriptor, verified against Project127's actual field accesses:
        ; length +11/+12, sector count +13, first sector +14,
        ; logical track +15. Project127's directory-dump comment is off by
        ; one; its ix-relative loads resolve to these descriptor offsets.
        ld      a,(ix+11)
        ld      l,a
        ld      a,(ix+12)
        ld      h,a
        ld      a,h
        or      l
        jp      z,p130_ngs_fail
        ld      a,h
        or      a
        jr      z,p130_ngs_len_ok
        cp      1
        jp      nz,p130_ngs_fail
        ld      a,l
        or      a
        jp      nz,p130_ngs_fail
p130_ngs_len_ok:
        ld      (p130_ngs_length),hl
        ld      a,(ix+14)
        cp      16
        jp      nc,p130_ngs_fail
        ld      (p130_ngs_sector),a
        ld      a,(ix+15)
        ld      (p130_ngs_track),a

        ; C=05, B=1, HL=#C000, DE=track:sector.
        ld      bc,00EFh
        ld      a,'T'
        out     (c),a
        ld      a,(p130_ngs_track)
        ld      d,a
        ld      a,(p130_ngs_sector)
        ld      e,a
        ld      hl,0C000h
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a

        ; Project127 sys_SHADOFF sequence:
        ; map the BASIC-48/DOS page into window 0, then write the saved
        ; RG6 mode to the ATM system port #FF77 (shadow ports off).
        ld      a,083h
        ld      bc,0FFF7h
        out     (c),a
        ld      a,P130_GFX_MODE
        ld      bc,0FF77h
        out     (c),a

        ; TR-DOS expects its return address through system variable 23613,
        ; not an ordinary CALL return alone. Project127 installs this
        ; trampoline and enters #3D13 with JP.
        ld      hl,p130_ngs_trdos_return
        push    hl
        ld      (23613),sp
        xor     a
        ld      (23801),a
        ld      (23823),a
        ld      (23824),a
        jp      03D13h

p130_ngs_trdos_return:
        push    af
        ld      bc,00EFh
        ld      a,'t'
        out     (c),a
        pop     af

        ; Restore Project130 host mapping and re-enable the same shadow
        ; ports/video mode using the #3D2F sequence from ui.asm.
        di
        ld      a,P130_HOST_PAGE5
        ld      bc,07FF7h
        out     (c),a
        ld      a,P130_HOST_PAGE0
        ld      bc,0FFF7h
        out     (c),a
        ei
        ld      bc,p130_ngs_trdos_video_restored
        push    bc
        ld      bc,02A53h
        push    bc
        ld      bc,00177h
        ld      a,P130_GFX_MODE
        jp      03D2Fh

p130_ngs_trdos_video_restored:
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jp      nz,p130_ngs_fail

        ld      a,2
        ld      (_p130_neogs_stage),a
        ld      a,'2'
        call    p130_ngs_trace
        ld      a,3
        ld      (_p130_neogs_stage),a
        ld      a,'3'
        call    p130_ngs_trace
        ld      a,4
        ld      (_p130_neogs_stage),a
        ld      a,'4'
        call    p130_ngs_trace
        ; TR-DOS has already loaded the complete file at #C000.

        ld      a,5
        ld      (_p130_neogs_stage),a
        ld      a,'5'
        call    p130_ngs_trace
        ; Restart the stock ROM into its known command receive state.
        ld      a,P130_CMD_RESET
        call    p130_ngs_send_command_long
        jp      c,p130_ngs_fail

        ld      a,6
        ld      (_p130_neogs_stage),a
        ld      a,'6'
        call    p130_ngs_trace
        ; #14: low length argument, then high length, address low/high.
        ld      hl,(p130_ngs_length)
        ld      a,l
        call    p130_ngs_send_argument
        jp      c,p130_ngs_fail
        ld      a,P130_CMD_RECV
        call    p130_ngs_send_command
        jp      c,p130_ngs_fail
        ld      hl,(p130_ngs_length)
        ld      a,h
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        xor     a
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        ld      a,040h
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail

        ld      a,7
        ld      (_p130_neogs_stage),a
        ld      a,'7'
        call    p130_ngs_trace
        ; The only GSDAT payload is the small bootstrap image.
        ld      hl,0C000h
        ld      de,(p130_ngs_length)
p130_ngs_stream:
        ld      a,d
        or      e
        jr      z,p130_ngs_stream_done
        ld      a,(hl)
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        inc     hl
        dec     de
        jr      p130_ngs_stream
p130_ngs_stream_done:
        ld      a,8
        ld      (_p130_neogs_stage),a
        ld      a,'8'
        call    p130_ngs_trace
        ; #13 transfers control to #4000. Bootstrap disables NOROM and
        ; publishes A1 through its own ZX data endpoint.
        xor     a
        call    p130_ngs_send_argument
        jp      c,p130_ngs_fail
        ld      a,P130_CMD_JUMP
        call    p130_ngs_send_command
        jp      c,p130_ngs_fail
        ld      a,040h
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        ld      a,9
        ld      (_p130_neogs_stage),a
        ld      a,'9'
        call    p130_ngs_trace
        call    p130_ngs_wait_dbit_set
        jp      c,p130_ngs_fail
        in      a,(P130_GSDAT)
        cp      P130_ACK_READY
        jp      nz,p130_ngs_fail
        xor     a
        jp      p130_ngs_finish

p130_ngs_fail:
        ld      a,1

p130_ngs_finish:
        ld      (p130_ngs_result),a
        ld      a,(p130_ngs_old_name_len)
        ld      (05D06h),a
        ld      a,(p130_ngs_old_drive)
        ld      (05CF9h),a
        ld      a,(p130_ngs_old_ext)
        ld      (05CE5h),a
        ld      a,(p130_ngs_old_status)
        ld      (05D10h),a
        ld      sp,(p130_ngs_saved_sp)
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
        ld      a,(p130_ngs_result)
        ld      l,a
        ld      h,0
        ret

; Emit a one-character progress marker on the existing #EF debug channel.
p130_ngs_trace:
        push    bc
        ld      bc,00EFh
        out     (c),a
        call    0A003h
        pop     bc
        ret

; Long bounded CBIT wait for the GS105a cold-reset command.
p130_ngs_send_command_long:
        ld      (p130_ngs_tx),a
        ld      a,(p130_ngs_tx)
        out     (P130_GSCOM),a
        push    de
        ld      d,16
p130_ngs_reset_outer:
        ld      bc,0FFFFh
p130_ngs_reset_inner:
        in      a,(P130_GSSTAT)
        bit     0,a
        jr      z,p130_ngs_reset_done
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_reset_inner
        dec     d
        jr      nz,p130_ngs_reset_outer
        pop     de
        scf
        ret
p130_ngs_reset_done:
        pop     de
        or      a
        ret

; A=command. Carry set on bounded CBIT timeout.
p130_ngs_send_command:
        ld      (p130_ngs_tx),a
        ld      a,(p130_ngs_tx)
        out     (P130_GSCOM),a
        ld      bc,0FFFFh
p130_ngs_cmd_wait:
        in      a,(P130_GSSTAT)
        bit     0,a
        jr      z,p130_ngs_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_cmd_wait
        scf
        ret

; A=argument, preloaded before #13/#14 command dispatch.
p130_ngs_send_argument:
        ld      (p130_ngs_tx),a
        call    p130_ngs_wait_dbit_clear
        ret     c
        ld      a,(p130_ngs_tx)
        out     (P130_GSDAT),a
        or      a
        ret

; A=payload byte. Used only while stock ROM receives NEOBOOT.C.
p130_ngs_send_byte:
        ld      (p130_ngs_tx),a
        call    p130_ngs_wait_dbit_clear
        ret     c
        ld      a,(p130_ngs_tx)
        out     (P130_GSDAT),a
        jp      p130_ngs_wait_dbit_clear

p130_ngs_wait_dbit_clear:
        ld      bc,0FFFFh
p130_ngs_dbit_clear_loop:
        in      a,(P130_GSSTAT)
        bit     7,a
        jr      z,p130_ngs_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_dbit_clear_loop
        scf
        ret

p130_ngs_wait_dbit_set:
        ld      bc,0FFFFh
p130_ngs_dbit_set_loop:
        in      a,(P130_GSSTAT)
        bit     7,a
        jr      nz,p130_ngs_ok
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_dbit_set_loop
        scf
        ret

p130_ngs_ok:
        or      a
        ret

PUBLIC _p130_neogs_stage
_p130_neogs_stage: db 0

p130_ngs_boot_name: db "NEOBOOT C"
p130_ngs_length:    dw 0
p130_ngs_tx:        db 0
p130_ngs_saved_sp:  dw 0
p130_ngs_result:    db 0
p130_ngs_old_name_len: db 0
p130_ngs_old_drive: db 0
p130_ngs_old_ext: db 0
p130_ngs_old_status: db 0
p130_ngs_sector: db 0
p130_ngs_track: db 0
p130_ngs_scan_left: db 0
