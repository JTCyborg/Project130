; Project130 ATM-side GS105a bootstrap launcher.
; Legacy GSDAT is restricted to transferring NEOBOOT.C (<=256 bytes).
; After #13, the Project126-compatible A1 bootstrap-ready acknowledgement
; is accepted. Project130 then switches to its own DMA/IPC initialization;
; no resident core or application payload is sent over GSDAT.

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

        ; Re-enable shadow ports/video first, exactly as ui.asm does,
        ; then restore the host's W2/W3 pages.
        di
        ld      bc,p130_ngs_trdos_video_restored
        push    bc
        ld      bc,02A53h
        push    bc
        ld      bc,00177h
        ld      a,P130_GFX_MODE
        jp      03D2Fh

p130_ngs_trdos_video_restored:
        ld      a,P130_HOST_PAGE5
        ld      bc,07FF7h
        out     (c),a
        ld      a,P130_HOST_PAGE0
        ld      bc,0FFF7h
        out     (c),a
        ei
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
        ; GS105a #14 encodes the byte count as a 16-bit two's-complement
        ; negative length (same as Project126), not the positive file size.
        ; The low byte is preloaded before command dispatch; the high byte
        ; follows #14. For 1..256 bytes this is FFxx or FF00.
        ld      hl,0
        ld      de,(p130_ngs_length)
        or      a
        sbc     hl,de
        ld      (p130_ngs_block_length),hl
        ld      a,l
        call    p130_ngs_send_argument
        jp      c,p130_ngs_fail
        ld      a,P130_CMD_RECV
        call    p130_ngs_send_command
        jp      c,p130_ngs_fail
        ld      a,(p130_ngs_block_length+1)
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
        ; Reproduce Project126's complete pre-jump file-open phase:
        ; after #14 has received NEOBOOT, open P130BOOT.C through the native
        ; TR-DOS C=0A/C=08 ABI and read its first sector with C=05. This is
        ; intentionally between #14 and #13, just like X86CORE in Project126.
        ld      a,'P'
        ld      (_p130_neogs_stage),a
        ld      a,'P'
        call    p130_ngs_trace
        call    p130_ngs_probe_host_file
        jp      c,p130_ngs_fail

        ; #13 transfers control to #4000. Bootstrap follows the Project126
        ; stack/DMA/GSCFG0/temporary-window sequence, then publishes A1.
        xor     a
        call    p130_ngs_send_argument
        jp      c,p130_ngs_fail
        ld      a,P130_CMD_JUMP
        call    p130_ngs_send_command
        jp      c,p130_ngs_fail
        ld      a,9
        ld      (_p130_neogs_stage),a
        ld      a,'9'
        call    p130_ngs_trace
        ; Split the jump handoff into observable sub-stages. 'J' means the
        ; target byte is about to be sent; 'W' means the host is waiting for
        ; the bootstrap response.
        ld      a,'J'
        call    p130_ngs_trace
        ld      a,040h
        call    p130_ngs_send_byte
        jr      nc,p130_ngs_jump_tx_done
        ; Project126 fallback: the #13 target byte may still be pending
        ; while GS105a has already switched to the bootstrap receiver.
        in      a,(P130_GSSTAT)
        ld      (p130_ngs_last_status),a
        bit     7,a
        jp      z,p130_ngs_jump_tx_fail
        ld      a,'W'
        call    p130_ngs_trace
        call    p130_ngs_receive_byte
        jr      c,p130_ngs_ack_timeout
        jr      p130_ngs_ack_check
p130_ngs_jump_tx_done:
        ld      a,'W'
        call    p130_ngs_trace
        call    p130_ngs_receive_byte
        jr      c,p130_ngs_ack_timeout
p130_ngs_ack_check:
        ld      (p130_ngs_ack_value),a
        ; One A1 acknowledgement, matching Project126. It is emitted only
        ; after DMA stop, NOROM/EXPAG and temporary memory-window setup.
        cp      P130_ACK_READY
        jr      nz,p130_ngs_ack_bad
        ld      a,'a'
        call    p130_ngs_trace
        ld      a,'1'
        call    p130_ngs_trace
        xor     a
        jp      p130_ngs_finish

p130_ngs_ack_bad:
        ld      a,'x'
        call    p130_ngs_trace
        ld      a,(p130_ngs_ack_value)
        call    p130_ngs_trace_hex
        jp      p130_ngs_fail

p130_ngs_ack_timeout:
        ld      a,'!'
        call    p130_ngs_trace
        ld      a,(p130_ngs_last_status)
        call    p130_ngs_trace_hex
        jp      p130_ngs_fail

p130_ngs_jump_tx_fail:
        ld      a,'j'
        call    p130_ngs_trace
        ld      a,(p130_ngs_last_status)
        call    p130_ngs_trace_hex
        jp      p130_ngs_fail

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

; A=byte, emit two hexadecimal digits on the existing debug channel.
p130_ngs_trace_hex:
        push    af
        rrca
        rrca
        rrca
        rrca
        call    p130_ngs_trace_nibble
        pop     af
        and     0Fh
        jp      p130_ngs_trace_nibble
p130_ngs_trace_nibble:
        and     0Fh
        add     a,'0'
        cp      '9'+1
        jr      c,p130_ngs_trace_hex_out
        add     a,7
p130_ngs_trace_hex_out:
        jp      p130_ngs_trace

; Project126-equivalent TR-DOS open-file probe, deliberately run after
; NEOBOOT has been transferred and before GS105a command #13.
; It opens the already-loaded host resident P130BOOT.C, validates its
; descriptor, and reads the first sector exactly as p126_neogs_open_file
; does for X86CORE. No resident bytes are sent to NeoGS over GSDAT.
p130_ngs_probe_host_file:
        xor     a
        ld      (p130_ngs_probe_error),a

        ; Match Project126/Project125 TR-DOS file-open ABI.
        ld      hl,p130_ngs_host_name
        ld      de,05CDDh
        ld      bc,8
        ldir
        ld      a,'C'
        ld      (05CE5h),a
        ld      a,9
        ld      (05D06h),a

        ; Enter the same shadow-off DOS mapping used by Project127.
        ld      a,083h
        ld      bc,0FFF7h
        out     (c),a
        ld      a,P130_GFX_MODE
        ld      bc,0FF77h
        out     (c),a

        ; C=0A: locate P130BOOT.C.
        ld      c,10
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        call    03D13h
        ld      a,c
        cp      0FFh
        jr      z,p130_ngs_probe_trdos_error

        ; C=08: fetch the complete TR-DOS file descriptor.
        push    af
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        pop     af
        ld      c,8
        call    03D13h
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_probe_trdos_error

        ; Match Project126 descriptor checks: nonzero length, bounded file,
        ; valid first-sector index.
        ld      hl,(05CE8h)
        ld      a,h
        or      l
        jr      z,p130_ngs_probe_trdos_error
        ld      (p130_ngs_host_length),hl
        ld      de,0C010h
        or      a
        sbc     hl,de
        jr      c,p130_ngs_probe_length_ok
        jr      z,p130_ngs_probe_length_ok
        jr      p130_ngs_probe_trdos_error
p130_ngs_probe_length_ok:
        ld      a,(05CEBh)
        cp      16
        jr      nc,p130_ngs_probe_trdos_error

        ; C=05: acquire the first sector into the Project126 staging buffer.
        ld      e,a
        ld      a,(05CECh)
        ld      d,a
        ld      hl,0C000h
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        call    03D13h
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_probe_trdos_error
        jr      p130_ngs_probe_restore_video

p130_ngs_probe_trdos_error:
        ld      a,1
        ld      (p130_ngs_probe_error),a

p130_ngs_probe_restore_video:
        ; Restore the RG6 console and host W2/W3 mapping before returning.
        di
        ld      bc,p130_ngs_probe_video_restored
        push    bc
        ld      bc,02A53h
        push    bc
        ld      bc,00177h
        ld      a,P130_GFX_MODE
        jp      03D2Fh

p130_ngs_probe_video_restored:
        ld      a,P130_HOST_PAGE5
        ld      bc,07FF7h
        out     (c),a
        ld      a,P130_HOST_PAGE0
        ld      bc,0FFF7h
        out     (c),a
        ei
        ld      a,(p130_ngs_probe_error)
        or      a
        jr      nz,p130_ngs_probe_failed
        or      a
        ret

p130_ngs_probe_failed:
        scf
        ret

; Receive one NeoGS byte and allow the sender to observe DBIT clear.
; This turnaround is present in the Project126 reference implementation.
p130_ngs_receive_byte:
        call    p130_ngs_wait_dbit_set
        ret     c
        in      a,(P130_GSDAT)
        push    af
        push    bc
        ld      bc,0400h
p130_ngs_receive_turnaround:
        dec     bc
        ld      a,b
        or      c
        jr      nz,p130_ngs_receive_turnaround
        pop     bc
        pop     af
        or      a
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
        ld      (p130_ngs_last_status),a
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
p130_ngs_block_length: dw 0
p130_ngs_tx:        db 0
p130_ngs_saved_sp:  dw 0
p130_ngs_result:    db 0
p130_ngs_old_name_len: db 0
p130_ngs_old_drive: db 0
p130_ngs_old_ext: db 0
p130_ngs_old_status: db 0
p130_ngs_sector: db 0
p130_ngs_track: db 0
p130_ngs_ack_value: db 0
p130_ngs_probe_error: db 0
p130_ngs_host_length: dw 0
p130_ngs_host_name: db "P130BOOT"
p130_ngs_last_status: db 0
p130_ngs_scan_left: db 0
