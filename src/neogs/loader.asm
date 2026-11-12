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

        ; Project126-compatible TR-DOS open/read path. Do not scan the
        ; preloaded catalogue: use C=#0A, C=#08 and C=#05 for both files.
        ld      a,'R'
        call    p130_ngs_trace
        ld      hl,p130_ngs_boot_name
        call    p130_ngs_open_file
        jp      c,p130_ngs_fail
        ld      hl,(p130_ngs_length)
        ld      a,h
        or      a
        jr      z,p130_ngs_boot_len_low
        cp      1
        jp      nz,p130_ngs_fail
        ld      a,l
        or      a
        jp      nz,p130_ngs_fail
        jr      p130_ngs_boot_len_ok
p130_ngs_boot_len_low:
        ld      a,l
        or      a
        jp      z,p130_ngs_fail
p130_ngs_boot_len_ok:
        ld      a,'r'
        call    p130_ngs_trace

        ; Match Project126 reset and #14 transaction byte-for-byte.
        ld      a,5
        ld      (_p130_neogs_stage),a
        ld      a,'5'
        call    p130_ngs_trace
        ld      a,P130_CMD_RESET
        call    p130_ngs_send_command_long
        jp      c,p130_ngs_fail

        ld      a,6
        ld      (_p130_neogs_stage),a
        ld      a,'6'
        call    p130_ngs_trace
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
; Project130 deliberately does not open X86CORE before A1.
        ; The resident core is a DMA/IPC payload and is not yet packaged or
        ; loaded at this bootstrap-only milestone. Match P126 from NEOBOOT
        ; transfer through #13 and A1; defer core discovery until DMA/IPC.

        ld      a,9
        ld      (_p130_neogs_stage),a
        ld      a,'9'
        call    p130_ngs_trace
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
        ; P126's exact #13 target-byte send and DBIT fallback.
        ld      a,040h
        call    p130_ngs_send_byte
        jr      nc,p130_ngs_jump_tx_done
        in      a,(P130_GSSTAT)
        bit     7,a
        jp      z,p130_ngs_fail
        call    p130_ngs_receive_byte
        jr      c,p130_ngs_ack_timeout
        jr      p130_ngs_ack_check
p130_ngs_jump_tx_done:
        call    p130_ngs_receive_byte
        jr      c,p130_ngs_ack_timeout
p130_ngs_ack_check:
        ld      (p130_ngs_ack_value),a
        ; Exactly one A1 ready byte; no resident payload follows it.
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

; Project126 TR-DOS file-open ABI, with Project130's required ATM
; shadow/video banking around each ROM call. IN HL=8-char name; OUT C=0,
; first sector at C000h and exact file length in p130_ngs_length.
p130_ngs_open_file:
        ld      (p130_ngs_name_ptr),hl
        ld      hl,(p130_ngs_name_ptr)
        ld      de,05CDDh
        ld      bc,8
        ldir
        ld      a,(p130_ngs_file_extension)
        ld      (05CE5h),a
        ld      a,9
        ld      (05D06h),a
        ld      c,10
        call    p130_ngs_trdos_call
        ld      a,c
        cp      0FFh
        jr      z,p130_ngs_trdos_open_error
        ld      (p130_ngs_trdos_a),a
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        ld      a,(p130_ngs_trdos_a)
        ld      c,8
        call    p130_ngs_trdos_call
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_trdos_open_error
        ld      hl,(05CE8h)
        ld      (p130_ngs_length),hl
        ld      a,h
        or      l
        jr      z,p130_ngs_trdos_open_error
        ld      de,0C010h
        or      a
        sbc     hl,de
        jr      c,p130_ngs_file_length_ok
        jp      nz,p130_ngs_trdos_open_error
p130_ngs_file_length_ok:
        ld      hl,(p130_ngs_length)
        ld      de,255
        add     hl,de
        ld      a,h
        or      a
        jr      z,p130_ngs_trdos_open_error
        ld      (p130_ngs_file_sectors_left),a
        ld      a,(05CEBh)
        cp      16
        jr      nc,p130_ngs_trdos_open_error
        ld      (p130_ngs_file_sector),a
        ld      a,(05CECh)
        ld      (p130_ngs_file_track),a
        call    p130_ngs_read_first_sector
        ret

p130_ngs_trdos_open_error:
        scf
        ret

; C=5/B=1 sector read, same cursor semantics as Project126.
p130_ngs_read_first_sector:
        ld      a,(p130_ngs_file_sectors_left)
        or      a
        jr      z,p130_ngs_trdos_open_error
        ld      a,(p130_ngs_file_track)
        ld      d,a
        ld      a,(p130_ngs_file_sector)
        ld      e,a
        ld      hl,0C000h
        ld      b,1
        ld      c,5
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        call    p130_ngs_trdos_call
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_trdos_open_error
        xor     a
        ret

; Invoke TR-DOS #3D13 with the Project127 shadow-page transition.
; Preserve the ROM result registers across video/page restoration.
p130_ngs_trdos_call:
        ld      (p130_ngs_trdos_in_a),a
        ld      (p130_ngs_trdos_in_bc),bc
        ld      (p130_ngs_trdos_in_de),de
        ld      (p130_ngs_trdos_in_hl),hl
        push    af
        push    bc
        push    de
        push    hl
        ld      a,083h
        ld      bc,0FFF7h
        out     (c),a
        ld      a,P130_GFX_MODE
        ld      bc,0FF77h
        out     (c),a
        ; Restore the exact TR-DOS call inputs after the paging writes.
        ld      a,(p130_ngs_trdos_in_a)
        ld      bc,(p130_ngs_trdos_in_bc)
        ld      de,(p130_ngs_trdos_in_de)
        ld      hl,(p130_ngs_trdos_in_hl)
        ld      hl,p130_ngs_trdos_return
        push    hl
        ld      (23613),sp
        ; Restore the requested entry registers once the return trampoline
        ; has been installed; use the saved copies because HL held its PC.
        ld      a,(p130_ngs_trdos_in_a)
        ld      bc,(p130_ngs_trdos_in_bc)
        ld      de,(p130_ngs_trdos_in_de)
        ld      hl,(p130_ngs_trdos_in_hl)
        xor     a
        ld      (23801),a
        ld      (23823),a
        ld      (23824),a
        ld      a,(p130_ngs_trdos_in_a)
        jp      03D13h
p130_ngs_trdos_return:
        ld      (p130_ngs_trdos_a),a
        ld      (p130_ngs_trdos_bc),bc
        ld      (p130_ngs_trdos_de),de
        ld      (p130_ngs_trdos_hl),hl
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
        ; Drop the saved caller inputs, then restore the TR-DOS outputs.
        pop     hl
        pop     de
        pop     bc
        pop     af
        ld      hl,(p130_ngs_trdos_hl)
        ld      de,(p130_ngs_trdos_de)
        ld      bc,(p130_ngs_trdos_bc)
        ld      a,(p130_ngs_trdos_a)
        ret

; Emit a one-character progress marker on the existing #EF debug channel.
p130_ngs_trace:
        push    bc
        ld      bc,00EFh
        out     (c),a
        ; Side-effect-free: the #EF channel is sufficient for diagnostics.
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
p130_ngs_last_status: db 0
p130_ngs_scan_left: db 0

; File-open state for the NEOBOOT.C bootstrap path.
; Keep these buffers in CODE's writable data area, as in the P126 loader.
p130_ngs_file_extension: db 'C'
p130_ngs_name_ptr: dw 0
p130_ngs_file_sectors_left: db 0
p130_ngs_file_sector: db 0
p130_ngs_file_track: db 0

; TR-DOS #3D13 wrapper: saved entry registers and returned registers.
p130_ngs_trdos_in_a: db 0
p130_ngs_trdos_in_bc: dw 0
p130_ngs_trdos_in_de: dw 0
p130_ngs_trdos_in_hl: dw 0
p130_ngs_trdos_a: db 0
p130_ngs_trdos_bc: dw 0
p130_ngs_trdos_de: dw 0
p130_ngs_trdos_hl: dw 0
