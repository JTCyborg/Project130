; ============================================================================
; Project130 ATM host DS12887 RTC driver
; Ported from the verified Project129 ATM host driver contract.
; Read-only: never writes DS12887 time or control registers.
;
; Native GLUK: 0EFF7h gate, 0DFF7h register index, 0BFF7h data.
; SMUC fallback: 0FFBAh selects RTC read mode, 0DFBAh index/data.
; 0EFF7h close is followed by the Project126 TR-DOS 03D2Fh restore trampoline.
;
; C API:
;   p130_rtc_probe()
;   p130_rtc_read_current()
;   p130_rtc_available, p130_rtc_backend
;   p130_rtc_hour[2], p130_rtc_minute[2], p130_rtc_second[2]
; ============================================================================

SECTION CODE
PUBLIC _p130_rtc_probe
PUBLIC _p130_rtc_read_current
PUBLIC _p130_rtc_available
PUBLIC _p130_rtc_backend
PUBLIC _p130_rtc_hour
PUBLIC _p130_rtc_minute
PUBLIC _p130_rtc_second

_p130_rtc_probe:
        push    af
        push    bc
        push    de
        push    hl

        xor     a
        ld      (_p130_rtc_available),a
        ld      (_p130_rtc_backend),a
        call    p130_rtc_open
        call    p130_rtc_read_status
        call    p130_rtc_validate_status
        jr      nc,p130_rtc_probe_status_ready

        ; Native GLUK decoder absent: close it and try the SMUC interface.
        call    p130_rtc_close
        ld      a,1
        ld      (_p130_rtc_backend),a
        call    p130_rtc_open
        call    p130_rtc_read_status
        call    p130_rtc_validate_status
        jr      nc,p130_rtc_probe_status_ready
        call    p130_rtc_close
        call    p130_rtc_set_unknown
        jr      p130_rtc_probe_done

p130_rtc_probe_status_ready:
        call    p130_rtc_read_snapshot
        jr      c,p130_rtc_probe_read_failed
        call    p130_rtc_convert_snapshot
        ld      a,1
        ld      (_p130_rtc_available),a
        call    p130_rtc_close
        jr      p130_rtc_probe_done

p130_rtc_probe_read_failed:
        call    p130_rtc_close
        call    p130_rtc_set_unknown

p130_rtc_probe_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Public read API. Output buffers contain decimal ASCII HH/MM/SS or "??".
_p130_rtc_read_current:
        push    af
        push    bc
        push    de
        push    hl

        ld      a,(_p130_rtc_available)
        or      a
        jr      nz,p130_rtc_read_current_open
        call    p130_rtc_set_unknown
        jr      p130_rtc_read_current_done

p130_rtc_read_current_open:
        call    p130_rtc_open
        call    p130_rtc_read_snapshot
        jr      c,p130_rtc_read_current_failed
        call    p130_rtc_convert_snapshot
        call    p130_rtc_close
        jr      p130_rtc_read_current_done

p130_rtc_read_current_failed:
        call    p130_rtc_close
        call    p130_rtc_set_unknown

p130_rtc_read_current_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

p130_rtc_set_unknown:
        ld      a,'?'
        ld      (_p130_rtc_hour),a
        ld      (_p130_rtc_hour+1),a
        ld      (_p130_rtc_minute),a
        ld      (_p130_rtc_minute+1),a
        ld      (_p130_rtc_second),a
        ld      (_p130_rtc_second+1),a
        ret

; Capture DS12887 Status D, A and B.
p130_rtc_read_status:
        ld      a,00Dh
        call    p130_rtc_read_reg
        ld      (p130_rtc_status_d),a
        ld      a,00Ah
        call    p130_rtc_read_reg
        ld      (p130_rtc_status_a),a
        ld      a,00Bh
        call    p130_rtc_read_reg
        ld      (p130_rtc_status_b),a
        ret

; A plausible DS12887 has VRT=1 (Status D=080h) and divider bits 010b.
p130_rtc_validate_status:
        ld      a,(p130_rtc_status_d)
        cp      080h
        jr      nz,p130_rtc_status_invalid
        ld      a,(p130_rtc_status_a)
        and     070h
        cp      020h
        jr      nz,p130_rtc_status_invalid
        or      a
        ret
p130_rtc_status_invalid:
        scf
        ret

; Native GLUK gate or SMUC RTC read mode. Preserve caller AF/BC.
p130_rtc_open:
        push    af
        push    bc
        ld      a,(_p130_rtc_backend)
        or      a
        jr      nz,p130_rtc_open_smuc
        ld      bc,0EFF7h
        ld      a,080h
        out     (c),a
        jr      p130_rtc_open_done
p130_rtc_open_smuc:
        ; Keep the documented SMUC selector pattern; do not write 000h.
        ld      bc,0FFBAh
        ld      a,071h
        out     (c),a
p130_rtc_open_done:
        pop     bc
        pop     af
        ret

p130_rtc_close:
        push    af
        push    bc
        ld      a,(_p130_rtc_backend)
        or      a
        jr      nz,p130_rtc_close_done
        ld      bc,0EFF7h
        xor     a
        out     (c),a
        ; Re-establish the permanent DOSEN/shadow-port and RG6 state.
        call    p130_rtc_restore_dosen
p130_rtc_close_done:
        pop     bc
        pop     af
        ret

; A=RTC register number, returns data in A. BC preserved.
p130_rtc_read_reg:
        push    bc
        ld      c,a
        ld      a,(_p130_rtc_backend)
        or      a
        jr      nz,p130_rtc_read_reg_smuc
        ld      a,c
        ld      bc,0DFF7h
        out     (c),a
        ld      bc,0BFF7h
        in      a,(c)
        pop     bc
        ret
p130_rtc_read_reg_smuc:
        ld      a,c
        ld      bc,0DFBAh
        out     (c),a
        in      a,(c)
        pop     bc
        ret

; Wait for UIP=0, then read seconds/minutes/hours/seconds consistently.
; Carry set on timeout or repeated second rollover.
p130_rtc_read_snapshot:
        ld      b,4
p130_rtc_snapshot_retry:
        call    p130_rtc_wait_uip
        ret     c
        ld      a,000h
        call    p130_rtc_read_reg
        ld      (p130_rtc_seconds_raw),a
        ld      a,002h
        call    p130_rtc_read_reg
        ld      (p130_rtc_minutes_raw),a
        ld      a,004h
        call    p130_rtc_read_reg
        ld      (p130_rtc_hours_raw),a
        ld      a,000h
        call    p130_rtc_read_reg
        ld      c,a
        ld      a,(p130_rtc_seconds_raw)
        cp      c
        jr      z,p130_rtc_snapshot_stable
        djnz    p130_rtc_snapshot_retry
        scf
        ret
p130_rtc_snapshot_stable:
        ld      a,c
        ld      (p130_rtc_seconds_raw),a
        or      a
        ret

; 256 bounded UIP polls maximum. READ_REG preserves BC.
p130_rtc_wait_uip:
        push    bc
        ld      b,0
p130_rtc_uip_loop:
        ld      a,00Ah
        call    p130_rtc_read_reg
        bit     7,a
        jr      nz,p130_rtc_uip_busy
        or      a
        pop     bc
        ret
p130_rtc_uip_busy:
        djnz    p130_rtc_uip_loop
        scf
        pop     bc
        ret

; Convert hour respecting Status B 12/24-hour and BCD/binary bits.
p130_rtc_convert_snapshot:
        ld      a,(p130_rtc_hours_raw)
        ld      b,a
        ld      a,(p130_rtc_status_b)
        bit     1,a
        jr      nz,p130_rtc_hour_24

        ld      a,b
        and     080h
        ld      (p130_rtc_hour_pm),a
        ld      a,b
        and     07Fh
        call    p130_rtc_to_binary
        ld      (p130_rtc_hour_binary),a
        ld      a,(p130_rtc_hour_pm)
        or      a
        jr      z,p130_rtc_hour_am
        ld      a,(p130_rtc_hour_binary)
        cp      12
        jr      z,p130_rtc_hour_ready
        add     a,12
        jr      p130_rtc_hour_ready
p130_rtc_hour_am:
        ld      a,(p130_rtc_hour_binary)
        cp      12
        jr      nz,p130_rtc_hour_ready
        xor     a
        jr      p130_rtc_hour_ready
p130_rtc_hour_24:
        ld      a,b
        call    p130_rtc_to_binary
p130_rtc_hour_ready:
        ld      hl,_p130_rtc_hour
        call    p130_rtc_to_decimal
        ld      a,(p130_rtc_minutes_raw)
        call    p130_rtc_to_binary
        ld      hl,_p130_rtc_minute
        call    p130_rtc_to_decimal
        ld      a,(p130_rtc_seconds_raw)
        call    p130_rtc_to_binary
        ld      hl,_p130_rtc_second
        jp      p130_rtc_to_decimal

; A=RTC value. Convert BCD unless Status B bit 2 selects binary.
p130_rtc_to_binary:
        ld      b,a
        ld      a,(p130_rtc_status_b)
        bit     2,a
        ld      a,b
        ret     nz
        ld      b,a
        and     00Fh
        ld      c,a
        ld      a,b
        and     0F0h
        rrca
        rrca
        rrca
        rrca
        ld      b,a
        add     a,a
        ld      d,a
        add     a,a
        add     a,a
        add     a,d
        add     a,c
        ret

; A=0..99, HL=two-byte decimal ASCII destination.
p130_rtc_to_decimal:
        ld      b,0
p130_rtc_decimal_tens:
        cp      10
        jr      c,p130_rtc_decimal_ones
        sub     10
        inc     b
        jr      p130_rtc_decimal_tens
p130_rtc_decimal_ones:
        ld      d,a
        ld      a,b
        add     a,'0'
        ld      (hl),a
        inc     hl
        ld      a,d
        add     a,'0'
        ld      (hl),a
        ret

; Exact Project126 DOSEN restore trampoline, needed after GLUK 0EFF7h close.
p130_rtc_restore_dosen:
        push    af
        push    bc
        ld      bc,p130_rtc_restore_dosen_done
        push    bc
        ld      bc,02A53h
        push    bc
        ld      bc,00177h
        ld      a,0C6h
        jp      03D2Fh
p130_rtc_restore_dosen_done:
        pop     bc
        pop     af
        ; The ROM call may have changed the active W3 mapping.
        ld      a,07Fh
        ld      bc,0FFF7h
        out     (c),a
        ret

_p130_rtc_available: db 0
_p130_rtc_backend:   db 0
p130_rtc_status_a:   db 0
p130_rtc_status_b:   db 0
p130_rtc_status_d:   db 0
p130_rtc_seconds_raw: db 0
p130_rtc_minutes_raw: db 0
p130_rtc_hours_raw:   db 0
p130_rtc_hour_pm:     db 0
p130_rtc_hour_binary: db 0
_p130_rtc_hour:      db "??"
_p130_rtc_minute:    db "??"
_p130_rtc_second:    db "??"
