; Project130 ATM-side GS105a bootstrap launcher.
; Startup transaction is ported from the working Project126
; atm_host/p126_neogs_loader.asm: #F4 -> #14 -> #13 -> A1 -> A3 -> image -> A2.
; Keep the caller's stack exactly as Project126 does; do not switch to a
; Project130-private stack during TR-DOS ROM calls or the GS105a handshake.

SECTION CODE
PUBLIC _p130_neogs_startup
EXTERN p130_trdos_rom_call

P130_GSCOM       EQU 0BBh
P130_GSSTAT      EQU 0BBh
P130_GSDAT       EQU 0B3h
P130_CMD_JUMP    EQU 013h
P130_CMD_RECV    EQU 014h
P130_CMD_RESET   EQU 0F4h
P130_ACK_READY   EQU 0A1h
P130_ACK_LENGTH  EQU 0A3h
P130_ACK_DONE    EQU 0A2h

_p130_neogs_startup:
        ; Run the Project126 pre-video TR-DOS ROM call path directly.
; The host has not enabled ATM shadow/video paging at this startup stage.
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
        xor     a
        ld      (p130_ngs_result),a

        ; Project126 startup transaction, ported in the same order and with
        ; the same diagnostic markers. Only the P130 symbol/filename names
        ; and the C-callable entry/return wrapper differ.
        ld      a,1
        ld      (_p130_neogs_stage),a
        ld      a,'1'
        call    p130_ngs_trace
        ld      hl,p130_ngs_boot_name
        call    p130_ngs_open_file
        jp      c,p130_ngs_fail

        ld      a,2
        ld      (_p130_neogs_stage),a
        ld      a,'2'
        call    p130_ngs_trace
        ; Accept bootstrap files of 1..255 bytes and exactly 256 bytes.
        ld      hl,(p130_ngs_length)
        ld      a,h
        or      a
        jr      z,p130_ngs_boot_length_low
        cp      1
        jp      nz,p130_ngs_fail
        ld      a,l
        or      a
        jp      nz,p130_ngs_fail
        jr      p130_ngs_boot_length_ok
p130_ngs_boot_length_low:
        ld      a,l
        or      a
        jp      z,p130_ngs_fail
p130_ngs_boot_length_ok:

        ; Exact Project126 reset step: no #20 RAM probe.
        ld      a,0Ah
        ld      (_p130_neogs_stage),a
        ld      a,'A'
        call    p130_ngs_trace
        ld      a,P130_CMD_RESET
        call    p130_ngs_send_command_long
        jp      c,p130_ngs_fail

        ; GS105a #14 receives NEOBOOT.C at logical #4000.
        ld      a,4
        ld      (_p130_neogs_stage),a
        ld      a,'4'
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
        ld      hl,0C000h
        ld      de,(p130_ngs_length)
p130_ngs_boot_stream:
        ld      a,d
        or      e
        jr      z,p130_ngs_boot_loaded
        ld      a,(hl)
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        inc     hl
        dec     de
        jr      p130_ngs_boot_stream
p130_ngs_boot_loaded:
        ; Project126 opens X86CORE.C and primes its first 256-byte sector
        ; BEFORE entering stage-0. Preserve that ordering exactly.
        ld      a,5
        ld      (_p130_neogs_stage),a
        ld      a,'5'
        call    p130_ngs_trace
        ld      hl,p130_ngs_core_name
        ld      a,'C'
        ld      (p130_ngs_file_extension),a
        call    p130_ngs_open_file
        jp      c,p130_ngs_fail

        ld      a,6
        ld      (_p130_neogs_stage),a
        ld      a,'6'
        call    p130_ngs_trace
        ld      hl,(p130_ngs_length)
        ld      a,h
        cp      040h
        jr      c,p130_ngs_core_size_low
        jp      nz,p130_ngs_fail
        ld      a,l
        or      a
        jp      nz,p130_ngs_fail
p130_ngs_core_size_low:
        ld      a,h
        or      l
        jp      z,p130_ngs_fail
        ld      hl,(p130_ngs_length)
        ld      (p130_ngs_core_length),hl

        ; Enter stage-0 at #4000. This is the Project126 #13 transaction.
        ld      a,7
        ld      (_p130_neogs_stage),a
        ld      a,'7'
        call    p130_ngs_trace
        xor     a
        call    p130_ngs_send_argument
        jp      c,p130_ngs_fail
        ld      a,P130_CMD_JUMP
        call    p130_ngs_send_command
        jp      c,p130_ngs_fail
        ld      a,040h
        call    p130_ngs_send_byte
        jr      nc,p130_ngs_jump_tx_done
        in      a,(P130_GSSTAT)
        bit     7,a
        jp      z,p130_ngs_jump_tx_fail
        call    p130_ngs_receive_byte
        jp      c,p130_ngs_ack_timeout
        cp      P130_ACK_READY
        jp      nz,p130_ngs_ack_bad
        jr      p130_ngs_stage0_ready
p130_ngs_jump_tx_done:
        call    p130_ngs_receive_byte
        jp      c,p130_ngs_ack_timeout
        cp      P130_ACK_READY
        jp      nz,p130_ngs_ack_bad

p130_ngs_stage0_ready:
        ; Stage-0 length exchange; A3 confirms the exact resident size.
        ld      a,8
        ld      (_p130_neogs_stage),a
        ld      a,'8'
        call    p130_ngs_trace
        ld      hl,(p130_ngs_core_length)
        ld      a,l
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        ld      a,h
        call    p130_ngs_send_byte
        jr      nc,p130_ngs_length_sent
        in      a,(P130_GSSTAT)
        bit     7,a
        jp      z,p130_ngs_fail
        call    p130_ngs_receive_byte
        jp      c,p130_ngs_fail
        cp      0A3h
        jp      nz,p130_ngs_fail
        jr      p130_ngs_stream_begin
p130_ngs_length_sent:
        call    p130_ngs_receive_byte
        jp      c,p130_ngs_fail
        cp      0A3h
        jp      nz,p130_ngs_fail

p130_ngs_stream_begin:
        ld      a,9
        ld      (_p130_neogs_stage),a
        ld      a,'9'
        call    p130_ngs_trace
        ld      hl,0C000h
        ld      (p130_ngs_buffer_ptr),hl
        ld      hl,256
        ld      (p130_ngs_buffer_remaining),hl
        ld      de,(p130_ngs_core_length)
p130_ngs_core_stream:
        ld      a,d
        or      e
        jr      z,p130_ngs_core_stream_done
        ; Refill only after all 256 bytes in the current sector are consumed.
        ld      hl,(p130_ngs_buffer_remaining)
        ld      a,h
        or      l
        jr      nz,p130_ngs_core_buffer_ready
        push    de
        call    p130_ngs_read_next_sector
        pop     de
        jp      c,p130_ngs_fail
        ld      hl,0C000h
        ld      (p130_ngs_buffer_ptr),hl
        ld      hl,256
        ld      (p130_ngs_buffer_remaining),hl
p130_ngs_core_buffer_ready:
        ld      hl,(p130_ngs_buffer_ptr)
        ld      a,(hl)
        call    p130_ngs_send_byte
        jp      c,p130_ngs_fail
        inc     hl
        ld      (p130_ngs_buffer_ptr),hl
        ld      hl,(p130_ngs_buffer_remaining)
        dec     hl
        ld      (p130_ngs_buffer_remaining),hl
        dec     de
        jr      p130_ngs_core_stream

p130_ngs_core_stream_done:
        ; P126 marks the post-transfer resident-ready wait with 'B'.
        ld      a,0Bh
        ld      (_p130_neogs_stage),a
        ld      a,'B'
        call    p130_ngs_trace
        call    p130_ngs_receive_byte
        jp      c,p130_ngs_fail
        cp      0A2h
        jp      nz,p130_ngs_fail
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

; Project126 TR-DOS file-open ABI using direct #3D13 calls before video init.
; IN HL=8-char name; OUT C=0,
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
        call    p130_trdos_rom_call
        ld      a,c
        cp      0FFh
        jr      z,p130_ngs_trdos_open_error
        ld      (p130_ngs_trdos_a),a
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        ld      a,(p130_ngs_trdos_a)
        ld      c,8
        call    p130_trdos_rom_call
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
        call    p130_trdos_rom_call
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_trdos_open_error
        jp      p130_ngs_advance_sector_cursor

p130_ngs_read_next_sector:
        ld      a,(p130_ngs_file_sectors_left)
        or      a
        jr      nz,p130_ngs_next_sector_available
        scf
        ret
p130_ngs_next_sector_available:
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
        call    p130_trdos_rom_call
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jr      nz,p130_ngs_trdos_open_error
p130_ngs_advance_sector_cursor:
        ld      a,(p130_ngs_file_sector)
        inc     a
        cp      16
        jr      c,p130_ngs_sector_same_track
        xor     a
        ld      (p130_ngs_file_sector),a
        ld      a,(p130_ngs_file_track)
        inc     a
        ld      (p130_ngs_file_track),a
        jr      p130_ngs_sector_cursor_advanced
p130_ngs_sector_same_track:
        ld      (p130_ngs_file_sector),a
p130_ngs_sector_cursor_advanced:
        ld      a,(p130_ngs_file_sectors_left)
        dec     a
        ld      (p130_ngs_file_sectors_left),a
        or      a
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

p130_ngs_boot_name: db "NEOBOOT "
p130_ngs_core_name: db "X86CORE "
p130_ngs_length:    dw 0
p130_ngs_core_length: dw 0
p130_ngs_buffer_ptr: dw 0
p130_ngs_buffer_remaining: dw 0
p130_ngs_block_length: dw 0
p130_ngs_tx:        db 0
p130_ngs_result:    db 0
p130_ngs_old_name_len: db 0
p130_ngs_old_drive: db 0
p130_ngs_old_ext: db 0
p130_ngs_old_status: db 0
p130_ngs_sector: db 0
p130_ngs_track: db 0
p130_ngs_ack_value: db 0
p130_ngs_ram_report: db 0,0,0
p130_ngs_last_status: db 0
p130_ngs_scan_left: db 0

; File-open state for the NEOBOOT.C bootstrap path.
; Keep these buffers in CODE's writable data area, as in the P126 loader.
p130_ngs_file_extension: db 'C'
p130_ngs_name_ptr: dw 0
p130_ngs_file_sectors_left: db 0
p130_ngs_file_sector: db 0
p130_ngs_file_track: db 0
p130_ngs_trdos_a: db 0

