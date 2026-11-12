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

_p130_neogs_startup:
        ld      hl,p130_ngs_boot_name
        ld      de,05CDDh
        ld      bc,8
        ldir
        ld      a,'C'
        ld      (05CE5h),a
        ld      a,9
        ld      (05D06h),a
        ld      a,1
        ld      (_p130_neogs_stage),a
        ld      a,'1'
        call    p130_ngs_trace
        ld      c,10
        call    03D13h
        ld      a,c
        cp      0FFh
        jp      z,p130_ngs_fail

        push    af
        xor     a
        ld      (05D0Fh),a
        ld      (05D10h),a
        pop     af
        ld      a,2
        ld      (_p130_neogs_stage),a
        ld      a,'2'
        call    p130_ngs_trace
        ld      c,8
        call    03D13h
        ld      a,(05D0Fh)
        ld      b,a
        ld      a,(05D10h)
        or      b
        jp      nz,p130_ngs_fail

        ld      a,3
        ld      (_p130_neogs_stage),a
        ld      a,'3'
        call    p130_ngs_trace
        ; Stage-0 must fit one ROM receive block (1..256 bytes).
        ld      hl,(05CE8h)
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
        ld      hl,(05CE8h)
        ld      (p130_ngs_length),hl

        ld      a,4
        ld      (_p130_neogs_stage),a
        ld      a,'4'
        call    p130_ngs_trace
        ; Read the first and only sector into ATM W3 scratch at #C000.
        ld      a,(05CEBh)
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
        jp      nz,p130_ngs_fail

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
        ld      (_p130_neogs_stage),a
        ld      hl,0
        ret

p130_ngs_fail:
        ld      hl,1
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

p130_ngs_boot_name: db "NEOBOOT "
p130_ngs_length:    dw 0
p130_ngs_tx:        db 0
